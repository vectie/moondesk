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
