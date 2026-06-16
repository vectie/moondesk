///|
// MoonCode eval-report projection, native evidence normalization, and readiness scoring.

///|
pub fn eval_report_projection(session : Json) -> Json {
  let summary = summary_json_object_field_or_empty(session, "mooncode_summary")
  let checks = json_array_items(summary, "eval_checks")
  let session_id = json_string(session, "id", default="")
  let passed_count = eval_check_passed_count(checks)
  let missing_count = checks.length() - passed_count
  let native_eval = summary_json_object_field_or_empty(
    session, "mooncode_native_eval_report",
  )
  let native_ready = native_eval_report_ready(native_eval)
  let native_harnesses = native_eval_report_harnesses(native_eval)
  let native_passed_harness_count = native_eval_passed_harness_count(
    native_harnesses,
  )
  let bridge_score = summary_json_int(summary, "eval_score", default=0)
  let bridge_level = json_string(summary, "eval_level", default="empty")
  let status = if native_ready && missing_count == 0 {
    "production-ready"
  } else if native_ready {
    "native-partial"
  } else if missing_count == 0 {
    "bridge-ready"
  } else if passed_count > 0 {
    "bridge-partial"
  } else {
    "empty"
  }
  let manifest = summary_json_object_field_or_empty(
    session, "mooncode_last_eval_report_manifest",
  )
  {
    "kind": "mooncode-eval-report",
    "protocol": "mooncode.v1",
    "status": status,
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "runtime_owner": "moonclaw",
    "ui_owner": "moondesk",
    "artifact_owner": "moonbook",
    "extractable_component": "mooncode",
    "bridge_score": bridge_score,
    "bridge_level": bridge_level,
    "passed_check_count": passed_count,
    "missing_check_count": missing_count,
    "check_count": checks.length(),
    "checks": Json::array(checks),
    "native_eval_evidence_ready": native_ready,
    "native_eval_report": native_eval,
    "native_eval_status": json_string(native_eval, "status", default="missing"),
    "native_eval_harness_count": native_harnesses.length(),
    "native_eval_passed_harness_count": native_passed_harness_count,
    "native_eval_failed_harness_count": native_harnesses.length() -
    native_passed_harness_count,
    "native_eval_harnesses": Json::array(native_harnesses),
    "native_eval_source": if native_ready {
      json_string(native_eval, "source", default="moonclaw-native-runtime")
    } else {
      "missing"
    },
    "native_eval_endpoint": json_string(
      native_eval,
      "endpoint",
      default="/v1/mooncode/sessions/<id>/eval-report?book_root=<path>",
    ),
    "native_eval_ingest_method": "POST",
    "native_eval_ingest_endpoint": if session_id == "" {
      "/api/mooncode/sessions/<id>/eval-report"
    } else {
      "/api/mooncode/sessions/\{session_id}/eval-report"
    },
    "recorded_at": json_string(manifest, "recorded_at", default=""),
    "manifest_path": json_string(manifest, "manifest_path", default=""),
    "absolute_manifest_path": json_string(
      manifest,
      "absolute_manifest_path",
      default="",
    ),
    "required_native_harnesses": string_array_json(["tool_harness", "file_edit"]),
    "minimum_native_evidence": string_array_json([
      "read/edit/write/shell/moon_check tool reliability", "file-edit task success/failure fixtures",
      "test/build execution with stdout/stderr", "package assembly proof for generated tools and miniapps",
    ]),
    "current_gap": if native_ready {
      "MoonClaw reported native eval evidence; remaining bridge/runtime gaps are reflected in the checks array."
    } else {
      "Bridge evidence is visible, but MoonClaw still needs OpenSeek-style tool_harness and file_edit eval results before Moondesk can claim production-grade coding-agent behavior."
    },
    "summary": summary,
  }
}

///|
pub fn normalize_native_eval_report(report : Json, endpoint : String) -> Json {
  let ok = native_eval_report_ready(report)
  eval_report_with_field(
    eval_report_with_field(
      eval_report_with_field(report, "ok", ok.to_json()),
      "source",
      "moonclaw-native-runtime".to_json(),
    ),
    "endpoint",
    endpoint.to_json(),
  )
}

///|
pub fn session_without_eval_report_projection(session : Json) -> Json {
  let object : Map[String, Json] = {}
  match session {
    Json::Object(fields) =>
      for key, value in fields {
        if key != "mooncode_last_eval_report_manifest" &&
          key != "mooncode_summary" {
          object[key] = value
        }
      }
    _ => ()
  }
  Json::object(object)
}

///|
fn native_eval_report_ready(report : Json) -> Bool {
  match summary_json_object_field(report, "ok") {
    Some(value) => return @json.from_json(value) catch { _ => false }
    None => ()
  }
  if json_bool(report, "native_eval_evidence_ready", default=false) {
    return true
  }
  let status = json_string(report, "status", default="")
  if status == "accepted" || status == "passed" || status == "production-ready" {
    return true
  }
  let native_eval = summary_json_object_field_or_empty(report, "native_eval")
  let nested_status = json_string(native_eval, "status", default="")
  if nested_status == "passed" || nested_status == "accepted" {
    return true
  }
  let harnesses = native_eval_report_harnesses(report)
  harnesses.length() > 0 &&
  native_eval_passed_harness_count(harnesses) == harnesses.length()
}

///|
fn native_eval_report_harnesses(report : Json) -> Array[Json] {
  let native_eval = summary_json_object_field_or_empty(report, "native_eval")
  let nested = json_array_items(native_eval, "harnesses")
  if nested.length() > 0 {
    return nested
  }
  json_array_items(report, "harnesses")
}

///|
fn native_eval_passed_harness_count(harnesses : Array[Json]) -> Int {
  let mut count = 0
  for harness in harnesses {
    let status = json_string(harness, "status", default="")
    if status == "passed" || status == "accepted" {
      count += 1
    }
  }
  count
}

///|
pub fn eval_check_passed_count(checks : Array[Json]) -> Int {
  let mut count = 0
  for check in checks {
    if json_bool(check, "ok", default=false) {
      count += 1
    }
  }
  count
}

///|
pub fn eval_check(
  id : String,
  label : String,
  ok : Bool,
  evidence : String,
) -> Json {
  { "id": id, "label": label, "ok": ok, "evidence": evidence }
}

///|
pub fn eval_score(checks : Array[Json]) -> Int {
  if checks.length() == 0 {
    return 0
  }
  let mut passed = 0
  for check in checks {
    if json_bool(check, "ok", default=false) {
      passed += 1
    }
  }
  passed * 100 / checks.length()
}

///|
pub fn eval_level(checks : Array[Json]) -> String {
  let score = eval_score(checks)
  if score >= 85 {
    "ready"
  } else if score >= 50 {
    "partial"
  } else if score > 0 {
    "early"
  } else {
    "empty"
  }
}

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
