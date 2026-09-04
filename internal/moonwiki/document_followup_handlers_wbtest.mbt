///|
test "follow-up queue validates bounded independent turns" {
  let payload : Json = {
    "items": [
      { "id": "followup-1", "text": "First question", "state": "draft" },
      { "id": "followup-2", "text": "Second question", "state": "sending" },
    ],
  }
  let items = document_followup_items(payload).unwrap()
  assert_eq(items.length(), 2)
  assert_eq(json_int(items[1], "position", default=-1), 1)
  assert_true(
    document_followup_items({
      "items": [
        { "id": "same", "text": "one" },
        { "id": "same", "text": "two" },
      ],
    })
    is None,
  )
  assert_true(
    document_followup_items({ "items": [{ "id": "followup-1", "text": "" }] })
    is None,
  )
}

///|
test "follow-up replacement enforces optimistic revision" {
  let current = empty_document_followup_queue("book", "conversation-1")
  let first = document_followup_replacement(
    current,
    {
      "expected_revision": 0,
      "task_id": "task-1",
      "items": [{ "id": "followup-1", "text": "Check the totals" }],
    },
    "2026-09-04T00:00:00Z",
  ).unwrap()
  assert_eq(json_int(first, "revision", default=-1), 1)
  assert_eq(json_array_items(first, "items").length(), 1)
  assert_true(
    document_followup_replacement(
      first,
      { "expected_revision": 0, "task_id": "task-1", "items": [] },
      "2026-09-04T00:01:00Z",
    )
    is Err("revision_conflict"),
  )
}

///|
async test "follow-up queues persist atomically in product storage" {
  let root = "/tmp/moondesk-document-followups-" +
    @async.now().to_int().to_string()
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  write_document_followup_queues(root, [
    {
      "contract": DocumentFollowupContract,
      "id": "book::conversation-1",
      "workspace_id": "book",
      "conversation_id": "conversation-1",
      "revision": 1,
      "items": [],
    },
  ])
  let path = document_followups_path(root)
  assert_true(@fsx.exists(path))
  assert_true(@fsx.read_file(path).contains("book::conversation-1"))
}
