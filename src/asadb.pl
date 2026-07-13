#!/usr/bin/env swipl
% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* AsaDB CLI entrypoint */

:- use_module('asadb_core.pl').
:- initialization(main, main).

main :-
    current_prolog_flag(argv, Argv),
    run_argv(Argv), !.
main :-
    writeln('AsaDB fatal: invalid arguments.'),
    halt(1).

run_argv([DbFile, SqlFile|_]) :- !,
    asadb_boot(DbFile),
    read_file_to_codes(SqlFile, Codes, []),
    asadb_exec_sql(Codes, Result),
    asadb_format_result(Result),
    asadb_shutdown,
    halt(0).
run_argv([DbFile]) :- !,
    asadb_boot(DbFile),
    repl,
    asadb_shutdown,
    halt(0).
run_argv(_) :-
    writeln('AsaDB - Prolog SQL engine'),
    writeln('Usage:'),
    writeln('  swipl -q -s src/asadb.pl -- data.asa script.sql'),
    writeln('  swipl -q -s src/asadb.pl -- data.asa'),
    halt(0).

repl :-
    writeln('AsaDB REPL. Ketik SQL lalu akhiri dengan titik-koma. Ketik .quit untuk keluar.'),
    repl_loop.

repl_loop :-
    write('asadb> '), flush_output,
    read_line_to_codes(user_input, Codes),
    ( Codes == end_of_file -> true
    ; atom_codes(Atom, Codes), Atom == '.quit' -> true
    ; asadb_exec_sql(Codes, Result), asadb_format_result(Result), repl_loop
    ).
