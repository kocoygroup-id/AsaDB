#!/usr/bin/env swipl
% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/*
  Internal implementation for Asa Process Guardian.

  The guardian is deliberately separate from the SQL executor.  It can make a
  rolling, content-hashed mirror of selected project files and, when given a
  command, supervise that child with bounded restart and heartbeat auditing.
*/

:- module(yoru_the_wardevil, []).

:- use_module(library(crypto)).
:- use_module(library(filesex)).
:- use_module(library(http/json)).
:- use_module(library(lists)).
:- use_module(library(process)).
:- use_module(library(readutil)).

:- dynamic guardian_script_file/1.
:- prolog_load_context(file, ScriptFile), assertz(guardian_script_file(ScriptFile)).
:- initialization(main, main).

main :-
    current_prolog_flag(argv, Argv),
    catch(guardian_main(Argv, Code), Error,
          ( print_message(error, Error), Code = 1 )),
    halt(Code).

guardian_main(Argv, Code) :-
    default_options(Default),
    parse_argv(Argv, Default, Options, Command),
    ( Options.help == true ->
        usage,
        Code = 0
    ; validate_options(Options),
      prepare_context(Options, Command, Context),
      run_guardian(Context, Status),
      status_code(Status, Code)
    ).

usage :-
    format('Asa Process Guardian~n~n'),
    format('Usage:~n'),
    format('  scripts/asadb_guardian.sh [options] -- command [arg ...]~n'),
    format('  scripts/asadb_guardian.sh --once [options]~n~n'),
    format('Options:~n'),
    format('  --root DIR                  Project root (default: AsaDB root)~n'),
    format('  --backup-dir DIR            Mirror destination (default: ROOT/.asa-guardian)~n'),
    format('  --interval SEC              Snapshot interval (default: 90)~n'),
    format('  --include PATTERN           Extra wildcard, repeatable~n'),
    format('  --exclude PATTERN           Excluded wildcard, repeatable~n'),
    format('  --max-file-bytes N          Skip files over N bytes (default: 16777216)~n'),
    format('  --heartbeat-file FILE       Child progress marker~n'),
    format('  --stall-after SEC           Idle time before a Unix CONT nudge (0 disables)~n'),
    format('  --restart-stuck-after SEC   Restart after a nudge (0 disables)~n'),
    format('  --audit-every SEC           Audit cadence (default: 30)~n'),
    format('  --max-restarts N            Restart limit (0 is unlimited; default: 5)~n'),
    format('  --no-restart                Do not restart an abnormal child~n'),
    format('  --once                      Snapshot once and exit~n'),
    format('  --help                      Show this help~n').

default_options(options{
    root:'', backup_dir:'', heartbeat_file:'', interval:90, audit_every:30,
    stall_after:300, restart_stuck_after:0, max_restarts:5,
    max_file_bytes:16777216, include:[], exclude:[], restart:true,
    once:false, help:false
}).

parse_argv(['--'|Command], Options, Options, Command) :- !.
parse_argv([], Options, Options, []) :- !.
parse_argv([Name, Value|Rest], Options0, Options, Command) :-
    valued_option(Name), !,
    put_option(Name, Value, Options0, Options1),
    parse_argv(Rest, Options1, Options, Command).
parse_argv([Name], _Options0, _Options, _Command) :-
    valued_option(Name), !,
    throw(error(domain_error(option_value, Name), _)).
parse_argv([Arg|Rest], Options0, Options, Command) :-
    atom_concat('--', Name, Arg), !,
    put_flag(Name, Options0, Options1),
    parse_argv(Rest, Options1, Options, Command).
parse_argv(Command, Options, Options, Command).

valued_option('--root').
valued_option('--backup-dir').
valued_option('--heartbeat-file').
valued_option('--interval').
valued_option('--audit-every').
valued_option('--stall-after').
valued_option('--restart-stuck-after').
valued_option('--max-restarts').
valued_option('--max-file-bytes').
valued_option('--include').
valued_option('--exclude').

put_option('--root', Value, Options0, Options) :- !, put_dict(root, Options0, Value, Options).
put_option('--backup-dir', Value, Options0, Options) :- !, put_dict(backup_dir, Options0, Value, Options).
put_option('--heartbeat-file', Value, Options0, Options) :- !, put_dict(heartbeat_file, Options0, Value, Options).
put_option('--include', Value, Options0, Options) :- !,
    append(Options0.include, [Value], Values), put_dict(include, Options0, Values, Options).
put_option('--exclude', Value, Options0, Options) :- !,
    append(Options0.exclude, [Value], Values), put_dict(exclude, Options0, Values, Options).
put_option(Name, Value, Options0, Options) :-
    numeric_option(Name, Key), !,
    atom_number(Value, Number),
    put_dict(Key, Options0, Number, Options).
put_option(Name, _Value, _Options0, _Options) :- throw(error(domain_error(option, Name), _)).

numeric_option('--interval', interval).
numeric_option('--audit-every', audit_every).
numeric_option('--stall-after', stall_after).
numeric_option('--restart-stuck-after', restart_stuck_after).
numeric_option('--max-restarts', max_restarts).
numeric_option('--max-file-bytes', max_file_bytes).

put_flag('help', Options0, Options) :- put_dict(help, Options0, true, Options).
put_flag('once', Options0, Options) :- put_dict(once, Options0, true, Options).
put_flag('no-restart', Options0, Options) :- put_dict(restart, Options0, false, Options).
put_flag('restart', Options0, Options) :- put_dict(restart, Options0, true, Options).
put_flag(Name, _Options0, _Options) :- throw(error(domain_error(option, Name), _)).

validate_options(Options) :-
    positive(Options.interval), positive(Options.audit_every),
    positive(Options.max_file_bytes), nonnegative(Options.stall_after),
    nonnegative(Options.restart_stuck_after), nonnegative(Options.max_restarts),
    ( Options.restart_stuck_after =:= 0 ; Options.stall_after > 0 ), !.
validate_options(Options) :- throw(error(domain_error(guardian_options, Options), _)).

positive(Value) :- number(Value), Value > 0.
nonnegative(Value) :- number(Value), Value >= 0.

prepare_context(Options0, Command, Context) :-
    resolve_root(Options0.root, Root),
    resolve_path(Options0.backup_dir, Root, Backup0),
    ( Backup0 == '' -> directory_file_path(Root, '.asa-guardian', Backup1) ; Backup1 = Backup0 ),
    absolute_file_name(Backup1, Backup),
    ( same_path(Root, Backup) -> throw(error(permission_error(create, backup, Root), _)) ; true ),
    make_directory_path(Backup),
    directory_file_path(Backup, current, Current), make_directory_path(Current),
    resolve_path(Options0.heartbeat_file, Root, Heartbeat),
    put_dict(_{root:Root, backup_dir:Backup, heartbeat_file:Heartbeat}, Options0, Options),
    directory_file_path(Backup, 'manifest.json', Manifest),
    directory_file_path(Backup, 'state.json', State),
    directory_file_path(Backup, 'guardian.log', Log),
    Context = context{options:Options, command:Command, root:Root, backup:Backup,
                      current:Current, manifest:Manifest, state:State, log:Log}.

resolve_root('', Root) :- !, default_root(Root).
resolve_root(Path, Root) :- absolute_file_name(Path, Root, [file_type(directory)]).

resolve_path('', _Root, '') :- !.
resolve_path(Path, Root, Absolute) :- absolute_file_name(Path, Absolute, [relative_to(Root)]).

default_root(Root) :-
    guardian_script_file(File), file_directory_name(File, Here),
    ascend(Here, 6, Candidate),
    absolute_file_name(Candidate, Root, [file_type(directory)]), !.
default_root(Root) :- working_directory(Root, Root).

ascend(Path, 0, Path) :- !.
ascend(Path0, Count, Path) :-
    directory_file_path(Path0, '..', Parent0), absolute_file_name(Parent0, Parent),
    Next is Count - 1, ascend(Parent, Next, Path).

same_path(Left, Right) :- normalize_path(Left, A), normalize_path(Right, B), A == B.

path_inside_or_same(Path, Parent) :-
    normalize_path(Path, NormalPath), normalize_path(Parent, NormalParent),
    ( NormalPath == NormalParent
    ; atom_concat(NormalParent, '/', Prefix), sub_atom(NormalPath, 0, _, _, Prefix)
    ).

normalize_path(Path, Normalized) :-
    atom_chars(Path, Chars), maplist(normalize_path_char, Chars, Slashes), atom_chars(Atom, Slashes),
    ( current_prolog_flag(windows, true) -> downcase_atom(Atom, Normalized) ; Normalized = Atom ).

normalize_path_char('\\', '/') :- !.
normalize_path_char(Char, Char).

run_guardian(Context, Status) :-
    log_event(Context, start, _{command:Context.command}),
    snapshot(Context, Snapshot),
    write_state(Context, starting, Snapshot, null),
    ( Context.options.once == true ->
        write_state(Context, complete, Snapshot, null), Status = complete
    ; Context.command == [] -> backup_loop(Context, Snapshot, Status)
    ; supervise(Context, 0, Status)
    ).

backup_loop(Context, Snapshot0, Status) :-
    sleep(Context.options.interval),
    snapshot(Context, Snapshot),
    write_state(Context, backing_up, Snapshot, null),
    ( Snapshot == Snapshot0 -> true ; true ),
    backup_loop(Context, Snapshot, Status).

snapshot(Context, Snapshot) :-
    collect_files(Context, Files), load_manifest(Context.manifest, Previous),
    snapshot_files(Files, Context, Previous, [], Entries, 0, Copied, 0, Kept, 0, Skipped),
    remove_stale(Previous, Entries, Context, 0, Deleted),
    timestamp(Now),
    Manifest = _{version:1, generated_at:Now, files:Entries},
    write_json_atomic(Context.manifest, Manifest),
    length(Entries, Count),
    Snapshot = _{files:Count, copied:Copied, kept:Kept, skipped:Skipped, deleted:Deleted,
                 generated_at:Now},
    log_event(Context, snapshot, Snapshot).

collect_files(Context, Files) :-
    walk_directory(Context.root, Context, Unsorted), sort(2, @=<, Unsorted, Files).

walk_directory(Directory, Context, Files) :-
    directory_files(Directory, Names), walk_names(Names, Directory, Context, Files).

walk_names([], _Directory, _Context, []).
walk_names([Name|Rest], Directory, Context, Files) :-
    directory_file_path(Directory, Name, Path),
    ( memberchk(Name, ['.', '..']) -> Here = []
    ; path_inside_or_same(Path, Context.backup) -> Here = []
    ; exists_directory(Path) -> walk_directory(Path, Context, Here)
    ; exists_file(Path), relative_file_name(Path, Context.root, Relative0),
      normalize_path(Relative0, Relative), selected_file(Relative, Context.options) -> Here = [file(Path, Relative)]
    ; Here = []
    ),
    walk_names(Rest, Directory, Context, Tail), append(Here, Tail, Files).

selected_file(Relative, Options) :-
    \+ excluded(Relative, Options.exclude),
    ( Options.include == [] -> default_selected(Relative)
    ; member(Pattern, Options.include), wildcard_match(Pattern, Relative)
    ).

excluded(Relative, Patterns) :- member(Pattern, Patterns), wildcard_match(Pattern, Relative), !.

default_selected('asadb.conf').
default_selected('Makefile').
default_selected(Relative) :- atom_concat('src/', Tail, Relative), file_name_extension(_, pl, Tail).
default_selected(Relative) :- atom_concat('scripts/', Tail, Relative), file_name_extension(_, sh, Tail).

snapshot_files([], _Context, _Previous, Entries, Entries, Copied, Copied, Kept, Kept, Skipped, Skipped).
snapshot_files([file(Source, Relative)|Rest], Context, Previous, Entries0, Entries,
               Copied0, Copied, Kept0, Kept, Skipped0, Skipped) :-
    size_file(Source, Size), time_file(Source, MTime),
    ( Size > Context.options.max_file_bytes ->
        Entries1 = Entries0, Copied1 = Copied0, Kept1 = Kept0, Skipped1 is Skipped0 + 1
    ; entry_unchanged(Relative, Size, MTime, Previous, Context) ->
        old_entry(Relative, Previous, Entry), Entries1 = [Entry|Entries0],
        Copied1 = Copied0, Kept1 is Kept0 + 1, Skipped1 = Skipped0
    ; copy_snapshot_file(Source, Relative, Size, MTime, Context, Entry),
      Entries1 = [Entry|Entries0], Copied1 is Copied0 + 1, Kept1 = Kept0, Skipped1 = Skipped0
    ),
    snapshot_files(Rest, Context, Previous, Entries1, Entries, Copied1, Copied,
                   Kept1, Kept, Skipped1, Skipped).

old_entry(Relative, Entries, Entry) :-
    member(Entry, Entries), entry_path_equal(Entry.path, Relative), !.

entry_path_equal(Path, Relative) :- atom(Path), !, Path == Relative.
entry_path_equal(Path, Relative) :- string(Path), atom_string(Relative, Path).

entry_unchanged(Relative, Size, MTime, Previous, Context) :-
    old_entry(Relative, Previous, Entry), Entry.size =:= Size, Entry.mtime =:= MTime,
    snapshot_path(Context, Relative, Destination), exists_file(Destination).

copy_snapshot_file(Source, Relative, Size, MTime, Context, Entry) :-
    snapshot_path(Context, Relative, Destination), file_directory_name(Destination, Parent),
    make_directory_path(Parent), atom_concat(Destination, '.tmp-', Temporary),
    setup_call_cleanup(true, copy_file(Source, Temporary), true),
    replace_file(Temporary, Destination), crypto_file_hash(Destination, Digest, [algorithm(sha256)]),
    Entry = _{path:Relative, size:Size, mtime:MTime, sha256:Digest}.

snapshot_path(Context, Relative, Destination) :-
    directory_file_path(Context.current, Relative, Destination),
    path_inside_or_same(Destination, Context.current), !.
snapshot_path(_Context, Relative, _Destination) :- throw(error(permission_error(write, backup_path, Relative), _)).

replace_file(Temporary, Destination) :-
    catch(rename_file(Temporary, Destination), _, fail), !.
replace_file(Temporary, Destination) :-
    ( exists_file(Destination) -> delete_file(Destination) ; true ), rename_file(Temporary, Destination).

remove_stale([], _Entries, _Context, Deleted, Deleted).
remove_stale([Old|Rest], Entries, Context, Deleted0, Deleted) :-
    ( old_entry(Old.path, Entries, _) -> Deleted1 = Deleted0
    ; snapshot_path(Context, Old.path, Destination),
      ( exists_file(Destination) -> delete_file(Destination), Deleted1 is Deleted0 + 1 ; Deleted1 = Deleted0 )
    ),
    remove_stale(Rest, Entries, Context, Deleted1, Deleted).

load_manifest(Path, Entries) :-
    ( exists_file(Path),
      catch(setup_call_cleanup(open(Path, read, In, [encoding(utf8)]), json_read_dict(In, Dict), close(In)), _, fail),
      get_dict(files, Dict, Candidate), is_list(Candidate) -> Entries = Candidate
    ; Entries = []
    ).

write_json_atomic(Path, Dict) :-
    atom_concat(Path, '.tmp-', Temporary),
    setup_call_cleanup(open(Temporary, write, Out, [encoding(utf8)]),
                       json_write_dict(Out, Dict, [width(0)]), close(Out)),
    replace_file(Temporary, Path).

timestamp(Stamp) :- get_time(Time), format_time(atom(Stamp), '%FT%TZ', Time).

write_state(Context, Status, Snapshot, ChildPid) :-
    timestamp(Now),
    State = _{version:1, updated_at:Now, status:Status, root:Context.root,
              backup_dir:Context.backup, command:Context.command, child_pid:ChildPid,
              snapshot:Snapshot},
    write_json_atomic(Context.state, State).

log_event(Context, Event, Fields) :-
    timestamp(Now),
    setup_call_cleanup(open(Context.log, append, Out, [encoding(utf8)]),
                       format(Out, '~w ~w ~q~n', [Now, Event, Fields]), close(Out)),
    rotate_log(Context.log).

rotate_log(Path) :-
    exists_file(Path), size_file(Path, Size), Size > 1048576, !,
    atom_concat(Path, '.1', Previous), ( exists_file(Previous) -> delete_file(Previous) ; true ),
    rename_file(Path, Previous).
rotate_log(_Path).

supervise(Context, Attempt0, Status) :-
    ( spawn_child(Context, Child, Queue, Threads) ->
        write_state(Context, running, _{}, Child.pid), get_time(Now), heartbeat_mtime(Context, Heartbeat),
        NextAudit is Now + Context.options.audit_every,
        monitor_child(Context, Child.pid, Queue, Now, Heartbeat, none, NextAudit, Result),
        stop_child_io(Queue, Threads),
        handle_result(Context, Attempt0, Result, Status)
    ; handle_result(Context, Attempt0, spawn_error, Status)
    ).

spawn_child(Context, child{pid:Pid}, Queue, [OutThread, ErrThread, WaitThread]) :-
    Context.command = [Executable|Args],
    process_create(path(Executable), Args,
                   [process(Pid), stdin(null), stdout(pipe(Out)), stderr(pipe(Err))]),
    message_queue_create(Queue),
    thread_create(forward_stream(Out, stdout, Queue), OutThread, []),
    thread_create(forward_stream(Err, stderr, Queue), ErrThread, []),
    thread_create(wait_child(Pid, Queue), WaitThread, []),
    log_event(Context, child_start, _{pid:Pid, command:Context.command}).

forward_stream(Stream, Label, Queue) :-
    repeat,
    read_line_to_string(Stream, Line),
    ( Line == end_of_file -> thread_send_message(Queue, closed(Label)), !
    ; thread_send_message(Queue, output(Label, Line)), fail
    ),
    close(Stream).

wait_child(Pid, Queue) :-
    catch(process_wait(Pid, ProcessStatus), Error, ProcessStatus = error(Error)),
    thread_send_message(Queue, done(ProcessStatus)).

stop_child_io(Queue, Threads) :-
    forall(member(Thread, Threads), catch(thread_join(Thread, _), _, true)),
    catch(message_queue_destroy(Queue), _, true).

monitor_child(Context, Pid, Queue, Last0, Heartbeat0, Nudge0, NextAudit0, Result) :-
    ( thread_get_message(Queue, Message, [timeout(0.25)]) ->
        handle_monitor_message(Message, Context, Last0, Last1, MaybeStatus)
    ; Last1 = Last0, MaybeStatus = none
    ),
    ( MaybeStatus = done(ProcessStatus) -> process_result(ProcessStatus, Result)
    ; get_time(Now), heartbeat_progress(Context, Heartbeat0, Heartbeat1, Last1, Last2),
      ( Last2 > Last0 -> NudgeBase = none ; NudgeBase = Nudge0 ),
      scheduled_audit(Context, Pid, Now, Last2, NudgeBase, NextAudit0, NextAudit),
      maybe_nudge(Context, Pid, Now, Last2, NudgeBase, Nudge1),
      ( restart_stuck(Context, Now, Nudge1) -> terminate_child(Pid), Result = stuck
      ; monitor_child(Context, Pid, Queue, Last2, Heartbeat1, Nudge1, NextAudit, Result)
      )
    ).

handle_monitor_message(output(Label, Text), Context, _Last0, Last, none) :- !,
    log_event(Context, child_output, _{stream:Label, text:Text}), get_time(Last).
handle_monitor_message(done(Status), _Context, Last, Last, done(Status)) :- !.
handle_monitor_message(_Message, _Context, Last, Last, none).

heartbeat_mtime(Context, MTime) :-
    ( Context.options.heartbeat_file == '' -> MTime = none
    ; exists_file(Context.options.heartbeat_file) -> time_file(Context.options.heartbeat_file, MTime)
    ; MTime = none
    ).

heartbeat_progress(Context, Before, After, Last0, Last) :-
    heartbeat_mtime(Context, After),
    ( After \== none, After \== Before -> get_time(Last), log_event(Context, heartbeat, _{file:Context.options.heartbeat_file})
    ; Last = Last0
    ).

scheduled_audit(Context, Pid, Now, Last, Nudge, Next0, Next) :-
    ( Now >= Next0 ->
        Idle is floor(Now - Last), log_event(Context, audit, _{pid:Pid, idle_sec:Idle, nudge:Nudge}),
        Next is Now + Context.options.audit_every
    ; Next = Next0
    ).

maybe_nudge(Context, Pid, Now, Last, Nudge0, Nudge) :-
    Stall = Context.options.stall_after, Idle is Now - Last,
    ( Stall > 0, Idle >= Stall, Nudge0 == none ->
        gentle_nudge(Pid, Delivery), log_event(Context, nudge, _{pid:Pid, delivery:Delivery}), Nudge = Now
    ; Nudge = Nudge0
    ).

gentle_nudge(_Pid, skipped_windows) :- current_prolog_flag(windows, true), !.
gentle_nudge(Pid, delivered) :- catch(process_kill(Pid, cont), _, fail), !.
gentle_nudge(_Pid, unavailable).

restart_stuck(Context, Now, NudgeAt) :-
    Delay = Context.options.restart_stuck_after, Delay > 0, number(NudgeAt), Now - NudgeAt >= Delay.

terminate_child(Pid) :-
    catch(process_kill(Pid, term), _, true), sleep(1), catch(process_kill(Pid, kill), _, true).

process_result(exit(0), exit) :- !.
process_result(_Status, crash).

handle_result(Context, _Attempt, exit, complete) :-
    write_state(Context, complete, _{}, null), log_event(Context, child_exit, _{status:exit}).
handle_result(Context, Attempt0, Reason, Status) :-
    log_event(Context, recovery_needed, _{reason:Reason}),
    ( Context.options.restart == true,
      ( Context.options.max_restarts =:= 0 ; Attempt0 < Context.options.max_restarts ) ->
        Attempt is Attempt0 + 1, Delay is min(120, 5 * (2 ** (Attempt - 1))),
        write_state(Context, backoff, _{attempt:Attempt, delay_sec:Delay}, null),
        sleep(Delay), supervise(Context, Attempt, Status)
    ; write_state(Context, stopped_after_recovery_limit, _{reason:Reason}, null), Status = failed
    ).

status_code(complete, 0).
status_code(_Status, 1).
