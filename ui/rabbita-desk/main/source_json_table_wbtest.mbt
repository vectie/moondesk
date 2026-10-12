///|
test "JSON keeps its source editor and offers an explicit table action" {
  let loading = update_source_pane(
    init_source_pane("book-data", "session"),
    RequestSource("records.json"),
  )
  let preview = @desk.preview(
    @desk.file_entry(workspace_id="book-data", path="records.json"),
    body="[{\"name\":\"東京\"}]",
  )
  let ready = update_source_pane(
    loading,
    PreviewResult(source_pane_identity(loading), Ok(preview)),
  )
  assert_true(source_pane_editable(ready))
  assert_true(source_json_table_supported(ready))
  assert_eq(ready.draft, preview.body)
  let edited = update_source_pane(ready, EditDraft("[{\"name\":\"new\"}]"))
  assert_true(source_pane_dirty(edited))
  assert_eq(edited.baseline, preview.body)
  let jsonl = { ..ready, requested_path: "records.jsonl", }
  assert_true(source_json_table_supported(jsonl))
  for file in ["sales.csv", "sales.tsv", "sales.xlsx", "SALES.JSONL"] {
    assert_true(json_table_selection_supported(file))
  }
  assert_false(
    source_json_table_supported({ ..ready, requested_path: "readme.md", }),
  )
  assert_eq(
    @desk.workspace_json_table_url("book-data", "records.json"),
    "/api/workspaces/book-data/json-table?path=records.json&format=html",
  )
}
