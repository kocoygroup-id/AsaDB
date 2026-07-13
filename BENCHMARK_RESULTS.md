# AsaDB v1.2.1 Storage Benchmark

Measured on Windows with SWI-Prolog. The generated workload uses a table with
three columns and 100-row multi-value INSERT statements. Every run verifies
COUNT, indexed lookup, indexed range/order behavior, UPDATE, DELETE, bounded
result retrieval, shutdown, reopen, and persisted row count.

| Rows | Import | First indexed lookup and build | Indexed ORDER/LIMIT | UPDATE | DELETE | 500-row result | Peak working set | Result |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10,000 | 7.1 s | 6.1 s | 80 ms | 144 ms | 109 ms | 804 ms | not separately sampled | PASS |
| 50,000 | 34.7 s | 31.6 s | 46 ms | 234 ms | 213 ms | 948 ms | 229.9 MB | PASS |
| 100,000 | 73.9 s | 76.1 s | 19 ms | 519 ms | 401 ms | 654 ms | 229.8 MB | PASS |

The measured 50,000 and 100,000-row runs had the same approximately 230 MB
peak working set. The configured logical buffer pool was 64 x 4 KB pages; peak
working set also includes the SWI-Prolog runtime, parser, temporary external
sort runs, and benchmark process.

The earlier 100,000-row prototype baseline took almost 11 minutes and peaked at
about 820 MB. The final measured run completed in about 247 seconds and peaked
at 229.8 MB.

Run all sizes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run_storage_benchmarks.ps1
```

Run one size directly:

```powershell
swipl -q -s tests\stress_100k.pl -- 100000
```

These numbers are project measurements, not a claim of performance parity with
CouchDB, PostgreSQL, MySQL, or another production database.
