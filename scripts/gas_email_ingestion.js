/**
 * Google Apps Script: Email Ingestion for SPWS Ranklist (ADR-023)
 *
 * Polls spws.weterani@gmail.com every 5 minutes for emails with
 * .zip/.xml attachments, uploads to Supabase Storage staging/,
 * then triggers the GitHub Actions ingest.yml workflow.
 *
 * Setup (Script Properties):
 *   SUPABASE_URL           — Supabase project URL
 *   SUPABASE_SERVICE_ROLE_KEY — service_role key (bypasses RLS)
 *   GITHUB_PAT             — GitHub personal access token (workflow_dispatch scope)
 *   GITHUB_REPO            — owner/repo (e.g. "user/SPWSranklist")
 *   TELEGRAM_BOT_TOKEN     — Telegram bot token (optional, for GAS-side alerts)
 *   TELEGRAM_CHAT_ID       — Telegram chat ID (optional)
 *
 * Deploy:
 *   1. Create GAS project linked to spws.weterani@gmail.com
 *   2. Set Script Properties above
 *   3. Run createTimeTrigger() once to start 5-minute polling
 */

function checkEmailForResults() {
  var props = PropertiesService.getScriptProperties();
  var supabaseUrl = props.getProperty('SUPABASE_URL');
  var supabaseKey = props.getProperty('SUPABASE_SERVICE_ROLE_KEY');
  var githubPat = props.getProperty('GITHUB_PAT');
  var githubRepo = props.getProperty('GITHUB_REPO');

  // Search for unread emails with attachments
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
    // Label as processed
    var label = GmailApp.getUserLabelByName('PROCESSED');
    if (!label) label = GmailApp.createLabel('PROCESSED');
    threads[t].addLabel(label);
  }

  if (uploadedCount > 0) {
    // Notify via Telegram
    sendTelegramAlert(props, 'New files uploaded to staging: ' + uploadedCount + ' file(s)');

    // Trigger GitHub Actions workflow
    triggerGitHubWorkflow(githubPat, githubRepo);
  }
}

function uploadToSupabaseStorage(url, key, path, bytes, contentType) {
  var endpoint = url + '/storage/v1/object/xml-inbox/' + path;
  var options = {
    method: 'post',
    headers: {
      'Authorization': 'Bearer ' + key,
      'apikey': key,
      'Content-Type': contentType || 'application/octet-stream',
    },
    payload: bytes,
    muteHttpExceptions: true,
  };
  var response = UrlFetchApp.fetch(endpoint, options);
  if (response.getResponseCode() >= 400) {
    throw new Error('Storage upload failed: ' + response.getContentText());
  }
}

function triggerGitHubWorkflow(pat, repo) {
  var url = 'https://api.github.com/repos/' + repo + '/actions/workflows/ingest.yml/dispatches';
  var options = {
    method: 'post',
    headers: {
      'Authorization': 'token ' + pat,
      'Accept': 'application/vnd.github.v3+json',
    },
    payload: JSON.stringify({ ref: 'main', inputs: { source: 'gas' } }),
    contentType: 'application/json',
    muteHttpExceptions: true,
  };
  var response = UrlFetchApp.fetch(url, options);
  if (response.getResponseCode() >= 400) {
    throw new Error('GitHub dispatch failed: ' + response.getContentText());
  }
}

function sendTelegramAlert(props, message) {
  var token = props.getProperty('TELEGRAM_BOT_TOKEN');
  var chatId = props.getProperty('TELEGRAM_CHAT_ID');
  if (!token || !chatId) return;

  var url = 'https://api.telegram.org/bot' + token + '/sendMessage';
  UrlFetchApp.fetch(url, {
    method: 'post',
    payload: { chat_id: chatId, text: message, parse_mode: 'Markdown' },
    muteHttpExceptions: true,
  });
}

/**
 * Run once to set up the 5-minute polling trigger.
 */
function createTimeTrigger() {
  ScriptApp.newTrigger('checkEmailForResults')
    .timeBased()
    .everyMinutes(5)
    .create();
}