///|
async fn handle_mooncode_session_runtime_claim_state(
  workspace_root : String,
  session_id : String,
  request_path : String,
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
      send_json(
        conn,
        method_,
        @mooncode.runtime_claim_state_for_session(
          session,
          commands,
          receipts,
          runtime_command_log_path=mooncode_runtime_command_log_path(
            workspace_root, session_id,
          ),
          runtime_receipt_log_path=mooncode_runtime_receipt_log_path(
            workspace_root, session_id,
          ),
          lease_now=match query_value(request_path, "now") {
            Some(value) if value != "" => value
            _ => @async.now().to_string()
          },
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
async fn handle_mooncode_session_runtime_claim(
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
  let session = match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let commands = read_mooncode_runtime_command_log(workspace_root, session_id)
  let receipts = read_mooncode_runtime_receipt_log(workspace_root, session_id)
  let claim_receipts = @mooncode.runtime_claim_receipts_with_defaults(
    session,
    commands,
    receipts,
    payload,
    now=@async.now().to_string(),
  )
  for receipt in claim_receipts {
    append_mooncode_runtime_receipt_log(workspace_root, session_id, receipt) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime claim receipt",
        )
        return
      }
    }
  }
  let updated = mooncode_session_with_field(
    session,
    "updated_at",
    @async.now().to_string().to_json(),
  )
  let with_runtime_handoff = write_mooncode_runtime_projection_chain(
    workspace_root, updated,
  )
  write_mooncode_session_record(workspace_root, with_runtime_handoff) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session after runtime claim",
      )
      return
    }
  }
  let next_receipts = read_mooncode_runtime_receipt_log(
    workspace_root, session_id,
  )
  send_json(
    conn,
    method_,
    @mooncode.runtime_claim_result_response(
      session_id,
      commands,
      next_receipts,
      claim_receipts,
      enrich_mooncode_session_for_response(workspace_root, with_runtime_handoff),
      runtime_command_log_path=mooncode_runtime_command_log_path(
        workspace_root, session_id,
      ),
      runtime_receipt_log_path=mooncode_runtime_receipt_log_path(
        workspace_root, session_id,
      ),
    ),
  )
}
