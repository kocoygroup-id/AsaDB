% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* Backend interchange regression.

   Verifies that every public interchange format is produced from backend
   storage and can be prepared for import without browser-owned row state.
*/

:- use_module('../src/asadb_core.pl').
:- use_module('../src/asadb_interchange.pl').
:- use_module(library(filesex)).
:- use_module(library(readutil)).
:- use_module(library(zip)).
:- initialization(main, main).

main :-
    DbFile = 'tests/interchange_test.asa',
    cleanup_database(DbFile),
    setup_call_cleanup(
        asadb_boot(DbFile),
        run_interchange_regression,
        ( catch(asadb_shutdown, _, true), cleanup_database(DbFile) )
    ),
    writeln('PASS: backend MySQL, PostgreSQL, CSV, and XLSX interchange.'),
    halt(0).

run_interchange_regression :-
    exec_ok(fixture,
            "CREATE DATABASE interchange; USE interchange; CREATE TABLE people (id INT PRIMARY KEY, name TEXT, score DOUBLE, note TEXT); INSERT INTO people VALUES (1, 'Ayu', 98.5, 'comma,quote\"'), (2, '日本', 87, NULL), (3, 'O\\'Brien', -4.25, 'line\\nnext'); CREATE TABLE teams (id INT PRIMARY KEY, team TEXT); INSERT INTO teams VALUES (1, '001'), (2, 'blue');"),
    ExportOptions = _{
        tables:[people],
        include_schema:true,
        include_data:true,
        create_database:false
    },
    test_step(csv, test_csv(ExportOptions)),
    test_step(csv_zip, test_csv_zip),
    test_step(xlsx, test_xlsx(ExportOptions)),
    test_step(mysql, test_sql_format(mysql, ExportOptions)),
    test_step(postgresql, test_sql_format(postgresql, ExportOptions)),
    test_step(export_selection, test_export_selection_controls),
    test_step(dialect_literal_safety, test_dialect_literal_safety),
    test_step(xlsx_dtd_rejected, test_xlsx_dtd_rejected).

test_step(Label, Goal) :-
    format('TEST: ~w ... ', [Label]),
    ( call(Goal) -> writeln(ok)
    ; writeln(failed),
      throw(error(assertion_failed(test_step(Label)), _))
    ).

test_csv(Options) :-
    asadb_interchange_export(interchange, csv, Options, File, Metadata),
    setup_call_cleanup(
        true,
        ( assert_metadata(csv, Metadata, 3),
          asadb_interchange_prepare_import(File, 'people.csv', csv,
                                           people_csv, replace,
                                           Prepared, ImportMetadata),
          setup_call_cleanup(
              true,
              ( assert_import_metadata(csv, ImportMetadata, 3),
                exec_sql_file(csv_import, Prepared),
                expect_count(people_csv, 3),
                expect_name(people_csv, 2, '日本')
              ),
              asadb_interchange_cleanup(Prepared)
          )
        ),
        asadb_interchange_cleanup(File)
    ).

test_csv_zip :-
    Options = _{
        tables:[people,teams],
        data_tables:[people,teams],
        include_schema:true,
        include_data:true,
        create_database:false
    },
    asadb_interchange_export(interchange, csv, Options, File, Metadata),
    setup_call_cleanup(
        true,
        ( Metadata.table_count =:= 2,
          Metadata.row_count =:= 5,
          Metadata.content_type == 'application/zip',
          asadb_interchange_prepare_import(
              File, 'interchange-csv.zip', auto, bundle_copy, replace,
              Prepared, ImportMetadata),
          setup_call_cleanup(
              true,
              ( ImportMetadata.tables =:= 2,
                ImportMetadata.rows =:= 5,
                exec_sql_file(csv_zip_import, Prepared),
                expect_prefixed_rows(bundle_copy, 5),
                expect_value(bundle_copy, team, id, 1, '001')
              ),
              asadb_interchange_cleanup(Prepared)
          )
        ),
        asadb_interchange_cleanup(File)
    ),
    NoDataOptions = Options.put(data_tables, []),
    asadb_interchange_export(interchange, mysql, NoDataOptions,
                             NoDataFile, NoDataMetadata),
    setup_call_cleanup(
        true,
        ( NoDataMetadata.row_count =:= 0,
          read_file_to_string(NoDataFile, NoDataSQL, [encoding(utf8)]),
          \+ sub_string(NoDataSQL, _, _, _, 'INSERT INTO')
        ),
        asadb_interchange_cleanup(NoDataFile)
    ).

expect_prefixed_rows(Prefix, Expected) :-
    asadb_get_state(state(_, DBs)),
    member(db(interchange, Tables, _, _, _, _), DBs),
    findall(Count,
            ( member(table(Name, _, Storage, _), Tables),
              sub_atom(Name, 0, _, _, Prefix),
              storage_count(Storage, Count)
            ),
            Counts),
    sum_list(Counts, Total),
    ( Total =:= Expected -> true
    ; throw(error(assertion_failed(prefixed_rows(Prefix, Expected, Total)), _))
    ).

storage_count(paged_rows(_, Count, _), Count) :- !.
storage_count(Rows, Count) :- length(Rows, Count).

test_xlsx(Options) :-
    ( asadb_interchange_export(interchange, xlsx, Options, File, Metadata) ->
        true
    ; asadb_get_state(State),
      throw(error(assertion_failed(xlsx_export(State, Options)), _))
    ),
    setup_call_cleanup(
        true,
        ( assert_metadata(xlsx, Metadata, 3),
          asadb_interchange_prepare_import(File, 'people.xlsx', auto,
                                           people_xlsx, replace,
                                           Prepared, ImportMetadata),
          setup_call_cleanup(
              true,
              ( assert_import_metadata(xlsx, ImportMetadata, 3),
                exec_sql_file(xlsx_import, Prepared),
                expect_count(people_xlsx, 3),
                expect_name(people_xlsx, 2, '日本')
              ),
              asadb_interchange_cleanup(Prepared)
          )
        ),
        asadb_interchange_cleanup(File)
    ).

test_sql_format(Format, Options) :-
    asadb_interchange_export(interchange, Format, Options, File, Metadata),
    setup_call_cleanup(
        true,
        ( assert_metadata(Format, Metadata, 3),
          format_extension(Format, Extension),
          atom_concat('people', Extension, Name),
          asadb_interchange_prepare_import(File, Name, auto, ignored, replace,
                                           Prepared, ImportMetadata),
          setup_call_cleanup(
              true,
              ( ImportMetadata.format == Format,
                exec_sql_file(Format, Prepared),
                expect_count(people, 3),
                expect_name(people, 2, '日本')
              ),
              asadb_interchange_cleanup(Prepared)
          )
        ),
        asadb_interchange_cleanup(File)
    ).

format_extension(mysql, '.mysql').
format_extension(postgresql, '.pgsql').

test_export_selection_controls :-
    Options = _{
        tables:[people,teams],
        data_tables:[people],
        include_schema:true,
        include_data:true,
        create_database:false,
        drop_tables:false
    },
    asadb_interchange_export(interchange, mysql, Options, File, Metadata),
    setup_call_cleanup(
        true,
        ( Metadata.table_count =:= 2,
          Metadata.row_count =:= 3,
          read_file_to_string(File, SQL, [encoding(utf8)]),
          sub_string(SQL, _, _, _, 'CREATE TABLE `teams`'),
          \+ sub_string(SQL, _, _, _, 'DROP TABLE'),
          \+ sub_string(SQL, _, _, _, '''blue''')
        ),
        asadb_interchange_cleanup(File)
    ).

test_dialect_literal_safety :-
    tmp_file_stream(utf8, Source, Out),
    setup_call_cleanup(
        true,
        format(Out,
               'CREATE TABLE public.literal_guard (serial_number TEXT, note TEXT);~nINSERT INTO public.literal_guard VALUES (''public.keep SERIAL::text'', ''x''::text);~n',
               []),
        close(Out)
    ),
    setup_call_cleanup(
          true,
          ( asadb_interchange_prepare_import(
              Source, 'literal_guard.sql', auto, ignored, replace,
              Prepared, Detection),
            Detection.format == postgresql,
          setup_call_cleanup(
              true,
              ( read_file_to_string(Prepared, SQL, [encoding(utf8)]),
                sub_string(SQL, _, _, _, 'serial_number'),
                sub_string(SQL, _, _, _, '''public.keep SERIAL::text'''),
                sub_string(SQL, _, _, _, '''x'''),
                \+ sub_string(SQL, _, _, _, '''x''::text')
              ),
              asadb_interchange_cleanup(Prepared)
          )
        ),
        asadb_interchange_cleanup(Source)
    ).

test_xlsx_dtd_rejected :-
    tmp_file_stream(octet, File, Temp),
    close(Temp),
    zip_open(File, write, Zipper, []),
    setup_call_cleanup(
        true,
        ( zipper_open_new_file_in_zip(
              Zipper, 'xl/workbook.xml', Out, [method(deflated)]),
          setup_call_cleanup(
              true,
              format(Out,
                     '<?xml version="1.0"?><!DOCTYPE x [<!ENTITY e SYSTEM "file:///etc/passwd">]><workbook/>',
                     []),
              close(Out)
          )
        ),
        zip_close(Zipper)
    ),
    setup_call_cleanup(
        true,
        ( catch(
              asadb_interchange_prepare_import(
                  File, 'unsafe.xlsx', xlsx, unsafe, replace, _, _),
              Error,
              true),
          ( Error = error(permission_error(parse, xlsx_xml_dtd,
                                           'xl/workbook.xml'), _) ->
              true
          ; throw(error(assertion_failed(xlsx_dtd_rejection(Error)), _))
          )
        ),
        asadb_interchange_cleanup(File)
    ).

assert_metadata(Format, Metadata, Rows) :-
    ( Metadata.format == Format,
      Metadata.source == backend_storage,
      Metadata.table_count =:= 1,
      Metadata.row_count =:= Rows,
      Metadata.bytes > 0 -> true
    ; throw(error(assertion_failed(export_metadata(Format, Metadata)), _))
    ).

assert_import_metadata(Format, Metadata, Rows) :-
    ( Metadata.format == Format,
      Metadata.rows =:= Rows -> true
    ; throw(error(assertion_failed(import_metadata(Format, Metadata)), _))
    ).

exec_sql_file(Stage, File) :-
    read_file_to_string(File, SQL, [encoding(utf8)]),
    exec_ok(Stage, SQL).

exec_ok(Stage, SQL) :-
    asadb_exec_sql(SQL, Result),
    ( result_has_error(Result) ->
        throw(error(assertion_failed(sql(Stage, Result)), _))
    ; true
    ).

result_has_error(error(_, _)).
result_has_error(multi(Results)) :-
    member(error(_, _), Results).

expect_count(Table, Count) :-
    format(atom(SQL), 'SELECT COUNT(*) AS total FROM ~w;', [Table]),
    asadb_exec_sql(SQL, Result0),
    single_result(Result0, Result),
    ( Result == table([total], [[Count]]) -> true
    ; throw(error(assertion_failed(count(Table, Count, Result)), _))
    ).

expect_name(Table, Id, Name) :-
    expect_value(Table, name, id, Id, Name).

expect_value(Table, Column, KeyColumn, Key, Value) :-
    format(atom(SQL), 'SELECT ~w FROM ~w WHERE ~w = ~w;',
           [Column, Table, KeyColumn, Key]),
    asadb_exec_sql(SQL, Result0),
    single_result(Result0, Result),
    ( Result == table([Column], [[Value]]) -> true
    ; throw(error(assertion_failed(value(Table, Column, Key, Value, Result)), _))
    ).

single_result(multi([Result]), Result) :- !.
single_result(Result, Result).

cleanup_database(DbFile) :-
    maplist(delete_if_exists, [DbFile]),
    atom_concat(DbFile, '.journal', Journal),
    atom_concat(DbFile, '.current_db', CurrentDb),
    atom_concat(DbFile, '.wal', Wal),
    atom_concat(DbFile, '.meta', Metadata),
    atom_concat(Metadata, '.tmp', MetadataTemp),
    atom_concat(Metadata, '.bak', MetadataBackup),
    atom_concat(DbFile, '.store', StoreDir),
    maplist(delete_if_exists,
            [Journal, CurrentDb, Wal, Metadata, MetadataTemp, MetadataBackup]),
    ( exists_directory(StoreDir) ->
        delete_directory_and_contents(StoreDir)
    ; true
    ).

delete_if_exists(File) :-
    ( exists_file(File) -> delete_file(File) ; true ).
