from asadb_server.util import is_single_select_statement, looks_like_write, sql_statements


def test_reader_sql_is_one_top_level_select_only():
    assert is_single_select_statement("SELECT ';' AS literal; -- comment\n")
    assert is_single_select_statement("/* comment ; */ SELECT 1")
    assert sql_statements("SELECT 1; UPDATE users SET admin = 1") == [
        "SELECT 1",
        "UPDATE users SET admin = 1",
    ]
    assert looks_like_write("SELECT 1; UPDATE users SET admin = 1")


def test_reader_sql_fails_closed_for_non_select_or_malformed_input():
    for sql in (
        "WITH x AS (SELECT 1) SELECT * FROM x",
        "SHOW TABLES",
        "SELECT 1; DELETE FROM users",
        "/* missing comment",
        "SELECT 'unterminated",
    ):
        assert not is_single_select_statement(sql)
        assert looks_like_write(sql)
