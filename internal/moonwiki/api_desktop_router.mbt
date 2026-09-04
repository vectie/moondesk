///|
async fn route_desktop_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "desktop", "provider-handoff"] => {
      if method_ is Post {
        handle_desktop_provider_handoff(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    ["api", "desktop", "pack-apps"] => {
      let endpoint = @desk.desktop_api_path(["api", "desktop", "pack-apps"])
      if desktop_api_route_accepts_read(endpoint, method_) {
        send_json(conn, method_, installed_pack_apps(workspace_root))
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "desktop", "capabilities"] => {
      let endpoint = @desk.desktop_capabilities_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_desktop_api_capabilities(method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    _ => false
  }
}
