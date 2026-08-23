///|
/// The only LaunchAgents MoonDesk may administer directly on the host.
pub(all) enum ManagedLaunchAgent {
  MoonDesk
  MoonTown
} derive(Debug, Eq)

///|
fn safe_absolute_path(path : String) -> Bool {
  path.length() > 1 &&
  path.length() <= 4096 &&
  path.has_prefix("/") &&
  !path.contains("\u0000") &&
  !path.contains("\n") &&
  !path.contains("\r")
}

///|
fn safe_http_url(url : String) -> Bool {
  url.length() <= 4096 &&
  (url.has_prefix("http://") || url.has_prefix("https://")) &&
  !url.contains("\u0000") &&
  !url.contains("\n") &&
  !url.contains("\r")
}

///|
fn safe_pid(pid : Int) -> Bool {
  pid > 1
}

///|
fn safe_user_id(uid : String) -> Bool {
  if uid == "" || uid.length() > 20 {
    return false
  }
  for char in uid {
    if char < '0' || char > '9' {
      return false
    }
  }
  true
}

///|
fn process_status_is_alive(status : String) -> Bool {
  let status = status.trim().to_owned()
  status != "" && !status.has_prefix("Z")
}

///|
fn launch_agent_label(service : ManagedLaunchAgent) -> String {
  match service {
    MoonDesk => "app.vectie.moondesk"
    MoonTown => "app.vectie.moonsuite.town"
  }
}

///|
fn launch_agent_plist_path(service : ManagedLaunchAgent) -> String {
  let home = @sys.get_env_var("HOME").unwrap_or("")
  if !safe_absolute_path(home) {
    ""
  } else {
    home.trim_end(chars="/").to_owned() +
    "/Library/LaunchAgents/" +
    launch_agent_label(service) +
    ".plist"
  }
}

///|
pub async fn system_name() -> String {
  let output = @process.collect_output("/usr/bin/uname", ["-s"]) catch {
    _ => return ""
  }
  if output.0 == 0 {
    (output.1.text() catch { _ => "" }).trim().to_owned()
  } else {
    ""
  }
}

///|
pub async fn machine_name() -> String {
  let output = @process.collect_output("/usr/bin/uname", ["-m"]) catch {
    _ => return ""
  }
  if output.0 == 0 {
    (output.1.text() catch { _ => "" }).trim().to_owned()
  } else {
    ""
  }
}

///|
async fn current_user_id() -> String {
  let output = @process.collect_output("/usr/bin/id", ["-u"]) catch {
    _ => return ""
  }
  if output.0 == 0 {
    (output.1.text() catch { _ => "" }).trim().to_owned()
  } else {
    ""
  }
}

///|
async fn launchctl_domain() -> String {
  let uid = current_user_id()
  if safe_user_id(uid) {
    "gui/\{uid}"
  } else {
    ""
  }
}

///|
async fn launchctl_target(service : ManagedLaunchAgent) -> String {
  let domain = launchctl_domain()
  if domain == "" {
    ""
  } else {
    domain + "/" + launch_agent_label(service)
  }
}

///|
pub async fn bootstrap_launch_agent(service : ManagedLaunchAgent) -> Int {
  let plist_path = launch_agent_plist_path(service)
  if plist_path == "" {
    return -1
  }
  let domain = launchctl_domain()
  if domain == "" {
    return -1
  }
  @process.run("/bin/launchctl", ["bootstrap", domain, plist_path]) catch {
    _ => -1
  }
}

///|
pub async fn bootout_launch_agent(service : ManagedLaunchAgent) -> Int {
  let target = launchctl_target(service)
  if target == "" {
    return -1
  }
  @process.run("/bin/launchctl", ["bootout", target]) catch {
    _ => -1
  }
}

///|
pub async fn launch_agent_is_loaded(service : ManagedLaunchAgent) -> Bool {
  let target = launchctl_target(service)
  if target == "" {
    return false
  }
  (@process.run("/bin/launchctl", ["print", target]) catch { _ => -1 }) == 0
}

///|
pub async fn open_browser_url(url : String) -> Int {
  if !safe_http_url(url) {
    return -1
  }
  let mac = @process.run("/usr/bin/open", [url]) catch { _ => -1 }
  if mac == 0 {
    mac
  } else {
    @process.run("/usr/bin/xdg-open", [url]) catch {
      _ => mac
    }
  }
}

///|
pub async fn reveal_path(path : String, fallback_directory : String) -> Int {
  if !safe_absolute_path(path) || !safe_absolute_path(fallback_directory) {
    return -1
  }
  let mac = @process.run("/usr/bin/open", ["-R", path]) catch { _ => -1 }
  if mac == 0 {
    mac
  } else {
    @process.run("/usr/bin/xdg-open", [fallback_directory]) catch {
      _ => mac
    }
  }
}

///|
pub async fn pid_is_alive(pid : Int) -> Bool {
  if !safe_pid(pid) {
    return false
  }
  let alive = (@process.run("/bin/kill", ["-0", pid.to_string()]) catch {
      _ => -1
    }) ==
    0
  if !alive {
    return false
  }
  let output = @process.collect_output("/bin/ps", [
    "-p",
    pid.to_string(),
    "-o",
    "stat=",
  ]) catch {
    _ => return true
  }
  let stat = if output.0 == 0 {
    (output.1.text() catch { _ => "" }).trim().to_owned()
  } else {
    ""
  }
  process_status_is_alive(stat)
}

///|
pub async fn terminate_pid(pid : Int) -> Int {
  if !safe_pid(pid) {
    return -1
  }
  @process.run("/bin/kill", ["-TERM", pid.to_string()]) catch {
    _ => -1
  }
}

///|
pub async fn force_kill_pid(pid : Int) -> Int {
  if !safe_pid(pid) {
    return -1
  }
  @process.run("/bin/kill", ["-KILL", pid.to_string()]) catch {
    _ => -1
  }
}
