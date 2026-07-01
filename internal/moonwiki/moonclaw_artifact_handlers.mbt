///|
async fn handle_moonclaw_artifacts(
  workspace_root : String,
  run_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match find_run(workspace_root, run_id) {
    Some(run) =>
      match find_workspace(workspace_root, run.workspace_id) {
        Some(workspace) =>
          send_json(
            conn,
            method_,
            run_artifacts(workspace, run.run_id, run.run_root).to_json(),
          )
        None =>
          send_api_error(
            conn, method_, 404, "Not Found", "Run workspace is no longer available",
          )
      }
    None => send_api_error(conn, method_, 404, "Not Found", "Unknown run")
  }
}

///|
async fn find_run(workspace_root : String, run_id : String) -> RunRef? {
  for workspace in discover_workspaces(workspace_root) {
    let run_root = moonclaw_jobs_root(workspace.root_path)
    let candidate = @pathx.join(run_root, run_id)
    if is_directory(candidate) {
      return Some({ workspace_id: workspace.id, run_id, run_root: candidate })
    }
  }
  None
}

///|
async fn run_artifacts(
  workspace : @desk.DeskWorkspace,
  run_id : String,
  run_root : String,
) -> Array[@desk.DeskRunArtifact] {
  let artifacts : Array[@desk.DeskRunArtifact] = []
  for artifact_name in ["report.md", "result.json"] {
    let absolute = @pathx.join(run_root, artifact_name)
    if @fs.exists(absolute) {
      let path = moonclaw_run_relative_path(run_id, artifact_name)
      artifacts.push(
        @desk.run_artifact(id=@desk.stable_id(run_id, path), path~),
      )
    }
  }
  let outputs_root = @pathx.join(run_root, "outputs")
  for name in read_directory_names(outputs_root, include_hidden=false) {
    if artifacts.length() >= 32 {
      break
    }
    if !(name.has_suffix(".md") || name.has_suffix(".json")) {
      continue
    }
    let absolute = @pathx.join(outputs_root, name)
    if @fs.exists(absolute) && !is_directory(absolute) {
      let path = moonclaw_run_relative_path(
        run_id,
        @pathx.join("outputs", name),
      )
      artifacts.push(
        @desk.run_artifact(id=@desk.stable_id(run_id, path), path~),
      )
    }
  }
  ignore(workspace)
  artifacts
}
