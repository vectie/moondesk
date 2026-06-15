///|
pub fn moonclaw_adapter_contract_json() -> Json {
  {
    "kind": "mooncode-moonclaw-adapter-contract",
    "protocol": "mooncode.v1",
    "owner": "mooncode",
    "runtime_owner": "moonclaw",
    "reference": "../moonclaw",
    "daemon": {
      "legacy_task_create": "POST /v1/task",
      "legacy_task_events": "GET /v1/task/<task-id>/events",
      "legacy_task_forward": "ANY /v1/task/<task-id>/...",
      "native_target": "/v1/mooncode/capabilities plus /v1/mooncode/sessions/<id>/commands",
    },
    "event_mapping": moonclaw_event_mapping_json(),
    "tool_mapping": Json::array(moonclaw_tool_mapping_rows()),
    "native_gap": "Current MoonClaw daemon routes now expose native MoonCode capabilities, command ingestion, session stream snapshots, eval-report snapshots, and prompt/steer/cancel controls. Remaining native gaps are package-result acknowledgement, richer streamed runtime proof, and typed durable MoonClaw-owned MoonCode sessions beyond the in-memory daemon binding.",
    "boundary": {
      "moondesk": "records MoonCode command/session/review state and normalizes MoonClaw compatibility events",
      "moonclaw": "executes tools, streams events, enforces approvals, and reports proof",
      "mooncode": "defines the reusable protocol and adapter mapping",
    },
  }
}

///|
pub fn moonclaw_event_mapping_json() -> Json {
  {
    "AssistantMessageDelta": {
      "event": "assistant_delta",
      "lane": "transcript",
      "status": "running",
    },
    "AssistantMessage": {
      "event": "assistant_message",
      "lane": "transcript",
      "status": "done",
    },
    "PreToolCall": { "event": "tool_call", "lane": "tool", "status": "running" },
    "PostToolCall": {
      "event": "tool_result",
      "lane": "tool",
      "status": "done-or-failed",
    },
    "Cancelled": {
      "event": "agent_aborted",
      "lane": "review",
      "status": "failed",
    },
    "Failed": { "event": "agent_aborted", "lane": "review", "status": "failed" },
  }
}

///|
pub fn moonclaw_tool_mapping_rows() -> Array[Json] {
  [
    moonclaw_tool_mapping_row("read_file", "read", "native-compatible"),
    moonclaw_tool_mapping_row(
      "read_multiple_files", "read", "native-compatible",
    ),
    moonclaw_tool_mapping_row("read_resource", "read", "native-compatible"),
    moonclaw_tool_mapping_row("write_to_file", "write", "native-compatible"),
    moonclaw_tool_mapping_row("replace_in_file", "edit", "native-compatible"),
    moonclaw_tool_mapping_row("patch_edit", "edit", "native-compatible"),
    moonclaw_tool_mapping_row("apply_patch", "apply_patch", "native-compatible"),
    moonclaw_tool_mapping_row("execute_command", "shell", "native-compatible"),
    moonclaw_tool_mapping_row("list_files", "read", "discovery-compatible"),
    moonclaw_tool_mapping_row("glob_files", "read", "discovery-compatible"),
    moonclaw_tool_mapping_row("search_files", "read", "discovery-compatible"),
    moonclaw_tool_mapping_row("runtime_context", "read", "context-compatible"),
    moonclaw_tool_mapping_row("todo", "finish", "planning-only"),
  ]
}

///|
pub fn moonclaw_tool_to_mooncode_tool(tool_name : String) -> String {
  match tool_name {
    "read_file" | "read_multiple_files" | "read_resource" => "read"
    "write_to_file" => "write"
    "replace_in_file" | "patch_edit" => "edit"
    "apply_patch" => "apply_patch"
    "execute_command" => "shell"
    "list_files" | "glob_files" | "search_files" | "runtime_context" => "read"
    "todo" => "finish"
    _ => tool_name
  }
}

///|
pub fn moonclaw_adapter_readiness(
  daemon_running : Bool,
  native_mooncode_ready : Bool,
  legacy_task_bridge_ready : Bool,
  task_events_ready : Bool,
) -> Json {
  let missing : Array[String] = []
  if !daemon_running {
    missing.push("moonclaw-daemon")
  }
  if !native_mooncode_ready {
    missing.push("native-/v1/mooncode")
  }
  if !legacy_task_bridge_ready {
    missing.push("legacy-/v1/task bridge")
  }
  if !task_events_ready {
    missing.push("legacy task event stream")
  }
  let status = if native_mooncode_ready {
    "native-ready"
  } else if daemon_running && legacy_task_bridge_ready && task_events_ready {
    "compatibility-bridge"
  } else {
    "missing-runtime"
  }
  {
    "kind": "mooncode-moonclaw-adapter-readiness",
    "protocol": "mooncode.v1",
    "status": status,
    "daemon_running": daemon_running,
    "native_mooncode_ready": native_mooncode_ready,
    "legacy_task_bridge_ready": legacy_task_bridge_ready,
    "task_events_ready": task_events_ready,
    "missing": Json::array([ for item in missing => Json::string(item) ]),
    "contract": moonclaw_adapter_contract_json(),
  }
}

///|
pub fn moonclaw_event_to_runtime_event(
  event : Json,
  fallback_id~ : String,
  fallback_created_at~ : String,
) -> Json? {
  let desc = moonclaw_json_object_field_or_empty(event, "desc")
  let msg = moonclaw_json_string(desc, "msg", default="")
  if msg == "" {
    return None
  }
  let event_id = moonclaw_json_string(event, "id", default=fallback_id)
  let created_at = moonclaw_first_string(
    event,
    ["created_at", "created"],
    default=fallback_created_at,
  )
  match msg {
    "AssistantMessageDelta" =>
      Some({
        "event": "assistant_delta",
        "id": event_id,
        "created_at": created_at,
        "content": moonclaw_json_string(desc, "content", default=""),
      })
    "AssistantMessage" =>
      Some({
        "event": "assistant_message",
        "id": event_id,
        "created_at": created_at,
        "content": moonclaw_json_string(desc, "content", default=""),
      })
    "PreToolCall" =>
      Some(
        moonclaw_tool_event(
          event_name="tool_call",
          event_id~,
          created_at~,
          desc~,
          failed=false,
        ),
      )
    "PostToolCall" =>
      Some(
        moonclaw_tool_event(
          event_name="tool_result",
          event_id~,
          created_at~,
          desc~,
          failed=moonclaw_json_object_field(desc, "error") is Some(_),
        ),
      )
    "Cancelled" =>
      Some({
        "event": "agent_aborted",
        "id": event_id,
        "created_at": created_at,
        "reason": "MoonClaw task cancelled.",
      })
    "Failed" =>
      Some({
        "event": "agent_aborted",
        "id": event_id,
        "created_at": created_at,
        "reason": moonclaw_json_object_field_or_empty(desc, "error").stringify(),
      })
    _ => None
  }
}

///|
fn moonclaw_tool_event(
  event_name~ : String,
  event_id~ : String,
  created_at~ : String,
  desc~ : Json,
  failed~ : Bool,
) -> Json {
  let tool_call = moonclaw_json_object_field_or_empty(desc, "tool_call")
  let raw_name = moonclaw_json_string(desc, "name", default="")
  let tool_name = moonclaw_tool_to_mooncode_tool(raw_name)
  let normalized_tool_call = moonclaw_tool_call_with_name(tool_call, tool_name)
  let detail = moonclaw_json_string(
    desc,
    "text",
    default=if failed { "MoonClaw tool failed." } else { "" },
  )
  {
    "event": event_name,
    "id": event_id,
    "created_at": created_at,
    "tool_name": tool_name,
    "moonclaw_tool_name": raw_name,
    "tool_call_id": moonclaw_json_string(tool_call, "id", default=""),
    "tool_call": normalized_tool_call,
    "arguments": moonclaw_tool_call_arguments(tool_call),
    "content": detail,
    "error": moonclaw_json_object_field_or_empty(desc, "error").stringify(),
    "status": if failed {
      "failed"
    } else {
      "done"
    },
  }
}

///|
fn moonclaw_tool_call_with_name(tool_call : Json, tool_name : String) -> Json {
  let function = moonclaw_json_object_field_or_empty(tool_call, "function")
  let next_function = moonclaw_json_with_string(function, "name", tool_name)
  moonclaw_json_with_json(tool_call, "function", next_function)
}

///|
fn moonclaw_tool_call_arguments(tool_call : Json) -> String {
  let function = moonclaw_json_object_field_or_empty(tool_call, "function")
  moonclaw_json_string(function, "arguments", default="")
}

///|
fn moonclaw_tool_mapping_row(
  moonclaw_tool : String,
  mooncode_tool : String,
  compatibility : String,
) -> Json {
  {
    "moonclaw_tool": moonclaw_tool,
    "mooncode_tool": mooncode_tool,
    "compatibility": compatibility,
  }
}

///|
fn moonclaw_json_object_field_or_empty(json : Json, key : String) -> Json {
  match moonclaw_json_object_field(json, key) {
    Some(value) => value
    None => Json::object({})
  }
}

///|
fn moonclaw_json_object_field(json : Json, key : String) -> Json? {
  match json {
    Json::Object(object) => object.get(key)
    _ => None
  }
}

///|
fn moonclaw_json_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        Some(Json::Number(value, ..)) => value.to_string()
        _ => default
      }
    _ => default
  }
}

///|
fn moonclaw_first_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  for key in keys {
    let value = moonclaw_json_string(json, key, default="")
    if value != "" {
      return value
    }
  }
  default
}

///|
fn moonclaw_json_with_string(json : Json, key : String, value : String) -> Json {
  let object : Map[String, Json] = {}
  match json {
    Json::Object(fields) =>
      for k, v in fields {
        object[k] = v
      }
    _ => ()
  }
  object[key] = value.to_json()
  Json::object(object)
}

///|
fn moonclaw_json_with_json(json : Json, key : String, value : Json) -> Json {
  let object : Map[String, Json] = {}
  match json {
    Json::Object(fields) =>
      for k, v in fields {
        object[k] = v
      }
    _ => ()
  }
  object[key] = value
  Json::object(object)
}

///|
test "mooncode moonclaw adapter maps moonclaw tools to mooncode tools" {
  assert_eq(moonclaw_tool_to_mooncode_tool("execute_command"), "shell")
  assert_eq(moonclaw_tool_to_mooncode_tool("read_file"), "read")
  assert_eq(moonclaw_tool_to_mooncode_tool("write_to_file"), "write")
  assert_eq(moonclaw_tool_to_mooncode_tool("replace_in_file"), "edit")
  assert_eq(moonclaw_tool_to_mooncode_tool("unknown_tool"), "unknown_tool")
  let contract = moonclaw_adapter_contract_json()
  assert_eq(
    moonclaw_json_string(contract, "kind", default=""),
    "mooncode-moonclaw-adapter-contract",
  )
  assert_true(contract.stringify().contains("/v1/task/<task-id>/events"))
}

///|
test "mooncode moonclaw adapter normalizes tool events" {
  let raw : Json = {
    "id": "evt-1",
    "created": 0,
    "desc": {
      "msg": "PreToolCall",
      "tool_call": {
        "id": "call-1",
        "function": {
          "name": "execute_command",
          "arguments": "{\"command\":\"moon test\"}",
        },
        "type": "function",
      },
      "name": "execute_command",
    },
  }
  guard moonclaw_event_to_runtime_event(
      raw,
      fallback_id="fallback",
      fallback_created_at="2026-06-15T00:00:00Z",
    )
    is Some(event) else {
    fail("expected MoonClaw tool event")
  }
  assert_eq(moonclaw_json_string(event, "event", default=""), "tool_call")
  assert_eq(moonclaw_json_string(event, "tool_name", default=""), "shell")
  let tool_call = moonclaw_json_object_field_or_empty(event, "tool_call")
  let function = moonclaw_json_object_field_or_empty(tool_call, "function")
  assert_eq(moonclaw_json_string(function, "name", default=""), "shell")
}

///|
test "mooncode moonclaw adapter readiness distinguishes bridge from native" {
  let bridged = moonclaw_adapter_readiness(true, false, true, true)
  assert_eq(
    moonclaw_json_string(bridged, "status", default=""),
    "compatibility-bridge",
  )
  let native = moonclaw_adapter_readiness(true, true, true, true)
  assert_eq(moonclaw_json_string(native, "status", default=""), "native-ready")
}
