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
fn action_plan_item_state_with_tool_harness(
  action : String,
  runtime_state : String,
  state : String,
  runtime_evidence : Json,
) -> String {
  if runtime_state != "delivered" ||
    !action_plan_action_requires_tool_harness(action) ||
    state == "blocked" ||
    state == "queued-for-runtime" ||
    state == "running" ||
    state == "runtime-retry" {
    return state
  }
  if runtime_json_int(
      runtime_evidence,
      "tool_harness_expected_tool_count",
      default=0,
    ) ==
    0 {
    return state
  }
  match json_string(runtime_evidence, "tool_harness_status", default="") {
    "proven" | "no-tools" => state
    "failed" => "runtime-retry"
    _ => "awaiting-proof"
  }
}

///|
fn action_plan_action_requires_tool_harness(action : String) -> Bool {
  match action {
    "prompt"
    | "steer"
    | "run_tests"
    | "run_eval"
    | "package"
    | "commit"
    | "accept"
    | "apply_patch"
    | "revert_patch" => true
    _ => false
  }
}

///|
fn action_plan_runtime_command_for_id(
  command_id : String,
  runtime_commands : Array[Json],
) -> Json {
  if command_id == "" {
    return Json::object({})
  }
  for command in runtime_commands {
    if json_string(command, "command_id", default="") == command_id {
      return command
    }
  }
  Json::object({})
}

///|
pub fn action_plan_runtime_state_at(
  command_id : String,
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  lease_now? : String = "",
) -> String {
  if command_id == "" {
    return "not-recorded"
  }
  let mut runtime_recorded = false
  for command in runtime_commands {
    if json_string(command, "command_id", default="") == command_id {
      runtime_recorded = true
    }
  }
  let statuses = runtime_receipt_statuses(runtime_dispatches)
  let latest_receipts = runtime_latest_receipts(runtime_dispatches)
  let receipt = statuses.get(command_id).unwrap_or("")
  if runtime_receipt_status_delivered(receipt) {
    "delivered"
  } else if runtime_receipt_status_claimed(receipt) &&
    lease_now != "" &&
    runtime_receipt_claim_expired(
      latest_receipts.get(command_id).unwrap_or(Json::object({})),
      lease_now,
    ) {
    "expired-claim"
  } else if runtime_receipt_status_claimed(receipt) {
    "claimed"
  } else if receipt == "failed" {
    "failed"
  } else if runtime_recorded {
    "pending"
  } else {
    "not-recorded"
  }
}

///|
pub fn action_plan_item_state(
  action : String,
  runtime_state : String,
  summary : Json,
) -> String {
  action_plan_item_state_for_command(action, "", runtime_state, summary, [])
}

///|
pub fn action_plan_item_state_for_command(
  action : String,
  command_id : String,
  runtime_state : String,
  summary : Json,
  proof_events : Array[Json],
) -> String {
  if runtime_state == "failed" || runtime_state == "expired-claim" {
    return "runtime-retry"
  }
  if runtime_state == "claimed" {
    return "running"
  }
  if runtime_state == "pending" || runtime_state == "not-recorded" {
    return "queued-for-runtime"
  }
  let verified_tests = runtime_json_int(
    summary,
    "verified_test_count",
    default=0,
  )
  let failed_tests = runtime_json_int(summary, "failed_test_count", default=0)
  let source_bound = runtime_json_int(
    summary,
    "source_bound_package_count",
    default=0,
  )
  let pending_diffs = runtime_json_int(summary, "pending_diff_count", default=0)
  let pending_approvals = runtime_json_int(
    summary,
    "pending_tool_approval_count",
    default=0,
  )
  let runtime_commit_proofs = runtime_json_int(
    summary,
    "runtime_commit_proof_count",
    default=0,
  )
  let command_verified_tests = command_proof_count(
    proof_events,
    command_id,
    action,
    proof_kind="test_result",
  )
  let command_source_bound_packages = command_proof_count(
      proof_events,
      command_id,
      action,
      proof_kind="package.manifest",
    ) +
    command_proof_count(
      proof_events,
      command_id,
      action,
      proof_kind="runtime.package_verified",
    )
  let command_commit_proofs = command_proof_count(
    proof_events,
    command_id,
    action,
    proof_kind="runtime.commit_created",
  )
  match action {
    "run_tests" =>
      if failed_tests > 0 {
        "blocked"
      } else if command_proofs_are_scoped(proof_events, action) {
        if command_verified_tests > 0 {
          "completed"
        } else {
          "awaiting-proof"
        }
      } else if verified_tests > 0 {
        "completed"
      } else {
        "awaiting-proof"
      }
    "run_eval" => {
      let eval_report = runtime_json_object_field_or_empty(
        summary, "last_moonbook_eval_report_manifest",
      )
      if json_bool(eval_report, "native_eval_evidence_ready", default=false) {
        "completed"
      } else {
        "awaiting-proof"
      }
    }
    "package" =>
      if failed_tests > 0 {
        "blocked"
      } else if command_proofs_are_scoped(proof_events, action) {
        if command_source_bound_packages > 0 {
          "completed"
        } else {
          "ready-for-review"
        }
      } else if source_bound > 0 {
        "completed"
      } else {
        "ready-for-review"
      }
    "accept" =>
      if failed_tests > 0 ||
        pending_approvals > 0 ||
        (pending_diffs > 0 && verified_tests == 0) {
        "blocked"
      } else {
        "ready-for-review"
      }
    "commit" =>
      if failed_tests > 0 ||
        pending_approvals > 0 ||
        (pending_diffs > 0 && verified_tests == 0) {
        "blocked"
      } else if command_proofs_are_scoped(proof_events, action) {
        if command_commit_proofs > 0 {
          "completed"
        } else {
          "awaiting-proof"
        }
      } else if runtime_commit_proofs > 0 {
        "completed"
      } else {
        "awaiting-proof"
      }
    "reject"
    | "approve_tool"
    | "reject_tool"
    | "apply_patch"
    | "revert_patch" => "ready-for-review"
    "cancel" => "completed"
    _ => "completed"
  }
}

///|
pub fn action_plan_blocking_reason(
  action : String,
  runtime_state : String,
  state : String,
  summary : Json,
) -> String {
  if state == "queued-for-runtime" {
    return "command is recorded but has not been delivered to MoonClaw/native MoonCode yet"
  }
  if state == "runtime-retry" {
    if runtime_state == "expired-claim" {
      return "runtime claim lease expired; reclaim the command before execution"
    }
    return "last runtime dispatch failed; replay or retry the command"
  }
  if state == "running" {
    return "MoonClaw or standalone MoonCode has claimed this command and should acknowledge it through runtime replay"
  }
  if state != "blocked" {
    return ""
  }
  let failed_tests = runtime_json_int(summary, "failed_test_count", default=0)
  let pending_approvals = runtime_json_int(
    summary,
    "pending_tool_approval_count",
    default=0,
  )
  let pending_diffs = runtime_json_int(summary, "pending_diff_count", default=0)
  let verified_tests = runtime_json_int(
    summary,
    "verified_test_count",
    default=0,
  )
  if failed_tests > 0 {
    "fix failing test/build results before \{action}"
  } else if pending_approvals > 0 {
    "resolve pending tool approvals before \{action}"
  } else if pending_diffs > 0 && verified_tests == 0 {
    "run tests/builds before accepting pending file changes"
  } else if runtime_state == "" {
    "missing runtime state"
  } else {
    "waiting for MoonClaw proof events"
  }
}

///|
pub fn action_plan_item_next_step(_action : String, state : String) -> String {
  match state {
    "queued-for-runtime" =>
      "deliver command through runtime replay or native MoonCode"
    "running" => "wait for runtime acknowledgement or recover a stale claim"
    "runtime-retry" => "retry dispatch and preserve the failed receipt"
    "awaiting-proof" => "wait for MoonClaw to emit typed proof events"
    "blocked" => "resolve blocking gates before continuing"
    "ready-for-review" => "operator can review this action in Moondesk"
    "completed" => "no immediate operator action"
    _ => "inspect command"
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
