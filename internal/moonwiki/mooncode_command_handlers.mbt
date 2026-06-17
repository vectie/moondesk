///|
async fn handle_mooncode_session_commands(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
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
  match read_agent_session_record(workspace_root, session_id) {
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
  let session = match read_agent_session_record(workspace_root, session_id) {
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
  let dispatched = if action == "note" {
    with_command
  } else if action == "cancel" {
    send_mooncode_cancel_command(
      workspace_root, with_command, action, payload, message, command_packet,
    )
  } else {
    match
      send_mooncode_command_to_agent(
        workspace_root, with_command, payload, message, command_packet,
      ) {
      Ok(session) => session
      Err(error) =>
        @mooncode.append_projected_command_event(
          with_command,
          action~,
          status="failed",
          detail=error,
          created_at=@async.now().to_string(),
          path=context_path,
          command_packet~,
        )
    }
  }
  append_mooncode_runtime_dispatch_log(
    workspace_root,
    session_id,
    @mooncode.projected_runtime_dispatch_receipt(
      dispatched,
      runtime_command,
      @async.now().to_string(),
    ),
  ) catch {
    _ => ()
  }
  let receipt_session = write_mooncode_review_receipt_if_needed(
    dispatched, action, command_packet, context_path, message, now,
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
    None => dispatched
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
  write_agent_session_record(workspace_root, with_runtime_handoff) catch {
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
    enrich_agent_session_for_response(workspace_root, with_runtime_handoff, []),
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

///|
async fn send_mooncode_command_to_agent(
  workspace_root : String,
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Result[Json, String] {
  let daemon = ensure_moonclaw_daemon(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return Err(
      json_string(daemon, "message", default="MoonClaw daemon is not running"),
    )
  }
  if mooncode_native_runtime_ready(daemon) {
    return send_mooncode_native_runtime_command(
      daemon, session, payload, message, command_packet,
    )
  }
  let task = match ensure_session_task(daemon, session) {
    Ok(task) => task
    Err(error) => return Err(error)
  }
  let task_id = json_string(task, "id", default="")
  let sent_at = @async.now().to_string()
  let with_user = append_agent_message(
    update_agent_session_status(session, task),
    role="user",
    content=message,
    status="sending",
    created_at=sent_at,
  )
  let runtime_message = @mooncode.command_runtime_message(
    message, command_packet,
  )
  let moonclaw_message = agent_session_message(
    payload, session, runtime_message,
  )
  let next = match
    send_moonclaw_message(
      daemon,
      task_id,
      moonclaw_message,
      web_search=json_bool(payload, "web_search", default=false),
    ) {
    Ok(response) =>
      append_agent_message(
        with_user,
        role="status",
        content=agent_send_status(response),
        status=if json_bool(response, "queued", default=false) {
          "queued"
        } else {
          "running"
        },
      )
    Err(error) =>
      append_agent_message(
        with_user,
        role="status",
        content=error,
        status="failed",
      )
  }
  Ok(
    @mooncode.apply_moonclaw_runtime_session_patch(
      next,
      @mooncode.moonclaw_task_bridge_session_patch(
        command_packet,
        message,
        @async.now().to_string(),
      ),
    ),
  )
}

///|
async fn mooncode_native_runtime_ready(daemon : Json) -> Bool {
  match moonclaw_get_json(daemon, "/v1/mooncode/capabilities") {
    Ok(capabilities) =>
      @mooncode.moonclaw_native_capabilities_ready(capabilities)
    Err(_) => false
  }
}

///|
async fn sync_mooncode_native_eval_report(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  if session_id == "" {
    return session
  }
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return session
  }
  if !mooncode_native_runtime_ready(daemon) {
    return session
  }
  let endpoint = @mooncode.moonclaw_native_eval_report_endpoint(
    session_id, workspace_root,
  )
  match moonclaw_get_json(daemon, endpoint) {
    Ok(report) =>
      @mooncode.session_with_native_eval_report(session, report, endpoint)
    Err(_) => session
  }
}

///|
async fn send_mooncode_native_runtime_command(
  daemon : Json,
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Result[Json, String] {
  let session_id = json_string(session, "id", default="")
  if session_id == "" {
    return Err("MoonCode native runtime dispatch needs a session id")
  }
  let body = @mooncode.native_command_body(
    session, payload, message, command_packet,
  )
  let queue_response = match
    moonclaw_post_json(
      daemon,
      @mooncode.moonclaw_native_command_endpoint(session_id),
      body,
    ) {
    Ok(response) => response
    Err(error) => return Err(error)
  }
  let queue_accepted = json_bool(queue_response, "accepted", default=true)
  let book_root = json_string(body, "book_root", default="")
  let runtime_response = if queue_accepted {
    let loop_response = moonclaw_post_json(
      daemon,
      @mooncode.moonclaw_native_runtime_loop_endpoint(session_id, book_root),
      @mooncode.moonclaw_runtime_loop_request(
        session_id,
        book_root,
        consumer_id="moondesk-native-runtime-loop",
        max_turns=8,
      ),
    )
    match loop_response {
      Ok(_) => loop_response
      Err(_) =>
        moonclaw_post_json(
          daemon,
          @mooncode.moonclaw_native_runtime_turn_endpoint(session_id, book_root),
          @mooncode.moonclaw_runtime_turn_request(
            session_id,
            book_root,
            consumer_id="moondesk-native-runtime-turn",
          ),
        )
    }
  } else {
    Err(
      json_string(
        queue_response,
        "message",
        default="MoonClaw rejected native MoonCode queueing",
      ),
    )
  }
  let runtime_payload = match runtime_response {
    Ok(payload) => payload
    Err(_) => Json::object({})
  }
  let dispatch_result = @mooncode.moonclaw_native_runtime_dispatch_result(
    queue_response,
    runtime_payload,
    command_packet,
    queue_accepted~,
    runtime_succeeded=runtime_response is Ok(_),
    runtime_error=match runtime_response {
      Ok(_) => ""
      Err(error) => error
    },
  )
  let updated_at = @async.now().to_string()
  let session_patch = @mooncode.moonclaw_native_runtime_session_patch(
    dispatch_result, command_packet, message, updated_at,
  )
  let status_message = json_object_field_or_empty(
    session_patch, "status_message",
  )
  let queue_observed_at = @async.now().to_string()
  let runtime_observed_at = @async.now().to_string()
  let with_status = append_agent_message(
    @mooncode.append_projected_native_response_events(
      @mooncode.append_projected_native_response_events(
        session,
        queue_response,
        loop_fallback_created_at=queue_observed_at,
      ),
      runtime_payload,
      loop_fallback_created_at=runtime_observed_at,
    ),
    role="status",
    content=json_string(status_message, "content", default=""),
    status=json_string(status_message, "status", default="failed"),
    created_at=json_string(status_message, "created_at", default=updated_at),
  )
  Ok(@mooncode.apply_moonclaw_runtime_session_patch(with_status, session_patch))
}

///|
async fn send_mooncode_cancel_command(
  workspace_root : String,
  session : Json,
  action : String,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return @mooncode.append_projected_command_event(
      session,
      action~,
      status="failed",
      detail="MoonClaw daemon is not running",
      created_at=@async.now().to_string(),
    )
  }
  if mooncode_native_runtime_ready(daemon) {
    return match
      send_mooncode_native_runtime_command(
        daemon, session, payload, message, command_packet,
      ) {
      Ok(next) => next
      Err(error) =>
        @mooncode.append_projected_command_event(
          session,
          action~,
          status="failed",
          detail=error,
          created_at=@async.now().to_string(),
        )
    }
  }
  let task_id = json_string(session, "moonclaw_task_id", default="")
  if task_id == "" {
    return @mooncode.append_projected_command_event(
      session,
      action~,
      status="failed",
      detail="Session has no MoonClaw task",
      created_at=@async.now().to_string(),
    )
  }
  let (status, detail) = match
    moonclaw_post_json(daemon, "/v1/task/\{task_id}/cancel", Json::object({})) {
    Ok(payload) => ("cancelled", "cancelled: \{payload.stringify()}")
    Err(error) => ("failed", error)
  }
  append_agent_message(
    @mooncode.append_projected_command_event(
      session,
      action~,
      status~,
      detail~,
      created_at=@async.now().to_string(),
    ),
    role="status",
    content=detail,
    status~,
  )
}
