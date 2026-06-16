///|
// MoonCode eval-report HTTP handlers and native proof persistence.

///|
async fn handle_mooncode_session_eval_report(
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
      let projected = sync_mooncode_native_eval_report(
        workspace_root, projected,
      ) catch {
        _ => projected
      }
      let with_saved_manifest = match
        mooncode_read_eval_report_manifest(projected) {
        Some(manifest) =>
          mooncode_session_with_saved_eval_manifest(projected, manifest)
        None => projected
      }
      send_json(
        conn,
        method_,
        @mooncode.eval_report_projection(with_saved_manifest),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_eval_report_ingest(
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
  let endpoint = json_string(
    payload,
    "endpoint",
    default=@mooncode.moonclaw_native_eval_report_endpoint(
      session_id, workspace_root,
    ),
  )
  let with_manifest = persist_mooncode_native_eval_report(
    workspace_root, session, payload, endpoint,
  ) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not persist MoonCode eval report: \{error}",
      )
      return
    }
  }
  write_agent_session_record(workspace_root, with_manifest)
  send_json(conn, method_, @mooncode.eval_report_projection(with_manifest))
}

///|
async fn persist_mooncode_native_eval_report(
  workspace_root : String,
  session : Json,
  payload : Json,
  endpoint : String,
) -> Json {
  let native_report = mooncode_normalize_native_eval_report(payload, endpoint)
  let projected = attach_mooncode_session_projection(
    workspace_root,
    @mooncode.session_without_eval_report_projection(session),
  )
  let with_native = agent_session_with_field(
    projected, "mooncode_native_eval_report", native_report,
  )
  let with_snapshot = write_mooncode_session_snapshot_if_possible(
    workspace_root, with_native,
  ) catch {
    _ => with_native
  }
  let with_runtime_handoff = write_mooncode_runtime_handoff_if_possible(
    workspace_root, with_snapshot,
  ) catch {
    _ => with_snapshot
  }
  let with_manifest = write_mooncode_eval_report_if_possible(
    with_runtime_handoff,
  )
  let refreshed = attach_mooncode_session_projection(
    workspace_root, with_manifest,
  )
  append_new_mooncode_command_events(workspace_root, projected, refreshed)
  write_agent_session_record(workspace_root, refreshed)
  refreshed
}
