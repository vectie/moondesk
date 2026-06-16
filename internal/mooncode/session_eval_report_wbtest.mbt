///|
test "mooncode eval report projection stays extractable" {
  let checks = [
    eval_check("book_scope", "Book scope", true, "book"),
    eval_check("native_eval", "Native eval", false, "missing"),
  ]
  let summary : Json = {
    "eval_score": eval_score(checks),
    "eval_level": eval_level(checks),
    "eval_checks": Json::array(checks),
  }
  let report = eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "moonclaw_task_id": "task",
    "mooncode_summary": summary,
  })
  assert_eq(json_string(report, "kind", default=""), "mooncode-eval-report")
  assert_eq(
    json_string(report, "extractable_component", default=""),
    "mooncode",
  )
  assert_eq(summary_json_int(report, "passed_check_count", default=0), 1)
}

///|
test "mooncode native eval report normalization accepts legacy readiness" {
  let native_eval = normalize_native_eval_report(
    {
      "native_eval_evidence_ready": true,
      "harnesses": ["tool_harness", "file_edit"],
    },
    "/v1/mooncode/sessions/s1/eval-report",
  )
  assert_true(json_bool(native_eval, "ok", default=false))
  assert_eq(
    json_string(native_eval, "source", default=""),
    "moonclaw-native-runtime",
  )
  assert_eq(
    json_string(native_eval, "endpoint", default=""),
    "/v1/mooncode/sessions/s1/eval-report",
  )
  assert_eq(json_array_items(native_eval, "harnesses").length(), 2)
}

///|
test "mooncode native eval report normalization accepts MoonClaw harness status" {
  let native_eval = normalize_native_eval_report(
    {
      "kind": "mooncode-native-eval-report",
      "protocol": "mooncode.v1",
      "status": "accepted",
      "native_eval": {
        "status": "passed",
        "harnesses": [
          { "id": "tool_harness", "status": "passed" },
          { "id": "file_edit", "status": "passed" },
        ],
      },
    },
    "/v1/mooncode/sessions/s1/eval-report?book_root=/tmp/book",
  )
  assert_true(json_bool(native_eval, "ok", default=false))
  let report = eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "moonclaw_task_id": "task",
    "mooncode_native_eval_report": native_eval,
    "mooncode_summary": {
      "eval_score": 100,
      "eval_level": "ready",
      "eval_checks": [],
    },
  })
  assert_eq(json_string(report, "status", default=""), "production-ready")
  assert_eq(summary_json_int(report, "native_eval_harness_count", default=0), 2)
  assert_eq(
    summary_json_int(report, "native_eval_passed_harness_count", default=0),
    2,
  )
}

///|
test "mooncode native eval report normalization preserves explicit false" {
  let native_eval = normalize_native_eval_report(
    { "ok": false, "native_eval_evidence_ready": true },
    "/v1/mooncode/sessions/s2/eval-report",
  )
  assert_false(json_bool(native_eval, "ok", default=true))
  assert_eq(
    json_string(native_eval, "endpoint", default=""),
    "/v1/mooncode/sessions/s2/eval-report",
  )
}

///|
test "mooncode eval report projection cleanup is MoonCode-owned" {
  let cleaned = session_without_eval_report_projection({
    "id": "s1",
    "workspace_id": "book",
    "mooncode_summary": { "eval_score": 20 },
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
