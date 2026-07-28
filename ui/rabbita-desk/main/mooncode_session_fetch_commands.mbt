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
fn decode_mooncode_selected_session(
  payload : Json,
) -> Result[MoonCodeSession, String] {
  match @mooncode_core.decode_mooncode_selected_session(payload) {
    Supported(summary) =>
      try
        @json.from_json(@mooncode_core.encode_mooncode_session_summary(summary))
      catch {
        _ => Err("Invalid MoonCode selected session")
      } noraise {
        session => Ok(session)
      }
    UnsupportedVersion(version) =>
      Err("Unsupported MoonCode selected session contract version \{version}")
    Malformed(error) => Err(error)
  }
}

///|
fn fetch_mooncode_selected_session_cmd(
  dispatch : Dispatch[Msg],
  session_id : String,
) -> @rabbita.Cmd {
  @http.get(@desk.mooncode_session_url(session_id)).expect_json(result => {
    let decoded = match result {
      Ok(payload) => decode_mooncode_selected_session(payload)
      Err(error) => Err(error.to_string())
    }
    dispatch(LoadedMoonCodeSelectedSession(session_id, decoded))
  })
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
