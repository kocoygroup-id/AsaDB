% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* Regression for the production backup path.

   The fixture deliberately exceeds the browser catalog full-sync threshold.
   Rows stay paged in the backend while the backup module scans the heap and
   then restores into a clean engine.  This catches the historic schema-only
   export failure directly.
*/

:- use_module('../src/asadb_core.pl').
:- use_module('../src/asadb_backup.pl').
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- initialization(main, main).

main :-
    Source = 'tests/production_backup_source.asa',
    Destination = 'tests/production_backup_destination.asa',
    cleanup_database(Source),
    cleanup_database(Destination),
    setup_call_cleanup(
        true,
        production_backup_round_trip(Source, Destination),
        ( cleanup_database(Source), cleanup_database(Destination) )
    ),
    writeln('PASS: production backup scans backend rows and restores a verified snapshot.'),
    halt(0).

production_backup_round_trip(Source, Destination) :-
    asadb_boot(Source),
    test_step(source_fixture, setup_source_fixture),
    test_step(source_paged, assert_paged_source),
    test_step(active_transaction_rejected, assert_active_transaction_is_rejected),
    test_step(create_backup, asadb_backup_create(production_backup, Backup, Manifest)),
    test_step(backup_manifest, assert_backup_manifest(Manifest)),
    test_step(metadata_tamper, assert_metadata_tamper_is_rejected(Backup)),
    test_step(backup_prepare_restore, asadb_backup_prepare_restore(Backup, Database, Payload, RestoredManifest)),
    test_step(restored_manifest, assert_restored_manifest(Database, RestoredManifest)),
    asadb_shutdown,
    asadb_boot(Destination),
    setup_call_cleanup(
        open(Payload, read, In, [encoding(utf8)]),
        read_string(In, _, SQL),
        close(In)
    ),
    asadb_exec_sql(SQL, RestoreResult),
    test_step(restore_sql, assert_no_error(restore_sql, RestoreResult)),
    CatalogObjects = RestoredManifest.catalog_objects,
    CatalogObjects = catalog_objects(Views, Functions, Procedures, Triggers),
    test_step(restore_catalog, asadb_backup_restore_catalog_objects(Database, Views, Functions, Procedures, Triggers)),
    test_step(restored_rows, assert_restored_rows),
    test_step(restored_schema, assert_restored_schema_and_view),
    asadb_shutdown,
    asadb_backup_cleanup(Payload),
    asadb_backup_cleanup(Backup).

test_step(Label, Goal) :-
    ( call(Goal) -> true
    ; fail_with('test step failed', Label)
    ).

setup_source_fixture :-
    asadb_exec_sql('CREATE DATABASE production_backup; USE production_backup; CREATE TABLE backup_rows (id INT PRIMARY KEY, note TEXT COMMENT ''primary notes'', optional TEXT); CREATE TABLE backup_floats (id INT PRIMARY KEY, value DOUBLE);', Create),
    assert_no_error(create, Create),
    asadb_exec_sql('BEGIN;', Begin),
    assert_no_error(begin, Begin),
    insert_fixture_batches(1, 6137),
    asadb_exec_sql("INSERT INTO backup_rows (id, note, optional) VALUES (7000, 'O\\'Brien\\n日本\\t\\\\path', NULL);", Special),
    assert_no_error(special_row, Special),
    asadb_exec_sql('INSERT INTO backup_floats (id, value) VALUES (1, 1.0e-20), (2, -1.7976931348623157e+308), (3, -0.0);', FloatRows),
    assert_no_error(float_rows, FloatRows),
    asadb_exec_sql('COMMIT; CREATE INDEX backup_note_idx ON backup_rows (note); CREATE VIEW backup_view AS SELECT id, note FROM backup_rows;', Commit),
    assert_no_error(commit, Commit).

insert_fixture_batches(First, Last) :-
    First > Last, !.
insert_fixture_batches(First, Last) :-
    BatchLast is min(Last, First + 255),
    fixture_insert_sql(First, BatchLast, SQL),
    asadb_exec_sql(SQL, Result),
    assert_no_error(insert_batch, Result),
    Next is BatchLast + 1,
    insert_fixture_batches(Next, Last).

fixture_insert_sql(First, Last, SQL) :-
    findall(Row,
            ( between(First, Last, Id),
              format(atom(Note), 'row-~d', [Id]),
              format(atom(Row), '  (~d, ''~w'', NULL)', [Id, Note])
            ),
            Rows),
    atomic_list_concat(Rows, ',\n', Values),
    format(atom(SQL), 'INSERT INTO backup_rows (id, note, optional) VALUES\n~w;', [Values]).

assert_paged_source :-
    asadb_get_state(state(_, DBs)),
    member(db(production_backup, Tables, _, _, _, _), DBs),
    member(table(backup_rows, _, paged_rows(_, Count, _), _), Tables),
    ( Count =:= 6138 -> true
    ; fail_with('source rows were not retained in paged backend storage', Count)
    ).

assert_active_transaction_is_rejected :-
    asadb_exec_sql('BEGIN;', Begin),
    assert_no_error(backup_rejection_begin, Begin),
    catch(asadb_backup_create(production_backup, _File, _Manifest), Error, true),
    ( nonvar(Error), Error = error(permission_error(create, production_backup, active_transaction), _) -> true
    ; fail_with('backup did not reject an active transaction', Error)
    ),
    asadb_exec_sql('ROLLBACK;', Rollback),
    assert_no_error(backup_rejection_rollback, Rollback).

assert_backup_manifest(Manifest) :-
    ( Manifest.database == production_backup,
      Manifest.table_count =:= 2,
      Manifest.row_count =:= 6141,
      atom_length(Manifest.payload_sha256, 64),
      atom_length(Manifest.integrity_sha256, 64),
      Manifest.payload_bytes > 0 -> true
    ; fail_with('invalid backup manifest', Manifest)
    ).

assert_restored_manifest(Database, Manifest) :-
    ( Database == production_backup,
      Manifest.row_count =:= 6141,
      Manifest.catalog_objects = catalog_objects([view(backup_view, _, _)], [], [], []) -> true
    ; fail_with('backup manifest lost catalog objects', Manifest)
    ).

assert_restored_rows :-
    expect_sql('USE production_backup; SELECT COUNT(*) AS total FROM backup_rows;', table([total], [[6138]])),
    expect_sql('SELECT id, note, optional FROM backup_rows WHERE id = 1;', table([id,note,optional], [[1,'row-1',null]])),
    expect_sql('SELECT id, note, optional FROM backup_rows WHERE id = 3072;', table([id,note,optional], [[3072,'row-3072',null]])),
    expect_sql('SELECT id, note, optional FROM backup_rows WHERE id = 6137;', table([id,note,optional], [[6137,'row-6137',null]])),
    expect_sql('SELECT id, note, optional FROM backup_rows WHERE id = 7000;', table([id,note,optional], [[7000,'O\'Brien\n日本\t\\path',null]])),
    expect_sql('SELECT id, value FROM backup_floats WHERE id = 1;', table([id,value], [[1,1.0e-20]])),
    expect_sql('SELECT id, value FROM backup_floats WHERE id = 2;', table([id,value], [[2,-1.7976931348623157e+308]])),
    expect_sql('SELECT id, value FROM backup_floats WHERE id = 3;', table([id,value], [[3,-0.0]])).

assert_restored_schema_and_view :-
    asadb_get_state(state(_, DBs)),
    assert_member(restored_database, db(production_backup, Tables, Views, _, _, _), DBs),
    assert_member(restored_table, table(backup_rows, Columns, _, Indexes), Tables),
    assert_member(restored_primary_column, col(id, 'int ', Options), Columns),
    assert_member(restored_primary_option, primary_key, Options),
    assert_member(restored_note_column, col(note, 'text ', NoteOptions), Columns),
    assert_member(restored_comment_keyword, raw_option(kw(comment)), NoteOptions),
    assert_member(restored_comment_text, raw_option(str('primary notes')), NoteOptions),
    assert_member(restored_index, index(backup_note_idx, [note], non_unique), Indexes),
    assert_member(restored_view, view(backup_view, _, _), Views),
    BadManifest = backup_manifest{table_count:2,row_count:1},
    catch(asadb_backup_validate_restored_snapshot(production_backup, BadManifest), CountError, true),
    ( CountError = error(integrity_error(backup_total_row_count(1, 6141)), _) -> true
    ; fail_with('restored snapshot count check did not reject mismatch', CountError)
    ).

assert_member(Label, Item, List) :-
    ( member(Item, List) -> true
    ; fail_with('expected restored schema item is missing', missing(Label, Item, List))
    ).

assert_metadata_tamper_is_rejected(Backup) :-
    read_file_to_string(Backup, Contents, [encoding(utf8)]),
    replace_once(Contents, "-- database: production_backup", "-- database: production_tamper", Tampered),
    tmp_file_stream(utf8, TamperedFile, Out),
    setup_call_cleanup(
        true,
        ( format(Out, '~s', [Tampered]),
          close(Out),
          catch(asadb_backup_prepare_restore(TamperedFile, _, _, _), Error, true),
          ( Error = error(integrity_error(backup_integrity_sha256(_, _)), _) -> true
          ; fail_with('metadata tampering was not rejected by integrity hash', Error)
          )
        ),
        ( catch(close(Out), _, true), asadb_backup_cleanup(TamperedFile) )
    ).

replace_once(Source, Needle, Replacement, Output) :-
    sub_string(Source, Before, Length, After, Needle), !,
    sub_string(Source, 0, Before, _, Prefix),
    Start is Before + Length,
    sub_string(Source, Start, After, 0, Suffix),
    string_concat(Prefix, Replacement, Head),
    string_concat(Head, Suffix, Output).

expect_sql(SQL, Expected) :-
    asadb_exec_sql(SQL, Result),
    ( Result = multi(Results), last(Results, Expected) -> true
    ; fail_with('unexpected SQL result', result(SQL, Expected, Result))
    ).

assert_no_error(_, multi(Results)) :- \+ member(error(_, _), Results), !.
assert_no_error(Stage, Result) :- fail_with('SQL failed', stage(Stage, Result)).

cleanup_database(DbFile) :-
    maplist(delete_if_exists, [DbFile]),
    atom_concat(DbFile, '.journal', Journal),
    atom_concat(DbFile, '.current_db', CurrentDb),
    atom_concat(DbFile, '.wal', Wal),
    atom_concat(DbFile, '.meta', Metadata),
    atom_concat(Metadata, '.tmp', MetadataTemp),
    atom_concat(Metadata, '.bak', MetadataBackup),
    atom_concat(DbFile, '.store', StoreDir),
    maplist(delete_if_exists, [Journal, CurrentDb, Wal, Metadata, MetadataTemp, MetadataBackup]),
    ( exists_directory(StoreDir) -> delete_directory_and_contents(StoreDir) ; true ).

delete_if_exists(File) :- ( exists_file(File) -> delete_file(File) ; true ).

fail_with(Message, Detail) :-
    format(user_error, 'PRODUCTION BACKUP REGRESSION FAILED: ~w~n~q~n', [Message, Detail]),
    catch(asadb_shutdown, _, true),
    halt(1).
