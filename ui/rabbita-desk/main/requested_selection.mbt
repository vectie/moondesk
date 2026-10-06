///|
/// URL workspace identity remains pinned until the user chooses a destination.
fn requested_workspace_unavailable(model : Model) -> Bool {
  requested_workspace_active(model) &&
  !has_workspace(model.workspaces, model.requested_workspace_id)
}

///|
fn requested_workspace_active(model : Model) -> Bool {
  model.requested_workspace_id != "" &&
  model.selected_workspace_id == model.requested_workspace_id
}

///|
/// A catalog response may predate the selected book. Retain the confirmed
/// row just as session refresh retains an already hydrated selected chat.
fn preserve_requested_workspace(
  model : Model,
  incoming : Array[@desk.DeskWorkspace],
) -> Array[@desk.DeskWorkspace] {
  if requested_workspace_active(model) &&
    !has_workspace(incoming, model.requested_workspace_id) {
    for workspace in model.workspaces {
      if workspace.id == model.requested_workspace_id {
        return [workspace] + incoming
      }
    }
  }
  incoming
}

///|
fn mooncode_selection_unavailable(model : Model) -> Bool {
  requested_workspace_unavailable(model) ||
  (
    model.selected_mooncode_session_id != "" &&
    selected_mooncode_session(model) is None
  )
}

///|
/// Restore reads are independent of model execution readiness. Reading saved
/// work must not require an available model or a successful catalog request.
fn fetch_requested_selection_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  @rabbita.batch([
    if model.selected_mooncode_session_id != "" {
      fetch_mooncode_selected_session_cmd(
        dispatch,
        model.selected_mooncode_session_id,
      )
    } else {
      @rabbita.none
    },
    if model.workspace_mode == MoonCode &&
      (
        model.selected_mooncode_session_id != "" ||
        model.requested_workspace_id != ""
      ) {
      fetch_mooncode_sessions_cmd(dispatch, "")
    } else {
      @rabbita.none
    },
  ])
}

///|
fn requested_selection_loading(model : Model) -> Bool {
  (
    requested_workspace_unavailable(model) &&
    model.workspace_catalog_state is Some(Loading)
  ) ||
  (
    model.selected_mooncode_session_id != "" &&
    selected_mooncode_session(model) is None &&
    model.mooncode_selected_session_loading
  )
}

///|
/// Leaving an unresolved chat cancels its authority, including a late direct
/// response or the first listing that arrives after the navigation.
fn leave_unresolved_session(model : Model) -> Model {
  if model.selected_mooncode_session_id != "" &&
    selected_mooncode_session(model) is None {
    {
      ..model,
      selected_mooncode_session_id: "",
      mooncode_selected_session_loading: false,
      mooncode_auto_select_session: false,
    }
  } else {
    model
  }
}

///|
/// Model cancellation must also remove the departed session from the URL so
/// a later reload cannot silently reissue the request the user left.
fn sync_departed_session_context_cmd(
  previous : Model,
  next : Model,
) -> @rabbita.Cmd {
  if previous.selected_mooncode_session_id != "" &&
    next.selected_mooncode_session_id == "" {
    sync_mooncode_context_cmd(next.selected_workspace_id, "")
  } else {
    @rabbita.none
  }
}

///|
fn render_requested_selection(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !mooncode_selection_unavailable(model) {
    return @html.nothing
  }
  let loading = requested_selection_loading(model)
  let mismatch = requested_workspace_active(model) &&
    mooncode_find_session(
      model.mooncode_sessions,
      model.selected_mooncode_session_id,
    )
    is Some(session) &&
    !mooncode_session_matches_workspace_id(
      session,
      model.requested_workspace_id,
    )
  section(
    class="mooncode-empty requested-selection",
    attrs=@html.Attrs::build()
      .data_set("testid", "requested-selection")
      .role("status")
      .aria_live("polite"),
    [
      h2(
        if mismatch {
          "The requested chat belongs to another MoonBook"
        } else if loading {
          "Loading the requested work"
        } else {
          "The requested work is unavailable"
        },
      ),
      p(
        if model.selected_mooncode_session_id != "" {
          "Chat: " + model.selected_mooncode_session_id
        } else {
          "MoonBook: " + model.selected_workspace_id
        },
      ),
      if model.requested_workspace_id != "" &&
        model.selected_mooncode_session_id != "" {
        p("MoonBook: " + model.requested_workspace_id)
      } else {
        @html.nothing
      },
      p(
        if loading {
          "Checking the exact destination from your link. You can choose another destination while it loads."
        } else {
          "Your selection has been kept. Retry, select another MoonBook or chat, or start a new chat."
        },
      ),
      if model.mooncode_sessions_error != "" {
        p(model.mooncode_sessions_error)
      } else if model.workspace_catalog_error != "" {
        p(model.workspace_catalog_error)
      } else {
        @html.nothing
      },
      button(
        class="secondary-button",
        on_click=dispatch(RetryBootstrap),
        "Retry",
      ),
      if model.workspace_mode == MoonCode {
        button(
          class="secondary-button",
          on_click=dispatch(NewMoonCodeSession),
          "New Chat",
        )
      } else {
        @html.nothing
      },
    ],
  )
}
