% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* Local TVCC regression: immutable reader pages, bounded three-generation
   retention, and writer backpressure instead of unsafe snapshot eviction. */

:- use_module('../src/asadb_core.pl').
:- use_module('../src/asadb_tvcc.pl').
:- use_module('../src/asadb_record_manager.pl').
:- use_module(library(filesex)).
:- initialization(main, main).

main :-
    cleanup,
    setup_call_cleanup(
        true,
        run_tvcc_regressions,
        ( catch(asadb_shutdown, _, true), cleanup )
    ),
    halt(0).

run_tvcc_regressions :-
    run_interrupted_boot_recovery_regression,
    asadb_shutdown,
    cleanup,
    run_database_context_regression,
    asadb_shutdown,
    cleanup,
    run_tvcc_regression.

% TVCC generations are transient process-local reader images.  Simulate the
% exact residue left by a forced stop after a generation was published but
% before staging cleanup.  A later process must recover from the durable
% catalog/store, not fail while trying to rename generation-000001.tmp over
% generation-000001.
run_interrupted_boot_recovery_regression :-
    asadb_boot('tests/tvcc testdata.asa'),
    expect_sql('CREATE DATABASE restart_tvcc; USE restart_tvcc; CREATE TABLE durable_rows (id INT PRIMARY KEY, label TEXT); INSERT INTO durable_rows VALUES (1, ''survives'');'),
    asadb_shutdown,
    make_tvcc_boot_residue('tests/tvcc testdata.asa'),
    asadb_boot('tests/tvcc testdata.asa'),
    expect_sql('USE restart_tvcc;'),
    expect_sql_result('SELECT label FROM durable_rows;', table([label], [[survives]])),
    tvcc_root('tests/tvcc testdata.asa', Root),
    directory_file_path(Root, 'generation-000001.tmp', Temporary),
    ( exists_directory(Temporary) ->
        throw(error(assertion_failed(tvcc_boot_left_staging_directory), _))
    ; true
    ).

make_tvcc_boot_residue(File) :-
    tvcc_root(File, Root),
    directory_file_path(Root, 'generation-000001', Published),
    directory_file_path(Root, 'generation-000001.tmp', Temporary),
    directory_file_path(Published, 'store', PublishedStore),
    directory_file_path(Temporary, 'store', TemporaryStore),
    make_directory_path(PublishedStore),
    make_directory_path(TemporaryStore),
    directory_file_path(Published, 'catalog.asa', PublishedCatalog),
    directory_file_path(Temporary, 'catalog.asa', TemporaryCatalog),
    write_fixture_file(PublishedCatalog, published),
    write_fixture_file(TemporaryCatalog, staging).

tvcc_root(File, Root) :- atom_concat(File, '.tvcc', Root).

write_fixture_file(File, Term) :-
    setup_call_cleanup(open(File, write, Stream, [encoding(utf8)]),
                       ( write_canonical(Stream, Term), write(Stream, '.\n') ),
                       close(Stream)).

run_database_context_regression :-
    asadb_boot('tests/tvcc testdata.asa'),
    expect_sql('CREATE DATABASE tvcc_a; USE tvcc_a;'),
    asadb_tvcc_acquire(OldGeneration, _, _, OldDatabase),
    assert_equal(tvcc_a, OldDatabase, old_snapshot_database),
    expect_sql('CREATE DATABASE tvcc_b; USE tvcc_b;'),
    asadb_tvcc_acquire(NewGeneration, _, _, NewDatabase),
    assert_equal(tvcc_b, NewDatabase, new_snapshot_database),
    assert_equal(tvcc_a, OldDatabase, old_snapshot_database_is_immutable),
    asadb_tvcc_release(NewGeneration),
    asadb_tvcc_release(OldGeneration).

run_tvcc_regression :-
    asadb_boot('tests/tvcc testdata.asa'),
    % Pin generation one before the writer creates the application database.
    asadb_tvcc_acquire(InitialGeneration, _, _, _),
    expect_sql('CREATE DATABASE tvcc; USE tvcc; CREATE TABLE events (id INT PRIMARY KEY, label TEXT); CREATE TABLE metrics (id INT PRIMARY KEY, score INT); INSERT INTO events VALUES (1, ''before''), (2, ''stable''); INSERT INTO metrics VALUES (1, 10), (2, 20);'),
    asadb_tvcc_acquire(ReaderGeneration, _ReaderState, ReaderStore, _),
    asadb_tvcc_acquire(ReaderGeneration, _SecondReaderState, SecondReaderStore, _),
    assert_equal(ReaderStore, SecondReaderStore, readers_share_generation_store),
    asadb_record_store_id(tvcc, events, StoreId),
    snapshot_rows(ReaderStore, StoreId, BeforeRows),
    assert_equal([[1,before],[2,stable]], BeforeRows, initial_snapshot_rows),
    run_snapshot_query_shape_regression,
    thread_create(tvcc_writer, Writer, []),
    sleep(0.15),
    ( thread_property(Writer, status(running)) -> true
    ; thread_property(Writer, status(Status)),
      throw(error(assertion_failed(tvcc_writer_did_not_wait_for_pinned_oldest_snapshot(Status)), _))
    ),
    asadb_tvcc_stats(WaitingStats),
    assert_equal(3, WaitingStats.retained_generations,
                 temporary_generation_is_not_committed),
    % The held generation is still readable while the fourth publication waits.
    snapshot_rows(ReaderStore, StoreId, StableRows),
    assert_equal(BeforeRows, StableRows, immutable_reader_rows),
    asadb_tvcc_release(ReaderGeneration),
    asadb_tvcc_stats(HeldReaderStats),
    assert_equal(2, HeldReaderStats.active_readers, second_reader_keeps_generation_pinned),
    asadb_tvcc_release(ReaderGeneration),
    asadb_tvcc_release(InitialGeneration),
    thread_join(Writer, true),
    expect_snapshot_sql('SELECT COUNT(*) FROM events;', table([count], [[4]])),
    run_snapshot_api_safety_regression,
    run_transaction_visibility_regression,
    asadb_storage_stats(Storage),
    Tvcc = Storage.tvcc,
    ( Tvcc.retained_generations =< 3,
      Tvcc.active_readers =:= 0 -> true
    ; throw(error(assertion_failed(tvcc_retention_stats(Tvcc)), _))
    ).

tvcc_writer :-
    expect_sql('INSERT INTO events VALUES (3, ''writer-one'');'),
    expect_sql('INSERT INTO events VALUES (4, ''writer-two'');').

run_snapshot_api_safety_regression :-
    expect_snapshot_rejected('INSERT INTO events VALUES (9, ''forbidden'');'),
    expect_snapshot_rejected('UPDATE events SET label = ''forbidden'' WHERE id = 1;'),
    expect_snapshot_rejected('DELETE FROM events WHERE id = 1;'),
    expect_snapshot_rejected('BEGIN;'),
    expect_snapshot_rejected('SELECT * FROM events; DELETE FROM events WHERE id = 1;'),
    asadb_exec_sql_snapshot_limited('SELECT unknown_tvcc_function(id) FROM events;', 50, _),
    asadb_tvcc_stats(Stats),
    assert_equal(0, Stats.active_readers, failed_snapshot_releases_reader).

run_snapshot_query_shape_regression :-
    expect_snapshot_sql(
        'SELECT e.id, m.score FROM events e INNER JOIN metrics m ON e.id = m.id ORDER BY e.id;',
        table(['e.id','m.score'], [[1,10],[2,20]])),
    expect_snapshot_sql(
        'SELECT COUNT(*) AS n, SUM(score) AS total FROM metrics WHERE id IN (SELECT id FROM events);',
        table([n,total], [[2,30]])),
    expect_snapshot_sql('SELECT score FROM metrics WHERE id = 2;',
                        table([score], [[20]])),
    expect_snapshot_sql('SELECT id FROM metrics ORDER BY id DESC LIMIT 1;',
                        table([id], [[2]])).

run_transaction_visibility_regression :-
    expect_sql('BEGIN; INSERT INTO events VALUES (5, ''transaction-visible'');'),
    ( asadb_transaction_active -> true
    ; throw(error(assertion_failed(transaction_should_be_active), _))
    ),
    expect_sql_result('SELECT COUNT(*) FROM events;', table([count], [[5]])),
    expect_snapshot_rejected('SELECT COUNT(*) FROM events;'),
    expect_sql('ROLLBACK;'),
    expect_sql_result('SELECT COUNT(*) FROM events;', table([count], [[4]])).

snapshot_rows(StoreRoot, StoreId, Values) :-
    asadb_record_with_root(StoreRoot,
        findall([Id,Label],
            ( asadb_record_scan(StoreId, _, row(Pairs)),
              member(id=Id, Pairs), member(label=Label, Pairs)
            ),
            Values)).

expect_sql(SQL) :-
    asadb_exec_sql(SQL, multi(Results)),
    ( member(error(_, _), Results) ->
        throw(error(assertion_failed(sql(SQL, Results)), _))
    ; true
    ).

expect_snapshot_sql(SQL, Expected) :-
    asadb_exec_sql_snapshot_limited(SQL, 50, multi([Actual])),
    assert_equal(Expected, Actual, snapshot_sql).

expect_snapshot_rejected(SQL) :-
    asadb_exec_sql_snapshot_limited(SQL, 50, Result),
    ( Result = error(runtime_error, _) -> true
    ; throw(error(assertion_failed(snapshot_should_reject(SQL, Result)), _))
    ).

expect_sql_result(SQL, Expected) :-
    asadb_exec_sql(SQL, multi([Actual])),
    assert_equal(Expected, Actual, sql_result).

assert_equal(Expected, Actual, _) :- Expected == Actual, !.
assert_equal(Expected, Actual, Label) :-
    throw(error(assertion_failed(Label, expected(Expected), actual(Actual)), _)).

cleanup :-
    delete_if_exists('tests/tvcc testdata.asa'),
    delete_if_exists('tests/tvcc testdata.asa.current_db'),
    delete_if_exists('tests/tvcc testdata.asa.journal'),
    delete_if_exists('tests/tvcc testdata.asa.wal'),
    delete_if_exists('tests/tvcc testdata.asa.meta'),
    remove_directory_if_exists('tests/tvcc testdata.asa.store'),
    remove_directory_if_exists('tests/tvcc testdata.asa.tvcc').

remove_directory_if_exists(Path) :-
    ( exists_directory(Path) -> delete_directory_and_contents(Path) ; true ).

delete_if_exists(Path) :-
    ( exists_file(Path) -> delete_file(Path) ; true ).
