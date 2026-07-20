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
const STARTUP_WARMUP_MS = 650;
const LARGE_SQL_EDITOR_CHAR_LIMIT = 180000;
const LARGE_SQL_EDITOR_LINE_LIMIT = 4000;
const SQL_EDITOR_LINE_HEIGHT = 20.15;
const RESERVOIR_POLL_INTERVAL_MS = 120;
const METADATA_ACTIVE_POLL_INTERVAL_MS = 500;
const METADATA_OPEN_POLL_INTERVAL_MS = 1500;
const METADATA_IDLE_POLL_INTERVAL_MS = 5000;
const RESULT_PAGE_SIZE = 500;
const TABLE_LIST_PAGE_SIZE = 120;
const ACTIVE_RESERVOIR_STORAGE_KEY = 'asadb-active-reservoir-job-v1';
const LANGUAGE_STORAGE_KEY = 'asadb-language';

const LANGUAGE_LOCALES = { id: 'id-ID', ja: 'ja-JP', en: 'en-US' };
const LANGUAGE_HTML = { id: 'id', ja: 'ja', en: 'en' };

const I18N = {
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
    'common.viewKind': 'view',
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
    'common.viewKind': 'view',
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
    'common.viewKind': 'ビュー',
  },
};

function loadLanguage() {
  try {
    const saved = localStorage.getItem(LANGUAGE_STORAGE_KEY);
    return Object.prototype.hasOwnProperty.call(I18N, saved) ? saved : 'id';
  } catch (_) {
    return 'id';
  }
}

let currentLanguage = loadLanguage();

function t(key, values = {}) {
  const template = I18N[currentLanguage]?.[key] ?? I18N.id[key] ?? key;
  return String(template).replace(/\{([A-Za-z0-9_]+)\}/g, (_, name) => String(values[name] ?? `{${name}}`));
}

const FORMAT_LABELS = {
  asadb: 'AsaDB',
  csv: 'CSV',
  xlsx: 'XLSX',
  postgresql: 'PostgreSQL',
  mysql: 'MySQL',
};

const startupLoader = $('startupLoader');

let ASA_OK_LABEL = 'Asa Terima \uD83D\uDE33';
let ASA_ERROR_LABEL = 'Asa Tidak Suka! \uD83D\uDE21';
let ASA_CORRECTION_LABEL = 'Asa Mau Koreksi \uD83E\uDD14';
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
let asaRunAudioChannel = null;
let asaRunAudioGeneration = 0;

let ASA_ERROR_OPENERS = [
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

let ASA_CORRECTION_OPENERS = [
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

let ASA_SUCCESS_OPENERS = [
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

const ASA_LANGUAGE_COPY = {
  id: {
    okLabel: 'Asa Terima \uD83D\uDE33',
    errorLabel: 'Asa Tidak Suka! \uD83D\uDE21',
    correctionLabel: 'Asa Mau Koreksi \uD83E\uDD14',
    errors: [...ASA_ERROR_OPENERS],
    corrections: [...ASA_CORRECTION_OPENERS],
    successes: [...ASA_SUCCESS_OPENERS],
  },
  en: {
    okLabel: 'Asa Approves \uD83D\uDE33',
    errorLabel: "Asa Doesn't Like That! \uD83D\uDE21",
    correctionLabel: 'Asa Suggests a Fix \uD83E\uDD14',
    errors: [
      'Asa stopped here because one part does not connect yet.',
      'Asa got stuck here, but this can still be fixed.',
      'Asa cannot safely accept this form yet.',
      'Asa found a break in the execution path.',
      'Asa suspects that one piece is missing.',
      'Asa paused before the data could change incorrectly.',
      'Asa needs a clearer SQL sentence first.',
      'Asa found a token that interrupts the command.',
    ],
    corrections: [
      'Asa has a small suggestion.',
      'Asa wants to tidy this up a little.',
      'Asa thinks this is almost right.',
      'Asa suspects this is only a typo.',
      'Asa can straighten this out.',
      'Asa found one part that can be polished.',
    ],
    successes: [
      'Asa accepted this happily.',
      'Asa ran it and the result is safe.',
      'Asa agrees; the command went through.',
      'Asa completed this part successfully.',
      'Asa accepted this SQL form.',
      'Asa has the result ready.',
    ],
  },
  ja: {
    okLabel: 'アサは受け入れました \uD83D\uDE33',
    errorLabel: 'アサは気に入りません！ \uD83D\uDE21',
    correctionLabel: 'アサから修正案 \uD83E\uDD14',
    errors: [
      'まだつながっていない部分があるため、アサはここで止まりました。',
      'アサはここで詰まりましたが、まだ修正できます。',
      'アサはこの形を安全に受け入れられません。',
      'アサは実行経路が切れている箇所を見つけました。',
      'アサは何か一つ足りないと考えています。',
      'データを誤って変更しないよう、アサは実行を止めました。',
      'アサには、もう少し明確な SQL が必要です。',
      'アサはコマンドを中断するトークンを見つけました。',
    ],
    corrections: [
      'アサから小さな提案があります。',
      'アサが少し整えます。',
      'アサには、ほぼ正しく見えます。',
      'アサは単純な入力ミスだと考えています。',
      'アサが正しい形に直せます。',
      'アサは改善できる箇所を見つけました。',
    ],
    successes: [
      'アサは喜んで受け入れました。',
      'アサが実行し、結果の安全を確認しました。',
      'アサは同意しました。コマンドは正常です。',
      'アサはこの処理を完了しました。',
      'アサはこの SQL を受け入れました。',
      'アサが結果を用意しました。',
    ],
  },
};

function syncAsaLanguageCopy() {
  const copy = ASA_LANGUAGE_COPY[currentLanguage] || ASA_LANGUAGE_COPY.id;
  ASA_OK_LABEL = copy.okLabel;
  ASA_ERROR_LABEL = copy.errorLabel;
  ASA_CORRECTION_LABEL = copy.correctionLabel;
  ASA_ERROR_OPENERS = [...copy.errors];
  ASA_CORRECTION_OPENERS = [...copy.corrections];
  ASA_SUCCESS_OPENERS = [...copy.successes];
}

const sqlInput = $('sqlInput');
const sqlEditor = $('sqlEditor');
const sqlHighlight = $('sqlHighlight');
const sqlLineNumbers = $('sqlLineNumbers');
const sqlLineNumbersContent = $('sqlLineNumbersContent');
const sqlDiagnostics = $('sqlDiagnostics');
const sqlCompletions = $('sqlCompletions');
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
const dbMetadataPanel = $('dbMetadataPanel');
const metadataState = $('metadataState');
const metadataEngine = $('metadataEngine');
const metadataIdentity = $('metadataIdentity');
const metadataObjects = $('metadataObjects');
const metadataRows = $('metadataRows');
const metadataStorage = $('metadataStorage');
const metadataCache = $('metadataCache');
const metadataCheckpoint = $('metadataCheckpoint');
const metadataReservoir = $('metadataReservoir');
const languageSwitcher = $('languageSwitcher');

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
const importProgressPanel = $('importProgressPanel');
const importProgressLabel = $('importProgressLabel');
const importProgressPercent = $('importProgressPercent');
const importProgressBar = $('importProgressBar');
const importProgressStatus = $('importProgressStatus');
const importCancelBtn = $('importCancelBtn');

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
let engineCheckCompleted = false;
let selectedTable = '';
let currentViewName = 'sql';
let currentTableDetailMode = 'structure';
let lastDatabaseMetadata = null;
let lastRenderedResults = [];
let lastRunState = { key: 'sql.noQuery', values: {}, raw: '' };
let sandbox = loadSandbox();
let sqlDiagnosticsState = [];
let sqlAnalyzeTimer = 0;
let sqlAnalyzeRequest = 0;
let sqlRunPromise = null;
let activeReservoirJobId = '';
let activeReservoirDescriptor = null;
let lastReservoirSnapshot = null;
let reservoirResumePromise = null;
let reservoirCancelPromise = null;
let importOperationPromise = null;
let metadataRefreshPromise = null;
let metadataPollTimer = 0;
let lastMetadataRefreshAt = 0;
let tableListVisibleLimit = TABLE_LIST_PAGE_SIZE;
let tableListObserver = null;
let resultPageContext = null;
let resultPagePromises = new Map();
let tableDataPageState = null;
let tableDetailRequestId = 0;
let asaRunPrimePromise = null;
let sqlLineRenderFrame = 0;
let sqlScrollRestoreFrame = 0;
let sqlPasteInProgress = false;
let sqlPasteAnchor = { top: 0, left: 0 };
let sqlEditorMetrics = { lineCount: 1, large: false, textLength: 0 };
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

function applyStaticTranslations() {
  document.documentElement.lang = LANGUAGE_HTML[currentLanguage] || LANGUAGE_HTML.id;
  document.title = t('document.title');
  document.querySelectorAll('[data-i18n]').forEach((node) => {
    node.textContent = t(node.dataset.i18n);
  });
  for (const [attribute, dataName] of [
    ['placeholder', 'i18nPlaceholder'],
    ['title', 'i18nTitle'],
    ['aria-label', 'i18nAriaLabel'],
  ]) {
    document.querySelectorAll(`[data-${dataName.replace(/[A-Z]/g, value => `-${value.toLowerCase()}`)}]`).forEach((node) => {
      node.setAttribute(attribute, t(node.dataset[dataName]));
    });
  }
  languageSwitcher?.querySelectorAll('[data-language]').forEach((button) => {
    const active = button.dataset.language === currentLanguage;
    button.classList.toggle('active', active);
    button.setAttribute('aria-pressed', String(active));
  });
}

function updatePageTitle() {
  const key = currentViewName === 'table' ? 'page.tableDetail' :
    currentViewName === 'create' ? 'page.create' :
    currentViewName === 'import' ? 'page.import' :
    currentViewName === 'export' ? 'page.export' :
    'page.sql';
  pageTitle.textContent = t(key);
}

function updateEngineStatus() {
  const key = !engineCheckCompleted ? 'mode.detecting' : backendOnline ? 'mode.backend' : 'mode.sandbox';
  engineStatus.textContent = t(key);
  engineStatus.className = !engineCheckCompleted ? 'status muted' : backendOnline ? 'status ok' : 'status warn';
}

function localizedRelationKind(kind) {
  return t(kind === 'view' ? 'common.viewKind' : 'common.tableKind');
}

function renderLastRunState() {
  const values = { ...lastRunState.values };
  if (typeof values.count === 'number') values.count = formatNumber(values.count);
  lastRun.textContent = lastRunState.key ? t(lastRunState.key, values) : lastRunState.raw;
}

function setLastRunKey(key, values = {}) {
  lastRunState = { key, values, raw: '' };
  renderLastRunState();
}

function setLastRunRaw(raw) {
  lastRunState = { key: '', values: {}, raw: String(raw) };
  renderLastRunState();
}

function setLanguage(language, persist = true) {
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
  if (lastRenderedResults.length) renderResults(lastRenderedResults, { remember: false, archive: false });
  if (currentViewName === 'table' && selectedTable && currentRelation(selectedTable)) {
    renderTableDetail(selectedTable, currentTableDetailMode);
  }
}

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

const SQL_FUNCTIONS = new Set(['count', 'max', 'min', 'sum', 'avg', 'lower', 'upper', 'length', 'concat', 'substr', 'substring', 'trim', 'replace', 'coalesce', 'now', 'current_timestamp']);

// Keep the editor self-contained: catalog names come from the normal panel
// refresh, so suggestions never need a request for each keystroke.
const SQL_COMPLETION_KEYWORDS = [
  'ADD', 'AFTER', 'ALL', 'ALTER', 'ANALYZE', 'AND', 'AS', 'ASC', 'AUTO_INCREMENT', 'BEGIN', 'BEFORE', 'BETWEEN', 'BY',
  'CASCADE', 'CASE', 'CHANGE', 'CHECK', 'COLLATE', 'COLUMN', 'COLUMNS', 'COMMENT',
  'COMMIT', 'CONSTRAINT', 'CREATE', 'DATABASE', 'DATABASES', 'DEFAULT',
  'DELETE', 'DESC', 'DESCRIBE', 'DISTINCT', 'DROP', 'EACH', 'ELSE', 'END', 'ENGINE', 'EXISTS',
  'EXPLAIN', 'FALSE', 'FOR', 'FOREIGN', 'FROM', 'FULL', 'FUNCTION', 'GRANT',
  'GRANTS', 'GROUP', 'HAVING', 'IDENTIFIED', 'IF', 'IN', 'INOUT', 'INDEX', 'INDEXES',
  'INNER', 'INSERT', 'INTO', 'IS', 'JOIN', 'KEY', 'KEYS', 'LEFT', 'LIKE',
  'LIMIT', 'LOCK', 'LOGIN', 'MODIFY', 'NOT', 'NULL', 'OFFSET', 'ON', 'OR',
  'ORDER', 'OUT', 'OUTER', 'PASSWORD', 'PRIMARY', 'PROCEDURE', 'REFERENCES',
  'RENAME', 'REPLACE', 'RETURN', 'RETURNS', 'REVOKE', 'RIGHT', 'ROLLBACK', 'ROW', 'SELECT', 'SET',
  'SHOW', 'START', 'TABLE', 'TABLES', 'THEN', 'TO', 'TRANSACTION', 'TRUE',
  'TRIGGER', 'TRUNCATE', 'UNION', 'UNIQUE', 'UNLOCK', 'UPDATE', 'USE', 'USER',
  'USING', 'VALUES', 'VIEW', 'WHEN', 'WHERE', 'WITH',
];

// The parser's SQL vocabulary is also the highlighter vocabulary. Keep types
// and functions in the set for recognition, then give them their own colour
// class when rendering below.
for (const word of SQL_COMPLETION_KEYWORDS) SQL_KEYWORDS.add(word.toLowerCase());
for (const type of SQL_TYPES) SQL_KEYWORDS.add(type);
for (const functionName of SQL_FUNCTIONS) SQL_KEYWORDS.add(functionName);

let sqlCompletionState = { open: false, items: [], active: 0, start: 0, end: 0 };
let sqlCompletionCanvas = null;

function sqlCompletionIcon(kind) {
  return kind === 'column' ? '⊟' : kind === 'table' ? '▤' : kind === 'view' ? '◫' :
    kind === 'function' ? 'ƒ' : kind === 'type' ? 'T' : kind === 'database' ? '●' : '›';
}

function sqlCompletionIdentifier(name) {
  const text = String(name || '');
  return /^[A-Za-z_][\w$]*$/.test(text) ? text : `\`${text.replace(/`/g, '``')}\``;
}

function sqlCompletionRelation(name) {
  const db = sandbox.dbs?.[currentDbName()] || {};
  const viewsForDb = sandbox.views?.[currentDbName()] || {};
  const key = Object.keys(db).find(item => item.toLowerCase() === String(name).toLowerCase());
  if (key) return { kind: 'table', name: key, value: db[key] };
  const viewKey = Object.keys(viewsForDb).find(item => item.toLowerCase() === String(name).toLowerCase());
  return viewKey ? { kind: 'view', name: viewKey, value: viewsForDb[viewKey] } : null;
}

function sqlCompletionAliases(statement) {
  const aliases = new Map();
  const relationPattern = /\b(?:from|join|update|into|table|references)\s+(`[^`]+`|[A-Za-z_][\w$]*)(?:\s+(?:as\s+)?([A-Za-z_][\w$]*))?/gi;
  let match;
  while ((match = relationPattern.exec(statement))) {
    const relationName = match[1].replace(/^`|`$/g, '');
    const relation = sqlCompletionRelation(relationName);
    if (!relation) continue;
    aliases.set(relationName.toLowerCase(), relation);
    const alias = match[2]?.toLowerCase();
    if (alias && !SQL_KEYWORDS.has(alias)) aliases.set(alias, relation);
  }
  return aliases;
}

function sqlCompletionInsideLiteral(text) {
  let quote = '';
  let blockComment = false;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];
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
    if (char === '-' && next === '-') {
      const end = text.indexOf('\n', index + 2);
      index = end < 0 ? text.length : end;
      continue;
    }
    if (char === '#') {
      const end = text.indexOf('\n', index + 1);
      index = end < 0 ? text.length : end;
      continue;
    }
    if (char === "'" || char === '"' || char === '`') quote = char;
  }
  return Boolean(quote || blockComment);
}

function sqlCompletionToken() {
  const caret = sqlInput.selectionStart ?? sqlInput.value.length;
  const before = sqlInput.value.slice(0, caret);
  const match = /([A-Za-z_][\w$]*)$/.exec(before);
  const prefix = match?.[1] || '';
  const start = caret - prefix.length;
  const statementStart = before.lastIndexOf(';') + 1;
  const statement = before.slice(statementStart);
  const qualified = /([A-Za-z_][\w$]*)\.\s*([A-Za-z_][\w$]*)?$/.exec(statement);
  return { caret, start, prefix, statement, qualified, beforeToken: before.slice(statementStart, start) };
}

function sqlCompletionCatalogItems(relation) {
  return (relation?.value?.columns || []).map(column => ({
    label: String(column.name), insert: sqlCompletionIdentifier(column.name), kind: 'column',
    detail: String(column.type || 'TEXT'),
  }));
}

function sqlCompletionItems(token) {
  const prefix = token.prefix.toLowerCase();
  const add = (items, label, insert, kind, detail = '') => {
    const key = `${kind}:${label}`.toLowerCase();
    if (!items.some(item => `${item.kind}:${item.label}`.toLowerCase() === key)) items.push({ label, insert, kind, detail });
  };
  const items = [];
  const aliases = sqlCompletionAliases(token.statement);
  const qualifier = token.qualified?.[1]?.toLowerCase();
  if (qualifier) {
    for (const item of sqlCompletionCatalogItems(aliases.get(qualifier) || sqlCompletionRelation(qualifier))) add(items, item.label, item.insert, item.kind, item.detail);
  } else {
    const context = token.beforeToken.trim();
    const wantsRelation = /\b(?:from|join|update|into|table|describe|desc|truncate)\s*$/i.test(context) ||
      /\b(?:create|drop)\s+(?:unique\s+)?index\b[\s\S]*\bon\s*$/i.test(context) ||
      /\b(?:create|drop)\s+trigger\b[\s\S]*\bon\s*$/i.test(context);
    const wantsDatabase = /\b(?:use|database)\s*$/i.test(context);
    const activeDb = sandbox.dbs?.[currentDbName()] || {};
    const activeViews = sandbox.views?.[currentDbName()] || {};
    if (wantsDatabase) {
      for (const name of visibleDbNames(sandbox)) add(items, name, sqlCompletionIdentifier(name), 'database', 'database');
    } else if (wantsRelation) {
      for (const [name] of Object.entries(activeDb)) add(items, name, sqlCompletionIdentifier(name), 'table', 'table');
      for (const [name] of Object.entries(activeViews)) add(items, name, sqlCompletionIdentifier(name), 'view', 'view');
    } else {
      for (const relation of Object.values(activeDb)) {
        for (const item of sqlCompletionCatalogItems({ kind: 'table', value: relation })) add(items, item.label, item.insert, item.kind, item.detail);
      }
      for (const name of SQL_FUNCTIONS) add(items, name.toUpperCase(), `${name.toUpperCase()}()`, 'function', 'function');
      for (const type of SQL_TYPES) add(items, type.toUpperCase(), type.toUpperCase(), 'type', 'type');
      for (const keyword of SQL_COMPLETION_KEYWORDS) add(items, keyword, keyword, 'keyword', 'keyword');
    }
  }
  const rank = item => {
    const label = item.label.toLowerCase();
    if (!prefix) return 1;
    if (label.startsWith(prefix)) return 0;
    return label.includes(prefix) ? 2 : 9;
  };
  return items.filter(item => rank(item) < 9).sort((a, b) => rank(a) - rank(b) || a.label.localeCompare(b.label)).slice(0, 18);
}

function positionSqlCompletions() {
  if (!sqlCompletionState.open) return;
  const caret = sqlCompletionState.end;
  const lineStart = sqlInput.value.lastIndexOf('\n', caret - 1) + 1;
  const line = sqlInput.value.slice(lineStart, caret).replace(/\t/g, '    ');
  const lineNumber = sqlInput.value.slice(0, lineStart).split('\n').length - 1;
  sqlCompletionCanvas ||= document.createElement('canvas');
  const style = getComputedStyle(sqlInput);
  const context = sqlCompletionCanvas.getContext('2d');
  context.font = `${style.fontSize} ${style.fontFamily}`;
  const left = Math.max(4, Math.min(sqlInput.clientWidth - 424, 14 + context.measureText(line).width - sqlInput.scrollLeft));
  const naturalTop = 12 + ((lineNumber + 1) * SQL_EDITOR_LINE_HEIGHT) - sqlInput.scrollTop;
  const top = naturalTop + 272 > sqlInput.clientHeight ? Math.max(4, naturalTop - 278) : naturalTop;
  sqlCompletions.style.left = `${left}px`;
  sqlCompletions.style.top = `${top}px`;
}

function closeSqlCompletions() {
  sqlCompletionState = { open: false, items: [], active: 0, start: 0, end: 0 };
  sqlCompletions.hidden = true;
  sqlCompletions.textContent = '';
}

function renderSqlCompletions() {
  sqlCompletions.textContent = '';
  sqlCompletionState.items.forEach((item, index) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = `sql-completion${index === sqlCompletionState.active ? ' active' : ''}`;
    button.setAttribute('role', 'option');
    button.setAttribute('aria-selected', String(index === sqlCompletionState.active));
    button.append(Object.assign(document.createElement('span'), { className: 'sql-completion-icon', textContent: sqlCompletionIcon(item.kind) }));
    button.append(Object.assign(document.createElement('span'), { className: 'sql-completion-label', textContent: item.label }));
    button.append(Object.assign(document.createElement('span'), { className: 'sql-completion-detail', textContent: item.detail }));
    button.addEventListener('mousedown', event => { event.preventDefault(); applySqlCompletion(index); });
    sqlCompletions.append(button);
  });
  sqlCompletions.hidden = false;
  positionSqlCompletions();
  sqlCompletions.children[sqlCompletionState.active]?.scrollIntoView({ block: 'nearest' });
}

function updateSqlCompletions(force = false) {
  if (sqlEditorMetrics.large || sqlCompletionInsideLiteral(sqlInput.value.slice(0, sqlInput.selectionStart ?? 0))) return closeSqlCompletions();
  const token = sqlCompletionToken();
  const contextExpected = /\b(?:select|from|join|where|on|set|values|show|use|create|alter|drop)\s*$/i.test(token.statement);
  if (!force && !token.prefix && !token.qualified && !contextExpected) return closeSqlCompletions();
  const items = sqlCompletionItems(token);
  if (!items.length) return closeSqlCompletions();
  sqlCompletionState = { open: true, items, active: 0, start: token.start, end: token.caret };
  renderSqlCompletions();
}

function applySqlCompletion(index = sqlCompletionState.active) {
  const item = sqlCompletionState.items[index];
  if (!item) return closeSqlCompletions();
  const before = sqlInput.value.slice(0, sqlCompletionState.start);
  const after = sqlInput.value.slice(sqlCompletionState.end);
  sqlInput.value = `${before}${item.insert}${after}`;
  const caret = before.length + item.insert.length - (item.kind === 'function' ? 1 : 0);
  sqlInput.setSelectionRange(caret, caret);
  updateSqlEditor();
  scheduleSqlAnalysis();
  closeSqlCompletions();
}

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
  const time = new Date().toLocaleTimeString(LANGUAGE_LOCALES[currentLanguage] || LANGUAGE_LOCALES.id);
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
    sizeBytes: String(sql || '').length,
    progress: total ? completed / total : 0,
    updatedAt: Date.now(),
  };
  updateArchiveMonitor();
}

function inferArchiveDatasetFromSql(sql) {
  const source = String(sql || '');
  const text = source.slice(Math.max(0, source.length - (512 * 1024))).replace(/`/g, '').trim();
  const pattern = /\b(?:from|into|table|view)\s+([A-Za-z_][\w$]*)/gi;
  let match;
  let last = '';
  while ((match = pattern.exec(text))) last = match[1];
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
  log(t('database.selectFirst'));
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
  if (value.length >= LARGE_SQL_EDITOR_CHAR_LIMIT) return false;
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
      const cls = SQL_TYPES.has(lower) ? 'sql-type' :
        SQL_FUNCTIONS.has(lower) ? 'sql-function' :
        SQL_KEYWORDS.has(lower) ? 'sql-keyword' :
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
  return text ? `\`${text}\`` : '`?`';
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
  if (currentLanguage === 'en') return asaErrorDetailEnglish(text);
  if (currentLanguage === 'ja') return asaErrorDetailJapanese(text);
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

function asaErrorDetailEnglish(text) {
  let match;
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
  if ((match = /sandbox belum support:\s*(.+)$/i.exec(text))) return `Browser sandbox cannot run this form. Use the online Prolog backend for full support. Asa saw: ${match[1].slice(0, 90)}`;
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
  const raw = asaReadableRaw(text);
  return raw ? `Asa could not accept this part. Check table names, columns, punctuation, and keyword order. Asa saw: ${raw}` : 'Asa could not accept this part. Check table names, columns, punctuation, and keyword order.';
}

function asaErrorDetailJapanese(text) {
  let match;
  if (!text) return '完全なエラー内容を取得できませんでした。最後に変更した行からもう一度確認してください。';
  if (/select or create a database first|no database|database.*not selected|pilih atau buat database/i.test(text)) return '先にデータベースを選択または作成してください。アサにはテーブルの保存先が必要です。';
  if ((match = /table not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown table\s+([A-Za-z_][\w$]*)/i.exec(text)) || (match = /table_ref\('([^']+)'/i.exec(text))) return `テーブル ${asaCode(match[1])} は現在のデータベースにありません。DB の選択を確認するか、先にテーブルを作成してください。`;
  if ((match = /column not found:?\s*([A-Za-z_][\w$]*)/i.exec(text)) || (match = /unknown column\s+([A-Za-z_][\w$]*)/i.exec(text))) return `カラム ${asaCode(match[1])} はそのテーブルにありません。名前の綴りまたはテーブル構造を確認してください。`;
  if (/belum dikenali|unknown statement|unrecognized/i.test(text)) return '先頭のコマンドを認識できません。SELECT、CREATE、INSERT、UPDATE、DELETE、ALTER、DROP、SHOW、DESCRIBE などの対応キーワードから始めてください。';
  if ((match = /sandbox belum support:\s*(.+)$/i.exec(text))) return `ブラウザーサンドボックスではこの形式を実行できません。全機能にはオンラインの Prolog バックエンドを使用してください。先頭部分: ${match[1].slice(0, 90)}`;
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
  const raw = asaReadableRaw(text);
  return raw ? `この部分を受け入れられません。テーブル名、カラム名、記号、キーワード順を確認してください。内容: ${raw}` : 'この部分を受け入れられません。テーブル名、カラム名、記号、キーワード順を確認してください。';
}

function asaCorrectionDetail(item) {
  const text = asaCleanMessage(item?.message);
  const pair = asaCorrectionPair(text);
  if (currentLanguage === 'en') {
    if (pair) return `Did you mean ${asaCode(pair.to)} instead of ${asaCode(pair.from)}? Asa can correct it automatically before execution.`;
    if (/titik koma|semicolon|terminated/i.test(text)) return 'Add ; at the end so Asa knows where the SQL statement finishes.';
    if (/Kurung buka belum ditutup|opening parenthesis/i.test(text)) return 'An opening parenthesis is missing its closing ).';
    if (/Kurung tutup berlebih|closing parenthesis/i.test(text)) return 'There is one extra closing parenthesis on this line.';
    if (/INSERT.*VALUES|butuh VALUES|missing values/i.test(text)) return 'Add VALUES and the data after the INSERT table name.';
    if (item?.correction) return `Try this form: ${item.correction}`;
    return asaErrorDetailEnglish(text);
  }
  if (currentLanguage === 'ja') {
    if (pair) return `${asaCode(pair.from)} ではなく ${asaCode(pair.to)} の意味でしょうか。実行前にアサが自動修正できます。`;
    if (/titik koma|semicolon|terminated/i.test(text)) return 'SQL 文の終わりが分かるよう、末尾に ; を追加してください。';
    if (/Kurung buka belum ditutup|opening parenthesis/i.test(text)) return '開き括弧に対応する閉じ括弧 ) がありません。';
    if (/Kurung tutup berlebih|closing parenthesis/i.test(text)) return 'この行には閉じ括弧が一つ多くあります。';
    if (/INSERT.*VALUES|butuh VALUES|missing values/i.test(text)) return 'INSERT のテーブル名の後に VALUES とデータを追加してください。';
    if (item?.correction) return `この形式を試してください: ${item.correction}`;
    return asaErrorDetailJapanese(text);
  }
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
  if (currentLanguage === 'en') return asaSuccessDetailEnglish(text);
  if (currentLanguage === 'ja') return asaSuccessDetailJapanese(text);
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

function asaSuccessDetailEnglish(text) {
  let match;
  if ((match = /^created_database\(([^)]+)\)/i.exec(text))) return `Database ${asaCode(match[1])} was created and is ready.`;
  if ((match = /^using_database\(([^)]+)\)/i.exec(text))) return `Asa is now working in database ${asaCode(match[1])}.`;
  if ((match = /^dropped_database\(([^)]+)\)/i.exec(text))) return `Database ${asaCode(match[1])} was dropped.`;
  if ((match = /^created_table\(([^)]+)\)/i.exec(text))) return `Table ${asaCode(match[1])} was created.`;
  if ((match = /^altered_table\(([^)]+)\)/i.exec(text))) return `Table ${asaCode(match[1])} was updated.`;
  if ((match = /^dropped_table\(([^)]+)\)/i.exec(text))) return `Table ${asaCode(match[1])} was removed from the active database.`;
  if ((match = /^truncated_table\(([^)]+)\)/i.exec(text))) return `Rows in ${asaCode(match[1])} were cleared while its structure was kept.`;
  if ((match = /^(inserted|updated|deleted)\(([^,]+),\s*([^)]+)\)/i.exec(text))) return `${match[3]} row(s) were ${match[1]} in ${asaCode(match[2])}.`;
  if ((match = /^created_index\(([^,]+),\s*([^)]+)\)/i.exec(text))) return `Index ${asaCode(match[1])} was created for ${asaCode(match[2])}.`;
  if ((match = /^created_view\(([^)]+)\)/i.exec(text))) return `View ${asaCode(match[1])} was created.`;
  if ((match = /^dropped_view\(([^)]+)\)/i.exec(text))) return `View ${asaCode(match[1])} was dropped.`;
  if (/^committed|commit$/i.test(text)) return 'The transaction was committed and its changes are durable.';
  if (/^rolled_back|rollback$/i.test(text)) return 'The transaction was rolled back safely.';
  if (/^started_transaction|begin|start_transaction$/i.test(text)) return 'The transaction started. Asa is waiting for COMMIT or ROLLBACK.';
  if ((match = /^batch_completed\(([^)]+)\)/i.exec(text))) return `The batch completed with ${match[1]} successful step(s).`;
  if (/^ok$|^done$/i.test(text)) return 'The command completed successfully.';
  return text ? `The command completed. Asa note: ${text}` : 'The command completed and the database is calm.';
}

function asaSuccessDetailJapanese(text) {
  let match;
  if ((match = /^created_database\(([^)]+)\)/i.exec(text))) return `データベース ${asaCode(match[1])} を作成し、使用できる状態になりました。`;
  if ((match = /^using_database\(([^)]+)\)/i.exec(text))) return `現在、アサはデータベース ${asaCode(match[1])} を使用しています。`;
  if ((match = /^dropped_database\(([^)]+)\)/i.exec(text))) return `データベース ${asaCode(match[1])} を削除しました。`;
  if ((match = /^created_table\(([^)]+)\)/i.exec(text))) return `テーブル ${asaCode(match[1])} を作成しました。`;
  if ((match = /^altered_table\(([^)]+)\)/i.exec(text))) return `テーブル ${asaCode(match[1])} を更新しました。`;
  if ((match = /^dropped_table\(([^)]+)\)/i.exec(text))) return `現在のデータベースからテーブル ${asaCode(match[1])} を削除しました。`;
  if ((match = /^truncated_table\(([^)]+)\)/i.exec(text))) return `${asaCode(match[1])} の構造を残し、全行を削除しました。`;
  if ((match = /^(inserted|updated|deleted)\(([^,]+),\s*([^)]+)\)/i.exec(text))) return `${asaCode(match[2])} で ${match[3]} 行の処理が完了しました。`;
  if ((match = /^created_index\(([^,]+),\s*([^)]+)\)/i.exec(text))) return `${asaCode(match[2])} にインデックス ${asaCode(match[1])} を作成しました。`;
  if ((match = /^created_view\(([^)]+)\)/i.exec(text))) return `ビュー ${asaCode(match[1])} を作成しました。`;
  if ((match = /^dropped_view\(([^)]+)\)/i.exec(text))) return `ビュー ${asaCode(match[1])} を削除しました。`;
  if (/^committed|commit$/i.test(text)) return 'トランザクションをコミットし、変更を永続化しました。';
  if (/^rolled_back|rollback$/i.test(text)) return 'トランザクションを安全にロールバックしました。';
  if (/^started_transaction|begin|start_transaction$/i.test(text)) return 'トランザクションを開始しました。COMMIT または ROLLBACK を待っています。';
  if ((match = /^batch_completed\(([^)]+)\)/i.exec(text))) return `バッチが完了し、${match[1]} ステップ成功しました。`;
  if (/^ok$|^done$/i.test(text)) return 'コマンドは正常に完了しました。';
  return text ? `コマンドが完了しました。アサからのメモ: ${text}` : 'コマンドが完了し、データベースは正常です。';
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

  const supported = /^(create|use|drop|truncate|insert|select|describe|desc|show|update|delete|alter|explain|begin|start|commit|rollback|lock|unlock|grant|revoke|login)\b/i;
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

function countSqlLines(sql) {
  let count = 1;
  let index = -1;
  while ((index = sql.indexOf('\n', index + 1)) !== -1) count += 1;
  return count;
}

function measureSqlEditor(sql) {
  const textLength = sql.length;
  if (textLength >= LARGE_SQL_EDITOR_CHAR_LIMIT) {
    return { lineCount: countSqlLines(sql), large: true, textLength };
  }
  const lineCount = countSqlLines(sql);
  return { lineCount, large: lineCount >= LARGE_SQL_EDITOR_LINE_LIMIT, textLength };
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
      <span><span class="diagnostic-line">${escapeHtml(t('result.line'))} ${item.line}</span> ${escapeHtml(asaDiagnosticCopy(item))}</span>
    </div>
  `).join('');
}

function renderSqlLineNumbers(sql) {
  const severityByLine = {};
  for (const item of sqlDiagnosticsState) {
    if (item.severity === 'error') severityByLine[item.line] = 'error';
    else if (!severityByLine[item.line]) severityByLine[item.line] = 'warning';
  }
  const lines = sqlEditorMetrics.textLength === sql.length
    ? sqlEditorMetrics.lineCount
    : countSqlLines(sql);
  let firstLine = 1;
  let lastLine = lines;
  if (sqlEditorMetrics.large) {
    const visibleLines = Math.ceil((sqlInput.clientHeight || 420) / SQL_EDITOR_LINE_HEIGHT) + 16;
    firstLine = Math.max(1, Math.floor(sqlInput.scrollTop / SQL_EDITOR_LINE_HEIGHT) - 7);
    lastLine = Math.min(lines, firstLine + visibleLines);
    sqlLineNumbersContent.style.paddingTop = `${12 + ((firstLine - 1) * SQL_EDITOR_LINE_HEIGHT)}px`;
    sqlLineNumbersContent.style.paddingBottom = `${12 + ((lines - lastLine) * SQL_EDITOR_LINE_HEIGHT)}px`;
  } else {
    sqlLineNumbersContent.style.paddingTop = '';
    sqlLineNumbersContent.style.paddingBottom = '';
  }
  const numbers = [];
  for (let line = firstLine; line <= lastLine; line += 1) {
    const severity = severityByLine[line] || '';
    numbers.push(`<span class="${severity}">${line}</span>`);
  }
  sqlLineNumbersContent.innerHTML = numbers.join('');
}

function syncSqlScroll() {
  sqlHighlight.scrollTop = sqlInput.scrollTop;
  sqlHighlight.scrollLeft = sqlInput.scrollLeft;
  if (sqlEditorMetrics.large) {
    cancelAnimationFrame(sqlLineRenderFrame);
    sqlLineRenderFrame = requestAnimationFrame(() => renderSqlLineNumbers(sqlInput.value));
  }
  sqlLineNumbers.scrollTop = sqlInput.scrollTop;
  positionSqlCompletions();
}

function sqlCaretScrollTarget() {
  const caret = sqlInput.selectionStart ?? sqlInput.value.length;
  const line = lineNumberAtIndex(sqlInput.value, caret);
  const viewport = sqlInput.clientHeight || 420;
  const target = ((line - 1) * SQL_EDITOR_LINE_HEIGHT) - (viewport * 0.45);
  const max = Math.max(0, sqlInput.scrollHeight - viewport);
  return Math.max(0, Math.min(max, target));
}

function restoreSqlViewport(top, left, frames = 2) {
  cancelAnimationFrame(sqlScrollRestoreFrame);
  const apply = (remaining) => {
    sqlInput.scrollTop = Math.max(0, Number(top) || 0);
    sqlInput.scrollLeft = Math.max(0, Number(left) || 0);
    syncSqlScroll();
    if (remaining > 0) sqlScrollRestoreFrame = requestAnimationFrame(() => apply(remaining - 1));
  };
  apply(frames);
}

function updateSqlEditor(options = {}) {
  const requestedTop = Number.isFinite(options.scrollTop) ? options.scrollTop : sqlInput.scrollTop;
  const requestedLeft = Number.isFinite(options.scrollLeft) ? options.scrollLeft : sqlInput.scrollLeft;
  const sql = sqlInput.value;
  sqlEditorMetrics = measureSqlEditor(sql);
  sqlEditor.classList.toggle('large-script', sqlEditorMetrics.large);
  if (sqlEditorMetrics.large) sqlHighlight.textContent = '';
  else sqlHighlight.innerHTML = highlightSql(sql);
  renderSqlLineNumbers(sql);
  sqlInput.scrollTop = requestedTop;
  sqlInput.scrollLeft = requestedLeft;
  syncSqlScroll();
  if (options.persistScroll) restoreSqlViewport(requestedTop, requestedLeft);
  return sqlEditorMetrics;
}

function setSqlText(text, analyze = true) {
  sqlInput.value = text;
  updateSqlEditor();
  closeSqlCompletions();
  if (analyze) scheduleSqlAnalysis();
}

function scheduleSqlAnalysis() {
  clearTimeout(sqlAnalyzeTimer);
  // Reject an old backend response immediately, rather than after the
  // debounce delay. This prevents a stale "missing ;" warning from briefly
  // replacing diagnostics for the query the user has already corrected.
  sqlAnalyzeRequest += 1;
  if (sqlEditorMetrics.large) {
    setSqlDiagnostics([]);
    return;
  }
  sqlAnalyzeTimer = setTimeout(() => refreshSqlDiagnostics(true), 420);
}

async function refreshSqlDiagnostics(useBackend = true) {
  const sql = sqlInput.value;
  if (sqlEditorMetrics.large || sql.length >= LARGE_SQL_EDITOR_CHAR_LIMIT) {
    setSqlDiagnostics([]);
    return [];
  }
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
      log(t('log.analyzerFallback', { error: err.message }));
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

async function executeBackendSqlPage(sql, offset = 0) {
  const body = new URLSearchParams({
    sql,
    offset: String(Math.max(0, Number(offset) || 0)),
  });
  const res = await fetch('/api/query', {
    method: 'POST',
    headers: apiHeaders({ 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' }),
    body,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`);
  return data;
}

function createSqlExecutionPlan(sql) {
  const text = String(sql || '');
  const containsWrite = /\b(?:create|drop|alter|truncate|insert|update|delete|replace|grant|revoke)\b/i.test(text);
  const statements = containsWrite ? null : splitStatementsDetailed(text);
  return {
    mode: containsWrite || text.length > 250000 ? 'reservoir' : 'direct',
    statements,
    statementCount: statements?.length ?? null,
  };
}

async function executeBackendSqlStreamed(sql, options = {}) {
  const body = new Blob([sql], { type: 'application/sql;charset=UTF-8' });
  return submitReservoirPayload(body, {
    ...options,
    label: options.label || 'SQL command',
    kind: options.kind || 'sql',
  });
}

function makeReservoirIdempotencyKey(prefix = 'job') {
  const browserCrypto = window.crypto || window.msCrypto;
  const suffix = browserCrypto && typeof browserCrypto.randomUUID === 'function'
    ? browserCrypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  return `${prefix}-${suffix}`;
}

function reservoirStatusText(status) {
  switch (String(status || '').toLowerCase()) {
    case 'receiving': return t('state.receiving');
    case 'queued': return t('state.queued');
    case 'processing': return t('state.processing');
    case 'cancelling': return t('state.cancelling');
    case 'completed': return t('state.completed');
    case 'delivered': return t('state.delivered');
    case 'failed': return t('state.failed');
    case 'cancelled': return t('state.cancelled');
    case 'interrupted': return t('state.interrupted');
    case 'reconnecting': return t('state.reconnecting');
    default: return String(status || t('state.waiting'));
  }
}

function reservoirJobIsTerminal(job) {
  if (!job) return false;
  return job.done === true || ['completed', 'delivered', 'failed', 'cancelled', 'interrupted'].includes(String(job.status || '').toLowerCase());
}

function reservoirJobPercent(job) {
  if (!job) return 0;
  if (job.result_available || ['completed', 'delivered'].includes(String(job.status || '').toLowerCase())) return 100;
  const reported = Number(job.progress_percent);
  if (Number.isFinite(reported)) return Math.max(0, Math.min(100, Math.round(reported)));
  const completed = Number(job.processed_bytes) || 0;
  const total = Number(job.size_bytes) || 0;
  return total ? Math.max(0, Math.min(100, Math.round((completed / total) * 100))) : 0;
}

function loadActiveReservoirDescriptor() {
  try {
    const descriptor = JSON.parse(localStorage.getItem(ACTIVE_RESERVOIR_STORAGE_KEY) || 'null');
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

function clearActiveReservoirDescriptor(jobId = '') {
  try {
    const stored = loadActiveReservoirDescriptor();
    if (!jobId || !stored || stored.id === jobId) localStorage.removeItem(ACTIVE_RESERVOIR_STORAGE_KEY);
  } catch (_) {}
}

function normalizeReservoirDescriptor(jobId, options = {}, job = null) {
  const supplied = options.descriptor || {};
  const stored = loadActiveReservoirDescriptor();
  const previous = stored && stored.id === jobId ? stored : {};
  return {
    id: jobId,
    label: options.label || supplied.label || job?.label || previous.label || 'Reservoir',
    kind: options.kind || supplied.kind || previous.kind || 'reservoir',
    sizeBytes: Number(options.sizeBytes ?? supplied.sizeBytes ?? job?.size_bytes ?? previous.sizeBytes) || 0,
    startedAt: supplied.startedAt || previous.startedAt || new Date().toISOString(),
  };
}

function updateImportControls() {
  const busy = Boolean(importOperationPromise || activeReservoirJobId);
  importExecuteBtn.disabled = busy;
  importRunServerBtn.disabled = busy;
  importFileInput.disabled = busy;
}

function renderReservoirJob(job = lastReservoirSnapshot) {
  if (!importProgressPanel) return;
  if (!job && !activeReservoirJobId) {
    importProgressPanel.hidden = true;
    importCancelBtn.disabled = true;
    importCancelBtn.textContent = t('import.cancel');
    updateImportControls();
    return;
  }

  if (job) lastReservoirSnapshot = job;
  const snapshot = job || lastReservoirSnapshot || {};
  const descriptor = activeReservoirDescriptor || loadActiveReservoirDescriptor() || {};
  const percent = reservoirJobPercent(snapshot);
  const status = reservoirStatusText(snapshot.status);
  const message = String(snapshot.message || '').trim() || '-';
  const statements = Number(snapshot.statements) || 0;
  const terminal = reservoirJobIsTerminal(snapshot);
  const cancelPending = Boolean(activeReservoirJobId) && !terminal && Boolean(reservoirCancelPromise || snapshot.cancel_requested || snapshot.status === 'cancelling');
  const canCancel = Boolean(activeReservoirJobId) && !terminal && !cancelPending;

  importProgressPanel.hidden = false;
  importProgressLabel.textContent = snapshot.label || descriptor.label || 'Reservoir';
  importProgressPercent.textContent = `${percent}%`;
  importProgressBar.value = percent;
  importProgressBar.textContent = `${percent}%`;
  importProgressStatus.textContent = t('import.jobStatus', {
    status,
    count: formatNumber(statements),
    message,
  });
  importCancelBtn.disabled = !canCancel;
  importCancelBtn.textContent = t(cancelPending ? 'import.cancelling' : 'import.cancel');
  updateImportControls();
}

function activateReservoirJob(jobId, options = {}, job = null) {
  if (!jobId) return null;
  activeReservoirJobId = jobId;
  activeReservoirDescriptor = normalizeReservoirDescriptor(jobId, options, job);
  saveActiveReservoirDescriptor(activeReservoirDescriptor);
  const snapshot = job || {
    id: jobId,
    label: activeReservoirDescriptor.label,
    status: options.status || 'queued',
    size_bytes: activeReservoirDescriptor.sizeBytes,
    processed_bytes: 0,
    statements: 0,
    result_available: false,
    done: false,
    message: options.message || '',
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
  const error = new Error(payload?.message || `HTTP ${response.status}`);
  error.httpStatus = response.status;
  return error;
}

async function submitReservoirPayload(payload, options = {}) {
  const idempotencyKey = options.idempotencyKey || makeReservoirIdempotencyKey('reservoir');
  const res = await fetch('/api/reservoir/jobs', {
    method: 'POST',
    headers: apiHeaders({
      'Content-Type': options.contentType || 'application/sql;charset=UTF-8',
      'X-AsaDB-Idempotency-Key': idempotencyKey,
      'X-AsaDB-Job-Label': options.label || 'SQL command',
      'X-AsaDB-Stop-On-Error': options.stopOnError === false ? 'false' : 'true',
    }),
    body: payload,
  });
  const admission = await res.json();
  if (!res.ok) throw new Error(admission.message || `HTTP ${res.status}`);
  activateReservoirJob(admission.job_id, {
    ...options,
    idempotencyKey,
    sizeBytes: admission.job?.size_bytes || payload?.size || 0,
  }, admission.job || null);
  return waitForReservoirJob(admission.job_id, options);
}

async function startReservoirFile(path, options = {}) {
  const body = new URLSearchParams({
    path,
    idempotency_key: options.idempotencyKey || makeReservoirIdempotencyKey('file'),
    stop_on_error: options.stopOnError === false ? 'false' : 'true',
  });
  const res = await fetch('/api/reservoir/file', {
    method: 'POST',
    headers: apiHeaders({ 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' }),
    body,
  });
  const admission = await res.json();
  if (!res.ok) throw new Error(admission.message || `HTTP ${res.status}`);
  activateReservoirJob(admission.job_id, {
    ...options,
    kind: options.kind || 'import-file',
    label: options.label || path,
    sizeBytes: admission.size_bytes || admission.job?.size_bytes || 0,
  }, admission.job || null);
  return waitForReservoirJob(admission.job_id, options);
}

async function waitForReservoirJob(jobId, options = {}) {
  activateReservoirJob(jobId, options);
  let retryCount = 0;
  while (true) {
    try {
      const res = await fetch(`/api/reservoir/job?id=${encodeURIComponent(jobId)}`, {
        cache: 'no-store',
        headers: apiHeaders(),
      });
      const job = await res.json();
      if (!res.ok) throw reservoirHttpError(res, job);
      retryCount = 0;
      renderReservoirJob(job);
      options.onProgress?.({
        completed: Number(job.processed_bytes) || 0,
        total: Number(job.size_bytes) || 0,
        statements: Number(job.statements) || 0,
        label: job.message || job.status || 'Reservoir',
        status: job.status,
      });
      requestMetadataRefreshDuringJob();
      if (job.result_available) {
        const data = await fetchReservoirResult(jobId, job);
        finishReservoirJob(jobId, { ...job, done: true, progress_percent: 100 });
        return data;
      }
      if (['failed', 'cancelled', 'interrupted'].includes(job.status)) {
        const error = new Error(job.message || `Reservoir job ${job.status}`);
        error.reservoirStatus = job.status;
        finishReservoirJob(jobId, job);
        throw error;
      }
      await new Promise(resolve => setTimeout(resolve, RESERVOIR_POLL_INTERVAL_MS));
    } catch (err) {
      if (err.reservoirStatus) throw err;
      if (err.httpStatus === 404 || err.httpStatus === 410) {
        finishReservoirJob(jobId, {
          ...(lastReservoirSnapshot || {}),
          id: jobId,
          status: 'interrupted',
          done: true,
          message: err.message,
        });
        throw err;
      }
      retryCount += 1;
      renderReservoirJob({
        ...(lastReservoirSnapshot || {}),
        id: jobId,
        label: activeReservoirDescriptor?.label || lastReservoirSnapshot?.label || 'Reservoir',
        status: 'reconnecting',
        done: false,
        message: err.message,
      });
      await new Promise(resolve => setTimeout(resolve, Math.min(5000, 300 * (2 ** Math.min(retryCount, 4)))));
    }
  }
}

async function fetchReservoirResult(jobId, job) {
  const res = await fetch(`/api/reservoir/result?id=${encodeURIComponent(jobId)}`, {
    cache: 'no-store',
    headers: apiHeaders(),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.message || `HTTP ${res.status}`);
  const allResults = data.results || [data];
  return { ...data, allResults, statementCount: Number(job.statements) || allResults.length };
}

async function cancelActiveReservoirJob() {
  if (reservoirCancelPromise) return reservoirCancelPromise;
  const jobId = activeReservoirJobId;
  if (!jobId) return null;

  reservoirCancelPromise = (async () => {
    const res = await fetch(`/api/reservoir/cancel?id=${encodeURIComponent(jobId)}`, {
      method: 'POST',
      headers: apiHeaders(),
    });
    const snapshot = await res.json();
    if (!res.ok) throw reservoirHttpError(res, snapshot);
    renderReservoirJob(snapshot);
    importSummary.textContent = t('import.cancelRequested');
    requestMetadataRefreshDuringJob();
    return snapshot;
  })();
  renderReservoirJob(lastReservoirSnapshot);

  try {
    return await reservoirCancelPromise;
  } catch (err) {
    log(t('log.reservoirCancelFailed', { error: err.message }));
    importSummary.textContent = `${ASA_ERROR_LABEL}: ${asaErrorCopy(err.message)}`;
    return null;
  } finally {
    reservoirCancelPromise = null;
    renderReservoirJob(lastReservoirSnapshot);
  }
}

async function fetchReservoirJobSnapshot(jobId) {
  const res = await fetch(`/api/reservoir/job?id=${encodeURIComponent(jobId)}`, {
    cache: 'no-store',
    headers: apiHeaders(),
  });
  const job = await res.json();
  if (!res.ok) throw reservoirHttpError(res, job);
  return job;
}

async function discoverActiveReservoirJob() {
  const stored = loadActiveReservoirDescriptor();
  if (stored) {
    try {
      const job = await fetchReservoirJobSnapshot(stored.id);
      if (!reservoirJobIsTerminal(job) || job.result_available) return { job, descriptor: stored };
      lastReservoirSnapshot = job;
      renderReservoirJob(job);
      clearActiveReservoirDescriptor(stored.id);
    } catch (err) {
      if (err.httpStatus !== 404 && err.httpStatus !== 410) {
        return {
          job: {
            id: stored.id,
            label: stored.label,
            status: 'reconnecting',
            size_bytes: stored.sizeBytes || 0,
            done: false,
            message: err.message,
          },
          descriptor: stored,
        };
      }
      clearActiveReservoirDescriptor(stored.id);
    }
  }

  try {
    const res = await fetch('/api/reservoir/jobs', { cache: 'no-store', headers: apiHeaders() });
    if (!res.ok) return null;
    const data = await res.json();
    const jobs = Array.isArray(data.jobs) ? data.jobs : [];
    const job = jobs.find(candidate => !reservoirJobIsTerminal(candidate));
    if (!job) return null;
    return { job, descriptor: normalizeReservoirDescriptor(job.id, {}, job) };
  } catch (_) {
    return null;
  }
}

async function finalizeResumedReservoirJob(data, descriptor) {
  const results = data.results || [data];
  renderResults(results);
  addRuntimeDiagnostics(results);
  const statementCount = Number(data.statementCount) || 0;
  setLastRunKey('progress.backendSteps', { count: statementCount });
  await Promise.all([
    syncBackendStateSmart().catch(() => syncCatalogFromBackend().catch(() => false)),
    refreshDatabaseMetadata().catch(() => null),
  ]);
  renderTableBrowser();
  const tableResult = results.find(result => result.status === 'table');
  noteArchiveImportComplete(
    descriptor.label,
    descriptor.sizeBytes || 0,
    tableResult?.columns || ['status'],
    tableResult?.rows || [],
    statementCount,
  );
  const summary = t('import.resumedComplete', {
    name: descriptor.label,
    count: formatNumber(statementCount),
  });
  importSummary.textContent = summary;
  log(summary);
}

function resumeActiveReservoirJob() {
  if (reservoirResumePromise) return reservoirResumePromise;
  if (activeReservoirJobId) return Promise.resolve(null);
  reservoirResumePromise = (async () => {
    const recovered = await discoverActiveReservoirJob();
    if (!recovered) return null;
    const { job, descriptor } = recovered;
    activateReservoirJob(job.id, { descriptor }, job);
    importSummary.textContent = t('import.resumed', { name: descriptor.label });
    log(t('log.reservoirResumed', { name: descriptor.label }));
    try {
      const data = await waitForReservoirJob(job.id, { descriptor });
      await finalizeResumedReservoirJob(data, descriptor);
      return data;
    } catch (err) {
      if (err.reservoirStatus === 'cancelled') {
        importSummary.textContent = t('import.cancelled');
      } else {
        importSummary.textContent = `${ASA_ERROR_LABEL}: ${asaErrorCopy(err.message)}`;
        log(t('log.reservoirMonitorFailed', { error: err.message }));
      }
      return null;
    }
  })().finally(() => {
    reservoirResumePromise = null;
  });
  return reservoirResumePromise;
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

async function backendListContains(sql, expectedName) {
  const data = await executeBackendSql(sql, { sync: false });
  if (hasResultError(data)) {
    const error = (data.results || []).find(result => result?.status === 'error');
    throw new Error(error?.message || 'backend verification failed');
  }
  const table = (data.results || [data]).find(result => result?.status === 'table');
  if (!table) throw new Error('backend verification returned no table');
  const target = String(expectedName).toLowerCase();
  return (table.rows || []).some(row => (row || []).some(value => String(value).toLowerCase() === target));
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
  const source = ASA_RUN_SOUNDS.ok[0] || ASA_RUN_SOUNDS.error[0];
  const audio = source ? getAsaRunAudioChannel() : null;
  if (!audio) return Promise.resolve();
  const generation = ++asaRunAudioGeneration;
  try {
    audio.pause();
    audio.src = source;
    audio.muted = true;
    audio.volume = 0;
    audio.currentTime = 0;
    const played = audio.play();
    let primePromise;
    primePromise = Promise.resolve(played).then(() => {
        if (asaRunAudioGeneration !== generation) return;
        audio.pause();
        audio.currentTime = 0;
      }).catch(() => {
        // Some browsers unlock media only after the first completed gesture.
      }).finally(() => {
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
  const src = chooseAsaRunSound(kind);
  const audio = getAsaRunAudioChannel();
  if (!audio) return;
  stopAsaRunSounds();
  const generation = asaRunAudioGeneration;
  try {
    audio.src = src;
    audio.currentTime = 0;
    audio.muted = false;
    audio.volume = 0.72;
    audio.onended = () => {
      if (asaRunAudioGeneration === generation) audio.currentTime = 0;
    };
    const played = audio.play();
    if (played && typeof played.catch === 'function') {
      played.catch(() => {});
    }
  } catch (_) {}
}

async function executeBackendSqlBatched(sql, options = {}) {
  const statements = options.statements || splitStatementsDetailed(sql).flatMap(stmt =>
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

function buildBackendSqlChunks(statements, limit = 200000) {
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

function expandOversizedStatement(text, limit = 200000) {
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

function refreshDatabaseMetadata() {
  if (!backendOnline) {
    lastDatabaseMetadata = null;
    renderDatabaseMetadata(null);
    return Promise.resolve(null);
  }
  if (metadataRefreshPromise) return metadataRefreshPromise;
  metadataRefreshPromise = (async () => {
    const res = await fetch('/api/metadata', { cache: 'no-store', headers: apiHeaders() });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const metadata = await res.json();
    lastDatabaseMetadata = metadata;
    lastMetadataRefreshAt = Date.now();
    renderDatabaseMetadata(metadata);
    return metadata;
  })().finally(() => {
    metadataRefreshPromise = null;
  });
  return metadataRefreshPromise;
}

function metadataPollInterval() {
  if (activeReservoirJobId) return METADATA_ACTIVE_POLL_INTERVAL_MS;
  if (dbMetadataPanel?.open) return METADATA_OPEN_POLL_INTERVAL_MS;
  return METADATA_IDLE_POLL_INTERVAL_MS;
}

function scheduleMetadataPoll(delay = metadataPollInterval()) {
  clearTimeout(metadataPollTimer);
  metadataPollTimer = setTimeout(async () => {
    if (backendOnline && document.visibilityState !== 'hidden') {
      try {
        await refreshDatabaseMetadata();
      } catch (_) {
        // Keep the last good snapshot; the next adaptive poll retries.
      }
    }
    scheduleMetadataPoll(metadataPollInterval());
  }, Math.max(0, delay));
}

function requestMetadataRefreshDuringJob() {
  if (!backendOnline) return;
  const elapsed = Date.now() - lastMetadataRefreshAt;
  scheduleMetadataPoll(Math.max(0, METADATA_ACTIVE_POLL_INTERVAL_MS - elapsed));
}

function renderDatabaseMetadata(metadata) {
  if (!dbMetadataPanel) return;
  if (!metadata) {
    metadataState.textContent = backendOnline ? t('state.unavailable') : t('state.offline');
    for (const node of [metadataEngine, metadataIdentity, metadataObjects, metadataRows, metadataStorage, metadataCache, metadataReservoir, metadataCheckpoint]) {
      node.textContent = '-';
    }
    return;
  }
  const summary = metadata.summary || {};
  const persistence = metadata.persistence || {};
  const pager = metadata.storage?.pager || {};
  const pool = pager.buffer_pool || {};
  const reservoir = metadata.reservoir || {};
  const dirty = Boolean(persistence.checkpoint_dirty || persistence.transaction_active);
  metadataState.textContent = dirty ? t('state.pending') : t('state.durable');
  metadataEngine.textContent = `v${metadata.engine_version || '?'} / format ${metadata.storage_format || summary.storage_format || '?'}`;
  metadataIdentity.textContent = metadata.database_id || '-';
  metadataObjects.textContent = t('metadata.objectsValue', {
    databases: formatNumber(summary.database_count || 0),
    tables: formatNumber(summary.table_count || 0),
    views: formatNumber(summary.view_count || 0),
  });
  metadataRows.textContent = formatNumber(summary.row_count || 0);
  metadataStorage.textContent = t('metadata.storageValue', { size: formatBytes((persistence.catalog_bytes || 0) + (persistence.store_bytes || 0)) });
  metadataCache.textContent = t('metadata.cacheValue', {
    pages: formatNumber(pool.pages || 0),
    limit: formatNumber(pool.limit_pages || 0),
    hits: formatNumber(pool.hits || 0),
  });
  metadataReservoir.textContent = t('metadata.reservoirValue', {
    active: formatNumber(reservoir.active ?? reservoir.processing ?? 0),
    queued: formatNumber(reservoir.queued || 0),
    size: formatBytes(reservoir.spool_bytes || 0),
  });
  metadataCheckpoint.textContent = t('metadata.checkpointValue', {
    count: formatNumber(metadata.checkpoint_count || 0),
    time: metadata.last_checkpoint_at || t('state.never'),
  });
}

function syncSandboxFromCatalogData(data) {
  const rows = data?.rows || [];
  if (!rows.length) {
    sandbox = normalizeSandbox({ currentDb: '', dbs: {}, views: {} });
    selectedTable = '';
    saveSandbox();
    renderTableBrowser();
    return { totalRows: 0 };
  }

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
        query: queryTerm ? String(queryTerm) : '',
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
    log(t('log.stateSyncSkipped', { error: err.message }));
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
  // The Prolog server has already warmed its runtime before opening port 8088.
  // Keep only a short, non-blocking visual cue; do not issue a second warmup.
  Promise.resolve(engineWork).catch(() => {});
  startupDelay(STARTUP_WARMUP_MS).then(hideStartupLoader);
}

async function checkEngine() {
  let reservoirOnline = false;
  try {
    const res = await fetch('/api/reservoir/stats', { cache: 'no-store', headers: apiHeaders() });
    reservoirOnline = res.ok;
  } catch (_) {
    reservoirOnline = false;
  }
  if (reservoirOnline) {
    backendOnline = true;
    syncBackendStateSmart().catch(() => false);
  } else {
    try {
      backendOnline = Boolean(await syncBackendStateSmart());
    } catch (_) {
      backendOnline = false;
    }
  }
  engineCheckCompleted = true;
  updateEngineStatus();
  log(backendOnline ? t('log.connected') : t('log.sandbox'));
  if (backendOnline) {
    refreshDatabaseMetadata().catch(() => renderDatabaseMetadata(null));
    resumeActiveReservoirJob().catch(() => null);
  } else {
    renderDatabaseMetadata(null);
  }
  scheduleMetadataPoll(backendOnline ? 0 : METADATA_IDLE_POLL_INTERVAL_MS);
  refreshSqlDiagnostics(backendOnline);
}

function showView(name, hashName = name) {
  currentViewName = name;
  for (const [viewName, node] of Object.entries(views)) node.hidden = viewName !== name;
  for (const [viewName, button] of Object.entries(viewButtons)) button.classList.toggle('active', viewName === name);
  updatePageTitle();
  if (location.hash !== `#${hashName}`) history.replaceState(null, '', `#${hashName}`);
  if (name === 'export') {
    renderExportTablePicker();
    exportDbName.textContent = currentDbName() || t('database.noneSelected');
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
  runBtn.textContent = t(busy ? 'sql.running' : 'sql.run');
}

function runSql() {
  if (sqlRunPromise) return sqlRunPromise;
  stopAsaRunSounds();
  void primeAsaRunSounds();
  setSqlRunBusy(true);
  sqlRunPromise = runSqlOnce().finally(() => {
    sqlRunPromise = null;
    setSqlRunBusy(false);
  });
  return sqlRunPromise;
}

async function runSqlOnce() {
  if (!sqlEditorMetrics.large) applySqlAutoCorrection(true);
  const sql = sqlInput.value;
  const metrics = updateSqlEditor();
  clearTimeout(sqlAnalyzeTimer);
  sqlAnalyzeTimer = 0;
  sqlAnalyzeRequest += 1;
  if (metrics.large) setSqlDiagnostics([]);
  else setSqlDiagnostics(analyzeSqlClient(sql));
  const plan = backendOnline ? createSqlExecutionPlan(sql) : null;
  await new Promise(resolve => requestAnimationFrame(resolve));
  const started = performance.now();
  let data;
  if (backendOnline) {
    try {
      data = plan.mode === 'reservoir'
        ? await executeBackendSqlStreamed(sql, {
            stopOnError: true,
            onProgress: ({ completed, total, statements }) => {
              const percent = total ? Math.min(100, Math.round((completed / total) * 100)) : 0;
              setLastRunKey('progress.importing', { percent, count: statements });
            },
          })
        : await executeBackendSql(sql, { sync: false });
    } catch (err) {
      data = { results: [{ status: 'error', message: `Backend Prolog gagal: ${err.message}` }] };
      log(t('log.backendFailed', { error: err.message }));
    }
  } else {
    data = sandboxExec(sql);
  }
  renderResults(data.results || [data], { sourceSql: sql });
  addRuntimeDiagnostics(data.results || [data]);
  playAsaRunSound(resultSetHasError(data) ? 'error' : 'ok');
  setLastRunRaw(`${Math.round(performance.now() - started)} ms`);
  const statementCount = Number(data.statementCount ?? plan?.statementCount ?? 0);
  log(statementCount > 0 ? t('result.executed', { count: formatNumber(statementCount) }) : t('result.completed'));
  await refreshBrowserAfterRun(sql, data);
}

async function refreshBrowserAfterRun(sql, data) {
  if (!backendOnline) {
    renderTableBrowser();
    return;
  }

  const [synced] = await Promise.all([
    syncCatalogFromBackend().catch(err => {
      log(t('log.postSyncSkipped', { error: err.message }));
      return false;
    }),
    refreshDatabaseMetadata().catch(() => null),
  ]);
  if (!synced) log(t('log.postSyncUnavailable'));

  renderTableBrowser();
}

function shouldBatchBackendSql(sql) {
  return String(sql || '').length > 180000 || splitStatementsDetailed(sql).length > 12;
}

function pageableResultSql(sql) {
  if (!sql) return '';
  try {
    const text = String(sql);
    return text.length <= 250000 && splitStatementsDetailed(text).length === 1 ? text : '';
  } catch (_) {
    return '';
  }
}

function resultPageOffsets(results, supplied) {
  return (results || []).map((result, index) => {
    const existing = Number(supplied?.[index]);
    if (Number.isFinite(existing) && existing >= 0) return existing;
    return Number(result?.rows?.length) || 0;
  });
}

async function loadMoreResultPage(index) {
  const context = resultPageContext;
  const current = lastRenderedResults[index];
  if (!context?.sql || !current?.has_more || resultPagePromises.has(index)) return;
  const offset = context.offsets[index] || 0;
  const pending = (async () => {
    const data = await executeBackendSqlPage(context.sql, offset);
    const next = (data.results || [data])[index] || (data.results || [data]).find(item => item.status === 'table');
    if (!next || next.status !== 'table') throw new Error(t('result.previewMissing'));
    const merged = [...lastRenderedResults];
    merged[index] = {
      ...current,
      ...next,
      rows: [...(current.rows || []), ...(next.rows || [])],
      returned_rows: (Number(current.returned_rows) || (current.rows || []).length) + (Number(next.returned_rows) || (next.rows || []).length),
    };
    context.offsets[index] = offset + (next.rows || []).length;
    renderResults(merged, { sourceSql: context.sql, resultOffsets: context.offsets });
  })().catch(err => {
    log(`${t('result.loadingMore')} ${asaErrorCopy(err.message)}`);
  }).finally(() => {
    resultPagePromises.delete(index);
  });
  resultPagePromises.set(index, pending);
  await pending;
}

function renderResults(results, options = {}) {
  const nextResults = Array.isArray(results) ? results : [];
  if (options.remember !== false) lastRenderedResults = [...nextResults];
  const pageSql = pageableResultSql(options.sourceSql || (options.remember === false ? resultPageContext?.sql : ''));
  if (pageSql) {
    resultPageContext = {
      sql: pageSql,
      offsets: resultPageOffsets(nextResults, options.resultOffsets || resultPageContext?.offsets),
    };
  } else if (options.remember !== false) {
    resultPageContext = null;
    resultPagePromises.clear();
  }
  resultBox.innerHTML = '';
  const fragment = document.createDocumentFragment();
  for (const [resultIndex, r] of nextResults.entries()) {
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
        note.textContent = t('result.rowsShown', { count: formatNumber(r.returned_rows || (r.rows || []).length) });
        item.appendChild(note);
        if (resultPageContext?.sql) {
          const more = document.createElement('button');
          more.type = 'button';
          more.className = 'result-show-more';
          more.textContent = t('result.showMore');
          more.addEventListener('click', () => {
            more.disabled = true;
            more.textContent = t('result.loadingMore');
            loadMoreResultPage(resultIndex).finally(() => {
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
  }
  resultBox.appendChild(fragment);
  if (options.archive !== false) noteArchiveQuery(results, sqlInput?.value || '');
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
    : t('database.noneSelected');
  tableListObserver?.disconnect();
  tableListObserver = null;
  tableList.innerHTML = '';

  const rendered = visible.slice(0, tableListVisibleLimit);
  for (const item of rendered) {
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
    const kindLabel = localizedRelationKind(item.kind);
    drop.title = t('table.dropNamed', { kind: kindLabel, name: item.name });
    drop.setAttribute('aria-label', t('table.dropNamed', { kind: kindLabel, name: item.name }));
    drop.innerHTML = '<span class="drop-icon" aria-hidden="true"></span>';
    row.append(button, drop);
    tableList.appendChild(row);
  }
  if (visible.length > rendered.length) {
    const more = document.createElement('button');
    more.type = 'button';
    more.className = 'table-show-more';
    more.textContent = t('table.showMore');
    more.title = t('table.tablesShown', {
      shown: formatNumber(rendered.length),
      total: formatNumber(visible.length),
    });
    more.addEventListener('click', () => {
      tableListVisibleLimit += TABLE_LIST_PAGE_SIZE;
      renderTableBrowser();
    });
    tableList.appendChild(more);
    if ('IntersectionObserver' in window) {
      tableListObserver = new IntersectionObserver(entries => {
        if (entries.some(entry => entry.isIntersecting)) {
          tableListVisibleLimit += TABLE_LIST_PAGE_SIZE;
          renderTableBrowser();
        }
      }, { root: null, rootMargin: '80px' });
      tableListObserver.observe(more);
    }
  }
  renderExportTablePicker();
  updateArchiveMonitor();
}

function relationCountText(visibleCount, totalCount, tableCountValue, viewCount, filter) {
  if (filter) return t('table.countFiltered', { visible: formatNumber(visibleCount), total: formatNumber(totalCount) });
  return viewCount
    ? t('table.countViews', { tables: formatNumber(tableCountValue), views: formatNumber(viewCount) })
    : t('table.count', { count: formatNumber(tableCountValue) });
}

function renderDbSelector() {
  const names = visibleDbNames();
  const activeDb = currentDbName();
  dbSelect.innerHTML = `<option value="">${escapeHtml(t('database.select'))}</option>` +
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
  exportDbName.textContent = activeDb || t('database.noneSelected');
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
    log(t('log.databaseNameEmpty'));
    return;
  }
  const sql = `CREATE DATABASE IF NOT EXISTS ${quoteIdent(nextDb)};\nUSE ${quoteIdent(nextDb)};`;
  setSqlText(sql);
  let data;
  if (backendOnline) {
    try {
      data = await executeBackendSql(sql);
      if (hasResultError(data)) {
        renderResults(data.results || [data]);
        return;
      }
      log(t('log.databaseCreated', { name: nextDb }));
    } catch (err) {
      backendOnline = false;
      engineCheckCompleted = true;
      updateEngineStatus();
      log(t('log.databaseCreateFallback', { error: err.message }));
    }
  }
  if (!data) data = sandboxExec(sql);
  renderResults(data.results || [data]);
  if (hasResultError(data)) return;
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
      const data = await executeBackendSql(sql);
      if (hasResultError(data)) {
        renderResults(data.results || [data]);
        renderTableBrowser();
        return;
      }
    } catch (err) {
      backendOnline = false;
      engineCheckCompleted = true;
      updateEngineStatus();
      log(t('log.databaseSelectFallback', { error: err.message }));
    }
  }
  sandbox.currentDb = nextDb;
  sandbox.dbs[nextDb] ||= {};
  sandbox.views ||= {};
  sandbox.views[nextDb] ||= {};
  selectedTable = '';
  saveSandbox();
  renderTableBrowser();
  log(t('log.databaseSelected', { name: nextDb }));
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
      engineCheckCompleted = true;
      updateEngineStatus();
      log(t('log.databaseSaveFallback', { error: err.message }));
    }
  }

  saveSandbox();
  if (!data) data = { results: [{ status: 'ok', message: `saved_database(${db})` }] };
  renderResults(data.results || [data]);
  renderTableBrowser();
  log(t('log.databaseSaved', { name: db }));
}

async function dropCurrentDatabase() {
  const db = ensureCurrentDb('drop database');
  if (!db) return;
  if (!confirm(t('confirm.dropDatabase', { name: db }))) return;

  const sql = `DROP DATABASE ${quoteIdent(db)};`;
  setSqlText(sql);
  let data;
  let droppedOnBackend = false;

  if (backendOnline) {
    try {
      data = await executeBackendSql(sql, { sync: false });
      droppedOnBackend = true;
    } catch (err) {
      backendOnline = false;
      engineCheckCompleted = true;
      updateEngineStatus();
      log(t('log.dropBackendFallback', { error: err.message }));
    }
  }

  if (!data) data = sandboxExec(sql);
  renderResults(data.results || [data]);
  if (hasResultError(data)) {
    log(t('log.dropFailed', { kind: t('common.database'), name: db }));
    return;
  }

  if (droppedOnBackend) {
    try {
      if (await backendListContains('SHOW DATABASES;', db)) {
        log(t('log.dropFailed', { kind: t('common.database'), name: db }));
        return;
      }
    } catch (err) {
      log(`${t('log.dropVerifyFailed', { kind: t('common.database'), name: db })} ${err.message}`);
      return;
    }
  }

  delete sandbox.dbs[db];
  if (sandbox.views) delete sandbox.views[db];
  if (sandbox.currentDb === db) sandbox.currentDb = '';
  selectedTable = '';
  saveSandbox();
  if (droppedOnBackend) await syncCatalogFromBackend().catch(() => false);
  renderTableBrowser();
  showView('sql');
  log(t('log.dropped', { kind: t('common.database'), name: db }));
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
  const kindLabel = localizedRelationKind(kind);
  if (!confirm(t('confirm.dropTable', { kind: kindLabel, name: tableName, db }))) return;
  const sql = kind === 'view' ? `DROP VIEW IF EXISTS ${quoteIdent(tableName)};` : `DROP TABLE IF EXISTS ${quoteIdent(tableName)};`;
  let data;
  let droppedOnBackend = false;
  if (backendOnline) {
    try {
      data = await executeBackendSql(sql, { sync: false });
      droppedOnBackend = true;
    } catch (err) {
      backendOnline = false;
      engineCheckCompleted = true;
      updateEngineStatus();
      log(t('log.dropBackendFallback', { error: err.message }));
    }
  }
  if (!data) data = sandboxExec(sql);
  renderResults(data.results || [data]);
  if (hasResultError(data)) {
    log(t('log.dropFailed', { kind: kindLabel, name: tableName }));
    return;
  }
  if (droppedOnBackend) {
    try {
      if (await backendListContains('SHOW TABLES;', tableName)) {
        log(t('log.dropFailed', { kind: kindLabel, name: tableName }));
        return;
      }
    } catch (err) {
      log(`${t('log.dropVerifyFailed', { kind: kindLabel, name: tableName })} ${err.message}`);
      return;
    }
  }
  if (kind === 'view') delete sandbox.views?.[db]?.[tableName];
  else delete sandbox.dbs[db]?.[tableName];
  if (selectedTable === tableName) selectedTable = '';
  saveSandbox();
  if (droppedOnBackend) await syncCatalogFromBackend().catch(() => false);
  renderTableBrowser();
  if (currentViewName === 'table' && !selectedTable) showView('sql');
  log(t('log.dropped', { kind: kindLabel, name: tableName }));
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
      <td>${escapeHtml(view.query || t('table.viewDescription'))}</td>
    </tr>
  `;
  tableIndexBody.innerHTML = `<tr><td>VIEW</td><td class="index-column">${escapeHtml(t('table.virtualResult'))}</td></tr>`;
}

async function renderViewDataDetail(viewName) {
  if (!backendOnline) {
    tableDataBox.innerHTML = `<div class="empty-state">${escapeHtml(t('table.viewNeedsBackend'))}</div>`;
    return;
  }
  tableDataPageState = {
    sql: `SELECT * FROM ${quoteIdent(viewName)};`,
    columns: [],
    rows: [],
    offset: 0,
    total: 0,
    hasMore: true,
    loading: false,
    loadingLabel: t('table.loadingView'),
  };
  await loadTableDataPage(tableDataPageState, tableDetailRequestId);
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
  const columns = (table.columns || []).map(col => col.name);
  const localRows = (table.rows || []).map(row => columns.map(column => row[column] ?? null));
  const remoteRows = Number(table.rowCount) || 0;

  if (backendOnline && remoteRows > localRows.length) {
    tableDataPageState = {
      sql: `SELECT * FROM ${quoteIdent(tableName)};`,
      columns,
      rows: [],
      offset: 0,
      total: remoteRows,
      hasMore: true,
      loading: false,
      loadingLabel: t('table.loadingPreview'),
    };
    await loadTableDataPage(tableDataPageState, tableDetailRequestId);
    return;
  }

  tableDataBox.innerHTML = '';
  const rows = localRows;
  const tableNode = renderTable(columns, rows);
  tableNode.classList.add('legacy-data-table');
  tableDataBox.appendChild(tableNode);
}

function renderTableDataPage(state) {
  if (!state || state !== tableDataPageState) return;
  tableDataBox.innerHTML = '';
  if (state.loading && !state.rows.length) {
    tableDataBox.innerHTML = `<div class="empty-state">${escapeHtml(state.loadingLabel || t('table.loadingMore'))}</div>`;
  } else {
    const tableNode = renderTable(state.columns || [], state.rows || []);
    tableNode.classList.add('legacy-data-table');
    tableDataBox.appendChild(tableNode);
  }

  if (state.total > 0 && state.rows.length > 0) {
    const note = document.createElement('div');
    note.className = 'empty-state table-page-note';
    note.textContent = state.hasMore
      ? t('table.showingRows', { shown: formatNumber(state.rows.length), total: formatNumber(state.total) })
      : t('result.allRows', { count: formatNumber(state.rows.length) });
    tableDataBox.appendChild(note);
  }

  if (state.hasMore && !state.loading) {
    const more = document.createElement('button');
    more.type = 'button';
    more.className = 'table-show-more';
    more.textContent = t('table.showMore');
    more.addEventListener('click', () => loadTableDataPage(state, state.requestId));
    tableDataBox.appendChild(more);
  }
}

async function loadTableDataPage(state, requestId = tableDetailRequestId) {
  if (!state || state !== tableDataPageState || state.loading || requestId !== tableDetailRequestId) return;
  state.loading = true;
  state.requestId = requestId;
  renderTableDataPage(state);
  try {
    const data = state.offset > 0
      ? await executeBackendSqlPage(state.sql, state.offset)
      : await executeBackendSql(state.sql, { sync: false });
    const result = (data.results || [data]).find(item => item.status === 'table');
    if (!result) throw new Error(data.message || t('result.previewMissing'));
    if (requestId !== tableDetailRequestId || state !== tableDataPageState) return;
    state.columns = result.columns || state.columns;
    state.rows.push(...(result.rows || []));
    state.offset += (result.rows || []).length;
    state.hasMore = Boolean(result.has_more) || (state.total > 0 && state.offset < state.total);
  } catch (err) {
    if (requestId === tableDetailRequestId && state === tableDataPageState) {
      tableDataBox.innerHTML = `<div class="empty-state error-text">${escapeHtml(ASA_ERROR_LABEL)}: ${escapeHtml(asaErrorCopy(err.message))}</div>`;
    }
    return;
  } finally {
    state.loading = false;
  }
  renderTableDataPage(state);
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
      <button class="mini-button create-row-add" type="button" title="${escapeHtml(t('table.addColumn'))}" aria-label="${escapeHtml(t('table.addColumn'))}">+</button>
      <button class="mini-button create-row-up" type="button" title="${escapeHtml(t('table.moveUp'))}" aria-label="${escapeHtml(t('table.moveUp'))}">&uarr;</button>
      <button class="mini-button create-row-down" type="button" title="${escapeHtml(t('table.moveDown'))}" aria-label="${escapeHtml(t('table.moveDown'))}">&darr;</button>
      <button class="mini-button create-row-delete" type="button" title="${escapeHtml(t('table.deleteColumn'))}" aria-label="${escapeHtml(t('table.deleteColumn'))}">x</button>
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
    log(t('log.tableNameEmpty'));
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
    log(t('log.tableColumnsEmpty'));
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
      if (hasResultError(data)) return;
    } catch (err) {
      backendOnline = false;
      engineCheckCompleted = true;
      updateEngineStatus();
      log(t('log.tableCreateFallback', { error: err.message }));
    }
  }

  sandbox.dbs[activeDb] ||= {};
  sandbox.dbs[activeDb][tableName] = tableRecord;
  saveSandbox();
  renderTableBrowser();
  log(t('log.tableCreated', { name: tableName }));
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

function startImportOperation(operation) {
  if (importOperationPromise) return importOperationPromise;
  const pending = Promise.resolve().then(operation).finally(() => {
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

async function importFromFilesOnce() {
  const files = Array.from(importFileInput.files || []);
  if (!files.length) {
    importSummary.textContent = t('import.noFile');
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
          log(t('log.importRejected', { name: file.name, error: backendErr.message }));
          summary = await importUploadedFileWithBackend(file);
        }
      } else if (useBackendSql && shouldUploadFileToBackend(file)) {
        summary = await importUploadedFileWithBackend(file);
      } else if (!backendOnline && shouldUseBackendFileImport(file.name, importFormat.value) && file.size > BROWSER_SQL_IMPORT_LIMIT_BYTES) {
        throw new Error(t('import.largeBackendRequired'));
      } else {
        summary = await importFromBuffer(file.name, await file.arrayBuffer(), importFormat.value);
      }
      summaries.push(summary);
    } catch (err) {
      summaries.push(err.reservoirStatus === 'cancelled'
        ? `${file.name}: ${t('import.cancelled')}`
        : `${file.name}: ${ASA_ERROR_LABEL} ${asaErrorCopy(err.message)}`);
      log(t('log.importFailed', { name: file.name, error: err.message }));
      if (importStopOnError.checked) break;
    }
  }
  importFileInput.value = '';
  importSummary.textContent = summaries.join('\n');
  renderTableBrowser();
}

function importFromServerFile() {
  return startImportOperation(importFromServerFileOnce);
}

async function importFromServerFileOnce() {
  const path = importServerPath.value.trim();
  if (!path) return;
  try {
    if (backendOnline && shouldUseBackendFileImport(path, importFormat.value)) {
      importSummary.textContent = await importServerPathWithBackend(path);
      return;
    }
    if (!backendOnline && isKnownHugeServerImport(path)) {
      throw new Error(t('import.largeBackendRequired'));
    }
    const res = await fetch(path, { cache: 'no-store' });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const summary = await importFromBuffer(path, await res.arrayBuffer(), importFormat.value);
    importSummary.textContent = summary;
  } catch (err) {
    importSummary.textContent = err.reservoirStatus === 'cancelled'
      ? t('import.cancelled')
      : `${ASA_ERROR_LABEL}: ${asaErrorCopy(err.message)}`;
    log(t('log.serverImportFailed', { error: err.message }));
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
  if (/^public_safety_archive_\d+\.sql$/i.test(name)) return `stress tests/${name}`;
  return '';
}

function isKnownHugeServerImport(path) {
  return /(?:^|[\\/])public_safety_archive_1275080\.sql$/i.test(String(path || ''));
}

function makeImportId() {
  return `import-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

async function importServerPathWithBackend(path, sizeHint = 0) {
  noteArchiveImportStart(path, sizeHint);
  log(t('log.reservoirFileStart', { name: path }));
  const data = await startReservoirFile(path, {
    kind: 'import-file',
    label: path,
    sizeBytes: sizeHint,
    stopOnError: importStopOnError.checked,
    onProgress: ({ completed, total, statements, label }) => {
      const percent = total ? Math.min(100, Math.round((completed / total) * 100)) : 0;
      setLastRunKey('progress.reservoir', { percent, count: statements });
      noteArchiveSqlProgress('', completed, total, label);
    },
  });

  const results = data.results || [data];
  renderResults(results);
  const summaryTable = results.find(result => result.status === 'table');
  const row = summaryTable?.rows?.[0] || [];
  const status = row[0] || 'ok';
  const statements = Number(row[2]) || 0;
  const errors = Number(row[3]) || 0;
  const sizeBytes = Number(row[6]) || sizeHint || 0;

  await Promise.all([
    syncCatalogFromBackend().catch(() => false),
    refreshDatabaseMetadata().catch(() => null),
  ]);
  noteArchiveImportComplete(path, sizeBytes, summaryTable?.columns || ['status'], summaryTable?.rows || [[status]], statements);
  setSqlText(`-- Backend Prolog import: ${path}\nSHOW TABLES;\nSELECT COUNT(*) AS total_rows FROM Public_Safety_Archive;`);
  setLastRunKey('progress.backendSteps', { count: statements });
  renderTableBrowser();
  const summary = t('import.backendSummary', { name: path, statements: formatNumber(statements), errors: formatNumber(errors) });
  log(summary);
  if (errors > 0) throw new Error(summary);
  return summary;
}

async function importUploadedFileWithBackend(file) {
  noteArchiveImportStart(file.name, file.size || 0);
  log(t('log.reservoirUploadStart', { name: file.name }));
  const data = await submitReservoirPayload(file, {
    kind: 'import-upload',
    label: file.name,
    sizeBytes: file.size || 0,
    contentType: file.type || 'application/sql',
    stopOnError: importStopOnError.checked,
    onProgress: ({ completed, total, statements }) => {
      const percent = total ? Math.min(100, Math.round((completed / total) * 100)) : 0;
      setLastRunKey('progress.reservoir', { percent, count: statements });
    },
  });

  const results = data.results || [data];
  renderResults(results);
  const summaryTable = results.find(result => result.status === 'table');
  const row = summaryTable?.rows?.[0] || [];
  const status = row[0] || 'ok';
  const statements = Number(row[2]) || 0;
  const errors = Number(row[3]) || 0;
  const sizeBytes = Number(row[6]) || file.size || 0;

  await Promise.all([
    syncBackendStateSmart().catch(() => syncCatalogFromBackend().catch(() => false)),
    refreshDatabaseMetadata().catch(() => null),
  ]);
  noteArchiveImportComplete(file.name, sizeBytes, summaryTable?.columns || ['status'], summaryTable?.rows || [[status]], statements);
  setSqlText(`-- Uploaded through Prolog backend: ${file.name}\nSHOW TABLES;`);
  setLastRunKey('progress.backendSteps', { count: statements });
  renderTableBrowser();
  const summary = t('import.uploadSummary', { name: file.name, statements: formatNumber(statements), errors: formatNumber(errors) });
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
  let summary = t('import.conversion', { name, format: FORMAT_LABELS[format] });
  let backendMutation = false;
  noteArchiveImportStart(name, rawBuffer.byteLength || buffer.byteLength || 0);

  if (format === 'asadb') {
    const imported = parseAsaDbBuffer(buffer);
    mergeSandbox(imported, mode === 'replace');
    saveSandbox();
    const preview = firstImportedTablePreview(imported);
    noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, preview.columns, preview.rows, preview.rowCount);
    summary += `, ${t('import.tablesLoaded', { count: formatNumber(countTables(imported)) })}`;
  } else if (format === 'csv') {
    if (!ensureCurrentDb('import CSV')) throw new Error(t('import.databaseRequired', { format: 'CSV' }));
    const tableName = importTargetTable.value.trim() || sanitizeName(baseName(cleanName));
    const matrix = parseCsv(decodeText(buffer));
    upsertMatrixTable(tableName, matrix, mode);
    noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, matrix[0] || [], matrix.slice(1, 5), Math.max(0, matrix.length - 1));
    summary += `, ${t('import.tableRows', { table: tableName, count: formatNumber(Math.max(0, matrix.length - 1)) })}`;
  } else if (format === 'xlsx') {
    if (!ensureCurrentDb('import XLSX')) throw new Error(t('import.databaseRequired', { format: 'XLSX' }));
    const workbook = await readXlsxWorkbook(buffer);
    for (const sheet of workbook.sheets) {
      const tableName = sanitizeName(sheet.name || baseName(cleanName));
      upsertMatrixTable(tableName, sheet.rows, mode);
    }
    const firstSheet = workbook.sheets[0] || { rows: [] };
    noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, firstSheet.rows[0] || [], (firstSheet.rows || []).slice(1, 5), Math.max(0, (firstSheet.rows || []).length - 1));
    summary += `, ${t('import.sheetsLoaded', { count: formatNumber(workbook.sheets.length) })}`;
  } else if (format === 'mysql' || format === 'postgresql') {
    const sql = convertDialectToAsaSql(decodeText(buffer), format);
    let data;
    if (backendOnline) {
      const plan = createSqlExecutionPlan(sql);
      backendMutation = true;
      data = plan.mode === 'reservoir'
        ? await executeBackendSqlStreamed(sql, {
            kind: 'import-conversion',
            label: name,
            sizeBytes: rawBuffer.byteLength || buffer.byteLength || 0,
            stopOnError: importStopOnError.checked,
            onProgress: ({ completed, total, statements }) => {
              const percent = total ? Math.min(100, Math.round((completed / total) * 100)) : 0;
              setLastRunKey('progress.importing', { percent, count: statements });
            },
          })
        : await executeBackendSql(sql, { sync: false });
    } else if (sql.length > 100000) {
      throw new Error(t('import.largeBackendRequired'));
    } else {
      data = sandboxExecWithOptions(sql, {
        stopOnError: importStopOnError.checked,
        showOnlyErrors: importShowOnlyErrors.checked,
      });
    }
    renderResults(data.results || [data]);
    if (sql.length < 500000) setSqlText(sql);
    else setSqlText(`-- Large SQL imported through Prolog backend: ${name}\nSHOW TABLES;`);
    const allResults = data.allResults || data.results || [];
    const statementCount = Number(data.statementCount || allResults.length || 0);
    setLastRunKey('import.statements', { count: statementCount });
    noteArchiveImportComplete(name, rawBuffer.byteLength || buffer.byteLength || 0, ['statement', 'status'], allResults.slice(0, 4).map((result, index) => [index + 1, result.status || 'ok']), statementCount);
    summary += `, ${t('import.statements', { count: formatNumber(statementCount) })}`;
  } else {
    throw new Error(t('import.unsupportedFormat', { format }));
  }

  if (backendMutation) {
    await Promise.all([
      syncBackendStateSmart().catch(() => syncCatalogFromBackend().catch(() => false)),
      refreshDatabaseMetadata().catch(() => null),
    ]);
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
  if (!activeDb) throw new Error(t('database.selectFirst'));
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
      log(t('log.fileOpened', { name: filename }));
    } else {
      downloadBlob(blob, filename);
      log(t('log.fileDownloaded', { name: filename }));
    }
  } catch (err) {
    exportPreview.textContent = `${ASA_ERROR_LABEL}: ${asaErrorCopy(err.message)}`;
    log(t('log.exportFailed', { error: err.message }));
  }
}

async function buildExportPackage(format) {
  const db = ensureCurrentDb('export');
  if (!db) throw new Error(t('database.selectFirst'));
  const selection = getExportSelection();
  if (!selection.length) throw new Error(t('export.noTables'));

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
  throw new Error(t('import.unsupportedFormat', { format }));
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

sqlInput.addEventListener('paste', () => {
  sqlPasteInProgress = true;
  sqlPasteAnchor = { top: sqlInput.scrollTop, left: sqlInput.scrollLeft };
  requestAnimationFrame(() => {
    sqlPasteInProgress = false;
  });
});
sqlInput.addEventListener('input', (event) => {
  const pasted = sqlPasteInProgress || event.inputType === 'insertFromPaste';
  if (!pasted) applySqlAutoCorrection(false);
  const scrollTop = pasted
    ? Math.max(sqlPasteAnchor.top, sqlInput.scrollTop, sqlCaretScrollTarget())
    : sqlInput.scrollTop;
  const scrollLeft = pasted ? Math.max(sqlPasteAnchor.left, sqlInput.scrollLeft) : sqlInput.scrollLeft;
  updateSqlEditor({ scrollTop, scrollLeft, persistScroll: pasted });
  scheduleSqlAnalysis();
  updateSqlCompletions();
});
sqlInput.addEventListener('scroll', syncSqlScroll);
sqlInput.addEventListener('keydown', (event) => {
  if (sqlCompletionState.open) {
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const direction = event.key === 'ArrowDown' ? 1 : -1;
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
sqlInput.addEventListener('click', () => updateSqlCompletions());
sqlInput.addEventListener('keyup', (event) => {
  if (!['ArrowDown', 'ArrowUp', 'Enter', 'Tab', 'Escape'].includes(event.key)) updateSqlCompletions();
});
sqlInput.addEventListener('blur', () => setTimeout(closeSqlCompletions, 120));

runBtn.addEventListener('click', runSql);
languageSwitcher?.addEventListener('click', (event) => {
  const button = event.target.closest('[data-language]');
  if (button) setLanguage(button.dataset.language);
});
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
  log(t('sandbox.resetDone'));
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
importCancelBtn.addEventListener('click', cancelActiveReservoirJob);
dbMetadataPanel?.addEventListener('toggle', () => {
  if (dbMetadataPanel.open) scheduleMetadataPoll(0);
});
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState !== 'hidden') scheduleMetadataPoll(0);
});
window.addEventListener('focus', () => scheduleMetadataPoll(0));
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
tableSearch.addEventListener('input', () => {
  tableListVisibleLimit = TABLE_LIST_PAGE_SIZE;
  renderTableBrowser();
});
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

setLanguage(currentLanguage, false);
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
// app-loader.js uses this marker to show a useful error rather than leaving a
// static-looking page should an unsupported browser reject the UI bundle.
window.__asadbUiReady = true;
runStartupWarmup(checkEngine());
