# AsaDB v1.0.0

AsaDB v1.0.0 adalah paket publik siap upload untuk menjalankan AsAPanel dan engine AsaDB lokal berbasis Prolog tanpa membuka source engine.

## Jalankan Cepat

1. Double click `START_ASADB.bat`.
2. Panel akan terbuka di `http://127.0.0.1:8088`.
3. Buat database, jalankan SQL, atau import `samples/feature-tour.sql`.

Kalau browser tidak terbuka otomatis, buka manual:

```text
http://127.0.0.1:8088
```

## CLI Sample

Double click `RUN_CLI_SAMPLE.bat` untuk menjalankan demo SQL lengkap lewat CLI.

Atau manual:

```bat
cd app
AsA.exe cli ..\data\sample-run.asa ..\samples\feature-tour.sql
```

## Yang Disupport Di v1.0.0

- Database/table dasar: `CREATE`, `DROP`, `USE`, `SHOW`, `DESCRIBE`
- DML: `INSERT`, `SELECT`, `UPDATE`, `DELETE`, `TRUNCATE`
- `ALTER TABLE`: add/drop/modify/change/rename column, rename table
- SELECT kritikal: `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`
- `GROUP BY` dan aggregate: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`
- Basic subquery: `IN (SELECT ...)` dan scalar subquery
- `UNION`, `CASE`, `CONCAT`, `LOWER`, `UPPER`
- View: `CREATE VIEW`, `DROP VIEW`, dan `SELECT` dari view
- Metadata routine: `CREATE/DROP FUNCTION`, `PROCEDURE`, `TRIGGER`
- Basic index metadata: `CREATE INDEX`, `DROP INDEX`, `SHOW INDEX`
- Transaction snapshot: `BEGIN`, `START TRANSACTION`, `COMMIT`, `ROLLBACK`
- User/permission catalog: `CREATE USER`, `GRANT`, `REVOKE`, `SHOW GRANTS`, `LOGIN`

## Struktur Paket

```text
AsaDB v1.0.0/
+-- app/                  runtime portable + AsAPanel
|   +-- AsA.exe            executable utama
|   +-- web/               UI panel lokal
+-- data/                 database lokal user, ignored by git
+-- samples/              demo SQL aman
+-- START_ASADB.bat
+-- START_ASADB_NO_BROWSER.bat
+-- RUN_CLI_SAMPLE.bat
+-- LICENSE.md
+-- SECURITY.md
```

## Proteksi Engine

Source Prolog (`src/`, `tests/`, docs internal, tools dev, file `.asa` pribadi) tidak ikut dalam paket ini. UI publik dipaksa memakai backend Prolog lokal dari `AsA.exe`, bukan fallback engine JavaScript.

File database user tersimpan di `data/*.asa` dan `data/*.journal`; file ini sudah di-ignore supaya tidak ikut ke GitHub.

## Upload Ke GitHub

Jadikan folder ini repo baru, bukan folder project developer asli.

```bat
cd "AsaDB-v1.0.0-Windows"
git init
git add .
git commit -m "AsaDB v1.0.0 public release"
git branch -M main
git remote add origin https://github.com/USERNAME/REPO.git
git push -u origin main
```

Kalau mau aman maksimal, buat repo GitHub baru khusus rilis publik dan jangan upload folder project asli.
