% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* Build helper. Usage: swipl -q -s src/asadb_release.pl */
:- use_module('asadb_core.pl').
:- initialization(build, main).

build :-
    qsave_program('build/asadb', [goal(asadb_cli_entry), toplevel(asadb_cli_entry), stand_alone(false)]).

asadb_cli_entry :-
    current_prolog_flag(argv, Argv),
    consult('src/asadb.pl'),
    run_argv(Argv).
