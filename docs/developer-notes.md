# AsaDB Developer Notes

## Menambah statement baru

1. Tambahkan keyword jika belum ada di `keyword/1` dalam `src/asadb_core.pl`.
2. Tambahkan rule `parse_statement/2` yang menghasilkan AST baru.
3. Tambahkan rule `execute_statement/2` untuk AST tersebut.
4. Tambahkan test SQL di `tests/smoke.sql` atau test baru.
5. Update `src/asadb_mysql55_compat.pl` dan `docs/mysql55-compatibility.md`.

## Menambah expression evaluator

Saat ini evaluator `WHERE`/`UPDATE SET` mendukung:

```sql
WHERE col = value
WHERE col != value
WHERE col <> value
WHERE col > value
WHERE col < value
WHERE col >= value
WHERE col <= value
WHERE col IS NULL
WHERE col IS NOT NULL
WHERE a = 1 AND b = 2
WHERE a = 1 OR b = 2
WHERE NOT a = 1
WHERE id IN (1, 2, 3)
WHERE name LIKE 'Air%'
WHERE qty BETWEEN 2 AND 10
UPDATE t SET qty = qty + 1
```

Parser ekspresi masih hand-written precedence parser. Kalau grammar makin melebar ke function call kompleks, subquery, dan aggregate expression, langkah berikutnya adalah memindahkan `parse_expr/2` ke DCG/Pratt parser yang lebih eksplisit.

## Menambah JOIN

Rencana AST:

```prolog
select(Projection, from(Table, Alias, Joins), Where, Order, Limit)
join(Type, Table, Alias, OnExpression)
```

Executor bisa mulai dari nested loop join sederhana, lalu nanti optimizer cost-based.

## Menambah index

Rencana metadata:

```prolog
index(Name, Table, Columns, unique(false), root(PageId))
```

Versi term-storage saat ini menyimpan metadata index langsung di tabel:

```prolog
table(Name, Columns, Rows, Indexes)
index(Name, Columns, unique)
index(Name, Columns, non_unique)
```

Executor sudah memakai equality predicate yang match index sebagai candidate filter awal. Langkah berikutnya untuk production-grade penuh adalah mengganti metadata ini dengan page-based B+Tree di `.asa` v2.

## Transaksi dan permission

`START TRANSACTION` membuat snapshot state, `COMMIT` menyimpan `.asa`, dan `ROLLBACK` mengembalikan snapshot. Setiap write menulis journal append-only di `data.asa.journal`.

User/grant disimpan di database internal `__asadb_catalog`. User default adalah `admin`; user biasa bisa login dengan:

```sql
LOGIN reader IDENTIFIED BY 'pw';
```

Permission check sudah aktif untuk `SELECT`, `INSERT`, `UPDATE`, `DELETE`, dan `ALTER` pada scope `db.table`, `db.*`, atau `*.*`.

## Build release

`qsave_program/2` bisa membuat saved state SWI-Prolog:

```bash
mkdir -p build
swipl -q -s src/asadb_release.pl
```

Untuk `.exe` Windows, gunakan SWI-Prolog Windows + wrapper installer seperti Inno Setup/NSIS/IExpress sesuai kebutuhan.
