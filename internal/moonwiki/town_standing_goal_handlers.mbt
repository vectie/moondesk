///|
async fn handle_town_daemon(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let root = workspace_context(workspace_root).suite_root
  let daemon = read_json_file_or_object(town_daemon_path(root))
  let status = daemon_status_record(root, "daemon")
  send_json(
    conn,
    method_,
    api_contract_response(
      @mooncore.session_with_field(status, "state", daemon),
      ok=json_bool(status, "ok", default=false),
      status=json_string(status, "status", default="unknown"),
      message=json_string(
        status,
        "message",
        default="MoonTown daemon status is unknown",
      ),
      next_action=if json_bool(status, "running", default=false) {
        "use_moontown"
      } else if json_bool(status, "service_configured", default=false) {
        "start_moontown_daemon"
      } else {
        "configure_moontown_service"
      },
    ),
  )
}

///|
async fn handle_town_standing_goals(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let rows = match
    moontown_owner_get_json(workspace_root, "/api/standing-goals") {
    Ok(Array(rows)) => rows
    Ok(_) => {
      send_api_error(
        conn, method_, 502, "Bad Gateway", "MoonTown returned an invalid standing-goal registry",
      )
      return
    }
    Err(error) => {
      send_api_error(conn, method_, 503, "Service Unavailable", error)
      return
    }
  }
  let projected : Array[Json] = []
  for row in rows {
    projected.push(standing_goal_record_from_payload(row, daemon_tick=0))
  }
  send_json(conn, method_, Json::array(projected))
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
  let receipt = match
    moontown_owner_post_json(
      workspace_root,
      "/api/operator-requests",
      moontown_owner_watch_payload(payload),
    ) {
    Ok(value) => value
    Err(error) => {
      send_api_error(conn, method_, 503, "Service Unavailable", error)
      return
    }
  }
  let goal_id = json_string(receipt, "standing_goal_id", default="")
  if goal_id == "" {
    send_api_error(
      conn, method_, 502, "Bad Gateway", "MoonTown accepted no standing-goal identity",
    )
    return
  }
  let record = standing_goal_record_from_payload(
    @mooncore.session_with_field(payload, "id", goal_id.to_json()),
    daemon_tick=0,
  )
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
  ignore(workspace_root)
  send_api_error(
    conn, method_, 409, "Conflict", "Direct MoonTown ticks from MoonDesk are retired because they created a second Town dispatch ledger. Open MoonTown to run or recover its owner-managed daemon.",
  )
}
