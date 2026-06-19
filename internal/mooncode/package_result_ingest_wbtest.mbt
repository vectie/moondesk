///|
test "mooncode package result ingest accepts direct package proof" {
  let report = package_result_ingest_report(
    {
      "protocol": protocol_version(),
      "session_id": "session-a",
      "command_id": "cmd-1",
      "event": event_package_verified(),
      "path": "site/generated/app.js",
      "detail": "verified executable tool",
    },
    session_id="session-a",
    ingested_at="2026-06-16T10:00:00Z",
  )
  assert_eq(json_string(report, "status", default=""), "accepted")
  let events = json_array_items(report, "events")
  assert_eq(events.length(), 1)
  assert_eq(
    json_string(events[0], "kind", default=""),
    "runtime.package_verified",
  )
  assert_eq(json_string(events[0], "path", default=""), "site/generated/app.js")
}

///|
test "mooncode package result ingest response owns native forwarding fields" {
  let event : Json = {
    "id": "event-1",
    "kind": "runtime.package_verified",
    "command_packet": { "command_id": "cmd-1" },
  }
  let response = package_result_ingest_result_response(
    "session-a",
    [event],
    [event],
    { "kind": "mooncode-package-result-ingest-report", "accepted_count": 1 },
    { "id": "session-a" },
    { "id": "session-a", "workspace_id": "book-a" },
    event_log_path="/tmp/session/events.jsonl",
    native_state={
      "native_package_result_ready": true,
      "endpoint": "/v1/code/sessions/session-a/package-result?book_root=%2Ftmp%2Fbook",
      "error": "",
      "submitted_count": 2,
      "accepted_count": 1,
    },
  )
  assert_eq(
    json_string(response, "kind", default=""),
    "mooncode-runtime-event-ingest-result",
  )
  assert_eq(json_string(response, "session_id", default=""), "session-a")
  assert_true(json_bool(response, "native_package_result_ready", default=false))
  assert_eq(
    json_string(response, "native_package_result_endpoint", default=""),
    "/v1/code/sessions/session-a/package-result?book_root=%2Ftmp%2Fbook",
  )
  assert_eq(
    runtime_json_int(
      response,
      "native_package_result_submitted_count",
      default=0,
    ),
    2,
  )
  assert_eq(
    runtime_json_int(
      response,
      "native_package_result_accepted_count",
      default=0,
    ),
    1,
  )
  assert_true(
    runtime_json_object_field(response, "native_package_result")
    is Some(Object(_)),
  )
}

///|
test "mooncode native package result unavailable report is MoonCode owned" {
  let report = native_package_result_unavailable_report(
    "/v1/code/sessions/session-a/package-result?book_root=%2Ftmp%2Fbook", 3, "MoonClaw daemon is not running",
  )
  assert_false(json_bool(report, "native_package_result_ready", default=true))
  assert_eq(
    json_string(report, "endpoint", default=""),
    "/v1/code/sessions/session-a/package-result?book_root=%2Ftmp%2Fbook",
  )
  assert_eq(
    json_string(report, "error", default=""),
    "MoonClaw daemon is not running",
  )
  assert_eq(runtime_json_int(report, "submitted_count", default=0), 3)
  assert_eq(runtime_json_int(report, "accepted_count", default=-1), 0)
  assert_eq(json_array_items(report, "responses").length(), 0)
  assert_eq(json_array_items(report, "errors").length(), 0)
}

///|
test "mooncode native package result forwarding report records partial failures" {
  let responses : Array[Json] = [{ "ok": true, "command_id": "cmd-1" }]
  let errors : Array[Json] = [
    { "error": "bad request", "request": { "command_id": "cmd-2" } },
    { "error": "timeout", "request": { "command_id": "cmd-3" } },
  ]
  let report = native_package_result_forwarding_report(
    "/v1/code/sessions/session-a/package-result?book_root=%2Ftmp%2Fbook", 3, responses,
    errors,
  )
  assert_false(json_bool(report, "native_package_result_ready", default=true))
  assert_eq(
    json_string(report, "error", default=""),
    "MoonClaw rejected 2 package result(s)",
  )
  assert_eq(runtime_json_int(report, "submitted_count", default=0), 3)
  assert_eq(runtime_json_int(report, "accepted_count", default=0), 1)
  assert_eq(json_array_items(report, "responses").length(), 1)
  assert_eq(json_array_items(report, "errors").length(), 2)
}

///|
test "mooncode package result ingest accepts native sidecar record shape" {
  let report = package_result_ingest_report(
    {
      "kind": "mooncode-package-result",
      "protocol": protocol_version(),
      "session_id": "session-b",
      "command_id": "cmd-2",
      "package_result": {
        "event": event_package_built(),
        "path": "portable/app-tool/mooncode/session-b/app",
        "detail": "built bundle",
      },
    },
    session_id="session-b",
    ingested_at="2026-06-16T10:00:00Z",
  )
  assert_eq(json_string(report, "status", default=""), "accepted")
  let events = json_array_items(report, "events")
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "kind", default=""), "runtime.package_built")
  let packet = runtime_json_object_field_or_empty(events[0], "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-2")
}

///|
test "mooncode package result ingest rejects invalid package proof" {
  let report = package_result_ingest_report(
    {
      "protocol": protocol_version(),
      "session_id": "session-a",
      "event": event_package_verified(),
    },
    session_id="session-a",
    ingested_at="2026-06-16T10:00:00Z",
  )
  assert_eq(json_string(report, "status", default=""), "empty")
  assert_eq(json_array_items(report, "events").length(), 0)
  let rejected = json_array_items(report, "rejected")
  assert_eq(rejected.length(), 1)
  assert_true(rejected[0].stringify().contains("\"command_id\""))
  assert_true(rejected[0].stringify().contains("\"path\""))
}
