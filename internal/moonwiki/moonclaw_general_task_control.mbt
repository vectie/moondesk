///|
fn moonclaw_general_task_workspace(payload : Json) -> String {
  let task = json_object_field(payload, "task").unwrap_or(payload)
  json_string(task, "cwd", default="")
}

///|
async fn moonclaw_general_task_belongs_to_suite(
  workspace_root : String,
  payload : Json,
) -> Bool {
  let cwd = moonclaw_general_task_workspace(payload)
  if cwd == "" {
    return false
  }
  for workspace in discover_workspaces(workspace_root) {
    if cwd == workspace.root_path {
      return true
    }
  }
  false
}

///|
/// Read the existing resumable stream's first metadata frame before submission.
/// Its head cursor is signed by the daemon and scoped to this task.
async fn moonclaw_general_task_head_cursor(
  daemon : Json,
  task_id : String,
) -> Result[String, String] {
  let config = match moonclaw_load_control_config(daemon) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let port = json_int(daemon, "port", default=0)
  let (response, client) = @http.get_stream(
    "http://127.0.0.1:\{port}/v1/task/\{task_id}/events/resume?cursor=start&replay_limit=1",
    headers=moonclaw_control_headers(config),
  ) catch {
    _ => return Err("MoonClaw turn boundary could not be read")
  }
  defer client.close()
  if response.code != 200 ||
    response.headers.get("x-moonclaw-instance-id") != Some(config.instance_id) {
    return Err("MoonClaw turn boundary returned an unbound control response")
  }
  let frame = client.read_until("\n\n") catch {
    _ => return Err("MoonClaw turn boundary stream could not be read")
  }
  guard frame is Some(frame) else {
    return Err("MoonClaw turn boundary metadata is unavailable")
  }
  for line in frame.split("\n") {
    if line.has_prefix("data:") {
      let value = @json.parse(line[5:].trim().to_owned()) catch {
        _ => return Err("MoonClaw turn boundary metadata is invalid")
      }
      if value
        is {
          "contract": String("moonclaw-task-stream.v2"),
          "kind": String("meta"),
          "head_cursor": String(cursor),
          ..
        } &&
        cursor.has_prefix("mct2.") {
        return Ok(cursor)
      }
    }
  }
  Err("MoonClaw turn boundary requires the updated task stream")
}

///|
async fn handle_moonclaw_general_task_cancel(
  workspace_root : String,
  task_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  if !moonclaw_general_task_id_valid(task_id) {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid task id")
    return
  }
  let daemon = moonclaw_daemon_status(workspace_root)
  let task = match moonclaw_get_json(daemon, "/v1/task/" + task_id) {
    Ok(value) => value
    Err(error) => {
      send_api_error(conn, method_, 502, "Bad Gateway", error)
      return
    }
  }
  if !moonclaw_general_task_belongs_to_suite(workspace_root, task) {
    send_api_error(
      conn, method_, 403, "Forbidden", "Task is outside this workspace",
    )
    return
  }
  let record = json_object_field(task, "task").unwrap_or(task)
  if json_string(record, "status", default="") != "generating" {
    send_json(conn, method_, {
      "task_id": task_id,
      "cancelled": false,
      "status": json_string(record, "status", default="unknown"),
    })
    return
  }
  match moonclaw_post_json(daemon, "/v1/task/" + task_id + "/cancel", {}) {
    Err(error) => send_api_error(conn, method_, 502, "Bad Gateway", error)
    Ok(response) =>
      send_json(conn, method_, {
        "task_id": task_id,
        "cancelled": true,
        "pending_messages": json_array_items(response, "pending_messages"),
      })
  }
}
