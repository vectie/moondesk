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
    "protocol": "mooncode.v1",
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
pub fn command_preflight_selected_patch(
  context_path : String,
  patch_entries : Array[Json],
) -> Json {
  if context_path == "" {
    return command_preflight_patch_summary(
      context_path, false, "", "", "", "", "",
    )
  }
  for patch in patch_entries {
    if json_string(patch, "path", default="") == context_path {
      return command_preflight_patch_summary(
        context_path,
        true,
        json_string(patch, "review_state", default="pending"),
        json_string(patch, "execution_state", default="pending"),
        json_string(patch, "gate_status", default="needs-review"),
        json_string(patch, "next_action", default="review"),
        json_string(patch, "blocked_reason", default=""),
      )
    }
    for hunk in json_array_items(patch, "hunks") {
      if json_string(hunk, "target", default="") == context_path {
        return command_preflight_patch_summary(
          context_path,
          true,
          json_string(hunk, "review_state", default="pending"),
          json_string(hunk, "execution_state", default="pending"),
          json_string(hunk, "gate_status", default="needs-review"),
          json_string(hunk, "next_action", default="review"),
          json_string(hunk, "blocked_reason", default=""),
        )
      }
    }
  }
  command_preflight_patch_summary(context_path, false, "", "", "", "", "")
}

///|
fn command_preflight_patch_summary(
  context_path : String,
  matched : Bool,
  review_state : String,
  execution_state : String,
  gate_status : String,
  next_action : String,
  blocked_reason : String,
) -> Json {
  {
    "context_path": context_path,
    "matched": matched,
    "review_state": review_state,
    "execution_state": execution_state,
    "gate_status": gate_status,
    "next_action": next_action,
    "blocked_reason": blocked_reason,
    "runtime_proven": execution_state == "applied" ||
    execution_state == "reverted" ||
    gate_status == "runtime-proven",
  }
}

///|
pub fn command_preflight_selected_patch_blocking_reason(
  action : String,
  context_path : String,
  patch_entries : Array[Json],
) -> String {
  let selected_patch = command_preflight_selected_patch(
    context_path, patch_entries,
  )
  if !json_bool(selected_patch, "matched", default=false) {
    return ""
  }
  let review_state = json_string(selected_patch, "review_state", default="")
  let execution_state = json_string(
    selected_patch,
    "execution_state",
    default="",
  )
  let gate_status = json_string(selected_patch, "gate_status", default="")
  if review_state == "rejected" {
    return "selected patch was rejected: \{context_path}"
  }
  match action {
    "package" =>
      if !json_bool(selected_patch, "runtime_proven", default=false) {
        "apply selected patch and record MoonClaw runtime proof before package: \{context_path} is \{gate_status}"
      } else {
        ""
      }
    "commit" =>
      if review_state != "accepted" &&
        review_state != "applied" &&
        review_state != "reverted" {
        "accept selected patch before commit: \{context_path} is \{review_state}"
      } else if execution_state != "applied" && execution_state != "reverted" {
        "record MoonClaw patch execution proof before commit: \{context_path} is \{execution_state}"
      } else {
        ""
      }
    _ => ""
  }
}

///|
pub fn command_preflight_has_patch_target(
  patch_entries : Array[Json],
  target : String,
) -> Bool {
  command_preflight_patch_target_state(patch_entries, target) != ""
}

///|
pub fn command_preflight_patch_target_state(
  patch_entries : Array[Json],
  target : String,
) -> String {
  for patch in patch_entries {
    if json_string(patch, "path", default="") == target {
      return json_string(patch, "review_state", default="pending")
    }
    for hunk in json_array_items(patch, "hunks") {
      if json_string(hunk, "target", default="") == target {
        return json_string(hunk, "review_state", default="pending")
      }
    }
  }
  ""
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

///|
test "mooncode command preflight blocks accept until changed code is tested" {
  let summary : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 1,
    "verified_test_count": 0,
    "source_bound_package_count": 0,
  }
  let blocked = command_preflight(
    session_id="agent-demo",
    action="accept",
    context_path="tools/demo/main.mbt",
    summary~,
    patch_entries=[],
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(
    json_string(blocked, "reason", default="").contains("run tests/builds"),
  )
  let tested : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 1,
    "verified_test_count": 1,
    "source_bound_package_count": 0,
  }
  let allowed = command_preflight(
    session_id="agent-demo",
    action="accept",
    context_path="tools/demo/main.mbt",
    summary=tested,
    patch_entries=[],
  )
  assert_true(json_bool(allowed, "allowed", default=false))
}

///|
test "mooncode command preflight gates package on pending approvals" {
  let summary : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 1,
    "pending_diff_count": 0,
    "verified_test_count": 0,
    "source_bound_package_count": 0,
  }
  let blocked = command_preflight(
    session_id="agent-demo",
    action="package",
    context_path="apps/demo",
    summary~,
    patch_entries=[],
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(
    json_string(blocked, "reason", default="").contains(
      "pending tool approvals",
    ),
  )
}

///|
test "mooncode command preflight gates commit on accepted review" {
  let summary : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 0,
    "diff_count": 1,
    "accepted_review_count": 0,
    "verified_test_count": 1,
    "source_bound_package_count": 1,
  }
  let blocked = command_preflight(
    session_id="agent-demo",
    action="commit",
    context_path="tools/demo/main.mbt",
    summary~,
    patch_entries=[],
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(json_string(blocked, "reason", default="").contains("accept"))
  let accepted : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 0,
    "diff_count": 1,
    "accepted_review_count": 1,
    "verified_test_count": 1,
    "source_bound_package_count": 1,
  }
  let allowed = command_preflight(
    session_id="agent-demo",
    action="commit",
    context_path="tools/demo/main.mbt",
    summary=accepted,
    patch_entries=[],
  )
  assert_true(json_bool(allowed, "allowed", default=false))
}

///|
test "mooncode command preflight is selected patch aware for package" {
  let summary : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 0,
    "diff_count": 1,
    "accepted_review_count": 1,
    "verified_test_count": 1,
    "source_bound_package_count": 1,
  }
  let patch_entries : Array[Json] = [
    {
      "path": "tools/demo/main.mbt",
      "review_state": "accepted",
      "execution_state": "pending",
      "gate_status": "runtime-needed",
      "next_action": "apply_patch",
      "blocked_reason": "accepted patch still needs runtime proof",
      "hunks": [],
    },
  ]
  let blocked = command_preflight(
    session_id="agent-demo",
    action="package",
    context_path="tools/demo/main.mbt",
    summary~,
    patch_entries~,
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(
    json_string(blocked, "reason", default="").contains("runtime proof"),
  )
  let selected = runtime_json_object_field_or_empty(blocked, "selected_patch")
  assert_eq(json_string(selected, "gate_status", default=""), "runtime-needed")
  assert_eq(json_string(selected, "next_action", default=""), "apply_patch")
  let proven_entries : Array[Json] = [
    {
      "path": "tools/demo/main.mbt",
      "review_state": "accepted",
      "execution_state": "applied",
      "gate_status": "runtime-proven",
      "next_action": "run_tests",
      "blocked_reason": "",
      "hunks": [],
    },
  ]
  let allowed = command_preflight(
    session_id="agent-demo",
    action="package",
    context_path="tools/demo/main.mbt",
    summary~,
    patch_entries=proven_entries,
  )
  assert_true(json_bool(allowed, "allowed", default=false))
}

///|
test "mooncode command preflight requires selected patch proof before commit" {
  let summary : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 0,
    "diff_count": 1,
    "accepted_review_count": 1,
    "verified_test_count": 1,
    "source_bound_package_count": 1,
  }
  let patch_entries : Array[Json] = [
    {
      "path": "tools/demo/main.mbt",
      "review_state": "accepted",
      "execution_state": "pending",
      "gate_status": "runtime-needed",
      "next_action": "apply_patch",
      "hunks": [],
    },
  ]
  let blocked = command_preflight(
    session_id="agent-demo",
    action="commit",
    context_path="tools/demo/main.mbt",
    summary~,
    patch_entries~,
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(
    json_string(blocked, "reason", default="").contains("execution proof"),
  )
  assert_true(
    command_preflight_selected_patch_blocking_reason(
      "commit", "tools/demo/main.mbt", patch_entries,
    ).contains("execution proof"),
  )
}

///|
test "mooncode action required gates are protocol metadata" {
  assert_true(action_required_gates("run_eval").contains("file_edit"))
  assert_true(action_required_gates("package").contains("package-index"))
  assert_true(action_required_gates("commit").contains("git-commit-proof"))
  assert_true(action_required_gates("apply_patch").contains("patch-set"))
  let fallback = action_required_gates("unknown")
  assert_eq(fallback.length(), 1)
  assert_true(fallback.contains("runtime-dispatch"))
}

///|
test "mooncode command preflight requires accepted patch target before apply" {
  let summary : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 0,
    "verified_test_count": 0,
    "source_bound_package_count": 0,
  }
  let patch_entries : Array[Json] = [
    {
      "path": "tools/demo/main.mbt",
      "review_state": "accepted",
      "hunks": [
        { "target": "apps/demo.ts", "review_state": "accepted" },
        { "target": "apps/pending.ts", "review_state": "pending" },
      ],
    },
  ]
  let missing = command_preflight(
    session_id="agent-demo",
    action="apply_patch",
    context_path="",
    summary~,
    patch_entries~,
  )
  assert_true(json_bool(missing, "blocked", default=false))
  let wrong = command_preflight(
    session_id="agent-demo",
    action="apply_patch",
    context_path="tools/other/main.mbt",
    summary~,
    patch_entries~,
  )
  assert_true(json_bool(wrong, "blocked", default=false))
  let allowed = command_preflight(
    session_id="agent-demo",
    action="apply_patch",
    context_path="tools/demo/main.mbt",
    summary~,
    patch_entries~,
  )
  assert_true(json_bool(allowed, "allowed", default=false))
  assert_true(command_preflight_has_patch_target(patch_entries, "apps/demo.ts"))
  assert_eq(
    command_preflight_patch_target_state(patch_entries, "apps/demo.ts"),
    "accepted",
  )
  let unreviewed = command_preflight(
    session_id="agent-demo",
    action="apply_patch",
    context_path="apps/pending.ts",
    summary~,
    patch_entries~,
  )
  assert_true(json_bool(unreviewed, "blocked", default=false))
  assert_true(
    json_string(unreviewed, "reason", default="").contains(
      "accept patch target",
    ),
  )
}

///|
test "mooncode command preflight requires applied patch target before revert" {
  let summary : Json = {
    "failed_test_count": 0,
    "pending_tool_approval_count": 0,
    "pending_diff_count": 0,
    "verified_test_count": 0,
    "source_bound_package_count": 0,
  }
  let patch_entries : Array[Json] = [
    {
      "path": "tools/demo/main.mbt",
      "review_state": "applied",
      "hunks": [
        { "target": "tools/demo/main.mbt#hunk-1", "review_state": "accepted" },
        { "target": "tools/demo/main.mbt#hunk-2", "review_state": "applied" },
      ],
    },
  ]
  let blocked = command_preflight(
    session_id="agent-demo",
    action="revert_patch",
    context_path="tools/demo/main.mbt#hunk-1",
    summary~,
    patch_entries~,
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(
    json_string(blocked, "reason", default="").contains(
      "apply patch target before revert_patch",
    ),
  )
  let allowed = command_preflight(
    session_id="agent-demo",
    action="revert_patch",
    context_path="tools/demo/main.mbt#hunk-2",
    summary~,
    patch_entries~,
  )
  assert_true(json_bool(allowed, "allowed", default=false))
}

///|
test "mooncode command preflight blocked attempts become review events" {
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": "mooncode.v1",
    "action": "package",
    "blocked": true,
    "reason": "resolve pending tool approvals before package",
  }
  let event = command_preflight_blocked_event(
    preflight,
    action="package",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-14T00:02:00Z",
    event_id="blocked-1",
  )
  assert_eq(json_string(event, "kind", default=""), "preflight.blocked")
  assert_eq(json_string(event, "lane", default=""), "artifact")
  assert_eq(json_string(event, "status", default=""), "blocked")
  assert_eq(json_string(event, "path", default=""), "tools/demo/main.mbt")
  assert_true(
    json_string(event, "detail", default="").contains("pending tool approvals"),
  )
}

///|
test "mooncode command preflight override attempts become audit events" {
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": "mooncode.v1",
    "action": "commit",
    "blocked": true,
    "reason": "accept reviewed file changes before commit",
  }
  let event = command_preflight_override_event(
    preflight,
    action="commit",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-15T00:02:00Z",
    event_id="override-1",
  )
  assert_eq(json_string(event, "kind", default=""), "preflight.override")
  assert_eq(json_string(event, "lane", default=""), "review")
  assert_eq(json_string(event, "status", default=""), "override")
  assert_true(json_string(event, "detail", default="").contains("Operator"))
}
