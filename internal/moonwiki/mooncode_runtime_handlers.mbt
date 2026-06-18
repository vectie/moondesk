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
        @mooncode.runtime_replay_state_for_session(
          session,
          commands,
          receipts,
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
        @mooncode.runtime_serve_jsonl(commands, receipts, scope~),
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
  let ack_receipts = @mooncode.runtime_replay_ack_receipts_with_defaults(
    session,
    commands,
    payload,
    acknowledged_at=@async.now().to_string(),
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
        @mooncode.runtime_claim_state_for_session(
          session,
          commands,
          receipts,
          runtime_command_log_path=mooncode_runtime_command_log_path(
            workspace_root, session_id,
          ),
          runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
            workspace_root, session_id,
          ),
          lease_now=match query_value(request_path, "now") {
            Some(value) if value != "" => value
            _ => @async.now().to_string()
          },
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
  let claim_receipts = @mooncode.runtime_claim_receipts_with_defaults(
    session,
    commands,
    receipts,
    payload,
    now=@async.now().to_string(),
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
        @mooncode.serve_scheduler_response(
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
    live_wait_ms=json_int(payload, "live_wait_ms", default=5000),
    poll_ms=json_int(payload, "poll_ms", default=250),
  )
  let runtime_response = match
    moonclaw_post_json(
      daemon,
      @mooncode.moonclaw_native_runtime_loop_endpoint(
        session_id, workspace_root,
      ),
      loop_body,
    ) {
    Ok(response) => Ok(response)
    Err(_) =>
      moonclaw_post_json(
        daemon,
        @mooncode.moonclaw_native_runtime_turn_endpoint(
          session_id, workspace_root,
        ),
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
  let updated_at = @async.now().to_string()
  let session_patch = @mooncode.moonclaw_runtime_supervisor_run_session_patch(
    response, updated_at,
  )
  let status_message = json_object_field_or_empty(
    session_patch, "status_message",
  )
  let with_response = append_agent_message(
    @mooncode.append_projected_native_response_events(
      session,
      response,
      loop_fallback_created_at=updated_at,
    ),
    role="status",
    content=json_string(status_message, "content", default=""),
    status=json_string(status_message, "status", default="failed"),
    created_at=json_string(status_message, "created_at", default=updated_at),
  )
  let with_updated = @mooncode.apply_moonclaw_runtime_session_patch(
    with_response, session_patch,
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
      let local_events = read_mooncode_event_log(workspace_root, session_id)
      let native = mooncode_native_runtime_events_state(
        workspace_root, session_id,
      )
      let native_report = @mooncode.runtime_native_event_report(
        native,
        session_id~,
        observed_at=@async.now().to_string(),
      )
      let native_events = @mooncode.native_runtime_events_for_projection(
        native_report,
      )
      let events = @mooncode.merge_events([], native_events, local_events)
      send_json(
        conn,
        method_,
        @mooncode.runtime_event_sink_result_response_with_native(
          session_id,
          events,
          session,
          event_log_path=mooncode_event_log_path(workspace_root, session_id),
          local_event_count=local_events.length(),
          native_state=native,
          native_report~,
        ),
      )
    }
    None => {
      let native = mooncode_native_runtime_events_state(
        workspace_root, session_id,
      )
      let native_report = @mooncode.runtime_native_event_report(
        native,
        session_id~,
        observed_at=@async.now().to_string(),
      )
      let native_events = @mooncode.native_runtime_events_for_projection(
        native_report,
      )
      if !mooncode_native_session_known(
          workspace_root, session_id, native_events,
        ) {
        send_api_error(
          conn, method_, 404, "Not Found", "Unknown MoonCode session",
        )
        return
      }
      send_json(
        conn,
        method_,
        @mooncode.runtime_event_sink_result_response_with_native(
          session_id,
          native_events,
          @mooncode.native_runtime_session_stub(workspace_root, session_id),
          event_log_path="",
          local_event_count=0,
          native_state=native,
          native_report~,
        ),
      )
    }
  }
}

///|
async fn mooncode_native_runtime_events_state(
  workspace_root : String,
  session_id : String,
) -> Json {
  let endpoint = @mooncode.moonclaw_native_runtime_events_endpoint(
    session_id, workspace_root,
  )
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    return @mooncode.native_runtime_events_unavailable_state(
      endpoint, "MoonClaw daemon is not running",
    )
  }
  if !mooncode_native_runtime_ready(daemon) {
    return @mooncode.native_runtime_events_unavailable_state(
      endpoint, "MoonClaw MoonCode runtime is not available",
    )
  }
  match moonclaw_get_json(daemon, endpoint) {
    Ok(payload) =>
      @mooncode.native_runtime_events_available_state(payload, endpoint)
    Err(message) =>
      @mooncode.native_runtime_events_unavailable_state(endpoint, message)
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
  let ingest_report = @mooncode.runtime_event_ingest_report_with_moonclaw_adapter(
    payload,
    session_id~,
    ingested_at=@async.now().to_string(),
  )
  let events = json_array_items(ingest_report, "events")
  if events.length() == 0 {
    send_api_error(
      conn, method_, 400, "Bad Request", "No valid MoonCode runtime event found. Send an OpenSeek-style event object or {\"events\":[...]} payload.",
    )
    return
  }
  let with_runtime_handoff = persist_mooncode_runtime_events_and_projection(
    workspace_root, session_id, session, events,
  ) catch {
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
async fn persist_mooncode_runtime_events_and_projection(
  workspace_root : String,
  session_id : String,
  session : Json,
  events : Array[Json],
) -> Json {
  for event in events {
    append_mooncode_event_log(workspace_root, session_id, event)
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
  write_agent_session_record(workspace_root, with_runtime_handoff)
  with_runtime_handoff
}
