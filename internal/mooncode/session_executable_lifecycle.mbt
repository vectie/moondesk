///|
// Ordered executable-book lifecycle evidence derived from MoonCode readiness.

///|
pub fn session_executable_book_lifecycle(
  session : Json,
  events : Array[Json],
) -> Json {
  executable_book_lifecycle_report_from_checks(
    session_readiness_checks(session, events),
  )
}

///|
pub fn executable_book_lifecycle_report_from_checks(
  checks : Array[Json],
) -> Json {
  let steps = [
    for step_id in executable_book_lifecycle_steps() => {
      executable_book_lifecycle_step_report(step_id, checks)
    }
  ]
  let passed_count = executable_book_lifecycle_passed_count(steps)
  let first_blocker = first_blocked_lifecycle_step(steps)
  let step_count = steps.length()
  let ready = step_count > 0 && passed_count == step_count
  {
    "kind": "mooncode-executable-book-lifecycle-report",
    "protocol": protocol_version(),
    "contract_id": executable_book_lifecycle_contract_id(),
    "standalone_component": "mooncode",
    "ready": ready,
    "status": if ready {
      "complete"
    } else {
      "blocked"
    },
    "completed_step_count": passed_count,
    "step_count": step_count,
    "blocked_step_count": step_count - passed_count,
    "first_blocker_id": json_string(first_blocker, "id", default=""),
    "first_blocker_label": json_string(first_blocker, "label", default=""),
    "first_blocker_evidence": json_string(first_blocker, "evidence", default=""),
    "steps": Json::array(steps),
    "rule": "Executable-book lifecycle is an ordered projection over MoonCode readiness evidence. MoonClaw owns execution, MoonBook owns artifacts, Bookkeeper owns acceptance, and desktop shells only render this report.",
  }
}

///|
fn executable_book_lifecycle_step_report(
  step_id : String,
  checks : Array[Json],
) -> Json {
  let required_checks = lifecycle_step_required_checks(step_id)
  let matched_checks = lifecycle_matched_checks(required_checks, checks)
  let ok = required_checks.length() > 0 &&
    lifecycle_all_required_checks_passed(required_checks, checks)
  {
    "id": step_id,
    "label": lifecycle_step_label(step_id),
    "ok": ok,
    "owner": lifecycle_step_owner(step_id),
    "required_checks": string_array_json(required_checks),
    "evidence": lifecycle_step_evidence(step_id, matched_checks),
    "checks": Json::array(matched_checks),
  }
}

///|
fn lifecycle_step_required_checks(step_id : String) -> Array[String] {
  match step_id {
    "select_book" => ["moonbook_selected"]
    "start_session" =>
      [
        "runtime_session_attached", "durable_session", "runtime_supervisor_ready",
      ]
    "propose_change" => ["canonical_conversation", "typed_command_queue"]
    "edit_code" => ["tool_execution", "diff_review"]
    "verify_code" => ["test_build_execution", "native_eval_ready"]
    "review_diff" => ["review_receipts", "action_plan_current"]
    "accept_result" => ["review_receipts", "live_blockers_clear"]
    "package_output" => ["package_result", "package_lifecycle"]
    "resume_session" => ["resume_lifecycle", "standalone_boundary"]
    _ => []
  }
}

///|
fn lifecycle_step_label(step_id : String) -> String {
  match step_id {
    "select_book" => "Select MoonBook"
    "start_session" => "Start durable runtime session"
    "propose_change" => "Propose executable change"
    "edit_code" => "Edit code in the selected book"
    "verify_code" => "Verify code"
    "review_diff" => "Review diff"
    "accept_result" => "Accept result"
    "package_output" => "Package output"
    "resume_session" => "Resume session"
    _ => step_id
  }
}

///|
fn lifecycle_step_owner(step_id : String) -> String {
  match step_id {
    "select_book" => "moondesk"
    "start_session"
    | "propose_change"
    | "edit_code"
    | "verify_code"
    | "resume_session" => "moonclaw"
    "review_diff" | "accept_result" => "bookkeeper"
    "package_output" => "moonbook"
    _ => "mooncode"
  }
}

///|
fn lifecycle_matched_checks(
  required_checks : Array[String],
  checks : Array[Json],
) -> Array[Json] {
  let matched : Array[Json] = []
  for check_id in required_checks {
    matched.push(lifecycle_check_by_id(checks, check_id))
  }
  matched
}

///|
fn lifecycle_check_by_id(checks : Array[Json], check_id : String) -> Json {
  for check in checks {
    if json_string(check, "id", default="") == check_id {
      return check
    }
  }
  readiness_check(
    check_id,
    lifecycle_missing_check_label(check_id),
    false,
    "missing readiness check",
  )
}

///|
fn lifecycle_missing_check_label(check_id : String) -> String {
  "Missing check \{check_id}"
}

///|
fn lifecycle_all_required_checks_passed(
  required_checks : Array[String],
  checks : Array[Json],
) -> Bool {
  for check_id in required_checks {
    if !json_bool(lifecycle_check_by_id(checks, check_id), "ok", default=false) {
      return false
    }
  }
  true
}

///|
fn lifecycle_step_evidence(step_id : String, checks : Array[Json]) -> String {
  if checks.length() == 0 {
    "no mapped readiness checks for \{step_id}"
  } else {
    [
      for check in checks => {
        "\{json_string(check, "id", default="unknown")}: \{json_string(check, "evidence", default="")}"
      }
    ].join("; ")
  }
}

///|
fn executable_book_lifecycle_passed_count(steps : Array[Json]) -> Int {
  let mut passed = 0
  for step in steps {
    if json_bool(step, "ok", default=false) {
      passed += 1
    }
  }
  passed
}

///|
fn first_blocked_lifecycle_step(steps : Array[Json]) -> Json {
  for step in steps {
    if !json_bool(step, "ok", default=false) {
      return step
    }
  }
  {}
}
