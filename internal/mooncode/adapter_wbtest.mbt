///|
test "adapter exposes only the canonical desktop route surface" {
  let routes = desktop_projection_route_contracts()
  assert_eq(routes.length(), 6)
  let payload = Json::array(routes).stringify()
  assert_true(payload.contains(desktop_session_watch_endpoint()))
  assert_false(payload.contains("runtime-service"))
  assert_false(payload.contains("runtime-replay"))
  assert_false(payload.contains("session-store"))
}

///|
test "capability declares one MoonClaw-owned journal" {
  let capability = capabilities_json()
  let ownership = json_object_field_or_empty(capability, "ownership")
  assert_eq(json_string(ownership, "sessions", default=""), "moonclaw")
  let serialized = capability.stringify()
  assert_true(serialized.contains("journal.jsonl"))
  assert_true(serialized.contains(@mooncode_core.journal_contract_id()))
  assert_false(serialized.contains("commands.jsonl"))
  assert_false(serialized.contains("events.jsonl"))
  assert_false(serialized.contains("runtime-receipts.jsonl"))
  assert_false(serialized.contains("runtime-replay"))
}

///|
test "native capability readiness is derived from the shared core contract" {
  let ready : Json = {
    "component": "mooncode",
    "protocol": protocol_version(),
    "capability_contract_id": @mooncode_core.native_capability_contract_id(),
    "capability_surface": @mooncode_core.native_capability_surface_json(),
    "native_runtime_ready": true,
    "endpoints": @mooncode_core.native_capability_required_endpoints(),
    "tools": @mooncode_core.native_capability_required_tools(),
  }
  assert_true(moonclaw_native_capabilities_ready(ready))
  assert_false(
    moonclaw_native_capabilities_ready(
      session_with_field(ready, "native_runtime_ready", false.to_json()),
    ),
  )
}

///|
test "turn adapter keeps stable ownership and omits retired replay contracts" {
  let session : Json = {
    "id": "session-one",
    "workspace_id": "book-one",
    "workspace_name": "Book One",
    "workspace_root": "/tmp/book-one",
  }
  let payload : Json = {
    "client_turn_id": "client-one",
    "model": "codex/gpt-5.4",
    "web_search": true,
  }
  let first = projected_command_packet(
    session, payload, "prompt", "Fix the parser", "2026-07-15T00:00:00Z", "src/parser.mbt",
  )
  let second = projected_command_packet(
    session, payload, "prompt", "Fix the parser", "2026-07-15T00:00:00Z", "src/parser.mbt",
  )
  assert_eq(
    json_string(first, "command_id", default=""),
    json_string(second, "command_id", default=""),
  )
  assert_eq(json_string(first, "client_turn_id", default=""), "client-one")
  let body = native_command_body(session, payload, "Fix the parser", first)
  assert_eq(json_string(body, "book_root", default=""), "/tmp/book-one")
  assert_true(json_bool(body, "web_search", default=false))
  let serialized = body.stringify()
  assert_false(serialized.contains("result_contract"))
  assert_false(serialized.contains("runtime-replay"))
  assert_false(serialized.contains("tool_authorization"))
}

///|
test "cancel adapter preserves the visible turn target" {
  let session : Json = {
    "id": "session-cancel",
    "workspace_id": "book-one",
    "workspace_name": "Book One",
    "workspace_root": "/tmp/book-one",
  }
  let payload : Json = {
    "client_turn_id": "client-cancel",
    "target_command_id": "command-visible-running",
  }
  let packet = projected_command_packet(
    session, payload, "cancel", "Cancel the visible request", "2026-07-15T00:00:00Z",
    "",
  )
  let body = native_command_body(
    session, payload, "Cancel the visible request", packet,
  )
  assert_eq(json_string(body, "command", default=""), "cancel")
  assert_eq(
    json_string(
      json_object_field_or_empty(body, "payload"),
      "target_command_id",
      default="",
    ),
    "command-visible-running",
  )
}

///|
test "listing adapter preserves MoonClaw order and canonical identity" {
  let rows = runtime_session_listing_rows({
    "sessions": [
      {
        "id": "newer",
        "book_root": "/tmp/newer",
        "source": "moonclaw",
        "event_count": 9,
      },
      { "id": "older", "workspace_root": "/tmp/older" },
      { "title": "invalid" },
    ],
  })
  assert_eq(rows.length(), 2)
  assert_eq(json_string(rows[0], "id", default=""), "newer")
  assert_eq(json_string(rows[1], "id", default=""), "older")
  assert_eq(
    json_string(rows[0], "mooncode_runtime_session_id", default=""),
    "newer",
  )
  assert_eq(json_string(rows[0], "title", default=""), "newer")
  assert_eq(json_int(rows[0], "queued_count", default=-1), 0)
  let summary = json_object_field_or_empty(rows[0], "mooncode_summary")
  assert_eq(json_int(summary, "event_count", default=-1), 9)
  assert_eq(json_int(summary, "verified_test_count", default=-1), 0)
  assert_eq(json_int(summary, "pending_diff_count", default=-1), 0)
}

///|
test "session defaults never expose a second transcript" {
  let session = session_response_defaults({
    "id": "session-one",
    "workspace_root": "/tmp/book-one",
    "transcript": [{ "role": "assistant", "content": "stale" }],
  })
  assert_true(@mooncore.json_object_field(session, "transcript") is None)
  assert_eq(json_string(session, "cwd", default=""), "/tmp/book-one")
}
