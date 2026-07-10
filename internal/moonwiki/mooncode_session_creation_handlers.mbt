///|
async fn resolve_mooncode_workspace_scope(
  workspace_root : String,
  workspace_id : String,
) -> Result[@desk.DeskWorkspace, String] {
  let context = workspace_context(workspace_root)
  if workspace_id == "" {
    return Ok(
      @desk.workspace(
        id=@desk.stable_id("general-mooncode", context.suite_root),
        name="General MoonCode",
        root_path=context.suite_root,
        kind=SuiteRoot,
      ),
    )
  }
  match find_workspace(workspace_root, workspace_id) {
    Some(workspace) => Ok(workspace)
    None => Err("Unknown workspace")
  }
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
  let context = workspace_context(workspace_root)
  let root = context.suite_root
  let workspace = match resolve_mooncode_workspace_scope(root, workspace_id) {
    Ok(workspace) => workspace
    Err(message) => {
      send_api_error(conn, method_, 404, "Not Found", message)
      return
    }
  }
  let now = @async.now().to_string()
  let runtime : Json = {
    "id": "",
    "status": "created",
    "model": json_string(payload, "model", default=""),
    "web_search": json_bool(payload, "web_search", default=false),
    "queued_messages": [],
  }
  let message = trimmed_text(
    json_string(payload, "message", default=""),
    fallback=if workspace_id == "" {
      "Help me plan, write, test, or explain code."
    } else {
      "Create, inspect, test, or package executable code inside this MoonBook."
    },
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
    runtime~,
    title~,
    created_at=now,
    updated_at=now,
    last_message=message,
    initial_context_path=context_path,
  )
  let command_packet = @mooncode.projected_command_packet(
    base, payload, "prompt", message, now, context_path,
  )
  let runtime_command = @mooncode.runtime_command_record(
    base, payload, message, command_packet,
  )
  append_mooncode_command_log(
    root,
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
    root,
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
  let queued = mooncode_immediate_queued_session(
    base,
    action="prompt",
    message~,
    context_path~,
    command_packet~,
    created_at=now,
  )
  ignore(runtime_command)
  write_mooncode_session_record(root, queued) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not save MoonCode session",
      )
      return
    }
  }
  append_new_mooncode_command_events(root, base, queued) catch {
    _ => {
      send_api_error(
        conn, method_, 500, "Internal Server Error", "Could not append MoonCode event log",
      )
      return
    }
  }
  match
    mooncode_command_response_after_enqueue(
      root, queued, command_packet, payload,
    ) {
    Ok(response) => send_json(conn, method_, response)
    Err(error) => {
      ignore(
        record_mooncode_runtime_service_failure(
          root,
          json_string(queued, "id", default=""),
          queued,
          error,
        ),
      ) catch {
        _ => ()
      }
      send_api_error(
        conn,
        method_,
        json_int(error, "code", default=500),
        json_string(error, "reason", default="Internal Server Error"),
        json_string(
          error,
          "message",
          default="Could not start MoonCode runtime",
        ),
      )
    }
  }
}
