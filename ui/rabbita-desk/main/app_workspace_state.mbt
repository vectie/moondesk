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
  let root = workspace_root(model)
  if root == "not connected" && model.workspace_root_path != "" {
    return model.workspace_root_path
  }
  match root.rev_split_once("/books/") {
    Some((base, _)) => base.to_owned()
    None =>
      if root.has_suffix("/books") {
        root[:root.length() - "/books".length()].to_owned()
      } else {
        root
      }
  }
}

///|
fn workspace_moonbook_library_path(model : Model) -> String {
  let root = workspace_library_root(model)
  if root == "not connected" && model.workspace_library_path != "" {
    return model.workspace_library_path
  }
  if root == "not connected" {
    root
  } else if root.has_suffix("/books") {
    root
  } else {
    root + "/books"
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
fn workspace_core_products(model : Model) -> Array[MoonSuiteProduct] {
  let visible : Array[MoonSuiteProduct] = []
  for product in model.moonsuite_products {
    if [
      "moondesk", "moonbook", "moonwiki", "mooncode", "moonclaw", "moontown",
    ].contains(product.id) {
      visible.push(product)
    }
  }
  if visible.length() > 0 {
    visible
  } else {
    model.moonsuite_products
  }
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
fn workspace_kind_label(kind : @desk.WorkspaceKind) -> String {
  match kind {
    MoonBook => "moonbook"
    TownRoot => "town"
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
fn clear_markdown_editor(model : Model) -> Model {
  {
    ..model,
    markdown_editor_path: "",
    markdown_editor_content: "",
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
