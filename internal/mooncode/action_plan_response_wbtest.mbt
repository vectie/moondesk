///|
test "mooncode action plan response owns aggregate surface" {
  let actions : Array[Json] = [
    {
      "command_id": "cmd-1",
      "action": "run_tests",
      "state": "completed",
      "approval": "auto",
    },
    {
      "command_id": "cmd-2",
      "action": "package",
      "state": "ready-for-review",
      "approval": "operator",
    },
  ]
  let response = action_plan_response(
    "session-demo",
    {
      "id": "session-demo",
      "workspace_id": "book-demo",
      "workspace_name": "Demo Book",
      "mooncode_runtime_session_id": "runtime-demo",
    },
    actions,
    {
      "verified_test_count": 1,
      "failed_test_count": 0,
      "pending_diff_count": 0,
      "pending_tool_approval_count": 0,
      "pending_steer_count": 0,
      "deferred_steer_count": 0,
      "source_bound_package_count": 0,
    },
    [],
    [],
    recorded_at="2026-06-16T00:00:00Z",
    runtime_command_log_path="/tmp/session/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/session/runtime-receipt.jsonl",
  )
  assert_eq(json_string(response, "kind", default=""), "mooncode-action-plan")
  assert_eq(json_string(response, "status", default=""), "review-ready")
  assert_eq(json_string(response, "workspace_id", default=""), "book-demo")
  assert_eq(runtime_json_int(response, "action_count", default=0), 2)
  assert_eq(runtime_json_int(response, "completed_count", default=0), 1)
  assert_eq(runtime_json_int(response, "ready_for_review_count", default=0), 1)
  assert_eq(runtime_json_int(response, "run_test_command_count", default=0), 1)
  assert_eq(runtime_json_int(response, "package_command_count", default=0), 1)
  assert_eq(runtime_json_int(response, "review_command_count", default=0), 1)
  assert_eq(runtime_json_int(response, "pending_steer_count", default=-1), 0)
  assert_eq(runtime_json_int(response, "deferred_steer_count", default=-1), 0)
  assert_eq(
    json_string(response, "next_required_action", default=""),
    "package_executable_output",
  )
  let readiness = runtime_json_object_field_or_empty(response, "readiness")
  assert_eq(json_string(readiness, "kind", default=""), "mooncode-readiness")
  assert_eq(json_string(readiness, "source", default=""), "action-plan-derived")
  assert_eq(
    json_string(readiness, "next_action", default=""),
    "package_executable_output",
  )
  assert_eq(
    json_string(readiness, "next_owner", default=""),
    "moonbook-moonclaw",
  )
  assert_false(json_bool(readiness, "ready", default=true))
  let recommended = runtime_json_object_field_or_empty(
    response, "recommended_command",
  )
  assert_eq(json_string(recommended, "action", default=""), "package")
  assert_eq(
    json_string(recommended, "ui_action", default=""),
    "mooncode_command",
  )
  assert_eq(json_string(recommended, "label", default=""), "Package")
  let recommended_commands = runtime_json_array_items(
    response, "recommended_commands",
  )
  assert_eq(recommended_commands.length(), 1)
  assert_eq(
    json_string(recommended_commands[0], "action", default=""),
    "package",
  )
  assert_true(runtime_json_object_field(response, "runtime_replay") is Some(_))
  assert_true(
    runtime_json_object_field(response, "acceptance_gates") is Some(_),
  )
  let manifest = action_plan_manifest_response(
    response, "wiki/reviews/mooncode/session-demo/action-plan.json", "/tmp/book/wiki/reviews/mooncode/session-demo/action-plan.json",
  )
  assert_eq(
    json_string(manifest, "manifest_path", default=""),
    "wiki/reviews/mooncode/session-demo/action-plan.json",
  )
  assert_eq(
    json_string(manifest, "absolute_manifest_path", default=""),
    "/tmp/book/wiki/reviews/mooncode/session-demo/action-plan.json",
  )
  assert_eq(json_string(manifest, "kind", default=""), "mooncode-action-plan")
  assert_eq(runtime_json_int(manifest, "action_count", default=0), 2)
}

///|
test "mooncode action plan projection derives actions and summary" {
  let session : Json = {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "mooncode_runtime_session_id": "runtime-demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_command(),
      "command_id": "cmd-1",
      "action": "prompt",
      "control": "prompt",
      "created_at": "2026-06-16T00:00:00Z",
      "approval": "none",
    },
  ]
  let runtime_commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "action": "prompt",
      "control": "prompt",
      "mooncode_command": { "command": "prompt", "text": "build" },
    },
  ]
  let runtime_receipts : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_runtime_receipt(),
      "command_id": "cmd-1",
      "status": "runtime-claimed",
      "lease_expires_at": "2026-06-16T00:10:00Z",
    },
  ]
  let response = action_plan_projection_response(
    "session-demo",
    session,
    commands,
    runtime_commands,
    runtime_receipts,
    [],
    recorded_at="2026-06-16T00:01:00Z",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipt.jsonl",
    lease_now="2026-06-16T00:02:00Z",
  )
  assert_eq(json_string(response, "status", default=""), "running")
  assert_eq(runtime_json_int(response, "action_count", default=0), 1)
  assert_eq(runtime_json_int(response, "running_count", default=0), 1)
  assert_eq(
    json_string(response, "next_required_action", default=""),
    "package_executable_output",
  )
  let readiness = runtime_json_object_field_or_empty(response, "readiness")
  assert_eq(json_string(readiness, "kind", default=""), "mooncode-readiness")
  assert_eq(json_string(readiness, "source", default=""), "")
  assert_eq(
    json_string(readiness, "first_blocker_id", default=""),
    "durable_session",
  )
  assert_eq(
    json_string(readiness, "next_action", default=""),
    "persist_session_snapshot",
  )
  assert_eq(
    json_string(readiness, "next_owner", default=""),
    "mooncode-moonbook",
  )
  let actions = runtime_json_array_items(response, "actions")
  assert_eq(actions.length(), 1)
  assert_eq(json_string(actions[0], "runtime_state", default=""), "claimed")
}

///|
test "mooncode action plan recommends a next turn for deferred steering" {
  let response = action_plan_response(
    "session-deferred",
    {
      "id": "session-deferred",
      "workspace_id": "book-demo",
      "workspace_name": "Demo Book",
      "mooncode_runtime_session_id": "runtime-demo",
    },
    [{ "command_id": "cmd-steer", "action": "steer", "state": "completed" }],
    {
      "verified_test_count": 0,
      "failed_test_count": 0,
      "pending_diff_count": 0,
      "pending_tool_approval_count": 0,
      "pending_steer_count": 1,
      "deferred_steer_count": 1,
      "source_bound_package_count": 0,
    },
    [],
    [],
    recorded_at="2026-06-16T00:00:00Z",
    runtime_command_log_path="/tmp/session/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/session/runtime-receipt.jsonl",
  )
  assert_eq(
    json_string(response, "next_required_action", default=""),
    "start_next_turn_for_deferred_steering",
  )
  let recommended = runtime_json_object_field_or_empty(
    response, "recommended_command",
  )
  assert_eq(json_string(recommended, "action", default=""), "prompt")
  assert_eq(
    json_string(recommended, "ui_action", default=""),
    "mooncode_command",
  )
  assert_eq(json_string(recommended, "label", default=""), "Start Next Turn")
  assert_eq(
    json_string(recommended, "status", default=""),
    "queued next MoonCode turn for deferred steering",
  )
  assert_true(json_string(recommended, "message", default="").length() > 0)
}

///|
test "mooncode action plan recommends runtime loop and repair prompts" {
  let control = action_plan_recommended_command(
    "run_or_replay_runtime_commands",
  )
  assert_true(json_bool(control, "available", default=false))
  assert_eq(json_string(control, "ui_action", default=""), "runtime_loop")
  assert_eq(json_string(control, "label", default=""), "Run Native Loop")
  let runtime_commands = action_plan_recommended_commands(
    "run_or_replay_runtime_commands",
  )
  assert_eq(runtime_commands.length(), 2)
  assert_eq(
    json_string(runtime_commands[0], "ui_action", default=""),
    "runtime_loop",
  )
  assert_eq(
    json_string(runtime_commands[1], "ui_action", default=""),
    "runtime_service",
  )
  assert_eq(
    json_string(runtime_commands[1], "label", default=""),
    "Start Service",
  )
  let proof = action_plan_recommended_command("await_runtime_proof")
  assert_eq(json_string(proof, "ui_action", default=""), "runtime_loop")
  assert_eq(json_string(proof, "label", default=""), "Refresh Proof")
  let proof_commands = action_plan_recommended_commands("await_runtime_proof")
  assert_eq(proof_commands.length(), 2)
  assert_eq(
    json_string(proof_commands[1], "ui_action", default=""),
    "runtime_service",
  )
  let eval = action_plan_recommended_command("run_native_eval")
  assert_eq(json_string(eval, "ui_action", default=""), "mooncode_command")
  assert_eq(json_string(eval, "action", default=""), "run_eval")
  assert_eq(json_string(eval, "label", default=""), "Run Eval")
  let eval_commands = action_plan_recommended_commands("run_native_eval")
  assert_eq(eval_commands.length(), 2)
  assert_eq(
    json_string(eval_commands[1], "ui_action", default=""),
    "runtime_service",
  )
  let retry_commands = action_plan_recommended_commands(
    "retry_failed_runtime_receipt",
  )
  assert_eq(retry_commands.length(), 2)
  assert_eq(
    json_string(retry_commands[0], "label", default=""),
    "Retry Runtime",
  )
  assert_eq(
    json_string(retry_commands[1], "label", default=""),
    "Start Service",
  )
  let failed_tests = action_plan_recommended_command("fix_failed_tests")
  assert_eq(
    json_string(failed_tests, "ui_action", default=""),
    "mooncode_command",
  )
  assert_eq(json_string(failed_tests, "action", default=""), "prompt")
  assert_eq(json_string(failed_tests, "label", default=""), "Fix Tests")
  assert_true(
    json_string(failed_tests, "message", default="").contains("failing"),
  )
  let resume_command = action_plan_recommended_command(
    "start_or_resume_session",
  )
  assert_eq(json_string(resume_command, "action", default=""), "prompt")
  assert_eq(json_string(resume_command, "label", default=""), "Resume")
  let review = action_plan_recommended_command("accept_or_reject_changes")
  assert_false(json_bool(review, "available", default=true))
}

///|
test "mooncode action plan recommends native eval for readiness gap" {
  let response = action_plan_response(
    "session-eval",
    {
      "id": "session-eval",
      "workspace_id": "book-demo",
      "workspace_name": "Demo Book",
      "mooncode_runtime_session_id": "runtime-demo",
    },
    [
      { "command_id": "cmd-tests", "action": "run_tests", "state": "completed" },
      { "command_id": "cmd-package", "action": "package", "state": "completed" },
    ],
    {
      "verified_test_count": 1,
      "failed_test_count": 0,
      "pending_diff_count": 0,
      "pending_tool_approval_count": 0,
      "pending_steer_count": 0,
      "deferred_steer_count": 0,
      "source_bound_package_count": 1,
      "readiness": {
        "kind": "mooncode-readiness",
        "ready": false,
        "first_blocker_id": "native_eval_ready",
        "next_action": "run_native_eval",
        "next_owner": "moonclaw",
      },
    },
    [],
    [],
    recorded_at="2026-06-16T00:00:00Z",
    runtime_command_log_path="/tmp/session/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/session/runtime-receipt.jsonl",
  )
  assert_eq(
    json_string(response, "next_required_action", default=""),
    "run_native_eval",
  )
  let recommended = runtime_json_object_field_or_empty(
    response, "recommended_command",
  )
  assert_eq(json_string(recommended, "action", default=""), "run_eval")
  assert_eq(
    json_string(recommended, "ui_action", default=""),
    "mooncode_command",
  )
  assert_eq(json_string(recommended, "label", default=""), "Run Eval")
  let recommended_commands = runtime_json_array_items(
    response, "recommended_commands",
  )
  assert_eq(recommended_commands.length(), 2)
  assert_eq(
    json_string(recommended_commands[1], "ui_action", default=""),
    "runtime_service",
  )
}

///|
test "mooncode action plan keeps awaiting proof ahead of native eval recommendation" {
  let response = action_plan_response(
    "session-eval",
    {
      "id": "session-eval",
      "workspace_id": "book-demo",
      "workspace_name": "Demo Book",
      "mooncode_runtime_session_id": "runtime-demo",
    },
    [
      {
        "command_id": "cmd-eval",
        "action": "run_eval",
        "state": "awaiting-proof",
      },
    ],
    {
      "verified_test_count": 1,
      "failed_test_count": 0,
      "pending_diff_count": 0,
      "pending_tool_approval_count": 0,
      "pending_steer_count": 0,
      "deferred_steer_count": 0,
      "source_bound_package_count": 1,
      "readiness": {
        "kind": "mooncode-readiness",
        "ready": false,
        "first_blocker_id": "native_eval_ready",
        "next_action": "run_native_eval",
      },
    },
    [],
    [],
    recorded_at="2026-06-16T00:00:00Z",
    runtime_command_log_path="/tmp/session/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/session/runtime-receipt.jsonl",
  )
  assert_eq(
    json_string(response, "next_required_action", default=""),
    "await_runtime_proof",
  )
  let recommended = runtime_json_object_field_or_empty(
    response, "recommended_command",
  )
  assert_eq(json_string(recommended, "action", default=""), "runtime_loop")
}

///|
test "mooncode action plan recommends review and tool approval choices" {
  let review_commands = action_plan_recommended_commands(
    "accept_or_reject_changes",
  )
  assert_eq(review_commands.length(), 2)
  assert_eq(json_string(review_commands[0], "action", default=""), "accept")
  assert_eq(json_string(review_commands[0], "label", default=""), "Accept")
  assert_eq(json_string(review_commands[1], "action", default=""), "reject")
  assert_eq(json_string(review_commands[1], "label", default=""), "Reject")
  let tool_commands = action_plan_recommended_commands("resolve_tool_approvals")
  assert_eq(tool_commands.length(), 2)
  assert_eq(json_string(tool_commands[0], "action", default=""), "approve_tool")
  assert_eq(json_string(tool_commands[1], "action", default=""), "reject_tool")
  let ready_commands = action_plan_recommended_commands("ready_for_book_review")
  assert_eq(ready_commands.length(), 2)
  assert_eq(json_string(ready_commands[0], "action", default=""), "package")
  assert_eq(json_string(ready_commands[1], "action", default=""), "commit")
}

///|
test "mooncode action plan response carries multi-choice recommendations" {
  let response = action_plan_response(
    "session-review",
    {
      "id": "session-review",
      "workspace_id": "book-demo",
      "workspace_name": "Demo Book",
      "mooncode_runtime_session_id": "runtime-demo",
    },
    [{ "command_id": "cmd-review", "action": "prompt", "state": "completed" }],
    {
      "verified_test_count": 1,
      "failed_test_count": 0,
      "pending_diff_count": 1,
      "pending_tool_approval_count": 0,
      "pending_steer_count": 0,
      "deferred_steer_count": 0,
      "source_bound_package_count": 1,
    },
    [],
    [],
    recorded_at="2026-06-16T00:00:00Z",
    runtime_command_log_path="/tmp/session/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/session/runtime-receipt.jsonl",
  )
  assert_eq(
    json_string(response, "next_required_action", default=""),
    "accept_or_reject_changes",
  )
  assert_false(
    json_bool(
      runtime_json_object_field_or_empty(response, "recommended_command"),
      "available",
      default=true,
    ),
  )
  let commands = runtime_json_array_items(response, "recommended_commands")
  assert_eq(commands.length(), 2)
  assert_eq(json_string(commands[0], "action", default=""), "accept")
  assert_eq(json_string(commands[1], "action", default=""), "reject")
}

///|
test "mooncode action plan blocks partial patch lifecycle" {
  let response = action_plan_response(
    "session-partial",
    {
      "id": "session-partial",
      "workspace_id": "book-demo",
      "workspace_name": "Demo Book",
      "mooncode_runtime_session_id": "runtime-demo",
    },
    [{ "command_id": "cmd-review", "action": "prompt", "state": "completed" }],
    {
      "verified_test_count": 1,
      "failed_test_count": 0,
      "pending_diff_count": 0,
      "pending_tool_approval_count": 0,
      "pending_steer_count": 0,
      "deferred_steer_count": 0,
      "source_bound_package_count": 1,
      "patch_lifecycle": {
        "kind": "mooncode-patch-lifecycle",
        "needs_review_count": 0,
        "runtime_needed_count": 0,
        "partial_count": 1,
        "partial_patch_count": 1,
        "runtime_partial_patch_count": 1,
      },
    },
    [],
    [],
    recorded_at="2026-06-18T00:00:00Z",
    runtime_command_log_path="/tmp/session/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/session/runtime-receipt.jsonl",
  )
  assert_eq(
    json_string(response, "next_required_action", default=""),
    "accept_or_reject_changes",
  )
  assert_eq(runtime_json_int(response, "pending_diff_count", default=9), 0)
  assert_eq(
    runtime_json_int(response, "patch_needs_review_count", default=9),
    0,
  )
  assert_eq(
    runtime_json_int(response, "patch_runtime_needed_count", default=9),
    0,
  )
  assert_eq(runtime_json_int(response, "partial_patch_count", default=0), 1)
  assert_eq(
    runtime_json_int(response, "runtime_partial_patch_count", default=0),
    1,
  )
  let commands = runtime_json_array_items(response, "recommended_commands")
  assert_eq(commands.length(), 2)
  assert_eq(json_string(commands[0], "action", default=""), "accept")
  assert_eq(json_string(commands[1], "action", default=""), "reject")
  let readiness = runtime_json_object_field_or_empty(response, "readiness")
  assert_false(json_bool(readiness, "ready", default=true))
  assert_eq(
    json_string(readiness, "next_action", default=""),
    "accept_or_reject_changes",
  )
}
