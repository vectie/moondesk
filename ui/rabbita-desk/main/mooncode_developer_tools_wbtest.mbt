///|
#warnings("-alert_unstable")
test "MoonCode developer tools remain disclosed and identify honest execution boundaries" {
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_mooncode_developer_tools(init_model())),
  )
  assert_true(markup.has_prefix("<details"))
  assert_true(markup.contains("data-testid=\"mooncode-developer-tools\""))
  assert_true(markup.contains("data-runtime=\"mooncode-developer-tools-v1\""))
  assert_true(markup.contains("data-initial-url=\"about:blank\""))
  assert_true(markup.contains("data-preferred-tool=\"terminal\""))
  assert_true(markup.contains("data-source-path=\"\""))
  assert_true(markup.contains("data-workspace-id=\"\""))
  assert_true(markup.contains("Developer tools"))
  assert_true(markup.contains("Terminal · Browser · Compare"))
  assert_true(markup.contains("data-testid=\"mooncode-developer-compare\""))
  assert_true(markup.contains("data-developer-compare-form=\"true\""))
  assert_true(
    markup.contains(
      "data-testid=\"mooncode-developer-compare-submit\" disabled",
    ),
  )
}

///|
#warnings("-alert_unstable")
test "MoonCode developer browser starts blank without an HTML workspace preview" {
  assert_eq(mooncode_developer_browser_url(init_model()), "about:blank")
}

///|
#warnings("-alert_unstable")
test "HTML workspace preview opens directly in MoonCode browser tools" {
  let path = "book/site/generated/index.html"
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: path,
    preview: Some(
      @desk.preview(
        @desk.file_entry(workspace_id="book-demo", path~),
        body="<!doctype html><title>Demo</title>",
      ),
    ),
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_mooncode_developer_tools(model)),
  )
  assert_true(markup.contains("data-preferred-tool=\"browser\""))
  assert_true(
    markup.contains("data-source-path=\"book/site/generated/index.html\""),
  )
  assert_true(
    markup.contains(
      "data-testid=\"mooncode-developer-browser-prepare-evidence\"",
    ),
  )
  assert_true(markup.contains("disabled"))
  assert_true(markup.contains(" open"))
  assert_true(markup.contains("/api/workspaces/book-demo/site/"))
}
