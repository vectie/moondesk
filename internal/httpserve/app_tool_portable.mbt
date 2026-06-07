///|
fn app_tool_portable_bundle_relative_dir() -> String {
  "portable/app-tool"
}

///|
fn app_tool_portable_index_relative_path() -> String {
  @pathx.join(app_tool_portable_bundle_relative_dir(), "index.html")
}

///|
fn app_tool_portable_manifest_relative_path() -> String {
  @pathx.join(app_tool_portable_bundle_relative_dir(), "portable-manifest.json")
}

///|
fn app_tool_default_manifest_relative_path() -> String {
  "tool-manifest.json"
}

///|
async fn handle_app_tool_portable_status(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let book_id = decode_query_value(
      query_value(request_path, "book_id").unwrap_or(""),
    )
    .trim()
    .to_owned()
  if book_id == "" {
    send_api_error(conn, method_, 400, "Bad Request", "book_id is required")
    return
  }
  let root = @pathx.normalize(workspace_root)
  let book_root = app_tool_book_root_for_id(root, book_id)
  if !@fs.exists(@pathx.join(book_root, "book.json")) {
    send_api_error(conn, method_, 404, "Not Found", "Book not found")
    return
  }
  send_json(conn, method_, app_tool_portable_status(root, book_root, book_id))
}

///|
async fn handle_app_tool_portable_export(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let book_id = json_string(payload, "book_id", default="").trim().to_owned()
  if book_id == "" {
    send_api_error(conn, method_, 400, "Bad Request", "book_id is required")
    return
  }
  let root = @pathx.normalize(workspace_root)
  let book_root = app_tool_book_root_for_id(root, book_id)
  if !@fs.exists(@pathx.join(book_root, "book.json")) {
    send_api_error(conn, method_, 404, "Not Found", "Book not found")
    return
  }
  let result = export_app_tool_portable_bundle(root, book_root, book_id) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not export app-tool portable bundle: \{error}",
      )
      return
    }
  }
  if !json_bool(result, "ok", default=false) {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      json_string(
        result,
        "message",
        default="App-tool bundle is not exportable",
      ),
    )
    return
  }
  send_json(conn, method_, result)
}

///|
fn app_tool_book_root_for_id(root : String, book_id : String) -> String {
  @pathx.join(@pathx.join(root, ".moontown/books"), book_id)
}

///|
async fn app_tool_portable_status(
  root : String,
  book_root : String,
  book_id : String,
) -> Json {
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let manifest_relative = app_tool_manifest_relative_path(book_json)
  let manifest = read_json_file_or_object(
    @pathx.join(book_root, manifest_relative),
  )
  let is_app_tool = app_tool_book_is_app_tool(book_json, manifest)
  let entrypoints = app_tool_entrypoints(book_json, manifest)
  let existing_entrypoints : Array[String] = []
  let missing_entrypoints : Array[String] = []
  for entrypoint in entrypoints {
    let absolute = @pathx.join(book_root, entrypoint)
    if @fs.exists(absolute) && !is_directory(absolute) {
      existing_entrypoints.push(entrypoint)
    } else {
      missing_entrypoints.push(entrypoint)
    }
  }
  let entrypoint = if existing_entrypoints.length() > 0 {
    existing_entrypoints[0]
  } else {
    ""
  }
  let bundle_root = @pathx.join(
    book_root,
    app_tool_portable_bundle_relative_dir(),
  )
  let portable_manifest_path = @pathx.join(
    book_root,
    app_tool_portable_manifest_relative_path(),
  )
  let portable_manifest = read_json_file_or_object(portable_manifest_path)
  let portable_entrypoint = json_string(
    portable_manifest,
    "entrypoint",
    default=entrypoint,
  )
  let portable_entrypoint_ready = portable_entrypoint != "" &&
    @fs.exists(@pathx.join(bundle_root, portable_entrypoint)) &&
    !is_directory(@pathx.join(bundle_root, portable_entrypoint))
  let portable_ready = is_app_tool &&
    existing_entrypoints.length() > 0 &&
    @fs.exists(@pathx.join(book_root, app_tool_portable_index_relative_path())) &&
    @fs.exists(portable_manifest_path) &&
    portable_entrypoint_ready
  let api_warnings = json_string_array_items(
    portable_manifest, "api_dependency_warnings",
  )
  let status = if !is_app_tool {
    "not_app_tool"
  } else if existing_entrypoints.length() == 0 {
    "missing_entrypoint"
  } else if portable_ready && api_warnings.length() == 0 {
    "portable_ready"
  } else if portable_ready {
    "portable_with_api_warnings"
  } else {
    "export_required"
  }
  {
    "kind": "moondesk-app-tool-portable-status",
    "ok": is_app_tool && existing_entrypoints.length() > 0,
    "status": status,
    "message": app_tool_portable_status_message(status),
    "book_id": book_id,
    "book_root": book_root,
    "workspace_root": root,
    "source_manifest_path": manifest_relative,
    "template_id": app_tool_template_id(book_json, manifest),
    "app_tool": is_app_tool,
    "entrypoint": entrypoint,
    "entrypoints": json_from_string_array(entrypoints),
    "existing_entrypoints": json_from_string_array(existing_entrypoints),
    "missing_entrypoints": json_from_string_array(missing_entrypoints),
    "portable_ready": portable_ready,
    "portable_bundle_path": app_tool_portable_bundle_relative_dir(),
    "portable_index_path": app_tool_portable_index_relative_path(),
    "portable_manifest_path": app_tool_portable_manifest_relative_path(),
    "standalone_runtime": "static-file-bundle",
    "operatable_without_moondesk_api": portable_ready &&
    api_warnings.length() == 0,
    "api_dependency_warnings": json_from_string_array(api_warnings),
  }
}

///|
fn app_tool_portable_status_message(status : String) -> String {
  match status {
    "not_app_tool" =>
      "Book does not declare the app-tool-book template or manifest."
    "missing_entrypoint" =>
      "Book declares app-tool metadata but none of its entrypoints exist."
    "portable_ready" =>
      "Portable app-tool bundle is ready and has no detected Moondesk API dependency."
    "portable_with_api_warnings" =>
      "Portable app-tool bundle is ready, but copied assets still reference Moondesk APIs."
    "export_required" =>
      "Book can be exported, but portable/app-tool has not been generated yet."
    _ => "Unknown app-tool portable status."
  }
}

///|
async fn export_app_tool_portable_bundle(
  _root : String,
  book_root : String,
  book_id : String,
) -> Json {
  let book_json = read_json_file_or_object(@pathx.join(book_root, "book.json"))
  let manifest_relative = app_tool_manifest_relative_path(book_json)
  let manifest = read_json_file_or_object(
    @pathx.join(book_root, manifest_relative),
  )
  if !app_tool_book_is_app_tool(book_json, manifest) {
    return {
      "kind": "moondesk-app-tool-portable-export",
      "ok": false,
      "status": "not_app_tool",
      "message": app_tool_portable_status_message("not_app_tool"),
      "book_id": book_id,
    }
  }
  let entrypoints = app_tool_entrypoints(book_json, manifest)
  let existing_entrypoints : Array[String] = []
  for entrypoint in entrypoints {
    let absolute = @pathx.join(book_root, entrypoint)
    if @fs.exists(absolute) && !is_directory(absolute) {
      existing_entrypoints.push(entrypoint)
    }
  }
  if existing_entrypoints.length() == 0 {
    return {
      "kind": "moondesk-app-tool-portable-export",
      "ok": false,
      "status": "missing_entrypoint",
      "message": app_tool_portable_status_message("missing_entrypoint"),
      "book_id": book_id,
      "entrypoints": json_from_string_array(entrypoints),
    }
  }
  let bundle_root = @pathx.join(
    book_root,
    app_tool_portable_bundle_relative_dir(),
  )
  @fsx.make_directory(bundle_root, recursive=true, exists_ok=true)
  let source_paths = app_tool_portable_source_paths(book_json, manifest)
  let copied_paths : Array[String] = []
  let missing_paths : Array[String] = []
  let skipped_paths : Array[String] = []
  for relative in source_paths {
    app_tool_copy_book_path(
      book_root, bundle_root, relative, copied_paths, missing_paths, skipped_paths,
    )
  }
  let api_warnings = app_tool_portable_api_dependency_warnings(
    bundle_root, copied_paths,
  )
  let entrypoint = existing_entrypoints[0]
  let title = app_tool_title(book_json, manifest, book_id)
  let index_html = app_tool_portable_index_html(
    book_id, title, entrypoint, existing_entrypoints, api_warnings,
  )
  @fsx.write_to_file(
    @pathx.join(bundle_root, "index.html"),
    index_html,
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(bundle_root, "README.md"),
    app_tool_portable_readme(book_id, entrypoint, api_warnings),
    create=0o644,
  )
  let export_record : Json = {
    "kind": "moondesk-app-tool-portable-bundle",
    "portable_version": "1",
    "ok": true,
    "status": if api_warnings.length() == 0 {
      "portable_ready"
    } else {
      "portable_with_api_warnings"
    },
    "book_id": book_id,
    "title": title,
    "template_id": app_tool_template_id(book_json, manifest),
    "source_manifest_path": manifest_relative,
    "bundle_path": app_tool_portable_bundle_relative_dir(),
    "index_path": app_tool_portable_index_relative_path(),
    "manifest_path": app_tool_portable_manifest_relative_path(),
    "entrypoint": entrypoint,
    "entrypoints": json_from_string_array(existing_entrypoints),
    "copied_paths": json_from_string_array(copied_paths),
    "missing_paths": json_from_string_array(missing_paths),
    "skipped_paths": json_from_string_array(skipped_paths),
    "api_dependency_warnings": json_from_string_array(api_warnings),
    "standalone_runtime": "static-file-bundle",
    "operatable_without_moondesk_api": api_warnings.length() == 0,
    "open_hint": "Open portable/app-tool/index.html from any standalone shell or static file host.",
  }
  @fsx.write_to_file(
    @pathx.join(bundle_root, "portable-manifest.json"),
    export_record.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "raw/analysis-runs"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "raw/analysis-runs/app-tool-portable-export.json"),
    export_record.stringify(indent=2) + "\n",
    create=0o644,
  )
  export_record
}

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
      "wiki/tools", "skills", "schemas",
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
    Json::String(text) => app_tool_add_relative_path(paths, text)
    Json::Array(items) =>
      for item in items {
        app_tool_collect_json_paths(item, paths)
      }
    Json::Object(object) =>
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

///|
async fn app_tool_copy_book_path(
  book_root : String,
  bundle_root : String,
  relative : String,
  copied_paths : Array[String],
  missing_paths : Array[String],
  skipped_paths : Array[String],
) -> Unit {
  match clean_relative_path(relative) {
    Some(path) =>
      if path == "" || path == "portable" || path.has_prefix("portable/") {
        app_tool_push_unique(skipped_paths, relative)
        return
      } else {
        let source = @pathx.join(book_root, path)
        if !@fs.exists(source) {
          if app_tool_optional_source_path(path) {
            app_tool_push_unique(skipped_paths, path)
          } else {
            app_tool_push_unique(missing_paths, path)
          }
        } else if is_directory(source) {
          app_tool_copy_dir_recursive(
            book_root, bundle_root, path, copied_paths, missing_paths, skipped_paths,
          )
        } else {
          app_tool_copy_file(
            book_root, bundle_root, path, copied_paths, missing_paths,
          )
        }
      }
    None => app_tool_push_unique(skipped_paths, relative)
  }
}

///|
async fn app_tool_copy_dir_recursive(
  book_root : String,
  bundle_root : String,
  relative_dir : String,
  copied_paths : Array[String],
  missing_paths : Array[String],
  skipped_paths : Array[String],
) -> Unit {
  let source_dir = @pathx.join(book_root, relative_dir)
  @fsx.make_directory(
    @pathx.join(bundle_root, relative_dir),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => {
      app_tool_push_unique(missing_paths, relative_dir)
      return
    }
  }
  for name in read_directory_names(source_dir, include_hidden=true) {
    if app_tool_should_skip_copy_name(name) {
      app_tool_push_unique(skipped_paths, @pathx.join(relative_dir, name))
      continue
    }
    let child_relative = @pathx.join(relative_dir, name)
    if child_relative == "portable" || child_relative.has_prefix("portable/") {
      app_tool_push_unique(skipped_paths, child_relative)
      continue
    }
    let child_source = @pathx.join(book_root, child_relative)
    if is_directory(child_source) {
      app_tool_copy_dir_recursive(
        book_root, bundle_root, child_relative, copied_paths, missing_paths, skipped_paths,
      )
    } else {
      app_tool_copy_file(
        book_root, bundle_root, child_relative, copied_paths, missing_paths,
      )
    }
  }
}

///|
fn app_tool_should_skip_copy_name(name : String) -> Bool {
  name == ".DS_Store" ||
  name == ".git" ||
  name == "node_modules" ||
  name == "_build" ||
  name == "portable"
}

///|
fn app_tool_optional_source_path(relative : String) -> Bool {
  [
    "app", "book/site/generated", "site/generated", "book/outputs", "wiki/reports",
    "wiki/tools", "skills", "schemas",
  ].contains(relative)
}

///|
async fn app_tool_copy_file(
  book_root : String,
  bundle_root : String,
  relative : String,
  copied_paths : Array[String],
  missing_paths : Array[String],
) -> Unit {
  let source = @pathx.join(book_root, relative)
  let target = @pathx.join(bundle_root, relative)
  let bytes = @fs.read_file(source).binary() catch {
    _ => {
      app_tool_push_unique(missing_paths, relative)
      return
    }
  }
  @fsx.make_directory(
    @pathx.dirname(target).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => {
      app_tool_push_unique(missing_paths, relative)
      return
    }
  }
  write_bytes_file(target, bytes) catch {
    _ => {
      app_tool_push_unique(missing_paths, relative)
      return
    }
  }
  app_tool_push_unique(copied_paths, relative)
}

///|
fn app_tool_push_unique(items : Array[String], item : String) -> Unit {
  if item != "" && !items.contains(item) {
    items.push(item)
  }
}

///|
async fn app_tool_portable_api_dependency_warnings(
  bundle_root : String,
  copied_paths : Array[String],
) -> Array[String] {
  let warnings : Array[String] = []
  for relative in copied_paths {
    if !app_tool_scan_text_asset(relative) {
      continue
    }
    let text = @fs.read_file(@pathx.join(bundle_root, relative)).text() catch {
      _ => continue
    }
    if text.contains("/api/") ||
      text.contains("http://127.0.0.1") ||
      text.contains("http://localhost") ||
      text.contains("https://localhost") {
      app_tool_push_unique(warnings, relative)
    }
  }
  warnings
}

///|
fn app_tool_scan_text_asset(relative : String) -> Bool {
  relative.has_suffix(".html") ||
  relative.has_suffix(".js") ||
  relative.has_suffix(".mjs") ||
  relative.has_suffix(".css") ||
  relative.has_suffix(".json")
}

///|
fn app_tool_portable_index_html(
  book_id : String,
  title : String,
  entrypoint : String,
  entrypoints : Array[String],
  api_warnings : Array[String],
) -> String {
  let links : Array[String] = []
  for item in entrypoints {
    links.push(
      "<a class=\"entry-link\" href=\"\{app_tool_html_escape(item)}\">\{app_tool_html_escape(item)}</a>",
    )
  }
  let warning = if api_warnings.length() == 0 {
    "<p class=\"status good\">Standalone-ready: no Moondesk API dependency was detected in copied assets.</p>"
  } else {
    "<p class=\"status warn\">Standalone warning: copied assets still reference Moondesk APIs in \{app_tool_html_escape(api_warnings.join(", "))}.</p>"
  }
  [
    "<!doctype html>",
    "<html>",
    "<head>",
    "<meta charset=\"utf-8\">",
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
    "<title>\{app_tool_html_escape(title)}</title>",
    "<style>",
    "body{margin:0;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;background:#f6f7f9;color:#17202a}",
    "header{display:flex;gap:16px;align-items:center;justify-content:space-between;padding:14px 18px;border-bottom:1px solid #d7dde5;background:#fff}",
    "h1{font-size:18px;line-height:1.25;margin:0}.meta{font-size:12px;color:#53606f;margin-top:4px}",
    ".actions{display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end}.entry-link{border:1px solid #b8c2ce;background:#fff;border-radius:6px;padding:7px 10px;color:#0f4c81;text-decoration:none;font-size:13px}",
    ".status{margin:0;padding:9px 18px;font-size:13px;border-bottom:1px solid #d7dde5}.good{background:#e9f7ef;color:#176137}.warn{background:#fff7dd;color:#7a4a00}",
    "iframe{display:block;width:100%;height:calc(100vh - 102px);border:0;background:#fff}",
    "</style>",
    "</head>",
    "<body>",
    "<header><div><h1>\{app_tool_html_escape(title)}</h1><div class=\"meta\">Portable app-tool bundle for \{app_tool_html_escape(book_id)}</div></div><nav class=\"actions\">\{links.join("")}</nav></header>",
    warning,
    "<iframe src=\"\{app_tool_html_escape(entrypoint)}\" title=\"\{app_tool_html_escape(title)}\"></iframe>",
    "</body>",
    "</html>",
    "",
  ].join("\n")
}

///|
fn app_tool_portable_readme(
  book_id : String,
  entrypoint : String,
  api_warnings : Array[String],
) -> String {
  let status = if api_warnings.length() == 0 {
    "No Moondesk API dependencies were detected in copied text assets."
  } else {
    "Copied text assets still reference Moondesk APIs: " +
    api_warnings.join(", ") +
    ". A standalone host should provide those APIs or the tool should be rebuilt as a pure static app."
  }
  [
    "# Portable App Tool Bundle",
    "",
    "- Book: `\{book_id}`",
    "- Entrypoint: `\{entrypoint}`",
    "- Runtime: static file bundle",
    "- Status: \{status}",
    "",
    "Open `index.html` from a native shell or static file host. The copied folder preserves the source book's relative paths so generated app assets and declared outputs can resolve without Moondesk.",
    "",
  ].join("\n")
}

///|
fn app_tool_html_escape(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
  .to_string()
}
