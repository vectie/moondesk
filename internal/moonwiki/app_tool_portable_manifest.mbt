///|
fn app_tool_manifest_relative_path(book_json : Json) -> String {
  for
    owner in [
      json_object_field_or_empty(book_json, "toolbook"),
      json_object_field_or_empty(book_json, "tool_binding"),
    ] {
    let manifest_path = json_string(owner, "manifest_path", default="")
      .trim()
      .to_owned()
    match clean_relative_path(manifest_path) {
      Some(path) => if path != "" { return path }
      None => ()
    }
  }
  app_tool_default_manifest_relative_path()
}

///|
fn app_tool_book_is_app_tool(book_json : Json, manifest : Json) -> Bool {
  app_tool_template_id(book_json, manifest) == "app-tool-book" ||
  json_string(manifest, "kind", default="") == "app-tool-book-manifest" ||
  json_string(book_json, "type", default="") == "toolbook" ||
  json_string(book_json, "book_type", default="") == "toolbook"
}

///|
async fn app_tool_book_is_portable_candidate(
  book_root : String,
  book_json : Json,
  manifest : Json,
) -> Bool {
  app_tool_book_is_app_tool(book_json, manifest) ||
  app_tool_book_has_generated_app_entrypoint(book_root)
}

///|
async fn app_tool_book_has_generated_app_entrypoint(book_root : String) -> Bool {
  for entrypoint in ["app/index.html", "app/index.htm"] {
    let path = @pathx.join(book_root, entrypoint)
    if @fs.exists(path) && !is_directory(path) {
      return true
    }
  }
  false
}

///|
fn app_tool_template_id(book_json : Json, manifest : Json) -> String {
  let manifest_template = json_string(manifest, "template_id", default="")
  if manifest_template != "" {
    return manifest_template
  }
  let direct = json_string(book_json, "template_id", default="")
  if direct != "" {
    return direct
  }
  for
    owner in [
      json_object_field_or_empty(book_json, "toolbook"),
      json_object_field_or_empty(book_json, "tool_binding"),
    ] {
    let template = json_string(owner, "template_id", default="")
    if template != "" {
      return template
    }
  }
  json_string(book_json, "specialization", default="")
}

///|
fn app_tool_title(
  book_json : Json,
  manifest : Json,
  book_id : String,
) -> String {
  let direct = json_string(book_json, "title", default="")
  if direct != "" {
    return direct
  }
  let tool = json_object_field_or_empty(manifest, "tool")
  let tool_title = json_string(tool, "title", default="")
  if tool_title != "" {
    tool_title
  } else {
    book_id
  }
}

///|
fn app_tool_entrypoints(book_json : Json, manifest : Json) -> Array[String] {
  let entrypoints : Array[String] = []
  app_tool_add_entrypoints_from_object(
    entrypoints,
    json_object_field_or_empty(manifest, "tool"),
  )
  app_tool_add_entrypoints_from_object(entrypoints, manifest)
  app_tool_add_entrypoints_from_object(
    entrypoints,
    json_object_field_or_empty(book_json, "toolbook"),
  )
  app_tool_add_entrypoints_from_object(
    entrypoints,
    json_object_field_or_empty(book_json, "tool_binding"),
  )
  if entrypoints.length() == 0 {
    app_tool_add_relative_path(entrypoints, "book/site/generated/tool.html")
    app_tool_add_relative_path(entrypoints, "book/site/generated/index.html")
    app_tool_add_relative_path(entrypoints, "app/index.html")
  }
  entrypoints
}

///|
fn app_tool_add_entrypoints_from_object(
  entrypoints : Array[String],
  object : Json,
) -> Unit {
  for item in json_string_array_items(object, "entrypoints") {
    app_tool_add_relative_path(entrypoints, item)
  }
  let entrypoint = json_string(object, "entrypoint", default="")
  app_tool_add_relative_path(entrypoints, entrypoint)
}

///|
fn app_tool_entrypoint_is_html(entrypoint : String) -> Bool {
  let lower = entrypoint.to_lower()
  lower.has_suffix(".html") || lower.has_suffix(".htm")
}

///|
fn app_tool_preferred_html_entrypoint(
  html_entrypoints : Array[String],
) -> String {
  if html_entrypoints.length() == 0 {
    return ""
  }
  let mut selected = html_entrypoints[0]
  let mut selected_rank = app_tool_entrypoint_rank(selected)
  for entrypoint in html_entrypoints {
    let rank = app_tool_entrypoint_rank(entrypoint)
    if rank < selected_rank {
      selected = entrypoint
      selected_rank = rank
    }
  }
  selected
}

///|
fn app_tool_entrypoint_rank(entrypoint : String) -> Int {
  let lower = entrypoint.to_lower()
  if lower == "app/index.html" || lower == "app/index.htm" {
    0
  } else if lower.has_prefix("app/") {
    1
  } else if lower == "book/site/generated/tool.html" ||
    lower == "site/generated/tool.html" {
    2
  } else if lower.has_prefix("book/site/generated/") ||
    lower.has_prefix("site/generated/") {
    3
  } else {
    4
  }
}

///|
fn app_tool_portable_source_paths(
  book_json : Json,
  manifest : Json,
) -> Array[String] {
  let paths : Array[String] = []
  app_tool_add_relative_path(paths, "book.json")
  app_tool_add_relative_path(paths, app_tool_manifest_relative_path(book_json))
  for
    dir in [
      "app", "book/site/generated", "site/generated", "book/outputs", "wiki/reports",
      "wiki/tools", "raw/analysis-runs", "skills", "schemas",
    ] {
    app_tool_add_relative_path(paths, dir)
  }
  for entrypoint in app_tool_entrypoints(book_json, manifest) {
    app_tool_add_relative_path(paths, entrypoint)
  }
  app_tool_collect_json_paths(
    json_object_field_or_empty(manifest, "outputs"),
    paths,
  )
  app_tool_collect_json_paths(
    json_object_field_or_empty(
      json_object_field_or_empty(book_json, "toolbook"),
      "outputs",
    ),
    paths,
  )
  app_tool_collect_json_paths(
    json_object_field_or_empty(
      json_object_field_or_empty(book_json, "tool_binding"),
      "outputs",
    ),
    paths,
  )
  paths
}

///|
fn app_tool_collect_json_paths(value : Json, paths : Array[String]) -> Unit {
  match value {
    String(text) => app_tool_add_relative_path(paths, text)
    Array(items) =>
      for item in items {
        app_tool_collect_json_paths(item, paths)
      }
    Object(object) =>
      for _, item in object {
        app_tool_collect_json_paths(item, paths)
      }
    _ => ()
  }
}

///|
fn app_tool_add_relative_path(paths : Array[String], relative : String) -> Unit {
  let relative = relative.trim().to_owned()
  if relative == "" ||
    relative.has_prefix("http://") ||
    relative.has_prefix("https://") ||
    relative.has_prefix("data:") ||
    relative.has_prefix("#") {
    return
  }
  match clean_relative_path(relative) {
    Some(path) =>
      if path != "" && !path.has_prefix("portable/") && !paths.contains(path) {
        paths.push(path)
      }
    None => ()
  }
}
