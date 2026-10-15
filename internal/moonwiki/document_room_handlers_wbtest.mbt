///|
test "workspace room keeps channels messages and live presence in their book" {
  let records : Array[Json] = [
    {
      "id": "a",
      "kind": "message",
      "workspace_id": "book-a",
      "channel": "general",
      "text": "Hello",
    },
    {
      "id": "b",
      "kind": "message",
      "workspace_id": "book-b",
      "channel": "general",
      "text": "Other book",
    },
    {
      "id": "person-a",
      "kind": "presence",
      "workspace_id": "book-a",
      "channel": "general",
      "last_seen": 990,
    },
    {
      "id": "person-old",
      "kind": "presence",
      "workspace_id": "book-a",
      "channel": "general",
      "last_seen": 900,
    },
  ]
  let snapshot = document_room_snapshot(records, "book-a", "general", 1000)
  guard snapshot
    is { "messages": Array(messages), "presence": Array(presence), .. } else {
    fail("expected room snapshot")
  }
  assert_eq(messages.length(), 1)
  assert_eq(presence.length(), 1)
  assert_eq(json_string(messages[0], "text", default=""), "Hello")
}

///|
test "workspace room reactions toggle for one participant without replacing others" {
  let message : Json = { "reactions": [] }
  let agreed = document_room_reaction(message, "alice", "agree")
  let together = document_room_reaction(agreed, "bob", "agree")
  let toggled = document_room_reaction(together, "alice", "agree")
  guard toggled is { "reactions": Array(reactions), .. } else {
    fail("expected reactions")
  }
  assert_eq(reactions.length(), 1)
  assert_eq(json_string(reactions[0], "actor_id", default=""), "bob")
}
