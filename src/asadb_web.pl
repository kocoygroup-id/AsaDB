% Copyright (C) 2026 Kocoy Group and AsaDB contributors
% SPDX-License-Identifier: GPL-3.0-only
/* AsaDB Local Web API + AsAPanel static host. */

:- set_prolog_flag(double_quotes, codes).
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_multipart_plugin)).
:- use_module(library(http/json)).
:- use_module(library(http/http_stream)).
:- use_module(library(random)).
:- use_module(library(readutil)).
:- use_module(library(utf8)).
:- use_module('asadb_core.pl').
:- use_module('asadb_backup.pl').
:- use_module('asadb_config.pl').
:- use_module('bridge/reservoir.pl').
:- initialization(main, main).

:- dynamic asadb_panel_token/1.
:- dynamic asadb_import_progress/9.
:- dynamic asadb_import_pending/2.

:- http_handler(root(.), serve_index, []).
:- http_handler(root('assets/app-loader.js'), serve_asset('web/assets/app-loader.js', 'application/javascript'), []).
:- http_handler(root('assets/app.js'), serve_asset('web/assets/app.js', 'application/javascript'), []).
:- http_handler(root('assets/app.legacy.js'), serve_asset('web/assets/app.legacy.js', 'application/javascript'), []).
:- http_handler(root('assets/style.css'), serve_asset('web/assets/style.css', 'text/css'), []).
:- http_handler(root('favicon.ico'), serve_binary_asset('web/assets/asadb-logo.png', 'image/png'), []).
:- http_handler(root('assets/fonts/noto-sans-jp-japanese-400-normal.woff2'), serve_binary_asset('web/assets/fonts/noto-sans-jp-japanese-400-normal.woff2', 'font/woff2'), []).
:- http_handler(root('assets/fonts/noto-sans-jp-japanese-400-normal.woff'), serve_binary_asset('web/assets/fonts/noto-sans-jp-japanese-400-normal.woff', 'font/woff'), []).
:- http_handler(root('assets/asadb-logo.png'), serve_binary_asset('web/assets/asadb-logo.png', 'image/png'), []).
:- http_handler(root('assets/Icon/save.png'), serve_binary_asset('web/assets/Icon/save.png', 'image/png'), []).
:- http_handler(root('assets/Icon/tong_sampah.png'), serve_binary_asset('web/assets/Icon/tong_sampah.png', 'image/png'), []).
:- http_handler(root('assets/Effect/Berhasil/1.mp3'), serve_binary_asset('web/assets/Effect/Berhasil/1.mp3', 'audio/mpeg'), []).
:- http_handler(root('assets/Effect/Berhasil/2.mp3'), serve_binary_asset('web/assets/Effect/Berhasil/2.mp3', 'audio/mpeg'), []).
:- http_handler(root('assets/Effect/Berhasil/3.mp3'), serve_binary_asset('web/assets/Effect/Berhasil/3.mp3', 'audio/mpeg'), []).
:- http_handler(root('assets/Effect/Berhasil/4.mp3'), serve_binary_asset('web/assets/Effect/Berhasil/4.mp3', 'audio/mpeg'), []).
:- http_handler(root('assets/Effect/Gagal/1g.mp3'), serve_binary_asset('web/assets/Effect/Gagal/1g.mp3', 'audio/mpeg'), []).
:- http_handler(root('assets/Effect/Gagal/2g.mp3'), serve_binary_asset('web/assets/Effect/Gagal/2g.mp3', 'audio/mpeg'), []).
:- http_handler(root('assets/Effect/Gagal/3g.mp3'), serve_binary_asset('web/assets/Effect/Gagal/3g.mp3', 'audio/mpeg'), []).
:- http_handler(root('assets/Effect/Gagal/4g.mp3'), serve_binary_asset('web/assets/Effect/Gagal/4g.mp3', 'audio/mpeg'), []).
:- http_handler(root('samples/demo.sql'), serve_asset('web/samples/demo.sql', 'application/sql'), []).
:- http_handler(root('samples/feature-tour.sql'), serve_asset('web/samples/feature-tour.sql', 'application/sql'), []).
:- http_handler(root('api/query'), api_query, []).
:- http_handler(root('api/execute_stream'), api_execute_stream, []).
:- http_handler(root('api/warmup'), api_warmup, []).
:- http_handler(root('api/save'), api_save, []).
:- http_handler(root('api/analyze'), api_analyze, []).
:- http_handler(root('api/state'), api_state, []).
:- http_handler(root('api/catalog'), api_catalog, []).
:- http_handler(root('api/metadata'), api_metadata, []).
:- http_handler(root('api/backup'), api_backup, []).
:- http_handler(root('api/import_file'), api_import_file, []).
:- http_handler(root('api/import_upload'), api_import_upload, []).
:- http_handler(root('api/import_progress'), api_import_progress, []).
:- http_handler(root('api/reservoir/jobs'), api_reservoir_jobs, []).
:- http_handler(root('api/reservoir/file'), api_reservoir_file, []).
:- http_handler(root('api/reservoir/job'), api_reservoir_job, []).
:- http_handler(root('api/reservoir/result'), api_reservoir_result, []).
:- http_handler(root('api/reservoir/cancel'), api_reservoir_cancel, []).
:- http_handler(root('api/reservoir/stats'), api_reservoir_stats, []).

main :-
    current_prolog_flag(argv, Argv),
    parse_args(Argv, DbFile, Port),
    init_panel_token,
    asadb_boot(DbFile),
    asadb_warmup,
    asadb_init_reservoir(DbFile),
    asadb_start_http_on_available_port(Port, ActualPort),
    asadb_write_panel_port_file(ActualPort),
    format('AsAPanel running at http://127.0.0.1:~w/ using ~w~n', [ActualPort, DbFile]),
    wait_forever.

parse_args([DbFile, PortAtom|_], DbFile, Port) :- atom_number(PortAtom, Port), !.
parse_args([DbFile|_], DbFile, 8088) :- !.
parse_args(_, 'data.asa', 8088).

wait_forever :- sleep(3600), wait_forever.

asadb_start_http_on_available_port(PreferredPort, Port) :-
    Upper is PreferredPort + 30,
    between(PreferredPort, Upper, Port),
    catch(http_server(http_dispatch, [port(localhost:Port), silent(true)]), _, fail),
    !.
asadb_start_http_on_available_port(PreferredPort, _) :-
    format(user_error, 'AsA fatal: no local port available near ~w.~n', [PreferredPort]),
    halt(1).

asadb_write_panel_port_file(Port) :-
    catch(
        setup_call_cleanup(
            open('asadb.port', write, Out),
            format(Out, 'http://127.0.0.1:~w/~n', [Port]),
            close(Out)
        ),
        _,
        true
    ).

init_panel_token :-
    retractall(asadb_panel_token(_)),
    random_between(100000000, 999999999, A),
    random_between(100000000, 999999999, B),
    random_between(100000000, 999999999, C),
    format(atom(Token), '~w-~w-~w', [A, B, C]),
    assertz(asadb_panel_token(Token)).

asadb_init_reservoir(DbFile) :-
    reservoir_init(DbFile, user:reservoir_execute_job).

reservoir_execute_job(JobId, SpoolPath, StopOnError, Result) :-
    with_mutex(asadb_execution,
        reservoir_execute_spooled_sql(JobId, SpoolPath, StopOnError, Result)).

reservoir_execute_spooled_sql(JobId, SpoolPath, _, Result) :-
    size_file(SpoolPath, Size),
    Size =< 250000, !,
    ensure_import_not_cancelled(JobId),
    read_file_to_codes(SpoolPath, SQL, []),
    web_query_fetch_size(FetchRows),
    asadb_exec_sql_limited(SQL, FetchRows, Result0),
    web_query_result(Result0, Result),
    result_error_count(Result, Errors),
    result_statement_count(Result, Statements),
    reservoir_update_progress(JobId, Size, Statements, Errors, completed,
                              'Backend completed the spooled SQL command.', true).
reservoir_execute_spooled_sql(JobId, SpoolPath, StopOnError, Result) :-
    import_sql_file_backend(SpoolPath, StopOnError, JobId, Result).

result_statement_count(multi(Results), Count) :- !, length(Results, Count).
result_statement_count(_, 1).

serve_index(_Request) :-
    asadb_panel_token(Token),
    security_headers,
    format('Set-Cookie: asadb_token=~w; Path=/; SameSite=Strict~n', [Token]),
    serve_file_body('web/index.html', 'text/html').
serve_asset(Path, Type, _Request) :- serve_file(Path, Type).
serve_binary_asset(Path, Type, _Request) :- serve_binary_file(Path, Type).

serve_file(Path, Type) :-
    security_headers,
    serve_file_body(Path, Type).

serve_file_body(Path, Type) :-
    % Static UI files include Japanese translations.  Read them as UTF-8 text
    % so SWI-Prolog transcodes characters once for the HTTP text stream.
    % Copying binary bytes to that stream double-encodes non-ASCII text.
    format('Content-type: ~w; charset=utf-8~n~n', [Type]),
    setup_call_cleanup(
        open(Path, read, In, [encoding(utf8)]),
        copy_stream_data(In, current_output),
        close(In)
    ).

serve_binary_file(Path, Type) :-
    security_headers,
    size_file(Path, Size),
    format('Content-type: ~w~n', [Type]),
    format('Content-length: ~w~n~n', [Size]),
    setup_call_cleanup(
        open(Path, read, In, [type(binary)]),
        copy_stream_data(In, current_output),
        close(In)
    ).

api_query(Request) :-
    member(method(post), Request), !,
    (   authorized_api(Request)
    ->  (   read_sql_page_body(Request, SQL, Offset)
        ->  web_query_fetch_size(FetchRows),
            with_mutex(asadb_execution,
                       query_page_execution(SQL, Offset, FetchRows, Result0, OffsetApplied)),
            ( OffsetApplied == true ->
                web_query_result(Result0, Result)
            ;   web_query_result_offset(Result0, Offset, Result)
            ),
            asadb_result_json(Result, JSON),
            json_response(JSON)
        ;   json_error('400 Bad Request', 'Missing or oversized SQL payload')
        )
    ;   json_error('403 Forbidden', 'Forbidden')
    ).
api_query(_) :-
    json_error('405 Method Not Allowed', 'POST only').

read_sql_page_body(Request, SQL, Offset) :-
    http_read_data(Request, Data, []),
    member(sql=SQL, Data),
    atom_length(SQL, Len),
    Len =< 250000,
    query_page_offset(Data, Offset).

query_page_offset(Data, Offset) :-
    member(offset=Raw, Data),
    !,
    page_number_value(Raw, Offset).
query_page_offset(_, 0).

page_number_value(Value, Number) :-
    integer(Value),
    Value >= 0,
    Value =< 1000000000,
    Number = Value, !.
page_number_value(Value, Number) :-
    atom(Value),
    catch(atom_number(Value, Number), _, fail),
    integer(Number),
    Number >= 0,
    Number =< 1000000000.

query_page_execution(SQL, Offset, FetchRows, Result, true) :-
    Offset > 0,
    catch(asadb_parse_sql(SQL, [select(_, _, _, _, _, _)]), _, fail), !,
    asadb_exec_sql_page(SQL, Offset, FetchRows, Result).
query_page_execution(SQL, _Offset, FetchRows, Result, false) :-
    asadb_exec_sql_limited(SQL, FetchRows, Result).

api_execute_stream(Request) :-
    member(method(post), Request), !,
    ( authorized_api(Request) ->
        ( request_stream_payload(Request, In, Size) ->
            request_stop_on_error(Request, StopOnError),
            request_idempotency_key(Request, IdempotencyKey),
            setup_call_cleanup(
                true,
                catch(
                    ( reservoir_submit_stream(In, 'SQL command stream', Size, IdempotencyKey,
                                              StopOnError, JobId, _),
                      reservoir_wait(JobId, 3600, WaitOutcome),
                      reservoir_wait_result(WaitOutcome, Result)
                    ),
                    Error,
                    Result = error(stream_execution_failed, Error)
                ),
                close(In)
            ),
            asadb_result_json(Result, JSON),
            json_response(JSON)
        ; json_error('400 Bad Request', 'Missing or oversized SQL stream')
        )
    ; json_error('403 Forbidden', 'Forbidden')
    ).
api_execute_stream(_) :-
    json_error('405 Method Not Allowed', 'POST only').

reservoir_wait_result(result(Result), Result) :- !.
reservoir_wait_result(error(Status, Message), error(Status, Message)) :- !.
reservoir_wait_result(timeout, error(reservoir_timeout, 'Reservoir job timed out while waiting for compatibility response.')).

web_query_row_limit(Limit) :- asadb_config_get(max_result_rows, Limit).
web_query_fetch_size(FetchRows) :-
    web_query_row_limit(Limit),
    FetchRows is Limit + 1.

web_query_result(multi(Results0), multi(Results)) :- !,
    maplist(web_query_result, Results0, Results).
web_query_result(table(Columns, Rows0), table_page(Columns, Rows, HasMore)) :- !,
    web_query_row_limit(Limit),
    take_web_rows(Limit, Rows0, Rows, HasMore).
web_query_result(Result, Result).

web_query_result_offset(multi(Results0), Offset, multi(Results)) :- !,
    maplist(web_query_result_offset_at(Offset), Results0, Results).
web_query_result_offset(table(Columns, Rows0), Offset, table_page(Columns, Rows, HasMore)) :- !,
    web_query_row_limit(Limit),
    drop_web_rows(Offset, Rows0, Remaining),
    take_web_rows(Limit, Remaining, Rows, HasMore).
web_query_result_offset(Result, _, Result).

web_query_result_offset_at(Offset, Result0, Result) :-
    web_query_result_offset(Result0, Offset, Result).

drop_web_rows(0, Rows, Rows) :- !.
drop_web_rows(_, [], []) :- !.
drop_web_rows(N, [_|Rows], Remaining) :-
    N1 is max(0, N - 1),
    drop_web_rows(N1, Rows, Remaining).

take_web_rows(0, Rows, [], HasMore) :- !,
    ( Rows == [] -> HasMore = false ; HasMore = true ).
take_web_rows(_, [], [], false) :- !.
take_web_rows(N, [Row|Rows0], [Row|Rows], HasMore) :-
    N1 is N - 1,
    take_web_rows(N1, Rows0, Rows, HasMore).

api_warmup(Request) :-
    (   authorized_api(Request)
    ->  asadb_warmup,
        asadb_result_json(ok(warmup_ready), JSON),
        json_response(JSON)
    ;   json_error('403 Forbidden', 'Forbidden')
    ).

api_save(Request) :-
    member(method(post), Request), !,
    (   authorized_api(Request)
    ->  with_mutex(asadb_execution,
            ( asadb_save,
              asadb_current_database(CurrentDb)
            )),
        asadb_result_json(ok(saved_database(CurrentDb)), JSON),
        json_response(JSON)
    ;   json_error('403 Forbidden', 'Forbidden')
    ).
api_save(_) :-
    json_error('405 Method Not Allowed', 'POST only').

api_analyze(Request) :-
    member(method(post), Request), !,
    (   authorized_api(Request)
    ->  (   read_sql_body(Request, SQL)
        ->  asadb_analyze_sql(SQL, Diagnostics),
            asadb_analysis_json(Diagnostics, JSON),
            json_response(JSON)
        ;   json_error('400 Bad Request', 'Missing or oversized SQL payload')
        )
    ;   json_error('403 Forbidden', 'Forbidden')
    ).
api_analyze(_) :-
    json_error('405 Method Not Allowed', 'POST only').

api_state(Request) :-
    (   authorized_api(Request)
    ->  asadb_get_state(State),
        asadb_current_database(CurrentDb),
        asadb_result_json(table([state,current_db], [[State,CurrentDb]]), JSON),
        json_response(JSON)
    ;   json_error('403 Forbidden', 'Forbidden')
    ).

api_catalog(Request) :-
    (   authorized_api(Request)
    ->  asadb_current_database(CurrentDb),
        asadb_get_state(state(_, DBs)),
        findall(Row, catalog_row(CurrentDb, DBs, Row), Rows),
        asadb_result_json(table([current_db,database,kind,name,row_count,columns,indexes,query], Rows), JSON),
        json_response(JSON)
    ;   json_error('403 Forbidden', 'Forbidden')
    ).

api_metadata(Request) :-
    ( authorized_api(Request) ->
        asadb_database_metadata(CoreMetadata),
        reservoir_stats(Reservoir),
        Metadata = CoreMetadata.put(reservoir, Reservoir),
        json_dict_response(Metadata)
    ; json_error('403 Forbidden', 'Forbidden')
    ).

% The backup endpoint intentionally accepts only database/output controls.
% It never accepts table rows, browser state, or a client-side catalog: the
% production artifact is generated by scanning the backend record store.
api_backup(Request) :-
    member(method(post), Request), !,
    ( authorized_api(Request) ->
        catch(api_backup_authorized(Request), Error, api_backup_error(Error))
    ; json_error('403 Forbidden', 'Forbidden')
    ).
api_backup(_) :-
    json_error('405 Method Not Allowed', 'POST only').

api_backup_authorized(Request) :-
    http_read_data(Request, Data, []),
    backup_request_database(Data, Database),
    backup_request_output(Data, Output),
    asadb_backup_create(Database, BackupFile, Manifest),
    setup_call_cleanup(
        true,
        serve_production_backup(BackupFile, Database, Output, Manifest),
        asadb_backup_cleanup(BackupFile)
    ).

backup_request_database(Data, Database) :-
    member(database=Raw, Data),
    backup_database_value(Raw, Database), !.
backup_request_database(_, _) :-
    throw(error(domain_error(backup_database, missing), _)).

backup_database_value(Value, Database) :- atom(Value), !, Database = Value.
backup_database_value(Value, Database) :- string(Value), !, atom_string(Database, Value).
backup_database_value(Value, _) :- throw(error(domain_error(backup_database, Value), _)).

backup_request_output(Data, Output) :-
    member(output=Raw, Data), member(Raw, [save,open]), !, Output = Raw.
backup_request_output(_, save).

serve_production_backup(File, Database, Output, Manifest) :-
    size_file(File, Size),
    backup_download_name(Database, Name),
    security_headers,
    format('Content-type: application/octet-stream~n'),
    format('Content-length: ~w~n', [Size]),
    format('X-AsaDB-Backup-Format: ~w~n', [Manifest.format]),
    format('X-AsaDB-Backup-SHA256: ~w~n', [Manifest.payload_sha256]),
    ( Output == open -> Disposition = inline ; Disposition = attachment ),
    format('Content-Disposition: ~w; filename="~w"~n~n', [Disposition, Name]),
    setup_call_cleanup(
        open(File, read, In, [type(binary)]),
        copy_stream_data(In, current_output),
        close(In)
    ).

backup_download_name(Database, Name) :-
    atom_codes(Database, Codes),
    maplist(backup_filename_code, Codes, SafeCodes),
    atom_codes(Safe, SafeCodes),
    atomic_list_concat([Safe, '.asb'], Name).

backup_filename_code(Code, Code) :-
    ( Code >= 65, Code =< 90
    ; Code >= 97, Code =< 122
    ; Code >= 48, Code =< 57
    ; memberchk(Code, [45,95])
    ), !.
backup_filename_code(_, 95).

api_backup_error(Error) :-
    term_atom_safe(Error, Message),
    json_error('400 Bad Request', Message).

api_reservoir_jobs(Request) :-
    member(method(get), Request), !,
    ( authorized_api(Request) ->
        reservoir_job_snapshots(Snapshots),
        length(Snapshots, Count),
        json_dict_response(reservoir_jobs{count:Count,jobs:Snapshots})
    ; json_error('403 Forbidden', 'Forbidden')
    ).
api_reservoir_jobs(Request) :-
    member(method(post), Request), !,
    ( authorized_api(Request) ->
        ( request_stream_payload(Request, In, Size) ->
            request_stop_on_error(Request, StopOnError),
            request_idempotency_key(Request, IdempotencyKey),
            request_job_label(Request, Label),
            setup_call_cleanup(
                true,
                catch(
                    ( reservoir_submit_stream(In, Label, Size, IdempotencyKey, StopOnError,
                                              JobId, Admission),
                      reservoir_job_snapshot(JobId, Snapshot),
                      Response = reservoir_admission{
                          status:accepted,
                          admission:Admission,
                          job_id:JobId,
                          job:Snapshot
                      },
                      json_dict_response('202 Accepted', Response)
                    ),
                    Error,
                    reservoir_api_error(Error)
                ),
                close(In)
            )
        ; json_error('400 Bad Request', 'Missing or oversized Reservoir payload')
        )
    ; json_error('403 Forbidden', 'Forbidden')
    ).
api_reservoir_jobs(_) :-
    json_error('405 Method Not Allowed', 'GET or POST only').

api_reservoir_file(Request) :-
    member(method(post), Request), !,
    ( authorized_api(Request) ->
        http_read_data(Request, Data, []),
        ( member(path=RawPath, Data),
          allowed_import_path(RawPath, File),
          exists_file(File) ->
            catch(
                ( import_stop_on_error(Data, StopOnError),
                  form_idempotency_key(Data, IdempotencyKey),
                  reservoir_submit_file(File, File, IdempotencyKey, StopOnError,
                                        JobId, Admission, Size),
                  reservoir_job_snapshot(JobId, Snapshot),
                  Response = reservoir_admission{
                      status:accepted,
                      admission:Admission,
                      job_id:JobId,
                      size_bytes:Size,
                      job:Snapshot
                  },
                  json_dict_response('202 Accepted', Response)
                ),
                Error,
                reservoir_api_error(Error)
            )
        ; json_error('400 Bad Request', 'Import file path is not allowed or not found')
        )
    ; json_error('403 Forbidden', 'Forbidden')
    ).
api_reservoir_file(_) :-
    json_error('405 Method Not Allowed', 'POST only').

api_reservoir_job(Request) :-
    member(method(get), Request), !,
    ( authorized_api(Request) ->
        catch(
            ( reservoir_http_job_id(Request, JobId),
              reservoir_job_snapshot(JobId, Snapshot),
              json_dict_response(Snapshot)
            ),
            Error,
            reservoir_api_error(Error)
        )
    ; json_error('403 Forbidden', 'Forbidden')
    ).
api_reservoir_job(_) :-
    json_error('405 Method Not Allowed', 'GET only').

api_reservoir_result(Request) :-
    member(method(get), Request), !,
    ( authorized_api(Request) ->
        catch(
            ( reservoir_http_result_parameters(Request, JobId, Offset, Limit),
              reservoir_job_result_page(JobId, Offset, Limit, Result),
              asadb_result_json(Result, JSON),
              json_response(JSON)
            ),
            Error,
            reservoir_api_error(Error)
        )
    ; json_error('403 Forbidden', 'Forbidden')
    ).
api_reservoir_result(_) :-
    json_error('405 Method Not Allowed', 'GET only').

api_reservoir_cancel(Request) :-
    member(method(post), Request), !,
    ( authorized_api(Request) ->
        catch(
            ( reservoir_http_job_id(Request, JobId),
              reservoir_cancel(JobId, Snapshot),
              json_dict_response(Snapshot)
            ),
            Error,
            reservoir_api_error(Error)
        )
    ; json_error('403 Forbidden', 'Forbidden')
    ).
api_reservoir_cancel(_) :-
    json_error('405 Method Not Allowed', 'POST only').

api_reservoir_stats(Request) :-
    member(method(get), Request), !,
    ( authorized_api(Request) ->
        reservoir_stats(Stats),
        json_dict_response(Stats)
    ; json_error('403 Forbidden', 'Forbidden')
    ).
api_reservoir_stats(_) :-
    json_error('405 Method Not Allowed', 'GET only').

api_import_file(Request) :-
    member(method(post), Request), !,
    (   authorized_api(Request)
    ->  catch(api_import_file_authorized(Request), Error, api_import_upload_error(Error))
    ;   json_error('403 Forbidden', 'Forbidden')
    ).
api_import_file(_) :-
    json_error('405 Method Not Allowed', 'POST only').

api_import_file_authorized(Request) :-
    http_read_data(Request, Data, []),
    (   member(path=RawPath, Data),
        allowed_import_path(RawPath, File),
        exists_file(File)
    ->  import_stop_on_error(Data, StopOnError),
        import_id(Data, ImportId),
        with_mutex(asadb_execution,
                   import_uploaded_database_file(File, File,
                                                 StopOnError, ImportId, Result)),
        asadb_result_json(Result, JSON),
        json_response(JSON)
    ;   json_error('400 Bad Request', 'Import file path is not allowed or not found')
    ).

api_import_upload(Request) :-
    member(method(post), Request), !,
    (   authorized_api(Request)
    ->  catch(api_import_upload_authorized(Request),
              Error,
              api_import_upload_error(Error))
    ;   json_error('403 Forbidden', 'Forbidden')
    ).
api_import_upload(_) :-
    json_error('405 Method Not Allowed', 'POST only').

api_import_upload_authorized(Request) :-
    http_read_data(Request, Data, [on_filename(save_uploaded_import_part)]),
    (   member(file=upload(TempFile, OriginalName, Size), Data)
    ->  import_stop_on_error(Data, StopOnError),
        import_id(Data, ImportId),
        setup_call_cleanup(
            true,
            with_mutex(asadb_execution,
                       import_uploaded_database_file(TempFile, OriginalName,
                                                     StopOnError, ImportId, Result0)),
            cleanup_uploaded_import_file(TempFile)
        ),
        uploaded_import_result(Result0, OriginalName, Size, Result),
        asadb_result_json(Result, JSON),
        json_response(JSON)
    ;   json_error('400 Bad Request', 'No SQL upload file found')
    ).

% A production backup is verified before it reaches the SQL importer.  Its
% catalog-only objects are staged immediately before COMMIT, making the full
% restore atomic: SQL rows and catalog objects succeed or roll back together.
import_uploaded_database_file(File, OriginalName, StopOnError, ImportId, Result) :-
    ( production_backup_candidate(File, OriginalName) ->
        asadb_backup_prepare_restore(File, Database, PayloadFile, Manifest),
        setup_call_cleanup(
            true,
            import_verified_production_backup(PayloadFile, Database, Manifest,
                                              StopOnError, ImportId, Result),
            asadb_backup_cleanup(PayloadFile)
        )
    ; import_sql_file_backend(File, StopOnError, ImportId, Result)
    ).

% A file called .asb is never permitted to fall through into the generic SQL
% importer.  That prevents a damaged production backup from being interpreted
% as comment-prefixed SQL and bypassing its integrity checks.  The marker
% probe also catches the common "one broken byte in the magic" case when a
% file has been renamed before upload.
production_backup_candidate(_File, OriginalName) :-
    production_backup_name(OriginalName), !.
production_backup_candidate(File, _) :-
    asadb_backup_file(File), !.
production_backup_candidate(File, _) :-
    production_backup_marker_present(File).

production_backup_name(Name) :-
    atom(Name), file_name_extension(_, Extension0, Name),
    downcase_atom(Extension0, asb), !.
production_backup_name(Name) :-
    string(Name), atom_string(Atom, Name), production_backup_name(Atom).

production_backup_marker_present(File) :-
    setup_call_cleanup(
        open(File, read, In, [type(binary)]),
        ( read_string(In, 4096, Prefix),
          sub_string(Prefix, _, _, _, 'ASADB-PRODUCTION-BACKUP')
        ),
        close(In)
    ).

import_verified_production_backup(PayloadFile, Database, Manifest,
                                  StopOnError, ImportId, Result) :-
    CatalogObjects = Manifest.catalog_objects,
    CatalogObjects = catalog_objects(Views, Functions, Procedures, Triggers),
    import_sql_file_backend_before_commit(
        PayloadFile, StopOnError, ImportId,
        import_verified_backup_precommit(Database, Manifest, Views, Functions, Procedures, Triggers),
        Result
    ).

import_verified_backup_precommit(Database, Manifest, Views, Functions, Procedures, Triggers) :-
    asadb_backup_validate_restored_snapshot(Database, Manifest),
    asadb_backup_stage_catalog_objects(Database, Views, Functions, Procedures, Triggers).

api_import_upload_error(Error) :-
    term_atom_safe(Error, Message),
    json_error('400 Bad Request', Message).

term_atom_safe(Term, Atom) :-
    catch(message_to_string(Term, String), _, fail), !,
    atom_string(Atom, String).
term_atom_safe(Term, Atom) :-
    with_output_to(atom(Atom), write_term(Term, [quoted(true), max_depth(8)])).

save_uploaded_import_part(In, upload(TempFile, BaseName, Size), Options) :-
    memberchk(filename(ClientName), Options),
    uploaded_file_base(ClientName, BaseName),
    safe_import_file_name(BaseName), !,
    tmp_file_stream(octet, TempFile, Out),
    setup_call_cleanup(
        true,
        copy_stream_data(In, Out),
        close(Out)
    ),
    size_file(TempFile, Size).
save_uploaded_import_part(_, _, Options) :-
    memberchk(filename(ClientName), Options),
    uploaded_file_base(ClientName, BaseName),
    throw(error(permission_error(import, file, BaseName), _)).

uploaded_file_base(Raw, Base) :-
    atom_codes(Raw, Codes0),
    maplist(import_slash_code, Codes0, Codes),
    atom_codes(Slashed, Codes),
    atomic_list_concat(Parts0, '/', Slashed),
    exclude(=(''), Parts0, Parts),
    Parts \= [],
    last(Parts, Base).

cleanup_uploaded_import_file(File) :-
    (   exists_file(File)
    ->  catch(delete_file(File), _, true)
    ;   true
    ).

uploaded_import_result(table(Columns, [[Status, _TempPath, Statements, Errors, LastStatus, LastMessage, _TempSize]]),
                       OriginalName,
                       Size,
                       table(Columns, [[Status,OriginalName,Statements,Errors,LastStatus,LastMessage,Size]])) :- !.
uploaded_import_result(Result, _, _, Result).

api_import_progress(Request) :-
    (   authorized_api(Request)
    ->  http_parameters(Request, [id(Id, [atom, default('')])]),
        import_progress_result(Id, Result),
        asadb_result_json(Result, JSON),
        json_response(JSON)
    ;   json_error('403 Forbidden', 'Forbidden')
    ).

allowed_import_path(RawPath, File) :-
    normalize_import_path(RawPath, Clean),
    allowed_import_path_clean(Clean, File).

allowed_import_path_clean(Clean, File) :-
    atomic_list_concat(['test', Name], '/', Clean),
    safe_import_file_name(Name), !,
    stress_import_file(Name, File).
allowed_import_path_clean(Clean, File) :-
    atomic_list_concat(['stress test', Name], '/', Clean),
    safe_import_file_name(Name), !,
    stress_import_file(Name, File).
allowed_import_path_clean(Clean, File) :-
    atomic_list_concat(['stress-test', Name], '/', Clean),
    safe_import_file_name(Name), !,
    stress_import_file(Name, File).
allowed_import_path_clean(Clean, File) :-
    atomic_list_concat(['stress_test', Name], '/', Clean),
    safe_import_file_name(Name), !,
    stress_import_file(Name, File).
allowed_import_path_clean(Clean, File) :-
    atomic_list_concat(['stress tests', Name], '/', Clean),
    safe_import_file_name(Name), !,
    stress_import_file(Name, File).
allowed_import_path_clean(Clean, File) :-
    atomic_list_concat(['samples', Name], '/', Clean),
    safe_import_file_name(Name), !,
    atom_concat('web/samples/', Name, File).
allowed_import_path_clean(Clean, File) :-
    atomic_list_concat(['web', 'samples', Name], '/', Clean),
    safe_import_file_name(Name), !,
    atom_concat('web/samples/', Name, File).

safe_import_file_name(Name) :-
    \+ sub_atom(Name, _, _, _, '/'),
    file_name_extension(_, Ext, Name),
    member(Ext, [asb,sql,mysql,pgsql,psql,postgres]).

stress_import_file(Name, File) :-
    directory_file_path('stress tests', Name, Candidate),
    ( exists_file(Candidate) ->
        File = Candidate
    ; stress_import_file_casefold(Name, File)
    ).

stress_import_file_casefold(Name, File) :-
    directory_files('stress tests', Entries),
    member(Entry, Entries),
    downcase_atom(Entry, Name),
    safe_import_file_name(Entry),
    directory_file_path('stress tests', Entry, File),
    exists_file(File), !.

normalize_import_path(RawPath, Clean) :-
    atom_codes(RawPath, Codes0),
    maplist(import_slash_code, Codes0, Codes1),
    atom_codes(Slashed, Codes1),
    atomic_list_concat(Parts0, '/', Slashed),
    exclude(=(''), Parts0, Parts),
    \+ member('..', Parts),
    atomic_list_concat(Parts, '/', Joined),
    downcase_atom(Joined, Clean).

import_slash_code(92, 47) :- !.
import_slash_code(Code, Code).

import_stop_on_error(Data, true) :-
    member(stop_on_error=Value, Data),
    member(Value, [true, 'true', yes, 'yes', '1', 1]), !.
import_stop_on_error(_, false).

import_id(Data, Id) :-
    member(import_id=Raw, Data),
    atom(Raw),
    Raw \= '', !,
    Id = Raw.
import_id(_, Id) :-
    random_between(100000000, 999999999, N),
    format(atom(Id), 'import-~w', [N]).

import_sql_file_backend(File, StopOnError, ImportId, Result) :-
    import_sql_file_backend_before_commit(File, StopOnError, ImportId, true, Result).

import_sql_file_backend_before_commit(File, StopOnError, ImportId, BeforeCommit, Result) :-
    size_file(File, Size),
    setup_call_cleanup(
        open(File, read, In, [type(binary)]),
        import_sql_stream_backend_before_commit(In, File, Size, StopOnError, ImportId,
                                                BeforeCommit, Result),
        close(In)
    ).

import_sql_stream_backend(In, Label, Size, StopOnError, ImportId, Result) :-
    import_sql_stream_backend_before_commit(In, Label, Size, StopOnError, ImportId, true, Result).

import_sql_stream_backend_before_commit(In, Label, Size, StopOnError, ImportId,
                                        BeforeCommit, Result) :-
    flag(asadb_import_batches, _, 0),
    ensure_import_not_cancelled(ImportId),
    set_import_progress(ImportId, Label, Size, 0, 0, 0, running, 'starting', false),
    ensure_import_transaction_idle,
    asadb_backup_capture_current_database(PreviousDatabase),
    import_transaction_command('BEGIN;'),
    catch(
        import_sql_stream_backend_transaction(In, Label, Size, StopOnError, ImportId,
                                              BeforeCommit, PreviousDatabase, Result),
        Error,
        ( import_rollback_safely,
          restore_import_database_safely(PreviousDatabase),
          record_import_failure(ImportId, Label, Size, Error),
          throw(Error)
        )
    ).

import_sql_stream_backend_transaction(In, Label, Size, StopOnError, ImportId,
                                      BeforeCommit, PreviousDatabase, Result) :-
    statistics(walltime, [StreamStart|_]),
    setup_call_cleanup(
        retractall(asadb_import_pending(ImportId, _)),
        import_sql_stream(In, StopOnError, Label, Size, ImportId, 0, 0, 0, none, [], [], none, '', Stats),
        retractall(asadb_import_pending(ImportId, _))
    ),
    statistics(walltime, [StreamEnd|_]),
    garbage_collect,
    trim_stacks,
    Stats = import_stats(Statements, Errors, LastStatus, LastMessage, BytesRead),
    ( Errors =:= 0 ->
        ensure_import_not_cancelled(ImportId),
        must_run_before_commit(BeforeCommit),
        statistics(walltime, [CommitStart|_]),
        import_transaction_command('COMMIT;'),
        statistics(walltime, [CommitEnd|_]),
        StreamMs is StreamEnd - StreamStart,
        CommitMs is CommitEnd - CommitStart,
        format(user_error,
               'AsA import timing: stream=~w ms, commit=~w ms, statements=~w~n',
               [StreamMs, CommitMs, Statements]),
        set_import_progress(ImportId, Label, Size, BytesRead, Statements, Errors, committed, LastMessage, true),
        Result = table([status,path,statements,errors,last_status,last_message,size_bytes],
                       [[ok,Label,Statements,Errors,LastStatus,LastMessage,Size]])
    ;   import_transaction_command('ROLLBACK;'),
        asadb_backup_restore_current_database(PreviousDatabase),
        set_import_progress(ImportId, Label, Size, BytesRead, Statements, Errors, rolled_back, LastMessage, true),
        Result = table([status,path,statements,errors,last_status,last_message,size_bytes],
                       [[rolled_back,Label,Statements,Errors,LastStatus,LastMessage,Size]])
    ).

ensure_import_transaction_idle :-
    ( asadb_backup_transaction_active ->
        throw(error(permission_error(import, database, active_transaction), _))
    ; true
    ).

must_run_before_commit(Goal) :-
    ( call(Goal) -> true
    ; throw(error(integrity_error(backup_precommit_failed), _))
    ).

import_transaction_command(SQL) :-
    asadb_exec_sql(SQL, Result),
    ( import_transaction_result_ok(Result) -> true
    ; throw(error(transaction_command_failed(SQL, Result), _))
    ).

import_transaction_result_ok(multi(Results)) :-
    Results \= [],
    \+ member(error(_, _), Results), !.
import_transaction_result_ok(ok(_)).

import_rollback_safely :-
    catch(import_transaction_command('ROLLBACK;'), _, true).

restore_import_database_safely(Database) :-
    catch(asadb_backup_restore_current_database(Database), _, true).

import_sql_stream(In, StopOnError, File, Size, ImportId, Bytes0, Statements0, Errors0, Mode0, RevAcc0, Utf8Carry0, LastStatus0, LastMessage0, Stats) :-
    ensure_import_not_cancelled(ImportId),
    import_read_block(In, Size, Bytes0, BlockString),
    string_length(BlockString, BlockLength),
    ( BlockLength =:= 0 ->
        ( Utf8Carry0 == [] -> true ; throw(error(invalid_utf8_tail(Utf8Carry0), _)) ),
        import_flush_pending(RevAcc0, StopOnError, File, Size, ImportId, Bytes0, Statements0, Errors0, LastStatus0, LastMessage0, Stats)
    ; string_codes(BlockString, RawBytes),
      length(RawBytes, BlockBytes),
      append(Utf8Carry0, RawBytes, Utf8Bytes),
      phrase(utf8_codes(BlockCodes), Utf8Bytes, Utf8Carry),
      Bytes1 is Bytes0 + BlockBytes,
      scan_sql_line(BlockCodes, Mode0, RevAcc0, [], Mode, RevAcc, StatementCodes),
      queue_import_statements(ImportId, StatementCodes),
      % Publish the read position before a large bounded batch is executed.
      % Generated stress files can contain thousands of rows in one batch;
      % reporting only after execution made a live panel look frozen.
      maybe_set_import_progress(ImportId, File, Size, Bytes0, Bytes1,
                                Statements0, Errors0, none,
                                'buffered; executing batch'),
      flush_import_statements(ImportId, false, StopOnError, Statements0, Errors0,
                              Statements1, Errors1, LastStatus, LastMessage, Stop),
      merge_import_last(LastStatus0, LastMessage0, LastStatus, LastMessage, LastStatus1, LastMessage1),
      maybe_set_import_progress(ImportId, File, Size, Bytes0, Bytes1,
                                Statements1, Errors1, LastStatus, LastMessage1),
      ( Stop == true ->
          Stats = import_stats(Statements1, Errors1, LastStatus1, LastMessage1, Bytes1)
      ; import_sql_stream(In, StopOnError, File, Size, ImportId, Bytes1, Statements1, Errors1, Mode, RevAcc, Utf8Carry, LastStatus1, LastMessage1, Stats)
      )
    ).

import_read_block_size(262144).

import_read_block(_, Size, BytesRead, "") :-
    Size > 0,
    BytesRead >= Size, !.
import_read_block(In, Size, BytesRead, BlockString) :-
    import_read_block_size(BlockSize),
    ( Size > 0 ->
        Remaining is Size - BytesRead,
        ReadSize is min(BlockSize, Remaining)
    ; ReadSize = BlockSize
    ),
    read_string(In, ReadSize, BlockString).

import_flush_pending(RevAcc, StopOnError, File, Size, ImportId, BytesRead, Statements0, Errors0, LastStatus0, LastMessage0, Stats) :-
    reverse(RevAcc, Codes),
    trim_sql_codes(Codes, Trimmed),
    queue_import_statements(ImportId, [Trimmed]),
    flush_import_statements(ImportId, true, StopOnError, Statements0, Errors0,
                            Statements, Errors, LastStatus, LastMessage, _),
    merge_import_last(LastStatus0, LastMessage0, LastStatus, LastMessage, FinalStatus, FinalMessage),
    set_import_progress(ImportId, File, Size, BytesRead, Statements, Errors, running, FinalMessage, false),
    Stats = import_stats(Statements, Errors, FinalStatus, FinalMessage, BytesRead).

maybe_set_import_progress(ImportId, File, Size, _, Bytes, Statements, Errors, LastStatus, Message) :-
    LastStatus \== none, !,
    set_import_progress(ImportId, File, Size, Bytes, Statements, Errors, running, Message, false).
maybe_set_import_progress(ImportId, File, Size, Bytes0, Bytes, Statements, Errors, _, Message) :-
    ProgressQuantum is 64 * 1024,
    PreviousBucket is Bytes0 // ProgressQuantum,
    CurrentBucket is Bytes // ProgressQuantum,
    CurrentBucket > PreviousBucket, !,
    set_import_progress(ImportId, File, Size, Bytes, Statements, Errors, running, Message, false).
maybe_set_import_progress(_, _, _, _, _, _, _, _, _).

import_statement_batch_size(BatchSize) :-
    asadb_config_get(import_batch_size, BatchSize).

queue_import_statements(_, []).
queue_import_statements(ImportId, [Codes|Statements]) :-
    ( Codes == [] -> true ; assertz(asadb_import_pending(ImportId, Codes)) ),
    queue_import_statements(ImportId, Statements).

flush_import_statements(ImportId, Force, StopOnError, Statements0, Errors0,
                        Statements, Errors, LastStatus, LastMessage, Stop) :-
    aggregate_all(count, asadb_import_pending(ImportId, _), PendingCount),
    import_statement_batch_size(BatchSize),
    ( PendingCount =:= 0 ->
        Statements = Statements0,
        Errors = Errors0,
        LastStatus = none,
        LastMessage = '',
        Stop = false
    ; ( Force == true ; PendingCount >= BatchSize ) ->
        findall(Codes, retract(asadb_import_pending(ImportId, Codes)), CodeGroups),
        statement_groups_sql(CodeGroups, SQLCodes),
        asadb_exec_sql(SQLCodes, Result),
        length(CodeGroups, ExecutedCount),
        Statements is Statements0 + ExecutedCount,
        result_error_count(Result, BatchErrors),
        Errors is Errors0 + BatchErrors,
        result_status_message(Result, LastStatus, LastMessage),
        ( StopOnError == true, BatchErrors > 0 -> Stop = true ; Stop = false ),
        release_import_batch_memory
    ;   Statements = Statements0,
        Errors = Errors0,
        LastStatus = none,
        LastMessage = '',
        Stop = false
    ).

release_import_batch_memory :-
    flag(asadb_import_batches, Batch0, Batch0 + 1),
    ( Batch0 mod 8 =:= 7 -> garbage_collect, trim_stacks ; true ).

statement_groups_sql([], []).
statement_groups_sql([Codes|Groups], SQL) :-
    append(Codes, [59,10|Rest], SQL),
    statement_groups_sql(Groups, Rest).

result_error_count(error(_, _), 1) :- !.
result_error_count(multi(Results), Count) :- !,
    maplist(result_error_count, Results, Counts),
    sum_list(Counts, Count).
result_error_count(_, 0).

set_import_progress(Id, Path, Size, Bytes, Statements, Errors, Status, Message, Done) :-
    with_mutex(asadb_import_progress_state,
        ( retractall(asadb_import_progress(Id, _, _, _, _, _, _, _, _)),
          assertz(asadb_import_progress(Id, Path, Size, Bytes, Statements, Errors,
                                       Status, Message, Done))
        )),
    catch(reservoir_update_progress(Id, Bytes, Statements, Errors, Status, Message, Done), _, true).

record_import_failure(ImportId, DefaultPath, DefaultSize, Error) :-
    import_cancelled_error(ImportId, Error), !,
    current_import_progress(ImportId, DefaultPath, DefaultSize,
                            Path, Size, Bytes, Statements, Errors),
    set_import_progress(ImportId, Path, Size, Bytes, Statements, Errors,
                        cancelled, 'Cancellation requested; transaction rolled back.', true).
record_import_failure(ImportId, DefaultPath, DefaultSize, Error) :-
    term_atom_safe(Error, ErrorMessage),
    current_import_progress(ImportId, DefaultPath, DefaultSize,
                            Path, Size, Bytes, Statements, Errors0),
    Errors is Errors0 + 1,
    set_import_progress(ImportId, Path, Size, Bytes, Statements, Errors,
                        error, ErrorMessage, true).

import_cancelled_error(ImportId, error(reservoir_cancelled(ImportId), _)).
import_cancelled_error(ImportId, reservoir_cancelled(ImportId)).

current_import_progress(Id, DefaultPath, DefaultSize,
                        Path, Size, Bytes, Statements, Errors) :-
    with_mutex(asadb_import_progress_state,
        ( asadb_import_progress(Id, Path0, Size0, Bytes0, Statements0, Errors0,
                                _, _, _) ->
            Path = Path0,
            Size = Size0,
            Bytes = Bytes0,
            Statements = Statements0,
            Errors = Errors0
        ; Path = DefaultPath,
          Size = DefaultSize,
          Bytes = 0,
          Statements = 0,
          Errors = 0
        )).

ensure_import_not_cancelled(ImportId) :-
    ( catch(reservoir_cancel_requested(ImportId), _, fail) ->
        throw(error(reservoir_cancelled(ImportId), _))
    ; true
    ).

import_progress_result(Id, table([id,path,size_bytes,bytes_read,statements,errors,status,message,done], Rows)) :-
    with_mutex(asadb_import_progress_state,
        findall([Id,Path,Size,Bytes,Statements,Errors,Status,Message,Done],
                asadb_import_progress(Id, Path, Size, Bytes, Statements, Errors,
                                      Status, Message, Done),
                Found)),
    ( Found = [] -> Rows = [[Id,'',0,0,0,0,waiting,'',false]]
    ; Rows = Found
    ).

merge_import_last(PrevStatus, PrevMessage, none, _, PrevStatus, PrevMessage) :- !.
merge_import_last(_, _, Status, Message, Status, Message).

scan_sql_line([], line_comment, RevAcc, RevStatements, none, RevAcc, Statements) :- !,
    reverse(RevStatements, Statements).
scan_sql_line([], Mode, RevAcc, RevStatements, Mode, RevAcc, Statements) :- !,
    reverse(RevStatements, Statements).
scan_sql_line([59|Cs], none, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    reverse(RevAcc, Codes),
    trim_sql_codes(Codes, Trimmed),
    scan_sql_line(Cs, none, [], [Trimmed|RevStatements], Mode, RevOut, Statements).
scan_sql_line([45,45|Cs], none, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, line_comment, [45,45|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([35|Cs], none, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, line_comment, [35|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([47,42|Cs], none, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, block_comment, [42,47|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([39|Cs], none, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, single, [39|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([34|Cs], none, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, double, [34|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([96|Cs], none, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, backtick, [96|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([10|Cs], line_comment, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, none, [10|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([42,47|Cs], block_comment, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, none, [47,42|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([92,C|Cs], single, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, single, [C,92|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([92,C|Cs], double, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, double, [C,92|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([39|Cs], single, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, none, [39|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([34|Cs], double, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, none, [34|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([96|Cs], backtick, RevAcc, RevStatements, Mode, RevOut, Statements) :- !,
    scan_sql_line(Cs, none, [96|RevAcc], RevStatements, Mode, RevOut, Statements).
scan_sql_line([C|Cs], Mode0, RevAcc, RevStatements, Mode, RevOut, Statements) :-
    scan_sql_line(Cs, Mode0, [C|RevAcc], RevStatements, Mode, RevOut, Statements).

execute_statement_codes([], _, Statements, Errors, Statements, Errors, none, '', false).
execute_statement_codes([Codes|Rest], StopOnError, Statements0, Errors0, Statements, Errors, LastStatus, LastMessage, Stop) :-
    ( Codes == [] ->
        execute_statement_codes(Rest, StopOnError, Statements0, Errors0, Statements, Errors, LastStatus, LastMessage, Stop)
    ; atom_codes(SQL, Codes),
      asadb_exec_sql(SQL, Result),
      result_status_message(Result, Status, Message),
      Statements1 is Statements0 + 1,
      ( result_has_error(Result) -> Errors1 is Errors0 + 1 ; Errors1 = Errors0 ),
      ( StopOnError == true, result_has_error(Result) ->
          Statements = Statements1,
          Errors = Errors1,
          LastStatus = Status,
          LastMessage = Message,
          Stop = true
      ; execute_statement_codes(Rest, StopOnError, Statements1, Errors1, Statements, Errors, LastStatus0, LastMessage0, Stop),
        ( LastStatus0 == none -> LastStatus = Status, LastMessage = Message ; LastStatus = LastStatus0, LastMessage = LastMessage0 )
      )
    ).

result_has_error(error(_, _)) :- !.
result_has_error(multi(Results)) :- !, member(Result, Results), result_has_error(Result).
result_has_error(_):- fail.

result_status_message(ok(Message), ok, Message) :- !.
result_status_message(error(_, Message), error, Message) :- !.
result_status_message(table(_, Rows), table, Message) :- !,
    length(Rows, Count),
    format(atom(Message), '~w row(s)', [Count]).
result_status_message(multi(Results), Status, Message) :- !,
    last_result_status_message(Results, Status, Message).
result_status_message(Result, ok, Atom) :-
    term_to_atom(Result, Atom).

last_result_status_message([], none, '').
last_result_status_message([Result], Status, Message) :- !, result_status_message(Result, Status, Message).
last_result_status_message([_|Rest], Status, Message) :- last_result_status_message(Rest, Status, Message).

trim_sql_codes(Codes, Trimmed) :-
    drop_sql_ws(Codes, Left),
    reverse(Left, Rev),
    drop_sql_ws(Rev, RevTrimmed),
    reverse(RevTrimmed, Trimmed).

drop_sql_ws([C|Cs], Rest) :- member(C, [9,10,13,32]), !, drop_sql_ws(Cs, Rest).
drop_sql_ws(Codes, Codes).

catalog_row(CurrentDb, DBs, [CurrentDb, DBName, database, DBName, 0, [], [], '']) :-
    member(DBTerm, DBs),
    db_catalog_parts(DBTerm, DBName, _, _),
    visible_catalog_db(DBName).
catalog_row(CurrentDb, DBs, [CurrentDb, DBName, table, TableName, RowCount, Columns, Indexes, '']) :-
    member(DBTerm, DBs),
    db_catalog_parts(DBTerm, DBName, Tables, _),
    visible_catalog_db(DBName),
    member(TableTerm, Tables),
    table_catalog_parts(TableTerm, TableName, Columns, RowStorage, Indexes),
    catalog_row_count(RowStorage, RowCount).
catalog_row(CurrentDb, DBs, [CurrentDb, DBName, view, ViewName, 0, [], [], Query]) :-
    member(DBTerm, DBs),
    db_catalog_parts(DBTerm, DBName, _, Views),
    visible_catalog_db(DBName),
    member(ViewTerm, Views),
    view_catalog_parts(ViewTerm, ViewName, Query).

visible_catalog_db(Name) :- \+ sub_atom(Name, 0, 2, _, '__').

db_catalog_parts(db(Name, Tables, Views, _, _, _), Name, Tables, Views) :- !.
db_catalog_parts(db(Name, Tables), Name, Tables, []).

table_catalog_parts(table(Name, Columns, Rows, Indexes), Name, Columns, Rows, Indexes) :- !.
table_catalog_parts(table(Name, Columns, Rows), Name, Columns, Rows, []).

catalog_row_count(paged_rows(_, Count, _), Count) :- !.
catalog_row_count(Rows, Count) :- length(Rows, Count).

view_catalog_parts(view(Name, Query, _), Name, Query) :- !.
view_catalog_parts(view(Name, Query), Name, Query) :- !.
view_catalog_parts(Name, Name, '').

read_sql_body(Request, SQL) :-
    http_read_data(Request, Data, []),
    member(sql=SQL, Data),
    atom_length(SQL, Len),
    Len =< 250000.

request_stream_payload(Request, In, Size) :-
    member(input(RawIn), Request),
    request_content_size(Request, Size),
    asadb_config_get(reservoir_max_spool_bytes, MaxSpoolBytes),
    Size > 0,
    Size =< MaxSpoolBytes,
    stream_range_open(RawIn, In, [size(Size)]),
    set_stream(In, encoding(octet)).

request_content_size(Request, Size) :-
    member(content_length(Size0), Request),
    content_size_number(Size0, Number), !,
    Size is max(0, Number).
request_content_size(_, 0).

content_size_number(Value, Value) :- number(Value), !.
content_size_number(Value, Number) :- atom(Value), atom_number(Value, Number).

request_import_id(Request, Id) :-
    request_header(x_asadb_import_id, Request, Raw),
    atom(Raw),
    Raw \= '', !,
    Id = Raw.
request_import_id(_, Id) :-
    random_between(100000000, 999999999, N),
    format(atom(Id), 'stream-~w', [N]).

request_stop_on_error(Request, true) :-
    request_header(x_asadb_stop_on_error, Request, Value),
    member(Value, [true, 'true', yes, 'yes', '1', 1]), !.
request_stop_on_error(_, false).

request_idempotency_key(Request, Key) :-
    request_header(x_asadb_idempotency_key, Request, Raw),
    atom(Raw),
    Raw \= '', !,
    Key = Raw.
request_idempotency_key(Request, Key) :-
    request_header(x_asadb_import_id, Request, Raw),
    atom(Raw),
    Raw \= '', !,
    Key = Raw.
request_idempotency_key(_, '').

request_job_label(Request, Label) :-
    request_header(x_asadb_job_label, Request, Raw),
    atom(Raw),
    Raw \= '', !,
    Label = Raw.
request_job_label(_, 'SQL command').

form_idempotency_key(Data, Key) :-
    member(idempotency_key=Raw, Data),
    atom(Raw),
    Raw \= '', !,
    Key = Raw.
form_idempotency_key(Data, Key) :-
    import_id(Data, Key).

reservoir_http_job_id(Request, JobId) :-
    http_parameters(Request, [id(JobId, [atom])]).

reservoir_http_result_parameters(Request, JobId, Offset, Limit) :-
    asadb_config_get(reservoir_result_page_rows, DefaultLimit),
    http_parameters(Request, [
        id(JobId, [atom]),
        offset(Offset0, [integer, default(0)]),
        limit(Limit0, [integer, default(DefaultLimit)])
    ]),
    Offset is max(0, Offset0),
    Limit is max(1, min(DefaultLimit, Limit0)).

reservoir_api_error(error(resource_error(reservoir_job_slots), _)) :- !,
    json_error('429 Too Many Requests', 'Reservoir queue is full; retry after an active job finishes.').
reservoir_api_error(error(resource_error(reservoir_spool_capacity), _)) :- !,
    json_error('507 Insufficient Storage', 'Reservoir spool capacity would be exceeded.').
reservoir_api_error(error(existence_error(reservoir_job, _), _)) :- !,
    json_error('404 Not Found', 'Reservoir job was not found or has expired.').
reservoir_api_error(Error) :-
    term_atom_safe(Error, Message),
    json_error('400 Bad Request', Message).

authorized_api(Request) :-
    request_token(Request, Token),
    asadb_panel_token(Token), !.

request_token(Request, Token) :-
    request_header(x_asadb_token, Request, Token).
request_token(Request, Token) :-
    request_header(cookie, Request, Cookie),
    cookie_token(Cookie, Token).

request_header(Name, Request, Value) :-
    member(Header, Request),
    Header =.. [Name, Value].

cookie_token(Cookie, Token) :-
    is_list(Cookie), !,
    member(asadb_token=Token, Cookie).
cookie_token(Cookie, Token) :-
    atomic_list_concat(Parts, ';', Cookie),
    member(Part0, Parts),
    normalize_space(atom(Part), Part0),
    sub_atom(Part, 0, _, _, 'asadb_token='),
    sub_atom(Part, 12, _, 0, Token).

security_headers :-
    format('X-Content-Type-Options: nosniff~n'),
    format('Referrer-Policy: no-referrer~n'),
    format('X-Frame-Options: DENY~n'),
    format('Cross-Origin-Resource-Policy: same-origin~n'),
    format('Content-Security-Policy: default-src ''self''; script-src ''self''; style-src ''self''; img-src ''self'' data:; media-src ''self''; connect-src ''self''; base-uri ''none''; frame-ancestors ''none''~n'),
    format('Cache-Control: no-store~n').

json_response(JSON) :-
    security_headers,
    format('Content-type: application/json~n~n'),
    format('~w', [JSON]).

json_dict_response(Dict) :-
    security_headers,
    format('Content-type: application/json~n~n'),
    json_write_dict(current_output, Dict, [width(0)]).

json_dict_response(Status, Dict) :-
    format('Status: ~w~n', [Status]),
    json_dict_response(Dict).

json_error(Status, Message) :-
    format('Status: ~w~n', [Status]),
    security_headers,
    format('Content-type: application/json~n~n'),
    json_write_dict(current_output, _{status:error,message:Message}, [width(0)]).
