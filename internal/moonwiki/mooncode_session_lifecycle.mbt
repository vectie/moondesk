///|
fn mooncode_session_lifecycle_failure_message(
  failure : @mooncode_core.MoonCodeLifecycleFailure,
) -> String {
  match failure {
    MalformedAction => "Unsupported MoonCode session lifecycle action"
    UnsupportedAction(_) => "Unsupported MoonCode session lifecycle action"
    InvalidTitle => "A non-empty session title is required"
    TitleTooLong => "Session titles may not exceed 160 characters"
    NotFound => "Unknown MoonCode session"
    Conflict => "MoonCode session lifecycle conflict"
    RuntimeUnavailable => "MoonClaw session management is unavailable"
    RuntimeFailure => "MoonClaw session lifecycle failed"
    InvalidResult(message) => message
    UnsupportedProtocol(protocol) =>
      "Unsupported MoonCode lifecycle protocol \{protocol}"
    WrongOwner(owner) => "Unexpected MoonCode lifecycle owner \{owner}"
    WrongSession(expected~, actual~) =>
      "MoonCode lifecycle session mismatch: expected \{expected}, got \{actual}"
  }
}

///|
fn mooncode_session_lifecycle_decode_action(
  payload : Json,
) -> Result[@mooncode_core.MoonCodeLifecycleAction, String] {
  match @mooncode_core.decode_mooncode_lifecycle_action(payload) {
    Ok(action) => Ok(action)
    Err(failure) => Err(mooncode_session_lifecycle_failure_message(failure))
  }
}

///|
fn mooncode_session_lifecycle_native_body(
  action : @mooncode_core.MoonCodeLifecycleAction,
  workspace_root : String,
) -> Json {
  @mooncode_core.encode_mooncode_lifecycle_action(
    action,
    book_root=workspace_root,
  )
}

///|
priv struct MoonCodeLifecycleRouteFailure {
  code : Int
  title : String
  failure : @mooncode_core.MoonCodeLifecycleFailure
  stop_reason : @mooncode_core.MoonCodeLifecycleStopReason?
  detail : String
}

///|
fn mooncode_session_lifecycle_route_failure(
  code : Int,
  detail : String,
) -> MoonCodeLifecycleRouteFailure {
  match code {
    404 =>
      { code, title: "Not Found", failure: NotFound, stop_reason: None, detail }
    409 =>
      {
        code,
        title: "Conflict",
        failure: Conflict,
        stop_reason: if detail.contains(
            "This MoonCode session is still running; stop it before changing its storage",
          ) {
          Some(SessionActive)
        } else {
          None
        },
        detail,
      }
    503 =>
      {
        code,
        title: "Service Unavailable",
        failure: RuntimeUnavailable,
        stop_reason: None,
        detail,
      }
    _ =>
      {
        code: 502,
        title: "Bad Gateway",
        failure: RuntimeFailure,
        stop_reason: None,
        detail,
      }
  }
}

///|
fn mooncode_session_lifecycle_proxy_failure(
  error : String,
) -> MoonCodeLifecycleRouteFailure {
  if error.contains(" returned 409:") {
    mooncode_session_lifecycle_route_failure(409, error)
  } else if error.contains(" returned 404:") {
    mooncode_session_lifecycle_route_failure(404, error)
  } else {
    mooncode_session_lifecycle_route_failure(502, error)
  }
}

///|
fn mooncode_session_lifecycle_result(
  payload : Json,
  session_id : String,
) -> Result[@mooncode_core.MoonCodeLifecycleResult, String] {
  guard @mooncode_core.MoonCodeSessionId::parse(session_id) is Some(expected) else {
    return Err("Invalid MoonCode session identifier")
  }
  match
    @mooncode_core.decode_mooncode_lifecycle_result(
      payload,
      expected_session_id=expected,
    ) {
    Ok(result) => Ok(result)
    Err(failure) => Err(mooncode_session_lifecycle_failure_message(failure))
  }
}

///|
async fn handle_mooncode_session_lifecycle(
  workspace_root : String,
  session_id : String,
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
  let action = match mooncode_session_lifecycle_decode_action(payload) {
    Ok(value) => value
    Err(error) => {
      send_api_error(conn, method_, 400, "Bad Request", error)
      return
    }
  }
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="manage-session",
  )
  if !json_bool(daemon, "running", default=false) {
    let outcome = mooncode_session_lifecycle_route_failure(
      503,
      json_string(
        daemon,
        "message",
        default="MoonClaw session management is unavailable",
      ),
    )
    send_api_error(conn, method_, outcome.code, outcome.title, outcome.detail)
    return
  }
  let endpoint = @mooncode.moonclaw_native_session_lifecycle_endpoint(
    session_id,
  )
  match
    moonclaw_post_json(
      daemon,
      endpoint,
      mooncode_session_lifecycle_native_body(action, workspace_root),
    ) {
    Ok(result) =>
      match mooncode_session_lifecycle_result(result, session_id) {
        Ok(_) => send_json(conn, method_, result)
        Err(error) => send_api_error(conn, method_, 502, "Bad Gateway", error)
      }
    Err(error) => {
      let outcome = mooncode_session_lifecycle_proxy_failure(error)
      send_api_error(conn, method_, outcome.code, outcome.title, outcome.detail)
    }
  }
}
