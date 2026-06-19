///|
// MoonCode runtime consumer handoff and execution-plan response projection.

///|
pub fn runtime_consumer_handoff(
  session_id : String,
  runtime_replay : Json,
  runtime_claim : Json,
  native_ready : Bool,
) -> Json {
  let invalid_count = rq_json_int(
    runtime_claim,
    "invalid_command_count",
    default=0,
  )
  let claimable_count = rq_json_int(
    runtime_claim,
    "claimable_command_count",
    default=0,
  )
  let claimed_count = rq_json_int(
    runtime_claim,
    "claimed_command_count",
    default=0,
  )
  let tool_authorization_blocked_count = rq_json_int(
    runtime_claim,
    "tool_authorization_blocked_command_count",
    default=0,
  )
  let delivered_count = rq_json_int(
    runtime_claim,
    "delivered_command_count",
    default=0,
  )
  let pending_count = rq_json_int(
    runtime_replay,
    "pending_command_count",
    default=0,
  )
  let status = if invalid_count > 0 {
    "blocked-invalid-command"
  } else if tool_authorization_blocked_count > 0 {
    "blocked-tool-authorization"
  } else if claimable_count > 0 {
    "claim-ready"
  } else if claimed_count > 0 {
    "lease-held"
  } else if pending_count > 0 {
    "replay-ready"
  } else if delivered_count > 0 {
    "delivered"
  } else {
    "idle"
  }
  {
    "kind": "mooncode-runtime-consumer-handoff",
    "protocol": protocol_version(),
    "session_id": session_id,
    "status": status,
    "native_runtime_ready": native_ready,
    "ready_to_claim": invalid_count == 0 && claimable_count > 0,
    "ready_to_replay": rq_json_bool(
      runtime_replay,
      "replay_ready",
      default=false,
    ),
    "claimable_command_count": claimable_count,
    "claimed_command_count": claimed_count,
    "pending_command_count": pending_count,
    "invalid_command_count": invalid_count,
    "tool_authorization_blocked_command_count": tool_authorization_blocked_count,
    "next_action": runtime_consumer_next_action(status),
    "endpoints": {
      "runtime_claim": "/api/mooncode/sessions/\{session_id}/runtime-claim",
      "runtime_replay": "/api/mooncode/sessions/\{session_id}/runtime-replay",
      "runtime_events": "/api/mooncode/sessions/\{session_id}/runtime-events",
      "runtime_commands": "/api/mooncode/sessions/\{session_id}/runtime-commands",
      "stream": "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=<sequence>",
      "native_session_listing": "/v1/code/sessions?book_root=<path>&format=json",
      "native_commands": "/v1/code/sessions/\{session_id}/commands",
      "native_runtime_control": "/v1/code/sessions/\{session_id}/runtime-control?book_root=<path>",
      "native_eval_report": "/v1/code/sessions/\{session_id}/eval-report?book_root=<path>",
    },
    "required_loop": [
      "GET runtime-handoff or session-store", "GET runtime-claim", "POST runtime-claim with consumer_id before execution",
      "GET native runtime-control when using MoonClaw's native MoonCode endpoint",
      "execute claimed MoonCode command with MoonClaw/MoonCode tools", "POST runtime-events for streamed reasoning/tool/diff/test/artifact events",
      "POST runtime-replay with runtime-acknowledged or runtime-completed receipt",
      "POST eval-report when native tool/file-edit/patch-review/command-execution/package-output harness evidence is available",
    ],
    "safety_boundary": "Moondesk records queue, review, and display state; MoonClaw must enforce path, tool, shell, approval, test, and package policy before execution.",
  }
}

///|
pub fn runtime_consumer_execution_plan(
  session_id : String,
  runtime_replay : Json,
  runtime_claim : Json,
  native_ready : Bool,
) -> Json {
  let claimable = rq_json_array_items(runtime_claim, "claimable_commands")
  let claimed = rq_json_array_items(runtime_claim, "claimed_commands")
  let invalid = rq_json_array_items(runtime_claim, "invalid_commands")
  let tool_blocked = rq_json_array_items(
    runtime_claim, "tool_authorization_blocked_commands",
  )
  let order_blocked = rq_json_array_items(
    runtime_claim, "order_blocked_commands",
  )
  let pending = rq_json_array_items(runtime_replay, "pending_commands")
  let mut status = "idle"
  let mut operation = "wait"
  let mut item = Json::object({})
  if claimable.length() > 0 {
    status = "ready-to-claim"
    operation = "claim-command"
    item = claimable[0]
  } else if claimed.length() > 0 {
    status = "lease-held"
    operation = "execute-claimed-command"
    item = claimed[0]
  } else if invalid.length() > 0 {
    status = "blocked-invalid-command"
    operation = "repair-command-log"
    item = invalid[0]
  } else if tool_blocked.length() > 0 {
    status = "blocked-tool-authorization"
    operation = "request-tool-approval"
    item = tool_blocked[0]
  } else if order_blocked.length() > 0 {
    status = "blocked-by-prior-command"
    operation = "settle-prior-command"
    item = order_blocked[0]
  } else if pending.length() > 0 {
    status = "replay-ready"
    operation = "claim-command"
    item = pending[0]
  }
  let command = rq_json_object_field_or_empty(item, "runtime_command")
  let summary = rq_json_object_field_or_empty(command, "execution_summary")
  let native_body = rq_json_object_field_or_empty(
    command, "native_mooncode_body",
  )
  let command_id = rq_json_string(item, "command_id", default="")
  let action = rq_json_string(item, "action", default="")
  let required_events = rq_json_string_array_items(summary, "required_events")
  let required_outputs = rq_json_string_array_items(summary, "required_outputs")
  let event_sink = rq_json_string(
    summary,
    "event_sink",
    default="/api/mooncode/sessions/\{session_id}/runtime-events",
  )
  let ack_sink = rq_json_string(
    summary,
    "ack_sink",
    default="/api/mooncode/sessions/\{session_id}/runtime-replay",
  )
  {
    "kind": "mooncode-runtime-consumer-execution-plan",
    "protocol": protocol_version(),
    "session_id": session_id,
    "status": status,
    "operation": operation,
    "native_runtime_ready": native_ready,
    "ready_to_claim": status == "ready-to-claim",
    "ready_to_execute": status == "ready-to-claim" || status == "lease-held",
    "ready_to_ack": status == "lease-held",
    "command_id": command_id,
    "action": action,
    "target": rq_json_string(item, "target", default=""),
    "context_path": rq_json_string(item, "context_path", default=""),
    "claim_status": rq_json_string(item, "claim_status", default=""),
    "receipt_status": rq_json_string(item, "receipt_status", default=""),
    "blocked_by_command_id": rq_json_string(
      item,
      "blocked_by_command_id",
      default="",
    ),
    "blocked_by_status": rq_json_string(item, "blocked_by_status", default=""),
    "tool_authorization_state": rq_json_string(
      item,
      "tool_authorization_state",
      default="",
    ),
    "runtime_may_execute_tools": rq_json_bool(
      item,
      "runtime_may_execute_tools",
      default=false,
    ),
    "claim_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
    "ack_endpoint": ack_sink,
    "runtime_event_ingest_endpoint": event_sink,
    "stream_endpoint": "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=<sequence>",
    "native_session_listing_endpoint": "/v1/code/sessions?book_root=<path>&format=json",
    "native_command_endpoint": "/v1/code/sessions/\{session_id}/commands",
    "native_runtime_control_endpoint": "/v1/code/sessions/\{session_id}/runtime-control?book_root=<path>",
    "native_eval_report_endpoint": "/v1/code/sessions/\{session_id}/eval-report?book_root=<path>",
    "claim_request_template": {
      "consumer_id": "moonclaw",
      "lease_seconds": 300,
      "command_id": command_id,
    },
    "ack_request_template": {
      "consumer_id": "moonclaw",
      "command_id": command_id,
      "status": "runtime-completed",
      "events": [],
    },
    "failure_ack_template": {
      "consumer_id": "moonclaw",
      "command_id": command_id,
      "status": "failed",
      "detail": "execution failed",
      "events": [],
    },
    "mooncode_command": rq_json_object_field_or_empty(
      command, "mooncode_command",
    ),
    "native_mooncode_body": native_body,
    "execution_summary": summary,
    "execution_checklist": rq_json_array_items(summary, "execution_checklist"),
    "required_events": string_array_json(required_events),
    "required_event_count": required_events.length(),
    "required_outputs": string_array_json(required_outputs),
    "required_output_count": required_outputs.length(),
    "completion_rule": rq_json_string(summary, "completion_rule", default=""),
    "next_step": runtime_consumer_execution_next_step(
      status, operation, command_id, action,
    ),
    "safety_boundary": "This is an execution plan, not execution. MoonClaw must enforce the embedded tool/path/approval/test contracts before running tools, then stream events and acknowledge through the listed endpoints.",
    "owner": runtime_owner_record(),
  }
}

///|
fn runtime_consumer_execution_next_step(
  status : String,
  operation : String,
  command_id : String,
  action : String,
) -> String {
  let base = match status {
    "ready-to-claim" =>
      "POST runtime-claim for command `\{command_id}`, execute `\{action}` through the native MoonCode tool loop, stream required events, then POST runtime-replay."
    "lease-held" =>
      "Resume or finish the leased command `\{command_id}`; emit any missing runtime events, then acknowledge completion or failure through runtime-replay."
    "blocked-invalid-command" =>
      "Repair or skip the invalid earlier runtime command before later commands can run."
    "blocked-tool-authorization" =>
      "Resolve tool approval state before MoonClaw executes this command."
    "blocked-by-prior-command" =>
      "Settle the prior blocking runtime command before this command can run."
    "replay-ready" =>
      "Claim the replay-ready command before execution so the lease and acknowledgement trail is durable."
    _ =>
      "No runtime command is currently ready; wait for a prompt, steer, or review command."
  }
  "\{base} Operation: \{operation}."
}

///|
fn runtime_consumer_next_action(status : String) -> String {
  match status {
    "blocked-invalid-command" =>
      "repair or skip invalid runtime command records before executing the queue"
    "blocked-tool-authorization" =>
      "resolve pending or rejected tool approvals before claiming runtime commands"
    "claim-ready" =>
      "POST runtime-claim with a stable consumer_id, execute the claimed command, then acknowledge through runtime-replay"
    "lease-held" =>
      "resume the active consumer lease or use force=true only for an operator-approved stale-lease recovery"
    "replay-ready" =>
      "consume pending_mooncode_jsonl from runtime-replay if single-consumer leasing is not required"
    "delivered" =>
      "wait for new runtime commands or append runtime events/eval evidence for completed work"
    _ => "wait for a prompt, steer, cancel, test, package, or review command"
  }
}
