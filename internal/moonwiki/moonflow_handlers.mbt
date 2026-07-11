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
      Some(projection) => projections.push(projection)
      None => ()
    }
  }
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
    Some(projection) => send_json(conn, method_, projection)
    None =>
      send_api_error(conn, method_, 404, "Not Found", "MoonFlow run not found")
  }
}
