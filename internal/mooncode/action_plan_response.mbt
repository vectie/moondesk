///|
// MoonCode action-plan aggregate response and review summary projection.

///|
pub fn action_plan_status(
  pending_runtime_count : Int,
  running_count : Int,
  blocked_count : Int,
  ready_for_review_count : Int,
  completed_count : Int,
  action_count : Int,
) -> String {
  if blocked_count > 0 {
    "blocked"
  } else if running_count > 0 {
    "running"
  } else if pending_runtime_count > 0 {
    "queued"
  } else if ready_for_review_count > 0 {
    "review-ready"
  } else if action_count > 0 && completed_count == action_count {
    "complete"
  } else if action_count > 0 {
    "waiting-for-proof"
  } else {
    "empty"
  }
}

///|
pub fn action_plan_state_count(actions : Array[Json], state : String) -> Int {
  let mut count = 0
  for action in actions {
    if json_string(action, "state", default="") == state {
      count += 1
    }
  }
  count
}

///|
pub fn action_plan_command_count(
  actions : Array[Json],
  command : String,
) -> Int {
  let mut count = 0
  for action in actions {
    if json_string(action, "action", default="") == command {
      count += 1
    }
  }
  count
}

///|
pub fn action_plan_review_count(actions : Array[Json]) -> Int {
  let mut count = 0
  for action in actions {
    if json_string(action, "approval", default="") == "operator" {
      count += 1
    }
  }
  count
}

///|
pub fn action_plan_next_required_action(
  summary : Json,
  actions : Array[Json],
) -> String {
  if action_plan_state_count(actions, "queued-for-runtime") > 0 {
    return "dispatch_or_replay_runtime_commands"
  }
  if action_plan_state_count(actions, "runtime-retry") > 0 {
    return "retry_failed_runtime_dispatch"
  }
  if action_plan_state_count(actions, "awaiting-proof") > 0 {
    return "await_runtime_proof"
  }
  if runtime_json_int(summary, "failed_test_count", default=0) > 0 {
    return "fix_failed_tests"
  }
  if runtime_json_int(summary, "pending_tool_approval_count", default=0) > 0 {
    return "resolve_tool_approvals"
  }
  if runtime_json_int(summary, "pending_diff_count", default=0) > 0 &&
    runtime_json_int(summary, "verified_test_count", default=0) == 0 {
    return "run_tests"
  }
  if runtime_json_int(summary, "pending_diff_count", default=0) > 0 {
    return "accept_or_reject_changes"
  }
  if runtime_json_int(summary, "source_bound_package_count", default=0) == 0 &&
    actions.length() > 0 {
    return "package_executable_output"
  }
  if action_plan_command_count(actions, "commit") > 0 &&
    runtime_json_int(summary, "runtime_commit_proof_count", default=0) == 0 {
    return "await_commit_proof"
  }
  if actions.length() == 0 {
    "start_or_resume_session"
  } else {
    "ready_for_book_review"
  }
}

///|
pub fn action_plan_response(
  session_id : String,
  session : Json,
  actions : Array[Json],
  summary : Json,
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  recorded_at~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
) -> Json {
  let pending_runtime_count = action_plan_state_count(
      actions, "queued-for-runtime",
    ) +
    action_plan_state_count(actions, "runtime-retry")
  let running_count = action_plan_state_count(actions, "running")
  let blocked_count = action_plan_state_count(actions, "blocked")
  let ready_for_review_count = action_plan_state_count(
    actions, "ready-for-review",
  )
  let completed_count = action_plan_state_count(actions, "completed")
  {
    "kind": "mooncode-action-plan",
    "protocol": "mooncode.v1",
    "status": action_plan_status(
      pending_runtime_count,
      running_count,
      blocked_count,
      ready_for_review_count,
      completed_count,
      actions.length(),
    ),
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": "",
    "absolute_manifest_path": "",
    "action_count": actions.length(),
    "pending_runtime_count": pending_runtime_count,
    "running_count": running_count,
    "blocked_count": blocked_count,
    "ready_for_review_count": ready_for_review_count,
    "completed_count": completed_count,
    "run_test_command_count": action_plan_command_count(actions, "run_tests"),
    "package_command_count": action_plan_command_count(actions, "package"),
    "commit_command_count": action_plan_command_count(actions, "commit"),
    "accept_command_count": action_plan_command_count(actions, "accept"),
    "review_command_count": action_plan_review_count(actions),
    "verified_test_count": runtime_json_int(
      summary,
      "verified_test_count",
      default=0,
    ),
    "failed_test_count": runtime_json_int(
      summary,
      "failed_test_count",
      default=0,
    ),
    "pending_diff_count": runtime_json_int(
      summary,
      "pending_diff_count",
      default=0,
    ),
    "pending_tool_approval_count": runtime_json_int(
      summary,
      "pending_tool_approval_count",
      default=0,
    ),
    "source_bound_package_count": runtime_json_int(
      summary,
      "source_bound_package_count",
      default=0,
    ),
    "next_required_action": action_plan_next_required_action(summary, actions),
    "actions": Json::array(actions),
    "runtime_replay": runtime_replay_state(
      session_id,
      runtime_commands,
      runtime_dispatches,
      workspace_id=json_string(session, "workspace_id", default=""),
      workspace_name=json_string(session, "workspace_name", default=""),
      task_id=json_string(session, "moonclaw_task_id", default=""),
      runtime_command_log_path~,
      runtime_dispatch_log_path~,
    ),
    "acceptance_gates": command_acceptance_gates(summary),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "extractable_component": "mooncode",
    },
    "rule": "This plan is Moondesk's compact execution/review contract. MoonClaw or standalone MoonCode consumes the command queue, emits proof events, then Moondesk updates this plan without executing tools itself.",
  }
}

///|
fn action_plan_json_array(json : Json, key : String) -> Json {
  match runtime_json_object_field(json, key) {
    Some(Json::Array(items)) => Json::array(items)
    _ => Json::array([])
  }
}

///|
fn action_plan_string_array_json(items : Array[String]) -> Json {
  Json::array([ for item in items => item.to_json() ])
}

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
  assert_eq(
    json_string(response, "next_required_action", default=""),
    "package_executable_output",
  )
  assert_true(runtime_json_object_field(response, "runtime_replay") is Some(_))
  assert_true(
    runtime_json_object_field(response, "acceptance_gates") is Some(_),
  )
}
