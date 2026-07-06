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
    let status = json_string(
      proof,
      "status",
      default=@mooncode_core.runtime_required_event_status_missing(),
    )
    if status == @mooncode_core.runtime_required_event_status_proven() {
      proven_count += 1
    } else if status == @mooncode_core.runtime_required_event_status_failed() {
      failed_count += 1
    } else {
      missing_count += 1
    }
  }
  let required_outputs = @mooncode_core.runtime_evidence_required_outputs(
    action,
    evidence_json_string_array_items(summary, "required_outputs"),
  )
  let tool_harness = tool_harness_evidence(command, runtime_command, events)
  {
    "kind": @mooncode_core.command_runtime_evidence_kind(),
    "protocol": protocol_version(),
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
      default=@mooncode_core.runtime_evidence_status_missing(),
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
    "proven": @mooncode_core.runtime_evidence_is_proven(
      required_events.length(),
      missing_count,
      failed_count,
    ),
    "status": @mooncode_core.runtime_evidence_status_for_required_events(
      required_events.length(),
      missing_count,
      failed_count,
    ),
    "rule": @mooncode_core.runtime_evidence_command_rule(),
  }
}

///|
fn evidence_required_events(action : String, summary : Json) -> Array[String] {
  @mooncode_core.runtime_evidence_required_events(
    action,
    evidence_json_string_array_items(summary, "required_events"),
  )
}

///|
fn evidence_json_object_field_or_empty(json : Json, key : String) -> Json {
  match json {
    Object(object) =>
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
    Object(object) =>
      match object.get(key) {
        Some(Array(values)) => Json::array(values)
        _ => []
      }
    _ => []
  }
}

///|
fn evidence_json_string_array_items(json : Json, key : String) -> Array[String] {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(Array(values)) => {
          let result : Array[String] = []
          for value in values {
            match value {
              String(item) => result.push(item)
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
