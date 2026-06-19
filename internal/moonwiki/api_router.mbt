///|
async fn handle_api_request(
  workspace_root : String,
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let segments = path_segments(strip_query(request_path))
  if route_workspace_api(
      workspace_root, segments, method_, request_path, body, conn,
    ) {
    return
  }
  if route_town_api(workspace_root, segments, method_, body, conn) {
    return
  }
  if route_book_requests(
      workspace_root, segments, method_, request_path, body, conn,
    ) {
    return
  }
  if route_moonclaw_api(workspace_root, segments, method_, request_path, conn) {
    return
  }
  if route_mooncode_api(
      workspace_root, segments, method_, request_path, body, conn,
    ) {
    return
  }
  if route_review_preferences_api(
      workspace_root, segments, method_, request_path, body, conn,
    ) {
    return
  }
  send_api_error(conn, method_, 404, "Not Found", "Not Found")
}

///|
async fn send_method_not_allowed(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
) -> Unit {
  send_api_error(conn, method_, 405, "Method Not Allowed", "Method Not Allowed")
}
