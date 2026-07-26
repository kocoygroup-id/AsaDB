% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  AsaDB Prolog JIT support
  ------------------------
  SWI-Prolog compiles asserted clauses to VM code and adds clause indexes
  lazily through JITI.  This module supplies two bounded specialization steps:

  1. small/repeated SQL text is parsed once and its immutable AST is cached;
  2. safe logical ASTs are translated to clause bodies which asadb_core can
     assert behind an integer plan id, allowing SWI's JITI to index hot plans.

  No SQL text is ever consulted or called as Prolog source.
*/

:- module(asadb_prolog_jit, [
    asadb_jit_parse/3,
    asadb_jit_filter_body/3,
    asadb_jit_reset/0,
    asadb_jit_stats/1
]).

:- meta_predicate asadb_jit_parse(+, 2, -).

:- dynamic sql_plan_cache/4.
:- dynamic sql_plan_tick/1.

sql_cache_max_entries(128).
sql_cache_max_chars(32768).

asadb_jit_reset :-
    with_mutex(asadb_prolog_jit,
        ( retractall(sql_plan_cache(_, _, _, _)),
          retractall(sql_plan_tick(_)),
          assertz(sql_plan_tick(0)),
          flag(asadb_jit_parse_hits, _, 0),
          flag(asadb_jit_parse_misses, _, 0)
        )).

asadb_jit_parse(SQL, Parser, Statements) :-
    cacheable_sql_string(SQL, Text), !,
    term_hash(Text, Hash),
    ( with_mutex(asadb_prolog_jit,
                 jit_cached_plan(Hash, Text, Statements)) ->
        true
    ; call(Parser, SQL, ParsedStatements),
      ground(ParsedStatements),
      with_mutex(asadb_prolog_jit,
          jit_store_plan(Hash, Text, ParsedStatements, Statements))
    ).
asadb_jit_parse(SQL, Parser, Statements) :-
    call(Parser, SQL, Statements).

jit_cached_plan(Hash, Text, Statements) :-
    sql_plan_cache(Hash, CachedText, CachedStatements, _),
    Text == CachedText, !,
    increment_flag(asadb_jit_parse_hits),
    Statements = CachedStatements.
jit_cached_plan(_, _, _) :-
    increment_flag(asadb_jit_parse_misses),
    fail.

% Parsing happens outside the cache mutex so unrelated first-seen SQL from
% concurrent clients does not serialize behind the parser. A racing thread may
% finish the same parse first; in that case reuse its ground plan and discard
% this equivalent result.
jit_store_plan(Hash, Text, _, Statements) :-
    sql_plan_cache(Hash, CachedText, CachedStatements, _),
    Text == CachedText, !,
    Statements = CachedStatements.
jit_store_plan(Hash, Text, ParsedStatements, ParsedStatements) :-
    next_sql_plan_tick(Tick),
    assertz(sql_plan_cache(Hash, Text, ParsedStatements, Tick)),
    trim_sql_plan_cache.

cacheable_sql_string(SQL, Text) :-
    string(SQL), !,
    string_length(SQL, Length),
    sql_cache_max_chars(Max),
    Length =< Max,
    Text = SQL.
cacheable_sql_string(SQL, Text) :-
    atom(SQL), !,
    atom_length(SQL, Length),
    sql_cache_max_chars(Max),
    Length =< Max,
    atom_string(SQL, Text).

next_sql_plan_tick(Tick) :-
    ( retract(sql_plan_tick(Tick0)) -> true ; Tick0 = 0 ),
    Tick is Tick0 + 1,
    assertz(sql_plan_tick(Tick)).

trim_sql_plan_cache :-
    aggregate_all(count, sql_plan_cache(_, _, _, _), Count),
    sql_cache_max_entries(Max),
    ( Count =< Max -> true
    ; findall(Tick-cache(Hash, Text, Statements),
              sql_plan_cache(Hash, Text, Statements, Tick),
              Entries),
      keysort(Entries, [_-cache(OldHash, OldText, OldStatements)|_]),
      retract(sql_plan_cache(OldHash, OldText, OldStatements, _))
    ).

increment_flag(Name) :-
    flag(Name, Old, Old),
    New is Old + 1,
    flag(Name, _, New).

asadb_jit_stats(Stats) :-
    with_mutex(asadb_prolog_jit, asadb_jit_stats_locked(Stats)).

asadb_jit_stats_locked(jit{
    sql_cache_entries:Entries,
    sql_cache_limit:Limit,
    parse_hits:Hits,
    parse_misses:Misses
}) :-
    aggregate_all(count, sql_plan_cache(_, _, _, _), Entries),
    sql_cache_max_entries(Limit),
    flag(asadb_jit_parse_hits, Hits, Hits),
    flag(asadb_jit_parse_misses, Misses, Misses).

% Compile a safe boolean expression to a Prolog clause body. The resulting
% body only calls predicates owned by asadb_core; unsupported expressions
% simply fail compilation and stay on the interpreter path.
asadb_jit_filter_body(Expression, Row, Body) :-
    ground(Expression),
    jit_bool(Expression, Row, Body).

jit_bool(true, _, true) :- !.
jit_bool(and(A, B), Row, (BodyA, BodyB)) :- !,
    jit_bool(A, Row, BodyA),
    jit_bool(B, Row, BodyB).
jit_bool(or(A, B), Row, (BodyA ; BodyB)) :- !,
    jit_bool(A, Row, BodyA),
    jit_bool(B, Row, BodyB).
jit_bool(xor(A, B), Row,
         ((BodyA, \+ BodyB) ; (\+ BodyA, BodyB))) :- !,
    jit_bool(A, Row, BodyA),
    jit_bool(B, Row, BodyB).
jit_bool(not(A), Row, \+ Body) :- !,
    jit_bool(A, Row, Body).
jit_bool(cmp(Op, A, B), Row,
         (BodyA, BodyB, compare_value(Op, ValueA, ValueB))) :- !,
    jit_value(A, Row, ValueA, BodyA),
    jit_value(B, Row, ValueB, BodyB).
jit_bool(is_null(A), Row, (Body, Value == null)) :- !,
    jit_value(A, Row, Value, Body).
jit_bool(is_not_null(A), Row, (Body, Value \== null)) :- !,
    jit_value(A, Row, Value, Body).
jit_bool(is_true(A), Row, (Body, truthy(Value))) :- !,
    jit_value(A, Row, Value, Body).
jit_bool(is_false(A), Row,
         (Body, Value \== null, \+ truthy(Value))) :- !,
    jit_value(A, Row, Value, Body).
jit_bool(is_unknown(A), Row, (Body, Value == null)) :- !,
    jit_value(A, Row, Value, Body).
jit_bool(like(A, B), Row,
         (BodyA, BodyB, like_value(ValueA, ValueB))) :- !,
    jit_value(A, Row, ValueA, BodyA),
    jit_value(B, Row, ValueB, BodyB).
jit_bool(between(A, Low, High), Row,
         (BodyA, BodyLow, BodyHigh,
          compare_value('>=', Value, LowValue),
          compare_value('<=', Value, HighValue))) :- !,
    jit_value(A, Row, Value, BodyA),
    jit_value(Low, Row, LowValue, BodyLow),
    jit_value(High, Row, HighValue, BodyHigh).
jit_bool(in_list(A, Values), Row,
         (BodyA, member_expr_value(Row, Value, Values))) :- !,
    ground(Values),
    jit_value(A, Row, Value, BodyA).

jit_value(value(Value), _, Value, true) :- !.
jit_value(col(Name), Row, Value,
          (Row = row(Pairs), lookup_value(Name, Pairs, Value))) :- !.
jit_value(qcol(Qualifier, Name), Row, Value,
          eval_expr(Row, qcol(Qualifier, Name), Value)) :- !.
jit_value(add(A, B), Row, Value,
          (BodyA, BodyB, number(ValueA), number(ValueB),
           Value is ValueA + ValueB)) :- !,
    jit_value(A, Row, ValueA, BodyA),
    jit_value(B, Row, ValueB, BodyB).
jit_value(sub(A, B), Row, Value,
          (BodyA, BodyB, number(ValueA), number(ValueB),
           Value is ValueA - ValueB)) :- !,
    jit_value(A, Row, ValueA, BodyA),
    jit_value(B, Row, ValueB, BodyB).
jit_value(mul(A, B), Row, Value,
          (BodyA, BodyB, number(ValueA), number(ValueB),
           Value is ValueA * ValueB)) :- !,
    jit_value(A, Row, ValueA, BodyA),
    jit_value(B, Row, ValueB, BodyB).
jit_value(div(A, B), Row, Value,
          (BodyA, BodyB, number(ValueA), number(ValueB), ValueB =\= 0,
           Value is ValueA / ValueB)) :- !,
    jit_value(A, Row, ValueA, BodyA),
    jit_value(B, Row, ValueB, BodyB).
jit_value(neg(A), Row, Value,
          (Body, number(Input), Value is -Input)) :- !,
    jit_value(A, Row, Input, Body).
jit_value(Expression, Row, Value, eval_expr(Row, Expression, Value)) :-
    jit_safe_fallback_value(Expression).

jit_safe_fallback_value(func(lower, [_])).
jit_safe_fallback_value(func(upper, [_])).
jit_safe_fallback_value(func(length, [_])).
jit_safe_fallback_value(func(concat, _)).
jit_safe_fallback_value(func(substr, _)).
jit_safe_fallback_value(func(substring, _)).
jit_safe_fallback_value(func(trim, [_])).
jit_safe_fallback_value(func(replace, [_,_,_])).
jit_safe_fallback_value(func(coalesce, _)).
jit_safe_fallback_value(case(_, _)).
