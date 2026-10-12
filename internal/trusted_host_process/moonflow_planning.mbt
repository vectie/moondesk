///|
/// The planning bridge has no adapter, dispatch, execute, shell or generic
/// command variant. Browser requests cannot select its executable or argv.
pub(all) enum MoonFlowPlanningOperation {
  PrepareForm(
    form_ref~ : String,
    catalog_ref~ : String,
    draft_id~ : String,
    recorded_at~ : String
  )
  ApplyPrepared(
    preparation_id~ : String,
    catalog_ref~ : String,
    evaluated_at~ : String
  )
}

///|
pub struct MoonFlowPlanningRuntime {
  priv executable : String
  priv stamp : MoonBookExecutableStamp
}

///|
fn moonflow_planning_identifier(value : String) -> Bool {
  value.length() > 0 &&
  value.length() <= 160 &&
  !value.has_prefix("-") &&
  value.all(char => {
    char.is_ascii_alphabetic() ||
    char.is_ascii_digit() ||
    char == '-' ||
    char == '_'
  })
}

///|
fn moonflow_planning_ref(value : String) -> Bool {
  value.has_prefix(".moonsuite/products/moondesk/flow-plans/desk-") &&
  value.length() <= 512 &&
  !value.contains("..") &&
  value.all(char => {
    char.is_ascii_alphabetic() ||
    char.is_ascii_digit() ||
    char == '-' ||
    char == '_' ||
    char == '.' ||
    char == '/'
  }) &&
  !value.contains("//") &&
  !value.has_suffix("/")
}

///|
fn moonflow_planning_time(value : String) -> Bool {
  value.length() == 20 &&
  value.has_suffix("Z") &&
  value.all(char => {
    char.is_ascii_digit() ||
    char == '-' ||
    char == ':' ||
    char == 'T' ||
    char == 'Z'
  })
}

///|
fn moonflow_planning_arguments(
  workspace : String,
  operation : MoonFlowPlanningOperation,
) -> Result[Array[String], String] {
  guard safe_canonical_path_shape(workspace) else {
    return Err("Flow planning workspace must be canonical")
  }
  match operation {
    PrepareForm(form_ref~, catalog_ref~, draft_id~, recorded_at~) => {
      guard moonflow_planning_ref(form_ref) &&
        moonflow_planning_ref(catalog_ref) &&
        moonflow_planning_identifier(draft_id) &&
        moonflow_planning_time(recorded_at) else {
        return Err("Invalid bounded Flow preparation arguments")
      }
      Ok([
        "plan", "prepare-form", workspace, form_ref, catalog_ref, draft_id, recorded_at,
      ])
    }
    ApplyPrepared(preparation_id~, catalog_ref~, evaluated_at~) => {
      guard moonflow_planning_identifier(preparation_id) &&
        preparation_id.has_prefix("plan-") &&
        moonflow_planning_ref(catalog_ref) &&
        moonflow_planning_time(evaluated_at) else {
        return Err("Invalid bounded Flow import arguments")
      }
      Ok([
        "plan", "apply-prepared", workspace, preparation_id, catalog_ref, evaluated_at,
      ])
    }
  }
}

///|
/// Only host-owned configuration is read. No fallback to moon run, a shell,
/// ambient PATH, compilation, network access or a generic executor is used.
pub async fn moonflow_planning_runtime() -> Result[
  MoonFlowPlanningRuntime,
  String,
] {
  let executable = match @env.get_env_var("MOONDESK_MOONFLOW_BIN") {
    Some(value) => value
    None =>
      match @env.get_env_var("MOONFLOW_ROOT") {
        Some(root) => root + "/_build/native/release/build/cmd/main/main.exe"
        None =>
          return Err(
            "Configure a native Flow planning executable before preparing a plan",
          )
      }
  }
  let stamp = match moonbook_executable_stamp(executable) {
    Ok(stamp) => stamp
    Err(_) =>
      return Err(
        "The configured native Flow planning executable is unavailable",
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
  guard moonflow_planning_help_compatible(help) else {
    return Err(
      "The configured Flow executable needs prepare-form and apply-prepared support",
    )
  }
  guard moonbook_executable_stamp(executable) == Ok(stamp) else {
    return Err(
      "Flow executable changed during its planning compatibility check",
    )
  }
  Ok({ executable, stamp, })
}

///|
fn moonflow_planning_help_compatible(help : String) -> Bool {
  let lines = help.split("\n").map(line => line.trim().to_owned()).to_array()
  lines.contains(
    "moonflow plan prepare-form <workspace> <form-ref> <catalog-ref> <draft-id> <recorded-at>",
  ) &&
  lines.contains(
    "moonflow plan apply-prepared <workspace> <preparation-id> <catalog-ref> <evaluated-at>",
  )
}

///|
pub async fn run_moonflow_planning(
  runtime : MoonFlowPlanningRuntime,
  workspace : String,
  operation : MoonFlowPlanningOperation,
) -> Result[String, String] {
  let args = match moonflow_planning_arguments(workspace, operation) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  guard canonical_directory("Flow workspace", workspace) is Ok(_) else {
    return Err("Flow workspace is unavailable or changed")
  }
  guard moonbook_executable_stamp(runtime.executable) == Ok(runtime.stamp) else {
    return Err(
      "Flow executable changed; retry preparation with the configured runtime",
    )
  }
  let output = match
    moonbook_capture(
      runtime.executable,
      args,
      workspace,
      60_000,
      4 * 1024 * 1024,
    ) {
    Ok(output) => output
    Err(_) =>
      return Err(
        "Flow planning timed out, exceeded its output limit, or could not complete",
      )
  }
  let stdout = @utf8.decode(output.stdout) catch {
    _ => return Err("Flow returned invalid text")
  }
  let stderr = @utf8.decode(output.stderr) catch {
    _ => "Flow rejected this plan"
  }
  if output.status == 0 {
    Ok(stdout)
  } else {
    Err("Flow could not prepare/import this plan: " + stderr[:4096].to_owned())
  }
}
