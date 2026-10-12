///|
type MoonFlowSingleStepRun = async (@trusted_host.MoonFlowSingleStepOperation) -> Result[
  String,
  String,
]

///|
fn moonflow_single_step_identifier(value : String) -> Bool {
  value != "" &&
  value.length() <= 128 &&
  !value.has_prefix("-") &&
  value.all(char => {
    char.is_ascii_alphabetic() ||
    char.is_ascii_digit() ||
    char == '-' ||
    char == '_'
  })
}

///|
fn moonflow_single_step_payload_valid(payload : Json) -> Bool {
  guard payload is Object(fields) && fields.length() == 5 else { return false }
  fields
  .iter()
  .all(pair => {
    ["workspace_id", "run_id", "work_item_id", "request_id", "action"].contains(
      pair.0,
    )
  }) &&
  ["run_id", "work_item_id", "request_id"].all(field => {
    moonflow_single_step_identifier(json_string(payload, field, default=""))
  }) &&
  ["execute", "reconcile"].contains(json_string(payload, "action", default=""))
}

///|
fn moonflow_single_step_response(
  payload : Json,
  status : String,
  message : String,
  result? : Json,
) -> Json {
  {
    "contract_id": "moondesk.flow-single-step-result.v1",
    "workspace_id": json_string(payload, "workspace_id", default=""),
    "run_id": json_string(payload, "run_id", default=""),
    "work_item_id": json_string(payload, "work_item_id", default=""),
    "request_id": json_string(payload, "request_id", default=""),
    "status": status,
    "message": message,
    "reconcile_required": status == "reconcile-required",
    "result": result.unwrap_or(Json::null()),
  }
}

///|
fn moonflow_single_step_book_matches(
  workspace : @desk.DeskWorkspace,
  projection : Json,
) -> Bool {
  let book = json_string(projection, "book_id", default="")
  book == workspace.id ||
  book == workspace.root_path ||
  (
    book != "" &&
    !book.contains("/") &&
    workspace.root_path.has_suffix("/" + book) &&
    workspace.id == @desk.stable_id("book", book)
  )
}

///|
async fn moonflow_single_step_handle_with(
  suite_root : String,
  workspace : @desk.DeskWorkspace,
  payload : Json,
  recorded_at : String,
  run : MoonFlowSingleStepRun,
) -> Json {
  guard moonflow_single_step_payload_valid(payload) &&
    json_string(payload, "workspace_id", default="") == workspace.id else {
    fail(
      "Invalid digital-step request. Select one Book, run and item; browser commands or configuration are not accepted.",
    )
  }
  guard @fs.realpath(suite_root) == suite_root &&
    @fs.realpath(workspace.root_path) == workspace.root_path &&
    workspace.root_path.has_prefix(suite_root + "/") else {
    fail(
      "The selected Book is outside this Flow workspace or has changed; reload the Book",
    )
  }
  let run_id = json_string(payload, "run_id", default="")
  let item_id = json_string(payload, "work_item_id", default="")
  let request_id = json_string(payload, "request_id", default="")
  let relative = ".moonsuite/products/moonflow/runs/" + run_id
  let projection = moonflow_plan_read(suite_root, relative + "/projection.json")
  guard json_string(projection, "run_id", default="") == run_id &&
    moonflow_single_step_book_matches(workspace, projection) else {
    fail("This imported run does not belong to the selected Book")
  }
  guard moonflow_graph_items(projection).any(item => {
    json_string(item, "work_item_id", default="") == item_id
  }) else {
    fail("The selected item is not in this imported run")
  }
  let operation = if json_string(payload, "action", default="") == "execute" {
    @trusted_host.ExecuteOne(run_id~, item_id~, request_id~, recorded_at~)
  } else {
    @trusted_host.ReconcileOne(run_id~, item_id~, request_id~, recorded_at~)
  }
  let outcome = run(operation) catch {
    error =>
      return moonflow_single_step_response(
        payload,
        "reconcile-required",
        "The host could not confirm the original action: " + error.to_string(),
      )
  }
  let raw = match outcome {
    Ok(value) => value
    Err(message) =>
      return moonflow_single_step_response(
        payload, "reconcile-required", message,
      )
  }
  let result = @json.parse(raw) catch {
    _ =>
      return moonflow_single_step_response(
        payload, "reconcile-required", "Flow returned unreadable evidence. Reconcile this same action before continuing.",
      )
  }
  if json_string(result, "contract_id", default="") ==
    "moonflow.single-step-blocker.v1" &&
    json_string(result, "run_id", default="") == run_id &&
    json_string(result, "work_item_id", default="") == item_id &&
    json_string(result, "request_id", default="") == request_id &&
    json_string(result, "status", default="") == "blocked" &&
    json_bool(result, "no_attempt_created", default=false) {
    return moonflow_single_step_response(
      payload,
      "blocked",
      json_string(result, "message", default="Host setup needs correction"),
      result~,
    )
  }
  let qualification = json_object_field(result, "qualification").unwrap_or(
    Json::null(),
  )
  guard json_string(result, "contract_id", default="") ==
    "moonflow.single-step-result.v1" &&
    json_string(result, "run_id", default="") == run_id &&
    json_string(result, "work_item_id", default="") == item_id &&
    json_string(result, "request_id", default="") == request_id &&
    ["review", "reconcile-required", "not-applied", "failed"].contains(
      json_string(result, "status", default=""),
    ) &&
    json_string(qualification, "evidence_class", default="") ==
    "fixture-reference-only" &&
    !json_bool(qualification, "production_qualified", default=true) &&
    !json_bool(qualification, "physical_authority", default=true) else {
    return moonflow_single_step_response(
      payload, "reconcile-required", "Flow evidence did not match this action or its digital-only boundary. Reconcile the original action.",
    )
  }
  moonflow_single_step_response(
    payload,
    json_string(result, "status", default=""),
    json_string(result, "message", default=""),
    result~,
  )
}

///|
/// Project only safe action identity and outcome. Adapter bodies and trusted
/// configuration are intentionally absent from browser run responses.
async fn moonflow_single_step_actions(
  run_root : String,
  projection : Json,
) -> Array[Json] {
  let actions : Array[Json] = []
  for item in moonflow_graph_items(projection) {
    let id = json_string(item, "work_item_id", default="")
    if !moonflow_single_step_identifier(id) {
      continue
    }
    let path = run_root + "/single-step/" + id + ".action.json"
    if !@fs.exists(path) {
      continue
    }
    let value = try {
      guard @fs.realpath(path) == path &&
        @fs.kind(path, follow_symlink=false) == Regular else {
        fail("Unsafe action record")
      }
      @json.parse(agent_export_bounded_text(path, 4 * 1024 * 1024))
    } catch {
      _ => continue
    }
    let request = json_string(value, "request_id", default="")
    guard json_string(value, "contract_id", default="") ==
      "moonflow.single-step-action.v1" &&
      json_string(value, "run_id", default="") ==
      json_string(projection, "run_id", default="") &&
      json_string(value, "work_item_id", default="") == id &&
      moonflow_single_step_identifier(request) else {
      continue
    }
    actions.push({
      "work_item_id": id,
      "request_id": request,
      "status": json_string(value, "status", default="reconcile-required"),
      "message": json_string(
        value,
        "message",
        default="Reconcile the retained action before continuing",
      ),
    })
  }
  actions
}

///|
fn moonflow_single_step_setup() -> Json {
  let available = @env.get_env_var("MOONDESK_MOONFLOW_BIN").unwrap_or("") != "" &&
    @env.get_env_var("MOONDESK_MOONFLOW_SINGLE_STEP_CONFIG").unwrap_or("") != ""
  {
    "configured": available,
    "message": if available {
      "One digital Mold step uses the configured host runtime and existing Gate authority. Success stops at Review."
    } else {
      "Digital step setup is missing. The host needs MOONDESK_MOONFLOW_BIN and MOONDESK_MOONFLOW_SINGLE_STEP_CONFIG with existing Gate authority. No new grant is created here."
    },
  }
}

///|
async fn handle_moonflow_single_step(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = moonflow_plan_read_body(body) catch {
    error => {
      send_api_error(conn, method_, 400, "Bad Request", error.to_string())
      return
    }
  }
  let result = try {
    guard moonflow_single_step_payload_valid(payload) else {
      fail("Invalid digital-step request fields")
    }
    guard find_workspace(
        workspace_root,
        json_string(payload, "workspace_id", default=""),
      )
      is Some(workspace) else {
      fail("Select a Book before running one digital step")
    }
    let runtime = match @trusted_host.moonflow_single_step_runtime() {
      Ok(runtime) => runtime
      Err(message) => {
        send_json(
          conn,
          method_,
          moonflow_single_step_response(payload, "blocked", message),
        )
        return
      }
    }
    let suite_root = @fs.realpath(workspace_context(workspace_root).suite_root)
    moonflow_single_step_handle_with(
      suite_root,
      workspace,
      payload,
      moonflow_server_utc_timestamp(),
      operation => {
        @trusted_host.run_moonflow_single_step(runtime, suite_root, operation)
      },
    )
  } catch {
    error =>
      moonflow_single_step_response(payload, "blocked", error.to_string())
  }
  send_json(conn, method_, result)
}
