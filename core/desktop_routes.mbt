///|
pub fn desktop_api_url(
  segments : Array[String],
  query? : Array[(String, String)] = [],
) -> String {
  let path = desktop_api_path(segments)
  if query.length() == 0 {
    path
  } else {
    path + "?" + desktop_api_query(query)
  }
}

///|
pub fn desktop_api_path(segments : Array[String]) -> String {
  let encoded : Array[String] = []
  for segment in segments {
    encoded.push(url_component(segment))
  }
  "/" + encoded.join("/")
}

///|
pub fn desktop_api_query(query : Array[(String, String)]) -> String {
  let fields : Array[String] = []
  for field in query {
    let (key, value) = field
    fields.push(url_component(key) + "=" + url_component(value))
  }
  fields.join("&")
}

///|
pub fn url_path(value : String) -> String {
  let encoded : Array[String] = []
  for segment in value.split("/") {
    encoded.push(url_component(segment.to_owned()))
  }
  encoded.join("/")
}

///|
pub(all) struct DesktopApiRouteContract {
  path : String
  methods : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct DesktopApiCapabilities {
  component : String
  kind : String
  version : Int
  route_contract_endpoint : String
  required_endpoints : Array[String]
  desktop_route_contracts : Array[DesktopApiRouteContract]
  portable_api_snapshot_routes : Array[String]
  portable_api_workspace_content_routes : Array[String]
  portable_api_supported_route_patterns : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

///|
fn desktop_api_route_contract(
  path : String,
  methods : Array[String],
) -> DesktopApiRouteContract {
  { path, methods }
}

///|
fn desktop_api_contract_path(endpoint : String) -> String {
  let parts = endpoint.split("?").to_array()
  if parts.length() > 0 {
    parts[0].to_owned()
  } else {
    endpoint
  }
}

///|
pub fn desktop_capabilities_url() -> String {
  desktop_api_url(["api", "desktop", "capabilities"])
}

///|
pub fn desktop_capabilities_route() -> String {
  desktop_api_path(["api", "desktop", "capabilities"])
}

///|
pub fn workspaces_url() -> String {
  desktop_api_url(["api", "workspaces"])
}

///|
pub fn workspaces_route() -> String {
  desktop_api_path(["api", "workspaces"])
}

///|
pub fn workspace_metadata_url() -> String {
  desktop_api_url(["api", "workspaces", "metadata"])
}

///|
pub fn workspace_metadata_route() -> String {
  desktop_api_path(["api", "workspaces", "metadata"])
}

///|
pub fn workspace_import_url() -> String {
  desktop_api_url(["api", "workspaces", "import"])
}

///|
pub fn workspace_import_route() -> String {
  desktop_api_path(["api", "workspaces", "import"])
}

///|
pub fn workspace_action_route(action : String) -> String {
  desktop_api_path(["api", "workspaces"]) +
  "/<workspace-id>/" +
  url_path(action)
}

///|
pub fn workspace_endpoint_url(
  workspace_id : String,
  endpoint : String,
) -> String {
  desktop_api_url(["api", "workspaces", workspace_id, endpoint])
}

///|
pub fn workspace_entries_url(workspace_id : String, path : String) -> String {
  desktop_api_url(["api", "workspaces", workspace_id, "entries"], query=[
    ("path", path),
  ])
}

///|
pub fn workspace_preview_url(workspace_id : String, path : String) -> String {
  desktop_api_url(["api", "workspaces", workspace_id, "preview"], query=[
    ("path", path),
  ])
}

///|
pub fn workspace_raw_url(workspace_id : String, path : String) -> String {
  desktop_api_url(["api", "workspaces", workspace_id, "raw"], query=[
    ("path", path),
  ])
}

///|
pub fn workspace_file_url(workspace_id : String, path : String) -> String {
  desktop_api_path(["api", "workspaces", workspace_id, "file"]) +
  "/" +
  url_path(path)
}

///|
pub fn workspace_file_route() -> String {
  desktop_api_path(["api", "workspaces"]) + "/<workspace-id>/file/<path>"
}

///|
pub fn workspace_site_route() -> String {
  desktop_api_path(["api", "workspaces"]) + "/<workspace-id>/site/<path>"
}

///|
pub fn moonclaw_endpoint_url(endpoint : String) -> String {
  desktop_api_path(["api", "moonclaw"]) + "/" + url_path(endpoint)
}

///|
pub fn moonclaw_route(endpoint : String) -> String {
  desktop_api_path(["api", "moonclaw"]) + "/" + url_path(endpoint)
}

///|
pub fn moonclaw_run_artifacts_route() -> String {
  desktop_api_path(["api", "moonclaw"]) + "/runs/<run-id>/artifacts"
}

///|
pub fn moonclaw_workspace_url(
  endpoint : String,
  workspace_id : String,
) -> String {
  desktop_api_url(["api", "moonclaw", endpoint], query=[
    ("workspace", workspace_id),
  ])
}

///|
pub fn review_items_url(workspace_id : String) -> String {
  desktop_api_url(["api", "review", "items"], query=[
    ("workspace", workspace_id),
  ])
}

///|
pub fn review_items_route() -> String {
  desktop_api_path(["api", "review", "items"])
}

///|
pub fn review_decision_url() -> String {
  desktop_api_url(["api", "review", "items", "decision"])
}

///|
pub fn review_decision_route() -> String {
  desktop_api_path(["api", "review", "items", "decision"])
}

///|
pub fn search_url(query : String) -> String {
  desktop_api_url(["api", "search"], query=[("query", query)])
}

///|
pub fn search_route() -> String {
  desktop_api_path(["api", "search"])
}

///|
pub fn town_endpoint_url(endpoint : String) -> String {
  desktop_api_path(["api", "town"]) + "/" + url_path(endpoint)
}

///|
pub fn town_route(endpoint : String) -> String {
  desktop_api_path(["api", "town"]) + "/" + url_path(endpoint)
}

///|
pub fn town_calendar_url() -> String {
  town_endpoint_url("calendar.ics")
}

///|
pub fn preferences_views_url() -> String {
  desktop_api_url(["api", "preferences", "views"])
}

///|
pub fn preferences_views_route() -> String {
  desktop_api_path(["api", "preferences", "views"])
}

///|
pub fn preferences_tags_route() -> String {
  desktop_api_path(["api", "preferences", "tags"])
}

///|
pub fn books_endpoint_url(endpoint : String) -> String {
  desktop_api_path(["api", "books"]) + "/" + url_path(endpoint)
}

///|
pub fn books_route(endpoint : String) -> String {
  desktop_api_path(["api", "books"]) + "/" + url_path(endpoint)
}

///|
pub fn desktop_portable_api_snapshot_routes() -> Array[String] {
  [
    workspaces_route(),
    books_route("patterns"),
    books_route("base-types"),
    books_route("template-registry"),
  ]
}

///|
pub fn desktop_portable_api_workspace_content_routes() -> Array[String] {
  [
    workspace_action_route("entries"),
    workspace_action_route("preview"),
    workspace_action_route("raw"),
    workspace_file_route(),
    workspace_site_route(),
  ]
}

///|
pub fn desktop_portable_api_supported_route_patterns() -> Array[String] {
  let routes : Array[String] = []
  for route in desktop_portable_api_snapshot_routes() {
    routes.push(route)
  }
  for route in desktop_portable_api_workspace_content_routes() {
    routes.push(route)
  }
  routes
}

///|
pub fn desktop_portable_api_route_supported(route : String) -> Bool {
  desktop_portable_api_static_route_supported(route) ||
  desktop_portable_api_workspace_content_route_supported(route)
}

///|
fn desktop_portable_api_static_route_supported(route : String) -> Bool {
  for supported in desktop_portable_api_snapshot_routes() {
    if route == supported ||
      route == supported + "/" ||
      route.has_prefix(supported + "?") ||
      route.has_prefix(supported + "/?") ||
      route.has_prefix(supported + "#") {
      return true
    }
  }
  false
}

///|
fn desktop_portable_api_workspace_content_route_supported(
  route : String,
) -> Bool {
  let workspace_prefix = workspaces_route() + "/"
  if !route.has_prefix(workspace_prefix) {
    return false
  }
  let tail = route[workspace_prefix.length():].to_owned()
  match tail.find("/") {
    Some(index) if index + 1 < tail.length() => {
      let action_tail = tail[index + 1:].to_owned()
      action_tail.has_prefix("entries?path=") ||
      action_tail.has_prefix("preview?path=") ||
      action_tail.has_prefix("raw?path=") ||
      action_tail.has_prefix("file/") ||
      action_tail.has_prefix("site/")
    }
    _ => false
  }
}

///|
pub fn desktop_api_route_contracts() -> Array[DesktopApiRouteContract] {
  [
    desktop_api_route_contract(desktop_capabilities_route(), ["GET", "HEAD"]),
    desktop_api_route_contract(workspaces_route(), ["GET", "HEAD", "POST"]),
    desktop_api_route_contract(workspace_metadata_route(), ["GET", "HEAD"]),
    desktop_api_route_contract(workspace_import_route(), ["POST"]),
    desktop_api_route_contract(workspace_action_route("entries"), [
      "GET", "HEAD", "POST",
    ]),
    desktop_api_route_contract(workspace_action_route("entries/import"), [
      "POST",
    ]),
    desktop_api_route_contract(workspace_action_route("preview"), [
      "GET", "HEAD",
    ]),
    desktop_api_route_contract(workspace_action_route("raw"), ["GET", "HEAD"]),
    desktop_api_route_contract(workspace_file_route(), ["GET", "HEAD"]),
    desktop_api_route_contract(workspace_site_route(), ["GET", "HEAD"]),
    desktop_api_route_contract(workspace_action_route("inbox"), ["POST"]),
    desktop_api_route_contract(workspace_action_route("markdown"), ["POST"]),
    desktop_api_route_contract(workspace_action_route("rename"), ["POST"]),
    desktop_api_route_contract(workspace_action_route("move"), ["POST"]),
    desktop_api_route_contract(workspace_action_route("copy"), ["POST"]),
    desktop_api_route_contract(workspace_action_route("trash"), [
      "GET", "HEAD", "POST",
    ]),
    desktop_api_route_contract(workspace_action_route("restore"), ["POST"]),
    desktop_api_route_contract(workspace_action_route("import"), ["POST"]),
    desktop_api_route_contract(workspace_action_route("reveal"), ["POST"]),
    desktop_api_route_contract(workspace_action_route("review-diff"), [
      "GET", "HEAD",
    ]),
    desktop_api_route_contract(search_route(), ["GET", "HEAD"]),
    desktop_api_route_contract(town_route("state"), ["GET", "HEAD"]),
    desktop_api_route_contract(town_route("daemon"), ["GET", "HEAD"]),
    desktop_api_route_contract(town_route("daemon/status"), ["GET", "HEAD"]),
    desktop_api_route_contract(town_route("daemon/supervision"), [
      "GET", "HEAD", "POST",
    ]),
    desktop_api_route_contract(town_route("daemon/launch-agent"), [
      "GET", "HEAD", "POST",
    ]),
    desktop_api_route_contract(town_route("daemon/start"), ["POST"]),
    desktop_api_route_contract(town_route("daemon/stop"), ["POST"]),
    desktop_api_route_contract(town_route("daemon/restart"), ["POST"]),
    desktop_api_route_contract(town_route("analytics"), ["GET", "HEAD"]),
    desktop_api_route_contract(town_route("progress"), ["GET", "HEAD"]),
    desktop_api_route_contract(town_route("events"), ["GET", "HEAD"]),
    desktop_api_route_contract(town_route("calendar.ics"), ["GET", "HEAD"]),
    desktop_api_route_contract(town_route("messages"), ["GET", "HEAD"]),
    desktop_api_route_contract(town_route("requests"), ["GET", "HEAD", "POST"]),
    desktop_api_route_contract(town_route("standing-goals"), [
      "GET", "HEAD", "POST",
    ]),
    desktop_api_route_contract(town_route("dispatch"), ["POST"]),
    desktop_api_route_contract(books_route("patterns"), ["GET", "HEAD"]),
    desktop_api_route_contract(books_route("base-types"), ["GET", "HEAD"]),
    desktop_api_route_contract(books_route("template-registry"), ["GET", "HEAD"]),
    desktop_api_route_contract(books_route("verify"), ["GET", "HEAD"]),
    desktop_api_route_contract(books_route("app-tool-portable"), [
      "GET", "HEAD", "POST",
    ]),
    desktop_api_route_contract(books_route("app-tool-portable/all"), [
      "GET", "HEAD", "POST",
    ]),
    desktop_api_route_contract(books_route("sync-standing-goal"), ["POST"]),
    desktop_api_route_contract(books_route("from-pattern"), ["POST"]),
    desktop_api_route_contract(moonclaw_route("runs"), ["GET", "HEAD"]),
    desktop_api_route_contract(moonclaw_route("progress"), ["GET", "HEAD"]),
    desktop_api_route_contract(moonclaw_route("events"), ["GET", "HEAD"]),
    desktop_api_route_contract(moonclaw_run_artifacts_route(), ["GET", "HEAD"]),
    desktop_api_route_contract(moonclaw_route("daemon"), ["GET", "HEAD"]),
    desktop_api_route_contract(moonclaw_route("models"), ["GET", "HEAD"]),
    desktop_api_route_contract(review_items_route(), ["GET", "HEAD"]),
    desktop_api_route_contract(review_decision_route(), ["POST"]),
    desktop_api_route_contract(preferences_views_route(), [
      "GET", "HEAD", "POST",
    ]),
    desktop_api_route_contract(preferences_tags_route(), ["GET", "HEAD", "POST"]),
  ]
}

///|
pub fn desktop_api_required_endpoints() -> Array[String] {
  let endpoints : Array[String] = []
  for contract in desktop_api_route_contracts() {
    if contract.path != "" {
      endpoints.push(contract.path)
    }
  }
  endpoints
}

///|
pub fn desktop_api_capability_contract() -> DesktopApiCapabilities {
  {
    component: "moondesk-desktop-api",
    kind: "moondesk-desktop-api-capabilities.v1",
    version: 1,
    route_contract_endpoint: desktop_capabilities_route(),
    required_endpoints: desktop_api_required_endpoints(),
    desktop_route_contracts: desktop_api_route_contracts(),
    portable_api_snapshot_routes: desktop_portable_api_snapshot_routes(),
    portable_api_workspace_content_routes: desktop_portable_api_workspace_content_routes(),
    portable_api_supported_route_patterns: desktop_portable_api_supported_route_patterns(),
  }
}

///|
pub fn desktop_api_route_allowed_methods(endpoint : String) -> Array[String] {
  let path = desktop_api_contract_path(endpoint)
  for contract in desktop_api_route_contracts() {
    if contract.path == path {
      return contract.methods
    }
  }
  []
}

///|
pub fn desktop_api_route_accepts_method(
  endpoint : String,
  method_name : String,
) -> Bool {
  method_name != "" &&
  desktop_api_route_allowed_methods(endpoint).contains(method_name)
}
