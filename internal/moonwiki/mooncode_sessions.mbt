///|
async fn handle_mooncode_sessions(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_filter = query_value(request_path, "workspace").unwrap_or("")
  let list_format = query_value(request_path, "format").unwrap_or("full")
  if list_format == "listing" {
    let local_rows = mooncode_local_session_listing_rows(
      workspace_root, workspace_filter,
    )
    let runtime_rows = moonclaw_runtime_session_listing_rows(workspace_root)
    let rows = @mooncode.merge_session_listing_rows(runtime_rows, local_rows)
    send_json(conn, method_, Json::array(rows))
    return
  }
  let sessions : Array[Json] = []
  for record in read_mooncode_session_records(workspace_root) {
    if workspace_filter != "" &&
      json_string(record, "workspace_id", default="") != workspace_filter {
      continue
    }
    sessions.push(attach_mooncode_session_projection(workspace_root, record))
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
  send_json(conn, method_, Json::array(sessions))
}

///|
async fn handle_mooncode_session(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let response_format = query_value(request_path, "format").unwrap_or("full")
  let since_revision = @string.parse_int(
    query_value(request_path, "since_revision").unwrap_or("0"),
  ) catch {
    _ => 0
  }
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) =>
      if response_format == "chat" || response_format == "compact" {
        let session = sync_mooncode_native_canonical_conversation(
          workspace_root, session_id, session,
        )
        send_json(
          conn,
          method_,
          compact_mooncode_session_revision_response(
            workspace_root,
            session,
            Json::object({}),
            since_revision,
          ),
        )
      } else {
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
        send_json(conn, method_, projected)
      }
    None => {
      let native = moonclaw_runtime_session_by_id(workspace_root, session_id)
      if json_string(native, "id", default="") == session_id {
        if response_format == "chat" || response_format == "compact" {
          send_json(
            conn,
            method_,
            compact_mooncode_session_revision_response(
              workspace_root,
              native,
              Json::object({}),
              since_revision,
            ),
          )
        } else {
          send_json(conn, method_, native)
        }
      } else {
        send_api_error(
          conn, method_, 404, "Not Found", "Unknown MoonCode session",
        )
      }
    }
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
async fn moonclaw_runtime_session_by_id(
  workspace_root : String,
  session_id : String,
) -> Json {
  for row in moonclaw_runtime_session_listing_rows(workspace_root) {
    if json_string(row, "id", default="") == session_id {
      return moonclaw_runtime_full_session(workspace_root, row)
    }
  }
  Json::object({})
}

///|
async fn moonclaw_runtime_full_session(
  workspace_root : String,
  row : Json,
) -> Json {
  let id = json_string(row, "id", default="")
  let book_root = json_string(row, "workspace_root", default=workspace_root)
  let native_record = moonclaw_runtime_session_record(
    workspace_root, id, book_root,
  )
  let native_conversation = moonclaw_runtime_record_conversation_for_session(
    native_record, id,
  )
  let session = moonclaw_runtime_full_session_base(
    workspace_root, row, native_record,
  )
  let events = if json_string(native_conversation, "kind", default="") ==
    @mooncode.conversation_kind() {
    []
  } else {
    let text = match
      mooncode_native_stream_text(
        book_root,
        id,
        "jsonl",
        0,
        wait_ms=0,
        poll_ms=100,
      ) {
      Ok(text) => text
      Err(_) => ""
    }
    mooncode_native_stream_event_payloads(text)
  }
  @mooncode.session_projection_response(
    mooncode_session_response_defaults(session),
    events,
    event_log_path=moonclaw_runtime_record_storage_path(
      native_record,
      "events_jsonl",
      mooncode_event_log_path(book_root, id),
    ),
    append_log_count=json_int(native_record, "event_log_count", default=0),
    command_log_path=moonclaw_runtime_record_storage_path(
      native_record,
      "commands_jsonl",
      mooncode_command_log_path(book_root, id),
    ),
    command_log_count=json_int(native_record, "command_log_count", default=0),
    runtime_command_log_path=moonclaw_runtime_record_storage_path(
      native_record,
      "commands_jsonl",
      mooncode_runtime_command_log_path(book_root, id),
    ),
    runtime_command_log_count=json_int(
      native_record,
      "command_log_count",
      default=0,
    ),
    runtime_receipt_log_path=moonclaw_runtime_record_storage_path(
      native_record,
      "runtime_receipts_jsonl",
      mooncode_runtime_receipt_log_path(book_root, id),
    ),
    runtime_receipt_log_count=json_int(
      native_record,
      "runtime_receipt_log_count",
      default=0,
    ),
  )
}

///|
async fn moonclaw_runtime_session_record(
  workspace_root : String,
  session_id : String,
  book_root : String,
) -> Json {
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return Json::object({})
  }
  let endpoint = @mooncode.moonclaw_native_session_show_endpoint(
    session_id, book_root,
  )
  match moonclaw_get_json(daemon, endpoint) {
    Ok(text) => text
    Err(_) => Json::object({})
  }
}

///|
fn moonclaw_runtime_full_session_base(
  workspace_root : String,
  row : Json,
  native_record : Json,
) -> Json {
  let id = json_string(row, "id", default="")
  let book_root = json_string(row, "workspace_root", default=workspace_root)
  let base = @mooncode.native_runtime_session_projection(book_root, id)
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
                json_string(row, "workspace_id", default=book_root).to_json(),
              ),
              "workspace_name",
              json_string(row, "workspace_name", default=book_root).to_json(),
            ),
            "cwd",
            json_string(row, "cwd", default=book_root).to_json(),
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
  let native_conversation = moonclaw_runtime_record_conversation(native_record)
  if moonclaw_runtime_record_conversation_belongs_to_session(
      native_conversation, id,
    ) {
    mooncode_session_with_field(
      session, "mooncode_conversation", native_conversation,
    )
  } else {
    session
  }
}

///|
fn moonclaw_runtime_record_conversation(native_record : Json) -> Json {
  json_object_field_or_empty(native_record, "mooncode_conversation")
}

///|
fn moonclaw_runtime_record_conversation_for_session(
  native_record : Json,
  session_id : String,
) -> Json {
  let conversation = moonclaw_runtime_record_conversation(native_record)
  if moonclaw_runtime_record_conversation_belongs_to_session(
      conversation, session_id,
    ) {
    conversation
  } else {
    Json::object({})
  }
}

///|
fn moonclaw_runtime_record_conversation_belongs_to_session(
  conversation : Json,
  session_id : String,
) -> Bool {
  json_string(conversation, "kind", default="") == @mooncode.conversation_kind() &&
  session_id != "" &&
  json_string(conversation, "session_id", default="") == session_id
}

///|
fn moonclaw_runtime_record_storage_path(
  native_record : Json,
  key : String,
  fallback : String,
) -> String {
  let storage = json_object_field_or_empty(native_record, "storage")
  let path = json_string(storage, key, default="")
  if path == "" {
    fallback
  } else {
    path
  }
}

///|
async fn mooncode_local_session_listing_rows(
  workspace_root : String,
  workspace_filter : String,
) -> Array[Json] {
  let sessions : Array[Json] = []
  for record in read_mooncode_session_records(workspace_root) {
    if workspace_filter != "" &&
      json_string(record, "workspace_id", default="") != workspace_filter {
      continue
    }
    sessions.push(mooncode_session_response_defaults(record))
  }
  @mooncode.merge_session_listing_rows([], sessions)
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
