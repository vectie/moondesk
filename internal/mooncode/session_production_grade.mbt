///|
// MoonCode product-grade scoring for the end-to-end workspace success criteria.

///|
pub fn production_grade_check(
  id : String,
  label : String,
  ok : Bool,
  evidence : String,
) -> Json {
  { "id": id, "label": label, "ok": ok, "evidence": evidence }
}

///|
fn production_grade_rubric_check(
  id : String,
  label : String,
  evidence_required : String,
) -> Json {
  {
    "id": id,
    "label": label,
    "evidence_required": evidence_required,
    "next_action": production_next_action(id),
    "next_owner": production_next_owner(id),
  }
}

///|
pub fn production_grade_rubric_json() -> Json {
  let checks = [
    production_grade_rubric_check(
      "moonbook_selected", "MoonBook selected", "selected workspace/book id is present",
    ),
    production_grade_rubric_check(
      "moonclaw_attached", "MoonClaw session attached", "book-scoped MoonClaw task/session id is present",
    ),
    production_grade_rubric_check(
      "durable_session", "Durable session", "append-only event log, command log, and session snapshot are persisted",
    ),
    production_grade_rubric_check(
      "resume_lifecycle", "Resume lifecycle", "session snapshot can be resumed and is not blocked",
    ),
    production_grade_rubric_check(
      "chat_transcript", "Chat transcript", "assistant/transcript lane has durable chat evidence",
    ),
    production_grade_rubric_check(
      "typed_command_queue", "Typed command queue", "mooncode.v1 command packet and runtime command queue are present",
    ),
    production_grade_rubric_check(
      "live_runtime_stream", "Live runtime stream", "runtime events and dispatch receipts prove live progress",
    ),
    production_grade_rubric_check(
      "tool_execution", "Tool execution", "tool lane has MoonClaw or standalone MoonCode execution evidence",
    ),
    production_grade_rubric_check(
      "diff_review", "Diff review", "diff events plus MoonBook change-set and patch-set manifests exist",
    ),
    production_grade_rubric_check(
      "test_build_execution", "Test/build execution", "verified test/build result exists, no failing tests remain, and test-run manifest exists",
    ),
    production_grade_rubric_check(
      "review_receipts", "Review receipts", "review lane and MoonBook accept/reject receipt are present",
    ),
    production_grade_rubric_check(
      "package_result", "Package result", "source-bound package, package index, artifact event, and verified package proof exist",
    ),
    production_grade_rubric_check(
      "package_lifecycle", "Package lifecycle", "package lifecycle is verified and executable-ready",
    ),
    production_grade_rubric_check(
      "action_plan_current", "Current action plan", "MoonBook action-plan manifest is current",
    ),
    production_grade_rubric_check(
      "live_blockers_clear", "Live blockers clear", "no blocked action, pending diff, pending tool approval, pending steer, or failing test remains",
    ),
    production_grade_rubric_check(
      "extractable_boundary", "Extractable MoonCode boundary", "runtime handoff manifest proves the protocol/runtime boundary",
    ),
  ]
  {
    "kind": "mooncode-production-grade-rubric",
    "protocol": protocol_version(),
    "extractable_component": "mooncode",
    "score_rule": "score = passed_check_count * 100 / check_count",
    "thresholds": [
      { "level": "production-grade", "min_score": 95 },
      { "level": "near-production", "min_score": 80 },
      { "level": "working-slice", "min_score": 60 },
      { "level": "prototype", "min_score": 1 },
      { "level": "empty", "min_score": 0 },
    ],
    "check_count": checks.length(),
    "checks": checks,
    "readiness_contract": "production_readiness_summary(checks) returns ready, score, level, first blocker, next action, next owner, and blocking check ids.",
    "owner_rule": "MoonCode owns the rubric and readiness projection; Moondesk renders the score, MoonClaw or standalone mooncode provides execution evidence, and MoonBook owns accepted artifacts and review state.",
  }
}

///|
pub fn session_production_checks(
  session : Json,
  events : Array[Json],
) -> Array[Json] {
  let workspace_id = json_string(session, "workspace_id", default="")
  let task_id = json_string(session, "moonclaw_task_id", default="")
  let transcript_count = count_lane(events, "transcript")
  let runtime_count = count_lane(events, "runtime")
  let tool_count = count_lane(events, "tool")
  let diff_count = count_lane(events, "diff")
  let test_count = count_lane(events, "test")
  let artifact_count = count_lane(events, "artifact")
  let review_count = count_lane(events, "review")
  let verified_test_count = count_verified_tests(events)
  let failed_test_count = count_failed_tests(events)
  let command_packet_count = count_command_packets(events)
  let review_receipt_count = count_review_receipts(events)
  let package_manifest_count = count_package_manifests(events)
  let package_index_manifest_count = count_package_index_manifests(events)
  let change_set_manifest_count = count_change_set_manifests(events)
  let patch_set_manifest_count = count_patch_set_manifests(events)
  let test_runs_manifest_count = count_test_runs_manifests(events)
  let runtime_handoff_manifest_count = count_runtime_handoff_manifests(events)
  let action_plan = summary_json_object_field_or_empty(
    session, "mooncode_last_action_plan_manifest",
  )
  let action_plan_ready = json_string(action_plan, "kind", default="") ==
    "mooncode-action-plan"
  let action_plan_status = json_string(action_plan, "status", default="")
  let next_required_action = json_string(
    action_plan,
    "next_required_action",
    default="",
  )
  let blocked_action_count = summary_json_int(
    action_plan,
    "blocked_count",
    default=0,
  )
  let pending_runtime_count = summary_json_int(
    action_plan,
    "pending_runtime_count",
    default=0,
  )
  let running_count = summary_json_int(action_plan, "running_count", default=0)
  let pending_action_diff_count = summary_json_int(
    action_plan,
    "pending_diff_count",
    default=0,
  )
  let pending_action_tool_approval_count = summary_json_int(
    action_plan,
    "pending_tool_approval_count",
    default=0,
  )
  let pending_action_steer_count = summary_json_int(
    action_plan,
    "pending_steer_count",
    default=0,
  )
  let failed_action_test_count = summary_json_int(
    action_plan,
    "failed_test_count",
    default=failed_test_count,
  )
  let source_bound_package_count = count_source_bound_packages(
    session, package_manifest_count,
  )
  let runtime_package_proof_count = count_package_runtime_proofs(events)
  let runtime_verified_package_count = count_package_runtime_state(
    events, "verified",
  )
  let append_log_count = summary_json_int(
    session,
    "mooncode_append_log_count",
    default=0,
  )
  let command_log_count = summary_json_int(
    session,
    "mooncode_command_log_count",
    default=0,
  )
  let runtime_command_log_count = summary_json_int(
    session,
    "mooncode_runtime_command_log_count",
    default=0,
  )
  let runtime_dispatch_log_count = summary_json_int(
    session,
    "mooncode_runtime_dispatch_log_count",
    default=0,
  )
  let snapshot = summary_json_object_field_or_empty(
    session, "mooncode_session_snapshot",
  )
  let session_snapshot_ready = json_string(snapshot, "kind", default="") ==
    "mooncode-session-snapshot"
  let resume_lifecycle = session_resume_lifecycle(session, events)
  let resume_status = json_string(resume_lifecycle, "latest_status", default="")
  let resume_ok = json_bool(resume_lifecycle, "snapshot_ready", default=false) &&
    resume_status != "missing-snapshot" &&
    resume_status != "blocked"
  let package_lifecycle = session_package_lifecycle(session, events)
  let package_lifecycle_status = json_string(
    package_lifecycle,
    "latest_status",
    default="",
  )
  let package_lifecycle_verified = package_lifecycle_status == "verified" &&
    summary_json_int(
      package_lifecycle,
      "runtime_verified_package_count",
      default=0,
    ) >
    0 &&
    summary_json_int(package_lifecycle, "executable_ready_count", default=0) > 0
  [
    production_grade_check(
      "moonbook_selected",
      "MoonBook selected",
      workspace_id != "",
      if workspace_id == "" {
        "no selected workspace id"
      } else {
        workspace_id
      },
    ),
    production_grade_check(
      "moonclaw_attached",
      "MoonClaw session attached",
      task_id != "",
      if task_id == "" {
        "no MoonClaw task id"
      } else {
        task_id
      },
    ),
    production_grade_check(
      "durable_session",
      "Durable session",
      append_log_count > 0 && command_log_count > 0 && session_snapshot_ready,
      "\{append_log_count} event(s), \{command_log_count} command(s), snapshot \{if session_snapshot_ready { "ready" } else { "missing" }}",
    ),
    production_grade_check(
      "resume_lifecycle",
      "Resume lifecycle",
      resume_ok,
      "status \{empty_production_label(resume_status)}, pending \{summary_json_int(resume_lifecycle, "pending_count", default=0)}, running \{summary_json_int(resume_lifecycle, "running_count", default=0)}, blocked \{summary_json_int(resume_lifecycle, "blocked_count", default=0)}",
    ),
    production_grade_check(
      "chat_transcript",
      "Chat transcript",
      transcript_count > 0,
      "\{transcript_count} transcript event(s)",
    ),
    production_grade_check(
      "typed_command_queue",
      "Typed command queue",
      command_packet_count > 0 && runtime_command_log_count > 0,
      "\{command_packet_count} command packet(s), \{runtime_command_log_count} runtime command(s)",
    ),
    production_grade_check(
      "live_runtime_stream",
      "Live runtime stream",
      runtime_count > 0 && runtime_dispatch_log_count > 0,
      "\{runtime_count} runtime event(s), \{runtime_dispatch_log_count} dispatch receipt(s)",
    ),
    production_grade_check(
      "tool_execution",
      "Tool execution",
      tool_count > 0,
      "\{tool_count} tool event(s)",
    ),
    production_grade_check(
      "diff_review",
      "Diff review",
      diff_count > 0 &&
      change_set_manifest_count > 0 &&
      patch_set_manifest_count > 0,
      "\{diff_count} diff event(s), \{change_set_manifest_count} change-set manifest(s), \{patch_set_manifest_count} patch-set manifest(s)",
    ),
    production_grade_check(
      "test_build_execution",
      "Test/build execution",
      test_count > 0 &&
      verified_test_count > 0 &&
      failed_test_count == 0 &&
      test_runs_manifest_count > 0,
      if failed_test_count > 0 {
        "\{failed_test_count} failing test/build result(s)"
      } else {
        "\{verified_test_count} verified result(s), \{test_runs_manifest_count} test-run manifest(s)"
      },
    ),
    production_grade_check(
      "review_receipts",
      "Review receipts",
      review_count > 0 && review_receipt_count > 0,
      "\{review_count} review event(s), \{review_receipt_count} MoonBook receipt(s)",
    ),
    production_grade_check(
      "package_result",
      "Package result",
      artifact_count > 0 &&
      source_bound_package_count > 0 &&
      package_index_manifest_count > 0 &&
      runtime_verified_package_count > 0,
      "\{artifact_count} artifact event(s), \{source_bound_package_count} source-bound package(s), \{package_index_manifest_count} package index manifest(s), \{runtime_verified_package_count}/\{runtime_package_proof_count} verified runtime package proof",
    ),
    production_grade_check(
      "package_lifecycle",
      "Package lifecycle",
      package_lifecycle_verified,
      "status \{empty_production_label(package_lifecycle_status)}, executable-ready \{summary_json_int(package_lifecycle, "executable_ready_count", default=0)}, verified \{summary_json_int(package_lifecycle, "runtime_verified_package_count", default=0)}",
    ),
    production_grade_check(
      "action_plan_current",
      "Current action plan",
      action_plan_ready,
      if action_plan_ready {
        "status \{empty_production_label(action_plan_status)}, next \{empty_production_label(next_required_action)}"
      } else {
        "no MoonBook action-plan manifest"
      },
    ),
    production_grade_check(
      "live_blockers_clear",
      "Live blockers clear",
      action_plan_ready &&
      blocked_action_count == 0 &&
      pending_action_diff_count == 0 &&
      pending_action_tool_approval_count == 0 &&
      pending_action_steer_count == 0 &&
      failed_action_test_count == 0,
      "blocked \{blocked_action_count}, pending runtime \{pending_runtime_count}, running \{running_count}, pending diffs \{pending_action_diff_count}, pending tools \{pending_action_tool_approval_count}, pending steers \{pending_action_steer_count}, failing tests \{failed_action_test_count}",
    ),
    production_grade_check(
      "extractable_boundary",
      "Extractable MoonCode boundary",
      runtime_handoff_manifest_count > 0,
      "\{runtime_handoff_manifest_count} runtime handoff manifest(s); MoonCode owns protocol/projection while MoonClaw owns execution",
    ),
  ]
}

///|
fn empty_production_label(value : String) -> String {
  if value == "" {
    "empty"
  } else {
    value
  }
}

///|
pub fn production_grade_score(checks : Array[Json]) -> Int {
  if checks.length() == 0 {
    return 0
  }
  production_grade_passed_count(checks) * 100 / checks.length()
}

///|
pub fn production_grade_level(checks : Array[Json]) -> String {
  let score = production_grade_score(checks)
  if score >= 95 {
    "production-grade"
  } else if score >= 80 {
    "near-production"
  } else if score >= 60 {
    "working-slice"
  } else if score > 0 {
    "prototype"
  } else {
    "empty"
  }
}

///|
pub fn production_grade_passed_count(checks : Array[Json]) -> Int {
  let mut passed = 0
  for check in checks {
    if json_bool(check, "ok", default=false) {
      passed += 1
    }
  }
  passed
}

///|
pub fn production_readiness_summary(checks : Array[Json]) -> Json {
  let failed_checks : Array[Json] = []
  for check in checks {
    if !json_bool(check, "ok", default=false) {
      failed_checks.push(check)
    }
  }
  let first_blocker = first_failed_production_check(checks)
  let blocker_id = json_string(first_blocker, "id", default="")
  {
    "kind": "mooncode-production-readiness",
    "protocol": protocol_version(),
    "extractable_component": "mooncode",
    "ready": checks.length() > 0 && failed_checks.length() == 0,
    "score": production_grade_score(checks),
    "level": production_grade_level(checks),
    "passed_count": production_grade_passed_count(checks),
    "check_count": checks.length(),
    "blocked_count": failed_checks.length(),
    "first_blocker_id": blocker_id,
    "first_blocker_label": json_string(first_blocker, "label", default=""),
    "first_blocker_evidence": json_string(first_blocker, "evidence", default=""),
    "next_action": production_next_action(blocker_id),
    "next_owner": production_next_owner(blocker_id),
    "blocking_check_ids": Json::array(
      [
        for check in failed_checks => {
          Json::string(json_string(check, "id", default=""))
        }
      ],
    ),
    "rule": "Production readiness is derived from MoonCode protocol evidence and MoonBook artifacts. Moondesk renders this summary; MoonClaw or standalone mooncode still owns execution.",
  }
}

///|
pub fn session_production_readiness_response(session : Json) -> Json {
  let events = json_array_items(session, "mooncode_events")
  let current_summary = summary_json_object_field_or_empty(
    session, "mooncode_summary",
  )
  let summary = if json_string(current_summary, "protocol", default="") == "" {
    session_summary(session, events)
  } else {
    current_summary
  }
  let checks = json_array_items(summary, "production_checks")
  let readiness = summary_json_object_field_or_empty(
    summary, "production_readiness",
  )
  let session_id = json_string(
    summary,
    "session_id",
    default=json_string(session, "id", default=""),
  )
  {
    "kind": "mooncode-session-production-readiness",
    "protocol": protocol_version(),
    "extractable_component": "mooncode",
    "session_id": session_id,
    "workspace_id": json_string(
      summary,
      "workspace_id",
      default=json_string(session, "workspace_id", default=""),
    ),
    "readiness": readiness,
    "score": summary_json_int(summary, "production_score", default=0),
    "level": json_string(summary, "production_level", default="empty"),
    "passed_count": summary_json_int(
      summary,
      "production_passed_check_count",
      default=0,
    ),
    "check_count": summary_json_int(
      summary,
      "production_check_count",
      default=0,
    ),
    "blocked_count": summary_json_int(readiness, "blocked_count", default=0),
    "first_blocker_id": json_string(readiness, "first_blocker_id", default=""),
    "next_action": json_string(readiness, "next_action", default="completed"),
    "next_owner": json_string(readiness, "next_owner", default="none"),
    "checks": Json::array(checks),
    "rubric": production_grade_rubric_json(),
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
      "/api/mooncode/sessions/\{session_id}/production-readiness"
    },
    "rule": "This response is the session-scoped production gate for Moondesk dashboards and standalone mooncode audits. It is derived from projected MoonCode events plus MoonBook review/runtime artifacts, not from UI-only state.",
  }
}

///|
fn first_failed_production_check(checks : Array[Json]) -> Json {
  for check in checks {
    if !json_bool(check, "ok", default=false) {
      return check
    }
  }
  {}
}

///|
fn production_next_action(blocker_id : String) -> String {
  match blocker_id {
    "" => "completed"
    "moonbook_selected" => "select_moonbook"
    "moonclaw_attached" => "attach_moonclaw_session"
    "durable_session" => "persist_session_snapshot"
    "resume_lifecycle" => "resume_runtime"
    "chat_transcript" => "send_prompt"
    "typed_command_queue" => "queue_prompt_command"
    "live_runtime_stream" => "run_native_runtime_service"
    "tool_execution" => "run_tool_execution"
    "diff_review" => "review_patch_set"
    "test_build_execution" => "run_tests_or_build"
    "review_receipts" => "accept_or_reject_changes"
    "package_result" => "package_result"
    "package_lifecycle" => "verify_package"
    "action_plan_current" => "refresh_action_plan"
    "live_blockers_clear" => "resolve_live_blockers"
    "extractable_boundary" => "write_runtime_handoff"
    _ => "inspect_production_check"
  }
}

///|
fn production_next_owner(blocker_id : String) -> String {
  match blocker_id {
    "" => "none"
    "moonbook_selected" => "moondesk"
    "moonclaw_attached" => "moondesk-moonclaw"
    "durable_session" => "mooncode-moonbook"
    "resume_lifecycle" => "moonclaw-or-standalone-mooncode"
    "chat_transcript" => "moondesk-moonclaw"
    "typed_command_queue" => "mooncode"
    "live_runtime_stream" => "moonclaw-or-standalone-mooncode"
    "tool_execution" => "moonclaw"
    "diff_review" => "moondesk-moonbook"
    "test_build_execution" => "moonclaw"
    "review_receipts" => "moondesk-moonbook"
    "package_result" => "moonbook-moonclaw"
    "package_lifecycle" => "moonbook-moonclaw"
    "action_plan_current" => "mooncode-moonbook"
    "live_blockers_clear" => "moondesk-moonclaw"
    "extractable_boundary" => "mooncode"
    _ => "mooncode"
  }
}
