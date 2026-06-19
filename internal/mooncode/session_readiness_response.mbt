///|
// MoonCode readiness summary and HTTP response projection contracts.

///|
pub fn readiness_passed_count(checks : Array[Json]) -> Int {
  let mut passed = 0
  for check in checks {
    if json_bool(check, "ok", default=false) {
      passed += 1
    }
  }
  passed
}

///|
pub fn readiness_summary(checks : Array[Json]) -> Json {
  let failed_checks : Array[Json] = []
  for check in checks {
    if !json_bool(check, "ok", default=false) {
      failed_checks.push(check)
    }
  }
  let first_blocker = first_failed_readiness_check(checks)
  let blocker_id = json_string(first_blocker, "id", default="")
  {
    "kind": "mooncode-readiness",
    "protocol": protocol_version(),
    "standalone_component": "mooncode",
    "ready": checks.length() > 0 && failed_checks.length() == 0,
    "passed_count": readiness_passed_count(checks),
    "check_count": checks.length(),
    "blocked_count": failed_checks.length(),
    "first_blocker_id": blocker_id,
    "first_blocker_label": json_string(first_blocker, "label", default=""),
    "first_blocker_evidence": json_string(first_blocker, "evidence", default=""),
    "next_action": readiness_next_action(blocker_id),
    "next_owner": readiness_next_owner(blocker_id),
    "blocking_check_ids": Json::array(
      [
        for check in failed_checks => {
          Json::string(json_string(check, "id", default=""))
        }
      ],
    ),
    "rule": "Readiness is derived from MoonCode protocol evidence and MoonBook artifacts. Moondesk renders this summary; MoonClaw still owns execution.",
  }
}

///|
pub fn session_readiness_response(session : Json) -> Json {
  let events = json_array_items(session, "mooncode_events")
  let current_summary = summary_json_object_field_or_empty(
    session, "mooncode_summary",
  )
  let summary = if json_string(current_summary, "protocol", default="") == "" {
    session_summary(session, events)
  } else {
    current_summary
  }
  let checks = json_array_items(summary, "readiness_checks")
  let readiness = summary_json_object_field_or_empty(summary, "readiness")
  let session_id = json_string(
    summary,
    "session_id",
    default=json_string(session, "id", default=""),
  )
  {
    "kind": "mooncode-session-readiness",
    "protocol": protocol_version(),
    "standalone_component": "mooncode",
    "session_id": session_id,
    "workspace_id": json_string(
      summary,
      "workspace_id",
      default=json_string(session, "workspace_id", default=""),
    ),
    "readiness": readiness,
    "passed_count": summary_json_int(
      summary,
      "readiness_passed_check_count",
      default=0,
    ),
    "check_count": summary_json_int(summary, "readiness_check_count", default=0),
    "blocked_count": summary_json_int(readiness, "blocked_count", default=0),
    "first_blocker_id": json_string(readiness, "first_blocker_id", default=""),
    "next_action": json_string(readiness, "next_action", default="completed"),
    "next_owner": json_string(readiness, "next_owner", default="none"),
    "checks": Json::array(checks),
    "contract": readiness_contract_json(),
    "evidence_paths": {
      "event_log_path": json_string(summary, "event_log_path", default=""),
      "command_log_path": json_string(summary, "command_log_path", default=""),
      "runtime_command_log_path": json_string(
        summary,
        "runtime_command_log_path",
        default="",
      ),
      "runtime_dispatch_log_path": json_string(
        summary,
        "runtime_dispatch_log_path",
        default="",
      ),
      "session_snapshot_path": json_string(
        summary,
        "session_snapshot_path",
        default="",
      ),
    },
    "endpoint": if session_id == "" {
      ""
    } else {
      "/api/mooncode/sessions/\{session_id}/readiness"
    },
    "rule": "This response is session readiness telemetry for Moondesk dashboards and protocol audits. It is derived from projected MoonCode events plus MoonBook review/runtime artifacts, not from UI-only state.",
  }
}

///|
fn first_failed_readiness_check(checks : Array[Json]) -> Json {
  for check in checks {
    if !json_bool(check, "ok", default=false) {
      return check
    }
  }
  {}
}
