% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- use_module('../src/asadb_core.pl').
:- use_module('../src/asadb_mysql55_compat.pl').
:- use_module('../src/kocoy.pl').
:- use_module(library(filesex)).
:- if(exists_source(library(time))).
:- use_module(library(time)).
:- endif.
:- initialization(main, main).

main :-
    run_sql_file('tests/smoke.sql'),
    run_sql_file('tests/production_foundation.sql'),
    run_sql_file('tests/alter_table_comprehensive.sql'),
    run_sql_file('tests/critical_select_features.sql'),
    run_persistence_assertions,
    run_metadata_persistence_assertions,
    run_metadata_version_upgrade_assertions,
    run_alter_order_assertions,
    run_auto_increment_assertions,
    run_schema_integrity_assertions,
    run_incremental_insert_assertions,
    run_stop_on_error_assertions,
    run_bounded_insert_batch_assertions,
    run_insert_key_hash_collision_assertions,
    run_order_by_duplicate_assertions,
    run_order_by_wildcard_assertions,
    run_order_by_filtered_projection_assertions,
    run_delete_where_safety_assertions,
    run_duplicate_column_assertions,
    run_bare_identifier_insert_assertions,
    run_wal_recovery_assertions,
    run_read_only_no_autosave_assertions,
    run_limited_result_assertions,
    run_storage_engine_assertions,
    run_native_storage_accelerator_assertions,
    run_logic_jit_assertions,
    run_drop_table_cleanup_assertions,
    run_drop_database_assertions,
    run_catalog_multitable_assertions,
    run_critical_select_assertions,
    run_join_syntax_compat_assertions,
    run_mysql55_manifest_assertions,
    cleanup,
    halt(0).

run_stop_on_error_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    asadb_exec_sql('CREATE DATABASE stop_assert; USE stop_assert; CREATE TABLE t (id INT PRIMARY KEY); BEGIN;', Setup),
    ( result_has_error(Setup) ->
        asadb_format_result(Setup),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_exec_sql_stop_on_error(
        'INSERT INTO t VALUES (1); INSERT INTO missing VALUES (2); INSERT INTO t VALUES (3);',
        Result),
    ( Result = multi([ok(inserted(t,1)), error(_,_)]) -> true
    ; format('ASSERTION FAILED: stop-on-error executed past failure: ~q.~n',
             [Result]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    expect_sql('SELECT COUNT(*) AS total FROM t;', table([total], [[1]])),
    expect_sql('ROLLBACK;', ok(rolled_back)),
    expect_sql('SELECT COUNT(*) AS total FROM t;', table([total], [[0]])),
    asadb_shutdown,
    cleanup.

% A dump commonly emits hundreds of consecutive INSERT statements for the
% same table.  Execution may combine them for speed, but the combined run must
% stay bounded so a Reservoir worker never receives one dump-sized row list.
run_bounded_insert_batch_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    bounded_insert_fixture(10, 512, SQL, ExpectedRows),
    asadb_exec_sql(SQL, Result),
    ( Result = multi([ok(created_database(batch_assert)),
                      ok(using_database(batch_assert)),
                      ok(created_table(batch_rows))|InsertResults]),
      InsertResults \= [],
      maplist(bounded_insert_result, InsertResults, InsertCounts),
      sum_list(InsertCounts, Total),
      Total =:= ExpectedRows ->
        true
    ; format('ASSERTION FAILED: consecutive INSERT run was not bounded: ~q.~n',
             [Result]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    expect_sql('SELECT COUNT(*) AS total FROM batch_rows;',
               table([total], [[ExpectedRows]])),
    asadb_shutdown,
    cleanup.

% A UNIQUE-cache trie stores hashes only and exact-checks candidate rows in
% the record store.  Hash collisions must therefore behave like an idempotent
% set insertion.  SWI-Prolog 9.2 reaches such a collision in the 72k import
% fixture much sooner than newer runtimes did, which previously aborted the
% otherwise valid transaction.
run_insert_key_hash_collision_assertions :-
    trie_new(Trie),
    setup_call_cleanup(
        true,
        ( asadb_core:constraint_key_hash([number(2287)], FirstHash),
          asadb_core:constraint_key_hash([number(5900)], SecondHash),
          FirstHash \== SecondHash,
          asadb_core:insert_key_trie_add_hash(Trie, 42),
          asadb_core:insert_key_trie_add_hash(Trie, 42),
          trie_lookup(Trie, 42, true)
        ),
        trie_destroy(Trie)
    ), !.
run_insert_key_hash_collision_assertions :-
    format('ASSERTION FAILED: UNIQUE hash collision was not idempotent.~n', []),
    cleanup,
    halt(1).

bounded_insert_result(ok(inserted(batch_rows, Count)), Count) :-
    Count =< 512.

bounded_insert_fixture(StatementCount, RowsPerStatement, SQL, ExpectedRows) :-
    findall(Statement,
            ( between(1, StatementCount, StatementNo),
              First is (StatementNo - 1) * RowsPerStatement + 1,
              Last is StatementNo * RowsPerStatement,
              findall(Row,
                      ( between(First, Last, Id),
                        format(atom(Row), '(~w, ''row-~w'')', [Id, Id])
                      ),
                      Rows),
              atomic_list_concat(Rows, ', ', Values),
              format(atom(Statement),
                     'INSERT INTO batch_rows (id, label) VALUES ~w', [Values])
            ),
            Inserts),
    atomic_list_concat(Inserts, '; ', InsertSQL),
    format(atom(SQL),
           'CREATE DATABASE batch_assert; USE batch_assert; CREATE TABLE batch_rows (id INT PRIMARY KEY, label VARCHAR(32)); ~w;',
           [InsertSQL]),
    ExpectedRows is StatementCount * RowsPerStatement.

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
    ( Before.engine_version == '1.5.0',
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

run_metadata_version_upgrade_assertions :-
    cleanup,
    StaleMetadata = metadata{
        format:1,
        database_id:'asa-upgrade-regression',
        created_at:'2026-01-01T00:00:00Z',
        updated_at:'2026-01-01T00:00:00Z',
        last_checkpoint_at:'2026-01-01T00:00:00Z',
        checkpoint_count:7,
        engine_version:'1.3.0',
        storage_format:3,
        summary:summary{row_count:42}
    },
    setup_call_cleanup(
        open('tests/testdata.asa.meta', write, Out, [encoding(utf8)]),
        ( write_canonical(Out, StaleMetadata), write(Out, '.\n') ),
        close(Out)
    ),
    asadb_boot('tests/testdata.asa'),
    asadb_database_metadata(Upgraded),
    ( Upgraded.engine_version == '1.5.0',
      Upgraded.storage_format =:= 3,
      Upgraded.database_id == 'asa-upgrade-regression',
      Upgraded.checkpoint_count =:= 7 ->
        true
    ;   format('ASSERTION FAILED: stale metadata was not upgraded safely: ~w.~n', [Upgraded]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    asadb_shutdown,
    cleanup.

run_join_syntax_compat_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE join_syntax; USE join_syntax; CREATE TABLE a (id INT PRIMARY KEY, label TEXT, bucket TEXT); CREATE TABLE b (id INT PRIMARY KEY, status TEXT, bucket TEXT); INSERT INTO a VALUES (1, ''one'', ''x''), (2, ''two'', ''x''); INSERT INTO b VALUES (1, ''active'', ''x''), (2, ''idle'', ''y'');',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('SELECT a.id, a.label, b.status FROM a JOIN b USING (id) ORDER BY a.id;',
               table(['a.id','a.label','b.status'],
                     [[1,one,active],[2,two,idle]])),
    expect_sql('SELECT a.id, b.status FROM a JOIN b USING (id, bucket);',
               table(['a.id','b.status'], [[1,active]])),
    expect_sql('SELECT COUNT(*) AS total FROM a CROSS JOIN b;',
               table([total], [[4]])),
    expect_sql('SELECT a.id, b.status FROM a, b WHERE a.id = b.id ORDER BY a.id;',
               table(['a.id','b.status'], [[1,active],[2,idle]])),
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

run_schema_integrity_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE integrity_assert; USE integrity_assert; CREATE TABLE ledger (tenant_id INT, entry_id INT, code VARCHAR(3), amount DECIMAL(4,2), due_date DATE, CONSTRAINT ledger_pk PRIMARY KEY (tenant_id, entry_id), CONSTRAINT ledger_code UNIQUE (tenant_id, code), CONSTRAINT amount_positive CHECK (amount > 0)); CREATE TABLE parent (id INT PRIMARY KEY); CREATE TABLE child (id INT PRIMARY KEY, parent_id INT, CONSTRAINT child_parent FOREIGN KEY (parent_id) REFERENCES parent (id) ON DELETE RESTRICT ON UPDATE RESTRICT);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('INSERT INTO ledger VALUES (1, 1, ''ok'', 12.34, ''2024-02-29'');',
               ok(inserted(ledger, 1))),
    expect_integrity_rejected('INSERT INTO ledger VALUES (1, 1, ''du'', 2.00, ''2024-02-29'');'),
    expect_integrity_rejected('INSERT INTO ledger VALUES (1, 2, ''toolong'', 2.00, ''2024-02-29'');'),
    expect_integrity_rejected('INSERT INTO ledger VALUES (1, 2, ''due'', 2.00, ''2024-02-30'');'),
    expect_integrity_rejected('INSERT INTO ledger VALUES (1, 2, ''neg'', -1.00, ''2024-02-29'');'),
    expect_integrity_rejected('UPDATE ledger SET due_date = ''not-a-date'' WHERE entry_id = 1;'),
    expect_sql('SELECT tenant_id, entry_id, code, amount, due_date FROM ledger;',
               table([tenant_id,entry_id,code,amount,due_date], [[1,1,ok,12.34,'2024-02-29']])),
    expect_sql('CREATE TABLE unsigned_values (id INT UNSIGNED);',
               ok(created_table(unsigned_values))),
    expect_sql('INSERT INTO unsigned_values VALUES (4294967295);',
               ok(inserted(unsigned_values, 1))),
    expect_integrity_rejected('INSERT INTO unsigned_values VALUES (-1);'),
    expect_integrity_rejected('INSERT INTO unsigned_values VALUES (4294967296);'),
    expect_integrity_rejected('INSERT INTO child VALUES (1, 99);'),
    asadb_exec_sql('INSERT INTO parent VALUES (99); INSERT INTO child VALUES (1, 99);', ParentChildResult),
    ( ParentChildResult == multi([ok(inserted(parent, 1)),ok(inserted(child, 1))]) -> true
    ; format('ASSERTION FAILED: valid foreign-key insert failed: ~w~n', [ParentChildResult]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    asadb_exec_sql('SHOW CREATE TABLE child;', ShowResult),
    ( result_has_error(ShowResult) ->
        format('ASSERTION FAILED: SHOW CREATE TABLE lost foreign-key metadata: ~w~n', [ShowResult]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_shutdown,
    asadb_boot('tests/testdata.asa'),
    expect_integrity_rejected('INSERT INTO child VALUES (2, 100);'),
    asadb_shutdown,
    cleanup.

expect_integrity_rejected(SQL) :-
    asadb_exec_sql(SQL, Result),
    ( result_has_error(Result) -> true
    ; format('ASSERTION FAILED: integrity violation was accepted: ~w~nResult: ~w~n', [SQL, Result]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ).

run_incremental_insert_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE incremental_insert_assert; USE incremental_insert_assert; CREATE TABLE parent (id INT PRIMARY KEY); CREATE TABLE child (id INT PRIMARY KEY, parent_id INT, CONSTRAINT child_parent FOREIGN KEY (parent_id) REFERENCES parent (id)); INSERT INTO parent VALUES (1), (2), (3);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    % A projected equality lookup materializes the persistent primary-key
    % index.  Rejected INSERTs must probe it without invalidating it.
    expect_sql('SELECT id FROM parent WHERE id = 2;', table([id], [[2]])),
    expect_sql('SELECT id FROM parent WHERE id = 2;', table([id], [[2]])),
    expect_sql('SELECT id FROM parent WHERE id = 2;', table([id], [[2]])),
    asadb_record_manager:asadb_record_store_id(incremental_insert_assert,
                                                parent, ParentStore),
    asadb_record_manager:asadb_record_index_file(ParentStore, id, IndexFile),
    asadb_storage_stats(BeforeStats),
    get_dict(planner, BeforeStats, BeforePlanner),
    get_dict(insert_validation_scans, BeforePlanner, Scans0),
    get_dict(insert_index_probes, BeforePlanner, Probes0),
    expect_integrity_rejected('INSERT INTO parent VALUES (2);'),
    expect_integrity_rejected('INSERT INTO parent VALUES (2.0);'),
    asadb_storage_stats(RejectedStats),
    get_dict(planner, RejectedStats, RejectedPlanner),
    get_dict(insert_validation_scans, RejectedPlanner, Scans0),
    get_dict(insert_index_probes, RejectedPlanner, Probes1),
    ( Probes1 > Probes0, exists_file(IndexFile) -> true
    ; format('ASSERTION FAILED: indexed INSERT validation did not preserve/probe the index: ~w~n',
             [RejectedPlanner]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    expect_sql('SELECT id FROM parent ORDER BY id;',
               table([id], [[1],[2],[3]])),
    % New-batch uniqueness is checked before any page mutation.
    expect_integrity_rejected('INSERT INTO parent VALUES (4), (4);'),
    expect_integrity_rejected('INSERT INTO parent VALUES (5), (5.0);'),
    expect_sql('SELECT id FROM parent ORDER BY id;',
               table([id], [[1],[2],[3]])),
    expect_integrity_rejected('INSERT INTO child VALUES (1, 99);'),
    expect_sql('SELECT id FROM child;', table([id], [])),
    expect_sql('INSERT INTO child VALUES (1, 2);', ok(inserted(child, 1))),
    % A successful indexed-table INSERT invalidates the stale persistent file;
    % the next indexed query will rebuild it from committed rows.
    expect_sql('INSERT INTO parent VALUES (4);', ok(inserted(parent, 1))),
    ( \+ exists_file(IndexFile) -> true
    ; format('ASSERTION FAILED: successful INSERT left a stale B+Tree index.~n', []),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    expect_sql('SELECT id FROM parent WHERE id = 4;', table([id], [[4]])),
    expect_sql('BEGIN;', ok(started_transaction)),
    expect_sql('INSERT INTO parent VALUES (6);', ok(inserted(parent, 1))),
    expect_sql('ROLLBACK;', ok(rolled_back)),
    expect_sql('BEGIN;', ok(started_transaction)),
    expect_sql('INSERT INTO parent VALUES (6);', ok(inserted(parent, 1))),
    expect_sql('COMMIT;', ok(committed)),
    expect_integrity_rejected('INSERT INTO parent VALUES (6);'),
    expect_sql('SELECT id FROM parent ORDER BY id;',
               table([id], [[1],[2],[3],[4],[6]])),
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

% A paged table must be able to sort by a selected text column while WHERE
% filters on another column.  This crosses multiple sorter buffers, covering
% the production Double_Company query shape without making the core suite
% depend on an external stress-import file.  Keep this large enough that a
% comparator which reevaluates expressions for every comparison is visible,
% while the bound catches the former multi-second-to-minute regression rather
% than enforcing a fragile microbenchmark.
run_order_by_filtered_projection_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    order_by_filtered_projection_fixture(8192, Setup),
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    Query = 'SELECT department FROM Double_Company WHERE sales_yen > 100000 ORDER BY department;',
    statistics(walltime, [Started|_]),
    catch(call_with_time_limit(15, asadb_exec_sql_limited(Query, 500, Result)),
          time_limit_exceeded,
          Result = timeout),
    statistics(walltime, [Finished|_]),
    QueryMilliseconds is Finished - Started,
    ( Result = multi([table([department], Rows)]),
      length(Rows, 500),
      rows_are_ascending(Rows),
      QueryMilliseconds =< 15000 ->
        true
    ; format('ASSERTION FAILED: filtered projected ORDER BY result (ms=~w): ~q.~n',
             [QueryMilliseconds, Result]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    asadb_shutdown,
    cleanup.

order_by_filtered_projection_fixture(RowCount, SQL) :-
    findall(Row,
            ( between(1, RowCount, Id),
              order_fixture_department(Id, Department),
              TransactionCount is Id,
              SalesYen is 100000 + Id,
              format(atom(Row), '(~w, ''~w'', ~w, ~w)',
                     [Id, Department, TransactionCount, SalesYen])
            ),
            Rows),
    atomic_list_concat(Rows, ', ', Values),
    format(atom(SQL),
           'CREATE DATABASE order_projection_assert; USE order_projection_assert; CREATE TABLE Double_Company (company_id INT, department VARCHAR(60), transaction_count INT, sales_yen INT); INSERT INTO Double_Company VALUES ~w;',
           [Values]).

order_fixture_department(Id, 'Accounting') :- Id mod 3 =:= 0, !.
order_fixture_department(Id, 'Finance') :- Id mod 3 =:= 1, !.
order_fixture_department(_, 'Sales').

rows_are_ascending([]).
rows_are_ascending([_]).
rows_are_ascending([[Left], [Right]|Rows]) :-
    Left @=< Right,
    rows_are_ascending([[Right]|Rows]).

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
    Setup = 'CREATE DATABASE dup_col_assert; USE dup_col_assert; CREATE TABLE t (id INT, nama TEXT); ALTER TABLE t ADD COLUMN nama TEXT; ALTER TABLE t ADD COLUMN Nama TEXT; INSERT INTO t VALUES (1, ''A'');',
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

% The native storage accelerator must remain observable and preserve ordinary
% table-scan results.  Use enough rows to span several 4 KiB heap pages; a
% one-page fixture would not exercise batched stream reads.
run_native_storage_accelerator_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    native_storage_fixture(1024, Setup),
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    asadb_kocoy_reset,
    asadb_exec_sql_limited('SELECT label FROM native_scan_rows;', 2048,
                           QueryResult),
    ( QueryResult = multi([table([label], Rows)]), length(Rows, 1024) -> true
    ; format('ASSERTION FAILED: native storage scan changed query result: ~w.~n',
             [QueryResult]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    asadb_storage_stats(Stats),
    get_dict(native_storage, Stats, Native),
    get_dict(implementation, Native, 'swi_prolog_native_stream_batches'),
    get_dict(scan_batches, Native, Batches),
    get_dict(scanned_pages, Native, Pages),
    ( Batches >= 1, Pages >= 2 -> true
    ; format('ASSERTION FAILED: native storage accelerator was not exercised: ~w.~n',
             [Native]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    asadb_shutdown,
    cleanup.

native_storage_fixture(RowCount, SQL) :-
    findall(Row,
            ( between(1, RowCount, Id),
              format(atom(Row),
                     '(~d, ''native-page-~d-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'')',
                     [Id, Id])
            ),
            Rows),
    atomic_list_concat(Rows, ', ', Values),
    format(atom(SQL),
           'CREATE DATABASE native_storage_assert; USE native_storage_assert; CREATE TABLE native_scan_rows (id INT PRIMARY KEY, label TEXT); INSERT INTO native_scan_rows VALUES ~w;',
           [Values]).

run_logic_jit_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE logic_jit_assert; USE logic_jit_assert; CREATE TABLE truth_table (id INT, enabled INT, blocked INT); INSERT INTO truth_table VALUES (1, 1, 0), (2, 1, 1), (3, 0, 1), (4, 0, 0), (5, NULL, 0);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    expect_sql('LOCK TABLES logic_jit_assert.truth_table WRITE;',
               ok(locked_tables([logic_jit_assert-truth_table]))),
    expect_sql('UNLOCK TABLES;', ok(unlocked_tables)),
    expect_sql('SELECT * FROM truth_table GROUP BY enabled;',
               table([enabled], [[1],[0],[null]])),
    Query = 'SELECT id FROM truth_table WHERE enabled = 1 XOR blocked = 1 ORDER BY id;',
    expect_sql(Query, table([id], [[1],[3]])),
    expect_sql(Query, table([id], [[1],[3]])),
    expect_sql(Query, table([id], [[1],[3]])),
    expect_sql(Query, table([id], [[1],[3]])),
    expect_sql('SELECT id FROM truth_table WHERE enabled IS TRUE XOR blocked IS TRUE ORDER BY id;',
               table([id], [[1],[3]])),
    expect_sql('SELECT id FROM truth_table WHERE enabled IS UNKNOWN ORDER BY id;',
               table([id], [[5]])),
    expect_sql('SELECT id FROM truth_table WHERE enabled IS NOT FALSE ORDER BY id;',
               table([id], [[1],[2],[5]])),
    expect_sql('SELECT id FROM truth_table WHERE id / 2 >= 2 ORDER BY id;',
               table([id], [[4],[5]])),
    asadb_storage_stats(Stats),
    get_dict(jit, Stats, Jit),
    get_dict(parse_hits, Jit, ParseHits),
    get_dict(filter_hits, Jit, FilterHits),
    get_dict(filter_cache_entries, Jit, FilterEntries),
    get_dict(filter_cache_limit, Jit, FilterLimit),
    get_dict(native_code, Jit, false),
    ( ParseHits >= 1,
      FilterHits >= 1,
      FilterEntries >= 1,
      FilterEntries =< FilterLimit ->
        true
    ;   format('ASSERTION FAILED: bounded Prolog JIT cache was not exercised: ~w.~n',
               [Jit]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    % Exercise cache pressure: SQL ASTs stay bounded, while one-off filter
    % shapes remain interpreted instead of filling the compiled-plan cache.
    forall(between(1, 64, N),
           ( format(atom(SQL), 'SELECT id FROM truth_table WHERE id = ~d;', [N]),
             asadb_parse_sql(SQL, _),
             Expression = cmp('=', col(id), value(N)),
             asadb_core:prepare_row_filter(Expression, _)
           )),
    % Refresh this hot query before adding more than half a cache worth of
    % one-off shapes. The compiled filter remains resident because cold
    % expressions never displace compiled plans.
    asadb_parse_sql(Query, _),
    HotExpression = xor(cmp('=', col(enabled), value(1)),
                        cmp('=', col(blocked), value(1))),
    asadb_core:prepare_row_filter(HotExpression, _),
    forall(between(65, 140, N),
           ( format(atom(SQL), 'SELECT id FROM truth_table WHERE id = ~d;', [N]),
             asadb_parse_sql(SQL, _),
             Expression = cmp('=', col(id), value(N)),
             asadb_core:prepare_row_filter(Expression, _)
           )),
    asadb_storage_stats(BoundedStats),
    get_dict(jit, BoundedStats, BoundedJit),
    get_dict(sql_cache_entries, BoundedJit, SQLCacheEntries),
    get_dict(sql_cache_limit, BoundedJit, SQLCacheLimit),
    get_dict(filter_cache_entries, BoundedJit, BoundedFilterEntries),
    get_dict(filter_cache_limit, BoundedJit, BoundedFilterLimit),
    get_dict(parse_hits, BoundedJit, ParseHitsBeforeReuse),
    get_dict(filter_hits, BoundedJit, FilterHitsBeforeReuse),
    get_dict(filter_hotness_entries, BoundedJit, HotnessEntries),
    get_dict(filter_hotness_limit, BoundedJit, HotnessLimit),
    ( SQLCacheEntries =:= SQLCacheLimit,
      BoundedFilterEntries >= 1,
      BoundedFilterEntries =< BoundedFilterLimit,
      HotnessEntries =< HotnessLimit ->
        true
    ;   format('ASSERTION FAILED: Prolog JIT caches exceeded or missed their bounds: ~w.~n',
               [BoundedJit]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    % The hot plan remains resident while one-off expressions are denied
    % admission to the compiled-plan cache.
    % Query results must stay identical across the specialized path.
    expect_sql(Query, table([id], [[1],[3]])),
    asadb_storage_stats(RetainedStats),
    get_dict(jit, RetainedStats, RetainedJit),
    get_dict(parse_hits, RetainedJit, ParseHitsAfterReuse),
    get_dict(filter_hits, RetainedJit, FilterHitsAfterReuse),
    ( ParseHitsAfterReuse > ParseHitsBeforeReuse,
      FilterHitsAfterReuse > FilterHitsBeforeReuse ->
        true
    ;   format('ASSERTION FAILED: hot JIT plans did not survive cache pressure: ~w.~n',
               [RetainedJit]),
        asadb_shutdown,
        cleanup,
        halt(1)
    ),
    run_jit_hotness_and_concurrency_assertions,
    asadb_shutdown,
    cleanup.

run_jit_hotness_and_concurrency_assertions :-
    asadb_core:reset_logic_jit,
    forall(between(1, 140, N),
           ( Expression = cmp('=', col(id), value(N)),
             asadb_core:prepare_row_filter(Expression, interpreted(Expression))
           )),
    asadb_storage_stats(ColdStats),
    get_dict(jit, ColdStats, ColdJit),
    get_dict(filter_cache_entries, ColdJit, 0),
    get_dict(filter_specializations, ColdJit, 0),
    get_dict(filter_hotness_entries, ColdJit, ColdEntries),
    get_dict(filter_hotness_limit, ColdJit, ColdLimit),
    ColdEntries =< ColdLimit,
    Hot = cmp('=', col(id), value(999)),
    asadb_core:prepare_row_filter(Hot, interpreted(Hot)),
    asadb_core:prepare_row_filter(Hot, interpreted(Hot)),
    SavedFilter = compiled(PlanId, Hot),
    asadb_core:prepare_row_filter(Hot, SavedFilter),
    asadb_storage_stats(CompiledStats),
    get_dict(jit, CompiledStats, CompiledJit),
    get_dict(filter_specializations, CompiledJit, Specializations0),
    asadb_core:prepare_row_filter(Hot, compiled(PlanId, Hot)),
    asadb_storage_stats(HitStats),
    get_dict(jit, HitStats, HitJit),
    get_dict(filter_specializations, HitJit, Specializations0),
    findall(Thread,
            ( between(1, 4, Worker),
              thread_create(jit_cache_worker(Worker), Thread, [])
            ),
            Threads),
    maplist(join_jit_thread, Threads),
    % Eviction may happen after a query has prepared its filter handle.  The
    % saved handle must retain interpreter-correct behavior without pinning an
    % unbounded dynamic clause.
    forall(between(1, 140, N),
           ( Value is 10000 + N,
             Expression = cmp('=', col(id), value(Value)),
             asadb_core:prepare_row_filter(Expression, _),
             asadb_core:prepare_row_filter(Expression, _),
             asadb_core:prepare_row_filter(Expression, _)
           )),
    asadb_core:row_filter_matches(SavedFilter, row([id=999])),
    \+ asadb_core:row_filter_matches(SavedFilter, row([id=998])),
    asadb_storage_stats(ConcurrentStats),
    get_dict(jit, ConcurrentStats, ConcurrentJit),
    get_dict(filter_cache_entries, ConcurrentJit, ConcurrentEntries),
    get_dict(filter_cache_limit, ConcurrentJit, ConcurrentLimit),
    ConcurrentEntries =< ConcurrentLimit.

jit_cache_worker(Worker) :-
    forall(between(1, 500, N),
           ( Value is Worker * 1000 + (N mod 8),
             Expression = cmp('=', col(id), value(Value)),
             asadb_core:prepare_row_filter(Expression, _)
           )).

join_jit_thread(Thread) :-
    thread_join(Thread, Status),
    ( Status == true -> true
    ; throw(error(jit_worker_failed(Thread, Status), _))
    ).

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

% DROP DATABASE is both a catalog mutation and a destructive heap cleanup.
% It must clear the selected database, publish the new TVCC generation, and
% remain absent after restart; otherwise the panel can report a stale database
% after the SQL command or Delete DB control has already returned success.
run_drop_database_assertions :-
    cleanup,
    asadb_boot('tests/testdata.asa'),
    Setup = 'CREATE DATABASE retained_db; CREATE DATABASE doomed_db; USE doomed_db; CREATE TABLE rows_to_remove (id INT PRIMARY KEY); INSERT INTO rows_to_remove VALUES (1);',
    asadb_exec_sql(Setup, SetupResult),
    ( result_has_error(SetupResult) ->
        asadb_format_result(SetupResult),
        asadb_shutdown,
        cleanup,
        halt(1)
    ; true
    ),
    % USE is selection only.  A typo or a stale Flask/session affinity must
    % never recreate a database that DROP DATABASE removed (or any other DB).
    asadb_exec_sql('USE missing_after_drop;', MissingUse),
    ( MissingUse = multi([error(existence_error(database, missing_after_drop), _)]) -> true
    ; format('ASSERTION FAILED: USE created or accepted a missing database: ~w~n', [MissingUse]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    ( asadb_current_database(doomed_db) -> true
    ; format('ASSERTION FAILED: failed USE changed the selected database.~n', []),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    expect_sql('SHOW DATABASES;', table([database], [[doomed_db],[retained_db]])),
    expect_sql('DROP DATABASE doomed_db;', ok(dropped_database(doomed_db))),
    ( asadb_current_database(none) -> true
    ; format('ASSERTION FAILED: DROP DATABASE left the removed database selected.~n', []),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    expect_sql('SHOW DATABASES;', table([database], [[retained_db]])),
    % Separate executions model a new HTTP request.  The catalog may not use
    % a stale in-memory selection to recreate the just-dropped database.
    expect_sql('SHOW DATABASES;', table([database], [[retained_db]])),
    size_file('tests/testdata.asa.wal', WalSize),
    ( WalSize =:= 0 -> true
    ; format('ASSERTION FAILED: DROP DATABASE was left WAL-only (~w bytes).~n', [WalSize]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    asadb_shutdown,
    asadb_boot('tests/testdata.asa'),
    ( asadb_current_database(none) -> true
    ; format('ASSERTION FAILED: dropped database selection survived restart.~n', []),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
    expect_sql('SHOW DATABASES;', table([database], [[retained_db]])),
    asadb_exec_sql('CREATE DATABASE doomed_db; USE doomed_db; SHOW TABLES;', Recreated),
    ( Recreated = multi([ok(created_database(doomed_db)),
                         ok(using_database(doomed_db)),
                         table([table], [])]) -> true
    ; format('ASSERTION FAILED: dropped database recreated with stale tables: ~w~n', [Recreated]),
      asadb_shutdown,
      cleanup,
      halt(1)
    ),
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
    ( exists_directory('tests/testdata.asa.store') -> delete_directory_and_contents('tests/testdata.asa.store') ; true ),
    ( exists_directory('tests/testdata.asa.tvcc') -> delete_directory_and_contents('tests/testdata.asa.tvcc') ; true ).
