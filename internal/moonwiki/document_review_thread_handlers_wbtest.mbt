///|
test "document review counts open unread and assigned work" {
  let records : Array[Json] = [
    {
      "id": "thread-1",
      "kind": "thread",
      "status": "open",
      "pinned": true,
      "assigned_to": "reviewer-a",
      "author": "Alex",
      "author_id": "viewer-other",
      "updated_at": "2026-09-04T12:00:00Z",
    },
    {
      "id": "reply-1",
      "kind": "reply",
      "status": "open",
      "assigned_to": "",
      "author": "You",
      "author_id": "viewer-self",
      "updated_at": "2026-09-04T13:00:00Z",
    },
    {
      "id": "thread-2",
      "kind": "thread",
      "status": "resolved",
      "assigned_to": "reviewer-b",
      "author": "Alex",
      "author_id": "viewer-other",
      "updated_at": "2026-09-03T12:00:00Z",
    },
  ]
  let counts = document_review_counts(
    records, "viewer-self", "2026-09-04T11:00:00Z",
  )
  assert_eq(json_int(counts, "open_count", default=-1), 1)
  assert_eq(json_int(counts, "unread_count", default=-1), 1)
  assert_eq(json_int(counts, "required_action_count", default=-1), 1)
  assert_eq(json_int(counts, "pinned_count", default=-1), 1)
  assert_eq(document_review_participants(records), [
    "Alex", "reviewer-a", "You", "reviewer-b",
  ])
}

///|
test "document review anchors become stale only after a baseline change" {
  let record : Json = { "id": "thread-1", "document_baseline": "sha256:old" }
  let current = document_review_record_with_anchor_state(record, "sha256:old")
  let stale = document_review_record_with_anchor_state(record, "sha256:new")
  assert_eq(json_string(current, "anchor_status", default=""), "current")
  assert_eq(json_string(stale, "anchor_status", default=""), "stale")
}

///|
test "review room decisions pin unpin and resolve immutably" {
  let record : Json = {
    "id": "thread-1",
    "kind": "thread",
    "status": "open",
    "pinned": false,
    "revision": 3,
  }
  let pinned = document_review_thread_decision(
    record, "pin", "2026-09-04T13:00:00Z", 3,
  )
  assert_true(json_bool(pinned, "pinned", default=false))
  assert_false(json_bool(record, "pinned", default=false))
  assert_eq(json_int(pinned, "revision", default=0), 4)
  let unpinned = document_review_thread_decision(
    pinned, "unpin", "2026-09-04T13:05:00Z", 4,
  )
  assert_false(json_bool(unpinned, "pinned", default=true))
  let resolved = document_review_thread_decision(
    unpinned, "resolve", "2026-09-04T13:10:00Z", 5,
  )
  assert_eq(json_string(resolved, "status", default=""), "resolved")
}
