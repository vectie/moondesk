///|
async fn run_lepusa_integration(args : Array[String]) -> Unit {
  let repo_root = @pathx.normalize(@env.current_dir().unwrap_or("."))
  let options = match parse_lepusa_integration_args(args) {
    Some(options) => options
    None => {
      print_usage()
      return
    }
  }
  let lepusa_root = absolute_path(options.lepusa_root, repo_root)
  if !@fs.exists(@pathx.join(lepusa_root, "moon.mod")) {
    println("lepusa failed: Lepusa checkout not found at \{lepusa_root}")
    return
  }
  let out_dir = absolute_path(options.out_dir, repo_root)
  let manifest_path = if options.manifest_path == "" {
    lepusa_integration_runtime_manifest_path(options.target, out_dir)
  } else {
    absolute_path(options.manifest_path, repo_root)
  }
  let live_options = lepusa_integration_resolve_live_paths(options, repo_root)
  let project = if lepusa_integration_command_uses_live_project(options.command) {
    let live_project = lepusa_integration_live_project_path(out_dir)
    if !write_lepusa_integration_live_project(
        live_options, repo_root, live_project,
      ) {
      return
    }
    live_project
  } else {
    absolute_path(options.project, repo_root)
  }
  if options.command != "doctor" && !@fs.exists(project) {
    println("lepusa failed: project manifest not found at \{project}")
    return
  }
  if lepusa_integration_command_builds_runtime(options.command) {
    if !build_lepusa_runtime(lepusa_root) {
      return
    }
  }
  if lepusa_integration_command_uses_live_project(options.command) ||
    options.command == "smoke" {
    if !build_moondesk_sidecar(repo_root) {
      return
    }
  }
  if options.command == "bundle-check" {
    ignore(run_lepusa_integration_bundle_check(options, out_dir, manifest_path))
    return
  }
  if options.command == "live-bundle-check" {
    ignore(
      run_lepusa_integration_live_bundle_check(
        live_options, out_dir, manifest_path,
      ),
    )
    return
  }
  if options.command == "live-smoke" {
    run_lepusa_integration_live_smoke(
      live_options, repo_root, lepusa_root, project, out_dir, manifest_path,
    )
    return
  }
  if options.command == "live-build" {
    run_lepusa_integration_live_build(
      live_options, repo_root, lepusa_root, project, out_dir, manifest_path,
    )
    return
  }
  if options.command == "live-session" || options.command == "live-launch" {
    run_lepusa_integration_live_runtime(
      live_options, repo_root, lepusa_root, project, out_dir, manifest_path,
    )
    return
  }
  if options.command == "smoke" {
    run_lepusa_integration_smoke(
      options, repo_root, lepusa_root, project, out_dir, manifest_path,
    )
    return
  }
  let lepusa_args = lepusa_integration_process_args(
    options, project, out_dir, manifest_path,
  )
  let code = @process.run("moon", lepusa_args, cwd=lepusa_root) catch {
    error => {
      println("lepusa failed: could not run Lepusa CLI: \{error}")
      return
    }
  }
  if code == 0 {
    println("lepusa \{options.command} \{options.target}: ok")
  } else {
    println(
      "lepusa \{options.command} \{options.target}: failed with exit \{code}",
    )
  }
}
