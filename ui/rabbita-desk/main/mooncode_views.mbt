///|
fn render_mooncode_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane mooncode-rail", [
    div(class="pane-heading", [
      div([
        p(class="eyebrow", "MoonCode"),
        h2("Sessions"),
        p(class="rail-count", mooncode_session_count_label(model)),
      ]),
    ]),
    button(
      class="mooncode-new-session",
      on_click=dispatch(NewMoonCodeSession),
      "New chat",
    ),
    div(
      class="mooncode-session-list",
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
            title="\{session.id} / \{session.cwd}",
            on_click=dispatch(SelectMoonCodeSession(session.id)),
            [
              strong(session.title),
              small("\{session.status} / \{session.updated_at}"),
            ],
          )
        })
      },
    ),
  ])
}

///|
fn mooncode_session_count_label(model : Model) -> String {
  let count = model.mooncode_sessions.length()
  if count == 1 { "1 session" } else { "\{count} sessions" }
}

///|
fn mooncode_session_runtime_line(session : MoonCodeSession) -> String {
  let model = if session.model == "" { "default" } else { session.model }
  let runtime_id = mooncode_session_runtime_id(session)
  let runtime = if runtime_id == "" {
    "not attached"
  } else {
    runtime_id
  }
  "\{model} / \{runtime} / queued \{session.queued_count}"
}

fn render_mooncode_center(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let session = selected_mooncode_session(model)
  let empty = session is None
  let scope_label = mooncode_scope_label(model)
  main_(class="preview-center mooncode-center", [
    div(class="mooncode-topline", [
      span(class="path-pill", scope_label),
      span(class="status-line", selected_mooncode_runtime_label(model)),
    ]),
    section(class=if empty { "mooncode-chat-surface empty" } else { "mooncode-chat-surface" }, [
      match session {
        Some(session) => div(class="mooncode-session-surface", [
          render_mooncode_session_header(session),
          render_mooncode_transcript(model, session),
        ])
        None =>
          div(class="mooncode-empty", [
            h1("Ask MoonCode"),
            p(
              class="lead",
              "Describe the code change you want in this MoonBook.",
            ),
          ])
      },
      div(class="mooncode-composer", [
        div(class="composer-field", [
          p(class="composer-label", "Message"),
          textarea(
            class="mooncode-input",
            rows=1,
            value=model.mooncode_prompt,
            placeholder="Ask MoonCode...",
            on_input=fn(value) { dispatch(SetMoonCodePrompt(value)) },
            "",
          ),
        ]),
        div(class="composer-footer", [
          div(class="composer-meta", [
            span(class="option-chip active", mooncode_workspace_chip(model)),
            span(class="option-chip", mooncode_path_chip(model)),
            button(
              class=if model.mooncode_web_search {
                "web-toggle active"
              } else {
                "web-toggle"
              },
              on_click=dispatch(ToggleMoonCodeWebSearch),
              "Web",
            ),
          ]),
          button(
            class="primary-button",
            on_click=dispatch(SendMoonCodeMessage),
            mooncode_composer_button_label(model, session),
          ),
        ]),
        render_mooncode_composer_status(model),
      ]),
      if empty { render_mooncode_starters(dispatch) } else { span(class="hidden-inline", "") },
    ]),
  ])
}

///|
fn render_mooncode_starters(dispatch : Dispatch[Msg]) -> @rabbita.Html {
  div(class="mooncode-starters", [
    p(class="starter-label", "Start with"),
    div(class="starter-row", [
      starter_button(
        dispatch,
        "Add a tool",
        "Add a small executable tool to this MoonBook.",
      ),
      starter_button(
        dispatch,
        "Fix a bug",
        "Find and fix a bug in this MoonBook's executable code.",
      ),
      starter_button(
        dispatch,
        "Explain this book",
        "Explain how this MoonBook is organized and what can run.",
      ),
    ]),
  ])
}

fn starter_button(
  dispatch : Dispatch[Msg],
  label : String,
  prompt : String
) -> @rabbita.Html {
  button(
    class="starter-chip",
    on_click=dispatch(SetMoonCodePrompt(prompt)),
    label,
  )
}

///|
fn mooncode_scope_label(model : Model) -> String {
  let workspace = workspace_name(model)
  if workspace == "No workspace" {
    "Select or create a MoonBook"
  } else {
    "\{workspace} / \{model.selected_path}"
  }
}

fn mooncode_workspace_chip(model : Model) -> String {
  let workspace = workspace_name(model)
  if workspace == "No workspace" { "No MoonBook" } else { workspace }
}

fn mooncode_path_chip(model : Model) -> String {
  let workspace = workspace_name(model)
  if workspace == "No workspace" { "Pick a book first" } else { model.selected_path }
}

///|
fn mooncode_status_summary(status : String) -> String {
  if status.contains("daemon") || status.contains("MoonClaw") {
    "Agent offline"
  } else if status == "0 MoonCode session(s)" {
    "No sessions yet"
  } else {
    status
  }
}

fn render_mooncode_composer_status(model : Model) -> @rabbita.Html {
  let summary = mooncode_status_summary(model.mooncode_composer_status)
  if summary == "" ||
    summary == "mooncode idle" ||
    summary == "draft" ||
    summary == "No sessions yet" {
    span(class="hidden-inline", "")
  } else {
    p(class="composer-status", summary)
  }
}

fn mooncode_composer_button_label(
  model : Model,
  session : MoonCodeSession?
) -> String {
  match session {
    Some(active) if mooncode_session_accepts_steer(model, active) => "Steer"
    Some(_) => "Prompt"
    None => "Start"
  }
}

///|
fn render_mooncode_session_header(
  session : MoonCodeSession,
) -> @rabbita.Html {
  let summary = session.mooncode_summary
  div(class="mooncode-session-header", [
    div(class="mooncode-session-title", [
      div([
        h2(session.title),
        small(
          "\{session.workspace_name} / \{mooncode_session_runtime_line(session)}",
        ),
      ]),
    ]),
    div(class="mooncode-session-grid", [
      info_chip("status", session.status),
      info_chip("events", summary.event_count.to_string()),
      info_chip("diffs", summary.pending_diff_count.to_string()),
      info_chip("tests", summary.verified_test_count.to_string()),
    ]),
  ])
}
