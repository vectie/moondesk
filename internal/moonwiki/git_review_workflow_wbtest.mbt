///|
test "Git history keeps subject and author separate and paginates" {
  let record = "0123456789012345678901234567890123456789\u0000parent\u0000A User\u00002026-10-13T12:00:00+08:00\u0000Fix | useful subject\u0000\n"
  let single = parse_git_history(record, 40)
  let commits = json_array_items(single, "commits")
  assert_eq(commits.length(), 1)
  assert_eq(
    json_string(commits[0], "subject", default=""),
    "Fix | useful subject",
  )
  assert_eq(json_int(single, "next_offset", default=0), 41)
  let many = parse_git_history([ for _ in 0..<41 => record ].join(""), 0)
  assert_eq(json_array_items(many, "commits").length(), 40)
  assert_true(json_bool(many, "has_more", default=false))
}
