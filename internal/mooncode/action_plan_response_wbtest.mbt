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
      "moonclaw_task_id": "task-demo",
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
    runtime_dispatch_log_path="/tmp/session/runtime-dispatch.jsonl",
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
    "moonclaw_task_id": "task-demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_command(),
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
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
      "dispatch": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "build" },
    },
  ]
  let runtime_dispatches : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_runtime_dispatch(),
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
    runtime_dispatches,
    [],
    recorded_at="2026-06-16T00:01:00Z",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatch.jsonl",
    lease_now="2026-06-16T00:02:00Z",
  )
  assert_eq(json_string(response, "status", default=""), "running")
  assert_eq(runtime_json_int(response, "action_count", default=0), 1)
  assert_eq(runtime_json_int(response, "running_count", default=0), 1)
  assert_eq(
    json_string(response, "next_required_action", default=""),
    "package_executable_output",
  )
  let actions = runtime_json_array_items(response, "actions")
  assert_eq(actions.length(), 1)
  assert_eq(json_string(actions[0], "runtime_state", default=""), "claimed")
}
