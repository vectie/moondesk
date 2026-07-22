///|
async fn build_lepusa_runtime(lepusa_root : String) -> Bool {
  let build_code = @process.run(
    "moon",
    ["build", "cmd/runtime", "--target", "native", "--release"],
    cwd=lepusa_root,
  ) catch {
    error => {
      println("lepusa failed: could not build Lepusa runtime: \{error}")
      return false
    }
  }
  if build_code != 0 {
    println("lepusa failed: Lepusa runtime build exited with \{build_code}")
    false
  } else {
    true
  }
}

///|
async fn build_moondesk_sidecar(repo_root : String) -> Bool {
  let build_code = @process.run(
    "moon",
    ["build", "cmd/main", "--target", "native", "--release"],
    cwd=repo_root,
  ) catch {
    error => {
      println("lepusa failed: could not build MoonDesk sidecar: \{error}")
      return false
    }
  }
  if build_code != 0 {
    println("lepusa failed: MoonDesk sidecar build exited with \{build_code}")
    false
  } else {
    true
  }
}

///|
async fn copy_moondesk_sidecar(
  repo_root : String,
  target : String,
  out_dir : String,
) -> Bool {
  let source = moondesk_sidecar_build_output(repo_root)
  let destination = lepusa_integration_sidecar_path(target, out_dir)
  @fsx.make_directory(
    @pathx.dirname(destination).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    error => {
      println("lepusa failed: could not create sidecar directory: \{error}")
      return false
    }
  }
  let data = @fs.read_file(source) catch {
    error => {
      println("lepusa failed: could not read MoonDesk sidecar: \{error}")
      return false
    }
  }
  @fs.write_file(
    destination,
    data,
    create_mode=CreateOrTruncate,
    permission=0o755,
  ) catch {
    error => {
      println("lepusa failed: could not write MoonDesk sidecar: \{error}")
      return false
    }
  }
  @fs.chmod(destination, 0o755) catch {
    error => {
      println(
        "lepusa failed: could not make MoonDesk sidecar executable: \{error}",
      )
      return false
    }
  }
  true
}

///|
fn lepusa_runtime_build_output(lepusa_root : String) -> String {
  @pathx.join(
    lepusa_root, "_build/native/release/build/cmd/runtime/runtime.exe",
  )
}

///|
async fn copy_lepusa_runtime(
  lepusa_root : String,
  target : String,
  out_dir : String,
) -> Bool {
  let source = lepusa_runtime_build_output(lepusa_root)
  let destination = lepusa_integration_bundle_paths(target, out_dir).runtime_executable
  @fsx.make_directory(
    @pathx.dirname(destination).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    error => {
      println("lepusa failed: could not create runtime directory: \{error}")
      return false
    }
  }
  let data = @fs.read_file(source) catch {
    error => {
      println("lepusa failed: could not read built Lepusa runtime: \{error}")
      return false
    }
  }
  @fs.write_file(
    destination,
    data,
    create_mode=CreateOrTruncate,
    permission=0o755,
  ) catch {
    error => {
      println("lepusa failed: could not bundle Lepusa runtime: \{error}")
      return false
    }
  }
  @fs.chmod(destination, 0o755) catch {
    error => {
      println(
        "lepusa failed: could not make Lepusa runtime executable: \{error}",
      )
      return false
    }
  }
  true
}

///|
async fn copy_moondesk_ui_bundle(
  ui_dir : String,
  target : String,
  out_dir : String,
) -> Bool {
  let destination = lepusa_integration_bundled_ui_dir(target, out_dir)
  if !path_is_directory(ui_dir) {
    println("lepusa failed: UI dist is not a directory: \{ui_dir}")
    return false
  }
  if @fs.exists(destination) {
    @fs.rmdir(destination, recursive=true) catch {
      error => {
        println("lepusa failed: could not replace bundled UI dir: \{error}")
        return false
      }
    }
  }
  if copy_directory_tree(ui_dir, destination) {
    true
  } else {
    println("lepusa failed: could not copy UI dist to bundled resources")
    false
  }
}

///|
async fn copy_directory_tree(source : String, destination : String) -> Bool {
  @fsx.make_directory(destination, recursive=true, exists_ok=true) catch {
    _ => return false
  }
  for name in directory_names(source, include_hidden=true) {
    let child_source = @pathx.join(source, name)
    let child_destination = @pathx.join(destination, name)
    if path_is_directory(child_source) {
      if !copy_directory_tree(child_source, child_destination) {
        return false
      }
    } else if !copy_file_bytes(child_source, child_destination) {
      return false
    }
  }
  true
}

///|
async fn copy_file_bytes(source : String, destination : String) -> Bool {
  let data = @fs.read_file(source) catch { _ => return false }
  @fsx.make_directory(
    @pathx.dirname(destination).to_owned(),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => return false
  }
  @fs.write_file(
    destination,
    data,
    create_mode=CreateOrTruncate,
    permission=0o644,
  ) catch {
    _ => return false
  }
  true
}

///|
async fn directory_names(
  path : String,
  include_hidden~ : Bool,
) -> Array[String] {
  let dir = @fs.opendir(path) catch { _ => return [] }
  defer dir.close()
  let names = dir.read_all(include_hidden~) catch { _ => return [] }
  names.sort()
  names
}

///|
async fn path_is_directory(path : String) -> Bool {
  let kind = @fs.kind(path) catch { _ => return false }
  kind is Directory
}

///|
fn lepusa_integration_bundled_ui_dir(
  target : String,
  out_dir : String,
) -> String {
  @pathx.dirname(lepusa_integration_bundle_paths(target, out_dir).entrypoint).to_owned()
}

///|
async fn copy_moondesk_live_bundle_files(
  repo_root : String,
  lepusa_root : String,
  options : LepusaIntegrationOptions,
  out_dir : String,
) -> Bool {
  copy_lepusa_runtime(lepusa_root, options.target, out_dir) &&
  copy_moondesk_sidecar(repo_root, options.target, out_dir) &&
  copy_moondesk_ui_bundle(options.ui_dir, options.target, out_dir)
}

///|
fn moondesk_sidecar_build_output(repo_root : String) -> String {
  @pathx.join(repo_root, "_build/native/release/build/cmd/main/main.exe")
}

///|
fn lepusa_integration_sidecar_path(target : String, out_dir : String) -> String {
  let paths = lepusa_integration_bundle_paths(target, out_dir)
  if target == "macos" {
    @pathx.join(paths.app_root, "Contents/MacOS/moondesk-sidecar")
  } else if target == "windows" {
    @pathx.join(paths.app_root, "moondesk-sidecar.exe")
  } else {
    @pathx.join(paths.app_root, "moondesk-sidecar")
  }
}

///|
async fn run_lepusa_integration_smoke(
  options : LepusaIntegrationOptions,
  repo_root : String,
  lepusa_root : String,
  project : String,
  out_dir : String,
  manifest_path : String,
) -> Unit {
  for
    step in lepusa_integration_smoke_steps(
      options, project, out_dir, manifest_path,
    ) {
    if !run_lepusa_integration_step(step, lepusa_root) {
      println("lepusa smoke \{options.target}: failed at \{step.name}")
      return
    }
    if step.name == "bundle-write" &&
      (
        !copy_lepusa_runtime(lepusa_root, options.target, out_dir) ||
        !copy_moondesk_sidecar(repo_root, options.target, out_dir)
      ) {
      return
    }
  }
  if !run_lepusa_integration_bundle_check(options, out_dir, manifest_path) {
    println("lepusa smoke \{options.target}: failed at bundle-check")
    return
  }
  println("lepusa smoke \{options.target}: ok")
}

///|
async fn run_lepusa_integration_live_smoke(
  options : LepusaIntegrationOptions,
  repo_root : String,
  lepusa_root : String,
  project : String,
  out_dir : String,
  manifest_path : String,
) -> Unit {
  for
    step in lepusa_integration_live_smoke_steps(
      options, project, out_dir, manifest_path,
    ) {
    if !run_lepusa_integration_step(step, lepusa_root) {
      println("lepusa live-smoke \{options.target}: failed at \{step.name}")
      return
    }
    if step.name == "bundle-write" &&
      !copy_moondesk_live_bundle_files(repo_root, lepusa_root, options, out_dir) {
      return
    }
  }
  if !run_lepusa_integration_live_bundle_check(options, out_dir, manifest_path) {
    println("lepusa live-smoke \{options.target}: failed at bundle-check")
    return
  }
  println("lepusa live-smoke \{options.target}: ok")
}

///|
async fn run_lepusa_integration_live_build(
  options : LepusaIntegrationOptions,
  repo_root : String,
  lepusa_root : String,
  project : String,
  out_dir : String,
  manifest_path : String,
) -> Unit {
  for
    step in lepusa_integration_live_build_steps(
      options, project, out_dir, manifest_path,
    ) {
    if !run_lepusa_integration_step(step, lepusa_root) {
      println("lepusa live-build \{options.target}: failed at \{step.name}")
      return
    }
    if step.name == "bundle-write" &&
      !copy_moondesk_live_bundle_files(repo_root, lepusa_root, options, out_dir) {
      return
    }
  }
  if !run_lepusa_integration_live_bundle_check(options, out_dir, manifest_path) {
    println("lepusa live-build \{options.target}: failed at bundle-check")
    return
  }
  println("lepusa live-build \{options.target}: ok")
}

///|
async fn run_lepusa_integration_live_runtime(
  options : LepusaIntegrationOptions,
  repo_root : String,
  lepusa_root : String,
  project : String,
  out_dir : String,
  manifest_path : String,
) -> Unit {
  for
    step in lepusa_integration_live_runtime_steps(
      options, project, out_dir, manifest_path,
    ) {
    if !run_lepusa_integration_step(step, lepusa_root) {
      println(
        "lepusa \{options.command} \{options.target}: failed at \{step.name}",
      )
      return
    }
    if step.name == "bundle-write" &&
      !copy_moondesk_live_bundle_files(repo_root, lepusa_root, options, out_dir) {
      return
    }
  }
  if options.command == "live-launch" &&
    !run_lepusa_integration_live_bundle_check(options, out_dir, manifest_path) {
    println("lepusa live-launch \{options.target}: failed at bundle-check")
    return
  }
  println("lepusa \{options.command} \{options.target}: ok")
}

///|
async fn run_lepusa_integration_step(
  step : LepusaIntegrationProcessStep,
  lepusa_root : String,
) -> Bool {
  let code = @process.run("moon", step.args, cwd=lepusa_root) catch {
    error => {
      println("lepusa failed: \{step.name} could not run: \{error}")
      return false
    }
  }
  if code != 0 {
    println("lepusa failed: \{step.name} exited with \{code}")
    false
  } else {
    true
  }
}

///|
fn lepusa_integration_live_smoke_steps(
  options : LepusaIntegrationOptions,
  project : String,
  out_dir : String,
  manifest_path : String,
) -> Array[LepusaIntegrationProcessStep] {
  let verify = { ..options, command: "verify" }
  let bundle = { ..options, command: "bundle-write" }
  let session = { ..options, command: "runtime-session" }
  [
    {
      name: "verify",
      args: lepusa_integration_process_args(
        verify, project, out_dir, manifest_path,
      ),
    },
    {
      name: "bundle-write",
      args: lepusa_integration_process_args(
        bundle, project, out_dir, manifest_path,
      ),
    },
    {
      name: "runtime-session",
      args: lepusa_integration_process_args(
        session, project, out_dir, manifest_path,
      ),
    },
  ]
}

///|
fn lepusa_integration_live_build_steps(
  options : LepusaIntegrationOptions,
  project : String,
  out_dir : String,
  manifest_path : String,
) -> Array[LepusaIntegrationProcessStep] {
  let verify = { ..options, command: "verify" }
  let bundle = { ..options, command: "bundle-write" }
  [
    {
      name: "verify",
      args: lepusa_integration_process_args(
        verify, project, out_dir, manifest_path,
      ),
    },
    {
      name: "bundle-write",
      args: lepusa_integration_process_args(
        bundle, project, out_dir, manifest_path,
      ),
    },
  ]
}

///|
fn lepusa_integration_live_runtime_steps(
  options : LepusaIntegrationOptions,
  project : String,
  out_dir : String,
  manifest_path : String,
) -> Array[LepusaIntegrationProcessStep] {
  let steps = lepusa_integration_live_build_steps(
    options, project, out_dir, manifest_path,
  )
  let runtime_command = if options.command == "live-launch" {
    { ..options, command: "runtime-launch" }
  } else {
    { ..options, command: "runtime-session" }
  }
  steps.push({
    name: runtime_command.command,
    args: lepusa_integration_process_args(
      runtime_command, project, out_dir, manifest_path,
    ),
  })
  steps
}

///|
fn lepusa_integration_smoke_steps(
  options : LepusaIntegrationOptions,
  project : String,
  out_dir : String,
  manifest_path : String,
) -> Array[LepusaIntegrationProcessStep] {
  let verify = { ..options, command: "verify" }
  let bundle = { ..options, command: "bundle-write" }
  let session = { ..options, command: "runtime-session" }
  let asset = { ..options, command: "runtime-asset" }
  [
    {
      name: "verify",
      args: lepusa_integration_process_args(
        verify, project, out_dir, manifest_path,
      ),
    },
    {
      name: "bundle-write",
      args: lepusa_integration_process_args(
        bundle, project, out_dir, manifest_path,
      ),
    },
    {
      name: "runtime-session",
      args: lepusa_integration_process_args(
        session, project, out_dir, manifest_path,
      ),
    },
    {
      name: "runtime-asset",
      args: lepusa_integration_process_args(
        asset, project, out_dir, manifest_path,
      ),
    },
  ]
}

///|
fn lepusa_integration_process_args(
  options : LepusaIntegrationOptions,
  project : String,
  out_dir : String,
  manifest_path : String,
) -> Array[String] {
  let command_pkg = if lepusa_integration_command_uses_runtime(options.command) {
    "cmd/runtime"
  } else {
    "cmd/main"
  }
  let args = ["run", command_pkg, "--target", "native", "--"]
  match options.command {
    "doctor" => {
      args.push("doctor")
      args.push(options.target)
    }
    "verify" => {
      args.push("verify")
      args.push(options.target)
      if options.strict {
        args.push("--strict")
      }
      args.push("--project")
      args.push(project)
    }
    "run" | "launch-session" | "bundle-plan" => {
      args.push(options.command)
      args.push(options.target)
      args.push("--project")
      args.push(project)
    }
    "bundle-write" | "build" => {
      args.push(options.command)
      args.push(options.target)
      args.push(out_dir)
      args.push("--project")
      args.push(project)
    }
    "asset" => {
      args.push("asset")
      args.push(options.asset_url)
      args.push("--project")
      args.push(project)
    }
    "runtime-session" => {
      args.push("launch-session")
      args.push("--manifest")
      args.push(manifest_path)
    }
    "runtime-launch" => {
      args.push("launch")
      args.push("--manifest")
      args.push(manifest_path)
    }
    "runtime-asset" => {
      args.push("asset")
      args.push(options.asset_url)
      args.push("--manifest")
      args.push(manifest_path)
    }
    "launch" => {
      args.push("run")
      args.push(options.target)
      args.push("--launch")
      args.push("--project")
      args.push(project)
    }
    _ => ()
  }
  args
}

///|
fn lepusa_integration_runtime_manifest_path(
  target : String,
  out_dir : String,
) -> String {
  if target == "macos" {
    @pathx.join(out_dir, "moondesk.app/Contents/Resources/lepusa/runtime.json")
  } else {
    @pathx.join(out_dir, "moondesk/lepusa/runtime.json")
  }
}
