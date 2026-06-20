///|
test "mooncode executable book lifecycle blocks without evidence" {
  let report = executable_book_lifecycle_report_from_checks([])
  assert_eq(
    json_string(report, "kind", default=""),
    "mooncode-executable-book-lifecycle-report",
  )
  assert_eq(
    json_string(report, "contract_id", default=""),
    executable_book_lifecycle_contract_id(),
  )
  assert_false(json_bool(report, "ready", default=true))
  assert_eq(json_string(report, "status", default=""), "blocked")
  assert_eq(
    summary_json_int(report, "step_count", default=0),
    executable_book_lifecycle_steps().length(),
  )
  assert_eq(json_string(report, "first_blocker_id", default=""), "select_book")
  let steps = json_array_items(report, "steps")
  assert_eq(json_string(steps[0], "id", default=""), "select_book")
  assert_false(json_bool(steps[0], "ok", default=true))
  assert_true(
    json_string(steps[0], "evidence", default="").contains(
      "missing readiness check",
    ),
  )
}

///|
test "mooncode executable book lifecycle completes from readiness evidence" {
  let checks : Array[Json] = [
    readiness_check("moonbook_selected", "MoonBook selected", true, "book"),
    readiness_check(
      "runtime_session_attached", "Runtime attached", true, "runtime",
    ),
    readiness_check("durable_session", "Durable session", true, "snapshot"),
    readiness_check(
      "runtime_supervisor_ready", "Runtime supervisor", true, "ready",
    ),
    readiness_check("chat_transcript", "Chat transcript", true, "assistant"),
    readiness_check(
      "typed_command_queue", "Typed command queue", true, "command",
    ),
    readiness_check("tool_execution", "Tool execution", true, "tool"),
    readiness_check("diff_review", "Diff review", true, "diff"),
    readiness_check(
      "test_build_execution", "Test/build execution", true, "passed",
    ),
    readiness_check("native_eval_ready", "Native eval", true, "passed"),
    readiness_check("review_receipts", "Review receipts", true, "accepted"),
    readiness_check(
      "action_plan_current", "Current action plan", true, "complete",
    ),
    readiness_check("live_blockers_clear", "Live blockers clear", true, "clear"),
    readiness_check("package_result", "Package result", true, "source-bound"),
    readiness_check("package_lifecycle", "Package lifecycle", true, "verified"),
    readiness_check("resume_lifecycle", "Resume lifecycle", true, "ready"),
    readiness_check(
      "standalone_boundary", "Standalone boundary", true, "runtime handoff",
    ),
  ]
  let report = executable_book_lifecycle_report_from_checks(checks)
  assert_true(json_bool(report, "ready", default=false))
  assert_eq(json_string(report, "status", default=""), "complete")
  assert_eq(
    summary_json_int(report, "completed_step_count", default=0),
    executable_book_lifecycle_steps().length(),
  )
  assert_eq(json_string(report, "first_blocker_id", default="blocked"), "")
  let steps = json_array_items(report, "steps")
  assert_eq(steps.length(), executable_book_lifecycle_steps().length())
  let mut found_package = false
  let mut found_accept = false
  for step in steps {
    assert_true(json_bool(step, "ok", default=false))
    let text = step.stringify()
    assert_false(text.contains("Rabbita"))
    assert_false(text.contains("rabbita"))
    match json_string(step, "id", default="") {
      "package_output" => {
        found_package = true
        assert_eq(json_string(step, "owner", default=""), "moonbook")
        assert_true(
          json_string(step, "evidence", default="").contains(
            "package_lifecycle",
          ),
        )
      }
      "accept_result" => {
        found_accept = true
        assert_eq(json_string(step, "owner", default=""), "bookkeeper")
        assert_true(
          json_string(step, "evidence", default="").contains(
            "live_blockers_clear",
          ),
        )
      }
      _ => ()
    }
  }
  assert_true(found_package)
  assert_true(found_accept)
}

///|
test "mooncode session summary exposes executable book lifecycle report" {
  let summary = session_summary({ "id": "s1", "workspace_id": "book" }, [])
  let lifecycle = summary_json_object_field_or_empty(
    summary, "executable_book_lifecycle",
  )
  assert_eq(
    json_string(lifecycle, "kind", default=""),
    "mooncode-executable-book-lifecycle-report",
  )
  assert_eq(
    json_string(lifecycle, "contract_id", default=""),
    executable_book_lifecycle_contract_id(),
  )
  assert_eq(
    summary_json_int(lifecycle, "step_count", default=0),
    executable_book_lifecycle_steps().length(),
  )
  assert_false(json_bool(lifecycle, "ready", default=true))
}
