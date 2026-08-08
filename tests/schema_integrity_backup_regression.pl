% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* Regression for schema-integrity backup round trips.

   The production backup must retain constraints in addition to rows.  This
   fixture covers composite keys, CHECK, and FOREIGN KEY RESTRICT and then
   verifies that the restored database still rejects invalid writes.
*/

:- use_module('../src/asadb_core.pl').
:- use_module('../src/asadb_backup.pl').
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- initialization(main, main).

main :-
    Source = 'tests/schema_integrity_backup_source.asa',
    Destination = 'tests/schema_integrity_backup_destination.asa',
    cleanup_database(Source),
    cleanup_database(Destination),
    setup_call_cleanup(
        true,
        schema_integrity_backup_round_trip(Source, Destination),
        ( cleanup_database(Source), cleanup_database(Destination) )
    ),
    writeln('PASS: production backup preserves enforced schema-integrity constraints.'),
    halt(0).

schema_integrity_backup_round_trip(Source, Destination) :-
    asadb_boot(Source),
    asadb_exec_sql('CREATE DATABASE integrity_backup; USE integrity_backup; CREATE TABLE parent (tenant_id INT, parent_id INT, CONSTRAINT parent_pk PRIMARY KEY (tenant_id, parent_id)); CREATE TABLE child (tenant_id INT, child_id INT, parent_id INT, code VARCHAR(3), amount DECIMAL(5,2), CONSTRAINT child_pk PRIMARY KEY (tenant_id, child_id), CONSTRAINT child_code UNIQUE (tenant_id, code), CONSTRAINT child_amount CHECK (amount > 0), CONSTRAINT child_parent FOREIGN KEY (tenant_id, parent_id) REFERENCES parent (tenant_id, parent_id) ON DELETE RESTRICT ON UPDATE RESTRICT); INSERT INTO parent VALUES (7, 9); INSERT INTO child VALUES (7, 1, 9, ''ok'', 10.50);', Setup),
    assert_no_error(source_setup, Setup),
    asadb_backup_create(integrity_backup, Backup, _Manifest),
    asadb_backup_prepare_restore(Backup, integrity_backup, Payload, _),
    asadb_shutdown,
    asadb_boot(Destination),
    setup_call_cleanup(
        open(Payload, read, In, [encoding(utf8)]),
        read_string(In, _, SQL),
        close(In)
    ),
    asadb_exec_sql(SQL, Restore),
    assert_no_error(restore, Restore),
    expect_sql('SELECT tenant_id, child_id, parent_id, code, amount FROM child;',
               table([tenant_id,child_id,parent_id,code,amount], [[7,1,9,ok,10.50]])),
    expect_rejected('INSERT INTO child VALUES (7, 2, 9, ''toolong'', 4.00);'),
    expect_rejected('INSERT INTO child VALUES (7, 2, 9, ''new'', -1.00);'),
    expect_rejected('INSERT INTO child VALUES (7, 2, 99, ''new'', 4.00);'),
    expect_rejected('DELETE FROM parent WHERE tenant_id = 7 AND parent_id = 9;'),
    asadb_shutdown,
    asadb_backup_cleanup(Payload),
    asadb_backup_cleanup(Backup).

expect_sql(SQL, Expected) :-
    asadb_exec_sql(SQL, Result),
    ( Result = multi([Expected]) -> true
    ; throw(error(assertion_failed(sql(SQL, Expected, Result)), _))
    ).

expect_rejected(SQL) :-
    asadb_exec_sql(SQL, Result),
    ( Result = multi([error(_, _)]) -> true
    ; throw(error(assertion_failed(rejected_sql(SQL, Result)), _))
    ).

assert_no_error(_, multi(Results)) :-
    \+ member(error(_, _), Results), !.
assert_no_error(Label, Result) :-
    throw(error(assertion_failed(Label-Result), _)).

cleanup_database(File) :-
    cleanup_file(File),
    atom_concat(File, '.journal', Journal), cleanup_file(Journal),
    atom_concat(File, '.current_db', Current), cleanup_file(Current),
    atom_concat(File, '.wal', Wal), cleanup_file(Wal),
    atom_concat(File, '.meta', Meta), cleanup_file(Meta),
    atom_concat(File, '.meta.tmp', MetaTmp), cleanup_file(MetaTmp),
    atom_concat(File, '.meta.bak', MetaBak), cleanup_file(MetaBak),
    atom_concat(File, '.store', Store),
    ( exists_directory(Store) -> delete_directory_and_contents(Store) ; true ),
    atom_concat(File, '.tvcc', Tvcc),
    ( exists_directory(Tvcc) -> delete_directory_and_contents(Tvcc) ; true ).

cleanup_file(File) :-
    ( exists_file(File) -> delete_file(File) ; true ).
