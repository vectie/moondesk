///|
fn render_mooncode_pane(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if work_handoff_active(model) {
    return render_work_handoff_rail(dispatch, model)
  }
  aside(
    class="activity-pane mooncode-rail",
    attrs=@html.Attrs::build()
      .aria_label("Code sessions")
      .data_set("i18n-aria-label", "code.sessions_aria")
      .data_set("testid", "mooncode-rail"),
    [
      div(class="pane-heading", [
        div([
          h2(
            if model.selected_workspace_id == "" {
              Map([
                (
                  "general",
                  span(
                    attrs=@html.Attrs::build().data_set("i18n", "code.general"),
                    "General chat",
                  ),
                ),
              ])
            } else {
              Map([
                (
                  "book",
                  span(
                    attrs=@html.Attrs::build().data_set("i18n-scope", "content"),
                    mooncode_workspace_label(model),
                  ),
                ),
              ])
            },
          ),
        ]),
        button(
          class="moon-icon-button code-navigation-close",
          attrs=@html.Attrs::build()
            .data_set("close-code-navigation", "true")
            .data_set("i18n-aria-label", "code.close_chats")
            .aria_label("Close chats sidebar")
            .title("Close chats sidebar"),
          ui_icon("panel-left"),
        ),
      ]),
      button(
        class="mooncode-new-session",
        attrs=@html.Attrs::build().data_set("testid", "mooncode-new-session"),
        on_click=dispatch(NewMoonCodeSession),
        [ui_icon("chat"), span("New chat")],
      ),
      div(class="mooncode-session-search", [
        input(
          class="mooncode-session-search-input",
          attrs=@html.Attrs::build()
            .data_set("testid", "mooncode-session-search")
            .data_set("i18n-aria-label", "code.search_sessions")
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
      mooncode_sessions_state_panel(dispatch, model),
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
  let children : Map[String, @rabbita.Html] = Map([])
  let groups = mooncode_session_groups(model)
  let selected_id = selected_mooncode_session(model)
    .map(fn(item) { item.id })
    .unwrap_or("")
  let other_books : Array[MoonCodeSessionGroup] = []
  for group in groups {
    if model.mooncode_session_query.trim() == "" &&
      group.workspace_id != "" &&
      group.sessions.is_empty() &&
      !mooncode_session_group_active(model, group) {
      other_books.push(group)
      continue
    }
    children["group:" + group.id] = render_mooncode_session_group_heading(
      dispatch, model, group,
    )
    if group.sessions.length() == 0 &&
      mooncode_session_group_active(model, group) &&
      model.mooncode_sessions_state is Some(LegitimateZero) {
      children["group-empty:" + group.id] = p(
        class="status-line empty-list mooncode-session-group-empty",
        attrs=@html.Attrs::build().data_set(
          "i18n",
          if group.workspace_id == "" {
            "code.no_general_chats"
          } else {
            "code.no_chats"
          },
        ),
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
  if other_books.length() > 0 {
    children["other-books"] = details(class="mooncode-other-books", [
      summary(
        attrs=@html.Attrs::build()
          .data_set("i18n", "code.other_books")
          .data_set(
            "i18n-params",
            ({ "count": other_books.length() } : Json).stringify(),
          ),
        "Other MoonBooks · \{other_books.length()}",
      ),
      div(
        class="mooncode-other-books-list",
        other_books.map(group => {
          render_mooncode_session_group_heading(dispatch, model, group)
        }),
      ),
    ])
  }
  if groups.length() == 0 &&
    mooncode_sessions_listing_succeeded(model.mooncode_sessions_state) &&
    model.mooncode_session_query.trim().to_owned() != "" {
    children["search-empty"] = p(
      class="status-line empty-list mooncode-session-search-empty",
      attrs=@html.Attrs::build().data_set("i18n", "code.no_matching_chats"),
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
  let group_labels : Map[String, String] = Map([])
  let group_workspaces : Map[String, String] = Map([])
  let group_sessions : Map[String, Array[MoonCodeSession]] = Map([])
  if !searching {
    group_order.push("general")
    group_labels["general"] = "General"
    group_workspaces["general"] = ""
    group_sessions["general"] = []
    for workspace in model.workspaces {
      let group_id = "workspace:" + workspace.id
      if !mooncode_group_order_has(group_order, group_id) {
        group_order.push(group_id)
        group_labels[group_id] = mooncode_workspace_group_label(
          model,
          workspace.id,
          workspace.name,
        )
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
      group_labels[selected_group_id] = mooncode_workspace_group_label(
        model,
        model.selected_workspace_id,
        mooncode_workspace_name_for_id(model, model.selected_workspace_id),
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
    mooncode_workspace_group_label(
      model,
      session.workspace_id,
      session.workspace_name,
    )
  } else {
    mooncode_workspace_group_label(
      model,
      session.workspace_id,
      mooncode_workspace_name_for_id(model, session.workspace_id),
    )
  }
}

///|
/// A book title is not necessarily unique in a suite. Show its folder name
/// when needed so selecting a Code history group is unambiguous.
fn mooncode_workspace_group_label(
  model : Model,
  workspace_id : String,
  name : String,
) -> String {
  let mut root = ""
  let mut matching_names = 0
  for workspace in model.workspaces {
    if workspace.id == workspace_id {
      root = workspace.root_path
    }
    if workspace.name == name {
      matching_names += 1
    }
  }
  if matching_names > 1 && root != "" {
    name + " · " + @desk.display_name(root)
  } else {
    name
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
      .data_set(
        "i18n-title",
        if group.workspace_id == "" {
          "code.general_chats_title"
        } else {
          "code.book_chats_title"
        },
      )
      .data_set("i18n-params", ({ "name": group.label } : Json).stringify())
      .aria_pressed(if active { "true" } else { "false" }),
    title=if group.workspace_id == "" {
      "General chats without a MoonBook"
    } else {
      "MoonBook chats for \{group.label}"
    },
    on_click=dispatch(SelectWorkspace(group.workspace_id)),
    [
      span(class="mooncode-session-group-mark", ""),
      span(
        class="mooncode-session-group-name",
        attrs=@html.Attrs::build().data_set(
          if group.workspace_id == "" {
            "i18n"
          } else {
            "i18n-scope"
          },
          if group.workspace_id == "" {
            "code.general"
          } else {
            "content"
          },
        ),
        group.label,
      ),
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
                if mooncode_session_status_line(session) == "Ready" {
                  @html.nothing
                } else {
                  small(
                    attrs=if mooncode_session_status_i18n_key(session) == "" {
                      @html.Attrs::build()
                    } else {
                      @html.Attrs::build().data_set(
                        "i18n",
                        mooncode_session_status_i18n_key(session),
                      )
                    },
                    mooncode_session_status_line(session),
                  )
                },
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
  let children : Map[String, @rabbita.Html] = Map([])
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
  } else if session.status == "done" {
    "Completed"
  } else if session.status == "cancelled" {
    "Stopped"
  } else if session.status == "unknown" {
    "Status not loaded"
  } else {
    match session.updated_at {
      Some(value) if value != "" => browser_mooncode_relative_time(value)
      _ => "Ready"
    }
  }
}

///|
fn mooncode_session_status_i18n_key(session : MoonCodeSession) -> String {
  if session.queued_count > 0 || session.status == "queued" {
    "code.session_queued"
  } else if session.status == "running" {
    "code.session_working"
  } else if session.status == "failed" {
    "code.session_attention"
  } else if session.status == "done" {
    "code.session_completed"
  } else if session.status == "cancelled" {
    "code.session_stopped"
  } else if session.status == "unknown" {
    "code.session_unknown"
  } else {
    match session.updated_at {
      Some(value) if value != "" => ""
      _ => "code.session_ready"
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

