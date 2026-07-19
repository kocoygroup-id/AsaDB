% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* Portable AsA executable entrypoint. */

:- set_prolog_flag(double_quotes, codes).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(readutil)).
:- use_module(library(www_browser)).
:- ensure_loaded('asadb_web.pl').

asa_entry :-
    asa_entry_.

asa_entry_ :-
    ensure_portable_root,
    current_prolog_flag(argv, Argv),
    dispatch_asa(Argv).

dispatch_asa([]) :- !,
    start_panel('data.asa', 8088, true).
dispatch_asa(['--help'|_]) :- !,
    print_help.
dispatch_asa(['help'|_]) :- !,
    print_help.
dispatch_asa(['panel'|Args]) :- !,
    panel_args(Args, DbFile, Port, OpenBrowser),
    start_panel(DbFile, Port, OpenBrowser).
dispatch_asa(['web'|Args]) :- !,
    panel_args(Args, DbFile, Port, OpenBrowser),
    start_panel(DbFile, Port, OpenBrowser).
dispatch_asa(['cli', DbFile, SqlFile|_]) :- !,
    run_sql_file(DbFile, SqlFile).
dispatch_asa(['cli', DbFile|_]) :- !,
    run_repl(DbFile).
dispatch_asa([DbFile, SqlFile|_]) :- !,
    run_sql_file(DbFile, SqlFile).
dispatch_asa([DbFile|_]) :- !,
    start_panel(DbFile, 8088, true).

panel_args([], 'data.asa', 8088, true).
panel_args(['--no-browser'|Rest], DbFile, Port, false) :- !,
    panel_args(Rest, DbFile, Port, _).
panel_args([DbFile], DbFile, 8088, true) :- !.
panel_args([DbFile, PortAtom|_], DbFile, Port, true) :-
    parse_port(PortAtom, 8088, Port).

parse_port(Value, _Default, Port) :-
    atom(Value),
    atom_number(Value, Number),
    integer(Number),
    Number > 0, !,
    Port = Number.
parse_port(_, Default, Default).

start_panel(DbFile, PreferredPort, OpenBrowser) :-
    init_panel_token,
    asadb_boot(DbFile),
    asadb_warmup,
    asadb_init_reservoir(DbFile),
    asadb_start_http_on_available_port(PreferredPort, Port),
    asadb_write_panel_port_file(Port),
    format(atom(URL), 'http://127.0.0.1:~w/', [Port]),
    nl,
    format('AsA / AsaDB Admin~n', []),
    format('Database : ~w~n', [DbFile]),
    format('Panel    : ~w~n', [URL]),
    format('Press Ctrl+C to stop.~n~n', []),
    maybe_open_browser(OpenBrowser, URL),
    wait_forever.

maybe_open_browser(false, _) :- !.
maybe_open_browser(true, URL) :-
    catch(www_open_url(URL), _, fail), !.
maybe_open_browser(true, URL) :-
    current_prolog_flag(windows, true), !,
    atomic_list_concat(['start "" "', URL, '"'], Command),
    shell(Command).
maybe_open_browser(_, _).

run_sql_file(DbFile, SqlFile) :-
    asadb_boot(DbFile),
    read_file_to_codes(SqlFile, Codes, []),
    asadb_exec_sql(Codes, Result),
    asadb_format_result(Result),
    asadb_shutdown,
    halt(0).

run_repl(DbFile) :-
    asadb_boot(DbFile),
    repl_loop,
    asadb_shutdown,
    halt(0).

repl_loop :-
    writeln('AsA / AsaDB REPL. End SQL with semicolon. Type .quit to exit.'),
    repl_loop_.

repl_loop_ :-
    write('asa> '), flush_output,
    read_line_to_codes(user_input, Codes),
    (   Codes == end_of_file
    ->  true
    ;   atom_codes(Atom, Codes),
        Atom == '.quit'
    ->  true
    ;   asadb_exec_sql(Codes, Result),
        asadb_format_result(Result),
        repl_loop_
    ).

print_help :-
    writeln('AsA - portable AsaDB executable'),
    writeln(''),
    writeln('Usage:'),
    writeln('  AsA.exe                         Start local AsAPanel on data.asa'),
    writeln('  AsA.exe panel [db.asa] [port]    Start local AsAPanel'),
    writeln('  AsA.exe panel --no-browser       Start panel without opening browser'),
    writeln('  AsA.exe cli data.asa script.sql  Run SQL file'),
    writeln('  AsA.exe cli data.asa             Start REPL'),
    halt(0).

ensure_portable_root :-
    current_prolog_flag(executable, Exe),
    file_directory_name(Exe, Dir),
    directory_file_path(Dir, 'web/index.html', WebIndex),
    exists_file(WebIndex), !,
    working_directory(_, Dir).
ensure_portable_root.

asa_fatal(Error) :-
    message_to_string(Error, Message),
    format(user_error, 'AsA fatal: ~w~n', [Message]),
    halt(1).
