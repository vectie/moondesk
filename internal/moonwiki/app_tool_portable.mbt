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
    "portable-api-snapshot.json",
  )
}

///|
fn app_tool_portable_api_runtime_relative_path() -> String {
  @pathx.join(app_tool_portable_bundle_relative_dir(), "portable-runtime.js")
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
  let context = workspace_context(workspace_root)
  let book_root = app_tool_book_root_for_context(context, book_id)
  if !@fs.exists(@pathx.join(book_root, "book.json")) {
    send_api_error(conn, method_, 404, "Not Found", "Book not found")
    return
  }
  send_json(
    conn,
    method_,
    app_tool_portable_status(context.suite_root, book_root, book_id),
  )
}

///|
async fn handle_app_tool_portable_all_status(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let context = workspace_context(workspace_root)
  send_json(conn, method_, app_tool_portable_all_status_for_context(context))
}

///|
async fn handle_app_tool_portable_all_export(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let context = workspace_context(workspace_root)
  send_json(
    conn,
    method_,
    export_all_app_tool_portable_bundles_for_context(context),
  )
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
  let context = workspace_context(workspace_root)
  let book_root = app_tool_book_root_for_context(context, book_id)
  if !@fs.exists(@pathx.join(book_root, "book.json")) {
    send_api_error(conn, method_, 404, "Not Found", "Book not found")
    return
  }
  let result = export_app_tool_portable_bundle(
    context.suite_root,
    book_root,
    book_id,
  ) catch {
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
