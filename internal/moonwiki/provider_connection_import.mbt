///|
priv struct OpenAiConnectionImport {
  version : String
  api : String
  base_url : String
  api_key : String
  model : String
  max_output_tokens : Int32
} derive(FromJson)

///|
fn connection_url_parts(value : String) -> (String, String)? {
  if value.length() > 2048 ||
    value.trim() != value ||
    value.contains_char('@') ||
    value.contains_char('?') ||
    value.contains_char('#') ||
    value.contains_char('\\') ||
    value.any(c => c <= ' ' || c > '\u{7f}') {
    return None
  }
  let scheme = if value.has_prefix("https://") {
    "https://"
  } else if value.has_prefix("http://") {
    "http://"
  } else {
    return None
  }
  let rest = value[scheme.length():]
  let boundary = rest.find("/").unwrap_or(rest.length())
  let authority = rest[:boundary].to_owned()
  if authority.is_empty() ||
    !authority.all(c => {
      (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      c.is_ascii_digit() ||
      ['.', '-', ':', '[', ']'].contains(c)
    }) {
    return None
  }
  let loopback = ["localhost", "127.0.0.1", "[::1]"].any(host => {
    authority == host ||
    (
      authority.has_prefix(host + ":") &&
      authority[host.length() + 1:].all(c => c.is_ascii_digit()) &&
      authority.length() > host.length() + 1
    )
  })
  if scheme == "http://" && !loopback {
    return None
  }
  Some((scheme + authority, rest[boundary:].trim_end(chars="/").to_owned()))
}

///|
fn valid_openai_connection_import(value : OpenAiConnectionImport) -> Bool {
  value.version == "openai.connection.v1" &&
  value.api == "chat.completions" &&
  connection_url_parts(value.base_url) is Some(_) &&
  !value.base_url.has_suffix("/chat/completions") &&
  value.model.length() > 0 &&
  value.model.length() <= 256 &&
  value.model.all(c => c > ' ' && c <= '~') &&
  value.api_key.length() > 0 &&
  value.api_key.length() <= 512 &&
  value.api_key.all(c => c > ' ' && c <= '~') &&
  !value.api_key.has_prefix("api-key-") &&
  value.max_output_tokens >= 1 &&
  value.max_output_tokens <= 131072
}

///|
async fn read_openai_connection_import(
  body : &@io.Reader,
) -> OpenAiConnectionImport? {
  let bytes = @buffer.Buffer(size_hint=1024)
  for ;; {
    guard body.read_some(max_len=(8193 - bytes.length()).min(1024))
      is Some(chunk) else {
      break
    }
    bytes.write_bytes(chunk)
    if bytes.length() > 8192 {
      return None
    }
  }
  let value : OpenAiConnectionImport = @json.from_json(
    @json.parse(@encoding/utf8.decode(bytes.to_bytes())),
  ) catch {
    _ => return None
  }
  if valid_openai_connection_import(value) {
    Some(value)
  } else {
    None
  }
}

///|
fn imported_connection_provider_id(value : OpenAiConnectionImport) -> String {
  let hash = @crypto.bytes_to_hex_string(
    @crypto.sha256(
      @encoding/utf8.encode(value.base_url + "\n" + value.model).to_fixedarray(),
    ),
  )
  "imported-openai-" + hash[:16].to_owned()
}

///|
fn openai_connection_import_json(value : OpenAiConnectionImport) -> Json {
  {
    "version": value.version,
    "api": value.api,
    "base_url": value.base_url,
    "api_key": value.api_key,
    "model": value.model,
    "max_output_tokens": value.max_output_tokens,
  }
}

///|
fn imported_connection_response(
  value : OpenAiConnectionImport,
  response : Json,
) -> Result[Unit, String] {
  guard response
    is {
      "ok": true,
      "status": "connected",
      "model": String(model),
      "provider_id": String(provider_id),
      ..
    } &&
    model == value.model &&
    provider_id == imported_connection_provider_id(value) else {
    return Err("MoonClaw did not confirm the imported connection")
  }
  Ok(())
}

///|
/// Claw owns transient validation and all subsequent MoonGate mutations.
/// Only a bound control response can confirm the existing import result.
async fn install_openai_connection_import_with_control_config(
  daemon : Json,
  value : OpenAiConnectionImport,
  config : SourceSemanticsSandboxClientConfig,
) -> Result[Unit, String] {
  guard valid_openai_connection_import(value) else {
    return Err("Invalid OpenAI connection settings")
  }
  // Let Claw's 30-second operation deadline return its sanitized response.
  @async.with_timeout(35000, () => {
    match
      moonclaw_post_json_with_control_config(
        daemon,
        "/v1/provider-connections/import",
        openai_connection_import_json(value),
        config,
      ) {
      Ok(response) => imported_connection_response(value, response)
      Err(_) =>
        Err(
          "Could not import the provider connection through MoonClaw. Check service readiness and connection access.",
        )
    }
  }) catch {
    _ =>
      Err(
        "Could not import the provider connection through MoonClaw. Check service readiness and connection access.",
      )
  }
}

///|
async fn install_openai_connection_import(
  workspace_root : String,
  value : OpenAiConnectionImport,
) -> Result[Unit, String] {
  guard valid_openai_connection_import(value) else {
    return Err("Invalid OpenAI connection settings")
  }
  let daemon = moonclaw_model_route_daemon_candidate(workspace_root)
  guard json_bool(daemon, "running", default=false) else {
    return Err("MoonClaw is unavailable for provider connection import")
  }
  let config = match moonclaw_load_control_config(daemon) {
    Ok(config) => config
    Err(_) =>
      return Err("MoonClaw private control authentication is unavailable")
  }
  install_openai_connection_import_with_control_config(daemon, value, config)
}

///|
async fn handle_openai_connection_import(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  guard read_openai_connection_import(body) is Some(value) else {
    send_api_json_error(conn, method_, 400, "Bad Request", {
      "error": "Invalid OpenAI connection settings",
    })
    return
  }
  match install_openai_connection_import(workspace_root, value) {
    Ok(_) =>
      send_json(conn, method_, {
        "ok": true,
        "status": "connected",
        "model": value.model,
        "provider_id": imported_connection_provider_id(value),
      })
    Err(error) =>
      send_api_json_error(conn, method_, 502, "Bad Gateway", { "error": error })
  }
}
