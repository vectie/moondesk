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
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(@desk.mooncode_session_url(session_id) + "?format=chat").expect_json(result => {
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
  fetch_mooncode_session_cmd(dispatch, model.selected_mooncode_session_id)
}
