///|
pub fn command_preflight(
  session_id~ : String,
  action~ : String,
  context_path~ : String,
  summary~ : Json,
  patch_entries~ : Array[Json],
) -> Json {
  let selected_patch = command_preflight_selected_patch(
    context_path, patch_entries,
  )
  let reason = command_preflight_blocking_reason(
    action~,
    context_path~,
    summary~,
    patch_entries~,
  )
  let blocked = reason != ""
  {
    "kind": "mooncode-command-preflight",
    "protocol": protocol_version(),
    "action": action,
    "session_id": session_id,
    "allowed": !blocked,
    "blocked": blocked,
    "reason": reason,
    "context_path": context_path,
    "acceptance_gates": command_acceptance_gates(summary),
    "selected_patch": selected_patch,
    "summary": summary,
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "review": "moonbook",
      "extractable_component": "mooncode",
    },
  }
}

///|
pub fn command_preflight_for_session(
  session : Json,
  payload : Json,
  events : Array[Json],
  action~ : String,
) -> Json {
  let summary = session_summary(session, events)
  command_preflight(
    session_id=json_string(session, "id", default=""),
    action~,
    context_path=command_context_path(payload),
    summary~,
    patch_entries=patch_set_entries(events),
  )
}

///|
pub fn command_preflight_blocking_reason(
  action~ : String,
  context_path~ : String,
  summary~ : Json,
  patch_entries~ : Array[Json],
) -> String {
  let failed_tests = runtime_json_int(summary, "failed_test_count", default=0)
  let pending_approvals = runtime_json_int(
    summary,
    "pending_tool_approval_count",
    default=0,
  )
  let pending_diffs = runtime_json_int(summary, "pending_diff_count", default=0)
  let diff_count = runtime_json_int(summary, "diff_count", default=0)
  let accepted_reviews = runtime_json_int(
    summary,
    "accepted_review_count",
    default=0,
  )
  let verified_tests = runtime_json_int(
    summary,
    "verified_test_count",
    default=0,
  )
  match action {
    "accept" | "package" | "commit" => {
      if failed_tests > 0 {
        return "fix failing test/build results before \{action}"
      }
      if pending_approvals > 0 {
        return "resolve pending tool approvals before \{action}"
      }
      if pending_diffs > 0 && verified_tests == 0 {
        return "run tests/builds before \{action} for pending file changes"
      }
      if action == "commit" && diff_count > 0 && accepted_reviews == 0 {
        return "accept reviewed file changes before commit"
      }
      let patch_reason = command_preflight_selected_patch_blocking_reason(
        action, context_path, patch_entries,
      )
      if patch_reason != "" {
        return patch_reason
      }
      ""
    }
    "apply_patch" | "revert_patch" => {
      if context_path == "" {
        return "select a patch path before \{action}"
      }
      if !command_preflight_has_patch_target(patch_entries, context_path) {
        return "no MoonCode patch candidate exists for \{context_path}"
      }
      let patch_state = command_preflight_patch_target_state(
        patch_entries, context_path,
      )
      if action == "apply_patch" && patch_state != "accepted" {
        return "accept patch target before apply_patch: \{context_path} is \{patch_state}"
      }
      if action == "revert_patch" && patch_state != "applied" {
        return "apply patch target before revert_patch: \{context_path} is \{patch_state}"
      }
      ""
    }
    _ => ""
  }
}

///|
pub fn command_acceptance_gates(summary : Json) -> Json {
  {
    "no_failing_tests": runtime_json_int(
      summary,
      "failed_test_count",
      default=0,
    ) ==
    0,
    "has_verified_tests": runtime_json_int(
      summary,
      "verified_test_count",
      default=0,
    ) >
    0,
    "tool_approvals_resolved": runtime_json_int(
      summary,
      "pending_tool_approval_count",
      default=0,
    ) ==
    0,
    "diffs_resolved": runtime_json_int(summary, "pending_diff_count", default=0) ==
    0,
    "has_source_bound_package": runtime_json_int(
      summary,
      "source_bound_package_count",
      default=0,
    ) >
    0,
  }
}

///|
pub fn command_preflight_blocked_event(
  preflight : Json,
  action~ : String,
  context_path~ : String,
  created_at~ : String,
  event_id~ : String,
) -> Json {
  let reason = json_string(
    preflight,
    "reason",
    default="MoonCode command is blocked by current review gates",
  )
  event_record(
    id=event_id,
    lane=command_lane(action),
    kind="preflight.blocked",
    title=command_title(action, "blocked"),
    status="blocked",
    created_at~,
    detail=reason,
    path=context_path,
    command=action,
    command_packet=preflight,
  )
}

///|
pub fn command_preflight_blocked_projected_event(
  preflight : Json,
  action~ : String,
  context_path~ : String,
  created_at~ : String,
) -> Json {
  let reason = json_string(
    preflight,
    "reason",
    default="MoonCode command is blocked by current review gates",
  )
  command_preflight_blocked_event(
    preflight,
    action~,
    context_path~,
    created_at~,
    event_id=stable_event_id(
      "mooncode-preflight-blocked:" +
      action +
      ":" +
      context_path +
      ":" +
      created_at +
      ":" +
      reason,
    ),
  )
}

///|
pub fn command_preflight_override_event(
  preflight : Json,
  action~ : String,
  context_path~ : String,
  created_at~ : String,
  event_id~ : String,
) -> Json {
  let reason = json_string(
    preflight,
    "reason",
    default="MoonCode command preflight was overridden by the operator",
  )
  event_record(
    id=event_id,
    lane=command_lane(action),
    kind="preflight.override",
    title=command_title(action, "override"),
    status="override",
    created_at~,
    detail="Operator override: " + reason,
    path=context_path,
    command=action,
    command_packet=preflight,
  )
}

///|
pub fn command_preflight_override_projected_event(
  preflight : Json,
  action~ : String,
  context_path~ : String,
  created_at~ : String,
) -> Json {
  let reason = json_string(
    preflight,
    "reason",
    default="MoonCode command preflight was overridden by the operator",
  )
  command_preflight_override_event(
    preflight,
    action~,
    context_path~,
    created_at~,
    event_id=stable_event_id(
      "mooncode-preflight-override:" +
      action +
      ":" +
      context_path +
      ":" +
      created_at +
      ":" +
      reason,
    ),
  )
}

///|
pub fn action_required_gates(action : String) -> Array[String] {
  match action {
    "run_tests" =>
      ["runtime-dispatch", "moon_check-or-shell-tool", "test_result-event"]
    "run_eval" =>
      ["runtime-dispatch", "tool_harness", "file_edit", "native-eval-report"]
    "package" =>
      [
        "runtime-dispatch", "source-inventory", "package-index", "operator-review",
      ]
    "commit" =>
      [
        "operator-review", "no-failing-tests", "accepted-file-changes", "git-commit-proof",
      ]
    "accept" =>
      [
        "operator-review", "no-failing-tests", "review-receipt", "moonbook-owned-output",
      ]
    "reject" => ["operator-review", "review-receipt"]
    "approve_tool" | "reject_tool" =>
      ["operator-review", "tool-approval-manifest"]
    "apply_patch" | "revert_patch" =>
      ["operator-review", "patch-set", "post-change-test-result"]
    "cancel" => ["runtime-dispatch", "terminal-event"]
    "prompt" | "steer" =>
      ["runtime-dispatch", "stream-event", "tool-or-transcript-progress"]
    _ => ["runtime-dispatch"]
  }
}
