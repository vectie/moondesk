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
  let missing_required_native_harnesses = native_eval_missing_required_harnesses(
    native_eval,
  )
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
    "protocol": protocol_version(),
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
    "required_native_harness_count": required_native_eval_harness_ids().length(),
    "missing_required_native_harness_count": missing_required_native_harnesses.length(),
    "missing_required_native_harnesses": string_array_json(
      missing_required_native_harnesses,
    ),
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
    "required_native_harnesses": string_array_json(
      required_native_eval_harness_ids(),
    ),
    "minimum_native_evidence": string_array_json([
      "read/edit/write/shell/moon_check tool reliability", "file-edit task success/failure fixtures",
      "patch review and apply/revert proof", "ordered command execution for prompt/steer/cancel/test/build/eval/package/review",
      "package assembly proof for generated tools and miniapps",
    ]),
    "current_gap": if native_ready {
      "MoonClaw reported native eval evidence; remaining bridge/runtime gaps are reflected in the checks array."
    } else {
      "Bridge evidence is visible, but MoonClaw still needs OpenSeek-style tool_harness, file_edit, patch_review, command_execution, and package_output eval results before Moondesk can claim production-grade coding-agent behavior."
    },
    "summary": summary,
  }
}

///|
pub fn eval_report_manifest_response_for_session(
  session : Json,
  events : Array[Json],
  recorded_at~ : String,
  manifest_path~ : String,
  absolute_manifest_path~ : String,
) -> Json {
  let summary = session_summary(session, events)
  let report = eval_report_projection(
    runtime_with_field(session, "mooncode_summary", summary),
  )
  runtime_with_field(
    runtime_with_field(
      runtime_with_field(report, "recorded_at", recorded_at.to_json()),
      "manifest_path",
      manifest_path.to_json(),
    ),
    "absolute_manifest_path",
    absolute_manifest_path.to_json(),
  )
}

///|
pub fn session_with_eval_report_manifest_event(
  session : Json,
  manifest : Json,
  event : Json,
) -> Json {
  let with_manifest = session_with_manifest_event(
    session, "mooncode_last_eval_report_manifest", manifest, event,
  )
  let events = project_session_events_for_session(with_manifest, [], [])
  session_with_field(
    with_manifest,
    "mooncode_summary",
    session_summary(with_manifest, events),
  )
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
pub fn session_with_native_eval_report(
  session : Json,
  report : Json,
  endpoint : String,
) -> Json {
  runtime_with_field(
    session,
    "mooncode_native_eval_report",
    normalize_native_eval_report(report, endpoint),
  )
}

///|
fn eval_report_with_field(base : Json, key : String, value : Json) -> Json {
  match base {
    Json::Object(fields) => {
      let next : Map[String, Json] = {}
      for item in fields {
        next[item.0] = item.1
      }
      next[key] = value
      Json::object(next)
    }
    _ => base
  }
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
pub fn session_with_saved_eval_manifest(
  session : Json,
  manifest : Json,
) -> Json {
  let with_manifest = runtime_with_field(
    session, "mooncode_last_eval_report_manifest", manifest,
  )
  let native_report = summary_json_object_field_or_empty(
    manifest, "native_eval_report",
  )
  if json_bool(native_report, "ok", default=false) &&
    !json_bool(
      summary_json_object_field_or_empty(session, "mooncode_native_eval_report"),
      "ok",
      default=false,
    ) {
    runtime_with_field(
      with_manifest, "mooncode_native_eval_report", native_report,
    )
  } else {
    with_manifest
  }
}

///|
fn native_eval_report_ready(report : Json) -> Bool {
  match summary_json_object_field(report, "ok") {
    Some(value) =>
      if !(@json.from_json(value) catch { _ => false }) {
        return false
      }
    None => ()
  }
  native_eval_missing_required_harnesses(report).length() == 0
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
fn required_native_eval_harness_ids() -> Array[String] {
  [
    "tool_harness", "file_edit", "patch_review", "command_execution", "package_output",
  ]
}

///|
fn native_eval_missing_required_harnesses(report : Json) -> Array[String] {
  let harnesses = native_eval_report_harnesses(report)
  let missing : Array[String] = []
  for required in required_native_eval_harness_ids() {
    let mut found = false
    for harness in harnesses {
      if native_eval_harness_id(harness) == required &&
        native_eval_harness_passed(harness) {
        found = true
      }
    }
    if !found {
      missing.push(required)
    }
  }
  missing
}

///|
fn native_eval_harness_id(harness : Json) -> String {
  match harness {
    Json::String(value) => value
    _ => json_string(harness, "id", default="")
  }
}

///|
fn native_eval_harness_passed(harness : Json) -> Bool {
  match harness {
    Json::String(_) => false
    _ => {
      let status = json_string(harness, "status", default="")
      status == "passed" || status == "accepted"
    }
  }
}

///|
fn native_eval_passed_harness_count(harnesses : Array[Json]) -> Int {
  let mut count = 0
  for harness in harnesses {
    if native_eval_harness_passed(harness) {
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
