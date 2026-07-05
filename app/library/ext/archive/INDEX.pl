/*  Creator: make/0

    Purpose: Provide index for autoload
*/

index(archive_open(?,?,?), archive, archive).
index(archive_open(?,?,?,?), archive, archive).
index(archive_create(?,?,?), archive, archive).
index(archive_close(?), archive, archive).
index(archive_property(?,?), archive, archive).
index(archive_next_header(?,?), archive, archive).
index(archive_open_entry(?,?), archive, archive).
index(archive_header_property(?,?), archive, archive).
index(archive_set_header_property(?,?), archive, archive).
index(archive_extract(?,?,?), archive, archive).
index(archive_entries(?,?), archive, archive).
index(archive_data_stream(?,?,?), archive, archive).
index(archive_foldl(4,+,+,-), archive, archive).
