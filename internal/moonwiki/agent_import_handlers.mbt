///|
fn agent_import_runtime_runner(
  runtime : @trusted_host.MoonBookExportRuntime,
  root : String,
  is_current? : () -> Bool = () => true,
) -> AgentExportRun {
  (command, args) => {
    let operation = match (command, args) {
      ("inspect", [package_path]) => @trusted_host.Inspect(package_path~)
      ("verify", [package_path]) => @trusted_host.Verify(package_path~)
      ("source", [package_path]) => @trusted_host.Source(package_path~)
      ("import", [destination, package_path, source_path]) =>
        @trusted_host.Import(destination~, package_path~, source_path~)
      ("verify-import", [destination, package_path]) =>
        @trusted_host.VerifyImport(destination~, package_path~)
      _ => return Err("Unsupported MoonBook receive operation")
    }
    runtime.run(root, operation, may_run=() => {
      !(operation is @trusted_host.Import(..)) || is_current()
    })
  }
}

///|
async fn agent_import_read_body(body : &@io.Reader, limit : Int) -> Json? {
  let bytes = @buffer.Buffer(size_hint=8192)
  while body.read_some(max_len=(limit + 1 - bytes.length()).min(65536))
        is Some(chunk) {
    if bytes.length() + chunk.length() > limit {
      return None
    }
    bytes.write_bytes(chunk)
  }
  Some(@json.parse(@encoding/utf8.decode(bytes.to_bytes()))) catch {
    _ => None
  }
}

///|
async fn handle_agent_import(
  workspace_root : String,
  operation_id : String?,
  request_path : String,
  method_ : @http.RequestMethod,
  body : &@io.Reader,
  conn : @http.ServerConnection,
  active_root? : Ref[String],
) -> Unit {
  if operation_id is Some(id) && !agent_export_id_valid(id) {
    send_api_error(
      conn, method_, 400, "Bad Request", "Invalid receive operation",
    )
    return
  }
  if !(method_ is Post ||
    (operation_id is Some(_) && (method_ is Get || method_ is Head))) {
    send_method_not_allowed_with_methods(
      conn,
      method_,
      if operation_id is None {
        ["POST"]
      } else {
        ["GET", "HEAD", "POST"]
      },
    )
    return
  }
  let context = workspace_context(workspace_root)
  // This is the live server-owned reference, never browser-supplied state.
  let is_current = () => {
    match active_root {
      Some(active) =>
        workspace_context(active.val).books_root == context.books_root
      None => true
    }
  }
  let mut stage : AgentImportStage? = None
  let mut request : AgentImportRequest? = None
  let expected_library = if method_ is Post {
    guard agent_import_read_body(
        body,
        if operation_id is None {
          agent_import_body_limit
        } else {
          8192
        },
      )
      is Some(payload) else {
      send_api_error(
        conn, method_, 400, "Bad Request", "Receive request is invalid or exceeds its size limit",
      )
      return
    }
    if operation_id is None {
      match agent_import_stage_request(payload) {
        Ok(value) => {
          stage = Some(value)
          value.expected_library
        }
        Err(message) => {
          send_api_error(conn, method_, 400, "Bad Request", message)
          return
        }
      }
    } else {
      match agent_import_request(payload) {
        Ok(value) if operation_id == Some(value.operation_id) => {
          request = Some(value)
          value.expected_library
        }
        _ => {
          send_api_error(
            conn, method_, 400, "Bad Request", "Import must identify its reviewed package and operation",
          )
          return
        }
      }
    }
  } else {
    decode_query_value(
      query_value(request_path, "expected_library").unwrap_or(""),
    )
  }
  guard expected_library == context.books_root else {
    send_api_error(
      conn, method_, 409, "Conflict", "The selected library changed. Return to the original library to check this receive operation.",
    )
    return
  }
  let runtime = match @trusted_host.moonbook_import_runtime() {
    Ok(value) => value
    Err(message) => {
      send_api_error(conn, method_, 503, "Service Unavailable", message)
      return
    }
  }
  let run = agent_import_runtime_runner(
    runtime,
    context.suite_root,
    is_current~,
  )
  let result = try {
    if stage is Some(value) {
      agent_import_stage_with(context, value, run, is_current~)
    } else if request is Some(value) {
      agent_import_apply_with(context, value, run, is_current~)
    } else {
      agent_import_mutex.acquire()
      defer agent_import_mutex.release()
      agent_import_inspect_with(
        context,
        operation_id.unwrap(),
        expected_library,
        run,
      )
    }
  } catch {
    _ => {
      send_api_error(
        conn, method_, 409, "Conflict", "This package or destination could not be verified. Check this operation before starting another import; existing files were left in place.",
      )
      return
    }
  }
  send_json(conn, method_, result)
}
