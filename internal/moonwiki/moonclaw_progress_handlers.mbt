///|
async fn handle_moonclaw_progress(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requested_workspace = query_value(request_path, "workspace")
  let summary = moonclaw_progress_summary(workspace_root, requested_workspace)
  send_json(conn, method_, summary)
}

///|
async fn handle_moonclaw_runs(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let requested_workspace = query_value(request_path, "workspace")
  let runs : Array[@desk.DeskRunProjection] = []
  for workspace in discover_workspaces(workspace_root) {
    match requested_workspace {
      Some(id) if id != workspace.id => continue
      _ => ()
    }
    let run_root = moonclaw_jobs_root(workspace.root_path)
    let names = read_directory_names(run_root, include_hidden=false)
    let start = if names.length() > 80 { names.length() - 80 } else { 0 }
    let mut index = start
    while index < names.length() {
      let name = names[index]
      index += 1
      if !name.has_prefix("run-") {
        continue
      }
      let absolute = @pathx.join(run_root, name)
      if !is_directory(absolute) {
        continue
      }
      let artifacts = run_artifacts(workspace, name, absolute)
      let status = if @fs.exists(@pathx.join(absolute, "result.json")) {
        "ready"
      } else {
        "available"
      }
      runs.push(
        @desk.run_projection(
          run_id=name,
          book_id=workspace.id,
          status~,
          phase="workspace",
          summary="MoonClaw run workspace with \{artifacts.length()} visible artifacts.",
          artifacts~,
        ),
      )
    }
  }
  send_json(conn, method_, runs.to_json())
}
