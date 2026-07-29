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
    Ok(summaries) =>
      Ok(
        summaries.map(summary => {
          mooncode_local_session_from_summary(summary, None)
        }),
      )
    Err(UnsupportedVersion(version)) =>
      Err("Unsupported MoonCode session listing contract version \{version}")
    Err(Malformed(error)) => Err(error)
    Err(_) => Err("Invalid MoonCode session listing")
  }
}

///|
fn mooncode_local_session_from_summary(
  summary : @mooncode_core.MoonCodeSessionSummary,
  conversation : @mooncode_core.MoonCodeConversation?,
) -> MoonCodeSession {
  let local_summary = match summary.extensions.get("mooncode_summary") {
    Some(value) =>
      @json.from_json(value) catch {
        _ => { event_count: 0, verified_test_count: 0, pending_diff_count: 0 }
      }
    None => { event_count: 0, verified_test_count: 0, pending_diff_count: 0 }
  }
  let runtime_detail = match summary.extensions.get("mooncode_runtime_detail") {
    Some(String(value)) => Some(value)
    _ => None
  }
  let canonical_unchanged = match
    summary.extensions.get("canonical_unchanged") {
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
    Ok(summary) => {
      let conversation_payload = match payload {
        Object(fields) =>
          fields.get("mooncode_conversation").unwrap_or(Json::null())
        _ => Json::null()
      }
      let conversation = match
        @mooncode_core.decode_mooncode_conversation(conversation_payload) {
        Err(Absent) => None
        Ok(value) => Some(value)
        Err(UnsupportedProtocol(protocol)) =>
          return Err("Unsupported MoonCode conversation protocol \{protocol}")
        Err(UnsupportedContract(contract)) =>
          return Err("Unsupported MoonCode conversation contract \{contract}")
        Err(Stale(revision~, current_revision~)) =>
          return Err(
            "Stale MoonCode conversation revision \{revision} < \{current_revision}",
          )
        Err(Malformed(error)) => return Err(error)
        Err(UnsupportedVersion(version)) =>
          return Err("Unsupported MoonCode version \{version}")
      }
      Ok(mooncode_local_session_from_summary(summary, conversation))
    }
    Err(UnsupportedVersion(version)) =>
      Err("Unsupported MoonCode selected session contract version \{version}")
    Err(Malformed(error)) => Err(error)
    Err(_) => Err("Invalid MoonCode selected session")
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
