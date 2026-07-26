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
        run_tvcc_regression,
        ( catch(asadb_shutdown, _, true), cleanup )
    ),
    halt(0).

run_tvcc_regression :-
    asadb_boot('tests/tvcc_testdata.asa'),
    % Pin generation one before the writer creates the application database.
    asadb_tvcc_acquire(InitialGeneration, _, _, _),
    expect_sql('CREATE DATABASE tvcc; USE tvcc; CREATE TABLE events (id INT, label TEXT); INSERT INTO events VALUES (1, ''before''), (2, ''stable'');'),
    asadb_tvcc_acquire(ReaderGeneration, _ReaderState, ReaderStore, _),
    asadb_record_store_id(tvcc, events, StoreId),
    snapshot_rows(ReaderStore, StoreId, BeforeRows),
    assert_equal([[1,before],[2,stable]], BeforeRows, initial_snapshot_rows),
    thread_create(tvcc_writer, Writer, []),
    sleep(0.15),
    ( thread_property(Writer, status(running)) -> true
    ; thread_property(Writer, status(Status)),
      throw(error(assertion_failed(tvcc_writer_did_not_wait_for_pinned_oldest_snapshot(Status)), _))
    ),
    % The held generation is still readable while the fourth publication waits.
    snapshot_rows(ReaderStore, StoreId, StableRows),
    assert_equal(BeforeRows, StableRows, immutable_reader_rows),
    asadb_tvcc_release(ReaderGeneration),
    asadb_tvcc_release(InitialGeneration),
    thread_join(Writer, true),
    expect_snapshot_sql('SELECT COUNT(*) FROM events;', table([count], [[4]])),
    asadb_storage_stats(Storage),
    Tvcc = Storage.tvcc,
    ( Tvcc.retained_generations =< 3,
      Tvcc.active_readers =:= 0 -> true
    ; throw(error(assertion_failed(tvcc_retention_stats(Tvcc)), _))
    ).

tvcc_writer :-
    expect_sql('INSERT INTO events VALUES (3, ''writer-one'');'),
    expect_sql('INSERT INTO events VALUES (4, ''writer-two'');').

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

assert_equal(Expected, Actual, _) :- Expected == Actual, !.
assert_equal(Expected, Actual, Label) :-
    throw(error(assertion_failed(Label, expected(Expected), actual(Actual)), _)).

cleanup :-
    delete_if_exists('tests/tvcc_testdata.asa'),
    delete_if_exists('tests/tvcc_testdata.asa.current_db'),
    delete_if_exists('tests/tvcc_testdata.asa.journal'),
    delete_if_exists('tests/tvcc_testdata.asa.wal'),
    delete_if_exists('tests/tvcc_testdata.asa.meta'),
    remove_directory_if_exists('tests/tvcc_testdata.asa.store'),
    remove_directory_if_exists('tests/tvcc_testdata.asa.tvcc').

remove_directory_if_exists(Path) :-
    ( exists_directory(Path) -> delete_directory_and_contents(Path) ; true ).

delete_if_exists(Path) :-
    ( exists_file(Path) -> delete_file(Path) ; true ).
