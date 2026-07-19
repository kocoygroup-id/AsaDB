% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- ensure_loaded('../src/asadb_web.pl').
:- use_module(library(filesex)).
:- initialization(stress_main, main).

stress_main :-
    stress_row_target(TargetRows),
    SqlFile = 'tests/stress_100k_generated.sql',
    DbFile = 'tests/stress_100k.asa',
    cleanup_stress(SqlFile, DbFile),
    setup_call_cleanup(
        open(SqlFile, write, Out, [encoding(utf8)]),
        write_stress_sql(Out, TargetRows),
        close(Out)
    ),
    size_file(SqlFile, SqlBytes),
    asadb_boot(DbFile),
    stress_stage(import_start),
    statistics(walltime, [ImportStart|_]),
    import_sql_file_backend(SqlFile, true, 'stress-100k', ImportResult),
    statistics(walltime, [ImportEnd|_]),
    ImportMs is ImportEnd - ImportStart,
    assert_no_error(import, ImportResult),
    stress_stage(import_complete),
    expect_stress_count(TargetRows),
    LookupId is TargetRows - 1,
    format(atom(LookupSql), 'SELECT id, name FROM stress_rows WHERE id = ~w;', [LookupId]),
    format(atom(LookupName), 'User ~w', [LookupId]),
    statistics(walltime, [LookupStart|_]),
    expect_stress_sql(LookupSql,
                      table([id,name], [[LookupId,LookupName]])),
    statistics(walltime, [LookupEnd|_]),
    LookupMs is LookupEnd - LookupStart,
    ThirdId is TargetRows - 2,
    format(atom(OrderSql), 'SELECT id FROM stress_rows ORDER BY id DESC LIMIT 3;', []),
    stress_stage(order_by_start),
    statistics(walltime, [OrderStart|_]),
    expect_stress_sql(OrderSql,
                      table([id], [[TargetRows],[LookupId],[ThirdId]])),
    statistics(walltime, [OrderEnd|_]),
    OrderMs is OrderEnd - OrderStart,
    stress_stage(order_by_complete),
    UpdateId is max(4, TargetRows // 2),
    format(atom(UpdateSql), 'UPDATE stress_rows SET score = 777 WHERE id = ~w;', [UpdateId]),
    statistics(walltime, [UpdateStart|_]),
    expect_stress_sql(UpdateSql,
                      ok(updated(stress_rows, 1))),
    statistics(walltime, [UpdateEnd|_]),
    UpdateMs is UpdateEnd - UpdateStart,
    format(atom(UpdateCheckSql), 'SELECT score FROM stress_rows WHERE id = ~w;', [UpdateId]),
    expect_stress_sql(UpdateCheckSql,
                      table([score], [[777]])),
    statistics(walltime, [DeleteStart|_]),
    expect_stress_sql('DELETE FROM stress_rows WHERE id = 3;',
                      ok(deleted(stress_rows, 1))),
    statistics(walltime, [DeleteEnd|_]),
    DeleteMs is DeleteEnd - DeleteStart,
    RemainingRows is TargetRows - 1,
    expect_stress_count(RemainingRows),
    stress_stage(limited_select_start),
    statistics(walltime, [LimitedStart|_]),
    asadb_exec_sql_limited('SELECT * FROM stress_rows ORDER BY id;', 501, Limited),
    Limited = multi([table(_, LimitedRows)]),
    length(LimitedRows, 501),
    statistics(walltime, [LimitedEnd|_]),
    LimitedMs is LimitedEnd - LimitedStart,
    stress_stage(limited_select_complete),
    asadb_storage_stats(RuntimeStats),
    asadb_shutdown,
    stress_stage(reload_start),
    asadb_boot(DbFile),
    expect_stress_count(RemainingRows),
    asadb_storage_stats(StorageStats),
    asadb_shutdown,
    size_file(DbFile, DbBytes),
    atom_concat(DbFile, '.store', StoreDir),
    directory_size(StoreDir, StoreBytes),
    format('STRESS ~w PASS~n', [TargetRows]),
    format('SQL bytes: ~w~nCatalog bytes: ~w~nPage store bytes: ~w~nImport ms: ~w~nIndexed lookup ms: ~w~nOrder/limit ms: ~w~nUpdate ms: ~w~nDelete ms: ~w~nLimited result ms: ~w~nRuntime stats: ~q~nReload stats: ~q~n',
           [SqlBytes, DbBytes, StoreBytes, ImportMs, LookupMs, OrderMs,
            UpdateMs, DeleteMs, LimitedMs, RuntimeStats, StorageStats]),
    cleanup_stress(SqlFile, DbFile),
    halt(0).

stress_row_target(TargetRows) :-
    current_prolog_flag(argv, [Raw|_]),
    catch(atom_number(Raw, Parsed), _, fail),
    integer(Parsed),
    Parsed >= 1000, !,
    TargetRows is (Parsed // 100) * 100.
stress_row_target(100000).

stress_stage(Stage) :-
    format('STAGE ~w~n', [Stage]),
    flush_output.

write_stress_sql(Out, TargetRows) :-
    format(Out, 'CREATE DATABASE stress_100k;~nUSE stress_100k;~n', []),
    format(Out, 'CREATE TABLE stress_rows (id INT PRIMARY KEY, name VARCHAR(64), score INT);~n', []),
    LastBatch is TargetRows // 100 - 1,
    forall(between(0, LastBatch, Batch), write_insert_batch(Out, Batch)).

write_insert_batch(Out, Batch) :-
    First is Batch * 100 + 1,
    Last is First + 99,
    format(Out, 'INSERT INTO stress_rows (id, name, score) VALUES~n', []),
    forall(between(First, Last, Id), write_insert_row(Out, Id, Last)).

write_insert_row(Out, Id, Last) :-
    Score is Id mod 1000,
    ( Id =:= Last -> End = ';' ; End = ',' ),
    format(Out, '  (~w, ''User ~w'', ~w)~w~n', [Id, Id, Score, End]).

expect_stress_sql(SQL, Expected) :-
    asadb_exec_sql(SQL, Result),
    ( Result = multi([Expected]) ->
        true
    ;   format(user_error, 'STRESS ASSERTION FAILED~nSQL: ~w~nExpected: ~w~nGot: ~w~n',
               [SQL, Expected, Result]),
        halt(1)
    ).

expect_stress_count(ExpectedCount) :-
    expect_stress_sql('SELECT COUNT(*) AS total FROM stress_rows;',
                      table([total], [[ExpectedCount]])).

assert_no_error(_, error(Code, Message)) :- !,
    format(user_error, 'STRESS IMPORT FAILED: ~w ~w~n', [Code, Message]),
    halt(1).
assert_no_error(_, table(_, [[Status|_]])) :-
    member(Status, [ok, committed]), !.
assert_no_error(Stage, Result) :-
    format(user_error, 'STRESS ~w FAILED: ~w~n', [Stage, Result]),
    halt(1).

cleanup_stress(SqlFile, DbFile) :-
    delete_if_exists(SqlFile),
    delete_if_exists(DbFile),
    atom_concat(DbFile, '.journal', Journal),
    atom_concat(DbFile, '.current_db', CurrentDb),
    atom_concat(DbFile, '.wal', Wal),
    atom_concat(DbFile, '.meta', Metadata),
    atom_concat(Metadata, '.tmp', MetadataTemp),
    atom_concat(Metadata, '.bak', MetadataBackup),
    atom_concat(DbFile, '.store', StoreDir),
    delete_if_exists(Journal),
    delete_if_exists(CurrentDb),
    delete_if_exists(Wal),
    delete_if_exists(Metadata),
    delete_if_exists(MetadataTemp),
    delete_if_exists(MetadataBackup),
    ( exists_directory(StoreDir) -> delete_directory_and_contents(StoreDir) ; true ).

delete_if_exists(File) :-
    ( exists_file(File) -> delete_file(File) ; true ).

directory_size(Dir, Size) :-
    ( exists_directory(Dir) -> directory_size_(Dir, Size) ; Size = 0 ).

directory_size_(Dir, Size) :-
    directory_files(Dir, Names),
    directory_entries_size(Names, Dir, 0, Size).

directory_entries_size([], _, Size, Size).
directory_entries_size([Name|Names], Dir, Acc, Size) :-
    ( memberchk(Name, ['.','..']) -> Next = Acc
    ; directory_file_path(Dir, Name, Path),
      ( exists_directory(Path) -> directory_size_(Path, EntrySize)
      ; size_file(Path, EntrySize)
      ),
      Next is Acc + EntrySize
    ),
    directory_entries_size(Names, Dir, Next, Size).
