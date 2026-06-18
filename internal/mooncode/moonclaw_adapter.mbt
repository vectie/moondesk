///|
pub fn moonclaw_adapter_contract_json() -> Json {
  {
    "kind": "mooncode-moonclaw-adapter-contract",
    "protocol": protocol_version(),
    "owner": "mooncode",
    "runtime_owner": "moonclaw",
    "reference": "../moonclaw",
    "daemon": {
      "legacy_task_create": "POST /v1/task",
      "legacy_task_events": "GET /v1/task/<task-id>/events",
      "legacy_task_forward": "ANY /v1/task/<task-id>/...",
      "native_target": "/v1/mooncode/capabilities plus /v1/mooncode/sessions?book_root=<path>, /v1/mooncode/sessions?book_root=<path>&format=json, /v1/mooncode/sessions/<id>?book_root=<path>, /v1/mooncode/sessions/<id>/serve-scheduler?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-claim?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-dispatch?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-turn?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-loop?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-events?book_root=<path>, /v1/mooncode/sessions/<id>/tool-exec?book_root=<path>, /v1/mooncode/sessions/<id>/commands, /v1/mooncode/sessions/<id>/eval-report?book_root=<path>, and /v1/mooncode/sessions/<id>/package-result?book_root=<path>",
    },
    "event_mapping": moonclaw_event_mapping_json(),
    "tool_mapping": Json::array(moonclaw_tool_mapping_rows()),
    "native_gap": "Current MoonClaw daemon routes now expose native MoonCode capabilities, cold book-local sidecar list/show, native serve-scheduler projection, native runtime-claim receipts, native runtime-dispatch delivery receipts, native runtime-turn execution receipts for explicit, deterministic, or bounded model-planned tool calls with tool-result feedback plus planner reasoning/assistant/tool-call events, native runtime-loop queue supervision, native runtime-events evidence ingress, native read/edit/write/apply_patch/revert_patch/shell/moon_ide/moon_cmd/moon_check/finish tool execution, command ingestion, session stream snapshots, native tool/file-edit eval-report evidence, prompt/steer/cancel controls, package-result acknowledgement, normalized MoonClaw task stream proof, and book-local durable MoonCode sidecars. Remaining native gap is a production-grade OpenSeek-style service for live steering, diff-aware review, long-running resume/cancel UX, and broader model-backed coding eval cases.",
    "boundary": {
      "moondesk": "records MoonCode command/session/review state and normalizes MoonClaw compatibility events",
      "moonclaw": "executes tools, streams events, enforces approvals, and reports proof",
      "mooncode": "defines the reusable protocol and adapter mapping",
    },
  }
}

///|
pub fn moonclaw_native_required_endpoints() -> Array[String] {
  native_capability_required_endpoints()
}

///|
pub fn moonclaw_native_required_tools() -> Array[String] {
  native_capability_required_tools()
}

///|
pub fn moonclaw_native_capability_contract_id() -> String {
  native_capability_contract_id()
}

///|
fn moonclaw_native_capability_surface_present(capabilities : Json) -> Bool {
  match rq_json_object_field(capabilities, "capability_surface") {
    Some(Json::Object(_)) => true
    _ => false
  }
}

///|
pub fn moonclaw_native_capabilities_readiness(capabilities : Json) -> Json {
  let required_endpoints = moonclaw_native_required_endpoints()
  let required_tools = moonclaw_native_required_tools()
  let expected_contract_id = moonclaw_native_capability_contract_id()
  let endpoints = rq_json_string_array_items(capabilities, "endpoints")
  let tools = rq_json_string_array_items(capabilities, "tools")
  let missing_endpoints = moonclaw_missing_strings(
    required_endpoints, endpoints,
  )
  let missing_tools = moonclaw_missing_strings(required_tools, tools)
  let component_ok = moonclaw_json_string(capabilities, "component", default="") ==
    "mooncode"
  let protocol_ok = moonclaw_json_string(capabilities, "protocol", default="") ==
    protocol_version()
  let daemon_contract_id = moonclaw_json_string(
    capabilities,
    "capability_contract_id",
    default="",
  )
  let capability_contract_ok = daemon_contract_id == expected_contract_id
  let capability_surface = rq_json_object_field_or_empty(
    capabilities, "capability_surface",
  )
  let capability_surface_present = moonclaw_native_capability_surface_present(
    capabilities,
  )
  let surface_component_ok = moonclaw_json_string(
      capability_surface,
      "component",
      default="",
    ) ==
    "mooncode"
  let surface_protocol_ok = moonclaw_json_string(
      capability_surface,
      "protocol",
      default="",
    ) ==
    protocol_version()
  let surface_contract_id = moonclaw_json_string(
    capability_surface,
    "capability_contract_id",
    default="",
  )
  let surface_contract_ok = surface_contract_id == expected_contract_id
  let expected_surface_fingerprint = native_capability_surface_fingerprint()
  let surface_fingerprint = moonclaw_json_string(
    capability_surface,
    "capability_surface_fingerprint",
    default="",
  )
  let surface_fingerprint_ok = surface_fingerprint ==
    expected_surface_fingerprint
  let surface_missing_endpoints = moonclaw_missing_strings(
    required_endpoints,
    rq_json_string_array_items(capability_surface, "required_endpoints"),
  )
  let surface_missing_tools = moonclaw_missing_strings(
    required_tools,
    rq_json_string_array_items(capability_surface, "required_tools"),
  )
  let capability_surface_ok = capability_surface_present &&
    surface_component_ok &&
    surface_protocol_ok &&
    surface_contract_ok &&
    surface_fingerprint_ok &&
    surface_missing_endpoints.length() == 0 &&
    surface_missing_tools.length() == 0
  let runtime_ready = rq_json_bool(
    capabilities,
    "native_runtime_ready",
    default=false,
  )
  let ok = component_ok &&
    protocol_ok &&
    capability_contract_ok &&
    capability_surface_ok &&
    runtime_ready &&
    missing_endpoints.length() == 0 &&
    missing_tools.length() == 0
  {
    "kind": "mooncode-moonclaw-native-capabilities-readiness",
    "protocol": protocol_version(),
    "ok": ok,
    "status": if ok {
      "native-runtime-ready"
    } else {
      "native-runtime-incompatible"
    },
    "component_ok": component_ok,
    "protocol_ok": protocol_ok,
    "capability_contract_id": expected_contract_id,
    "daemon_capability_contract_id": daemon_contract_id,
    "capability_contract_ok": capability_contract_ok,
    "expected_capability_surface": native_capability_surface_json(),
    "daemon_capability_surface": capability_surface,
    "capability_surface_present": capability_surface_present,
    "capability_surface_fingerprint": expected_surface_fingerprint,
    "daemon_capability_surface_fingerprint": surface_fingerprint,
    "capability_surface_fingerprint_ok": surface_fingerprint_ok,
    "daemon_capability_surface_contract_id": surface_contract_id,
    "capability_surface_ok": capability_surface_ok,
    "capability_surface_component_ok": surface_component_ok,
    "capability_surface_protocol_ok": surface_protocol_ok,
    "capability_surface_contract_ok": surface_contract_ok,
    "capability_surface_missing_endpoint_count": surface_missing_endpoints.length(),
    "capability_surface_missing_endpoints": Json::array(
      [
        for item in surface_missing_endpoints => Json::string(item)
      ],
    ),
    "capability_surface_missing_tool_count": surface_missing_tools.length(),
    "capability_surface_missing_tools": Json::array(
      [
        for item in surface_missing_tools => Json::string(item)
      ],
    ),
    "native_runtime_ready": runtime_ready,
    "required_endpoint_count": required_endpoints.length(),
    "missing_endpoint_count": missing_endpoints.length(),
    "missing_endpoints": Json::array(
      [
        for item in missing_endpoints => Json::string(item)
      ],
    ),
    "required_tool_count": required_tools.length(),
    "missing_tool_count": missing_tools.length(),
    "missing_tools": Json::array(
      [
        for item in missing_tools => Json::string(item)
      ],
    ),
    "rule": "Moondesk may use MoonClaw native MoonCode runtime only when the daemon advertises the current protocol, capability surface object, endpoint set, and tool-execution set owned by the MoonCode boundary.",
  }
}

///|
pub fn moonclaw_native_capabilities_unavailable(error : String) -> Json {
  {
    "kind": "mooncode-moonclaw-native-capabilities-readiness",
    "protocol": protocol_version(),
    "capability_contract_id": moonclaw_native_capability_contract_id(),
    "capability_contract_ok": false,
    "expected_capability_surface": native_capability_surface_json(),
    "capability_surface_present": false,
    "capability_surface_ok": false,
    "ok": false,
    "status": "native-runtime-unavailable",
    "error": error,
    "rule": "Moondesk may use MoonClaw native MoonCode runtime only when the daemon advertises the current protocol, capability surface object, endpoint set, and tool-execution set owned by the MoonCode boundary.",
  }
}

///|
pub fn moonclaw_native_capabilities_ready(capabilities : Json) -> Bool {
  rq_json_bool(
    moonclaw_native_capabilities_readiness(capabilities),
    "ok",
    default=false,
  )
}

///|
pub fn moonclaw_runtime_loop_request(
  session_id : String,
  book_root : String,
  consumer_id? : String = "moonclaw-native-runtime-loop",
  max_turns? : Int = 8,
  live_wait_ms? : Int = 0,
  poll_ms? : Int = 250,
) -> Json {
  {
    "protocol": protocol_version(),
    "session_id": session_id,
    "book_root": book_root,
    "consumer_id": consumer_id,
    "max_turns": max_turns,
    "live_wait_ms": live_wait_ms,
    "poll_ms": poll_ms,
  }
}

///|
pub fn moonclaw_runtime_turn_request(
  session_id : String,
  book_root : String,
  consumer_id? : String = "moonclaw-native-runtime-turn",
) -> Json {
  {
    "protocol": protocol_version(),
    "session_id": session_id,
    "book_root": book_root,
    "consumer_id": consumer_id,
  }
}

///|
pub fn moonclaw_runtime_dispatch_mode(
  response : Json,
  accepted? : Bool = true,
) -> String {
  if !accepted {
    return "moonclaw-mooncode-runtime"
  }
  if json_string(response, "kind", default="") == "mooncode-runtime-loop" {
    "moonclaw-mooncode-runtime-loop"
  } else {
    "moonclaw-mooncode-runtime-turn"
  }
}

///|
pub fn moonclaw_native_runtime_dispatch_result(
  queue_response : Json,
  runtime_payload : Json,
  command_packet : Json,
  queue_accepted~ : Bool,
  runtime_succeeded~ : Bool,
  runtime_error~ : String,
) -> Json {
  let runtime_accepted = json_bool(runtime_payload, "accepted", default=false)
  let status = if !queue_accepted {
    "failed"
  } else if !runtime_succeeded {
    "failed"
  } else if runtime_accepted {
    "done"
  } else {
    "failed"
  }
  let detail = json_string(
    runtime_payload,
    "message",
    default=if runtime_succeeded {
      json_string(
        queue_response,
        "message",
        default="MoonClaw MoonCode runtime accepted \{json_string(command_packet, "action", default="command")}",
      )
    } else {
      "MoonClaw queued command but native runtime execution failed: \{runtime_error}"
    },
  )
  {
    "kind": "mooncode-native-runtime-dispatch-result",
    "protocol": protocol_version(),
    "queue_accepted": queue_accepted,
    "runtime_succeeded": runtime_succeeded,
    "runtime_accepted": runtime_accepted,
    "status": status,
    "detail": detail,
    "dispatch_mode": moonclaw_runtime_dispatch_mode(
      runtime_payload,
      accepted=runtime_accepted,
    ),
  }
}

///|
pub fn moonclaw_native_runtime_session_patch(
  dispatch_result : Json,
  command_packet : Json,
  message : String,
  updated_at : String,
) -> Json {
  let status = json_string(dispatch_result, "status", default="failed")
  let detail = json_string(dispatch_result, "detail", default="")
  let dispatch_mode = json_string(dispatch_result, "dispatch_mode", default="")
  {
    "kind": "mooncode-native-runtime-session-patch",
    "protocol": protocol_version(),
    "status": status,
    "detail": detail,
    "last_message": message,
    "mooncode_last_command_packet": command_packet,
    "mooncode_dispatch_mode": dispatch_mode,
    "updated_at": updated_at,
    "status_message": {
      "role": "status",
      "content": detail,
      "status": status,
      "created_at": updated_at,
    },
  }
}

///|
pub fn moonclaw_task_bridge_session_patch(
  command_packet : Json,
  message : String,
  updated_at : String,
) -> Json {
  {
    "kind": "mooncode-moonclaw-task-bridge-session-patch",
    "protocol": protocol_version(),
    "last_message": message,
    "mooncode_last_command_packet": command_packet,
    "mooncode_dispatch_mode": "moonclaw-task-bridge",
    "updated_at": updated_at,
  }
}

///|
pub fn moonclaw_runtime_supervisor_run_session_patch(
  response : Json,
  updated_at : String,
) -> Json {
  let accepted = json_bool(response, "accepted", default=false)
  let status = if accepted { "done" } else { "failed" }
  let detail = json_string(
    response,
    "message",
    default=if accepted {
      "MoonClaw native MoonCode runtime loop completed"
    } else {
      "MoonClaw native MoonCode runtime loop did not accept work"
    },
  )
  {
    "kind": "mooncode-runtime-supervisor-run-session-patch",
    "protocol": protocol_version(),
    "status": status,
    "detail": detail,
    "mooncode_dispatch_mode": moonclaw_runtime_dispatch_mode(response),
    "updated_at": updated_at,
    "status_message": {
      "role": "status",
      "content": detail,
      "status": status,
      "created_at": updated_at,
    },
  }
}

///|
pub fn apply_moonclaw_runtime_session_patch(
  session : Json,
  patch : Json,
) -> Json {
  let mut next = session
  match moonclaw_patch_field(patch, "last_message") {
    Some(value) => next = session_with_field(next, "last_message", value)
    None => ()
  }
  match moonclaw_patch_field(patch, "mooncode_last_command_packet") {
    Some(value) =>
      next = session_with_field(next, "mooncode_last_command_packet", value)
    None => ()
  }
  match moonclaw_patch_field(patch, "mooncode_dispatch_mode") {
    Some(value) =>
      next = session_with_field(next, "mooncode_dispatch_mode", value)
    None => ()
  }
  match moonclaw_patch_field(patch, "updated_at") {
    Some(value) => next = session_with_field(next, "updated_at", value)
    None => ()
  }
  next
}

///|
fn moonclaw_patch_field(patch : Json, key : String) -> Json? {
  match patch {
    Json::Object(fields) => fields.get(key)
    _ => None
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
    "PreToolCall": {
      "event": event_tool_call(),
      "lane": "tool",
      "status": "running",
    },
    "PostToolCall": {
      "event": event_tool_result(),
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
    "protocol": protocol_version(),
    "status": status,
    "daemon_running": daemon_running,
    "native_mooncode_ready": native_mooncode_ready,
    "legacy_task_bridge_ready": legacy_task_bridge_ready,
    "task_events_ready": task_events_ready,
    "missing": Json::array([ for item in missing => Json::string(item) ]),
    "contract": moonclaw_adapter_contract_json(),
  }
}
