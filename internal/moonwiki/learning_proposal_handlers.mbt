///|
const LearningProposalContract : String = "moondesk.learning-proposal.v1"

///|
const LearningProposalMaxRecords : Int32 = 512

///|
const LearningProposalMaxDetailChars : Int32 = 4_000

///|
const LearningProposalMaxSourceChars : Int32 = 8_000

///|
let learning_proposal_write_mutex : @async.Mutex = Mutex()

///|
fn learning_proposals_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "learning/proposals.v1.json",
  )
}

///|
fn learning_proposal_kind_valid(kind : String) -> Bool {
  ["preference", "knowledge", "procedure", "capability"].contains(kind)
}

///|
fn learning_proposal_find(records : Array[Json], id : String) -> Json? {
  for record in records {
    if json_string(record, "id", default="") == id {
      return Some(record)
    }
  }
  None
}

///|
fn learning_proposal_create(
  payload : Json,
  now : String,
) -> Result[Json, String] {
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  let kind = json_string(payload, "kind", default="knowledge").trim().to_owned()
  let detail = json_string(payload, "detail", default="").trim().to_owned()
  let source = json_string(payload, "source", default="").trim().to_owned()
  if workspace_id == "" ||
    !learning_proposal_kind_valid(kind) ||
    detail == "" ||
    detail.length() > LearningProposalMaxDetailChars ||
    source.length() > LearningProposalMaxSourceChars {
    return Err("invalid_learning_proposal")
  }
  Ok({
    "contract": LearningProposalContract,
    "id": @desk.stable_id(
      "learning-proposal",
      workspace_id + ":" + kind + ":" + detail + ":" + now,
    ),
    "workspace_id": workspace_id,
    "kind": kind,
    "detail": detail,
    "source": source,
    "status": "proposed",
    "created_at": now,
    "decided_at": "",
  })
}

///|
fn learning_proposal_decide(
  records : Array[Json],
  payload : Json,
  now : String,
) -> Result[Json, String] {
  let id = json_string(payload, "id", default="").trim().to_owned()
  let action = json_string(payload, "action", default="").trim().to_owned()
  if id == "" || !["accept", "reject", "persist"].contains(action) {
    return Err("invalid_learning_decision")
  }
  let current = match learning_proposal_find(records, id) {
    Some(value) => value
    None => return Err("learning_proposal_not_found")
  }
  let workspace_id = json_string(payload, "workspace_id", default="")
  if workspace_id != "" &&
    json_string(current, "workspace_id", default="") != workspace_id {
    return Err("learning_proposal_not_found")
  }
  let status = json_string(current, "status", default="")
  if status == "accepted" && ["accept", "persist"].contains(action) {
    return Ok(current)
  }
  if action == "persist" || status != "proposed" {
    return Err("learning_proposal_already_decided")
  }
  let decided = @mooncore.session_with_field(
    current,
    "status",
    ToJson::to_json(if action == "accept" { "accepted" } else { "rejected" }),
  )
  Ok(@mooncore.session_with_field(decided, "decided_at", ToJson::to_json(now)))
}

///|
async fn write_learning_proposals(
  workspace_root : String,
  records : Array[Json],
) -> Unit {
  let path = learning_proposals_path(workspace_root)
  let content = Json::array(records).stringify(indent=2) + "\n"
  if @fsx.exists(path) {
    if @fsx.read_file(path) == content {
      return
    }
  }
  let parent = @pathx.dirname(path).to_owned()
  @fsx.make_directory(parent, recursive=true, exists_ok=true)
  let temp = @pathx.join(
    parent,
    ".learning-proposals." +
    @desk.stable_id("learning-write", @async.now().to_string()) +
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
async fn apply_learning_proposal(
  workspace_root : String,
  payload : Json,
  now : String,
  save~ : async (String, Array[Json], Json) -> Bool = save_learning_record,
) -> Result[Json, String] {
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  if workspace_id == "" {
    return Err("workspace_id_required")
  }
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => return Err("unknown_workspace")
  }
  learning_proposal_write_mutex.acquire()
  defer learning_proposal_write_mutex.release()
  let path = learning_proposals_path(workspace_root)
  @fsx.make_directory(
    @pathx.dirname(path).to_owned(),
    recursive=true,
    exists_ok=true,
  )
  let records = match read_learning_proposals(workspace_root) {
    Ok(records) => records
    Err(error) => return Err(error)
  }
  let action = json_string(payload, "action", default="propose")
  let record = if action == "propose" {
    learning_proposal_create(payload, now)
  } else {
    learning_proposal_decide(records, payload, now)
  }
  let record = match record {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if json_string(record, "status", default="") != "accepted" {
    if !save(workspace_root, records, record) {
      return Err("learning_journal_write_failed")
    }
    return Ok(record)
  }
  if !(workspace.kind is MoonBook) {
    let desk_only = learning_book_receipt(
      record, "unsupported", "learning_requires_moonbook",
    )
    if !save(workspace_root, records, desk_only) {
      return Err("learning_journal_write_failed")
    }
    return Ok(desk_only)
  }
  // Journal the human decision first. A crash leaves one explicit retryable
  // accepted record, never an unjournaled Book lesson or a second decision time.
  let pending = learning_book_receipt(record, "pending", "")
  if !save(workspace_root, records, pending) {
    return Err("learning_journal_write_failed")
  }
  let persisted = persist_learning_in_book(workspace.root_path, record) catch {
    _ => Err("learning_book_write_failed")
  }
  let saved = match persisted {
    Ok(_) => learning_book_receipt(record, "persisted", "")
    Err(error) => learning_book_receipt(record, "failed", error)
  }
  if !save(workspace_root, records, saved) {
    return Err("learning_journal_write_failed")
  }
  Ok(saved)
}

///|
async fn accepted_learning_for_prompt(
  workspace_root : String,
  workspace_id : String,
) -> Array[String] {
  let lines : Array[String] = []
  for record in read_json_array_file(learning_proposals_path(workspace_root)) {
    if json_string(record, "workspace_id", default="") == workspace_id &&
      json_string(record, "status", default="") == "accepted" {
      let kind = json_string(record, "kind", default="knowledge")
      let detail = json_string(record, "detail", default="")
      if detail != "" {
        lines.push("- Learned " + kind + ": " + detail)
        if lines.length() >= 40 {
          break
        }
      }
    }
  }
  lines
}

///|
async fn handle_learning_proposals(
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
  if workspace_id == "" {
    send_api_error(
      conn, method_, 400, "Bad Request", "workspace_id is required",
    )
    return
  }
  let records = match read_learning_proposals(workspace_root) {
    Ok(records) => records
    Err(_) => {
      send_api_error(
        conn, method_, 503, "Service Unavailable", "Learning journal is unavailable; retry after restoring access",
      )
      return
    }
  }
  let proposals = records.filter(record => {
    json_string(record, "workspace_id", default="") == workspace_id
  })
  send_json(conn, method_, {
    "contract": "moondesk.learning-proposals.v1",
    "workspace_id": workspace_id,
    "proposals": Json::array(proposals),
  })
}

///|
async fn handle_update_learning_proposal(
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
  match
    apply_learning_proposal(workspace_root, payload, @async.now().to_string()) {
    Ok(record) => send_json(conn, method_, record)
    Err("unknown_workspace") =>
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
    Err("learning_proposal_not_found") =>
      send_api_error(
        conn, method_, 404, "Not Found", "Learning proposal not found",
      )
    Err("learning_proposal_already_decided") =>
      send_api_error(
        conn, method_, 409, "Conflict", "Learning proposal was already decided",
      )
    Err("learning_journal_write_failed")
    | Err("learning_journal_unreadable")
    | Err("learning_journal_invalid") =>
      send_api_error(
        conn, method_, 503, "Service Unavailable", "Learning decision could not be confirmed; reload and retry",
      )
    Err(error) => send_api_error(conn, method_, 400, "Bad Request", error)
  }
}
