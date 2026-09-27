///|
/// MoonDesk presents MoonTown-owned Code schedules. It never copies schedule
/// state into its own store or dispatches a turn on MoonTown's behalf.
async fn handle_mooncode_schedules(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if method_ is Get || method_ is Head {
    match moontown_owner_get_json(workspace_root, "/api/code-schedules") {
      Ok(payload) => send_json(conn, method_, payload)
      Err(error) =>
        send_api_error(conn, method_, 503, "Service Unavailable", error)
    }
    return
  }
  guard method_ is Post else {
    send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD", "POST"])
    return
  }
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  match
    moontown_owner_post_json_with_status(
      workspace_root, "/api/code-schedules", payload,
    ) {
    Ok(response) => send_json(conn, method_, response)
    Err((code, error)) =>
      send_api_error(
        conn,
        method_,
        if code == 400 || code == 404 || code == 409 {
          code
        } else {
          503
        },
        if code == 400 {
          "Bad Request"
        } else if code == 409 {
          "Conflict"
        } else if code == 404 {
          "Not Found"
        } else {
          "Service Unavailable"
        },
        error,
      )
  }
}
