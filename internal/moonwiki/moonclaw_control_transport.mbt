///|
fn moonclaw_status_probe(
  port : Int32,
  running : Bool,
  info_path : String,
) -> Json {
  { "port": port, "running": running, "info_path": info_path }
}

///|
const MoonClawControlResponseChars : Int32 = 2_000_000

///|
fn moonclaw_control_config_for_daemon(
  daemon : Json,
  loaded : SourceSemanticsSandboxClientConfig?,
) -> Result[SourceSemanticsSandboxClientConfig, String] {
  guard loaded is Some(config) &&
    source_semantics_safe_hex(config.instance_id, 32) &&
    source_semantics_safe_hex(config.auth_token, 64) &&
    json_bool(daemon, "running", default=false) &&
    json_int(daemon, "port", default=0) > 0 &&
    json_string(daemon, "info_path", default="") ==
    moonclaw_daemon_info_path(config.workspace_root) else {
    return Err("MoonClaw private control authentication is unavailable")
  }
  Ok(config)
}

///|
async fn moonclaw_load_control_config(
  daemon : Json,
) -> Result[SourceSemanticsSandboxClientConfig, String] {
  let loaded = source_semantics_load_sandbox_client_config() catch {
    _ => return Err("MoonClaw private control authentication is unavailable")
  }
  moonclaw_control_config_for_daemon(daemon, loaded)
}

///|
fn moonclaw_control_headers(
  config : SourceSemanticsSandboxClientConfig,
  content_type~ : Bool = false,
) -> @http.Headers {
  let headers : @http.Headers = {
    "X-MoonClaw-Execution-Token": config.auth_token,
    "X-MoonClaw-Instance-ID": config.instance_id,
  }
  if content_type {
    headers["Content-Type"] = "application/json"
  }
  headers
}

///|
fn moonclaw_control_response_text(
  response : @http.Response,
  data : &@io.Data,
  config : SourceSemanticsSandboxClientConfig,
  operation : String,
  max_chars~ : Int32 = MoonClawControlResponseChars,
) -> Result[String, String] {
  guard response.headers.get("x-moonclaw-instance-id") ==
    Some(config.instance_id) else {
    return Err("MoonClaw \{operation} returned an unbound control response")
  }
  guard response.code >= 200 && response.code <= 299 else {
    // A hostile or stale localhost service must not be able to reflect the
    // private request credential through its error body into browser state.
    return Err("MoonClaw \{operation} returned HTTP \{response.code}")
  }
  let text = data.text() catch {
    _ => return Err("MoonClaw \{operation} returned an unreadable response")
  }
  guard text.length() <= max_chars else {
    return Err("MoonClaw \{operation} exceeded the response limit")
  }
  guard !text.contains(config.auth_token) else {
    return Err("MoonClaw \{operation} returned an invalid control response")
  }
  Ok(text)
}

///|
async fn moonclaw_get_media_with_control_config(
  daemon : Json,
  path : String,
  config : SourceSemanticsSandboxClientConfig,
) -> Result[Json, String] {
  let port = json_int(daemon, "port", default=0)
  guard port > 0 &&
    path.has_prefix("/v1/code/sessions/") &&
    path.contains("/media/") else {
    return Err("MoonClaw media endpoint is not available")
  }
  let (response, data) = @http.get(
    "http://127.0.0.1:\{port}\{path}",
    headers=moonclaw_control_headers(config),
  ) catch {
    _ => return Err("MoonClaw media GET failed")
  }
  let body = match
    moonclaw_control_response_text(
      response,
      data,
      config,
      "media GET",
      max_chars=11 * 1024 * 1024 + 1024,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(
    @json.parse(body) catch {
      _ => return Err("MoonClaw media returned invalid JSON")
    },
  )
}

///|
async fn moonclaw_get_json_with_control_config(
  daemon : Json,
  path : String,
  config : SourceSemanticsSandboxClientConfig,
) -> Result[Json, String] {
  let port = json_int(daemon, "port", default=0)
  guard port > 0 && path.has_prefix("/v1/") else {
    return Err("MoonClaw control endpoint is not available")
  }
  let (response, data) = @http.get(
    "http://127.0.0.1:\{port}\{path}",
    headers=moonclaw_control_headers(config),
  ) catch {
    _ => return Err("MoonClaw GET \{path} failed")
  }
  let text = match
    moonclaw_control_response_text(response, data, config, "GET \{path}") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let payload = @json.parse(text) catch {
    _ => return Err("MoonClaw GET \{path} returned invalid JSON")
  }
  Ok(payload)
}

///|
async fn moonclaw_get_text_with_control_config(
  daemon : Json,
  path : String,
  config : SourceSemanticsSandboxClientConfig,
) -> Result[String, String] {
  let port = json_int(daemon, "port", default=0)
  guard port > 0 && path.has_prefix("/v1/") else {
    return Err("MoonClaw control endpoint is not available")
  }
  let (response, data) = @http.get(
    "http://127.0.0.1:\{port}\{path}",
    headers=moonclaw_control_headers(config),
  ) catch {
    _ => return Err("MoonClaw GET \{path} failed")
  }
  moonclaw_control_response_text(response, data, config, "GET \{path}")
}

///|
async fn moonclaw_post_json_with_control_config(
  daemon : Json,
  path : String,
  body : Json,
  config : SourceSemanticsSandboxClientConfig,
) -> Result[Json, String] {
  let port = json_int(daemon, "port", default=0)
  guard port > 0 && path.has_prefix("/v1/") else {
    return Err("MoonClaw control endpoint is not available")
  }
  let (response, data) = @http.post(
    "http://127.0.0.1:\{port}\{path}",
    body,
    headers=moonclaw_control_headers(config, content_type=true),
  ) catch {
    _ => return Err("MoonClaw POST \{path} failed")
  }
  let text = match
    moonclaw_control_response_text(response, data, config, "POST \{path}") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let payload = @json.parse(text) catch {
    _ => return Err("MoonClaw POST \{path} returned invalid JSON")
  }
  Ok(payload)
}

///|
/// Read the existing resumable stream's first metadata frame before submission.
/// Its head cursor is signed by the daemon and scoped to this task.
async fn moonclaw_general_task_head_cursor(
  daemon : Json,
  task_id : String,
) -> Result[String, String] {
  let config = match moonclaw_load_control_config(daemon) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let port = json_int(daemon, "port", default=0)
  let (response, client) = @http.get_stream(
    "http://127.0.0.1:\{port}/v1/task/\{task_id}/events/resume?cursor=start&replay_limit=1",
    headers=moonclaw_control_headers(config),
  ) catch {
    _ => return Err("MoonClaw turn boundary could not be read")
  }
  defer client.close()
  if response.code != 200 ||
    response.headers.get("x-moonclaw-instance-id") != Some(config.instance_id) {
    return Err("MoonClaw turn boundary returned an unbound control response")
  }
  let frame = client.read_until("\n\n") catch {
    _ => return Err("MoonClaw turn boundary stream could not be read")
  }
  guard frame is Some(frame) else {
    return Err("MoonClaw turn boundary metadata is unavailable")
  }
  for line in frame.split("\n") {
    if line.has_prefix("data:") {
      let value = @json.parse(line[5:].trim().to_owned()) catch {
        _ => return Err("MoonClaw turn boundary metadata is invalid")
      }
      if value
        is {
          "contract": String("moonclaw-task-stream.v2"),
          "kind": String("meta"),
          "head_cursor": String(cursor),
          ..
        } &&
        cursor.has_prefix("mct2.") {
        return Ok(cursor)
      }
    }
  }
  Err("MoonClaw turn boundary requires the updated task stream")
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

///|
async fn mooncode_continuation_post_exact(
  daemon : Json,
  path : String,
  body : String,
) -> Result[Json, String] {
  let config = match moonclaw_load_control_config(daemon) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let port = json_int(daemon, "port", default=0)
  if port <= 0 {
    return Err("MoonClaw control endpoint is unavailable")
  }
  let (response, data) = @http.post(
    "http://127.0.0.1:\{port}\{path}",
    body,
    headers=moonclaw_control_headers(config, content_type=true),
  ) catch {
    _ => return Err("MoonClaw continuation POST failed")
  }
  let text = match
    moonclaw_control_response_text(response, data, config, "continuation POST") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(
    @json.parse(text) catch {
      _ => return Err("MoonClaw returned invalid continuation acknowledgement")
    },
  )
}
