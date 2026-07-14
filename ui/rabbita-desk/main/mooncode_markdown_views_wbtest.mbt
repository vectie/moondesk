///|
fn mooncode_markdown_test_dispatch(_msg : Msg) -> @rabbita.Cmd {
  @rabbita.none
}

///|
test "MoonCode markdown renders useful block structure" {
  assert_eq(
    mooncode_markdown_nodes(mooncode_markdown_test_dispatch, "", "").length(),
    0,
  )
  assert_eq(
    mooncode_markdown_nodes(
      mooncode_markdown_test_dispatch, "", "# Result\n\nUpdated the parser.\n\n```moonbit\nfn parse() {}\n```\n\n| Check | State |\n| - | - |\n| test | pass |",
    ).length(),
    4,
  )
}

///|
test "MoonCode markdown contains parser failures for streaming prefixes" {
  let answer = "Result:\n\n- first\n- second\n\n```moonbit\nfn main() {}\n```"
  let buffer = StringBuilder::new()
  for char in answer {
    buffer.write_char(char)
    let nodes = mooncode_markdown_nodes(
      mooncode_markdown_test_dispatch,
      "",
      buffer.to_string(),
    )
    assert_true(nodes.length() > 0)
  }
}

///|
test "MoonCode markdown treats raw HTML and unsafe links as content" {
  let nodes = mooncode_markdown_nodes(
    mooncode_markdown_test_dispatch, "", "<script>alert('no')</script>\n\n[unsafe](javascript:alert(1))",
  )
  assert_eq(nodes.length(), 2)
}
