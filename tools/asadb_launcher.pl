% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* Cross-platform source/pack launcher for Local and Server modes.

   Run from a checkout or installed pack directory:

       swipl asadb
       swipl asadb local --database data.asa
       swipl asadb doctor

   The pack app is available on SWI-Prolog 9.1.18 and newer.  The explicit
   `-s` form remains useful when running a source checkout.
*/

:- module(asadb_launcher, [main/0]).

:- use_module(library(process)).
:- use_module(library(lists)).
:- initialization(main, main).

main :-
    current_prolog_flag(argv, Arguments),
    catch(dispatch(Arguments), Error,
          ( print_message(error, Error), halt(1) )),
    halt.

% A bare `swipl asadb` is deliberately useful: start the authenticated portal
% with the safe defaults.  The first run creates one administrator before any
% workspace is exposed.
dispatch([]) :- !, root_directory(Root), run_python(Root, [start]).
dispatch([help|_]) :- !, usage.
dispatch(['--help'|_]) :- !, usage.
dispatch([version|_]) :- !, root_directory(Root), run_python(Root, [version]).
dispatch([local|Arguments]) :- !, root_directory(Root), local_arguments(Arguments, Database, Rest),
    run_swipl(Root, 'src/asadb.pl', [Database|Rest]).
dispatch([panel|Arguments]) :- !, root_directory(Root), panel_arguments(Arguments, Database, Port),
    run_python(Root, [start, '--database', Database, '--port', Port]).
dispatch([python|Arguments]) :- !, root_directory(Root), python_command(Arguments, Command),
    run_python(Root, Command).
dispatch([doctor|Arguments]) :- !, root_directory(Root), run_python(Root, [doctor|Arguments]).
dispatch([init|Arguments]) :- !, root_directory(Root), run_python(Root, [init|Arguments]).
dispatch([start|Arguments]) :- !, root_directory(Root), run_python(Root, [start|Arguments]).
dispatch([server|Arguments]) :- !, root_directory(Root), run_python(Root, [server|Arguments]).
dispatch([remote|Arguments]) :- !, root_directory(Root), run_python(Root, [remote|Arguments]).
dispatch([config|_]) :- !, root_directory(Root), run_python(Root, [config]).
dispatch([reset|Arguments]) :- !, root_directory(Root), run_python(Root, [reset|Arguments]).
dispatch([migrate|_]) :- !,
    format('AsaDB: no server-control-plane migration is required for this release.~n', []).
dispatch([rollback_upgrade|_]) :- !,
    format('AsaDB: code rollback is performed with swipl pack install --upgrade asadb; user data was preserved.~n', []).
dispatch([Command|_]) :-
    format(user_error, 'AsaDB: unsupported command: ~w~n', [Command]), usage, halt(2).

python_command([]) :- !, usage, halt(2).
python_command([setup|_], [setup]) :- !.
python_command([doctor|Rest], [doctor|Rest]) :- !.
python_command([repair|_], [repair]) :- !.
python_command([reset|Rest], [reset|Rest]) :- !.
python_command([Command|_], _) :-
    format(user_error, 'AsaDB: unsupported python command: ~w~n', [Command]), halt(2).

local_arguments(Arguments, Database, Rest) :-
    option_value('--database', Arguments, 'data.asa', Database, Rest).

panel_arguments(Arguments, Database, Port) :-
    option_value('--database', Arguments, 'data.asa', Database, AfterDatabase),
    option_value('--port', AfterDatabase, '8088', Port, _).

option_value(Name, [Name, Value|Rest], _, Value, Rest) :- !.
option_value(Name, [Item|Rest], Default, Value, [Item|Remaining]) :- !,
    option_value(Name, Rest, Default, Value, Remaining).
option_value(_, [], Default, Default, []).

root_directory(Root) :-
    source_file(asadb_launcher:main, ThisFile),
    file_directory_name(ThisFile, ToolsDirectory),
    file_directory_name(ToolsDirectory, Root).

run_swipl(Root, RelativeScript, Arguments) :-
    directory_file_path(Root, RelativeScript, Script),
    process_create(path(swipl), ['-q', '-s', Script, '--'|Arguments],
                   [cwd(Root), process(Process)]),
    process_wait(Process, exit(Status)),
    ( Status =:= 0 -> true ; halt(Status) ).

run_python(Root, Arguments) :-
    directory_file_path(Root, 'flaskserver/scripts/bootstrap_python.py', Bootstrap),
    python_command_line(Bootstrap, Arguments, Program, ProgramArguments),
    process_create(path(Program), ProgramArguments,
                   [cwd(Root), process(Process)]),
    process_wait(Process, exit(Status)),
    ( Status =:= 0 -> true ; halt(Status) ).

python_command_line(Bootstrap, Arguments, py, ['-3', Bootstrap|Arguments]) :-
    current_prolog_flag(windows, true), !.
python_command_line(Bootstrap, Arguments, python3, [Bootstrap|Arguments]).

usage :-
    format('AsaDB One Pack, Two Modes~n~n', []),
    format('  (no command)                         Start the login-first portal~n', []),
    format('  local [--database FILE] [SQL_FILE]   Run the direct Prolog CLI~n', []),
    format('  panel [--database FILE] [--port PORT] Open the authenticated portal~n', []),
    format('  start [OPTIONS]                      One-command login-first AsAPanel~n', []),
    format('  init [OPTIONS]                       Initialize admin without starting~n', []),
    format('  server [OPTIONS]                     Start an initialized Flask Server~n', []),
    format('  remote COMMAND                       Use the authenticated remote CLI~n', []),
    format('  doctor [--json] [--repair]           Check the bundled runtime~n', []),
    format('  python <setup|doctor|repair|reset>    Maintain per-user Python runtime~n', []),
    format('  config | reset <python|config> --yes | version~n', []).
