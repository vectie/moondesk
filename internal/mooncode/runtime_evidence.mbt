///|
pub fn command_runtime_evidence(
  command : Json,
  runtime_command : Json,
  events : Array[Json],
) -> Json {
  let command_id = json_string(command, "command_id", default="")
  let action = json_string(command, "action", default="prompt")
  let summary = evidence_json_object_field_or_empty(
    runtime_command, "execution_summary",
  )
  let required_events = evidence_required_events(action, summary)
  let event_results : Array[Json] = []
  let mut proven_count = 0
  let mut missing_count = 0
  let mut failed_count = 0
  for required in required_events {
    let proof = evidence_match_required_event(
      required, command_id, action, events,
    )
    event_results.push(proof)
    match json_string(proof, "status", default="missing") {
      "proven" => proven_count += 1
      "failed" => failed_count += 1
      _ => missing_count += 1
    }
  }
  let required_outputs = if json_string(summary, "kind", default="") == "" {
    native_command_required_outputs(action)
  } else {
    evidence_json_string_array_items(summary, "required_outputs")
  }
  let tool_harness = tool_harness_evidence(command, runtime_command, events)
  {
    "kind": "mooncode-command-runtime-evidence",
    "protocol": "mooncode.v1",
    "command_id": command_id,
    "action": action,
    "runtime_command_recorded": json_string(
      runtime_command,
      "command_id",
      default="",
    ) !=
    "",
    "required_event_count": required_events.length(),
    "proven_required_event_count": proven_count,
    "missing_required_event_count": missing_count,
    "failed_required_event_count": failed_count,
    "required_events": string_array_json(required_events),
    "missing_required_events": string_array_json(
      evidence_events_with_status(event_results, "missing"),
    ),
    "failed_required_events": string_array_json(
      evidence_events_with_status(event_results, "failed"),
    ),
    "required_outputs": string_array_json(required_outputs),
    "tool_harness": tool_harness,
    "tool_harness_status": json_string(
      tool_harness,
      "status",
      default="missing-evidence",
    ),
    "tool_harness_proven": json_bool(tool_harness, "proven", default=false),
    "tool_harness_expected_tool_count": runtime_json_int(
      tool_harness,
      "expected_tool_count",
      default=0,
    ),
    "tool_harness_proven_tool_count": runtime_json_int(
      tool_harness,
      "proven_tool_count",
      default=0,
    ),
    "tool_harness_failed_tool_count": runtime_json_int(
      tool_harness,
      "failed_tool_count",
      default=0,
    ),
    "tool_harness_missing_tool_count": runtime_json_int(
      tool_harness,
      "missing_tool_count",
      default=0,
    ),
    "events": Json::array(event_results),
    "proven": required_events.length() > 0 &&
    missing_count == 0 &&
    failed_count == 0,
    "status": if required_events.length() == 0 {
      "no-required-events"
    } else if failed_count > 0 {
      "failed"
    } else if missing_count > 0 {
      "missing-evidence"
    } else {
      "proven"
    },
    "rule": "Required runtime events are proven only by command-scoped MoonCode events. Unscoped legacy events may still render in the transcript, but they do not satisfy this command-level proof.",
  }
}

///|
pub fn session_runtime_evidence(
  session : Json,
  commands : Array[Json],
  runtime_commands : Array[Json],
  proof_events : Array[Json],
  recorded_at~ : String,
) -> Json {
  let items : Array[Json] = []
  let mut index = 0
  let mut proven_count = 0
  let mut missing_count = 0
  let mut failed_count = 0
  let mut missing_runtime_command_count = 0
  let mut required_event_count = 0
  let mut proven_required_event_count = 0
  let mut failed_required_event_count = 0
  let mut missing_required_event_count = 0
  let mut tool_harness_expected_tool_count = 0
  let mut tool_harness_proven_tool_count = 0
  let mut tool_harness_failed_tool_count = 0
  let mut tool_harness_missing_tool_count = 0
  for command in commands {
    let runtime_command = evidence_runtime_command_for_id(
      json_string(command, "command_id", default=""),
      runtime_commands,
    )
    let evidence = command_runtime_evidence(
      command, runtime_command, proof_events,
    )
    let status = json_string(evidence, "status", default="missing-evidence")
    if status == "proven" {
      proven_count += 1
    } else if status == "failed" {
      failed_count += 1
    } else {
      missing_count += 1
    }
    if !json_bool(evidence, "runtime_command_recorded", default=false) {
      missing_runtime_command_count += 1
    }
    required_event_count += runtime_json_int(
      evidence,
      "required_event_count",
      default=0,
    )
    proven_required_event_count += runtime_json_int(
      evidence,
      "proven_required_event_count",
      default=0,
    )
    failed_required_event_count += runtime_json_int(
      evidence,
      "failed_required_event_count",
      default=0,
    )
    missing_required_event_count += runtime_json_int(
      evidence,
      "missing_required_event_count",
      default=0,
    )
    tool_harness_expected_tool_count += runtime_json_int(
      evidence,
      "tool_harness_expected_tool_count",
      default=0,
    )
    tool_harness_proven_tool_count += runtime_json_int(
      evidence,
      "tool_harness_proven_tool_count",
      default=0,
    )
    tool_harness_failed_tool_count += runtime_json_int(
      evidence,
      "tool_harness_failed_tool_count",
      default=0,
    )
    tool_harness_missing_tool_count += runtime_json_int(
      evidence,
      "tool_harness_missing_tool_count",
      default=0,
    )
    items.push({
      "index": index,
      "command_id": json_string(command, "command_id", default=""),
      "action": json_string(command, "action", default="prompt"),
      "created_at": json_string(command, "created_at", default=""),
      "context_path": json_string(command, "context_path", default=""),
      "message": json_string(command, "message", default=""),
      "runtime_command_recorded": json_bool(
        evidence,
        "runtime_command_recorded",
        default=false,
      ),
      "status": status,
      "required_event_count": runtime_json_int(
        evidence,
        "required_event_count",
        default=0,
      ),
      "proven_required_event_count": runtime_json_int(
        evidence,
        "proven_required_event_count",
        default=0,
      ),
      "missing_required_events": evidence_json_array(
        evidence, "missing_required_events",
      ),
      "failed_required_events": evidence_json_array(
        evidence, "failed_required_events",
      ),
      "tool_harness_status": json_string(
        evidence,
        "tool_harness_status",
        default="missing-evidence",
      ),
      "tool_harness_proven_tool_count": runtime_json_int(
        evidence,
        "tool_harness_proven_tool_count",
        default=0,
      ),
      "tool_harness_expected_tool_count": runtime_json_int(
        evidence,
        "tool_harness_expected_tool_count",
        default=0,
      ),
      "evidence": evidence,
    })
    index += 1
  }
  {
    "kind": "mooncode-session-runtime-evidence",
    "protocol": "mooncode.v1",
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "command_count": commands.length(),
    "runtime_command_count": runtime_commands.length(),
    "proof_event_count": proof_events.length(),
    "proven_command_count": proven_count,
    "missing_evidence_command_count": missing_count,
    "failed_evidence_command_count": failed_count,
    "missing_runtime_command_count": missing_runtime_command_count,
    "required_event_count": required_event_count,
    "proven_required_event_count": proven_required_event_count,
    "missing_required_event_count": missing_required_event_count,
    "failed_required_event_count": failed_required_event_count,
    "tool_harness_expected_tool_count": tool_harness_expected_tool_count,
    "tool_harness_proven_tool_count": tool_harness_proven_tool_count,
    "tool_harness_missing_tool_count": tool_harness_missing_tool_count,
    "tool_harness_failed_tool_count": tool_harness_failed_tool_count,
    "tool_harness_status": if tool_harness_expected_tool_count == 0 {
      "no-tools"
    } else if tool_harness_failed_tool_count > 0 {
      "failed"
    } else if tool_harness_missing_tool_count > 0 {
      "missing-evidence"
    } else {
      "proven"
    },
    "status": if commands.length() == 0 {
      "no-commands"
    } else if failed_count > 0 || failed_required_event_count > 0 {
      "failed"
    } else if missing_count > 0 ||
      missing_runtime_command_count > 0 ||
      missing_required_event_count > 0 {
      "missing-evidence"
    } else {
      "proven"
    },
    "items": Json::array(items),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "extractable_component": "mooncode",
    },
    "rule": "This projection is the session-level proof contract. Moondesk records and displays it, while MoonClaw or standalone MoonCode must satisfy it with command-scoped runtime events.",
  }
}

///|
fn evidence_runtime_command_for_id(
  command_id : String,
  runtime_commands : Array[Json],
) -> Json {
  if command_id == "" {
    return Json::object({})
  }
  for runtime_command in runtime_commands {
    if json_string(runtime_command, "command_id", default="") == command_id {
      return runtime_command
    }
  }
  Json::object({})
}

///|
fn evidence_required_events(action : String, summary : Json) -> Array[String] {
  let required = evidence_json_string_array_items(summary, "required_events")
  if required.length() == 0 {
    native_command_expected_events(action)
  } else {
    required
  }
}

///|
fn evidence_json_object_field_or_empty(json : Json, key : String) -> Json {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => value
        None => Json::object({})
      }
    _ => Json::object({})
  }
}

///|
fn evidence_json_array(json : Json, key : String) -> Json {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) => Json::array(values)
        _ => []
      }
    _ => []
  }
}

///|
fn evidence_json_string_array_items(json : Json, key : String) -> Array[String] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) => {
          let result : Array[String] = []
          for value in values {
            match value {
              Json::String(item) => result.push(item)
              _ => ()
            }
          }
          result
        }
        _ => []
      }
    _ => []
  }
}
