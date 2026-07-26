% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  Public SWI-Prolog pack API for AsaDB.

  Load this module after installation with:

      :- use_module(library(asadb)).

  The command-line and web entrypoints remain in src/asadb.pl and
  src/asadb_web.pl.  This module deliberately exposes a small, stable API for
  programs that embed AsaDB instead of loading an entrypoint with side effects.
*/

:- module(asadb, [
    asadb_version/1,
    asadb_boot/1,
    asadb_warmup/0,
    asadb_shutdown/0,
    asadb_save/0,
    asadb_exec_sql/2,
    asadb_exec_sql_limited/3,
    asadb_exec_sql_page/4,
    asadb_parse_sql/2,
    asadb_analyze_sql/2,
    asadb_current_database/1,
    asadb_storage_stats/1,
    asadb_database_metadata/1,
    asadb_result_json/2,
    asadb_interchange_export/5,
    asadb_interchange_prepare_import/7,
    asadb_interchange_detect_format/3,
    asadb_interchange_cleanup/1
]).

:- use_module(library(readutil)).

:- reexport('../src/asadb_core.pl', [
    asadb_boot/1,
    asadb_warmup/0,
    asadb_shutdown/0,
    asadb_save/0,
    asadb_exec_sql/2,
    asadb_exec_sql_limited/3,
    asadb_exec_sql_page/4,
    asadb_parse_sql/2,
    asadb_analyze_sql/2,
    asadb_current_database/1,
    asadb_storage_stats/1,
    asadb_database_metadata/1,
    asadb_result_json/2
]).

:- reexport('../src/asadb_interchange.pl', [
    asadb_interchange_export/5,
    asadb_interchange_prepare_import/7,
    asadb_interchange_detect_format/3,
    asadb_interchange_cleanup/1
]).

%!  asadb_version(-Version:atom) is det.
%
%   Version declared by the installed source tree.  Reading VERSION instead
%   of duplicating the value in code keeps this API aligned with release and
%   pack metadata checks.
asadb_version(Version) :-
    source_file(asadb:asadb_version(_), ThisFile),
    file_directory_name(ThisFile, PrologDirectory),
    directory_file_path(PrologDirectory, '..', ParentDirectory),
    absolute_file_name(ParentDirectory, Root, [file_type(directory)]),
    directory_file_path(Root, 'VERSION', VersionFile),
    setup_call_cleanup(
        open(VersionFile, read, In, [encoding(utf8)]),
        read_string(In, _, VersionText),
        close(In)
    ),
    normalize_space(string(Normalized), VersionText),
    atom_string(Version, Normalized).
