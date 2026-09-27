///|
test "Code media paths accept only bounded immutable identifiers" {
  assert_true(mooncode_media_safe_segment("mooncode-cmd_123.4"))
  assert_false(mooncode_media_safe_segment("../other"))
  assert_false(mooncode_media_safe_segment("bad%2Fsegment"))
  assert_false(mooncode_media_safe_segment(""))
  assert_true(mooncode_media_safe_index("0"))
  assert_true(mooncode_media_safe_index("11"))
  assert_false(mooncode_media_safe_index("12"))
  assert_false(mooncode_media_safe_index("01"))
  assert_false(mooncode_media_safe_index("-1"))
}
