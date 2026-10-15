///|
fn mooncode_setup_mcp_path(book_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    book_root, "moonclaw", "mcp-servers.json",
  )
}

///|
async fn mooncode_setup_integrations(book_root : String) -> Array[Json] {
  let config = read_json_file_or_object(mooncode_setup_mcp_path(book_root))
  json_array_items(config, "servers").map(server => {
    "id": json_string(server, "id", default=""),
    "url": json_string(server, "url", default=""),
    "enabled": json_bool(server, "enabled", default=true),
    "has_token": json_string(server, "token", default="") != "",
  })
}

///|
async fn mooncode_setup_save_integrations(
  book_root : String,
  payload : Json,
) -> Result[Json, String] {
  let previous = json_array_items(
    read_json_file_or_object(mooncode_setup_mcp_path(book_root)),
    "servers",
  )
  let saved : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for server in json_array_items(payload, "servers") {
    let id = json_string(server, "id", default="").trim().to_owned()
    let url = json_string(server, "url", default="").trim().to_owned()
    if id == "" ||
      seen.contains(id) ||
      (!url.has_prefix("https://") && !url.has_prefix("http://")) {
      return Err("Each integration needs a unique name and an HTTP endpoint")
    }
    seen[id] = true
    let mut token = json_string(server, "token", default="")
    if token == "" && !json_bool(server, "clear_token", default=false) {
      for existing in previous {
        if json_string(existing, "id", default="") == id {
          token = json_string(existing, "token", default="")
        }
      }
    }
    saved.push({
      "id": id,
      "url": url,
      "token": token,
      "enabled": json_bool(server, "enabled", default=true),
    })
  }
  let config : Json = { "servers": Json::array(saved) }
  let previous_public = mooncode_setup_integrations(book_root)
  mooncode_setup_write(
    mooncode_setup_mcp_path(book_root),
    config.stringify(indent=2),
  )
  Ok({
    "kind": "integrations",
    "servers": Json::array(mooncode_setup_integrations(book_root)),
    "previous": Json::array(previous_public),
  })
}

///|
async fn handle_mooncode_setup_test_integration(
  workspace_root : String,
  book_root : String,
  payload : Json,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="test-integration",
  )
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn, method_, 503, "Service Unavailable", "Start MoonClaw to test your integration",
    )
    return
  }
  let result = moonclaw_post_json(daemon, "/v1/mooncode/mcp", {
    "book_root": book_root,
    "server": json_string(payload, "server", default=""),
  })
  match result {
    Ok(result) => send_json(conn, method_, result)
    Err(message) =>
      send_api_error(conn, method_, 503, "Service Unavailable", message)
  }
}
