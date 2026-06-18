///|
test "mooncode production-grade rubric is a standalone contract" {
  let rubric = production_grade_rubric_json()
  assert_eq(
    json_string(rubric, "kind", default=""),
    "mooncode-production-grade-rubric",
  )
  assert_eq(json_string(rubric, "protocol", default=""), protocol_version())
  assert_eq(
    json_string(rubric, "extractable_component", default=""),
    "mooncode",
  )
  assert_eq(summary_json_int(rubric, "check_count", default=0), 17)
  let checks = json_array_items(rubric, "checks")
  assert_eq(checks.length(), 17)
  let ids = checks.map(check => json_string(check, "id", default=""))
  assert_true(ids.contains("moonbook_selected"))
  assert_true(ids.contains("runtime_supervisor_ready"))
  assert_true(ids.contains("typed_command_queue"))
  assert_true(ids.contains("test_build_execution"))
  assert_true(ids.contains("package_lifecycle"))
  assert_true(ids.contains("extractable_boundary"))
  assert_true(
    rubric
    .stringify()
    .contains(
      "\"score_rule\":\"score = passed_check_count * 100 / check_count\"",
    ),
  )
  assert_true(rubric.stringify().contains("\"level\":\"production-grade\""))
  assert_true(rubric.stringify().contains("\"min_score\":95"))
  let mut diff_review = Json::object({})
  for check in checks {
    if json_string(check, "id", default="") == "diff_review" {
      diff_review = check
    }
  }
  assert_eq(
    json_string(diff_review, "next_action", default=""),
    "review_patch_set",
  )
  assert_eq(
    json_string(diff_review, "next_owner", default=""),
    "moondesk-moonbook",
  )
}

///|
test "mooncode session production readiness response is audit scoped" {
  let session : Json = {
    "id": "s1",
    "workspace_id": "research-book",
    "mooncode_events": Json::array([
      event_record(
        id="chat",
        lane="transcript",
        kind="assistant_delta",
        title="Assistant",
        status="completed",
        created_at="1",
        detail="I will edit the tool.",
      ),
    ]),
  }
  let response = session_production_readiness_response(session)
  assert_eq(
    json_string(response, "kind", default=""),
    "mooncode-session-production-readiness",
  )
  assert_eq(json_string(response, "protocol", default=""), protocol_version())
  assert_eq(json_string(response, "session_id", default=""), "s1")
  assert_eq(json_string(response, "workspace_id", default=""), "research-book")
  assert_eq(
    json_string(response, "endpoint", default=""),
    "/api/mooncode/sessions/s1/production-readiness",
  )
  assert_eq(summary_json_int(response, "check_count", default=0), 17)
  assert_true(summary_json_int(response, "score", default=0) > 0)
  assert_eq(json_string(response, "level", default=""), "prototype")
  assert_eq(
    json_string(response, "extractable_component", default=""),
    "mooncode",
  )
  let readiness = summary_json_object_field_or_empty(response, "readiness")
  assert_eq(
    json_string(readiness, "kind", default=""),
    "mooncode-production-readiness",
  )
  assert_eq(
    json_string(response, "first_blocker_id", default=""),
    "moonclaw_attached",
  )
  assert_eq(
    json_string(response, "next_action", default=""),
    "attach_moonclaw_session",
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(response, "rubric"),
      "kind",
      default="",
    ),
    "mooncode-production-grade-rubric",
  )
}
