///|
// MoonCode tool-approval HTTP handlers.

///|
async fn handle_mooncode_session_tool_approvals(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      match mooncode_read_tool_approvals_manifest(session) {
        Some(manifest) => send_json(conn, method_, manifest)
        None =>
          send_api_error(
            conn, method_, 404, "Not Found", "No MoonCode tool approval manifest has been recorded for this session",
          )
      }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_tool_authorization_contract(
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
      let manifest = match mooncode_read_tool_approvals_manifest(projected) {
        Some(manifest) => manifest
        None =>
          json_object_field_or_empty(
            projected, "mooncode_last_tool_approvals_manifest",
          )
      }
      send_json(
        conn,
        method_,
        @mooncode.tool_authorization_contract(session_id, manifest),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_tool_authorization(
  workspace_root : String,
  session_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let now = @async.now().to_string()
  let preview = mooncode_tool_authorization_preview_event(payload, now)
  let projected = attach_mooncode_session_projection(workspace_root, session)
  let events = json_array_items(projected, "mooncode_events")
  let approval = @mooncode.tool_event_approval(preview)
  let target = @mooncode.tool_approval_target(preview)
  let should_record = approval != "" &&
    !@mooncode.tool_authorization_has_target(events, target)
  let with_preview = if should_record {
    append_mooncode_event_log(workspace_root, session_id, preview) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode tool authorization event",
        )
        return
      }
    }
    let updated = agent_session_with_field(session, "updated_at", now.to_json())
    let refreshed = refresh_mooncode_runtime_review_artifacts(
      workspace_root,
      attach_mooncode_session_projection(workspace_root, updated),
    )
    write_agent_session_record(workspace_root, refreshed) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not save MoonCode tool authorization state",
        )
        return
      }
    }
    refreshed
  } else {
    projected
  }
  let final_events = json_array_items(with_preview, "mooncode_events")
  let response = mooncode_tool_authorization_response(
    with_preview, preview, final_events,
  )
  send_json(conn, method_, response)
}
