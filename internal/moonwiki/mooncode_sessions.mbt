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
  for record in read_mooncode_session_records(workspace_root) {
    if workspace_filter != "" &&
      json_string(record, "workspace_id", default="") != workspace_filter {
      continue
    }
    let synced = sync_mooncode_native_runtime_events(
      workspace_root,
      json_string(record, "id", default=""),
      record,
    ) catch {
      _ => record
    }
    sessions.push(attach_mooncode_session_projection(workspace_root, synced))
  }
  sessions.sort_by(fn(left, right) {
    json_string(right, "updated_at", default="").compare(
      json_string(left, "updated_at", default=""),
    )
  })
  if list_format == "listing" {
    let rows = mooncode_session_listing_rows(workspace_root, sessions)
    send_json(conn, method_, Json::array(rows))
  } else {
    send_json(conn, method_, Json::array(sessions))
  }
}

///|
async fn mooncode_session_listing_rows(
  workspace_root : String,
  sessions : Array[Json],
) -> Array[Json] {
  @mooncode.merge_session_listing_rows(
    moonclaw_runtime_session_listing_rows(workspace_root),
    sessions,
  )
}

///|
async fn moonclaw_runtime_session_listing_rows(
  workspace_root : String,
) -> Array[Json] {
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return []
  }
  let endpoint = @mooncode.moonclaw_native_session_listing_endpoint(
    workspace_root,
  )
  match moonclaw_get_json(daemon, endpoint) {
    Ok(payload) => @mooncode.runtime_session_listing_rows(payload)
    Err(_) => []
  }
}

///|
async fn handle_mooncode_session_events(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => {
      let session = sync_mooncode_native_runtime_events(
        workspace_root, session_id, session,
      ) catch {
        _ => {
          send_api_error(
            conn, method_, 500, "Internal Server Error", "Could not sync MoonCode native runtime events",
          )
          return
        }
      }
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
