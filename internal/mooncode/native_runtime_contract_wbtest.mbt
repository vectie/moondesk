///|
test "mooncode native runtime contract accepts command scoped chat and diagnostic watcher events" {
  let native_report = runtime_event_ingest_report(
    {
      "events": [
        {
          "event": "reasoning_delta",
          "id": "native-think",
          "command_id": "cmd-live",
          "content": "Checking the project shape.",
          "created_at": "2026-07-04T00:00:00Z",
        },
        {
          "event": "assistant_message",
          "id": "native-answer",
          "command_id": "cmd-live",
          "content": "The change is ready.",
          "created_at": "2026-07-04T00:00:01Z",
        },
        {
          "id": "watcher-update",
          "lane": "test",
          "kind": "runtime_update",
          "title": "MoonCode moon_check update",
          "status": "running",
          "detail": "watching",
          "created_at": "2026-07-04T00:00:02Z",
          "source": "moonclaw-native-moon-check-watcher",
        },
      ],
    },
    session_id="session-live",
    ingested_at="2026-07-04T00:00:03Z",
  )
  let contract = native_runtime_event_contract_report(
    native_report,
    session_id="session-live",
    observed_at="2026-07-04T00:00:03Z",
  )
  assert_eq(
    json_string(contract, "kind", default=""),
    "mooncode-native-runtime-contract-report",
  )
  assert_eq(json_string(contract, "status", default=""), "projection-safe")
  assert_true(json_bool(contract, "projection_safe", default=false))
  assert_eq(runtime_json_int(contract, "accepted_event_count", default=0), 3)
  assert_eq(
    runtime_json_int(contract, "command_scoped_event_count", default=0),
    2,
  )
  assert_eq(runtime_json_int(contract, "diagnostic_event_count", default=0), 1)
  assert_eq(
    runtime_json_int(contract, "unscoped_projection_event_count", default=-1),
    0,
  )
  assert_eq(json_array_items(contract, "problems").length(), 0)
}

///|
test "mooncode native runtime contract rejects unscoped chat eligible events" {
  let native_report = runtime_event_ingest_report(
    {
      "events": [
        {
          "event": "assistant_message",
          "id": "unscoped-answer",
          "content": "This answer has no owner.",
          "created_at": "2026-07-04T00:00:01Z",
        },
      ],
    },
    session_id="session-live",
    ingested_at="2026-07-04T00:00:03Z",
  )
  let contract = native_runtime_event_contract_report(
    native_report,
    session_id="session-live",
    observed_at="2026-07-04T00:00:03Z",
  )
  assert_eq(json_string(contract, "status", default=""), "unsafe")
  assert_false(json_bool(contract, "projection_safe", default=true))
  assert_eq(
    runtime_json_int(contract, "unscoped_projection_event_count", default=0),
    1,
  )
  let problems = json_array_items(contract, "problems")
  assert_eq(problems.length(), 1)
  assert_eq(
    json_string(problems[0], "reason", default=""),
    "user-facing-native-event-without-command-scope",
  )
  assert_eq(json_string(problems[0], "lane", default=""), "transcript")
  assert_eq(json_string(problems[0], "kind", default=""), "assistant")
}

///|
test "mooncode runtime event sink response includes native contract summary" {
  let native_report = runtime_event_ingest_report(
    {
      "events": [
        {
          "event": "assistant_message",
          "id": "native-answer",
          "command_id": "cmd-live",
          "content": "done",
          "created_at": "2026-07-04T00:00:01Z",
        },
      ],
    },
    session_id="session-live",
    ingested_at="2026-07-04T00:00:03Z",
  )
  let events = runtime_json_array_items(native_report, "events")
  let response = runtime_event_sink_result_response_with_native(
    "session-live",
    events,
    {
      "id": "session-live",
      "workspace_id": "book-live",
      "workspace_name": "Book Live",
    },
    event_log_path="/tmp/session-live/events.jsonl",
    local_event_count=1,
    native_state={
      "native_runtime_ready": true,
      "endpoint": "/v1/code/sessions/session-live/runtime-events",
      "error": "",
      "events": [],
    },
    native_report~,
  )
  assert_eq(
    json_string(response, "native_runtime_contract_status", default=""),
    "projection-safe",
  )
  assert_true(
    json_bool(
      response,
      "native_runtime_contract_projection_safe",
      default=false,
    ),
  )
  assert_eq(
    runtime_json_int(
      response,
      "native_runtime_contract_unscoped_projection_event_count",
      default=-1,
    ),
    0,
  )
  let contract = runtime_json_object_field_or_empty(
    response, "native_runtime_contract",
  )
  assert_eq(
    json_string(contract, "kind", default=""),
    "mooncode-native-runtime-contract-report",
  )
}
