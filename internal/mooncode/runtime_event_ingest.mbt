///|
pub fn runtime_event_fallback_id(event : Json) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(event.stringify()).to_fixedarray()),
  )
  "mooncode-runtime-event-" + digest[:16].to_owned()
}

///|
pub fn normalize_runtime_event_with_defaults(
  event : Json,
  fallback_created_at~ : String,
) -> Json? {
  let with_created_at = if json_string(event, "created_at", default="") == "" &&
    json_string(event, "created", default="") == "" {
    runtime_with_field(event, "created_at", fallback_created_at.to_json())
  } else {
    event
  }
  normalize_runtime_event(
    with_created_at,
    fallback_id=runtime_event_fallback_id(event),
    fallback_created_at~,
  )
}

///|
pub fn normalize_runtime_loop_response_event(
  response : Json,
  fallback_id~ : String,
  fallback_created_at~ : String,
) -> Json? {
  if json_string(response, "kind", default="") != "mooncode-runtime-loop" {
    return None
  }
  let stopped_by = runtime_json_string(
    response,
    "stopped_by",
    default="unknown",
  )
  let status = match stopped_by {
    "failed" => "failed"
    "cancelled" => "cancelled"
    "max_turns" => "running"
    _ => "done"
  }
  Some(
    event_record(
      id=runtime_json_string(response, "id", default=fallback_id),
      lane="runtime",
      kind="runtime_loop",
      title="Native runtime loop: \{stopped_by}",
      status~,
      created_at=runtime_first_string(
        response,
        ["created_at", "created"],
        default=fallback_created_at,
      ),
      detail=runtime_json_string(
        response,
        "message",
        default="MoonClaw native runtime loop stopped by \{stopped_by}",
      ),
      path=runtime_json_string(response, "book_root", default=""),
      command="runtime-loop",
    ),
  )
}

///|
pub fn native_response_event_items(
  response : Json,
  loop_fallback_id~ : String,
  loop_fallback_created_at~ : String,
) -> Array[Json] {
  let incoming = runtime_json_array_items(response, "events")
  let execution = runtime_json_object_field_or_empty(response, "execution")
  for event in runtime_json_array_items(execution, "events") {
    incoming.push(event)
  }
  match
    normalize_runtime_loop_response_event(
      response,
      fallback_id=loop_fallback_id,
      fallback_created_at=loop_fallback_created_at,
    ) {
    Some(event) => incoming.push(event)
    None => ()
  }
  for event in runtime_json_array_items(response, "package_events") {
    incoming.push(event)
  }
  let turn_receipt = runtime_json_object_field_or_empty(
    response, "turn_receipt",
  )
  for event in runtime_json_array_items(turn_receipt, "events") {
    incoming.push(event)
  }
  let mut turn_index = 0
  for turn in runtime_json_array_items(response, "turns") {
    for
      event in native_response_event_items(
        turn,
        loop_fallback_id=loop_fallback_id + "-turn-" + turn_index.to_string(),
        loop_fallback_created_at~,
      ) {
      incoming.push(event)
    }
    turn_index += 1
  }
  incoming
}

///|
pub fn append_native_response_events(
  session : Json,
  response : Json,
  loop_fallback_id~ : String,
  loop_fallback_created_at~ : String,
) -> Json {
  let incoming = native_response_event_items(
    response,
    loop_fallback_id~,
    loop_fallback_created_at~,
  )
  if incoming.length() == 0 {
    return session
  }
  let current = runtime_json_array_items(session, "mooncode_command_events")
  let events = merge_events(current, incoming, [])
  runtime_with_field(session, "mooncode_command_events", Json::array(events))
}

///|
pub fn runtime_event_ingest_report(
  payload : Json,
  session_id~ : String,
  ingested_at~ : String,
) -> Json {
  let candidates = runtime_json_array_items(payload, "events")
  let incoming = if candidates.length() > 0 { candidates } else { [payload] }
  let events : Array[Json] = []
  let rejected : Array[Json] = []
  for candidate in incoming {
    match runtime_ingest_event(candidate, ingested_at) {
      Some(event) => events.push(event)
      None =>
        rejected.push({
          "reason": "unsupported-runtime-event-shape",
          "event": candidate,
        })
    }
  }
  {
    "kind": "mooncode-runtime-event-ingest-report",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "ingested_at": ingested_at,
    "submitted_count": incoming.length(),
    "accepted_count": events.length(),
    "rejected_count": rejected.length(),
    "events": Json::array(events),
    "rejected": Json::array(rejected),
    "command_progress": runtime_event_command_progress(events),
    "status": if events.length() > 0 {
      "accepted"
    } else {
      "empty"
    },
    "owner": { "runtime": "moonclaw", "protocol": "mooncode", "ui": "moondesk" },
  }
}

///|
pub fn runtime_event_sink_response(
  session_id : String,
  events : Array[Json],
  event_log_path~ : String,
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-event-sink",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "task_id": task_id,
    "event_log_path": event_log_path,
    "event_count": events.length(),
    "events": Json::array(events),
    "command_progress": runtime_event_command_progress(events),
    "post_contract": runtime_event_ingest_contract(session_id),
    "runtime_protocol": runtime_protocol_contract_json(),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_event_sink_result_response(
  session_id : String,
  events : Array[Json],
  session : Json,
  event_log_path~ : String,
) -> Json {
  runtime_event_sink_response(
    session_id,
    events,
    event_log_path~,
    workspace_id=runtime_json_string(session, "workspace_id", default=""),
    workspace_name=runtime_json_string(session, "workspace_name", default=""),
    task_id=runtime_json_string(session, "moonclaw_task_id", default=""),
  )
}

///|
pub fn runtime_event_ingest_result_response(
  session_id : String,
  accepted_events : Array[Json],
  all_events : Array[Json],
  ingest_report : Json,
  final_session : Json,
  session_response : Json,
  event_log_path~ : String,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-event-ingest-result",
    "session_id": session_id,
    "accepted_event_count": accepted_events.length(),
    "ingest_report": ingest_report,
    "event_log_path": event_log_path,
    "command_progress": runtime_event_command_progress(all_events),
    "action_plan": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_action_plan_manifest",
    ),
    "change_set": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_change_set_manifest",
    ),
    "patch_set": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_patch_set_manifest",
    ),
    "tool_approvals": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_tool_approvals_manifest",
    ),
    "test_runs": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_test_runs_manifest",
    ),
    "runtime_evidence": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_runtime_evidence_manifest",
    ),
    "eval_report": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_eval_report_manifest",
    ),
    "runtime_handoff": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_runtime_handoff_manifest",
    ),
    "session": session_response,
  }
}

///|
pub fn runtime_ingest_events(
  payload : Json,
  ingested_at~ : String,
) -> Array[Json] {
  json_array_items(
    runtime_event_ingest_report(payload, session_id="", ingested_at~),
    "events",
  )
}

///|
fn runtime_ingest_event(event : Json, ingested_at : String) -> Json? {
  if json_string(event, "lane", default="") != "" &&
    json_string(event, "kind", default="") != "" {
    return Some(
      canonical_event_record(
        event,
        fallback_id=runtime_event_fallback_id(event),
        fallback_created_at=ingested_at,
      ),
    )
  }
  match
    normalize_runtime_event_with_defaults(
      event,
      fallback_created_at=ingested_at,
    ) {
    Some(normalized) => Some(normalized)
    None =>
      match
        moonclaw_event_to_runtime_event(
          event,
          fallback_id=runtime_event_fallback_id(event),
          fallback_created_at=ingested_at,
        ) {
        Some(converted) =>
          normalize_runtime_event_with_defaults(
            converted,
            fallback_created_at=ingested_at,
          )
        None => None
      }
  }
}
