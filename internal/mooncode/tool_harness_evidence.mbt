///|
pub fn tool_harness_evidence(
  command : Json,
  runtime_command : Json,
  events : Array[Json],
) -> Json {
  let command_id = json_string(command, "command_id", default="")
  let action = json_string(command, "action", default="prompt")
  let tools = tool_harness_expected_tools(action, runtime_command)
  let cases : Array[Json] = []
  let mut proven_count = 0
  let mut failed_count = 0
  let mut missing_count = 0
  for tool in tools {
    let proof = tool_harness_case_evidence(tool, command_id, action, events)
    cases.push(proof)
    let status = json_string(
      proof,
      "status",
      default=@mooncode_core.runtime_required_event_status_missing(),
    )
    if status == @mooncode_core.runtime_evidence_status_proven() {
      proven_count += 1
    } else if status == @mooncode_core.runtime_evidence_status_failed() {
      failed_count += 1
    } else {
      missing_count += 1
    }
  }
  {
    "kind": @mooncode_core.tool_harness_evidence_kind(),
    "protocol": protocol_version(),
    "reference": "mooncode/eval/tool_harness",
    "command_id": command_id,
    "action": action,
    "expected_tool_count": tools.length(),
    "proven_tool_count": proven_count,
    "failed_tool_count": failed_count,
    "missing_tool_count": missing_count,
    "expected_tools": string_array_json(tools),
    "cases": Json::array(cases),
    "status": @mooncode_core.tool_harness_status_for_counts(
      tools.length(),
      failed_count,
      missing_count,
    ),
    "proven": @mooncode_core.tool_harness_is_proven(
      tools.length(),
      failed_count,
      missing_count,
    ),
    "rule": @mooncode_core.tool_harness_evidence_rule(),
  }
}

///|
fn tool_harness_expected_tools(
  action : String,
  runtime_command : Json,
) -> Array[String] {
  let summary = tool_harness_json_object_field_or_empty(
    runtime_command, "execution_summary",
  )
  let from_summary = tool_harness_json_string_array_items(
    summary, "tool_sequence",
  )
  @mooncode_core.tool_harness_expected_tools(action, from_summary)
}

///|
fn tool_harness_case_evidence(
  tool : String,
  command_id : String,
  action : String,
  events : Array[Json],
) -> Json {
  let mut call = Json::object({})
  let mut result = Json::object({})
  let mut failed = Json::object({})
  for event in events {
    if !tool_harness_event_matches_command(event, command_id, action) ||
      !tool_harness_event_matches_tool(event, tool) {
      continue
    }
    if json_string(event, "status", default="") ==
      @mooncode_core.runtime_evidence_status_failed() ||
      json_string(event, "kind", default="") == "tool_call_decode_error" {
      if json_string(failed, "id", default="") == "" {
        failed = event
      }
      continue
    }
    if tool == @mooncode_core.runtime_tool_finish() {
      result = event
      continue
    }
    if tool_harness_is_tool_call(event) &&
      json_string(call, "id", default="") == "" {
      call = event
    } else if tool_harness_is_tool_result(event) &&
      json_string(result, "id", default="") == "" {
      result = event
    }
  }
  let call_id = json_string(call, "tool_call_id", default="")
  let result_id = json_string(result, "tool_call_id", default="")
  let call_seen = tool == @mooncode_core.runtime_tool_finish() || call_id != ""
  let result_seen = if tool == @mooncode_core.runtime_tool_finish() {
    json_string(result, "id", default="") != ""
  } else {
    result_id != "" && (call_id == "" || call_id == result_id)
  }
  let failed_seen = json_string(failed, "id", default="") != ""
  let status = @mooncode_core.tool_harness_case_status(
    failed_seen, call_seen, result_seen,
  )
  {
    "tool": tool,
    "status": status,
    "call_seen": call_seen,
    "result_seen": result_seen,
    "failed_seen": failed_seen,
    "call_event_id": json_string(call, "id", default=""),
    "result_event_id": json_string(result, "id", default=""),
    "failed_event_id": json_string(failed, "id", default=""),
    "tool_call_id": if call_id != "" {
      call_id
    } else {
      result_id
    },
    "lane": json_string(
      result,
      "lane",
      default=json_string(call, "lane", default=""),
    ),
    "detail": if json_string(result, "detail", default="") != "" {
      json_string(result, "detail", default="")
    } else {
      json_string(failed, "detail", default="")
    },
  }
}

///|
fn tool_harness_event_matches_command(
  event : Json,
  command_id : String,
  action : String,
) -> Bool {
  if command_id == "" {
    return false
  }
  let packet = tool_harness_json_object_field_or_empty(event, "command_packet")
  json_string(packet, "command_id", default="") == command_id &&
  tool_harness_event_action(event, packet) == action
}

///|
fn tool_harness_event_action(event : Json, packet : Json) -> String {
  let packet_action = json_string(packet, "action", default="")
  if packet_action != "" {
    return packet_action
  }
  let command = json_string(event, "command", default="")
  if command != "" {
    command
  } else {
    "prompt"
  }
}

///|
fn tool_harness_event_matches_tool(event : Json, tool : String) -> Bool {
  if tool == @mooncode_core.runtime_tool_finish() {
    let kind = json_string(event, "kind", default="")
    return kind == "finish" || kind == "runtime_finished"
  }
  let kind = json_string(event, "kind", default="")
  if kind == tool {
    return true
  }
  json_string(event, "tool_name", default="") == tool
}

///|
fn tool_harness_is_tool_call(event : Json) -> Bool {
  json_string(event, "tool_call_id", default="") != "" &&
  json_string(event, "status", default="") == "running"
}

///|
fn tool_harness_is_tool_result(event : Json) -> Bool {
  json_string(event, "tool_call_id", default="") != "" &&
  json_string(event, "status", default="") != "running"
}

///|
fn tool_harness_json_object_field_or_empty(json : Json, key : String) -> Json {
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
fn tool_harness_json_string_array_items(
  json : Json,
  key : String,
) -> Array[String] {
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
