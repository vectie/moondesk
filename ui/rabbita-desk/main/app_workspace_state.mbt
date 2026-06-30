///|
fn first_workspace_id(workspaces : Array[@desk.DeskWorkspace]) -> String {
  match workspaces {
    [workspace, ..] => workspace.id
    [] => ""
  }
}

///|
fn has_workspace(workspaces : Array[@desk.DeskWorkspace], id : String) -> Bool {
  for workspace in workspaces {
    if workspace.id == id {
      return true
    }
  }
  false
}

///|
fn workspace_name(model : Model) -> String {
  for workspace in model.workspaces {
    if workspace.id == model.selected_workspace_id {
      return workspace.name
    }
  }
  "No workspace"
}

///|
fn workspace_root(model : Model) -> String {
  for workspace in model.workspaces {
    if workspace.id == model.selected_workspace_id {
      return workspace.root_path
    }
  }
  "not connected"
}

///|
fn find_entry(model : Model, path : String) -> @desk.DeskFileEntry? {
  for entry in model.entries {
    if entry.path == path {
      return Some(entry)
    }
  }
  None
}

///|
fn selected_layer(model : Model) -> String {
  match find_entry(model, model.selected_path) {
    Some(entry) => layer_label(entry.source_layer)
    None =>
      match model.preview {
        Some(preview) => renderer_label(preview.renderer)
        None => "unknown"
      }
  }
}

///|
fn workspace_kind_label(kind : @desk.WorkspaceKind) -> String {
  match kind {
    MoonBook => "moonbook"
    TownRoot => "town"
  }
}

///|
fn is_inbox_path(path : String) -> Bool {
  path == "inbox" || path.has_prefix("inbox/")
}

///|
fn is_generated_site_path(path : String) -> Bool {
  path == "book/site/generated" || path.has_prefix("book/site/generated/")
}

///|
fn remember_primary_preview_path(model : Model, path : String) -> String {
  if path != "" && !is_generated_site_path(path) {
    path
  } else {
    model.primary_preview_path
  }
}

///|
fn is_textual_renderer(renderer : @desk.PreviewRenderer) -> Bool {
  match renderer {
    Markdown | Json | Text | ArtifactSummary | DirectoryListing | Unsupported =>
      true
    _ => false
  }
}

///|
fn can_edit_markdown_selection(model : Model) -> Bool {
  model.selected_workspace_id != "" &&
  model.preview is Some({ renderer: Markdown, .. }) &&
  is_editable_moonwiki_markdown_path(model.selected_path)
}

///|
fn is_editable_moonwiki_markdown_path(path : String) -> Bool {
  (path.has_prefix("wiki/") || path.has_prefix("inbox/")) &&
  (
    path.has_suffix(".md") ||
    path.has_suffix(".markdown") ||
    path.has_suffix(".mbt.md")
  )
}

///|
fn markdown_editor_active(model : Model) -> Bool {
  model.markdown_editor_path != "" &&
  model.markdown_editor_path == model.selected_path
}

///|
fn remember_path(paths : Array[String], path : String) -> Array[String] {
  if path == "" {
    return paths
  }
  let next : Array[String] = [path]
  for item in paths {
    if item != path && next.length() < 8 {
      next.push(item)
    }
  }
  next
}

///|
fn has_string(items : Array[String], value : String) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
fn toggle_string(items : Array[String], value : String) -> Array[String] {
  let next : Array[String] = []
  if has_string(items, value) {
    for item in items {
      if item != value {
        next.push(item)
      }
    }
  } else {
    for item in items {
      next.push(item)
    }
    next.push(value)
  }
  next
}
