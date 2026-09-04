///|
test "document review counts open unread and assigned work" {
  let records : Array[Json] = [
    {
      "id": "thread-1",
      "kind": "thread",
      "status": "open",
      "assigned_to": "reviewer-a",
      "author_id": "viewer-other",
      "updated_at": "2026-09-04T12:00:00Z",
    },
    {
      "id": "reply-1",
      "kind": "reply",
      "status": "open",
      "assigned_to": "",
      "author_id": "viewer-self",
      "updated_at": "2026-09-04T13:00:00Z",
    },
    {
      "id": "thread-2",
      "kind": "thread",
      "status": "resolved",
      "assigned_to": "reviewer-b",
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
}

///|
test "document review anchors become stale only after a baseline change" {
  let record : Json = { "id": "thread-1", "document_baseline": "sha256:old" }
  let current = document_review_record_with_anchor_state(record, "sha256:old")
  let stale = document_review_record_with_anchor_state(record, "sha256:new")
  assert_eq(json_string(current, "anchor_status", default=""), "current")
  assert_eq(json_string(stale, "anchor_status", default=""), "stale")
}
