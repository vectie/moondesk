///|
test "book calendar stores recurring review date and reminder with its document" {
  let event = document_calendar_event(
    {
      "workspace_id": "book-a",
      "title": "Weekly review",
      "starts_at": 1793350800,
      "ends_at": 1793354400,
      "timezone": "Asia/Shanghai",
      "recurrence": "weekdays",
      "remind_minutes": 15,
      "document_path": "reports/review.md",
    },
    "2026-10-13T00:00:00Z",
  ).unwrap()
  assert_eq(json_string(event, "title", default=""), "Weekly review")
  assert_eq(json_string(event, "recurrence", default=""), "weekdays")
  assert_eq(json_int(event, "remind_minutes", default=0), 15)
  assert_true(
    document_calendar_event(
      { "title": "Review", "starts_at": 100, "ends_at": 50 },
      "now",
    )
    is Err(_),
  )
}
