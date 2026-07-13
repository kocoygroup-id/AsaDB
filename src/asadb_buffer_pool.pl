% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- module(asadb_buffer_pool, [
    asadb_buffer_pool_reset/0,
    asadb_buffer_pool_get/3,
    asadb_buffer_pool_put/4,
    asadb_buffer_pool_pin/4,
    asadb_buffer_pool_unpin/3,
    asadb_buffer_pool_mark_dirty/2,
    asadb_buffer_pool_invalidate_file/1,
    asadb_buffer_pool_flush_page/2,
    asadb_buffer_pool_flush_all/0,
    asadb_buffer_pool_stats/1
]).

:- use_module('asadb_config.pl').

:- meta_predicate asadb_buffer_pool_pin(+, +, 1, -).

:- dynamic buffer_page/8.
:- dynamic buffer_tick/1.
:- dynamic buffer_stat/2.
:- dynamic buffer_write_count/1.

% buffer_page(File, PageNo, Bytes, Dirty, Pins, Referenced, Tick, ByteCount).

asadb_buffer_pool_reset :-
    with_mutex(asadb_buffer_pool,
        ( flush_all_locked,
          retractall(buffer_page(_, _, _, _, _, _, _, _)),
          retractall(buffer_tick(_)),
          retractall(buffer_stat(_, _)),
          retractall(buffer_write_count(_)),
          assertz(buffer_tick(0)),
          assertz(buffer_write_count(0)),
          init_stats
        )).

init_stats :-
    forall(member(Name, [hit,miss,eviction,flush,pin,unpin]),
           assertz(buffer_stat(Name, 0))).

asadb_buffer_pool_get(File, PageNo, Bytes) :-
    with_mutex(asadb_buffer_pool, get_locked(File, PageNo, Bytes)).

get_locked(File, PageNo, Bytes) :-
    buffer_page(File, PageNo, Bytes0, Dirty, Pins, _, _, Size), !,
    next_tick(Tick),
    retractall(buffer_page(File, PageNo, _, _, _, _, _, _)),
    assertz(buffer_page(File, PageNo, Bytes0, Dirty, Pins, true, Tick, Size)),
    bump_stat(hit),
    Bytes = Bytes0.
get_locked(_, _, _) :-
    bump_stat(miss),
    fail.

asadb_buffer_pool_put(File, PageNo, Bytes, Dirty0) :-
    normalize_dirty(Dirty0, Dirty),
    with_mutex(asadb_buffer_pool,
        put_locked(File, PageNo, Bytes, Dirty, 0)).

put_locked(File, PageNo, Bytes, Dirty, Pins) :-
    next_tick(Tick),
    length(Bytes, Size),
    retractall(buffer_page(File, PageNo, _, _, _, _, _, _)),
    assertz(buffer_page(File, PageNo, Bytes, Dirty, Pins, true, Tick, Size)),
    note_write(Dirty),
    evict_if_needed.

asadb_buffer_pool_pin(File, PageNo, Loader, Bytes) :-
    with_mutex(asadb_buffer_pool,
        pin_locked(File, PageNo, Loader, Bytes)).

pin_locked(File, PageNo, _, Bytes) :-
    buffer_page(File, PageNo, Bytes0, Dirty, Pins0, _, _, Size), !,
    Pins is Pins0 + 1,
    next_tick(Tick),
    retractall(buffer_page(File, PageNo, _, _, _, _, _, _)),
    assertz(buffer_page(File, PageNo, Bytes0, Dirty, Pins, true, Tick, Size)),
    bump_stat(hit),
    bump_stat(pin),
    Bytes = Bytes0.
pin_locked(File, PageNo, Loader, Bytes) :-
    bump_stat(miss),
    call(Loader, Bytes),
    put_locked(File, PageNo, Bytes, clean, 1),
    bump_stat(pin).

asadb_buffer_pool_unpin(File, PageNo, Dirty0) :-
    normalize_dirty(Dirty0, DirtyRequest),
    with_mutex(asadb_buffer_pool,
        unpin_locked(File, PageNo, DirtyRequest)).

unpin_locked(File, PageNo, DirtyRequest) :-
    retract(buffer_page(File, PageNo, Bytes, Dirty0, Pins0, Ref, Tick, Size)), !,
    Pins is max(0, Pins0 - 1),
    merge_dirty(Dirty0, DirtyRequest, Dirty),
    assertz(buffer_page(File, PageNo, Bytes, Dirty, Pins, Ref, Tick, Size)),
    note_write(DirtyRequest),
    bump_stat(unpin),
    evict_if_needed.
unpin_locked(_, _, _).

asadb_buffer_pool_mark_dirty(File, PageNo) :-
    with_mutex(asadb_buffer_pool,
        ( retract(buffer_page(File, PageNo, Bytes, _, Pins, Ref, Tick, Size)),
          assertz(buffer_page(File, PageNo, Bytes, dirty, Pins, Ref, Tick, Size)),
          note_write(dirty)
        )).

asadb_buffer_pool_invalidate_file(File) :-
    with_mutex(asadb_buffer_pool,
        ( findall(PageNo,
                  buffer_page(File, PageNo, _, dirty, _, _, _, _),
                  DirtyPages),
          flush_file_pages(File, DirtyPages),
          retractall(buffer_page(File, _, _, _, _, _, _, _))
        )).

flush_file_pages(_, []).
flush_file_pages(File, [PageNo|Pages]) :-
    flush_page_locked(File, PageNo),
    flush_file_pages(File, Pages).

asadb_buffer_pool_flush_page(File, PageNo) :-
    with_mutex(asadb_buffer_pool, flush_page_locked(File, PageNo)).

flush_page_locked(File, PageNo) :-
    buffer_page(File, PageNo, Bytes, dirty, Pins, Ref, Tick, Size), !,
    write_page_bytes(File, PageNo, Bytes),
    retractall(buffer_page(File, PageNo, _, _, _, _, _, _)),
    assertz(buffer_page(File, PageNo, Bytes, clean, Pins, Ref, Tick, Size)),
    bump_stat(flush).
flush_page_locked(_, _).

asadb_buffer_pool_flush_all :-
    with_mutex(asadb_buffer_pool, flush_all_locked).

flush_all_locked :-
    findall(File-PageNo,
            buffer_page(File, PageNo, _, dirty, _, _, _, _),
            DirtyPages),
    flush_page_pairs(DirtyPages).

flush_page_pairs([]).
flush_page_pairs([File-PageNo|Pages]) :-
    flush_page_locked(File, PageNo),
    flush_page_pairs(Pages).

asadb_buffer_pool_stats(buffer_pool{
    hits:Hits,
    misses:Misses,
    pages:Pages,
    pinned_pages:PinnedPages,
    dirty_pages:DirtyPages,
    evictions:Evictions,
    flushes:Flushes,
    bytes:Bytes,
    limit_pages:Limit,
    limit_bytes:LimitBytes,
    policy:Policy
}) :-
    with_mutex(asadb_buffer_pool,
        stats_locked(Hits, Misses, Pages, PinnedPages, DirtyPages,
                     Evictions, Flushes, Bytes, Limit, LimitBytes, Policy)).

stats_locked(Hits, Misses, Pages, PinnedPages, DirtyPages,
             Evictions, Flushes, Bytes, Limit, LimitBytes, Policy) :-
    stat_value(hit, Hits),
    stat_value(miss, Misses),
    stat_value(eviction, Evictions),
    stat_value(flush, Flushes),
    aggregate_all(count, buffer_page(_, _, _, _, _, _, _, _), Pages),
    aggregate_all(count,
                  ( buffer_page(_, _, _, _, Pins, _, _, _), Pins > 0 ),
                  PinnedPages),
    aggregate_all(count, buffer_page(_, _, _, dirty, _, _, _, _), DirtyPages),
    aggregate_all(sum(Size), buffer_page(_, _, _, _, _, _, _, Size), Bytes0),
    ( var(Bytes0) -> Bytes = 0 ; Bytes = Bytes0 ),
    asadb_config_get(buffer_pool_pages, Limit),
    asadb_config_get(page_size, PageSize),
    LimitBytes is Limit * PageSize,
    asadb_config_get(cache_policy, Policy).

normalize_dirty(dirty, dirty) :- !.
normalize_dirty(true, dirty) :- !.
normalize_dirty(_, clean).

merge_dirty(dirty, _, dirty) :- !.
merge_dirty(_, dirty, dirty) :- !.
merge_dirty(_, _, clean).

next_tick(Tick) :-
    ( retract(buffer_tick(Current)) -> true ; Current = 0 ),
    Tick is Current + 1,
    assertz(buffer_tick(Tick)).

bump_stat(Name) :-
    ( retract(buffer_stat(Name, Current)) -> true ; Current = 0 ),
    Next is Current + 1,
    assertz(buffer_stat(Name, Next)).

stat_value(Name, Value) :- buffer_stat(Name, Value), !.
stat_value(_, 0).

note_write(clean) :- !.
note_write(dirty) :-
    ( retract(buffer_write_count(Current)) -> true ; Current = 0 ),
    Next is Current + 1,
    assertz(buffer_write_count(Next)),
    asadb_config_get(flush_interval, Interval),
    ( 0 is Next mod Interval -> flush_one_dirty_unpinned ; true ).

evict_if_needed :-
    asadb_config_get(buffer_pool_pages, Limit),
    aggregate_all(count, buffer_page(_, _, _, _, _, _, _, _), Count),
    ( Count =< Limit -> true
    ; evict_one -> evict_if_needed
    ; true
    ).

evict_one :-
    asadb_config_get(cache_policy, Policy),
    eviction_candidate(Policy, File, PageNo), !,
    ( buffer_page(File, PageNo, _, dirty, _, _, _, _) -> flush_page_locked(File, PageNo) ; true ),
    retractall(buffer_page(File, PageNo, _, _, _, _, _, _)),
    bump_stat(eviction).

eviction_candidate(clock, File, PageNo) :-
    buffer_page(File, PageNo, _, _, 0, false, Tick, _),
    \+ ( buffer_page(_, _, _, _, 0, false, Earlier, _), Earlier < Tick ), !.
eviction_candidate(clock, File, PageNo) :-
    clear_unpinned_reference_bits,
    buffer_page(File, PageNo, _, _, 0, false, Tick, _),
    \+ ( buffer_page(_, _, _, _, 0, false, Earlier, _), Earlier < Tick ), !.
eviction_candidate(_, File, PageNo) :-
    buffer_page(File, PageNo, _, _, 0, _, Tick, _),
    \+ ( buffer_page(_, _, _, _, 0, _, Earlier, _), Earlier < Tick ).

clear_unpinned_reference_bits :-
    findall(page(File, PageNo, Bytes, Dirty, Tick, Size),
            buffer_page(File, PageNo, Bytes, Dirty, 0, true, Tick, Size),
            Pages),
    clear_reference_pages(Pages).

clear_reference_pages([]).
clear_reference_pages([page(File, PageNo, Bytes, Dirty, Tick, Size)|Pages]) :-
    retractall(buffer_page(File, PageNo, _, _, _, _, _, _)),
    assertz(buffer_page(File, PageNo, Bytes, Dirty, 0, false, Tick, Size)),
    clear_reference_pages(Pages).

flush_one_dirty_unpinned :-
    buffer_page(File, PageNo, _, dirty, 0, _, Tick, _),
    \+ ( buffer_page(_, _, _, dirty, 0, _, Earlier, _), Earlier < Tick ), !,
    flush_page_locked(File, PageNo).
flush_one_dirty_unpinned.

write_page_bytes(File, PageNo, Bytes) :-
    ensure_page_file(File),
    asadb_config_get(page_size, PageSize),
    Offset is PageNo * PageSize,
    setup_call_cleanup(
        open(File, update, Stream, [type(binary)]),
        ( seek(Stream, Offset, bof, _),
          format(Stream, '~s', [Bytes]),
          flush_output(Stream)
        ),
        close(Stream)
    ).

ensure_page_file(File) :- exists_file(File), !.
ensure_page_file(File) :-
    file_directory_name(File, Dir),
    ensure_directory(Dir),
    setup_call_cleanup(open(File, write, Stream, [type(binary)]), true, close(Stream)).

ensure_directory('.') :- !.
ensure_directory('') :- !.
ensure_directory(Dir) :- exists_directory(Dir), !.
ensure_directory(Dir) :-
    file_directory_name(Dir, Parent),
    ensure_directory(Parent),
    make_directory(Dir).

:- initialization(asadb_buffer_pool_reset).
