% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* Bounded interchange stress smoke.

   Exercises repeated backend scans plus streaming CSV/XLSX preparation on a
   row set large enough to cross normal UI catalog hydration limits.
*/

:- use_module('../src/asadb_core.pl').
:- use_module('../src/asadb_interchange.pl').
:- use_module(library(filesex)).
:- initialization(main, main).

stress_rows(20000).

main :-
    DbFile = 'tests/interchange_stress.asa',
    cleanup_database(DbFile),
    setup_call_cleanup(
        asadb_boot(DbFile),
        run_stress,
        ( catch(asadb_shutdown, _, true), cleanup_database(DbFile) )
    ),
    halt(0).

run_stress :-
    stress_rows(Rows),
    exec_ok('CREATE DATABASE interchange_stress; USE interchange_stress; CREATE TABLE measurements (id INT PRIMARY KEY, label TEXT, value DOUBLE);'),
    insert_batches(1, Rows),
    Options = _{
        tables:[measurements],
        data_tables:[measurements],
        include_schema:true,
        include_data:true,
        create_database:false,
        drop_tables:true
    },
    statistics(walltime, [Start|_]),
    maplist(stress_export(Options, Rows), [mysql,postgresql,csv,xlsx]),
    statistics(walltime, [End|_]),
    Milliseconds is End - Start,
    format('PASS: 4 backend exports plus CSV/XLSX preparation, ~d rows each, ~d ms.~n',
           [Rows, Milliseconds]).

stress_export(Options, Rows, Format) :-
    asadb_interchange_export(interchange_stress, Format, Options,
                             File, Metadata),
    setup_call_cleanup(
        true,
        ( Metadata.row_count =:= Rows,
          Metadata.bytes > 0,
          stress_prepare_if_needed(Format, File, Rows)
        ),
        asadb_interchange_cleanup(File)
    ).

stress_prepare_if_needed(csv, File, Rows) :- !,
    prepare_and_assert(File, 'measurements.csv', csv, Rows).
stress_prepare_if_needed(xlsx, File, Rows) :- !,
    prepare_and_assert(File, 'measurements.xlsx', xlsx, Rows).
stress_prepare_if_needed(_, _, _).

prepare_and_assert(File, Name, Format, Rows) :-
    asadb_interchange_prepare_import(File, Name, Format, imported,
                                     replace, Prepared, Metadata),
    setup_call_cleanup(
        true,
        ( Metadata.rows =:= Rows,
          size_file(Prepared, PreparedBytes),
          PreparedBytes > 0
        ),
        asadb_interchange_cleanup(Prepared)
    ).

insert_batches(First, Last) :-
    First > Last, !.
insert_batches(First, Last) :-
    BatchLast is min(Last, First + 255),
    findall(Row,
            ( between(First, BatchLast, Id),
              Value is Id / 10,
              format(atom(Row), '(~d, ''row-~d'', ~15g)',
                     [Id, Id, Value])
            ),
            Rows),
    atomic_list_concat(Rows, ',', Values),
    format(atom(SQL),
           'INSERT INTO measurements (id,label,value) VALUES ~w;',
           [Values]),
    exec_ok(SQL),
    Next is BatchLast + 1,
    insert_batches(Next, Last).

exec_ok(SQL) :-
    asadb_exec_sql(SQL, Result),
    ( result_has_error(Result) ->
        throw(error(assertion_failed(sql(Result)), _))
    ; true
    ).

result_has_error(error(_, _)).
result_has_error(multi(Results)) :-
    member(error(_, _), Results).

cleanup_database(DbFile) :-
    atom_concat(DbFile, '.journal', Journal),
    atom_concat(DbFile, '.current_db', CurrentDb),
    atom_concat(DbFile, '.wal', Wal),
    atom_concat(DbFile, '.meta', Metadata),
    atom_concat(Metadata, '.tmp', MetadataTemp),
    atom_concat(Metadata, '.bak', MetadataBackup),
    atom_concat(DbFile, '.store', StoreDir),
    maplist(delete_if_exists,
            [DbFile, Journal, CurrentDb, Wal, Metadata, MetadataTemp,
             MetadataBackup]),
    ( exists_directory(StoreDir) ->
        delete_directory_and_contents(StoreDir)
    ; true
    ).

delete_if_exists(File) :-
    ( exists_file(File) -> delete_file(File) ; true ).
