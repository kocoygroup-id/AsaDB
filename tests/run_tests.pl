% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- use_module('../src/asadb_core.pl').
:- use_module('../src/asadb_mysql55_compat.pl').
:- use_module(library(filesex)).
:- initialization(main, main).

main :-
    run_sql_file('tests/smoke.sql'),
    run_sql_file('tests/production_foundation.sql'),
    run_sql_file('tests/alter_table_comprehensive.sql'),
    run_sql_file('tests/critical_select_features.sql'),
    run_persistence_assertions,
    run_metadata_persistence_assertions,
    run_alter_order_assertions,
    run_auto_increment_assertions,
    run_order_by_duplicate_assertions,
    run_order_by_wildcard_assertions,
    run_delete_where_safety_assertions,
    run_duplicate_column_assertions,
    run_bare_identifier_insert_assertions,
    run_wal_recovery_assertions,
    run_read_only_no_autosave_assertions,
    run_limited_result_assertions,
    run_storage_engine_assertions,
    run_drop_table_cleanup_assertions,
    run_catalog_multitable_assertions,
    run_critical_select_assertions,
    run_mysql55_manifest_assertions,
    cleanup,
    halt(0).

run_sql_file(File) :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    read_file_to_codes(File, Codes, []),
    asadb_exec_sql(Codes, Result),
    asadb_format_result(Result),
    ( result_has_error(Result) ->
        asadb_shutdown,
        cleanup,
        halt(1)
    ; asadb_shutdown
    ).

result_has_error(error(_, _)).
result_has_error(multi(Results)) :- member(error(_, _), Results).

run_persistence_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    asadb_exec_sql('CREATE DATABASE keepdb; USE keepdb; CREATE TABLE kept (id INT); ALTER TABLE kept ADD COLUMN note TEXT;', SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_shutdown,
    asadb_boot('tests/testdata.asa'),
    ( asadb_current_database(keepdb) ->
        true
    ;   format('ASSERTION FAILED: persisted database was not restored.~n', []),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    expect_sql('SELECT * FROM kept;',
               table([id,note], [])),
    asadb_shutdown,
    cleanup.

run_metadata_persistence_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    asadb_exec_sql('CREATE DATABASE metadata_assert; USE metadata_assert; CREATE TABLE items (id INT); INSERT INTO items VALUES (1), (2), (3);', SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_database_metadata(Before),
    DatabaseId = Before.database_id,
    ( Before.engine_version == '1.4.0',
      Before.storage_format =:= 3,
      Before.summary.row_count =:= 3 ->
        true
    ;   format('ASSERTION FAILED: live database metadata is invalid: ~w.~n', [Before]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_shutdown,
    asadb_boot('tests/testdata.asa'),
    asadb_database_metadata(After),
    ( After.database_id == DatabaseId,
      After.summary.current_database == metadata_assert,
      After.summary.row_count =:= 3,
      After.checkpoint_count >= Before.checkpoint_count ->
        true
    ;   format('ASSERTION FAILED: database metadata did not survive restart: before=~w after=~w.~n', [Before,After]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_shutdown,
    cleanup.

run_alter_order_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE alter_order_assert; USE alter_order_assert; CREATE TABLE Coba (ID INT, Nama TEXT, Tanggal_Masuk DATE); ALTER TABLE Coba ADD COLUMN Tugas INTEGER;',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT * FROM Coba;',
               table(['ID','Nama','Tanggal_Masuk','Tugas'], [])),
    asadb_shutdown,
    cleanup.

run_auto_increment_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE ai_assert; USE ai_assert; CREATE TABLE people (id INT PRIMARY KEY AUTO_INCREMENT, name TEXT); INSERT INTO people (name) VALUES (''A''), (''B''); INSERT INTO people (id, name) VALUES (NULL, ''C''), (10, ''D''); INSERT INTO people (name) VALUES (''E''); INSERT INTO people VALUES (NULL, ''F'');',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT id, name FROM people ORDER BY id;',
               table([id,name], [[1,'A'],[2,'B'],[3,'C'],[10,'D'],[11,'E'],[12,'F']])),
    asadb_shutdown,
    cleanup.

run_order_by_duplicate_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE order_assert; USE order_assert; CREATE TABLE Coba (ID INT, Nama TEXT, Gaji INT); INSERT INTO Coba (ID, Nama, Gaji) VALUES (1, ''Aires'', 100), (2, ''Budi'', 100), (3, ''Cici'', 100), (4, ''Dodi'', 20);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT ID, Nama, Gaji FROM Coba WHERE Gaji > 90 ORDER BY Gaji;',
               table(['ID','Nama','Gaji'], [[1,'Aires',100],[2,'Budi',100],[3,'Cici',100]])),
    asadb_exec_sql('CREATE TABLE TextNums (ID INT, Gaji TEXT); INSERT INTO TextNums (ID, Gaji) VALUES (1, ''100''), (2, ''20''), (3, ''90'');', TextSetupResult),
    ( result_has_error(TextSetupResult) ->
        asadb_format_result(TextSetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT ID, Gaji FROM TextNums WHERE Gaji > 50 ORDER BY Gaji;',
               table(['ID','Gaji'], [[3,'90'],[1,'100']])),
    asadb_shutdown,
    cleanup.

run_order_by_wildcard_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE wildcard_order_assert; USE wildcard_order_assert; CREATE TABLE Double_Company (id INT, sales_yen INT); INSERT INTO Double_Company VALUES (3, 120), (1, 90), (2, 110);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    % AsaDB has historically accepted ORDER BY *.  It cannot order rows by a
    % wildcard scalar, so it must preserve scan order without invoking a sort.
    expect_sql('SELECT * FROM Double_Company WHERE sales_yen < 32007290 ORDER BY *;',
               table([id,sales_yen], [[3,120],[1,90],[2,110]])),
    asadb_analyze_sql('SELECT * FROM Double_Company WHERE sales_yen < 32007290 ORDER BY *;', diagnostics(Diagnostics)),
    ( Diagnostics == [] ->
        true
    ;   format('ASSERTION FAILED: a terminated ORDER BY * query has diagnostics: ~w.~n', [Diagnostics]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_shutdown,
    cleanup.

run_delete_where_safety_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE delete_assert; USE delete_assert; CREATE TABLE KIPASANGIN (ID INT, Nama TEXT); INSERT INTO KIPASANGIN (ID, Nama) VALUES (1, ''A''), (2, ''B''), (3, ''C''), (4, ''D'');',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('DELETE FROM KIPASANGIN WHERE ID = 3;',
               ok(deleted(KIPASANGIN, 1))),
    expect_sql('SELECT * FROM KIPASANGIN;',
               table(['ID','Nama'], [[1,'A'],[2,'B'],[4,'D']])),
    expect_sql('DELETE FROM KIPASANGIN WHERE ID = 999;',
               ok(deleted(KIPASANGIN, 0))),
    expect_sql('SELECT * FROM KIPASANGIN;',
               table(['ID','Nama'], [[1,'A'],[2,'B'],[4,'D']])),
    asadb_shutdown,
    cleanup.

run_duplicate_column_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE dup_col_assert; USE dup_col_assert; CREATE TABLE t (id INT, nama TEXT); ALTER TABLE t ADD COLUMN nama TEXT; ALTER TABLE t ADD COLUMN Nama TEXT; INSERT INTO t VALUES (1, ''A'', ''B'', ''C'');',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT * FROM t;',
               table([id,nama], [[1,'A']])),
    expect_sql('ALTER TABLE t DROP COLUMN Nama;',
               ok(altered_table(t))),
    expect_sql('SELECT * FROM t;',
               table([id], [[1]])),
    asadb_shutdown,
    cleanup.

run_bare_identifier_insert_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE bare_insert_assert; USE bare_insert_assert; CREATE TABLE p (id INT PRIMARY KEY AUTO_INCREMENT, nama TEXT, tanggal_masuk DATE, tugas_selesai INT); INSERT INTO p (nama, tanggal_masuk, tugas_selesai) VALUES (Hayakawa Aki, ''2005-10-14'', 650), (Mitaka Asa, ''2007-10-14'', 650), (Denji, ''2006-10-14'', 650), (Kishibe, ''1999-10-14'', 650);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT * FROM p;',
               table([id,nama,tanggal_masuk,tugas_selesai],
                     [[1,'Hayakawa Aki','2005-10-14',650],
                      [2,'Mitaka Asa','2007-10-14',650],
                      [3,'Denji','2006-10-14',650],
                      [4,'Kishibe','1999-10-14',650]])),
    asadb_shutdown,
    cleanup.

run_read_only_no_autosave_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    asadb_exec_sql('CREATE DATABASE readonly_assert; USE readonly_assert; CREATE TABLE t (id INT); INSERT INTO t VALUES (1), (2);', SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_save,
    delete_file('tests/testdata.asa'),
    expect_sql('SELECT * FROM t ORDER BY id;',
               table([id], [[1],[2]])),
    ( exists_file('tests/testdata.asa') ->
        format('ASSERTION FAILED: read-only SELECT rewrote the database file.~n', []),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_shutdown,
    cleanup.

run_wal_recovery_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    asadb_exec_sql('CREATE DATABASE wal_assert; USE wal_assert; CREATE TABLE t (id INT, name TEXT); INSERT INTO t VALUES (1, ''A''), (2, ''B''); UPDATE t SET name = ''BB'' WHERE id = 2;', SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_boot('tests/testdata.asa'),
    expect_sql('SELECT * FROM t ORDER BY id;',
               table([id,name], [[1,'A'],[2,'BB']])),
    asadb_save,
    size_file('tests/testdata.asa.wal', WalSize),
    ( WalSize =:= 0 ->
        true
    ;   format('ASSERTION FAILED: WAL was not checkpointed after save.~n', []),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_shutdown,
    cleanup.

run_limited_result_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    asadb_exec_sql('CREATE DATABASE limit_assert; USE limit_assert; CREATE TABLE t (id INT); INSERT INTO t VALUES (1), (2), (3), (4);', SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_exec_sql_limited('SELECT * FROM t ORDER BY id;', 3, Limited),
    ( Limited = multi([table([id], [[1],[2],[3]])]) ->
        true
    ;   format('ASSERTION FAILED: limited query returned ~w.~n', [Limited]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_database_metadata(BeforeCountMetadata),
    BeforeSequentialScans = BeforeCountMetadata.storage.planner.sequential_scans,
    asadb_exec_sql_limited('SELECT COUNT(*) AS total FROM t;', 3, Counted),
    ( Counted = multi([table([total], [[4]])]) ->
        true
    ;   format('ASSERTION FAILED: result limit changed aggregate semantics: ~w.~n', [Counted]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_database_metadata(Metadata),
    Planner = Metadata.storage.planner,
    ( Planner.metadata_count_scans >= 1,
      Planner.sequential_scans =:= BeforeSequentialScans ->
        true
    ;   format('ASSERTION FAILED: COUNT(*) did not use the catalog metadata path: ~w.~n', [Planner]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_result_json(table_page([id], [[1],[2]], true), JSON),
    ( sub_atom(JSON, _, _, _, '"has_more":true') ->
        true
    ;   format('ASSERTION FAILED: paged result JSON is incomplete: ~w.~n', [JSON]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_shutdown,
    cleanup.

run_storage_engine_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE storage_assert; USE storage_assert; CREATE TABLE items (id INT PRIMARY KEY, name TEXT, qty INT); INSERT INTO items (id, name, qty) VALUES (1, ''A'', 10), (2, ''B'', 20), (3, ''C'', 20), (4, ''D'', 40); CREATE INDEX idx_qty ON items(qty);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT name FROM items WHERE qty = 20 ORDER BY name;',
               table([name], [['B'],['C']])),
    expect_sql('SELECT id FROM items WHERE id >= 3 ORDER BY id;',
               table([id], [[3],[4]])),
    asadb_save,
    asadb_storage_stats(Stats),
    get_dict(pager, Stats, Pager),
    get_dict(page_size, Pager, 4096),
    get_dict(buffer_pool, Pager, Buffer),
    get_dict(pages, Buffer, Pages),
    get_dict(btree_cache, Stats, Cache),
    get_dict(entries, Cache, Entries),
    ( Pages > 0, Entries > 0 ->
        true
    ;   format('ASSERTION FAILED: storage engine stats did not show active pager/btree cache. Got: ~w~n', [Stats]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_shutdown,
    cleanup.

run_drop_table_cleanup_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE drop_assert; USE drop_assert; CREATE TABLE doomed (id INT PRIMARY KEY, qty INT); INSERT INTO doomed VALUES (1, 20), (2, 30); CREATE INDEX idx_qty ON doomed(qty);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT id FROM doomed WHERE qty = 20;',
               table([id], [[1]])),
    asadb_record_manager:asadb_record_store_id(drop_assert, doomed, StoreId),
    atom_concat(StoreId, '.heap', HeapName),
    directory_file_path('tests/testdata.asa.store', HeapName, HeapFile),
    asadb_record_manager:asadb_record_index_file(StoreId, qty, IndexFile),
    ( exists_file(HeapFile), exists_file(IndexFile) ->
        true
    ;   format('ASSERTION FAILED: DROP TABLE fixture did not create heap/index files.~nHeap=~w~nIndex=~w~n', [HeapFile,IndexFile]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    expect_sql('DROP TABLE IF EXISTS doomed;',
               ok(dropped_table(doomed))),
    expect_sql('SHOW TABLES;',
               table([table], [])),
    ( \+ exists_file(HeapFile), \+ exists_file(IndexFile) ->
        true
    ;   format('ASSERTION FAILED: DROP TABLE left heap/index files behind.~nHeap=~w~nIndex=~w~n', [HeapFile,IndexFile]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_shutdown,
    asadb_boot('tests/testdata.asa'),
    expect_sql('SHOW TABLES;',
               table([table], [])),
    expect_sql('DROP TABLE IF EXISTS doomed;',
               ok(dropped_table(doomed))),
    asadb_shutdown,
    cleanup.

run_catalog_multitable_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE cat_assert; USE cat_assert; CREATE TABLE alpha (id INT); CREATE TABLE beta (id INT); CREATE TABLE gamma (id INT); INSERT INTO alpha VALUES (1); INSERT INTO beta VALUES (1); INSERT INTO gamma VALUES (1);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_current_database(CurrentDb),
    asadb_get_state(state(_, DBs)),
    findall(Name, core_state_named_table(CurrentDb, DBs, cat_assert, Name), Names0),
    sort(Names0, Names),
    ( Names == [alpha,beta,gamma] ->
        true
    ;   format('ASSERTION FAILED: catalog did not list all tables. Got: ~w~n', [Names]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_shutdown,
    cleanup.

core_state_named_table(CurrentDb, DBs, DBName, TableName) :-
    CurrentDb == DBName,
    member(db(DBName, Tables, _, _, _, _), DBs),
    member(table(TableName, _, _, _), Tables).

run_critical_select_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE crit_assert; USE crit_assert; CREATE TABLE users (id INT PRIMARY KEY, age INT); CREATE TABLE orders (id INT PRIMARY KEY, user_id INT, total INT); INSERT INTO users (id, age) VALUES (1, 10), (2, 20), (3, 30); INSERT INTO orders (id, user_id, total) VALUES (10, 1, 50), (11, 1, 70), (12, 2, 30), (13, 4, 99); CREATE VIEW user_ages AS SELECT id, age FROM users;',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT u.id, o.total FROM users u INNER JOIN orders o ON u.id = o.user_id ORDER BY u.id, o.total;',
               table(['u.id','o.total'], [[1,50],[1,70],[2,30]])),
    expect_sql('SELECT u.id, o.total FROM users u LEFT JOIN orders o ON u.id = o.user_id ORDER BY u.id, o.total;',
               table(['u.id','o.total'], [[1,50],[1,70],[2,30],[3,null]])),
    expect_sql('SELECT u.id, o.total FROM users u RIGHT JOIN orders o ON u.id = o.user_id ORDER BY o.id;',
               table(['u.id','o.total'], [[1,50],[1,70],[2,30],[null,99]])),
    expect_sql('SELECT user_id, COUNT(*) AS n, SUM(total) AS s, AVG(total) AS a, MIN(total) AS mn, MAX(total) AS mx FROM orders GROUP BY user_id ORDER BY user_id;',
               table([user_id,n,s,a,mn,mx], [[1,2,120,60,50,70],[2,1,30,30,30,30],[4,1,99,99,99,99]])),
    expect_sql('SELECT id FROM users WHERE id IN (SELECT user_id FROM orders) ORDER BY id;',
               table([id], [[1],[2]])),
    expect_sql('SELECT (SELECT COUNT(*) FROM orders) AS order_count FROM users LIMIT 1;',
               table([order_count], [[4]])),
    expect_sql('SELECT id FROM users WHERE age > 20 UNION SELECT user_id FROM orders WHERE total = 30;',
               table([id], [[2],[3]])),
    expect_sql('SELECT id, CASE WHEN age >= 20 THEN ''adult'' ELSE ''young'' END AS bucket, CONCAT(''u'', id) AS label FROM users ORDER BY id;',
               table([id,bucket,label], [[1,young,u1],[2,adult,u2],[3,adult,u3]])),
    expect_sql('SELECT * FROM user_ages ORDER BY id;',
               table([id,age], [[1,10],[2,20],[3,30]])),
    expect_sql('CREATE FUNCTION hello(name VARCHAR(100)) RETURNS VARCHAR(200) BEGIN RETURN name END;',
               ok(created_function(hello))),
    expect_sql('CREATE PROCEDURE noop(IN uid INT) BEGIN SELECT uid END;',
               ok(created_procedure(noop))),
    expect_sql('CREATE TRIGGER user_audit AFTER INSERT ON users FOR EACH ROW BEGIN SELECT ''audit'' END;',
               ok(created_trigger(user_audit))),
    expect_sql('DROP TRIGGER user_audit;',
               ok(dropped_trigger(user_audit))),
    expect_sql('DROP PROCEDURE noop;',
               ok(dropped_procedure(noop))),
    expect_sql('DROP FUNCTION hello;',
               ok(dropped_function(hello))),
    asadb_shutdown,
    cleanup.

run_mysql55_manifest_assertions :-
    ( mysql55_feature_status(replace, planned),
      mysql55_feature_status(type(varchar), implemented),
      asadb_parse_sql('REPLACE INTO t VALUES (1);',
                      [unsupported_mysql55(replace, raw(_))]) ->
        true
    ;   format('ASSERTION FAILED: MySQL compatibility manifest is not wired to parser fallback.~n', []),
        cleanup,
        halt(1)
    ).

expect_sql(SQL, Expected) :-
    asadb_exec_sql(SQL, Result),
    ( Result = multi([Expected]) ->
        true
    ;   format('ASSERTION FAILED for SQL: ~w~nExpected: ~w~nGot: ~w~n', [SQL, Expected, Result]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ).

cleanup :-
    ( exists_file('tests/testdata.asa') -> delete_file('tests/testdata.asa') ; true ),
    ( exists_file('tests/testdata.asa.journal') -> delete_file('tests/testdata.asa.journal') ; true ),
    ( exists_file('tests/testdata.asa.current_db') -> delete_file('tests/testdata.asa.current_db') ; true ),
    ( exists_file('tests/testdata.asa.wal') -> delete_file('tests/testdata.asa.wal') ; true ),
    ( exists_file('tests/testdata.asa.meta') -> delete_file('tests/testdata.asa.meta') ; true ),
    ( exists_file('tests/testdata.asa.meta.tmp') -> delete_file('tests/testdata.asa.meta.tmp') ; true ),
    ( exists_file('tests/testdata.asa.meta.bak') -> delete_file('tests/testdata.asa.meta.bak') ; true ),
    ( exists_directory('tests/testdata.asa.store') -> delete_directory_and_contents('tests/testdata.asa.store') ; true ).
