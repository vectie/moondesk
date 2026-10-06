///|
fn agent_export_runtime_runner(
  runtime : @trusted_host.MoonBookExportRuntime,
  root : String,
) -> AgentExportRun {
  (command, args) => {
    let operation = match (command, args) {
      ("pack", [version, output, selection]) =>
        @trusted_host.Pack(version~, output~, selection~)
      ("inspect", [path]) => @trusted_host.Inspect(package_path=path)
      ("verify", [path]) => @trusted_host.Verify(package_path=path)
      ("source", [path]) => @trusted_host.Source(package_path=path)
      _ => return Err("Unsupported MoonBook export operation")
    }
    runtime.run(root, operation)
  }
}

///|
async fn agent_export_read_body(body : &@io.Reader) -> Json? {
  let limit = 1024 * 1024
  let bytes = @buffer.Buffer(size_hint=512)
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
async fn handle_agent_export(
  workspace_root : String,
  workspace_id : String,
  export_id : String?,
  request_path : String,
  method_ : @http.RequestMethod,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  guard find_workspace(workspace_root, workspace_id) is Some(workspace) &&
    workspace.kind is MoonBook else {
    send_api_error(
      conn, method_, 404, "Not Found", "Choose an existing MoonBook",
    )
    return
  }
  if export_id is Some(id) && !agent_export_id_valid(id) {
    send_api_error(conn, method_, 400, "Bad Request", "Invalid preparation ID")
    return
  }
  if !(method_ is Get ||
    method_ is Head ||
    (method_ is Post && export_id is None)) {
    send_method_not_allowed_with_methods(
      conn,
      method_,
      if export_id is None {
        ["GET", "HEAD", "POST"]
      } else {
        ["GET", "HEAD"]
      },
    )
    return
  }
  let prepare_request = if method_ is Post {
    guard agent_export_read_body(body) is Some(payload) else {
      send_api_error(
        conn, method_, 400, "Bad Request", "Preparation needs a valid JSON body of at most 1 MiB",
      )
      return
    }
    match agent_export_request(payload) {
      Ok(value) => Some(value)
      Err(message) => {
        send_api_error(conn, method_, 400, "Bad Request", message)
        return
      }
    }
  } else {
    None
  }
  let expected_library = match prepare_request {
    Some(request) => request.expected_library
    None =>
      decode_query_value(
        query_value(request_path, "expected_library").unwrap_or(""),
      )
  }
  guard expected_library == workspace_context(workspace_root).books_root else {
    send_api_error(
      conn, method_, 409, "Conflict", "The selected library changed. Refresh the Book before preparing or inspecting packages.",
    )
    return
  }
  let runtime = @trusted_host.moonbook_export_runtime()
  if export_id is None && !(method_ is Post) {
    let available = runtime is Ok(_)
    let message = match runtime {
      Ok(_) => "Ready to prepare a local experienced-Book package"
      Err(message) => message
    }
    let exports = agent_export_retained(workspace) catch { _ => [] }
    send_json(conn, method_, {
      "workspace_id": workspace.id,
      "expected_library": expected_library,
      "available": available,
      "message": message,
      "exports": exports,
    })
    return
  }
  let runtime = match runtime {
    Ok(value) => value
    Err(message) => {
      send_api_error(conn, method_, 503, "Service Unavailable", message)
      return
    }
  }
  let run = agent_export_runtime_runner(runtime, workspace.root_path)
  let result = try {
    if export_id is Some(id) {
      agent_export_inspection_with(
        workspace,
        id,
        agent_export_relative(id),
        run,
        retained=true,
      )
    } else {
      let request = prepare_request.unwrap()
      agent_export_prepare_with(workspace, request, run)
    }
  } catch {
    error => {
      // Only feature-local stable errors are returned. The process adapter
      // never reflects child stderr, host executable paths, or user configs.
      send_api_error(
        conn, method_, 409, "Conflict", "Could not verify or complete this local package preparation. Check saved packages before starting another preparation.",
      )
      ignore(error)
      return
    }
  }
  send_json(conn, method_, result)
}
