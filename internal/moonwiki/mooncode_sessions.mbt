///|
async fn handle_mooncode_sessions(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_filter = query_value(request_path, "workspace").unwrap_or("")
  let list_format = query_value(request_path, "format").unwrap_or("full")
  let sessions : Array[Json] = []
  for record in read_agent_session_records(workspace_root) {
    if workspace_filter != "" &&
      json_string(record, "workspace_id", default="") != workspace_filter {
      continue
    }
    sessions.push(attach_mooncode_session_projection(workspace_root, record))
  }
  sessions.sort_by(fn(left, right) {
    json_string(right, "updated_at", default="").compare(
      json_string(left, "updated_at", default=""),
    )
  })
  if list_format == "listing" {
    send_json(
      conn,
      method_,
      Json::array(
        [
          for session in sessions => {
            @mooncode.session_listing_row(session, Json::null())
          }
        ],
      ),
    )
  } else {
    send_json(conn, method_, Json::array(sessions))
  }
}

///|
async fn handle_mooncode_session_events(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let projected = attach_mooncode_session_projection(
        workspace_root, session,
      )
      send_json(conn, method_, json_array(projected, "mooncode_events"))
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}
