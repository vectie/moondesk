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
pub fn workspaces_url() -> String {
  desktop_api_url(["api", "workspaces"])
}

///|
pub fn workspace_metadata_url() -> String {
  desktop_api_url(["api", "workspaces", "metadata"])
}

///|
pub fn workspace_import_url() -> String {
  desktop_api_url(["api", "workspaces", "import"])
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
pub fn moonclaw_endpoint_url(endpoint : String) -> String {
  desktop_api_path(["api", "moonclaw"]) + "/" + url_path(endpoint)
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
pub fn review_decision_url() -> String {
  desktop_api_url(["api", "review", "items", "decision"])
}

///|
pub fn search_url(query : String) -> String {
  desktop_api_url(["api", "search"], query=[("query", query)])
}

///|
pub fn town_endpoint_url(endpoint : String) -> String {
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
pub fn books_endpoint_url(endpoint : String) -> String {
  desktop_api_path(["api", "books"]) + "/" + url_path(endpoint)
}
