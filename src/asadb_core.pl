% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  AsaDB Core Engine
  -----------------
  Prototype SQL database engine written in Prolog.

  Internal storage model (v3):
    state(Version, Databases)
    db(Name, Tables)
    table(Name, Columns, paged_rows(StoreId, Count, AutoCounters), Indexes)
    col(Name, Type, Options)
    row([Column=Value, ...])

  .asa file format:
    magic bytes: ASADB001\n
    payload: XOR-obfuscated canonical Prolog term with a trailing checksum.

  This is intentionally tiny compared to MySQL, but the code is designed as
  a hackable base for expanding the MySQL 5.5 grammar.
*/

:- module(asadb_core, [
    asadb_boot/1,
    asadb_warmup/0,
    asadb_shutdown/0,
    asadb_save/0,
    asadb_exec_sql/2,
    asadb_exec_sql_limited/3,
    asadb_exec_sql_page/4,
    asadb_exec_sql_snapshot_limited/3,
    asadb_exec_sql_snapshot_page/4,
    asadb_snapshot_read_allowed/1,
    asadb_parse_sql/2,
    asadb_analyze_sql/2,
    asadb_current_database/1,
    asadb_get_state/1,
    asadb_transaction_active/0,
    asadb_backup_transaction_active/0,
    asadb_backup_capture_current_database/1,
    asadb_backup_restore_current_database/1,
    asadb_backup_stage_catalog_objects/5,
    asadb_backup_restore_catalog_objects/5,
    asadb_view_definition/3,
    asadb_view_rows/4,
    asadb_storage_stats/1,
    asadb_database_metadata/1,
    asadb_analysis_json/2,
    asadb_result_json/2,
    asadb_format_result/1,
    asadb_constraint_expression_sql/2
]).

:- set_prolog_flag(double_quotes, codes).
:- discontiguous apply_db_action/3.
:- discontiguous normalize_dbs/2.
:- discontiguous normalize_tables/3.

:- use_module(library(lists)).
:- use_module(library(assoc)).
:- use_module(library(readutil)).
:- use_module(library(solution_sequences)).
:- use_module('asadb_buffer_pool.pl').
:- use_module('asadb_pager.pl').
:- use_module('asadb_btree.pl').
:- use_module('asadb_config.pl').
:- use_module('asadb_record_manager.pl').
:- use_module('asadb_metadata.pl').
:- use_module('asadb_mysql55_compat.pl').
:- use_module('asadb_prolog_jit.pl').
:- use_module('asadb_schema.pl').
:- use_module('asadb_sql_frontend.pl', [asadb_parse_statement/2]).
:- use_module('asadb_tvcc.pl').

:- dynamic asadb_state/1.
:- dynamic asadb_file/1.
:- dynamic asadb_current_db/1.
:- dynamic asadb_tx_snapshot/1.
:- dynamic asadb_write_lock/1.
:- dynamic asadb_current_user/1.
:- dynamic asadb_btree_cache/4.
:- dynamic asadb_index_probe_count/4.
:- dynamic asadb_plan_stat/2.
:- dynamic asadb_hot_filter/2.
:- dynamic asadb_hot_filter_cache/5.
:- dynamic asadb_hot_filter_tick/1.
:- dynamic asadb_checkpoint_dirty/0.
:- thread_local asadb_query_batch_depth/1.
:- thread_local asadb_tvcc_read_state/1.
:- thread_local asadb_tvcc_read_db/1.

asadb_magic("ASADB001\n").

empty_state(state(3, [])).

catalog_db('__asadb_catalog').

normalize_state(state(V, DBs), state(V, DBs)) :-
    integer(V),
    V >= 3, !.
normalize_state(state(_, DBs), state(3, Normalized)) :- !,
    normalize_dbs(DBs, Normalized).
normalize_state(_, State) :- empty_state(State).

normalize_dbs([], []).
normalize_dbs([db(Name, Tables, Views, Functions, Procedures, Triggers)|DBs], [db(Name, NTables, Views, Functions, Procedures, Triggers)|Out]) :- !,
    normalize_tables(Name, Tables, NTables),
    normalize_dbs(DBs, Out).
normalize_dbs([db(Name, Tables)|DBs], [db(Name, NTables, [], [], [], [])|Out]) :- !,
    normalize_tables(Name, Tables, NTables),
    normalize_dbs(DBs, Out).
normalize_dbs([_|DBs], Out) :- normalize_dbs(DBs, Out).

normalize_tables(_, [], []).
normalize_tables(Database, [table(Name, Columns0, Rows0)|Tables], [table(Name, Columns, Rows, Indexes)|Out]) :- !,
    normalize_table_payload(Database, Name, Columns0, Rows0, [], Columns, Rows, Indexes),
    normalize_tables(Database, Tables, Out).
normalize_tables(Database, [table(Name, Columns0, Rows0, Indexes0)|Tables], [table(Name, Columns, Rows, Indexes)|Out]) :- !,
    normalize_table_payload(Database, Name, Columns0, Rows0, Indexes0, Columns, Rows, Indexes),
    normalize_tables(Database, Tables, Out).
normalize_tables(Database, [_|Tables], Out) :- normalize_tables(Database, Tables, Out).

normalize_table_payload(Database, Name, Columns0, Rows0, Indexes0, Columns, Rows, Indexes) :-
    dedupe_columns(Columns0, Columns),
    normalize_table_row_storage(Database, Name, Columns, Rows0, Rows),
    normalize_indexes_for_columns(Columns, Indexes0, CleanIndexes),
    ( CleanIndexes = [] -> default_indexes(Name, Columns, Indexes) ; Indexes = CleanIndexes ).

normalize_table_row_storage(_, _, _, paged_rows(StoreId, Count, Counters),
                            paged_rows(StoreId, Count, Counters)) :- !.
normalize_table_row_storage(Database, Table, Columns, Rows0,
                            paged_rows(StoreId, Count, Counters)) :-
    normalize_rows_for_columns(Columns, Rows0, Rows),
    asadb_record_store_id(Database, Table, StoreId),
    asadb_record_create(StoreId),
    asadb_record_insert_batch(StoreId, Rows, _),
    length(Rows, Count),
    init_auto_counters(Columns, Rows, Counters).

dedupe_columns(Columns0, Columns) :-
    dedupe_columns_(Columns0, [], Columns).

dedupe_columns_([], _, []).
dedupe_columns_([col(Name, _, _)|Columns], Seen, Out) :-
    identifier_member(Name, Seen), !,
    dedupe_columns_(Columns, Seen, Out).
dedupe_columns_([col(Name, Type, Options)|Columns], Seen, [col(Name, Type, Options)|Out]) :- !,
    dedupe_columns_(Columns, [Name|Seen], Out).
dedupe_columns_([_|Columns], Seen, Out) :-
    dedupe_columns_(Columns, Seen, Out).

normalize_rows_for_columns(_, [], []).
normalize_rows_for_columns(Columns, [row(Pairs0)|Rows], [row(Pairs)|Out]) :- !,
    row_pairs_for_columns(Columns, Pairs0, Pairs),
    normalize_rows_for_columns(Columns, Rows, Out).
normalize_rows_for_columns(Columns, [_|Rows], Out) :-
    normalize_rows_for_columns(Columns, Rows, Out).

row_pairs_for_columns([], _, []).
row_pairs_for_columns([col(Name, _, _)|Columns], Pairs0, [Name=Value|Pairs]) :-
    lookup_pair_value(Name, Pairs0, Value),
    row_pairs_for_columns(Columns, Pairs0, Pairs).

normalize_indexes_for_columns(_, [], []).
normalize_indexes_for_columns(Columns, [index(Name, RawCols, Unique)|Indexes], Out) :- !,
    normalize_index_columns(Columns, RawCols, CleanCols),
    normalize_indexes_for_columns(Columns, Indexes, Rest),
    ( CleanCols = [] -> Out = Rest ; Out = [index(Name, CleanCols, Unique)|Rest] ).
normalize_indexes_for_columns(Columns, [check(Name, Expr)|Indexes], [check(Name, Expr)|Out]) :- !,
    normalize_indexes_for_columns(Columns, Indexes, Out).
normalize_indexes_for_columns(Columns,
                              [foreign_key(Name, RawLocal, RefTable, RawRef, DeleteAction, UpdateAction)|Indexes],
                              Out) :- !,
    normalize_index_columns(Columns, RawLocal, Local),
    normalize_indexes_for_columns(Columns, Indexes, Rest),
    ( Local = [] -> Out = Rest
    ; Out = [foreign_key(Name, Local, RefTable, RawRef, DeleteAction, UpdateAction)|Rest]
    ).
normalize_indexes_for_columns(Columns, [_|Indexes], Out) :-
    normalize_indexes_for_columns(Columns, Indexes, Out).

normalize_index_columns(Columns, RawCols, CleanCols) :-
    normalize_index_columns_(RawCols, Columns, [], CleanCols).

normalize_index_columns_([], _, _, []).
normalize_index_columns_([Name|Names], Columns, Seen, Out) :-
    ( identifier_member(Name, Seen) ->
        normalize_index_columns_(Names, Columns, Seen, Out)
    ; column_actual_name(Name, Columns, Actual) ->
        Out = [Actual|Rest],
        normalize_index_columns_(Names, Columns, [Actual|Seen], Rest)
    ; normalize_index_columns_(Names, Columns, Seen, Out)
    ).

column_actual_name(Name, [col(Actual, _, _)|_], Actual) :-
    same_identifier(Name, Actual), !.
column_actual_name(Name, [_|Columns], Actual) :-
    column_actual_name(Name, Columns, Actual).

ensure_catalog :-
    catalog_db(Catalog),
    update_state_raw(ensure_catalog(Catalog)).

catalog_columns(users, [
    col(user, varchar, [primary_key, not_null]),
    col(password, varchar, [not_null]),
    col(created_at, varchar, [])
]).
catalog_columns(grants, [
    col(user, varchar, [not_null]),
    col(privilege, varchar, [not_null]),
    col(scope, varchar, [not_null])
]).

catalog_table(users, table(users, Columns, Rows, [index('PRIMARY', [user], unique)])) :-
    catalog_columns(users, Columns),
    Rows = [row([user=admin,password='',created_at=system])].
catalog_table(grants, table(grants, Columns, [], [index(grants_user_scope, [user,scope], non_unique)])) :-
    catalog_columns(grants, Columns).

default_indexes(_Name, Columns, Indexes) :-
    findall(Col,
            ( member(col(Col, _, Options), Columns), member(primary_key, Options) ),
            PrimaryColumns),
    ( PrimaryColumns = [] -> Primary = []
    ; Primary = [index('PRIMARY', PrimaryColumns, unique)]
    ),
    findall(index(Col, [Col], unique),
            ( member(col(Col, _, Options), Columns), member(unique, Options) ),
            Unique),
    append(Primary, Unique, Indexes0),
    ( Indexes0 = [] -> Indexes = [] ; Indexes = Indexes0 ).

table_option_constraints(table_options(Constraints, _), Constraints) :- !.
table_option_constraints(_, []).

validate_table_constraints(DB, Columns, Constraints) :-
    validate_constraint_columns(Columns, Constraints),
    validate_primary_key_declarations(Columns, Constraints),
    validate_foreign_key_declarations(DB, Constraints).

validate_constraint_columns(_, []).
validate_constraint_columns(Columns, [Constraint|Constraints]) :-
    validate_constraint_columns_(Columns, Constraint),
    validate_constraint_columns(Columns, Constraints).

validate_constraint_columns_(Columns, primary_key(_, Names)) :- !,
    validate_constraint_column_list(Columns, Names).
validate_constraint_columns_(Columns, unique_key(_, Names)) :- !,
    validate_constraint_column_list(Columns, Names).
validate_constraint_columns_(Columns, index_key(_, Names)) :- !,
    validate_constraint_column_list(Columns, Names).
validate_constraint_columns_(Columns, foreign_key(_, LocalNames, _, RefNames, _, _)) :- !,
    validate_constraint_column_list(Columns, LocalNames),
    ( same_length(LocalNames, RefNames) -> true
    ; throw(error(domain_error(foreign_key_column_count(LocalNames), RefNames), _))
    ).
validate_constraint_columns_(_, check_constraint(_, _)).

validate_constraint_column_list(_, []) :-
    throw(error(domain_error(constraint_columns, []), _)).
validate_constraint_column_list(Columns, [Name|Names]) :-
    ( column_actual_name(Name, Columns, _) -> true
    ; throw(error(existence_error(column, Name), _))
    ),
    ( identifier_member(Name, Names) ->
        throw(error(permission_error(use, duplicate_constraint_column, Name), _))
    ; true
    ),
    validate_constraint_column_list_tail(Columns, Names).

validate_constraint_column_list_tail(_, []).
validate_constraint_column_list_tail(Columns, [Name|Names]) :-
    ( column_actual_name(Name, Columns, _) -> true
    ; throw(error(existence_error(column, Name), _))
    ),
    validate_constraint_column_list_tail(Columns, Names).

validate_primary_key_declarations(Columns, Constraints) :-
    findall(Names, member(primary_key(_, Names), Constraints), TablePrimaryKeys),
    findall(Name,
            ( member(col(Name, _, Options), Columns), member(primary_key, Options) ),
            ColumnPrimaryKeys),
    append(TablePrimaryKeys, [ColumnPrimaryKeys], AllDeclarations),
    nonempty_primary_declarations(AllDeclarations, Nonempty),
    ( Nonempty = [] -> true
    ; Nonempty = [_] -> true
    ; throw(error(permission_error(create, multiple_primary_keys, Nonempty), _))
    ).

nonempty_primary_declarations([], []).
nonempty_primary_declarations([[]|Declarations], Nonempty) :- !,
    nonempty_primary_declarations(Declarations, Nonempty).
nonempty_primary_declarations([Declaration|Declarations], [Declaration|Nonempty]) :-
    nonempty_primary_declarations(Declarations, Nonempty).

validate_foreign_key_declarations(_, []).
validate_foreign_key_declarations(DB,
                                  [foreign_key(_, _, RefTable, RefColumns, DeleteAction, UpdateAction)|Constraints]) :- !,
    validate_fk_action(DeleteAction),
    validate_fk_action(UpdateAction),
    ( get_table_existing(DB, RefTable, table(_, _, _, RefIndexes)) ->
        ( foreign_key_reference_index(RefColumns, RefIndexes) -> true
        ; throw(error(domain_error(foreign_key_reference_key(RefTable), RefColumns), _))
        )
    ; throw(error(existence_error(table, RefTable), _))
    ),
    validate_foreign_key_declarations(DB, Constraints).
validate_foreign_key_declarations(DB, [_|Constraints]) :-
    validate_foreign_key_declarations(DB, Constraints).

validate_fk_action(restrict).
validate_fk_action(Action) :-
    throw(error(domain_error(foreign_key_action, Action), _)).

foreign_key_reference_index(Columns, Indexes) :-
    member(index(_, IndexedColumns, unique), Indexes),
    same_identifier_lists(Columns, IndexedColumns), !.

same_identifier_lists([], []).
same_identifier_lists([A|As], [B|Bs]) :-
    same_identifier(A, B),
    same_identifier_lists(As, Bs).

table_constraint_items(_, [], [], _).
table_constraint_items(Table, [Constraint|Constraints], Items, Sequence0) :-
    table_constraint_item(Table, Constraint, Sequence0, Item),
    Sequence is Sequence0 + 1,
    table_constraint_items(Table, Constraints, Rest, Sequence),
    ( Item = none -> Items = Rest ; Items = [Item|Rest] ).

table_constraint_item(_, primary_key(_, Columns), _, index('PRIMARY', Columns, unique)) :- !.
table_constraint_item(Table, unique_key(Name0, Columns), Sequence, index(Name, Columns, unique)) :- !,
    constraint_item_name(Table, unique, Name0, Sequence, Name).
table_constraint_item(Table, index_key(Name0, Columns), Sequence, index(Name, Columns, non_unique)) :- !,
    constraint_item_name(Table, index, Name0, Sequence, Name).
table_constraint_item(Table, check_constraint(Name0, Expr), Sequence, check(Name, Expr)) :- !,
    constraint_item_name(Table, check, Name0, Sequence, Name).
table_constraint_item(_, foreign_key(Name, Local, RefTable, RefColumns, restrict, restrict), _,
                      foreign_key(Name, Local, RefTable, RefColumns, restrict, restrict)) :- !.
table_constraint_item(_, Constraint, _, _) :-
    throw(error(domain_error(table_constraint, Constraint), _)).

constraint_item_name(_, _, Name, _, Name) :- Name \== unnamed, !.
constraint_item_name(Table, Kind, _, Sequence, Name) :-
    format(atom(Name), '__asadb_~w_~w_~d', [Kind, Table, Sequence]).

table_indexes(Name, Columns, Constraints, Indexes) :-
    default_indexes(Name, Columns, DefaultIndexes),
    table_constraint_items(Name, Constraints, ConstraintItems, 1),
    append(DefaultIndexes, ConstraintItems, Indexes).

same_identifier(A, B) :- A == B, !.
same_identifier(A, B) :-
    atom(A),
    atom(B),
    downcase_atom(A, LowerA),
    downcase_atom(B, LowerB),
    LowerA == LowerB.

identifier_member(Name, [Seen|_]) :- same_identifier(Name, Seen), !.
identifier_member(Name, [_|Seen]) :- identifier_member(Name, Seen).

lookup_pair_value(_, [], null) :- !.
lookup_pair_value(Name, [Key=Value|_], Value) :-
    same_identifier(Name, Key),
    Value \== null, !.
lookup_pair_value(Name, [_|Pairs], Value) :-
    lookup_pair_value(Name, Pairs, Value).

pair_value_same_identifier(Name, [Key=Value|_], Value) :-
    same_identifier(Name, Key).
pair_value_same_identifier(Name, [_|Pairs], Value) :-
    pair_value_same_identifier(Name, Pairs, Value).

pair_has_identifier(Name, Pairs) :-
    pair_value_same_identifier(Name, Pairs, _), !.

asadb_boot(InputFile) :-
    normalize_storage_path(InputFile, File),
    load_storage_config(File),
    asadb_buffer_pool_reset,
    asadb_record_store_open(File),
    recover_checkpoint_file(File),
    retractall(asadb_file(_)),
    retractall(asadb_state(_)),
    retractall(asadb_current_db(_)),
    retractall(asadb_tx_snapshot(_)),
    retractall(asadb_write_lock(_)),
    retractall(asadb_current_user(_)),
    retractall(asadb_btree_cache(_, _, _, _)),
    retractall(asadb_index_probe_count(_, _, _, _)),
    retractall(asadb_plan_stat(_, _)),
    reset_logic_jit,
    retractall(asadb_checkpoint_dirty),
    retractall(asadb_query_batch_depth(_)),
    assertz(asadb_file(File)),
    asadb_metadata_open(File),
    ( exists_file(File) ->
        catch(asadb_load_file(File, State), Error,
              ( format(user_error,
                       'AsaDB catalog load failed for ~w: ~p~n',
                       [File, Error]),
                empty_state(State)
              ))
    ; empty_state(State)
    ),
    asadb_boot_trace(loaded, State),
    normalize_state(State, Normalized),
    asadb_boot_trace(normalized, Normalized),
    mark_state_upgrade(State),
    recover_wal_state(Normalized, Recovered),
    asadb_boot_trace(recovered, Recovered),
    assertz(asadb_state(Recovered)),
    ensure_catalog,
    restore_current_db,
    assertz(asadb_current_user(admin)),
    % A boot snapshot is built only after recovery and catalog initialization
    % have completed.  It must not force a checkpoint just to create a reader
    % image, because that would change recovery and metadata accounting.
    asadb_state(BootState),
    tvcc_selected_database(BootDatabase),
    asadb_tvcc_boot(File, BootState, BootDatabase).

% TEMPORARY: retained only while isolating the Windows restart regression.
% This clause is removed together with the E2E trace once its output has
% identified the failing transition.
asadb_boot_trace(Stage, State) :-
    format(user_error, 'AsaDB boot ~w: ~q~n', [Stage, State]).

load_storage_config(File) :-
    asadb_config_load('asadb.conf'),
    file_directory_name(File, Directory),
    directory_file_path(Directory, 'asadb.conf', LocalConfig),
    ( LocalConfig == 'asadb.conf' -> true ; asadb_config_load(LocalConfig) ).

normalize_storage_path(Input, Path) :-
    atom(Input), !,
    atom_codes(Input, Codes0),
    maplist(storage_slash_code, Codes0, Codes),
    atom_codes(Path, Codes).
normalize_storage_path(Input, Input).

storage_slash_code(92, 47) :- !.
storage_slash_code(Code, Code).

asadb_warmup :-
    ignore(catch(asadb_current_database(_), _, fail)),
    ignore(catch(asadb_parse_sql("SHOW DATABASES;", _), _, fail)),
    ignore(catch(asadb_parse_sql("SELECT * FROM __asa_warmup__;", _), _, fail)),
    ignore(catch(asadb_analyze_sql("CREATE TABLE __asa_warmup__ (id INT);", _), _, fail)),
    ignore(catch(asadb_analyze_sql("SELECT * FROM __asa_warmup__;", _), _, fail)).

asadb_shutdown :-
    rollback_open_transaction_on_shutdown,
    asadb_save_if_needed,
    retractall(asadb_file(_)),
    retractall(asadb_state(_)),
    retractall(asadb_current_db(_)),
    retractall(asadb_tx_snapshot(_)),
    retractall(asadb_write_lock(_)),
    retractall(asadb_current_user(_)),
    retractall(asadb_btree_cache(_, _, _, _)),
    retractall(asadb_index_probe_count(_, _, _, _)),
    retractall(asadb_plan_stat(_, _)),
    reset_logic_jit,
    retractall(asadb_checkpoint_dirty),
    retractall(asadb_query_batch_depth(_)),
    asadb_buffer_pool_flush_all,
    asadb_metadata_close,
    asadb_tvcc_shutdown.

asadb_save_if_needed :-
    asadb_file(File),
    wal_file(Wal),
    ( asadb_checkpoint_dirty -> asadb_save
    ; \+ exists_file(File) -> asadb_save
    ; exists_file(Wal), size_file(Wal, Size), Size > 0 -> asadb_save
    ; true
    ).

rollback_open_transaction_on_shutdown :-
    retract(asadb_tx_snapshot(State)), !,
    asadb_record_tx_rollback,
    retractall(asadb_state(_)),
    assertz(asadb_state(State)).
rollback_open_transaction_on_shutdown.

asadb_save :-
    with_mutex(asadb_write, asadb_save_locked).

asadb_save_locked :-
    asadb_file(File),
    asadb_state(State),
    % A TVCC generation copies durable heap files.  Flush buffered pages
    % before catalog/checkpoint publication so its row count and page image
    % always describe the same commit.
    asadb_pager_flush,
    asadb_save_file(File, State),
    clear_wal,
    retractall(asadb_checkpoint_dirty),
    metadata_checkpoint_summary(State, Summary),
    catch(asadb_metadata_checkpoint(Summary), _, true),
    tvcc_selected_database(Database),
    asadb_tvcc_publish(File, State, Database).

mark_state_upgrade(state(V, _)) :-
    ( \+ integer(V) ; V < 3 ), !,
    assertz(asadb_checkpoint_dirty).
mark_state_upgrade(_).

asadb_get_state(State) :-
    with_mutex(asadb_write, asadb_state(State)).

% Production backups must never claim a transaction snapshot that has not
% committed.  The web backup path checks this before walking record pages.
asadb_backup_transaction_active :-
    with_mutex(asadb_write, asadb_tx_snapshot(_)).

% The transaction implementation is local and single-writer.  A transaction
% must read its own uncommitted writes through the primary execution path, not
% through a previously committed TVCC generation.
asadb_transaction_active :-
    asadb_tx_snapshot(_).

% USE inside a streamed backup changes the selected database outside the row
% transaction snapshot.  The web importer captures it before BEGIN and uses
% this helper on rollback so a failed restore cannot redirect later queries.
asadb_backup_capture_current_database(Database) :-
    with_mutex(asadb_write, asadb_current_database(Database)).

asadb_backup_restore_current_database(none) :- !,
    with_mutex(asadb_write,
               ( retractall(asadb_current_db(_)),
                 clear_persisted_current_db
               )).
asadb_backup_restore_current_database(Database) :-
    with_mutex(asadb_write,
               asadb_backup_restore_current_database_locked(Database)).

asadb_backup_restore_current_database_locked(Database) :-
    asadb_state(State),
    ( db_exists(State, Database) ->
        retractall(asadb_current_db(_)),
        assertz(asadb_current_db(Database)),
        persist_current_db(Database)
    ; throw(error(existence_error(database, Database), _))
    ).

% A verified production backup stages catalog-only objects in the same
% transaction snapshot as its SQL rows.  If the streaming restore fails, the
% normal transaction rollback restores both the rows and these objects.
asadb_backup_stage_catalog_objects(Database, Views, Functions, Procedures, Triggers) :-
    with_mutex(asadb_write,
               asadb_backup_stage_catalog_objects_locked(Database, Views,
                                                          Functions, Procedures,
                                                          Triggers)).

asadb_backup_stage_catalog_objects_locked(Database, Views, Functions, Procedures, Triggers) :-
    ( asadb_tx_snapshot(_) -> true
    ; throw(error(permission_error(restore, production_backup, no_active_transaction), _))
    ),
    asadb_state(State0),
    ( backup_catalog_database_exists(Database, State0) -> true
    ; throw(error(existence_error(database, Database), _))
    ),
    transform_db(Database, State0,
                 replace_backup_catalog_objects(Views, Functions, Procedures, Triggers),
                 State),
    retractall(asadb_state(_)),
    assertz(asadb_state(State)).

backup_catalog_database_exists(Database, state(_, DBs)) :-
    member(DB, DBs),
    backup_catalog_db_name(DB, Name),
    same_identifier(Name, Database), !.

backup_catalog_db_name(db(Name, _, _, _, _, _), Name) :- !.
backup_catalog_db_name(db(Name, _), Name).

% This committed form remains available to the direct core API.  The HTTP
% backup importer uses asadb_backup_stage_catalog_objects/5 before COMMIT.
asadb_backup_restore_catalog_objects(Database, Views, Functions, Procedures, Triggers) :-
    with_mutex(asadb_write,
               asadb_backup_restore_catalog_objects_locked(Database, Views,
                                                            Functions, Procedures,
                                                            Triggers)).

asadb_backup_restore_catalog_objects_locked(Database, Views, Functions, Procedures, Triggers) :-
    ( asadb_tx_snapshot(_) ->
        throw(error(permission_error(restore, production_backup, active_transaction), _))
    ; true
    ),
    asadb_state(State0),
    transform_db(Database, State0,
                 replace_backup_catalog_objects(Views, Functions, Procedures, Triggers),
                 State),
    retractall(asadb_state(_)),
    assertz(asadb_state(State)),
    asadb_save_locked.

asadb_storage_stats(storage{config:Config,pager:PagerStats,btree_cache:btree_cache{entries:CacheEntries},planner:Planner,jit:Jit,tvcc:Tvcc}) :-
    asadb_config_snapshot(Config),
    asadb_pager_stats(PagerStats),
    aggregate_all(count, asadb_btree_cache(_, _, _, _), CacheEntries),
    planner_stats_dict(Planner),
    logic_jit_stats(Jit),
    asadb_tvcc_stats(Tvcc).

asadb_database_metadata(Metadata) :-
    asadb_metadata_snapshot(Identity),
    with_mutex(asadb_write,
        asadb_database_metadata_snapshot(File, Summary,
                                         TransactionActive, CheckpointDirty)),
    file_size_or_zero(File, CatalogBytes),
    atom_concat(File, '.store', StoreRoot),
    directory_size(StoreRoot, StoreBytes),
    wal_file(WalFile),
    file_size_or_zero(WalFile, WalBytes),
    asadb_storage_stats(Storage),
    Persistence = persistence{
        catalog_file:File,
        catalog_bytes:CatalogBytes,
        store_directory:StoreRoot,
        store_bytes:StoreBytes,
        wal_bytes:WalBytes,
        transaction_active:TransactionActive,
        checkpoint_dirty:CheckpointDirty,
        atomic_catalog_replace:true,
        page_checksums:true
    },
    Metadata = Identity.put(_{summary:Summary,persistence:Persistence,storage:Storage}).

asadb_database_metadata_snapshot(File, Summary, TransactionActive, CheckpointDirty) :-
    asadb_file(File),
    asadb_state(State),
    metadata_checkpoint_summary(State, Summary),
    bool_value(asadb_tx_snapshot(_), TransactionActive),
    bool_value(asadb_checkpoint_dirty, CheckpointDirty).

metadata_checkpoint_summary(state(StorageFormat, DBs), summary{
    current_database:CurrentDb,
    database_count:DatabaseCount,
    table_count:TableCount,
    view_count:ViewCount,
    row_count:RowCount,
    storage_format:StorageFormat
}) :-
    asadb_current_database(CurrentDb),
    metadata_catalog_counts(DBs, 0, DatabaseCount, 0, TableCount, 0, ViewCount, 0, RowCount).

metadata_catalog_counts([], DBs, DBs, Tables, Tables, Views, Views, Rows, Rows).
metadata_catalog_counts([DB|Rest], DBs0, DBs, Tables0, Tables, Views0, Views, Rows0, Rows) :-
    metadata_db_parts(DB, Name, DBTables, DBViews),
    ( metadata_visible_database(Name) ->
        length(DBTables, DBTableCount),
        length(DBViews, DBViewCount),
        metadata_table_rows(DBTables, 0, DBRows),
        DBs1 is DBs0 + 1,
        Tables1 is Tables0 + DBTableCount,
        Views1 is Views0 + DBViewCount,
        Rows1 is Rows0 + DBRows
    ; DBs1 = DBs0,
      Tables1 = Tables0,
      Views1 = Views0,
      Rows1 = Rows0
    ),
    metadata_catalog_counts(Rest, DBs1, DBs, Tables1, Tables, Views1, Views, Rows1, Rows).

metadata_db_parts(db(Name, Tables, Views, _, _, _), Name, Tables, Views) :- !.
metadata_db_parts(db(Name, Tables), Name, Tables, []).

metadata_visible_database(Name) :- \+ sub_atom(Name, 0, 2, _, '__').

metadata_table_rows([], Rows, Rows).
metadata_table_rows([table(_, _, paged_rows(_, Count, _), _)|Tables], Rows0, Rows) :- !,
    Rows1 is Rows0 + Count,
    metadata_table_rows(Tables, Rows1, Rows).
metadata_table_rows([table(_, _, TableRows, _)|Tables], Rows0, Rows) :- !,
    length(TableRows, Count),
    Rows1 is Rows0 + Count,
    metadata_table_rows(Tables, Rows1, Rows).
metadata_table_rows([_|Tables], Rows0, Rows) :-
    metadata_table_rows(Tables, Rows0, Rows).

file_size_or_zero(File, Size) :-
    catch(
        ( exists_file(File) -> size_file(File, Size) ; Size = 0 ),
        _,
        Size = 0
    ).

directory_size(Directory, Size) :-
    exists_directory(Directory), !,
    catch(
        ( directory_files(Directory, Names),
          directory_entries_size(Names, Directory, 0, Size)
        ),
        _,
        Size = 0
    ).
directory_size(_, 0).

directory_entries_size([], _, Size, Size).
directory_entries_size(['.'|Names], Directory, Size0, Size) :- !,
    directory_entries_size(Names, Directory, Size0, Size).
directory_entries_size(['..'|Names], Directory, Size0, Size) :- !,
    directory_entries_size(Names, Directory, Size0, Size).
directory_entries_size([Name|Names], Directory, Size0, Size) :-
    directory_file_path(Directory, Name, Path),
    ( exists_directory(Path) -> directory_size(Path, EntrySize)
    ; file_size_or_zero(Path, EntrySize)
    ),
    Size1 is Size0 + EntrySize,
    directory_entries_size(Names, Directory, Size1, Size).

bool_value(Goal, true) :- call(Goal), !.
bool_value(_, false).

planner_stats_dict(planner{index_scans:IndexScans,index_order_scans:IndexOrderScans,
                           sequential_scans:SequentialScans,index_builds:IndexBuilds,
                           metadata_count_scans:MetadataCountScans,
                           indexed_joins:IndexedJoins,nested_loop_joins:NestedLoopJoins}) :-
    plan_stat(index_scan, IndexScans),
    plan_stat(index_order_scan, IndexOrderScans),
    plan_stat(sequential_scan, SequentialScans),
    plan_stat(index_build, IndexBuilds),
    plan_stat(metadata_count_scan, MetadataCountScans),
    plan_stat(indexed_join, IndexedJoins),
    plan_stat(nested_loop_join, NestedLoopJoins).

plan_stat(Name, Value) :- asadb_plan_stat(Name, Value), !.
plan_stat(_, 0).

note_plan(Name) :-
    ( retract(asadb_plan_stat(Name, Current)) -> true ; Current = 0 ),
    Next is Current + 1,
    assertz(asadb_plan_stat(Name, Next)).

asadb_current_database(Name) :-
    asadb_tvcc_read_db(Name),
    Name \== none, !.
asadb_current_database(Name) :-
    asadb_current_db(Name), !.
asadb_current_database(none).

current_db_file(Path) :-
    asadb_file(File),
    atom_concat(File, '.current_db', Path).

restore_current_db :-
    current_db_file(Path),
    exists_file(Path),
    catch(read_current_db_file(Path, Name), _, fail),
    atom(Name),
    asadb_state(State),
    db_exists(State, Name), !,
    retractall(asadb_current_db(_)),
    assertz(asadb_current_db(Name)).
restore_current_db.

read_current_db_file(Path, Name) :-
    setup_call_cleanup(
        open(Path, read, S),
        read(S, Name),
        close(S)
    ).

persist_current_db(Name) :-
    current_db_file(Path),
    ensure_file_parent_directory(Path),
    setup_call_cleanup(
        open(Path, write, S),
        ( writeq(S, Name), write(S, '.\n') ),
        close(S)
    ), !.
persist_current_db(_).

clear_persisted_current_db :-
    current_db_file(Path),
    ( exists_file(Path) -> delete_file(Path) ; true ), !.
clear_persisted_current_db.

wal_file(Path) :-
    asadb_file(File),
    atom_concat(File, '.wal', Path).

append_wal(Action) :-
    wal_file(Path),
    ensure_file_parent_directory(Path),
    setup_call_cleanup(
        open(Path, append, Stream, [encoding(utf8)]),
        ( writeq(Stream, wal(Action)),
          write(Stream, '.\n'),
          flush_output(Stream)
        ),
        close(Stream)
    ).

clear_wal :-
    wal_file(Path),
    ( exists_file(Path) ->
        setup_call_cleanup(open(Path, write, Stream), true, close(Stream))
    ; true
    ).

recover_wal_state(State0, State) :-
    wal_file(Path),
    exists_file(Path), !,
    setup_call_cleanup(
        open(Path, read, Stream, [encoding(utf8)]),
        recover_wal_stream(Stream, State0, State),
        close(Stream)
    ).
recover_wal_state(State, State).

recover_wal_stream(Stream, State0, State) :-
    catch(read_term(Stream, Term, []), _, Term = end_of_file),
    ( Term == end_of_file ->
        State = State0
    ; Term = wal(Action) ->
        ( catch(apply_action(Action, State0, State1), _, fail) -> true ; State1 = State0 ),
        recover_wal_stream(Stream, State1, State)
    ; recover_wal_stream(Stream, State0, State)
    ).

/* -------------------------------------------------------------------------
   Binary-ish .asa storage
   ------------------------------------------------------------------------- */

asadb_save_file(File, State) :-
    ensure_file_parent_directory(File),
    term_to_atom(State, Atom),
    atom_codes(Atom, Codes),
    checksum(Codes, Sum),
    asadb_magic(Magic),
    number_codes(Sum, SumCodes),
    append(Magic, SumCodes, Header),
    append(Header, [10], Prefix),
    atom_concat(File, '.tmp', Temp),
    atom_concat(File, '.bak', Backup),
    delete_storage_file_if_exists(Temp),
    asadb_pager_write_xor_file_codes(Temp, Prefix, Codes, 90),
    asadb_pager_invalidate_file(Temp),
    delete_storage_file_if_exists(Backup),
    ( exists_file(File) -> rename_file(File, Backup) ; true ),
    catch(
        ( rename_file(Temp, File), delete_storage_file_if_exists(Backup) ),
        Error,
        ( delete_storage_file_if_exists(File),
          ( exists_file(Backup) -> rename_file(Backup, File) ; true ),
          throw(Error)
        )
    ).

recover_checkpoint_file(File) :-
    atom_concat(File, '.bak', Backup),
    ( exists_file(File) -> delete_storage_file_if_exists(Backup)
    ; exists_file(Backup) -> rename_file(Backup, File)
    ; true
    ),
    atom_concat(File, '.tmp', Temp),
    delete_storage_file_if_exists(Temp).

delete_storage_file_if_exists(Path) :-
    ( exists_file(Path) -> delete_file(Path) ; true ).

ensure_file_parent_directory(File) :-
    file_directory_name(File, Dir),
    ensure_directory_path(Dir).

ensure_directory_path('.') :- !.
ensure_directory_path('') :- !.
ensure_directory_path(Dir) :-
    exists_directory(Dir), !.
ensure_directory_path(Dir) :-
    file_directory_name(Dir, Parent),
    Parent \== Dir,
    ensure_directory_path(Parent),
    (   exists_directory(Dir)
    ->  true
    ;   make_directory(Dir)
    ).

ensure_file_exists(File) :-
    exists_file(File), !.
ensure_file_exists(File) :-
    ensure_file_parent_directory(File),
    setup_call_cleanup(open(File, write, S), true, close(S)).

asadb_load_file(File, State) :-
    asadb_pager_read_file_codes(File, All),
    asadb_magic(Magic),
    catalog_magic_rest(Magic, All, Rest),
    take_line(Rest, SumCodes, Payload),
    number_codes(Sum, SumCodes),
    decode_codes(Payload, Codes),
    checksum(Codes, Sum),
    atom_codes(Atom, Codes),
    atom_to_term(Atom, State, _).

% A binary AsaDB catalog is normally written with LF delimiters.  Some
% Windows stream configurations preserve the byte content but encode those
% two textual header delimiters as CRLF.  Accept both on read so a committed
% catalog is never mistaken for a new empty database after a restart.
catalog_magic_rest(Magic, All, Rest) :-
    append(Magic, Rest, All), !.
catalog_magic_rest(Magic, All, Rest) :-
    append(Prefix, [10], Magic),
    append(Prefix, [13,10], WindowsMagic),
    append(WindowsMagic, Rest, All).

take_line([13,10|Rest], [], Rest) :- !.
take_line([10|Rest], [], Rest) :- !.
take_line([C|Cs], [C|Line], Rest) :- take_line(Cs, Line, Rest).

checksum(Codes, Sum) :-
    sum_list(Codes, Total),
    Sum is Total mod 1000000007.

decode_codes([], []).
decode_codes([E|Es], [C|Cs]) :- C is (E xor 90) mod 256, decode_codes(Es, Cs).

/* -------------------------------------------------------------------------
   Public SQL execution pipeline
   ------------------------------------------------------------------------- */

asadb_exec_sql(SQL, Result) :-
    catch(with_query_batch((
        asadb_parse_sql(SQL, Statements),
        execute_many(Statements, Results),
        Result = multi(Results)
    )), Error, Result = error(runtime_error, Error)).

asadb_exec_sql_limited(SQL, MaxRows, Result) :-
    catch(with_query_batch((
        asadb_parse_sql(SQL, Statements0),
        maplist(limit_top_level_statement(MaxRows), Statements0, Statements),
        execute_many(Statements, Results),
        Result = multi(Results)
    )), Error, Result = error(runtime_error, Error)).

% Execute a read page without materializing the rows before Offset.  The
% regular limited pipeline intentionally starts at row zero; the page
% pipeline keeps the SQL LIMIT/OFFSET semantics intact so the panel can ask
% for the next page after a result reaches the 500-row display boundary.
asadb_exec_sql_page(SQL, Offset, MaxRows, Result) :-
    valid_result_page_number(Offset),
    valid_result_page_number(MaxRows),
    MaxRows > 0,
    catch(with_query_batch((
        asadb_parse_sql(SQL, Statements0),
        maplist(page_top_level_statement(Offset, MaxRows), Statements0, Statements),
        execute_many(Statements, Results),
        Result = multi(Results)
    )), Error, Result = error(runtime_error, Error)).

% The HTTP SELECT path uses this wrapper instead of opening the mutable record
% store.  Catalog and heap files are bound to the same committed generation.
asadb_exec_sql_snapshot_limited(SQL, MaxRows, Result) :-
    catch(( asadb_require_snapshot_read_only(SQL),
            asadb_with_tvcc_snapshot(asadb_exec_sql_limited(SQL, MaxRows, Result))
          ),
          Error,
          Result = error(runtime_error, Error)).

asadb_exec_sql_snapshot_page(SQL, Offset, MaxRows, Result) :-
    catch(( asadb_require_snapshot_read_only(SQL),
            asadb_with_tvcc_snapshot(asadb_exec_sql_page(SQL, Offset, MaxRows, Result))
          ),
          Error,
          Result = error(runtime_error, Error)).

asadb_snapshot_read_allowed(SQL) :-
    \+ asadb_transaction_active,
    asadb_parse_sql(SQL, Statements),
    Statements = [_|_],
    snapshot_read_only_statements(Statements).

snapshot_read_only_statements([Statement|Statements]) :-
    snapshot_read_only_statement(Statement),
    snapshot_read_only_statements(Statements).
snapshot_read_only_statements([]) :- !.

snapshot_read_only_statement(select(_, _, _, _, _, _)).

asadb_require_snapshot_read_only(SQL) :-
    asadb_snapshot_read_allowed(SQL), !.
asadb_require_snapshot_read_only(_) :-
    throw(error(permission_error(execute, tvcc_snapshot, read_only_select_required), _)).

:- meta_predicate asadb_with_tvcc_snapshot(0).

asadb_with_tvcc_snapshot(Goal) :-
    ( asadb_tx_snapshot(_) ->
        throw(error(permission_error(execute, tvcc_snapshot,
                                     active_transaction), _))
    ; asadb_tvcc_acquire(Generation, State, StoreRoot, Database)
    ),
    setup_call_cleanup(
        ( assertz(asadb_tvcc_read_state(State)),
          assertz(asadb_tvcc_read_db(Database))
        ),
        asadb_record_with_root(StoreRoot, Goal),
        ( retractall(asadb_tvcc_read_state(_)),
          retractall(asadb_tvcc_read_db(_)),
          asadb_tvcc_release(Generation)
        )
    ).

tvcc_selected_database(Database) :- asadb_current_db(Database), !.
tvcc_selected_database(none).

valid_result_page_number(Value) :- integer(Value), Value >= 0.

with_query_batch(Goal) :-
    begin_query_batch(Outermost),
    call_cleanup(Goal, end_query_batch(Outermost)).

begin_query_batch(true) :-
    \+ asadb_query_batch_depth(_), !,
    assertz(asadb_query_batch_depth(1)).
begin_query_batch(false) :-
    retract(asadb_query_batch_depth(Depth0)),
    Depth is Depth0 + 1,
    assertz(asadb_query_batch_depth(Depth)).

end_query_batch(false) :-
    retract(asadb_query_batch_depth(Depth0)), !,
    Depth is max(1, Depth0 - 1),
    assertz(asadb_query_batch_depth(Depth)).
end_query_batch(true) :-
    retractall(asadb_query_batch_depth(_)),
    ( asadb_tvcc_read_state(_) -> true
    ; asadb_tx_snapshot(_) -> true
    ; asadb_checkpoint_dirty -> asadb_save
    ; true
    ).

% Execution stays in the stateful core.  The SQL frontend only produces ASTs;
% batching consecutive INSERT statements here retains the previous atomic
% execution and checkpoint semantics.
execute_many([], []).
execute_many([insert(Table, Columns, Rows)|Stmts], [Result|Results]) :- !,
    collect_insert_run(Stmts, Table, Columns, [Rows], RowGroups, Rest),
    append(RowGroups, CombinedRows),
    once(catch(execute_statement(insert(Table, Columns, CombinedRows), Result),
               Error,
               Result = error(runtime_error, Error))),
    execute_many(Rest, Results).
execute_many([Stmt|Stmts], [Result|Results]) :-
    once(catch(execute_statement(Stmt, Result), Error, Result = error(runtime_error, Error))),
    execute_many(Stmts, Results).

collect_insert_run([insert(NextTable, NextColumns, NextRows)|Stmts],
                   Table, Columns, Groups0, Groups, Rest) :-
    same_identifier(Table, NextTable),
    same_identifier_list(Columns, NextColumns), !,
    collect_insert_run(Stmts, Table, Columns, [NextRows|Groups0], Groups, Rest).
collect_insert_run(Rest, _, _, RevGroups, Groups, Rest) :-
    reverse(RevGroups, Groups).

same_identifier_list([], []).
same_identifier_list([A|As], [B|Bs]) :-
    same_identifier(A, B),
    same_identifier_list(As, Bs).

limit_top_level_statement(MaxRows,
                          select(Projection, Source, Where, Group, Order, Limit0),
                          select(Projection, Source, Where, Group, Order, Limit)) :- !,
    cap_result_limit(MaxRows, Limit0, Limit).
limit_top_level_statement(MaxRows,
                          select(Projection, Source, Where, Order, Limit0),
                          select(Projection, Source, Where, Order, Limit)) :- !,
    cap_result_limit(MaxRows, Limit0, Limit).
limit_top_level_statement(_, Statement, Statement).

page_top_level_statement(Offset, MaxRows,
                         select(Projection, Source, Where, Group, Order, Limit0),
                         select(Projection, Source, Where, Group, Order, Limit)) :- !,
    page_result_limit(Offset, MaxRows, Limit0, Limit).
page_top_level_statement(Offset, MaxRows,
                         select(Projection, Source, Where, Order, Limit0),
                         select(Projection, Source, Where, Order, Limit)) :- !,
    page_result_limit(Offset, MaxRows, Limit0, Limit).
page_top_level_statement(_, _, Statement, Statement).

page_result_limit(Offset, MaxRows, none, limit(Offset, MaxRows)) :- !.
page_result_limit(Offset, MaxRows, limit(ExistingOffset, ExistingCount),
                  limit(NewOffset, PageCount)) :- !,
    NewOffset is ExistingOffset + Offset,
    Remaining is max(0, ExistingCount - Offset),
    PageCount is min(MaxRows, Remaining).
page_result_limit(Offset, MaxRows, limit(ExistingCount), limit(Offset, PageCount)) :- !,
    Remaining is max(0, ExistingCount - Offset),
    PageCount is min(MaxRows, Remaining).
page_result_limit(Offset, MaxRows, _, limit(Offset, MaxRows)).

cap_result_limit(MaxRows, none, limit(0, MaxRows)) :- !.
cap_result_limit(MaxRows, limit(Offset, Count), limit(Offset, Capped)) :- !,
    Capped is min(MaxRows, Count).
cap_result_limit(MaxRows, limit(Count), limit(Capped)) :- !,
    Capped is min(MaxRows, Count).
cap_result_limit(_, Limit, Limit).

asadb_parse_sql(SQL, Statements) :-
    asadb_jit_parse(SQL, asadb_sql_frontend:asadb_parse_sql, Statements).

asadb_analyze_sql(SQL, Diagnostics) :-
    asadb_sql_frontend:asadb_analyze_sql(SQL, Diagnostics).

/* -------------------------------------------------------------------------
   Bounded Prolog VM/JITI specialization
   ------------------------------------------------------------------------- */

hot_filter_cache_max_entries(128).

reset_logic_jit :-
    with_mutex(asadb_logic_jit,
        ( retractall(asadb_hot_filter(_, _)),
          retractall(asadb_hot_filter_cache(_, _, _, _, _)),
          retractall(asadb_hot_filter_tick(_)),
          assertz(asadb_hot_filter_tick(0)),
          flag(asadb_jit_filter_hits, _, 0),
          flag(asadb_jit_filter_misses, _, 0)
        )),
    asadb_jit_reset.

prepare_row_filter(true, always) :- !.
prepare_row_filter(Expression, compiled(PlanId)) :-
    ground(Expression),
    asadb_jit_filter_body(Expression, Row, Body), !,
    term_hash(Expression, Hash),
    with_mutex(asadb_logic_jit,
        cached_or_compile_filter(Hash, Expression, Row, Body, PlanId)).
prepare_row_filter(Expression, interpreted(Expression)).

cached_or_compile_filter(Hash, Expression, _, _, PlanId) :-
    % Refresh the LRU position on each hit.  The expression check deliberately
    % precedes the cut: two distinct expressions may share term_hash/2.
    asadb_hot_filter_cache(Hash, CachedExpression, PlanId, ClauseRef, OldTick),
    Expression == CachedExpression, !,
    retract(asadb_hot_filter_cache(Hash, CachedExpression, PlanId, ClauseRef,
                                   OldTick)),
    next_hot_filter_tick(NewTick),
    assertz(asadb_hot_filter_cache(Hash, CachedExpression, PlanId, ClauseRef,
                                   NewTick)),
    increment_logic_jit_flag(asadb_jit_filter_hits).
cached_or_compile_filter(Hash, Expression, Row, Body, PlanId) :-
    increment_logic_jit_flag(asadb_jit_filter_misses),
    next_hot_filter_tick(PlanId),
    assertz((asadb_hot_filter(PlanId, Row) :- Body), ClauseRef),
    assertz(asadb_hot_filter_cache(Hash, Expression, PlanId, ClauseRef, PlanId)),
    trim_hot_filter_cache.

next_hot_filter_tick(Tick) :-
    ( retract(asadb_hot_filter_tick(Tick0)) -> true ; Tick0 = 0 ),
    Tick is Tick0 + 1,
    assertz(asadb_hot_filter_tick(Tick)).

trim_hot_filter_cache :-
    aggregate_all(count, asadb_hot_filter_cache(_, _, _, _, _), Count),
    hot_filter_cache_max_entries(Max),
    ( Count =< Max -> true
    ; findall(Tick-entry(Hash, Expression, PlanId, ClauseRef),
              asadb_hot_filter_cache(Hash, Expression, PlanId, ClauseRef, Tick),
              Entries),
      keysort(Entries,
              [_-entry(OldHash, OldExpression, OldPlanId, OldClauseRef)|_]),
      catch(erase(OldClauseRef), _, true),
      retractall(asadb_hot_filter_cache(OldHash, OldExpression, OldPlanId,
                                        OldClauseRef, _))
    ).

row_filter_matches(always, _).
row_filter_matches(compiled(PlanId), Row) :-
    % SQL WHERE is semidet: a row either matches once or does not match.
    % Some compatible truth predicates have more than one Prolog proof (for
    % example numeric 1), so never let proof multiplicity duplicate SQL rows.
    asadb_hot_filter(PlanId, Row), !.
row_filter_matches(interpreted(Expression), Row) :-
    row_matches(Row, Expression).

increment_logic_jit_flag(Name) :-
    flag(Name, Old, Old),
    New is Old + 1,
    flag(Name, _, New).

logic_jit_stats(Jit) :-
    asadb_jit_stats(ParseStats),
    with_mutex(asadb_logic_jit,
               logic_filter_jit_stats(ParseStats, Jit)).

logic_filter_jit_stats(ParseStats, Jit) :-
    aggregate_all(count, asadb_hot_filter_cache(_, _, _, _, _),
                  FilterEntries),
    hot_filter_cache_max_entries(FilterLimit),
    flag(asadb_jit_filter_hits, FilterHits, FilterHits),
    flag(asadb_jit_filter_misses, FilterMisses, FilterMisses),
    put_dict(_{
        filter_cache_entries:FilterEntries,
        filter_cache_limit:FilterLimit,
        filter_hits:FilterHits,
        filter_misses:FilterMisses,
        backend:'SWI-Prolog VM + JITI',
        native_code:false
    }, ParseStats, Jit).

/* -------------------------------------------------------------------------
   Executor
   ------------------------------------------------------------------------- */

execute_statement(unsupported_mysql55(alter_table, raw([kw(table)|Rest])), Result) :-
    asadb_parse_statement([kw(alter),kw(table)|Rest], Statement), !,
    execute_statement(Statement, Result).
execute_statement(unsupported_mysql55(Feature, Raw), error(mysql55_feature_not_implemented, feature(Feature, Raw))) :- !.
execute_statement(unsupported_mysql55(Raw), error(mysql55_feature_not_implemented, Raw)) :- !.

execute_statement(create_database(Name), ok(created_database(Name))) :-
    update_state(create_db(Name)).

execute_statement(use_database(Name), ok(using_database(Name))) :-
    asadb_state(State),
    ( db_exists(State, Name) ->
        retractall(asadb_current_db(_)), assertz(asadb_current_db(Name))
    ; update_state(create_db(Name)), retractall(asadb_current_db(_)), assertz(asadb_current_db(Name))
    ),
    persist_current_db(Name),
    % `USE` changes the database context without changing table pages. Publish
    % a catalog-equivalent generation so a snapshot never combines an older
    % catalog/store with a newer selected database.
    asadb_file(File),
    asadb_state(CurrentState),
    asadb_tvcc_publish(File, CurrentState, Name).

execute_statement(drop_database(Name), ok(dropped_database(Name))) :-
    update_state(drop_db(Name)),
    ( asadb_current_db(Name) ->
        retractall(asadb_current_db(_)),
        clear_persisted_current_db
    ; true ).

execute_statement(create_table(Name, Columns, Options), ok(created_table(Name))) :-
    current_db_or_default(DB),
    table_option_constraints(Options, Constraints),
    validate_table_constraints(DB, Columns, Constraints),
    update_state(create_table(DB, Name, Columns, Constraints)).

execute_statement(drop_table(Name), ok(dropped_table(Name))) :-
    current_db_or_default(DB), update_state(drop_table(DB, Name)).

execute_statement(truncate_table(Name), ok(truncated_table(Name))) :-
    current_db_or_default(DB), update_state(truncate_table(DB, Name)).

execute_statement(insert(Table, Columns, Rows), ok(inserted(Table, Count))) :-
    current_db_or_default(DB),
    eval_insert_rows(Rows, ValueRows),
    length(ValueRows, Count),
    require_privilege(insert, DB, Table),
    update_state(insert_rows(DB, Table, Columns, ValueRows)).

execute_statement(union(Left, Right, Mode), table(Columns, OutRows)) :-
    execute_statement(Left, table(Columns, LeftRows)),
    execute_statement(Right, table(RightColumns, RightRows)),
    same_length(Columns, RightColumns),
    append(LeftRows, RightRows, Rows),
    union_rows(Mode, Rows, OutRows).

execute_statement(select(Projection, table_ref(Table, _Alias), true, none, _Order, Limit),
                  table([Label], OutRows)) :-
    count_all_projection(Projection, Label),
    current_db_or_default(DB),
    require_privilege(select, DB, Table),
    get_table_storage(DB, Table, table(Table, _Columns, paged_rows(_StoreId, Count, _Counters), _Indexes)), !,
    note_plan(metadata_count_scan),
    aggregate_limit_rows(Limit, [Count], OutRows).

execute_statement(select(Projection, table_ref(Table, Alias), Where, none, _Order, Limit), table(OutColumns, OutRows)) :-
    select_needs_grouping(Projection, none),
    current_db_or_default(DB),
    require_privilege(select, DB, Table),
    get_table_storage(DB, Table, table(Table, Columns, RowStorage, Indexes)),
    paged_row_storage(RowStorage), !,
    storage_aggregate_rows(DB, Table, Alias, Columns, Indexes, RowStorage,
                           Projection, Where, Limit, OutColumns, OutRows).

execute_statement(select(Projection, table_ref(Table, Alias), Where, none, Order, Limit), table(OutColumns, OutRows)) :-
    \+ select_needs_grouping(Projection, none),
    current_db_or_default(DB),
    require_privilege(select, DB, Table),
    get_table_storage(DB, Table, table(Table, Columns, RowStorage, Indexes)),
    paged_row_storage(RowStorage), !,
    storage_required_columns(Projection, Where, Order, RequiredColumns),
    storage_source_rows_for_select(DB, Table, Alias, Columns, Indexes,
                                   RowStorage, Where, Order, Limit,
                                   RequiredColumns, Filtered),
    project_rows(Projection, Columns, Filtered, OutColumns, OutRows).

execute_statement(select(Projection, Source, Where, Group, Order, Limit), table(OutColumns, OutRows)) :-
    current_db_or_default(DB),
    require_source_privileges(DB, Source),
    % Push predicates that belong to one side of a JOIN into that source
    % before materializing it.  Without this, a query such as
    % `... JOIN ... WHERE c.company_id <= 20` loaded both 250k-row tables,
    % built the join, and only then discarded 249,980 left rows.  The
    % residual WHERE is still evaluated below, preserving exact semantics for
    % mixed predicates and OR expressions.
    build_source_rows_filtered(DB, Source, Where, Columns, Rows0),
    Rows = Rows0,
    filter_rows(Where, Rows, Filtered0),
    ( select_needs_grouping(Projection, Group) ->
        project_grouped_rows(Projection, Group, Filtered0, OutColumns, GroupRows),
        apply_order(Order, GroupRows, Ordered0),
        apply_limit(Limit, Ordered0, Limited0),
        rows_to_lists(OutColumns, Limited0, OutRows)
    ;   apply_order(Order, Filtered0, Ordered),
        apply_limit(Limit, Ordered, Filtered),
        project_rows(Projection, Columns, Filtered, OutColumns, OutRows)
    ).

execute_statement(select(Projection, Table, Where, Order, Limit), table(OutColumns, OutRows)) :-
    current_db_or_default(DB),
    require_privilege(select, DB, Table),
    get_table_storage(DB, Table, table(Table, Columns, RowStorage, Indexes)),
    ( paged_row_storage(RowStorage) ->
        storage_rows(DB, Table, RowStorage, Indexes, Where, Order, Limit, Filtered)
    ; maybe_index_filter(DB, Table, Where, Indexes, RowStorage, CandidateRows),
      filter_rows(Where, CandidateRows, Filtered0),
      apply_order(Order, Filtered0, Ordered),
      apply_limit(Limit, Ordered, Filtered)
    ),
    project_rows(Projection, Columns, Filtered, OutColumns, OutRows).

execute_statement(create_index(Name, Table, Columns, Unique), ok(created_index(Name, Table))) :-
    current_db_or_default(DB),
    require_privilege(alter, DB, Table),
    update_state(create_index(DB, Table, Name, Columns, Unique)).

execute_statement(drop_index(Name, Table), ok(dropped_index(Name, Table))) :-
    current_db_or_default(DB),
    require_privilege(alter, DB, Table),
    update_state(drop_index(DB, Table, Name)).

execute_statement(alter_table(Table, Operations), ok(altered_table(Table))) :-
    current_db_or_default(DB),
    require_privilege(alter, DB, Table),
    update_state(alter_table(DB, Table, Operations)).

execute_statement(create_view(Name, SelectAST), ok(created_view(Name))) :-
    current_db_or_default(DB),
    require_privilege(create, DB, '*'),
    update_state(create_view(DB, Name, SelectAST)).

execute_statement(drop_view(Name), ok(dropped_view(Name))) :-
    current_db_or_default(DB),
    require_privilege(drop, DB, Name),
    update_state(drop_view(DB, Name)).

execute_statement(create_procedure(Name, Params, Body), ok(created_procedure(Name))) :-
    current_db_or_default(DB),
    require_privilege(create, DB, '*'),
    update_state(create_procedure(DB, Name, Params, Body)).

execute_statement(drop_procedure(Name), ok(dropped_procedure(Name))) :-
    current_db_or_default(DB),
    require_privilege(drop, DB, '*'),
    update_state(drop_procedure(DB, Name)).

execute_statement(create_function(Name, Params, RetType, Body), ok(created_function(Name))) :-
    current_db_or_default(DB),
    require_privilege(create, DB, '*'),
    update_state(create_function(DB, Name, Params, RetType, Body)).

execute_statement(drop_function(Name), ok(dropped_function(Name))) :-
    current_db_or_default(DB),
    require_privilege(drop, DB, '*'),
    update_state(drop_function(DB, Name)).

execute_statement(create_trigger(Name, Event, Timing, Table, Body), ok(created_trigger(Name))) :-
    current_db_or_default(DB),
    require_privilege(create, DB, '*'),
    update_state(create_trigger(DB, Name, Event, Timing, Table, Body)).

execute_statement(drop_trigger(Name), ok(dropped_trigger(Name))) :-
    current_db_or_default(DB),
    require_privilege(drop, DB, '*'),
    update_state(drop_trigger(DB, Name)).

execute_statement(update(Table, Assignments, Where), ok(updated(Table, Count))) :-
    current_db_or_default(DB),
    require_privilege(update, DB, Table),
    update_state(update_rows(DB, Table, Assignments, Where, Count)).

execute_statement(delete(Table, Where), ok(deleted(Table, Count))) :-
    current_db_or_default(DB),
    require_privilege(delete, DB, Table),
    update_state(delete_rows(DB, Table, Where, Count)).

execute_statement(show_index(Name), table([table,non_unique,key_name,seq_in_index,column_name], Rows)) :-
    current_db_or_default(DB),
    get_table(DB, Name, table(Name, _Columns, _Rows, Indexes)),
    indexes_rows(Name, Indexes, Rows).

execute_statement(show_columns(Name), table([field,type,null,key,default,extra], Rows)) :-
    execute_statement(describe_table(Name), table([field,type,null,key,default,extra], Rows)).

execute_statement(show_create_table(Name), table(['Table','Create Table'], [[Name, SQL]])) :-
    current_db_or_default(DB),
    get_table(DB, Name, table(Name, Columns, _Rows, Indexes)),
    create_table_sql(Name, Columns, Indexes, SQL).

execute_statement(start_transaction, ok(started_transaction)) :-
    start_transaction_snapshot.

execute_statement(commit_transaction, ok(committed)) :-
    commit_transaction_snapshot.

execute_statement(rollback_transaction, ok(rolled_back)) :-
    rollback_transaction_snapshot.

execute_statement(lock_tables(Targets), ok(locked_tables(Tables))) :-
    resolve_lock_targets(Targets, Tables),
    lock_write_tables(Tables).

execute_statement(unlock_tables, ok(unlocked_tables)) :-
    retractall(asadb_write_lock(_)).

execute_statement(create_user(User, Password), ok(created_user(User))) :-
    update_state(create_user(User, Password)).

execute_statement(drop_user(User), ok(dropped_user(User))) :-
    update_state(drop_user(User)).

execute_statement(grant_privilege(Privilege, Scope, User), ok(granted(Privilege, Scope, User))) :-
    update_state(grant_privilege(User, Privilege, Scope)).

execute_statement(revoke_privilege(Privilege, Scope, User), ok(revoked(Privilege, Scope, User))) :-
    update_state(revoke_privilege(User, Privilege, Scope)).

execute_statement(show_grants(User), table(['Grants for user'], Rows)) :-
    grants_for_user(User, Grants),
    grants_rows(User, Grants, Rows).

execute_statement(login_user(User, Password), ok(logged_in(User))) :-
    authenticate_user(User, Password),
    retractall(asadb_current_user(_)),
    assertz(asadb_current_user(User)).

execute_statement(show_databases, table([database], Rows)) :-
    asadb_visible_state(state(_, DBs)), db_names(DBs, Names), atoms_rows(Names, Rows).

execute_statement(show_tables, table([table], Rows)) :-
    current_db_or_default(DB),
    get_db(DB, db(DB, Tables, Views, _, _, _)),
    table_names(Tables, TableNames),
    view_names(Views, ViewNames),
    append(TableNames, ViewNames, Names0),
    sort(Names0, Names),
    atoms_rows(Names, Rows).

execute_statement(describe_table(Name), table([field,type,null,key,default,extra], Rows)) :-
    current_db_or_default(DB),
    get_table(DB, Name, table(_, Columns, _, Indexes)), describe_columns(Columns, Indexes, Rows).

execute_statement(explain(Statement), table([id,select_type,table,access,index,estimated_rows,extra], Rows)) :- !,
    explain_statement_plan(Statement, Rows).
execute_statement(explain(raw(Rest)), error(explain_unsupported_statement, Rest)).

execute_statement(Stmt, error(unknown_statement, Stmt)).

% EXPLAIN is derived from the same catalog/index predicates used by execution.
% The estimates are intentionally transparent heuristics until persistent
% ANALYZE statistics exist: no fake cost number is presented as measurement.
explain_statement_plan(select(_, table_ref(Table, _), Where, _Group, Order, _Limit), Rows) :- !,
    current_db_or_default(DB),
    get_table_storage(DB, Table, table(Table, _Columns, Storage, Indexes)),
    row_storage_count(Storage, TotalRows),
    explain_table_access(Where, Order, Indexes, TotalRows, Access, IndexName,
                         EstimatedRows, Extra),
    Rows = [[1,'SIMPLE',Table,Access,IndexName,EstimatedRows,Extra]].
explain_statement_plan(select(_, Table, Where, Order, _Limit), Rows) :-
    atom(Table), !,
    current_db_or_default(DB),
    get_table_storage(DB, Table, table(Table, _Columns, Storage, Indexes)),
    row_storage_count(Storage, TotalRows),
    explain_table_access(Where, Order, Indexes, TotalRows, Access, IndexName,
                         EstimatedRows, Extra),
    Rows = [[1,'SIMPLE',Table,Access,IndexName,EstimatedRows,Extra]].
explain_statement_plan(select(_, Source, _Where, _Group, _Order, _Limit),
                       [[1,'COMPLEX',Source,'EXECUTOR',null,null,
                         'join/group plan uses executor fallback']]) :- !.
explain_statement_plan(Statement, _) :-
    throw(error(domain_error(explainable_statement, Statement), _)).

explain_table_access(Where, Order, Indexes, TotalRows, Access, IndexName,
                     EstimatedRows, Extra) :-
    indexed_column_predicate(Where, Indexes, Column, Operator, _Value),
    member(index(IndexName, IndexColumns, Unique), Indexes),
    IndexColumns = [IndexedColumn|_],
    same_identifier(Column, IndexedColumn), !,
    explain_index_access(Operator, Unique, IndexColumns, TotalRows, Access, EstimatedRows),
    explain_extra(Order, Indexes, Column, Extra).
explain_table_access(_Where, Order, Indexes, TotalRows, 'TABLE SCAN', null,
                     TotalRows, Extra) :-
    explain_scan_extra(Order, Indexes, Extra).

explain_index_access('=', unique, [_], _TotalRows, 'UNIQUE INDEX LOOKUP', 1) :- !.
explain_index_access('=', _, _, TotalRows, 'INDEX LOOKUP', EstimatedRows) :- !,
    EstimatedRows is max(1, ceiling(TotalRows / 10)).
explain_index_access(_, _, _, TotalRows, 'INDEX RANGE SCAN', EstimatedRows) :-
    EstimatedRows is max(1, ceiling(TotalRows / 3)).

explain_extra(Order, Indexes, Column, 'index filter; order satisfied by index') :-
    indexed_storage_order(Order, Indexes, OrderColumn, _),
    same_identifier(Column, OrderColumn), !.
explain_extra(Order, Indexes, _, 'index filter; explicit sort') :-
    Order \== none,
    \+ indexed_storage_order(Order, Indexes, _, _), !.
explain_extra(_, _, _, 'index filter').

explain_scan_extra(Order, Indexes, 'table scan; explicit sort') :-
    Order \== none,
    \+ indexed_storage_order(Order, Indexes, _, _), !.
explain_scan_extra(_, _, 'table scan').

union_rows(all, Rows, Rows) :- !.
union_rows(distinct, Rows, UniqueRows) :- sort(Rows, UniqueRows).

current_db_or_default(DB) :- asadb_tvcc_read_db(DB), DB \== none, !.
current_db_or_default(DB) :- asadb_current_db(DB), !.
current_db_or_default(main) :-
    asadb_state(State),
    ( db_exists(State, main) -> true ; update_state(create_db(main)) ),
    retractall(asadb_current_db(_)),
    assertz(asadb_current_db(main)),
    persist_current_db(main).

eval_insert_rows([], []).
eval_insert_rows([Exprs|Rows], [Values|Out]) :-
    eval_insert_values(Exprs, Values),
    eval_insert_rows(Rows, Out).

eval_insert_values([], []).
eval_insert_values([value(Value)|Exprs], [Value|Values]) :- !,
    eval_insert_values(Exprs, Values).
eval_insert_values([col(Name)|Exprs], [Name|Values]) :- !,
    eval_insert_values(Exprs, Values).
eval_insert_values([qcol(Qualifier, Name)|Exprs], [Value|Values]) :- !,
    qualified_column_atom(Qualifier, Name, Value),
    eval_insert_values(Exprs, Values).
eval_insert_values([Expr|Exprs], [Value|Values]) :-
    eval_expr(row([]), Expr, Value), !,
    eval_insert_values(Exprs, Values).
eval_insert_values([Value|Exprs], [Value|Values]) :-
    eval_insert_values(Exprs, Values).

require_source_privileges(DB, Source) :-
    source_tables(Source, Tables),
    require_source_table_privileges(DB, Tables).

require_source_table_privileges(_, []).
require_source_table_privileges(DB, [Table|Tables]) :-
    require_privilege(select, DB, Table),
    require_source_table_privileges(DB, Tables).

source_tables(table_ref(Table, _), [Table]) :- !.
source_tables(join(_, Left, Right, _), Tables) :-
    source_tables(Left, LT),
    source_tables(Right, RT),
    append(LT, RT, Tables).

build_source_rows(DB, table_ref(Table, Alias), Columns, SourceRows) :-
    get_table_existing(DB, Table, table(Table, Columns, Rows, _Indexes)), !,
    source_qualifiers(Table, Alias, Qualifiers),
    table_rows_to_source_rows(Table, Qualifiers, Columns, Rows, SourceRows).
build_source_rows(DB, table_ref(View, Alias), Columns, SourceRows) :-
    get_view(DB, View, view(View, SelectAST, _CreatedAt)), !,
    execute_statement(SelectAST, table(Labels, RowLists)),
    labels_to_columns(Labels, Columns),
    rows_from_value_lists(Labels, RowLists, Rows),
    source_qualifiers(View, Alias, Qualifiers),
    table_rows_to_source_rows(View, Qualifiers, Columns, Rows, SourceRows).
build_source_rows(DB, join(Kind, Left, Right, On), Columns, JoinedRows) :-
    build_source_rows(DB, Left, LeftColumns, LeftRows),
    build_source_rows(DB, Right, RightColumns, RightRows),
    join_side_columns(Left, LeftColumns, LeftOutColumns),
    join_side_columns(Right, RightColumns, RightOutColumns),
    append(LeftOutColumns, RightOutColumns, Columns),
    source_null_row(Right, RightColumns, NullRight),
    source_null_row(Left, LeftColumns, NullLeft),
    join_rows(Kind, LeftRows, RightRows, NullLeft, NullRight, On,
              Left, Right, JoinedRows).

% Build source rows while pushing safe, source-local WHERE conjuncts down into
% JOIN inputs.  This is deliberately conservative: an expression mentioning
% both inputs, an unqualified column, or a non-conjunctive predicate remains a
% residual filter at the normal SELECT stage.
build_source_rows_filtered(DB, table_ref(Table, Alias), Where, Columns, SourceRows) :-
    % Keep paged tables lazy.  get_table_existing/3 materializes the complete
    % heap, which defeats predicate pushdown before storage_source_rows/10 can
    % apply its bounded scan.
    get_table_storage(DB, Table, table(Table, Columns, RowStorage, Indexes)), !,
    source_qualifiers(Table, Alias, Qualifiers),
    source_where_for_storage(Where, StorageWhere),
    ( paged_row_storage(RowStorage) ->
        storage_source_rows(DB, Table, Alias, Columns, Indexes, RowStorage,
                            StorageWhere, none, source_fetch_all_limit, SourceRows)
    ; table_rows_to_source_rows(Table, Qualifiers, Columns, RowStorage, Rows0),
      filter_rows(StorageWhere, Rows0, SourceRows)
    ).
build_source_rows_filtered(DB, table_ref(View, Alias), _Where, Columns, SourceRows) :-
    get_view(DB, View, view(View, SelectAST, _CreatedAt)), !,
    execute_statement(SelectAST, table(Labels, RowLists)),
    labels_to_columns(Labels, Columns),
    rows_from_value_lists(Labels, RowLists, Rows),
    source_qualifiers(View, Alias, Qualifiers),
    table_rows_to_source_rows(View, Qualifiers, Columns, Rows, SourceRows).
% For an INNER/LEFT equality JOIN whose right side is a paged table, use its
% persistent B+Tree directly for the already-filtered left keys.  This avoids
% materializing a second 250k-row table merely to discover the twenty matching
% status rows in the common Double_Company-shaped query.
build_source_rows_filtered(DB, join(Kind, Left, Right, On), Where, Columns, JoinedRows) :-
    memberchk(Kind, [inner,left]),
    split_join_source_where(Where, Left, Right, LeftWhere, RightWhere),
    % A right-side predicate changes which rows are eligible after the key
    % lookup, so leave that case to the general filtered-source path.  Check
    % this before touching either source to avoid duplicate work on
    % backtracking.
    RightWhere = true,
    build_source_rows_filtered(DB, Left, LeftWhere, LeftColumns, LeftRows),
    length(LeftRows, LeftCount),
    LeftCount =< 4096,
    equi_join_expressions(On, Left, Right, LeftExpr, RightExpr),
    build_join_lookup_rows(DB, Right, LeftRows, LeftExpr, RightExpr,
                           RightColumns, RightRows),
    join_side_columns(Left, LeftColumns, LeftOutColumns),
    join_side_columns(Right, RightColumns, RightOutColumns),
    append(LeftOutColumns, RightOutColumns, Columns),
    source_null_row(Right, RightColumns, NullRight),
    source_null_row(Left, LeftColumns, NullLeft),
    join_rows(Kind, LeftRows, RightRows, NullLeft, NullRight, On,
              Left, Right, JoinedRows), !.
build_source_rows_filtered(DB, join(Kind, Left, Right, On), Where, Columns, JoinedRows) :-
    split_join_source_where(Where, Left, Right, LeftWhere, RightWhere),
    build_source_rows_filtered(DB, Left, LeftWhere, LeftColumns, LeftRows),
    build_source_rows_filtered(DB, Right, RightWhere, RightColumns, RightRows),
    join_side_columns(Left, LeftColumns, LeftOutColumns),
    join_side_columns(Right, RightColumns, RightOutColumns),
    append(LeftOutColumns, RightOutColumns, Columns),
    source_null_row(Right, RightColumns, NullRight),
    source_null_row(Left, LeftColumns, NullLeft),
    join_rows(Kind, LeftRows, RightRows, NullLeft, NullRight, On,
              Left, Right, JoinedRows).

build_join_lookup_rows(DB, table_ref(Table, Alias), LeftRows, LeftExpr,
                       qcol(_, RightColumn), Columns, SourceRows) :-
    get_table_storage(DB, Table,
                      table(Table, Columns, paged_rows(StoreId, _, _), Indexes)),
    source_qualifiers(Table, Alias, Qualifiers),
    join_lookup_left_keys(LeftRows, LeftExpr, Keys),
    ( join_lookup_unique_column(RightColumn, Indexes) ->
        % A unique key is sufficient to answer this small lookup without
        % building a persistent B+Tree on demand.  This matters immediately
        % after a bulk import.  For the common append-ordered integer key,
        % read only the prefix that can contain the requested keys; if that
        % conservative check does not hold, fall back to a complete scan.
        ( join_lookup_prefix_limit(Keys, PrefixLimit),
          findnsols(PrefixLimit, BaseRow,
                    asadb_record_scan(StoreId, _, BaseRow), PrefixRows),
          prefix_rows_cover_keys(PrefixRows, RightColumn, Keys) ->
            include(base_row_has_join_key(RightColumn, Keys),
                    PrefixRows, MatchedRows),
            maplist(table_row_to_source_row(Table, Qualifiers, Columns),
                    MatchedRows, SourceRows)
        ;   findall(SourceRow,
                ( asadb_record_scan(StoreId, _, BaseRow),
                  BaseRow = row(BasePairs),
                  lookup_value(RightColumn, BasePairs, Key),
                      join_lookup_key_member(Key, Keys),
                      table_row_to_source_row(Table, Qualifiers, Columns,
                                              BaseRow, SourceRow)
                    ),
                    SourceRows)
        )
    ;   ensure_persistent_btree(DB, Table, StoreId, RightColumn, File),
        findall(SourceRow,
                ( member(Key, Keys),
                  asadb_btree_file_candidate(File, '=', Key, Rid),
                  asadb_record_read(StoreId, Rid, BaseRow),
                  table_row_to_source_row(Table, Qualifiers, Columns,
                                          BaseRow, SourceRow)
                ),
                SourceRows)
    ), !.

join_lookup_left_keys(LeftRows, LeftExpr, Keys) :-
    findall(Key,
            ( member(LeftRow, LeftRows),
              eval_expr(LeftRow, LeftExpr, Key)
            ), RawKeys),
    sort(RawKeys, Keys).

join_lookup_unique_column(Column, Indexes) :-
    member(index(_, [IndexedColumn], unique), Indexes),
    same_identifier(Column, IndexedColumn), !.

join_lookup_key_member(Key, [Candidate|_]) :- sql_equal(Key, Candidate), !.
join_lookup_key_member(Key, [_|Keys]) :- join_lookup_key_member(Key, Keys).

join_lookup_prefix_limit(Keys, Limit) :-
    Keys \= [],
    maplist(positive_integer_key, Keys),
    max_list(Keys, Limit),
    Limit =< 4096.

positive_integer_key(Key) :- integer(Key), Key > 0.

prefix_rows_cover_keys(Rows, Column, Keys) :-
    forall(member(Key, Keys),
           ( member(row(Pairs), Rows),
             lookup_value(Column, Pairs, Found),
             sql_equal(Key, Found) )).

base_row_has_join_key(Column, Keys, row(Pairs)) :-
    lookup_value(Column, Pairs, Key),
    join_lookup_key_member(Key, Keys).

source_where_for_storage(Where, StorageWhere) :-
    source_where_unqualify(Where, StorageWhere).

source_where_unqualify(true, true) :- !.
source_where_unqualify(qcol(_, Name), col(Name)) :- !.
source_where_unqualify(col(Name), col(Name)) :- !.
source_where_unqualify(value(Value), value(Value)) :- !.
source_where_unqualify(cmp(Op, A, B), cmp(Op, UA, UB)) :- !,
    source_where_unqualify(A, UA),
    source_where_unqualify(B, UB).
source_where_unqualify(and(A, B), and(UA, UB)) :- !,
    source_where_unqualify(A, UA),
    source_where_unqualify(B, UB).
source_where_unqualify(or(A, B), or(UA, UB)) :- !,
    source_where_unqualify(A, UA),
    source_where_unqualify(B, UB).
source_where_unqualify(xor(A, B), xor(UA, UB)) :- !,
    source_where_unqualify(A, UA),
    source_where_unqualify(B, UB).
source_where_unqualify(not(A), not(UA)) :- !, source_where_unqualify(A, UA).
source_where_unqualify(is_null(A), is_null(UA)) :- !, source_where_unqualify(A, UA).
source_where_unqualify(is_not_null(A), is_not_null(UA)) :- !, source_where_unqualify(A, UA).
source_where_unqualify(like(A, B), like(UA, UB)) :- !,
    source_where_unqualify(A, UA),
    source_where_unqualify(B, UB).
source_where_unqualify(in_list(A, Values), in_list(UA, UValues)) :- !,
    source_where_unqualify(A, UA),
    maplist(source_where_unqualify, Values, UValues).
source_where_unqualify(between(A, Low, High), between(UA, ULow, UHigh)) :- !,
    source_where_unqualify(A, UA),
    source_where_unqualify(Low, ULow),
    source_where_unqualify(High, UHigh).
source_where_unqualify(Expr, Expr).

split_join_source_where(Where, LeftSource, RightSource, LeftWhere, RightWhere) :-
    split_where_conjuncts(Where, Parts),
    include(expr_only_source_for(LeftSource), Parts, LeftParts),
    include(expr_only_source_for(RightSource), Parts, RightParts),
    conjunction_from_parts(LeftParts, LeftWhere),
    conjunction_from_parts(RightParts, RightWhere).

expr_only_source_for(Source, Expr) :- expr_only_source(Expr, Source).

expr_only_source(cmp(_, A, B), Side) :- !,
    expr_only_source(A, Side),
    expr_only_source(B, Side).
expr_only_source(and(A, B), Side) :- !,
    expr_only_source(A, Side),
    expr_only_source(B, Side).
expr_only_source(or(A, B), Side) :- !,
    expr_only_source(A, Side),
    expr_only_source(B, Side).
expr_only_source(xor(A, B), Side) :- !,
    expr_only_source(A, Side),
    expr_only_source(B, Side).
expr_only_source(not(A), Side) :- !, expr_only_source(A, Side).
expr_only_source(is_null(A), Side) :- !, expr_only_source(A, Side).
expr_only_source(is_not_null(A), Side) :- !, expr_only_source(A, Side).
expr_only_source(like(A, B), Side) :- !,
    expr_only_source(A, Side),
    expr_only_source(B, Side).
expr_only_source(in_list(A, Values), Side) :- !,
    expr_only_source(A, Side),
    maplist(expr_only_source_side(Side), Values).
expr_only_source(between(A, Low, High), Side) :- !,
    expr_only_source(A, Side),
    expr_only_source(Low, Side),
    expr_only_source(High, Side).
expr_only_source(qcol(Qualifier, _), Source) :-
    source_has_qualifier(Source, Qualifier).
expr_only_source(value(_), _) :- !.
expr_only_source_side(Side, Expr) :- expr_only_source(Expr, Side).

split_where_conjuncts(and(A, B), Parts) :- !,
    split_where_conjuncts(A, Left),
    split_where_conjuncts(B, Right),
    append(Left, Right, Parts).
split_where_conjuncts(Where, [Where]).

conjunction_from_parts([], true).
conjunction_from_parts([Part], Part) :- !.
conjunction_from_parts([Part|Parts], and(Part, Rest)) :-
    conjunction_from_parts(Parts, Rest).

maybe_source_index_filter(DB, table_ref(Table, none), Where, Rows, CandidateRows) :-
    get_table_existing(DB, Table, table(Table, _Columns, _BaseRows, Indexes)),
    !,
    maybe_index_filter(DB, Table, Where, Indexes, Rows, CandidateRows).
maybe_source_index_filter(_, _, _, Rows, Rows).

source_qualifiers(Table, none, [Table]) :- !.
source_qualifiers(Table, Alias, [Alias, Table]).

table_rows_to_source_rows(_, _, _, [], []).
table_rows_to_source_rows(Table, Qualifiers, Columns, [Row|Rows], [SourceRow|Out]) :-
    table_row_to_source_row(Table, Qualifiers, Columns, Row, SourceRow),
    table_rows_to_source_rows(Table, Qualifiers, Columns, Rows, Out).

table_row_to_source_row(_, Qualifiers, Columns, row(Pairs), row(SourcePairs)) :-
    columns_source_pairs(Columns, Qualifiers, Pairs, SourcePairs).

columns_source_pairs([], _, _, []).
columns_source_pairs([col(Name,_,_)|Columns], Qualifiers, Pairs, SourcePairs) :-
    lookup_value(Name, Pairs, Value),
    qualified_pairs(Qualifiers, Name, Value, QPairs),
    columns_source_pairs(Columns, Qualifiers, Pairs, Rest),
    append([Name=Value|QPairs], Rest, SourcePairs).

qualified_pairs([], _, _, []).
qualified_pairs([Qualifier|Qualifiers], Name, Value, [q(Qualifier,Name)=Value, Atom=Value|Pairs]) :-
    qualified_column_atom(Qualifier, Name, Atom),
    qualified_pairs(Qualifiers, Name, Value, Pairs).

qualified_column_atom(Qualifier, Name, Atom) :-
    atomic_list_concat([Qualifier, '.', Name], Atom).

join_side_columns(table_ref(Table, Alias), Columns, OutColumns) :- !,
    source_display_qualifier(Table, Alias, Qualifier),
    qualify_display_columns(Qualifier, Columns, OutColumns).
join_side_columns(join(_,_,_,_), Columns, Columns).

source_display_qualifier(Table, none, Table) :- !.
source_display_qualifier(_, Alias, Alias).

qualify_display_columns(_, [], []).
qualify_display_columns(Qualifier, [col(Name,Type,Options)|Columns], [col(Label,Type,Options)|Out]) :-
    qualified_column_atom(Qualifier, Name, Label),
    qualify_display_columns(Qualifier, Columns, Out).

source_null_row(table_ref(Table, Alias), Columns, Row) :- !,
    source_qualifiers(Table, Alias, Qualifiers),
    null_pairs_for_columns(Columns, Qualifiers, Pairs),
    Row = row(Pairs).
source_null_row(join(_, _, _, _), Columns, row(Pairs)) :-
    null_pairs_for_display_columns(Columns, Pairs).

null_pairs_for_columns([], _, []).
null_pairs_for_columns([col(Name,_,_)|Columns], Qualifiers, [Name=null|Pairs]) :-
    qualified_pairs(Qualifiers, Name, null, QPairs),
    null_pairs_for_columns(Columns, Qualifiers, Rest),
    append(QPairs, Rest, Pairs).

null_pairs_for_display_columns([], []).
null_pairs_for_display_columns([col(Name,_,_)|Columns], [Name=null|Pairs]) :-
    null_pairs_for_display_columns(Columns, Pairs).

join_rows(Kind, LeftRows, RightRows, NullLeft, NullRight, On,
          LeftSource, RightSource, JoinedRows) :-
    equi_join_expressions(On, LeftSource, RightSource, LeftExpr, RightExpr), !,
    note_plan(indexed_join),
    indexed_join_rows(Kind, LeftRows, RightRows, NullLeft, NullRight,
                      LeftExpr, RightExpr, JoinedRows).
join_rows(inner, LeftRows, RightRows, _, _, On, _, _, JoinedRows) :- !,
    note_plan(nested_loop_join),
    prepare_row_filter(On, Filter),
    findall(Joined,
            ( member(L, LeftRows),
              member(R, RightRows),
              combine_rows(L, R, Joined),
              row_filter_matches(Filter, Joined)
            ),
            JoinedRows).
join_rows(left, LeftRows, RightRows, _, NullRight, On, _, _, JoinedRows) :- !,
    note_plan(nested_loop_join),
    prepare_row_filter(On, Filter),
    left_join_rows(LeftRows, RightRows, NullRight, Filter, JoinedRows).
join_rows(right, LeftRows, RightRows, NullLeft, _, On, _, _, JoinedRows) :- !,
    note_plan(nested_loop_join),
    prepare_row_filter(On, Filter),
    right_join_rows(RightRows, LeftRows, NullLeft, Filter, JoinedRows).

% A simple qualified equality is the overwhelmingly common JOIN shape.  The
% old implementation compared every left row with every right row (O(n*m)).
% Resolve which operand belongs to each source and use an AVL-backed lookup
% index instead.  Complex ON predicates deliberately retain the compatible
% nested-loop fallback above.
equi_join_expressions(and(A, B), LeftSource, RightSource,
                      tuple(LeftExprs), tuple(RightExprs)) :-
    equi_join_expression_list(and(A, B), LeftSource, RightSource,
                              LeftExprs, RightExprs),
    LeftExprs = [_,_|_], !.
equi_join_expressions(cmp('=', qcol(QA, CA), qcol(QB, CB)),
                      LeftSource, RightSource,
                      qcol(QA, CA), qcol(QB, CB)) :-
    source_has_qualifier(LeftSource, QA),
    source_has_qualifier(RightSource, QB), !.
equi_join_expressions(cmp('=', qcol(QA, CA), qcol(QB, CB)),
                      LeftSource, RightSource,
                      qcol(QB, CB), qcol(QA, CA)) :-
    source_has_qualifier(LeftSource, QB),
    source_has_qualifier(RightSource, QA).

equi_join_expression_list(and(A, B), LeftSource, RightSource,
                          LeftExprs, RightExprs) :- !,
    equi_join_expression_list(A, LeftSource, RightSource, LeftA, RightA),
    equi_join_expression_list(B, LeftSource, RightSource, LeftB, RightB),
    append(LeftA, LeftB, LeftExprs),
    append(RightA, RightB, RightExprs).
equi_join_expression_list(Expression, LeftSource, RightSource,
                          [LeftExpr], [RightExpr]) :-
    equi_join_expressions(Expression, LeftSource, RightSource,
                          LeftExpr, RightExpr).

source_has_qualifier(table_ref(Table, none), Qualifier) :- !,
    same_identifier(Table, Qualifier).
source_has_qualifier(table_ref(Table, Alias), Qualifier) :-
    ( same_identifier(Alias, Qualifier)
    ; same_identifier(Table, Qualifier)
    ), !.
source_has_qualifier(join(_, Left, Right, _), Qualifier) :-
    ( source_has_qualifier(Left, Qualifier)
    ; source_has_qualifier(Right, Qualifier)
    ).

indexed_join_rows(inner, LeftRows, RightRows, _, _, LeftExpr, RightExpr, Rows) :- !,
    build_join_index(RightRows, RightExpr, Index),
    indexed_inner_rows(LeftRows, LeftExpr, Index, Rows).
indexed_join_rows(left, LeftRows, RightRows, _, NullRight, LeftExpr, RightExpr, Rows) :- !,
    build_join_index(RightRows, RightExpr, Index),
    indexed_left_rows(LeftRows, LeftExpr, Index, NullRight, Rows).
indexed_join_rows(right, LeftRows, RightRows, NullLeft, _, LeftExpr, RightExpr, Rows) :- !,
    build_join_index(LeftRows, LeftExpr, Index),
    indexed_right_rows(RightRows, RightExpr, Index, NullLeft, Rows).

build_join_index(Rows, Expr, Index) :-
    empty_assoc(Empty),
    build_join_index_rows(Rows, Expr, Empty, ReversedIndex),
    map_assoc(reverse, ReversedIndex, Index).

build_join_index_rows([], _, Index, Index).
build_join_index_rows([Row|Rows], Expr, Index0, Index) :-
    eval_expr(Row, Expr, Value),
    join_index_key(Value, Key),
    ( get_assoc(Key, Index0, Existing) -> Bucket = [Row|Existing]
    ; Bucket = [Row]
    ),
    put_assoc(Key, Index0, Bucket, Index1),
    build_join_index_rows(Rows, Expr, Index1, Index).

join_index_key(Value, number(NumberKey)) :-
    comparable_number(Value, Number), !,
    NumberKey is rationalize(Number).
join_index_key(Value, term(Value)).

indexed_inner_rows([], _, _, []).
indexed_inner_rows([Left|LeftRows], LeftExpr, Index, Rows) :-
    indexed_matches(Left, LeftExpr, Index, Matches),
    combine_left_bucket(Left, Matches, Joined),
    append(Joined, Rest, Rows),
    indexed_inner_rows(LeftRows, LeftExpr, Index, Rest).

indexed_left_rows([], _, _, _, []).
indexed_left_rows([Left|LeftRows], LeftExpr, Index, NullRight, Rows) :-
    indexed_matches(Left, LeftExpr, Index, Matches),
    ( Matches = [] ->
        combine_rows(Left, NullRight, Joined),
        Rows = [Joined|Rest]
    ; combine_left_bucket(Left, Matches, JoinedRows),
      append(JoinedRows, Rest, Rows)
    ),
    indexed_left_rows(LeftRows, LeftExpr, Index, NullRight, Rest).

indexed_right_rows([], _, _, _, []).
indexed_right_rows([Right|RightRows], RightExpr, Index, NullLeft, Rows) :-
    indexed_matches(Right, RightExpr, Index, Matches),
    ( Matches = [] ->
        combine_rows(NullLeft, Right, Joined),
        Rows = [Joined|Rest]
    ; combine_right_bucket(Matches, Right, JoinedRows),
      append(JoinedRows, Rest, Rows)
    ),
    indexed_right_rows(RightRows, RightExpr, Index, NullLeft, Rest).

indexed_matches(Row, Expr, Index, Matches) :-
    eval_expr(Row, Expr, Value),
    join_index_key(Value, Key),
    ( get_assoc(Key, Index, Matches) -> true ; Matches = [] ).

combine_left_bucket(_, [], []).
combine_left_bucket(Left, [Right|Rights], [Joined|Rows]) :-
    combine_rows(Left, Right, Joined),
    combine_left_bucket(Left, Rights, Rows).

combine_right_bucket([], _, []).
combine_right_bucket([Left|Lefts], Right, [Joined|Rows]) :-
    combine_rows(Left, Right, Joined),
    combine_right_bucket(Lefts, Right, Rows).

left_join_rows([], _, _, _, []).
left_join_rows([L|Ls], RightRows, NullRight, Filter, Rows) :-
    findall(Joined,
            ( member(R, RightRows),
              combine_rows(L, R, Joined),
              row_filter_matches(Filter, Joined)
            ),
            Matches),
    ( Matches = [] ->
        combine_rows(L, NullRight, NullJoined),
        Rows = [NullJoined|Rest]
    ;   append(Matches, Rest, Rows)
    ),
    left_join_rows(Ls, RightRows, NullRight, Filter, Rest).

right_join_rows([], _, _, _, []).
right_join_rows([R|Rs], LeftRows, NullLeft, Filter, Rows) :-
    findall(Joined,
            ( member(L, LeftRows),
              combine_rows(L, R, Joined),
              row_filter_matches(Filter, Joined)
            ),
            Matches),
    ( Matches = [] ->
        combine_rows(NullLeft, R, NullJoined),
        Rows = [NullJoined|Rest]
    ;   append(Matches, Rest, Rows)
    ),
    right_join_rows(Rs, LeftRows, NullLeft, Filter, Rest).

combine_rows(row(L), row(R), row(Pairs)) :- append(L, R, Pairs).

update_state(Action) :-
    with_mutex(asadb_write, update_state_locked(Action)).

update_state_raw(Action) :-
    with_mutex(asadb_write, update_state_locked(Action)).

update_state_locked(Action) :-
    ensure_write_allowed(Action),
    asadb_state(State),
    apply_action(Action, State, NewState),
    retractall(asadb_state(_)),
    assertz(asadb_state(NewState)),
    ( State == NewState -> true
    ; invalidate_index_cache(Action),
      asadb_tvcc_mark_change(Action),
      mark_changed_action_for_checkpoint(Action),
      persist_state_after_write(Action)
    ).

% Catalog bootstrap may append recovery information during boot, but it is not
% a user commit. Every user-visible change marks a checkpoint so the TVCC
% publisher receives a durable catalog and durable record pages at batch end.
mark_changed_action_for_checkpoint(ensure_catalog(_)) :- !.
mark_changed_action_for_checkpoint(_) :- assert_checkpoint_dirty.

persist_state_after_write(_) :- asadb_tx_snapshot(_), !.
persist_state_after_write(Action) :- paged_storage_action(Action), !,
    assert_checkpoint_dirty,
    ( asadb_query_batch_depth(_) -> true ; asadb_save_locked ).
persist_state_after_write(Action) :- append_wal(Action).

assert_checkpoint_dirty :-
    ( asadb_checkpoint_dirty -> true ; assertz(asadb_checkpoint_dirty) ).

paged_storage_action(create_table(_, _, _)).
paged_storage_action(create_table(_, _, _, _)).
paged_storage_action(drop_table(_, _)).
paged_storage_action(truncate_table(_, _)).
paged_storage_action(insert_rows(_, _, _, _)).
paged_storage_action(update_rows(_, _, _, _, _)).
paged_storage_action(delete_rows(_, _, _)).
paged_storage_action(alter_table(_, _, _)).

ensure_write_allowed(Action) :-
    action_table(Action, DB, Table),
    asadb_write_lock(Locks), !,
    ( member(DB-Table, Locks) -> true ; throw(error(write_lock_violation(DB, Table), Action)) ).
ensure_write_allowed(_).

action_table(create_table(DB, Table, _), DB, Table).
action_table(create_table(DB, Table, _, _), DB, Table).
action_table(drop_table(DB, Table), DB, Table).
action_table(truncate_table(DB, Table), DB, Table).
action_table(insert_rows(DB, Table, _, _), DB, Table).
action_table(update_rows(DB, Table, _, _, _), DB, Table).
action_table(delete_rows(DB, Table, _), DB, Table).
action_table(create_index(DB, Table, _, _, _), DB, Table).
action_table(drop_index(DB, Table, _), DB, Table).

invalidate_index_cache(Action) :-
    action_table(Action, DB, Table), !,
    retractall(asadb_btree_cache(DB, Table, _, _)),
    retractall(asadb_index_probe_count(DB, Table, _, _)).
invalidate_index_cache(drop_db(DB)) :- !,
    retractall(asadb_btree_cache(DB, _, _, _)),
    retractall(asadb_index_probe_count(DB, _, _, _)).
invalidate_index_cache(create_db(_)) :- !.
invalidate_index_cache(_) :-
    true.

start_transaction_snapshot :-
    with_mutex(asadb_write, start_transaction_snapshot_locked).

start_transaction_snapshot_locked :-
    asadb_tx_snapshot(_), !.
start_transaction_snapshot_locked :-
    asadb_state(State),
    assertz(asadb_tx_snapshot(State)),
    asadb_record_tx_begin.

commit_transaction_snapshot :-
    with_mutex(asadb_write, commit_transaction_snapshot_locked).

commit_transaction_snapshot_locked :-
    asadb_tx_snapshot(_), !,
    retractall(asadb_tx_snapshot(_)),
    asadb_save_locked,
    asadb_record_tx_commit.
commit_transaction_snapshot_locked.

rollback_transaction_snapshot :-
    with_mutex(asadb_write, rollback_transaction_snapshot_locked).

rollback_transaction_snapshot_locked :-
    retract(asadb_tx_snapshot(State)), !,
    asadb_record_tx_rollback,
    retractall(asadb_state(_)),
    assertz(asadb_state(State)).
rollback_transaction_snapshot_locked.

resolve_lock_targets([], []).
resolve_lock_targets([lock_target(current, Table)|Targets], [DB-Table|Tables]) :- !,
    current_db_or_default(DB),
    resolve_lock_targets(Targets, Tables).
resolve_lock_targets([lock_target(DB, Table)|Targets], [DB-Table|Tables]) :-
    resolve_lock_targets(Targets, Tables).

lock_write_tables(Tables) :-
    retractall(asadb_write_lock(_)),
    assertz(asadb_write_lock(Tables)).

apply_action(ensure_catalog(Catalog), State, NewState) :-
    ensure_db(State, Catalog, S1),
    catalog_table(users, Users),
    catalog_table(grants, Grants),
    transform_db(Catalog, S1, ensure_table(Users), S2),
    transform_db(Catalog, S2, ensure_table(Grants), NewState).

apply_action(create_db(Name), state(V, DBs), state(V, NewDBs)) :-
    ( db_member(Name, DBs, _) -> NewDBs = DBs ; NewDBs = [db(Name, [], [], [], [], [])|DBs] ).
apply_action(drop_db(Name), state(V, DBs), state(V, NewDBs)) :-
    ( db_member(Name, DBs, db(_, Tables, _, _, _, _)) -> drop_table_stores(Tables) ; true ),
    remove_db(Name, DBs, NewDBs).
apply_action(create_table(DB, Name, Columns), State, NewState) :-
    ensure_db(State, DB, S1),
    default_indexes(Name, Columns, Indexes),
    transform_db(DB, S1, create_table_in_db(Name, Columns, Indexes), NewState).
apply_action(create_table(DB, Name, Columns, Constraints), State, NewState) :-
    ensure_db(State, DB, S1),
    table_indexes(Name, Columns, Constraints, Indexes),
    transform_db(DB, S1, create_table_in_db(Name, Columns, Indexes), NewState).
apply_action(drop_table(DB, Name), State, NewState) :- transform_db(DB, State, drop_table_in_db(Name), NewState).
apply_action(truncate_table(DB, Name), State, NewState) :- transform_db(DB, State, truncate_table_in_db(Name), NewState).
apply_action(insert_rows(DB, Table, Columns, Rows), State, NewState) :- transform_db(DB, State, insert_rows_in_db(Table, Columns, Rows), NewState).
apply_action(update_rows(DB, Table, Assignments, Where, Count), State, NewState) :- transform_db(DB, State, update_rows_in_db(Table, Assignments, Where, Count), NewState).
apply_action(delete_rows(DB, Table, Where, Count), State, NewState) :- transform_db(DB, State, delete_rows_in_db(Table, Where, Count), NewState).
apply_action(create_index(DB, Table, Name, Columns, Unique), State, NewState) :- transform_db(DB, State, create_index_in_db(Table, Name, Columns, Unique), NewState).
apply_action(drop_index(DB, Table, Name), State, NewState) :- transform_db(DB, State, drop_index_in_db(Table, Name), NewState).
apply_action(alter_table(DB, Table, Operations), State, NewState) :- transform_db(DB, State, alter_table_in_db(Table, Operations), NewState).
apply_action(create_view(DB, Name, SelectAST), State, NewState) :- transform_db(DB, State, create_view_in_db(Name, SelectAST), NewState).
apply_action(drop_view(DB, Name), State, NewState) :- transform_db(DB, State, drop_view_in_db(Name), NewState).
apply_action(create_procedure(DB, Name, Params, Body), State, NewState) :- transform_db(DB, State, create_procedure_in_db(Name, Params, Body), NewState).
apply_action(drop_procedure(DB, Name), State, NewState) :- transform_db(DB, State, drop_procedure_in_db(Name), NewState).
apply_action(create_function(DB, Name, Params, RetType, Body), State, NewState) :- transform_db(DB, State, create_function_in_db(Name, Params, RetType, Body), NewState).
apply_action(drop_function(DB, Name), State, NewState) :- transform_db(DB, State, drop_function_in_db(Name), NewState).
apply_action(create_trigger(DB, Name, Event, Timing, Table, Body), State, NewState) :- transform_db(DB, State, create_trigger_in_db(Name, Event, Timing, Table, Body), NewState).
apply_action(drop_trigger(DB, Name), State, NewState) :- transform_db(DB, State, drop_trigger_in_db(Name), NewState).
apply_action(create_user(User, Password), State, NewState) :-
    catalog_db(Catalog),
    transform_db(Catalog, State, upsert_row(users, [user=User,password=Password,created_at=manual]), NewState).
apply_action(drop_user(User), State, NewState) :-
    catalog_db(Catalog),
    transform_db(Catalog, State, delete_rows_in_db(users, cmp('=', col(user), value(User)), _), S1),
    transform_db(Catalog, S1, delete_rows_in_db(grants, cmp('=', col(user), value(User)), _), NewState).
apply_action(grant_privilege(User, Privilege, Scope), State, NewState) :-
    catalog_db(Catalog),
    transform_db(Catalog, State, upsert_row(grants, [user=User,privilege=Privilege,scope=Scope]), NewState).
apply_action(revoke_privilege(User, Privilege, Scope), State, NewState) :-
    catalog_db(Catalog),
    Where = and(cmp('=', col(user), value(User)), and(cmp('=', col(privilege), value(Privilege)), cmp('=', col(scope), value(Scope)))),
    transform_db(Catalog, State, delete_rows_in_db(grants, Where, _), NewState).

% Helper to apply multiple ALTER operations to table
apply_alter_operations([], Cols0, Rows0, Idxs0, Cols, Rows, Idxs) :-
    dedupe_columns(Cols0, Cols),
    normalize_rows_for_columns(Cols, Rows0, Rows),
    normalize_indexes_for_columns(Cols, Idxs0, Idxs).
apply_alter_operations([Op|Ops], Cols0, Rows0, Idxs0, Cols, Rows, Idxs) :-
    apply_single_alter(Op, Cols0, Rows0, Idxs0, Cols1, Rows1, Idxs1),
    apply_alter_operations(Ops, Cols1, Rows1, Idxs1, Cols, Rows, Idxs).

% Apply individual ALTER operations
apply_single_alter(add_column(Name, _Type, _Options), Cols, Rows, Idxs, Cols, Rows, Idxs) :-
    column_exists(Name, Cols), !.

apply_single_alter(add_column(Name, Type, Options), Cols, Rows, Idxs, NewCols, NewRows, Idxs) :- !,
    append(Cols, [col(Name, Type, Options)], NewCols),
    add_column_to_rows(Name, Options, Rows, NewRows).

apply_single_alter(drop_column(Name), Cols, Rows, Idxs, NewCols, NewRows, Idxs) :- !,
    remove_column(Name, Cols, NewCols),
    remove_column_from_rows(Name, Rows, NewRows).

apply_single_alter(modify_column(Name, Type, Options), Cols, Rows, Idxs, NewCols, Rows, Idxs) :- !,
    modify_column_def(Name, Type, Options, Cols, NewCols).

apply_single_alter(rename_column(OldName, NewName, Type, Options), Cols, Rows, Idxs, NewCols, NewRows, NewIdxs) :- !,
    replace_column_def(OldName, col(NewName, Type, Options), Cols, NewCols),
    rename_column_in_rows(OldName, NewName, Rows, NewRows),
    rename_column_in_indexes(OldName, NewName, Idxs, NewIdxs).

apply_single_alter(rename_column_simple(OldName, NewName), Cols, Rows, Idxs, NewCols, NewRows, NewIdxs) :- !,
    rename_column_in_cols(OldName, NewName, Cols, NewCols),
    rename_column_in_rows(OldName, NewName, Rows, NewRows),
    rename_column_in_indexes(OldName, NewName, Idxs, NewIdxs).

apply_single_alter(rename_table(_NewName), Cols, Rows, Idxs, Cols, Rows, Idxs) :- !.
    % Table rename is handled at the apply_db_action level

add_column_to_rows(_, _, [], []).
add_column_to_rows(Name, Options, [row(Pairs)|Rows], [row(NewPairs)|NewRows]) :-
    alter_column_initial_value(Options, Value),
    append(Pairs, [Name=Value], NewPairs),
    add_column_to_rows(Name, Options, Rows, NewRows).

alter_column_initial_value(Options, Value) :-
    option_default(Options, Value), !.
alter_column_initial_value(_, null).

% Remove a column from column list
remove_column(_, [], []).
remove_column(Name, [col(Existing,_,_)|Cols], Rest) :-
    same_identifier(Name, Existing), !,
    remove_column(Name, Cols, Rest).
remove_column(Name, [Col|Cols], [Col|Rest]) :- remove_column(Name, Cols, Rest).

% Remove a column from all rows
remove_column_from_rows(_, [], []).
remove_column_from_rows(ColName, [row(Pairs)|Rows], [row(NewPairs)|NewRows]) :-
    remove_pair_by_key(ColName, Pairs, NewPairs),
    remove_column_from_rows(ColName, Rows, NewRows).

% Helper to remove a key-value pair from a list
remove_pair_by_key(_, [], []).
remove_pair_by_key(Key, [Existing=_|Pairs], Rest) :-
    same_identifier(Key, Existing), !,
    remove_pair_by_key(Key, Pairs, Rest).
remove_pair_by_key(Key, [Pair|Pairs], [Pair|Rest]) :- remove_pair_by_key(Key, Pairs, Rest).

% Modify a column definition
modify_column_def(Name, Type, Options, Cols, NewCols) :-
    replace_column_def(Name, col(Name, Type, Options), Cols, NewCols).

replace_column_def(_, _, [], []).
replace_column_def(Name, NewCol, [col(Existing,_,_)|Cols], [NewCol|Cols]) :-
    same_identifier(Name, Existing), !.
replace_column_def(Name, NewCol, [Col|Cols], [Col|Rest]) :-
    replace_column_def(Name, NewCol, Cols, Rest).

% Rename a column in column list
rename_column_in_cols(_, _, [], []).
rename_column_in_cols(OldName, NewName, [col(Existing, Type, Options)|Cols], [col(NewName, Type, Options)|Rest]) :-
    same_identifier(OldName, Existing), !,
    rename_column_in_cols(OldName, NewName, Cols, Rest).
rename_column_in_cols(OldName, NewName, [Col|Cols], [Col|Rest]) :-
    rename_column_in_cols(OldName, NewName, Cols, Rest).

% Rename a column in all rows
rename_column_in_rows(_, _, [], []).
rename_column_in_rows(OldName, NewName, [row(Pairs)|Rows], [row(NewPairs)|NewRows]) :-
    rename_pair_key(OldName, NewName, Pairs, NewPairs),
    rename_column_in_rows(OldName, NewName, Rows, NewRows).

% Helper to rename a key in a key-value pair list
rename_pair_key(_, _, [], []).
rename_pair_key(OldName, NewName, [Existing=Value|Pairs], [NewName=Value|Rest]) :-
    same_identifier(OldName, Existing), !,
    rename_pair_key(OldName, NewName, Pairs, Rest).
rename_pair_key(OldName, NewName, [Pair|Pairs], [Pair|Rest]) :-
    rename_pair_key(OldName, NewName, Pairs, Rest).

% Rename a column in indexes
rename_column_in_indexes(_, _, [], []).
rename_column_in_indexes(OldName, NewName, [index(IdxName, Cols, Unique)|Idxs], [index(IdxName, NewCols, Unique)|Rest]) :-
    rename_in_list(OldName, NewName, Cols, NewCols),
    rename_column_in_indexes(OldName, NewName, Idxs, Rest).

% Helper to rename in a list
rename_in_list(_, _, [], []).
rename_in_list(OldName, NewName, [Existing|List], [NewName|Rest]) :-
    same_identifier(OldName, Existing), !,
    rename_in_list(OldName, NewName, List, Rest).
rename_in_list(OldName, NewName, [Item|List], [Item|Rest]) :-
    rename_in_list(OldName, NewName, List, Rest).

ensure_db(state(V, DBs), Name, state(V, DBs)) :- db_member(Name, DBs, _), !.
ensure_db(state(V, DBs), Name, state(V, [db(Name, [], [], [], [], [])|DBs])).

db_exists(state(_, DBs), Name) :- db_member(Name, DBs, _).

remove_db(_, [], []).
remove_db(Name, [db(Name,_,_,_,_,_)|DBs], New) :- !, remove_db(Name, DBs, New).
remove_db(Name, [db(Name,_)|DBs], New) :- !, remove_db(Name, DBs, New).
remove_db(Name, [DB|DBs], [DB|New]) :- remove_db(Name, DBs, New).

db_member(Name, [db(Name, Tables, Views, Functions, Procedures, Triggers)|_], db(Name, Tables, Views, Functions, Procedures, Triggers)) :- !.
db_member(Name, [db(Name, Tables)|_], db(Name, Tables, [], [], [], [])) :- !.
db_member(Name, [_|DBs], DB) :- db_member(Name, DBs, DB).

transform_db(DBName, state(V, DBs), Action, state(V, NewDBs)) :-
    transform_db_list(DBName, DBs, Action, NewDBs).

transform_db_list(DBName, [], Action, [NewDB]) :- apply_db_action(Action, db(DBName, [], [], [], [], []), NewDB), !.
transform_db_list(DBName, [db(DBName, Tables, Views, Functions, Procedures, Triggers)|DBs], Action, [NewDB|DBs]) :- !,
    apply_db_action(Action, db(DBName, Tables, Views, Functions, Procedures, Triggers), NewDB).
transform_db_list(DBName, [db(DBName, Tables)|DBs], Action, [NewDB|DBs]) :- !,
    apply_db_action(Action, db(DBName, Tables, [], [], [], []), NewDB).
transform_db_list(DBName, [DB|DBs], Action, [DB|NewDBs]) :- transform_db_list(DBName, DBs, Action, NewDBs).

apply_db_action(ensure_table(Table), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    table_name(Table, Name),
    ( table_member(Name, Tables, _) -> NewTables = Tables ; NewTables = [Table|Tables] ).
apply_db_action(create_table_in_db(Name, Columns, Indexes), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    asadb_record_store_id(DB, Name, StoreId),
    asadb_record_create(StoreId),
    init_auto_counters(Columns, [], Counters),
    New = table(Name, Columns, paged_rows(StoreId, 0, Counters), Indexes),
    ( replace_table(Name, New, Tables, NewTables) -> true
    ; NewTables = [New|Tables]
    ).
apply_db_action(drop_table_in_db(Name), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    ( table_member(Name, Tables, Existing),
      table_parts(Existing, _, _, RowStorage, _) -> drop_row_storage(RowStorage)
    ; true
    ),
    remove_table(Name, Tables, NewTables).
apply_db_action(truncate_table_in_db(Name), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    map_truncate_table(Name, Tables, NewTables).
apply_db_action(insert_rows_in_db(Name, Columns, ValueRows), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, TableColumns, paged_rows(StoreId, Count0, Counters0), Indexes), OtherTables), !,
    build_rows_(TableColumns, Columns, ValueRows, Counters0, Counters, NewRows),
    findall(ExistingRow, asadb_record_scan(StoreId, _, ExistingRow), ExistingRows),
    asadb_schema_validate_insert_rows(TableColumns, Indexes, ExistingRows, NewRows),
    append(ExistingRows, NewRows, CandidateRows),
    validate_table_integrity(Name, TableColumns, Indexes, CandidateRows, OtherTables),
    asadb_record_insert_batch(StoreId, NewRows),
    asadb_record_invalidate_indexes(StoreId),
    length(NewRows, Added),
    Count is Count0 + Added,
    NewTables = [table(Name, TableColumns, paged_rows(StoreId, Count, Counters), Indexes)|OtherTables].
apply_db_action(insert_rows_in_db(Name, Columns, ValueRows), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, TableColumns, Rows, Indexes), OtherTables),
    build_rows(TableColumns, Columns, ValueRows, Rows, NewRows),
    asadb_schema_validate_insert_rows(TableColumns, Indexes, Rows, NewRows),
    append(Rows, NewRows, AllRows),
    validate_table_integrity(Name, TableColumns, Indexes, AllRows, OtherTables),
    NewTables = [table(Name, TableColumns, AllRows, Indexes)|OtherTables].
apply_db_action(update_rows_in_db(Name, Assignments, Where, Count), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, Columns, paged_rows(StoreId, Count0, Counters), Indexes), OtherTables), !,
    asadb_schema_validate_assignment_columns(Columns, Assignments),
    validate_paged_update_integrity(Name, StoreId, Columns, Indexes, Assignments, Where, OtherTables),
    ( paged_indexed_updates(DB, Name, StoreId, Columns, Indexes,
                            Assignments, Where, Updates) ->
        asadb_record_update_batch(StoreId, Updates, Count),
        NewCount = Count0
    ; asadb_record_rewrite(StoreId, paged_update_transform(Assignments, Where), NewCount, Count, _)
    ),
    maybe_invalidate_update_indexes(StoreId, Indexes, Assignments),
    NewTables = [table(Name, Columns, paged_rows(StoreId, NewCount, Counters), Indexes)|OtherTables].
apply_db_action(update_rows_in_db(Name, Assignments, Where, Count), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, Columns, Rows, Indexes), OtherTables),
    asadb_schema_validate_assignment_columns(Columns, Assignments),
    validate_parent_update_restrict(Name, Assignments, Where, Rows, OtherTables),
    update_matching_rows(Rows, Assignments, Where, NewRows, Count),
    asadb_schema_validate_replacement_rows(Columns, Indexes, NewRows),
    validate_table_integrity(Name, Columns, Indexes, NewRows, OtherTables),
    NewTables = [table(Name, Columns, NewRows, Indexes)|OtherTables].
apply_db_action(delete_rows_in_db(Name, Where, Count), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, Columns, paged_rows(StoreId, Count0, Counters), Indexes), OtherTables), !,
    validate_paged_parent_delete_restrict(Name, StoreId, Where, OtherTables),
    ( paged_indexed_deletes(DB, Name, StoreId, Columns, Indexes, Where, Rids) ->
        asadb_record_delete_batch(StoreId, Rids, Count),
        NewCount is Count0 - Count,
        KeepIndexes = true
    ; asadb_record_rewrite(StoreId, paged_delete_transform(Where), NewCount, Count, _),
      KeepIndexes = false
    ),
    ( KeepIndexes == true -> true ; asadb_record_invalidate_indexes(StoreId) ),
    NewTables = [table(Name, Columns, paged_rows(StoreId, NewCount, Counters), Indexes)|OtherTables].
apply_db_action(delete_rows_in_db(Name, Where, Count), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, Columns, Rows, Indexes), OtherTables),
    validate_parent_delete_restrict(Name, Where, Rows, OtherTables),
    delete_matching_rows(Rows, Where, Kept, Count),
    NewTables = [table(Name, Columns, Kept, Indexes)|OtherTables].
apply_db_action(create_index_in_db(Table, Name, Columns, Unique), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Table, Tables, table(Table, TableColumns, Rows, Indexes), OtherTables),
    remove_index(Name, Indexes, Without),
    NewTables = [table(Table, TableColumns, Rows, [index(Name, Columns, Unique)|Without])|OtherTables].
apply_db_action(drop_index_in_db(Table, Name), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Table, Tables, table(Table, Columns, Rows, Indexes), OtherTables),
    remove_index(Name, Indexes, NewIndexes),
    NewTables = [table(Table, Columns, Rows, NewIndexes)|OtherTables].
apply_db_action(alter_table_in_db(Table, Operations), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Table, Tables, table(Table, Columns, paged_rows(StoreId, Count, _Counters), Indexes), OtherTables), !,
    apply_alter_operations(Operations, Columns, [], Indexes, NewColumns, [], NewIndexes),
    asadb_record_rewrite(StoreId, paged_alter_transform(Operations, Columns, Indexes), Count, _, _),
    asadb_record_invalidate_indexes(StoreId),
    paged_auto_counters(NewColumns, StoreId, NewCounters),
    NewTables = [table(Table, NewColumns, paged_rows(StoreId, Count, NewCounters), NewIndexes)|OtherTables].
apply_db_action(alter_table_in_db(Table, Operations), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Table, Tables, table(Table, Columns, Rows, Indexes), OtherTables),
    apply_alter_operations(Operations, Columns, Rows, Indexes, NewColumns, NewRows, NewIndexes),
    NewTables = [table(Table, NewColumns, NewRows, NewIndexes)|OtherTables].
apply_db_action(upsert_row(Table, Pairs), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Table, Tables, table(Table, Columns, Rows, Indexes), OtherTables),
    primary_column(Columns, Key),
    lookup_value(Key, Pairs, KeyValue),
    delete_matching_rows(Rows, cmp('=', col(Key), value(KeyValue)), Kept, _),
    NewTables = [table(Table, Columns, [row(Pairs)|Kept], Indexes)|OtherTables].

paged_update_transform(Assignments, Where, Row, keep(NewRow)) :-
    row_matches(Row, Where), !,
    apply_assignments(Row, Assignments, NewRow).
paged_update_transform(_, _, _, keep).

paged_delete_transform(Where, Row, delete) :- row_matches(Row, Where), !.
paged_delete_transform(_, _, keep).

validate_paged_update_integrity(Name, StoreId, Columns, Indexes, Assignments, Where, OtherTables) :-
    findall(Row, asadb_record_scan(StoreId, _, Row), Rows),
    validate_parent_update_restrict(Name, Assignments, Where, Rows, OtherTables),
    update_matching_rows(Rows, Assignments, Where, CandidateRows, _),
    asadb_schema_validate_replacement_rows(Columns, Indexes, CandidateRows),
    validate_table_integrity(Name, Columns, Indexes, CandidateRows, OtherTables).

validate_paged_parent_delete_restrict(Name, StoreId, Where, OtherTables) :-
    findall(Row, asadb_record_scan(StoreId, _, Row), Rows),
    validate_parent_delete_restrict(Name, Where, Rows, OtherTables).

% Constraint evaluation is deliberately performed before a record-store
% mutation.  This makes a rejected INSERT or UPDATE leave both catalog and
% data pages untouched, including the paged storage path used for large data.
validate_table_integrity(Table, Columns, Indexes, Rows, OtherTables) :-
    validate_column_check_constraints(Table, Columns, Rows),
    validate_check_constraints(Indexes, Rows),
    validate_foreign_key_rows(Table, Indexes, Rows, OtherTables).

validate_column_check_constraints(_, [], _).
validate_column_check_constraints(Table, [col(Column, _, Options)|Columns], Rows) :-
    validate_column_checks(Table, Column, Options, Rows),
    validate_column_check_constraints(Table, Columns, Rows).

validate_column_checks(_, _, [], _).
validate_column_checks(Table, Column, [check(Expr)|Options], Rows) :- !,
    format(atom(Name), '__asadb_check_~w_~w', [Table, Column]),
    validate_check_rows(Name, Expr, Rows),
    validate_column_checks(Table, Column, Options, Rows).
validate_column_checks(Table, Column, [_|Options], Rows) :-
    validate_column_checks(Table, Column, Options, Rows).

validate_check_constraints([], _).
validate_check_constraints([check(Name, Expr)|Indexes], Rows) :- !,
    validate_check_rows(Name, Expr, Rows),
    validate_check_constraints(Indexes, Rows).
validate_check_constraints([_|Indexes], Rows) :-
    validate_check_constraints(Indexes, Rows).

validate_check_rows(_, _, []).
validate_check_rows(Name, Expr, [Row|Rows]) :-
    ( check_constraint_holds(Row, Expr) -> true
    ; throw(error(domain_error(check_constraint(Name), Row), _))
    ),
    validate_check_rows(Name, Expr, Rows).

check_constraint_holds(Row, Expr) :-
    eval_bool(Row, Expr), !.
% SQL CHECK evaluates UNKNOWN (typically because a nullable input is NULL) as
% satisfied. NOT NULL remains the explicit way to reject the NULL itself.
check_constraint_holds(Row, Expr) :-
    expression_has_null_input(Row, Expr), !.

expression_has_null_input(row(Pairs), col(Name)) :- !,
    pair_value_same_identifier(Name, Pairs, null).
expression_has_null_input(row(Pairs), qcol(_, Name)) :- !,
    pair_value_same_identifier(Name, Pairs, null).
expression_has_null_input(Row, Expr) :-
    compound(Expr),
    Expr =.. [_|Arguments],
    member(Argument, Arguments),
    expression_has_null_input(Row, Argument), !.

validate_foreign_key_rows(_, [], _, _).
validate_foreign_key_rows(Table,
                          [foreign_key(Name, LocalColumns, RefTable, RefColumns, restrict, restrict)|Indexes],
                          Rows, OtherTables) :- !,
    foreign_key_parent_rows(Table, RefTable, Rows, OtherTables, ParentRows),
    validate_foreign_key_row_set(Name, LocalColumns, RefTable, RefColumns, Rows, ParentRows),
    validate_foreign_key_rows(Table, Indexes, Rows, OtherTables).
validate_foreign_key_rows(Table, [_|Indexes], Rows, OtherTables) :-
    validate_foreign_key_rows(Table, Indexes, Rows, OtherTables).

foreign_key_parent_rows(Table, RefTable, CandidateRows, _OtherTables, CandidateRows) :-
    same_identifier(Table, RefTable), !.
foreign_key_parent_rows(_, RefTable, _, OtherTables, ParentRows) :-
    table_member(RefTable, OtherTables, ParentTable),
    table_parts(ParentTable, _, _, ParentStorage, _),
    materialize_rows(ParentStorage, ParentRows).

validate_foreign_key_row_set(_, _, _, _, [], _).
validate_foreign_key_row_set(Name, LocalColumns, RefTable, RefColumns, [Row|Rows], ParentRows) :-
    row_key_values(LocalColumns, Row, LocalValues),
    ( memberchk(null, LocalValues) -> true
    ; member(ParentRow, ParentRows),
      row_key_values(RefColumns, ParentRow, ParentValues),
      same_sql_value_lists(LocalValues, ParentValues) -> true
    ; throw(error(existence_error(foreign_key(Name, RefTable), LocalValues), _))
    ),
    validate_foreign_key_row_set(Name, LocalColumns, RefTable, RefColumns, Rows, ParentRows).

row_key_values([], _, []).
row_key_values([Column|Columns], row(Pairs), [Value|Values]) :-
    lookup_value(Column, Pairs, Value),
    row_key_values(Columns, row(Pairs), Values).

same_sql_value_lists([], []).
same_sql_value_lists([A|As], [B|Bs]) :-
    sql_equal(A, B),
    same_sql_value_lists(As, Bs).

% RESTRICT is checked on the parent side too.  Without this companion check a
% child insert would be protected but a later parent DELETE/UPDATE could still
% create an orphan.  We only materialize the relevant table when a declared
% referencing constraint exists; normal deletes retain their indexed path.
validate_parent_delete_restrict(ParentTable, Where, ParentRows, OtherTables) :-
    include_where(ParentRows, Where, DeletedRows),
    validate_referencing_rows(ParentTable, DeletedRows, OtherTables).

validate_parent_update_restrict(ParentTable, Assignments, Where, ParentRows, OtherTables) :-
    include_where(ParentRows, Where, UpdatedRows),
    forall(
        ( dependent_foreign_key(ParentTable, OtherTables, _ChildTable, _ChildRows,
                                _ConstraintName, _LocalColumns, RefColumns),
          assignment_touches_columns(Assignments, RefColumns)
        ),
        validate_referencing_rows(ParentTable, UpdatedRows, OtherTables)
    ).

assignment_touches_columns([assign(Name, _)|_], Columns) :-
    identifier_member(Name, Columns), !.
assignment_touches_columns([_|Assignments], Columns) :-
    assignment_touches_columns(Assignments, Columns).

validate_referencing_rows(_, [], _) :- !.
validate_referencing_rows(ParentTable, ParentRows, OtherTables) :-
    ( dependent_foreign_key(ParentTable, OtherTables, ChildTable, ChildRows,
                            ConstraintName, LocalColumns, RefColumns),
      member(ChildRow, ChildRows),
      row_key_values(LocalColumns, ChildRow, LocalValues),
      \+ memberchk(null, LocalValues),
      member(ParentRow, ParentRows),
      row_key_values(RefColumns, ParentRow, ParentValues),
      same_sql_value_lists(LocalValues, ParentValues) ->
        throw(error(permission_error(delete, referenced_row(ConstraintName), ChildTable), _))
    ; true
    ).

dependent_foreign_key(ParentTable, OtherTables, ChildTable, ChildRows,
                      ConstraintName, LocalColumns, RefColumns) :-
    member(Child, OtherTables),
    table_parts(Child, ChildTable, _, ChildStorage, ChildIndexes),
    member(foreign_key(ConstraintName, LocalColumns, RefTable, RefColumns, restrict, restrict),
           ChildIndexes),
    same_identifier(ParentTable, RefTable),
    materialize_rows(ChildStorage, ChildRows).

paged_indexed_updates(_, _, StoreId, Columns, Indexes,
                      Assignments, Where, Updates) :-
    indexed_column_predicate(Where, Indexes, Col, '=', Value),
    join_lookup_unique_column(Col, Indexes),
    \+ valid_persistent_index(StoreId, Col), !,
    column_names(Columns, ColumnNames),
    ( once((
          asadb_record_scan_columns(StoreId, ColumnNames, [Col], Rid, KeyRow),
          eval_expr(KeyRow, col(Col), Found),
          sql_equal(Found, Value)
      )) ->
        asadb_record_read(StoreId, Rid, Row),
        ( row_matches(Row, Where) ->
            apply_assignments(Row, Assignments, NewRow),
            Updates = [Rid-NewRow]
        ; Updates = []
        )
    ; Updates = []
    ).
paged_indexed_updates(DB, Table, StoreId, _Columns, Indexes,
                      Assignments, Where, Updates) :-
    indexed_column_predicate(Where, Indexes, Col, Op, Value),
    ensure_persistent_btree(DB, Table, StoreId, Col, File),
    findall(Rid-NewRow,
            ( asadb_btree_file_candidate(File, Op, Value, Rid),
              asadb_record_read(StoreId, Rid, Row),
              row_matches(Row, Where),
              apply_assignments(Row, Assignments, NewRow)
            ),
            Updates).

paged_indexed_deletes(_, _, StoreId, Columns, Indexes, Where, Rids) :-
    indexed_column_predicate(Where, Indexes, Col, '=', Value),
    join_lookup_unique_column(Col, Indexes),
    \+ valid_persistent_index(StoreId, Col), !,
    column_names(Columns, ColumnNames),
    ( once((
          asadb_record_scan_columns(StoreId, ColumnNames, [Col], Rid, KeyRow),
          eval_expr(KeyRow, col(Col), Found),
          sql_equal(Found, Value)
      )) ->
        asadb_record_read(StoreId, Rid, Row),
        ( row_matches(Row, Where) -> Rids = [Rid] ; Rids = [] )
    ; Rids = []
    ).
paged_indexed_deletes(DB, Table, StoreId, _Columns, Indexes, Where, Rids) :-
    indexed_column_predicate(Where, Indexes, Col, Op, Value),
    ensure_persistent_btree(DB, Table, StoreId, Col, File),
    findall(Rid,
            ( asadb_btree_file_candidate(File, Op, Value, Rid),
              asadb_record_read(StoreId, Rid, Row),
              row_matches(Row, Where)
            ),
            Rids).

valid_persistent_index(StoreId, Col) :-
    identifier_cache_key(Col, CacheCol),
    asadb_record_index_file(StoreId, CacheCol, File),
    exists_file(File),
    catch(asadb_btree_file_stats(File, _), _, fail).

maybe_invalidate_update_indexes(StoreId, Indexes, Assignments) :-
    assignment_touches_index(Assignments, Indexes), !,
    asadb_record_invalidate_indexes(StoreId).
maybe_invalidate_update_indexes(_, _, _).

assignment_touches_index([assign(Name, _)|_], Indexes) :-
    member(index(_, Columns, _), Indexes),
    identifier_member(Name, Columns), !.
assignment_touches_index([_|Assignments], Indexes) :-
    assignment_touches_index(Assignments, Indexes).

paged_alter_transform(Operations, Columns, Indexes, Row, keep(NewRow)) :-
    apply_alter_operations(Operations, Columns, [Row], Indexes, _, [NewRow], _).

paged_auto_counters(Columns, StoreId, Counters) :-
    paged_auto_counters_(Columns, StoreId, Counters).

paged_auto_counters_([], _, []).
paged_auto_counters_([col(Name, _, Options)|Columns], StoreId, Counters) :-
    auto_increment_column(Options), !,
    ( aggregate_all(max(Number),
          ( asadb_record_scan(StoreId, _, row(Pairs)),
            lookup_value(Name, Pairs, Value),
            numeric_auto_value(Value, Number)
          ), Max0),
      number(Max0) -> Max = Max0
    ; Max = 0
    ),
    Next is Max + 1,
    Counters = [Name-Next|Rest],
    paged_auto_counters_(Columns, StoreId, Rest).
paged_auto_counters_([_|Columns], StoreId, Counters) :-
    paged_auto_counters_(Columns, StoreId, Counters).

drop_row_storage(paged_rows(StoreId, _, _)) :- !, asadb_record_drop(StoreId).
drop_row_storage(_).

% View operations
apply_db_action(create_view_in_db(Name, SelectAST), db(DB, Tables, Views, F, P, T), db(DB, Tables, NewViews, F, P, T)) :-
    get_time(Time),
    NewViews = [view(Name, SelectAST, Time)|Views].
apply_db_action(drop_view_in_db(Name), db(DB, Tables, Views, F, P, T), db(DB, Tables, NewViews, F, P, T)) :-
    remove_view(Name, Views, NewViews).

% Function operations
apply_db_action(create_function_in_db(Name, Params, RetType, Body), db(DB, Tables, V, Functions, P, T), db(DB, Tables, V, NewFunctions, P, T)) :-
    get_time(Time),
    NewFunctions = [function(Name, Params, RetType, Body, Time)|Functions].
apply_db_action(drop_function_in_db(Name), db(DB, Tables, V, Functions, P, T), db(DB, Tables, V, NewFunctions, P, T)) :-
    remove_function(Name, Functions, NewFunctions).

% Procedure operations
apply_db_action(create_procedure_in_db(Name, Params, Body), db(DB, Tables, V, F, Procedures, T), db(DB, Tables, V, F, NewProcedures, T)) :-
    get_time(Time),
    NewProcedures = [procedure(Name, Params, Body, Time)|Procedures].
apply_db_action(drop_procedure_in_db(Name), db(DB, Tables, V, F, Procedures, T), db(DB, Tables, V, F, NewProcedures, T)) :-
    remove_procedure(Name, Procedures, NewProcedures).

% Trigger operations
apply_db_action(create_trigger_in_db(Name, Event, Timing, Table, Body), db(DB, Tables, V, F, P, Triggers), db(DB, Tables, V, F, P, NewTriggers)) :-
    get_time(Time),
    NewTriggers = [trigger(Name, Event, Timing, Table, Body, Time)|Triggers].
apply_db_action(drop_trigger_in_db(Name), db(DB, Tables, V, F, P, Triggers), db(DB, Tables, V, F, P, NewTriggers)) :-
    remove_trigger(Name, Triggers, NewTriggers).
apply_db_action(replace_backup_catalog_objects(Views, Functions, Procedures, Triggers),
                db(DB, Tables, _, _, _, _),
                db(DB, Tables, Views, Functions, Procedures, Triggers)).

replace_table(Name, New, [T|Ts], [New|Ts]) :- table_has_name(T, Name), !.
replace_table(Name, New, [T|Ts], [T|Out]) :- replace_table(Name, New, Ts, Out).

remove_table(_, [], []).
remove_table(Name, [T|Ts], New) :- table_has_name(T, Name), !, remove_table(Name, Ts, New).
remove_table(Name, [T|Ts], [T|New]) :- remove_table(Name, Ts, New).

map_truncate_table(_, [], []).
map_truncate_table(Name, [T|Ts], [NewT|Ts]) :-
    table_parts(T, ActualName, Cols, paged_rows(StoreId, _, _), Indexes),
    same_identifier(Name, ActualName), !,
    asadb_record_truncate(StoreId),
    asadb_record_invalidate_indexes(StoreId),
    init_auto_counters(Cols, [], Counters),
    NewT = table(ActualName, Cols, paged_rows(StoreId, 0, Counters), Indexes).
map_truncate_table(Name, [T|Ts], [NewT|Ts]) :-
    table_parts(T, ActualName, Cols, _Rows, Indexes),
    same_identifier(Name, ActualName), !,
    NewT = table(Name, Cols, [], Indexes).
map_truncate_table(Name, [T|Ts], [T|Out]) :- map_truncate_table(Name, Ts, Out).

select_table(Name, [T|Ts], table(Name,C,R,I), Ts) :-
    table_parts(T, ActualName, C, R, I),
    same_identifier(Name, ActualName), !.
select_table(Name, [T|Ts], Table, [T|Other]) :- select_table(Name, Ts, Table, Other).
select_table(Name, [], table(Name, [], [], []), []).

table_member(Name, [T|_], T) :- table_has_name(T, Name), !.
table_member(Name, [_|Ts], T) :- table_member(Name, Ts, T).

table_name(table(Name,_,_), Name).
table_name(table(Name,_,_,_), Name).

table_has_name(Table, Name) :-
    table_name(Table, Existing),
    same_identifier(Name, Existing).

table_parts(table(Name, Columns, Rows), Name, Columns, Rows, Indexes) :-
    default_indexes(Name, Columns, Indexes).
table_parts(table(Name, Columns, Rows, Indexes), Name, Columns, Rows, Indexes).

drop_table_stores([]).
drop_table_stores([Table|Tables]) :-
    table_parts(Table, _, _, RowStorage, _),
    drop_row_storage(RowStorage),
    drop_table_stores(Tables).

get_db(Name, db(Name, Tables, Views, Functions, Procedures, Triggers)) :-
    asadb_visible_state(state(_, DBs)),
    (member(db(Name, Tables, Views, Functions, Procedures, Triggers), DBs) ->
        true
    ;
        member(db(Name, Tables), DBs),
        Views = [], Functions = [], Procedures = [], Triggers = []
    ), !.
get_db(Name, db(Name, [], [], [], [], [])).

asadb_visible_state(State) :- asadb_tvcc_read_state(State), !.
asadb_visible_state(State) :- asadb_state(State).

get_table(DB, Name, table(Name, Columns, Rows, Indexes)) :-
    get_db(DB, db(DB, Tables, _, _, _, _)),
    table_member(Name, Tables, Table), !,
    table_parts(Table, Name, Columns, RowStorage, Indexes),
    materialize_rows(RowStorage, Rows).
get_table(_, Name, table(Name, [], [], [])).

get_table_existing(DB, Name, table(Name, Columns, Rows, Indexes)) :-
    get_db(DB, db(DB, Tables, _, _, _, _)),
    table_member(Name, Tables, Table),
    table_parts(Table, Name, Columns, RowStorage, Indexes),
    materialize_rows(RowStorage, Rows).

get_table_storage(DB, Name, table(Name, Columns, RowStorage, Indexes)) :-
    get_db(DB, db(DB, Tables, _, _, _, _)),
    table_member(Name, Tables, Table),
    table_parts(Table, Name, Columns, RowStorage, Indexes).

materialize_rows(paged_rows(StoreId, _, _), Rows) :- !,
    findall(Row, asadb_record_scan(StoreId, _, Row), Rows).
materialize_rows(Rows, Rows).

row_storage_count(paged_rows(_, Count, _), Count) :- !.
row_storage_count(Rows, Count) :- length(Rows, Count).

get_view(DB, Name, View) :-
    get_db(DB, db(DB, _, Views, _, _, _)),
    member(View, Views),
    View = view(Name, _, _), !.

% Interchange export needs a view's immutable definition for SQL dialect
% dumps, and its evaluated rows for CSV/XLSX.  Keep the database context
% thread-local instead of changing the user's selected database globally.
asadb_view_definition(Database, Name, SelectAST) :-
    get_view(Database, Name, view(Name, SelectAST, _)).

asadb_view_rows(Database, Name, Columns, Rows) :-
    asadb_view_definition(Database, Name, SelectAST),
    setup_call_cleanup(
        assertz(asadb_tvcc_read_db(Database), Context),
        execute_statement(SelectAST, table(Columns, Rows)),
        erase(Context)
    ).

labels_to_columns([], []).
labels_to_columns([Name|Names], [col(Name, any, [])|Columns]) :-
    labels_to_columns(Names, Columns).

rows_from_value_lists(_, [], []).
rows_from_value_lists(Labels, [Values|Rows], [row(Pairs)|Out]) :-
    zip_columns_values(Labels, Values, Pairs),
    rows_from_value_lists(Labels, Rows, Out).

column_names([], []).
column_names([col(N,_,_)|Cs], [N|Ns]) :- column_names(Cs, Ns).

column_exists(Name, Columns) :-
    member(col(Existing, _, _), Columns),
    same_identifier(Name, Existing), !.

primary_column([col(Name,_,Options)|_], Name) :- member(primary_key, Options), !.
primary_column([col(Name,_,_)|_], Name) :- !.
primary_column([], id).

remove_index(_, [], []).
remove_index(Name, [index(Name,_,_)|Indexes], Rest) :- !, remove_index(Name, Indexes, Rest).
remove_index(Name, [I|Indexes], [I|Rest]) :- remove_index(Name, Indexes, Rest).

% View helpers
remove_view(_, [], []).
remove_view(Name, [view(Name,_,_)|Views], Rest) :- !, remove_view(Name, Views, Rest).
remove_view(Name, [V|Views], [V|Rest]) :- remove_view(Name, Views, Rest).

% Function helpers
remove_function(_, [], []).
remove_function(Name, [function(Name,_,_,_,_)|Functions], Rest) :- !, remove_function(Name, Functions, Rest).
remove_function(Name, [F|Functions], [F|Rest]) :- remove_function(Name, Functions, Rest).

% Procedure helpers
remove_procedure(_, [], []).
remove_procedure(Name, [procedure(Name,_,_,_)|Procedures], Rest) :- !, remove_procedure(Name, Procedures, Rest).
remove_procedure(Name, [P|Procedures], [P|Rest]) :- remove_procedure(Name, Procedures, Rest).

% Trigger helpers
remove_trigger(_, [], []).
remove_trigger(Name, [trigger(Name,_,_,_,_,_)|Triggers], Rest) :- !, remove_trigger(Name, Triggers, Rest).
remove_trigger(Name, [T|Triggers], [T|Rest]) :- remove_trigger(Name, Triggers, Rest).

maybe_index_filter(DB, Table, Where, Indexes, Rows, CandidateRows) :-
    indexed_column_predicate(Where, Indexes, Col, Op, Value), !,
    btree_for_table_column(DB, Table, Col, Rows, Tree),
    btree_candidate_rows(Tree, Op, Value, CandidateRows).
maybe_index_filter(_, _, _, _, Rows, Rows).

paged_row_storage(paged_rows(_, _, _)).

% A full row decode is required for SELECT * and expressions we do not yet
% classify.  For ordinary single-table projections, filters, and ORDER BY
% expressions, decode only the referenced fields from each page record.
storage_required_columns(Projection, Where, Order, Required) :-
    projection_required_columns(Projection, ProjectionColumns),
    expr_required_columns(Where, WhereColumns),
    order_required_columns(Order, OrderColumns),
    combine_required_columns([ProjectionColumns, WhereColumns, OrderColumns], Required).

projection_required_columns(all, all) :- !.
projection_required_columns(Projection, Columns) :-
    is_list(Projection), !,
    required_columns_from_items(Projection, Columns).
projection_required_columns(_, all).

required_columns_from_items([], []).
required_columns_from_items([Item|Items], Required) :-
    projection_item_required_columns(Item, Here),
    required_columns_from_items(Items, Rest),
    combine_required_columns([Here, Rest], Required).

projection_item_required_columns(projection(_, Expr), Columns) :- !,
    expr_required_columns(Expr, Columns).
projection_item_required_columns(Expr, Columns) :-
    expr_required_columns(Expr, Columns).

order_required_columns(none, []) :- !.
order_required_columns(order(Items), Required) :- !,
    order_item_required_columns(Items, Required).
order_required_columns(_, all).

order_item_required_columns([], []).
order_item_required_columns([order(Expr, _)|Items], Required) :-
    expr_required_columns(Expr, Here),
    order_item_required_columns(Items, Rest),
    combine_required_columns([Here, Rest], Required).

expr_required_columns(true, []) :- !.
expr_required_columns(value(_), []) :- !.
expr_required_columns(all, all) :- !.
expr_required_columns(col(Name), [Name]) :- !.
expr_required_columns(qcol(_, Name), [Name]) :- !.
expr_required_columns(Expr, [Expr]) :- atom(Expr), !.
expr_required_columns(raw(_), all) :- !.
expr_required_columns(subquery(_), all) :- !.
expr_required_columns(in_subquery(_, _), all) :- !.
expr_required_columns(exists_subquery(_), all) :- !.
expr_required_columns(func(_, Args), Required) :- !,
    required_columns_from_items(Args, Required).
expr_required_columns(case(Whens, Else), Required) :- !,
    case_required_columns(Whens, Else, Required).
expr_required_columns(Expr, Required) :-
    compound(Expr), !,
    Expr =.. [_|Args],
    required_columns_from_items(Args, Required).
expr_required_columns(_, all).

case_required_columns([], Else, Required) :- !,
    expr_required_columns(Else, Required).
case_required_columns([when(Condition, Value)|Whens], Else, Required) :-
    expr_required_columns(Condition, ConditionColumns),
    expr_required_columns(Value, ValueColumns),
    case_required_columns(Whens, Else, Rest),
    combine_required_columns([ConditionColumns, ValueColumns, Rest], Required).

combine_required_columns(Parts, all) :- memberchk(all, Parts), !.
combine_required_columns(Parts, Required) :-
    append(Parts, Raw),
    sort(Raw, Required).

storage_source_rows_for_select(DB, Table, Alias, Columns, Indexes, RowStorage,
                               Where, Order, Limit, all, Rows) :- !,
    RowStorage = paged_rows(StoreId, _, _),
    ( indexed_storage_order(Order, Indexes, OrderCol, _),
      persistent_order_path_ready(DB, Table, StoreId, OrderCol) ->
        storage_source_rows(DB, Table, Alias, Columns, Indexes, RowStorage,
                            Where, Order, Limit, Rows)
    ; source_qualifiers(Table, Alias, Qualifiers),
      Generator = (asadb_record_scan(StoreId, _, BaseRow),
                   table_row_to_source_row(Table, Qualifiers, Columns,
                                           BaseRow, SourceRow)),
      storage_collect_rows(Generator, SourceRow, Where, Order, Limit, Rows)
    ).
storage_source_rows_for_select(DB, Table, Alias, Columns, Indexes,
                               paged_rows(StoreId, _, _), Where, Order, Limit,
                               Required, Rows) :-
    ( indexed_storage_order(Order, Indexes, OrderCol, _),
      persistent_order_path_ready(DB, Table, StoreId, OrderCol) ->
        storage_source_rows(DB, Table, Alias, Columns, Indexes,
                            paged_rows(StoreId, _, _), Where, Order, Limit, Rows)
    ; column_names(Columns, ColumnNames),
      source_qualifiers(Table, Alias, Qualifiers),
      Generator = (storage_row_candidate_columns(DB, Table, StoreId, Indexes,
                                                  Where, ColumnNames, Required,
                                                  BaseRow),
                   table_row_to_source_row_columns(Qualifiers, Required,
                                                   BaseRow, SourceRow)),
      storage_collect_rows(Generator, SourceRow, Where, Order, Limit, Rows)
    ).

persistent_order_path_ready(_, _, StoreId, Col) :-
    identifier_cache_key(Col, CacheCol),
    asadb_record_index_file(StoreId, CacheCol, File),
    exists_file(File),
    catch(asadb_btree_file_stats(File, _), _, fail), !.
persistent_order_path_ready(DB, Table, StoreId, Col) :-
    \+ defer_order_index_build(DB, Table, StoreId, Col).

% Building an on-disk B+Tree is valuable for repeated ordered scans, but a
% fresh large import should not pay that full construction cost for its first
% couple of small ordered results. The bounded in-memory top-N path remains
% responsive until the persistent order index becomes hot.
defer_order_index_build(DB, Table, StoreId, Col) :-
    identifier_cache_key(Col, CacheCol),
    asadb_record_index_file(StoreId, CacheCol, File),
    \+ exists_file(File),
    with_mutex(asadb_adaptive_index,
        defer_order_index_build_locked(DB, Table, CacheCol)).

defer_order_index_build_locked(DB, Table, CacheCol) :-
    ProbeKey = order(CacheCol),
    ( retract(asadb_index_probe_count(DB, Table, ProbeKey, Count0)) -> true
    ; Count0 = 0
    ),
    Count is Count0 + 1,
    assertz(asadb_index_probe_count(DB, Table, ProbeKey, Count)),
    Count =< 2.

storage_row_candidate_columns(DB, Table, StoreId, Indexes, Where, ColumnNames,
                              _Required, Row) :-
    indexed_column_predicate(Where, Indexes, Col, '=', Value),
    join_lookup_unique_column(Col, Indexes),
    defer_unique_index_build(DB, Table, StoreId, Col), !,
    note_plan_once(sequential_scan),
    once((
        asadb_record_scan_columns(StoreId, ColumnNames, [Col], Rid, KeyRow),
        eval_expr(KeyRow, col(Col), Found),
        sql_equal(Found, Value)
    )),
    asadb_record_read(StoreId, Rid, Row).
storage_row_candidate_columns(DB, Table, StoreId, Indexes, Where, ColumnNames,
                              _Required, Row) :-
    indexed_column_predicate(Where, Indexes, Col, Op, Value), !,
    ensure_persistent_btree_columns(DB, Table, StoreId, Col, ColumnNames, File),
    note_plan(index_scan),
    asadb_btree_file_candidate(File, Op, Value, Rid),
    asadb_record_read(StoreId, Rid, Row).
storage_row_candidate_columns(_, _, StoreId, _, _, ColumnNames, Required, Row) :-
    note_plan_once(sequential_scan),
    asadb_record_scan_columns(StoreId, ColumnNames, Required, _, Row).

table_row_to_source_row_columns(Qualifiers, Required, row(Pairs),
                                row(SourcePairs)) :-
    required_source_pairs(Required, Qualifiers, Pairs, SourcePairs).

required_source_pairs([], _, _, []).
required_source_pairs([Name|Names], Qualifiers, Pairs, SourcePairs) :-
    lookup_value(Name, Pairs, Value),
    qualified_pairs(Qualifiers, Name, Value, QPairs),
    required_source_pairs(Names, Qualifiers, Pairs, Rest),
    append([Name=Value|QPairs], Rest, SourcePairs).

storage_source_rows(DB, Table, Alias, Columns, Indexes,
                    paged_rows(StoreId, _, _), Where, Order, Limit, Rows) :-
    indexed_storage_order(Order, Indexes, Col, Direction), !,
    column_names(Columns, ColumnNames),
    ensure_persistent_btree_columns(DB, Table, StoreId, Col, ColumnNames, File),
    note_plan(index_order_scan),
    source_qualifiers(Table, Alias, Qualifiers),
    Generator = (asadb_btree_file_ordered_rids(File, Direction, Rids),
                 asadb_record_read_rids(StoreId, Rids, BaseRows),
                 member(BaseRow, BaseRows),
                 table_row_to_source_row(Table, Qualifiers, Columns, BaseRow, SourceRow)),
    storage_collect_rows(Generator, SourceRow, Where, none, Limit, Rows).
% Predicate-pushdown sources use a deliberately large fetch window.  If an
% index file has not been materialized yet, building a 250k-row B+Tree just
% to filter one side of a JOIN is slower than scanning the append-only store
% once and keeping the matching rows.  Normal SELECTs retain the indexed path
% below, so this fallback only applies to the pushdown marker.
storage_source_rows(_, Table, Alias, Columns, Indexes,
                    paged_rows(StoreId, _, _), Where, none,
                    source_fetch_all_limit, Rows) :-
    source_prefix_fetch_limit(StoreId, Where, Indexes, PrefixLimit),
    !,
    source_qualifiers(Table, Alias, Qualifiers),
    Generator = (asadb_record_scan(StoreId, _, BaseRow),
                 table_row_to_source_row(Table, Qualifiers, Columns,
                                         BaseRow, SourceRow)),
    storage_collect_rows(Generator, SourceRow, Where, none,
                         limit(PrefixLimit), Rows).
storage_source_rows(_, Table, Alias, Columns, _Indexes,
                    paged_rows(StoreId, _, _), Where, none,
                    source_fetch_all_limit, Rows) :- !,
    source_qualifiers(Table, Alias, Qualifiers),
    Generator = (asadb_record_scan(StoreId, _, BaseRow),
                 table_row_to_source_row(Table, Qualifiers, Columns,
                                         BaseRow, SourceRow)),
    storage_collect_rows(Generator, SourceRow, Where, none,
                         source_fetch_all_limit, Rows).
storage_source_rows(DB, Table, Alias, Columns, Indexes, RowStorage, Where, Order, Limit, Rows) :-
    RowStorage = paged_rows(StoreId, _, _),
    source_qualifiers(Table, Alias, Qualifiers),
    Generator = (storage_row_candidate(DB, Table, StoreId, Indexes, Where, BaseRow),
                 table_row_to_source_row(Table, Qualifiers, Columns, BaseRow, SourceRow)),
    storage_collect_rows(Generator, SourceRow, Where, Order, Limit, Rows).

storage_rows(DB, Table, paged_rows(StoreId, _, _), Indexes, Where, Order, Limit, Rows) :-
    indexed_storage_order(Order, Indexes, Col, Direction), !,
    ensure_persistent_btree(DB, Table, StoreId, Col, File),
    note_plan(index_order_scan),
    Generator = (asadb_btree_file_ordered_rids(File, Direction, Rids),
                 asadb_record_read_rids(StoreId, Rids, PageRows),
                 member(Row, PageRows)),
    storage_collect_rows(Generator, Row, Where, none, Limit, Rows).
storage_rows(DB, Table, paged_rows(StoreId, _, _), Indexes, Where, Order, Limit, Rows) :-
    storage_collect_rows(storage_row_candidate(DB, Table, StoreId, Indexes, Where, Row), Row,
                         Where, Order, Limit, Rows).

indexed_storage_order(order([order(col(Col), Direction)]), Indexes, Col, Direction) :-
    memberchk(Direction, [asc, desc]),
    member(index(_, [IndexedCol|_], _), Indexes),
    same_identifier(Col, IndexedCol), !.
indexed_storage_order(order([order(qcol(_, Col), Direction)]), Indexes, Col, Direction) :-
    memberchk(Direction, [asc, desc]),
    member(index(_, [IndexedCol|_], _), Indexes),
    same_identifier(Col, IndexedCol), !.

storage_row_candidate(DB, Table, StoreId, Indexes, Where, Row) :-
    indexed_column_predicate(Where, Indexes, Col, '=', Value),
    join_lookup_unique_column(Col, Indexes),
    defer_unique_index_build(DB, Table, StoreId, Col), !,
    note_plan_once(sequential_scan),
    once((
        asadb_record_scan_columns(StoreId, [Col], Rid, KeyRow),
        eval_expr(KeyRow, col(Col), Found),
        sql_equal(Found, Value)
    )),
    asadb_record_read(StoreId, Rid, Row).
storage_row_candidate(DB, Table, StoreId, Indexes, Where, Row) :-
    indexed_column_predicate(Where, Indexes, Col, Op, Value), !,
    ensure_persistent_btree(DB, Table, StoreId, Col, File),
    note_plan(index_scan),
    asadb_btree_file_candidate(File, Op, Value, Rid),
    asadb_record_read(StoreId, Rid, Row).
storage_row_candidate(_, _, StoreId, _, _, Row) :-
    note_plan_once(sequential_scan),
    asadb_record_scan(StoreId, _, Row).

% Building a durable B+Tree is valuable for repeated probes, but it is much
% more expensive than one selective sequential pass for the first lookup
% immediately after a bulk import. Two unique equality probes are served by a
% one-column scan; the third materializes the persistent index for all later
% queries and restarts.
defer_unique_index_build(DB, Table, StoreId, Col) :-
    identifier_cache_key(Col, CacheCol),
    asadb_record_index_file(StoreId, CacheCol, File),
    \+ exists_file(File),
    with_mutex(asadb_adaptive_index,
        defer_unique_index_build_locked(DB, Table, CacheCol)).

defer_unique_index_build_locked(DB, Table, CacheCol) :-
    ( retract(asadb_index_probe_count(DB, Table, CacheCol, Count0)) -> true
    ; Count0 = 0
    ),
    Count is Count0 + 1,
    assertz(asadb_index_probe_count(DB, Table, CacheCol, Count)),
    Count =< 2.

note_plan_once(Name) :-
    ( asadb_plan_stat(active(Name), _) -> true
    ; assertz(asadb_plan_stat(active(Name), 1)), note_plan(Name)
    ).

ensure_persistent_btree(DB, Table, StoreId, Col, File) :-
    identifier_cache_key(Col, CacheCol),
    asadb_record_index_file(StoreId, CacheCol, File),
    exists_file(File),
    catch(asadb_btree_file_stats(File, _), _, fail), !,
    retractall(asadb_btree_cache(DB, Table, CacheCol, _)),
    assertz(asadb_btree_cache(DB, Table, CacheCol, persistent(File))).
ensure_persistent_btree(DB, Table, StoreId, Col, File) :-
    identifier_cache_key(Col, CacheCol),
    asadb_record_index_file(StoreId, CacheCol, File),
    asadb_btree_file_build_stream(
        File,
        Key-Rid,
        ( asadb_record_scan_columns(StoreId, [Col], Rid, Row),
          eval_expr(Row, col(Col), Key)
        ),
        _),
    note_plan(index_build),
    retractall(asadb_btree_cache(DB, Table, CacheCol, _)),
    retractall(asadb_index_probe_count(DB, Table, CacheCol, _)),
    assertz(asadb_btree_cache(DB, Table, CacheCol, persistent(File))).

ensure_persistent_btree_columns(DB, Table, StoreId, Col, _ColumnNames, File) :-
    identifier_cache_key(Col, CacheCol),
    asadb_record_index_file(StoreId, CacheCol, File),
    exists_file(File),
    catch(asadb_btree_file_stats(File, _), _, fail), !,
    retractall(asadb_btree_cache(DB, Table, CacheCol, _)),
    assertz(asadb_btree_cache(DB, Table, CacheCol, persistent(File))).
ensure_persistent_btree_columns(DB, Table, StoreId, Col, ColumnNames, File) :-
    identifier_cache_key(Col, CacheCol),
    asadb_record_index_file(StoreId, CacheCol, File),
    asadb_btree_file_build_stream(
        File,
        Key-Rid,
        ( asadb_record_scan_columns(StoreId, ColumnNames, [Col], Rid, Row),
          eval_expr(Row, col(Col), Key)
        ),
        _),
    note_plan(index_build),
    retractall(asadb_btree_cache(DB, Table, CacheCol, _)),
    retractall(asadb_index_probe_count(DB, Table, CacheCol, _)),
    assertz(asadb_btree_cache(DB, Table, CacheCol, persistent(File))).

% `ORDER BY *` is accepted for compatibility.  The wildcard evaluates to the
% same marker for every row, so sorting cannot change the scan order.  Treat
% it as a no-op before entering the top-N sorter, which otherwise rescans and
% repeatedly sorts large page-backed result sets for no visible benefit.
storage_collect_rows(Generator, Row, Where, Order, Limit, Rows) :-
    order_is_noop(Order), !,
    storage_collect_rows(Generator, Row, Where, none, Limit, Rows).
storage_collect_rows(Generator, Row, Where, none, Limit, Rows) :- !,
    result_window(Limit, Offset, Count),
    Fetch is Offset + Count,
    prepare_row_filter(Where, Filter),
    findnsols(Fetch, Row,
              (call(Generator), row_filter_matches(Filter, Row)), Window),
    drop_n(Offset, Window, Rows).
storage_collect_rows(Generator, Row, Where, Order, Limit, Rows) :-
    result_window(Limit, Offset, Count),
    Keep is Offset + Count,
    prepare_row_filter(Where, Filter),
    % Cache ORDER BY expressions once per matching row.  The previous top-N
    % sorter reevaluated column lookups for every comparison; a 250k-row
    % projection sorted by text could therefore spend seconds repeatedly
    % downcasing the same field names instead of scanning storage.
    Acc = top_rows_acc([], [], 0, 0),
    forall((call(Generator), row_filter_matches(Filter, Row)),
           buffer_top_row(Acc, Order, Keep, Row)),
    flush_top_row_buffer(Acc, Order, Keep),
    arg(1, Acc, OrderedEntries),
    keyed_rows_to_rows(OrderedEntries, OrderedWindow),
    drop_n(Offset, OrderedWindow, Rows).

result_window(none, 0, Count) :- !,
    asadb_config_get(max_result_rows, Count).
result_window(limit(Count), 0, Count) :- !.
result_window(limit(Offset, Count), Offset, Count).
% Internal marker used by source-predicate pushdown.  It deliberately means
% "fetch all matching rows" while remaining distinguishable from a user's
% ordinary LIMIT term.
result_window(source_fetch_all_limit, 0, 1000000000).

source_prefix_fetch_limit(StoreId, cmp(Op, col(Column), value(Value)), Indexes, Limit) :-
    memberchk(Op, ['=','<','<=']),
    integer(Value),
    Value > 0,
    Value =< 4096,
    join_lookup_unique_column(Column, Indexes),
    ( Op == '<' -> Limit is Value - 1 ; Limit = Value ),
    Limit > 0,
    findnsols(Limit, BaseRow,
              asadb_record_scan(StoreId, _, BaseRow), PrefixRows),
    length(PrefixRows, Limit),
    ordered_prefix_rows(PrefixRows, Column, 1).

ordered_prefix_rows([], _, _).
ordered_prefix_rows([row(Pairs)|Rows], Column, Expected) :-
    lookup_value(Column, Pairs, Value),
    integer(Value),
    Value =:= Expected,
    Next is Expected + 1,
    ordered_prefix_rows(Rows, Column, Next).

buffer_top_row(_, _, 0, _) :- !.
buffer_top_row(Acc, Order, Keep, Row) :-
    arg(2, Acc, Buffer0),
    arg(3, Acc, Count0),
    arg(4, Acc, Sequence0),
    order_row_key(Order, Row, Key),
    Entry = keyed_row(Key, Sequence0, Row),
    Buffer = [Entry|Buffer0],
    Count is Count0 + 1,
    Sequence is Sequence0 + 1,
    nb_setarg(2, Acc, Buffer),
    nb_setarg(3, Acc, Count),
    nb_setarg(4, Acc, Sequence),
    ( Count >= 256 -> flush_top_row_buffer(Acc, Order, Keep) ; true ).

flush_top_row_buffer(Acc, _, _) :-
    arg(3, Acc, 0), !.
flush_top_row_buffer(Acc, Order, Keep) :-
    arg(1, Acc, Top),
    arg(2, Acc, Buffer),
    % Sorting the complete Top+Buffer collection on every 256-row flush made
    % an ordinary ORDER BY increasingly expensive for large page-backed
    % tables.  Top and the newly sorted buffer are both ordered already, so
    % merge only the first Keep values.  Equal values take the older Top row
    % first, retaining the stable scan-order tie behaviour of apply_order/3.
    reverse(Buffer, ScanOrderedBuffer),
    apply_key_order(Order, ScanOrderedBuffer, OrderedBuffer),
    merge_top_ordered_entries(Order, Keep, Top, OrderedBuffer, Limited),
    nb_setarg(1, Acc, Limited),
    nb_setarg(2, Acc, []),
    nb_setarg(3, Acc, 0).

merge_top_ordered_entries(_, 0, _, _, []) :- !.
merge_top_ordered_entries(_, Keep, [], Right, Out) :- !,
    take_n(Keep, Right, Out).
merge_top_ordered_entries(_, Keep, Left, [], Out) :- !,
    take_n(Keep, Left, Out).
merge_top_ordered_entries(order(Items), Keep,
                          [Left|LeftRows], [Right|RightRows], [First|Out]) :-
    compare_keyed_rows(Items, Comparison, Left, Right),
    Keep1 is Keep - 1,
    ( Comparison == (>) ->
        First = Right,
        merge_top_ordered_entries(order(Items), Keep1, [Left|LeftRows], RightRows, Out)
    ; First = Left,
      merge_top_ordered_entries(order(Items), Keep1, LeftRows, [Right|RightRows], Out)
    ).

order_row_key(order(Items), Row, Key) :- !,
    order_row_key_values(Items, Row, Key).
order_row_key(_, _, []).

order_row_key_values([], _, []).
order_row_key_values([order(Expr, _)|Items], Row, [Value|Values]) :-
    eval_expr(Row, Expr, Value),
    order_row_key_values(Items, Row, Values).

apply_key_order(order(Items), Entries, Ordered) :-
    predsort(compare_keyed_rows(Items), Entries, Ordered).

compare_keyed_rows(Items, Order,
                   keyed_row(KeysA, SequenceA, _),
                   keyed_row(KeysB, SequenceB, _)) :-
    compare_order_key_values(Items, KeysA, KeysB, KeyOrder), !,
    ( KeyOrder == (=) -> compare(Order, SequenceA, SequenceB)
    ; Order = KeyOrder
    ).
compare_keyed_rows(_, =, _, _).

compare_order_key_values([], [], [], =).
compare_order_key_values([order(_, Direction)|Items], [A|As], [B|Bs], Order) :-
    compare_sql_values(Comparison, A, B),
    orient_order(Direction, Comparison, Oriented),
    ( Oriented == (=) -> compare_order_key_values(Items, As, Bs, Order)
    ; Order = Oriented
    ).

keyed_rows_to_rows([], []).
keyed_rows_to_rows([keyed_row(_, _, Row)|Entries], [Row|Rows]) :-
    keyed_rows_to_rows(Entries, Rows).

count_all_projection([projection(Label, Expr)], Label) :-
    aggregate_expr(Expr, count, all).

storage_aggregate_rows(DB, Table, Alias, Columns, Indexes,
                       paged_rows(StoreId, _, _), Projection, Where, Limit,
                       OutColumns, OutRows) :-
    grouped_projection_items(Projection, none, Items),
    projection_labels(Items, OutColumns),
    init_stream_aggregate_states(Items, States0),
    Acc = aggregate_acc(States0),
    source_qualifiers(Table, Alias, Qualifiers),
    prepare_row_filter(Where, Filter),
    forall(
        ( storage_row_candidate(DB, Table, StoreId, Indexes, Where, BaseRow),
          table_row_to_source_row(Table, Qualifiers, Columns, BaseRow, Row),
          row_filter_matches(Filter, Row)
        ),
        update_stream_aggregate_acc(Acc, Items, Row)
    ),
    arg(1, Acc, States),
    finalize_stream_aggregate_states(States, Values),
    aggregate_limit_rows(Limit, Values, OutRows).

aggregate_limit_rows(limit(0), _, []) :- !.
aggregate_limit_rows(limit(_, 0), _, []) :- !.
aggregate_limit_rows(_, Values, [Values]).

init_stream_aggregate_states([], []).
init_stream_aggregate_states([projection(_, Expr)|Items], [State|States]) :-
    init_stream_aggregate_state(Expr, State),
    init_stream_aggregate_states(Items, States).

init_stream_aggregate_state(Expr, count(all, 0)) :-
    aggregate_expr(Expr, count, all), !.
init_stream_aggregate_state(Expr, count(Arg, 0)) :-
    aggregate_expr(Expr, count, Arg), !.
init_stream_aggregate_state(Expr, sum(Arg, 0)) :-
    aggregate_expr(Expr, sum, Arg), !.
init_stream_aggregate_state(Expr, avg(Arg, 0, 0)) :-
    aggregate_expr(Expr, avg, Arg), !.
init_stream_aggregate_state(Expr, min(Arg, none)) :-
    aggregate_expr(Expr, min, Arg), !.
init_stream_aggregate_state(Expr, max(Arg, none)) :-
    aggregate_expr(Expr, max, Arg), !.
init_stream_aggregate_state(Expr, first(Expr, none)).

update_stream_aggregate_acc(Acc, Items, Row) :-
    arg(1, Acc, States0),
    update_stream_aggregate_states(Items, States0, Row, States),
    nb_setarg(1, Acc, States).

update_stream_aggregate_states([], [], _, []).
update_stream_aggregate_states([_|Items], [State0|States0], Row, [State|States]) :-
    update_stream_aggregate_state(State0, Row, State),
    update_stream_aggregate_states(Items, States0, Row, States).

update_stream_aggregate_state(count(all, Count0), _, count(all, Count)) :- !,
    Count is Count0 + 1.
update_stream_aggregate_state(count(Arg, Count0), Row, count(Arg, Count)) :- !,
    eval_expr(Row, Arg, Value),
    ( Value == null -> Count = Count0 ; Count is Count0 + 1 ).
update_stream_aggregate_state(sum(Arg, Sum0), Row, sum(Arg, Sum)) :- !,
    eval_expr(Row, Arg, Value),
    ( comparable_number(Value, Number) -> Sum is Sum0 + Number ; Sum = Sum0 ).
update_stream_aggregate_state(avg(Arg, Sum0, Count0), Row, avg(Arg, Sum, Count)) :- !,
    eval_expr(Row, Arg, Value),
    ( comparable_number(Value, Number) -> Sum is Sum0 + Number, Count is Count0 + 1
    ; Sum = Sum0, Count = Count0
    ).
update_stream_aggregate_state(min(Arg, Current0), Row, min(Arg, Current)) :- !,
    eval_expr(Row, Arg, Value),
    stream_min(Current0, Value, Current).
update_stream_aggregate_state(max(Arg, Current0), Row, max(Arg, Current)) :- !,
    eval_expr(Row, Arg, Value),
    stream_max(Current0, Value, Current).
update_stream_aggregate_state(first(Expr, none), Row, first(Expr, Value)) :- !,
    eval_expr(Row, Expr, Value).
update_stream_aggregate_state(State, _, State).

stream_min(Current, null, Current) :- !.
stream_min(none, Value, Value) :- !.
stream_min(Current, Value, Value) :- compare_sql_values(<, Value, Current), !.
stream_min(Current, _, Current).

stream_max(Current, null, Current) :- !.
stream_max(none, Value, Value) :- !.
stream_max(Current, Value, Value) :- compare_sql_values(>, Value, Current), !.
stream_max(Current, _, Current).

finalize_stream_aggregate_states([], []).
finalize_stream_aggregate_states([State|States], [Value|Values]) :-
    finalize_stream_aggregate_state(State, Value),
    finalize_stream_aggregate_states(States, Values).

finalize_stream_aggregate_state(count(_, Count), Count).
finalize_stream_aggregate_state(sum(_, Sum), Sum).
finalize_stream_aggregate_state(avg(_, _, 0), null) :- !.
finalize_stream_aggregate_state(avg(_, Sum, Count), Avg) :- Avg is Sum / Count.
finalize_stream_aggregate_state(min(_, none), null) :- !.
finalize_stream_aggregate_state(min(_, Value), Value).
finalize_stream_aggregate_state(max(_, none), null) :- !.
finalize_stream_aggregate_state(max(_, Value), Value).
finalize_stream_aggregate_state(first(_, none), null) :- !.
finalize_stream_aggregate_state(first(_, Value), Value).

indexed_column_predicate(Where, Indexes, Col, Op, Value) :-
    column_predicate(Where, Col, Op, Value),
    member(index(_, Columns, _), Indexes),
    Columns = [IndexedCol|_],
    same_identifier(Col, IndexedCol), !.

column_predicate(cmp(Op, col(Col), value(Value)), Col, Op, Value) :-
    index_supported_op(Op), !.
column_predicate(cmp(Op, value(Value), col(Col)), Col, Reversed, Value) :-
    index_supported_op(Op),
    reverse_index_op(Op, Reversed), !.
column_predicate(and(A, _), Col, Op, Value) :- column_predicate(A, Col, Op, Value), !.
column_predicate(and(_, B), Col, Op, Value) :- column_predicate(B, Col, Op, Value).

index_supported_op('=').
index_supported_op('>').
index_supported_op('>=').
index_supported_op('<').
index_supported_op('<=').

reverse_index_op('=', '=').
reverse_index_op('>', '<').
reverse_index_op('>=', '<=').
reverse_index_op('<', '>').
reverse_index_op('<=', '>=').

btree_candidate_rows(Tree, '=', Value, Rows) :- !,
    asadb_btree_lookup(Tree, Value, Rows).
btree_candidate_rows(Tree, Op, Value, Rows) :-
    asadb_btree_range(Tree, Op, Value, Rows).

btree_for_table_column(DB, Table, Col, _Rows, Tree) :-
    identifier_cache_key(Col, CacheCol),
    asadb_btree_cache(DB, Table, CacheCol, Tree), !.
btree_for_table_column(DB, Table, Col, Rows, Tree) :-
    findall(Key-Row,
            ( member(Row, Rows),
              eval_expr(Row, col(Col), Key)
            ),
            Entries),
    asadb_btree_build(Entries, Tree),
    identifier_cache_key(Col, CacheCol),
    retractall(asadb_btree_cache(DB, Table, CacheCol, _)),
    assertz(asadb_btree_cache(DB, Table, CacheCol, Tree)).

identifier_cache_key(Name, Key) :-
    atom(Name), !,
    downcase_atom(Name, Key).
identifier_cache_key(Name, Name).

indexes_rows(Table, Indexes, Rows) :- indexes_rows_(Table, Indexes, Rows).
indexes_rows_(_, [], []).
indexes_rows_(Table, [index(Name, Columns, Unique)|Indexes], Rows) :-
    index_columns_rows(Table, Name, Columns, Unique, 1, Head),
    indexes_rows_(Table, Indexes, Tail),
    append(Head, Tail, Rows).
indexes_rows_(Table, [_|Indexes], Rows) :-
    indexes_rows_(Table, Indexes, Rows).

index_columns_rows(_, _, [], _, _, []).
index_columns_rows(Table, Name, [Col|Cols], Unique, Seq, [[Table,NonUnique,Name,Seq,Col]|Rows]) :-
    ( Unique = unique -> NonUnique = 0 ; NonUnique = 1 ),
    Seq1 is Seq + 1,
    index_columns_rows(Table, Name, Cols, Unique, Seq1, Rows).

create_table_sql(Name, Columns, Indexes, SQL) :-
    column_defs_sql(Columns, ColLines),
    index_defs_sql(Indexes, IndexLines),
    append(ColLines, IndexLines, Lines),
    join_atoms(Lines, ',\n  ', Body),
    atomic_list_concat(['CREATE TABLE ', Name, ' (\n  ', Body, '\n);'], SQL).

column_defs_sql([], []).
column_defs_sql([col(Name, Type, Options)|Cols], [Line|Lines]) :-
    column_options_sql(Options, OptSQL),
    atomic_list_concat([Name, ' ', Type, OptSQL], Line),
    column_defs_sql(Cols, Lines).

column_options_sql(Options, SQL) :-
    findall(Part, column_option_sql(Options, Part), Parts),
    ( Parts = [] -> SQL = '' ; atomic_list_concat([''|Parts], ' ', SQL) ).

column_option_sql(Options, 'NOT NULL') :- member(not_null, Options).
column_option_sql(Options, 'AUTO_INCREMENT') :- member(auto_increment, Options).
column_option_sql(Options, DefaultSQL) :-
    option_default(Options, Default),
    term_atom_safe(Default, DefaultAtom),
    atomic_list_concat(['DEFAULT ', DefaultAtom], DefaultSQL).

index_defs_sql([], []).
index_defs_sql([index('PRIMARY', Columns, _)|Indexes], [Line|Lines]) :- !,
    join_atoms(Columns, ', ', ColSQL),
    atomic_list_concat(['PRIMARY KEY (', ColSQL, ')'], Line),
    index_defs_sql(Indexes, Lines).
index_defs_sql([index(Name, Columns, unique)|Indexes], [Line|Lines]) :- !,
    join_atoms(Columns, ', ', ColSQL),
    atomic_list_concat(['UNIQUE KEY ', Name, ' (', ColSQL, ')'], Line),
    index_defs_sql(Indexes, Lines).
index_defs_sql([index(Name, Columns, _)|Indexes], [Line|Lines]) :-
    join_atoms(Columns, ', ', ColSQL),
    atomic_list_concat(['KEY ', Name, ' (', ColSQL, ')'], Line),
    index_defs_sql(Indexes, Lines).
index_defs_sql([check(Name, Expr)|Indexes], [Line|Lines]) :- !,
    constraint_expr_sql(Expr, ExprSQL),
    atomic_list_concat(['CONSTRAINT ', Name, ' CHECK (', ExprSQL, ')'], Line),
    index_defs_sql(Indexes, Lines).
index_defs_sql([foreign_key(Name, LocalColumns, RefTable, RefColumns, restrict, restrict)|Indexes], [Line|Lines]) :- !,
    join_atoms(LocalColumns, ', ', LocalSQL),
    join_atoms(RefColumns, ', ', RefSQL),
    atomic_list_concat(['CONSTRAINT ', Name, ' FOREIGN KEY (', LocalSQL,
                        ') REFERENCES ', RefTable, ' (', RefSQL,
                        ') ON DELETE RESTRICT ON UPDATE RESTRICT'], Line),
    index_defs_sql(Indexes, Lines).
index_defs_sql([_|Indexes], Lines) :-
    index_defs_sql(Indexes, Lines).

constraint_expr_sql(value(null), 'NULL') :- !.
constraint_expr_sql(value(Value), SQL) :- !,
    constraint_value_sql(Value, SQL).
constraint_expr_sql(col(Name), Name) :- !.
constraint_expr_sql(qcol(Qualifier, Name), SQL) :- !,
    atomic_list_concat([Qualifier, '.', Name], SQL).
constraint_expr_sql(cmp(Op, Left, Right), SQL) :- !,
    constraint_expr_sql(Left, LeftSQL),
    constraint_expr_sql(Right, RightSQL),
    atomic_list_concat([LeftSQL, ' ', Op, ' ', RightSQL], SQL).
constraint_expr_sql(and(Left, Right), SQL) :- !,
    constraint_binary_sql('AND', Left, Right, SQL).
constraint_expr_sql(or(Left, Right), SQL) :- !,
    constraint_binary_sql('OR', Left, Right, SQL).
constraint_expr_sql(not(Expr), SQL) :- !,
    constraint_expr_sql(Expr, ExprSQL),
    atomic_list_concat(['NOT (', ExprSQL, ')'], SQL).
constraint_expr_sql(Expr, SQL) :-
    term_atom_safe(Expr, SQL).

asadb_constraint_expression_sql(Expr, SQL) :-
    constraint_expr_sql(Expr, SQL).

constraint_binary_sql(Operator, Left, Right, SQL) :-
    constraint_expr_sql(Left, LeftSQL),
    constraint_expr_sql(Right, RightSQL),
    atomic_list_concat(['(', LeftSQL, ' ', Operator, ' ', RightSQL, ')'], SQL).

constraint_value_sql(Value, SQL) :-
    number(Value), !,
    term_to_atom(Value, SQL).
constraint_value_sql(true, 'TRUE') :- !.
constraint_value_sql(false, 'FALSE') :- !.
constraint_value_sql(Value, SQL) :-
    term_atom_safe(Value, Escaped),
    atomic_list_concat(['''', Escaped, ''''], SQL).

join_atoms([], _, '').
join_atoms([A], _, A) :- !.
join_atoms([A|As], Sep, Joined) :-
    join_atoms(As, Sep, Rest),
    atomic_list_concat([A, Sep, Rest], Joined).

require_privilege(_, _, _) :- asadb_current_user(admin), !.
require_privilege(Privilege, DB, Table) :-
    asadb_current_user(User),
    has_grant(User, Privilege, DB, Table), !.
require_privilege(Privilege, DB, Table) :-
    throw(error(permission_denied(Privilege, DB, Table), user)).

has_grant(User, Privilege, DB, Table) :-
    grants_for_user(User, Grants),
    scope_match(Privilege, DB, Table, Grants).

scope_match(Privilege, DB, Table, [grant(Privilege, Scope)|_]) :- scope_covers(Scope, DB, Table), !.
scope_match(_, DB, Table, [grant(all, Scope)|_]) :- scope_covers(Scope, DB, Table), !.
scope_match(Privilege, DB, Table, [_|Grants]) :- scope_match(Privilege, DB, Table, Grants).

scope_covers('*.*', _, _) :- !.
scope_covers(Scope, DB, Table) :-
    atomic_list_concat([DB, '.', Table], Full),
    Scope == Full, !.
scope_covers(Scope, DB, _) :-
    atomic_list_concat([DB, '.*'], Full),
    Scope == Full.

authenticate_user(admin, _) :- !.
authenticate_user(User, Password) :-
    user_row(User, row(Pairs)),
    lookup_value(password, Pairs, Password).

user_row(User, Row) :-
    catalog_db(Catalog),
    get_table(Catalog, users, table(users, _Columns, Rows, _Indexes)),
    member(Row, Rows),
    Row = row(Pairs),
    lookup_value(user, Pairs, User).

grants_for_user(User, Grants) :-
    catalog_db(Catalog),
    get_table(Catalog, grants, table(grants, _Columns, Rows, _Indexes)),
    findall(grant(Privilege, Scope),
            ( member(row(Pairs), Rows),
              lookup_value(user, Pairs, User),
              lookup_value(privilege, Pairs, Privilege),
              lookup_value(scope, Pairs, Scope)
            ),
            Grants).

grants_rows(_, [], []).
grants_rows(User, [grant(Privilege, Scope)|Grants], [[GrantSQL]|Rows]) :-
    atomic_list_concat(['GRANT ', Privilege, ' ON ', Scope, ' TO ', User], GrantSQL),
    grants_rows(User, Grants, Rows).

build_rows(TableColumns, Columns, ValueRows, ExistingRows, NewRows) :-
    init_auto_counters(TableColumns, ExistingRows, Counters0),
    build_rows_(TableColumns, Columns, ValueRows, Counters0, _, NewRows).

build_rows(TableColumns, Columns, ValueRows, NewRows) :-
    build_rows(TableColumns, Columns, ValueRows, [], NewRows).

build_rows_(TableColumns, Columns, ValueRows, Counters0, Counters, Built) :-
    ( Columns = [] -> column_names(TableColumns, InputColumns) ; InputColumns = Columns ),
    asadb_schema_validate_insert_shape(TableColumns, InputColumns, ValueRows),
    row_build_plan(TableColumns, InputColumns, 0, Plan),
    build_rows_with_plan(ValueRows, Plan, Counters0, Counters, Built).

row_build_plan([], _, _, []).
row_build_plan([col(Name, _, Options)|TableColumns], InputColumns, _,
               [row_field(Name, Options, Source)|Plan]) :-
    first_identifier_position(Name, InputColumns, 0, Position), !,
    Source = source(Position),
    row_build_plan(TableColumns, InputColumns, 0, Plan).
row_build_plan([col(Name, _, Options)|TableColumns], InputColumns, _,
               [row_field(Name, Options, missing)|Plan]) :-
    row_build_plan(TableColumns, InputColumns, 0, Plan).

first_identifier_position(Name, [Input|_], Position, Position) :-
    same_identifier(Name, Input), !.
first_identifier_position(Name, [_|Inputs], Position0, Position) :-
    Position1 is Position0 + 1,
    first_identifier_position(Name, Inputs, Position1, Position).

build_rows_with_plan([], _, Counters, Counters, []).
build_rows_with_plan([Values|Rows], Plan, Counters0, Counters,
                     [row(Pairs)|Built]) :-
    build_row_from_plan(Plan, Values, Counters0, Counters1, Pairs),
    build_rows_with_plan(Rows, Plan, Counters1, Counters, Built).

build_row_from_plan([], _, Counters, Counters, []).
build_row_from_plan([row_field(Name, Options, Source)|Plan], Values,
                    Counters0, Counters, [Name=Value|Pairs]) :-
    planned_field_value(Source, Values, Name, Options,
                        Counters0, Counters1, Value),
    build_row_from_plan(Plan, Values, Counters1, Counters, Pairs).

planned_field_value(source(Position), Values, Name, Options,
                    Counters0, Counters, Value) :-
    nth0(Position, Values, Supplied), !,
    ( auto_increment_column(Options), blank_auto_value(Supplied) ->
        next_auto_value(Name, Counters0, Counters, Value)
    ; auto_increment_column(Options) ->
        bump_auto_counter(Name, Supplied, Counters0, Counters),
        Value = Supplied
    ; Counters = Counters0,
      Value = Supplied
    ).
planned_field_value(_, _, Name, Options, Counters0, Counters, Value) :-
    ( auto_increment_column(Options) ->
        next_auto_value(Name, Counters0, Counters, Value)
    ; option_default(Options, Value) ->
        Counters = Counters0
    ; Counters = Counters0,
      Value = null
    ).

zip_columns_values(Columns, Values, Pairs) :-
    zip_columns_values_(Columns, Values, [], RevPairs),
    reverse(RevPairs, Pairs).

zip_columns_values_([], _, Pairs, Pairs).
zip_columns_values_(_, [], Pairs, Pairs).
zip_columns_values_([C|Cs], [V|Vs], Acc, Pairs) :-
    ( pair_has_identifier(C, Acc) ->
        Next = Acc
    ;   Next = [C=V|Acc]
    ),
    zip_columns_values_(Cs, Vs, Next, Pairs).

fill_defaults(TableColumns, Pairs0, Pairs) :-
    init_auto_counters(TableColumns, [], Counters0),
    fill_defaults(TableColumns, Pairs0, Counters0, _, Pairs).

fill_defaults([], Pairs, Counters, Counters, Pairs).
fill_defaults([col(Name,_,Options)|Cols], Pairs0, Counters0, Counters, Pairs) :-
    ( pair_has_identifier(Name, Pairs0) ->
        lookup_pair_value(Name, Pairs0, Value),
        ( auto_increment_column(Options), blank_auto_value(Value) ->
            next_auto_value(Name, Counters0, Counters1, Generated),
            replace_pair(Name, Generated, Pairs0, P1)
        ; auto_increment_column(Options) ->
            bump_auto_counter(Name, Value, Counters0, Counters1),
            P1 = Pairs0
        ; Counters1 = Counters0,
          P1 = Pairs0
        )
    ; auto_increment_column(Options) ->
        next_auto_value(Name, Counters0, Counters1, Generated),
        P1 = [Name=Generated|Pairs0]
    ; option_default(Options, Default) ->
        Counters1 = Counters0,
        P1 = [Name=Default|Pairs0]
    ; Counters1 = Counters0,
      P1 = [Name=null|Pairs0]
    ),
    fill_defaults(Cols, P1, Counters1, Counters, Pairs).

auto_increment_column(Options) :- member(auto_increment, Options).

blank_auto_value(null) :- !.
blank_auto_value('') :- !.

init_auto_counters([], _, []).
init_auto_counters([col(Name,_,Options)|Cols], Rows, Counters) :-
    auto_increment_column(Options), !,
    max_column_number(Name, Rows, Max),
    Next is Max + 1,
    Counters = [Name-Next|Rest],
    init_auto_counters(Cols, Rows, Rest).
init_auto_counters([_|Cols], Rows, Counters) :-
    init_auto_counters(Cols, Rows, Counters).

max_column_number(Name, Rows, Max) :- max_column_number_(Rows, Name, 0, Max).
max_column_number_([], _, Max, Max).
max_column_number_([row(Pairs)|Rows], Name, Acc, Max) :-
    ( lookup_value(Name, Pairs, Value), numeric_auto_value(Value, Number), Number > Acc ->
        Acc1 is Number
    ; Acc1 = Acc
    ),
    max_column_number_(Rows, Name, Acc1, Max).

numeric_auto_value(Value, Number) :-
    number(Value), !,
    Number is floor(Value).
numeric_auto_value(Value, Number) :-
    atom(Value),
    catch(atom_number(Value, Parsed), _, fail),
    number(Parsed),
    Number is floor(Parsed).

next_auto_value(Name, Counters0, Counters, Value) :-
    select(Name-Value, Counters0, Rest), !,
    Next is Value + 1,
    Counters = [Name-Next|Rest].
next_auto_value(Name, Counters, [Name-2|Counters], 1).

bump_auto_counter(Name, Value, Counters0, Counters) :-
    numeric_auto_value(Value, Number),
    select(Name-Next0, Counters0, Rest), !,
    Next is max(Next0, Number + 1),
    Counters = [Name-Next|Rest].
bump_auto_counter(_, _, Counters, Counters).

replace_pair(Name, Value, [Existing=_|Pairs], [Existing=Value|Pairs]) :-
    same_identifier(Name, Existing), !.
replace_pair(Name, Value, [Pair|Pairs], [Pair|Out]) :-
    replace_pair(Name, Value, Pairs, Out), !.
replace_pair(Name, Value, [], [Name=Value]).

option_default([default(V)|_], V) :- !.
option_default([_|Os], V) :- option_default(Os, V).

filter_rows(true, Rows, Rows) :- !.
filter_rows(Where, Rows, Filtered) :-
    prepare_row_filter(Where, Filter),
    include_where_plan(Rows, Filter, Filtered).

include_where_plan([], _, []).
include_where_plan([Row|Rows], Filter, [Row|Out]) :-
    row_filter_matches(Filter, Row), !,
    include_where_plan(Rows, Filter, Out).
include_where_plan([_|Rows], Filter, Out) :-
    include_where_plan(Rows, Filter, Out).

include_where([], _, []).
include_where([R|Rs], Where, [R|Out]) :- row_matches(R, Where), !, include_where(Rs, Where, Out).
include_where([_|Rs], Where, Out) :- include_where(Rs, Where, Out).

row_matches(_, true) :- !.
row_matches(Row, Expr) :- eval_bool(Row, Expr), !.
row_matches(_, raw_where(_)) :- fail.

eval_bool(Row, Expr) :- eval_expr(Row, Expr, Value), truthy(Value).

truthy(true).
truthy(1).
truthy(V) :- number(V), V =\= 0.

eval_expr(_, value(V), V) :- !.
eval_expr(row(Pairs), col(Name), V) :- !, lookup_value(Name, Pairs, V).
eval_expr(row(Pairs), qcol(Qualifier, Name), V) :- !,
    ( lookup_qualified_value(Qualifier, Name, Pairs, V) -> true
    ; qualified_column_atom(Qualifier, Name, Atom),
      lookup_value(Atom, Pairs, V)
    ).
eval_expr(Row, and(A,B), true) :- !, eval_bool(Row, A), eval_bool(Row, B).
eval_expr(Row, or(A,B), true) :- !, ( eval_bool(Row, A) ; eval_bool(Row, B) ).
eval_expr(Row, xor(A,B), true) :- !,
    ( eval_bool(Row, A) -> \+ eval_bool(Row, B) ; eval_bool(Row, B) ).
eval_expr(Row, not(A), true) :- !, \+ eval_bool(Row, A).
eval_expr(Row, cmp(Op,A,B), true) :- !, eval_expr(Row, A, AV), eval_expr(Row, B, BV), compare_value(Op, AV, BV).
eval_expr(Row, is_null(A), true) :- !, eval_expr(Row, A, null).
eval_expr(Row, is_not_null(A), true) :- !, eval_expr(Row, A, V), V \== null.
eval_expr(Row, is_true(A), true) :- !,
    eval_expr(Row, A, V),
    truthy(V).
eval_expr(Row, is_false(A), true) :- !,
    eval_expr(Row, A, V),
    V \== null,
    \+ truthy(V).
eval_expr(Row, is_unknown(A), true) :- !,
    eval_expr(Row, A, null).
eval_expr(Row, like(A,B), true) :- !, eval_expr(Row, A, AV), eval_expr(Row, B, Pattern), like_value(AV, Pattern).
eval_expr(Row, in_list(A, Values), true) :- !, eval_expr(Row, A, AV), member_expr_value(Row, AV, Values).
eval_expr(Row, in_subquery(A, SelectAST), true) :- !,
    eval_expr(Row, A, AV),
    subquery_first_column_values(SelectAST, Values),
    member(Value, Values),
    compare_value('=', AV, Value).
eval_expr(_, exists_subquery(SelectAST), true) :- !,
    execute_statement(SelectAST, table(_, Rows)),
    Rows \= [].
eval_expr(Row, between(A,Low,High), true) :- !, eval_expr(Row, A, AV), eval_expr(Row, Low, LV), eval_expr(Row, High, HV), compare_value('>=', AV, LV), compare_value('<=', AV, HV).
eval_expr(Row, add(A,B), V) :- !, eval_number_pair(Row, A, B, AV, BV), V is AV + BV.
eval_expr(Row, sub(A,B), V) :- !, eval_number_pair(Row, A, B, AV, BV), V is AV - BV.
eval_expr(Row, mul(A,B), V) :- !, eval_number_pair(Row, A, B, AV, BV), V is AV * BV.
eval_expr(Row, div(A,B), V) :- !, eval_number_pair(Row, A, B, AV, BV), BV =\= 0, V is AV / BV.
eval_expr(Row, neg(A), V) :- !, eval_expr(Row, A, AV), number(AV), V is -AV.
eval_expr(Row, tuple(Expressions), Values) :- !,
    eval_expr_list(Row, Expressions, Values).
eval_expr(Row, case(Whens, Else), V) :- !, eval_case_expr(Row, Whens, Else, V).
eval_expr(Row, func(lower, [A]), V) :- !, eval_expr(Row, A, AV), term_atom_safe(AV, Atom), downcase_atom(Atom, V).
eval_expr(Row, func(upper, [A]), V) :- !, eval_expr(Row, A, AV), term_atom_safe(AV, Atom), upcase_atom(Atom, V).
eval_expr(Row, func(length, [A]), V) :- !, eval_expr(Row, A, AV), term_atom_safe(AV, Atom), atom_length(Atom, V).
eval_expr(Row, func(concat, Args), V) :- !, eval_concat_args(Row, Args, Atoms), atomic_list_concat(Atoms, V).
eval_expr(Row, func(substr, Args), V) :- !, eval_substring_args(Row, Args, V).
eval_expr(Row, func(substring, Args), V) :- !, eval_substring_args(Row, Args, V).
eval_expr(Row, func(trim, [A]), V) :- !, eval_expr(Row, A, AV), term_atom_safe(AV, Atom), normalize_space(atom(V), Atom).
eval_expr(Row, func(replace, [A,From,To]), V) :- !,
    eval_expr(Row, A, AV), eval_expr(Row, From, FromV), eval_expr(Row, To, ToV),
    term_atom_safe(AV, Atom), term_atom_safe(FromV, FromAtom), term_atom_safe(ToV, ToAtom),
    atomic_list_concat(Parts, FromAtom, Atom),
    atomic_list_concat(Parts, ToAtom, V).
eval_expr(Row, func(coalesce, Args), V) :- !, eval_coalesce_args(Row, Args, V).
eval_expr(_, subquery(SelectAST), V) :- !, subquery_scalar_value(SelectAST, V).
eval_expr(_, raw(Raw), Raw) :- !.
eval_expr(_, V, V).

eval_expr_list(_, [], []).
eval_expr_list(Row, [Expression|Expressions], [Value|Values]) :-
    eval_expr(Row, Expression, Value),
    eval_expr_list(Row, Expressions, Values).

eval_number_pair(Row, A, B, AV, BV) :-
    eval_expr(Row, A, AV),
    eval_expr(Row, B, BV),
    number(AV), number(BV).

member_expr_value(Row, Value, [Expr|_]) :- eval_expr(Row, Expr, Found), compare_value('=', Value, Found), !.
member_expr_value(Row, Value, [_|Exprs]) :- member_expr_value(Row, Value, Exprs).

eval_case_expr(Row, [when(Condition, Value)|_], _, V) :-
    eval_bool(Row, Condition), !,
    eval_expr(Row, Value, V).
eval_case_expr(Row, [_|Whens], Else, V) :- !,
    eval_case_expr(Row, Whens, Else, V).
eval_case_expr(Row, [], Else, V) :-
    eval_expr(Row, Else, V).

eval_concat_args(_, [], []).
eval_concat_args(Row, [Arg|Args], [Atom|Atoms]) :-
    eval_expr(Row, Arg, Value),
    term_atom_safe(Value, Atom),
    eval_concat_args(Row, Args, Atoms).

eval_substring_args(Row, [Text, Start], V) :- !,
    eval_substring_args(Row, [Text, Start, value(-1)], V).
eval_substring_args(Row, [Text, Start, Length], V) :-
    eval_expr(Row, Text, TextValue),
    eval_expr(Row, Start, StartValue),
    eval_expr(Row, Length, LengthValue),
    term_atom_safe(TextValue, Atom),
    number(StartValue),
    atom_length(Atom, AtomLength),
    Offset0 is max(0, StartValue - 1),
    ( LengthValue == -1 ->
        Count is AtomLength - Offset0
    ; number(LengthValue),
      Count is max(0, LengthValue)
    ),
    sub_atom(Atom, Offset0, Count, _, V).

eval_coalesce_args(Row, [Arg|_], V) :-
    eval_expr(Row, Arg, V),
    V \== null, !.
eval_coalesce_args(Row, [_|Args], V) :- !,
    eval_coalesce_args(Row, Args, V).
eval_coalesce_args(_, [], null).

subquery_scalar_value(SelectAST, Value) :-
    execute_statement(SelectAST, table(_, [[Value|_]|_])), !.
subquery_scalar_value(_, null).

subquery_first_column_values(SelectAST, Values) :-
    execute_statement(SelectAST, table(_, Rows)),
    first_column_values(Rows, Values).

first_column_values([], []).
first_column_values([[Value|_]|Rows], [Value|Values]) :- first_column_values(Rows, Values).
first_column_values([[]|Rows], Values) :- first_column_values(Rows, Values).

like_value(Value, Pattern) :-
    term_atom_safe(Value, ValueAtom),
    term_atom_safe(Pattern, PatternAtom),
    like_atom(ValueAtom, PatternAtom).

like_atom(Value, Pattern) :-
    atom_concat('%', Mid0, Pattern),
    atom_concat(Mid, '%', Mid0), !,
    sub_atom(Value, _, _, _, Mid).
like_atom(Value, Pattern) :-
    atom_concat('%', Suffix, Pattern), !,
    sub_atom(Value, _, _, 0, Suffix).
like_atom(Value, Pattern) :-
    atom_concat(Prefix, '%', Pattern), !,
    sub_atom(Value, 0, _, _, Prefix).
like_atom(Value, Pattern) :- Value == Pattern.

lookup_value(Name, Pairs, V) :-
    lookup_pair_value(Name, Pairs, V), !.
lookup_value(_, [], null).

% Generic lookup_value/3 returns null for a missing key.  JOIN aliases need to
% distinguish "missing" from "present with NULL" so the dotted-name fallback
% remains reachable and aliases are resolved correctly.
lookup_qualified_value(Qualifier, Name,
                       [q(RowQualifier, RowName)=Value|_], Value) :-
    same_identifier(Qualifier, RowQualifier),
    same_identifier(Name, RowName), !.
lookup_qualified_value(Qualifier, Name, [_|Pairs], Value) :-
    lookup_qualified_value(Qualifier, Name, Pairs, Value).

compare_value('=', A, B) :- !, sql_equal(A, B).
compare_value('!=', A, B) :- !, \+ sql_equal(A, B).
compare_value('<>', A, B) :- !, \+ sql_equal(A, B).
compare_value('>', A, B) :- !, compare_order(A, B, >).
compare_value('<', A, B) :- !, compare_order(A, B, <).
compare_value('>=', A, B) :- !, compare_order(A, B, >=).
compare_value('<=', A, B) :- !, compare_order(A, B, <=).
compare_value(is, null, null) :- !.
compare_value(is_not, A, null) :- !, A \== null.

sql_equal(A, B) :- A == B, !.
sql_equal(A, B) :-
    comparable_number(A, AN),
    comparable_number(B, BN),
    AN =:= BN.

compare_order(A, B, Op) :-
    comparable_number(A, AN),
    comparable_number(B, BN), !,
    compare_number_order(Op, AN, BN).
compare_order(A, B, Op) :-
    term_atom_safe(A, AA),
    term_atom_safe(B, BA),
    compare_atom_order(Op, AA, BA).

comparable_number(Value, Value) :-
    number(Value), !.
comparable_number(Value, Number) :-
    atom(Value),
    catch(atom_number(Value, Number), _, fail),
    number(Number).

compare_number_order(>, A, B) :- A > B.
compare_number_order(<, A, B) :- A < B.
compare_number_order(>=, A, B) :- A >= B.
compare_number_order(<=, A, B) :- A =< B.

compare_atom_order(>, A, B) :- A @> B.
compare_atom_order(<, A, B) :- A @< B.
compare_atom_order(>=, A, B) :- (A @> B ; A == B).
compare_atom_order(<=, A, B) :- (A @< B ; A == B).

order_is_noop(order([])).
order_is_noop(order([order(all, _)])).

apply_order(none, Rows, Rows) :- !.
apply_order(Order, Rows, Rows) :- order_is_noop(Order), !.
apply_order(order(Items), Rows, Ordered) :-
    numbered_rows(Rows, 0, Numbered),
    predsort(compare_numbered_rows(Items), Numbered, Sorted),
    strip_numbered_rows(Sorted, Ordered).

numbered_rows([], _, []).
numbered_rows([Row|Rows], N, [N-Row|Out]) :-
    N1 is N + 1,
    numbered_rows(Rows, N1, Out).

strip_numbered_rows([], []).
strip_numbered_rows([_-Row|Rows], [Row|Out]) :-
    strip_numbered_rows(Rows, Out).

compare_numbered_rows(Items, Order, IA-A, IB-B) :-
    compare_order_items(Items, A, B, ItemOrder), !,
    ( ItemOrder = (=) -> compare(Order, IA, IB) ; Order = ItemOrder ).
compare_numbered_rows(_, Order, IA-_, IB-_) :-
    compare(Order, IA, IB).

compare_rows(Items, Order, A, B) :-
    compare_order_items(Items, A, B, Order), !.
compare_rows(_, =, _, _).

compare_order_items([], _, _, =).
compare_order_items([order(Expr, Dir)|Items], A, B, Order) :-
    eval_expr(A, Expr, AV),
    eval_expr(B, Expr, BV),
    compare_sql_values(Cmp, AV, BV),
    orient_order(Dir, Cmp, Oriented),
    ( Oriented = (=) -> compare_order_items(Items, A, B, Order) ; Order = Oriented ).

compare_sql_values(Order, A, B) :-
    comparable_number(A, AN),
    comparable_number(B, BN), !,
    compare(Order, AN, BN).
compare_sql_values(Order, A, B) :-
    compare(Order, A, B).

orient_order(desc, <, >) :- !.
orient_order(desc, >, <) :- !.
orient_order(_, Order, Order).

apply_limit(none, Rows, Rows) :- !.
apply_limit(limit(N), Rows, Limited) :- !, take_n(N, Rows, Limited).
apply_limit(limit(Offset, N), Rows, Limited) :- drop_n(Offset, Rows, Rest), take_n(N, Rest, Limited).

drop_n(0, Rows, Rows) :- !.
drop_n(_, [], []) :- !.
drop_n(N, [_|Rows], Rest) :- N > 0, N1 is N - 1, drop_n(N1, Rows, Rest).

take_n(0, _, []) :- !.
take_n(_, [], []) :- !.
take_n(N, [X|Xs], [X|Ys]) :- N > 0, N2 is N - 1, take_n(N2, Xs, Ys).

project_rows(all, Columns, Rows, OutColumns, OutRows) :-
    column_names(Columns, OutColumns), rows_to_lists(OutColumns, Rows, OutRows), !.
project_rows(Projections, _Columns, Rows, OutColumns, OutRows) :-
    projection_list(Projections), !,
    projection_labels(Projections, OutColumns),
    rows_to_projection_lists(Projections, Rows, OutRows).
project_rows(Projection, _Columns, Rows, Projection, OutRows) :- rows_to_lists(Projection, Rows, OutRows).

projection_list([projection(_,_)|_]).

projection_labels([], []).
projection_labels([projection(Label,_)|Ps], [Label|Labels]) :- projection_labels(Ps, Labels).

select_needs_grouping(_, group(_)) :- !.
select_needs_grouping(Projection, _) :- projection_has_aggregate(Projection).

projection_has_aggregate(all) :- !, fail.
projection_has_aggregate([]) :- !, fail.
projection_has_aggregate([projection(_,Expr)|_]) :- contains_aggregate(Expr), !.
projection_has_aggregate([projection(_,_)|Ps]) :- projection_has_aggregate(Ps).
projection_has_aggregate([_|Ps]) :- projection_has_aggregate(Ps).

contains_aggregate(func(Name, _)) :- aggregate_name(Name), !.
contains_aggregate(func(_, Args)) :- !, expr_list_contains_aggregate(Args).
contains_aggregate(qcol(_, _)) :- !, fail.
contains_aggregate(col(_)) :- !, fail.
contains_aggregate(value(_)) :- !, fail.
contains_aggregate(all) :- !, fail.
contains_aggregate(and(A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(or(A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(xor(A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(not(A)) :- !, contains_aggregate(A).
contains_aggregate(cmp(_,A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(is_null(A)) :- !, contains_aggregate(A).
contains_aggregate(is_not_null(A)) :- !, contains_aggregate(A).
contains_aggregate(is_true(A)) :- !, contains_aggregate(A).
contains_aggregate(is_false(A)) :- !, contains_aggregate(A).
contains_aggregate(is_unknown(A)) :- !, contains_aggregate(A).
contains_aggregate(like(A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(in_list(A, Values)) :- !, (contains_aggregate(A) ; expr_list_contains_aggregate(Values)).
contains_aggregate(between(A,B,C)) :- !, (contains_aggregate(A) ; contains_aggregate(B) ; contains_aggregate(C)).
contains_aggregate(add(A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(sub(A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(mul(A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(div(A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(neg(A)) :- !, contains_aggregate(A).
contains_aggregate(_):- fail.

expr_list_contains_aggregate([Expr|_]) :- contains_aggregate(Expr), !.
expr_list_contains_aggregate([_|Exprs]) :- expr_list_contains_aggregate(Exprs).

aggregate_name(count).
aggregate_name(sum).
aggregate_name(avg).
aggregate_name(min).
aggregate_name(max).

project_grouped_rows(Projection, Group, Rows, OutColumns, OutRows) :-
    grouped_projection_items(Projection, Group, Items),
    projection_labels(Items, OutColumns),
    build_groups(Group, Rows, Groups),
    project_groups(Groups, Items, OutRows).

grouped_projection_items(all, group(Exprs), Items) :- !,
    group_expr_projection_items(Exprs, Items).
grouped_projection_items(all, none, [projection(count, func(count, [all]))]) :- !.
grouped_projection_items(Projections, _, Projections) :- projection_list(Projections), !.
grouped_projection_items(Columns, _, Items) :- columns_projection_items(Columns, Items).

group_expr_projection_items([], []).
group_expr_projection_items([Expr|Exprs], [projection(Label, Expr)|Items]) :-
    group_expr_label(Expr, Label),
    group_expr_projection_items(Exprs, Items).

group_expr_label(col(Name), Name) :- !.
group_expr_label(qcol(Qualifier, Name), Label) :- !,
    qualified_column_atom(Qualifier, Name, Label).
group_expr_label(func(Name, _), Name) :- !.
group_expr_label(Expr, Label) :-
    term_atom_safe(Expr, Label).

columns_projection_items([], []).
columns_projection_items([Name|Names], [projection(Name, col(Name))|Items]) :-
    columns_projection_items(Names, Items).

build_groups(none, Rows, [group(all, Rows)]) :- !.
build_groups(group(_), [], []) :- !.
build_groups(group(Exprs), Rows, Groups) :-
    empty_assoc(Empty),
    build_group_index(Rows, Exprs, Empty, Index, [], RevKeys),
    reverse(RevKeys, Keys),
    group_index_rows(Keys, Index, Groups).

% AVL-backed grouping keeps high-cardinality GROUP BY at O(n log g). The key
% list records first-seen order so queries without ORDER BY remain stable.
build_group_index([], _, Index, Index, Keys, Keys).
build_group_index([Row|Rows], Exprs, Index0, Index, Keys0, Keys) :-
    group_key(Exprs, Row, Key),
    ( get_assoc(Key, Index0, GroupRows0) ->
        put_assoc(Key, Index0, [Row|GroupRows0], Index1),
        Keys1 = Keys0
    ; put_assoc(Key, Index0, [Row], Index1),
      Keys1 = [Key|Keys0]
    ),
    build_group_index(Rows, Exprs, Index1, Index, Keys1, Keys).

group_index_rows([], _, []).
group_index_rows([Key|Keys], Index, [group(Key, Rows)|Groups]) :-
    get_assoc(Key, Index, Rows),
    group_index_rows(Keys, Index, Groups).

group_key([], _, []).
group_key([Expr|Exprs], Row, [Value|Values]) :-
    eval_expr(Row, Expr, Value),
    group_key(Exprs, Row, Values).

project_groups([], _, []).
project_groups([group(_, Rows0)|Groups], Items, [row(Pairs)|Out]) :-
    reverse(Rows0, Rows),
    project_group_pairs(Items, Rows, Pairs),
    project_groups(Groups, Items, Out).

project_group_pairs([], _, []).
project_group_pairs([projection(Label,Expr)|Items], Rows, [Label=Value|Pairs]) :-
    group_expr_value(Expr, Rows, Value),
    project_group_pairs(Items, Rows, Pairs).

group_expr_value(Expr, Rows, Value) :-
    aggregate_expr(Expr, Name, Arg), !,
    aggregate_value(Name, Arg, Rows, Value).
group_expr_value(Expr, [Row|_], Value) :- !,
    eval_expr(Row, Expr, Value).
group_expr_value(_, [], null).

aggregate_expr(func(Name, [Arg]), Name, Arg) :- aggregate_name(Name), !.

aggregate_value(count, all, Rows, Count) :- !, length(Rows, Count).
aggregate_value(count, Arg, Rows, Count) :- !,
    aggregate_values(Arg, Rows, Values),
    exclude_nulls(Values, NonNull),
    length(NonNull, Count).
aggregate_value(sum, Arg, Rows, Sum) :- !,
    aggregate_numeric_values(Arg, Rows, Values),
    sum_numbers(Values, 0, Sum).
aggregate_value(avg, Arg, Rows, Avg) :- !,
    aggregate_numeric_values(Arg, Rows, Values),
    ( Values = [] -> Avg = null
    ; sum_numbers(Values, 0, Sum),
      length(Values, Count),
      Avg is Sum / Count
    ).
aggregate_value(min, Arg, Rows, Min) :- !,
    aggregate_values(Arg, Rows, Values0),
    exclude_nulls(Values0, Values),
    min_value(Values, Min).
aggregate_value(max, Arg, Rows, Max) :-
    aggregate_values(Arg, Rows, Values0),
    exclude_nulls(Values0, Values),
    max_value(Values, Max).

aggregate_values(_, [], []).
aggregate_values(Arg, [Row|Rows], [Value|Values]) :-
    eval_expr(Row, Arg, Value),
    aggregate_values(Arg, Rows, Values).

aggregate_numeric_values(Arg, Rows, Values) :-
    aggregate_values(Arg, Rows, Raw),
    include(number, Raw, Values).

exclude_nulls([], []).
exclude_nulls([null|Values], Out) :- !, exclude_nulls(Values, Out).
exclude_nulls([Value|Values], [Value|Out]) :- exclude_nulls(Values, Out).

sum_numbers([], Sum, Sum).
sum_numbers([Value|Values], Acc, Sum) :-
    Acc1 is Acc + Value,
    sum_numbers(Values, Acc1, Sum).

min_value([], null) :- !.
min_value([Value|Values], Min) :- min_value_(Values, Value, Min).

min_value_([], Min, Min).
min_value_([Value|Values], Current, Min) :-
    compare(Cmp, Value, Current),
    ( Cmp = (<) -> Next = Value ; Next = Current ),
    min_value_(Values, Next, Min).

max_value([], null) :- !.
max_value([Value|Values], Max) :- max_value_(Values, Value, Max).

max_value_([], Max, Max).
max_value_([Value|Values], Current, Max) :-
    compare(Cmp, Value, Current),
    ( Cmp = (>) -> Next = Value ; Next = Current ),
    max_value_(Values, Next, Max).

rows_to_projection_lists(_, [], []).
rows_to_projection_lists(Projections, [Row|Rows], [Vals|Out]) :-
    project_expr_values(Projections, Row, Vals),
    rows_to_projection_lists(Projections, Rows, Out).

project_expr_values([], _, []).
project_expr_values([projection(_,Expr)|Ps], Row, [V|Vs]) :-
    eval_expr(Row, Expr, V),
    project_expr_values(Ps, Row, Vs).

rows_to_lists(_, [], []).
rows_to_lists(Columns, [row(Pairs)|Rows], [Vals|Out]) :- project_values(Columns, Pairs, Vals), rows_to_lists(Columns, Rows, Out).

project_values([], _, []).
project_values([C|Cs], Pairs, [V|Vs]) :- lookup_value(C, Pairs, V), project_values(Cs, Pairs, Vs).

update_matching_rows([], _, _, [], 0).
update_matching_rows([R|Rs], Assignments, Where, [NewR|Out], Count) :-
    row_matches(R, Where), !,
    apply_assignments(R, Assignments, NewR),
    update_matching_rows(Rs, Assignments, Where, Out, CountRest),
    Count is CountRest + 1.
update_matching_rows([R|Rs], Assignments, Where, [R|Out], Count) :- update_matching_rows(Rs, Assignments, Where, Out, Count).

apply_assignments(Row, Assignments, row(NewPairs)) :-
    Row = row(Pairs),
    apply_assignments_pairs(Assignments, Row, Pairs, NewPairs).

apply_assignments_pairs([], _, Pairs, Pairs).
apply_assignments_pairs([assign(Name, Expr)|As], Row, Pairs, Out) :-
    eval_expr(Row, Expr, Value),
    set_pair(Name, Value, Pairs, P1),
    apply_assignments_pairs(As, row(P1), P1, Out).

set_pair(Name, Value, [], [Name=Value]).
set_pair(Name, Value, [Existing=_|Ps], [Existing=Value|Ps]) :-
    same_identifier(Name, Existing), !.
set_pair(Name, Value, [P|Ps], [P|Out]) :- set_pair(Name, Value, Ps, Out).

delete_matching_rows([], _, [], 0).
delete_matching_rows([R|Rs], Where, Out, Count) :-
    row_matches(R, Where), !,
    delete_matching_rows(Rs, Where, Out, C0),
    Count is C0 + 1.
delete_matching_rows([R|Rs], Where, [R|Out], Count) :- delete_matching_rows(Rs, Where, Out, Count).

db_names([], []).
db_names([db(N,_,_,_,_,_)|DBs], Names) :-
    catalog_db(N), !,
    db_names(DBs, Names).
db_names([db(N,_,_,_,_,_)|DBs], [N|Ns]) :- !,
    db_names(DBs, Ns).
db_names([db(N,_)|DBs], Names) :-
    catalog_db(N), !,
    db_names(DBs, Names).
db_names([db(N,_)|DBs], [N|Ns]) :- !, db_names(DBs, Ns).
db_names([_|DBs], Ns) :- db_names(DBs, Ns).

table_names([], []).
table_names([T|Ts], [N|Ns]) :- table_name(T, N), table_names(Ts, Ns).

view_names([], []).
view_names([view(N,_,_)|Vs], [N|Ns]) :- !, view_names(Vs, Ns).
view_names([_|Vs], Ns) :- view_names(Vs, Ns).

atoms_rows([], []).
atoms_rows([A|As], [[A]|Rows]) :- atoms_rows(As, Rows).

describe_columns(Columns, Indexes, Rows) :- describe_columns_(Columns, Indexes, Rows).

describe_columns_([], _, []).
describe_columns_([col(Name,Type,Options)|Cols], Indexes, [[Name,Type,Null,Key,Default,Extra]|Rows]) :-
    ( member(not_null, Options) -> Null = 'NO' ; Null = 'YES' ),
    column_key(Name, Options, Indexes, Key),
    ( option_default(Options, Default) -> true ; Default = null ),
    ( member(auto_increment, Options) -> Extra = auto_increment ; Extra = '' ),
    describe_columns_(Cols, Indexes, Rows).

column_key(_, Options, _, 'PRI') :- member(primary_key, Options), !.
column_key(_, Options, _, 'UNI') :- member(unique, Options), !.
column_key(Name, _, Indexes, 'PRI') :- member(index('PRIMARY', Columns, _), Indexes), identifier_member(Name, Columns), !.
column_key(Name, _, Indexes, 'UNI') :- member(index(_, Columns, unique), Indexes), identifier_member(Name, Columns), !.
column_key(Name, _, Indexes, 'MUL') :- member(index(_, Columns, _), Indexes), identifier_member(Name, Columns), !.
column_key(_, _, _, '').

/*
   Legacy v1 executor/storage block kept out of compilation after the
   table/4 metadata and expression-evaluator rewrite above.
*/
/*
    filter_rows(Where, Rows, Filtered0),
    apply_limit(Limit, Filtered0, Filtered),
    project_rows(Projection, Columns, Filtered, OutColumns, OutRows).

execute_statement(update(Table, Assignments, Where), ok(updated(Table, Count))) :-
    current_db_or_default(DB),
    update_state(update_rows(DB, Table, Assignments, Where, Count)).

execute_statement(delete(Table, Where), ok(deleted(Table, Count))) :-
    current_db_or_default(DB),
    update_state(delete_rows(DB, Table, Where, Count)).

execute_statement(show_databases, table([database], Rows)) :-
    asadb_state(state(_, DBs)), db_names(DBs, Names), atoms_rows(Names, Rows).

execute_statement(show_tables, table([table], Rows)) :-
    current_db_or_default(DB),
    get_db(DB, db(DB, Tables, _, _, _, _)), table_names(Tables, Names), atoms_rows(Names, Rows).

update_state(Action) :-
    retract(asadb_state(State)),
    apply_action(Action, State, NewState),
    assertz(asadb_state(NewState)).

apply_action(create_db(Name), state(V, DBs), state(V, NewDBs)) :-
    ( member(db(Name,_), DBs) -> NewDBs = DBs ; NewDBs = [db(Name, [])|DBs] ).
apply_action(drop_db(Name), state(V, DBs), state(V, NewDBs)) :- remove_db(Name, DBs, NewDBs).
apply_action(create_table(DB, Name, Columns), State, NewState) :-
    ensure_db(State, DB, S1),
    transform_db(DB, S1, create_table_in_db(Name, Columns), NewState).
apply_action(drop_table(DB, Name), State, NewState) :- transform_db(DB, State, drop_table_in_db(Name), NewState).
apply_action(truncate_table(DB, Name), State, NewState) :- transform_db(DB, State, truncate_table_in_db(Name), NewState).
apply_action(insert_rows(DB, Table, Columns, Rows), State, NewState) :- transform_db(DB, State, insert_rows_in_db(Table, Columns, Rows), NewState).
apply_action(update_rows(DB, Table, Assignments, Where, Count), State, NewState) :- transform_db(DB, State, update_rows_in_db(Table, Assignments, Where, Count), NewState).
apply_action(delete_rows(DB, Table, Where, Count), State, NewState) :- transform_db(DB, State, delete_rows_in_db(Table, Where, Count), NewState).

ensure_db(state(V, DBs), Name, state(V, DBs)) :- member(db(Name,_), DBs), !.
ensure_db(state(V, DBs), Name, state(V, [db(Name, [])|DBs])).

db_exists(state(_, DBs), Name) :- member(db(Name,_,_,_,_,_), DBs) ; member(db(Name,_), DBs).

column_names([], []).
column_names([col(N,_,_)|Cs], [N|Ns]) :- column_names(Cs, Ns).

build_rows(_, _, [], []).
build_rows(TableColumns, Columns, [Values|Rows], [row(Pairs)|Built]) :-
    ( Columns = [] -> column_names(TableColumns, ColNames) ; ColNames = Columns ),
    zip_columns_values(ColNames, Values, Pairs0),
    fill_defaults(TableColumns, Pairs0, Pairs),
    build_rows(TableColumns, Columns, Rows, Built).

zip_columns_values([], _, []).
zip_columns_values(_, [], []).
zip_columns_values([C|Cs], [V|Vs], [C=V|Pairs]) :- zip_columns_values(Cs, Vs, Pairs).

fill_defaults([], Pairs, Pairs).
fill_defaults([col(Name,_,Options)|Cols], Pairs0, Pairs) :-
    ( member(Name=_, Pairs0) -> P1 = Pairs0
    ; option_default(Options, Default) -> P1 = [Name=Default|Pairs0]
    ; P1 = [Name=null|Pairs0]
    ),
    fill_defaults(Cols, P1, Pairs).

option_default([default(V)|_], V) :- !.
option_default([_|Os], V) :- option_default(Os, V).

filter_rows(true, Rows, Rows) :- !.
filter_rows(Where, Rows, Filtered) :- include_where(Rows, Where, Filtered).

include_where([], _, []).
include_where([R|Rs], Where, [R|Out]) :- row_matches(R, Where), !, include_where(Rs, Where, Out).
include_where([_|Rs], Where, Out) :- include_where(Rs, Where, Out).

row_matches(_, true) :- !.
row_matches(Row, and(A,B)) :- !, row_matches(Row, A), row_matches(Row, B).
row_matches(row(Pairs), cmp(Name, Op, Value)) :- lookup_value(Name, Pairs, Found), compare_value(Op, Found, Value).
row_matches(_, raw_where(_)) :- fail.

lookup_value(Name, [Name=V|_], V) :- !.
lookup_value(Name, [_|Ps], V) :- lookup_value(Name, Ps, V).
lookup_value(_, [], null).

compare_value('=', A, B) :- A == B.
compare_value('!=', A, B) :- A \== B.
compare_value('<>', A, B) :- A \== B.
compare_value('>', A, B) :- number(A), number(B), A > B.
compare_value('<', A, B) :- number(A), number(B), A < B.
compare_value('>=', A, B) :- number(A), number(B), A >= B.
compare_value('<=', A, B) :- number(A), number(B), A =< B.
compare_value(is, null, null).
compare_value(is_not, A, null) :- A \== null.

apply_limit(none, Rows, Rows) :- !.
apply_limit(limit(N), Rows, Limited) :- take_n(N, Rows, Limited).

take_n(0, _, []) :- !.
take_n(_, [], []) :- !.
take_n(N, [X|Xs], [X|Ys]) :- N > 0, N2 is N - 1, take_n(N2, Xs, Ys).

project_rows(all, Columns, Rows, OutColumns, OutRows) :-
    column_names(Columns, OutColumns), rows_to_lists(OutColumns, Rows, OutRows), !.
project_rows(Projection, _Columns, Rows, Projection, OutRows) :- rows_to_lists(Projection, Rows, OutRows).

rows_to_lists(_, [], []).
rows_to_lists(Columns, [row(Pairs)|Rows], [Vals|Out]) :- project_values(Columns, Pairs, Vals), rows_to_lists(Columns, Rows, Out).

project_values([], _, []).
project_values([C|Cs], Pairs, [V|Vs]) :- lookup_value(C, Pairs, V), project_values(Cs, Pairs, Vs).

update_matching_rows([], _, _, [], 0).
update_matching_rows([R|Rs], Assignments, Where, [NewR|Out], Count) :-
    row_matches(R, Where), !,
    apply_assignments(R, Assignments, NewR),
    update_matching_rows(Rs, Assignments, Where, Out, CountRest),
    Count is CountRest + 1.
update_matching_rows([R|Rs], Assignments, Where, [R|Out], Count) :- update_matching_rows(Rs, Assignments, Where, Out, Count).

apply_assignments(row(Pairs), Assignments, row(NewPairs)) :- apply_assignments_pairs(Assignments, Pairs, NewPairs).
apply_assignments_pairs([], Pairs, Pairs).
apply_assignments_pairs([assign(Name, Value)|As], Pairs, Out) :- set_pair(Name, Value, Pairs, P1), apply_assignments_pairs(As, P1, Out).

set_pair(Name, Value, [], [Name=Value]).
set_pair(Name, Value, [Name=_|Ps], [Name=Value|Ps]) :- !.
set_pair(Name, Value, [P|Ps], [P|Out]) :- set_pair(Name, Value, Ps, Out).

delete_matching_rows([], _, [], 0).
delete_matching_rows([R|Rs], Where, Out, Count) :-
    row_matches(R, Where), !,
    delete_matching_rows(Rs, Where, Out, C0),
    Count is C0 + 1.
delete_matching_rows([R|Rs], Where, [R|Out], Count) :- delete_matching_rows(Rs, Where, Out, Count).

db_names([], []).
db_names([db(N,_)|DBs], [N|Ns]) :- db_names(DBs, Ns).

table_names([], []).
table_names([table(N,_,_)|Ts], [N|Ns]) :- table_names(Ts, Ns).

atoms_rows([], []).
atoms_rows([A|As], [[A]|Rows]) :- atoms_rows(As, Rows).

describe_columns([], []).
describe_columns([col(Name,Type,Options)|Cols], [[Name,Type,Null,Key,Default,Extra]|Rows]) :-
    ( member(not_null, Options) -> Null = 'NO' ; Null = 'YES' ),
    ( member(primary_key, Options) -> Key = 'PRI' ; member(unique, Options) -> Key = 'UNI' ; Key = '' ),
    ( option_default(Options, Default) -> true ; Default = null ),
    ( member(auto_increment, Options) -> Extra = auto_increment ; Extra = '' ),
    describe_columns(Cols, Rows).
*/

/* -------------------------------------------------------------------------
   Result formatting for CLI and Web
   ------------------------------------------------------------------------- */

asadb_format_result(multi(Results)) :- !, format_results(Results).
asadb_format_result(Result) :- format_result(Result).

format_results([]).
format_results([R|Rs]) :- format_result(R), nl, format_results(Rs).

format_result(ok(Msg)) :- !, format('OK: ~w~n', [Msg]).
format_result(error(Code, Msg)) :- !, format('ERROR[~w]: ~w~n', [Code, Msg]).
format_result(table(Columns, Rows)) :-
    !,
    format('~w~n', [Columns]),
    format_table_rows(Rows),
    length(Rows, Count), format('~w row(s).~n', [Count]).
format_result(Other) :- format('~w~n', [Other]).

format_table_rows([]).
format_table_rows([R|Rows]) :- format('~w~n', [R]), format_table_rows(Rows).

asadb_result_json(Result, Atom) :-
    result_json_codes(Result, Codes), atom_codes(Atom, Codes).

asadb_analysis_json(diagnostics(Diagnostics), Atom) :-
    diagnostics_json(Diagnostics, Codes),
    atom_codes(Atom, Codes).

diagnostics_json(Diagnostics, Codes) :-
    diagnostics_array_json(Diagnostics, Inner),
    append("{\"status\":\"ok\",\"diagnostics\":[", Inner, A),
    append(A, "]}", Codes).

diagnostics_array_json([], []).
diagnostics_array_json([D], Codes) :- !, diagnostic_json(D, Codes).
diagnostics_array_json([D|Ds], Codes) :-
    diagnostic_json(D, C1),
    diagnostics_array_json(Ds, C2),
    append(C1, [44|C2], Codes).

diagnostic_json(diagnostic(Severity, Line, Message, Correction), Codes) :-
    term_atom_safe(Severity, SeverityAtom),
    term_atom_safe(Message, MessageAtom),
    term_atom_safe(Correction, CorrectionAtom),
    json_string(SeverityAtom, JS),
    number_codes(Line, JL),
    json_string(MessageAtom, JM),
    json_string(CorrectionAtom, JC),
    append("{\"severity\":", JS, A),
    append(A, ",\"line\":", B),
    append(B, JL, C),
    append(C, ",\"message\":", D),
    append(D, JM, E),
    append(E, ",\"correction\":", F),
    append(F, JC, G),
    append(G, "}", Codes).

result_json_codes(multi(Results), Codes) :-
    results_json(Results, Inner), append("{\"results\":[", Inner, A), append(A, "]}", Codes).
result_json_codes(ok(Msg), Codes) :-
    term_atom_safe(Msg, A), json_string(A, JS), append("{\"status\":\"ok\",\"message\":", JS, B), append(B, "}", Codes).
result_json_codes(error(Code, Msg), Codes) :-
    term_atom_safe(Code, C), term_atom_safe(Msg, M), json_string(C, JC), json_string(M, JM),
    append("{\"status\":\"error\",\"code\":", JC, A), append(A, ",\"message\":", B), append(B, JM, D), append(D, "}", Codes).
result_json_codes(table(Cols, Rows), Codes) :-
    atoms_array_json(Cols, JC), rows_array_json(Rows, JR),
    append("{\"status\":\"table\",\"columns\":", JC, A), append(A, ",\"rows\":", B), append(B, JR, C), append(C, "}", Codes).
result_json_codes(table_page(Cols, Rows, HasMore), Codes) :-
    atoms_array_json(Cols, JC), rows_array_json(Rows, JR),
    length(Rows, Returned), number_codes(Returned, JReturned),
    json_boolean(HasMore, JHasMore),
    append("{\"status\":\"table\",\"columns\":", JC, A),
    append(A, ",\"rows\":", B), append(B, JR, C),
    append(C, ",\"returned_rows\":", D), append(D, JReturned, E),
    append(E, ",\"has_more\":", F), append(F, JHasMore, G),
    append(G, "}", Codes).

json_boolean(true, "true") :- !.
json_boolean(_, "false").

results_json([], []).
results_json([R], Codes) :- !, result_json_codes(R, Codes).
results_json([R|Rs], Codes) :- result_json_codes(R, C1), results_json(Rs, C2), append(C1, [44|C2], Codes).

atoms_array_json([], "[]").
atoms_array_json(List, Codes) :- values_json(List, Inner), append("[", Inner, A), append(A, "]", Codes).
rows_array_json([], "[]").
rows_array_json([Row|Rows], Codes) :- rows_array_json_(Rows, Tail), values_json(Row, RCodes), append("[[", RCodes, A), append(A, "]", B), append(B, Tail, C), append(C, "]", Codes).
rows_array_json_([], []).
rows_array_json_([Row|Rows], Codes) :- values_json(Row, RCodes), rows_array_json_(Rows, Rest), append(",[", RCodes, A), append(A, "]", B), append(B, Rest, Codes).

values_json([], []).
values_json([V], Codes) :- !, value_json(V, Codes).
values_json([V|Vs], Codes) :- value_json(V, C1), values_json(Vs, C2), append(C1, [44|C2], Codes).

value_json(null, "null") :- !.
value_json(N, Codes) :- number(N), !, number_codes(N, Codes).
value_json(V, Codes) :- term_atom_safe(V, A), json_string(A, Codes).

term_atom_safe(T, A) :- atom(T), !, A = T.
term_atom_safe(T, A) :- term_to_atom(T, A).

json_string(Atom, Codes) :- atom_codes(Atom, Raw), escape_json(Raw, Esc), append([34|Esc], [34], Codes).
escape_json([], []).
escape_json([34|Cs], [92,34|Es]) :- !, escape_json(Cs, Es).
escape_json([92|Cs], [92,92|Es]) :- !, escape_json(Cs, Es).
escape_json([10|Cs], [92,110|Es]) :- !, escape_json(Cs, Es).
escape_json([13|Cs], [92,114|Es]) :- !, escape_json(Cs, Es).
escape_json([9|Cs], [92,116|Es]) :- !, escape_json(Cs, Es).
escape_json([C|Cs], [C|Es]) :- escape_json(Cs, Es).
