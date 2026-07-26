# Backend Data Interchange

AsaDB supports backend-owned import and export for MySQL SQL, PostgreSQL SQL,
CSV, and XLSX. Portable interchange is separate from the authenticated
`.asb` production-backup format:

- use `.asb` for complete logical backup and verified disaster recovery;
- use MySQL/PostgreSQL SQL, CSV, or XLSX to exchange selected tables with
  other tools.

The browser sends only format and selection controls.
`src/asadb_interchange.pl` holds the normal backend execution lock for export
and scans verified record pages directly, so a large export does not depend on
rows currently loaded in AsAPanel.

## Formats

| Format | Export | Import behavior |
| --- | --- | --- |
| MySQL SQL | `CREATE TABLE`, indexes, and 256-row multi-value `INSERT` batches | Common dump controls are removed and portable DDL/DML enters the normal AsaDB parser and transaction path. |
| PostgreSQL SQL | PostgreSQL identifiers/types plus streaming `COPY ... FROM stdin` data | `COPY` rows become bounded multi-value inserts; common schema qualifiers and portable type casts are normalized. |
| CSV | One selected table produces `.csv`; multiple tables produce a ZIP containing one CSV per table | Plain CSV and AsaDB `-csv.zip` packages are accepted. Header names are sanitized and deduplicated; the first 256 rows infer `BIGINT`, `DOUBLE`, or `TEXT`; remaining rows stream to bounded inserts. |
| XLSX | A valid OOXML workbook with one sheet per selected table | ZIP paths/counts/sizes are validated; worksheets are parsed row by row; a 256-row sample infers column types without materializing the workbook. |

CSV and XLSX imports support `replace` (`DROP` then `CREATE`) and `append`
(`CREATE IF NOT EXISTS`, then insert). The target table field names the first
CSV table or XLSX sheet; additional workbook sheets receive a sanitized sheet
suffix.

## Execution and safety

Uploaded interchange files enter the durable Reservoir spool with their
format, source name, target, and write mode. The worker prepares bounded AsaDB
SQL in Prolog, then uses the existing transactional streaming importer.
Cancellation, rollback, capacity limits, persisted progress, idempotency, and
single-writer execution therefore remain active.

XLSX input is rejected if it contains an unsafe member path, more than 4,096
ZIP entries, an entry larger than 256 MiB, or more than 512 MiB of declared
uncompressed data. XML DTD and entity declarations are rejected before
workbook parsing. These are defensive input limits, not recommended workbook
sizes.

MySQL and PostgreSQL have vendor-specific extensions. The interchange layer
covers the portable dump surface tested by AsaDB; unsupported procedural
objects, extensions, custom types, and vendor-only clauses are reported by the
normal parser rather than silently accepted.

## HTTP contract

Authenticated portable export uses `POST /api/export` with:

- `database`;
- `format=mysql|postgresql|csv|xlsx`;
- `tables` and `data_tables` as comma-separated backend table names;
- `include_schema`, `include_data`, `create_database`, and `drop_tables`;
- `output=save|open`.

Raw imports use `POST /api/reservoir/jobs`. AsAPanel supplies
`X-AsaDB-Import-Format`, `X-AsaDB-Import-Name`,
`X-AsaDB-Import-Table`, and `X-AsaDB-Import-Mode`. Production `.asb` files
continue to use `POST /api/import_upload` so backup integrity verification
cannot be bypassed.

## Validation

Run:

```sh
make test-interchange
make test-interchange-stress
```

The regression covers Unicode, `NULL`, quotes, multiline values, MySQL
multi-row inserts, PostgreSQL `COPY`, CSV quoting/type inference, XLSX
OOXML/ZIP validation, authenticated HTTP export, Reservoir import, and
backend row verification. On the recorded PCLinuxOS audit host, four exports
plus CSV and XLSX preparation over 20,000 rows per format completed in about
9.7 seconds. This is a development measurement, not a universal latency
guarantee.
