///|
fn raw_url(model : Model, path : String) -> String {
  if model.selected_workspace_id == "" {
    "#"
  } else {
    "/api/workspaces/\{model.selected_workspace_id}/raw?path=\{encode_component(path)}"
  }
}

///|
fn file_url(model : Model, path : String) -> String {
  if model.selected_workspace_id == "" {
    "#"
  } else {
    "/api/workspaces/\{model.selected_workspace_id}/file/\{encode_path(path)}"
  }
}

///|
fn html_preview_url(model : Model, path : String) -> String {
  file_url(model, path)
}

///|
fn workspace_entries_url(workspace_id : String, path : String) -> String {
  "/api/workspaces/\{workspace_id}/entries?path=\{encode_component(path)}"
}

///|
fn workspace_preview_url(workspace_id : String, path : String) -> String {
  "/api/workspaces/\{workspace_id}/preview?path=\{encode_component(path)}"
}
