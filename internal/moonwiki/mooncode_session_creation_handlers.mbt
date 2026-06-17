///|
async fn handle_create_mooncode_session(
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
  let workspace_id = json_string(payload, "workspace_id", default="")
  let workspace = match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => workspace
    None => {
      send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
      return
    }
  }
  let daemon = ensure_moonclaw_daemon(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn,
      method_,
      503,
      "Service Unavailable",
      json_string(daemon, "message", default="MoonClaw daemon is not running"),
    )
    return
  }
  let task = match ensure_moonclaw_task(daemon, workspace, payload) {
    Ok(task) => task
    Err(message) => {
      send_api_error(conn, method_, 502, "Bad Gateway", message)
      return
    }
  }
  let now = @async.now().to_string()
  let message = trimmed_text(
    json_string(payload, "message", default=""),
    fallback="Create, inspect, test, or package executable code inside this MoonBook.",
  )
  let title = trimmed_text(
    json_string(payload, "title", default="MoonCode - \{workspace.name}"),
    fallback="MoonCode - \{workspace.name}",
  )
  let context_path = @mooncode.command_context_path(payload)
  let base = @mooncode.projected_session_record(
    workspace_id=workspace.id,
    workspace_name=workspace.name,
    workspace_root=workspace.root_path,
    task~,
    title~,
    created_at=now,
    updated_at=now,
    last_message=message,
    transcript=[],
    initial_context_path=context_path,
  )
  let command_packet = @mooncode.projected_command_packet(
    base, payload, "prompt", message, now, context_path,
  )
  let runtime_command = @mooncode.runtime_command_record(
    base, payload, message, command_packet,
  )
  append_mooncode_command_log(
    workspace_root,
    json_string(base, "id", default=""),
    command_packet,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode command queue",
      )
      return
    }
  }
  append_mooncode_runtime_command_log(
    workspace_root,
    json_string(base, "id", default=""),
    runtime_command,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime command feed",
      )
      return
    }
  }
  let queued = @mooncode.append_projected_command_event(
    base,
    action="prompt",
    status="queued",
    detail=message,
    created_at=now,
    path=context_path,
    command_packet~,
  )
  let dispatched = match
    send_mooncode_command_to_agent(
      workspace_root, queued, payload, message, command_packet,
    ) {
    Ok(session) => session
    Err(error) =>
      @mooncode.append_projected_command_event(
        queued,
        action="prompt",
        status="failed",
        detail=error,
        created_at=@async.now().to_string(),
        path=context_path,
        command_packet~,
      )
  }
  append_mooncode_runtime_dispatch_log(
    workspace_root,
    json_string(base, "id", default=""),
    @mooncode.projected_runtime_dispatch_receipt(
      dispatched,
      runtime_command,
      @async.now().to_string(),
    ),
  ) catch {
    _ => ()
  }
  let with_native_eval = sync_mooncode_native_eval_report(
    workspace_root, dispatched,
  ) catch {
    _ => dispatched
  }
  let with_action_plan = write_mooncode_action_plan_if_possible(
    workspace_root, with_native_eval,
  ) catch {
    _ => with_native_eval
  }
  let with_runtime_evidence = write_mooncode_runtime_evidence_if_possible(
    workspace_root, with_action_plan,
  ) catch {
    _ => with_action_plan
  }
  let with_eval_report = write_mooncode_eval_report_if_possible(
    with_runtime_evidence,
  ) catch {
    _ => with_runtime_evidence
  }
  let with_session_snapshot = write_mooncode_session_snapshot_if_possible(
    workspace_root, with_eval_report,
  ) catch {
    _ => with_eval_report
  }
  let with_runtime_handoff = write_mooncode_runtime_handoff_if_possible(
    workspace_root, with_session_snapshot,
  ) catch {
    _ => with_session_snapshot
  }
  write_agent_session_record(workspace_root, with_runtime_handoff) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session",
      )
      return
    }
  }
  append_new_mooncode_command_events(workspace_root, base, with_runtime_handoff) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode event log",
      )
      return
    }
  }
  send_json(
    conn,
    method_,
    enrich_agent_session_for_response(workspace_root, with_runtime_handoff, [
      task,
    ]),
  )
}
