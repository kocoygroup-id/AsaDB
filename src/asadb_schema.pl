% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  AsaDB schema integrity rules.

  This module deliberately validates values after DEFAULT/AUTO_INCREMENT
  expansion and before a record-store mutation.  Keeping the contract here
  prevents INSERT and UPDATE paths from drifting as storage implementations
  evolve.
*/

:- module(asadb_schema, [
    asadb_schema_validate_insert_shape/3,
    asadb_schema_validate_insert_rows/4,
    asadb_schema_validate_replacement_rows/3,
    asadb_schema_validate_assignment_columns/2
]).

:- use_module(library(lists)).

asadb_schema_validate_insert_shape(Columns, InputColumns, ValueRows) :-
    validate_input_columns(InputColumns, Columns),
    length(InputColumns, Expected),
    forall(member(Values, ValueRows),
           validate_value_arity(Expected, Values)).

asadb_schema_validate_insert_rows(Columns, Indexes, ExistingRows, NewRows) :-
    validate_rows(Columns, NewRows),
    append(ExistingRows, NewRows, AllRows),
    validate_unique_indexes(Indexes, AllRows).

asadb_schema_validate_replacement_rows(Columns, Indexes, Rows) :-
    validate_rows(Columns, Rows),
    validate_unique_indexes(Indexes, Rows).

asadb_schema_validate_assignment_columns(_, []).
asadb_schema_validate_assignment_columns(Columns, [assign(Name, _)|Assignments]) :-
    ( column_named(Name, Columns) -> true
    ; throw(error(existence_error(column, Name), _))
    ),
    asadb_schema_validate_assignment_columns(Columns, Assignments).

validate_input_columns([], _).
validate_input_columns([Name|Names], Columns) :-
    ( column_named(Name, Columns) -> true
    ; throw(error(existence_error(column, Name), _))
    ),
    ( identifier_member(Name, Names) ->
        throw(error(permission_error(use, duplicate_column, Name), _))
    ; true
    ),
    validate_input_columns(Names, Columns).

validate_value_arity(Expected, Values) :-
    length(Values, Actual),
    ( Actual =:= Expected -> true
    ; throw(error(domain_error(insert_value_count(Expected), Actual), _))
    ).

% Types are part of a table schema, not of an individual value.  Compile the
% small column signature vector once per validation unit so a 1,000-row INSERT
% does not repeatedly normalize the same `VARCHAR(150)` atom thousands of
% times.  This is deliberately local to the call: schema changes cannot leave
% a stale global type cache behind.
validate_rows(Columns, Rows) :-
    compile_column_signatures(Columns, CompiledColumns),
    maplist(validate_compiled_row(CompiledColumns), Rows).

compile_column_signatures([], []).
compile_column_signatures([col(Name, Type, Options)|Columns],
                          [compiled_col(Name, Type, Options, Signature)|Compiled]) :-
    type_signature(Type, TypeName, Arguments),
    Signature = type_signature(TypeName, Arguments),
    compile_column_signatures(Columns, Compiled).

validate_compiled_row([], _).
validate_compiled_row([compiled_col(Name, Type, Options, Signature)|Columns], row(Pairs)) :-
    ( lookup_value(Name, Pairs, Value) -> true ; Value = null ),
    validate_compiled_column_value(Name, Type, Options, Signature, Value),
    validate_compiled_row(Columns, row(Pairs)).

validate_compiled_column_value(Name, _Type, Options, _, null) :-
    ( memberchk(not_null, Options) ; memberchk(primary_key, Options) ), !,
    throw(error(existence_error(non_null_value, Name), _)).
validate_compiled_column_value(_, _, _, _, null) :- !.
validate_compiled_column_value(Name, Type, _Options,
                               type_signature(TypeName, Arguments), Value) :-
    ( type_accepts(TypeName, Arguments, Value) -> true
    ; throw(error(domain_error(sql_type(Name, Type), Value), _))
    ).

% Retained for internal callers that validate one ad-hoc value.  INSERT and
% replacement validation use the precompiled path above.
validate_row([], _).
validate_row([col(Name, Type, Options)|Columns], row(Pairs)) :-
    ( lookup_value(Name, Pairs, Value) -> true ; Value = null ),
    validate_column_value(Name, Type, Options, Value),
    validate_row(Columns, row(Pairs)).

validate_column_value(Name, _Type, Options, null) :-
    ( memberchk(not_null, Options) ; memberchk(primary_key, Options) ), !,
    throw(error(existence_error(non_null_value, Name), _)).
validate_column_value(_, _, _, null) :- !.
validate_column_value(Name, Type, _Options, Value) :-
    ( sql_type_accepts(Type, Value) -> true
    ; throw(error(domain_error(sql_type(Name, Type), Value), _))
    ).

sql_type_accepts(Type, Value) :-
    type_signature(Type, Name, Arguments),
    type_accepts(Name, Arguments, Value), !.

type_signature(Type0, Name, Arguments) :-
    type_atom(Type0, TypeAtom),
    downcase_atom(TypeAtom, Lower),
    atom_codes(Lower, Codes0),
    exclude(space_code, Codes0, Codes),
    atom_codes(Compact, Codes),
    ( split_type_arguments(Compact, NameAtom, ArgumentAtom) ->
        atom_codes(ArgumentAtom, ArgumentCodes),
        split_argument_codes(ArgumentCodes, ArgumentParts),
        maplist(atom_number, ArgumentParts, Arguments),
        canonical_type_name(NameAtom, Name)
    ; canonical_type_name(Compact, Name),
      Arguments = []
    ).

% Column types originate in the SQL parser as atoms.  term_to_atom/2 would
% quote atoms that contain whitespace (for example the parser's "date "),
% turning the quotes into part of the type name after normalization.  Preserve
% atoms and strings verbatim; only render a non-text term as a last resort.
type_atom(Type, Type) :- atom(Type), !.
type_atom(Type, Atom) :- string(Type), !, atom_string(Atom, Type).
type_atom(Type, Atom) :- term_to_atom(Type, Atom).

canonical_type_name(character, char) :- !.
canonical_type_name(Raw, Name) :-
    atom_concat(Base, unsigned, Raw),
    signed_integer_type(Base), !,
    atomic_list_concat([Base, unsigned], '_', Name).
canonical_type_name(Name, Name).

split_type_arguments(Compact, Name, Arguments) :-
    sub_atom(Compact, OpenAt, 1, _, '('),
    sub_atom(Compact, CloseAt, 1, 0, ')'),
    OpenAt < CloseAt,
    sub_atom(Compact, 0, OpenAt, _, Name),
    Start is OpenAt + 1,
    Length is CloseAt - Start,
    sub_atom(Compact, Start, Length, _, Arguments).

split_argument_codes([], []) :- !.
split_argument_codes(Codes, Parts) :-
    atom_codes(Arguments, Codes),
    atomic_list_concat(Parts, ',', Arguments).

type_accepts(Name, _, Value) :- integer_type(Name), !, integer(Value), integer_in_range(Name, Value).
type_accepts(decimal, [Precision, Scale], Value) :- !,
    number(Value), decimal_precision_scale(Value, Digits, ActualScale),
    Digits =< Precision, ActualScale =< Scale.
type_accepts(decimal, _, Value) :- !, number(Value).
type_accepts(Name, _, Value) :- floating_type(Name), !, number(Value).
type_accepts(varchar, [Limit|_], Value) :- !, text_value(Value, Text), atom_length(Text, Length), Length =< Limit.
type_accepts(char, [Limit|_], Value) :- !, text_value(Value, Text), atom_length(Text, Length), Length =< Limit.
type_accepts(varchar, _, Value) :- !, text_value(Value, _).
type_accepts(char, _, Value) :- !, text_value(Value, _).
type_accepts(Name, _, Value) :- text_type(Name), !, text_value(Value, _).
type_accepts(date, _, Value) :- !, valid_date_value(Value).
type_accepts(time, _, Value) :- !, valid_time_value(Value).
type_accepts(datetime, _, Value) :- !, valid_datetime_value(Value).
type_accepts(timestamp, _, Value) :- !, valid_datetime_value(Value).
type_accepts(year, _, Value) :- !, valid_year_value(Value).
type_accepts(bool, _, Value) :- !, boolean_value(Value).
type_accepts(boolean, _, Value) :- !, boolean_value(Value).
type_accepts(Name, _, _) :- \+ strict_type(Name).

strict_type(Name) :- integer_type(Name).
strict_type(decimal).
strict_type(Name) :- floating_type(Name).
strict_type(varchar).
strict_type(char).
strict_type(Name) :- text_type(Name).
strict_type(date).
strict_type(time).
strict_type(datetime).
strict_type(timestamp).
strict_type(year).
strict_type(bool).
strict_type(boolean).

integer_type(tinyint).
integer_type(smallint).
integer_type(mediumint).
integer_type(int).
integer_type(integer).
integer_type(bigint).
integer_type(tinyint_unsigned).
integer_type(smallint_unsigned).
integer_type(mediumint_unsigned).
integer_type(int_unsigned).
integer_type(integer_unsigned).
integer_type(bigint_unsigned).

signed_integer_type(tinyint).
signed_integer_type(smallint).
signed_integer_type(mediumint).
signed_integer_type(int).
signed_integer_type(integer).
signed_integer_type(bigint).

integer_in_range(tinyint, Value) :- Value >= -128, Value =< 127.
integer_in_range(smallint, Value) :- Value >= -32768, Value =< 32767.
integer_in_range(mediumint, Value) :- Value >= -8388608, Value =< 8388607.
integer_in_range(int, Value) :- Value >= -2147483648, Value =< 2147483647.
integer_in_range(integer, Value) :- Value >= -2147483648, Value =< 2147483647.
integer_in_range(bigint, Value) :- Value >= -9223372036854775808, Value =< 9223372036854775807.
integer_in_range(tinyint_unsigned, Value) :- Value >= 0, Value =< 255.
integer_in_range(smallint_unsigned, Value) :- Value >= 0, Value =< 65535.
integer_in_range(mediumint_unsigned, Value) :- Value >= 0, Value =< 16777215.
integer_in_range(int_unsigned, Value) :- Value >= 0, Value =< 4294967295.
integer_in_range(integer_unsigned, Value) :- Value >= 0, Value =< 4294967295.
integer_in_range(bigint_unsigned, Value) :- Value >= 0, Value =< 18446744073709551615.

floating_type(float).
floating_type(double).
floating_type(real).

text_type(text).
text_type(tinytext).
text_type(mediumtext).
text_type(longtext).

text_value(Value, Text) :- atom(Value), !, Text = Value.
text_value(Value, Text) :- string(Value), !, atom_string(Text, Value).

boolean_value(true).
boolean_value(false).
boolean_value(0).
boolean_value(1).

decimal_precision_scale(Value, Digits, Scale) :-
    number_codes(Value, Codes0),
    ( ( memberchk(101, Codes0) ; memberchk(69, Codes0) ) ->
        format(atom(Text0), '~15f', [Value]), atom_codes(Text0, Codes1)
    ; Codes1 = Codes0
    ),
    atom_codes(Text, Codes1),
    decimal_digits_scale(Text, Digits, Scale).

decimal_digits_scale(Text, Digits, Scale) :-
    atom_codes(Text, Codes0),
    exclude(sign_code, Codes0, Codes),
    ( append(IntegerCodes, [46|Fraction0], Codes) ->
        trim_trailing_zeros(Fraction0, Fraction),
        length(Fraction, Scale)
    ; IntegerCodes = Codes,
      Scale = 0
    ),
    append(IntegerCodes, Fraction, RawDigits),
    trim_leading_zeros(RawDigits, Significant),
    ( Significant = [] -> Digits = 1 ; length(Significant, Digits) ).

sign_code(45).
sign_code(43).
space_code(Code) :- code_type(Code, space).

trim_trailing_zeros(Codes, Trimmed) :- reverse(Codes, Reversed), trim_leading_zeros(Reversed, Clean), reverse(Clean, Trimmed).
trim_leading_zeros([48|Codes], Trimmed) :- !, trim_leading_zeros(Codes, Trimmed).
trim_leading_zeros(Codes, Codes).

valid_year_value(Value) :- integer(Value), Value >= 0, Value =< 9999.
valid_year_value(Value) :- text_value(Value, Text), atom_length(Text, 4), atom_number(Text, Year), valid_year_value(Year).

valid_date_value(Value) :-
    text_value(Value, Text),
    atom_codes(Text, Codes),
    Codes = [Y1,Y2,Y3,Y4,45,M1,M2,45,D1,D2],
    maplist(decimal_code, [Y1,Y2,Y3,Y4,M1,M2,D1,D2]),
    number_codes(Year, [Y1,Y2,Y3,Y4]),
    number_codes(Month, [M1,M2]),
    number_codes(Day, [D1,D2]),
    valid_calendar_date(Year, Month, Day).

valid_time_value(Value) :-
    text_value(Value, Text),
    atom_codes(Text, Codes),
    Codes = [H1,H2,58,M1,M2,58,S1,S2],
    maplist(decimal_code, [H1,H2,M1,M2,S1,S2]),
    number_codes(Hour, [H1,H2]),
    number_codes(Minute, [M1,M2]),
    number_codes(Second, [S1,S2]),
    Hour >= 0, Hour =< 23,
    Minute >= 0, Minute =< 59,
    Second >= 0, Second =< 59.

valid_datetime_value(Value) :-
    text_value(Value, Text),
    ( sub_atom(Text, 10, 1, _, ' ') ; sub_atom(Text, 10, 1, _, 'T') ),
    sub_atom(Text, 0, 10, _, Date),
    sub_atom(Text, 11, _, 0, Time),
    valid_date_value(Date),
    valid_time_value(Time).

decimal_code(Code) :- Code >= 48, Code =< 57.

valid_calendar_date(Year, Month, Day) :-
    Month >= 1, Month =< 12,
    days_in_month(Year, Month, MaxDay),
    Day >= 1, Day =< MaxDay.

days_in_month(_, 1, 31).
days_in_month(Year, 2, Days) :- ( leap_year(Year) -> Days = 29 ; Days = 28 ).
days_in_month(_, 3, 31).
days_in_month(_, 4, 30).
days_in_month(_, 5, 31).
days_in_month(_, 6, 30).
days_in_month(_, 7, 31).
days_in_month(_, 8, 31).
days_in_month(_, 9, 30).
days_in_month(_, 10, 31).
days_in_month(_, 11, 30).
days_in_month(_, 12, 31).

leap_year(Year) :- 0 is Year mod 400, !.
leap_year(Year) :- 0 =\= Year mod 100, 0 is Year mod 4.

validate_unique_indexes([], _).
validate_unique_indexes([index(Name, Columns, unique)|Indexes], Rows) :- !,
    validate_unique_index(Name, Columns, Rows),
    validate_unique_indexes(Indexes, Rows).
validate_unique_indexes([_|Indexes], Rows) :-
    validate_unique_indexes(Indexes, Rows).

validate_unique_index(Name, Columns, Rows) :-
    findall(Key,
            ( member(Row, Rows),
              row_key(Columns, Row, Key),
              unique_key_participates(Name, Key)
            ),
            Keys),
    msort(Keys, Sorted),
    ( adjacent_duplicate(Sorted, Duplicate) ->
        throw(error(permission_error(insert, unique_key(Name), Duplicate), _))
    ; true
    ).

unique_key_participates('PRIMARY', Key) :- !,
    ( memberchk(null, Key) -> throw(error(existence_error(primary_key_value, Key), _)) ; true ).
unique_key_participates(_, Key) :- \+ memberchk(null, Key).

row_key([], _, []).
row_key([Column|Columns], row(Pairs), [Key|Keys]) :-
    ( lookup_value(Column, Pairs, Value) -> canonical_key_value(Value, Key) ; Key = null ),
    row_key(Columns, row(Pairs), Keys).

canonical_key_value(null, null) :- !.
canonical_key_value(Value, number(Text)) :- number(Value), !,
    % 17 significant digits preserve an IEEE-754 double's round-trip value;
    % a shorter display format can collapse distinct keys during uniqueness
    % validation.
    format(atom(Text), '~17g', [Value]).
canonical_key_value(Value, Value).

adjacent_duplicate([Value,Value|_], Value) :- !.
adjacent_duplicate([_|Values], Duplicate) :- adjacent_duplicate(Values, Duplicate).

column_named(Name, [col(Column, _, _)|_]) :- same_identifier(Name, Column), !.
column_named(Name, [_|Columns]) :- column_named(Name, Columns).

identifier_member(Name, [Column|_]) :- same_identifier(Name, Column), !.
identifier_member(Name, [_|Columns]) :- identifier_member(Name, Columns).

same_identifier(A, B) :- A == B, !.
same_identifier(A, B) :- atom(A), atom(B), downcase_atom(A, DA), downcase_atom(B, DB), DA == DB.

lookup_value(Name, [Column=Value|_], Value) :- same_identifier(Name, Column), !.
lookup_value(Name, [_|Pairs], Value) :- lookup_value(Name, Pairs, Value).
