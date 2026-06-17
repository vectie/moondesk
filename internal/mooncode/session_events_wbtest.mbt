///|
test "mooncode appends command event to durable session events" {
  let session = append_command_event(
    { "id": "agent-demo" },
    action="run_tests",
    status="queued",
    detail="Run tests",
    created_at="2026-06-16T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet={ "command_id": "cmd-run-tests", "action": "run_tests" },
    event_id="cmd-run-tests",
  )
  let events = session_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 1)
  assert_eq(
    json_string(session, "updated_at", default=""),
    "2026-06-16T00:00:00Z",
  )
  assert_eq(json_string(events[0], "id", default=""), "cmd-run-tests")
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "kind", default=""), "command.run_tests")
  assert_eq(json_string(events[0], "command", default=""), "run_tests")
}

///|
test "mooncode projected command event preserves packet command id" {
  let session = append_projected_command_event(
    { "id": "agent-demo" },
    action="run_tests",
    status="queued",
    detail="Run tests",
    created_at="2026-06-16T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet={ "command_id": "cmd-run-tests", "action": "run_tests" },
  )
  let events = session_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "id", default=""), "cmd-run-tests")
  assert_eq(json_string(events[0], "lane", default=""), "test")
}

///|
test "mooncode projected command event owns stable fallback ids" {
  let first = append_projected_command_event(
    { "id": "agent-demo" },
    action="accept",
    status="queued",
    detail="Accept tools/demo/main.mbt",
    created_at="2026-06-16T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet=Json::object({}),
  )
  let second = append_projected_command_event(
    { "id": "agent-demo" },
    action="accept",
    status="queued",
    detail="Accept tools/demo/main.mbt",
    created_at="2026-06-16T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet=Json::object({}),
  )
  let first_events = session_json_array_items(first, "mooncode_command_events")
  let second_events = session_json_array_items(
    second, "mooncode_command_events",
  )
  assert_eq(
    json_string(first_events[0], "id", default=""),
    json_string(second_events[0], "id", default=""),
  )
  assert_true(
    json_string(first_events[0], "id", default="").has_prefix("mooncode-event-"),
  )
  assert_eq(json_string(first_events[0], "lane", default=""), "review")
  assert_eq(json_string(first_events[0], "command", default=""), "accept")
}

///|
test "mooncode projected command event owns default path and packet" {
  let session = append_projected_command_event(
    { "id": "agent-demo" },
    action="cancel",
    status="failed",
    detail="MoonClaw daemon is not running",
    created_at="2026-06-17T00:00:00Z",
  )
  let events = session_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "command", default=""), "cancel")
  assert_eq(json_string(events[0], "path", default="fallback"), "")
  assert_true(
    summary_json_object_field(events[0], "command_packet")
    is Some(Json::Object(_)),
  )
}

///|
test "mooncode stamps manifest event and latest manifest field" {
  let existing : Json = {
    "id": "event-existing",
    "kind": "mooncode.event.existing",
  }
  let manifest : Json = {
    "kind": "mooncode-patch-set",
    "manifest_path": "wiki/reviews/mooncode/s1/patch-set.json",
  }
  let event : Json = {
    "id": "event-patch",
    "kind": "mooncode.patch-set.manifest",
  }
  let session = session_with_manifest_event(
    { "id": "s1", "mooncode_command_events": [existing] },
    "mooncode_last_patch_set_manifest",
    manifest,
    event,
  )
  let events = session_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 2)
  assert_eq(json_string(events[0], "id", default=""), "event-existing")
  assert_eq(json_string(events[1], "id", default=""), "event-patch")
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(
        session, "mooncode_last_patch_set_manifest",
      ),
      "manifest_path",
      default="",
    ),
    "wiki/reviews/mooncode/s1/patch-set.json",
  )
}

///|
test "mooncode stamps review receipt event and latest receipt field" {
  let receipt : Json = {
    "kind": "mooncode-review-receipt",
    "receipt_path": "wiki/reviews/mooncode/s1/receipts/cmd-1.json",
  }
  let event : Json = { "id": "event-receipt", "kind": "receipt.accept" }
  let session = session_with_review_receipt_event(
    { "id": "s1" },
    receipt,
    event,
  )
  let events = session_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "id", default=""), "event-receipt")
  let saved = summary_json_object_field_or_empty(
    session, "mooncode_last_review_receipt",
  )
  assert_eq(
    json_string(saved, "receipt_path", default=""),
    "wiki/reviews/mooncode/s1/receipts/cmd-1.json",
  )
}

///|
test "mooncode stamps package manifest and index events together" {
  let existing : Json = { "id": "event-existing" }
  let manifest : Json = {
    "kind": "mooncode-package-manifest",
    "manifest_path": "wiki/reviews/mooncode/s1/packages/cmd-1.json",
  }
  let index_manifest : Json = {
    "kind": "mooncode-package-index",
    "manifest_path": "wiki/reviews/mooncode/s1/package-index.json",
  }
  let session = session_with_package_manifest_events(
    { "id": "s1", "mooncode_command_events": [existing] },
    manifest,
    { "id": "event-package" },
    index_manifest,
    { "id": "event-package-index" },
  )
  let events = session_json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 3)
  assert_eq(json_string(events[0], "id", default=""), "event-existing")
  assert_eq(json_string(events[1], "id", default=""), "event-package")
  assert_eq(json_string(events[2], "id", default=""), "event-package-index")
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(
        session, "mooncode_last_package_manifest",
      ),
      "manifest_path",
      default="",
    ),
    "wiki/reviews/mooncode/s1/packages/cmd-1.json",
  )
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(
        session, "mooncode_last_package_index_manifest",
      ),
      "manifest_path",
      default="",
    ),
    "wiki/reviews/mooncode/s1/package-index.json",
  )
}

///|
test "mooncode shapes transcript messages as reusable lane events" {
  let user_event = transcript_message_event(
    {
      "role": "user",
      "content": "Create a CLI tool",
      "created_at": "2026-06-16T00:00:00Z",
    },
    fallback_id="message-fallback",
  )
  assert_eq(json_string(user_event, "id", default=""), "message-fallback")
  assert_eq(json_string(user_event, "lane", default=""), "transcript")
  assert_eq(json_string(user_event, "kind", default=""), "user")
  assert_eq(json_string(user_event, "title", default=""), "User prompt")
  assert_eq(json_string(user_event, "detail", default=""), "Create a CLI tool")
  let tool_event = transcript_message_event(
    { "role": "tool", "id": "tool-message", "content": "done" },
    fallback_id="unused",
  )
  assert_eq(json_string(tool_event, "id", default=""), "tool-message")
  assert_eq(json_string(tool_event, "lane", default=""), "tool")
  assert_eq(json_string(tool_event, "title", default=""), "Tool result")
}

///|
test "mooncode owns stable transcript message projection ids" {
  let message : Json = {
    "role": "user",
    "content": "Create a CLI tool",
    "created_at": "2026-06-16T00:00:00Z",
  }
  let first = transcript_message_projected_event(message)
  let second = transcript_message_projected_event(message)
  assert_eq(
    json_string(first, "id", default=""),
    json_string(second, "id", default=""),
  )
  assert_true(
    json_string(first, "id", default="").has_prefix("mooncode-event-"),
  )
  assert_eq(json_string(first, "lane", default=""), "transcript")
  assert_eq(json_string(first, "kind", default=""), "user")
}

///|
test "mooncode projects session transcript commands and durable events together" {
  let command = append_projected_command_event(
    {
      "id": "s1",
      "mooncode_events": [
        { "id": "seed", "lane": "runtime", "kind": "seed", "status": "done" },
      ],
      "transcript": [
        { "role": "user", "id": "message-1", "content": "Create a tool" },
      ],
    },
    action="run_tests",
    status="queued",
    detail="Run tests",
    created_at="2026-06-17T00:00:00Z",
  )
  let events = project_session_events_for_session(command, [], [
    { "id": "durable", "lane": "artifact", "kind": "durable" },
  ])
  assert_eq(events.length(), 4)
  assert_eq(json_string(events[0], "id", default=""), "seed")
  assert_eq(json_string(events[1], "id", default=""), "message-1")
  assert_eq(json_string(events[2], "command", default=""), "run_tests")
  assert_eq(json_string(events[3], "id", default=""), "durable")
}

///|
test "mooncode prefers raw MoonClaw events over transcript fallback" {
  let events = project_session_events_for_session(
    {
      "id": "s1",
      "transcript": [
        {
          "role": "user",
          "id": "fallback-message",
          "content": "Fallback should not be used",
        },
      ],
    },
    [
      {
        "id": "raw-user",
        "created": "2026-06-17T00:00:00Z",
        "desc": { "msg": "UserMessage", "content": "Use raw event" },
      },
    ],
    [],
    fallback_created_at="2026-06-17T00:00:01Z",
  )
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "id", default=""), "raw-user")
  assert_eq(json_string(events[0], "kind", default=""), "user")
  assert_eq(json_string(events[0], "detail", default=""), "Use raw event")
}
