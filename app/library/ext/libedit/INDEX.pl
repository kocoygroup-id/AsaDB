/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(el_wrap, editline, editline).
index(el_wrap(?), editline, editline).
index(el_wrap(?,?,?,?), editline, editline).
index(el_wrap(?,?,?,?,?), editline, editline).
index(el_wrapped(?), editline, editline).
index(el_unwrap(?), editline, editline).
index(el_source(?,?), editline, editline).
index(el_bind(?,?), editline, editline).
index(el_set(?,?), editline, editline).
index(el_addfn(+,+,+,3), editline, editline).
index(el_cursor(?,?), editline, editline).
index(el_line(?,?), editline, editline).
index(el_insertstr(?,?), editline, editline).
index(el_deletestr(?,?), editline, editline).
index(el_history(?,?), editline, editline).
index(el_history_events(?,?), editline, editline).
index(el_add_history(?,?), editline, editline).
index(el_write_history(?,?), editline, editline).
index(el_read_history(?,?), editline, editline).
index(el_version(?), editline, editline).
