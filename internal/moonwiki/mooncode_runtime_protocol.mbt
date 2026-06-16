///|
fn mooncode_command_action(payload : Json) -> String {
  @mooncode.command_action(payload)
}

///|
fn mooncode_command_is_supported(action : String) -> Bool {
  @mooncode.command_is_supported(action)
}

///|
fn mooncode_preflight_payload_from_request(request_path : String) -> Json {
  let action = match query_value(request_path, "action") {
    Some(value) => decode_query_value(value).trim().to_owned()
    None => "package"
  }
  let context_path = match query_value(request_path, "context_path") {
    Some(value) => decode_query_value(value).trim().to_owned()
    None =>
      match query_value(request_path, "path") {
        Some(value) => decode_query_value(value).trim().to_owned()
        None => ""
      }
  }
  { "action": action, "context_path": context_path }
}

///|
fn mooncode_command_preflight(
  session : Json,
  payload : Json,
  action : String,
) -> Json {
  let events = project_mooncode_events(session, [], [])
  let summary = @mooncode.session_summary(session, events)
  @mooncode.command_preflight(
    session_id=json_string(session, "id", default=""),
    action~,
    context_path=mooncode_command_context_path(payload),
    summary~,
    patch_entries=mooncode_patch_set_entries(events),
  )
}

///|
fn mooncode_command_preflight_blocked_event(
  preflight : Json,
  payload : Json,
  action : String,
  created_at : String,
) -> Json {
  let reason = json_string(
    preflight,
    "reason",
    default="MoonCode command is blocked by current review gates",
  )
  let target = mooncode_command_context_path(payload)
  @mooncode.command_preflight_blocked_event(
    preflight,
    action~,
    context_path=target,
    created_at~,
    event_id=@desk.stable_id(
      "mooncode-preflight-blocked",
      action + ":" + target + ":" + created_at + ":" + reason,
    ),
  )
}

///|
fn mooncode_command_preflight_override_event(
  preflight : Json,
  payload : Json,
  action : String,
  created_at : String,
) -> Json {
  let reason = json_string(
    preflight,
    "reason",
    default="MoonCode command preflight was overridden by the operator",
  )
  let target = mooncode_command_context_path(payload)
  @mooncode.command_preflight_override_event(
    preflight,
    action~,
    context_path=target,
    created_at~,
    event_id=@desk.stable_id(
      "mooncode-preflight-override",
      action + ":" + target + ":" + created_at + ":" + reason,
    ),
  )
}

///|
fn mooncode_command_preflight_has_patch_target(
  events : Array[Json],
  target : String,
) -> Bool {
  @mooncode.command_preflight_has_patch_target(
    mooncode_patch_set_entries(events),
    target,
  )
}

///|
fn mooncode_command_message(action : String, payload : Json) -> String {
  @mooncode.command_message(action, payload)
}

///|
fn mooncode_command_context_path(payload : Json) -> String {
  @mooncode.command_context_path(payload)
}

///|
fn mooncode_command_packet(
  session : Json,
  payload : Json,
  action : String,
  message : String,
  created_at : String,
  context_path : String,
) -> Json {
  let command_id = @desk.stable_id(
    "mooncode-command",
    action + ":" + created_at + ":" + context_path + ":" + message,
  )
  @mooncode.command_packet(
    session,
    payload,
    action,
    message,
    created_at,
    context_path,
    command_id~,
  )
}

///|
fn mooncode_runtime_command_record(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  @mooncode.runtime_command_record(session, payload, message, command_packet)
}

///|
fn mooncode_runtime_dispatch_receipt(
  session : Json,
  runtime_command : Json,
) -> Json {
  let command_id = json_string(runtime_command, "command_id", default="")
  let status = @mooncode.runtime_dispatch_status(session, runtime_command)
  let now = @async.now().to_string()
  @mooncode.runtime_dispatch_receipt(
    session,
    runtime_command,
    dispatch_id=@desk.stable_id(
      "mooncode-runtime-dispatch",
      command_id + ":" + status + ":" + now,
    ),
    created_at=now,
  )
}

///|
fn mooncode_runtime_dispatch_pending_count(
  commands : Array[Json],
  receipts : Array[Json],
) -> Int {
  @mooncode.runtime_dispatch_pending_count(
    commands,
    receipts,
    lease_now=@async.now().to_string(),
  )
}

///|
fn mooncode_runtime_pending_command_ids(
  commands : Array[Json],
  receipts : Array[Json],
) -> Array[Json] {
  @mooncode.runtime_pending_command_ids(
    commands,
    receipts,
    lease_now=@async.now().to_string(),
  )
}

///|
fn mooncode_runtime_replay_state(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  lease_now? : String = "",
) -> Json {
  @mooncode.runtime_replay_state(
    session_id,
    commands,
    receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now=if lease_now == "" { @async.now().to_string() } else { lease_now },
  )
}

///|
fn mooncode_runtime_serve_jsonl(
  commands : Array[Json],
  receipts : Array[Json],
  scope~ : String,
  lease_now? : String = "",
) -> String {
  @mooncode.runtime_serve_jsonl(commands, receipts, scope~, lease_now~)
}

///|
fn mooncode_serve_scheduler_projection(
  session_id : String,
  command_log : Array[Json],
  lifecycle : Json,
) -> Json {
  @mooncode.serve_scheduler_projection(session_id, command_log, lifecycle)
}

///|
fn mooncode_serve_scheduler_response(
  session_id : String,
  command_log : Array[Json],
  runtime_commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  lease_now? : String = "",
) -> Json {
  @mooncode.serve_scheduler_response(
    session_id,
    command_log,
    runtime_commands,
    receipts,
    events,
    lease_now=if lease_now == "" { @async.now().to_string() } else { lease_now },
  )
}

///|
fn mooncode_runtime_claim_state(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  lease_now? : String = "",
) -> Json {
  @mooncode.runtime_claim_state(
    session_id,
    commands,
    receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now=if lease_now == "" { @async.now().to_string() } else { lease_now },
  )
}

///|
fn mooncode_runtime_execution_plan(
  workspace_root : String,
  session : Json,
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  moonclaw_root~ : String,
  native_ready? : Bool = false,
  lease_now? : String = "",
) -> Json {
  let now = if lease_now == "" { @async.now().to_string() } else { lease_now }
  @mooncode.runtime_execution_plan_response(
    session_id,
    commands,
    receipts,
    events,
    workspace_id=json_string(session, "workspace_id", default=""),
    workspace_name=json_string(session, "workspace_name", default=""),
    task_id=json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    workspace_root~,
    moonclaw_root~,
    host_base_url="",
    native_ready~,
    lease_now=now,
  )
}

///|
fn mooncode_runtime_supervisor_launch_packet(
  workspace_root : String,
  session : Json,
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  daemon : Json,
  native_ready? : Bool = false,
  lease_now? : String = "",
) -> Json {
  let now = if lease_now == "" { @async.now().to_string() } else { lease_now }
  @mooncode.runtime_supervisor_response(
    session_id,
    commands,
    receipts,
    events,
    workspace_id=json_string(session, "workspace_id", default=""),
    workspace_name=json_string(session, "workspace_name", default=""),
    task_id=json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    workspace_root~,
    moonclaw_root=json_string(daemon, "moonclaw_root", default=""),
    host_base_url="",
    native_ready~,
    lease_now=now,
  )
}

///|
fn mooncode_runtime_replay_ack_receipts(
  session : Json,
  commands : Array[Json],
  payload : Json,
  dispatch_receipts? : Array[Json] = [],
  prior_events? : Array[Json] = [],
) -> Array[Json] {
  @mooncode.runtime_replay_ack_receipts(
    session,
    commands,
    mooncode_json_with_missing_string(
      payload,
      "acknowledged_at",
      @async.now().to_string(),
    ),
    dispatch_receipts~,
    prior_events~,
  )
}

///|
fn mooncode_runtime_replay_ack_normalized_events(
  receipts : Array[Json],
) -> Array[Json] {
  @mooncode.runtime_replay_ack_normalized_events(receipts)
}

///|
fn mooncode_runtime_claim_receipts(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  payload : Json,
) -> Array[Json] {
  let now = @async.now().to_string()
  @mooncode.runtime_claim_receipts(
    session,
    commands,
    receipts,
    mooncode_json_with_missing_string(
      mooncode_json_with_missing_string(payload, "now", now),
      "claimed_at",
      now,
    ),
  )
}

///|
fn mooncode_runtime_dispatch_receipts_for_response(
  receipts : Array[Json],
) -> Array[Json] {
  @mooncode.runtime_dispatch_receipts_for_response(receipts)
}

///|
fn mooncode_json_with_missing_string(
  object : Json,
  field : String,
  value : String,
) -> Json {
  match json_object_field(object, field) {
    Some(_) => object
    None => agent_session_with_field(object, field, value.to_json())
  }
}

///|
fn mooncode_runtime_ingest_report(session_id : String, payload : Json) -> Json {
  let ingested_at = @async.now().to_string()
  let report = @mooncode.runtime_event_ingest_report(
    payload,
    session_id~,
    ingested_at~,
  )
  if json_int(report, "accepted_count", default=0) > 0 {
    return report
  }
  let legacy_events = mooncode_legacy_moonclaw_ingest_events(payload)
  if legacy_events.length() == 0 {
    return report
  }
  agent_session_with_field(
    agent_session_with_field(
      agent_session_with_field(
        agent_session_with_field(
          report,
          "status",
          "accepted-legacy-moonclaw".to_json(),
        ),
        "accepted_count",
        legacy_events.length().to_json(),
      ),
      "events",
      Json::array(legacy_events),
    ),
    "legacy_adapter",
    "moondesk.moonclaw.desc".to_json(),
  )
}

///|
fn mooncode_legacy_moonclaw_ingest_events(payload : Json) -> Array[Json] {
  let candidates = json_array_items(payload, "events")
  let incoming = if candidates.length() > 0 { candidates } else { [payload] }
  let events : Array[Json] = []
  for candidate in incoming {
    match mooncode_event_from_moonclaw_event(candidate) {
      Some(event) => events.push(event)
      None => ()
    }
  }
  events
}

///|
fn mooncode_command_runtime_message(
  message : String,
  command_packet : Json,
) -> String {
  @mooncode.command_runtime_message(message, command_packet)
}
