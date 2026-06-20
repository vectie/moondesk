///|
async fn app_tool_portable_api_dependency_paths(
  bundle_root : String,
  copied_paths : Array[String],
) -> Array[String] {
  let paths : Array[String] = []
  for relative in copied_paths {
    if !app_tool_scan_text_asset(relative) ||
      relative == "portable-runtime.js" ||
      relative == "portable-api-snapshot.json" {
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
      relative == "portable-runtime.js" ||
      relative == "portable-api-snapshot.json" {
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
  if app_tool_workspace_file_api_route_is_supported(route) {
    return true
  }
  false
}

///|
fn app_tool_workspace_file_api_route_is_supported(route : String) -> Bool {
  if !route.has_prefix("/api/workspaces/") {
    return false
  }
  route.contains("/raw?path=") ||
  route.contains("/preview?path=") ||
  route.contains("/entries?path=") ||
  route.contains("/file/") ||
  route.contains("/site/")
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
