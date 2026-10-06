/**
 * Google Apps Script: Telegram admin bot for SPWS Ranklist (ADR-025, ADR-108)
 *
 * The live Apps Script project runs this file verbatim: paste the whole file over
 * the project's Code.gs (operator runbooks, "Change the Telegram bot"). The help
 * text below is the bot's command list; python/tests/test_gas_bot.py keeps it in
 * step with the commands (GAS.HELP.01–04).
 *
 * One function runs on a 5-minute timer:
 *   checkTelegramCommands() — polls Telegram getUpdates for admin commands
 *
 * Setup (Script Properties):
 *   SUPABASE_PROJECT_REF   — CERT project ref; the database commands run there
 *   SUPABASE_PROD_REF      — PROD project ref, for the read-only *-prod commands
 *   SUPABASE_ACCESS_TOKEN  — Supabase personal access token (Management API) for the
 *                            database commands; a stale token answers "Unauthorized"
 *   GITHUB_PAT             — GitHub personal access token (workflow_dispatch scope)
 *   GITHUB_REPO            — owner/repo (e.g. "Fencer4Life/spws-automated-ranklist")
 *   TELEGRAM_BOT_TOKEN     — Telegram bot token
 *   TELEGRAM_CHAT_ID       — Authorized admin chat ID
 *   TELEGRAM_LAST_UPDATE   — (auto-managed) last processed update_id
 *
 * Deploy:
 *   1. Create GAS project linked to spws.weterani@gmail.com
 *   2. Set Script Properties above
 *   3. Run createTimeTrigger() once to start 5-minute polling
 */


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
  switch (command) {
    // --- Lifecycle ---
    case 'status':
      var statusData = callRpc('fn_event_status', { p_prefix: arg });
      return '<b>Event Status (CERT)</b>\n'
        + '<pre>' + (statusData.event_code || arg) + '</pre>\n'
        + 'Status: <b>' + (statusData.event_status || '—') + '</b>\n'
        + 'Tournaments: <b>' + (statusData.tournament_count || 0) + '</b>\n'
        + 'Results: <b>' + (statusData.result_count || 0) + '</b>\n'
        + 'Pending: <b>' + (statusData.pending_count || 0) + '</b>';

    case 'complete':
      // ADR-108 §7: an exact event code; a prefix is refused with the matching codes.
      // CERT only; the daily close (event-close.yml) closes PROD after the end date.
      callRpc('fn_complete_event', { p_prefix: arg });
      // export-seed.yml exports the seed from PROD (ADR-036).
      try { triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'), 'export-seed.yml', { reason: 'complete' }); } catch(e) {}
      return '<b>Event Completed (CERT)</b>\n'
        + '<pre>' + arg + '</pre>\n'
        + 'Status changed to <b>COMPLETED</b> on CERT\n'
        + '<i>PROD closes by the daily close after the end date. Seed export from PROD started.</i>';

    case 'rollback':
      var result = callRpc('fn_rollback_event', { p_prefix: arg });
      // export-seed.yml exports the seed from PROD (ADR-036).
      try { triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'), 'export-seed.yml', { reason: 'rollback' }); } catch(e) {}
      return '<b>Event Rolled Back (CERT)</b>\n'
        + '<pre>' + arg + '</pre>\n'
        + 'Tournaments deleted: <b>' + result.tournaments_deleted + '</b>\n'
        + 'Results deleted: <b>' + result.results_deleted + '</b>\n'
        + 'Status reset to <b>PLANNED</b>\n'
        + '<i>Seed export from PROD started.</i>';

    case 'promote':
      // ADR-108 §6: an exact event code; promote.yml answers a prefix with the matching codes.
      triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'), 'promote.yml', { event_code: arg });
      return '<b>Promotion Triggered</b>\n'
        + '<pre>' + arg + '</pre>\n'
        + '<i>The verified CERT run will be replayed on PROD.\nWatch for the result notification.</i>';

    // --- Review ---
    case 'results':
      var resData = callRpc('fn_event_results_summary', { p_prefix: arg });
      if (!resData || resData.length === 0) return '<b>Results (CERT)</b>\n<pre>' + arg + '</pre>\n<i>No tournaments found</i>';
      var resLines = ['<b>Results (CERT)</b>\n<pre>' + arg + '</pre>'];
      resData.forEach(function(t) {
        resLines.push('\n<b>' + t.category + ' ' + t.gender + ' ' + t.weapon + '</b>  (' + t.participants + ' fencers)');
        if (t.top3) {
          t.top3.forEach(function(f) {
            resLines.push('  ' + f.place + '. ' + f.name);
          });
        }
      });
      return resLines.join('\n');

    case 'pending':
      var pendData = callRpc('fn_event_pending', { p_prefix: arg });
      if (!pendData || pendData.length === 0) return '<b>Pending (CERT)</b>\n<pre>' + arg + '</pre>\n<i>No unresolved matches</i>';
      var pendLines = ['<b>Pending Matches (CERT)</b>\n<pre>' + arg + '</pre>'];
      pendData.forEach(function(p) {
        pendLines.push('\n<code>' + p.scraped_name + '</code>');
        pendLines.push('  Suggested: ' + (p.suggested_fencer || '—') + ' (' + (p.confidence || 0) + '%)');
        pendLines.push('  <i>' + p.tournament + '</i>');
      });
      return pendLines.join('\n');

    case 'missing':
      var missData = callRpc('fn_event_missing_categories', { p_prefix: arg });
      if (!missData || missData.length === 0) return '<b>Missing Categories (CERT)</b>\n<pre>' + arg + '</pre>\n<i>All categories have results</i>';
      var missLines = ['<b>Missing Categories (CERT)</b>\n<pre>' + arg + '</pre>'];
      missData.forEach(function(m) {
        missLines.push('  ' + m.category + ' ' + m.gender + ' ' + m.weapon);
      });
      return missLines.join('\n');

    // --- Season ---
    case 'season':
      var seasonData = callRpc('fn_season_overview', {});
      if (!seasonData || seasonData.length === 0) return '<b>Season Overview (CERT)</b>\n<i>No events found</i>';
      var seasonLines = ['<b>Season Overview (CERT)</b>'];
      seasonData.forEach(function(e) {
        var status = e.status || 'PLANNED';
        var intl = e.is_international ? '  [INT]' : '';
        seasonLines.push('\n<pre>' + e.event_code + '</pre>');
        seasonLines.push('<b>' + status + '</b>' + intl);
        seasonLines.push((e.event_name || '') + (e.dt_start ? '  |  ' + e.dt_start : ''));
        seasonLines.push('Tournaments: ' + (e.tournament_count || 0) + '  |  Results: ' + (e.result_count || 0));
      });
      // Summary totals
      var summary = callRpc('fn_season_summary', {});
      if (summary) {
        seasonLines.push('\n<b>Summary</b>');
        seasonLines.push('Fencers: <b>' + (summary.fencers || 0) + '</b>');
        seasonLines.push('Tournaments: <b>' + (summary.tournaments || 0) + '</b>');
        seasonLines.push('Results: <b>' + (summary.results || 0) + '</b>  |  Scored: <b>' + (summary.scored || 0) + '</b>');
      }
      return seasonLines.join('\n');

    case 'ranking':
      var rParts = arg.toUpperCase().split(/\s+/);
      if (rParts.length < 3) return '<b>Usage</b>\n<pre>ranking V2 M EPEE</pre>\n<i>category  gender  weapon</i>';
      var rankData = callRpc('fn_category_ranking', {
        p_weapon: rParts[2], p_gender: rParts[1], p_category: rParts[0]
      });
      if (!rankData || rankData.length === 0) return '<b>Ranking ' + arg + '</b>\n<i>No results found</i>';
      var rankLines = ['<b>Ranking ' + rParts[0] + ' ' + rParts[1] + ' ' + rParts[2] + ' (CERT)</b>\n<i>Top 5 by PPW/MPW points only</i>'];
      rankData.forEach(function(r, i) {
        rankLines.push('\n<pre>' + (i + 1) + '. ' + r.fencer + '</pre>' + r.total_score + ' pts');
      });
      return rankLines.join('\n');

    // --- Ingestion ---
    case 'ingest':
      // ingest <EVENT-CODE> → re-ingest ONE event on CERT from the event's own URL
      // (tbl_event.url_event, set in Admin) via ingest-event.yml (a recorded run); the
      // staging report (full + diff) comes back to this chat when the run finishes.
      // The bot never sends a URL: a blank url_event input makes the workflow read the
      // stored one. ADR-108: PROD is refused; promote <exact code> replays the CERT run.
      var iParts = arg ? arg.split(/\s+/) : [];
      var iUsage = '<b>Usage</b>\n<pre>ingest &lt;EVENT-CODE&gt;</pre>\n'
                 + '<i>Use the full event code, e.g. PPW5-2025-2026</i>';
      if (iParts.length < 1 || !iParts[0]) return iUsage;
      if (iParts.slice(1).some(function (p) { return /^https?:\/\//.test(p); })) {
        return '<b>No URL</b>\n<i>The URL comes from the event (Admin). Send</i> <pre>ingest ' + iParts[0] + '</pre>';
      }
      var iEvent = iParts[0];                                   // full event code, e.g. PPW5-2025-2026
      var iTarget = (iParts[1] || 'cert').toLowerCase();
      var iYm = iEvent.match(/-(\d{4})-(\d{4})$/);             // season-end year = 2nd group
      if (!iYm) return iUsage;
      if (iTarget === 'prod') {
        return '<b>Not on PROD</b>\n<i>A domestic event reaches PROD only through promote, which replays the verified CERT run. '
             + 'Ingest on CERT, then send</i> <pre>promote ' + iEvent + '</pre>';
      }
      if (iTarget !== 'cert') {
        return '<b>Usage</b>\n<pre>ingest &lt;EVENT-CODE&gt;</pre>\n<i>the target is cert</i>';
      }
      // Dispatch straight to the workflow (like `promote`) — no Management API call,
      // so it does not depend on SUPABASE_ACCESS_TOKEN. ingest_cli matches the exact code.
      triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'),
        'ingest-event.yml', { event_code: iEvent, season_end_year: iYm[2], target: iTarget });
      return '<b>Event Re-ingest Triggered</b>\n'
        + '<pre>' + iEvent + '</pre>\n'
        + 'Target: <b>' + iTarget + '</b>\n'
        + '<i>Re-ingesting from the event\'s own URL.\n'
        + 'Staging report (full + diff) will arrive here when done (~1 min).</i>';

    case 't-scrape':
      triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'), 'scrape-tournament.yml', { tournament_code: arg });
      return '<b>Scrape Tournament (CERT)</b>\n<pre>' + arg + '</pre>\n<i>Scraping results from URL and ingesting...</i>';

    case 'populate-urls':
      triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'), 'populate-urls.yml', { event_code: arg });
      return '<b>Populate URLs (CERT)</b>\n<pre>' + arg + '</pre>\n<i>Discovering tournament result URLs from event page...</i>';

    case 'populate-urls-prod':
      triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'), 'populate-urls.yml', { event_code: arg, target: 'prod' });
      return '<b>Populate URLs (PROD)</b>\n<pre>' + arg + '</pre>\n<i>Discovering tournament URLs on PROD...</i>';

    // --- EVF ---
    case 'evf-cal-import':
      triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'), 'evf-sync.yml', { mode: 'calendar' });
      return '<b>EVF Calendar Import</b>\n<i>Scraping veteransfencing.eu into CERT, then promoting the calendar to PROD. Watch for notification.</i>';

    case 'evf-results-import':
      triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'), 'evf-sync.yml', { mode: 'results', event_code: arg });
      return '<b>EVF Results Import (CERT)</b>\n<pre>' + arg + '</pre>\n<i>Fetching results from EVF API. Watch for notification.</i>';

    case 'evf-status':
      var evfEvents = callRpc('fn_season_overview', {});
      if (!evfEvents || evfEvents.length === 0) return '<b>EVF Status (CERT)</b>\n<i>No events</i>';
      var today = new Date().toISOString().slice(0, 10);
      var evfLines = ['<b>EVF Status (CERT)</b>\n<i>International events missing results:</i>'];
      evfEvents.forEach(function(e) {
        if (e.is_international && e.dt_end && e.dt_end < today && e.result_count === 0) {
          evfLines.push('\n<pre>' + e.event_code + '</pre>');
          evfLines.push(e.event_name + '  |  ' + (e.dt_start || '') + '  |  0 results');
        }
      });
      if (evfLines.length === 1) evfLines.push('\n<i>All past international events have results ✓</i>');
      return evfLines.join('\n');

    // --- PROD read-only commands ---
    case 'status-prod':
      var statusProd = callRpc('fn_event_status', { p_prefix: arg }, props.getProperty('SUPABASE_PROD_REF'));
      return '<b>Event Status (PROD)</b>\n'
        + '<pre>' + (statusProd.event_code || arg) + '</pre>\n'
        + 'Status: <b>' + (statusProd.event_status || '—') + '</b>\n'
        + 'Tournaments: <b>' + (statusProd.tournament_count || 0) + '</b>\n'
        + 'Results: <b>' + (statusProd.result_count || 0) + '</b>\n'
        + 'Pending: <b>' + (statusProd.pending_count || 0) + '</b>';

    case 'results-prod':
      var resProd = callRpc('fn_event_results_summary', { p_prefix: arg }, props.getProperty('SUPABASE_PROD_REF'));
      if (!resProd || resProd.length === 0) return '<b>Results (PROD)</b>\n<pre>' + arg + '</pre>\n<i>No tournaments found</i>';
      var resProdLines = ['<b>Results (PROD)</b>\n<pre>' + arg + '</pre>'];
      resProd.forEach(function(t) {
        resProdLines.push('\n<b>' + t.category + ' ' + t.gender + ' ' + t.weapon + '</b>  (' + t.participants + ' fencers)');
        if (t.top3) {
          t.top3.forEach(function(f) {
            resProdLines.push('  ' + f.place + '. ' + f.name);
          });
        }
      });
      return resProdLines.join('\n');

    case 'evf-status-prod':
      var evfProd = callRpc('fn_season_overview', {}, props.getProperty('SUPABASE_PROD_REF'));
      if (!evfProd || evfProd.length === 0) return '<b>EVF Status (PROD)</b>\n<i>No events</i>';
      var todayP = new Date().toISOString().slice(0, 10);
      var evfProdLines = ['<b>EVF Status (PROD)</b>\n<i>International events missing results:</i>'];
      evfProd.forEach(function(e) {
        if (e.is_international && e.dt_end && e.dt_end < todayP && e.result_count === 0) {
          evfProdLines.push('\n<pre>' + e.event_code + '</pre>');
          evfProdLines.push(e.event_name + '  |  ' + (e.dt_start || '') + '  |  0 results');
        }
      });
      if (evfProdLines.length === 1) evfProdLines.push('\n<i>All past international events have results ✓</i>');
      return evfProdLines.join('\n');

    // --- Seed ---
    case 'export-seed':
      triggerGitHubWorkflow(props.getProperty('GITHUB_PAT'), props.getProperty('GITHUB_REPO'), 'export-seed.yml', { reason: 'manual' });
      return '<b>Seed Export (PROD)</b>\n<i>Exporting the seed from PROD into the repository. Watch for completion notification.</i>';

    // --- Admin ---
    case 'help':
      return [
        '<b>SPWS Ranklist Bot</b>',
        '<i>CERT = test database · PROD = public site</i>',
        '',
        '<b><u>Lifecycle</u></b>',
        '',
        '<pre>status &lt;event&gt;</pre>',
        'Event status and counts on CERT; a prefix works · <code>status PPW1</code>',
        '',
        '<pre>complete &lt;exact code&gt;</pre>',
        'IN_PROGRESS → COMPLETED on CERT only; PROD closes by the daily close after the end date',
        '',
        '<pre>rollback &lt;event&gt;</pre>',
        'Delete the event results and tournaments on CERT, back to PLANNED (active season)',
        '',
        '<pre>promote &lt;exact code&gt;</pre>',
        'Replay the verified CERT run on PROD; a prefix gets the matching codes · <code>promote PPW1-2026-2027</code>',
        '',
        '<b><u>Review</u></b>',
        '',
        '<pre>results &lt;event&gt;</pre>',
        'Top 3 of each tournament on CERT',
        '',
        '<pre>pending &lt;event&gt;</pre>',
        'Fencers whose identity is unresolved, on CERT',
        '',
        '<pre>missing &lt;event&gt;</pre>',
        'Categories with no results yet, on CERT',
        '',
        '<pre>season</pre>',
        'Every event of the active season with counts, plus totals, on CERT',
        '',
        '<pre>ranking &lt;category&gt; &lt;gender&gt; &lt;weapon&gt;</pre>',
        'Top 5 by PPW/MPW points only, on CERT (not the SPWS + EVF+ ranking) · <code>ranking V2 M EPEE</code>',
        '',
        '<b><u>Ingestion</u></b>',
        '',
        '<pre>ingest &lt;EVENT-CODE&gt;</pre>',
        'Re-ingest one event on CERT from the event\'s own URL (set in Admin) as a recorded run; the report comes here. Full code, e.g. PPW1-2026-2027. PROD gets it through promote',
        '',
        '<pre>t-scrape &lt;tournament_code&gt;</pre>',
        'Scrape one international tournament into CERT; a domestic event goes through ingest',
        '',
        '<pre>populate-urls &lt;event&gt;</pre>',
        'Find the tournament result URLs of an event on CERT',
        '',
        '<pre>populate-urls-prod &lt;event&gt;</pre>',
        'Find the tournament result URLs of an event on PROD',
        '',
        '<b><u>EVF</u></b>',
        '',
        '<pre>evf-cal-import</pre>',
        'Scrape the EVF calendar into CERT, then promote the calendar to PROD (also runs daily)',
        '',
        '<pre>evf-results-import &lt;event&gt;</pre>',
        'Import one event results from the EVF API into CERT',
        '',
        '<pre>evf-status</pre>',
        'Past PEW/MEW/MSW events with no results, on CERT',
        '',
        '<b><u>PROD, read only</u></b>',
        '',
        '<pre>status-prod &lt;event&gt;</pre>',
        'Event status and counts on PROD',
        '',
        '<pre>results-prod &lt;event&gt;</pre>',
        'Top 3 of each tournament on PROD',
        '',
        '<pre>evf-status-prod</pre>',
        'Past PEW/MEW/MSW events with no results, on PROD',
        '',
        '<b><u>Seed</u></b>',
        '',
        '<pre>export-seed</pre>',
        'Export the seed files from PROD into the repository',
        '',
        '<i>Database commands use the Supabase token in Script Properties; "Unauthorized" means it is stale.</i>',
      ].join('\n');

    default:
      return 'Unknown command: <code>' + command + '</code>\n<i>Send</i> <code>help</code> <i>for available commands.</i>';
  }
}


// ═══════════════════════════════════════════════════════════════
// SUPABASE HELPERS
// ═══════════════════════════════════════════════════════════════

function callRpc(fnName, params, overrideRef) {
  // Build SQL call from function name and params
  var paramParts = [];
  for (var k in params) {
    var v = params[k];
    if (typeof v === 'string') {
      paramParts.push(k + " := '" + v.replace(/'/g, "''") + "'");
    } else if (v === null || v === undefined) {
      paramParts.push(k + ' := NULL');
    } else {
      paramParts.push(k + ' := ' + v);
    }
  }
  var sql = 'SELECT ' + fnName + '(' + paramParts.join(', ') + ')';

  // Use Management API (bypasses PostgREST restrictions); CERT unless a ref is given.
  var props = PropertiesService.getScriptProperties();
  var accessToken = props.getProperty('SUPABASE_ACCESS_TOKEN');
  var projectRef = overrideRef || props.getProperty('SUPABASE_PROJECT_REF');

  var endpoint = 'https://api.supabase.com/v1/projects/' + projectRef + '/database/query';
  var response = UrlFetchApp.fetch(endpoint, {
    method: 'post',
    headers: {
      'Authorization': 'Bearer ' + accessToken,
      'Content-Type': 'application/json',
    },
    payload: JSON.stringify({ query: sql }),
    muteHttpExceptions: true,
  });

  if (response.getResponseCode() === 401) {
    throw new Error('Unauthorized: SUPABASE_ACCESS_TOKEN in Script Properties is stale or missing. '
      + 'Replace it (operator runbooks, "Change the Telegram bot").');
  }
  if (response.getResponseCode() >= 400) {
    throw new Error(response.getContentText());
  }

  var rows = JSON.parse(response.getContentText());
  if (rows && rows.length > 0) {
    // Extract the function result from the first row's first column
    var firstKey = Object.keys(rows[0])[0];
    return rows[0][firstKey];
  }
  return null;
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
    payload: { chat_id: chatId, text: message, parse_mode: 'HTML' },
    muteHttpExceptions: true,
  });
}


// ═══════════════════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════════════════

/**
 * Run once after pasting: removes every existing trigger (including the retired
 * e-mail check's) and sets up the 5-minute Telegram polling trigger.
 */
function createTimeTrigger() {
  ScriptApp.getProjectTriggers().forEach(function(t) { ScriptApp.deleteTrigger(t); });
  ScriptApp.newTrigger('checkTelegramCommands')
    .timeBased()
    .everyMinutes(5)
    .create();
}
