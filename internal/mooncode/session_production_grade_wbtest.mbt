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
  assert_eq(summary_json_int(rubric, "check_count", default=0), 16)
  let checks = json_array_items(rubric, "checks")
  assert_eq(checks.length(), 16)
  let ids = checks.map(check => json_string(check, "id", default=""))
  assert_true(ids.contains("moonbook_selected"))
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
