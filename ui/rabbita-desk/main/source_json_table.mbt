///|
fn source_json_table_supported(source : SourcePaneState) -> Bool {
  source_pane_editable(source) &&
  json_table_selection_supported(source.requested_path)
}

///|
fn json_table_selection_supported(path : String) -> Bool {
  let path = path.to_lower()
  path.has_suffix(".json") ||
  path.has_suffix(".jsonl") ||
  path.has_suffix(".ndjson") ||
  path.has_suffix(".csv") ||
  path.has_suffix(".tsv") ||
  path.has_suffix(".xlsx")
}

///|
fn render_json_table_link(
  workspace_id : String,
  path : String,
) -> @rabbita.Html {
  if !json_table_selection_supported(path) {
    return @html.nothing
  }
  @html.a(
    class="secondary-button",
    attrs=@html.Attrs::build()
      .data_set("testid", "view-as-table")
      .target(Blank)
      .rel("noopener"),
    href=@desk.workspace_json_table_url(workspace_id, path),
    "View as table",
  )
}

///|
fn render_source_json_table_action(source : SourcePaneState) -> @rabbita.Html {
  if !source_json_table_supported(source) {
    return @html.span("")
  }
  if source_pane_dirty(source) || source.saving {
    return @html.span("Save changes to view this data as a table")
  }
  render_json_table_link(source.workspace_id, source.requested_path)
}
