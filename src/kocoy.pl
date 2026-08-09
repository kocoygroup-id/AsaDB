% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  AsaDB Native Storage Accelerator
  --------------------------------

  This module keeps the physical sequential-read path in SWI-Prolog native
  stream primitives.  A scan obtains several fixed pages in one read_string/3
  call, then exposes them one page at a time to the existing checksum/page
  format layer.  It does not change the on-disk format, SQL semantics, or the
  buffer-pool contract.

  The name is intentionally separate from the logical query JIT: this is the
  storage boundary used by full table scans, exports, and index construction.
*/

:- module(asadb_kocoy, [
    asadb_kocoy_reset/0,
    asadb_kocoy_scan_pages/5,
    asadb_kocoy_stats/1
]).

:- use_module('asadb_buffer_pool.pl').

% 64 pages keeps each native read bounded to 256 KiB at the default 4 KiB
% page size.  That is large enough to reduce Prolog-to-stream calls during a
% cold scan, without retaining a large import/export result in memory.
kocoy_pages_per_read(64).

asadb_kocoy_reset :-
    flag(asadb_kocoy_scan_batches, _, 0),
    flag(asadb_kocoy_scanned_pages, _, 0),
    flag(asadb_kocoy_scanned_bytes, _, 0).

asadb_kocoy_stats(native_storage{
    implementation:'swi_prolog_native_stream_batches',
    pages_per_read:PagesPerRead,
    scan_batches:Batches,
    scanned_pages:Pages,
    scanned_bytes:Bytes
}) :-
    kocoy_pages_per_read(PagesPerRead),
    flag(asadb_kocoy_scan_batches, Batches, Batches),
    flag(asadb_kocoy_scanned_pages, Pages, Pages),
    flag(asadb_kocoy_scanned_bytes, Bytes, Bytes).

% Enumerate pages in storage order.  Cached pages always win, preserving
% read-your-own-write semantics for dirty pages while the uncached run is read
% through one native buffered stream.
asadb_kocoy_scan_pages(File, PageCount, PageSize, PageNo, Bytes) :-
    integer(PageCount),
    PageCount > 0,
    integer(PageSize),
    PageSize > 0,
    kocoy_disk_page_count(File, PageSize, DiskPages),
    LastDiskPage is DiskPages - 1,
    LastPage is PageCount - 1,
    ( DiskPages > 0,
      setup_call_cleanup(
          open(File, read, Stream, [type(binary), buffer_size(1048576)]),
          kocoy_scan_disk(Stream, File, PageSize, 0, LastDiskPage,
                           PageNo, Bytes),
          close(Stream)
      )
    ; DiskPages =:= 0,
      kocoy_scan_cached_tail(File, 0, LastPage, PageNo, Bytes)
    ; DiskPages > 0,
      kocoy_scan_cached_tail(File, DiskPages, LastPage, PageNo, Bytes)
    ).

kocoy_disk_page_count(File, PageSize, Count) :-
    ( exists_file(File) -> size_file(File, Size) ; Size = 0 ),
    Count is (Size + PageSize - 1) // PageSize.

kocoy_scan_disk(Stream, File, PageSize, FirstPage, LastPage, PageNo, Bytes) :-
    FirstPage =< LastPage,
    kocoy_pages_per_read(PagesPerRead),
    Remaining is LastPage - FirstPage + 1,
    BatchPages is min(PagesPerRead, Remaining),
    BatchBytes is BatchPages * PageSize,
    read_string(Stream, BatchBytes, Chunk),
    string_length(Chunk, ChunkLength),
    ChunkLength > 0,
    ActualPages is (ChunkLength + PageSize - 1) // PageSize,
    note_kocoy_batch(ActualPages, ChunkLength),
    ( kocoy_chunk_page(Chunk, File, PageSize, FirstPage, ActualPages,
                        PageNo, Bytes)
    ; NextPage is FirstPage + ActualPages,
      kocoy_scan_disk(Stream, File, PageSize, NextPage, LastPage,
                      PageNo, Bytes)
    ).

kocoy_chunk_page(Chunk, File, PageSize, FirstPage, ActualPages,
                 PageNo, Bytes) :-
    LastOffset is ActualPages - 1,
    between(0, LastOffset, OffsetPages),
    PageNo is FirstPage + OffsetPages,
    ( asadb_buffer_pool_get(File, PageNo, Bytes) -> true
    ; StringOffset is OffsetPages * PageSize,
      string_length(Chunk, ChunkLength),
      Available is ChunkLength - StringOffset,
      PageLength is min(PageSize, Available),
      sub_string(Chunk, StringOffset, PageLength, _, PageString),
      string_codes(PageString, Bytes)
    ).

kocoy_scan_cached_tail(_, FirstPage, LastPage, _, _) :-
    FirstPage > LastPage, !, fail.
kocoy_scan_cached_tail(File, FirstPage, LastPage, PageNo, Bytes) :-
    between(FirstPage, LastPage, PageNo),
    asadb_buffer_pool_get(File, PageNo, Bytes).

note_kocoy_batch(Pages, Bytes) :-
    flag(asadb_kocoy_scan_batches, Batches0, Batches0),
    Batches is Batches0 + 1,
    flag(asadb_kocoy_scan_batches, _, Batches),
    flag(asadb_kocoy_scanned_pages, Pages0, Pages0),
    TotalPages is Pages0 + Pages,
    flag(asadb_kocoy_scanned_pages, _, TotalPages),
    flag(asadb_kocoy_scanned_bytes, Bytes0, Bytes0),
    TotalBytes is Bytes0 + Bytes,
    flag(asadb_kocoy_scanned_bytes, _, TotalBytes).
