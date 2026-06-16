///|
pub fn action_plan_items(
  commands : Array[Json],
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  events : Array[Json],
  summary : Json,
  lease_now? : String = "",
) -> Array[Json] {
  let items : Array[Json] = []
  for index in 0..<commands.length() {
    let command = commands[index]
    items.push(
      action_plan_item(
        index,
        command,
        runtime_commands,
        runtime_dispatches,
        events,
        summary,
        lease_now~,
      ),
    )
  }
  let mut blocked_index = 0
  for event in events {
    if json_string(event, "kind", default="") == "preflight.blocked" ||
      json_string(event, "kind", default="") == "preflight.override" {
      items.push(
        action_plan_preflight_item(commands.length() + blocked_index, event),
      )
      blocked_index += 1
    }
  }
  items
}

///|
pub fn action_plan_preflight_item(index : Int, event : Json) -> Json {
  let action = json_string(event, "command", default="command")
  let overridden = json_string(event, "kind", default="") ==
    "preflight.override"
  {
    "index": index,
    "command_id": json_string(event, "id", default=""),
    "action": action,
    "dispatch": "preflight",
    "approval": command_approval(action),
    "state": if overridden {
      "override"
    } else {
      "blocked"
    },
    "runtime_state": if overridden {
      "operator-override"
    } else {
      "blocked-before-dispatch"
    },
    "created_at": json_string(event, "created_at", default=""),
    "target": json_string(event, "path", default="moonbook"),
    "context_path": json_string(event, "path", default=""),
    "message": json_string(event, "detail", default=""),
    "expected_lanes": action_plan_string_array_json(
      command_expected_lanes(action),
    ),
    "tool_hints": action_plan_string_array_json(command_tool_hints(action)),
    "required_gates": action_plan_string_array_json(
      action_required_gates(action),
    ),
    "runtime_evidence": {
      "kind": "mooncode-command-runtime-evidence",
      "protocol": "mooncode.v1",
      "command_id": json_string(event, "id", default=""),
      "action": action,
      "status": if overridden {
        "operator-override"
      } else {
        "blocked-before-dispatch"
      },
      "required_event_count": 0,
      "proven_required_event_count": 0,
      "missing_required_event_count": 0,
      "failed_required_event_count": 0,
      "missing_required_events": [],
      "failed_required_events": [],
      "events": [],
      "proven": false,
    },
    "runtime_evidence_status": if overridden {
      "operator-override"
    } else {
      "blocked-before-dispatch"
    },
    "required_event_count": 0,
    "proven_required_event_count": 0,
    "missing_required_events": [],
    "failed_required_events": [],
    "blocking_reason": json_string(event, "detail", default=""),
    "next_step": if overridden {
      "operator forced dispatch; audit runtime evidence before accepting output"
    } else {
      "resolve the preflight gates and retry this command"
    },
  }
}

///|
pub fn action_plan_item(
  index : Int,
  command : Json,
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  proof_events : Array[Json],
  summary : Json,
  lease_now? : String = "",
) -> Json {
  let command_id = json_string(command, "command_id", default="")
  let action = json_string(command, "action", default="prompt")
  let runtime_state = action_plan_runtime_state_at(
    command_id,
    runtime_commands,
    runtime_dispatches,
    lease_now~,
  )
  let runtime_command = action_plan_runtime_command_for_id(
    command_id, runtime_commands,
  )
  let runtime_evidence = command_runtime_evidence(
    command, runtime_command, proof_events,
  )
  let base_state = action_plan_item_state_for_command(
    action, command_id, runtime_state, summary, proof_events,
  )
  let state = action_plan_item_state_with_tool_harness(
    action, runtime_state, base_state, runtime_evidence,
  )
  {
    "index": index,
    "command_id": command_id,
    "action": action,
    "dispatch": json_string(command, "dispatch", default="command"),
    "approval": json_string(command, "approval", default="none"),
    "state": state,
    "runtime_state": runtime_state,
    "created_at": json_string(command, "created_at", default=""),
    "target": json_string(command, "target", default="moonbook"),
    "context_path": json_string(command, "context_path", default=""),
    "message": json_string(command, "message", default=""),
    "expected_lanes": action_plan_json_array(command, "expected_lanes"),
    "tool_hints": action_plan_json_array(command, "tool_hints"),
    "required_gates": action_plan_string_array_json(
      action_required_gates(action),
    ),
    "runtime_evidence": runtime_evidence,
    "runtime_evidence_status": json_string(
      runtime_evidence,
      "status",
      default="missing-evidence",
    ),
    "required_event_count": runtime_json_int(
      runtime_evidence,
      "required_event_count",
      default=0,
    ),
    "proven_required_event_count": runtime_json_int(
      runtime_evidence,
      "proven_required_event_count",
      default=0,
    ),
    "missing_required_events": action_plan_json_array(
      runtime_evidence, "missing_required_events",
    ),
    "failed_required_events": action_plan_json_array(
      runtime_evidence, "failed_required_events",
    ),
    "tool_harness_status": json_string(
      runtime_evidence,
      "tool_harness_status",
      default="no-tools",
    ),
    "tool_harness_expected_tool_count": runtime_json_int(
      runtime_evidence,
      "tool_harness_expected_tool_count",
      default=0,
    ),
    "tool_harness_proven_tool_count": runtime_json_int(
      runtime_evidence,
      "tool_harness_proven_tool_count",
      default=0,
    ),
    "tool_harness_missing_tool_count": runtime_json_int(
      runtime_evidence,
      "tool_harness_missing_tool_count",
      default=0,
    ),
    "tool_harness_failed_tool_count": runtime_json_int(
      runtime_evidence,
      "tool_harness_failed_tool_count",
      default=0,
    ),
    "blocking_reason": action_plan_blocking_reason(
      action, runtime_state, state, summary,
    ),
    "next_step": action_plan_item_next_step(action, state),
  }
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
  let items = action_plan_items(
    commands,
    runtime_commands,
    receipts,
    [],
    Json::object({}),
  )
  assert_eq(items.length(), 1)
  assert_eq(json_string(items[0], "runtime_state", default=""), "claimed")
  assert_eq(json_string(items[0], "state", default=""), "running")
  assert_eq(action_plan_status(0, 1, 0, 0, 0, 1), "running")
}

///|
test "mooncode action plan marks expired claims for runtime retry" {
  let runtime_commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-stale",
      "action": "prompt",
      "dispatch": "prompt",
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-stale",
      "status": "runtime-claimed",
      "lease_expires_at": "2000-01-01T00:05:00Z",
    },
  ]
  let runtime_state = action_plan_runtime_state_at(
    "cmd-stale",
    runtime_commands,
    receipts,
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(runtime_state, "expired-claim")
  assert_eq(
    action_plan_item_state("prompt", runtime_state, Json::object({})),
    "runtime-retry",
  )
}

///|
test "mooncode action plan waits for commit proof" {
  let summary_without_proof : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 0,
    "verified_test_count": 1,
    "runtime_commit_proof_count": 0,
  }
  assert_eq(
    action_plan_item_state("commit", "delivered", summary_without_proof),
    "awaiting-proof",
  )
  let summary_with_proof : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 0,
    "verified_test_count": 1,
    "runtime_commit_proof_count": 1,
  }
  assert_eq(
    action_plan_item_state("commit", "delivered", summary_with_proof),
    "completed",
  )
  assert_eq(
    action_plan_next_required_action(summary_without_proof, [
      { "action": "commit", "state": "awaiting-proof" },
    ]),
    "await_runtime_proof",
  )
}

///|
test "mooncode action plan correlates runtime proof to command id" {
  let summary_with_global_proof : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 0,
    "verified_test_count": 1,
    "runtime_commit_proof_count": 1,
  }
  let scoped_proof : Json = {
    "id": "commit-proof-a",
    "lane": "review",
    "kind": "runtime.commit_created",
    "title": "Commit created by runtime",
    "status": "done",
    "created_at": "2026-06-15T00:00:00Z",
    "detail": "abc1234",
    "command": "commit",
    "command_packet": {
      "protocol": "mooncode.v1",
      "kind": "mooncode.command-ref",
      "command_id": "cmd-a",
      "action": "commit",
    },
  }
  assert_eq(
    action_plan_item_state_for_command(
      "commit",
      "cmd-a",
      "delivered",
      summary_with_global_proof,
      [scoped_proof],
    ),
    "completed",
  )
  assert_eq(
    action_plan_item_state_for_command(
      "commit",
      "cmd-b",
      "delivered",
      summary_with_global_proof,
      [scoped_proof],
    ),
    "awaiting-proof",
  )
  assert_eq(
    command_proof_count(
      [scoped_proof],
      "cmd-a",
      "commit",
      proof_kind="runtime.commit_created",
    ),
    1,
  )
}

///|
test "mooncode action plan exposes command runtime evidence" {
  let command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "command_id": "cmd-test",
    "action": "run_tests",
    "dispatch": "command",
    "approval": "auto",
  }
  let runtime_command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-test",
    "action": "run_tests",
    "dispatch": "command",
    "execution_summary": {
      "required_events": ["test_result", "agent_finished"],
      "required_outputs": ["exit code"],
    },
  }
  let packet : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let item = action_plan_item(
    0,
    command,
    [runtime_command],
    [
      {
        "protocol": "mooncode.v1",
        "kind": "mooncode.runtime-dispatch",
        "command_id": "cmd-test",
        "status": "runtime-completed",
      },
    ],
    [
      event_record(
        id="test-result",
        lane="test",
        kind="test_result",
        title="Test result",
        status="done",
        created_at="2026-06-15T00:00:00Z",
        detail="ok",
        command_packet=packet,
      ),
    ],
    { "verified_test_count": 1 },
  )
  assert_eq(
    json_string(item, "runtime_evidence_status", default=""),
    "missing-evidence",
  )
  assert_eq(runtime_json_int(item, "required_event_count", default=0), 2)
  assert_eq(runtime_json_int(item, "proven_required_event_count", default=0), 1)
  assert_true(
    action_plan_json_string_array_items(item, "missing_required_events").contains(
      "agent_finished",
    ),
  )
}

///|
test "mooncode action plan waits for tool harness proof after delivery" {
  let command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "command_id": "cmd-test",
    "action": "run_tests",
    "dispatch": "command",
    "approval": "auto",
  }
  let runtime_command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-test",
    "action": "run_tests",
    "dispatch": "command",
    "execution_summary": {
      "tool_sequence": ["read", "moon_check", "finish"],
      "required_events": ["test_result", "agent_finished"],
      "required_outputs": ["exit code"],
    },
  }
  let packet : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let item = action_plan_item(
    0,
    command,
    [runtime_command],
    [
      {
        "protocol": "mooncode.v1",
        "kind": "mooncode.runtime-dispatch",
        "command_id": "cmd-test",
        "status": "runtime-completed",
      },
    ],
    [
      event_record(
        id="test-result",
        lane="test",
        kind="test_result",
        title="Test result",
        status="done",
        created_at="2026-06-15T00:00:00Z",
        detail="ok",
        command_packet=packet,
      ),
      event_record(
        id="finish",
        lane="review",
        kind="finish",
        title="Agent finished",
        status="done",
        created_at="2026-06-15T00:00:01Z",
        detail="done",
        command_packet=packet,
      ),
    ],
    { "verified_test_count": 1 },
  )
  assert_eq(json_string(item, "state", default=""), "awaiting-proof")
  assert_eq(
    json_string(item, "tool_harness_status", default=""),
    "missing-evidence",
  )
  assert_eq(
    runtime_json_int(item, "tool_harness_expected_tool_count", default=0),
    3,
  )
  assert_eq(
    runtime_json_int(item, "tool_harness_proven_tool_count", default=-1),
    1,
  )
}

///|
test "mooncode action plan retries failed tool harness proof" {
  let command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "command_id": "cmd-test",
    "action": "run_tests",
    "dispatch": "command",
    "approval": "auto",
  }
  let runtime_command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-test",
    "action": "run_tests",
    "dispatch": "command",
    "execution_summary": {
      "tool_sequence": ["moon_check"],
      "required_events": ["test_result", "agent_finished"],
    },
  }
  let packet : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let item = action_plan_item(
    0,
    command,
    [runtime_command],
    [
      {
        "protocol": "mooncode.v1",
        "kind": "mooncode.runtime-dispatch",
        "command_id": "cmd-test",
        "status": "runtime-completed",
      },
    ],
    [
      event_record(
        id="decode-error",
        lane="tool",
        kind="tool_call_decode_error",
        title="Tool decode failed",
        status="failed",
        created_at="2026-06-15T00:00:00Z",
        detail="bad args",
        command_packet=packet,
      )
      |> runtime_with_field("tool_name", "moon_check".to_json())
      |> runtime_with_field("tool_call_id", "call-check".to_json()),
      event_record(
        id="test-result",
        lane="test",
        kind="test_result",
        title="Test result",
        status="done",
        created_at="2026-06-15T00:00:01Z",
        detail="ok",
        command_packet=packet,
      ),
      event_record(
        id="finish",
        lane="review",
        kind="finish",
        title="Agent finished",
        status="done",
        created_at="2026-06-15T00:00:02Z",
        detail="done",
        command_packet=packet,
      ),
    ],
    { "verified_test_count": 1 },
  )
  assert_eq(json_string(item, "state", default=""), "runtime-retry")
  assert_eq(json_string(item, "tool_harness_status", default=""), "failed")
  assert_eq(
    runtime_json_int(item, "tool_harness_failed_tool_count", default=0),
    1,
  )
}

///|
test "mooncode action plan includes blocked command preflight attempts" {
  let blocked = command_preflight_blocked_event(
    {
      "kind": "mooncode-command-preflight",
      "protocol": "mooncode.v1",
      "action": "accept",
      "blocked": true,
      "reason": "run tests/builds before accept for pending file changes",
    },
    action="accept",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-14T00:02:00Z",
    event_id="blocked-1",
  )
  let actions = action_plan_items([], [], [], [blocked], Json::object({}))
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

///|
test "mooncode action plan includes operator preflight overrides" {
  let override_event = command_preflight_override_event(
    {
      "kind": "mooncode-command-preflight",
      "protocol": "mooncode.v1",
      "action": "commit",
      "blocked": true,
      "reason": "accept reviewed file changes before commit",
    },
    action="commit",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-15T00:02:00Z",
    event_id="override-1",
  )
  let actions = action_plan_items(
    [],
    [],
    [],
    [override_event],
    Json::object({}),
  )
  assert_eq(actions.length(), 1)
  assert_eq(json_string(actions[0], "dispatch", default=""), "preflight")
  assert_eq(json_string(actions[0], "state", default=""), "override")
  assert_eq(
    json_string(actions[0], "runtime_state", default=""),
    "operator-override",
  )
  assert_true(
    json_string(actions[0], "next_step", default="").contains(
      "audit runtime evidence",
    ),
  )
}
