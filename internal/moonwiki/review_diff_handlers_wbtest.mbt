///|
test "line diff summary detects additions and removals" {
  let diff = line_diff_summary("a\nb\n", "a\nc\n")
  assert_eq(json_int(diff, "added", default=0), 1)
  assert_eq(json_int(diff, "removed", default=0), 1)
  assert_true(json_bool(diff, "changed", default=false))
}

///|
test "line diff summary keeps rendered body bounded" {
  let long = "x".repeat(500)
  let diff = line_diff_summary("", long)
  let body = json_string(diff, "body", default="")
  assert_true(body.length() < 260)
  assert_true(body.contains("..."))
}
