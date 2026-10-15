///|
test "artifact template preserves item values and sources while restarting checklist progress" {
  let original : Json = {
    "workspace_id": "book-a",
    "title": "Review",
    "kind": "checklist",
    "purpose": "Review the release",
    "items": [
      {
        "label": "Read notes",
        "value": "Release notes",
        "source": "notes.md",
        "done": true,
      },
    ],
  }
  let duplicate = living_artifact_duplicate(
    original, "Next review", "2026-10-13T12:00:00Z",
  ).unwrap()
  let items = json_array_items(duplicate, "items")
  assert_eq(json_string(duplicate, "title", default=""), "Next review")
  assert_eq(json_string(items[0], "source", default=""), "notes.md")
  assert_eq(json_string(items[0], "value", default=""), "Release notes")
  assert_false(json_bool(items[0], "done", default=true))
}
