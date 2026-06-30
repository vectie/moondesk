///|
async fn handle_mooncode_session_commands(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_command_log(workspace_root, session_id)
      send_json(
        conn,
        method_,
        @mooncode.command_queue_result_response(
          session_id,
          commands,
          session,
          command_log_path=mooncode_command_log_path(workspace_root, session_id),
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
async fn handle_mooncode_session_preflight(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = mooncode_preflight_payload_from_request(request_path)
  let action = @mooncode.command_action(payload)
  if !@mooncode.command_is_supported(action) {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      "Unsupported MoonCode command: \{action}",
    )
    return
  }
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => {
      let projected = attach_mooncode_session_projection(
        workspace_root, session,
      )
      send_json(
        conn,
        method_,
        mooncode_command_preflight(projected, payload, action),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_command(
  workspace_root : String,
  session_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let session = match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let action = @mooncode.command_action(payload)
  if !@mooncode.command_is_supported(action) {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      "Unsupported MoonCode command: \{action}",
    )
    return
  }
  let projected = attach_mooncode_session_projection(workspace_root, session)
  let preflight = mooncode_command_preflight(projected, payload, action)
  let force_preflight = json_bool(payload, "force_preflight", default=false)
  if json_bool(preflight, "blocked", default=false) && !force_preflight {
    let event = @mooncode.command_preflight_blocked_projected_event(
      preflight,
      action~,
      context_path=@mooncode.command_context_path(payload),
      created_at=@async.now().to_string(),
    )
    append_mooncode_event_log(workspace_root, session_id, event) catch {
      _ => ()
    }
    send_api_json_error(conn, method_, 409, "Conflict", {
      "error": json_string(
        preflight,
        "reason",
        default="MoonCode command is blocked by current review gates",
      ),
      "preflight": preflight,
      "event": event,
    })
    return
  }
  let context_path = @mooncode.command_context_path(payload)
  let message = @mooncode.command_message(action, payload)
  let now = @async.now().to_string()
  if json_bool(preflight, "blocked", default=false) && force_preflight {
    let event = @mooncode.command_preflight_override_projected_event(
      preflight,
      action~,
      context_path=@mooncode.command_context_path(payload),
      created_at=now,
    )
    append_mooncode_event_log(workspace_root, session_id, event) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode preflight override event",
        )
        return
      }
    }
  }
  let command_packet = @mooncode.projected_command_packet(
    session, payload, action, message, now, context_path,
  )
  let runtime_command = @mooncode.runtime_command_record(
    session, payload, message, command_packet,
  )
  append_mooncode_command_log(workspace_root, session_id, command_packet) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode command queue",
      )
      return
    }
  }
  append_mooncode_runtime_command_log(
    workspace_root, session_id, runtime_command,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime command feed",
      )
      return
    }
  }
  let with_command = @mooncode.append_projected_command_event(
    session,
    action~,
    status="queued",
    detail=message,
    created_at=now,
    path=context_path,
    command_packet~,
  )
  let runtime_session = if action == "note" {
    with_command
  } else if action == "cancel" {
    send_mooncode_cancel_command(
      workspace_root, with_command, action, payload, message, command_packet,
    )
  } else {
    match
      send_mooncode_command_to_runtime(
        workspace_root, with_command, payload, message, command_packet,
      ) {
      Ok(session) => session
      Err(error) =>
        mooncode_runtime_waiting_session(
          with_command, action, error, context_path, command_packet,
        )
    }
  }
  append_mooncode_runtime_receipt_log(
    workspace_root,
    session_id,
    @mooncode.projected_runtime_receipt(
      runtime_session,
      runtime_command,
      @async.now().to_string(),
    ),
  ) catch {
    _ => ()
  }
  let receipt_session = write_mooncode_review_receipt_if_needed(
    runtime_session, action, command_packet, context_path, message, now,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not record MoonBook review receipt",
      )
      return
    }
  }
  let next = match receipt_session {
    Some(session) => session
    None => runtime_session
  }
  let with_change_set = write_mooncode_change_set_if_possible(next) catch {
    _ => next
  }
  let with_patch_set = write_mooncode_patch_set_if_possible(with_change_set) catch {
    _ => with_change_set
  }
  let with_tool_approvals = write_mooncode_tool_approvals_if_possible(
    with_patch_set,
  ) catch {
    _ => with_patch_set
  }
  let with_test_runs = write_mooncode_test_runs_if_possible(with_tool_approvals) catch {
    _ => with_tool_approvals
  }
  let with_action_plan = write_mooncode_action_plan_if_possible(
    workspace_root, with_test_runs,
  ) catch {
    _ => with_test_runs
  }
  let with_native_eval = sync_mooncode_native_eval_report(
    workspace_root, with_action_plan,
  ) catch {
    _ => with_action_plan
  }
  let with_runtime_evidence = write_mooncode_runtime_evidence_if_possible(
    workspace_root, with_native_eval,
  ) catch {
    _ => with_native_eval
  }
  let with_eval_report = write_mooncode_eval_report_if_possible(
    with_runtime_evidence,
  ) catch {
    _ => with_runtime_evidence
  }
  let with_session_snapshot = write_mooncode_session_snapshot_if_possible(
    workspace_root, with_eval_report,
  ) catch {
    _ => with_eval_report
  }
  let with_runtime_handoff = write_mooncode_runtime_handoff_if_possible(
    workspace_root, with_session_snapshot,
  ) catch {
    _ => with_session_snapshot
  }
  write_mooncode_session_record(workspace_root, with_runtime_handoff) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session",
      )
      return
    }
  }
  append_new_mooncode_command_events(
    workspace_root, session, with_runtime_handoff,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode event log",
      )
      return
    }
  }
  send_json(
    conn,
    method_,
    mooncode_compact_session_record(
      enrich_mooncode_session_for_response(workspace_root, with_runtime_handoff),
    ),
  )
}

///|
async fn append_new_mooncode_command_events(
  workspace_root : String,
  before : Json,
  after : Json,
) -> Unit {
  let session_id = json_string(after, "id", default="")
  let known : Map[String, Bool] = {}
  for event in read_mooncode_event_log(workspace_root, session_id) {
    let id = json_string(event, "id", default="")
    if id != "" {
      known[id] = true
    }
  }
  for event in json_array_items(before, "mooncode_command_events") {
    let id = json_string(event, "id", default="")
    if id != "" {
      known[id] = true
    }
  }
  for event in json_array_items(after, "mooncode_command_events") {
    let id = json_string(event, "id", default="")
    if id == "" || known.get(id).unwrap_or(false) {
      continue
    }
    append_mooncode_event_log(workspace_root, session_id, event)
    known[id] = true
  }
}
