///|
fn fetch_mooncode_sessions_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  @rabbita.batch([
    fetch_active_mooncode_sessions_cmd(dispatch, workspace_id),
    fetch_archived_mooncode_sessions_cmd(dispatch),
  ])
}

///|
fn fetch_active_mooncode_sessions_cmd(
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
fn fetch_archived_mooncode_sessions_cmd(
  dispatch : Dispatch[Msg],
) -> @rabbita.Cmd {
  @http.get(@desk.mooncode_archived_session_listing_url()).expect_json(result => {
    dispatch(
      LoadedMoonCodeArchivedSessions(
        http_result(result, "Invalid archived MoonCode session listing"),
      ),
    )
  })
}
