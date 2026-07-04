///|
fn mooncode_runtime_service_lease_path(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    mooncode_session_log_dir(workspace_root, session_id),
    "runtime-service.lease.json",
  )
}

///|
async fn mooncode_runtime_service_lease_active(
  workspace_root : String,
  session_id : String,
  command_count : Int,
  now_ms : Int,
) -> Bool {
  let lease = read_json_file_or_object(
    mooncode_runtime_service_lease_path(workspace_root, session_id),
  )
  if json_string(lease, "kind", default="") != "mooncode-runtime-service-lease" {
    return false
  }
  if json_int(lease, "command_count", default=-1) != command_count {
    return false
  }
  let started_at_ms = json_int(lease, "started_at_ms", default=0)
  started_at_ms > 0 && now_ms - started_at_ms < 15000
}

///|
async fn try_acquire_mooncode_runtime_service_lease(
  workspace_root : String,
  session_id : String,
) -> Bool {
  if !mooncode_valid_session_id(session_id) {
    return false
  }
  let command_count = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  ).length()
  let now_ms = @async.now().to_int()
  let lease_path = mooncode_runtime_service_lease_path(
    workspace_root, session_id,
  )
  if mooncode_runtime_service_lease_active(
      workspace_root, session_id, command_count, now_ms,
    ) {
    return false
  }
  @fs.remove(lease_path) catch {
    _ => ()
  }
  @fsx.make_directory(
    mooncode_session_log_dir(workspace_root, session_id),
    recursive=true,
    exists_ok=true,
  ) catch {
    _ => return false
  }
  let lease : Json = {
    "kind": "mooncode-runtime-service-lease",
    "protocol": "mooncode.v1",
    "session_id": session_id,
    "command_count": command_count,
    "started_at_ms": now_ms,
  }
  @fs.write_file(
    lease_path,
    lease.stringify(indent=2) + "\n",
    create_mode=CreateNew,
    permission=0o644,
  ) catch {
    _ => return false
  }
  true
}

///|
async fn release_mooncode_runtime_service_lease(
  workspace_root : String,
  session_id : String,
) -> Bool {
  if !mooncode_valid_session_id(session_id) {
    return false
  }
  @fs.remove(mooncode_runtime_service_lease_path(workspace_root, session_id)) catch {
    _ => return false
  }
  true
}

///|
async fn reconcile_mooncode_runtime_service_lease_from_events(
  workspace_root : String,
  session_id : String,
  events : Array[Json],
) -> Bool {
  if mooncode_runtime_service_terminal_event_observed(events) {
    release_mooncode_runtime_service_lease(workspace_root, session_id)
  } else {
    false
  }
}

///|
fn mooncode_runtime_service_terminal_event_observed(
  events : Array[Json],
) -> Bool {
  for event in events {
    let kind = json_string(event, "kind", default="")
    if kind == "runtime.service_finished" ||
      kind == "runtime.service_failed" ||
      kind == "runtime_unavailable" {
      return true
    }
  }
  false
}
