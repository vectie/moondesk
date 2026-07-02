///|
async fn send_mooncode_command_to_runtime(
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
  Err(
    "MoonCode requires the native MoonClaw MoonCode runtime. Start or update MoonClaw until /v1/code/capabilities reports ready.",
  )
}

///|
fn mooncode_runtime_waiting_detail(detail : String) -> String {
  let trimmed = detail.trim().to_owned()
  if trimmed == "" {
    "Local MoonClaw is not reachable yet. Your request is saved for the local agent."
  } else if trimmed.contains("MoonClaw") || trimmed.contains("daemon") {
    "Local agent is not reachable yet. Your request is saved and will continue when MoonClaw is available."
  } else {
    trimmed
  }
}

///|
fn mooncode_runtime_waiting_session(
  session : Json,
  action : String,
  detail : String,
  path : String,
  command_packet : Json,
) -> Json {
  let message = mooncode_runtime_waiting_detail(detail)
  if mooncode_session_has_command_event(session, command_packet) {
    return append_mooncode_transcript_message(
      session,
      role="status",
      content=message,
      status="queued",
    )
  }
  append_mooncode_transcript_message(
    @mooncode.append_projected_command_event(
      session,
      action~,
      status="queued",
      detail=message,
      created_at=@async.now().to_string(),
      path~,
      command_packet~,
    ),
    role="status",
    content=message,
    status="queued",
  )
}

///|
fn mooncode_session_has_command_event(
  session : Json,
  command_packet : Json,
) -> Bool {
  let command_id = json_string(command_packet, "command_id", default="")
  if command_id == "" {
    return false
  }
  for event in json_array_items(session, "mooncode_command_events") {
    if json_string(event, "id", default="") == command_id {
      return true
    }
  }
  false
}

///|
async fn mooncode_native_runtime_ready(daemon : Json) -> Bool {
  match moonclaw_get_json(daemon, "/v1/code/capabilities") {
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
    return Err("MoonCode native runtime receipt needs a session id")
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
    moonclaw_post_json(
      daemon,
      @mooncode.moonclaw_native_runtime_loop_endpoint(session_id, book_root),
      @mooncode.moonclaw_runtime_loop_request(
        session_id,
        book_root,
        consumer_id="moondesk-native-runtime-loop",
        max_turns=8,
        live_wait_ms=750,
        poll_ms=100,
      ),
    )
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
  let receipt_result = @mooncode.moonclaw_native_runtime_receipt_result(
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
    receipt_result, command_packet, message, updated_at,
  )
  let status_message = json_object_field_or_empty(
    session_patch, "status_message",
  )
  let queue_observed_at = @async.now().to_string()
  let runtime_observed_at = @async.now().to_string()
  let with_status = append_mooncode_transcript_message(
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
  append_mooncode_transcript_message(
    @mooncode.append_projected_command_event(
      session,
      action~,
      status="failed",
      detail="MoonCode cancel requires the native MoonClaw MoonCode runtime.",
      created_at=@async.now().to_string(),
    ),
    role="status",
    content="MoonCode cancel requires the native MoonClaw MoonCode runtime.",
    status="failed",
  )
}
