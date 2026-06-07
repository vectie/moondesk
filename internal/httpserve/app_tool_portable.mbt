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
fn app_tool_portable_api_snapshot_relative_path() -> String {
  @pathx.join(
    app_tool_portable_bundle_relative_dir(),
    "moondesk-api-snapshot.json",
  )
}

///|
fn app_tool_portable_api_shim_relative_path() -> String {
  @pathx.join(app_tool_portable_bundle_relative_dir(), "moondesk-api-shim.js")
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
  let raw_book_id = decode_query_value(
      query_value(request_path, "book_id").unwrap_or(""),
    )
    .trim()
    .to_owned()
  let book_id = match app_tool_clean_book_id(raw_book_id) {
    Some(book_id) => book_id
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "book_id is required")
      return
    }
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
async fn handle_app_tool_portable_all_status(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  send_json(conn, method_, app_tool_portable_all_status(root))
}

///|
async fn handle_app_tool_portable_all_export(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  send_json(conn, method_, export_all_app_tool_portable_bundles(root))
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
  let raw_book_id = json_string(payload, "book_id", default="")
    .trim()
    .to_owned()
  let book_id = match app_tool_clean_book_id(raw_book_id) {
    Some(book_id) => book_id
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "book_id is required")
      return
    }
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
fn app_tool_books_root(root : String) -> String {
  @pathx.join(root, ".moontown/books")
}

///|
fn app_tool_book_root_for_id(root : String, book_id : String) -> String {
  @pathx.join(app_tool_books_root(root), book_id)
}

///|
fn app_tool_clean_book_id(book_id : String) -> String? {
  let trimmed = book_id.trim().to_owned()
  if trimmed == "" {
    return None
  }
  match clean_relative_path(trimmed) {
    Some(path) =>
      if path != "" && !path.contains("/") {
        Some(path)
      } else {
        None
      }
    None => None
  }
}

///|
async fn app_tool_book_ids_for_workspace(root : String) -> Array[String] {
  let book_ids : Array[String] = []
  let books_root = app_tool_books_root(root)
  if !is_directory(books_root) {
    return book_ids
  }
  for name in read_directory_names(books_root, include_hidden=false) {
    let book_id = match app_tool_clean_book_id(name) {
      Some(book_id) => book_id
      None => continue
    }
    let book_root = app_tool_book_root_for_id(root, book_id)
    if !is_directory(book_root) ||
      !@fs.exists(@pathx.join(book_root, "book.json")) {
      continue
    }
    let book_json = read_json_file_or_object(
      @pathx.join(book_root, "book.json"),
    )
    let manifest = read_json_file_or_object(
      @pathx.join(book_root, app_tool_manifest_relative_path(book_json)),
    )
    if app_tool_book_is_app_tool(book_json, manifest) {
      book_ids.push(book_id)
    }
  }
  book_ids
}

///|
async fn app_tool_portable_all_status(root : String) -> Json {
  let book_ids = app_tool_book_ids_for_workspace(root)
  let books : Array[Json] = []
  let mut portable_ready_count = 0
  let mut api_warning_count = 0
  let mut export_required_count = 0
  let mut missing_entrypoint_count = 0
  let mut unsupported_entrypoint_count = 0
  for book_id in book_ids {
    let status = app_tool_portable_status(
      root,
      app_tool_book_root_for_id(root, book_id),
      book_id,
    )
    books.push(status)
    match json_string(status, "status", default="unknown") {
      "portable_ready" => portable_ready_count += 1
      "portable_with_api_warnings" => api_warning_count += 1
      "export_required" => export_required_count += 1
      "missing_entrypoint" => missing_entrypoint_count += 1
      "unsupported_entrypoint" => unsupported_entrypoint_count += 1
      _ => ()
    }
  }
  let overall_status = app_tool_portable_all_status_label(
    book_ids.length(),
    portable_ready_count,
    api_warning_count,
    export_required_count,
    missing_entrypoint_count,
    unsupported_entrypoint_count,
  )
  {
    "kind": "moondesk-app-tool-portable-all-status",
    "ok": missing_entrypoint_count == 0,
    "status": overall_status,
    "message": app_tool_portable_all_status_message(overall_status),
    "workspace_root": root,
    "app_tool_book_count": book_ids.length(),
    "book_ids": json_from_string_array(book_ids),
    "portable_ready_count": portable_ready_count,
    "api_warning_count": api_warning_count,
    "export_required_count": export_required_count,
    "missing_entrypoint_count": missing_entrypoint_count,
    "unsupported_entrypoint_count": unsupported_entrypoint_count,
    "portable_bundle_path": app_tool_portable_bundle_relative_dir(),
    "standalone_runtime": "static-file-bundle",
    "operatable_without_moondesk_api": book_ids.length() > 0 &&
    export_required_count == 0 &&
    missing_entrypoint_count == 0 &&
    unsupported_entrypoint_count == 0 &&
    api_warning_count == 0,
    "books": Json::array(books),
  }
}

///|
async fn export_all_app_tool_portable_bundles(root : String) -> Json {
  let book_ids = app_tool_book_ids_for_workspace(root)
  let results : Array[Json] = []
  let mut exported_count = 0
  let mut failure_count = 0
  let mut api_warning_count = 0
  for book_id in book_ids {
    let book_root = app_tool_book_root_for_id(root, book_id)
    let result = export_app_tool_portable_bundle(root, book_root, book_id) catch {
      error => {
        failure_count += 1
        results.push({
          "kind": "moondesk-app-tool-portable-export",
          "ok": false,
          "status": "export_failed",
          "message": "Could not export app-tool portable bundle: \{error}",
          "book_id": book_id,
        })
        continue
      }
    }
    results.push(result)
    if json_bool(result, "ok", default=false) {
      exported_count += 1
      if json_string(result, "status", default="") ==
        "portable_with_api_warnings" {
        api_warning_count += 1
      }
    } else {
      failure_count += 1
    }
  }
  let status = app_tool_portable_all_export_status_label(
    book_ids.length(),
    failure_count,
    api_warning_count,
  )
  {
    "kind": "moondesk-app-tool-portable-all-export",
    "ok": failure_count == 0,
    "status": status,
    "message": app_tool_portable_all_status_message(status),
    "workspace_root": root,
    "app_tool_book_count": book_ids.length(),
    "book_ids": json_from_string_array(book_ids),
    "exported_count": exported_count,
    "failure_count": failure_count,
    "api_warning_count": api_warning_count,
    "portable_bundle_path": app_tool_portable_bundle_relative_dir(),
    "standalone_runtime": "static-file-bundle",
    "operatable_without_moondesk_api": book_ids.length() > 0 &&
    failure_count == 0 &&
    api_warning_count == 0,
    "books": Json::array(results),
  }
}

///|
fn app_tool_portable_all_status_label(
  book_count : Int,
  portable_ready_count : Int,
  api_warning_count : Int,
  export_required_count : Int,
  missing_entrypoint_count : Int,
  unsupported_entrypoint_count : Int,
) -> String {
  if book_count == 0 {
    "no_app_tool_books"
  } else if missing_entrypoint_count > 0 {
    "missing_entrypoint"
  } else if unsupported_entrypoint_count > 0 {
    "unsupported_entrypoint"
  } else if export_required_count > 0 {
    "export_required"
  } else if api_warning_count > 0 {
    "portable_with_api_warnings"
  } else if portable_ready_count == book_count {
    "portable_ready"
  } else {
    "unknown"
  }
}

///|
fn app_tool_portable_all_export_status_label(
  book_count : Int,
  failure_count : Int,
  api_warning_count : Int,
) -> String {
  if book_count == 0 {
    "no_app_tool_books"
  } else if failure_count > 0 {
    "partial_failure"
  } else if api_warning_count > 0 {
    "portable_with_api_warnings"
  } else {
    "portable_ready"
  }
}

///|
fn app_tool_portable_all_status_message(status : String) -> String {
  match status {
    "no_app_tool_books" =>
      "No app-tool MoonBooks were discovered in this workspace."
    "missing_entrypoint" =>
      "One or more app-tool MoonBooks declare metadata but have no existing entrypoint."
    "unsupported_entrypoint" =>
      "One or more app-tool MoonBooks have existing entrypoints, but none are HTML app screens that a portable standalone shell can open."
    "export_required" =>
      "One or more app-tool MoonBooks are exportable but do not have a generated portable bundle yet."
    "portable_ready" =>
      "Every discovered app-tool MoonBook has a portable bundle with no detected Moondesk API dependency."
    "portable_with_api_warnings" =>
      "Every discovered app-tool MoonBook was exported, but at least one copied asset still references Moondesk APIs."
    "partial_failure" => "Some app-tool MoonBooks could not be exported."
    _ => "Unknown app-tool portable workspace status."
  }
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
  let html_entrypoints : Array[String] = []
  let missing_entrypoints : Array[String] = []
  for entrypoint in entrypoints {
    let absolute = @pathx.join(book_root, entrypoint)
    if @fs.exists(absolute) && !is_directory(absolute) {
      existing_entrypoints.push(entrypoint)
      if app_tool_entrypoint_is_html(entrypoint) {
        html_entrypoints.push(entrypoint)
      }
    } else {
      missing_entrypoints.push(entrypoint)
    }
  }
  let entrypoint = if html_entrypoints.length() > 0 {
    html_entrypoints[0]
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
    app_tool_entrypoint_is_html(portable_entrypoint) &&
    @fs.exists(@pathx.join(bundle_root, portable_entrypoint)) &&
    !is_directory(@pathx.join(bundle_root, portable_entrypoint))
  let portable_ready = is_app_tool &&
    html_entrypoints.length() > 0 &&
    @fs.exists(@pathx.join(book_root, app_tool_portable_index_relative_path())) &&
    @fs.exists(portable_manifest_path) &&
    portable_entrypoint_ready
  let api_warnings = json_string_array_items(
    portable_manifest, "api_dependency_warnings",
  )
  let api_dependency_paths = json_string_array_items(
    portable_manifest, "api_dependency_paths",
  )
  let api_compatibility_paths = json_string_array_items(
    portable_manifest, "api_compatibility_paths",
  )
  let api_snapshot_routes = json_string_array_items(
    portable_manifest, "api_snapshot_routes",
  )
  let api_reference_routes = json_string_array_items(
    portable_manifest, "api_reference_routes",
  )
  let api_unsupported_routes = json_string_array_items(
    portable_manifest, "api_unsupported_routes",
  )
  let api_compatibility_mode = json_string(
    portable_manifest,
    "api_compatibility_mode",
    default=if api_dependency_paths.length() > 0 ||
      api_compatibility_paths.length() > 0 {
      "offline-snapshot-fetch-shim"
    } else {
      "none"
    },
  )
  let status = if !is_app_tool {
    "not_app_tool"
  } else if existing_entrypoints.length() == 0 {
    "missing_entrypoint"
  } else if html_entrypoints.length() == 0 {
    "unsupported_entrypoint"
  } else if portable_ready && api_warnings.length() == 0 {
    "portable_ready"
  } else if portable_ready {
    "portable_with_api_warnings"
  } else {
    "export_required"
  }
  {
    "kind": "moondesk-app-tool-portable-status",
    "ok": is_app_tool && html_entrypoints.length() > 0,
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
    "html_entrypoints": json_from_string_array(html_entrypoints),
    "missing_entrypoints": json_from_string_array(missing_entrypoints),
    "portable_ready": portable_ready,
    "portable_bundle_path": app_tool_portable_bundle_relative_dir(),
    "portable_index_path": app_tool_portable_index_relative_path(),
    "portable_manifest_path": app_tool_portable_manifest_relative_path(),
    "api_snapshot_path": app_tool_portable_api_snapshot_relative_path(),
    "api_shim_path": app_tool_portable_api_shim_relative_path(),
    "standalone_runtime": "static-file-bundle",
    "operatable_without_moondesk_api": portable_ready &&
    api_warnings.length() == 0,
    "api_compatibility_mode": api_compatibility_mode,
    "api_dependency_paths": json_from_string_array(api_dependency_paths),
    "api_compatibility_paths": json_from_string_array(api_compatibility_paths),
    "api_snapshot_routes": json_from_string_array(api_snapshot_routes),
    "api_reference_routes": json_from_string_array(api_reference_routes),
    "api_unsupported_routes": json_from_string_array(api_unsupported_routes),
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
    "unsupported_entrypoint" =>
      "Book declares app-tool metadata and has existing entrypoints, but none are HTML files suitable for the portable iframe shell."
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
  root : String,
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
  let html_entrypoints : Array[String] = []
  for entrypoint in entrypoints {
    let absolute = @pathx.join(book_root, entrypoint)
    if @fs.exists(absolute) && !is_directory(absolute) {
      existing_entrypoints.push(entrypoint)
      if app_tool_entrypoint_is_html(entrypoint) {
        html_entrypoints.push(entrypoint)
      }
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
  if html_entrypoints.length() == 0 {
    return {
      "kind": "moondesk-app-tool-portable-export",
      "ok": false,
      "status": "unsupported_entrypoint",
      "message": app_tool_portable_status_message("unsupported_entrypoint"),
      "book_id": book_id,
      "entrypoints": json_from_string_array(entrypoints),
      "existing_entrypoints": json_from_string_array(existing_entrypoints),
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
  let api_dependency_paths = app_tool_portable_api_dependency_paths(
    bundle_root, copied_paths,
  )
  let api_reference_routes = app_tool_portable_api_reference_routes(
    bundle_root, copied_paths,
  )
  let api_compatibility_paths : Array[String] = []
  let api_dependency_warnings : Array[String] = []
  let api_snapshot_routes = app_tool_portable_api_snapshot_routes()
  let api_unsupported_routes = app_tool_portable_api_unsupported_routes(
    api_reference_routes, api_snapshot_routes,
  )
  let api_snapshot = app_tool_portable_api_snapshot(root, book_id)
  app_tool_write_api_compatibility(
    bundle_root, copied_paths, api_dependency_paths, api_snapshot, api_compatibility_paths,
    api_dependency_warnings, api_unsupported_routes,
  )
  let entrypoint = html_entrypoints[0]
  let title = app_tool_title(book_json, manifest, book_id)
  let index_html = app_tool_portable_index_html(
    book_id, title, entrypoint, existing_entrypoints, api_dependency_warnings, api_compatibility_paths,
  )
  @fsx.write_to_file(
    @pathx.join(bundle_root, "index.html"),
    index_html,
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(bundle_root, "README.md"),
    app_tool_portable_readme(
      book_id, entrypoint, api_dependency_warnings, api_compatibility_paths,
    ),
    create=0o644,
  )
  let export_record : Json = {
    "kind": "moondesk-app-tool-portable-bundle",
    "portable_version": "1",
    "ok": true,
    "status": if api_dependency_warnings.length() == 0 {
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
    "api_snapshot_path": app_tool_portable_api_snapshot_relative_path(),
    "api_shim_path": app_tool_portable_api_shim_relative_path(),
    "entrypoint": entrypoint,
    "entrypoints": json_from_string_array(existing_entrypoints),
    "html_entrypoints": json_from_string_array(html_entrypoints),
    "copied_paths": json_from_string_array(copied_paths),
    "missing_paths": json_from_string_array(missing_paths),
    "skipped_paths": json_from_string_array(skipped_paths),
    "api_compatibility_mode": app_tool_api_compatibility_mode(
      api_dependency_paths, api_compatibility_paths, api_dependency_warnings,
    ),
    "api_dependency_paths": json_from_string_array(api_dependency_paths),
    "api_compatibility_paths": json_from_string_array(api_compatibility_paths),
    "api_snapshot_routes": json_from_string_array(api_snapshot_routes),
    "api_reference_routes": json_from_string_array(api_reference_routes),
    "api_unsupported_routes": json_from_string_array(api_unsupported_routes),
    "api_dependency_warnings": json_from_string_array(api_dependency_warnings),
    "standalone_runtime": "static-file-bundle",
    "operatable_without_moondesk_api": api_dependency_warnings.length() == 0,
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
fn app_tool_entrypoint_is_html(entrypoint : String) -> Bool {
  let lower = entrypoint.to_lower()
  lower.has_suffix(".html") || lower.has_suffix(".htm")
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
async fn app_tool_portable_api_dependency_paths(
  bundle_root : String,
  copied_paths : Array[String],
) -> Array[String] {
  let paths : Array[String] = []
  for relative in copied_paths {
    if !app_tool_scan_text_asset(relative) ||
      relative == "moondesk-api-shim.js" ||
      relative == "moondesk-api-snapshot.json" {
      continue
    }
    let text = @fs.read_file(@pathx.join(bundle_root, relative)).text() catch {
      _ => continue
    }
    if app_tool_has_api_dependency_text(text) {
      app_tool_push_unique(paths, relative)
    }
  }
  paths
}

///|
async fn app_tool_portable_api_reference_routes(
  bundle_root : String,
  copied_paths : Array[String],
) -> Array[String] {
  let routes : Array[String] = []
  for relative in copied_paths {
    if !app_tool_scan_text_asset(relative) ||
      relative == "moondesk-api-shim.js" ||
      relative == "moondesk-api-snapshot.json" {
      continue
    }
    let text = @fs.read_file(@pathx.join(bundle_root, relative)).text() catch {
      _ => continue
    }
    for route in app_tool_api_reference_routes_from_text(text) {
      app_tool_push_unique(routes, route)
    }
  }
  routes
}

///|
fn app_tool_api_reference_routes_from_text(text : String) -> Array[String] {
  let routes : Array[String] = []
  let mut tail = text
  while true {
    match tail.find("/api/") {
      Some(index) => {
        let candidate = tail[index:].to_owned()
        let route = app_tool_take_api_reference_route(candidate)
        if route != "" {
          app_tool_push_unique(routes, route)
        }
        let next_start = index + "/api/".length()
        if next_start >= tail.length() {
          break
        }
        tail = tail[next_start:].to_owned()
      }
      None => break
    }
  }
  routes
}

///|
fn app_tool_take_api_reference_route(text : String) -> String {
  let mut end = text.length()
  for
    delimiter in [
      "\"", "'", "`", " ", "\n", "\r", "\t", "<", ">", ")", "(", ",", ";", "]", "[",
      "{", "}",
    ] {
    match text.find(delimiter) {
      Some(index) if index > 0 && index < end => end = index
      _ => ()
    }
  }
  text[:end].to_owned()
}

///|
fn app_tool_portable_api_unsupported_routes(
  api_reference_routes : Array[String],
  api_snapshot_routes : Array[String],
) -> Array[String] {
  let unsupported : Array[String] = []
  for route in api_reference_routes {
    if !app_tool_api_route_is_supported(route, api_snapshot_routes) {
      app_tool_push_unique(unsupported, route)
    }
  }
  unsupported
}

///|
fn app_tool_api_route_is_supported(
  route : String,
  api_snapshot_routes : Array[String],
) -> Bool {
  for supported in api_snapshot_routes {
    if route == supported ||
      route.has_prefix(supported + "?") ||
      route.has_prefix(supported + "#") {
      return true
    }
  }
  false
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
fn app_tool_has_api_dependency_text(text : String) -> Bool {
  text.contains("/api/") ||
  text.contains("http://127.0.0.1") ||
  text.contains("http://localhost") ||
  text.contains("https://localhost")
}

///|
fn app_tool_portable_api_snapshot_routes() -> Array[String] {
  [
    "/api/workspaces", "/api/books/patterns", "/api/books/base-types", "/api/books/template-registry",
  ]
}

///|
async fn app_tool_portable_api_snapshot(
  root : String,
  book_id : String,
) -> Json {
  let responses : Map[String, Json] = {}
  responses["/api/workspaces"] = discover_workspaces(root).to_json()
  responses["/api/books/patterns"] = Json::array(
    book_pattern_records_for_workspace(root),
  )
  responses["/api/books/base-types"] = Json::array(
    book_base_type_records_for_workspace(root),
  )
  responses["/api/books/template-registry"] = book_template_registry_status(
    root,
  )
  {
    "kind": "moondesk-app-tool-api-snapshot",
    "snapshot_version": "1",
    "book_id": book_id,
    "generated_at": @async.now().to_string(),
    "method": "GET",
    "routes": json_from_string_array(app_tool_portable_api_snapshot_routes()),
    "responses": Json::object(responses),
  }
}

///|
async fn app_tool_write_api_compatibility(
  bundle_root : String,
  copied_paths : Array[String],
  api_dependency_paths : Array[String],
  api_snapshot : Json,
  api_compatibility_paths : Array[String],
  api_dependency_warnings : Array[String],
  api_unsupported_routes : Array[String],
) -> Unit {
  @fsx.write_to_file(
    @pathx.join(bundle_root, "moondesk-api-snapshot.json"),
    api_snapshot.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(bundle_root, "moondesk-api-shim.js"),
    app_tool_portable_api_shim_js(api_snapshot),
    create=0o644,
  )
  app_tool_push_unique(copied_paths, "moondesk-api-snapshot.json")
  app_tool_push_unique(copied_paths, "moondesk-api-shim.js")
  for relative in copied_paths {
    if relative.has_suffix(".html") {
      app_tool_inject_api_shim(bundle_root, relative, api_compatibility_paths)
    }
  }
  if api_dependency_paths.length() > 0 && api_compatibility_paths.length() == 0 {
    for relative in api_dependency_paths {
      app_tool_push_unique(api_dependency_warnings, relative)
    }
  } else {
    for relative in api_dependency_paths {
      let text = @fs.read_file(@pathx.join(bundle_root, relative)).text() catch {
        _ => continue
      }
      if app_tool_has_unshimmable_api_dependency_text(text) ||
        app_tool_has_unsupported_api_route_text(text, api_unsupported_routes) {
        app_tool_push_unique(api_dependency_warnings, relative)
      }
    }
  }
}

///|
fn app_tool_api_compatibility_mode(
  api_dependency_paths : Array[String],
  api_compatibility_paths : Array[String],
  api_dependency_warnings : Array[String],
) -> String {
  if api_dependency_warnings.length() > 0 {
    "unresolved-api-dependencies"
  } else if api_dependency_paths.length() > 0 ||
    api_compatibility_paths.length() > 0 {
    "offline-snapshot-fetch-shim"
  } else {
    "offline-snapshot"
  }
}

///|
fn app_tool_has_unshimmable_api_dependency_text(text : String) -> Bool {
  let lower = text.to_lower()
  lower.contains("href=\"/api") ||
  lower.contains("href='/api") ||
  lower.contains("src=\"/api") ||
  lower.contains("src='/api") ||
  lower.contains("action=\"/api") ||
  lower.contains("action='/api") ||
  lower.contains("url(/api") ||
  lower.contains("url('/api") ||
  lower.contains("url(\"/api")
}

///|
fn app_tool_has_unsupported_api_route_text(
  text : String,
  api_unsupported_routes : Array[String],
) -> Bool {
  for route in api_unsupported_routes {
    if text.contains(route) {
      return true
    }
  }
  false
}

///|
async fn app_tool_inject_api_shim(
  bundle_root : String,
  relative : String,
  api_compatibility_paths : Array[String],
) -> Unit {
  let path = @pathx.join(bundle_root, relative)
  let html = @fs.read_file(path).text() catch { _ => return }
  let injected = app_tool_inject_html_shim(
    html,
    app_tool_api_shim_src_for_relative(relative),
  )
  if injected != html {
    @fsx.write_to_file(path, injected, create=0o644) catch {
      _ => return
    }
  }
  app_tool_push_unique(api_compatibility_paths, relative)
}

///|
fn app_tool_api_shim_src_for_relative(relative : String) -> String {
  let pieces = relative.split("/").to_array()
  let mut depth = if pieces.length() > 0 { pieces.length() - 1 } else { 0 }
  let prefixes : Array[String] = []
  while depth > 0 {
    prefixes.push("..")
    depth -= 1
  }
  if prefixes.length() == 0 {
    "./moondesk-api-shim.js"
  } else {
    prefixes.join("/") + "/moondesk-api-shim.js"
  }
}

///|
fn app_tool_inject_html_shim(html : String, shim_src : String) -> String {
  if html.contains("moondesk-api-shim.js") {
    return html
  }
  let tag = "<script src=\"\{app_tool_html_escape(shim_src)}\" data-moondesk-api-shim></script>\n"
  let lower = html.to_lower()
  match lower.find("<script") {
    Some(index) => html[:index].to_owned() + tag + html[index:].to_owned()
    None =>
      match lower.find("</head>") {
        Some(index) => html[:index].to_owned() + tag + html[index:].to_owned()
        None =>
          match lower.find("<body") {
            Some(index) =>
              html[:index].to_owned() + tag + html[index:].to_owned()
            None => tag + html
          }
      }
  }
}

///|
fn app_tool_portable_api_shim_js(api_snapshot : Json) -> String {
  [
    "(function () {",
    "  'use strict';",
    "  const snapshot = \{api_snapshot.stringify(indent=2)};",
    "  const responses = snapshot.responses || {};",
    "  const originalFetch = typeof window.fetch === 'function' ? window.fetch.bind(window) : null;",
    "  function apiKey(input) {",
    "    const raw = typeof input === 'string' ? input : input && input.url;",
    "    if (!raw) return '';",
    "    try {",
    "      const url = new URL(raw, window.location.href);",
    "      if (url.pathname && url.pathname.indexOf('/api/') === 0) return url.pathname + url.search;",
    "    } catch (_) {",
    "      if (raw.indexOf('/api/') === 0) return raw;",
    "    }",
    "    return raw.indexOf('/api/') === 0 ? raw : '';",
    "  }",
    "  function jsonResponse(value, status) {",
    "    return new Response(JSON.stringify(value), {",
    "      status: status || 200,",
    "      headers: { 'content-type': 'application/json; charset=utf-8', 'x-moondesk-api-snapshot': 'true' }",
    "    });",
    "  }",
    "  window.__MOONDESK_API_SNAPSHOT__ = snapshot;",
    "  window.fetch = function (input, init) {",
    "    const method = ((init && init.method) || (input && input.method) || 'GET').toUpperCase();",
    "    const key = apiKey(input);",
    "    const pathKey = key && key.split('?')[0];",
    "    if (method === 'GET' && key && Object.prototype.hasOwnProperty.call(responses, key)) {",
    "      return Promise.resolve(jsonResponse(responses[key], 200));",
    "    }",
    "    if (method === 'GET' && pathKey && Object.prototype.hasOwnProperty.call(responses, pathKey)) {",
    "      return Promise.resolve(jsonResponse(responses[pathKey], 200));",
    "    }",
    "    if (method === 'GET' && key && key.indexOf('/api/') === 0) {",
    "      return Promise.resolve(jsonResponse({ ok: false, status: 'offline_snapshot_miss', route: key, message: 'This portable app-tool bundle does not include a snapshot for the requested Moondesk API route.' }, 404));",
    "    }",
    "    if (originalFetch) return originalFetch(input, init);",
    "    return Promise.reject(new TypeError('fetch is unavailable and no Moondesk API snapshot route matched.'));",
    "  };",
    "}());",
    "",
  ].join("\n")
}

///|
fn app_tool_portable_index_html(
  book_id : String,
  title : String,
  entrypoint : String,
  entrypoints : Array[String],
  api_warnings : Array[String],
  api_compatibility_paths : Array[String],
) -> String {
  let links : Array[String] = []
  for item in entrypoints {
    links.push(
      "<a class=\"entry-link\" href=\"\{app_tool_html_escape(item)}\">\{app_tool_html_escape(item)}</a>",
    )
  }
  let warning = if api_warnings.length() == 0 {
    if api_compatibility_paths.length() == 0 {
      "<p class=\"status good\">Standalone-ready: copied app assets are bundled for static hosting.</p>"
    } else {
      "<p class=\"status good\">Standalone-ready: copied app assets include an offline Moondesk API snapshot shim.</p>"
    }
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
  api_compatibility_paths : Array[String],
) -> String {
  let status = if api_warnings.length() == 0 {
    if api_compatibility_paths.length() == 0 {
      "Copied app assets are bundled for static hosting."
    } else {
      "Copied app assets include `moondesk-api-snapshot.json` and `moondesk-api-shim.js`, which serve supported read-only Moondesk API calls from the bundle."
    }
  } else {
    "Copied text assets still reference Moondesk APIs: " +
    api_warnings.join(", ") +
    ". A standalone host should provide those APIs or the tool should avoid resource links that bypass the bundled fetch shim."
  }
  [
    "# Portable App Tool Bundle",
    "",
    "- Book: `\{book_id}`",
    "- Entrypoint: `\{entrypoint}`",
    "- Runtime: static file bundle",
    "- Status: \{status}",
    "- API shim: `moondesk-api-shim.js`",
    "- API snapshot: `moondesk-api-snapshot.json`",
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
