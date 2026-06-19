///|
// MoonCode action-plan readiness derivation and next-owner projection.

///|
fn action_plan_readiness(
  summary : Json,
  actions : Array[Json],
  next_required_action : String,
) -> Json {
  match runtime_json_object_field(summary, "readiness") {
    Some(readiness) => readiness
    None => action_plan_derived_readiness(actions, next_required_action)
  }
}

///|
fn action_plan_next_required_action_with_readiness(
  readiness : Json,
  base_next_required_action : String,
) -> String {
  match base_next_required_action {
    "run_or_replay_runtime_commands"
    | "retry_failed_runtime_receipt"
    | "await_runtime_proof"
    | "start_next_turn_for_deferred_steering"
    | "fix_failed_tests"
    | "run_tests"
    | "resolve_tool_approvals"
    | "accept_or_reject_changes"
    | "await_commit_proof"
    | "start_or_resume_session" => base_next_required_action
    _ =>
      match json_string(readiness, "first_blocker_id", default="") {
        "native_eval_ready" => "run_native_eval"
        _ => base_next_required_action
      }
  }
}

///|
fn action_plan_derived_readiness(
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
    "kind": "mooncode-readiness",
    "protocol": protocol_version(),
    "standalone_component": "mooncode",
    "source": "action-plan-derived",
    "ready": ready,
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
    "rule": "Action-plan readiness is derived from command state when the session summary has not supplied a richer readiness object.",
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
    "run_or_replay_runtime_commands"
    | "retry_failed_runtime_receipt"
    | "await_runtime_proof"
    | "start_next_turn_for_deferred_steering" => "moonclaw"
    "fix_failed_tests" | "run_tests" => "moonclaw"
    "run_native_eval" => "moonclaw"
    "package_executable_output" => "moonbook-moonclaw"
    "resolve_tool_approvals" | "accept_or_reject_changes" => "moondesk"
    "await_commit_proof" => "moonclaw"
    "start_or_resume_session" => "moondesk-moonclaw"
    "ready_for_book_review" => "moondesk-moonbook"
    _ => "mooncode"
  }
}
