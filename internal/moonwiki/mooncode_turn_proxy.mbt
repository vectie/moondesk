///|
fn mooncode_turn_proxy_error(
  code : Int,
  reason : String,
  message : String,
) -> Json {
  { "code": code, "reason": reason, "message": message }
}

///|
async fn mooncode_turn_runtime_ready(daemon : Json) -> Bool {
  match moonclaw_get_json(daemon, "/v1/code/capabilities") {
    Ok(capabilities) =>
      @mooncode.moonclaw_native_capabilities_ready(capabilities)
    Err(_) => false
  }
}

///|
async fn wait_for_mooncode_turn_runtime(daemon : Json) -> Bool {
  if mooncode_turn_runtime_ready(daemon) {
    return true
  }
  for _ in 0..<12 {
    @async.sleep(250)
    if mooncode_turn_runtime_ready(daemon) {
      return true
    }
  }
  false
}

///|
fn mooncode_canonical_session_status(conversation : Json) -> String {
  let turns = json_array_items(conversation, "turns")
  match turns.last() {
    Some(turn) => json_string(turn, "status", default="queued")
    None => "queued"
  }
}

///|
fn mooncode_session_from_native_record(
  base : Json,
  record : Json,
  updated_at : String,
) -> Json {
  let conversation = moonclaw_runtime_record_conversation(record)
  let session_id = json_string(base, "id", default="")
  let with_source = mooncode_session_with_field(
    base,
    "source",
    "moonclaw-canonical-session".to_json(),
  )
  let with_updated = mooncode_session_with_field(
    with_source,
    "updated_at",
    updated_at.to_json(),
  )
  if !moonclaw_runtime_record_conversation_belongs_to_session(
      conversation, session_id,
    ) {
    return with_updated
  }
  with_updated
  |> mooncode_session_with_field(
    "status",
    mooncode_canonical_session_status(conversation).to_json(),
  )
  |> mooncode_session_with_field("mooncode_conversation", conversation)
}

///|
async fn submit_mooncode_turn(
  workspace_root : String,
  session : Json,
  payload : Json,
  action : String,
  message : String,
  created_at : String,
  context_path : String,
) -> Result[Json, Json] {
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="submit-turn",
  )
  if !json_bool(daemon, "running", default=false) {
    return Err(
      mooncode_turn_proxy_error(
        409, "Conflict", "MoonClaw daemon is not running",
      ),
    )
  }
  if !wait_for_mooncode_turn_runtime(daemon) {
    return Err(
      mooncode_turn_proxy_error(
        409, "Conflict", "MoonClaw native MoonCode runtime is not available",
      ),
    )
  }
  let command_packet = @mooncode.projected_command_packet(
    session, payload, action, message, created_at, context_path,
  )
  let native_body = @mooncode.native_command_body(
    session, payload, message, command_packet,
  )
  let session_id = json_string(session, "id", default="")
  let response = match
    moonclaw_post_json(
      daemon,
      @mooncode.moonclaw_native_turn_endpoint(session_id),
      native_body,
    ) {
    Ok(response) => response
    Err(error) =>
      return Err(mooncode_turn_proxy_error(502, "Bad Gateway", error))
  }
  if !json_bool(response, "accepted", default=false) {
    return Err(
      mooncode_turn_proxy_error(
        502, "Bad Gateway", "MoonClaw did not accept the MoonCode turn",
      ),
    )
  }
  let record = json_object_field_or_empty(response, "session")
  if json_string(record, "session_id", default="") != session_id {
    return Err(
      mooncode_turn_proxy_error(
        502, "Bad Gateway", "MoonClaw returned an invalid canonical session for the accepted turn",
      ),
    )
  }
  let canonical = mooncode_session_from_native_record(
    session, record, created_at,
  )
  Ok(
    compact_mooncode_session_command_response(
      workspace_root, canonical, command_packet,
    ),
  )
}
