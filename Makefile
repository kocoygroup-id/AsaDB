# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
.PHONY: run panel test clean zip windows-exe

DB ?= data.asa
SQL ?= examples/demo.sql
PORT ?= 8088

run:
	swipl -q -s src/asadb.pl -- $(DB) $(SQL)

repl:
	swipl -q -s src/asadb.pl -- $(DB)

panel:
	swipl -q -s src/asadb_web.pl -- $(DB) $(PORT)

test:
	swipl -q -s tests/run_tests.pl

windows-exe:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_windows_exe.ps1

clean:
	rm -f *.asa tests/*.asa
	rm -rf build

zip:
	cd .. && zip -r AsaDB.zip AsaDB -x 'AsaDB/*.asa' 'AsaDB/tests/*.asa' 'AsaDB/build/*'
