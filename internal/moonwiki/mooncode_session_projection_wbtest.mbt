///|
test "mooncode projects file write and test lanes" {
  let raw_events : Array[Json] = [
    {
      "id": "write",
      "created_at": "1",
      "lane": "diff",
      "kind": "write",
      "title": "File changed: tools/demo/main.mbt",
      "status": "done",
      "path": "tools/demo/main.mbt",
      "diff": "+fn main { println(\"ok\") }",
    },
    {
      "id": "test",
      "created_at": "2",
      "lane": "test",
      "kind": "shell",
      "title": "Test/build command: moon test",
      "status": "done",
      "command": "moon test",
      "exit_code": 0,
      "detail": "Total tests: 1, passed: 1",
    },
  ]
  let events = project_mooncode_events(Json::object({}), raw_events, [])
  assert_eq(json_string(events[0], "lane", default=""), "diff")
  assert_eq(json_string(events[0], "path", default=""), "tools/demo/main.mbt")
  assert_eq(json_string(events[1], "lane", default=""), "test")
  assert_eq(json_string(events[1], "command", default=""), "moon test")
  let summary = @mooncode.session_summary({ "id": "s1" }, events)
  assert_eq(json_int(summary, "diff_count", default=0), 1)
  assert_eq(json_int(summary, "test_count", default=0), 1)
  assert_eq(json_int(summary, "verified_test_count", default=0), 1)
  assert_eq(json_int(summary, "failed_test_count", default=0), 0)
}

///|
test "mooncode marks portable app tool outputs as artifacts" {
  let event : Json = {
    "id": "artifact",
    "created_at": "1",
    "lane": "artifact",
    "kind": "package_app_tool",
    "title": "Artifact packaged: portable/app-tool/demo.zip",
    "status": "done",
    "path": "portable/app-tool/demo.zip",
    "detail": "packaged portable/app-tool/demo.zip",
  }
  assert_eq(json_string(event, "lane", default=""), "artifact")
  assert_true(
    json_bool(
      @mooncode.session_summary(Json::object({}), [event]),
      "has_packaging_candidate",
      default=false,
    ),
  )
}

///|
test "mooncode command events project into review lanes" {
  let session = @mooncode.append_projected_command_event(
    Json::object({}),
    action="run_tests",
    status="queued",
    detail=@mooncode.command_message("run_tests", Json::object({})),
    created_at="1",
  )
  let session = @mooncode.append_projected_command_event(
    session,
    action="package",
    status="queued",
    detail=@mooncode.command_message("package", Json::object({})),
    created_at="2",
  )
  let session = @mooncode.append_projected_command_event(
    session,
    action="accept",
    status="queued",
    detail=@mooncode.command_message("accept", Json::object({})),
    created_at="3",
  )
  let session = @mooncode.append_projected_command_event(
    session,
    action="reject",
    status="queued",
    detail=@mooncode.command_message("reject", Json::object({})),
    created_at="4",
  )
  let events = project_mooncode_events(session, [], [])
  assert_eq(events.length(), 4)
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[1], "lane", default=""), "artifact")
  assert_eq(json_string(events[2], "lane", default=""), "review")
  assert_eq(json_string(events[3], "lane", default=""), "review")
  let summary = @mooncode.session_summary(session, events)
  assert_true(json_bool(summary, "has_packaging_candidate", default=false))
  assert_eq(json_int(summary, "verified_test_count", default=0), 0)
  assert_eq(json_int(summary, "review_count", default=0), 2)
  assert_eq(json_int(summary, "accepted_review_count", default=0), 1)
  assert_eq(json_int(summary, "rejected_review_count", default=0), 1)
  assert_eq(json_string(summary, "review_state", default=""), "rejected")
}
