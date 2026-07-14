///|
fn fetch_mooncode_sessions_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(@desk.mooncode_session_listing_url(workspace_id)).expect_json(result => {
    dispatch(
      LoadedMoonCodeSessions(
        http_result(result, "Invalid MoonCode session listing"),
      ),
    )
  })
}

///|
fn fetch_mooncode_session_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
) -> @rabbita.Cmd {
  fetch_mooncode_session_revision_cmd(dispatch, session_id, 0)
}

///|
fn fetch_mooncode_session_revision_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
  known_revision : Int,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(@desk.mooncode_session_chat_url(session_id, known_revision)).expect_json(result => {
      dispatch(
        LoadedMoonCodeSession(
          session_id,
          http_result(result, "Invalid MoonCode session"),
        ),
      )
    },
  )
}

///|
fn fetch_selected_mooncode_session_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let session_id = model.selected_mooncode_session_id
  let revision = match
    mooncode_find_session(model.mooncode_sessions, session_id) {
    Some(session) => mooncode_session_conversation_revision(session)
    None => 0
  }
  fetch_mooncode_session_revision_cmd(dispatch, session_id, revision)
}
