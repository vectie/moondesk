///|
fn render_mooncode_pane(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(
    class="activity-pane mooncode-rail",
    attrs=@html.Attrs::build().data_set("testid", "mooncode-rail"),
    [
    div(class="pane-heading", [
      div([
        p(class="eyebrow", "MoonCode"),
        h2(mooncode_workspace_label(model)),
        p(class="rail-count", mooncode_session_count_label(model)),
      ]),
    ]),
    button(
      class="mooncode-new-session",
      attrs=@html.Attrs::build().data_set("testid", "mooncode-new-session"),
      on_click=dispatch(NewMoonCodeSession),
      "New chat",
    ),
    div(
      class="mooncode-session-list",
      attrs=@html.Attrs::build().data_set("testid", "mooncode-session-list"),
      if model.mooncode_sessions.length() == 0 {
        [p(class="status-line empty-list", "No chats")]
      } else {
        model.mooncode_sessions.map(session => {
          let selected = selected_mooncode_session(model)
            .map(fn(item) { item.id })
            .unwrap_or("") ==
            session.id
          button(
            class=if selected {
              "mooncode-session active"
            } else {
              "mooncode-session"
            },
            attrs=@html.Attrs::build()
              .data_set("testid", "mooncode-session")
              .data_set("session-id", session.id)
              .data_set("workspace-id", session.workspace_id)
              .data_set("status", session.status),
            title=mooncode_session_accessibility_title(session),
            on_click=dispatch(SelectMoonCodeSession(session.id)),
            [
              strong(session.title),
              small(mooncode_session_project_line(session)),
            ],
          )
        })
      },
    ),
  ])
}

///|
fn mooncode_workspace_label(model : Model) -> String {
  if model.selected_workspace_id == "" {
    "General chat"
  } else {
    workspace_name(model)
  }
}

///|
fn mooncode_session_count_label(model : Model) -> String {
  let count = model.mooncode_sessions.length()
  if count == 1 {
    "1 session"
  } else {
    "\{count} sessions"
  }
}

///|
fn mooncode_session_project_line(session : MoonCodeSession) -> String {
  if session.workspace_name == "" {
    session.cwd
  } else {
    "\{session.workspace_name} / \{session.cwd}"
  }
}

///|
fn mooncode_session_accessibility_title(session : MoonCodeSession) -> String {
  let runtime = match session.mooncode_runtime_session_id {
    Some(id) if id != "" => id
    _ => session.id
  }
  let summary = session.mooncode_summary
  "\{session.id} / \{session.workspace_name} / \{session.cwd} / \{session.status} / \{session.updated_at} / \{runtime} / events \{summary.event_count} / diffs \{summary.pending_diff_count} / tests \{summary.verified_test_count}"
}

///|
fn render_mooncode_center(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let session = selected_mooncode_session(model)
  let empty = session is None
  main_(
    class="preview-center mooncode-center",
    attrs=@html.Attrs::build().data_set("testid", "mooncode-center"),
    [
    div(class="mooncode-context-bar", [
      div([
        strong(mooncode_workspace_label(model)),
        span(mooncode_context_path_label(model, session)),
      ]),
    ]),
    section(
      class=if empty {
        "mooncode-chat-surface empty"
      } else {
        "mooncode-chat-surface"
      },
      attrs=@html.Attrs::build().data_set("testid", "mooncode-chat-surface"),
      [
        match session {
          Some(session) =>
            div(class="mooncode-session-surface", [
              render_mooncode_transcript(model, session),
            ])
          None =>
            div(class="mooncode-empty", [
              h1("Ask MoonCode"),
              p(
                class="lead",
                if model.selected_workspace_id == "" {
                  "Ask a coding question, or select a MoonBook when you want changes attached to a book."
                } else {
                  "Describe the code change you want in this MoonBook."
                },
              ),
            ])
        },
        div(class="mooncode-composer", [
          div(class="composer-field", [
            textarea(
              class="mooncode-input",
              attrs=@html.Attrs::build().data_set("testid", "mooncode-input"),
              rows=1,
              value=model.mooncode_prompt,
              placeholder="Ask MoonCode...",
              on_input=fn(value) { dispatch(SetMoonCodePrompt(value)) },
              "",
            ),
          ]),
          div(class="composer-footer", [
            button(
              class="primary-button",
              attrs=@html.Attrs::build().data_set(
                "testid",
                "mooncode-send",
              ),
              on_click=dispatch(SendMoonCodeMessage),
              mooncode_composer_button_label(model, session),
            ),
          ]),
        ]),
      ],
    ),
  ])
}

///|
fn mooncode_context_path_label(
  model : Model,
  session : MoonCodeSession?,
) -> String {
  match session {
    Some(session) =>
      if session.cwd == "" {
        model.selected_path
      } else {
        session.cwd
      }
    None =>
      if model.selected_path == "" {
        "No path selected"
      } else {
        model.selected_path
      }
  }
}

///|
fn mooncode_composer_button_label(
  model : Model,
  session : MoonCodeSession?,
) -> String {
  match session {
    Some(active) if mooncode_session_accepts_steer(model, active) => "Steer"
    Some(_) => "Prompt"
    None => "Start"
  }
}
