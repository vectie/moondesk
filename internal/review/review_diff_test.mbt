///|
test "line diff summary detects additions and removals" {
  let diff = @review.line_diff_summary("a\nb\n", "a\nc\n")
  assert_eq(diff.added(), 1)
  assert_eq(diff.removed(), 1)
  assert_true(diff.changed())
}

///|
test "line diff summary keeps rendered body bounded" {
  let long = "x".repeat(500)
  let diff = @review.line_diff_summary("", long)
  let body = diff.body()
  assert_true(body.length() < 260)
  assert_true(body.contains("..."))
}
