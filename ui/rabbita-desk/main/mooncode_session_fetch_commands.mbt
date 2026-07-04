///|
fn fetch_mooncode_sessions_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  let query = if workspace_id == "" {
    ""
  } else {
    "?workspace=\{encode_component(workspace_id)}"
  }
  @http.get("/api/mooncode/sessions\{query}").expect_json(result => {
    dispatch(
      LoadedMoonCodeSessions(
        http_result(result, "Invalid MoonCode session listing"),
      ),
    )
  })
}

///|
fn fetch_mooncode_stream_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
  since : Int,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/stream?format=jsonl&since=\{since}&live=true&timeout_ms=1000&poll_ms=100",
  ).expect_text(result => {
    let decoded : Result[MoonCodeStreamPoll, String] = match result {
      Ok(text) => parse_mooncode_stream_text(text)
      Err(_) => Err("Could not load MoonCode stream")
    }
    dispatch(LoadedMoonCodeStream(session_id, decoded))
  })
}

///|
fn save_mooncode_stream_checkpoint_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
  next_since : Int,
) -> @rabbita.Cmd {
  if session_id == "" || next_since <= 0 {
    return @rabbita.none
  }
  let body : Json = {
    "consumer_id": "moondesk-ui",
    "last_seen_sequence": next_since,
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/stream-state",
  )
  .with_json(body)
  .expect_json(result => {
    dispatch(
      SavedMoonCodeStreamCheckpoint(
        session_id,
        http_result(result, "Could not save MoonCode stream checkpoint"),
      ),
    )
  })
}
