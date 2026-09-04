///|
const DocumentConversationContract : String = "moondesk.document_conversation.v1"

///|
const DocumentConversationMaxRecords : Int = 256

///|
const DocumentConversationMaxEntries : Int = 240

///|
const DocumentConversationMaxEntryChars : Int = 240_000

///|
let document_conversation_write_mutex : @async.Mutex = Mutex()

///|
fn document_conversations_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "conversations/document-conversations.v1.json",
  )
}

///|
fn document_conversation_id_valid(value : String) -> Bool {
  let value = value.trim()
  if value == "" || value.length() > 128 {
    return false
  }
  for ch in value {
    if !((ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' ||
      ch == '_') {
      return false
    }
  }
  true
}

///|
fn document_conversation_title(value : String) -> String {
  let value = value.trim().to_owned()
  if value == "" {
    "Document conversation"
  } else if value.length() <= 72 {
    value
  } else {
    value[:72].to_owned()
  }
}

///|
fn document_conversation_entries(payload : Json) -> Array[Json]? {
  guard payload is Object(fields) else { return None }
  guard fields.get("entries") is Some(Array(items)) else { return None }
  if items.length() > DocumentConversationMaxEntries {
    return None
  }
  let normalized : Array[Json] = []
  for item in items {
    let role = json_string(item, "role", default="").trim().to_owned()
    let content = json_string(item, "content", default="")
    if ![
        "user", "assistant", "assistant-stream", "source_ref", "artifact_ref", "automation_suggestion",
        "preference_usage", "background_result",
      ].contains(role) ||
      content.length() > DocumentConversationMaxEntryChars {
      return None
    }
    normalized.push({ "role": role, "content": content })
  }
  Some(normalized)
}

///|
async fn write_document_conversations(
  workspace_root : String,
  records : Array[Json],
) -> Unit {
  let path = document_conversations_path(workspace_root)
  let content = Json::array(records).stringify(indent=2) + "\n"
  if @fs.exists(path) {
    if @fs.read_file(path).text() == content {
      return
    }
  }
  let parent = @pathx.dirname(path).to_owned()
  @fsx.make_directory(parent, recursive=true, exists_ok=true)
  let temp = @pathx.join(
    parent,
    "." +
    path.split("/").last().unwrap_or("conversations.json").to_owned() +
    "." +
    @desk.stable_id("conversation-write", @async.now().to_string()) +
    ".tmp",
  )
  @fs.write_file(
    temp,
    @encoding/utf8.encode(content),
    create_mode=CreateNew,
    permission=0o600,
    sync=Full,
  )
  @fs.rename(temp, path, replace=true)
  @fs.chmod(path, 0o600)
}

///|
async fn handle_document_conversations(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_id = decode_query_value(
      query_value(request_path, "workspace_id").unwrap_or(""),
    )
    .trim()
    .to_owned()
  let document_path = decode_query_value(
      query_value(request_path, "document_path").unwrap_or(""),
    )
    .trim()
    .to_owned()
  if workspace_id == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id is required",
    )
    return
  }
  if find_workspace(workspace_root, workspace_id) is None {
    send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
    return
  }
  let records = read_json_array_file(
    document_conversations_path(workspace_root),
  )
  let selected = records.filter(record => {
    json_string(record, "workspace_id", default="") == workspace_id &&
    (
      document_path == "" ||
      json_string(record, "document_path", default="") == document_path
    )
  })
  send_json(conn, method_, {
    "contract": "moondesk.document_conversations.v1",
    "workspace_id": workspace_id,
    "document_path": document_path,
    "conversations": Json::array(selected),
  })
}

///|
async fn handle_save_document_conversation(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  let conversation_id = json_string(payload, "conversation_id", default="")
    .trim()
    .to_owned()
  let document_path = json_string(payload, "document_path", default="")
    .trim()
    .to_owned()
  let action = json_string(payload, "action", default="upsert")
  if workspace_id == "" || !document_conversation_id_valid(conversation_id) {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id and a valid conversation_id are required",
    )
    return
  }
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  if document_path != "" &&
    resolve_workspace_existing_path(workspace.root_path, document_path) is None {
    send_api_error(
      conn, method_, 400, "Bad Request", "Document is outside this workspace",
    )
    return
  }
  let path = document_conversations_path(workspace_root)
  document_conversation_write_mutex.acquire()
  defer document_conversation_write_mutex.release()
  let existing = read_json_array_file(path)
  let mut previous : Json? = None
  for item in existing {
    if json_string(item, "workspace_id", default="") == workspace_id &&
      json_string(item, "conversation_id", default="") == conversation_id {
      previous = Some(item)
      break
    }
  }
  let previous_revision = match previous {
    Some(record) => json_int(record, "revision", default=0)
    None => 0
  }
  let expected_revision = json_int(
    payload,
    "expected_revision",
    default=previous_revision,
  )
  if expected_revision != previous_revision {
    send_api_json_error(conn, method_, 409, "Conflict", {
      "contract": DocumentConversationContract,
      "error": "revision_conflict",
      "message": "The conversation changed on another client",
      "conversation": previous.unwrap_or(Json::null()),
    })
    return
  }
  if action == "delete" {
    let next = existing.filter(record => {
      !(json_string(record, "workspace_id", default="") == workspace_id &&
      json_string(record, "conversation_id", default="") == conversation_id)
    })
    write_document_conversations(workspace_root, next) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not delete conversation",
        )
        return
      }
    }
    send_json(conn, method_, {
      "deleted": true,
      "conversation_id": conversation_id,
    })
    return
  }
  let entries = match document_conversation_entries(payload) {
    Some(value) => value
    None => {
      send_api_error(
        conn, method_, 400, "Bad Request", "Conversation entries are invalid",
      )
      return
    }
  }
  let created_at = match previous {
    Some(record) =>
      json_string(record, "created_at", default=@async.now().to_string())
    None => @async.now().to_string()
  }
  let record : Json = {
    "contract": DocumentConversationContract,
    "conversation_id": conversation_id,
    "workspace_id": workspace_id,
    "document_path": document_path,
    "document_baseline": json_string(payload, "document_baseline", default=""),
    "title": document_conversation_title(
      json_string(payload, "title", default="Document conversation"),
    ),
    "moonclaw_session_id": conversation_id,
    "status": json_string(payload, "status", default="ready"),
    "archived": json_bool(payload, "archived", default=false),
    "revision": previous_revision + 1,
    "entries": Json::array(entries),
    "created_at": created_at,
    "updated_at": @async.now().to_string(),
  }
  let next = upsert_record_by_id(
    existing.map(item => {
      if json_string(item, "id", default="") == "" {
        @mooncore.session_with_field(
          item,
          "id",
          json_string(item, "conversation_id", default="").to_json(),
        )
      } else {
        item
      }
    }),
    @mooncore.session_with_field(record, "id", conversation_id.to_json()),
  )
  next.sort_by((left, right) => {
    json_string(right, "updated_at", default="").compare(
      json_string(left, "updated_at", default=""),
    )
  })
  while next.length() > DocumentConversationMaxRecords {
    next.pop() |> ignore
  }
  write_document_conversations(workspace_root, next) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save conversation",
      )
      return
    }
  }
  send_json(conn, method_, record)
}
