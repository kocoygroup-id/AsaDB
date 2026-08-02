# AsaDB MySQL 5.5 Compatibility Target

AsaDB menargetkan sintaks MySQL 5.5 sebagai dialek SQL utama. Implementasi saat ini memakai model bertahap.

## Status legend

- **Implemented**: sudah diparse dan dieksekusi oleh executor.
- **Metadata stub**: dikenali parser dan disimpan sebagai metadata, tetapi belum menjalankan body/view.
- **Parsed stub**: dikenali parser, tetapi executor mengembalikan pesan belum diimplementasikan.
- **Planned**: masuk roadmap.

## DDL

| Statement | Status |
|---|---:|
| CREATE DATABASE | Implemented |
| DROP DATABASE | Implemented |
| CREATE TABLE | Implemented, including enforced PRIMARY KEY/UNIQUE, CHECK, and table-level FOREIGN KEY ... RESTRICT |
| DROP TABLE | Implemented |
| TRUNCATE TABLE | Implemented |
| ALTER TABLE | Implemented subset |
| CREATE INDEX | Implemented persistent index metadata and B+Tree candidate path |
| DROP INDEX | Implemented |
| CREATE VIEW | Implemented basic SELECT view |
| CREATE TRIGGER | Metadata stub |
| CREATE PROCEDURE | Metadata stub |
| CREATE FUNCTION | Metadata stub |

## DML/DQL

| Statement | Status |
|---|---:|
| INSERT INTO ... VALUES | Implemented |
| SELECT ... FROM | Implemented subset + expressions/order/offset/joins/group/subqueries |
| UPDATE ... SET ... WHERE | Implemented subset + expression SET/WHERE |
| DELETE FROM ... WHERE | Implemented subset + expression WHERE |
| SHOW DATABASES | Implemented |
| SHOW TABLES | Implemented |
| DESCRIBE / DESC | Implemented |
| SHOW COLUMNS | Implemented |
| SHOW INDEX | Implemented |
| SHOW CREATE TABLE | Implemented |
| EXPLAIN | Implemented catalog-derived access plan (scan/index access, index, estimate, sort note) |
| REPLACE | Planned |
| LOAD DATA INFILE | Planned |
| UNION | Implemented basic UNION / UNION ALL |
| JOIN | Implemented subset: INNER, LEFT, RIGHT, CROSS, comma join, and USING |
| GROUP BY | Implemented subset |
| HAVING | Planned |
| Aggregate functions | Implemented subset: COUNT, SUM, AVG, MIN, MAX |
| Subqueries | Implemented basic: IN, EXISTS, scalar SELECT |
| CASE expression | Implemented basic searched/simple CASE |

## Transaction / Admin / Permission

| Statement | Status |
|---|---:|
| START TRANSACTION | Implemented snapshot transaction |
| COMMIT | Implemented journaled commit |
| ROLLBACK | Implemented snapshot rollback |
| LOCK TABLES | Implemented in-process write guard |
| UNLOCK TABLES | Implemented |
| CREATE USER / DROP USER | Implemented catalog basic |
| GRANT | Implemented catalog basic |
| REVOKE | Implemented catalog basic |

## Type and integrity contract

Before a row is written, AsaDB validates the completed row after `DEFAULT` and
`AUTO_INCREMENT` expansion. It does not silently coerce a text literal into a
number or date: an incompatible value is rejected and the statement leaves the
record store unchanged. Existing databases are read as-is; validation applies
to new `INSERT` and `UPDATE` writes.

| SQL type | Current write contract |
|---|---|
| TINYINT / SMALLINT / MEDIUMINT / INT / INTEGER / BIGINT | integer only, with signed range checks; `UNSIGNED` uses the corresponding non-negative range |
| DECIMAL(p,s) | numeric only; precision and scale are bounded by `(p,s)` |
| FLOAT / DOUBLE / REAL | numeric only |
| VARCHAR(n) / CHAR(n) | atom/string only; maximum character length `n` |
| TEXT / TINYTEXT / MEDIUMTEXT / LONGTEXT | atom/string only |
| DATE / TIME / DATETIME / TIMESTAMP / YEAR | ISO calendar/time validation, including leap-year dates |
| BOOL / BOOLEAN | `TRUE`, `FALSE`, `0`, or `1` |
| NULL / DEFAULT | `NULL` is rejected by `NOT NULL`/primary key; defaults are expanded before validation |

### Enforced constraints

- Column and composite `PRIMARY KEY` / `UNIQUE` are checked on inserts and
  updates. Composite unique keys allow multiple rows containing `NULL`, while
  a primary-key component may not be `NULL`.
- Column and table-level `CHECK` expressions are evaluated before mutation.
  SQL `UNKNOWN` caused by `NULL` passes a `CHECK`; use `NOT NULL` when NULL is
  not allowed.
- Table-level `FOREIGN KEY (...) REFERENCES ... (...) ON DELETE RESTRICT ON
  UPDATE RESTRICT` requires a unique/primary referenced key and is enforced on
  child writes as well as parent deletes/key updates.
- `CASCADE` and `SET NULL` are intentionally rejected at DDL time for now;
  they are not accepted as no-op metadata.

## Production foundation yang sudah aktif

- Expression evaluator untuk `AND`, `OR`, `XOR`, `NOT`, literal `TRUE`/`FALSE`/`UNKNOWN`, predicate `IS [NOT] TRUE/FALSE/UNKNOWN`, `IN`, `LIKE`, `BETWEEN`, comparison, arithmetic sederhana, `CASE`, subquery basic, dan fungsi `LOWER`, `UPPER`, `LENGTH`, `CONCAT`, `SUBSTRING`, `TRIM`, `REPLACE`, `COALESCE`.
- SELECT multi-table basic via `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`, `CROSS JOIN`, comma join, dan `JOIN ... USING (...)`, plus `GROUP BY` dan aggregate `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`.
- Basic `UNION` / `UNION ALL` dan view sederhana berbasis SELECT.
- Persistent index metadata via `CREATE INDEX`, `DROP INDEX`, `SHOW INDEX`;
  executor uses suitable equality/range predicates as candidate paths.
- Snapshot transaction untuk `START TRANSACTION`, `COMMIT`, `ROLLBACK`, plus journal `.asa.journal`.
- In-process write mutex dan `LOCK TABLES`/`UNLOCK TABLES` guard.
- Basic user catalog: `CREATE USER`, `DROP USER`, `GRANT`, `REVOKE`, `SHOW GRANTS`, dan `LOGIN ... IDENTIFIED BY ...`.

## Prinsip kompatibilitas

1. AsaDB harus menerima SQL umum MySQL-style sebisa mungkin.
2. Jika belum bisa dieksekusi, error harus jelas menyebut feature-nya.
3. Syntax expansion dilakukan bertahap dari statement yang paling sering dipakai.
4. Storage `.asa` tidak harus sama dengan MySQL; kompatibilitas berada di layer SQL.
