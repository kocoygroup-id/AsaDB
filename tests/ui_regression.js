// Copyright (C) 2026 Kocoy Group and AsaDB contributors
// SPDX-License-Identifier: GPL-3.0-only
'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'web', 'index.html'), 'utf8');
const app = fs.readFileSync(path.join(root, 'web', 'assets', 'app.js'), 'utf8');
const legacyApp = fs.readFileSync(path.join(root, 'web', 'assets', 'app.legacy.js'), 'utf8');
const appLoader = fs.readFileSync(path.join(root, 'web', 'assets', 'app-loader.js'), 'utf8');
const css = fs.readFileSync(path.join(root, 'web', 'assets', 'style.css'), 'utf8');
const webBackend = fs.readFileSync(path.join(root, 'src', 'asadb_web.pl'), 'utf8');
const realtimeContract = fs.readFileSync(path.join(root, 'scripts', 'realtime_release_contract.txt'), 'utf8');
const japaneseFontWoff2 = path.join(root, 'web', 'assets', 'fonts', 'noto-sans-jp-japanese-400-normal.woff2');
const japaneseFontWoff = path.join(root, 'web', 'assets', 'fonts', 'noto-sans-jp-japanese-400-normal.woff');

const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
assert.equal(ids.length, new Set(ids).size, 'web/index.html contains duplicate element IDs');

const languageButtons = [...html.matchAll(/data-language="([^"]+)"/g)].map(match => match[1]);
assert.deepEqual(languageButtons, ['id', 'ja', 'en'], 'language switcher must expose ID, JP, and EN in that order');

const formatMarker = app.indexOf('const FORMAT_LABELS');
assert.ok(formatMarker > 0, 'could not isolate the i18n dictionary');
const context = {
  localStorage: { getItem: () => null },
};
vm.runInNewContext(`${app.slice(0, formatMarker)}\nthis.__I18N = I18N;`, context);
const i18n = context.__I18N;
assert.deepEqual(Object.keys(i18n).sort(), ['en', 'id', 'ja']);

const translatedKeys = new Set(
  [...html.matchAll(/data-i18n(?:-placeholder|-title|-aria-label)?="([^"]+)"/g)].map(match => match[1]),
);
for (const match of app.matchAll(/\bt\('([^']+)'/g)) translatedKeys.add(match[1]);
for (const language of ['id', 'ja', 'en']) {
  for (const key of translatedKeys) {
    assert.ok(i18n[language][key], `${language} is missing translation key ${key}`);
  }
}

for (const requiredKey of [
  'mode.backend',
  'sql.running',
  'database.noneSelected',
  'common.tableKind',
  'common.viewKind',
  'table.dropNamed',
  'result.rowsShown',
  'log.dropVerifyFailed',
]) {
  for (const language of ['id', 'ja', 'en']) {
    assert.ok(i18n[language][requiredKey], `${language} is missing dynamic key ${requiredKey}`);
  }
}

assert.match(app, /addEventListener\('paste'/, 'SQL editor must handle paste explicitly');
assert.match(app, /insertFromPaste/, 'SQL editor must recognize paste input events');
assert.match(app, /restoreSqlViewport/, 'SQL editor must restore its viewport after rerender');
assert.match(app, /executeBackendSqlPage/, 'SQL result paging request helper is missing');
assert.match(app, /loadMoreResultPage/, 'SQL result Show-more handler is missing');
assert.match(app, /IntersectionObserver/, 'table chooser must reveal more rows at the scroll boundary');
assert.match(html, /id="sqlLineNumbersContent"/, 'large SQL line-number gutter needs a scrollable content layer');
assert.match(app, /sqlLineNumbersContent\.style\.paddingTop/, 'large SQL gutter padding must live inside the scrollable content layer');
assert.match(css, /\.table-show-more/, 'table Show-more styling is missing');
assert.match(webBackend, /asadb_exec_sql_page/, 'backend SQL page executor is missing');
assert.match(webBackend, /query_page_offset/, 'backend SQL offset validation is missing');
assert.match(css, /overflow-anchor:\s*none/, 'SQL editor must disable browser scroll anchoring');
assert.match(css, /overscroll-behavior:\s*contain/, 'SQL editor must contain overscroll');
assert.match(css, /scrollbar-gutter:\s*stable/, 'SQL editor must reserve stable scrollbar space');
assert.match(css, /\.language-button\.active/, 'active language styling is missing');
assert.match(css, /@font-face[\s\S]*font-family:\s*"AsaDB Noto Sans JP"/, 'bundled Japanese web font is missing');
assert.match(css, /html:lang\(ja\)[\s\S]*--font-main:\s*"AsaDB Noto Sans JP"/, 'Japanese UI must select its bundled font');
assert.ok(fs.statSync(japaneseFontWoff2).size > 900_000, 'Japanese WOFF2 font is missing or truncated');
assert.ok(fs.statSync(japaneseFontWoff).size > 1_200_000, 'old-Firefox Japanese WOFF fallback is missing or truncated');

const startupDelayMatch = /const STARTUP_WARMUP_MS = (\d+);/.exec(app);
assert.ok(startupDelayMatch, 'startup loader delay is missing');
assert.ok(Number(startupDelayMatch[1]) <= 800, 'startup loader may block the panel for too long');
const startupSource = app.slice(app.indexOf('function runStartupWarmup'), app.indexOf('async function checkEngine'));
assert.match(startupSource, /startupDelay\(STARTUP_WARMUP_MS\)\.then\(hideStartupLoader\)/, 'startup loader must close after its compact visual cue');
assert.doesNotMatch(startupSource, /warmupBackendRuntime/, 'startup must not repeat backend warmup after server boot');
assert.match(css, /\.startup-loader[\s\S]*pointer-events:\s*none/, 'startup overlay must never intercept clicks');
assert.match(app, /window\.__asadbUiReady\s*=\s*true/, 'app must signal that event listeners finished booting');
assert.match(appLoader, /assets\/app\.legacy\.js/, 'browser-safe loader must load the legacy-compatible bundle');
assert.match(appLoader, /window\.NodeList.*prototype/, 'browser-safe loader must polyfill NodeList.forEach for old Firefox');
assert.match(legacyApp, /window\.__asadbUiReady\s*=\s*true/, 'legacy bundle must include the UI-ready marker');
assert.doesNotMatch(legacyApp, /\?\./, 'legacy bundle must not use optional chaining');
assert.doesNotMatch(legacyApp, /\?\?(?![=])/, 'legacy bundle must not use nullish coalescing');
assert.doesNotMatch(legacyApp, /(?:\|\|=|&&=|\?\?=)/, 'legacy bundle must not use logical assignment syntax');
assert.doesNotMatch(legacyApp, /\basync\b|\bawait\b|=>/, 'legacy bundle must not require Firefox async/arrow-function syntax');
assert.doesNotMatch(app, /STARTUP_WARMUP_MS\s*=\s*3500/, 'obsolete 3.5-second startup delay returned');

for (const line of realtimeContract.split(/\r?\n/)) {
  if (!line || line.startsWith('#')) continue;
  const separator = line.indexOf('|');
  assert.ok(separator > 0, `invalid realtime release contract line: ${line}`);
  const scope = line.slice(0, separator);
  const marker = line.slice(separator + 1);
  if (scope === 'bundle') {
    assert.ok(app.includes(marker), `modern bundle is missing realtime contract marker: ${marker}`);
    assert.ok(legacyApp.includes(marker), `legacy bundle is missing realtime contract marker: ${marker}`);
  } else if (scope === 'markup') {
    assert.ok(html.includes(marker), `panel markup is missing realtime contract marker: ${marker}`);
  } else if (scope === 'backend') {
    assert.ok(webBackend.includes(marker), `web backend is missing realtime contract marker: ${marker}`);
  } else {
    assert.fail(`unknown realtime release contract scope: ${scope}`);
  }
}

assert.match(html, /<section[^>]+id="importProgressPanel"[^>]+aria-live="polite"[^>]+hidden/,
  'Reservoir progress must be a non-blocking live region');
assert.match(html, /<progress[^>]+id="importProgressBar"[^>]+max="100"/,
  'Reservoir progress must expose a native 0-100 progress element');
assert.match(html, /<button[^>]+id="importCancelBtn"[^>]+type="button"[^>]+disabled/,
  'Reservoir cancel must start disabled and must not submit an unrelated form');
assert.match(css, /\.import-progress-panel\[hidden\]\s*\{\s*display:\s*none/,
  'hidden Reservoir progress must not leave a broken panel shell');

const reservoirSubmitSource = app.slice(
  app.indexOf('async function submitReservoirPayload'),
  app.indexOf('async function startReservoirFile'),
);
const reservoirSubmitActivateIndex = reservoirSubmitSource.indexOf('activateReservoirJob(admission.job_id');
const reservoirSubmitWaitIndex = reservoirSubmitSource.indexOf('waitForReservoirJob(admission.job_id');
assert.ok(
  reservoirSubmitActivateIndex >= 0 && reservoirSubmitActivateIndex < reservoirSubmitWaitIndex,
  'raw Reservoir admission must be persisted before polling begins',
);
const reservoirFileSource = app.slice(
  app.indexOf('async function startReservoirFile'),
  app.indexOf('async function waitForReservoirJob'),
);
const reservoirFileActivateIndex = reservoirFileSource.indexOf('activateReservoirJob(admission.job_id');
const reservoirFileWaitIndex = reservoirFileSource.indexOf('waitForReservoirJob(admission.job_id');
assert.ok(
  reservoirFileActivateIndex >= 0 && reservoirFileActivateIndex < reservoirFileWaitIndex,
  'server-file Reservoir admission must be persisted before polling begins',
);

const reservoirDiscoverySource = app.slice(
  app.indexOf('async function discoverActiveReservoirJob'),
  app.indexOf('async function finalizeResumedReservoirJob'),
);
assert.match(reservoirDiscoverySource, /fetchReservoirJobSnapshot\(stored\.id\)/,
  'reload recovery must resume the exact persisted job first');
assert.match(reservoirDiscoverySource, /fetch\('\/api\/reservoir\/jobs',\s*\{\s*cache:\s*'no-store'/,
  'reload recovery must fall back to the backend active-job list without cache');
const reservoirCancelSource = app.slice(
  app.indexOf('async function cancelActiveReservoirJob'),
  app.indexOf('async function fetchReservoirJobSnapshot'),
);
assert.match(reservoirCancelSource, /fetch\(`\/api\/reservoir\/cancel\?id=\$\{encodeURIComponent\(jobId\)\}`[\s\S]*method:\s*'POST'/,
  'the reload-safe cancel control must POST the encoded active job ID');
assert.match(app, /importCancelBtn\.addEventListener\('click',\s*cancelActiveReservoirJob\)/,
  'the Reservoir cancel control must be wired after boot');
const engineCheckSource = app.slice(app.indexOf('async function checkEngine'), app.indexOf('function showView'));
assert.match(engineCheckSource, /resumeActiveReservoirJob\(\)/,
  'backend boot must resume Reservoir monitoring after a panel reload');

const metadataRefreshSource = app.slice(
  app.indexOf('function refreshDatabaseMetadata'),
  app.indexOf('function renderDatabaseMetadata'),
);
assert.match(metadataRefreshSource, /if \(metadataRefreshPromise\) return metadataRefreshPromise/,
  'metadata refresh must be single-flight');
assert.match(metadataRefreshSource, /fetch\('\/api\/metadata',\s*\{\s*cache:\s*'no-store'/,
  'live metadata must bypass the browser HTTP cache');
assert.match(metadataRefreshSource, /document\.visibilityState\s*!==\s*'hidden'/,
  'metadata polling must avoid network requests while the panel is hidden');
assert.match(app, /document\.addEventListener\('visibilitychange'[\s\S]*scheduleMetadataPoll\(0\)/,
  'metadata polling must refresh as soon as the panel becomes visible');
for (const [name, maximum] of [
  ['METADATA_ACTIVE_POLL_INTERVAL_MS', 1000],
  ['METADATA_OPEN_POLL_INTERVAL_MS', 2000],
  ['METADATA_IDLE_POLL_INTERVAL_MS', 10000],
]) {
  const match = new RegExp(`const ${name} = (\\d+);`).exec(app);
  assert.ok(match, `${name} is missing`);
  assert.ok(Number(match[1]) <= maximum, `${name} is too slow for live metadata`);
}
assert.match(app, /active:\s*formatNumber\(reservoir\.active\b/,
  'metadata must render all active receiving/queued/processing jobs');

const saveButtonIndex = html.indexOf('id="saveDbBtn"');
const dropButtonIndex = html.indexOf('id="dropDbBtn"');
const languageSwitcherIndex = html.indexOf('id="languageSwitcher"');
assert.ok(saveButtonIndex >= 0 && dropButtonIndex > saveButtonIndex && languageSwitcherIndex > dropButtonIndex,
  'language controls must sit after the Save and Delete database buttons');
assert.match(html, /assets\/app-loader\.js/, 'index must load the compatibility-safe panel entry point');
assert.match(html, /rel="icon"[^>]+assets\/asadb-logo\.png/, 'index must declare an existing favicon');
assert.match(webBackend, /assets\/app-loader\.js/, 'web backend must serve the compatibility-safe loader');
assert.match(webBackend, /assets\/app\.legacy\.js/, 'web backend must serve the legacy UI bundle');
assert.match(webBackend, /root\('favicon\.ico'\)/, 'web backend must handle legacy browser favicon requests');
assert.match(webBackend, /assets\/fonts\/noto-sans-jp-japanese-400-normal\.woff2/, 'web backend must serve bundled Japanese WOFF2');
assert.match(webBackend, /assets\/fonts\/noto-sans-jp-japanese-400-normal\.woff/, 'web backend must serve old-Firefox Japanese WOFF fallback');
assert.match(webBackend, /api_reservoir_jobs\(Request\)\s*:-\s*\n\s*member\(method\(get\), Request\)/,
  'backend must expose reload recovery through GET /api/reservoir/jobs');
assert.match(webBackend, /reservoir_jobs\{count:Count,jobs:Snapshots\}/,
  'active-job recovery response must expose count and snapshot list');
const textAssetSource = webBackend.slice(
  webBackend.indexOf('serve_file_body(Path, Type) :-'),
  webBackend.indexOf('serve_binary_file(Path, Type) :-')
);
assert.match(textAssetSource, /open\(Path, read, In, \[encoding\(utf8\)\]\)/,
  'UTF-8 UI assets must be opened as UTF-8 text');
assert.match(textAssetSource, /copy_stream_data\(In, current_output\)/,
  'UTF-8 UI assets must be streamed once to the HTTP output');
assert.doesNotMatch(textAssetSource, /type\(binary\)/,
  'UTF-8 UI assets must not be copied as binary bytes to a text HTTP stream');

const dropTableSource = app.slice(app.indexOf('async function dropTable'), app.indexOf('function showCreateTableView'));
assert.match(dropTableSource, /hasResultError\(data\)/, 'DROP TABLE must preserve the local catalog on SQL errors');
assert.match(dropTableSource, /backendListContains\('SHOW TABLES;'/, 'DROP TABLE must verify backend deletion');
assert.ok(
  dropTableSource.indexOf('hasResultError(data)') < dropTableSource.indexOf('delete sandbox.dbs'),
  'DROP TABLE deletes browser state before checking the backend result',
);
const dropDatabaseSource = app.slice(app.indexOf('async function dropCurrentDatabase'), app.indexOf('function focusSqlCommand'));
assert.match(dropDatabaseSource, /backendListContains\('SHOW DATABASES;'/, 'DROP DATABASE must verify backend deletion');
assert.match(app, /if \(!rows\.length\) \{\s*sandbox = normalizeSandbox\(\{ currentDb: '', dbs: \{\}, views: \{\} \}\)/, 'empty backend catalogs must clear stale browser objects');

assert.doesNotMatch(webBackend, /'Stress Test'/, 'Linux backend must not depend on a Windows-only directory case');
assert.doesNotMatch(webBackend, /atom_concat\('Test\//, 'legacy test paths must not resolve to a missing Test directory');
assert.match(
  webBackend,
  /atomic_list_concat\(\['test', Name\].*?stress_import_file\(Name, File\)/s,
  'historical test/... imports must resolve through the canonical stress tests directory',
);
assert.doesNotMatch(app, /stress tests, Test, or web\/samples/, 'UI guidance must use canonical Linux path casing');

console.log(`UI regression checks passed (${translatedKeys.size} static translation keys, 3 languages).`);
