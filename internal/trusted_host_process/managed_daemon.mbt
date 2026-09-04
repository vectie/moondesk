///|
/// Opaque identifier for the only long-running daemon MoonDesk may launch
/// directly. The identifier selects a versioned binary inside MoonDesk's
/// managed runtime registry; it never contains an executable or argument list.
pub struct ManagedMoonClawBinding {
  version : String
}

///|
/// Receipt for a trusted daemon launch. Output is deliberately discarded, so
/// a daemon cannot grow an unbounded host log through this capability.
pub(all) struct ManagedDaemonStart {
  pid : Int
  display : String
}

///|
fn safe_binding_segment(value : String) -> Bool {
  if value == "" || value.length() > 160 {
    return false
  }
  for char in value {
    if !char.is_ascii_alphabetic() &&
      !char.is_ascii_digit() &&
      char != '.' &&
      char != '-' &&
      char != '_' {
      return false
    }
  }
  true
}

///|
fn safe_daemon_path(path : String) -> Bool {
  path.length() > 1 &&
  path.length() <= 4096 &&
  path.has_prefix("/") &&
  !path.contains("\u0000") &&
  !path.contains("\n") &&
  !path.contains("\r")
}

///|
fn join_daemon_path(parent : String, child : String) -> String {
  parent.trim_end(chars="/").to_owned() + "/" + child
}

///|
fn managed_runtime_root_from_values(
  override_root : String,
  app_data_root : String,
  home_root : String,
) -> Result[String, String] {
  let root = if override_root.trim() != "" {
    override_root.trim().to_owned()
  } else if app_data_root.trim() != "" {
    join_daemon_path(app_data_root.trim().to_owned(), "runtimes")
  } else if home_root.trim() != "" {
    join_daemon_path(
      home_root.trim().to_owned(),
      "Library/Application Support/app.vectie.moondesk/runtimes",
    )
  } else {
    return Err("MoonDesk managed runtime root is unavailable")
  }
  if !safe_daemon_path(root) {
    Err("MoonDesk managed runtime root is invalid")
  } else {
    Ok(root.trim_end(chars="/").to_owned())
  }
}

///|
fn managed_runtime_root() -> Result[String, String] {
  managed_runtime_root_from_values(
    @sys.get_env_var("MOONDESK_RUNTIME_ROOT").unwrap_or(""),
    @sys.get_env_var("LEPUSA_APP_DATA_DIR").unwrap_or(""),
    @sys.get_env_var("HOME").unwrap_or(""),
  )
}

///|
fn moonclaw_daemon_arguments(workspace_root : String) -> Array[String] {
  ["daemon", "--port", "0", "--serve", workspace_root]
}

///|
fn moonclaw_daemon_environment_from_values(
  home : String,
  lunanexa_issuer : String,
  moongate_control_token : String,
) -> Map[String, String] {
  let environment : Map[String, String] = {
    "HOME": home,
    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin",
    "LANG": "C.UTF-8",
    "LC_ALL": "C.UTF-8",
    "TMPDIR": "/tmp",
  }
  let issuer = lunanexa_issuer.trim().to_owned()
  if issuer != "" &&
    issuer.length() <= 2_048 &&
    !issuer.contains_char('\n') &&
    !issuer.contains_char('\r') {
    environment["MOONDESK_LUNANEXA_ISSUER"] = issuer
  }
  let token = moongate_control_token.trim().to_owned()
  if token != "" &&
    token.length() <= 4_096 &&
    !token.contains_char('\n') &&
    !token.contains_char('\r') {
    environment["MOONGATE_CONTROL_TOKEN"] = token
  }
  environment
}

///|
fn moonclaw_daemon_environment(home : String) -> Map[String, String] {
  moonclaw_daemon_environment_from_values(
    home,
    @sys.get_env_var("MOONDESK_LUNANEXA_ISSUER").unwrap_or(""),
    @sys.get_env_var("MOONGATE_CONTROL_TOKEN").unwrap_or(""),
  )
}

///|
fn moonclaw_daemon_display(
  executable : String,
  workspace_root : String,
) -> String {
  executable + " daemon --port 0 --serve " + workspace_root
}

///|
pub fn managed_moonclaw_binding(
  version : String,
) -> Result[ManagedMoonClawBinding, String] {
  if !safe_binding_segment(version) {
    Err("MoonClaw managed daemon binding is invalid")
  } else {
    Ok({ version, })
  }
}

///|
async fn canonical_managed_directory(
  label : String,
  path : String,
) -> Result[String, String] {
  if !safe_daemon_path(path) {
    return Err("MoonClaw managed " + label + " path is invalid")
  }
  let canonical = @fs.realpath(path) catch {
    _ => return Err("MoonClaw managed " + label + " does not resolve")
  }
  if canonical != path {
    return Err("MoonClaw managed " + label + " must be canonical")
  }
  let kind = @fs.kind(canonical, follow_symlink=false) catch {
    _ => return Err("MoonClaw managed " + label + " cannot be inspected")
  }
  if kind != Directory {
    return Err("MoonClaw managed " + label + " is not a directory")
  }
  Ok(canonical)
}

///|
async fn canonical_managed_executable(path : String) -> Result[String, String] {
  if !safe_daemon_path(path) {
    return Err("MoonClaw managed executable path is invalid")
  }
  let canonical = @fs.realpath(path) catch {
    _ => return Err("MoonClaw managed executable does not resolve")
  }
  if canonical != path {
    return Err("MoonClaw managed executable must be canonical")
  }
  let kind = @fs.kind(canonical, follow_symlink=false) catch {
    _ => return Err("MoonClaw managed executable cannot be inspected")
  }
  if kind != Regular || !@fs.can_execute(canonical) {
    return Err("MoonClaw managed executable is unavailable")
  }
  Ok(canonical)
}

///|
/// Launch the fixed MoonClaw daemon binding. The executable and cwd are
/// resolved from MoonDesk's managed runtime registry, arguments are fixed,
/// ambient environment inheritance is disabled, and all three stdio streams
/// are attached to `/dev/null` to impose a zero-byte output-storage bound.
pub async fn start_managed_moonclaw_daemon(
  binding : ManagedMoonClawBinding,
  workspace_root : String,
) -> Result[ManagedDaemonStart, String] {
  let runtime_root = match managed_runtime_root() {
    Ok(root) => root
    Err(message) => return Err(message)
  }
  let runtime_root = match
    canonical_managed_directory("runtime root", runtime_root) {
    Ok(root) => root
    Err(message) => return Err(message)
  }
  let install_dir = join_daemon_path(
    join_daemon_path(runtime_root, "moonclaw"),
    binding.version,
  )
  let install_dir = match
    canonical_managed_directory("installation", install_dir) {
    Ok(path) => path
    Err(message) => return Err(message)
  }
  let executable = match
    canonical_managed_executable(join_daemon_path(install_dir, "bin/moonclaw")) {
    Ok(path) => path
    Err(message) => return Err(message)
  }
  let workspace_root = match
    canonical_managed_directory("workspace root", workspace_root) {
    Ok(path) => path
    Err(message) => return Err(message)
  }
  let home = @sys.get_env_var("HOME").unwrap_or("")
  let home = match canonical_managed_directory("home", home) {
    Ok(path) => path
    Err(message) => return Err(message)
  }
  let stdin = @process.redirect_from_file("/dev/null") catch {
    _ => return Err("MoonDesk could not bind MoonClaw daemon stdin")
  }
  let stdout = @process.redirect_to_file(
    "/dev/null",
    append=true,
    create_mode=OpenExisting,
  ) catch {
    _ => return Err("MoonDesk could not bind MoonClaw daemon stdout")
  }
  let stderr = @process.redirect_to_file(
    "/dev/null",
    append=true,
    create_mode=OpenExisting,
  ) catch {
    _ => return Err("MoonDesk could not bind MoonClaw daemon stderr")
  }
  let pid = @process.spawn_orphan(
    executable,
    moonclaw_daemon_arguments(workspace_root),
    cwd=install_dir,
    stdin~,
    stdout~,
    stderr~,
    extra_env=moonclaw_daemon_environment(home),
    inherit_env=false,
  ) catch {
    error => return Err("Could not start managed MoonClaw daemon: \{error}")
  }
  Ok({ pid, display: moonclaw_daemon_display(executable, workspace_root) })
}
