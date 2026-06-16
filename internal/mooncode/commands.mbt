///|
pub fn command_packet(
  session : Json,
  payload : Json,
  action : String,
  message : String,
  created_at : String,
  context_path : String,
  command_id~ : String,
) -> Json {
  let workspace_id = json_string(session, "workspace_id", default="")
  let task_id = json_string(session, "moonclaw_task_id", default="")
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "command_id": command_id,
    "action": action,
    "dispatch": command_dispatch(action),
    "approval": command_approval(action),
    "created_at": created_at,
    "session_id": json_string(session, "id", default=""),
    "workspace_id": workspace_id,
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "task_id": task_id,
    "context_path": context_path,
    "target": if context_path == "" {
      "moonbook"
    } else {
      context_path
    },
    "message": message,
    "web_search": json_bool(payload, "web_search", default=false),
    "force_preflight": json_bool(payload, "force_preflight", default=false),
    "expected_lanes": string_array_json(command_expected_lanes(action)),
    "tool_hints": string_array_json(command_tool_hints(action)),
    "output_contract": {
      "owner": "moonbook",
      "roots": [
        "tools/", "apps/", "book/site/generated/", "portable/app-tool/", "wiki/reviews/",
        "raw/analysis-runs/",
      ],
      "review_required": command_approval(action) == "operator",
    },
    "boundary": {
      "ui_owner": "moondesk",
      "runtime_owner": "moonclaw",
      "artifact_owner": "moonbook",
      "extractable_component": "mooncode",
    },
  }
}

///|
pub fn command_event(
  action~ : String,
  status~ : String,
  detail~ : String,
  created_at~ : String,
  path~ : String,
  command_packet~ : Json,
  event_id~ : String,
) -> Json {
  event_record(
    id=event_id,
    lane=command_lane(action),
    kind="command.\{action}",
    title=command_title(action, status),
    status~,
    created_at~,
    detail~,
    path~,
    command=action,
    command_packet~,
  )
}

///|
pub fn command_runtime_message(
  message : String,
  command_packet : Json,
) -> String {
  message +
  "\n\nMoonCode command packet (JSON, protocol mooncode.v1):\n```json\n" +
  command_packet.stringify(indent=2) +
  "\n```\nUse this packet as the durable command contract. Keep all edits inside the selected MoonBook workspace, emit tool/diff/test/artifact/review events when available, and preserve the output contract."
}

///|
pub fn openseek_serve_command(message : String, command_packet : Json) -> Json {
  let dispatch = json_string(command_packet, "dispatch", default="command")
  let action = json_string(command_packet, "action", default="prompt")
  match dispatch {
    "cancel" => { "command": "cancel" }
    "steer" =>
      {
        "command": "steer",
        "text": command_runtime_message(message, command_packet),
      }
    "prompt" =>
      {
        "command": "prompt",
        "text": command_runtime_message(message, command_packet),
      }
    _ =>
      {
        "command": "prompt",
        "text": "MoonCode action `\{action}` requested.\n\n" +
        command_runtime_message(message, command_packet),
      }
  }
}

///|
pub fn runtime_command_record(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let serve_command = openseek_serve_command(message, command_packet)
  let session_id = json_string(session, "id", default="")
  let tool_authorization = command_tool_authorization_snapshot(
    session, command_packet,
  )
  let native_body = native_command_body(
    session, payload, message, command_packet,
  )
  {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": json_string(command_packet, "command_id", default=""),
    "action": json_string(command_packet, "action", default="prompt"),
    "dispatch": json_string(command_packet, "dispatch", default="prompt"),
    "approval": json_string(command_packet, "approval", default="none"),
    "serve_command": json_string(serve_command, "command", default="prompt"),
    "text": json_string(serve_command, "text", default=""),
    "created_at": json_string(command_packet, "created_at", default=""),
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "workspace_root": json_string(session, "workspace_root", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "context_path": json_string(command_packet, "context_path", default=""),
    "target": json_string(command_packet, "target", default="moonbook"),
    "openseek_wire_command": serve_command,
    "openseek_wire_valid": serve_wire_valid(serve_command),
    "native_mooncode_endpoint": "/v1/mooncode/sessions/\{session_id}/commands",
    "tool_authorization": tool_authorization,
    "native_mooncode_body": native_body,
    "execution_summary": native_command_execution_summary(
      command_packet, native_body,
    ),
    "command_packet": command_packet,
    "ordering_rule": "OpenSeek-compatible serve commands and native MoonCode command bodies share the same command_id and append order.",
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "extractable_component": "mooncode",
    },
  }
}

///|
pub fn native_command_body(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let action = json_string(command_packet, "action", default="prompt")
  let context_path = json_string(command_packet, "context_path", default="")
  let tool_authorization = command_tool_authorization_snapshot(
    session, command_packet,
  )
  {
    "protocol": "mooncode.v1",
    "command": action,
    "native_dispatch_mode": "queue-only",
    "text": message,
    "session_id": json_string(session, "id", default=""),
    "book_root": json_string(
      session,
      "workspace_root",
      default=json_string(session, "cwd", default=""),
    ),
    "context_path": context_path,
    "payload": payload,
    "packet": command_packet,
    "execution_plan": native_command_execution_plan(
      action, context_path, payload, command_packet,
    ),
    "tool_authorization": tool_authorization,
    "tool_contract": native_command_tool_contract(action),
    "result_contract": native_command_result_contract(action),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "extractable_component": "mooncode",
    },
  }
}

///|
pub fn command_tool_authorization_snapshot(
  session : Json,
  command_packet : Json,
) -> Json {
  let action = json_string(command_packet, "action", default="prompt")
  let session_id = json_string(
    session,
    "id",
    default=json_string(command_packet, "session_id", default=""),
  )
  let manifest = command_json_object_field_or_empty(
    session, "mooncode_last_tool_approvals_manifest",
  )
  let status = json_string(manifest, "status", default="empty")
  let pending = command_json_int(manifest, "pending_approval_count", default=0)
  let approved = command_json_int(
    manifest,
    "approved_approval_count",
    default=0,
  )
  let rejected = command_json_int(
    manifest,
    "rejected_approval_count",
    default=0,
  )
  let authorization_needed = command_uses_authorized_tools(action)
  let enforcement_state = if rejected > 0 {
    "blocked-by-rejected-tool"
  } else if pending > 0 {
    "requires-approval"
  } else if !authorization_needed {
    "not-required"
  } else if status == "empty" {
    "no-gated-tools-seen"
  } else {
    "authorized"
  }
  {
    "kind": "mooncode-tool-authorization-snapshot",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "command_id": json_string(command_packet, "command_id", default=""),
    "action": action,
    "authorization_needed": authorization_needed,
    "enforcement_state": enforcement_state,
    "runtime_may_execute": rejected == 0 && pending == 0,
    "runtime_must_enforce": authorization_needed,
    "tool_authorization_endpoint": "/api/mooncode/sessions/\{session_id}/tool-authorization",
    "manifest_status": status,
    "manifest_path": json_string(manifest, "manifest_path", default=""),
    "approval_count": command_json_int(manifest, "approval_count", default=0),
    "pending_approval_count": pending,
    "approved_approval_count": approved,
    "rejected_approval_count": rejected,
    "approvals": command_json_array_field_or_empty(manifest, "approvals"),
    "current_tool_approvals": manifest,
    "rule": "MoonClaw or standalone MoonCode must request/verify authorization before executing gated tools; pending or rejected approval rows block execution unless the runtime receives a later approving snapshot.",
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "review": "moonbook",
      "extractable_component": "mooncode",
    },
  }
}

///|
fn command_uses_authorized_tools(action : String) -> Bool {
  let tools = native_command_tool_sequence(action)
  command_string_array_contains(tools, "edit") ||
  command_string_array_contains(tools, "write") ||
  command_string_array_contains(tools, "shell") ||
  command_string_array_contains(tools, "moon_check") ||
  command_string_array_contains(tools, "apply_patch") ||
  command_string_array_contains(tools, "package_app_tool")
}

///|
pub fn native_command_execution_plan(
  action : String,
  context_path : String,
  payload : Json,
  command_packet : Json,
) -> Json {
  {
    "kind": "mooncode-native-command-execution-plan",
    "protocol": "mooncode.v1",
    "action": action,
    "dispatch": json_string(command_packet, "dispatch", default="command"),
    "approval": json_string(command_packet, "approval", default="none"),
    "target": if context_path == "" {
      "moonbook"
    } else {
      context_path
    },
    "context_path": context_path,
    "tool_sequence": string_array_json(native_command_tool_sequence(action)),
    "tool_policies": Json::array(
      native_command_tool_policies(action, context_path),
    ),
    "expected_events": string_array_json(native_command_expected_events(action)),
    "required_outputs": string_array_json(
      native_command_required_outputs(action),
    ),
    "recommended_commands": string_array_json(
      native_command_recommended_commands(action, context_path),
    ),
    "package_kind": trimmed_or(
      json_string(payload, "package_kind", default=""),
      fallback=native_command_default_package_kind(action),
    ),
    "review_required": json_string(command_packet, "approval", default="none") ==
    "operator",
    "path_policy": {
      "book_root": json_string(command_packet, "workspace_root", default=""),
      "context_path": context_path,
      "rule": "All reads, edits, shell commands, tests, and generated artifacts must stay inside the selected MoonBook unless an operator approves a broader workspace explicitly.",
    },
  }
}

///|
pub fn native_command_tool_sequence(action : String) -> Array[String] {
  match action {
    "run_tests" => ["read", "moon_check", "shell", "finish"]
    "run_eval" => ["read", "moon_check", "shell", "finish"]
    "package" => ["read", "moon_check", "shell", "package_app_tool", "finish"]
    "commit" => ["read", "moon_check", "shell", "finish"]
    "accept" => ["read", "package_app_tool", "finish"]
    "reject" => ["read", "finish"]
    "apply_patch" | "revert_patch" =>
      ["read", "apply_patch", "moon_check", "finish"]
    "approve_tool" | "reject_tool" => ["finish"]
    "prompt" | "steer" => ["read", "edit", "write", "moon_check", "finish"]
    "cancel" => ["finish"]
    _ => ["finish"]
  }
}

///|
pub fn native_command_expected_events(action : String) -> Array[String] {
  match action {
    "run_tests" => ["tool_call", "tool_result", "test_result", "agent_finished"]
    "run_eval" =>
      [
        "tool_call", "tool_result", "test_result", "eval_report.manifest", "agent_finished",
      ]
    "package" =>
      [
        "tool_call", "tool_result", "artifact", "package.manifest", "package.index",
        "package_verified", "agent_finished",
      ]
    "commit" => ["tool_call", "tool_result", "commit_created", "agent_finished"]
    "apply_patch" =>
      ["tool_call", "diff", "patch_applied", "test_result", "agent_finished"]
    "revert_patch" =>
      ["tool_call", "diff", "patch_reverted", "test_result", "agent_finished"]
    "accept" | "reject" => ["review.receipt", "artifact", "agent_finished"]
    "approve_tool" | "reject_tool" =>
      ["tool_authorization", "review.receipt", "agent_finished"]
    "prompt" | "steer" =>
      [
        "assistant_delta", "reasoning_delta", "tool_call", "tool_result", "diff",
        "test_result", "artifact", "agent_finished",
      ]
    "cancel" => ["agent_aborted", "agent_finished"]
    _ => ["runtime_update", "agent_finished"]
  }
}

///|
pub fn native_command_required_outputs(action : String) -> Array[String] {
  match action {
    "run_tests" => ["test command", "exit code", "test_result event"]
    "run_eval" =>
      [
        "tool_harness result", "file_edit result", "native eval report", "eval_report.manifest event",
      ]
    "package" =>
      [
        "source inventory", "package manifest", "package index", "artifact event",
        "package_verified proof event",
      ]
    "commit" =>
      ["git status before commit", "commit SHA", "commit_created proof event"]
    "accept" => ["review receipt", "accepted MoonBook output note"]
    "reject" => ["review receipt", "rejection note"]
    "apply_patch" =>
      [
        "diff event", "changed paths", "patch_applied proof event", "selected-hunk proof metadata",
        "post-change verification metadata",
      ]
    "revert_patch" =>
      [
        "diff event", "changed paths", "patch_reverted proof event", "selected-hunk proof metadata",
        "post-change verification metadata",
      ]
    "approve_tool" | "reject_tool" => ["tool authorization decision"]
    "prompt" | "steer" =>
      ["transcript progress", "tool/diff/test/artifact events as applicable"]
    "cancel" => ["terminal runtime event"]
    _ => ["runtime update"]
  }
}

///|
pub fn native_command_recommended_commands(
  action : String,
  context_path : String,
) -> Array[String] {
  match action {
    "run_tests" =>
      if context_path.has_suffix(".mbt") || context_path.contains("moon.pkg") {
        ["moon check", "moon test"]
      } else {
        ["moon check", "moon test", "package-specific test command if present"]
      }
    "run_eval" =>
      [
        "run tool_harness eval fixtures", "run file_edit eval fixtures", "POST /api/mooncode/sessions/<id>/eval-report",
      ]
    "package" => ["moon check", "moon test", "build/package selected artifact"]
    "commit" =>
      [
        "git status --short", "git diff --check", "git commit with reviewed message",
      ]
    "apply_patch" | "revert_patch" => ["moon check", "moon test"]
    _ => []
  }
}

///|
pub fn native_command_tool_policies(
  action : String,
  context_path : String,
) -> Array[Json] {
  let policies : Array[Json] = []
  for tool in native_command_tool_sequence(action) {
    policies.push(native_command_tool_policy(tool, action, context_path))
  }
  policies
}

///|
pub fn native_command_tool_policy(
  tool : String,
  action : String,
  context_path : String,
) -> Json {
  match tool {
    "read" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="auto",
        mutates_files=false,
        required_inputs=["path"],
        proof_events=["tool_call", "tool_result"],
        guardrails=[
          "resolve path relative to selected MoonBook root", "reject parent traversal and absolute paths outside the book",
          "return bounded content with path and byte metadata",
        ],
      )
    "edit" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="review",
        mutates_files=true,
        required_inputs=["path", "old", "new"],
        proof_events=["tool_call", "file_change", "diff", "tool_result"],
        guardrails=[
          "require recent bounded read context before replacing text", "reject empty old text or stale old text without applying partial edits",
          "run MoonBit manifest guardrails before editing moon.mod or moon.pkg",
          "emit diff evidence before review or packaging gates can pass",
        ],
      )
    "write" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="review",
        mutates_files=true,
        required_inputs=["path", "content"],
        proof_events=["tool_call", "file_change", "diff", "tool_result"],
        guardrails=[
          "write only inside executable MoonBook roots or reviewed wiki paths", "reject new moon.mod.json files for MoonBit code",
          "reject JSON-shaped moon.mod or moon.pkg content", "emit full-path diff evidence for operator review",
        ],
      )
    "shell" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="policy",
        mutates_files=false,
        required_inputs=["cmd"],
        proof_events=["tool_call", "tool_result", "runtime_update"],
        guardrails=[
          "accept argv arrays instead of raw shell strings", "run under selected MoonBook root or a book-relative cwd",
          "require bounded timeout and capped output", "destructive, networked, or broad workspace commands require operator policy approval",
        ],
      )
    "moon_check" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="auto",
        mutates_files=false,
        required_inputs=[],
        proof_events=["tool_call", "tool_result", "test_result"],
        guardrails=[
          "prefer moon check before broad moon test while iterating", "capture command, exit code, target, and bounded diagnostics",
          "publish test_result evidence for action-plan and acceptance gates",
        ],
      )
    "package_app_tool" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="operator",
        mutates_files=true,
        required_inputs=["artifact_root"],
        proof_events=[
          "tool_call", "artifact", "package.manifest", "package.index", "package_verified",
        ],
        guardrails=[
          "package only accepted or runtime-proven code artifacts", "bind package manifest to source paths inside the selected MoonBook",
          "write package index under portable/app-tool or another MoonBook-owned output root",
        ],
      )
    "finish" =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="auto",
        mutates_files=false,
        required_inputs=["summary"],
        proof_events=["agent_finished"],
        guardrails=[
          "summarize changed paths, test evidence, artifacts, and residual risks",
          "do not claim accepted output without review, test, or package evidence",
        ],
      )
    _ =>
      native_command_tool_policy_entry(
        tool,
        action,
        context_path,
        approval="unknown",
        mutates_files=false,
        required_inputs=[],
        proof_events=["tool_result"],
        guardrails=["runtime must reject unknown tools before execution"],
      )
  }
}

///|
fn native_command_tool_policy_entry(
  tool : String,
  action : String,
  context_path : String,
  approval~ : String,
  mutates_files~ : Bool,
  required_inputs~ : Array[String],
  proof_events~ : Array[String],
  guardrails~ : Array[String],
) -> Json {
  {
    "tool": tool,
    "action": action,
    "context_path": context_path,
    "approval": approval,
    "mutates_files": mutates_files,
    "required_inputs": string_array_json(required_inputs),
    "proof_events": string_array_json(proof_events),
    "guardrails": string_array_json(guardrails),
    "runtime_owner": "moonclaw-or-standalone-mooncode",
    "ui_owner": "moondesk",
    "artifact_owner": "moonbook",
  }
}

///|
pub fn native_command_default_package_kind(action : String) -> String {
  if action == "package" {
    "app-tool"
  } else {
    ""
  }
}

///|
pub fn native_command_tool_contract(action : String) -> Json {
  {
    "kind": "mooncode-native-tool-contract",
    "allowed_tools": string_array_json(native_command_tool_sequence(action)),
    "tool_policies": Json::array(native_command_tool_policies(action, "")),
    "mutating_tools_require_review": true,
    "shell_requires_bounded_timeout": true,
    "moon_check_required_for_code_changes": true,
    "approval_boundary": "Moondesk records approvals; MoonClaw or standalone mooncode must enforce them before read/edit/write/shell/moon_check/package tools execute.",
  }
}

///|
pub fn native_command_result_contract(action : String) -> Json {
  let required_events = native_command_expected_events(action)
  let required_outputs = native_command_required_outputs(action)
  let event_sink = "POST /api/mooncode/sessions/<session-id>/runtime-events"
  let eval_report_sink = if action == "run_eval" {
    "POST /api/mooncode/sessions/<session-id>/eval-report"
  } else {
    ""
  }
  let ack_sink = "POST /api/mooncode/sessions/<session-id>/runtime-replay"
  {
    "kind": "mooncode-native-result-contract",
    "required_events": string_array_json(required_events),
    "required_outputs": string_array_json(required_outputs),
    "event_sink": event_sink,
    "eval_report_sink": eval_report_sink,
    "ack_sink": ack_sink,
    "execution_checklist": Json::array(
      native_command_execution_checklist(
        action, required_events, required_outputs, event_sink, eval_report_sink,
        ack_sink,
      ),
    ),
    "completion_rule": "A runtime consumer should append typed progress events, then acknowledge the command as runtime-completed or failed through runtime replay.",
  }
}

///|
pub fn native_command_execution_checklist(
  action : String,
  required_events : Array[String],
  required_outputs : Array[String],
  event_sink : String,
  eval_report_sink : String,
  ack_sink : String,
) -> Array[Json] {
  let items : Array[Json] = []
  let mut index = 1
  let push_step = fn(
    id : String,
    title : String,
    owner : String,
    required_event : String,
    required_output : String,
    endpoint : String,
    blocking : Bool,
  ) {
    items.push({
      "index": index,
      "id": id,
      "title": title,
      "owner": owner,
      "required_event": required_event,
      "required_output": required_output,
      "endpoint": endpoint,
      "blocking": blocking,
    })
    index += 1
  }
  push_step(
    "claim-command", "Claim the runtime command before execution", "moonclaw-or-standalone-mooncode",
    "runtime-claimed receipt", "claim id", "POST /api/mooncode/sessions/<session-id>/runtime-claim",
    true,
  )
  for tool in native_command_tool_sequence(action) {
    push_step(
      "run-tool-\{tool}",
      "Run tool: \{tool}",
      "moonclaw-or-standalone-mooncode",
      "",
      "",
      "",
      true,
    )
  }
  for event in required_events {
    push_step(
      "emit-event-\{event}",
      "Emit event: \{event}",
      "moonclaw-or-standalone-mooncode",
      event,
      "",
      event_sink,
      true,
    )
  }
  for output in required_outputs {
    push_step(
      "produce-output-\{index}",
      "Produce output: \{output}",
      "moonclaw-or-standalone-mooncode",
      "",
      output,
      "",
      true,
    )
  }
  if eval_report_sink != "" {
    push_step(
      "publish-native-eval-report", "Publish native eval report", "moonclaw-or-standalone-mooncode",
      "native eval report", "eval-report manifest", eval_report_sink, true,
    )
  }
  push_step(
    "ack-command", "Acknowledge command completion", "moonclaw-or-standalone-mooncode",
    "runtime-completed or runtime-failed receipt", "ack receipt", ack_sink, true,
  )
  items
}

///|
pub fn native_command_execution_summary(
  command_packet : Json,
  native_body : Json,
) -> Json {
  let plan = command_json_object_field_or_empty(native_body, "execution_plan")
  let tool_contract = command_json_object_field_or_empty(
    native_body, "tool_contract",
  )
  let result_contract = command_json_object_field_or_empty(
    native_body, "result_contract",
  )
  let tool_authorization = command_json_object_field_or_empty(
    native_body, "tool_authorization",
  )
  let path_policy = command_json_object_field_or_empty(plan, "path_policy")
  {
    "kind": "mooncode-runtime-execution-summary",
    "protocol": "mooncode.v1",
    "command_id": json_string(command_packet, "command_id", default=""),
    "action": json_string(
      plan,
      "action",
      default=json_string(command_packet, "action", default="prompt"),
    ),
    "dispatch": json_string(
      plan,
      "dispatch",
      default=json_string(command_packet, "dispatch", default="prompt"),
    ),
    "approval": json_string(
      plan,
      "approval",
      default=json_string(command_packet, "approval", default="none"),
    ),
    "target": json_string(
      plan,
      "target",
      default=json_string(command_packet, "target", default="moonbook"),
    ),
    "context_path": json_string(
      plan,
      "context_path",
      default=json_string(command_packet, "context_path", default=""),
    ),
    "tool_sequence": string_array_json(
      command_json_string_array_items(plan, "tool_sequence"),
    ),
    "tool_policy_count": command_json_array_length(plan, "tool_policies"),
    "tool_policies": command_json_array_field_or_empty(plan, "tool_policies"),
    "allowed_tools": string_array_json(
      command_json_string_array_items(tool_contract, "allowed_tools"),
    ),
    "expected_events": string_array_json(
      command_json_string_array_items(plan, "expected_events"),
    ),
    "required_events": string_array_json(
      command_json_string_array_items(result_contract, "required_events"),
    ),
    "required_outputs": string_array_json(
      command_json_string_array_items(plan, "required_outputs"),
    ),
    "execution_checklist": command_json_array_field_or_empty(
      result_contract, "execution_checklist",
    ),
    "checklist_count": command_json_array_length(
      result_contract, "execution_checklist",
    ),
    "recommended_commands": string_array_json(
      command_json_string_array_items(plan, "recommended_commands"),
    ),
    "package_kind": json_string(plan, "package_kind", default=""),
    "review_required": json_bool(plan, "review_required", default=false),
    "event_sink": json_string(result_contract, "event_sink", default=""),
    "ack_sink": json_string(result_contract, "ack_sink", default=""),
    "completion_rule": json_string(
      result_contract,
      "completion_rule",
      default="",
    ),
    "tool_authorization_state": json_string(
      tool_authorization,
      "enforcement_state",
      default="",
    ),
    "tool_authorization_needed": json_bool(
      tool_authorization,
      "authorization_needed",
      default=false,
    ),
    "runtime_may_execute_tools": json_bool(
      tool_authorization,
      "runtime_may_execute",
      default=true,
    ),
    "pending_tool_approval_count": command_json_int(
      tool_authorization,
      "pending_approval_count",
      default=0,
    ),
    "rejected_tool_approval_count": command_json_int(
      tool_authorization,
      "rejected_approval_count",
      default=0,
    ),
    "approval_boundary": json_string(
      tool_contract,
      "approval_boundary",
      default="",
    ),
    "path_rule": json_string(path_policy, "rule", default=""),
  }
}

///|
fn trimmed_or(value : String, fallback~ : String) -> String {
  let trimmed = value.trim().to_owned()
  if trimmed == "" {
    fallback
  } else {
    trimmed
  }
}

///|
fn command_json_object_field_or_empty(json : Json, key : String) -> Json {
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
fn command_json_string_array_items(json : Json, key : String) -> Array[String] {
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

///|
fn command_json_array_field_or_empty(json : Json, key : String) -> Json {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) => Json::array(values)
        _ => Json::array([])
      }
    _ => Json::array([])
  }
}

///|
fn command_json_array_length(json : Json, key : String) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) => values.length()
        _ => 0
      }
    _ => 0
  }
}

///|
fn command_json_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
fn command_string_array_contains(
  items : Array[String],
  needle : String,
) -> Bool {
  for item in items {
    if item == needle {
      return true
    }
  }
  false
}

///|
fn command_checklist_contains_id(checklist : Array[Json], id : String) -> Bool {
  for step in checklist {
    if json_string(step, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn command_checklist_contains_id_prefix(
  checklist : Array[Json],
  prefix : String,
) -> Bool {
  for step in checklist {
    if json_string(step, "id", default="").has_prefix(prefix) {
      return true
    }
  }
  false
}

///|
fn command_policy_has_guardrail(
  policies : Array[Json],
  tool : String,
  phrase : String,
) -> Bool {
  for policy in policies {
    if json_string(policy, "tool", default="") == tool {
      for guardrail in command_json_string_array_items(policy, "guardrails") {
        if guardrail.contains(phrase) {
          return true
        }
      }
    }
  }
  false
}

///|
test "mooncode command metadata captures runtime dispatch and approval" {
  assert_true(command_is_supported("prompt"))
  assert_true(command_is_supported("run_eval"))
  assert_true(command_is_supported("commit"))
  assert_false(command_is_supported("deploy_global"))
  assert_eq(command_dispatch("prompt"), "prompt")
  assert_eq(command_dispatch("steer"), "steer")
  assert_eq(command_dispatch("cancel"), "cancel")
  assert_eq(command_dispatch("package"), "command")
  assert_eq(command_dispatch("commit"), "command")
  assert_eq(command_approval("package"), "operator")
  assert_eq(command_approval("commit"), "operator")
  assert_eq(command_approval("run_eval"), "auto")
  assert_eq(command_approval("prompt"), "user")
}

///|
test "mooncode command defaults are book coding oriented" {
  let payload : Json = {
    "action": " run_tests ",
    "context_path": "tools/demo/main.mbt",
  }
  assert_eq(command_action(payload), "run_tests")
  assert_eq(command_context_path(payload), "tools/demo/main.mbt")
  assert_eq(command_target_label(payload), "`tools/demo/main.mbt`")
  assert_true(
    command_message("run_tests", payload).contains(
      "Run the relevant tests or build checks",
    ),
  )
  let explicit : Json = { "message": "Use the local harness." }
  assert_eq(command_message("prompt", explicit), "Use the local harness.")
}

///|
test "mooncode command packet and runtime feed preserve execution boundary" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "moonclaw_task_id": "task-demo",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "package_kind": "miniapp",
    "web_search": false,
  }
  let packet = command_packet(
    session,
    payload,
    "package",
    "Package it",
    "2026-06-14T00:00:00Z",
    "tools/demo/main.mbt",
    command_id="cmd-package",
  )
  assert_eq(json_string(packet, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(packet, "approval", default=""), "operator")
  assert_true(
    command_json_string_array_items(packet, "tool_hints").contains(
      "package_app_tool",
    ),
  )
  assert_true(
    command_runtime_message("Package it", packet).contains(
      "MoonCode command packet",
    ),
  )
  let command = runtime_command_record(session, payload, "Package it", packet)
  assert_true(json_bool(command, "openseek_wire_valid", default=false))
  let summary = command_json_object_field_or_empty(command, "execution_summary")
  assert_eq(
    json_string(summary, "kind", default=""),
    "mooncode-runtime-execution-summary",
  )
  assert_eq(json_string(summary, "action", default=""), "package")
  assert_eq(json_string(summary, "package_kind", default=""), "miniapp")
  assert_true(
    command_json_string_array_items(summary, "tool_sequence").contains(
      "package_app_tool",
    ),
  )
  assert_true(command_json_int(summary, "tool_policy_count", default=0) > 0)
  assert_true(
    command_policy_has_guardrail(
      json_array_items(summary, "tool_policies"),
      "package_app_tool",
      "runtime-proven",
    ),
  )
  let native = command_json_object_field_or_empty(
    command, "native_mooncode_body",
  )
  let plan = command_json_object_field_or_empty(native, "execution_plan")
  assert_true(json_bool(plan, "review_required", default=false))
  assert_true(
    command_policy_has_guardrail(
      json_array_items(plan, "tool_policies"),
      "moon_check",
      "bounded diagnostics",
    ),
  )
  let result_contract = command_json_object_field_or_empty(
    native, "result_contract",
  )
  assert_true(
    json_string(result_contract, "ack_sink", default="").contains(
      "/runtime-replay",
    ),
  )
  let checklist = json_array_items(result_contract, "execution_checklist")
  assert_true(checklist.length() >= 4)
  assert_eq(json_string(checklist[0], "id", default=""), "claim-command")
  assert_true(
    command_checklist_contains_id_prefix(checklist, "emit-event-package.index"),
  )
  assert_true(command_checklist_contains_id(checklist, "ack-command"))
}

///|
test "mooncode command queue response owns queue surface" {
  let command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "command_id": "cmd-1",
    "action": "prompt",
  }
  let response = command_queue_response(
    "session-demo",
    [command],
    workspace_id="book-demo",
    workspace_name="Demo Book",
    task_id="task-demo",
    command_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/commands.jsonl",
  )
  assert_eq(json_string(response, "kind", default=""), "mooncode-command-queue")
  assert_eq(json_string(response, "session_id", default=""), "session-demo")
  assert_eq(
    json_string(response, "command_log_path", default=""),
    "/tmp/book/.moontown/mooncode-sessions/session-demo/commands.jsonl",
  )
  assert_eq(command_json_int(response, "command_count", default=0), 1)
  assert_eq(json_array_items(response, "commands").length(), 1)
  assert_eq(
    json_string(
      command_json_object_field_or_empty(response, "owner"),
      "extractable_component",
      default="",
    ),
    "mooncode",
  )
  let aggregate = command_queue_result_response(
    "session-demo",
    [command],
    {
      "id": "session-demo",
      "workspace_id": "book-demo",
      "workspace_name": "Demo Book",
      "moonclaw_task_id": "task-demo",
    },
    command_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/commands.jsonl",
  )
  assert_eq(json_string(aggregate, "workspace_id", default=""), "book-demo")
  assert_eq(json_string(aggregate, "workspace_name", default=""), "Demo Book")
  assert_eq(json_string(aggregate, "task_id", default=""), "task-demo")
}

///|
test "mooncode runtime commands carry tool authorization snapshots" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "mooncode_last_tool_approvals_manifest": {
      "kind": "mooncode-tool-approvals",
      "protocol": "mooncode.v1",
      "status": "pending",
      "manifest_path": "wiki/reviews/mooncode/agent-demo/tool-approvals.json",
      "approval_count": 1,
      "pending_approval_count": 1,
      "approved_approval_count": 0,
      "rejected_approval_count": 0,
      "approvals": [
        {
          "target": "moon test",
          "tool_name": "shell",
          "approval_state": "pending",
        },
      ],
    },
  }
  let payload : Json = {
    "action": "run_tests",
    "context_path": "tools/demo/main.mbt",
  }
  let packet = command_packet(
    session,
    payload,
    "run_tests",
    "Run tests",
    "2026-06-15T00:00:00Z",
    "tools/demo/main.mbt",
    command_id="cmd-tests",
  )
  let command = runtime_command_record(session, payload, "Run tests", packet)
  let auth = command_json_object_field_or_empty(command, "tool_authorization")
  assert_eq(
    json_string(auth, "kind", default=""),
    "mooncode-tool-authorization-snapshot",
  )
  assert_eq(
    json_string(auth, "enforcement_state", default=""),
    "requires-approval",
  )
  assert_false(json_bool(auth, "runtime_may_execute", default=true))
  assert_eq(command_json_int(auth, "pending_approval_count", default=0), 1)
  let native = command_json_object_field_or_empty(
    command, "native_mooncode_body",
  )
  let native_tool_contract = command_json_object_field_or_empty(
    native, "tool_contract",
  )
  assert_true(
    command_policy_has_guardrail(
      json_array_items(native_tool_contract, "tool_policies"),
      "shell",
      "argv arrays",
    ),
  )
  let native_auth = command_json_object_field_or_empty(
    native, "tool_authorization",
  )
  assert_eq(
    json_string(native_auth, "manifest_path", default=""),
    "wiki/reviews/mooncode/agent-demo/tool-approvals.json",
  )
  let summary = command_json_object_field_or_empty(command, "execution_summary")
  assert_eq(
    json_string(summary, "tool_authorization_state", default=""),
    "requires-approval",
  )
  assert_false(json_bool(summary, "runtime_may_execute_tools", default=true))
}

///|
test "mooncode command event is reusable outside moonwiki" {
  let packet : Json = { "command_id": "cmd-1", "action": "run_tests" }
  let event = command_event(
    action="run_tests",
    status="queued",
    detail="Run tests",
    created_at="2026-06-15T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet=packet,
    event_id="cmd-1",
  )
  assert_eq(json_string(event, "lane", default=""), "test")
  assert_eq(json_string(event, "kind", default=""), "command.run_tests")
  assert_eq(json_string(event, "command", default=""), "run_tests")
  assert_eq(
    json_string(
      command_json_object_field_or_empty(event, "command_packet"),
      "command_id",
      default="",
    ),
    "cmd-1",
  )
}

///|
test "mooncode command metadata exposes tool and lane contracts" {
  assert_true(command_tool_hints("run_eval").contains("eval_harness"))
  assert_true(command_tool_hints("prompt").contains("edit"))
  assert_true(command_expected_lanes("prompt").contains("diff"))
  assert_true(command_expected_lanes("package").contains("artifact"))
  assert_true(command_expected_lanes("commit").contains("review"))
  assert_eq(command_lane("run_tests"), "test")
  assert_eq(command_lane("accept"), "review")
  assert_eq(command_lane("commit"), "review")
  assert_eq(command_title("apply_patch", "queued"), "Apply patch: queued")
  assert_eq(command_title("commit", "queued"), "Commit result: queued")
  assert_true(
    native_command_expected_events("apply_patch").contains("patch_applied"),
  )
  assert_true(
    native_command_expected_events("revert_patch").contains("patch_reverted"),
  )
  assert_true(
    native_command_tool_sequence("apply_patch").contains("apply_patch"),
  )
  assert_false(native_command_tool_sequence("apply_patch").contains("edit"))
  assert_true(
    native_command_required_outputs("apply_patch").contains(
      "patch_applied proof event",
    ),
  )
  assert_true(
    native_command_required_outputs("apply_patch").contains(
      "selected-hunk proof metadata",
    ),
  )
  assert_true(
    native_command_expected_events("package").contains("package_verified"),
  )
  assert_true(
    native_command_required_outputs("package").contains(
      "package_verified proof event",
    ),
  )
  assert_true(
    native_command_expected_events("commit").contains("commit_created"),
  )
  assert_true(
    native_command_required_outputs("commit").contains(
      "commit_created proof event",
    ),
  )
}

///|
test "mooncode native command tool policies expose OpenSeek style guardrails" {
  let prompt_policies = native_command_tool_policies(
    "prompt", "tools/demo/main.mbt",
  )
  assert_true(
    command_policy_has_guardrail(prompt_policies, "edit", "recent bounded read"),
  )
  assert_true(
    command_policy_has_guardrail(prompt_policies, "write", "moon.mod.json"),
  )
  let shell = native_command_tool_policy(
    "shell", "run_tests", "tools/demo/main.mbt",
  )
  assert_eq(json_string(shell, "approval", default=""), "policy")
  assert_false(json_bool(shell, "mutates_files", default=true))
  assert_true(
    command_json_string_array_items(shell, "proof_events").contains(
      "runtime_update",
    ),
  )
  let package_policies = native_command_tool_policies(
    "package", "tools/demo/main.mbt",
  )
  assert_true(
    command_policy_has_guardrail(
      package_policies, "package_app_tool", "runtime-proven",
    ),
  )
}
