% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  AsaDB MySQL 5.5 Compatibility Manifest
  -------------------------------------
  This file is intentionally data-heavy. It lets the parser/executor report
  feature-specific messages instead of vague syntax errors, and it acts as a
  roadmap for expanding AsaDB toward a fuller MySQL 5.5 dialect.
*/

:- module(asadb_mysql55_compat, [mysql55_statement/3, mysql55_type/2]).

% mysql55_statement(Category, Statement, Status).
% Status: implemented | metadata_stub | parsed_stub | planned

mysql55_statement(ddl, create_database, implemented).
mysql55_statement(ddl, drop_database, implemented).
mysql55_statement(ddl, create_table, implemented).
mysql55_statement(ddl, drop_table, implemented).
mysql55_statement(ddl, truncate_table, implemented).
mysql55_statement(ddl, alter_table, implemented).
mysql55_statement(ddl, create_index, implemented).
mysql55_statement(ddl, drop_index, implemented).
mysql55_statement(ddl, create_view, implemented).
mysql55_statement(ddl, drop_view, implemented).
mysql55_statement(ddl, create_trigger, metadata_stub).
mysql55_statement(ddl, drop_trigger, metadata_stub).
mysql55_statement(ddl, create_procedure, metadata_stub).
mysql55_statement(ddl, create_function, metadata_stub).
mysql55_statement(ddl, drop_procedure, metadata_stub).
mysql55_statement(ddl, drop_function, metadata_stub).

mysql55_statement(dml, insert, implemented).
mysql55_statement(dml, select, implemented).
mysql55_statement(dml, update, implemented).
mysql55_statement(dml, delete, implemented).
mysql55_statement(dml, replace, planned).
mysql55_statement(dml, load_data_infile, planned).
mysql55_statement(dml, insert_select, planned).
mysql55_statement(dml, multi_table_update, planned).
mysql55_statement(dml, multi_table_delete, planned).

mysql55_statement(dql, show_databases, implemented).
mysql55_statement(dql, show_tables, implemented).
mysql55_statement(dql, describe, implemented).
mysql55_statement(dql, explain, implemented).
mysql55_statement(dql, show_columns, implemented).
mysql55_statement(dql, show_create_table, implemented).
mysql55_statement(dql, show_index, implemented).
mysql55_statement(dql, show_status, planned).
mysql55_statement(dql, show_variables, planned).

mysql55_statement(tcl, start_transaction, implemented).
mysql55_statement(tcl, commit, implemented).
mysql55_statement(tcl, rollback, implemented).
mysql55_statement(tcl, savepoint, planned).
mysql55_statement(tcl, release_savepoint, planned).

mysql55_statement(dcl, grant, implemented).
mysql55_statement(dcl, revoke, implemented).
mysql55_statement(dcl, create_user, implemented).
mysql55_statement(dcl, drop_user, implemented).
mysql55_statement(dcl, set_password, planned).

mysql55_statement(admin, lock_tables, implemented).
mysql55_statement(admin, unlock_tables, implemented).
mysql55_statement(admin, analyze_table, planned).
mysql55_statement(admin, check_table, planned).
mysql55_statement(admin, repair_table, planned).
mysql55_statement(admin, optimize_table, planned).

% mysql55_type(TypeName, Status).
mysql55_type(tinyint, implemented).
mysql55_type(smallint, implemented).
mysql55_type(mediumint, planned).
mysql55_type(int, implemented).
mysql55_type(integer, implemented).
mysql55_type(bigint, implemented).
mysql55_type(decimal, implemented).
mysql55_type(float, implemented).
mysql55_type(double, implemented).
mysql55_type(real, implemented).
mysql55_type(bit, planned).
mysql55_type(char, implemented).
mysql55_type(varchar, implemented).
mysql55_type(binary, planned).
mysql55_type(varbinary, planned).
mysql55_type(tinyblob, planned).
mysql55_type(blob, planned).
mysql55_type(mediumblob, planned).
mysql55_type(longblob, planned).
mysql55_type(tinytext, implemented).
mysql55_type(text, implemented).
mysql55_type(mediumtext, implemented).
mysql55_type(longtext, implemented).
mysql55_type(enum, planned).
mysql55_type(set, planned).
mysql55_type(date, implemented).
mysql55_type(time, implemented).
mysql55_type(datetime, implemented).
mysql55_type(timestamp, implemented).
mysql55_type(year, implemented).
