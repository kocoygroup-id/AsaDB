# AsaDB Install Guide

## Windows

1. Install SWI-Prolog.
2. Pastikan `swipl` masuk PATH.
3. Extract `AsaDB.zip`.
4. Buka PowerShell/CMD di folder `AsaDB`.
5. Jalankan demo:

```powershell
scripts\run_asadb.bat data.asa examples\demo.sql
```

6. Jalankan panel:

```powershell
scripts\run_panel.bat data.asa 8088
```

Buka browser:

```text
http://127.0.0.1:8088
```

## Linux/macOS

```bash
chmod +x scripts/*.sh bin/asadb
./scripts/run_asadb.sh data.asa examples/demo.sql
./scripts/run_panel.sh data.asa 8088
```

## VS Code

Buka folder `AsaDB`, lalu jalankan task:

- `AsaDB: Run demo SQL`
- `AsaDB: Start AsAPanel`
- `AsaDB: Smoke test`

## Troubleshooting

### `swipl` tidak dikenali

SWI-Prolog belum terinstall atau PATH belum benar.

### AsAPanel terbuka tapi fallback sandbox

Artinya kamu membuka `web/index.html` langsung atau backend Prolog belum aktif. Jalankan:

```bash
swipl -q -s src/asadb_web.pl -- data.asa 8088
```

### File `.asa` tidak kebaca

Jangan langsung menghapus database. Simpan salinan file `.asa`, direktori
`.asa.store`, dan journal yang menyertainya. AsaDB v1.2.1 dapat memigrasikan
table list-backed v2 yang kompatibel ke page storage v3 saat database dibuka.
Laporkan file yang gagal dimigrasikan beserta log melalui issue baru, tetapi
jangan unggah data sensitif.
