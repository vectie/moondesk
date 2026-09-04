///|
const DocumentAutomationBindingContract : String = "moondesk.document_automation_binding.v1"

///|
const DocumentAutomationMaxBindings : Int = 1_024

///|
let document_automation_binding_mutex : @async.Mutex = Mutex()

///|
fn document_automation_bindings_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moondesk", "automations/document-bindings.v1.json",
  )
}

///|
async fn write_document_automation_bindings(
  workspace_root : String,
  records : Array[Json],
) -> Unit {
  let path = document_automation_bindings_path(workspace_root)
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
    ".document-automation-bindings." +
    @desk.stable_id("automation-binding-write", @async.now().to_string()) +
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
async fn save_document_automation_binding(
  workspace_root : String,
  goal_id : String,
  payload : Json,
) -> Unit {
  let workspace_id = json_string(payload, "target_book_id", default="")
  let conversation_id = json_string(payload, "conversation_id", default="")
  if goal_id == "" ||
    workspace_id == "" ||
    !document_conversation_id_valid(conversation_id) {
    return
  }
  let record : Json = {
    "id": goal_id,
    "contract": DocumentAutomationBindingContract,
    "goal_id": goal_id,
    "workspace_id": workspace_id,
    "conversation_id": conversation_id,
    "document_path": json_string(payload, "document_path", default=""),
    "source_policy": json_string(
      payload,
      "source_policy",
      default="workspace-only",
    ),
    "review_policy": json_string(
      payload,
      "review_policy",
      default="bookkeeper_review",
    ),
    "created_at": @async.now().to_string(),
  }
  document_automation_binding_mutex.acquire()
  defer document_automation_binding_mutex.release()
  let existing = read_json_array_file(
    document_automation_bindings_path(workspace_root),
  )
  let next = upsert_record_by_id(existing, record)
  while next.length() > DocumentAutomationMaxBindings {
    next.pop() |> ignore
  }
  write_document_automation_bindings(workspace_root, next)
}

///|
fn document_automation_result(binding : Json, watcher : Json) -> Json {
  let decision = json_string(watcher, "decision", default="NoChange")
  let run_id = json_string(watcher, "run_id", default="")
  let tick = json_int(watcher, "tick", default=0)
  let summary = json_string(
    watcher,
    "summary",
    default="Background work completed without a visible summary.",
  )
  {
    "contract": "moondesk.document_automation_result.v1",
    "kind": "background_result",
    "id": @desk.stable_id(
      "document-automation-result",
      json_string(binding, "goal_id", default="") +
      ":" +
      run_id +
      ":" +
      tick.to_string() +
      ":" +
      decision,
    ),
    "goal_id": json_string(binding, "goal_id", default=""),
    "conversation_id": json_string(binding, "conversation_id", default=""),
    "document_path": json_string(binding, "document_path", default=""),
    "decision": decision,
    "summary": summary,
    "run_id": run_id,
    "path": json_string(watcher, "path", default=""),
    "tick": tick,
    "warning": ["Failed", "NeedsReview"].contains(decision),
    "created_at": json_string(watcher, "created_at", default=""),
  }
}

///|
async fn document_automation_results_for_conversation(
  workspace_root : String,
  workspace_id : String,
  conversation_id : String,
) -> Array[Json] {
  let bindings = read_json_array_file(
    document_automation_bindings_path(workspace_root),
  ).filter(binding => {
    json_string(binding, "workspace_id", default="") == workspace_id &&
    json_string(binding, "conversation_id", default="") == conversation_id
  })
  if bindings.is_empty() {
    return []
  }
  let root = workspace_context(workspace_root).suite_root
  let watchers = read_watcher_records(root, 1_000)
  let results : Array[Json] = []
  for binding in bindings {
    let goal_id = json_string(binding, "goal_id", default="")
    for watcher in watchers {
      if json_string(watcher, "goal_id", default="") == goal_id {
        results.push(document_automation_result(binding, watcher))
      }
    }
  }
  results.sort_by((left, right) => {
    json_int(left, "tick", default=0).compare(
      json_int(right, "tick", default=0),
    )
  })
  results
}

///|
async fn handle_document_automation_results(
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
  send_json(conn, method_, {
    "contract": "moondesk.document_automation_results.v1",
    "workspace_id": workspace_id,
    "conversation_id": conversation_id,
    "results": Json::array(
      document_automation_results_for_conversation(
        workspace_root, workspace_id, conversation_id,
      ),
    ),
  })
}
