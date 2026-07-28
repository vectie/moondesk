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
fn mooncode_local_session_from_summary(
  summary : @mooncode_core.MoonCodeSessionSummary,
  conversation : @mooncode_core.MoonCodeConversation?,
) -> MoonCodeSession {
  let local_summary = match summary.extensions.get("mooncode_summary") {
    Some(value) =>
      try @json.from_json(value) catch {
        _ => { event_count: 0, verified_test_count: 0, pending_diff_count: 0 }
      }
    None => { event_count: 0, verified_test_count: 0, pending_diff_count: 0 }
  }
  let runtime_detail = match summary.extensions.get("mooncode_runtime_detail") {
    Some(String(value)) => Some(value)
    _ => None
  }
  let canonical_unchanged = match summary.extensions.get("canonical_unchanged") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  {
    id: summary.id.to_string(),
    workspace_id: summary.workspace_id,
    workspace_name: summary.workspace_name,
    cwd: summary.cwd,
    source: summary.source,
    mooncode_runtime_session_id: summary.runtime_session_id,
    title: summary.title,
    updated_at: summary.updated_at,
    model: summary.model,
    status: summary.status.to_string(),
    queued_count: summary.queued_count,
    last_message: summary.last_message,
    mooncode_runtime_detail: runtime_detail,
    mooncode_conversation: conversation,
    mooncode_summary: local_summary,
    canonical_unchanged,
    archived: summary.archived,
  }
}

///|
fn decode_mooncode_selected_session(
  payload : Json,
) -> Result[MoonCodeSession, String] {
  match @mooncode_core.decode_mooncode_selected_session(payload) {
    Supported(summary) => {
      let conversation_payload = match payload {
        Object(fields) =>
          fields.get("mooncode_conversation").unwrap_or(Json::null())
        _ => Json::null()
      }
      let conversation = match
        @mooncode_core.decode_mooncode_conversation(conversation_payload) {
        Absent => None
        Supported(value) => Some(value)
        UnsupportedProtocol(protocol) =>
          return Err("Unsupported MoonCode conversation protocol \{protocol}")
        UnsupportedContract(contract) =>
          return Err("Unsupported MoonCode conversation contract \{contract}")
        Stale(revision~, current_revision~) =>
          return Err(
            "Stale MoonCode conversation revision \{revision} < \{current_revision}",
          )
        Malformed(error) => return Err(error)
      }
      Ok(mooncode_local_session_from_summary(summary, conversation))
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
