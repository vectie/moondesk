///|
pub fn change_set_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let diff_events = change_set_lane_entries(events, "diff")
  let test_events = change_set_lane_entries(events, "test")
  let artifact_events = change_set_lane_entries(events, "artifact")
  let review_events = change_set_lane_entries(events, "review")
  let accepted_count = count_review_command(events, "accept")
  let rejected_count = count_review_command(events, "reject")
  {
    "kind": "mooncode-change-set",
    "protocol": "mooncode.v1",
    "status": review_state(diff_events.length(), accepted_count, rejected_count),
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "diffs": Json::array(diff_events),
    "tests": Json::array(test_events),
    "artifacts": Json::array(artifact_events),
    "reviews": Json::array(review_events),
    "diff_count": diff_events.length(),
    "test_count": test_events.length(),
    "artifact_count": artifact_events.length(),
    "review_count": review_events.length(),
    "accepted_review_count": accepted_count,
    "rejected_review_count": rejected_count,
    "pending_diff_count": pending_diff_count(
      diff_events.length(),
      accepted_count,
      rejected_count,
    ),
    "verified_test_count": count_verified_tests(events),
    "failed_test_count": count_failed_tests(events),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "last_review_receipt": summary_json_object_field_or_empty(
      session, "mooncode_last_review_receipt",
    ),
    "last_package_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_package_manifest",
    ),
    "owner": review_artifact_owner("moonbook"),
    "next_runtime_step": "MoonClaw or standalone MoonCode should promote this change set into verified patch staging, tests, and packaged MoonBook code.",
  }
}

///|
pub fn tool_approvals_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let approvals = tool_approval_entries(events)
  let approved_count = count_tool_approval_state(approvals, "approved")
  let rejected_count = count_tool_approval_state(approvals, "rejected")
  let pending_count = count_tool_approval_state(approvals, "pending")
  {
    "kind": "mooncode-tool-approvals",
    "protocol": "mooncode.v1",
    "status": if rejected_count > 0 {
      "rejected"
    } else if pending_count > 0 {
      "pending"
    } else if approved_count > 0 {
      "approved"
    } else {
      "empty"
    },
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "approvals": Json::array(approvals),
    "approval_count": approvals.length(),
    "pending_approval_count": pending_count,
    "approved_approval_count": approved_count,
    "rejected_approval_count": rejected_count,
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "last_review_receipt": summary_json_object_field_or_empty(
      session, "mooncode_last_review_receipt",
    ),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "review": "moonbook",
      "extractable_component": "mooncode",
    },
    "next_runtime_step": "MoonClaw or standalone MoonCode should enforce these tool approval decisions before executing policy/review-gated tools.",
  }
}

///|
pub fn test_runs_manifest(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let runs = test_run_entries(events)
  let passed_count = count_test_run_state(runs, "passed")
  let failed_count = count_test_run_state(runs, "failed")
  let running_count = count_test_run_state(runs, "running")
  let queued_count = count_test_run_state(runs, "queued")
  {
    "kind": "mooncode-test-runs",
    "protocol": "mooncode.v1",
    "status": if failed_count > 0 {
      "failed"
    } else if running_count > 0 {
      "running"
    } else if queued_count > 0 {
      "queued"
    } else if passed_count > 0 {
      "passed"
    } else {
      "empty"
    },
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "manifest_path": manifest_path,
    "absolute_manifest_path": absolute_manifest_path,
    "runs": Json::array(runs),
    "run_count": runs.length(),
    "passed_run_count": passed_count,
    "failed_run_count": failed_count,
    "running_run_count": running_count,
    "queued_run_count": queued_count,
    "verified_run_count": count_verified_tests(events),
    "last_command_packet": summary_json_object_field_or_empty(
      session, "mooncode_last_command_packet",
    ),
    "change_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_change_set_manifest",
    ),
    "patch_set_manifest": summary_json_object_field_or_empty(
      session, "mooncode_last_patch_set_manifest",
    ),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "test": "moonbook",
      "extractable_component": "mooncode",
    },
    "next_runtime_step": "MoonClaw or standalone MoonCode should execute these commands directly, stream stdout/stderr, and attach exact test/build logs.",
  }
}

///|
pub fn change_set_lane_entries(
  events : Array[Json],
  lane : String,
) -> Array[Json] {
  let entries : Array[Json] = []
  for event in events {
    if json_string(event, "lane", default="") == lane {
      entries.push(change_set_event_entry(event))
    }
  }
  entries
}

///|
pub fn change_set_event_entry(event : Json) -> Json {
  let packet = summary_json_object_field_or_empty(event, "command_packet")
  {
    "id": json_string(event, "id", default=""),
    "kind": json_string(event, "kind", default=""),
    "title": json_string(event, "title", default=""),
    "status": json_string(event, "status", default=""),
    "path": json_string(event, "path", default=""),
    "command": json_string(event, "command", default=""),
    "exit_code": summary_json_int(event, "exit_code", default=0),
    "created_at": json_string(event, "created_at", default=""),
    "detail": json_string(event, "detail", default=""),
    "diff": json_string(event, "diff", default=""),
    "command_id": json_string(packet, "command_id", default=""),
  }
}

///|
pub fn count_package_runtime_proofs(events : Array[Json]) -> Int {
  let mut count = 0
  for event in events {
    if package_runtime_event_state(event) != "" &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
pub fn count_package_runtime_state(events : Array[Json], state : String) -> Int {
  let mut count = 0
  for event in events {
    if package_runtime_event_state(event) == state &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
pub fn test_run_entries(events : Array[Json]) -> Array[Json] {
  let entries : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for event in events {
    if json_string(event, "lane", default="") != "test" {
      continue
    }
    let key = test_run_target(event)
    if seen.get(key).unwrap_or(false) {
      continue
    }
    seen[key] = true
    entries.push(test_run_entry(event))
  }
  entries
}

///|
pub fn test_run_state(event : Json) -> String {
  let status = json_string(event, "status", default="")
  if test_event_failed(event) {
    "failed"
  } else if test_event_is_completed(event) {
    "passed"
  } else if status == "running" || status == "started" {
    "running"
  } else {
    "queued"
  }
}

///|
pub fn count_test_run_state(runs : Array[Json], state : String) -> Int {
  let mut count = 0
  for run in runs {
    if json_string(run, "run_state", default="") == state {
      count += 1
    }
  }
  count
}

///|
pub fn patch_review_state_for_path(
  path : String,
  events : Array[Json],
) -> String {
  if patch_review_event_count(path, "revert_patch", events) > 0 {
    "reverted"
  } else if patch_review_event_count(path, "apply_patch", events) > 0 {
    "applied"
  } else if patch_review_event_count(path, "reject", events) > 0 {
    "rejected"
  } else if patch_review_event_count(path, "accept", events) > 0 {
    "accepted"
  } else {
    "pending"
  }
}

///|
pub fn patch_execution_state_for_path(
  path : String,
  events : Array[Json],
) -> String {
  if patch_execution_event_count(path, "runtime.patch_reverted", events) > 0 {
    "reverted"
  } else if patch_execution_event_count(path, "runtime.patch_applied", events) >
    0 {
    "applied"
  } else {
    "pending"
  }
}

///|
pub fn patch_review_target_matches(
  target : String,
  event_path : String,
) -> Bool {
  target == "" ||
  event_path == "" ||
  event_path == target ||
  event_path == patch_review_parent_target(target) ||
  event_path.has_prefix(target + "#hunk-")
}

///|
fn review_artifact_owner(artifact_owner : String) -> Json {
  {
    "ui": "moondesk",
    "runtime": "moonclaw",
    "artifact": artifact_owner,
    "review": "moonbook",
    "extractable_component": "mooncode",
  }
}

///|
test "mooncode change set manifest summarizes reviewable work" {
  let events : Array[Json] = [
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.write",
      title="Write file",
      status="done",
      created_at="1",
      detail="updated",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
    ),
    event_record(
      id="test-1",
      lane="test",
      kind="tool.moon_check",
      title="Moon check",
      status="done",
      created_at="2",
      detail="passed",
      command="moon check",
    ),
  ]
  let manifest = change_set_manifest(
    { "id": "s1", "workspace_id": "book", "moonclaw_task_id": "task" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/change-set.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/change-set.json",
  )
  assert_eq(json_string(manifest, "kind", default=""), "mooncode-change-set")
  assert_eq(summary_json_int(manifest, "diff_count", default=0), 1)
  assert_eq(summary_json_int(manifest, "verified_test_count", default=0), 1)
  assert_eq(json_string(manifest, "status", default=""), "pending")
}

///|
test "mooncode tool approvals manifest tracks pending policy gates" {
  let events : Array[Json] = [
    event_record(
      id="tool-1",
      lane="tool",
      kind="tool.shell",
      title="Run command",
      status="running",
      created_at="1",
      detail="execute_command",
      command="moon test",
    ),
  ]
  let manifest = tool_approvals_manifest(
    { "id": "s1", "workspace_id": "book" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/tool-approvals.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/tool-approvals.json",
  )
  assert_eq(json_string(manifest, "status", default=""), "pending")
  assert_eq(summary_json_int(manifest, "pending_approval_count", default=0), 1)
}

///|
test "mooncode test runs manifest separates passed and failed runs" {
  let events : Array[Json] = [
    event_record(
      id="test-1",
      lane="test",
      kind="tool.moon_check",
      title="Moon check",
      status="done",
      created_at="1",
      detail="passed",
      command="moon check",
    ),
    event_record(
      id="test-2",
      lane="test",
      kind="tool.shell",
      title="Build",
      status="failed",
      created_at="2",
      detail="failed",
      command="moon build",
      exit_code=1,
    ),
  ]
  let manifest = test_runs_manifest(
    { "id": "s1", "workspace_id": "book" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/test-runs.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/test-runs.json",
  )
  assert_eq(json_string(manifest, "status", default=""), "failed")
  assert_eq(summary_json_int(manifest, "passed_run_count", default=0), 1)
  assert_eq(summary_json_int(manifest, "failed_run_count", default=0), 1)
  assert_eq(summary_json_int(manifest, "verified_run_count", default=0), 1)
}

///|
test "mooncode package manifest and index summarize executable candidates" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "workspace_name": "Book",
    "moonclaw_task_id": "task",
  }
  let command_packet : Json = {
    "protocol": "mooncode.v1",
    "command_id": "cmd-1",
    "session_id": "s1",
  }
  let source_inventory : Array[Json] = [
    {
      "path": "tools/demo/main.mbt",
      "exists": true,
      "kind": "file",
      "size_bytes": 32,
      "sha256": "abc123",
      "package_ready": true,
    },
  ]
  let manifest = package_manifest(
    session,
    { "receipt_path": "wiki/reviews/mooncode/s1/package-cmd-1.json" },
    command_packet,
    "tools/demo/main.mbt",
    "Package tool",
    "2026-06-15T00:00:00Z",
    "2026-06-15T00:01:00Z",
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
    "/tmp/book/portable/app-tool/mooncode/s1/package-cmd-1.json",
    source_inventory,
  )
  assert_eq(
    json_string(manifest, "kind", default=""),
    "mooncode-package-manifest",
  )
  assert_eq(json_string(manifest, "package_kind", default=""), "tool")
  assert_eq(
    json_string(manifest, "source_inventory_status", default=""),
    "source-bound",
  )
  assert_eq(summary_json_int(manifest, "source_present_count", default=0), 1)

  let index = package_index_manifest(
    session,
    "s1",
    manifest,
    [manifest],
    "2026-06-15T00:02:00Z",
    "portable/app-tool/mooncode/s1/index.json",
    "/tmp/book/portable/app-tool/mooncode/s1/index.json",
    "portable/app-tool/mooncode/s1",
  )
  assert_eq(json_string(index, "kind", default=""), "mooncode-package-index")
  assert_eq(json_string(index, "status", default=""), "source-bound")
  assert_eq(summary_json_int(index, "package_count", default=0), 1)
  assert_eq(summary_json_int(index, "executable_ready_count", default=0), 1)
  assert_eq(
    summary_json_int(index, "runtime_verified_package_count", default=0),
    0,
  )
  let entry_points = json_array_items(index, "entry_points")
  assert_eq(entry_points.length(), 1)
  assert_true(entry_points[0] is Json::String("tools/demo/main.mbt"))

  let candidates = package_candidates_projection(
    session,
    "s1",
    [manifest],
    index,
  )
  assert_eq(
    json_string(candidates, "kind", default=""),
    "mooncode-package-candidates",
  )
  assert_eq(summary_json_int(candidates, "package_count", default=0), 1)
  assert_eq(
    summary_json_int(
      candidates,
      "package_index_executable_ready_count",
      default=0,
    ),
    1,
  )
}

///|
test "mooncode package candidates separate source readiness from runtime proof" {
  let manifest = package_manifest(
    {
      "id": "s1",
      "workspace_id": "book",
      "mooncode_command_events": [
        event_record(
          id="pkg-proof",
          lane="artifact",
          kind="runtime.package_verified",
          title="Package verified by runtime",
          status="done",
          created_at="3",
          detail="verified",
          path="tools/demo/main.mbt",
          command="package",
        ),
      ],
    },
    { "receipt_path": "wiki/reviews/mooncode/s1/package-cmd-1.json" },
    { "command_id": "cmd-1" },
    "tools/demo/main.mbt",
    "Package tool",
    "2026-06-15T00:00:00Z",
    "2026-06-15T00:01:00Z",
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
    "/tmp/book/portable/app-tool/mooncode/s1/package-cmd-1.json",
    [
      {
        "path": "tools/demo/main.mbt",
        "exists": true,
        "kind": "file",
        "package_ready": true,
      },
    ],
  )
  let session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "mooncode_command_events": [
      event_record(
        id="pkg-proof",
        lane="artifact",
        kind="runtime.package_verified",
        title="Package verified by runtime",
        status="done",
        created_at="3",
        detail="verified",
        path="tools/demo/main.mbt",
        command="package",
      ),
    ],
  }
  let index = package_index_manifest(
    session,
    "s1",
    manifest,
    [manifest],
    "2026-06-15T00:02:00Z",
    "portable/app-tool/mooncode/s1/index.json",
    "/tmp/book/portable/app-tool/mooncode/s1/index.json",
    "portable/app-tool/mooncode/s1",
  )
  assert_eq(json_string(index, "status", default=""), "verified")
  assert_eq(
    summary_json_int(index, "runtime_verified_package_count", default=0),
    1,
  )
  let candidates = package_candidates_projection(
    session,
    "s1",
    [manifest],
    index,
  )
  assert_eq(json_string(candidates, "status", default=""), "verified")
  assert_eq(
    summary_json_int(candidates, "runtime_package_proof_count", default=0),
    1,
  )
  let projected = json_array_items(candidates, "packages")[0]
  assert_eq(json_string(projected, "execution_state", default=""), "verified")
  assert_true(json_bool(projected, "execution_verified", default=false))
}

///|
test "mooncode package manifest tracks missing default roots" {
  let manifest = package_manifest(
    { "id": "s1" },
    Json::object({}),
    { "command_id": "cmd-1" },
    "",
    "Package workspace",
    "2026-06-15T00:00:00Z",
    "2026-06-15T00:01:00Z",
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
    "/tmp/book/portable/app-tool/mooncode/s1/package-cmd-1.json",
    [
      {
        "path": "tools/",
        "exists": false,
        "kind": "missing",
        "package_ready": false,
      },
    ],
  )
  assert_eq(
    json_string(manifest, "package_kind", default=""),
    "app-tool-candidate",
  )
  assert_eq(
    json_string(manifest, "source_inventory_status", default=""),
    "no-source-yet",
  )
  assert_eq(json_array_items(manifest, "candidate_paths").length(), 4)
  assert_false(
    package_manifest_list_contains([manifest], "portable/app-tool/missing.json"),
  )
  assert_true(
    package_manifest_list_contains(
      [manifest],
      "portable/app-tool/mooncode/s1/package-cmd-1.json",
    ),
  )
}

///|
test "mooncode artifact paths sanitize session and command ids" {
  assert_eq(
    change_set_manifest_relative_path("s1"),
    "wiki/reviews/mooncode/s1/change-set.json",
  )
  assert_eq(
    patch_set_manifest_relative_path("../bad"),
    "wiki/reviews/mooncode/session/patch-set.json",
  )
  assert_eq(
    review_receipt_relative_path("s1", "cmd-1", "approve_tool"),
    "wiki/reviews/mooncode/s1/approve-tool-cmd-1.json",
  )
  assert_eq(
    review_receipt_relative_path("s1", "cmd/1", "unexpected"),
    "wiki/reviews/mooncode/s1/command-command.json",
  )
  assert_eq(
    package_manifest_relative_path("s1", "cmd-1"),
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
  )
  assert_eq(
    package_index_manifest_relative_path("s1"),
    "portable/app-tool/mooncode/s1/index.json",
  )
}

///|
test "mooncode review receipt policy covers review and execution decisions" {
  for
    action in [
      "accept", "reject", "package", "commit", "approve_tool", "reject_tool", "apply_patch",
      "revert_patch",
    ] {
    assert_true(command_writes_review_receipt(action))
  }
  for action in ["prompt", "steer", "cancel", "run_test", "run_eval"] {
    assert_false(command_writes_review_receipt(action))
  }
}

///|
test "mooncode package source records keep promotion contract extractable" {
  let directory = package_source_directory_record("tools/demo")
  assert_eq(json_string(directory, "kind", default=""), "directory")
  assert_true(json_bool(directory, "package_ready", default=false))
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(directory, "promotion"),
      "status",
      default="",
    ),
    "directory-source",
  )
  let promoted_path = package_source_promotion_path(
    "portable/app-tool/mooncode/s1", "cmd/1", "tools/demo/main.mbt",
  )
  assert_eq(
    promoted_path, "portable/app-tool/mooncode/s1/sources/command/tools/demo/main.mbt",
  )
  let promoted = package_source_promoted_promotion(
    "tools/demo/main.mbt",
    promoted_path,
    "/tmp/book/" + promoted_path,
    "fn main { println(\"moon\") }\n",
  )
  assert_true(json_bool(promoted, "promoted", default=false))
  assert_eq(json_string(promoted, "status", default=""), "promoted")
  assert_true(json_string(promoted, "sha256", default="").length() > 20)
  let file = package_source_file_record(
    "tools/demo/main.mbt", 28, "abc123", promoted,
  )
  assert_eq(json_string(file, "kind", default=""), "file")
  assert_true(json_bool(file, "promoted", default=false))
  assert_eq(json_string(file, "promoted_path", default=""), promoted_path)
  let failed = package_source_failed_promotion(
    "tools/demo/main.mbt",
    promoted_path,
    "/tmp/book/" + promoted_path,
    "permission denied",
  )
  assert_eq(json_string(failed, "status", default=""), "failed")
  assert_eq(json_string(failed, "error", default=""), "permission denied")
  assert_eq(
    json_string(package_source_invalid_record("../bad"), "kind", default=""),
    "invalid",
  )
  assert_eq(
    json_string(
      package_source_missing_record("tools/missing.mbt"),
      "kind",
      default="",
    ),
    "missing",
  )
}

///|
test "mooncode review receipt manifest records ownership split" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-1",
    "workspace_name": "Demo Book",
    "moonclaw_task_id": "task-1",
  }
  let command_packet : Json = {
    "protocol": "mooncode.v1",
    "command_id": "cmd/1",
    "action": "accept",
  }
  let manifest = review_receipt_manifest(
    session,
    "accept",
    command_packet,
    "tools/demo/main.mbt",
    "Accept this patch",
    "2026-06-14T00:00:00Z",
    command_id="command",
    recorded_at="2026-06-14T00:01:00Z",
    receipt_path="wiki/reviews/mooncode/agent-demo/accept-command.json",
    absolute_receipt_path="/tmp/book/wiki/reviews/mooncode/agent-demo/accept-command.json",
  )
  assert_eq(
    json_string(manifest, "kind", default=""),
    "mooncode-review-receipt",
  )
  assert_eq(json_string(manifest, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(manifest, "command_id", default=""), "command")
  assert_eq(
    json_string(manifest, "receipt_path", default=""),
    "wiki/reviews/mooncode/agent-demo/accept-command.json",
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(manifest, "owner"),
      "extractable_component",
      default="",
    ),
    "mooncode",
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(manifest, "command_packet"),
      "protocol",
      default="",
    ),
    "mooncode.v1",
  )
}

///|
test "mooncode artifact safe id shortens long ids deterministically" {
  let long_id = "session-" + "x".repeat(80)
  let safe = artifact_safe_id(long_id, fallback="session")
  assert_true(safe.has_prefix("session-"))
  assert_true(safe.length() < long_id.length())
  assert_eq(safe, artifact_safe_id(long_id, fallback="session"))
}

///|
test "mooncode review manifest events keep protocol lanes extractable" {
  let packet : Json = { "command_id": "cmd-1" }
  let change_event = change_set_manifest_event(
    {
      "session_id": "s1",
      "status": "pending",
      "recorded_at": "2026-06-15T00:00:00Z",
      "manifest_path": "wiki/reviews/mooncode/s1/change-set.json",
      "last_command_packet": packet,
    },
    "change-event",
  )
  assert_eq(json_string(change_event, "id", default=""), "change-event")
  assert_eq(json_string(change_event, "lane", default=""), "review")
  assert_eq(
    json_string(change_event, "kind", default=""),
    "change_set.manifest",
  )
  assert_eq(json_string(change_event, "status", default=""), "pending")
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(change_event, "command_packet"),
      "command_id",
      default="",
    ),
    "cmd-1",
  )

  let action_event = action_plan_manifest_event(
    {
      "session_id": "s1",
      "status": "ready",
      "recorded_at": "2026-06-15T00:01:00Z",
      "manifest_path": "wiki/reviews/mooncode/s1/action-plan.json",
    },
    "action-event",
  )
  assert_eq(json_string(action_event, "lane", default=""), "runtime")
  assert_eq(
    json_string(action_event, "kind", default=""),
    "action_plan.manifest",
  )
  assert_eq(
    runtime_evidence_manifest_relative_path("s1"),
    "wiki/reviews/mooncode/s1/runtime-evidence.json",
  )
  let evidence_event = runtime_evidence_manifest_event(
    {
      "session_id": "s1",
      "status": "proven",
      "recorded_at": "2026-06-15T00:02:00Z",
      "manifest_path": "wiki/reviews/mooncode/s1/runtime-evidence.json",
    },
    "runtime-evidence-event",
  )
  assert_eq(json_string(evidence_event, "lane", default=""), "runtime")
  assert_eq(
    json_string(evidence_event, "kind", default=""),
    "runtime_evidence.manifest",
  )
  assert_eq(json_string(evidence_event, "status", default=""), "proven")
}

///|
test "mooncode package and receipt events preserve review targets" {
  let packet : Json = { "command_id": "cmd-1" }
  let receipt = review_receipt_event(
    "accept", "wiki/reviews/mooncode/s1/accept-cmd-1.json", "tools/demo/main.mbt",
    "2026-06-15T00:00:00Z", packet, "receipt-event",
  )
  assert_eq(json_string(receipt, "kind", default=""), "receipt.accept")
  assert_eq(json_string(receipt, "path", default=""), "tools/demo/main.mbt")

  let package_event = package_manifest_event(
    {
      "status": "candidate",
      "command_id": "cmd-1",
      "manifest_path": "portable/app-tool/mooncode/s1/package-cmd-1.json",
    },
    "",
    "2026-06-15T00:01:00Z",
    packet,
    "package-event",
  )
  assert_eq(json_string(package_event, "lane", default=""), "artifact")
  assert_eq(json_string(package_event, "kind", default=""), "package.manifest")
  assert_eq(
    json_string(package_event, "path", default=""),
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
  )

  let runtime_event = runtime_handoff_manifest_event(
    {
      "session_id": "s1",
      "status": "bridge-resumable",
      "recorded_at": "2026-06-15T00:02:00Z",
      "manifest_path": "wiki/reviews/mooncode/s1/runtime-handoff.json",
      "last_command_packet": packet,
    },
    "runtime-event",
  )
  assert_eq(json_string(runtime_event, "lane", default=""), "runtime")
  assert_eq(json_string(runtime_event, "kind", default=""), "runtime.handoff")
}
