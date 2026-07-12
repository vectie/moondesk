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
  Json::object(fields)
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
