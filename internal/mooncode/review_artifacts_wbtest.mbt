///|
// MoonCode review artifact manifest tests.

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
    {
      "id": "s1",
      "workspace_id": "book",
      "mooncode_runtime_session_id": "runtime",
    },
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
    "mooncode_runtime_session_id": "runtime",
  }
  let command_packet : Json = {
    "protocol": protocol_version(),
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
  assert_true(entry_points[0] is String("tools/demo/main.mbt"))

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
    package_session_root_relative_path("s/1"),
    "portable/app-tool/mooncode/session",
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
test "mooncode package source records keep promotion contract standalone" {
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
    "id": "code-demo",
    "workspace_id": "book-1",
    "workspace_name": "Demo Book",
    "mooncode_runtime_session_id": "runtime-1",
  }
  let command_packet : Json = {
    "protocol": protocol_version(),
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
    receipt_path="wiki/reviews/mooncode/code-demo/accept-command.json",
    absolute_receipt_path="/tmp/book/wiki/reviews/mooncode/code-demo/accept-command.json",
  )
  assert_eq(
    json_string(manifest, "kind", default=""),
    "mooncode-review-receipt",
  )
  assert_eq(json_string(manifest, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(manifest, "command_id", default=""), "command")
  assert_eq(
    json_string(manifest, "receipt_path", default=""),
    "wiki/reviews/mooncode/code-demo/accept-command.json",
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(manifest, "owner"),
      "standalone_component",
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
test "mooncode review manifest events keep protocol lanes standalone" {
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
      "status": "replay-resumable",
      "recorded_at": "2026-06-15T00:02:00Z",
      "manifest_path": "wiki/reviews/mooncode/s1/runtime-handoff.json",
      "last_command_packet": packet,
    },
    "runtime-event",
  )
  assert_eq(json_string(runtime_event, "lane", default=""), "runtime")
  assert_eq(json_string(runtime_event, "kind", default=""), "runtime.handoff")
}

///|
test "mooncode projected review manifest events own stable ids" {
  let manifest : Json = {
    "session_id": "s1",
    "status": "recorded",
    "recorded_at": "2026-06-15T00:00:00Z",
    "manifest_path": "wiki/reviews/mooncode/s1/change-set.json",
    "last_command_packet": { "command_id": "cmd-1" },
  }
  let first = change_set_manifest_projected_event(manifest)
  let second = change_set_manifest_projected_event(manifest)
  assert_eq(
    json_string(first, "id", default=""),
    json_string(second, "id", default=""),
  )
  assert_eq(json_string(first, "lane", default=""), "review")
  assert_eq(json_string(first, "kind", default=""), "change_set.manifest")
  assert_eq(
    json_string(first, "path", default=""),
    "wiki/reviews/mooncode/s1/change-set.json",
  )

  let other = change_set_manifest_projected_event({
    "session_id": "s1",
    "recorded_at": "2026-06-15T00:00:00Z",
    "manifest_path": "wiki/reviews/mooncode/s1/change-set-other.json",
  })
  assert_true(
    json_string(first, "id", default="") != json_string(other, "id", default=""),
  )
  assert_eq(
    json_string(
      action_plan_manifest_projected_event(manifest),
      "lane",
      default="",
    ),
    "runtime",
  )
  assert_eq(
    json_string(
      runtime_handoff_manifest_projected_event(manifest),
      "kind",
      default="",
    ),
    "runtime.handoff",
  )
}

///|
test "mooncode projected package and receipt events own stable ids" {
  let packet : Json = { "command_id": "cmd-1" }
  let receipt = review_receipt_projected_event(
    "accept", "wiki/reviews/mooncode/s1/accept-cmd-1.json", "tools/demo/main.mbt",
    "2026-06-15T00:00:00Z", packet,
  )
  assert_eq(
    json_string(receipt, "id", default=""),
    json_string(
      review_receipt_projected_event(
        "accept", "wiki/reviews/mooncode/s1/accept-cmd-1.json", "tools/demo/main.mbt",
        "2026-06-15T00:00:00Z", packet,
      ),
      "id",
      default="",
    ),
  )
  assert_eq(json_string(receipt, "kind", default=""), "receipt.accept")
  assert_eq(json_string(receipt, "path", default=""), "tools/demo/main.mbt")

  let manifest : Json = {
    "session_id": "s1",
    "status": "candidate",
    "command_id": "cmd-1",
    "recorded_at": "2026-06-15T00:01:00Z",
    "manifest_path": "portable/app-tool/mooncode/s1/package-cmd-1.json",
  }
  let package_event = package_manifest_projected_event(
    manifest, "", "2026-06-15T00:01:00Z", packet,
  )
  assert_eq(json_string(package_event, "lane", default=""), "artifact")
  assert_eq(json_string(package_event, "kind", default=""), "package.manifest")
  assert_eq(
    json_string(package_event, "path", default=""),
    "portable/app-tool/mooncode/s1/package-cmd-1.json",
  )
  assert_eq(
    json_string(
      package_index_manifest_projected_event(manifest),
      "kind",
      default="",
    ),
    "package.index",
  )
}
