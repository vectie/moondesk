///|
const DesktopProviderHandoffMaximumBytes : Int = 2_048

///|
priv struct DesktopProviderHandoffRequest {
  client_id : String
  handoff_code : String
} derive(FromJson)

///|
async fn read_desktop_provider_handoff_body(
  body : &@io.Reader,
) -> Result[DesktopProviderHandoffRequest, String] {
  let output = @buffer.Buffer(size_hint=512)
  for ;; {
    let remaining = DesktopProviderHandoffMaximumBytes - output.length() + 1
    guard body.read_some(max_len=remaining.min(1_024)) is Some(chunk) else {
      break
    }
    if output.length() + chunk.length() > DesktopProviderHandoffMaximumBytes {
      return Err("provider handoff request exceeds the size limit")
    }
    output.write_bytes(chunk)
  }
  let json = @json.parse(@encoding/utf8.decode(output.to_bytes())) catch {
    _ => return Err("provider handoff request is not valid JSON")
  }
  let request : DesktopProviderHandoffRequest = @json.from_json(json) catch {
    _ => return Err("provider handoff request has an invalid shape")
  }
  Ok(request)
}

///|
fn valid_handoff_shape(request : DesktopProviderHandoffRequest) -> Bool {
  request.client_id.length() > 0 &&
  request.client_id.length() <= 256 &&
  request.client_id.all(character => {
    (character >= 'a' && character <= 'z') ||
    (character >= 'A' && character <= 'Z') ||
    (character >= '0' && character <= '9') ||
    ['-', '_', '.', ':'].contains(character)
  }) &&
  request.handoff_code.length() == 69 &&
  request.handoff_code.has_prefix("lnxc_") &&
  request.handoff_code[5:].all(character => character.is_ascii_hexdigit())
}

///|
fn desktop_provider_handoff_request_json(
  request : DesktopProviderHandoffRequest,
) -> Json {
  {
    "contract": "moonclaw.provider-handoff.v1",
    "client_id": request.client_id,
    "handoff_code": request.handoff_code,
  }
}

///|
async fn handle_desktop_provider_handoff(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let request = match read_desktop_provider_handoff_body(body) {
    Ok(value) if valid_handoff_shape(value) => value
    _ => {
      send_api_json_error(conn, method_, 400, "Bad Request", {
        "error": "Invalid provider handoff",
      })
      return
    }
  }
  let daemon = moonclaw_model_route_daemon_candidate(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    send_api_json_error(conn, method_, 503, "Service Unavailable", {
      "error": "MoonClaw is unavailable for provider handoff",
    })
    return
  }
  match
    moonclaw_post_json(
      daemon,
      "/v1/provider-handoff",
      desktop_provider_handoff_request_json(request),
    ) {
    Err(error) =>
      send_api_json_error(conn, method_, 503, "Service Unavailable", {
        "error": error,
      })
    Ok(response) => send_json(conn, method_, response)
  }
}
