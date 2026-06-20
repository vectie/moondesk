///|
async fn handle_mooncode_session_runtime_replay(
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
      send_json(
        conn,
        method_,
        @mooncode.runtime_replay_state_for_session(
          session,
          commands,
          receipts,
          runtime_command_log_path=mooncode_runtime_command_log_path(
            workspace_root, session_id,
          ),
          runtime_receipt_log_path=mooncode_runtime_receipt_log_path(
            workspace_root, session_id,
          ),
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
async fn handle_mooncode_session_command_jsonl(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(_) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_receipt_log(
        workspace_root, session_id,
      )
      let scope = match query_value(request_path, "scope") {
        Some(value) => decode_query_value(value).trim().to_owned()
        None => "pending"
      }
      send_text(
        conn,
        method_,
        "application/x-ndjson; charset=utf-8",
        @mooncode.runtime_command_jsonl(commands, receipts, scope~),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_replay_ack(
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
  let prior_events = read_mooncode_event_log(workspace_root, session_id)
  let ack_receipts = @mooncode.runtime_replay_ack_receipts_with_defaults(
    session,
    commands,
    payload,
    acknowledged_at=@async.now().to_string(),
    runtime_receipts=receipts,
    prior_events~,
  )
  if ack_receipts.length() == 0 {
    send_api_error(
      conn, method_, 400, "Bad Request", "Runtime replay acknowledgement must include a known command_id, command_ids, or receipts[].",
    )
    return
  }
  for receipt in ack_receipts {
    append_mooncode_runtime_receipt_log(workspace_root, session_id, receipt) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime replay receipt",
        )
        return
      }
    }
  }
  let events = @mooncode.runtime_replay_ack_normalized_events(ack_receipts)
  for event in events {
    append_mooncode_event_log(workspace_root, session_id, event) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime replay event",
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
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session after runtime replay acknowledgement",
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
    @mooncode.runtime_replay_ack_result_response(
      session_id,
      commands,
      next_receipts,
      ack_receipts,
      events,
      json_object_field_or_empty(
        with_runtime_handoff, "mooncode_last_runtime_evidence_manifest",
      ),
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
