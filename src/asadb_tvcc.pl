% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  AsaDB local TVCC coordinator
  ----------------------------

  TVCC here means *three-version concurrency control*, scoped deliberately to
  one local AsaDB process.  A committed reader never opens the mutable store:
  it receives an immutable generation containing the catalog state and record
  files.  Writers continue to use the existing single-writer recovery path,
  then publish a new generation only after it is durable.

  At most three committed generations are retained.  If a slow reader still
  pins the oldest one, publication waits for that reader instead of deleting a
  live snapshot.  This is intentional: returning a mixed or invalid result is
  worse than applying local backpressure to a writer.
*/

:- module(asadb_tvcc, [
    asadb_tvcc_boot/2,
    asadb_tvcc_shutdown/0,
    asadb_tvcc_mark_change/1,
    asadb_tvcc_publish/2,
    asadb_tvcc_acquire/4,
    asadb_tvcc_release/1,
    asadb_tvcc_stats/1
]).

:- use_module(library(filesex)).
:- use_module('asadb_record_manager.pl', [asadb_record_store_id/3]).

:- dynamic tvcc_root/1.
:- dynamic tvcc_current_generation/1.
:- dynamic tvcc_next_generation/1.
:- dynamic tvcc_generation/3.       % Generation, immutable State, store root
:- dynamic tvcc_reader/2.           % Generation, owning thread
:- dynamic tvcc_pending_change/1.   % all or store(StoreId)

% Never delete an arbitrary directory.  Every managed path is derived from
% the database file and generation is a positive integer.
tvcc_root_for_file(File, Root) :-
    atom_concat(File, '.tvcc', Root).

asadb_tvcc_boot(File, State) :-
    with_mutex(asadb_tvcc,
        asadb_tvcc_boot_locked(File, State)).

asadb_tvcc_boot_locked(File, State) :-
    asadb_tvcc_shutdown_locked,
    tvcc_root_for_file(File, Root),
    make_directory_path(Root),
    assertz(tvcc_root(Root)),
    assertz(tvcc_next_generation(1)),
    tvcc_create_generation_locked(File, State, [all], Generation, _),
    assertz(tvcc_current_generation(Generation)).

asadb_tvcc_shutdown :-
    with_mutex(asadb_tvcc, asadb_tvcc_shutdown_locked).

asadb_tvcc_shutdown_locked :-
    ( tvcc_root(Root) -> safe_remove_tvcc_root(Root) ; true ),
    retractall(tvcc_reader(_, _)),
    retractall(tvcc_generation(_, _, _)),
    retractall(tvcc_current_generation(_)),
    retractall(tvcc_next_generation(_)),
    retractall(tvcc_pending_change(_)),
    retractall(tvcc_root(_)).

safe_remove_tvcc_root(Root) :-
    atom(Root),
    sub_atom(Root, _, 5, 0, '.tvcc'),
    exists_directory(Root), !,
    delete_directory_and_contents(Root).
safe_remove_tvcc_root(_).

% Called only after the normal catalog/page write is durable.  Creating the
% copy before changing current_generation means a reader can observe either
% full old data or full new data, never the writer's in-place pages.
asadb_tvcc_publish(File, State) :-
    with_mutex(asadb_tvcc_publish,
        asadb_tvcc_publish_serial(File, State)).

asadb_tvcc_publish_serial(File, State) :-
    tvcc_root(_), !,
    with_mutex(asadb_tvcc, tvcc_pending_changes(Changes)),
    with_mutex(asadb_tvcc,
        tvcc_create_generation_locked(File, State, Changes, Generation, _)),
    tvcc_wait_for_generation_slot,
    with_mutex(asadb_tvcc,
        ( tvcc_retire_unpinned_generations_locked,
          retractall(tvcc_current_generation(_)),
          assertz(tvcc_current_generation(Generation)),
          retractall(tvcc_pending_change(_))
        )).
asadb_tvcc_publish_serial(_, _).

tvcc_wait_for_generation_slot :-
    with_mutex(asadb_tvcc,
        ( tvcc_retire_unpinned_generations_locked,
          tvcc_generation_count(Count)
        )),
    ( Count =< 3 -> true
    ; sleep(0.01),
      tvcc_wait_for_generation_slot
    ).

tvcc_retire_unpinned_generations_locked :-
    tvcc_generation_count(Count),
    ( Count =< 3 -> true
    ; oldest_generation(Generation),
      ( tvcc_reader(Generation, _) -> true
      ; tvcc_remove_generation_locked(Generation),
        tvcc_retire_unpinned_generations_locked
      )
    ).

tvcc_generation_count(Count) :-
    aggregate_all(count, tvcc_generation(_, _, _), Count).

oldest_generation(Generation) :-
    findall(G, tvcc_generation(G, _, _), Generations),
    min_list(Generations, Generation).

tvcc_create_generation_locked(File, State, Changes, Generation, StoreRoot) :-
    retract(tvcc_next_generation(Generation)),
    Next is Generation + 1,
    assertz(tvcc_next_generation(Next)),
    tvcc_root(Root),
    tvcc_generation_directory(Root, Generation, Directory),
    atom_concat(Directory, '.tmp', Temporary),
    ( exists_directory(Temporary) -> delete_directory_and_contents(Temporary) ; true ),
    make_directory_path(Temporary),
    directory_file_path(Temporary, 'catalog.asa', CatalogCopy),
    copy_catalog_image(File, CatalogCopy),
    directory_file_path(Temporary, 'store', TemporaryStoreRoot),
    copy_store_files(File, TemporaryStoreRoot, Changes),
    rename_file(Temporary, Directory),
    directory_file_path(Directory, 'store', StoreRoot),
    assertz(tvcc_generation(Generation, State, StoreRoot)).

tvcc_pending_changes([all]) :- tvcc_pending_change(all), !.
tvcc_pending_changes(Changes) :-
    findall(Change, tvcc_pending_change(Change), Raw),
    sort(Raw, Changes).

% Keep track of physical table stores affected since the preceding durable
% generation. This lets the publisher copy only changed heaps/indexes and
% hard-link every immutable file already present in the last generation.
asadb_tvcc_mark_change(Action) :-
    tvcc_change_scope(Action, Scope), !,
    with_mutex(asadb_tvcc,
        ( tvcc_pending_change(all) -> true
        ; tvcc_pending_change(Scope) -> true
        ; assertz(tvcc_pending_change(Scope))
        )).
asadb_tvcc_mark_change(_).

tvcc_change_scope(drop_db(_), all) :- !.
tvcc_change_scope(Action, store(StoreId)) :-
    tvcc_action_table(Action, Database, Table), !,
    asadb_record_store_id(Database, Table, StoreId).

tvcc_action_table(create_table(DB, Table, _), DB, Table).
tvcc_action_table(drop_table(DB, Table), DB, Table).
tvcc_action_table(truncate_table(DB, Table), DB, Table).
tvcc_action_table(insert_rows(DB, Table, _, _), DB, Table).
tvcc_action_table(update_rows(DB, Table, _, _, _), DB, Table).
tvcc_action_table(delete_rows(DB, Table, _), DB, Table).
tvcc_action_table(alter_table(DB, Table, _), DB, Table).
tvcc_action_table(create_index(DB, Table, _, _, _), DB, Table).
tvcc_action_table(drop_index(DB, Table, _), DB, Table).

tvcc_generation_directory(Root, Generation, Directory) :-
    format(atom(Name), 'generation-~|~`0t~d~6+', [Generation]),
    directory_file_path(Root, Name, Directory).

copy_store_files(File, Destination, Changes) :-
    atom_concat(File, '.store', Source),
    make_directory_path(Destination),
    ( exists_directory(Source) ->
        directory_files(Source, Names),
        forall(( member(Name, Names), tvcc_store_data_file(Name) ),
               copy_store_file(Source, Destination, Changes, Name))
    ; true
    ).

% The in-memory State is authoritative for a new database before its first
% user write.  The catalog copy is kept for diagnostics/forensics; readers use
% the immutable State passed to tvcc_generation/3, so an absent primary file
% must not force a checkpoint merely to satisfy this auxiliary artifact.
copy_catalog_image(File, Destination) :-
    exists_file(File), !,
    copy_file(File, Destination).
copy_catalog_image(_, Destination) :-
    setup_call_cleanup(open(Destination, write, Stream, [encoding(utf8)]),
                       ( write_canonical(Stream, tvcc_catalog_not_checkpointed),
                         write(Stream, '.\n') ),
                       close(Stream)).

% Heap and durable B+Tree files are the committed record representation.
% Undo, transaction, temporary and backup files are recovery internals and
% must never become part of a reader snapshot.
tvcc_store_data_file(Name) :- sub_atom(Name, _, 5, 0, '.heap'), !.
tvcc_store_data_file(Name) :- sub_atom(Name, _, 6, 0, '.btree').

copy_store_file(Source, Destination, Changes, Name) :-
    directory_file_path(Source, Name, From),
    directory_file_path(Destination, Name, To),
    ( tvcc_file_changed(Name, Changes) -> copy_file(From, To)
    ; tvcc_previous_store_file(Name, Previous), exists_file(Previous) ->
        copy_or_hard_link(Previous, To)
    ; copy_file(From, To)
    ).

tvcc_file_changed(_, [all]) :- !.
tvcc_file_changed(Name, Changes) :-
    member(store(StoreId), Changes),
    atom_concat(StoreId, '.', Prefix),
    sub_atom(Name, 0, _, _, Prefix), !.

tvcc_previous_store_file(Name, File) :-
    tvcc_current_generation(Generation),
    tvcc_generation(Generation, _, PreviousRoot),
    directory_file_path(PreviousRoot, Name, File).

% Hard links are supported by normal Linux filesystems and NTFS, so an
% unchanged multi-gigabyte table adds no data copy to a new generation.  A
% filesystem that rejects hard links remains correct through the copy fallback.
copy_or_hard_link(From, To) :-
    catch(link_file(From, To, hard), _, fail), !.
copy_or_hard_link(From, To) :- copy_file(From, To).

asadb_tvcc_acquire(Generation, State, StoreRoot, Database) :-
    thread_self(Thread),
    with_mutex(asadb_tvcc,
        ( tvcc_current_generation(Generation),
          tvcc_generation(Generation, State, StoreRoot),
          assertz(tvcc_reader(Generation, Thread)),
          Database = none
        )).

asadb_tvcc_release(Generation) :-
    thread_self(Thread),
    with_mutex(asadb_tvcc,
        retract(tvcc_reader(Generation, Thread))).

tvcc_remove_generation_locked(Generation) :-
    tvcc_generation(Generation, _, StoreRoot),
    file_directory_name(StoreRoot, Directory),
    retractall(tvcc_generation(Generation, _, _)),
    safe_remove_generation_directory(Directory).

safe_remove_generation_directory(Directory) :-
    tvcc_root(Root),
    atom_concat(Root, '/', Prefix),
    sub_atom(Directory, 0, _, _, Prefix),
    exists_directory(Directory), !,
    delete_directory_and_contents(Directory).
safe_remove_generation_directory(_).

asadb_tvcc_stats(tvcc{
    current_generation:Current,
    retained_generations:Retained,
    active_readers:Readers,
    policy:'local_single_writer_three_committed_generations'
}) :-
    with_mutex(asadb_tvcc,
        ( ( tvcc_current_generation(Current) -> true ; Current = none ),
          tvcc_generation_count(Retained),
          aggregate_all(count, tvcc_reader(_, _), Readers)
        )).
