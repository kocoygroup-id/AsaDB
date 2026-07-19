/*
   Karyawan - Reservoir traffic adviser
   ------------------------------------

   This file is a small, deterministic adviser rather than a second worker or
   an R runtime: Reservoir asks it for ingress/egress plans and backend health
   hints while the existing single worker remains the only executor.
*/

:- module(asadb_karyawan, [
    karyawan_ingress_plan/4,
    karyawan_egress_plan/5,
    karyawan_job_health/6,
    karyawan_backend_advice/4,
    karyawan_result_page_limit/3
]).

karyawan_ingress_plan(Expected0, MaxSpool0, Received0, Plan) :-
    nonnegative(Expected0, Expected),
    positive_or_zero(MaxSpool0, MaxSpool),
    nonnegative(Received0, Received),
    Reservation is max(Expected, Received),
    Headroom is max(0, MaxSpool - Reservation),
    pressure(MaxSpool, Reservation, Pressure),
    ingress_chunk(Headroom, ChunkBytes),
    ingress_action(Pressure, Action),
    Plan = karyawan_ingress{
        action:Action,
        chunk_bytes:ChunkBytes,
        headroom_bytes:Headroom,
        pressure:Pressure,
        reserved_bytes:Reservation
    }.

karyawan_egress_plan(Processed0, Total0, Statements0, DefaultPage0, Plan) :-
    nonnegative(Processed0, Processed),
    nonnegative(Total0, Total),
    nonnegative(Statements0, Statements),
    positive_page(DefaultPage0, DefaultPage),
    PageSize is min(1000, max(1, DefaultPage)),
    progress(Processed, Total, Percent),
    egress_action(Percent, Action),
    Plan = karyawan_egress{
        action:Action,
        next_page_size:PageSize,
        processed_bytes:Processed,
        progress_percent:Percent,
        statements:Statements,
        total_bytes:Total
    }.

karyawan_job_health(Status, CancelRequested, Processed0, Size0, Statements0, Health) :-
    nonnegative(Processed0, Processed),
    nonnegative(Size0, Size),
    nonnegative(Statements0, Statements),
    progress(Processed, Size, Percent),
    ( CancelRequested == true -> State = cancellation_requested
    ; memberchk(Status, [failed,interrupted]) -> State = attention_required
    ; memberchk(Status, [completed,delivered]) -> State = complete
    ; State = running
    ),
    Health = karyawan_backend{
        health:State,
        percent:Percent,
        status:Status,
        statements:Statements
    }.

karyawan_backend_advice(Receiving0, Queued0, Processing0, Advice) :-
    nonnegative(Receiving0, Receiving),
    nonnegative(Queued0, Queued),
    nonnegative(Processing0, Processing),
    Active is Receiving + Queued + Processing,
    ( Processing =:= 0, Active > 0 ->
        Action = start_worker
    ; Queued > 0, Processing > 0 ->
        Action = drain_queue
    ; Receiving > 0 ->
        Action = keep_receiving
    ; Action = idle
    ),
    Advice = karyawan_backend{
        action:Action,
        active:Active,
        processing:Processing,
        queued:Queued,
        receiving:Receiving,
        worker_count:1
    }.

karyawan_result_page_limit(Requested0, Configured0, Limit) :-
    positive_page(Requested0, Requested),
    positive_page(Configured0, Configured),
    Limit is min(1000, max(1, min(Requested, Configured))).

nonnegative(Value, Number) :- number(Value), Number is max(0, round(Value)), !.
nonnegative(_, 0).

positive_or_zero(Value, Number) :- number(Value), Number is max(0, round(Value)), !.
positive_or_zero(_, 0).

positive_page(Value, Number) :- number(Value), Number is max(1, round(Value)), !.
positive_page(_, 1).

pressure(0, _, full) :- !.
pressure(Max, Reserved, high) :- Reserved * 100 >= Max * 85, !.
pressure(Max, Reserved, medium) :- Reserved * 100 >= Max * 60, !.
pressure(_, _, low).

ingress_chunk(Headroom, 65536) :- Headroom < 262144, !.
ingress_chunk(Headroom, 131072) :- Headroom < 1048576, !.
ingress_chunk(Headroom, 262144) :- Headroom < 67108864, !.
ingress_chunk(_, 524288).

ingress_action(full, slow_down) :- !.
ingress_action(high, pace_input) :- !.
ingress_action(medium, balanced) :- !.
ingress_action(_, fast_path).

progress(_, 0, 0) :- !.
progress(Processed, Total, Percent) :-
    Percent0 is (Processed * 100) / Total,
    Percent is min(100, max(0, Percent0)).

egress_action(Percent, complete) :- Percent >= 100, !.
egress_action(Percent, drain) :- Percent >= 75, !.
egress_action(Percent, stream) :- Percent > 0, !.
egress_action(_, prepare).
