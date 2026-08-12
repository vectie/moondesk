///|
fn mooncode_markdown_test_dispatch(_msg : Msg) -> @rabbita.Cmd {
  @rabbita.none
}

///|
#warnings("-alert_unstable")
test "MoonCode markdown exposes a route-runtime source boundary" {
  assert_eq(
    mooncode_markdown_nodes(mooncode_markdown_test_dispatch, "", "").length(),
    0,
  )
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      div(
        mooncode_markdown_nodes(
          mooncode_markdown_test_dispatch, "", "# Result\n\nUpdated the parser.\n\n```moonbit\nfn parse() {}\n```",
        ),
      ),
    ),
  )
  assert_true(markup.contains("data-testid=\"mooncode-markdown-source\""))
  assert_true(markup.contains("fn parse()"))
}

///|
test "MoonCode markdown accepts every streaming prefix without parsing" {
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
#warnings("-alert_unstable")
test "MoonCode markdown keeps raw HTML and unsafe links as inert text" {
  let nodes = mooncode_markdown_nodes(
    mooncode_markdown_test_dispatch, "", "<script>alert('no')</script>\n\n[unsafe](javascript:alert(1))",
  )
  assert_eq(nodes.length(), 1)
  let markup = @rabbita.render_to_string(@rabbita.static_cell(div(nodes)))
  assert_true(markup.contains("&lt;script&gt;"))
  assert_false(markup.contains("href=\"javascript:"))
}
