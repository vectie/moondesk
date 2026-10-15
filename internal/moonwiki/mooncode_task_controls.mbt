///|
/// MoonDesk displays and forwards task controls; MoonClaw owns their journal.
async fn handle_mooncode_task_controls(
  workspace_root : String,
  session_id : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(Object(fields)) => fields.copy()
    _ => {
      send_api_error(
        conn, method_, 400, "Bad Request", "Invalid task controls request",
      )
      return
    }
  }
  let book_root = match
    moonclaw_runtime_session_book_root(workspace_root, session_id) {
    Ok(value) => value
    Err(error) => {
      let (code, reason) = mooncode_session_scope_error_status(error)
      send_api_error(conn, method_, code, reason, error)
      return
    }
  }
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="task-controls",
  )
  if !json_bool(daemon, "running", default=false) {
    send_api_error(
      conn, method_, 503, "Unavailable", "Start the coding service to manage this task",
    )
    return
  }
  payload["book_root"] = book_root.to_json()
  let lifecycle = @mooncode.moonclaw_native_session_lifecycle_endpoint(
    session_id,
  )
  let endpoint = lifecycle[:lifecycle.length() - "lifecycle".length()].to_owned() +
    "task-controls"
  match mooncode_task_control_post(daemon, endpoint, Json::object(payload)) {
    Ok(result) => send_json(conn, method_, result)
    Err(error) => {
      let outcome = mooncode_session_lifecycle_proxy_failure(error)
      send_api_error(conn, method_, outcome.code, outcome.title, outcome.detail)
    }
  }
}

///|
async fn mooncode_task_control_post(
  daemon : Json,
  endpoint : String,
  payload : Json,
) -> Result[Json, String] {
  if json_string(payload, "action", default="") != "load_image" {
    return moonclaw_post_json(daemon, endpoint, payload)
  }
  let config = match moonclaw_load_control_config(daemon) {
    Ok(config) => config
    Err(error) => return Err(error)
  }
  let port = json_int(daemon, "port", default=0)
  let (response, data) = @http.post(
    "http://127.0.0.1:\{port}\{endpoint}",
    payload,
    headers=moonclaw_control_headers(config, content_type=true),
  ) catch {
    _ => return Err("Could not load the generated image")
  }
  let text = match
    moonclaw_control_response_text(
      response,
      data,
      config,
      "image download",
      max_chars=32_000_000,
    ) {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  let result = @json.parse(text) catch {
    _ => return Err("Image response was unreadable")
  }
  Ok(result)
}
