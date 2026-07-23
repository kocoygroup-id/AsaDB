% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
:- module(asadb_metadata, [
    asadb_metadata_open/1,
    asadb_metadata_checkpoint/1,
    asadb_metadata_snapshot/1,
    asadb_metadata_close/0
]).

:- use_module(library(random)).

:- dynamic metadata_file/1.
:- dynamic metadata_state/1.

metadata_engine_version('1.4.0').
metadata_storage_format(3).

asadb_metadata_open(BaseFile) :-
    with_mutex(asadb_metadata, asadb_metadata_open_locked(BaseFile)).

asadb_metadata_open_locked(BaseFile) :-
    atom_concat(BaseFile, '.meta', File),
    retractall(metadata_file(_)),
    retractall(metadata_state(_)),
    assertz(metadata_file(File)),
    recover_metadata_file(File),
    ( catch(read_metadata(File, State), _, fail), valid_metadata(State) ->
        assertz(metadata_state(State))
    ; new_metadata(State),
      assertz(metadata_state(State)),
      write_metadata_atomic(File, State)
    ).

asadb_metadata_checkpoint(Summary) :-
    with_mutex(asadb_metadata, asadb_metadata_checkpoint_locked(Summary)).

asadb_metadata_checkpoint_locked(Summary) :-
    metadata_file(File),
    metadata_state(State0),
    utc_timestamp(Now),
    Count is State0.checkpoint_count + 1,
    metadata_engine_version(Version),
    metadata_storage_format(StorageFormat),
    State = State0.put(_{
        updated_at:Now,
        last_checkpoint_at:Now,
        checkpoint_count:Count,
        engine_version:Version,
        storage_format:StorageFormat,
        summary:Summary
    }),
    write_metadata_atomic(File, State),
    retractall(metadata_state(_)),
    assertz(metadata_state(State)).

asadb_metadata_snapshot(State) :-
    with_mutex(asadb_metadata, asadb_metadata_snapshot_locked(State)).

asadb_metadata_snapshot_locked(State) :-
    metadata_state(State), !.
asadb_metadata_snapshot_locked(metadata{
    format:1,
    database_id:unknown,
    created_at:unknown,
    updated_at:unknown,
    last_checkpoint_at:unknown,
    checkpoint_count:0,
    engine_version:'1.4.0',
    storage_format:3,
    summary:summary{}
}).

asadb_metadata_close :-
    with_mutex(asadb_metadata, asadb_metadata_close_locked).

asadb_metadata_close_locked :-
    retractall(metadata_file(_)),
    retractall(metadata_state(_)).

new_metadata(metadata{
    format:1,
    database_id:Id,
    created_at:Now,
    updated_at:Now,
    last_checkpoint_at:never,
    checkpoint_count:0,
    engine_version:Version,
    storage_format:StorageFormat,
    summary:summary{}
}) :-
    metadata_id(Id),
    utc_timestamp(Now),
    metadata_engine_version(Version),
    metadata_storage_format(StorageFormat).

valid_metadata(State) :-
    is_dict(State, metadata),
    State.format =:= 1,
    atom(State.database_id).

metadata_id(Id) :-
    random_between(0, 4294967295, A),
    random_between(0, 4294967295, B),
    random_between(0, 4294967295, C),
    random_between(0, 4294967295, D),
    format(atom(Id), 'asa-~|~`0t~16r~8+-~|~`0t~16r~8+-~|~`0t~16r~8+-~|~`0t~16r~8+', [A,B,C,D]).

utc_timestamp(Atom) :-
    get_time(Now),
    stamp_date_time(Now, DateTime, 'UTC'),
    format_time(atom(Atom), '%FT%TZ', DateTime).

read_metadata(File, State) :-
    exists_file(File),
    setup_call_cleanup(
        open(File, read, In, [encoding(utf8)]),
        read_term(In, State, []),
        close(In)
    ).

write_metadata_atomic(File, State) :-
    ensure_parent_directory(File),
    atom_concat(File, '.tmp', Temp),
    atom_concat(File, '.bak', Backup),
    delete_if_exists(Temp),
    setup_call_cleanup(
        open(Temp, write, Out, [encoding(utf8)]),
        ( write_canonical(Out, State),
          write(Out, '.\n'),
          flush_output(Out)
        ),
        close(Out)
    ),
    delete_if_exists(Backup),
    ( exists_file(File) -> rename_file(File, Backup) ; true ),
    catch(
        rename_file(Temp, File),
        Error,
        ( restore_metadata_backup(File, Backup), throw(Error) )
    ),
    delete_if_exists(Backup).

recover_metadata_file(File) :-
    atom_concat(File, '.tmp', Temp),
    atom_concat(File, '.bak', Backup),
    ( exists_file(File) ->
        delete_if_exists(Temp),
        delete_if_exists(Backup)
    ; exists_file(Temp), catch(read_metadata(Temp, State), _, fail), valid_metadata(State) ->
        rename_file(Temp, File),
        delete_if_exists(Backup)
    ; exists_file(Backup) ->
        rename_file(Backup, File),
        delete_if_exists(Temp)
    ; true
    ).

restore_metadata_backup(File, Backup) :-
    delete_if_exists(File),
    ( exists_file(Backup) -> rename_file(Backup, File) ; true ).

ensure_parent_directory(File) :-
    file_directory_name(File, Directory),
    ( Directory == '.' -> true ; make_directory_path(Directory) ).

delete_if_exists(File) :-
    ( exists_file(File) -> catch(delete_file(File), _, true) ; true ).
