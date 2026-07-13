% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- module(asadb_config, [
    asadb_config_get/2,
    asadb_config_set/2,
    asadb_config_reset/0,
    asadb_config_load/1,
    asadb_config_snapshot/1
]).

:- use_module(library(readutil)).

:- dynamic config_value/2.

config_default(page_size, 4096).
config_default(buffer_pool_pages, 64).
config_default(import_batch_size, 8).
config_default(flush_interval, 32).
config_default(max_result_rows, 500).
config_default(cache_policy, clock).

asadb_config_get(Name, Value) :-
    config_value(Name, Value), !.
asadb_config_get(Name, Value) :-
    config_default(Name, Value).

asadb_config_set(page_size, 4096) :- !,
    set_config_value(page_size, 4096).
asadb_config_set(page_size, Value) :- !,
    throw(error(domain_error(asadb_page_size, Value), _)).
asadb_config_set(Name, Value) :-
    valid_config(Name, Value), !,
    set_config_value(Name, Value).
asadb_config_set(Name, Value) :-
    throw(error(domain_error(asadb_config(Name), Value), _)).

set_config_value(Name, Value) :-
    retractall(config_value(Name, _)),
    assertz(config_value(Name, Value)).

valid_config(buffer_pool_pages, Value) :- integer(Value), Value >= 8.
valid_config(import_batch_size, Value) :- integer(Value), Value >= 1.
valid_config(flush_interval, Value) :- integer(Value), Value >= 1.
valid_config(max_result_rows, Value) :- integer(Value), Value >= 1.
valid_config(cache_policy, clock).
valid_config(cache_policy, lru).

asadb_config_reset :-
    retractall(config_value(_, _)).

asadb_config_load(File) :-
    ( exists_file(File) ->
        setup_call_cleanup(open(File, read, Stream, [encoding(utf8)]),
                           load_config_stream(Stream),
                           close(Stream))
    ; true
    ).

load_config_stream(Stream) :-
    read_line_to_string(Stream, Line),
    ( Line == end_of_file -> true
    ; load_config_line(Line),
      load_config_stream(Stream)
    ).

load_config_line(Line0) :-
    normalize_space(string(Line), Line0),
    ( Line == "" -> true
    ; sub_string(Line, 0, 1, _, "#") -> true
    ; split_string(Line, "=", " \t", Parts),
      Parts = [NameText, ValueText],
      atom_string(Name, NameText),
      config_text_value(Name, ValueText, Value),
      asadb_config_set(Name, Value)
    ), !.
load_config_line(Line) :-
    throw(error(syntax_error(asadb_config_line(Line)), _)).

config_text_value(cache_policy, Text, Value) :- !, atom_string(Value, Text).
config_text_value(_, Text, Value) :- number_string(Value, Text), integer(Value).

asadb_config_snapshot(config{
    page_size:PageSize,
    buffer_pool_pages:BufferPages,
    import_batch_size:ImportBatch,
    flush_interval:FlushInterval,
    max_result_rows:MaxRows,
    cache_policy:CachePolicy
}) :-
    asadb_config_get(page_size, PageSize),
    asadb_config_get(buffer_pool_pages, BufferPages),
    asadb_config_get(import_batch_size, ImportBatch),
    asadb_config_get(flush_interval, FlushInterval),
    asadb_config_get(max_result_rows, MaxRows),
    asadb_config_get(cache_policy, CachePolicy).
