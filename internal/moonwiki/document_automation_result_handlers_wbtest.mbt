///|
test "background result remains bound to its document conversation" {
  let result = document_automation_result(
    {
      "goal_id": "watch-revenue",
      "workspace_id": "book-demo",
      "conversation_id": "conversation-1",
      "document_path": "documents/revenue.xlsx",
    },
    {
      "goal_id": "watch-revenue",
      "decision": "NeedsReview",
      "summary": "Revenue fell below the approved threshold.",
      "run_id": "run-1",
      "tick": 42,
    },
  )
  assert_eq(
    json_string(result, "conversation_id", default=""),
    "conversation-1",
  )
  assert_true(json_bool(result, "warning", default=false))
  assert_eq(json_string(result, "run_id", default=""), "run-1")
}

///|
async test "automation bindings use atomic product storage" {
  let root = "/tmp/moondesk-automation-bindings-" +
    @async.now().to_int().to_string()
  @moonlib/fsx.make_directory(root, recursive=true, exists_ok=true)
  save_document_automation_binding(root, "watch-revenue", {
    "target_book_id": "book-demo",
    "conversation_id": "conversation-1",
    "document_path": "documents/revenue.xlsx",
  })
  let records = read_json_array_file(document_automation_bindings_path(root))
  assert_eq(records.length(), 1)
  assert_eq(
    json_string(records[0], "conversation_id", default=""),
    "conversation-1",
  )
}
