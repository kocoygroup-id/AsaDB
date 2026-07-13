% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- module(asadb_pager, [
    asadb_pager_page_size/1,
    asadb_pager_read_file_codes/2,
    asadb_pager_write_file_codes/2,
    asadb_pager_write_xor_file_codes/4,
    asadb_pager_read_page/3,
    asadb_pager_scan_page/3,
    asadb_pager_write_page/3,
    asadb_pager_allocate_page/3,
    asadb_pager_page_count/2,
    asadb_pager_invalidate_file/1,
    asadb_pager_flush/0,
    asadb_pager_stats/1
]).

:- use_module(library(readutil)).
:- use_module('asadb_buffer_pool.pl').
:- use_module('asadb_config.pl').

asadb_pager_page_size(Size) :- asadb_config_get(page_size, Size).

asadb_pager_read_page(File, PageNo, Bytes) :-
    must_be(nonneg, PageNo),
    asadb_buffer_pool_pin(File, PageNo, load_fixed_page(File, PageNo), Bytes),
    asadb_buffer_pool_unpin(File, PageNo, clean).

asadb_pager_scan_page(File, PageNo, Bytes) :-
    exists_file(File),
    size_file(File, Size),
    asadb_pager_page_size(PageSize),
    PageCount is Size // PageSize,
    PageCount > 0,
    LastPage is PageCount - 1,
    setup_call_cleanup(
        open(File, read, Stream, [type(binary)]),
        scan_open_stream_page(Stream, File, LastPage, PageNo, Bytes),
        close(Stream)
    ).

scan_open_stream_page(Stream, File, LastPage, PageNo, Bytes) :-
    between(0, LastPage, PageNo),
    ( asadb_buffer_pool_get(File, PageNo, Bytes) -> true
    ; asadb_pager_page_size(PageSize),
      Offset is PageNo * PageSize,
      seek(Stream, Offset, bof, _),
      read_page_bytes(Stream, PageSize, Bytes),
      asadb_buffer_pool_put(File, PageNo, Bytes, clean)
    ).

asadb_pager_write_page(File, PageNo, Bytes0) :-
    must_be(nonneg, PageNo),
    asadb_pager_page_size(PageSize),
    fixed_page_bytes(PageSize, Bytes0, Bytes),
    asadb_buffer_pool_put(File, PageNo, Bytes, dirty).

asadb_pager_allocate_page(File, Bytes0, PageNo) :-
    asadb_pager_page_count(File, PageNo),
    asadb_pager_write_page(File, PageNo, Bytes0).

asadb_pager_page_count(File, Count) :-
    ( exists_file(File) -> size_file(File, Size) ; Size = 0 ),
    asadb_pager_page_size(PageSize),
    Count is (Size + PageSize - 1) // PageSize.

asadb_pager_flush :- asadb_buffer_pool_flush_all.

asadb_pager_invalidate_file(File) :-
    asadb_buffer_pool_invalidate_file(File).

load_fixed_page(File, PageNo, Bytes) :-
    asadb_pager_page_size(PageSize),
    Offset is PageNo * PageSize,
    ( exists_file(File) ->
        setup_call_cleanup(
            open(File, read, Stream, [type(binary)]),
            ( seek(Stream, Offset, bof, _),
              read_page_bytes(Stream, PageSize, Raw)
            ),
            close(Stream)
        )
    ; Raw = []
    ),
    fixed_page_bytes(PageSize, Raw, Bytes).

fixed_page_bytes(PageSize, Bytes0, Bytes) :-
    length_prefix(PageSize, Bytes0, Prefix),
    length(Prefix, Used),
    Padding is PageSize - Used,
    zero_bytes(Padding, Zeros),
    append(Prefix, Zeros, Bytes).

length_prefix(0, _, []) :- !.
length_prefix(_, [], []) :- !.
length_prefix(N, [Byte|Bytes], [Byte|Prefix]) :-
    N > 0,
    N1 is N - 1,
    length_prefix(N1, Bytes, Prefix).

zero_bytes(0, []) :- !.
zero_bytes(N, [0|Zeros]) :-
    N > 0,
    N1 is N - 1,
    zero_bytes(N1, Zeros).

asadb_pager_read_file_codes(File, Codes) :-
    setup_call_cleanup(
        open(File, read, Stream, [type(binary)]),
        read_pages(Stream, File, 0, Pages),
        close(Stream)
    ),
    append(Pages, Codes).

asadb_pager_write_file_codes(File, Codes) :-
    asadb_pager_invalidate_file(File),
    setup_call_cleanup(
        open(File, write, Stream, [type(binary)]),
        write_code_pages(Stream, File, 0, Codes),
        close(Stream)
    ).

asadb_pager_write_xor_file_codes(File, Prefix, Codes, Mask) :-
    asadb_pager_invalidate_file(File),
    setup_call_cleanup(
        open(File, write, Stream, [type(binary)]),
        ( format(Stream, '~s', [Prefix]),
          write_xor_code_pages(Stream, File, 0, Codes, Mask)
        ),
        close(Stream)
    ).

asadb_pager_stats(pager{page_size:PageSize, buffer_pool:BufferStats}) :-
    asadb_pager_page_size(PageSize),
    asadb_buffer_pool_stats(BufferStats).

read_pages(Stream, File, PageNo, Pages) :-
    (   asadb_buffer_pool_get(File, PageNo, Cached)
    ->  ( Cached == []
        ->  Pages = []
        ;   Pages = [Cached|Rest],
            Next is PageNo + 1,
            read_pages(Stream, File, Next, Rest)
        )
    ;   asadb_pager_page_size(PageSize),
        Offset is PageNo * PageSize,
        seek(Stream, Offset, bof, _),
        read_page_bytes(Stream, PageSize, Bytes),
        asadb_buffer_pool_put(File, PageNo, Bytes, clean),
        ( Bytes == []
        -> Pages = []
        ;  Pages = [Bytes|Rest],
           Next is PageNo + 1,
           read_pages(Stream, File, Next, Rest)
        )
    ).

write_code_pages(_, _, _, []) :- !.
write_code_pages(Stream, File, PageNo, Codes) :-
    asadb_pager_page_size(PageSize),
    take_at_most(PageSize, Codes, Page, Rest),
    format(Stream, '~s', [Page]),
    asadb_buffer_pool_put(File, PageNo, Page, clean),
    Next is PageNo + 1,
    write_code_pages(Stream, File, Next, Rest).

write_xor_code_pages(_, _, _, [], _) :- !.
write_xor_code_pages(Stream, File, PageNo, Codes, Mask) :-
    asadb_pager_page_size(PageSize),
    take_at_most(PageSize, Codes, SourcePage, Rest),
    xor_page(SourcePage, Mask, Page),
    format(Stream, '~s', [Page]),
    asadb_buffer_pool_put(File, PageNo, Page, clean),
    Next is PageNo + 1,
    write_xor_code_pages(Stream, File, Next, Rest, Mask).

xor_page([], _, []).
xor_page([Code|Codes], Mask, [Encoded|Page]) :-
    Encoded is (Code xor Mask) mod 256,
    xor_page(Codes, Mask, Page).

take_at_most(0, Rest, [], Rest) :- !.
take_at_most(_, [], [], []) :- !.
take_at_most(N, [Code|Codes], [Code|Taken], Rest) :-
    N > 0,
    N1 is N - 1,
    take_at_most(N1, Codes, Taken, Rest).

read_page_bytes(_, 0, []) :- !.
read_page_bytes(Stream, N, Bytes) :-
    get_byte(Stream, Byte),
    ( Byte == -1
    -> Bytes = []
    ;  N1 is N - 1,
       Bytes = [Byte|Rest],
       read_page_bytes(Stream, N1, Rest)
    ).
