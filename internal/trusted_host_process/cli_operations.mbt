///|
/// Opaque, validated Lepusa platform selector. Callers cannot create arbitrary
/// command fragments through this type.
pub struct LepusaTarget {
  value : String
}

///|
/// Opaque Lepusa CLI operation. Every value is created by one of the closed
/// operation constructors below; executable and argument selection remain in
/// TrustedHostProcess.
pub struct LepusaOperation {
  args : Array[String]
  needs_project : String?
  output_directory : String?
  manifest : String?
}

///|
/// Bounded code-signing identity passed only as the value of `--sign`.
pub struct SigningIdentity {
  value : String
}

///|
/// Bounded keychain profile passed only as the value of
/// `--keychain-profile`.
pub struct NotaryProfile {
  value : String
}

///|
let fixed_tool_path = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"

///|
let tool_build_timeout_ms = 1_200_000

///|
let lepusa_operation_timeout_ms = 600_000

///|
let release_operation_timeout_ms = 1_800_000

///|
let fixed_tool_stream_limit_bytes : Int = 4 * 1024 * 1024

///|
fn safe_bounded_value(value : String, maximum : Int) -> Bool {
  if value == "" || value.length() > maximum {
    return false
  }
  for char in value {
    if char < ' ' || char == '\u007f' {
      return false
    }
  }
  true
}

///|
fn safe_canonical_path_shape(path : String) -> Bool {
  safe_absolute_path(path) &&
  path != "/" &&
  !path.contains("//") &&
  !path.contains("/./") &&
  !path.contains("/../") &&
  !path.has_suffix("/.") &&
  !path.has_suffix("/..")
}

///|
fn safe_asset_url(value : String) -> Bool {
  safe_bounded_value(value, 4096) &&
  (
    value.has_prefix("lepusa://") ||
    value.has_prefix("http://") ||
    value.has_prefix("https://")
  )
}

///|
pub fn lepusa_target(value : String) -> Result[LepusaTarget, String] {
  match value {
    "macos" | "linux" | "windows" => Ok({ value, })
    _ => Err("Lepusa target is not supported")
  }
}

///|
pub fn signing_identity(value : String) -> Result[SigningIdentity, String] {
  if safe_bounded_value(value, 512) {
    Ok({ value, })
  } else {
    Err("Code-signing identity is invalid")
  }
}

///|
pub fn notary_profile(value : String) -> Result[NotaryProfile, String] {
  if safe_bounded_value(value, 255) {
    Ok({ value, })
  } else {
    Err("Notary profile is invalid")
  }
}

///|
fn checked_operation(
  args : Array[String],
  project? : String,
  output_directory? : String,
  manifest? : String,
) -> Result[LepusaOperation, String] {
  for value in args {
    if !safe_bounded_value(value, 4096) {
      return Err("Lepusa operation value is invalid")
    }
  }
  if project is Some(path) && !safe_canonical_path_shape(path) {
    return Err("Lepusa project path is invalid")
  }
  if output_directory is Some(path) && !safe_canonical_path_shape(path) {
    return Err("Lepusa output path is invalid")
  }
  if manifest is Some(path) && !safe_canonical_path_shape(path) {
    return Err("Lepusa manifest path is invalid")
  }
  Ok({ args, needs_project: project, output_directory, manifest })
}

///|
pub fn lepusa_doctor(target : LepusaTarget) -> LepusaOperation {
  {
    args: [
      "run",
      "cmd/main",
      "--target",
      "native",
      "--",
      "doctor",
      target.value,
    ],
    needs_project: None,
    output_directory: None,
    manifest: None,
  }
}

///|
pub fn lepusa_verify(
  target : LepusaTarget,
  project : String,
  strict~ : Bool,
) -> Result[LepusaOperation, String] {
  let args = [
    "run",
    "cmd/main",
    "--target",
    "native",
    "--",
    "verify",
    target.value,
  ]
  if strict {
    args.push("--strict")
  }
  args.push("--project")
  args.push(project)
  checked_operation(args, project~)
}

///|
fn lepusa_project_operation(
  command : String,
  target : LepusaTarget,
  project : String,
) -> Result[LepusaOperation, String] {
  checked_operation(
    [
      "run",
      "cmd/main",
      "--target",
      "native",
      "--",
      command,
      target.value,
      "--project",
      project,
    ],
    project~,
  )
}

///|
pub fn lepusa_run(
  target : LepusaTarget,
  project : String,
) -> Result[LepusaOperation, String] {
  lepusa_project_operation("run", target, project)
}

///|
pub fn lepusa_launch_session(
  target : LepusaTarget,
  project : String,
) -> Result[LepusaOperation, String] {
  lepusa_project_operation("launch-session", target, project)
}

///|
pub fn lepusa_bundle_plan(
  target : LepusaTarget,
  project : String,
) -> Result[LepusaOperation, String] {
  lepusa_project_operation("bundle-plan", target, project)
}

///|
fn lepusa_output_operation(
  command : String,
  target : LepusaTarget,
  project : String,
  output_directory : String,
) -> Result[LepusaOperation, String] {
  checked_operation(
    [
      "run",
      "cmd/main",
      "--target",
      "native",
      "--",
      command,
      target.value,
      output_directory,
      "--project",
      project,
    ],
    project~,
    output_directory~,
  )
}

///|
pub fn lepusa_bundle_write(
  target : LepusaTarget,
  project : String,
  output_directory : String,
) -> Result[LepusaOperation, String] {
  lepusa_output_operation("bundle-write", target, project, output_directory)
}

///|
pub fn lepusa_build(
  target : LepusaTarget,
  project : String,
  output_directory : String,
) -> Result[LepusaOperation, String] {
  lepusa_output_operation("build", target, project, output_directory)
}

///|
pub fn lepusa_asset(
  project : String,
  asset_url : String,
) -> Result[LepusaOperation, String] {
  if !safe_asset_url(asset_url) {
    return Err("Lepusa asset URL is invalid")
  }
  checked_operation(
    [
      "run", "cmd/main", "--target", "native", "--", "asset", asset_url, "--project",
      project,
    ],
    project~,
  )
}

///|
pub fn lepusa_runtime_session(
  manifest : String,
) -> Result[LepusaOperation, String] {
  checked_operation(
    [
      "run", "cmd/runtime", "--target", "native", "--", "launch-session", "--manifest",
      manifest,
    ],
    manifest~,
  )
}

///|
pub fn lepusa_runtime_launch(
  manifest : String,
) -> Result[LepusaOperation, String] {
  checked_operation(
    [
      "run", "cmd/runtime", "--target", "native", "--", "launch", "--manifest", manifest,
    ],
    manifest~,
  )
}

///|
pub fn lepusa_runtime_asset(
  manifest : String,
  asset_url : String,
) -> Result[LepusaOperation, String] {
  if !safe_asset_url(asset_url) {
    return Err("Lepusa asset URL is invalid")
  }
  checked_operation(
    [
      "run", "cmd/runtime", "--target", "native", "--", "asset", asset_url, "--manifest",
      manifest,
    ],
    manifest~,
  )
}

///|
pub fn lepusa_launch(
  target : LepusaTarget,
  project : String,
) -> Result[LepusaOperation, String] {
  checked_operation(
    [
      "run",
      "cmd/main",
      "--target",
      "native",
      "--",
      "run",
      target.value,
      "--launch",
      "--project",
      project,
    ],
    project~,
  )
}

///|
async fn canonical_directory(
  label : String,
  path : String,
) -> Result[String, String] {
  if !safe_canonical_path_shape(path) {
    return Err(label + " path is invalid")
  }
  let canonical = @fs.realpath(path) catch {
    _ => return Err(label + " does not resolve")
  }
  if canonical != path {
    return Err(label + " must be canonical")
  }
  let kind = @fs.kind(path, follow_symlink=false) catch {
    _ => return Err(label + " cannot be inspected")
  }
  if kind != Directory {
    Err(label + " is not a directory")
  } else {
    Ok(path)
  }
}

///|
async fn canonical_regular_file(
  label : String,
  path : String,
) -> Result[String, String] {
  if !safe_canonical_path_shape(path) {
    return Err(label + " path is invalid")
  }
  let canonical = @fs.realpath(path) catch {
    _ => return Err(label + " does not resolve")
  }
  if canonical != path {
    return Err(label + " must be canonical")
  }
  let kind = @fs.kind(path, follow_symlink=false) catch {
    _ => return Err(label + " cannot be inspected")
  }
  if kind != Regular {
    Err(label + " is not a regular file")
  } else {
    Ok(path)
  }
}

///|
fn path_parent(path : String) -> String {
  match path.rev_find("/") {
    Some(0) => "/"
    Some(index) => path[:index].to_owned()
    None => ""
  }
}

///|
async fn canonical_output_path(
  label : String,
  path : String,
) -> Result[String, String] {
  if !safe_canonical_path_shape(path) {
    return Err(label + " path is invalid")
  }
  let exists = @fs.kind(path, follow_symlink=false) catch {
    _ => {
      let mut ancestor = path_parent(path)
      while ancestor != "" {
        let ancestor_exists = @fs.kind(ancestor, follow_symlink=false) catch {
          _ => {
            let parent = path_parent(ancestor)
            if parent == ancestor {
              return Err(label + " has no canonical parent")
            }
            ancestor = parent
            continue
          }
        }
        ignore(ancestor_exists)
        return match canonical_directory(label + " parent", ancestor) {
          Ok(_) => Ok(path)
          Err(message) => Err(message)
        }
      }
      return Err(label + " has no canonical parent")
    }
  }
  match exists {
    SymLink => Err(label + " cannot be a symlink")
    _ => Err(label + " already exists")
  }
}

///|
async fn canonical_output_directory(
  label : String,
  path : String,
) -> Result[String, String] {
  match canonical_directory(label, path) {
    Ok(path) => Ok(path)
    Err(_) => canonical_output_path(label, path)
  }
}

///|
async fn fixed_environment() -> Result[Map[String, String], String] {
  let home = @sys.get_env_var("HOME").unwrap_or("")
  let home = match canonical_directory("Trusted tool HOME", home) {
    Ok(path) => path
    Err(message) => return Err(message)
  }
  Ok({
    "HOME": home,
    "PATH": fixed_tool_path,
    "LANG": "C.UTF-8",
    "LC_ALL": "C.UTF-8",
    "TMPDIR": "/tmp",
  })
}

///|
async fn stream_fixed_tool_output(
  reader : @process.ReadFromProcess,
  output : @stdio.Output,
  limit : Int,
) -> Bool {
  defer reader.close()
  let mut written = 0
  while reader.read_some(max_len=16 * 1024) is Some(bytes) {
    if written + bytes.length() > limit {
      let remaining = limit - written
      if remaining > 0 {
        output.write(bytes[:remaining]) catch {
          _ => return false
        }
      }
      @stdio.stderr.write(
        "\nMoonDesk stopped a trusted host tool after its output limit was reached.\n",
      ) catch {
        _ => ()
      }
      return false
    }
    output.write(bytes) catch {
      _ => return false
    }
    written += bytes.length()
  }
  true
}

///|
async fn moon_executable() -> Result[String, String] {
  let home = @sys.get_env_var("HOME").unwrap_or("")
  let candidate = home.trim_end(chars="/").to_owned() + "/.moon/bin/moon"
  let candidate = canonical_regular_file("Moon toolchain executable", candidate)
  match candidate {
    Ok(path) if @fs.can_execute(path) => Ok(path)
    Ok(_) => Err("Moon toolchain executable is not executable")
    Err(message) => Err(message)
  }
}

///|
async fn fixed_tool_exit_code(
  executable : String,
  args : Array[String],
  cwd : String,
  timeout_ms : Int,
) -> Int {
  let environment = match fixed_environment() {
    Ok(environment) => environment
    Err(_) => return -1
  }
  @async.with_timeout(timeout_ms, () => {
    @async.with_task_group() <| group => {
      let (stdout_reader, stdout_writer) = @process.read_from_process()
      let (stderr_reader, stderr_writer) = @process.read_from_process()
      let process = @process.spawn(
        group,
        executable,
        args,
        cwd~,
        stdout=stdout_writer,
        stderr=stderr_writer,
        extra_env=environment,
        inherit_env=false,
        cancel_handler=@process.graceful_cancel(timeout=2_000),
      )
      let stdout = group.spawn(() => {
        let complete = stream_fixed_tool_output(
          stdout_reader, @stdio.stdout, fixed_tool_stream_limit_bytes,
        )
        if !complete {
          process.cancel()
        }
        complete
      })
      let stderr = group.spawn(() => {
        let complete = stream_fixed_tool_output(
          stderr_reader, @stdio.stderr, fixed_tool_stream_limit_bytes,
        )
        if !complete {
          process.cancel()
        }
        complete
      })
      let code = process.wait()
      let output_complete = stdout.wait() && stderr.wait()
      if output_complete {
        code
      } else {
        -2
      }
    }
  }) catch {
    _ => -1
  }
}

///|
pub async fn build_lepusa_runtime(lepusa_root : String) -> Int {
  let root = match canonical_directory("Lepusa checkout", lepusa_root) {
    Ok(path) => path
    Err(_) => return -1
  }
  let moon = match moon_executable() {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(
    moon,
    ["build", "cmd/runtime", "--target", "native", "--release"],
    root,
    tool_build_timeout_ms,
  )
}

///|
pub async fn build_moondesk_sidecar(repo_root : String) -> Int {
  let root = match canonical_directory("MoonDesk checkout", repo_root) {
    Ok(path) => path
    Err(_) => return -1
  }
  let moon = match moon_executable() {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(
    moon,
    ["build", "cmd/main", "--target", "native", "--release"],
    root,
    tool_build_timeout_ms,
  )
}

///|
pub async fn run_lepusa_operation(
  lepusa_root : String,
  operation : LepusaOperation,
) -> Int {
  let root = match canonical_directory("Lepusa checkout", lepusa_root) {
    Ok(path) => path
    Err(_) => return -1
  }
  if operation.needs_project is Some(path) {
    guard canonical_regular_file("Lepusa project", path) is Ok(_) else {
      return -1
    }
  }
  if operation.manifest is Some(path) {
    guard canonical_regular_file("Lepusa runtime manifest", path) is Ok(_) else {
      return -1
    }
  }
  if operation.output_directory is Some(path) {
    guard canonical_output_directory("Lepusa output directory", path) is Ok(_) else {
      return -1
    }
  }
  let moon = match moon_executable() {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(moon, operation.args, root, lepusa_operation_timeout_ms)
}

///|
pub async fn sign_app(identity : SigningIdentity, app_root : String) -> Int {
  let app = match canonical_directory("Application bundle", app_root) {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(
    "/usr/bin/codesign",
    ["--force", "--deep", "--sign", identity.value, app],
    path_parent(app),
    release_operation_timeout_ms,
  )
}

///|
pub async fn verify_app_signature(app_root : String) -> Int {
  let app = match canonical_directory("Application bundle", app_root) {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(
    "/usr/bin/codesign",
    ["--verify", "--deep", "--strict", app],
    path_parent(app),
    release_operation_timeout_ms,
  )
}

///|
pub async fn archive_app(app_root : String, archive_path : String) -> Int {
  let app = match canonical_directory("Application bundle", app_root) {
    Ok(path) => path
    Err(_) => return -1
  }
  let archive = match
    canonical_output_path("Application archive", archive_path) {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(
    "/usr/bin/ditto",
    ["-c", "-k", "--keepParent", app, archive],
    path_parent(archive),
    release_operation_timeout_ms,
  )
}

///|
pub async fn notarize_archive(
  profile : NotaryProfile,
  archive_path : String,
) -> Int {
  let archive = match
    canonical_regular_file("Application archive", archive_path) {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(
    "/usr/bin/xcrun",
    [
      "notarytool",
      "submit",
      archive,
      "--keychain-profile",
      profile.value,
      "--wait",
    ],
    path_parent(archive),
    release_operation_timeout_ms,
  )
}

///|
pub async fn staple_app(app_root : String) -> Int {
  let app = match canonical_directory("Application bundle", app_root) {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(
    "/usr/bin/xcrun",
    ["stapler", "staple", app],
    path_parent(app),
    release_operation_timeout_ms,
  )
}

///|
pub async fn copy_app(app_root : String, destination : String) -> Int {
  let app = match canonical_directory("Application bundle", app_root) {
    Ok(path) => path
    Err(_) => return -1
  }
  let destination = match
    canonical_output_path("Staged application", destination) {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(
    "/usr/bin/ditto",
    [app, destination],
    path_parent(destination),
    release_operation_timeout_ms,
  )
}

///|
pub async fn create_dmg(staging_directory : String, dmg_path : String) -> Int {
  let staging = match
    canonical_directory("DMG staging directory", staging_directory) {
    Ok(path) => path
    Err(_) => return -1
  }
  let dmg = match canonical_output_path("DMG", dmg_path) {
    Ok(path) => path
    Err(_) => return -1
  }
  fixed_tool_exit_code(
    "/usr/bin/hdiutil",
    [
      "create", "-volname", "MoonDesk", "-srcfolder", staging, "-ov", "-format",
      "UDZO", dmg,
    ],
    path_parent(dmg),
    release_operation_timeout_ms,
  )
}

///|
pub async fn sha256_file(path : String) -> String {
  let file = match canonical_regular_file("SHA-256 input", path) {
    Ok(path) => path
    Err(_) => return ""
  }
  let environment = match fixed_environment() {
    Ok(environment) => environment
    Err(_) => return ""
  }
  let output = @async.with_timeout(60_000, () => {
    @process.collect_output(
      "/usr/bin/shasum",
      ["-a", "256", file],
      extra_env=environment,
      inherit_env=false,
      cwd=path_parent(file),
    )
  }) catch {
    _ => return ""
  }
  if output.0 != 0 {
    return ""
  }
  let text = (output.1.text() catch { _ => "" }).trim().to_owned()
  // `shasum` emits one fixed digest plus the already-bounded input path. This
  // explicit ceiling also rejects unexpected implementations or wrappers.
  if text.length() > 8192 {
    return ""
  }
  match text.find(" ") {
    Some(index) => text[:index].to_owned()
    None => text
  }
}
