///|
fn moonflow_runs_root(workspace_root : String) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    ".moonsuite/products/moonflow/runs",
  )
}

///|
fn moonflow_safe_run_id(run_id : String) -> Bool {
  !run_id.trim().is_empty() &&
  !run_id.contains("/") &&
  !run_id.contains("\\") &&
  !run_id.contains("..")
}

///|
fn moonflow_graph_run_id(graph : Json) -> String {
  json_string(
    graph,
    "graph_id",
    default=json_string(graph, "run_id", default=""),
  )
}

///|
async fn handle_moonflow_import_selected(
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
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Select a MoonBook first")
      return
    }
  }
  let candidates = ["flow/draft-work-graph.json", "flow/work-graph.json"]
  let mut graph_path = ""
  for candidate in candidates {
    let path = @pathx.join(workspace.root_path, candidate)
    if graph_path == "" && @fs.exists(path) {
      graph_path = path
    }
  }
  if graph_path == "" {
    send_json(
      conn,
      method_,
      api_contract_response(
        { "book_id": workspace_id, "run_id": "" },
        ok=false,
        status="declaration_missing",
        message="This MoonBook has no executable Work graph yet",
        next_action="create_executable_document_in_wiki",
      ),
    )
    return
  }
  let moonflow_root = @sys.get_env_var("MOONFLOW_ROOT").unwrap_or("")
  if moonflow_root == "" || !@fs.exists(@pathx.join(moonflow_root, "moon.mod")) {
    send_json(
      conn,
      method_,
      api_contract_response(
        { "book_id": workspace_id, "run_id": "" },
        ok=false,
        status="moonflow_service_missing",
        message="MoonFlow is installed but its workspace service is not enabled",
        next_action="enable_moonflow_in_moongate",
      ),
    )
    return
  }
  let graph = @json.parse(@fs.read_file(graph_path).text()) catch {
    _ => Json::object({})
  }
  let run_id = moonflow_graph_run_id(graph)
  let moon = moonclaw_default_moon_command()
  let code = @async.with_timeout_opt(30000, () => {
    run_process_quiet(moon, [
      "-C",
      moonflow_root,
      "run",
      "cmd/main",
      "--",
      "import-graph",
      workspace_context(workspace_root).suite_root,
      graph_path,
    ])
  }).unwrap_or(-2)
  send_json(
    conn,
    method_,
    api_contract_response(
      { "book_id": workspace_id, "run_id": run_id },
      ok=code == 0,
      status=if code == 0 {
        "imported"
      } else if code == -2 {
        "import_timed_out"
      } else {
        "import_failed"
      },
      message=if code == 0 {
        "Executable document imported into MoonFlow"
      } else if code == -2 {
        "MoonFlow preparation exceeded 30 seconds"
      } else {
        "MoonFlow could not import this Work graph"
      },
      next_action=if code == 0 {
        "open_run"
      } else if code == -2 {
        "check_moonflow_service"
      } else {
        "review_work_graph"
      },
    ),
  )
}

///|
async fn moonflow_projection(path : String) -> Json? {
  if !@fs.exists(path) {
    return None
  }
  Some(@json.parse(@fs.read_file(path).text())) catch {
    _ => None
  }
}

///|
async fn moonflow_json_or(path : String, fallback : Json) -> Json {
  match moonflow_projection(path) {
    Some(value) => value
    None => fallback
  }
}

///|
fn moonflow_authority_rank(authority : String) -> Int? {
  match authority {
    "observe" => Some(0)
    "cognitive-maintenance" => Some(1)
    "sandbox-execution" => Some(2)
    "workspace-mutation" => Some(3)
    "external-effect" => Some(4)
    "physical-effect" => Some(5)
    _ => None
  }
}

///|
async fn moonflow_enriched_projection(
  run_root : String,
  projection : Json,
) -> Json {
  let fields : Map[String, Json] = {}
  match projection {
    Object(existing) =>
      for key, value in existing {
        fields[key] = value
      }
    _ => return projection
  }
  fields["autonomy_binding"] = moonflow_json_or(
    @pathx.join(run_root, "autonomy-binding.json"),
    {
      "contract_id": "moonflow.autonomy-binding.v1",
      "run_id": json_string(projection, "run_id", default=""),
      "envelope": {
        "envelope_id": "",
        "mode": "not-bound",
        "expires_at": "",
        "revoked": false,
        "external_effects_allowed": false,
        "physical_effects_allowed": false,
        "budget": {
          "model_tokens": 0,
          "tool_calls": 0,
          "storage_bytes": 0,
          "attempts": 0,
          "concurrency": 0,
        },
      },
      "usage_ref": "",
      "usage": {
        "model_tokens": 0,
        "tool_calls": 0,
        "storage_bytes": 0,
        "attempts": 0,
        "concurrency": 0,
      },
      "recorded_at": "",
    },
  )
  fields["intervention_scorecard"] = moonflow_json_or(
    @pathx.join(run_root, "intervention-scorecard.json"),
    {
      "contract_id": "moonflow.intervention-scorecard.v1",
      "run_id": json_string(projection, "run_id", default=""),
      "required_intervention_count": 0,
      "hidden_orchestration_count": 0,
      "normal_path_manual_count": 0,
      "unattended_qualified": false,
      "finalization_findings": [],
      "recorded_at": "",
    },
  )
  fields["run_control"] = moonflow_json_or(
    @pathx.join(run_root, "control.json"),
    {
      "contract_id": "moonflow.run-control.v1",
      "run_id": json_string(projection, "run_id", default=""),
      "state": "running",
      "authority_ceiling": "",
      "reason": "",
      "recorded_at": "",
    },
  )
  Json::object(fields)
}

///|
async fn handle_moonflow_control(
  workspace_root : String,
  run_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !moonflow_safe_run_id(run_id) {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid MoonFlow run id")
    return
  }
  let run_root = @pathx.join(moonflow_runs_root(workspace_root), run_id)
  let projection_path = @pathx.join(run_root, "projection.json")
  if !@fs.exists(projection_path) {
    send_api_error(conn, method_, 404, "Not Found", "MoonFlow run not found")
    return
  }
  let projection = @json.parse(@fs.read_file(projection_path).text()) catch {
    _ => {
      send_api_error(
        conn, method_, 409, "Conflict", "Invalid MoonFlow projection",
      )
      return
    }
  }
  if ["accepted", "blocked", "failed"].contains(
      json_string(projection, "outcome", default=""),
    ) {
    send_api_error(
      conn, method_, 409, "Conflict", "Terminal runs cannot be controlled",
    )
    return
  }
  let payload = match read_json_body(body) {
    Some(value) => value
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let action = json_string(payload, "action", default="")
  let detail = json_string(payload, "detail", default="")
  let recorded_at = json_string(payload, "recorded_at", default="")
  if recorded_at.trim().is_empty() {
    send_api_error(conn, method_, 400, "Bad Request", "recorded_at is required")
    return
  }
  let control_path = @pathx.join(run_root, "control.json")
  let existing = moonflow_json_or(control_path, {
    "contract_id": "moonflow.run-control.v1",
    "run_id": run_id,
    "state": "running",
    "authority_ceiling": "",
    "reason": "",
    "recorded_at": recorded_at,
  })
  let existing_fields = match existing {
    Object(values) => values
    _ => {
      send_api_error(
        conn, method_, 409, "Conflict", "Invalid run control state",
      )
      return
    }
  }
  let mut state = json_string(existing, "state", default="running")
  let mut ceiling = json_string(existing, "authority_ceiling", default="")
  match action {
    "pause" => state = "paused"
    "resume" =>
      if state == "cancelled" {
        send_api_error(
          conn, method_, 409, "Conflict", "Cancelled runs cannot resume",
        )
        return
      } else {
        state = "running"
      }
    "cancel" => state = "cancelled"
    "narrow-authority" => {
      let proposed_rank = match moonflow_authority_rank(detail) {
        Some(value) => value
        None => {
          send_api_error(
            conn, method_, 400, "Bad Request", "Invalid authority ceiling",
          )
          return
        }
      }
      if !ceiling.is_empty() {
        let current_rank = moonflow_authority_rank(ceiling).unwrap_or(-1)
        if current_rank < proposed_rank {
          send_api_error(
            conn, method_, 409, "Conflict", "Authority may only be narrowed",
          )
          return
        }
      }
      ceiling = detail
    }
    _ => {
      send_api_error(
        conn, method_, 400, "Bad Request", "Unsupported control action",
      )
      return
    }
  }
  ignore(existing_fields)
  let control : Json = {
    "contract_id": "moonflow.run-control.v1",
    "run_id": run_id,
    "state": state,
    "authority_ceiling": ceiling,
    "reason": if action == "narrow-authority" {
      ""
    } else {
      detail
    },
    "recorded_at": recorded_at,
  }
  @fsx.write_to_file(
    control_path,
    control.stringify(indent=2) + "\n",
    create=0o644,
  )
  send_json(conn, method_, control)
}

///|
fn sort_moonflow_projections(projections : Array[Json]) -> Unit {
  projections.sort_by(fn(left, right) {
    let right_revision = json_string(right, "declaration_revision", default="")
    let left_revision = json_string(left, "declaration_revision", default="")
    let by_length = right_revision.length().compare(left_revision.length())
    if by_length != 0 {
      return by_length
    }
    let by_revision = right_revision.compare(left_revision)
    if by_revision != 0 {
      return by_revision
    }
    json_string(right, "run_id", default="").compare(
      json_string(left, "run_id", default=""),
    )
  })
}

///|
async fn handle_moonflow_runs(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = moonflow_runs_root(workspace_root)
  let projections : Array[Json] = []
  for run_id in read_directory_names(root, include_hidden=false) {
    if !moonflow_safe_run_id(run_id) {
      continue
    }
    match
      moonflow_projection(
        @pathx.join(@pathx.join(root, run_id), "projection.json"),
      ) {
      Some(projection) =>
        projections.push(
          moonflow_enriched_projection(@pathx.join(root, run_id), projection),
        )
      None => ()
    }
  }
  sort_moonflow_projections(projections)
  send_json(conn, method_, Json::array(projections))
}

///|
async fn handle_moonflow_run(
  workspace_root : String,
  run_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !moonflow_safe_run_id(run_id) {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid MoonFlow run id")
    return
  }
  let path = @pathx.join(
    @pathx.join(moonflow_runs_root(workspace_root), run_id),
    "projection.json",
  )
  match moonflow_projection(path) {
    Some(projection) =>
      send_json(
        conn,
        method_,
        moonflow_enriched_projection(
          @pathx.join(moonflow_runs_root(workspace_root), run_id),
          projection,
        ),
      )
    None =>
      send_api_error(conn, method_, 404, "Not Found", "MoonFlow run not found")
  }
}
