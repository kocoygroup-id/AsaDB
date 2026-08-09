# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
.PHONY: run panel test test-ui test-join test-backup test-interchange test-interchange-stress test-modules test-launchers test-guardian test-windows-source test-package test-pack test-server-e2e test-all check-linux clean release release-linux release-source windows-exe

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
	swipl -q -s tests/reservoir_tests.pl
	./tests/reservoir_large_sql_regression.sh
	swipl -q -s tests/tvcc_regression.pl

test-ui:
	node tests/ui_regression.js

test-join:
	swipl -q -s tests/join_15000_regression.pl

test-backup:
	swipl -q -s tests/production_backup_regression.pl
	swipl -q -s tests/schema_integrity_backup_regression.pl
	./tests/production_backup_http_regression.sh

test-interchange:
	swipl -q -s tests/interchange_regression.pl
	./tests/interchange_http_regression.sh

test-interchange-stress:
	swipl -q -s tests/interchange_stress.pl

test-modules:
	./tests/prolog_module_audit.sh

test-launchers:
	./tests/launcher_regression.sh

test-guardian:
	./tests/guardian_regression.sh

test-windows-source:
	./tests/windows_source_package_regression.sh

test-package:
	./tests/release_package_regression.sh

test-pack:
	./tests/pack_regression.sh

test-server-e2e:
	./tests/server_e2e_regression.sh

test-all: test test-ui test-join test-backup test-interchange test-modules test-launchers test-guardian test-windows-source test-package test-pack test-server-e2e

check-linux:
	./scripts/check_linux_runtime.sh

windows-exe:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build_windows_exe.ps1

clean:
	rm -f *.asa tests/*.asa
	rm -rf build

release: release-linux

release-linux:
	./scripts/build_linux_release.sh

release-source:
	./scripts/build_source_release.sh
