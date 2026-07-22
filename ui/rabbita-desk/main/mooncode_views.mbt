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
      div(class="mooncode-session-search", [
        input(
          class="mooncode-session-search-input",
          attrs=@html.Attrs::build()
            .data_set("testid", "mooncode-session-search")
            .data_set("i18n-aria-label", "code.search_chats")
            .aria_label("Search MoonCode sessions"),
          value=model.mooncode_session_query,
          placeholder="Search chats",
          on_input=fn(value) { dispatch(SetMoonCodeSessionQuery(value)) },
        ),
        if model.mooncode_session_query.trim().to_owned() == "" {
          @html.nothing
        } else {
          button(
            class="mooncode-session-search-clear",
            attrs=@html.Attrs::build().data_set(
              "testid", "mooncode-session-search-clear",
            ),
            title="Clear search",
            on_click=dispatch(SetMoonCodeSessionQuery("")),
            "x",
          )
        },
      ]),
      div(
        class="mooncode-session-list",
        attrs=@html.Attrs::build().data_set("testid", "mooncode-session-list"),
        mooncode_session_list_children(dispatch, model),
      ),
      if model.mooncode_session_management_status == "" {
        @html.nothing
      } else {
        p(
          class="mooncode-session-management-status",
          attrs=@html.Attrs::build().role("status").aria_live("polite"),
          model.mooncode_session_management_status,
        )
      },
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
      children["session:" + session.id] = render_mooncode_session_row(
        dispatch,
        model,
        session,
        selected_id == session.id,
        archived=false,
      )
    }
  }
  if groups.length() == 0 &&
    model.mooncode_session_query.trim().to_owned() != "" {
    children["search-empty"] = p(
      class="status-line empty-list mooncode-session-search-empty",
      "No matching chats",
    )
  }
  if model.mooncode_archived_sessions.length() > 0 {
    children["archived"] = render_mooncode_archived_sessions(dispatch, model)
  }
  children
}

///|
fn mooncode_session_groups(model : Model) -> Array[MoonCodeSessionGroup] {
  let query = model.mooncode_session_query.trim().to_owned().to_lower()
  let searching = query != ""
  let group_order : Array[String] = []
  let group_labels : Map[String, String] = {}
  let group_workspaces : Map[String, String] = {}
  let group_sessions : Map[String, Array[MoonCodeSession]] = {}
  if !searching {
    group_order.push("general")
    group_labels["general"] = "General"
    group_workspaces["general"] = ""
    group_sessions["general"] = []
    for workspace in model.workspaces {
      let group_id = "workspace:" + workspace.id
      if !mooncode_group_order_has(group_order, group_id) {
        group_order.push(group_id)
        group_labels[group_id] = workspace.name
        group_workspaces[group_id] = workspace.id
        group_sessions[group_id] = []
      }
    }
  }
  for session in model.mooncode_sessions {
    if searching && !mooncode_session_matches_query(session, query) {
      continue
    }
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
  if !searching && model.selected_workspace_id != "" {
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
fn mooncode_session_matches_query(
  session : MoonCodeSession,
  query : String,
) -> Bool {
  query == "" ||
  session.title.to_lower().contains(query) ||
  session.workspace_name.to_lower().contains(query) ||
  session.id.to_lower().contains(query)
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
fn render_mooncode_session_row(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
  selected : Bool,
  archived~ : Bool,
) -> @rabbita.Html {
  let editing = model.mooncode_session_editing_id == session.id
  let confirming_delete = model.mooncode_session_delete_id == session.id
  div(
    class=if archived {
      "mooncode-session-row archived"
    } else {
      "mooncode-session-row"
    },
    attrs=@html.Attrs::build()
      .data_set("session-id", session.id)
      .data_set("archived", session.archived.to_string()),
    [
      if editing {
        render_mooncode_session_rename_editor(dispatch, model, session)
      } else {
        div(class="mooncode-session-line", [
          if archived {
            div(
              class="mooncode-session archived",
              attrs=@html.Attrs::build()
                .data_set("testid", "mooncode-archived-session")
                .data_set("session-id", session.id),
              [
                strong(session.title),
                small(mooncode_session_project_line(session)),
              ],
            )
          } else {
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
                .data_set("status", session.status)
                .aria_current(if selected { "page" } else { "false" }),
              title=mooncode_session_accessibility_title(session),
              on_click=dispatch(SelectMoonCodeSession(session.id)),
              [
                strong(session.title),
                small(mooncode_session_status_line(session)),
              ],
            )
          },
          if confirming_delete {
            @html.nothing
          } else {
            render_mooncode_session_menu(dispatch, session, archived~)
          },
        ])
      },
      if confirming_delete {
        render_mooncode_session_delete_confirmation(dispatch, session)
      } else {
        @html.nothing
      },
    ],
  )
}

///|
fn render_mooncode_session_menu(
  dispatch : Dispatch[Msg],
  session : MoonCodeSession,
  archived~ : Bool,
) -> @rabbita.Html {
  details(class="mooncode-session-menu", [
    summary(
      class="mooncode-session-menu-trigger",
      attrs=@html.Attrs::build()
        .data_set("testid", "mooncode-session-menu")
        .aria_label("Session actions"),
      title="Session actions",
      "...",
    ),
    div(class="mooncode-session-menu-popover", [
      button(
        attrs=@html.Attrs::build().data_set("testid", "mooncode-session-rename"),
        on_click=dispatch(BeginMoonCodeSessionRename(session.id)),
        "Rename",
      ),
      if archived {
        button(
          attrs=@html.Attrs::build().data_set(
            "testid", "mooncode-session-restore",
          ),
          on_click=dispatch(RestoreMoonCodeSession(session.id)),
          "Restore",
        )
      } else {
        button(
          attrs=@html.Attrs::build()
            .data_set("testid", "mooncode-session-archive")
            .disabled(mooncode_session_storage_locked(session)),
          title=if mooncode_session_storage_locked(session) {
            "Wait for MoonCode to finish"
          } else {
            "Archive session"
          },
          on_click=dispatch(ArchiveMoonCodeSession(session.id)),
          "Archive",
        )
      },
      button(
        class="danger",
        attrs=@html.Attrs::build()
          .data_set("testid", "mooncode-session-delete")
          .disabled(!archived && mooncode_session_storage_locked(session)),
        on_click=dispatch(RequestDeleteMoonCodeSession(session.id)),
        "Delete",
      ),
    ]),
  ])
}

///|
fn render_mooncode_session_rename_editor(
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
) -> @rabbita.Html {
  div(
    class="mooncode-session-inline-editor",
    attrs=@html.Attrs::build().data_set("testid", "mooncode-session-editor"),
    [
      input(
        class="mooncode-session-title-input",
        attrs=@html.Attrs::build().aria_label("Session title"),
        value=model.mooncode_session_title_draft,
        on_input=fn(value) { dispatch(SetMoonCodeSessionTitleDraft(value)) },
      ),
      div(class="mooncode-session-inline-actions", [
        button(
          class="primary",
          disabled=model.mooncode_session_title_draft.trim().to_owned() == "",
          on_click=dispatch(SaveMoonCodeSessionRename(session.id)),
          "Save",
        ),
        button(on_click=dispatch(CancelMoonCodeSessionRename), "Cancel"),
      ]),
    ],
  )
}

///|
fn render_mooncode_session_delete_confirmation(
  dispatch : Dispatch[Msg],
  session : MoonCodeSession,
) -> @rabbita.Html {
  div(
    class="mooncode-session-delete-confirmation",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-session-delete-confirmation")
      .role("alert"),
    [
      span("Delete this chat permanently?"),
      div(class="mooncode-session-inline-actions", [
        button(
          class="danger",
          on_click=dispatch(ConfirmDeleteMoonCodeSession(session.id)),
          "Delete",
        ),
        button(on_click=dispatch(CancelDeleteMoonCodeSession), "Cancel"),
      ]),
    ],
  )
}

///|
fn render_mooncode_archived_sessions(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let children : Map[String, @rabbita.Html] = {}
  for session in model.mooncode_archived_sessions {
    if mooncode_session_matches_query(
        session,
        model.mooncode_session_query.trim().to_owned().to_lower(),
      ) {
      children[session.id] = render_mooncode_session_row(
        dispatch,
        model,
        session,
        false,
        archived=true,
      )
    }
  }
  details(
    class="mooncode-archived-sessions",
    attrs=@html.Attrs::build().data_set("testid", "mooncode-archived-sessions"),
    [
      summary("Archived (\{model.mooncode_archived_sessions.length()})"),
      div(class="mooncode-archived-list", children),
    ],
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
    match session.updated_at {
      Some(value) if value != "" => browser_mooncode_relative_time(value)
      _ => "Ready"
    }
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
          strong(mooncode_context_title(model, session)),
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
                  .data_set("i18n-aria-label", "code.ask")
                  .data_set("i18n-placeholder", "code.ask_placeholder")
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
fn mooncode_context_title(model : Model, session : MoonCodeSession?) -> String {
  ignore(model)
  match session {
    Some(session) => session.title
    None => "New chat"
  }
}

///|
#cfg(target="js")
extern "js" fn browser_mooncode_relative_time(value : String) -> String =
  #| (value) => {
  #|   const timestamp = Date.parse(value);
  #|   if (!Number.isFinite(timestamp)) return "Ready";
  #|   const seconds = Math.max(0, Math.floor((Date.now() - timestamp) / 1000));
  #|   if (seconds < 60) return "now";
  #|   const minutes = Math.floor(seconds / 60);
  #|   if (minutes < 60) return `${minutes}m`;
  #|   const hours = Math.floor(minutes / 60);
  #|   if (hours < 24) return `${hours}h`;
  #|   const days = Math.floor(hours / 24);
  #|   if (days < 7) return `${days}d`;
  #|   const weeks = Math.floor(days / 7);
  #|   if (weeks < 5) return `${weeks}w`;
  #|   return `${Math.floor(days / 30)}mo`;
  #| }

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
                "Install MoonClaw directly with MoonDesk. Connect MoonGate separately when you want to use a provider managed there."
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
            div(class="mooncode-runtime-install", [
              button(
                class="primary-button compact-button",
                attrs=@html.Attrs::build().data_set(
                  "testid", "mooncode-install-moonclaw",
                ),
                disabled=model.moonclaw_installing,
                on_click=dispatch(ManageMoonClaw("install")),
                if model.moonclaw_installing {
                  "Installing MoonClaw…"
                } else {
                  "Install MoonClaw"
                },
              ),
              render_moonclaw_install_progress(model),
            ])
          },
        ],
      )
    _ => @html.nothing
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
