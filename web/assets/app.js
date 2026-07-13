// Copyright (C) 2026 Kocoy Group and AsaDB contributors
// SPDX-License-Identifier: GPL-3.0-only
const $ = (id) => document.getElementById(id);

const DEFAULT_DB = '';
const SAMPLE_DB = 'demo';
const SANDBOX_STORAGE_KEY = 'asadb-sandbox-v2';
const LEGACY_SANDBOX_STORAGE_KEY = 'asadb-sandbox';
const DEFAULT_TABLES = [];
const BACKEND_FULL_SYNC_ROW_LIMIT = 5000;
const BROWSER_SQL_IMPORT_LIMIT_BYTES = 512 * 1024;
const BACKEND_UPLOAD_IMPORT_MIN_BYTES = 128 * 1024;
const STARTUP_WARMUP_MS = 3500;

const FORMAT_LABELS = {
  asadb: 'AsaDB',
  csv: 'CSV',
  xlsx: 'XLSX',
  postgresql: 'PostgreSQL',
  mysql: 'MySQL',
};

const startupLoader = $('startupLoader');

const ASA_OK_LABEL = 'Asa Terima \uD83D\uDE33';
const ASA_ERROR_LABEL = 'Asa Tidak Suka! \uD83D\uDE21';
const ASA_CORRECTION_LABEL = 'Asa Mau Koreksi \uD83E\uDD14';
const ASA_RUN_SOUNDS = {
  ok: [
    'assets/Effect/Berhasil/1.mp3',
    'assets/Effect/Berhasil/2.mp3',
    'assets/Effect/Berhasil/3.mp3',
    'assets/Effect/Berhasil/4.mp3',
  ],
  error: [
    'assets/Effect/Gagal/1g.mp3',
    'assets/Effect/Gagal/2g.mp3',
    'assets/Effect/Gagal/3g.mp3',
    'assets/Effect/Gagal/4g.mp3',
  ],
};

const asaRunSoundState = {
  ok: -1,
  error: -1,
};
const asaRunAudioCache = {
  ok: [],
  error: [],
};
let asaRunPrimeAudio = null;

const ASA_ERROR_OPENERS = [
  'Asa berhenti dulu, ada bagian yang belum nyambung.',
  'Asa nyangkut di sini, tapi masih bisa dibenerin.',
  'Asa belum bisa nerima bentuk ini.',
  'Asa membaca ini sebagai jalur buntu.',
  'Asa curiga ada yang kelewat.',
  'Asa belum nemu pegangan buat perintah ini.',
  'Asa tahan dulu eksekusinya.',
  'Asa lihat ada bagian yang belum siap jalan.',
  'Asa belum sepakat sama susunan ini.',
  'Asa minta dicek satu langkah lagi.',
  'Asa belum paham maksud baris ini.',
  'Asa nangkep niatnya, tapi bentuknya masih miring.',
  'Asa belum berani jalanin ini.',
  'Asa perlu versi yang lebih rapi dulu.',
  'Asa kehilangan arah di bagian ini.',
  'Asa nemu tanda yang bikin langkahnya putus.',
  'Asa belum bisa menyambungkan kata-katanya.',
  'Asa minta bagian ini ditata ulang.',
  'Asa belum melihat tujuan perintahnya.',
  'Asa berhenti supaya data kamu tidak salah berubah.',
  'Asa belum dapat nama atau tanda yang dibutuhkan.',
  'Asa membaca ini sebagai perintah yang belum lengkap.',
  'Asa belum bisa menemukan benda yang kamu maksud.',
  'Asa butuh petunjuk yang lebih jelas di sini.',
  'Asa menolak dulu karena hasilnya bisa salah.',
  'Asa merasa urutan katanya belum pas.',
  'Asa belum bisa masuk ke jalur eksekusi.',
  'Asa melihat bentuk SQL ini masih kepeleset.',
  'Asa belum bisa menebak ini dengan aman.',
  'Asa stop sebentar, ada yang perlu diberesin.',
  'Asa belum nemu pasangan kata yang cocok.',
  'Asa bilang ini belum jadi kalimat SQL yang utuh.',
];

const ASA_CORRECTION_OPENERS = [
  'Asa punya tebakan kecil.',
  'Asa mau rapihin sedikit.',
  'Asa lihat ini hampir benar.',
  'Asa curiga ini cuma salah ketik.',
  'Asa bisa bantu lurusin.',
  'Asa nemu bagian yang bisa dipoles.',
  'Asa punya saran yang lebih aman.',
  'Asa ingin ganti satu potongan kecil.',
  'Asa menangkap maksudmu.',
  'Asa rasa ini tinggal disetel.',
  'Asa bisa bikin ini lebih kebaca.',
  'Asa mau usul bentuk yang lebih pas.',
  'Asa melihat jalannya, tinggal dirapikan.',
  'Asa punya koreksi halus.',
  'Asa hampir setuju, kurang satu sentuhan.',
  'Asa mau bantu sebelum dijalankan.',
  'Asa lihat ada tanda yang perlu ditutup.',
  'Asa baca ini sebagai SQL yang belum selesai.',
  'Asa punya cara supaya ini tidak nyasar.',
  'Asa kasih bisikan kecil dulu.',
];

const ASA_SUCCESS_OPENERS = [
  'Asa nerima ini dengan manis.',
  'Asa sudah jalanin dan hasilnya aman.',
  'Asa setuju, perintahnya masuk.',
  'Asa sudah simpan langkahnya.',
  'Asa berhasil menyelesaikan bagian ini.',
  'Asa jalan pelan dan sampai.',
  'Asa menerima bentuk SQL ini.',
  'Asa sudah pegang hasilnya.',
  'Asa mengangguk, ini valid.',
  'Asa sudah beresin sesuai permintaan.',
  'Asa suka yang ini, rapi.',
  'Asa sudah mengubah data dengan aman.',
  'Asa selesai tanpa protes.',
  'Asa berhasil membaca niatmu.',
  'Asa sudah kunci hasilnya.',
  'Asa bilang ini boleh lewat.',
];

const sqlInput = $('sqlInput');
const sqlEditor = $('sqlEditor');
const sqlHighlight = $('sqlHighlight');
const sqlLineNumbers = $('sqlLineNumbers');
const sqlDiagnostics = $('sqlDiagnostics');
const resultBox = $('resultBox');
const runBtn = $('runBtn');
const logBox = $('logBox');
const engineStatus = $('engineStatus');
const lastRun = $('lastRun');
const dbName = $('dbName');
const dbSelect = $('dbSelect');
const saveDbBtn = $('saveDbBtn');
const dropDbBtn = $('dropDbBtn');
const tableList = $('tableList');
const tableSearch = $('tableSearch');
const tableCount = $('tableCount');
const pageTitle = $('pageTitle');

const views = {
  sql: $('sqlView'),
  import: $('importView'),
  export: $('exportView'),
  table: $('tableView'),
  create: $('createTableView'),
};

const viewButtons = {
  sql: $('sqlCommandBtn'),
  import: $('importViewBtn'),
  export: $('exportViewBtn'),
};

const importFileInput = $('importFileInput');
const importFormat = $('importFormat');
const importExecuteBtn = $('importExecuteBtn');
const importServerPath = $('importServerPath');
const importRunServerBtn = $('importRunServerBtn');
const importStopOnError = $('importStopOnError');
const importShowOnlyErrors = $('importShowOnlyErrors');
const importWriteMode = $('importWriteMode');
const importTargetTable = $('importTargetTable');
const importSummary = $('importSummary');

const exportDbName = $('exportDbName');
const exportDatabaseMode = $('exportDatabaseMode');
const exportTableMode = $('exportTableMode');
const exportDataMode = $('exportDataMode');
const exportAllTables = $('exportAllTables');
const exportAllData = $('exportAllData');
const exportTableRows = $('exportTableRows');
const exportRunBtn = $('exportRunBtn');
const exportPreview = $('exportPreview');

const tableDetailName = $('tableDetailName');
const tableSelectDataBtn = $('tableSelectDataBtn');
const tableShowStructureBtn = $('tableShowStructureBtn');
const tableAlterBtn = $('tableAlterBtn');
const tableNewItemBtn = $('tableNewItemBtn');
const tableDropBtn = $('tableDropBtn');
const tableStructurePanel = $('tableStructurePanel');
const tableStructureBody = $('tableStructureBody');
const tableIndexBody = $('tableIndexBody');
const tableDataPanel = $('tableDataPanel');
const tableDataBox = $('tableDataBox');

const createTableForm = $('createTableForm');
const createTableName = $('createTableName');
const createEngine = $('createEngine');
const createCollation = $('createCollation');
const createColumnsBody = $('createColumnsBody');
const createAddHeaderBtn = $('createAddHeaderBtn');
const createAutoIncrement = $('createAutoIncrement');
const createDefaultValues = $('createDefaultValues');
const createComment = $('createComment');
const createAllAutoIncrement = $('createAllAutoIncrement');
const createAutoIncrementHelpBtn = $('createAutoIncrementHelpBtn');
const autoIncrementHelpPopover = $('autoIncrementHelpPopover');

let backendOnline = false;
let selectedTable = '';
let sandbox = loadSandbox();
let sqlDiagnosticsState = [];
let sqlAnalyzeTimer = 0;
let sqlAnalyzeRequest = 0;
let sqlRunPromise = null;
let activeRunAudio = null;
let asaRunPrimePromise = null;
let archiveRefreshTimer = 0;
let archiveSnapshot = {
  kind: 'idle',
  dataset: '',
  columns: [],
  rows: [],
  rowCount: 0,
  sizeBytes: 0,
  progress: 0,
  updatedAt: 0,
};

function backendToken() {
  const match = document.cookie.match(/(?:^|;\s*)asadb_token=([^;]+)/);
  return match ? decodeURIComponent(match[1]) : '';
}

function apiHeaders(extra = {}) {
  const headers = { ...extra };
  const token = backendToken();
  if (token) headers['X-AsaDB-Token'] = token;
  return headers;
}

const SQL_KEYWORDS = new Set([
  'add', 'all', 'alter', 'and', 'as', 'asc', 'begin', 'between', 'by', 'cascade',
  'check', 'collate', 'column', 'columns', 'commit', 'constraint', 'create',
  'database', 'databases', 'default', 'delete', 'desc', 'describe', 'distinct',
  'drop', 'exists', 'explain', 'for', 'from', 'grant', 'grants', 'group',
  'having', 'identified', 'if', 'in', 'index', 'indexes', 'insert', 'into', 'is',
  'join', 'key', 'keys', 'left', 'like', 'limit', 'lock', 'login', 'not', 'null',
  'offset', 'on', 'or', 'order', 'password', 'primary', 'references', 'revoke',
  'right', 'rollback', 'select', 'set', 'show', 'start', 'table', 'tables', 'to',
  'transaction', 'truncate', 'unique', 'unlock', 'update', 'user', 'use', 'values',
  'where',
]);

const SQL_TYPES = new Set([
  'bigint', 'binary', 'blob', 'bool', 'boolean', 'char', 'character', 'date',
  'datetime', 'decimal', 'double', 'enum', 'float', 'int', 'integer', 'longblob',
  'longtext', 'mediumint', 'mediumtext', 'real', 'smallint', 'text', 'time',
  'timestamp', 'tinyint', 'tinytext', 'unsigned', 'varbinary', 'varchar', 'year',
  'zerofill',
]);

const SQL_FUNCTIONS = new Set(['count', 'max', 'min', 'sum', 'avg', 'now', 'current_timestamp']);

const SQL_INDENT = '\t';

const SQL_CORRECTIONS = {
  addcolumn: 'ADD COLUMN',
  addd: 'ADD',
  altr: 'ALTER',
  altert: 'ALTER',
  alredy: 'ALREADY',
  autoicrement: 'AUTO_INCREMENT',
  autoincremen: 'AUTO_INCREMENT',
  bigintt: 'BIGINT',
  bolean: 'BOOLEAN',
  charcter: 'CHARACTER',
  cerate: 'CREATE',
  creat: 'CREATE',
  creatw: 'CREATE',
  crerate: 'CREATE',
  crate: 'CREATE',
  crete: 'CREATE',
  databsae: 'DATABASE',
  databse: 'DATABASE',
  databeses: 'DATABASES',
  datbase: 'DATABASE',
  del: 'DELETE',
  delet: 'DELETE',
  delte: 'DELETE',
  descibe: 'DESCRIBE',
  descirbe: 'DESCRIBE',
  desribe: 'DESCRIBE',
  distict: 'DISTINCT',
  drp: 'DROP',
  drpo: 'DROP',
  dropp: 'DROP',
  exisit: 'EXISTS',
  exsits: 'EXISTS',
  flase: 'FALSE',
  flaot: 'FLOAT',
  foregin: 'FOREIGN',
  fro: 'FROM',
  frm: 'FROM',
  form: 'FROM',
  gropu: 'GROUP',
  gruop: 'GROUP',
  havng: 'HAVING',
  identifed: 'IDENTIFIED',
  indexs: 'INDEXES',
  inesrt: 'INSERT',
  instert: 'INSERT',
  interger: 'INTEGER',
  intr: 'INT',
  isnt: 'INT',
  itno: 'INTO',
  joim: 'JOIN',
  jon: 'JOIN',
  lefft: 'LEFT',
  limt: 'LIMIT',
  limti: 'LIMIT',
  moddify: 'MODIFY',
  oder: 'ORDER',
  oredr: 'ORDER',
  primari: 'PRIMARY',
  primay: 'PRIMARY',
  primery: 'PRIMARY',
  refereces: 'REFERENCES',
  rigth: 'RIGHT',
  rolback: 'ROLLBACK',
  seelct: 'SELECT',
  slect: 'SELECT',
  selct: 'SELECT',
  selec: 'SELECT',
  selecet: 'SELECT',
  sellect: 'SELECT',
  seting: 'SET',
  shwo: 'SHOW',
  shw: 'SHOW',
  tabel: 'TABLE',
  tbale: 'TABLE',
  teble: 'TABLE',
  talbe: 'TABLE',
  trancate: 'TRUNCATE',
  truancate: 'TRUNCATE',
  ture: 'TRUE',
  udpate: 'UPDATE',
  upadte: 'UPDATE',
  updte: 'UPDATE',
  valuse: 'VALUES',
  vaules: 'VALUES',
  vlues: 'VALUES',
  vlaues: 'VALUES',
  varcahr: 'VARCHAR',
  varchr: 'VARCHAR',
  wher: 'WHERE',
  wheree: 'WHERE',
  whree: 'WHERE',
};

function createInitialSandbox() {
  return { currentDb: '', dbs: {}, views: {} };
}

function createDefaultTable(name) {
  return {
    columns: [
      { name: 'id', type: 'INT' },
      { name: 'created_at', type: 'VARCHAR(32)' },
    ],
    rows: [],
    indexes: [{ name: 'PRIMARY', columns: ['id'] }],
  };
}

function normalizeSandbox(value) {
  if (!value || !value.dbs || typeof value.dbs !== 'object') return createInitialSandbox();
  if (!value.views || typeof value.views !== 'object') value.views = {};
  for (const key of Object.keys(value.dbs)) {
    if (!value.dbs[key] || typeof value.dbs[key] !== 'object') value.dbs[key] = {};
  }
  for (const key of Object.keys(value.views)) {
    if (!value.views[key] || typeof value.views[key] !== 'object') value.views[key] = {};
  }
  const names = visibleDbNames(value);
  if (!value.currentDb || (!value.dbs[value.currentDb] && !value.views[value.currentDb]) || isSystemDb(value.currentDb)) value.currentDb = names[0] || '';
  if (value.currentDb) {
    value.dbs[value.currentDb] ||= {};
    value.views[value.currentDb] ||= {};
  }
  for (const db of Object.values(value.dbs)) {
    for (const [tableName, table] of Object.entries(db || {})) {
      if (DEFAULT_TABLES.includes(tableName) && isGenericDefaultTable(table)) {
        db[tableName] = createDefaultTable(tableName);
        continue;
      }
      table.columns ||= [];
      table.rows ||= [];
      table.indexes ||= [];
      table.columns = table.columns.map(col => typeof col === 'string' ? { name: col, type: 'TEXT' } : col);
      db[tableName] = table;
    }
  }
  for (const views of Object.values(value.views)) {
    for (const [viewName, view] of Object.entries(views || {})) {
      views[viewName] = { name: viewName, query: view?.query || '', columns: view?.columns || [], rows: view?.rows || [], isView: true };
    }
  }
  return value;
}

function isGenericDefaultTable(table) {
  const cols = table?.columns || [];
  const rows = table?.rows || [];
  return rows.length === 0 &&
    cols.length === 2 &&
    (cols[0]?.name || cols[0]) === 'id' &&
    (cols[1]?.name || cols[1]) === 'created_at';
}

function log(message) {
  const time = new Date().toLocaleTimeString();
  logBox.textContent += `[${time}] ${message}\n`;
  logBox.scrollTop = logBox.scrollHeight;
}

function updateArchiveMonitor() {
  return null;
}

function scheduleArchiveRefresh(_delay = 0) {
  return null;
}

function buildArchiveModel() {
  const db = currentDbName();
  const selectedRelation = selectedTable ? currentRelation(selectedTable) : null;
  const selectedSource = selectedRelation ? archiveRelationModel(db, selectedTable, selectedRelation) : null;
  const relation = preferredArchiveRelation();
  const querySnapshot = archiveSnapshot.kind === 'query' ? archiveSnapshot : null;
  const importSnapshot = archiveSnapshot.kind === 'import' ? archiveSnapshot : null;
  const recentActivity = archiveSnapshot.updatedAt && (Date.now() - archiveSnapshot.updatedAt < 12000);
  const source = selectedSource || (recentActivity ? archiveSnapshot : null) || relation || querySnapshot || importSnapshot;
  const columns = source?.columns || [];
  const rows = source?.rows || [];
  const rowCount = Number.isFinite(source?.rowCount) ? source.rowCount : rows.length;
  const sizeBytes = source?.sizeBytes || estimateArchiveSize(source);
  const relationName = source?.name || relation?.name || '';
  const sourceName = source?.dataset || relationName || (db ? `${db}.asa` : 'waiting_for_dataset.sql');
  const titleDb = (db || 'ASADB').toUpperCase();
  const badge = source?.kind === 'import' ? 'IMPORT' : source?.kind === 'query' ? 'QUERY' : source?.kind === 'view' ? 'VIEW' : 'TABLE';
  const progress = source?.progress ?? (rowCount > 0 ? 1 : 0);

  return {
    title: `${titleDb} PUBLIC SAFETY ARCHIVE`,
    badge,
    range: inferArchiveRange(columns, rows),
    dataset: sourceName,
    rows: rowCount,
    sizeBytes,
    engine: backendOnline ? 'Prolog-backed runtime' : 'Browser sandbox runtime',
    feedTitle: `LIVE ${badge} FEED`,
    feedRows: buildArchiveFeedRows(columns, rows),
    progress,
    progressText: `${formatNumber(rowCount)} / ${formatNumber(rowCount || 0)} rows`,
    live: Boolean(db || rows.length || archiveSnapshot.updatedAt),
  };
}

function preferredArchiveRelation() {
  const activeDb = currentDbName();
  if (!activeDb) return null;
  const selected = selectedTable ? currentRelation(selectedTable) : null;
  if (selected) return archiveRelationModel(activeDb, selectedTable, selected);
  const db = sandbox.dbs?.[activeDb] || {};
  const dbViews = sandbox.views?.[activeDb] || {};
  const tableName = Object.keys(db).sort((a, b) => (db[b]?.rows?.length || 0) - (db[a]?.rows?.length || 0) || a.localeCompare(b))[0];
  if (tableName) return archiveRelationModel(activeDb, tableName, { kind: 'table', value: db[tableName] });
  const viewName = Object.keys(dbViews).sort((a, b) => a.localeCompare(b))[0];
  if (viewName) return archiveRelationModel(activeDb, viewName, { kind: 'view', value: dbViews[viewName] });
  return null;
}

function archiveRelationModel(db, name, relation) {
  const value = relation.value || {};
  const columns = (value.columns || []).map(col => col.name || col);
  const rows = relation.kind === 'view'
    ? (value.rows || [])
    : (value.rows || []).map(row => columns.map(column => row?.[column] ?? null));
  const rowCount = Number.isFinite(value.rowCount) ? value.rowCount : rows.length;
  return {
    kind: relation.kind,
    name,
    dataset: `${db}.${name}.${relation.kind === 'view' ? 'view' : 'asa'}`,
    columns,
    rows,
    rowCount,
    sizeBytes: estimateArchiveSize({ columns, rows }),
    progress: rowCount ? 1 : 0,
  };
}

function noteArchiveQuery(results, sql = '') {
  const tableResult = (results || []).find(item => item.status === 'table');
  if (!tableResult) return;
  archiveSnapshot = {
    kind: 'query',
    dataset: inferArchiveDatasetFromSql(sql) || 'query_result.sql',
    columns: tableResult.columns || [],
    rows: tableResult.rows || [],
    rowCount: (tableResult.rows || []).length,
    sizeBytes: estimateArchiveSize(tableResult),
    progress: 1,
    updatedAt: Date.now(),
  };
  updateArchiveMonitor();
  scheduleArchiveRefresh();
}

function noteArchiveImportStart(name, sizeBytes) {
  archiveSnapshot = {
    kind: 'import',
    dataset: name || 'incoming_file.sql',
    columns: ['stage', 'file', 'status'],
    rows: [['read', name || 'file', 'streaming']],
    rowCount: 0,
    sizeBytes: sizeBytes || 0,
    progress: 0.18,
    updatedAt: Date.now(),
  };
  updateArchiveMonitor();
  scheduleArchiveRefresh();
}

function noteArchiveImportComplete(name, sizeBytes, columns, rows, rowCount) {
  archiveSnapshot = {
    kind: 'import',
    dataset: name || 'imported_dataset.sql',
    columns: columns?.length ? columns : ['status', 'dataset', 'rows'],
    rows: rows?.length ? rows : [['loaded', name || 'dataset', rowCount || 0]],
    rowCount: Number.isFinite(rowCount) ? rowCount : (rows || []).length,
    sizeBytes: sizeBytes || estimateArchiveSize({ columns, rows }),
    progress: 1,
    updatedAt: Date.now(),
  };
  updateArchiveMonitor();
  scheduleArchiveRefresh();
}

function noteArchiveSqlProgress(sql, completed, total, label = '') {
  const text = String(label || '').replace(/\s+/g, ' ').trim();
  const verb = text.match(/^([A-Za-z]+(?:\s+[A-Za-z]+)?)/)?.[1] || 'SQL';
  archiveSnapshot = {
    kind: 'import',
    dataset: inferArchiveDatasetFromSql(sql) || 'batched_sql_import.sql',
    columns: ['step', 'statement', 'status'],
    rows: [[completed, verb.toUpperCase(), `${completed}/${total}`]],
    rowCount: completed,
    sizeBytes: new TextEncoder().encode(String(sql || '')).length,
    progress: total ? completed / total : 0,
    updatedAt: Date.now(),
  };
  updateArchiveMonitor();
}

function inferArchiveDatasetFromSql(sql) {
  const text = String(sql || '').replace(/`/g, '').trim();
  const matches = [...text.matchAll(/\b(?:from|into|table|view)\s+([A-Za-z_][\w$]*)/gi)];
  const last = matches[matches.length - 1]?.[1];
  const db = currentDbName();
  if (!last) return db ? `${db}.query.sql` : 'query_result.sql';
  return db ? `${db}.${last}.sql` : `${last}.sql`;
}

function inferArchiveRange(columns, rows) {
  const years = [];
  for (const row of rows || []) {
    const values = Array.isArray(row) ? row : columns.map(column => row?.[column]);
    for (const value of values) {
      const match = String(value ?? '').match(/\b(19\d{2}|20\d{2})\b/);
      if (match) years.push(Number(match[1]));
    }
  }
  if (!years.length) return new Date().getFullYear().toString();
  const min = Math.min(...years);
  const max = Math.max(...years);
  return min === max ? String(min) : `${min}-${max}`;
}

function buildArchiveFeedRows(columns, rows) {
  const sample = (rows || []).slice(-4);
  return sample.map((row, index) => {
    const values = Array.isArray(row) ? row : columns.map(column => row?.[column]);
    const visible = values.slice(0, 4).map(value => value === null || value === undefined ? 'NULL' : String(value));
    return {
      index: String(index + 1).padStart(7, '0'),
      text: visible.join(' | '),
    };
  });
}

function estimateArchiveSize(source) {
  try {
    return new TextEncoder().encode(JSON.stringify({
      columns: source?.columns || [],
      rows: source?.rows || [],
    })).length;
  } catch (_) {
    return 0;
  }
}

function formatBytes(bytes) {
  const value = Number(bytes) || 0;
  if (value < 1024) return `${value} B`;
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(value < 10 * 1024 ? 1 : 0)} KB`;
  if (value < 1024 * 1024 * 1024) return `${(value / (1024 * 1024)).toFixed(value < 10 * 1024 * 1024 ? 1 : 0)} MB`;
  return `${(value / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

function formatNumber(value) {
  return new Intl.NumberFormat('en-US').format(Number(value) || 0);
}

function loadSandbox() {
  try {
    return normalizeSandbox(JSON.parse(localStorage.getItem(SANDBOX_STORAGE_KEY)));
  } catch (_) {
    return createInitialSandbox();
  }
}

function saveSandbox() {
  localStorage.setItem(SANDBOX_STORAGE_KEY, JSON.stringify(sandbox));
}

function isSystemDb(name) {
  return String(name || '').startsWith('__');
}

function visibleDbNames(state = sandbox) {
  const names = new Set([...Object.keys(state?.dbs || {}), ...Object.keys(state?.views || {})]);
  return [...names].filter(name => !isSystemDb(name)).sort((a, b) => a.localeCompare(b));
}

function currentDbName() {
  return sandbox.currentDb && !isSystemDb(sandbox.currentDb) ? sandbox.currentDb : '';
}

function ensureCurrentDb(action = 'melakukan aksi ini') {
  const current = currentDbName();
  if (current) return current;
  log(`Pilih atau buat database dulu sebelum ${action}.`);
  return '';
}

function lineNumberAtIndex(text, index) {
  let line = 1;
  for (let i = 0; i < index && i < text.length; i += 1) if (text[i] === '\n') line += 1;
  return line;
}

function copySqlQuoted(text, start) {
  const quote = text[start];
  let i = start + 1;
  while (i < text.length) {
    if (text[i] === '\\') {
      i += 2;
      continue;
    }
    if (text[i] === quote) {
      i += 1;
      break;
    }
    i += 1;
  }
  return i;
}

function copySqlComment(text, start) {
  if (text.startsWith('/*', start)) {
    const end = text.indexOf('*/', start + 2);
    return end === -1 ? text.length : end + 2;
  }
  const end = text.indexOf('\n', start + 1);
  return end === -1 ? text.length : end;
}

function transformSqlWords(sql, mapWord) {
  let out = '';
  let i = 0;
  while (i < sql.length) {
    if (sql.startsWith('--', i) || sql.startsWith('/*', i) || sql[i] === '#') {
      const end = copySqlComment(sql, i);
      out += sql.slice(i, end);
      i = end;
      continue;
    }
    if (sql[i] === '\'' || sql[i] === '"' || sql[i] === '`') {
      const end = copySqlQuoted(sql, i);
      out += sql.slice(i, end);
      i = end;
      continue;
    }
    if (/[A-Za-z_]/.test(sql[i])) {
      const start = i;
      i += 1;
      while (i < sql.length && /[\w$]/.test(sql[i])) i += 1;
      out += mapWord(sql.slice(start, i), start);
      continue;
    }
    out += sql[i];
    i += 1;
  }
  return out;
}

function correctSqlText(sql) {
  const changes = [];
  const text = transformSqlWords(sql, (word, index) => {
    const replacement = SQL_CORRECTIONS[word.toLowerCase()];
    if (!replacement) return word;
    changes.push({ from: word, to: replacement, line: lineNumberAtIndex(sql, index) });
    return replacement;
  });
  return { text, changes };
}

function applySqlAutoCorrection(force = false) {
  const value = sqlInput.value;
  const cursor = sqlInput.selectionStart ?? value.length;
  const previous = value[cursor - 1] || '';
  if (!force && previous && !/[\s;(),]/.test(previous)) return false;

  const corrected = correctSqlText(value);
  if (!corrected.changes.length || corrected.text === value) return false;

  const beforeCursor = correctSqlText(value.slice(0, cursor)).text;
  sqlInput.value = corrected.text;
  const nextCursor = Math.min(beforeCursor.length, sqlInput.value.length);
  sqlInput.setSelectionRange(nextCursor, nextCursor);
  updateSqlEditor();
  log(`${ASA_CORRECTION_LABEL}: ${corrected.changes.map(x => `${x.from} -> ${x.to}`).join(', ')}.`);
  return true;
}

function highlightSql(sql) {
  let html = '';
  let i = 0;
  while (i < sql.length) {
    if (sql.startsWith('--', i) || sql.startsWith('/*', i) || sql[i] === '#') {
      const end = copySqlComment(sql, i);
      html += `<span class="sql-comment">${escapeHtml(sql.slice(i, end))}</span>`;
      i = end;
      continue;
    }
    if (sql[i] === '\'' || sql[i] === '"' || sql[i] === '`') {
      const end = copySqlQuoted(sql, i);
      const cls = sql[i] === '`' ? 'sql-identifier' : 'sql-string';
      html += `<span class="${cls}">${escapeHtml(sql.slice(i, end))}</span>`;
      i = end;
      continue;
    }
    if (/\d/.test(sql[i])) {
      const start = i;
      i += 1;
      while (i < sql.length && /[\d.]/.test(sql[i])) i += 1;
      html += `<span class="sql-number">${escapeHtml(sql.slice(start, i))}</span>`;
      continue;
    }
    if (/[A-Za-z_]/.test(sql[i])) {
      const start = i;
      i += 1;
      while (i < sql.length && /[\w$]/.test(sql[i])) i += 1;
      const word = sql.slice(start, i);
      const lower = word.toLowerCase();
      const cls = SQL_KEYWORDS.has(lower) ? 'sql-keyword' :
        SQL_TYPES.has(lower) ? 'sql-type' :
        SQL_FUNCTIONS.has(lower) ? 'sql-function' :
        'sql-identifier';
      html += `<span class="${cls}">${escapeHtml(word)}</span>`;
      continue;
    }
    if (/[-+*/%=<>.,;()]/.test(sql[i])) {
      html += `<span class="sql-operator">${escapeHtml(sql[i])}</span>`;
    } else {
      html += escapeHtml(sql[i]);
    }
    i += 1;
  }
  return html || ' ';
}

function parenBalance(sql) {
  let balance = 0;
  let i = 0;
  while (i < sql.length) {
    if (sql.startsWith('--', i) || sql.startsWith('/*', i) || sql[i] === '#') {
      i = copySqlComment(sql, i);
      continue;
    }
    if (sql[i] === '\'' || sql[i] === '"' || sql[i] === '`') {
      i = copySqlQuoted(sql, i);
      continue;
    }
    if (sql[i] === '(') balance += 1;
    if (sql[i] === ')') balance -= 1;
    i += 1;
  }
  return balance;
}

function asaHash(text) {
  const value = String(text || '');
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) {
    hash = ((hash << 5) - hash + value.charCodeAt(i)) | 0;
  }
  return Math.abs(hash);
}

function asaPick(list, seed) {
  if (!list.length) return '';
  return list[asaHash(seed) % list.length];
}

function asaCleanMessage(message) {
  return String(message || '')
    .replace(/^ERROR:\s*/i, '')
    .replace(/^Backend Prolog gagal:\s*/i, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function asaReadableRaw(message) {
  const text = asaCleanMessage(message);
  if (!text || text.length > 150) return '';
  if (/raw\(|kw\(|id\('|feature\(|table_ref\(|select\(|insert\(|update\(|delete\(|\[[^\]]{12,}\]/i.test(text)) return '';
  return text;
}

function asaCode(value) {
  const text = String(value || '').replace(/[`'"]/g, '').trim();
  return text ? `\`${text}\`` : 'itu';
}

function asaFeatureName(message) {
  const feature = /feature\(([^,\)]+)/i.exec(message)?.[1];
  return feature ? feature.replace(/_/g, ' ').toUpperCase() : 'SQL ini';
}

function asaCorrectionPair(message) {
  const text = asaCleanMessage(message);
  let match = /Auto correction tersedia:\s*([A-Za-z_][\w$]*)\s*->\s*([A-Za-z_][\w$]*(?:\s+[A-Za-z_][\w$]*)?)/i.exec(text);
  if (match) return { from: match[1], to: match[2] };
  match = /([A-Za-z_][\w$]*)\s*->\s*([A-Za-z_][\w$]*(?:\s+[A-Za-z_][\w$]*)?)/i.exec(text);
  return match ? { from: match[1], to: match[2] } : null;
}

function asaErrorDetail(message) {
  const text = asaCleanMessage(message);
  let match;

  if (!text) return 'Asa tidak dapat pesan lengkapnya. Coba ulangi dari baris yang baru kamu ubah.';
  if (/select or create a database first|no database|database.*not selected/i.test(text)) {
    return 'Pilih atau buat database dulu. Asa perlu tahu tabelnya tinggal di rumah yang mana.';
  }
  if ((match = /table not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown table\s+([A-Za-z_][\w$]*)/i.exec(text))) {
    return `Tabel ${asaCode(match[1])} belum ada di database aktif. Cek pilihan DB di kiri, atau buat tabelnya dulu.`;
  }
  if ((match = /table_ref\('([^']+)'/i.exec(text))) {
    return `Tabel ${asaCode(match[1])} belum ada di database aktif. Cek pilihan DB di kiri, atau buat tabelnya dulu.`;
  }
  if ((match = /column not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown column\s+([A-Za-z_][\w$]*)/i.exec(text))) {
    return `Kolom ${asaCode(match[1])} belum ada di tabel itu. Cek ejaan nama kolom atau lihat struktur tabelnya dulu.`;
  }
  if ((match = /Statement\s+"?([A-Za-z_][\w$]*)"?\s+belum dikenali/i.exec(text))) {
    return `Pembuka ${asaCode(match[1])} belum Asa kenal. Biasanya ini typo dari CREATE, SELECT, INSERT, UPDATE, DELETE, ALTER, DROP, SHOW, atau DESCRIBE.`;
  }
  if (/belum dikenali|unknown statement|unrecognized/i.test(text)) {
    return 'Perintah pembukanya belum cocok. Coba mulai dengan kata SQL yang umum seperti SELECT, CREATE, INSERT, UPDATE, DELETE, ALTER, DROP, SHOW, atau DESCRIBE.';
  }
  if ((match = /sandbox belum support:\s*(.+)$/i.exec(text))) {
    const firstWords = match[1].slice(0, 90);
    return `Mode sandbox belum bisa menjalankan bentuk ini. Kalau butuh fitur penuh, pastikan Mode Prolog backend online. Asa melihat awalnya: ${firstWords}`;
  }
  if (/belum support|belum aktif|not implemented|feature\(/i.test(text)) {
    return `${asaFeatureName(text)} sudah kebaca, tapi jalur eksekusinya belum dibuka di bagian ini. Pakai bentuk yang lebih sederhana dulu atau jalankan lewat backend Prolog terbaru.`;
  }
  if (/Missing or oversized|oversized|payload|too large|terlalu besar/i.test(text)) {
    return 'Isinya terlalu besar untuk jalur tempel biasa. Pakai menu Import file supaya Asa membaca pelan-pelan, bukan sekali telan.';
  }
  if (/Import file path is not allowed|not found|file.*not/i.test(text)) {
    return 'File import belum ketemu di tempat yang Asa izinkan. Taruh di folder Stress Test, Test, atau web/samples, atau pilih file langsung dari tombol upload.';
  }
  if (/Kurung buka belum ditutup|opening parenthesis/i.test(text)) {
    return 'Ada tanda kurung buka yang belum punya pasangan. Tambahkan ) di bagian yang menutup daftar kolom, VALUES, atau kondisi.';
  }
  if (/Kurung tutup berlebih|closing parenthesis/i.test(text)) {
    return 'Ada tanda ) yang datang terlalu cepat. Hapus satu kurung tutup atau cek pasangan kurung sebelumnya.';
  }
  if (/titik koma|semicolon|terminated/i.test(text)) {
    return 'Kalimat SQL-nya belum ditutup. Tambahkan ; di ujung perintah supaya Asa tahu titik akhirnya.';
  }
  if (/INSERT.*VALUES|butuh VALUES|missing values/i.test(text)) {
    return 'INSERT butuh bagian VALUES. Setelah nama tabel dan kolom, tulis nilai yang mau dimasukkan.';
  }
  if (/UPDATE\b.*SET|missing set/i.test(text)) {
    return 'UPDATE perlu bagian SET. Tulis kolom mana yang mau diganti, baru kondisi WHERE kalau perlu.';
  }
  if (/DELETE\b.*FROM|missing from/i.test(text)) {
    return 'DELETE perlu kata FROM sebelum nama tabel. Asa harus tahu baris dari tabel mana yang mau dihapus.';
  }
  if (/duplicate|already exists|sudah ada/i.test(text)) {
    return 'Nama itu sudah ada. Pakai nama lain, atau hapus yang lama dulu kalau memang mau diganti.';
  }
  if (/permission|forbidden|403|denied/i.test(text)) {
    return 'Aksesnya belum boleh lewat. Cek token panel, user aktif, atau izin database yang sedang dipakai.';
  }
  if (/rollback|rolled back/i.test(text)) {
    return 'Asa membatalkan perubahan supaya data tetap aman. Cek error pertama sebelum coba lagi.';
  }
  if (/HTTP|Failed to fetch|NetworkError|backend/i.test(text)) {
    return 'Panel tidak mendapat jawaban yang rapi dari backend. Cek apakah AsA.exe masih hidup dan mode Prolog backend online.';
  }
  if (/syntax|parse|unexpected|invalid|token|near/i.test(text)) {
    const raw = asaReadableRaw(text);
    return raw
      ? `Susunan katanya belum pas di dekat bagian ini: ${raw}. Cek koma, tanda petik, kurung, dan urutan kata SQL.`
      : 'Susunan katanya belum pas. Cek koma, tanda petik, kurung, dan urutan kata SQL di baris itu.';
  }

  const raw = asaReadableRaw(text);
  return raw
    ? `Asa belum bisa menerima bagian ini. Cek nama tabel, nama kolom, tanda baca, dan urutan katanya. Asa melihat: ${raw}`
    : 'Asa belum bisa menerima bagian ini. Cek nama tabel, nama kolom, tanda baca, dan urutan katanya.';
}

function asaCorrectionDetail(item) {
  const text = asaCleanMessage(item?.message);
  const pair = asaCorrectionPair(text);
  if (pair) return `Kata ${asaCode(pair.from)} kayaknya maksudmu ${asaCode(pair.to)}. Asa bisa rapihin itu otomatis sebelum dijalankan.`;
  if (/titik koma|semicolon|terminated/i.test(text)) return 'Tambahkan ; di ujung perintah. Itu tanda buat Asa bahwa satu kalimat SQL sudah selesai.';
  if (/Kurung buka belum ditutup|opening parenthesis/i.test(text)) return 'Ada kurung buka yang belum ditutup. Cari daftar kolom, VALUES, atau kondisi yang belum punya pasangan ).';
  if (/Kurung tutup berlebih|closing parenthesis/i.test(text)) return 'Ada kurung tutup yang kebanyakan. Coba hapus satu ) di baris itu.';
  if (/INSERT.*VALUES|butuh VALUES|missing values/i.test(text)) return 'Untuk INSERT, setelah nama tabel tulis VALUES lalu isi datanya. Tanpa itu Asa belum tahu apa yang masuk.';
  if (item?.correction) return `Coba bentuk ini: ${item.correction}`;
  return asaErrorDetail(text);
}

function asaSuccessDetail(message) {
  const text = asaCleanMessage(message);
  let match;

  if ((match = /^created_database\(([^)]+)\)/i.exec(text))) return `Database ${asaCode(match[1])} sudah dibuat dan siap dipakai.`;
  if ((match = /^using_database\(([^)]+)\)/i.exec(text))) return `Sekarang Asa bekerja di database ${asaCode(match[1])}.`;
  if ((match = /^dropped_database\(([^)]+)\)/i.exec(text))) return `Database ${asaCode(match[1])} sudah dilepas dari daftar.`;
  if ((match = /^created_table\(([^)]+)\)/i.exec(text))) return `Tabel ${asaCode(match[1])} sudah lahir.`;
  if ((match = /^altered_table\(([^)]+)\)/i.exec(text))) return `Bentuk tabel ${asaCode(match[1])} sudah diperbarui.`;
  if ((match = /^dropped_table\(([^)]+)\)/i.exec(text))) return `Tabel ${asaCode(match[1])} sudah dihapus dari database aktif.`;
  if ((match = /^truncated_table\(([^)]+)\)/i.exec(text))) return `Isi tabel ${asaCode(match[1])} sudah dikosongkan, strukturnya tetap ada.`;
  if ((match = /^inserted\(([^,]+),\s*([^)]+)\)/i.exec(text))) return `${match[2]} baris sudah masuk ke tabel ${asaCode(match[1])}.`;
  if ((match = /^updated\(([^,]+),\s*([^)]+)\)/i.exec(text))) return `${match[2]} baris di tabel ${asaCode(match[1])} sudah diperbarui.`;
  if ((match = /^deleted\(([^,]+),\s*([^)]+)\)/i.exec(text))) return `${match[2]} baris dari tabel ${asaCode(match[1])} sudah dihapus.`;
  if ((match = /^created_index\(([^,]+),\s*([^)]+)\)/i.exec(text))) return `Index ${asaCode(match[1])} sudah dibuat untuk tabel ${asaCode(match[2])}.`;
  if ((match = /^created_view\(([^)]+)\)/i.exec(text))) return `View ${asaCode(match[1])} sudah dibuat dan akan muncul di daftar samping.`;
  if ((match = /^dropped_view\(([^)]+)\)/i.exec(text))) return `View ${asaCode(match[1])} sudah dihapus.`;
  if ((match = /^created_user\(([^)]+)\)/i.exec(text))) return `User ${asaCode(match[1])} sudah dibuat.`;
  if (/^granted\(/i.test(text)) return 'Izin sudah diberikan ke user yang dipilih.';
  if (/^revoked\(/i.test(text)) return 'Izin sudah dicabut dari user yang dipilih.';
  if (/^committed|commit$/i.test(text)) return 'Transaksi sudah dikunci. Perubahan resmi tersimpan.';
  if (/^rolled_back|rollback$/i.test(text)) return 'Transaksi sudah dibatalkan. Data balik aman seperti sebelumnya.';
  if (/^started_transaction|begin|start_transaction$/i.test(text)) return 'Transaksi sudah dibuka. Asa akan menunggu COMMIT atau ROLLBACK.';
  if ((match = /^batch_completed\(([^)]+)\)/i.exec(text))) return `Batch selesai. ${match[1]} berhasil dilewati.`;
  if (/^ok$/i.test(text) || /^done$/i.test(text)) return 'Perintah selesai dan tidak ada yang protes.';
  return text ? `Perintah selesai. Catatan Asa: ${text}` : 'Perintah selesai dan database tetap tenang.';
}

function asaDiagnosticCopy(item) {
  const seed = `${item?.severity}|${item?.line}|${item?.message}|${item?.correction || ''}`;
  const opener = item?.severity === 'error'
    ? asaPick(ASA_ERROR_OPENERS, seed)
    : asaPick(ASA_CORRECTION_OPENERS, seed);
  const detail = item?.severity === 'error' ? asaErrorDetail(item?.message) : asaCorrectionDetail(item);
  return `${opener} ${detail}`;
}

function asaResultCopy(result) {
  const message = result?.message || JSON.stringify(result || {});
  if (result?.status === 'ok') {
    return `${asaPick(ASA_SUCCESS_OPENERS, message)} ${asaSuccessDetail(message)}`;
  }
  return `${asaPick(ASA_ERROR_OPENERS, message)} ${asaErrorDetail(message)}`;
}

function asaErrorCopy(message) {
  return `${asaPick(ASA_ERROR_OPENERS, message)} ${asaErrorDetail(message)}`;
}

function analyzeSqlClient(sql) {
  const diagnostics = [];
  const corrected = correctSqlText(sql);
  for (const change of corrected.changes.slice(0, 4)) {
    diagnostics.push({
      severity: 'warning',
      line: change.line,
      message: `Auto correction tersedia: ${change.from} -> ${change.to}.`,
      source: 'client',
    });
  }

  const supported = /^(create|use|drop|truncate|insert|select|describe|desc|show|update|delete|alter|explain)\b/i;
  for (const stmt of splitStatementsDetailed(sql)) {
    const first = /^\s*([A-Za-z_][\w$]*)/.exec(stmt.text)?.[1] || '';
    if (first && !supported.test(first)) {
      diagnostics.push({
        severity: 'error',
        line: stmt.line,
        message: `Statement "${first}" belum dikenali AsaDB.`,
        source: 'client',
      });
    }
    const balance = parenBalance(stmt.text);
    if (balance !== 0) {
      diagnostics.push({
        severity: 'error',
        line: stmt.line,
        message: balance > 0 ? 'Kurung buka belum ditutup.' : 'Kurung tutup berlebih.',
        source: 'client',
      });
    }
    if (!stmt.terminated) {
      diagnostics.push({
        severity: 'warning',
        line: stmt.line,
        message: 'Statement belum ditutup titik koma (;).',
        source: 'client',
      });
    }
    if (/^\s*insert\b/i.test(stmt.text) && !/\bvalues\b/i.test(stmt.text)) {
      diagnostics.push({
        severity: 'error',
        line: stmt.line,
        message: 'INSERT AsaDB saat ini butuh VALUES.',
        source: 'client',
      });
    }
  }
  return dedupeDiagnostics(diagnostics);
}

function normalizeDiagnostics(items) {
  return (items || []).map(item => ({
    severity: item.severity === 'error' ? 'error' : 'warning',
    line: Math.max(1, Number(item.line) || 1),
    message: String(item.message || 'SQL diagnostic.'),
    correction: item.correction || '',
    source: item.source || 'backend',
  }));
}

function dedupeDiagnostics(items) {
  const seen = new Set();
  const out = [];
  for (const item of normalizeDiagnostics(items)) {
    const key = `${item.severity}|${item.line}|${item.message}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(item);
  }
  return out.sort((a, b) => a.line - b.line || (a.severity === 'error' ? -1 : 1));
}

function setSqlDiagnostics(items) {
  sqlDiagnosticsState = dedupeDiagnostics(items);
  renderSqlDiagnostics();
  renderSqlLineNumbers(sqlInput.value);
}

function renderSqlDiagnostics() {
  const items = sqlDiagnosticsState.filter(item => item.severity === 'error' || item.severity === 'warning');
  sqlEditor.classList.toggle('has-error', items.some(item => item.severity === 'error'));
  if (!items.length) {
    sqlDiagnostics.innerHTML = '';
    return;
  }
  sqlDiagnostics.innerHTML = items.slice(0, 6).map(item => `
    <div class="sql-diagnostic ${item.severity}">
      <strong>${escapeHtml(item.severity === 'error' ? ASA_ERROR_LABEL : ASA_CORRECTION_LABEL)}</strong>
      <span><span class="diagnostic-line">Line ${item.line}</span> ${escapeHtml(asaDiagnosticCopy(item))}</span>
    </div>
  `).join('');
}

function renderSqlLineNumbers(sql) {
  const severityByLine = {};
  for (const item of sqlDiagnosticsState) {
    if (item.severity === 'error') severityByLine[item.line] = 'error';
    else if (!severityByLine[item.line]) severityByLine[item.line] = 'warning';
  }
  const lines = Math.max(1, sql.split('\n').length);
  sqlLineNumbers.innerHTML = Array.from({ length: lines }, (_, index) => {
    const line = index + 1;
    const severity = severityByLine[line] || '';
    return `<span class="${severity}">${line}</span>`;
  }).join('');
}

function syncSqlScroll() {
  sqlHighlight.scrollTop = sqlInput.scrollTop;
  sqlHighlight.scrollLeft = sqlInput.scrollLeft;
  sqlLineNumbers.scrollTop = sqlInput.scrollTop;
}

function updateSqlEditor() {
  sqlHighlight.innerHTML = highlightSql(sqlInput.value);
  renderSqlLineNumbers(sqlInput.value);
  syncSqlScroll();
}

function setSqlText(text, analyze = true) {
  sqlInput.value = text;
  updateSqlEditor();
  if (analyze) scheduleSqlAnalysis();
}

function scheduleSqlAnalysis() {
  clearTimeout(sqlAnalyzeTimer);
  sqlAnalyzeTimer = setTimeout(() => refreshSqlDiagnostics(true), 420);
}

async function refreshSqlDiagnostics(useBackend = true) {
  const sql = sqlInput.value;
  const requestId = ++sqlAnalyzeRequest;
  let diagnostics = analyzeSqlClient(sql);

  if (backendOnline && useBackend) {
    try {
      const body = new URLSearchParams({ sql });
      const res = await fetch('/api/analyze', {
        method: 'POST',
        headers: apiHeaders({ 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' }),
        body,
      });
      if (res.ok) {
        const data = await res.json();
        if (requestId !== sqlAnalyzeRequest) return sqlDiagnosticsState;
        diagnostics = dedupeDiagnostics([...diagnostics, ...(data.diagnostics || [])]);
      }
    } catch (err) {
      backendOnline = false;
      engineStatus.textContent = 'Mode: browser sandbox';
      engineStatus.className = 'status warn';
      log(`Analyzer fallback: ${err.message}`);
    }
  }

  if (requestId === sqlAnalyzeRequest) setSqlDiagnostics(diagnostics);
  return diagnostics;
}

function addRuntimeDiagnostics(results) {
  const runtime = (results || []).filter(r => r.status === 'error' && r.line).map(r => ({
    severity: 'error',
    line: r.line,
    message: r.message || 'Runtime error.',
    source: 'runtime',
  }));
  if (runtime.length) setSqlDiagnostics([...sqlDiagnosticsState.filter(x => x.source !== 'runtime'), ...runtime]);
}

async function executeBackendSql(sql, options = {}) {
  const body = new URLSearchParams({ sql });
  const res = await fetch('/api/query', {
    method: 'POST',
    headers: apiHeaders({ 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' }),
    body,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`);
  if (options.sync !== false) await syncBackendStateSmart();
  return data;
}

async function saveBackendDatabase(db = currentDbName()) {
  let saveError = null;
  try {
    const res = await fetch('/api/save', {
      method: 'POST',
      headers: apiHeaders(),
    });
    if (res.ok) return res.json();
    saveError = new Error(`HTTP ${res.status}`);
  } catch (err) {
    saveError = err;
  }

  try {
    const body = new URLSearchParams({ sql: 'SHOW DATABASES;' });
    const res = await fetch('/api/query', {
      method: 'POST',
      headers: apiHeaders({ 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' }),
      body,
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`);
    if (hasResultError(data)) throw new Error(data.results.find(result => result.status === 'error')?.message || 'save failed');
    return { results: [{ status: 'ok', message: `saved_database(${db || 'none'})` }] };
  } catch (fallbackError) {
    throw saveError || fallbackError;
  }
}

function hasResultError(data) {
  return (data?.results || [data]).some(result => result?.status === 'error');
}

function resultSetHasError(data) {
  const results = data?.allResults || data?.results || [data];
  return results.some(result => result?.status === 'error');
}

function chooseAsaRunSound(kind) {
  const list = ASA_RUN_SOUNDS[kind] || ASA_RUN_SOUNDS.error;
  if (!list.length) return null;
  if (list.length === 1) return list[0];
  let index = Math.floor(Math.random() * list.length);
  if (index === asaRunSoundState[kind]) index = (index + 1) % list.length;
  asaRunSoundState[kind] = index;
  return list[index];
}

function asaRunAudioList(kind) {
  if (typeof Audio === 'undefined') return [];
  if (!asaRunAudioCache[kind]?.length) {
    asaRunAudioCache[kind] = (ASA_RUN_SOUNDS[kind] || []).map(src => {
      const audio = new Audio(src);
      audio.preload = 'auto';
      audio.volume = 0.72;
      return audio;
    });
  }
  return asaRunAudioCache[kind];
}

function primeAsaRunSounds() {
  if (typeof Audio === 'undefined') return Promise.resolve();
  if (asaRunPrimePromise) return asaRunPrimePromise;
  asaRunAudioList('ok');
  asaRunAudioList('error');
  const source = ASA_RUN_SOUNDS.ok[0] || ASA_RUN_SOUNDS.error[0];
  const audio = source ? new Audio(source) : null;
  if (!audio) return Promise.resolve();
  asaRunPrimeAudio = audio;
  try {
    audio.muted = true;
    audio.volume = 0;
    audio.currentTime = 0;
    const played = audio.play();
    asaRunPrimePromise = Promise.resolve(played).then(() => {
        audio.pause();
        audio.currentTime = 0;
      }).catch(() => {
        // Some browsers unlock media only after the first completed gesture.
      }).finally(() => {
        asaRunPrimeAudio = null;
      });
  } catch (_) {
    asaRunPrimeAudio = null;
    asaRunPrimePromise = Promise.resolve();
  }
  return asaRunPrimePromise;
}

function stopAsaRunSounds() {
  if (asaRunPrimeAudio) {
    try {
      asaRunPrimeAudio.pause();
      asaRunPrimeAudio.currentTime = 0;
    } catch (_) {}
    asaRunPrimeAudio = null;
  }
  for (const list of Object.values(asaRunAudioCache)) {
    for (const audio of list) {
      try {
        audio.pause();
        audio.currentTime = 0;
      } catch (_) {}
    }
  }
  activeRunAudio = null;
}

function playAsaRunSound(kind) {
  if (typeof Audio === 'undefined') return;
  const src = chooseAsaRunSound(kind);
  const list = asaRunAudioList(kind);
  const audio = list.find(item => item.src.endsWith(src));
  if (!audio) return;
  stopAsaRunSounds();
  activeRunAudio = audio;
  try {
    audio.currentTime = 0;
    audio.muted = false;
    audio.volume = 0.72;
    const played = audio.play();
    if (played && typeof played.catch === 'function') {
      played.catch(() => {
        if (activeRunAudio === audio) activeRunAudio = null;
      });
    }
  } catch (_) {}
}

async function executeBackendSqlBatched(sql, options = {}) {
  const statements = splitStatementsDetailed(sql).flatMap(stmt =>
    expandOversizedStatement(stmt.text).map(text => ({ ...stmt, text }))
  );
  const chunks = buildBackendSqlChunks(statements);
  const transactional = options.transaction !== false && statements.some(stmt => isWriteStatement(stmt.text));
  const allResults = [];
  const visibleResults = [];
  const maxVisible = options.maxVisible ?? 80;
  const total = chunks.length + (transactional ? 2 : 0);
  let completed = 0;

  const pushResults = (data, forceVisible = false) => {
    const results = data.results || [data];
    allResults.push(...results);
    for (const result of results) {
      const keepVisible = forceVisible || result.status === 'table' || result.status === 'error' || visibleResults.length < maxVisible;
      if (keepVisible) visibleResults.push(result);
    }
  };
  const tick = (label) => {
    completed += 1;
    options.onProgress?.({ completed, total, label });
  };

  try {
    if (transactional) {
      pushResults(await executeBackendSql('BEGIN;', { sync: false }));
      tick('BEGIN');
    }
    for (const chunk of chunks) {
      pushResults(await executeBackendSql(chunk.sql, { sync: false }), chunk.forceVisible);
      tick(chunk.label);
      const errorResult = allResults.find(result => result.status === 'error');
      if (errorResult && options.stopOnError) throw new Error(errorResult.message || 'SQL batch failed.');
    }
    if (transactional) {
      pushResults(await executeBackendSql('COMMIT;', { sync: false }), true);
      tick('COMMIT');
    }
    if (options.syncFinal === 'none') {
      // The caller owns the single post-run refresh.
    } else if (options.syncFinal === false) await syncCatalogFromBackend().catch(() => false);
    else await syncBackendStateSmart();
  } catch (err) {
    if (transactional) {
      try { await executeBackendSql('ROLLBACK;', { sync: false }); } catch (_) {}
    }
    if (options.syncFinal === 'none') {
      // The caller owns the single post-run refresh.
    } else if (options.syncFinal === false) await syncCatalogFromBackend().catch(() => false);
    else await syncBackendStateSmart().catch(() => false);
    throw err;
  }

  const filtered = options.showOnlyErrors ? allResults.filter(result => result.status === 'error') : visibleResults;
  return { results: compactBatchResults(filtered, allResults), allResults, statementCount: statements.length };
}

function buildBackendSqlChunks(statements, limit = 60000) {
  const chunks = [];
  let batch = [];
  let length = 0;

  const flush = () => {
    if (!batch.length) return;
    const first = statementBody(batch[0].text).slice(0, 72);
    chunks.push({
      sql: batch.map(stmt => `${stmt.text};`).join('\n'),
      forceVisible: batch.some(stmt => /^(select|show|describe|desc)\b/i.test(statementBody(stmt.text))),
      label: batch.length === 1 ? first : `${first} + ${batch.length - 1} statement(s)`,
    });
    batch = [];
    length = 0;
  };

  for (const stmt of statements) {
    const text = `${stmt.text};`;
    if (batch.length && length + text.length + 1 > limit) flush();
    batch.push(stmt);
    length += text.length + 1;
  }
  flush();
  return chunks;
}

function compactBatchResults(visibleResults, allResults) {
  const errors = allResults.filter(result => result.status === 'error');
  if (errors.length) return errors;
  const tableResults = visibleResults.filter(result => result.status === 'table');
  const finalOk = [...allResults].reverse().find(result => result.status === 'ok');
  const writes = allResults.filter(result => result.status === 'ok' && /^(inserted|created_table|dropped_table|committed|using_database|created_database)/.test(String(result.message || ''))).length;
  const summary = writes ? [{ status: 'ok', message: `batch_completed(${writes} write step(s))` }] : [];
  return [...summary, ...tableResults, ...(finalOk && !summary.includes(finalOk) ? [finalOk] : [])].slice(0, 80);
}

function isWriteStatement(text) {
  return /^(create|drop|insert|update|delete|alter|truncate|begin|start|commit|rollback|grant|revoke|use)\b/i.test(statementBody(text));
}

function statementBody(text) {
  return String(text || '').trim()
    .replace(/^(?:(?:--[^\n]*(?:\n|$)|#[^\n]*(?:\n|$)|\/\*[\s\S]*?\*\/)\s*)+/g, '')
    .trim();
}

function expandOversizedStatement(text, limit = 60000) {
  const source = String(text || '').trim();
  if (source.length <= limit) return [source];
  const body = statementBody(source);
  const match = /^(INSERT\s+INTO\s+[\s\S]+?\s+VALUES)\s+([\s\S]+)$/i.exec(body);
  if (!match) return [source];
  const prefix = match[1].trim();
  const groups = splitValueGroups(match[2]);
  if (!groups.length) return [source];
  const out = [];
  let batch = [];
  let batchLength = prefix.length + 8;
  for (const group of groups) {
    const groupText = `(${group})`;
    if (batch.length && batchLength + groupText.length + 2 > limit) {
      out.push(`${prefix}\n  ${batch.join(',\n  ')}`);
      batch = [];
      batchLength = prefix.length + 8;
    }
    batch.push(groupText);
    batchLength += groupText.length + 2;
  }
  if (batch.length) out.push(`${prefix}\n  ${batch.join(',\n  ')}`);
  return out;
}

async function syncSandboxFromBackend() {
  const res = await fetch('/api/state', { cache: 'no-store', headers: apiHeaders() });
  if (!res.ok) return false;
  const data = await res.json();
  syncSandboxFromStateData(data);
  return true;
}

async function syncBackendStateSmart() {
  const catalog = await syncCatalogFromBackend().catch(() => null);
  if (!catalog) return syncSandboxFromBackend();
  if (catalog.totalRows <= BACKEND_FULL_SYNC_ROW_LIMIT) return syncSandboxFromBackend();
  return true;
}

async function syncCatalogFromBackend() {
  const res = await fetch('/api/catalog', { cache: 'no-store', headers: apiHeaders() });
  if (!res.ok) return false;
  const data = await res.json();
  return syncSandboxFromCatalogData(data);
}

function syncSandboxFromCatalogData(data) {
  const rows = data?.rows || [];
  if (!rows.length) return { totalRows: 0 };

  const dbs = {};
  const views = {};
  let currentDb = '';
  let totalRows = 0;

  for (const row of rows) {
    const [current, dbName, kind, name, rowCount, columnsTerm, indexesTerm, queryTerm] = row;
    if (current && current !== 'none') currentDb = current;
    if (!dbName || isSystemDb(dbName)) continue;
    dbs[dbName] ||= {};
    views[dbName] ||= {};

    if (kind === 'table' && name) {
      const count = Number(rowCount) || 0;
      const existing = sandbox.dbs?.[dbName]?.[name];
      const existingRows = existing?.rows?.length === count ? existing.rows : [];
      dbs[dbName][name] = {
        columns: parseCatalogColumns(columnsTerm),
        rows: existingRows,
        indexes: parseCatalogIndexes(indexesTerm),
        rowCount: count,
        remote: true,
      };
      totalRows += count;
    } else if (kind === 'view' && name) {
      views[dbName][name] = {
        name,
        query: queryTerm ? String(queryTerm) : 'SELECT-backed view',
        columns: [],
        rows: [],
        isView: true,
        remote: true,
      };
    }
  }

  sandbox = normalizeSandbox({
    currentDb: currentDb && currentDb !== 'none' ? currentDb : sandbox.currentDb,
    dbs,
    views,
  });
  if (selectedTable && !currentRelation(selectedTable)) selectedTable = '';
  saveSandbox();
  renderTableBrowser();
  return { totalRows };
}

function parseCatalogColumns(termText) {
  try {
    const term = parsePrologTerm(String(termText || '[]'));
    return (term.items || []).filter(node => node.type === 'compound' && node.functor === 'col').map(node => {
      const column = {
        name: nodeValue(node.args[0]),
        type: nodeValue(node.args[1]) || 'TEXT',
      };
      for (const option of node.args[2]?.items || []) {
        const optionName = option.type === 'compound' ? option.functor : nodeValue(option);
        if (optionName === 'not_null') column.nullable = false;
        if (optionName === 'auto_increment') column.extra = 'Auto Increment';
        if (optionName === 'primary_key') column.primary = true;
        if (optionName === 'unique') column.unique = true;
        if (option.type === 'compound' && option.functor === 'default') column.default = nodeValue(option.args[0]);
      }
      return column;
    }).filter(column => column.name);
  } catch (_) {
    return [];
  }
}

function parseCatalogIndexes(termText) {
  try {
    const term = parsePrologTerm(String(termText || '[]'));
    return (term.items || []).filter(node => node.type === 'compound' && node.functor === 'index').map(node => ({
      name: nodeValue(node.args[0]) || 'INDEX',
      columns: (node.args[1]?.items || []).map(nodeValue).filter(Boolean),
      unique: nodeValue(node.args[2]) === 'unique',
    }));
  } catch (_) {
    return [];
  }
}

function syncSandboxFromStateData(data) {
  const row = data?.rows?.[0] || [];
  const stateTerm = row[0];
  const currentDb = row[1] && row[1] !== 'none' ? row[1] : '';
  if (!stateTerm) return;
  try {
    const next = prologTermToSandbox(parsePrologTerm(String(stateTerm)));
    if (currentDb && (next.dbs[currentDb] || next.views?.[currentDb]) && !isSystemDb(currentDb)) next.currentDb = currentDb;
    sandbox = normalizeSandbox(next);
    saveSandbox();
    if (selectedTable && !currentRelation(selectedTable)) selectedTable = '';
    renderTableBrowser();
  } catch (err) {
    log(`State sync skipped: ${err.message}`);
  }
}

function startupDelay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function startupWarmupEnabled() {
  if (!startupLoader) return false;
  if (location.protocol !== 'http:' && location.protocol !== 'https:') return false;
  return ['127.0.0.1', 'localhost', '::1', '[::1]'].includes(location.hostname);
}

async function warmupBackendRuntime() {
  if (!startupWarmupEnabled()) return false;
  const res = await fetch('/api/warmup', { cache: 'no-store', headers: apiHeaders() });
  return res.ok;
}

function hideStartupLoader() {
  if (!startupLoader) return;
  startupLoader.classList.add('hidden');
  document.body.classList.remove('is-warming');
  setTimeout(() => startupLoader.remove(), 260);
}

function runStartupWarmup(engineWork) {
  if (!startupLoader) return;
  if (!startupWarmupEnabled()) {
    hideStartupLoader();
    return;
  }
  document.body.classList.add('is-warming');
  Promise.allSettled([engineWork, warmupBackendRuntime()]);
  startupDelay(STARTUP_WARMUP_MS).then(hideStartupLoader);
}

async function checkEngine() {
  try {
    backendOnline = Boolean(await syncBackendStateSmart());
  } catch (_) {
    backendOnline = false;
  }
  engineStatus.textContent = backendOnline ? 'Mode: Prolog backend online' : 'Mode: browser sandbox';
  engineStatus.className = backendOnline ? 'status ok' : 'status warn';
  log(backendOnline ? 'Connected to local Prolog AsaDB engine.' : 'No backend detected; using local browser sandbox.');
  refreshSqlDiagnostics(backendOnline);
}

function showView(name, hashName = name) {
  for (const [viewName, node] of Object.entries(views)) node.hidden = viewName !== name;
  for (const [viewName, button] of Object.entries(viewButtons)) button.classList.toggle('active', viewName === name);
  pageTitle.textContent = name === 'sql' ? 'SQL Workspace' :
    name === 'table' ? 'Table Detail' :
    name === 'create' ? 'Create Table' :
    'Data Transfer';
  if (location.hash !== `#${hashName}`) history.replaceState(null, '', `#${hashName}`);
  if (name === 'export') {
    renderExportTablePicker();
    exportDbName.textContent = currentDbName() || 'No database selected';
  }
}

function splitStatements(sql) {
  return splitStatementsDetailed(sql).map(stmt => stmt.text);
}

function splitStatementsDetailed(sql) {
  const out = [];
  let cur = '';
  let quote = null;
  let esc = false;
  let line = 1;
  let stmtLine = 1;
  let hasContent = false;

  for (let i = 0; i < sql.length; i += 1) {
    const ch = sql[i];
    if (!hasContent && !/\s/.test(ch)) {
      stmtLine = line;
      hasContent = true;
    }

    if (esc) {
      cur += ch;
      esc = false;
      if (ch === '\n') line += 1;
      continue;
    }

    if (ch === '\\') {
      cur += ch;
      esc = true;
      continue;
    }

    if (quote) {
      cur += ch;
      if (ch === quote) quote = null;
      if (ch === '\n') line += 1;
      continue;
    }

    if (!quote && (sql.startsWith('--', i) || sql.startsWith('/*', i) || ch === '#')) {
      const end = copySqlComment(sql, i);
      const comment = sql.slice(i, end);
      cur += comment;
      line += (comment.match(/\n/g) || []).length;
      i = end - 1;
      continue;
    }

    if (ch === '\'' || ch === '"' || ch === '`') {
      quote = ch;
      cur += ch;
      continue;
    }

    if (ch === ';') {
      if (cur.trim()) out.push({ text: cur.trim(), line: stmtLine, terminated: true });
      cur = '';
      hasContent = false;
      stmtLine = line;
      continue;
    }

    cur += ch;
    if (ch === '\n') line += 1;
  }

  if (cur.trim()) out.push({ text: cur.trim(), line: stmtLine, terminated: false });
  return out;
}

function splitTopLevel(text, separator = ',') {
  const parts = [];
  let cur = '', quote = null, esc = false, depth = 0;
  for (const ch of text) {
    if (esc) { cur += ch; esc = false; continue; }
    if (ch === '\\') { cur += ch; esc = true; continue; }
    if (quote) {
      cur += ch;
      if (ch === quote) quote = null;
      continue;
    }
    if (ch === '\'' || ch === '"') { quote = ch; cur += ch; continue; }
    if (ch === '(') depth += 1;
    if (ch === ')') depth -= 1;
    if (ch === separator && depth === 0) {
      parts.push(cur.trim());
      cur = '';
      continue;
    }
    cur += ch;
  }
  if (cur.trim()) parts.push(cur.trim());
  return parts;
}

function splitValueGroups(text) {
  const groups = [];
  let cur = '', quote = null, esc = false, depth = 0, inGroup = false;
  for (const ch of text) {
    if (esc) { if (inGroup) cur += ch; esc = false; continue; }
    if (ch === '\\') { if (inGroup) cur += ch; esc = true; continue; }
    if (quote) {
      if (inGroup) cur += ch;
      if (ch === quote) quote = null;
      continue;
    }
    if (ch === '\'' || ch === '"') {
      if (inGroup) cur += ch;
      quote = ch;
      continue;
    }
    if (ch === '(') {
      if (inGroup) {
        depth += 1;
        cur += ch;
      } else {
        inGroup = true;
        depth = 1;
        cur = '';
      }
      continue;
    }
    if (ch === ')' && inGroup) {
      depth -= 1;
      if (depth === 0) {
        groups.push(cur.trim());
        inGroup = false;
      } else {
        cur += ch;
      }
      continue;
    }
    if (inGroup) cur += ch;
  }
  return groups;
}

function parseValue(v) {
  v = v.trim();
  if (/^null$/i.test(v)) return null;
  if (/^true$/i.test(v)) return 1;
  if (/^false$/i.test(v)) return 0;
  if (/^'.*'$/.test(v) || /^".*"$/.test(v)) return v.slice(1, -1).replace(/''/g, "'").replace(/\\"/g, '"').replace(/\\'/g, "'");
  if (/^-?\d+$/.test(v)) return Number(v);
  return v.replace(/`/g, '');
}

function quoteIdent(name) {
  const clean = String(name || '').trim();
  if (/^[A-Za-z_][\w$]*$/.test(clean)) return clean;
  return `\`${clean.replace(/`/g, '')}\``;
}

function sqlLiteral(value) {
  if (value === null || value === undefined) return 'NULL';
  if (typeof value === 'number') return String(value);
  return `'${String(value).replace(/'/g, "''")}'`;
}

function cleanSqlIdentifier(value) {
  return String(value || '').trim().replace(/^[`"]|[`"]$/g, '');
}

function normalizeSqlType(type) {
  return String(type || 'TEXT')
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/\s*\(\s*/g, '(')
    .replace(/\s*,\s*/g, ', ')
    .replace(/\s*\)\s*/g, ')')
    .toUpperCase();
}

function parseLeadingIdentifier(text) {
  const source = String(text || '').trim();
  const quoted = /^`([^`]+)`\s*(.*)$/s.exec(source) || /^"([^"]+)"\s*(.*)$/s.exec(source);
  if (quoted) return { name: quoted[1], rest: quoted[2].trim() };
  const bare = /^([A-Za-z_][\w$]*)\s*(.*)$/s.exec(source);
  return bare ? { name: bare[1], rest: bare[2].trim() } : null;
}

function stripColumnPlacement(text) {
  return String(text || '')
    .replace(/\s+FIRST\s*$/i, '')
    .replace(/\s+AFTER\s+`?[\w$]+`?\s*$/i, '')
    .trim();
}

function parseColumnSpec(text) {
  const ident = parseLeadingIdentifier(text);
  if (!ident || !ident.rest) return null;
  const rest = stripColumnPlacement(ident.rest);
  const typeMatch = /^([A-Za-z]+(?:\s*\([^)]*\))?(?:\s+UNSIGNED)?)([\s\S]*)$/i.exec(rest);
  if (!typeMatch) return null;
  const optionText = typeMatch[2] || '';
  const column = { name: cleanSqlIdentifier(ident.name), type: normalizeSqlType(typeMatch[1]) };
  if (/\bNOT\s+NULL\b/i.test(optionText)) column.nullable = false;
  if (/\bAUTO_INCREMENT\b/i.test(optionText)) column.extra = 'Auto Increment';
  const defaultMatch = /\bDEFAULT\s+('[^']*'|"[^"]*"|[^\s,]+)/i.exec(optionText);
  if (defaultMatch) column.default = parseValue(defaultMatch[1]);
  if (/\bPRIMARY\s+KEY\b/i.test(optionText)) column.primary = true;
  if (/\bUNIQUE\b/i.test(optionText)) column.unique = true;
  return column;
}

function parseAlterOperation(text) {
  const op = String(text || '').trim();
  let m;
  if ((m = /^ADD\s+(?:COLUMN\s+)?([\s\S]+)$/i.exec(op))) {
    const column = parseColumnSpec(m[1]);
    return column ? { kind: 'add', column } : null;
  }
  if ((m = /^DROP\s+(?:COLUMN\s+)?(.+)$/i.exec(op))) {
    const ident = parseLeadingIdentifier(m[1]);
    return ident ? { kind: 'drop', name: ident.name } : null;
  }
  if ((m = /^MODIFY\s+(?:COLUMN\s+)?([\s\S]+)$/i.exec(op))) {
    const column = parseColumnSpec(m[1]);
    return column ? { kind: 'modify', column } : null;
  }
  if ((m = /^CHANGE\s+(?:COLUMN\s+)?([\s\S]+)$/i.exec(op))) {
    const oldIdent = parseLeadingIdentifier(m[1]);
    const column = oldIdent ? parseColumnSpec(oldIdent.rest) : null;
    return column ? { kind: 'change', oldName: oldIdent.name, column } : null;
  }
  if ((m = /^RENAME\s+COLUMN\s+(.+?)\s+TO\s+(.+)$/i.exec(op))) {
    const oldIdent = parseLeadingIdentifier(m[1]);
    const newIdent = parseLeadingIdentifier(m[2]);
    return oldIdent && newIdent ? { kind: 'renameColumn', oldName: oldIdent.name, newName: newIdent.name } : null;
  }
  if ((m = /^RENAME\s+(?:TO\s+)?(.+)$/i.exec(op))) {
    const ident = parseLeadingIdentifier(m[1]);
    return ident ? { kind: 'renameTable', name: ident.name } : null;
  }
  return null;
}

function removeColumnFromIndexes(table, name) {
  table.indexes = (table.indexes || [])
    .map(index => ({ ...index, columns: (index.columns || []).filter(column => column !== name) }))
    .filter(index => (index.columns || []).length);
}

function renameColumnInIndexes(table, oldName, newName) {
  table.indexes = (table.indexes || []).map(index => ({
    ...index,
    columns: (index.columns || []).map(column => column === oldName ? newName : column),
  }));
}

function applyColumnIndexOptions(table, column) {
  table.indexes ||= [];
  if (column.primary) {
    table.indexes = table.indexes.filter(index => !/^PRIMARY$/i.test(index.name || ''));
    table.indexes.unshift({ name: 'PRIMARY', columns: [column.name], unique: true });
  } else if (column.unique) {
    const name = `${column.name}_unique`;
    table.indexes = table.indexes.filter(index => index.name !== name);
    table.indexes.push({ name, columns: [column.name], unique: true });
  }
  delete column.primary;
  delete column.unique;
}

function sandboxColumnKey(table, columnName, column) {
  if (column?.primary) return 'PRI';
  if (column?.unique) return 'UNI';
  for (const index of table.indexes || []) {
    if (!(index.columns || []).includes(columnName)) continue;
    if (/^PRIMARY$/i.test(index.name || '')) return 'PRI';
    if (index.unique) return 'UNI';
    return 'MUL';
  }
  return '';
}

function sandboxDescribeRows(table) {
  return (table.columns || []).map(column => [
    column.name,
    column.type || 'TEXT',
    column.nullable === false ? 'NO' : 'YES',
    sandboxColumnKey(table, column.name, column),
    Object.prototype.hasOwnProperty.call(column, 'default') ? column.default : 'NULL',
    column.extra || '',
  ]);
}

function applySandboxAlter(db, tableName, operations) {
  const table = db[tableName];
  if (!table) return `table not found: ${tableName}`;
  table.columns ||= [];
  table.rows ||= [];
  table.indexes ||= [];

  for (const operation of operations) {
    if (!operation) return `sandbox belum support: ALTER operation`;
    if (operation.kind === 'add') {
      if (table.columns.some(column => column.name === operation.column.name)) return `column already exists: ${operation.column.name}`;
      applyColumnIndexOptions(table, operation.column);
      table.columns.push(operation.column);
      for (const row of table.rows) row[operation.column.name] = Object.prototype.hasOwnProperty.call(operation.column, 'default') ? operation.column.default : null;
    } else if (operation.kind === 'drop') {
      table.columns = table.columns.filter(column => column.name !== operation.name);
      for (const row of table.rows) delete row[operation.name];
      removeColumnFromIndexes(table, operation.name);
    } else if (operation.kind === 'modify') {
      const index = table.columns.findIndex(column => column.name === operation.column.name);
      if (index === -1) return `column not found: ${operation.column.name}`;
      applyColumnIndexOptions(table, operation.column);
      table.columns[index] = { ...table.columns[index], ...operation.column };
    } else if (operation.kind === 'change') {
      const index = table.columns.findIndex(column => column.name === operation.oldName);
      if (index === -1) return `column not found: ${operation.oldName}`;
      const oldName = operation.oldName;
      const nextName = operation.column.name;
      applyColumnIndexOptions(table, operation.column);
      table.columns[index] = { ...table.columns[index], ...operation.column };
      for (const row of table.rows) {
        row[nextName] = row[oldName] ?? null;
        if (nextName !== oldName) delete row[oldName];
      }
      renameColumnInIndexes(table, oldName, nextName);
    } else if (operation.kind === 'renameColumn') {
      const index = table.columns.findIndex(column => column.name === operation.oldName);
      if (index === -1) return `column not found: ${operation.oldName}`;
      table.columns[index] = { ...table.columns[index], name: operation.newName };
      for (const row of table.rows) {
        row[operation.newName] = row[operation.oldName] ?? null;
        if (operation.newName !== operation.oldName) delete row[operation.oldName];
      }
      renameColumnInIndexes(table, operation.oldName, operation.newName);
    } else if (operation.kind === 'renameTable') {
      if (db[operation.name]) return `table already exists: ${operation.name}`;
      db[operation.name] = table;
      delete db[tableName];
      if (selectedTable === tableName) selectedTable = operation.name;
    } else {
      return `sandbox belum support: ALTER operation`;
    }
  }
  return '';
}

function sandboxExec(sql) {
  const results = [];
  for (const stmt of splitStatementsDetailed(sql)) {
    const line = stmt.line;
    const add = (result) => results.push({ line, ...result });
    const requireDb = () => {
      const db = currentDbName();
      if (!db) add({ status: 'error', message: 'select or create a database first' });
      return db;
    };
    const s = statementBody(stmt.text).replace(/\s+/g, ' ').trim();
    let m;
    if ((m = /^CREATE DATABASE(?: IF NOT EXISTS)? `?([\w$]+)`?$/i.exec(s))) {
      sandbox.dbs[m[1]] ||= {};
      sandbox.views ||= {};
      sandbox.views[m[1]] ||= {};
      add({ status: 'ok', message: `created_database(${m[1]})` });
    } else if ((m = /^USE `?([\w$]+)`?$/i.exec(s))) {
      sandbox.dbs[m[1]] ||= {};
      sandbox.views ||= {};
      sandbox.views[m[1]] ||= {};
      sandbox.currentDb = m[1];
      add({ status: 'ok', message: `using_database(${m[1]})` });
    } else if ((m = /^DROP DATABASE(?: IF EXISTS)? `?([\w$]+)`?$/i.exec(s))) {
      delete sandbox.dbs[m[1]];
      if (sandbox.views) delete sandbox.views[m[1]];
      if (sandbox.currentDb === m[1]) sandbox.currentDb = '';
      if (selectedTable && !currentRelation(selectedTable)) selectedTable = '';
      add({ status: 'ok', message: `dropped_database(${m[1]})` });
    } else if ((m = /^CREATE VIEW(?: IF NOT EXISTS)? `?([\w$]+)`? AS ([\s\S]+)$/i.exec(s))) {
      const dbName = requireDb();
      if (dbName) {
        sandbox.views ||= {};
        sandbox.views[dbName] ||= {};
        sandbox.views[dbName][m[1]] = { name: m[1], query: m[2], columns: [], rows: [], isView: true };
        add({ status: 'ok', message: `created_view(${m[1]})` });
      }
    } else if ((m = /^DROP VIEW(?: IF EXISTS)? `?([\w$]+)`?$/i.exec(s))) {
      const dbName = requireDb();
      if (dbName) {
        delete sandbox.views?.[dbName]?.[m[1]];
        add({ status: 'ok', message: `dropped_view(${m[1]})` });
      }
    } else if ((m = /^DROP TABLE(?: IF EXISTS)? `?([\w$]+)`?$/i.exec(s))) {
      const dbName = requireDb();
      if (dbName) {
        const db = sandbox.dbs[dbName] || {};
        delete db[m[1]];
        add({ status: 'ok', message: `dropped_table(${m[1]})` });
      }
    } else if ((m = /^TRUNCATE(?: TABLE)? `?([\w$]+)`?$/i.exec(s))) {
      const dbName = requireDb();
      if (dbName) {
        const table = sandbox.dbs[dbName]?.[m[1]];
        if (table) table.rows = [];
        add({ status: 'ok', message: `truncated_table(${m[1]})` });
      }
    } else if ((m = /^CREATE TABLE(?: IF NOT EXISTS)? `?([\w$]+)`? \((.*)\)(?: .*)?$/i.exec(s))) {
      const dbName = requireDb();
      if (dbName) {
        const table = m[1];
        const cols = splitTopLevel(m[2]).map(x => x.trim()).filter(Boolean).map(def => {
          const parts = def.split(/\s+/);
          return { name: parts[0].replace(/[`"]/g, ''), type: parts.slice(1).join(' ') || 'TEXT' };
        }).filter(c => !/^(primary|key|constraint|unique|index|foreign|check)$/i.test(c.name));
        sandbox.dbs[dbName] ||= {};
        sandbox.dbs[dbName][table] = { columns: cols, rows: [], indexes: defaultIndexesForTable(table, { columns: cols }) };
        add({ status: 'ok', message: `created_table(${table})` });
      }
    } else if ((m = /^ALTER\s+TABLE\s+`?([\w$]+)`?\s+([\s\S]+)$/i.exec(s))) {
      const dbName = requireDb();
      if (!dbName) continue;
      const table = m[1];
      const operations = splitTopLevel(m[2]).map(parseAlterOperation);
      const error = applySandboxAlter(sandbox.dbs[dbName] || {}, table, operations);
      if (error) add({ status: 'error', message: error });
      else add({ status: 'ok', message: `altered_table(${table})` });
    } else if ((m = /^CREATE\s+(UNIQUE\s+)?INDEX\s+`?([\w$]+)`?\s+ON\s+`?([\w$]+)`?\s*\((.*?)\)$/i.exec(s))) {
      const dbName = requireDb();
      if (!dbName) continue;
      const table = m[3];
      const t = sandbox.dbs[dbName]?.[table];
      if (!t) add({ status: 'error', message: `table not found: ${table}` });
      else {
        t.indexes ||= [];
        t.indexes = t.indexes.filter(index => index.name !== m[2]);
        t.indexes.push({ name: m[2], columns: splitTopLevel(m[4]).map(x => x.trim().replace(/[`"]/g, '')), unique: Boolean(m[1]) });
        add({ status: 'ok', message: `created_index(${m[2]},${table})` });
      }
    } else if ((m = /^INSERT INTO `?([\w$]+)`?(?: \((.*?)\))? VALUES (.*)$/i.exec(s))) {
      const dbName = requireDb();
      if (!dbName) continue;
      const table = m[1];
      const t = sandbox.dbs[dbName]?.[table];
      if (!t) {
        add({ status: 'error', message: `table not found: ${table}` });
      } else {
        const cols = m[2] ? splitTopLevel(m[2]).map(x => x.trim().replace(/[`"]/g, '')) : t.columns.map(c => c.name);
        const groups = splitValueGroups(m[3]);
        for (const group of groups) {
          const values = splitTopLevel(group).map(parseValue);
          const row = {};
          cols.forEach((c, i) => row[c] = values[i] ?? null);
          t.rows.push(row);
        }
        add({ status: 'ok', message: `inserted(${table},${groups.length})` });
      }
    } else if ((m = /^SELECT \* FROM `?([\w$]+)`?(?: LIMIT (\d+))?$/i.exec(s))) {
      const dbName = requireDb();
      if (!dbName) continue;
      const table = m[1];
      const t = sandbox.dbs[dbName]?.[table];
      if (!t) add({ status: 'error', message: `table not found: ${table}` });
      else {
        const rows = (m[2] ? t.rows.slice(0, Number(m[2])) : t.rows).map(r => t.columns.map(c => r[c.name] ?? null));
        add({ status: 'table', columns: t.columns.map(c => c.name), rows });
      }
    } else if ((m = /^DESCRIBE `?([\w$]+)`?$/i.exec(s))) {
      const dbName = requireDb();
      if (!dbName) continue;
      const table = m[1];
      const t = sandbox.dbs[dbName]?.[table];
      if (!t) add({ status: 'error', message: `table not found: ${table}` });
      else add({ status: 'table', columns: ['Field', 'Type', 'Null', 'Key', 'Default', 'Extra'], rows: sandboxDescribeRows(t) });
    } else if ((m = /^SHOW\s+(?:INDEX|INDEXES|KEYS)\s+FROM\s+`?([\w$]+)`?$/i.exec(s))) {
      const dbName = requireDb();
      if (!dbName) continue;
      const table = m[1];
      const t = sandbox.dbs[dbName]?.[table];
      if (!t) add({ status: 'error', message: `table not found: ${table}` });
      else {
        const rows = (t.indexes || []).flatMap(index => (index.columns || []).map((column, i) => [table, index.unique ? 0 : 1, index.name, i + 1, column]));
        add({ status: 'table', columns: ['table', 'non_unique', 'key_name', 'seq_in_index', 'column_name'], rows });
      }
    } else if (/^SHOW DATABASES$/i.test(s)) {
      add({ status: 'table', columns: ['database'], rows: visibleDbNames().map(x => [x]) });
    } else if (/^SHOW TABLES$/i.test(s)) {
      const dbName = requireDb();
      if (dbName) {
        const db = sandbox.dbs[dbName] || {};
        const names = [...Object.keys(db), ...Object.keys(sandbox.views?.[dbName] || {}).filter(name => !db[name])].sort((a, b) => a.localeCompare(b));
        add({ status: 'table', columns: [`Tables_in_${dbName}`], rows: names.map(x => [x]) });
      }
    } else if (/^(START TRANSACTION|BEGIN|COMMIT|ROLLBACK)$/i.test(s)) {
      add({ status: 'ok', message: s.toLowerCase().replace(/\s+/g, '_') });
    } else {
      add({ status: 'error', message: `sandbox belum support: ${s}` });
    }
  }
  saveSandbox();
  renderTableBrowser();
  return { results };
}

function sandboxExecWithOptions(sql, options = {}) {
  const all = [];
  for (const stmt of splitStatements(sql)) {
    const data = sandboxExec(`${stmt};`);
    all.push(...(data.results || []));
    if (options.stopOnError && data.results?.some(r => r.status === 'error')) break;
  }
  return {
    results: options.showOnlyErrors ? all.filter(r => r.status === 'error') : all,
    allResults: all,
  };
}

function setSqlRunBusy(busy) {
  runBtn.disabled = busy;
  runBtn.setAttribute('aria-busy', busy ? 'true' : 'false');
  runBtn.textContent = busy ? 'Running...' : 'Run SQL';
}

function runSql() {
  if (sqlRunPromise) return sqlRunPromise;
  stopAsaRunSounds();
  setSqlRunBusy(true);
  sqlRunPromise = runSqlOnce().finally(() => {
    sqlRunPromise = null;
    setSqlRunBusy(false);
  });
  return sqlRunPromise;
}

async function runSqlOnce() {
  // Audio priming must never delay or gate the first query click.
  void primeAsaRunSounds();
  applySqlAutoCorrection(true);
  updateSqlEditor();
  clearTimeout(sqlAnalyzeTimer);
  sqlAnalyzeTimer = 0;
  sqlAnalyzeRequest += 1;
  const sql = sqlInput.value;
  setSqlDiagnostics(analyzeSqlClient(sql));
  const started = performance.now();
  let data;
  if (backendOnline) {
    try {
      data = shouldBatchBackendSql(sql)
        ? await executeBackendSqlBatched(sql, {
            stopOnError: true,
            syncFinal: 'none',
            onProgress: ({ completed, total, label }) => noteArchiveSqlProgress(sql, completed, total, label),
          })
        : await executeBackendSql(sql, { sync: false });
    } catch (err) {
      data = { results: [{ status: 'error', message: `Backend Prolog gagal: ${err.message}` }] };
      log(`Backend Prolog failed: ${err.message}`);
    }
  } else {
    data = sandboxExec(sql);
  }
  renderResults(data.results || [data]);
  addRuntimeDiagnostics(data.results || [data]);
  playAsaRunSound(resultSetHasError(data) ? 'error' : 'ok');
  lastRun.textContent = `${Math.round(performance.now() - started)} ms`;
  log(`Executed ${splitStatements(sql).length} statement(s).`);
  await refreshBrowserAfterRun(sql, data);
}

async function refreshBrowserAfterRun(sql, data) {
  if (!backendOnline) {
    renderTableBrowser();
    return;
  }

  const synced = await syncCatalogFromBackend().catch(err => {
    log(`Post-run sync skipped: ${err.message}`);
    return false;
  });
  if (!synced) log('Post-run catalog refresh was unavailable.');

  renderTableBrowser();
}

function shouldBatchBackendSql(sql) {
  return String(sql || '').length > 180000 || splitStatementsDetailed(sql).length > 12;
}

function renderResults(results) {
  resultBox.innerHTML = '';
  const fragment = document.createDocumentFragment();
  for (const r of results) {
    const item = document.createElement('div');
    item.className = 'result-item';
    if (r.status === 'table') {
      const scroll = document.createElement('div');
      scroll.className = 'result-table-scroll';
      const table = renderTable(r.columns || [], r.rows || []);
      table.classList.add('result-data-table');
      scroll.appendChild(table);
      item.appendChild(scroll);
      if (r.has_more) {
        const note = document.createElement('div');
        note.className = 'result-page-note';
        note.textContent = `${formatNumber(r.returned_rows || (r.rows || []).length)} rows shown. More rows are available.`;
        item.appendChild(note);
      }
    } else if (r.status === 'ok') {
      item.innerHTML = `<div class="ok-text">${r.line ? `<span class="result-line">Line ${r.line}</span>` : ''}${escapeHtml(ASA_OK_LABEL)}: ${escapeHtml(asaResultCopy(r))}</div>`;
    } else {
      item.innerHTML = `<div class="error-text">${r.line ? `<span class="result-line">Line ${r.line}</span>` : ''}${escapeHtml(ASA_ERROR_LABEL)}: ${escapeHtml(asaResultCopy(r))}</div>`;
    }
    fragment.appendChild(item);
  }
  resultBox.appendChild(fragment);
  noteArchiveQuery(results, sqlInput?.value || '');
}

function renderTable(columns, rows) {
  const table = document.createElement('table');
  table.innerHTML = `<thead><tr>${columns.map(c => `<th>${escapeHtml(c)}</th>`).join('')}</tr></thead>`;
  const tbody = document.createElement('tbody');
  const fragment = document.createDocumentFragment();
  for (const row of rows) {
    const tr = document.createElement('tr');
    tr.innerHTML = row.map(v => `<td>${escapeHtml(v === null ? 'NULL' : String(v))}</td>`).join('');
    fragment.appendChild(tr);
  }
  tbody.appendChild(fragment);
  table.appendChild(tbody);
  return table;
}

function renderTableBrowser() {
  renderDbSelector();
  const activeDb = currentDbName();
  const db = activeDb ? (sandbox.dbs[activeDb] || {}) : {};
  const dbViews = activeDb ? (sandbox.views?.[activeDb] || {}) : {};
  const relations = [
    ...Object.keys(db).map(name => ({ name, kind: 'table' })),
    ...Object.keys(dbViews).filter(name => !db[name]).map(name => ({ name, kind: 'view' })),
  ].sort((a, b) => a.name.localeCompare(b.name) || a.kind.localeCompare(b.kind));
  const filter = tableSearch.value.trim().toLowerCase();
  const visible = relations.filter(item => item.name.toLowerCase().includes(filter));

  tableCount.textContent = activeDb
    ? relationCountText(visible.length, relations.length, Object.keys(db).length, Object.keys(dbViews).length, filter)
    : 'No database selected';
  tableList.innerHTML = '';

  for (const item of visible) {
    const row = document.createElement('div');
    row.className = `table-row ${item.kind}-row`;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `table-link${item.kind === 'view' ? ' view-link' : ''}${item.name === selectedTable ? ' active' : ''}`;
    button.dataset.table = item.name;
    button.dataset.kind = item.kind;
    button.innerHTML = `<span class="${item.kind === 'view' ? 'view-icon' : 'table-icon'}" aria-hidden="true"></span><span class="table-name">${escapeHtml(item.name)}</span>${item.kind === 'view' ? '<span class="relation-badge">VIEW</span>' : ''}`;
    const drop = document.createElement('button');
    drop.type = 'button';
    drop.className = 'drop-table-button';
    drop.dataset.dropTable = item.name;
    drop.dataset.kind = item.kind;
    drop.title = `Drop ${item.kind} ${item.name}`;
    drop.setAttribute('aria-label', `Drop ${item.kind} ${item.name}`);
    drop.innerHTML = '<span class="drop-icon" aria-hidden="true"></span>';
    row.append(button, drop);
    tableList.appendChild(row);
  }
  renderExportTablePicker();
  updateArchiveMonitor();
}

function relationCountText(visibleCount, totalCount, tableCountValue, viewCount, filter) {
  if (filter) return `${visibleCount} of ${totalCount} objects`;
  return viewCount ? `${tableCountValue} tables, ${viewCount} views` : `${tableCountValue} tables`;
}

function renderDbSelector() {
  const names = visibleDbNames();
  const activeDb = currentDbName();
  dbSelect.innerHTML = '<option value="">Select DB</option>' +
    names.map(name => `<option value="${escapeHtml(name)}">${escapeHtml(name)}</option>`).join('');
  dbSelect.value = activeDb && names.includes(activeDb) ? activeDb : '';
  dbName.value = activeDb || '';
}

function renderExportTablePicker() {
  if (!exportTableRows) return;
  const current = collectExportSelections();
  const activeDb = currentDbName();
  const db = activeDb ? (sandbox.dbs[activeDb] || {}) : {};
  const tables = Object.keys(db).sort((a, b) => a.localeCompare(b));
  exportDbName.textContent = activeDb || 'No database selected';
  exportTableRows.innerHTML = '';

  for (const table of tables) {
    const row = document.createElement('tr');
    const tableChecked = current.tables[table] ?? true;
    const dataChecked = current.data[table] ?? true;
    row.innerHTML = `
      <td><label><input class="export-table-check" data-table="${escapeHtml(table)}" type="checkbox" ${tableChecked ? 'checked' : ''} /> ${escapeHtml(table)}</label></td>
      <td><input class="export-data-check" data-table="${escapeHtml(table)}" type="checkbox" ${dataChecked ? 'checked' : ''} /></td>
    `;
    exportTableRows.appendChild(row);
  }
}

function collectExportSelections() {
  const tables = {};
  const data = {};
  document.querySelectorAll('.export-table-check').forEach(input => tables[input.dataset.table] = input.checked);
  document.querySelectorAll('.export-data-check').forEach(input => data[input.dataset.table] = input.checked);
  return { tables, data };
}

function getExportSelection() {
  const activeDb = currentDbName();
  const db = activeDb ? (sandbox.dbs[activeDb] || {}) : {};
  const checked = collectExportSelections();
  const includeDataGlobally = exportDataMode.value !== 'none';
  const includeSchema = exportTableMode.value !== 'none';
  return Object.keys(db).filter(table => checked.tables[table] ?? true).map(table => ({
    name: table,
    table: db[table],
    includeData: includeDataGlobally && (checked.data[table] ?? true),
    includeSchema,
  }));
}

function escapeHtml(s) {
  return String(s).replace(/[&<>'"]/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[ch]));
}

async function createDatabase() {
  const nextDb = sanitizeIdentifier(dbName.value);
  if (!nextDb) {
    log('Create DB failed: database name is empty.');
    return;
  }
  const sql = `CREATE DATABASE IF NOT EXISTS ${quoteIdent(nextDb)};\nUSE ${quoteIdent(nextDb)};`;
  setSqlText(sql);
  if (backendOnline) {
    try {
      const data = await executeBackendSql(sql);
      renderResults(data.results || [data]);
      log(`Created and selected database ${nextDb}.`);
    } catch (err) {
      backendOnline = false;
      log(`Backend DB create failed, fallback sandbox: ${err.message}`);
      sandboxExec(sql);
    }
  } else {
    sandboxExec(sql);
  }
  sandbox.currentDb = nextDb;
  sandbox.dbs[nextDb] ||= {};
  sandbox.views ||= {};
  sandbox.views[nextDb] ||= {};
  saveSandbox();
  selectedTable = '';
  renderTableBrowser();
  showView('sql');
}

async function selectDatabaseByName(nextDb) {
  if (!nextDb || (!sandbox.dbs[nextDb] && !sandbox.views?.[nextDb])) return;
  const sql = `USE ${quoteIdent(nextDb)};`;
  if (backendOnline) {
    try {
      await executeBackendSql(sql);
    } catch (err) {
      backendOnline = false;
      log(`Backend DB select failed, using browser state: ${err.message}`);
    }
  }
  sandbox.currentDb = nextDb;
  sandbox.dbs[nextDb] ||= {};
  sandbox.views ||= {};
  sandbox.views[nextDb] ||= {};
  selectedTable = '';
  saveSandbox();
  renderTableBrowser();
  log(`Selected database ${nextDb}.`);
}

async function saveCurrentDatabase() {
  const db = ensureCurrentDb('save database');
  if (!db) return;
  let data = null;

  if (backendOnline) {
    try {
      data = await saveBackendDatabase();
      await syncBackendStateSmart();
    } catch (err) {
      backendOnline = false;
      engineStatus.textContent = 'Mode: browser sandbox';
      engineStatus.className = 'status warn';
      log(`Backend save failed, saved browser state only: ${err.message}`);
    }
  }

  saveSandbox();
  if (!data) data = { results: [{ status: 'ok', message: `saved_database(${db})` }] };
  renderResults(data.results || [data]);
  renderTableBrowser();
  log(`Saved database ${db}.`);
}

async function dropCurrentDatabase() {
  const db = ensureCurrentDb('drop database');
  if (!db) return;
  if (!confirm(`Drop database "${db}" permanently? Semua table dan view di dalamnya akan dihapus.`)) return;

  const sql = `DROP DATABASE ${quoteIdent(db)};`;
  setSqlText(sql);
  let data;

  if (backendOnline) {
    try {
      data = await executeBackendSql(sql);
    } catch (err) {
      backendOnline = false;
      engineStatus.textContent = 'Mode: browser sandbox';
      engineStatus.className = 'status warn';
      log(`Backend drop database failed, fallback sandbox: ${err.message}`);
    }
  }

  if (!data) data = sandboxExec(sql);
  renderResults(data.results || [data]);
  if (hasResultError(data)) {
    log(`Drop database ${db} failed.`);
    return;
  }

  delete sandbox.dbs[db];
  if (sandbox.views) delete sandbox.views[db];
  if (sandbox.currentDb === db) sandbox.currentDb = '';
  selectedTable = '';
  saveSandbox();
  renderTableBrowser();
  showView('sql');
  log(`Dropped database ${db}.`);
}

function focusSqlCommand() {
  showView('sql');
  sqlInput.focus();
  sqlInput.setSelectionRange(sqlInput.value.length, sqlInput.value.length);
}

function insertCreateTableTemplate() {
  showCreateTableView();
}

function selectTable(table) {
  selectedTable = table;
  renderTableDetail(table, 'structure');
  renderTableBrowser();
}

async function dropTable(tableName) {
  const db = ensureCurrentDb('drop table');
  if (!db || !tableName) return;
  const relation = currentRelation(tableName);
  const kind = relation?.kind || 'table';
  if (!confirm(`Drop ${kind} "${tableName}" from database "${db}"?`)) return;
  const sql = kind === 'view' ? `DROP VIEW IF EXISTS ${quoteIdent(tableName)};` : `DROP TABLE IF EXISTS ${quoteIdent(tableName)};`;
  if (backendOnline) {
    try {
      const data = await executeBackendSql(sql);
      renderResults(data.results || [data]);
    } catch (err) {
      backendOnline = false;
      log(`Backend drop failed, fallback sandbox: ${err.message}`);
      sandboxExec(sql);
    }
  } else {
    sandboxExec(sql);
  }
  if (kind === 'view') delete sandbox.views?.[db]?.[tableName];
  else delete sandbox.dbs[db]?.[tableName];
  if (selectedTable === tableName) selectedTable = '';
  saveSandbox();
  renderTableBrowser();
  if (views.table && !selectedTable) showView('sql');
  log(`Dropped ${kind} ${tableName}.`);
}

function showCreateTableView() {
  createTableName.value = '';
  createEngine.value = 'AsaDB';
  createCollation.value = '';
  createAutoIncrement.value = '';
  createDefaultValues.checked = false;
  createComment.checked = false;
  createAllAutoIncrement.checked = false;
  createColumnsBody.innerHTML = '';
  addCreateColumnRow({ name: '', type: 'int', length: '', options: '', nullable: false, autoIncrement: false });
  showView('create', 'create');
  createTableName.focus();
}

function renderTableDetail(tableName, mode = 'structure') {
  const relation = currentRelation(tableName);
  if (!relation) return;
  const table = relation.value;

  selectedTable = tableName;
  tableDetailName.textContent = relation.kind === 'view' ? `${tableName} (view)` : tableName;
  tableStructurePanel.hidden = mode !== 'structure';
  tableDataPanel.hidden = mode !== 'data';
  tableSelectDataBtn.classList.toggle('strong', mode === 'data');
  tableShowStructureBtn.classList.toggle('strong', mode === 'structure');
  tableAlterBtn.disabled = relation.kind === 'view';
  tableNewItemBtn.disabled = relation.kind === 'view';

  if (relation.kind === 'view') {
    if (mode === 'data') renderViewDataDetail(tableName);
    else renderViewStructureDetail(tableName, table);
  } else if (mode === 'data') renderTableDataDetail(tableName, table);
  else renderTableStructureDetail(tableName, table);

  showView('table', `table=${encodeURIComponent(tableName)}`);
}

function currentTable(tableName) {
  const activeDb = currentDbName();
  return activeDb ? (sandbox.dbs[activeDb]?.[tableName] || null) : null;
}

function currentView(viewName) {
  const activeDb = currentDbName();
  return activeDb ? (sandbox.views?.[activeDb]?.[viewName] || null) : null;
}

function currentRelation(name) {
  const table = currentTable(name);
  if (table) return { kind: 'table', value: table };
  const view = currentView(name);
  if (view) return { kind: 'view', value: view };
  return null;
}

function renderViewStructureDetail(viewName, view) {
  tableStructureBody.innerHTML = `
    <tr>
      <td>${escapeHtml(viewName)}</td>
      <td>VIEW</td>
      <td>${escapeHtml(view.query || 'SELECT-backed view')}</td>
    </tr>
  `;
  tableIndexBody.innerHTML = '<tr><td>VIEW</td><td class="index-column">virtual result</td></tr>';
}

async function renderViewDataDetail(viewName) {
  tableDataBox.innerHTML = '<div class="empty-state">Loading view...</div>';
  if (!backendOnline) {
    tableDataBox.innerHTML = '<div class="empty-state">View data needs the Prolog backend.</div>';
    return;
  }
  try {
    const data = await executeBackendSql(`SELECT * FROM ${quoteIdent(viewName)};`);
    const result = (data.results || [data]).find(item => item.status === 'table');
    if (!result) throw new Error(data.message || 'View did not return a table.');
    tableDataBox.innerHTML = '';
    const tableNode = renderTable(result.columns || [], result.rows || []);
    tableNode.classList.add('legacy-data-table');
    tableDataBox.appendChild(tableNode);
  } catch (err) {
    tableDataBox.innerHTML = `<div class="empty-state error-text">${escapeHtml(ASA_ERROR_LABEL)}: ${escapeHtml(asaErrorCopy(err.message))}</div>`;
  }
}

function renderTableStructureDetail(tableName, table) {
  tableStructureBody.innerHTML = '';
  for (const column of table.columns || []) {
    const row = document.createElement('tr');
    row.innerHTML = `
      <td>${escapeHtml(column.name)}</td>
      <td>${columnTypeHtml(column)}</td>
      <td>${escapeHtml(column.comment || '')}</td>
    `;
    tableStructureBody.appendChild(row);
  }

  const indexes = table.indexes?.length ? table.indexes : defaultIndexesForTable(tableName, table);
  tableIndexBody.innerHTML = '';
  for (const index of indexes) {
    const row = document.createElement('tr');
    row.innerHTML = `
      <td>${escapeHtml(index.name || 'INDEX')}</td>
      <td class="index-column">${escapeHtml((index.columns || []).join(', '))}</td>
    `;
    tableIndexBody.appendChild(row);
  }
}

async function renderTableDataDetail(tableName, table) {
  tableDataBox.innerHTML = '';
  const columns = (table.columns || []).map(col => col.name);
  const localRows = (table.rows || []).map(row => columns.map(column => row[column] ?? null));
  const remoteRows = Number(table.rowCount) || 0;

  if (backendOnline && remoteRows > localRows.length) {
    tableDataBox.innerHTML = '<div class="empty-state">Loading backend preview...</div>';
    try {
      const data = await executeBackendSql(`SELECT * FROM ${quoteIdent(tableName)} LIMIT 100;`, { sync: false });
      const result = (data.results || [data]).find(item => item.status === 'table');
      if (!result) throw new Error(data.message || 'Table preview did not return rows.');
      tableDataBox.innerHTML = '';
      const tableNode = renderTable(result.columns || columns, result.rows || []);
      tableNode.classList.add('legacy-data-table');
      tableDataBox.appendChild(tableNode);
      if (remoteRows > (result.rows || []).length) {
        const note = document.createElement('div');
        note.className = 'empty-state';
        note.textContent = `Showing ${Math.min(100, (result.rows || []).length)} of ${formatNumber(remoteRows)} backend row(s).`;
        tableDataBox.appendChild(note);
      }
      return;
    } catch (err) {
      tableDataBox.innerHTML = `<div class="empty-state error-text">${escapeHtml(ASA_ERROR_LABEL)}: ${escapeHtml(asaErrorCopy(err.message))}</div>`;
      return;
    }
  }

  const rows = localRows;
  const tableNode = renderTable(columns, rows);
  tableNode.classList.add('legacy-data-table');
  tableDataBox.appendChild(tableNode);
}

function columnTypeHtml(column) {
  const bits = [escapeHtml(column.type || 'TEXT')];
  if (column.extra) bits.push(`<em>${escapeHtml(column.extra)}</em>`);
  if (Object.prototype.hasOwnProperty.call(column, 'default')) bits.push(`[${escapeHtml(column.default ?? '')}]`);
  return bits.join(' ');
}

function defaultIndexesForTable(tableName, table) {
  const columns = table.columns || [];
  if (!columns.length) return [];
  const first = columns[0].name;
  const indexes = [{ name: 'PRIMARY', columns: [first] }];
  const visible = columns.find(col => /visible|status|slug|name/i.test(col.name));
  if (visible && visible.name !== first) indexes.push({ name: 'INDEX', columns: [visible.name] });
  return indexes;
}

function addCreateColumnRow(column = {}) {
  const row = document.createElement('tr');
  row.innerHTML = `
    <td><input class="create-col-name" value="${escapeHtml(column.name || '')}" /></td>
    <td>
      <select class="create-col-type">
        ${['int', 'bigint', 'varchar', 'text', 'mediumtext', 'datetime', 'decimal'].map(type => `<option value="${type}" ${type === (column.type || 'int') ? 'selected' : ''}>${type}</option>`).join('')}
      </select>
    </td>
    <td><input class="create-col-length" value="${escapeHtml(column.length || '')}" /></td>
    <td>
      <select class="create-col-options">
        <option value="" ${!column.options ? 'selected' : ''}></option>
        <option value="unsigned" ${column.options === 'unsigned' ? 'selected' : ''}>unsigned</option>
        <option value="primary" ${column.options === 'primary' ? 'selected' : ''}>primary</option>
        <option value="unique" ${column.options === 'unique' ? 'selected' : ''}>unique</option>
      </select>
    </td>
    <td><input class="create-col-null" type="checkbox" ${column.nullable ? 'checked' : ''} /></td>
    <td><input class="create-col-auto-increment" type="radio" name="createAutoIncrementPick" ${column.autoIncrement ? 'checked' : ''} /></td>
    <td>
      <button class="mini-button create-row-add" type="button" title="Add column" aria-label="Add column">+</button>
      <button class="mini-button create-row-up" type="button" title="Move up" aria-label="Move column up">&uarr;</button>
      <button class="mini-button create-row-down" type="button" title="Move down" aria-label="Move column down">&darr;</button>
      <button class="mini-button create-row-delete" type="button" title="Delete column" aria-label="Delete column">x</button>
    </td>
  `;
  createColumnsBody.appendChild(row);
}

async function saveCreateTable(event) {
  event.preventDefault();
  const activeDb = ensureCurrentDb('create table');
  if (!activeDb) return;
  const tableName = sanitizeIdentifier(createTableName.value);
  if (!tableName) {
    log('Create table failed: table name is empty.');
    return;
  }

  const columns = [];
  const indexes = [];
  for (const row of Array.from(createColumnsBody.querySelectorAll('tr'))) {
    const name = sanitizeIdentifier(row.querySelector('.create-col-name')?.value);
    if (!name) continue;
    const type = row.querySelector('.create-col-type')?.value || 'int';
    const length = row.querySelector('.create-col-length')?.value.trim();
    const option = row.querySelector('.create-col-options')?.value || '';
    const nullable = row.querySelector('.create-col-null')?.checked;
    const autoIncrement = row.querySelector('.create-col-auto-increment')?.checked;
    const typeText = `${type}${length ? `(${length})` : ''}${option === 'unsigned' ? ' unsigned' : ''}`;
    const column = { name, type: typeText };
    if (!nullable) column.nullable = false;
    if (autoIncrement) column.extra = 'Auto Increment';
    if (createDefaultValues.checked) column.default = '';
    if (createComment.checked) column.comment = '';
    columns.push(column);
    if (autoIncrement || option === 'primary') indexes.push({ name: 'PRIMARY', columns: [name] });
    else if (option === 'unique') indexes.push({ name: 'UNIQUE', columns: [name] });
  }

  if (!columns.length) {
    log('Create table failed: add at least one column.');
    return;
  }

  const tableRecord = {
    columns,
    rows: [],
    indexes: indexes.length ? indexes : [{ name: 'PRIMARY', columns: [columns[0].name] }],
    engine: createEngine.value,
    collation: createCollation.value,
    autoIncrement: createAutoIncrement.value || '',
  };
  const createSql = `CREATE TABLE ${quoteIdent(tableName)} (\n${columns.map(column => {
    const nullable = column.nullable === false ? ' NOT NULL' : '';
    const extra = column.extra ? ' AUTO_INCREMENT' : '';
    return `  ${quoteIdent(column.name)} ${column.type || 'TEXT'}${nullable}${extra}`;
  }).join(',\n')}\n);`;

  if (backendOnline) {
    try {
      const data = await executeBackendSql(createSql);
      renderResults(data.results || [data]);
    } catch (err) {
      backendOnline = false;
      log(`Backend create table failed, keeping browser state: ${err.message}`);
    }
  }

  sandbox.dbs[activeDb] ||= {};
  sandbox.dbs[activeDb][tableName] = tableRecord;
  saveSandbox();
  renderTableBrowser();
  log(`Created table ${tableName}.`);
  renderTableDetail(tableName, 'structure');
}

function detectImportFormat(fileName, bytes, textHint = '') {
  const name = fileName.toLowerCase().replace(/\.gz$/, '');
  if (name.endsWith('.asa') || name.endsWith('.asadb') || name.endsWith('.json')) return 'asadb';
  if (name.endsWith('.csv')) return 'csv';
  if (name.endsWith('.xlsx') || name.endsWith('.xls')) return 'xlsx';
  if (name.endsWith('.pgsql') || name.endsWith('.psql') || name.endsWith('.postgres')) return 'postgresql';
  if (name.endsWith('.mysql')) return 'mysql';
  const text = textHint.slice(0, 12000);
  if (/COPY\s+[\w".]+\s*(\(|FROM)\s+/i.test(text) || /SET\s+search_path/i.test(text) || /\bSERIAL\b/i.test(text)) return 'postgresql';
  if (/ENGINE\s*=|LOCK TABLES|UNLOCK TABLES|`[^`]+`|\/\*!/i.test(text)) return 'mysql';
  return 'mysql';
}

async function importFromFiles() {
  const files = Array.from(importFileInput.files || []);
  if (!files.length) {
    importSummary.textContent = 'No file selected.';
    return;
  }
  const summaries = [];
  for (const file of files) {
    try {
      const useBackendSql = backendOnline && shouldUseBackendFileImport(file.name, importFormat.value);
      const backendPath = useBackendSql ? knownServerImportPath(file.name) : '';
      let summary;
      if (backendPath) {
        try {
          summary = await importServerPathWithBackend(backendPath, file.size);
        } catch (backendErr) {
          log(`Backend file import rejected for ${file.name}, trying upload stream: ${backendErr.message}`);
          summary = await importUploadedFileWithBackend(file);
        }
      } else if (useBackendSql && shouldUploadFileToBackend(file)) {
        summary = await importUploadedFileWithBackend(file);
      } else if (!backendOnline && shouldUseBackendFileImport(file.name, importFormat.value) && file.size > BROWSER_SQL_IMPORT_LIMIT_BYTES) {
        throw new Error('Prolog backend belum online. File SQL besar harus lewat engine backend supaya browser tidak macet.');
      } else {
        summary = await importFromBuffer(file.name, await file.arrayBuffer(), importFormat.value);
      }
      summaries.push(summary);
    } catch (err) {
      summaries.push(`${file.name}: ${ASA_ERROR_LABEL} ${asaErrorCopy(err.message)}`);
      log(`Import failed for ${file.name}: ${err.message}`);
      if (importStopOnError.checked) break;
    }
  }
  importFileInput.value = '';
  importSummary.textContent = summaries.join('\n');
  renderTableBrowser();
}

async function importFromServerFile() {
  const path = importServerPath.value.trim();
  if (!path) return;
  try {
    if (backendOnline && shouldUseBackendFileImport(path, importFormat.value)) {
      importSummary.textContent = await importServerPathWithBackend(path);
      return;
    }
    if (!backendOnline && isKnownHugeServerImport(path)) {
      throw new Error('Prolog backend wajib online untuk import file SQL besar dari server.');
    }
    const res = await fetch(path, { cache: 'no-store' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const summary = await importFromBuffer(path, await res.arrayBuffer(), importFormat.value);
    importSummary.textContent = summary;
  } catch (err) {
    importSummary.textContent = `${ASA_ERROR_LABEL}: ${asaErrorCopy(err.message)}`;
    log(`Server import failed: ${err.message}`);
  }
}

function shouldUseBackendFileImport(path, selectedFormat) {
  const clean = String(path || '').replace(/\\/g, '/').replace(/^\/+/, '');
  if (/\.gz$/i.test(clean)) return false;
  const sqlPath = /\.(sql|mysql|pgsql|psql|postgres)$/i.test(clean);
  const sqlFormat = selectedFormat === 'auto' || selectedFormat === 'mysql' || selectedFormat === 'postgresql';
  return sqlPath && sqlFormat;
}

function shouldUploadFileToBackend(file) {
  if (!file) return false;
  return Number(file.size || 0) >= BACKEND_UPLOAD_IMPORT_MIN_BYTES || shouldUseBackendFileImport(file.name, importFormat.value);
}

function knownServerImportPath(fileName) {
  const name = String(fileName || '').split(/[\\/]/).pop();
  if (/^public_safety_archive_1275080\.sql$/i.test(name)) return 'test/public_safety_archive_1275080.sql';
  if (/^public_safety_archive_\d+\.sql$/i.test(name)) return `Stress Test/${name}`;
  return '';
}

function isKnownHugeServerImport(path) {
  return /(?:^|[\\/])public_safety_archive_1275080\.sql$/i.test(String(path || ''));
}

function makeImportId() {
  return `import-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

async function importServerPathWithBackend(path, sizeHint = 0) {
  const importId = makeImportId();
  noteArchiveImportStart(path, sizeHint);
  log(`Backend import started: ${path}`);
  const body = new URLSearchParams({
    path,
    import_id: importId,
    stop_on_error: importStopOnError.checked ? 'true' : 'false',
  });
  const res = await fetch('/api/import_file', {
    method: 'POST',
    headers: apiHeaders({ 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' }),
    body,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`);

  const results = data.results || [data];
  renderResults(results);
  const summaryTable = results.find(result => result.status === 'table');
  const row = summaryTable?.rows?.[0] || [];
  const status = row[0] || 'ok';
  const statements = Number(row[2]) || 0;
  const errors = Number(row[3]) || 0;
  const sizeBytes = Number(row[6]) || sizeHint || 0;

  await syncCatalogFromBackend().catch(() => false);
  noteArchiveImportComplete(path, sizeBytes, summaryTable?.columns || ['status'], summaryTable?.rows || [[status]], statements);
  setSqlText(`-- Backend Prolog import: ${path}\nSHOW TABLES;\nSELECT COUNT(*) AS total_rows FROM Public_Safety_Archive;`);
  lastRun.textContent = `${statements} backend step(s)`;
  renderTableBrowser();
  const summary = `${path}: backend Prolog import, ${statements} statement(s), ${errors} error(s)`;
  log(summary);
  if (errors > 0) throw new Error(summary);
  return summary;
}

async function importUploadedFileWithBackend(file) {
  const importId = makeImportId();
  noteArchiveImportStart(file.name, file.size || 0);
  log(`Backend upload import started: ${file.name}`);
  const body = new FormData();
  body.append('file', file, file.name);
  body.append('import_id', importId);
  body.append('stop_on_error', importStopOnError.checked ? 'true' : 'false');

  const res = await fetch('/api/import_upload', {
    method: 'POST',
    headers: apiHeaders(),
    body,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`);

  const results = data.results || [data];
  renderResults(results);
  const summaryTable = results.find(result => result.status === 'table');
  const row = summaryTable?.rows?.[0] || [];
  const status = row[0] || 'ok';
  const statements = Number(row[2]) || 0;
  const errors = Number(row[3]) || 0;
  const sizeBytes = Number(row[6]) || file.size || 0;

  await syncBackendStateSmart().catch(() => syncCatalogFromBackend().catch(() => false));
  noteArchiveImportComplete(file.name, sizeBytes, summaryTable?.columns || ['status'], summaryTable?.rows || [[status]], statements);
  setSqlText(`-- Uploaded through Prolog backend: ${file.name}\nSHOW TABLES;`);
  lastRun.textContent = `${statements} backend step(s)`;
  renderTableBrowser();
  const summary = `${file.name}: backend Prolog upload import, ${statements} statement(s), ${errors} error(s)`;
  log(summary);
  if (errors > 0) throw new Error(summary);
  return summary;
}

async function importFromBuffer(name, rawBuffer, selectedFormat) {
  let buffer = rawBuffer;
  let cleanName = name;
  if (/\.gz$/i.test(cleanName)) {
    buffer = await gunzipBuffer(buffer);
    cleanName = cleanName.replace(/\.gz$/i, '');
  }

  const initialText = isLikelyText(cleanName) ? decodeText(buffer) : '';
  const format = selectedFormat === 'auto' ? detectImportFormat(cleanName, buffer, initialText) : selectedFormat;
  const mode = importWriteMode.value;
  let summary = `${name}: ${FORMAT_LABELS[format]} -> AsaDB`;
  noteArchiveImportStart(name, rawBuffer.byteLength || buffer.byteLength || 0);

  if (format === 'asadb') {
    const imported = parseAsaDbBuffer(buffer);
    mergeSandbox(imported, mode === 'replace');
    saveSandbox();
    const preview = firstImportedTablePreview(imported);
    noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, preview.columns, preview.rows, preview.rowCount);
    summary += `, ${countTables(imported)} table(s) loaded`;
  } else if (format === 'csv') {
    if (!ensureCurrentDb('import CSV')) throw new Error('Create or select a database before importing CSV.');
    const tableName = importTargetTable.value.trim() || sanitizeName(baseName(cleanName));
    const matrix = parseCsv(decodeText(buffer));
    upsertMatrixTable(tableName, matrix, mode);
    noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, matrix[0] || [], matrix.slice(1, 5), Math.max(0, matrix.length - 1));
    summary += `, table ${tableName}, ${Math.max(0, matrix.length - 1)} row(s)`;
  } else if (format === 'xlsx') {
    if (!ensureCurrentDb('import XLSX')) throw new Error('Create or select a database before importing XLSX.');
    const workbook = await readXlsxWorkbook(buffer);
    for (const sheet of workbook.sheets) {
      const tableName = sanitizeName(sheet.name || baseName(cleanName));
      upsertMatrixTable(tableName, sheet.rows, mode);
    }
    const firstSheet = workbook.sheets[0] || { rows: [] };
    noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, firstSheet.rows[0] || [], (firstSheet.rows || []).slice(1, 5), Math.max(0, (firstSheet.rows || []).length - 1));
    summary += `, ${workbook.sheets.length} sheet(s)`;
  } else if (format === 'mysql' || format === 'postgresql') {
    const sql = convertDialectToAsaSql(decodeText(buffer), format);
    let data;
    if (backendOnline) {
      data = await executeBackendSqlBatched(sql, {
        stopOnError: importStopOnError.checked,
        showOnlyErrors: importShowOnlyErrors.checked,
        maxVisible: 50,
        syncFinal: sql.length < 5 * 1024 * 1024,
        onProgress: ({ completed, total, label }) => noteArchiveSqlProgress(sql, completed, total, label),
      });
    } else if (sql.length > 100000) {
      throw new Error('Prolog backend belum online. Import SQL besar wajib lewat engine Prolog.');
    } else {
      data = sandboxExecWithOptions(sql, {
        stopOnError: importStopOnError.checked,
        showOnlyErrors: importShowOnlyErrors.checked,
      });
    }
    renderResults(data.results);
    if (sql.length < 500000) setSqlText(sql);
    else setSqlText(`-- Large SQL imported through Prolog backend: ${name}\nSHOW TABLES;`);
    lastRun.textContent = `${data.allResults.length} step(s)`;
    noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, ['statement', 'status'], data.allResults.slice(0, 4).map((result, index) => [index + 1, result.status || 'ok']), data.allResults.length);
    summary += `, ${splitStatements(sql).length} statement(s)`;
  } else {
    throw new Error(`Unsupported format: ${format}`);
  }

  saveSandbox();
  renderTableBrowser();
  log(summary);
  return summary;
}

function isLikelyText(name) {
  return /\.(asa|asadb|json|csv|sql|mysql|pgsql|psql|postgres|txt)$/i.test(name);
}

function decodeText(buffer) {
  return new TextDecoder('utf-8').decode(buffer).replace(/^\uFEFF/, '');
}

function countTables(state) {
  return Object.values(state.dbs || {}).reduce((sum, db) => sum + Object.keys(db || {}).length, 0);
}

function firstImportedTablePreview(state) {
  const normalized = normalizeSandbox(state);
  for (const db of Object.values(normalized.dbs || {})) {
    for (const table of Object.values(db || {})) {
      const columns = (table.columns || []).map(col => col.name || col);
      const rows = (table.rows || []).slice(0, 4).map(row => columns.map(column => row?.[column] ?? null));
      return { columns, rows, rowCount: table.rows?.length || 0 };
    }
  }
  return { columns: ['status'], rows: [['no table data']], rowCount: 0 };
}

function mergeSandbox(incoming, replace) {
  incoming = normalizeSandbox(incoming);
  if (replace) {
    sandbox = incoming;
    return;
  }
  sandbox.views ||= {};
  for (const [db, tables] of Object.entries(incoming.dbs)) {
    sandbox.dbs[db] ||= {};
    for (const [table, value] of Object.entries(tables)) {
      if (!sandbox.dbs[db][table]) {
        sandbox.dbs[db][table] = value;
      } else {
        const target = sandbox.dbs[db][table];
        const known = new Set(target.columns.map(c => c.name));
        for (const col of value.columns || []) {
          if (!known.has(col.name)) target.columns.push(col);
        }
        target.rows.push(...(value.rows || []));
      }
    }
  }
  for (const [db, dbViews] of Object.entries(incoming.views || {})) {
    sandbox.views[db] ||= {};
    for (const [view, value] of Object.entries(dbViews || {})) {
      sandbox.views[db][view] = value;
    }
  }
  sandbox.currentDb = incoming.currentDb || sandbox.currentDb;
}

function upsertMatrixTable(tableName, matrix, mode) {
  const activeDb = ensureCurrentDb('import table');
  if (!activeDb) throw new Error('Create or select a database before importing table data.');
  const rows = matrix.filter(row => row.some(cell => String(cell ?? '').trim() !== ''));
  if (!rows.length) return;
  const headers = rows[0].map((name, index) => sanitizeName(name || `column_${index + 1}`));
  const dataRows = rows.slice(1);
  const columns = headers.map((name, index) => ({ name, type: inferColumnType(dataRows.map(row => row[index])) }));
  const mappedRows = dataRows.map(row => {
    const out = {};
    headers.forEach((header, index) => out[header] = normalizeCellValue(row[index]));
    return out;
  });
  sandbox.dbs[activeDb] ||= {};
  if (mode === 'append' && sandbox.dbs[activeDb][tableName]) {
    const table = sandbox.dbs[activeDb][tableName];
    const known = new Set(table.columns.map(c => c.name));
    for (const col of columns) if (!known.has(col.name)) table.columns.push(col);
    table.rows.push(...mappedRows);
  } else {
    sandbox.dbs[activeDb][tableName] = { columns, rows: mappedRows };
  }
}

function inferColumnType(values) {
  const filled = values.map(normalizeCellValue).filter(v => v !== null && v !== '');
  if (filled.length && filled.every(v => typeof v === 'number')) return 'INT';
  return 'TEXT';
}

function normalizeCellValue(value) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value === 'number') return value;
  const text = String(value).trim();
  if (text === '') return null;
  if (/^-?\d+$/.test(text)) return Number(text);
  return text;
}

function parseCsv(text) {
  const rows = [];
  let row = [], cell = '', quote = false;
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quote) {
      if (ch === '"' && text[i + 1] === '"') {
        cell += '"';
        i += 1;
      } else if (ch === '"') {
        quote = false;
      } else {
        cell += ch;
      }
      continue;
    }
    if (ch === '"') quote = true;
    else if (ch === ',') { row.push(cell); cell = ''; }
    else if (ch === '\n') { row.push(cell); rows.push(row); row = []; cell = ''; }
    else if (ch !== '\r') cell += ch;
  }
  row.push(cell);
  if (row.length > 1 || row[0] !== '') rows.push(row);
  return rows;
}

function convertDialectToAsaSql(sql, dialect) {
  let out = sql.replace(/\r\n?/g, '\n').replace(/^\uFEFF/, '');
  out = out.replace(/\/\*![\s\S]*?\*\//g, '');
  out = out.replace(/\/\*[\s\S]*?\*\//g, '');
  out = out.split('\n').filter(line => !/^\s*(SET|LOCK TABLES|UNLOCK TABLES|DELIMITER|START TRANSACTION|COMMIT|ROLLBACK|BEGIN|ANALYZE)\b/i.test(line)).join('\n');
  out = out.replace(/CREATE\s+SCHEMA/gi, 'CREATE DATABASE');
  out = out.replace(/\b(public|dbo)\./gi, '');
  out = out.replace(/"([^"]+)"/g, '$1');
  out = out.replace(/\bBIGSERIAL\b/gi, 'INT');
  out = out.replace(/\bSERIAL\b/gi, 'INT');
  out = out.replace(/\bINTEGER\b/gi, 'INT');
  out = out.replace(/\bBYTEA\b/gi, 'TEXT');
  out = out.replace(/\bJSONB?\b/gi, 'TEXT');
  out = out.replace(/\bTIMESTAMP\s+WITHOUT\s+TIME\s+ZONE\b/gi, 'DATETIME');
  out = out.replace(/\bTIMESTAMP\s+WITH\s+TIME\s+ZONE\b/gi, 'DATETIME');
  out = out.replace(/\bBOOLEAN\b/gi, 'INT');
  out = out.replace(/::[A-Za-z_][\w]*/g, '');
  out = out.replace(/\bDEFAULT\s+nextval\('[^']+'\s*::regclass\)/gi, '');
  out = out.replace(/\bCOLLATE\s+["'`]?[A-Za-z0-9_.-]+["'`]?/gi, '');
  out = out.replace(/\)\s*(ENGINE|DEFAULT CHARSET|CHARSET|COLLATE|AUTO_INCREMENT)[^;]*;/gi, ');');
  out = out.replace(/ON\s+CONFLICT\s+[^;]+;/gi, ';');
  out = out.replace(/ALTER\s+TABLE\s+[`"]?([\w$]+)[`"]?\s+ADD\s+(UNIQUE\s+)?(?:KEY|INDEX)\s+[`"]?([\w$]+)[`"]?\s*\(([^)]+)\)\s*;/gi,
    (_m, table, unique, index, cols) => `CREATE ${unique ? 'UNIQUE ' : ''}INDEX ${index} ON ${table} (${cols.replace(/[`"]/g, '')});`);
  out = out.replace(/ALTER\s+TABLE\s+[^;]+;/gi, '');
  if (dialect === 'postgresql') out = convertCopyBlocks(out);
  return out;
}

function convertCopyBlocks(sql) {
  const lines = sql.split('\n');
  const out = [];
  for (let i = 0; i < lines.length; i += 1) {
    const m = /^\s*COPY\s+([\w."]+)\s*(?:\(([^)]*)\))?\s+FROM\s+stdin\s*;/i.exec(lines[i]);
    if (!m) {
      out.push(lines[i]);
      continue;
    }
    const table = m[1].replace(/"/g, '').split('.').pop();
    const columns = (m[2] || '').split(',').map(x => x.trim().replace(/"/g, '')).filter(Boolean);
    const rows = [];
    i += 1;
    while (i < lines.length && lines[i] !== '\\.') {
      rows.push(lines[i].split('\t').map(value => value === '\\N' ? null : value));
      i += 1;
    }
    if (columns.length) {
      for (const row of rows) {
        out.push(`INSERT INTO ${quoteIdent(table)} (${columns.map(quoteIdent).join(', ')}) VALUES (${row.map(sqlLiteral).join(', ')});`);
      }
    }
  }
  return out.join('\n');
}

async function exportDatabase() {
  const format = checkedValue('exportFormat');
  const output = checkedValue('exportOutput');
  try {
    const pkg = await buildExportPackage(format);
    let blob = pkg.blob;
    let filename = pkg.filename;
    if (output === 'gzip') {
      blob = await gzipBlob(blob);
      filename = `${filename}.gz`;
    }
    exportPreview.textContent = pkg.preview;
    if (output === 'open') {
      openBlob(blob, filename);
      log(`Opened ${filename}.`);
    } else {
      downloadBlob(blob, filename);
      log(`Downloaded ${filename}.`);
    }
  } catch (err) {
    exportPreview.textContent = `${ASA_ERROR_LABEL}: ${asaErrorCopy(err.message)}`;
    log(`Export failed: ${err.message}`);
  }
}

async function buildExportPackage(format) {
  const db = ensureCurrentDb('export');
  if (!db) throw new Error('Create or select a database before exporting.');
  const selection = getExportSelection();
  if (!selection.length) throw new Error('No tables selected.');

  if (format === 'asadb') {
    const bytes = makeAsaDbBytes(db, selection);
    const preview = prologStateText(db, selection).slice(0, 6000);
    return { blob: new Blob([bytes], { type: 'application/octet-stream' }), filename: `${db}.asa`, preview };
  }
  if (format === 'csv') {
    if (selection.length === 1) {
      const csv = tableToCsv(selection[0].table, selection[0].includeData, selection[0].includeSchema);
      return { blob: new Blob([csv], { type: 'text/csv' }), filename: `${selection[0].name}.csv`, preview: csv.slice(0, 6000) };
    }
    const entries = selection.map(item => ({ name: `${item.name}.csv`, data: utf8(tableToCsv(item.table, item.includeData, item.includeSchema)) }));
    const zip = makeZip(entries);
    return { blob: new Blob([zip], { type: 'application/zip' }), filename: `${db}-csv.zip`, preview: selection.map(x => `${x.name}.csv`).join('\n') };
  }
  if (format === 'xlsx') {
    const bytes = makeXlsx(selection);
    return { blob: new Blob([bytes], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }), filename: `${db}.xlsx`, preview: selection.map(x => `sheet: ${x.name}`).join('\n') };
  }
  if (format === 'mysql' || format === 'postgresql') {
    const sql = buildSqlExport(db, selection, format);
    return { blob: new Blob([sql], { type: 'application/sql' }), filename: `${db}-${format}.sql`, preview: sql.slice(0, 9000) };
  }
  throw new Error(`Unsupported format: ${format}`);
}

function checkedValue(name) {
  return document.querySelector(`input[name="${name}"]:checked`)?.value;
}

function tableToCsv(table, includeData, includeHeader = true) {
  const columns = table.columns || [];
  const lines = [];
  if (includeHeader) lines.push(columns.map(c => csvCell(c.name)).join(','));
  if (includeData) {
    for (const row of table.rows || []) lines.push(columns.map(c => csvCell(row[c.name])).join(','));
  }
  return lines.length ? `${lines.join('\n')}\n` : '';
}

function csvCell(value) {
  if (value === null || value === undefined) return '';
  const text = String(value);
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

function buildSqlExport(db, selection, dialect) {
  const lines = [];
  const quote = dialect === 'postgresql' ? quotePgIdent : quoteMysqlIdent;
  if (exportDatabaseMode.value === 'create') {
    lines.push(`CREATE DATABASE ${quote(db)};`);
    if (dialect === 'mysql') lines.push(`USE ${quote(db)};`);
    lines.push('');
  }
  for (const item of selection) {
    const tableMode = exportTableMode.value;
    if (tableMode === 'drop_create') lines.push(`DROP TABLE IF EXISTS ${quote(item.name)};`);
    if (tableMode !== 'none') {
      lines.push(`CREATE TABLE ${quote(item.name)} (`);
      const columns = (item.table.columns || []).map(col => `  ${quote(col.name)} ${mapTypeForDialect(col.type, dialect)}`);
      lines.push(columns.join(',\n'));
      lines.push(');');
      for (const index of item.table.indexes || []) {
        if (!index.columns?.length || /^PRIMARY$/i.test(index.name || '')) continue;
        const unique = /unique/i.test(index.name || '') || index.unique === true || index.kind === 'unique';
        const cols = index.columns.map(col => quote(col)).join(', ');
        lines.push(`CREATE ${unique ? 'UNIQUE ' : ''}INDEX ${quote(index.name || `${item.name}_idx`)} ON ${quote(item.name)} (${cols});`);
      }
    }
    if (exportDataMode.value !== 'none' && item.includeData) {
      const names = (item.table.columns || []).map(col => quote(col.name)).join(', ');
      for (const row of item.table.rows || []) {
        const values = (item.table.columns || []).map(col => sqlLiteral(row[col.name])).join(', ');
        lines.push(`INSERT INTO ${quote(item.name)} (${names}) VALUES (${values});`);
      }
    }
    lines.push('');
  }
  return lines.join('\n');
}

function quoteMysqlIdent(name) {
  return `\`${String(name).replace(/`/g, '')}\``;
}

function quotePgIdent(name) {
  return `"${String(name).replace(/"/g, '""')}"`;
}

function mapTypeForDialect(type, dialect) {
  const t = String(type || 'TEXT').toUpperCase();
  if (dialect === 'postgresql') {
    if (t === 'INT' || t === 'INTEGER') return 'INTEGER';
    if (t.includes('DATETIME')) return 'TIMESTAMP';
  }
  return t;
}

function prologStateText(db, selection) {
  const tables = selection.filter(item => item.includeSchema).map(item => {
    const columns = (item.table.columns || []).map(col => `col(${prologAtom(col.name)},${prologAtom(col.type || 'TEXT')},[])`).join(',');
    const rows = item.includeData ? (item.table.rows || []).map(row => {
      const pairs = (item.table.columns || []).map(col => `${prologAtom(col.name)}=${prologValue(row[col.name])}`).join(',');
      return `row([${pairs}])`;
    }).join(',') : '';
    return `table(${prologAtom(item.name)},[${columns}],[${rows}])`;
  }).join(',');
  return `state(1,[db(${prologAtom(db)},[${tables}])])`;
}

function makeAsaDbBytes(db, selection) {
  const text = prologStateText(db, selection);
  const codes = Array.from(text).map(ch => ch.charCodeAt(0) & 255);
  const sum = codes.reduce((acc, code) => (acc + code) % 1000000007, 0);
  const encoded = codes.map(code => (code ^ 90) & 255);
  const header = utf8(`ASADB001\n${sum}\n`);
  const out = new Uint8Array(header.length + encoded.length);
  out.set(header, 0);
  out.set(encoded, header.length);
  return out;
}

function parseAsaDbBuffer(buffer) {
  const bytes = new Uint8Array(buffer);
  if (!startsWithAscii(bytes, 'ASADB001\n')) {
    const text = decodeText(buffer);
    if (text.startsWith('ASADBWEB1\n')) return normalizeSandbox(JSON.parse(text.slice('ASADBWEB1\n'.length)));
    if (text.trim().startsWith('{')) return normalizeSandbox(JSON.parse(text));
    throw new Error('Invalid AsaDB file.');
  }

  let offset = 'ASADB001\n'.length;
  let sumText = '';
  while (offset < bytes.length && bytes[offset] !== 10) {
    sumText += String.fromCharCode(bytes[offset]);
    offset += 1;
  }
  offset += 1;
  const decoded = [];
  for (; offset < bytes.length; offset += 1) decoded.push((bytes[offset] ^ 90) & 255);
  const expected = Number(sumText);
  const actual = decoded.reduce((acc, code) => (acc + code) % 1000000007, 0);
  if (expected !== actual) throw new Error('AsaDB checksum mismatch.');
  const term = bytesToAscii(decoded);
  return prologTermToSandbox(parsePrologTerm(term));
}

function startsWithAscii(bytes, text) {
  if (bytes.length < text.length) return false;
  for (let i = 0; i < text.length; i += 1) if (bytes[i] !== text.charCodeAt(i)) return false;
  return true;
}

function bytesToAscii(bytes) {
  let out = '';
  for (let i = 0; i < bytes.length; i += 8192) {
    out += String.fromCharCode(...bytes.slice(i, i + 8192));
  }
  return out;
}

function prologAtom(value) {
  const text = String(value ?? '');
  return `'${text.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
}

function prologValue(value) {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'number') return String(value);
  return prologAtom(value);
}

function parsePrologTerm(text) {
  const tokens = tokenizeProlog(text);
  let pos = 0;

  function peek() { return tokens[pos]; }
  function take(type, value) {
    const token = tokens[pos];
    if (!token || token.type !== type || (value !== undefined && token.value !== value)) throw new Error(`Invalid AsaDB term near ${token?.value || 'end'}.`);
    pos += 1;
    return token;
  }
  function parseValue() {
    const token = peek();
    if (!token) throw new Error('Unexpected end of AsaDB term.');
    if (token.type === 'sym' && token.value === '[') return parseList();
    if (token.type === 'sym' && token.value === '=') { pos += 1; return { type: 'atom', value: '=' }; }
    if (token.type === 'number') { pos += 1; return { type: 'number', value: Number(token.value) }; }
    if (token.type === 'atom' || token.type === 'ident') {
      pos += 1;
      const node = { type: 'atom', value: token.value };
      if (peek()?.type === 'sym' && peek().value === '(') {
        take('sym', '(');
        const args = [];
        if (!(peek()?.type === 'sym' && peek().value === ')')) {
          do {
            args.push(parseValue());
            if (peek()?.type === 'sym' && peek().value === ',') take('sym', ',');
            else break;
          } while (true);
        }
        take('sym', ')');
        return { type: 'compound', functor: token.value, args };
      }
      if (peek()?.type === 'sym' && peek().value === '=') {
        take('sym', '=');
        return { type: 'pair', key: token.value, value: parseValue() };
      }
      return node;
    }
    throw new Error(`Unexpected token ${token.value}.`);
  }
  function parseList() {
    take('sym', '[');
    const items = [];
    if (!(peek()?.type === 'sym' && peek().value === ']')) {
      do {
        items.push(parseValue());
        if (peek()?.type === 'sym' && peek().value === ',') take('sym', ',');
        else break;
      } while (true);
    }
    take('sym', ']');
    return { type: 'list', items };
  }

  return parseValue();
}

function tokenizeProlog(text) {
  const tokens = [];
  for (let i = 0; i < text.length;) {
    const ch = text[i];
    if (/\s/.test(ch)) { i += 1; continue; }
    if ('[](),='.includes(ch)) { tokens.push({ type: 'sym', value: ch }); i += 1; continue; }
    if (ch === "'") {
      let value = '';
      i += 1;
      while (i < text.length) {
        if (text[i] === '\\') { value += text[i + 1] || ''; i += 2; continue; }
        if (text[i] === "'") { i += 1; break; }
        value += text[i];
        i += 1;
      }
      tokens.push({ type: 'atom', value });
      continue;
    }
    if (/\d/.test(ch) || (ch === '-' && /\d/.test(text[i + 1] || ''))) {
      let value = ch;
      i += 1;
      while (i < text.length && /[\d.]/.test(text[i])) { value += text[i]; i += 1; }
      tokens.push({ type: 'number', value });
      continue;
    }
    if (/[A-Za-z_]/.test(ch)) {
      let value = ch;
      i += 1;
      while (i < text.length && /[\w$]/.test(text[i])) { value += text[i]; i += 1; }
      tokens.push({ type: 'ident', value });
      continue;
    }
    if (/[<>!+\-*\/]/.test(ch)) {
      let value = ch;
      i += 1;
      while (i < text.length && /[<>=!+\-*\/]/.test(text[i])) { value += text[i]; i += 1; }
      tokens.push({ type: 'atom', value });
      continue;
    }
    throw new Error(`Invalid AsaDB character ${ch}.`);
  }
  return tokens;
}

function prologTermToSandbox(term) {
  if (term.type !== 'compound' || term.functor !== 'state') throw new Error('AsaDB state term expected.');
  const dbs = {};
  const views = {};
  const dbNodes = term.args[1]?.items || [];
  for (const dbNode of dbNodes) {
    if (dbNode.type !== 'compound' || dbNode.functor !== 'db') continue;
    const dbNameValue = nodeValue(dbNode.args[0]);
    if (!dbNameValue || isSystemDb(dbNameValue)) continue;
    const tables = {};
    const dbViews = {};
    for (const tableNode of dbNode.args[1]?.items || []) {
      if (tableNode.type !== 'compound' || tableNode.functor !== 'table') continue;
      const tableName = nodeValue(tableNode.args[0]);
      const columns = (tableNode.args[1]?.items || []).filter(n => n.type === 'compound' && n.functor === 'col').map(col => ({
        name: nodeValue(col.args[0]),
        type: nodeValue(col.args[1]) || 'TEXT',
      }));
      const rows = (tableNode.args[2]?.items || []).filter(n => n.type === 'compound' && n.functor === 'row').map(rowNode => {
        const row = {};
        for (const pair of rowNode.args[0]?.items || []) if (pair.type === 'pair') row[pair.key] = nodeValue(pair.value);
        return row;
      });
      tables[tableName] = { columns, rows };
    }
    for (const viewNode of dbNode.args[2]?.items || []) {
      if (viewNode.type !== 'compound' || viewNode.functor !== 'view') continue;
      const viewName = nodeValue(viewNode.args[0]);
      if (!viewName) continue;
      dbViews[viewName] = { name: viewName, query: 'SELECT-backed view', columns: [], rows: [], isView: true };
    }
    dbs[dbNameValue] = tables;
    views[dbNameValue] = dbViews;
  }
  return normalizeSandbox({ currentDb: visibleDbNames({ dbs, views })[0] || '', dbs, views });
}

function nodeValue(node) {
  if (!node) return null;
  if (node.type === 'number') return node.value;
  if (node.type === 'atom') return node.value === 'null' ? null : node.value;
  return null;
}

function makeXlsx(selection) {
  const workbookSheets = selection.map((item, index) => ({ id: index + 1, name: safeSheetName(item.name), item }));
  const workbookXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${workbookSheets.map(sheet => `<sheet name="${escapeXml(sheet.name)}" sheetId="${sheet.id}" r:id="rId${sheet.id}"/>`).join('')}</sheets></workbook>`;
  const workbookRels = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${workbookSheets.map(sheet => `<Relationship Id="rId${sheet.id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${sheet.id}.xml"/>`).join('')}</Relationships>`;
  const contentTypes = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>${workbookSheets.map(sheet => `<Override PartName="/xl/worksheets/sheet${sheet.id}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join('')}</Types>`;
  const rootRels = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`;
  const entries = [
    { name: '[Content_Types].xml', data: utf8(contentTypes) },
    { name: '_rels/.rels', data: utf8(rootRels) },
    { name: 'xl/workbook.xml', data: utf8(workbookXml) },
    { name: 'xl/_rels/workbook.xml.rels', data: utf8(workbookRels) },
  ];
  for (const sheet of workbookSheets) entries.push({ name: `xl/worksheets/sheet${sheet.id}.xml`, data: utf8(worksheetXml(sheet.item.table, sheet.item.includeData, sheet.item.includeSchema)) });
  return makeZip(entries);
}

function worksheetXml(table, includeData, includeHeader = true) {
  const rows = [];
  if (includeHeader) rows.push((table.columns || []).map(c => c.name));
  if (includeData) {
    for (const row of table.rows || []) rows.push((table.columns || []).map(c => row[c.name] ?? ''));
  }
  const xmlRows = rows.map((row, rIndex) => {
    const cells = row.map((value, cIndex) => {
      const ref = `${columnName(cIndex + 1)}${rIndex + 1}`;
      if (typeof value === 'number') return `<c r="${ref}"><v>${value}</v></c>`;
      return `<c r="${ref}" t="inlineStr"><is><t>${escapeXml(value ?? '')}</t></is></c>`;
    }).join('');
    return `<row r="${rIndex + 1}">${cells}</row>`;
  }).join('');
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${xmlRows}</sheetData></worksheet>`;
}

async function readXlsxWorkbook(buffer) {
  const files = await unzip(buffer);
  const workbook = parseXml(decodeFile(files, 'xl/workbook.xml'));
  const rels = parseXml(decodeFile(files, 'xl/_rels/workbook.xml.rels'));
  const sharedStrings = files['xl/sharedStrings.xml'] ? readSharedStrings(parseXml(decodeFile(files, 'xl/sharedStrings.xml'))) : [];
  const relMap = {};
  for (const rel of Array.from(rels.getElementsByTagName('Relationship'))) relMap[rel.getAttribute('Id')] = rel.getAttribute('Target');
  const sheets = [];
  for (const sheetNode of Array.from(workbook.getElementsByTagName('sheet'))) {
    const rid = sheetNode.getAttribute('r:id');
    const target = normalizeZipPath(`xl/${relMap[rid] || ''}`);
    if (!files[target]) continue;
    sheets.push({
      name: sheetNode.getAttribute('name') || `sheet_${sheets.length + 1}`,
      rows: readWorksheet(parseXml(decodeFile(files, target)), sharedStrings),
    });
  }
  return { sheets };
}

function readSharedStrings(xml) {
  return Array.from(xml.getElementsByTagName('si')).map(si => Array.from(si.getElementsByTagName('t')).map(t => t.textContent).join(''));
}

function readWorksheet(xml, sharedStrings) {
  const rows = [];
  for (const rowNode of Array.from(xml.getElementsByTagName('row'))) {
    const row = [];
    let nextIndex = 0;
    for (const cell of Array.from(rowNode.getElementsByTagName('c'))) {
      const ref = cell.getAttribute('r');
      const index = ref ? columnIndex(ref.replace(/\d+/g, '')) : nextIndex;
      while (row.length < index) row.push('');
      row[index] = readCell(cell, sharedStrings);
      nextIndex = index + 1;
    }
    rows.push(row);
  }
  return rows;
}

function readCell(cell, sharedStrings) {
  const type = cell.getAttribute('t');
  if (type === 'inlineStr') return cell.getElementsByTagName('t')[0]?.textContent || '';
  const value = cell.getElementsByTagName('v')[0]?.textContent || '';
  if (type === 's') return sharedStrings[Number(value)] || '';
  if (type === 'b') return value === '1' ? 'TRUE' : 'FALSE';
  return /^-?\d+(\.\d+)?$/.test(value) ? Number(value) : value;
}

function parseXml(text) {
  const xml = new DOMParser().parseFromString(text, 'application/xml');
  if (xml.getElementsByTagName('parsererror').length) throw new Error('Invalid XML inside XLSX.');
  return xml;
}

function decodeFile(files, name) {
  const file = files[name];
  if (!file) throw new Error(`${name} missing in XLSX.`);
  return new TextDecoder('utf-8').decode(file);
}

function safeSheetName(name) {
  return String(name).replace(/[\[\]*?:/\\]/g, '_').slice(0, 31) || 'Sheet';
}

function columnName(index) {
  let name = '';
  while (index > 0) {
    index -= 1;
    name = String.fromCharCode(65 + (index % 26)) + name;
    index = Math.floor(index / 26);
  }
  return name;
}

function columnIndex(name) {
  let out = 0;
  for (const ch of name) out = out * 26 + ch.toUpperCase().charCodeAt(0) - 64;
  return Math.max(0, out - 1);
}

function escapeXml(value) {
  return String(value).replace(/[<>&'"]/g, ch => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', "'": '&apos;', '"': '&quot;' }[ch]));
}

function makeZip(entries) {
  const localParts = [];
  const centralParts = [];
  let offset = 0;
  for (const entry of entries) {
    const name = utf8(entry.name);
    const data = entry.data instanceof Uint8Array ? entry.data : new Uint8Array(entry.data);
    const crc = crc32(data);
    const local = concatBytes([
      u32(0x04034b50), u16(20), u16(0), u16(0), u16(0), u16(0),
      u32(crc), u32(data.length), u32(data.length), u16(name.length), u16(0), name, data,
    ]);
    const central = concatBytes([
      u32(0x02014b50), u16(20), u16(20), u16(0), u16(0), u16(0), u16(0),
      u32(crc), u32(data.length), u32(data.length), u16(name.length), u16(0), u16(0), u16(0), u16(0), u32(0), u32(offset), name,
    ]);
    localParts.push(local);
    centralParts.push(central);
    offset += local.length;
  }
  const central = concatBytes(centralParts);
  const eocd = concatBytes([u32(0x06054b50), u16(0), u16(0), u16(entries.length), u16(entries.length), u32(central.length), u32(offset), u16(0)]);
  return concatBytes([...localParts, central, eocd]);
}

async function unzip(buffer) {
  const bytes = new Uint8Array(buffer);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const eocd = findEocd(view);
  const entries = view.getUint16(eocd + 10, true);
  let offset = view.getUint32(eocd + 16, true);
  const files = {};
  for (let i = 0; i < entries; i += 1) {
    if (view.getUint32(offset, true) !== 0x02014b50) throw new Error('Invalid ZIP central directory.');
    const method = view.getUint16(offset + 10, true);
    const compressedSize = view.getUint32(offset + 20, true);
    const nameLength = view.getUint16(offset + 28, true);
    const extraLength = view.getUint16(offset + 30, true);
    const commentLength = view.getUint16(offset + 32, true);
    const localOffset = view.getUint32(offset + 42, true);
    const name = new TextDecoder('utf-8').decode(bytes.slice(offset + 46, offset + 46 + nameLength));
    const localNameLength = view.getUint16(localOffset + 26, true);
    const localExtraLength = view.getUint16(localOffset + 28, true);
    const dataStart = localOffset + 30 + localNameLength + localExtraLength;
    const compressed = bytes.slice(dataStart, dataStart + compressedSize);
    files[normalizeZipPath(name)] = method === 0 ? compressed : await inflateRaw(compressed);
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return files;
}

function findEocd(view) {
  for (let offset = view.byteLength - 22; offset >= 0; offset -= 1) {
    if (view.getUint32(offset, true) === 0x06054b50) return offset;
  }
  throw new Error('Invalid ZIP/XLSX file.');
}

async function inflateRaw(bytes) {
  if (!('DecompressionStream' in window)) throw new Error('Compressed XLSX is not supported by this browser.');
  for (const format of ['deflate-raw', 'deflate']) {
    try {
      const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream(format));
      return new Uint8Array(await new Response(stream).arrayBuffer());
    } catch (_) {
      // Try the next browser-supported deflate variant.
    }
  }
  throw new Error('Unable to decompress XLSX entry.');
}

function normalizeZipPath(path) {
  const parts = [];
  for (const part of path.replace(/\\/g, '/').split('/')) {
    if (!part || part === '.') continue;
    if (part === '..') parts.pop();
    else parts.push(part);
  }
  return parts.join('/');
}

async function gzipBlob(blob) {
  if (!('CompressionStream' in window)) throw new Error('gzip is not supported by this browser.');
  const stream = blob.stream().pipeThrough(new CompressionStream('gzip'));
  return new Blob([await new Response(stream).arrayBuffer()], { type: 'application/gzip' });
}

async function gunzipBuffer(buffer) {
  if (!('DecompressionStream' in window)) throw new Error('gzip import is not supported by this browser.');
  const stream = new Blob([buffer]).stream().pipeThrough(new DecompressionStream('gzip'));
  return await new Response(stream).arrayBuffer();
}

function crc32(bytes) {
  let crc = -1;
  for (const byte of bytes) {
    crc = (crc >>> 8) ^ CRC_TABLE[(crc ^ byte) & 255];
  }
  return (crc ^ -1) >>> 0;
}

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i += 1) {
    let c = i;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[i] = c >>> 0;
  }
  return table;
})();

function u16(value) {
  const bytes = new Uint8Array(2);
  new DataView(bytes.buffer).setUint16(0, value, true);
  return bytes;
}

function u32(value) {
  const bytes = new Uint8Array(4);
  new DataView(bytes.buffer).setUint32(0, value >>> 0, true);
  return bytes;
}

function utf8(text) {
  return new TextEncoder().encode(text);
}

function concatBytes(parts) {
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let offset = 0;
  for (const part of parts) {
    out.set(part, offset);
    offset += part.length;
  }
  return out;
}

function downloadBlob(blob, filename) {
  const a = document.createElement('a');
  const url = URL.createObjectURL(blob);
  a.href = url;
  a.download = filename;
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function openBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const opened = window.open(url, '_blank', 'noopener,noreferrer');
  if (!opened) downloadBlob(blob, filename);
  setTimeout(() => URL.revokeObjectURL(url), 60000);
}

function sanitizeName(value) {
  const name = String(value || '').trim().replace(/\.[^.]+$/, '').replace(/[^\w$]+/g, '_').replace(/^_+|_+$/g, '');
  return name || 'imported_table';
}

function sanitizeIdentifier(value) {
  return String(value || '').trim().replace(/[^\w$]+/g, '_').replace(/^_+|_+$/g, '');
}

function baseName(path) {
  return String(path || '').split(/[\\/]/).pop().replace(/\.gz$/i, '').replace(/\.[^.]+$/, '');
}

function selectedSqlLineRange(value, start, end) {
  const lineStart = start === 0 ? 0 : value.lastIndexOf('\n', start - 1) + 1;
  let lineEnd = end;
  if (end > start && value[end - 1] === '\n') lineEnd -= 1;
  const nextBreak = value.indexOf('\n', Math.max(lineEnd, lineStart));
  return {
    lineStart,
    lineEnd: nextBreak === -1 ? value.length : nextBreak,
  };
}

function setSqlSelection(start, end = start) {
  sqlInput.setSelectionRange(Math.max(0, start), Math.max(0, end));
  updateSqlEditor();
  scheduleSqlAnalysis();
}

function indentSqlSelection() {
  const value = sqlInput.value;
  const start = sqlInput.selectionStart ?? 0;
  const end = sqlInput.selectionEnd ?? start;

  if (start === end) {
    sqlInput.value = `${value.slice(0, start)}${SQL_INDENT}${value.slice(end)}`;
    setSqlSelection(start + SQL_INDENT.length);
    return;
  }

  const { lineStart, lineEnd } = selectedSqlLineRange(value, start, end);
  const block = value.slice(lineStart, lineEnd);
  const lines = block.split('\n');
  const indented = lines.map(line => `${SQL_INDENT}${line}`).join('\n');
  sqlInput.value = `${value.slice(0, lineStart)}${indented}${value.slice(lineEnd)}`;
  setSqlSelection(start + SQL_INDENT.length, end + (SQL_INDENT.length * lines.length));
}

function leadingIndentWidth(line) {
  if (line.startsWith('\t')) return 1;
  const spaces = /^ {1,4}/.exec(line);
  return spaces ? spaces[0].length : 0;
}

function unindentSqlSelection() {
  const value = sqlInput.value;
  const start = sqlInput.selectionStart ?? 0;
  const end = sqlInput.selectionEnd ?? start;
  const { lineStart, lineEnd } = selectedSqlLineRange(value, start, end);
  const block = value.slice(lineStart, lineEnd);
  const lines = block.split('\n');
  let offset = lineStart;
  let removedBeforeStart = 0;
  let removedBeforeEnd = 0;

  const unindented = lines.map((line) => {
    const removeCount = leadingIndentWidth(line);
    if (removeCount) {
      if (offset < start) removedBeforeStart += Math.min(removeCount, start - offset);
      if (offset < end) removedBeforeEnd += Math.min(removeCount, end - offset);
    }
    offset += line.length + 1;
    return line.slice(removeCount);
  }).join('\n');

  sqlInput.value = `${value.slice(0, lineStart)}${unindented}${value.slice(lineEnd)}`;
  setSqlSelection(start - removedBeforeStart, end - removedBeforeEnd);
}

function handleSqlIndentKey(event) {
  if (event.key !== 'Tab') return false;
  event.preventDefault();
  if (event.shiftKey) unindentSqlSelection();
  else indentSqlSelection();
  return true;
}

sqlInput.addEventListener('input', () => {
  applySqlAutoCorrection(false);
  updateSqlEditor();
  scheduleSqlAnalysis();
});
sqlInput.addEventListener('scroll', syncSqlScroll);
sqlInput.addEventListener('keydown', (event) => {
  if (handleSqlIndentKey(event)) return;
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    event.preventDefault();
    runSql();
  }
});

runBtn.addEventListener('pointerdown', primeAsaRunSounds, { passive: true });
runBtn.addEventListener('click', runSql);
$('pingBtn').addEventListener('click', checkEngine);
$('clearBtn').addEventListener('click', () => setSqlText(''));
$('clearLogBtn').addEventListener('click', () => logBox.textContent = '');
$('resetSandboxBtn').addEventListener('click', () => {
  localStorage.removeItem(SANDBOX_STORAGE_KEY);
  localStorage.removeItem(LEGACY_SANDBOX_STORAGE_KEY);
  sandbox = createInitialSandbox();
  saveSandbox();
  selectedTable = '';
  renderTableBrowser();
  setSqlText('');
  log('Sandbox reset to empty state.');
});
$('loadSampleBtn').addEventListener('click', () => {
  setSqlText(`CREATE DATABASE ${SAMPLE_DB};\nUSE ${SAMPLE_DB};\nCREATE TABLE users (id INT NOT NULL, user_login VARCHAR(100), display_name VARCHAR(120), status VARCHAR(20) DEFAULT 'active');\nINSERT INTO users (id, user_login, display_name, status) VALUES (1, 'aires', 'Aires Admin', 'active'), (2, 'asa', 'Asa Editor', 'active');\nSELECT * FROM users;`);
  dbName.value = SAMPLE_DB;
  showView('sql');
});
$('createDbBtn').addEventListener('click', createDatabase);
saveDbBtn.addEventListener('click', saveCurrentDatabase);
dropDbBtn.addEventListener('click', dropCurrentDatabase);
dbSelect.addEventListener('change', () => selectDatabaseByName(dbSelect.value));
$('sqlCommandBtn').addEventListener('click', focusSqlCommand);
$('createTableBtn').addEventListener('click', insertCreateTableTemplate);
$('importViewBtn').addEventListener('click', () => showView('import'));
$('exportViewBtn').addEventListener('click', () => showView('export'));
tableSelectDataBtn.addEventListener('click', () => selectedTable && renderTableDetail(selectedTable, 'data'));
tableShowStructureBtn.addEventListener('click', () => selectedTable && renderTableDetail(selectedTable, 'structure'));
tableAlterBtn.addEventListener('click', () => {
  if (!selectedTable) return;
  const table = currentTable(selectedTable);
  const columns = (table?.columns || []).map(col => `  ${quoteIdent(col.name)} ${col.type || 'TEXT'}`).join(',\n');
  setSqlText(`CREATE TABLE ${quoteIdent(selectedTable)} (\n${columns}\n);`);
  focusSqlCommand();
});
tableNewItemBtn.addEventListener('click', () => {
  if (!selectedTable) return;
  const table = currentTable(selectedTable);
  const columns = (table?.columns || []).map(col => col.name);
  setSqlText(`INSERT INTO ${quoteIdent(selectedTable)} (${columns.map(quoteIdent).join(', ')}) VALUES (${columns.map(() => 'NULL').join(', ')});`);
  focusSqlCommand();
});
tableDropBtn.addEventListener('click', () => selectedTable && dropTable(selectedTable));
importExecuteBtn.addEventListener('click', importFromFiles);
importRunServerBtn.addEventListener('click', importFromServerFile);
exportRunBtn.addEventListener('click', exportDatabase);
createTableForm.addEventListener('submit', saveCreateTable);
createAddHeaderBtn.addEventListener('click', () => addCreateColumnRow({ type: 'int' }));
createAutoIncrementHelpBtn.addEventListener('click', (event) => {
  event.stopPropagation();
  const nextHidden = !autoIncrementHelpPopover.hidden;
  autoIncrementHelpPopover.hidden = nextHidden;
  createAutoIncrementHelpBtn.setAttribute('aria-expanded', String(!nextHidden));
});
document.addEventListener('click', (event) => {
  if (autoIncrementHelpPopover.hidden) return;
  if (event.target.closest('#autoIncrementHelpPopover') || event.target.closest('#createAutoIncrementHelpBtn')) return;
  autoIncrementHelpPopover.hidden = true;
  createAutoIncrementHelpBtn.setAttribute('aria-expanded', 'false');
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && !autoIncrementHelpPopover.hidden) {
    autoIncrementHelpPopover.hidden = true;
    createAutoIncrementHelpBtn.setAttribute('aria-expanded', 'false');
  }
});
createColumnsBody.addEventListener('click', (event) => {
  const button = event.target.closest('button');
  if (!button) return;
  const row = button.closest('tr');
  if (button.classList.contains('create-row-add')) {
    addCreateColumnRow({ type: 'int' });
  } else if (button.classList.contains('create-row-up') && row.previousElementSibling) {
    createColumnsBody.insertBefore(row, row.previousElementSibling);
  } else if (button.classList.contains('create-row-down') && row.nextElementSibling) {
    createColumnsBody.insertBefore(row.nextElementSibling, row);
  } else if (button.classList.contains('create-row-delete')) {
    if (createColumnsBody.rows.length > 1) row.remove();
  }
});
tableSearch.addEventListener('input', renderTableBrowser);
tableList.addEventListener('click', (event) => {
  const drop = event.target.closest('[data-drop-table]');
  if (drop) {
    event.preventDefault();
    event.stopPropagation();
    dropTable(drop.dataset.dropTable);
    return;
  }
  const button = event.target.closest('[data-table]');
  if (button) selectTable(button.dataset.table);
});
exportAllTables.addEventListener('change', () => {
  document.querySelectorAll('.export-table-check').forEach(input => input.checked = exportAllTables.checked);
});
exportAllData.addEventListener('change', () => {
  document.querySelectorAll('.export-data-check').forEach(input => input.checked = exportAllData.checked);
});

updateSqlEditor();
setSqlDiagnostics(analyzeSqlClient(sqlInput.value));
renderTableBrowser();
const initialHash = location.hash.slice(1);
if (initialHash.startsWith('table=')) {
  const tableName = decodeURIComponent(initialHash.slice('table='.length));
  if (currentRelation(tableName)) renderTableDetail(tableName, 'structure');
  else showView('sql');
} else if (views[initialHash]) {
  if (initialHash === 'create') showCreateTableView();
  else showView(initialHash);
} else {
  showView('sql');
}
runStartupWarmup(checkEngine());
