///|
async fn handle_mooncode_session_watch(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let since_revision = match
    mooncode_watch_query_nonnegative_int(
      request_path,
      "since_revision",
      default=0,
    ) {
    Ok(value) => value
    Err(reason) => {
      send_api_error(conn, method_, 400, "Bad Request", reason)
      return
    }
  }
  let since_sequence = match
    mooncode_watch_query_sequence(request_path, "since_sequence", default="0") {
    Ok(value) => value
    Err(reason) => {
      send_api_error(conn, method_, 400, "Bad Request", reason)
      return
    }
  }
  let wait_ms = mooncode_watch_wait_ms_value(
    mooncode_watch_query_option_int(request_path, "wait_ms", default=15000),
  )
  let poll_ms = mooncode_watch_poll_ms_value(
    mooncode_watch_query_option_int(request_path, "poll_ms", default=100),
  )
  let initial = mooncode_watch_session_snapshot(workspace_root, session_id)
  if json_string(initial, "id", default="") != session_id {
    send_api_error(conn, method_, 404, "Not Found", "Unknown MoonCode session")
    return
  }
  let initial_response = compact_mooncode_session_command_response(
    workspace_root,
    initial,
    Json::object({}),
  )
  let initial_revision = json_int(
    initial_response,
    "canonical_revision",
    default=0,
  )
  let initial_sequence = mooncode_watch_snapshot_sequence(initial_response)
  if initial_revision > since_revision {
    send_json(
      conn,
      method_,
      mooncode_conversation_watch_response(
        session_id,
        initial_response,
        since_revision,
        mooncode_max_sequence(since_sequence, initial_sequence.to_string()),
      ),
    )
    return
  }
  let resume_sequence = mooncode_max_sequence(
    since_sequence,
    initial_sequence.to_string(),
  )
  let resume_cursor = @mooncode_core.mooncode_watch_cursor(
    since_revision, resume_sequence,
  )
  let book_root = json_string(
    initial_response,
    "workspace_root",
    default=workspace_root,
  )
  let stream_text = match
    mooncode_native_stream_text(
      book_root,
      session_id,
      "jsonl",
      resume_cursor,
      wait_ms~,
      poll_ms~,
    ) {
    Ok(text) => text
    Err(error) => {
      send_api_error(conn, method_, 503, "Service Unavailable", error)
      return
    }
  }
  let next_sequence = match
    mooncode_native_stream_cursor(stream_text, resume_cursor) {
    @mooncode_core.Advanced(cursor) | @mooncode_core.Unchanged(cursor) =>
      cursor.sequence()
    @mooncode_core.Malformed(reason~, ..) => {
      send_api_error(conn, method_, 502, "Bad Gateway", reason)
      return
    }
  }
  let refreshed = mooncode_watch_session_snapshot(workspace_root, session_id)
  if json_string(refreshed, "id", default="") != session_id {
    send_api_error(conn, method_, 404, "Not Found", "Unknown MoonCode session")
    return
  }
  let response = compact_mooncode_session_command_response(
    workspace_root,
    refreshed,
    Json::object({}),
  )
  send_json(
    conn,
    method_,
    mooncode_conversation_watch_response(
      session_id, response, since_revision, next_sequence,
    ),
  )
}

///|
async fn mooncode_watch_session_snapshot(
  workspace_root : String,
  session_id : String,
) -> Json {
  moonclaw_runtime_session_by_id(workspace_root, session_id)
}

///|
fn mooncode_conversation_watch_response(
  session_id : String,
  snapshot : Json,
  since_revision : Int,
  next_sequence : String,
) -> Json raise {
  let actual_revision = json_int(snapshot, "canonical_revision", default=0)
  let changed = actual_revision > since_revision
  let revision = if changed { actual_revision } else { since_revision }
  let status = json_string(snapshot, "status", default="")
  let cursor = @mooncode_core.mooncode_watch_cursor(revision, next_sequence)
  @mooncode.conversation_watch_response_for_cursor(
    session_id~,
    cursor~,
    changed~,
    heartbeat=!changed,
    terminal=mooncode_watch_status_is_terminal(status),
    retry_after_ms=if changed { 0 } else { 100 },
    snapshot=if changed { snapshot } else { Json::null() },
  )
}

///|
fn mooncode_watch_snapshot_sequence(snapshot : Json) -> Int {
  let conversation = json_object_field_or_empty(
    snapshot, "mooncode_conversation",
  )
  json_int(conversation, "source_event_count", default=0)
}

///|
fn mooncode_watch_status_is_terminal(status : String) -> Bool {
  status == "done" || status == "failed" || status == "cancelled"
}

///|
fn mooncode_watch_query_nonnegative_int(
  request_path : String,
  key : String,
  default~ : Int,
) -> Result[Int, String] {
  let raw = query_value(request_path, key).unwrap_or(default.to_string())
  let value = @string.parse_int(raw) catch {
    _ => return Err("MoonCode watch \{key} must be a nonnegative integer")
  }
  if value < 0 {
    Err("MoonCode watch \{key} must be a nonnegative integer")
  } else {
    Ok(value)
  }
}

///|
fn mooncode_watch_query_sequence(
  request_path : String,
  key : String,
  default~ : String,
) -> Result[String, String] {
  let raw = query_value(request_path, key).unwrap_or(default)
  try @mooncode_core.mooncode_watch_cursor(0, raw) catch {
    _ => Err("MoonCode watch \{key} must be a canonical nonnegative decimal")
  } noraise {
    cursor => Ok(cursor.sequence())
  }
}

///|
fn mooncode_max_sequence(left : String, right : String) -> String raise {
  let cursor = @mooncode_core.mooncode_watch_cursor(0, left)
  cursor.advance_sequence(right).sequence()
}

///|
fn mooncode_watch_query_option_int(
  request_path : String,
  key : String,
  default~ : Int,
) -> Int {
  @string.parse_int(
    query_value(request_path, key).unwrap_or(default.to_string()),
  ) catch {
    _ => default
  }
}

///|
fn mooncode_watch_wait_ms_value(value : Int) -> Int {
  if value < 1000 {
    1000
  } else if value > 25000 {
    25000
  } else {
    value
  }
}

///|
fn mooncode_watch_poll_ms_value(value : Int) -> Int {
  if value < 25 {
    25
  } else if value > 1000 {
    1000
  } else {
    value
  }
}
