% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only

:- use_module('../src/asadb_sql_frontend.pl').
:- initialization(main, main).

main :-
    expect_unsupported(key_using_btree,
        'CREATE TABLE t (id INT, KEY idx USING BTREE (id));'),
    expect_unsupported(prefix_index,
        'CREATE TABLE t (name VARCHAR(100), KEY idx_name (name(10)));'),
    expect_unsupported(foreign_key_no_action,
        'CREATE TABLE child (id INT, CONSTRAINT fk FOREIGN KEY (id) REFERENCES parent(id) ON DELETE NO ACTION);'),
    expect_unsupported(generated_column,
        'CREATE TABLE t (id INT, doubled INT GENERATED ALWAYS AS (id * 2) STORED);'),
    expect_unsupported(fulltext_index,
        'CREATE TABLE t (body TEXT, FULLTEXT KEY idx_body (body));'),
    expect_unsupported(spatial_index,
        'CREATE TABLE t (shape TEXT, SPATIAL INDEX idx_shape (shape));'),
    expect_unsupported(malformed_constraint,
        'CREATE TABLE t (id INT, CONSTRAINT broken SOMETHING (id));'),
    expect_unsupported(malformed_primary,
        'CREATE TABLE t (id INT, PRIMARY (id));'),
    expect_unsupported(malformed_foreign,
        'CREATE TABLE t (id INT, FOREIGN (id));'),
    expect_unsupported(unknown_type_modifier,
        'CREATE TABLE t (name VARCHAR(10) BOGUS);'),
    expect_unsupported(unknown_date_modifier,
        'CREATE TABLE t (created DATE BOGUS);'),
    expect_unsupported(ignored_invisible_option,
        'CREATE TABLE t (name VARCHAR(10) NOT NULL INVISIBLE);'),
    expect_unsupported(inline_reference,
        'CREATE TABLE t (parent_id INT REFERENCES parent(id));'),
    expect_unsupported(unsupported_collation_semantics,
        'CREATE TABLE t (name VARCHAR(10) COLLATE utf8mb4_unicode_ci);'),
    expect_supported_index,
    expect_canonical_mysql_types,
    expect_canonical_mysql_alter_types,
    format('MySQL DDL fail-closed regression passed.~n', []),
    halt(0).

expect_unsupported(Label, SQL) :-
    asadb_parse_sql(SQL, Statements),
    ( Statements = [unsupported_mysql55(_)] ->
        true
    ; format(user_error,
             'ASSERTION FAILED (~w): unsafe DDL parsed as supported: ~q~n',
             [Label, Statements]),
      halt(1)
    ).

expect_supported_index :-
    SQL = 'CREATE TABLE indexed_rows (id INT, KEY idx_id (id));',
    asadb_parse_sql(SQL, Statements),
    Expected = [create_table(indexed_rows,
                             [col(id, 'int ', [])],
                             table_options([index_key(idx_id, [id])], []))],
    expect_equal(valid_index, Expected, Statements).

expect_canonical_mysql_types :-
    SQL = 'CREATE TABLE mysql_types (id INT(11) UNSIGNED, name VARCHAR(100) CHARACTER SET utf8mb4);',
    asadb_parse_sql(SQL, Statements),
    Expected = [create_table(mysql_types,
                             [col(id, 'int unsigned ', []),
                              col(name, 'varchar ( 100 ) ', [])],
                             table_options([], []))],
    expect_equal(canonical_mysql_types, Expected, Statements).

expect_canonical_mysql_alter_types :-
    SQL = 'ALTER TABLE mysql_types MODIFY id INT(11) UNSIGNED, MODIFY name VARCHAR(100) CHARACTER SET utf8mb4;',
    asadb_parse_sql(SQL, Statements),
    Expected = [alter_table(mysql_types,
                            [modify_column(id, 'int unsigned ', []),
                             modify_column(name, 'varchar ( 100 ) ', [])])],
    expect_equal(canonical_mysql_alter_types, Expected, Statements).

expect_equal(_, Expected, Expected) :- !.
expect_equal(Label, Expected, Actual) :-
    format(user_error,
           'ASSERTION FAILED (~w): expected ~q, got ~q~n',
           [Label, Expected, Actual]),
    halt(1).
