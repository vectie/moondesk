///|
async fn handle_mooncode_session_runtime_events(
  workspace_root : String,
  session_id : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => {
      let session = sync_mooncode_moonclaw_sidecar_events(
        workspace_root, session_id, session,
      ) catch {
        _ => {
          send_api_error(
            conn, method_, 500, "Internal Server Error", "Could not sync MoonCode native runtime events",
          )
          return
        }
      }
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
      let session = sync_mooncode_observed_runtime_events(
        workspace_root, session_id, session, native_events,
      ) catch {
        _ => {
          send_api_error(
            conn, method_, 500, "Internal Server Error", "Could not save MoonCode native runtime events",
          )
          return
        }
      }
      let local_events = read_mooncode_event_log(workspace_root, session_id)
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
      if !mooncode_runtime_session_known(
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
          @mooncode.native_runtime_session_projection(
            workspace_root, session_id,
          ),
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
async fn sync_mooncode_moonclaw_sidecar_events(
  workspace_root : String,
  session_id : String,
  session : Json,
) -> Json {
  let sidecar_events = read_moonclaw_mooncode_event_log(
    workspace_root, session_id,
  )
  if sidecar_events.length() == 0 {
    return session
  }
  let report = @mooncode.runtime_event_ingest_report(
    { "events": Json::array(sidecar_events) },
    session_id~,
    ingested_at=@async.now().to_string(),
  )
  sync_mooncode_observed_runtime_events(
    workspace_root,
    session_id,
    session,
    json_array_items(report, "events"),
  )
}

///|
async fn sync_mooncode_observed_runtime_events(
  workspace_root : String,
  session_id : String,
  session : Json,
  observed_events : Array[Json],
) -> Json {
  if observed_events.length() == 0 {
    return session
  }
  let local_events = read_mooncode_event_log(workspace_root, session_id)
  let new_events = mooncode_unpersisted_runtime_events(
    local_events, observed_events,
  )
  if new_events.length() == 0 {
    return session
  }
  let persisted = persist_mooncode_runtime_events_and_projection(
    workspace_root, session_id, session, new_events,
  )
  match read_mooncode_session_record(workspace_root, session_id) {
    Some(record) => record
    None => persisted
  }
}

///|
fn mooncode_unpersisted_runtime_events(
  local_events : Array[Json],
  observed_events : Array[Json],
) -> Array[Json] {
  let new_events : Array[Json] = []
  let merged = @mooncode.merge_events([], observed_events, local_events)
  for event in merged {
    if !mooncode_event_already_persisted(local_events, event) {
      new_events.push(event)
    }
  }
  new_events
}

///|
fn mooncode_event_already_persisted(
  local_events : Array[Json],
  event : Json,
) -> Bool {
  let event_id = json_string(event, "id", default="")
  for persisted in local_events {
    if event_id != "" && json_string(persisted, "id", default="") == event_id {
      return true
    }
    if event_id == "" && persisted.stringify() == event.stringify() {
      return true
    }
  }
  false
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
  let session = match read_mooncode_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let ingest_report = @mooncode.runtime_event_ingest_report(
    payload,
    session_id~,
    ingested_at=@async.now().to_string(),
  )
  let events = json_array_items(ingest_report, "events")
  if events.length() == 0 {
    send_api_error(
      conn, method_, 400, "Bad Request", "No valid MoonCode runtime event found. Send a MoonCode event object or {\"events\":[...]} payload.",
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
      enrich_mooncode_session_for_response(workspace_root, with_runtime_handoff),
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
  let updated = mooncode_session_with_field(
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
  write_mooncode_session_record(workspace_root, with_runtime_handoff)
  with_runtime_handoff
}
