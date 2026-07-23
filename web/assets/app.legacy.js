/* AsaDB legacy browser bundle; generated from app.js. GPL-3.0-only. */
function _regenerator() { /*! regenerator-runtime -- Copyright (c) 2014-present, Facebook, Inc. -- license (MIT): https://github.com/babel/babel/blob/main/packages/babel-helpers/LICENSE */ var e, t, r = "function" == typeof Symbol ? Symbol : {}, n = r.iterator || "@@iterator", o = r.toStringTag || "@@toStringTag"; function i(r, n, o, i) { var c = n && n.prototype instanceof Generator ? n : Generator, u = Object.create(c.prototype); return _regeneratorDefine2(u, "_invoke", function (r, n, o) { var i, c, u, f = 0, p = o || [], y = !1, G = { p: 0, n: 0, v: e, a: d, f: d.bind(e, 4), d: function d(t, r) { return i = t, c = 0, u = e, G.n = r, a; } }; function d(r, n) { for (c = r, u = n, t = 0; !y && f && !o && t < p.length; t++) { var o, i = p[t], d = G.p, l = i[2]; r > 3 ? (o = l === n) && (u = i[(c = i[4]) ? 5 : (c = 3, 3)], i[4] = i[5] = e) : i[0] <= d && ((o = r < 2 && d < i[1]) ? (c = 0, G.v = n, G.n = i[1]) : d < l && (o = r < 3 || i[0] > n || n > l) && (i[4] = r, i[5] = n, G.n = l, c = 0)); } if (o || r > 1) return a; throw y = !0, n; } return function (o, p, l) { if (f > 1) throw TypeError("Generator is already running"); for (y && 1 === p && d(p, l), c = p, u = l; (t = c < 2 ? e : u) || !y;) { i || (c ? c < 3 ? (c > 1 && (G.n = -1), d(c, u)) : G.n = u : G.v = u); try { if (f = 2, i) { if (c || (o = "next"), t = i[o]) { if (!(t = t.call(i, u))) throw TypeError("iterator result is not an object"); if (!t.done) return t; u = t.value, c < 2 && (c = 0); } else 1 === c && (t = i.return) && t.call(i), c < 2 && (u = TypeError("The iterator does not provide a '" + o + "' method"), c = 1); i = e; } else if ((t = (y = G.n < 0) ? u : r.call(n, G)) !== a) break; } catch (t) { i = e, c = 1, u = t; } finally { f = 1; } } return { value: t, done: y }; }; }(r, o, i), !0), u; } var a = {}; function Generator() {} function GeneratorFunction() {} function GeneratorFunctionPrototype() {} t = Object.getPrototypeOf; var c = [][n] ? t(t([][n]())) : (_regeneratorDefine2(t = {}, n, function () { return this; }), t), u = GeneratorFunctionPrototype.prototype = Generator.prototype = Object.create(c); function f(e) { return Object.setPrototypeOf ? Object.setPrototypeOf(e, GeneratorFunctionPrototype) : (e.__proto__ = GeneratorFunctionPrototype, _regeneratorDefine2(e, o, "GeneratorFunction")), e.prototype = Object.create(u), e; } return GeneratorFunction.prototype = GeneratorFunctionPrototype, _regeneratorDefine2(u, "constructor", GeneratorFunctionPrototype), _regeneratorDefine2(GeneratorFunctionPrototype, "constructor", GeneratorFunction), GeneratorFunction.displayName = "GeneratorFunction", _regeneratorDefine2(GeneratorFunctionPrototype, o, "GeneratorFunction"), _regeneratorDefine2(u), _regeneratorDefine2(u, o, "Generator"), _regeneratorDefine2(u, n, function () { return this; }), _regeneratorDefine2(u, "toString", function () { return "[object Generator]"; }), (_regenerator = function _regenerator() { return { w: i, m: f }; })(); }
function _regeneratorDefine2(e, r, n, t) { var i = Object.defineProperty; try { i({}, "", {}); } catch (e) { i = 0; } _regeneratorDefine2 = function _regeneratorDefine(e, r, n, t) { function o(r, n) { _regeneratorDefine2(e, r, function (e) { return this._invoke(r, n, e); }); } r ? i ? i(e, r, { value: n, enumerable: !t, configurable: !t, writable: !t }) : e[r] = n : (o("next", 0), o("throw", 1), o("return", 2)); }, _regeneratorDefine2(e, r, n, t); }
function asyncGeneratorStep(n, t, e, r, o, a, c) { try { var i = n[a](c), u = i.value; } catch (n) { return void e(n); } i.done ? t(u) : Promise.resolve(u).then(r, o); }
function _asyncToGenerator(n) { return function () { var t = this, e = arguments; return new Promise(function (r, o) { var a = n.apply(t, e); function _next(n) { asyncGeneratorStep(a, r, o, _next, _throw, "next", n); } function _throw(n) { asyncGeneratorStep(a, r, o, _next, _throw, "throw", n); } _next(void 0); }); }; }
function _createForOfIteratorHelper(r, e) { var t = "undefined" != typeof Symbol && r[Symbol.iterator] || r["@@iterator"]; if (!t) { if (Array.isArray(r) || (t = _unsupportedIterableToArray(r)) || e && r && "number" == typeof r.length) { t && (r = t); var _n = 0, F = function F() {}; return { s: F, n: function n() { return _n >= r.length ? { done: !0 } : { done: !1, value: r[_n++] }; }, e: function e(r) { throw r; }, f: F }; } throw new TypeError("Invalid attempt to iterate non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); } var o, a = !0, u = !1; return { s: function s() { t = t.call(r); }, n: function n() { var r = t.next(); return a = r.done, r; }, e: function e(r) { u = !0, o = r; }, f: function f() { try { a || null == t.return || t.return(); } finally { if (u) throw o; } } }; }
function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), !0).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: !0, configurable: !0, writable: !0 }) : e[r] = t, e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == typeof i ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != typeof t || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r || "default"); if ("object" != typeof i) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
function _slicedToArray(r, e) { return _arrayWithHoles(r) || _iterableToArrayLimit(r, e) || _unsupportedIterableToArray(r, e) || _nonIterableRest(); }
function _nonIterableRest() { throw new TypeError("Invalid attempt to destructure non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }
function _iterableToArrayLimit(r, l) { var t = null == r ? null : "undefined" != typeof Symbol && r[Symbol.iterator] || r["@@iterator"]; if (null != t) { var e, n, i, u, a = [], f = !0, o = !1; try { if (i = (t = t.call(r)).next, 0 === l) { if (Object(t) !== t) return; f = !1; } else for (; !(f = (e = i.call(t)).done) && (a.push(e.value), a.length !== l); f = !0); } catch (r) { o = !0, n = r; } finally { try { if (!f && null != t.return && (u = t.return(), Object(u) !== u)) return; } finally { if (o) throw n; } } return a; } }
function _arrayWithHoles(r) { if (Array.isArray(r)) return r; }
function _toConsumableArray(r) { return _arrayWithoutHoles(r) || _iterableToArray(r) || _unsupportedIterableToArray(r) || _nonIterableSpread(); }
function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }
function _unsupportedIterableToArray(r, a) { if (r) { if ("string" == typeof r) return _arrayLikeToArray(r, a); var t = {}.toString.call(r).slice(8, -1); return "Object" === t && r.constructor && (t = r.constructor.name), "Map" === t || "Set" === t ? Array.from(r) : "Arguments" === t || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(t) ? _arrayLikeToArray(r, a) : void 0; } }
function _iterableToArray(r) { if ("undefined" != typeof Symbol && null != r[Symbol.iterator] || null != r["@@iterator"]) return Array.from(r); }
function _arrayWithoutHoles(r) { if (Array.isArray(r)) return _arrayLikeToArray(r); }
function _arrayLikeToArray(r, a) { (null == a || a > r.length) && (a = r.length); for (var e = 0, n = Array(a); e < a; e++) n[e] = r[e]; return n; }
// Copyright (C) 2026 Kocoy Group and AsaDB contributors
// SPDX-License-Identifier: GPL-3.0-only
var $ = function $(id) {
  return document.getElementById(id);
};
var DEFAULT_DB = '';
var SAMPLE_DB = 'demo';
var SANDBOX_STORAGE_KEY = 'asadb-sandbox-v2';
var LEGACY_SANDBOX_STORAGE_KEY = 'asadb-sandbox';
var DEFAULT_TABLES = [];
var BACKEND_FULL_SYNC_ROW_LIMIT = 5000;
var BROWSER_SQL_IMPORT_LIMIT_BYTES = 512 * 1024;
var BACKEND_UPLOAD_IMPORT_MIN_BYTES = 128 * 1024;
var STARTUP_WARMUP_MS = 650;
var LARGE_SQL_EDITOR_CHAR_LIMIT = 180000;
var LARGE_SQL_EDITOR_LINE_LIMIT = 4000;
var SQL_EDITOR_LINE_HEIGHT = 20.15;
var RESERVOIR_POLL_INTERVAL_MS = 120;
var METADATA_ACTIVE_POLL_INTERVAL_MS = 500;
var METADATA_OPEN_POLL_INTERVAL_MS = 1500;
var METADATA_IDLE_POLL_INTERVAL_MS = 5000;
var RESULT_PAGE_SIZE = 500;
var TABLE_LIST_PAGE_SIZE = 120;
var ACTIVE_RESERVOIR_STORAGE_KEY = 'asadb-active-reservoir-job-v1';
var LANGUAGE_STORAGE_KEY = 'asadb-language';
var LANGUAGE_LOCALES = {
  id: 'id-ID',
  ja: 'ja-JP',
  en: 'en-US'
};
var LANGUAGE_HTML = {
  id: 'id',
  ja: 'ja',
  en: 'en'
};
var I18N = {
  id: {
    'document.title': 'AsAPanel - Panel Lokal AsaDB',
    'startup.title': 'Asa lagi pemanasan',
    'startup.copy': 'Nyambungin panel ke engine dan katalog lokal.',
    'brand.admin': 'Admin AsaDB',
    'brand.support': 'Traktir Mi',
    'aria.databaseSelector': 'Pemilih database',
    'aria.databaseTools': 'Alat database',
    'aria.databaseQuickActions': 'Aksi cepat database',
    'aria.tableActions': 'Aksi tabel',
    'language.aria': 'Bahasa antarmuka',
    'database.namePlaceholder': 'nama_database',
    'database.create': 'Buat DB',
    'database.select': 'Pilih DB',
    'database.selectAria': 'Pilih database',
    'database.save': 'Simpan database',
    'database.drop': 'Hapus database',
    'nav.sql': 'Perintah SQL',
    'nav.import': 'Impor',
    'nav.export': 'Ekspor',
    'table.create': 'Buat tabel',
    'table.filterAria': 'Filter tabel',
    'table.filterPlaceholder': 'Cari tabel...',
    'table.listAria': 'Tabel',
    'metadata.title': 'Metadata database',
    'metadata.engine': 'Engine',
    'metadata.identity': 'Identitas',
    'metadata.objects': 'Objek',
    'metadata.rows': 'Baris',
    'metadata.storage': 'Penyimpanan',
    'metadata.cache': 'Cache halaman',
    'metadata.checkpoint': 'Checkpoint',
    'state.waiting': 'Menunggu',
    'top.local': 'AsaDB Lokal',
    'engine.check': 'Cek Engine',
    'sql.command': 'Perintah SQL',
    'sql.run': 'Jalankan SQL',
    'sql.running': 'Menjalankan...',
    'sql.sample': 'Contoh',
    'sql.placeholder': 'Tulis SQL di sini...',
    'sql.result': 'Hasil',
    'sql.noQuery': 'Belum ada query.',
    'common.clear': 'Bersihkan',
    'common.file': 'File',
    'common.format': 'Format',
    'common.summary': 'Ringkasan',
    'common.preview': 'Pratinjau',
    'common.database': 'Database',
    'common.table': 'Tabel',
    'common.tables': 'Tabel',
    'common.data': 'Data',
    'common.none': 'Tidak ada',
    'common.save': 'Simpan',
    'import.fileUpload': 'Unggah file',
    'import.execute': 'Eksekusi',
    'import.fromServer': 'Dari server',
    'import.serverFile': 'File server',
    'import.runFile': 'Jalankan file',
    'import.stopOnError': 'Berhenti saat error',
    'import.onlyErrors': 'Tampilkan hanya error',
    'import.progressTitle': 'Progres Reservoir',
    'import.noActiveJob': 'Tidak ada impor aktif.',
    'import.cancel': 'Batalkan',
    'import.cancelling': 'Membatalkan...',
    'import.cancelRequested': 'Permintaan pembatalan dikirim. Reservoir akan rollback di batas batch berikutnya.',
    'import.cancelled': 'Impor dibatalkan dan perubahan yang belum commit di-rollback.',
    'import.resumed': 'Pemantauan {name} dilanjutkan setelah panel dimuat ulang.',
    'import.resumedComplete': '{name} selesai setelah panel dimuat ulang ({count} statement).',
    'import.jobStatus': '{status} · {count} statement · {message}',
    'import.autoDetect': 'Deteksi otomatis',
    'import.target': 'Target',
    'import.csvTable': 'Tabel CSV',
    'export.output': 'Keluaran',
    'export.download': 'Unduh',
    'export.openPreview': 'Buka pratinjau',
    'export.noTables': 'Belum ada tabel dipilih.',
    'export.productionReady': 'Backup produksi {name} sedang disiapkan langsung dari storage backend. Unduhan akan dimulai dari browser.',
    'export.backendRequired': 'Backup produksi membutuhkan backend AsaDB yang sedang online. Ekspor dari cache browser sengaja diblokir agar data tidak bisa terpotong.',
    'table.selectData': 'Pilih data',
    'table.showStructure': 'Lihat struktur',
    'table.alter': 'Ubah tabel',
    'table.newItem': 'Item baru',
    'table.drop': 'Hapus tabel',
    'table.column': 'Kolom',
    'table.columnName': 'Nama kolom',
    'table.type': 'Tipe',
    'table.comment': 'Komentar',
    'table.indexes': 'Indeks',
    'table.name': 'Nama tabel:',
    'table.collation': '(collation)',
    'table.length': 'Panjang',
    'table.options': 'Opsi',
    'table.autoIncShort': 'Auto inc.',
    'table.autoIncHelp': 'Bantuan auto increment',
    'table.autoIncDescription': 'Auto increment untuk kolom angka. Biasanya dipakai di primary key seperti id INT; nilainya naik otomatis saat baris baru dibuat.',
    'table.autoIncrement': 'Auto Increment',
    'table.defaultValues': 'Nilai default',
    'table.partitionBy': 'Partisi berdasarkan',
    'table.addColumn': 'Tambah kolom',
    'table.moveUp': 'Naikkan kolom',
    'table.moveDown': 'Turunkan kolom',
    'table.deleteColumn': 'Hapus kolom',
    'table.virtualResult': 'hasil virtual',
    'table.viewDescription': 'view berbasis SELECT',
    'log.title': 'Log Eksekusi',
    'log.resetSandbox': 'Reset sandbox',
    'log.clear': 'Bersihkan log',
    'page.sql': 'Ruang Kerja SQL',
    'page.import': 'Impor',
    'page.export': 'Ekspor',
    'page.table': 'Tabel',
    'page.tableDetail': 'Detail Tabel',
    'page.create': 'Buat tabel',
    'page.transfer': 'Transfer Data',
    'mode.detecting': 'Mode: mendeteksi...',
    'mode.backend': 'Mode: backend Prolog online',
    'mode.sandbox': 'Mode: sandbox browser',
    'state.unavailable': 'Tidak tersedia',
    'state.offline': 'Offline',
    'state.pending': 'Tertunda',
    'state.durable': 'Durable',
    'state.never': 'belum pernah',
    'state.receiving': 'menerima unggahan',
    'state.queued': 'mengantre',
    'state.processing': 'memproses',
    'state.cancelling': 'membatalkan',
    'state.completed': 'selesai',
    'state.delivered': 'hasil tersimpan',
    'state.failed': 'gagal',
    'state.cancelled': 'dibatalkan',
    'state.interrupted': 'terinterupsi',
    'state.reconnecting': 'menyambungkan ulang',
    'database.noneSelected': 'Belum ada database dipilih',
    'database.selectFirst': 'Pilih atau buat database dulu sebelum melanjutkan.',
    'table.noneSelected': 'Belum ada tabel dipilih',
    'table.count': '{count} tabel',
    'table.countViews': '{tables} tabel, {views} view',
    'table.countFiltered': '{visible} dari {total} objek',
    'table.dropNamed': 'Hapus {kind} {name}',
    'table.view': 'view',
    'table.loadingView': 'Memuat view...',
    'table.viewNeedsBackend': 'Data view memerlukan backend Prolog.',
    'table.loadingPreview': 'Memuat pratinjau backend...',
    'table.showingRows': 'Menampilkan {shown} dari {total} baris backend.',
    'result.line': 'Baris',
    'result.rowsShown': '{count} baris ditampilkan. Masih ada baris lainnya.',
    'result.executed': 'Menjalankan {count} statement.',
    'result.completed': 'Eksekusi SQL selesai.',
    'progress.importing': 'Mengimpor {percent}% / {count} statement',
    'progress.reservoir': 'Reservoir {percent}% / {count} statement',
    'progress.backendSteps': '{count} langkah backend',
    'confirm.dropDatabase': 'Hapus database "{name}" permanen? Semua tabel dan view di dalamnya akan dihapus.',
    'confirm.dropTable': 'Hapus {kind} "{name}" dari database "{db}"?',
    'import.noFile': 'Belum ada file dipilih.',
    'import.conversion': '{name}: {format} -> AsaDB',
    'import.tablesLoaded': '{count} tabel dimuat',
    'import.tableRows': 'tabel {table}, {count} baris',
    'import.sheetsLoaded': '{count} sheet dimuat',
    'import.statements': '{count} statement',
    'import.databaseRequired': 'Buat atau pilih database sebelum mengimpor {format}.',
    'import.largeBackendRequired': 'Backend Prolog belum online. Impor SQL besar wajib lewat engine Prolog.',
    'import.unsupportedFormat': 'Format tidak didukung: {format}',
    'sandbox.resetDone': 'Sandbox direset ke kondisi kosong.',
    'metadata.objectsValue': '{databases} DB, {tables} tabel, {views} view',
    'metadata.storageValue': '{size} di disk',
    'metadata.cacheValue': '{pages}/{limit} halaman, {hits} hit',
    'metadata.reservoirValue': '{active} aktif, {queued} antre, {size} spool',
    'metadata.checkpointValue': '{count} pada {time}',
    'result.showMore': 'Tampilkan lebih banyak baris',
    'result.loadingMore': 'Memuat baris berikutnya...',
    'result.allRows': '{count} baris ditampilkan',
    'result.viewMissing': 'View tidak menghasilkan tabel.',
    'result.previewMissing': 'Pratinjau tabel tidak menghasilkan baris.',
    'table.showMore': 'Tampilkan lebih banyak tabel',
    'table.loadingMore': 'Memuat tabel berikutnya...',
    'table.tablesShown': '{shown} dari {total} tabel ditampilkan',
    'log.connected': 'Terhubung ke engine Prolog AsaDB lokal.',
    'log.sandbox': 'Backend tidak terdeteksi; memakai sandbox browser lokal.',
    'log.dropFailed': 'Penghapusan {kind} {name} gagal. Daftar lokal tidak diubah.',
    'log.dropVerifyFailed': 'Backend belum bisa memastikan {kind} {name} terhapus. Daftar lokal dipertahankan.',
    'log.dropped': '{kind} {name} berhasil dihapus.',
    'log.analyzerFallback': 'Analyzer beralih ke sandbox: {error}',
    'log.stateSyncSkipped': 'Sinkronisasi state dilewati: {error}',
    'log.backendFailed': 'Backend Prolog gagal: {error}',
    'log.postSyncSkipped': 'Sinkronisasi setelah eksekusi dilewati: {error}',
    'log.postSyncUnavailable': 'Penyegaran katalog setelah eksekusi tidak tersedia.',
    'log.databaseNameEmpty': 'Gagal membuat DB: nama database kosong.',
    'log.databaseCreated': 'Database {name} dibuat dan dipilih.',
    'log.databaseCreateFallback': 'Pembuatan DB di backend gagal; beralih ke sandbox: {error}',
    'log.databaseSelectFallback': 'Pemilihan DB di backend gagal; memakai state browser: {error}',
    'log.databaseSelected': 'Database {name} dipilih.',
    'log.databaseSaveFallback': 'Penyimpanan backend gagal; hanya state browser yang tersimpan: {error}',
    'log.databaseSaved': 'Database {name} disimpan.',
    'log.dropBackendFallback': 'Penghapusan backend gagal; beralih ke sandbox: {error}',
    'log.tableNameEmpty': 'Gagal membuat tabel: nama tabel kosong.',
    'log.tableColumnsEmpty': 'Gagal membuat tabel: tambahkan minimal satu kolom.',
    'log.tableCreateFallback': 'Pembuatan tabel di backend gagal; state browser dipertahankan: {error}',
    'log.tableCreated': 'Tabel {name} dibuat.',
    'log.importRejected': 'Backend menolak {name}; mencoba stream unggahan: {error}',
    'log.importFailed': 'Impor {name} gagal: {error}',
    'log.serverImportFailed': 'Impor server gagal: {error}',
    'log.reservoirFileStart': 'Impor file Reservoir dimulai: {name}',
    'log.reservoirUploadStart': 'Impor unggahan Reservoir dimulai: {name}',
    'log.reservoirResumed': 'Melanjutkan pemantauan job Reservoir: {name}',
    'log.reservoirCancelFailed': 'Pembatalan Reservoir gagal: {error}',
    'log.reservoirMonitorFailed': 'Pemantauan Reservoir berhenti: {error}',
    'log.fileOpened': 'Membuka {name}.',
    'log.fileDownloaded': 'Mengunduh {name}.',
    'log.exportFailed': 'Ekspor gagal: {error}',
    'import.backendSummary': '{name}: impor backend Prolog, {statements} statement, {errors} error',
    'import.uploadSummary': '{name}: impor unggahan backend Prolog, {statements} statement, {errors} error',
    'common.tableKind': 'tabel',
    'common.viewKind': 'view'
  },
  en: {
    'document.title': 'AsAPanel - AsaDB Local Panel',
    'startup.title': 'Asa is warming up',
    'startup.copy': 'Connecting the panel to the local engine and catalog.',
    'brand.admin': 'AsaDB Admin',
    'brand.support': 'Buy Me Noodles',
    'aria.databaseSelector': 'Database selector',
    'aria.databaseTools': 'Database tools',
    'aria.databaseQuickActions': 'Database quick actions',
    'aria.tableActions': 'Table actions',
    'language.aria': 'Interface language',
    'database.namePlaceholder': 'database_name',
    'database.create': 'Create DB',
    'database.select': 'Select DB',
    'database.selectAria': 'Select database',
    'database.save': 'Save database',
    'database.drop': 'Drop database',
    'nav.sql': 'SQL command',
    'nav.import': 'Import',
    'nav.export': 'Export',
    'table.create': 'Create table',
    'table.filterAria': 'Filter tables',
    'table.filterPlaceholder': 'Search tables...',
    'table.listAria': 'Tables',
    'metadata.title': 'Database metadata',
    'metadata.engine': 'Engine',
    'metadata.identity': 'Identity',
    'metadata.objects': 'Objects',
    'metadata.rows': 'Rows',
    'metadata.storage': 'Storage',
    'metadata.cache': 'Page cache',
    'metadata.checkpoint': 'Checkpoint',
    'state.waiting': 'Waiting',
    'top.local': 'Local AsaDB',
    'engine.check': 'Check Engine',
    'sql.command': 'SQL command',
    'sql.run': 'Run SQL',
    'sql.running': 'Running...',
    'sql.sample': 'Sample',
    'sql.placeholder': 'Write SQL here...',
    'sql.result': 'Result',
    'sql.noQuery': 'No query yet.',
    'common.clear': 'Clear',
    'common.file': 'File',
    'common.format': 'Format',
    'common.summary': 'Summary',
    'common.preview': 'Preview',
    'common.database': 'Database',
    'common.table': 'Table',
    'common.tables': 'Tables',
    'common.data': 'Data',
    'common.none': 'None',
    'common.save': 'Save',
    'import.fileUpload': 'File upload',
    'import.execute': 'Execute',
    'import.fromServer': 'From server',
    'import.serverFile': 'Server file',
    'import.runFile': 'Run file',
    'import.stopOnError': 'Stop on error',
    'import.onlyErrors': 'Show only errors',
    'import.progressTitle': 'Reservoir progress',
    'import.noActiveJob': 'No active import.',
    'import.cancel': 'Cancel',
    'import.cancelling': 'Cancelling...',
    'import.cancelRequested': 'Cancellation requested. Reservoir will roll back at the next batch boundary.',
    'import.cancelled': 'The import was cancelled and uncommitted changes were rolled back.',
    'import.resumed': 'Monitoring {name} resumed after the panel reloaded.',
    'import.resumedComplete': '{name} completed after the panel reloaded ({count} statements).',
    'import.jobStatus': '{status} · {count} statements · {message}',
    'import.autoDetect': 'Auto detect',
    'import.target': 'Target',
    'import.csvTable': 'CSV table',
    'export.output': 'Output',
    'export.download': 'Download',
    'export.openPreview': 'Open preview',
    'export.noTables': 'No tables selected.',
    'export.productionReady': 'Production backup {name} is being prepared directly from backend storage. The browser download will start shortly.',
    'export.backendRequired': 'Production backup requires an online AsaDB backend. Browser-cache export is deliberately blocked so data cannot be truncated.',
    'table.selectData': 'Select data',
    'table.showStructure': 'Show structure',
    'table.alter': 'Alter table',
    'table.newItem': 'New item',
    'table.drop': 'Drop table',
    'table.column': 'Column',
    'table.columnName': 'Column name',
    'table.type': 'Type',
    'table.comment': 'Comment',
    'table.indexes': 'Indexes',
    'table.name': 'Table name:',
    'table.collation': '(collation)',
    'table.length': 'Length',
    'table.options': 'Options',
    'table.autoIncShort': 'Auto inc.',
    'table.autoIncHelp': 'Auto increment help',
    'table.autoIncDescription': 'Auto increment is for numeric columns. It is commonly used on a primary key such as id INT and increases automatically for each new row.',
    'table.autoIncrement': 'Auto Increment',
    'table.defaultValues': 'Default values',
    'table.partitionBy': 'Partition by',
    'table.addColumn': 'Add column',
    'table.moveUp': 'Move column up',
    'table.moveDown': 'Move column down',
    'table.deleteColumn': 'Delete column',
    'table.virtualResult': 'virtual result',
    'table.viewDescription': 'SELECT-backed view',
    'log.title': 'Execution Log',
    'log.resetSandbox': 'Reset sandbox',
    'log.clear': 'Clear log',
    'page.sql': 'SQL Workspace',
    'page.import': 'Import',
    'page.export': 'Export',
    'page.table': 'Table',
    'page.tableDetail': 'Table Detail',
    'page.create': 'Create table',
    'page.transfer': 'Data Transfer',
    'mode.detecting': 'Mode: detecting...',
    'mode.backend': 'Mode: Prolog backend online',
    'mode.sandbox': 'Mode: browser sandbox',
    'state.unavailable': 'Unavailable',
    'state.offline': 'Offline',
    'state.pending': 'Pending',
    'state.durable': 'Durable',
    'state.never': 'never',
    'state.receiving': 'receiving upload',
    'state.queued': 'queued',
    'state.processing': 'processing',
    'state.cancelling': 'cancelling',
    'state.completed': 'completed',
    'state.delivered': 'result retained',
    'state.failed': 'failed',
    'state.cancelled': 'cancelled',
    'state.interrupted': 'interrupted',
    'state.reconnecting': 'reconnecting',
    'database.noneSelected': 'No database selected',
    'database.selectFirst': 'Select or create a database before continuing.',
    'table.noneSelected': 'No table selected',
    'table.count': '{count} tables',
    'table.countViews': '{tables} tables, {views} views',
    'table.countFiltered': '{visible} of {total} objects',
    'table.dropNamed': 'Drop {kind} {name}',
    'table.view': 'view',
    'table.loadingView': 'Loading view...',
    'table.viewNeedsBackend': 'View data requires the Prolog backend.',
    'table.loadingPreview': 'Loading backend preview...',
    'table.showingRows': 'Showing {shown} of {total} backend rows.',
    'result.line': 'Line',
    'result.rowsShown': '{count} rows shown. More rows are available.',
    'result.executed': 'Executed {count} statements.',
    'result.completed': 'SQL execution completed.',
    'progress.importing': 'Importing {percent}% / {count} statements',
    'progress.reservoir': 'Reservoir {percent}% / {count} statements',
    'progress.backendSteps': '{count} backend steps',
    'confirm.dropDatabase': 'Permanently drop database "{name}"? All tables and views inside it will be deleted.',
    'confirm.dropTable': 'Drop {kind} "{name}" from database "{db}"?',
    'import.noFile': 'No file selected.',
    'import.conversion': '{name}: {format} -> AsaDB',
    'import.tablesLoaded': '{count} tables loaded',
    'import.tableRows': 'table {table}, {count} rows',
    'import.sheetsLoaded': '{count} sheets loaded',
    'import.statements': '{count} statements',
    'import.databaseRequired': 'Create or select a database before importing {format}.',
    'import.largeBackendRequired': 'The Prolog backend is offline. Large SQL imports require the Prolog engine.',
    'import.unsupportedFormat': 'Unsupported format: {format}',
    'sandbox.resetDone': 'Sandbox reset to an empty state.',
    'metadata.objectsValue': '{databases} DB, {tables} tables, {views} views',
    'metadata.storageValue': '{size} on disk',
    'metadata.cacheValue': '{pages}/{limit} pages, {hits} hits',
    'metadata.reservoirValue': '{active} active, {queued} queued, {size} spool',
    'metadata.checkpointValue': '{count} at {time}',
    'result.showMore': 'Show more rows',
    'result.loadingMore': 'Loading next rows...',
    'result.allRows': '{count} rows shown',
    'result.viewMissing': 'The view did not return a table.',
    'result.previewMissing': 'The table preview did not return rows.',
    'table.showMore': 'Show more tables',
    'table.loadingMore': 'Loading next tables...',
    'table.tablesShown': '{shown} of {total} tables shown',
    'log.connected': 'Connected to the local Prolog AsaDB engine.',
    'log.sandbox': 'No backend detected; using the local browser sandbox.',
    'log.dropFailed': 'Failed to drop {kind} {name}. The local list was not changed.',
    'log.dropVerifyFailed': 'The backend could not confirm that {kind} {name} was dropped. The local list was preserved.',
    'log.dropped': 'Dropped {kind} {name}.',
    'log.analyzerFallback': 'Analyzer switched to sandbox: {error}',
    'log.stateSyncSkipped': 'State synchronization was skipped: {error}',
    'log.backendFailed': 'Prolog backend failed: {error}',
    'log.postSyncSkipped': 'Post-run synchronization was skipped: {error}',
    'log.postSyncUnavailable': 'The post-run catalog refresh was unavailable.',
    'log.databaseNameEmpty': 'Create DB failed: the database name is empty.',
    'log.databaseCreated': 'Database {name} was created and selected.',
    'log.databaseCreateFallback': 'Backend DB creation failed; switched to sandbox: {error}',
    'log.databaseSelectFallback': 'Backend DB selection failed; using browser state: {error}',
    'log.databaseSelected': 'Selected database {name}.',
    'log.databaseSaveFallback': 'Backend save failed; only browser state was saved: {error}',
    'log.databaseSaved': 'Saved database {name}.',
    'log.dropBackendFallback': 'Backend drop failed; switched to sandbox: {error}',
    'log.tableNameEmpty': 'Create table failed: the table name is empty.',
    'log.tableColumnsEmpty': 'Create table failed: add at least one column.',
    'log.tableCreateFallback': 'Backend table creation failed; browser state was preserved: {error}',
    'log.tableCreated': 'Created table {name}.',
    'log.importRejected': 'The backend rejected {name}; trying the upload stream: {error}',
    'log.importFailed': 'Import failed for {name}: {error}',
    'log.serverImportFailed': 'Server import failed: {error}',
    'log.reservoirFileStart': 'Reservoir file import started: {name}',
    'log.reservoirUploadStart': 'Reservoir upload import started: {name}',
    'log.reservoirResumed': 'Resuming Reservoir job monitoring: {name}',
    'log.reservoirCancelFailed': 'Reservoir cancellation failed: {error}',
    'log.reservoirMonitorFailed': 'Reservoir monitoring stopped: {error}',
    'log.fileOpened': 'Opened {name}.',
    'log.fileDownloaded': 'Downloaded {name}.',
    'log.exportFailed': 'Export failed: {error}',
    'import.backendSummary': '{name}: Prolog backend import, {statements} statements, {errors} errors',
    'import.uploadSummary': '{name}: Prolog backend upload import, {statements} statements, {errors} errors',
    'common.tableKind': 'table',
    'common.viewKind': 'view'
  },
  ja: {
    'document.title': 'AsAPanel - AsaDB ローカルパネル',
    'startup.title': 'アサは準備中です',
    'startup.copy': 'パネルをローカルエンジンとカタログに接続しています。',
    'brand.admin': 'AsaDB 管理',
    'brand.support': '麺をごちそうする',
    'aria.databaseSelector': 'データベース選択',
    'aria.databaseTools': 'データベースツール',
    'aria.databaseQuickActions': 'データベースのクイック操作',
    'aria.tableActions': 'テーブル操作',
    'language.aria': '表示言語',
    'database.namePlaceholder': 'データベース名',
    'database.create': 'DB 作成',
    'database.select': 'DB 選択',
    'database.selectAria': 'データベースを選択',
    'database.save': 'データベースを保存',
    'database.drop': 'データベースを削除',
    'nav.sql': 'SQL コマンド',
    'nav.import': 'インポート',
    'nav.export': 'エクスポート',
    'table.create': 'テーブル作成',
    'table.filterAria': 'テーブルを絞り込む',
    'table.filterPlaceholder': 'テーブルを検索...',
    'table.listAria': 'テーブル',
    'metadata.title': 'データベースメタデータ',
    'metadata.engine': 'エンジン',
    'metadata.identity': '識別子',
    'metadata.objects': 'オブジェクト',
    'metadata.rows': '行',
    'metadata.storage': 'ストレージ',
    'metadata.cache': 'ページキャッシュ',
    'metadata.checkpoint': 'チェックポイント',
    'state.waiting': '待機中',
    'top.local': 'ローカル AsaDB',
    'engine.check': 'エンジン確認',
    'sql.command': 'SQL コマンド',
    'sql.run': 'SQL 実行',
    'sql.running': '実行中...',
    'sql.sample': 'サンプル',
    'sql.placeholder': 'ここに SQL を入力...',
    'sql.result': '結果',
    'sql.noQuery': 'クエリはまだありません。',
    'common.clear': 'クリア',
    'common.file': 'ファイル',
    'common.format': '形式',
    'common.summary': '概要',
    'common.preview': 'プレビュー',
    'common.database': 'データベース',
    'common.table': 'テーブル',
    'common.tables': 'テーブル',
    'common.data': 'データ',
    'common.none': 'なし',
    'common.save': '保存',
    'import.fileUpload': 'ファイルをアップロード',
    'import.execute': '実行',
    'import.fromServer': 'サーバーから',
    'import.serverFile': 'サーバーファイル',
    'import.runFile': 'ファイル実行',
    'import.stopOnError': 'エラー時に停止',
    'import.onlyErrors': 'エラーのみ表示',
    'import.progressTitle': 'Reservoir の進捗',
    'import.noActiveJob': '実行中のインポートはありません。',
    'import.cancel': 'キャンセル',
    'import.cancelling': 'キャンセル中...',
    'import.cancelRequested': 'キャンセルを要求しました。次のバッチ境界で Reservoir がロールバックします。',
    'import.cancelled': 'インポートをキャンセルし、未コミットの変更をロールバックしました。',
    'import.resumed': 'パネルの再読み込み後に {name} の監視を再開しました。',
    'import.resumedComplete': 'パネルの再読み込み後に {name} が完了しました（{count} ステートメント）。',
    'import.jobStatus': '{status}・{count} ステートメント・{message}',
    'import.autoDetect': '自動検出',
    'import.target': '対象',
    'import.csvTable': 'CSV テーブル',
    'export.output': '出力',
    'export.download': 'ダウンロード',
    'export.openPreview': 'プレビューを開く',
    'export.noTables': 'テーブルが選択されていません。',
    'export.productionReady': '本番バックアップ {name} をバックエンドストレージから直接作成しています。ブラウザーのダウンロードがまもなく始まります。',
    'export.backendRequired': '本番バックアップにはオンラインの AsaDB バックエンドが必要です。データ切り詰めを防ぐため、ブラウザーキャッシュからのエクスポートはブロックされています。',
    'table.selectData': 'データを表示',
    'table.showStructure': '構造を表示',
    'table.alter': 'テーブル変更',
    'table.newItem': '新規項目',
    'table.drop': 'テーブル削除',
    'table.column': 'カラム',
    'table.columnName': 'カラム名',
    'table.type': '型',
    'table.comment': 'コメント',
    'table.indexes': 'インデックス',
    'table.name': 'テーブル名:',
    'table.collation': '（照合順序）',
    'table.length': '長さ',
    'table.options': 'オプション',
    'table.autoIncShort': '自動採番',
    'table.autoIncHelp': '自動採番のヘルプ',
    'table.autoIncDescription': '自動採番は数値カラム向けです。通常は id INT のような主キーに使用し、新しい行ごとに値が自動で増えます。',
    'table.autoIncrement': '自動採番',
    'table.defaultValues': 'デフォルト値',
    'table.partitionBy': 'パーティション',
    'table.addColumn': 'カラム追加',
    'table.moveUp': 'カラムを上へ',
    'table.moveDown': 'カラムを下へ',
    'table.deleteColumn': 'カラム削除',
    'table.virtualResult': '仮想結果',
    'table.viewDescription': 'SELECT ベースのビュー',
    'log.title': '実行ログ',
    'log.resetSandbox': 'サンドボックスをリセット',
    'log.clear': 'ログをクリア',
    'page.sql': 'SQL ワークスペース',
    'page.import': 'インポート',
    'page.export': 'エクスポート',
    'page.table': 'テーブル',
    'page.tableDetail': 'テーブル詳細',
    'page.create': 'テーブル作成',
    'page.transfer': 'データ転送',
    'mode.detecting': 'モード: 検出中...',
    'mode.backend': 'モード: Prolog バックエンド接続中',
    'mode.sandbox': 'モード: ブラウザーサンドボックス',
    'state.unavailable': '利用不可',
    'state.offline': 'オフライン',
    'state.pending': '保留中',
    'state.durable': '永続化済み',
    'state.never': '未実行',
    'state.receiving': 'アップロード受信中',
    'state.queued': '待機中',
    'state.processing': '処理中',
    'state.cancelling': 'キャンセル中',
    'state.completed': '完了',
    'state.delivered': '結果を保持中',
    'state.failed': '失敗',
    'state.cancelled': 'キャンセル済み',
    'state.interrupted': '中断',
    'state.reconnecting': '再接続中',
    'database.noneSelected': 'データベースが選択されていません',
    'database.selectFirst': '続ける前にデータベースを選択または作成してください。',
    'table.noneSelected': 'テーブルが選択されていません',
    'table.count': '{count} テーブル',
    'table.countViews': '{tables} テーブル、{views} ビュー',
    'table.countFiltered': '{total} 件中 {visible} 件',
    'table.dropNamed': '{kind} {name} を削除',
    'table.view': 'ビュー',
    'table.loadingView': 'ビューを読み込み中...',
    'table.viewNeedsBackend': 'ビューのデータには Prolog バックエンドが必要です。',
    'table.loadingPreview': 'バックエンドのプレビューを読み込み中...',
    'table.showingRows': 'バックエンド全 {total} 行中 {shown} 行を表示しています。',
    'result.line': '行',
    'result.rowsShown': '{count} 行を表示しました。ほかの行もあります。',
    'result.executed': '{count} 個のステートメントを実行しました。',
    'result.completed': 'SQL の実行が完了しました。',
    'progress.importing': 'インポート {percent}% / {count} ステートメント',
    'progress.reservoir': 'Reservoir {percent}% / {count} ステートメント',
    'progress.backendSteps': 'バックエンド {count} ステップ',
    'confirm.dropDatabase': 'データベース「{name}」を完全に削除しますか？中のテーブルとビューもすべて削除されます。',
    'confirm.dropTable': 'データベース「{db}」から {kind}「{name}」を削除しますか？',
    'import.noFile': 'ファイルが選択されていません。',
    'import.conversion': '{name}: {format} -> AsaDB',
    'import.tablesLoaded': '{count} テーブルを読み込みました',
    'import.tableRows': 'テーブル {table}、{count} 行',
    'import.sheetsLoaded': '{count} シートを読み込みました',
    'import.statements': '{count} ステートメント',
    'import.databaseRequired': '{format} をインポートする前にデータベースを作成または選択してください。',
    'import.largeBackendRequired': 'Prolog バックエンドがオフラインです。大きな SQL のインポートには Prolog エンジンが必要です。',
    'import.unsupportedFormat': '未対応の形式: {format}',
    'sandbox.resetDone': 'サンドボックスを空の状態にリセットしました。',
    'metadata.objectsValue': '{databases} DB、{tables} テーブル、{views} ビュー',
    'metadata.storageValue': 'ディスク上 {size}',
    'metadata.cacheValue': '{pages}/{limit} ページ、{hits} ヒット',
    'metadata.reservoirValue': '{active} 実行中、{queued} 待機、{size} スプール',
    'metadata.checkpointValue': '{time} に {count} 回',
    'result.showMore': 'さらに行を表示',
    'result.loadingMore': '次の行を読み込み中...',
    'result.allRows': '{count} 行を表示しました',
    'result.viewMissing': 'ビューからテーブル結果が返されませんでした。',
    'result.previewMissing': 'テーブルのプレビュー行が返されませんでした。',
    'table.showMore': 'さらにテーブルを表示',
    'table.loadingMore': '次のテーブルを読み込み中...',
    'table.tablesShown': '{total} テーブル中 {shown} テーブルを表示',
    'log.connected': 'ローカル Prolog AsaDB エンジンに接続しました。',
    'log.sandbox': 'バックエンドが見つからないため、ローカルのブラウザーサンドボックスを使用します。',
    'log.dropFailed': '{kind} {name} を削除できませんでした。ローカル一覧は変更していません。',
    'log.dropVerifyFailed': '{kind} {name} の削除をバックエンドで確認できませんでした。ローカル一覧を保持しました。',
    'log.dropped': '{kind} {name} を削除しました。',
    'log.analyzerFallback': 'アナライザーをサンドボックスへ切り替えました: {error}',
    'log.stateSyncSkipped': '状態の同期を省略しました: {error}',
    'log.backendFailed': 'Prolog バックエンドで失敗しました: {error}',
    'log.postSyncSkipped': '実行後の同期を省略しました: {error}',
    'log.postSyncUnavailable': '実行後のカタログ更新を利用できません。',
    'log.databaseNameEmpty': 'DB を作成できません: データベース名が空です。',
    'log.databaseCreated': 'データベース {name} を作成して選択しました。',
    'log.databaseCreateFallback': 'バックエンドでの DB 作成に失敗し、サンドボックスへ切り替えました: {error}',
    'log.databaseSelectFallback': 'バックエンドでの DB 選択に失敗し、ブラウザー状態を使用します: {error}',
    'log.databaseSelected': 'データベース {name} を選択しました。',
    'log.databaseSaveFallback': 'バックエンド保存に失敗し、ブラウザー状態のみ保存しました: {error}',
    'log.databaseSaved': 'データベース {name} を保存しました。',
    'log.dropBackendFallback': 'バックエンドでの削除に失敗し、サンドボックスへ切り替えました: {error}',
    'log.tableNameEmpty': 'テーブルを作成できません: テーブル名が空です。',
    'log.tableColumnsEmpty': 'テーブルを作成できません: カラムを一つ以上追加してください。',
    'log.tableCreateFallback': 'バックエンドでのテーブル作成に失敗し、ブラウザー状態を保持しました: {error}',
    'log.tableCreated': 'テーブル {name} を作成しました。',
    'log.importRejected': 'バックエンドが {name} を拒否したため、アップロードストリームを試します: {error}',
    'log.importFailed': '{name} のインポートに失敗しました: {error}',
    'log.serverImportFailed': 'サーバーインポートに失敗しました: {error}',
    'log.reservoirFileStart': 'Reservoir ファイルインポートを開始しました: {name}',
    'log.reservoirUploadStart': 'Reservoir アップロードインポートを開始しました: {name}',
    'log.reservoirResumed': 'Reservoir ジョブの監視を再開します: {name}',
    'log.reservoirCancelFailed': 'Reservoir のキャンセルに失敗しました: {error}',
    'log.reservoirMonitorFailed': 'Reservoir の監視を停止しました: {error}',
    'log.fileOpened': '{name} を開きました。',
    'log.fileDownloaded': '{name} をダウンロードしました。',
    'log.exportFailed': 'エクスポートに失敗しました: {error}',
    'import.backendSummary': '{name}: Prolog バックエンドインポート、{statements} ステートメント、{errors} エラー',
    'import.uploadSummary': '{name}: Prolog バックエンドアップロード、{statements} ステートメント、{errors} エラー',
    'common.tableKind': 'テーブル',
    'common.viewKind': 'ビュー'
  }
};
function loadLanguage() {
  try {
    var saved = localStorage.getItem(LANGUAGE_STORAGE_KEY);
    return Object.prototype.hasOwnProperty.call(I18N, saved) ? saved : 'id';
  } catch (_) {
    return 'id';
  }
}
var currentLanguage = loadLanguage();
function t(key) {
  var _ref, _I18N$currentLanguage, _I18N$currentLanguage2;
  var values = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
  var template = (_ref = (_I18N$currentLanguage = (_I18N$currentLanguage2 = I18N[currentLanguage]) === null || _I18N$currentLanguage2 === void 0 ? void 0 : _I18N$currentLanguage2[key]) !== null && _I18N$currentLanguage !== void 0 ? _I18N$currentLanguage : I18N.id[key]) !== null && _ref !== void 0 ? _ref : key;
  return String(template).replace(/\{([A-Za-z0-9_]+)\}/g, function (_, name) {
    var _values$name;
    return String((_values$name = values[name]) !== null && _values$name !== void 0 ? _values$name : `{${name}}`);
  });
}
var FORMAT_LABELS = {
  asadb: 'AsaDB',
  csv: 'CSV',
  xlsx: 'XLSX',
  postgresql: 'PostgreSQL',
  mysql: 'MySQL'
};
var startupLoader = $('startupLoader');
var ASA_OK_LABEL = "Asa Terima \uD83D\uDE33";
var ASA_ERROR_LABEL = "Asa Tidak Suka! \uD83D\uDE21";
var ASA_CORRECTION_LABEL = "Asa Mau Koreksi \uD83E\uDD14";
var ASA_RUN_SOUNDS = {
  ok: ['assets/Effect/Berhasil/1.mp3', 'assets/Effect/Berhasil/2.mp3', 'assets/Effect/Berhasil/3.mp3', 'assets/Effect/Berhasil/4.mp3'],
  error: ['assets/Effect/Gagal/1g.mp3', 'assets/Effect/Gagal/2g.mp3', 'assets/Effect/Gagal/3g.mp3', 'assets/Effect/Gagal/4g.mp3']
};
var asaRunSoundState = {
  ok: -1,
  error: -1
};
var asaRunAudioChannel = null;
var asaRunAudioGeneration = 0;
var ASA_ERROR_OPENERS = ['Asa berhenti dulu, ada bagian yang belum nyambung.', 'Asa nyangkut di sini, tapi masih bisa dibenerin.', 'Asa belum bisa nerima bentuk ini.', 'Asa membaca ini sebagai jalur buntu.', 'Asa curiga ada yang kelewat.', 'Asa belum nemu pegangan buat perintah ini.', 'Asa tahan dulu eksekusinya.', 'Asa lihat ada bagian yang belum siap jalan.', 'Asa belum sepakat sama susunan ini.', 'Asa minta dicek satu langkah lagi.', 'Asa belum paham maksud baris ini.', 'Asa nangkep niatnya, tapi bentuknya masih miring.', 'Asa belum berani jalanin ini.', 'Asa perlu versi yang lebih rapi dulu.', 'Asa kehilangan arah di bagian ini.', 'Asa nemu tanda yang bikin langkahnya putus.', 'Asa belum bisa menyambungkan kata-katanya.', 'Asa minta bagian ini ditata ulang.', 'Asa belum melihat tujuan perintahnya.', 'Asa berhenti supaya data kamu tidak salah berubah.', 'Asa belum dapat nama atau tanda yang dibutuhkan.', 'Asa membaca ini sebagai perintah yang belum lengkap.', 'Asa belum bisa menemukan benda yang kamu maksud.', 'Asa butuh petunjuk yang lebih jelas di sini.', 'Asa menolak dulu karena hasilnya bisa salah.', 'Asa merasa urutan katanya belum pas.', 'Asa belum bisa masuk ke jalur eksekusi.', 'Asa melihat bentuk SQL ini masih kepeleset.', 'Asa belum bisa menebak ini dengan aman.', 'Asa stop sebentar, ada yang perlu diberesin.', 'Asa belum nemu pasangan kata yang cocok.', 'Asa bilang ini belum jadi kalimat SQL yang utuh.'];
var ASA_CORRECTION_OPENERS = ['Asa punya tebakan kecil.', 'Asa mau rapihin sedikit.', 'Asa lihat ini hampir benar.', 'Asa curiga ini cuma salah ketik.', 'Asa bisa bantu lurusin.', 'Asa nemu bagian yang bisa dipoles.', 'Asa punya saran yang lebih aman.', 'Asa ingin ganti satu potongan kecil.', 'Asa menangkap maksudmu.', 'Asa rasa ini tinggal disetel.', 'Asa bisa bikin ini lebih kebaca.', 'Asa mau usul bentuk yang lebih pas.', 'Asa melihat jalannya, tinggal dirapikan.', 'Asa punya koreksi halus.', 'Asa hampir setuju, kurang satu sentuhan.', 'Asa mau bantu sebelum dijalankan.', 'Asa lihat ada tanda yang perlu ditutup.', 'Asa baca ini sebagai SQL yang belum selesai.', 'Asa punya cara supaya ini tidak nyasar.', 'Asa kasih bisikan kecil dulu.'];
var ASA_SUCCESS_OPENERS = ['Asa nerima ini dengan manis.', 'Asa sudah jalanin dan hasilnya aman.', 'Asa setuju, perintahnya masuk.', 'Asa sudah simpan langkahnya.', 'Asa berhasil menyelesaikan bagian ini.', 'Asa jalan pelan dan sampai.', 'Asa menerima bentuk SQL ini.', 'Asa sudah pegang hasilnya.', 'Asa mengangguk, ini valid.', 'Asa sudah beresin sesuai permintaan.', 'Asa suka yang ini, rapi.', 'Asa sudah mengubah data dengan aman.', 'Asa selesai tanpa protes.', 'Asa berhasil membaca niatmu.', 'Asa sudah kunci hasilnya.', 'Asa bilang ini boleh lewat.'];
var ASA_LANGUAGE_COPY = {
  id: {
    okLabel: "Asa Terima \uD83D\uDE33",
    errorLabel: "Asa Tidak Suka! \uD83D\uDE21",
    correctionLabel: "Asa Mau Koreksi \uD83E\uDD14",
    errors: _toConsumableArray(ASA_ERROR_OPENERS),
    corrections: _toConsumableArray(ASA_CORRECTION_OPENERS),
    successes: _toConsumableArray(ASA_SUCCESS_OPENERS)
  },
  en: {
    okLabel: "Asa Approves \uD83D\uDE33",
    errorLabel: "Asa Doesn't Like That! \uD83D\uDE21",
    correctionLabel: "Asa Suggests a Fix \uD83E\uDD14",
    errors: ['Asa stopped here because one part does not connect yet.', 'Asa got stuck here, but this can still be fixed.', 'Asa cannot safely accept this form yet.', 'Asa found a break in the execution path.', 'Asa suspects that one piece is missing.', 'Asa paused before the data could change incorrectly.', 'Asa needs a clearer SQL sentence first.', 'Asa found a token that interrupts the command.'],
    corrections: ['Asa has a small suggestion.', 'Asa wants to tidy this up a little.', 'Asa thinks this is almost right.', 'Asa suspects this is only a typo.', 'Asa can straighten this out.', 'Asa found one part that can be polished.'],
    successes: ['Asa accepted this happily.', 'Asa ran it and the result is safe.', 'Asa agrees; the command went through.', 'Asa completed this part successfully.', 'Asa accepted this SQL form.', 'Asa has the result ready.']
  },
  ja: {
    okLabel: "\u30A2\u30B5\u306F\u53D7\u3051\u5165\u308C\u307E\u3057\u305F \uD83D\uDE33",
    errorLabel: "\u30A2\u30B5\u306F\u6C17\u306B\u5165\u308A\u307E\u305B\u3093\uFF01 \uD83D\uDE21",
    correctionLabel: "\u30A2\u30B5\u304B\u3089\u4FEE\u6B63\u6848 \uD83E\uDD14",
    errors: ['まだつながっていない部分があるため、アサはここで止まりました。', 'アサはここで詰まりましたが、まだ修正できます。', 'アサはこの形を安全に受け入れられません。', 'アサは実行経路が切れている箇所を見つけました。', 'アサは何か一つ足りないと考えています。', 'データを誤って変更しないよう、アサは実行を止めました。', 'アサには、もう少し明確な SQL が必要です。', 'アサはコマンドを中断するトークンを見つけました。'],
    corrections: ['アサから小さな提案があります。', 'アサが少し整えます。', 'アサには、ほぼ正しく見えます。', 'アサは単純な入力ミスだと考えています。', 'アサが正しい形に直せます。', 'アサは改善できる箇所を見つけました。'],
    successes: ['アサは喜んで受け入れました。', 'アサが実行し、結果の安全を確認しました。', 'アサは同意しました。コマンドは正常です。', 'アサはこの処理を完了しました。', 'アサはこの SQL を受け入れました。', 'アサが結果を用意しました。']
  }
};
function syncAsaLanguageCopy() {
  var copy = ASA_LANGUAGE_COPY[currentLanguage] || ASA_LANGUAGE_COPY.id;
  ASA_OK_LABEL = copy.okLabel;
  ASA_ERROR_LABEL = copy.errorLabel;
  ASA_CORRECTION_LABEL = copy.correctionLabel;
  ASA_ERROR_OPENERS = _toConsumableArray(copy.errors);
  ASA_CORRECTION_OPENERS = _toConsumableArray(copy.corrections);
  ASA_SUCCESS_OPENERS = _toConsumableArray(copy.successes);
}
var sqlInput = $('sqlInput');
var sqlEditor = $('sqlEditor');
var sqlHighlight = $('sqlHighlight');
var sqlLineNumbers = $('sqlLineNumbers');
var sqlLineNumbersContent = $('sqlLineNumbersContent');
var sqlDiagnostics = $('sqlDiagnostics');
var sqlCompletions = $('sqlCompletions');
var resultBox = $('resultBox');
var runBtn = $('runBtn');
var logBox = $('logBox');
var engineStatus = $('engineStatus');
var lastRun = $('lastRun');
var dbName = $('dbName');
var dbSelect = $('dbSelect');
var saveDbBtn = $('saveDbBtn');
var dropDbBtn = $('dropDbBtn');
var tableList = $('tableList');
var tableSearch = $('tableSearch');
var tableCount = $('tableCount');
var pageTitle = $('pageTitle');
var dbMetadataPanel = $('dbMetadataPanel');
var metadataState = $('metadataState');
var metadataEngine = $('metadataEngine');
var metadataIdentity = $('metadataIdentity');
var metadataObjects = $('metadataObjects');
var metadataRows = $('metadataRows');
var metadataStorage = $('metadataStorage');
var metadataCache = $('metadataCache');
var metadataCheckpoint = $('metadataCheckpoint');
var metadataReservoir = $('metadataReservoir');
var languageSwitcher = $('languageSwitcher');
var views = {
  sql: $('sqlView'),
  import: $('importView'),
  export: $('exportView'),
  table: $('tableView'),
  create: $('createTableView')
};
var viewButtons = {
  sql: $('sqlCommandBtn'),
  import: $('importViewBtn'),
  export: $('exportViewBtn')
};
var importFileInput = $('importFileInput');
var importFormat = $('importFormat');
var importExecuteBtn = $('importExecuteBtn');
var importServerPath = $('importServerPath');
var importRunServerBtn = $('importRunServerBtn');
var importStopOnError = $('importStopOnError');
var importShowOnlyErrors = $('importShowOnlyErrors');
var importWriteMode = $('importWriteMode');
var importTargetTable = $('importTargetTable');
var importSummary = $('importSummary');
var importProgressPanel = $('importProgressPanel');
var importProgressLabel = $('importProgressLabel');
var importProgressPercent = $('importProgressPercent');
var importProgressBar = $('importProgressBar');
var importProgressStatus = $('importProgressStatus');
var importCancelBtn = $('importCancelBtn');
var exportDbName = $('exportDbName');
var exportDatabaseMode = $('exportDatabaseMode');
var exportTableMode = $('exportTableMode');
var exportDataMode = $('exportDataMode');
var exportAllTables = $('exportAllTables');
var exportAllData = $('exportAllData');
var exportTableRows = $('exportTableRows');
var exportRunBtn = $('exportRunBtn');
var exportPreview = $('exportPreview');
var tableDetailName = $('tableDetailName');
var tableSelectDataBtn = $('tableSelectDataBtn');
var tableShowStructureBtn = $('tableShowStructureBtn');
var tableAlterBtn = $('tableAlterBtn');
var tableNewItemBtn = $('tableNewItemBtn');
var tableDropBtn = $('tableDropBtn');
var tableStructurePanel = $('tableStructurePanel');
var tableStructureBody = $('tableStructureBody');
var tableIndexBody = $('tableIndexBody');
var tableDataPanel = $('tableDataPanel');
var tableDataBox = $('tableDataBox');
var createTableForm = $('createTableForm');
var createTableName = $('createTableName');
var createEngine = $('createEngine');
var createCollation = $('createCollation');
var createColumnsBody = $('createColumnsBody');
var createAddHeaderBtn = $('createAddHeaderBtn');
var createAutoIncrement = $('createAutoIncrement');
var createDefaultValues = $('createDefaultValues');
var createComment = $('createComment');
var createAllAutoIncrement = $('createAllAutoIncrement');
var createAutoIncrementHelpBtn = $('createAutoIncrementHelpBtn');
var autoIncrementHelpPopover = $('autoIncrementHelpPopover');
var backendOnline = false;
var engineCheckCompleted = false;
var selectedTable = '';
var currentViewName = 'sql';
var currentTableDetailMode = 'structure';
var lastDatabaseMetadata = null;
var lastRenderedResults = [];
var lastRunState = {
  key: 'sql.noQuery',
  values: {},
  raw: ''
};
var sandbox = loadSandbox();
var sqlDiagnosticsState = [];
var sqlAnalyzeTimer = 0;
var sqlAnalyzeRequest = 0;
var sqlRunPromise = null;
var activeReservoirJobId = '';
var activeReservoirDescriptor = null;
var lastReservoirSnapshot = null;
var reservoirResumePromise = null;
var reservoirCancelPromise = null;
var importOperationPromise = null;
var metadataRefreshPromise = null;
var metadataPollTimer = 0;
var lastMetadataRefreshAt = 0;
var tableListVisibleLimit = TABLE_LIST_PAGE_SIZE;
var tableListObserver = null;
var resultPageContext = null;
var resultPagePromises = new Map();
var tableDataPageState = null;
var tableDetailRequestId = 0;
var asaRunPrimePromise = null;
var sqlLineRenderFrame = 0;
var sqlScrollRestoreFrame = 0;
var sqlPasteInProgress = false;
var sqlPasteAnchor = {
  top: 0,
  left: 0
};
var sqlEditorMetrics = {
  lineCount: 1,
  large: false,
  textLength: 0
};
var archiveRefreshTimer = 0;
var archiveSnapshot = {
  kind: 'idle',
  dataset: '',
  columns: [],
  rows: [],
  rowCount: 0,
  sizeBytes: 0,
  progress: 0,
  updatedAt: 0
};
function applyStaticTranslations() {
  document.documentElement.lang = LANGUAGE_HTML[currentLanguage] || LANGUAGE_HTML.id;
  document.title = t('document.title');
  document.querySelectorAll('[data-i18n]').forEach(function (node) {
    node.textContent = t(node.dataset.i18n);
  });
  var _loop = function _loop() {
    var _arr$_i = _slicedToArray(_arr[_i], 2),
      attribute = _arr$_i[0],
      dataName = _arr$_i[1];
    document.querySelectorAll(`[data-${dataName.replace(/[A-Z]/g, function (value) {
      return `-${value.toLowerCase()}`;
    })}]`).forEach(function (node) {
      node.setAttribute(attribute, t(node.dataset[dataName]));
    });
  };
  for (var _i = 0, _arr = [['placeholder', 'i18nPlaceholder'], ['title', 'i18nTitle'], ['aria-label', 'i18nAriaLabel']]; _i < _arr.length; _i++) {
    _loop();
  }
  languageSwitcher === null || languageSwitcher === void 0 || languageSwitcher.querySelectorAll('[data-language]').forEach(function (button) {
    var active = button.dataset.language === currentLanguage;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  });
}
function updatePageTitle() {
  var key = currentViewName === 'table' ? 'page.tableDetail' : currentViewName === 'create' ? 'page.create' : currentViewName === 'import' ? 'page.import' : currentViewName === 'export' ? 'page.export' : 'page.sql';
  pageTitle.textContent = t(key);
}
function updateEngineStatus() {
  var key = !engineCheckCompleted ? 'mode.detecting' : backendOnline ? 'mode.backend' : 'mode.sandbox';
  engineStatus.textContent = t(key);
  engineStatus.className = !engineCheckCompleted ? 'status muted' : backendOnline ? 'status ok' : 'status warn';
}
function localizedRelationKind(kind) {
  return t(kind === 'view' ? 'common.viewKind' : 'common.tableKind');
}
function renderLastRunState() {
  var values = _objectSpread({}, lastRunState.values);
  if (typeof values.count === 'number') values.count = formatNumber(values.count);
  lastRun.textContent = lastRunState.key ? t(lastRunState.key, values) : lastRunState.raw;
}
function setLastRunKey(key) {
  var values = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
  lastRunState = {
    key,
    values,
    raw: ''
  };
  renderLastRunState();
}
function setLastRunRaw(raw) {
  lastRunState = {
    key: '',
    values: {},
    raw: String(raw)
  };
  renderLastRunState();
}
function setLanguage(language) {
  var persist = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : true;
  if (!Object.prototype.hasOwnProperty.call(I18N, language)) return;
  currentLanguage = language;
  if (persist) {
    try {
      localStorage.setItem(LANGUAGE_STORAGE_KEY, language);
    } catch (_) {
      // The interface can still switch when browser storage is unavailable.
    }
  }
  syncAsaLanguageCopy();
  applyStaticTranslations();
  renderLastRunState();
  updatePageTitle();
  updateEngineStatus();
  renderSqlDiagnostics();
  setSqlRunBusy(Boolean(sqlRunPromise));
  renderReservoirJob(lastReservoirSnapshot);
  renderTableBrowser();
  renderDatabaseMetadata(lastDatabaseMetadata);
  if (lastRenderedResults.length) renderResults(lastRenderedResults, {
    remember: false,
    archive: false
  });
  if (currentViewName === 'table' && selectedTable && currentRelation(selectedTable)) {
    renderTableDetail(selectedTable, currentTableDetailMode);
  }
}
function backendToken() {
  var match = document.cookie.match(/(?:^|;\s*)asadb_token=([^;]+)/);
  return match ? decodeURIComponent(match[1]) : '';
}
function apiHeaders() {
  var extra = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var headers = _objectSpread({}, extra);
  var token = backendToken();
  if (token) headers['X-AsaDB-Token'] = token;
  return headers;
}
var SQL_KEYWORDS = new Set(['add', 'all', 'alter', 'and', 'as', 'asc', 'begin', 'between', 'by', 'cascade', 'check', 'collate', 'column', 'columns', 'commit', 'constraint', 'create', 'database', 'databases', 'default', 'delete', 'desc', 'describe', 'distinct', 'drop', 'exists', 'explain', 'for', 'from', 'grant', 'grants', 'group', 'having', 'identified', 'if', 'in', 'index', 'indexes', 'insert', 'into', 'is', 'join', 'key', 'keys', 'left', 'like', 'limit', 'lock', 'login', 'not', 'null', 'offset', 'on', 'or', 'order', 'password', 'primary', 'references', 'revoke', 'right', 'rollback', 'select', 'set', 'show', 'start', 'table', 'tables', 'to', 'transaction', 'truncate', 'unique', 'unlock', 'update', 'user', 'use', 'values', 'where']);
var SQL_TYPES = new Set(['bigint', 'binary', 'blob', 'bool', 'boolean', 'char', 'character', 'date', 'datetime', 'decimal', 'double', 'enum', 'float', 'int', 'integer', 'longblob', 'longtext', 'mediumint', 'mediumtext', 'real', 'smallint', 'text', 'time', 'timestamp', 'tinyint', 'tinytext', 'unsigned', 'varbinary', 'varchar', 'year', 'zerofill']);
var SQL_FUNCTIONS = new Set(['count', 'max', 'min', 'sum', 'avg', 'lower', 'upper', 'length', 'concat', 'substr', 'substring', 'trim', 'replace', 'coalesce', 'now', 'current_timestamp']);
/* Kept in the checked-in Firefox-38 bundle: do not make one request per key. */
var SQL_COMPLETION_KEYWORDS = 'ADD AFTER ALL ALTER ANALYZE AND AS ASC AUTO_INCREMENT BEGIN BEFORE BETWEEN BY CASCADE CASE CHANGE CHECK COLLATE COLUMN COLUMNS COMMENT COMMIT CONSTRAINT CREATE DATABASE DATABASES DEFAULT DELETE DESC DESCRIBE DISTINCT DROP EACH ELSE END ENGINE EXISTS EXPLAIN FALSE FOR FOREIGN FROM FULL FUNCTION GRANT GRANTS GROUP HAVING IDENTIFIED IF IN INOUT INDEX INDEXES INNER INSERT INTO IS JOIN KEY KEYS LEFT LIKE LIMIT LOCK LOGIN MODIFY NOT NULL OFFSET ON OR ORDER OUT OUTER PASSWORD PRIMARY PROCEDURE REFERENCES RENAME REPLACE RETURN RETURNS REVOKE RIGHT ROLLBACK ROW SELECT SET SHOW START TABLE TABLES THEN TO TRANSACTION TRUE TRIGGER TRUNCATE UNION UNIQUE UNLOCK UPDATE USE USER USING VALUES VIEW WHEN WHERE WITH'.split(' ');
/* The highlighter recognizes the same syntax vocabulary as completion. */
SQL_COMPLETION_KEYWORDS.forEach(function (word) { SQL_KEYWORDS.add(word.toLowerCase()); });
SQL_TYPES.forEach(function (type) { SQL_KEYWORDS.add(type); });
SQL_FUNCTIONS.forEach(function (functionName) { SQL_KEYWORDS.add(functionName); });
var sqlCompletionState = { open: false, items: [], active: 0, start: 0, end: 0 };
var sqlCompletionCanvas = null;
function sqlCompletionIcon(kind) {
  if (kind === 'column') return '⊟';
  if (kind === 'table') return '▤';
  if (kind === 'view') return '◫';
  if (kind === 'function') return 'ƒ';
  if (kind === 'type') return 'T';
  if (kind === 'database') return '●';
  return '›';
}
function sqlCompletionIdentifier(name) {
  var text = String(name || '');
  return /^[A-Za-z_][\w$]*$/.test(text) ? text : '`' + text.replace(/`/g, '``') + '`';
}
function sqlCompletionRelation(name) {
  var db = sandbox.dbs && sandbox.dbs[currentDbName()] || {};
  var viewsForDb = sandbox.views && sandbox.views[currentDbName()] || {};
  var lowered = String(name || '').toLowerCase();
  var tableNames = Object.keys(db);
  var viewNames = Object.keys(viewsForDb);
  var index;
  for (index = 0; index < tableNames.length; index += 1) {
    if (tableNames[index].toLowerCase() === lowered) return { kind: 'table', name: tableNames[index], value: db[tableNames[index]] };
  }
  for (index = 0; index < viewNames.length; index += 1) {
    if (viewNames[index].toLowerCase() === lowered) return { kind: 'view', name: viewNames[index], value: viewsForDb[viewNames[index]] };
  }
  return null;
}
function sqlCompletionAliases(statement) {
  var aliases = {};
  var pattern = /\b(?:from|join|update|into|table|references)\s+(`[^`]+`|[A-Za-z_][\w$]*)(?:\s+(?:as\s+)?([A-Za-z_][\w$]*))?/gi;
  var match;
  while ((match = pattern.exec(statement))) {
    var relationName = match[1].replace(/^`|`$/g, '');
    var relation = sqlCompletionRelation(relationName);
    var alias = match[2] && match[2].toLowerCase();
    if (!relation) continue;
    aliases[relationName.toLowerCase()] = relation;
    if (alias && !SQL_KEYWORDS.has(alias)) aliases[alias] = relation;
  }
  return aliases;
}
function sqlCompletionInsideLiteral(text) {
  var quote = '';
  var blockComment = false;
  var index;
  for (index = 0; index < text.length; index += 1) {
    var char = text[index];
    var next = text[index + 1];
    if (blockComment) {
      if (char === '*' && next === '/') { blockComment = false; index += 1; }
      continue;
    }
    if (quote) {
      if (char === '\\') { index += 1; continue; }
      if (char === quote) {
        if (next === quote && quote !== '`') { index += 1; continue; }
        quote = '';
      }
      continue;
    }
    if (char === '/' && next === '*') { blockComment = true; index += 1; continue; }
    if (char === '-' && next === '-') { var lineEnd = text.indexOf('\n', index + 2); index = lineEnd < 0 ? text.length : lineEnd; continue; }
    if (char === '#') { var hashEnd = text.indexOf('\n', index + 1); index = hashEnd < 0 ? text.length : hashEnd; continue; }
    if (char === "'" || char === '"' || char === '`') quote = char;
  }
  return Boolean(quote || blockComment);
}
function sqlCompletionToken() {
  var caret = sqlInput.selectionStart === undefined || sqlInput.selectionStart === null ? sqlInput.value.length : sqlInput.selectionStart;
  var before = sqlInput.value.slice(0, caret);
  var match = /([A-Za-z_][\w$]*)$/.exec(before);
  var prefix = match ? match[1] : '';
  var start = caret - prefix.length;
  var statementStart = before.lastIndexOf(';') + 1;
  var statement = before.slice(statementStart);
  return { caret: caret, start: start, prefix: prefix, statement: statement, qualified: /([A-Za-z_][\w$]*)\.\s*([A-Za-z_][\w$]*)?$/.exec(statement), beforeToken: before.slice(statementStart, start) };
}
function sqlCompletionAdd(items, label, insert, kind, detail) {
  var key = String(kind + ':' + label).toLowerCase();
  var index;
  for (index = 0; index < items.length; index += 1) if (String(items[index].kind + ':' + items[index].label).toLowerCase() === key) return;
  items.push({ label: label, insert: insert, kind: kind, detail: detail || '' });
}
function sqlCompletionColumns(items, relation) {
  var columns = relation && relation.value && relation.value.columns || [];
  var index;
  for (index = 0; index < columns.length; index += 1) {
    var column = columns[index];
    sqlCompletionAdd(items, String(column.name), sqlCompletionIdentifier(column.name), 'column', String(column.type || 'TEXT'));
  }
}
function sqlCompletionItems(token) {
  var prefix = token.prefix.toLowerCase();
  var items = [];
  var aliases = sqlCompletionAliases(token.statement);
  var qualifier = token.qualified && token.qualified[1] && token.qualified[1].toLowerCase();
  var index;
  if (qualifier) {
    sqlCompletionColumns(items, aliases[qualifier] || sqlCompletionRelation(qualifier));
  } else {
    var context = token.beforeToken.trim();
    var wantsRelation = /\b(?:from|join|update|into|table|describe|desc|truncate)\s*$/i.test(context) || /\b(?:create|drop)\s+(?:unique\s+)?index\b[\s\S]*\bon\s*$/i.test(context) || /\b(?:create|drop)\s+trigger\b[\s\S]*\bon\s*$/i.test(context);
    var wantsDatabase = /\b(?:use|database)\s*$/i.test(context);
    var db = sandbox.dbs && sandbox.dbs[currentDbName()] || {};
    var viewsForDb = sandbox.views && sandbox.views[currentDbName()] || {};
    if (wantsDatabase) {
      var dbNames = visibleDbNames(sandbox);
      for (index = 0; index < dbNames.length; index += 1) sqlCompletionAdd(items, dbNames[index], sqlCompletionIdentifier(dbNames[index]), 'database', 'database');
    } else if (wantsRelation) {
      var tableNames = Object.keys(db);
      var viewNames = Object.keys(viewsForDb);
      for (index = 0; index < tableNames.length; index += 1) sqlCompletionAdd(items, tableNames[index], sqlCompletionIdentifier(tableNames[index]), 'table', 'table');
      for (index = 0; index < viewNames.length; index += 1) sqlCompletionAdd(items, viewNames[index], sqlCompletionIdentifier(viewNames[index]), 'view', 'view');
    } else {
      var relationNames = Object.keys(db);
      for (index = 0; index < relationNames.length; index += 1) sqlCompletionColumns(items, { value: db[relationNames[index]] });
      SQL_FUNCTIONS.forEach(function (name) { sqlCompletionAdd(items, name.toUpperCase(), name.toUpperCase() + '()', 'function', 'function'); });
      SQL_TYPES.forEach(function (type) { sqlCompletionAdd(items, type.toUpperCase(), type.toUpperCase(), 'type', 'type'); });
      for (index = 0; index < SQL_COMPLETION_KEYWORDS.length; index += 1) sqlCompletionAdd(items, SQL_COMPLETION_KEYWORDS[index], SQL_COMPLETION_KEYWORDS[index], 'keyword', 'keyword');
    }
  }
  function rank(item) {
    var label = item.label.toLowerCase();
    if (!prefix) return 1;
    if (label.indexOf(prefix) === 0) return 0;
    return label.indexOf(prefix) !== -1 ? 2 : 9;
  }
  return items.filter(function (item) { return rank(item) < 9; }).sort(function (a, b) { return rank(a) - rank(b) || a.label.localeCompare(b.label); }).slice(0, 18);
}
function positionSqlCompletions() {
  if (!sqlCompletionState.open) return;
  var caret = sqlCompletionState.end;
  var lineStart = sqlInput.value.lastIndexOf('\n', caret - 1) + 1;
  var line = sqlInput.value.slice(lineStart, caret).replace(/\t/g, '    ');
  var lineNumber = sqlInput.value.slice(0, lineStart).split('\n').length - 1;
  sqlCompletionCanvas = sqlCompletionCanvas || document.createElement('canvas');
  var style = getComputedStyle(sqlInput);
  var context = sqlCompletionCanvas.getContext('2d');
  context.font = style.fontSize + ' ' + style.fontFamily;
  var left = Math.max(4, Math.min(sqlInput.clientWidth - 424, 14 + context.measureText(line).width - sqlInput.scrollLeft));
  var naturalTop = 12 + (lineNumber + 1) * SQL_EDITOR_LINE_HEIGHT - sqlInput.scrollTop;
  var top = naturalTop + 272 > sqlInput.clientHeight ? Math.max(4, naturalTop - 278) : naturalTop;
  sqlCompletions.style.left = left + 'px';
  sqlCompletions.style.top = top + 'px';
}
function closeSqlCompletions() {
  sqlCompletionState = { open: false, items: [], active: 0, start: 0, end: 0 };
  sqlCompletions.hidden = true;
  sqlCompletions.textContent = '';
}
function renderSqlCompletions() {
  var index;
  sqlCompletions.textContent = '';
  for (index = 0; index < sqlCompletionState.items.length; index += 1) (function (item, itemIndex) {
    var button = document.createElement('button');
    var icon = document.createElement('span');
    var label = document.createElement('span');
    var detail = document.createElement('span');
    button.type = 'button';
    button.className = 'sql-completion' + (itemIndex === sqlCompletionState.active ? ' active' : '');
    button.setAttribute('role', 'option');
    button.setAttribute('aria-selected', String(itemIndex === sqlCompletionState.active));
    icon.className = 'sql-completion-icon'; icon.textContent = sqlCompletionIcon(item.kind);
    label.className = 'sql-completion-label'; label.textContent = item.label;
    detail.className = 'sql-completion-detail'; detail.textContent = item.detail;
    button.appendChild(icon); button.appendChild(label); button.appendChild(detail);
    button.addEventListener('mousedown', function (event) { event.preventDefault(); applySqlCompletion(itemIndex); });
    sqlCompletions.appendChild(button);
  }(sqlCompletionState.items[index], index));
  sqlCompletions.hidden = false;
  positionSqlCompletions();
  if (sqlCompletions.children[sqlCompletionState.active] && sqlCompletions.children[sqlCompletionState.active].scrollIntoView) sqlCompletions.children[sqlCompletionState.active].scrollIntoView(false);
}
function updateSqlCompletions(force) {
  if (force === undefined) force = false;
  var caret = sqlInput.selectionStart === undefined || sqlInput.selectionStart === null ? 0 : sqlInput.selectionStart;
  if (sqlEditorMetrics.large || sqlCompletionInsideLiteral(sqlInput.value.slice(0, caret))) { closeSqlCompletions(); return; }
  var token = sqlCompletionToken();
  var contextExpected = /\b(?:select|from|join|where|on|set|values|show|use|create|alter|drop)\s*$/i.test(token.statement);
  if (!force && !token.prefix && !token.qualified && !contextExpected) { closeSqlCompletions(); return; }
  var items = sqlCompletionItems(token);
  if (!items.length) { closeSqlCompletions(); return; }
  sqlCompletionState = { open: true, items: items, active: 0, start: token.start, end: token.caret };
  renderSqlCompletions();
}
function applySqlCompletion(index) {
  if (index === undefined) index = sqlCompletionState.active;
  var item = sqlCompletionState.items[index];
  if (!item) { closeSqlCompletions(); return; }
  var before = sqlInput.value.slice(0, sqlCompletionState.start);
  var after = sqlInput.value.slice(sqlCompletionState.end);
  sqlInput.value = before + item.insert + after;
  var caret = before.length + item.insert.length - (item.kind === 'function' ? 1 : 0);
  sqlInput.setSelectionRange(caret, caret);
  updateSqlEditor();
  scheduleSqlAnalysis();
  closeSqlCompletions();
}
var SQL_INDENT = '\t';
var SQL_CORRECTIONS = {
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
  whree: 'WHERE'
};
function createInitialSandbox() {
  return {
    currentDb: '',
    dbs: {},
    views: {}
  };
}
function createDefaultTable(name) {
  return {
    columns: [{
      name: 'id',
      type: 'INT'
    }, {
      name: 'created_at',
      type: 'VARCHAR(32)'
    }],
    rows: [],
    indexes: [{
      name: 'PRIMARY',
      columns: ['id']
    }]
  };
}
function normalizeSandbox(value) {
  if (!value || !value.dbs || typeof value.dbs !== 'object') return createInitialSandbox();
  if (!value.views || typeof value.views !== 'object') value.views = {};
  for (var _i2 = 0, _Object$keys = Object.keys(value.dbs); _i2 < _Object$keys.length; _i2++) {
    var key = _Object$keys[_i2];
    if (!value.dbs[key] || typeof value.dbs[key] !== 'object') value.dbs[key] = {};
  }
  for (var _i3 = 0, _Object$keys2 = Object.keys(value.views); _i3 < _Object$keys2.length; _i3++) {
    var _key = _Object$keys2[_i3];
    if (!value.views[_key] || typeof value.views[_key] !== 'object') value.views[_key] = {};
  }
  var names = visibleDbNames(value);
  if (!value.currentDb || !value.dbs[value.currentDb] && !value.views[value.currentDb] || isSystemDb(value.currentDb)) value.currentDb = names[0] || '';
  if (value.currentDb) {
    var _value$dbs, _value$currentDb, _value$views, _value$currentDb2;
    (_value$dbs = value.dbs)[_value$currentDb = value.currentDb] || (_value$dbs[_value$currentDb] = {});
    (_value$views = value.views)[_value$currentDb2 = value.currentDb] || (_value$views[_value$currentDb2] = {});
  }
  for (var _i4 = 0, _Object$values = Object.values(value.dbs); _i4 < _Object$values.length; _i4++) {
    var db = _Object$values[_i4];
    for (var _i5 = 0, _Object$entries = Object.entries(db || {}); _i5 < _Object$entries.length; _i5++) {
      var _Object$entries$_i = _slicedToArray(_Object$entries[_i5], 2),
        tableName = _Object$entries$_i[0],
        table = _Object$entries$_i[1];
      if (DEFAULT_TABLES.includes(tableName) && isGenericDefaultTable(table)) {
        db[tableName] = createDefaultTable(tableName);
        continue;
      }
      table.columns || (table.columns = []);
      table.rows || (table.rows = []);
      table.indexes || (table.indexes = []);
      table.columns = table.columns.map(function (col) {
        return typeof col === 'string' ? {
          name: col,
          type: 'TEXT'
        } : col;
      });
      db[tableName] = table;
    }
  }
  for (var _i6 = 0, _Object$values2 = Object.values(value.views); _i6 < _Object$values2.length; _i6++) {
    var _views = _Object$values2[_i6];
    for (var _i7 = 0, _Object$entries2 = Object.entries(_views || {}); _i7 < _Object$entries2.length; _i7++) {
      var _Object$entries2$_i = _slicedToArray(_Object$entries2[_i7], 2),
        viewName = _Object$entries2$_i[0],
        view = _Object$entries2$_i[1];
      _views[viewName] = {
        name: viewName,
        query: (view === null || view === void 0 ? void 0 : view.query) || '',
        columns: (view === null || view === void 0 ? void 0 : view.columns) || [],
        rows: (view === null || view === void 0 ? void 0 : view.rows) || [],
        isView: true
      };
    }
  }
  return value;
}
function isGenericDefaultTable(table) {
  var _cols$, _cols$2;
  var cols = (table === null || table === void 0 ? void 0 : table.columns) || [];
  var rows = (table === null || table === void 0 ? void 0 : table.rows) || [];
  return rows.length === 0 && cols.length === 2 && (((_cols$ = cols[0]) === null || _cols$ === void 0 ? void 0 : _cols$.name) || cols[0]) === 'id' && (((_cols$2 = cols[1]) === null || _cols$2 === void 0 ? void 0 : _cols$2.name) || cols[1]) === 'created_at';
}
function log(message) {
  var time = new Date().toLocaleTimeString(LANGUAGE_LOCALES[currentLanguage] || LANGUAGE_LOCALES.id);
  logBox.textContent += `[${time}] ${message}\n`;
  logBox.scrollTop = logBox.scrollHeight;
}
function updateArchiveMonitor() {
  return null;
}
function scheduleArchiveRefresh() {
  var _delay = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : 0;
  return null;
}
function buildArchiveModel() {
  var _source$progress;
  var db = currentDbName();
  var selectedRelation = selectedTable ? currentRelation(selectedTable) : null;
  var selectedSource = selectedRelation ? archiveRelationModel(db, selectedTable, selectedRelation) : null;
  var relation = preferredArchiveRelation();
  var querySnapshot = archiveSnapshot.kind === 'query' ? archiveSnapshot : null;
  var importSnapshot = archiveSnapshot.kind === 'import' ? archiveSnapshot : null;
  var recentActivity = archiveSnapshot.updatedAt && Date.now() - archiveSnapshot.updatedAt < 12000;
  var source = selectedSource || (recentActivity ? archiveSnapshot : null) || relation || querySnapshot || importSnapshot;
  var columns = (source === null || source === void 0 ? void 0 : source.columns) || [];
  var rows = (source === null || source === void 0 ? void 0 : source.rows) || [];
  var rowCount = Number.isFinite(source === null || source === void 0 ? void 0 : source.rowCount) ? source.rowCount : rows.length;
  var sizeBytes = (source === null || source === void 0 ? void 0 : source.sizeBytes) || estimateArchiveSize(source);
  var relationName = (source === null || source === void 0 ? void 0 : source.name) || (relation === null || relation === void 0 ? void 0 : relation.name) || '';
  var sourceName = (source === null || source === void 0 ? void 0 : source.dataset) || relationName || (db ? `${db}.asa` : 'waiting_for_dataset.sql');
  var titleDb = (db || 'ASADB').toUpperCase();
  var badge = (source === null || source === void 0 ? void 0 : source.kind) === 'import' ? 'IMPORT' : (source === null || source === void 0 ? void 0 : source.kind) === 'query' ? 'QUERY' : (source === null || source === void 0 ? void 0 : source.kind) === 'view' ? 'VIEW' : 'TABLE';
  var progress = (_source$progress = source === null || source === void 0 ? void 0 : source.progress) !== null && _source$progress !== void 0 ? _source$progress : rowCount > 0 ? 1 : 0;
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
    live: Boolean(db || rows.length || archiveSnapshot.updatedAt)
  };
}
function preferredArchiveRelation() {
  var _sandbox$dbs, _sandbox$views;
  var activeDb = currentDbName();
  if (!activeDb) return null;
  var selected = selectedTable ? currentRelation(selectedTable) : null;
  if (selected) return archiveRelationModel(activeDb, selectedTable, selected);
  var db = ((_sandbox$dbs = sandbox.dbs) === null || _sandbox$dbs === void 0 ? void 0 : _sandbox$dbs[activeDb]) || {};
  var dbViews = ((_sandbox$views = sandbox.views) === null || _sandbox$views === void 0 ? void 0 : _sandbox$views[activeDb]) || {};
  var tableName = Object.keys(db).sort(function (a, b) {
    var _db$b, _db$a;
    return (((_db$b = db[b]) === null || _db$b === void 0 || (_db$b = _db$b.rows) === null || _db$b === void 0 ? void 0 : _db$b.length) || 0) - (((_db$a = db[a]) === null || _db$a === void 0 || (_db$a = _db$a.rows) === null || _db$a === void 0 ? void 0 : _db$a.length) || 0) || a.localeCompare(b);
  })[0];
  if (tableName) return archiveRelationModel(activeDb, tableName, {
    kind: 'table',
    value: db[tableName]
  });
  var viewName = Object.keys(dbViews).sort(function (a, b) {
    return a.localeCompare(b);
  })[0];
  if (viewName) return archiveRelationModel(activeDb, viewName, {
    kind: 'view',
    value: dbViews[viewName]
  });
  return null;
}
function archiveRelationModel(db, name, relation) {
  var value = relation.value || {};
  var columns = (value.columns || []).map(function (col) {
    return col.name || col;
  });
  var rows = relation.kind === 'view' ? value.rows || [] : (value.rows || []).map(function (row) {
    return columns.map(function (column) {
      var _row$column;
      return (_row$column = row === null || row === void 0 ? void 0 : row[column]) !== null && _row$column !== void 0 ? _row$column : null;
    });
  });
  var rowCount = Number.isFinite(value.rowCount) ? value.rowCount : rows.length;
  return {
    kind: relation.kind,
    name,
    dataset: `${db}.${name}.${relation.kind === 'view' ? 'view' : 'asa'}`,
    columns,
    rows,
    rowCount,
    sizeBytes: estimateArchiveSize({
      columns,
      rows
    }),
    progress: rowCount ? 1 : 0
  };
}
function noteArchiveQuery(results) {
  var sql = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : '';
  var tableResult = (results || []).find(function (item) {
    return item.status === 'table';
  });
  if (!tableResult) return;
  archiveSnapshot = {
    kind: 'query',
    dataset: inferArchiveDatasetFromSql(sql) || 'query_result.sql',
    columns: tableResult.columns || [],
    rows: tableResult.rows || [],
    rowCount: (tableResult.rows || []).length,
    sizeBytes: estimateArchiveSize(tableResult),
    progress: 1,
    updatedAt: Date.now()
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
    updatedAt: Date.now()
  };
  updateArchiveMonitor();
  scheduleArchiveRefresh();
}
function noteArchiveImportComplete(name, sizeBytes, columns, rows, rowCount) {
  archiveSnapshot = {
    kind: 'import',
    dataset: name || 'imported_dataset.sql',
    columns: columns !== null && columns !== void 0 && columns.length ? columns : ['status', 'dataset', 'rows'],
    rows: rows !== null && rows !== void 0 && rows.length ? rows : [['loaded', name || 'dataset', rowCount || 0]],
    rowCount: Number.isFinite(rowCount) ? rowCount : (rows || []).length,
    sizeBytes: sizeBytes || estimateArchiveSize({
      columns,
      rows
    }),
    progress: 1,
    updatedAt: Date.now()
  };
  updateArchiveMonitor();
  scheduleArchiveRefresh();
}
function noteArchiveSqlProgress(sql, completed, total) {
  var _text$match;
  var label = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : '';
  var text = String(label || '').replace(/\s+/g, ' ').trim();
  var verb = ((_text$match = text.match(/^([A-Za-z]+(?:\s+[A-Za-z]+)?)/)) === null || _text$match === void 0 ? void 0 : _text$match[1]) || 'SQL';
  archiveSnapshot = {
    kind: 'import',
    dataset: inferArchiveDatasetFromSql(sql) || 'batched_sql_import.sql',
    columns: ['step', 'statement', 'status'],
    rows: [[completed, verb.toUpperCase(), `${completed}/${total}`]],
    rowCount: completed,
    sizeBytes: String(sql || '').length,
    progress: total ? completed / total : 0,
    updatedAt: Date.now()
  };
  updateArchiveMonitor();
}
function inferArchiveDatasetFromSql(sql) {
  var source = String(sql || '');
  var text = source.slice(Math.max(0, source.length - 512 * 1024)).replace(/`/g, '').trim();
  var pattern = /\b(?:from|into|table|view)\s+([A-Za-z_][\w$]*)/gi;
  var match;
  var last = '';
  while (match = pattern.exec(text)) last = match[1];
  var db = currentDbName();
  if (!last) return db ? `${db}.query.sql` : 'query_result.sql';
  return db ? `${db}.${last}.sql` : `${last}.sql`;
}
function inferArchiveRange(columns, rows) {
  var years = [];
  var _iterator = _createForOfIteratorHelper(rows || []),
    _step;
  try {
    var _loop2 = function _loop2() {
      var row = _step.value;
      var values = Array.isArray(row) ? row : columns.map(function (column) {
        return row === null || row === void 0 ? void 0 : row[column];
      });
      var _iterator2 = _createForOfIteratorHelper(values),
        _step2;
      try {
        for (_iterator2.s(); !(_step2 = _iterator2.n()).done;) {
          var value = _step2.value;
          var match = String(value !== null && value !== void 0 ? value : '').match(/\b(19\d{2}|20\d{2})\b/);
          if (match) years.push(Number(match[1]));
        }
      } catch (err) {
        _iterator2.e(err);
      } finally {
        _iterator2.f();
      }
    };
    for (_iterator.s(); !(_step = _iterator.n()).done;) {
      _loop2();
    }
  } catch (err) {
    _iterator.e(err);
  } finally {
    _iterator.f();
  }
  if (!years.length) return new Date().getFullYear().toString();
  var min = Math.min.apply(Math, years);
  var max = Math.max.apply(Math, years);
  return min === max ? String(min) : `${min}-${max}`;
}
function buildArchiveFeedRows(columns, rows) {
  var sample = (rows || []).slice(-4);
  return sample.map(function (row, index) {
    var values = Array.isArray(row) ? row : columns.map(function (column) {
      return row === null || row === void 0 ? void 0 : row[column];
    });
    var visible = values.slice(0, 4).map(function (value) {
      return value === null || value === undefined ? 'NULL' : String(value);
    });
    return {
      index: String(index + 1).padStart(7, '0'),
      text: visible.join(' | ')
    };
  });
}
function estimateArchiveSize(source) {
  try {
    return new TextEncoder().encode(JSON.stringify({
      columns: (source === null || source === void 0 ? void 0 : source.columns) || [],
      rows: (source === null || source === void 0 ? void 0 : source.rows) || []
    })).length;
  } catch (_) {
    return 0;
  }
}
function formatBytes(bytes) {
  var value = Number(bytes) || 0;
  if (value < 1024) return `${value} B`;
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(value < 10 * 1024 ? 1 : 0)} KB`;
  if (value < 1024 * 1024 * 1024) return `${(value / (1024 * 1024)).toFixed(value < 10 * 1024 * 1024 ? 1 : 0)} MB`;
  return `${(value / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}
function formatNumber(value) {
  return new Intl.NumberFormat(LANGUAGE_LOCALES[currentLanguage] || LANGUAGE_LOCALES.id).format(Number(value) || 0);
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
function visibleDbNames() {
  var state = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : sandbox;
  var names = new Set([].concat(_toConsumableArray(Object.keys((state === null || state === void 0 ? void 0 : state.dbs) || {})), _toConsumableArray(Object.keys((state === null || state === void 0 ? void 0 : state.views) || {}))));
  return _toConsumableArray(names).filter(function (name) {
    return !isSystemDb(name);
  }).sort(function (a, b) {
    return a.localeCompare(b);
  });
}
function currentDbName() {
  return sandbox.currentDb && !isSystemDb(sandbox.currentDb) ? sandbox.currentDb : '';
}
function ensureCurrentDb() {
  var action = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : 'melakukan aksi ini';
  var current = currentDbName();
  if (current) return current;
  log(t('database.selectFirst'));
  return '';
}
function lineNumberAtIndex(text, index) {
  var line = 1;
  for (var i = 0; i < index && i < text.length; i += 1) if (text[i] === '\n') line += 1;
  return line;
}
function copySqlQuoted(text, start) {
  var quote = text[start];
  var i = start + 1;
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
    var _end = text.indexOf('*/', start + 2);
    return _end === -1 ? text.length : _end + 2;
  }
  var end = text.indexOf('\n', start + 1);
  return end === -1 ? text.length : end;
}
function transformSqlWords(sql, mapWord) {
  var out = '';
  var i = 0;
  while (i < sql.length) {
    if (sql.startsWith('--', i) || sql.startsWith('/*', i) || sql[i] === '#') {
      var end = copySqlComment(sql, i);
      out += sql.slice(i, end);
      i = end;
      continue;
    }
    if (sql[i] === '\'' || sql[i] === '"' || sql[i] === '`') {
      var _end2 = copySqlQuoted(sql, i);
      out += sql.slice(i, _end2);
      i = _end2;
      continue;
    }
    if (/[A-Za-z_]/.test(sql[i])) {
      var start = i;
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
  var changes = [];
  var text = transformSqlWords(sql, function (word, index) {
    var replacement = SQL_CORRECTIONS[word.toLowerCase()];
    if (!replacement) return word;
    changes.push({
      from: word,
      to: replacement,
      line: lineNumberAtIndex(sql, index)
    });
    return replacement;
  });
  return {
    text,
    changes
  };
}
function applySqlAutoCorrection() {
  var _sqlInput$selectionSt;
  var force = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : false;
  var value = sqlInput.value;
  if (value.length >= LARGE_SQL_EDITOR_CHAR_LIMIT) return false;
  var cursor = (_sqlInput$selectionSt = sqlInput.selectionStart) !== null && _sqlInput$selectionSt !== void 0 ? _sqlInput$selectionSt : value.length;
  var previous = value[cursor - 1] || '';
  if (!force && previous && !/[\s;(),]/.test(previous)) return false;
  var corrected = correctSqlText(value);
  if (!corrected.changes.length || corrected.text === value) return false;
  var beforeCursor = correctSqlText(value.slice(0, cursor)).text;
  sqlInput.value = corrected.text;
  var nextCursor = Math.min(beforeCursor.length, sqlInput.value.length);
  sqlInput.setSelectionRange(nextCursor, nextCursor);
  updateSqlEditor();
  log(`${ASA_CORRECTION_LABEL}: ${corrected.changes.map(function (x) {
    return `${x.from} -> ${x.to}`;
  }).join(', ')}.`);
  return true;
}
function highlightSql(sql) {
  var html = '';
  var i = 0;
  while (i < sql.length) {
    if (sql.startsWith('--', i) || sql.startsWith('/*', i) || sql[i] === '#') {
      var end = copySqlComment(sql, i);
      html += `<span class="sql-comment">${escapeHtml(sql.slice(i, end))}</span>`;
      i = end;
      continue;
    }
    if (sql[i] === '\'' || sql[i] === '"' || sql[i] === '`') {
      var _end3 = copySqlQuoted(sql, i);
      var cls = sql[i] === '`' ? 'sql-identifier' : 'sql-string';
      html += `<span class="${cls}">${escapeHtml(sql.slice(i, _end3))}</span>`;
      i = _end3;
      continue;
    }
    if (/\d/.test(sql[i])) {
      var start = i;
      i += 1;
      while (i < sql.length && /[\d.]/.test(sql[i])) i += 1;
      html += `<span class="sql-number">${escapeHtml(sql.slice(start, i))}</span>`;
      continue;
    }
    if (/[A-Za-z_]/.test(sql[i])) {
      var _start = i;
      i += 1;
      while (i < sql.length && /[\w$]/.test(sql[i])) i += 1;
      var word = sql.slice(_start, i);
      var lower = word.toLowerCase();
      var _cls = SQL_TYPES.has(lower) ? 'sql-type' : SQL_FUNCTIONS.has(lower) ? 'sql-function' : SQL_KEYWORDS.has(lower) ? 'sql-keyword' : 'sql-identifier';
      html += `<span class="${_cls}">${escapeHtml(word)}</span>`;
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
  var balance = 0;
  var i = 0;
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
  var value = String(text || '');
  var hash = 0;
  for (var i = 0; i < value.length; i += 1) {
    hash = (hash << 5) - hash + value.charCodeAt(i) | 0;
  }
  return Math.abs(hash);
}
function asaPick(list, seed) {
  if (!list.length) return '';
  return list[asaHash(seed) % list.length];
}
function asaCleanMessage(message) {
  return String(message || '').replace(/^ERROR:\s*/i, '').replace(/^Backend Prolog gagal:\s*/i, '').replace(/\s+/g, ' ').trim();
}
function asaReadableRaw(message) {
  var text = asaCleanMessage(message);
  if (!text || text.length > 150) return '';
  if (/raw\(|kw\(|id\('|feature\(|table_ref\(|select\(|insert\(|update\(|delete\(|\[[^\]]{12,}\]/i.test(text)) return '';
  return text;
}
function asaCode(value) {
  var text = String(value || '').replace(/[`'"]/g, '').trim();
  return text ? `\`${text}\`` : '`?`';
}
function asaFeatureName(message) {
  var _exec;
  var feature = (_exec = /feature\(([^,\)]+)/i.exec(message)) === null || _exec === void 0 ? void 0 : _exec[1];
  return feature ? feature.replace(/_/g, ' ').toUpperCase() : 'SQL ini';
}
function asaCorrectionPair(message) {
  var text = asaCleanMessage(message);
  var match = /Auto correction tersedia:\s*([A-Za-z_][\w$]*)\s*->\s*([A-Za-z_][\w$]*(?:\s+[A-Za-z_][\w$]*)?)/i.exec(text);
  if (match) return {
    from: match[1],
    to: match[2]
  };
  match = /([A-Za-z_][\w$]*)\s*->\s*([A-Za-z_][\w$]*(?:\s+[A-Za-z_][\w$]*)?)/i.exec(text);
  return match ? {
    from: match[1],
    to: match[2]
  } : null;
}
function asaErrorDetail(message) {
  var text = asaCleanMessage(message);
  if (currentLanguage === 'en') return asaErrorDetailEnglish(text);
  if (currentLanguage === 'ja') return asaErrorDetailJapanese(text);
  var match;
  if (!text) return 'Asa tidak dapat pesan lengkapnya. Coba ulangi dari baris yang baru kamu ubah.';
  if (/select or create a database first|no database|database.*not selected/i.test(text)) {
    return 'Pilih atau buat database dulu. Asa perlu tahu tabelnya tinggal di rumah yang mana.';
  }
  if ((match = /table not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown table\s+([A-Za-z_][\w$]*)/i.exec(text))) {
    return `Tabel ${asaCode(match[1])} belum ada di database aktif. Cek pilihan DB di kiri, atau buat tabelnya dulu.`;
  }
  if (match = /table_ref\('([^']+)'/i.exec(text)) {
    return `Tabel ${asaCode(match[1])} belum ada di database aktif. Cek pilihan DB di kiri, atau buat tabelnya dulu.`;
  }
  if ((match = /column not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown column\s+([A-Za-z_][\w$]*)/i.exec(text))) {
    return `Kolom ${asaCode(match[1])} belum ada di tabel itu. Cek ejaan nama kolom atau lihat struktur tabelnya dulu.`;
  }
  if (match = /Statement\s+"?([A-Za-z_][\w$]*)"?\s+belum dikenali/i.exec(text)) {
    return `Pembuka ${asaCode(match[1])} belum Asa kenal. Biasanya ini typo dari CREATE, SELECT, INSERT, UPDATE, DELETE, ALTER, DROP, SHOW, atau DESCRIBE.`;
  }
  if (/belum dikenali|unknown statement|unrecognized/i.test(text)) {
    return 'Perintah pembukanya belum cocok. Coba mulai dengan kata SQL yang umum seperti SELECT, CREATE, INSERT, UPDATE, DELETE, ALTER, DROP, SHOW, atau DESCRIBE.';
  }
  if (match = /sandbox belum support:\s*(.+)$/i.exec(text)) {
    var firstWords = match[1].slice(0, 90);
    return `Mode sandbox belum bisa menjalankan bentuk ini. Kalau butuh fitur penuh, pastikan Mode Prolog backend online. Asa melihat awalnya: ${firstWords}`;
  }
  if (/belum support|belum aktif|not implemented|feature\(/i.test(text)) {
    return `${asaFeatureName(text)} sudah kebaca, tapi jalur eksekusinya belum dibuka di bagian ini. Pakai bentuk yang lebih sederhana dulu atau jalankan lewat backend Prolog terbaru.`;
  }
  if (/Missing or oversized|oversized|payload|too large|terlalu besar/i.test(text)) {
    return 'Isinya terlalu besar untuk jalur tempel biasa. Pakai menu Import file supaya Asa membaca pelan-pelan, bukan sekali telan.';
  }
  if (/Import file path is not allowed|not found|file.*not/i.test(text)) {
    return 'File import belum ketemu di tempat yang Asa izinkan. Taruh di folder stress tests atau web/samples, atau pilih file langsung dari tombol upload.';
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
    var _raw = asaReadableRaw(text);
    return _raw ? `Susunan katanya belum pas di dekat bagian ini: ${_raw}. Cek koma, tanda petik, kurung, dan urutan kata SQL.` : 'Susunan katanya belum pas. Cek koma, tanda petik, kurung, dan urutan kata SQL di baris itu.';
  }
  var raw = asaReadableRaw(text);
  return raw ? `Asa belum bisa menerima bagian ini. Cek nama tabel, nama kolom, tanda baca, dan urutan katanya. Asa melihat: ${raw}` : 'Asa belum bisa menerima bagian ini. Cek nama tabel, nama kolom, tanda baca, dan urutan katanya.';
}
function asaErrorDetailEnglish(text) {
  var match;
  if (!text) return 'The complete error was unavailable. Retry from the line you most recently changed.';
  if (/select or create a database first|no database|database.*not selected|pilih atau buat database/i.test(text)) {
    return 'Select or create a database first so Asa knows where the table belongs.';
  }
  if ((match = /table not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown table\s+([A-Za-z_][\w$]*)/i.exec(text)) || (match = /table_ref\('([^']+)'/i.exec(text))) {
    return `Table ${asaCode(match[1])} is not in the active database. Check the selected DB or create the table first.`;
  }
  if ((match = /column not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown column\s+([A-Za-z_][\w$]*)/i.exec(text))) {
    return `Column ${asaCode(match[1])} is not in that table. Check its spelling or inspect the table structure.`;
  }
  if (/belum dikenali|unknown statement|unrecognized/i.test(text)) return 'The opening command is not recognized. Start with a supported SQL keyword such as SELECT, CREATE, INSERT, UPDATE, DELETE, ALTER, DROP, SHOW, or DESCRIBE.';
  if (match = /sandbox belum support:\s*(.+)$/i.exec(text)) return `Browser sandbox cannot run this form. Use the online Prolog backend for full support. Asa saw: ${match[1].slice(0, 90)}`;
  if (/belum support|belum aktif|not implemented|feature\(/i.test(text)) return 'The feature was recognized, but this execution path is not available here. Use a simpler form or the latest Prolog backend.';
  if (/Missing or oversized|oversized|payload|too large|terlalu besar/i.test(text)) return 'This input is too large for regular paste execution. Use file import so Reservoir can process it incrementally.';
  if (/Import file path is not allowed|not found|file.*not/i.test(text)) return 'The import file was not found in an allowed location. Choose it with Upload or place it in stress tests or web/samples.';
  if (/Kurung buka belum ditutup|opening parenthesis/i.test(text)) return 'An opening parenthesis has no closing partner. Add ) after the relevant columns, VALUES, or condition.';
  if (/Kurung tutup berlebih|closing parenthesis/i.test(text)) return 'There is an extra closing parenthesis. Remove one ) or check the previous pair.';
  if (/titik koma|semicolon|terminated/i.test(text)) return 'The SQL statement is not terminated. Add ; so Asa can identify its end.';
  if (/INSERT.*VALUES|butuh VALUES|missing values/i.test(text)) return 'INSERT needs a VALUES clause after the table and column names.';
  if (/UPDATE\b.*SET|missing set/i.test(text)) return 'UPDATE needs a SET clause describing which column values should change.';
  if (/DELETE\b.*FROM|missing from/i.test(text)) return 'DELETE needs FROM before the table name.';
  if (/duplicate|already exists|sudah ada/i.test(text)) return 'That name already exists. Choose another name or drop the old object first.';
  if (/permission|forbidden|403|denied/i.test(text)) return 'Access was denied. Check the panel token, active user, and database permissions.';
  if (/rollback|rolled back/i.test(text)) return 'Asa rolled the change back to keep the data safe. Fix the first error and retry.';
  if (/HTTP|Failed to fetch|NetworkError|backend/i.test(text)) return 'The panel did not receive a valid backend response. Check that the AsaDB server is running and the Prolog backend is online.';
  if (/syntax|parse|unexpected|invalid|token|near/i.test(text)) return 'The SQL structure is invalid. Check commas, quotes, parentheses, and keyword order on that line.';
  var raw = asaReadableRaw(text);
  return raw ? `Asa could not accept this part. Check table names, columns, punctuation, and keyword order. Asa saw: ${raw}` : 'Asa could not accept this part. Check table names, columns, punctuation, and keyword order.';
}
function asaErrorDetailJapanese(text) {
  var match;
  if (!text) return '完全なエラー内容を取得できませんでした。最後に変更した行からもう一度確認してください。';
  if (/select or create a database first|no database|database.*not selected|pilih atau buat database/i.test(text)) return '先にデータベースを選択または作成してください。アサにはテーブルの保存先が必要です。';
  if ((match = /table not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown table\s+([A-Za-z_][\w$]*)/i.exec(text)) || (match = /table_ref\('([^']+)'/i.exec(text))) return `テーブル ${asaCode(match[1])} は現在のデータベースにありません。DB の選択を確認するか、先にテーブルを作成してください。`;
  if ((match = /column not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown column\s+([A-Za-z_][\w$]*)/i.exec(text))) return `カラム ${asaCode(match[1])} はそのテーブルにありません。名前の綴りまたはテーブル構造を確認してください。`;
  if (/belum dikenali|unknown statement|unrecognized/i.test(text)) return '先頭のコマンドを認識できません。SELECT、CREATE、INSERT、UPDATE、DELETE、ALTER、DROP、SHOW、DESCRIBE などの対応キーワードから始めてください。';
  if (match = /sandbox belum support:\s*(.+)$/i.exec(text)) return `ブラウザーサンドボックスではこの形式を実行できません。全機能にはオンラインの Prolog バックエンドを使用してください。先頭部分: ${match[1].slice(0, 90)}`;
  if (/belum support|belum aktif|not implemented|feature\(/i.test(text)) return '機能は認識されましたが、この実行経路ではまだ利用できません。より単純な形式か最新の Prolog バックエンドを使用してください。';
  if (/Missing or oversized|oversized|payload|too large|terlalu besar/i.test(text)) return '通常の貼り付け実行には大きすぎます。Reservoir が分割処理できるよう、ファイルインポートを使用してください。';
  if (/Import file path is not allowed|not found|file.*not/i.test(text)) return '許可された場所にインポートファイルが見つかりません。アップロードで選択するか、stress tests または web/samples に配置してください。';
  if (/Kurung buka belum ditutup|opening parenthesis/i.test(text)) return '開き括弧に対応する閉じ括弧がありません。カラム、VALUES、条件の末尾に ) を追加してください。';
  if (/Kurung tutup berlebih|closing parenthesis/i.test(text)) return '閉じ括弧が一つ多いようです。) を一つ削除し、括弧の組を確認してください。';
  if (/titik koma|semicolon|terminated/i.test(text)) return 'SQL 文が終了していません。末尾に ; を追加してください。';
  if (/INSERT.*VALUES|butuh VALUES|missing values/i.test(text)) return 'INSERT には、テーブル名とカラム名の後に VALUES 句が必要です。';
  if (/UPDATE\b.*SET|missing set/i.test(text)) return 'UPDATE には、変更する値を指定する SET 句が必要です。';
  if (/DELETE\b.*FROM|missing from/i.test(text)) return 'DELETE ではテーブル名の前に FROM が必要です。';
  if (/duplicate|already exists|sudah ada/i.test(text)) return '同じ名前がすでに存在します。別の名前を選ぶか、古いオブジェクトを先に削除してください。';
  if (/permission|forbidden|403|denied/i.test(text)) return 'アクセスが拒否されました。パネルトークン、現在のユーザー、データベース権限を確認してください。';
  if (/rollback|rolled back/i.test(text)) return 'データを守るため、アサが変更をロールバックしました。最初のエラーを修正して再実行してください。';
  if (/HTTP|Failed to fetch|NetworkError|backend/i.test(text)) return 'バックエンドから正しい応答を受け取れませんでした。AsaDB サーバーと Prolog バックエンドの状態を確認してください。';
  if (/syntax|parse|unexpected|invalid|token|near/i.test(text)) return 'SQL の構造が正しくありません。その行のカンマ、引用符、括弧、キーワード順を確認してください。';
  var raw = asaReadableRaw(text);
  return raw ? `この部分を受け入れられません。テーブル名、カラム名、記号、キーワード順を確認してください。内容: ${raw}` : 'この部分を受け入れられません。テーブル名、カラム名、記号、キーワード順を確認してください。';
}
function asaCorrectionDetail(item) {
  var text = asaCleanMessage(item === null || item === void 0 ? void 0 : item.message);
  var pair = asaCorrectionPair(text);
  if (currentLanguage === 'en') {
    if (pair) return `Did you mean ${asaCode(pair.to)} instead of ${asaCode(pair.from)}? Asa can correct it automatically before execution.`;
    if (/titik koma|semicolon|terminated/i.test(text)) return 'Add ; at the end so Asa knows where the SQL statement finishes.';
    if (/Kurung buka belum ditutup|opening parenthesis/i.test(text)) return 'An opening parenthesis is missing its closing ).';
    if (/Kurung tutup berlebih|closing parenthesis/i.test(text)) return 'There is one extra closing parenthesis on this line.';
    if (/INSERT.*VALUES|butuh VALUES|missing values/i.test(text)) return 'Add VALUES and the data after the INSERT table name.';
    if (item !== null && item !== void 0 && item.correction) return `Try this form: ${item.correction}`;
    return asaErrorDetailEnglish(text);
  }
  if (currentLanguage === 'ja') {
    if (pair) return `${asaCode(pair.from)} ではなく ${asaCode(pair.to)} の意味でしょうか。実行前にアサが自動修正できます。`;
    if (/titik koma|semicolon|terminated/i.test(text)) return 'SQL 文の終わりが分かるよう、末尾に ; を追加してください。';
    if (/Kurung buka belum ditutup|opening parenthesis/i.test(text)) return '開き括弧に対応する閉じ括弧 ) がありません。';
    if (/Kurung tutup berlebih|closing parenthesis/i.test(text)) return 'この行には閉じ括弧が一つ多くあります。';
    if (/INSERT.*VALUES|butuh VALUES|missing values/i.test(text)) return 'INSERT のテーブル名の後に VALUES とデータを追加してください。';
    if (item !== null && item !== void 0 && item.correction) return `この形式を試してください: ${item.correction}`;
    return asaErrorDetailJapanese(text);
  }
  if (pair) return `Kata ${asaCode(pair.from)} kayaknya maksudmu ${asaCode(pair.to)}. Asa bisa rapihin itu otomatis sebelum dijalankan.`;
  if (/titik koma|semicolon|terminated/i.test(text)) return 'Tambahkan ; di ujung perintah. Itu tanda buat Asa bahwa satu kalimat SQL sudah selesai.';
  if (/Kurung buka belum ditutup|opening parenthesis/i.test(text)) return 'Ada kurung buka yang belum ditutup. Cari daftar kolom, VALUES, atau kondisi yang belum punya pasangan ).';
  if (/Kurung tutup berlebih|closing parenthesis/i.test(text)) return 'Ada kurung tutup yang kebanyakan. Coba hapus satu ) di baris itu.';
  if (/INSERT.*VALUES|butuh VALUES|missing values/i.test(text)) return 'Untuk INSERT, setelah nama tabel tulis VALUES lalu isi datanya. Tanpa itu Asa belum tahu apa yang masuk.';
  if (item !== null && item !== void 0 && item.correction) return `Coba bentuk ini: ${item.correction}`;
  return asaErrorDetail(text);
}
function asaSuccessDetail(message) {
  var text = asaCleanMessage(message);
  if (currentLanguage === 'en') return asaSuccessDetailEnglish(text);
  if (currentLanguage === 'ja') return asaSuccessDetailJapanese(text);
  var match;
  if (match = /^created_database\(([^)]+)\)/i.exec(text)) return `Database ${asaCode(match[1])} sudah dibuat dan siap dipakai.`;
  if (match = /^using_database\(([^)]+)\)/i.exec(text)) return `Sekarang Asa bekerja di database ${asaCode(match[1])}.`;
  if (match = /^dropped_database\(([^)]+)\)/i.exec(text)) return `Database ${asaCode(match[1])} sudah dilepas dari daftar.`;
  if (match = /^created_table\(([^)]+)\)/i.exec(text)) return `Tabel ${asaCode(match[1])} sudah lahir.`;
  if (match = /^altered_table\(([^)]+)\)/i.exec(text)) return `Bentuk tabel ${asaCode(match[1])} sudah diperbarui.`;
  if (match = /^dropped_table\(([^)]+)\)/i.exec(text)) return `Tabel ${asaCode(match[1])} sudah dihapus dari database aktif.`;
  if (match = /^truncated_table\(([^)]+)\)/i.exec(text)) return `Isi tabel ${asaCode(match[1])} sudah dikosongkan, strukturnya tetap ada.`;
  if (match = /^inserted\(([^,]+),\s*([^)]+)\)/i.exec(text)) return `${match[2]} baris sudah masuk ke tabel ${asaCode(match[1])}.`;
  if (match = /^updated\(([^,]+),\s*([^)]+)\)/i.exec(text)) return `${match[2]} baris di tabel ${asaCode(match[1])} sudah diperbarui.`;
  if (match = /^deleted\(([^,]+),\s*([^)]+)\)/i.exec(text)) return `${match[2]} baris dari tabel ${asaCode(match[1])} sudah dihapus.`;
  if (match = /^created_index\(([^,]+),\s*([^)]+)\)/i.exec(text)) return `Index ${asaCode(match[1])} sudah dibuat untuk tabel ${asaCode(match[2])}.`;
  if (match = /^created_view\(([^)]+)\)/i.exec(text)) return `View ${asaCode(match[1])} sudah dibuat dan akan muncul di daftar samping.`;
  if (match = /^dropped_view\(([^)]+)\)/i.exec(text)) return `View ${asaCode(match[1])} sudah dihapus.`;
  if (match = /^created_user\(([^)]+)\)/i.exec(text)) return `User ${asaCode(match[1])} sudah dibuat.`;
  if (/^granted\(/i.test(text)) return 'Izin sudah diberikan ke user yang dipilih.';
  if (/^revoked\(/i.test(text)) return 'Izin sudah dicabut dari user yang dipilih.';
  if (/^committed|commit$/i.test(text)) return 'Transaksi sudah dikunci. Perubahan resmi tersimpan.';
  if (/^rolled_back|rollback$/i.test(text)) return 'Transaksi sudah dibatalkan. Data balik aman seperti sebelumnya.';
  if (/^started_transaction|begin|start_transaction$/i.test(text)) return 'Transaksi sudah dibuka. Asa akan menunggu COMMIT atau ROLLBACK.';
  if (match = /^batch_completed\(([^)]+)\)/i.exec(text)) return `Batch selesai. ${match[1]} berhasil dilewati.`;
  if (/^ok$/i.test(text) || /^done$/i.test(text)) return 'Perintah selesai dan tidak ada yang protes.';
  return text ? `Perintah selesai. Catatan Asa: ${text}` : 'Perintah selesai dan database tetap tenang.';
}
function asaSuccessDetailEnglish(text) {
  var match;
  if (match = /^created_database\(([^)]+)\)/i.exec(text)) return `Database ${asaCode(match[1])} was created and is ready.`;
  if (match = /^using_database\(([^)]+)\)/i.exec(text)) return `Asa is now working in database ${asaCode(match[1])}.`;
  if (match = /^dropped_database\(([^)]+)\)/i.exec(text)) return `Database ${asaCode(match[1])} was dropped.`;
  if (match = /^created_table\(([^)]+)\)/i.exec(text)) return `Table ${asaCode(match[1])} was created.`;
  if (match = /^altered_table\(([^)]+)\)/i.exec(text)) return `Table ${asaCode(match[1])} was updated.`;
  if (match = /^dropped_table\(([^)]+)\)/i.exec(text)) return `Table ${asaCode(match[1])} was removed from the active database.`;
  if (match = /^truncated_table\(([^)]+)\)/i.exec(text)) return `Rows in ${asaCode(match[1])} were cleared while its structure was kept.`;
  if (match = /^(inserted|updated|deleted)\(([^,]+),\s*([^)]+)\)/i.exec(text)) return `${match[3]} row(s) were ${match[1]} in ${asaCode(match[2])}.`;
  if (match = /^created_index\(([^,]+),\s*([^)]+)\)/i.exec(text)) return `Index ${asaCode(match[1])} was created for ${asaCode(match[2])}.`;
  if (match = /^created_view\(([^)]+)\)/i.exec(text)) return `View ${asaCode(match[1])} was created.`;
  if (match = /^dropped_view\(([^)]+)\)/i.exec(text)) return `View ${asaCode(match[1])} was dropped.`;
  if (/^committed|commit$/i.test(text)) return 'The transaction was committed and its changes are durable.';
  if (/^rolled_back|rollback$/i.test(text)) return 'The transaction was rolled back safely.';
  if (/^started_transaction|begin|start_transaction$/i.test(text)) return 'The transaction started. Asa is waiting for COMMIT or ROLLBACK.';
  if (match = /^batch_completed\(([^)]+)\)/i.exec(text)) return `The batch completed with ${match[1]} successful step(s).`;
  if (/^ok$|^done$/i.test(text)) return 'The command completed successfully.';
  return text ? `The command completed. Asa note: ${text}` : 'The command completed and the database is calm.';
}
function asaSuccessDetailJapanese(text) {
  var match;
  if (match = /^created_database\(([^)]+)\)/i.exec(text)) return `データベース ${asaCode(match[1])} を作成し、使用できる状態になりました。`;
  if (match = /^using_database\(([^)]+)\)/i.exec(text)) return `現在、アサはデータベース ${asaCode(match[1])} を使用しています。`;
  if (match = /^dropped_database\(([^)]+)\)/i.exec(text)) return `データベース ${asaCode(match[1])} を削除しました。`;
  if (match = /^created_table\(([^)]+)\)/i.exec(text)) return `テーブル ${asaCode(match[1])} を作成しました。`;
  if (match = /^altered_table\(([^)]+)\)/i.exec(text)) return `テーブル ${asaCode(match[1])} を更新しました。`;
  if (match = /^dropped_table\(([^)]+)\)/i.exec(text)) return `現在のデータベースからテーブル ${asaCode(match[1])} を削除しました。`;
  if (match = /^truncated_table\(([^)]+)\)/i.exec(text)) return `${asaCode(match[1])} の構造を残し、全行を削除しました。`;
  if (match = /^(inserted|updated|deleted)\(([^,]+),\s*([^)]+)\)/i.exec(text)) return `${asaCode(match[2])} で ${match[3]} 行の処理が完了しました。`;
  if (match = /^created_index\(([^,]+),\s*([^)]+)\)/i.exec(text)) return `${asaCode(match[2])} にインデックス ${asaCode(match[1])} を作成しました。`;
  if (match = /^created_view\(([^)]+)\)/i.exec(text)) return `ビュー ${asaCode(match[1])} を作成しました。`;
  if (match = /^dropped_view\(([^)]+)\)/i.exec(text)) return `ビュー ${asaCode(match[1])} を削除しました。`;
  if (/^committed|commit$/i.test(text)) return 'トランザクションをコミットし、変更を永続化しました。';
  if (/^rolled_back|rollback$/i.test(text)) return 'トランザクションを安全にロールバックしました。';
  if (/^started_transaction|begin|start_transaction$/i.test(text)) return 'トランザクションを開始しました。COMMIT または ROLLBACK を待っています。';
  if (match = /^batch_completed\(([^)]+)\)/i.exec(text)) return `バッチが完了し、${match[1]} ステップ成功しました。`;
  if (/^ok$|^done$/i.test(text)) return 'コマンドは正常に完了しました。';
  return text ? `コマンドが完了しました。アサからのメモ: ${text}` : 'コマンドが完了し、データベースは正常です。';
}
function asaDiagnosticCopy(item) {
  var seed = `${item === null || item === void 0 ? void 0 : item.severity}|${item === null || item === void 0 ? void 0 : item.line}|${item === null || item === void 0 ? void 0 : item.message}|${(item === null || item === void 0 ? void 0 : item.correction) || ''}`;
  var opener = (item === null || item === void 0 ? void 0 : item.severity) === 'error' ? asaPick(ASA_ERROR_OPENERS, seed) : asaPick(ASA_CORRECTION_OPENERS, seed);
  var detail = (item === null || item === void 0 ? void 0 : item.severity) === 'error' ? asaErrorDetail(item === null || item === void 0 ? void 0 : item.message) : asaCorrectionDetail(item);
  return `${opener} ${detail}`;
}
function asaResultCopy(result) {
  var message = (result === null || result === void 0 ? void 0 : result.message) || JSON.stringify(result || {});
  if ((result === null || result === void 0 ? void 0 : result.status) === 'ok') {
    return `${asaPick(ASA_SUCCESS_OPENERS, message)} ${asaSuccessDetail(message)}`;
  }
  return `${asaPick(ASA_ERROR_OPENERS, message)} ${asaErrorDetail(message)}`;
}
function asaErrorCopy(message) {
  return `${asaPick(ASA_ERROR_OPENERS, message)} ${asaErrorDetail(message)}`;
}
function analyzeSqlClient(sql) {
  var diagnostics = [];
  var corrected = correctSqlText(sql);
  var _iterator3 = _createForOfIteratorHelper(corrected.changes.slice(0, 4)),
    _step3;
  try {
    for (_iterator3.s(); !(_step3 = _iterator3.n()).done;) {
      var change = _step3.value;
      diagnostics.push({
        severity: 'warning',
        line: change.line,
        message: `Auto correction tersedia: ${change.from} -> ${change.to}.`,
        source: 'client'
      });
    }
  } catch (err) {
    _iterator3.e(err);
  } finally {
    _iterator3.f();
  }
  var supported = /^(create|use|drop|truncate|insert|select|describe|desc|show|update|delete|alter|explain|begin|start|commit|rollback|lock|unlock|grant|revoke|login)\b/i;
  var _iterator4 = _createForOfIteratorHelper(splitStatementsDetailed(sql)),
    _step4;
  try {
    for (_iterator4.s(); !(_step4 = _iterator4.n()).done;) {
      var _exec2;
      var stmt = _step4.value;
      var first = ((_exec2 = /^\s*([A-Za-z_][\w$]*)/.exec(stmt.text)) === null || _exec2 === void 0 ? void 0 : _exec2[1]) || '';
      if (first && !supported.test(first)) {
        diagnostics.push({
          severity: 'error',
          line: stmt.line,
          message: `Statement "${first}" belum dikenali AsaDB.`,
          source: 'client'
        });
      }
      var balance = parenBalance(stmt.text);
      if (balance !== 0) {
        diagnostics.push({
          severity: 'error',
          line: stmt.line,
          message: balance > 0 ? 'Kurung buka belum ditutup.' : 'Kurung tutup berlebih.',
          source: 'client'
        });
      }
      if (!stmt.terminated) {
        diagnostics.push({
          severity: 'warning',
          line: stmt.line,
          message: 'Statement belum ditutup titik koma (;).',
          source: 'client'
        });
      }
      if (/^\s*insert\b/i.test(stmt.text) && !/\bvalues\b/i.test(stmt.text)) {
        diagnostics.push({
          severity: 'error',
          line: stmt.line,
          message: 'INSERT AsaDB saat ini butuh VALUES.',
          source: 'client'
        });
      }
    }
  } catch (err) {
    _iterator4.e(err);
  } finally {
    _iterator4.f();
  }
  return dedupeDiagnostics(diagnostics);
}
function normalizeDiagnostics(items) {
  return (items || []).map(function (item) {
    return {
      severity: item.severity === 'error' ? 'error' : 'warning',
      line: Math.max(1, Number(item.line) || 1),
      message: String(item.message || 'SQL diagnostic.'),
      correction: item.correction || '',
      source: item.source || 'backend'
    };
  });
}
function dedupeDiagnostics(items) {
  var seen = new Set();
  var out = [];
  var _iterator5 = _createForOfIteratorHelper(normalizeDiagnostics(items)),
    _step5;
  try {
    for (_iterator5.s(); !(_step5 = _iterator5.n()).done;) {
      var item = _step5.value;
      var key = `${item.severity}|${item.line}|${item.message}`;
      if (seen.has(key)) continue;
      seen.add(key);
      out.push(item);
    }
  } catch (err) {
    _iterator5.e(err);
  } finally {
    _iterator5.f();
  }
  return out.sort(function (a, b) {
    return a.line - b.line || (a.severity === 'error' ? -1 : 1);
  });
}
function setSqlDiagnostics(items) {
  sqlDiagnosticsState = dedupeDiagnostics(items);
  renderSqlDiagnostics();
  renderSqlLineNumbers(sqlInput.value);
}
function countSqlLines(sql) {
  var count = 1;
  var index = -1;
  while ((index = sql.indexOf('\n', index + 1)) !== -1) count += 1;
  return count;
}
function measureSqlEditor(sql) {
  var textLength = sql.length;
  if (textLength >= LARGE_SQL_EDITOR_CHAR_LIMIT) {
    return {
      lineCount: countSqlLines(sql),
      large: true,
      textLength
    };
  }
  var lineCount = countSqlLines(sql);
  return {
    lineCount,
    large: lineCount >= LARGE_SQL_EDITOR_LINE_LIMIT,
    textLength
  };
}
function renderSqlDiagnostics() {
  var items = sqlDiagnosticsState.filter(function (item) {
    return item.severity === 'error' || item.severity === 'warning';
  });
  sqlEditor.classList.toggle('has-error', items.some(function (item) {
    return item.severity === 'error';
  }));
  if (!items.length) {
    sqlDiagnostics.innerHTML = '';
    return;
  }
  sqlDiagnostics.innerHTML = items.slice(0, 6).map(function (item) {
    return `
    <div class="sql-diagnostic ${item.severity}">
      <strong>${escapeHtml(item.severity === 'error' ? ASA_ERROR_LABEL : ASA_CORRECTION_LABEL)}</strong>
      <span><span class="diagnostic-line">${escapeHtml(t('result.line'))} ${item.line}</span> ${escapeHtml(asaDiagnosticCopy(item))}</span>
    </div>
  `;
  }).join('');
}
function renderSqlLineNumbers(sql) {
  var severityByLine = {};
  var _iterator6 = _createForOfIteratorHelper(sqlDiagnosticsState),
    _step6;
  try {
    for (_iterator6.s(); !(_step6 = _iterator6.n()).done;) {
      var item = _step6.value;
      if (item.severity === 'error') severityByLine[item.line] = 'error';else if (!severityByLine[item.line]) severityByLine[item.line] = 'warning';
    }
  } catch (err) {
    _iterator6.e(err);
  } finally {
    _iterator6.f();
  }
  var lines = sqlEditorMetrics.textLength === sql.length ? sqlEditorMetrics.lineCount : countSqlLines(sql);
  var firstLine = 1;
  var lastLine = lines;
  if (sqlEditorMetrics.large) {
    var visibleLines = Math.ceil((sqlInput.clientHeight || 420) / SQL_EDITOR_LINE_HEIGHT) + 16;
    firstLine = Math.max(1, Math.floor(sqlInput.scrollTop / SQL_EDITOR_LINE_HEIGHT) - 7);
    lastLine = Math.min(lines, firstLine + visibleLines);
    sqlLineNumbersContent.style.paddingTop = `${12 + (firstLine - 1) * SQL_EDITOR_LINE_HEIGHT}px`;
    sqlLineNumbersContent.style.paddingBottom = `${12 + (lines - lastLine) * SQL_EDITOR_LINE_HEIGHT}px`;
  } else {
    sqlLineNumbersContent.style.paddingTop = '';
    sqlLineNumbersContent.style.paddingBottom = '';
  }
  var numbers = [];
  for (var line = firstLine; line <= lastLine; line += 1) {
    var severity = severityByLine[line] || '';
    numbers.push(`<span class="${severity}">${line}</span>`);
  }
  sqlLineNumbersContent.innerHTML = numbers.join('');
}
function syncSqlScroll() {
  sqlHighlight.scrollTop = sqlInput.scrollTop;
  sqlHighlight.scrollLeft = sqlInput.scrollLeft;
  if (sqlEditorMetrics.large) {
    cancelAnimationFrame(sqlLineRenderFrame);
    sqlLineRenderFrame = requestAnimationFrame(function () {
      return renderSqlLineNumbers(sqlInput.value);
    });
  }
  sqlLineNumbers.scrollTop = sqlInput.scrollTop;
  positionSqlCompletions();
}
function sqlCaretScrollTarget() {
  var _sqlInput$selectionSt2;
  var caret = (_sqlInput$selectionSt2 = sqlInput.selectionStart) !== null && _sqlInput$selectionSt2 !== void 0 ? _sqlInput$selectionSt2 : sqlInput.value.length;
  var line = lineNumberAtIndex(sqlInput.value, caret);
  var viewport = sqlInput.clientHeight || 420;
  var target = (line - 1) * SQL_EDITOR_LINE_HEIGHT - viewport * 0.45;
  var max = Math.max(0, sqlInput.scrollHeight - viewport);
  return Math.max(0, Math.min(max, target));
}
function restoreSqlViewport(top, left) {
  var frames = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : 2;
  cancelAnimationFrame(sqlScrollRestoreFrame);
  var _apply = function apply(remaining) {
    sqlInput.scrollTop = Math.max(0, Number(top) || 0);
    sqlInput.scrollLeft = Math.max(0, Number(left) || 0);
    syncSqlScroll();
    if (remaining > 0) sqlScrollRestoreFrame = requestAnimationFrame(function () {
      return _apply(remaining - 1);
    });
  };
  _apply(frames);
}
function updateSqlEditor() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var requestedTop = Number.isFinite(options.scrollTop) ? options.scrollTop : sqlInput.scrollTop;
  var requestedLeft = Number.isFinite(options.scrollLeft) ? options.scrollLeft : sqlInput.scrollLeft;
  var sql = sqlInput.value;
  sqlEditorMetrics = measureSqlEditor(sql);
  sqlEditor.classList.toggle('large-script', sqlEditorMetrics.large);
  if (sqlEditorMetrics.large) sqlHighlight.textContent = '';else sqlHighlight.innerHTML = highlightSql(sql);
  renderSqlLineNumbers(sql);
  sqlInput.scrollTop = requestedTop;
  sqlInput.scrollLeft = requestedLeft;
  syncSqlScroll();
  if (options.persistScroll) restoreSqlViewport(requestedTop, requestedLeft);
  return sqlEditorMetrics;
}
function setSqlText(text) {
  var analyze = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : true;
  sqlInput.value = text;
  updateSqlEditor();
  closeSqlCompletions();
  if (analyze) scheduleSqlAnalysis();
}
function scheduleSqlAnalysis() {
  clearTimeout(sqlAnalyzeTimer);
  /* Reject an old backend response before the debounce delay begins. */
  sqlAnalyzeRequest += 1;
  if (sqlEditorMetrics.large) {
    setSqlDiagnostics([]);
    return;
  }
  sqlAnalyzeTimer = setTimeout(function () {
    return refreshSqlDiagnostics(true);
  }, 420);
}
function refreshSqlDiagnostics() {
  return _refreshSqlDiagnostics.apply(this, arguments);
}
function _refreshSqlDiagnostics() {
  _refreshSqlDiagnostics = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee4() {
    var useBackend,
      sql,
      requestId,
      diagnostics,
      body,
      res,
      data,
      _args4 = arguments,
      _t8;
    return _regenerator().w(function (_context4) {
      while (1) switch (_context4.p = _context4.n) {
        case 0:
          useBackend = _args4.length > 0 && _args4[0] !== undefined ? _args4[0] : true;
          sql = sqlInput.value;
          if (!(sqlEditorMetrics.large || sql.length >= LARGE_SQL_EDITOR_CHAR_LIMIT)) {
            _context4.n = 1;
            break;
          }
          setSqlDiagnostics([]);
          return _context4.a(2, []);
        case 1:
          requestId = ++sqlAnalyzeRequest;
          diagnostics = analyzeSqlClient(sql);
          if (!(backendOnline && useBackend)) {
            _context4.n = 8;
            break;
          }
          _context4.p = 2;
          body = new URLSearchParams({
            sql
          });
          _context4.n = 3;
          return fetch('/api/analyze', {
            method: 'POST',
            headers: apiHeaders({
              'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'
            }),
            body
          });
        case 3:
          res = _context4.v;
          if (!res.ok) {
            _context4.n = 6;
            break;
          }
          _context4.n = 4;
          return res.json();
        case 4:
          data = _context4.v;
          if (!(requestId !== sqlAnalyzeRequest)) {
            _context4.n = 5;
            break;
          }
          return _context4.a(2, sqlDiagnosticsState);
        case 5:
          diagnostics = dedupeDiagnostics([].concat(_toConsumableArray(diagnostics), _toConsumableArray(data.diagnostics || [])));
        case 6:
          _context4.n = 8;
          break;
        case 7:
          _context4.p = 7;
          _t8 = _context4.v;
          log(t('log.analyzerFallback', {
            error: _t8.message
          }));
        case 8:
          if (requestId === sqlAnalyzeRequest) setSqlDiagnostics(diagnostics);
          return _context4.a(2, diagnostics);
      }
    }, _callee4, null, [[2, 7]]);
  }));
  return _refreshSqlDiagnostics.apply(this, arguments);
}
function addRuntimeDiagnostics(results) {
  var runtime = (results || []).filter(function (r) {
    return r.status === 'error' && r.line;
  }).map(function (r) {
    return {
      severity: 'error',
      line: r.line,
      message: r.message || 'Runtime error.',
      source: 'runtime'
    };
  });
  if (runtime.length) setSqlDiagnostics([].concat(_toConsumableArray(sqlDiagnosticsState.filter(function (x) {
    return x.source !== 'runtime';
  })), _toConsumableArray(runtime)));
}
function executeBackendSql(_x) {
  return _executeBackendSql.apply(this, arguments);
}
function _executeBackendSql() {
  _executeBackendSql = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee5(sql) {
    var options,
      body,
      res,
      data,
      _args5 = arguments;
    return _regenerator().w(function (_context5) {
      while (1) switch (_context5.n) {
        case 0:
          options = _args5.length > 1 && _args5[1] !== undefined ? _args5[1] : {};
          body = new URLSearchParams({
            sql
          });
          _context5.n = 1;
          return fetch('/api/query', {
            method: 'POST',
            headers: apiHeaders({
              'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'
            }),
            body
          });
        case 1:
          res = _context5.v;
          _context5.n = 2;
          return res.json();
        case 2:
          data = _context5.v;
          if (res.ok) {
            _context5.n = 3;
            break;
          }
          throw new Error(data.message || `HTTP ${res.status}`);
        case 3:
          if (!(options.sync !== false)) {
            _context5.n = 4;
            break;
          }
          _context5.n = 4;
          return syncBackendStateSmart();
        case 4:
          return _context5.a(2, data);
      }
    }, _callee5);
  }));
  return _executeBackendSql.apply(this, arguments);
}
function executeBackendSqlPage(_x2) {
  return _executeBackendSqlPage.apply(this, arguments);
}
function _executeBackendSqlPage() {
  _executeBackendSqlPage = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee6(sql) {
    var offset,
      body,
      res,
      data,
      _args6 = arguments;
    return _regenerator().w(function (_context6) {
      while (1) switch (_context6.n) {
        case 0:
          offset = _args6.length > 1 && _args6[1] !== undefined ? _args6[1] : 0;
          body = new URLSearchParams({
            sql,
            offset: String(Math.max(0, Number(offset) || 0))
          });
          _context6.n = 1;
          return fetch('/api/query', {
            method: 'POST',
            headers: apiHeaders({
              'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'
            }),
            body
          });
        case 1:
          res = _context6.v;
          _context6.n = 2;
          return res.json();
        case 2:
          data = _context6.v;
          if (res.ok) {
            _context6.n = 3;
            break;
          }
          throw new Error(data.message || `HTTP ${res.status}`);
        case 3:
          return _context6.a(2, data);
      }
    }, _callee6);
  }));
  return _executeBackendSqlPage.apply(this, arguments);
}
function createSqlExecutionPlan(sql) {
  var _statements$length;
  var text = String(sql || '');
  var containsWrite = /\b(?:create|drop|alter|truncate|insert|update|delete|replace|grant|revoke)\b/i.test(text);
  var statements = containsWrite ? null : splitStatementsDetailed(text);
  return {
    mode: containsWrite || text.length > 250000 ? 'reservoir' : 'direct',
    statements,
    statementCount: (_statements$length = statements === null || statements === void 0 ? void 0 : statements.length) !== null && _statements$length !== void 0 ? _statements$length : null
  };
}
function executeBackendSqlStreamed(_x3) {
  return _executeBackendSqlStreamed.apply(this, arguments);
}
function _executeBackendSqlStreamed() {
  _executeBackendSqlStreamed = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee7(sql) {
    var options,
      body,
      _args7 = arguments;
    return _regenerator().w(function (_context7) {
      while (1) switch (_context7.n) {
        case 0:
          options = _args7.length > 1 && _args7[1] !== undefined ? _args7[1] : {};
          body = new Blob([sql], {
            type: 'application/sql;charset=UTF-8'
          });
          return _context7.a(2, submitReservoirPayload(body, _objectSpread(_objectSpread({}, options), {}, {
            label: options.label || 'SQL command',
            kind: options.kind || 'sql'
          })));
      }
    }, _callee7);
  }));
  return _executeBackendSqlStreamed.apply(this, arguments);
}
function makeReservoirIdempotencyKey() {
  var prefix = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : 'job';
  var browserCrypto = window.crypto || window.msCrypto;
  var suffix = browserCrypto && typeof browserCrypto.randomUUID === 'function' ? browserCrypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  return `${prefix}-${suffix}`;
}
function reservoirStatusText(status) {
  switch (String(status || '').toLowerCase()) {
    case 'receiving':
      return t('state.receiving');
    case 'queued':
      return t('state.queued');
    case 'processing':
      return t('state.processing');
    case 'cancelling':
      return t('state.cancelling');
    case 'completed':
      return t('state.completed');
    case 'delivered':
      return t('state.delivered');
    case 'failed':
      return t('state.failed');
    case 'cancelled':
      return t('state.cancelled');
    case 'interrupted':
      return t('state.interrupted');
    case 'reconnecting':
      return t('state.reconnecting');
    default:
      return String(status || t('state.waiting'));
  }
}
function reservoirJobIsTerminal(job) {
  if (!job) return false;
  return job.done === true || ['completed', 'delivered', 'failed', 'cancelled', 'interrupted'].includes(String(job.status || '').toLowerCase());
}
function reservoirJobPercent(job) {
  if (!job) return 0;
  if (job.result_available || ['completed', 'delivered'].includes(String(job.status || '').toLowerCase())) return 100;
  var reported = Number(job.progress_percent);
  if (Number.isFinite(reported)) return Math.max(0, Math.min(100, Math.round(reported)));
  var completed = Number(job.processed_bytes) || 0;
  var total = Number(job.size_bytes) || 0;
  return total ? Math.max(0, Math.min(100, Math.round(completed / total * 100))) : 0;
}
function loadActiveReservoirDescriptor() {
  try {
    var descriptor = JSON.parse(localStorage.getItem(ACTIVE_RESERVOIR_STORAGE_KEY) || 'null');
    if (!descriptor || typeof descriptor.id !== 'string' || !descriptor.id) return null;
    return descriptor;
  } catch (_) {
    return null;
  }
}
function saveActiveReservoirDescriptor(descriptor) {
  try {
    localStorage.setItem(ACTIVE_RESERVOIR_STORAGE_KEY, JSON.stringify(descriptor));
  } catch (_) {
    // Reload recovery can still fall back to the backend active-job list.
  }
}
function clearActiveReservoirDescriptor() {
  var jobId = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : '';
  try {
    var stored = loadActiveReservoirDescriptor();
    if (!jobId || !stored || stored.id === jobId) localStorage.removeItem(ACTIVE_RESERVOIR_STORAGE_KEY);
  } catch (_) {}
}
function normalizeReservoirDescriptor(jobId) {
  var _ref2, _ref3, _options$sizeBytes;
  var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
  var job = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : null;
  var supplied = options.descriptor || {};
  var stored = loadActiveReservoirDescriptor();
  var previous = stored && stored.id === jobId ? stored : {};
  return {
    id: jobId,
    label: options.label || supplied.label || (job === null || job === void 0 ? void 0 : job.label) || previous.label || 'Reservoir',
    kind: options.kind || supplied.kind || previous.kind || 'reservoir',
    sizeBytes: Number((_ref2 = (_ref3 = (_options$sizeBytes = options.sizeBytes) !== null && _options$sizeBytes !== void 0 ? _options$sizeBytes : supplied.sizeBytes) !== null && _ref3 !== void 0 ? _ref3 : job === null || job === void 0 ? void 0 : job.size_bytes) !== null && _ref2 !== void 0 ? _ref2 : previous.sizeBytes) || 0,
    startedAt: supplied.startedAt || previous.startedAt || new Date().toISOString()
  };
}
function updateImportControls() {
  var busy = Boolean(importOperationPromise || activeReservoirJobId);
  importExecuteBtn.disabled = busy;
  importRunServerBtn.disabled = busy;
  importFileInput.disabled = busy;
}
function renderReservoirJob() {
  var job = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : lastReservoirSnapshot;
  if (!importProgressPanel) return;
  if (!job && !activeReservoirJobId) {
    importProgressPanel.hidden = true;
    importCancelBtn.disabled = true;
    importCancelBtn.textContent = t('import.cancel');
    updateImportControls();
    return;
  }
  if (job) lastReservoirSnapshot = job;
  var snapshot = job || lastReservoirSnapshot || {};
  var descriptor = activeReservoirDescriptor || loadActiveReservoirDescriptor() || {};
  var percent = reservoirJobPercent(snapshot);
  var status = reservoirStatusText(snapshot.status);
  var message = String(snapshot.message || '').trim() || '-';
  var statements = Number(snapshot.statements) || 0;
  var terminal = reservoirJobIsTerminal(snapshot);
  var cancelPending = Boolean(activeReservoirJobId) && !terminal && Boolean(reservoirCancelPromise || snapshot.cancel_requested || snapshot.status === 'cancelling');
  var canCancel = Boolean(activeReservoirJobId) && !terminal && !cancelPending;
  importProgressPanel.hidden = false;
  importProgressLabel.textContent = snapshot.label || descriptor.label || 'Reservoir';
  importProgressPercent.textContent = `${percent}%`;
  importProgressBar.value = percent;
  importProgressBar.textContent = `${percent}%`;
  importProgressStatus.textContent = t('import.jobStatus', {
    status,
    count: formatNumber(statements),
    message
  });
  importCancelBtn.disabled = !canCancel;
  importCancelBtn.textContent = t(cancelPending ? 'import.cancelling' : 'import.cancel');
  updateImportControls();
}
function activateReservoirJob(jobId) {
  var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
  var job = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : null;
  if (!jobId) return null;
  activeReservoirJobId = jobId;
  activeReservoirDescriptor = normalizeReservoirDescriptor(jobId, options, job);
  saveActiveReservoirDescriptor(activeReservoirDescriptor);
  var snapshot = job || {
    id: jobId,
    label: activeReservoirDescriptor.label,
    status: options.status || 'queued',
    size_bytes: activeReservoirDescriptor.sizeBytes,
    processed_bytes: 0,
    statements: 0,
    result_available: false,
    done: false,
    message: options.message || ''
  };
  renderReservoirJob(snapshot);
  requestMetadataRefreshDuringJob();
  return activeReservoirDescriptor;
}
function finishReservoirJob(jobId, job) {
  if (job) renderReservoirJob(job);
  if (activeReservoirJobId === jobId) {
    activeReservoirJobId = '';
    activeReservoirDescriptor = null;
  }
  clearActiveReservoirDescriptor(jobId);
  updateImportControls();
  scheduleMetadataPoll(0);
}
function reservoirHttpError(response, payload) {
  var error = new Error((payload === null || payload === void 0 ? void 0 : payload.message) || `HTTP ${response.status}`);
  error.httpStatus = response.status;
  return error;
}
function submitReservoirPayload(_x4) {
  return _submitReservoirPayload.apply(this, arguments);
}
function _submitReservoirPayload() {
  _submitReservoirPayload = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee8(payload) {
    var _admission$job;
    var options,
      idempotencyKey,
      res,
      admission,
      _args8 = arguments;
    return _regenerator().w(function (_context8) {
      while (1) switch (_context8.n) {
        case 0:
          options = _args8.length > 1 && _args8[1] !== undefined ? _args8[1] : {};
          idempotencyKey = options.idempotencyKey || makeReservoirIdempotencyKey('reservoir');
          _context8.n = 1;
          return fetch('/api/reservoir/jobs', {
            method: 'POST',
            headers: apiHeaders({
              'Content-Type': options.contentType || 'application/sql;charset=UTF-8',
              'X-AsaDB-Idempotency-Key': idempotencyKey,
              'X-AsaDB-Job-Label': options.label || 'SQL command',
              'X-AsaDB-Stop-On-Error': options.stopOnError === false ? 'false' : 'true'
            }),
            body: payload
          });
        case 1:
          res = _context8.v;
          _context8.n = 2;
          return res.json();
        case 2:
          admission = _context8.v;
          if (res.ok) {
            _context8.n = 3;
            break;
          }
          throw new Error(admission.message || `HTTP ${res.status}`);
        case 3:
          activateReservoirJob(admission.job_id, _objectSpread(_objectSpread({}, options), {}, {
            idempotencyKey,
            sizeBytes: ((_admission$job = admission.job) === null || _admission$job === void 0 ? void 0 : _admission$job.size_bytes) || (payload === null || payload === void 0 ? void 0 : payload.size) || 0
          }), admission.job || null);
          return _context8.a(2, waitForReservoirJob(admission.job_id, options));
      }
    }, _callee8);
  }));
  return _submitReservoirPayload.apply(this, arguments);
}
function startReservoirFile(_x5) {
  return _startReservoirFile.apply(this, arguments);
}
function _startReservoirFile() {
  _startReservoirFile = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee9(path) {
    var _admission$job2;
    var options,
      body,
      res,
      admission,
      _args9 = arguments;
    return _regenerator().w(function (_context9) {
      while (1) switch (_context9.n) {
        case 0:
          options = _args9.length > 1 && _args9[1] !== undefined ? _args9[1] : {};
          body = new URLSearchParams({
            path,
            idempotency_key: options.idempotencyKey || makeReservoirIdempotencyKey('file'),
            stop_on_error: options.stopOnError === false ? 'false' : 'true'
          });
          _context9.n = 1;
          return fetch('/api/reservoir/file', {
            method: 'POST',
            headers: apiHeaders({
              'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'
            }),
            body
          });
        case 1:
          res = _context9.v;
          _context9.n = 2;
          return res.json();
        case 2:
          admission = _context9.v;
          if (res.ok) {
            _context9.n = 3;
            break;
          }
          throw new Error(admission.message || `HTTP ${res.status}`);
        case 3:
          activateReservoirJob(admission.job_id, _objectSpread(_objectSpread({}, options), {}, {
            kind: options.kind || 'import-file',
            label: options.label || path,
            sizeBytes: admission.size_bytes || ((_admission$job2 = admission.job) === null || _admission$job2 === void 0 ? void 0 : _admission$job2.size_bytes) || 0
          }), admission.job || null);
          return _context9.a(2, waitForReservoirJob(admission.job_id, options));
      }
    }, _callee9);
  }));
  return _startReservoirFile.apply(this, arguments);
}
function waitForReservoirJob(_x6) {
  return _waitForReservoirJob.apply(this, arguments);
}
function _waitForReservoirJob() {
  _waitForReservoirJob = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee0(jobId) {
    var options,
      retryCount,
      _options$onProgress,
      res,
      job,
      data,
      error,
      _activeReservoirDescr,
      _lastReservoirSnapsho,
      _args0 = arguments,
      _t9;
    return _regenerator().w(function (_context0) {
      while (1) switch (_context0.p = _context0.n) {
        case 0:
          options = _args0.length > 1 && _args0[1] !== undefined ? _args0[1] : {};
          activateReservoirJob(jobId, options);
          retryCount = 0;
        case 1:
          if (!true) {
            _context0.n = 14;
            break;
          }
          _context0.p = 2;
          _context0.n = 3;
          return fetch(`/api/reservoir/job?id=${encodeURIComponent(jobId)}`, {
            cache: 'no-store',
            headers: apiHeaders()
          });
        case 3:
          res = _context0.v;
          _context0.n = 4;
          return res.json();
        case 4:
          job = _context0.v;
          if (res.ok) {
            _context0.n = 5;
            break;
          }
          throw reservoirHttpError(res, job);
        case 5:
          retryCount = 0;
          renderReservoirJob(job);
          (_options$onProgress = options.onProgress) === null || _options$onProgress === void 0 || _options$onProgress.call(options, {
            completed: Number(job.processed_bytes) || 0,
            total: Number(job.size_bytes) || 0,
            statements: Number(job.statements) || 0,
            label: job.message || job.status || 'Reservoir',
            status: job.status
          });
          requestMetadataRefreshDuringJob();
          if (!job.result_available) {
            _context0.n = 7;
            break;
          }
          _context0.n = 6;
          return fetchReservoirResult(jobId, job);
        case 6:
          data = _context0.v;
          finishReservoirJob(jobId, _objectSpread(_objectSpread({}, job), {}, {
            done: true,
            progress_percent: 100
          }));
          return _context0.a(2, data);
        case 7:
          if (!['failed', 'cancelled', 'interrupted'].includes(job.status)) {
            _context0.n = 8;
            break;
          }
          error = new Error(job.message || `Reservoir job ${job.status}`);
          error.reservoirStatus = job.status;
          finishReservoirJob(jobId, job);
          throw error;
        case 8:
          _context0.n = 9;
          return new Promise(function (resolve) {
            return setTimeout(resolve, RESERVOIR_POLL_INTERVAL_MS);
          });
        case 9:
          _context0.n = 13;
          break;
        case 10:
          _context0.p = 10;
          _t9 = _context0.v;
          if (!_t9.reservoirStatus) {
            _context0.n = 11;
            break;
          }
          throw _t9;
        case 11:
          if (!(_t9.httpStatus === 404 || _t9.httpStatus === 410)) {
            _context0.n = 12;
            break;
          }
          finishReservoirJob(jobId, _objectSpread(_objectSpread({}, lastReservoirSnapshot || {}), {}, {
            id: jobId,
            status: 'interrupted',
            done: true,
            message: _t9.message
          }));
          throw _t9;
        case 12:
          retryCount += 1;
          renderReservoirJob(_objectSpread(_objectSpread({}, lastReservoirSnapshot || {}), {}, {
            id: jobId,
            label: ((_activeReservoirDescr = activeReservoirDescriptor) === null || _activeReservoirDescr === void 0 ? void 0 : _activeReservoirDescr.label) || ((_lastReservoirSnapsho = lastReservoirSnapshot) === null || _lastReservoirSnapsho === void 0 ? void 0 : _lastReservoirSnapsho.label) || 'Reservoir',
            status: 'reconnecting',
            done: false,
            message: _t9.message
          }));
          _context0.n = 13;
          return new Promise(function (resolve) {
            return setTimeout(resolve, Math.min(5000, 300 * Math.pow(2, Math.min(retryCount, 4))));
          });
        case 13:
          _context0.n = 1;
          break;
        case 14:
          return _context0.a(2);
      }
    }, _callee0, null, [[2, 10]]);
  }));
  return _waitForReservoirJob.apply(this, arguments);
}
function fetchReservoirResult(_x7, _x8) {
  return _fetchReservoirResult.apply(this, arguments);
}
function _fetchReservoirResult() {
  _fetchReservoirResult = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee1(jobId, job) {
    var res, data, allResults;
    return _regenerator().w(function (_context1) {
      while (1) switch (_context1.n) {
        case 0:
          _context1.n = 1;
          return fetch(`/api/reservoir/result?id=${encodeURIComponent(jobId)}`, {
            cache: 'no-store',
            headers: apiHeaders()
          });
        case 1:
          res = _context1.v;
          _context1.n = 2;
          return res.json();
        case 2:
          data = _context1.v;
          if (res.ok) {
            _context1.n = 3;
            break;
          }
          throw new Error(data.message || `HTTP ${res.status}`);
        case 3:
          allResults = data.results || [data];
          return _context1.a(2, _objectSpread(_objectSpread({}, data), {}, {
            allResults,
            statementCount: Number(job.statements) || allResults.length
          }));
      }
    }, _callee1);
  }));
  return _fetchReservoirResult.apply(this, arguments);
}
function cancelActiveReservoirJob() {
  return _cancelActiveReservoirJob.apply(this, arguments);
}
function _cancelActiveReservoirJob() {
  _cancelActiveReservoirJob = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee11() {
    var jobId, _t0;
    return _regenerator().w(function (_context11) {
      while (1) switch (_context11.p = _context11.n) {
        case 0:
          if (!reservoirCancelPromise) {
            _context11.n = 1;
            break;
          }
          return _context11.a(2, reservoirCancelPromise);
        case 1:
          jobId = activeReservoirJobId;
          if (jobId) {
            _context11.n = 2;
            break;
          }
          return _context11.a(2, null);
        case 2:
          reservoirCancelPromise = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee10() {
            var res, snapshot;
            return _regenerator().w(function (_context10) {
              while (1) switch (_context10.n) {
                case 0:
                  _context10.n = 1;
                  return fetch(`/api/reservoir/cancel?id=${encodeURIComponent(jobId)}`, {
                    method: 'POST',
                    headers: apiHeaders()
                  });
                case 1:
                  res = _context10.v;
                  _context10.n = 2;
                  return res.json();
                case 2:
                  snapshot = _context10.v;
                  if (res.ok) {
                    _context10.n = 3;
                    break;
                  }
                  throw reservoirHttpError(res, snapshot);
                case 3:
                  renderReservoirJob(snapshot);
                  importSummary.textContent = t('import.cancelRequested');
                  requestMetadataRefreshDuringJob();
                  return _context10.a(2, snapshot);
              }
            }, _callee10);
          }))();
          renderReservoirJob(lastReservoirSnapshot);
          _context11.p = 3;
          _context11.n = 4;
          return reservoirCancelPromise;
        case 4:
          return _context11.a(2, _context11.v);
        case 5:
          _context11.p = 5;
          _t0 = _context11.v;
          log(t('log.reservoirCancelFailed', {
            error: _t0.message
          }));
          importSummary.textContent = `${ASA_ERROR_LABEL}: ${asaErrorCopy(_t0.message)}`;
          return _context11.a(2, null);
        case 6:
          _context11.p = 6;
          reservoirCancelPromise = null;
          renderReservoirJob(lastReservoirSnapshot);
          return _context11.f(6);
        case 7:
          return _context11.a(2);
      }
    }, _callee11, null, [[3, 5, 6, 7]]);
  }));
  return _cancelActiveReservoirJob.apply(this, arguments);
}
function fetchReservoirJobSnapshot(_x9) {
  return _fetchReservoirJobSnapshot.apply(this, arguments);
}
function _fetchReservoirJobSnapshot() {
  _fetchReservoirJobSnapshot = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee12(jobId) {
    var res, job;
    return _regenerator().w(function (_context12) {
      while (1) switch (_context12.n) {
        case 0:
          _context12.n = 1;
          return fetch(`/api/reservoir/job?id=${encodeURIComponent(jobId)}`, {
            cache: 'no-store',
            headers: apiHeaders()
          });
        case 1:
          res = _context12.v;
          _context12.n = 2;
          return res.json();
        case 2:
          job = _context12.v;
          if (res.ok) {
            _context12.n = 3;
            break;
          }
          throw reservoirHttpError(res, job);
        case 3:
          return _context12.a(2, job);
      }
    }, _callee12);
  }));
  return _fetchReservoirJobSnapshot.apply(this, arguments);
}
function discoverActiveReservoirJob() {
  return _discoverActiveReservoirJob.apply(this, arguments);
}
function _discoverActiveReservoirJob() {
  _discoverActiveReservoirJob = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee13() {
    var stored, job, res, data, jobs, _job, _t1, _t10;
    return _regenerator().w(function (_context13) {
      while (1) switch (_context13.p = _context13.n) {
        case 0:
          stored = loadActiveReservoirDescriptor();
          if (!stored) {
            _context13.n = 6;
            break;
          }
          _context13.p = 1;
          _context13.n = 2;
          return fetchReservoirJobSnapshot(stored.id);
        case 2:
          job = _context13.v;
          if (!(!reservoirJobIsTerminal(job) || job.result_available)) {
            _context13.n = 3;
            break;
          }
          return _context13.a(2, {
            job,
            descriptor: stored
          });
        case 3:
          lastReservoirSnapshot = job;
          renderReservoirJob(job);
          clearActiveReservoirDescriptor(stored.id);
          _context13.n = 6;
          break;
        case 4:
          _context13.p = 4;
          _t1 = _context13.v;
          if (!(_t1.httpStatus !== 404 && _t1.httpStatus !== 410)) {
            _context13.n = 5;
            break;
          }
          return _context13.a(2, {
            job: {
              id: stored.id,
              label: stored.label,
              status: 'reconnecting',
              size_bytes: stored.sizeBytes || 0,
              done: false,
              message: _t1.message
            },
            descriptor: stored
          });
        case 5:
          clearActiveReservoirDescriptor(stored.id);
        case 6:
          _context13.p = 6;
          _context13.n = 7;
          return fetch('/api/reservoir/jobs', {
            cache: 'no-store',
            headers: apiHeaders()
          });
        case 7:
          res = _context13.v;
          if (res.ok) {
            _context13.n = 8;
            break;
          }
          return _context13.a(2, null);
        case 8:
          _context13.n = 9;
          return res.json();
        case 9:
          data = _context13.v;
          jobs = Array.isArray(data.jobs) ? data.jobs : [];
          _job = jobs.find(function (candidate) {
            return !reservoirJobIsTerminal(candidate);
          });
          if (_job) {
            _context13.n = 10;
            break;
          }
          return _context13.a(2, null);
        case 10:
          return _context13.a(2, {
            job: _job,
            descriptor: normalizeReservoirDescriptor(_job.id, {}, _job)
          });
        case 11:
          _context13.p = 11;
          _t10 = _context13.v;
          return _context13.a(2, null);
      }
    }, _callee13, null, [[6, 11], [1, 4]]);
  }));
  return _discoverActiveReservoirJob.apply(this, arguments);
}
function finalizeResumedReservoirJob(_x0, _x1) {
  return _finalizeResumedReservoirJob.apply(this, arguments);
}
function _finalizeResumedReservoirJob() {
  _finalizeResumedReservoirJob = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee14(data, descriptor) {
    var results, statementCount, tableResult, summary;
    return _regenerator().w(function (_context14) {
      while (1) switch (_context14.n) {
        case 0:
          results = data.results || [data];
          renderResults(results);
          addRuntimeDiagnostics(results);
          statementCount = Number(data.statementCount) || 0;
          setLastRunKey('progress.backendSteps', {
            count: statementCount
          });
          _context14.n = 1;
          return Promise.all([syncBackendStateSmart().catch(function () {
            return syncCatalogFromBackend().catch(function () {
              return false;
            });
          }), refreshDatabaseMetadata().catch(function () {
            return null;
          })]);
        case 1:
          renderTableBrowser();
          tableResult = results.find(function (result) {
            return result.status === 'table';
          });
          noteArchiveImportComplete(descriptor.label, descriptor.sizeBytes || 0, (tableResult === null || tableResult === void 0 ? void 0 : tableResult.columns) || ['status'], (tableResult === null || tableResult === void 0 ? void 0 : tableResult.rows) || [], statementCount);
          summary = t('import.resumedComplete', {
            name: descriptor.label,
            count: formatNumber(statementCount)
          });
          importSummary.textContent = summary;
          log(summary);
        case 2:
          return _context14.a(2);
      }
    }, _callee14);
  }));
  return _finalizeResumedReservoirJob.apply(this, arguments);
}
function resumeActiveReservoirJob() {
  if (reservoirResumePromise) return reservoirResumePromise;
  if (activeReservoirJobId) return Promise.resolve(null);
  reservoirResumePromise = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee() {
    var recovered, job, descriptor, data, _t;
    return _regenerator().w(function (_context) {
      while (1) switch (_context.p = _context.n) {
        case 0:
          _context.n = 1;
          return discoverActiveReservoirJob();
        case 1:
          recovered = _context.v;
          if (recovered) {
            _context.n = 2;
            break;
          }
          return _context.a(2, null);
        case 2:
          job = recovered.job, descriptor = recovered.descriptor;
          activateReservoirJob(job.id, {
            descriptor
          }, job);
          importSummary.textContent = t('import.resumed', {
            name: descriptor.label
          });
          log(t('log.reservoirResumed', {
            name: descriptor.label
          }));
          _context.p = 3;
          _context.n = 4;
          return waitForReservoirJob(job.id, {
            descriptor
          });
        case 4:
          data = _context.v;
          _context.n = 5;
          return finalizeResumedReservoirJob(data, descriptor);
        case 5:
          return _context.a(2, data);
        case 6:
          _context.p = 6;
          _t = _context.v;
          if (_t.reservoirStatus === 'cancelled') {
            importSummary.textContent = t('import.cancelled');
          } else {
            importSummary.textContent = `${ASA_ERROR_LABEL}: ${asaErrorCopy(_t.message)}`;
            log(t('log.reservoirMonitorFailed', {
              error: _t.message
            }));
          }
          return _context.a(2, null);
      }
    }, _callee, null, [[3, 6]]);
  }))().finally(function () {
    reservoirResumePromise = null;
  });
  return reservoirResumePromise;
}
function saveBackendDatabase() {
  return _saveBackendDatabase.apply(this, arguments);
}
function _saveBackendDatabase() {
  _saveBackendDatabase = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee15() {
    var db,
      saveError,
      res,
      _data$results$find,
      body,
      _res,
      data,
      _args15 = arguments,
      _t11,
      _t12;
    return _regenerator().w(function (_context15) {
      while (1) switch (_context15.p = _context15.n) {
        case 0:
          db = _args15.length > 0 && _args15[0] !== undefined ? _args15[0] : currentDbName();
          saveError = null;
          _context15.p = 1;
          _context15.n = 2;
          return fetch('/api/save', {
            method: 'POST',
            headers: apiHeaders()
          });
        case 2:
          res = _context15.v;
          if (!res.ok) {
            _context15.n = 3;
            break;
          }
          return _context15.a(2, res.json());
        case 3:
          saveError = new Error(`HTTP ${res.status}`);
          _context15.n = 5;
          break;
        case 4:
          _context15.p = 4;
          _t11 = _context15.v;
          saveError = _t11;
        case 5:
          _context15.p = 5;
          body = new URLSearchParams({
            sql: 'SHOW DATABASES;'
          });
          _context15.n = 6;
          return fetch('/api/query', {
            method: 'POST',
            headers: apiHeaders({
              'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'
            }),
            body
          });
        case 6:
          _res = _context15.v;
          _context15.n = 7;
          return _res.json();
        case 7:
          data = _context15.v;
          if (_res.ok) {
            _context15.n = 8;
            break;
          }
          throw new Error(data.message || `HTTP ${_res.status}`);
        case 8:
          if (!hasResultError(data)) {
            _context15.n = 9;
            break;
          }
          throw new Error(((_data$results$find = data.results.find(function (result) {
            return result.status === 'error';
          })) === null || _data$results$find === void 0 ? void 0 : _data$results$find.message) || 'save failed');
        case 9:
          return _context15.a(2, {
            results: [{
              status: 'ok',
              message: `saved_database(${db || 'none'})`
            }]
          });
        case 10:
          _context15.p = 10;
          _t12 = _context15.v;
          throw saveError || _t12;
        case 11:
          return _context15.a(2);
      }
    }, _callee15, null, [[5, 10], [1, 4]]);
  }));
  return _saveBackendDatabase.apply(this, arguments);
}
function hasResultError(data) {
  return ((data === null || data === void 0 ? void 0 : data.results) || [data]).some(function (result) {
    return (result === null || result === void 0 ? void 0 : result.status) === 'error';
  });
}
function backendListContains(_x10, _x11) {
  return _backendListContains.apply(this, arguments);
}
function _backendListContains() {
  _backendListContains = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee16(sql, expectedName) {
    var data, error, table, target;
    return _regenerator().w(function (_context16) {
      while (1) switch (_context16.n) {
        case 0:
          _context16.n = 1;
          return executeBackendSql(sql, {
            sync: false
          });
        case 1:
          data = _context16.v;
          if (!hasResultError(data)) {
            _context16.n = 2;
            break;
          }
          error = (data.results || []).find(function (result) {
            return (result === null || result === void 0 ? void 0 : result.status) === 'error';
          });
          throw new Error((error === null || error === void 0 ? void 0 : error.message) || 'backend verification failed');
        case 2:
          table = (data.results || [data]).find(function (result) {
            return (result === null || result === void 0 ? void 0 : result.status) === 'table';
          });
          if (table) {
            _context16.n = 3;
            break;
          }
          throw new Error('backend verification returned no table');
        case 3:
          target = String(expectedName).toLowerCase();
          return _context16.a(2, (table.rows || []).some(function (row) {
            return (row || []).some(function (value) {
              return String(value).toLowerCase() === target;
            });
          }));
      }
    }, _callee16);
  }));
  return _backendListContains.apply(this, arguments);
}
function resultSetHasError(data) {
  var results = (data === null || data === void 0 ? void 0 : data.allResults) || (data === null || data === void 0 ? void 0 : data.results) || [data];
  return results.some(function (result) {
    return (result === null || result === void 0 ? void 0 : result.status) === 'error';
  });
}
function chooseAsaRunSound(kind) {
  var list = ASA_RUN_SOUNDS[kind] || ASA_RUN_SOUNDS.error;
  if (!list.length) return null;
  if (list.length === 1) return list[0];
  var index = Math.floor(Math.random() * list.length);
  if (index === asaRunSoundState[kind]) index = (index + 1) % list.length;
  asaRunSoundState[kind] = index;
  return list[index];
}
function getAsaRunAudioChannel() {
  if (typeof Audio === 'undefined') return null;
  if (!asaRunAudioChannel) {
    asaRunAudioChannel = new Audio();
    asaRunAudioChannel.preload = 'auto';
    asaRunAudioChannel.volume = 0.72;
  }
  return asaRunAudioChannel;
}
function primeAsaRunSounds() {
  if (typeof Audio === 'undefined') return Promise.resolve();
  if (asaRunPrimePromise) return asaRunPrimePromise;
  var source = ASA_RUN_SOUNDS.ok[0] || ASA_RUN_SOUNDS.error[0];
  var audio = source ? getAsaRunAudioChannel() : null;
  if (!audio) return Promise.resolve();
  var generation = ++asaRunAudioGeneration;
  try {
    audio.pause();
    audio.src = source;
    audio.muted = true;
    audio.volume = 0;
    audio.currentTime = 0;
    var played = audio.play();
    var primePromise;
    primePromise = Promise.resolve(played).then(function () {
      if (asaRunAudioGeneration !== generation) return;
      audio.pause();
      audio.currentTime = 0;
    }).catch(function () {
      // Some browsers unlock media only after the first completed gesture.
    }).finally(function () {
      if (asaRunPrimePromise === primePromise) asaRunPrimePromise = null;
    });
    asaRunPrimePromise = primePromise;
  } catch (_) {
    asaRunPrimePromise = Promise.resolve();
  }
  return asaRunPrimePromise;
}
function stopAsaRunSounds() {
  asaRunAudioGeneration += 1;
  if (!asaRunAudioChannel) return;
  try {
    asaRunAudioChannel.pause();
    asaRunAudioChannel.currentTime = 0;
    asaRunAudioChannel.muted = false;
  } catch (_) {}
}
function playAsaRunSound(kind) {
  if (typeof Audio === 'undefined') return;
  var src = chooseAsaRunSound(kind);
  var audio = getAsaRunAudioChannel();
  if (!audio) return;
  stopAsaRunSounds();
  var generation = asaRunAudioGeneration;
  try {
    audio.src = src;
    audio.currentTime = 0;
    audio.muted = false;
    audio.volume = 0.72;
    audio.onended = function () {
      if (asaRunAudioGeneration === generation) audio.currentTime = 0;
    };
    var played = audio.play();
    if (played && typeof played.catch === 'function') {
      played.catch(function () {});
    }
  } catch (_) {}
}
function executeBackendSqlBatched(_x12) {
  return _executeBackendSqlBatched.apply(this, arguments);
}
function _executeBackendSqlBatched() {
  _executeBackendSqlBatched = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee17(sql) {
    var _options$maxVisible;
    var options,
      statements,
      chunks,
      transactional,
      allResults,
      visibleResults,
      maxVisible,
      total,
      completed,
      pushResults,
      tick,
      _iterator45,
      _step45,
      chunk,
      errorResult,
      filtered,
      _args17 = arguments,
      _t13,
      _t14,
      _t15,
      _t16,
      _t17,
      _t18;
    return _regenerator().w(function (_context17) {
      while (1) switch (_context17.p = _context17.n) {
        case 0:
          options = _args17.length > 1 && _args17[1] !== undefined ? _args17[1] : {};
          statements = options.statements || splitStatementsDetailed(sql).flatMap(function (stmt) {
            return expandOversizedStatement(stmt.text).map(function (text) {
              return _objectSpread(_objectSpread({}, stmt), {}, {
                text
              });
            });
          });
          chunks = buildBackendSqlChunks(statements);
          transactional = options.transaction !== false && statements.some(function (stmt) {
            return isWriteStatement(stmt.text);
          });
          allResults = [];
          visibleResults = [];
          maxVisible = (_options$maxVisible = options.maxVisible) !== null && _options$maxVisible !== void 0 ? _options$maxVisible : 80;
          total = chunks.length + (transactional ? 2 : 0);
          completed = 0;
          pushResults = function pushResults(data) {
            var forceVisible = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : false;
            var results = data.results || [data];
            allResults.push.apply(allResults, _toConsumableArray(results));
            var _iterator44 = _createForOfIteratorHelper(results),
              _step44;
            try {
              for (_iterator44.s(); !(_step44 = _iterator44.n()).done;) {
                var result = _step44.value;
                var keepVisible = forceVisible || result.status === 'table' || result.status === 'error' || visibleResults.length < maxVisible;
                if (keepVisible) visibleResults.push(result);
              }
            } catch (err) {
              _iterator44.e(err);
            } finally {
              _iterator44.f();
            }
          };
          tick = function tick(label) {
            var _options$onProgress2;
            completed += 1;
            (_options$onProgress2 = options.onProgress) === null || _options$onProgress2 === void 0 || _options$onProgress2.call(options, {
              completed,
              total,
              label
            });
          };
          _context17.p = 1;
          if (!transactional) {
            _context17.n = 3;
            break;
          }
          _t13 = pushResults;
          _context17.n = 2;
          return executeBackendSql('BEGIN;', {
            sync: false
          });
        case 2:
          _t13(_context17.v);
          tick('BEGIN');
        case 3:
          _iterator45 = _createForOfIteratorHelper(chunks);
          _context17.p = 4;
          _iterator45.s();
        case 5:
          if ((_step45 = _iterator45.n()).done) {
            _context17.n = 8;
            break;
          }
          chunk = _step45.value;
          _t14 = pushResults;
          _context17.n = 6;
          return executeBackendSql(chunk.sql, {
            sync: false
          });
        case 6:
          _t14(_context17.v, chunk.forceVisible);
          tick(chunk.label);
          errorResult = allResults.find(function (result) {
            return result.status === 'error';
          });
          if (!(errorResult && options.stopOnError)) {
            _context17.n = 7;
            break;
          }
          throw new Error(errorResult.message || 'SQL batch failed.');
        case 7:
          _context17.n = 5;
          break;
        case 8:
          _context17.n = 10;
          break;
        case 9:
          _context17.p = 9;
          _t15 = _context17.v;
          _iterator45.e(_t15);
        case 10:
          _context17.p = 10;
          _iterator45.f();
          return _context17.f(10);
        case 11:
          if (!transactional) {
            _context17.n = 13;
            break;
          }
          _t16 = pushResults;
          _context17.n = 12;
          return executeBackendSql('COMMIT;', {
            sync: false
          });
        case 12:
          _t16(_context17.v, true);
          tick('COMMIT');
        case 13:
          if (!(options.syncFinal === 'none')) {
            _context17.n = 14;
            break;
          }
          _context17.n = 17;
          break;
        case 14:
          if (!(options.syncFinal === false)) {
            _context17.n = 16;
            break;
          }
          _context17.n = 15;
          return syncCatalogFromBackend().catch(function () {
            return false;
          });
        case 15:
          _context17.n = 17;
          break;
        case 16:
          _context17.n = 17;
          return syncBackendStateSmart();
        case 17:
          _context17.n = 27;
          break;
        case 18:
          _context17.p = 18;
          _t17 = _context17.v;
          if (!transactional) {
            _context17.n = 22;
            break;
          }
          _context17.p = 19;
          _context17.n = 20;
          return executeBackendSql('ROLLBACK;', {
            sync: false
          });
        case 20:
          _context17.n = 22;
          break;
        case 21:
          _context17.p = 21;
          _t18 = _context17.v;
        case 22:
          if (!(options.syncFinal === 'none')) {
            _context17.n = 23;
            break;
          }
          _context17.n = 26;
          break;
        case 23:
          if (!(options.syncFinal === false)) {
            _context17.n = 25;
            break;
          }
          _context17.n = 24;
          return syncCatalogFromBackend().catch(function () {
            return false;
          });
        case 24:
          _context17.n = 26;
          break;
        case 25:
          _context17.n = 26;
          return syncBackendStateSmart().catch(function () {
            return false;
          });
        case 26:
          throw _t17;
        case 27:
          filtered = options.showOnlyErrors ? allResults.filter(function (result) {
            return result.status === 'error';
          }) : visibleResults;
          return _context17.a(2, {
            results: compactBatchResults(filtered, allResults),
            allResults,
            statementCount: statements.length
          });
      }
    }, _callee17, null, [[19, 21], [4, 9, 10, 11], [1, 18]]);
  }));
  return _executeBackendSqlBatched.apply(this, arguments);
}
function buildBackendSqlChunks(statements) {
  var limit = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : 200000;
  var chunks = [];
  var batch = [];
  var length = 0;
  var flush = function flush() {
    if (!batch.length) return;
    var first = statementBody(batch[0].text).slice(0, 72);
    chunks.push({
      sql: batch.map(function (stmt) {
        return `${stmt.text};`;
      }).join('\n'),
      forceVisible: batch.some(function (stmt) {
        return /^(select|show|describe|desc)\b/i.test(statementBody(stmt.text));
      }),
      label: batch.length === 1 ? first : `${first} + ${batch.length - 1} statement(s)`
    });
    batch = [];
    length = 0;
  };
  var _iterator7 = _createForOfIteratorHelper(statements),
    _step7;
  try {
    for (_iterator7.s(); !(_step7 = _iterator7.n()).done;) {
      var stmt = _step7.value;
      var text = `${stmt.text};`;
      if (batch.length && length + text.length + 1 > limit) flush();
      batch.push(stmt);
      length += text.length + 1;
    }
  } catch (err) {
    _iterator7.e(err);
  } finally {
    _iterator7.f();
  }
  flush();
  return chunks;
}
function compactBatchResults(visibleResults, allResults) {
  var errors = allResults.filter(function (result) {
    return result.status === 'error';
  });
  if (errors.length) return errors;
  var tableResults = visibleResults.filter(function (result) {
    return result.status === 'table';
  });
  var finalOk = _toConsumableArray(allResults).reverse().find(function (result) {
    return result.status === 'ok';
  });
  var writes = allResults.filter(function (result) {
    return result.status === 'ok' && /^(inserted|created_table|dropped_table|committed|using_database|created_database)/.test(String(result.message || ''));
  }).length;
  var summary = writes ? [{
    status: 'ok',
    message: `batch_completed(${writes} write step(s))`
  }] : [];
  return [].concat(summary, _toConsumableArray(tableResults), _toConsumableArray(finalOk && !summary.includes(finalOk) ? [finalOk] : [])).slice(0, 80);
}
function isWriteStatement(text) {
  return /^(create|drop|insert|update|delete|alter|truncate|begin|start|commit|rollback|grant|revoke|use)\b/i.test(statementBody(text));
}
function statementBody(text) {
  return String(text || '').trim().replace(/^(?:(?:--[^\n]*(?:\n|$)|#[^\n]*(?:\n|$)|\/\*[\s\S]*?\*\/)\s*)+/g, '').trim();
}
function expandOversizedStatement(text) {
  var limit = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : 200000;
  var source = String(text || '').trim();
  if (source.length <= limit) return [source];
  var body = statementBody(source);
  var match = /^(INSERT\s+INTO\s+[\s\S]+?\s+VALUES)\s+([\s\S]+)$/i.exec(body);
  if (!match) return [source];
  var prefix = match[1].trim();
  var groups = splitValueGroups(match[2]);
  if (!groups.length) return [source];
  var out = [];
  var batch = [];
  var batchLength = prefix.length + 8;
  var _iterator8 = _createForOfIteratorHelper(groups),
    _step8;
  try {
    for (_iterator8.s(); !(_step8 = _iterator8.n()).done;) {
      var group = _step8.value;
      var groupText = `(${group})`;
      if (batch.length && batchLength + groupText.length + 2 > limit) {
        out.push(`${prefix}\n  ${batch.join(',\n  ')}`);
        batch = [];
        batchLength = prefix.length + 8;
      }
      batch.push(groupText);
      batchLength += groupText.length + 2;
    }
  } catch (err) {
    _iterator8.e(err);
  } finally {
    _iterator8.f();
  }
  if (batch.length) out.push(`${prefix}\n  ${batch.join(',\n  ')}`);
  return out;
}
function syncSandboxFromBackend() {
  return _syncSandboxFromBackend.apply(this, arguments);
}
function _syncSandboxFromBackend() {
  _syncSandboxFromBackend = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee18() {
    var res, data;
    return _regenerator().w(function (_context18) {
      while (1) switch (_context18.n) {
        case 0:
          _context18.n = 1;
          return fetch('/api/state', {
            cache: 'no-store',
            headers: apiHeaders()
          });
        case 1:
          res = _context18.v;
          if (res.ok) {
            _context18.n = 2;
            break;
          }
          return _context18.a(2, false);
        case 2:
          _context18.n = 3;
          return res.json();
        case 3:
          data = _context18.v;
          syncSandboxFromStateData(data);
          return _context18.a(2, true);
      }
    }, _callee18);
  }));
  return _syncSandboxFromBackend.apply(this, arguments);
}
function syncBackendStateSmart() {
  return _syncBackendStateSmart.apply(this, arguments);
}
function _syncBackendStateSmart() {
  _syncBackendStateSmart = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee19() {
    var catalog;
    return _regenerator().w(function (_context19) {
      while (1) switch (_context19.n) {
        case 0:
          _context19.n = 1;
          return syncCatalogFromBackend().catch(function () {
            return null;
          });
        case 1:
          catalog = _context19.v;
          if (catalog) {
            _context19.n = 2;
            break;
          }
          return _context19.a(2, syncSandboxFromBackend());
        case 2:
          if (!(catalog.totalRows <= BACKEND_FULL_SYNC_ROW_LIMIT)) {
            _context19.n = 3;
            break;
          }
          return _context19.a(2, syncSandboxFromBackend());
        case 3:
          return _context19.a(2, true);
      }
    }, _callee19);
  }));
  return _syncBackendStateSmart.apply(this, arguments);
}
function syncCatalogFromBackend() {
  return _syncCatalogFromBackend.apply(this, arguments);
}
function _syncCatalogFromBackend() {
  _syncCatalogFromBackend = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee20() {
    var res, data;
    return _regenerator().w(function (_context20) {
      while (1) switch (_context20.n) {
        case 0:
          _context20.n = 1;
          return fetch('/api/catalog', {
            cache: 'no-store',
            headers: apiHeaders()
          });
        case 1:
          res = _context20.v;
          if (res.ok) {
            _context20.n = 2;
            break;
          }
          return _context20.a(2, false);
        case 2:
          _context20.n = 3;
          return res.json();
        case 3:
          data = _context20.v;
          return _context20.a(2, syncSandboxFromCatalogData(data));
      }
    }, _callee20);
  }));
  return _syncCatalogFromBackend.apply(this, arguments);
}
function refreshDatabaseMetadata() {
  if (!backendOnline) {
    lastDatabaseMetadata = null;
    renderDatabaseMetadata(null);
    return Promise.resolve(null);
  }
  if (metadataRefreshPromise) return metadataRefreshPromise;
  metadataRefreshPromise = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee2() {
    var res, metadata;
    return _regenerator().w(function (_context2) {
      while (1) switch (_context2.n) {
        case 0:
          _context2.n = 1;
          return fetch('/api/metadata', {
            cache: 'no-store',
            headers: apiHeaders()
          });
        case 1:
          res = _context2.v;
          if (res.ok) {
            _context2.n = 2;
            break;
          }
          throw new Error(`HTTP ${res.status}`);
        case 2:
          _context2.n = 3;
          return res.json();
        case 3:
          metadata = _context2.v;
          lastDatabaseMetadata = metadata;
          lastMetadataRefreshAt = Date.now();
          renderDatabaseMetadata(metadata);
          return _context2.a(2, metadata);
      }
    }, _callee2);
  }))().finally(function () {
    metadataRefreshPromise = null;
  });
  return metadataRefreshPromise;
}
function metadataPollInterval() {
  if (activeReservoirJobId) return METADATA_ACTIVE_POLL_INTERVAL_MS;
  if (dbMetadataPanel !== null && dbMetadataPanel !== void 0 && dbMetadataPanel.open) return METADATA_OPEN_POLL_INTERVAL_MS;
  return METADATA_IDLE_POLL_INTERVAL_MS;
}
function scheduleMetadataPoll() {
  var delay = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : metadataPollInterval();
  clearTimeout(metadataPollTimer);
  metadataPollTimer = setTimeout(/*#__PURE__*/_asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee3() {
    var _t2;
    return _regenerator().w(function (_context3) {
      while (1) switch (_context3.p = _context3.n) {
        case 0:
          if (!(backendOnline && document.visibilityState !== 'hidden')) {
            _context3.n = 4;
            break;
          }
          _context3.p = 1;
          _context3.n = 2;
          return refreshDatabaseMetadata();
        case 2:
          _context3.n = 4;
          break;
        case 3:
          _context3.p = 3;
          _t2 = _context3.v;
        case 4:
          scheduleMetadataPoll(metadataPollInterval());
        case 5:
          return _context3.a(2);
      }
    }, _callee3, null, [[1, 3]]);
  })), Math.max(0, delay));
}
function requestMetadataRefreshDuringJob() {
  if (!backendOnline) return;
  var elapsed = Date.now() - lastMetadataRefreshAt;
  scheduleMetadataPoll(Math.max(0, METADATA_ACTIVE_POLL_INTERVAL_MS - elapsed));
}
function renderDatabaseMetadata(metadata) {
  var _metadata$storage, _ref7, _reservoir$active;
  if (!dbMetadataPanel) return;
  if (!metadata) {
    metadataState.textContent = backendOnline ? t('state.unavailable') : t('state.offline');
    for (var _i8 = 0, _arr2 = [metadataEngine, metadataIdentity, metadataObjects, metadataRows, metadataStorage, metadataCache, metadataReservoir, metadataCheckpoint]; _i8 < _arr2.length; _i8++) {
      var node = _arr2[_i8];
      node.textContent = '-';
    }
    return;
  }
  var summary = metadata.summary || {};
  var persistence = metadata.persistence || {};
  var pager = ((_metadata$storage = metadata.storage) === null || _metadata$storage === void 0 ? void 0 : _metadata$storage.pager) || {};
  var pool = pager.buffer_pool || {};
  var reservoir = metadata.reservoir || {};
  var dirty = Boolean(persistence.checkpoint_dirty || persistence.transaction_active);
  metadataState.textContent = dirty ? t('state.pending') : t('state.durable');
  metadataEngine.textContent = `v${metadata.engine_version || '?'} / format ${metadata.storage_format || summary.storage_format || '?'}`;
  metadataIdentity.textContent = metadata.database_id || '-';
  metadataObjects.textContent = t('metadata.objectsValue', {
    databases: formatNumber(summary.database_count || 0),
    tables: formatNumber(summary.table_count || 0),
    views: formatNumber(summary.view_count || 0)
  });
  metadataRows.textContent = formatNumber(summary.row_count || 0);
  metadataStorage.textContent = t('metadata.storageValue', {
    size: formatBytes((persistence.catalog_bytes || 0) + (persistence.store_bytes || 0))
  });
  metadataCache.textContent = t('metadata.cacheValue', {
    pages: formatNumber(pool.pages || 0),
    limit: formatNumber(pool.limit_pages || 0),
    hits: formatNumber(pool.hits || 0)
  });
  metadataReservoir.textContent = t('metadata.reservoirValue', {
    active: formatNumber((_ref7 = (_reservoir$active = reservoir.active) !== null && _reservoir$active !== void 0 ? _reservoir$active : reservoir.processing) !== null && _ref7 !== void 0 ? _ref7 : 0),
    queued: formatNumber(reservoir.queued || 0),
    size: formatBytes(reservoir.spool_bytes || 0)
  });
  metadataCheckpoint.textContent = t('metadata.checkpointValue', {
    count: formatNumber(metadata.checkpoint_count || 0),
    time: metadata.last_checkpoint_at || t('state.never')
  });
}
function syncSandboxFromCatalogData(data) {
  var rows = (data === null || data === void 0 ? void 0 : data.rows) || [];
  if (!rows.length) {
    sandbox = normalizeSandbox({
      currentDb: '',
      dbs: {},
      views: {}
    });
    selectedTable = '';
    saveSandbox();
    renderTableBrowser();
    return {
      totalRows: 0
    };
  }
  var dbs = {};
  var views = {};
  var currentDb = '';
  var totalRows = 0;
  var _iterator9 = _createForOfIteratorHelper(rows),
    _step9;
  try {
    for (_iterator9.s(); !(_step9 = _iterator9.n()).done;) {
      var row = _step9.value;
      var _row = _slicedToArray(row, 8),
        current = _row[0],
        _dbName = _row[1],
        kind = _row[2],
        name = _row[3],
        rowCount = _row[4],
        columnsTerm = _row[5],
        indexesTerm = _row[6],
        queryTerm = _row[7];
      if (current && current !== 'none') currentDb = current;
      if (!_dbName || isSystemDb(_dbName)) continue;
      dbs[_dbName] || (dbs[_dbName] = {});
      views[_dbName] || (views[_dbName] = {});
      if (kind === 'table' && name) {
        var _sandbox$dbs2, _existing$rows;
        var count = Number(rowCount) || 0;
        var existing = (_sandbox$dbs2 = sandbox.dbs) === null || _sandbox$dbs2 === void 0 || (_sandbox$dbs2 = _sandbox$dbs2[_dbName]) === null || _sandbox$dbs2 === void 0 ? void 0 : _sandbox$dbs2[name];
        var existingRows = (existing === null || existing === void 0 || (_existing$rows = existing.rows) === null || _existing$rows === void 0 ? void 0 : _existing$rows.length) === count ? existing.rows : [];
        dbs[_dbName][name] = {
          columns: parseCatalogColumns(columnsTerm),
          rows: existingRows,
          indexes: parseCatalogIndexes(indexesTerm),
          rowCount: count,
          remote: true
        };
        totalRows += count;
      } else if (kind === 'view' && name) {
        views[_dbName][name] = {
          name,
          query: queryTerm ? String(queryTerm) : '',
          columns: [],
          rows: [],
          isView: true,
          remote: true
        };
      }
    }
  } catch (err) {
    _iterator9.e(err);
  } finally {
    _iterator9.f();
  }
  sandbox = normalizeSandbox({
    currentDb: currentDb && currentDb !== 'none' ? currentDb : sandbox.currentDb,
    dbs,
    views
  });
  if (selectedTable && !currentRelation(selectedTable)) selectedTable = '';
  saveSandbox();
  renderTableBrowser();
  return {
    totalRows
  };
}
function parseCatalogColumns(termText) {
  try {
    var term = parsePrologTerm(String(termText || '[]'));
    return (term.items || []).filter(function (node) {
      return node.type === 'compound' && node.functor === 'col';
    }).map(function (node) {
      var _node$args$;
      var column = {
        name: nodeValue(node.args[0]),
        type: nodeValue(node.args[1]) || 'TEXT'
      };
      var _iterator0 = _createForOfIteratorHelper(((_node$args$ = node.args[2]) === null || _node$args$ === void 0 ? void 0 : _node$args$.items) || []),
        _step0;
      try {
        for (_iterator0.s(); !(_step0 = _iterator0.n()).done;) {
          var option = _step0.value;
          var optionName = option.type === 'compound' ? option.functor : nodeValue(option);
          if (optionName === 'not_null') column.nullable = false;
          if (optionName === 'auto_increment') column.extra = 'Auto Increment';
          if (optionName === 'primary_key') column.primary = true;
          if (optionName === 'unique') column.unique = true;
          if (option.type === 'compound' && option.functor === 'default') column.default = nodeValue(option.args[0]);
        }
      } catch (err) {
        _iterator0.e(err);
      } finally {
        _iterator0.f();
      }
      return column;
    }).filter(function (column) {
      return column.name;
    });
  } catch (_) {
    return [];
  }
}
function parseCatalogIndexes(termText) {
  try {
    var term = parsePrologTerm(String(termText || '[]'));
    return (term.items || []).filter(function (node) {
      return node.type === 'compound' && node.functor === 'index';
    }).map(function (node) {
      var _node$args$2;
      return {
        name: nodeValue(node.args[0]) || 'INDEX',
        columns: (((_node$args$2 = node.args[1]) === null || _node$args$2 === void 0 ? void 0 : _node$args$2.items) || []).map(nodeValue).filter(Boolean),
        unique: nodeValue(node.args[2]) === 'unique'
      };
    });
  } catch (_) {
    return [];
  }
}
function syncSandboxFromStateData(data) {
  var _data$rows;
  var row = (data === null || data === void 0 || (_data$rows = data.rows) === null || _data$rows === void 0 ? void 0 : _data$rows[0]) || [];
  var stateTerm = row[0];
  var currentDb = row[1] && row[1] !== 'none' ? row[1] : '';
  if (!stateTerm) return;
  try {
    var _next$views;
    var next = prologTermToSandbox(parsePrologTerm(String(stateTerm)));
    if (currentDb && (next.dbs[currentDb] || (_next$views = next.views) !== null && _next$views !== void 0 && _next$views[currentDb]) && !isSystemDb(currentDb)) next.currentDb = currentDb;
    sandbox = normalizeSandbox(next);
    saveSandbox();
    if (selectedTable && !currentRelation(selectedTable)) selectedTable = '';
    renderTableBrowser();
  } catch (err) {
    log(t('log.stateSyncSkipped', {
      error: err.message
    }));
  }
}
function startupDelay(ms) {
  return new Promise(function (resolve) {
    return setTimeout(resolve, ms);
  });
}
function startupWarmupEnabled() {
  if (!startupLoader) return false;
  if (location.protocol !== 'http:' && location.protocol !== 'https:') return false;
  return ['127.0.0.1', 'localhost', '::1', '[::1]'].includes(location.hostname);
}
function hideStartupLoader() {
  if (!startupLoader) return;
  startupLoader.classList.add('hidden');
  document.body.classList.remove('is-warming');
  setTimeout(function () {
    return startupLoader.remove();
  }, 260);
}
function runStartupWarmup(engineWork) {
  if (!startupLoader) return;
  if (!startupWarmupEnabled()) {
    hideStartupLoader();
    return;
  }
  document.body.classList.add('is-warming');
  // The Prolog server has already warmed its runtime before opening port 8088.
  // Keep only a short, non-blocking visual cue; do not issue a second warmup.
  Promise.resolve(engineWork).catch(function () {});
  startupDelay(STARTUP_WARMUP_MS).then(hideStartupLoader);
}
function checkEngine() {
  return _checkEngine.apply(this, arguments);
}
function _checkEngine() {
  _checkEngine = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee21() {
    var reservoirOnline, res, _t19, _t20, _t21;
    return _regenerator().w(function (_context21) {
      while (1) switch (_context21.p = _context21.n) {
        case 0:
          reservoirOnline = false;
          _context21.p = 1;
          _context21.n = 2;
          return fetch('/api/reservoir/stats', {
            cache: 'no-store',
            headers: apiHeaders()
          });
        case 2:
          res = _context21.v;
          reservoirOnline = res.ok;
          _context21.n = 4;
          break;
        case 3:
          _context21.p = 3;
          _t19 = _context21.v;
          reservoirOnline = false;
        case 4:
          if (!reservoirOnline) {
            _context21.n = 5;
            break;
          }
          backendOnline = true;
          syncBackendStateSmart().catch(function () {
            return false;
          });
          _context21.n = 8;
          break;
        case 5:
          _context21.p = 5;
          _t20 = Boolean;
          _context21.n = 6;
          return syncBackendStateSmart();
        case 6:
          backendOnline = _t20(_context21.v);
          _context21.n = 8;
          break;
        case 7:
          _context21.p = 7;
          _t21 = _context21.v;
          backendOnline = false;
        case 8:
          engineCheckCompleted = true;
          updateEngineStatus();
          log(backendOnline ? t('log.connected') : t('log.sandbox'));
          if (backendOnline) {
            refreshDatabaseMetadata().catch(function () {
              return renderDatabaseMetadata(null);
            });
            resumeActiveReservoirJob().catch(function () {
              return null;
            });
          } else {
            renderDatabaseMetadata(null);
          }
          scheduleMetadataPoll(backendOnline ? 0 : METADATA_IDLE_POLL_INTERVAL_MS);
          refreshSqlDiagnostics(backendOnline);
        case 9:
          return _context21.a(2);
      }
    }, _callee21, null, [[5, 7], [1, 3]]);
  }));
  return _checkEngine.apply(this, arguments);
}
function showView(name) {
  var hashName = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : name;
  currentViewName = name;
  for (var _i9 = 0, _Object$entries3 = Object.entries(views); _i9 < _Object$entries3.length; _i9++) {
    var _Object$entries3$_i = _slicedToArray(_Object$entries3[_i9], 2),
      viewName = _Object$entries3$_i[0],
      node = _Object$entries3$_i[1];
    node.hidden = viewName !== name;
  }
  for (var _i0 = 0, _Object$entries4 = Object.entries(viewButtons); _i0 < _Object$entries4.length; _i0++) {
    var _Object$entries4$_i = _slicedToArray(_Object$entries4[_i0], 2),
      _viewName = _Object$entries4$_i[0],
      button = _Object$entries4$_i[1];
    button.classList.toggle('active', _viewName === name);
  }
  updatePageTitle();
  if (location.hash !== `#${hashName}`) history.replaceState(null, '', `#${hashName}`);
  if (name === 'export') {
    renderExportTablePicker();
    exportDbName.textContent = currentDbName() || t('database.noneSelected');
  }
}
function splitStatements(sql) {
  return splitStatementsDetailed(sql).map(function (stmt) {
    return stmt.text;
  });
}
function splitStatementsDetailed(sql) {
  var out = [];
  var cur = '';
  var quote = null;
  var esc = false;
  var line = 1;
  var stmtLine = 1;
  var hasContent = false;
  for (var i = 0; i < sql.length; i += 1) {
    var ch = sql[i];
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
      var end = copySqlComment(sql, i);
      var comment = sql.slice(i, end);
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
      if (cur.trim()) out.push({
        text: cur.trim(),
        line: stmtLine,
        terminated: true
      });
      cur = '';
      hasContent = false;
      stmtLine = line;
      continue;
    }
    cur += ch;
    if (ch === '\n') line += 1;
  }
  if (cur.trim()) out.push({
    text: cur.trim(),
    line: stmtLine,
    terminated: false
  });
  return out;
}
function splitTopLevel(text) {
  var separator = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : ',';
  var parts = [];
  var cur = '',
    quote = null,
    esc = false,
    depth = 0;
  var _iterator1 = _createForOfIteratorHelper(text),
    _step1;
  try {
    for (_iterator1.s(); !(_step1 = _iterator1.n()).done;) {
      var ch = _step1.value;
      if (esc) {
        cur += ch;
        esc = false;
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
        continue;
      }
      if (ch === '\'' || ch === '"') {
        quote = ch;
        cur += ch;
        continue;
      }
      if (ch === '(') depth += 1;
      if (ch === ')') depth -= 1;
      if (ch === separator && depth === 0) {
        parts.push(cur.trim());
        cur = '';
        continue;
      }
      cur += ch;
    }
  } catch (err) {
    _iterator1.e(err);
  } finally {
    _iterator1.f();
  }
  if (cur.trim()) parts.push(cur.trim());
  return parts;
}
function splitValueGroups(text) {
  var groups = [];
  var cur = '',
    quote = null,
    esc = false,
    depth = 0,
    inGroup = false;
  var _iterator10 = _createForOfIteratorHelper(text),
    _step10;
  try {
    for (_iterator10.s(); !(_step10 = _iterator10.n()).done;) {
      var ch = _step10.value;
      if (esc) {
        if (inGroup) cur += ch;
        esc = false;
        continue;
      }
      if (ch === '\\') {
        if (inGroup) cur += ch;
        esc = true;
        continue;
      }
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
  } catch (err) {
    _iterator10.e(err);
  } finally {
    _iterator10.f();
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
  var clean = String(name || '').trim();
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
  return String(type || 'TEXT').trim().replace(/\s+/g, ' ').replace(/\s*\(\s*/g, '(').replace(/\s*,\s*/g, ', ').replace(/\s*\)\s*/g, ')').toUpperCase();
}
function parseLeadingIdentifier(text) {
  var source = String(text || '').trim();
  var quoted = /^`([^`]+)`\s*([^]*)$/.exec(source) || /^"([^"]+)"\s*([^]*)$/.exec(source);
  if (quoted) return {
    name: quoted[1],
    rest: quoted[2].trim()
  };
  var bare = /^([A-Za-z_][\w$]*)\s*([^]*)$/.exec(source);
  return bare ? {
    name: bare[1],
    rest: bare[2].trim()
  } : null;
}
function stripColumnPlacement(text) {
  return String(text || '').replace(/\s+FIRST\s*$/i, '').replace(/\s+AFTER\s+`?[\w$]+`?\s*$/i, '').trim();
}
function parseColumnSpec(text) {
  var ident = parseLeadingIdentifier(text);
  if (!ident || !ident.rest) return null;
  var rest = stripColumnPlacement(ident.rest);
  var typeMatch = /^([A-Za-z]+(?:\s*\([^)]*\))?(?:\s+UNSIGNED)?)([\s\S]*)$/i.exec(rest);
  if (!typeMatch) return null;
  var optionText = typeMatch[2] || '';
  var column = {
    name: cleanSqlIdentifier(ident.name),
    type: normalizeSqlType(typeMatch[1])
  };
  if (/\bNOT\s+NULL\b/i.test(optionText)) column.nullable = false;
  if (/\bAUTO_INCREMENT\b/i.test(optionText)) column.extra = 'Auto Increment';
  var defaultMatch = /\bDEFAULT\s+('[^']*'|"[^"]*"|[^\s,]+)/i.exec(optionText);
  if (defaultMatch) column.default = parseValue(defaultMatch[1]);
  if (/\bPRIMARY\s+KEY\b/i.test(optionText)) column.primary = true;
  if (/\bUNIQUE\b/i.test(optionText)) column.unique = true;
  return column;
}
function parseAlterOperation(text) {
  var op = String(text || '').trim();
  var m;
  if (m = /^ADD\s+(?:COLUMN\s+)?([\s\S]+)$/i.exec(op)) {
    var column = parseColumnSpec(m[1]);
    return column ? {
      kind: 'add',
      column
    } : null;
  }
  if (m = /^DROP\s+(?:COLUMN\s+)?(.+)$/i.exec(op)) {
    var ident = parseLeadingIdentifier(m[1]);
    return ident ? {
      kind: 'drop',
      name: ident.name
    } : null;
  }
  if (m = /^MODIFY\s+(?:COLUMN\s+)?([\s\S]+)$/i.exec(op)) {
    var _column = parseColumnSpec(m[1]);
    return _column ? {
      kind: 'modify',
      column: _column
    } : null;
  }
  if (m = /^CHANGE\s+(?:COLUMN\s+)?([\s\S]+)$/i.exec(op)) {
    var oldIdent = parseLeadingIdentifier(m[1]);
    var _column2 = oldIdent ? parseColumnSpec(oldIdent.rest) : null;
    return _column2 ? {
      kind: 'change',
      oldName: oldIdent.name,
      column: _column2
    } : null;
  }
  if (m = /^RENAME\s+COLUMN\s+(.+?)\s+TO\s+(.+)$/i.exec(op)) {
    var _oldIdent = parseLeadingIdentifier(m[1]);
    var newIdent = parseLeadingIdentifier(m[2]);
    return _oldIdent && newIdent ? {
      kind: 'renameColumn',
      oldName: _oldIdent.name,
      newName: newIdent.name
    } : null;
  }
  if (m = /^RENAME\s+(?:TO\s+)?(.+)$/i.exec(op)) {
    var _ident = parseLeadingIdentifier(m[1]);
    return _ident ? {
      kind: 'renameTable',
      name: _ident.name
    } : null;
  }
  return null;
}
function removeColumnFromIndexes(table, name) {
  table.indexes = (table.indexes || []).map(function (index) {
    return _objectSpread(_objectSpread({}, index), {}, {
      columns: (index.columns || []).filter(function (column) {
        return column !== name;
      })
    });
  }).filter(function (index) {
    return (index.columns || []).length;
  });
}
function renameColumnInIndexes(table, oldName, newName) {
  table.indexes = (table.indexes || []).map(function (index) {
    return _objectSpread(_objectSpread({}, index), {}, {
      columns: (index.columns || []).map(function (column) {
        return column === oldName ? newName : column;
      })
    });
  });
}
function applyColumnIndexOptions(table, column) {
  table.indexes || (table.indexes = []);
  if (column.primary) {
    table.indexes = table.indexes.filter(function (index) {
      return !/^PRIMARY$/i.test(index.name || '');
    });
    table.indexes.unshift({
      name: 'PRIMARY',
      columns: [column.name],
      unique: true
    });
  } else if (column.unique) {
    var name = `${column.name}_unique`;
    table.indexes = table.indexes.filter(function (index) {
      return index.name !== name;
    });
    table.indexes.push({
      name,
      columns: [column.name],
      unique: true
    });
  }
  delete column.primary;
  delete column.unique;
}
function sandboxColumnKey(table, columnName, column) {
  if (column !== null && column !== void 0 && column.primary) return 'PRI';
  if (column !== null && column !== void 0 && column.unique) return 'UNI';
  var _iterator11 = _createForOfIteratorHelper(table.indexes || []),
    _step11;
  try {
    for (_iterator11.s(); !(_step11 = _iterator11.n()).done;) {
      var index = _step11.value;
      if (!(index.columns || []).includes(columnName)) continue;
      if (/^PRIMARY$/i.test(index.name || '')) return 'PRI';
      if (index.unique) return 'UNI';
      return 'MUL';
    }
  } catch (err) {
    _iterator11.e(err);
  } finally {
    _iterator11.f();
  }
  return '';
}
function sandboxDescribeRows(table) {
  return (table.columns || []).map(function (column) {
    return [column.name, column.type || 'TEXT', column.nullable === false ? 'NO' : 'YES', sandboxColumnKey(table, column.name, column), Object.prototype.hasOwnProperty.call(column, 'default') ? column.default : 'NULL', column.extra || ''];
  });
}
function applySandboxAlter(db, tableName, operations) {
  var table = db[tableName];
  if (!table) return `table not found: ${tableName}`;
  table.columns || (table.columns = []);
  table.rows || (table.rows = []);
  table.indexes || (table.indexes = []);
  var _iterator12 = _createForOfIteratorHelper(operations),
    _step12;
  try {
    var _loop3 = function _loop3() {
        var operation = _step12.value;
        if (!operation) return {
          v: `sandbox belum support: ALTER operation`
        };
        if (operation.kind === 'add') {
          if (table.columns.some(function (column) {
            return column.name === operation.column.name;
          })) return {
            v: `column already exists: ${operation.column.name}`
          };
          applyColumnIndexOptions(table, operation.column);
          table.columns.push(operation.column);
          var _iterator13 = _createForOfIteratorHelper(table.rows),
            _step13;
          try {
            for (_iterator13.s(); !(_step13 = _iterator13.n()).done;) {
              var row = _step13.value;
              row[operation.column.name] = Object.prototype.hasOwnProperty.call(operation.column, 'default') ? operation.column.default : null;
            }
          } catch (err) {
            _iterator13.e(err);
          } finally {
            _iterator13.f();
          }
        } else if (operation.kind === 'drop') {
          table.columns = table.columns.filter(function (column) {
            return column.name !== operation.name;
          });
          var _iterator14 = _createForOfIteratorHelper(table.rows),
            _step14;
          try {
            for (_iterator14.s(); !(_step14 = _iterator14.n()).done;) {
              var _row2 = _step14.value;
              delete _row2[operation.name];
            }
          } catch (err) {
            _iterator14.e(err);
          } finally {
            _iterator14.f();
          }
          removeColumnFromIndexes(table, operation.name);
        } else if (operation.kind === 'modify') {
          var index = table.columns.findIndex(function (column) {
            return column.name === operation.column.name;
          });
          if (index === -1) return {
            v: `column not found: ${operation.column.name}`
          };
          applyColumnIndexOptions(table, operation.column);
          table.columns[index] = _objectSpread(_objectSpread({}, table.columns[index]), operation.column);
        } else if (operation.kind === 'change') {
          var _index = table.columns.findIndex(function (column) {
            return column.name === operation.oldName;
          });
          if (_index === -1) return {
            v: `column not found: ${operation.oldName}`
          };
          var oldName = operation.oldName;
          var nextName = operation.column.name;
          applyColumnIndexOptions(table, operation.column);
          table.columns[_index] = _objectSpread(_objectSpread({}, table.columns[_index]), operation.column);
          var _iterator15 = _createForOfIteratorHelper(table.rows),
            _step15;
          try {
            for (_iterator15.s(); !(_step15 = _iterator15.n()).done;) {
              var _row3$oldName;
              var _row3 = _step15.value;
              _row3[nextName] = (_row3$oldName = _row3[oldName]) !== null && _row3$oldName !== void 0 ? _row3$oldName : null;
              if (nextName !== oldName) delete _row3[oldName];
            }
          } catch (err) {
            _iterator15.e(err);
          } finally {
            _iterator15.f();
          }
          renameColumnInIndexes(table, oldName, nextName);
        } else if (operation.kind === 'renameColumn') {
          var _index2 = table.columns.findIndex(function (column) {
            return column.name === operation.oldName;
          });
          if (_index2 === -1) return {
            v: `column not found: ${operation.oldName}`
          };
          table.columns[_index2] = _objectSpread(_objectSpread({}, table.columns[_index2]), {}, {
            name: operation.newName
          });
          var _iterator16 = _createForOfIteratorHelper(table.rows),
            _step16;
          try {
            for (_iterator16.s(); !(_step16 = _iterator16.n()).done;) {
              var _row4$operation$oldNa;
              var _row4 = _step16.value;
              _row4[operation.newName] = (_row4$operation$oldNa = _row4[operation.oldName]) !== null && _row4$operation$oldNa !== void 0 ? _row4$operation$oldNa : null;
              if (operation.newName !== operation.oldName) delete _row4[operation.oldName];
            }
          } catch (err) {
            _iterator16.e(err);
          } finally {
            _iterator16.f();
          }
          renameColumnInIndexes(table, operation.oldName, operation.newName);
        } else if (operation.kind === 'renameTable') {
          if (db[operation.name]) return {
            v: `table already exists: ${operation.name}`
          };
          db[operation.name] = table;
          delete db[tableName];
          if (selectedTable === tableName) selectedTable = operation.name;
        } else {
          return {
            v: `sandbox belum support: ALTER operation`
          };
        }
      },
      _ret;
    for (_iterator12.s(); !(_step12 = _iterator12.n()).done;) {
      _ret = _loop3();
      if (_ret) return _ret.v;
    }
  } catch (err) {
    _iterator12.e(err);
  } finally {
    _iterator12.f();
  }
  return '';
}
function sandboxExec(sql) {
  var results = [];
  var _iterator17 = _createForOfIteratorHelper(splitStatementsDetailed(sql)),
    _step17;
  try {
    var _loop4 = function _loop4() {
        var stmt = _step17.value;
        var line = stmt.line;
        var add = function add(result) {
          return results.push(_objectSpread({
            line
          }, result));
        };
        var requireDb = function requireDb() {
          var db = currentDbName();
          if (!db) add({
            status: 'error',
            message: 'select or create a database first'
          });
          return db;
        };
        var s = statementBody(stmt.text).replace(/\s+/g, ' ').trim();
        var m;
        if (m = /^CREATE DATABASE(?: IF NOT EXISTS)? `?([\w$]+)`?$/i.exec(s)) {
          var _sandbox$dbs3, _m$, _sandbox, _sandbox$views2, _m$2;
          (_sandbox$dbs3 = sandbox.dbs)[_m$ = m[1]] || (_sandbox$dbs3[_m$] = {});
          (_sandbox = sandbox).views || (_sandbox.views = {});
          (_sandbox$views2 = sandbox.views)[_m$2 = m[1]] || (_sandbox$views2[_m$2] = {});
          add({
            status: 'ok',
            message: `created_database(${m[1]})`
          });
        } else if (m = /^USE `?([\w$]+)`?$/i.exec(s)) {
          var _sandbox$dbs4, _m$3, _sandbox2, _sandbox$views3, _m$4;
          (_sandbox$dbs4 = sandbox.dbs)[_m$3 = m[1]] || (_sandbox$dbs4[_m$3] = {});
          (_sandbox2 = sandbox).views || (_sandbox2.views = {});
          (_sandbox$views3 = sandbox.views)[_m$4 = m[1]] || (_sandbox$views3[_m$4] = {});
          sandbox.currentDb = m[1];
          add({
            status: 'ok',
            message: `using_database(${m[1]})`
          });
        } else if (m = /^DROP DATABASE(?: IF EXISTS)? `?([\w$]+)`?$/i.exec(s)) {
          delete sandbox.dbs[m[1]];
          if (sandbox.views) delete sandbox.views[m[1]];
          if (sandbox.currentDb === m[1]) sandbox.currentDb = '';
          if (selectedTable && !currentRelation(selectedTable)) selectedTable = '';
          add({
            status: 'ok',
            message: `dropped_database(${m[1]})`
          });
        } else if (m = /^CREATE VIEW(?: IF NOT EXISTS)? `?([\w$]+)`? AS ([\s\S]+)$/i.exec(s)) {
          var _dbName2 = requireDb();
          if (_dbName2) {
            var _sandbox3, _sandbox$views4;
            (_sandbox3 = sandbox).views || (_sandbox3.views = {});
            (_sandbox$views4 = sandbox.views)[_dbName2] || (_sandbox$views4[_dbName2] = {});
            sandbox.views[_dbName2][m[1]] = {
              name: m[1],
              query: m[2],
              columns: [],
              rows: [],
              isView: true
            };
            add({
              status: 'ok',
              message: `created_view(${m[1]})`
            });
          }
        } else if (m = /^DROP VIEW(?: IF EXISTS)? `?([\w$]+)`?$/i.exec(s)) {
          var _dbName3 = requireDb();
          if (_dbName3) {
            var _sandbox$views5;
            (_sandbox$views5 = sandbox.views) === null || _sandbox$views5 === void 0 || (_sandbox$views5 = _sandbox$views5[_dbName3]) === null || _sandbox$views5 === void 0 || delete _sandbox$views5[m[1]];
            add({
              status: 'ok',
              message: `dropped_view(${m[1]})`
            });
          }
        } else if (m = /^DROP TABLE(?: IF EXISTS)? `?([\w$]+)`?$/i.exec(s)) {
          var _dbName4 = requireDb();
          if (_dbName4) {
            var db = sandbox.dbs[_dbName4] || {};
            delete db[m[1]];
            add({
              status: 'ok',
              message: `dropped_table(${m[1]})`
            });
          }
        } else if (m = /^TRUNCATE(?: TABLE)? `?([\w$]+)`?$/i.exec(s)) {
          var _dbName5 = requireDb();
          if (_dbName5) {
            var _sandbox$dbs$_dbName;
            var table = (_sandbox$dbs$_dbName = sandbox.dbs[_dbName5]) === null || _sandbox$dbs$_dbName === void 0 ? void 0 : _sandbox$dbs$_dbName[m[1]];
            if (table) table.rows = [];
            add({
              status: 'ok',
              message: `truncated_table(${m[1]})`
            });
          }
        } else if (m = /^CREATE TABLE(?: IF NOT EXISTS)? `?([\w$]+)`? \((.*)\)(?: .*)?$/i.exec(s)) {
          var _dbName6 = requireDb();
          if (_dbName6) {
            var _sandbox$dbs5;
            var _table = m[1];
            var cols = splitTopLevel(m[2]).map(function (x) {
              return x.trim();
            }).filter(Boolean).map(function (def) {
              var parts = def.split(/\s+/);
              return {
                name: parts[0].replace(/[`"]/g, ''),
                type: parts.slice(1).join(' ') || 'TEXT'
              };
            }).filter(function (c) {
              return !/^(primary|key|constraint|unique|index|foreign|check)$/i.test(c.name);
            });
            (_sandbox$dbs5 = sandbox.dbs)[_dbName6] || (_sandbox$dbs5[_dbName6] = {});
            sandbox.dbs[_dbName6][_table] = {
              columns: cols,
              rows: [],
              indexes: defaultIndexesForTable(_table, {
                columns: cols
              })
            };
            add({
              status: 'ok',
              message: `created_table(${_table})`
            });
          }
        } else if (m = /^ALTER\s+TABLE\s+`?([\w$]+)`?\s+([\s\S]+)$/i.exec(s)) {
          var _dbName7 = requireDb();
          if (!_dbName7) return 0; // continue
          var _table2 = m[1];
          var operations = splitTopLevel(m[2]).map(parseAlterOperation);
          var error = applySandboxAlter(sandbox.dbs[_dbName7] || {}, _table2, operations);
          if (error) add({
            status: 'error',
            message: error
          });else add({
            status: 'ok',
            message: `altered_table(${_table2})`
          });
        } else if (m = /^CREATE\s+(UNIQUE\s+)?INDEX\s+`?([\w$]+)`?\s+ON\s+`?([\w$]+)`?\s*\((.*?)\)$/i.exec(s)) {
          var _sandbox$dbs$_dbName2;
          var _dbName8 = requireDb();
          if (!_dbName8) return 0; // continue
          var _table3 = m[3];
          var _t3 = (_sandbox$dbs$_dbName2 = sandbox.dbs[_dbName8]) === null || _sandbox$dbs$_dbName2 === void 0 ? void 0 : _sandbox$dbs$_dbName2[_table3];
          if (!_t3) add({
            status: 'error',
            message: `table not found: ${_table3}`
          });else {
            _t3.indexes || (_t3.indexes = []);
            _t3.indexes = _t3.indexes.filter(function (index) {
              return index.name !== m[2];
            });
            _t3.indexes.push({
              name: m[2],
              columns: splitTopLevel(m[4]).map(function (x) {
                return x.trim().replace(/[`"]/g, '');
              }),
              unique: Boolean(m[1])
            });
            add({
              status: 'ok',
              message: `created_index(${m[2]},${_table3})`
            });
          }
        } else if (m = /^INSERT INTO `?([\w$]+)`?(?: \((.*?)\))? VALUES (.*)$/i.exec(s)) {
          var _sandbox$dbs$_dbName3;
          var _dbName9 = requireDb();
          if (!_dbName9) return 0; // continue
          var _table4 = m[1];
          var _t4 = (_sandbox$dbs$_dbName3 = sandbox.dbs[_dbName9]) === null || _sandbox$dbs$_dbName3 === void 0 ? void 0 : _sandbox$dbs$_dbName3[_table4];
          if (!_t4) {
            add({
              status: 'error',
              message: `table not found: ${_table4}`
            });
          } else {
            var _cols = m[2] ? splitTopLevel(m[2]).map(function (x) {
              return x.trim().replace(/[`"]/g, '');
            }) : _t4.columns.map(function (c) {
              return c.name;
            });
            var groups = splitValueGroups(m[3]);
            var _iterator18 = _createForOfIteratorHelper(groups),
              _step18;
            try {
              var _loop5 = function _loop5() {
                var group = _step18.value;
                var values = splitTopLevel(group).map(parseValue);
                var row = {};
                _cols.forEach(function (c, i) {
                  var _values$i;
                  return row[c] = (_values$i = values[i]) !== null && _values$i !== void 0 ? _values$i : null;
                });
                _t4.rows.push(row);
              };
              for (_iterator18.s(); !(_step18 = _iterator18.n()).done;) {
                _loop5();
              }
            } catch (err) {
              _iterator18.e(err);
            } finally {
              _iterator18.f();
            }
            add({
              status: 'ok',
              message: `inserted(${_table4},${groups.length})`
            });
          }
        } else if (m = /^SELECT \* FROM `?([\w$]+)`?(?: LIMIT (\d+))?$/i.exec(s)) {
          var _sandbox$dbs$_dbName4;
          var _dbName0 = requireDb();
          if (!_dbName0) return 0; // continue
          var _table5 = m[1];
          var _t5 = (_sandbox$dbs$_dbName4 = sandbox.dbs[_dbName0]) === null || _sandbox$dbs$_dbName4 === void 0 ? void 0 : _sandbox$dbs$_dbName4[_table5];
          if (!_t5) add({
            status: 'error',
            message: `table not found: ${_table5}`
          });else {
            var rows = (m[2] ? _t5.rows.slice(0, Number(m[2])) : _t5.rows).map(function (r) {
              return _t5.columns.map(function (c) {
                var _r$c$name;
                return (_r$c$name = r[c.name]) !== null && _r$c$name !== void 0 ? _r$c$name : null;
              });
            });
            add({
              status: 'table',
              columns: _t5.columns.map(function (c) {
                return c.name;
              }),
              rows
            });
          }
        } else if (m = /^DESCRIBE `?([\w$]+)`?$/i.exec(s)) {
          var _sandbox$dbs$_dbName5;
          var _dbName1 = requireDb();
          if (!_dbName1) return 0; // continue
          var _table6 = m[1];
          var _t6 = (_sandbox$dbs$_dbName5 = sandbox.dbs[_dbName1]) === null || _sandbox$dbs$_dbName5 === void 0 ? void 0 : _sandbox$dbs$_dbName5[_table6];
          if (!_t6) add({
            status: 'error',
            message: `table not found: ${_table6}`
          });else add({
            status: 'table',
            columns: ['Field', 'Type', 'Null', 'Key', 'Default', 'Extra'],
            rows: sandboxDescribeRows(_t6)
          });
        } else if (m = /^SHOW\s+(?:INDEX|INDEXES|KEYS)\s+FROM\s+`?([\w$]+)`?$/i.exec(s)) {
          var _sandbox$dbs$_dbName6;
          var _dbName10 = requireDb();
          if (!_dbName10) return 0; // continue
          var _table7 = m[1];
          var _t7 = (_sandbox$dbs$_dbName6 = sandbox.dbs[_dbName10]) === null || _sandbox$dbs$_dbName6 === void 0 ? void 0 : _sandbox$dbs$_dbName6[_table7];
          if (!_t7) add({
            status: 'error',
            message: `table not found: ${_table7}`
          });else {
            var _rows = (_t7.indexes || []).flatMap(function (index) {
              return (index.columns || []).map(function (column, i) {
                return [_table7, index.unique ? 0 : 1, index.name, i + 1, column];
              });
            });
            add({
              status: 'table',
              columns: ['table', 'non_unique', 'key_name', 'seq_in_index', 'column_name'],
              rows: _rows
            });
          }
        } else if (/^SHOW DATABASES$/i.test(s)) {
          add({
            status: 'table',
            columns: ['database'],
            rows: visibleDbNames().map(function (x) {
              return [x];
            })
          });
        } else if (/^SHOW TABLES$/i.test(s)) {
          var _dbName11 = requireDb();
          if (_dbName11) {
            var _sandbox$views6;
            var _db = sandbox.dbs[_dbName11] || {};
            var names = [].concat(_toConsumableArray(Object.keys(_db)), _toConsumableArray(Object.keys(((_sandbox$views6 = sandbox.views) === null || _sandbox$views6 === void 0 ? void 0 : _sandbox$views6[_dbName11]) || {}).filter(function (name) {
              return !_db[name];
            }))).sort(function (a, b) {
              return a.localeCompare(b);
            });
            add({
              status: 'table',
              columns: [`Tables_in_${_dbName11}`],
              rows: names.map(function (x) {
                return [x];
              })
            });
          }
        } else if (/^(START TRANSACTION|BEGIN|COMMIT|ROLLBACK)$/i.test(s)) {
          add({
            status: 'ok',
            message: s.toLowerCase().replace(/\s+/g, '_')
          });
        } else {
          add({
            status: 'error',
            message: `sandbox belum support: ${s}`
          });
        }
      },
      _ret2;
    for (_iterator17.s(); !(_step17 = _iterator17.n()).done;) {
      _ret2 = _loop4();
      if (_ret2 === 0) continue;
    }
  } catch (err) {
    _iterator17.e(err);
  } finally {
    _iterator17.f();
  }
  saveSandbox();
  renderTableBrowser();
  return {
    results
  };
}
function sandboxExecWithOptions(sql) {
  var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
  var all = [];
  var _iterator19 = _createForOfIteratorHelper(splitStatements(sql)),
    _step19;
  try {
    for (_iterator19.s(); !(_step19 = _iterator19.n()).done;) {
      var _data$results;
      var stmt = _step19.value;
      var data = sandboxExec(`${stmt};`);
      all.push.apply(all, _toConsumableArray(data.results || []));
      if (options.stopOnError && (_data$results = data.results) !== null && _data$results !== void 0 && _data$results.some(function (r) {
        return r.status === 'error';
      })) break;
    }
  } catch (err) {
    _iterator19.e(err);
  } finally {
    _iterator19.f();
  }
  return {
    results: options.showOnlyErrors ? all.filter(function (r) {
      return r.status === 'error';
    }) : all,
    allResults: all
  };
}
function setSqlRunBusy(busy) {
  runBtn.disabled = busy;
  runBtn.setAttribute('aria-busy', busy ? 'true' : 'false');
  runBtn.textContent = t(busy ? 'sql.running' : 'sql.run');
}
function runSql() {
  if (sqlRunPromise) return sqlRunPromise;
  stopAsaRunSounds();
  void primeAsaRunSounds();
  setSqlRunBusy(true);
  sqlRunPromise = runSqlOnce().finally(function () {
    sqlRunPromise = null;
    setSqlRunBusy(false);
  });
  return sqlRunPromise;
}
function runSqlOnce() {
  return _runSqlOnce.apply(this, arguments);
}
function _runSqlOnce() {
  _runSqlOnce = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee22() {
    var _ref0, _data$statementCount;
    var sql, metrics, plan, started, data, statementCount, _t22, _t23;
    return _regenerator().w(function (_context22) {
      while (1) switch (_context22.p = _context22.n) {
        case 0:
          if (!sqlEditorMetrics.large) applySqlAutoCorrection(true);
          sql = sqlInput.value;
          metrics = updateSqlEditor();
          clearTimeout(sqlAnalyzeTimer);
          sqlAnalyzeTimer = 0;
          sqlAnalyzeRequest += 1;
          if (metrics.large) setSqlDiagnostics([]);else setSqlDiagnostics(analyzeSqlClient(sql));
          plan = backendOnline ? createSqlExecutionPlan(sql) : null;
          _context22.n = 1;
          return new Promise(function (resolve) {
            return requestAnimationFrame(resolve);
          });
        case 1:
          started = performance.now();
          if (!backendOnline) {
            _context22.n = 9;
            break;
          }
          _context22.p = 2;
          if (!(plan.mode === 'reservoir')) {
            _context22.n = 4;
            break;
          }
          _context22.n = 3;
          return executeBackendSqlStreamed(sql, {
            stopOnError: true,
            onProgress: function onProgress(_ref9) {
              var completed = _ref9.completed,
                total = _ref9.total,
                statements = _ref9.statements;
              var percent = total ? Math.min(100, Math.round(completed / total * 100)) : 0;
              setLastRunKey('progress.importing', {
                percent,
                count: statements
              });
            }
          });
        case 3:
          _t22 = _context22.v;
          _context22.n = 6;
          break;
        case 4:
          _context22.n = 5;
          return executeBackendSql(sql, {
            sync: false
          });
        case 5:
          _t22 = _context22.v;
        case 6:
          data = _t22;
          _context22.n = 8;
          break;
        case 7:
          _context22.p = 7;
          _t23 = _context22.v;
          data = {
            results: [{
              status: 'error',
              message: `Backend Prolog gagal: ${_t23.message}`
            }]
          };
          log(t('log.backendFailed', {
            error: _t23.message
          }));
        case 8:
          _context22.n = 10;
          break;
        case 9:
          data = sandboxExec(sql);
        case 10:
          renderResults(data.results || [data], {
            sourceSql: sql
          });
          addRuntimeDiagnostics(data.results || [data]);
          playAsaRunSound(resultSetHasError(data) ? 'error' : 'ok');
          setLastRunRaw(`${Math.round(performance.now() - started)} ms`);
          statementCount = Number((_ref0 = (_data$statementCount = data.statementCount) !== null && _data$statementCount !== void 0 ? _data$statementCount : plan === null || plan === void 0 ? void 0 : plan.statementCount) !== null && _ref0 !== void 0 ? _ref0 : 0);
          log(statementCount > 0 ? t('result.executed', {
            count: formatNumber(statementCount)
          }) : t('result.completed'));
          _context22.n = 11;
          return refreshBrowserAfterRun(sql, data);
        case 11:
          return _context22.a(2);
      }
    }, _callee22, null, [[2, 7]]);
  }));
  return _runSqlOnce.apply(this, arguments);
}
function refreshBrowserAfterRun(_x13, _x14) {
  return _refreshBrowserAfterRun.apply(this, arguments);
}
function _refreshBrowserAfterRun() {
  _refreshBrowserAfterRun = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee23(sql, data) {
    var _yield$Promise$all, _yield$Promise$all2, synced;
    return _regenerator().w(function (_context23) {
      while (1) switch (_context23.n) {
        case 0:
          if (backendOnline) {
            _context23.n = 1;
            break;
          }
          renderTableBrowser();
          return _context23.a(2);
        case 1:
          _context23.n = 2;
          return Promise.all([syncCatalogFromBackend().catch(function (err) {
            log(t('log.postSyncSkipped', {
              error: err.message
            }));
            return false;
          }), refreshDatabaseMetadata().catch(function () {
            return null;
          })]);
        case 2:
          _yield$Promise$all = _context23.v;
          _yield$Promise$all2 = _slicedToArray(_yield$Promise$all, 1);
          synced = _yield$Promise$all2[0];
          if (!synced) log(t('log.postSyncUnavailable'));
          renderTableBrowser();
        case 3:
          return _context23.a(2);
      }
    }, _callee23);
  }));
  return _refreshBrowserAfterRun.apply(this, arguments);
}
function shouldBatchBackendSql(sql) {
  return String(sql || '').length > 180000 || splitStatementsDetailed(sql).length > 12;
}
function pageableResultSql(sql) {
  if (!sql) return '';
  try {
    var text = String(sql);
    return text.length <= 250000 && splitStatementsDetailed(text).length === 1 ? text : '';
  } catch (_) {
    return '';
  }
}
function resultPageOffsets(results, supplied) {
  return (results || []).map(function (result, index) {
    var _result$rows;
    var existing = Number(supplied === null || supplied === void 0 ? void 0 : supplied[index]);
    if (Number.isFinite(existing) && existing >= 0) return existing;
    return Number(result === null || result === void 0 || (_result$rows = result.rows) === null || _result$rows === void 0 ? void 0 : _result$rows.length) || 0;
  });
}
function loadMoreResultPage(_x15) {
  return _loadMoreResultPage.apply(this, arguments);
}
function _loadMoreResultPage() {
  _loadMoreResultPage = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee25(index) {
    var context, current, offset, pending;
    return _regenerator().w(function (_context25) {
      while (1) switch (_context25.n) {
        case 0:
          context = resultPageContext;
          current = lastRenderedResults[index];
          if (!(!(context !== null && context !== void 0 && context.sql) || !(current !== null && current !== void 0 && current.has_more) || resultPagePromises.has(index))) {
            _context25.n = 1;
            break;
          }
          return _context25.a(2);
        case 1:
          offset = context.offsets[index] || 0;
          pending = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee24() {
            var data, next, merged;
            return _regenerator().w(function (_context24) {
              while (1) switch (_context24.n) {
                case 0:
                  _context24.n = 1;
                  return executeBackendSqlPage(context.sql, offset);
                case 1:
                  data = _context24.v;
                  next = (data.results || [data])[index] || (data.results || [data]).find(function (item) {
                    return item.status === 'table';
                  });
                  if (!(!next || next.status !== 'table')) {
                    _context24.n = 2;
                    break;
                  }
                  throw new Error(t('result.previewMissing'));
                case 2:
                  merged = _toConsumableArray(lastRenderedResults);
                  merged[index] = _objectSpread(_objectSpread(_objectSpread({}, current), next), {}, {
                    rows: [].concat(_toConsumableArray(current.rows || []), _toConsumableArray(next.rows || [])),
                    returned_rows: (Number(current.returned_rows) || (current.rows || []).length) + (Number(next.returned_rows) || (next.rows || []).length)
                  });
                  context.offsets[index] = offset + (next.rows || []).length;
                  renderResults(merged, {
                    sourceSql: context.sql,
                    resultOffsets: context.offsets
                  });
                case 3:
                  return _context24.a(2);
              }
            }, _callee24);
          }))().catch(function (err) {
            log(`${t('result.loadingMore')} ${asaErrorCopy(err.message)}`);
          }).finally(function () {
            resultPagePromises.delete(index);
          });
          resultPagePromises.set(index, pending);
          _context25.n = 2;
          return pending;
        case 2:
          return _context25.a(2);
      }
    }, _callee25);
  }));
  return _loadMoreResultPage.apply(this, arguments);
}
function renderResults(results) {
  var _resultPageContext;
  var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
  var nextResults = Array.isArray(results) ? results : [];
  if (options.remember !== false) lastRenderedResults = _toConsumableArray(nextResults);
  var pageSql = pageableResultSql(options.sourceSql || (options.remember === false ? (_resultPageContext = resultPageContext) === null || _resultPageContext === void 0 ? void 0 : _resultPageContext.sql : ''));
  if (pageSql) {
    var _resultPageContext2;
    resultPageContext = {
      sql: pageSql,
      offsets: resultPageOffsets(nextResults, options.resultOffsets || ((_resultPageContext2 = resultPageContext) === null || _resultPageContext2 === void 0 ? void 0 : _resultPageContext2.offsets))
    };
  } else if (options.remember !== false) {
    resultPageContext = null;
    resultPagePromises.clear();
  }
  resultBox.innerHTML = '';
  var fragment = document.createDocumentFragment();
  var _iterator20 = _createForOfIteratorHelper(nextResults.entries()),
    _step20;
  try {
    var _loop6 = function _loop6() {
      var _step20$value = _slicedToArray(_step20.value, 2),
        resultIndex = _step20$value[0],
        r = _step20$value[1];
      var item = document.createElement('div');
      item.className = 'result-item';
      if (r.status === 'table') {
        var scroll = document.createElement('div');
        scroll.className = 'result-table-scroll';
        var table = renderTable(r.columns || [], r.rows || []);
        table.classList.add('result-data-table');
        scroll.appendChild(table);
        item.appendChild(scroll);
        if (r.has_more) {
          var _resultPageContext3;
          var note = document.createElement('div');
          note.className = 'result-page-note';
          note.textContent = t('result.rowsShown', {
            count: formatNumber(r.returned_rows || (r.rows || []).length)
          });
          item.appendChild(note);
          if ((_resultPageContext3 = resultPageContext) !== null && _resultPageContext3 !== void 0 && _resultPageContext3.sql) {
            var more = document.createElement('button');
            more.type = 'button';
            more.className = 'result-show-more';
            more.textContent = t('result.showMore');
            more.addEventListener('click', function () {
              more.disabled = true;
              more.textContent = t('result.loadingMore');
              loadMoreResultPage(resultIndex).finally(function () {
                if (more.isConnected) {
                  more.disabled = false;
                  more.textContent = t('result.showMore');
                }
              });
            });
            item.appendChild(more);
          }
        }
      } else if (r.status === 'ok') {
        item.innerHTML = `<div class="ok-text">${r.line ? `<span class="result-line">${escapeHtml(t('result.line'))} ${r.line}</span>` : ''}${escapeHtml(ASA_OK_LABEL)}: ${escapeHtml(asaResultCopy(r))}</div>`;
      } else {
        item.innerHTML = `<div class="error-text">${r.line ? `<span class="result-line">${escapeHtml(t('result.line'))} ${r.line}</span>` : ''}${escapeHtml(ASA_ERROR_LABEL)}: ${escapeHtml(asaResultCopy(r))}</div>`;
      }
      fragment.appendChild(item);
    };
    for (_iterator20.s(); !(_step20 = _iterator20.n()).done;) {
      _loop6();
    }
  } catch (err) {
    _iterator20.e(err);
  } finally {
    _iterator20.f();
  }
  resultBox.appendChild(fragment);
  if (options.archive !== false) noteArchiveQuery(results, (sqlInput === null || sqlInput === void 0 ? void 0 : sqlInput.value) || '');
}
function renderTable(columns, rows) {
  var table = document.createElement('table');
  table.innerHTML = `<thead><tr>${columns.map(function (c) {
    return `<th>${escapeHtml(c)}</th>`;
  }).join('')}</tr></thead>`;
  var tbody = document.createElement('tbody');
  var fragment = document.createDocumentFragment();
  var _iterator21 = _createForOfIteratorHelper(rows),
    _step21;
  try {
    for (_iterator21.s(); !(_step21 = _iterator21.n()).done;) {
      var row = _step21.value;
      var tr = document.createElement('tr');
      tr.innerHTML = row.map(function (v) {
        return `<td>${escapeHtml(v === null ? 'NULL' : String(v))}</td>`;
      }).join('');
      fragment.appendChild(tr);
    }
  } catch (err) {
    _iterator21.e(err);
  } finally {
    _iterator21.f();
  }
  tbody.appendChild(fragment);
  table.appendChild(tbody);
  return table;
}
function renderTableBrowser() {
  var _sandbox$views7, _tableListObserver;
  renderDbSelector();
  var activeDb = currentDbName();
  var db = activeDb ? sandbox.dbs[activeDb] || {} : {};
  var dbViews = activeDb ? ((_sandbox$views7 = sandbox.views) === null || _sandbox$views7 === void 0 ? void 0 : _sandbox$views7[activeDb]) || {} : {};
  var relations = [].concat(_toConsumableArray(Object.keys(db).map(function (name) {
    return {
      name,
      kind: 'table'
    };
  })), _toConsumableArray(Object.keys(dbViews).filter(function (name) {
    return !db[name];
  }).map(function (name) {
    return {
      name,
      kind: 'view'
    };
  }))).sort(function (a, b) {
    return a.name.localeCompare(b.name) || a.kind.localeCompare(b.kind);
  });
  var filter = tableSearch.value.trim().toLowerCase();
  var visible = relations.filter(function (item) {
    return item.name.toLowerCase().includes(filter);
  });
  tableCount.textContent = activeDb ? relationCountText(visible.length, relations.length, Object.keys(db).length, Object.keys(dbViews).length, filter) : t('database.noneSelected');
  (_tableListObserver = tableListObserver) === null || _tableListObserver === void 0 || _tableListObserver.disconnect();
  tableListObserver = null;
  tableList.innerHTML = '';
  var rendered = visible.slice(0, tableListVisibleLimit);
  var _iterator22 = _createForOfIteratorHelper(rendered),
    _step22;
  try {
    for (_iterator22.s(); !(_step22 = _iterator22.n()).done;) {
      var item = _step22.value;
      var row = document.createElement('div');
      row.className = `table-row ${item.kind}-row`;
      var button = document.createElement('button');
      button.type = 'button';
      button.className = `table-link${item.kind === 'view' ? ' view-link' : ''}${item.name === selectedTable ? ' active' : ''}`;
      button.dataset.table = item.name;
      button.dataset.kind = item.kind;
      button.innerHTML = `<span class="${item.kind === 'view' ? 'view-icon' : 'table-icon'}" aria-hidden="true"></span><span class="table-name">${escapeHtml(item.name)}</span>${item.kind === 'view' ? '<span class="relation-badge">VIEW</span>' : ''}`;
      var drop = document.createElement('button');
      drop.type = 'button';
      drop.className = 'drop-table-button';
      drop.dataset.dropTable = item.name;
      drop.dataset.kind = item.kind;
      var kindLabel = localizedRelationKind(item.kind);
      drop.title = t('table.dropNamed', {
        kind: kindLabel,
        name: item.name
      });
      drop.setAttribute('aria-label', t('table.dropNamed', {
        kind: kindLabel,
        name: item.name
      }));
      drop.innerHTML = '<span class="drop-icon" aria-hidden="true"></span>';
      row.append(button, drop);
      tableList.appendChild(row);
    }
  } catch (err) {
    _iterator22.e(err);
  } finally {
    _iterator22.f();
  }
  if (visible.length > rendered.length) {
    var more = document.createElement('button');
    more.type = 'button';
    more.className = 'table-show-more';
    more.textContent = t('table.showMore');
    more.title = t('table.tablesShown', {
      shown: formatNumber(rendered.length),
      total: formatNumber(visible.length)
    });
    more.addEventListener('click', function () {
      tableListVisibleLimit += TABLE_LIST_PAGE_SIZE;
      renderTableBrowser();
    });
    tableList.appendChild(more);
    if ('IntersectionObserver' in window) {
      tableListObserver = new IntersectionObserver(function (entries) {
        if (entries.some(function (entry) {
          return entry.isIntersecting;
        })) {
          tableListVisibleLimit += TABLE_LIST_PAGE_SIZE;
          renderTableBrowser();
        }
      }, {
        root: null,
        rootMargin: '80px'
      });
      tableListObserver.observe(more);
    }
  }
  renderExportTablePicker();
  updateArchiveMonitor();
}
function relationCountText(visibleCount, totalCount, tableCountValue, viewCount, filter) {
  if (filter) return t('table.countFiltered', {
    visible: formatNumber(visibleCount),
    total: formatNumber(totalCount)
  });
  return viewCount ? t('table.countViews', {
    tables: formatNumber(tableCountValue),
    views: formatNumber(viewCount)
  }) : t('table.count', {
    count: formatNumber(tableCountValue)
  });
}
function renderDbSelector() {
  var names = visibleDbNames();
  var activeDb = currentDbName();
  dbSelect.innerHTML = `<option value="">${escapeHtml(t('database.select'))}</option>` + names.map(function (name) {
    return `<option value="${escapeHtml(name)}">${escapeHtml(name)}</option>`;
  }).join('');
  dbSelect.value = activeDb && names.includes(activeDb) ? activeDb : '';
  dbName.value = activeDb || '';
}
function renderExportTablePicker() {
  if (!exportTableRows) return;
  var current = collectExportSelections();
  var activeDb = currentDbName();
  var db = activeDb ? sandbox.dbs[activeDb] || {} : {};
  var tables = Object.keys(db).sort(function (a, b) {
    return a.localeCompare(b);
  });
  exportDbName.textContent = activeDb || t('database.noneSelected');
  exportTableRows.innerHTML = '';
  var _iterator23 = _createForOfIteratorHelper(tables),
    _step23;
  try {
    for (_iterator23.s(); !(_step23 = _iterator23.n()).done;) {
      var _current$tables$table, _current$data$table;
      var table = _step23.value;
      var row = document.createElement('tr');
      var tableChecked = (_current$tables$table = current.tables[table]) !== null && _current$tables$table !== void 0 ? _current$tables$table : true;
      var dataChecked = (_current$data$table = current.data[table]) !== null && _current$data$table !== void 0 ? _current$data$table : true;
      row.innerHTML = `
      <td><label><input class="export-table-check" data-table="${escapeHtml(table)}" type="checkbox" ${tableChecked ? 'checked' : ''} /> ${escapeHtml(table)}</label></td>
      <td><input class="export-data-check" data-table="${escapeHtml(table)}" type="checkbox" ${dataChecked ? 'checked' : ''} /></td>
    `;
      exportTableRows.appendChild(row);
    }
  } catch (err) {
    _iterator23.e(err);
  } finally {
    _iterator23.f();
  }
}
function collectExportSelections() {
  var tables = {};
  var data = {};
  document.querySelectorAll('.export-table-check').forEach(function (input) {
    return tables[input.dataset.table] = input.checked;
  });
  document.querySelectorAll('.export-data-check').forEach(function (input) {
    return data[input.dataset.table] = input.checked;
  });
  return {
    tables,
    data
  };
}
function getExportSelection() {
  var activeDb = currentDbName();
  var db = activeDb ? sandbox.dbs[activeDb] || {} : {};
  var checked = collectExportSelections();
  var includeDataGlobally = exportDataMode.value !== 'none';
  var includeSchema = exportTableMode.value !== 'none';
  return Object.keys(db).filter(function (table) {
    var _checked$tables$table;
    return (_checked$tables$table = checked.tables[table]) !== null && _checked$tables$table !== void 0 ? _checked$tables$table : true;
  }).map(function (table) {
    var _checked$data$table;
    return {
      name: table,
      table: db[table],
      includeData: includeDataGlobally && ((_checked$data$table = checked.data[table]) !== null && _checked$data$table !== void 0 ? _checked$data$table : true),
      includeSchema
    };
  });
}
function escapeHtml(s) {
  return String(s).replace(/[&<>'"]/g, function (ch) {
    return {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      "'": '&#39;',
      '"': '&quot;'
    }[ch];
  });
}
function createDatabase() {
  return _createDatabase.apply(this, arguments);
}
function _createDatabase() {
  _createDatabase = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee26() {
    var _sandbox$dbs8, _sandbox5, _sandbox$views0;
    var nextDb, sql, data, _t24;
    return _regenerator().w(function (_context26) {
      while (1) switch (_context26.p = _context26.n) {
        case 0:
          nextDb = sanitizeIdentifier(dbName.value);
          if (nextDb) {
            _context26.n = 1;
            break;
          }
          log(t('log.databaseNameEmpty'));
          return _context26.a(2);
        case 1:
          sql = `CREATE DATABASE IF NOT EXISTS ${quoteIdent(nextDb)};\nUSE ${quoteIdent(nextDb)};`;
          setSqlText(sql);
          if (!backendOnline) {
            _context26.n = 6;
            break;
          }
          _context26.p = 2;
          _context26.n = 3;
          return executeBackendSql(sql);
        case 3:
          data = _context26.v;
          if (!hasResultError(data)) {
            _context26.n = 4;
            break;
          }
          renderResults(data.results || [data]);
          return _context26.a(2);
        case 4:
          log(t('log.databaseCreated', {
            name: nextDb
          }));
          _context26.n = 6;
          break;
        case 5:
          _context26.p = 5;
          _t24 = _context26.v;
          backendOnline = false;
          engineCheckCompleted = true;
          updateEngineStatus();
          log(t('log.databaseCreateFallback', {
            error: _t24.message
          }));
        case 6:
          if (!data) data = sandboxExec(sql);
          renderResults(data.results || [data]);
          if (!hasResultError(data)) {
            _context26.n = 7;
            break;
          }
          return _context26.a(2);
        case 7:
          sandbox.currentDb = nextDb;
          (_sandbox$dbs8 = sandbox.dbs)[nextDb] || (_sandbox$dbs8[nextDb] = {});
          (_sandbox5 = sandbox).views || (_sandbox5.views = {});
          (_sandbox$views0 = sandbox.views)[nextDb] || (_sandbox$views0[nextDb] = {});
          saveSandbox();
          selectedTable = '';
          renderTableBrowser();
          showView('sql');
        case 8:
          return _context26.a(2);
      }
    }, _callee26, null, [[2, 5]]);
  }));
  return _createDatabase.apply(this, arguments);
}
function selectDatabaseByName(_x16) {
  return _selectDatabaseByName.apply(this, arguments);
}
function _selectDatabaseByName() {
  _selectDatabaseByName = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee27(nextDb) {
    var _sandbox$views1, _sandbox$dbs9, _sandbox6, _sandbox$views10;
    var sql, data, _t25;
    return _regenerator().w(function (_context27) {
      while (1) switch (_context27.p = _context27.n) {
        case 0:
          if (!(!nextDb || !sandbox.dbs[nextDb] && !((_sandbox$views1 = sandbox.views) !== null && _sandbox$views1 !== void 0 && _sandbox$views1[nextDb]))) {
            _context27.n = 1;
            break;
          }
          return _context27.a(2);
        case 1:
          sql = `USE ${quoteIdent(nextDb)};`;
          if (!backendOnline) {
            _context27.n = 6;
            break;
          }
          _context27.p = 2;
          _context27.n = 3;
          return executeBackendSql(sql);
        case 3:
          data = _context27.v;
          if (!hasResultError(data)) {
            _context27.n = 4;
            break;
          }
          renderResults(data.results || [data]);
          renderTableBrowser();
          return _context27.a(2);
        case 4:
          _context27.n = 6;
          break;
        case 5:
          _context27.p = 5;
          _t25 = _context27.v;
          backendOnline = false;
          engineCheckCompleted = true;
          updateEngineStatus();
          log(t('log.databaseSelectFallback', {
            error: _t25.message
          }));
        case 6:
          sandbox.currentDb = nextDb;
          (_sandbox$dbs9 = sandbox.dbs)[nextDb] || (_sandbox$dbs9[nextDb] = {});
          (_sandbox6 = sandbox).views || (_sandbox6.views = {});
          (_sandbox$views10 = sandbox.views)[nextDb] || (_sandbox$views10[nextDb] = {});
          selectedTable = '';
          saveSandbox();
          renderTableBrowser();
          log(t('log.databaseSelected', {
            name: nextDb
          }));
        case 7:
          return _context27.a(2);
      }
    }, _callee27, null, [[2, 5]]);
  }));
  return _selectDatabaseByName.apply(this, arguments);
}
function saveCurrentDatabase() {
  return _saveCurrentDatabase.apply(this, arguments);
}
function _saveCurrentDatabase() {
  _saveCurrentDatabase = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee28() {
    var db, data, _t26;
    return _regenerator().w(function (_context28) {
      while (1) switch (_context28.p = _context28.n) {
        case 0:
          db = ensureCurrentDb('save database');
          if (db) {
            _context28.n = 1;
            break;
          }
          return _context28.a(2);
        case 1:
          data = null;
          if (!backendOnline) {
            _context28.n = 6;
            break;
          }
          _context28.p = 2;
          _context28.n = 3;
          return saveBackendDatabase();
        case 3:
          data = _context28.v;
          _context28.n = 4;
          return syncBackendStateSmart();
        case 4:
          _context28.n = 6;
          break;
        case 5:
          _context28.p = 5;
          _t26 = _context28.v;
          backendOnline = false;
          engineCheckCompleted = true;
          updateEngineStatus();
          log(t('log.databaseSaveFallback', {
            error: _t26.message
          }));
        case 6:
          saveSandbox();
          if (!data) data = {
            results: [{
              status: 'ok',
              message: `saved_database(${db})`
            }]
          };
          renderResults(data.results || [data]);
          renderTableBrowser();
          log(t('log.databaseSaved', {
            name: db
          }));
        case 7:
          return _context28.a(2);
      }
    }, _callee28, null, [[2, 5]]);
  }));
  return _saveCurrentDatabase.apply(this, arguments);
}
function dropCurrentDatabase() {
  return _dropCurrentDatabase.apply(this, arguments);
}
function _dropCurrentDatabase() {
  _dropCurrentDatabase = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee29() {
    var db, sql, data, droppedOnBackend, _t27, _t28;
    return _regenerator().w(function (_context29) {
      while (1) switch (_context29.p = _context29.n) {
        case 0:
          db = ensureCurrentDb('drop database');
          if (db) {
            _context29.n = 1;
            break;
          }
          return _context29.a(2);
        case 1:
          if (confirm(t('confirm.dropDatabase', {
            name: db
          }))) {
            _context29.n = 2;
            break;
          }
          return _context29.a(2);
        case 2:
          sql = `DROP DATABASE ${quoteIdent(db)};`;
          setSqlText(sql);
          droppedOnBackend = false;
          if (!backendOnline) {
            _context29.n = 6;
            break;
          }
          _context29.p = 3;
          _context29.n = 4;
          return executeBackendSql(sql, {
            sync: false
          });
        case 4:
          data = _context29.v;
          droppedOnBackend = true;
          _context29.n = 6;
          break;
        case 5:
          _context29.p = 5;
          _t27 = _context29.v;
          backendOnline = false;
          engineCheckCompleted = true;
          updateEngineStatus();
          log(t('log.dropBackendFallback', {
            error: _t27.message
          }));
        case 6:
          if (!data) data = sandboxExec(sql);
          renderResults(data.results || [data]);
          if (!hasResultError(data)) {
            _context29.n = 7;
            break;
          }
          log(t('log.dropFailed', {
            kind: t('common.database'),
            name: db
          }));
          return _context29.a(2);
        case 7:
          if (!droppedOnBackend) {
            _context29.n = 12;
            break;
          }
          _context29.p = 8;
          _context29.n = 9;
          return backendListContains('SHOW DATABASES;', db);
        case 9:
          if (!_context29.v) {
            _context29.n = 10;
            break;
          }
          log(t('log.dropFailed', {
            kind: t('common.database'),
            name: db
          }));
          return _context29.a(2);
        case 10:
          _context29.n = 12;
          break;
        case 11:
          _context29.p = 11;
          _t28 = _context29.v;
          log(`${t('log.dropVerifyFailed', {
            kind: t('common.database'),
            name: db
          })} ${_t28.message}`);
          return _context29.a(2);
        case 12:
          delete sandbox.dbs[db];
          if (sandbox.views) delete sandbox.views[db];
          if (sandbox.currentDb === db) sandbox.currentDb = '';
          selectedTable = '';
          saveSandbox();
          if (!droppedOnBackend) {
            _context29.n = 13;
            break;
          }
          _context29.n = 13;
          return syncCatalogFromBackend().catch(function () {
            return false;
          });
        case 13:
          renderTableBrowser();
          showView('sql');
          log(t('log.dropped', {
            kind: t('common.database'),
            name: db
          }));
        case 14:
          return _context29.a(2);
      }
    }, _callee29, null, [[8, 11], [3, 5]]);
  }));
  return _dropCurrentDatabase.apply(this, arguments);
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
function dropTable(_x17) {
  return _dropTable.apply(this, arguments);
}
function _dropTable() {
  _dropTable = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee30(tableName) {
    var _sandbox$views11, _sandbox$dbs$db;
    var db, relation, kind, kindLabel, sql, data, droppedOnBackend, _t29, _t30;
    return _regenerator().w(function (_context30) {
      while (1) switch (_context30.p = _context30.n) {
        case 0:
          db = ensureCurrentDb('drop table');
          if (!(!db || !tableName)) {
            _context30.n = 1;
            break;
          }
          return _context30.a(2);
        case 1:
          relation = currentRelation(tableName);
          kind = (relation === null || relation === void 0 ? void 0 : relation.kind) || 'table';
          kindLabel = localizedRelationKind(kind);
          if (confirm(t('confirm.dropTable', {
            kind: kindLabel,
            name: tableName,
            db
          }))) {
            _context30.n = 2;
            break;
          }
          return _context30.a(2);
        case 2:
          sql = kind === 'view' ? `DROP VIEW IF EXISTS ${quoteIdent(tableName)};` : `DROP TABLE IF EXISTS ${quoteIdent(tableName)};`;
          droppedOnBackend = false;
          if (!backendOnline) {
            _context30.n = 6;
            break;
          }
          _context30.p = 3;
          _context30.n = 4;
          return executeBackendSql(sql, {
            sync: false
          });
        case 4:
          data = _context30.v;
          droppedOnBackend = true;
          _context30.n = 6;
          break;
        case 5:
          _context30.p = 5;
          _t29 = _context30.v;
          backendOnline = false;
          engineCheckCompleted = true;
          updateEngineStatus();
          log(t('log.dropBackendFallback', {
            error: _t29.message
          }));
        case 6:
          if (!data) data = sandboxExec(sql);
          renderResults(data.results || [data]);
          if (!hasResultError(data)) {
            _context30.n = 7;
            break;
          }
          log(t('log.dropFailed', {
            kind: kindLabel,
            name: tableName
          }));
          return _context30.a(2);
        case 7:
          if (!droppedOnBackend) {
            _context30.n = 12;
            break;
          }
          _context30.p = 8;
          _context30.n = 9;
          return backendListContains('SHOW TABLES;', tableName);
        case 9:
          if (!_context30.v) {
            _context30.n = 10;
            break;
          }
          log(t('log.dropFailed', {
            kind: kindLabel,
            name: tableName
          }));
          return _context30.a(2);
        case 10:
          _context30.n = 12;
          break;
        case 11:
          _context30.p = 11;
          _t30 = _context30.v;
          log(`${t('log.dropVerifyFailed', {
            kind: kindLabel,
            name: tableName
          })} ${_t30.message}`);
          return _context30.a(2);
        case 12:
          if (kind === 'view') (_sandbox$views11 = sandbox.views) === null || _sandbox$views11 === void 0 || (_sandbox$views11 = _sandbox$views11[db]) === null || _sandbox$views11 === void 0 || delete _sandbox$views11[tableName];else (_sandbox$dbs$db = sandbox.dbs[db]) === null || _sandbox$dbs$db === void 0 || delete _sandbox$dbs$db[tableName];
          if (selectedTable === tableName) selectedTable = '';
          saveSandbox();
          if (!droppedOnBackend) {
            _context30.n = 13;
            break;
          }
          _context30.n = 13;
          return syncCatalogFromBackend().catch(function () {
            return false;
          });
        case 13:
          renderTableBrowser();
          if (currentViewName === 'table' && !selectedTable) showView('sql');
          log(t('log.dropped', {
            kind: kindLabel,
            name: tableName
          }));
        case 14:
          return _context30.a(2);
      }
    }, _callee30, null, [[8, 11], [3, 5]]);
  }));
  return _dropTable.apply(this, arguments);
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
  addCreateColumnRow({
    name: '',
    type: 'int',
    length: '',
    options: '',
    nullable: false,
    autoIncrement: false
  });
  showView('create', 'create');
  createTableName.focus();
}
function renderTableDetail(tableName) {
  var mode = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : 'structure';
  var relation = currentRelation(tableName);
  if (!relation) return;
  var table = relation.value;
  tableDetailRequestId += 1;
  tableDataPageState = null;
  selectedTable = tableName;
  currentTableDetailMode = mode;
  tableDetailName.textContent = relation.kind === 'view' ? `${tableName} (${t('table.view')})` : tableName;
  tableStructurePanel.hidden = mode !== 'structure';
  tableDataPanel.hidden = mode !== 'data';
  tableSelectDataBtn.classList.toggle('strong', mode === 'data');
  tableShowStructureBtn.classList.toggle('strong', mode === 'structure');
  tableAlterBtn.disabled = relation.kind === 'view';
  tableNewItemBtn.disabled = relation.kind === 'view';
  if (relation.kind === 'view') {
    if (mode === 'data') renderViewDataDetail(tableName);else renderViewStructureDetail(tableName, table);
  } else if (mode === 'data') renderTableDataDetail(tableName, table);else renderTableStructureDetail(tableName, table);
  showView('table', `table=${encodeURIComponent(tableName)}`);
}
function currentTable(tableName) {
  var _sandbox$dbs$activeDb;
  var activeDb = currentDbName();
  return activeDb ? ((_sandbox$dbs$activeDb = sandbox.dbs[activeDb]) === null || _sandbox$dbs$activeDb === void 0 ? void 0 : _sandbox$dbs$activeDb[tableName]) || null : null;
}
function currentView(viewName) {
  var _sandbox$views8;
  var activeDb = currentDbName();
  return activeDb ? ((_sandbox$views8 = sandbox.views) === null || _sandbox$views8 === void 0 || (_sandbox$views8 = _sandbox$views8[activeDb]) === null || _sandbox$views8 === void 0 ? void 0 : _sandbox$views8[viewName]) || null : null;
}
function currentRelation(name) {
  var table = currentTable(name);
  if (table) return {
    kind: 'table',
    value: table
  };
  var view = currentView(name);
  if (view) return {
    kind: 'view',
    value: view
  };
  return null;
}
function renderViewStructureDetail(viewName, view) {
  tableStructureBody.innerHTML = `
    <tr>
      <td>${escapeHtml(viewName)}</td>
      <td>VIEW</td>
      <td>${escapeHtml(view.query || t('table.viewDescription'))}</td>
    </tr>
  `;
  tableIndexBody.innerHTML = `<tr><td>VIEW</td><td class="index-column">${escapeHtml(t('table.virtualResult'))}</td></tr>`;
}
function renderViewDataDetail(_x18) {
  return _renderViewDataDetail.apply(this, arguments);
}
function _renderViewDataDetail() {
  _renderViewDataDetail = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee31(viewName) {
    return _regenerator().w(function (_context31) {
      while (1) switch (_context31.n) {
        case 0:
          if (backendOnline) {
            _context31.n = 1;
            break;
          }
          tableDataBox.innerHTML = `<div class="empty-state">${escapeHtml(t('table.viewNeedsBackend'))}</div>`;
          return _context31.a(2);
        case 1:
          tableDataPageState = {
            sql: `SELECT * FROM ${quoteIdent(viewName)};`,
            columns: [],
            rows: [],
            offset: 0,
            total: 0,
            hasMore: true,
            loading: false,
            loadingLabel: t('table.loadingView')
          };
          _context31.n = 2;
          return loadTableDataPage(tableDataPageState, tableDetailRequestId);
        case 2:
          return _context31.a(2);
      }
    }, _callee31);
  }));
  return _renderViewDataDetail.apply(this, arguments);
}
function renderTableStructureDetail(tableName, table) {
  var _table$indexes;
  tableStructureBody.innerHTML = '';
  var _iterator24 = _createForOfIteratorHelper(table.columns || []),
    _step24;
  try {
    for (_iterator24.s(); !(_step24 = _iterator24.n()).done;) {
      var column = _step24.value;
      var row = document.createElement('tr');
      row.innerHTML = `
      <td>${escapeHtml(column.name)}</td>
      <td>${columnTypeHtml(column)}</td>
      <td>${escapeHtml(column.comment || '')}</td>
    `;
      tableStructureBody.appendChild(row);
    }
  } catch (err) {
    _iterator24.e(err);
  } finally {
    _iterator24.f();
  }
  var indexes = (_table$indexes = table.indexes) !== null && _table$indexes !== void 0 && _table$indexes.length ? table.indexes : defaultIndexesForTable(tableName, table);
  tableIndexBody.innerHTML = '';
  var _iterator25 = _createForOfIteratorHelper(indexes),
    _step25;
  try {
    for (_iterator25.s(); !(_step25 = _iterator25.n()).done;) {
      var index = _step25.value;
      var _row5 = document.createElement('tr');
      _row5.innerHTML = `
      <td>${escapeHtml(index.name || 'INDEX')}</td>
      <td class="index-column">${escapeHtml((index.columns || []).join(', '))}</td>
    `;
      tableIndexBody.appendChild(_row5);
    }
  } catch (err) {
    _iterator25.e(err);
  } finally {
    _iterator25.f();
  }
}
function renderTableDataDetail(_x19, _x20) {
  return _renderTableDataDetail.apply(this, arguments);
}
function _renderTableDataDetail() {
  _renderTableDataDetail = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee32(tableName, table) {
    var columns, localRows, remoteRows, rows, tableNode;
    return _regenerator().w(function (_context32) {
      while (1) switch (_context32.n) {
        case 0:
          columns = (table.columns || []).map(function (col) {
            return col.name;
          });
          localRows = (table.rows || []).map(function (row) {
            return columns.map(function (column) {
              var _row$column3;
              return (_row$column3 = row[column]) !== null && _row$column3 !== void 0 ? _row$column3 : null;
            });
          });
          remoteRows = Number(table.rowCount) || 0;
          if (!(backendOnline && remoteRows > localRows.length)) {
            _context32.n = 2;
            break;
          }
          tableDataPageState = {
            sql: `SELECT * FROM ${quoteIdent(tableName)};`,
            columns,
            rows: [],
            offset: 0,
            total: remoteRows,
            hasMore: true,
            loading: false,
            loadingLabel: t('table.loadingPreview')
          };
          _context32.n = 1;
          return loadTableDataPage(tableDataPageState, tableDetailRequestId);
        case 1:
          return _context32.a(2);
        case 2:
          tableDataBox.innerHTML = '';
          rows = localRows;
          tableNode = renderTable(columns, rows);
          tableNode.classList.add('legacy-data-table');
          tableDataBox.appendChild(tableNode);
        case 3:
          return _context32.a(2);
      }
    }, _callee32);
  }));
  return _renderTableDataDetail.apply(this, arguments);
}
function renderTableDataPage(state) {
  if (!state || state !== tableDataPageState) return;
  tableDataBox.innerHTML = '';
  if (state.loading && !state.rows.length) {
    tableDataBox.innerHTML = `<div class="empty-state">${escapeHtml(state.loadingLabel || t('table.loadingMore'))}</div>`;
  } else {
    var tableNode = renderTable(state.columns || [], state.rows || []);
    tableNode.classList.add('legacy-data-table');
    tableDataBox.appendChild(tableNode);
  }
  if (state.total > 0 && state.rows.length > 0) {
    var note = document.createElement('div');
    note.className = 'empty-state table-page-note';
    note.textContent = state.hasMore ? t('table.showingRows', {
      shown: formatNumber(state.rows.length),
      total: formatNumber(state.total)
    }) : t('result.allRows', {
      count: formatNumber(state.rows.length)
    });
    tableDataBox.appendChild(note);
  }
  if (state.hasMore && !state.loading) {
    var more = document.createElement('button');
    more.type = 'button';
    more.className = 'table-show-more';
    more.textContent = t('table.showMore');
    more.addEventListener('click', function () {
      return loadTableDataPage(state, state.requestId);
    });
    tableDataBox.appendChild(more);
  }
}
function loadTableDataPage(_x21) {
  return _loadTableDataPage.apply(this, arguments);
}
function _loadTableDataPage() {
  _loadTableDataPage = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee33(state) {
    var requestId,
      _state$rows,
      data,
      result,
      _args33 = arguments,
      _t31,
      _t32;
    return _regenerator().w(function (_context33) {
      while (1) switch (_context33.p = _context33.n) {
        case 0:
          requestId = _args33.length > 1 && _args33[1] !== undefined ? _args33[1] : tableDetailRequestId;
          if (!(!state || state !== tableDataPageState || state.loading || requestId !== tableDetailRequestId)) {
            _context33.n = 1;
            break;
          }
          return _context33.a(2);
        case 1:
          state.loading = true;
          state.requestId = requestId;
          renderTableDataPage(state);
          _context33.p = 2;
          if (!(state.offset > 0)) {
            _context33.n = 4;
            break;
          }
          _context33.n = 3;
          return executeBackendSqlPage(state.sql, state.offset);
        case 3:
          _t31 = _context33.v;
          _context33.n = 6;
          break;
        case 4:
          _context33.n = 5;
          return executeBackendSql(state.sql, {
            sync: false
          });
        case 5:
          _t31 = _context33.v;
        case 6:
          data = _t31;
          result = (data.results || [data]).find(function (item) {
            return item.status === 'table';
          });
          if (result) {
            _context33.n = 7;
            break;
          }
          throw new Error(data.message || t('result.previewMissing'));
        case 7:
          if (!(requestId !== tableDetailRequestId || state !== tableDataPageState)) {
            _context33.n = 8;
            break;
          }
          return _context33.a(2);
        case 8:
          state.columns = result.columns || state.columns;
          (_state$rows = state.rows).push.apply(_state$rows, _toConsumableArray(result.rows || []));
          state.offset += (result.rows || []).length;
          state.hasMore = Boolean(result.has_more) || state.total > 0 && state.offset < state.total;
          _context33.n = 10;
          break;
        case 9:
          _context33.p = 9;
          _t32 = _context33.v;
          if (requestId === tableDetailRequestId && state === tableDataPageState) {
            tableDataBox.innerHTML = `<div class="empty-state error-text">${escapeHtml(ASA_ERROR_LABEL)}: ${escapeHtml(asaErrorCopy(_t32.message))}</div>`;
          }
          return _context33.a(2);
        case 10:
          _context33.p = 10;
          state.loading = false;
          return _context33.f(10);
        case 11:
          renderTableDataPage(state);
        case 12:
          return _context33.a(2);
      }
    }, _callee33, null, [[2, 9, 10, 11]]);
  }));
  return _loadTableDataPage.apply(this, arguments);
}
function columnTypeHtml(column) {
  var _column$default;
  var bits = [escapeHtml(column.type || 'TEXT')];
  if (column.extra) bits.push(`<em>${escapeHtml(column.extra)}</em>`);
  if (Object.prototype.hasOwnProperty.call(column, 'default')) bits.push(`[${escapeHtml((_column$default = column.default) !== null && _column$default !== void 0 ? _column$default : '')}]`);
  return bits.join(' ');
}
function defaultIndexesForTable(tableName, table) {
  var columns = table.columns || [];
  if (!columns.length) return [];
  var first = columns[0].name;
  var indexes = [{
    name: 'PRIMARY',
    columns: [first]
  }];
  var visible = columns.find(function (col) {
    return /visible|status|slug|name/i.test(col.name);
  });
  if (visible && visible.name !== first) indexes.push({
    name: 'INDEX',
    columns: [visible.name]
  });
  return indexes;
}
function addCreateColumnRow() {
  var column = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var row = document.createElement('tr');
  row.innerHTML = `
    <td><input class="create-col-name" value="${escapeHtml(column.name || '')}" /></td>
    <td>
      <select class="create-col-type">
        ${['int', 'bigint', 'varchar', 'text', 'mediumtext', 'datetime', 'decimal'].map(function (type) {
    return `<option value="${type}" ${type === (column.type || 'int') ? 'selected' : ''}>${type}</option>`;
  }).join('')}
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
      <button class="mini-button create-row-add" type="button" title="${escapeHtml(t('table.addColumn'))}" aria-label="${escapeHtml(t('table.addColumn'))}">+</button>
      <button class="mini-button create-row-up" type="button" title="${escapeHtml(t('table.moveUp'))}" aria-label="${escapeHtml(t('table.moveUp'))}">&uarr;</button>
      <button class="mini-button create-row-down" type="button" title="${escapeHtml(t('table.moveDown'))}" aria-label="${escapeHtml(t('table.moveDown'))}">&darr;</button>
      <button class="mini-button create-row-delete" type="button" title="${escapeHtml(t('table.deleteColumn'))}" aria-label="${escapeHtml(t('table.deleteColumn'))}">x</button>
    </td>
  `;
  createColumnsBody.appendChild(row);
}
function saveCreateTable(_x22) {
  return _saveCreateTable.apply(this, arguments);
}
function _saveCreateTable() {
  _saveCreateTable = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee34(event) {
    var _sandbox$dbs0;
    var activeDb, tableName, columns, indexes, _i17, _Array$from3, _row$querySelector, _row$querySelector2, _row$querySelector3, _row$querySelector4, _row$querySelector5, _row$querySelector6, row, name, type, length, option, nullable, autoIncrement, typeText, column, tableRecord, createSql, data, _t33;
    return _regenerator().w(function (_context34) {
      while (1) switch (_context34.p = _context34.n) {
        case 0:
          event.preventDefault();
          activeDb = ensureCurrentDb('create table');
          if (activeDb) {
            _context34.n = 1;
            break;
          }
          return _context34.a(2);
        case 1:
          tableName = sanitizeIdentifier(createTableName.value);
          if (tableName) {
            _context34.n = 2;
            break;
          }
          log(t('log.tableNameEmpty'));
          return _context34.a(2);
        case 2:
          columns = [];
          indexes = [];
          _i17 = 0, _Array$from3 = Array.from(createColumnsBody.querySelectorAll('tr'));
        case 3:
          if (!(_i17 < _Array$from3.length)) {
            _context34.n = 6;
            break;
          }
          row = _Array$from3[_i17];
          name = sanitizeIdentifier((_row$querySelector = row.querySelector('.create-col-name')) === null || _row$querySelector === void 0 ? void 0 : _row$querySelector.value);
          if (name) {
            _context34.n = 4;
            break;
          }
          return _context34.a(3, 5);
        case 4:
          type = ((_row$querySelector2 = row.querySelector('.create-col-type')) === null || _row$querySelector2 === void 0 ? void 0 : _row$querySelector2.value) || 'int';
          length = (_row$querySelector3 = row.querySelector('.create-col-length')) === null || _row$querySelector3 === void 0 ? void 0 : _row$querySelector3.value.trim();
          option = ((_row$querySelector4 = row.querySelector('.create-col-options')) === null || _row$querySelector4 === void 0 ? void 0 : _row$querySelector4.value) || '';
          nullable = (_row$querySelector5 = row.querySelector('.create-col-null')) === null || _row$querySelector5 === void 0 ? void 0 : _row$querySelector5.checked;
          autoIncrement = (_row$querySelector6 = row.querySelector('.create-col-auto-increment')) === null || _row$querySelector6 === void 0 ? void 0 : _row$querySelector6.checked;
          typeText = `${type}${length ? `(${length})` : ''}${option === 'unsigned' ? ' unsigned' : ''}`;
          column = {
            name,
            type: typeText
          };
          if (!nullable) column.nullable = false;
          if (autoIncrement) column.extra = 'Auto Increment';
          if (createDefaultValues.checked) column.default = '';
          if (createComment.checked) column.comment = '';
          columns.push(column);
          if (autoIncrement || option === 'primary') indexes.push({
            name: 'PRIMARY',
            columns: [name]
          });else if (option === 'unique') indexes.push({
            name: 'UNIQUE',
            columns: [name]
          });
        case 5:
          _i17++;
          _context34.n = 3;
          break;
        case 6:
          if (columns.length) {
            _context34.n = 7;
            break;
          }
          log(t('log.tableColumnsEmpty'));
          return _context34.a(2);
        case 7:
          tableRecord = {
            columns,
            rows: [],
            indexes: indexes.length ? indexes : [{
              name: 'PRIMARY',
              columns: [columns[0].name]
            }],
            engine: createEngine.value,
            collation: createCollation.value,
            autoIncrement: createAutoIncrement.value || ''
          };
          createSql = `CREATE TABLE ${quoteIdent(tableName)} (\n${columns.map(function (column) {
            var nullable = column.nullable === false ? ' NOT NULL' : '';
            var extra = column.extra ? ' AUTO_INCREMENT' : '';
            return `  ${quoteIdent(column.name)} ${column.type || 'TEXT'}${nullable}${extra}`;
          }).join(',\n')}\n);`;
          if (!backendOnline) {
            _context34.n = 12;
            break;
          }
          _context34.p = 8;
          _context34.n = 9;
          return executeBackendSql(createSql);
        case 9:
          data = _context34.v;
          renderResults(data.results || [data]);
          if (!hasResultError(data)) {
            _context34.n = 10;
            break;
          }
          return _context34.a(2);
        case 10:
          _context34.n = 12;
          break;
        case 11:
          _context34.p = 11;
          _t33 = _context34.v;
          backendOnline = false;
          engineCheckCompleted = true;
          updateEngineStatus();
          log(t('log.tableCreateFallback', {
            error: _t33.message
          }));
        case 12:
          (_sandbox$dbs0 = sandbox.dbs)[activeDb] || (_sandbox$dbs0[activeDb] = {});
          sandbox.dbs[activeDb][tableName] = tableRecord;
          saveSandbox();
          renderTableBrowser();
          log(t('log.tableCreated', {
            name: tableName
          }));
          renderTableDetail(tableName, 'structure');
        case 13:
          return _context34.a(2);
      }
    }, _callee34, null, [[8, 11]]);
  }));
  return _saveCreateTable.apply(this, arguments);
}
function detectImportFormat(fileName, bytes) {
  var textHint = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : '';
  var name = fileName.toLowerCase().replace(/\.gz$/, '');
  if (name.endsWith('.asb')) return 'asadb';
  if (name.endsWith('.asa') || name.endsWith('.asadb') || name.endsWith('.json')) return 'asadb';
  if (name.endsWith('.csv')) return 'csv';
  if (name.endsWith('.xlsx') || name.endsWith('.xls')) return 'xlsx';
  if (name.endsWith('.pgsql') || name.endsWith('.psql') || name.endsWith('.postgres')) return 'postgresql';
  if (name.endsWith('.mysql')) return 'mysql';
  var text = textHint.slice(0, 12000);
  if (/COPY\s+[\w".]+\s*(\(|FROM)\s+/i.test(text) || /SET\s+search_path/i.test(text) || /\bSERIAL\b/i.test(text)) return 'postgresql';
  if (/ENGINE\s*=|LOCK TABLES|UNLOCK TABLES|`[^`]+`|\/\*!/i.test(text)) return 'mysql';
  return 'mysql';
}
function startImportOperation(operation) {
  if (importOperationPromise) return importOperationPromise;
  var pending = Promise.resolve().then(operation).finally(function () {
    if (importOperationPromise === pending) importOperationPromise = null;
    updateImportControls();
  });
  importOperationPromise = pending;
  updateImportControls();
  return pending;
}
function importFromFiles() {
  return startImportOperation(importFromFilesOnce);
}
function importFromFilesOnce() {
  return _importFromFilesOnce.apply(this, arguments);
}
function _importFromFilesOnce() {
  _importFromFilesOnce = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee35() {
    var files, summaries, _i18, _files, file, useBackendSql, backendPath, summary, _t34, _t35, _t36, _t37;
    return _regenerator().w(function (_context35) {
      while (1) switch (_context35.p = _context35.n) {
        case 0:
          files = Array.from(importFileInput.files || []);
          if (files.length) {
            _context35.n = 1;
            break;
          }
          importSummary.textContent = t('import.noFile');
          return _context35.a(2);
        case 1:
          summaries = [];
          _i18 = 0, _files = files;
        case 2:
          if (!(_i18 < _files.length)) {
            _context35.n = 18;
            break;
          }
          file = _files[_i18];
          _context35.p = 3;
          useBackendSql = backendOnline && shouldUseBackendFileImport(file.name, importFormat.value);
          backendPath = useBackendSql ? knownServerImportPath(file.name) : '';
          summary = void 0;
          if (!backendPath) {
            _context35.n = 9;
            break;
          }
          _context35.p = 4;
          _context35.n = 5;
          return importServerPathWithBackend(backendPath, file.size);
        case 5:
          summary = _context35.v;
          _context35.n = 8;
          break;
        case 6:
          _context35.p = 6;
          _t34 = _context35.v;
          log(t('log.importRejected', {
            name: file.name,
            error: _t34.message
          }));
          _context35.n = 7;
          return importUploadedFileWithBackend(file);
        case 7:
          summary = _context35.v;
        case 8:
          _context35.n = 15;
          break;
        case 9:
          if (!(useBackendSql && shouldUploadFileToBackend(file))) {
            _context35.n = 11;
            break;
          }
          _context35.n = 10;
          return importUploadedFileWithBackend(file);
        case 10:
          summary = _context35.v;
          _context35.n = 15;
          break;
        case 11:
          if (!(!backendOnline && shouldUseBackendFileImport(file.name, importFormat.value) && file.size > BROWSER_SQL_IMPORT_LIMIT_BYTES)) {
            _context35.n = 12;
            break;
          }
          throw new Error(t('import.largeBackendRequired'));
        case 12:
          _t35 = importFromBuffer;
          _t36 = file.name;
          _context35.n = 13;
          return file.arrayBuffer();
        case 13:
          _context35.n = 14;
          return _t35(_t36, _context35.v, importFormat.value);
        case 14:
          summary = _context35.v;
        case 15:
          summaries.push(summary);
          _context35.n = 17;
          break;
        case 16:
          _context35.p = 16;
          _t37 = _context35.v;
          summaries.push(_t37.reservoirStatus === 'cancelled' ? `${file.name}: ${t('import.cancelled')}` : `${file.name}: ${ASA_ERROR_LABEL} ${asaErrorCopy(_t37.message)}`);
          log(t('log.importFailed', {
            name: file.name,
            error: _t37.message
          }));
          if (!importStopOnError.checked) {
            _context35.n = 17;
            break;
          }
          return _context35.a(3, 18);
        case 17:
          _i18++;
          _context35.n = 2;
          break;
        case 18:
          importFileInput.value = '';
          importSummary.textContent = summaries.join('\n');
          renderTableBrowser();
        case 19:
          return _context35.a(2);
      }
    }, _callee35, null, [[4, 6], [3, 16]]);
  }));
  return _importFromFilesOnce.apply(this, arguments);
}
function importFromServerFile() {
  return startImportOperation(importFromServerFileOnce);
}
function importFromServerFileOnce() {
  return _importFromServerFileOnce.apply(this, arguments);
}
function _importFromServerFileOnce() {
  _importFromServerFileOnce = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee36() {
    var path, res, summary, _t38, _t39, _t40;
    return _regenerator().w(function (_context36) {
      while (1) switch (_context36.p = _context36.n) {
        case 0:
          path = importServerPath.value.trim();
          if (path) {
            _context36.n = 1;
            break;
          }
          return _context36.a(2);
        case 1:
          _context36.p = 1;
          if (!(backendOnline && shouldUseBackendFileImport(path, importFormat.value))) {
            _context36.n = 3;
            break;
          }
          _context36.n = 2;
          return importServerPathWithBackend(path);
        case 2:
          importSummary.textContent = _context36.v;
          return _context36.a(2);
        case 3:
          if (!(!backendOnline && isKnownHugeServerImport(path))) {
            _context36.n = 4;
            break;
          }
          throw new Error(t('import.largeBackendRequired'));
        case 4:
          _context36.n = 5;
          return fetch(path, {
            cache: 'no-store'
          });
        case 5:
          res = _context36.v;
          if (res.ok) {
            _context36.n = 6;
            break;
          }
          throw new Error(`HTTP ${res.status}`);
        case 6:
          _t38 = importFromBuffer;
          _t39 = path;
          _context36.n = 7;
          return res.arrayBuffer();
        case 7:
          _context36.n = 8;
          return _t38(_t39, _context36.v, importFormat.value);
        case 8:
          summary = _context36.v;
          importSummary.textContent = summary;
          _context36.n = 10;
          break;
        case 9:
          _context36.p = 9;
          _t40 = _context36.v;
          importSummary.textContent = _t40.reservoirStatus === 'cancelled' ? t('import.cancelled') : `${ASA_ERROR_LABEL}: ${asaErrorCopy(_t40.message)}`;
          log(t('log.serverImportFailed', {
            error: _t40.message
          }));
        case 10:
          return _context36.a(2);
      }
    }, _callee36, null, [[1, 9]]);
  }));
  return _importFromServerFileOnce.apply(this, arguments);
}
function shouldUseBackendFileImport(path, selectedFormat) {
  var clean = String(path || '').replace(/\\/g, '/').replace(/^\/+/, '');
  if (/\.gz$/i.test(clean)) return false;
  var productionBackup = /\.asb$/i.test(clean);
  var sqlPath = /\.(sql|mysql|pgsql|psql|postgres)$/i.test(clean);
  var sqlFormat = selectedFormat === 'auto' || selectedFormat === 'mysql' || selectedFormat === 'postgresql';
  return productionBackup || sqlPath && sqlFormat;
}
function shouldUploadFileToBackend(file) {
  if (!file) return false;
  return Number(file.size || 0) >= BACKEND_UPLOAD_IMPORT_MIN_BYTES || shouldUseBackendFileImport(file.name, importFormat.value);
}
function knownServerImportPath(fileName) {
  var name = String(fileName || '').split(/[\\/]/).pop();
  if (/^public_safety_archive_\d+\.sql$/i.test(name)) return `stress tests/${name}`;
  return '';
}
function isKnownHugeServerImport(path) {
  return /(?:^|[\\/])public_safety_archive_1275080\.sql$/i.test(String(path || ''));
}
function makeImportId() {
  return `import-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}
function importServerPathWithBackend(_x23) {
  return _importServerPathWithBackend.apply(this, arguments);
}
function _importServerPathWithBackend() {
  _importServerPathWithBackend = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee37(path) {
    var _summaryTable$rows;
    var sizeHint,
      data,
      results,
      summaryTable,
      row,
      status,
      statements,
      errors,
      sizeBytes,
      summary,
      _args37 = arguments;
    return _regenerator().w(function (_context37) {
      while (1) switch (_context37.n) {
        case 0:
          sizeHint = _args37.length > 1 && _args37[1] !== undefined ? _args37[1] : 0;
          noteArchiveImportStart(path, sizeHint);
          log(t('log.reservoirFileStart', {
            name: path
          }));
          _context37.n = 1;
          return startReservoirFile(path, {
            kind: 'import-file',
            label: path,
            sizeBytes: sizeHint,
            stopOnError: importStopOnError.checked,
            onProgress: function onProgress(_ref10) {
              var completed = _ref10.completed,
                total = _ref10.total,
                statements = _ref10.statements,
                label = _ref10.label;
              var percent = total ? Math.min(100, Math.round(completed / total * 100)) : 0;
              setLastRunKey('progress.reservoir', {
                percent,
                count: statements
              });
              noteArchiveSqlProgress('', completed, total, label);
            }
          });
        case 1:
          data = _context37.v;
          results = data.results || [data];
          renderResults(results);
          summaryTable = results.find(function (result) {
            return result.status === 'table';
          });
          row = (summaryTable === null || summaryTable === void 0 || (_summaryTable$rows = summaryTable.rows) === null || _summaryTable$rows === void 0 ? void 0 : _summaryTable$rows[0]) || [];
          status = row[0] || 'ok';
          statements = Number(row[2]) || 0;
          errors = Number(row[3]) || 0;
          sizeBytes = Number(row[6]) || sizeHint || 0;
          _context37.n = 2;
          return Promise.all([syncCatalogFromBackend().catch(function () {
            return false;
          }), refreshDatabaseMetadata().catch(function () {
            return null;
          })]);
        case 2:
          noteArchiveImportComplete(path, sizeBytes, (summaryTable === null || summaryTable === void 0 ? void 0 : summaryTable.columns) || ['status'], (summaryTable === null || summaryTable === void 0 ? void 0 : summaryTable.rows) || [[status]], statements);
          setSqlText(`-- Backend Prolog import: ${path}\nSHOW TABLES;\nSELECT COUNT(*) AS total_rows FROM Public_Safety_Archive;`);
          setLastRunKey('progress.backendSteps', {
            count: statements
          });
          renderTableBrowser();
          summary = t('import.backendSummary', {
            name: path,
            statements: formatNumber(statements),
            errors: formatNumber(errors)
          });
          log(summary);
          if (!(errors > 0)) {
            _context37.n = 3;
            break;
          }
          throw new Error(summary);
        case 3:
          return _context37.a(2, summary);
      }
    }, _callee37);
  }));
  return _importServerPathWithBackend.apply(this, arguments);
}
function importUploadedFileWithBackend(_x24) {
  return _importUploadedFileWithBackend.apply(this, arguments);
}
function _importUploadedFileWithBackend() {
  _importUploadedFileWithBackend = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee38(file) {
    var _summaryTable$rows2;
    var data, results, summaryTable, row, status, statements, errors, sizeBytes, summary;
    return _regenerator().w(function (_context38) {
      while (1) switch (_context38.n) {
        case 0:
          noteArchiveImportStart(file.name, file.size || 0);
          log(t('log.reservoirUploadStart', {
            name: file.name
          }));
          _context38.n = 1;
          return submitReservoirPayload(file, {
            kind: 'import-upload',
            label: file.name,
            sizeBytes: file.size || 0,
            contentType: file.type || 'application/sql',
            stopOnError: importStopOnError.checked,
            onProgress: function onProgress(_ref11) {
              var completed = _ref11.completed,
                total = _ref11.total,
                statements = _ref11.statements;
              var percent = total ? Math.min(100, Math.round(completed / total * 100)) : 0;
              setLastRunKey('progress.reservoir', {
                percent,
                count: statements
              });
            }
          });
        case 1:
          data = _context38.v;
          results = data.results || [data];
          renderResults(results);
          summaryTable = results.find(function (result) {
            return result.status === 'table';
          });
          row = (summaryTable === null || summaryTable === void 0 || (_summaryTable$rows2 = summaryTable.rows) === null || _summaryTable$rows2 === void 0 ? void 0 : _summaryTable$rows2[0]) || [];
          status = row[0] || 'ok';
          statements = Number(row[2]) || 0;
          errors = Number(row[3]) || 0;
          sizeBytes = Number(row[6]) || file.size || 0;
          _context38.n = 2;
          return Promise.all([syncBackendStateSmart().catch(function () {
            return syncCatalogFromBackend().catch(function () {
              return false;
            });
          }), refreshDatabaseMetadata().catch(function () {
            return null;
          })]);
        case 2:
          noteArchiveImportComplete(file.name, sizeBytes, (summaryTable === null || summaryTable === void 0 ? void 0 : summaryTable.columns) || ['status'], (summaryTable === null || summaryTable === void 0 ? void 0 : summaryTable.rows) || [[status]], statements);
          setSqlText(`-- Uploaded through Prolog backend: ${file.name}\nSHOW TABLES;`);
          setLastRunKey('progress.backendSteps', {
            count: statements
          });
          renderTableBrowser();
          summary = t('import.uploadSummary', {
            name: file.name,
            statements: formatNumber(statements),
            errors: formatNumber(errors)
          });
          log(summary);
          if (!(errors > 0)) {
            _context38.n = 3;
            break;
          }
          throw new Error(summary);
        case 3:
          return _context38.a(2, summary);
      }
    }, _callee38);
  }));
  return _importUploadedFileWithBackend.apply(this, arguments);
}
function importFromBuffer(_x25, _x26, _x27) {
  return _importFromBuffer.apply(this, arguments);
}
function _importFromBuffer() {
  _importFromBuffer = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee39(name, rawBuffer, selectedFormat) {
    var buffer, cleanName, initialText, format, mode, summary, backendMutation, imported, preview, tableName, matrix, workbook, _iterator46, _step46, sheet, _tableName, firstSheet, sql, data, plan, _allResults, statementCount, _t41;
    return _regenerator().w(function (_context39) {
      while (1) switch (_context39.n) {
        case 0:
          buffer = rawBuffer;
          cleanName = name;
          if (!/\.gz$/i.test(cleanName)) {
            _context39.n = 2;
            break;
          }
          _context39.n = 1;
          return gunzipBuffer(buffer);
        case 1:
          buffer = _context39.v;
          cleanName = cleanName.replace(/\.gz$/i, '');
        case 2:
          initialText = isLikelyText(cleanName) ? decodeText(buffer) : '';
          format = selectedFormat === 'auto' ? detectImportFormat(cleanName, buffer, initialText) : selectedFormat;
          mode = importWriteMode.value;
          summary = t('import.conversion', {
            name,
            format: FORMAT_LABELS[format]
          });
          backendMutation = false;
          noteArchiveImportStart(name, rawBuffer.byteLength || buffer.byteLength || 0);
          if (!(format === 'asadb')) {
            _context39.n = 3;
            break;
          }
          imported = parseAsaDbBuffer(buffer);
          mergeSandbox(imported, mode === 'replace');
          saveSandbox();
          preview = firstImportedTablePreview(imported);
          noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, preview.columns, preview.rows, preview.rowCount);
          summary += `, ${t('import.tablesLoaded', {
            count: formatNumber(countTables(imported))
          })}`;
          _context39.n = 17;
          break;
        case 3:
          if (!(format === 'csv')) {
            _context39.n = 5;
            break;
          }
          if (ensureCurrentDb('import CSV')) {
            _context39.n = 4;
            break;
          }
          throw new Error(t('import.databaseRequired', {
            format: 'CSV'
          }));
        case 4:
          tableName = importTargetTable.value.trim() || sanitizeName(baseName(cleanName));
          matrix = parseCsv(decodeText(buffer));
          upsertMatrixTable(tableName, matrix, mode);
          noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, matrix[0] || [], matrix.slice(1, 5), Math.max(0, matrix.length - 1));
          summary += `, ${t('import.tableRows', {
            table: tableName,
            count: formatNumber(Math.max(0, matrix.length - 1))
          })}`;
          _context39.n = 17;
          break;
        case 5:
          if (!(format === 'xlsx')) {
            _context39.n = 8;
            break;
          }
          if (ensureCurrentDb('import XLSX')) {
            _context39.n = 6;
            break;
          }
          throw new Error(t('import.databaseRequired', {
            format: 'XLSX'
          }));
        case 6:
          _context39.n = 7;
          return readXlsxWorkbook(buffer);
        case 7:
          workbook = _context39.v;
          _iterator46 = _createForOfIteratorHelper(workbook.sheets);
          try {
            for (_iterator46.s(); !(_step46 = _iterator46.n()).done;) {
              sheet = _step46.value;
              _tableName = sanitizeName(sheet.name || baseName(cleanName));
              upsertMatrixTable(_tableName, sheet.rows, mode);
            }
          } catch (err) {
            _iterator46.e(err);
          } finally {
            _iterator46.f();
          }
          firstSheet = workbook.sheets[0] || {
            rows: []
          };
          noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, firstSheet.rows[0] || [], (firstSheet.rows || []).slice(1, 5), Math.max(0, (firstSheet.rows || []).length - 1));
          summary += `, ${t('import.sheetsLoaded', {
            count: formatNumber(workbook.sheets.length)
          })}`;
          _context39.n = 17;
          break;
        case 8:
          if (!(format === 'mysql' || format === 'postgresql')) {
            _context39.n = 16;
            break;
          }
          sql = convertDialectToAsaSql(decodeText(buffer), format);
          if (!backendOnline) {
            _context39.n = 13;
            break;
          }
          plan = createSqlExecutionPlan(sql);
          backendMutation = true;
          if (!(plan.mode === 'reservoir')) {
            _context39.n = 10;
            break;
          }
          _context39.n = 9;
          return executeBackendSqlStreamed(sql, {
            kind: 'import-conversion',
            label: name,
            sizeBytes: rawBuffer.byteLength || buffer.byteLength || 0,
            stopOnError: importStopOnError.checked,
            onProgress: function onProgress(_ref12) {
              var completed = _ref12.completed,
                total = _ref12.total,
                statements = _ref12.statements;
              var percent = total ? Math.min(100, Math.round(completed / total * 100)) : 0;
              setLastRunKey('progress.importing', {
                percent,
                count: statements
              });
            }
          });
        case 9:
          _t41 = _context39.v;
          _context39.n = 12;
          break;
        case 10:
          _context39.n = 11;
          return executeBackendSql(sql, {
            sync: false
          });
        case 11:
          _t41 = _context39.v;
        case 12:
          data = _t41;
          _context39.n = 15;
          break;
        case 13:
          if (!(sql.length > 100000)) {
            _context39.n = 14;
            break;
          }
          throw new Error(t('import.largeBackendRequired'));
        case 14:
          data = sandboxExecWithOptions(sql, {
            stopOnError: importStopOnError.checked,
            showOnlyErrors: importShowOnlyErrors.checked
          });
        case 15:
          renderResults(data.results || [data]);
          if (sql.length < 500000) setSqlText(sql);else setSqlText(`-- Large SQL imported through Prolog backend: ${name}\nSHOW TABLES;`);
          _allResults = data.allResults || data.results || [];
          statementCount = Number(data.statementCount || _allResults.length || 0);
          setLastRunKey('import.statements', {
            count: statementCount
          });
          noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, ['statement', 'status'], _allResults.slice(0, 4).map(function (result, index) {
            return [index + 1, result.status || 'ok'];
          }), statementCount);
          summary += `, ${t('import.statements', {
            count: formatNumber(statementCount)
          })}`;
          _context39.n = 17;
          break;
        case 16:
          throw new Error(t('import.unsupportedFormat', {
            format
          }));
        case 17:
          if (!backendMutation) {
            _context39.n = 18;
            break;
          }
          _context39.n = 18;
          return Promise.all([syncBackendStateSmart().catch(function () {
            return syncCatalogFromBackend().catch(function () {
              return false;
            });
          }), refreshDatabaseMetadata().catch(function () {
            return null;
          })]);
        case 18:
          saveSandbox();
          renderTableBrowser();
          log(summary);
          return _context39.a(2, summary);
      }
    }, _callee39);
  }));
  return _importFromBuffer.apply(this, arguments);
}
function isLikelyText(name) {
  return /\.(asa|asadb|json|csv|sql|mysql|pgsql|psql|postgres|txt)$/i.test(name);
}
function decodeText(buffer) {
  return new TextDecoder('utf-8').decode(buffer).replace(/^\uFEFF/, '');
}
function countTables(state) {
  return Object.values(state.dbs || {}).reduce(function (sum, db) {
    return sum + Object.keys(db || {}).length;
  }, 0);
}
function firstImportedTablePreview(state) {
  var normalized = normalizeSandbox(state);
  for (var _i1 = 0, _Object$values3 = Object.values(normalized.dbs || {}); _i1 < _Object$values3.length; _i1++) {
    var db = _Object$values3[_i1];
    var _loop7 = function _loop7() {
        var _table$rows;
        var table = _Object$values4[_i10];
        var columns = (table.columns || []).map(function (col) {
          return col.name || col;
        });
        var rows = (table.rows || []).slice(0, 4).map(function (row) {
          return columns.map(function (column) {
            var _row$column2;
            return (_row$column2 = row === null || row === void 0 ? void 0 : row[column]) !== null && _row$column2 !== void 0 ? _row$column2 : null;
          });
        });
        return {
          v: {
            columns,
            rows,
            rowCount: ((_table$rows = table.rows) === null || _table$rows === void 0 ? void 0 : _table$rows.length) || 0
          }
        };
      },
      _ret3;
    for (var _i10 = 0, _Object$values4 = Object.values(db || {}); _i10 < _Object$values4.length; _i10++) {
      _ret3 = _loop7();
      if (_ret3) return _ret3.v;
    }
  }
  return {
    columns: ['status'],
    rows: [['no table data']],
    rowCount: 0
  };
}
function mergeSandbox(incoming, replace) {
  var _sandbox4;
  incoming = normalizeSandbox(incoming);
  if (replace) {
    sandbox = incoming;
    return;
  }
  (_sandbox4 = sandbox).views || (_sandbox4.views = {});
  for (var _i11 = 0, _Object$entries5 = Object.entries(incoming.dbs); _i11 < _Object$entries5.length; _i11++) {
    var _sandbox$dbs6;
    var _Object$entries5$_i = _slicedToArray(_Object$entries5[_i11], 2),
      db = _Object$entries5$_i[0],
      tables = _Object$entries5$_i[1];
    (_sandbox$dbs6 = sandbox.dbs)[db] || (_sandbox$dbs6[db] = {});
    for (var _i12 = 0, _Object$entries6 = Object.entries(tables); _i12 < _Object$entries6.length; _i12++) {
      var _Object$entries6$_i = _slicedToArray(_Object$entries6[_i12], 2),
        table = _Object$entries6$_i[0],
        value = _Object$entries6$_i[1];
      if (!sandbox.dbs[db][table]) {
        sandbox.dbs[db][table] = value;
      } else {
        var _target$rows;
        var target = sandbox.dbs[db][table];
        var known = new Set(target.columns.map(function (c) {
          return c.name;
        }));
        var _iterator26 = _createForOfIteratorHelper(value.columns || []),
          _step26;
        try {
          for (_iterator26.s(); !(_step26 = _iterator26.n()).done;) {
            var col = _step26.value;
            if (!known.has(col.name)) target.columns.push(col);
          }
        } catch (err) {
          _iterator26.e(err);
        } finally {
          _iterator26.f();
        }
        (_target$rows = target.rows).push.apply(_target$rows, _toConsumableArray(value.rows || []));
      }
    }
  }
  for (var _i13 = 0, _Object$entries7 = Object.entries(incoming.views || {}); _i13 < _Object$entries7.length; _i13++) {
    var _sandbox$views9;
    var _Object$entries7$_i = _slicedToArray(_Object$entries7[_i13], 2),
      _db2 = _Object$entries7$_i[0],
      dbViews = _Object$entries7$_i[1];
    (_sandbox$views9 = sandbox.views)[_db2] || (_sandbox$views9[_db2] = {});
    for (var _i14 = 0, _Object$entries8 = Object.entries(dbViews || {}); _i14 < _Object$entries8.length; _i14++) {
      var _Object$entries8$_i = _slicedToArray(_Object$entries8[_i14], 2),
        view = _Object$entries8$_i[0],
        _value = _Object$entries8$_i[1];
      sandbox.views[_db2][view] = _value;
    }
  }
  sandbox.currentDb = incoming.currentDb || sandbox.currentDb;
}
function upsertMatrixTable(tableName, matrix, mode) {
  var _sandbox$dbs7;
  var activeDb = ensureCurrentDb('import table');
  if (!activeDb) throw new Error(t('database.selectFirst'));
  var rows = matrix.filter(function (row) {
    return row.some(function (cell) {
      return String(cell !== null && cell !== void 0 ? cell : '').trim() !== '';
    });
  });
  if (!rows.length) return;
  var headers = rows[0].map(function (name, index) {
    return sanitizeName(name || `column_${index + 1}`);
  });
  var dataRows = rows.slice(1);
  var columns = headers.map(function (name, index) {
    return {
      name,
      type: inferColumnType(dataRows.map(function (row) {
        return row[index];
      }))
    };
  });
  var mappedRows = dataRows.map(function (row) {
    var out = {};
    headers.forEach(function (header, index) {
      return out[header] = normalizeCellValue(row[index]);
    });
    return out;
  });
  (_sandbox$dbs7 = sandbox.dbs)[activeDb] || (_sandbox$dbs7[activeDb] = {});
  if (mode === 'append' && sandbox.dbs[activeDb][tableName]) {
    var _table$rows2;
    var table = sandbox.dbs[activeDb][tableName];
    var known = new Set(table.columns.map(function (c) {
      return c.name;
    }));
    var _iterator27 = _createForOfIteratorHelper(columns),
      _step27;
    try {
      for (_iterator27.s(); !(_step27 = _iterator27.n()).done;) {
        var col = _step27.value;
        if (!known.has(col.name)) table.columns.push(col);
      }
    } catch (err) {
      _iterator27.e(err);
    } finally {
      _iterator27.f();
    }
    (_table$rows2 = table.rows).push.apply(_table$rows2, _toConsumableArray(mappedRows));
  } else {
    sandbox.dbs[activeDb][tableName] = {
      columns,
      rows: mappedRows
    };
  }
}
function inferColumnType(values) {
  var filled = values.map(normalizeCellValue).filter(function (v) {
    return v !== null && v !== '';
  });
  if (filled.length && filled.every(function (v) {
    return typeof v === 'number';
  })) return 'INT';
  return 'TEXT';
}
function normalizeCellValue(value) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value === 'number') return value;
  var text = String(value).trim();
  if (text === '') return null;
  if (/^-?\d+$/.test(text)) return Number(text);
  return text;
}
function parseCsv(text) {
  var rows = [];
  var row = [],
    cell = '',
    quote = false;
  for (var i = 0; i < text.length; i += 1) {
    var ch = text[i];
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
    if (ch === '"') quote = true;else if (ch === ',') {
      row.push(cell);
      cell = '';
    } else if (ch === '\n') {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
    } else if (ch !== '\r') cell += ch;
  }
  row.push(cell);
  if (row.length > 1 || row[0] !== '') rows.push(row);
  return rows;
}
function convertDialectToAsaSql(sql, dialect) {
  var out = sql.replace(/\r\n?/g, '\n').replace(/^\uFEFF/, '');
  out = out.replace(/\/\*![\s\S]*?\*\//g, '');
  out = out.replace(/\/\*[\s\S]*?\*\//g, '');
  out = out.split('\n').filter(function (line) {
    return !/^\s*(SET|LOCK TABLES|UNLOCK TABLES|DELIMITER|START TRANSACTION|COMMIT|ROLLBACK|BEGIN|ANALYZE)\b/i.test(line);
  }).join('\n');
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
  out = out.replace(/ALTER\s+TABLE\s+[`"]?([\w$]+)[`"]?\s+ADD\s+(UNIQUE\s+)?(?:KEY|INDEX)\s+[`"]?([\w$]+)[`"]?\s*\(([^)]+)\)\s*;/gi, function (_m, table, unique, index, cols) {
    return `CREATE ${unique ? 'UNIQUE ' : ''}INDEX ${index} ON ${table} (${cols.replace(/[`"]/g, '')});`;
  });
  out = out.replace(/ALTER\s+TABLE\s+[^;]+;/gi, '');
  if (dialect === 'postgresql') out = convertCopyBlocks(out);
  return out;
}
function convertCopyBlocks(sql) {
  var lines = sql.split('\n');
  var out = [];
  for (var i = 0; i < lines.length; i += 1) {
    var m = /^\s*COPY\s+([\w."]+)\s*(?:\(([^)]*)\))?\s+FROM\s+stdin\s*;/i.exec(lines[i]);
    if (!m) {
      out.push(lines[i]);
      continue;
    }
    var table = m[1].replace(/"/g, '').split('.').pop();
    var columns = (m[2] || '').split(',').map(function (x) {
      return x.trim().replace(/"/g, '');
    }).filter(Boolean);
    var rows = [];
    i += 1;
    while (i < lines.length && lines[i] !== '\\.') {
      rows.push(lines[i].split('\t').map(function (value) {
        return value === '\\N' ? null : value;
      }));
      i += 1;
    }
    if (columns.length) {
      var _iterator28 = _createForOfIteratorHelper(rows),
        _step28;
      try {
        for (_iterator28.s(); !(_step28 = _iterator28.n()).done;) {
          var row = _step28.value;
          out.push(`INSERT INTO ${quoteIdent(table)} (${columns.map(quoteIdent).join(', ')}) VALUES (${row.map(sqlLiteral).join(', ')});`);
        }
      } catch (err) {
        _iterator28.e(err);
      } finally {
        _iterator28.f();
      }
    }
  }
  return out.join('\n');
}
function exportDatabase() {
  return _exportDatabase.apply(this, arguments);
}
function _exportDatabase() {
  _exportDatabase = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee40() {
    var format, output, pkg, blob, filename, _t42;
    return _regenerator().w(function (_context40) {
      while (1) switch (_context40.p = _context40.n) {
        case 0:
          format = checkedValue('exportFormat');
          output = checkedValue('exportOutput');
          _context40.p = 1;
          _context40.n = 2;
          return buildExportPackage(format);
        case 2:
          pkg = _context40.v;
          blob = pkg.blob;
          filename = pkg.filename;
          if (!(output === 'gzip')) {
            _context40.n = 4;
            break;
          }
          _context40.n = 3;
          return gzipBlob(blob);
        case 3:
          blob = _context40.v;
          filename = `${filename}.gz`;
        case 4:
          exportPreview.textContent = pkg.preview;
          if (output === 'open') {
            openBlob(blob, filename);
            log(t('log.fileOpened', {
              name: filename
            }));
          } else {
            downloadBlob(blob, filename);
            log(t('log.fileDownloaded', {
              name: filename
            }));
          }
          _context40.n = 6;
          break;
        case 5:
          _context40.p = 5;
          _t42 = _context40.v;
          exportPreview.textContent = `${ASA_ERROR_LABEL}: ${asaErrorCopy(_t42.message)}`;
          log(t('log.exportFailed', {
            error: _t42.message
          }));
        case 6:
          return _context40.a(2);
      }
    }, _callee40, null, [[1, 5]]);
  }));
  return _exportDatabase.apply(this, arguments);
}
function buildExportPackage(_x28) {
  return _buildExportPackage.apply(this, arguments);
}
function _buildExportPackage() {
  _buildExportPackage = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee41(format) {
    var db, selection, bytes, preview, csv, entries, zip, _bytes, sql;
    return _regenerator().w(function (_context41) {
      while (1) switch (_context41.n) {
        case 0:
          db = ensureCurrentDb('export');
          if (db) {
            _context41.n = 1;
            break;
          }
          throw new Error(t('database.selectFirst'));
        case 1:
          selection = getExportSelection();
          if (selection.length) {
            _context41.n = 2;
            break;
          }
          throw new Error(t('export.noTables'));
        case 2:
          if (!(format === 'asadb')) {
            _context41.n = 3;
            break;
          }
          bytes = makeAsaDbBytes(db, selection);
          preview = prologStateText(db, selection).slice(0, 6000);
          return _context41.a(2, {
            blob: new Blob([bytes], {
              type: 'application/octet-stream'
            }),
            filename: `${db}.asa`,
            preview
          });
        case 3:
          if (!(format === 'csv')) {
            _context41.n = 5;
            break;
          }
          if (!(selection.length === 1)) {
            _context41.n = 4;
            break;
          }
          csv = tableToCsv(selection[0].table, selection[0].includeData, selection[0].includeSchema);
          return _context41.a(2, {
            blob: new Blob([csv], {
              type: 'text/csv'
            }),
            filename: `${selection[0].name}.csv`,
            preview: csv.slice(0, 6000)
          });
        case 4:
          entries = selection.map(function (item) {
            return {
              name: `${item.name}.csv`,
              data: utf8(tableToCsv(item.table, item.includeData, item.includeSchema))
            };
          });
          zip = makeZip(entries);
          return _context41.a(2, {
            blob: new Blob([zip], {
              type: 'application/zip'
            }),
            filename: `${db}-csv.zip`,
            preview: selection.map(function (x) {
              return `${x.name}.csv`;
            }).join('\n')
          });
        case 5:
          if (!(format === 'xlsx')) {
            _context41.n = 6;
            break;
          }
          _bytes = makeXlsx(selection);
          return _context41.a(2, {
            blob: new Blob([_bytes], {
              type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            }),
            filename: `${db}.xlsx`,
            preview: selection.map(function (x) {
              return `sheet: ${x.name}`;
            }).join('\n')
          });
        case 6:
          if (!(format === 'mysql' || format === 'postgresql')) {
            _context41.n = 7;
            break;
          }
          sql = buildSqlExport(db, selection, format);
          return _context41.a(2, {
            blob: new Blob([sql], {
              type: 'application/sql'
            }),
            filename: `${db}-${format}.sql`,
            preview: sql.slice(0, 9000)
          });
        case 7:
          throw new Error(t('import.unsupportedFormat', {
            format
          }));
        case 8:
          return _context41.a(2);
      }
    }, _callee41);
  }));
  return _buildExportPackage.apply(this, arguments);
}
function checkedValue(name) {
  var _document$querySelect;
  return (_document$querySelect = document.querySelector(`input[name="${name}"]:checked`)) === null || _document$querySelect === void 0 ? void 0 : _document$querySelect.value;
}
function tableToCsv(table, includeData) {
  var includeHeader = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : true;
  var columns = table.columns || [];
  var lines = [];
  if (includeHeader) lines.push(columns.map(function (c) {
    return csvCell(c.name);
  }).join(','));
  if (includeData) {
    var _iterator29 = _createForOfIteratorHelper(table.rows || []),
      _step29;
    try {
      var _loop8 = function _loop8() {
        var row = _step29.value;
        lines.push(columns.map(function (c) {
          return csvCell(row[c.name]);
        }).join(','));
      };
      for (_iterator29.s(); !(_step29 = _iterator29.n()).done;) {
        _loop8();
      }
    } catch (err) {
      _iterator29.e(err);
    } finally {
      _iterator29.f();
    }
  }
  return lines.length ? `${lines.join('\n')}\n` : '';
}
function csvCell(value) {
  if (value === null || value === undefined) return '';
  var text = String(value);
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}
function buildSqlExport(db, selection, dialect) {
  var lines = [];
  var quote = dialect === 'postgresql' ? quotePgIdent : quoteMysqlIdent;
  if (exportDatabaseMode.value === 'create') {
    lines.push(`CREATE DATABASE ${quote(db)};`);
    if (dialect === 'mysql') lines.push(`USE ${quote(db)};`);
    lines.push('');
  }
  var _iterator30 = _createForOfIteratorHelper(selection),
    _step30;
  try {
    for (_iterator30.s(); !(_step30 = _iterator30.n()).done;) {
      var item = _step30.value;
      var tableMode = exportTableMode.value;
      if (tableMode === 'drop_create') lines.push(`DROP TABLE IF EXISTS ${quote(item.name)};`);
      if (tableMode !== 'none') {
        lines.push(`CREATE TABLE ${quote(item.name)} (`);
        var columns = (item.table.columns || []).map(function (col) {
          return `  ${quote(col.name)} ${mapTypeForDialect(col.type, dialect)}`;
        });
        lines.push(columns.join(',\n'));
        lines.push(');');
        var _iterator31 = _createForOfIteratorHelper(item.table.indexes || []),
          _step31;
        try {
          for (_iterator31.s(); !(_step31 = _iterator31.n()).done;) {
            var _index$columns;
            var index = _step31.value;
            if (!((_index$columns = index.columns) !== null && _index$columns !== void 0 && _index$columns.length) || /^PRIMARY$/i.test(index.name || '')) continue;
            var unique = /unique/i.test(index.name || '') || index.unique === true || index.kind === 'unique';
            var cols = index.columns.map(function (col) {
              return quote(col);
            }).join(', ');
            lines.push(`CREATE ${unique ? 'UNIQUE ' : ''}INDEX ${quote(index.name || `${item.name}_idx`)} ON ${quote(item.name)} (${cols});`);
          }
        } catch (err) {
          _iterator31.e(err);
        } finally {
          _iterator31.f();
        }
      }
      if (exportDataMode.value !== 'none' && item.includeData) {
        var names = (item.table.columns || []).map(function (col) {
          return quote(col.name);
        }).join(', ');
        var _iterator32 = _createForOfIteratorHelper(item.table.rows || []),
          _step32;
        try {
          var _loop9 = function _loop9() {
            var row = _step32.value;
            var values = (item.table.columns || []).map(function (col) {
              return sqlLiteral(row[col.name]);
            }).join(', ');
            lines.push(`INSERT INTO ${quote(item.name)} (${names}) VALUES (${values});`);
          };
          for (_iterator32.s(); !(_step32 = _iterator32.n()).done;) {
            _loop9();
          }
        } catch (err) {
          _iterator32.e(err);
        } finally {
          _iterator32.f();
        }
      }
      lines.push('');
    }
  } catch (err) {
    _iterator30.e(err);
  } finally {
    _iterator30.f();
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
  var t = String(type || 'TEXT').toUpperCase();
  if (dialect === 'postgresql') {
    if (t === 'INT' || t === 'INTEGER') return 'INTEGER';
    if (t.includes('DATETIME')) return 'TIMESTAMP';
  }
  return t;
}
function prologStateText(db, selection) {
  var tables = selection.filter(function (item) {
    return item.includeSchema;
  }).map(function (item) {
    var columns = (item.table.columns || []).map(function (col) {
      return `col(${prologAtom(col.name)},${prologAtom(col.type || 'TEXT')},[])`;
    }).join(',');
    var rows = item.includeData ? (item.table.rows || []).map(function (row) {
      var pairs = (item.table.columns || []).map(function (col) {
        return `${prologAtom(col.name)}=${prologValue(row[col.name])}`;
      }).join(',');
      return `row([${pairs}])`;
    }).join(',') : '';
    return `table(${prologAtom(item.name)},[${columns}],[${rows}])`;
  }).join(',');
  return `state(1,[db(${prologAtom(db)},[${tables}])])`;
}
function makeAsaDbBytes(db, selection) {
  var text = prologStateText(db, selection);
  var codes = Array.from(text).map(function (ch) {
    return ch.charCodeAt(0) & 255;
  });
  var sum = codes.reduce(function (acc, code) {
    return (acc + code) % 1000000007;
  }, 0);
  var encoded = codes.map(function (code) {
    return (code ^ 90) & 255;
  });
  var header = utf8(`ASADB001\n${sum}\n`);
  var out = new Uint8Array(header.length + encoded.length);
  out.set(header, 0);
  out.set(encoded, header.length);
  return out;
}
function parseAsaDbBuffer(buffer) {
  var bytes = new Uint8Array(buffer);
  if (!startsWithAscii(bytes, 'ASADB001\n')) {
    var text = decodeText(buffer);
    if (text.startsWith('ASADBWEB1\n')) return normalizeSandbox(JSON.parse(text.slice('ASADBWEB1\n'.length)));
    if (text.trim().startsWith('{')) return normalizeSandbox(JSON.parse(text));
    throw new Error('Invalid AsaDB file.');
  }
  var offset = 'ASADB001\n'.length;
  var sumText = '';
  while (offset < bytes.length && bytes[offset] !== 10) {
    sumText += String.fromCharCode(bytes[offset]);
    offset += 1;
  }
  offset += 1;
  var decoded = [];
  for (; offset < bytes.length; offset += 1) decoded.push((bytes[offset] ^ 90) & 255);
  var expected = Number(sumText);
  var actual = decoded.reduce(function (acc, code) {
    return (acc + code) % 1000000007;
  }, 0);
  if (expected !== actual) throw new Error('AsaDB checksum mismatch.');
  var term = bytesToAscii(decoded);
  return prologTermToSandbox(parsePrologTerm(term));
}
function startsWithAscii(bytes, text) {
  if (bytes.length < text.length) return false;
  for (var i = 0; i < text.length; i += 1) if (bytes[i] !== text.charCodeAt(i)) return false;
  return true;
}
function bytesToAscii(bytes) {
  var out = '';
  for (var i = 0; i < bytes.length; i += 8192) {
    out += String.fromCharCode.apply(String, _toConsumableArray(bytes.slice(i, i + 8192)));
  }
  return out;
}
function prologAtom(value) {
  var text = String(value !== null && value !== void 0 ? value : '');
  return `'${text.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
}
function prologValue(value) {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'number') return String(value);
  return prologAtom(value);
}
function parsePrologTerm(text) {
  var tokens = tokenizeProlog(text);
  var pos = 0;
  function peek() {
    return tokens[pos];
  }
  function take(type, value) {
    var token = tokens[pos];
    if (!token || token.type !== type || value !== undefined && token.value !== value) throw new Error(`Invalid AsaDB term near ${(token === null || token === void 0 ? void 0 : token.value) || 'end'}.`);
    pos += 1;
    return token;
  }
  function parseValue() {
    var token = peek();
    if (!token) throw new Error('Unexpected end of AsaDB term.');
    if (token.type === 'sym' && token.value === '[') return parseList();
    if (token.type === 'sym' && token.value === '=') {
      pos += 1;
      return {
        type: 'atom',
        value: '='
      };
    }
    if (token.type === 'number') {
      pos += 1;
      return {
        type: 'number',
        value: Number(token.value)
      };
    }
    if (token.type === 'atom' || token.type === 'ident') {
      var _peek, _peek4;
      pos += 1;
      var node = {
        type: 'atom',
        value: token.value
      };
      if (((_peek = peek()) === null || _peek === void 0 ? void 0 : _peek.type) === 'sym' && peek().value === '(') {
        var _peek2;
        take('sym', '(');
        var args = [];
        if (!(((_peek2 = peek()) === null || _peek2 === void 0 ? void 0 : _peek2.type) === 'sym' && peek().value === ')')) {
          do {
            var _peek3;
            args.push(parseValue());
            if (((_peek3 = peek()) === null || _peek3 === void 0 ? void 0 : _peek3.type) === 'sym' && peek().value === ',') take('sym', ',');else break;
          } while (true);
        }
        take('sym', ')');
        return {
          type: 'compound',
          functor: token.value,
          args
        };
      }
      if (((_peek4 = peek()) === null || _peek4 === void 0 ? void 0 : _peek4.type) === 'sym' && peek().value === '=') {
        take('sym', '=');
        return {
          type: 'pair',
          key: token.value,
          value: parseValue()
        };
      }
      return node;
    }
    throw new Error(`Unexpected token ${token.value}.`);
  }
  function parseList() {
    var _peek5;
    take('sym', '[');
    var items = [];
    if (!(((_peek5 = peek()) === null || _peek5 === void 0 ? void 0 : _peek5.type) === 'sym' && peek().value === ']')) {
      do {
        var _peek6;
        items.push(parseValue());
        if (((_peek6 = peek()) === null || _peek6 === void 0 ? void 0 : _peek6.type) === 'sym' && peek().value === ',') take('sym', ',');else break;
      } while (true);
    }
    take('sym', ']');
    return {
      type: 'list',
      items
    };
  }
  return parseValue();
}
function tokenizeProlog(text) {
  var tokens = [];
  for (var i = 0; i < text.length;) {
    var ch = text[i];
    if (/\s/.test(ch)) {
      i += 1;
      continue;
    }
    if ('[](),='.includes(ch)) {
      tokens.push({
        type: 'sym',
        value: ch
      });
      i += 1;
      continue;
    }
    if (ch === "'") {
      var value = '';
      i += 1;
      while (i < text.length) {
        if (text[i] === '\\') {
          value += text[i + 1] || '';
          i += 2;
          continue;
        }
        if (text[i] === "'") {
          i += 1;
          break;
        }
        value += text[i];
        i += 1;
      }
      tokens.push({
        type: 'atom',
        value
      });
      continue;
    }
    if (/\d/.test(ch) || ch === '-' && /\d/.test(text[i + 1] || '')) {
      var _value2 = ch;
      i += 1;
      while (i < text.length && /[\d.]/.test(text[i])) {
        _value2 += text[i];
        i += 1;
      }
      tokens.push({
        type: 'number',
        value: _value2
      });
      continue;
    }
    if (/[A-Za-z_]/.test(ch)) {
      var _value3 = ch;
      i += 1;
      while (i < text.length && /[\w$]/.test(text[i])) {
        _value3 += text[i];
        i += 1;
      }
      tokens.push({
        type: 'ident',
        value: _value3
      });
      continue;
    }
    if (/[<>!+\-*\/]/.test(ch)) {
      var _value4 = ch;
      i += 1;
      while (i < text.length && /[<>=!+\-*\/]/.test(text[i])) {
        _value4 += text[i];
        i += 1;
      }
      tokens.push({
        type: 'atom',
        value: _value4
      });
      continue;
    }
    throw new Error(`Invalid AsaDB character ${ch}.`);
  }
  return tokens;
}
function prologTermToSandbox(term) {
  var _term$args$;
  if (term.type !== 'compound' || term.functor !== 'state') throw new Error('AsaDB state term expected.');
  var dbs = {};
  var views = {};
  var dbNodes = ((_term$args$ = term.args[1]) === null || _term$args$ === void 0 ? void 0 : _term$args$.items) || [];
  var _iterator33 = _createForOfIteratorHelper(dbNodes),
    _step33;
  try {
    for (_iterator33.s(); !(_step33 = _iterator33.n()).done;) {
      var _dbNode$args$, _dbNode$args$2;
      var dbNode = _step33.value;
      if (dbNode.type !== 'compound' || dbNode.functor !== 'db') continue;
      var dbNameValue = nodeValue(dbNode.args[0]);
      if (!dbNameValue || isSystemDb(dbNameValue)) continue;
      var tables = {};
      var dbViews = {};
      var _iterator34 = _createForOfIteratorHelper(((_dbNode$args$ = dbNode.args[1]) === null || _dbNode$args$ === void 0 ? void 0 : _dbNode$args$.items) || []),
        _step34;
      try {
        for (_iterator34.s(); !(_step34 = _iterator34.n()).done;) {
          var _tableNode$args$, _tableNode$args$2;
          var tableNode = _step34.value;
          if (tableNode.type !== 'compound' || tableNode.functor !== 'table') continue;
          var tableName = nodeValue(tableNode.args[0]);
          var columns = (((_tableNode$args$ = tableNode.args[1]) === null || _tableNode$args$ === void 0 ? void 0 : _tableNode$args$.items) || []).filter(function (n) {
            return n.type === 'compound' && n.functor === 'col';
          }).map(function (col) {
            return {
              name: nodeValue(col.args[0]),
              type: nodeValue(col.args[1]) || 'TEXT'
            };
          });
          var rows = (((_tableNode$args$2 = tableNode.args[2]) === null || _tableNode$args$2 === void 0 ? void 0 : _tableNode$args$2.items) || []).filter(function (n) {
            return n.type === 'compound' && n.functor === 'row';
          }).map(function (rowNode) {
            var _rowNode$args$;
            var row = {};
            var _iterator36 = _createForOfIteratorHelper(((_rowNode$args$ = rowNode.args[0]) === null || _rowNode$args$ === void 0 ? void 0 : _rowNode$args$.items) || []),
              _step36;
            try {
              for (_iterator36.s(); !(_step36 = _iterator36.n()).done;) {
                var pair = _step36.value;
                if (pair.type === 'pair') row[pair.key] = nodeValue(pair.value);
              }
            } catch (err) {
              _iterator36.e(err);
            } finally {
              _iterator36.f();
            }
            return row;
          });
          tables[tableName] = {
            columns,
            rows
          };
        }
      } catch (err) {
        _iterator34.e(err);
      } finally {
        _iterator34.f();
      }
      var _iterator35 = _createForOfIteratorHelper(((_dbNode$args$2 = dbNode.args[2]) === null || _dbNode$args$2 === void 0 ? void 0 : _dbNode$args$2.items) || []),
        _step35;
      try {
        for (_iterator35.s(); !(_step35 = _iterator35.n()).done;) {
          var viewNode = _step35.value;
          if (viewNode.type !== 'compound' || viewNode.functor !== 'view') continue;
          var viewName = nodeValue(viewNode.args[0]);
          if (!viewName) continue;
          dbViews[viewName] = {
            name: viewName,
            query: 'SELECT-backed view',
            columns: [],
            rows: [],
            isView: true
          };
        }
      } catch (err) {
        _iterator35.e(err);
      } finally {
        _iterator35.f();
      }
      dbs[dbNameValue] = tables;
      views[dbNameValue] = dbViews;
    }
  } catch (err) {
    _iterator33.e(err);
  } finally {
    _iterator33.f();
  }
  return normalizeSandbox({
    currentDb: visibleDbNames({
      dbs,
      views
    })[0] || '',
    dbs,
    views
  });
}
function nodeValue(node) {
  if (!node) return null;
  if (node.type === 'number') return node.value;
  if (node.type === 'atom') return node.value === 'null' ? null : node.value;
  return null;
}
function makeXlsx(selection) {
  var workbookSheets = selection.map(function (item, index) {
    return {
      id: index + 1,
      name: safeSheetName(item.name),
      item
    };
  });
  var workbookXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${workbookSheets.map(function (sheet) {
    return `<sheet name="${escapeXml(sheet.name)}" sheetId="${sheet.id}" r:id="rId${sheet.id}"/>`;
  }).join('')}</sheets></workbook>`;
  var workbookRels = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${workbookSheets.map(function (sheet) {
    return `<Relationship Id="rId${sheet.id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${sheet.id}.xml"/>`;
  }).join('')}</Relationships>`;
  var contentTypes = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>${workbookSheets.map(function (sheet) {
    return `<Override PartName="/xl/worksheets/sheet${sheet.id}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`;
  }).join('')}</Types>`;
  var rootRels = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`;
  var entries = [{
    name: '[Content_Types].xml',
    data: utf8(contentTypes)
  }, {
    name: '_rels/.rels',
    data: utf8(rootRels)
  }, {
    name: 'xl/workbook.xml',
    data: utf8(workbookXml)
  }, {
    name: 'xl/_rels/workbook.xml.rels',
    data: utf8(workbookRels)
  }];
  var _iterator37 = _createForOfIteratorHelper(workbookSheets),
    _step37;
  try {
    for (_iterator37.s(); !(_step37 = _iterator37.n()).done;) {
      var sheet = _step37.value;
      entries.push({
        name: `xl/worksheets/sheet${sheet.id}.xml`,
        data: utf8(worksheetXml(sheet.item.table, sheet.item.includeData, sheet.item.includeSchema))
      });
    }
  } catch (err) {
    _iterator37.e(err);
  } finally {
    _iterator37.f();
  }
  return makeZip(entries);
}
function worksheetXml(table, includeData) {
  var includeHeader = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : true;
  var rows = [];
  if (includeHeader) rows.push((table.columns || []).map(function (c) {
    return c.name;
  }));
  if (includeData) {
    var _iterator38 = _createForOfIteratorHelper(table.rows || []),
      _step38;
    try {
      var _loop0 = function _loop0() {
        var row = _step38.value;
        rows.push((table.columns || []).map(function (c) {
          var _row$c$name;
          return (_row$c$name = row[c.name]) !== null && _row$c$name !== void 0 ? _row$c$name : '';
        }));
      };
      for (_iterator38.s(); !(_step38 = _iterator38.n()).done;) {
        _loop0();
      }
    } catch (err) {
      _iterator38.e(err);
    } finally {
      _iterator38.f();
    }
  }
  var xmlRows = rows.map(function (row, rIndex) {
    var cells = row.map(function (value, cIndex) {
      var ref = `${columnName(cIndex + 1)}${rIndex + 1}`;
      if (typeof value === 'number') return `<c r="${ref}"><v>${value}</v></c>`;
      return `<c r="${ref}" t="inlineStr"><is><t>${escapeXml(value !== null && value !== void 0 ? value : '')}</t></is></c>`;
    }).join('');
    return `<row r="${rIndex + 1}">${cells}</row>`;
  }).join('');
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>${xmlRows}</sheetData></worksheet>`;
}
function readXlsxWorkbook(_x29) {
  return _readXlsxWorkbook.apply(this, arguments);
}
function _readXlsxWorkbook() {
  _readXlsxWorkbook = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee42(buffer) {
    var files, workbook, rels, sharedStrings, relMap, _i19, _Array$from4, rel, sheets, _i20, _Array$from5, sheetNode, rid, target;
    return _regenerator().w(function (_context42) {
      while (1) switch (_context42.n) {
        case 0:
          _context42.n = 1;
          return unzip(buffer);
        case 1:
          files = _context42.v;
          workbook = parseXml(decodeFile(files, 'xl/workbook.xml'));
          rels = parseXml(decodeFile(files, 'xl/_rels/workbook.xml.rels'));
          sharedStrings = files['xl/sharedStrings.xml'] ? readSharedStrings(parseXml(decodeFile(files, 'xl/sharedStrings.xml'))) : [];
          relMap = {};
          for (_i19 = 0, _Array$from4 = Array.from(rels.getElementsByTagName('Relationship')); _i19 < _Array$from4.length; _i19++) {
            rel = _Array$from4[_i19];
            relMap[rel.getAttribute('Id')] = rel.getAttribute('Target');
          }
          sheets = [];
          _i20 = 0, _Array$from5 = Array.from(workbook.getElementsByTagName('sheet'));
        case 2:
          if (!(_i20 < _Array$from5.length)) {
            _context42.n = 5;
            break;
          }
          sheetNode = _Array$from5[_i20];
          rid = sheetNode.getAttribute('r:id');
          target = normalizeZipPath(`xl/${relMap[rid] || ''}`);
          if (files[target]) {
            _context42.n = 3;
            break;
          }
          return _context42.a(3, 4);
        case 3:
          sheets.push({
            name: sheetNode.getAttribute('name') || `sheet_${sheets.length + 1}`,
            rows: readWorksheet(parseXml(decodeFile(files, target)), sharedStrings)
          });
        case 4:
          _i20++;
          _context42.n = 2;
          break;
        case 5:
          return _context42.a(2, {
            sheets
          });
      }
    }, _callee42);
  }));
  return _readXlsxWorkbook.apply(this, arguments);
}
function readSharedStrings(xml) {
  return Array.from(xml.getElementsByTagName('si')).map(function (si) {
    return Array.from(si.getElementsByTagName('t')).map(function (t) {
      return t.textContent;
    }).join('');
  });
}
function readWorksheet(xml, sharedStrings) {
  var rows = [];
  for (var _i15 = 0, _Array$from = Array.from(xml.getElementsByTagName('row')); _i15 < _Array$from.length; _i15++) {
    var rowNode = _Array$from[_i15];
    var row = [];
    var nextIndex = 0;
    for (var _i16 = 0, _Array$from2 = Array.from(rowNode.getElementsByTagName('c')); _i16 < _Array$from2.length; _i16++) {
      var cell = _Array$from2[_i16];
      var ref = cell.getAttribute('r');
      var index = ref ? columnIndex(ref.replace(/\d+/g, '')) : nextIndex;
      while (row.length < index) row.push('');
      row[index] = readCell(cell, sharedStrings);
      nextIndex = index + 1;
    }
    rows.push(row);
  }
  return rows;
}
function readCell(cell, sharedStrings) {
  var _cell$getElementsByTa, _cell$getElementsByTa2;
  var type = cell.getAttribute('t');
  if (type === 'inlineStr') return ((_cell$getElementsByTa = cell.getElementsByTagName('t')[0]) === null || _cell$getElementsByTa === void 0 ? void 0 : _cell$getElementsByTa.textContent) || '';
  var value = ((_cell$getElementsByTa2 = cell.getElementsByTagName('v')[0]) === null || _cell$getElementsByTa2 === void 0 ? void 0 : _cell$getElementsByTa2.textContent) || '';
  if (type === 's') return sharedStrings[Number(value)] || '';
  if (type === 'b') return value === '1' ? 'TRUE' : 'FALSE';
  return /^-?\d+(\.\d+)?$/.test(value) ? Number(value) : value;
}
function parseXml(text) {
  var xml = new DOMParser().parseFromString(text, 'application/xml');
  if (xml.getElementsByTagName('parsererror').length) throw new Error('Invalid XML inside XLSX.');
  return xml;
}
function decodeFile(files, name) {
  var file = files[name];
  if (!file) throw new Error(`${name} missing in XLSX.`);
  return new TextDecoder('utf-8').decode(file);
}
function safeSheetName(name) {
  return String(name).replace(/[\[\]*?:/\\]/g, '_').slice(0, 31) || 'Sheet';
}
function columnName(index) {
  var name = '';
  while (index > 0) {
    index -= 1;
    name = String.fromCharCode(65 + index % 26) + name;
    index = Math.floor(index / 26);
  }
  return name;
}
function columnIndex(name) {
  var out = 0;
  var _iterator39 = _createForOfIteratorHelper(name),
    _step39;
  try {
    for (_iterator39.s(); !(_step39 = _iterator39.n()).done;) {
      var ch = _step39.value;
      out = out * 26 + ch.toUpperCase().charCodeAt(0) - 64;
    }
  } catch (err) {
    _iterator39.e(err);
  } finally {
    _iterator39.f();
  }
  return Math.max(0, out - 1);
}
function escapeXml(value) {
  return String(value).replace(/[<>&'"]/g, function (ch) {
    return {
      '<': '&lt;',
      '>': '&gt;',
      '&': '&amp;',
      "'": '&apos;',
      '"': '&quot;'
    }[ch];
  });
}
function makeZip(entries) {
  var localParts = [];
  var centralParts = [];
  var offset = 0;
  var _iterator40 = _createForOfIteratorHelper(entries),
    _step40;
  try {
    for (_iterator40.s(); !(_step40 = _iterator40.n()).done;) {
      var entry = _step40.value;
      var name = utf8(entry.name);
      var data = entry.data instanceof Uint8Array ? entry.data : new Uint8Array(entry.data);
      var crc = crc32(data);
      var local = concatBytes([u32(0x04034b50), u16(20), u16(0), u16(0), u16(0), u16(0), u32(crc), u32(data.length), u32(data.length), u16(name.length), u16(0), name, data]);
      var _central = concatBytes([u32(0x02014b50), u16(20), u16(20), u16(0), u16(0), u16(0), u16(0), u32(crc), u32(data.length), u32(data.length), u16(name.length), u16(0), u16(0), u16(0), u16(0), u32(0), u32(offset), name]);
      localParts.push(local);
      centralParts.push(_central);
      offset += local.length;
    }
  } catch (err) {
    _iterator40.e(err);
  } finally {
    _iterator40.f();
  }
  var central = concatBytes(centralParts);
  var eocd = concatBytes([u32(0x06054b50), u16(0), u16(0), u16(entries.length), u16(entries.length), u32(central.length), u32(offset), u16(0)]);
  return concatBytes([].concat(localParts, [central, eocd]));
}
function unzip(_x30) {
  return _unzip.apply(this, arguments);
}
function _unzip() {
  _unzip = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee43(buffer) {
    var bytes, view, eocd, entries, offset, files, i, method, compressedSize, nameLength, extraLength, commentLength, localOffset, name, localNameLength, localExtraLength, dataStart, compressed, _t43;
    return _regenerator().w(function (_context43) {
      while (1) switch (_context43.n) {
        case 0:
          bytes = new Uint8Array(buffer);
          view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
          eocd = findEocd(view);
          entries = view.getUint16(eocd + 10, true);
          offset = view.getUint32(eocd + 16, true);
          files = {};
          i = 0;
        case 1:
          if (!(i < entries)) {
            _context43.n = 7;
            break;
          }
          if (!(view.getUint32(offset, true) !== 0x02014b50)) {
            _context43.n = 2;
            break;
          }
          throw new Error('Invalid ZIP central directory.');
        case 2:
          method = view.getUint16(offset + 10, true);
          compressedSize = view.getUint32(offset + 20, true);
          nameLength = view.getUint16(offset + 28, true);
          extraLength = view.getUint16(offset + 30, true);
          commentLength = view.getUint16(offset + 32, true);
          localOffset = view.getUint32(offset + 42, true);
          name = new TextDecoder('utf-8').decode(bytes.slice(offset + 46, offset + 46 + nameLength));
          localNameLength = view.getUint16(localOffset + 26, true);
          localExtraLength = view.getUint16(localOffset + 28, true);
          dataStart = localOffset + 30 + localNameLength + localExtraLength;
          compressed = bytes.slice(dataStart, dataStart + compressedSize);
          if (!(method === 0)) {
            _context43.n = 3;
            break;
          }
          _t43 = compressed;
          _context43.n = 5;
          break;
        case 3:
          _context43.n = 4;
          return inflateRaw(compressed);
        case 4:
          _t43 = _context43.v;
        case 5:
          files[normalizeZipPath(name)] = _t43;
          offset += 46 + nameLength + extraLength + commentLength;
        case 6:
          i += 1;
          _context43.n = 1;
          break;
        case 7:
          return _context43.a(2, files);
      }
    }, _callee43);
  }));
  return _unzip.apply(this, arguments);
}
function findEocd(view) {
  for (var offset = view.byteLength - 22; offset >= 0; offset -= 1) {
    if (view.getUint32(offset, true) === 0x06054b50) return offset;
  }
  throw new Error('Invalid ZIP/XLSX file.');
}
function inflateRaw(_x31) {
  return _inflateRaw.apply(this, arguments);
}
function _inflateRaw() {
  _inflateRaw = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee44(bytes) {
    var _i21, _arr3, format, stream, _t44, _t45, _t46;
    return _regenerator().w(function (_context44) {
      while (1) switch (_context44.p = _context44.n) {
        case 0:
          if ('DecompressionStream' in window) {
            _context44.n = 1;
            break;
          }
          throw new Error('Compressed XLSX is not supported by this browser.');
        case 1:
          _i21 = 0, _arr3 = ['deflate-raw', 'deflate'];
        case 2:
          if (!(_i21 < _arr3.length)) {
            _context44.n = 7;
            break;
          }
          format = _arr3[_i21];
          _context44.p = 3;
          stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream(format));
          _t44 = Uint8Array;
          _context44.n = 4;
          return new Response(stream).arrayBuffer();
        case 4:
          _t45 = _context44.v;
          return _context44.a(2, new _t44(_t45));
        case 5:
          _context44.p = 5;
          _t46 = _context44.v;
        case 6:
          _i21++;
          _context44.n = 2;
          break;
        case 7:
          throw new Error('Unable to decompress XLSX entry.');
        case 8:
          return _context44.a(2);
      }
    }, _callee44, null, [[3, 5]]);
  }));
  return _inflateRaw.apply(this, arguments);
}
function normalizeZipPath(path) {
  var parts = [];
  var _iterator41 = _createForOfIteratorHelper(path.replace(/\\/g, '/').split('/')),
    _step41;
  try {
    for (_iterator41.s(); !(_step41 = _iterator41.n()).done;) {
      var part = _step41.value;
      if (!part || part === '.') continue;
      if (part === '..') parts.pop();else parts.push(part);
    }
  } catch (err) {
    _iterator41.e(err);
  } finally {
    _iterator41.f();
  }
  return parts.join('/');
}
function gzipBlob(_x32) {
  return _gzipBlob.apply(this, arguments);
}
function _gzipBlob() {
  _gzipBlob = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee45(blob) {
    var stream, _t47, _t48, _t49, _t50;
    return _regenerator().w(function (_context45) {
      while (1) switch (_context45.n) {
        case 0:
          if ('CompressionStream' in window) {
            _context45.n = 1;
            break;
          }
          throw new Error('gzip is not supported by this browser.');
        case 1:
          stream = blob.stream().pipeThrough(new CompressionStream('gzip'));
          _t47 = Blob;
          _context45.n = 2;
          return new Response(stream).arrayBuffer();
        case 2:
          _t48 = _context45.v;
          _t49 = [_t48];
          _t50 = {
            type: 'application/gzip'
          };
          return _context45.a(2, new _t47(_t49, _t50));
      }
    }, _callee45);
  }));
  return _gzipBlob.apply(this, arguments);
}
function gunzipBuffer(_x33) {
  return _gunzipBuffer.apply(this, arguments);
}
function _gunzipBuffer() {
  _gunzipBuffer = _asyncToGenerator(/*#__PURE__*/_regenerator().m(function _callee46(buffer) {
    var stream;
    return _regenerator().w(function (_context46) {
      while (1) switch (_context46.n) {
        case 0:
          if ('DecompressionStream' in window) {
            _context46.n = 1;
            break;
          }
          throw new Error('gzip import is not supported by this browser.');
        case 1:
          stream = new Blob([buffer]).stream().pipeThrough(new DecompressionStream('gzip'));
          _context46.n = 2;
          return new Response(stream).arrayBuffer();
        case 2:
          return _context46.a(2, _context46.v);
      }
    }, _callee46);
  }));
  return _gunzipBuffer.apply(this, arguments);
}
function crc32(bytes) {
  var crc = -1;
  var _iterator42 = _createForOfIteratorHelper(bytes),
    _step42;
  try {
    for (_iterator42.s(); !(_step42 = _iterator42.n()).done;) {
      var byte = _step42.value;
      crc = crc >>> 8 ^ CRC_TABLE[(crc ^ byte) & 255];
    }
  } catch (err) {
    _iterator42.e(err);
  } finally {
    _iterator42.f();
  }
  return (crc ^ -1) >>> 0;
}
var CRC_TABLE = function () {
  var table = new Uint32Array(256);
  for (var i = 0; i < 256; i += 1) {
    var c = i;
    for (var k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ c >>> 1 : c >>> 1;
    table[i] = c >>> 0;
  }
  return table;
}();
function u16(value) {
  var bytes = new Uint8Array(2);
  new DataView(bytes.buffer).setUint16(0, value, true);
  return bytes;
}
function u32(value) {
  var bytes = new Uint8Array(4);
  new DataView(bytes.buffer).setUint32(0, value >>> 0, true);
  return bytes;
}
function utf8(text) {
  return new TextEncoder().encode(text);
}
function concatBytes(parts) {
  var total = parts.reduce(function (sum, part) {
    return sum + part.length;
  }, 0);
  var out = new Uint8Array(total);
  var offset = 0;
  var _iterator43 = _createForOfIteratorHelper(parts),
    _step43;
  try {
    for (_iterator43.s(); !(_step43 = _iterator43.n()).done;) {
      var part = _step43.value;
      out.set(part, offset);
      offset += part.length;
    }
  } catch (err) {
    _iterator43.e(err);
  } finally {
    _iterator43.f();
  }
  return out;
}
function downloadBlob(blob, filename) {
  var a = document.createElement('a');
  var url = URL.createObjectURL(blob);
  a.href = url;
  a.download = filename;
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(function () {
    return URL.revokeObjectURL(url);
  }, 1000);
}
function openBlob(blob, filename) {
  var url = URL.createObjectURL(blob);
  var opened = window.open(url, '_blank', 'noopener,noreferrer');
  if (!opened) downloadBlob(blob, filename);
  setTimeout(function () {
    return URL.revokeObjectURL(url);
  }, 60000);
}
function sanitizeName(value) {
  var name = String(value || '').trim().replace(/\.[^.]+$/, '').replace(/[^\w$]+/g, '_').replace(/^_+|_+$/g, '');
  return name || 'imported_table';
}
function sanitizeIdentifier(value) {
  return String(value || '').trim().replace(/[^\w$]+/g, '_').replace(/^_+|_+$/g, '');
}
function baseName(path) {
  return String(path || '').split(/[\\/]/).pop().replace(/\.gz$/i, '').replace(/\.[^.]+$/, '');
}
function selectedSqlLineRange(value, start, end) {
  var lineStart = start === 0 ? 0 : value.lastIndexOf('\n', start - 1) + 1;
  var lineEnd = end;
  if (end > start && value[end - 1] === '\n') lineEnd -= 1;
  var nextBreak = value.indexOf('\n', Math.max(lineEnd, lineStart));
  return {
    lineStart,
    lineEnd: nextBreak === -1 ? value.length : nextBreak
  };
}
function setSqlSelection(start) {
  var end = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : start;
  sqlInput.setSelectionRange(Math.max(0, start), Math.max(0, end));
  updateSqlEditor();
  scheduleSqlAnalysis();
}
function indentSqlSelection() {
  var _sqlInput$selectionSt3, _sqlInput$selectionEn;
  var value = sqlInput.value;
  var start = (_sqlInput$selectionSt3 = sqlInput.selectionStart) !== null && _sqlInput$selectionSt3 !== void 0 ? _sqlInput$selectionSt3 : 0;
  var end = (_sqlInput$selectionEn = sqlInput.selectionEnd) !== null && _sqlInput$selectionEn !== void 0 ? _sqlInput$selectionEn : start;
  if (start === end) {
    sqlInput.value = `${value.slice(0, start)}${SQL_INDENT}${value.slice(end)}`;
    setSqlSelection(start + SQL_INDENT.length);
    return;
  }
  var _selectedSqlLineRange = selectedSqlLineRange(value, start, end),
    lineStart = _selectedSqlLineRange.lineStart,
    lineEnd = _selectedSqlLineRange.lineEnd;
  var block = value.slice(lineStart, lineEnd);
  var lines = block.split('\n');
  var indented = lines.map(function (line) {
    return `${SQL_INDENT}${line}`;
  }).join('\n');
  sqlInput.value = `${value.slice(0, lineStart)}${indented}${value.slice(lineEnd)}`;
  setSqlSelection(start + SQL_INDENT.length, end + SQL_INDENT.length * lines.length);
}
function leadingIndentWidth(line) {
  if (line.startsWith('\t')) return 1;
  var spaces = /^ {1,4}/.exec(line);
  return spaces ? spaces[0].length : 0;
}
function unindentSqlSelection() {
  var _sqlInput$selectionSt4, _sqlInput$selectionEn2;
  var value = sqlInput.value;
  var start = (_sqlInput$selectionSt4 = sqlInput.selectionStart) !== null && _sqlInput$selectionSt4 !== void 0 ? _sqlInput$selectionSt4 : 0;
  var end = (_sqlInput$selectionEn2 = sqlInput.selectionEnd) !== null && _sqlInput$selectionEn2 !== void 0 ? _sqlInput$selectionEn2 : start;
  var _selectedSqlLineRange2 = selectedSqlLineRange(value, start, end),
    lineStart = _selectedSqlLineRange2.lineStart,
    lineEnd = _selectedSqlLineRange2.lineEnd;
  var block = value.slice(lineStart, lineEnd);
  var lines = block.split('\n');
  var offset = lineStart;
  var removedBeforeStart = 0;
  var removedBeforeEnd = 0;
  var unindented = lines.map(function (line) {
    var removeCount = leadingIndentWidth(line);
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
  if (event.shiftKey) unindentSqlSelection();else indentSqlSelection();
  return true;
}
sqlInput.addEventListener('paste', function () {
  sqlPasteInProgress = true;
  sqlPasteAnchor = {
    top: sqlInput.scrollTop,
    left: sqlInput.scrollLeft
  };
  requestAnimationFrame(function () {
    sqlPasteInProgress = false;
  });
});
sqlInput.addEventListener('input', function (event) {
  var pasted = sqlPasteInProgress || event.inputType === 'insertFromPaste';
  if (!pasted) applySqlAutoCorrection(false);
  var scrollTop = pasted ? Math.max(sqlPasteAnchor.top, sqlInput.scrollTop, sqlCaretScrollTarget()) : sqlInput.scrollTop;
  var scrollLeft = pasted ? Math.max(sqlPasteAnchor.left, sqlInput.scrollLeft) : sqlInput.scrollLeft;
  updateSqlEditor({
    scrollTop,
    scrollLeft,
    persistScroll: pasted
  });
  scheduleSqlAnalysis();
  updateSqlCompletions();
});
sqlInput.addEventListener('scroll', syncSqlScroll);
sqlInput.addEventListener('keydown', function (event) {
  if (sqlCompletionState.open) {
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      var direction = event.key === 'ArrowDown' ? 1 : -1;
      sqlCompletionState.active = (sqlCompletionState.active + direction + sqlCompletionState.items.length) % sqlCompletionState.items.length;
      renderSqlCompletions();
      return;
    }
    if (event.key === 'Enter' || event.key === 'Tab') {
      event.preventDefault();
      applySqlCompletion();
      return;
    }
    if (event.key === 'Escape') {
      event.preventDefault();
      closeSqlCompletions();
      return;
    }
  }
  if ((event.ctrlKey || event.metaKey) && event.key === ' ') {
    event.preventDefault();
    updateSqlCompletions(true);
    return;
  }
  if (handleSqlIndentKey(event)) return;
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
    event.preventDefault();
    runSql();
  }
});
sqlInput.addEventListener('click', function () {
  updateSqlCompletions();
});
sqlInput.addEventListener('keyup', function (event) {
  if (['ArrowDown', 'ArrowUp', 'Enter', 'Tab', 'Escape'].indexOf(event.key) === -1) updateSqlCompletions();
});
sqlInput.addEventListener('blur', function () {
  setTimeout(closeSqlCompletions, 120);
});
runBtn.addEventListener('click', runSql);
languageSwitcher === null || languageSwitcher === void 0 || languageSwitcher.addEventListener('click', function (event) {
  var button = event.target.closest('[data-language]');
  if (button) setLanguage(button.dataset.language);
});
$('pingBtn').addEventListener('click', checkEngine);
$('clearBtn').addEventListener('click', function () {
  return setSqlText('');
});
$('clearLogBtn').addEventListener('click', function () {
  return logBox.textContent = '';
});
$('resetSandboxBtn').addEventListener('click', function () {
  localStorage.removeItem(SANDBOX_STORAGE_KEY);
  localStorage.removeItem(LEGACY_SANDBOX_STORAGE_KEY);
  sandbox = createInitialSandbox();
  saveSandbox();
  selectedTable = '';
  renderTableBrowser();
  setSqlText('');
  log(t('sandbox.resetDone'));
});
$('loadSampleBtn').addEventListener('click', function () {
  setSqlText(`CREATE DATABASE ${SAMPLE_DB};\nUSE ${SAMPLE_DB};\nCREATE TABLE users (id INT NOT NULL, user_login VARCHAR(100), display_name VARCHAR(120), status VARCHAR(20) DEFAULT 'active');\nINSERT INTO users (id, user_login, display_name, status) VALUES (1, 'aires', 'Aires Admin', 'active'), (2, 'asa', 'Asa Editor', 'active');\nSELECT * FROM users;`);
  dbName.value = SAMPLE_DB;
  showView('sql');
});
$('createDbBtn').addEventListener('click', createDatabase);
saveDbBtn.addEventListener('click', saveCurrentDatabase);
dropDbBtn.addEventListener('click', dropCurrentDatabase);
dbSelect.addEventListener('change', function () {
  return selectDatabaseByName(dbSelect.value);
});
$('sqlCommandBtn').addEventListener('click', focusSqlCommand);
$('createTableBtn').addEventListener('click', insertCreateTableTemplate);
$('importViewBtn').addEventListener('click', function () {
  return showView('import');
});
$('exportViewBtn').addEventListener('click', function () {
  return showView('export');
});
tableSelectDataBtn.addEventListener('click', function () {
  return selectedTable && renderTableDetail(selectedTable, 'data');
});
tableShowStructureBtn.addEventListener('click', function () {
  return selectedTable && renderTableDetail(selectedTable, 'structure');
});
tableAlterBtn.addEventListener('click', function () {
  if (!selectedTable) return;
  var table = currentTable(selectedTable);
  var columns = ((table === null || table === void 0 ? void 0 : table.columns) || []).map(function (col) {
    return `  ${quoteIdent(col.name)} ${col.type || 'TEXT'}`;
  }).join(',\n');
  setSqlText(`CREATE TABLE ${quoteIdent(selectedTable)} (\n${columns}\n);`);
  focusSqlCommand();
});
tableNewItemBtn.addEventListener('click', function () {
  if (!selectedTable) return;
  var table = currentTable(selectedTable);
  var columns = ((table === null || table === void 0 ? void 0 : table.columns) || []).map(function (col) {
    return col.name;
  });
  setSqlText(`INSERT INTO ${quoteIdent(selectedTable)} (${columns.map(quoteIdent).join(', ')}) VALUES (${columns.map(function () {
    return 'NULL';
  }).join(', ')});`);
  focusSqlCommand();
});
tableDropBtn.addEventListener('click', function () {
  return selectedTable && dropTable(selectedTable);
});
importExecuteBtn.addEventListener('click', importFromFiles);
importRunServerBtn.addEventListener('click', importFromServerFile);
importCancelBtn.addEventListener('click', cancelActiveReservoirJob);
dbMetadataPanel === null || dbMetadataPanel === void 0 || dbMetadataPanel.addEventListener('toggle', function () {
  if (dbMetadataPanel.open) scheduleMetadataPoll(0);
});
document.addEventListener('visibilitychange', function () {
  if (document.visibilityState !== 'hidden') scheduleMetadataPoll(0);
});
window.addEventListener('focus', function () {
  return scheduleMetadataPoll(0);
});
// Keep the checked-in ES5 bundle on the production backup path as well.  The
// readable app.js is the source of truth; this small adapter avoids rebuilding
// the entire Babel bundle on installations without Node.js.
function exportDatabaseProduction() {
  var format = checkedValue('exportFormat');
  var output = checkedValue('exportOutput');
  if (backendOnline) {
    try {
      exportDatabaseFromBackendLegacy(output);
    } catch (err) {
      exportPreview.textContent = ASA_ERROR_LABEL + ': ' + asaErrorCopy(err.message);
      log(t('log.exportFailed', {
        error: err.message
      }));
    }
    return;
  }
  if (format === 'asadb') {
    var message = t('export.backendRequired');
    exportPreview.textContent = ASA_ERROR_LABEL + ': ' + message;
    log(t('log.exportFailed', {
      error: message
    }));
    return;
  }
  exportDatabase();
}
function exportDatabaseFromBackendLegacy(output) {
  var db = ensureCurrentDb('export');
  if (!db) throw new Error(t('database.selectFirst'));
  var form = document.createElement('form');
  form.method = 'post';
  form.action = '/api/backup';
  form.style.display = 'none';
  if (output === 'open') form.target = '_blank';
  var databaseInput = document.createElement('input');
  databaseInput.type = 'hidden';
  databaseInput.name = 'database';
  databaseInput.value = db;
  form.appendChild(databaseInput);
  var outputInput = document.createElement('input');
  outputInput.type = 'hidden';
  outputInput.name = 'output';
  outputInput.value = output === 'open' ? 'open' : 'save';
  form.appendChild(outputInput);
  document.body.appendChild(form);
  form.submit();
  window.setTimeout(function () {
    if (form.parentNode) form.parentNode.removeChild(form);
  }, 0);
  var filename = db + '.asb';
  exportPreview.textContent = t('export.productionReady', {
    name: filename
  });
  log(t('export.productionReady', {
    name: filename
  }));
}
exportRunBtn.addEventListener('click', exportDatabaseProduction);
createTableForm.addEventListener('submit', saveCreateTable);
createAddHeaderBtn.addEventListener('click', function () {
  return addCreateColumnRow({
    type: 'int'
  });
});
createAutoIncrementHelpBtn.addEventListener('click', function (event) {
  event.stopPropagation();
  var nextHidden = !autoIncrementHelpPopover.hidden;
  autoIncrementHelpPopover.hidden = nextHidden;
  createAutoIncrementHelpBtn.setAttribute('aria-expanded', String(!nextHidden));
});
document.addEventListener('click', function (event) {
  if (autoIncrementHelpPopover.hidden) return;
  if (event.target.closest('#autoIncrementHelpPopover') || event.target.closest('#createAutoIncrementHelpBtn')) return;
  autoIncrementHelpPopover.hidden = true;
  createAutoIncrementHelpBtn.setAttribute('aria-expanded', 'false');
});
document.addEventListener('keydown', function (event) {
  if (event.key === 'Escape' && !autoIncrementHelpPopover.hidden) {
    autoIncrementHelpPopover.hidden = true;
    createAutoIncrementHelpBtn.setAttribute('aria-expanded', 'false');
  }
});
createColumnsBody.addEventListener('click', function (event) {
  var button = event.target.closest('button');
  if (!button) return;
  var row = button.closest('tr');
  if (button.classList.contains('create-row-add')) {
    addCreateColumnRow({
      type: 'int'
    });
  } else if (button.classList.contains('create-row-up') && row.previousElementSibling) {
    createColumnsBody.insertBefore(row, row.previousElementSibling);
  } else if (button.classList.contains('create-row-down') && row.nextElementSibling) {
    createColumnsBody.insertBefore(row.nextElementSibling, row);
  } else if (button.classList.contains('create-row-delete')) {
    if (createColumnsBody.rows.length > 1) row.remove();
  }
});
tableSearch.addEventListener('input', function () {
  tableListVisibleLimit = TABLE_LIST_PAGE_SIZE;
  renderTableBrowser();
});
tableList.addEventListener('click', function (event) {
  var drop = event.target.closest('[data-drop-table]');
  if (drop) {
    event.preventDefault();
    event.stopPropagation();
    dropTable(drop.dataset.dropTable);
    return;
  }
  var button = event.target.closest('[data-table]');
  if (button) selectTable(button.dataset.table);
});
exportAllTables.addEventListener('change', function () {
  document.querySelectorAll('.export-table-check').forEach(function (input) {
    return input.checked = exportAllTables.checked;
  });
});
exportAllData.addEventListener('change', function () {
  document.querySelectorAll('.export-data-check').forEach(function (input) {
    return input.checked = exportAllData.checked;
  });
});
setLanguage(currentLanguage, false);
updateSqlEditor();
setSqlDiagnostics(analyzeSqlClient(sqlInput.value));
renderTableBrowser();
var initialHash = location.hash.slice(1);
if (initialHash.startsWith('table=')) {
  var tableName = decodeURIComponent(initialHash.slice('table='.length));
  if (currentRelation(tableName)) renderTableDetail(tableName, 'structure');else showView('sql');
} else if (views[initialHash]) {
  if (initialHash === 'create') showCreateTableView();else showView(initialHash);
} else {
  showView('sql');
}
// app-loader.js uses this marker to show a useful error rather than leaving a
// static-looking page should an unsupported browser reject the UI bundle.
window.__asadbUiReady = true;
runStartupWarmup(checkEngine());
