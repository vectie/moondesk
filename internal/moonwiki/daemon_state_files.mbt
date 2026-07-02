///|
pub fn moondesk_daemon_dir(root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(root, "moondesk", "daemon")
}

///|
fn daemon_lifecycle_state_path(root : String) -> String {
  @pathx.join(moondesk_daemon_dir(root), "state.json")
}

///|
fn daemon_policy_path(root : String) -> String {
  @pathx.join(moondesk_daemon_dir(root), "policy.json")
}

///|
async fn read_daemon_lifecycle_state(root : String) -> Json {
  let path = daemon_lifecycle_state_path(root)
  if !@fsx.exists(path) {
    return Json::object({})
  }
  @json.parse(@fsx.read_file(path)) catch {
    _ => Json::object({})
  }
}

///|
async fn read_daemon_policy(root : String) -> Json {
  let path = daemon_policy_path(root)
  if !@fsx.exists(path) {
    return {
      "enabled": false,
      "desired_state": "stopped",
      "restart_count": 0,
      "last_health_check": "",
      "updated_at": "",
    }
  }
  @json.parse(@fsx.read_file(path)) catch {
    _ =>
      {
        "enabled": false,
        "desired_state": "stopped",
        "restart_count": 0,
        "last_health_check": "",
        "updated_at": "",
      }
  }
}

///|
async fn write_daemon_policy(root : String, record : Json) -> Unit {
  @fsx.make_directory(moondesk_daemon_dir(root), recursive=true, exists_ok=true) catch {
    _ => return
  }
  @fsx.write_to_file(
    daemon_policy_path(root),
    record.stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => ()
  }
}

///|
async fn set_daemon_desired_state(root : String, desired : String) -> Unit {
  let policy = read_daemon_policy(root)
  write_daemon_policy(root, {
    "enabled": json_bool(policy, "enabled", default=false),
    "desired_state": desired,
    "restart_count": json_int(policy, "restart_count", default=0),
    "last_health_check": json_string(policy, "last_health_check", default=""),
    "updated_at": @async.now().to_string(),
  })
}

///|
async fn increment_daemon_restart_count(root : String) -> Unit {
  let policy = read_daemon_policy(root)
  write_daemon_policy(root, {
    "enabled": json_bool(policy, "enabled", default=false),
    "desired_state": json_string(policy, "desired_state", default="running"),
    "restart_count": json_int(policy, "restart_count", default=0) + 1,
    "last_health_check": @async.now().to_string(),
    "updated_at": @async.now().to_string(),
  })
}

///|
async fn touch_daemon_policy_health(root : String) -> Unit {
  let policy = read_daemon_policy(root)
  if json_bool(policy, "enabled", default=false) {
    write_daemon_policy(root, {
      "enabled": true,
      "desired_state": json_string(policy, "desired_state", default="running"),
      "restart_count": json_int(policy, "restart_count", default=0),
      "last_health_check": @async.now().to_string(),
      "updated_at": json_string(policy, "updated_at", default=""),
    })
  }
}

///|
async fn write_daemon_lifecycle_state(root : String, record : Json) -> Unit {
  @fsx.make_directory(moondesk_daemon_dir(root), recursive=true, exists_ok=true) catch {
    _ => return
  }
  @fsx.write_to_file(
    daemon_lifecycle_state_path(root),
    record.stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => ()
  }
}
