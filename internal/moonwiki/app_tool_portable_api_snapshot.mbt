///|
async fn app_tool_portable_api_snapshot(
  root : String,
  book_id : String,
) -> Json {
  let routes = @desk.desktop_portable_api_snapshot_routes()
  let responses : Map[String, Json] = {}
  responses[@desk.workspaces_route()] = discover_workspaces(root).to_json()
  responses[@desk.books_route("patterns")] = Json::array(
    book_pattern_records_for_workspace(root),
  )
  responses[@desk.books_route("base-types")] = Json::array(
    book_base_type_records_for_workspace(root),
  )
  responses[@desk.books_route("template-registry")] = book_template_registry_status(
    root,
  )
  {
    "kind": "portable-app-tool-api-snapshot",
    "snapshot_version": "1",
    "book_id": book_id,
    "generated_at": @async.now().to_string(),
    "method": "GET",
    "route_contract_endpoint": @desk.desktop_capabilities_route(),
    "routes": json_from_string_array(routes),
    "supported_route_patterns": json_from_string_array(
      @desk.desktop_portable_api_supported_route_patterns(),
    ),
    "responses": Json::object(responses),
  }
}

///|
async fn app_tool_write_offline_api_snapshot(
  bundle_root : String,
  copied_paths : Array[String],
  api_dependency_paths : Array[String],
  api_snapshot : Json,
  api_offline_paths : Array[String],
  api_dependency_warnings : Array[String],
  api_unsupported_routes : Array[String],
) -> Unit {
  @fsx.write_to_file(
    @pathx.join(bundle_root, "portable-api-snapshot.json"),
    api_snapshot.stringify(indent=2) + "\n",
    create=0o644,
  )
  @fsx.write_to_file(
    @pathx.join(bundle_root, "portable-runtime.js"),
    app_tool_portable_api_runtime_js(api_snapshot),
    create=0o644,
  )
  app_tool_push_unique(copied_paths, "portable-api-snapshot.json")
  app_tool_push_unique(copied_paths, "portable-runtime.js")
  for relative in copied_paths {
    if relative.has_suffix(".html") {
      app_tool_inject_portable_runtime(bundle_root, relative, api_offline_paths)
    }
  }
  if api_dependency_paths.length() > 0 && api_offline_paths.length() == 0 {
    for relative in api_dependency_paths {
      app_tool_push_unique(api_dependency_warnings, relative)
    }
  } else {
    for relative in api_dependency_paths {
      let text = @fs.read_file(@pathx.join(bundle_root, relative)).text() catch {
        _ => continue
      }
      if app_tool_has_api_dependency_outside_portable_runtime_text(text) ||
        app_tool_has_unsupported_api_route_text(text, api_unsupported_routes) {
        app_tool_push_unique(api_dependency_warnings, relative)
      }
    }
  }
}

///|
fn app_tool_offline_api_mode(
  api_dependency_paths : Array[String],
  api_offline_paths : Array[String],
  api_dependency_warnings : Array[String],
) -> String {
  if api_dependency_warnings.length() > 0 {
    "unresolved-api-dependencies"
  } else if api_dependency_paths.length() > 0 || api_offline_paths.length() > 0 {
    "offline-snapshot-runtime"
  } else {
    "offline-snapshot"
  }
}
