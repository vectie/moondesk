///|
// Serializes this bounded Desk planning path. Flow also owns native writer
// locks and immutable preparation identity; the generic executor stays denied.
let moonflow_plan_mutex : @async.Mutex = Mutex()

///|
type MoonFlowPlanningRun = async (@trusted_host.MoonFlowPlanningOperation) -> Result[
  String,
  String,
]

///|
fn moonflow_plan_request_id_valid(id : String) -> Bool {
  id.length() >= 8 &&
  id.length() <= 128 &&
  id.all(char => {
    char.is_ascii_alphabetic() ||
    char.is_ascii_digit() ||
    char == '-' ||
    char == '_'
  })
}

///|
fn moonflow_plan_relative(request_id : String) -> String {
  ".moonsuite/products/moondesk/flow-plans/desk-" + request_id
}

///|
async fn moonflow_plan_directory(root : String, relative : String) -> String {
  guard @fs.realpath(root) == root else {
    fail("The Flow workspace changed; reload this Book")
  }
  let mut path = root
  for name in relative.split("/") {
    guard name != "" && name != "." && name != ".." else {
      fail("Invalid preparation location")
    }
    path = path + "/" + name.to_owned()
    if !@fs.exists(path) {
      @fs.mkdir(path, permission=0o700)
    }
    guard @fs.kind(path, follow_symlink=false) == Directory &&
      @fs.realpath(path) == path else {
      fail("The Flow preparation directory is not a confined regular directory")
    }
  }
  path
}

///|
async fn moonflow_plan_read(root : String, relative : String) -> Json {
  let path = root + "/" + relative
  guard @fs.realpath(path) == path &&
    @fs.kind(path, follow_symlink=false) == Regular else {
    fail("Prepared plan evidence is missing or unsafe")
  }
  @json.parse(agent_export_bounded_text(path, 4 * 1024 * 1024))
}

///|
async fn moonflow_plan_freeze(path : String, value : Json) -> Unit {
  if @fs.exists(path) {
    guard @fs.realpath(path) == path &&
      @fs.kind(path, follow_symlink=false) == Regular &&
      @json.parse(agent_export_bounded_text(path, 4 * 1024 * 1024)) == value else {
      fail(
        "This request already retains different evidence; start a new preparation",
      )
    }
  } else {
    @fs.write_file(
      path,
      value.stringify(indent=2),
      create_mode=CreateNew,
      permission=0o600,
    )
  }
}

///|
fn moonflow_plan_changes(form : Json) -> Array[Json] {
  let source = json_object_field(form, "source_graph").unwrap_or(Json::null())
  let edits = match json_object_field(form, "edits") {
    Some(Array(values)) => values
    _ => []
  }
  let changes : Array[Json] = []
  for edit in edits {
    let id = json_string(edit, "work_item_id", default="")
    let original = moonflow_graph_items(source)
      .filter(item => moonflow_graph_item_id(item) == id)
      .get(0)
    if original is Some(original) {
      for
        field in [
          "input_artifacts", "depends_on", "acceptance_criteria", "timeout_ms",
        ] {
        let before = json_object_field(original, field).unwrap_or(Json::null())
        let after = json_object_field(edit, field).unwrap_or(Json::null())
        if before != after {
          changes.push({
            "work_item_id": id,
            "field": field,
            "before": before,
            "after": after,
          })
        }
      }
    } else {
      let template = match json_object_field(form, "added_templates") {
        Some(Object(values)) => values.get(id).unwrap_or(Json::null())
        _ => Json::null()
      }
      changes.push({
        "work_item_id": id,
        "field": "added_step",
        "before": Json::null(),
        "after": template,
      })
      for
        field in [
          "input_artifacts", "depends_on", "acceptance_criteria", "timeout_ms",
        ] {
        if json_object_field(edit, field) is Some(after) {
          changes.push({
            "work_item_id": id,
            "field": field,
            "before": Json::null(),
            "after": after,
          })
        }
      }
    }
  }
  for original in moonflow_graph_items(source) {
    let id = moonflow_graph_item_id(original)
    if !edits.any(edit => json_string(edit, "work_item_id", default="") == id) {
      changes.push({
        "work_item_id": id,
        "field": "removed_step",
        "before": id,
        "after": Json::null(),
      })
    }
  }
  changes
}

///|
fn moonflow_plan_result(
  workspace_id : String,
  request_id : String,
  receipt : Json,
  changes : Array[Json],
  applied? : Json,
  source_current? : Bool = true,
) -> Json {
  {
    "contract_id": "moondesk.flow-plan-result.v1",
    "ok": true,
    "status": if applied is Some(_) {
      "imported"
    } else {
      "prepared"
    },
    "message": if applied is Some(_) {
      "The child plan is imported. No work was executed."
    } else {
      "The child plan is prepared. Review changes before importing."
    },
    "workspace_id": workspace_id,
    "request_id": request_id,
    "receipt": receipt,
    "changes": changes,
    "source_current": source_current,
    "applied": match applied {
      Some(value) => value
      None => Json::null()
    },
    "dispatched": false,
  }
}

///|
async fn moonflow_plan_command(
  run : MoonFlowPlanningRun,
  operation : @trusted_host.MoonFlowPlanningOperation,
) -> Json {
  let body = match run(operation) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  @json.parse(body) catch {
    _ => fail("Flow returned unreadable planning evidence")
  }
}

///|
async fn moonflow_plan_handle_with(
  suite_root : String,
  workspace : @desk.DeskWorkspace,
  payload : Json,
  evaluated_at : String,
  run : MoonFlowPlanningRun,
) -> Json {
  moonflow_plan_mutex.acquire()
  defer moonflow_plan_mutex.release()
  let request_id = json_string(payload, "request_id", default="")
  let action = json_string(payload, "action", default="")
  guard moonflow_plan_request_id_valid(request_id) else {
    fail("Invalid plan request identity")
  }
  guard json_string(payload, "workspace_id", default="") == workspace.id else {
    fail("The selected Book changed; reload before preparing")
  }
  let relative = moonflow_plan_relative(request_id)
  let source_path = moonflow_source_graph_path(workspace.root_path)
  let source = if source_path == "" {
    if action == "inspect" {
      Json::null()
    } else {
      fail("The selected Book has no available declared work graph")
    }
  } else {
    moonflow_load_executable_graph(source_path) catch {
      error =>
        if action == "inspect" {
          Json::null()
        } else {
          fail(error.to_string())
        }
    }
  }
  let catalog = moonflow_resolve_capability_catalog(
    workspace.root_path,
    evaluated_at,
  )
  let catalog_digest = json_string(
    catalog.evidence,
    "catalog_digest",
    default="",
  )
  let source_bytes_digest = if source != Json::null() {
    "sha256:" +
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@fs.read_file(source_path).binary()),
    )
  } else {
    ""
  }
  if action == "prepare" {
    guard catalog.catalog is Some(catalog_value) else {
      fail(
        "The selected Book’s capability catalog is unavailable; refresh its setup",
      )
    }
    guard json_object_field(payload, "form") is Some(form) else {
      fail("Plan fields are missing")
    }
    guard json_object_field(form, "source_graph") == Some(source) else {
      fail(
        "The Book’s source graph changed. Your draft is retained; reload before preparing",
      )
    }
    let canonical_source = @fs.realpath(source_path)
    guard canonical_source.has_prefix(suite_root + "/") else {
      fail(
        "This Book’s source graph is outside the Flow workspace; select a Book within this suite before preparing",
      )
    }
    let form = @json.parse(form.stringify())
    guard form is Object(form_fields) else {
      fail("The plan form must be an object")
    }
    form_fields["source_ref"] = canonical_source[suite_root.length() + 1:]
      .to_owned()
      .to_json()
    guard form.stringify().length() <= 655360 else {
      fail("This plan exceeds the 640 KiB form limit")
    }
    let directory = moonflow_plan_directory(suite_root, relative)
    let request_path = directory + "/request.json"
    let request = if @fs.exists(request_path) {
      let existing = moonflow_plan_read(suite_root, relative + "/request.json")
      guard json_string(existing, "workspace_id", default="") == workspace.id &&
        json_object_field(existing, "form") == Some(form) &&
        json_string(existing, "source_bytes_digest", default="") ==
        source_bytes_digest &&
        json_string(existing, "catalog_digest", default="") == catalog_digest else {
        fail(
          "This preparation belongs to different source or catalog bytes; prepare a new child plan",
        )
      }
      existing
    } else {
      let value : Json = {
        "workspace_id": workspace.id,
        "form": form,
        "catalog_digest": catalog_digest,
        "source_bytes_digest": source_bytes_digest,
        "recorded_at": evaluated_at,
      }
      moonflow_plan_freeze(request_path, value)
      value
    }
    moonflow_plan_freeze(directory + "/form.json", form)
    moonflow_plan_freeze(directory + "/catalog.json", catalog_value)
    // Repeated HTTP clicks share the exact native draft and immutable receipt.
    let receipt = if @fs.exists(directory + "/receipt.json") {
      moonflow_plan_read(suite_root, relative + "/receipt.json")
    } else {
      let value = moonflow_plan_command(
        run,
        @trusted_host.PrepareForm(
          form_ref=relative + "/form.json",
          catalog_ref=relative + "/catalog.json",
          draft_id="desk-" + request_id,
          recorded_at=json_string(request, "recorded_at", default=""),
        ),
      )
      guard json_string(value, "contract_id", default="") ==
        "moonflow.declared-plan-preparation-receipt.v1" &&
        !json_bool(value, "dispatched", default=true) else {
        fail("Flow returned no valid non-executing preparation receipt")
      }
      moonflow_plan_freeze(directory + "/receipt.json", value)
      value
    }
    moonflow_plan_result(
      workspace.id,
      request_id,
      receipt,
      moonflow_plan_changes(form),
    )
  } else if action == "inspect" || action == "apply" {
    let request = moonflow_plan_read(suite_root, relative + "/request.json")
    guard json_string(request, "workspace_id", default="") == workspace.id else {
      fail("This plan belongs to another Book")
    }
    let form = json_object_field(request, "form").unwrap_or(Json::null())
    let source_current = source != Json::null() &&
      catalog.catalog is Some(_) &&
      json_object_field(form, "source_graph") == Some(source) &&
      json_string(request, "source_bytes_digest", default="") ==
      source_bytes_digest &&
      json_string(request, "catalog_digest", default="") == catalog_digest
    let receipt = moonflow_plan_read(suite_root, relative + "/receipt.json")
    let applied_path = suite_root + "/" + relative + "/applied.json"
    if action == "inspect" {
      let applied = if @fs.exists(applied_path) {
        Some(moonflow_plan_read(suite_root, relative + "/applied.json"))
      } else {
        None
      }
      moonflow_plan_result(
        workspace.id,
        request_id,
        receipt,
        moonflow_plan_changes(form),
        applied?,
        source_current~,
      )
    } else {
      guard source_current else {
        fail(
          "The source graph or capability catalog changed after preparation. The prepared packet is retained; prepare and review a new child before importing",
        )
      }
      let prepared = json_object_field(receipt, "prepared").unwrap_or(
        Json::null(),
      )
      let preparation_id = json_string(prepared, "preparation_id", default="")
      guard preparation_id.has_prefix("plan-") &&
        moonflow_safe_run_id(preparation_id) else {
        fail("Prepared child identity is missing")
      }
      // Flow rechecks frozen bytes, current health, and revision eligibility
      // under its own lock. Cached Desk receipts never authorize execution.
      let applied = moonflow_plan_command(
        run,
        @trusted_host.ApplyPrepared(
          preparation_id~,
          catalog_ref=relative + "/catalog.json",
          evaluated_at~,
        ),
      )
      guard json_string(applied, "contract_id", default="") ==
        "moonflow.declared-plan-apply-receipt.v1" &&
        json_string(applied, "preparation_id", default="") == preparation_id &&
        !json_bool(applied, "dispatched", default=true) else {
        fail(
          "Flow returned no matching non-executing import receipt; reload the retained result before retrying",
        )
      }
      moonflow_plan_freeze(applied_path, applied)
      moonflow_plan_result(
        workspace.id,
        request_id,
        receipt,
        moonflow_plan_changes(form),
        applied~,
      )
    }
  } else {
    fail("Unsupported plan action; choose prepare, inspect, or apply")
  }
}

///|
async fn handle_moonflow_plan(
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
  let workspace_id = json_string(payload, "workspace_id", default="")
  let request_id = json_string(payload, "request_id", default="")
  let result = try {
    guard find_workspace(workspace_root, workspace_id) is Some(workspace) else {
      fail("Select a Book before preparing a plan")
    }
    let suite_root = @fs.realpath(workspace_context(workspace_root).suite_root)
    moonflow_plan_handle_with(
      suite_root,
      workspace,
      payload,
      moonflow_server_utc_timestamp(),
      operation => {
        let runtime = match @trusted_host.moonflow_planning_runtime() {
          Ok(value) => value
          Err(message) => fail(message)
        }
        @trusted_host.run_moonflow_planning(runtime, suite_root, operation)
      },
    )
  } catch {
    error =>
      (
        {
          "contract_id": "moondesk.flow-plan-result.v1",
          "ok": false,
          "status": "blocked",
          "message": error.to_string(),
          "workspace_id": workspace_id,
          "request_id": request_id,
          "dispatched": false,
        } : Json)
  }
  send_json(conn, method_, result)
}

///|
async fn moonflow_plan_read_body(body : &@io.Reader) -> Json {
  let bytes = @buffer.Buffer(size_hint=8192)
  for ;; {
    guard body.read_some(max_len=8192) is Some(chunk) else { break }
    guard bytes.length() + chunk.length() <= 700000 else {
      fail("The plan request exceeds the 700 KiB limit")
    }
    bytes.write_bytes(chunk)
  }
  @json.parse(@encoding/utf8.decode(bytes.to_bytes()))
}
