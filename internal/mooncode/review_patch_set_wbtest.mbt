///|
test "mooncode patch set groups hunks and review state" {
  let diff = "@@ -1 +1 @@\n-old\n+new\n context"
  let events : Array[Json] = [
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.edit",
      title="Edit file",
      status="done",
      created_at="1",
      detail="edited",
      path="tools/demo/main.mbt",
      diff~,
    ),
    event_record(
      id="review-1",
      lane="review",
      kind="command.apply_patch",
      title="Apply patch",
      status="done",
      created_at="2",
      detail="applied",
      path="tools/demo/main.mbt#hunk-1",
      command="apply_patch",
    ),
  ]
  let manifest = patch_set_manifest(
    { "id": "s1", "workspace_id": "book" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/patch-set.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/patch-set.json",
  )
  assert_eq(json_string(manifest, "status", default=""), "applied")
  assert_eq(summary_json_int(manifest, "patch_count", default=0), 1)
  let patch = json_array_items(manifest, "patches")[0]
  assert_eq(summary_json_int(patch, "hunk_count", default=0), 1)
  assert_eq(json_string(patch, "review_state", default=""), "applied")
  assert_eq(json_string(patch, "execution_state", default=""), "pending")
  assert_eq(json_string(patch, "gate_status", default=""), "runtime-needed")
  assert_eq(
    json_string(patch, "next_action", default=""),
    "await-runtime-proof",
  )
  assert_true(
    json_string(patch, "blocked_reason", default="").contains("runtime proof"),
  )
  let hunks = json_array_items(patch, "hunks")
  assert_eq(json_string(hunks[0], "gate_status", default=""), "runtime-needed")
  assert_eq(
    json_string(hunks[0], "next_action", default=""),
    "await-runtime-proof",
  )
  assert_eq(
    summary_json_int(manifest, "runtime_patch_proof_count", default=0),
    0,
  )
  let lifecycle = session_patch_lifecycle(events)
  assert_eq(
    json_string(lifecycle, "kind", default=""),
    "mooncode-patch-lifecycle",
  )
  assert_eq(summary_json_int(lifecycle, "patch_count", default=0), 1)
  assert_eq(summary_json_int(lifecycle, "runtime_needed_count", default=0), 1)
  assert_eq(
    json_string(lifecycle, "latest_status", default=""),
    "runtime-needed",
  )
  let rows = json_array_items(lifecycle, "rows")
  assert_eq(rows.length(), 1)
  assert_eq(json_string(rows[0], "path", default=""), "tools/demo/main.mbt")
  assert_eq(
    json_string(rows[0], "next_action", default=""),
    "await-runtime-proof",
  )
}

///|
test "mooncode patch set separates runtime execution proof from operator review" {
  let events : Array[Json] = [
    event_record(
      id="diff-1",
      lane="diff",
      kind="tool.edit",
      title="Edit file",
      status="done",
      created_at="1",
      detail="edited",
      path="tools/demo/main.mbt",
      diff="@@ -1 +1 @@\n-old\n+new",
    ),
    event_record(
      id="review-1",
      lane="review",
      kind="command.apply_patch",
      title="Apply patch",
      status="done",
      created_at="2",
      detail="operator accepted apply",
      path="tools/demo/main.mbt",
      command="apply_patch",
    ),
    event_record(
      id="runtime-1",
      lane="review",
      kind="runtime.patch_applied",
      title="Patch applied by runtime",
      status="done",
      created_at="3",
      detail="applied cleanly",
      path="tools/demo/main.mbt",
      command="apply_patch",
    ),
  ]
  let manifest = patch_set_manifest(
    { "id": "s1", "workspace_id": "book" },
    events,
    recorded_at="2026-06-15T00:00:00Z",
    manifest_path="wiki/reviews/mooncode/s1/patch-set.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/patch-set.json",
  )
  assert_eq(json_string(manifest, "status", default=""), "applied")
  assert_eq(json_string(manifest, "execution_status", default=""), "applied")
  assert_eq(
    summary_json_int(manifest, "runtime_applied_patch_count", default=0),
    1,
  )
  assert_eq(
    summary_json_int(manifest, "runtime_patch_proof_count", default=0),
    1,
  )
  let patch = json_array_items(manifest, "patches")[0]
  assert_eq(json_string(patch, "review_state", default=""), "applied")
  assert_eq(json_string(patch, "execution_state", default=""), "applied")
  assert_eq(json_string(patch, "gate_status", default=""), "runtime-proven")
  assert_eq(json_string(patch, "next_action", default=""), "run_tests")
  assert_true(json_bool(patch, "execution_verified", default=false))
  let lifecycle = session_patch_lifecycle(events)
  assert_eq(summary_json_int(lifecycle, "runtime_proven_count", default=0), 1)
  assert_eq(
    summary_json_int(lifecycle, "runtime_patch_proof_count", default=0),
    1,
  )
  assert_eq(
    json_string(lifecycle, "latest_status", default=""),
    "runtime-proven",
  )
  assert_true(
    json_string(lifecycle, "next_step", default="").contains("Run tests"),
  )
}
