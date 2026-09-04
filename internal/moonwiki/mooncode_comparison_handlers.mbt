///|
const MoonCodeComparisonContract : String = "moondesk.mooncode_comparison.v1"

///|
const MoonCodeComparisonMaxRecords : Int = 128

///|
const MoonCodeComparisonMaxGoalChars : Int = 16_384

///|
let mooncode_comparison_write_mutex : @async.Mutex = Mutex()

///|
fn mooncode_comparisons_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "comparisons/mooncode-comparisons.v1.json",
  )
}

///|
fn mooncode_comparison_digest_valid(value : String) -> Bool {
  if !value.has_prefix("sha256:") || value.length() != 71 {
    return false
  }
  for ch in value[7:] {
    if !((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')) {
      return false
    }
  }
  true
}

///|
fn normalized_mooncode_comparison_sessions(
  payload : Json,
) -> Result[Array[Json], String] {
  let sessions = json_array_items(payload, "sessions")
  if sessions.length() != 2 {
    return Err("A comparison requires exactly two branch sessions")
  }
  let normalized : Array[Json] = []
  let mut saw_a = false
  let mut saw_b = false
  for session in sessions {
    let label = json_string(session, "label", default="")
    let id = json_string(session, "id", default="").trim().to_owned()
    if !document_conversation_id_valid(id) {
      return Err("Comparison branch session identity is invalid")
    }
    if label == "A" {
      if saw_a {
        return Err("Comparison branch A is duplicated")
      }
      saw_a = true
    } else if label == "B" {
      if saw_b {
        return Err("Comparison branch B is duplicated")
      }
      saw_b = true
    } else {
      return Err("Comparison branches must be labeled A and B")
    }
    normalized.push({
      "label": label,
      "id": id,
      "status": json_string(session, "status", default="queued"),
      "event_count": json_int(session, "event_count", default=0).max(0),
      "verified_test_count": json_int(session, "verified_test_count", default=0).max(
        0,
      ),
      "pending_diff_count": json_int(session, "pending_diff_count", default=0).max(
        0,
      ),
    })
  }
  if !saw_a || !saw_b {
    return Err("Comparison must contain one A branch and one B branch")
  }
  Ok(normalized)
}

///|
async fn write_mooncode_comparisons(
  workspace_root : String,
  records : Array[Json],
) -> Unit {
  let path = mooncode_comparisons_path(workspace_root)
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
    ".mooncode-comparisons." +
    @desk.stable_id("comparison-write", @async.now().to_string()) +
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
async fn persist_mooncode_comparison(
  workspace_root : String,
  payload : Json,
) -> Result[Json, String] {
  let workspace_id = json_string(payload, "workspace_id", default="")
    .trim()
    .to_owned()
  let comparison_id = json_string(payload, "id", default="").trim().to_owned()
  let goal = json_string(payload, "goal", default="").trim().to_owned()
  let digest = json_string(payload, "baseline_request_digest", default="")
  let selected_branch = json_string(payload, "selected_branch", default="")
  if json_string(payload, "contract", default="") != MoonCodeComparisonContract {
    return Err("Unsupported MoonCode comparison contract")
  }
  if !document_conversation_id_valid(comparison_id) {
    return Err("Comparison identity is invalid")
  }
  if goal == "" || goal.length() > MoonCodeComparisonMaxGoalChars {
    return Err("Comparison goal is empty or too large")
  }
  if !mooncode_comparison_digest_valid(digest) {
    return Err("Comparison baseline digest is invalid")
  }
  if selected_branch != "" && selected_branch != "A" && selected_branch != "B" {
    return Err("Selected comparison branch must be A or B")
  }
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => return Err("Unknown workspace")
  }
  let context_path = json_string(payload, "context_path", default="")
    .trim()
    .to_owned()
  if context_path != "" &&
    resolve_workspace_existing_path(workspace.root_path, context_path) is None {
    return Err("Comparison context is outside this workspace")
  }
  let sessions = match normalized_mooncode_comparison_sessions(payload) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  mooncode_comparison_write_mutex.acquire()
  defer mooncode_comparison_write_mutex.release()
  let existing = read_json_array_file(mooncode_comparisons_path(workspace_root))
  let mut previous : Json? = None
  for record in existing {
    if json_string(record, "id", default="") == comparison_id {
      previous = Some(record)
      break
    }
  }
  let previous_revision = previous
    .map(record => json_int(record, "revision", default=0))
    .unwrap_or(0)
  let expected_revision = json_int(
    payload,
    "revision",
    default=previous_revision,
  )
  if expected_revision != previous_revision {
    return Err("Comparison revision conflict")
  }
  let created_at = previous
    .map(record => {
      json_string(record, "created_at", default=@async.now().to_string())
    })
    .unwrap_or(@async.now().to_string())
  let record : Json = {
    "contract": MoonCodeComparisonContract,
    "id": comparison_id,
    "workspace_id": workspace_id,
    "context_path": context_path,
    "baseline_request_digest": digest,
    "goal": goal,
    "sessions": Json::array(sessions),
    "selected_branch": selected_branch,
    "selected_at": json_string(payload, "selected_at", default=""),
    "revision": previous_revision + 1,
    "created_at": created_at,
    "updated_at": @async.now().to_string(),
    "evaluation_candidate": if selected_branch == "" {
      Json::null()
    } else {
      {
        "contract": "moongate.comparison_evaluation_candidate.v1",
        "comparison_id": comparison_id,
        "selected_branch": selected_branch,
        "baseline_request_digest": digest,
        "status": "awaiting-verified-outcome",
      }
    },
  }
  let next = upsert_record_by_id(existing, record)
  next.sort_by((left, right) => {
    json_string(right, "updated_at", default="").compare(
      json_string(left, "updated_at", default=""),
    )
  })
  while next.length() > MoonCodeComparisonMaxRecords {
    next.pop() |> ignore
  }
  write_mooncode_comparisons(workspace_root, next) catch {
    error => return Err("Could not persist MoonCode comparison: \{error}")
  }
  Ok(record)
}

///|
async fn handle_mooncode_comparisons(
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
  if find_workspace(workspace_root, workspace_id) is None {
    send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
    return
  }
  let records = read_json_array_file(mooncode_comparisons_path(workspace_root)).filter(record => {
      json_string(record, "workspace_id", default="") == workspace_id
    },
  )
  send_json(conn, method_, {
    "contract": "moondesk.mooncode_comparisons.v1",
    "workspace_id": workspace_id,
    "comparisons": Json::array(records),
  })
}

///|
async fn handle_save_mooncode_comparison(
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
  match persist_mooncode_comparison(workspace_root, payload) {
    Ok(record) => send_json(conn, method_, record)
    Err("Comparison revision conflict") =>
      send_api_error(
        conn, method_, 409, "Conflict", "Comparison changed on another client",
      )
    Err(message) => send_api_error(conn, method_, 400, "Bad Request", message)
  }
}
