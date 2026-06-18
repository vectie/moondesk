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
test "mooncode command preflight for session derives summary and patch entries" {
  let diff_event = event_record(
    id="diff-1",
    lane="diff",
    kind="tool.write",
    title="File changed",
    status="done",
    created_at="2026-06-17T00:00:00Z",
    detail="changed",
    path="tools/demo/main.mbt",
    diff="+fn main { println(1) }",
  )
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  let blocked = command_preflight_for_session(
    { "id": "agent-demo" },
    payload,
    [diff_event],
    action="accept",
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_eq(
    runtime_json_int(
      runtime_json_object_field_or_empty(blocked, "summary"),
      "diff_count",
      default=0,
    ),
    1,
  )
  assert_true(
    json_bool(
      runtime_json_object_field_or_empty(blocked, "selected_patch"),
      "matched",
      default=false,
    ),
  )
  assert_true(json_string(blocked, "reason", default="") != "")
  let command_gates = runtime_json_object_field_or_empty(
    blocked, "acceptance_gates",
  )
  assert_false(json_bool(command_gates, "has_verified_tests", default=true))
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
  assert_true(action_required_gates("run_build").contains("test_result-event"))
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
    "protocol": protocol_version(),
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
test "mooncode command preflight blocked projection owns stable event ids" {
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": protocol_version(),
    "action": "package",
    "blocked": true,
    "reason": "resolve pending tool approvals before package",
  }
  let first = command_preflight_blocked_projected_event(
    preflight,
    action="package",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-14T00:02:00Z",
  )
  let second = command_preflight_blocked_projected_event(
    preflight,
    action="package",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-14T00:02:00Z",
  )
  assert_eq(
    json_string(first, "id", default=""),
    json_string(second, "id", default=""),
  )
  assert_true(
    json_string(first, "id", default="").has_prefix("mooncode-event-"),
  )
  assert_eq(json_string(first, "kind", default=""), "preflight.blocked")
  assert_eq(json_string(first, "lane", default=""), "artifact")
}

///|
test "mooncode command preflight override attempts become audit events" {
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": protocol_version(),
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

///|
test "mooncode command preflight override projection owns stable event ids" {
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": protocol_version(),
    "action": "commit",
    "blocked": true,
    "reason": "accept reviewed file changes before commit",
  }
  let first = command_preflight_override_projected_event(
    preflight,
    action="commit",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-15T00:02:00Z",
  )
  let second = command_preflight_override_projected_event(
    preflight,
    action="commit",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-15T00:02:00Z",
  )
  assert_eq(
    json_string(first, "id", default=""),
    json_string(second, "id", default=""),
  )
  assert_true(
    json_string(first, "id", default="").has_prefix("mooncode-event-"),
  )
  assert_eq(json_string(first, "kind", default=""), "preflight.override")
  assert_eq(json_string(first, "lane", default=""), "review")
}
