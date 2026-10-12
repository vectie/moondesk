///|
/// Existing review inspection and fixed review mutation only. There is no
/// grant, membership, run acceptance, adapter or generic command variant.
pub(all) enum MoonFlowReviewOperation {
  InspectReviewWorkspace(workspace_id~ : String)
  BeginExistingReview(workspace_id~ : String, mutation_ref~ : String)
  DecideExistingReview(workspace_id~ : String, mutation_ref~ : String)
}

///|
pub struct MoonFlowReviewRuntime {
  priv executable : String
  priv stamp : MoonBookExecutableStamp
}

///|
fn moonflow_review_arguments(
  workspace : String,
  operation : MoonFlowReviewOperation,
) -> Result[Array[String], String] {
  guard safe_canonical_path_shape(workspace) else {
    return Err("Invalid collaboration workspace")
  }
  match operation {
    InspectReviewWorkspace(workspace_id~) => {
      guard moonflow_planning_identifier(workspace_id) else {
        return Err("Invalid review workspace identity")
      }
      Ok(["collaboration", "inspect", workspace, workspace_id])
    }
    BeginExistingReview(workspace_id~, mutation_ref~)
    | DecideExistingReview(workspace_id~, mutation_ref~) => {
      guard moonflow_planning_identifier(workspace_id) &&
        mutation_ref.has_prefix(
          ".moonsuite/products/moondesk/review-mutations/",
        ) &&
        mutation_ref.has_suffix("/mutation.json") &&
        moonflow_single_step_configuration_ref(mutation_ref) else {
        return Err("Invalid fixed review mutation reference")
      }
      Ok([
        "collaboration",
        "apply",
        workspace,
        workspace_id,
        workspace + "/" + mutation_ref,
      ])
    }
  }
}

///|
pub async fn moonflow_review_runtime() -> Result[MoonFlowReviewRuntime, String] {
  let executable = @env.get_env_var("MOONDESK_MOONFLOW_BIN").unwrap_or("")
  let stamp = match moonbook_executable_stamp(executable) {
    Ok(value) => value
    Err(_) =>
      return Err(
        "Review unavailable: configure the trusted native Flow executable",
      )
  }
  let help = match moonbook_capture(executable, ["--help"], "/", 8000, 131072) {
    Ok(output) if output.status == 0 =>
      @utf8.decode(output.stdout) catch {
        _ => ""
      }
    _ => ""
  }
  guard help.contains(
      "moonflow collaboration inspect <workspace> <workspace-id>",
    ) &&
    help.contains(
      "moonflow collaboration apply <workspace> <workspace-id> <typed-mutation.json>",
    ) &&
    moonbook_executable_stamp(executable) == Ok(stamp) else {
    return Err(
      "Review unavailable: native Flow collaboration contract is missing or changed",
    )
  }
  Ok({ executable, stamp, })
}

///|
pub async fn run_moonflow_review(
  runtime : MoonFlowReviewRuntime,
  workspace : String,
  operation : MoonFlowReviewOperation,
) -> Result[String, String] {
  let arguments = match moonflow_review_arguments(workspace, operation) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  guard canonical_directory("Review workspace", workspace) is Ok(_) &&
    moonbook_executable_stamp(runtime.executable) == Ok(runtime.stamp) else {
    return Err("Review workspace or executable changed")
  }
  match operation {
    InspectReviewWorkspace(..) => ()
    BeginExistingReview(mutation_ref~, ..)
    | DecideExistingReview(mutation_ref~, ..) => {
      let path = workspace + "/" + mutation_ref
      guard @fs.realpath(path) == path &&
        @fs.kind(path, follow_symlink=false) == Regular else {
        return Err("Review mutation is not a confined regular file")
      }
      let value = @json.parse(@fs.read_file(path).text()) catch {
        _ => return Err("Invalid fixed review mutation")
      }
      let expected = match operation {
        BeginExistingReview(..) => "review-begin"
        _ => "decision"
      }
      guard value
        is {
          "contract_id": String("moonflow.collaboration-operator-mutation.v1"),
          "action": String(action),
          ..
        } &&
        action == expected else {
        return Err(
          "The fixed review bridge cannot apply other collaboration actions",
        )
      }
    }
  }
  let output = match
    moonbook_capture(
      runtime.executable,
      arguments,
      workspace,
      30000,
      4 * 1024 * 1024,
    ) {
    Ok(value) => value
    Err(_) =>
      return Err(
        "Review response interrupted; reopen or retry the original mutation identity",
      )
  }
  if output.status != 0 {
    let error = @utf8.decode(output.stderr) catch {
      _ => "Review mutation denied"
    }
    return Err(error[:4096].to_owned())
  }
  Ok(
    @utf8.decode(output.stdout) catch {
      _ => return Err("Unreadable review response")
    },
  )
}
