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
