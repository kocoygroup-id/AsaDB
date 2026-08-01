% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
   Cross-platform AsaDB repository-pack helper.

   Run from an extracted source package or checkout:

       swipl -q -s tools/asadb_pack.pl -- install
       swipl -q -s tools/asadb_pack.pl -- upgrade
       swipl -q -s tools/asadb_pack.pl -- info
       swipl -q -s tools/asadb_pack.pl -- version
       swipl -q -s tools/asadb_pack.pl -- remove

   Stock SWI-Prolog reserves `swipl pack ...` for pack management; this helper
   deliberately does not replace or shadow the user's `swipl` executable.
*/

:- use_module(library(prolog_pack)).
:- use_module(library(error)).
:- initialization(main, main).

asadb_pack_name(asadb).
asadb_repository('https://github.com/kocoygroup-id/AsaDB.git').
asadb_default_branch(main).

main :-
    current_prolog_flag(argv, Arguments),
    catch(dispatch(Arguments), Error,
          ( print_message(error, Error), halt(1) )),
    halt.

dispatch([Command|Arguments]) :-
    parse_options(Arguments, Options),
    prepare_pack_context(Options),
    dispatch_command(Command, Options), !.
dispatch(_) :-
    usage,
    halt(2).

dispatch_command(install, Options) :- !,
    repository_options(Options, InstallOptions),
    asadb_pack_name(Pack),
    pack_install(Pack, InstallOptions),
    installed_summary.
dispatch_command(upgrade, Options) :- !,
    repository_options(Options, InstallOptions0),
    asadb_pack_name(Pack),
    pack_install(Pack, [upgrade(true)|InstallOptions0]),
    installed_summary.
dispatch_command(info, Options) :- !,
    no_operation_options(Options),
    installed_summary.
dispatch_command(version, Options) :- !,
    no_operation_options(Options),
    asadb_pack_name(Pack),
    ( pack_property(Pack, version(Version)) -> format('~w~n', [Version])
    ; throw(error(existence_error(pack, Pack), _))
    ).
dispatch_command(remove, Options) :- !,
    remove_options(Options, RemoveOptions),
    asadb_pack_name(Pack),
    pack_remove(Pack, RemoveOptions),
    format('Removed AsaDB pack (~w).~n', [Pack]).
dispatch_command(_, _) :-
    usage,
    halt(2).

repository_options(Options, PackOptions) :-
    asadb_repository(URL),
    OptionDirectory = Options.directory,
    asadb_directory_option(OptionDirectory, DirectoryOptions),
    PackOptions = [ url(URL), git(true), branch(Options.branch),
                    pack(asadb), interactive(false), test(false),
                    register(false)
                  | DirectoryOptions
                  ].

remove_options(Options, RemoveOptions) :-
    asadb_directory_option(Options.directory, DirectoryOptions),
    RemoveOptions = [interactive(false)|DirectoryOptions].

no_operation_options(Options) :-
    ( Options.branch == main -> true
    ; throw(error(domain_error(command_option, Options), _))
    ).

% A custom pack directory is not automatically visible to a fresh SWI-Prolog
% process.  Attach it before upgrade, inspection, version, or removal so all
% commands work equally from Linux and Windows test/portable directories.
prepare_pack_context(Options) :-
    Options.directory == default, !.
prepare_pack_context(Options) :-
    must_be(atom, Options.directory),
    attach_packs(Options.directory, [replace(true)]).

asadb_directory_option(default, []) :- !.
asadb_directory_option(Directory, [Option]) :-
    must_be(atom, Directory),
    current_prolog_flag(version_data, swi(Major, _, _, _)),
    ( Major >= 10 -> Option = pack_directory(Directory)
    ; Option = package_directory(Directory)
    ).

parse_options(Arguments, Options) :-
    asadb_default_branch(DefaultBranch),
    parse_options(Arguments, options{directory:default, branch:DefaultBranch}, Options).

parse_options([], Options, Options).
parse_options(['--dir', Directory|Rest], Options0, Options) :- !,
    parse_options(Rest, Options0.put(directory, Directory), Options).
parse_options(['--branch', Branch|Rest], Options0, Options) :- !,
    parse_options(Rest, Options0.put(branch, Branch), Options).
parse_options([Argument|Rest], Options0, Options) :-
    atom_concat('--dir=', Directory, Argument), !,
    parse_options(Rest, Options0.put(directory, Directory), Options).
parse_options([Argument|Rest], Options0, Options) :-
    atom_concat('--branch=', Branch, Argument), !,
    parse_options(Rest, Options0.put(branch, Branch), Options).
parse_options([Argument|_], _, _) :-
    throw(error(domain_error(command_option, Argument), _)).

installed_summary :-
    asadb_pack_name(Pack),
    ( pack_property(Pack, version(Version)),
      pack_property(Pack, directory(Directory)) ->
        format('AsaDB ~w installed at ~w~n', [Version, Directory])
    ; throw(error(existence_error(pack, Pack), _))
    ).

usage :-
    format(user_error,
           'Usage: swipl -q -s tools/asadb_pack.pl -- <install|upgrade|info|version|remove> [--branch BRANCH] [--dir DIRECTORY]~n',
           []),
    format(user_error,
           'The default repository channel is the official main branch.  Use swipl pack install asadb after public pack publication.\n',
           []).
