///|
/// Resolve the installed owner executable without requiring a source checkout.
pub fn moonflow_executable() -> Result[String, String] {
  if @env.get_env_var("MOONDESK_MOONFLOW_BIN") is Some(value) && value != "" {
    return Ok(value)
  }
  if @env.get_env_var("LEPUSA_APP_DIR") is Some(root) && root != "" {
    return Ok(root + "/MacOS/moonflow")
  }
  if @env.get_env_var("MOONFLOW_ROOT") is Some(root) && root != "" {
    return Ok(root + "/_build/native/release/build/cmd/main/main.exe")
  }
  Err("The native Flow runtime is not installed")
}

///|
pub(all) enum MoonFlowServiceOperation {
  ValidateGraph(
    graph_path~ : String,
    catalog_path~ : String,
    evaluated_at~ : String
  )
  ImportGraph(
    graph_path~ : String,
    catalog_path~ : String,
    evaluated_at~ : String
  )
  Control(
    run_id~ : String,
    action~ : String,
    evaluated_at~ : String,
    detail~ : String
  )
  InspectCollaboration(workspace_id~ : String)
  ListHandovers
}

///|
pub struct MoonFlowServiceRuntime {
  priv executable : String
  priv stamp : MoonBookExecutableStamp
}

///|
fn moonflow_service_arguments(
  workspace : String,
  operation : MoonFlowServiceOperation,
) -> Result[Array[String], String] {
  guard safe_canonical_path_shape(workspace) else {
    return Err("Flow workspace is invalid")
  }
  match operation {
    ValidateGraph(graph_path~, catalog_path~, evaluated_at~)
    | ImportGraph(graph_path~, catalog_path~, evaluated_at~) => {
      guard safe_canonical_path_shape(graph_path) &&
        safe_canonical_path_shape(catalog_path) &&
        moonflow_planning_time(evaluated_at) else {
        return Err("Flow graph references are invalid")
      }
      let prefix = match operation {
        ValidateGraph(..) => ["validate-work-graph-capabilities"]
        _ => ["import-conformant-graph", workspace]
      }
      Ok(prefix + [graph_path, catalog_path, evaluated_at])
    }
    Control(run_id~, action~, evaluated_at~, detail~) => {
      guard moonflow_planning_identifier(run_id) &&
        moonflow_planning_time(evaluated_at) &&
        ["pause", "resume", "cancel", "narrow-authority"].contains(action) else {
        return Err("Flow control action is invalid")
      }
      Ok(["control", workspace, run_id, action, evaluated_at, detail])
    }
    InspectCollaboration(workspace_id~) => {
      guard moonflow_planning_identifier(workspace_id) else {
        return Err("Collaboration workspace is invalid")
      }
      Ok(["collaboration", "inspect", workspace, workspace_id])
    }
    ListHandovers => Ok(["handover", "list", workspace])
  }
}

///|
pub async fn moonflow_service_runtime() -> Result[
  MoonFlowServiceRuntime,
  String,
] {
  let executable = match moonflow_executable() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let stamp = match moonbook_executable_stamp(executable) {
    Ok(value) => value
    Err(_) => return Err("The installed Flow executable is unavailable")
  }
  let output = match
    moonbook_capture(executable, ["--help"], "/", 8_000, 131072) {
    Ok(value) if value.status == 0 => value
    _ => return Err("The installed Flow executable could not start")
  }
  let help = @utf8.decode(output.stdout) catch { _ => "" }
  guard help.contains(
      "moonflow import-conformant-graph <workspace> <graph.json> <catalog.json> <evaluated-at>",
    ) &&
    help.contains("moonflow collaboration inspect <workspace> <workspace-id>") &&
    help.contains("moonflow handover list <workspace>") &&
    moonbook_executable_stamp(executable) == Ok(stamp) else {
    return Err("The installed Flow executable needs an update")
  }
  Ok({ executable, stamp, })
}

///|
pub async fn run_moonflow_service(
  runtime : MoonFlowServiceRuntime,
  workspace : String,
  operation : MoonFlowServiceOperation,
) -> Result[Json, String] {
  let args = match moonflow_service_arguments(workspace, operation) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  guard canonical_directory("Flow workspace", workspace) is Ok(_) &&
    moonbook_executable_stamp(runtime.executable) == Ok(runtime.stamp) else {
    return Err("The Flow runtime or workspace changed; reload and try again")
  }
  let output = match
    moonbook_capture(
      runtime.executable,
      args,
      workspace,
      60_000,
      4 * 1024 * 1024,
    ) {
    Ok(value) => value
    Err(_) =>
      return Err("Flow did not respond; reload to check its saved state")
  }
  if output.status != 0 {
    let detail = @utf8.decode(output.stderr) catch {
      _ => "Flow rejected the request"
    }
    return Err(detail[:4096].to_owned())
  }
  try @json.parse(@utf8.decode(output.stdout)) catch {
    _ => Err("Flow returned an unreadable response")
  } noraise {
    value => Ok(value)
  }
}
