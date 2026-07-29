///|
fn adapter_command_payload(
  action : String,
  client_turn_id : String,
  message : String,
) -> Json {
  {
    "action": action,
    "client_turn_id": client_turn_id,
    "message": message,
    "model": "codex/gpt-5.4",
    "web_search": true,
  }
}

///|
test "typed adapter derives stable acceptance identity from caller submission" {
  let session : Json = {
    "id": "session-one",
    "workspace_id": "book-one",
    "workspace_name": "Book One",
    "workspace_root": "/tmp/book-one",
  }
  guard decode_command_submission(
      adapter_command_payload("prompt", "client-one", "Fix the parser"),
    )
    is Ok(command) else {
    fail("submission must decode")
  }
  let first = accepted_command_packet(session, command, "2026-07-15T00:00:00Z")
  let retry = accepted_command_packet(session, command, "2026-07-16T00:00:00Z")
  assert_eq(first.command_id(), retry.command_id())
  assert_eq(first.client_turn_id(), "client-one")
  let body = native_command_body(session, command, first, Json::empty_object())
  let packet = json_object_field_or_empty(body, "packet")
  assert_eq(json_string(packet, "protocol", default=""), protocol_version())
  assert_eq(json_string(packet, "kind", default=""), "mooncode.command")
  assert_eq(json_string(packet, "status", default=""), "accepted")
  assert_eq(json_string(packet, "command_id", default=""), first.command_id())
  assert_eq(json_string(packet, "client_turn_id", default=""), "client-one")
  assert_eq(json_string(packet, "action", default=""), "prompt")
  assert_eq(json_string(packet, "control", default=""), "prompt")
  assert_eq(json_string(packet, "approval", default=""), "user")
  assert_eq(
    json_string(packet, "created_at", default=""),
    "2026-07-15T00:00:00Z",
  )
  assert_eq(json_string(packet, "session_id", default=""), "session-one")
  assert_eq(json_string(packet, "workspace_id", default=""), "book-one")
  assert_eq(json_string(packet, "workspace_name", default=""), "Book One")
  assert_eq(json_string(packet, "workspace_root", default=""), "/tmp/book-one")
  assert_eq(json_string(packet, "model", default=""), "codex/gpt-5.4")
  assert_true(json_bool(packet, "web_search", default=false))
  assert_eq(json_array_items(packet, "runtime_tool_calls").length(), 0)
  assert_eq(json_string(body, "book_root", default=""), "/tmp/book-one")
  assert_true(json_bool(body, "web_search", default=false))
  let serialized = body.stringify()
  assert_false(serialized.contains("result_contract"))
  assert_false(serialized.contains("runtime-replay"))
  assert_false(serialized.contains("tool_authorization"))
  let nested = json_object_field_or_empty(body, "payload")
  assert_false(nested.stringify().contains("planner_max_steps"))
  let guidance = json_object_field_or_empty(nested, "planner_guidance")
  assert_eq(
    json_string(guidance, "no_match_policy", default=""),
    "Treat an empty optional search as a useful result, not a failed turn.",
  )
  assert_eq(
    json_string(guidance, "finish_policy", default=""),
    "Always finish with a concise user-facing answer when no more tool work is needed.",
  )
  assert_eq(
    json_string(guidance, "tool_failure_policy", default=""),
    "Report real execution failures and continue when a bounded fallback exists.",
  )
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
    "action": "cancel",
    "client_turn_id": "client-cancel",
    "message": "Cancel the visible request",
    "target_command_id": "command-visible-running",
  }
  guard decode_command_submission(payload) is Ok(command) else {
    fail("cancel command must decode")
  }
  let accepted = accepted_command_packet(
    session, command, "2026-07-15T00:00:00Z",
  )
  let body = native_command_body(session, command, accepted, payload)
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
test "typed approval command keeps adapter and runtime packet wire parity" {
  let session : Json = {
    "id": "session-approval",
    "workspace_id": "book-one",
    "workspace_name": "Book One",
    "workspace_root": "/tmp/book-one",
  }
  let payload : Json = {
    "action": "approve_tool",
    "client_turn_id": "approval-client-one",
    "approval_id": "approval-one",
    "target_command_id": "command-one",
    "tool_call_id": "call-one",
  }
  guard decode_command_submission(payload) is Ok(command) else {
    fail("typed approval command must decode")
  }
  guard @mooncode_core.encode_mooncode_command(command) is Ok(encoded) else {
    fail("typed approval command must encode")
  }
  assert_true(
    encoded
    is {
      "action": "approve_tool",
      "client_turn_id": "approval-client-one",
      "approval_id": "approval-one",
      "target_command_id": "command-one",
      "tool_call_id": "call-one",
      ..
    },
  )
  let accepted = accepted_command_packet(
    session, command, "2026-07-29T00:00:00Z",
  )
  let packet = json_object_field_or_empty(
    native_command_body(session, command, accepted, Json::empty_object()),
    "packet",
  )
  assert_eq(json_string(packet, "action", default=""), "approve_tool")
  assert_eq(json_string(packet, "approval_id", default=""), "approval-one")
  assert_eq(json_string(packet, "target_command_id", default=""), "command-one")
  assert_eq(json_string(packet, "tool_call_id", default=""), "call-one")
}

///|
test "typed adapter conflicting idempotency payload derives a distinct identity" {
  let session : Json = { "id": "session-one" }
  guard decode_command_submission(
      adapter_command_payload("prompt", "client-one", "first payload"),
    )
    is Ok(first) else {
    fail("first submission must decode")
  }
  guard decode_command_submission(
      adapter_command_payload("prompt", "client-one", "conflicting payload"),
    )
    is Ok(conflict) else {
    fail(
      "conflicting submission must decode before route evidence rejects reuse",
    )
  }
  assert_false(
    accepted_command_packet(session, first, "one").command_id() ==
    accepted_command_packet(session, conflict, "two").command_id(),
  )
}

///|
test "adapter preserves explicit planner limit and private runtime passthrough" {
  let payload : Json = {
    "action": "prompt",
    "client_turn_id": "client-limit",
    "message": "bounded by caller",
    "planner_max_steps": 21,
  }
  guard decode_command_submission(payload) is Ok(command) else {
    fail("planner command must decode")
  }
  let session : Json = { "id": "session-limit", "workspace_root": "/tmp/book" }
  let accepted = accepted_command_packet(session, command, "now")
  let body = native_command_body(session, command, accepted, {
    "runtime_tool_calls": [{ "tool": "finish" }],
  })
  let nested = json_object_field_or_empty(body, "payload")
  assert_eq(json_int(nested, "planner_max_steps", default=0), 21)
  assert_eq(json_array_items(body, "runtime_tool_calls").length(), 1)
  assert_true(nested.stringify().contains("planner_guidance"))
}

///|
test "adapter exposes only the canonical desktop route surface" {
  let routes = desktop_projection_route_contracts()
  assert_eq(routes.length(), 7)
  let payload = Json::array(routes).stringify()
  assert_true(payload.contains(desktop_session_watch_endpoint()))
  assert_true(payload.contains(desktop_session_lifecycle_endpoint()))
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
  assert_false(serialized.contains("\"events_jsonl\""))
  assert_false(serialized.contains("runtime-receipts.jsonl"))
  assert_false(serialized.contains("runtime-replay.jsonl"))
}

///|
test "listing adapter preserves MoonClaw order and canonical identity" {
  guard runtime_session_listing_rows({
      "sessions": [
        {
          "id": "newer",
          "book_root": "/tmp/newer",
          "source": "moonclaw",
          "updated_at": 1784093903397,
          "event_count": 9,
          "archived": true,
        },
        {
          "id": "older",
          "workspace_root": "/tmp/older",
          "updated_at": "2026-07-15T10:00:00Z",
        },
      ],
    })
    is Ok(rows) else {
    fail("expected supported listing")
  }
  assert_eq(rows.length(), 2)
  assert_eq(json_string(rows[0], "id", default=""), "newer")
  assert_eq(json_string(rows[1], "id", default=""), "older")
  assert_eq(
    json_string(rows[0], "mooncode_runtime_session_id", default=""),
    "newer",
  )
  assert_eq(json_string(rows[0], "title", default=""), "newer")
  assert_eq(json_string(rows[0], "updated_at", default=""), "1784093903397")
  assert_eq(
    json_string(rows[1], "updated_at", default=""),
    "2026-07-15T10:00:00Z",
  )
  assert_eq(json_int(rows[0], "queued_count", default=-1), 0)
  let summary = json_object_field_or_empty(rows[0], "mooncode_summary")
  assert_eq(json_int(summary, "event_count", default=-1), 9)
  assert_eq(json_int(summary, "verified_test_count", default=-1), 0)
  assert_eq(json_int(summary, "pending_diff_count", default=-1), 0)
  assert_true(json_bool(rows[0], "archived", default=false))
}

///|
test "listing adapter reports malformed IDs and unsupported versions" {
  assert_true(
    runtime_session_listing_rows({ "sessions": [{ "title": "invalid" }] })
    is Err(_),
  )
  assert_true(runtime_session_listing_rows(true) is Err(_))
  assert_true(runtime_session_listing_rows({}) is Err(_))
  assert_true(
    runtime_session_listing_rows({ "sessions": "not-an-array" }) is Err(_),
  )
  assert_true(
    runtime_session_listing_rows({ "protocol": 1, "sessions": [] }) is Err(_),
  )
  assert_true(
    runtime_session_listing_rows({
      "protocol": "mooncode.v9",
      "sessions": [
        { "id": "future", "workspace_root": "/tmp/future", "status": "durable" },
      ],
    })
    is Err(message) &&
    message.contains("version 9"),
  )
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
  assert_false(json_bool(session, "archived", default=true))
}

///|
test "selected session adapter validates known fields and preserves extensions" {
  let raw_id = "session /resume:1\\branch"
  guard selected_session_response({
      "id": raw_id,
      "status": "running",
      "mooncode_summary": { "event_count": 9 },
    })
    is Ok(session) else {
    fail("expected selected session response")
  }
  assert_eq(json_string(session, "id", default=""), raw_id)
  assert_true(session.stringify().contains("mooncode_summary"))
  assert_true(
    selected_session_response({ "id": raw_id, "status": 1 }) is Err(_),
  )
  assert_true(
    selected_session_response({
      "protocol": "mooncode.v8",
      "id": raw_id,
      "status": "idle",
    })
    is Err(message) &&
    message.contains("version 8"),
  )
}
