% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  AsaDB SQL Frontend
  ------------------
  Tokenization, statement parsing, and syntax diagnostics.  This module has no
  storage side effects: it converts SQL text into the AST consumed by
  asadb_core's executor.
*/

:- module(asadb_sql_frontend, [
    asadb_parse_sql/2,
    asadb_analyze_sql/2,
    asadb_parse_statement/2
]).

:- set_prolog_flag(double_quotes, codes).
:- discontiguous parse_statement/2.

:- use_module(library(lists)).
:- use_module('asadb_mysql55_compat.pl').

% Parser-local identifier rules intentionally mirror the catalog's
% case-insensitive matching without importing the stateful core module.
same_identifier(A, B) :- A == B, !.
same_identifier(A, B) :-
    atom(A),
    atom(B),
    downcase_atom(A, LowerA),
    downcase_atom(B, LowerB),
    LowerA == LowerB.

identifier_member(Name, [Seen|_]) :- same_identifier(Name, Seen), !.
identifier_member(Name, [_|Seen]) :- identifier_member(Name, Seen).

dedupe_columns(Columns0, Columns) :-
    dedupe_columns_(Columns0, [], Columns).

dedupe_columns_([], _, []).
dedupe_columns_([col(Name, _, _)|Columns], Seen, Out) :-
    identifier_member(Name, Seen), !,
    dedupe_columns_(Columns, Seen, Out).
dedupe_columns_([col(Name, Type, Options)|Columns], Seen,
                [col(Name, Type, Options)|Out]) :- !,
    dedupe_columns_(Columns, [Name|Seen], Out).
dedupe_columns_([_|Columns], Seen, Out) :-
    dedupe_columns_(Columns, Seen, Out).

asadb_parse_sql(SQL, Statements) :-
    sql_codes(SQL, Codes),
    sql_tokens(Codes, Tokens),
    split_statements(Tokens, TokenStatements),
    parse_statements(TokenStatements, Statements).

asadb_analyze_sql(SQL, diagnostics(Diagnostics)) :-
    sql_codes(SQL, Codes),
    sql_statement_spans(Codes, Statements),
    analyze_statement_spans(Statements, Diagnostics0),
    sort_diagnostics(Diagnostics0, Diagnostics).

sql_statement_spans(Codes, Statements) :-
    split_sql_chunks(Codes, Chunks),
    chunks_to_statement_spans(Chunks, 1, Statements).

split_sql_chunks(Codes, Chunks) :-
    split_sql_chunks_(Codes, none, [], [], Rev),
    reverse(Rev, Chunks).

split_sql_chunks_([], _, Acc, Out, [chunk(Chunk, false)|Out]) :-
    reverse(Acc, Chunk), !.
split_sql_chunks_([59|Cs], none, Acc, Out, Res) :-
    reverse(Acc, Chunk), !,
    split_sql_chunks_(Cs, none, [], [chunk(Chunk, true)|Out], Res).
split_sql_chunks_([45,45|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, line_comment, [45,45|Acc], Out, Res).
split_sql_chunks_([35|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, line_comment, [35|Acc], Out, Res).
split_sql_chunks_([47,42|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, block_comment, [42,47|Acc], Out, Res).
split_sql_chunks_([39|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, single, [39|Acc], Out, Res).
split_sql_chunks_([34|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, double, [34|Acc], Out, Res).
split_sql_chunks_([96|Cs], none, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, backtick, [96|Acc], Out, Res).
split_sql_chunks_([92,C|Cs], single, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, single, [C,92|Acc], Out, Res).
split_sql_chunks_([92,C|Cs], double, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, double, [C,92|Acc], Out, Res).
split_sql_chunks_([39|Cs], single, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [39|Acc], Out, Res).
split_sql_chunks_([34|Cs], double, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [34|Acc], Out, Res).
split_sql_chunks_([96|Cs], backtick, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [96|Acc], Out, Res).
split_sql_chunks_([10|Cs], line_comment, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [10|Acc], Out, Res).
split_sql_chunks_([42,47|Cs], block_comment, Acc, Out, Res) :- !,
    split_sql_chunks_(Cs, none, [47,42|Acc], Out, Res).
split_sql_chunks_([C|Cs], Quote, Acc, Out, Res) :-
    split_sql_chunks_(Cs, Quote, [C|Acc], Out, Res).

chunks_to_statement_spans([], _, []).
chunks_to_statement_spans([chunk(Codes, Terminated)|Chunks], BaseLine, Statements) :-
    trim_leading_sql_ws(Codes, LeadingLines, Trim0),
    trim_trailing_sql_ws(Trim0, Trimmed),
    count_newlines(Codes, NewLines),
    NextLine is BaseLine + NewLines,
    ( Trimmed = [] ->
        Statements = Rest
    ; StartLine is BaseLine + LeadingLines,
      Statements = [stmt(StartLine, Trimmed, Terminated)|Rest]
    ),
    chunks_to_statement_spans(Chunks, NextLine, Rest).

trim_leading_sql_ws([], 0, []).
trim_leading_sql_ws([C|Cs], Lines, Rest) :-
    is_space_code(C), !,
    trim_leading_sql_ws(Cs, Lines0, Rest),
    ( C =:= 10 -> Lines is Lines0 + 1 ; Lines = Lines0 ).
trim_leading_sql_ws(Codes, 0, Codes).

trim_trailing_sql_ws(Codes, Trimmed) :-
    reverse(Codes, Rev),
    drop_leading_sql_ws(Rev, RevTrimmed),
    reverse(RevTrimmed, Trimmed).

drop_leading_sql_ws([C|Cs], Rest) :- is_space_code(C), !, drop_leading_sql_ws(Cs, Rest).
drop_leading_sql_ws(Codes, Codes).

count_newlines([], 0).
count_newlines([10|Cs], N) :- !, count_newlines(Cs, N0), N is N0 + 1.
count_newlines([_|Cs], N) :- count_newlines(Cs, N).

analyze_statement_spans([], []).
analyze_statement_spans([Stmt|Stmts], Diagnostics) :-
    analyze_statement_span(Stmt, D1),
    analyze_statement_spans(Stmts, D2),
    append(D1, D2, Diagnostics).

analyze_statement_span(stmt(Line, Codes, Terminated), Diagnostics) :-
    catch(sql_tokens(Codes, Tokens), Error,
          Tokens = [lexer_error(Error)]),
    syntax_diagnostics(Line, Tokens, SyntaxDiagnostics),
    semicolon_diagnostic(Line, Terminated, SemicolonDiagnostics),
    append(SyntaxDiagnostics, SemicolonDiagnostics, Diagnostics).

semicolon_diagnostic(_, true, []) :- !.
semicolon_diagnostic(Line, false, [diagnostic(warning, Line, 'Statement belum ditutup titik koma (;).', '')]).

syntax_diagnostics(Line, [lexer_error(Error)], [diagnostic(error, Line, Message, '')]) :- !,
    term_atom_safe(Error, ErrorAtom),
    atom_concat('Lexer AsaDB error: ', ErrorAtom, Message).
syntax_diagnostics(Line, Tokens, Diagnostics) :-
    paren_delta(Tokens, Delta),
    paren_diagnostic(Line, Delta, ParenDiagnostics),
    parse_diagnostic(Line, Tokens, ParseDiagnostics),
    correction_diagnostic(Line, Tokens, CorrectionDiagnostics),
    append(ParenDiagnostics, ParseDiagnostics, A),
    append(A, CorrectionDiagnostics, Diagnostics).

paren_delta(Tokens, Delta) :- paren_delta_(Tokens, 0, Delta).
paren_delta_([], Delta, Delta).
paren_delta_([sym('(')|Ts], Acc, Delta) :- !, Acc1 is Acc + 1, paren_delta_(Ts, Acc1, Delta).
paren_delta_([sym(')')|Ts], Acc, Delta) :- !, Acc1 is Acc - 1, paren_delta_(Ts, Acc1, Delta).
paren_delta_([_|Ts], Acc, Delta) :- paren_delta_(Ts, Acc, Delta).

paren_diagnostic(_, 0, []) :- !.
paren_diagnostic(Line, Delta, [diagnostic(error, Line, Message, '')]) :-
    ( Delta > 0 -> Message = 'Kurung buka belum ditutup.'
    ; Message = 'Kurung tutup berlebih.'
    ).

parse_diagnostic(_, Tokens, []) :-
    parse_statement(Tokens, Statement),
    \+ unsupported_statement(Statement), !.
parse_diagnostic(Line, Tokens, [diagnostic(error, Line, Message, '')]) :-
    parse_statement(Tokens, Statement),
    unsupported_statement(Statement), !,
    unsupported_message(Statement, Message).
parse_diagnostic(Line, Tokens, [diagnostic(error, Line, Message, Suggestion)]) :-
    first_token_name(Tokens, First),
    keyword_correction(First, Suggestion), !,
    atom_concat('Statement belum kebaca parser. Mungkin maksudnya ', Suggestion, M0),
    atom_concat(M0, '.', Message).
parse_diagnostic(Line, Tokens, [diagnostic(error, Line, 'Statement belum dikenali parser AsaDB.', '')]) :-
    Tokens \= [], !.
parse_diagnostic(_, [], []).

unsupported_statement(unsupported_mysql55(_, _)).
unsupported_statement(unsupported_mysql55(_)).

unsupported_message(unsupported_mysql55(Feature, _), Message) :- !,
    mysql55_unsupported_message(Feature, Message).
unsupported_message(unsupported_mysql55(_), 'Statement MySQL 5.5 belum aktif di AsaDB.').

mysql55_unsupported_message(Feature, Message) :-
    mysql55_feature_status(Feature, Status), !,
    term_atom_safe(Feature, FeatureAtom),
    format(atom(Message), 'Fitur MySQL 5.5 ~w: ~w.', [Status, FeatureAtom]).
mysql55_unsupported_message(Feature, Message) :-
    term_atom_safe(Feature, FeatureAtom),
    atom_concat('Fitur MySQL 5.5 belum aktif: ', FeatureAtom, Message).

correction_diagnostic(_, [], []) :- !.
correction_diagnostic(Line, Tokens, Diagnostics) :-
    findall(diagnostic(warning, Line, Message, Suggestion),
            ( member(Token, Tokens),
              token_name(Token, Name),
              keyword_correction(Name, Suggestion),
              atom_concat('Auto correction tersedia: ', Name, A),
              atom_concat(A, ' -> ', B),
              atom_concat(B, Suggestion, Message)
            ),
            Raw),
    take_first_diagnostics(4, Raw, Diagnostics).

take_first_diagnostics(_, [], []).
take_first_diagnostics(0, _, []) :- !.
take_first_diagnostics(N, [D|Ds], [D|Rest]) :-
    N1 is N - 1,
    take_first_diagnostics(N1, Ds, Rest).

first_token_name([Token|_], Name) :- token_name(Token, Name), !.
first_token_name(_, '').

token_name(id(Name), Name).
token_name(kw(Name), Name).

keyword_correction(Name, Suggestion) :-
    downcase_atom(Name, Lower),
    sql_keyword_typo(Lower, Suggestion).

sql_keyword_typo(addd, 'ADD').
sql_keyword_typo(altr, 'ALTER').
sql_keyword_typo(cerate, 'CREATE').
sql_keyword_typo(creat, 'CREATE').
sql_keyword_typo(crete, 'CREATE').
sql_keyword_typo(databse, 'DATABASE').
sql_keyword_typo(databeses, 'DATABASES').
sql_keyword_typo(delet, 'DELETE').
sql_keyword_typo(delte, 'DELETE').
sql_keyword_typo(descibe, 'DESCRIBE').
sql_keyword_typo(descirbe, 'DESCRIBE').
sql_keyword_typo(drpo, 'DROP').
sql_keyword_typo(exsits, 'EXISTS').
sql_keyword_typo(frm, 'FROM').
sql_keyword_typo(form, 'FROM').
sql_keyword_typo(inesrt, 'INSERT').
sql_keyword_typo(instert, 'INSERT').
sql_keyword_typo(isnt, 'INT').
sql_keyword_typo(itno, 'INTO').
sql_keyword_typo(limt, 'LIMIT').
sql_keyword_typo(primay, 'PRIMARY').
sql_keyword_typo(slect, 'SELECT').
sql_keyword_typo(selct, 'SELECT').
sql_keyword_typo(selec, 'SELECT').
sql_keyword_typo(shwo, 'SHOW').
sql_keyword_typo(tabel, 'TABLE').
sql_keyword_typo(tbale, 'TABLE').
sql_keyword_typo(teble, 'TABLE').
sql_keyword_typo(udpate, 'UPDATE').
sql_keyword_typo(updte, 'UPDATE').
sql_keyword_typo(vaules, 'VALUES').
sql_keyword_typo(vlaues, 'VALUES').
sql_keyword_typo(wher, 'WHERE').
sql_keyword_typo(whree, 'WHERE').

sort_diagnostics(Diagnostics, Sorted) :-
    predsort(compare_diagnostics, Diagnostics, Sorted0),
    unique_diagnostics(Sorted0, Sorted).

compare_diagnostics(Order, diagnostic(S1, L1, M1, _), diagnostic(S2, L2, M2, _)) :-
    compare(LineOrder, L1, L2),
    ( LineOrder \= (=) -> Order = LineOrder
    ; severity_rank(S1, R1),
      severity_rank(S2, R2),
      compare(SeverityOrder, R1, R2),
      ( SeverityOrder \= (=) -> Order = SeverityOrder ; compare(Order, M1, M2) )
    ).

severity_rank(error, 0) :- !.
severity_rank(warning, 1) :- !.
severity_rank(_, 2).

unique_diagnostics([], []).
unique_diagnostics([D|Ds], [D|Out]) :- drop_same_diagnostics(D, Ds, Rest), unique_diagnostics(Rest, Out).

drop_same_diagnostics(_, [], []).
drop_same_diagnostics(diagnostic(S, L, M, _), [diagnostic(S, L, M, _)|Ds], Rest) :- !,
    drop_same_diagnostics(diagnostic(S, L, M, ''), Ds, Rest).
drop_same_diagnostics(_, Ds, Ds).

sql_codes(SQL, SQL) :- is_list(SQL), !.
sql_codes(SQL, Codes) :- atom(SQL), !, atom_codes(SQL, Codes).
sql_codes(SQL, Codes) :- string(SQL), !, string_codes(SQL, Codes).

parse_statements([], []).
parse_statements([[]|Rest], Statements) :- !, parse_statements(Rest, Statements).
parse_statements([Tokens|Rest], [Stmt|Statements]) :-
    parse_statement(Tokens, Stmt), !,
    parse_statements(Rest, Statements).
parse_statements([Tokens|Rest], [unsupported_mysql55(Feature, raw(Tokens))|Statements]) :-
    mysql55_unsupported_feature(Tokens, Feature), !,
    parse_statements(Rest, Statements).
parse_statements([Tokens|Rest], [unsupported_mysql55(raw(Tokens))|Statements]) :-
    parse_statements(Rest, Statements).

% Keep the compatibility manifest operational: an unimplemented but known
% MySQL statement gets a precise status rather than being reported as a vague
% parser failure.  Supported AsaDB statements are handled by parse_statement/2
% above, so this branch is only reached for an actual fallback.
mysql55_unsupported_feature([Token|_], Feature) :-
    token_name(Token, RawFeature),
    downcase_atom(RawFeature, Feature),
    mysql55_feature_status(Feature, Status),
    Status \= implemented.

/* -------------------------------------------------------------------------
   Lexer
   ------------------------------------------------------------------------- */

sql_tokens(Codes, Tokens) :- scan(Codes, Tokens0), remove_ws(Tokens0, Tokens).

remove_ws([], []).
remove_ws([ws|Ts], Clean) :- !, remove_ws(Ts, Clean).
remove_ws([T|Ts], [T|Clean]) :- remove_ws(Ts, Clean).

scan([], []).
scan([C|Cs], [ws|Ts]) :- is_space_code(C), !, scan(Cs, Ts).
scan([45,45|Cs], Ts) :- !, skip_line(Cs, Rest), scan(Rest, Ts).       % -- comment
scan([35|Cs], Ts) :- !, skip_line(Cs, Rest), scan(Rest, Ts).           % # comment
scan([47,42|Cs], Ts) :- !, skip_block_comment(Cs, Rest), scan(Rest, Ts). % /* */
scan([96|Cs], [id(A)|Ts]) :- !, take_until(96, Cs, IdCodes, Rest), atom_codes(A, IdCodes), scan(Rest, Ts).
scan([39|Cs], [str(A)|Ts]) :- !, take_string(39, Cs, StrCodes, Rest), atom_codes(A, StrCodes), scan(Rest, Ts).
scan([34|Cs], [str(A)|Ts]) :- !, take_string(34, Cs, StrCodes, Rest), atom_codes(A, StrCodes), scan(Rest, Ts).
scan([C|Cs], [num(N)|Ts]) :- is_digit_code(C), !, take_number(Cs, Ds, Rest), number_codes(N, [C|Ds]), scan(Rest, Ts).
scan([C|Cs], [Tok|Ts]) :- is_ident_start(C), !, take_ident(Cs, More, Rest), atom_codes(Atom0, [C|More]), normalize_atom(Atom0, Tok), scan(Rest, Ts).
scan([62,61|Cs], [op('>=')|Ts]) :- !, scan(Cs, Ts).
scan([60,61|Cs], [op('<=')|Ts]) :- !, scan(Cs, Ts).
scan([60,62|Cs], [op('<>')|Ts]) :- !, scan(Cs, Ts).
scan([33,61|Cs], [op('!=')|Ts]) :- !, scan(Cs, Ts).
scan([61|Cs], [op('=')|Ts]) :- !, scan(Cs, Ts).
scan([62|Cs], [op('>')|Ts]) :- !, scan(Cs, Ts).
scan([60|Cs], [op('<')|Ts]) :- !, scan(Cs, Ts).
scan([40|Cs], [sym('(')|Ts]) :- !, scan(Cs, Ts).
scan([41|Cs], [sym(')')|Ts]) :- !, scan(Cs, Ts).
scan([44|Cs], [sym(',')|Ts]) :- !, scan(Cs, Ts).
scan([59|Cs], [sym(';')|Ts]) :- !, scan(Cs, Ts).
scan([42|Cs], [sym('*')|Ts]) :- !, scan(Cs, Ts).
scan([46|Cs], [sym('.')|Ts]) :- !, scan(Cs, Ts).
scan([43|Cs], [op('+')|Ts]) :- !, scan(Cs, Ts).
scan([45|Cs], [op('-')|Ts]) :- !, scan(Cs, Ts).
scan([47|Cs], [op('/')|Ts]) :- !, scan(Cs, Ts).
scan([C|Cs], [char(C)|Ts]) :- scan(Cs, Ts).

skip_line([], []).
skip_line([10|Rest], Rest) :- !.
skip_line([_|Cs], Rest) :- skip_line(Cs, Rest).

skip_block_comment([], []).
skip_block_comment([42,47|Rest], Rest) :- !.
skip_block_comment([_|Cs], Rest) :- skip_block_comment(Cs, Rest).

take_until(_, [], [], []).
take_until(Q, [Q|Rest], [], Rest) :- !.
take_until(Q, [C|Cs], [C|Out], Rest) :- take_until(Q, Cs, Out, Rest).

take_string(_, [], [], []).
% Preserve conventional SQL escapes so production backups can round-trip
% quotes, literal backslashes, and multiline text without emitting physical
% newlines into the SQL stream.
take_string(Q, [92,92|Cs], [92|Out], Rest) :- !, take_string(Q, Cs, Out, Rest).
take_string(Q, [92,110|Cs], [10|Out], Rest) :- !, take_string(Q, Cs, Out, Rest).
take_string(Q, [92,114|Cs], [13|Out], Rest) :- !, take_string(Q, Cs, Out, Rest).
take_string(Q, [92,116|Cs], [9|Out], Rest) :- !, take_string(Q, Cs, Out, Rest).
take_string(Q, [92,Q|Cs], [Q|Out], Rest) :- !, take_string(Q, Cs, Out, Rest).
take_string(Q, [Q|Rest], [], Rest) :- !.
take_string(Q, [C|Cs], [C|Out], Rest) :- take_string(Q, Cs, Out, Rest).

take_digits([C|Cs], [C|Ds], Rest) :- is_digit_code(C), !, take_digits(Cs, Ds, Rest).
take_digits(Rest, [], Rest).

take_number(Cs, Ds, Rest) :-
    take_digits(Cs, Int, Rest0),
    take_fraction(Rest0, Frac, Rest1),
    take_exponent(Rest1, Exponent, Rest),
    append(Int, Frac, Decimal),
    append(Decimal, Exponent, Ds).
take_fraction([46,C|Cs], [46,C|Ds], Rest) :- is_digit_code(C), !, take_digits(Cs, Ds, Rest).
take_fraction(Rest, [], Rest).

% Backup output uses number_codes/2 for reversible floating-point literals.
% Accept scientific notation as well as ordinary integer/decimal SQL values.
take_exponent([E,C|Cs], [E,C|Ds], Rest) :-
    memberchk(E, [69,101]),
    is_digit_code(C), !,
    take_digits(Cs, Ds, Rest).
take_exponent([E,Sign,C|Cs], [E,Sign,C|Ds], Rest) :-
    memberchk(E, [69,101]),
    memberchk(Sign, [43,45]),
    is_digit_code(C), !,
    take_digits(Cs, Ds, Rest).
take_exponent(Rest, [], Rest).

take_ident([C|Cs], [C|More], Rest) :- is_ident_code(C), !, take_ident(Cs, More, Rest).
take_ident(Rest, [], Rest).

is_space_code(9). is_space_code(10). is_space_code(13). is_space_code(32).
is_digit_code(C) :- C >= 48, C =< 57.
is_letter_code(C) :- C >= 65, C =< 90.
is_letter_code(C) :- C >= 97, C =< 122.
is_ident_start(C) :- is_letter_code(C), !.
is_ident_start(95).  % _
is_ident_code(C) :- is_ident_start(C), !.
is_ident_code(C) :- is_digit_code(C), !.
is_ident_code(36).   % $

normalize_atom(Atom0, kw(Atom)) :-
    downcase_atom(Atom0, Atom),
    keyword(Atom), !.
normalize_atom(Atom, id(Atom)).

keyword(add). keyword(all). keyword(alter). keyword(and). keyword(as). keyword(asc).
keyword(auto_increment). keyword(after). keyword(before). keyword(begin). keyword(between). keyword(bigint). keyword(binary).
keyword(blob). keyword(bool). keyword(boolean). keyword(by). keyword(cascade).
keyword(case). keyword(char). keyword(character). keyword(change). keyword(check). keyword(collate). keyword(column). keyword(columns). keyword(comment).
keyword(constraint). keyword(create). keyword(cross). keyword(current_timestamp). keyword(database).
keyword(databases). keyword(date). keyword(datetime). keyword(decimal). keyword(default).
keyword(delete). keyword(desc). keyword(describe). keyword(distinct). keyword(double).
keyword(drop). keyword(each). keyword(else). keyword(end). keyword(engine). keyword(enum). keyword(exists). keyword(float).
keyword(for). keyword(foreign). keyword(from). keyword(grants). keyword(group). keyword(having). keyword(if).
keyword(identified). keyword(inout).
keyword(in). keyword(index). keyword(indexes). keyword(inner). keyword(insert). keyword(int). keyword(integer). keyword(into).
keyword(is). keyword(join). keyword(key). keyword(keys). keyword(left). keyword(like). keyword(limit). keyword(login).
keyword(longblob). keyword(longtext). keyword(mediumint). keyword(mediumtext). keyword(modify).
keyword(not). keyword(null). keyword(offset). keyword(on). keyword(or). keyword(order). keyword(out). keyword(outer). keyword(password). keyword(primary).
keyword(real). keyword(references). keyword(rename). keyword(restrict). keyword(return). keyword(returns). keyword(right). keyword(row). keyword(select). keyword(set).
keyword(show). keyword(smallint). keyword(table). keyword(tables). keyword(text). keyword(then). keyword(true).
keyword(time). keyword(timestamp). keyword(tinyint). keyword(tinytext). keyword(to).
keyword(union). keyword(unique). keyword(unknown). keyword(unsigned). keyword(update). keyword(user). keyword(use). keyword(using). keyword(values).
keyword(varchar). keyword(varbinary). keyword(where). keyword(xor). keyword(year). keyword(zerofill).
keyword(truncate). keyword(view). keyword(trigger). keyword(procedure). keyword(function).
keyword(false). keyword(grant). keyword(revoke). keyword(commit). keyword(rollback). keyword(start).
keyword(transaction). keyword(lock). keyword(unlock). keyword(explain). keyword(analyze). keyword(when).

split_statements(Tokens, Statements) :- split_statements_(Tokens, [], [], Rev), reverse(Rev, Statements).
split_statements_([], Acc, Out, [Stmt|Out]) :- reverse(Acc, Stmt), !.
split_statements_([sym(';')|Ts], Acc, Out, Res) :- reverse(Acc, Stmt), !, split_statements_(Ts, [], [Stmt|Out], Res).
split_statements_([T|Ts], Acc, Out, Res) :- split_statements_(Ts, [T|Acc], Out, Res).

/* -------------------------------------------------------------------------
   Parser helpers
   ------------------------------------------------------------------------- */

parse_statement([kw(create),kw(database)|Rest], create_database(Name)) :-
    optional_if_not_exists(Rest, Rest2),
    parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(use)|Rest], use_database(Name)) :-
    parse_ident(Rest, Name, Tail), Tail = [].

parse_statement([kw(drop),kw(database)|Rest], drop_database(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(create),kw(table)|Rest], create_table(Name, Columns, Options)) :-
    optional_if_not_exists(Rest, Rest2),
    parse_ident(Rest2, Name, [sym('(')|AfterName]),
    take_paren_payload(AfterName, ColumnTokens, Tail),
    split_top_commas(ColumnTokens, ColumnDefs),
    parse_table_definitions(ColumnDefs, Columns0, Constraints),
    dedupe_columns(Columns0, Columns),
    Options = table_options(Constraints, Tail).

parse_statement([kw(drop),kw(table)|Rest], drop_table(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(truncate),kw(table)|Rest], truncate_table(Name)) :-
    parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(truncate)|Rest], truncate_table(Name)) :-
    parse_ident(Rest, Name, Tail), Tail = [].

parse_statement([kw(insert),kw(into)|Rest], insert(Table, Columns, Rows)) :-
    parse_ident(Rest, Table, Rest1),
    ( Rest1 = [sym('(')|AfterOpen] ->
        take_paren_payload(AfterOpen, ColTokens, Rest2),
        parse_ident_list(ColTokens, Columns)
    ; Columns = [], Rest2 = Rest1
    ),
    Rest2 = [kw(values)|AfterValues],
    parse_value_groups(AfterValues, Rows, Tail), Tail = [].

parse_statement([kw(select)|Rest], union(Left, Right, Mode)) :-
    split_top_level_kw(union, [kw(select)|Rest], LeftTokens, AfterUnion), !,
    parse_statement(LeftTokens, Left),
    parse_union_right(AfterUnion, Right, Mode).
parse_statement([kw(select)|Rest], select(Projection, Source, Where, Group, Order, Limit)) :-
    split_top_level_kw(from, Rest, ProjectionTokens, AfterFrom),
    parse_projection(ProjectionTokens, Projection),
    split_select_source_tail(AfterFrom, SourceTokens, TailTokens),
    parse_from_source(SourceTokens, Source),
    parse_select_tail_ext(TailTokens, Where, Group, Order, Limit).

parse_statement([kw(update)|Rest], update(Table, Assignments, Where)) :-
    parse_ident(Rest, Table, [kw(set)|AfterSet]),
    split_optional_where(AfterSet, AssignTokens, WhereTokens),
    split_top_commas(AssignTokens, AssignParts),
    parse_assignments(AssignParts, Assignments),
    parse_where_tokens(WhereTokens, Where).

parse_statement([kw(delete),kw(from)|Rest], delete(Table, Where)) :-
    parse_ident(Rest, Table, AfterTable),
    ( AfterTable = [kw(where)|WhereTokens] -> parse_where_tokens(WhereTokens, Where)
    ; AfterTable = [], Where = true
    ).

parse_statement([kw(show),kw(databases)], show_databases).
parse_statement([kw(show),kw(tables)], show_tables).
parse_statement([kw(show),kw(columns),kw(from)|Rest], show_columns(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(index),kw(from)|Rest], show_index(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(indexes),kw(from)|Rest], show_index(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(keys),kw(from)|Rest], show_index(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(create),kw(table)|Rest], show_create_table(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(show),kw(grants),kw(for)|Rest], show_grants(User)) :- parse_user_name(Rest, User, Tail), Tail = [].
parse_statement([kw(describe)|Rest], describe_table(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].
parse_statement([kw(desc)|Rest], describe_table(Name)) :- parse_ident(Rest, Name, Tail), Tail = [].

parse_statement([kw(explain)|Rest], explain(Statement)) :-
    parse_statement(Rest, Statement), !.
% Keep an explicit raw form for diagnostics when the nested statement is not
% in the supported grammar; the executor will report it as unsupported rather
% than pretending a token dump is an execution plan.
parse_statement([kw(explain)|Rest], explain(raw(Rest))).

parse_statement([kw(create),kw(unique),kw(index)|Rest], create_index(Name, Table, Columns, unique)) :-
    parse_index_statement(Rest, Name, Table, Columns).
parse_statement([kw(create),kw(index)|Rest], create_index(Name, Table, Columns, non_unique)) :-
    parse_index_statement(Rest, Name, Table, Columns).
parse_statement([kw(drop),kw(index)|Rest], drop_index(Name, Table)) :-
    parse_ident(Rest, Name, [kw(on)|AfterOn]),
    parse_ident(AfterOn, Table, Tail), Tail = [].

parse_statement([kw(start),kw(transaction)], start_transaction).
parse_statement([kw(begin)], start_transaction).
parse_statement([kw(commit)], commit_transaction).
parse_statement([kw(rollback)], rollback_transaction).
parse_statement([kw(lock),kw(tables)|Rest], lock_tables(Targets)) :-
    parse_lock_targets(Rest, Targets).
parse_statement([kw(unlock),kw(tables)], unlock_tables).

parse_statement([kw(create),kw(user)|Rest], create_user(User, Password)) :-
    parse_user_name(Rest, User, [kw(identified),kw(by)|AfterBy]),
    parse_password(AfterBy, Password, Tail), Tail = [].
parse_statement([kw(drop),kw(user)|Rest], drop_user(User)) :-
    parse_user_name(Rest, User, Tail), Tail = [].
parse_statement([kw(grant)|Rest], grant_privilege(Privilege, Scope, User)) :-
    parse_ident(Rest, Privilege, [kw(on)|AfterOn]),
    parse_scope(AfterOn, Scope, [kw(to)|AfterTo]),
    parse_user_name(AfterTo, User, Tail), Tail = [].
parse_statement([kw(revoke)|Rest], revoke_privilege(Privilege, Scope, User)) :-
    parse_ident(Rest, Privilege, [kw(on)|AfterOn]),
    parse_scope(AfterOn, Scope, [kw(from)|AfterFrom]),
    parse_user_name(AfterFrom, User, Tail), Tail = [].
parse_statement([kw(login)|Rest], login_user(User, Password)) :-
    parse_user_name(Rest, User, [kw(identified),kw(by)|AfterBy]),
    parse_password(AfterBy, Password, Tail), Tail = [].

% ALTER TABLE operations
parse_statement([kw(alter),kw(table)|Rest], alter_table(Table, Operations)) :-
    parse_ident(Rest, Table, AfterTable),
    parse_alter_operations(AfterTable, Operations, Tail), Tail = [].

% Parse comma-separated ALTER operations
parse_alter_operations([], [], []) :- !.
parse_alter_operations(Tokens, [Op|Ops], Rest) :-
    parse_single_alter(Tokens, Op, AfterOp),
    ( AfterOp = [sym(',')|More] -> parse_alter_operations(More, Ops, Rest)
    ; Ops = [], Rest = AfterOp
    ).

% Parse individual ALTER operations
parse_single_alter([kw(add),kw(column)|Rest], add_column(Name, Type, Options), Tail) :- !,
    parse_ident(Rest, Name, AfterName),
    ( AfterName = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(add)|Rest], add_column(Name, Type, Options), Tail) :- !,
    parse_ident(Rest, Name, AfterName),
    ( AfterName = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(drop),kw(column)|Rest], drop_column(Name), Tail) :- !,
    parse_ident(Rest, Name, Tail).
parse_single_alter([kw(drop)|Rest], drop_column(Name), Tail) :- !,
    parse_ident(Rest, Name, Tail).
parse_single_alter([kw(modify),kw(column)|Rest], modify_column(Name, Type, Options), Tail) :- !,
    parse_ident(Rest, Name, AfterName),
    ( AfterName = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(modify)|Rest], modify_column(Name, Type, Options), Tail) :- !,
    parse_ident(Rest, Name, AfterName),
    ( AfterName = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(change),kw(column)|Rest], rename_column(OldName, NewName, Type, Options), Tail) :- !,
    parse_ident(Rest, OldName, AfterOld),
    parse_ident(AfterOld, NewName, AfterNew),
    ( AfterNew = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(change)|Rest], rename_column(OldName, NewName, Type, Options), Tail) :- !,
    parse_ident(Rest, OldName, AfterOld),
    parse_ident(AfterOld, NewName, AfterNew),
    ( AfterNew = [H|T], is_column_type_token(H) ->
        split_type_options_ext([H|T], TypeTokens, OptionTokens, Tail),
        tokens_text(TypeTokens, Type),
        parse_column_options(OptionTokens, Options)
    ; fail
    ).
parse_single_alter([kw(rename),kw(column)|Rest], rename_column_simple(OldName, NewName), Tail) :- !,
    parse_ident(Rest, OldName, [kw(to)|AfterTo]),
    parse_ident(AfterTo, NewName, Tail).
parse_single_alter([kw(rename),kw(to)|Rest], rename_table(NewName), Tail) :- !,
    parse_ident(Rest, NewName, Tail).
parse_single_alter([kw(rename)|Rest], rename_table(NewName), Tail) :- !,
    parse_ident(Rest, NewName, Tail).

% Helper to identify column type tokens
is_column_type_token(T) :-
    ( T = kw(int) ; T = kw(integer) ; T = kw(bigint) ; T = kw(tinyint) ; T = kw(smallint)
    ; T = kw(float) ; T = kw(double) ; T = kw(real) ; T = kw(decimal)
    ; T = kw(varchar) ; T = kw(char) ; T = kw(text) ; T = kw(tinytext) ; T = kw(mediumtext) ; T = kw(longtext)
    ; T = kw(date) ; T = kw(time) ; T = kw(datetime) ; T = kw(timestamp) ; T = kw(year)
    ; T = kw(blob) ; T = kw(longblob)
    ), !.
parse_statement([kw(create),kw(view)|Rest], create_view(Name, SelectAST)) :-
    optional_if_not_exists(Rest, Rest2),
    parse_ident(Rest2, Name, [kw(as)|AfterAs]),
    parse_statement(AfterAs, SelectAST), !.

parse_statement([kw(drop),kw(view)|Rest], drop_view(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(create),kw(procedure)|Rest], create_procedure(Name, Params, Body)) :-
    parse_ident(Rest, Name, [sym('(')|AfterOpen]),
    take_paren_payload(AfterOpen, ParamTokens, [kw(begin)|BodyTokens]),
    parse_proc_params(ParamTokens, Params),
    take_until_kw(end, BodyTokens, RawBody, _),
    Body = raw_sql(RawBody), !.

parse_statement([kw(drop),kw(procedure)|Rest], drop_procedure(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(create),kw(function)|Rest], create_function(Name, Params, RetType, Body)) :-
    parse_ident(Rest, Name, [sym('(')|AfterOpen]),
    take_paren_payload(AfterOpen, ParamTokens, [kw(returns)|AfterReturns]),
    parse_proc_params(ParamTokens, Params),
    take_until_kw(begin, AfterReturns, RetTypeTokens, BodyTokens),
    tokens_text(RetTypeTokens, RetType),
    take_until_kw(end, BodyTokens, RawBody, _),
    Body = raw_sql(RawBody), !.

parse_statement([kw(drop),kw(function)|Rest], drop_function(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

parse_statement([kw(create),kw(trigger)|Rest], create_trigger(Name, Event, Timing, Table, Body)) :-
    parse_ident(Rest, Name, [TimingTok,EventTok,kw(on)|AfterOn]),
    token_ident(TimingTok, TimingName),
    token_ident(EventTok, EventName),
    timing_keyword(TimingName, Timing),
    event_keyword(EventName, Event),
    parse_ident(AfterOn, Table, [kw(for)|AfterFor]),
    skip_to_begin(AfterFor, BodyTokens),
    take_until_kw(end, BodyTokens, RawBody, _),
    Body = raw_sql(RawBody), !.
parse_statement([kw(create),kw(trigger)|Rest], create_trigger(Name, Event, Timing, Table, Body)) :-
    parse_ident(Rest, Name, [EventTok,TimingTok,kw(on)|AfterOn]),
    token_ident(EventTok, EventName),
    token_ident(TimingTok, TimingName),
    event_keyword(EventName, Event),
    timing_keyword(TimingName, Timing),
    parse_ident(AfterOn, Table, [kw(for)|AfterFor]),
    skip_to_begin(AfterFor, BodyTokens),
    take_until_kw(end, BodyTokens, RawBody, _),
    Body = raw_sql(RawBody), !.

parse_statement([kw(drop),kw(trigger)|Rest], drop_trigger(Name)) :-
    optional_if_exists(Rest, Rest2), parse_ident(Rest2, Name, Tail), Tail = [].

% Helper predicates
parse_proc_params([], []) :- !.
parse_proc_params(Tokens, Params) :-
    split_top_commas(Tokens, ParamParts),
    parse_proc_param_parts(ParamParts, Params).

parse_proc_param_parts([], []).
parse_proc_param_parts([Part|Parts], [param(Name, Type)|Out]) :-
    parse_proc_param_part(Part, Name, Type), !,
    parse_proc_param_parts(Parts, Out).

parse_proc_param_part([ModeTok|Tokens], Name, Type) :-
    token_ident(ModeTok, Mode),
    param_mode(Mode), !,
    parse_proc_param_part(Tokens, Name, Type).
parse_proc_param_part([NameTok|TypeToks], Name, Type) :-
    token_ident(NameTok, Name),
    tokens_text(TypeToks, Type).

param_mode(in).
param_mode(out).
param_mode(inout).

take_until_kw(Kw, Tokens, Before, After) :-
    append(Before, [kw(Kw)|After], Tokens), !.
take_until_kw(_, Tokens, Tokens, []).

skip_to_begin([kw(begin)|Ts], Ts) :- !.
skip_to_begin([_|Ts], Result) :- skip_to_begin(Ts, Result).
skip_to_begin([], []).

event_keyword(kw(insert), insert) :- !.
event_keyword(kw(update), update) :- !.
event_keyword(kw(delete), delete) :- !.
event_keyword(insert, insert) :- !.
event_keyword(update, update) :- !.
event_keyword(delete, delete).

timing_keyword(kw(before), before) :- !.
timing_keyword(kw(after), after) :- !.
timing_keyword(before, before) :- !.
timing_keyword(after, after).

optional_if_not_exists([kw(if),kw(not),kw(exists)|Rest], Rest) :- !.
optional_if_not_exists(Rest, Rest).
optional_if_exists([kw(if),kw(exists)|Rest], Rest) :- !.
optional_if_exists(Rest, Rest).

parse_ident([id(Name)|Rest], Name, Rest) :- !.
parse_ident([kw(Name)|Rest], Name, Rest) :- !.
parse_ident([str(Name)|Rest], Name, Rest) :- !.

parse_index_statement(Rest, Name, Table, Columns) :-
    parse_ident(Rest, Name, [kw(on)|AfterOn]),
    parse_ident(AfterOn, Table, [sym('(')|AfterTable]),
    take_paren_payload(AfterTable, ColTokens, Tail),
    parse_ident_list(ColTokens, Columns),
    Tail = [].

parse_user_name(Tokens, User, Rest) :- parse_ident(Tokens, User, Rest).

parse_password([str(Password)|Rest], Password, Rest) :- !.
parse_password([id(Password)|Rest], Password, Rest) :- !.
parse_password([kw(Password)|Rest], Password, Rest) :- !.

parse_scope(Tokens, Scope, Tail) :-
    take_scope_tokens(Tokens, ScopeTokens, Tail),
    ScopeTokens \= [],
    tokens_text_no_space(ScopeTokens, Scope).

take_scope_tokens([kw(to)|Rest], [], [kw(to)|Rest]) :- !.
take_scope_tokens([kw(from)|Rest], [], [kw(from)|Rest]) :- !.
take_scope_tokens([T|Ts], [T|Scope], Tail) :- take_scope_tokens(Ts, Scope, Tail).

parse_lock_targets(Tokens, Targets) :-
    split_top_commas(Tokens, Parts),
    Parts \= [],
    parse_lock_target_parts(Parts, Targets).

parse_lock_target_parts([], []).
parse_lock_target_parts([Part|Parts], [Target|Targets]) :-
    parse_lock_target(Part, Target),
    parse_lock_target_parts(Parts, Targets).

parse_lock_target([DatabaseToken,sym('.'),TableToken|_],
                  lock_target(Database, Table)) :- !,
    token_ident(DatabaseToken, Database),
    token_ident(TableToken, Table).
parse_lock_target([TableToken|_], lock_target(current, Table)) :-
    token_ident(TableToken, Table).

tokens_text_no_space(Tokens, Text) :-
    tokens_codes_no_space(Tokens, Codes),
    atom_codes(Text, Codes).

tokens_codes_no_space([], []).
tokens_codes_no_space([T|Ts], Codes) :-
    token_codes(T, C1),
    tokens_codes_no_space(Ts, C2),
    append(C1, C2, Codes).

split_once_kw(Kw, Tokens, Before, After) :-
    append(Before, [kw(Kw)|After], Tokens), !.

split_optional_where(Tokens, Before, Where) :-
    append(Before, [kw(where)|Where], Tokens), !.
split_optional_where(Tokens, Tokens, []).

take_paren_payload(Tokens, Payload, Tail) :- take_paren_payload_(Tokens, 0, [], Rev, Tail), reverse(Rev, Payload).
take_paren_payload_([sym(')')|Tail], 0, Acc, Acc, Tail) :- !.
take_paren_payload_([sym('(')|Ts], D, Acc, Payload, Tail) :- !, D2 is D + 1, take_paren_payload_(Ts, D2, [sym('(')|Acc], Payload, Tail).
take_paren_payload_([sym(')')|Ts], D, Acc, Payload, Tail) :- D > 0, !, D2 is D - 1, take_paren_payload_(Ts, D2, [sym(')')|Acc], Payload, Tail).
take_paren_payload_([T|Ts], D, Acc, Payload, Tail) :- take_paren_payload_(Ts, D, [T|Acc], Payload, Tail).

split_top_commas(Tokens, Parts) :-
    split_top_commas_(Tokens, 0, [], [], Rev),
    reverse(Rev, Ordered),
    reverse_clean(Ordered, Parts).
split_top_commas_([], _, Acc, Out, [Part|Out]) :- reverse(Acc, Part), !.
split_top_commas_([sym(',')|Ts], 0, Acc, Out, Res) :- reverse(Acc, Part), !, split_top_commas_(Ts, 0, [], [Part|Out], Res).
split_top_commas_([sym('(')|Ts], D, Acc, Out, Res) :- !, D2 is D + 1, split_top_commas_(Ts, D2, [sym('(')|Acc], Out, Res).
split_top_commas_([sym(')')|Ts], D, Acc, Out, Res) :- D > 0, !, D2 is D - 1, split_top_commas_(Ts, D2, [sym(')')|Acc], Out, Res).
split_top_commas_([T|Ts], D, Acc, Out, Res) :- split_top_commas_(Ts, D, [T|Acc], Out, Res).

reverse_clean([], []).
reverse_clean([[]|Xs], Ys) :- !, reverse_clean(Xs, Ys).
reverse_clean([X|Xs], [X|Ys]) :- reverse_clean(Xs, Ys).

parse_ident_list([], []).
parse_ident_list(Tokens, Names) :-
    split_top_commas(Tokens, Parts),
    parse_ident_parts(Parts, Names).
parse_ident_parts([], []).
parse_ident_parts([[id(N)]|Ps], [N|Ns]) :- !, parse_ident_parts(Ps, Ns).
parse_ident_parts([[kw(N)]|Ps], [N|Ns]) :- !, parse_ident_parts(Ps, Ns).
parse_ident_parts([[str(N)]|Ps], [N|Ns]) :- !, parse_ident_parts(Ps, Ns).

% A table definition can be either a column or a table-level constraint.  The
% previous parser silently discarded PRIMARY KEY, UNIQUE, CHECK, and FOREIGN
% KEY definitions here, which is unsafe: accepted DDL must never lose its
% integrity contract.
parse_table_definitions([], [], []).
parse_table_definitions([Def|Defs], Columns, Constraints) :-
    parse_table_definition(Def, Item),
    parse_table_definitions(Defs, RestColumns, RestConstraints),
    table_definition_parts(Item, Columns, Constraints, RestColumns, RestConstraints).

table_definition_parts(column(Col), [Col|Columns], Constraints, Columns, Constraints).
table_definition_parts(constraint(Constraint), Columns, [Constraint|Constraints], Columns, Constraints).

parse_table_definition(Def, constraint(Constraint)) :-
    parse_table_constraint(Def, Constraint), !.
parse_table_definition(Def, column(Col)) :-
    parse_column_def(Def, Col).

parse_column_def([NameTok|Rest], col(Name, Type, Options)) :-
    token_ident(NameTok, Name),
    split_type_options(Rest, TypeTokens, OptionTokens),
    TypeTokens \= [],
    tokens_text(TypeTokens, Type),
    parse_column_options(OptionTokens, Options).

parse_table_constraint([kw(constraint), NameTok|Rest], Constraint) :- !,
    token_ident(NameTok, Name),
    parse_table_constraint_body(Rest, Name, Constraint).
parse_table_constraint(Tokens, Constraint) :-
    parse_table_constraint_body(Tokens, unnamed, Constraint).

parse_table_constraint_body([kw(primary),kw(key)|Rest], Name, primary_key(Name, Columns)) :- !,
    parse_constraint_columns(Rest, Columns).
parse_table_constraint_body([kw(unique)|Rest], Name0, unique_key(Name, Columns)) :- !,
    skip_optional_key_keyword(Rest, AfterKey),
    parse_named_constraint_columns(AfterKey, Name0, Name, Columns).
parse_table_constraint_body([kw(key)|Rest], Name0, index_key(Name, Columns)) :- !,
    parse_named_constraint_columns(Rest, Name0, Name, Columns).
parse_table_constraint_body([kw(index)|Rest], Name0, index_key(Name, Columns)) :- !,
    parse_named_constraint_columns(Rest, Name0, Name, Columns).
parse_table_constraint_body([kw(check),sym('(')|Rest], Name, check_constraint(Name, Expr)) :- !,
    take_paren_payload(Rest, ExprTokens, []),
    parse_expr(ExprTokens, Expr).
parse_table_constraint_body([kw(foreign),kw(key)|Rest], Name,
                            foreign_key(Name, LocalColumns, RefTable, RefColumns,
                                        DeleteAction, UpdateAction)) :- !,
    parse_constraint_columns(Rest, LocalColumns, [kw(references)|AfterReferences]),
    parse_ident(AfterReferences, RefTable, [sym('(')|AfterRefOpen]),
    take_paren_payload(AfterRefOpen, RefTokens, ActionTokens),
    parse_ident_list(RefTokens, RefColumns),
    parse_fk_actions(ActionTokens, DeleteAction, UpdateAction).

skip_optional_key_keyword([kw(key)|Rest], Rest) :- !.
skip_optional_key_keyword([kw(index)|Rest], Rest) :- !.
skip_optional_key_keyword(Rest, Rest).

parse_named_constraint_columns([sym('(')|Rest], Name, Name, Columns) :- !,
    take_paren_payload(Rest, ColumnTokens, []),
    parse_ident_list(ColumnTokens, Columns).
parse_named_constraint_columns([_IndexName,sym('(')|Rest], Name, Name, Columns) :-
    Name \== unnamed, !,
    take_paren_payload(Rest, ColumnTokens, []),
    parse_ident_list(ColumnTokens, Columns).
parse_named_constraint_columns([NameTok,sym('(')|Rest], unnamed, Name, Columns) :- !,
    token_ident(NameTok, Name),
    take_paren_payload(Rest, ColumnTokens, []),
    parse_ident_list(ColumnTokens, Columns).

parse_constraint_columns([sym('(')|Rest], Columns) :- !,
    take_paren_payload(Rest, ColumnTokens, []),
    parse_ident_list(ColumnTokens, Columns).
parse_constraint_columns([sym('(')|Rest], Columns, Tail) :- !,
    take_paren_payload(Rest, ColumnTokens, Tail),
    parse_ident_list(ColumnTokens, Columns).

parse_fk_actions([], restrict, restrict).
parse_fk_actions([kw(on),kw(delete)|Rest], DeleteAction, UpdateAction) :- !,
    parse_fk_action(Rest, DeleteAction, AfterDelete),
    parse_fk_actions(AfterDelete, _IgnoredDelete, UpdateAction).
parse_fk_actions([kw(on),kw(update)|Rest], DeleteAction, UpdateAction) :- !,
    parse_fk_action(Rest, UpdateAction, AfterUpdate),
    parse_fk_actions(AfterUpdate, DeleteAction, _IgnoredUpdate).

parse_fk_action([kw(cascade)|Rest], cascade, Rest) :- !.
parse_fk_action([kw(restrict)|Rest], restrict, Rest) :- !.
parse_fk_action([kw(set),kw(null)|Rest], set_null, Rest) :- !.

token_ident(id(N), N).
token_ident(kw(N), N).
token_ident(str(N), N).

split_type_options(Tokens, TypeTokens, OptionTokens) :-
    split_type_options_(Tokens, [], TypeRev, OptionTokens), reverse(TypeRev, TypeTokens).
split_type_options_([], Acc, Acc, []).
split_type_options_([T|Ts], Acc, Acc, [T|Ts]) :- option_start(T), !.
split_type_options_([T|Ts], Acc, Type, Opt) :- split_type_options_(Ts, [T|Acc], Type, Opt).

% Extended version for ALTER TABLE that returns trailing tokens
split_type_options_ext(Tokens, TypeTokens, OptionTokens, Rest) :-
    split_type_options_ext_(Tokens, 0, [], TypeRev, OptionTokens, Rest),
    reverse(TypeRev, TypeTokens).
split_type_options_ext_([], _, TypeAcc, TypeAcc, [], []).
split_type_options_ext_([sym(',')|Ts], 0, TypeAcc, TypeAcc, [], [sym(',')|Ts]) :- !.
split_type_options_ext_([sym(';')|Ts], 0, TypeAcc, TypeAcc, [], [sym(';')|Ts]) :- !.
split_type_options_ext_([sym('(')|Ts], Depth, TypeAcc, TypeRev, OptionTokens, Rest) :- !,
    Depth1 is Depth + 1,
    split_type_options_ext_(Ts, Depth1, [sym('(')|TypeAcc], TypeRev, OptionTokens, Rest).
split_type_options_ext_([sym(')')|Ts], Depth, TypeAcc, TypeRev, OptionTokens, Rest) :- Depth > 0, !,
    Depth1 is Depth - 1,
    split_type_options_ext_(Ts, Depth1, [sym(')')|TypeAcc], TypeRev, OptionTokens, Rest).
split_type_options_ext_([T|Ts], 0, TypeAcc, TypeRev, OptionTokens, Rest) :-
    option_start(T), !,
    take_options([T|Ts], OptionTokens, Rest),
    TypeRev = TypeAcc.
split_type_options_ext_([T|Ts], Depth, TypeAcc, TypeRev, OptionTokens, Rest) :-
    split_type_options_ext_(Ts, Depth, [T|TypeAcc], TypeRev, OptionTokens, Rest).

take_options([], [], []).
take_options([sym(',')|Ts], [], [sym(',')|Ts]) :- !.
take_options([sym(';')|Ts], [], [sym(';')|Ts]) :- !.
take_options([kw(add)|Ts], [], [kw(add)|Ts]) :- !.
take_options([kw(drop)|Ts], [], [kw(drop)|Ts]) :- !.
take_options([kw(modify)|Ts], [], [kw(modify)|Ts]) :- !.
take_options([kw(change)|Ts], [], [kw(change)|Ts]) :- !.
take_options([kw(rename)|Ts], [], [kw(rename)|Ts]) :- !.
take_options([T|Ts], [T|Os], Rest) :- take_options(Ts, Os, Rest).

option_start(kw(not)). option_start(kw(null)). option_start(kw(default)).
option_start(kw(primary)). option_start(kw(key)). option_start(kw(auto_increment)).
option_start(kw(unique)). option_start(kw(check)). option_start(kw(comment)).

parse_column_options([], []).
parse_column_options([kw(not),kw(null)|Ts], [not_null|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([kw(null)|Ts], [nullable|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([kw(default),V|Ts], [default(Value)|Os]) :- !, token_value(V, Value), parse_column_options(Ts, Os).
parse_column_options([kw(primary),kw(key)|Ts], [primary_key|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([kw(auto_increment)|Ts], [auto_increment|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([kw(unique)|Ts], [unique|Os]) :- !, parse_column_options(Ts, Os).
parse_column_options([kw(check),sym('(')|Ts], [check(Expr)|Os]) :- !,
    take_paren_payload(Ts, ExprTokens, Rest),
    parse_expr(ExprTokens, Expr),
    parse_column_options(Rest, Os).
parse_column_options([T|Ts], [raw_option(T)|Os]) :- parse_column_options(Ts, Os).

parse_value_groups([], [], []).
parse_value_groups([sym('(')|Tokens], [Values|Rows], Tail) :-
    take_paren_payload(Tokens, ValueTokens, AfterGroup),
    parse_values(ValueTokens, Values),
    ( AfterGroup = [sym(',')|More] -> parse_value_groups(More, Rows, Tail)
    ; Rows = [], Tail = AfterGroup
    ).

parse_values(Tokens, Values) :-
    split_top_commas(Tokens, Parts), parse_value_parts(Parts, Values).
parse_value_parts([], []).
parse_value_parts([Tokens|Ps], [Expr|Vs]) :-
    parse_expr(Tokens, Expr), !,
    parse_value_parts(Ps, Vs).
parse_value_parts([Tokens|Ps], [raw(Raw)|Vs]) :-
    tokens_text(Tokens, Raw0),
    normalize_space(atom(Raw), Raw0),
    parse_value_parts(Ps, Vs).

token_value(num(N), N) :- !.
token_value(str(S), S) :- !.
token_value(kw(null), null) :- !.
token_value(kw(current_timestamp), current_timestamp) :- !.
token_value(id(A), A) :- !.
token_value(kw(A), A) :- !.

parse_projection([sym('*')], all) :- !.
parse_projection(Tokens, Columns) :-
    parse_ident_list(Tokens, Columns),
    Columns \= [], !.
parse_projection(Tokens, Projections) :-
    split_top_commas(Tokens, Parts),
    parse_projection_parts(Parts, Projections).

parse_projection_parts([], []).
parse_projection_parts([Part|Parts], [projection(Label, Expr)|Out]) :-
    parse_projection_part(Part, Label, Expr),
    parse_projection_parts(Parts, Out).

parse_projection_part(Tokens, Label, Expr) :-
    append(ExprTokens, [kw(as), AliasTok], Tokens),
    token_ident(AliasTok, Label), !,
    parse_expr(ExprTokens, Expr).
parse_projection_part(Tokens, Label, Expr) :-
    append(ExprTokens, [AliasTok], Tokens),
    ExprTokens \= [],
    token_ident(AliasTok, Label),
    parse_expr(ExprTokens, Expr), !.
parse_projection_part(Tokens, Label, Expr) :-
    parse_expr(Tokens, Expr),
    expr_label(Expr, Label).

split_select_source_tail(Tokens, Source, Tail) :-
    split_select_source_tail_(Tokens, 0, [], SourceRev, Tail),
    reverse(SourceRev, Source).

split_select_source_tail_([], _, Acc, Acc, []).
split_select_source_tail_([kw(where)|Rest], 0, Acc, Acc, [kw(where)|Rest]) :- !.
split_select_source_tail_([kw(group),kw(by)|Rest], 0, Acc, Acc, [kw(group),kw(by)|Rest]) :- !.
split_select_source_tail_([kw(order),kw(by)|Rest], 0, Acc, Acc, [kw(order),kw(by)|Rest]) :- !.
split_select_source_tail_([kw(limit)|Rest], 0, Acc, Acc, [kw(limit)|Rest]) :- !.
split_select_source_tail_([sym('(')|Ts], D, Acc, Source, Tail) :- !,
    D1 is D + 1,
    split_select_source_tail_(Ts, D1, [sym('(')|Acc], Source, Tail).
split_select_source_tail_([sym(')')|Ts], D, Acc, Source, Tail) :- D > 0, !,
    D1 is D - 1,
    split_select_source_tail_(Ts, D1, [sym(')')|Acc], Source, Tail).
split_select_source_tail_([T|Ts], D, Acc, Source, Tail) :-
    split_select_source_tail_(Ts, D, [T|Acc], Source, Tail).

parse_from_source(Tokens, Source) :-
    parse_table_ref(Tokens, Left, Rest),
    parse_join_tail(Rest, Left, Source).

parse_join_tail([], Source, Source) :- !.
parse_join_tail([kw(inner),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, inner, Left, Source).
parse_join_tail([kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, inner, Left, Source).
parse_join_tail([kw(left),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, left, Left, Source).
parse_join_tail([kw(left),kw(outer),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, left, Left, Source).
parse_join_tail([kw(right),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, right, Left, Source).
parse_join_tail([kw(right),kw(outer),kw(join)|Rest], Left, Source) :- !,
    parse_join_right(Rest, right, Left, Source).
parse_join_tail([kw(cross),kw(join)|Rest], Left, Source) :- !,
    parse_cross_join_right(Rest, Left, Source).
parse_join_tail([sym(',')|Rest], Left, Source) :- !,
    parse_cross_join_right(Rest, Left, Source).

parse_join_right(Tokens, Kind, Left, Source) :-
    parse_table_ref(Tokens, Right, [kw(on)|AfterOn]),
    split_join_on_tail(AfterOn, OnTokens, Rest),
    parse_where_tokens(OnTokens, On),
    parse_join_tail(Rest, join(Kind, Left, Right, On), Source).
parse_join_right(Tokens, Kind, Left, Source) :-
    parse_table_ref(Tokens, Right, [kw(using),sym('(')|AfterOpen]),
    take_paren_payload(AfterOpen, UsingTokens, Rest),
    parse_ident_list(UsingTokens, UsingColumns),
    UsingColumns \= [],
    join_using_condition(UsingColumns, Left, Right, On),
    parse_join_tail(Rest, join(Kind, Left, Right, On), Source).

parse_cross_join_right(Tokens, Left, Source) :-
    parse_table_ref(Tokens, Right, Rest),
    parse_join_tail(Rest, join(inner, Left, Right, true), Source).

join_using_condition([Column|Columns], Left, Right, On) :-
    table_ref_qualifier(Left, LeftQualifier),
    table_ref_qualifier(Right, RightQualifier),
    First = cmp('=', qcol(LeftQualifier, Column),
                     qcol(RightQualifier, Column)),
    join_using_conditions(Columns, LeftQualifier, RightQualifier, First, On).

join_using_conditions([], _, _, On, On).
join_using_conditions([Column|Columns], LeftQualifier, RightQualifier,
                      Acc, On) :-
    Condition = cmp('=', qcol(LeftQualifier, Column),
                         qcol(RightQualifier, Column)),
    join_using_conditions(Columns, LeftQualifier, RightQualifier,
                          and(Acc, Condition), On).

table_ref_qualifier(table_ref(Table, none), Table) :- !.
table_ref_qualifier(table_ref(_, Alias), Alias).

split_join_on_tail(Tokens, On, Rest) :-
    split_join_on_tail_(Tokens, 0, [], OnRev, Rest),
    reverse(OnRev, On).

split_join_on_tail_([], _, Acc, Acc, []).
split_join_on_tail_([kw(inner),kw(join)|Rest], 0, Acc, Acc, [kw(inner),kw(join)|Rest]) :- !.
split_join_on_tail_([kw(join)|Rest], 0, Acc, Acc, [kw(join)|Rest]) :- !.
split_join_on_tail_([kw(left),kw(join)|Rest], 0, Acc, Acc, [kw(left),kw(join)|Rest]) :- !.
split_join_on_tail_([kw(left),kw(outer),kw(join)|Rest], 0, Acc, Acc, [kw(left),kw(outer),kw(join)|Rest]) :- !.
split_join_on_tail_([kw(right),kw(join)|Rest], 0, Acc, Acc, [kw(right),kw(join)|Rest]) :- !.
split_join_on_tail_([kw(right),kw(outer),kw(join)|Rest], 0, Acc, Acc, [kw(right),kw(outer),kw(join)|Rest]) :- !.
split_join_on_tail_([kw(cross),kw(join)|Rest], 0, Acc, Acc, [kw(cross),kw(join)|Rest]) :- !.
split_join_on_tail_([sym(',')|Rest], 0, Acc, Acc, [sym(',')|Rest]) :- !.
split_join_on_tail_([sym('(')|Ts], D, Acc, On, Rest) :- !,
    D1 is D + 1,
    split_join_on_tail_(Ts, D1, [sym('(')|Acc], On, Rest).
split_join_on_tail_([sym(')')|Ts], D, Acc, On, Rest) :- D > 0, !,
    D1 is D - 1,
    split_join_on_tail_(Ts, D1, [sym(')')|Acc], On, Rest).
split_join_on_tail_([T|Ts], D, Acc, On, Rest) :-
    split_join_on_tail_(Ts, D, [T|Acc], On, Rest).

parse_table_ref(Tokens, table_ref(Name, Alias), Tail) :-
    parse_ident(Tokens, Name, Rest),
    parse_optional_table_alias(Rest, Alias, Tail).

parse_optional_table_alias([kw(as),AliasTok|Rest], Alias, Rest) :-
    token_ident(AliasTok, Alias), !.
parse_optional_table_alias([Tok|Rest], Alias, Rest) :-
    token_ident(Tok, Alias),
    \+ select_source_boundary_token(Tok), !.
parse_optional_table_alias(Rest, none, Rest).

select_source_boundary_token(kw(inner)).
select_source_boundary_token(kw(join)).
select_source_boundary_token(kw(left)).
select_source_boundary_token(kw(right)).
select_source_boundary_token(kw(cross)).
select_source_boundary_token(kw(outer)).
select_source_boundary_token(kw(on)).
select_source_boundary_token(kw(using)).
select_source_boundary_token(sym(',')).

parse_select_tail_ext([], true, none, none, none) :- !.
parse_select_tail_ext(Tokens, Where, Group, Order, Limit) :-
    extract_clause_ext(where, Tokens, WhereTokens, Rest1),
    parse_where_tokens(WhereTokens, Where),
    extract_group(Rest1, Group, Rest2),
    extract_order(Rest2, Order, Rest3),
    extract_limit(Rest3, Limit, _).

extract_clause_ext(Kw, [kw(Kw)|Tokens], Clause, Rest) :- !,
    take_until_clause_ext(Tokens, Clause, Rest).
extract_clause_ext(_, Tokens, [], Tokens).

take_until_clause_ext([], [], []).
take_until_clause_ext([kw(group),kw(by)|Rest], [], [kw(group),kw(by)|Rest]) :- !.
take_until_clause_ext([kw(order),kw(by)|Rest], [], [kw(order),kw(by)|Rest]) :- !.
take_until_clause_ext([kw(limit)|Rest], [], [kw(limit)|Rest]) :- !.
take_until_clause_ext([T|Ts], [T|Clause], Rest) :- take_until_clause_ext(Ts, Clause, Rest).

extract_group([kw(group),kw(by)|Tokens], group(Items), Rest) :- !,
    take_until_order_limit(Tokens, Raw, Rest),
    parse_group_items(Raw, Items).
extract_group(Tokens, none, Tokens).

take_until_order_limit([], [], []).
take_until_order_limit([kw(order),kw(by)|Rest], [], [kw(order),kw(by)|Rest]) :- !.
take_until_order_limit([kw(limit)|Rest], [], [kw(limit)|Rest]) :- !.
take_until_order_limit([T|Ts], [T|Raw], Rest) :- take_until_order_limit(Ts, Raw, Rest).

parse_group_items([], []).
parse_group_items(Tokens, Items) :-
    split_top_commas(Tokens, Parts),
    parse_expr_parts(Parts, Items).

parse_union_right([kw(all)|Tokens], Right, all) :- !,
    parse_statement(Tokens, Right).
parse_union_right(Tokens, Right, distinct) :-
    parse_statement(Tokens, Right).

parse_select_tail([], true, none, none) :- !.
parse_select_tail(Tokens, Where, Order, Limit) :-
    extract_clause(where, Tokens, WhereTokens, Rest1),
    parse_where_tokens(WhereTokens, Where),
    extract_order(Rest1, Order, Rest2),
    extract_limit(Rest2, Limit, _).

extract_clause(Kw, Tokens, Clause, Rest) :-
    append(_, [kw(Kw)|_], Tokens), !,
    append(Before, [kw(Kw)|After], Tokens),
    Before = [],
    take_until_clause(After, Clause, Rest).
extract_clause(_, Tokens, [], Tokens).

take_until_clause([], [], []).
take_until_clause([kw(order),kw(by)|Rest], [], [kw(order),kw(by)|Rest]) :- !.
take_until_clause([kw(limit)|Rest], [], [kw(limit)|Rest]) :- !.
take_until_clause([T|Ts], [T|Clause], Rest) :- take_until_clause(Ts, Clause, Rest).

extract_order([kw(order),kw(by)|Tokens], order(Items), Rest) :- !,
    take_until_limit(Tokens, Raw, Rest),
    parse_order_items(Raw, Items).
extract_order(Tokens, none, Tokens).

take_until_limit([], [], []).
take_until_limit([kw(limit)|Rest], [], [kw(limit)|Rest]) :- !.
take_until_limit([T|Ts], [T|Raw], Rest) :- take_until_limit(Ts, Raw, Rest).

extract_limit([kw(limit),num(Offset),sym(','),num(N)|Rest], limit(Offset,N), Rest) :- !.
extract_limit([kw(limit),num(N),kw(offset),num(Offset)|Rest], limit(Offset,N), Rest) :- !.
extract_limit([kw(limit),num(N)|Rest], limit(0,N), Rest) :- !.
extract_limit(Tokens, none, Tokens).

parse_order_items([], []).
parse_order_items(Tokens, Items) :-
    split_top_commas(Tokens, Parts),
    parse_order_parts(Parts, Items).

parse_order_parts([], []).
parse_order_parts([Part|Parts], [order(Expr, Dir)|Out]) :-
    parse_order_part(Part, Expr, Dir),
    parse_order_parts(Parts, Out).

parse_order_part(Tokens, Expr, desc) :-
    append(ExprTokens, [kw(desc)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_order_part(Tokens, Expr, asc) :-
    append(ExprTokens, [kw(asc)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_order_part(Tokens, Expr, asc) :- parse_expr(Tokens, Expr).

parse_assignments([], []).
parse_assignments([Part|Parts], [assign(Name, Value)|As]) :-
    parse_assignment(Part, assign(Name, Value)), !,
    parse_assignments(Parts, As).
parse_assignment([NameTok,op('=')|ValueTokens], assign(Name, Expr)) :-
    token_ident(NameTok, Name), parse_expr(ValueTokens, Expr).

parse_where_tokens([], true) :- !.
parse_where_tokens(Tokens, Where) :- parse_expr(Tokens, Where), !.
parse_where_tokens(Tokens, raw_where(Tokens)).

parse_expr([sym('(')|Tokens], subquery(SelectAST)) :-
    take_paren_payload(Tokens, Inner, []),
    Inner = [kw(select)|_], !,
    parse_statement(Inner, SelectAST).
% INSERT/backup workloads are dominated by one-token literals. Resolve those
% before running the precedence splitters; this preserves the same primary AST
% while avoiding a dozen whole-list probes for every value in a large batch.
parse_expr([Token], Expr) :-
    parse_primary([Token], Expr), !.
parse_expr(Tokens, Expr) :- strip_outer_parens(Tokens, Inner), Inner \= Tokens, !, parse_expr(Inner, Expr).
parse_expr(Tokens, or(A,B)) :-
    split_top_level_kw(or, Tokens, Left, Right), !,
    parse_expr(Left, A), parse_expr(Right, B).
parse_expr(Tokens, xor(A,B)) :-
    split_top_level_kw(xor, Tokens, Left, Right), !,
    parse_expr(Left, A), parse_expr(Right, B).
parse_expr(Tokens, between(Expr, Low, High)) :-
    split_top_level_kw(between, Tokens, Left, AfterBetween),
    split_top_level_kw(and, AfterBetween, LowTokens, HighTokens), !,
    parse_expr(Left, Expr), parse_expr(LowTokens, Low), parse_expr(HighTokens, High).
parse_expr(Tokens, and(A,B)) :-
    split_top_level_kw(and, Tokens, Left, Right), !,
    parse_expr(Left, A), parse_expr(Right, B).
parse_expr([kw(not)|Tokens], not(Expr)) :- !, parse_expr(Tokens, Expr).
parse_expr(Tokens, cmp(Op, A, B)) :-
    % The comparison-aware splitter skips arithmetic operators in one pass.
    % The old generic splitter committed to the first `+` or `/`; enumerating
    % every comparison fixed correctness but multiplied large-INSERT parse
    % work. This retains both correctness and linear scanning.
    split_top_level_comparison(Tokens, Op, Left, Right), !,
    parse_expr(Left, A), parse_expr(Right, B).
parse_expr(Tokens, is_null(Expr)) :-
    append(ExprTokens, [kw(is),kw(null)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, is_not_null(Expr)) :-
    append(ExprTokens, [kw(is),kw(not),kw(null)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, is_true(Expr)) :-
    append(ExprTokens, [kw(is),kw(true)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, is_false(Expr)) :-
    append(ExprTokens, [kw(is),kw(false)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, is_unknown(Expr)) :-
    append(ExprTokens, [kw(is),kw(unknown)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, not(is_true(Expr))) :-
    append(ExprTokens, [kw(is),kw(not),kw(true)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, not(is_false(Expr))) :-
    append(ExprTokens, [kw(is),kw(not),kw(false)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, not(is_unknown(Expr))) :-
    append(ExprTokens, [kw(is),kw(not),kw(unknown)], Tokens), !,
    parse_expr(ExprTokens, Expr).
parse_expr(Tokens, like(Expr, Pattern)) :-
    split_top_level_kw(like, Tokens, Left, Right), !,
    parse_expr(Left, Expr), parse_expr(Right, Pattern).
parse_expr(Tokens, in_subquery(Expr, SelectAST)) :-
    split_top_level_kw(in, Tokens, Left, [sym('(')|AfterIn]),
    take_paren_payload(AfterIn, SelectTokens, []),
    SelectTokens = [kw(select)|_], !,
    parse_expr(Left, Expr),
    parse_statement(SelectTokens, SelectAST).
parse_expr(Tokens, in_list(Expr, Values)) :-
    split_top_level_kw(in, Tokens, Left, [sym('(')|AfterIn]),
    take_paren_payload(AfterIn, ValueTokens, []), !,
    parse_expr(Left, Expr),
    parse_expr_list(ValueTokens, Values).
parse_expr([kw(exists),sym('(')|Rest], exists_subquery(SelectAST)) :-
    take_paren_payload(Rest, SelectTokens, []),
    SelectTokens = [kw(select)|_], !,
    parse_statement(SelectTokens, SelectAST).
parse_expr(Tokens, Expr) :- parse_additive(Tokens, Expr).

parse_additive(Tokens, add(A,B)) :-
    split_top_level_op('+', Tokens, Left, Right), !,
    parse_additive(Left, A), parse_multiplicative(Right, B).
parse_additive(Tokens, sub(A,B)) :-
    split_top_level_op('-', Tokens, Left, Right), Left \= [], !,
    parse_additive(Left, A), parse_multiplicative(Right, B).
parse_additive(Tokens, Expr) :- parse_multiplicative(Tokens, Expr).

parse_multiplicative(Tokens, mul(A,B)) :-
    split_top_level_sym('*', Tokens, Left, Right), !,
    parse_multiplicative(Left, A), parse_unary(Right, B).
parse_multiplicative(Tokens, div(A,B)) :-
    split_top_level_op('/', Tokens, Left, Right), !,
    parse_multiplicative(Left, A), parse_unary(Right, B).
parse_multiplicative(Tokens, Expr) :- parse_unary(Tokens, Expr).

parse_unary([op('-')|Tokens], neg(Expr)) :- !, parse_primary(Tokens, Expr).
parse_unary(Tokens, Expr) :- parse_primary(Tokens, Expr).

parse_primary([num(N)], value(N)) :- !.
parse_primary([str(S)], value(S)) :- !.
parse_primary([kw(null)], value(null)) :- !.
parse_primary([kw(true)], value(true)) :- !.
parse_primary([kw(false)], value(false)) :- !.
parse_primary([kw(unknown)], value(null)) :- !.
parse_primary([kw(current_timestamp)], value(current_timestamp)) :- !.
parse_primary([sym('*')], all) :- !.
parse_primary([kw(case)|Tokens], case(Whens, Else)) :-
    parse_case_expression(Tokens, Whens, Else), !.
parse_primary([QualifierTok,sym('.'),NameTok], qcol(Qualifier, Name)) :-
    token_ident(QualifierTok, Qualifier),
    token_ident(NameTok, Name), !.
parse_primary([id(Name0),sym('(')|Rest], func(Name, Args)) :-
    take_paren_payload(Rest, ArgTokens, []), !,
    downcase_atom(Name0, Name),
    parse_expr_list(ArgTokens, Args).
parse_primary([kw(Name),sym('(')|Rest], func(Name, Args)) :-
    take_paren_payload(Rest, ArgTokens, []), !,
    parse_expr_list(ArgTokens, Args).
parse_primary([id(Name)], col(Name)) :- !.
parse_primary([kw(Name)], col(Name)) :- !.
parse_primary([sym('(')|Tokens], subquery(SelectAST)) :-
    take_paren_payload(Tokens, Inner, []),
    Inner = [kw(select)|_], !,
    parse_statement(Inner, SelectAST).
parse_primary([sym('(')|Tokens], Expr) :-
    take_paren_payload(Tokens, Inner, []), !,
    parse_expr(Inner, Expr).

parse_expr_list([], []) :- !.
parse_expr_list([sym('*')], [all]) :- !.
parse_expr_list(Tokens, Exprs) :-
    split_top_commas(Tokens, Parts),
    parse_expr_parts(Parts, Exprs).

parse_expr_parts([], []).
parse_expr_parts([Part|Parts], [Expr|Exprs]) :-
    parse_expr(Part, Expr),
    parse_expr_parts(Parts, Exprs).

parse_case_expression(Tokens, Whens, Else) :-
    take_until_case_end(Tokens, Body, []),
    ( Body = [kw(when)|_] ->
        parse_case_whens(Body, Whens, Else)
    ;   split_top_level_kw(when, Body, BaseTokens, AfterWhen),
        parse_expr(BaseTokens, Base),
        parse_simple_case_whens(Base, [kw(when)|AfterWhen], Whens, Else)
    ).

take_until_case_end(Tokens, Body, Rest) :-
    take_until_case_end_(Tokens, 0, [], Rev, Rest),
    reverse(Rev, Body).

take_until_case_end_([], _, Acc, Acc, []).
take_until_case_end_([kw(case)|Tokens], Depth, Acc, Body, Rest) :- !,
    D1 is Depth + 1,
    take_until_case_end_(Tokens, D1, [kw(case)|Acc], Body, Rest).
take_until_case_end_([kw(end)|Tokens], 0, Acc, Acc, Tokens) :- !.
take_until_case_end_([kw(end)|Tokens], Depth, Acc, Body, Rest) :- Depth > 0, !,
    D1 is Depth - 1,
    take_until_case_end_(Tokens, D1, [kw(end)|Acc], Body, Rest).
take_until_case_end_([T|Tokens], Depth, Acc, Body, Rest) :-
    take_until_case_end_(Tokens, Depth, [T|Acc], Body, Rest).

parse_case_whens([kw(when)|Tokens], [when(Condition, Value)|Whens], Else) :- !,
    split_top_level_kw(then, Tokens, ConditionTokens, AfterThen),
    take_until_case_next(AfterThen, ValueTokens, Rest),
    parse_expr(ConditionTokens, Condition),
    parse_expr(ValueTokens, Value),
    parse_case_rest(Rest, Whens, Else).

parse_simple_case_whens(Base, [kw(when)|Tokens], [when(cmp('=', Base, Match), Value)|Whens], Else) :- !,
    split_top_level_kw(then, Tokens, MatchTokens, AfterThen),
    take_until_case_next(AfterThen, ValueTokens, Rest),
    parse_expr(MatchTokens, Match),
    parse_expr(ValueTokens, Value),
    parse_simple_case_rest(Base, Rest, Whens, Else).

parse_case_rest([kw(when)|Tokens], Whens, Else) :- !,
    parse_case_whens([kw(when)|Tokens], Whens, Else).
parse_case_rest([kw(else)|Tokens], [], Else) :- !,
    parse_expr(Tokens, Else).
parse_case_rest([], [], value(null)).

parse_simple_case_rest(Base, [kw(when)|Tokens], Whens, Else) :- !,
    parse_simple_case_whens(Base, [kw(when)|Tokens], Whens, Else).
parse_simple_case_rest(_, [kw(else)|Tokens], [], Else) :- !,
    parse_expr(Tokens, Else).
parse_simple_case_rest(_, [], [], value(null)).

take_until_case_next(Tokens, ExprTokens, Rest) :-
    take_until_case_next_(Tokens, 0, [], Rev, Rest),
    reverse(Rev, ExprTokens).

take_until_case_next_([], _, Acc, Acc, []).
take_until_case_next_([kw(when)|Rest], 0, Acc, Acc, [kw(when)|Rest]) :- !.
take_until_case_next_([kw(else)|Rest], 0, Acc, Acc, [kw(else)|Rest]) :- !.
take_until_case_next_([kw(case)|Tokens], Depth, Acc, Expr, Rest) :- !,
    D1 is Depth + 1,
    take_until_case_next_(Tokens, D1, [kw(case)|Acc], Expr, Rest).
take_until_case_next_([kw(end)|Tokens], Depth, Acc, Expr, Rest) :- Depth > 0, !,
    D1 is Depth - 1,
    take_until_case_next_(Tokens, D1, [kw(end)|Acc], Expr, Rest).
take_until_case_next_([sym('(')|Tokens], Depth, Acc, Expr, Rest) :- !,
    D1 is Depth + 1,
    take_until_case_next_(Tokens, D1, [sym('(')|Acc], Expr, Rest).
take_until_case_next_([sym(')')|Tokens], Depth, Acc, Expr, Rest) :- Depth > 0, !,
    D1 is Depth - 1,
    take_until_case_next_(Tokens, D1, [sym(')')|Acc], Expr, Rest).
take_until_case_next_([T|Tokens], Depth, Acc, Expr, Rest) :-
    take_until_case_next_(Tokens, Depth, [T|Acc], Expr, Rest).

comparison_op('='). comparison_op('!='). comparison_op('<>').
comparison_op('>'). comparison_op('<'). comparison_op('>=').
comparison_op('<=').

strip_outer_parens([sym('(')|Tokens], Inner) :-
    take_paren_payload(Tokens, Inner, []), !.
strip_outer_parens(Tokens, Tokens).

split_top_level_kw(Kw, Tokens, Left, Right) :-
    split_top_level_token(kw(Kw), Tokens, Left, Right).

split_top_level_op(Op, Tokens, Left, Right) :-
    split_top_level_token(op(Op), Tokens, Left, Right).

split_top_level_sym(Sym, Tokens, Left, Right) :-
    split_top_level_token(sym(Sym), Tokens, Left, Right).

split_top_level_comparison(Tokens, Op, Left, Right) :-
    split_top_level_comparison_(Tokens, 0, [], Op, Left, Right).

split_top_level_comparison_([], _, _, _, _, _) :- fail.
split_top_level_comparison_([op(Op)|Tokens], 0, Acc, Op, Left, Tokens) :-
    comparison_op(Op), !,
    reverse(Acc, Left),
    Left \= [].
split_top_level_comparison_([sym('(')|Tokens], Depth, Acc, Op, Left, Right) :- !,
    NextDepth is Depth + 1,
    split_top_level_comparison_(Tokens, NextDepth, [sym('(')|Acc],
                                Op, Left, Right).
split_top_level_comparison_([sym(')')|Tokens], Depth, Acc, Op, Left, Right) :-
    Depth > 0, !,
    NextDepth is Depth - 1,
    split_top_level_comparison_(Tokens, NextDepth, [sym(')')|Acc],
                                Op, Left, Right).
split_top_level_comparison_([kw(case)|Tokens], Depth, Acc, Op, Left, Right) :- !,
    NextDepth is Depth + 1,
    split_top_level_comparison_(Tokens, NextDepth, [kw(case)|Acc],
                                Op, Left, Right).
split_top_level_comparison_([kw(end)|Tokens], Depth, Acc, Op, Left, Right) :-
    Depth > 0, !,
    NextDepth is Depth - 1,
    split_top_level_comparison_(Tokens, NextDepth, [kw(end)|Acc],
                                Op, Left, Right).
split_top_level_comparison_([Token|Tokens], Depth, Acc, Op, Left, Right) :-
    split_top_level_comparison_(Tokens, Depth, [Token|Acc],
                                Op, Left, Right).

split_top_level_token(Target, Tokens, Left, Right) :-
    split_top_level_token_(Tokens, Target, 0, [], Left, Right).

split_top_level_token_([], _, _, _, _, _) :- fail.
split_top_level_token_([Target|Ts], Target, 0, Acc, Left, Ts) :- !, reverse(Acc, Left), Left \= [].
split_top_level_token_([sym('(')|Ts], Target, D, Acc, Left, Right) :- !,
    D1 is D + 1, split_top_level_token_(Ts, Target, D1, [sym('(')|Acc], Left, Right).
split_top_level_token_([sym(')')|Ts], Target, D, Acc, Left, Right) :- D > 0, !,
    D1 is D - 1, split_top_level_token_(Ts, Target, D1, [sym(')')|Acc], Left, Right).
split_top_level_token_([kw(case)|Ts], Target, D, Acc, Left, Right) :- !,
    D1 is D + 1, split_top_level_token_(Ts, Target, D1, [kw(case)|Acc], Left, Right).
split_top_level_token_([kw(end)|Ts], Target, D, Acc, Left, Right) :- D > 0, !,
    D1 is D - 1, split_top_level_token_(Ts, Target, D1, [kw(end)|Acc], Left, Right).
split_top_level_token_([T|Ts], Target, D, Acc, Left, Right) :-
    split_top_level_token_(Ts, Target, D, [T|Acc], Left, Right).

expr_label(col(Name), Name) :- !.
expr_label(qcol(Qualifier, Name), Label) :- !,
    qualified_column_atom(Qualifier, Name, Label).
expr_label(func(Name, _), Name) :- !.
expr_label(Expr, Label) :- term_atom_safe(Expr, Label).

tokens_text(Tokens, Text) :-
    tokens_codes(Tokens, Codes), atom_codes(Text, Codes).

tokens_codes([], []).
tokens_codes([T|Ts], Codes) :- token_codes(T, C1), tokens_codes(Ts, C2), append(C1, [32|C2], Codes).

token_codes(kw(A), C) :- atom_codes(A, C).
token_codes(id(A), C) :- atom_codes(A, C).
token_codes(str(A), C) :- atom_codes(A, AC), append([39|AC], [39], C).
token_codes(num(N), C) :- number_codes(N, C).
token_codes(sym(S), C) :- atom_codes(S, C).
token_codes(op(O), C) :- atom_codes(O, C).
token_codes(char(C), [C]).

% Public token-level entry point used by the executor when it normalizes a
% compatibility fallback into a standard AsaDB statement.
asadb_parse_statement(Tokens, Statement) :-
    parse_statement(Tokens, Statement).

qualified_column_atom(Qualifier, Name, Atom) :-
    atomic_list_concat([Qualifier, Name], '.', Atom).

term_atom_safe(Term, Atom) :-
    atom(Term), !,
    Atom = Term.
term_atom_safe(Term, Atom) :-
    term_to_atom(Term, Atom).
