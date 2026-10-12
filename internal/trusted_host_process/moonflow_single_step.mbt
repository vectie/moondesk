///|
/// This bridge deliberately has only two fixed digital-step operations. It
/// cannot invoke an observer, reviewer, shell, generic executor or next item.
pub(all) enum MoonFlowSingleStepOperation {
  ExecuteOne(
    run_id~ : String,
    item_id~ : String,
    request_id~ : String,
    recorded_at~ : String
  )
  ReconcileOne(
    run_id~ : String,
    item_id~ : String,
    request_id~ : String,
    recorded_at~ : String
  )
}

///|
pub struct MoonFlowSingleStepRuntime {
  priv executable : String
  priv stamp : MoonBookExecutableStamp
  priv configuration_ref : String
}

///|
fn moonflow_single_step_configuration_ref(value : String) -> Bool {
  value != "" &&
  value.length() <= 512 &&
  !value.has_prefix("/") &&
  !value.has_prefix("-") &&
  !value.contains("..") &&
  !value.contains("//") &&
  !value.has_suffix("/") &&
  value.all(char => {
    char.is_ascii_alphabetic() ||
    char.is_ascii_digit() ||
    char == '-' ||
    char == '_' ||
    char == '.' ||
    char == '/'
  })
}

///|
fn moonflow_single_step_arguments(
  workspace : String,
  configuration_ref : String,
  operation : MoonFlowSingleStepOperation,
) -> Result[Array[String], String] {
  let (action, run, item, request, time) = match operation {
    ExecuteOne(run_id~, item_id~, request_id~, recorded_at~) =>
      ("execute-one", run_id, item_id, request_id, recorded_at)
    ReconcileOne(run_id~, item_id~, request_id~, recorded_at~) =>
      ("reconcile-one", run_id, item_id, request_id, recorded_at)
  }
  guard safe_canonical_path_shape(workspace) &&
    moonflow_single_step_configuration_ref(configuration_ref) &&
    moonflow_planning_identifier(run) &&
    moonflow_planning_identifier(item) &&
    moonflow_planning_identifier(request) &&
    moonflow_planning_time(time) else {
    return Err("Invalid bounded Flow single-step arguments")
  }
  Ok([action, workspace, run, item, request, configuration_ref, time])
}

///|
fn moonflow_single_step_help_compatible(help : String) -> Bool {
  let lines = help.split("\n").map(line => line.trim().to_owned()).to_array()
  lines.contains(
    "moonflow execute-one <workspace> <run-id> <item-id> <request-id> <configuration-ref> <recorded-at>",
  ) &&
  lines.contains(
    "moonflow reconcile-one <workspace> <run-id> <item-id> <request-id> <configuration-ref> <recorded-at>",
  )
}

///|
pub async fn moonflow_single_step_runtime() -> Result[
  MoonFlowSingleStepRuntime,
  String,
] {
  let executable = match @env.get_env_var("MOONDESK_MOONFLOW_BIN") {
    Some(value) if value != "" => value
    _ =>
      return Err(
        "Digital step setup is missing. Configure MOONDESK_MOONFLOW_BIN with the trusted native Flow executable.",
      )
  }
  let configuration_ref = match
    @env.get_env_var("MOONDESK_MOONFLOW_SINGLE_STEP_CONFIG") {
    Some(value) if moonflow_single_step_configuration_ref(value) => value
    _ =>
      return Err(
        "Digital step setup is missing. Configure MOONDESK_MOONFLOW_SINGLE_STEP_CONFIG with the host-owned workspace-relative configuration and existing Gate authority.",
      )
  }
  let stamp = match moonbook_executable_stamp(executable) {
    Ok(stamp) => stamp
    Err(_) =>
      return Err(
        "The configured native Flow digital-step executable is unavailable or unsafe",
      )
  }
  let help = match
    moonbook_capture(executable, ["--help"], "/", 8_000, 131072) {
    Ok(output) if output.status == 0 =>
      @utf8.decode(output.stdout) catch {
        _ => ""
      }
    _ => ""
  }
  guard moonflow_single_step_help_compatible(help) else {
    return Err(
      "The configured Flow executable needs execute-one and reconcile-one support",
    )
  }
  guard moonbook_executable_stamp(executable) == Ok(stamp) else {
    return Err(
      "Flow executable changed during the digital-step compatibility check",
    )
  }
  Ok({ executable, stamp, configuration_ref, })
}

///|
pub async fn run_moonflow_single_step(
  runtime : MoonFlowSingleStepRuntime,
  workspace : String,
  operation : MoonFlowSingleStepOperation,
) -> Result[String, String] {
  let arguments = match
    moonflow_single_step_arguments(
      workspace,
      runtime.configuration_ref,
      operation,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  guard canonical_directory("Flow workspace", workspace) is Ok(_) &&
    moonbook_executable_stamp(runtime.executable) == Ok(runtime.stamp) else {
    return Err(
      "The Flow workspace or executable changed; reconcile the original action before continuing",
    )
  }
  let output = match
    moonbook_capture(
      runtime.executable,
      arguments,
      workspace,
      120_000,
      4 * 1024 * 1024,
    ) {
    Ok(value) => value
    Err(_) =>
      return Err(
        "Flow response was interrupted or exceeded its limit. Reconcile the original action; do not run it again.",
      )
  }
  let stdout = @utf8.decode(output.stdout) catch {
    _ =>
      return Err(
        "Flow returned unreadable evidence; reconcile the original action",
      )
  }
  if output.status == 0 {
    Ok(stdout)
  } else {
    let stderr = @utf8.decode(output.stderr) catch {
      _ => "Flow did not complete"
    }
    Err("Flow could not confirm this action: " + stderr[:4096].to_owned())
  }
}
