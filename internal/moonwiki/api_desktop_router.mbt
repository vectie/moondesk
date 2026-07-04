///|
async fn route_desktop_api(
  segments : Array[String],
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
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
