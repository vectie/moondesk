///|
fn moonclaw_jobs_root(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moonclaw", "jobs",
  )
}

///|
fn moonclaw_jobs_relative_root() -> String {
  moonsuite_product_display_artifact("moonclaw", "jobs")
}

///|
fn moonclaw_jobs_relative_prefix() -> String {
  moonclaw_jobs_relative_root() + "/"
}

///|
fn moonclaw_run_relative_path(run_id : String, relative : String) -> String {
  @pathx.join(@pathx.join(moonclaw_jobs_relative_root(), run_id), relative)
}
