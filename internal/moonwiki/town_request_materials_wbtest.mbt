///|
test "town request listing preserves material context" {
  let request : Json = {
    "title": "Build a field guide",
    "prompt": "Use the attached reports.",
    "target_book_id": "book-demo",
    "context_entries": ["inbox/imports/report.md", "inbox/imports/table.md"],
  }
  let projected = town_request_payload_from_existing_request(
    request,
    { "id": "request-1" },
    "request-1.json",
  )
  assert_eq(json_string(projected, "target_book_id", default=""), "book-demo")
  assert_true(
    json_string_array_items(projected, "context_entries") ==
    ["inbox/imports/report.md", "inbox/imports/table.md"],
  )
}

///|
test "town request listing falls back to record material context" {
  let projected = town_request_payload_from_existing_request(
    { "title": "Build" },
    {
      "target_book_id": "book-fallback",
      "context_entries": ["inbox/fallback.md"],
    },
    "request-2.json",
  )
  assert_eq(
    json_string(projected, "target_book_id", default=""),
    "book-fallback",
  )
  assert_true(
    json_string_array_items(projected, "context_entries") ==
    ["inbox/fallback.md"],
  )
}
