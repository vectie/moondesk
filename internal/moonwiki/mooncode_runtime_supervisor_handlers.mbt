///|
async fn handle_mooncode_session_runtime_supervisor(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_receipt_log(
        workspace_root, session_id,
      )
      let events = read_mooncode_event_log(workspace_root, session_id)
      let daemon = moonclaw_daemon_status(workspace_root)
      let native_ready = if json_bool(daemon, "running", default=false) {
        mooncode_native_runtime_ready(daemon) catch {
          _ => false
        }
      } else {
        false
      }
      send_json(
        conn,
        method_,
        mooncode_runtime_supervisor_launch_packet(
          workspace_root,
          session,
          session_id,
          commands,
          receipts,
          events,
          daemon,
          native_ready~,
          lease_now=@async.now().to_string(),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_supervisor_run(
  workspace_root : String,
  session_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = read_json_body(body).unwrap_or(Json::object({}))
  let session = match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="runtime-supervisor-run",
  )
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn, method_, 409, "Conflict", "MoonClaw daemon is not running",
    )
    return
  }
  if !mooncode_native_runtime_ready(daemon) {
    send_api_error(
      conn, method_, 409, "Conflict", "MoonClaw native MoonCode runtime is not available",
    )
    return
  }
  let loop_body = @mooncode.moonclaw_runtime_loop_request(
    session_id,
    workspace_root,
    consumer_id=json_string(
      payload,
      "consumer_id",
      default="moondesk-ui-runtime-loop",
    ),
    max_turns=json_int(payload, "max_turns", default=8),
    live_wait_ms=json_int(payload, "live_wait_ms", default=5000),
    poll_ms=json_int(payload, "poll_ms", default=250),
  )
  let runtime_response = moonclaw_post_json(
    daemon,
    @mooncode.moonclaw_native_runtime_loop_endpoint(session_id, workspace_root),
    loop_body,
  )
  let response = match runtime_response {
    Ok(response) => response
    Err(error) => {
      send_api_error(conn, method_, 502, "Bad Gateway", error)
      return
    }
  }
  let updated_at = @async.now().to_string()
  let session_patch = @mooncode.moonclaw_runtime_supervisor_run_session_patch(
    response, updated_at,
  )
  let status_message = json_object_field_or_empty(
    session_patch, "status_message",
  )
  let with_response = append_mooncode_transcript_message(
    @mooncode.append_projected_native_response_events(
      session,
      response,
      loop_fallback_created_at=updated_at,
    ),
    role="status",
    content=json_string(status_message, "content", default=""),
    status=json_string(status_message, "status", default="failed"),
    created_at=json_string(status_message, "created_at", default=updated_at),
  )
  let with_updated = @mooncode.apply_moonclaw_runtime_session_patch(
    with_response, session_patch,
  )
  let refreshed = refresh_mooncode_runtime_review_artifacts(
    workspace_root, with_updated,
  )
  write_mooncode_session_record(workspace_root, refreshed) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session after native runtime loop",
      )
      return
    }
  }
  append_new_mooncode_command_events(workspace_root, session, refreshed) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode event log after native runtime loop",
      )
      return
    }
  }
  send_json(
    conn,
    method_,
    enrich_mooncode_session_for_response(workspace_root, refreshed),
  )
}

///|
fn mooncode_runtime_receipt_delivered_for_command(
  receipts : Array[Json],
  command_id : String,
) -> Bool {
  for receipt in receipts {
    if json_string(receipt, "command_id", default="") == command_id &&
      @mooncode.runtime_receipt_status_delivered(
        json_string(receipt, "status", default=""),
      ) {
      return true
    }
  }
  false
}

///|
fn mooncode_native_runtime_accepted_session(
  session : Json,
  session_id : String,
) -> Json {
  {
    "id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "mooncode_runtime_session_id": json_string(
      session,
      "mooncode_runtime_session_id",
      default=session_id,
    ),
    "mooncode_runtime_mode": "moonclaw-mooncode-runtime",
  }
}

///|
async fn replay_recorded_mooncode_commands_to_native_runtime(
  workspace_root : String,
  session_id : String,
  session : Json,
  daemon : Json,
) -> Result[Int, String] {
  let commands = read_mooncode_runtime_command_log(workspace_root, session_id)
  let receipts = read_mooncode_runtime_receipt_log(workspace_root, session_id)
  let accepted_session = mooncode_native_runtime_accepted_session(
    session, session_id,
  )
  let mut replayed_count = 0
  for command in commands {
    let command_id = json_string(command, "command_id", default="")
    if command_id != "" &&
      !mooncode_runtime_receipt_delivered_for_command(receipts, command_id) {
      let native_body = json_object_field_or_empty(
        command, "native_mooncode_body",
      )
      if native_body.stringify() == "{}" {
        continue
      }
      let response = match
        moonclaw_post_json(
          daemon,
          @mooncode.moonclaw_native_command_endpoint(session_id),
          native_body,
        ) {
        Ok(response) => response
        Err(error) => return Err(error)
      }
      if !json_bool(response, "accepted", default=true) {
        return Err(
          json_string(
            response,
            "message",
            default="MoonClaw rejected replayed MoonCode command",
          ),
        )
      }
      append_mooncode_runtime_receipt_log(
        workspace_root,
        session_id,
        @mooncode.projected_runtime_receipt(
          accepted_session,
          command,
          @async.now().to_string(),
        ),
      ) catch {
        error => return Err(error.to_string())
      }
      replayed_count += 1
    }
  }
  Ok(replayed_count)
}

///|
fn mooncode_runtime_service_error(
  code : Int,
  reason : String,
  message : String,
) -> Json {
  { "code": code, "reason": reason, "message": message }
}

///|
fn mooncode_runtime_service_lease_path(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    mooncode_session_log_dir(workspace_root, session_id),
    "runtime-service.lease.json",
  )
}

///|
async fn mooncode_runtime_service_lease_active(
  workspace_root : String,
  session_id : String,
  command_count : Int,
  now_ms : Int,
) -> Bool {
  let lease = read_json_file_or_object(
    mooncode_runtime_service_lease_path(workspace_root, session_id),
  )
  if json_string(lease, "kind", default="") != "mooncode-runtime-service-lease" {
    return false
  }
  if json_int(lease, "command_count", default=-1) != command_count {
    return false
  }
  let started_at_ms = json_int(lease, "started_at_ms", default=0)
  started_at_ms > 0 && now_ms - started_at_ms < 15000
}

///|
async fn try_acquire_mooncode_runtime_service_lease(
  workspace_root : String,
  session_id : String,
) -> Bool {
  if !mooncode_valid_session_id(session_id) {
    return false
  }
  let command_count = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  ).length()
  let now_ms = @async.now().to_int()
  let lease_path = mooncode_runtime_service_lease_path(
    workspace_root, session_id,
  )
  if mooncode_runtime_service_lease_active(
      workspace_root, session_id, command_count, now_ms,
    ) {
    return false
  }
  @fs.remove(lease_path) catch {
    _ => ()
  }
  @fsx.make_directory(
    mooncode_session_log_dir(workspace_root, session_id),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => return false
  }
  let lease : Json = {
    "kind": "mooncode-runtime-service-lease",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "command_count": command_count,
    "started_at_ms": now_ms,
  }
  @fs.write_file(
    lease_path,
    lease.stringify(indent=2) + "\n",
    create_mode=CreateNew,
    permission=0o644,
  ) catch {
    _ => return false
  }
  true
}

///|
async fn wait_for_mooncode_native_runtime_ready(daemon : Json) -> Bool {
  if mooncode_native_runtime_ready(daemon) {
    return true
  }
  let mut checks = 0
  while checks < 12 {
    @async.sleep(250)
    if mooncode_native_runtime_ready(daemon) {
      return true
    }
    checks += 1
  }
  false
}

///|
async fn run_mooncode_runtime_service_for_session(
  workspace_root : String,
  session_id : String,
  session : Json,
  payload : Json,
) -> Result[Json, Json] {
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="runtime-service",
  )
  if !json_bool(daemon, "running", default=false) {
    return Err(
      mooncode_runtime_service_error(
        409, "Conflict", "MoonClaw daemon is not running",
      ),
    )
  }
  if !wait_for_mooncode_native_runtime_ready(daemon) {
    return Err(
      mooncode_runtime_service_error(
        409, "Conflict", "MoonClaw native MoonCode runtime is not available",
      ),
    )
  }
  match
    replay_recorded_mooncode_commands_to_native_runtime(
      workspace_root, session_id, session, daemon,
    ) {
    Ok(_) => ()
    Err(error) =>
      return Err(mooncode_runtime_service_error(502, "Bad Gateway", error))
  }
  let service_body = @mooncode.moonclaw_runtime_loop_request(
    session_id,
    workspace_root,
    consumer_id=json_string(
      payload,
      "consumer_id",
      default="moondesk-backend-runtime-service",
    ),
    max_turns=json_int(payload, "max_turns", default=8),
    live_wait_ms=json_int(payload, "live_wait_ms", default=5000),
    poll_ms=json_int(payload, "poll_ms", default=250),
  )
  let response = match
    moonclaw_post_json(
      daemon,
      @mooncode.moonclaw_native_runtime_service_endpoint(
        session_id, workspace_root,
      ),
      service_body,
    ) {
    Ok(response) => response
    Err(error) =>
      return Err(mooncode_runtime_service_error(502, "Bad Gateway", error))
  }
  let updated_at = @async.now().to_string()
  let session_patch = @mooncode.moonclaw_runtime_supervisor_run_session_patch(
    response, updated_at,
  )
  let status_message = json_object_field_or_empty(
    session_patch, "status_message",
  )
  let with_response = append_mooncode_transcript_message(
    @mooncode.append_projected_native_response_events(
      session,
      response,
      loop_fallback_created_at=updated_at,
    ),
    role="status",
    content=json_string(status_message, "content", default=""),
    status=json_string(status_message, "status", default="running"),
    created_at=json_string(status_message, "created_at", default=updated_at),
  )
  let with_updated = @mooncode.apply_moonclaw_runtime_session_patch(
    with_response, session_patch,
  )
  write_mooncode_session_record(workspace_root, with_updated) catch {
    _ =>
      return Err(
        mooncode_runtime_service_error(
          500, "Internal Server Error", "Could not save MoonCode session after native runtime service start",
        ),
      )
  }
  append_new_mooncode_command_events(workspace_root, session, with_updated) catch {
    _ =>
      return Err(
        mooncode_runtime_service_error(
          500, "Internal Server Error", "Could not append MoonCode event log after native runtime service start",
        ),
      )
  }
  Ok(enrich_mooncode_session_for_response(workspace_root, with_updated))
}

///|
async fn handle_mooncode_session_runtime_service_run(
  workspace_root : String,
  session_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = read_json_body(body).unwrap_or(Json::object({}))
  let session = match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  if !try_acquire_mooncode_runtime_service_lease(workspace_root, session_id) {
    send_json(
      conn,
      method_,
      enrich_mooncode_session_for_response(workspace_root, session),
    )
    return
  }
  match
    run_mooncode_runtime_service_for_session(
      workspace_root, session_id, session, payload,
    ) {
    Ok(started) => send_json(conn, method_, started)
    Err(error) =>
      send_api_error(
        conn,
        method_,
        json_int(error, "code", default=500),
        json_string(error, "reason", default="Internal Server Error"),
        json_string(
          error,
          "message",
          default="Could not start MoonCode runtime service",
        ),
      )
  }
}
