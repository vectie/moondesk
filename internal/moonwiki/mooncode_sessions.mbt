///|
async fn handle_mooncode_sessions(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_filter = query_value(request_path, "workspace").unwrap_or("")
  let list_format = query_value(request_path, "format").unwrap_or("full")
  let rows : Array[Json] = []
  for row in moonclaw_runtime_session_listing_rows(workspace_root) {
    if workspace_filter == "" ||
      json_string(row, "workspace_id", default="") == workspace_filter {
      rows.push(row)
    }
  }
  if list_format == "listing" {
    send_json(conn, method_, Json::array(rows))
    return
  }
  let sessions : Array[Json] = []
  for row in rows {
    let session = moonclaw_runtime_full_session(workspace_root, row)
    if json_string(session, "id", default="") != "" {
      sessions.push(session)
    }
  }
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
  let session = moonclaw_runtime_session_by_id(workspace_root, session_id)
  if json_string(session, "id", default="") != session_id {
    send_api_error(conn, method_, 404, "Not Found", "Unknown MoonCode session")
    return
  }
  if response_format == "chat" || response_format == "compact" {
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
    send_json(conn, method_, session)
  }
}

///|
async fn moonclaw_runtime_session_by_id(
  workspace_root : String,
  session_id : String,
) -> Json {
  let record = moonclaw_runtime_session_record(
    workspace_root, session_id, workspace_root,
  )
  if json_string(record, "session_id", default="") != session_id {
    return Json::object({})
  }
  moonclaw_runtime_full_session_from_record(workspace_root, record)
}

///|
async fn moonclaw_runtime_full_session(
  workspace_root : String,
  row : Json,
) -> Json {
  let session_id = json_string(row, "id", default="")
  let book_root = json_string(row, "workspace_root", default=workspace_root)
  let record = moonclaw_runtime_session_record(
    workspace_root, session_id, book_root,
  )
  if json_string(record, "session_id", default="") != session_id {
    return Json::object({})
  }
  moonclaw_runtime_full_session_from_record(workspace_root, record, row~)
}

///|
fn moonclaw_runtime_full_session_from_record(
  workspace_root : String,
  record : Json,
  row? : Json = Json::object({}),
) -> Json {
  let listing = if json_string(row, "id", default="") == "" {
    moonclaw_runtime_listing_row_from_record(workspace_root, record)
  } else {
    row
  }
  let session = moonclaw_runtime_full_session_base(
    workspace_root, listing, record,
  )
  @mooncode.session_projection_response(
    mooncode_session_response_defaults(session),
    [],
    event_log_path=moonclaw_runtime_record_storage_path(
      record, "events_jsonl", "",
    ),
    append_log_count=json_int(record, "event_log_count", default=0),
    command_log_path=moonclaw_runtime_record_storage_path(
      record, "commands_jsonl", "",
    ),
    command_log_count=json_int(record, "command_log_count", default=0),
    runtime_command_log_path=moonclaw_runtime_record_storage_path(
      record, "commands_jsonl", "",
    ),
    runtime_command_log_count=json_int(record, "command_log_count", default=0),
    runtime_receipt_log_path=moonclaw_runtime_record_storage_path(
      record, "runtime_receipts_jsonl", "",
    ),
    runtime_receipt_log_count=json_int(
      record,
      "runtime_receipt_log_count",
      default=0,
    ),
  )
}

///|
fn moonclaw_runtime_listing_row_from_record(
  workspace_root : String,
  record : Json,
) -> Json {
  let session_id = json_string(record, "session_id", default="")
  let book_root = json_string(record, "book_root", default=workspace_root)
  let snapshot = json_object_field_or_empty(record, "snapshot")
  let conversation = moonclaw_runtime_record_conversation(record)
  let turns = json_array_items(conversation, "turns")
  let latest = turns.last().unwrap_or(Json::object({}))
  let user = json_object_field_or_empty(latest, "user")
  let first_prompt = json_string(snapshot, "first_user_prompt", default="")
  {
    "id": session_id,
    "title": trimmed_text(first_prompt, fallback=session_id),
    "updated_at": json_string(
      latest,
      "updated_at",
      default=json_string(snapshot, "last_updated", default=""),
    ),
    "workspace_id": json_string(conversation, "workspace_id", default=""),
    "workspace_name": json_string(conversation, "workspace_name", default=""),
    "workspace_root": book_root,
    "book_root": book_root,
    "cwd": book_root,
    "status": json_string(latest, "status", default="durable"),
    "model": "",
    "queued_count": 0,
    "last_message": json_string(user, "content", default=first_prompt),
    "mooncode_runtime_session_id": session_id,
    "source": "moonclaw",
    "protocol": @mooncode.protocol_version(),
    "component": "mooncode",
  }
}

///|
async fn moonclaw_runtime_session_record(
  workspace_root : String,
  session_id : String,
  book_root : String,
) -> Json {
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="read-session",
  )
  if !json_bool(daemon, "running", default=false) {
    return Json::object({})
  }
  let endpoint = @mooncode.moonclaw_native_session_show_endpoint(
    session_id, book_root,
  )
  match moonclaw_get_json(daemon, endpoint) {
    Ok(record) => record
    Err(_) => Json::object({})
  }
}

///|
fn moonclaw_runtime_full_session_base(
  workspace_root : String,
  row : Json,
  record : Json,
) -> Json {
  ignore(workspace_root)
  let session_id = json_string(record, "session_id", default="")
  let book_root = json_string(record, "book_root", default="")
  let conversation = moonclaw_runtime_record_conversation(record)
  let canonical = moonclaw_runtime_record_conversation_belongs_to_session(
    conversation, session_id,
  )
  let workspace_id = if canonical {
    json_string(
      conversation,
      "workspace_id",
      default=json_string(row, "workspace_id", default=""),
    )
  } else {
    json_string(row, "workspace_id", default="")
  }
  let workspace_name = if canonical {
    json_string(
      conversation,
      "workspace_name",
      default=json_string(row, "workspace_name", default=""),
    )
  } else {
    json_string(row, "workspace_name", default="")
  }
  let base = @mooncode.native_runtime_session_projection(book_root, session_id)
  let session = base
    |> mooncode_session_with_field(
      "title",
      json_string(row, "title", default=session_id).to_json(),
    )
    |> mooncode_session_with_field("workspace_id", workspace_id.to_json())
    |> mooncode_session_with_field("workspace_name", workspace_name.to_json())
    |> mooncode_session_with_field("cwd", book_root.to_json())
    |> mooncode_session_with_field(
      "status",
      json_string(row, "status", default="durable").to_json(),
    )
    |> mooncode_session_with_field(
      "model",
      json_string(row, "model", default="").to_json(),
    )
    |> mooncode_session_with_field(
      "queued_count",
      json_int(row, "queued_count", default=0).to_json(),
    )
    |> mooncode_session_with_field(
      "updated_at",
      json_string(row, "updated_at", default="").to_json(),
    )
    |> mooncode_session_with_field(
      "last_message",
      json_string(row, "last_message", default="").to_json(),
    )
  if canonical {
    mooncode_session_with_field(session, "mooncode_conversation", conversation)
  } else {
    session
  }
}

///|
fn moonclaw_runtime_record_conversation(record : Json) -> Json {
  json_object_field_or_empty(record, "mooncode_conversation")
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
  record : Json,
  key : String,
  fallback : String,
) -> String {
  json_string(
    json_object_field_or_empty(record, "storage"),
    key,
    default=fallback,
  )
}

///|
async fn moonclaw_runtime_session_listing_rows(
  workspace_root : String,
) -> Array[Json] {
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="list-sessions",
  )
  if !json_bool(daemon, "running", default=false) {
    return []
  }
  let endpoint = @mooncode.moonclaw_native_session_listing_endpoint(
    workspace_root,
  )
  let native_rows = match moonclaw_get_json(daemon, endpoint) {
    Ok(payload) => @mooncode.runtime_session_listing_rows(payload)
    Err(_) => return []
  }
  let workspaces = discover_workspaces(workspace_root)
  native_rows.map(row => {
    moonclaw_runtime_listing_row_with_workspace(row, workspaces)
  })
}

///|
fn moonclaw_runtime_listing_row_with_workspace(
  row : Json,
  workspaces : Array[@desk.DeskWorkspace],
) -> Json {
  let row_root = @pathx.normalize(
    json_string(
      row,
      "workspace_root",
      default=json_string(row, "book_root", default=""),
    ),
  )
  for workspace in workspaces {
    if row_root == @pathx.normalize(workspace.root_path) {
      return row
        |> mooncode_session_with_field("workspace_id", workspace.id.to_json())
        |> mooncode_session_with_field(
          "workspace_name",
          workspace.name.to_json(),
        )
    }
  }
  row
  |> mooncode_session_with_field("workspace_id", "".to_json())
  |> mooncode_session_with_field("workspace_name", "".to_json())
}
