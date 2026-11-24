///|
fn moondesk_moonclaw_build_output(repo_root : String) -> String {
  @env.get_env_var("MOONDESK_MOONCLAW_BIN").unwrap_or(
    @pathx.join(
      @pathx.dirname(repo_root).to_owned(),
      "moonclaw/_build/native/release/build/cmd/main/main.exe",
    ),
  )
}

///|
fn moondesk_moonclaw_module_path(repo_root : String) -> String {
  @pathx.join(@pathx.dirname(repo_root).to_owned(), "moonclaw/moon.mod")
}

///|
async fn copy_moondesk_moonclaw_runtime(
  repo_root : String,
  target : String,
  out_dir : String,
) -> Bool {
  let executable_dir = @pathx.dirname(
    lepusa_integration_sidecar_path(target, out_dir),
  ).to_owned()
  let resources = if target == "macos" {
    @pathx.join(@pathx.dirname(executable_dir).to_owned(), "Resources")
  } else {
    @pathx.join(executable_dir, "resources")
  }
  let bundled = @pathx.join(resources, "moonclaw-runtime")
  try {
    @fsx.make_directory(
      @pathx.join(bundled, "bin"),
      recursive=true,
      exists_ok=true,
    )
    @fs.write_file(
      @pathx.join(bundled, "bin/moonclaw"),
      @fs.read_file(moondesk_moonclaw_build_output(repo_root)),
      create_mode=CreateOrTruncate,
      permission=0o755,
    )
    @fs.chmod(@pathx.join(bundled, "bin/moonclaw"), 0o755)
    @fs.write_file(
      @pathx.join(bundled, "moon.mod"),
      @fs.read_file(moondesk_moonclaw_module_path(repo_root)),
      create_mode=CreateOrTruncate,
      permission=0o644,
    )
    true
  } catch {
    error => {
      println(
        "Could not bundle Code runtime: \{error}. Build ../moonclaw/cmd/main or set MOONDESK_MOONCLAW_BIN.",
      )
      false
    }
  }
}
