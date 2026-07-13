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
| CREATE TABLE | Implemented |
| DROP TABLE | Implemented |
| TRUNCATE TABLE | Implemented |
| ALTER TABLE | Implemented subset |
| CREATE INDEX | Implemented metadata index |
| DROP INDEX | Implemented metadata index |
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
| EXPLAIN | Implemented placeholder |
| REPLACE | Planned |
| LOAD DATA INFILE | Planned |
| UNION | Implemented basic UNION / UNION ALL |
| JOIN | Implemented subset: INNER, LEFT, RIGHT |
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

## Type mapping awal

AsaDB v1 menyimpan value sebagai term Prolog. Type SQL disimpan sebagai metadata kolom, belum melakukan strict coercion penuh.

| MySQL type | AsaDB v1 behavior |
|---|---|
| INT / INTEGER / BIGINT | numeric value if literal numeric |
| DECIMAL / FLOAT / DOUBLE / REAL | numeric value if literal numeric |
| VARCHAR / CHAR | atom/string literal |
| TEXT / MEDIUMTEXT / LONGTEXT | atom/string literal |
| DATE / TIME / DATETIME / TIMESTAMP / YEAR | metadata type, value stored as literal |
| NULL | `null` |
| DEFAULT | metadata, dipakai saat insert kolom kosong |

## Production foundation yang sudah aktif

- Expression evaluator untuk `AND`, `OR`, `NOT`, `IN`, `LIKE`, `BETWEEN`, comparison, arithmetic sederhana, `CASE`, subquery basic, dan fungsi `LOWER`, `UPPER`, `LENGTH`, `CONCAT`, `SUBSTRING`, `TRIM`, `REPLACE`, `COALESCE`.
- SELECT multi-table basic via `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`, plus `GROUP BY` dan aggregate `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`.
- Basic `UNION` / `UNION ALL` dan view sederhana berbasis SELECT.
- Metadata index via `CREATE INDEX`, `DROP INDEX`, `SHOW INDEX`; executor memakai equality predicate yang cocok sebagai candidate filter awal.
- Snapshot transaction untuk `START TRANSACTION`, `COMMIT`, `ROLLBACK`, plus journal `.asa.journal`.
- In-process write mutex dan `LOCK TABLES`/`UNLOCK TABLES` guard.
- Basic user catalog: `CREATE USER`, `DROP USER`, `GRANT`, `REVOKE`, `SHOW GRANTS`, dan `LOGIN ... IDENTIFIED BY ...`.

## Prinsip kompatibilitas

1. AsaDB harus menerima SQL umum MySQL-style sebisa mungkin.
2. Jika belum bisa dieksekusi, error harus jelas menyebut feature-nya.
3. Syntax expansion dilakukan bertahap dari statement yang paling sering dipakai.
4. Storage `.asa` tidak harus sama dengan MySQL; kompatibilitas berada di layer SQL.
