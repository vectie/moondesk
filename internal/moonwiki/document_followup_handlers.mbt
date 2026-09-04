///|
const DocumentFollowupContract : String = "moondesk.document_followup_queue.v1"

///|
const DocumentFollowupMaxQueues : Int = 1_024

///|
const DocumentFollowupMaxItems : Int = 64

///|
const DocumentFollowupMaxTextChars : Int = 120_000

///|
let document_followup_write_mutex : @async.Mutex = Mutex()

///|
fn document_followups_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "conversations/document-followups.v1.json",
  )
}

///|
fn document_followup_queue_id(
  workspace_id : String,
  conversation_id : String,
) -> String {
  workspace_id + "::" + conversation_id
}

///|
fn document_followup_items(payload : Json) -> Array[Json]? {
  guard payload is Object(fields) else { return None }
  guard fields.get("items") is Some(Array(items)) else { return None }
  if items.length() > DocumentFollowupMaxItems {
    return None
  }
  let normalized : Array[Json] = []
  let seen : Map[String, Unit] = Map([])
  for index, item in items {
    let id = json_string(item, "id", default="").trim().to_owned()
    let text = json_string(item, "text", default="").trim().to_owned()
    let state = json_string(item, "state", default="draft")
    if !document_conversation_id_valid(id) ||
      seen.contains(id) ||
      text == "" ||
      text.length() > DocumentFollowupMaxTextChars ||
      !["draft", "sending"].contains(state) {
      return None
    }
    seen[id] = ()
    normalized.push({
      "id": id,
      "text": text,
      "state": state,
      "position": index,
      "created_at": json_string(item, "created_at", default=""),
    })
  }
  Some(normalized)
}

///|
fn document_followup_queue(
  records : Array[Json],
  workspace_id : String,
  conversation_id : String,
) -> Json? {
  let id = document_followup_queue_id(workspace_id, conversation_id)
  for record in records {
    if json_string(record, "id", default="") == id {
      return Some(record)
    }
  }
  None
}

///|
fn empty_document_followup_queue(
  workspace_id : String,
  conversation_id : String,
  task_id? : String = "",
) -> Json {
  {
    "contract": DocumentFollowupContract,
    "id": document_followup_queue_id(workspace_id, conversation_id),
    "workspace_id": workspace_id,
    "conversation_id": conversation_id,
    "task_id": task_id,
    "revision": 0,
    "items": [],
    "updated_at": "",
  }
}

///|
fn document_followup_replacement(
  current : Json,
  payload : Json,
  updated_at : String,
) -> Result[Json, String] {
  let expected_revision = json_int(payload, "expected_revision", default=-1)
  let current_revision = json_int(current, "revision", default=0)
  if expected_revision >= 0 && expected_revision != current_revision {
    return Err("revision_conflict")
  }
  let items = match document_followup_items(payload) {
    Some(value) => value
    None => return Err("invalid_items")
  }
  Ok({
    "contract": DocumentFollowupContract,
    "id": json_string(current, "id", default=""),
    "workspace_id": json_string(current, "workspace_id", default=""),
    "conversation_id": json_string(current, "conversation_id", default=""),
    "task_id": json_string(payload, "task_id", default=""),
    "revision": current_revision + 1,
    "items": Json::array(items),
    "updated_at": updated_at,
  })
}

///|
async fn write_document_followup_queues(
  workspace_root : String,
  records : Array[Json],
) -> Unit {
  let path = document_followups_path(workspace_root)
  let content = Json::array(records).stringify(indent=2) + "\n"
  if @fsx.exists(path) {
    if @fsx.read_file(path) == content {
      return
    }
  }
  let parent = @pathx.dirname(path).to_owned()
  @moonlib/fsx.make_directory(parent, recursive=true, exists_ok=true)
  let temp = @pathx.join(
    parent,
    ".document-followups." +
    @desk.stable_id("followup-write", @async.now().to_string()) +
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
async fn handle_document_followups(
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
  let conversation_id = decode_query_value(
      query_value(request_path, "conversation_id").unwrap_or(""),
    )
    .trim()
    .to_owned()
  if workspace_id == "" || !document_conversation_id_valid(conversation_id) {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id and a valid conversation_id are required",
    )
    return
  }
  if find_workspace(workspace_root, workspace_id) is None {
    send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
    return
  }
  let records = read_json_array_file(document_followups_path(workspace_root))
  let queue = document_followup_queue(records, workspace_id, conversation_id).unwrap_or(
    empty_document_followup_queue(workspace_id, conversation_id),
  )
  send_json(conn, method_, queue)
}

///|
async fn handle_save_document_followups(
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
  let task_id = json_string(payload, "task_id", default="").trim().to_owned()
  if workspace_id == "" ||
    !document_conversation_id_valid(conversation_id) ||
    (task_id != "" && !moonclaw_general_task_id_valid(task_id)) {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id, conversation_id, or task_id is invalid",
    )
    return
  }
  if find_workspace(workspace_root, workspace_id) is None {
    send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
    return
  }
  document_followup_write_mutex.acquire()
  defer document_followup_write_mutex.release()
  let path = document_followups_path(workspace_root)
  let records = read_json_array_file(path)
  let current = document_followup_queue(records, workspace_id, conversation_id).unwrap_or(
    empty_document_followup_queue(workspace_id, conversation_id, task_id~),
  )
  let replacement = match
    document_followup_replacement(current, payload, @async.now().to_string()) {
    Ok(value) => value
    Err("revision_conflict") => {
      send_api_json_error(conn, method_, 409, "Conflict", {
        "contract": DocumentFollowupContract,
        "error": "revision_conflict",
        "message": "The follow-up queue changed on another client",
        "queue": current,
      })
      return
    }
    Err(_) => {
      send_api_error(
        conn, method_, 400, "Bad Request", "Follow-up items are invalid",
      )
      return
    }
  }
  let next = upsert_record_by_id(records, replacement)
  next.sort_by((left, right) => {
    json_string(right, "updated_at", default="").compare(
      json_string(left, "updated_at", default=""),
    )
  })
  while next.length() > DocumentFollowupMaxQueues {
    next.pop() |> ignore
  }
  write_document_followup_queues(workspace_root, next) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save follow-up queue",
      )
      return
    }
  }
  send_json(conn, method_, replacement)
}
