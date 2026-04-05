/**
 * Google Apps Script: Email Ingestion + Telegram Admin for SPWS Ranklist
 * (ADR-023 + ADR-025)
 *
 * Two functions run on a 5-minute timer:
 *   1. checkEmailForResults() — polls Gmail for .zip/.xml attachments
 *   2. checkTelegramCommands() — polls Telegram getUpdates for admin commands
 *
 * Setup (Script Properties):
 *   SUPABASE_URL           — Supabase project URL (CERT)
 *   SUPABASE_SERVICE_ROLE_KEY — service_role key (bypasses RLS)
 *   GITHUB_PAT             — GitHub personal access token (workflow_dispatch scope)
 *   GITHUB_REPO            — owner/repo (e.g. "Fencer4Life/spws-automated-ranklist")
 *   TELEGRAM_BOT_TOKEN     — Telegram bot token
 *   TELEGRAM_CHAT_ID       — Authorized admin chat ID
 *   TELEGRAM_LAST_UPDATE   — (auto-managed) last processed update_id
 *   PAUSED                 — (auto-managed) "true" to pause email polling
 *
 * Deploy:
 *   1. Create GAS project linked to spws.weterani@gmail.com
 *   2. Set Script Properties above
 *   3. Run createTimeTrigger() once to start 5-minute polling
 */


// ═══════════════════════════════════════════════════════════════
// EMAIL INGESTION
// ═══════════════════════════════════════════════════════════════

function checkEmailForResults() {
  var props = PropertiesService.getScriptProperties();

  // Check if paused
  if (props.getProperty('PAUSED') === 'true') return;

  var supabaseUrl = props.getProperty('SUPABASE_URL');
  var supabaseKey = props.getProperty('SUPABASE_SERVICE_ROLE_KEY');
  var githubPat = props.getProperty('GITHUB_PAT');
  var githubRepo = props.getProperty('GITHUB_REPO');

  var threads = GmailApp.search('is:unread has:attachment (filename:zip OR filename:xml)', 0, 10);
  if (threads.length === 0) return;

  var uploadedCount = 0;

  for (var t = 0; t < threads.length; t++) {
    var messages = threads[t].getMessages();
    for (var m = 0; m < messages.length; m++) {
      var msg = messages[m];
      if (msg.isUnread()) {
        var attachments = msg.getAttachments();
        for (var a = 0; a < attachments.length; a++) {
          var att = attachments[a];
          var name = att.getName().toLowerCase();
          if (name.endsWith('.zip') || name.endsWith('.xml')) {
            var timestamp = Utilities.formatDate(new Date(), 'UTC', 'yyyyMMdd_HHmmss');
            var storagePath = 'staging/' + timestamp + '_' + att.getName();
            uploadToSupabaseStorage(supabaseUrl, supabaseKey, storagePath, att.getBytes(), att.getContentType());
            uploadedCount++;
          }
        }
        msg.markRead();
      }
    }
    var label = GmailApp.getUserLabelByName('PROCESSED');
    if (!label) label = GmailApp.createLabel('PROCESSED');
    threads[t].addLabel(label);
  }

  if (uploadedCount > 0) {
    sendTelegramMessage(props, 'New files uploaded to staging: ' + uploadedCount + ' file(s)');
    triggerGitHubWorkflow(githubPat, githubRepo, 'ingest.yml', { source: 'gas' });
  }
}


// ═══════════════════════════════════════════════════════════════
// TELEGRAM COMMAND INTERFACE (ADR-025)
// ═══════════════════════════════════════════════════════════════

function checkTelegramCommands() {
  var props = PropertiesService.getScriptProperties();
  var token = props.getProperty('TELEGRAM_BOT_TOKEN');
  var authorizedChat = props.getProperty('TELEGRAM_CHAT_ID');
  if (!token || !authorizedChat) return;

  var lastUpdate = parseInt(props.getProperty('TELEGRAM_LAST_UPDATE') || '0', 10);
  var url = 'https://api.telegram.org/bot' + token + '/getUpdates?offset=' + (lastUpdate + 1) + '&timeout=0';

  var response = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  var data = JSON.parse(response.getContentText());
  if (!data.ok || !data.result || data.result.length === 0) return;

  for (var i = 0; i < data.result.length; i++) {
    var update = data.result[i];
    props.setProperty('TELEGRAM_LAST_UPDATE', String(update.update_id));

    var msg = update.message;
    if (!msg || !msg.text) continue;
    if (String(msg.chat.id) !== authorizedChat) continue;

    var text = msg.text.trim();
    var parts = text.split(/\s+/);
    var command = parts[0].toLowerCase();
    var arg = parts.slice(1).join(' ');

    try {
      var reply = handleCommand(props, command, arg);
      sendTelegramMessage(props, reply);
    } catch (e) {
      sendTelegramMessage(props, 'Error: ' + e.message);
    }
  }
}

function handleCommand(props, command, arg) {
  var supabaseUrl = props.getProperty('SUPABASE_URL');
  var supabaseKey = props.getProperty('SUPABASE_SERVICE_ROLE_KEY');

  switch (command) {
    // --- Lifecycle ---
    case 'status':
      return formatJson(callRpc(supabaseUrl, supabaseKey, 'fn_event_status', { p_prefix: arg }));

    case 'complete':
      callRpc(supabaseUrl, supabaseKey, 'fn_complete_event', { p_prefix: arg });
      return 'Event "' + arg + '" marked COMPLETED.';

    case 'rollback':
      var result = callRpc(supabaseUrl, supabaseKey, 'fn_rollback_event', { p_prefix: arg });
      return 'Rolled back "' + arg + '": ' + result.tournaments_deleted + ' tournaments, ' + result.results_deleted + ' results deleted.';

    case 'promote':
      var githubPat = props.getProperty('GITHUB_PAT');
      var githubRepo = props.getProperty('GITHUB_REPO');
      triggerGitHubWorkflow(githubPat, githubRepo, 'promote.yml', { event_code: arg });
      return 'Promotion triggered for "' + arg + '". Watch for completion notification.';

    // --- Data review ---
    case 'results':
      return formatJson(callRpc(supabaseUrl, supabaseKey, 'fn_event_results_summary', { p_prefix: arg }));

    case 'pending':
      return formatJson(callRpc(supabaseUrl, supabaseKey, 'fn_event_pending', { p_prefix: arg }));

    case 'missing':
      return formatJson(callRpc(supabaseUrl, supabaseKey, 'fn_event_missing_categories', { p_prefix: arg }));

    // --- Storage ---
    case 'staging':
      return listStagingFiles(supabaseUrl, supabaseKey);

    case 'cleanup':
      return cleanupStaging(supabaseUrl, supabaseKey);

    // --- Season ---
    case 'season':
      return formatJson(callRpc(supabaseUrl, supabaseKey, 'fn_season_overview', {}));

    case 'ranking':
      var rParts = arg.split(/\s+/);
      if (rParts.length < 3) return 'Usage: ranking <category> <gender> <weapon>\nExample: ranking V2 M EPEE';
      return formatJson(callRpc(supabaseUrl, supabaseKey, 'fn_category_ranking', {
        p_weapon: rParts[2], p_gender: rParts[1], p_category: rParts[0]
      }));

    // --- Emergency ---
    case 'pause':
      props.setProperty('PAUSED', 'true');
      return 'Email polling PAUSED. Send "resume" to re-enable.';

    case 'resume':
      props.deleteProperty('PAUSED');
      return 'Email polling RESUMED.';

    // --- Admin ---
    case 'help':
      return [
        'SPWS Bot Commands:',
        '',
        'Lifecycle:',
        '  status <event>    - Event status + counts',
        '  complete <event>  - Mark event done',
        '  rollback <event>  - Delete all data, reset to PLANNED',
        '  promote <event>   - Push CERT data to PROD',
        '',
        'Review:',
        '  results <event>   - Top 3 per tournament',
        '  pending <event>   - Unresolved matches',
        '  missing <event>   - Missing categories',
        '',
        'Storage:',
        '  staging           - List files in staging',
        '  cleanup           - Delete all staging files',
        '',
        'Season:',
        '  season            - All events overview',
        '  ranking V2 M EPEE - Top 5 in category',
        '',
        'Emergency:',
        '  pause / resume    - Toggle email polling',
      ].join('\n');

    default:
      return 'Unknown command: "' + command + '". Send "help" for available commands.';
  }
}


// ═══════════════════════════════════════════════════════════════
// SUPABASE HELPERS
// ═══════════════════════════════════════════════════════════════

function callRpc(url, key, fnName, params) {
  var endpoint = url + '/rest/v1/rpc/' + fnName;
  var response = UrlFetchApp.fetch(endpoint, {
    method: 'post',
    headers: {
      'Authorization': 'Bearer ' + key,
      'apikey': key,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    },
    payload: JSON.stringify(params),
    muteHttpExceptions: true,
  });

  if (response.getResponseCode() >= 400) {
    var err = JSON.parse(response.getContentText());
    throw new Error(err.message || response.getContentText());
  }

  return JSON.parse(response.getContentText());
}

function uploadToSupabaseStorage(url, key, path, bytes, contentType) {
  var endpoint = url + '/storage/v1/object/xml-inbox/' + path;
  var response = UrlFetchApp.fetch(endpoint, {
    method: 'post',
    headers: {
      'Authorization': 'Bearer ' + key,
      'apikey': key,
      'Content-Type': contentType || 'application/octet-stream',
    },
    payload: bytes,
    muteHttpExceptions: true,
  });
  if (response.getResponseCode() >= 400) {
    throw new Error('Storage upload failed: ' + response.getContentText());
  }
}

function listStagingFiles(url, key) {
  var endpoint = url + '/storage/v1/object/list/xml-inbox';
  var response = UrlFetchApp.fetch(endpoint, {
    method: 'post',
    headers: {
      'Authorization': 'Bearer ' + key,
      'apikey': key,
      'Content-Type': 'application/json',
    },
    payload: JSON.stringify({ prefix: 'staging', limit: 100 }),
    muteHttpExceptions: true,
  });

  var files = JSON.parse(response.getContentText());
  if (!files || files.length === 0) return 'Staging is empty.';

  var lines = ['Staging files (' + files.length + '):'];
  for (var i = 0; i < files.length; i++) {
    lines.push('  ' + files[i].name);
  }
  return lines.join('\n');
}

function cleanupStaging(url, key) {
  var endpoint = url + '/storage/v1/object/list/xml-inbox';
  var response = UrlFetchApp.fetch(endpoint, {
    method: 'post',
    headers: {
      'Authorization': 'Bearer ' + key,
      'apikey': key,
      'Content-Type': 'application/json',
    },
    payload: JSON.stringify({ prefix: 'staging', limit: 100 }),
    muteHttpExceptions: true,
  });

  var files = JSON.parse(response.getContentText());
  if (!files || files.length === 0) return 'Staging already empty.';

  var paths = files.map(function(f) { return 'staging/' + f.name; });

  var delEndpoint = url + '/storage/v1/object/xml-inbox';
  UrlFetchApp.fetch(delEndpoint, {
    method: 'delete',
    headers: {
      'Authorization': 'Bearer ' + key,
      'apikey': key,
      'Content-Type': 'application/json',
    },
    payload: JSON.stringify({ prefixes: paths }),
    muteHttpExceptions: true,
  });

  return 'Staging cleared: ' + files.length + ' file(s) deleted.';
}


// ═══════════════════════════════════════════════════════════════
// GITHUB + TELEGRAM HELPERS
// ═══════════════════════════════════════════════════════════════

function triggerGitHubWorkflow(pat, repo, workflow, inputs) {
  var url = 'https://api.github.com/repos/' + repo + '/actions/workflows/' + workflow + '/dispatches';
  var response = UrlFetchApp.fetch(url, {
    method: 'post',
    headers: {
      'Authorization': 'token ' + pat,
      'Accept': 'application/vnd.github.v3+json',
    },
    payload: JSON.stringify({ ref: 'main', inputs: inputs }),
    contentType: 'application/json',
    muteHttpExceptions: true,
  });
  if (response.getResponseCode() >= 400) {
    throw new Error('GitHub dispatch failed: ' + response.getContentText());
  }
}

function sendTelegramMessage(props, message) {
  var token = props.getProperty('TELEGRAM_BOT_TOKEN');
  var chatId = props.getProperty('TELEGRAM_CHAT_ID');
  if (!token || !chatId) return;

  // Telegram has a 4096 char limit — truncate if needed
  if (message.length > 4000) {
    message = message.substring(0, 4000) + '\n...(truncated)';
  }

  UrlFetchApp.fetch('https://api.telegram.org/bot' + token + '/sendMessage', {
    method: 'post',
    payload: { chat_id: chatId, text: message },
    muteHttpExceptions: true,
  });
}

function formatJson(data) {
  if (typeof data === 'string') return data;
  return JSON.stringify(data, null, 2);
}


// ═══════════════════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════════════════

/**
 * Run once to set up the 5-minute polling trigger for both functions.
 */
function createTimeTrigger() {
  ScriptApp.newTrigger('checkEmailForResults')
    .timeBased()
    .everyMinutes(5)
    .create();
  ScriptApp.newTrigger('checkTelegramCommands')
    .timeBased()
    .everyMinutes(5)
    .create();
}
