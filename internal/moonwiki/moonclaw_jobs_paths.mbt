///|
fn moonclaw_jobs_root(workspace_root : String) -> String {
  @pathx.join(moonsuite_product_dir(workspace_root, "moonclaw"), "jobs")
}

///|
fn moonclaw_jobs_relative_root() -> String {
  ".moonsuite/products/moonclaw/jobs"
}

///|
fn moonclaw_run_relative_path(run_id : String, relative : String) -> String {
  @pathx.join(@pathx.join(moonclaw_jobs_relative_root(), run_id), relative)
}
