///|
fn evidence_match_required_event(
  required : String,
  command_id : String,
  action : String,
  events : Array[Json],
) -> Json {
  let mut failed_event = Json::object({})
  for event in events {
    if !evidence_event_matches_command(event, command_id, action) {
      continue
    }
    if evidence_event_fails_required(required, event) {
      if json_string(failed_event, "id", default="") == "" {
        failed_event = event
      }
      continue
    }
    if !evidence_event_satisfies(required, event) {
      continue
    }
    if json_string(event, "status", default="") == "failed" {
      if json_string(failed_event, "id", default="") == "" {
        failed_event = event
      }
      continue
    }
    return evidence_required_event_result(required, "proven", event)
  }
  if json_string(failed_event, "id", default="") != "" {
    evidence_required_event_result(required, "failed", failed_event)
  } else {
    evidence_required_event_result(required, "missing", Json::object({}))
  }
}

///|
fn evidence_required_event_result(
  required : String,
  status : String,
  event : Json,
) -> Json {
  {
    "required_event": required,
    "status": status,
    "event_id": json_string(event, "id", default=""),
    "event_kind": json_string(event, "kind", default=""),
    "event_status": json_string(event, "status", default=""),
    "event_title": json_string(event, "title", default=""),
    "event_path": json_string(event, "path", default=""),
    "event_detail": json_string(event, "detail", default=""),
    "tool_call_id": json_string(event, "tool_call_id", default=""),
  }
}

///|
fn evidence_event_matches_command(
  event : Json,
  command_id : String,
  action : String,
) -> Bool {
  if command_id == "" {
    return false
  }
  let packet = evidence_json_object_field_or_empty(event, "command_packet")
  json_string(packet, "command_id", default="") == command_id &&
  evidence_event_action(event) == action
}

///|
fn evidence_event_action(event : Json) -> String {
  let packet = evidence_json_object_field_or_empty(event, "command_packet")
  let packet_action = json_string(packet, "action", default="")
  if packet_action != "" {
    return packet_action
  }
  json_string(event, "command", default="")
}

///|
fn evidence_event_satisfies(required : String, event : Json) -> Bool {
  let kind = json_string(event, "kind", default="")
  match required {
    "tool_call" =>
      json_string(event, "tool_call_id", default="") != "" &&
      json_string(event, "status", default="") == "running"
    "tool_result" =>
      json_string(event, "tool_call_id", default="") != "" &&
      kind != "tool_call_decode_error" &&
      json_string(event, "status", default="") != "running"
    "agent_finished" => kind == "finish"
    "review.receipt" => kind.has_prefix("receipt.")
    "package_verified" => kind == "runtime.package_verified"
    "package_built" => kind == "runtime.package_built"
    "commit_created" => kind == "runtime.commit_created"
    "patch_applied" => kind == "runtime.patch_applied"
    "patch_reverted" => kind == "runtime.patch_reverted"
    "native eval report" => kind == "eval_report.manifest"
    _ => kind == required
  }
}

///|
fn evidence_event_fails_required(required : String, event : Json) -> Bool {
  if json_string(event, "status", default="") != "failed" {
    return false
  }
  let kind = json_string(event, "kind", default="")
  let source_event = json_string(event, "source_event", default="")
  match required {
    "tool_call" =>
      kind == "tool_call_decode_error" &&
      source_event != "tool_result" &&
      json_string(event, "tool_call_id", default="") != ""
    "tool_result" =>
      kind == "tool_call_decode_error" &&
      source_event == "tool_result" &&
      json_string(event, "tool_call_id", default="") != ""
    _ => evidence_event_satisfies(required, event)
  }
}

///|
fn evidence_events_with_status(
  event_results : Array[Json],
  status : String,
) -> Array[String] {
  let result : Array[String] = []
  for item in event_results {
    if json_string(item, "status", default="") == status {
      result.push(json_string(item, "required_event", default=""))
    }
  }
  result
}
