% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  AsaDB production backup format.

  A v3 AsaDB catalog only contains paged-row references; the rows themselves
  live in the record store.  This module therefore walks the record store on
  the backend and writes a portable, self-verifying logical snapshot.  It is
  deliberately file based: a browser can download it through a native HTTP
  attachment without first materialising the database in JavaScript memory.

  The payload is ordinary AsaDB SQL and is preceded by a small manifest.  A
  SHA-256 covers the exact SQL payload and a second SHA-256 covers the
  database identity, catalog objects, counts, payload metadata, and payload
  together.  Restore verifies both before the web layer opens its normal
  transactional importer.
*/

:- module(asadb_backup, [
    asadb_backup_create/3,
    asadb_backup_prepare_restore/4,
    asadb_backup_validate_restored_snapshot/2,
    asadb_backup_file/1,
    asadb_backup_cleanup/1
]).

:- set_prolog_flag(double_quotes, string).

:- use_module(library(crypto)).
:- use_module(library(readutil)).
:- use_module('asadb_core.pl').
:- use_module('asadb_record_manager.pl').

backup_magic("-- ASADB-PRODUCTION-BACKUP 1").
payload_begin("-- ASADB-PAYLOAD-BEGIN").
payload_end("-- ASADB-PAYLOAD-END").

/* -------------------------------------------------------------------------
   Public API
   ------------------------------------------------------------------------- */

% Create a complete, immutable backup artifact for one user database.  The
% asadb_execution mutex is shared with the HTTP write/import paths, so the
% catalog and heap pages are observed as one logical snapshot.
asadb_backup_create(Database0, BackupFile, Manifest) :-
    backup_database_atom(Database0, Database),
    with_mutex(asadb_execution,
               asadb_backup_create_locked(Database, BackupFile, Manifest)).

asadb_backup_file(File) :-
    exists_file(File),
    setup_call_cleanup(
        open(File, read, In, [encoding(utf8)]),
        ( read_line_to_string(In, First), backup_magic(First) ),
        close(In)
    ).

% Verify a production artifact and extract the SQL payload into a private
% temporary file.  The caller owns the returned file and must clean it up.
asadb_backup_prepare_restore(File, Database, PayloadFile, Manifest) :-
    setup_call_cleanup(
        open(File, read, In, [encoding(utf8)]),
        backup_read_and_extract(In, Database, PayloadFile, Manifest),
        close(In)
    ).

asadb_backup_cleanup(File) :-
    ( nonvar(File), exists_file(File) -> catch(delete_file(File), _, true) ; true ).

% Before COMMIT, prove that the backend currently holds exactly the data the
% signed manifest promised.  This re-scans paged record stores rather than
% trusting their cached counts.
asadb_backup_validate_restored_snapshot(Database, Manifest) :-
    asadb_get_state(State),
    backup_database_from_state(State, Database, Db),
    backup_db_parts(Db, ActualDatabase, Tables, _, _, _, _),
    ( ActualDatabase == Database -> true
    ; throw(error(integrity_error(backup_database_identity(Database, ActualDatabase)), _))
    ),
    length(Tables, TableCount),
    ExpectedTableCount = Manifest.table_count,
    ( TableCount =:= ExpectedTableCount -> true
    ; throw(error(integrity_error(backup_table_count(ExpectedTableCount, TableCount)), _))
    ),
    backup_count_tables(Tables, 0, RowCount),
    ExpectedRowCount = Manifest.row_count,
    ( RowCount =:= ExpectedRowCount -> true
    ; throw(error(integrity_error(backup_total_row_count(ExpectedRowCount, RowCount)), _))
    ).

/* -------------------------------------------------------------------------
   Snapshot creation
   ------------------------------------------------------------------------- */

asadb_backup_create_locked(Database, BackupFile, Manifest) :-
    ( asadb_backup_transaction_active ->
        throw(error(permission_error(create, production_backup, active_transaction), _))
    ; true
    ),
    asadb_get_state(State),
    backup_database_from_state(State, Database, Db),
    backup_db_parts(Db, _Name, Tables, Views, Functions, Procedures, Triggers),
    temporary_backup_file(snapshot, BackupFile),
    atom_concat(BackupFile, '.payload', PayloadFile),
    asadb_backup_cleanup(PayloadFile),
    setup_call_cleanup(
        true,
        backup_create_envelope(Database, Tables, Views, Functions, Procedures, Triggers,
                               BackupFile, PayloadFile, Manifest),
        asadb_backup_cleanup(PayloadFile)
    ).

% A failed Prolog goal does not raise an exception.  Treat it as a failed
% backup as well, otherwise a caller could be left with an empty temporary
% artifact that looks like a completed download candidate.
backup_create_envelope(Database, Tables, Views, Functions, Procedures, Triggers,
                       BackupFile, PayloadFile, Manifest) :-
    ( catch(
          backup_create_envelope_or_fail(Database, Tables, Views, Functions,
                                         Procedures, Triggers, BackupFile,
                                         PayloadFile, Manifest),
          Error,
          ( asadb_backup_cleanup(BackupFile), throw(Error) )
      ) -> true
    ; asadb_backup_cleanup(BackupFile),
      throw(error(resource_error(production_backup_create_failed), _))
    ).

backup_create_envelope_or_fail(Database, Tables, Views, Functions, Procedures, Triggers,
                               BackupFile, PayloadFile, Manifest) :-
    setup_call_cleanup(
        open(PayloadFile, write, PayloadOut, [encoding(utf8)]),
        ( backup_write_payload(PayloadOut, Database, Tables, TableCount, RowCount),
          flush_output(PayloadOut)
        ),
        close(PayloadOut)
    ),
    size_file(PayloadFile, PayloadBytes),
    crypto_file_hash(PayloadFile, PayloadHash, [algorithm(sha256)]),
    CatalogObjects = catalog_objects(Views, Functions, Procedures, Triggers),
    backup_integrity_sha256(Database, CatalogObjects, PayloadHash,
                            PayloadBytes, TableCount, RowCount,
                            PayloadFile, IntegrityHash),
    backup_write_envelope(BackupFile, PayloadFile, Database, CatalogObjects,
                          PayloadHash, IntegrityHash, PayloadBytes,
                          TableCount, RowCount),
    Manifest = backup_manifest{
        format:'ASADB-PRODUCTION-BACKUP/1',
        database:Database,
        payload_sha256:PayloadHash,
        integrity_sha256:IntegrityHash,
        payload_bytes:PayloadBytes,
        table_count:TableCount,
        row_count:RowCount
    }.

temporary_backup_file(_Tag, File) :-
    tmp_file_stream(utf8, File, Out),
    close(Out).

backup_database_from_state(state(_, DBs), Database, Db) :-
    member(Db, DBs),
    backup_db_parts(Db, Name, _, _, _, _, _),
    backup_same_identifier(Name, Database),
    \+ backup_internal_database(Name), !.
backup_database_from_state(_, Database, _) :-
    throw(error(existence_error(database, Database), _)).

backup_internal_database(Name) :-
    atom(Name), sub_atom(Name, 0, 2, _, '__').

backup_db_parts(db(Name, Tables, Views, Functions, Procedures, Triggers),
                Name, Tables, Views, Functions, Procedures, Triggers) :- !.
backup_db_parts(db(Name, Tables), Name, Tables, [], [], [], []).

backup_table_parts(table(Name, Columns, Storage, Indexes), Name, Columns, Storage, Indexes) :- !.
backup_table_parts(table(Name, Columns, Storage), Name, Columns, Storage, []).

backup_write_payload(Out, Database, Tables, TableCount, RowCount) :-
    backup_sql_identifier(Database, QuotedDatabase),
    format(Out, 'DROP DATABASE IF EXISTS ~w;~n', [QuotedDatabase]),
    format(Out, 'CREATE DATABASE ~w;~n', [QuotedDatabase]),
    format(Out, 'USE ~w;~n~n', [QuotedDatabase]),
    backup_write_tables(Out, Tables, 0, TableCount, 0, RowCount).

backup_count_tables([], Count, Count).
backup_count_tables([Table|Tables], Count0, Count) :-
    backup_table_parts(Table, Name, _Columns, Storage, _Indexes),
    backup_count_storage_rows(Name, Storage, Rows),
    Count1 is Count0 + Rows,
    backup_count_tables(Tables, Count1, Count).

backup_count_storage_rows(Table, paged_rows(StoreId, Expected, _), Count) :- !,
    aggregate_all(count, asadb_record_scan(StoreId, _, _), Count),
    ( Count =:= Expected -> true
    ; throw(error(integrity_error(backup_restored_row_count(Table, Expected, Count)), _))
    ).
backup_count_storage_rows(_, Rows, Count) :- is_list(Rows), !, length(Rows, Count).
backup_count_storage_rows(Table, Storage, _) :-
    throw(error(domain_error(backup_row_storage(Table), Storage), _)).

backup_write_tables(_, [], TableCount, TableCount, RowCount, RowCount).
backup_write_tables(Out, [Table|Tables], TableCount0, TableCount,
                    RowCount0, RowCount) :-
    backup_write_table(Out, Table, Rows),
    TableCount1 is TableCount0 + 1,
    RowCount1 is RowCount0 + Rows,
    backup_write_tables(Out, Tables, TableCount1, TableCount, RowCount1, RowCount).

backup_write_table(Out, Table, RowCount) :-
    backup_table_parts(Table, Name, Columns, Storage, Indexes),
    backup_write_create_table(Out, Name, Columns),
    backup_write_storage_rows(Out, Name, Columns, Storage, RowCount),
    backup_write_indexes(Out, Name, Indexes),
    nl(Out).

backup_write_create_table(Out, Name, Columns) :-
    maplist(backup_column_sql, Columns, Definitions),
    atomic_list_concat(Definitions, ',\n  ', DefinitionsText),
    backup_sql_identifier(Name, QuotedName),
    format(Out, 'CREATE TABLE ~w (\n  ~w\n);~n',
           [QuotedName, DefinitionsText]).

backup_column_sql(col(Name, Type, Options), SQL) :- !,
    backup_sql_identifier(Name, Identifier),
    backup_sql_type(Type, TypeSQL),
    backup_column_options_sql(Options, OptionsSQL),
    atomic_list_concat([Identifier, ' ', TypeSQL, OptionsSQL], SQL).
backup_column_sql(Column, _) :-
    throw(error(domain_error(backup_column, Column), _)).

backup_sql_type(Type, SQL) :-
    ( atom(Type) -> Atom = Type
    ; string(Type) -> atom_string(Atom, Type)
    ; throw(error(domain_error(backup_column_type, Type), _))
    ),
    atom_codes(Atom, RawCodes),
    backup_trim_type_space(RawCodes, Codes),
    ( Codes \= [], maplist(backup_type_code, Codes) -> atom_codes(SQL, Codes)
    ; throw(error(domain_error(backup_column_type, Type), _))
    ).

backup_trim_type_space(Codes0, Codes) :-
    backup_drop_leading_type_space(Codes0, LeadingTrimmed),
    reverse(LeadingTrimmed, Reversed),
    backup_drop_leading_type_space(Reversed, TrailingTrimmed),
    reverse(TrailingTrimmed, Codes).

backup_drop_leading_type_space([32|Codes], Trimmed) :- !,
    backup_drop_leading_type_space(Codes, Trimmed).
backup_drop_leading_type_space(Codes, Codes).

backup_type_code(Code) :-
    ( Code >= 65, Code =< 90
    ; Code >= 97, Code =< 122
    ; Code >= 48, Code =< 57
    ; memberchk(Code, [32,40,41,44,95])
    ).

backup_column_options_sql([], '').
backup_column_options_sql([Option|Options], SQL) :-
    backup_column_option_sql(Option, Head),
    backup_column_options_sql(Options, Tail),
    atom_concat(Head, Tail, SQL).

backup_column_option_sql(not_null, ' NOT NULL') :- !.
backup_column_option_sql(nullable, ' NULL') :- !.
backup_column_option_sql(primary_key, ' PRIMARY KEY') :- !.
backup_column_option_sql(auto_increment, ' AUTO_INCREMENT') :- !.
backup_column_option_sql(unique, ' UNIQUE') :- !.
backup_column_option_sql(default(Value), SQL) :- !,
    backup_sql_value(Value, Literal),
    atomic_list_concat([' DEFAULT ', Literal], SQL).
backup_column_option_sql(raw_option(Token), SQL) :- !,
    backup_raw_option_token_sql(Token, TokenSQL),
    atom_concat(' ', TokenSQL, SQL).
backup_column_option_sql(Option, _) :-
    % Never silently discard unsupported schema state in a production backup.
    throw(error(domain_error(backup_column_option, Option), _)).

% The parser retains accepted-but-not-semantic column syntax (for example
% COMMENT text) as raw tokens.  Re-emit those tokens instead of discarding
% schema detail during a production backup.
backup_raw_option_token_sql(kw(Name), SQL) :- !,
    backup_raw_keyword_atom(Name, SQL).
backup_raw_option_token_sql(id(Name), SQL) :- !,
    backup_sql_identifier(Name, SQL).
backup_raw_option_token_sql(str(Value), SQL) :- !,
    backup_sql_value(Value, SQL).
backup_raw_option_token_sql(num(Value), SQL) :- !,
    backup_sql_value(Value, SQL).
backup_raw_option_token_sql(sym(Symbol), SQL) :- !,
    backup_raw_symbol_atom(Symbol, SQL).
backup_raw_option_token_sql(op(Operator), SQL) :- !,
    backup_raw_symbol_atom(Operator, SQL).
backup_raw_option_token_sql(char(Code), SQL) :- !,
    backup_raw_character_atom(Code, SQL).
backup_raw_option_token_sql(Token, _) :-
    throw(error(domain_error(backup_raw_column_option, Token), _)).

backup_raw_keyword_atom(Name, Name) :-
    atom(Name), atom_codes(Name, Codes), Codes \= [],
    maplist(backup_raw_keyword_code, Codes), !.
backup_raw_keyword_atom(Name, _) :- throw(error(domain_error(backup_raw_keyword, Name), _)).

backup_raw_keyword_code(Code) :-
    ( Code >= 65, Code =< 90
    ; Code >= 97, Code =< 122
    ; Code >= 48, Code =< 57
    ; Code =:= 95
    ).

backup_raw_symbol_atom(Symbol, Symbol) :-
    atom(Symbol), atom_codes(Symbol, Codes), Codes \= [],
    maplist(backup_raw_symbol_code, Codes), !.
backup_raw_symbol_atom(Symbol, _) :- throw(error(domain_error(backup_raw_symbol, Symbol), _)).

backup_raw_symbol_code(Code) :- memberchk(Code, [40,41,44,43,45,42,47,37,61,60,62,33,46]).

backup_raw_character_atom(Code, Atom) :-
    integer(Code), backup_raw_symbol_code(Code), !,
    atom_codes(Atom, [Code]).
backup_raw_character_atom(Code, _) :- throw(error(domain_error(backup_raw_character, Code), _)).

backup_write_storage_rows(Out, Table, Columns, paged_rows(StoreId, Expected, _), Count) :- !,
    % Verify the physical record-store cardinality before streaming.  Do not
    % use a mutable counter inside forall/2: that is vulnerable to Prolog
    % backtracking semantics and previously produced unstable totals.
    aggregate_all(count, asadb_record_scan(StoreId, _, _), Actual),
    ( Actual =:= Expected -> true
    ; throw(error(integrity_error(backup_row_count(Table, Expected, Actual)), _))
    ),
    forall(asadb_record_scan(StoreId, _, Row),
           backup_write_insert(Out, Table, Columns, Row)),
    Count = Expected.
backup_write_storage_rows(Out, Table, Columns, Rows, Count) :-
    is_list(Rows), !,
    backup_write_inline_rows(Out, Table, Columns, Rows, 0, Count).
backup_write_storage_rows(_, Table, _, Storage, _) :-
    throw(error(domain_error(backup_row_storage(Table), Storage), _)).

backup_write_inline_rows(_, _, _, [], Count, Count).
backup_write_inline_rows(Out, Table, Columns, [Row|Rows], Count0, Count) :-
    backup_write_insert(Out, Table, Columns, Row),
    Count1 is Count0 + 1,
    backup_write_inline_rows(Out, Table, Columns, Rows, Count1, Count).

backup_write_insert(Out, Table, Columns, row(Pairs)) :- !,
    maplist(backup_column_name, Columns, Names),
    maplist(backup_row_value(Pairs), Names, Values),
    maplist(backup_sql_identifier, Names, Identifiers),
    maplist(backup_sql_value, Values, Literals),
    atomic_list_concat(Identifiers, ', ', IdentifierText),
    atomic_list_concat(Literals, ', ', LiteralText),
    backup_sql_identifier(Table, QuotedTable),
    format(Out, 'INSERT INTO ~w (~w) VALUES (~w);~n',
           [QuotedTable, IdentifierText, LiteralText]).
backup_write_insert(_, Table, _, Row) :-
    throw(error(domain_error(backup_row(Table), Row), _)).

backup_column_name(col(Name, _, _), Name).

backup_row_value([Name=Value|_], Wanted, Value) :- backup_same_identifier(Name, Wanted), !.
backup_row_value([_|Pairs], Wanted, Value) :- backup_row_value(Pairs, Wanted, Value).
backup_row_value([], _Wanted, null).

backup_write_indexes(_, _, []).
backup_write_indexes(Out, Table, [index(Name, Columns, Unique)|Indexes]) :- !,
    ( backup_primary_index(Name) -> true
    ; maplist(backup_sql_identifier, Columns, Identifiers),
      atomic_list_concat(Identifiers, ', ', ColumnText),
      backup_index_keyword(Unique, UniqueKeyword),
      backup_sql_identifier(Name, QuotedName),
      backup_sql_identifier(Table, QuotedTable),
      format(Out, 'CREATE ~wINDEX ~w ON ~w (~w);~n',
             [UniqueKeyword, QuotedName, QuotedTable, ColumnText])
    ),
    backup_write_indexes(Out, Table, Indexes).
backup_write_indexes(_, Table, [Index|_]) :-
    throw(error(domain_error(backup_index(Table), Index), _)).

backup_primary_index(Name) :- backup_same_identifier(Name, 'PRIMARY').

backup_index_keyword(unique, 'UNIQUE ') :- !.
backup_index_keyword(true, 'UNIQUE ') :- !.
backup_index_keyword(_, '').

backup_sql_identifier(Name, SQL) :-
    backup_identifier_atom(Name, Atom),
    atom_codes(Atom, Codes),
    ( memberchk(96, Codes) -> throw(error(domain_error(backup_identifier, Name), _)) ; true ),
    append(Codes, [96], WithEnd),
    atom_codes(SQL, [96|WithEnd]).

backup_identifier_atom(Name, Atom) :- atom(Name), !, Atom = Name.
backup_identifier_atom(Name, Atom) :- string(Name), !, atom_string(Atom, Name).
backup_identifier_atom(Name, _) :- throw(error(domain_error(backup_identifier, Name), _)).

backup_sql_value(null, 'NULL') :- !.
backup_sql_value(Value, SQL) :- integer(Value), !,
    format(atom(SQL), '~d', [Value]).
backup_sql_value(Value, SQL) :- float(Value), !,
    backup_finite_float(Value),
    % number_codes/2 emits a decimal representation that SWI-Prolog reads
    % back to the same float, including exponent notation and negative zero.
    number_codes(Value, Codes),
    atom_codes(SQL, Codes).
backup_sql_value(Value, SQL) :- atom(Value), !,
    atom_codes(Value, Codes),
    backup_quoted_codes(Codes, Quoted),
    atom_codes(SQL, Quoted).
backup_sql_value(Value, SQL) :- string(Value), !,
    string_codes(Value, Codes),
    backup_quoted_codes(Codes, Quoted),
    atom_codes(SQL, Quoted).
backup_sql_value(Value, _) :-
    throw(error(domain_error(backup_scalar_value, Value), _)).

backup_finite_float(Value) :-
    float_class(Value, Class),
    memberchk(Class, [normal, subnormal, zero]), !.
backup_finite_float(Value) :-
    throw(error(domain_error(backup_finite_float, Value), _)).

backup_quoted_codes(Codes, Quoted) :-
    backup_escape_string_codes(Codes, Escaped),
    append([39|Escaped], [39], Quoted).

backup_escape_string_codes([], []).
backup_escape_string_codes([92|Codes], [92,92|Escaped]) :- !,
    backup_escape_string_codes(Codes, Escaped).
backup_escape_string_codes([39|Codes], [92,39|Escaped]) :- !,
    backup_escape_string_codes(Codes, Escaped).
backup_escape_string_codes([10|Codes], [92,110|Escaped]) :- !,
    backup_escape_string_codes(Codes, Escaped).
backup_escape_string_codes([13|Codes], [92,114|Escaped]) :- !,
    backup_escape_string_codes(Codes, Escaped).
backup_escape_string_codes([9|Codes], [92,116|Escaped]) :- !,
    backup_escape_string_codes(Codes, Escaped).
backup_escape_string_codes([Code|Codes], [Code|Escaped]) :-
    backup_escape_string_codes(Codes, Escaped).

backup_write_envelope(BackupFile, PayloadFile, Database, CatalogObjects,
                      PayloadHash, IntegrityHash, PayloadBytes, TableCount, RowCount) :-
    setup_call_cleanup(
        open(BackupFile, write, Out, [encoding(utf8)]),
        ( backup_write_header(Out, Database, CatalogObjects, PayloadHash,
                              IntegrityHash, PayloadBytes, TableCount, RowCount),
          % Both streams are UTF-8 text streams.  Copying raw UTF-8 bytes to
          % a text stream would encode non-ASCII bytes a second time.
          setup_call_cleanup(open(PayloadFile, read, In, [encoding(utf8)]),
                             copy_stream_data(In, Out),
                             close(In)),
          payload_end(End), format(Out, '~s~n', [End])
        ),
        close(Out)
    ).

backup_write_header(Out, Database, CatalogObjects, PayloadHash, IntegrityHash,
                    PayloadBytes, TableCount, RowCount) :-
    backup_canonical_atom(Database, DatabaseAtom),
    backup_canonical_atom(CatalogObjects, CatalogAtom),
    backup_validate_catalog_header_size(CatalogAtom),
    backup_magic(Magic), payload_begin(Begin),
    format(Out, '~s~n', [Magic]),
    format(Out, '-- database: ~w~n', [DatabaseAtom]),
    format(Out, '-- payload-sha256: ~w~n', [PayloadHash]),
    format(Out, '-- integrity-sha256: ~w~n', [IntegrityHash]),
    format(Out, '-- payload-bytes: ~d~n', [PayloadBytes]),
    format(Out, '-- table-count: ~d~n', [TableCount]),
    format(Out, '-- row-count: ~d~n', [RowCount]),
    format(Out, '-- catalog-objects: ~w~n', [CatalogAtom]),
    format(Out, '~s~n', [Begin]).

backup_canonical_atom(Term, Atom) :-
    with_output_to(atom(Atom), write_canonical(Term)).

% The payload checksum catches a damaged SQL stream.  The integrity checksum
% additionally binds the header fields that direct restore, especially the
% database identifier and catalog-only objects which intentionally do not go
% through the SQL parser.
backup_integrity_sha256(Database, CatalogObjects, PayloadHash,
                        PayloadBytes, TableCount, RowCount, PayloadFile, Hash) :-
    backup_integrity_metadata_atom(Database, CatalogObjects, PayloadHash,
                                   PayloadBytes, TableCount, RowCount, Metadata),
    backup_utf8_atom_bytes(Metadata, MetadataBytes),
    crypto_context_new(Context0, [algorithm(sha256)]),
    crypto_data_context(MetadataBytes, Context0, Context1),
    setup_call_cleanup(
        open(PayloadFile, read, In, [type(binary)]),
        backup_hash_binary_stream(In, Context1, Context),
        close(In)
    ),
    crypto_context_hash(Context, Hash).

backup_integrity_metadata_atom(Database, CatalogObjects, PayloadHash,
                              PayloadBytes, TableCount, RowCount, Metadata) :-
    backup_canonical_atom(Database, DatabaseAtom),
    backup_canonical_atom(CatalogObjects, CatalogAtom),
    format(atom(Metadata),
           'asadb-production-backup-integrity-v1~ndatabase=~w~ncatalog-objects=~w~npayload-sha256=~w~npayload-bytes=~d~ntable-count=~d~nrow-count=~d~n',
           [DatabaseAtom, CatalogAtom, PayloadHash, PayloadBytes, TableCount, RowCount]).

% Hash the metadata as actual UTF-8 bytes, then feed the existing payload
% bytes in fixed-size chunks.  Keeping the hash incremental avoids a second
% full-sized temporary copy of a large production backup.
backup_utf8_atom_bytes(Atom, Bytes) :-
    atom_codes(Atom, Codes),
    backup_utf8_codes(Codes, Bytes).

backup_utf8_codes([], []).
backup_utf8_codes([Code|Codes], Bytes) :-
    backup_utf8_code_bytes(Code, Head),
    backup_utf8_codes(Codes, Tail),
    append(Head, Tail, Bytes).

backup_utf8_code_bytes(Code, [Code]) :- Code >= 0, Code =< 127, !.
backup_utf8_code_bytes(Code, [A, B]) :-
    Code =< 2047, !,
    A is 192 \/ (Code >> 6),
    B is 128 \/ (Code /\ 63).
backup_utf8_code_bytes(Code, [A, B, C]) :-
    Code =< 65535, !,
    A is 224 \/ (Code >> 12),
    B is 128 \/ ((Code >> 6) /\ 63),
    C is 128 \/ (Code /\ 63).
backup_utf8_code_bytes(Code, [A, B, C, D]) :-
    Code =< 1114111, !,
    A is 240 \/ (Code >> 18),
    B is 128 \/ ((Code >> 12) /\ 63),
    C is 128 \/ ((Code >> 6) /\ 63),
    D is 128 \/ (Code /\ 63).
backup_utf8_code_bytes(Code, _) :- throw(error(domain_error(unicode_code_point, Code), _)).

backup_hash_binary_stream(In, Context0, Context) :-
    read_string(In, 65536, Chunk),
    ( Chunk == "" -> Context = Context0
    ; string_codes(Chunk, Bytes),
      crypto_data_context(Bytes, Context0, Context1),
      backup_hash_binary_stream(In, Context1, Context)
    ).

/* -------------------------------------------------------------------------
   Restore verification
   ------------------------------------------------------------------------- */

backup_read_and_extract(In, Database, PayloadFile, Manifest) :-
    read_line_to_string(In, First),
    backup_magic(First), !,
    backup_read_header(In, Header),
    backup_header_manifest(Header, Database, CatalogObjects, Manifest0),
    temporary_backup_file(restore_payload, PayloadFile),
    catch(
        ( setup_call_cleanup(
              open(PayloadFile, write, Out, [encoding(utf8)]),
              ( backup_copy_payload(In, Out), flush_output(Out) ),
              close(Out)
          ),
          backup_verify_payload(PayloadFile, Manifest0),
          backup_verify_integrity(Database, CatalogObjects, PayloadFile, Manifest0),
          backup_verify_payload_identity(PayloadFile, Database),
          Manifest = Manifest0.put(catalog_objects, CatalogObjects)
        ),
        Error,
        ( asadb_backup_cleanup(PayloadFile), throw(Error) )
    ).
backup_read_and_extract(_, _, _, _) :-
    throw(error(syntax_error(not_asadb_production_backup), _)).

backup_max_header_lines(16).
% Catalog-only objects are canonicalized into one signed header line.  Keep a
% generous, symmetric bound on writer and reader so a valid locally-created
% backup is never rejected on restore, while a hostile upload cannot request
% unbounded header allocation.
backup_max_header_line_chars(67108864).

backup_validate_catalog_header_size(CatalogAtom) :-
    atom_length(CatalogAtom, Length),
    backup_max_header_line_chars(MaxLength),
    ( Length =< MaxLength -> true
    ; throw(error(resource_error(backup_catalog_metadata_too_large), _))
    ).

backup_read_header(In, Header) :-
    backup_read_header(In, 0, [], Header).

backup_read_header(In, Lines0, Seen, Header) :-
    read_line_to_string(In, Line),
    ( Line == end_of_file -> throw(error(syntax_error(backup_header_truncated), _))
    ; string_length(Line, Length),
      backup_max_header_line_chars(MaxLength),
      ( Length =< MaxLength -> true
      ; throw(error(resource_error(backup_header_line_too_large), _))
      ),
      payload_begin(Begin), Line == Begin -> Header = []
    ; backup_max_header_lines(MaxLines),
      ( Lines0 < MaxLines -> true
      ; throw(error(resource_error(backup_header_too_large), _))
      ),
      backup_header_line(Line, Key, Value),
      ( memberchk(Key, Seen) -> throw(error(syntax_error(backup_header_duplicate(Key)), _)) ; true ),
      Lines1 is Lines0 + 1,
      backup_read_header(In, Lines1, [Key|Seen], Rest),
      Header = [Key-Value|Rest]
    ).

backup_header_line(Line, Key, Value) :-
    string_concat("-- ", Body, Line),
    sub_string(Body, Before, 2, After, ': '),
    sub_string(Body, 0, Before, _, KeyString),
    Start is Before + 2,
    sub_string(Body, Start, After, 0, ValueString),
    atom_string(Key, KeyString),
    atom_string(Value, ValueString),
    memberchk(Key, [database,'payload-sha256','integrity-sha256','payload-bytes',
                    'table-count','row-count','catalog-objects']).

backup_header_manifest(Header, Database, CatalogObjects, Manifest) :-
    backup_header_required(Header, database, DatabaseAtom),
    backup_header_required(Header, 'payload-sha256', Hash),
    backup_header_required(Header, 'integrity-sha256', IntegrityHash),
    backup_header_number(Header, 'payload-bytes', PayloadBytes),
    backup_header_number(Header, 'table-count', TableCount),
    backup_header_number(Header, 'row-count', RowCount),
    backup_header_required(Header, 'catalog-objects', CatalogAtom),
    backup_read_canonical(DatabaseAtom, Database),
    backup_database_atom(Database, Database),
    backup_read_canonical(CatalogAtom, CatalogObjects),
    backup_valid_catalog_objects(CatalogObjects),
    backup_sha256_atom(Hash),
    backup_sha256_atom(IntegrityHash),
    PayloadBytes >= 0, TableCount >= 0, RowCount >= 0,
    Manifest = backup_manifest{
        format:'ASADB-PRODUCTION-BACKUP/1',
        database:Database,
        payload_sha256:Hash,
        integrity_sha256:IntegrityHash,
        payload_bytes:PayloadBytes,
        table_count:TableCount,
        row_count:RowCount
    }.

backup_header_required(Header, Key, Value) :-
    memberchk(Key-Value, Header), !.
backup_header_required(_, Key, _) :- throw(error(syntax_error(backup_header_missing(Key)), _)).

backup_sha256_atom(Hash) :-
    atom_length(Hash, 64),
    atom_codes(Hash, Codes),
    maplist(backup_hex_code, Codes), !.
backup_sha256_atom(_) :- throw(error(syntax_error(backup_header_sha256), _)).

backup_hex_code(Code) :-
    ( Code >= 48, Code =< 57
    ; Code >= 65, Code =< 70
    ; Code >= 97, Code =< 102
    ).

backup_header_number(Header, Key, Number) :-
    backup_header_required(Header, Key, Atom),
    catch(atom_number(Atom, Number), _, fail), integer(Number), !.
backup_header_number(_, Key, _) :- throw(error(syntax_error(backup_header_number(Key)), _)).

backup_read_canonical(Atom, Term) :-
    catch(read_term_from_atom(Atom, Term, [syntax_errors(error)]), _, fail),
    ground(Term), !.
backup_read_canonical(_, _) :- throw(error(syntax_error(backup_header_term), _)).

backup_valid_catalog_objects(catalog_objects(Views, Functions, Procedures, Triggers)) :-
    is_list(Views), is_list(Functions), is_list(Procedures), is_list(Triggers),
    maplist(backup_valid_view, Views),
    maplist(backup_valid_function, Functions),
    maplist(backup_valid_procedure, Procedures),
    maplist(backup_valid_trigger, Triggers), !.
backup_valid_catalog_objects(_) :- throw(error(syntax_error(backup_catalog_objects), _)).

backup_valid_view(view(Name, _Select, _Time)) :- backup_identifier_atom(Name, _), !.
backup_valid_function(function(Name, _Params, _Type, _Body, _Time)) :- backup_identifier_atom(Name, _), !.
backup_valid_procedure(procedure(Name, _Params, _Body, _Time)) :- backup_identifier_atom(Name, _), !.
backup_valid_trigger(trigger(Name, _Event, _Timing, Table, _Body, _Time)) :-
    backup_identifier_atom(Name, _), backup_identifier_atom(Table, _), !.

backup_copy_payload(In, Out) :-
    read_line_to_string(In, Line),
    ( Line == end_of_file -> throw(error(syntax_error(backup_payload_truncated), _))
    ; payload_end(End), Line == End -> backup_require_no_trailing_content(In)
    ; format(Out, '~s~n', [Line]),
      backup_copy_payload(In, Out)
    ).

backup_verify_payload(PayloadFile, Manifest) :-
    size_file(PayloadFile, Bytes),
    ExpectedBytes = Manifest.payload_bytes,
    ( Bytes =:= ExpectedBytes -> true
    ; throw(error(integrity_error(backup_payload_bytes(ExpectedBytes, Bytes)), _))
    ),
    crypto_file_hash(PayloadFile, ActualHash, [algorithm(sha256)]),
    ExpectedHash = Manifest.payload_sha256,
    ( ActualHash == ExpectedHash -> true
    ; throw(error(integrity_error(backup_payload_sha256(ExpectedHash, ActualHash)), _))
    ).

backup_verify_integrity(Database, CatalogObjects, PayloadFile, Manifest) :-
    backup_integrity_sha256(Database, CatalogObjects, Manifest.payload_sha256,
                            Manifest.payload_bytes, Manifest.table_count,
                            Manifest.row_count, PayloadFile, ActualHash),
    ExpectedHash = Manifest.integrity_sha256,
    ( ActualHash == ExpectedHash -> true
    ; throw(error(integrity_error(backup_integrity_sha256(ExpectedHash, ActualHash)), _))
    ).

% The manifest identity is used to restore catalog-only objects.  Require the
% generated SQL prologue to target exactly that same database before any SQL
% is handed to the streaming importer.
backup_verify_payload_identity(PayloadFile, Database) :-
    backup_sql_identifier(Database, QuotedDatabase),
    format(atom(DropExpected), 'DROP DATABASE IF EXISTS ~w;', [QuotedDatabase]),
    format(atom(CreateExpected), 'CREATE DATABASE ~w;', [QuotedDatabase]),
    format(atom(UseExpected), 'USE ~w;', [QuotedDatabase]),
    setup_call_cleanup(
        open(PayloadFile, read, In, [encoding(utf8)]),
        ( read_line_to_string(In, Drop),
          read_line_to_string(In, Create),
          read_line_to_string(In, Use),
          atom_string(DropExpected, Drop),
          atom_string(CreateExpected, Create),
          atom_string(UseExpected, Use)
        ),
        close(In)
    ), !.
backup_verify_payload_identity(_, Database) :-
    throw(error(integrity_error(backup_payload_database_identity(Database)), _)).

backup_require_no_trailing_content(In) :-
    read_string(In, 65536, Trailing),
    ( Trailing == "" -> true
    ; string_codes(Trailing, Codes),
      ( maplist(backup_whitespace_code, Codes) -> backup_require_no_trailing_content(In)
      ; throw(error(syntax_error(backup_trailing_content), _))
      )
    ).

backup_whitespace_code(9).
backup_whitespace_code(10).
backup_whitespace_code(13).
backup_whitespace_code(32).

backup_database_atom(Database, Database) :-
    atom(Database), Database \= '',
    \+ backup_internal_database(Database), !.
backup_database_atom(Database, _) :-
    throw(error(domain_error(backup_database, Database), _)).

backup_same_identifier(A, B) :- A == B, !.
backup_same_identifier(A, B) :-
    atom(A), atom(B), downcase_atom(A, LowerA), downcase_atom(B, LowerB), LowerA == LowerB.
