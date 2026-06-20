///|
async fn handle_mooncode_session_stream(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let format = query_value(request_path, "format").unwrap_or("jsonl")
  let since = @mooncode.stream_since_value(
    query_value(request_path, "since").unwrap_or(""),
  )
  let content_type = @mooncode.stream_content_type(format)
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => {
      let live = @mooncode.stream_live_enabled_value(
        query_value(request_path, "live").unwrap_or(""),
      )
      let live_timeout_ms = @mooncode.stream_live_timeout_ms_value(
        query_value(request_path, "timeout_ms").unwrap_or(""),
      )
      let live_poll_ms = @mooncode.stream_live_poll_ms_value(
        query_value(request_path, "poll_ms").unwrap_or(""),
      )
      match
        mooncode_native_stream_text(
          workspace_root,
          session_id,
          format,
          since,
          wait_ms=if live { live_timeout_ms } else { 0 },
          poll_ms=live_poll_ms,
        ) {
        Ok(text) => send_text(conn, method_, content_type, text)
        Err(_) => {
          let projected = if live {
            mooncode_live_stream_projection(
              workspace_root, session_id, session, since, live_timeout_ms, live_poll_ms,
            )
          } else {
            attach_mooncode_session_projection(workspace_root, session)
          }
          let events = json_array_items(projected, "mooncode_events")
          if format == "sse" {
            send_text(
              conn,
              method_,
              content_type,
              @mooncode.stream_sse_text(projected, events, since~),
            )
          } else {
            send_text(
              conn,
              method_,
              content_type,
              @mooncode.stream_jsonl_text(projected, events, since~),
            )
          }
        }
      }
    }
    None =>
      match
        mooncode_native_stream_text(
          workspace_root,
          session_id,
          format,
          since,
          wait_ms=0,
          poll_ms=100,
        ) {
        Ok(text) => send_text(conn, method_, content_type, text)
        Err(_) =>
          send_api_error(
            conn, method_, 404, "Not Found", "Unknown MoonCode session",
          )
      }
  }
}

///|
async fn handle_mooncode_session_stream_state(
  workspace_root : String,
  session_id : String,
  request_path : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let session = match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let since = @mooncode.stream_since_value(
    query_value(request_path, "since").unwrap_or(""),
  )
  if method_ is Post {
    let payload = match read_json_body(body) {
      Some(json) => json
      None => {
        send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
        return
      }
    }
    let consumer_id = @mooncode.stream_checkpoint_consumer_id(
      payload,
      query_value(request_path, "consumer").unwrap_or(""),
    )
    let projected = attach_mooncode_session_projection(workspace_root, session)
    let events = json_array_items(projected, "mooncode_events")
    let requested_sequence = @mooncode.stream_checkpoint_sequence(
      payload,
      since,
      events.length(),
    )
    let checkpoint = mooncode_stream_checkpoint_record(
      workspace_root,
      projected,
      consumer_id,
      requested_sequence,
      events.length(),
    )
    write_mooncode_stream_checkpoint(
      workspace_root, session_id, consumer_id, checkpoint,
    ) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not save MoonCode stream checkpoint",
        )
        return
      }
    }
    send_json(
      conn,
      method_,
      mooncode_stream_state_projection(
        workspace_root, projected, since, consumer_id,
      ),
    )
  } else {
    let consumer_id = @mooncode.stream_checkpoint_consumer_id(
      Json::object({}),
      query_value(request_path, "consumer").unwrap_or(""),
    )
    send_json(
      conn,
      method_,
      mooncode_stream_state_projection(
        workspace_root, session, since, consumer_id,
      ),
    )
  }
}

///|
async fn mooncode_live_stream_projection(
  workspace_root : String,
  session_id : String,
  fallback_session : Json,
  since : Int,
  timeout_ms : Int,
  poll_ms : Int,
) -> Json {
  let initial = attach_mooncode_session_projection(
    workspace_root, fallback_session,
  )
  if json_array_items(initial, "mooncode_events").length() > since ||
    timeout_ms <= 0 {
    return initial
  }
  let attempts = @mooncode.stream_live_attempt_count(timeout_ms, poll_ms)
  for _ in 0..<attempts {
    @async.sleep(poll_ms)
    match read_mooncode_session_record(workspace_root, session_id) {
      Some(session) => {
        let projected = attach_mooncode_session_projection(
          workspace_root, session,
        )
        if json_array_items(projected, "mooncode_events").length() > since {
          return projected
        }
      }
      None => ()
    }
  }
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => attach_mooncode_session_projection(workspace_root, session)
    None => initial
  }
}

///|
fn mooncode_stream_checkpoint_record(
  workspace_root : String,
  session : Json,
  consumer_id : String,
  last_seen_sequence : Int,
  latest_sequence : Int,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let clamped = @mooncode.stream_checkpoint_sequence(
    { "last_seen_sequence": last_seen_sequence },
    0,
    latest_sequence,
  )
  @mooncode.moondesk_stream_checkpoint_record(
    session,
    consumer_id,
    clamped,
    latest_sequence,
    @async.now().to_string(),
    mooncode_stream_checkpoint_path(workspace_root, session_id, consumer_id),
  )
}

///|
async fn mooncode_stream_state_projection(
  workspace_root : String,
  session : Json,
  since : Int,
  consumer_id : String,
) -> Json {
  let projected = attach_mooncode_session_projection(workspace_root, session)
  let session_id = json_string(projected, "id", default="")
  let events = json_array_items(projected, "mooncode_events")
  let checkpoint = read_mooncode_stream_checkpoint(
    workspace_root, session_id, consumer_id,
  )
  @mooncode.moondesk_stream_state_projection_record(
    projected,
    events,
    since,
    consumer_id,
    mooncode_event_log_path(workspace_root, session_id),
    mooncode_stream_checkpoint_path(workspace_root, session_id, consumer_id),
    checkpoint,
    @mooncode.moonclaw_native_stream_endpoint(
      session_id, workspace_root, "sse", since,
    ),
  )
}

///|
async fn mooncode_native_stream_text(
  workspace_root : String,
  session_id : String,
  format : String,
  since : Int,
  wait_ms~ : Int,
  poll_ms~ : Int,
) -> Result[String, String] {
  let daemon = moonclaw_daemon_status(workspace_root)
  let running = json_bool(daemon, "running", default=false)
  if !running {
    return Err("MoonClaw daemon is not running")
  }
  if !mooncode_native_runtime_ready(daemon) {
    return Err("MoonClaw MoonCode runtime is not available")
  }
  moonclaw_get_text(
    daemon,
    @mooncode.moonclaw_native_stream_endpoint(
      session_id,
      workspace_root,
      format,
      since,
      wait_ms~,
      poll_ms~,
    ),
  )
}
