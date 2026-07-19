% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* Durable, bounded bridge between AsAPanel and the Prolog SQL executor. */

:- module(asadb_reservoir, [
    reservoir_init/2,
    reservoir_shutdown/0,
    reservoir_submit_stream/7,
    reservoir_submit_file/7,
    reservoir_job_snapshots/1,
    reservoir_job_snapshot/2,
    reservoir_job_result/2,
    reservoir_job_result_page/4,
    reservoir_cancel/2,
    reservoir_cancel_requested/1,
    reservoir_update_progress/7,
    reservoir_wait/3,
    reservoir_stats/1,
    reservoir_karyawan_advice/1,
    reservoir_cleanup/0
]).

:- use_module(library(crypto)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(uuid)).
:- use_module('../asadb_config.pl').
:- use_module('karyawan.pl').

:- dynamic reservoir_root/1.
:- dynamic reservoir_executor/1.
:- dynamic reservoir_queue/1.
:- dynamic reservoir_worker/1.
:- dynamic reservoir_job/2.

:- at_halt(reservoir_shutdown).

reservoir_init(DatabaseFile, Executor) :-
    reservoir_shutdown,
    reservoir_absolute_path(DatabaseFile, AbsoluteDatabase),
    atom_concat(AbsoluteDatabase, '.reservoir', Root),
    reservoir_prepare_directories(Root),
    assertz(reservoir_root(Root)),
    assertz(reservoir_executor(Executor)),
    reservoir_reset_counters,
    reservoir_recover_jobs,
    message_queue_create(Queue),
    assertz(reservoir_queue(Queue)),
    thread_create(reservoir_worker_loop(Queue), Worker, []),
    assertz(reservoir_worker(Worker)),
    reservoir_requeue_recovered_jobs.

reservoir_shutdown :-
    ( retract(reservoir_queue(Queue)) ->
        catch(thread_send_message(Queue, stop), _, true),
        ( retract(reservoir_worker(Worker)) ->
            catch(thread_join(Worker, _), _, true)
        ; true
        ),
        catch(message_queue_destroy(Queue), _, true)
    ; retractall(reservoir_worker(_))
    ),
    retractall(reservoir_job(_, _)),
    retractall(reservoir_executor(_)),
    retractall(reservoir_root(_)).

reservoir_submit_file(File, Label, IdempotencyKey, StopOnError, JobId, Admission, Size) :-
    size_file(File, Size),
    setup_call_cleanup(
        open(File, read, In, [type(binary)]),
        reservoir_submit_stream(In, Label, Size, IdempotencyKey, StopOnError, JobId, Admission),
        close(In)
    ).

reservoir_submit_stream(In, Label0, SizeHint, IdempotencyKey0, StopOnError0, JobId, Admission) :-
    reservoir_normalize_label(Label0, Label),
    reservoir_normalize_idempotency_key(IdempotencyKey0, IdempotencyKey),
    reservoir_bool(StopOnError0, StopOnError),
    reservoir_size_hint(SizeHint, ExpectedSize),
    uuid(CandidateId),
    get_time(Now),
    Job0 = job{
        id:CandidateId,
        idempotency_key:IdempotencyKey,
        fingerprint:'',
        label:Label,
        size_bytes:ExpectedSize,
        received_bytes:0,
        processed_bytes:0,
        statements:0,
        errors:0,
        status:receiving,
        created_at:Now,
        updated_at:Now,
        stop_on_error:StopOnError,
        cancel_requested:false,
        message:'Receiving a bounded input stream.',
        result_available:false,
        delivered:false,
        recovered:false
    },
    reservoir_admit_and_store(Job0, ExpectedSize),
    reservoir_spool_path(CandidateId, SpoolPath),
    catch(
        ( reservoir_copy_stream(CandidateId, In, SpoolPath, ActualSize),
          crypto_file_hash(SpoolPath, Fingerprint, [algorithm(sha256)]),
          reservoir_finish_submission(CandidateId, IdempotencyKey, Fingerprint, ActualSize,
                                      ExistingId, Admission0)
        ),
        Error,
        ( reservoir_fail_submission(CandidateId, Error), throw(Error) )
    ),
    ( Admission0 == duplicate ->
        reservoir_delete_job_files(CandidateId),
        with_mutex(asadb_reservoir, retractall(reservoir_job(CandidateId, _))),
        JobId = ExistingId,
        Admission = duplicate,
        reservoir_counter_inc(deduplicated)
    ; Admission0 == cancelled ->
        JobId = CandidateId,
        Admission = cancelled
    ; JobId = CandidateId,
      reservoir_queue_job(CandidateId),
      Admission = queued,
      reservoir_counter_inc(submitted)
    ).

reservoir_copy_stream(JobId, In, SpoolPath, ActualSize) :-
    setup_call_cleanup(
        open(SpoolPath, write, Out, [type(binary)]),
        ( reservoir_copy_chunks(JobId, In, Out, 0, ActualSize),
          flush_output(Out)
        ),
        close(Out)
    ).

reservoir_copy_chunks(JobId, In, Out, Received0, ActualSize) :-
    reservoir_ensure_submission_active(JobId),
    reservoir_ingress_chunk_size(JobId, ChunkSize),
    read_string(In, ChunkSize, Chunk),
    string_length(Chunk, ChunkBytes),
    ( ChunkBytes =:= 0 ->
        ActualSize = Received0
    ; Received is Received0 + ChunkBytes,
      reservoir_reserve_received(JobId, Received),
      format(Out, '~s', [Chunk]),
      reservoir_copy_chunks(JobId, In, Out, Received, ActualSize)
    ).

reservoir_ingress_chunk_size(JobId, ChunkSize) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job) ->
            asadb_config_get(reservoir_max_spool_bytes, MaxSpool),
            karyawan_ingress_plan(Job.size_bytes, MaxSpool,
                                   Job.received_bytes, Plan),
            ChunkSize = Plan.chunk_bytes
        ; ChunkSize = 262144
        )).

reservoir_admit_and_store(Job, SizeHint) :-
    with_mutex(asadb_reservoir,
        ( reservoir_admit_locked(SizeHint),
          reservoir_store_job_locked(Job, persist)
        )).

reservoir_admit_locked(SizeHint) :-
    asadb_config_get(reservoir_max_jobs, MaxJobs),
    asadb_config_get(reservoir_max_spool_bytes, MaxSpoolBytes),
    reservoir_active_count_locked(Active),
    reservoir_reserved_bytes_locked(Reserved),
    Projected is Reserved + SizeHint,
    ( Active >= MaxJobs ->
        reservoir_counter_inc(rejected),
        throw(error(resource_error(reservoir_job_slots), _))
    ; Projected > MaxSpoolBytes ->
        reservoir_counter_inc(rejected),
        throw(error(resource_error(reservoir_spool_capacity), _))
    ; true
    ).

reservoir_reserve_received(JobId, Received) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0),
          reservoir_other_reserved_bytes_locked(JobId, OtherReserved),
          asadb_config_get(reservoir_max_spool_bytes, MaxSpoolBytes),
          CurrentReservation is max(Job0.size_bytes, Received),
          Projected is OtherReserved + CurrentReservation,
          ( Projected > MaxSpoolBytes ->
              reservoir_counter_inc(rejected),
              throw(error(resource_error(reservoir_spool_capacity), _))
          ; get_time(Now),
            Job = Job0.put(_{received_bytes:Received,updated_at:Now}),
            reservoir_store_job_locked(Job, memory)
          )
        )).

reservoir_ensure_submission_active(JobId) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job),
          ( Job.cancel_requested == true ->
              throw(error(reservoir_cancelled(JobId), _))
          ; true
          )
        )).

reservoir_finish_submission(JobId, IdempotencyKey, Fingerprint, ActualSize,
                            ExistingId, Admission) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0),
          ( Job0.cancel_requested == true ->
              reservoir_cancel_locked(Job0, 'Upload cancelled before backend execution.'),
              reservoir_counter_inc(cancelled),
              ExistingId = JobId,
              Admission = cancelled
          ; reservoir_duplicate_locked(JobId, IdempotencyKey, Fingerprint, ExistingId) ->
              Admission = duplicate
          ; get_time(Now),
            Job = Job0.put(_{
                fingerprint:Fingerprint,
                size_bytes:ActualSize,
                received_bytes:ActualSize,
                status:queued,
                updated_at:Now,
                message:'Safely spooled; waiting for backend capacity.'
            }),
            reservoir_store_job_locked(Job, persist),
            ExistingId = JobId,
            Admission = queued
          )
        )).

reservoir_duplicate_locked(_, '', _, _) :- !, fail.
reservoir_duplicate_locked(JobId, Key, Fingerprint, ExistingId) :-
    reservoir_job(ExistingId, Existing),
    ExistingId \== JobId,
    Existing.idempotency_key == Key,
    Existing.fingerprint == Fingerprint,
    \+ memberchk(Existing.status, [failed,cancelled,interrupted]),
    !.

reservoir_queue_job(JobId) :-
    reservoir_queue(Queue),
    thread_send_message(Queue, run(JobId)).

reservoir_worker_loop(Queue) :-
    thread_get_message(Queue, Message),
    ( Message == stop -> true
    ; Message = run(JobId) ->
        catch(reservoir_run_job(JobId), Error, reservoir_worker_error(JobId, Error)),
        catch(reservoir_cleanup, _, true),
        reservoir_worker_loop(Queue)
    ; reservoir_worker_loop(Queue)
    ).

reservoir_run_job(JobId) :-
    reservoir_claim_job(JobId, Decision),
    ( Decision = skip -> true
    ; Decision = run(Job),
      reservoir_executor(Executor),
      SpoolPath = Job.spool_path,
      StopOnError = Job.stop_on_error,
      catch(
          ( call(Executor, JobId, SpoolPath, StopOnError, Result),
            Outcome = result(Result)
          ),
          Error,
          Outcome = error(Error)
      ),
      reservoir_finish_job(JobId, Outcome)
    ).

reservoir_claim_job(JobId, Decision) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0) ->
            ( ( Job0.cancel_requested == true ; Job0.status == cancelled ) ->
                  reservoir_cancel_locked(Job0, 'Cancelled before execution.'),
                  Decision = skip
              ; Job0.status == queued ->
                  get_time(Now),
                  Job1 = Job0.put(_{
                      status:processing,
                      updated_at:Now,
                      message:'Backend is pulling batches from the Reservoir.'
                  }),
                  reservoir_store_job_locked(Job1, persist),
                  reservoir_spool_path(JobId, SpoolPath),
                  Decision = run(Job1.put(spool_path, SpoolPath))
              ; Decision = skip
            )
        ; Decision = skip
        )).

reservoir_finish_job(JobId, error(Error)) :- !,
    ( reservoir_cancel_error(JobId, Error) ->
        with_mutex(asadb_reservoir,
            ( reservoir_job(JobId, Job),
              reservoir_cancel_locked(Job, 'Execution cancelled and rolled back.')
            )),
        reservoir_counter_inc(cancelled)
    ; reservoir_error_message(Error, Message),
      reservoir_mark_failed(JobId, Message)
    ).
reservoir_finish_job(JobId, result(Result)) :-
    ( reservoir_result_failed(Result, FailureMessage) ->
        reservoir_write_result(JobId, Result),
        reservoir_mark_failed_with_result(JobId, FailureMessage)
    ; reservoir_write_result(JobId, Result),
      with_mutex(asadb_reservoir,
          ( reservoir_job(JobId, Job0),
            get_time(Now),
            reservoir_completion_message(Job0, CompletionMessage),
            Job = Job0.put(_{
                status:completed,
                updated_at:Now,
                cancel_requested:false,
                result_available:true,
                message:CompletionMessage
            }),
            reservoir_store_job_locked(Job, persist)
          )),
      reservoir_delete_spool(JobId),
      reservoir_counter_inc(completed)
    ).

reservoir_completion_message(Job, 'Backend completed before cancellation could be applied.') :-
    Job.cancel_requested == true, !.
reservoir_completion_message(_, 'Backend committed the job; result is ready.').

reservoir_cancel_error(JobId, error(reservoir_cancelled(JobId), _)).
reservoir_cancel_error(JobId, reservoir_cancelled(JobId)).

reservoir_result_failed(error(Code, Detail), Message) :- !,
    term_string(error(Code, Detail), Message, [quoted(true), max_depth(8)]).
reservoir_result_failed(multi(Results), Message) :- !,
    member(Result, Results),
    reservoir_result_failed(Result, Message), !.
reservoir_result_failed(table(_, [[rolled_back|_]|_]), 'The transaction was rolled back.') :- !.

reservoir_worker_error(JobId, Error) :-
    reservoir_error_message(Error, Message),
    reservoir_mark_failed(JobId, Message).

reservoir_mark_failed(JobId, Message) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0) ->
            get_time(Now),
            Job = Job0.put(_{
                status:failed,
                updated_at:Now,
                message:Message,
                result_available:false
            }),
            reservoir_store_job_locked(Job, persist)
        ; true
        )),
    reservoir_counter_inc(failed).

reservoir_mark_failed_with_result(JobId, Message) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0),
          get_time(Now),
          Job = Job0.put(_{
              status:failed,
              updated_at:Now,
              message:Message,
              result_available:true
          }),
          reservoir_store_job_locked(Job, persist)
        )),
    reservoir_counter_inc(failed).

reservoir_fail_submission(JobId, Error) :-
    ( reservoir_submission_cancelled(JobId, Error) ->
        reservoir_finalize_cancelled_submission(JobId)
    ; reservoir_error_message(Error, Message),
      reservoir_mark_failed(JobId, Message),
      reservoir_delete_spool(JobId)
    ).

reservoir_submission_cancelled(JobId, error(reservoir_cancelled(JobId), _)) :- !.
reservoir_submission_cancelled(JobId, reservoir_cancelled(JobId)) :- !.
reservoir_submission_cancelled(JobId, _) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job),
          Job.cancel_requested == true
        )).

reservoir_finalize_cancelled_submission(JobId) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0),
          ( Job0.status == cancelled ->
              Changed = false
          ; reservoir_cancel_locked(Job0, 'Upload cancelled before backend execution.'),
            Changed = true
          )
        )),
    ( Changed == true -> reservoir_counter_inc(cancelled) ; true ).

reservoir_cancel(JobId, Snapshot) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0) ->
            ( Job0.status == receiving ->
                get_time(Now),
                Job = Job0.put(_{
                    status:cancelling,
                    cancel_requested:true,
                    updated_at:Now,
                    message:'Cancellation requested; stopping the upload safely.'
                }),
                reservoir_store_job_locked(Job, persist)
            ; Job0.status == queued ->
                reservoir_cancel_locked(Job0, 'Cancelled before backend execution.'),
                reservoir_counter_inc(cancelled)
            ; Job0.status == processing ->
                get_time(Now),
                Job = Job0.put(_{
                    status:cancelling,
                    cancel_requested:true,
                    updated_at:Now,
                    message:'Cancellation requested; rolling back at the next batch boundary.'
                }),
                reservoir_store_job_locked(Job, persist)
            ; true
            ),
            reservoir_job(JobId, Current),
            reservoir_snapshot_dict(Current, Snapshot)
        ; throw(error(existence_error(reservoir_job, JobId), _))
        )).

reservoir_cancel_locked(Job0, Message) :-
    get_time(Now),
    Job = Job0.put(_{
        status:cancelled,
        cancel_requested:true,
        updated_at:Now,
        message:Message
    }),
    reservoir_store_job_locked(Job, persist),
    reservoir_delete_spool(Job.id).

reservoir_cancel_requested(JobId) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job),
          Job.cancel_requested == true
        )).

reservoir_update_progress(JobId, ProcessedBytes, Statements, Errors, Status, Message0, Done) :-
    reservoir_normalize_label(Message0, Message),
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0) ->
            get_time(Now),
            Job1 = Job0.put(_{
                processed_bytes:ProcessedBytes,
                statements:Statements,
                errors:Errors,
                updated_at:Now,
                message:Message
            }),
            reservoir_progress_status(Job1, Status, Done, Job),
            reservoir_progress_persist(Job0, Job, Status, Done, Persist),
            reservoir_store_job_locked(Job, Persist)
        ; true
        )).

reservoir_progress_status(Job, _, _, Job) :- Job.cancel_requested == true, !.
reservoir_progress_status(Job0, rolled_back, _, Job) :- !,
    Job = Job0.put(status, processing).
reservoir_progress_status(Job0, error, _, Job) :- !,
    Job = Job0.put(status, processing).
reservoir_progress_status(Job0, _, _, Job) :-
    Job = Job0.put(status, processing).

reservoir_progress_persist(Job0, Job, Status, Done, persist) :-
    ( Done == true
    ; Job0.status \== Job.status
    ; memberchk(Status, [committed,rolled_back,error])
    ; asadb_config_get(reservoir_progress_quantum_bytes, Quantum),
      OldBucket is Job0.processed_bytes // Quantum,
      NewBucket is Job.processed_bytes // Quantum,
      NewBucket > OldBucket
    ), !.
reservoir_progress_persist(_, _, _, _, memory).

reservoir_job_snapshot(JobId, Snapshot) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job) ->
            reservoir_snapshot_dict(Job, Snapshot)
        ; throw(error(existence_error(reservoir_job, JobId), _))
        )).

reservoir_snapshot_dict(Job, Snapshot) :-
    reservoir_iso_time(Job.created_at, CreatedAt),
    reservoir_iso_time(Job.updated_at, UpdatedAt),
    reservoir_done_status(Job.status, Done),
    ( Job.size_bytes > 0 ->
        Percent0 is (Job.processed_bytes * 100) / Job.size_bytes,
        Percent is min(100.0, Percent0)
    ; Percent = 0.0
    ),
    asadb_config_get(reservoir_max_spool_bytes, MaxSpoolBytes),
    asadb_config_get(reservoir_result_page_rows, ResultPageRows),
    karyawan_ingress_plan(Job.size_bytes, MaxSpoolBytes,
                           Job.received_bytes, IngressAdvice),
    karyawan_egress_plan(Job.processed_bytes, Job.size_bytes,
                          Job.statements, ResultPageRows, EgressAdvice),
    karyawan_job_health(Job.status, Job.cancel_requested,
                        Job.processed_bytes, Job.size_bytes,
                        Job.statements, BackendAdvice),
    Snapshot = reservoir_job{
        id:Job.id,
        label:Job.label,
        status:Job.status,
        size_bytes:Job.size_bytes,
        received_bytes:Job.received_bytes,
        processed_bytes:Job.processed_bytes,
        statements:Job.statements,
        errors:Job.errors,
        progress_percent:Percent,
        created_at:CreatedAt,
        updated_at:UpdatedAt,
        stop_on_error:Job.stop_on_error,
        cancel_requested:Job.cancel_requested,
        result_available:Job.result_available,
        delivered:Job.delivered,
        recovered:Job.recovered,
        done:Done,
        message:Job.message,
        advisor:karyawan{
            backend:BackendAdvice,
            egress:EgressAdvice,
            ingress:IngressAdvice
        }
    }.

reservoir_job_snapshots(Snapshots) :-
    catch(reservoir_cleanup, _, true),
    with_mutex(asadb_reservoir,
        ( findall((UpdatedAt-Id)-Job,
                  ( reservoir_job(Id, Job),
                    get_dict(status, Job, Status),
                    reservoir_active_status(Status),
                    get_dict(updated_at, Job, UpdatedAt)
                  ),
                  Pairs0),
          keysort(Pairs0, Pairs1),
          reverse(Pairs1, Pairs),
          reservoir_snapshot_pairs(Pairs, Snapshots)
        )).

reservoir_snapshot_pairs([], []).
reservoir_snapshot_pairs([_-Job|Pairs], [Snapshot|Snapshots]) :-
    reservoir_snapshot_dict(Job, Snapshot),
    reservoir_snapshot_pairs(Pairs, Snapshots).

reservoir_active_status(receiving).
reservoir_active_status(queued).
reservoir_active_status(processing).
reservoir_active_status(cancelling).

reservoir_job_result(JobId, Result) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0),
          Job0.result_available == true,
          get_time(Now),
          Job = Job0.put(updated_at, Now),
          reservoir_store_job_locked(Job, memory)
        )),
    reservoir_read_result(JobId, Result).

reservoir_job_result_page(JobId, Offset, Limit, ResultPage) :-
    reservoir_job_result(JobId, Result),
    reservoir_page_result(Result, Offset, Limit, ResultPage),
    reservoir_mark_delivered(JobId).

reservoir_page_result(table(Columns, Rows), Offset, Limit,
                      table_page(Columns, PageRows, HasMore)) :- !,
    reservoir_drop_rows(Offset, Rows, Remaining),
    reservoir_take_rows(Limit, Remaining, PageRows, HasMore).
reservoir_page_result(multi(Results), Offset, Limit, multi(Pages)) :- !,
    maplist(reservoir_page_result_at(Offset, Limit), Results, Pages).
reservoir_page_result(Result, _, _, Result).

reservoir_page_result_at(Offset, Limit, Result, Page) :-
    reservoir_page_result(Result, Offset, Limit, Page).

reservoir_drop_rows(0, Rows, Rows) :- !.
reservoir_drop_rows(_, [], []) :- !.
reservoir_drop_rows(N, [_|Rows], Remaining) :-
    N1 is N - 1,
    reservoir_drop_rows(N1, Rows, Remaining).

reservoir_take_rows(0, Rows, [], HasMore) :- !,
    ( Rows == [] -> HasMore = false ; HasMore = true ).
reservoir_take_rows(_, [], [], false) :- !.
reservoir_take_rows(N, [Row|Rows0], [Row|Rows], HasMore) :-
    N1 is N - 1,
    reservoir_take_rows(N1, Rows0, Rows, HasMore).

reservoir_mark_delivered(JobId) :-
    with_mutex(asadb_reservoir,
        ( reservoir_job(JobId, Job0) ->
            get_time(Now),
            Job = Job0.put(_{
                status:delivered,
                delivered:true,
                updated_at:Now,
                message:'Result delivered; retained temporarily for safe retry.'
            }),
            reservoir_store_job_locked(Job, persist)
        ; true
        )).

reservoir_wait(JobId, TimeoutSeconds, Outcome) :-
    get_time(Now),
    Deadline is Now + TimeoutSeconds,
    reservoir_wait_until(JobId, Deadline, Outcome).

reservoir_wait_until(JobId, Deadline, Outcome) :-
    reservoir_job_snapshot(JobId, Snapshot),
    ( Snapshot.result_available == true ->
        reservoir_job_result(JobId, Result),
        Outcome = result(Result)
    ; memberchk(Snapshot.status, [failed,cancelled,interrupted]) ->
        Outcome = error(Snapshot.status, Snapshot.message)
    ; get_time(Now),
      Now >= Deadline ->
        Outcome = timeout
    ; sleep(0.05),
      reservoir_wait_until(JobId, Deadline, Outcome)
    ).

reservoir_stats(Stats) :-
    with_mutex(asadb_reservoir,
        ( aggregate_all(count, reservoir_job(_, _), Total),
          reservoir_status_count_locked(receiving, Receiving),
          reservoir_status_count_locked(queued, Queued),
          reservoir_status_count_locked(processing, Processing0),
          reservoir_status_count_locked(cancelling, Cancelling),
          Processing is Processing0 + Cancelling,
          reservoir_status_count_locked(completed, Completed0),
          reservoir_status_count_locked(delivered, Delivered),
          Completed is Completed0 + Delivered,
          reservoir_reserved_bytes_locked(SpoolBytes),
          Active is Receiving + Queued + Processing
        )),
    karyawan_backend_advice(Receiving, Queued, Processing, BackendAdvice),
    asadb_config_get(reservoir_max_jobs, MaxJobs),
    asadb_config_get(reservoir_max_spool_bytes, MaxSpoolBytes),
    reservoir_counter_value(submitted, Submitted),
    reservoir_counter_value(completed, CompletedRuns),
    reservoir_counter_value(failed, Failed),
    reservoir_counter_value(cancelled, Cancelled),
    reservoir_counter_value(deduplicated, Deduplicated),
    reservoir_counter_value(rejected, Rejected),
    reservoir_counter_value(recovered, Recovered),
    Stats = reservoir{
        enabled:true,
        worker_count:1,
        jobs:Total,
        active:Active,
        receiving:Receiving,
        queued:Queued,
        processing:Processing,
        cancelling:Cancelling,
        completed:Completed,
        spool_bytes:SpoolBytes,
        max_jobs:MaxJobs,
        max_spool_bytes:MaxSpoolBytes,
        submitted:Submitted,
        completed_runs:CompletedRuns,
        failed:Failed,
        cancelled:Cancelled,
        deduplicated:Deduplicated,
        rejected:Rejected,
        recovered:Recovered,
        advisor:BackendAdvice
    }.

reservoir_karyawan_advice(Advice) :-
    with_mutex(asadb_reservoir,
        ( reservoir_status_count_locked(receiving, Receiving),
          reservoir_status_count_locked(queued, Queued),
          reservoir_status_count_locked(processing, Processing0),
          reservoir_status_count_locked(cancelling, Cancelling),
          Processing is Processing0 + Cancelling
        )),
    karyawan_backend_advice(Receiving, Queued, Processing, Advice).

reservoir_cleanup :-
    get_time(Now),
    asadb_config_get(reservoir_job_ttl_seconds, TTL),
    with_mutex(asadb_reservoir,
        findall(Id,
            ( reservoir_job(Id, Job),
              get_dict(status, Job, Status),
              get_dict(updated_at, Job, UpdatedAt),
              reservoir_done_status(Status, true),
              Age is Now - UpdatedAt,
              Age > TTL
            ),
            Expired)),
    maplist(reservoir_remove_expired_job, Expired).

reservoir_remove_expired_job(Id) :-
    get_time(Now),
    asadb_config_get(reservoir_job_ttl_seconds, TTL),
    with_mutex(asadb_reservoir,
        ( ( reservoir_job(Id, Job),
            reservoir_done_status(Job.status, true),
            Age is Now - Job.updated_at,
            Age > TTL
          ) ->
            retractall(reservoir_job(Id, _)),
            Removed = true
        ; Removed = false
        )),
    ( Removed == true -> reservoir_delete_job_files(Id) ; true ).

reservoir_recover_jobs :-
    reservoir_jobs_directory(JobsDir),
    directory_files(JobsDir, Entries),
    include(reservoir_event_file, Entries, EventFiles),
    maplist(reservoir_recover_event_file(JobsDir), EventFiles),
    reservoir_cleanup.

reservoir_event_file(Name) :- file_name_extension(_, events, Name).

reservoir_recover_event_file(JobsDir, Name) :-
    directory_file_path(JobsDir, Name, Path),
    ( reservoir_read_last_event(Path, Job0) ->
        reservoir_recovered_job(Job0, Job, Action),
        assertz(reservoir_job(Job.id, Job)),
        ( Action == persist -> reservoir_persist_job_locked(Job) ; true )
    ; true
    ).

reservoir_recovered_job(Job0, Job, persist) :-
    reservoir_result_path(Job0.id, ResultPath),
    memberchk(Job0.status, [processing,cancelling]),
    exists_file(ResultPath), !,
    get_time(Now),
    Job = Job0.put(_{
        status:completed,
        updated_at:Now,
        result_available:true,
        recovered:true,
        message:'Recovered a completed result after an interrupted status update.'
    }),
    reservoir_counter_inc(recovered).
reservoir_recovered_job(Job0, Job, persist) :-
    memberchk(Job0.status, [receiving,processing,cancelling]), !,
    get_time(Now),
    Job = Job0.put(_{
        status:interrupted,
        updated_at:Now,
        cancel_requested:false,
        recovered:true,
        message:'Interrupted job was not replayed automatically to prevent duplicate writes.'
    }),
    reservoir_counter_inc(recovered).
reservoir_recovered_job(Job0, Job, memory) :-
    Job = Job0.put(recovered, true).

reservoir_requeue_recovered_jobs :-
    findall(Id,
            ( reservoir_job(Id, Job),
              get_dict(status, Job, queued)
            ),
            Ids),
    maplist(reservoir_queue_job, Ids).

reservoir_read_last_event(Path, Job) :-
    setup_call_cleanup(
        open(Path, read, In, [encoding(utf8)]),
        reservoir_read_event_terms(In, none, Last),
        close(In)
    ),
    Last \== none,
    Job = Last.

reservoir_read_event_terms(In, Previous, Last) :-
    catch(read_term(In, Term, []), _, Term = end_of_file),
    ( Term == end_of_file -> Last = Previous
    ; is_dict(Term, job) -> reservoir_read_event_terms(In, Term, Last)
    ; reservoir_read_event_terms(In, Previous, Last)
    ).

reservoir_store_job_locked(Job, Persist) :-
    retractall(reservoir_job(Job.id, _)),
    assertz(reservoir_job(Job.id, Job)),
    ( Persist == persist -> reservoir_persist_job_locked(Job) ; true ).

reservoir_persist_job_locked(Job) :-
    reservoir_event_path(Job.id, Path),
    setup_call_cleanup(
        open(Path, append, Out, [encoding(utf8)]),
        ( write_term(Out, Job, [quoted(true), fullstop(true), nl(true)]),
          flush_output(Out)
        ),
        close(Out)
    ).

reservoir_write_result(JobId, Result) :-
    reservoir_result_path(JobId, Path),
    atom_concat(Path, '.tmp', Temp),
    setup_call_cleanup(
        open(Temp, write, Out, [encoding(utf8)]),
        ( write_term(Out, Result, [quoted(true), fullstop(true), nl(true)]),
          flush_output(Out)
        ),
        close(Out)
    ),
    ( exists_file(Path) -> delete_file(Path) ; true ),
    rename_file(Temp, Path).

reservoir_read_result(JobId, Result) :-
    reservoir_result_path(JobId, Path),
    setup_call_cleanup(
        open(Path, read, In, [encoding(utf8)]),
        read_term(In, Result, []),
        close(In)
    ).

reservoir_prepare_directories(Root) :-
    make_directory_path(Root),
    directory_file_path(Root, spool, Spool),
    directory_file_path(Root, jobs, Jobs),
    directory_file_path(Root, results, Results),
    make_directory_path(Spool),
    make_directory_path(Jobs),
    make_directory_path(Results).

reservoir_spool_path(JobId, Path) :-
    reservoir_root(Root),
    directory_file_path(Root, spool, Dir),
    atom_concat(JobId, '.sql', Name),
    directory_file_path(Dir, Name, Path).

reservoir_event_path(JobId, Path) :-
    reservoir_jobs_directory(Dir),
    atom_concat(JobId, '.events', Name),
    directory_file_path(Dir, Name, Path).

reservoir_jobs_directory(Dir) :-
    reservoir_root(Root),
    directory_file_path(Root, jobs, Dir).

reservoir_result_path(JobId, Path) :-
    reservoir_root(Root),
    directory_file_path(Root, results, Dir),
    atom_concat(JobId, '.result', Name),
    directory_file_path(Dir, Name, Path).

reservoir_delete_spool(JobId) :-
    reservoir_spool_path(JobId, Path),
    reservoir_delete_file(Path).

reservoir_delete_job_files(JobId) :-
    reservoir_spool_path(JobId, Spool),
    reservoir_event_path(JobId, Events),
    reservoir_result_path(JobId, Result),
    reservoir_delete_file(Spool),
    reservoir_delete_file(Events),
    reservoir_delete_file(Result),
    atom_concat(Result, '.tmp', ResultTemp),
    reservoir_delete_file(ResultTemp).

reservoir_delete_file(Path) :-
    ( exists_file(Path) -> catch(delete_file(Path), _, true) ; true ).

reservoir_absolute_path(Path0, Absolute) :-
    ( is_absolute_file_name(Path0) -> Absolute = Path0
    ; working_directory(Cwd, Cwd),
      directory_file_path(Cwd, Path0, Absolute)
    ).

reservoir_active_count_locked(Count) :-
    aggregate_all(count,
        ( reservoir_job(_, Job),
          get_dict(status, Job, Status),
          memberchk(Status, [receiving,queued,processing,cancelling])
        ), Count).

reservoir_reserved_bytes_locked(Bytes) :-
    findall(Size,
        ( reservoir_job(_, Job),
          get_dict(status, Job, Status),
          memberchk(Status, [receiving,queued,processing,cancelling]),
          get_dict(size_bytes, Job, SizeBytes),
          get_dict(received_bytes, Job, ReceivedBytes),
          Size is max(SizeBytes, ReceivedBytes)
        ), Sizes),
    sum_list(Sizes, Bytes).

reservoir_other_reserved_bytes_locked(ExcludedId, Bytes) :-
    findall(Size,
        ( reservoir_job(Id, Job),
          Id \== ExcludedId,
          get_dict(status, Job, Status),
          memberchk(Status, [receiving,queued,processing,cancelling]),
          get_dict(size_bytes, Job, SizeBytes),
          get_dict(received_bytes, Job, ReceivedBytes),
          Size is max(SizeBytes, ReceivedBytes)
        ), Sizes),
    sum_list(Sizes, Bytes).

reservoir_status_count_locked(Status, Count) :-
    aggregate_all(count,
                  ( reservoir_job(_, Job),
                    get_dict(status, Job, JobStatus),
                    JobStatus == Status
                  ),
                  Count).

reservoir_done_status(completed, true).
reservoir_done_status(delivered, true).
reservoir_done_status(failed, true).
reservoir_done_status(cancelled, true).
reservoir_done_status(interrupted, true).
reservoir_done_status(_, false).

reservoir_normalize_label(Value, Label) :-
    ( atom(Value) -> Atom = Value
    ; string(Value) -> atom_string(Atom, Value)
    ; term_to_atom(Value, Atom)
    ),
    atom_length(Atom, Length),
    ( Length =< 240 -> Label = Atom
    ; sub_atom(Atom, 0, 240, _, Label)
    ).

reservoir_normalize_idempotency_key(Value, Key) :-
    ( var(Value) ; Value == '' ; Value == "" ), !,
    Key = ''.
reservoir_normalize_idempotency_key(Value, Key) :-
    reservoir_normalize_label(Value, Key).

reservoir_size_hint(Value, Size) :-
    integer(Value),
    Value >= 0, !,
    Size = Value.
reservoir_size_hint(_, 0).

reservoir_bool(true, true) :- !.
reservoir_bool('true', true) :- !.
reservoir_bool(1, true) :- !.
reservoir_bool(_, false).

reservoir_iso_time(Stamp, Atom) :-
    stamp_date_time(Stamp, DateTime, 'UTC'),
    format_time(atom(Atom), '%FT%TZ', DateTime).

reservoir_error_message(Error, Message) :-
    catch(message_to_string(Error, String), _, fail), !,
    atom_string(Message, String).
reservoir_error_message(Error, Message) :-
    term_string(Error, String, [quoted(true), max_depth(8)]),
    atom_string(Message, String).

reservoir_reset_counters :-
    forall(member(Name, [submitted,completed,failed,cancelled,deduplicated,rejected,recovered]),
           ( reservoir_counter_key(Name, Key),
             flag(Key, _, 0)
           )).

reservoir_counter_inc(Name) :-
    reservoir_counter_key(Name, Key),
    flag(Key, Old, Old + 1).

reservoir_counter_value(Name, Value) :-
    reservoir_counter_key(Name, Key),
    flag(Key, Value, Value).

reservoir_counter_key(Name, Key) :-
    atom_concat(asadb_reservoir_, Name, Key).
