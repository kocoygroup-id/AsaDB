# Copyright (C) 2026 Kocoy Group and AsaDB contributors
# SPDX-License-Identifier: GPL-3.0-only
.PHONY: run panel test test-ui test-join test-launchers test-package test-all check-linux clean release release-linux release-source windows-exe

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

test-ui:
	node tests/ui_regression.js

test-join:
	swipl -q -s tests/join_15000_regression.pl

test-launchers:
	./tests/launcher_regression.sh

test-package:
	./tests/release_package_regression.sh

test-all: test test-ui test-join test-launchers test-package

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
