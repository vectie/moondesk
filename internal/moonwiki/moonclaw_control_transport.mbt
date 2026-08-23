///|
const MoonClawControlResponseChars : Int = 2_000_000

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
  content_type? : Bool = false,
) -> Map[String, String] {
  let headers = {
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
  guard text.length() <= MoonClawControlResponseChars else {
    return Err("MoonClaw \{operation} exceeded the response limit")
  }
  guard !text.contains(config.auth_token) else {
    return Err("MoonClaw \{operation} returned an invalid control response")
  }
  Ok(text)
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
