///|
fn mooncode_skill_catalog_valid(payload : Json, book_root : String) -> Bool {
  json_string(payload, "kind", default="") == "mooncode-skill-catalog" &&
  json_string(payload, "owner", default="") == "moonclaw" &&
  json_string(payload, "book_root", default="") == book_root &&
  json_object_field(payload, "skills") is Some(Array(_)) &&
  !json_bool(payload, "content_included", default=true)
}

///|
async fn handle_mooncode_skills(
  workspace_root : String,
  workspace_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Select a MoonBook to inspect its skills",
      )
      return
    }
  }
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="read-skills",
  )
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn, method_, 503, "Service Unavailable", "MoonClaw is not running",
    )
    return
  }
  let result = moonclaw_get_json(
    daemon,
    @mooncode.moonclaw_native_skills_endpoint(workspace.root_path),
  )
  match result {
    Ok(payload) if mooncode_skill_catalog_valid(payload, workspace.root_path) =>
      send_json(conn, method_, payload)
    Ok(_) =>
      send_api_error(
        conn, method_, 502, "Bad Gateway", "MoonClaw returned an invalid skill catalog",
      )
    Err(error) =>
      send_api_error(conn, method_, 503, "Service Unavailable", error)
  }
}
