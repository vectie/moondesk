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
  let context_path = mooncode_command_context_path(payload)
  let base = mooncode_new_session_record(
    workspace, task, title, now, message, payload,
  )
  let command_packet = mooncode_command_packet(
    base, payload, "prompt", message, now, context_path,
  )
  let runtime_command = mooncode_runtime_command_record(
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
    initial_context_path=mooncode_command_context_path(payload),
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
        mooncode_tool_authorization_contract(session_id, manifest),
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
  let approval = mooncode_tool_event_approval(preview)
  let target = mooncode_tool_approval_target(preview)
  let should_record = approval != "" &&
    !mooncode_tool_authorization_has_target(events, target)
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
    default="/v1/mooncode/sessions/\{session_id}/eval-report",
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
    mooncode_session_without_eval_report_projection(session),
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
fn mooncode_session_without_eval_report_projection(session : Json) -> Json {
  let object : Map[String, Json] = {}
  match session {
    Json::Object(fields) =>
      for key, value in fields {
        if key != "mooncode_last_eval_report_manifest" &&
          key != "mooncode_summary" {
          object[key] = value
        }
      }
    _ => ()
  }
  Json::object(object)
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
          if mooncode_runtime_handoff_manifest_current(manifest) {
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
      send_json(conn, method_, {
        "protocol": "mooncode.v1",
        "kind": "mooncode-runtime-command-feed",
        "session_id": session_id,
        "workspace_id": json_string(session, "workspace_id", default=""),
        "workspace_name": json_string(session, "workspace_name", default=""),
        "task_id": json_string(session, "moonclaw_task_id", default=""),
        "runtime_command_log_path": mooncode_runtime_command_log_path(
          workspace_root, session_id,
        ),
        "runtime_command_count": commands.length(),
        "runtime_dispatch_log_path": mooncode_runtime_dispatch_log_path(
          workspace_root, session_id,
        ),
        "runtime_claim_endpoint": "/api/mooncode/sessions/\{session_id}/runtime-claim",
        "runtime_dispatch_count": receipts.length(),
        "runtime_dispatch_pending_count": mooncode_runtime_dispatch_pending_count(
          commands, receipts,
        ),
        "commands": Json::array(commands),
        "dispatch_receipts": Json::array(
          mooncode_runtime_dispatch_receipts_for_response(receipts),
        ),
        "runtime_replay": mooncode_runtime_replay_state(
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
        "decode_reports": Json::array(
          [
            for command in commands => {
              @mooncode.runtime_command_decode_report(command)
            }
          ],
        ),
        "execution_summaries": Json::array(
          [
            for command in commands => {
              mooncode_runtime_command_execution_summary(command)
            }
          ],
        ),
        "command_lifecycle": mooncode_runtime_command_lifecycle(
          session_id, commands, receipts, events,
        ),
        "serve_scheduler": mooncode_serve_scheduler_projection(
          session_id,
          commands,
          mooncode_runtime_command_lifecycle(
            session_id, commands, receipts, events,
          ),
        ),
        "runtime_turn_packet": @mooncode.runtime_turn_packet(
          session_id,
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
          ),
          mooncode_serve_scheduler_projection(
            session_id,
            commands,
            mooncode_runtime_command_lifecycle(
              session_id, commands, receipts, events,
            ),
          ),
          false,
        ),
        "runtime_supervisor": mooncode_runtime_supervisor_launch_packet(
          workspace_root,
          session,
          session_id,
          commands,
          receipts,
          events,
          moonclaw_daemon_status(workspace_root),
          native_ready=false,
        ),
        "wire_protocol": {
          "openseek_serve_commands": Json::array(
            [
              for command in @mooncode.serve_command_names() => {
                Json::string(command)
              }
            ],
          ),
          "native_mooncode_endpoint": "/v1/mooncode/sessions/\{session_id}/commands",
          "ordering_rule": "append-only runtime-commands.jsonl; consume in file order",
        },
        "runtime_protocol": @mooncode.runtime_protocol_contract_json(),
        "runtime_claim_contract": mooncode_runtime_claim_consumer_contract_json(
          session_id,
        ),
        "owner": {
          "ui": "moondesk",
          "runtime": "moonclaw",
          "extractable_component": "mooncode",
        },
      })
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
  let events = mooncode_runtime_replay_ack_normalized_events(ack_receipts)
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
  send_json(conn, method_, {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-replay-ack",
    "session_id": session_id,
    "accepted_receipt_count": ack_receipts.length(),
    "accepted_event_count": events.length(),
    "receipts": Json::array(ack_receipts),
    "runtime_replay": mooncode_runtime_replay_state(
      session_id,
      commands,
      next_receipts,
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
    "runtime_evidence": json_object_field_or_empty(
      with_runtime_handoff, "mooncode_last_runtime_evidence_manifest",
    ),
    "session": enrich_agent_session_for_response(
      workspace_root,
      with_runtime_handoff,
      [],
    ),
  })
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
  send_json(conn, method_, {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-claim",
    "session_id": session_id,
    "claimed_count": claim_receipts.length(),
    "claim_receipts": Json::array(claim_receipts),
    "claimed_commands": Json::array(
      [
        for receipt in claim_receipts => {
          json_object_field_or_empty(receipt, "runtime_command")
        }
      ],
    ),
    "runtime_replay": mooncode_runtime_replay_state(
      session_id,
      commands,
      next_receipts,
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
    "claim_state": mooncode_runtime_claim_state(
      session_id,
      commands,
      next_receipts,
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
    "consumer_contract": mooncode_runtime_claim_consumer_contract_json(
      session_id,
    ),
    "session": enrich_agent_session_for_response(
      workspace_root,
      with_runtime_handoff,
      [],
    ),
  })
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
      let lifecycle = mooncode_runtime_command_lifecycle(
        session_id, runtime_commands, receipts, events,
      )
      send_json(
        conn,
        method_,
        mooncode_serve_scheduler_projection(session_id, commands, lifecycle),
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
      send_json(conn, method_, {
        "protocol": "mooncode.v1",
        "kind": "mooncode-runtime-dispatch-state",
        "session_id": session_id,
        "workspace_id": json_string(session, "workspace_id", default=""),
        "workspace_name": json_string(session, "workspace_name", default=""),
        "task_id": json_string(session, "moonclaw_task_id", default=""),
        "dispatch_mode": json_string(
          session,
          "mooncode_dispatch_mode",
          default="unknown",
        ),
        "runtime_command_count": commands.length(),
        "runtime_dispatch_count": receipts.length(),
        "runtime_dispatch_pending_count": mooncode_runtime_dispatch_pending_count(
          commands, receipts,
        ),
        "runtime_command_log_path": mooncode_runtime_command_log_path(
          workspace_root, session_id,
        ),
        "runtime_dispatch_log_path": mooncode_runtime_dispatch_log_path(
          workspace_root, session_id,
        ),
        "dispatch_receipts": Json::array(
          mooncode_runtime_dispatch_receipts_for_response(receipts),
        ),
        "pending_command_ids": Json::array(
          mooncode_runtime_pending_command_ids(commands, receipts),
        ),
        "runtime_protocol": @mooncode.runtime_protocol_contract_json(),
        "owner": {
          "ui": "moondesk",
          "runtime": "moonclaw",
          "extractable_component": "mooncode",
        },
      })
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
      send_json(conn, method_, {
        "protocol": "mooncode.v1",
        "kind": "mooncode-runtime-event-sink",
        "session_id": session_id,
        "workspace_id": json_string(session, "workspace_id", default=""),
        "workspace_name": json_string(session, "workspace_name", default=""),
        "task_id": json_string(session, "moonclaw_task_id", default=""),
        "event_log_path": mooncode_event_log_path(workspace_root, session_id),
        "event_count": events.length(),
        "events": Json::array(events),
        "command_progress": @mooncode.runtime_event_command_progress(events),
        "post_contract": mooncode_runtime_event_ingest_contract(session_id),
        "runtime_protocol": @mooncode.runtime_protocol_contract_json(),
        "owner": {
          "ui": "moondesk",
          "runtime": "moonclaw",
          "extractable_component": "mooncode",
        },
      })
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
  send_json(conn, method_, {
    "protocol": "mooncode.v1",
    "kind": "mooncode-runtime-event-ingest-result",
    "session_id": session_id,
    "accepted_event_count": events.length(),
    "ingest_report": ingest_report,
    "event_log_path": mooncode_event_log_path(workspace_root, session_id),
    "command_progress": @mooncode.runtime_event_command_progress(
      read_mooncode_event_log(workspace_root, session_id),
    ),
    "action_plan": json_object_field_or_empty(
      with_runtime_handoff, "mooncode_last_action_plan_manifest",
    ),
    "change_set": json_object_field_or_empty(
      with_runtime_handoff, "mooncode_last_change_set_manifest",
    ),
    "patch_set": json_object_field_or_empty(
      with_runtime_handoff, "mooncode_last_patch_set_manifest",
    ),
    "tool_approvals": json_object_field_or_empty(
      with_runtime_handoff, "mooncode_last_tool_approvals_manifest",
    ),
    "test_runs": json_object_field_or_empty(
      with_runtime_handoff, "mooncode_last_test_runs_manifest",
    ),
    "runtime_evidence": json_object_field_or_empty(
      with_runtime_handoff, "mooncode_last_runtime_evidence_manifest",
    ),
    "eval_report": json_object_field_or_empty(
      with_runtime_handoff, "mooncode_last_eval_report_manifest",
    ),
    "runtime_handoff": json_object_field_or_empty(
      with_runtime_handoff, "mooncode_last_runtime_handoff_manifest",
    ),
    "session": enrich_agent_session_for_response(
      workspace_root,
      with_runtime_handoff,
      [],
    ),
  })
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
      send_json(conn, method_, {
        "protocol": "mooncode.v1",
        "kind": "mooncode-command-queue",
        "session_id": session_id,
        "workspace_id": json_string(session, "workspace_id", default=""),
        "workspace_name": json_string(session, "workspace_name", default=""),
        "task_id": json_string(session, "moonclaw_task_id", default=""),
        "command_log_path": mooncode_command_log_path(
          workspace_root, session_id,
        ),
        "command_count": commands.length(),
        "commands": Json::array(commands),
        "ordering_rule": "append-only commands.jsonl; MoonClaw or standalone MoonCode consumes commands in file order",
        "owner": {
          "ui": "moondesk",
          "runtime": "moonclaw",
          "extractable_component": "mooncode",
        },
      })
    }
    None =>
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
  }
}

///|
async fn handle_mooncode_session_stream(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let format = query_value(request_path, "format").unwrap_or("jsonl")
      let since = mooncode_stream_since(request_path)
      let live = mooncode_stream_live_enabled(request_path)
      let live_timeout_ms = mooncode_stream_live_timeout_ms(request_path)
      let live_poll_ms = mooncode_stream_live_poll_ms(request_path)
      let content_type = mooncode_stream_content_type(format)
      match
        mooncode_native_stream_text(workspace_root, session_id, format, since) {
        Ok(text) => send_text(conn, method_, content_type, text)
        Err(_) => {
          let projected = if live {
            mooncode_live_stream_projection(
              workspace_root, session_id, session, since, live_timeout_ms, live_poll_ms,
            )
          } else {
            attach_mooncode_session_projection(workspace_root, session)
          }
          let events = json_array_items(projected, "mooncode_events")
          if format == "sse" {
            send_text(
              conn,
              method_,
              content_type,
              mooncode_sse_stream_text(projected, events, since~),
            )
          } else {
            send_text(
              conn,
              method_,
              content_type,
              mooncode_jsonl_stream_text(projected, events, since~),
            )
          }
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
async fn handle_mooncode_session_stream_state(
  workspace_root : String,
  session_id : String,
  request_path : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let since = mooncode_stream_since(request_path)
  if method_ is @http.RequestMethod::Post {
    let payload = match read_json_body(body) {
      Some(json) => json
      None => {
        send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
        return
      }
    }
    let consumer_id = mooncode_stream_checkpoint_consumer(request_path, payload)
    let projected = attach_mooncode_session_projection(workspace_root, session)
    let events = json_array_items(projected, "mooncode_events")
    let requested_sequence = mooncode_stream_checkpoint_sequence(
      payload,
      since,
      events.length(),
    )
    let checkpoint = mooncode_stream_checkpoint_record(
      workspace_root,
      projected,
      consumer_id,
      requested_sequence,
      events.length(),
    )
    write_mooncode_stream_checkpoint(
      workspace_root, session_id, consumer_id, checkpoint,
    ) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not save MoonCode stream checkpoint",
        )
        return
      }
    }
    send_json(
      conn,
      method_,
      mooncode_stream_state_projection(
        workspace_root, projected, since, consumer_id,
      ),
    )
  } else {
    let consumer_id = mooncode_stream_checkpoint_consumer(
      request_path,
      Json::object({}),
    )
    send_json(
      conn,
      method_,
      mooncode_stream_state_projection(
        workspace_root, session, since, consumer_id,
      ),
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
  let action = mooncode_command_action(payload)
  if !mooncode_command_is_supported(action) {
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
  let action = mooncode_command_action(payload)
  if !mooncode_command_is_supported(action) {
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
  let context_path = mooncode_command_context_path(payload)
  let message = mooncode_command_message(action, payload)
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
  let runtime_command = mooncode_runtime_command_record(
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
fn mooncode_jsonl_stream_text(
  session : Json,
  events : Array[Json],
  since? : Int = 0,
) -> String {
  @mooncode.stream_jsonl_text(session, events, since~)
}

///|
fn mooncode_sse_stream_text(
  session : Json,
  events : Array[Json],
  since? : Int = 0,
) -> String {
  @mooncode.stream_sse_text(session, events, since~)
}

///|
fn mooncode_stream_since(request_path : String) -> Int {
  let value = query_value(request_path, "since").unwrap_or("")
  let parsed = @string.parse_int(value) catch { _ => 0 }
  if parsed < 0 {
    0
  } else {
    parsed
  }
}

///|
fn mooncode_stream_live_enabled(request_path : String) -> Bool {
  let value = query_value(request_path, "live").unwrap_or("").to_lower()
  value == "1" || value == "true" || value == "tail" || value == "wait"
}

///|
fn mooncode_stream_live_timeout_ms(request_path : String) -> Int {
  mooncode_clamp_int(
    @string.parse_int(query_value(request_path, "timeout_ms").unwrap_or("")) catch {
      _ => 8000
    },
    0,
    15000,
  )
}

///|
fn mooncode_stream_live_poll_ms(request_path : String) -> Int {
  mooncode_clamp_int(
    @string.parse_int(query_value(request_path, "poll_ms").unwrap_or("")) catch {
      _ => 250
    },
    50,
    1000,
  )
}

///|
fn mooncode_clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
async fn mooncode_live_stream_projection(
  workspace_root : String,
  session_id : String,
  fallback_session : Json,
  since : Int,
  timeout_ms : Int,
  poll_ms : Int,
) -> Json {
  let initial = attach_mooncode_session_projection(
    workspace_root, fallback_session,
  )
  if json_array_items(initial, "mooncode_events").length() > since ||
    timeout_ms <= 0 {
    return initial
  }
  let attempts = mooncode_live_stream_attempt_count(timeout_ms, poll_ms)
  for _ in 0..<attempts {
    @async.sleep(poll_ms)
    match read_agent_session_record(workspace_root, session_id) {
      Some(session) => {
        let projected = attach_mooncode_session_projection(
          workspace_root, session,
        )
        if json_array_items(projected, "mooncode_events").length() > since {
          return projected
        }
      }
      None => ()
    }
  }
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => attach_mooncode_session_projection(workspace_root, session)
    None => initial
  }
}

///|
fn mooncode_live_stream_attempt_count(timeout_ms : Int, poll_ms : Int) -> Int {
  if timeout_ms <= 0 {
    0
  } else {
    let count = timeout_ms / poll_ms
    if count * poll_ms < timeout_ms {
      count + 1
    } else if count == 0 {
      1
    } else {
      count
    }
  }
}

///|
fn mooncode_stream_checkpoint_consumer(
  request_path : String,
  payload : Json,
) -> String {
  let from_payload = json_string(payload, "consumer_id", default="")
  let from_query = query_value(request_path, "consumer").unwrap_or("")
  let candidate = if from_payload != "" {
    from_payload
  } else if from_query != "" {
    from_query
  } else {
    "moondesk-ui"
  }
  mooncode_safe_receipt_id(candidate, fallback="moondesk-ui")
}

///|
fn mooncode_stream_checkpoint_sequence(
  payload : Json,
  fallback_since : Int,
  latest_sequence : Int,
) -> Int {
  @mooncode.stream_checkpoint_sequence(payload, fallback_since, latest_sequence)
}

///|
fn mooncode_stream_tail_event_records(
  session : Json,
  events : Array[Json],
  since : Int,
) -> Array[Json] {
  @mooncode.stream_tail_event_records(session, events, since)
}

///|
fn mooncode_stream_checkpoint_record(
  workspace_root : String,
  session : Json,
  consumer_id : String,
  last_seen_sequence : Int,
  latest_sequence : Int,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let clamped = @mooncode.stream_checkpoint_sequence(
    { "last_seen_sequence": last_seen_sequence },
    0,
    latest_sequence,
  )
  @mooncode.stream_checkpoint_record(
    session,
    consumer_id,
    last_seen_sequence,
    latest_sequence,
    @async.now().to_string(),
    mooncode_stream_checkpoint_path(workspace_root, session_id, consumer_id),
    "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=\{clamped}",
    "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=\{clamped}",
    "/api/mooncode/sessions/\{session_id}/stream-state?consumer=\{consumer_id}&since=\{clamped}",
    "/api/mooncode/sessions/\{session_id}/runtime-events",
  )
}

///|
async fn mooncode_stream_state_projection(
  workspace_root : String,
  session : Json,
  since : Int,
  consumer_id : String,
) -> Json {
  let projected = attach_mooncode_session_projection(workspace_root, session)
  let session_id = json_string(projected, "id", default="")
  let events = json_array_items(projected, "mooncode_events")
  let latest_sequence = events.length()
  let emitted_count = mooncode_stream_emitted_count(events, since)
  let checkpoint = read_mooncode_stream_checkpoint(
    workspace_root, session_id, consumer_id,
  )
  let checkpoint_ready = json_string(checkpoint, "kind", default="") ==
    "mooncode-stream-checkpoint"
  @mooncode.stream_state_record(
    projected,
    consumer_id,
    since,
    latest_sequence,
    emitted_count,
    mooncode_event_log_path(workspace_root, session_id),
    checkpoint_ready,
    mooncode_stream_checkpoint_path(workspace_root, session_id, consumer_id),
    checkpoint,
    mooncode_stream_tail_event_records(projected, events, since),
    "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=\{since}",
    "/api/mooncode/sessions/\{session_id}/stream?format=sse&since=\{since}",
    "/api/mooncode/sessions/\{session_id}/stream-state",
    "/api/mooncode/sessions/\{session_id}/runtime-events",
    "/api/mooncode/sessions/\{session_id}/stream?format=sse&since=\{since}&live=true&timeout_ms=8000",
    "/v1/mooncode/sessions/<id>/stream",
  )
}

///|
fn mooncode_stream_emitted_count(events : Array[Json], since : Int) -> Int {
  @mooncode.stream_emitted_count(events, since)
}

///|
fn mooncode_stream_content_type(format : String) -> String {
  if format == "sse" {
    "text/event-stream; charset=utf-8"
  } else {
    "application/x-ndjson; charset=utf-8"
  }
}

///|
fn mooncode_native_stream_path(
  session_id : String,
  format : String,
  since : Int,
) -> String {
  "/v1/mooncode/sessions/\{session_id}/stream?format=\{format}&since=\{since}"
}

///|
async fn mooncode_native_stream_text(
  workspace_root : String,
  session_id : String,
  format : String,
  since : Int,
) -> Result[String, String] {
  let daemon = moonclaw_daemon_status(workspace_root)
  let running = json_bool(daemon, "running", default=false)
  if !running {
    return Err("MoonClaw daemon is not running")
  }
  if !mooncode_native_runtime_ready(daemon) {
    return Err("MoonClaw MoonCode runtime is not available")
  }
  moonclaw_get_text(
    daemon,
    mooncode_native_stream_path(session_id, format, since),
  )
}

///|
fn mooncode_command_action(payload : Json) -> String {
  @mooncode.command_action(payload)
}

///|
fn mooncode_command_is_supported(action : String) -> Bool {
  @mooncode.command_is_supported(action)
}

///|
fn mooncode_preflight_payload_from_request(request_path : String) -> Json {
  let action = match query_value(request_path, "action") {
    Some(value) => decode_query_value(value).trim().to_owned()
    None => "package"
  }
  let context_path = match query_value(request_path, "context_path") {
    Some(value) => decode_query_value(value).trim().to_owned()
    None =>
      match query_value(request_path, "path") {
        Some(value) => decode_query_value(value).trim().to_owned()
        None => ""
      }
  }
  { "action": action, "context_path": context_path }
}

///|
fn mooncode_command_preflight(
  session : Json,
  payload : Json,
  action : String,
) -> Json {
  let events = project_mooncode_events(session, [], [])
  let summary = @mooncode.session_summary(session, events)
  @mooncode.command_preflight(
    session_id=json_string(session, "id", default=""),
    action~,
    context_path=mooncode_command_context_path(payload),
    summary~,
    patch_entries=mooncode_patch_set_entries(events),
  )
}

///|
fn mooncode_command_preflight_blocked_event(
  preflight : Json,
  payload : Json,
  action : String,
  created_at : String,
) -> Json {
  let reason = json_string(
    preflight,
    "reason",
    default="MoonCode command is blocked by current review gates",
  )
  let target = mooncode_command_context_path(payload)
  @mooncode.command_preflight_blocked_event(
    preflight,
    action~,
    context_path=target,
    created_at~,
    event_id=@desk.stable_id(
      "mooncode-preflight-blocked",
      action + ":" + target + ":" + created_at + ":" + reason,
    ),
  )
}

///|
fn mooncode_command_preflight_override_event(
  preflight : Json,
  payload : Json,
  action : String,
  created_at : String,
) -> Json {
  let reason = json_string(
    preflight,
    "reason",
    default="MoonCode command preflight was overridden by the operator",
  )
  let target = mooncode_command_context_path(payload)
  @mooncode.command_preflight_override_event(
    preflight,
    action~,
    context_path=target,
    created_at~,
    event_id=@desk.stable_id(
      "mooncode-preflight-override",
      action + ":" + target + ":" + created_at + ":" + reason,
    ),
  )
}

///|
fn mooncode_command_preflight_has_patch_target(
  events : Array[Json],
  target : String,
) -> Bool {
  @mooncode.command_preflight_has_patch_target(
    mooncode_patch_set_entries(events),
    target,
  )
}

///|
fn mooncode_command_message(action : String, payload : Json) -> String {
  @mooncode.command_message(action, payload)
}

///|
fn mooncode_command_context_path(payload : Json) -> String {
  @mooncode.command_context_path(payload)
}

///|
fn mooncode_command_packet(
  session : Json,
  payload : Json,
  action : String,
  message : String,
  created_at : String,
  context_path : String,
) -> Json {
  let command_id = @desk.stable_id(
    "mooncode-command",
    action + ":" + created_at + ":" + context_path + ":" + message,
  )
  @mooncode.command_packet(
    session,
    payload,
    action,
    message,
    created_at,
    context_path,
    command_id~,
  )
}

///|
fn mooncode_runtime_command_record(
  session : Json,
  payload : Json,
  message : String,
  command_packet : Json,
) -> Json {
  @mooncode.runtime_command_record(session, payload, message, command_packet)
}

///|
fn mooncode_runtime_dispatch_receipt(
  session : Json,
  runtime_command : Json,
) -> Json {
  let command_id = json_string(runtime_command, "command_id", default="")
  let status = @mooncode.runtime_dispatch_status(session, runtime_command)
  let now = @async.now().to_string()
  @mooncode.runtime_dispatch_receipt(
    session,
    runtime_command,
    dispatch_id=@desk.stable_id(
      "mooncode-runtime-dispatch",
      command_id + ":" + status + ":" + now,
    ),
    created_at=now,
  )
}

///|
fn mooncode_runtime_dispatch_pending_count(
  commands : Array[Json],
  receipts : Array[Json],
) -> Int {
  @mooncode.runtime_dispatch_pending_count(
    commands,
    receipts,
    lease_now=@async.now().to_string(),
  )
}

///|
fn mooncode_runtime_pending_command_ids(
  commands : Array[Json],
  receipts : Array[Json],
) -> Array[Json] {
  @mooncode.runtime_pending_command_ids(
    commands,
    receipts,
    lease_now=@async.now().to_string(),
  )
}

///|
fn mooncode_runtime_command_lifecycle(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
) -> Json {
  @mooncode.runtime_command_lifecycle(
    session_id,
    commands,
    receipts,
    events,
    lease_now=@async.now().to_string(),
  )
}

///|
fn mooncode_runtime_replay_state(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  lease_now? : String = "",
) -> Json {
  @mooncode.runtime_replay_state(
    session_id,
    commands,
    receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now=if lease_now == "" { @async.now().to_string() } else { lease_now },
  )
}

///|
fn mooncode_runtime_serve_jsonl(
  commands : Array[Json],
  receipts : Array[Json],
  scope~ : String,
  lease_now? : String = "",
) -> String {
  @mooncode.runtime_serve_jsonl(commands, receipts, scope~, lease_now~)
}

///|
fn mooncode_serve_scheduler_projection(
  session_id : String,
  command_log : Array[Json],
  lifecycle : Json,
) -> Json {
  @mooncode.serve_scheduler_projection(session_id, command_log, lifecycle)
}

///|
fn mooncode_runtime_claim_state(
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
  runtime_command_log_path~ : String,
  runtime_dispatch_log_path~ : String,
  lease_now? : String = "",
) -> Json {
  @mooncode.runtime_claim_state(
    session_id,
    commands,
    receipts,
    workspace_id~,
    workspace_name~,
    task_id~,
    runtime_command_log_path~,
    runtime_dispatch_log_path~,
    lease_now=if lease_now == "" { @async.now().to_string() } else { lease_now },
  )
}

///|
fn mooncode_runtime_execution_plan(
  workspace_root : String,
  session : Json,
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  native_ready? : Bool = false,
  lease_now? : String = "",
) -> Json {
  let now = if lease_now == "" { @async.now().to_string() } else { lease_now }
  let replay = mooncode_runtime_replay_state(
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
    lease_now=now,
  )
  let claim = mooncode_runtime_claim_state(
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
    lease_now=now,
  )
  let plan = @mooncode.runtime_consumer_execution_plan(
    session_id, replay, claim, native_ready,
  )
  let lifecycle = mooncode_runtime_command_lifecycle(
    session_id,
    commands,
    receipts,
    [],
  )
  let scheduler = mooncode_serve_scheduler_projection(
    session_id, commands, lifecycle,
  )
  let turn_packet = @mooncode.runtime_turn_packet(
    session_id, replay, claim, scheduler, native_ready,
  )
  agent_session_with_field(
    agent_session_with_field(
      agent_session_with_field(plan, "serve_scheduler", scheduler),
      "runtime_turn_packet",
      turn_packet,
    ),
    "runtime_supervisor",
    @mooncode.runtime_supervisor_launch_packet(
      session_id,
      turn_packet,
      @mooncode.runtime_consumer_handoff(
        session_id, replay, claim, native_ready,
      ),
      workspace_root~,
      moonclaw_root="",
      host_base_url="",
      native_ready,
    ),
  )
}

///|
fn mooncode_runtime_supervisor_launch_packet(
  workspace_root : String,
  session : Json,
  session_id : String,
  commands : Array[Json],
  receipts : Array[Json],
  events : Array[Json],
  daemon : Json,
  native_ready? : Bool = false,
  lease_now? : String = "",
) -> Json {
  let now = if lease_now == "" { @async.now().to_string() } else { lease_now }
  let normalized_receipts = mooncode_runtime_dispatch_receipts_for_response(
    receipts,
  )
  let replay = mooncode_runtime_replay_state(
    session_id,
    commands,
    normalized_receipts,
    workspace_id=json_string(session, "workspace_id", default=""),
    workspace_name=json_string(session, "workspace_name", default=""),
    task_id=json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    lease_now=now,
  )
  let claim = mooncode_runtime_claim_state(
    session_id,
    commands,
    normalized_receipts,
    workspace_id=json_string(session, "workspace_id", default=""),
    workspace_name=json_string(session, "workspace_name", default=""),
    task_id=json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    lease_now=now,
  )
  let lifecycle = mooncode_runtime_command_lifecycle(
    session_id, commands, normalized_receipts, events,
  )
  let scheduler = mooncode_serve_scheduler_projection(
    session_id, commands, lifecycle,
  )
  let turn_packet = @mooncode.runtime_turn_packet(
    session_id, replay, claim, scheduler, native_ready,
  )
  @mooncode.runtime_supervisor_launch_packet(
    session_id,
    turn_packet,
    @mooncode.runtime_consumer_handoff(session_id, replay, claim, native_ready),
    workspace_root~,
    moonclaw_root=json_string(daemon, "moonclaw_root", default=""),
    host_base_url="",
    native_ready,
  )
}

///|
fn mooncode_runtime_replay_ack_receipts(
  session : Json,
  commands : Array[Json],
  payload : Json,
  dispatch_receipts? : Array[Json] = [],
  prior_events? : Array[Json] = [],
) -> Array[Json] {
  @mooncode.runtime_replay_ack_receipts(
    session,
    commands,
    mooncode_json_with_missing_string(
      payload,
      "acknowledged_at",
      @async.now().to_string(),
    ),
    dispatch_receipts~,
    prior_events~,
  )
}

///|
fn mooncode_runtime_replay_ack_normalized_events(
  receipts : Array[Json],
) -> Array[Json] {
  @mooncode.runtime_replay_ack_normalized_events(receipts)
}

///|
fn mooncode_runtime_claim_receipts(
  session : Json,
  commands : Array[Json],
  receipts : Array[Json],
  payload : Json,
) -> Array[Json] {
  let now = @async.now().to_string()
  @mooncode.runtime_claim_receipts(
    session,
    commands,
    receipts,
    mooncode_json_with_missing_string(
      mooncode_json_with_missing_string(payload, "now", now),
      "claimed_at",
      now,
    ),
  )
}

///|
fn mooncode_runtime_dispatch_receipts_for_response(
  receipts : Array[Json],
) -> Array[Json] {
  [
    for receipt in receipts => {
      mooncode_runtime_dispatch_receipt_for_response(receipt)
    }
  ]
}

///|
fn mooncode_runtime_dispatch_receipt_for_response(receipt : Json) -> Json {
  @mooncode.runtime_dispatch_receipt_for_response(
    receipt,
    fallback_dispatch_id=@desk.stable_id(
      "mooncode-runtime-dispatch",
      json_string(receipt, "command_id", default="") +
      ":" +
      json_string(receipt, "status", default="unknown"),
    ),
  )
}

///|
fn mooncode_json_with_missing_string(
  object : Json,
  field : String,
  value : String,
) -> Json {
  match json_object_field(object, field) {
    Some(_) => object
    None => agent_session_with_field(object, field, value.to_json())
  }
}

///|
fn mooncode_runtime_claim_consumer_contract_json(session_id : String) -> Json {
  @mooncode.runtime_claim_consumer_contract_json(session_id)
}

///|
fn mooncode_runtime_event_ingest_contract(session_id : String) -> Json {
  @mooncode.runtime_event_ingest_contract(session_id)
}

///|
fn mooncode_runtime_ingest_report(session_id : String, payload : Json) -> Json {
  let ingested_at = @async.now().to_string()
  let report = @mooncode.runtime_event_ingest_report(
    payload,
    session_id~,
    ingested_at~,
  )
  if json_int(report, "accepted_count", default=0) > 0 {
    return report
  }
  let legacy_events = mooncode_legacy_moonclaw_ingest_events(payload)
  if legacy_events.length() == 0 {
    return report
  }
  agent_session_with_field(
    agent_session_with_field(
      agent_session_with_field(
        agent_session_with_field(
          report,
          "status",
          "accepted-legacy-moonclaw".to_json(),
        ),
        "accepted_count",
        legacy_events.length().to_json(),
      ),
      "events",
      Json::array(legacy_events),
    ),
    "legacy_adapter",
    "moondesk.moonclaw.desc".to_json(),
  )
}

///|
fn mooncode_legacy_moonclaw_ingest_events(payload : Json) -> Array[Json] {
  let candidates = json_array_items(payload, "events")
  let incoming = if candidates.length() > 0 { candidates } else { [payload] }
  let events : Array[Json] = []
  for candidate in incoming {
    match mooncode_event_from_moonclaw_event(candidate) {
      Some(event) => events.push(event)
      None => ()
    }
  }
  events
}

///|
fn mooncode_command_runtime_message(
  message : String,
  command_packet : Json,
) -> String {
  @mooncode.command_runtime_message(message, command_packet)
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
  let events = json_array_items(session, "mooncode_command_events")
  let event_id = json_string(
    command_packet,
    "command_id",
    default=@desk.stable_id(
      "mooncode-command",
      action + ":" + status + ":" + created_at + ":" + detail,
    ),
  )
  events.push(
    @mooncode.command_event(
      action~,
      status~,
      detail~,
      created_at~,
      path~,
      command_packet~,
      event_id~,
    ),
  )
  let next = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(next, "updated_at", created_at.to_json())
}

///|
async fn write_mooncode_review_receipt_if_needed(
  session : Json,
  action : String,
  command_packet : Json,
  context_path : String,
  detail : String,
  command_created_at : String,
) -> Json? {
  if !mooncode_command_writes_review_receipt(action) {
    return None
  }
  let receipt = write_mooncode_review_receipt(
    session, action, command_packet, context_path, detail, command_created_at,
  )
  let receipt_path = json_string(receipt, "receipt_path", default="")
  let recorded_at = json_string(receipt, "recorded_at", default="")
  let event = mooncode_review_receipt_event(
    action, receipt_path, context_path, recorded_at, command_packet,
  )
  let events = json_array_items(session, "mooncode_command_events")
  events.push(event)
  let with_receipt_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  let with_receipt = agent_session_with_field(
    with_receipt_events, "mooncode_last_review_receipt", receipt,
  )
  let with_package = if action == "package" {
    write_mooncode_package_manifest_for_receipt(
      with_receipt, receipt, command_packet, context_path, detail, command_created_at,
    )
  } else {
    with_receipt
  }
  Some(
    agent_session_with_field(with_package, "updated_at", recorded_at.to_json()),
  )
}

///|
async fn write_mooncode_change_set_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_change_set_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_change_set_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_change_set_manifest", manifest,
  )
}

///|
async fn write_mooncode_patch_set_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_patch_set_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_patch_set_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_patch_set_manifest", manifest,
  )
}

///|
async fn write_mooncode_tool_approvals_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_tool_approvals_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_tool_approvals_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_tool_approvals_manifest", manifest,
  )
}

///|
async fn write_mooncode_test_runs_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_test_runs_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_test_runs_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_test_runs_manifest", manifest,
  )
}

///|
async fn write_mooncode_action_plan_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let manifest = write_mooncode_action_plan_manifest(workspace_root, session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_action_plan_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_action_plan_manifest", manifest,
  )
}

///|
async fn write_mooncode_runtime_evidence_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let manifest = write_mooncode_runtime_evidence_manifest(
    workspace_root, session,
  )
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_runtime_evidence_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_runtime_evidence_manifest", manifest,
  )
}

///|
async fn write_mooncode_eval_report_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_eval_report_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_eval_report_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  let with_manifest = agent_session_with_field(
    with_events, "mooncode_last_eval_report_manifest", manifest,
  )
  let refreshed_events = project_mooncode_events(with_manifest, [], [])
  let refreshed_summary = @mooncode.session_summary(
    with_manifest, refreshed_events,
  )
  agent_session_with_field(with_manifest, "mooncode_summary", refreshed_summary)
}

///|
async fn write_mooncode_runtime_handoff_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let manifest = write_mooncode_runtime_handoff_manifest(
    workspace_root, session,
  )
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_runtime_handoff_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_runtime_handoff_manifest", manifest,
  )
}

///|
fn mooncode_session_with_saved_eval_manifest(
  session : Json,
  manifest : Json,
) -> Json {
  let with_manifest = agent_session_with_field(
    session, "mooncode_last_eval_report_manifest", manifest,
  )
  let native_report = json_object_field_or_empty(manifest, "native_eval_report")
  if json_bool(native_report, "ok", default=false) &&
    !json_bool(
      json_object_field_or_empty(session, "mooncode_native_eval_report"),
      "ok",
      default=false,
    ) {
    agent_session_with_field(
      with_manifest, "mooncode_native_eval_report", native_report,
    )
  } else {
    with_manifest
  }
}

///|
async fn write_mooncode_change_set_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode change set needs a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = mooncode_change_set_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.change_set_manifest(
    session,
    events,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_patch_set_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode patch set needs a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = mooncode_patch_set_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.patch_set_manifest(
    session,
    events,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_tool_approvals_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode tool approvals need a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = mooncode_tool_approvals_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.tool_approvals_manifest(
    session,
    events,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_test_runs_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode test runs need a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = mooncode_test_runs_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.test_runs_manifest(
    session,
    events,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_action_plan_manifest(
  workspace_root : String,
  session : Json,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode action plan needs a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = mooncode_action_plan_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let manifest = agent_session_with_field(
    agent_session_with_field(
      mooncode_action_plan_projection(workspace_root, session),
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
async fn write_mooncode_runtime_evidence_manifest(
  workspace_root : String,
  session : Json,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode runtime evidence needs a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = mooncode_runtime_evidence_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let manifest = agent_session_with_field(
    agent_session_with_field(
      mooncode_session_runtime_evidence_projection(workspace_root, session),
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
  let pending_runtime_count = mooncode_action_plan_state_count(
      actions, "queued-for-runtime",
    ) +
    mooncode_action_plan_state_count(actions, "runtime-retry")
  let running_count = mooncode_action_plan_state_count(actions, "running")
  let blocked_count = mooncode_action_plan_state_count(actions, "blocked")
  let ready_for_review_count = mooncode_action_plan_state_count(
    actions, "ready-for-review",
  )
  let completed_count = mooncode_action_plan_state_count(actions, "completed")
  let summary = @mooncode.session_summary(session, events)
  {
    "kind": "mooncode-action-plan",
    "protocol": "mooncode.v1",
    "status": mooncode_action_plan_status(
      pending_runtime_count,
      running_count,
      blocked_count,
      ready_for_review_count,
      completed_count,
      actions.length(),
    ),
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": @async.now().to_string(),
    "manifest_path": "",
    "absolute_manifest_path": "",
    "action_count": actions.length(),
    "pending_runtime_count": pending_runtime_count,
    "running_count": running_count,
    "blocked_count": blocked_count,
    "ready_for_review_count": ready_for_review_count,
    "completed_count": completed_count,
    "run_test_command_count": mooncode_action_plan_command_count(
      actions, "run_tests",
    ),
    "package_command_count": mooncode_action_plan_command_count(
      actions, "package",
    ),
    "commit_command_count": mooncode_action_plan_command_count(
      actions, "commit",
    ),
    "accept_command_count": mooncode_action_plan_command_count(
      actions, "accept",
    ),
    "review_command_count": mooncode_action_plan_review_count(actions),
    "verified_test_count": json_int(summary, "verified_test_count", default=0),
    "failed_test_count": json_int(summary, "failed_test_count", default=0),
    "pending_diff_count": json_int(summary, "pending_diff_count", default=0),
    "pending_tool_approval_count": json_int(
      summary,
      "pending_tool_approval_count",
      default=0,
    ),
    "source_bound_package_count": json_int(
      summary,
      "source_bound_package_count",
      default=0,
    ),
    "next_required_action": mooncode_action_plan_next_required_action(
      summary, actions,
    ),
    "actions": Json::array(actions),
    "runtime_replay": mooncode_runtime_replay_state(
      session_id,
      runtime_commands,
      runtime_dispatches,
      workspace_id=json_string(session, "workspace_id", default=""),
      workspace_name=json_string(session, "workspace_name", default=""),
      task_id=json_string(session, "moonclaw_task_id", default=""),
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
    ),
    "acceptance_gates": mooncode_action_plan_acceptance_gates(summary),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "extractable_component": "mooncode",
    },
    "rule": "This plan is Moondesk's compact execution/review contract. MoonClaw or standalone MoonCode consumes the command queue, emits proof events, then Moondesk updates this plan without executing tools itself.",
  }
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
              mooncode_runtime_evidence_manifest_relative_path(session_id)
            }).to_json(),
          ),
          "absolute_manifest_path",
          (if session_id == "" {
            ""
          } else {
            @pathx.join(
              workspace_root,
              mooncode_runtime_evidence_manifest_relative_path(session_id),
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
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = mooncode_eval_report_manifest_relative_path(session_id)
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
  let normalized_runtime_dispatches = mooncode_runtime_dispatch_receipts_for_response(
    runtime_dispatches,
  )
  let session_id = json_string(session, "id", default="")
  let snapshot = @mooncode.session_snapshot(
    session,
    events,
    commands,
    runtime_commands,
    normalized_runtime_dispatches,
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
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = mooncode_runtime_handoff_manifest_relative_path(session_id)
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
  let normalized_runtime_dispatches = mooncode_runtime_dispatch_receipts_for_response(
    runtime_dispatches,
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
    normalized_runtime_dispatches,
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
    normalized_runtime_dispatches,
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
    normalized_runtime_dispatches,
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
fn mooncode_change_set_manifest_relative_path(session_id : String) -> String {
  @mooncode.change_set_manifest_relative_path(session_id)
}

///|
fn mooncode_patch_set_manifest_relative_path(session_id : String) -> String {
  @mooncode.patch_set_manifest_relative_path(session_id)
}

///|
fn mooncode_tool_approvals_manifest_relative_path(
  session_id : String,
) -> String {
  @mooncode.tool_approvals_manifest_relative_path(session_id)
}

///|
fn mooncode_test_runs_manifest_relative_path(session_id : String) -> String {
  @mooncode.test_runs_manifest_relative_path(session_id)
}

///|
fn mooncode_action_plan_manifest_relative_path(session_id : String) -> String {
  @mooncode.action_plan_manifest_relative_path(session_id)
}

///|
fn mooncode_runtime_evidence_manifest_relative_path(
  session_id : String,
) -> String {
  @mooncode.runtime_evidence_manifest_relative_path(session_id)
}

///|
fn mooncode_eval_report_manifest_relative_path(session_id : String) -> String {
  @mooncode.eval_report_manifest_relative_path(session_id)
}

///|
fn mooncode_runtime_handoff_manifest_relative_path(
  session_id : String,
) -> String {
  @mooncode.runtime_handoff_manifest_relative_path(session_id)
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
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    mooncode_change_set_manifest_relative_path(session_id),
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
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    mooncode_patch_set_manifest_relative_path(session_id),
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
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    mooncode_tool_approvals_manifest_relative_path(session_id),
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
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    mooncode_test_runs_manifest_relative_path(session_id),
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
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    mooncode_eval_report_manifest_relative_path(session_id),
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
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    mooncode_runtime_handoff_manifest_relative_path(session_id),
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
fn mooncode_runtime_handoff_manifest_current(manifest : Json) -> Bool {
  let contract = json_object_field_or_empty(manifest, "resume_contract")
  let runtime_consumer = json_object_field_or_empty(
    manifest, "runtime_consumer",
  )
  let runtime_consumer_endpoints = json_object_field_or_empty(
    runtime_consumer, "endpoints",
  )
  json_string(contract, "runtime_command_feed_endpoint", default="") != "" &&
  json_string(contract, "runtime_command_log_path", default="") != "" &&
  json_string(contract, "runtime_claim_endpoint", default="") != "" &&
  json_string(contract, "runtime_dispatch_endpoint", default="") != "" &&
  json_string(contract, "runtime_dispatch_log_path", default="") != "" &&
  json_string(contract, "runtime_event_ingest_endpoint", default="") != "" &&
  json_string(contract, "runtime_replay_endpoint", default="") != "" &&
  json_string(contract, "action_plan_endpoint", default="") != "" &&
  json_string(runtime_consumer, "status", default="") != "" &&
  json_string(runtime_consumer, "next_action", default="") != "" &&
  json_string(runtime_consumer_endpoints, "runtime_claim", default="") != "" &&
  json_string(runtime_consumer_endpoints, "runtime_replay", default="") != ""
}

///|
fn mooncode_patch_set_entries(events : Array[Json]) -> Array[Json] {
  let entries : Array[Json] = []
  let seen : Map[String, Bool] = {}
  for event in events {
    if json_string(event, "lane", default="") != "diff" {
      continue
    }
    let path = json_string(event, "path", default="")
    let id = if path == "" {
      json_string(
        event,
        "id",
        default=@desk.stable_id("patch", event.stringify()),
      )
    } else {
      path
    }
    if seen.get(id).unwrap_or(false) {
      continue
    }
    seen[id] = true
    entries.push(mooncode_patch_set_event_entry(event, events))
  }
  entries
}

///|
fn mooncode_patch_set_event_entry(event : Json, events : Array[Json]) -> Json {
  let path = json_string(event, "path", default="")
  let diff = json_string(event, "diff", default="")
  let packet = json_object_field_or_empty(event, "command_packet")
  let review_state = mooncode_patch_review_state_for_path(path, events)
  let hunks = mooncode_patch_hunks(path, diff, events)
  {
    "id": json_string(event, "id", default=""),
    "path": path,
    "title": json_string(event, "title", default=""),
    "status": json_string(event, "status", default=""),
    "review_state": review_state,
    "created_at": json_string(event, "created_at", default=""),
    "detail": json_string(event, "detail", default=""),
    "diff": diff,
    "diff_present": diff != "",
    "hunks": Json::array(hunks),
    "hunk_count": hunks.length(),
    "command": json_string(event, "command", default=""),
    "command_id": json_string(packet, "command_id", default=""),
    "accepted_review_count": mooncode_patch_review_event_count(
      path, "accept", events,
    ),
    "rejected_review_count": mooncode_patch_review_event_count(
      path, "reject", events,
    ),
    "applied_review_count": mooncode_patch_review_event_count(
      path, "apply_patch", events,
    ),
    "reverted_review_count": mooncode_patch_review_event_count(
      path, "revert_patch", events,
    ),
    "package_review_count": mooncode_patch_review_event_count(
      path, "package", events,
    ),
  }
}

///|
fn mooncode_patch_hunks(
  path : String,
  diff : String,
  events : Array[Json],
) -> Array[Json] {
  let hunks : Array[Json] = []
  if diff == "" {
    return hunks
  }
  let lines : Array[String] = diff
    .split("\n")
    .map(line => line.to_owned())
    .collect()
  let mut current_header = ""
  let current_lines : Array[String] = []
  let mut hunk_index = 0
  let flush = fn() {
    if current_header != "" || current_lines.length() > 0 {
      hunk_index += 1
      hunks.push(
        mooncode_patch_hunk_record(
          path, hunk_index, current_header, current_lines, events,
        ),
      )
      current_lines.clear()
      current_header = ""
    }
  }
  for line in lines {
    if line.has_prefix("@@") {
      flush()
      current_header = line
    } else if current_header != "" ||
      line.has_prefix("+") ||
      line.has_prefix("-") ||
      line.has_prefix(" ") {
      current_lines.push(line)
    }
  }
  flush()
  if hunks.length() == 0 {
    hunks.push(mooncode_patch_hunk_record(path, 1, "synthetic", lines, events))
  }
  hunks
}

///|
fn mooncode_patch_hunk_record(
  path : String,
  index : Int,
  header : String,
  lines : Array[String],
  events : Array[Json],
) -> Json {
  let mut added = 0
  let mut removed = 0
  let mut context = 0
  for line in lines {
    if line.has_prefix("+") && !line.has_prefix("+++") {
      added += 1
    } else if line.has_prefix("-") && !line.has_prefix("---") {
      removed += 1
    } else {
      context += 1
    }
  }
  let hunk_id = "hunk-\{index}"
  let target = mooncode_patch_hunk_target(path, hunk_id)
  {
    "id": hunk_id,
    "index": index,
    "target": target,
    "header": header,
    "review_state": mooncode_patch_review_state_for_path(target, events),
    "added_lines": added,
    "removed_lines": removed,
    "context_lines": context,
    "line_count": lines.length(),
    "preview": trim_for_record(lines.join("\n")),
    "accepted_review_count": mooncode_patch_review_event_count(
      target, "accept", events,
    ),
    "rejected_review_count": mooncode_patch_review_event_count(
      target, "reject", events,
    ),
    "applied_review_count": mooncode_patch_review_event_count(
      target, "apply_patch", events,
    ),
    "reverted_review_count": mooncode_patch_review_event_count(
      target, "revert_patch", events,
    ),
  }
}

///|
fn mooncode_patch_hunk_target(path : String, hunk_id : String) -> String {
  if path == "" {
    hunk_id
  } else {
    path + "#" + hunk_id
  }
}

///|
fn mooncode_patch_review_state_for_path(
  path : String,
  events : Array[Json],
) -> String {
  if mooncode_patch_review_event_count(path, "revert_patch", events) > 0 {
    "reverted"
  } else if mooncode_patch_review_event_count(path, "apply_patch", events) > 0 {
    "applied"
  } else if mooncode_patch_review_event_count(path, "reject", events) > 0 {
    "rejected"
  } else if mooncode_patch_review_event_count(path, "accept", events) > 0 {
    "accepted"
  } else {
    "pending"
  }
}

///|
fn mooncode_patch_review_event_count(
  path : String,
  command : String,
  events : Array[Json],
) -> Int {
  let mut count = 0
  for event in events {
    if json_string(event, "lane", default="") != "review" ||
      json_string(event, "command", default="") != command ||
      json_string(event, "status", default="") == "failed" {
      continue
    }
    let event_path = json_string(event, "path", default="")
    if mooncode_patch_review_target_matches(path, event_path) {
      count += 1
    }
  }
  count
}

///|
fn mooncode_patch_review_target_matches(
  target : String,
  event_path : String,
) -> Bool {
  target == "" ||
  event_path == "" ||
  event_path == target ||
  event_path == mooncode_patch_review_parent_target(target) ||
  event_path.has_prefix(target + "#hunk-")
}

///|
fn mooncode_patch_review_parent_target(target : String) -> String {
  if !target.contains("#hunk-") {
    return target
  }
  let parts : Array[String] = target
    .split("#hunk-")
    .map(part => part.to_owned())
    .collect()
  if parts.length() == 0 {
    target
  } else {
    parts[0]
  }
}

///|
fn mooncode_count_patch_review_state(
  patches : Array[Json],
  state : String,
) -> Int {
  let mut count = 0
  for patch in patches {
    if json_string(patch, "review_state", default="") == state {
      count += 1
    }
  }
  count
}

///|
fn mooncode_tool_approval_entries(events : Array[Json]) -> Array[Json] {
  @mooncode.tool_approval_entries(events)
}

///|
fn mooncode_tool_authorization_contract(
  session_id : String,
  manifest : Json,
) -> Json {
  @mooncode.tool_authorization_contract(session_id, manifest)
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
fn mooncode_tool_authorization_has_target(
  events : Array[Json],
  target : String,
) -> Bool {
  @mooncode.tool_authorization_has_target(events, target)
}

///|
fn mooncode_tool_event_approval(event : Json) -> String {
  @mooncode.tool_event_approval(event)
}

///|
fn mooncode_tool_approval_target(event : Json) -> String {
  @mooncode.tool_approval_target(event)
}

///|
fn mooncode_count_tool_approval_state(
  approvals : Array[Json],
  state : String,
) -> Int {
  @mooncode.count_tool_approval_state(approvals, state)
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
fn mooncode_action_plan_runtime_state_at(
  command_id : String,
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  lease_now~ : String,
) -> String {
  @mooncode.action_plan_runtime_state_at(
    command_id,
    runtime_commands,
    runtime_dispatches,
    lease_now~,
  )
}

///|
fn mooncode_action_plan_item_state(
  action : String,
  runtime_state : String,
  summary : Json,
) -> String {
  @mooncode.action_plan_item_state(action, runtime_state, summary)
}

///|
fn mooncode_action_plan_status(
  pending_runtime_count : Int,
  running_count : Int,
  blocked_count : Int,
  ready_for_review_count : Int,
  completed_count : Int,
  action_count : Int,
) -> String {
  @mooncode.action_plan_status(
    pending_runtime_count, running_count, blocked_count, ready_for_review_count,
    completed_count, action_count,
  )
}

///|
fn mooncode_action_plan_state_count(
  actions : Array[Json],
  state : String,
) -> Int {
  @mooncode.action_plan_state_count(actions, state)
}

///|
fn mooncode_action_plan_command_count(
  actions : Array[Json],
  command : String,
) -> Int {
  @mooncode.action_plan_command_count(actions, command)
}

///|
fn mooncode_action_plan_review_count(actions : Array[Json]) -> Int {
  @mooncode.action_plan_review_count(actions)
}

///|
fn mooncode_action_plan_next_required_action(
  summary : Json,
  actions : Array[Json],
) -> String {
  @mooncode.action_plan_next_required_action(summary, actions)
}

///|
fn mooncode_action_plan_acceptance_gates(summary : Json) -> Json {
  @mooncode.command_acceptance_gates(summary)
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
fn mooncode_command_writes_review_receipt(action : String) -> Bool {
  action == "accept" ||
  action == "reject" ||
  action == "package" ||
  action == "commit" ||
  action == "approve_tool" ||
  action == "reject_tool" ||
  action == "apply_patch" ||
  action == "revert_patch"
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
  let session_id = mooncode_safe_receipt_id(
    json_string(
      session,
      "id",
      default=json_string(command_packet, "session_id", default=""),
    ),
    fallback="session",
  )
  let command_id = mooncode_safe_receipt_id(
    json_string(command_packet, "command_id", default="command"),
    fallback="command",
  )
  let relative = mooncode_review_receipt_relative_path(
    session_id, command_id, action,
  )
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let recorded_at = @async.now().to_string()
  let receipt : Json = {
    "kind": "mooncode-review-receipt",
    "protocol": "mooncode.v1",
    "status": "recorded",
    "action": action,
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "context_path": context_path,
    "command_id": command_id,
    "command_created_at": command_created_at,
    "recorded_at": recorded_at,
    "receipt_path": relative,
    "absolute_receipt_path": absolute,
    "detail": detail,
    "command_packet": command_packet,
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "review": "moonbook",
      "extractable_component": "mooncode",
    },
  }
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
  let session_id = mooncode_safe_receipt_id(
    json_string(
      session,
      "id",
      default=json_string(command_packet, "session_id", default=""),
    ),
    fallback="session",
  )
  let command_id = mooncode_safe_receipt_id(
    json_string(command_packet, "command_id", default="command"),
    fallback="command",
  )
  let relative = mooncode_package_manifest_relative_path(session_id, command_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let recorded_at = @async.now().to_string()
  let candidate_paths = @mooncode.package_candidate_paths(context_path)
  let source_inventory = mooncode_package_source_inventory(
    book_root, candidate_paths,
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
fn mooncode_package_manifest_relative_path(
  session_id : String,
  command_id : String,
) -> String {
  @mooncode.package_manifest_relative_path(session_id, command_id)
}

///|
fn mooncode_package_index_manifest_relative_path(session_id : String) -> String {
  @mooncode.package_index_manifest_relative_path(session_id)
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
  let relative = mooncode_package_index_manifest_relative_path(session_id)
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
) -> Array[Json] {
  let records : Array[Json] = []
  for candidate in candidate_paths {
    records.push(mooncode_package_source_record(book_root, candidate))
  }
  records
}

///|
async fn mooncode_package_source_record(
  book_root : String,
  candidate : String,
) -> Json {
  match resolve_workspace_path(book_root, candidate) {
    Some((absolute, relative)) =>
      if !@fs.exists(absolute) {
        {
          "path": relative,
          "exists": false,
          "kind": "missing",
          "package_ready": false,
        }
      } else {
        let kind = @fs.kind(absolute) catch {
          _ =>
            return {
              "path": relative,
              "exists": true,
              "kind": "unknown",
              "package_ready": false,
            }
        }
        match kind {
          @fs.FileKind::Directory =>
            {
              "path": relative,
              "exists": true,
              "kind": "directory",
              "package_ready": true,
            }
          _ => mooncode_package_file_record(absolute, relative)
        }
      }
    None =>
      {
        "path": candidate,
        "exists": false,
        "kind": "invalid",
        "package_ready": false,
      }
  }
}

///|
async fn mooncode_package_file_record(
  absolute : String,
  relative : String,
) -> Json {
  let bytes = @fs.read_file(absolute).binary() catch {
    _ =>
      return {
        "path": relative,
        "exists": true,
        "kind": "file",
        "package_ready": false,
      }
  }
  {
    "path": relative,
    "exists": true,
    "kind": "file",
    "size_bytes": bytes.length(),
    "sha256": @crypto.bytes_to_hex_string(@crypto.sha256(bytes.to_fixedarray())),
    "package_ready": true,
  }
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
    mooncode_package_index_manifest_relative_path(session_id),
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
    let safe_session = mooncode_safe_receipt_id(session_id, fallback="session")
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
fn mooncode_review_receipt_relative_path(
  session_id : String,
  command_id : String,
  action : String,
) -> String {
  @mooncode.review_receipt_relative_path(session_id, command_id, action)
}

///|
fn mooncode_safe_receipt_id(value : String, fallback~ : String) -> String {
  @mooncode.artifact_safe_id(value, fallback~)
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
  let runtime_message = mooncode_command_runtime_message(
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
  let endpoint = "/v1/mooncode/sessions/\{session_id}/eval-report"
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
      "/v1/mooncode/sessions/\{session_id}/commands",
      body,
    ) {
    Ok(response) => response
    Err(error) => return Err(error)
  }
  let queue_accepted = json_bool(queue_response, "accepted", default=true)
  let turn_response = if queue_accepted {
    moonclaw_post_json(
      daemon,
      "/v1/mooncode/sessions/\{session_id}/runtime-turn",
      {
        "protocol": "mooncode.v1",
        "session_id": session_id,
        "book_root": json_string(body, "book_root", default=""),
        "consumer_id": "moondesk-native-runtime-turn",
      },
    )
  } else {
    Err(
      json_string(
        queue_response,
        "message",
        default="MoonClaw rejected native MoonCode queueing",
      ),
    )
  }
  let turn_payload = match turn_response {
    Ok(payload) => payload
    Err(_) => Json::object({})
  }
  let turn_accepted = json_bool(turn_payload, "accepted", default=false)
  let status = if !queue_accepted {
    "failed"
  } else if turn_response is Err(_) {
    "failed"
  } else if turn_accepted {
    "done"
  } else {
    "failed"
  }
  let detail = json_string(
    turn_payload,
    "message",
    default=match turn_response {
      Ok(_) =>
        json_string(
          queue_response,
          "message",
          default="MoonClaw MoonCode runtime accepted \{json_string(command_packet, "action", default="command")}",
        )
      Err(error) => "MoonClaw queued command but runtime-turn failed: \{error}"
    },
  )
  let with_status = append_agent_message(
    mooncode_append_native_response_events(
      mooncode_append_native_response_events(session, queue_response),
      turn_payload,
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
        if turn_accepted {
          "moonclaw-mooncode-runtime-turn".to_json()
        } else {
          "moonclaw-mooncode-runtime".to_json()
        },
      ),
      "updated_at",
      @async.now().to_string().to_json(),
    ),
  )
}

///|
fn mooncode_runtime_command_execution_summary(command : Json) -> Json {
  match json_object_field(command, "execution_summary") {
    Some(summary) => summary
    None =>
      @mooncode.native_command_execution_summary(
        json_object_field_or_empty(command, "command_packet"),
        json_object_field_or_empty(command, "native_mooncode_body"),
      )
  }
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
  let incoming = mooncode_native_response_event_items(response)
  if incoming.length() == 0 {
    return session
  }
  let events = json_array_items(session, "mooncode_command_events")
  let seen : Map[String, Bool] = {}
  for event in events {
    let id = json_string(event, "id", default="")
    if id != "" {
      seen[id] = true
    }
  }
  for event in incoming {
    let id = json_string(event, "id", default="")
    if id != "" && !seen.contains(id) {
      events.push(event)
      seen[id] = true
    }
  }
  agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
}

///|
fn mooncode_native_response_event_items(response : Json) -> Array[Json] {
  let incoming = json_array_items(response, "events")
  let execution = json_object_field_or_empty(response, "execution")
  for event in json_array_items(execution, "events") {
    incoming.push(event)
  }
  let turn_receipt = json_object_field_or_empty(response, "turn_receipt")
  for event in json_array_items(turn_receipt, "events") {
    incoming.push(event)
  }
  incoming
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
  let role = json_string(message, "role", default="status")
  let lane = match role {
    "assistant" | "user" => "transcript"
    "tool" => "tool"
    _ => "runtime"
  }
  mooncode_event_record(
    id=json_string(
      message,
      "id",
      default=@desk.stable_id("mooncode-message", message.stringify()),
    ),
    lane~,
    kind=role,
    title=mooncode_title_for_role(role),
    status=json_string(message, "status", default="done"),
    created_at=json_string(message, "created_at", default=""),
    detail=json_string(message, "content", default=""),
  )
}

///|
fn mooncode_title_for_role(role : String) -> String {
  match role {
    "user" => "User prompt"
    "assistant" => "Assistant response"
    "tool" => "Tool result"
    _ => "Runtime status"
  }
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
  let msg = json_string(desc, "msg", default="")
  let event_id = json_field_text(
    event,
    "id",
    default=@desk.stable_id("mooncode-event", desc.stringify()),
  )
  let created_at = json_field_text(event, "created", default=event_id)
  match msg {
    "UserMessage" =>
      Some(
        mooncode_event_record(
          id=event_id,
          lane="transcript",
          kind="user",
          title="User prompt",
          status="done",
          created_at~,
          detail=json_string(desc, "content", default=""),
        ),
      )
    "AssistantMessage" =>
      Some(
        mooncode_event_record(
          id=event_id,
          lane="transcript",
          kind="assistant",
          title="Assistant response",
          status="done",
          created_at~,
          detail=json_string(desc, "content", default=""),
        ),
      )
    "RequestCompleted" =>
      Some(
        mooncode_event_record(
          id=event_id,
          lane="transcript",
          kind="assistant",
          title="Assistant response",
          status="done",
          created_at~,
          detail=match json_object_field(desc, "message") {
            Some(message) => openai_message_content_text(message)
            None => ""
          },
        ),
      )
    "PreToolCall" => {
      let name = mooncode_tool_name(desc)
      Some(
        mooncode_event_record(
          id=event_id,
          lane="tool",
          kind="tool_call",
          title="Tool started: \{name}",
          status="running",
          created_at~,
          detail=mooncode_tool_arguments(desc),
          command=mooncode_tool_command(desc),
          path=mooncode_tool_path(desc),
        ),
      )
    }
    "PostToolCall" => Some(mooncode_post_tool_event(event_id, created_at, desc))
    "MessageQueued"
    | "MessageUnqueued"
    | "PreConversation"
    | "PostConversation"
    | "ModelLoaded"
    | "TokenCounted"
    | "ContextPruned"
    | "Failed"
    | "Cancelled" =>
      Some(mooncode_runtime_event(event_id, created_at, msg, desc))
    _ => None
  }
}

///|
fn mooncode_runtime_event(
  id : String,
  created_at : String,
  msg : String,
  desc : Json,
) -> Json {
  let status = match msg {
    "Failed" => "failed"
    "Cancelled" => "cancelled"
    "PostConversation" => "done"
    _ => "running"
  }
  let title = match msg {
    "ModelLoaded" =>
      "Model loaded: \{json_string(desc, "name", default="default")}"
    "TokenCounted" =>
      "Context measured: \{json_int(desc, "token_count", default=0)} tokens"
    "ContextPruned" => "Context pruned"
    "Failed" => "MoonClaw failed"
    "Cancelled" => "MoonClaw cancelled"
    "PostConversation" => "Conversation finished"
    "MessageQueued" => "Message queued"
    "MessageUnqueued" => "Message started"
    _ => "Runtime: \{msg}"
  }
  mooncode_event_record(
    id~,
    lane="runtime",
    kind=msg,
    title~,
    status~,
    created_at~,
    detail=if msg == "Failed" {
      json_field_text(desc, "error", default="")
    } else {
      desc.stringify()
    },
  )
}

///|
fn mooncode_post_tool_event(
  id : String,
  created_at : String,
  desc : Json,
) -> Json {
  let name = mooncode_tool_name(desc)
  let path = mooncode_tool_path(desc)
  let diff = mooncode_tool_diff(desc)
  let command = mooncode_tool_command(desc)
  let exit_code = mooncode_tool_exit_code(desc)
  let status = if json_object_field(desc, "error") is Some(_) || exit_code > 0 {
    "failed"
  } else {
    "done"
  }
  let lane = mooncode_tool_lane(
    name,
    path,
    diff,
    command,
    mooncode_tool_text(desc),
  )
  let title = match lane {
    "diff" => "File changed: \{mooncode_label(path)}"
    "test" => "Test/build command: \{mooncode_label(command)}"
    "artifact" => "Artifact packaged: \{mooncode_label(path)}"
    _ => "Tool finished: \{name}"
  }
  mooncode_event_record(
    id~,
    lane~,
    kind=name,
    title~,
    status~,
    created_at~,
    detail=mooncode_tool_text(desc),
    path~,
    diff~,
    command~,
    exit_code~,
  )
}

///|
fn mooncode_tool_lane(
  name : String,
  path : String,
  diff : String,
  command : String,
  text : String,
) -> String {
  @mooncode.tool_lane(name, path, diff, command, text)
}

///|
fn mooncode_tool_name(desc : Json) -> String {
  let direct = json_string(desc, "name", default="")
  if direct != "" {
    return direct
  }
  let tool_call = mooncode_tool_call(desc)
  let function = match json_object_field(tool_call, "function") {
    Some(function) => function
    None => Json::object({})
  }
  json_string(function, "name", default="tool")
}

///|
fn mooncode_tool_arguments(desc : Json) -> String {
  let tool_call = mooncode_tool_call(desc)
  let function = match json_object_field(tool_call, "function") {
    Some(function) => function
    None => Json::object({})
  }
  json_string(function, "arguments", default="")
}

///|
fn mooncode_label(value : String) -> String {
  @mooncode.event_label(value)
}

///|
fn mooncode_tool_call(desc : Json) -> Json {
  match json_object_field(desc, "tool_call") {
    Some(tool_call) => tool_call
    None => Json::object({})
  }
}

///|
fn mooncode_tool_result(desc : Json) -> Json {
  match json_object_field(desc, "result") {
    Some(result) => result
    None => Json::object({})
  }
}

///|
fn mooncode_tool_result_object(desc : Json) -> Json {
  match mooncode_tool_result(desc) {
    Json::Object(_) as object => object
    Json::Array(items) =>
      if items.length() > 1 {
        items[1]
      } else {
        Json::object({})
      }
    _ => Json::object({})
  }
}

///|
fn mooncode_tool_path(desc : Json) -> String {
  let result = mooncode_tool_result_object(desc)
  let path = json_first_string(result, ["path", "file", "target"], default="")
  if path != "" {
    return path
  }
  let args = @json.parse(mooncode_tool_arguments(desc)) catch {
    _ => Json::object({})
  }
  json_first_string(args, ["path", "file", "target"], default="")
}

///|
fn mooncode_tool_diff(desc : Json) -> String {
  let result = mooncode_tool_result_object(desc)
  let diff = json_string(result, "diff", default="")
  if diff != "" {
    diff
  } else {
    let text = mooncode_tool_text(desc)
    if text.contains("\n+") || text.contains("\n-") {
      text
    } else {
      ""
    }
  }
}

///|
fn mooncode_tool_command(desc : Json) -> String {
  let result = mooncode_tool_result_object(desc)
  let command = json_string(result, "command", default="")
  if command != "" {
    return command
  }
  let args = @json.parse(mooncode_tool_arguments(desc)) catch {
    _ => Json::object({})
  }
  json_first_string(args, ["command", "cmd"], default="")
}

///|
fn mooncode_tool_exit_code(desc : Json) -> Int {
  json_int(mooncode_tool_result_object(desc), "status", default=0)
}

///|
fn mooncode_tool_text(desc : Json) -> String {
  let text = json_string(
    desc,
    "text",
    default=json_string(desc, "rendered", default=""),
  )
  if text != "" {
    return trim_for_record(text)
  }
  let result = mooncode_tool_result_object(desc)
  let stdout = json_string(result, "stdout", default="")
  let stderr = json_string(result, "stderr", default="")
  trim_for_record([stdout, stderr].join("\n"))
}

///|
fn mooncode_event_record(
  id~ : String,
  lane~ : String,
  kind~ : String,
  title~ : String,
  status~ : String,
  created_at~ : String,
  detail~ : String,
  path? : String = "",
  diff? : String = "",
  command? : String = "",
  exit_code? : Int = 0,
  command_packet? : Json = Json::object({}),
) -> Json {
  @mooncode.event_record(
    id~,
    lane~,
    kind~,
    title~,
    status~,
    created_at~,
    detail~,
    path~,
    diff~,
    command~,
    exit_code~,
    command_packet~,
  )
}

///|
fn mooncode_session_summary(session : Json, events : Array[Json]) -> Json {
  @mooncode.session_summary(session, events)
}

///|
fn mooncode_eval_report_projection(session : Json) -> Json {
  @mooncode.eval_report_projection(session)
}

///|
test "mooncode projects file write and test lanes" {
  let raw_events : Array[Json] = [
    {
      "id": "write",
      "created": "1",
      "desc": {
        "msg": "PostToolCall",
        "tool_call": {
          "function": {
            "name": "meta_write_to_file",
            "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
          },
        },
        "result": {
          "path": "tools/demo/main.mbt",
          "diff": "+fn main { println(\"ok\") }",
        },
      },
    },
    {
      "id": "test",
      "created": "2",
      "desc": {
        "msg": "PostToolCall",
        "tool_call": {
          "function": {
            "name": "execute_command",
            "arguments": "{\"command\":\"moon test\"}",
          },
        },
        "result": [
          "Completed",
          {
            "command": "moon test",
            "status": 0,
            "stdout": "Total tests: 1, passed: 1",
            "stderr": "",
          },
        ],
      },
    },
  ]
  let events = project_mooncode_events(Json::object({}), raw_events, [])
  assert_eq(json_string(events[0], "lane", default=""), "diff")
  assert_eq(json_string(events[0], "path", default=""), "tools/demo/main.mbt")
  assert_eq(json_string(events[1], "lane", default=""), "test")
  assert_eq(json_string(events[1], "command", default=""), "moon test")
  let summary = @mooncode.session_summary({ "id": "s1" }, events)
  assert_eq(json_int(summary, "diff_count", default=0), 1)
  assert_eq(json_int(summary, "test_count", default=0), 1)
  assert_eq(json_int(summary, "verified_test_count", default=0), 1)
  assert_eq(json_int(summary, "failed_test_count", default=0), 0)
}

///|
test "mooncode marks portable app tool outputs as artifacts" {
  let event = mooncode_post_tool_event("artifact", "1", {
    "msg": "PostToolCall",
    "name": "package_app_tool",
    "result": { "path": "portable/app-tool/demo.zip" },
    "text": "packaged portable/app-tool/demo.zip",
  })
  assert_eq(json_string(event, "lane", default=""), "artifact")
  assert_true(
    json_bool(
      @mooncode.session_summary(Json::object({}), [event]),
      "has_packaging_candidate",
      default=false,
    ),
  )
}

///|
test "mooncode command events project into review lanes" {
  let session = append_mooncode_command_event(
    Json::object({}),
    action="run_tests",
    status="queued",
    detail=mooncode_command_message("run_tests", Json::object({})),
    created_at="1",
  )
  let session = append_mooncode_command_event(
    session,
    action="package",
    status="queued",
    detail=mooncode_command_message("package", Json::object({})),
    created_at="2",
  )
  let session = append_mooncode_command_event(
    session,
    action="accept",
    status="queued",
    detail=mooncode_command_message("accept", Json::object({})),
    created_at="3",
  )
  let session = append_mooncode_command_event(
    session,
    action="reject",
    status="queued",
    detail=mooncode_command_message("reject", Json::object({})),
    created_at="4",
  )
  let events = project_mooncode_events(session, [], [])
  assert_eq(events.length(), 4)
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[1], "lane", default=""), "artifact")
  assert_eq(json_string(events[2], "lane", default=""), "review")
  assert_eq(json_string(events[3], "lane", default=""), "review")
  let summary = @mooncode.session_summary(session, events)
  assert_true(json_bool(summary, "has_packaging_candidate", default=false))
  assert_eq(json_int(summary, "verified_test_count", default=0), 0)
  assert_eq(json_int(summary, "review_count", default=0), 2)
  assert_eq(json_int(summary, "accepted_review_count", default=0), 1)
  assert_eq(json_int(summary, "rejected_review_count", default=0), 1)
  assert_eq(json_string(summary, "review_state", default=""), "rejected")
}

///|
test "mooncode command preflight blocks accept until changed code is tested" {
  let diff_event = mooncode_event_record(
    id="diff-1",
    lane="diff",
    kind="write",
    title="File changed",
    status="done",
    created_at="2026-06-14T00:00:00Z",
    detail="changed",
    path="tools/demo/main.mbt",
    diff="+fn main { println(1) }",
  )
  let session : Json = { "id": "agent-demo", "mooncode_events": [diff_event] }
  let session = append_mooncode_command_event(
    session,
    action="approve_tool",
    status="queued",
    detail="Approve file write",
    created_at="2026-06-14T00:00:30Z",
    path="tools/demo/main.mbt",
  )
  let blocked = mooncode_command_preflight(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "accept",
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(
    json_string(blocked, "reason", default="").contains("run tests/builds"),
  )
  let test_event = mooncode_event_record(
    id="test-1",
    lane="test",
    kind="test_result",
    title="Tests passed",
    status="done",
    created_at="2026-06-14T00:01:00Z",
    detail="Total tests: 1, passed: 1",
    command="moon test",
    exit_code=0,
  )
  let tested = agent_session_with_field(
    session,
    "mooncode_events",
    Json::array([diff_event, test_event]),
  )
  let allowed = mooncode_command_preflight(
    tested,
    { "context_path": "tools/demo/main.mbt" },
    "accept",
  )
  assert_true(json_bool(allowed, "allowed", default=false))
}

///|
test "mooncode command preflight blocks package while tool approvals are pending" {
  let preview = mooncode_tool_authorization_preview_event(
    {
      "tool_call_id": "call-build",
      "tool_name": "shell",
      "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"]}",
    },
    "2026-06-14T00:00:00Z",
  )
  let session : Json = { "id": "agent-demo", "mooncode_events": [preview] }
  let blocked = mooncode_command_preflight(
    session,
    { "context_path": "apps/demo" },
    "package",
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(
    json_string(blocked, "reason", default="").contains(
      "pending tool approvals",
    ),
  )
}

///|
test "mooncode command preflight requires selected accepted patch target for apply" {
  let diff_event = mooncode_event_record(
    id="diff-1",
    lane="diff",
    kind="write",
    title="File changed",
    status="done",
    created_at="2026-06-14T00:00:00Z",
    detail="changed",
    path="tools/demo/main.mbt",
    diff="+fn main { println(1) }",
  )
  let accept_event = mooncode_event_record(
    id="review-1",
    lane="review",
    kind="command.accept",
    title="Accept patch",
    status="done",
    created_at="2026-06-14T00:01:00Z",
    detail="accepted",
    path="tools/demo/main.mbt",
    command="accept",
  )
  let session : Json = { "id": "agent-demo", "mooncode_events": [diff_event] }
  let missing = mooncode_command_preflight(
    session,
    Json::object({}),
    "apply_patch",
  )
  assert_true(json_bool(missing, "blocked", default=false))
  let wrong = mooncode_command_preflight(
    session,
    { "context_path": "tools/other/main.mbt" },
    "apply_patch",
  )
  assert_true(json_bool(wrong, "blocked", default=false))
  let unreviewed = mooncode_command_preflight(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "apply_patch",
  )
  assert_true(json_bool(unreviewed, "blocked", default=false))
  assert_true(
    json_string(unreviewed, "reason", default="").contains(
      "accept patch target",
    ),
  )
  let accepted_session : Json = {
    "id": "agent-demo",
    "mooncode_events": [diff_event, accept_event],
  }
  let allowed = mooncode_command_preflight(
    accepted_session,
    { "context_path": "tools/demo/main.mbt" },
    "apply_patch",
  )
  assert_true(json_bool(allowed, "allowed", default=false))
}

///|
test "mooncode preflight endpoint query builds command payload" {
  let payload = mooncode_preflight_payload_from_request(
    "/api/mooncode/sessions/s1/preflight?action=apply_patch&context_path=tools%2Fdemo%2Fmain.mbt",
  )
  assert_eq(json_string(payload, "action", default=""), "apply_patch")
  assert_eq(
    json_string(payload, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  let path_alias = mooncode_preflight_payload_from_request(
    "/api/mooncode/sessions/s1/preflight?action=accept&path=wiki%2Findex.md",
  )
  assert_eq(json_string(path_alias, "action", default=""), "accept")
  assert_eq(
    json_string(path_alias, "context_path", default=""),
    "wiki/index.md",
  )
}

///|
test "mooncode command preflight blocked attempts become runtime events" {
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": "mooncode.v1",
    "action": "package",
    "blocked": true,
    "reason": "resolve pending tool approvals before package",
  }
  let event = mooncode_command_preflight_blocked_event(
    preflight,
    { "context_path": "tools/demo/main.mbt" },
    "package",
    "2026-06-14T00:02:00Z",
  )
  assert_eq(json_string(event, "kind", default=""), "preflight.blocked")
  assert_eq(json_string(event, "lane", default=""), "artifact")
  assert_eq(json_string(event, "status", default=""), "blocked")
  assert_eq(json_string(event, "path", default=""), "tools/demo/main.mbt")
  assert_true(
    json_string(event, "detail", default="").contains("pending tool approvals"),
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(event, "command_packet"),
      "kind",
      default="",
    ),
    "mooncode-command-preflight",
  )
}

///|
test "mooncode forced preflight command creates override audit event and packet" {
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "force_preflight": true,
  }
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": "mooncode.v1",
    "action": "commit",
    "blocked": true,
    "reason": "accept reviewed file changes before commit",
  }
  let event = mooncode_command_preflight_override_event(
    preflight, payload, "commit", "2026-06-15T00:03:00Z",
  )
  assert_eq(json_string(event, "kind", default=""), "preflight.override")
  assert_eq(json_string(event, "status", default=""), "override")
  assert_eq(json_string(event, "path", default=""), "tools/demo/main.mbt")
  assert_true(
    json_string(event, "detail", default="").contains(
      "accept reviewed file changes",
    ),
  )
  let packet = mooncode_command_packet(
    { "id": "agent-demo", "workspace_root": "/tmp/book" },
    payload,
    "commit",
    "Commit anyway",
    "2026-06-15T00:03:00Z",
    "tools/demo/main.mbt",
  )
  assert_true(json_bool(packet, "force_preflight", default=false))
}

///|
test "mooncode review commands preserve target path" {
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  let target_path = mooncode_command_context_path(payload)
  let session = append_mooncode_command_event(
    Json::object({}),
    action="accept",
    status="queued",
    detail=mooncode_command_message("accept", payload),
    created_at="1",
    path=target_path,
  )
  let events = project_mooncode_events(session, [], [])
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "lane", default=""), "review")
  assert_eq(json_string(events[0], "path", default=""), "tools/demo/main.mbt")
  assert_true(
    json_string(events[0], "detail", default="").contains("tools/demo/main.mbt"),
  )
}

///|
test "mooncode patch set groups diff candidates by review state" {
  let command_packet : Json = {
    "protocol": "mooncode.v1",
    "command_id": "cmd-apply",
    "action": "apply_patch",
  }
  let events = [
    mooncode_event_record(
      id="diff",
      lane="diff",
      kind="file.write",
      title="File changed",
      status="done",
      created_at="1",
      detail="updated tool",
      path="tools/demo/main.mbt",
      diff="@@ -1,1 +1,1 @@\n-fn main { println(\"old\") }\n+fn main { println(\"ok\") }",
    ),
    mooncode_event_record(
      id="review",
      lane="review",
      kind="command.apply_patch",
      title="Apply patch",
      status="queued",
      created_at="2",
      detail="applied",
      path="tools/demo/main.mbt",
      command="apply_patch",
      command_packet~,
    ),
  ]
  let patches = mooncode_patch_set_entries(events)
  assert_eq(patches.length(), 1)
  assert_eq(json_string(patches[0], "path", default=""), "tools/demo/main.mbt")
  assert_eq(json_string(patches[0], "review_state", default=""), "applied")
  assert_true(json_bool(patches[0], "diff_present", default=false))
  assert_eq(json_int(patches[0], "hunk_count", default=0), 1)
  let hunks = json_array_items(patches[0], "hunks")
  assert_eq(json_string(hunks[0], "header", default=""), "@@ -1,1 +1,1 @@")
  assert_eq(
    json_string(hunks[0], "target", default=""),
    "tools/demo/main.mbt#hunk-1",
  )
  assert_eq(json_string(hunks[0], "review_state", default=""), "applied")
  assert_eq(json_int(hunks[0], "added_lines", default=0), 1)
  assert_eq(json_int(hunks[0], "removed_lines", default=0), 1)
  assert_eq(json_int(hunks[0], "applied_review_count", default=0), 1)
  assert_true(
    mooncode_command_preflight_has_patch_target(
      events, "tools/demo/main.mbt#hunk-1",
    ),
  )
  assert_eq(json_int(patches[0], "applied_review_count", default=0), 1)
  assert_eq(mooncode_count_patch_review_state(patches, "pending"), 0)
  assert_eq(mooncode_count_patch_review_state(patches, "applied"), 1)
}

///|
test "mooncode command prompts are book coding specific" {
  assert_true(mooncode_command_is_supported("reject"))
  assert_true(mooncode_command_is_supported("approve_tool"))
  assert_true(mooncode_command_is_supported("reject_tool"))
  assert_true(mooncode_command_is_supported("apply_patch"))
  assert_true(mooncode_command_is_supported("revert_patch"))
  assert_true(mooncode_command_is_supported("cancel"))
  assert_true(mooncode_command_is_supported("run_eval"))
  assert_true(mooncode_command_is_supported("commit"))
  assert_true(
    mooncode_command_message("run_tests", Json::object({})).contains("tests"),
  )
  assert_true(
    mooncode_command_message("run_eval", Json::object({})).contains(
      "eval harnesses",
    ),
  )
  assert_true(
    mooncode_command_message("package", Json::object({})).contains("MoonBook"),
  )
  assert_true(
    mooncode_command_message("commit", Json::object({})).contains(
      "commit_created",
    ),
  )
  assert_true(
    mooncode_command_message("accept", Json::object({})).contains(
      "operator accepts",
    ),
  )
  assert_true(
    mooncode_command_message("reject", Json::object({})).contains(
      "operator rejects",
    ),
  )
  assert_true(
    mooncode_command_message("approve_tool", Json::object({})).contains(
      "Approve",
    ),
  )
  assert_true(
    mooncode_command_message("reject_tool", Json::object({})).contains("Reject"),
  )
  assert_true(
    mooncode_command_message("apply_patch", Json::object({})).contains("Apply"),
  )
  assert_true(
    mooncode_command_message("revert_patch", Json::object({})).contains(
      "Revert",
    ),
  )
  assert_true(
    mooncode_command_message("cancel", Json::object({})).contains("Cancel"),
  )
}

///|
test "mooncode tool approvals identify policy and review gated tools" {
  let approve_packet : Json = {
    "protocol": "mooncode.v1",
    "command_id": "cmd-approve",
    "action": "approve_tool",
  }
  let events = [
    mooncode_event_record(
      id="shell",
      lane="tool",
      kind="execute_command",
      title="Tool finished: execute_command",
      status="done",
      created_at="1",
      detail="ran command",
      command="npm test",
    ),
    mooncode_event_record(
      id="write",
      lane="diff",
      kind="meta_write_to_file",
      title="File changed",
      status="done",
      created_at="2",
      detail="wrote file",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
    ),
    mooncode_event_record(
      id="approve",
      lane="review",
      kind="command.approve_tool",
      title="Approve tool",
      status="queued",
      created_at="3",
      detail="approved",
      path="npm test",
      command="approve_tool",
      command_packet=approve_packet,
    ),
  ]
  let approvals = mooncode_tool_approval_entries(events)
  assert_eq(approvals.length(), 2)
  assert_eq(json_string(approvals[0], "approval", default=""), "policy")
  assert_eq(json_string(approvals[0], "approval_state", default=""), "approved")
  assert_eq(json_string(approvals[1], "approval", default=""), "review")
  assert_eq(json_string(approvals[1], "approval_state", default=""), "pending")
  assert_eq(mooncode_count_tool_approval_state(approvals, "approved"), 1)
  assert_eq(mooncode_count_tool_approval_state(approvals, "pending"), 1)
}

///|
test "mooncode command packet preserves runtime boundary" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "moonclaw_task_id": "task-demo",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "web_search": false,
  }
  let message = mooncode_command_message("run_tests", payload)
  let packet = mooncode_command_packet(
    session, payload, "run_tests", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  assert_eq(json_string(packet, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(packet, "dispatch", default=""), "command")
  assert_eq(json_string(packet, "approval", default=""), "auto")
  assert_eq(
    json_string(packet, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_true(
    json_string_array_items(packet, "tool_hints").contains("moon_check"),
  )
  let output_contract = json_object_field_or_empty(packet, "output_contract")
  assert_eq(json_string(output_contract, "owner", default=""), "moonbook")
  assert_true(
    json_string_array_items(output_contract, "roots").contains("tools/"),
  )
  assert_true(
    mooncode_command_runtime_message(message, packet).contains(
      "MoonCode command packet",
    ),
  )
}

///|
fn mooncode_runtime_test_ingested_events(payload : Json) -> Array[Json] {
  json_array_items(
    @mooncode.runtime_event_ingest_report(
      payload,
      session_id="agent-demo",
      ingested_at="2026-06-15T00:00:00Z",
    ),
    "events",
  )
}

///|
test "mooncode runtime event ingest normalizes batches" {
  let events = mooncode_runtime_test_ingested_events({
    "events": [
      {
        "id": "tool-call-1",
        "event": "tool_call",
        "created_at": "0",
        "tool_name": "shell",
        "arguments": "{\"cmd\":[\"moon\",\"test\",\"tools/demo\"]}",
      },
      {
        "id": "assistant-1",
        "event": "assistant_message",
        "created_at": "1",
        "content": "done",
      },
      {
        "id": "test-1",
        "event": "test_result",
        "created_at": "2",
        "status": "done",
        "command": "moon test",
        "exit_code": 0,
        "detail": "Total tests: 1, passed: 1",
      },
      {
        "id": "steer-1",
        "event": "steer_applied",
        "created_at": "3",
        "content": "focus tests",
      },
      {
        "id": "steer-2",
        "event": "steer_dropped",
        "created_at": "4",
        "content": "too late",
      },
      {
        "id": "canonical-1",
        "lane": "artifact",
        "kind": "artifact",
        "title": "Packaged tool",
        "status": "done",
        "created_at": "5",
        "path": "portable/app-tool/demo.zip",
      },
    ],
  })
  assert_eq(events.length(), 6)
  assert_eq(json_string(events[0], "lane", default=""), "test")
  assert_eq(json_string(events[0], "kind", default=""), "shell")
  assert_eq(
    json_string(events[0], "command", default=""),
    "moon test tools/demo",
  )
  assert_eq(json_string(events[1], "lane", default=""), "transcript")
  assert_eq(json_string(events[2], "lane", default=""), "test")
  assert_eq(json_string(events[2], "command", default=""), "moon test")
  assert_eq(json_string(events[3], "kind", default=""), "steer_applied")
  assert_eq(json_string(events[3], "status", default=""), "done")
  assert_eq(json_string(events[4], "kind", default=""), "steer_dropped")
  assert_eq(json_string(events[4], "status", default=""), "failed")
  assert_eq(json_string(events[5], "lane", default=""), "artifact")
}

///|
async test "mooncode durable native tool call creates pending approval manifest" {
  let root = "/tmp/moondesk-mooncode-tool-call-" +
    @desk.stable_id("tool-call-test", @async.now().to_string())
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "moonclaw_task_id": "task-demo",
    "mooncode_last_eval_report_manifest": {
      "manifest_path": "wiki/reviews/mooncode/agent-demo/stale-eval-report.json",
      "absolute_manifest_path": "/tmp/stale-book/wiki/reviews/mooncode/agent-demo/stale-eval-report.json",
    },
    "mooncode_summary": {
      "last_moonbook_eval_report_manifest": {
        "manifest_path": "wiki/reviews/mooncode/agent-demo/stale-eval-report.json",
      },
    },
  }
  for
    event in mooncode_runtime_test_ingested_events({
      "event": "tool_call",
      "id": "tool-call-shell",
      "created_at": "2026-06-14T00:00:00Z",
      "tool_name": "shell",
      "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"],\"cwd\":\"apps/demo\"}",
    }) {
    append_mooncode_event_log(root, "agent-demo", event)
  }
  let projected = attach_mooncode_session_projection(root, session)
  let with_tool_approvals = write_mooncode_tool_approvals_if_possible(projected)
  let manifest = json_object_field_or_empty(
    with_tool_approvals, "mooncode_last_tool_approvals_manifest",
  )
  assert_eq(
    json_string(manifest, "kind", default=""),
    "mooncode-tool-approvals",
  )
  assert_eq(json_int(manifest, "pending_approval_count", default=0), 1)
  let approvals = json_array_items(manifest, "approvals")
  assert_eq(json_string(approvals[0], "tool_id", default=""), "shell")
  assert_eq(json_string(approvals[0], "approval", default=""), "policy")
  assert_eq(json_string(approvals[0], "command", default=""), "npm run build")
  assert_true(
    @fs.exists(
      @pathx.join(
        root,
        mooncode_tool_approvals_manifest_relative_path("agent-demo"),
      ),
    ),
  )
}

///|
test "mooncode tool authorization follows approval state" {
  let session : Json = { "id": "agent-demo" }
  let preview = mooncode_tool_authorization_preview_event(
    {
      "tool_call_id": "call-build",
      "tool_name": "shell",
      "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"]}",
    },
    "2026-06-14T00:00:00Z",
  )
  let pending = mooncode_tool_authorization_response(session, preview, [preview])
  assert_eq(json_string(pending, "decision", default=""), "requires_approval")
  assert_eq(json_string(pending, "approval", default=""), "policy")
  assert_eq(json_string(pending, "approval_state", default=""), "pending")
  assert_eq(json_string(pending, "command", default=""), "npm run build")
  let approve_session = append_mooncode_command_event(
    session,
    action="approve_tool",
    status="queued",
    detail="Approve build",
    created_at="2026-06-14T00:01:00Z",
    path="tool_call:call-build",
  )
  let approved_events = project_mooncode_events(approve_session, [], [preview])
  let approved = mooncode_tool_authorization_response(
    approve_session, preview, approved_events,
  )
  assert_eq(json_string(approved, "decision", default=""), "allowed")
  assert_true(json_bool(approved, "allowed", default=false))
  let reject_session = append_mooncode_command_event(
    session,
    action="reject_tool",
    status="queued",
    detail="Reject build",
    created_at="2026-06-14T00:02:00Z",
    path="tool_call:call-build",
  )
  let rejected_events = project_mooncode_events(reject_session, [], [preview])
  let rejected = mooncode_tool_authorization_response(
    reject_session, preview, rejected_events,
  )
  assert_eq(json_string(rejected, "decision", default=""), "blocked")
  assert_true(json_bool(rejected, "blocked", default=false))
}

///|
test "mooncode tool authorization allows read tools without approval" {
  let preview = mooncode_tool_authorization_preview_event(
    {
      "tool_call_id": "call-read",
      "tool_name": "read",
      "arguments": "{\"path\":\"wiki/index.md\"}",
    },
    "2026-06-14T00:00:00Z",
  )
  let response = mooncode_tool_authorization_response(
    { "id": "agent-demo" },
    preview,
    [preview],
  )
  assert_eq(json_string(response, "decision", default=""), "allowed")
  assert_eq(json_string(response, "approval", default=""), "auto")
  assert_true(json_bool(response, "allowed", default=false))
}

///|
async test "mooncode durable runtime event satisfies action plan test proof" {
  let root = "/tmp/moondesk-mooncode-runtime-events-" +
    @desk.stable_id("runtime-event-test", @async.now().to_string())
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
  let message = mooncode_command_message("run_tests", payload)
  let packet = mooncode_command_packet(
    session, payload, "run_tests", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let runtime_command = mooncode_runtime_command_record(
    session, payload, message, packet,
  )
  append_mooncode_command_log(root, "agent-demo", packet)
  append_mooncode_runtime_command_log(root, "agent-demo", runtime_command)
  append_mooncode_runtime_dispatch_log(
    root,
    "agent-demo",
    mooncode_runtime_dispatch_receipt(session, runtime_command),
  )
  let before = mooncode_action_plan_projection(root, session)
  let before_actions = json_array_items(before, "actions")
  assert_eq(
    json_string(before_actions[0], "state", default=""),
    "awaiting-proof",
  )
  let command_id = json_string(packet, "command_id", default="")
  for
    event in mooncode_runtime_test_ingested_events({
      "events": [
        {
          "event": "tool_call",
          "id": "tool-call-read",
          "created_at": "2026-06-14T00:00:30Z",
          "tool_name": "read",
          "tool_call_id": "call-read",
          "arguments": "{\"path\":\"tools/demo/main.mbt\"}",
          "command_id": command_id,
          "action": "run_tests",
        },
        {
          "event": "tool_result",
          "id": "tool-result-read",
          "created_at": "2026-06-14T00:00:45Z",
          "tool_name": "read",
          "tool_call_id": "call-read",
          "content": "fn main { println(\"demo\") }",
          "command_id": command_id,
          "action": "run_tests",
        },
        {
          "event": "tool_call",
          "id": "tool-call-1",
          "created_at": "2026-06-14T00:01:00Z",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "arguments": "{\"command\":\"moon check\"}",
          "command_id": command_id,
          "action": "run_tests",
        },
        {
          "event": "tool_result",
          "id": "tool-result-1",
          "created_at": "2026-06-14T00:01:30Z",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "content": "moon check passed",
          "command_id": command_id,
          "action": "run_tests",
        },
        {
          "event": "tool_call",
          "id": "tool-call-shell",
          "created_at": "2026-06-14T00:01:40Z",
          "tool_name": "shell",
          "tool_call_id": "call-shell",
          "arguments": "{\"command\":\"moon test\"}",
          "command_id": command_id,
          "action": "run_tests",
        },
        {
          "event": "tool_result",
          "id": "tool-result-shell",
          "created_at": "2026-06-14T00:01:50Z",
          "tool_name": "shell",
          "tool_call_id": "call-shell",
          "content": "moon test passed",
          "command_id": command_id,
          "action": "run_tests",
        },
        {
          "event": "test_result",
          "id": "test-result-1",
          "created_at": "2026-06-14T00:02:00Z",
          "status": "done",
          "command": "moon test",
          "exit_code": 0,
          "detail": "Total tests: 1, passed: 1",
          "command_id": command_id,
        },
        {
          "event": "agent_finished",
          "id": "finish-1",
          "created_at": "2026-06-14T00:03:00Z",
          "answer": "done",
          "command_id": command_id,
          "action": "run_tests",
        },
      ],
    }) {
    append_mooncode_event_log(root, "agent-demo", event)
  }
  let after = mooncode_action_plan_projection(root, session)
  let after_actions = json_array_items(after, "actions")
  assert_eq(json_int(after, "verified_test_count", default=0), 3)
  assert_eq(json_string(after_actions[0], "state", default=""), "completed")
  let gates = json_object_field_or_empty(after, "acceptance_gates")
  assert_true(json_bool(gates, "has_verified_tests", default=false))
  let refreshed = refresh_mooncode_runtime_review_artifacts(
    root,
    attach_mooncode_session_projection(root, session),
  )
  let runtime_evidence = json_object_field_or_empty(
    refreshed, "mooncode_last_runtime_evidence_manifest",
  )
  assert_eq(
    json_string(runtime_evidence, "kind", default=""),
    "mooncode-session-runtime-evidence",
  )
  assert_eq(json_string(runtime_evidence, "status", default=""), "proven")
  assert_eq(
    json_int(runtime_evidence, "proven_required_event_count", default=0),
    4,
  )
  assert_true(
    @fs.exists(
      json_string(runtime_evidence, "absolute_manifest_path", default=""),
    ),
  )
  let manifest_events = json_array_items(refreshed, "mooncode_command_events")
  let mut has_runtime_evidence_manifest_event = false
  for event in manifest_events {
    if json_string(event, "kind", default="") == "runtime_evidence.manifest" {
      has_runtime_evidence_manifest_event = true
    }
  }
  assert_true(has_runtime_evidence_manifest_event)
}

///|
async test "mooncode runtime replay ack events persist as session evidence" {
  let root = "/tmp/moondesk-mooncode-replay-proof-" +
    @desk.stable_id("runtime-replay-proof-test", @async.now().to_string())
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
  let message = mooncode_command_message("run_tests", payload)
  let packet = mooncode_command_packet(
    session, payload, "run_tests", message, "2026-06-15T00:00:00Z", "tools/demo/main.mbt",
  )
  let runtime_command = mooncode_runtime_command_record(
    session, payload, message, packet,
  )
  append_mooncode_command_log(root, "agent-demo", packet)
  append_mooncode_runtime_command_log(root, "agent-demo", runtime_command)
  let command_id = json_string(packet, "command_id", default="")
  let ack_receipts = mooncode_runtime_replay_ack_receipts(
    session,
    [runtime_command],
    {
      "consumer_id": "moonclaw-runtime",
      "command_id": command_id,
      "status": "runtime-completed",
      "acknowledged_at": "2026-06-15T00:01:00Z",
      "events": [
        {
          "event": "tool_call",
          "id": "evt-tool-start",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "arguments": "{\"command\":\"moon check\"}",
        },
        {
          "event": "tool_result",
          "id": "evt-tool-result",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "content": "moon check passed",
        },
        {
          "event": "test_result",
          "id": "evt-test",
          "command": "moon test",
          "status": "passed",
          "exit_code": 0,
        },
        { "event": "agent_finished", "id": "evt-finish", "answer": "done" },
      ],
    },
  )
  assert_eq(ack_receipts.length(), 1)
  append_mooncode_runtime_dispatch_log(root, "agent-demo", ack_receipts[0])
  let ack_events = mooncode_runtime_replay_ack_normalized_events(ack_receipts)
  assert_eq(ack_events.length(), 4)
  for event in ack_events {
    append_mooncode_event_log(root, "agent-demo", event)
  }
  let stored_events = read_mooncode_event_log(root, "agent-demo")
  assert_eq(stored_events.length(), 4)
  let stored_packet = json_object_field_or_empty(
    stored_events[0],
    "command_packet",
  )
  assert_eq(
    json_string(stored_packet, "kind", default=""),
    "mooncode.command-ref",
  )
  assert_eq(json_string(stored_packet, "command_id", default=""), command_id)
  assert_eq(json_string(stored_packet, "action", default=""), "run_tests")
  assert_true(json_bool(stored_packet, "runtime_proof", default=false))
  let projection = mooncode_session_runtime_evidence_projection(root, session)
  assert_eq(json_string(projection, "status", default=""), "proven")
  assert_eq(json_int(projection, "command_count", default=0), 1)
  assert_eq(json_int(projection, "runtime_command_count", default=0), 1)
  assert_eq(json_int(projection, "proof_event_count", default=0), 4)
  assert_eq(json_int(projection, "proven_command_count", default=0), 1)
  assert_eq(json_int(projection, "missing_required_event_count", default=-1), 0)
  assert_eq(
    json_string(projection, "manifest_path", default=""),
    mooncode_runtime_evidence_manifest_relative_path("agent-demo"),
  )
  assert_eq(
    json_string(projection, "absolute_manifest_path", default=""),
    @pathx.join(
      root,
      mooncode_runtime_evidence_manifest_relative_path("agent-demo"),
    ),
  )
  let with_manifest = write_mooncode_runtime_evidence_if_possible(root, session)
  let manifest = json_object_field_or_empty(
    with_manifest, "mooncode_last_runtime_evidence_manifest",
  )
  assert_eq(
    json_string(manifest, "kind", default=""),
    "mooncode-session-runtime-evidence",
  )
  assert_eq(json_string(manifest, "status", default=""), "proven")
  assert_eq(
    json_string(manifest, "manifest_path", default=""),
    mooncode_runtime_evidence_manifest_relative_path("agent-demo"),
  )
  assert_true(
    @fs.exists(json_string(manifest, "absolute_manifest_path", default="")),
  )
  let manifest_events = json_array_items(
    with_manifest, "mooncode_command_events",
  )
  assert_eq(
    json_string(manifest_events[0], "kind", default=""),
    "runtime_evidence.manifest",
  )
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
  let message = mooncode_command_message("package", payload)
  let packet = mooncode_command_packet(
    session, payload, "package", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let command = mooncode_runtime_command_record(
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
  let scheduler = mooncode_serve_scheduler_projection(
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
  let response_receipts = mooncode_runtime_dispatch_receipts_for_response(
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
  let runtime_state = mooncode_action_plan_runtime_state_at(
    "cmd-stale",
    commands,
    receipts,
    lease_now="2000-01-01T00:06:00Z",
  )
  assert_eq(runtime_state, "expired-claim")
  assert_eq(
    mooncode_action_plan_item_state("prompt", runtime_state, {}),
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
  assert_eq(mooncode_action_plan_status(0, 1, 0, 0, 0, 1), "running")
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
    mooncode_event_record(
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
  let message = mooncode_command_message("run_tests", payload)
  let packet = mooncode_command_packet(
    session, payload, "run_tests", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let runtime_command = mooncode_runtime_command_record(
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
  let event = mooncode_event_record(
    id="native-event",
    lane="runtime",
    kind="runtime_update",
    title="Runtime update",
    status="running",
    created_at="1",
    detail="native",
  )
  let turn_event = mooncode_event_record(
    id="runtime-turn-event",
    lane="tool",
    kind="tool_result",
    title="Tool result",
    status="done",
    created_at="2",
    detail="turn",
  )
  let session = mooncode_append_native_response_events(Json::object({}), {
    "events": [event],
    "execution": { "events": [turn_event] },
    "turn_receipt": { "events": [turn_event] },
  })
  let events = json_array_items(session, "mooncode_command_events")
  assert_eq(events.length(), 2)
  assert_eq(json_string(events[0], "id", default=""), "native-event")
  assert_eq(json_string(events[1], "id", default=""), "runtime-turn-event")
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
  let message = mooncode_command_message("package", payload)
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
  let message = mooncode_command_message("accept", payload)
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
      mooncode_command_message("package", payload),
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
        mooncode_runtime_command_record(
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
      assert_true(mooncode_runtime_handoff_manifest_current(runtime_handoff))
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
        mooncode_runtime_handoff_manifest_current(legacy_runtime_handoff),
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
    mooncode_event_record(
      id="transcript",
      lane="transcript",
      kind="message.user",
      title="User",
      status="recorded",
      created_at="1",
      detail="Please edit this book tool.",
    ),
    mooncode_event_record(
      id="tool",
      lane="tool",
      kind="tool.read",
      title="Read",
      status="completed",
      created_at="2",
      detail="read source",
    ),
    mooncode_event_record(
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
    mooncode_event_record(
      id="test",
      lane="test",
      kind="tool.moon_check",
      title="Moon check",
      status="passed",
      created_at="4",
      detail="passed",
      command="moon test",
    ),
    mooncode_event_record(
      id="artifact",
      lane="artifact",
      kind="artifact.package",
      title="Package",
      status="completed",
      created_at="5",
      detail="packaged",
    ),
    mooncode_event_record(
      id="review",
      lane="review",
      kind="review.accept",
      title="Accept",
      status="accepted",
      created_at="6",
      detail="accepted",
      command_packet~,
    ),
    mooncode_event_record(
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
    mooncode_event_record(
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
    mooncode_event_record(
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
    mooncode_event_record(
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
    mooncode_event_record(
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
    mooncode_event_record(
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
    mooncode_event_record(
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
    mooncode_event_record(
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
    mooncode_event_record(
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
    mooncode_event_record(
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
    mooncode_event_record(
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
    "/v1/mooncode/sessions/<id>/eval-report",
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
  let eval_message = mooncode_command_message("run_eval", eval_payload)
  let eval_packet = mooncode_command_packet(
    session, eval_payload, "run_eval", eval_message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  let eval_runtime_command = mooncode_runtime_command_record(
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
    event in mooncode_runtime_test_ingested_events({
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
    }) {
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
    root, session, native_payload, "/v1/mooncode/sessions/agent-demo/eval-report",
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
    "/v1/mooncode/sessions/agent-demo/eval-report",
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
test "mooncode jsonl stream includes meta events and done records" {
  let event = mooncode_event_record(
    id="e1",
    lane="test",
    kind="command.run_tests",
    title="Run tests: queued",
    status="queued",
    created_at="1",
    detail="Run tests",
  )
  let fields : Map[String, Json] = {}
  fields["id"] = "s1".to_json()
  fields["workspace_id"] = "book".to_json()
  fields["moonclaw_task_id"] = "task".to_json()
  fields["mooncode_events"] = Json::array([event])
  let session = Json::object(fields)
  let text = mooncode_jsonl_stream_text(session, [event])
  let lines = text.trim().split("\n").to_array()
  assert_eq(lines.length(), 3)
  let meta = @json.parse(lines[0].to_owned()) catch { _ => Json::object({}) }
  let item = @json.parse(lines[1].to_owned()) catch { _ => Json::object({}) }
  let done = @json.parse(lines[2].to_owned()) catch { _ => Json::object({}) }
  assert_eq(json_string(meta, "type", default=""), "meta")
  assert_eq(json_int(meta, "event_count", default=0), 1)
  assert_eq(json_int(meta, "since", default=-1), 0)
  assert_eq(json_int(meta, "emitted_count", default=0), 1)
  assert_eq(json_int(meta, "next_since", default=0), 1)
  assert_eq(
    json_string(meta, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_eq(json_string(item, "type", default=""), "event")
  assert_eq(json_int(item, "sequence", default=0), 1)
  assert_eq(
    json_string(item, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_eq(json_string(done, "type", default=""), "done")
  assert_eq(json_int(done, "next_since", default=0), 1)
  assert_eq(
    json_string(done, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
}

///|
test "mooncode jsonl stream supports incremental since sequence" {
  let first = mooncode_event_record(
    id="e1",
    lane="tool",
    kind="tool.read",
    title="Read",
    status="done",
    created_at="1",
    detail="first",
  )
  let second = mooncode_event_record(
    id="e2",
    lane="diff",
    kind="tool.write",
    title="Write",
    status="done",
    created_at="2",
    detail="second",
  )
  let fields : Map[String, Json] = {}
  fields["id"] = "s1".to_json()
  fields["mooncode_events"] = Json::array([first, second])
  let session = Json::object(fields)
  let text = mooncode_jsonl_stream_text(session, [first, second], since=1)
  let lines = text.trim().split("\n").to_array()
  assert_eq(lines.length(), 3)
  let meta = @json.parse(lines[0].to_owned()) catch { _ => Json::object({}) }
  let item = @json.parse(lines[1].to_owned()) catch { _ => Json::object({}) }
  let done = @json.parse(lines[2].to_owned()) catch { _ => Json::object({}) }
  assert_eq(json_string(meta, "stream", default=""), "append-log-incremental")
  assert_eq(
    json_string(meta, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_eq(json_int(meta, "since", default=0), 1)
  assert_eq(json_int(meta, "emitted_count", default=0), 1)
  assert_eq(json_int(meta, "next_since", default=0), 2)
  assert_eq(json_int(item, "sequence", default=0), 2)
  let event_payload = match item {
    Json::Object(object) => object.get("event").unwrap_or(Json::object({}))
    _ => Json::object({})
  }
  assert_eq(json_string(event_payload, "id", default=""), "e2")
  assert_eq(json_int(done, "sequence", default=0), 2)
}

///|
async test "mooncode stream state records resumable checkpoint" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-stream-state-wbtest-" +
    @desk.stable_id("mooncode-stream-state", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "moonclaw_task_id": "task-demo",
  }
  append_mooncode_event_log(
    root,
    "agent-demo",
    mooncode_event_record(
      id="event-1",
      lane="runtime",
      kind="assistant_delta",
      title="Assistant delta",
      status="running",
      created_at="1",
      detail="first",
    ),
  )
  append_mooncode_event_log(
    root,
    "agent-demo",
    mooncode_event_record(
      id="event-2",
      lane="test",
      kind="test_result",
      title="Tests passed",
      status="passed",
      created_at="2",
      detail="second",
    ),
  )
  assert_eq(read_mooncode_event_log(root, "agent-demo").length(), 2)
  let state = mooncode_stream_state_projection(root, session, 1, "moondesk-ui")
  assert_eq(json_string(state, "kind", default=""), "mooncode-stream-state")
  assert_eq(json_int(state, "latest_sequence", default=0), 2)
  assert_eq(json_int(state, "emitted_count", default=0), 1)
  assert_eq(json_int(state, "next_since", default=0), 2)
  assert_false(json_bool(state, "checkpoint_ready", default=true))
  let tail = json_array_items(state, "tail_events")
  assert_eq(tail.length(), 1)
  assert_eq(json_int(tail[0], "sequence", default=0), 2)
  assert_eq(
    json_string(
      json_object_field_or_empty(tail[0], "event"),
      "kind",
      default="",
    ),
    "test_result",
  )
  let checkpoint = mooncode_stream_checkpoint_record(
    root,
    session,
    "moondesk-ui",
    json_int(state, "next_since", default=0),
    2,
  )
  write_mooncode_stream_checkpoint(
    root, "agent-demo", "moondesk-ui", checkpoint,
  )
  let resumed = mooncode_stream_state_projection(
    root, session, 2, "moondesk-ui",
  )
  assert_true(json_bool(resumed, "checkpoint_ready", default=false))
  assert_eq(json_int(resumed, "emitted_count", default=-1), 0)
  let saved = json_object_field_or_empty(resumed, "checkpoint")
  assert_eq(
    json_string(saved, "kind", default=""),
    "mooncode-stream-checkpoint",
  )
  assert_eq(json_int(saved, "last_seen_sequence", default=0), 2)
  assert_true(@fs.exists(json_string(saved, "checkpoint_path", default="")))
  assert_true(
    json_string(resumed, "checkpoint_endpoint", default="").contains(
      "/api/mooncode/sessions/agent-demo/stream-state",
    ),
  )
}

///|
test "mooncode native stream path targets typed runtime endpoint" {
  assert_eq(
    mooncode_native_stream_path("agent-demo", "sse", 7),
    "/v1/mooncode/sessions/agent-demo/stream?format=sse&since=7",
  )
}

///|
test "mooncode stream live query opts into bounded tail" {
  assert_true(
    mooncode_stream_live_enabled(
      "/api/mooncode/sessions/s1/stream?format=sse&since=2&live=true",
    ),
  )
  assert_true(
    mooncode_stream_live_enabled(
      "/api/mooncode/sessions/s1/stream?format=jsonl&live=wait",
    ),
  )
  assert_false(
    mooncode_stream_live_enabled("/api/mooncode/sessions/s1/stream?live=false"),
  )
  assert_eq(
    mooncode_stream_live_timeout_ms(
      "/api/mooncode/sessions/s1/stream?timeout_ms=20000",
    ),
    15000,
  )
  assert_eq(
    mooncode_stream_live_poll_ms("/api/mooncode/sessions/s1/stream?poll_ms=10"),
    50,
  )
  assert_eq(mooncode_live_stream_attempt_count(801, 250), 4)
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
test "mooncode summary and eval report delegate to extracted protocol" {
  let event = mooncode_event_record(
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
  let legacy_summary = mooncode_session_summary(session, [event])
  let extracted_summary = @mooncode.session_summary(session, [event])
  assert_eq(
    json_int(legacy_summary, "diff_count", default=0),
    json_int(extracted_summary, "diff_count", default=0),
  )
  assert_eq(
    json_string(legacy_summary, "review_state", default=""),
    json_string(extracted_summary, "review_state", default=""),
  )
  let with_summary = agent_session_with_field(
    session, "mooncode_summary", extracted_summary,
  )
  let delegated_report = mooncode_eval_report_projection(with_summary)
  let extracted_report = @mooncode.eval_report_projection(with_summary)
  assert_eq(
    json_string(delegated_report, "kind", default=""),
    json_string(extracted_report, "kind", default=""),
  )
  assert_eq(
    json_string(delegated_report, "extractable_component", default=""),
    json_string(extracted_report, "extractable_component", default=""),
  )
}

///|
test "mooncode sse stream uses named events" {
  let event = mooncode_event_record(
    id="e1",
    lane="artifact",
    kind="command.package",
    title="Package result: queued",
    status="queued",
    created_at="1",
    detail="Package",
  )
  let fields : Map[String, Json] = {}
  fields["id"] = "s1".to_json()
  fields["mooncode_events"] = Json::array([event])
  let session = Json::object(fields)
  let text = mooncode_sse_stream_text(session, [event])
  assert_true(text.contains("event: mooncode.meta\n"))
  assert_true(text.contains("event: mooncode.event\n"))
  assert_true(text.contains("event: mooncode.done\n"))
}
