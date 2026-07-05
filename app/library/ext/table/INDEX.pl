/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(new_table(?,?,?,?), table, table).
index(open_table(?), table, table).
index(close_table(?), table, table).
index(free_table(?), table, table).
index(table_window(?,?,?), table, table).
index(read_table_record(?,?,?,?), table, table).
index(read_table_record_data(?,?,?,?), table, table).
index(read_table_fields(?,?,?,?), table, table).
index(get_table_attribute(?,?,?), table, table).
index(table_previous_record(?,?,?), table, table).
index(table_start_of_record(?,?,?,?), table, table).
index(in_table(?,?,?), table, table).
index(new_order_table(?,?), table, table).
index(order_table_mapping(?,?,?), table, table).
index(compare_strings(?,?,?,?), table, table).
index(prefix_string(?,?,?), table, table).
index(prefix_string(?,?,?,?), table, table).
index(sub_string(?,?,?), table, table).
index(table_version(?,?), table, table).
index(sort_table(?,?), table_util, table_util).
index(verify_table_order(?), table_util, table_util).
