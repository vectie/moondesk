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
