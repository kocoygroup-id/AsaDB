% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only

:- use_module('../src/bridge/reservoir.pl').
:- use_module('../src/asadb_config.pl').
:- use_module(library(filesex)).
:- use_module(library(prolog_stream)).
:- use_module(library(readutil)).
:- use_module(library(prolog_stack)).
:- dynamic reservoir_test_stream_chunks/2.
:- initialization(main, main).

main :-
    catch_with_backtrace(run_reservoir_tests, Error, reservoir_test_failed(Error)),
    reservoir_shutdown,
    cleanup_reservoir_test,
    format('Reservoir bridge assertions passed.~n', []),
    halt(0).

run_reservoir_tests :-
    cleanup_reservoir_test,
    asadb_config_reset,
    reservoir_init('tests/reservoir-test.asa', user:reservoir_test_executor),
    test_submit_result_and_paging(JobId),
    test_idempotent_retry(JobId),
    test_queued_cancellation,
    test_receiving_cancellation,
    test_live_progress_metadata,
    test_processing_cancellation,
    test_backpressure,
    test_underreported_stream_capacity,
    test_restart_recovery(JobId).

test_submit_result_and_paging(JobId) :-
    submit_text('rows', 'result test', 'result-key', JobId, Admission),
    must_equal(Admission, queued, first_admission),
    reservoir_wait(JobId, 5, Outcome),
    must_equal(Outcome, result(table([n], [[1],[2],[3]])), result_payload),
    reservoir_job_result_page(JobId, 1, 1, Page),
    must_equal(Page, table_page([n], [[2]], true), result_page),
    reservoir_job_snapshot(JobId, Snapshot),
    must_equal(Snapshot.status, delivered, delivered_status),
    must_equal(Snapshot.advisor.egress.next_page_size, 250, karyawan_default_page),
    ( Snapshot.advisor.ingress.chunk_bytes > 0,
      Snapshot.advisor.backend.health == complete ->
        true
    ; throw(error(assertion_failed(karyawan_snapshot_advice,
                                   expected(ingress_chunk_and_complete_health),
                                   got(Snapshot.advisor)), _))
    ).

test_idempotent_retry(ExpectedJobId) :-
    submit_text('rows', 'result retry', 'result-key', JobId, Admission),
    must_equal(Admission, duplicate, duplicate_admission),
    must_equal(JobId, ExpectedJobId, duplicate_job_id),
    reservoir_stats(Stats),
    must_equal(Stats.deduplicated, 1, deduplicated_counter).

test_queued_cancellation :-
    submit_text('slow', 'blocking job', 'slow-cancel-a', SlowId, _),
    wait_for_status(SlowId, processing, 2),
    submit_text('rows', 'queued cancel', 'slow-cancel-b', CancelId, _),
    reservoir_job_snapshots(ActiveJobs),
    ActiveJobs = [Newest|_],
    must_equal(Newest.id, CancelId, active_jobs_newest_first),
    ( member(ActiveSlow, ActiveJobs), ActiveSlow.id == SlowId ->
        true
    ; throw(error(assertion_failed(active_jobs_include_processing_holder,
                                   expected(SlowId), got(ActiveJobs)), _))
    ),
    reservoir_cancel(CancelId, Cancelled),
    must_equal(Cancelled.status, cancelled, queued_cancel_status),
    reservoir_wait(CancelId, 1, CancelOutcome),
    must_equal(CancelOutcome, error(cancelled, 'Cancelled before backend execution.'), queued_cancel_outcome),
    reservoir_job_snapshots(AfterCancelJobs),
    ( member(TerminalLeak, AfterCancelJobs), TerminalLeak.id == CancelId ->
        throw(error(assertion_failed(active_jobs_exclude_terminal,
                                     expected(no_cancelled_job), got(AfterCancelJobs)), _))
    ; true
    ),
    reservoir_wait(SlowId, 5, result(ok(slow_complete))).

test_receiving_cancellation :-
    reservoir_stats(BeforeStats),
    CancelledBefore = BeforeStats.cancelled,
    thread_create(reservoir_test_submit_slow_input, SubmitThread, []),
    wait_for_active_label('receiving cancellation', receiving, JobId, 2),
    reservoir_cancel(JobId, Cancelling),
    must_equal(Cancelling.status, cancelling, receiving_cancel_requested_status),
    must_equal(Cancelling.cancel_requested, true, receiving_cancel_requested_flag),
    thread_join(SubmitThread, SubmitStatus),
    must_match(SubmitStatus,
               exited(error(error(reservoir_cancelled(JobId), _))),
               receiving_submit_cancel_error),
    reservoir_job_snapshot(JobId, Cancelled),
    must_equal(Cancelled.status, cancelled, receiving_cancel_terminal_status),
    must_equal(Cancelled.cancel_requested, true, receiving_cancel_terminal_flag),
    reservoir_job_snapshots(ActiveJobs),
    ( member(ActiveLeak, ActiveJobs), ActiveLeak.id == JobId ->
        throw(error(assertion_failed(receiving_cancel_not_active,
                                     expected(no_cancelled_job), got(ActiveJobs)), _))
    ; true
    ),
    reservoir_test_event_statuses(JobId, EventStatuses),
    ( memberchk(queued, EventStatuses) ->
        throw(error(assertion_failed(receiving_cancel_never_queued,
                                     expected(no_queued_event), got(EventStatuses)), _))
    ; true
    ),
    reservoir_test_spool_path(JobId, SpoolPath),
    ( exists_file(SpoolPath) ->
        throw(error(assertion_failed(receiving_cancel_spool_removed,
                                     expected(absent), got(SpoolPath)), _))
    ; true
    ),
    reservoir_stats(AfterStats),
    CancelledAfter is CancelledBefore + 1,
    must_equal(AfterStats.cancelled, CancelledAfter,
               receiving_cancel_counted_once).

test_live_progress_metadata :-
    submit_text('progress', 'live metadata progress', 'live-progress-a', JobId, _),
    wait_for_progress(JobId, 2, 2),
    reservoir_job_snapshot(JobId, First),
    must_equal(First.status, processing, live_progress_status),
    ( First.progress_percent > 0,
      First.progress_percent < 100 ->
        true
    ; throw(error(assertion_failed(live_progress_percent,
                                   expected(strictly_between(0, 100)),
                                   got(First.progress_percent)), _))
    ),
    reservoir_stats(ActiveStats),
    ExpectedActive is ActiveStats.receiving + ActiveStats.queued + ActiveStats.processing,
    ( ActiveStats.active =:= ExpectedActive,
      ActiveStats.active >= 1,
      ActiveStats.processing >= 1,
      ActiveStats.spool_bytes >= First.size_bytes ->
        true
    ; throw(error(assertion_failed(live_reservoir_stats,
                                   expected(active_job_and_reserved_spool),
                                   got(ActiveStats)), _))
    ),
    must_equal(ActiveStats.advisor.worker_count, 1, karyawan_single_worker),
    wait_for_progress(JobId, 6, 2),
    reservoir_job_snapshot(JobId, Later),
    ( Later.processed_bytes > First.processed_bytes,
      Later.statements > First.statements ->
        true
    ; throw(error(assertion_failed(live_progress_moves_forward,
                                   expected(newer_progress),
                                   got(First, Later)), _))
    ),
    reservoir_wait(JobId, 5, result(ok(progress_complete))),
    reservoir_stats(DoneStats),
    must_equal(DoneStats.processing, 0, live_progress_terminal_stats),
    must_equal(DoneStats.active, 0, live_active_terminal_stats).

test_processing_cancellation :-
    submit_text('cancelable', 'processing cancellation', 'processing-cancel-a', JobId, _),
    wait_for_progress(JobId, 1, 2),
    reservoir_cancel(JobId, Cancelling),
    must_equal(Cancelling.status, cancelling, processing_cancel_requested_status),
    must_equal(Cancelling.cancel_requested, true, processing_cancel_requested_flag),
    reservoir_wait(JobId, 5, CancelOutcome),
    must_match(CancelOutcome, error(cancelled, _), processing_cancel_outcome),
    reservoir_cancel(JobId, CancelledAgain),
    must_equal(CancelledAgain.status, cancelled, terminal_cancel_idempotent_status),
    must_equal(CancelledAgain.cancel_requested, true, terminal_cancel_idempotent_flag).

test_backpressure :-
    asadb_config_set(reservoir_max_jobs, 1),
    submit_text('slow', 'capacity holder', 'capacity-a', SlowId, _),
    wait_for_status(SlowId, processing, 2),
    catch(submit_text('rows', 'capacity rejected', 'capacity-b', _, _), Error, true),
    must_match(Error, error(resource_error(reservoir_job_slots), _), backpressure_error),
    reservoir_wait(SlowId, 5, result(ok(slow_complete))),
    asadb_config_set(reservoir_max_jobs, 16).

test_underreported_stream_capacity :-
    asadb_config_set(reservoir_max_spool_bytes, 1048576),
    format(string(Payload), '~*c', [1048577, 0'a]),
    setup_call_cleanup(
        open_string(Payload, In),
        catch(
            reservoir_submit_stream(In, 'underreported payload', 1,
                                    'underreported-capacity', true, _, _),
            Error,
            true
        ),
        close(In)
    ),
    must_match(Error, error(resource_error(reservoir_spool_capacity), _),
               underreported_capacity_error),
    asadb_config_set(reservoir_max_spool_bytes, 536870912).

test_restart_recovery(JobId) :-
    reservoir_shutdown,
    reservoir_init('tests/reservoir-test.asa', user:reservoir_test_executor),
    reservoir_job_snapshot(JobId, Snapshot),
    must_equal(Snapshot.recovered, true, recovered_flag),
    reservoir_job_result(JobId, Result),
    must_equal(Result, table([n], [[1],[2],[3]]), recovered_result).

submit_text(Text, Label, Key, JobId, Admission) :-
    setup_call_cleanup(
        open_string(Text, In),
        reservoir_submit_stream(In, Label, 4, Key, true, JobId, Admission),
        close(In)
    ).

reservoir_test_executor(JobId, SpoolPath, _, Result) :-
    read_file_to_string(SpoolPath, Text, []),
    ( Text == "slow" ->
        sleep(0.35),
        reservoir_update_progress(JobId, 4, 1, 0, completed, 'slow complete', true),
        Result = ok(slow_complete)
    ; Text == "progress" ->
        reservoir_test_progress_steps(JobId, [2-1, 4-2, 6-3, 8-4]),
        Result = ok(progress_complete)
    ; Text == "cancelable" ->
        reservoir_test_cancel_steps(JobId, 1),
        Result = ok(unexpected_cancel_completion)
    ; Text == "rows" ->
        reservoir_update_progress(JobId, 4, 1, 0, completed, 'rows complete', true),
        Result = table([n], [[1],[2],[3]])
    ; Result = error(unexpected_test_payload, Text)
    ).

reservoir_test_progress_steps(_, []).
reservoir_test_progress_steps(JobId, [Bytes-Statements|Steps]) :-
    reservoir_update_progress(JobId, Bytes, Statements, 0, running,
                              'live progress test', false),
    sleep(0.08),
    reservoir_test_progress_steps(JobId, Steps).

reservoir_test_cancel_steps(_, Step) :-
    Step > 100, !.
reservoir_test_cancel_steps(JobId, Step) :-
    ( reservoir_cancel_requested(JobId) ->
        throw(error(reservoir_cancelled(JobId), _))
    ; Bytes is min(10, Step),
      reservoir_update_progress(JobId, Bytes, Step, 0, running,
                                'cancellable progress test', false),
      sleep(0.05),
      Next is Step + 1,
      reservoir_test_cancel_steps(JobId, Next)
    ).

reservoir_test_submit_slow_input :-
    catch(
        setup_call_cleanup(
            open_prolog_stream(user, read, In, []),
            ( assertz(reservoir_test_stream_chunks(In, 32)),
              reservoir_submit_stream(In, 'receiving cancellation', 2097152,
                                      'receiving-cancel-a', true, JobId, Admission),
              Outcome = submitted(JobId, Admission)
            ),
            close(In)
        ),
        Error,
        Outcome = error(Error)
    ),
    thread_exit(Outcome).

stream_read(Stream, Text) :-
    with_mutex(reservoir_test_stream,
        ( retract(reservoir_test_stream_chunks(Stream, Remaining0)) ->
            Remaining is Remaining0 - 1,
            ( Remaining > 0 ->
                assertz(reservoir_test_stream_chunks(Stream, Remaining))
            ; true
            )
        ; Remaining0 = 0,
          Remaining = 0
        )),
    ( Remaining0 > 0 ->
        sleep(0.04),
        format(string(Text), '~*c', [65536, 0'a])
    ; Text = ""
    ).

stream_write(_, _).

stream_close(Stream) :-
    retractall(reservoir_test_stream_chunks(Stream, _)).

wait_for_status(JobId, Expected, Timeout) :-
    get_time(Start),
    Deadline is Start + Timeout,
    wait_for_status_until(JobId, Expected, Deadline).

wait_for_status_until(JobId, Expected, Deadline) :-
    reservoir_job_snapshot(JobId, Snapshot),
    ( Snapshot.status == Expected -> true
    ; get_time(Now),
      Now < Deadline ->
        sleep(0.01),
        wait_for_status_until(JobId, Expected, Deadline)
    ; throw(error(assertion_failed(wait_for_status(Expected), Snapshot.status), _))
    ).

wait_for_active_label(Label, ExpectedStatus, JobId, Timeout) :-
    get_time(Start),
    Deadline is Start + Timeout,
    wait_for_active_label_until(Label, ExpectedStatus, JobId, Deadline).

wait_for_active_label_until(Label, ExpectedStatus, JobId, Deadline) :-
    reservoir_job_snapshots(Snapshots),
    ( member(Snapshot, Snapshots),
      Snapshot.label == Label,
      Snapshot.status == ExpectedStatus ->
        JobId = Snapshot.id
    ; get_time(Now),
      Now < Deadline ->
        sleep(0.01),
        wait_for_active_label_until(Label, ExpectedStatus, JobId, Deadline)
    ; throw(error(assertion_failed(wait_for_active_label(Label, ExpectedStatus),
                                   Snapshots), _))
    ).

wait_for_progress(JobId, Minimum, Timeout) :-
    get_time(Start),
    Deadline is Start + Timeout,
    wait_for_progress_until(JobId, Minimum, Deadline).

wait_for_progress_until(JobId, Minimum, Deadline) :-
    reservoir_job_snapshot(JobId, Snapshot),
    ( Snapshot.processed_bytes >= Minimum ->
        true
    ; get_time(Now),
      Now < Deadline ->
        sleep(0.01),
        wait_for_progress_until(JobId, Minimum, Deadline)
    ; throw(error(assertion_failed(wait_for_progress(Minimum), Snapshot), _))
    ).

reservoir_test_spool_path(JobId, Path) :-
    format(atom(Path), 'tests/reservoir-test.asa.reservoir/spool/~w.sql', [JobId]).

reservoir_test_event_statuses(JobId, Statuses) :-
    format(atom(Path), 'tests/reservoir-test.asa.reservoir/jobs/~w.events', [JobId]),
    setup_call_cleanup(
        open(Path, read, In, [encoding(utf8)]),
        reservoir_test_read_event_statuses(In, [], RevStatuses),
        close(In)
    ),
    reverse(RevStatuses, Statuses).

reservoir_test_read_event_statuses(In, Acc, Statuses) :-
    read_term(In, Term, []),
    ( Term == end_of_file ->
        Statuses = Acc
    ; is_dict(Term, job),
      get_dict(status, Term, Status) ->
        reservoir_test_read_event_statuses(In, [Status|Acc], Statuses)
    ; reservoir_test_read_event_statuses(In, Acc, Statuses)
    ).

must_equal(Actual, Expected, _) :- Actual =@= Expected, !.
must_equal(Actual, Expected, Label) :-
    throw(error(assertion_failed(Label, expected(Expected), got(Actual)), _)).

must_match(Actual, Expected, _) :- subsumes_term(Expected, Actual), !.
must_match(Actual, Expected, Label) :-
    throw(error(assertion_failed(Label, expected(Expected), got(Actual)), _)).

reservoir_test_failed(Error) :-
    print_message(error, Error),
    get_prolog_backtrace(20, Trace),
    print_prolog_backtrace(user_error, Trace),
    reservoir_shutdown,
    cleanup_reservoir_test,
    halt(1).

cleanup_reservoir_test :-
    ( exists_directory('tests/reservoir-test.asa.reservoir') ->
        delete_directory_and_contents('tests/reservoir-test.asa.reservoir')
    ; true
    ).
