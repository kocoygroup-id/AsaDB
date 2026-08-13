% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  AsaDB production interchange
  ----------------------------
  Backend-owned, bounded import/export for CSV, XLSX, MySQL SQL and
  PostgreSQL SQL.  This module never reads browser state: export walks the
  catalog and verified record pages while holding the normal execution lock.

  Interchange files are intentionally distinct from authenticated .asb
  production backups.  They are portable data/schema representations, not
  disaster-recovery snapshots.
*/

:- module(asadb_interchange, [
    asadb_interchange_export/5,
    asadb_interchange_prepare_import/7,
    asadb_interchange_detect_format/3,
    asadb_interchange_cleanup/1
]).

:- set_prolog_flag(double_quotes, string).

:- use_module(library(csv)).
:- use_module(library(lists)).
:- use_module(library(readutil)).
:- use_module(library(sgml)).
:- use_module(library(zip)).
:- use_module('asadb_core.pl').
:- use_module('asadb_record_manager.pl').

interchange_insert_batch_size(256).
interchange_csv_sample_rows(256).
interchange_archive_max_entries(4096).
interchange_archive_max_uncompressed_bytes(536870912).
interchange_archive_max_entry_bytes(268435456).

/* -------------------------------------------------------------------------
   Public API
   ------------------------------------------------------------------------- */

asadb_interchange_export(Database0, Format0, Options0, File, Metadata) :-
    interchange_database_atom(Database0, Database),
    interchange_format(Format0, Format),
    interchange_export_options(Options0, Options),
    catch(
        with_mutex(asadb_execution,
            once(interchange_export_locked(
                Database, Format, Options, File, Metadata))),
        Error,
        ( asadb_interchange_cleanup(File), throw(Error) )
    ).

asadb_interchange_prepare_import(File, OriginalName, RequestedFormat,
                                 TargetTable0, Mode0, PreparedFile,
                                 Metadata) :-
    interchange_import_mode(Mode0, Mode),
    interchange_target_table(TargetTable0, OriginalName, TargetTable),
    interchange_prepare_detect(File, OriginalName, RequestedFormat, Format),
    catch(
        once(interchange_prepare_import(
            Format, File, OriginalName, TargetTable,
            Mode, PreparedFile, Metadata)),
        Error,
        ( ( Format == asadb -> true
          ; asadb_interchange_cleanup(PreparedFile)
          ),
          throw(Error)
        )
    ).

asadb_interchange_detect_format(Name0, Requested0, Format) :-
    interchange_requested_format(Requested0, Requested),
    ( Requested \== auto ->
        Format = Requested
    ; interchange_name_atom(Name0, Name),
      downcase_atom(Name, Lower),
      interchange_extension_format(Lower, ExtensionFormat) ->
        ( ExtensionFormat == sql ->
            interchange_probe_sql_format(Name0, Format)
        ; Format = ExtensionFormat
        )
    ; Format = mysql
    ).

interchange_prepare_detect(_, _OriginalName, Requested0, Format) :-
    interchange_requested_format(Requested0, Requested),
    Requested \== auto, !,
    Format = Requested.
interchange_prepare_detect(File, OriginalName, auto, Format) :-
    interchange_name_atom(OriginalName, Name),
    downcase_atom(Name, Lower),
    ( interchange_extension_format(Lower, ExtensionFormat),
      ExtensionFormat \== sql ->
        Format = ExtensionFormat
    ; interchange_probe_sql_format(File, Format)
    ).

asadb_interchange_cleanup(File) :-
    ( nonvar(File), exists_file(File) -> catch(delete_file(File), _, true)
    ; true
    ).

/* -------------------------------------------------------------------------
   Export orchestration
   ------------------------------------------------------------------------- */

interchange_export_locked(Database, Format, Options, File, Metadata) :-
    asadb_get_state(State),
    interchange_database(State, Database, Db),
    interchange_db_parts(Db, CanonicalDatabase, Tables0, Views0),
    interchange_select_tables(Tables0, Options.tables, Tables),
    interchange_select_views(Views0, Options.tables, Views),
    ( Tables \= [] ; Views \= [] ),
    ( Format == mysql ->
        temporary_interchange_file(text, File),
        setup_call_cleanup(
            open(File, write, Out, [encoding(utf8), newline(posix)]),
            once(interchange_write_mysql(
                Out, CanonicalDatabase, Tables, Views, Options,
                _, ViewCount, RowCount)),
            close(Out)
        ),
        interchange_filename(CanonicalDatabase, '-mysql.sql', Filename),
        ContentType = 'application/sql; charset=UTF-8'
    ; Format == postgresql ->
        temporary_interchange_file(text, File),
        setup_call_cleanup(
            open(File, write, Out, [encoding(utf8), newline(posix)]),
            once(interchange_write_postgresql(
                Out, CanonicalDatabase, Tables, Views, Options,
                _, ViewCount, RowCount)),
            close(Out)
        ),
        interchange_filename(CanonicalDatabase, '-postgresql.sql', Filename),
        ContentType = 'application/sql; charset=UTF-8'
    ; Format == csv ->
        interchange_materialize_views(CanonicalDatabase, Views, ViewTables),
        append(Tables, ViewTables, ExportTables),
        interchange_write_csv_package(CanonicalDatabase, ExportTables, Options,
                                      File, Filename, ContentType,
                                      _, RowCount),
        length(Views, ViewCount)
    ; Format == xlsx ->
        interchange_materialize_views(CanonicalDatabase, Views, ViewTables),
        append(Tables, ViewTables, ExportTables),
        interchange_write_xlsx(CanonicalDatabase, ExportTables, Options, File,
                               _, RowCount),
        length(Views, ViewCount),
        interchange_filename(CanonicalDatabase, '.xlsx', Filename),
        ContentType =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ),
    size_file(File, Bytes),
    length(Tables, PhysicalTableCount),
    length(Views, ViewCount),
    ObjectCount is PhysicalTableCount + ViewCount,
    Metadata = interchange{
        format:Format,
        database:CanonicalDatabase,
        filename:Filename,
        content_type:ContentType,
        table_count:PhysicalTableCount,
        view_count:ViewCount,
        object_count:ObjectCount,
        row_count:RowCount,
        bytes:Bytes,
        source:backend_storage,
        production_backup:false
    }.

interchange_export_options(Options0, Options) :-
    ( is_dict(Options0) -> Dict = Options0 ; Dict = _{} ),
    interchange_dict_value(Dict, tables, all, RawTables),
    interchange_table_selection(RawTables, Tables),
    interchange_dict_value(Dict, data_tables, all, RawDataTables),
    interchange_data_table_selection(RawDataTables, DataTables),
    interchange_dict_bool(Dict, include_schema, true, IncludeSchema),
    interchange_dict_bool(Dict, include_data, true, IncludeData),
    interchange_dict_bool(Dict, create_database, true, CreateDatabase),
    interchange_dict_bool(Dict, drop_tables, true, DropTables),
    Options = export_options{
        tables:Tables,
        data_tables:DataTables,
        include_schema:IncludeSchema,
        include_data:IncludeData,
        create_database:CreateDatabase,
        drop_tables:DropTables
    }.

interchange_dict_value(Dict, Key, Default, Value) :-
    ( get_dict(Key, Dict, Found) -> Value = Found ; Value = Default ).

interchange_dict_bool(Dict, Key, Default, Bool) :-
    interchange_dict_value(Dict, Key, Default, Raw),
    interchange_bool(Raw, Bool).

interchange_bool(true, true) :- !.
interchange_bool(1, true) :- !.
interchange_bool(yes, true) :- !.
interchange_bool('true', true) :- !.
interchange_bool('1', true) :- !.
interchange_bool(_, false).

interchange_table_selection(all, all) :- !.
interchange_table_selection([], all) :- !.
interchange_table_selection(Value, Tables) :-
    is_list(Value), !,
    maplist(interchange_name_atom, Value, Tables).
interchange_table_selection(Value, Tables) :-
    interchange_name_atom(Value, Atom),
    atomic_list_concat(Parts0, ',', Atom),
    exclude(=(''), Parts0, Parts),
    ( Parts == [] -> Tables = all ; Tables = Parts ).

interchange_data_table_selection(all, all) :- !.
interchange_data_table_selection([], []) :- !.
interchange_data_table_selection(Value, Tables) :-
    interchange_table_selection(Value, Tables).

interchange_select_tables(Tables, all, Tables) :- !.
interchange_select_tables(Tables0, Names, Tables) :-
    include(interchange_selected_table(Names), Tables0, Tables).

interchange_select_views(Views, all, Views) :- !.
interchange_select_views(Views0, Names, Views) :-
    include(interchange_selected_view(Names), Views0, Views).

interchange_selected_table(Names, Table) :-
    interchange_table_parts(Table, Name, _, _, _),
    member(Selected, Names),
    interchange_same_identifier(Name, Selected), !.

interchange_selected_view(Names, View) :-
    interchange_view_parts(View, Name, _),
    member(Selected, Names),
    interchange_same_identifier(Name, Selected), !.

interchange_table_data_enabled(Options, Name) :-
    Options.include_data == true,
    ( Options.data_tables == all
    ; member(Selected, Options.data_tables),
      interchange_same_identifier(Name, Selected)
    ), !.

interchange_table_options(Options, Name, TableOptions) :-
    ( interchange_table_data_enabled(Options, Name) ->
        TableOptions = Options
    ; TableOptions = Options.put(include_data, false)
    ).

% Spreadsheet/CSV formats encode rows, not database objects.  Materialize
% only the explicitly selected views and give their result columns a portable
% TEXT-like type; the exact view definition remains available in SQL exports
% and native .asb backups.
interchange_materialize_views(_, [], []).
interchange_materialize_views(Database, [View|Views], [Table|Tables]) :-
    interchange_view_parts(View, Name, _),
    asadb_view_rows(Database, Name, Labels, Rows),
    interchange_view_columns(Labels, Columns),
    interchange_rows_from_lists(Labels, Rows, Storage),
    Table = table(Name, Columns, Storage, []),
    interchange_materialize_views(Database, Views, Tables).

interchange_view_columns([], []).
interchange_view_columns([Name|Names], [col(Name, text, [])|Columns]) :-
    interchange_view_columns(Names, Columns).

interchange_rows_from_lists(_, [], []).
interchange_rows_from_lists(Labels, [Values|Rows], [row(Pairs)|Storage]) :-
    interchange_zip_pairs(Labels, Values, Pairs),
    interchange_rows_from_lists(Labels, Rows, Storage).

interchange_zip_pairs([], _, []).
interchange_zip_pairs([Name|Names], [Value|Values], [Name=Value|Pairs]) :- !,
    interchange_zip_pairs(Names, Values, Pairs).
interchange_zip_pairs([Name|Names], [], [Name=null|Pairs]) :-
    interchange_zip_pairs(Names, [], Pairs).

/* -------------------------------------------------------------------------
   MySQL and PostgreSQL export
   ------------------------------------------------------------------------- */

interchange_write_mysql(Out, Database, Tables, Views, Options,
                        TableCount, ViewCount, RowCount) :-
    format(Out, '-- AsaDB backend interchange: MySQL~n', []),
    format(Out, 'SET NAMES utf8mb4;~nSET FOREIGN_KEY_CHECKS=0;~n', []),
    ( Options.create_database == true ->
        sql_identifier(mysql, Database, DB),
        format(Out, 'CREATE DATABASE IF NOT EXISTS ~w;~nUSE ~w;~n~n', [DB, DB])
    ; true
    ),
    interchange_order_tables(Tables, OrderedTables),
    interchange_write_sql_tables(mysql, Out, OrderedTables, Options,
                                 0, TableCount, 0, RowCount),
    interchange_write_sql_views(mysql, Out, Database, Views, Options,
                                0, ViewCount),
    format(Out, 'SET FOREIGN_KEY_CHECKS=1;~n', []).

interchange_write_postgresql(Out, Database, Tables, Views, Options,
                             TableCount, ViewCount, RowCount) :-
    format(Out, '-- AsaDB backend interchange: PostgreSQL~n', []),
    format(Out, 'SET client_encoding = ''UTF8'';~n', []),
    ( Options.create_database == true ->
        sql_identifier(postgresql, Database, Schema),
        format(Out, 'CREATE SCHEMA IF NOT EXISTS ~w;~n', [Schema]),
        format(Out, 'SET search_path TO ~w;~n~n', [Schema])
    ; true
    ),
    interchange_order_tables(Tables, OrderedTables),
    interchange_write_sql_tables(postgresql, Out, OrderedTables, Options,
                                 0, TableCount, 0, RowCount),
    interchange_write_sql_views(postgresql, Out, Database, Views, Options,
                                0, ViewCount).

interchange_write_sql_tables(_, _, [], _, TableCount, TableCount,
                             RowCount, RowCount).
interchange_write_sql_tables(Dialect, Out, [Table|Tables], Options,
                             TableCount0, TableCount, RowCount0, RowCount) :-
    interchange_table_parts(Table, Name, Columns, Storage, Indexes),
    ( Options.include_schema == true ->
        interchange_write_table_schema(Dialect, Out, Name, Columns, Indexes,
                                       Options)
    ; true
    ),
    ( interchange_table_data_enabled(Options, Name) ->
        interchange_write_table_data(Dialect, Out, Name, Columns, Storage,
                                     Rows)
    ; Rows = 0
    ),
    TableCount1 is TableCount0 + 1,
    RowCount1 is RowCount0 + Rows,
    interchange_write_sql_tables(Dialect, Out, Tables, Options,
                                 TableCount1, TableCount,
                                 RowCount1, RowCount).

% SQL formats retain a view as a view definition.  CSV/XLSX do not have a
% view DDL concept, so their path materializes the same definition below.
interchange_write_sql_views(_, _, _, [], _, Count, Count).
interchange_write_sql_views(Dialect, Out, Database, [View|Views], Options,
                            Count0, Count) :-
    ( Options.include_schema == true ->
        interchange_write_view_schema(Dialect, Out, Database, View, Options)
    ; true
    ),
    Count1 is Count0 + 1,
    interchange_write_sql_views(Dialect, Out, Database, Views, Options,
                                Count1, Count).

interchange_write_view_schema(Dialect, Out, Database, View, Options) :-
    interchange_view_parts(View, Name, SelectAST),
    sql_identifier(Dialect, Name, ViewSQL),
    ( Options.drop_tables == true ->
        format(Out, 'DROP VIEW IF EXISTS ~w;~n', [ViewSQL])
    ; true
    ),
    interchange_select_sql(Dialect, SelectAST, SelectSQL),
    format(Out, 'CREATE VIEW ~w AS ~w;~n~n', [ViewSQL, SelectSQL]),
    % Resolve the definition while the database is explicit.  It catches a
    % stale/corrupt catalog entry before we hand an export to the caller.
    asadb_view_definition(Database, Name, SelectAST).

interchange_write_table_schema(Dialect, Out, Name, Columns, Indexes, Options) :-
    sql_identifier(Dialect, Name, TableSQL),
    ( Options.drop_tables == true ->
        format(Out, 'DROP TABLE IF EXISTS ~w;~n', [TableSQL])
    ; true
    ),
    format(Out, 'CREATE TABLE ~w (~n', [TableSQL]),
    interchange_write_columns(Dialect, Out, Columns, 0),
    interchange_write_table_constraints(Dialect, Out, Indexes, Columns),
    format(Out, '~n);~n', []),
    interchange_write_indexes(Dialect, Out, Name, Indexes),
    nl(Out).

% The catalog is newest-first, while foreign-key DDL requires the parent to
% exist first on both MySQL and PostgreSQL.  Stable topological order keeps
% SQL exports executable without weakening or dropping constraints.
interchange_order_tables(Tables, Ordered) :-
    interchange_order_tables_(Tables, [], Ordered).

interchange_order_tables_([], Ordered, Ordered).
interchange_order_tables_(Remaining, Ordered0, Ordered) :-
    select(Ready, Remaining, Rest),
    interchange_table_ready(Ready, Ordered0), !,
    append(Ordered0, [Ready], Ordered1),
    interchange_order_tables_(Rest, Ordered1, Ordered).
interchange_order_tables_(Remaining, _, _) :-
    throw(error(domain_error(interchange_foreign_key_dependency_cycle, Remaining), _)).

interchange_table_ready(Table, Ordered) :-
    interchange_table_parts(Table, Name, _Columns, _Storage, Indexes),
    forall(member(foreign_key(_, _, RefTable, _, restrict, restrict), Indexes),
           ( interchange_same_identifier(Name, RefTable)
           ; interchange_ordered_table(RefTable, Ordered)
           )).

interchange_ordered_table(Name, [Table|_]) :-
    interchange_table_parts(Table, Existing, _Columns, _Storage, _Indexes),
    interchange_same_identifier(Name, Existing), !.
interchange_ordered_table(Name, [_|Tables]) :-
    interchange_ordered_table(Name, Tables).

interchange_write_table_constraints(Dialect, Out, Indexes, Columns) :-
    interchange_table_constraint_sqls(Dialect, Indexes, ConstraintSQL),
    ( Columns = [] -> PrefixComma = false ; PrefixComma = true ),
    interchange_emit_table_constraints(Out, ConstraintSQL, PrefixComma).

interchange_emit_table_constraints(_, [], _).
interchange_emit_table_constraints(Out, [SQL|SQLs], true) :- !,
    format(Out, ',~n  ~w', [SQL]),
    interchange_emit_table_constraints(Out, SQLs, true).
interchange_emit_table_constraints(Out, [SQL|SQLs], false) :-
    format(Out, '  ~w', [SQL]),
    interchange_emit_table_constraints(Out, SQLs, true).

interchange_table_constraint_sqls(_, [], []).
interchange_table_constraint_sqls(Dialect, [Index|Indexes], SQLs) :-
    ( interchange_table_constraint_sql(Dialect, Index, SQL) ->
        SQLs = [SQL|Rest]
    ; SQLs = Rest
    ),
    interchange_table_constraint_sqls(Dialect, Indexes, Rest).

interchange_table_constraint_sql(Dialect, index('PRIMARY', Columns, _), SQL) :- !,
    interchange_constraint_columns(Dialect, Columns, ColumnSQL),
    atomic_list_concat(['PRIMARY KEY (', ColumnSQL, ')'], SQL).
interchange_table_constraint_sql(Dialect, index(Name, Columns, unique), SQL) :- !,
    sql_identifier(Dialect, Name, NameSQL),
    interchange_constraint_columns(Dialect, Columns, ColumnSQL),
    atomic_list_concat(['CONSTRAINT ', NameSQL, ' UNIQUE (', ColumnSQL, ')'], SQL).
interchange_table_constraint_sql(Dialect, check(Name, Expr), SQL) :- !,
    sql_identifier(Dialect, Name, NameSQL),
    asadb_constraint_expression_sql(Expr, ExprSQL),
    atomic_list_concat(['CONSTRAINT ', NameSQL, ' CHECK (', ExprSQL, ')'], SQL).
interchange_table_constraint_sql(Dialect,
                                 foreign_key(Name, Local, RefTable, Ref, restrict, restrict), SQL) :- !,
    sql_identifier(Dialect, Name, NameSQL),
    interchange_constraint_columns(Dialect, Local, LocalSQL),
    sql_identifier(Dialect, RefTable, RefTableSQL),
    interchange_constraint_columns(Dialect, Ref, RefSQL),
    atomic_list_concat(['CONSTRAINT ', NameSQL, ' FOREIGN KEY (', LocalSQL,
                        ') REFERENCES ', RefTableSQL, ' (', RefSQL,
                        ') ON DELETE RESTRICT ON UPDATE RESTRICT'], SQL).

interchange_constraint_columns(Dialect, Columns, SQL) :-
    maplist(sql_identifier(Dialect), Columns, SQLColumns),
    atomic_list_concat(SQLColumns, ', ', SQL).

interchange_write_columns(_, _, [], _).
interchange_write_columns(Dialect, Out, [Column|Columns], Index) :-
    ( Index > 0 -> format(Out, ',~n', []) ; true ),
    interchange_column_sql(Dialect, Column, SQL),
    format(Out, '  ~w', [SQL]),
    Next is Index + 1,
    interchange_write_columns(Dialect, Out, Columns, Next).

interchange_column_sql(Dialect, col(Name, Type0, Options), SQL) :-
    sql_identifier(Dialect, Name, NameSQL),
    interchange_type_sql(Dialect, Type0, TypeSQL),
    interchange_column_options_sql(Dialect, Options, OptionSQL),
    atomic_list_concat([NameSQL, ' ', TypeSQL, OptionSQL], SQL).

interchange_column_options_sql(_, [], '').
interchange_column_options_sql(Dialect, [Option|Options], SQL) :-
    interchange_column_option_sql(Dialect, Option, Head),
    interchange_column_options_sql(Dialect, Options, Tail),
    atom_concat(Head, Tail, SQL).

interchange_column_option_sql(_, not_null, ' NOT NULL') :- !.
interchange_column_option_sql(_, nullable, '') :- !.
interchange_column_option_sql(_, primary_key, '') :- !.
interchange_column_option_sql(_, unique, '') :- !.
interchange_column_option_sql(mysql, auto_increment, ' AUTO_INCREMENT') :- !.
interchange_column_option_sql(postgresql, auto_increment,
                              ' GENERATED BY DEFAULT AS IDENTITY') :- !.
interchange_column_option_sql(Dialect, default(Value), SQL) :- !,
    sql_value(Dialect, Value, Literal),
    atomic_list_concat([' DEFAULT ', Literal], SQL).
interchange_column_option_sql(_, check(Expr), SQL) :- !,
    asadb_constraint_expression_sql(Expr, ExprSQL),
    atomic_list_concat([' CHECK (', ExprSQL, ')'], SQL).
interchange_column_option_sql(_, raw_option(_), '') :- !.
interchange_column_option_sql(_, _, '').

interchange_type_sql(Dialect, Type0, Type) :-
    interchange_name_atom(Type0, TypeAtom),
    upcase_atom(TypeAtom, Upper),
    ( Dialect == postgresql -> postgres_type(Upper, Type)
    ; mysql_type(Upper, Type)
    ).

mysql_type(Type, Type).

postgres_type(Type, 'INTEGER') :-
    memberchk(Type, ['INT','INTEGER','TINYINT','SMALLINT','MEDIUMINT']), !.
postgres_type(Type, 'BIGINT') :- sub_atom(Type, 0, _, _, 'BIGINT'), !.
postgres_type(Type, 'DOUBLE PRECISION') :-
    memberchk(Type, ['DOUBLE','REAL']), !.
postgres_type(Type, 'BYTEA') :-
    ( sub_atom(Type, _, _, _, 'BLOB')
    ; sub_atom(Type, _, _, _, 'BINARY')
    ), !.
postgres_type(Type, 'TIMESTAMP') :-
    sub_atom(Type, _, _, _, 'DATETIME'), !.
postgres_type(Type, 'BOOLEAN') :-
    memberchk(Type, ['BOOL','BOOLEAN']), !.
postgres_type(Type, Type).

interchange_write_indexes(_, _, _, []).
interchange_write_indexes(Dialect, Out, Table, [Index|Indexes]) :-
    ( interchange_index_sql(Dialect, Table, Index, SQL) ->
        format(Out, '~w;~n', [SQL])
    ; true
    ),
    interchange_write_indexes(Dialect, Out, Table, Indexes).

interchange_index_sql(_, _, index(Name, _, _), _) :-
    interchange_same_identifier(Name, 'PRIMARY'), !, fail.
interchange_index_sql(_, _, index(_, _, unique), _) :- !, fail.
interchange_index_sql(Dialect, Table, index(Name, Columns, Kind), SQL) :-
    Columns \= [],
    sql_identifier(Dialect, Name, IndexSQL),
    sql_identifier(Dialect, Table, TableSQL),
    maplist(sql_identifier(Dialect), Columns, ColumnSQL),
    atomic_list_concat(ColumnSQL, ', ', ColumnsText),
    ( Kind == unique -> Unique = 'UNIQUE ' ; Unique = '' ),
    atomic_list_concat(['CREATE ', Unique, 'INDEX ', IndexSQL, ' ON ',
                        TableSQL, ' (', ColumnsText, ')'], SQL).

interchange_write_table_data(mysql, Out, Table, Columns, Storage, Count) :-
    sql_identifier(mysql, Table, TableSQL),
    interchange_column_names(Columns, Names),
    maplist(sql_identifier(mysql), Names, SQLNames),
    atomic_list_concat(SQLNames, ', ', ColumnText),
    Counter = sql_batch(0, 0),
    forall(interchange_storage_row(Storage, Row),
           mysql_write_batch_row(Out, TableSQL, ColumnText, Columns,
                                 Row, Counter)),
    finish_sql_batch(Out, Counter),
    arg(2, Counter, Count).
interchange_write_table_data(postgresql, Out, Table, Columns, Storage, Count) :-
    sql_identifier(postgresql, Table, TableSQL),
    interchange_column_names(Columns, Names),
    maplist(sql_identifier(postgresql), Names, SQLNames),
    atomic_list_concat(SQLNames, ', ', ColumnText),
    format(Out, 'COPY ~w (~w) FROM stdin;~n', [TableSQL, ColumnText]),
    Counter = row_count(0),
    forall(interchange_storage_row(Storage, Row),
           postgres_write_copy_row(Out, Columns, Row, Counter)),
    format(Out, '\\.~n~n', []),
    arg(1, Counter, Count).

mysql_write_batch_row(Out, TableSQL, ColumnText, Columns, row(Pairs), Counter) :-
    arg(1, Counter, Batch0),
    ( Batch0 =:= 0 ->
        format(Out, 'INSERT INTO ~w (~w) VALUES~n  ', [TableSQL, ColumnText])
    ; format(Out, ',~n  ', [])
    ),
    interchange_row_values(Columns, Pairs, Values),
    maplist(sql_value(mysql), Values, Literals),
    atomic_list_concat(Literals, ', ', ValueText),
    format(Out, '(~w)', [ValueText]),
    Batch1 is Batch0 + 1,
    arg(2, Counter, Total0),
    Total is Total0 + 1,
    interchange_insert_batch_size(Max),
    ( Batch1 >= Max ->
        format(Out, ';~n', []),
        Batch = 0
    ; Batch = Batch1
    ),
    nb_setarg(1, Counter, Batch),
    nb_setarg(2, Counter, Total).

finish_sql_batch(Out, Counter) :-
    arg(1, Counter, Batch),
    ( Batch > 0 -> format(Out, ';~n~n', []) ; true ).

postgres_write_copy_row(Out, Columns, row(Pairs), Counter) :-
    interchange_row_values(Columns, Pairs, Values),
    maplist(postgres_copy_value, Values, Fields),
    atomic_list_concat(Fields, '\t', Line),
    format(Out, '~w~n', [Line]),
    arg(1, Counter, Count0),
    Count is Count0 + 1,
    nb_setarg(1, Counter, Count).

postgres_copy_value(null, '\\N') :- !.
postgres_copy_value(Value, Field) :-
    interchange_scalar_atom(Value, Atom),
    atom_codes(Atom, Codes),
    postgres_copy_escape(Codes, Escaped),
    atom_codes(Field, Escaped).

postgres_copy_escape([], []).
postgres_copy_escape([92|Codes], [92,92|Escaped]) :- !,
    postgres_copy_escape(Codes, Escaped).
postgres_copy_escape([9|Codes], [92,116|Escaped]) :- !,
    postgres_copy_escape(Codes, Escaped).
postgres_copy_escape([10|Codes], [92,110|Escaped]) :- !,
    postgres_copy_escape(Codes, Escaped).
postgres_copy_escape([13|Codes], [92,114|Escaped]) :- !,
    postgres_copy_escape(Codes, Escaped).
postgres_copy_escape([Code|Codes], [Code|Escaped]) :-
    postgres_copy_escape(Codes, Escaped).

/* -------------------------------------------------------------------------
   View SQL rendering
   ------------------------------------------------------------------------- */

% Views are stored as parsed AsaDB SELECT terms, not as untrusted source SQL.
% Render that AST with dialect quoting so an interchange file can recreate the
% view without relying on a browser cache or on a lossy Prolog-term comment.
interchange_select_sql(Dialect,
                       select(Projection, Source, Where, Group, Order, Limit),
                       SQL) :-
    interchange_projection_sql(Dialect, Projection, ProjectionSQL),
    interchange_source_sql(Dialect, Source, SourceSQL),
    interchange_where_sql(Dialect, Where, WhereSQL),
    interchange_group_sql(Dialect, Group, GroupSQL),
    interchange_order_sql(Dialect, Order, OrderSQL),
    interchange_limit_sql(Limit, LimitSQL),
    atomic_list_concat(['SELECT ', ProjectionSQL, ' FROM ', SourceSQL,
                        WhereSQL, GroupSQL, OrderSQL, LimitSQL], SQL).
interchange_select_sql(Dialect, union(Left, Right, Mode), SQL) :-
    interchange_select_sql(Dialect, Left, LeftSQL),
    interchange_select_sql(Dialect, Right, RightSQL),
    ( Mode == all -> Keyword = ' UNION ALL ' ; Keyword = ' UNION ' ),
    atomic_list_concat([LeftSQL, Keyword, RightSQL], SQL).
interchange_select_sql(_, SelectAST, _) :-
    throw(error(domain_error(exportable_view_select, SelectAST), _)).

interchange_projection_sql(_, all, '*') :- !.
interchange_projection_sql(Dialect, Projections, SQL) :-
    maplist(interchange_projection_item_sql(Dialect), Projections, Items),
    atomic_list_concat(Items, ', ', SQL).

interchange_projection_item_sql(Dialect, Name, SQL) :-
    atom(Name), !,
    sql_identifier(Dialect, Name, SQL).
interchange_projection_item_sql(Dialect, projection(Label, Expr), SQL) :-
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    ( interchange_expr_label(Expr, Label) -> SQL = ExprSQL
    ; sql_identifier(Dialect, Label, LabelSQL),
      atomic_list_concat([ExprSQL, ' AS ', LabelSQL], SQL)
    ).

interchange_expr_label(col(Name), Name) :- !.
interchange_expr_label(qcol(Qualifier, Name), Label) :- !,
    atomic_list_concat([Qualifier, Name], '.', Label).
interchange_expr_label(func(Name, _), Name) :- !.
interchange_expr_label(Expr, Label) :- atom(Expr), Expr == Label.

interchange_source_sql(Dialect, table_ref(Name, none), SQL) :- !,
    sql_identifier(Dialect, Name, SQL).
interchange_source_sql(Dialect, table_ref(Name, Alias), SQL) :- !,
    sql_identifier(Dialect, Name, NameSQL),
    sql_identifier(Dialect, Alias, AliasSQL),
    atomic_list_concat([NameSQL, ' AS ', AliasSQL], SQL).
interchange_source_sql(Dialect, join(Kind, Left, Right, On), SQL) :- !,
    interchange_source_sql(Dialect, Left, LeftSQL),
    interchange_source_sql(Dialect, Right, RightSQL),
    interchange_join_keyword(Kind, Keyword),
    interchange_expr_sql(Dialect, On, OnSQL),
    atomic_list_concat([LeftSQL, ' ', Keyword, ' ', RightSQL, ' ON ', OnSQL], SQL).
interchange_source_sql(_, Source, _) :-
    throw(error(domain_error(exportable_view_source, Source), _)).

interchange_join_keyword(inner, 'INNER JOIN').
interchange_join_keyword(left, 'LEFT JOIN').
interchange_join_keyword(right, 'RIGHT JOIN').
interchange_join_keyword(cross, 'CROSS JOIN').

interchange_where_sql(_, true, '') :- !.
interchange_where_sql(Dialect, Expr, SQL) :-
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    atomic_list_concat([' WHERE ', ExprSQL], SQL).

interchange_group_sql(_, none, '') :- !.
interchange_group_sql(Dialect, group(Exprs), SQL) :-
    maplist(interchange_expr_sql(Dialect), Exprs, Items),
    atomic_list_concat(Items, ', ', Text),
    atomic_list_concat([' GROUP BY ', Text], SQL).

interchange_order_sql(_, none, '') :- !.
interchange_order_sql(_, order([]), '') :- !.
interchange_order_sql(Dialect, order(Items), SQL) :-
    maplist(interchange_order_item_sql(Dialect), Items, TextItems),
    atomic_list_concat(TextItems, ', ', Text),
    atomic_list_concat([' ORDER BY ', Text], SQL).

interchange_order_item_sql(Dialect, order(Expr, Direction), SQL) :-
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    upcase_atom(Direction, DirectionSQL),
    atomic_list_concat([ExprSQL, ' ', DirectionSQL], SQL).

interchange_limit_sql(none, '') :- !.
interchange_limit_sql(limit(0, Count), SQL) :- !,
    format(atom(SQL), ' LIMIT ~w', [Count]).
interchange_limit_sql(limit(Offset, Count), SQL) :-
    format(atom(SQL), ' LIMIT ~w OFFSET ~w', [Count, Offset]).

interchange_expr_sql(_, all, '*') :- !.
interchange_expr_sql(_, value(current_timestamp), 'CURRENT_TIMESTAMP') :- !.
interchange_expr_sql(Dialect, value(Value), SQL) :- !,
    sql_value(Dialect, Value, SQL).
interchange_expr_sql(Dialect, col(Name), SQL) :- !,
    sql_identifier(Dialect, Name, SQL).
interchange_expr_sql(Dialect, qcol(Qualifier, Name), SQL) :- !,
    sql_identifier(Dialect, Qualifier, QualifierSQL),
    sql_identifier(Dialect, Name, NameSQL),
    atomic_list_concat([QualifierSQL, '.', NameSQL], SQL).
interchange_expr_sql(Dialect, func(Name, Args), SQL) :- !,
    upcase_atom(Name, Function),
    maplist(interchange_expr_sql(Dialect), Args, ArgSQL),
    atomic_list_concat(ArgSQL, ', ', Arguments),
    atomic_list_concat([Function, '(', Arguments, ')'], SQL).
interchange_expr_sql(Dialect, cmp(Op, Left, Right), SQL) :- !,
    interchange_binary_expr_sql(Dialect, Left, Op, Right, SQL).
interchange_expr_sql(Dialect, and(Left, Right), SQL) :- !,
    interchange_binary_expr_sql(Dialect, Left, 'AND', Right, SQL).
interchange_expr_sql(Dialect, or(Left, Right), SQL) :- !,
    interchange_binary_expr_sql(Dialect, Left, 'OR', Right, SQL).
interchange_expr_sql(Dialect, xor(Left, Right), SQL) :- !,
    interchange_binary_expr_sql(Dialect, Left, 'XOR', Right, SQL).
interchange_expr_sql(Dialect, not(Expr), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    atomic_list_concat(['(NOT ', ExprSQL, ')'], SQL).
interchange_expr_sql(Dialect, is_null(Expr), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    atomic_list_concat(['(', ExprSQL, ' IS NULL)'], SQL).
interchange_expr_sql(Dialect, is_not_null(Expr), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    atomic_list_concat(['(', ExprSQL, ' IS NOT NULL)'], SQL).
interchange_expr_sql(Dialect, is_true(Expr), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    atomic_list_concat(['(', ExprSQL, ' IS TRUE)'], SQL).
interchange_expr_sql(Dialect, is_false(Expr), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    atomic_list_concat(['(', ExprSQL, ' IS FALSE)'], SQL).
interchange_expr_sql(Dialect, is_unknown(Expr), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    atomic_list_concat(['(', ExprSQL, ' IS UNKNOWN)'], SQL).
interchange_expr_sql(Dialect, like(Left, Right), SQL) :- !,
    interchange_binary_expr_sql(Dialect, Left, 'LIKE', Right, SQL).
interchange_expr_sql(Dialect, between(Expr, Low, High), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    interchange_expr_sql(Dialect, Low, LowSQL),
    interchange_expr_sql(Dialect, High, HighSQL),
    atomic_list_concat(['(', ExprSQL, ' BETWEEN ', LowSQL, ' AND ', HighSQL, ')'], SQL).
interchange_expr_sql(Dialect, in_list(Expr, Values), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    maplist(interchange_expr_sql(Dialect), Values, ValueSQL),
    atomic_list_concat(ValueSQL, ', ', Text),
    atomic_list_concat(['(', ExprSQL, ' IN (', Text, '))'], SQL).
interchange_expr_sql(Dialect, in_subquery(Expr, SelectAST), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    interchange_select_sql(Dialect, SelectAST, SelectSQL),
    atomic_list_concat(['(', ExprSQL, ' IN (', SelectSQL, '))'], SQL).
interchange_expr_sql(Dialect, exists_subquery(SelectAST), SQL) :- !,
    interchange_select_sql(Dialect, SelectAST, SelectSQL),
    atomic_list_concat(['EXISTS (', SelectSQL, ')'], SQL).
interchange_expr_sql(Dialect, subquery(SelectAST), SQL) :- !,
    interchange_select_sql(Dialect, SelectAST, SelectSQL),
    atomic_list_concat(['(', SelectSQL, ')'], SQL).
interchange_expr_sql(Dialect, add(Left, Right), SQL) :- !,
    interchange_binary_expr_sql(Dialect, Left, '+', Right, SQL).
interchange_expr_sql(Dialect, sub(Left, Right), SQL) :- !,
    interchange_binary_expr_sql(Dialect, Left, '-', Right, SQL).
interchange_expr_sql(Dialect, mul(Left, Right), SQL) :- !,
    interchange_binary_expr_sql(Dialect, Left, '*', Right, SQL).
interchange_expr_sql(Dialect, div(Left, Right), SQL) :- !,
    interchange_binary_expr_sql(Dialect, Left, '/', Right, SQL).
interchange_expr_sql(Dialect, neg(Expr), SQL) :- !,
    interchange_expr_sql(Dialect, Expr, ExprSQL),
    atomic_list_concat(['(-', ExprSQL, ')'], SQL).
interchange_expr_sql(Dialect, tuple(Exprs), SQL) :- !,
    maplist(interchange_expr_sql(Dialect), Exprs, Items),
    atomic_list_concat(Items, ', ', Text),
    atomic_list_concat(['(', Text, ')'], SQL).
interchange_expr_sql(Dialect, case(Whens, Else), SQL) :- !,
    interchange_case_when_sql(Dialect, Whens, WhenSQL),
    interchange_expr_sql(Dialect, Else, ElseSQL),
    atomic_list_concat(['CASE ', WhenSQL, ' ELSE ', ElseSQL, ' END'], SQL).
interchange_expr_sql(_, Expr, _) :-
    throw(error(domain_error(exportable_view_expression, Expr), _)).

interchange_binary_expr_sql(Dialect, Left, Operator, Right, SQL) :-
    interchange_expr_sql(Dialect, Left, LeftSQL),
    interchange_expr_sql(Dialect, Right, RightSQL),
    atomic_list_concat(['(', LeftSQL, ' ', Operator, ' ', RightSQL, ')'], SQL).

interchange_case_when_sql(_, [], '').
interchange_case_when_sql(Dialect, [when(Condition, Value)|Whens], SQL) :-
    interchange_expr_sql(Dialect, Condition, ConditionSQL),
    interchange_expr_sql(Dialect, Value, ValueSQL),
    interchange_case_when_sql(Dialect, Whens, Tail),
    atomic_list_concat(['WHEN ', ConditionSQL, ' THEN ', ValueSQL, ' ', Tail], SQL).

/* -------------------------------------------------------------------------
   CSV export
   ------------------------------------------------------------------------- */

interchange_write_csv_package(_Database, [Table], Options, File, Filename,
                              'text/csv; charset=UTF-8', 1, RowCount) :- !,
    temporary_interchange_file(text, File),
    interchange_table_parts(Table, Name, Columns, Storage, _),
    interchange_table_options(Options, Name, TableOptions),
    setup_call_cleanup(
        open(File, write, Out, [encoding(utf8), newline(posix)]),
        once(interchange_write_csv_table(
            Out, Columns, Storage, TableOptions, RowCount)),
        close(Out)
    ),
    interchange_filename(Name, '.csv', Filename).
interchange_write_csv_package(Database, Tables, Options, File, Filename,
                              'application/zip', TableCount, RowCount) :-
    temporary_interchange_file(binary, File),
    zip_open(File, write, Zipper, []),
    setup_call_cleanup(
        true,
        once(interchange_write_csv_zip_tables(
            Zipper, Tables, Options,
            0, TableCount, 0, RowCount)),
        zip_close(Zipper)
    ),
    interchange_filename(Database, '-csv.zip', Filename).

interchange_write_csv_zip_tables(_, [], _, TableCount, TableCount,
                                 RowCount, RowCount).
interchange_write_csv_zip_tables(Zipper, [Table|Tables], Options,
                                 TableCount0, TableCount,
                                 RowCount0, RowCount) :-
    interchange_table_parts(Table, Name, Columns, Storage, _),
    interchange_table_options(Options, Name, TableOptions),
    interchange_filename(Name, '.csv', EntryName),
    zipper_open_new_file_in_zip(Zipper, EntryName, Out,
                                [type(text), encoding(utf8),
                                 method(deflated), level(6), zip64(true)]),
    setup_call_cleanup(
        true,
        once(interchange_write_csv_table(
            Out, Columns, Storage, TableOptions, Rows)),
        close(Out)
    ),
    TableCount1 is TableCount0 + 1,
    RowCount1 is RowCount0 + Rows,
    interchange_write_csv_zip_tables(Zipper, Tables, Options,
                                     TableCount1, TableCount,
                                     RowCount1, RowCount).

interchange_write_csv_table(Out, Columns, Storage, Options, RowCount) :-
    ( Options.include_schema == true ->
        interchange_column_names(Columns, Names),
        write_csv_fields(Out, Names)
    ; true
    ),
    Counter = row_count(0),
    ( Options.include_data == true ->
        forall(interchange_storage_row(Storage, row(Pairs)),
               ( interchange_row_values(Columns, Pairs, Values),
                 write_csv_fields(Out, Values),
                 arg(1, Counter, Count0),
                 Count is Count0 + 1,
                 nb_setarg(1, Counter, Count)
               ))
    ; true
    ),
    arg(1, Counter, RowCount).

write_csv_fields(Out, Values) :-
    maplist(csv_field, Values, Fields),
    atomic_list_concat(Fields, ',', Line),
    interchange_write_format(Out, '~w~n', [Line]).

csv_field(null, '') :- !.
csv_field(Value, Field) :-
    interchange_scalar_atom(Value, Atom),
    ( sub_atom(Atom, _, _, _, ',')
    ; sub_atom(Atom, _, _, _, '"')
    ; sub_atom(Atom, _, _, _, '\n')
    ; sub_atom(Atom, _, _, _, '\r')
    ), !,
    atomic_list_concat(Parts, '"', Atom),
    atomic_list_concat(Parts, '""', Escaped),
    atomic_list_concat(['"', Escaped, '"'], Field).
csv_field(Value, Field) :-
    interchange_scalar_atom(Value, Field).

/* -------------------------------------------------------------------------
   XLSX export
   ------------------------------------------------------------------------- */

interchange_write_xlsx(_Database, Tables, Options, File,
                       TableCount, RowCount) :-
    temporary_interchange_file(binary, File),
    length(Tables, TableCount),
    xlsx_sheet_specs(Tables, 1, [], Sheets),
    zip_open(File, write, Zipper, []),
    setup_call_cleanup(
        true,
        once(xlsx_write_archive(
            Zipper, Sheets, Options, 0, RowCount)),
        zip_close(Zipper)
    ).

xlsx_sheet_specs([], _, _, []).
xlsx_sheet_specs([Table|Tables], Index, Seen,
                 [sheet(Index, SheetName, Table)|Sheets]) :-
    interchange_table_parts(Table, Name, _, _, _),
    xlsx_sheet_name(Name, Index, Seen, SheetName),
    Next is Index + 1,
    xlsx_sheet_specs(Tables, Next, [SheetName|Seen], Sheets).

xlsx_sheet_name(Name0, Index, Seen, SheetName) :-
    interchange_name_atom(Name0, Name),
    atom_codes(Name, Codes0),
    maplist(xlsx_sheet_code, Codes0, Codes1),
    take_prefix(25, Codes1, Prefix),
    atom_codes(Base0, Prefix),
    ( Base0 == '' -> format(atom(Base), 'Sheet~w', [Index]) ; Base = Base0 ),
    xlsx_unique_sheet_name(Base, Index, Seen, SheetName).

xlsx_unique_sheet_name(Base, _, Seen, Base) :-
    \+ memberchk(Base, Seen), !.
xlsx_unique_sheet_name(Base, Index, _, Name) :-
    format(atom(Name), '~w_~w', [Base, Index]).

xlsx_sheet_code(Code, 95) :- memberchk(Code, [47,92,63,42,91,93,58]), !.
xlsx_sheet_code(Code, Code).

xlsx_write_archive(Zipper, Sheets, Options, RowCount0, RowCount) :-
    xlsx_content_types(Sheets, ContentTypes),
    xlsx_workbook(Sheets, Workbook),
    xlsx_workbook_relationships(Sheets, WorkbookRels),
    xlsx_root_relationships(RootRels),
    xlsx_write_entry(Zipper, '[Content_Types].xml', ContentTypes),
    xlsx_write_entry(Zipper, '_rels/.rels', RootRels),
    xlsx_write_entry(Zipper, 'xl/workbook.xml', Workbook),
    xlsx_write_entry(Zipper, 'xl/_rels/workbook.xml.rels', WorkbookRels),
    xlsx_write_sheet_entries(Zipper, Sheets, Options, RowCount0, RowCount).

xlsx_write_entry(Zipper, Name, Text) :-
    zipper_open_new_file_in_zip(Zipper, Name, Out,
                                [type(text), encoding(utf8),
                                 method(deflated), level(6), zip64(true)]),
    setup_call_cleanup(
        true,
        once(interchange_write_format(Out, '~s', [Text])),
        close(Out)
    ).

xlsx_write_sheet_entries(_, [], _, RowCount, RowCount).
xlsx_write_sheet_entries(Zipper, [sheet(Index, _, Table)|Sheets], Options,
                         RowCount0, RowCount) :-
    format(atom(Name), 'xl/worksheets/sheet~w.xml', [Index]),
    interchange_table_parts(Table, TableName, _, _, _),
    interchange_table_options(Options, TableName, TableOptions),
    zipper_open_new_file_in_zip(Zipper, Name, Out,
                                [type(text), encoding(utf8),
                                 method(deflated), level(6), zip64(true)]),
    setup_call_cleanup(
        true,
        once(xlsx_write_worksheet(
            Out, Table, TableOptions, Rows)),
        close(Out)
    ),
    RowCount1 is RowCount0 + Rows,
    xlsx_write_sheet_entries(Zipper, Sheets, Options, RowCount1, RowCount).

xlsx_content_types(Sheets, Text) :-
    findall(Override,
            ( member(sheet(Index, _, _), Sheets),
              format(string(Override),
                     '<Override PartName="/xl/worksheets/sheet~w.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
                     [Index])
            ),
            Overrides),
    atomics_to_string(Overrides, '', OverrideText),
    format(string(Text),
           '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>~s</Types>',
           [OverrideText]).

xlsx_root_relationships(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>').

xlsx_workbook(Sheets, Text) :-
    findall(SheetXML,
            ( member(sheet(Index, Name, _), Sheets),
              xml_escape(Name, Escaped),
              format(string(SheetXML),
                     '<sheet name="~s" sheetId="~w" r:id="rId~w"/>',
                     [Escaped, Index, Index])
            ),
            SheetXMLs),
    atomics_to_string(SheetXMLs, '', SheetText),
    format(string(Text),
           '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>~s</sheets></workbook>',
           [SheetText]).

xlsx_workbook_relationships(Sheets, Text) :-
    findall(RelXML,
            ( member(sheet(Index, _, _), Sheets),
              format(string(RelXML),
                     '<Relationship Id="rId~w" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet~w.xml"/>',
                     [Index, Index])
            ),
            RelXMLs),
    atomics_to_string(RelXMLs, '', RelText),
    format(string(Text),
           '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">~s</Relationships>',
           [RelText]).

xlsx_write_worksheet(Out, Table, Options, RowCount) :-
    interchange_table_parts(Table, _, Columns, Storage, _),
    interchange_write_format(
        Out,
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
        []),
    RowIndex0 = 1,
    ( Options.include_schema == true ->
        interchange_column_names(Columns, Names),
        xlsx_write_row(Out, RowIndex0, Names),
        RowIndex = 2
    ; RowIndex = RowIndex0
    ),
    Counter = xlsx_counter(RowIndex, 0),
    ( Options.include_data == true ->
        forall(interchange_storage_row(Storage, row(Pairs)),
               ( arg(1, Counter, CurrentRow),
                 interchange_row_values(Columns, Pairs, Values),
                 xlsx_write_row(Out, CurrentRow, Values),
                 NextRow is CurrentRow + 1,
                 arg(2, Counter, Count0),
                 Count is Count0 + 1,
                 nb_setarg(1, Counter, NextRow),
                 nb_setarg(2, Counter, Count)
               ))
    ; true
    ),
    interchange_write_format(Out, '</sheetData></worksheet>', []),
    arg(2, Counter, RowCount).

xlsx_write_row(Out, RowIndex, Values) :-
    interchange_write_format(Out, '<row r="~w">', [RowIndex]),
    xlsx_write_cells(Out, Values, RowIndex, 1),
    interchange_write_format(Out, '</row>', []).

xlsx_write_cells(_, [], _, _).
xlsx_write_cells(Out, [Value|Values], Row, Column) :-
    xlsx_column_name(Column, ColumnName),
    ( number(Value) ->
        interchange_write_format(
            Out, '<c r="~w~w"><v>~w</v></c>',
            [ColumnName, Row, Value])
    ; Value == null ->
        true
    ; interchange_scalar_atom(Value, Atom),
      xml_escape(Atom, Escaped),
      interchange_write_format(
          Out,
          '<c r="~w~w" t="inlineStr"><is><t xml:space="preserve">~s</t></is></c>',
          [ColumnName, Row, Escaped])
    ),
    Next is Column + 1,
    xlsx_write_cells(Out, Values, Row, Next).

/* libarchive exposes ZIP members as octet streams even when text stream
   options are requested.  Encode each bounded fragment explicitly so XLSX
   and zipped CSV preserve non-ASCII data without buffering whole tables. */
interchange_write_format(Out, Template, Arguments) :-
    format(string(Text), Template, Arguments),
    ( stream_property(Out, encoding(octet)) ->
        string_codes(Text, Unicode),
        utf8_encode_codes(Unicode, Bytes),
        % `format/3` writes an octet list in one buffered stream operation.
        % Calling put_byte/2 through maplist for every UTF-8 byte dominated
        % large XLSX/ZIP exports despite the rows themselves being streamed.
        format(Out, '~s', [Bytes])
    ; format(Out, '~s', [Text])
    ).

utf8_encode_codes([], []).
utf8_encode_codes([Code|Codes], Bytes) :-
    utf8_encode_code(Code, Head),
    append(Head, Rest, Bytes),
    utf8_encode_codes(Codes, Rest).

utf8_encode_code(Code, [Code]) :-
    Code >= 0, Code =< 16'7f, !.
utf8_encode_code(Code, [B1,B2]) :-
    Code =< 16'7ff, !,
    B1 is 16'c0 \/ (Code >> 6),
    B2 is 16'80 \/ (Code /\ 16'3f).
utf8_encode_code(Code, [B1,B2,B3]) :-
    Code =< 16'ffff, !,
    B1 is 16'e0 \/ (Code >> 12),
    B2 is 16'80 \/ ((Code >> 6) /\ 16'3f),
    B3 is 16'80 \/ (Code /\ 16'3f).
utf8_encode_code(Code, [B1,B2,B3,B4]) :-
    Code =< 16'10ffff,
    B1 is 16'f0 \/ (Code >> 18),
    B2 is 16'80 \/ ((Code >> 12) /\ 16'3f),
    B3 is 16'80 \/ ((Code >> 6) /\ 16'3f),
    B4 is 16'80 \/ (Code /\ 16'3f).

/* -------------------------------------------------------------------------
   Import dispatch
   ------------------------------------------------------------------------- */

interchange_prepare_import(asadb, File, _, _, _, File,
                           interchange{format:asadb,temporary:false}) :- !.
interchange_prepare_import(mysql, File, Name, _, _, Prepared, Metadata) :- !,
    temporary_interchange_file(text, Prepared),
    setup_call_cleanup(
        open(File, read, In, [encoding(utf8)]),
        setup_call_cleanup(
            open(Prepared, write, Out, [encoding(utf8), newline(posix)]),
            once(convert_sql_stream(mysql, In, Out, Stats)),
            close(Out)
        ),
        close(In)
    ),
    Metadata = Stats.put(_{format:mysql,source_name:Name,temporary:true}).
interchange_prepare_import(postgresql, File, Name, _, _, Prepared,
                           Metadata) :- !,
    temporary_interchange_file(text, Prepared),
    setup_call_cleanup(
        open(File, read, In, [encoding(utf8)]),
        setup_call_cleanup(
            open(Prepared, write, Out, [encoding(utf8), newline(posix)]),
            once(convert_sql_stream(postgresql, In, Out, Stats)),
            close(Out)
        ),
        close(In)
    ),
    Metadata = Stats.put(_{format:postgresql,source_name:Name,temporary:true}).
interchange_prepare_import(csv, File, Name, Target, Mode, Prepared,
                           Metadata) :- !,
    temporary_interchange_file(text, Prepared),
    setup_call_cleanup(
        open(Prepared, write, Out, [encoding(utf8), newline(posix)]),
        once(csv_file_to_asadb_sql(
            File, Name, Out, Target, Mode,
            Tables, Rows, Columns)),
        close(Out)
    ),
    Metadata = interchange{
        format:csv,source_name:Name,target_table:Target,mode:Mode,
        tables:Tables,rows:Rows,columns:Columns,temporary:true
    }.
interchange_prepare_import(xlsx, File, Name, Target, Mode, Prepared,
                           Metadata) :- !,
    temporary_interchange_file(text, Prepared),
    setup_call_cleanup(
        open(Prepared, write, Out, [encoding(utf8), newline(posix)]),
        once(xlsx_to_asadb_sql(
            File, Out, Target, Mode, Sheets, Rows)),
        close(Out)
    ),
    Metadata = interchange{
        format:xlsx,source_name:Name,target_table:Target,mode:Mode,
        sheets:Sheets,rows:Rows,temporary:true
    }.

/* -------------------------------------------------------------------------
   CSV import
   ------------------------------------------------------------------------- */

csv_file_to_asadb_sql(File, Name, Out, Target, Mode,
                      Tables, Rows, Columns) :-
    csv_zip_candidate(File, Name), !,
    validate_interchange_archive(File),
    zip_open(File, read, Zipper, []),
    setup_call_cleanup(
        true,
        once(csv_zip_to_asadb_sql(
            Zipper, Out, Target, Mode, Tables, Rows)),
        zip_close(Zipper)
    ),
    Columns = 0.
csv_file_to_asadb_sql(File, _, Out, Target, Mode, 1, Rows, Columns) :-
    setup_call_cleanup(
        open(File, read, In, [encoding(utf8), bom(true)]),
        once(csv_to_asadb_sql(
            In, Out, Target, Mode, Rows, Columns)),
        close(In)
    ).

csv_zip_candidate(File, Name0) :-
    interchange_name_atom(Name0, Name),
    downcase_atom(Name, Lower),
    sub_atom(Lower, _, 4, 0, '.zip'),
    setup_call_cleanup(
        open(File, read, In, [type(binary)]),
        ( get_byte(In, 16'50), get_byte(In, 16'4b) ),
        close(In)
    ).

csv_zip_to_asadb_sql(Zipper, Out, Target, Mode, TableCount, RowCount) :-
    zipper_goto(Zipper, first),
    csv_import_zip_cursor(Zipper, Out, Target, Mode,
                          0, TableCount, 0, RowCount),
    TableCount > 0.

csv_zip_member(Name) :-
    downcase_atom(Name, Lower),
    sub_atom(Lower, _, 4, 0, '.csv').

csv_import_zip_cursor(Zipper, Out, Target, Mode,
                      TableCount0, TableCount, RowCount0, RowCount) :-
    zipper_file_info(Zipper, Entry, _),
    ( csv_zip_member(Entry) ->
        csv_import_table_name(Target, Entry, TableCount0, Table),
        zipper_open_current(Zipper, In, [type(text), encoding(utf8)]),
        setup_call_cleanup(
            true,
            once(csv_to_asadb_sql(In, Out, Table, Mode, Rows, _)),
            close(In)
        ),
        TableCount1 is TableCount0 + 1,
        RowCount1 is RowCount0 + Rows
    ; TableCount1 = TableCount0,
      RowCount1 = RowCount0
    ),
    ( zipper_goto(Zipper, next) ->
        csv_import_zip_cursor(Zipper, Out, Target, Mode,
                              TableCount1, TableCount,
                              RowCount1, RowCount)
    ; TableCount = TableCount1,
      RowCount = RowCount1
    ).

csv_import_table_name(Target, _, 0, Target) :- !.
csv_import_table_name(Target, Entry, _, Table) :-
    file_base_name(Entry, Base),
    file_name_extension(Stem, _, Base),
    sanitize_identifier(Stem, Suffix),
    format(atom(Table), '~w_~w', [Target, Suffix]).

csv_to_asadb_sql(In, Out, Target, Mode, RowCount, ColumnCount) :-
    csv_options(CSVOptions,
                [functor(row), convert(false), strip(false),
                 match_arity(false)]),
    csv_read_row(In, HeaderRow, CSVOptions),
    ( HeaderRow == end_of_file ->
        throw(error(domain_error(csv, empty_file), _))
    ; true
    ),
    HeaderRow =.. [_|Headers0],
    sanitize_headers(Headers0, Headers),
    length(Headers, ColumnCount),
    ColumnCount > 0,
    interchange_csv_sample_rows(SampleRows),
    collect_csv_sample(In, CSVOptions, SampleRows, Sample, Ended),
    infer_csv_types(Sample, ColumnCount, Types),
    write_import_table_prelude(Out, Target, Headers, Types, Mode),
    ImportState = import_batch(Out, Target, Headers, 0, 0),
    maplist(write_import_row(ImportState), Sample),
    ( Ended == true -> true
    ; csv_import_remaining(In, CSVOptions, ImportState)
    ),
    finish_import_batch(ImportState),
    arg(5, ImportState, RowCount).

collect_csv_sample(_, _, 0, [], false) :- !.
collect_csv_sample(In, Options, Limit, Rows, Ended) :-
    csv_read_row(In, Row, Options),
    ( Row == end_of_file ->
        Rows = [],
        Ended = true
    ; Row =.. [_|Values],
      Rows = [Values|Rest],
      Next is Limit - 1,
      collect_csv_sample(In, Options, Next, Rest, Ended)
    ).

csv_import_remaining(In, Options, State) :-
    csv_read_row(In, Row, Options),
    ( Row == end_of_file -> true
    ; Row =.. [_|Values],
      write_import_row(State, Values),
      csv_import_remaining(In, Options, State)
    ).

infer_csv_types(Rows, ColumnCount, Types) :-
    numlist(1, ColumnCount, Positions),
    maplist(infer_csv_column(Rows), Positions, Types).

infer_csv_column(Rows, Position, Type) :-
    findall(Value,
            ( member(Row, Rows),
              row_value_at(Row, Position, Raw),
              normalize_import_scalar(Raw, Value),
              Value \== null
            ),
            Values),
    ( Values \= [], maplist(integer, Values) -> Type = 'BIGINT'
    ; Values \= [], maplist(number, Values) -> Type = 'DOUBLE'
    ; Type = 'TEXT'
    ).

row_value_at(Row, Position, Value) :-
    ( nth1(Position, Row, Found) -> Value = Found ; Value = '' ).

/* -------------------------------------------------------------------------
   SQL dialect import
   ------------------------------------------------------------------------- */

convert_sql_stream(Dialect, In, Out,
                   interchange{lines:Lines,copy_rows:CopyRows}) :-
    SQLState = sql_convert_state(0, 0, false),
    convert_sql_lines(Dialect, In, Out, SQLState),
    arg(1, SQLState, Lines),
    arg(2, SQLState, CopyRows).

convert_sql_lines(Dialect, In, Out, State) :-
    read_line_to_string(In, Line),
    ( Line == end_of_file -> true
    ; arg(1, State, Lines0),
      Lines is Lines0 + 1,
      nb_setarg(1, State, Lines),
      ( Dialect == postgresql,
        postgres_copy_header(Line, Table, Columns) ->
          postgres_copy_to_insert(In, Out, Table, Columns, State)
      ; convert_sql_line_state(Dialect, Line, State, Converted),
        ( Converted == skip -> true ; format(Out, '~s~n', [Converted]) )
      ),
      convert_sql_lines(Dialect, In, Out, State)
    ).

convert_sql_line(_, Line, skip) :-
    sql_line_upper(Line, Upper),
    sql_line_starts_any(Upper,
                        ["SET ", "LOCK TABLES", "UNLOCK TABLES", "DELIMITER",
                         "START TRANSACTION", "BEGIN", "COMMIT", "ROLLBACK",
                         "ANALYZE"]), !.
convert_sql_line(postgresql, Line, skip) :-
    sql_line_upper(Line, Upper),
    sql_line_starts_any(Upper,
                        ["SELECT PG_CATALOG", "CREATE EXTENSION",
                         "COMMENT ON", "\\CONNECT", "\\RESTRICT",
                         "\\UNRESTRICT"]), !.
convert_sql_line(postgresql, Line, skip) :-
    sql_line_upper(Line, Upper),
    sql_line_starts_any(Upper, ["ALTER "]),
    sub_string(Upper, _, _, _, " OWNER TO "), !.
convert_sql_line(_, Line, skip) :-
    sql_line_upper(Line, Upper),
    sub_string(Upper, 0, 3, _, "/*!"),
    sub_string(Upper, _, 2, _, "*/"), !.
% A mysqldump normally writes one VALUES tuple per physical line.  Dialect
% rewrites affect statement/schema tokens, not a MySQL tuple's quoted data.
% Passing these continuation lines through avoids repeatedly splitting and
% rescanning hundreds of thousands of values before Reservoir progress starts.
convert_sql_line(Dialect, Line, Converted) :-
    normalize_sql_dialect_line(Dialect, Line, Converted).

convert_sql_line_state(mysql, Line, State, Line) :-
    arg(3, State, true),
    mysql_values_tuple_line(Line), !,
    update_mysql_values_state(Line, State).
convert_sql_line_state(Dialect, Line, State, Converted) :-
    convert_sql_line(Dialect, Line, Converted),
    update_sql_values_state(Dialect, Line, State).

update_sql_values_state(mysql, Line, State) :- !,
    arg(3, State, Current),
    sql_line_upper(Line, Upper),
    ( Current == true -> InValues = true
    ; Current == pending,
      sub_string(Upper, _, _, _, "VALUES") -> InValues = true
    ; Current == pending -> InValues = pending
    ; sql_line_starts_any(Upper, ["INSERT "]) ->
        ( sub_string(Upper, _, _, _, "VALUES") -> InValues = true
        ; InValues = pending
        )
    ; InValues = false
    ),
    nb_setarg(3, State, InValues),
    update_mysql_values_state(Line, State).
update_sql_values_state(_, _, _).

update_mysql_values_state(Line, State) :-
    ( mysql_line_terminates_statement(Line) -> nb_setarg(3, State, false)
    ; true
    ).

mysql_line_terminates_statement(Line) :-
    string_codes(Line, Codes0),
    reverse(Codes0, Reverse0),
    drop_sql_horizontal_space(Reverse0, [59|_]).

mysql_values_tuple_line(Line) :-
    string_codes(Line, Codes),
    drop_sql_horizontal_space(Codes, [40|_]).

drop_sql_horizontal_space([Code|Codes], Rest) :-
    memberchk(Code, [9,32]), !,
    drop_sql_horizontal_space(Codes, Rest).
drop_sql_horizontal_space(Codes, Codes).

normalize_sql_dialect_line(Dialect, Line0, Line) :-
    transform_sql_unquoted(Line0, Line7),
    strip_mysql_table_options(Line7, Line8),
    strip_on_conflict(Line8, Line9),
    normalize_schema_line(Dialect, Line9, Line).

transform_sql_unquoted(Input, Output) :-
    string_codes(Input, Codes),
    transform_sql_unquoted_codes(Codes, OutputCodes),
    string_codes(Output, OutputCodes).

transform_sql_unquoted_codes([], []).
transform_sql_unquoted_codes(Codes, Output) :-
    take_until_sql_quote(Codes, PlainCodes, Rest),
    string_codes(Plain, PlainCodes),
    normalize_unquoted_sql(Plain, Normalized),
    string_codes(Normalized, NormalizedCodes),
    append(NormalizedCodes, Tail, Output),
    ( Rest = [Quote|QuotedRest] ->
        take_sql_quoted(QuotedRest, Quote, QuotedCodes, After),
        Tail = [Quote|QuotedTail],
        append(QuotedCodes, Next, QuotedTail),
        transform_sql_unquoted_codes(After, Next)
    ; Tail = []
    ).

normalize_unquoted_sql(Line0, Line) :-
    replace_all_ci(Line0, "public.", "", Line1),
    replace_all_ci(Line1, "dbo.", "", Line2),
    strip_postgresql_casts(Line2, Line3),
    replace_word_ci(Line3, "BIGSERIAL", "BIGINT AUTO_INCREMENT", Line4),
    replace_word_ci(Line4, "SERIAL", "INT AUTO_INCREMENT", Line5),
    replace_word_ci(Line5, "BYTEA", "TEXT", Line6),
    replace_word_ci(Line6, "BOOLEAN", "INT", Line).

take_until_sql_quote([], [], []).
take_until_sql_quote([Code|Codes], [], [Code|Codes]) :-
    memberchk(Code, [39,34,96]), !.
take_until_sql_quote([Code|Codes], [Code|Plain], Rest) :-
    take_until_sql_quote(Codes, Plain, Rest).

take_sql_quoted([], _, [], []).
take_sql_quoted([92,Code|Codes], Quote, [92,Code|Quoted], Rest) :- !,
    take_sql_quoted(Codes, Quote, Quoted, Rest).
take_sql_quoted([Quote,Quote|Codes], Quote,
                [Quote,Quote|Quoted], Rest) :- !,
    take_sql_quoted(Codes, Quote, Quoted, Rest).
take_sql_quoted([Quote|Codes], Quote, [Quote], Codes) :- !.
take_sql_quoted([Code|Codes], Quote, [Code|Quoted], Rest) :-
    take_sql_quoted(Codes, Quote, Quoted, Rest).

normalize_schema_line(postgresql, Line0, Line) :-
    sql_line_upper(Line0, Upper),
    sub_string(Upper, 0, 14, _, "CREATE SCHEMA "),
    split_string(Line0, " \t;", " \t;", Tokens),
    last(Tokens, Name0),
    interchange_unquote_qualified_identifier(Name0, Name),
    format(string(Line), 'CREATE DATABASE `~w`; USE `~w`;', [Name, Name]).
normalize_schema_line(_, Line, Line).

postgres_copy_header(Line, Table, Columns) :-
    sql_line_upper(Line, Upper),
    sub_string(Upper, 0, 5, _, "COPY "),
    sub_string(Upper, FromStart, _, _, ") FROM STDIN"),
    sub_string(Line, 5, _, _, AfterCopy),
    sub_string(AfterCopy, Open, 1, _, "("),
    sub_string(AfterCopy, 0, Open, _, TableText),
    ColumnStart is Open + 1,
    ColumnLength is FromStart - 5 - ColumnStart,
    ColumnLength >= 0,
    sub_string(AfterCopy, ColumnStart, ColumnLength, _, ColumnText),
    interchange_unquote_qualified_identifier(TableText, Table),
    split_string(ColumnText, ",", " \t\"`", ColumnStrings),
    maplist(atom_string, Columns, ColumnStrings).

sql_line_upper(Line0, Upper) :-
    normalize_space(string(Line), Line0),
    string_upper(Line, Upper).

sql_line_starts_any(Line, [Prefix|_]) :-
    sub_string(Line, 0, Length, _, Prefix),
    sql_prefix_boundary(Prefix, Line, Length), !.
sql_line_starts_any(Line, [_|Prefixes]) :-
    sql_line_starts_any(Line, Prefixes).

sql_prefix_boundary(Prefix, _, _) :-
    string_codes(Prefix, Codes),
    last(Codes, Last),
    memberchk(Last, [9,32,92]), !.
sql_prefix_boundary(_, Line, Length) :-
    string_length(Line, Length), !.
sql_prefix_boundary(_, Line, Length) :-
    sub_string(Line, Length, 1, _, Next),
    string_codes(Next, [Code]),
    \+ sql_word_code(Code).

replace_all_ci(Input0, Search0, Replacement0, Output) :-
    string_lower(Input0, Lower),
    string_lower(Search0, Search),
    ( sub_string(Lower, Before, _, After, Search) ->
        sub_string(Input0, 0, Before, _, Left),
        string_length(Search, SearchLength),
        Start is Before + SearchLength,
        sub_string(Input0, Start, After, 0, Right),
        string_concat(Left, Replacement0, Prefix),
        replace_all_ci(Right, Search0, Replacement0, Suffix),
        string_concat(Prefix, Suffix, Output)
    ; Output = Input0
    ).

replace_word_ci(Input, Search, Replacement, Output) :-
    string_codes(Input, Codes),
    string_lower(Search, SearchLower),
    string_codes(Replacement, ReplacementCodes),
    replace_word_codes(Codes, SearchLower, ReplacementCodes, OutputCodes),
    string_codes(Output, OutputCodes).

replace_word_codes([], _, _, []).
replace_word_codes([Code|Codes], Search, Replacement, Output) :-
    sql_word_code(Code), !,
    take_sql_word([Code|Codes], WordCodes, Rest),
    string_codes(Word, WordCodes),
    string_lower(Word, Lower),
    ( Lower == Search ->
        append(Replacement, Tail, Output)
    ; append(WordCodes, Tail, Output)
    ),
    replace_word_codes(Rest, Search, Replacement, Tail).
replace_word_codes([Code|Codes], Search, Replacement, [Code|Output]) :-
    replace_word_codes(Codes, Search, Replacement, Output).

take_sql_word([Code|Codes], [Code|Word], Rest) :-
    sql_word_code(Code), !,
    take_sql_word(Codes, Word, Rest).
take_sql_word(Rest, [], Rest).

sql_word_code(Code) :-
    code_type(Code, alnum), !.
sql_word_code(95).

strip_postgresql_casts(Input, Output) :-
    string_codes(Input, Codes),
    strip_postgresql_cast_codes(Codes, Stripped),
    string_codes(Output, Stripped).

strip_postgresql_cast_codes([], []).
strip_postgresql_cast_codes([58,58|Codes], Output) :- !,
    skip_sql_type_codes(Codes, Rest),
    strip_postgresql_cast_codes(Rest, Output).
strip_postgresql_cast_codes([Code|Codes], [Code|Output]) :-
    strip_postgresql_cast_codes(Codes, Output).

skip_sql_type_codes([Code|Codes], Rest) :-
    sql_type_code(Code), !,
    skip_sql_type_codes(Codes, Rest).
skip_sql_type_codes([40|Codes], Rest) :- !,
    skip_sql_type_precision(Codes, 1, Rest).
skip_sql_type_codes(Rest, Rest).

skip_sql_type_precision([], _, []).
skip_sql_type_precision([40|Codes], Depth0, Rest) :- !,
    Depth is Depth0 + 1,
    skip_sql_type_precision(Codes, Depth, Rest).
skip_sql_type_precision([41|Codes], 1, Codes) :- !.
skip_sql_type_precision([41|Codes], Depth0, Rest) :- !,
    Depth is Depth0 - 1,
    skip_sql_type_precision(Codes, Depth, Rest).
skip_sql_type_precision([_|Codes], Depth, Rest) :-
    skip_sql_type_precision(Codes, Depth, Rest).

sql_type_code(Code) :-
    code_type(Code, alnum), !.
sql_type_code(95).
sql_type_code(91).
sql_type_code(93).

strip_mysql_table_options(Input, Output) :-
    sql_line_upper(Input, Upper),
    ( sub_string(Upper, 0, _, _, "CREATE TABLE")
    ; sub_string(Upper, 0, 1, _, ")")
    ),
    ( sub_string(Upper, Start, _, _, ") ENGINE")
    ; sub_string(Upper, Start, _, _, ") DEFAULT CHARSET")
    ; sub_string(Upper, Start, _, _, ") CHARSET")
    ; sub_string(Upper, Start, _, _, ") COLLATE")
    ), !,
    Length is Start + 1,
    sub_string(Input, 0, Length, _, Prefix),
    string_concat(Prefix, ";", Output).
strip_mysql_table_options(Input, Input).

strip_on_conflict(Input, Output) :-
    string_upper(Input, Upper),
    normalize_space(string(TrimmedUpper), Upper),
    sub_string(TrimmedUpper, 0, 7, _, "INSERT "),
    sub_string(Upper, Start, _, _, " ON CONFLICT"), !,
    sub_string(Input, 0, Start, _, Prefix),
    string_concat(Prefix, ";", Output).
strip_on_conflict(Input, Input).

postgres_copy_to_insert(In, Out, Table, Columns, State) :-
    ImportState = import_batch(Out, Table, Columns, 0, 0),
    postgres_copy_rows(In, ImportState, State),
    finish_import_batch(ImportState).

postgres_copy_rows(In, ImportState, State) :-
    read_line_to_string(In, Line),
    ( Line == end_of_file ->
        throw(error(syntax_error(unterminated_postgresql_copy), _))
    ; Line == "\\." ->
        true
    ; split_string(Line, "\t", "", Fields0),
      maplist(postgres_copy_import_value, Fields0, Fields),
      write_import_row(ImportState, Fields),
      arg(2, State, Rows0),
      Rows is Rows0 + 1,
      nb_setarg(2, State, Rows),
      postgres_copy_rows(In, ImportState, State)
    ).

postgres_copy_import_value("\\N", null) :- !.
postgres_copy_import_value(Text, Value) :-
    string_codes(Text, Codes),
    postgres_copy_unescape(Codes, Decoded),
    string_codes(String, Decoded),
    normalize_import_scalar(String, Value).

postgres_copy_unescape([], []).
postgres_copy_unescape([92,116|Codes], [9|Decoded]) :- !,
    postgres_copy_unescape(Codes, Decoded).
postgres_copy_unescape([92,110|Codes], [10|Decoded]) :- !,
    postgres_copy_unescape(Codes, Decoded).
postgres_copy_unescape([92,114|Codes], [13|Decoded]) :- !,
    postgres_copy_unescape(Codes, Decoded).
postgres_copy_unescape([92,92|Codes], [92|Decoded]) :- !,
    postgres_copy_unescape(Codes, Decoded).
postgres_copy_unescape([Code|Codes], [Code|Decoded]) :-
    postgres_copy_unescape(Codes, Decoded).

/* -------------------------------------------------------------------------
   XLSX import
   ------------------------------------------------------------------------- */

xlsx_to_asadb_sql(File, Out, Target, Mode, SheetCount, RowCount) :-
    validate_interchange_archive(File),
    zip_open(File, read, Zipper, []),
    setup_call_cleanup(
        true,
        once(xlsx_import_zip(
            Zipper, Out, Target, Mode, SheetCount, RowCount)),
        zip_close(Zipper)
    ).

xlsx_import_zip(Zipper, Out, Target, Mode, SheetCount, RowCount) :-
    xlsx_read_dom_entry(Zipper, 'xl/workbook.xml', WorkbookDOM),
    xlsx_read_dom_entry(Zipper, 'xl/_rels/workbook.xml.rels', RelsDOM),
    xlsx_workbook_specs(WorkbookDOM, RelsDOM, Specs),
    Specs \= [],
    xlsx_shared_strings(Zipper, SharedStrings),
    xlsx_import_sheets(Zipper, Specs, SharedStrings, Out, Target, Mode,
                       0, SheetCount, 0, RowCount).

validate_interchange_archive(File) :-
    zip_open(File, read, Zipper, []),
    setup_call_cleanup(
        true,
        once(validate_archive_cursor(Zipper)),
        zip_close(Zipper)
    ).

validate_archive_cursor(Zipper) :-
    zipper_goto(Zipper, first),
    validate_archive_entries(Zipper, 0, 0).

validate_archive_entries(Zipper, EntryCount0, Total0) :-
    zipper_file_info(Zipper, Name, Info),
    EntryCount is EntryCount0 + 1,
    interchange_archive_max_entries(MaxEntries),
    ( EntryCount =< MaxEntries -> true
    ; throw(error(resource_error(xlsx_archive_entries), _))
    ),
    safe_zip_member(Name),
    Size = Info.uncompressed_size,
    interchange_archive_max_entry_bytes(MaxEntry),
    ( Size =< MaxEntry -> true
    ; throw(error(resource_error(xlsx_entry_size(Name)), _))
    ),
    Total1 is Total0 + Size,
    interchange_archive_max_uncompressed_bytes(MaxTotal),
    ( Total1 =< MaxTotal -> true
    ; throw(error(resource_error(xlsx_uncompressed_size), _))
    ),
    validate_xlsx_xml_member(Zipper, Name),
    ( zipper_goto(Zipper, next) ->
        validate_archive_entries(Zipper, EntryCount, Total1)
    ; true
    ).

validate_xlsx_xml_member(Zipper, Name) :-
    downcase_atom(Name, Lower),
    ( sub_atom(Lower, _, 4, 0, '.xml')
    ; sub_atom(Lower, _, 5, 0, '.rels')
    ), !,
    zipper_open_current(Zipper, In, [type(text), encoding(utf8)]),
    setup_call_cleanup(
        true,
        once(read_string(In, 65536, Prefix)),
        close(In)
    ),
    string_upper(Prefix, Upper),
    ( ( sub_string(Upper, _, _, _, "<!DOCTYPE")
      ; sub_string(Upper, _, _, _, "<!ENTITY")
      ) ->
        throw(error(permission_error(parse, xlsx_xml_dtd, Name), _))
    ; true
    ).
validate_xlsx_xml_member(_, _).

safe_zip_member(Name) :-
    \+ sub_atom(Name, 0, 1, _, '/'),
    \+ sub_atom(Name, _, _, _, '..'),
    \+ sub_atom(Name, _, _, _, '\\'), !.
safe_zip_member(Name) :-
    throw(error(permission_error(read, xlsx_entry, Name), _)).

xlsx_read_dom_entry(Zipper, Name, DOM) :-
    ( zipper_goto(Zipper, file(Name)) -> true
    ; throw(error(existence_error(xlsx_entry, Name), _))
    ),
    zipper_open_current(Zipper, In, [type(text), encoding(utf8)]),
    setup_call_cleanup(
        true,
        once(load_structure(
            In, DOM, [dialect(xml), space(remove)])),
        close(In)
    ).

xlsx_workbook_specs(WorkbookDOM, RelsDOM, Specs) :-
    findall(Id-Target,
            ( dom_element_named(RelsDOM, 'Relationship',
                                element(_, Attrs, _)),
              dom_attribute(Attrs, 'Id', Id),
              dom_attribute(Attrs, 'Target', Target0),
              xlsx_relationship_target(Target0, Target)
            ),
            Relations),
    findall(sheet(Name, Target),
            ( dom_element_named(WorkbookDOM, sheet,
                                element(_, Attrs, _)),
              dom_attribute(Attrs, name, Name),
              dom_attribute(Attrs, 'r:id', RelId),
              memberchk(RelId-Target, Relations)
            ),
            Specs).

xlsx_relationship_target(Target0, Target) :-
    interchange_name_atom(Target0, TargetAtom),
    ( sub_atom(TargetAtom, 0, 1, _, '/') ->
        sub_atom(TargetAtom, 1, _, 0, Target)
    ; sub_atom(TargetAtom, 0, 3, _, 'xl/') ->
        Target = TargetAtom
    ; atomic_list_concat(['xl', TargetAtom], '/', Target)
    ).

xlsx_shared_strings(Zipper, Strings) :-
    ( zipper_goto(Zipper, file('xl/sharedStrings.xml')) ->
        zipper_open_current(Zipper, In, [type(text), encoding(utf8)]),
        setup_call_cleanup(
            true,
            once(load_structure(
                In, DOM, [dialect(xml), space(preserve)])),
            close(In)
        ),
        findall(Text,
                ( dom_element_named(DOM, si, Element),
                  dom_text_content(Element, Text)
                ),
                Strings)
    ; Strings = []
    ).

xlsx_import_sheets(_, [], _, _, _, _, SheetCount, SheetCount,
                   RowCount, RowCount).
xlsx_import_sheets(Zipper, [sheet(SheetName, Entry)|Sheets], Shared,
                   Out, Target, Mode,
                   SheetCount0, SheetCount, RowCount0, RowCount) :-
    xlsx_import_table_name(Target, SheetName, SheetCount0, Table),
    xlsx_import_sheet(Zipper, Entry, Shared, Out, Table, Mode, Rows),
    SheetCount1 is SheetCount0 + 1,
    RowCount1 is RowCount0 + Rows,
    xlsx_import_sheets(Zipper, Sheets, Shared, Out, Target, Mode,
                       SheetCount1, SheetCount, RowCount1, RowCount).

xlsx_import_table_name(Target, _, 0, Target) :- !.
xlsx_import_table_name(Target, SheetName, _, Table) :-
    sanitize_identifier(SheetName, Sheet),
    format(atom(Table), '~w_~w', [Target, Sheet]).

xlsx_import_sheet(Zipper, Entry, Shared, Out, Table, Mode, RowCount) :-
    ( zipper_goto(Zipper, file(Entry)) -> true
    ; throw(error(existence_error(xlsx_entry, Entry), _))
    ),
    zipper_open_current(Zipper, In, [type(text), encoding(utf8)]),
    State = xlsx_import_state(Out, Table, Mode, Shared, none, none, 0,
                              [], 0, false),
    new_sgml_parser(Parser, []),
    set_sgml_parser(Parser, dialect(xml)),
    setup_call_cleanup(
        nb_linkval(asadb_xlsx_import_state, State),
        once((
            sgml_parse(Parser,
                       [source(In),
                        call(begin, xlsx_row_begin)]),
            nb_getval(asadb_xlsx_import_state, ParsedState),
            xlsx_finish_sheet(ParsedState),
            arg(7, ParsedState, RowCount)
        )),
        ( nb_delete(asadb_xlsx_import_state),
          free_sgml_parser(Parser),
          close(In)
        )
    ).

xlsx_row_begin(Element, _, Parser) :-
    dom_local_name(Element, row),
    nb_getval(asadb_xlsx_import_state, State), !,
    sgml_parse(Parser, [document(Content), parse(content)]),
    xlsx_content_values(Content, State, Values),
    xlsx_accept_row(State, Values).
xlsx_row_begin(_, _, _).

xlsx_content_values(Content, State, Values) :-
    findall(Index-Value,
            ( dom_element_named(Content, c, element(_, Attrs, Children)),
              dom_attribute(Attrs, r, CellRef),
              xlsx_cell_column(CellRef, Index),
              xlsx_cell_value(Attrs, Children, State, Value)
            ),
            Pairs),
    pairs_dense_values(Pairs, Values).

xlsx_cell_value(Attrs, Children, _, Value) :-
    dom_attribute(Attrs, t, inlineStr), !,
    dom_text_content(element(cell, [], Children), Text),
    normalize_import_scalar(Text, Value).
xlsx_cell_value(Attrs, Children, State, Value) :-
    dom_attribute(Attrs, t, s), !,
    dom_element_named(Children, v, VElement),
    dom_text_content(VElement, IndexText),
    atom_number(IndexText, ZeroIndex),
    OneIndex is ZeroIndex + 1,
    arg(4, State, Shared),
    nth1(OneIndex, Shared, Text),
    normalize_import_scalar(Text, Value).
xlsx_cell_value(Attrs, Children, _, Value) :-
    dom_attribute(Attrs, t, b), !,
    dom_element_named(Children, v, VElement),
    dom_text_content(VElement, Bool),
    ( Bool == '1' -> Value = 1 ; Value = 0 ).
xlsx_cell_value(_, Children, _, Value) :-
    ( dom_element_named(Children, v, VElement) ->
        dom_text_content(VElement, Text),
        normalize_import_scalar(Text, Value)
    ; Value = null
    ).

xlsx_accept_row(State, Values) :-
    arg(5, State, none), !,
    sanitize_headers(Values, Headers),
    Headers \= [],
    nb_setarg(5, State, Headers).
xlsx_accept_row(State, Values) :-
    arg(7, State, Rows0),
    Rows is Rows0 + 1,
    nb_setarg(7, State, Rows),
    ( arg(10, State, true) ->
        arg(6, State, ImportState),
        write_import_row(ImportState, Values)
    ; arg(8, State, Samples0),
      arg(9, State, SampleCount0),
      SampleCount is SampleCount0 + 1,
      nb_setarg(8, State, [Values|Samples0]),
      nb_setarg(9, State, SampleCount),
      interchange_csv_sample_rows(Limit),
      ( SampleCount >= Limit -> xlsx_start_import(State) ; true )
    ).

xlsx_finish_sheet(State) :-
    ( arg(5, State, none) ->
        throw(error(domain_error(xlsx_sheet, missing_header), _))
    ; ( arg(10, State, true) -> true ; xlsx_start_import(State) ),
      arg(6, State, ImportState),
      finish_import_batch(ImportState)
    ).

xlsx_start_import(State) :-
    arg(5, State, Headers),
    arg(8, State, SamplesRev),
    reverse(SamplesRev, Samples),
    length(Headers, ColumnCount),
    infer_csv_types(Samples, ColumnCount, Types),
    arg(1, State, Out),
    arg(2, State, Table),
    arg(3, State, Mode),
    write_import_table_prelude(Out, Table, Headers, Types, Mode),
    ImportState = import_batch(Out, Table, Headers, 0, 0),
    maplist(write_import_row(ImportState), Samples),
    nb_setarg(6, State, ImportState),
    nb_setarg(8, State, []),
    nb_setarg(10, State, true).

/* -------------------------------------------------------------------------
   Import SQL writer
   ------------------------------------------------------------------------- */

write_import_table_prelude(Out, Table, Headers, Types, replace) :- !,
    sql_identifier(mysql, Table, TableSQL),
    format(Out, 'DROP TABLE IF EXISTS ~w;~n', [TableSQL]),
    write_import_create_table(Out, TableSQL, Headers, Types, false).
write_import_table_prelude(Out, Table, Headers, Types, append) :-
    sql_identifier(mysql, Table, TableSQL),
    write_import_create_table(Out, TableSQL, Headers, Types, true).

write_import_create_table(Out, TableSQL, Headers, Types, IfNotExists) :-
    ( IfNotExists == true -> Conditional = ' IF NOT EXISTS' ; Conditional = '' ),
    format(Out, 'CREATE TABLE~w ~w (~n', [Conditional, TableSQL]),
    write_import_columns(Out, Headers, Types, 0),
    format(Out, '~n);~n', []).

write_import_columns(_, [], [], _).
write_import_columns(Out, [Header|Headers], [Type|Types], Index) :-
    ( Index > 0 -> format(Out, ',~n', []) ; true ),
    sql_identifier(mysql, Header, HeaderSQL),
    format(Out, '  ~w ~w', [HeaderSQL, Type]),
    Next is Index + 1,
    write_import_columns(Out, Headers, Types, Next).

write_import_row(State, Values0) :-
    arg(1, State, Out),
    arg(2, State, Table),
    arg(3, State, Headers),
    length(Headers, Arity),
    normalize_row_arity(Values0, Arity, Values),
    arg(4, State, Batch0),
    ( Batch0 =:= 0 ->
        sql_identifier(mysql, Table, TableSQL),
        maplist(sql_identifier(mysql), Headers, HeaderSQL),
        atomic_list_concat(HeaderSQL, ', ', HeaderText),
        format(Out, 'INSERT INTO ~w (~w) VALUES~n  ', [TableSQL, HeaderText])
    ; format(Out, ',~n  ', [])
    ),
    maplist(normalize_import_scalar, Values, Normalized),
    maplist(sql_value(mysql), Normalized, Literals),
    atomic_list_concat(Literals, ', ', ValueText),
    format(Out, '(~w)', [ValueText]),
    Batch1 is Batch0 + 1,
    arg(5, State, Rows0),
    Rows is Rows0 + 1,
    interchange_insert_batch_size(Max),
    ( Batch1 >= Max ->
        format(Out, ';~n', []),
        Batch = 0
    ; Batch = Batch1
    ),
    nb_setarg(4, State, Batch),
    nb_setarg(5, State, Rows).

finish_import_batch(State) :-
    arg(1, State, Out),
    arg(4, State, Batch),
    ( Batch > 0 -> format(Out, ';~n', []) ; true ).

normalize_row_arity(Values, Arity, Normalized) :-
    length(Prefix, Arity),
    append(Prefix, _, Values), !,
    Normalized = Prefix.
normalize_row_arity(Values, Arity, Normalized) :-
    length(Values, Length),
    Missing is Arity - Length,
    length(Padding, Missing),
    maplist(=(null), Padding),
    append(Values, Padding, Normalized).

normalize_import_scalar(Value, null) :-
    ( var(Value)
    ; Value == null
    ; Value == ''
    ; Value == ""
    ), !.
normalize_import_scalar(Value, Value) :- number(Value), !.
normalize_import_scalar(Value, Number) :-
    interchange_name_atom(Value, Atom),
    numeric_import_atom(Atom, Number), !.
normalize_import_scalar(Value, Atom) :-
    interchange_name_atom(Value, Atom).

numeric_import_atom(Atom, Number) :-
    \+ import_leading_zero_text(Atom),
    catch(atom_number(Atom, Number), _, fail).

import_leading_zero_text(Atom) :-
    atom_codes(Atom, [48,Next|_]),
    code_type(Next, digit), !.
import_leading_zero_text(Atom) :-
    atom_codes(Atom, [Sign,48,Next|_]),
    memberchk(Sign, [43,45]),
    code_type(Next, digit).

sanitize_headers(Headers0, Headers) :-
    sanitize_headers(Headers0, 1, [], Headers).

sanitize_headers([], _, _, []).
sanitize_headers([Header0|Headers0], Index, Seen, [Header|Headers]) :-
    ( normalize_import_scalar(Header0, null) ->
        format(atom(Base), 'column_~w', [Index])
    ; sanitize_identifier(Header0, Base)
    ),
    unique_identifier(Base, Index, Seen, Header),
    Next is Index + 1,
    sanitize_headers(Headers0, Next, [Header|Seen], Headers).

unique_identifier(Base, _, Seen, Base) :-
    \+ memberchk(Base, Seen), !.
unique_identifier(Base, Index, _, Header) :-
    format(atom(Header), '~w_~w', [Base, Index]).

sanitize_identifier(Value, Identifier) :-
    interchange_name_atom(Value, Atom),
    atom_codes(Atom, Codes0),
    maplist(identifier_code, Codes0, Codes1),
    collapse_underscores(Codes1, Codes2),
    trim_identifier_underscores(Codes2, Codes),
    ( Codes == [] -> Identifier = imported
    ; atom_codes(Identifier, Codes)
    ).

identifier_code(Code, Code) :-
    ( Code >= 65, Code =< 90
    ; Code >= 97, Code =< 122
    ; Code >= 48, Code =< 57
    ; Code =:= 95
    ), !.
identifier_code(_, 95).

collapse_underscores([], []).
collapse_underscores([95,95|Codes], Collapsed) :- !,
    collapse_underscores([95|Codes], Collapsed).
collapse_underscores([Code|Codes], [Code|Collapsed]) :-
    collapse_underscores(Codes, Collapsed).

trim_identifier_underscores(Codes0, Codes) :-
    drop_leading_underscores(Codes0, Codes1),
    reverse(Codes1, Reversed),
    drop_leading_underscores(Reversed, TrimmedReversed),
    reverse(TrimmedReversed, Codes).

drop_leading_underscores([95|Codes], Rest) :- !,
    drop_leading_underscores(Codes, Rest).
drop_leading_underscores(Codes, Codes).

/* -------------------------------------------------------------------------
   DOM and scalar helpers
   ------------------------------------------------------------------------- */

dom_element_named(Term, Name, Element) :-
    is_list(Term), !,
    member(Child, Term),
    dom_element_named(Child, Name, Element).
dom_element_named(element(Tag, Attrs, Children),
                  Name, element(Tag, Attrs, Children)) :-
    dom_local_name(Tag, Name).
dom_element_named(element(_, _, Children), Name, Element) :-
    dom_element_named(Children, Name, Element).

dom_local_name(Tag, Name) :- Tag == Name, !.
dom_local_name(_NS:Local, Name) :- Local == Name, !.
dom_local_name(Tag, Name) :-
    atom(Tag),
    atomic_list_concat(Parts, ':', Tag),
    last(Parts, Name).

dom_attribute([Key=Value|_], Name, Value) :-
    dom_local_name(Key, Name), !.
dom_attribute([_|Attrs], Name, Value) :-
    dom_attribute(Attrs, Name, Value).

dom_text_content(element(_, _, Children), Text) :- !,
    dom_text_content(Children, Text).
dom_text_content(Children, Text) :-
    is_list(Children), !,
    maplist(dom_text_content, Children, Parts),
    atomic_list_concat(Parts, '', Text).
dom_text_content(Value, Text) :-
    interchange_name_atom(Value, Text).

pairs_dense_values([], []).
pairs_dense_values(Pairs, Values) :-
    pairs_max_index(Pairs, 0, Max),
    numlist(1, Max, Positions),
    maplist(pair_position_value(Pairs), Positions, Values).

pairs_max_index([], Max, Max).
pairs_max_index([Index-_|Pairs], Max0, Max) :-
    Max1 is max(Index, Max0),
    pairs_max_index(Pairs, Max1, Max).

pair_position_value(Pairs, Position, Value) :-
    ( memberchk(Position-Found, Pairs) -> Value = Found ; Value = null ).

xlsx_cell_column(Reference0, Index) :-
    interchange_name_atom(Reference0, Reference),
    atom_codes(Reference, Codes),
    take_letter_codes(Codes, Letters),
    Letters \= [],
    xlsx_letters_index(Letters, 0, Index).

take_letter_codes([Code|Codes], [Upper|Letters]) :-
    ( Code >= 65, Code =< 90 -> Upper = Code
    ; Code >= 97, Code =< 122 -> Upper is Code - 32
    ), !,
    take_letter_codes(Codes, Letters).
take_letter_codes(_, []).

xlsx_letters_index([], Index, Index).
xlsx_letters_index([Code|Codes], Acc0, Index) :-
    Acc is Acc0 * 26 + Code - 64,
    xlsx_letters_index(Codes, Acc, Index).

xlsx_column_name(Index, Name) :-
    xlsx_column_codes(Index, Codes),
    atom_codes(Name, Codes).

xlsx_column_codes(Index, Codes) :-
    Index > 0,
    xlsx_column_codes_rev(Index, Rev),
    reverse(Rev, Codes).

xlsx_column_codes_rev(0, []) :- !.
xlsx_column_codes_rev(Index, [Code|Codes]) :-
    Next is Index - 1,
    Digit is Next mod 26,
    Code is 65 + Digit,
    Rest is Next // 26,
    xlsx_column_codes_rev(Rest, Codes).

xml_escape(Value, Escaped) :-
    interchange_name_atom(Value, Atom),
    atom_codes(Atom, Codes),
    xml_escape_codes(Codes, EscapedCodes),
    string_codes(Escaped, EscapedCodes).

xml_escape_codes([], []).
xml_escape_codes([38|Codes], Escaped) :- !,
    append([38,97,109,112,59], Rest, Escaped),
    xml_escape_codes(Codes, Rest).
xml_escape_codes([60|Codes], Escaped) :- !,
    append([38,108,116,59], Rest, Escaped),
    xml_escape_codes(Codes, Rest).
xml_escape_codes([62|Codes], Escaped) :- !,
    append([38,103,116,59], Rest, Escaped),
    xml_escape_codes(Codes, Rest).
xml_escape_codes([34|Codes], Escaped) :- !,
    append([38,113,117,111,116,59], Rest, Escaped),
    xml_escape_codes(Codes, Rest).
xml_escape_codes([39|Codes], Escaped) :- !,
    append([38,97,112,111,115,59], Rest, Escaped),
    xml_escape_codes(Codes, Rest).
xml_escape_codes([Code|Codes], [Code|Escaped]) :-
    xml_escape_codes(Codes, Escaped).

take_prefix(0, _, []) :- !.
take_prefix(_, [], []) :- !.
take_prefix(N, [X|Xs], [X|Ys]) :-
    N1 is N - 1,
    take_prefix(N1, Xs, Ys).

/* -------------------------------------------------------------------------
   Catalog, row, quoting, and format helpers
   ------------------------------------------------------------------------- */

interchange_database(state(_, DBs), Database, Db) :-
    member(Db, DBs),
    interchange_db_parts(Db, Name, _, _),
    interchange_same_identifier(Name, Database),
    \+ interchange_internal_database(Name), !.
interchange_database(_, Database, _) :-
    throw(error(existence_error(database, Database), _)).

interchange_db_parts(db(Name, Tables, Views, _, _, _), Name, Tables, Views) :- !.
interchange_db_parts(db(Name, Tables), Name, Tables, []).

interchange_table_parts(table(Name, Columns, Storage, Indexes),
                        Name, Columns, Storage, Indexes) :- !.
interchange_table_parts(table(Name, Columns, Storage),
                        Name, Columns, Storage, []).

interchange_view_parts(view(Name, SelectAST, _), Name, SelectAST) :- !.
interchange_view_parts(view(Name, SelectAST), Name, SelectAST).

interchange_internal_database(Name) :-
    atom(Name), sub_atom(Name, 0, 2, _, '__').

interchange_storage_row(paged_rows(StoreId, _, _), Row) :- !,
    asadb_record_scan_verified(StoreId, _, Row).
interchange_storage_row(Rows, Row) :-
    is_list(Rows),
    member(Row, Rows).

interchange_column_names([], []).
interchange_column_names([col(Name, _, _)|Columns], [Name|Names]) :-
    interchange_column_names(Columns, Names).

interchange_row_values([], _, []).
interchange_row_values([col(Name, _, _)|Columns], Pairs, [Value|Values]) :-
    interchange_pair_value(Name, Pairs, Value),
    interchange_row_values(Columns, Pairs, Values).

interchange_pair_value(_, [], null).
interchange_pair_value(Name, [Key=Value|_], Value) :-
    interchange_same_identifier(Name, Key), !.
interchange_pair_value(Name, [_|Pairs], Value) :-
    interchange_pair_value(Name, Pairs, Value).

sql_identifier(mysql, Name0, SQL) :-
    interchange_name_atom(Name0, Name),
    atom_codes(Name, Codes0),
    escape_identifier_code(96, Codes0, Codes),
    append([96|Codes], [96], Quoted),
    atom_codes(SQL, Quoted).
sql_identifier(postgresql, Name0, SQL) :-
    interchange_name_atom(Name0, Name),
    atom_codes(Name, Codes0),
    escape_identifier_code(34, Codes0, Codes),
    append([34|Codes], [34], Quoted),
    atom_codes(SQL, Quoted).

escape_identifier_code(_, [], []).
escape_identifier_code(Quote, [Quote|Codes], [Quote,Quote|Escaped]) :- !,
    escape_identifier_code(Quote, Codes, Escaped).
escape_identifier_code(Quote, [Code|Codes], [Code|Escaped]) :-
    escape_identifier_code(Quote, Codes, Escaped).

sql_value(_, null, 'NULL') :- !.
sql_value(_, Value, SQL) :- number(Value), !,
    number_codes(Value, Codes),
    atom_codes(SQL, Codes).
sql_value(postgresql, Value, SQL) :- !,
    interchange_name_atom(Value, Atom),
    atom_codes(Atom, Codes),
    escape_postgresql_string(Codes, Escaped),
    append([39|Escaped], [39], Quoted),
    atom_codes(SQL, Quoted).
sql_value(_, Value, SQL) :-
    interchange_name_atom(Value, Atom),
    atom_codes(Atom, Codes),
    escape_sql_string(Codes, Escaped),
    append([39|Escaped], [39], Quoted),
    atom_codes(SQL, Quoted).

escape_sql_string([], []).
escape_sql_string([92|Codes], [92,92|Escaped]) :- !,
    escape_sql_string(Codes, Escaped).
escape_sql_string([39|Codes], [92,39|Escaped]) :- !,
    escape_sql_string(Codes, Escaped).
escape_sql_string([10|Codes], [92,110|Escaped]) :- !,
    escape_sql_string(Codes, Escaped).
escape_sql_string([13|Codes], [92,114|Escaped]) :- !,
    escape_sql_string(Codes, Escaped).
escape_sql_string([9|Codes], [92,116|Escaped]) :- !,
    escape_sql_string(Codes, Escaped).
escape_sql_string([Code|Codes], [Code|Escaped]) :-
    escape_sql_string(Codes, Escaped).

escape_postgresql_string([], []).
escape_postgresql_string([39|Codes], [39,39|Escaped]) :- !,
    escape_postgresql_string(Codes, Escaped).
escape_postgresql_string([Code|Codes], [Code|Escaped]) :-
    escape_postgresql_string(Codes, Escaped).

interchange_scalar_atom(Value, Atom) :- atom(Value), !, Atom = Value.
interchange_scalar_atom(Value, Atom) :- string(Value), !,
    atom_string(Atom, Value).
interchange_scalar_atom(Value, Atom) :- number(Value), !,
    number_codes(Value, Codes), atom_codes(Atom, Codes).
interchange_scalar_atom(Value, Atom) :-
    term_to_atom(Value, Atom).

interchange_format(Value, Format) :-
    interchange_requested_format(Value, Format),
    memberchk(Format, [mysql,postgresql,csv,xlsx]), !.
interchange_format(Value, _) :-
    throw(error(domain_error(interchange_export_format, Value), _)).

interchange_requested_format(Value0, Format) :-
    interchange_name_atom(Value0, Value),
    downcase_atom(Value, Lower),
    interchange_format_alias(Lower, Format), !.
interchange_requested_format(Value, _) :-
    throw(error(domain_error(interchange_import_format, Value), _)).

interchange_format_alias(auto, auto).
interchange_format_alias(asadb, asadb).
interchange_format_alias(asa, asadb).
interchange_format_alias(asb, asadb).
interchange_format_alias(sql, mysql).
interchange_format_alias(mysql, mysql).
interchange_format_alias(postgresql, postgresql).
interchange_format_alias(postgres, postgresql).
interchange_format_alias(pgsql, postgresql).
interchange_format_alias(psql, postgresql).
interchange_format_alias(csv, csv).
interchange_format_alias(xlsx, xlsx).

interchange_extension_format(Name, asadb) :-
    ( sub_atom(Name, _, 4, 0, '.asb')
    ; sub_atom(Name, _, 4, 0, '.asa')
    ; sub_atom(Name, _, 6, 0, '.asadb')
    ), !.
interchange_extension_format(Name, csv) :-
    ( sub_atom(Name, _, 4, 0, '.csv')
    ; sub_atom(Name, _, 8, 0, '-csv.zip')
    ), !.
interchange_extension_format(Name, xlsx) :-
    sub_atom(Name, _, 5, 0, '.xlsx'), !.
interchange_extension_format(Name, postgresql) :-
    ( sub_atom(Name, _, 6, 0, '.pgsql')
    ; sub_atom(Name, _, 5, 0, '.psql')
    ; sub_atom(Name, _, 9, 0, '.postgres')
    ), !.
interchange_extension_format(Name, mysql) :-
    sub_atom(Name, _, 6, 0, '.mysql'), !.
interchange_extension_format(Name, sql) :-
    sub_atom(Name, _, 4, 0, '.sql').

interchange_probe_sql_format(Name, Format) :-
    interchange_name_atom(Name, Atom),
    ( exists_file(Atom) ->
        setup_call_cleanup(
            open(Atom, read, In, [encoding(utf8)]),
            once(read_string(In, 65536, Prefix)),
            close(In)
        ),
        string_upper(Prefix, Upper),
        ( sql_line_contains_any(Upper,
                                ["COPY ", " FROM STDIN", "SET SEARCH_PATH",
                                 "SERIAL", "PG_CATALOG"]) ->
            Format = postgresql
        ; Format = mysql
        )
    ; Format = mysql
    ).

sql_line_contains_any(Line, [Needle|_]) :-
    sub_string(Line, _, _, _, Needle), !.
sql_line_contains_any(Line, [_|Needles]) :-
    sql_line_contains_any(Line, Needles).

interchange_import_mode(Value0, Mode) :-
    interchange_name_atom(Value0, Value),
    downcase_atom(Value, Lower),
    memberchk(Lower, [replace,append]), !,
    Mode = Lower.
interchange_import_mode(_, replace).

interchange_target_table(Value0, OriginalName, Table) :-
    ( nonvar(Value0),
      interchange_name_atom(Value0, Value),
      Value \== '' ->
        sanitize_identifier(Value, Table)
    ; interchange_name_atom(OriginalName, Name),
      file_base_name(Name, Base),
      file_name_extension(Stem, _, Base),
      sanitize_identifier(Stem, Table)
    ).

interchange_unquote_qualified_identifier(Value, Identifier) :-
    interchange_name_atom(Value, Raw),
    normalize_space(atom(Atom0), Raw),
    atomic_list_concat(Parts, '.', Atom0),
    last(Parts, Last0),
    atom_codes(Last0, Codes0),
    exclude(identifier_quote_code, Codes0, Codes),
    atom_codes(Identifier, Codes).

identifier_quote_code(34).
identifier_quote_code(96).

interchange_database_atom(Value, Database) :-
    interchange_name_atom(Value, Database),
    Database \== '', !.
interchange_database_atom(Value, _) :-
    throw(error(domain_error(database, Value), _)).

interchange_name_atom(Value, Atom) :- atom(Value), !, Atom = Value.
interchange_name_atom(Value, Atom) :- string(Value), !,
    atom_string(Atom, Value).
interchange_name_atom(Value, Atom) :- number(Value), !,
    number_codes(Value, Codes), atom_codes(Atom, Codes).

interchange_same_identifier(A, B) :- A == B, !.
interchange_same_identifier(A, B) :-
    atom(A), atom(B),
    downcase_atom(A, Lower),
    downcase_atom(B, Lower).

temporary_interchange_file(text, File) :-
    tmp_file_stream(utf8, File, Out),
    close(Out).
temporary_interchange_file(binary, File) :-
    tmp_file_stream(octet, File, Out),
    close(Out).

interchange_filename(Name0, Suffix, Filename) :-
    interchange_name_atom(Name0, Name),
    atom_codes(Name, Codes0),
    maplist(filename_code, Codes0, Codes),
    atom_codes(Safe, Codes),
    atom_concat(Safe, Suffix, Filename).

filename_code(Code, Code) :-
    ( Code >= 65, Code =< 90
    ; Code >= 97, Code =< 122
    ; Code >= 48, Code =< 57
    ; memberchk(Code, [45,95])
    ), !.
filename_code(_, 95).
