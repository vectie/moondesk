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
pub fn action_plan_recommended_command(next_required_action : String) -> Json {
  match next_required_action {
    "dispatch_or_replay_runtime_commands" =>
      {
        "available": true,
        "ui_action": "runtime_loop",
        "action": "runtime_loop",
        "label": "Run Native Loop",
        "context_path": "",
        "message": "",
        "status": "running MoonClaw native MoonCode loop",
      }
    "retry_failed_runtime_dispatch" =>
      {
        "available": true,
        "ui_action": "runtime_loop",
        "action": "runtime_loop",
        "label": "Retry Runtime",
        "context_path": "",
        "message": "",
        "status": "retrying failed MoonCode runtime dispatch",
      }
    "await_runtime_proof" =>
      {
        "available": true,
        "ui_action": "runtime_loop",
        "action": "runtime_loop",
        "label": "Refresh Proof",
        "context_path": "",
        "message": "",
        "status": "refreshing MoonCode runtime proof",
      }
    "start_next_turn_for_deferred_steering" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "prompt",
        "label": "Start Next Turn",
        "context_path": "",
        "message": "Continue this MoonCode session and apply the deferred steering already saved in the command queue.",
        "status": "queued next MoonCode turn for deferred steering",
      }
    "fix_failed_tests" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "prompt",
        "label": "Fix Tests",
        "context_path": "",
        "message": "Inspect the failing MoonCode test evidence, edit the relevant files, and rerun the appropriate tests until they pass.",
        "status": "queued MoonCode test-fix prompt",
      }
    "run_tests" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "run_tests",
        "label": "Run Tests",
        "context_path": "",
        "message": "",
        "status": "queued MoonCode tests from action plan",
      }
    "package_executable_output" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "package",
        "label": "Package",
        "context_path": "",
        "message": "",
        "status": "queued MoonCode package from action plan",
      }
    "run_native_eval" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "run_eval",
        "label": "Run Eval",
        "context_path": "",
        "message": "",
        "status": "queued MoonCode native eval from action plan",
      }
    "start_or_resume_session" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "prompt",
        "label": "Resume",
        "context_path": "",
        "message": "Resume this MoonCode session for the selected MoonBook and propose the next executable-code change.",
        "status": "queued MoonCode resume prompt",
      }
    _ =>
      {
        "available": false,
        "ui_action": "",
        "action": "",
        "label": "",
        "context_path": "",
        "message": "",
        "status": "",
      }
  }
}

///|
fn action_plan_runtime_service_command(status : String) -> Json {
  {
    "available": true,
    "ui_action": "runtime_service",
    "action": "runtime_service",
    "label": "Start Service",
    "context_path": "",
    "message": "",
    "status": status,
  }
}

///|
pub fn action_plan_recommended_commands(
  next_required_action : String,
) -> Array[Json] {
  match next_required_action {
    "dispatch_or_replay_runtime_commands" =>
      [
        action_plan_recommended_command(next_required_action),
        action_plan_runtime_service_command(
          "starting MoonClaw native MoonCode service",
        ),
      ]
    "retry_failed_runtime_dispatch" =>
      [
        action_plan_recommended_command(next_required_action),
        action_plan_runtime_service_command(
          "starting MoonClaw native MoonCode service for retry",
        ),
      ]
    "await_runtime_proof" =>
      [
        action_plan_recommended_command(next_required_action),
        action_plan_runtime_service_command(
          "starting MoonClaw native MoonCode service for proof refresh",
        ),
      ]
    "run_native_eval" =>
      [
        action_plan_recommended_command(next_required_action),
        action_plan_runtime_service_command(
          "starting MoonClaw native MoonCode service for eval proof",
        ),
      ]
    "resolve_tool_approvals" =>
      [
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "approve_tool",
          "label": "Approve Tool",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode tool approval",
        },
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "reject_tool",
          "label": "Reject Tool",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode tool rejection",
        },
      ]
    "accept_or_reject_changes" =>
      [
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "accept",
          "label": "Accept",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode accept from action plan",
        },
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "reject",
          "label": "Reject",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode reject from action plan",
        },
      ]
    "ready_for_book_review" =>
      [
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "package",
          "label": "Package",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode package from review-ready plan",
        },
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "commit",
          "label": "Commit",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode commit from review-ready plan",
        },
      ]
    _ => {
      let primary = action_plan_recommended_command(next_required_action)
      if json_bool(primary, "available", default=false) {
        [primary]
      } else {
        []
      }
    }
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
  let production_readiness = action_plan_production_readiness(
    summary, actions, base_next_required_action,
  )
  let next_required_action = action_plan_next_required_action_with_readiness(
    production_readiness, base_next_required_action,
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
    "production_readiness": production_readiness,
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
fn action_plan_production_readiness(
  summary : Json,
  actions : Array[Json],
  next_required_action : String,
) -> Json {
  match runtime_json_object_field(summary, "production_readiness") {
    Some(readiness) => readiness
    None =>
      action_plan_fallback_production_readiness(actions, next_required_action)
  }
}

///|
fn action_plan_next_required_action_with_readiness(
  production_readiness : Json,
  base_next_required_action : String,
) -> String {
  match base_next_required_action {
    "dispatch_or_replay_runtime_commands"
    | "retry_failed_runtime_dispatch"
    | "await_runtime_proof"
    | "start_next_turn_for_deferred_steering"
    | "fix_failed_tests"
    | "run_tests"
    | "resolve_tool_approvals"
    | "accept_or_reject_changes"
    | "await_commit_proof"
    | "start_or_resume_session" => base_next_required_action
    _ =>
      match json_string(production_readiness, "first_blocker_id", default="") {
        "native_eval_ready" => "run_native_eval"
        _ => base_next_required_action
      }
  }
}

///|
fn action_plan_fallback_production_readiness(
  actions : Array[Json],
  next_required_action : String,
) -> Json {
  let blocked_count = action_plan_state_count(actions, "blocked") +
    action_plan_state_count(actions, "runtime-retry") +
    action_plan_state_count(actions, "awaiting-proof") +
    action_plan_state_count(actions, "queued-for-runtime")
  let ready = actions.length() > 0 &&
    blocked_count == 0 &&
    next_required_action == "ready_for_book_review"
  let blocker = action_plan_first_blocking_action(actions)
  let blocker_state = json_string(blocker, "state", default="")
  {
    "kind": "mooncode-production-readiness",
    "protocol": protocol_version(),
    "extractable_component": "mooncode",
    "source": "action-plan-fallback",
    "ready": ready,
    "score": if ready {
      100
    } else {
      0
    },
    "level": if ready {
      "production-grade"
    } else {
      "action-plan-blocked"
    },
    "passed_count": if ready {
      actions.length()
    } else {
      0
    },
    "check_count": actions.length(),
    "blocked_count": blocked_count,
    "first_blocker_id": json_string(blocker, "command_id", default=""),
    "first_blocker_label": action_plan_blocker_label(blocker),
    "first_blocker_evidence": json_string(
      blocker,
      "blocking_reason",
      default="",
    ),
    "next_action": next_required_action,
    "next_owner": action_plan_next_owner(next_required_action),
    "blocking_check_ids": Json::array(
      if blocker_state == "" {
        []
      } else {
        [Json::string(blocker_state)]
      },
    ),
    "rule": "Fallback action-plan readiness is derived only from command state. Full production readiness comes from the MoonCode session summary when available.",
  }
}

///|
fn action_plan_first_blocking_action(actions : Array[Json]) -> Json {
  for
    state in [
      "blocked", "runtime-retry", "awaiting-proof", "queued-for-runtime",
    ] {
    for action in actions {
      if json_string(action, "state", default="") == state {
        return action
      }
    }
  }
  {}
}

///|
fn action_plan_blocker_label(action : Json) -> String {
  let command_id = json_string(action, "command_id", default="")
  let command = json_string(action, "action", default="")
  if command_id == "" && command == "" {
    ""
  } else if command_id == "" {
    command
  } else if command == "" {
    command_id
  } else {
    "\{command}: \{command_id}"
  }
}

///|
fn action_plan_next_owner(next_required_action : String) -> String {
  match next_required_action {
    "dispatch_or_replay_runtime_commands"
    | "retry_failed_runtime_dispatch"
    | "await_runtime_proof"
    | "start_next_turn_for_deferred_steering" =>
      "moonclaw-or-standalone-mooncode"
    "fix_failed_tests" | "run_tests" => "moonclaw"
    "run_native_eval" => "moonclaw-or-standalone-mooncode"
    "package_executable_output" => "moonbook-moonclaw"
    "resolve_tool_approvals" | "accept_or_reject_changes" => "moondesk"
    "await_commit_proof" => "moonclaw"
    "start_or_resume_session" => "moondesk-moonclaw"
    "ready_for_book_review" => "moondesk-moonbook"
    _ => "mooncode"
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
    Some(Json::Array(items)) => Json::array(items)
    _ => Json::array([])
  }
}

///|
fn action_plan_string_array_json(items : Array[String]) -> Json {
  Json::array([ for item in items => item.to_json() ])
}
