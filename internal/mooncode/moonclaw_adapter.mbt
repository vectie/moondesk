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
      "native_target": "/v1/mooncode/capabilities plus /v1/mooncode/sessions?book_root=<path>, /v1/mooncode/sessions/<id>?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-claim?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-dispatch?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-turn?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-loop?book_root=<path>, /v1/mooncode/sessions/<id>/runtime-events?book_root=<path>, /v1/mooncode/sessions/<id>/tool-exec?book_root=<path>, /v1/mooncode/sessions/<id>/commands, and /v1/mooncode/sessions/<id>/package-result",
    },
    "event_mapping": moonclaw_event_mapping_json(),
    "tool_mapping": Json::array(moonclaw_tool_mapping_rows()),
    "native_gap": "Current MoonClaw daemon routes now expose native MoonCode capabilities, cold book-local sidecar list/show, native runtime-claim receipts, native runtime-dispatch delivery receipts, native runtime-turn execution receipts for explicit, deterministic, or bounded model-planned tool calls with tool-result feedback plus planner reasoning/assistant/tool-call events, native runtime-loop queue supervision, native runtime-events evidence ingress, native read/edit/write/shell/moon_check/finish tool execution, command ingestion, session stream snapshots, native tool/file-edit eval-report evidence, prompt/steer/cancel controls, package-result acknowledgement, normalized MoonClaw task stream proof, and book-local durable MoonCode sidecars. Remaining native gap is a production-grade OpenSeek-style service for live steering, diff-aware review, long-running resume/cancel UX, and broader model-backed coding eval cases.",
    "boundary": {
      "moondesk": "records MoonCode command/session/review state and normalizes MoonClaw compatibility events",
      "moonclaw": "executes tools, streams events, enforces approvals, and reports proof",
      "mooncode": "defines the reusable protocol and adapter mapping",
    },
  }
}

///|
pub fn moonclaw_runtime_loop_request(
  session_id : String,
  book_root : String,
  consumer_id? : String = "moonclaw-native-runtime-loop",
  max_turns? : Int = 8,
) -> Json {
  {
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "book_root": book_root,
    "consumer_id": consumer_id,
    "max_turns": max_turns,
  }
}

///|
pub fn moonclaw_runtime_turn_request(
  session_id : String,
  book_root : String,
  consumer_id? : String = "moonclaw-native-runtime-turn",
) -> Json {
  {
    "protocol": "mooncode.v1",
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
    "protocol": "mooncode.v1",
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
