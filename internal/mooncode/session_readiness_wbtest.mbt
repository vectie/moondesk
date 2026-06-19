///|
test "mooncode readiness contract is standalone telemetry" {
  let contract = readiness_contract_json()
  assert_eq(
    json_string(contract, "kind", default=""),
    "mooncode-readiness-contract",
  )
  assert_eq(json_string(contract, "protocol", default=""), protocol_version())
  assert_eq(
    json_string(contract, "standalone_component", default=""),
    "mooncode",
  )
  assert_eq(summary_json_int(contract, "check_count", default=0), 18)
  let checks = json_array_items(contract, "checks")
  assert_eq(checks.length(), 18)
  let ids = checks.map(check => json_string(check, "id", default=""))
  assert_true(ids.contains("moonbook_selected"))
  assert_true(ids.contains("runtime_supervisor_ready"))
  assert_true(ids.contains("native_eval_ready"))
  assert_true(ids.contains("typed_command_queue"))
  assert_true(ids.contains("test_build_execution"))
  assert_true(ids.contains("package_lifecycle"))
  assert_true(ids.contains("standalone_boundary"))
  assert_false(contract.stringify().contains("\"level\""))
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
test "mooncode session readiness response is audit scoped" {
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
  let response = session_readiness_response(session)
  assert_eq(
    json_string(response, "kind", default=""),
    "mooncode-session-readiness",
  )
  assert_eq(json_string(response, "protocol", default=""), protocol_version())
  assert_eq(json_string(response, "session_id", default=""), "s1")
  assert_eq(json_string(response, "workspace_id", default=""), "research-book")
  assert_eq(
    json_string(response, "endpoint", default=""),
    "/api/mooncode/sessions/s1/readiness",
  )
  assert_eq(summary_json_int(response, "check_count", default=0), 18)
  assert_false(response.stringify().contains("\"level\""))
  assert_eq(
    json_string(response, "standalone_component", default=""),
    "mooncode",
  )
  let readiness = summary_json_object_field_or_empty(response, "readiness")
  assert_eq(json_string(readiness, "kind", default=""), "mooncode-readiness")
  assert_eq(
    json_string(response, "first_blocker_id", default=""),
    "durable_session",
  )
  assert_eq(
    json_string(response, "next_action", default=""),
    "persist_session_snapshot",
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(response, "contract"),
      "kind",
      default="",
    ),
    "mooncode-readiness-contract",
  )
}
