% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
   SWI-Prolog pack application entry point.

   After `swipl pack install asadb`, SWI-Prolog discovers this file from the
   pack's app directory and runs it as:

       swipl asadb [command] [options]

   The launcher owns all command parsing so this small entry point cannot
   diverge from the source and Windows launchers.
*/

:- module(asadb_app, []).
:- use_module('../tools/asadb_launcher.pl', []).
:- initialization(asadb_launcher:main, main).
