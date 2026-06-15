///|
pub fn session_snapshot(
  session : Json,
  events : Array[Json],
  commands : Array[Json],
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  recorded_at~ : String,
  snapshot_path~ : String,
  command_log_path~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  event_log_path~ : String,
) -> Json {
  {
    "kind": "mooncode-session-snapshot",
    "protocol": "mooncode.v1",
    "component": "mooncode",
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "title": json_string(session, "title", default=""),
    "model": json_string(session, "model", default=""),
    "status": json_string(session, "status", default=""),
    "created_at": json_string(session, "created_at", default=""),
    "updated_at": json_string(session, "updated_at", default=""),
    "recorded_at": recorded_at,
    "snapshot_path": snapshot_path,
    "command_log_path": command_log_path,
    "runtime_command_log_path": runtime_command_log_path,
    "runtime_dispatch_log_path": runtime_dispatch_log_path,
    "event_log_path": event_log_path,
    "transcript": Json::array(json_array_items(session, "transcript")),
    "transcript_count": json_array_items(session, "transcript").length(),
    "commands": Json::array(commands),
    "command_count": commands.length(),
    "runtime_commands": Json::array(runtime_commands),
    "runtime_command_count": runtime_commands.length(),
    "runtime_dispatches": Json::array(runtime_dispatches),
    "runtime_dispatch_count": runtime_dispatches.length(),
    "runtime_dispatch_pending_count": runtime_dispatch_pending_count(
      runtime_commands,
      runtime_dispatches,
      lease_now=recorded_at,
    ),
    "events": Json::array(events),
    "event_count": events.length(),
    "tool_call_wire": tool_call_wire_contract_json(),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "last_runtime_handoff": summary_json_object_field_or_empty(
      session, "mooncode_last_runtime_handoff_manifest",
    ),
    "store_contract": {
      "shape": "typed session header plus transcript, commands.jsonl, runtime-commands.jsonl, runtime-dispatches.jsonl, events.jsonl, and projected MoonCode events",
      "append_only_inputs": [
        "commands.jsonl", "runtime-commands.jsonl", "runtime-dispatches.jsonl", "events.jsonl",
      ],
      "resume_modes": [
        "session_id", "session_snapshot", "command_log", "runtime_command_log", "runtime_dispatch_log",
        "event_log", "runtime_handoff",
      ],
      "openseek_reference": "agent_session + agent_session/store",
      "tool_call_wire": "tool-call and tool-result records in events.jsonl should satisfy the sibling mooncode-tool-call-wire-contract before runtime execution is trusted",
    },
    "event_normalization": {
      "owner": "mooncode",
      "function": "normalize_event_record",
      "id_policy": "preserve event.id when present; otherwise derive stable mooncode-event hash from lane, kind, title, created_at, and detail",
      "defaulted_fields": [
        "id", "lane", "kind", "title", "status", "created_at", "detail", "path",
        "diff", "command", "exit_code", "command_packet",
      ],
      "text_policy": "detail and diff are trimmed and capped before persistence or streaming",
      "consumer_note": "MoonClaw and standalone mooncode can resume this snapshot without Moondesk HTTP fallback logic for sparse runtime events.",
    },
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "session_store": "mooncode",
      "extractable_component": "mooncode",
    },
  }
}

///|
test "mooncode session snapshot records durable queue and event state" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "workspace_name": "Book",
    "workspace_root": "/tmp/book",
    "moonclaw_task_id": "task",
    "title": "Build tool",
    "transcript": [
      { "role": "user", "content": "create a tool" },
      { "role": "assistant", "content": "working" },
    ],
    "mooncode_last_command_packet": {
      "command_id": "cmd-1",
      "action": "prompt",
    },
  }
  let commands : Array[Json] = [{ "command_id": "cmd-1", "action": "prompt" }]
  let runtime_commands : Array[Json] = [
    {
      "command_id": "cmd-1",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "type": "prompt", "prompt": "create a tool" },
    },
  ]
  let snapshot = session_snapshot(
    session,
    [
      event_record(
        id="evt-1",
        lane="transcript",
        kind="assistant_delta",
        title="Assistant",
        status="done",
        created_at="2026-06-15T00:00:00Z",
        detail="working",
      ),
    ],
    commands,
    runtime_commands,
    [],
    recorded_at="2026-06-15T00:01:00Z",
    snapshot_path="/tmp/book/.moontown/mooncode-sessions/s1/session.json",
    command_log_path="/tmp/book/.moontown/mooncode-sessions/s1/commands.jsonl",
    runtime_command_log_path="/tmp/book/.moontown/mooncode-sessions/s1/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/book/.moontown/mooncode-sessions/s1/runtime-dispatches.jsonl",
    event_log_path="/tmp/book/.moontown/mooncode-sessions/s1/events.jsonl",
  )
  assert_eq(
    json_string(snapshot, "kind", default=""),
    "mooncode-session-snapshot",
  )
  assert_eq(summary_json_int(snapshot, "transcript_count", default=0), 2)
  assert_eq(summary_json_int(snapshot, "command_count", default=0), 1)
  assert_eq(summary_json_int(snapshot, "runtime_command_count", default=0), 1)
  assert_eq(
    summary_json_int(snapshot, "runtime_dispatch_pending_count", default=0),
    1,
  )
  assert_eq(summary_json_int(snapshot, "event_count", default=0), 1)
  let tool_call_wire = summary_json_object_field_or_empty(
    snapshot, "tool_call_wire",
  )
  assert_eq(
    json_string(tool_call_wire, "kind", default=""),
    "mooncode-tool-call-wire-contract",
  )
  assert_true(tool_call_wire.stringify().contains("moon_check"))
  let event_normalization = summary_json_object_field_or_empty(
    snapshot, "event_normalization",
  )
  assert_eq(
    json_string(event_normalization, "function", default=""),
    "normalize_event_record",
  )
  assert_eq(json_string(event_normalization, "owner", default=""), "mooncode")
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(snapshot, "last_command_packet"),
      "command_id",
      default="",
    ),
    "cmd-1",
  )
}
