///|
async test "MoonCode comparisons persist two evidence-bound branches and a selection candidate" {
  let root : String = "/tmp/moondesk-mooncode-comparison-\{@async.now()}"
  let book = @pathx.join(root, "books/comparison-book")
  @fsx.make_directory(book, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(book, "book.json"),
    "{\"id\":\"comparison-book\",\"name\":\"Comparison Book\"}\n",
  )
  @fsx.write_to_file(@pathx.join(book, "main.mbt"), "fn main { }\n")
  let digest = "sha256:" + "a".repeat(64)
  let first = persist_mooncode_comparison(root, {
    "contract": MoonCodeComparisonContract,
    "id": "comparison-one",
    "workspace_id": "book-comparison-book",
    "context_path": "main.mbt",
    "baseline_request_digest": digest,
    "goal": "Compare two safe implementations",
    "sessions": [
      { "label": "A", "id": "session-a", "status": "running" },
      { "label": "B", "id": "session-b", "status": "queued" },
    ],
    "selected_branch": "",
  })
  let record = match first {
    Ok(value) => value
    Err(message) => fail("comparison should persist: " + message)
  }
  assert_eq(json_int(record, "revision", default=0), 1)
  assert_true(
    match record {
      Object(fields) => fields.get("evaluation_candidate") is Some(Null)
      _ => false
    },
  )
  let selected_payload = @mooncore.session_with_field(
    @mooncore.session_with_field(record, "selected_branch", "B".to_json()),
    "selected_at",
    "2026-09-04T12:00:00Z".to_json(),
  )
  let selected = persist_mooncode_comparison(root, selected_payload)
  let updated = match selected {
    Ok(value) => value
    Err(message) => fail("selection should persist: " + message)
  }
  assert_eq(json_int(updated, "revision", default=0), 2)
  assert_eq(
    json_string(
      json_object_field_or_empty(updated, "evaluation_candidate"),
      "selected_branch",
      default="",
    ),
    "B",
  )
  let stored = read_json_array_file(mooncode_comparisons_path(root))
  assert_eq(stored.length(), 1)
}

///|
async test "MoonCode comparison rejects invalid branch and baseline contracts" {
  let root : String = "/tmp/moondesk-mooncode-comparison-invalid-\{@async.now()}"
  let book = @pathx.join(root, "books/comparison-book")
  @fsx.make_directory(book, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    @pathx.join(book, "book.json"),
    "{\"id\":\"comparison-book\",\"name\":\"Comparison Book\"}\n",
  )
  let invalid = persist_mooncode_comparison(root, {
    "contract": MoonCodeComparisonContract,
    "id": "comparison-invalid",
    "workspace_id": "book-comparison-book",
    "baseline_request_digest": "request:weak",
    "goal": "Compare",
    "sessions": [
      { "label": "A", "id": "session-a" },
      { "label": "A", "id": "session-b" },
    ],
  })
  assert_true(invalid is Err(_))
}
