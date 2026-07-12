///|
fn raw_url(model : Model, path : String) -> String {
  if model.selected_workspace_id == "" {
    "#"
  } else {
    @desk.workspace_raw_url(model.selected_workspace_id, path)
  }
}

///|
fn file_url(model : Model, path : String) -> String {
  if model.selected_workspace_id == "" {
    "#"
  } else {
    @desk.workspace_file_url(model.selected_workspace_id, path)
  }
}

///|
fn html_preview_url(model : Model, path : String) -> String {
  if model.selected_workspace_id == "" {
    "#"
  } else if path == "book/site/generated" {
    @desk.workspace_site_url(model.selected_workspace_id, "")
  } else if path.has_prefix("book/site/generated/") {
    @desk.workspace_site_url(
      model.selected_workspace_id,
      path["book/site/generated/".length():].to_owned(),
    )
  } else {
    file_url(model, path)
  }
}

///|
fn workspace_entries_url(workspace_id : String, path : String) -> String {
  @desk.workspace_entries_url(workspace_id, path)
}

///|
fn workspace_preview_url(workspace_id : String, path : String) -> String {
  @desk.workspace_preview_url(workspace_id, path)
}
