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
        mooncode_session_list_children(dispatch, model),
      ),
    ],
  )
}

///|
struct MoonCodeSessionGroup {
  id : String
  workspace_id : String
  label : String
  sessions : Array[MoonCodeSession]
}

///|
fn mooncode_session_list_children(
  dispatch : Dispatch[Msg],
  model : Model,
) -> Map[String, @rabbita.Html] {
  let children : Map[String, @rabbita.Html] = {}
  let groups = mooncode_session_groups(model)
  let selected_id = selected_mooncode_session(model)
    .map(fn(item) { item.id })
    .unwrap_or("")
  for group in groups {
    children["group:" + group.id] = render_mooncode_session_group_heading(
      dispatch, model, group,
    )
    if group.sessions.length() == 0 &&
      mooncode_session_group_active(model, group) {
      children["group-empty:" + group.id] = p(
        class="status-line empty-list mooncode-session-group-empty",
        if group.workspace_id == "" {
          "No general chats"
        } else {
          "No chats in this MoonBook"
        },
      )
    }
    for session in group.sessions {
      children["session:" + session.id] = render_mooncode_session_button(
        dispatch,
        session,
        selected_id == session.id,
      )
    }
  }
  children
}

///|
fn mooncode_session_groups(model : Model) -> Array[MoonCodeSessionGroup] {
  let group_order : Array[String] = ["general"]
  let group_labels : Map[String, String] = { "general": "General" }
  let group_workspaces : Map[String, String] = { "general": "" }
  let group_sessions : Map[String, Array[MoonCodeSession]] = { "general": [] }
  for workspace in model.workspaces {
    let group_id = "workspace:" + workspace.id
    if !mooncode_group_order_has(group_order, group_id) {
      group_order.push(group_id)
      group_labels[group_id] = workspace.name
      group_workspaces[group_id] = workspace.id
      group_sessions[group_id] = []
    }
  }
  for session in model.mooncode_sessions {
    let group_id = mooncode_session_group_id(session)
    if !mooncode_group_order_has(group_order, group_id) {
      group_order.push(group_id)
      group_labels[group_id] = mooncode_session_group_label(model, session)
      group_workspaces[group_id] = if mooncode_session_is_general(session) {
        ""
      } else {
        session.workspace_id
      }
      group_sessions[group_id] = []
    }
    let sessions = group_sessions.get(group_id).unwrap_or([])
    sessions.push(session)
    group_sessions[group_id] = sessions
  }
  if model.selected_workspace_id != "" {
    let selected_group_id = "workspace:" + model.selected_workspace_id
    if !mooncode_group_order_has(group_order, selected_group_id) {
      group_order.push(selected_group_id)
      group_labels[selected_group_id] = mooncode_workspace_name_for_id(
        model,
        model.selected_workspace_id,
      )
      group_workspaces[selected_group_id] = model.selected_workspace_id
      group_sessions[selected_group_id] = []
    }
  }
  let groups : Array[MoonCodeSessionGroup] = []
  for group_id in group_order {
    groups.push({
      id: group_id,
      workspace_id: group_workspaces.get(group_id).unwrap_or(""),
      label: group_labels.get(group_id).unwrap_or("General"),
      sessions: group_sessions.get(group_id).unwrap_or([]),
    })
  }
  groups
}

///|
fn mooncode_group_order_has(
  group_order : Array[String],
  group_id : String,
) -> Bool {
  for existing in group_order {
    if existing == group_id {
      return true
    }
  }
  false
}

///|
fn mooncode_session_group_id(session : MoonCodeSession) -> String {
  if mooncode_session_is_general(session) {
    "general"
  } else {
    "workspace:" + session.workspace_id
  }
}

///|
fn mooncode_session_group_label(
  model : Model,
  session : MoonCodeSession,
) -> String {
  if mooncode_session_is_general(session) {
    "General"
  } else if session.workspace_name != "" {
    session.workspace_name
  } else {
    mooncode_workspace_name_for_id(model, session.workspace_id)
  }
}

///|
fn mooncode_workspace_name_for_id(
  model : Model,
  workspace_id : String,
) -> String {
  if workspace_id == "" {
    return "General"
  }
  for workspace in model.workspaces {
    if workspace.id == workspace_id {
      return workspace.name
    }
  }
  workspace_id
}

///|
fn mooncode_session_group_active(
  model : Model,
  group : MoonCodeSessionGroup,
) -> Bool {
  model.selected_workspace_id == group.workspace_id
}

///|
fn render_mooncode_session_group_heading(
  dispatch : Dispatch[Msg],
  model : Model,
  group : MoonCodeSessionGroup,
) -> @rabbita.Html {
  let active = mooncode_session_group_active(model, group)
  button(
    class=if active {
      "mooncode-session-group-heading active"
    } else {
      "mooncode-session-group-heading"
    },
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-session-group")
      .data_set("scope-id", group.id)
      .data_set("workspace-id", group.workspace_id)
      .aria_pressed(if active { "true" } else { "false" }),
    title=if group.workspace_id == "" {
      "General chats without a MoonBook"
    } else {
      "MoonBook chats for \{group.label}"
    },
    on_click=dispatch(SelectWorkspace(group.workspace_id)),
    [
      span(class="mooncode-session-group-mark", ""),
      span(class="mooncode-session-group-name", group.label),
      span(
        class="mooncode-session-group-count",
        group.sessions.length().to_string(),
      ),
    ],
  )
}

///|
fn render_mooncode_session_button(
  dispatch : Dispatch[Msg],
  session : MoonCodeSession,
  selected : Bool,
) -> @rabbita.Html {
  button(
    class=if selected { "mooncode-session active" } else { "mooncode-session" },
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-session")
      .data_set("session-id", session.id)
      .data_set("workspace-id", session.workspace_id)
      .data_set("status", session.status)
      .aria_current(if selected { "page" } else { "false" }),
    title=mooncode_session_accessibility_title(session),
    on_click=dispatch(SelectMoonCodeSession(session.id)),
    [strong(session.title), small(mooncode_session_status_line(session))],
  )
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
    "General MoonCode"
  } else {
    session.workspace_name
  }
}

///|
fn mooncode_session_status_line(session : MoonCodeSession) -> String {
  if session.queued_count > 0 || session.status == "queued" {
    "Queued"
  } else if session.status == "running" {
    "Working"
  } else if session.status == "failed" {
    "Needs attention"
  } else {
    "Ready"
  }
}

///|
fn mooncode_session_accessibility_title(session : MoonCodeSession) -> String {
  let runtime = match session.mooncode_runtime_session_id {
    Some(id) if id != "" => id
    _ => session.id
  }
  let summary = session.mooncode_summary
  "\{mooncode_session_project_line(session)} / \{session.status} / \{runtime} / events \{summary.event_count} / diffs \{summary.pending_diff_count} / tests \{summary.verified_test_count}"
}

///|
fn render_mooncode_center(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let session = selected_mooncode_session(model)
  let empty = session is None
  main_(
    class=mooncode_center_class(model),
    attrs=@html.Attrs::build().data_set("testid", "mooncode-center"),
    [
      div(class="mooncode-context-bar", [
        div([
          strong(mooncode_workspace_label(model)),
          span(mooncode_context_path_label(model, session)),
        ]),
      ]),
      render_mooncode_runtime_setup(dispatch, model),
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
                render_mooncode_session_state(session),
                render_mooncode_transcript(dispatch, model, session),
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
                attrs=@html.Attrs::build()
                  .data_set("testid", "mooncode-input")
                  .aria_label("Message MoonCode"),
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
                attrs=@html.Attrs::build()
                  .data_set("testid", "mooncode-send")
                  .on_click(_ => {
                    dispatch(
                      SendMoonCodeMessage(browser_mooncode_prompt_value()),
                    )
                  }),
                mooncode_composer_button_label(model, session),
              ),
            ]),
          ]),
        ],
      ),
    ],
  )
}

///|
fn mooncode_center_class(model : Model) -> String {
  match model.moonclaw_daemon {
    Some(daemon) if !daemon.running =>
      "preview-center mooncode-center runtime-setup-visible"
    _ => "preview-center mooncode-center"
  }
}

///|
fn render_mooncode_runtime_setup(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  match model.moonclaw_daemon {
    Some(daemon) if !daemon.running =>
      section(
        class="mooncode-runtime-setup",
        attrs=@html.Attrs::build()
          .data_set("testid", "mooncode-runtime-setup")
          .role("status")
          .aria_live("polite"),
        [
          div([
            strong(
              if daemon.service_configured {
                "MoonClaw is ready to start"
              } else {
                "MoonClaw needs setup"
              },
            ),
            p(
              if daemon.service_configured {
                "Start the installed workspace worker, then retry your saved request."
              } else {
                "Enable the installed MoonClaw product from MoonGate; no path or service file editing is required here."
              },
            ),
          ]),
          if daemon.service_configured {
            button(
              class="primary-button compact-button",
              attrs=@html.Attrs::build().data_set(
                "testid", "mooncode-start-moonclaw",
              ),
              on_click=dispatch(ManageMoonClaw("retry")),
              "Start and retry",
            )
          } else {
            button(
              class="secondary-button compact-button",
              attrs=@html.Attrs::build().data_set(
                "testid", "mooncode-open-moongate",
              ),
              on_click=dispatch(SelectWorkspaceMode(Desk)),
              "Open MoonGate setup",
            )
          },
        ],
      )
    _ => @html.nothing
  }
}

///|
fn render_mooncode_session_state(session : MoonCodeSession) -> @rabbita.Html {
  let title = mooncode_user_state_title(session)
  if title == "" {
    @html.nothing
  } else {
    section(
      class="mooncode-user-state " + session.status,
      attrs=@html.Attrs::build()
        .data_set("testid", "mooncode-user-state")
        .data_set("status", session.status)
        .role("status")
        .aria_live("polite"),
      [
        div(class="mooncode-user-state-copy", [
          h2(title),
          p(mooncode_user_state_message(session)),
        ]),
        details(class="mooncode-why-disclosure", [
          summary("Why?"),
          div(class="mooncode-why-body", [
            p(mooncode_user_state_reason(session)),
            p(class="mooncode-next-action", mooncode_user_next_action(session)),
            details(class="mooncode-technical-disclosure", [
              summary("Technical evidence"),
              div(class="mooncode-technical-evidence", [
                info_row("Session", session.id),
                info_row("State", session.status),
                info_row(
                  "Runtime",
                  match session.mooncode_runtime_session_id {
                    Some(id) if id != "" => id
                    _ => "not attached"
                  },
                ),
                info_row(
                  "Evidence",
                  "\{session.mooncode_summary.event_count} events · \{session.mooncode_summary.pending_diff_count} pending diffs · \{session.mooncode_summary.verified_test_count} verified tests",
                ),
              ]),
            ]),
          ]),
        ]),
      ],
    )
  }
}

///|
fn mooncode_user_state_title(session : MoonCodeSession) -> String {
  if session.status == "failed" {
    "MoonCode couldn't start"
  } else if session.status == "queued" || session.queued_count > 0 {
    "Your request is queued"
  } else if session.status == "running" {
    "MoonCode is working"
  } else {
    ""
  }
}

///|
fn mooncode_user_state_message(session : MoonCodeSession) -> String {
  if session.status == "failed" {
    "Your request was saved, but no coding work ran."
  } else if session.status == "queued" || session.queued_count > 0 {
    "MoonCode will begin when its worker is ready."
  } else if session.status == "running" {
    "You can keep working in MoonDesk while this continues."
  } else {
    ""
  }
}

///|
fn mooncode_user_state_reason(session : MoonCodeSession) -> String {
  match session.mooncode_runtime_detail {
    Some(detail) if detail != "" => detail
    _ if session.status == "failed" =>
      "The runtime reported a failure without a specific reason."
    _ => "MoonCode is waiting for its governed worker."
  }
}

///|
fn mooncode_user_next_action(session : MoonCodeSession) -> String {
  match session.mooncode_runtime_detail {
    Some("MoonClaw daemon is not running") =>
      "Next: connect or start MoonClaw for this workspace, then send the request again."
    Some(_) if session.status == "failed" =>
      "Next: resolve the reason above, then send the request again."
    _ if session.status == "queued" || session.queued_count > 0 =>
      "Next: wait, or open Why? to verify what MoonCode is waiting for."
    _ if session.status == "running" =>
      "Next: review the result when MoonCode asks for attention."
    _ => ""
  }
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
        mooncode_session_project_line(session)
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
  ignore(model)
  match session {
    Some(_) => "Prompt"
    None => "Start"
  }
}
