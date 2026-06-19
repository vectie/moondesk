///|
test "mooncode eval report projection stays standalone" {
  let checks = [
    eval_check("book_scope", "Book scope", true, "book"),
    eval_check("native_eval", "Native eval", false, "missing"),
  ]
  let summary : Json = { "eval_checks": Json::array(checks) }
  let report = eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "mooncode_runtime_session_id": "runtime",
    "mooncode_summary": summary,
  })
  assert_eq(json_string(report, "kind", default=""), "mooncode-eval-report")
  assert_eq(json_string(report, "standalone_component", default=""), "mooncode")
  assert_eq(summary_json_int(report, "passed_check_count", default=0), 1)
}

///|
test "mooncode eval report manifest response owns summary and path stamping" {
  let event = event_record(
    id="test-1",
    lane="test",
    kind="tool.moon_check",
    title="Moon check",
    status="done",
    created_at="2026-06-17T00:00:00Z",
    detail="passed",
    command="moon check",
  )
  let manifest = eval_report_manifest_response_for_session(
    { "id": "s1", "workspace_id": "book" },
    [event],
    recorded_at="2026-06-17T00:01:00Z",
    manifest_path="wiki/reviews/mooncode/s1/eval-report.json",
    absolute_manifest_path="/tmp/book/wiki/reviews/mooncode/s1/eval-report.json",
  )
  assert_eq(json_string(manifest, "kind", default=""), "mooncode-eval-report")
  assert_eq(
    json_string(manifest, "recorded_at", default=""),
    "2026-06-17T00:01:00Z",
  )
  assert_eq(
    json_string(manifest, "manifest_path", default=""),
    "wiki/reviews/mooncode/s1/eval-report.json",
  )
  assert_eq(
    summary_json_int(
      summary_json_object_field_or_empty(manifest, "summary"),
      "verified_test_count",
      default=0,
    ),
    1,
  )
}

///|
test "mooncode eval report manifest session update refreshes summary" {
  let manifest : Json = {
    "kind": "mooncode-eval-report",
    "manifest_path": "wiki/reviews/mooncode/s1/eval-report.json",
  }
  let event = eval_report_manifest_projected_event(manifest)
  let session = session_with_eval_report_manifest_event(
    {
      "id": "s1",
      "workspace_id": "book",
      "transcript": [{ "role": "user", "content": "Add a miniapp" }],
    },
    manifest,
    event,
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(
        session, "mooncode_last_eval_report_manifest",
      ),
      "manifest_path",
      default="",
    ),
    "wiki/reviews/mooncode/s1/eval-report.json",
  )
  assert_eq(
    summary_json_int(
      summary_json_object_field_or_empty(session, "mooncode_summary"),
      "moonbook_eval_report_manifest_count",
      default=0,
    ),
    1,
  )
  assert_eq(json_array_items(session, "mooncode_command_events").length(), 1)
}

///|
test "mooncode native eval report normalization keeps incomplete readiness partial" {
  let native_eval = normalize_native_eval_report(
    {
      "native_eval_evidence_ready": true,
      "harnesses": ["tool_harness", "file_edit"],
    },
    "/v1/code/sessions/s1/eval-report",
  )
  assert_false(json_bool(native_eval, "ok", default=true))
  assert_eq(
    json_string(native_eval, "source", default=""),
    "moonclaw-native-runtime",
  )
  assert_eq(
    json_string(native_eval, "endpoint", default=""),
    "/v1/code/sessions/s1/eval-report",
  )
  assert_eq(json_array_items(native_eval, "harnesses").length(), 2)
}

///|
test "mooncode native eval report normalization accepts MoonClaw harness status" {
  let native_eval = normalize_native_eval_report(
    {
      "kind": "mooncode-native-eval-report",
      "protocol": protocol_version(),
      "status": "accepted",
      "native_eval": {
        "status": "passed",
        "harnesses": [
          { "id": "tool_harness", "status": "passed" },
          { "id": "file_edit", "status": "passed" },
          { "id": "patch_review", "status": "passed" },
          { "id": "command_execution", "status": "passed" },
          { "id": "package_output", "status": "passed" },
        ],
      },
    },
    "/v1/code/sessions/s1/eval-report?book_root=/tmp/book",
  )
  assert_true(json_bool(native_eval, "ok", default=false))
  let report = eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "mooncode_runtime_session_id": "runtime",
    "mooncode_native_eval_report": native_eval,
    "mooncode_summary": { "eval_checks": [] },
  })
  assert_eq(json_string(report, "status", default=""), "native-ready")
  assert_eq(summary_json_int(report, "native_eval_harness_count", default=0), 5)
  assert_eq(
    summary_json_int(report, "native_eval_passed_harness_count", default=0),
    5,
  )
  assert_eq(
    summary_json_int(
      report,
      "missing_required_native_harness_count",
      default=-1,
    ),
    0,
  )
}

///|
test "mooncode native eval report session patch is MoonCode owned" {
  let session = session_with_native_eval_report(
    { "id": "s1", "workspace_id": "book" },
    {
      "native_eval": {
        "harnesses": [
          { "id": "tool_harness", "status": "passed" },
          { "id": "file_edit", "status": "passed" },
          { "id": "patch_review", "status": "passed" },
          { "id": "command_execution", "status": "passed" },
          { "id": "package_output", "status": "passed" },
        ],
      },
    },
    "/v1/code/sessions/s1/eval-report",
  )
  assert_eq(json_string(session, "id", default=""), "s1")
  let native = summary_json_object_field_or_empty(
    session, "mooncode_native_eval_report",
  )
  assert_true(json_bool(native, "ok", default=false))
  assert_eq(
    json_string(native, "endpoint", default=""),
    "/v1/code/sessions/s1/eval-report",
  )
  assert_eq(
    json_string(native, "source", default=""),
    "moonclaw-native-runtime",
  )
}

///|
test "mooncode native eval report exposes missing required harnesses" {
  let native_eval = normalize_native_eval_report(
    {
      "status": "accepted",
      "native_eval": {
        "status": "passed",
        "harnesses": [
          { "id": "tool_harness", "status": "passed" },
          { "id": "file_edit", "status": "passed" },
        ],
      },
    },
    "/v1/code/sessions/s1/eval-report?book_root=/tmp/book",
  )
  assert_false(json_bool(native_eval, "ok", default=true))
  let report = eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "mooncode_runtime_session_id": "runtime",
    "mooncode_native_eval_report": native_eval,
    "mooncode_summary": { "eval_checks": [] },
  })
  assert_eq(json_string(report, "status", default=""), "local-ready")
  assert_eq(
    summary_json_int(
      report,
      "missing_required_native_harness_count",
      default=-1,
    ),
    3,
  )
  let missing = eval_report_wbtest_json_string_array_items(
    report, "missing_required_native_harnesses",
  )
  assert_true(missing.contains("patch_review"))
  assert_true(missing.contains("command_execution"))
  assert_true(missing.contains("package_output"))
}

///|
test "mooncode native eval report normalization preserves explicit false" {
  let native_eval = normalize_native_eval_report(
    { "ok": false, "native_eval_evidence_ready": true },
    "/v1/code/sessions/s2/eval-report",
  )
  assert_false(json_bool(native_eval, "ok", default=true))
  assert_eq(
    json_string(native_eval, "endpoint", default=""),
    "/v1/code/sessions/s2/eval-report",
  )
}

///|
test "mooncode eval report projection cleanup is MoonCode-owned" {
  let cleaned = session_without_eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "mooncode_summary": { "eval_checks": [] },
    "mooncode_last_eval_report_manifest": { "kind": "mooncode-eval-report" },
    "mooncode_native_eval_report": { "ok": true },
  })
  assert_eq(json_string(cleaned, "id", default=""), "s1")
  assert_eq(json_string(cleaned, "workspace_id", default=""), "book")
  assert_true(summary_json_object_field(cleaned, "mooncode_summary") is None)
  assert_true(
    summary_json_object_field(cleaned, "mooncode_last_eval_report_manifest")
    is None,
  )
  assert_true(
    summary_json_object_field(cleaned, "mooncode_native_eval_report") is Some(_),
  )
}

///|
test "mooncode saved eval manifest updates session and carries native evidence" {
  let next = session_with_saved_eval_manifest({ "id": "s1" }, {
    "kind": "mooncode-eval-report",
    "manifest_path": "wiki/reviews/mooncode/s1/eval-report.json",
    "native_eval_report": { "ok": true, "status": "accepted" },
  })
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(
        next, "mooncode_last_eval_report_manifest",
      ),
      "manifest_path",
      default="",
    ),
    "wiki/reviews/mooncode/s1/eval-report.json",
  )
  let native = summary_json_object_field_or_empty(
    next, "mooncode_native_eval_report",
  )
  assert_true(json_bool(native, "ok", default=false))
  assert_eq(json_string(native, "status", default=""), "accepted")
}

///|
test "mooncode saved eval manifest keeps existing accepted native evidence" {
  let next = session_with_saved_eval_manifest(
    {
      "id": "s1",
      "mooncode_native_eval_report": {
        "ok": true,
        "status": "previously-accepted",
      },
    },
    {
      "kind": "mooncode-eval-report",
      "native_eval_report": { "ok": true, "status": "newer" },
    },
  )
  let native = summary_json_object_field_or_empty(
    next, "mooncode_native_eval_report",
  )
  assert_eq(json_string(native, "status", default=""), "previously-accepted")
}

///|
fn eval_report_wbtest_json_string_array_items(
  json : Json,
  key : String,
) -> Array[String] {
  let values = json_array_items(json, key)
  let result : Array[String] = []
  for value in values {
    match value {
      String(item) => result.push(item)
      _ => ()
    }
  }
  result
}

///|
test "mooncode saved eval manifest does not promote failed native evidence" {
  let next = session_with_saved_eval_manifest({ "id": "s1" }, {
    "kind": "mooncode-eval-report",
    "native_eval_report": { "ok": false, "status": "failed" },
  })
  let native = summary_json_object_field_or_empty(
    next, "mooncode_native_eval_report",
  )
  assert_eq(native.stringify(), "{}")
}
