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
  if model.workspace_root_path != "" {
    "MoonSuite: " + @desk.display_name(model.workspace_root_path)
  } else {
    "No workspace"
  }
}

///|
fn workspace_root(model : Model) -> String {
  for workspace in model.workspaces {
    if workspace.id == model.selected_workspace_id {
      return workspace.root_path
    }
  }
  if model.workspace_root_path != "" {
    model.workspace_root_path
  } else {
    "not connected"
  }
}

///|
fn workspace_library_root(model : Model) -> String {
  if model.workspace_suite_root_path != "" {
    return model.workspace_suite_root_path
  }
  let root = workspace_root(model)
  @desk.moonsuite_root_for_workspace_root(root)
}

///|
fn workspace_moonbook_library_path(model : Model) -> String {
  if model.workspace_books_root_path != "" {
    return model.workspace_books_root_path
  }
  let root = workspace_library_root(model)
  if root == "not connected" && model.workspace_library_path != "" {
    return model.workspace_library_path
  }
  if root == "not connected" {
    root
  } else {
    @desk.moonsuite_books_root(root)
  }
}

///|
fn workspace_library_count_label(model : Model) -> String {
  let count = model.workspaces.length()
  if count == 1 {
    "1 MoonBook"
  } else {
    "\{count} MoonBooks"
  }
}

///|
fn workspace_product_count_label(model : Model) -> String {
  let count = model.moonsuite_products.length()
  if count == 1 {
    "1 product installed"
  } else {
    "\{count} products installed"
  }
}

///|
fn workspace_display_products(model : Model) -> Array[MoonSuiteProduct] {
  model.moonsuite_products
}

///|
fn workspace_suite_display_name(model : Model) -> String {
  let root = workspace_library_root(model)
  if root == "" || root == "not connected" {
    "MoonSuite"
  } else {
    @desk.display_name(root)
  }
}

///|
fn workspace_books_display_label(model : Model) -> String {
  ignore(model)
  "books/"
}

///|
fn workspace_visible_location_label(model : Model) -> String {
  "MoonSuite: " + workspace_suite_display_name(model)
}

///|
fn workspace_display_book_location(
  model : Model,
  workspace : @desk.DeskWorkspace,
) -> String {
  match workspace.kind {
    SuiteRoot => "MoonSuite root"
    MoonBook => {
      let books_root = workspace_moonbook_library_path(model)
      if books_root != "" && workspace.root_path.has_prefix(books_root + "/") {
        "books/" + workspace.root_path[books_root.length() + 1:].to_owned()
      } else {
        "books/" + @desk.display_name(workspace.root_path)
      }
    }
  }
}

///|
fn workspace_service_status_items(
  model : Model,
) -> Array[(String, String, String)] {
  let items : Array[(String, String, String)] = []
  items.push(("MoonSuite", "ready", workspace_suite_display_name(model)))
  items.push(("MoonBooks", "ready", workspace_library_count_label(model)))
  items.push(("Products", "ready", workspace_product_count_label(model)))
  match model.moonclaw_daemon {
    Some(daemon) =>
      items.push(
        (
          "MoonClaw",
          if daemon.running {
            "ready"
          } else {
            "missing"
          },
          if daemon.running {
            "running"
          } else {
            "not running"
          },
        ),
      )
    None => items.push(("MoonClaw", "unknown", "checking"))
  }
  match model.town_progress {
    Some(progress) =>
      items.push(
        (
          "MoonTown",
          if progress.daemon_running {
            "ready"
          } else {
            "missing"
          },
          if progress.daemon_running {
            progress.daemon_status
          } else {
            "not running"
          },
        ),
      )
    None => items.push(("MoonTown", "unknown", "checking"))
  }
  items
}

///|
fn workspace_product_status_label(product : MoonSuiteProduct) -> String {
  match product.status {
    "installed" => "Installed"
    "enabled" => "Enabled"
    "disabled" => "Disabled"
    "missing" => "Missing"
    "" => "Unknown"
    other => other
  }
}

///|
fn workspace_product_chip_title(product : MoonSuiteProduct) -> String {
  product.name + ": " + workspace_product_status_label(product)
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
fn workspace_status_label(status : @desk.WorkspaceStatus) -> String {
  match status {
    Ready => "Ready"
    Missing => "Missing"
    NeedsAttention => "Needs setup"
    Unknown => "Unknown"
  }
}

///|
fn workspace_status_key(status : @desk.WorkspaceStatus) -> String {
  match status {
    Ready => "ready"
    Missing => "missing"
    NeedsAttention => "needs-attention"
    Unknown => "unknown"
  }
}

///|
fn workspace_status_class(status : @desk.WorkspaceStatus) -> String {
  "status-" + workspace_status_key(status)
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
fn markdown_editor_dirty(model : Model) -> Bool {
  model.markdown_editor_path != "" &&
  model.markdown_editor_content != model.markdown_editor_original
}

///|
fn clear_markdown_editor(model : Model) -> Model {
  {
    ..model,
    markdown_editor_path: "",
    markdown_editor_content: "",
    markdown_editor_original: "",
    markdown_editor_status: "editor idle",
  }
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
