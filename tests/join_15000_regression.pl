% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- use_module('../src/asadb_core.pl').
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- if(exists_source(library(time))).
:- use_module(library(time)).
join_with_timeout(Goal) :- call_with_time_limit(30, Goal).
:- else.
join_with_timeout(Goal) :- call(Goal).
:- endif.
:- initialization(main, main).

main :-
    SqlFile = 'tests/join_15000_generated.sql',
    DbFile = 'tests/join_15000.asa',
    cleanup(SqlFile, DbFile),
    setup_call_cleanup(
        open(SqlFile, write, Out, [encoding(utf8)]),
        write_join_fixture(Out, 15000),
        close(Out)
    ),
    asadb_boot(DbFile),
    read_file_to_codes(SqlFile, FixtureSql, []),
    asadb_exec_sql(FixtureSql, ImportResult),
    assert_no_error(import, ImportResult),
    Query = 'SELECT m.No, m.Depth, m.Water_Cut, z.Zone_Name FROM field m INNER JOIN zone z ON m.No = z.No WHERE m.No <= 3 ORDER BY m.No LIMIT 100;',
    statistics(walltime, [Start|_]),
    catch(join_with_timeout(expect_sql(Query,
        table(['m.No','m.Depth','m.Water_Cut','z.Zone_Name'],
              [[1,1001,1,'Zone A'],[2,1002,2,'Zone B'],[3,1003,3,'Zone C']]))),
          time_limit_exceeded,
          join_timeout),
    statistics(walltime, [End|_]),
    JoinMs is End - Start,
    expect_sql('CREATE VIEW field_analysis AS SELECT No, Depth, Water_Cut FROM field;',
               ok(created_view(field_analysis))),
    expect_multi_sql(
        'SELECT m.No, m.Depth, z.Zone_Name FROM field m INNER JOIN zone z ON m.No = z.No WHERE m.No <= 3 ORDER BY m.No LIMIT 3; SELECT No, Depth FROM field_analysis ORDER BY No LIMIT 3;',
        [table(['m.No','m.Depth','z.Zone_Name'],
               [[1,1001,'Zone A'],[2,1002,'Zone B'],[3,1003,'Zone C']]),
         table(['No','Depth'], [[1,1001],[2,1002],[3,1003]])]),
    expect_sql('SELECT COUNT(*) AS total FROM field m INNER JOIN zone z ON m.No = z.No;',
               table([total], [[15000]])),
    asadb_storage_stats(Stats),
    ( Stats.planner.indexed_joins >= 2,
      Stats.planner.nested_loop_joins =:= 0 -> true
    ; format(user_error, 'JOIN PLAN ASSERTION FAILED: ~q~n', [Stats.planner]),
      halt(1)
    ),
    format('JOIN 15000 PASS alias=m/z rows=15000 join_ms=~w planner=~q~n',
           [JoinMs, Stats.planner]),
    asadb_shutdown,
    cleanup(SqlFile, DbFile),
    halt(0).

write_join_fixture(Out, Rows) :-
    format(Out, 'CREATE DATABASE join_regression;~nUSE join_regression;~n', []),
    format(Out, 'CREATE TABLE field (No INT PRIMARY KEY, Depth INT, Water_Cut INT);~n', []),
    format(Out, 'CREATE TABLE zone (No INT PRIMARY KEY, Zone_Name VARCHAR(32));~n', []),
    LastBatch is (Rows - 1) // 100,
    forall(between(0, LastBatch, Batch), write_field_batch(Out, Batch, Rows)),
    forall(between(0, LastBatch, Batch), write_zone_batch(Out, Batch, Rows)).

write_field_batch(Out, Batch, Rows) :-
    First is Batch * 100 + 1,
    Last is min(Rows, First + 99),
    format(Out, 'INSERT INTO field (No, Depth, Water_Cut) VALUES~n', []),
    forall(between(First, Last, No),
           ( Depth is 1000 + No,
             WaterCut is No mod 100,
             row_terminator(No, Last, End),
             format(Out, '  (~w, ~w, ~w)~w~n', [No, Depth, WaterCut, End])
           )).

write_zone_batch(Out, Batch, Rows) :-
    First is Batch * 100 + 1,
    Last is min(Rows, First + 99),
    format(Out, 'INSERT INTO zone (No, Zone_Name) VALUES~n', []),
    forall(between(First, Last, No),
           ( zone_name(No, ZoneName),
             row_terminator(No, Last, End),
             format(Out, '  (~w, ''~w'')~w~n', [No, ZoneName, End])
           )).

zone_name(No, 'Zone A') :- No mod 3 =:= 1, !.
zone_name(No, 'Zone B') :- No mod 3 =:= 2, !.
zone_name(_, 'Zone C').

row_terminator(No, Last, ';') :- No =:= Last, !.
row_terminator(_, _, ',').

expect_sql(SQL, Expected) :-
    asadb_exec_sql(SQL, Result),
    ( Result = multi([Expected]) -> true
    ; format(user_error, 'JOIN ASSERTION FAILED~nSQL: ~w~nExpected: ~q~nGot: ~q~n',
             [SQL, Expected, Result]),
      halt(1)
    ).

expect_multi_sql(SQL, Expected) :-
    asadb_exec_sql(SQL, Result),
    ( Result = multi(Expected) -> true
    ; format(user_error, 'JOIN MULTI ASSERTION FAILED~nSQL: ~w~nExpected: ~q~nGot: ~q~n',
             [SQL, Expected, Result]),
      halt(1)
    ).

assert_no_error(_, error(Code, Message)) :- !,
    format(user_error, 'JOIN FIXTURE IMPORT FAILED: ~w ~w~n', [Code, Message]),
    halt(1).
assert_no_error(_, multi(Results)) :-
    \+ member(error(_, _), Results), !.
assert_no_error(Stage, Result) :-
    format(user_error, 'JOIN ~w FAILED: ~q~n', [Stage, Result]),
    halt(1).

join_timeout :-
    format(user_error, 'JOIN REGRESSION FAILED: 15000-row aliased JOIN exceeded 30 seconds.~n', []),
    halt(1).

cleanup(SqlFile, DbFile) :-
    delete_if_exists(SqlFile),
    delete_if_exists(DbFile),
    atom_concat(DbFile, '.journal', Journal),
    atom_concat(DbFile, '.current_db', CurrentDb),
    atom_concat(DbFile, '.wal', Wal),
    atom_concat(DbFile, '.meta', Metadata),
    atom_concat(Metadata, '.tmp', MetadataTemp),
    atom_concat(Metadata, '.bak', MetadataBackup),
    atom_concat(DbFile, '.store', StoreDir),
    maplist(delete_if_exists,
            [Journal,CurrentDb,Wal,Metadata,MetadataTemp,MetadataBackup]),
    ( exists_directory(StoreDir) -> delete_directory_and_contents(StoreDir) ; true ).

delete_if_exists(File) :-
    ( exists_file(File) -> delete_file(File) ; true ).
