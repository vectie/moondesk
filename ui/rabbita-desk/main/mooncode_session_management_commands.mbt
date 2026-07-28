///|
fn decode_mooncode_lifecycle_result(
  payload : Json,
  session_id : String,
) -> Result[@mooncode_core.MoonCodeLifecycleResult, String] {
  guard @mooncode_core.MoonCodeSessionId::parse(session_id) is Some(expected) else {
    return Err("Could not manage MoonCode session")
  }
  match
    @mooncode_core.decode_mooncode_lifecycle_result(
      payload,
      expected_session_id=expected,
    ) {
    Ok(result) => Ok(result)
    Err(_) => Err("MoonClaw returned an invalid session management result")
  }
}

///|
fn manage_mooncode_session_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
  action : @mooncode_core.MoonCodeLifecycleAction,
) -> @rabbita.Cmd {
  let body = @mooncode_core.encode_mooncode_lifecycle_action(action)
  @http.post(@desk.mooncode_session_lifecycle_url(session_id))
  .with_json(body)
  .expect_json(result => {
    dispatch(
      ManagedMoonCodeSession(
        match http_result(result, "Could not manage MoonCode session") {
          Ok(payload) => decode_mooncode_lifecycle_result(payload, session_id)
          Err(error) => Err(error)
        },
      ),
    )
  })
}
