% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- module(asadb_page_manager, [
    asadb_page_new/5,
    asadb_page_build/6,
    asadb_page_header/2,
    asadb_page_has_space/2,
    asadb_page_insert_record/4,
    asadb_page_read_record/3,
    asadb_page_replace_record/4,
    asadb_page_remove_slots/3,
    asadb_page_delete_record/3,
    asadb_page_records/2,
    asadb_page_set_siblings/4,
    asadb_page_validate/1
]).

:- use_module('asadb_config.pl').

page_magic([65,83,80,71]).       % ASPG
page_version(1).
page_header_size(32).
page_slot_size(4).
page_none(4294967295).

page_type_code(heap, 1).
page_type_code(btree_leaf, 2).
page_type_code(btree_internal, 3).
page_type_code(free, 4).

asadb_page_new(PageId, Type, Prev0, Next0, Page) :-
    asadb_page_build(PageId, Type, Prev0, Next0, [], Page).

asadb_page_build(PageId, Type, Prev0, Next0, Records, Page) :-
    maplist(record_bytes_valid, Records),
    page_type_code(Type, TypeCode),
    pointer_code(Prev0, Prev),
    pointer_code(Next0, Next),
    page_header_size(HeaderSize),
    asadb_config_get(page_size, PageSize),
    u32_bytes(PageId, PageIdBytes),
    length(Records, RecordCount),
    page_slot_size(SlotSize),
    FreeStart is HeaderSize + RecordCount * SlotSize,
    records_byte_length(Records, PayloadLength),
    FreeEnd is PageSize - PayloadLength,
    FreeStart =< FreeEnd,
    u16_bytes(RecordCount, LiveBytes),
    u16_bytes(FreeStart, FreeStartBytes),
    u16_bytes(FreeEnd, FreeEndBytes),
    u32_bytes(Prev, PrevBytes),
    u32_bytes(Next, NextBytes),
    append([[65,83,80,71,1,TypeCode,0,0], PageIdBytes, LiveBytes,
            FreeStartBytes, FreeEndBytes, PrevBytes, NextBytes,
            [0,0,0,0,0,0]], Header),
    length(Header, HeaderSize),
    build_slots(Records, PageSize, SlotBytes),
    GapLength is FreeEnd - FreeStart,
    zero_bytes(GapLength, Gap),
    reverse(Records, ReverseRecords),
    append(ReverseRecords, Payload),
    append([Header, SlotBytes, Gap, Payload], RawPage),
    length(RawPage, PageSize),
    finalize_page(RawPage, Page).

record_bytes_valid(Bytes) :- maplist(valid_byte, Bytes).

records_byte_length([], 0).
records_byte_length([Bytes|Records], Total) :-
    length(Bytes, Length),
    records_byte_length(Records, Rest),
    Total is Length + Rest.

build_slots(Records, PageSize, SlotBytes) :-
    build_slots_(Records, PageSize, _, SlotChunks),
    append(SlotChunks, SlotBytes).

build_slots_([], Offset, Offset, []).
build_slots_([Bytes|Records], Offset0, Offset, [Slot|Slots]) :-
    length(Bytes, Length),
    RecordOffset is Offset0 - Length,
    u16_bytes(RecordOffset, OffsetBytes),
    u16_bytes(Length, LengthBytes),
    append(OffsetBytes, LengthBytes, Slot),
    build_slots_(Records, RecordOffset, Offset, Slots).

asadb_page_header(Page, page_meta{
    page_id:PageId,
    page_type:Type,
    record_count:LiveCount,
    slot_count:SlotCount,
    free_start:FreeStart,
    free_end:FreeEnd,
    free_bytes:FreeBytes,
    previous_page:Prev,
    next_page:Next,
    checksum:Checksum
}) :-
    page_magic(Magic),
    prefix_bytes(Page, 0, 4, Magic),
    byte_at(Page, 4, Version),
    page_version(Version),
    byte_at(Page, 5, TypeCode),
    page_type_code(Type, TypeCode),
    read_u32(Page, 8, PageId),
    read_u16(Page, 12, LiveCount),
    read_u16(Page, 14, FreeStart),
    read_u16(Page, 16, FreeEnd),
    read_u32(Page, 18, PrevCode),
    read_u32(Page, 22, NextCode),
    read_u32(Page, 26, Checksum),
    page_header_size(HeaderSize),
    page_slot_size(SlotSize),
    SlotCount is (FreeStart - HeaderSize) // SlotSize,
    FreeBytes is FreeEnd - FreeStart,
    pointer_value(PrevCode, Prev),
    pointer_value(NextCode, Next).

asadb_page_has_space(Page, RecordBytes) :-
    length(RecordBytes, RecordLength),
    asadb_page_header(Page, Meta),
    page_slot_size(SlotSize),
    Needed is RecordLength + SlotSize,
    Meta.free_bytes >= Needed.

asadb_page_insert_record(Page0, RecordBytes, Page, SlotId) :-
    maplist(valid_byte, RecordBytes),
    asadb_page_has_space(Page0, RecordBytes),
    asadb_page_header(Page0, Meta),
    length(RecordBytes, RecordLength),
    SlotId = Meta.slot_count,
    PayloadOffset is Meta.free_end - RecordLength,
    replace_bytes(Page0, PayloadOffset, RecordBytes, Page1),
    u16_bytes(PayloadOffset, OffsetBytes),
    u16_bytes(RecordLength, LengthBytes),
    append(OffsetBytes, LengthBytes, SlotBytes),
    replace_bytes(Page1, Meta.free_start, SlotBytes, Page2),
    NewLive is Meta.record_count + 1,
    NewFreeStart is Meta.free_start + 4,
    set_u16(Page2, 12, NewLive, Page3),
    set_u16(Page3, 14, NewFreeStart, Page4),
    set_u16(Page4, 16, PayloadOffset, Page5),
    finalize_page(Page5, Page).

asadb_page_read_record(Page, SlotId, RecordBytes) :-
    asadb_page_header(Page, Meta),
    integer(SlotId), SlotId >= 0, SlotId < Meta.slot_count,
    page_header_size(HeaderSize),
    SlotOffset is HeaderSize + SlotId * 4,
    read_u16(Page, SlotOffset, RecordOffset),
    LengthOffset is SlotOffset + 2,
    read_u16(Page, LengthOffset, RecordLength),
    RecordLength > 0,
    prefix_bytes(Page, RecordOffset, RecordLength, RecordBytes).

asadb_page_delete_record(Page0, SlotId, Page) :-
    asadb_page_read_record(Page0, SlotId, _),
    asadb_page_header(Page0, Meta),
    page_header_size(HeaderSize),
    LengthOffset is HeaderSize + SlotId * 4 + 2,
    set_u16(Page0, LengthOffset, 0, Page1),
    NewLive is Meta.record_count - 1,
    set_u16(Page1, 12, NewLive, Page2),
    finalize_page(Page2, Page).

asadb_page_replace_record(Page0, SlotId, RecordBytes, Page) :-
    asadb_page_header(Page0, Meta),
    asadb_page_records(Page0, Records0),
    replace_slot_record(Records0, SlotId, RecordBytes, Records),
    pairs_values_page(Records, Payloads),
    asadb_page_build(Meta.page_id, Meta.page_type,
                     Meta.previous_page, Meta.next_page, Payloads, Page).

replace_slot_record([Slot-_|Records], Slot, Bytes, [Slot-Bytes|Records]) :- !.
replace_slot_record([Record|Records], Slot, Bytes, [Record|Out]) :-
    replace_slot_record(Records, Slot, Bytes, Out).

pairs_values_page([], []).
pairs_values_page([_-Value|Pairs], [Value|Values]) :-
    pairs_values_page(Pairs, Values).

asadb_page_remove_slots(Page0, Slots, Page) :-
    asadb_page_header(Page0, Meta),
    asadb_page_records(Page0, Records0),
    exclude(slot_selected(Slots), Records0, Records),
    pairs_values_page(Records, Payloads),
    asadb_page_build(Meta.page_id, Meta.page_type,
                     Meta.previous_page, Meta.next_page, Payloads, Page).

slot_selected(Slots, Slot-_) :- memberchk(Slot, Slots).

asadb_page_records(Page, Records) :-
    asadb_page_header(Page, Meta),
    page_slot_lengths(Page, 0, Meta.slot_count, Slots),
    compact_payload_records(Page, Meta, Slots, Records), !.
asadb_page_records(Page, Records) :-
    asadb_page_header(Page, Meta),
    collect_records(0, Meta.slot_count, Page, Records).

page_slot_lengths(_, Slot, Count, []) :- Slot >= Count, !.
page_slot_lengths(Page, Slot, Count, [Slot-Length|Slots]) :-
    page_header_size(HeaderSize),
    LengthOffset is HeaderSize + Slot * 4 + 2,
    read_u16(Page, LengthOffset, Length),
    Next is Slot + 1,
    page_slot_lengths(Page, Next, Count, Slots).

compact_payload_records(Page, Meta, Slots, Records) :-
    all_live_slots(Slots),
    slots_total_length(Slots, PayloadLength),
    asadb_config_get(page_size, PageSize),
    PayloadLength =:= PageSize - Meta.free_end,
    drop_bytes(Meta.free_end, Page, Payload),
    reverse(Slots, ReverseSlots),
    split_payload_records(ReverseSlots, Payload, ReverseRecords, []),
    reverse(ReverseRecords, Records).

all_live_slots([]).
all_live_slots([_-Length|Slots]) :- Length > 0, all_live_slots(Slots).

slots_total_length([], 0).
slots_total_length([_-Length|Slots], Total) :-
    slots_total_length(Slots, Rest),
    Total is Length + Rest.

split_payload_records([], Payload, [], Payload).
split_payload_records([Slot-Length|Slots], Payload0, [Slot-Bytes|Records], Rest) :-
    take_payload_bytes(Length, Payload0, Bytes, Payload),
    split_payload_records(Slots, Payload, Records, Rest).

take_payload_bytes(0, Bytes, [], Bytes) :- !.
take_payload_bytes(N, [Byte|Bytes], [Byte|Taken], Rest) :-
    N > 0,
    Next is N - 1,
    take_payload_bytes(Next, Bytes, Taken, Rest).

collect_records(Slot, Count, _, []) :- Slot >= Count, !.
collect_records(Slot, Count, Page, Records) :-
    Next is Slot + 1,
    ( asadb_page_read_record(Page, Slot, Bytes) ->
        Records = [Slot-Bytes|Rest]
    ; Records = Rest
    ),
    collect_records(Next, Count, Page, Rest).

asadb_page_set_siblings(Page0, Prev0, Next0, Page) :-
    pointer_code(Prev0, Prev),
    pointer_code(Next0, Next),
    set_u32(Page0, 18, Prev, Page1),
    set_u32(Page1, 22, Next, Page2),
    finalize_page(Page2, Page).

asadb_page_validate(Page) :-
    asadb_config_get(page_size, PageSize),
    length(Page, PageSize),
    asadb_page_header(Page, Meta),
    page_header_size(HeaderSize),
    Meta.free_start >= HeaderSize,
    Meta.free_end >= Meta.free_start,
    Meta.free_end =< PageSize,
    page_checksum(Page, Actual),
    Meta.checksum =:= Actual.

finalize_page(Page0, Page) :-
    set_u32(Page0, 26, 0, WithoutChecksum),
    page_checksum(WithoutChecksum, Checksum),
    set_u32(WithoutChecksum, 26, Checksum, Page).

page_checksum(Page, Checksum) :-
    zero_checksum_field(Page, Bytes),
    sum_list(Bytes, Total),
    Checksum is Total mod 4294967291.

zero_checksum_field(Page, Bytes) :-
    set_u32(Page, 26, 0, Bytes).

pointer_code(none, Code) :- !, page_none(Code).
pointer_code(Code, Code) :- integer(Code), Code >= 0.
pointer_value(Code, none) :- page_none(Code), !.
pointer_value(Code, Code).

valid_byte(Byte) :- integer(Byte), Byte >= 0, Byte =< 255.

byte_at(Bytes, Offset, Byte) :- nth0(Offset, Bytes, Byte).

prefix_bytes(Bytes, Offset, Length, Prefix) :-
    drop_bytes(Offset, Bytes, Tail),
    take_bytes(Length, Tail, Prefix).

drop_bytes(0, Bytes, Bytes) :- !.
drop_bytes(N, [_|Bytes], Tail) :- N > 0, N1 is N - 1, drop_bytes(N1, Bytes, Tail).

take_bytes(0, _, []) :- !.
take_bytes(N, [Byte|Bytes], [Byte|Prefix]) :- N > 0, N1 is N - 1, take_bytes(N1, Bytes, Prefix).

replace_bytes(Bytes, Offset, Replacement, Out) :-
    same_length(Replacement, Removed),
    append(Before, Rest, Bytes),
    length(Before, Offset),
    append(Removed, After, Rest), !,
    append([Before, Replacement, After], Out).

read_u16(Bytes, Offset, Value) :-
    byte_at(Bytes, Offset, A),
    Offset1 is Offset + 1,
    byte_at(Bytes, Offset1, B),
    Value is (A << 8) + B.

read_u32(Bytes, Offset, Value) :-
    byte_at(Bytes, Offset, A),
    Offset1 is Offset + 1, byte_at(Bytes, Offset1, B),
    Offset2 is Offset + 2, byte_at(Bytes, Offset2, C),
    Offset3 is Offset + 3, byte_at(Bytes, Offset3, D),
    Value is (A << 24) + (B << 16) + (C << 8) + D.

set_u16(Bytes, Offset, Value, Out) :-
    u16_bytes(Value, Encoded),
    replace_bytes(Bytes, Offset, Encoded, Out).

set_u32(Bytes, Offset, Value, Out) :-
    u32_bytes(Value, Encoded),
    replace_bytes(Bytes, Offset, Encoded, Out).

u16_bytes(Value, [A,B]) :-
    A is (Value >> 8) /\ 255,
    B is Value /\ 255.

u32_bytes(Value, [A,B,C,D]) :-
    A is (Value >> 24) /\ 255,
    B is (Value >> 16) /\ 255,
    C is (Value >> 8) /\ 255,
    D is Value /\ 255.

zero_bytes(0, []) :- !.
zero_bytes(N, [0|Bytes]) :- N > 0, N1 is N - 1, zero_bytes(N1, Bytes).
