///|
async fn handle_town_daemon(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let daemon = read_json_file_or_object(town_daemon_path(workspace_root))
  send_json(conn, method_, daemon)
}

///|
async fn handle_town_standing_goals(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(workspace_root)
  ignore(
    sync_all_book_pattern_standing_goals(root) catch {
      _ => Json::object({})
    },
  )
  send_json(
    conn,
    method_,
    Json::array(read_json_array_file(town_standing_goals_path(root))),
  )
}

///|
async fn handle_create_standing_goal(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(json) => json
    None => {
      send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
      return
    }
  }
  let root = @pathx.normalize(workspace_root)
  let town_root = @pathx.join(root, ".moontown")
  @fsx.make_directory(town_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create town state directory",
      )
      return
    }
  }
  let path = town_standing_goals_path(root)
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let record = standing_goal_record_from_payload(
    payload,
    daemon_tick=json_int(daemon, "tick_sequence", default=0),
  )
  let goals = upsert_record_by_id(read_json_array_file(path), record)
  @fsx.write_to_file(
    path,
    Json::array(goals).stringify(indent=2) + "\n",
    create=0o644,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not write standing goal",
      )
      return
    }
  }
  send_json(conn, method_, record)
}

///|
async fn handle_town_dispatch(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  ignore(body)
  let root = @pathx.normalize(workspace_root)
  let dispatch_root = @pathx.join(root, ".moontown/moondesk-dispatches")
  @fsx.make_directory(dispatch_root, recursive=true, exists_ok=true) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not create dispatch ledger",
      )
      return
    }
  }
  let id = @desk.stable_id("dispatch", @async.now().to_string())
  let path = ".moontown/moondesk-dispatches/" + id + ".json"
  let absolute = @pathx.join(root, path)
  let preflight_repair = sync_all_book_pattern_standing_goals(root) catch {
    _ => Json::object({ "ok": false, "status": "repair_failed" })
  }
  let descriptor = town_service_descriptor(root, "tick")
  let can_run = json_bool(descriptor, "configured", default=false)
  let mut exit_code = -1
  let mut stdout = ""
  let mut stderr = ""
  if can_run {
    let collected = Some(
      @process.collect_output(
        json_string(descriptor, "command", default=""),
        json_string_array_items(descriptor, "args"),
        cwd=json_string(descriptor, "cwd", default=root),
      ),
    ) catch {
      error => {
        stderr = "Could not run Moontown daemon tick: \{error}"
        None
      }
    }
    match collected {
      Some((code, out, err)) => {
        exit_code = code
        stdout = out.text()
        stderr = err.text()
      }
      None => ()
    }
  } else {
    stderr = "Moontown daemon tick service is not configured for this workspace"
  }
  let postflight_repair = sync_all_book_pattern_standing_goals(root) catch {
    _ => Json::object({ "ok": false, "status": "repair_failed" })
  }
  let record : Json = {
    "id": id,
    "ok": exit_code == 0,
    "status": if exit_code == 0 {
      "daemon tick completed"
    } else {
      "daemon tick failed"
    },
    "exit_code": exit_code,
    "path": path,
    "stdout": trim_for_record(stdout),
    "stderr": trim_for_record(stderr),
    "service_configured": can_run,
    "service_config_path": json_string(descriptor, "config_path", default=""),
    "service_command": json_string(descriptor, "display", default=""),
    "moondesk_standing_goal_preflight_repair": preflight_repair,
    "moondesk_standing_goal_postflight_repair": postflight_repair,
  }
  @fsx.write_to_file(absolute, record.stringify(indent=2) + "\n", create=0o644) catch {
    _ => ()
  }
  send_json(conn, method_, record)
}
