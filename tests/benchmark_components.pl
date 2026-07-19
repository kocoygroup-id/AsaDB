% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- use_module('../src/asadb_core.pl').
:- initialization(main, main).

main :-
    File = 'stress tests/public_safety_archive_5500.sql',
    DbFile = 'tests/benchmark_components.asa',
    cleanup(DbFile),
    read_file_to_codes(File, Codes, []),
    statistics(walltime, [ParseStart|_]),
    asadb_parse_sql(Codes, Statements),
    statistics(walltime, [ParseEnd|_]),
    length(Statements, StatementCount),
    asadb_boot(DbFile),
    asadb_exec_sql('CREATE DATABASE bench; USE bench; BEGIN;', Setup),
    ensure_ok(Setup),
    exclude(is_insert_ast, Statements, DdlStatements),
    include(is_insert_ast, Statements, InsertStatements),
    asadb_core:execute_many(DdlStatements, DdlResults),
    ensure_results_ok(DdlResults),
    InsertStatements = [insert(Table, Columns, _)|_],
    findall(Rows, member(insert(_, _, Rows), InsertStatements), RowGroups),
    append(RowGroups, ValueRows),
    statistics(walltime, [ExecuteStart|_]),
    asadb_core:eval_insert_rows(ValueRows, EvaluatedRows),
    statistics(walltime, [EvalEnd|_]),
    asadb_core:get_table(bench, Table, table(_, TableColumns, ExistingRows, _)),
    asadb_core:build_rows(TableColumns, Columns, EvaluatedRows, ExistingRows, _BuiltRows),
    statistics(walltime, [BuildEnd|_]),
    asadb_core:asadb_state(State0),
    asadb_core:apply_action(insert_rows(bench, Table, Columns, EvaluatedRows), State0, State),
    statistics(walltime, [ApplyEnd|_]),
    retractall(asadb_core:asadb_state(_)),
    assertz(asadb_core:asadb_state(State)),
    statistics(walltime, [ExecuteEnd|_]),
    statistics(walltime, [CommitStart|_]),
    asadb_exec_sql('COMMIT;', Commit),
    statistics(walltime, [CommitEnd|_]),
    ensure_ok(Commit),
    statistics(walltime, [LookupStart|_]),
    asadb_exec_sql('SELECT * FROM Public_Safety_Archive WHERE ID = 5000;', Lookup),
    statistics(walltime, [LookupEnd|_]),
    ensure_ok(Lookup),
    ParseMs is ParseEnd - ParseStart,
    ExecuteMs is ExecuteEnd - ExecuteStart,
    EvalMs is EvalEnd - ExecuteStart,
    BuildMs is BuildEnd - EvalEnd,
    ApplyMs is ApplyEnd - BuildEnd,
    JournalMs is ExecuteEnd - ApplyEnd,
    CommitMs is CommitEnd - CommitStart,
    LookupMs is LookupEnd - LookupStart,
    format('BENCH rows=5500 statements=~w parse_ms=~w execute_ms=~w eval_ms=~w build_ms=~w apply_ms=~w wal_ms=~w commit_ms=~w lookup_ms=~w~n',
           [StatementCount, ParseMs, ExecuteMs, EvalMs, BuildMs, ApplyMs, JournalMs,
            CommitMs, LookupMs]),
    asadb_shutdown,
    cleanup(DbFile),
    halt(0).

is_insert_ast(insert(_, _, _)).

ensure_ok(error(Code, Message)) :- !,
    format(user_error, 'BENCH FAILED: ~w ~w~n', [Code, Message]),
    halt(1).
ensure_ok(multi(Results)) :- !,
    ensure_results_ok(Results).
ensure_ok(_).

ensure_results_ok([]).
ensure_results_ok([error(Code, Message)|_]) :- !,
    format(user_error, 'BENCH FAILED: ~w ~w~n', [Code, Message]),
    halt(1).
ensure_results_ok([_|Results]) :-
    ensure_results_ok(Results).

cleanup(DbFile) :-
    delete_if_exists(DbFile),
    atom_concat(DbFile, '.journal', Journal),
    atom_concat(DbFile, '.current_db', CurrentDb),
    atom_concat(DbFile, '.wal', Wal),
    delete_if_exists(Journal),
    delete_if_exists(CurrentDb),
    delete_if_exists(Wal).

delete_if_exists(File) :-
    ( exists_file(File) -> delete_file(File) ; true ).
