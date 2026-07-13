# AsaDB `.asa` Binary Format

Format awal `.asa` sengaja sederhana agar mudah dioprek.

## Layout v1

```text
+----------------------+--------------------------+
| ASADB001\n            | magic header              |
+----------------------+--------------------------+
| decimal checksum\n    | checksum payload decoded   |
+----------------------+--------------------------+
| encoded payload      | XOR canonical term bytes |
+----------------------+--------------------------+
```

## Payload decoded

Payload decoded adalah canonical Prolog term:

```prolog
state(1, [
  db(asa, [
    table(users,
      [col(id,'int',[not_null]), col(name,'varchar ( 100 )',[])],
      [row([id=1,name='Aires'])]
    )
  ])
])
```

## Kenapa bukan plaintext `.sql`?

`.sql` adalah input/export manusia. `.asa` adalah storage lokal engine. Pada versi awal, payload masih mudah dikembalikan karena tujuannya bukan enkripsi, melainkan struktur biner lokal.

## Versi berikutnya

Rencana format page-based:

```text
File Header Page
Catalog Page
Table Root Pages
Data Pages
Free Pages
Journal/WAL Pages
```

### Page header kandidat

```text
offset size field
0      4    magic ASDP
4      2    page_size
6      2    page_type
8      8    page_id
16     8    lsn
24     4    checksum
28     ...  payload
```

### Page type kandidat

- `1`: catalog
- `2`: table heap leaf
- `3`: btree internal
- `4`: btree leaf
- `5`: overflow
- `6`: freelist
- `7`: wal/journal
