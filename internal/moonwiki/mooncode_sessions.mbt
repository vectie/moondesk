///|
async fn handle_mooncode_sessions(
  workspace_root : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let workspace_filter = query_value(request_path, "workspace").unwrap_or("")
  let sessions : Array[Json] = []
  for record in read_agent_session_records(workspace_root) {
    if workspace_filter != "" &&
      json_string(record, "workspace_id", default="") != workspace_filter {
      continue
    }
    sessions.push(attach_mooncode_session_projection(workspace_root, record))
  }
  sessions.sort_by(fn(left, right) {
    json_string(right, "updated_at", default="").compare(
      json_string(left, "updated_at", default=""),
    )
  })
  send_json(conn, method_, Json::array(sessions))
}

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
  let base = mooncode_new_session_record(
    workspace, task, title, now, message, payload,
  )
  let command_packet = mooncode_command_packet(
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
  let queued = append_mooncode_command_event(
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
      append_mooncode_command_event(
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
    mooncode_runtime_dispatch_receipt(dispatched, runtime_command),
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

///|
fn mooncode_new_session_record(
  workspace : @desk.DeskWorkspace,
  task : Json,
  title : String,
  now : String,
  message : String,
  payload : Json,
) -> Json {
  @mooncode.session_record(
    session_id=@desk.stable_id(
      "mooncode",
      workspace.id + ":" + title + ":" + now,
    ),
    workspace_id=workspace.id,
    workspace_name=workspace.name,
    workspace_root=workspace.root_path,
    task~,
    title~,
    created_at=now,
    updated_at=now,
    last_message=message,
    transcript=[],
    initial_context_path=@mooncode.command_context_path(payload),
  )
}

///|
async fn handle_mooncode_session_events(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let projected = attach_mooncode_session_projection(
        workspace_root, session,
      )
      send_json(conn, method_, json_array(projected, "mooncode_events"))
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_change_set(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      match mooncode_read_change_set_manifest(session) {
        Some(manifest) => send_json(conn, method_, manifest)
        None =>
          send_api_error(
            conn, method_, 404, "Not Found", "No MoonCode change set has been recorded for this session",
          )
      }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_patch_set(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      match mooncode_read_patch_set_manifest(session) {
        Some(manifest) => send_json(conn, method_, manifest)
        None =>
          send_api_error(
            conn, method_, 404, "Not Found", "No MoonCode patch set has been recorded for this session",
          )
      }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_tool_approvals(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      match mooncode_read_tool_approvals_manifest(session) {
        Some(manifest) => send_json(conn, method_, manifest)
        None =>
          send_api_error(
            conn, method_, 404, "Not Found", "No MoonCode tool approval manifest has been recorded for this session",
          )
      }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_tool_authorization_contract(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let projected = attach_mooncode_session_projection(
        workspace_root, session,
      )
      let manifest = match mooncode_read_tool_approvals_manifest(projected) {
        Some(manifest) => manifest
        None =>
          json_object_field_or_empty(
            projected, "mooncode_last_tool_approvals_manifest",
          )
      }
      send_json(
        conn,
        method_,
        @mooncode.tool_authorization_contract(session_id, manifest),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_tool_authorization(
  workspace_root : String,
  session_id : String,
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
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let now = @async.now().to_string()
  let preview = mooncode_tool_authorization_preview_event(payload, now)
  let projected = attach_mooncode_session_projection(workspace_root, session)
  let events = json_array_items(projected, "mooncode_events")
  let approval = @mooncode.tool_event_approval(preview)
  let target = @mooncode.tool_approval_target(preview)
  let should_record = approval != "" &&
    !@mooncode.tool_authorization_has_target(events, target)
  let with_preview = if should_record {
    append_mooncode_event_log(workspace_root, session_id, preview) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode tool authorization event",
        )
        return
      }
    }
    let updated = agent_session_with_field(session, "updated_at", now.to_json())
    let refreshed = refresh_mooncode_runtime_review_artifacts(
      workspace_root,
      attach_mooncode_session_projection(workspace_root, updated),
    )
    write_agent_session_record(workspace_root, refreshed) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not save MoonCode tool authorization state",
        )
        return
      }
    }
    refreshed
  } else {
    projected
  }
  let final_events = json_array_items(with_preview, "mooncode_events")
  let response = mooncode_tool_authorization_response(
    with_preview, preview, final_events,
  )
  send_json(conn, method_, response)
}

///|
async fn handle_mooncode_session_test_runs(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      match mooncode_read_test_runs_manifest(session) {
        Some(manifest) => send_json(conn, method_, manifest)
        None =>
          send_api_error(
            conn, method_, 404, "Not Found", "No MoonCode test-run manifest has been recorded for this session",
          )
      }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_package_candidates(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      send_json(
        conn,
        method_,
        mooncode_package_candidates_projection(session, session_id),
      )
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_action_plan(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let projected = attach_mooncode_session_projection(
        workspace_root, session,
      )
      send_json(
        conn,
        method_,
        mooncode_action_plan_projection(workspace_root, projected),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_eval_report(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let projected = attach_mooncode_session_projection(
        workspace_root, session,
      )
      let projected = sync_mooncode_native_eval_report(
        workspace_root, projected,
      ) catch {
        _ => projected
      }
      let with_saved_manifest = match
        mooncode_read_eval_report_manifest(projected) {
        Some(manifest) =>
          mooncode_session_with_saved_eval_manifest(projected, manifest)
        None => projected
      }
      send_json(
        conn,
        method_,
        @mooncode.eval_report_projection(with_saved_manifest),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_eval_report_ingest(
  workspace_root : String,
  session_id : String,
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
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let endpoint = json_string(
    payload,
    "endpoint",
    default=@mooncode.moonclaw_native_eval_report_endpoint(
      session_id, workspace_root,
    ),
  )
  let with_manifest = persist_mooncode_native_eval_report(
    workspace_root, session, payload, endpoint,
  ) catch {
    error => {
      send_api_error(
        conn,
        method_,
        500,
        "Internal Server Error",
        "Could not persist MoonCode eval report: \{error}",
      )
      return
    }
  }
  write_agent_session_record(workspace_root, with_manifest)
  send_json(conn, method_, @mooncode.eval_report_projection(with_manifest))
}

///|
async fn persist_mooncode_native_eval_report(
  workspace_root : String,
  session : Json,
  payload : Json,
  endpoint : String,
) -> Json {
  let native_report = mooncode_normalize_native_eval_report(payload, endpoint)
  let projected = attach_mooncode_session_projection(
    workspace_root,
    @mooncode.session_without_eval_report_projection(session),
  )
  let with_native = agent_session_with_field(
    projected, "mooncode_native_eval_report", native_report,
  )
  let with_snapshot = write_mooncode_session_snapshot_if_possible(
    workspace_root, with_native,
  ) catch {
    _ => with_native
  }
  let with_runtime_handoff = write_mooncode_runtime_handoff_if_possible(
    workspace_root, with_snapshot,
  ) catch {
    _ => with_snapshot
  }
  let with_manifest = write_mooncode_eval_report_if_possible(
    with_runtime_handoff,
  )
  let refreshed = attach_mooncode_session_projection(
    workspace_root, with_manifest,
  )
  append_new_mooncode_command_events(workspace_root, projected, refreshed)
  write_agent_session_record(workspace_root, refreshed)
  refreshed
}

///|
async fn handle_mooncode_session_runtime_handoff(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      match mooncode_read_runtime_handoff_manifest(session) {
        Some(manifest) =>
          if @mooncode.runtime_handoff_manifest_current(manifest) {
            send_json(conn, method_, manifest)
          } else {
            let projected = attach_mooncode_session_projection(
              workspace_root, session,
            )
            let with_manifest = write_mooncode_runtime_handoff_if_possible(
              workspace_root, projected,
            ) catch {
              _ => projected
            }
            match
              json_object_field(
                with_manifest, "mooncode_last_runtime_handoff_manifest",
              ) {
              Some(manifest) => send_json(conn, method_, manifest)
              None => send_json(conn, method_, manifest)
            }
          }
        None => {
          let projected = attach_mooncode_session_projection(
            workspace_root, session,
          )
          let with_manifest = write_mooncode_runtime_handoff_if_possible(
            workspace_root, projected,
          ) catch {
            _ => projected
          }
          match
            json_object_field(
              with_manifest, "mooncode_last_runtime_handoff_manifest",
            ) {
            Some(manifest) => send_json(conn, method_, manifest)
            None =>
              send_api_error(
                conn, method_, 404, "Not Found", "No MoonCode runtime handoff has been recorded for this session",
              )
          }
        }
      }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_execution_plan(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_dispatch_log(
        workspace_root, session_id,
      )
      let events = read_mooncode_event_log(workspace_root, session_id)
      let daemon = moonclaw_daemon_status(workspace_root)
      let native_ready = if json_bool(daemon, "running", default=false) {
        mooncode_native_runtime_ready(daemon) catch {
          _ => false
        }
      } else {
        false
      }
      send_json(
        conn,
        method_,
        mooncode_runtime_execution_plan(
          workspace_root,
          session,
          session_id,
          commands,
          receipts,
          events,
          moonclaw_root=json_string(daemon, "moonclaw_root", default=""),
          native_ready~,
          lease_now=@async.now().to_string(),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_store(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      match read_mooncode_session_snapshot(workspace_root, session_id) {
        Some(snapshot) => send_json(conn, method_, snapshot)
        None => {
          let projected = attach_mooncode_session_projection(
            workspace_root, session,
          )
          let with_snapshot = write_mooncode_session_snapshot_if_possible(
            workspace_root, projected,
          ) catch {
            _ => projected
          }
          match json_object_field(with_snapshot, "mooncode_session_snapshot") {
            Some(snapshot) => send_json(conn, method_, snapshot)
            None =>
              send_api_error(
                conn, method_, 404, "Not Found", "No MoonCode session snapshot has been recorded for this session",
              )
          }
        }
      }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_commands(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_dispatch_log(
        workspace_root, session_id,
      )
      let events = read_mooncode_event_log(workspace_root, session_id)
      let daemon = moonclaw_daemon_status(workspace_root)
      send_json(
        conn,
        method_,
        @mooncode.runtime_command_feed_result_response(
          session_id,
          commands,
          receipts,
          events,
          session,
          runtime_command_log_path=mooncode_runtime_command_log_path(
            workspace_root, session_id,
          ),
          runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
            workspace_root, session_id,
          ),
          workspace_root~,
          moonclaw_root=json_string(daemon, "moonclaw_root", default=""),
          host_base_url="",
          native_ready=false,
          lease_now=@async.now().to_string(),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_replay(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_dispatch_log(
        workspace_root, session_id,
      )
      send_json(
        conn,
        method_,
        mooncode_runtime_replay_state(
          session_id,
          commands,
          receipts,
          workspace_id=json_string(session, "workspace_id", default=""),
          workspace_name=json_string(session, "workspace_name", default=""),
          task_id=json_string(session, "moonclaw_task_id", default=""),
          runtime_command_log_path=mooncode_runtime_command_log_path(
            workspace_root, session_id,
          ),
          runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
            workspace_root, session_id,
          ),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_serve_jsonl(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(_) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_dispatch_log(
        workspace_root, session_id,
      )
      let scope = match query_value(request_path, "scope") {
        Some(value) => decode_query_value(value).trim().to_owned()
        None => "pending"
      }
      send_text(
        conn,
        method_,
        "application/x-ndjson; charset=utf-8",
        mooncode_runtime_serve_jsonl(commands, receipts, scope~),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_replay_ack(
  workspace_root : String,
  session_id : String,
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
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let commands = read_mooncode_runtime_command_log(workspace_root, session_id)
  let receipts = read_mooncode_runtime_dispatch_log(workspace_root, session_id)
  let prior_events = read_mooncode_event_log(workspace_root, session_id)
  let ack_receipts = mooncode_runtime_replay_ack_receipts(
    session,
    commands,
    payload,
    dispatch_receipts=receipts,
    prior_events~,
  )
  if ack_receipts.length() == 0 {
    send_api_error(
      conn, method_, 400, "Bad Request", "Runtime replay acknowledgement must include a known command_id, command_ids, or receipts[].",
    )
    return
  }
  for receipt in ack_receipts {
    append_mooncode_runtime_dispatch_log(workspace_root, session_id, receipt) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime replay receipt",
        )
        return
      }
    }
  }
  let events = @mooncode.runtime_replay_ack_normalized_events(ack_receipts)
  for event in events {
    append_mooncode_event_log(workspace_root, session_id, event) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime replay event",
        )
        return
      }
    }
  }
  let updated = agent_session_with_field(
    session,
    "updated_at",
    @async.now().to_string().to_json(),
  )
  let projected = attach_mooncode_session_projection(workspace_root, updated)
  let with_action_plan = write_mooncode_action_plan_if_possible(
    workspace_root, projected,
  ) catch {
    _ => projected
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
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session after runtime replay acknowledgement",
      )
      return
    }
  }
  let next_receipts = read_mooncode_runtime_dispatch_log(
    workspace_root, session_id,
  )
  send_json(
    conn,
    method_,
    @mooncode.runtime_replay_ack_result_response(
      session_id,
      commands,
      next_receipts,
      ack_receipts,
      events,
      json_object_field_or_empty(
        with_runtime_handoff, "mooncode_last_runtime_evidence_manifest",
      ),
      enrich_agent_session_for_response(workspace_root, with_runtime_handoff, []),
      runtime_command_log_path=mooncode_runtime_command_log_path(
        workspace_root, session_id,
      ),
      runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
        workspace_root, session_id,
      ),
    ),
  )
}

///|
async fn handle_mooncode_session_runtime_claim_state(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_dispatch_log(
        workspace_root, session_id,
      )
      send_json(
        conn,
        method_,
        mooncode_runtime_claim_state(
          session_id,
          commands,
          receipts,
          workspace_id=json_string(session, "workspace_id", default=""),
          workspace_name=json_string(session, "workspace_name", default=""),
          task_id=json_string(session, "moonclaw_task_id", default=""),
          runtime_command_log_path=mooncode_runtime_command_log_path(
            workspace_root, session_id,
          ),
          runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
            workspace_root, session_id,
          ),
          lease_now=query_value(request_path, "now").unwrap_or(""),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_claim(
  workspace_root : String,
  session_id : String,
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
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let commands = read_mooncode_runtime_command_log(workspace_root, session_id)
  let receipts = read_mooncode_runtime_dispatch_log(workspace_root, session_id)
  let claim_receipts = mooncode_runtime_claim_receipts(
    session, commands, receipts, payload,
  )
  for receipt in claim_receipts {
    append_mooncode_runtime_dispatch_log(workspace_root, session_id, receipt) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime claim receipt",
        )
        return
      }
    }
  }
  let updated = agent_session_with_field(
    session,
    "updated_at",
    @async.now().to_string().to_json(),
  )
  let projected = attach_mooncode_session_projection(workspace_root, updated)
  let with_action_plan = write_mooncode_action_plan_if_possible(
    workspace_root, projected,
  ) catch {
    _ => projected
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
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session after runtime claim",
      )
      return
    }
  }
  let next_receipts = read_mooncode_runtime_dispatch_log(
    workspace_root, session_id,
  )
  send_json(
    conn,
    method_,
    @mooncode.runtime_claim_result_response(
      session_id,
      commands,
      next_receipts,
      claim_receipts,
      enrich_agent_session_for_response(workspace_root, with_runtime_handoff, []),
      runtime_command_log_path=mooncode_runtime_command_log_path(
        workspace_root, session_id,
      ),
      runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
        workspace_root, session_id,
      ),
    ),
  )
}

///|
async fn handle_mooncode_session_serve_scheduler(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(_) => {
      let commands = read_mooncode_command_log(workspace_root, session_id)
      let runtime_commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_dispatch_log(
        workspace_root, session_id,
      )
      let events = read_mooncode_event_log(workspace_root, session_id)
      send_json(
        conn,
        method_,
        mooncode_serve_scheduler_response(
          session_id,
          commands,
          runtime_commands,
          receipts,
          events,
          lease_now=@async.now().to_string(),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_supervisor(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_dispatch_log(
        workspace_root, session_id,
      )
      let events = read_mooncode_event_log(workspace_root, session_id)
      let daemon = moonclaw_daemon_status(workspace_root)
      let native_ready = if json_bool(daemon, "running", default=false) {
        mooncode_native_runtime_ready(daemon) catch {
          _ => false
        }
      } else {
        false
      }
      send_json(
        conn,
        method_,
        mooncode_runtime_supervisor_launch_packet(
          workspace_root,
          session,
          session_id,
          commands,
          receipts,
          events,
          daemon,
          native_ready~,
          lease_now=@async.now().to_string(),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_supervisor_run(
  workspace_root : String,
  session_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = read_json_body(body).unwrap_or(Json::object({}))
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn, method_, 409, "Conflict", "MoonClaw daemon is not running",
    )
    return
  }
  if !mooncode_native_runtime_ready(daemon) {
    send_api_error(
      conn, method_, 409, "Conflict", "MoonClaw native MoonCode runtime is not available",
    )
    return
  }
  let loop_body = @mooncode.moonclaw_runtime_loop_request(
    session_id,
    workspace_root,
    consumer_id=json_string(
      payload,
      "consumer_id",
      default="moondesk-ui-runtime-loop",
    ),
    max_turns=json_int(payload, "max_turns", default=8),
  )
  let runtime_response = match
    moonclaw_post_json(
      daemon,
      @mooncode.moonclaw_native_runtime_loop_endpoint(session_id),
      loop_body,
    ) {
    Ok(response) => Ok(response)
    Err(_) =>
      moonclaw_post_json(
        daemon,
        @mooncode.moonclaw_native_runtime_turn_endpoint(session_id),
        @mooncode.moonclaw_runtime_turn_request(
          session_id,
          workspace_root,
          consumer_id="moondesk-ui-runtime-turn",
        ),
      )
  }
  let response = match runtime_response {
    Ok(response) => response
    Err(error) => {
      send_api_error(conn, method_, 502, "Bad Gateway", error)
      return
    }
  }
  let status = if json_bool(response, "accepted", default=false) {
    "done"
  } else {
    "failed"
  }
  let detail = json_string(
    response,
    "message",
    default=if status == "done" {
      "MoonClaw native MoonCode runtime loop completed"
    } else {
      "MoonClaw native MoonCode runtime loop did not accept work"
    },
  )
  let with_response = append_agent_message(
    mooncode_append_native_response_events(session, response),
    role="status",
    content=detail,
    status~,
  )
  let with_dispatch = agent_session_with_field(
    with_response,
    "mooncode_dispatch_mode",
    @mooncode.moonclaw_runtime_dispatch_mode(response).to_json(),
  )
  let with_updated = agent_session_with_field(
    with_dispatch,
    "updated_at",
    @async.now().to_string().to_json(),
  )
  let refreshed = refresh_mooncode_runtime_review_artifacts(
    workspace_root, with_updated,
  )
  write_agent_session_record(workspace_root, refreshed) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session after native runtime loop",
      )
      return
    }
  }
  append_new_mooncode_command_events(workspace_root, session, refreshed) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode event log after native runtime loop",
      )
      return
    }
  }
  send_json(
    conn,
    method_,
    enrich_agent_session_for_response(workspace_root, refreshed, []),
  )
}

///|
async fn handle_mooncode_session_runtime_dispatch(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_runtime_command_log(
        workspace_root, session_id,
      )
      let receipts = read_mooncode_runtime_dispatch_log(
        workspace_root, session_id,
      )
      send_json(
        conn,
        method_,
        @mooncode.runtime_dispatch_response(
          session_id,
          commands,
          receipts,
          workspace_id=json_string(session, "workspace_id", default=""),
          workspace_name=json_string(session, "workspace_name", default=""),
          task_id=json_string(session, "moonclaw_task_id", default=""),
          dispatch_mode=json_string(
            session,
            "mooncode_dispatch_mode",
            default="unknown",
          ),
          runtime_command_log_path=mooncode_runtime_command_log_path(
            workspace_root, session_id,
          ),
          runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
            workspace_root, session_id,
          ),
          lease_now=@async.now().to_string(),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_events(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let events = read_mooncode_event_log(workspace_root, session_id)
      send_json(
        conn,
        method_,
        @mooncode.runtime_event_sink_result_response(
          session_id,
          events,
          session,
          event_log_path=mooncode_event_log_path(workspace_root, session_id),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_runtime_event_ingest(
  workspace_root : String,
  session_id : String,
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
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let ingest_report = mooncode_runtime_ingest_report(session_id, payload)
  let events = json_array_items(ingest_report, "events")
  if events.length() == 0 {
    send_api_error(
      conn, method_, 400, "Bad Request", "No valid MoonCode runtime event found. Send an OpenSeek-style event object or {\"events\":[...]} payload.",
    )
    return
  }
  for event in events {
    append_mooncode_event_log(workspace_root, session_id, event) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime event",
        )
        return
      }
    }
  }
  let updated = agent_session_with_field(
    session,
    "updated_at",
    @async.now().to_string().to_json(),
  )
  let projected = attach_mooncode_session_projection(workspace_root, updated)
  let with_change_set = write_mooncode_change_set_if_possible(projected) catch {
    _ => projected
  }
  let with_patch_set = write_mooncode_patch_set_if_possible(with_change_set) catch {
    _ => with_change_set
  }
  let with_tool_approvals = write_mooncode_tool_approvals_if_possible(
    with_patch_set,
  ) catch {
    _ => with_patch_set
  }
  let with_test_runs = write_mooncode_test_runs_if_possible(with_tool_approvals) catch {
    _ => with_tool_approvals
  }
  let with_action_plan = write_mooncode_action_plan_if_possible(
    workspace_root, with_test_runs,
  ) catch {
    _ => with_test_runs
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
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session after runtime event ingest",
      )
      return
    }
  }
  send_json(
    conn,
    method_,
    @mooncode.runtime_event_ingest_result_response(
      session_id,
      events,
      read_mooncode_event_log(workspace_root, session_id),
      ingest_report,
      with_runtime_handoff,
      enrich_agent_session_for_response(workspace_root, with_runtime_handoff, []),
      event_log_path=mooncode_event_log_path(workspace_root, session_id),
    ),
  )
}

///|
async fn handle_mooncode_session_commands(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let commands = read_mooncode_command_log(workspace_root, session_id)
      send_json(
        conn,
        method_,
        @mooncode.command_queue_result_response(
          session_id,
          commands,
          session,
          command_log_path=mooncode_command_log_path(workspace_root, session_id),
        ),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_preflight(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = mooncode_preflight_payload_from_request(request_path)
  let action = @mooncode.command_action(payload)
  if !@mooncode.command_is_supported(action) {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      "Unsupported MoonCode command: \{action}",
    )
    return
  }
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let projected = attach_mooncode_session_projection(
        workspace_root, session,
      )
      send_json(
        conn,
        method_,
        mooncode_command_preflight(projected, payload, action),
      )
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_command(
  workspace_root : String,
  session_id : String,
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
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let action = @mooncode.command_action(payload)
  if !@mooncode.command_is_supported(action) {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      "Unsupported MoonCode command: \{action}",
    )
    return
  }
  let projected = attach_mooncode_session_projection(workspace_root, session)
  let preflight = mooncode_command_preflight(projected, payload, action)
  let force_preflight = json_bool(payload, "force_preflight", default=false)
  if json_bool(preflight, "blocked", default=false) && !force_preflight {
    let event = mooncode_command_preflight_blocked_event(
      preflight,
      payload,
      action,
      @async.now().to_string(),
    )
    append_mooncode_event_log(workspace_root, session_id, event) catch {
      _ => ()
    }
    send_api_json_error(conn, method_, 409, "Conflict", {
      "error": json_string(
        preflight,
        "reason",
        default="MoonCode command is blocked by current review gates",
      ),
      "preflight": preflight,
      "event": event,
    })
    return
  }
  let context_path = @mooncode.command_context_path(payload)
  let message = @mooncode.command_message(action, payload)
  let now = @async.now().to_string()
  if json_bool(preflight, "blocked", default=false) && force_preflight {
    let event = mooncode_command_preflight_override_event(
      preflight, payload, action, now,
    )
    append_mooncode_event_log(workspace_root, session_id, event) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not append MoonCode preflight override event",
        )
        return
      }
    }
  }
  let command_packet = mooncode_command_packet(
    session, payload, action, message, now, context_path,
  )
  let runtime_command = @mooncode.runtime_command_record(
    session, payload, message, command_packet,
  )
  append_mooncode_command_log(workspace_root, session_id, command_packet) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode command queue",
      )
      return
    }
  }
  append_mooncode_runtime_command_log(
    workspace_root, session_id, runtime_command,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode runtime command feed",
      )
      return
    }
  }
  let with_command = append_mooncode_command_event(
    session,
    action~,
    status="queued",
    detail=message,
    created_at=now,
    path=context_path,
    command_packet~,
  )
  let dispatched = if action == "note" {
    with_command
  } else if action == "cancel" {
    send_mooncode_cancel_command(
      workspace_root, with_command, action, payload, message, command_packet,
    )
  } else {
    match
      send_mooncode_command_to_agent(
        workspace_root, with_command, payload, message, command_packet,
      ) {
      Ok(session) => session
      Err(error) =>
        append_mooncode_command_event(
          with_command,
          action~,
          status="failed",
          detail=error,
          created_at=@async.now().to_string(),
          path=context_path,
          command_packet~,
        )
    }
  }
  append_mooncode_runtime_dispatch_log(
    workspace_root,
    session_id,
    mooncode_runtime_dispatch_receipt(dispatched, runtime_command),
  ) catch {
    _ => ()
  }
  let receipt_session = write_mooncode_review_receipt_if_needed(
    dispatched, action, command_packet, context_path, message, now,
  ) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not record MoonBook review receipt",
      )
      return
    }
  }
  let next = match receipt_session {
    Some(session) => session
    None => dispatched
  }
  let with_change_set = write_mooncode_change_set_if_possible(next) catch {
    _ => next
  }
  let with_patch_set = write_mooncode_patch_set_if_possible(with_change_set) catch {
    _ => with_change_set
  }
  let with_tool_approvals = write_mooncode_tool_approvals_if_possible(
    with_patch_set,
  ) catch {
    _ => with_patch_set
  }
  let with_test_runs = write_mooncode_test_runs_if_possible(with_tool_approvals) catch {
    _ => with_tool_approvals
  }
  let with_action_plan = write_mooncode_action_plan_if_possible(
    workspace_root, with_test_runs,
  ) catch {
    _ => with_test_runs
  }
  let with_native_eval = sync_mooncode_native_eval_report(
    workspace_root, with_action_plan,
  ) catch {
    _ => with_action_plan
  }
  let with_runtime_evidence = write_mooncode_runtime_evidence_if_possible(
    workspace_root, with_native_eval,
  ) catch {
    _ => with_native_eval
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
  append_new_mooncode_command_events(
    workspace_root, session, with_runtime_handoff,
  ) catch {
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
    enrich_agent_session_for_response(workspace_root, with_runtime_handoff, []),
  )
}

///|
async fn refresh_mooncode_runtime_review_artifacts(
  workspace_root : String,
  session : Json,
) -> Json {
  let with_change_set = write_mooncode_change_set_if_possible(session) catch {
    _ => session
  }
  let with_patch_set = write_mooncode_patch_set_if_possible(with_change_set) catch {
    _ => with_change_set
  }
  let with_tool_approvals = write_mooncode_tool_approvals_if_possible(
    with_patch_set,
  ) catch {
    _ => with_patch_set
  }
  let with_test_runs = write_mooncode_test_runs_if_possible(with_tool_approvals) catch {
    _ => with_tool_approvals
  }
  let with_action_plan = write_mooncode_action_plan_if_possible(
    workspace_root, with_test_runs,
  ) catch {
    _ => with_test_runs
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
  write_mooncode_runtime_handoff_if_possible(
    workspace_root, with_session_snapshot,
  ) catch {
    _ => with_session_snapshot
  }
}

///|
async fn attach_mooncode_session_projection(
  workspace_root : String,
  session : Json,
) -> Json {
  let raw_events = read_mooncode_raw_events(session)
  let session_id = json_string(session, "id", default="")
  let durable_events = read_mooncode_event_log(workspace_root, session_id)
  let durable_commands = read_mooncode_command_log(workspace_root, session_id)
  let durable_runtime_commands = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  )
  let durable_runtime_dispatches = read_mooncode_runtime_dispatch_log(
    workspace_root, session_id,
  )
  let events = project_mooncode_events(session, raw_events, durable_events)
  let log_path = if session_id == "" {
    ""
  } else {
    mooncode_event_log_path(workspace_root, session_id)
  }
  let command_log_path = if session_id == "" {
    ""
  } else {
    mooncode_command_log_path(workspace_root, session_id)
  }
  let runtime_command_log_path = if session_id == "" {
    ""
  } else {
    mooncode_runtime_command_log_path(workspace_root, session_id)
  }
  let runtime_dispatch_log_path = if session_id == "" {
    ""
  } else {
    mooncode_runtime_dispatch_log_path(workspace_root, session_id)
  }
  let summary_session = agent_session_with_field(
    agent_session_with_field(
      agent_session_with_field(
        agent_session_with_field(
          agent_session_with_field(
            agent_session_with_field(
              agent_session_with_field(
                agent_session_with_field(
                  session,
                  "mooncode_event_log_path",
                  log_path.to_json(),
                ),
                "mooncode_runtime_dispatch_log_path",
                runtime_dispatch_log_path.to_json(),
              ),
              "mooncode_runtime_dispatch_log_count",
              durable_runtime_dispatches.length().to_json(),
            ),
            "mooncode_runtime_command_log_path",
            runtime_command_log_path.to_json(),
          ),
          "mooncode_runtime_command_log_count",
          durable_runtime_commands.length().to_json(),
        ),
        "mooncode_append_log_count",
        durable_events.length().to_json(),
      ),
      "mooncode_command_log_path",
      command_log_path.to_json(),
    ),
    "mooncode_command_log_count",
    durable_commands.length().to_json(),
  )
  let summary = @mooncode.session_summary(summary_session, events)
  let next = agent_session_with_field(
    session,
    "mooncode_events",
    Json::array(events),
  )
  agent_session_with_field(next, "mooncode_summary", summary)
}

///|
async fn read_mooncode_raw_events(session : Json) -> Array[Json] {
  let task_id = json_string(session, "moonclaw_task_id", default="")
  if task_id == "" {
    return []
  }
  let events = read_moonclaw_conversation_events(session, task_id)
  if events.length() > 0 {
    events
  } else {
    read_moonclaw_log_events(session)
  }
}

///|
fn project_mooncode_events(
  session : Json,
  raw_events : Array[Json],
  durable_events : Array[Json],
) -> Array[Json] {
  let projected : Array[Json] = []
  for event in json_array_items(session, "mooncode_events") {
    projected.push(event)
  }
  if raw_events.length() > 0 {
    for event in raw_events {
      match mooncode_event_from_moonclaw_event(event) {
        Some(item) => projected.push(item)
        None => ()
      }
    }
  } else {
    for message in json_array_items(session, "transcript") {
      projected.push(mooncode_event_from_transcript_message(message))
    }
  }
  let merged = merge_mooncode_events(
    projected,
    json_array_items(session, "mooncode_command_events"),
    durable_events,
  )
  let normalized : Array[Json] = []
  for event in merged {
    normalized.push(@mooncode.normalize_event_record(event))
  }
  normalized
}

///|
fn append_mooncode_command_event(
  session : Json,
  action~ : String,
  status~ : String,
  detail~ : String,
  created_at~ : String,
  path? : String = "",
  command_packet? : Json = Json::object({}),
) -> Json {
  let event_id = json_string(
    command_packet,
    "command_id",
    default=@desk.stable_id(
      "mooncode-command",
      action + ":" + status + ":" + created_at + ":" + detail,
    ),
  )
  @mooncode.append_command_event(
    session,
    action~,
    status~,
    detail~,
    created_at~,
    path~,
    command_packet~,
    event_id~,
  )
}

///|
async fn mooncode_action_plan_projection(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let durable_events = if session_id == "" {
    []
  } else {
    read_mooncode_event_log(workspace_root, session_id)
  }
  let events = project_mooncode_events(session, [], durable_events)
  let commands = if session_id == "" {
    []
  } else {
    read_mooncode_command_log(workspace_root, session_id)
  }
  let runtime_commands = if session_id == "" {
    []
  } else {
    read_mooncode_runtime_command_log(workspace_root, session_id)
  }
  let runtime_dispatches = if session_id == "" {
    []
  } else {
    read_mooncode_runtime_dispatch_log(workspace_root, session_id)
  }
  let actions = mooncode_action_plan_items(
    session, commands, runtime_commands, runtime_dispatches, events,
  )
  let summary = @mooncode.session_summary(session, events)
  @mooncode.action_plan_response(
    session_id,
    session,
    actions,
    summary,
    runtime_commands,
    runtime_dispatches,
    recorded_at=@async.now().to_string(),
    runtime_command_log_path=if session_id == "" {
      ""
    } else {
      mooncode_runtime_command_log_path(workspace_root, session_id)
    },
    runtime_dispatch_log_path=if session_id == "" {
      ""
    } else {
      mooncode_runtime_dispatch_log_path(workspace_root, session_id)
    },
  )
}

///|
async fn handle_mooncode_session_runtime_evidence(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) =>
      send_json(
        conn,
        method_,
        mooncode_session_runtime_evidence_projection(workspace_root, session),
      )
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn mooncode_session_runtime_evidence_projection(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let durable_events = if session_id == "" {
    []
  } else {
    read_mooncode_event_log(workspace_root, session_id)
  }
  let events = project_mooncode_events(session, [], durable_events)
  let commands = if session_id == "" {
    []
  } else {
    read_mooncode_command_log(workspace_root, session_id)
  }
  let runtime_commands = if session_id == "" {
    []
  } else {
    read_mooncode_runtime_command_log(workspace_root, session_id)
  }
  let projection = @mooncode.session_runtime_evidence(
    session,
    commands,
    runtime_commands,
    events,
    recorded_at=@async.now().to_string(),
  )
  agent_session_with_field(
    agent_session_with_field(
      agent_session_with_field(
        agent_session_with_field(
          agent_session_with_field(
            projection,
            "manifest_path",
            (if session_id == "" {
              ""
            } else {
              @mooncode.runtime_evidence_manifest_relative_path(session_id)
            }).to_json(),
          ),
          "absolute_manifest_path",
          (if session_id == "" {
            ""
          } else {
            @pathx.join(
              workspace_root,
              @mooncode.runtime_evidence_manifest_relative_path(session_id),
            )
          }).to_json(),
        ),
        "command_log_path",
        (if session_id == "" {
          ""
        } else {
          mooncode_command_log_path(workspace_root, session_id)
        }).to_json(),
      ),
      "runtime_command_log_path",
      (if session_id == "" {
        ""
      } else {
        mooncode_runtime_command_log_path(workspace_root, session_id)
      }).to_json(),
    ),
    "event_log_path",
    (if session_id == "" {
      ""
    } else {
      mooncode_event_log_path(workspace_root, session_id)
    }).to_json(),
  )
}

///|
async fn write_mooncode_eval_report_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode eval report needs a MoonBook workspace root")
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.eval_report_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let summary = @mooncode.session_summary(session, events)
  let report = @mooncode.eval_report_projection(
    agent_session_with_field(session, "mooncode_summary", summary),
  )
  let recorded_at = @async.now().to_string()
  let manifest = agent_session_with_field(
    agent_session_with_field(
      agent_session_with_field(report, "recorded_at", recorded_at.to_json()),
      "manifest_path",
      relative.to_json(),
    ),
    "absolute_manifest_path",
    absolute.to_json(),
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_session_snapshot_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  if session_id == "" {
    fail("MoonCode session snapshot needs a session id")
  }
  let events = project_mooncode_events(session, [], [])
  let commands = read_mooncode_command_log(workspace_root, session_id)
  let runtime_commands = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  )
  let runtime_dispatches = read_mooncode_runtime_dispatch_log(
    workspace_root, session_id,
  )
  let session_id = json_string(session, "id", default="")
  let snapshot = @mooncode.session_snapshot(
    session,
    events,
    commands,
    runtime_commands,
    runtime_dispatches,
    recorded_at=@async.now().to_string(),
    snapshot_path=mooncode_session_snapshot_path(workspace_root, session_id),
    command_log_path=mooncode_command_log_path(workspace_root, session_id),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    event_log_path=mooncode_event_log_path(workspace_root, session_id),
  )
  write_mooncode_session_snapshot(workspace_root, session_id, snapshot)
  agent_session_with_field(session, "mooncode_session_snapshot", snapshot)
}

///|
async fn write_mooncode_runtime_handoff_manifest(
  workspace_root : String,
  session : Json,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode runtime handoff needs a MoonBook workspace root")
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.runtime_handoff_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let commands = read_mooncode_command_log(workspace_root, session_id)
  let runtime_commands = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  )
  let runtime_dispatches = read_mooncode_runtime_dispatch_log(
    workspace_root, session_id,
  )
  let summary = @mooncode.session_summary(session, events)
  let daemon = moonclaw_daemon_status(workspace_root)
  let daemon_running = json_bool(daemon, "running", default=false)
  let native_ready = if daemon_running {
    mooncode_native_runtime_ready(daemon) catch {
      _ => false
    }
  } else {
    false
  }
  let runtime_replay = mooncode_runtime_replay_state(
    session_id,
    runtime_commands,
    runtime_dispatches,
    workspace_id=json_string(session, "workspace_id", default=""),
    workspace_name=json_string(session, "workspace_name", default=""),
    task_id=json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
  )
  let runtime_claim = mooncode_runtime_claim_state(
    session_id,
    runtime_commands,
    runtime_dispatches,
    workspace_id=json_string(session, "workspace_id", default=""),
    workspace_name=json_string(session, "workspace_name", default=""),
    task_id=json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
  )
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.runtime_handoff_manifest(
    session,
    summary,
    runtime_replay,
    runtime_claim,
    commands,
    runtime_commands,
    runtime_dispatches,
    daemon,
    native_ready,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
    workspace_root=book_root,
    session_snapshot_path=mooncode_session_snapshot_path(
      workspace_root, session_id,
    ),
    command_log_path=mooncode_command_log_path(workspace_root, session_id),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    event_log_path=mooncode_event_log_path(workspace_root, session_id),
    stream_checkpoint_path=mooncode_stream_checkpoint_path(
      workspace_root, session_id, "moondesk-ui",
    ),
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn mooncode_read_change_set_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_change_set_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-change-set" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.change_set_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-change-set" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_patch_set_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_patch_set_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-patch-set" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.patch_set_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-patch-set" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_tool_approvals_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_tool_approvals_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-tool-approvals" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.tool_approvals_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-tool-approvals" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_test_runs_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_test_runs_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-test-runs" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.test_runs_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-test-runs" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_eval_report_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_eval_report_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-eval-report" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.eval_report_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-eval-report" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_runtime_handoff_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_runtime_handoff_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-runtime-handoff" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.runtime_handoff_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-runtime-handoff" {
    Some(manifest)
  } else {
    None
  }
}

///|
fn mooncode_tool_authorization_preview_event(
  payload : Json,
  created_at : String,
) -> Json {
  @mooncode.tool_authorization_preview_event(
    payload,
    created_at,
    fallback_id=@desk.stable_id(
      "mooncode-tool-auth",
      payload.stringify() + ":" + created_at,
    ),
  )
}

///|
fn mooncode_tool_authorization_response(
  session : Json,
  preview : Json,
  events : Array[Json],
) -> Json {
  @mooncode.tool_authorization_response(
    json_string(session, "id", default=""),
    preview,
    events,
    json_object_field_or_empty(session, "mooncode_last_tool_approvals_manifest"),
  )
}

///|
fn mooncode_action_plan_items(
  session : Json,
  commands : Array[Json],
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  events : Array[Json],
) -> Array[Json] {
  let summary = @mooncode.session_summary(session, events)
  @mooncode.action_plan_items(
    commands,
    runtime_commands,
    runtime_dispatches,
    events,
    summary,
    lease_now=@async.now().to_string(),
  )
}

///|
fn mooncode_change_set_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.change_set_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-change-set",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_patch_set_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.patch_set_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-patch-set",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_tool_approvals_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.tool_approvals_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-tool-approvals",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_test_runs_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.test_runs_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-test-runs",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_action_plan_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.action_plan_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-action-plan",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_runtime_evidence_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.runtime_evidence_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-runtime-evidence",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_eval_report_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.eval_report_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-eval-report",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
async fn write_mooncode_review_receipt(
  session : Json,
  action : String,
  command_packet : Json,
  context_path : String,
  detail : String,
  command_created_at : String,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(session, command_packet)
  if book_root == "" {
    fail("MoonCode review receipt needs a MoonBook workspace root")
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(
      session,
      "id",
      default=json_string(command_packet, "session_id", default=""),
    ),
    fallback="session",
  )
  let command_id = @mooncode.artifact_safe_id(
    json_string(command_packet, "command_id", default="command"),
    fallback="command",
  )
  let relative = @mooncode.review_receipt_relative_path(
    session_id, command_id, action,
  )
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let recorded_at = @async.now().to_string()
  let receipt = @mooncode.review_receipt_manifest(
    session,
    action,
    command_packet,
    context_path,
    detail,
    command_created_at,
    command_id~,
    recorded_at~,
    receipt_path=relative,
    absolute_receipt_path=absolute,
  )
  @fsx.write_to_file(absolute, receipt.stringify(indent=2) + "\n")
  receipt
}

///|
async fn write_mooncode_package_manifest_for_receipt(
  session : Json,
  receipt : Json,
  command_packet : Json,
  context_path : String,
  detail : String,
  command_created_at : String,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(session, command_packet)
  if book_root == "" {
    fail("MoonCode package manifest needs a MoonBook workspace root")
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(
      session,
      "id",
      default=json_string(command_packet, "session_id", default=""),
    ),
    fallback="session",
  )
  let command_id = @mooncode.artifact_safe_id(
    json_string(command_packet, "command_id", default="command"),
    fallback="command",
  )
  let relative = @mooncode.package_manifest_relative_path(
    session_id, command_id,
  )
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let recorded_at = @async.now().to_string()
  let candidate_paths = @mooncode.package_candidate_paths(context_path)
  let source_inventory = mooncode_package_source_inventory(
    book_root,
    candidate_paths,
    package_root=@pathx.dirname(relative).to_owned(),
    command_id~,
  )
  let manifest = @mooncode.package_manifest(
    session, receipt, command_packet, context_path, detail, command_created_at, recorded_at,
    relative, absolute, source_inventory,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  let index_manifest = write_mooncode_package_index_manifest(
    session, session_id, manifest,
  )
  let events = json_array_items(session, "mooncode_command_events")
  events.push(
    mooncode_package_manifest_event(
      manifest, context_path, recorded_at, command_packet,
    ),
  )
  events.push(mooncode_package_index_manifest_event(index_manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  let with_manifest = agent_session_with_field(
    with_events, "mooncode_last_package_manifest", manifest,
  )
  agent_session_with_field(
    with_manifest, "mooncode_last_package_index_manifest", index_manifest,
  )
}

///|
async fn write_mooncode_package_index_manifest(
  session : Json,
  session_id : String,
  latest_manifest : Json,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(latest_manifest, "command_packet"),
  )
  if book_root == "" {
    fail("MoonCode package index needs a MoonBook workspace root")
  }
  let relative = @mooncode.package_index_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let packages = mooncode_package_candidate_manifests(session, session_id)
  let latest_path = json_string(latest_manifest, "manifest_path", default="")
  if latest_path != "" &&
    !@mooncode.package_manifest_list_contains(packages, latest_path) {
    packages.push(latest_manifest)
  }
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.package_index_manifest(
    session,
    session_id,
    latest_manifest,
    packages,
    recorded_at,
    relative,
    absolute,
    @pathx.dirname(relative).to_owned(),
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn mooncode_package_source_inventory(
  book_root : String,
  candidate_paths : Array[String],
  package_root~ : String,
  command_id~ : String,
) -> Array[Json] {
  let records : Array[Json] = []
  for candidate in candidate_paths {
    records.push(
      mooncode_package_source_record(
        book_root,
        candidate,
        package_root~,
        command_id~,
      ),
    )
  }
  records
}

///|
async fn mooncode_package_source_record(
  book_root : String,
  candidate : String,
  package_root~ : String,
  command_id~ : String,
) -> Json {
  match resolve_workspace_path(book_root, candidate) {
    Some((absolute, relative)) =>
      if !@fs.exists(absolute) {
        @mooncode.package_source_missing_record(relative)
      } else {
        let kind = @fs.kind(absolute) catch {
          _ => return @mooncode.package_source_unknown_record(relative)
        }
        match kind {
          @fs.FileKind::Directory =>
            @mooncode.package_source_directory_record(relative)
          _ =>
            mooncode_package_file_record(
              absolute,
              relative,
              book_root~,
              package_root~,
              command_id~,
            )
        }
      }
    None => @mooncode.package_source_invalid_record(candidate)
  }
}

///|
async fn mooncode_package_file_record(
  absolute : String,
  relative : String,
  book_root~ : String,
  package_root~ : String,
  command_id~ : String,
) -> Json {
  let bytes = @fs.read_file(absolute).binary() catch {
    _ => return @mooncode.package_source_unknown_record(relative)
  }
  let text = @fs.read_file(absolute).text() catch { _ => "" }
  let promotion = mooncode_promote_package_source(
    book_root,
    package_root,
    command_id,
    relative,
    text,
    can_promote=text != "",
  )
  @mooncode.package_source_file_record(
    relative,
    bytes.length(),
    @crypto.bytes_to_hex_string(@crypto.sha256(bytes.to_fixedarray())),
    promotion,
  )
}

///|
async fn mooncode_promote_package_source(
  book_root : String,
  package_root : String,
  command_id : String,
  relative : String,
  content : String,
  can_promote~ : Bool,
) -> Json {
  let promoted_path = @mooncode.package_source_promotion_path(
    package_root, command_id, relative,
  )
  let promoted_absolute = @pathx.join(book_root, promoted_path)
  if !can_promote {
    return @mooncode.package_source_non_text_promotion(
      relative, promoted_path, promoted_absolute,
    )
  }
  @fsx.make_directory(
    @pathx.dirname(promoted_absolute),
    recursive=true,
    exists_ok=true,
  ) catch {
    error =>
      return @mooncode.package_source_failed_promotion(
        relative,
        promoted_path,
        promoted_absolute,
        "\{error}",
      )
  }
  @fsx.write_to_file(promoted_absolute, content) catch {
    error =>
      return @mooncode.package_source_failed_promotion(
        relative,
        promoted_path,
        promoted_absolute,
        "\{error}",
      )
  }
  @mooncode.package_source_promoted_promotion(
    relative, promoted_path, promoted_absolute, content,
  )
}

///|
async fn mooncode_package_candidates_projection(
  session : Json,
  session_id : String,
) -> Json {
  let packages = mooncode_package_candidate_manifests(session, session_id)
  let index_manifest = mooncode_package_index_manifest(session, session_id)
  @mooncode.package_candidates_projection(
    session, session_id, packages, index_manifest,
  )
}

///|
async fn mooncode_package_index_manifest(
  session : Json,
  session_id : String,
) -> Json {
  match json_object_field(session, "mooncode_last_package_index_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-package-index" {
        return manifest
      }
    None => ()
  }
  let book_root = json_string(session, "workspace_root", default="")
  if book_root == "" {
    return Json::object({})
  }
  let absolute = @pathx.join(
    book_root,
    @mooncode.package_index_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch {
    _ => return Json::object({})
  }
  let manifest = @json.parse(text) catch { _ => return Json::object({}) }
  if json_string(manifest, "kind", default="") == "mooncode-package-index" {
    manifest
  } else {
    Json::object({})
  }
}

///|
async fn mooncode_package_candidate_manifests(
  session : Json,
  session_id : String,
) -> Array[Json] {
  let manifests : Array[Json] = []
  let book_root = json_string(session, "workspace_root", default="")
  if book_root != "" {
    let safe_session = @mooncode.artifact_safe_id(
      session_id,
      fallback="session",
    )
    let root = @pathx.join(
      book_root,
      "portable/app-tool/mooncode/\{safe_session}",
    )
    for name in read_directory_names(root, include_hidden=false) {
      if name.has_prefix("package-") && name.has_suffix(".json") {
        let manifest = read_json_file_or_object(@pathx.join(root, name))
        if json_string(manifest, "kind", default="") ==
          "mooncode-package-manifest" {
          manifests.push(manifest)
        }
      }
    }
  }
  let last = json_object_field_or_empty(
    session, "mooncode_last_package_manifest",
  )
  if json_string(last, "kind", default="") == "mooncode-package-manifest" {
    let path = json_string(last, "manifest_path", default="")
    if !@mooncode.package_manifest_list_contains(manifests, path) {
      manifests.push(last)
    }
  }
  manifests
}

///|
fn mooncode_review_receipt_book_root(
  session : Json,
  command_packet : Json,
) -> String {
  let from_session = json_string(session, "workspace_root", default="")
  if from_session != "" {
    return @pathx.normalize(from_session)
  }
  let from_packet = json_string(command_packet, "workspace_root", default="")
  if from_packet != "" {
    return @pathx.normalize(from_packet)
  }
  let cwd = json_string(session, "cwd", default="")
  if cwd != "" {
    @pathx.normalize(cwd)
  } else {
    ""
  }
}

///|
fn mooncode_review_receipt_event(
  action : String,
  receipt_path : String,
  context_path : String,
  recorded_at : String,
  command_packet : Json,
) -> Json {
  let command_id = json_string(command_packet, "command_id", default="command")
  @mooncode.review_receipt_event(
    action,
    receipt_path,
    context_path,
    recorded_at,
    command_packet,
    @desk.stable_id(
      "mooncode-review-receipt",
      action + ":" + command_id + ":" + receipt_path,
    ),
  )
}

///|
fn mooncode_package_manifest_event(
  manifest : Json,
  context_path : String,
  recorded_at : String,
  command_packet : Json,
) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.package_manifest_event(
    manifest,
    context_path,
    recorded_at,
    command_packet,
    @desk.stable_id(
      "mooncode-package-manifest",
      json_string(manifest, "command_id", default="command") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_package_index_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.package_index_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-package-index",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_runtime_handoff_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.runtime_handoff_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-runtime-handoff",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
async fn append_new_mooncode_command_events(
  workspace_root : String,
  before : Json,
  after : Json,
) -> Unit {
  let session_id = json_string(after, "id", default="")
  let known : Map[String, Bool] = {}
  for event in read_mooncode_event_log(workspace_root, session_id) {
    let id = json_string(event, "id", default="")
    if id != "" {
      known[id] = true
    }
  }
  for event in json_array_items(before, "mooncode_command_events") {
    let id = json_string(event, "id", default="")
    if id != "" {
      known[id] = true
    }
  }
  for event in json_array_items(after, "mooncode_command_events") {
    let id = json_string(event, "id", default="")
    if id == "" || known.get(id).unwrap_or(false) {
      continue
    }
    append_mooncode_event_log(workspace_root, session_id, event)
    known[id] = true
  }
}

///|
async fn send_mooncode_command_to_agent(
  workspace_root : String,
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Result[Json, String] {
  let daemon = ensure_moonclaw_daemon(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return Err(
      json_string(daemon, "message", default="MoonClaw daemon is not running"),
    )
  }
  if mooncode_native_runtime_ready(daemon) {
    return send_mooncode_native_runtime_command(
      daemon, session, payload, message, command_packet,
    )
  }
  let task = match ensure_session_task(daemon, session) {
    Ok(task) => task
    Err(error) => return Err(error)
  }
  let task_id = json_string(task, "id", default="")
  let sent_at = @async.now().to_string()
  let with_user = append_agent_message(
    update_agent_session_status(session, task),
    role="user",
    content=message,
    status="sending",
    created_at=sent_at,
  )
  let runtime_message = @mooncode.command_runtime_message(
    message, command_packet,
  )
  let moonclaw_message = agent_session_message(
    payload, session, runtime_message,
  )
  let next = match
    send_moonclaw_message(
      daemon,
      task_id,
      moonclaw_message,
      web_search=json_bool(payload, "web_search", default=false),
    ) {
    Ok(response) =>
      append_agent_message(
        with_user,
        role="status",
        content=agent_send_status(response),
        status=if json_bool(response, "queued", default=false) {
          "queued"
        } else {
          "running"
        },
      )
    Err(error) =>
      append_agent_message(
        with_user,
        role="status",
        content=error,
        status="failed",
      )
  }
  Ok(
    agent_session_with_field(
      agent_session_with_field(
        agent_session_with_field(
          agent_session_with_field(next, "last_message", message.to_json()),
          "mooncode_last_command_packet",
          command_packet,
        ),
        "mooncode_dispatch_mode",
        "moonclaw-task-bridge".to_json(),
      ),
      "updated_at",
      @async.now().to_string().to_json(),
    ),
  )
}

///|
async fn mooncode_native_runtime_ready(daemon : Json) -> Bool {
  match moonclaw_get_json(daemon, "/v1/mooncode/capabilities") {
    Ok(_) => true
    Err(_) => false
  }
}

///|
async fn sync_mooncode_native_eval_report(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  if session_id == "" {
    return session
  }
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return session
  }
  if !mooncode_native_runtime_ready(daemon) {
    return session
  }
  let endpoint = @mooncode.moonclaw_native_eval_report_endpoint(
    session_id, workspace_root,
  )
  match moonclaw_get_json(daemon, endpoint) {
    Ok(report) =>
      agent_session_with_field(
        session,
        "mooncode_native_eval_report",
        mooncode_normalize_native_eval_report(report, endpoint),
      )
    Err(_) => session
  }
}

///|
fn mooncode_normalize_native_eval_report(
  report : Json,
  endpoint : String,
) -> Json {
  @mooncode.normalize_native_eval_report(report, endpoint)
}

///|
async fn send_mooncode_native_runtime_command(
  daemon : Json,
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Result[Json, String] {
  let session_id = json_string(session, "id", default="")
  if session_id == "" {
    return Err("MoonCode native runtime dispatch needs a session id")
  }
  let body = @mooncode.native_command_body(
    session, payload, message, command_packet,
  )
  let queue_response = match
    moonclaw_post_json(
      daemon,
      @mooncode.moonclaw_native_command_endpoint(session_id),
      body,
    ) {
    Ok(response) => response
    Err(error) => return Err(error)
  }
  let queue_accepted = json_bool(queue_response, "accepted", default=true)
  let runtime_response = if queue_accepted {
    let loop_response = moonclaw_post_json(
      daemon,
      @mooncode.moonclaw_native_runtime_loop_endpoint(session_id),
      @mooncode.moonclaw_runtime_loop_request(
        session_id,
        json_string(body, "book_root", default=""),
        consumer_id="moondesk-native-runtime-loop",
        max_turns=8,
      ),
    )
    match loop_response {
      Ok(_) => loop_response
      Err(_) =>
        moonclaw_post_json(
          daemon,
          @mooncode.moonclaw_native_runtime_turn_endpoint(session_id),
          @mooncode.moonclaw_runtime_turn_request(
            session_id,
            json_string(body, "book_root", default=""),
            consumer_id="moondesk-native-runtime-turn",
          ),
        )
    }
  } else {
    Err(
      json_string(
        queue_response,
        "message",
        default="MoonClaw rejected native MoonCode queueing",
      ),
    )
  }
  let runtime_payload = match runtime_response {
    Ok(payload) => payload
    Err(_) => Json::object({})
  }
  let dispatch_result = @mooncode.moonclaw_native_runtime_dispatch_result(
    queue_response,
    runtime_payload,
    command_packet,
    queue_accepted~,
    runtime_succeeded=runtime_response is Ok(_),
    runtime_error=match runtime_response {
      Ok(_) => ""
      Err(error) => error
    },
  )
  let status = json_string(dispatch_result, "status", default="failed")
  let detail = json_string(dispatch_result, "detail", default="")
  let with_status = append_agent_message(
    mooncode_append_native_response_events(
      mooncode_append_native_response_events(session, queue_response),
      runtime_payload,
    ),
    role="status",
    content=detail,
    status~,
  )
  Ok(
    agent_session_with_field(
      agent_session_with_field(
        agent_session_with_field(
          agent_session_with_field(
            with_status,
            "last_message",
            message.to_json(),
          ),
          "mooncode_last_command_packet",
          command_packet,
        ),
        "mooncode_dispatch_mode",
        json_string(dispatch_result, "dispatch_mode", default="").to_json(),
      ),
      "updated_at",
      @async.now().to_string().to_json(),
    ),
  )
}

///|
fn mooncode_json_array_contains_id(items : Array[Json], id : String) -> Bool {
  for item in items {
    if json_string(item, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn mooncode_append_native_response_events(
  session : Json,
  response : Json,
) -> Json {
  let stopped_by = json_string(response, "stopped_by", default="unknown")
  let ran_turn_count = json_int(response, "ran_turn_count", default=0)
  let failed_turn_count = json_int(response, "failed_turn_count", default=0)
  let session_id = json_string(response, "session_id", default="")
  let consumer_id = json_string(response, "consumer_id", default="")
  let created_at = @async.now().to_string()
  @mooncode.append_native_response_events(
    session,
    response,
    loop_fallback_id=@desk.stable_id(
      "mooncode-runtime-loop",
      session_id +
      ":" +
      consumer_id +
      ":" +
      created_at +
      ":" +
      stopped_by +
      ":" +
      ran_turn_count.to_string() +
      ":" +
      failed_turn_count.to_string(),
    ),
    loop_fallback_created_at=created_at,
  )
}

///|
async fn send_mooncode_cancel_command(
  workspace_root : String,
  session : Json,
  action : String,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return append_mooncode_command_event(
      session,
      action~,
      status="failed",
      detail="MoonClaw daemon is not running",
      created_at=@async.now().to_string(),
    )
  }
  if mooncode_native_runtime_ready(daemon) {
    return match
      send_mooncode_native_runtime_command(
        daemon, session, payload, message, command_packet,
      ) {
      Ok(next) => next
      Err(error) =>
        append_mooncode_command_event(
          session,
          action~,
          status="failed",
          detail=error,
          created_at=@async.now().to_string(),
        )
    }
  }
  let task_id = json_string(session, "moonclaw_task_id", default="")
  if task_id == "" {
    return append_mooncode_command_event(
      session,
      action~,
      status="failed",
      detail="Session has no MoonClaw task",
      created_at=@async.now().to_string(),
    )
  }
  let (status, detail) = match
    moonclaw_post_json(daemon, "/v1/task/\{task_id}/cancel", Json::object({})) {
    Ok(payload) => ("cancelled", "cancelled: \{payload.stringify()}")
    Err(error) => ("failed", error)
  }
  append_agent_message(
    append_mooncode_command_event(
      session,
      action~,
      status~,
      detail~,
      created_at=@async.now().to_string(),
    ),
    role="status",
    content=detail,
    status~,
  )
}

///|
fn mooncode_event_from_transcript_message(message : Json) -> Json {
  @mooncode.transcript_message_event(
    message,
    fallback_id=@desk.stable_id("mooncode-message", message.stringify()),
  )
}

///|
fn mooncode_event_from_moonclaw_event(event : Json) -> Json? {
  let desc = match json_object_field(event, "desc") {
    Some(desc) => desc
    None =>
      return @mooncode.normalize_runtime_event_with_defaults(
        event,
        fallback_created_at=@async.now().to_string(),
      )
  }
  let event_id = json_field_text(
    event,
    "id",
    default=@desk.stable_id("mooncode-event", desc.stringify()),
  )
  @mooncode.moonclaw_event_record(event, fallback_id=event_id)
}

///|
test "mooncode native command body uses typed runtime protocol" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_root": "/tmp/demo-book",
  }
  let packet : Json = {
    "protocol": "mooncode.v1",
    "action": "run_tests",
    "context_path": "tools/demo/main.mbt",
  }
  let body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "Run tests",
    packet,
  )
  assert_eq(json_string(body, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(body, "command", default=""), "run_tests")
  assert_eq(json_string(body, "native_dispatch_mode", default=""), "queue-only")
  assert_eq(json_string(body, "session_id", default=""), "agent-demo")
  assert_eq(json_string(body, "book_root", default=""), "/tmp/demo-book")
  assert_eq(
    json_string(body, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(body, "packet"),
      "protocol",
      default="",
    ),
    "mooncode.v1",
  )
  let plan = json_object_field_or_empty(body, "execution_plan")
  assert_eq(
    json_string(plan, "kind", default=""),
    "mooncode-native-command-execution-plan",
  )
  assert_true(
    json_string_array_items(plan, "tool_sequence").contains("moon_check"),
  )
  assert_true(
    json_string_array_items(plan, "expected_events").contains("test_result"),
  )
  assert_true(
    json_string_array_items(plan, "required_outputs").contains(
      "test_result event",
    ),
  )
  assert_true(
    json_string_array_items(plan, "recommended_commands").contains("moon test"),
  )
  let tool_contract = json_object_field_or_empty(body, "tool_contract")
  assert_true(
    json_bool(
      tool_contract,
      "moon_check_required_for_code_changes",
      default=false,
    ),
  )
  let result_contract = json_object_field_or_empty(body, "result_contract")
  assert_true(
    json_string_array_items(result_contract, "required_events").contains(
      "test_result",
    ),
  )
  let checklist = json_array_items(result_contract, "execution_checklist")
  assert_true(checklist.length() > 0)
  assert_eq(json_string(checklist[0], "id", default=""), "claim-command")
  assert_true(
    mooncode_json_array_contains_id(checklist, "emit-event-test_result"),
  )
  assert_true(mooncode_json_array_contains_id(checklist, "ack-command"))
  let eval_packet : Json = {
    "protocol": "mooncode.v1",
    "action": "run_eval",
    "context_path": "tools/demo/main.mbt",
  }
  let eval_body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "Run eval",
    eval_packet,
  )
  let eval_plan = json_object_field_or_empty(eval_body, "execution_plan")
  assert_true(
    json_string_array_items(eval_plan, "tool_sequence").contains("moon_check"),
  )
  assert_true(
    json_string_array_items(eval_plan, "required_outputs").contains(
      "native eval report",
    ),
  )
  assert_true(
    json_string_array_items(eval_plan, "recommended_commands").contains(
      "run tool_harness eval fixtures",
    ),
  )
  let eval_result_contract = json_object_field_or_empty(
    eval_body, "result_contract",
  )
  assert_eq(
    json_string(eval_result_contract, "eval_report_sink", default=""),
    "POST /api/mooncode/sessions/<session-id>/eval-report",
  )
  assert_true(
    mooncode_json_array_contains_id(
      json_array_items(eval_result_contract, "execution_checklist"),
      "publish-native-eval-report",
    ),
  )
}

///|
test "mooncode native command body gives package and review actions executable contracts" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_root": "/tmp/demo-book",
  }
  let package_packet : Json = {
    "protocol": "mooncode.v1",
    "action": "package",
    "dispatch": "command",
    "approval": "operator",
    "context_path": "tools/demo/main.mbt",
    "workspace_root": "/tmp/demo-book",
  }
  let package_body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt", "package_kind": "miniapp" },
    "Package it",
    package_packet,
  )
  let package_plan = json_object_field_or_empty(package_body, "execution_plan")
  assert_eq(json_string(package_plan, "package_kind", default=""), "miniapp")
  assert_true(json_bool(package_plan, "review_required", default=false))
  assert_true(
    json_string_array_items(package_plan, "tool_sequence").contains(
      "package_app_tool",
    ),
  )
  assert_true(
    json_string_array_items(package_plan, "required_outputs").contains(
      "package manifest",
    ),
  )
  assert_true(
    json_string_array_items(package_plan, "expected_events").contains(
      "package.index",
    ),
  )
  let package_contract = json_object_field_or_empty(
    package_body, "result_contract",
  )
  assert_true(
    json_string(package_contract, "ack_sink", default="").contains(
      "/runtime-replay",
    ),
  )
  let commit_packet : Json = {
    "protocol": "mooncode.v1",
    "action": "commit",
    "dispatch": "command",
    "approval": "operator",
    "context_path": "tools/demo/main.mbt",
    "workspace_root": "/tmp/demo-book",
  }
  let commit_body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "Commit it",
    commit_packet,
  )
  let commit_plan = json_object_field_or_empty(commit_body, "execution_plan")
  assert_true(
    json_string_array_items(commit_plan, "expected_events").contains(
      "commit_created",
    ),
  )
  assert_true(
    json_string_array_items(commit_plan, "required_outputs").contains(
      "commit_created proof event",
    ),
  )
  let accept_packet : Json = {
    "protocol": "mooncode.v1",
    "action": "accept",
    "dispatch": "command",
    "approval": "operator",
    "context_path": "tools/demo/main.mbt",
  }
  let accept_body = @mooncode.native_command_body(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "Accept it",
    accept_packet,
  )
  let accept_plan = json_object_field_or_empty(accept_body, "execution_plan")
  assert_true(json_bool(accept_plan, "review_required", default=false))
  assert_true(
    json_string_array_items(accept_plan, "required_outputs").contains(
      "review receipt",
    ),
  )
  assert_false(
    json_string_array_items(accept_plan, "tool_sequence").contains("shell"),
  )
}

///|
test "mooncode runtime command stores compact execution summary" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "moonclaw_task_id": "task-demo",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "package_kind": "miniapp",
  }
  let message = @mooncode.command_message("package", payload)
  let packet = mooncode_command_packet(
    session, payload, "package", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let command = @mooncode.runtime_command_record(
    session, payload, message, packet,
  )
  let summary = json_object_field_or_empty(command, "execution_summary")
  assert_eq(
    json_string(summary, "kind", default=""),
    "mooncode-runtime-execution-summary",
  )
  assert_eq(json_string(summary, "action", default=""), "package")
  assert_eq(json_string(summary, "package_kind", default=""), "miniapp")
  assert_true(json_bool(summary, "review_required", default=false))
  assert_true(
    json_string_array_items(summary, "tool_sequence").contains(
      "package_app_tool",
    ),
  )
  assert_true(
    json_string_array_items(summary, "allowed_tools").contains(
      "package_app_tool",
    ),
  )
  assert_true(
    json_string_array_items(summary, "required_events").contains(
      "package.index",
    ),
  )
  assert_true(
    json_string_array_items(summary, "required_outputs").contains(
      "package manifest",
    ),
  )
  assert_true(
    json_string(summary, "ack_sink", default="").contains("/runtime-replay"),
  )
  assert_true(json_int(summary, "checklist_count", default=0) > 0)
  assert_true(
    mooncode_json_array_contains_id(
      json_array_items(summary, "execution_checklist"),
      "ack-command",
    ),
  )
  assert_true(
    json_string(summary, "path_rule", default="").contains("MoonBook"),
  )
}

///|
test "mooncode runtime dispatch pending count ignores bridged receipts" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "legacy-bridged",
    },
  ]
  assert_eq(mooncode_runtime_dispatch_pending_count(commands, receipts), 1)
  assert_eq(
    mooncode_runtime_pending_command_ids(commands, receipts).length(),
    1,
  )
}

///|
test "mooncode runtime replay skips delivered commands and emits pending jsonl" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "target": "tools/demo",
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "target": "tools/demo",
      "openseek_wire_command": { "command": "steer", "text": "add tests" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "native-dispatched",
    },
  ]
  let state = mooncode_runtime_replay_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_string(state, "kind", default=""), "mooncode-runtime-replay")
  assert_eq(json_int(state, "command_count", default=0), 2)
  assert_eq(json_int(state, "delivered_command_count", default=0), 1)
  assert_eq(json_int(state, "pending_command_count", default=0), 1)
  assert_eq(json_int(state, "first_pending_index", default=-1), 1)
  assert_true(json_bool(state, "replay_ready", default=false))
  assert_true(
    json_string(state, "pending_openseek_jsonl", default="").contains(
      "\"steer\"",
    ),
  )
  let pending = json_array_items(state, "pending_commands")
  assert_eq(pending.length(), 1)
  assert_eq(json_string(pending[0], "command_id", default=""), "cmd-2")
}

///|
test "mooncode runtime serve jsonl exports pending or all wire commands" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "action": "steer",
      "dispatch": "steer",
      "openseek_wire_command": { "command": "steer", "text": "add tests" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-bad",
      "action": "prompt",
      "dispatch": "prompt",
      "openseek_wire_command": { "command": "prompt" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "runtime-completed",
    },
  ]
  let pending = mooncode_runtime_serve_jsonl(
    commands,
    receipts,
    scope="pending",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_false(pending.contains("build it"))
  assert_true(pending.contains("add tests"))
  assert_false(pending.contains("cmd-bad"))
  assert_true(pending.has_suffix("\n"))
  let all = mooncode_runtime_serve_jsonl(commands, receipts, scope="all")
  assert_true(all.contains("build it"))
  assert_true(all.contains("add tests"))
  assert_false(all.contains("cmd-bad"))
}

///|
test "mooncode runtime replay acknowledgement marks commands delivered" {
  let session : Json = {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "target": "tools/demo",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
  ]
  let claims : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "dispatch_id": "claim-1",
      "claim_id": "claim-1",
      "command_id": "cmd-1",
      "status": "runtime-claimed",
      "consumer_id": "moonclaw-native",
    },
  ]
  let receipts = mooncode_runtime_replay_ack_receipts(
    session,
    commands,
    {
      "consumer_id": "moonclaw-native",
      "command_id": "cmd-1",
      "status": "runtime-completed",
      "detail": "turn finished",
    },
    dispatch_receipts=claims,
  )
  assert_eq(receipts.length(), 1)
  assert_eq(mooncode_runtime_dispatch_pending_count(commands, receipts), 0)
  assert_eq(
    mooncode_runtime_pending_command_ids(commands, receipts).length(),
    0,
  )
  assert_eq(
    json_string(receipts[0], "kind", default=""),
    "mooncode.runtime-dispatch",
  )
  assert_eq(json_string(receipts[0], "status", default=""), "runtime-completed")
  assert_eq(
    json_string(receipts[0], "ack_order_status", default=""),
    "matching-claim",
  )
  assert_eq(
    json_string(receipts[0], "previous_claim_id", default=""),
    "claim-1",
  )
  assert_eq(
    json_string(receipts[0], "dispatch_mode", default=""),
    "mooncode-runtime-replay",
  )
  let state = mooncode_runtime_replay_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_int(state, "delivered_command_count", default=0), 1)
  assert_eq(json_int(state, "pending_command_count", default=1), 0)
  assert_false(json_bool(state, "replay_ready", default=true))
}

///|
test "mooncode runtime replay acknowledgement ignores unknown commands" {
  let session : Json = { "id": "session-demo" }
  let receipts = mooncode_runtime_replay_ack_receipts(session, [], {
    "consumer_id": "moonclaw-native",
    "command_id": "missing-command",
    "status": "runtime-completed",
  })
  assert_eq(receipts.length(), 0)
}

///|
test "mooncode runtime execution plan endpoint projection exposes next command" {
  let session : Json = {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
    "workspace_root": "/tmp/book",
    "moonclaw_task_id": "task-demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "target": "tools/demo/main.mbt",
      "context_path": "tools/demo/main.mbt",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
      "execution_summary": {
        "required_events": [
          "tool_call", "tool_result", "test_result", "agent_finished",
        ],
        "required_outputs": ["test/build log"],
        "event_sink": "/api/mooncode/sessions/session-demo/runtime-events",
        "ack_sink": "/api/mooncode/sessions/session-demo/runtime-replay",
        "execution_checklist": [
          { "id": "claim-command", "blocking": true },
          { "id": "emit-event-test_result", "blocking": true },
        ],
      },
      "native_mooncode_body": {
        "protocol": "mooncode.v1",
        "command": "run_tests",
        "session_id": "session-demo",
      },
    },
  ]
  let plan = mooncode_runtime_execution_plan(
    "/tmp/book",
    session,
    "session-demo",
    commands,
    [],
    [],
    moonclaw_root="/tmp/moonclaw",
    native_ready=true,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    json_string(plan, "kind", default=""),
    "mooncode-runtime-consumer-execution-plan",
  )
  assert_eq(json_string(plan, "status", default=""), "ready-to-claim")
  assert_eq(json_string(plan, "command_id", default=""), "cmd-1")
  assert_true(json_bool(plan, "native_runtime_ready", default=false))
  assert_true(json_bool(plan, "ready_to_execute", default=false))
  assert_true(
    json_string(plan, "claim_endpoint", default="").contains("/runtime-claim"),
  )
  assert_true(
    json_string_array_items(plan, "required_events").contains("test_result"),
  )
  assert_eq(json_array_items(plan, "execution_checklist").length(), 2)
  let scheduler = json_object_field_or_empty(plan, "serve_scheduler")
  assert_eq(
    json_string(scheduler, "kind", default=""),
    "mooncode-serve-scheduler-state",
  )
  let packet = json_object_field_or_empty(plan, "runtime_turn_packet")
  assert_eq(
    json_string(packet, "kind", default=""),
    "mooncode-runtime-turn-packet",
  )
  assert_eq(json_string(packet, "command_id", default=""), "cmd-1")
  assert_eq(json_string(packet, "scheduler_effect", default=""), "start-turn")
  let supervisor = json_object_field_or_empty(plan, "runtime_supervisor")
  assert_eq(
    json_string(supervisor, "kind", default=""),
    "mooncode-runtime-supervisor-launch",
  )
  assert_eq(json_string(supervisor, "command_id", default=""), "cmd-1")
  assert_true(json_bool(supervisor, "ready_to_launch", default=false))
  let readiness = json_object_field_or_empty(supervisor, "readiness")
  assert_eq(
    json_string(readiness, "kind", default=""),
    "mooncode-runtime-supervisor-readiness",
  )
  assert_true(json_bool(readiness, "ok", default=false))
  assert_eq(json_int(readiness, "missing_requirement_count", default=-1), 0)
  assert_true(
    json_string(supervisor, "safety_boundary", default="").contains(
      "declarative",
    ),
  )
}

///|
test "mooncode serve scheduler projection exposes ordered control decisions" {
  let command_log : Array[Json] = [
    {
      "command_id": "cmd-active",
      "action": "prompt",
      "dispatch": "prompt",
      "message": "build a tool",
    },
    {
      "command_id": "cmd-steer",
      "action": "steer",
      "dispatch": "steer",
      "message": "focus the package output",
    },
  ]
  let lifecycle : Json = {
    "commands": [
      { "command_id": "cmd-active", "action": "prompt", "status": "running" },
      { "command_id": "cmd-steer", "action": "steer", "status": "pending" },
    ],
  }
  let scheduler = @mooncode.serve_scheduler_projection(
    "session-demo", command_log, lifecycle,
  )
  assert_eq(
    json_string(scheduler, "kind", default=""),
    "mooncode-serve-scheduler-state",
  )
  assert_eq(json_string(scheduler, "active_turn_id", default=""), "cmd-active")
  let decisions = json_array_items(scheduler, "decisions")
  assert_eq(decisions.length(), 2)
  assert_eq(json_string(decisions[0], "effect", default=""), "active-turn")
  assert_eq(json_string(decisions[1], "effect", default=""), "deliver-steer")
  assert_true(
    json_string(scheduler, "protocol", default="").contains("mooncode.v1"),
  )
}

///|
test "mooncode runtime claim marks pending command without completing it" {
  let session : Json = {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
  }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "session_id": "session-demo",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "steer", "text": "add tests" },
    },
  ]
  let receipts = mooncode_runtime_claim_receipts(session, commands, [], {
    "consumer_id": "moonclaw-runtime",
    "max_count": 1,
    "claimed_at": "2026-06-15T00:00:00Z",
  })
  assert_eq(receipts.length(), 1)
  assert_eq(json_string(receipts[0], "status", default=""), "runtime-claimed")
  assert_eq(
    json_string(receipts[0], "legacy_bridge_endpoint", default="missing"),
    "",
  )
  assert_eq(
    json_string(receipts[0], "dispatch_mode", default=""),
    "mooncode-runtime-claim",
  )
  assert_eq(json_string(receipts[0], "command_id", default=""), "cmd-1")
  assert_eq(mooncode_runtime_dispatch_pending_count(commands, receipts), 1)
  let state = mooncode_runtime_replay_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_int(state, "claimed_command_count", default=0), 1)
  assert_eq(json_int(state, "delivered_command_count", default=0), 0)
  assert_eq(json_int(state, "pending_command_count", default=0), 0)
  let items = json_array_items(state, "replay_items")
  assert_eq(json_string(items[0], "replay_status", default=""), "claimed")
  assert_eq(
    json_string(items[1], "replay_status", default=""),
    "blocked-by-prior-command",
  )
  assert_eq(json_string(items[1], "blocked_by_command_id", default=""), "cmd-1")
  let claim_state = mooncode_runtime_claim_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
  )
  assert_eq(
    json_string(claim_state, "kind", default=""),
    "mooncode-runtime-claim-state",
  )
  assert_eq(json_int(claim_state, "claimed_command_count", default=0), 1)
  assert_eq(json_int(claim_state, "claimable_command_count", default=0), 0)
  assert_eq(json_int(claim_state, "order_blocked_command_count", default=0), 1)
  let claimed_items = json_array_items(claim_state, "claimed_commands")
  assert_eq(claimed_items.length(), 1)
  assert_eq(json_string(claimed_items[0], "command_id", default=""), "cmd-1")
  let order_blocked = json_array_items(claim_state, "order_blocked_commands")
  assert_eq(json_string(order_blocked[0], "command_id", default=""), "cmd-2")
  assert_eq(
    json_string(order_blocked[0], "blocked_by_command_id", default=""),
    "cmd-1",
  )
  let response_receipts = @mooncode.runtime_dispatch_receipts_for_response(
    receipts,
  )
  assert_eq(
    json_string(
      response_receipts[0],
      "legacy_bridge_endpoint",
      default="missing",
    ),
    "",
  )
}

///|
test "mooncode runtime claim exposes tool authorization blocked commands" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tool",
      "session_id": "session-demo",
      "action": "run_tests",
      "dispatch": "command",
      "serve_command": "prompt",
      "openseek_wire_valid": true,
      "openseek_wire_command": { "command": "prompt", "text": "run tests" },
      "tool_authorization": {
        "kind": "mooncode-tool-authorization-snapshot",
        "protocol": "mooncode.v1",
        "enforcement_state": "requires-approval",
        "runtime_may_execute": false,
        "pending_approval_count": 1,
      },
    },
  ]
  let claim_state = mooncode_runtime_claim_state(
    "session-demo",
    commands,
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
  )
  assert_eq(json_int(claim_state, "claimable_command_count", default=0), 0)
  assert_eq(
    json_int(claim_state, "tool_authorization_blocked_command_count", default=0),
    1,
  )
  let blocked = json_array_items(
    claim_state, "tool_authorization_blocked_commands",
  )
  assert_eq(json_string(blocked[0], "command_id", default=""), "cmd-tool")
  let receipts = mooncode_runtime_claim_receipts(session, commands, [], {
    "consumer_id": "moonclaw-runtime",
    "max_count": 1,
  })
  assert_eq(receipts.length(), 0)
}

///|
test "mooncode runtime claim preserves ordering behind claimed commands" {
  let session : Json = { "id": "session-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "session_id": "session-demo",
      "openseek_wire_command": { "command": "prompt", "text": "one" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "session_id": "session-demo",
      "openseek_wire_command": { "command": "prompt", "text": "two" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-3",
      "session_id": "session-demo",
      "openseek_wire_command": { "command": "prompt", "text": "three" },
    },
  ]
  let existing : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "runtime-claimed",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-2",
      "status": "runtime-completed",
    },
  ]
  let claimed = mooncode_runtime_claim_receipts(session, commands, existing, {
    "consumer_id": "moonclaw-runtime",
    "max_count": 10,
  })
  assert_eq(claimed.length(), 0)
  let forced = mooncode_runtime_claim_receipts(session, commands, existing, {
    "consumer_id": "moonclaw-runtime",
    "max_count": 10,
    "force": true,
  })
  assert_eq(forced.length(), 2)
  assert_eq(json_string(forced[0], "command_id", default=""), "cmd-1")
  assert_eq(json_string(forced[1], "command_id", default=""), "cmd-3")
}

///|
test "mooncode runtime claim recovers expired leases" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-stale",
      "session_id": "session-demo",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "recover me" },
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-fresh",
      "session_id": "session-demo",
      "action": "steer",
      "dispatch": "steer",
      "serve_command": "steer",
      "openseek_wire_command": { "command": "steer", "text": "next" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-stale",
      "status": "runtime-claimed",
      "claim_id": "claim-old",
      "consumer_id": "dead-runtime",
      "claimed_at": "2000-01-01T00:00:00Z",
      "lease_expires_at": "2000-01-01T00:05:00Z",
    },
  ]
  let state = mooncode_runtime_claim_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(json_int(state, "claimable_command_count", default=0), 2)
  assert_eq(json_int(state, "claimed_command_count", default=0), 0)
  assert_eq(json_int(state, "expired_claim_command_count", default=0), 1)
  let expired = json_array_items(state, "expired_claim_commands")
  assert_eq(json_string(expired[0], "command_id", default=""), "cmd-stale")
  assert_true(json_bool(expired[0], "previous_claim_expired", default=false))
  let replay = mooncode_runtime_replay_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
    lease_now="2000-01-01T00:06:00Z",
  )
  let replay_items = json_array_items(replay, "replay_items")
  assert_eq(
    json_string(replay_items[0], "replay_status", default=""),
    "expired-claim-pending-retry",
  )
  assert_eq(json_int(replay, "pending_command_count", default=0), 2)
  let claimed = mooncode_runtime_claim_receipts(session, commands, receipts, {
    "consumer_id": "moonclaw-runtime",
    "max_count": 1,
    "now": "2000-01-01T00:06:00Z",
    "claimed_at": "2000-01-01T00:06:30Z",
    "lease_expires_at": "2000-01-01T00:11:30Z",
  })
  assert_eq(claimed.length(), 1)
  assert_eq(json_string(claimed[0], "command_id", default=""), "cmd-stale")
  assert_true(json_bool(claimed[0], "recovered_expired_claim", default=false))
  assert_eq(
    json_string(claimed[0], "previous_claim_id", default=""),
    "claim-old",
  )
  let active = mooncode_runtime_claim_receipts(session, commands, receipts, {
    "consumer_id": "moonclaw-runtime",
    "max_count": 1,
    "now": "1999-12-31T23:59:00Z",
  })
  assert_eq(active.length(), 0)
  let runtime_state = @mooncode.action_plan_runtime_state_at(
    "cmd-stale",
    commands,
    receipts,
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(runtime_state, "expired-claim")
  assert_eq(
    @mooncode.action_plan_item_state("prompt", runtime_state, {}),
    "runtime-retry",
  )
}

///|
test "mooncode action plan treats claimed runtime commands as running" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
      "approval": "none",
    },
  ]
  let runtime_commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "action": "prompt",
      "dispatch": "prompt",
      "openseek_wire_command": { "command": "prompt", "text": "build it" },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-1",
      "status": "runtime-claimed",
    },
  ]
  let items = mooncode_action_plan_items(
    Json::object({}),
    commands,
    runtime_commands,
    receipts,
    [],
  )
  assert_eq(items.length(), 1)
  assert_eq(json_string(items[0], "runtime_state", default=""), "claimed")
  assert_eq(json_string(items[0], "state", default=""), "running")
  assert_eq(@mooncode.action_plan_status(0, 1, 0, 0, 0, 1), "running")
}

///|
test "mooncode runtime replay blocks invalid openseek wire rows" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-invalid",
      "action": "prompt",
      "dispatch": "prompt",
      "serve_command": "prompt",
      "openseek_wire_command": { "command": "prompt" },
    },
  ]
  let state = mooncode_runtime_replay_state(
    "session-demo",
    commands,
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    task_id="task-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_dispatch_log_path="/tmp/runtime-dispatches.jsonl",
  )
  assert_eq(json_int(state, "invalid_command_count", default=0), 1)
  assert_eq(
    json_string(state, "first_invalid_command_id", default=""),
    "cmd-invalid",
  )
  assert_false(json_bool(state, "replay_ready", default=true))
  let items = json_array_items(state, "replay_items")
  assert_eq(
    json_string(items[0], "replay_status", default=""),
    "blocked-invalid",
  )
}

///|
test "mooncode action plan classifies review and test gates" {
  let commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.command",
      "command_id": "cmd-test",
      "action": "run_tests",
      "dispatch": "command",
      "approval": "auto",
      "target": "tools/demo",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.command",
      "command_id": "cmd-accept",
      "action": "accept",
      "dispatch": "command",
      "approval": "operator",
      "target": "tools/demo",
    },
  ]
  let runtime_commands : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-test",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-accept",
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-test",
      "status": "native-dispatched",
    },
    {
      "protocol": "mooncode.v1",
      "kind": "mooncode.runtime-dispatch",
      "command_id": "cmd-accept",
      "status": "native-dispatched",
    },
  ]
  let events = [
    @mooncode.event_record(
      id="diff",
      lane="diff",
      kind="file.write",
      title="File changed",
      status="done",
      created_at="1",
      detail="changed",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
    ),
  ]
  let actions = mooncode_action_plan_items(
    Json::object({}),
    commands,
    runtime_commands,
    receipts,
    events,
  )
  assert_eq(actions.length(), 2)
  assert_eq(json_string(actions[0], "state", default=""), "awaiting-proof")
  assert_eq(json_string(actions[1], "state", default=""), "blocked")
  assert_true(json_string(actions[1], "blocking_reason", default="") != "")
}

///|
test "mooncode action plan includes blocked command preflight attempts" {
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": "mooncode.v1",
    "action": "accept",
    "blocked": true,
    "reason": "run tests/builds before accept for pending file changes",
  }
  let blocked = mooncode_command_preflight_blocked_event(
    preflight,
    { "context_path": "tools/demo/main.mbt" },
    "accept",
    "2026-06-14T00:02:00Z",
  )
  let actions = mooncode_action_plan_items(Json::object({}), [], [], [], [
    blocked,
  ])
  assert_eq(actions.length(), 1)
  assert_eq(json_string(actions[0], "dispatch", default=""), "preflight")
  assert_eq(json_string(actions[0], "state", default=""), "blocked")
  assert_eq(
    json_string(actions[0], "runtime_state", default=""),
    "blocked-before-dispatch",
  )
  assert_true(
    json_string(actions[0], "blocking_reason", default="").contains(
      "run tests/builds",
    ),
  )
}

///|
async test "mooncode action plan writes durable moonbook manifest" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-action-plan-wbtest-" +
    @desk.stable_id("mooncode-action-plan-test", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
  }
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  let message = @mooncode.command_message("run_tests", payload)
  let packet = mooncode_command_packet(
    session, payload, "run_tests", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let runtime_command = @mooncode.runtime_command_record(
    session, payload, message, packet,
  )
  append_mooncode_command_log(root, "agent-demo", packet)
  append_mooncode_runtime_command_log(root, "agent-demo", runtime_command)
  append_mooncode_runtime_dispatch_log(root, "agent-demo", {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-dispatch",
    "command_id": json_string(packet, "command_id", default=""),
    "session_id": "agent-demo",
    "status": "legacy-bridged",
  })
  let manifest = write_mooncode_action_plan_manifest(root, session)
  assert_eq(json_string(manifest, "kind", default=""), "mooncode-action-plan")
  assert_eq(json_int(manifest, "action_count", default=0), 1)
  assert_eq(
    json_string(manifest, "next_required_action", default=""),
    "await_runtime_proof",
  )
  let relative = json_string(manifest, "manifest_path", default="")
  assert_eq(relative, "wiki/reviews/mooncode/agent-demo/action-plan.json")
  assert_true(@fs.exists(@pathx.join(root, relative)))
  let actions = json_array_items(manifest, "actions")
  assert_eq(json_string(actions[0], "runtime_state", default=""), "delivered")
}

///|
test "mooncode native response appends runtime events" {
  let event = @mooncode.event_record(
    id="native-event",
    lane="runtime",
    kind="runtime_update",
    title="Runtime update",
    status="running",
    created_at="1",
    detail="native",
  )
  let turn_event = @mooncode.event_record(
    id="runtime-turn-event",
    lane="tool",
    kind="tool_result",
    title="Tool result",
    status="done",
    created_at="2",
    detail="turn",
  )
  let package_event = @mooncode.event_record(
    id="runtime-package-event",
    lane="artifact",
    kind="runtime.package_verified",
    title="Package verified",
    status="verified",
    created_at="3",
    detail="package",
  )
  let session = mooncode_append_native_response_events(Json::object({}), {
    "events": [event],
    "execution": { "events": [turn_event] },
    "turn_receipt": { "events": [turn_event] },
    "package_events": [package_event],
    "turns": [{ "package_events": [package_event] }],
  })
  let events = json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 3)
  assert_eq(json_string(events[0], "id", default=""), "native-event")
  assert_eq(json_string(events[1], "id", default=""), "runtime-turn-event")
  assert_eq(json_string(events[2], "id", default=""), "runtime-package-event")
}

///|
test "mooncode native runtime loop response records loop status event" {
  let session = mooncode_append_native_response_events(Json::object({}), {
    "kind": "mooncode-runtime-loop",
    "protocol": "mooncode.v1",
    "session_id": "agent-demo",
    "book_root": "/tmp/demo-book",
    "consumer_id": "moondesk-native-runtime-loop",
    "ran_turn_count": 0,
    "failed_turn_count": 0,
    "stopped_by": "idle",
    "message": "MoonClaw native runtime loop found no claimable MoonCode commands.",
  })
  let events = json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "lane", default=""), "runtime")
  assert_eq(json_string(events[0], "kind", default=""), "runtime_loop")
  assert_eq(json_string(events[0], "status", default=""), "done")
  assert_eq(json_string(events[0], "command", default=""), "runtime-loop")
  assert_eq(json_string(events[0], "path", default=""), "/tmp/demo-book")
  assert_true(
    json_string(events[0], "detail", default="").contains("no claimable"),
  )
}

///|
test "mooncode command events keep typed command packet" {
  let base : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "moonclaw_task_id": "task-demo",
  }
  let payload : Json = { "context_path": "apps/demo/app.mbt" }
  let message = @mooncode.command_message("package", payload)
  let packet = mooncode_command_packet(
    base, payload, "package", message, "2026-06-14T00:00:00Z", "apps/demo/app.mbt",
  )
  let session = append_mooncode_command_event(
    base,
    action="package",
    status="queued",
    detail=message,
    created_at="2026-06-14T00:00:00Z",
    path="apps/demo/app.mbt",
    command_packet=packet,
  )
  let events = project_mooncode_events(session, [], [])
  assert_eq(events.length(), 1)
  let event_packet = json_object_field_or_empty(events[0], "command_packet")
  assert_eq(json_string(event_packet, "action", default=""), "package")
  assert_eq(json_string(event_packet, "approval", default=""), "operator")
  assert_true(
    json_string_array_items(event_packet, "tool_hints").contains(
      "package_app_tool",
    ),
  )
  let summary = @mooncode.session_summary(session, events)
  assert_eq(json_int(summary, "command_packet_count", default=0), 1)
  assert_true(
    json_string(summary, "last_command_packet", default="") == "" ||
    summary.stringify().contains("typed_command_packets"),
  )
}

///|
async test "mooncode review actions write moonbook receipts" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-review-receipt-wbtest-" +
    @desk.stable_id("mooncode-review-test", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "moonclaw_task_id": "task-demo",
    "mooncode_dispatch_mode": "moonclaw-mooncode-runtime",
  }
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  @fsx.make_directory(
    @pathx.join(root, "tools/demo"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(root, "tools/demo/main.mbt"),
    "fn main { println(\"mooncode\") }\n",
  )
  let message = @mooncode.command_message("accept", payload)
  let packet = mooncode_command_packet(
    session, payload, "accept", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let receipt = write_mooncode_review_receipt(
    session, "accept", packet, "tools/demo/main.mbt", message, "2026-06-14T00:00:00Z",
  )
  assert_eq(json_string(receipt, "kind", default=""), "mooncode-review-receipt")
  assert_eq(json_string(receipt, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(receipt, "action", default=""), "accept")
  assert_eq(
    json_string(receipt, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  let relative = json_string(receipt, "receipt_path", default="")
  assert_true(relative.has_prefix("wiki/reviews/mooncode/agent-demo/accept-"))
  let absolute = @pathx.join(root, relative)
  assert_true(@fs.exists(absolute))
  let saved = @json.parse(@fs.read_file(absolute).text()) catch {
    _ => Json::object({})
  }
  assert_eq(json_string(saved, "action", default=""), "accept")
  assert_eq(
    json_string(
      json_object_field_or_empty(saved, "command_packet"),
      "protocol",
      default="",
    ),
    "mooncode.v1",
  )

  let recorded = write_mooncode_review_receipt_if_needed(
    session,
    "package",
    mooncode_command_packet(
      session,
      payload,
      "package",
      @mooncode.command_message("package", payload),
      "2026-06-14T00:01:00Z",
      "tools/demo/main.mbt",
    ),
    "tools/demo/main.mbt",
    "Package it.",
    "2026-06-14T00:01:00Z",
  )
  match recorded {
    Some(next) => {
      let events = json_array_items(next, "mooncode_command_events")
      assert_eq(events.length(), 3)
      assert_eq(json_string(events[0], "kind", default=""), "receipt.package")
      assert_eq(json_string(events[0], "command", default=""), "")
      assert_eq(json_string(events[1], "kind", default=""), "package.manifest")
      assert_eq(json_string(events[1], "lane", default=""), "artifact")
      assert_eq(json_string(events[2], "kind", default=""), "package.index")
      assert_eq(json_string(events[2], "lane", default=""), "artifact")
      let manifest = json_object_field_or_empty(
        next, "mooncode_last_package_manifest",
      )
      assert_eq(
        json_string(manifest, "kind", default=""),
        "mooncode-package-manifest",
      )
      assert_eq(json_string(manifest, "package_kind", default=""), "tool")
      let manifest_relative = json_string(manifest, "manifest_path", default="")
      assert_true(
        manifest_relative.has_prefix(
          "portable/app-tool/mooncode/agent-demo/package-",
        ),
      )
      assert_true(@fs.exists(@pathx.join(root, manifest_relative)))
      let saved_manifest = @json.parse(
        @fs.read_file(@pathx.join(root, manifest_relative)).text(),
      ) catch {
        _ => Json::object({})
      }
      assert_eq(
        json_string(saved_manifest, "review_receipt_path", default=""),
        json_string(
          json_object_field_or_empty(next, "mooncode_last_review_receipt"),
          "receipt_path",
          default="",
        ),
      )
      assert_eq(
        json_string(saved_manifest, "source_inventory_status", default=""),
        "source-bound",
      )
      assert_eq(json_int(saved_manifest, "source_present_count", default=0), 1)
      assert_eq(
        json_string(saved_manifest, "source_promotion_status", default=""),
        "promoted",
      )
      assert_eq(json_int(saved_manifest, "promoted_source_count", default=0), 1)
      let inventory = json_array_items(saved_manifest, "source_inventory")
      assert_eq(inventory.length(), 1)
      assert_eq(
        json_string(inventory[0], "path", default=""),
        "tools/demo/main.mbt",
      )
      assert_eq(json_string(inventory[0], "kind", default=""), "file")
      assert_true(json_bool(inventory[0], "package_ready", default=false))
      assert_eq(
        json_int(inventory[0], "size_bytes", default=0),
        "fn main { println(\"mooncode\") }\n".length(),
      )
      assert_true(json_string(inventory[0], "sha256", default="").length() > 20)
      assert_true(json_bool(inventory[0], "promoted", default=false))
      let promoted_path = json_string(inventory[0], "promoted_path", default="")
      assert_true(
        promoted_path.has_prefix(
          "portable/app-tool/mooncode/agent-demo/sources/",
        ),
      )
      assert_true(promoted_path.has_suffix("/tools/demo/main.mbt"))
      assert_true(@fs.exists(@pathx.join(root, promoted_path)))
      assert_eq(
        @fs.read_file(@pathx.join(root, promoted_path)).text(),
        "fn main { println(\"mooncode\") }\n",
      )
      let index_manifest = json_object_field_or_empty(
        next, "mooncode_last_package_index_manifest",
      )
      assert_eq(
        json_string(index_manifest, "kind", default=""),
        "mooncode-package-index",
      )
      assert_eq(
        json_string(index_manifest, "status", default=""),
        "source-bound",
      )
      assert_eq(
        json_string(index_manifest, "manifest_path", default=""),
        "portable/app-tool/mooncode/agent-demo/index.json",
      )
      assert_true(
        @fs.exists(
          @pathx.join(
            root,
            json_string(index_manifest, "manifest_path", default=""),
          ),
        ),
      )
      assert_eq(json_int(index_manifest, "package_count", default=0), 1)
      assert_eq(
        json_int(index_manifest, "source_bound_package_count", default=0),
        1,
      )
      assert_eq(
        json_int(index_manifest, "executable_ready_count", default=0),
        1,
      )
      assert_eq(json_string_array_items(index_manifest, "entry_points"), [
        "tools/demo/main.mbt",
      ])
      let candidates = mooncode_package_candidates_projection(
        next, "agent-demo",
      )
      assert_eq(
        json_string(candidates, "kind", default=""),
        "mooncode-package-candidates",
      )
      assert_eq(json_int(candidates, "package_count", default=0), 1)
      assert_eq(
        json_int(candidates, "source_bound_package_count", default=0),
        1,
      )
      assert_eq(
        json_int(candidates, "missing_source_package_count", default=1),
        0,
      )
      assert_eq(
        json_string(candidates, "package_index_status", default=""),
        "source-bound",
      )
      assert_eq(
        json_string(candidates, "package_index_path", default=""),
        "portable/app-tool/mooncode/agent-demo/index.json",
      )
      assert_eq(
        json_int(candidates, "package_index_executable_ready_count", default=0),
        1,
      )
      assert_eq(json_array_items(candidates, "packages").length(), 1)
      assert_eq(
        json_int(
          @mooncode.session_summary(next, events),
          "moonbook_review_receipt_count",
          default=0,
        ),
        1,
      )
      assert_eq(
        json_int(
          @mooncode.session_summary(next, events),
          "moonbook_package_manifest_count",
          default=0,
        ),
        1,
      )
      assert_eq(
        json_int(
          @mooncode.session_summary(next, events),
          "moonbook_package_index_manifest_count",
          default=0,
        ),
        1,
      )
      let with_change_set = write_mooncode_change_set_if_possible(next)
      let change_set = json_object_field_or_empty(
        with_change_set, "mooncode_last_change_set_manifest",
      )
      assert_eq(
        json_string(change_set, "kind", default=""),
        "mooncode-change-set",
      )
      assert_eq(json_int(change_set, "artifact_count", default=0), 2)
      assert_eq(json_int(change_set, "review_count", default=0), 1)
      let change_set_relative = json_string(
        change_set,
        "manifest_path",
        default="",
      )
      assert_eq(
        change_set_relative, "wiki/reviews/mooncode/agent-demo/change-set.json",
      )
      assert_true(@fs.exists(@pathx.join(root, change_set_relative)))
      match mooncode_read_change_set_manifest(with_change_set) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            change_set_relative,
          )
        None => fail("change-set manifest should be readable from session")
      }
      let saved_change_set = @json.parse(
        @fs.read_file(@pathx.join(root, change_set_relative)).text(),
      ) catch {
        _ => Json::object({})
      }
      assert_eq(
        json_string(saved_change_set, "protocol", default=""),
        "mooncode.v1",
      )
      assert_eq(
        json_int(
          @mooncode.session_summary(
            with_change_set,
            json_array_items(with_change_set, "mooncode_command_events"),
          ),
          "moonbook_change_set_manifest_count",
          default=0,
        ),
        1,
      )
      let with_patch_set = write_mooncode_patch_set_if_possible(with_change_set)
      let patch_set = json_object_field_or_empty(
        with_patch_set, "mooncode_last_patch_set_manifest",
      )
      assert_eq(
        json_string(patch_set, "kind", default=""),
        "mooncode-patch-set",
      )
      let patch_set_relative = json_string(
        patch_set,
        "manifest_path",
        default="",
      )
      assert_eq(
        patch_set_relative, "wiki/reviews/mooncode/agent-demo/patch-set.json",
      )
      assert_true(@fs.exists(@pathx.join(root, patch_set_relative)))
      match mooncode_read_patch_set_manifest(with_patch_set) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            patch_set_relative,
          )
        None => fail("patch-set manifest should be readable from session")
      }
      assert_eq(json_string(patch_set, "status", default=""), "empty")
      assert_eq(json_int(patch_set, "patch_count", default=-1), 0)
      assert_eq(
        json_int(
          @mooncode.session_summary(
            with_patch_set,
            json_array_items(with_patch_set, "mooncode_command_events"),
          ),
          "moonbook_patch_set_manifest_count",
          default=0,
        ),
        1,
      )
      let with_tool_approvals = write_mooncode_tool_approvals_if_possible(
        append_mooncode_command_event(
          with_patch_set,
          action="approve_tool",
          status="queued",
          detail="Approve shell",
          created_at="2026-06-14T00:02:00Z",
          path="moon test",
          command_packet=mooncode_command_packet(
            with_patch_set,
            { "context_path": "moon test" },
            "approve_tool",
            "Approve shell",
            "2026-06-14T00:02:00Z",
            "moon test",
          ),
        ),
      )
      let tool_approvals = json_object_field_or_empty(
        with_tool_approvals, "mooncode_last_tool_approvals_manifest",
      )
      assert_eq(
        json_string(tool_approvals, "kind", default=""),
        "mooncode-tool-approvals",
      )
      let tool_approvals_relative = json_string(
        tool_approvals,
        "manifest_path",
        default="",
      )
      assert_eq(
        tool_approvals_relative, "wiki/reviews/mooncode/agent-demo/tool-approvals.json",
      )
      assert_true(@fs.exists(@pathx.join(root, tool_approvals_relative)))
      match mooncode_read_tool_approvals_manifest(with_tool_approvals) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            tool_approvals_relative,
          )
        None => fail("tool-approval manifest should be readable from session")
      }
      let with_test_event = append_mooncode_command_event(
        with_tool_approvals,
        action="run_tests",
        status="passed",
        detail="moon test passed",
        created_at="2026-06-14T00:03:00Z",
        path="tools/demo/main.mbt",
        command_packet=mooncode_command_packet(
          with_tool_approvals,
          { "context_path": "tools/demo/main.mbt" },
          "run_tests",
          "moon test",
          "2026-06-14T00:03:00Z",
          "tools/demo/main.mbt",
        ),
      )
      let with_test_runs = write_mooncode_test_runs_if_possible(with_test_event)
      let test_runs = json_object_field_or_empty(
        with_test_runs, "mooncode_last_test_runs_manifest",
      )
      assert_eq(
        json_string(test_runs, "kind", default=""),
        "mooncode-test-runs",
      )
      let test_runs_relative = json_string(
        test_runs,
        "manifest_path",
        default="",
      )
      assert_eq(
        test_runs_relative, "wiki/reviews/mooncode/agent-demo/test-runs.json",
      )
      assert_true(@fs.exists(@pathx.join(root, test_runs_relative)))
      assert_eq(json_int(test_runs, "run_count", default=0), 1)
      assert_eq(json_int(test_runs, "passed_run_count", default=0), 1)
      assert_eq(json_int(test_runs, "failed_run_count", default=-1), 0)
      match mooncode_read_test_runs_manifest(with_test_runs) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            test_runs_relative,
          )
        None => fail("test-run manifest should be readable from session")
      }
      let with_eval_report = write_mooncode_eval_report_if_possible(
        with_test_runs,
      )
      let eval_report = json_object_field_or_empty(
        with_eval_report, "mooncode_last_eval_report_manifest",
      )
      assert_eq(
        json_string(eval_report, "kind", default=""),
        "mooncode-eval-report",
      )
      let eval_report_relative = json_string(
        eval_report,
        "manifest_path",
        default="",
      )
      assert_eq(
        eval_report_relative, "wiki/reviews/mooncode/agent-demo/eval-report.json",
      )
      assert_true(@fs.exists(@pathx.join(root, eval_report_relative)))
      assert_eq(json_int(eval_report, "bridge_score", default=0), 64)
      assert_eq(json_int(eval_report, "check_count", default=0), 28)
      assert_eq(json_int(eval_report, "missing_check_count", default=0), 10)
      match mooncode_read_eval_report_manifest(with_eval_report) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            eval_report_relative,
          )
        None => fail("eval-report manifest should be readable from session")
      }
      let package_payload : Json = { "context_path": "tools/demo/main.mbt" }
      let package_packet = mooncode_command_packet(
        with_eval_report, package_payload, "package", "Package it.", "2026-06-14T00:04:00Z",
        "tools/demo/main.mbt",
      )
      append_mooncode_command_log(root, "agent-demo", package_packet)
      append_mooncode_runtime_command_log(
        root,
        "agent-demo",
        @mooncode.runtime_command_record(
          with_eval_report, package_payload, "Package it.", package_packet,
        ),
      )
      append_mooncode_runtime_dispatch_log(root, "agent-demo", {
        "protocol": "mooncode.v1",
        "kind": "mooncode.runtime-dispatch",
        "dispatch_id": "legacy-claim-package",
        "command_id": json_string(package_packet, "command_id", default=""),
        "session_id": "agent-demo",
        "status": "runtime-claimed",
        "dispatch_mode": "mooncode-runtime-claim",
        "created_at": "2026-06-14T00:04:30Z",
        "openseek_wire_valid": true,
      })
      let with_session_snapshot = write_mooncode_session_snapshot_if_possible(
        root, with_eval_report,
      )
      let session_snapshot = json_object_field_or_empty(
        with_session_snapshot, "mooncode_session_snapshot",
      )
      assert_eq(
        json_string(session_snapshot, "kind", default=""),
        "mooncode-session-snapshot",
      )
      assert_true(
        @fs.exists(json_string(session_snapshot, "snapshot_path", default="")),
      )
      assert_eq(
        json_int(session_snapshot, "runtime_command_count", default=0),
        1,
      )
      let snapshot_dispatches = json_array_items(
        session_snapshot, "runtime_dispatches",
      )
      assert_eq(snapshot_dispatches.length(), 1)
      assert_eq(
        json_string(
          snapshot_dispatches[0],
          "legacy_bridge_endpoint",
          default="missing",
        ),
        "",
      )
      assert_true(
        json_object_field(snapshot_dispatches[0], "runtime_command") is Some(_),
      )
      assert_true(json_object_field(snapshot_dispatches[0], "owner") is Some(_))
      let with_runtime_handoff = write_mooncode_runtime_handoff_if_possible(
        root, with_session_snapshot,
      )
      let runtime_handoff = json_object_field_or_empty(
        with_runtime_handoff, "mooncode_last_runtime_handoff_manifest",
      )
      assert_eq(
        json_string(runtime_handoff, "kind", default=""),
        "mooncode-runtime-handoff",
      )
      assert_eq(
        json_string(runtime_handoff, "status", default=""),
        "bridge-resumable",
      )
      let handoff_relative = json_string(
        runtime_handoff,
        "manifest_path",
        default="",
      )
      assert_eq(
        handoff_relative, "wiki/reviews/mooncode/agent-demo/runtime-handoff.json",
      )
      assert_true(@fs.exists(@pathx.join(root, handoff_relative)))
      assert_eq(json_int(runtime_handoff, "command_count", default=0), 1)
      assert_eq(
        json_int(runtime_handoff, "runtime_command_count", default=0),
        1,
      )
      let handoff_dispatches = json_array_items(
        runtime_handoff, "runtime_dispatches",
      )
      assert_eq(handoff_dispatches.length(), 1)
      assert_eq(
        json_string(
          handoff_dispatches[0],
          "legacy_bridge_endpoint",
          default="missing",
        ),
        "",
      )
      assert_true(
        json_object_field(handoff_dispatches[0], "runtime_command") is Some(_),
      )
      let runtime_consumer = json_object_field_or_empty(
        runtime_handoff, "runtime_consumer",
      )
      assert_eq(
        json_string(runtime_consumer, "kind", default=""),
        "mooncode-runtime-consumer-handoff",
      )
      assert_eq(
        json_string(runtime_consumer, "status", default=""),
        "lease-held",
      )
      assert_false(json_bool(runtime_consumer, "ready_to_claim", default=true))
      assert_true(@mooncode.runtime_handoff_manifest_current(runtime_handoff))
      let legacy_runtime_handoff : Json = {
        "kind": "mooncode-runtime-handoff",
        "resume_contract": {
          "runtime_command_feed_endpoint": "/api/mooncode/sessions/agent-demo/runtime-commands",
          "runtime_command_log_path": "runtime-commands.jsonl",
          "runtime_claim_endpoint": "/api/mooncode/sessions/agent-demo/runtime-claim",
          "runtime_dispatch_endpoint": "/api/mooncode/sessions/agent-demo/runtime-dispatch",
          "runtime_dispatch_log_path": "runtime-dispatches.jsonl",
          "runtime_event_ingest_endpoint": "/api/mooncode/sessions/agent-demo/runtime-events",
          "runtime_replay_endpoint": "/api/mooncode/sessions/agent-demo/runtime-replay",
          "action_plan_endpoint": "/api/mooncode/sessions/agent-demo/action-plan",
        },
      }
      assert_false(
        @mooncode.runtime_handoff_manifest_current(legacy_runtime_handoff),
      )
      let runtime_claim = json_object_field_or_empty(
        runtime_handoff, "runtime_claim",
      )
      assert_eq(json_int(runtime_claim, "claimed_command_count", default=0), 1)
      let resume_contract = json_object_field_or_empty(
        runtime_handoff, "resume_contract",
      )
      assert_true(
        json_string(resume_contract, "stream_endpoint", default="").contains(
          "since=<sequence>",
        ),
      )
      assert_eq(
        json_string(resume_contract, "session_snapshot_path", default=""),
        json_string(session_snapshot, "snapshot_path", default=""),
      )
      assert_eq(
        json_string(resume_contract, "session_store_endpoint", default=""),
        "/api/mooncode/sessions/agent-demo/session-store",
      )
      assert_true(
        json_string(resume_contract, "runtime_command_log_path", default="").contains(
          "runtime-commands.jsonl",
        ),
      )
      assert_eq(
        json_string(
          resume_contract,
          "runtime_command_feed_endpoint",
          default="",
        ),
        "/api/mooncode/sessions/agent-demo/runtime-commands",
      )
      let engine = json_object_field_or_empty(runtime_handoff, "engine")
      assert_false(json_bool(engine, "native_runtime_ready", default=true))
      match mooncode_read_runtime_handoff_manifest(with_runtime_handoff) {
        Some(read_back) =>
          assert_eq(
            json_string(read_back, "manifest_path", default=""),
            handoff_relative,
          )
        None => fail("runtime-handoff manifest should be readable from session")
      }
      assert_eq(
        json_int(
          @mooncode.session_summary(
            with_runtime_handoff,
            json_array_items(with_runtime_handoff, "mooncode_command_events"),
          ),
          "mooncode_runtime_handoff_manifest_count",
          default=0,
        ),
        1,
      )
      assert_eq(
        json_int(
          @mooncode.session_summary(
            with_runtime_handoff,
            json_array_items(with_runtime_handoff, "mooncode_command_events"),
          ),
          "moonbook_eval_report_manifest_count",
          default=0,
        ),
        1,
      )
    }
    None => fail("package action should write a MoonBook review receipt")
  }
}

///|
test "mooncode summary exposes eval readiness gates" {
  let base_session : Json = {
    "id": "s1",
    "workspace_id": "book",
    "moonclaw_task_id": "task-1",
    "mooncode_event_log_path": "/tmp/mooncode/events.jsonl",
    "mooncode_append_log_count": 1,
    "mooncode_command_log_path": "/tmp/mooncode/commands.jsonl",
    "mooncode_command_log_count": 1,
    "mooncode_last_package_manifest": {
      "kind": "mooncode-package-manifest",
      "source_inventory_status": "source-bound",
      "source_present_count": 1,
    },
    "mooncode_last_package_index_manifest": {
      "kind": "mooncode-package-index",
      "manifest_path": "portable/app-tool/mooncode/s1/index.json",
      "source_bound_package_count": 1,
    },
    "mooncode_last_change_set_manifest": {
      "kind": "mooncode-change-set",
      "manifest_path": "wiki/reviews/mooncode/s1/change-set.json",
    },
    "mooncode_last_patch_set_manifest": {
      "kind": "mooncode-patch-set",
      "manifest_path": "wiki/reviews/mooncode/s1/patch-set.json",
    },
    "mooncode_last_tool_approvals_manifest": {
      "kind": "mooncode-tool-approvals",
      "manifest_path": "wiki/reviews/mooncode/s1/tool-approvals.json",
    },
    "mooncode_last_test_runs_manifest": {
      "kind": "mooncode-test-runs",
      "manifest_path": "wiki/reviews/mooncode/s1/test-runs.json",
    },
    "mooncode_last_runtime_handoff_manifest": {
      "kind": "mooncode-runtime-handoff",
      "manifest_path": "wiki/reviews/mooncode/s1/runtime-handoff.json",
    },
  }
  let command_packet = mooncode_command_packet(
    base_session,
    { "context_path": "tools/demo/main.mbt" },
    "accept",
    "Accept the proposed file.",
    "7",
    "tools/demo/main.mbt",
  )
  let events = [
    @mooncode.event_record(
      id="transcript",
      lane="transcript",
      kind="message.user",
      title="User",
      status="recorded",
      created_at="1",
      detail="Please edit this book tool.",
    ),
    @mooncode.event_record(
      id="tool",
      lane="tool",
      kind="tool.read",
      title="Read",
      status="completed",
      created_at="2",
      detail="read source",
    ),
    @mooncode.event_record(
      id="diff",
      lane="diff",
      kind="file.write",
      title="Write",
      status="completed",
      created_at="3",
      detail="wrote file",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
    ),
    @mooncode.event_record(
      id="test",
      lane="test",
      kind="tool.moon_check",
      title="Moon check",
      status="passed",
      created_at="4",
      detail="passed",
      command="moon test",
    ),
    @mooncode.event_record(
      id="artifact",
      lane="artifact",
      kind="artifact.package",
      title="Package",
      status="completed",
      created_at="5",
      detail="packaged",
    ),
    @mooncode.event_record(
      id="review",
      lane="review",
      kind="review.accept",
      title="Accept",
      status="accepted",
      created_at="6",
      detail="accepted",
      command_packet~,
    ),
    @mooncode.event_record(
      id="approve-tool",
      lane="review",
      kind="command.approve_tool",
      title="Approve tool",
      status="approved",
      created_at="6",
      detail="approved file write",
      path="tools/demo/main.mbt",
      command="approve_tool",
      command_packet~,
    ),
    @mooncode.event_record(
      id="approve-artifact",
      lane="review",
      kind="command.approve_tool",
      title="Approve artifact",
      status="approved",
      created_at="6",
      detail="approved package artifact",
      path="artifact",
      command="approve_tool",
      command_packet~,
    ),
    @mooncode.event_record(
      id="receipt",
      lane="review",
      kind="receipt.accept",
      title="MoonBook review receipt",
      status="recorded",
      created_at="7",
      detail="MoonBook review receipt recorded",
      path="wiki/reviews/mooncode/s1/accept-command.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="manifest",
      lane="artifact",
      kind="package.manifest",
      title="MoonBook package manifest",
      status="candidate",
      created_at="8",
      detail="MoonBook package manifest recorded",
      path="portable/app-tool/mooncode/s1/package-command.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="package-index",
      lane="artifact",
      kind="package.index",
      title="MoonBook package index",
      status="source-bound",
      created_at="8",
      detail="MoonBook package index recorded",
      path="portable/app-tool/mooncode/s1/index.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="change-set",
      lane="review",
      kind="change_set.manifest",
      title="MoonCode change set",
      status="pending",
      created_at="9",
      detail="MoonBook change-set manifest recorded",
      path="wiki/reviews/mooncode/s1/change-set.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="patch-set",
      lane="review",
      kind="patch_set.manifest",
      title="MoonCode patch set",
      status="accepted",
      created_at="10",
      detail="MoonBook patch-set manifest recorded",
      path="wiki/reviews/mooncode/s1/patch-set.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="tool-approvals",
      lane="review",
      kind="tool_approvals.manifest",
      title="MoonCode tool approvals",
      status="approved",
      created_at="11",
      detail="MoonBook tool-approval manifest recorded",
      path="wiki/reviews/mooncode/s1/tool-approvals.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="test-runs",
      lane="review",
      kind="test_runs.manifest",
      title="MoonCode test runs",
      status="passed",
      created_at="12",
      detail="MoonBook test-run manifest recorded",
      path="wiki/reviews/mooncode/s1/test-runs.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="runtime-evidence",
      lane="runtime",
      kind="runtime_evidence.manifest",
      title="MoonCode runtime evidence",
      status="proven",
      created_at="12",
      detail="MoonCode runtime evidence recorded",
      path="wiki/reviews/mooncode/s1/runtime-evidence.json",
      command_packet~,
    ),
    @mooncode.event_record(
      id="runtime-handoff",
      lane="runtime",
      kind="runtime.handoff",
      title="MoonCode runtime handoff",
      status="bridge-resumable",
      created_at="14",
      detail="MoonCode runtime handoff recorded",
      path="wiki/reviews/mooncode/s1/runtime-handoff.json",
      command_packet~,
    ),
  ]
  let summary = @mooncode.session_summary(base_session, events)
  assert_eq(
    json_string(summary, "stream_mode", default=""),
    "append-log-incremental",
  )
  assert_eq(
    json_string(summary, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_false(json_bool(summary, "live_stream_ready", default=true))
  assert_true(json_bool(summary, "incremental_stream_ready", default=false))
  assert_true(
    json_string(summary, "incremental_stream_url", default="").contains(
      "since=<sequence>",
    ),
  )
  assert_eq(
    json_string(summary, "event_log_path", default=""),
    "/tmp/mooncode/events.jsonl",
  )
  assert_true(json_bool(summary, "append_log_ready", default=false))
  assert_eq(json_int(summary, "append_log_count", default=0), 1)
  assert_eq(
    json_string(summary, "command_log_path", default=""),
    "/tmp/mooncode/commands.jsonl",
  )
  assert_true(json_bool(summary, "command_log_ready", default=false))
  assert_eq(json_int(summary, "command_log_count", default=0), 1)
  assert_eq(json_int(summary, "command_packet_count", default=0), 1)
  assert_eq(json_int(summary, "moonbook_review_receipt_count", default=0), 1)
  assert_eq(json_int(summary, "moonbook_package_manifest_count", default=0), 1)
  assert_eq(
    json_int(summary, "moonbook_package_index_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "moonbook_change_set_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "moonbook_patch_set_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "moonbook_tool_approvals_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "moonbook_test_runs_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "mooncode_runtime_evidence_manifest_count", default=0),
    1,
  )
  assert_eq(
    json_int(summary, "mooncode_runtime_handoff_manifest_count", default=0),
    1,
  )
  assert_false(json_bool(summary, "session_snapshot_ready", default=true))
  assert_eq(json_string(summary, "session_snapshot_path", default="x"), "")
  assert_eq(json_int(summary, "pending_tool_approval_count", default=-1), 0)
  assert_eq(json_int(summary, "verified_test_count", default=0), 1)
  assert_eq(json_int(summary, "failed_test_count", default=0), 0)
  assert_eq(json_int(summary, "source_bound_package_count", default=0), 1)
  assert_eq(json_int(summary, "runtime_package_proof_count", default=-1), 0)
  assert_eq(json_int(summary, "runtime_verified_package_count", default=-1), 0)
  assert_eq(
    json_int(summary, "runtime_patch_execution_proof_count", default=-1),
    0,
  )
  assert_eq(json_int(summary, "eval_score", default=0), 85)
  assert_eq(json_string(summary, "eval_level", default=""), "ready")
  assert_eq(json_int(summary, "pending_diff_count", default=0), 1)
  assert_eq(json_int(summary, "accepted_review_count", default=0), 0)
  assert_eq(json_string(summary, "review_state", default=""), "pending")
  let checks = json_array_items(summary, "eval_checks")
  assert_eq(checks.length(), 28)
  let eval_report = @mooncode.eval_report_projection(
    agent_session_with_field(base_session, "mooncode_summary", summary),
  )
  assert_eq(
    json_string(eval_report, "kind", default=""),
    "mooncode-eval-report",
  )
  assert_eq(json_string(eval_report, "status", default=""), "bridge-partial")
  assert_eq(json_int(eval_report, "bridge_score", default=0), 85)
  assert_eq(json_int(eval_report, "check_count", default=0), 28)
  assert_eq(json_int(eval_report, "missing_check_count", default=0), 4)
  assert_false(
    json_bool(eval_report, "native_eval_evidence_ready", default=true),
  )
  assert_eq(
    json_string(eval_report, "native_eval_source", default=""),
    "missing",
  )
  assert_eq(
    json_string(eval_report, "native_eval_endpoint", default=""),
    "/v1/mooncode/sessions/<id>/eval-report?book_root=<path>",
  )
  assert_eq(
    json_string(eval_report, "native_eval_ingest_method", default=""),
    "POST",
  )
  assert_eq(
    json_string(eval_report, "native_eval_ingest_endpoint", default=""),
    "/api/mooncode/sessions/s1/eval-report",
  )
  assert_true(
    json_string(eval_report, "current_gap", default="").contains("MoonClaw"),
  )
  let native_eval = mooncode_normalize_native_eval_report(
    { "native_eval_evidence_ready": true, "harnesses": ["tool_harness"] },
    "/v1/mooncode/sessions/s1/eval-report",
  )
  assert_true(json_bool(native_eval, "ok", default=false))
  assert_eq(
    json_string(native_eval, "source", default=""),
    "moonclaw-native-runtime",
  )
  assert_eq(
    json_string(native_eval, "endpoint", default=""),
    "/v1/mooncode/sessions/s1/eval-report",
  )
  let native_eval_report = @mooncode.eval_report_projection(
    agent_session_with_field(
      agent_session_with_field(base_session, "mooncode_summary", summary),
      "mooncode_native_eval_report",
      native_eval,
    ),
  )
  assert_eq(
    json_string(native_eval_report, "status", default=""),
    "native-partial",
  )
  assert_true(
    json_bool(native_eval_report, "native_eval_evidence_ready", default=false),
  )
  assert_eq(
    json_string(native_eval_report, "native_eval_source", default=""),
    "moonclaw-native-runtime",
  )
  assert_eq(json_string(checks[6], "id", default=""), "verified_test_results")
  assert_true(json_bool(checks[6], "ok", default=false))
  let check_payload = Json::array(checks).stringify()
  assert_true(check_payload.contains("typed_command_packets"))
  assert_true(check_payload.contains("ordered_command_queue"))
  assert_true(check_payload.contains("moonbook_review_receipts"))
  assert_true(check_payload.contains("moonbook_package_manifest"))
  assert_true(check_payload.contains("moonbook_package_index"))
  assert_true(check_payload.contains("moonbook_change_set_manifest"))
  assert_true(check_payload.contains("moonbook_patch_set_manifest"))
  assert_true(check_payload.contains("runtime_patch_execution_proof"))
  assert_true(check_payload.contains("runtime_package_proof"))
  assert_true(check_payload.contains("moonbook_tool_approvals_manifest"))
  assert_true(check_payload.contains("moonbook_test_runs_manifest"))
  assert_true(check_payload.contains("tool_approval_queue"))
  assert_eq(
    json_string(checks[checks.length() - 4], "id", default=""),
    "source_bound_package",
  )
  assert_true(json_bool(checks[checks.length() - 4], "ok", default=false))
  assert_eq(
    json_string(checks[checks.length() - 3], "id", default=""),
    "runtime_package_proof",
  )
  assert_false(json_bool(checks[checks.length() - 3], "ok", default=true))
  assert_eq(
    json_string(checks[checks.length() - 2], "id", default=""),
    "incremental_append_stream",
  )
  assert_true(json_bool(checks[checks.length() - 2], "ok", default=false))
  assert_eq(
    json_string(checks[checks.length() - 1], "id", default=""),
    "live_append_only_stream",
  )
  assert_true(json_bool(checks[checks.length() - 1], "ok", default=false))
  assert_true(
    json_string(checks[checks.length() - 1], "evidence", default="").contains(
      "?live=true",
    ),
  )
}

///|
async test "mooncode native eval report ingress persists moonbook proof" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-native-eval-wbtest-" +
    @desk.stable_id("mooncode-native-eval", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "moonclaw_task_id": "task-demo",
    "mooncode_dispatch_mode": "moonclaw-mooncode-runtime",
  }
  let eval_payload : Json = { "context_path": "tools/demo/main.mbt" }
  let eval_message = @mooncode.command_message("run_eval", eval_payload)
  let eval_packet = mooncode_command_packet(
    session, eval_payload, "run_eval", eval_message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let eval_runtime_command = @mooncode.runtime_command_record(
    session, eval_payload, eval_message, eval_packet,
  )
  append_mooncode_command_log(root, "agent-demo", eval_packet)
  append_mooncode_runtime_command_log(root, "agent-demo", eval_runtime_command)
  append_mooncode_runtime_dispatch_log(
    root,
    "agent-demo",
    mooncode_runtime_dispatch_receipt(session, eval_runtime_command),
  )
  let before_plan = mooncode_action_plan_projection(root, session)
  let before_actions = json_array_items(before_plan, "actions")
  assert_eq(json_string(before_actions[0], "action", default=""), "run_eval")
  assert_eq(
    json_string(before_actions[0], "state", default=""),
    "awaiting-proof",
  )
  let command_id = json_string(eval_packet, "command_id", default="")
  for
    event in @mooncode.runtime_ingest_events(
      {
        "events": [
          {
            "event": "tool_call",
            "id": "eval-tool-call-read",
            "created_at": "2026-06-14T00:00:30Z",
            "tool_name": "read",
            "tool_call_id": "eval-call-read",
            "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_result",
            "id": "eval-tool-result-read",
            "created_at": "2026-06-14T00:00:45Z",
            "tool_name": "read",
            "tool_call_id": "eval-call-read",
            "content": "fn main { println(\"demo\") }",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_call",
            "id": "eval-tool-call-check",
            "created_at": "2026-06-14T00:01:00Z",
            "tool_name": "moon_check",
            "tool_call_id": "eval-call-check",
            "arguments": "{\"command\":\"moon check\"}",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_result",
            "id": "eval-tool-result-check",
            "created_at": "2026-06-14T00:01:20Z",
            "tool_name": "moon_check",
            "tool_call_id": "eval-call-check",
            "content": "moon check passed",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_call",
            "id": "eval-tool-call-shell",
            "created_at": "2026-06-14T00:01:40Z",
            "tool_name": "shell",
            "tool_call_id": "eval-call-shell",
            "arguments": "{\"command\":\"moon test\"}",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "tool_result",
            "id": "eval-tool-result-shell",
            "created_at": "2026-06-14T00:01:55Z",
            "tool_name": "shell",
            "tool_call_id": "eval-call-shell",
            "content": "moon test passed",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "test_result",
            "id": "eval-test-result",
            "created_at": "2026-06-14T00:02:10Z",
            "status": "done",
            "command": "moon test",
            "exit_code": 0,
            "detail": "Total tests: 1, passed: 1",
            "command_id": command_id,
            "action": "run_eval",
          },
          {
            "event": "agent_finished",
            "id": "eval-finish",
            "created_at": "2026-06-14T00:02:30Z",
            "answer": "eval passed",
            "command_id": command_id,
            "action": "run_eval",
          },
        ],
      },
      ingested_at="2026-06-15T00:00:00Z",
    ) {
    append_mooncode_event_log(root, "agent-demo", event)
  }
  let native_payload : Json = {
    "ok": true,
    "required_harnesses": ["tool_harness", "file_edit"],
    "harnesses": [
      { "id": "tool_harness", "status": "passed" },
      { "id": "file_edit", "status": "passed" },
    ],
    "tool_harness": { "status": "passed", "passed_count": 8 },
    "file_edit": { "status": "passed", "passed_count": 5 },
    "passed_count": 13,
    "failed_count": 0,
    "evidence": ["OpenSeek-style harnesses passed"],
  }
  let with_report = persist_mooncode_native_eval_report(
    root,
    session,
    native_payload,
    "/v1/mooncode/sessions/agent-demo/eval-report?book_root=" +
    encode_query_value(root),
  )
  let after_plan = mooncode_action_plan_projection(root, with_report)
  let after_actions = json_array_items(after_plan, "actions")
  assert_eq(json_string(after_actions[0], "action", default=""), "run_eval")
  assert_eq(json_string(after_actions[0], "state", default=""), "completed")
  let native_report = json_object_field_or_empty(
    with_report, "mooncode_native_eval_report",
  )
  assert_true(json_bool(native_report, "ok", default=false))
  assert_eq(
    json_string(native_report, "source", default=""),
    "moonclaw-native-runtime",
  )
  assert_eq(
    json_string(native_report, "endpoint", default=""),
    "/v1/mooncode/sessions/agent-demo/eval-report?book_root=" +
    encode_query_value(root),
  )
  let manifest = json_object_field_or_empty(
    with_report, "mooncode_last_eval_report_manifest",
  )
  assert_eq(json_string(manifest, "kind", default=""), "mooncode-eval-report")
  assert_true(json_bool(manifest, "native_eval_evidence_ready", default=false))
  assert_eq(json_string(manifest, "status", default=""), "native-partial")
  assert_eq(
    json_string(manifest, "native_eval_ingest_endpoint", default=""),
    "/api/mooncode/sessions/agent-demo/eval-report",
  )
  let relative = json_string(manifest, "manifest_path", default="")
  assert_eq(relative, "wiki/reviews/mooncode/agent-demo/eval-report.json")
  assert_true(@fs.exists(@pathx.join(root, relative)))
  let snapshot = json_object_field_or_empty(
    with_report, "mooncode_session_snapshot",
  )
  assert_eq(
    json_string(snapshot, "kind", default=""),
    "mooncode-session-snapshot",
  )
  assert_true(@fs.exists(json_string(snapshot, "snapshot_path", default="")))
  let runtime_handoff = json_object_field_or_empty(
    with_report, "mooncode_last_runtime_handoff_manifest",
  )
  assert_eq(
    json_string(runtime_handoff, "kind", default=""),
    "mooncode-runtime-handoff",
  )
  assert_true(
    @fs.exists(
      json_string(runtime_handoff, "absolute_manifest_path", default=""),
    ),
  )
  let durable_events = read_mooncode_event_log(root, "agent-demo")
  let mut saw_eval_report_event = false
  for event in durable_events {
    match json_string(event, "kind", default="") {
      "eval_report.manifest" =>
        if json_string(event, "path", default="") == relative {
          saw_eval_report_event = true
        }
      _ => ()
    }
  }
  assert_true(saw_eval_report_event)
  assert_false(manifest.stringify().contains("stale-eval-report"))
  let response_projection = @mooncode.eval_report_projection(with_report)
  let response_summary = json_object_field_or_empty(
    response_projection, "summary",
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(
        response_summary, "last_moonbook_eval_report_manifest",
      ),
      "manifest_path",
      default="",
    ),
    relative,
  )
  assert_true(
    json_bool(response_summary, "session_snapshot_ready", default=false),
  )
  assert_eq(
    json_int(
      response_summary,
      "mooncode_runtime_handoff_manifest_count",
      default=0,
    ),
    1,
  )
  match read_agent_session_record(root, "agent-demo") {
    Some(saved) => {
      let saved_native = json_object_field_or_empty(
        saved, "mooncode_native_eval_report",
      )
      assert_true(json_bool(saved_native, "ok", default=false))
      assert_eq(
        json_string(
          json_object_field_or_empty(
            saved, "mooncode_last_eval_report_manifest",
          ),
          "manifest_path",
          default="",
        ),
        relative,
      )
      assert_true(
        json_bool(
          json_object_field_or_empty(saved, "mooncode_summary"),
          "session_snapshot_ready",
          default=false,
        ),
      )
    }
    None => fail("native eval ingress should persist the session record")
  }
}

///|
test "mooncode new session record starts with typed coding protocol" {
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo Book",
    root_path="/tmp/demo-book",
    kind=@desk.WorkspaceKind::MoonBook,
  )
  let task : Json = {
    "id": "task-demo",
    "status": "created",
    "model": "default",
    "web_search": true,
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "web_search": true,
  }
  let session = mooncode_new_session_record(
    workspace, task, "MoonCode - Demo Book", "2026-06-15T00:00:00Z", "Build a demo tool",
    payload,
  )
  assert_true(json_string(session, "id", default="").has_prefix("mooncode-"))
  assert_eq(json_string(session, "component", default=""), "mooncode")
  assert_eq(json_string(session, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(session, "mooncode_session_kind", default=""), "coding")
  assert_eq(
    json_string(session, "mooncode_initial_context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_eq(json_string(session, "workspace_id", default=""), "book-demo")
  assert_eq(json_string(session, "moonclaw_task_id", default=""), "task-demo")
  assert_eq(json_array_items(session, "transcript").length(), 0)
}

///|
test "mooncode prompt command packet seeds durable session creation" {
  let session : Json = {
    "id": "mooncode-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "moonclaw_task_id": "task-demo",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "web_search": false,
  }
  let packet = mooncode_command_packet(
    session, payload, "prompt", "Build a demo tool", "2026-06-15T00:00:00Z", "tools/demo/main.mbt",
  )
  assert_eq(json_string(packet, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(packet, "action", default=""), "prompt")
  assert_eq(json_string(packet, "dispatch", default=""), "prompt")
  assert_eq(json_string(packet, "approval", default=""), "user")
  assert_eq(
    json_string(packet, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_true(
    json_string_array_items(packet, "expected_lanes").contains("diff"),
  )
  assert_true(json_string_array_items(packet, "tool_hints").contains("write"))
  let queued = append_mooncode_command_event(
    session,
    action="prompt",
    status="queued",
    detail="Build a demo tool",
    created_at="2026-06-15T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet=packet,
  )
  let events = project_mooncode_events(queued, [], [])
  let summary = @mooncode.session_summary(queued, events)
  assert_eq(json_int(summary, "command_packet_count", default=0), 1)
  assert_eq(json_int(summary, "event_count", default=0), 1)
  assert_eq(json_string(events[0], "lane", default=""), "runtime")
}

///|
test "mooncode summary and eval report use extracted protocol" {
  let event = @mooncode.event_record(
    id="d1",
    lane="diff",
    kind="tool.write",
    title="Write file",
    status="done",
    created_at="1",
    detail="updated file",
    path="tools/demo/main.mbt",
    diff="+fn main { println(\"ok\") }",
  )
  let session : Json = {
    "id": "s1",
    "workspace_id": "book-demo",
    "moonclaw_task_id": "task-demo",
    "mooncode_append_log_count": 1,
    "mooncode_command_log_count": 1,
    "mooncode_runtime_command_log_count": 1,
  }
  let extracted_summary = @mooncode.session_summary(session, [event])
  assert_eq(json_int(extracted_summary, "diff_count", default=0), 1)
  assert_eq(
    json_string(extracted_summary, "review_state", default=""),
    "pending",
  )
  let with_summary = agent_session_with_field(
    session, "mooncode_summary", extracted_summary,
  )
  let extracted_report = @mooncode.eval_report_projection(with_summary)
  assert_eq(
    json_string(extracted_report, "kind", default=""),
    "mooncode-eval-report",
  )
  assert_eq(
    json_string(extracted_report, "extractable_component", default=""),
    "mooncode",
  )
}
