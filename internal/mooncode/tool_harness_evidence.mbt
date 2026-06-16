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
    match json_string(proof, "status", default="missing") {
      "proven" => proven_count += 1
      "failed" => failed_count += 1
      _ => missing_count += 1
    }
  }
  {
    "kind": "mooncode-tool-harness-evidence",
    "protocol": "mooncode.v1",
    "reference": "../openseek/eval/tool_harness",
    "command_id": command_id,
    "action": action,
    "expected_tool_count": tools.length(),
    "proven_tool_count": proven_count,
    "failed_tool_count": failed_count,
    "missing_tool_count": missing_count,
    "expected_tools": string_array_json(tools),
    "cases": Json::array(cases),
    "status": if tools.length() == 0 {
      "no-tools"
    } else if failed_count > 0 {
      "failed"
    } else if missing_count > 0 {
      "missing-evidence"
    } else {
      "proven"
    },
    "proven": tools.length() > 0 && failed_count == 0 && missing_count == 0,
    "rule": "MoonClaw or standalone MoonCode must run each expected tool through the typed tool boundary and emit command-scoped tool_call/tool_result proof. Moondesk records and renders the verdict; it does not execute tools.",
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
  if from_summary.length() > 0 {
    tool_harness_dedup_strings(from_summary)
  } else {
    tool_harness_dedup_strings(native_command_tool_sequence(action))
  }
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
    if json_string(event, "status", default="") == "failed" ||
      json_string(event, "kind", default="") == "tool_call_decode_error" {
      if json_string(failed, "id", default="") == "" {
        failed = event
      }
      continue
    }
    if tool == "finish" {
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
  let call_seen = tool == "finish" || call_id != ""
  let result_seen = if tool == "finish" {
    json_string(result, "id", default="") != ""
  } else {
    result_id != "" && (call_id == "" || call_id == result_id)
  }
  let failed_seen = json_string(failed, "id", default="") != ""
  let status = if failed_seen {
    "failed"
  } else if call_seen && result_seen {
    "proven"
  } else {
    "missing"
  }
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
  if tool == "finish" {
    let kind = json_string(event, "kind", default="")
    return kind == "finish" || kind == "agent_finished"
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
fn tool_harness_dedup_strings(items : Array[String]) -> Array[String] {
  let result : Array[String] = []
  for item in items {
    if item != "" && !result.contains(item) {
      result.push(item)
    }
  }
  result
}

///|
fn tool_harness_json_object_field_or_empty(json : Json, key : String) -> Json {
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
fn tool_harness_json_string_array_items(
  json : Json,
  key : String,
) -> Array[String] {
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
