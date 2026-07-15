///|
fn mooncode_session_for_management(
  model : Model,
  session_id : String,
) -> MoonCodeSession? {
  match mooncode_find_session(model.mooncode_sessions, session_id) {
    Some(session) => Some(session)
    None => mooncode_find_session(model.mooncode_archived_sessions, session_id)
  }
}

///|
fn mooncode_session_storage_locked(session : MoonCodeSession) -> Bool {
  session.status == "running" ||
  session.status == "queued" ||
  session.queued_count > 0
}

///|
fn mooncode_save_session_rename(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
) -> (@rabbita.Cmd, Model) {
  let title = model.mooncode_session_title_draft.trim().to_owned()
  if title == "" {
    return (
      @rabbita.none,
      {
        ..model,
        mooncode_session_management_status: "Enter a session title",
      },
    )
  }
  if title.length() > 160 {
    return (
      @rabbita.none,
      {
        ..model,
        mooncode_session_management_status: "Session titles may not exceed 160 characters",
      },
    )
  }
  (
    manage_mooncode_session_cmd(dispatch, session_id, "rename", title~),
    { ..model, mooncode_session_management_status: "Renaming session" },
  )
}

///|
fn mooncode_start_session_storage_action(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  action : String,
) -> (@rabbita.Cmd, Model) {
  match mooncode_session_for_management(model, session_id) {
    Some(session) if action != "restore" && mooncode_session_storage_locked(session) =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_session_management_status: "Wait for MoonCode to finish before changing this session",
        },
      )
    Some(_) =>
      (
        manage_mooncode_session_cmd(dispatch, session_id, action),
        {
          ..model,
          mooncode_session_management_status: match action {
            "archive" => "Archiving session"
            "restore" => "Restoring session"
            "delete" => "Deleting session"
            _ => "Updating session"
          },
        },
      )
    None =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_session_management_status: "This MoonCode session is no longer available",
        },
      )
  }
}

///|
fn mooncode_sessions_with_title(
  sessions : Array[MoonCodeSession],
  session_id : String,
  title : String,
) -> Array[MoonCodeSession] {
  sessions.map(session => {
    if session.id == session_id { { ..session, title } } else { session }
  })
}

///|
fn mooncode_sessions_without(
  sessions : Array[MoonCodeSession],
  session_id : String,
) -> Array[MoonCodeSession] {
  sessions.filter(session => session.id != session_id)
}

///|
fn mooncode_sessions_prepend(
  sessions : Array[MoonCodeSession],
  session : MoonCodeSession,
) -> Array[MoonCodeSession] {
  let next = [session]
  for existing in sessions {
    if existing.id != session.id {
      next.push(existing)
    }
  }
  next
}

///|
fn mooncode_session_management_result(
  dispatch : Dispatch[Msg],
  model : Model,
  result : Result[MoonCodeSessionLifecycleResult, String],
) -> (@rabbita.Cmd, Model) {
  match result {
    Err(error) =>
      (
        @rabbita.none,
        { ..model, mooncode_session_management_status: error },
      )
    Ok(result) => {
      if result.kind != "mooncode-session-lifecycle-result" ||
        result.protocol == "" ||
        result.owner != "moonclaw" ||
        (result.action == "archive" && !result.archived) ||
        (result.action == "restore" && result.archived) ||
        (result.action == "delete" && !result.deleted) {
        return (
          @rabbita.none,
          {
            ..model,
            mooncode_session_management_status: "MoonClaw returned an invalid session lifecycle result",
          },
        )
      }
      let session_id = result.session_id
      let current = mooncode_session_for_management(model, session_id)
      let mut active = model.mooncode_sessions
      let mut archived = model.mooncode_archived_sessions
      match result.action {
        "rename" => {
          active = mooncode_sessions_with_title(active, session_id, result.title)
          archived = mooncode_sessions_with_title(
            archived, session_id, result.title,
          )
        }
        "archive" => {
          active = mooncode_sessions_without(active, session_id)
          match current {
            Some(session) =>
              archived = mooncode_sessions_prepend(
                archived, { ..session, archived: true },
              )
            None => ()
          }
        }
        "restore" => {
          archived = mooncode_sessions_without(archived, session_id)
          match current {
            Some(session) =>
              active = mooncode_sessions_prepend(
                active, { ..session, archived: false },
              )
            None => ()
          }
        }
        "delete" => {
          active = mooncode_sessions_without(active, session_id)
          archived = mooncode_sessions_without(archived, session_id)
        }
        _ => ()
      }
      let clears_selection = model.selected_mooncode_session_id == session_id &&
        (result.action == "archive" || result.action == "delete")
      let next = {
        ..model,
        mooncode_sessions: active,
        mooncode_archived_sessions: archived,
        selected_mooncode_session_id: if clears_selection {
          ""
        } else {
          model.selected_mooncode_session_id
        },
        mooncode_new_chat_active: if clears_selection {
          true
        } else {
          model.mooncode_new_chat_active
        },
        mooncode_session_editing_id: "",
        mooncode_session_title_draft: "",
        mooncode_session_delete_id: "",
        mooncode_session_management_status: match result.action {
          "rename" => "Session renamed"
          "archive" => "Session archived"
          "restore" => "Session restored"
          "delete" => "Session deleted"
          _ => "Session updated"
        },
        mooncode_watch_generation: if clears_selection {
          model.mooncode_watch_generation + 1
        } else {
          model.mooncode_watch_generation
        },
        mooncode_watch_revision: if clears_selection {
          0
        } else {
          model.mooncode_watch_revision
        },
        mooncode_watch_sequence: if clears_selection {
          0
        } else {
          model.mooncode_watch_sequence
        },
        mooncode_watch_status: if clears_selection {
          "idle"
        } else {
          model.mooncode_watch_status
        },
      }
      let refresh = fetch_mooncode_sessions_cmd(dispatch, "")
      if clears_selection {
        (
          @rabbita.batch([
            refresh,
            stop_mooncode_watch_cmd(),
            sync_mooncode_context_cmd(model.selected_workspace_id, ""),
          ]),
          next,
        )
      } else {
        (refresh, next)
      }
    }
  }
}
