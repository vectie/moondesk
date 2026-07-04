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
  for
    native in moonclaw_runtime_full_sessions(
      workspace_root, workspace_filter, sessions,
    ) {
    sessions.push(native)
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
async fn moonclaw_runtime_full_sessions(
  workspace_root : String,
  workspace_filter : String,
  local_sessions : Array[Json],
) -> Array[Json] {
  let sessions : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for session in local_sessions {
    let id = json_string(session, "id", default="")
    if id != "" {
      seen[id] = true
    }
  }
  for row in moonclaw_runtime_session_listing_rows(workspace_root) {
    let id = json_string(row, "id", default="")
    if id == "" || seen.contains(id) {
      continue
    }
    if workspace_filter != "" &&
      json_string(row, "workspace_id", default="") != workspace_filter {
      continue
    }
    sessions.push(moonclaw_runtime_full_session(workspace_root, row))
    seen[id] = true
  }
  sessions
}

///|
async fn moonclaw_runtime_full_session(
  workspace_root : String,
  row : Json,
) -> Json {
  let id = json_string(row, "id", default="")
  let base = @mooncode.native_runtime_session_projection(workspace_root, id)
  let session = mooncode_session_with_field(
    mooncode_session_with_field(
      mooncode_session_with_field(
        mooncode_session_with_field(
          mooncode_session_with_field(
            mooncode_session_with_field(
              mooncode_session_with_field(
                mooncode_session_with_field(
                  base,
                  "title",
                  json_string(row, "title", default=id).to_json(),
                ),
                "workspace_id",
                json_string(row, "workspace_id", default=id).to_json(),
              ),
              "workspace_name",
              json_string(row, "workspace_name", default=id).to_json(),
            ),
            "cwd",
            json_string(row, "cwd", default=workspace_root).to_json(),
          ),
          "status",
          json_string(row, "status", default="").to_json(),
        ),
        "model",
        json_string(row, "model", default="").to_json(),
      ),
      "queued_count",
      json_int(row, "queued_count", default=0).to_json(),
    ),
    "updated_at",
    json_string(row, "updated_at", default="").to_json(),
  )
  let text = match
    mooncode_native_stream_text(
      workspace_root,
      id,
      "jsonl",
      0,
      wait_ms=0,
      poll_ms=100,
    ) {
    Ok(text) => text
    Err(_) => ""
  }
  @mooncode.session_projection_response(
    mooncode_session_response_defaults(session),
    mooncode_native_stream_event_payloads(text),
    event_log_path=mooncode_event_log_path(workspace_root, id),
    append_log_count=0,
    command_log_path=mooncode_command_log_path(workspace_root, id),
    command_log_count=0,
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, id,
    ),
    runtime_command_log_count=0,
    runtime_receipt_log_path=mooncode_runtime_receipt_log_path(
      workspace_root, id,
    ),
    runtime_receipt_log_count=0,
  )
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
