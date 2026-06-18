///|
fn mooncode_runtime_dispatch_pending_count_for_test(
  commands : Array[Json],
  receipts : Array[Json],
) -> Int {
  @mooncode.runtime_dispatch_pending_count(
    commands,
    receipts,
    lease_now=@async.now().to_string(),
  )
}

///|
fn mooncode_runtime_pending_command_ids_for_test(
  commands : Array[Json],
  receipts : Array[Json],
) -> Array[Json] {
  @mooncode.runtime_pending_command_ids(
    commands,
    receipts,
    lease_now=@async.now().to_string(),
  )
}

///|
fn mooncode_json_array_contains_id_for_test(
  items : Array[Json],
  id : String,
) -> Bool {
  for item in items {
    if json_string(item, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn mooncode_runtime_flow_session_for_test() -> Json {
  {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
    "moonclaw_task_id": "task-demo",
  }
}

///|
test "mooncode native command body uses typed runtime protocol" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_root": "/tmp/demo-book",
  }
  let packet : Json = {
    "protocol": "mooncode.v1",
    "action": "run_tests",
    "context_path": "tools/demo/main.mbt",
  }
  let body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "Run tests",
    packet,
  )
  assert_eq(json_string(body, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(body, "command", default=""), "run_tests")
  assert_eq(json_string(body, "native_dispatch_mode", default=""), "queue-only")
  assert_eq(json_string(body, "session_id", default=""), "agent-demo")
  assert_eq(json_string(body, "book_root", default=""), "/tmp/demo-book")
  assert_eq(
    json_string(body, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(body, "packet"),
      "protocol",
      default="",
    ),
    "mooncode.v1",
  )
  let plan = json_object_field_or_empty(body, "execution_plan")
  assert_eq(
    json_string(plan, "kind", default=""),
    "mooncode-native-command-execution-plan",
  )
  assert_true(
    json_string_array_items(plan, "tool_sequence").contains("moon_check"),
  )
  assert_true(
    json_string_array_items(plan, "expected_events").contains("test_result"),
  )
  assert_true(
    json_string_array_items(plan, "required_outputs").contains(
      "test_result event",
    ),
  )
  assert_true(
    json_string_array_items(plan, "recommended_commands").contains("moon test"),
  )
  let tool_contract = json_object_field_or_empty(body, "tool_contract")
  assert_true(
    json_bool(
      tool_contract,
      "moon_check_required_for_code_changes",
      default=false,
    ),
  )
  let result_contract = json_object_field_or_empty(body, "result_contract")
  assert_true(
    json_string_array_items(result_contract, "required_events").contains(
      "test_result",
    ),
  )
  let checklist = json_array_items(result_contract, "execution_checklist")
  assert_true(checklist.length() > 0)
  assert_eq(json_string(checklist[0], "id", default=""), "claim-command")
  assert_true(
    mooncode_json_array_contains_id_for_test(
      checklist, "emit-event-test_result",
    ),
  )
  assert_true(
    mooncode_json_array_contains_id_for_test(checklist, "ack-command"),
  )
  let eval_packet : Json = {
    "protocol": "mooncode.v1",
    "action": "run_eval",
    "context_path": "tools/demo/main.mbt",
  }
  let eval_body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "Run eval",
    eval_packet,
  )
  let eval_plan = json_object_field_or_empty(eval_body, "execution_plan")
  assert_true(
    json_string_array_items(eval_plan, "tool_sequence").contains("moon_check"),
  )
  assert_true(
    json_string_array_items(eval_plan, "required_outputs").contains(
      "native eval report",
    ),
  )
  assert_true(
    json_string_array_items(eval_plan, "recommended_commands").contains(
      "run tool_harness eval fixtures",
    ),
  )
  let eval_result_contract = json_object_field_or_empty(
    eval_body, "result_contract",
  )
  assert_eq(
    json_string(eval_result_contract, "eval_report_sink", default=""),
    "POST /api/mooncode/sessions/<session-id>/eval-report",
  )
  assert_true(
    mooncode_json_array_contains_id_for_test(
      json_array_items(eval_result_contract, "execution_checklist"),
      "publish-native-eval-report",
    ),
  )
}

///|
test "mooncode native command body gives package and review actions executable contracts" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_root": "/tmp/demo-book",
  }
  let package_packet : Json = {
    "protocol": "mooncode.v1",
    "action": "package",
    "dispatch": "command",
    "approval": "operator",
    "context_path": "tools/demo/main.mbt",
    "workspace_root": "/tmp/demo-book",
  }
  let package_body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt", "package_kind": "miniapp" },
    "Package it",
    package_packet,
  )
  let package_plan = json_object_field_or_empty(package_body, "execution_plan")
  assert_eq(json_string(package_plan, "package_kind", default=""), "miniapp")
  assert_true(json_bool(package_plan, "review_required", default=false))
  assert_true(
    json_string_array_items(package_plan, "tool_sequence").contains(
      "package_app_tool",
    ),
  )
  assert_true(
    json_string_array_items(package_plan, "required_outputs").contains(
      "package manifest",
    ),
  )
  assert_true(
    json_string_array_items(package_plan, "expected_events").contains(
      "package.index",
    ),
  )
  let package_contract = json_object_field_or_empty(
    package_body, "result_contract",
  )
  assert_true(
    json_string(package_contract, "ack_sink", default="").contains(
      "/runtime-replay",
    ),
  )
  let commit_packet : Json = {
    "protocol": "mooncode.v1",
    "action": "commit",
    "dispatch": "command",
    "approval": "operator",
    "context_path": "tools/demo/main.mbt",
    "workspace_root": "/tmp/demo-book",
  }
  let commit_body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "Commit it",
    commit_packet,
  )
  let commit_plan = json_object_field_or_empty(commit_body, "execution_plan")
  assert_true(
    json_string_array_items(commit_plan, "expected_events").contains(
      "commit_created",
    ),
  )
  assert_true(
    json_string_array_items(commit_plan, "required_outputs").contains(
      "commit_created proof event",
    ),
  )
  let accept_packet : Json = {
    "protocol": "mooncode.v1",
    "action": "accept",
    "dispatch": "command",
    "approval": "operator",
    "context_path": "tools/demo/main.mbt",
  }
  let accept_body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "Accept it",
    accept_packet,
  )
  let accept_plan = json_object_field_or_empty(accept_body, "execution_plan")
  assert_true(json_bool(accept_plan, "review_required", default=false))
  assert_true(
    json_string_array_items(accept_plan, "required_outputs").contains(
      "review receipt",
    ),
  )
  assert_false(
    json_string_array_items(accept_plan, "tool_sequence").contains("shell"),
  )
}

///|
test "mooncode runtime command stores compact execution summary" {
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
  }
  let message = @mooncode.command_message("package", payload)
  let packet = @mooncode.projected_command_packet(
    session, payload, "package", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let command = @mooncode.runtime_command_record(
    session, payload, message, packet,
  )
  let summary = json_object_field_or_empty(command, "execution_summary")
  assert_eq(
    json_string(summary, "kind", default=""),
    "mooncode-runtime-execution-summary",
  )
  assert_eq(json_string(summary, "action", default=""), "package")
  assert_eq(json_string(summary, "package_kind", default=""), "miniapp")
  assert_true(json_bool(summary, "review_required", default=false))
  assert_true(
    json_string_array_items(summary, "tool_sequence").contains(
      "package_app_tool",
    ),
  )
  assert_true(
    json_string_array_items(summary, "allowed_tools").contains(
      "package_app_tool",
    ),
  )
  assert_true(
    json_string_array_items(summary, "required_events").contains(
      "package.index",
    ),
  )
  assert_true(
    json_string_array_items(summary, "required_outputs").contains(
      "package manifest",
    ),
  )
  assert_true(
    json_string(summary, "ack_sink", default="").contains("/runtime-replay"),
  )
  assert_true(json_int(summary, "checklist_count", default=0) > 0)
  assert_true(
    mooncode_json_array_contains_id_for_test(
      json_array_items(summary, "execution_checklist"),
      "ack-command",
    ),
  )
  assert_true(
    json_string(summary, "path_rule", default="").contains("MoonBook"),
  )
}

///|
test "mooncode runtime dispatch pending count ignores bridged receipts" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "legacy-bridged",
    },
  ]
  assert_eq(
    mooncode_runtime_dispatch_pending_count_for_test(commands, receipts),
    1,
  )
  assert_eq(
    mooncode_runtime_pending_command_ids_for_test(commands, receipts).length(),
    1,
  )
}

///|
test "mooncode runtime replay skips delivered commands and emits pending jsonl" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "target": "tools/demo",
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "target": "tools/demo",
      "openseek_wire_command": { "command": "steer", "text": "add tests" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "native-dispatched",
    },
  ]
  let state = @mooncode.runtime_replay_state_for_session(
    mooncode_runtime_flow_session_for_test(),
    commands,
    receipts,
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_string(state, "kind", default=""), "mooncode-runtime-replay")
  assert_eq(json_int(state, "command_count", default=0), 2)
  assert_eq(json_int(state, "delivered_command_count", default=0), 1)
  assert_eq(json_int(state, "pending_command_count", default=0), 1)
  assert_eq(json_int(state, "first_pending_index", default=-1), 1)
  assert_true(json_bool(state, "replay_ready", default=false))
  assert_true(
    json_string(state, "pending_openseek_jsonl", default="").contains(
      "\"steer\"",
    ),
  )
  let pending = json_array_items(state, "pending_commands")
  assert_eq(pending.length(), 1)
  assert_eq(json_string(pending[0], "command_id", default=""), "cmd-2")
}

///|
test "mooncode runtime serve jsonl exports pending or all wire commands" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "action": "steer",
      "dispatch": "steer",
      "openseek_wire_command": { "command": "steer", "text": "add tests" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-bad",
      "action": "prompt",
      "dispatch": "prompt",
      "openseek_wire_command": { "command": "prompt" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "runtime-completed",
    },
  ]
  let pending = @mooncode.runtime_serve_jsonl(
    commands,
    receipts,
    scope="pending",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_false(pending.contains("build it"))
  assert_true(pending.contains("add tests"))
  assert_false(pending.contains("cmd-bad"))
  assert_true(pending.has_suffix("\n"))
  let all = @mooncode.runtime_serve_jsonl(commands, receipts, scope="all")
  assert_true(all.contains("build it"))
  assert_true(all.contains("add tests"))
  assert_false(all.contains("cmd-bad"))
}

///|
test "mooncode runtime replay acknowledgement marks commands delivered" {
  let session : Json = {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "target": "tools/demo",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
  ]
  let claims : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "dispatch_id": "claim-1",
      "claim_id": "claim-1",
      "command_id": "cmd-1",
      "status": "runtime-claimed",
      "consumer_id": "moonclaw-native",
    },
  ]
  let receipts = @mooncode.runtime_replay_ack_receipts_with_defaults(
    session,
    commands,
    {
      "consumer_id": "moonclaw-native",
      "command_id": "cmd-1",
      "status": "runtime-completed",
      "detail": "turn finished",
    },
    acknowledged_at="2026-06-15T00:01:00Z",
    dispatch_receipts=claims,
  )
  assert_eq(receipts.length(), 1)
  assert_eq(
    mooncode_runtime_dispatch_pending_count_for_test(commands, receipts),
    0,
  )
  assert_eq(
    mooncode_runtime_pending_command_ids_for_test(commands, receipts).length(),
    0,
  )
  assert_eq(
    json_string(receipts[0], "kind", default=""),
    "mooncode.runtime-dispatch",
  )
  assert_eq(json_string(receipts[0], "status", default=""), "runtime-completed")
  assert_eq(
    json_string(receipts[0], "ack_order_status", default=""),
    "matching-claim",
  )
  assert_eq(
    json_string(receipts[0], "previous_claim_id", default=""),
    "claim-1",
  )
  assert_eq(
    json_string(receipts[0], "dispatch_mode", default=""),
    "mooncode-runtime-replay",
  )
  let state = @mooncode.runtime_replay_state_for_session(
    mooncode_runtime_flow_session_for_test(),
    commands,
    receipts,
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_int(state, "delivered_command_count", default=0), 1)
  assert_eq(json_int(state, "pending_command_count", default=1), 0)
  assert_false(json_bool(state, "replay_ready", default=true))
}

///|
test "mooncode runtime replay acknowledgement ignores unknown commands" {
  let session : Json = { "id": "session-demo" }
  let receipts = @mooncode.runtime_replay_ack_receipts_with_defaults(
    session,
    [],
    {
      "consumer_id": "moonclaw-native",
      "command_id": "missing-command",
      "status": "runtime-completed",
    },
    acknowledged_at="2026-06-15T00:01:00Z",
  )
  assert_eq(receipts.length(), 0)
}

///|
test "mooncode runtime execution plan endpoint projection exposes next command" {
  let session : Json = {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
    "workspace_root": "/tmp/book",
    "moonclaw_task_id": "task-demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "target": "tools/demo/main.mbt",
      "context_path": "tools/demo/main.mbt",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
      "execution_summary": {
        "required_events": [
          "tool_call", "tool_result", "test_result", "agent_finished",
        ],
        "required_outputs": ["test/build log"],
        "event_sink": "/api/mooncode/sessions/session-demo/runtime-events",
        "ack_sink": "/api/mooncode/sessions/session-demo/runtime-replay",
        "execution_checklist": [
          { "id": "claim-command", "blocking": true },
          { "id": "emit-event-test_result", "blocking": true },
        ],
      },
      "native_mooncode_body": {
        "protocol": "mooncode.v1",
        "command": "run_tests",
        "session_id": "session-demo",
      },
    },
  ]
  let plan = mooncode_runtime_execution_plan(
    "/tmp/book",
    session,
    "session-demo",
    commands,
    [],
    [],
    moonclaw_root="/tmp/moonclaw",
    native_ready=true,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    json_string(plan, "kind", default=""),
    "mooncode-runtime-consumer-execution-plan",
  )
  assert_eq(json_string(plan, "status", default=""), "ready-to-claim")
  assert_eq(json_string(plan, "command_id", default=""), "cmd-1")
  assert_true(json_bool(plan, "native_runtime_ready", default=false))
  assert_true(json_bool(plan, "ready_to_execute", default=false))
  assert_true(
    json_string(plan, "claim_endpoint", default="").contains("/runtime-claim"),
  )
  assert_true(
    json_string_array_items(plan, "required_events").contains("test_result"),
  )
  assert_eq(json_array_items(plan, "execution_checklist").length(), 2)
  let scheduler = json_object_field_or_empty(plan, "serve_scheduler")
  assert_eq(
    json_string(scheduler, "kind", default=""),
    "mooncode-serve-scheduler-state",
  )
  let packet = json_object_field_or_empty(plan, "runtime_turn_packet")
  assert_eq(
    json_string(packet, "kind", default=""),
    "mooncode-runtime-turn-packet",
  )
  assert_eq(json_string(packet, "command_id", default=""), "cmd-1")
  assert_eq(json_string(packet, "scheduler_effect", default=""), "start-turn")
  let supervisor = json_object_field_or_empty(plan, "runtime_supervisor")
  assert_eq(
    json_string(supervisor, "kind", default=""),
    "mooncode-runtime-supervisor-launch",
  )
  assert_eq(json_string(supervisor, "command_id", default=""), "cmd-1")
  assert_true(json_bool(supervisor, "ready_to_launch", default=false))
  let supervisor_endpoints = json_object_field_or_empty(supervisor, "endpoints")
  assert_eq(
    json_string(supervisor_endpoints, "production_readiness", default=""),
    "/api/mooncode/sessions/session-demo/production-readiness",
  )
  let supervisor_loop = json_array_items(supervisor, "supervisor_loop")
  assert_eq(
    json_string(supervisor_loop[6], "id", default=""),
    "check-production-readiness",
  )
  let readiness = json_object_field_or_empty(supervisor, "readiness")
  assert_eq(
    json_string(readiness, "kind", default=""),
    "mooncode-runtime-supervisor-readiness",
  )
  assert_true(json_bool(readiness, "ok", default=false))
  assert_eq(json_int(readiness, "missing_requirement_count", default=-1), 0)
  assert_true(
    json_string(supervisor, "safety_boundary", default="").contains(
      "declarative",
    ),
  )
}

///|
test "mooncode serve scheduler projection exposes ordered control decisions" {
  let command_log : Array[Json] = [
    {
      "command_id": "cmd-active",
      "action": "prompt",
      "dispatch": "prompt",
      "message": "build a tool",
    },
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "dispatch": "steer",
      "message": "focus the package output",
    },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-active", "action": "prompt", "status": "running" },
      { "command_id": "cmd-steer", "action": "steer", "status": "pending" },
    ],
  }
  let scheduler = @mooncode.serve_scheduler_projection(
    "session-demo", command_log, lifecycle,
  )
  assert_eq(
    json_string(scheduler, "kind", default=""),
    "mooncode-serve-scheduler-state",
  )
  assert_eq(json_string(scheduler, "active_turn_id", default=""), "cmd-active")
  let decisions = json_array_items(scheduler, "decisions")
  assert_eq(decisions.length(), 2)
  assert_eq(json_string(decisions[0], "effect", default=""), "active-turn")
  assert_eq(json_string(decisions[1], "effect", default=""), "deliver-steer")
  assert_true(
    json_string(scheduler, "protocol", default="").contains("mooncode.v1"),
  )
}

///|
test "mooncode runtime claim marks pending command without completing it" {
  let session : Json = {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "session_id": "session-demo",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "steer", "text": "add tests" },
    },
  ]
  let receipts = @mooncode.runtime_claim_receipts_with_defaults(
    session,
    commands,
    [],
    {
      "consumer_id": "moonclaw-runtime",
      "max_count": 1,
      "claimed_at": "2026-06-15T00:00:00Z",
    },
    now="2026-06-15T00:00:00Z",
  )
  assert_eq(receipts.length(), 1)
  assert_eq(json_string(receipts[0], "status", default=""), "runtime-claimed")
  assert_eq(
    json_string(receipts[0], "legacy_bridge_endpoint", default="missing"),
    "",
  )
  assert_eq(
    json_string(receipts[0], "dispatch_mode", default=""),
    "mooncode-runtime-claim",
  )
  assert_eq(json_string(receipts[0], "command_id", default=""), "cmd-1")
  assert_eq(
    mooncode_runtime_dispatch_pending_count_for_test(commands, receipts),
    1,
  )
  let state = @mooncode.runtime_replay_state_for_session(
    mooncode_runtime_flow_session_for_test(),
    commands,
    receipts,
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_int(state, "claimed_command_count", default=0), 1)
  assert_eq(json_int(state, "delivered_command_count", default=0), 0)
  assert_eq(json_int(state, "pending_command_count", default=0), 0)
  let items = json_array_items(state, "replay_items")
  assert_eq(json_string(items[0], "replay_status", default=""), "claimed")
  assert_eq(
    json_string(items[1], "replay_status", default=""),
    "blocked-by-prior-command",
  )
  assert_eq(json_string(items[1], "blocked_by_command_id", default=""), "cmd-1")
  let claim_state = @mooncode.runtime_claim_state_for_session(
    mooncode_runtime_flow_session_for_test(),
    commands,
    receipts,
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(
    json_string(claim_state, "kind", default=""),
    "mooncode-runtime-claim-state",
  )
  assert_eq(json_int(claim_state, "claimed_command_count", default=0), 1)
  assert_eq(json_int(claim_state, "claimable_command_count", default=0), 0)
  assert_eq(json_int(claim_state, "order_blocked_command_count", default=0), 1)
  let claimed_items = json_array_items(claim_state, "claimed_commands")
  assert_eq(claimed_items.length(), 1)
  assert_eq(json_string(claimed_items[0], "command_id", default=""), "cmd-1")
  let order_blocked = json_array_items(claim_state, "order_blocked_commands")
  assert_eq(json_string(order_blocked[0], "command_id", default=""), "cmd-2")
  assert_eq(
    json_string(order_blocked[0], "blocked_by_command_id", default=""),
    "cmd-1",
  )
  let response_receipts = @mooncode.runtime_dispatch_receipts_for_response(
    receipts,
  )
  assert_eq(
    json_string(
      response_receipts[0],
      "legacy_bridge_endpoint",
      default="missing",
    ),
    "",
  )
}

///|
test "mooncode runtime claim exposes tool authorization blocked commands" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tool",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "serve_command": "prompt",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
      "tool_authorization": {
        "kind": "mooncode-tool-authorization-snapshot",
        "protocol": "mooncode.v1",
        "enforcement_state": "requires-approval",
        "runtime_may_execute": false,
        "pending_approval_count": 1,
      },
    },
  ]
  let claim_state = @mooncode.runtime_claim_state_for_session(
    mooncode_runtime_flow_session_for_test(),
    commands,
    [],
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_int(claim_state, "claimable_command_count", default=0), 0)
  assert_eq(
    json_int(claim_state, "tool_authorization_blocked_command_count", default=0),
    1,
  )
  let blocked = json_array_items(
    claim_state, "tool_authorization_blocked_commands",
  )
  assert_eq(json_string(blocked[0], "command_id", default=""), "cmd-tool")
  let receipts = @mooncode.runtime_claim_receipts_with_defaults(
    session,
    commands,
    [],
    { "consumer_id": "moonclaw-runtime", "max_count": 1 },
    now="2026-06-15T00:00:00Z",
  )
  assert_eq(receipts.length(), 0)
}

///|
test "mooncode runtime claim preserves ordering behind claimed commands" {
  let session : Json = { "id": "session-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "session_id": "session-demo",
      "openseek_wire_command": { "command": "prompt", "text": "one" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "session_id": "session-demo",
      "openseek_wire_command": { "command": "prompt", "text": "two" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-3",
      "session_id": "session-demo",
      "openseek_wire_command": { "command": "prompt", "text": "three" },
    },
  ]
  let existing : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "runtime-claimed",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-2",
      "status": "runtime-completed",
    },
  ]
  let claimed = @mooncode.runtime_claim_receipts_with_defaults(
    session,
    commands,
    existing,
    { "consumer_id": "moonclaw-runtime", "max_count": 10 },
    now="2026-06-15T00:00:00Z",
  )
  assert_eq(claimed.length(), 0)
  let forced = @mooncode.runtime_claim_receipts_with_defaults(
    session,
    commands,
    existing,
    { "consumer_id": "moonclaw-runtime", "max_count": 10, "force": true },
    now="2026-06-15T00:00:00Z",
  )
  assert_eq(forced.length(), 2)
  assert_eq(json_string(forced[0], "command_id", default=""), "cmd-1")
  assert_eq(json_string(forced[1], "command_id", default=""), "cmd-3")
}

///|
test "mooncode runtime claim recovers expired leases" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-stale",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "recover me" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-fresh",
      "session_id": "session-demo",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "openseek_wire_command": { "command": "steer", "text": "next" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-stale",
      "status": "runtime-claimed",
      "claim_id": "claim-old",
      "consumer_id": "dead-runtime",
      "claimed_at": "2000-01-01T00:00:00Z",
      "lease_expires_at": "2000-01-01T00:05:00Z",
    },
  ]
  let state = @mooncode.runtime_claim_state_for_session(
    mooncode_runtime_flow_session_for_test(),
    commands,
    receipts,
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_int(state, "claimable_command_count", default=0), 2)
  assert_eq(json_int(state, "claimed_command_count", default=0), 0)
  assert_eq(json_int(state, "expired_claim_command_count", default=0), 1)
  let expired = json_array_items(state, "expired_claim_commands")
  assert_eq(json_string(expired[0], "command_id", default=""), "cmd-stale")
  assert_true(json_bool(expired[0], "previous_claim_expired", default=false))
  let replay = @mooncode.runtime_replay_state_for_session(
    mooncode_runtime_flow_session_for_test(),
    commands,
    receipts,
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  let replay_items = json_array_items(replay, "replay_items")
  assert_eq(
    json_string(replay_items[0], "replay_status", default=""),
    "expired-claim-pending-retry",
  )
  assert_eq(json_int(replay, "pending_command_count", default=0), 2)
  let claimed = @mooncode.runtime_claim_receipts_with_defaults(
    session,
    commands,
    receipts,
    {
      "consumer_id": "moonclaw-runtime",
      "max_count": 1,
      "now": "2000-01-01T00:06:00Z",
      "claimed_at": "2000-01-01T00:06:30Z",
      "lease_expires_at": "2000-01-01T00:11:30Z",
    },
    now="2000-01-01T00:06:00Z",
  )
  assert_eq(claimed.length(), 1)
  assert_eq(json_string(claimed[0], "command_id", default=""), "cmd-stale")
  assert_true(json_bool(claimed[0], "recovered_expired_claim", default=false))
  assert_eq(
    json_string(claimed[0], "previous_claim_id", default=""),
    "claim-old",
  )
  let active = @mooncode.runtime_claim_receipts_with_defaults(
    session,
    commands,
    receipts,
    {
      "consumer_id": "moonclaw-runtime",
      "max_count": 1,
      "now": "1999-12-31T23:59:00Z",
    },
    now="1999-12-31T23:59:00Z",
  )
  assert_eq(active.length(), 0)
  let runtime_state = @mooncode.action_plan_runtime_state_at(
    "cmd-stale",
    commands,
    receipts,
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(runtime_state, "expired-claim")
  assert_eq(
    @mooncode.action_plan_item_state("prompt", runtime_state, {}),
    "runtime-retry",
  )
}

///|
test "mooncode action plan treats claimed runtime commands as running" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
      "approval": "none",
    },
  ]
  let runtime_commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "runtime-claimed",
    },
  ]
  let items = @mooncode.action_plan_actions_for_session(
    Json::object({}),
    commands,
    runtime_commands,
    receipts,
    [],
  )
  assert_eq(items.length(), 1)
  assert_eq(json_string(items[0], "runtime_state", default=""), "claimed")
  assert_eq(json_string(items[0], "state", default=""), "running")
  assert_eq(@mooncode.action_plan_status(0, 1, 0, 0, 0, 1), "running")
}

///|
test "mooncode runtime replay blocks invalid openseek wire rows" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-invalid",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt" },
    },
  ]
  let state = @mooncode.runtime_replay_state_for_session(
    mooncode_runtime_flow_session_for_test(),
    commands,
    [],
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_int(state, "invalid_command_count", default=0), 1)
  assert_eq(
    json_string(state, "first_invalid_command_id", default=""),
    "cmd-invalid",
  )
  assert_false(json_bool(state, "replay_ready", default=true))
  let items = json_array_items(state, "replay_items")
  assert_eq(
    json_string(items[0], "replay_status", default=""),
    "blocked-invalid",
  )
}

///|
test "mooncode action plan classifies review and test gates" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.command",
      "command_id": "cmd-test",
      "action": "run_tests",
      "dispatch": "command",
      "approval": "auto",
      "target": "tools/demo",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.command",
      "command_id": "cmd-accept",
      "action": "accept",
      "dispatch": "command",
      "approval": "operator",
      "target": "tools/demo",
    },
  ]
  let runtime_commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-test",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-accept",
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-test",
      "status": "native-dispatched",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-accept",
      "status": "native-dispatched",
    },
  ]
  let events = [
    @mooncode.event_record(
      id="diff",
      lane="diff",
      kind="file.write",
      title="File changed",
      status="done",
      created_at="1",
      detail="changed",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
    ),
  ]
  let actions = @mooncode.action_plan_actions_for_session(
    Json::object({}),
    commands,
    runtime_commands,
    receipts,
    events,
  )
  assert_eq(actions.length(), 2)
  assert_eq(json_string(actions[0], "state", default=""), "awaiting-proof")
  assert_eq(json_string(actions[1], "state", default=""), "blocked")
  assert_true(json_string(actions[1], "blocking_reason", default="") != "")
}

///|
test "mooncode action plan includes blocked command preflight attempts" {
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": "mooncode.v1",
    "action": "accept",
    "blocked": true,
    "reason": "run tests/builds before accept for pending file changes",
  }
  let blocked = @mooncode.command_preflight_blocked_projected_event(
    preflight,
    action="accept",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-14T00:02:00Z",
  )
  let actions = @mooncode.action_plan_actions_for_session(
    Json::object({}),
    [],
    [],
    [],
    [blocked],
  )
  assert_eq(actions.length(), 1)
  assert_eq(json_string(actions[0], "dispatch", default=""), "preflight")
  assert_eq(json_string(actions[0], "state", default=""), "blocked")
  assert_eq(
    json_string(actions[0], "runtime_state", default=""),
    "blocked-before-dispatch",
  )
  assert_true(
    json_string(actions[0], "blocking_reason", default="").contains(
      "run tests/builds",
    ),
  )
}
