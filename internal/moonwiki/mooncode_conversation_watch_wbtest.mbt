///|
test "canonical watch returns a snapshot only when revision advances" {
  let snapshot : Json = {
    "id": "session-a",
    "status": "running",
    "canonical_revision": 4,
    "mooncode_conversation": {
      "kind": @mooncode.conversation_kind(),
      "contract_id": @mooncode.conversation_contract_id(),
      "session_id": "session-a",
      "revision": 4,
      "last_sequence": 7,
      "source_event_count": 3,
      "turns": [],
    },
  }
  let changed = mooncode_conversation_watch_response(
    "session-a", snapshot, 3, 3,
  )
  assert_eq(
    json_string(changed, "contract_id", default=""),
    @mooncode.conversation_watch_contract_id(),
  )
  assert_true(json_bool(changed, "changed", default=false))
  assert_false(json_bool(changed, "heartbeat", default=true))
  assert_eq(json_int(changed, "revision", default=0), 4)
  assert_eq(
    json_string(
      json_object_field_or_empty(changed, "snapshot"),
      "id",
      default="",
    ),
    "session-a",
  )
  assert_true(json_object_field(changed, "events") is None)
  let heartbeat = mooncode_conversation_watch_response(
    "session-a", snapshot, 4, 3,
  )
  assert_false(json_bool(heartbeat, "changed", default=true))
  assert_true(json_bool(heartbeat, "heartbeat", default=false))
  assert_eq(json_int(heartbeat, "revision", default=0), 4)
  assert_eq(json_int(heartbeat, "retry_after_ms", default=0), 100)
  assert_true(json_object_field(heartbeat, "snapshot") is Some(Null))
  assert_eq(mooncode_watch_snapshot_sequence(snapshot), 3)
}

///|
test "canonical watch clamps bounded long poll options" {
  assert_eq(mooncode_watch_wait_ms_value(0), 1000)
  assert_eq(mooncode_watch_wait_ms_value(15000), 15000)
  assert_eq(mooncode_watch_wait_ms_value(60000), 25000)
  assert_eq(mooncode_watch_poll_ms_value(0), 25)
  assert_eq(mooncode_watch_poll_ms_value(100), 100)
  assert_eq(mooncode_watch_poll_ms_value(5000), 1000)
  assert_true(mooncode_watch_status_is_terminal("done"))
  assert_true(mooncode_watch_status_is_terminal("failed"))
  assert_false(mooncode_watch_status_is_terminal("running"))
}
