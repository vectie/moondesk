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
  let with_response = @mooncode.append_projected_native_response_events(
    session,
    response,
    loop_fallback_created_at=updated_at,
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
  let with_response = @mooncode.append_projected_native_response_events(
    session,
    response,
    loop_fallback_created_at=updated_at,
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
async fn record_mooncode_runtime_service_failure(
  workspace_root : String,
  session_id : String,
  session : Json,
  error : Json,
) -> Json {
  let commands = read_mooncode_command_log(workspace_root, session_id)
  let runtime_commands = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  )
  let receipts = read_mooncode_runtime_receipt_log(workspace_root, session_id)
  let events = read_mooncode_event_log(workspace_root, session_id)
  let control = @mooncode.runtime_control_response(
    session_id,
    commands,
    runtime_commands,
    receipts,
    events,
    lease_now=@async.now().to_string(),
  )
  let command_packet = mooncode_runtime_service_failure_target_command(
    session, commands, control,
  )
  let command_id = json_string(command_packet, "command_id", default="")
  if command_id == "" {
    return enrich_mooncode_session_for_response(workspace_root, session)
  }
  let message = json_string(
    error,
    "message",
    default="Could not start MoonCode runtime service",
  )
  let created_at = @async.now().to_string()
  let with_failed = mooncode_session_with_field(
    mooncode_session_with_field(
      mooncode_session_with_field(session, "status", "failed".to_json()),
      "mooncode_runtime_detail",
      message.to_json(),
    ),
    "updated_at",
    created_at.to_json(),
  )
  if !mooncode_runtime_service_failure_event_exists(events, command_id) {
    let event = @mooncode.event_record(
      id=@desk.stable_id(
        "mooncode-runtime-service-unavailable",
        session_id + ":" + command_id,
      ),
      lane="runtime",
      kind="runtime_unavailable",
      title="MoonCode runtime unavailable",
      status="failed",
      created_at~,
      detail=message,
      command_packet~,
    )
    append_mooncode_event_log(workspace_root, session_id, event)
  }
  write_mooncode_session_record(workspace_root, with_failed)
  ignore(release_mooncode_runtime_service_lease(workspace_root, session_id))
  enrich_mooncode_session_for_response(workspace_root, with_failed)
}

///|
fn mooncode_runtime_service_failure_event_exists(
  events : Array[Json],
  command_id : String,
) -> Bool {
  for event in events {
    let command_packet = json_object_field_or_empty(event, "command_packet")
    if json_string(event, "kind", default="") == "runtime_unavailable" &&
      json_string(command_packet, "command_id", default="") == command_id {
      return true
    }
  }
  false
}

///|
fn mooncode_runtime_service_failure_target_command(
  session : Json,
  commands : Array[Json],
  control : Json,
) -> Json {
  let target_id = mooncode_runtime_service_failure_target_command_id(control)
  if target_id != "" {
    for command in commands {
      if json_string(command, "command_id", default="") == target_id {
        return command
      }
    }
  }
  let mut fallback = json_object_field_or_empty(
    session, "mooncode_last_command_packet",
  )
  for command in commands {
    if mooncode_runtime_service_turn_starting_action(
        json_string(command, "action", default="prompt"),
      ) {
      fallback = command
    }
  }
  fallback
}

///|
fn mooncode_runtime_service_failure_target_command_id(control : Json) -> String {
  for decision in json_array_items(control, "decisions") {
    let effect = json_string(decision, "effect", default="")
    if effect == "active-turn" || effect == "start-turn" {
      return json_string(decision, "command_id", default="")
    }
  }
  ""
}

///|
fn mooncode_runtime_service_turn_starting_action(action : String) -> Bool {
  action != "steer" && action != "cancel" && action != "note"
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
    Err(error) => {
      ignore(
        record_mooncode_runtime_service_failure(
          workspace_root, session_id, session, error,
        ),
      ) catch {
        _ => ()
      }
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
}
