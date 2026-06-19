///|
// MoonCode readiness HTTP handler and host-side projection assembly.

///|
async fn handle_mooncode_session_readiness(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) =>
      send_json(
        conn,
        method_,
        @mooncode.session_readiness_response(
          attach_mooncode_session_projection(workspace_root, session),
        ),
      )
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}
