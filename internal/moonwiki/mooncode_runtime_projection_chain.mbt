///|
async fn write_mooncode_runtime_projection_chain(
  workspace_root : String,
  session : Json,
) -> Json {
  let projected = attach_mooncode_session_projection(workspace_root, session)
  let with_action_plan = write_mooncode_action_plan_if_possible(
    workspace_root, projected,
  ) catch {
    _ => projected
  }
  let with_runtime_evidence = write_mooncode_runtime_evidence_if_possible(
    workspace_root, with_action_plan,
  ) catch {
    _ => with_action_plan
  }
  let with_eval_report = write_mooncode_eval_report_if_possible(
    with_runtime_evidence,
  ) catch {
    _ => with_runtime_evidence
  }
  let with_session_snapshot = write_mooncode_session_snapshot_if_possible(
    workspace_root, with_eval_report,
  ) catch {
    _ => with_eval_report
  }
  write_mooncode_runtime_handoff_if_possible(
    workspace_root, with_session_snapshot,
  ) catch {
    _ => with_session_snapshot
  }
}
