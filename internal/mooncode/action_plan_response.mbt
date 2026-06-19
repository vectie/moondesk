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
  let patch_lifecycle = runtime_json_object_field_or_empty(
    summary, "patch_lifecycle",
  )
  let patch_needs_review_count = runtime_json_int(
      patch_lifecycle,
      "needs_review_count",
      default=0,
    ) +
    runtime_json_int(patch_lifecycle, "partial_count", default=0)
  let patch_runtime_needed_count = runtime_json_int(
    patch_lifecycle,
    "runtime_needed_count",
    default=0,
  )
  if action_plan_state_count(actions, "queued-for-runtime") > 0 {
    return "dispatch_or_replay_runtime_commands"
  }
  if action_plan_state_count(actions, "runtime-retry") > 0 {
    return "retry_failed_runtime_dispatch"
  }
  if action_plan_state_count(actions, "awaiting-proof") > 0 {
    return "await_runtime_proof"
  }
  if runtime_json_int(summary, "deferred_steer_count", default=0) > 0 &&
    runtime_json_int(summary, "pending_steer_count", default=0) > 0 {
    return "start_next_turn_for_deferred_steering"
  }
  if runtime_json_int(summary, "failed_test_count", default=0) > 0 {
    return "fix_failed_tests"
  }
  if runtime_json_int(summary, "pending_tool_approval_count", default=0) > 0 {
    return "resolve_tool_approvals"
  }
  if patch_needs_review_count > 0 {
    return "accept_or_reject_changes"
  }
  if patch_runtime_needed_count > 0 {
    return "await_runtime_proof"
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
  let base_next_required_action = action_plan_next_required_action(
    summary, actions,
  )
  let patch_lifecycle = runtime_json_object_field_or_empty(
    summary, "patch_lifecycle",
  )
  let patch_needs_review_count = runtime_json_int(
    patch_lifecycle,
    "needs_review_count",
    default=0,
  )
  let patch_runtime_needed_count = runtime_json_int(
    patch_lifecycle,
    "runtime_needed_count",
    default=0,
  )
  let partial_patch_count = runtime_json_int(
    patch_lifecycle,
    "partial_patch_count",
    default=0,
  )
  let runtime_partial_patch_count = runtime_json_int(
    patch_lifecycle,
    "runtime_partial_patch_count",
    default=0,
  )
  let readiness = action_plan_readiness(
    summary, actions, base_next_required_action,
  )
  let next_required_action = action_plan_next_required_action_with_readiness(
    readiness, base_next_required_action,
  )
  {
    "kind": "mooncode-action-plan",
    "protocol": protocol_version(),
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
    "runtime_session_id": session_runtime_session_id(session),
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
    "patch_needs_review_count": patch_needs_review_count,
    "patch_runtime_needed_count": patch_runtime_needed_count,
    "partial_patch_count": partial_patch_count,
    "runtime_partial_patch_count": runtime_partial_patch_count,
    "pending_tool_approval_count": runtime_json_int(
      summary,
      "pending_tool_approval_count",
      default=0,
    ),
    "pending_steer_count": runtime_json_int(
      summary,
      "pending_steer_count",
      default=0,
    ),
    "deferred_steer_count": runtime_json_int(
      summary,
      "deferred_steer_count",
      default=0,
    ),
    "source_bound_package_count": runtime_json_int(
      summary,
      "source_bound_package_count",
      default=0,
    ),
    "next_required_action": next_required_action,
    "readiness": readiness,
    "recommended_command": action_plan_recommended_command(next_required_action),
    "recommended_commands": Json::array(
      action_plan_recommended_commands(next_required_action),
    ),
    "actions": Json::array(actions),
    "runtime_replay": runtime_replay_state(
      session_id,
      runtime_commands,
      runtime_dispatches,
      workspace_id=json_string(session, "workspace_id", default=""),
      workspace_name=json_string(session, "workspace_name", default=""),
      runtime_session_id=session_runtime_session_id(session),
      runtime_command_log_path~,
      runtime_dispatch_log_path~,
    ),
    "acceptance_gates": command_acceptance_gates(summary),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "standalone_component": "mooncode",
    },
    "rule": "This plan is Moondesk's compact execution/review contract. MoonClaw consumes the command queue, emits proof events, then Moondesk updates this plan without executing tools itself.",
  }
}

///|
pub fn action_plan_actions_for_session(
  session : Json,
  commands : Array[Json],
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  events : Array[Json],
  lease_now? : String = "",
) -> Array[Json] {
  let summary = session_summary(session, events)
  action_plan_items(
    commands,
    runtime_commands,
    runtime_dispatches,
    events,
    summary,
    lease_now~,
  )
}

///|
pub fn action_plan_projection_response(
  session_id : String,
  session : Json,
  commands : Array[Json],
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  events : Array[Json],
  recorded_at~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  lease_now? : String = "",
) -> Json {
  let summary = session_summary(session, events)
  let actions = action_plan_items(
    commands,
    runtime_commands,
    runtime_dispatches,
    events,
    summary,
    lease_now~,
  )
  action_plan_response(
    session_id,
    session,
    actions,
    summary,
    runtime_commands,
    runtime_dispatches,
    recorded_at~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
  )
}

///|
pub fn action_plan_manifest_response(
  action_plan : Json,
  manifest_path : String,
  absolute_manifest_path : String,
) -> Json {
  action_plan
  |> runtime_with_field("manifest_path", manifest_path.to_json())
  |> runtime_with_field(
    "absolute_manifest_path",
    absolute_manifest_path.to_json(),
  )
}

///|
fn action_plan_json_array(json : Json, key : String) -> Json {
  match runtime_json_object_field(json, key) {
    Some(Array(items)) => Json::array(items)
    _ => Json::array([])
  }
}

///|
fn action_plan_string_array_json(items : Array[String]) -> Json {
  Json::array([ for item in items => item.to_json() ])
}
