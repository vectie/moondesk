///|
fn markdown_edit_preview(path : String, body : String) -> @desk.DeskPreview {
  @desk.preview(@desk.file_entry(workspace_id="book-demo", path~), body~)
}

///|
test "moonwiki markdown editor starts from selected preview" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    preview: Some(markdown_edit_preview("wiki/index.md", "# Hello\n")),
  }
  let (_, next) = update_workspace_surface_actions(
    dispatch,
    StartMarkdownEdit,
    model,
  )
  assert_eq(next.markdown_editor_path, "wiki/index.md")
  assert_eq(next.markdown_editor_content, "# Hello\n")
  assert_eq(next.markdown_editor_status, "editing wiki/index.md")
  assert_true(markdown_editor_active(next))
}

///|
test "moonwiki markdown editor rejects non wiki markdown selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "raw/source.md",
    preview: Some(markdown_edit_preview("raw/source.md", "# Raw\n")),
  }
  let (_, next) = update_workspace_surface_actions(
    dispatch,
    StartMarkdownEdit,
    model,
  )
  assert_eq(next.markdown_editor_path, "")
  assert_true(next.markdown_editor_status.contains("wiki or inbox markdown"))
}

///|
test "saved markdown edit refreshes preview and exits editor" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    current_directory: "wiki",
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# Updated\n",
  }
  let (_, next) = update_workspace_results(
    dispatch,
    SavedMarkdownEdit(
      Ok({ workspace_id: "book-demo", path: "wiki/index.md" }),
    ),
    model,
  )
  assert_eq(next.selected_workspace_id, "book-demo")
  assert_eq(next.selected_path, "wiki/index.md")
  assert_eq(next.current_directory, "wiki")
  assert_eq(next.markdown_editor_path, "")
  assert_eq(next.markdown_editor_content, "")
  assert_eq(next.markdown_editor_status, "saved wiki/index.md")
  assert_eq(next.preview_status, "loading saved markdown")
}

///|
test "markdown editor preview follows draft content" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# Draft\n\n- one\n",
  }
  let preview = markdown_editor_preview(model)
  assert_true(preview.renderer is Markdown)
  assert_eq(preview.title, "index.md")
  assert_eq(preview.body, "# Draft\n\n- one\n")
}

///|
test "navigating away clears markdown editor state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# Draft\n",
    markdown_editor_status: "editing wiki/index.md",
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectPath("wiki/other.md"),
    model,
  )
  assert_eq(next.selected_path, "wiki/other.md")
  assert_eq(next.markdown_editor_path, "")
  assert_eq(next.markdown_editor_content, "")
  assert_eq(next.markdown_editor_status, "editor idle")
}

///|
test "reloading same markdown path keeps editor state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    markdown_editor_path: "wiki/index.md",
    markdown_editor_content: "# Draft\n",
    markdown_editor_status: "editing wiki/index.md",
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    OpenQuickPath("wiki/index.md"),
    model,
  )
  assert_eq(next.selected_path, "wiki/index.md")
  assert_eq(next.markdown_editor_path, "wiki/index.md")
  assert_eq(next.markdown_editor_content, "# Draft\n")
}
