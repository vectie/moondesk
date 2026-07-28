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
fn decode_mooncode_session_listing(
  payload : Json,
) -> Result[Array[MoonCodeSession], String] {
  match @mooncode_core.decode_mooncode_session_listing(payload) {
    Supported(summaries) => {
      let sessions : Array[MoonCodeSession] = []
      for summary in summaries {
        try
          @json.from_json(
            @mooncode_core.encode_mooncode_session_summary(summary),
          )
        catch {
          _ => return Err("Invalid MoonCode session listing")
        } noraise {
          session => sessions.push(session)
        }
      }
      Ok(sessions)
    }
    UnsupportedVersion(version) =>
      Err("Unsupported MoonCode session listing contract version \{version}")
    Malformed(error) => Err(error)
  }
}

///|
fn fetch_active_mooncode_sessions_cmd(
  dispatch : Dispatch[Msg],
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(@desk.mooncode_session_listing_url(workspace_id)).expect_json(result => {
    let decoded = match result {
      Ok(payload) => decode_mooncode_session_listing(payload)
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedMoonCodeSessions(decoded))
  })
}

///|
fn fetch_archived_mooncode_sessions_cmd(
  dispatch : Dispatch[Msg],
) -> @rabbita.Cmd {
  @http.get(@desk.mooncode_archived_session_listing_url()).expect_json(result => {
    let decoded = match result {
      Ok(payload) => decode_mooncode_session_listing(payload)
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedMoonCodeArchivedSessions(decoded))
  })
}
