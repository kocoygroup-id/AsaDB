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
    asadb_parse_sql/2,
    asadb_analyze_sql/2,
    asadb_current_database/1,
    asadb_get_state/1,
    asadb_storage_stats/1,
    asadb_database_metadata/1,
    asadb_analysis_json/2,
    asadb_result_json/2,
    asadb_format_result/1
]).

:- set_prolog_flag(double_quotes, codes).
:- discontiguous parse_statement/2.
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

:- dynamic asadb_state/1.
:- dynamic asadb_file/1.
:- dynamic asadb_current_db/1.
:- dynamic asadb_tx_snapshot/1.
:- dynamic asadb_write_lock/1.
:- dynamic asadb_current_user/1.
:- dynamic asadb_btree_cache/4.
:- dynamic asadb_plan_stat/2.
:- dynamic asadb_checkpoint_dirty/0.
:- thread_local asadb_query_batch_depth/1.

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
    findall(index('PRIMARY', [Col], unique),
            ( member(col(Col, _, Options), Columns), member(primary_key, Options) ),
            Primary),
    findall(index(Col, [Col], unique),
            ( member(col(Col, _, Options), Columns), member(unique, Options) ),
            Unique),
    append(Primary, Unique, Indexes0),
    ( Indexes0 = [] -> Indexes = [] ; Indexes = Indexes0 ).

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
    retractall(asadb_plan_stat(_, _)),
    retractall(asadb_checkpoint_dirty),
    retractall(asadb_query_batch_depth(_)),
    assertz(asadb_file(File)),
    asadb_metadata_open(File),
    ( exists_file(File) ->
        catch(asadb_load_file(File, State), _, empty_state(State))
    ; empty_state(State)
    ),
    normalize_state(State, Normalized),
    mark_state_upgrade(State),
    recover_wal_state(Normalized, Recovered),
    assertz(asadb_state(Recovered)),
    ensure_catalog,
    restore_current_db,
    assertz(asadb_current_user(admin)).

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
    retractall(asadb_plan_stat(_, _)),
    retractall(asadb_checkpoint_dirty),
    retractall(asadb_query_batch_depth(_)),
    asadb_buffer_pool_flush_all,
    asadb_metadata_close.

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
    asadb_save_file(File, State),
    clear_wal,
    retractall(asadb_checkpoint_dirty),
    metadata_checkpoint_summary(State, Summary),
    catch(asadb_metadata_checkpoint(Summary), _, true).

mark_state_upgrade(state(V, _)) :-
    ( \+ integer(V) ; V < 3 ), !,
    assertz(asadb_checkpoint_dirty).
mark_state_upgrade(_).

asadb_get_state(State) :-
    with_mutex(asadb_write, asadb_state(State)).

asadb_storage_stats(storage{config:Config,pager:PagerStats,btree_cache:btree_cache{entries:CacheEntries},planner:Planner}) :-
    asadb_config_snapshot(Config),
    asadb_pager_stats(PagerStats),
    aggregate_all(count, asadb_btree_cache(_, _, _, _), CacheEntries),
    planner_stats_dict(Planner).

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
    append(Magic, Rest, All),
    take_line(Rest, SumCodes, Payload),
    number_codes(Sum, SumCodes),
    decode_codes(Payload, Codes),
    checksum(Codes, Sum),
    atom_codes(Atom, Codes),
    atom_to_term(Atom, State, _).

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
    ( asadb_tx_snapshot(_) -> true
    ; asadb_checkpoint_dirty -> asadb_save
    ; true
    ).

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
    sql_codes(SQL, Codes),
    sql_tokens(Codes, Tokens),
    split_statements(Tokens, TokenStatements),
    parse_statements(TokenStatements, Statements).

asadb_analyze_sql(SQL, diagnostics(Diagnostics)) :-
    sql_codes(SQL, Codes),
    sql_statement_spans(Codes, Statements),
    analyze_statement_spans(Statements, Diagnostics0),
    sort_diagnostics(Diagnostics0, Diagnostics).

sql_statement_spans(Codes, Statements) :-
    split_sql_chunks(Codes, Chunks),
    chunks_to_statement_spans(Chunks, 1, Statements).

split_sql_chunks(Codes, Chunks) :-
    split_sql_chunks_(Codes, none, [], [], Rev),
    reverse(Rev, Chunks).

split_sql_chunks_([], _, Acc, Out, [chunk(Chunk, false)|Out]) :-
    reverse(Acc, Chunk), !.
split_sql_chunks_([59|Cs], none, Acc, Out, Res) :-
    reverse(Acc, Chunk), !,
    split_sql_chunks_(Cs, none, [], [chunk(Chunk, true)|Out], Res).
split_sql_chunks_([45,45|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, line_comment, [45,45|Acc], Out, Res).
split_sql_chunks_([35|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, line_comment, [35|Acc], Out, Res).
split_sql_chunks_([47,42|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, block_comment, [42,47|Acc], Out, Res).
split_sql_chunks_([39|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, single, [39|Acc], Out, Res).
split_sql_chunks_([34|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, double, [34|Acc], Out, Res).
split_sql_chunks_([96|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, backtick, [96|Acc], Out, Res).
split_sql_chunks_([92,C|Cs], single, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, single, [C,92|Acc], Out, Res).
split_sql_chunks_([92,C|Cs], double, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, double, [C,92|Acc], Out, Res).
split_sql_chunks_([39|Cs], single, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [39|Acc], Out, Res).
split_sql_chunks_([34|Cs], double, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [34|Acc], Out, Res).
split_sql_chunks_([96|Cs], backtick, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [96|Acc], Out, Res).
split_sql_chunks_([10|Cs], line_comment, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [10|Acc], Out, Res).
split_sql_chunks_([42,47|Cs], block_comment, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [47,42|Acc], Out, Res).
split_sql_chunks_([C|Cs], Quote, Acc, Out, Res) :-
    split_sql_chunks_(Cs, Quote, [C|Acc], Out, Res).

chunks_to_statement_spans([], _, []).
chunks_to_statement_spans([chunk(Codes, Terminated)|Chunks], BaseLine, Statements) :-
    trim_leading_sql_ws(Codes, LeadingLines, Trim0),
    trim_trailing_sql_ws(Trim0, Trimmed),
    count_newlines(Codes, NewLines),
    NextLine is BaseLine + NewLines,
    ( Trimmed = [] ->
        Statements = Rest
    ; StartLine is BaseLine + LeadingLines,
      Statements = [stmt(StartLine, Trimmed, Terminated)|Rest]
    ),
    chunks_to_statement_spans(Chunks, NextLine, Rest).

trim_leading_sql_ws([], 0, []).
trim_leading_sql_ws([C|Cs], Lines, Rest) :-
    is_space_code(C), !,
    trim_leading_sql_ws(Cs, Lines0, Rest),
    ( C =:= 10 -> Lines is Lines0 + 1 ; Lines = Lines0 ).
trim_leading_sql_ws(Codes, 0, Codes).

trim_trailing_sql_ws(Codes, Trimmed) :-
    reverse(Codes, Rev),
    drop_leading_sql_ws(Rev, RevTrimmed),
    reverse(RevTrimmed, Trimmed).

drop_leading_sql_ws([C|Cs], Rest) :- is_space_code(C), !, drop_leading_sql_ws(Cs, Rest).
drop_leading_sql_ws(Codes, Codes).

count_newlines([], 0).
count_newlines([10|Cs], N) :- !, count_newlines(Cs, N0), N is N0 + 1.
count_newlines([_|Cs], N) :- count_newlines(Cs, N).

analyze_statement_spans([], []).
analyze_statement_spans([Stmt|Stmts], Diagnostics) :-
    analyze_statement_span(Stmt, D1),
    analyze_statement_spans(Stmts, D2),
    append(D1, D2, Diagnostics).

analyze_statement_span(stmt(Line, Codes, Terminated), Diagnostics) :-
    catch(sql_tokens(Codes, Tokens), Error,
          Tokens = [lexer_error(Error)]),
    syntax_diagnostics(Line, Tokens, SyntaxDiagnostics),
    semicolon_diagnostic(Line, Terminated, SemicolonDiagnostics),
    append(SyntaxDiagnostics, SemicolonDiagnostics, Diagnostics).

semicolon_diagnostic(_, true, []) :- !.
semicolon_diagnostic(Line, false, [diagnostic(warning, Line, 'Statement belum ditutup titik koma (;).', '')]).

syntax_diagnostics(Line, [lexer_error(Error)], [diagnostic(error, Line, Message, '')]) :- !,
    term_atom_safe(Error, ErrorAtom),
    atom_concat('Lexer AsaDB error: ', ErrorAtom, Message).
syntax_diagnostics(Line, Tokens, Diagnostics) :-
    paren_delta(Tokens, Delta),
    paren_diagnostic(Line, Delta, ParenDiagnostics),
    parse_diagnostic(Line, Tokens, ParseDiagnostics),
    correction_diagnostic(Line, Tokens, CorrectionDiagnostics),
    append(ParenDiagnostics, ParseDiagnostics, A),
    append(A, CorrectionDiagnostics, Diagnostics).

paren_delta(Tokens, Delta) :- paren_delta_(Tokens, 0, Delta).
paren_delta_([], Delta, Delta).
paren_delta_([sym('(')|Ts], Acc, Delta) :- !, Acc1 is Acc + 1, paren_delta_(Ts, Acc1, Delta).
paren_delta_([sym(')')|Ts], Acc, Delta) :- !, Acc1 is Acc - 1, paren_delta_(Ts, Acc1, Delta).
paren_delta_([_|Ts], Acc, Delta) :- paren_delta_(Ts, Acc, Delta).

paren_diagnostic(_, 0, []) :- !.
paren_diagnostic(Line, Delta, [diagnostic(error, Line, Message, '')]) :-
    ( Delta > 0 -> Message = 'Kurung buka belum ditutup.'
    ; Message = 'Kurung tutup berlebih.'
    ).

parse_diagnostic(_, Tokens, []) :-
    parse_statement(Tokens, Statement),
    \+ unsupported_statement(Statement), !.
parse_diagnostic(Line, Tokens, [diagnostic(error, Line, Message, '')]) :-
    parse_statement(Tokens, Statement),
    unsupported_statement(Statement), !,
    unsupported_message(Statement, Message).
parse_diagnostic(Line, Tokens, [diagnostic(error, Line, Message, Suggestion)]) :-
    first_token_name(Tokens, First),
    keyword_correction(First, Suggestion), !,
    atom_concat('Statement belum kebaca parser. Mungkin maksudnya ', Suggestion, M0),
    atom_concat(M0, '.', Message).
parse_diagnostic(Line, Tokens, [diagnostic(error, Line, 'Statement belum dikenali parser AsaDB.', '')]) :-
    Tokens \= [], !.
parse_diagnostic(_, [], []).

unsupported_statement(unsupported_mysql55(_, _)).
unsupported_statement(unsupported_mysql55(_)).

unsupported_message(unsupported_mysql55(Feature, _), Message) :- !,
    term_atom_safe(Feature, FeatureAtom),
    atom_concat('Fitur MySQL 5.5 belum aktif: ', FeatureAtom, Message).
unsupported_message(unsupported_mysql55(_), 'Statement MySQL 5.5 belum aktif di AsaDB.').

correction_diagnostic(_, [], []) :- !.
correction_diagnostic(Line, Tokens, Diagnostics) :-
    findall(diagnostic(warning, Line, Message, Suggestion),
            ( member(Token, Tokens),
              token_name(Token, Name),
              keyword_correction(Name, Suggestion),
              atom_concat('Auto correction tersedia: ', Name, A),
              atom_concat(A, ' -> ', B),
              atom_concat(B, Suggestion, Message)
            ),
            Raw),
    take_first_diagnostics(4, Raw, Diagnostics).

take_first_diagnostics(_, [], []).
take_first_diagnostics(0, _, []) :- !.
take_first_diagnostics(N, [D|Ds], [D|Rest]) :-
    N1 is N - 1,
    take_first_diagnostics(N1, Ds, Rest).

first_token_name([Token|_], Name) :- token_name(Token, Name), !.
first_token_name(_, '').

token_name(id(Name), Name).
token_name(kw(Name), Name).

keyword_correction(Name, Suggestion) :-
    downcase_atom(Name, Lower),
    sql_keyword_typo(Lower, Suggestion).

sql_keyword_typo(addd, 'ADD').
sql_keyword_typo(altr, 'ALTER').
sql_keyword_typo(cerate, 'CREATE').
sql_keyword_typo(creat, 'CREATE').
sql_keyword_typo(crete, 'CREATE').
sql_keyword_typo(databse, 'DATABASE').
sql_keyword_typo(databeses, 'DATABASES').
sql_keyword_typo(delet, 'DELETE').
sql_keyword_typo(delte, 'DELETE').
sql_keyword_typo(descibe, 'DESCRIBE').
sql_keyword_typo(descirbe, 'DESCRIBE').
sql_keyword_typo(drpo, 'DROP').
sql_keyword_typo(exsits, 'EXISTS').
sql_keyword_typo(frm, 'FROM').
sql_keyword_typo(form, 'FROM').
sql_keyword_typo(inesrt, 'INSERT').
sql_keyword_typo(instert, 'INSERT').
sql_keyword_typo(isnt, 'INT').
sql_keyword_typo(itno, 'INTO').
sql_keyword_typo(limt, 'LIMIT').
sql_keyword_typo(primay, 'PRIMARY').
sql_keyword_typo(slect, 'SELECT').
sql_keyword_typo(selct, 'SELECT').
sql_keyword_typo(selec, 'SELECT').
sql_keyword_typo(shwo, 'SHOW').
sql_keyword_typo(tabel, 'TABLE').
sql_keyword_typo(tbale, 'TABLE').
sql_keyword_typo(teble, 'TABLE').
sql_keyword_typo(udpate, 'UPDATE').
sql_keyword_typo(updte, 'UPDATE').
sql_keyword_typo(vaules, 'VALUES').
sql_keyword_typo(vlaues, 'VALUES').
sql_keyword_typo(wher, 'WHERE').
sql_keyword_typo(whree, 'WHERE').

sort_diagnostics(Diagnostics, Sorted) :-
    predsort(compare_diagnostics, Diagnostics, Sorted0),
    unique_diagnostics(Sorted0, Sorted).

compare_diagnostics(Order, diagnostic(S1, L1, M1, _), diagnostic(S2, L2, M2, _)) :-
    compare(LineOrder, L1, L2),
    ( LineOrder \= (=) -> Order = LineOrder
    ; severity_rank(S1, R1),
      severity_rank(S2, R2),
      compare(SeverityOrder, R1, R2),
      ( SeverityOrder \= (=) -> Order = SeverityOrder ; compare(Order, M1, M2) )
    ).

severity_rank(error, 0) :- !.
severity_rank(warning, 1) :- !.
severity_rank(_, 2).

unique_diagnostics([], []).
unique_diagnostics([D|Ds], [D|Out]) :- drop_same_diagnostics(D, Ds, Rest), unique_diagnostics(Rest, Out).

drop_same_diagnostics(_, [], []).
drop_same_diagnostics(diagnostic(S, L, M, _), [diagnostic(S, L, M, _)|Ds], Rest) :- !,
    drop_same_diagnostics(diagnostic(S, L, M, ''), Ds, Rest).
drop_same_diagnostics(_, Ds, Ds).

sql_codes(SQL, SQL) :- is_list(SQL), !.
sql_codes(SQL, Codes) :- atom(SQL), !, atom_codes(SQL, Codes).
sql_codes(SQL, Codes) :- string(SQL), !, string_codes(SQL, Codes).

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
                   Table,
                   Columns,
                   Groups0,
                   Groups,
                   Rest) :-
    same_identifier(Table, NextTable),
    same_identifier_list(Columns, NextColumns), !,
    collect_insert_run(Stmts, Table, Columns, [NextRows|Groups0], Groups, Rest).
collect_insert_run(Rest, _, _, RevGroups, Groups, Rest) :-
    reverse(RevGroups, Groups).

same_identifier_list([], []).
same_identifier_list([A|As], [B|Bs]) :-
    same_identifier(A, B),
    same_identifier_list(As, Bs).

parse_statements([], []).
parse_statements([[]|Rest], Statements) :- !, parse_statements(Rest, Statements).
parse_statements([Tokens|Rest], [Stmt|Statements]) :-
    parse_statement(Tokens, Stmt), !,
    parse_statements(Rest, Statements).
parse_statements([Tokens|Rest], [unsupported_mysql55(raw(Tokens))|Statements]) :-
    parse_statements(Rest, Statements).

/* -------------------------------------------------------------------------
   Lexer
   ------------------------------------------------------------------------- */

sql_tokens(Codes, Tokens) :- scan(Codes, Tokens0), remove_ws(Tokens0, Tokens).

remove_ws([], []).
remove_ws([ws|Ts], Clean) :- !, remove_ws(Ts, Clean).
remove_ws([T|Ts], [T|Clean]) :- remove_ws(Ts, Clean).

scan([], []).
scan([C|Cs], [ws|Ts]) :- is_space_code(C), !, scan(Cs, Ts).
scan([45,45|Cs], Ts) :- !, skip_line(Cs, Rest), scan(Rest, Ts).       % -- comment
scan([35|Cs], Ts) :- !, skip_line(Cs, Rest), scan(Rest, Ts).           % # comment
scan([47,42|Cs], Ts) :- !, skip_block_comment(Cs, Rest), scan(Rest, Ts). % /* */
scan([96|Cs], [id(A)|Ts]) :- !, take_until(96, Cs, IdCodes, Rest), atom_codes(A, IdCodes), scan(Rest, Ts).
scan([39|Cs], [str(A)|Ts]) :- !, take_string(39, Cs, StrCodes, Rest), atom_codes(A, StrCodes), scan(Rest, Ts).
scan([34|Cs], [str(A)|Ts]) :- !, take_string(34, Cs, StrCodes, Rest), atom_codes(A, StrCodes), scan(Rest, Ts).
scan([C|Cs], [num(N)|Ts]) :- is_digit_code(C), !, take_number(Cs, Ds, Rest), number_codes(N, [C|Ds]), scan(Rest, Ts).
scan([C|Cs], [Tok|Ts]) :- is_ident_start(C), !, take_ident(Cs, More, Rest), atom_codes(Atom0, [C|More]), normalize_atom(Atom0, Tok), scan(Rest, Ts).
scan([62,61|Cs], [op('>=')|Ts]) :- !, scan(Cs, Ts).
scan([60,61|Cs], [op('<=')|Ts]) :- !, scan(Cs, Ts).
scan([60,62|Cs], [op('<>')|Ts]) :- !, scan(Cs, Ts).
scan([33,61|Cs], [op('!=')|Ts]) :- !, scan(Cs, Ts).
scan([61|Cs], [op('=')|Ts]) :- !, scan(Cs, Ts).
scan([62|Cs], [op('>')|Ts]) :- !, scan(Cs, Ts).
scan([60|Cs], [op('<')|Ts]) :- !, scan(Cs, Ts).
scan([40|Cs], [sym('(')|Ts]) :- !, scan(Cs, Ts).
scan([41|Cs], [sym(')')|Ts]) :- !, scan(Cs, Ts).
scan([44|Cs], [sym(',')|Ts]) :- !, scan(Cs, Ts).
scan([59|Cs], [sym(';')|Ts]) :- !, scan(Cs, Ts).
scan([42|Cs], [sym('*')|Ts]) :- !, scan(Cs, Ts).
scan([46|Cs], [sym('.')|Ts]) :- !, scan(Cs, Ts).
scan([43|Cs], [op('+')|Ts]) :- !, scan(Cs, Ts).
scan([45|Cs], [op('-')|Ts]) :- !, scan(Cs, Ts).
scan([47|Cs], [op('/')|Ts]) :- !, scan(Cs, Ts).
scan([C|Cs], [char(C)|Ts]) :- scan(Cs, Ts).

skip_line([], []).
skip_line([10|Rest], Rest) :- !.
skip_line([_|Cs], Rest) :- skip_line(Cs, Rest).

skip_block_comment([], []).
skip_block_comment([42,47|Rest], Rest) :- !.
skip_block_comment([_|Cs], Rest) :- skip_block_comment(Cs, Rest).

take_until(_, [], [], []).
take_until(Q, [Q|Rest], [], Rest) :- !.
take_until(Q, [C|Cs], [C|Out], Rest) :- take_until(Q, Cs, Out, Rest).

take_string(_, [], [], []).
take_string(Q, [92,Q|Cs], [Q|Out], Rest) :- !, take_string(Q, Cs, Out, Rest).
take_string(Q, [Q|Rest], [], Rest) :- !.
take_string(Q, [C|Cs], [C|Out], Rest) :- take_string(Q, Cs, Out, Rest).

take_digits([C|Cs], [C|Ds], Rest) :- is_digit_code(C), !, take_digits(Cs, Ds, Rest).
take_digits(Rest, [], Rest).

take_number(Cs, Ds, Rest) :- take_digits(Cs, Int, Rest0), take_fraction(Rest0, Frac, Rest), append(Int, Frac, Ds).
take_fraction([46,C|Cs], [46,C|Ds], Rest) :- is_digit_code(C), !, take_digits(Cs, Ds, Rest).
take_fraction(Rest, [], Rest).

take_ident([C|Cs], [C|More], Rest) :- is_ident_code(C), !, take_ident(Cs, More, Rest).
take_ident(Rest, [], Rest).

is_space_code(9). is_space_code(10). is_space_code(13). is_space_code(32).
is_digit_code(C) :- C >= 48, C =< 57.
is_letter_code(C) :- C >= 65, C =< 90.
is_letter_code(C) :- C >= 97, C =< 122.
is_ident_start(C) :- is_letter_code(C), !.
is_ident_start(95).  % _
is_ident_code(C) :- is_ident_start(C), !.
is_ident_code(C) :- is_digit_code(C), !.
is_ident_code(36).   % $

normalize_atom(Atom0, kw(Atom)) :-
    downcase_atom(Atom0, Atom),
    keyword(Atom), !.
normalize_atom(Atom, id(Atom)).

keyword(add). keyword(all). keyword(alter). keyword(and). keyword(as). keyword(asc).
keyword(auto_increment). keyword(after). keyword(before). keyword(begin). keyword(between). keyword(bigint). keyword(binary).
keyword(blob). keyword(bool). keyword(boolean). keyword(by). keyword(cascade).
keyword(case). keyword(char). keyword(character). keyword(change). keyword(check). keyword(collate). keyword(column). keyword(columns). keyword(comment).
keyword(constraint). keyword(create). keyword(current_timestamp). keyword(database).
keyword(databases). keyword(date). keyword(datetime). keyword(decimal). keyword(default).
keyword(delete). keyword(desc). keyword(describe). keyword(distinct). keyword(double).
keyword(drop). keyword(each). keyword(else). keyword(end). keyword(engine). keyword(enum). keyword(exists). keyword(float).
keyword(for). keyword(foreign). keyword(from). keyword(grants). keyword(group). keyword(having). keyword(if).
keyword(identified). keyword(inout).
keyword(in). keyword(index). keyword(indexes). keyword(inner). keyword(insert). keyword(int). keyword(integer). keyword(into).
keyword(is). keyword(join). keyword(key). keyword(keys). keyword(left). keyword(like). keyword(limit). keyword(login).
keyword(longblob). keyword(longtext). keyword(mediumint). keyword(mediumtext). keyword(modify).
keyword(not). keyword(null). keyword(offset). keyword(on). keyword(or). keyword(order). keyword(out). keyword(outer). keyword(password). keyword(primary).
keyword(real). keyword(references). keyword(rename). keyword(return). keyword(returns). keyword(right). keyword(row). keyword(select). keyword(set).
keyword(show). keyword(smallint). keyword(table). keyword(tables). keyword(text). keyword(then).
keyword(time). keyword(timestamp). keyword(tinyint). keyword(tinytext). keyword(to).
keyword(union). keyword(unique). keyword(unsigned). keyword(update). keyword(user). keyword(use). keyword(values).
keyword(varchar). keyword(varbinary). keyword(where). keyword(year). keyword(zerofill).
keyword(truncate). keyword(view). keyword(trigger). keyword(procedure). keyword(function).
keyword(grant). keyword(revoke). keyword(commit). keyword(rollback). keyword(start).
keyword(transaction). keyword(lock). keyword(unlock). keyword(explain). keyword(analyze). keyword(when).

split_statements(Tokens, Statements) :- split_statements_(Tokens, [], [], Rev), reverse(Rev, Statements).
split_statements_([], Acc, Out, [Stmt|Out]) :- reverse(Acc, Stmt), !.
split_statements_([sym(';')|Ts], Acc, Out, Res) :- reverse(Acc, Stmt), !, split_statements_(Ts, [], [Stmt|Out], Res).
split_statements_([T|Ts], Acc, Out, Res) :- split_statements_(Ts, [T|Acc], Out, Res).

/* -------------------------------------------------------------------------
   Parser helpers
   ------------------------------------------------------------------------- */

parse_statement([kw(create),kw(database)|Rest], create_database(Name)) :-
    optional_if_not_exists(Rest, Rest2),
    parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(use)|Rest], use_database(Name)) :-
    parse_ident(Rest, Name, Tail), Tail = [].

parse_statement([kw(drop),kw(database)|Rest], drop_database(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(create),kw(table)|Rest], create_table(Name, Columns, Options)) :-
    optional_if_not_exists(Rest, Rest2),
    parse_ident(Rest2, Name, [sym('(')|AfterName]),
    take_paren_payload(AfterName, ColumnTokens, Tail),
    split_top_commas(ColumnTokens, ColumnDefs),
    parse_column_defs(ColumnDefs, Columns0),
    dedupe_columns(Columns0, Columns),
    Options = Tail.

parse_statement([kw(drop),kw(table)|Rest], drop_table(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(truncate),kw(table)|Rest], truncate_table(Name)) :-
    parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(truncate)|Rest], truncate_table(Name)) :-
    parse_ident(Rest, Name, Tail), Tail = [].

parse_statement([kw(insert),kw(into)|Rest], insert(Table, Columns, Rows)) :-
    parse_ident(Rest, Table, Rest1),
    ( Rest1 = [sym('(')|AfterOpen] ->
        take_paren_payload(AfterOpen, ColTokens, Rest2),
        parse_ident_list(ColTokens, Columns)
    ; Columns = [], Rest2 = Rest1
    ),
    Rest2 = [kw(values)|AfterValues],
    parse_value_groups(AfterValues, Rows, Tail), Tail = [].

parse_statement([kw(select)|Rest], union(Left, Right, Mode)) :-
    split_top_level_kw(union, [kw(select)|Rest], LeftTokens, AfterUnion), !,
    parse_statement(LeftTokens, Left),
    parse_union_right(AfterUnion, Right, Mode).
parse_statement([kw(select)|Rest], select(Projection, Source, Where, Group, Order, Limit)) :-
    split_top_level_kw(from, Rest, ProjectionTokens, AfterFrom),
    parse_projection(ProjectionTokens, Projection),
    split_select_source_tail(AfterFrom, SourceTokens, TailTokens),
    parse_from_source(SourceTokens, Source),
    parse_select_tail_ext(TailTokens, Where, Group, Order, Limit).

parse_statement([kw(update)|Rest], update(Table, Assignments, Where)) :-
    parse_ident(Rest, Table, [kw(set)|AfterSet]),
    split_optional_where(AfterSet, AssignTokens, WhereTokens),
    split_top_commas(AssignTokens, AssignParts),
    parse_assignments(AssignParts, Assignments),
    parse_where_tokens(WhereTokens, Where).

parse_statement([kw(delete),kw(from)|Rest], delete(Table, Where)) :-
    parse_ident(Rest, Table, AfterTable),
    ( AfterTable = [kw(where)|WhereTokens] -> parse_where_tokens(WhereTokens, Where)
    ; AfterTable = [], Where = true
    ).

parse_statement([kw(show),kw(databases)], show_databases).
parse_statement([kw(show),kw(tables)], show_tables).
parse_statement([kw(show),kw(columns),kw(from)|Rest], show_columns(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(index),kw(from)|Rest], show_index(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(indexes),kw(from)|Rest], show_index(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(keys),kw(from)|Rest], show_index(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(create),kw(table)|Rest], show_create_table(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(grants),kw(for)|Rest], show_grants(User)) :- parse_user_name(Rest, User, Tail), Tail = [].
parse_statement([kw(describe)|Rest], describe_table(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(desc)|Rest], describe_table(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].

parse_statement([kw(explain)|Rest], explain(raw(Rest))).

parse_statement([kw(create),kw(unique),kw(index)|Rest], create_index(Name, Table, Columns, unique)) :-
    parse_index_statement(Rest, Name, Table, Columns).
parse_statement([kw(create),kw(index)|Rest], create_index(Name, Table, Columns, non_unique)) :-
    parse_index_statement(Rest, Name, Table, Columns).
parse_statement([kw(drop),kw(index)|Rest], drop_index(Name, Table)) :-
    parse_ident(Rest, Name, [kw(on)|AfterOn]),
    parse_ident(AfterOn, Table, Tail), Tail = [].

parse_statement([kw(start),kw(transaction)], start_transaction).
parse_statement([kw(begin)], start_transaction).
parse_statement([kw(commit)], commit_transaction).
parse_statement([kw(rollback)], rollback_transaction).
parse_statement([kw(lock),kw(tables)|Rest], lock_tables(raw(Rest))).
parse_statement([kw(unlock),kw(tables)], unlock_tables).

parse_statement([kw(create),kw(user)|Rest], create_user(User, Password)) :-
    parse_user_name(Rest, User, [kw(identified),kw(by)|AfterBy]),
    parse_password(AfterBy, Password, Tail), Tail = [].
parse_statement([kw(drop),kw(user)|Rest], drop_user(User)) :-
    parse_user_name(Rest, User, Tail), Tail = [].
parse_statement([kw(grant)|Rest], grant_privilege(Privilege, Scope, User)) :-
    parse_ident(Rest, Privilege, [kw(on)|AfterOn]),
    parse_scope(AfterOn, Scope, [kw(to)|AfterTo]),
    parse_user_name(AfterTo, User, Tail), Tail = [].
parse_statement([kw(revoke)|Rest], revoke_privilege(Privilege, Scope, User)) :-
    parse_ident(Rest, Privilege, [kw(on)|AfterOn]),
    parse_scope(AfterOn, Scope, [kw(from)|AfterFrom]),
    parse_user_name(AfterFrom, User, Tail), Tail = [].
parse_statement([kw(login)|Rest], login_user(User, Password)) :-
    parse_user_name(Rest, User, [kw(identified),kw(by)|AfterBy]),
    parse_password(AfterBy, Password, Tail), Tail = [].

% ALTER TABLE operations
parse_statement([kw(alter),kw(table)|Rest], alter_table(Table, Operations)) :-
    parse_ident(Rest, Table, AfterTable),
    parse_alter_operations(AfterTable, Operations, Tail), Tail = [].

% Parse comma-separated ALTER operations
parse_alter_operations([], [], []) :- !.
parse_alter_operations(Tokens, [Op|Ops], Rest) :-
    parse_single_alter(Tokens, Op, AfterOp),
    ( AfterOp = [sym(',')|More] -> parse_alter_operations(More, Ops, Rest)
    ; Ops = [], Rest = AfterOp
    ).

% Parse individual ALTER operations
parse_single_alter([kw(add),kw(column)|Rest], add_column(Name, Type, Options), Tail) :- !,
    parse_ident(Rest, Name, AfterName),
    ( AfterName = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(add)|Rest], add_column(Name, Type, Options), Tail) :- !,
    parse_ident(Rest, Name, AfterName),
    ( AfterName = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(drop),kw(column)|Rest], drop_column(Name), Tail) :- !,
    parse_ident(Rest, Name, Tail).
parse_single_alter([kw(drop)|Rest], drop_column(Name), Tail) :- !,
    parse_ident(Rest, Name, Tail).
parse_single_alter([kw(modify),kw(column)|Rest], modify_column(Name, Type, Options), Tail) :- !,
    parse_ident(Rest, Name, AfterName),
    ( AfterName = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(modify)|Rest], modify_column(Name, Type, Options), Tail) :- !,
    parse_ident(Rest, Name, AfterName),
    ( AfterName = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(change),kw(column)|Rest], rename_column(OldName, NewName, Type, Options), Tail) :- !,
    parse_ident(Rest, OldName, AfterOld),
    parse_ident(AfterOld, NewName, AfterNew),
    ( AfterNew = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(change)|Rest], rename_column(OldName, NewName, Type, Options), Tail) :- !,
    parse_ident(Rest, OldName, AfterOld),
    parse_ident(AfterOld, NewName, AfterNew),
    ( AfterNew = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(rename),kw(column)|Rest], rename_column_simple(OldName, NewName), Tail) :- !,
    parse_ident(Rest, OldName, [kw(to)|AfterTo]),
    parse_ident(AfterTo, NewName, Tail).
parse_single_alter([kw(rename),kw(to)|Rest], rename_table(NewName), Tail) :- !,
    parse_ident(Rest, NewName, Tail).
parse_single_alter([kw(rename)|Rest], rename_table(NewName), Tail) :- !,
    parse_ident(Rest, NewName, Tail).

% Helper to identify column type tokens
is_column_type_token(T) :-
    ( T = kw(int) ; T = kw(integer) ; T = kw(bigint) ; T = kw(tinyint) ; T = kw(smallint)
    ; T = kw(float) ; T = kw(double) ; T = kw(real) ; T = kw(decimal)
    ; T = kw(varchar) ; T = kw(char) ; T = kw(text) ; T = kw(tinytext) ; T = kw(mediumtext) ; T = kw(longtext)
    ; T = kw(date) ; T = kw(time) ; T = kw(datetime) ; T = kw(timestamp) ; T = kw(year)
    ; T = kw(blob) ; T = kw(longblob)
    ), !.
parse_statement([kw(create),kw(view)|Rest], create_view(Name, SelectAST)) :-
    optional_if_not_exists(Rest, Rest2),
    parse_ident(Rest2, Name, [kw(as)|AfterAs]),
    parse_statement(AfterAs, SelectAST), !.

parse_statement([kw(drop),kw(view)|Rest], drop_view(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(create),kw(procedure)|Rest], create_procedure(Name, Params, Body)) :-
    parse_ident(Rest, Name, [sym('(')|AfterOpen]),
    take_paren_payload(AfterOpen, ParamTokens, [kw(begin)|BodyTokens]),
    parse_proc_params(ParamTokens, Params),
    take_until_kw(end, BodyTokens, RawBody, _),
    Body = raw_sql(RawBody), !.

parse_statement([kw(drop),kw(procedure)|Rest], drop_procedure(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(create),kw(function)|Rest], create_function(Name, Params, RetType, Body)) :-
    parse_ident(Rest, Name, [sym('(')|AfterOpen]),
    take_paren_payload(AfterOpen, ParamTokens, [kw(returns)|AfterReturns]),
    parse_proc_params(ParamTokens, Params),
    take_until_kw(begin, AfterReturns, RetTypeTokens, BodyTokens),
    tokens_text(RetTypeTokens, RetType),
    take_until_kw(end, BodyTokens, RawBody, _),
    Body = raw_sql(RawBody), !.

parse_statement([kw(drop),kw(function)|Rest], drop_function(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(create),kw(trigger)|Rest], create_trigger(Name, Event, Timing, Table, Body)) :-
    parse_ident(Rest, Name, [TimingTok,EventTok,kw(on)|AfterOn]),
    token_ident(TimingTok, TimingName),
    token_ident(EventTok, EventName),
    timing_keyword(TimingName, Timing),
    event_keyword(EventName, Event),
    parse_ident(AfterOn, Table, [kw(for)|AfterFor]),
    skip_to_begin(AfterFor, BodyTokens),
    take_until_kw(end, BodyTokens, RawBody, _),
    Body = raw_sql(RawBody), !.
parse_statement([kw(create),kw(trigger)|Rest], create_trigger(Name, Event, Timing, Table, Body)) :-
    parse_ident(Rest, Name, [EventTok,TimingTok,kw(on)|AfterOn]),
    token_ident(EventTok, EventName),
    token_ident(TimingTok, TimingName),
    event_keyword(EventName, Event),
    timing_keyword(TimingName, Timing),
    parse_ident(AfterOn, Table, [kw(for)|AfterFor]),
    skip_to_begin(AfterFor, BodyTokens),
    take_until_kw(end, BodyTokens, RawBody, _),
    Body = raw_sql(RawBody), !.

parse_statement([kw(drop),kw(trigger)|Rest], drop_trigger(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

% Helper predicates
parse_proc_params([], []) :- !.
parse_proc_params(Tokens, Params) :-
    split_top_commas(Tokens, ParamParts),
    parse_proc_param_parts(ParamParts, Params).

parse_proc_param_parts([], []).
parse_proc_param_parts([Part|Parts], [param(Name, Type)|Out]) :-
    parse_proc_param_part(Part, Name, Type), !,
    parse_proc_param_parts(Parts, Out).

parse_proc_param_part([ModeTok|Tokens], Name, Type) :-
    token_ident(ModeTok, Mode),
    param_mode(Mode), !,
    parse_proc_param_part(Tokens, Name, Type).
parse_proc_param_part([NameTok|TypeToks], Name, Type) :-
    token_ident(NameTok, Name),
    tokens_text(TypeToks, Type).

param_mode(in).
param_mode(out).
param_mode(inout).

take_until_kw(Kw, Tokens, Before, After) :-
    append(Before, [kw(Kw)|After], Tokens), !.
take_until_kw(_, Tokens, Tokens, []).

skip_to_begin([kw(begin)|Ts], Ts) :- !.
skip_to_begin([_|Ts], Result) :- skip_to_begin(Ts, Result).
skip_to_begin([], []).

event_keyword(kw(insert), insert) :- !.
event_keyword(kw(update), update) :- !.
event_keyword(kw(delete), delete) :- !.
event_keyword(insert, insert) :- !.
event_keyword(update, update) :- !.
event_keyword(delete, delete).

timing_keyword(kw(before), before) :- !.
timing_keyword(kw(after), after) :- !.
timing_keyword(before, before) :- !.
timing_keyword(after, after).

optional_if_not_exists([kw(if),kw(not),kw(exists)|Rest], Rest) :- !.
optional_if_not_exists(Rest, Rest).
optional_if_exists([kw(if),kw(exists)|Rest], Rest) :- !.
optional_if_exists(Rest, Rest).

parse_ident([id(Name)|Rest], Name, Rest) :- !.
parse_ident([kw(Name)|Rest], Name, Rest) :- !.
parse_ident([str(Name)|Rest], Name, Rest) :- !.

parse_index_statement(Rest, Name, Table, Columns) :-
    parse_ident(Rest, Name, [kw(on)|AfterOn]),
    parse_ident(AfterOn, Table, [sym('(')|AfterTable]),
    take_paren_payload(AfterTable, ColTokens, Tail),
    parse_ident_list(ColTokens, Columns),
    Tail = [].

parse_user_name(Tokens, User, Rest) :- parse_ident(Tokens, User, Rest).

parse_password([str(Password)|Rest], Password, Rest) :- !.
parse_password([id(Password)|Rest], Password, Rest) :- !.
parse_password([kw(Password)|Rest], Password, Rest) :- !.

parse_scope(Tokens, Scope, Tail) :-
    take_scope_tokens(Tokens, ScopeTokens, Tail),
    ScopeTokens \= [],
    tokens_text_no_space(ScopeTokens, Scope).

take_scope_tokens([kw(to)|Rest], [], [kw(to)|Rest]) :- !.
take_scope_tokens([kw(from)|Rest], [], [kw(from)|Rest]) :- !.
take_scope_tokens([T|Ts], [T|Scope], Tail) :- take_scope_tokens(Ts, Scope, Tail).

tokens_text_no_space(Tokens, Text) :-
    tokens_codes_no_space(Tokens, Codes),
    atom_codes(Text, Codes).

tokens_codes_no_space([], []).
tokens_codes_no_space([T|Ts], Codes) :-
    token_codes(T, C1),
    tokens_codes_no_space(Ts, C2),
    append(C1, C2, Codes).

split_once_kw(Kw, Tokens, Before, After) :-
    append(Before, [kw(Kw)|After], Tokens), !.

split_optional_where(Tokens, Before, Where) :-
    append(Before, [kw(where)|Where], Tokens), !.
split_optional_where(Tokens, Tokens, []).

take_paren_payload(Tokens, Payload, Tail) :- take_paren_payload_(Tokens, 0, [], Rev, Tail), reverse(Rev, Payload).
take_paren_payload_([sym(')')|Tail], 0, Acc, Acc, Tail) :- !.
take_paren_payload_([sym('(')|Ts], D, Acc, Payload, Tail) :- !, D2 is D + 1, take_paren_payload_(Ts, D2, [sym('(')|Acc], Payload, Tail).
take_paren_payload_([sym(')')|Ts], D, Acc, Payload, Tail) :- D > 0, !, D2 is D - 1, take_paren_payload_(Ts, D2, [sym(')')|Acc], Payload, Tail).
take_paren_payload_([T|Ts], D, Acc, Payload, Tail) :- take_paren_payload_(Ts, D, [T|Acc], Payload, Tail).

split_top_commas(Tokens, Parts) :-
    split_top_commas_(Tokens, 0, [], [], Rev),
    reverse(Rev, Ordered),
    reverse_clean(Ordered, Parts).
split_top_commas_([], _, Acc, Out, [Part|Out]) :- reverse(Acc, Part), !.
split_top_commas_([sym(',')|Ts], 0, Acc, Out, Res) :- reverse(Acc, Part), !, split_top_commas_(Ts, 0, [], [Part|Out], Res).
split_top_commas_([sym('(')|Ts], D, Acc, Out, Res) :- !, D2 is D + 1, split_top_commas_(Ts, D2, [sym('(')|Acc], Out, Res).
split_top_commas_([sym(')')|Ts], D, Acc, Out, Res) :- D > 0, !, D2 is D - 1, split_top_commas_(Ts, D2, [sym(')')|Acc], Out, Res).
split_top_commas_([T|Ts], D, Acc, Out, Res) :- split_top_commas_(Ts, D, [T|Acc], Out, Res).

reverse_clean([], []).
reverse_clean([[]|Xs], Ys) :- !, reverse_clean(Xs, Ys).
reverse_clean([X|Xs], [X|Ys]) :- reverse_clean(Xs, Ys).

parse_ident_list([], []).
parse_ident_list(Tokens, Names) :-
    split_top_commas(Tokens, Parts),
    parse_ident_parts(Parts, Names).
parse_ident_parts([], []).
parse_ident_parts([[id(N)]|Ps], [N|Ns]) :- !, parse_ident_parts(Ps, Ns).
parse_ident_parts([[kw(N)]|Ps], [N|Ns]) :- !, parse_ident_parts(Ps, Ns).
parse_ident_parts([[str(N)]|Ps], [N|Ns]) :- !, parse_ident_parts(Ps, Ns).

parse_column_defs([], []).
parse_column_defs([Def|Defs], Columns) :-
    ( parse_column_def(Def, Col) -> Columns = [Col|Rest]
    ; Columns = Rest
    ),
    parse_column_defs(Defs, Rest).

parse_column_def([kw(primary),kw(key)|_], _) :- !, fail.
parse_column_def([kw(key)|_], _) :- !, fail.
parse_column_def([kw(index)|_], _) :- !, fail.
parse_column_def([kw(unique)|_], _) :- !, fail.
parse_column_def([kw(constraint)|_], _) :- !, fail.
parse_column_def([NameTok|Rest], col(Name, Type, Options)) :-
    token_ident(NameTok, Name),
    split_type_options(Rest, TypeTokens, OptionTokens),
    tokens_text(TypeTokens, Type),
    parse_column_options(OptionTokens, Options).

token_ident(id(N), N).
token_ident(kw(N), N).
token_ident(str(N), N).

split_type_options(Tokens, TypeTokens, OptionTokens) :-
    split_type_options_(Tokens, [], TypeRev, OptionTokens), reverse(TypeRev, TypeTokens).
split_type_options_([], Acc, Acc, []).
split_type_options_([T|Ts], Acc, Acc, [T|Ts]) :- option_start(T), !.
split_type_options_([T|Ts], Acc, Type, Opt) :- split_type_options_(Ts, [T|Acc], Type, Opt).

% Extended version for ALTER TABLE that returns trailing tokens
split_type_options_ext(Tokens, TypeTokens, OptionTokens, Rest) :-
    split_type_options_ext_(Tokens, 0, [], TypeRev, OptionTokens, Rest),
    reverse(TypeRev, TypeTokens).
split_type_options_ext_([], _, TypeAcc, TypeAcc, [], []).
split_type_options_ext_([sym(',')|Ts], 0, TypeAcc, TypeAcc, [], [sym(',')|Ts]) :- !.
split_type_options_ext_([sym(';')|Ts], 0, TypeAcc, TypeAcc, [], [sym(';')|Ts]) :- !.
split_type_options_ext_([sym('(')|Ts], Depth, TypeAcc, TypeRev, OptionTokens, Rest) :- !,
    Depth1 is Depth + 1,
    split_type_options_ext_(Ts, Depth1, [sym('(')|TypeAcc], TypeRev, OptionTokens, Rest).
split_type_options_ext_([sym(')')|Ts], Depth, TypeAcc, TypeRev, OptionTokens, Rest) :- Depth > 0, !,
    Depth1 is Depth - 1,
    split_type_options_ext_(Ts, Depth1, [sym(')')|TypeAcc], TypeRev, OptionTokens, Rest).
split_type_options_ext_([T|Ts], 0, TypeAcc, TypeRev, OptionTokens, Rest) :-
    option_start(T), !,
    take_options([T|Ts], OptionTokens, Rest),
    TypeRev = TypeAcc.
split_type_options_ext_([T|Ts], Depth, TypeAcc, TypeRev, OptionTokens, Rest) :-
    split_type_options_ext_(Ts, Depth, [T|TypeAcc], TypeRev, OptionTokens, Rest).

take_options([], [], []).
take_options([sym(',')|Ts], [], [sym(',')|Ts]) :- !.
take_options([sym(';')|Ts], [], [sym(';')|Ts]) :- !.
take_options([kw(add)|Ts], [], [kw(add)|Ts]) :- !.
take_options([kw(drop)|Ts], [], [kw(drop)|Ts]) :- !.
take_options([kw(modify)|Ts], [], [kw(modify)|Ts]) :- !.
take_options([kw(change)|Ts], [], [kw(change)|Ts]) :- !.
take_options([kw(rename)|Ts], [], [kw(rename)|Ts]) :- !.
take_options([T|Ts], [T|Os], Rest) :- take_options(Ts, Os, Rest).

option_start(kw(not)). option_start(kw(null)). option_start(kw(default)).
option_start(kw(primary)). option_start(kw(key)). option_start(kw(auto_increment)).
option_start(kw(unique)). option_start(kw(comment)).

parse_column_options([], []).
parse_column_options([kw(not),kw(null)|Ts], [not_null|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([kw(null)|Ts], [nullable|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([kw(default),V|Ts], [default(Value)|Os]) :- !, token_value(V, Value), parse_column_options(Ts, Os).
parse_column_options([kw(primary),kw(key)|Ts], [primary_key|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([kw(auto_increment)|Ts], [auto_increment|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([kw(unique)|Ts], [unique|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([T|Ts], [raw_option(T)|Os]) :- parse_column_options(Ts, Os).

parse_value_groups([], [], []).
parse_value_groups([sym('(')|Tokens], [Values|Rows], Tail) :-
    take_paren_payload(Tokens, ValueTokens, AfterGroup),
    parse_values(ValueTokens, Values),
    ( AfterGroup = [sym(',')|More] -> parse_value_groups(More, Rows, Tail)
    ; Rows = [], Tail = AfterGroup
    ).

parse_values(Tokens, Values) :-
    split_top_commas(Tokens, Parts), parse_value_parts(Parts, Values).
parse_value_parts([], []).
parse_value_parts([Tokens|Ps], [Expr|Vs]) :-
    parse_expr(Tokens, Expr), !,
    parse_value_parts(Ps, Vs).
parse_value_parts([Tokens|Ps], [raw(Raw)|Vs]) :-
    tokens_text(Tokens, Raw0),
    normalize_space(atom(Raw), Raw0),
    parse_value_parts(Ps, Vs).

token_value(num(N), N) :- !.
token_value(str(S), S) :- !.
token_value(kw(null), null) :- !.
token_value(kw(current_timestamp), current_timestamp) :- !.
token_value(id(A), A) :- !.
token_value(kw(A), A) :- !.

parse_projection([sym('*')], all) :- !.
parse_projection(Tokens, Columns) :-
    parse_ident_list(Tokens, Columns),
    Columns \= [], !.
parse_projection(Tokens, Projections) :-
    split_top_commas(Tokens, Parts),
    parse_projection_parts(Parts, Projections).

parse_projection_parts([], []).
parse_projection_parts([Part|Parts], [projection(Label, Expr)|Out]) :-
    parse_projection_part(Part, Label, Expr),
    parse_projection_parts(Parts, Out).

parse_projection_part(Tokens, Label, Expr) :-
    append(ExprTokens, [kw(as), AliasTok], Tokens),
    token_ident(AliasTok, Label), !,
    parse_expr(ExprTokens, Expr).
parse_projection_part(Tokens, Label, Expr) :-
    append(ExprTokens, [AliasTok], Tokens),
    ExprTokens \= [],
    token_ident(AliasTok, Label),
    parse_expr(ExprTokens, Expr), !.
parse_projection_part(Tokens, Label, Expr) :-
    parse_expr(Tokens, Expr),
    expr_label(Expr, Label).

split_select_source_tail(Tokens, Source, Tail) :-
    split_select_source_tail_(Tokens, 0, [], SourceRev, Tail),
    reverse(SourceRev, Source).

split_select_source_tail_([], _, Acc, Acc, []).
split_select_source_tail_([kw(where)|Rest], 0, Acc, Acc, [kw(where)|Rest]) :- !.
split_select_source_tail_([kw(group),kw(by)|Rest], 0, Acc, Acc, [kw(group),kw(by)|Rest]) :- !.
split_select_source_tail_([kw(order),kw(by)|Rest], 0, Acc, Acc, [kw(order),kw(by)|Rest]) :- !.
split_select_source_tail_([kw(limit)|Rest], 0, Acc, Acc, [kw(limit)|Rest]) :- !.
split_select_source_tail_([sym('(')|Ts], D, Acc, Source, Tail) :- !,
    D1 is D + 1,
    split_select_source_tail_(Ts, D1, [sym('(')|Acc], Source, Tail).
split_select_source_tail_([sym(')')|Ts], D, Acc, Source, Tail) :- D > 0, !,
    D1 is D - 1,
    split_select_source_tail_(Ts, D1, [sym(')')|Acc], Source, Tail).
split_select_source_tail_([T|Ts], D, Acc, Source, Tail) :-
    split_select_source_tail_(Ts, D, [T|Acc], Source, Tail).

parse_from_source(Tokens, Source) :-
    parse_table_ref(Tokens, Left, Rest),
    parse_join_tail(Rest, Left, Source).

parse_join_tail([], Source, Source) :- !.
parse_join_tail([kw(inner),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, inner, Left, Source).
parse_join_tail([kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, inner, Left, Source).
parse_join_tail([kw(left),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, left, Left, Source).
parse_join_tail([kw(left),kw(outer),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, left, Left, Source).
parse_join_tail([kw(right),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, right, Left, Source).
parse_join_tail([kw(right),kw(outer),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, right, Left, Source).

parse_join_right(Tokens, Kind, Left, Source) :-
    parse_table_ref(Tokens, Right, [kw(on)|AfterOn]),
    split_join_on_tail(AfterOn, OnTokens, Rest),
    parse_where_tokens(OnTokens, On),
    parse_join_tail(Rest, join(Kind, Left, Right, On), Source).

split_join_on_tail(Tokens, On, Rest) :-
    split_join_on_tail_(Tokens, 0, [], OnRev, Rest),
    reverse(OnRev, On).

split_join_on_tail_([], _, Acc, Acc, []).
split_join_on_tail_([kw(inner),kw(join)|Rest], 0, Acc, Acc, [kw(inner),kw(join)|Rest]) :- !.
split_join_on_tail_([kw(join)|Rest], 0, Acc, Acc, [kw(join)|Rest]) :- !.
split_join_on_tail_([kw(left),kw(join)|Rest], 0, Acc, Acc, [kw(left),kw(join)|Rest]) :- !.
split_join_on_tail_([kw(left),kw(outer),kw(join)|Rest], 0, Acc, Acc, [kw(left),kw(outer),kw(join)|Rest]) :- !.
split_join_on_tail_([kw(right),kw(join)|Rest], 0, Acc, Acc, [kw(right),kw(join)|Rest]) :- !.
split_join_on_tail_([kw(right),kw(outer),kw(join)|Rest], 0, Acc, Acc, [kw(right),kw(outer),kw(join)|Rest]) :- !.
split_join_on_tail_([sym('(')|Ts], D, Acc, On, Rest) :- !,
    D1 is D + 1,
    split_join_on_tail_(Ts, D1, [sym('(')|Acc], On, Rest).
split_join_on_tail_([sym(')')|Ts], D, Acc, On, Rest) :- D > 0, !,
    D1 is D - 1,
    split_join_on_tail_(Ts, D1, [sym(')')|Acc], On, Rest).
split_join_on_tail_([T|Ts], D, Acc, On, Rest) :-
    split_join_on_tail_(Ts, D, [T|Acc], On, Rest).

parse_table_ref(Tokens, table_ref(Name, Alias), Tail) :-
    parse_ident(Tokens, Name, Rest),
    parse_optional_table_alias(Rest, Alias, Tail).

parse_optional_table_alias([kw(as),AliasTok|Rest], Alias, Rest) :-
    token_ident(AliasTok, Alias), !.
parse_optional_table_alias([Tok|Rest], Alias, Rest) :-
    token_ident(Tok, Alias),
    \+ select_source_boundary_token(Tok), !.
parse_optional_table_alias(Rest, none, Rest).

select_source_boundary_token(kw(inner)).
select_source_boundary_token(kw(join)).
select_source_boundary_token(kw(left)).
select_source_boundary_token(kw(right)).
select_source_boundary_token(kw(outer)).
select_source_boundary_token(kw(on)).

parse_select_tail_ext([], true, none, none, none) :- !.
parse_select_tail_ext(Tokens, Where, Group, Order, Limit) :-
    extract_clause_ext(where, Tokens, WhereTokens, Rest1),
    parse_where_tokens(WhereTokens, Where),
    extract_group(Rest1, Group, Rest2),
    extract_order(Rest2, Order, Rest3),
    extract_limit(Rest3, Limit, _).

extract_clause_ext(Kw, [kw(Kw)|Tokens], Clause, Rest) :- !,
    take_until_clause_ext(Tokens, Clause, Rest).
extract_clause_ext(_, Tokens, [], Tokens).

take_until_clause_ext([], [], []).
take_until_clause_ext([kw(group),kw(by)|Rest], [], [kw(group),kw(by)|Rest]) :- !.
take_until_clause_ext([kw(order),kw(by)|Rest], [], [kw(order),kw(by)|Rest]) :- !.
take_until_clause_ext([kw(limit)|Rest], [], [kw(limit)|Rest]) :- !.
take_until_clause_ext([T|Ts], [T|Clause], Rest) :- take_until_clause_ext(Ts, Clause, Rest).

extract_group([kw(group),kw(by)|Tokens], group(Items), Rest) :- !,
    take_until_order_limit(Tokens, Raw, Rest),
    parse_group_items(Raw, Items).
extract_group(Tokens, none, Tokens).

take_until_order_limit([], [], []).
take_until_order_limit([kw(order),kw(by)|Rest], [], [kw(order),kw(by)|Rest]) :- !.
take_until_order_limit([kw(limit)|Rest], [], [kw(limit)|Rest]) :- !.
take_until_order_limit([T|Ts], [T|Raw], Rest) :- take_until_order_limit(Ts, Raw, Rest).

parse_group_items([], []).
parse_group_items(Tokens, Items) :-
    split_top_commas(Tokens, Parts),
    parse_expr_parts(Parts, Items).

parse_union_right([kw(all)|Tokens], Right, all) :- !,
    parse_statement(Tokens, Right).
parse_union_right(Tokens, Right, distinct) :-
    parse_statement(Tokens, Right).

parse_select_tail([], true, none, none) :- !.
parse_select_tail(Tokens, Where, Order, Limit) :-
    extract_clause(where, Tokens, WhereTokens, Rest1),
    parse_where_tokens(WhereTokens, Where),
    extract_order(Rest1, Order, Rest2),
    extract_limit(Rest2, Limit, _).

extract_clause(Kw, Tokens, Clause, Rest) :-
    append(_, [kw(Kw)|_], Tokens), !,
    append(Before, [kw(Kw)|After], Tokens),
    Before = [],
    take_until_clause(After, Clause, Rest).
extract_clause(_, Tokens, [], Tokens).

take_until_clause([], [], []).
take_until_clause([kw(order),kw(by)|Rest], [], [kw(order),kw(by)|Rest]) :- !.
take_until_clause([kw(limit)|Rest], [], [kw(limit)|Rest]) :- !.
take_until_clause([T|Ts], [T|Clause], Rest) :- take_until_clause(Ts, Clause, Rest).

extract_order([kw(order),kw(by)|Tokens], order(Items), Rest) :- !,
    take_until_limit(Tokens, Raw, Rest),
    parse_order_items(Raw, Items).
extract_order(Tokens, none, Tokens).

take_until_limit([], [], []).
take_until_limit([kw(limit)|Rest], [], [kw(limit)|Rest]) :- !.
take_until_limit([T|Ts], [T|Raw], Rest) :- take_until_limit(Ts, Raw, Rest).

extract_limit([kw(limit),num(Offset),sym(','),num(N)|Rest], limit(Offset,N), Rest) :- !.
extract_limit([kw(limit),num(N),kw(offset),num(Offset)|Rest], limit(Offset,N), Rest) :- !.
extract_limit([kw(limit),num(N)|Rest], limit(0,N), Rest) :- !.
extract_limit(Tokens, none, Tokens).

parse_order_items([], []).
parse_order_items(Tokens, Items) :-
    split_top_commas(Tokens, Parts),
    parse_order_parts(Parts, Items).

parse_order_parts([], []).
parse_order_parts([Part|Parts], [order(Expr, Dir)|Out]) :-
    parse_order_part(Part, Expr, Dir),
    parse_order_parts(Parts, Out).

parse_order_part(Tokens, Expr, desc) :-
    append(ExprTokens, [kw(desc)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_order_part(Tokens, Expr, asc) :-
    append(ExprTokens, [kw(asc)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_order_part(Tokens, Expr, asc) :- parse_expr(Tokens, Expr).

parse_assignments([], []).
parse_assignments([Part|Parts], [assign(Name, Value)|As]) :-
    parse_assignment(Part, assign(Name, Value)), !,
    parse_assignments(Parts, As).
parse_assignment([NameTok,op('=')|ValueTokens], assign(Name, Expr)) :-
    token_ident(NameTok, Name), parse_expr(ValueTokens, Expr).

parse_where_tokens([], true) :- !.
parse_where_tokens(Tokens, Where) :- parse_expr(Tokens, Where), !.
parse_where_tokens(Tokens, raw_where(Tokens)).

parse_expr([sym('(')|Tokens], subquery(SelectAST)) :-
    take_paren_payload(Tokens, Inner, []),
    Inner = [kw(select)|_], !,
    parse_statement(Inner, SelectAST).
parse_expr(Tokens, Expr) :- strip_outer_parens(Tokens, Inner), Inner \= Tokens, !, parse_expr(Inner, Expr).
parse_expr(Tokens, or(A,B)) :-
    split_top_level_kw(or, Tokens, Left, Right), !,
    parse_expr(Left, A), parse_expr(Right, B).
parse_expr(Tokens, between(Expr, Low, High)) :-
    split_top_level_kw(between, Tokens, Left, AfterBetween),
    split_top_level_kw(and, AfterBetween, LowTokens, HighTokens), !,
    parse_expr(Left, Expr), parse_expr(LowTokens, Low), parse_expr(HighTokens, High).
parse_expr(Tokens, and(A,B)) :-
    split_top_level_kw(and, Tokens, Left, Right), !,
    parse_expr(Left, A), parse_expr(Right, B).
parse_expr([kw(not)|Tokens], not(Expr)) :- !, parse_expr(Tokens, Expr).
parse_expr(Tokens, cmp(Op, A, B)) :-
    split_top_level_op(Op, Tokens, Left, Right),
    comparison_op(Op), !,
    parse_expr(Left, A), parse_expr(Right, B).
parse_expr(Tokens, is_null(Expr)) :-
    append(ExprTokens, [kw(is),kw(null)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, is_not_null(Expr)) :-
    append(ExprTokens, [kw(is),kw(not),kw(null)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, like(Expr, Pattern)) :-
    split_top_level_kw(like, Tokens, Left, Right), !,
    parse_expr(Left, Expr), parse_expr(Right, Pattern).
parse_expr(Tokens, in_subquery(Expr, SelectAST)) :-
    split_top_level_kw(in, Tokens, Left, [sym('(')|AfterIn]),
    take_paren_payload(AfterIn, SelectTokens, []),
    SelectTokens = [kw(select)|_], !,
    parse_expr(Left, Expr),
    parse_statement(SelectTokens, SelectAST).
parse_expr(Tokens, in_list(Expr, Values)) :-
    split_top_level_kw(in, Tokens, Left, [sym('(')|AfterIn]),
    take_paren_payload(AfterIn, ValueTokens, []), !,
    parse_expr(Left, Expr),
    parse_expr_list(ValueTokens, Values).
parse_expr([kw(exists),sym('(')|Rest], exists_subquery(SelectAST)) :-
    take_paren_payload(Rest, SelectTokens, []),
    SelectTokens = [kw(select)|_], !,
    parse_statement(SelectTokens, SelectAST).
parse_expr(Tokens, Expr) :- parse_additive(Tokens, Expr).

parse_additive(Tokens, add(A,B)) :-
    split_top_level_op('+', Tokens, Left, Right), !,
    parse_additive(Left, A), parse_multiplicative(Right, B).
parse_additive(Tokens, sub(A,B)) :-
    split_top_level_op('-', Tokens, Left, Right), Left \= [], !,
    parse_additive(Left, A), parse_multiplicative(Right, B).
parse_additive(Tokens, Expr) :- parse_multiplicative(Tokens, Expr).

parse_multiplicative(Tokens, mul(A,B)) :-
    split_top_level_sym('*', Tokens, Left, Right), !,
    parse_multiplicative(Left, A), parse_unary(Right, B).
parse_multiplicative(Tokens, div(A,B)) :-
    split_top_level_op('/', Tokens, Left, Right), !,
    parse_multiplicative(Left, A), parse_unary(Right, B).
parse_multiplicative(Tokens, Expr) :- parse_unary(Tokens, Expr).

parse_unary([op('-')|Tokens], neg(Expr)) :- !, parse_primary(Tokens, Expr).
parse_unary(Tokens, Expr) :- parse_primary(Tokens, Expr).

parse_primary([num(N)], value(N)) :- !.
parse_primary([str(S)], value(S)) :- !.
parse_primary([kw(null)], value(null)) :- !.
parse_primary([kw(current_timestamp)], value(current_timestamp)) :- !.
parse_primary([sym('*')], all) :- !.
parse_primary([kw(case)|Tokens], case(Whens, Else)) :-
    parse_case_expression(Tokens, Whens, Else), !.
parse_primary([QualifierTok,sym('.'),NameTok], qcol(Qualifier, Name)) :-
    token_ident(QualifierTok, Qualifier),
    token_ident(NameTok, Name), !.
parse_primary([id(Name0),sym('(')|Rest], func(Name, Args)) :-
    take_paren_payload(Rest, ArgTokens, []), !,
    downcase_atom(Name0, Name),
    parse_expr_list(ArgTokens, Args).
parse_primary([kw(Name),sym('(')|Rest], func(Name, Args)) :-
    take_paren_payload(Rest, ArgTokens, []), !,
    parse_expr_list(ArgTokens, Args).
parse_primary([id(Name)], col(Name)) :- !.
parse_primary([kw(Name)], col(Name)) :- !.
parse_primary([sym('(')|Tokens], subquery(SelectAST)) :-
    take_paren_payload(Tokens, Inner, []),
    Inner = [kw(select)|_], !,
    parse_statement(Inner, SelectAST).
parse_primary([sym('(')|Tokens], Expr) :-
    take_paren_payload(Tokens, Inner, []), !,
    parse_expr(Inner, Expr).

parse_expr_list([], []) :- !.
parse_expr_list([sym('*')], [all]) :- !.
parse_expr_list(Tokens, Exprs) :-
    split_top_commas(Tokens, Parts),
    parse_expr_parts(Parts, Exprs).

parse_expr_parts([], []).
parse_expr_parts([Part|Parts], [Expr|Exprs]) :-
    parse_expr(Part, Expr),
    parse_expr_parts(Parts, Exprs).

parse_case_expression(Tokens, Whens, Else) :-
    take_until_case_end(Tokens, Body, []),
    ( Body = [kw(when)|_] ->
        parse_case_whens(Body, Whens, Else)
    ;   split_top_level_kw(when, Body, BaseTokens, AfterWhen),
        parse_expr(BaseTokens, Base),
        parse_simple_case_whens(Base, [kw(when)|AfterWhen], Whens, Else)
    ).

take_until_case_end(Tokens, Body, Rest) :-
    take_until_case_end_(Tokens, 0, [], Rev, Rest),
    reverse(Rev, Body).

take_until_case_end_([], _, Acc, Acc, []).
take_until_case_end_([kw(case)|Tokens], Depth, Acc, Body, Rest) :- !,
    D1 is Depth + 1,
    take_until_case_end_(Tokens, D1, [kw(case)|Acc], Body, Rest).
take_until_case_end_([kw(end)|Tokens], 0, Acc, Acc, Tokens) :- !.
take_until_case_end_([kw(end)|Tokens], Depth, Acc, Body, Rest) :- Depth > 0, !,
    D1 is Depth - 1,
    take_until_case_end_(Tokens, D1, [kw(end)|Acc], Body, Rest).
take_until_case_end_([T|Tokens], Depth, Acc, Body, Rest) :-
    take_until_case_end_(Tokens, Depth, [T|Acc], Body, Rest).

parse_case_whens([kw(when)|Tokens], [when(Condition, Value)|Whens], Else) :- !,
    split_top_level_kw(then, Tokens, ConditionTokens, AfterThen),
    take_until_case_next(AfterThen, ValueTokens, Rest),
    parse_expr(ConditionTokens, Condition),
    parse_expr(ValueTokens, Value),
    parse_case_rest(Rest, Whens, Else).

parse_simple_case_whens(Base, [kw(when)|Tokens], [when(cmp('=', Base, Match), Value)|Whens], Else) :- !,
    split_top_level_kw(then, Tokens, MatchTokens, AfterThen),
    take_until_case_next(AfterThen, ValueTokens, Rest),
    parse_expr(MatchTokens, Match),
    parse_expr(ValueTokens, Value),
    parse_simple_case_rest(Base, Rest, Whens, Else).

parse_case_rest([kw(when)|Tokens], Whens, Else) :- !,
    parse_case_whens([kw(when)|Tokens], Whens, Else).
parse_case_rest([kw(else)|Tokens], [], Else) :- !,
    parse_expr(Tokens, Else).
parse_case_rest([], [], value(null)).

parse_simple_case_rest(Base, [kw(when)|Tokens], Whens, Else) :- !,
    parse_simple_case_whens(Base, [kw(when)|Tokens], Whens, Else).
parse_simple_case_rest(_, [kw(else)|Tokens], [], Else) :- !,
    parse_expr(Tokens, Else).
parse_simple_case_rest(_, [], [], value(null)).

take_until_case_next(Tokens, ExprTokens, Rest) :-
    take_until_case_next_(Tokens, 0, [], Rev, Rest),
    reverse(Rev, ExprTokens).

take_until_case_next_([], _, Acc, Acc, []).
take_until_case_next_([kw(when)|Rest], 0, Acc, Acc, [kw(when)|Rest]) :- !.
take_until_case_next_([kw(else)|Rest], 0, Acc, Acc, [kw(else)|Rest]) :- !.
take_until_case_next_([kw(case)|Tokens], Depth, Acc, Expr, Rest) :- !,
    D1 is Depth + 1,
    take_until_case_next_(Tokens, D1, [kw(case)|Acc], Expr, Rest).
take_until_case_next_([kw(end)|Tokens], Depth, Acc, Expr, Rest) :- Depth > 0, !,
    D1 is Depth - 1,
    take_until_case_next_(Tokens, D1, [kw(end)|Acc], Expr, Rest).
take_until_case_next_([sym('(')|Tokens], Depth, Acc, Expr, Rest) :- !,
    D1 is Depth + 1,
    take_until_case_next_(Tokens, D1, [sym('(')|Acc], Expr, Rest).
take_until_case_next_([sym(')')|Tokens], Depth, Acc, Expr, Rest) :- Depth > 0, !,
    D1 is Depth - 1,
    take_until_case_next_(Tokens, D1, [sym(')')|Acc], Expr, Rest).
take_until_case_next_([T|Tokens], Depth, Acc, Expr, Rest) :-
    take_until_case_next_(Tokens, Depth, [T|Acc], Expr, Rest).

comparison_op('='). comparison_op('!='). comparison_op('<>').
comparison_op('>'). comparison_op('<'). comparison_op('>=').
comparison_op('<=').

strip_outer_parens([sym('(')|Tokens], Inner) :-
    take_paren_payload(Tokens, Inner, []), !.
strip_outer_parens(Tokens, Tokens).

split_top_level_kw(Kw, Tokens, Left, Right) :-
    split_top_level_token(kw(Kw), Tokens, Left, Right).

split_top_level_op(Op, Tokens, Left, Right) :-
    split_top_level_token(op(Op), Tokens, Left, Right).

split_top_level_sym(Sym, Tokens, Left, Right) :-
    split_top_level_token(sym(Sym), Tokens, Left, Right).

split_top_level_token(Target, Tokens, Left, Right) :-
    split_top_level_token_(Tokens, Target, 0, [], Left, Right).

split_top_level_token_([], _, _, _, _, _) :- fail.
split_top_level_token_([Target|Ts], Target, 0, Acc, Left, Ts) :- !, reverse(Acc, Left), Left \= [].
split_top_level_token_([sym('(')|Ts], Target, D, Acc, Left, Right) :- !,
    D1 is D + 1, split_top_level_token_(Ts, Target, D1, [sym('(')|Acc], Left, Right).
split_top_level_token_([sym(')')|Ts], Target, D, Acc, Left, Right) :- D > 0, !,
    D1 is D - 1, split_top_level_token_(Ts, Target, D1, [sym(')')|Acc], Left, Right).
split_top_level_token_([kw(case)|Ts], Target, D, Acc, Left, Right) :- !,
    D1 is D + 1, split_top_level_token_(Ts, Target, D1, [kw(case)|Acc], Left, Right).
split_top_level_token_([kw(end)|Ts], Target, D, Acc, Left, Right) :- D > 0, !,
    D1 is D - 1, split_top_level_token_(Ts, Target, D1, [kw(end)|Acc], Left, Right).
split_top_level_token_([T|Ts], Target, D, Acc, Left, Right) :-
    split_top_level_token_(Ts, Target, D, [T|Acc], Left, Right).

expr_label(col(Name), Name) :- !.
expr_label(qcol(Qualifier, Name), Label) :- !,
    qualified_column_atom(Qualifier, Name, Label).
expr_label(func(Name, _), Name) :- !.
expr_label(Expr, Label) :- term_atom_safe(Expr, Label).

tokens_text(Tokens, Text) :-
    tokens_codes(Tokens, Codes), atom_codes(Text, Codes).

tokens_codes([], []).
tokens_codes([T|Ts], Codes) :- token_codes(T, C1), tokens_codes(Ts, C2), append(C1, [32|C2], Codes).

token_codes(kw(A), C) :- atom_codes(A, C).
token_codes(id(A), C) :- atom_codes(A, C).
token_codes(str(A), C) :- atom_codes(A, AC), append([39|AC], [39], C).
token_codes(num(N), C) :- number_codes(N, C).
token_codes(sym(S), C) :- atom_codes(S, C).
token_codes(op(O), C) :- atom_codes(O, C).
token_codes(char(C), [C]).

/* -------------------------------------------------------------------------
   Executor
   ------------------------------------------------------------------------- */

execute_statement(unsupported_mysql55(alter_table, raw([kw(table)|Rest])), Result) :-
    parse_statement([kw(alter),kw(table)|Rest], Statement), !,
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
    persist_current_db(Name).

execute_statement(drop_database(Name), ok(dropped_database(Name))) :-
    update_state(drop_db(Name)),
    ( asadb_current_db(Name) ->
        retractall(asadb_current_db(_)),
        clear_persisted_current_db
    ; true ).

execute_statement(create_table(Name, Columns, _Options), ok(created_table(Name))) :-
    current_db_or_default(DB),
    update_state(create_table(DB, Name, Columns)).

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
    storage_source_rows(DB, Table, Alias, Columns, Indexes, RowStorage, Where, Order, Limit, Filtered),
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

execute_statement(lock_tables(raw(Rest)), ok(locked_tables(Tables))) :-
    parse_lock_targets(Rest, Tables),
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
    asadb_state(state(_, DBs)), db_names(DBs, Names), atoms_rows(Names, Rows).

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

execute_statement(explain(raw(Rest)), table([explain], [[Rest]])).

execute_statement(Stmt, error(unknown_statement, Stmt)).

union_rows(all, Rows, Rows) :- !.
union_rows(distinct, Rows, UniqueRows) :- sort(Rows, UniqueRows).

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
    findall(Joined,
            ( member(L, LeftRows),
              member(R, RightRows),
              combine_rows(L, R, Joined),
              row_matches(Joined, On)
            ),
            JoinedRows).
join_rows(left, LeftRows, RightRows, _, NullRight, On, _, _, JoinedRows) :- !,
    note_plan(nested_loop_join),
    left_join_rows(LeftRows, RightRows, NullRight, On, JoinedRows).
join_rows(right, LeftRows, RightRows, NullLeft, _, On, _, _, JoinedRows) :- !,
    note_plan(nested_loop_join),
    right_join_rows(RightRows, LeftRows, NullLeft, On, JoinedRows).

% A simple qualified equality is the overwhelmingly common JOIN shape.  The
% old implementation compared every left row with every right row (O(n*m)).
% Resolve which operand belongs to each source and use an AVL-backed lookup
% index instead.  Complex ON predicates deliberately retain the compatible
% nested-loop fallback above.
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
left_join_rows([L|Ls], RightRows, NullRight, On, Rows) :-
    findall(Joined,
            ( member(R, RightRows),
              combine_rows(L, R, Joined),
              row_matches(Joined, On)
            ),
            Matches),
    ( Matches = [] ->
        combine_rows(L, NullRight, NullJoined),
        Rows = [NullJoined|Rest]
    ;   append(Matches, Rest, Rows)
    ),
    left_join_rows(Ls, RightRows, NullRight, On, Rest).

right_join_rows([], _, _, _, []).
right_join_rows([R|Rs], LeftRows, NullLeft, On, Rows) :-
    findall(Joined,
            ( member(L, LeftRows),
              combine_rows(L, R, Joined),
              row_matches(Joined, On)
            ),
            Matches),
    ( Matches = [] ->
        combine_rows(NullLeft, R, NullJoined),
        Rows = [NullJoined|Rest]
    ;   append(Matches, Rest, Rows)
    ),
    right_join_rows(Rs, LeftRows, NullLeft, On, Rest).

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
      persist_state_after_write(Action)
    ).

persist_state_after_write(_) :- asadb_tx_snapshot(_), !.
persist_state_after_write(Action) :- paged_storage_action(Action), !,
    assert_checkpoint_dirty,
    ( asadb_query_batch_depth(_) -> true ; asadb_save_locked ).
persist_state_after_write(Action) :- append_wal(Action).

assert_checkpoint_dirty :-
    ( asadb_checkpoint_dirty -> true ; assertz(asadb_checkpoint_dirty) ).

paged_storage_action(create_table(_, _, _)).
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
action_table(drop_table(DB, Table), DB, Table).
action_table(truncate_table(DB, Table), DB, Table).
action_table(insert_rows(DB, Table, _, _), DB, Table).
action_table(update_rows(DB, Table, _, _, _), DB, Table).
action_table(delete_rows(DB, Table, _), DB, Table).
action_table(create_index(DB, Table, _, _, _), DB, Table).
action_table(drop_index(DB, Table, _), DB, Table).

invalidate_index_cache(Action) :-
    action_table(Action, DB, Table), !,
    retractall(asadb_btree_cache(DB, Table, _, _)).
invalidate_index_cache(drop_db(DB)) :- !,
    retractall(asadb_btree_cache(DB, _, _, _)).
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

parse_lock_targets(Tokens, Tables) :-
    split_top_commas(Tokens, Parts),
    parse_lock_parts(Parts, Tables).

parse_lock_parts([], []).
parse_lock_parts([Part|Parts], [DB-Table|Out]) :-
    parse_lock_part(Part, DB, Table),
    parse_lock_parts(Parts, Out).

parse_lock_part(Tokens, DB, Table) :-
    parse_ident(Tokens, Table, _),
    current_db_or_default(DB).

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
    asadb_record_insert_batch(StoreId, NewRows),
    asadb_record_invalidate_indexes(StoreId),
    length(NewRows, Added),
    Count is Count0 + Added,
    NewTables = [table(Name, TableColumns, paged_rows(StoreId, Count, Counters), Indexes)|OtherTables].
apply_db_action(insert_rows_in_db(Name, Columns, ValueRows), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, TableColumns, Rows, Indexes), OtherTables),
    build_rows(TableColumns, Columns, ValueRows, Rows, NewRows),
    append(Rows, NewRows, AllRows),
    NewTables = [table(Name, TableColumns, AllRows, Indexes)|OtherTables].
apply_db_action(update_rows_in_db(Name, Assignments, Where, Count), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, Columns, paged_rows(StoreId, Count0, Counters), Indexes), OtherTables), !,
    ( paged_indexed_updates(DB, Name, StoreId, Indexes, Assignments, Where, Updates) ->
        asadb_record_update_batch(StoreId, Updates, Count),
        NewCount = Count0
    ; asadb_record_rewrite(StoreId, paged_update_transform(Assignments, Where), NewCount, Count, _)
    ),
    maybe_invalidate_update_indexes(StoreId, Indexes, Assignments),
    NewTables = [table(Name, Columns, paged_rows(StoreId, NewCount, Counters), Indexes)|OtherTables].
apply_db_action(update_rows_in_db(Name, Assignments, Where, Count), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, Columns, Rows, Indexes), OtherTables),
    update_matching_rows(Rows, Assignments, Where, NewRows, Count),
    NewTables = [table(Name, Columns, NewRows, Indexes)|OtherTables].
apply_db_action(delete_rows_in_db(Name, Where, Count), db(DB, Tables, V, F, P, T), db(DB, NewTables, V, F, P, T)) :-
    select_table(Name, Tables, table(Name, Columns, paged_rows(StoreId, Count0, Counters), Indexes), OtherTables), !,
    ( paged_indexed_deletes(DB, Name, StoreId, Indexes, Where, Rids) ->
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

paged_indexed_updates(DB, Table, StoreId, Indexes, Assignments, Where, Updates) :-
    indexed_column_predicate(Where, Indexes, Col, Op, Value),
    ensure_persistent_btree(DB, Table, StoreId, Col, File),
    findall(Rid-NewRow,
            ( asadb_btree_file_candidate(File, Op, Value, Rid),
              asadb_record_read(StoreId, Rid, Row),
              row_matches(Row, Where),
              apply_assignments(Row, Assignments, NewRow)
            ),
            Updates).

paged_indexed_deletes(DB, Table, StoreId, Indexes, Where, Rids) :-
    indexed_column_predicate(Where, Indexes, Col, Op, Value),
    ensure_persistent_btree(DB, Table, StoreId, Col, File),
    findall(Rid,
            ( asadb_btree_file_candidate(File, Op, Value, Rid),
              asadb_record_read(StoreId, Rid, Row),
              row_matches(Row, Where)
            ),
            Rids).

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
    asadb_state(state(_, DBs)),
    (member(db(Name, Tables, Views, Functions, Procedures, Triggers), DBs) ->
        true
    ;
        member(db(Name, Tables), DBs),
        Views = [], Functions = [], Procedures = [], Triggers = []
    ), !.
get_db(Name, db(Name, [], [], [], [], [])).

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

storage_source_rows(DB, Table, Alias, Columns, Indexes,
                    paged_rows(StoreId, _, _), Where, Order, Limit, Rows) :-
    indexed_storage_order(Order, Indexes, Col, Direction), !,
    ensure_persistent_btree(DB, Table, StoreId, Col, File),
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
    indexed_column_predicate(Where, Indexes, Col, Op, Value), !,
    ensure_persistent_btree(DB, Table, StoreId, Col, File),
    note_plan(index_scan),
    asadb_btree_file_candidate(File, Op, Value, Rid),
    asadb_record_read(StoreId, Rid, Row).
storage_row_candidate(_, _, StoreId, _, _, Row) :-
    note_plan_once(sequential_scan),
    asadb_record_scan(StoreId, _, Row).

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
        ( asadb_record_scan(StoreId, Rid, Row),
          eval_expr(Row, col(Col), Key)
        ),
        _),
    note_plan(index_build),
    retractall(asadb_btree_cache(DB, Table, CacheCol, _)),
    assertz(asadb_btree_cache(DB, Table, CacheCol, persistent(File))).

storage_collect_rows(Generator, Row, Where, none, Limit, Rows) :- !,
    result_window(Limit, Offset, Count),
    Fetch is Offset + Count,
    findnsols(Fetch, Row, (call(Generator), row_matches(Row, Where)), Window),
    drop_n(Offset, Window, Rows).
storage_collect_rows(Generator, Row, Where, Order, Limit, Rows) :-
    result_window(Limit, Offset, Count),
    Keep is Offset + Count,
    Acc = top_rows_acc([], [], 0),
    forall((call(Generator), row_matches(Row, Where)),
           buffer_top_row(Acc, Order, Keep, Row)),
    flush_top_row_buffer(Acc, Order, Keep),
    arg(1, Acc, OrderedWindow),
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
    Buffer = [Row|Buffer0],
    Count is Count0 + 1,
    nb_setarg(2, Acc, Buffer),
    nb_setarg(3, Acc, Count),
    ( Count >= 256 -> flush_top_row_buffer(Acc, Order, Keep) ; true ).

flush_top_row_buffer(Acc, _, _) :-
    arg(3, Acc, 0), !.
flush_top_row_buffer(Acc, Order, Keep) :-
    arg(1, Acc, Top),
    arg(2, Acc, Buffer),
    reverse(Buffer, OrderedBuffer),
    append(Top, OrderedBuffer, Combined),
    apply_order(Order, Combined, Ordered),
    take_n(Keep, Ordered, Limited),
    nb_setarg(1, Acc, Limited),
    nb_setarg(2, Acc, []),
    nb_setarg(3, Acc, 0).

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
    forall(
        ( storage_row_candidate(DB, Table, StoreId, Indexes, Where, BaseRow),
          table_row_to_source_row(Table, Qualifiers, Columns, BaseRow, Row),
          row_matches(Row, Where)
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
column_option_sql(Options, 'PRIMARY KEY') :- member(primary_key, Options).
column_option_sql(Options, 'UNIQUE') :- member(unique, Options).
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
filter_rows(Where, Rows, Filtered) :- include_where(Rows, Where, Filtered).

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
eval_expr(Row, not(A), true) :- !, \+ eval_bool(Row, A).
eval_expr(Row, cmp(Op,A,B), true) :- !, eval_expr(Row, A, AV), eval_expr(Row, B, BV), compare_value(Op, AV, BV).
eval_expr(Row, is_null(A), true) :- !, eval_expr(Row, A, null).
eval_expr(Row, is_not_null(A), true) :- !, eval_expr(Row, A, V), V \== null.
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

apply_order(none, Rows, Rows) :- !.
apply_order(order([]), Rows, Rows) :- !.
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
contains_aggregate(not(A)) :- !, contains_aggregate(A).
contains_aggregate(cmp(_,A,B)) :- !, (contains_aggregate(A) ; contains_aggregate(B)).
contains_aggregate(is_null(A)) :- !, contains_aggregate(A).
contains_aggregate(is_not_null(A)) :- !, contains_aggregate(A).
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
    expr_label(Expr, Label),
    group_expr_projection_items(Exprs, Items).

columns_projection_items([], []).
columns_projection_items([Name|Names], [projection(Name, col(Name))|Items]) :-
    columns_projection_items(Names, Items).

build_groups(none, Rows, [group(all, Rows)]) :- !.
build_groups(group(_), [], []) :- !.
build_groups(group(Exprs), Rows, Groups) :-
    build_groups_(Rows, Exprs, [], Groups).

build_groups_([], _, Groups, Groups).
build_groups_([Row|Rows], Exprs, Acc, Groups) :-
    group_key(Exprs, Row, Key),
    add_row_to_group(Key, Row, Acc, Next),
    build_groups_(Rows, Exprs, Next, Groups).

group_key([], _, []).
group_key([Expr|Exprs], Row, [Value|Values]) :-
    eval_expr(Row, Expr, Value),
    group_key(Exprs, Row, Values).

add_row_to_group(Key, Row, [], [group(Key, [Row])]).
add_row_to_group(Key, Row, [group(Key, Rows)|Groups], [group(Key, [Row|Rows])|Groups]) :- !.
add_row_to_group(Key, Row, [Group|Groups], [Group|Out]) :-
    add_row_to_group(Key, Row, Groups, Out).

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
