% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- module(asadb_record_manager, [
    asadb_record_store_open/1,
    asadb_record_store_id/3,
    asadb_record_index_file/3,
    asadb_record_invalidate_indexes/1,
    asadb_record_tx_begin/0,
    asadb_record_tx_commit/0,
    asadb_record_tx_rollback/0,
    asadb_record_create/1,
    asadb_record_drop/1,
    asadb_record_truncate/1,
    asadb_record_insert_batch/2,
    asadb_record_insert_batch/3,
    asadb_record_scan/3,
    asadb_record_read/3,
    asadb_record_read_rids/3,
    asadb_record_update_batch/3,
    asadb_record_delete_batch/3,
    asadb_record_rewrite/5,
    asadb_record_stats/2
]).

:- use_module(library(readutil)).
:- use_module(library(utf8)).
:- use_module(library(pairs)).
:- use_module('asadb_pager.pl').
:- use_module('asadb_page_manager.pl').

:- dynamic record_root/1.
:- dynamic record_tx_active/0.
:- dynamic record_tx_snapshot/3.
:- dynamic record_page_checked/2.

:- meta_predicate asadb_record_rewrite(+, 2, -, -, -).

asadb_record_store_open(BaseFile) :-
    atom_concat(BaseFile, '.store', Root),
    ensure_directory(Root),
    retractall(record_root(_)),
    retractall(record_page_checked(_, _)),
    assertz(record_root(Root)),
    recover_store_root(Root).

asadb_record_tx_begin :-
    record_tx_active, !.
asadb_record_tx_begin :-
    retractall(record_tx_snapshot(_, _, _)),
    assertz(record_tx_active),
    transaction_manifest(Manifest),
    setup_call_cleanup(open(Manifest, write, Stream, [encoding(utf8)]),
                       ( write_canonical(Stream, transaction(active)), write(Stream, '.\n'), flush_output(Stream) ),
                       close(Stream)).

asadb_record_tx_commit :-
    record_tx_active, !,
    % The transaction snapshot remains available until every dirty page is durable.
    asadb_pager_flush,
    forall(record_tx_snapshot(_, _, Backup), delete_if_exists(Backup)),
    retractall(record_tx_snapshot(_, _, _)),
    retractall(record_tx_active),
    transaction_manifest(Manifest),
    delete_if_exists(Manifest).
asadb_record_tx_commit.

asadb_record_tx_rollback :-
    record_tx_active, !,
    asadb_pager_flush,
    forall(record_tx_snapshot(StoreId, Status, Backup),
           restore_tx_snapshot(StoreId, Status, Backup)),
    retractall(record_tx_snapshot(_, _, _)),
    retractall(record_tx_active),
    transaction_manifest(Manifest),
    delete_if_exists(Manifest).
asadb_record_tx_rollback.

asadb_record_store_id(Database, Table, StoreId) :-
    with_output_to(codes(Codes), write_canonical(Database-Table)),
    phrase(utf8_codes(Codes), Bytes),
    bytes_hex(Bytes, HexCodes),
    atom_codes(StoreId, HexCodes).

asadb_record_index_file(StoreId, Column, File) :-
    with_output_to(codes(Codes), write_canonical(Column)),
    phrase(utf8_codes(Codes), Bytes),
    bytes_hex(Bytes, HexCodes),
    atom_codes(ColumnId, HexCodes),
    record_root(Root),
    atomic_list_concat([StoreId, '.', ColumnId, '.btree'], Name),
    directory_file_path(Root, Name, File).

asadb_record_create(StoreId) :-
    store_file(StoreId, File),
    ensure_tx_snapshot(StoreId),
    ensure_file_parent(File),
    asadb_pager_invalidate_file(File),
    retractall(record_page_checked(File, _)),
    setup_call_cleanup(open(File, write, Stream, [type(binary)]), true, close(Stream)).

asadb_record_drop(StoreId) :-
    store_file(StoreId, File),
    ensure_tx_snapshot(StoreId),
    asadb_pager_invalidate_file(File),
    retractall(record_page_checked(File, _)),
    delete_if_exists(File),
    undo_file(File, Undo), delete_if_exists(Undo),
    temp_file(File, Temp), delete_if_exists(Temp),
    backup_file(File, Backup), delete_if_exists(Backup),
    asadb_record_invalidate_indexes(StoreId).

asadb_record_invalidate_indexes(StoreId) :-
    record_root(Root),
    directory_files(Root, Names),
    atom_concat(StoreId, '.', Prefix),
    forall(( member(Name, Names),
             sub_atom(Name, 0, _, _, Prefix),
             sub_atom(Name, _, 6, 0, '.btree') ),
           ( directory_file_path(Root, Name, IndexFile),
             asadb_pager_invalidate_file(IndexFile),
             delete_if_exists(IndexFile)
           )).

asadb_record_truncate(StoreId) :-
    asadb_record_create(StoreId).

asadb_record_insert_batch(_, [], []) :- !.
asadb_record_insert_batch(StoreId, Rows, Rids) :-
    record_tx_active, !,
    store_file(StoreId, File),
    ensure_tx_snapshot(StoreId),
    ensure_record_file(File),
    append_rows(File, Rows, Rids),
    retractall(record_page_checked(File, _)).
asadb_record_insert_batch(StoreId, Rows, Rids) :-
    store_file(StoreId, File),
    ensure_tx_snapshot(StoreId),
    ensure_record_file(File),
    begin_append_undo(File),
    catch(
        ( append_rows(File, Rows, Rids),
          asadb_pager_flush,
          retractall(record_page_checked(File, _)),
          finish_append_undo(File)
        ),
        Error,
        ( asadb_pager_flush,
          recover_append_undo(File),
          throw(Error)
        )
    ).

asadb_record_insert_batch(_, []) :- !.
asadb_record_insert_batch(StoreId, Rows) :-
    record_tx_active, !,
    store_file(StoreId, File),
    ensure_tx_snapshot(StoreId),
    ensure_record_file(File),
    append_rows_without_rids_for_batch(File, Rows),
    retractall(record_page_checked(File, _)).
asadb_record_insert_batch(StoreId, Rows) :-
    store_file(StoreId, File),
    ensure_tx_snapshot(StoreId),
    ensure_record_file(File),
    begin_append_undo(File),
    catch(
        ( append_rows_without_rids_for_batch(File, Rows),
          asadb_pager_flush,
          retractall(record_page_checked(File, _)),
          finish_append_undo(File)
        ),
        Error,
        ( asadb_pager_flush,
          recover_append_undo(File),
          throw(Error)
        )
    ).

append_rows(File, Rows, Rids) :-
    rows_bytes(Rows, EncodedRows),
    asadb_pager_page_count(File, PageCount),
    ( PageCount =:= 0 ->
        PageNo = 0,
        asadb_page_new(PageNo, heap, none, none, Page0)
    ; PageNo is PageCount - 1,
      asadb_pager_read_page(File, PageNo, Page0)
    ),
    asadb_page_header(Page0, Meta0),
    asadb_page_records(Page0, ExistingPairs),
    record_pair_values(ExistingPairs, ExistingRecords),
    append_rows_pages(EncodedRows, File, PageNo, Meta0.previous_page,
                      ExistingRecords, Rids, FinalNo, FinalPage),
    asadb_pager_write_page(File, FinalNo, FinalPage).

record_append_chunk_size(8192).

% The buffered path is faster for ordinary DML and indexed JOIN fixtures.
% Switch to the streaming writer only for the very large generated batches
% that otherwise approach the Prolog stack limit.
record_direct_append_threshold(16000).

append_rows_without_rids_for_batch(File, Rows) :-
    length(Rows, Count),
    record_direct_append_threshold(Threshold),
    ( Count >= Threshold ->
        append_rows_without_rids_chunked(File, Rows)
    ; append_rows_without_rids_buffered(File, Rows)
    ).

append_rows_without_rids_buffered(File, Rows) :-
    rows_bytes(Rows, EncodedRows),
    asadb_pager_page_count(File, PageCount),
    ( PageCount =:= 0 ->
        PageNo = 0,
        asadb_page_new(PageNo, heap, none, none, Page0)
    ; PageNo is PageCount - 1,
      asadb_pager_read_page(File, PageNo, Page0)
    ),
    asadb_page_header(Page0, Meta0),
    asadb_page_records(Page0, ExistingPairs),
    record_pair_values(ExistingPairs, ExistingRecords),
    append_rows_pages_without_rids(EncodedRows, File, PageNo,
                                   Meta0.previous_page, ExistingRecords,
                                   FinalNo, FinalPage),
    asadb_pager_write_page(File, FinalNo, FinalPage).

append_rows_without_rids_chunked(File, Rows) :-
    record_append_chunk_size(ChunkSize),
    append_rows_without_rids_chunked(File, Rows, ChunkSize).

append_rows_without_rids_chunked(_, [], _) :- !.
append_rows_without_rids_chunked(File, Rows0, ChunkSize) :-
    take_record_chunk(Rows0, ChunkSize, Rows, Rest),
    append_rows_without_rids_file(File, Rows),
    append_rows_without_rids_chunked(File, Rest, ChunkSize).

take_record_chunk([], _, [], []).
take_record_chunk(Rows, 0, [], Rows) :- !.
take_record_chunk([Row|Rows0], Count, [Row|Chunk], Rest) :-
    Count > 0,
    Next is Count - 1,
    take_record_chunk(Rows0, Next, Chunk, Rest).

append_rows_without_rids_file(File, Rows) :-
    % Import batches are append-only.  Build the bounded page run first and
    % write it through one open stream; putting every completed page through
    % the small buffer pool made generated stress imports spend most of their
    % time opening, evicting, and flushing the same heap file.
    asadb_pager_invalidate_file(File),
    rows_bytes(Rows, EncodedRows),
    asadb_pager_page_count(File, PageCount),
    ( PageCount =:= 0 ->
        PageNo = 0,
        asadb_page_new(PageNo, heap, none, none, Page0)
    ; PageNo is PageCount - 1,
      asadb_pager_read_page(File, PageNo, Page0),
      asadb_pager_invalidate_file(File)
    ),
    asadb_page_header(Page0, Meta0),
    asadb_page_records(Page0, ExistingPairs),
    record_pair_values(ExistingPairs, ExistingRecords),
    append_rows_pages_collected(EncodedRows, PageNo, Meta0.previous_page,
                                ExistingRecords, Pages),
    write_record_pages(File, Pages).

append_rows_pages_collected([], PageNo, Prev, Records, [PageNo-Page]) :- !,
    asadb_page_build(PageNo, heap, Prev, none, Records, Page).
append_rows_pages_collected(EncodedRows, PageNo, Prev, ExistingRecords,
                            [PageNo-Page|Pages]) :-
    fill_page_records(EncodedRows, ExistingRecords, PageRecords, RestRows, _),
    ( RestRows == [] ->
        asadb_page_build(PageNo, heap, Prev, none, PageRecords, Page),
        Pages = []
    ; NextNo is PageNo + 1,
      asadb_page_build(PageNo, heap, Prev, NextNo, PageRecords, Page),
      append_rows_pages_collected(RestRows, NextNo, PageNo, [], Pages)
    ).

write_record_pages(_, []) :- !.
write_record_pages(File, Pages) :-
    setup_call_cleanup(
        open(File, update, Stream, [type(binary)]),
        write_record_pages_stream(Stream, Pages),
        close(Stream)
    ).

write_record_pages_stream(_, []) :- !.
write_record_pages_stream(Stream, [PageNo-Page|Pages]) :-
    asadb_pager_page_size(PageSize),
    Offset is PageNo * PageSize,
    seek(Stream, Offset, bof, _),
    format(Stream, '~s', [Page]),
    write_record_pages_stream(Stream, Pages).

append_rows_pages_without_rids([], _, PageNo, Prev, Records, PageNo, Page) :-
    asadb_page_build(PageNo, heap, Prev, none, Records, Page).
append_rows_pages_without_rids(EncodedRows, File, PageNo, Prev, ExistingRecords,
                               FinalNo, FinalPage) :-
    fill_page_records(EncodedRows, ExistingRecords, PageRecords, RestRows, _),
    ( RestRows == [] ->
        asadb_page_build(PageNo, heap, Prev, none, PageRecords, FinalPage),
        FinalNo = PageNo
    ; NextNo is PageNo + 1,
      asadb_page_build(PageNo, heap, Prev, NextNo, PageRecords, FullPage),
      asadb_pager_write_page(File, PageNo, FullPage),
      append_rows_pages_without_rids(RestRows, File, NextNo, PageNo, [],
                                     FinalNo, FinalPage)
    ).

append_rows_pages([], _, PageNo, Prev, Records, [], PageNo, Page) :-
    asadb_page_build(PageNo, heap, Prev, none, Records, Page).
append_rows_pages(EncodedRows, File, PageNo, Prev, ExistingRecords,
                  Rids, FinalNo, FinalPage) :-
    fill_page_records(EncodedRows, ExistingRecords, PageRecords, RestRows, Added),
    length(ExistingRecords, ExistingCount),
    page_rids(PageNo, ExistingCount, Added, PageRids),
    ( RestRows == [] ->
        asadb_page_build(PageNo, heap, Prev, none, PageRecords, FinalPage),
        FinalNo = PageNo,
        Rids = PageRids
    ; NextNo is PageNo + 1,
      asadb_page_build(PageNo, heap, Prev, NextNo, PageRecords, FullPage),
      asadb_pager_write_page(File, PageNo, FullPage),
      append_rows_pages(RestRows, File, NextNo, PageNo, [], RestRids, FinalNo, FinalPage),
      append(PageRids, RestRids, Rids)
    ).

fill_page_records(Rows, Existing, Records, Rest, AddedCount) :-
    length(Existing, ExistingCount),
    records_total_bytes(Existing, ExistingPayload),
    Used0 is 32 + ExistingCount * 4 + ExistingPayload,
    asadb_pager_page_size(PageSize),
    take_fitting_records(Rows, Used0, PageSize, Added, Rest, AddedCount),
    append(Existing, Added, Records).

take_fitting_records([], _, _, [], [], 0) :- !.
take_fitting_records([Bytes|Rows], Used0, PageSize, [Bytes|Added], Rest, Count) :-
    length(Bytes, Length),
    Used is Used0 + 4 + Length,
    Used =< PageSize, !,
    take_fitting_records(Rows, Used, PageSize, Added, Rest, Count0),
    Count is Count0 + 1.
take_fitting_records(Rows, _, _, [], Rows, 0).

records_total_bytes([], 0).
records_total_bytes([Bytes|Records], Total) :-
    length(Bytes, Length),
    records_total_bytes(Records, Rest),
    Total is Length + Rest.

page_rids(_, _, 0, []) :- !.
page_rids(PageNo, Slot, Count, [rid(PageNo,Slot)|Rids]) :-
    NextSlot is Slot + 1,
    NextCount is Count - 1,
    page_rids(PageNo, NextSlot, NextCount, Rids).

record_pair_values([], []).
record_pair_values([_-Value|Pairs], [Value|Values]) :- record_pair_values(Pairs, Values).

rows_bytes([], []).
rows_bytes([Row|Rows], [Bytes|Encoded]) :-
    row_bytes(Row, Bytes),
    rows_bytes(Rows, Encoded).

asadb_record_scan(StoreId, Rid, Row) :-
    store_file(StoreId, File),
    asadb_pager_scan_page(File, PageNo, Page),
    asadb_page_validate(Page),
    asadb_page_records(Page, Records),
    member(Slot-Bytes, Records),
    bytes_row(Bytes, Row),
    Rid = rid(PageNo, Slot).

asadb_record_read(StoreId, rid(PageNo, Slot), Row) :-
    store_file(StoreId, File),
    asadb_pager_read_page(File, PageNo, Page),
    ensure_record_page_valid(File, PageNo, Page),
    asadb_page_read_record(Page, Slot, Bytes),
    bytes_row(Bytes, Row).

ensure_record_page_valid(File, PageNo, _) :- record_page_checked(File, PageNo), !.
ensure_record_page_valid(File, PageNo, Page) :-
    asadb_page_validate(Page),
    assertz(record_page_checked(File, PageNo)).

asadb_record_read_rids(StoreId, Rids, Rows) :-
    store_file(StoreId, File),
    read_rids_cached(Rids, File, [], Rows).

read_rids_cached([], _, _, []).
read_rids_cached([rid(PageNo, Slot)|Rids], File, Cache0, Rows) :-
    cached_record_page(File, PageNo, Cache0, Page, Cache),
    ( asadb_page_read_record(Page, Slot, Bytes) ->
        bytes_row(Bytes, Row), Rows = [Row|Rest]
    ; Rows = Rest
    ),
    read_rids_cached(Rids, File, Cache, Rest).

cached_record_page(_, PageNo, Cache, Page, Cache) :-
    memberchk(PageNo-Page, Cache), !.
cached_record_page(File, PageNo, Cache, Page, [PageNo-Page|Cache]) :-
    asadb_pager_read_page(File, PageNo, Page),
    ensure_record_page_valid(File, PageNo, Page).

asadb_record_update_batch(_, [], 0) :- !.
asadb_record_update_batch(StoreId, Updates, Count) :-
    store_file(StoreId, File),
    ensure_tx_snapshot(StoreId),
    map_update_pages(Updates, PagePairs),
    keysort(PagePairs, Sorted),
    group_pairs_by_key(Sorted, Groups),
    with_mutation_backup(File, update_page_groups(File, Groups)),
    retractall(record_page_checked(File, _)),
    length(Updates, Count).

asadb_record_delete_batch(_, [], 0) :- !.
asadb_record_delete_batch(StoreId, Rids, Count) :-
    store_file(StoreId, File),
    ensure_tx_snapshot(StoreId),
    map_delete_pages(Rids, PagePairs),
    keysort(PagePairs, Sorted),
    group_pairs_by_key(Sorted, Groups),
    with_mutation_backup(File, delete_page_groups(File, Groups)),
    retractall(record_page_checked(File, _)),
    length(Rids, Count).

map_update_pages([], []).
map_update_pages([rid(Page,Slot)-Row|Updates], [Page-(Slot-Row)|Pairs]) :-
    map_update_pages(Updates, Pairs).

map_delete_pages([], []).
map_delete_pages([rid(Page,Slot)|Rids], [Page-Slot|Pairs]) :-
    map_delete_pages(Rids, Pairs).

update_page_groups(_, []).
update_page_groups(File, [PageNo-Updates|Groups]) :-
    asadb_pager_read_page(File, PageNo, Page0),
    update_page_records(Updates, Page0, Page),
    asadb_pager_write_page(File, PageNo, Page),
    update_page_groups(File, Groups).

update_page_records([], Page, Page).
update_page_records([Slot-Row|Updates], Page0, Page) :-
    row_bytes(Row, Bytes),
    asadb_page_replace_record(Page0, Slot, Bytes, Page1),
    update_page_records(Updates, Page1, Page).

delete_page_groups(_, []).
delete_page_groups(File, [PageNo-Slots|Groups]) :-
    asadb_pager_read_page(File, PageNo, Page0),
    delete_page_slots(Slots, Page0, Page),
    asadb_pager_write_page(File, PageNo, Page),
    delete_page_groups(File, Groups).

delete_page_slots([], Page, Page).
delete_page_slots([Slot|Slots], Page0, Page) :-
    ( asadb_page_delete_record(Page0, Slot, Page1) -> true ; Page1 = Page0 ),
    delete_page_slots(Slots, Page1, Page).

with_mutation_backup(_, Goal) :- record_tx_active, !,
    call(Goal).
with_mutation_backup(File, Goal) :-
    mutation_backup_file(File, Backup),
    asadb_pager_invalidate_file(File),
    delete_if_exists(Backup),
    copy_file(File, Backup),
    catch((call(Goal), asadb_pager_flush, delete_if_exists(Backup)), Error,
          ( asadb_pager_invalidate_file(File),
            delete_if_exists(File),
            rename_file(Backup, File),
            throw(Error) )).

% Transform is called as call(Transform, OldRow, Action).
% Action is keep(NewRow), keep, or delete.
asadb_record_rewrite(StoreId, Transform, NewCount, Changed, NewRids) :-
    store_file(StoreId, File),
    ensure_tx_snapshot(StoreId),
    temp_file(File, Temp),
    delete_if_exists(Temp),
    setup_call_cleanup(open(Temp, write, Stream, [type(binary)]), true, close(Stream)),
    rewrite_rows(StoreId, Transform, Temp, 0, NewCount, 0, Changed, [], RevRids),
    reverse(RevRids, NewRids),
    asadb_pager_flush,
    atomic_replace_store(File, Temp).

rewrite_rows(StoreId, Transform, Temp, Count0, Count, Changed0, Changed, Rids0, Rids) :-
    store_file(StoreId, Source),
    asadb_pager_page_count(Source, PageCount),
    rewrite_pages(0, PageCount, Source, Transform, Temp,
                  Count0, Count, Changed0, Changed, Rids0, Rids).

rewrite_pages(PageNo, PageCount, _, _, _, Count, Count, Changed, Changed, Rids, Rids) :-
    PageNo >= PageCount, !.
rewrite_pages(PageNo, PageCount, Source, Transform, Temp,
              Count0, Count, Changed0, Changed, Rids0, Rids) :-
    asadb_pager_read_page(Source, PageNo, Page),
    asadb_page_validate(Page),
    asadb_page_records(Page, EncodedRows),
    decode_page_rows(EncodedRows, Rows),
    transform_row_list(Rows, Transform, OutputRows, Changed0, Changed1),
    ( OutputRows == [] -> PageRids = []
    ; append_rows(Temp, OutputRows, PageRids), asadb_pager_flush
    ),
    length(OutputRows, Added),
    Count1 is Count0 + Added,
    reverse(PageRids, RevPageRids),
    append(RevPageRids, Rids0, Rids1),
    NextPage is PageNo + 1,
    rewrite_pages(NextPage, PageCount, Source, Transform, Temp,
                  Count1, Count, Changed1, Changed, Rids1, Rids).

decode_page_rows([], []).
decode_page_rows([_-Bytes|Records], [Row|Rows]) :-
    bytes_row(Bytes, Row),
    decode_page_rows(Records, Rows).

transform_row_list([], _, [], Changed, Changed).
transform_row_list([Row|Rows], Transform, OutputRows, Changed0, Changed) :-
    call(Transform, Row, Action),
    transform_row_action(Action, Row, OutputRows, Tail, Changed0, Changed1),
    transform_row_list(Rows, Transform, Tail, Changed1, Changed).

transform_row_action(delete, _, Rows, Rows, Changed0, Changed) :- !,
    Changed is Changed0 + 1.
transform_row_action(keep(NewRow), OldRow, [NewRow|Rows], Rows, Changed0, Changed) :- !,
    ( NewRow == OldRow -> Changed = Changed0 ; Changed is Changed0 + 1 ).
transform_row_action(keep, Row, [Row|Rows], Rows, Changed, Changed) :- !.
transform_row_action(_, Row, [Row|Rows], Rows, Changed, Changed).

asadb_record_stats(StoreId, record_store{
    file:File,
    pages:Pages,
    page_size:PageSize,
    bytes:Bytes,
    live_records:Records
}) :-
    store_file(StoreId, File),
    asadb_pager_page_count(File, Pages),
    asadb_pager_page_size(PageSize),
    ( exists_file(File) -> size_file(File, Bytes) ; Bytes = 0 ),
    aggregate_all(count, asadb_record_scan(StoreId, _, _), Records).

row_bytes(row(Pairs), Bytes) :- !,
    length(Pairs, PairCount),
    u16_record_bytes(PairCount, CountBytes),
    encode_row_pairs(Pairs, PairBytes),
    append([[82,1], CountBytes, PairBytes], Bytes),
    ensure_record_length(Bytes).
row_bytes(Row, [84|Bytes]) :-
    with_output_to(codes(Codes), write_canonical(Row)),
    phrase(utf8_codes(Codes), Bytes),
    ensure_record_length(Bytes).

ensure_record_length(Bytes) :-
    length(Bytes, Length),
    asadb_pager_page_size(PageSize),
    ( Length + 36 =< PageSize -> true
    ; throw(error(resource_error(record_too_large), Length))
    ).

bytes_row([82,1|Bytes], row(Pairs)) :- !,
    read_u16_record(Bytes, PairCount, Rest),
    decode_row_pairs(PairCount, Rest, Pairs, []).
bytes_row([84|Bytes], Row) :- !,
    phrase(utf8_codes(Codes), Bytes),
    read_term_from_codes(Codes, Row, []).
bytes_row(Bytes, Row) :-
    phrase(utf8_codes(Codes), Bytes),
    read_term_from_codes(Codes, Row, []).

encode_row_pairs([], []).
encode_row_pairs([Name=Value|Pairs], Bytes) :-
    atom_utf8_bytes(Name, NameBytes),
    length(NameBytes, NameLength),
    u16_record_bytes(NameLength, NameLengthBytes),
    encode_record_value(Value, ValueBytes),
    encode_row_pairs(Pairs, Rest),
    append([NameLengthBytes, NameBytes, ValueBytes, Rest], Bytes).

encode_record_value(null, [0]) :- !.
encode_record_value(Value, [1|Bytes]) :- integer(Value), !,
    signed_u64(Value, Unsigned),
    u64_record_bytes(Unsigned, Bytes).
encode_record_value(Value, [2|Bytes]) :- number(Value), !,
    number_codes(Value, Codes),
    length(Codes, Length),
    u16_record_bytes(Length, LengthBytes),
    append(LengthBytes, Codes, Bytes).
encode_record_value(Value, [3|Bytes]) :- atom(Value), !,
    atom_utf8_bytes(Value, ValueBytes),
    length(ValueBytes, Length),
    u16_record_bytes(Length, LengthBytes),
    append(LengthBytes, ValueBytes, Bytes).
encode_record_value(Value, [4|Bytes]) :- string(Value), !,
    string_codes(Value, Codes),
    phrase(utf8_codes(Codes), ValueBytes),
    length(ValueBytes, Length),
    u16_record_bytes(Length, LengthBytes),
    append(LengthBytes, ValueBytes, Bytes).
encode_record_value(Value, [5|Bytes]) :-
    with_output_to(codes(Codes), write_canonical(Value)),
    phrase(utf8_codes(Codes), ValueBytes),
    length(ValueBytes, Length),
    u16_record_bytes(Length, LengthBytes),
    append(LengthBytes, ValueBytes, Bytes).

decode_row_pairs(0, Rest, [], Rest) :- !.
decode_row_pairs(Count, Bytes0, [Name=Value|Pairs], Rest) :-
    read_u16_record(Bytes0, NameLength, Bytes1),
    take_record_bytes(NameLength, Bytes1, NameBytes, Bytes2),
    utf8_atom(NameBytes, Name),
    decode_record_value(Bytes2, Value, Bytes3),
    Next is Count - 1,
    decode_row_pairs(Next, Bytes3, Pairs, Rest).

decode_record_value([0|Bytes], null, Bytes) :- !.
decode_record_value([1|Bytes0], Value, Bytes) :- !,
    read_u64_record(Bytes0, Unsigned, Bytes),
    unsigned_signed_u64(Unsigned, Value).
decode_record_value([2|Bytes0], Value, Bytes) :- !,
    read_length_bytes(Bytes0, ValueBytes, Bytes),
    number_codes(Value, ValueBytes).
decode_record_value([3|Bytes0], Value, Bytes) :- !,
    read_length_bytes(Bytes0, ValueBytes, Bytes),
    utf8_atom(ValueBytes, Value).
decode_record_value([4|Bytes0], Value, Bytes) :- !,
    read_length_bytes(Bytes0, ValueBytes, Bytes),
    phrase(utf8_codes(Codes), ValueBytes),
    string_codes(Value, Codes).
decode_record_value([5|Bytes0], Value, Bytes) :-
    read_length_bytes(Bytes0, ValueBytes, Bytes),
    phrase(utf8_codes(Codes), ValueBytes),
    read_term_from_codes(Codes, Value, []).

read_length_bytes(Bytes0, ValueBytes, Bytes) :-
    read_u16_record(Bytes0, Length, Bytes1),
    take_record_bytes(Length, Bytes1, ValueBytes, Bytes).

atom_utf8_bytes(Atom, Bytes) :-
    atom_codes(Atom, Codes),
    phrase(utf8_codes(Codes), Bytes).

utf8_atom(Bytes, Atom) :-
    phrase(utf8_codes(Codes), Bytes),
    atom_codes(Atom, Codes).

u16_record_bytes(Value, [A,B]) :-
    A is (Value >> 8) /\ 255,
    B is Value /\ 255.

read_u16_record([A,B|Bytes], Value, Bytes) :- Value is (A << 8) + B.

u64_record_bytes(Value, [A,B,C,D,E,F,G,H]) :-
    A is (Value >> 56) /\ 255,
    B is (Value >> 48) /\ 255,
    C is (Value >> 40) /\ 255,
    D is (Value >> 32) /\ 255,
    E is (Value >> 24) /\ 255,
    F is (Value >> 16) /\ 255,
    G is (Value >> 8) /\ 255,
    H is Value /\ 255.

read_u64_record([A,B,C,D,E,F,G,H|Bytes], Value, Bytes) :-
    Value is (A << 56) + (B << 48) + (C << 40) + (D << 32) +
             (E << 24) + (F << 16) + (G << 8) + H.

signed_u64(Value, Unsigned) :-
    ( Value < 0 -> Unsigned is (1 << 64) + Value ; Unsigned = Value ).

unsigned_signed_u64(Unsigned, Value) :-
    SignBit is 1 << 63,
    ( Unsigned >= SignBit -> Value is Unsigned - (1 << 64) ; Value = Unsigned ).

take_record_bytes(0, Bytes, [], Bytes) :- !.
take_record_bytes(N, [Byte|Bytes], [Byte|Taken], Rest) :-
    N > 0,
    Next is N - 1,
    take_record_bytes(Next, Bytes, Taken, Rest).

store_file(StoreId, File) :-
    record_root(Root),
    atomic_list_concat([StoreId, '.heap'], Name),
    directory_file_path(Root, Name, File).

begin_append_undo(File) :-
    asadb_pager_flush,
    ( exists_file(File) -> size_file(File, Size) ; Size = 0 ),
    asadb_pager_page_size(PageSize),
    ( Size >= PageSize ->
        LastPage is Size // PageSize - 1,
        asadb_pager_read_page(File, LastPage, LastBytes)
    ; LastPage = none, LastBytes = []
    ),
    undo_file(File, Undo),
    setup_call_cleanup(
        open(Undo, write, Stream, [encoding(utf8)]),
        ( write_canonical(Stream, undo(Size, LastPage, LastBytes)),
          write(Stream, '.\n'), flush_output(Stream) ),
        close(Stream)
    ).

finish_append_undo(File) :- undo_file(File, Undo), delete_if_exists(Undo).

recover_append_undo(File) :-
    undo_file(File, Undo),
    exists_file(Undo), !,
    setup_call_cleanup(open(Undo, read, Stream, [encoding(utf8)]),
                       read_term(Stream, undo(Size, LastPage, LastBytes), []),
                       close(Stream)),
    truncate_file(File, Size),
    ( LastPage == none -> true
    ; asadb_pager_write_page(File, LastPage, LastBytes), asadb_pager_flush
    ),
    delete_if_exists(Undo).
recover_append_undo(_).

truncate_file(File, Size) :-
    ensure_record_file(File),
    setup_call_cleanup(
        open(File, update, Stream, [type(binary)]),
        ( seek(Stream, Size, bof, _), set_end_of_stream(Stream) ),
        close(Stream)
    ).

atomic_replace_store(File, Temp) :-
    asadb_pager_invalidate_file(File),
    asadb_pager_invalidate_file(Temp),
    backup_file(File, Backup),
    delete_if_exists(Backup),
    ( exists_file(File) -> rename_file(File, Backup) ; true ),
    catch(
        ( rename_file(Temp, File), delete_if_exists(Backup) ),
        Error,
        ( delete_if_exists(File),
          ( exists_file(Backup) -> rename_file(Backup, File) ; true ),
          throw(Error)
        )
    ).

recover_store_root(Root) :-
    recover_interrupted_transaction(Root),
    directory_files(Root, Names),
    forall(member(Name, Names), recover_store_entry(Root, Name)).

recover_store_entry(Root, Name) :-
    sub_atom(Name, _, 5, 0, '.undo'), !,
    sub_atom(Name, 0, _, 5, BaseName),
    directory_file_path(Root, BaseName, File),
    recover_append_undo(File).
recover_store_entry(Root, Name) :-
    sub_atom(Name, _, 7, 0, '.mutbak'), !,
    sub_atom(Name, 0, _, 7, BaseName),
    directory_file_path(Root, Name, Backup),
    directory_file_path(Root, BaseName, File),
    asadb_pager_invalidate_file(File),
    delete_if_exists(File),
    rename_file(Backup, File).
recover_store_entry(Root, Name) :-
    sub_atom(Name, _, 4, 0, '.bak'), !,
    sub_atom(Name, 0, _, 4, BaseName),
    directory_file_path(Root, Name, Backup),
    directory_file_path(Root, BaseName, File),
    ( exists_file(File) -> delete_if_exists(Backup) ; rename_file(Backup, File) ).
recover_store_entry(_, _).

ensure_tx_snapshot(_) :- \+ record_tx_active, !.
ensure_tx_snapshot(StoreId) :- record_tx_snapshot(StoreId, _, _), !.
ensure_tx_snapshot(StoreId) :-
    store_file(StoreId, File),
    tx_backup_file(File, Backup),
    delete_if_exists(Backup),
    ( exists_file(File) ->
        asadb_pager_invalidate_file(File),
        copy_file(File, Backup),
        Status = present
    ; Status = absent
    ),
    assertz(record_tx_snapshot(StoreId, Status, Backup)),
    transaction_manifest(Manifest),
    setup_call_cleanup(open(Manifest, append, Stream, [encoding(utf8)]),
        ( write_canonical(Stream, snapshot(StoreId, Status, Backup)), write(Stream, '.\n'), flush_output(Stream) ),
        close(Stream)).

restore_tx_snapshot(StoreId, present, Backup) :-
    store_file(StoreId, File),
    asadb_pager_invalidate_file(File),
    delete_if_exists(File),
    ( exists_file(Backup) -> rename_file(Backup, File) ; true ).
restore_tx_snapshot(StoreId, absent, Backup) :-
    store_file(StoreId, File),
    asadb_pager_invalidate_file(File),
    delete_if_exists(File),
    delete_if_exists(Backup).

recover_interrupted_transaction(Root) :-
    directory_file_path(Root, '.transaction', Manifest),
    exists_file(Manifest), !,
    setup_call_cleanup(open(Manifest, read, Stream, [encoding(utf8)]),
                       recover_transaction_stream(Stream),
                       close(Stream)),
    delete_if_exists(Manifest).
recover_interrupted_transaction(_).

recover_transaction_stream(Stream) :-
    read_term(Stream, Term, []),
    ( Term == end_of_file -> true
    ; Term = snapshot(StoreId, Status, Backup) ->
        restore_tx_snapshot(StoreId, Status, Backup),
        recover_transaction_stream(Stream)
    ; recover_transaction_stream(Stream)
    ).

transaction_manifest(Manifest) :-
    record_root(Root),
    directory_file_path(Root, '.transaction', Manifest).

undo_file(File, Undo) :- atom_concat(File, '.undo', Undo).
temp_file(File, Temp) :- atom_concat(File, '.tmp', Temp).
backup_file(File, Backup) :- atom_concat(File, '.bak', Backup).
tx_backup_file(File, Backup) :- atom_concat(File, '.txbak', Backup).
mutation_backup_file(File, Backup) :- atom_concat(File, '.mutbak', Backup).

ensure_record_file(File) :- exists_file(File), !.
ensure_record_file(File) :- ensure_file_parent(File),
    setup_call_cleanup(open(File, write, Stream, [type(binary)]), true, close(Stream)).

ensure_file_parent(File) :- file_directory_name(File, Dir), ensure_directory(Dir).
ensure_directory('.') :- !.
ensure_directory('') :- !.
ensure_directory(Dir) :- exists_directory(Dir), !.
ensure_directory(Dir) :- file_directory_name(Dir, Parent), ensure_directory(Parent), make_directory(Dir).

delete_if_exists(File) :- ( exists_file(File) -> delete_file(File) ; true ).

bytes_hex([], []).
bytes_hex([Byte|Bytes], [HighCode,LowCode|Codes]) :-
    High is (Byte >> 4) /\ 15,
    Low is Byte /\ 15,
    hex_code(High, HighCode),
    hex_code(Low, LowCode),
    bytes_hex(Bytes, Codes).

hex_code(Value, Code) :- Value < 10, !, Code is 48 + Value.
hex_code(Value, Code) :- Code is 87 + Value.
