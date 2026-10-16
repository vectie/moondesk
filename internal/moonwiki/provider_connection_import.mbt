///|
priv struct OpenAiConnectionImport {
  version : String
  api : String
  base_url : String
  api_key : String
  model : String
  max_output_tokens : Int
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
/// Bounded transport deliberately discards upstream error bodies, which may
/// reflect credentials. Neither request nor response bodies are logged.
async fn connection_request_json(
  origin : String,
  path : String,
  headers : @http.Headers,
  payload : Json?,
) -> Json {
  @async.with_timeout(30000, () => {
    let client = @http.Client(origin, headers~)
    defer client.close()
    let response = match payload {
      Some(value) => client.post(path, value)
      None => client.get(path)
    }
    if response.code < 200 || response.code >= 300 {
      raise Failure("Connection service rejected the request")
    }
    let body = @buffer.Buffer(size_hint=1024)
    for ;; {
      guard client.read_some(max_len=(65537 - body.length()).min(8192))
        is Some(chunk) else {
        break
      }
      body.write_bytes(chunk)
      if body.length() > 65536 {
        raise Failure("Connection service response exceeded its limit")
      }
    }
    if body.length() == 0 {
      Json::empty_object()
    } else {
      @json.parse(@encoding/utf8.decode(body.to_bytes()))
    }
  })
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
fn imported_connection_provider(value : OpenAiConnectionImport) -> Json {
  {
    "appType": "openclaw",
    "id": imported_connection_provider_id(value),
    "name": "Imported " + value.model,
    "enabled": true,
    "providerType": "openai-compatible",
    "apiFormat": "openai_chat",
    "baseUrl": value.base_url,
    "apiKey": value.api_key,
    "defaultModel": value.model,
    "notes": "Imported from a reviewed OpenAI connection descriptor",
  }
}

///|
fn connection_provider_exists(value : Json, id : String) -> Bool {
  match value {
    Array(values) => values.any(value => connection_provider_exists(value, id))
    Object(fields) =>
      fields.get("id") == Some(Json::string(id)) ||
      fields.values().any(value => connection_provider_exists(value, id))
    _ => false
  }
}

///|
async fn install_openai_connection_import(
  workspace_root : String,
  value : OpenAiConnectionImport,
) -> Result[Unit, String] {
  let mut stage = "model discovery"
  try {
    guard connection_url_parts(value.base_url) is Some((origin, prefix)) else {
      return Err("Invalid provider URL")
    }
    let models = connection_request_json(
      origin,
      prefix + "/models",
      {
        "Authorization": "Bearer " + value.api_key,
        "Accept": "application/json",
      },
      None,
    )
    guard models is { "data": Array(rows), .. } &&
      rows.any(row => row is { "id": String(model), .. } && model == value.model) else {
      return Err("The key cannot access the selected model")
    }
    stage = "MoonGate discovery"
    let status = read_json_file_or_object(
      @pathx.join(
        workspace_context(workspace_root).state_dir,
        "suite-status.json",
      ),
    )
    guard status
      is {
        "contract": "moon.suite.status.v2",
        "service": "moongate",
        "manifest": {
          "contract": "moon.suite.service.v1",
          "service": "moongate",
          "baseUrl": String(url),
          ..
        },
        ..
      } &&
      connection_url_parts(url) is Some((gate_origin, gate_prefix)) else {
      return Err("MoonGate service is not configured")
    }
    let headers : @http.Headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
    }
    stage = "local MoonGate authentication"
    let configured_token = match @env.get_env_var("MOONGATE_CONTROL_TOKEN") {
      Some(token) if !token.trim().is_empty() => token
      _ =>
        @fs.read_file(
          moonsuite_product_artifact_for_workspace_root(
            workspace_context(workspace_root).suite_root,
            "moongate",
            "control-token",
          ),
        ).text() catch {
          _ => ""
        }
    }
    let control_token = if configured_token.trim().is_empty() {
      connection_local_control_token(gate_origin, gate_prefix)
    } else {
      configured_token.trim().to_owned()
    }
    if !control_token.is_empty() {
      headers["x-moongate-control-token"] = control_token.trim().to_owned()
    }
    configure_imported_connection(gate_origin, gate_prefix, headers, value)
  } catch {
    _ =>
      Err(
        "Could not complete " +
        stage +
        ". Check service readiness and connection access.",
      )
  }
}

///|
async fn configure_imported_connection(
  gate_origin : String,
  gate_prefix : String,
  headers : @http.Headers,
  value : OpenAiConnectionImport,
) -> Result[Unit, String] {
  let mut stage = "MoonGate provider listing"
  try {
    let listed = connection_request_json(
      gate_origin,
      gate_prefix + "/providers?appType=openclaw",
      headers,
      None,
    )
    let id = imported_connection_provider_id(value)
    let path = if connection_provider_exists(listed, id) {
      "/providers/update"
    } else {
      "/providers"
    }
    stage = "provider configuration"
    let _ = connection_request_json(
      gate_origin,
      gate_prefix + path,
      headers,
      Some(imported_connection_provider(value)),
    )
    stage = "provider activation"
    let _ = connection_request_json(
      gate_origin,
      gate_prefix + "/providers/switch",
      headers,
      Some({ "appType": "openclaw", "id": id }),
    )
    stage = "runtime binding"
    let _ = connection_request_json(
      gate_origin,
      gate_prefix + "/bindings",
      headers,
      Some({ "appType": "moondesk", "providerId": id }),
    )
    Ok(())
  } catch {
    _ =>
      Err(
        "Could not complete " +
        stage +
        ". Check service readiness and connection access.",
      )
  }
}

///|
/// MoonGate's published bootstrap is restricted to a trusted local origin.
/// Hosted workspaces may supply the token to the gateway process only.
/// Keep the resolved token request-local and never proxy it to the browser.
async fn connection_local_control_token(
  origin : String,
  prefix : String,
) -> String {
  guard origin.has_prefix("http://127.0.0.1:") ||
    origin.has_prefix("http://localhost:") ||
    origin.has_prefix("http://[::1]:") else {
    raise Failure("Configure remote MoonGate control access")
  }
  let response = connection_request_json(
    origin,
    prefix + "/control/bootstrap",
    {
      "Origin": origin,
      "Sec-Fetch-Site": "same-origin",
      "Accept": "application/json",
    },
    None,
  )
  guard response is { "token": String(token), .. } &&
    !token.is_empty() &&
    token.length() <= 4096 &&
    token.all(c => c > ' ' && c <= '~') else {
    raise Failure("Local MoonGate control is unavailable")
  }
  token
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
