///|
fn fetch_mooncode_sessions_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  let query = if workspace_id == "" {
    ""
  } else {
    "?workspace=\{encode_component(workspace_id)}"
  }
  @http.get(
    "/api/mooncode/sessions\{query}",
    expect=Json(fn(result) { dispatch(LoadedMoonCodeSessions(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode session listing")
      }
    }),
  )
}

///|
fn fetch_mooncode_stream_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  since : Int,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  let expect : @http.Expecting[@rabbita.Cmd, Unit] = Text(fn(result) {
      let decoded : Result[MoonCodeStreamPoll, String] = match result {
        Ok(text) => parse_mooncode_stream_text(text)
        Err(error) => Err(error)
      }
      dispatch(LoadedMoonCodeStream(session_id, decoded))
    })
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/stream?format=jsonl&since=\{since}&live=true&timeout_ms=1000&poll_ms=100",
    expect~,
  )
}

///|
fn save_mooncode_stream_checkpoint_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  next_since : Int,
) -> @rabbita.Cmd {
  if session_id == "" || next_since <= 0 {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/stream-state",
    Json({
      "consumer_id": "moondesk-ui",
      "last_seen_sequence": next_since,
    }),
    expect=Json(
      fn(result) { dispatch(SavedMoonCodeStreamCheckpoint(session_id, result)) },
      json => {
        Ok(@json.from_json(json)) catch {
          _ => Err("Could not save MoonCode stream checkpoint")
        }
      },
    ),
  )
}
