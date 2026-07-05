/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(odbc_connect(?,?,?), odbc, odbc).
index(odbc_driver_connect(?,?,?), odbc, odbc).
index(odbc_disconnect(?), odbc, odbc).
index(odbc_current_connection(?,?), odbc, odbc).
index(odbc_set_connection(?,?), odbc, odbc).
index(odbc_get_connection(?,?), odbc, odbc).
index(odbc_end_transaction(?,?), odbc, odbc).
index(odbc_query(?,?,?,?), odbc, odbc).
index(odbc_query(?,?,?), odbc, odbc).
index(odbc_query(?,?), odbc, odbc).
index(odbc_prepare(?,?,?,?), odbc, odbc).
index(odbc_prepare(?,?,?,?,?), odbc, odbc).
index(odbc_execute(?,?), odbc, odbc).
index(odbc_execute(?,?,?), odbc, odbc).
index(odbc_fetch(?,?,?), odbc, odbc).
index(odbc_next_result_set(?), odbc, odbc).
index(odbc_close_statement(?), odbc, odbc).
index(odbc_clone_statement(?,?), odbc, odbc).
index(odbc_free_statement(?), odbc, odbc).
index(odbc_current_table(?,?), odbc, odbc).
index(odbc_current_table(?,?,?), odbc, odbc).
index(odbc_table_column(?,?,?), odbc, odbc).
index(odbc_table_column(?,?,?,?), odbc, odbc).
index(odbc_type(?,?,?), odbc, odbc).
index(odbc_data_source(?,?), odbc, odbc).
index(odbc_table_primary_key(?,?,?), odbc, odbc).
index(odbc_table_foreign_key(?,?,?,?,?), odbc, odbc).
index(odbc_set_option(?), odbc, odbc).
index(odbc_statistics(?), odbc, odbc).
index(odbc_debug(?), odbc, odbc).
