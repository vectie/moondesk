///|
test "mooncode projects file write and test lanes" {
  let raw_events : Array[Json] = [
    {
      "id": "write",
      "created": "1",
      "desc": {
        "msg": "PostToolCall",
        "tool_call": {
          "function": {
            "name": "meta_write_to_file",
            "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
          },
        },
        "result": {
          "path": "tools/demo/main.mbt",
          "diff": "+fn main { println(\"ok\") }",
        },
      },
    },
    {
      "id": "test",
      "created": "2",
      "desc": {
        "msg": "PostToolCall",
        "tool_call": {
          "function": {
            "name": "execute_command",
            "arguments": "{\"command\":\"moon test\"}",
          },
        },
        "result": [
          "Completed",
          {
            "command": "moon test",
            "status": 0,
            "stdout": "Total tests: 1, passed: 1",
            "stderr": "",
          },
        ],
      },
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
  guard @mooncode.moonclaw_tool_event_record(
      {
        "id": "artifact",
        "created": "1",
        "desc": {
          "msg": "PostToolCall",
          "name": "package_app_tool",
          "result": { "path": "portable/app-tool/demo.zip" },
          "text": "packaged portable/app-tool/demo.zip",
        },
      },
      fallback_id="artifact",
    )
    is Some(event) else {
    fail("package app tool event was not projected")
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
  let session = append_mooncode_command_event(
    Json::object({}),
    action="run_tests",
    status="queued",
    detail=@mooncode.command_message("run_tests", Json::object({})),
    created_at="1",
  )
  let session = append_mooncode_command_event(
    session,
    action="package",
    status="queued",
    detail=@mooncode.command_message("package", Json::object({})),
    created_at="2",
  )
  let session = append_mooncode_command_event(
    session,
    action="accept",
    status="queued",
    detail=@mooncode.command_message("accept", Json::object({})),
    created_at="3",
  )
  let session = append_mooncode_command_event(
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
