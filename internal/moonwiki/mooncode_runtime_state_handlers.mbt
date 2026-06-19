///|
async fn handle_mooncode_session_runtime_handoff(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) =>
      match mooncode_read_runtime_handoff_manifest(session) {
        Some(manifest) =>
          if @mooncode.runtime_handoff_manifest_current(manifest) {
            send_json(conn, method_, manifest)
          } else {
            let projected = attach_mooncode_session_projection(
              workspace_root, session,
            )
            let with_manifest = write_mooncode_runtime_handoff_if_possible(
              workspace_root, projected,
            ) catch {
              _ => projected
            }
            match
              json_object_field(
                with_manifest, "mooncode_last_runtime_handoff_manifest",
              ) {
              Some(manifest) => send_json(conn, method_, manifest)
              None => send_json(conn, method_, manifest)
            }
          }
        None => {
          let projected = attach_mooncode_session_projection(
            workspace_root, session,
          )
          let with_manifest = write_mooncode_runtime_handoff_if_possible(
            workspace_root, projected,
          ) catch {
            _ => projected
          }
          match
            json_object_field(
              with_manifest, "mooncode_last_runtime_handoff_manifest",
            ) {
            Some(manifest) => send_json(conn, method_, manifest)
            None =>
              send_api_error(
                conn, method_, 404, "Not Found", "No MoonCode runtime handoff has been recorded for this session",
              )
          }
        }
      }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_execution_plan(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_receipt_log(
        workspace_root, session_id,
      )
      let events = read_mooncode_event_log(workspace_root, session_id)
      let daemon = moonclaw_daemon_status(workspace_root)
      let native_ready = if json_bool(daemon, "running", default=false) {
        mooncode_native_runtime_ready(daemon) catch {
          _ => false
        }
      } else {
        false
      }
      send_json(
        conn,
        method_,
        mooncode_runtime_execution_plan(
          workspace_root,
          session,
          session_id,
          commands,
          receipts,
          events,
          moonclaw_root=json_string(daemon, "moonclaw_root", default=""),
          native_ready~,
          lease_now=@async.now().to_string(),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_store(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) =>
      match read_mooncode_session_snapshot(workspace_root, session_id) {
        Some(snapshot) => send_json(conn, method_, snapshot)
        None => {
          let projected = attach_mooncode_session_projection(
            workspace_root, session,
          )
          let with_snapshot = write_mooncode_session_snapshot_if_possible(
            workspace_root, projected,
          ) catch {
            _ => projected
          }
          match json_object_field(with_snapshot, "mooncode_session_snapshot") {
            Some(snapshot) => send_json(conn, method_, snapshot)
            None =>
              send_api_error(
                conn, method_, 404, "Not Found", "No MoonCode session snapshot has been recorded for this session",
              )
          }
        }
      }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}
