///|
/// Ship the native owner with the desktop app; Finder launches do not inherit
/// a developer shell's checkout variables.
async fn copy_moondesk_flow_runtime(
  repo_root : String,
  target : String,
  out_dir : String,
) -> Bool {
  let source = moondesk_flow_build_output(repo_root)
  let directory = @pathx.dirname(
    lepusa_integration_sidecar_path(target, out_dir),
  ).to_owned()
  let destination = @pathx.join(
    directory,
    if target == "windows" {
      "moonflow.exe"
    } else {
      "moonflow"
    },
  )
  try {
    @fs.write_file(
      destination,
      @fs.read_file(source),
      create_mode=CreateOrTruncate,
      permission=0o755,
    )
    @fs.chmod(destination, 0o755)
    true
  } catch {
    error => {
      println(
        "Could not bundle native Flow: \{error}. Build ../moonflow/cmd/main in native release mode or set MOONDESK_MOONFLOW_BIN.",
      )
      false
    }
  }
}

///|
fn moondesk_flow_build_output(repo_root : String) -> String {
  @env.get_env_var("MOONDESK_MOONFLOW_BIN").unwrap_or(
    @pathx.join(
      @pathx.dirname(repo_root).to_owned(),
      "moonflow/_build/native/release/build/cmd/main/main.exe",
    ),
  )
}
