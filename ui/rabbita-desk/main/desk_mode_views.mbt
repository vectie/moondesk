///|
fn render_desk_mode(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  main_(
    class="desk-main file-desk-main",
    attrs=main_content_attrs(Desk).data_set("testid", "desk-mode"),
    [
      h1(class="visually-hidden", "Home"),
      render_desk_workspace_sidebar(dispatch, model),
      render_desk_file_browser(dispatch, model),
      render_desk_details(dispatch, model),
    ],
  )
}

///|
fn render_desk_workspace_sidebar(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let cold_start = classify_cold_start(model)
  aside(
    class="desk-sidebar",
    attrs=@html.Attrs::build().aria_label("MoonBook library"),
    [
      div(class="pane-heading", [
        div([h2("MoonBooks")]),
        button(
          class="secondary-button compact-button",
          title="Refresh",
          attrs=@html.Attrs::build().data_set(
            "testid", "desk-refresh-workspaces",
          ),
          on_click=dispatch(RefreshAll),
          "Refresh",
        ),
      ]),
      render_desk_library_location(dispatch, model),
      render_moongate_setup(dispatch, model),
      match cold_start {
        EmptyLibrary => render_new_moonbook_panel_open(dispatch, model)
        OneBook | ManyBooks => render_new_moonbook_panel(dispatch, model)
        Connecting | LibraryUnavailable | CatalogUnavailable => @html.nothing
      },
      div(
        class="desk-workspace-list",
        attrs=@html.Attrs::build().data_set("testid", "desk-workspace-list"),
        render_desk_workspace_rows(dispatch, model, cold_start),
      ),
      if model.favorites.length() > 0 || model.recent_paths.length() > 0 {
        render_desk_quick_access(dispatch, model)
      } else {
        div(class="desk-quick-access-empty", [@html.nothing])
      },
      render_desk_folder_outline(dispatch, model),
    ],
  )
}

///|
fn render_desk_workspace_rows(
  dispatch : Dispatch[Msg],
  model : Model,
  cold_start : ColdStartState,
) -> Array[@rabbita.Html] {
  if model.workspaces.is_empty() {
    let content : Array[@rabbita.Html] = [
      render_polite_state_announcement(
        "workspace-catalog-state-announcement",
        desk_empty_library_title(model),
        desk_empty_library_message(model),
      ),
      strong(desk_empty_library_title(model)),
      p(desk_empty_library_message(model)),
      render_desk_cold_start_action(dispatch, cold_start),
    ]
    if cold_start is CatalogUnavailable && model.workspace_catalog_error != "" {
      content.push(
        details(class="technical-details", [
          summary("Technical details"),
          code(model.workspace_catalog_error),
        ]),
      )
    }
    let state_content = if cold_start is CatalogUnavailable {
      div(
        class="workspace-catalog-state",
        attrs=@html.Attrs::build()
          .data_set("testid", "workspace-catalog-state-panel")
          .data_set("state", surface_state_key(RecoverableError)),
        content,
      )
    } else {
      @html.fragment(content)
    }
    return [
      div(
        class="desk-empty-state",
        attrs=@html.Attrs::build()
          .data_set("testid", "desk-cold-start")
          .data_set("state", cold_start_state_key(cold_start)),
        [state_content],
      ),
    ]
  }
  let rows : Array[@rabbita.Html] = []
  match model.workspace_catalog_state {
    Some(Loading) =>
      rows.push(render_workspace_catalog_state_panel(dispatch, model, Loading))
    Some(Stale) =>
      rows.push(render_workspace_catalog_state_panel(dispatch, model, Stale))
    _ => ()
  }
  for workspace in model.workspaces {
    rows.push(render_desk_workspace_row(dispatch, model, workspace))
  }
  rows
}

///|
fn render_workspace_catalog_state_panel(
  dispatch : Dispatch[Msg],
  model : Model,
  state : SurfaceState,
) -> @rabbita.Html {
  let children : Array[@rabbita.Html] = [
    render_polite_state_announcement(
      "workspace-catalog-state-announcement",
      workspace_catalog_state_title(state),
      workspace_catalog_state_detail(state),
    ),
    strong(workspace_catalog_state_title(state)),
    p(workspace_catalog_state_detail(state)),
  ]
  match workspace_catalog_state_action(state) {
    Some(label) =>
      children.push(
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set(
            "testid", "workspace-catalog-state-action",
          ),
          on_click=dispatch(RefreshAll),
          label,
        ),
      )
    None => ()
  }
  if workspace_catalog_state_shows_technical_details(state) &&
    model.workspace_catalog_error != "" {
    children.push(
      details(class="technical-details", [
        summary("Technical details"),
        code(model.workspace_catalog_error),
      ]),
    )
  }
  div(
    class="workspace-catalog-state",
    attrs=@html.Attrs::build()
      .data_set("testid", "workspace-catalog-state-panel")
      .data_set("state", surface_state_key(state)),
    children,
  )
}

///|
fn render_desk_workspace_row(
  dispatch : Dispatch[Msg],
  model : Model,
  workspace : @desk.DeskWorkspace,
) -> @rabbita.Html {
  let selected = workspace.id == model.selected_workspace_id
  let class_name = if selected {
    "desk-workspace-row active " + workspace_status_class(workspace.status)
  } else {
    "desk-workspace-row " + workspace_status_class(workspace.status)
  }
  let row_children : Array[@rabbita.Html] = [strong(workspace.name)]
  if workspace.status != Ready {
    row_children.push(
      span(
        class="desk-workspace-status",
        workspace_status_label(workspace.status),
      ),
    )
  }
  button(
    class=class_name,
    title=workspace.name +
      " / " +
      workspace_display_book_location(model, workspace),
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-workspace-row")
      .data_set("workspace-id", workspace.id)
      .data_set("status", workspace_status_key(workspace.status))
      .aria_pressed(if selected { "true" } else { "false" }),
    on_click=dispatch(SelectWorkspace(workspace.id)),
    row_children,
  )
}

///|
fn render_moongate_setup(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = moonclaw_capability_state(model.moonclaw_daemon)
  let action = code_capability_primary_action(state)
  section(
    id="moongate-summary",
    class=if state is DetectedRunning {
      "moongate-card ready"
    } else {
      "moongate-card blocked"
    },
    attrs=@html.Attrs::build()
      .data_set("testid", "moongate-summary")
      .data_set("state", capability_state_key(state))
      .aria_live("polite")
      .role("status"),
    [
      div(class="moongate-card-head", [
        div([
          p(
            class="eyebrow",
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.assistance_eyebrow",
            ),
            "Optional capability",
          ),
          strong(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.assistance_heading",
            ),
            "Code assistance",
          ),
        ]),
        span(
          class=if state is DetectedRunning {
            "status-pill ready"
          } else {
            "status-pill warning"
          },
          attrs=@html.Attrs::build().data_set(
            "i18n",
            code_capability_status_i18n_key(state),
          ),
          capability_status_label(state),
        ),
      ]),
      render_home_code_assistance_public(dispatch, model, state, action),
      render_code_assistance_technical_details(model),
    ],
  )
}

///|
fn render_code_capability_summary(state : CapabilityState) -> @rabbita.Html {
  div(class="code-capability-summary", [
    strong(
      attrs=@html.Attrs::build().data_set(
        "i18n",
        code_capability_title_i18n_key(state),
      ),
      code_capability_title(state),
    ),
    p(
      attrs=@html.Attrs::build().data_set(
        "i18n",
        code_capability_detail_i18n_key(state),
      ),
      code_capability_detail(state),
    ),
  ])
}

///|
fn render_home_code_assistance_public(
  dispatch : Dispatch[Msg],
  model : Model,
  state : CapabilityState,
  action : CodeCapabilityPrimaryAction,
) -> @rabbita.Html {
  div(
    class="moongate-next-step",
    attrs=@html.Attrs::build().data_set(
      "testid", "code-assistance-public-summary",
    ),
    [
      render_code_capability_summary(state),
      match action {
        StartCapability =>
          button(
            class="primary-button full",
            attrs=@html.Attrs::build()
              .data_set("testid", "moongate-start-moonclaw")
              .data_set("i18n", code_capability_primary_action_i18n_key(action)),
            on_click=dispatch(ManageMoonClaw("retry")),
            code_capability_primary_action_label(action),
          )
        InstallCapability =>
          div([
            button(
              class="primary-button full",
              attrs=@html.Attrs::build()
                .data_set("testid", "moongate-install-moonclaw")
                .data_set(
                  "i18n",
                  if model.moonclaw_installing {
                    if moonclaw_repair_available(model.moonclaw_daemon) {
                      "code.assistance_repairing"
                    } else {
                      "code.assistance_installing"
                    }
                  } else if moonclaw_repair_available(model.moonclaw_daemon) {
                    "code.assistance_action_repair"
                  } else {
                    code_capability_primary_action_i18n_key(action)
                  },
                ),
              disabled=model.moonclaw_installing,
              on_click=dispatch(ManageMoonClaw("install")),
              if model.moonclaw_installing {
                if moonclaw_repair_available(model.moonclaw_daemon) {
                  "Repairing Code assistance…"
                } else {
                  "Installing Code assistance…"
                }
              } else if moonclaw_repair_available(model.moonclaw_daemon) {
                "Repair Code assistance"
              } else {
                code_capability_primary_action_label(action)
              },
            ),
            render_moonclaw_install_progress(model),
          ])
        ConfigureCapability => render_moonclaw_first_run_setup(dispatch, model)
        OpenConfiguration =>
          button(
            class="primary-button full",
            attrs=@html.Attrs::build()
              .data_set("testid", "moongate-review-code-configuration")
              .data_set("i18n", code_capability_primary_action_i18n_key(action)),
            on_click=dispatch(SelectActivity(Settings)),
            code_capability_primary_action_label(action),
          )
        RetryCapabilityCheck =>
          button(
            class="primary-button full",
            attrs=@html.Attrs::build()
              .data_set("testid", "moongate-retry-code-assistance")
              .data_set("i18n", code_capability_primary_action_i18n_key(action)),
            on_click=dispatch(ManageMoonClaw("retry")),
            code_capability_primary_action_label(action),
          )
        NoPrimaryAction => @html.nothing
      },
      render_code_assistance_operation_alert(model),
    ],
  )
}

///|
fn render_code_assistance_operation_alert(model : Model) -> @rabbita.Html {
  if !model.moonclaw_operation_failed {
    return @html.nothing
  }
  div(
    class="surface-state-panel",
    attrs=@html.Attrs::build()
      .data_set("testid", "code-assistance-operation-error")
      .role("alert"),
    [
      strong("Code assistance setup didn’t finish"),
      if model.moonclaw_operation_status == "" {
        @html.nothing
      } else {
        p([span("Status: "), code(model.moonclaw_operation_status)])
      },
      if model.moonclaw_install_feedback == "" {
        @html.nothing
      } else {
        p(model.moonclaw_install_feedback)
      },
      match model.moonclaw_daemon {
        Some(daemon) =>
          match daemon.next_action {
            Some(next_action) if next_action != "" =>
              p([span("Next action: "), code(next_action)])
            _ => @html.nothing
          }
        None => @html.nothing
      },
    ],
  )
}

///|
fn render_moonclaw_first_run_setup(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let busy = model.moonclaw_auth_pending != ""
  let codex_url = moonclaw_codex_auth_url(model)
  let copilot_url = moonclaw_copilot_auth_url(model)
  let authorization_started = codex_url is Some(_) || copilot_url is Some(_)
  let setup_ready_to_check = (
      model.moonclaw_setup_started &&
      (
        !model.moonclaw_auth_failed ||
        model.moonclaw_auth_status == "auth_status_unknown" ||
        model.moonclaw_auth_status == "auth_status_request_failed"
      ) &&
      !authorization_started &&
      model.moonclaw_auth_pending == ""
    ) ||
    moonclaw_auth_has_connected_provider(model.moonclaw_auth)
  div(
    class="desk-detail-actions",
    attrs=@html.Attrs::build().data_set("testid", "code-assistance-first-run"),
    [
      match codex_url {
        Some(url) =>
          a(
            class="primary-button full link-button",
            href=url,
            target=Blank,
            rel="noopener noreferrer",
            attrs=@html.Attrs::build().data_set(
              "testid", "moonclaw-open-codex-auth",
            ),
            "Open Codex sign-in",
          )
        None =>
          match copilot_url {
            Some(url) =>
              a(
                class="primary-button full link-button",
                href=url,
                target=Blank,
                rel="noopener noreferrer",
                attrs=@html.Attrs::build().data_set(
                  "testid", "moonclaw-open-copilot-auth",
                ),
                "Open GitHub device authorization",
              )
            None =>
              if setup_ready_to_check {
                button(
                  class="primary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "moonclaw-check-setup",
                  ),
                  disabled=busy,
                  on_click=dispatch(CheckMoonClawSetup),
                  if model.moonclaw_auth_pending == "check" {
                    "Checking setup…"
                  } else {
                    "Check setup"
                  },
                )
              } else {
                button(
                  class="primary-button full",
                  attrs=@html.Attrs::build()
                    .data_set("testid", "moonclaw-connect-codex")
                    .data_set("i18n", "code.assistance_action_connect"),
                  disabled=busy,
                  on_click=dispatch(StartMoonClawAuth("codex")),
                  if model.moonclaw_auth_pending == "codex" {
                    "Starting Codex setup…"
                  } else {
                    "Connect Codex"
                  },
                )
              }
          }
      },
      if authorization_started {
        button(
          class="secondary-button full",
          attrs=@html.Attrs::build().data_set("testid", "moonclaw-check-setup"),
          disabled=busy,
          on_click=dispatch(CheckMoonClawSetup),
          if model.moonclaw_auth_pending == "check" {
            "Checking setup…"
          } else {
            "Check setup"
          },
        )
      } else {
        @html.nothing
      },
      if setup_ready_to_check || authorization_started {
        button(
          class="secondary-button full",
          attrs=@html.Attrs::build().data_set(
            "testid", "moonclaw-connect-codex",
          ),
          disabled=busy,
          on_click=dispatch(StartMoonClawAuth("codex")),
          "Connect Codex",
        )
      } else {
        @html.nothing
      },
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set(
          "testid", "moonclaw-connect-copilot",
        ),
        disabled=busy,
        on_click=dispatch(StartMoonClawAuth("copilot")),
        if model.moonclaw_auth_pending == "copilot" {
          "Starting GitHub Copilot setup…"
        } else {
          "Connect GitHub Copilot"
        },
      ),
      render_moonclaw_auth_flow(model),
      details(
        class="technical-details",
        attrs=@html.Attrs::build().data_set(
          "testid", "moonclaw-openrouter-setup",
        ),
        [
          summary("Use OpenRouter API key"),
          @html.label(
            class="mini-label",
            for_="moonclaw-openrouter-key",
            "OpenRouter API key",
          ),
          input(
            id="moonclaw-openrouter-key",
            class="line-input",
            input_type=Password,
            auto_complete=Off,
            value=model.moonclaw_openrouter_key,
            on_input=fn(value) { dispatch(SetMoonClawOpenRouterKey(value)) },
          ),
          button(
            class="secondary-button full",
            attrs=@html.Attrs::build().data_set(
              "testid", "moonclaw-save-openrouter-key",
            ),
            disabled=busy,
            on_click=dispatch(SaveMoonClawOpenRouterKey),
            if model.moonclaw_auth_pending == "openrouter" {
              "Saving API key…"
            } else {
              "Save API key"
            },
          ),
        ],
      ),
      render_moonclaw_auth_feedback(model),
    ],
  )
}

///|
fn render_moonclaw_auth_flow(model : Model) -> @rabbita.Html {
  let children : Array[@rabbita.Html] = []
  match model.moonclaw_codex_auth_flow {
    Some(flow) =>
      match flow.auth_url {
        Some(url) if url != "" =>
          children.push(
            div(
              class="surface-state-panel",
              attrs=@html.Attrs::build().data_set(
                "testid", "moonclaw-codex-auth-flow",
              ),
              [
                strong("Codex sign-in is ready"),
                p(
                  "Open the sign-in page, complete authorization, then check setup.",
                ),
              ],
            ),
          )
        _ => ()
      }
    None => ()
  }
  match model.moonclaw_copilot_auth_flow {
    Some(flow) =>
      match (flow.user_code, flow.verification_uri) {
        (Some(user_code), Some(url)) if user_code != "" && url != "" =>
          children.push(
            div(
              class="surface-state-panel",
              attrs=@html.Attrs::build().data_set(
                "testid", "moonclaw-copilot-auth-flow",
              ),
              [
                strong("GitHub Copilot device code"),
                p([span("Code: "), code(user_code)]),
              ],
            ),
          )
        _ => ()
      }
    None => ()
  }
  if children.is_empty() {
    @html.nothing
  } else {
    div(class="moonclaw-auth-flow", children)
  }
}

///|
fn moonclaw_codex_auth_url(model : Model) -> String? {
  match model.moonclaw_codex_auth_flow {
    Some(flow) =>
      match flow.auth_url {
        Some(url) if url != "" => Some(url)
        _ => None
      }
    None => None
  }
}

///|
fn moonclaw_copilot_auth_url(model : Model) -> String? {
  match model.moonclaw_copilot_auth_flow {
    Some(flow) =>
      match flow.verification_uri {
        Some(url) if url != "" => Some(url)
        _ => None
      }
    None => None
  }
}

///|
fn render_moonclaw_auth_feedback(model : Model) -> @rabbita.Html {
  if model.moonclaw_auth_feedback == "" {
    return @html.nothing
  }
  div(
    class=if model.moonclaw_auth_failed {
      "surface-state-panel"
    } else {
      "status-line"
    },
    attrs=if model.moonclaw_auth_failed {
      @html.Attrs::build()
      .data_set("testid", "moonclaw-auth-feedback")
      .role("alert")
    } else {
      @html.Attrs::build()
      .data_set("testid", "moonclaw-auth-feedback")
      .role("status")
      .aria_live("polite")
    },
    [
      if model.moonclaw_auth_status == "" {
        @html.nothing
      } else {
        p([span("Status: "), code(model.moonclaw_auth_status)])
      },
      p(model.moonclaw_auth_feedback),
    ],
  )
}

///|
fn render_code_assistance_technical_details(model : Model) -> @rabbita.Html {
  details(
    class="moongate-details technical-details",
    attrs=@html.Attrs::build().data_set(
      "testid", "code-assistance-technical-details",
    ),
    [
      summary("Technical details"),
      info_row("Service", "MoonClaw"),
      match model.moonclaw_daemon {
        Some(daemon) =>
          @html.fragment([
            info_row("Running", if daemon.running { "yes" } else { "no" }),
            info_row(
              "Managed installation",
              match daemon.managed_install {
                Some(true) => "present"
                Some(false) => "absent"
                None => "not reported"
              },
            ),
            info_row(
              "Managed process",
              match daemon.managed_running {
                Some(true) => "running"
                Some(false) => "stopped"
                None => "not reported"
              },
            ),
            if daemon.message == "" {
              @html.nothing
            } else {
              info_row("Service message", daemon.message)
            },
            match daemon.status {
              Some(status) if status != "" => info_row("Status code", status)
              _ => @html.nothing
            },
            match daemon.next_action {
              Some(next_action) if next_action != "" =>
                info_row("Next action", next_action)
              _ => @html.nothing
            },
            info_row(
              "Model ready",
              match moonclaw_model_ready(Some(daemon)) {
                Some(true) => "yes"
                Some(false) => "no"
                None => "not reported"
              },
            ),
            info_row(
              "Repair available",
              if moonclaw_repair_available(Some(daemon)) {
                "yes"
              } else {
                "no"
              },
            ),
            match capability_platform_technical_detail(daemon) {
              Some(detail) => p(detail)
              None => @html.nothing
            },
            match daemon.installation_evidence {
              Some(evidence) =>
                @html.fragment([
                  info_row("Installation source", evidence.source),
                  info_row("Installation reason", evidence.reason),
                ])
              None => @html.nothing
            },
            match daemon.configuration_evidence {
              Some(evidence) =>
                info_row("Configuration reason", evidence.reason)
              None => @html.nothing
            },
          ])
        None => p("No daemon status response was available.")
      },
      if model.moonclaw_install_feedback == "" {
        @html.nothing
      } else {
        info_row("Installation detail", model.moonclaw_install_feedback)
      },
      p(
        "Authority: workspace-local assistance only. Network, publication, physical action, and new credentials require separate authority.",
      ),
    ],
  )
}

///|
fn render_moonclaw_install_progress(model : Model) -> @rabbita.Html {
  if !model.moonclaw_installing {
    return @html.nothing
  }
  div(class="moonclaw-install-progress", [
    div(
      class="moonclaw-install-progress-bar",
      attrs=@html.Attrs::build()
        .data_set("testid", "moonclaw-install-progress")
        .role("progressbar"),
      [span(class="moonclaw-install-progress-value", "")],
    ),
    p(
      class="status-line",
      attrs=@html.Attrs::build()
        .data_set("i18n", "code.assistance_install_progress")
        .aria_live("polite"),
      "Preparing Code assistance. This can take a moment.",
    ),
  ])
}

///|
fn desk_empty_library_title(model : Model) -> String {
  cold_start_title(classify_cold_start(model))
}

///|
fn desk_empty_library_message(model : Model) -> String {
  cold_start_detail(classify_cold_start(model))
}

///|
fn render_desk_cold_start_action(
  dispatch : Dispatch[Msg],
  state : ColdStartState,
) -> @rabbita.Html {
  match cold_start_primary_action(state) {
    Refresh =>
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().data_set("testid", "desk-cold-start-primary"),
        on_click=dispatch(RefreshAll),
        cold_start_primary_action_label(Refresh),
      )
    ChooseLibrary =>
      button(
        class="primary-button compact-button",
        attrs=@html.Attrs::build().data_set("testid", "desk-cold-start-primary"),
        on_click=dispatch(PickLibraryFolder),
        cold_start_primary_action_label(ChooseLibrary),
      )
    AddMoonBook | OpenMoonBook | ChooseMoonBook => @html.nothing
  }
}

///|
fn render_desk_quick_access(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let groups : Array[@rabbita.Html] = []
  let recent_paths = model.recent_paths.filter(path => {
    !model.favorites.contains(path)
  })
  if model.favorites.length() > 0 {
    groups.push(
      render_desk_quick_path_group(
        dispatch,
        model,
        "Favorites",
        "desk-favorite-row",
        model.favorites,
      ),
    )
  }
  if recent_paths.length() > 0 {
    groups.push(
      render_desk_quick_path_group(
        dispatch, model, "Recent", "desk-recent-row", recent_paths,
      ),
    )
  }
  section(
    class="desk-quick-access",
    attrs=@html.Attrs::build().data_set("testid", "desk-quick-access"),
    [
      div(class="pane-heading compact-heading", [div([h2("Quick Access")])]),
      div(class="desk-quick-groups", groups),
    ],
  )
}

///|
fn render_desk_quick_path_group(
  dispatch : Dispatch[Msg],
  model : Model,
  label : String,
  testid : String,
  paths : Array[String],
) -> @rabbita.Html {
  div(class="desk-quick-group", [
    strong(label),
    div(
      class="desk-quick-list",
      paths.map(path => {
        button(
          class=desk_quick_path_row_class(model, path),
          title=path,
          attrs=@html.Attrs::build()
            .data_set("testid", testid)
            .data_set("path", path),
          on_click=dispatch(OpenQuickPath(path)),
          [
            span(class="tree-icon", icon_for_kind(quick_path_kind(model, path))),
            span(class="folder-label", empty_root_path(path)),
          ],
        )
      }),
    ),
  ])
}

///|
fn desk_quick_path_row_class(model : Model, path : String) -> String {
  if model.selected_path == path {
    "desk-quick-row active"
  } else {
    "desk-quick-row"
  }
}

///|
fn quick_path_kind(model : Model, path : String) -> @desk.EntryKind {
  match find_entry(model, path) {
    Some(entry) => entry.kind
    None => Unknown
  }
}

///|
fn render_desk_library_location(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="desk-library-location",
    attrs=@html.Attrs::build().data_set("testid", "desk-library-root"),
    [
      div(class="desk-library-summary", [
        div([p(class="eyebrow", "Library"), strong("My MoonBooks")]),
        span(class="desk-library-count", workspace_library_count_label(model)),
      ]),
      render_desk_library_diagnostics(dispatch, model),
    ],
  )
}

///|
fn render_desk_library_diagnostics(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  desk_disclosure(
    "desk-library-diagnostics",
    "desk-library-storage-details",
    "Storage & services",
    [
      div(class="desk-technical-list", [
        info_row("Library", workspace_moonbook_library_path(model)),
        info_row("Suite", workspace_library_root(model)),
      ]),
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().data_set(
          "testid", "desk-change-library-folder",
        ),
        title="Choose a different MoonBook library folder",
        on_click=dispatch(PickLibraryFolder),
        "Change library folder",
      ),
      p(
        class="status-line",
        attrs=@html.Attrs::build().data_set(
          "testid", "desk-library-selection-status",
        ),
        model.host_status,
      ),
      render_desk_service_status(model),
      render_desk_product_summary(model),
    ],
  )
}

///|
fn desk_disclosure(
  class_name : String,
  testid : String,
  label : String,
  children : Array[@rabbita.Html],
) -> @rabbita.Html {
  desk_disclosure_with_open(class_name, testid, label, false, children)
}

///|
fn desk_disclosure_with_open(
  class_name : String,
  testid : String,
  label : String,
  open : Bool,
  children : Array[@rabbita.Html],
) -> @rabbita.Html {
  @html.node(
    "details",
    @html.Attrs::build().class(class_name).data_set("testid", testid).open(open),
    [
      @html.node(
        "summary",
        @html.Attrs::build().class("desk-disclosure-summary"),
        [span(label)],
      ),
      div(class="desk-disclosure-body", children),
    ],
  )
}

///|
fn render_desk_service_status(model : Model) -> @rabbita.Html {
  section(
    class="desk-service-status",
    attrs=@html.Attrs::build().data_set("testid", "desk-service-status"),
    [
      strong(class="desk-technical-heading", "Services"),
      div(
        class="desk-service-list",
        workspace_service_status_items(model).map(item => {
          let (name, status, detail) = item
          div(
            class="desk-service-row status-" + status,
            attrs=@html.Attrs::build()
              .data_set("testid", "desk-service-row")
              .data_set("service", name)
              .data_set("status", status),
            [
              span(class="status-dot " + service_status_dot_class(status), ""),
              strong(name),
              small(detail),
            ],
          )
        }),
      ),
    ],
  )
}

///|
fn service_status_dot_class(status : String) -> String {
  match status {
    "ready" => "live"
    "missing" => "idle"
    _ => "idle"
  }
}

///|
fn render_desk_product_summary(model : Model) -> @rabbita.Html {
  let products = workspace_display_products(model)
  if products.length() == 0 {
    p(class="status-line", "Product registry pending")
  } else {
    div(class="desk-product-summary", [
      small(workspace_product_count_label(model)),
      div(
        class="desk-product-strip",
        products.map(product => {
          span(
            class="desk-product-chip status-" + product.status,
            title=workspace_product_chip_title(product),
            [
              span(class="status-dot live", ""),
              span(product.name),
              small(workspace_product_status_label(product)),
            ],
          )
        }),
      ),
    ])
  }
}

///|
fn render_new_moonbook_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  render_new_moonbook_panel_with_open(dispatch, model, false)
}

///|
fn render_new_moonbook_panel_open(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  render_new_moonbook_panel_with_open(dispatch, model, true)
}

///|
fn render_new_moonbook_panel_with_open(
  dispatch : Dispatch[Msg],
  model : Model,
  open : Bool,
) -> @rabbita.Html {
  desk_disclosure_with_open(
    "desk-add-book-disclosure",
    "desk-add-moonbook",
    "Add MoonBook",
    open,
    [
      section(class="desk-new-book-panel", [
        div(class="desk-library-action", [
          strong("Create new"),
          input(
            class="line-input",
            attrs=@html.Attrs::build()
              .data_set("testid", "desk-new-book-name")
              .aria_label("MoonBook name"),
            value=model.new_book_name,
            placeholder="MoonBook name",
            on_input=fn(value) { dispatch(SetNewBookName(value)) },
          ),
          input(
            class="line-input",
            attrs=@html.Attrs::build()
              .data_set("testid", "desk-new-book-id")
              .aria_label("Optional folder name"),
            value=model.new_book_id,
            placeholder="Optional folder name",
            on_input=fn(value) { dispatch(SetNewBookId(value)) },
          ),
          button(
            class="primary-button full",
            attrs=@html.Attrs::build().data_set("testid", "desk-create-book"),
            title="Create MoonBook",
            disabled=desk_create_book_disabled(model),
            on_click=dispatch(CreateBlankMoonBook),
            "Create MoonBook",
          ),
          render_desk_operation_status("status-line", model.new_book_status),
        ]),
        div(class="desk-library-action", [
          strong("Import existing"),
          button(
            class="secondary-button full",
            attrs=@html.Attrs::build().data_set(
              "testid", "desk-import-book-folder",
            ),
            title="Choose a MoonBook folder",
            on_click=dispatch(PickImportMoonBookFolder),
            "Choose Folder",
          ),
          button(
            class="secondary-button full",
            attrs=@html.Attrs::build().data_set(
              "testid", "desk-import-book-archive",
            ),
            title="Choose a zipped MoonBook archive",
            on_click=dispatch(PickImportMoonBookArchive),
            "Choose Archive",
          ),
          desk_disclosure(
            "desk-advanced-import",
            "desk-import-from-path",
            "Import from path",
            [
              input(
                class="line-input",
                attrs=@html.Attrs::build().data_set(
                  "testid", "desk-import-book-path",
                ),
                value=model.import_book_path,
                placeholder="Folder path",
                on_input=fn(value) { dispatch(SetImportBookPath(value)) },
              ),
              button(
                class="secondary-button full",
                attrs=@html.Attrs::build().data_set(
                  "testid", "desk-import-book",
                ),
                title="Import a MoonBook from a folder path",
                disabled=desk_import_book_disabled(model),
                on_click=dispatch(ImportMoonBook),
                "Import Path",
              ),
            ],
          ),
          render_desk_operation_status("status-line", model.import_book_status),
        ]),
      ]),
    ],
  )
}

///|
fn desk_create_book_disabled(model : Model) -> Bool {
  model.new_book_name.trim().to_owned() == "" &&
  model.new_book_id.trim().to_owned() == ""
}

///|
fn desk_import_book_disabled(model : Model) -> Bool {
  model.import_book_path.trim().to_owned() == ""
}

///|
fn desk_workspace_action_disabled(model : Model) -> Bool {
  model.selected_workspace_id == ""
}

///|
fn render_desk_folder_outline(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="desk-folder-outline", [
    div(class="pane-heading compact-heading", [
      div([p(class="eyebrow", "folders"), h2("Directory")]),
    ]),
    div(
      class="desk-folder-list",
      attrs=@html.Attrs::build().data_set("testid", "desk-folder-list"),
      desk_folder_outline(model.current_directory, model.entries).map(item => {
        let (label, path, active, depth) = item
        button(
          class=desk_folder_outline_row_class(active, depth),
          title=empty_root_path(path),
          on_click=dispatch(OpenDirectory(path)),
          [
            span(class="folder-indent", ""),
            span(class="tree-icon", "D"),
            span(class="folder-label", label),
          ],
        )
      }),
    ),
  ])
}

///|
fn render_desk_file_browser(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let visible_entries = sorted_desk_entries(model)
  section(class="desk-browser", [
    div(class="desk-browser-head", [
      div(class="desk-browser-title", [
        div(class="desk-browser-location", [
          if model.selected_workspace_id == "" {
            span(class="desk-browser-workspace-empty", "")
          } else {
            small(class="desk-browser-workspace", workspace_name(model))
          },
          h2(desk_directory_title(model.current_directory)),
        ]),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-refresh"),
          title="Refresh this folder",
          on_click=dispatch(RefreshAll),
          "Refresh",
        ),
      ]),
      div(class="toolbar-actions", [
        div(class="desk-navigation-actions", [
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "desk-back"),
            title="Back",
            disabled=desk_workspace_action_disabled(model) ||
              model.desk_back_stack.length() == 0,
            on_click=dispatch(NavigateDeskBack),
            "Back",
          ),
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "desk-forward"),
            title="Forward",
            disabled=desk_workspace_action_disabled(model) ||
              model.desk_forward_stack.length() == 0,
            on_click=dispatch(NavigateDeskForward),
            "Forward",
          ),
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "desk-up"),
            title="Open parent folder",
            disabled=desk_workspace_action_disabled(model) ||
              model.current_directory == "",
            on_click=dispatch(
              OpenDirectory(parent_path(model.current_directory)),
            ),
            "Up",
          ),
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "desk-root"),
            title="Open MoonBook home",
            disabled=desk_workspace_action_disabled(model) ||
              model.current_directory == "",
            on_click=dispatch(OpenDirectory("")),
            "Home",
          ),
        ]),
        input(
          class="line-input compact-input desk-filter-input",
          attrs=@html.Attrs::build()
            .data_set("testid", "desk-filter-query")
            .disabled(desk_workspace_action_disabled(model)),
          value=model.desk_filter_query,
          placeholder="Search this folder",
          on_input=fn(value) { dispatch(SetDeskFilterQuery(value)) },
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-clear-filter"),
          title="Clear folder search",
          disabled=desk_workspace_action_disabled(model) ||
            model.desk_filter_query.trim().to_owned() == "",
          on_click=dispatch(SetDeskFilterQuery("")),
          "Clear",
        ),
        render_desk_new_item_disclosure(dispatch, model),
        render_desk_import_disclosure(dispatch, model),
        desk_disclosure(
          "desk-toolbar-disclosure desk-view-disclosure",
          "desk-view-options",
          "View",
          [
            render_desk_density_control(dispatch, model),
            button(
              class="secondary-button compact-button",
              attrs=@html.Attrs::build().data_set(
                "testid", "desk-sort-source-area",
              ),
              title="Sort by source area",
              on_click=dispatch(SetDeskSort(SortByLayer)),
              "Sort by source area",
            ),
          ],
        ),
      ]),
    ]),
    render_desk_breadcrumb(dispatch, model.current_directory),
    render_desk_location_bar(dispatch, model),
    render_desk_operation_status(
      "desk-create-status",
      model.desk_new_item_status,
    ),
    div(class=desk_file_table_class(model), [
      div(class="desk-file-row desk-file-header", [
        desk_sort_header_button(dispatch, model, SortByName, "Name"),
        desk_sort_header_button(dispatch, model, SortByKind, "Type"),
        desk_sort_header_button(dispatch, model, SortByModified, "Modified"),
        desk_sort_header_button(dispatch, model, SortBySize, "Size"),
      ]),
      div(
        class="desk-file-rows",
        attrs=@html.Attrs::build()
          .data_set("testid", "desk-file-list")
          .tabindex(0)
          .role("listbox")
          .aria_label("Desk file list")
          .aria_multiselectable("true"),
        on_keydown=fn(keyboard) { dispatch(desk_keyboard_msg(keyboard)) },
        render_desk_file_rows(dispatch, model, visible_entries),
      ),
    ]),
  ])
}

///|
fn render_desk_file_rows(
  dispatch : Dispatch[Msg],
  model : Model,
  visible_entries : Array[@desk.DeskFileEntry],
) -> Array[@rabbita.Html] {
  let rows : Array[@rabbita.Html] = []
  match model.desk_entries_state {
    Some(state) => {
      rows.push(render_desk_entries_state_panel(dispatch, model, state))
      if (state is Loading || state is Stale) && !visible_entries.is_empty() {
        for entry in visible_entries {
          rows.push(render_desk_file_row(dispatch, model, entry))
        }
      }
    }
    None =>
      if model.entries.is_empty() {
        rows.push(
          render_desk_entries_state_panel(dispatch, model, RecoverableError),
        )
      } else if visible_entries.is_empty() {
        rows.push(
          div(class="desk-empty", [
            strong("No matching files"),
            p("Clear the filter to show all items in this folder."),
          ]),
        )
      } else {
        for entry in visible_entries {
          rows.push(render_desk_file_row(dispatch, model, entry))
        }
      }
  }
  rows
}

///|
fn render_desk_entries_state_panel(
  dispatch : Dispatch[Msg],
  model : Model,
  state : SurfaceState,
) -> @rabbita.Html {
  let children : Array[@rabbita.Html] = if state is LegitimateZero {
    [
      div(attrs=@html.Attrs::build().data_set("testid", "desk-empty-folder"), [
        render_polite_state_announcement(
          "desk-entries-state-announcement",
          desk_entries_state_title(state, model),
          desk_entries_state_detail(state, model),
        ),
      ]),
    ]
  } else {
    [
      render_polite_state_announcement(
        "desk-entries-state-announcement",
        desk_entries_state_title(state, model),
        desk_entries_state_detail(state, model),
      ),
    ]
  }
  match desk_entries_state_action(state) {
    Some(label) =>
      children.push(
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set(
            "testid", "desk-entries-state-action",
          ),
          on_click=dispatch(RefreshAll),
          label,
        ),
      )
    None => ()
  }
  if desk_entries_state_shows_technical_detail(state) &&
    model.desk_entries_error != "" {
    children.push(
      details(class="desk-state-technical", [
        summary("Technical details"),
        code(model.desk_entries_error),
      ]),
    )
  }
  div(
    class="desk-empty desk-entries-state",
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-entries-state-panel")
      .data_set("state", desk_entries_state_key(state)),
    children,
  )
}

///|
fn render_desk_new_item_disclosure(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  desk_disclosure("desk-toolbar-disclosure", "desk-new-menu", "New", [
    input(
      class="line-input compact-input",
      attrs=@html.Attrs::build()
        .data_set("testid", "desk-new-item-name")
        .disabled(desk_workspace_action_disabled(model)),
      value=model.desk_new_item_name,
      placeholder="Name",
      on_input=fn(value) { dispatch(SetDeskNewItemName(value)) },
    ),
    div(class="desk-disclosure-actions", [
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().data_set("testid", "desk-new-folder"),
        title="Create folder here",
        disabled=desk_workspace_action_disabled(model),
        on_click=dispatch(CreateDeskFolder),
        "Folder",
      ),
      button(
        class="secondary-button compact-button",
        attrs=@html.Attrs::build().data_set("testid", "desk-new-note"),
        title="Create Markdown note here",
        disabled=desk_workspace_action_disabled(model),
        on_click=dispatch(CreateDeskMarkdown),
        "Note",
      ),
    ]),
  ])
}

///|
fn render_desk_import_disclosure(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  desk_disclosure("desk-toolbar-disclosure", "desk-import-menu", "Import", [
    button(
      class="secondary-button compact-button",
      attrs=@html.Attrs::build().data_set("testid", "desk-import-files"),
      title="Import files here",
      disabled=desk_workspace_action_disabled(model),
      on_click=dispatch(ImportLocalFilesToDesk),
      "Files",
    ),
    button(
      class="secondary-button compact-button",
      attrs=@html.Attrs::build().data_set("testid", "desk-import-folder"),
      title="Import a folder here",
      disabled=desk_workspace_action_disabled(model),
      on_click=dispatch(ImportLocalFolderToDesk),
      "Folder",
    ),
  ])
}

///|
fn render_desk_operation_status(
  class_name : String,
  status : String,
) -> @rabbita.Html {
  if status == "" || status.has_prefix("ready to ") {
    span(class="desk-status-empty", "")
  } else {
    p(
      class=class_name,
      attrs=@html.Attrs::build().role("status").aria_live("polite"),
      status,
    )
  }
}

///|
fn desk_empty_folder_title(model : Model) -> String {
  if model.selected_workspace_id == "" {
    "No MoonBook selected"
  } else if model.current_directory == "" {
    "This MoonBook root is empty"
  } else {
    "This folder is empty"
  }
}

///|
fn desk_empty_folder_message(model : Model) -> String {
  if model.selected_workspace_id == "" {
    "Select or create a MoonBook to browse its files."
  } else if model.current_directory == "" {
    "Create a folder, create a note, import files, or paste items into this MoonBook."
  } else {
    "Create a folder, create a note, import files, or paste items into \{empty_root_path(model.current_directory)}."
  }
}

///|
fn render_desk_density_control(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(
    class="desk-density-control",
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-density-control")
      .role("group")
      .aria_label("Desk row density"),
    [
      button(
        class=desk_density_button_class(model, DeskDensityComfortable),
        attrs=@html.Attrs::build().data_set(
          "testid", "desk-density-comfortable",
        ),
        title="Use comfortable Desk row spacing",
        on_click=dispatch(SetDeskDensity(DeskDensityComfortable)),
        "Comfort",
      ),
      button(
        class=desk_density_button_class(model, DeskDensityCompact),
        attrs=@html.Attrs::build().data_set("testid", "desk-density-compact"),
        title="Use compact Desk row spacing",
        on_click=dispatch(SetDeskDensity(DeskDensityCompact)),
        "Compact",
      ),
    ],
  )
}

///|
fn desk_file_table_class(model : Model) -> String {
  match model.desk_density {
    DeskDensityComfortable => "desk-file-table density-comfortable"
    DeskDensityCompact => "desk-file-table density-compact"
  }
}

///|
fn desk_density_button_class(model : Model, density : DeskDensity) -> String {
  if model.desk_density == density {
    "secondary-button compact-button density-button active"
  } else {
    "secondary-button compact-button density-button"
  }
}

///|
fn desk_sort_header_button(
  dispatch : Dispatch[Msg],
  model : Model,
  key : DeskSortKey,
  label : String,
) -> @rabbita.Html {
  button(
    class=desk_sort_header_class(model, key),
    title="Sort by " + label,
    on_click=dispatch(SetDeskSort(key)),
    desk_sort_header_label(model, key, label),
  )
}

///|
fn desk_sort_header_class(model : Model, key : DeskSortKey) -> String {
  if model.desk_sort_key == key {
    "desk-sort-button active"
  } else {
    "desk-sort-button"
  }
}

///|
fn desk_sort_header_label(
  model : Model,
  key : DeskSortKey,
  label : String,
) -> String {
  if model.desk_sort_key != key {
    label
  } else if model.desk_sort_desc {
    label + " v"
  } else {
    label + " ^"
  }
}

///|
fn sorted_desk_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  let entries = filtered_desk_entries(model)
  let sorted : Array[@desk.DeskFileEntry] = []
  let added : Array[String] = []
  while sorted.length() < entries.length() {
    let mut best : @desk.DeskFileEntry? = None
    for entry in entries {
      if added.contains(entry.id) {
        continue
      }
      match best {
        Some(current) =>
          if desk_entry_before(entry, current, model) {
            best = Some(entry)
          }
        None => best = Some(entry)
      }
    }
    match best {
      Some(entry) => {
        sorted.push(entry)
        added.push(entry.id)
      }
      None => break
    }
  }
  sorted
}

///|
fn filtered_desk_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  let query = model.desk_filter_query.trim().to_owned().to_lower()
  if query == "" {
    model.entries
  } else {
    model.entries.filter(entry => desk_entry_matches_filter(entry, query))
  }
}

///|
fn desk_entry_matches_filter(
  entry : @desk.DeskFileEntry,
  query : String,
) -> Bool {
  entry.display_name.to_lower().contains(query) ||
  entry.path.to_lower().contains(query)
}

///|
fn desk_entry_before(
  left : @desk.DeskFileEntry,
  right : @desk.DeskFileEntry,
  model : Model,
) -> Bool {
  let left_directory = left.kind is Directory
  let right_directory = right.kind is Directory
  if left_directory && !right_directory {
    return true
  }
  if !left_directory && right_directory {
    return false
  }
  let order = desk_entry_sort_compare(left, right, model.desk_sort_key)
  let directional = if model.desk_sort_desc { 0 - order } else { order }
  directional < 0
}

///|
fn desk_entry_sort_compare(
  left : @desk.DeskFileEntry,
  right : @desk.DeskFileEntry,
  key : DeskSortKey,
) -> Int {
  let primary = match key {
    SortByName => desk_string_compare(left.display_name, right.display_name)
    SortByKind =>
      desk_string_compare(kind_label(left.kind), kind_label(right.kind))
    SortByLayer =>
      desk_string_compare(
        layer_label(left.source_layer),
        layer_label(right.source_layer),
      )
    SortByModified =>
      desk_optional_string_compare(left.modified_at, right.modified_at)
    SortBySize => desk_optional_int_compare(left.size_bytes, right.size_bytes)
  }
  if primary != 0 {
    primary
  } else {
    let name = desk_string_compare(left.display_name, right.display_name)
    if name != 0 {
      name
    } else {
      desk_string_compare(left.path, right.path)
    }
  }
}

///|
fn desk_optional_string_compare(left : String?, right : String?) -> Int {
  match (left, right) {
    (Some(left), Some(right)) => desk_string_compare(left, right)
    (Some(_), None) => -1
    (None, Some(_)) => 1
    (None, None) => 0
  }
}

///|
fn desk_optional_int_compare(left : Int?, right : Int?) -> Int {
  match (left, right) {
    (Some(left), Some(right)) =>
      if left < right {
        -1
      } else if left > right {
        1
      } else {
        0
      }
    (Some(_), None) => -1
    (None, Some(_)) => 1
    (None, None) => 0
  }
}

///|
fn desk_string_compare(left : String, right : String) -> Int {
  let left_chars = desk_string_chars(left.to_lower())
  let right_chars = desk_string_chars(right.to_lower())
  let limit = if left_chars.length() < right_chars.length() {
    left_chars.length()
  } else {
    right_chars.length()
  }
  for index in 0..<limit {
    let left_code = left_chars[index].to_int()
    let right_code = right_chars[index].to_int()
    if left_code < right_code {
      return -1
    }
    if left_code > right_code {
      return 1
    }
  }
  if left_chars.length() < right_chars.length() {
    -1
  } else if left_chars.length() > right_chars.length() {
    1
  } else {
    0
  }
}

///|
fn desk_string_chars(value : String) -> Array[Char] {
  let chars : Array[Char] = []
  for ch in value {
    chars.push(ch)
  }
  chars
}

///|
fn render_desk_location_bar(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let visible_entries = filtered_desk_entries(model)
  let counts = desk_entry_counts(visible_entries)
  div(class="desk-location-bar", [
    div(class="desk-location-meta", [
      span(
        desk_entry_count_label_for_model(
          model,
          counts,
          visible_entries.length(),
        ),
      ),
      span(desk_selection_label(model)),
      span(desk_access_label(selected_desk_entry(model))),
    ]),
    desk_disclosure(
      "desk-location-disclosure",
      "desk-go-to-folder",
      "Go to folder",
      [
        div(class="desk-location-path", [
          input(
            class="line-input desk-location-input",
            attrs=@html.Attrs::build()
              .data_set("testid", "desk-location-input")
              .disabled(desk_workspace_action_disabled(model)),
            value=model.desk_location_input,
            placeholder="Folder path",
            on_input=fn(value) { dispatch(SetDeskLocationInput(value)) },
          ),
          button(
            class="secondary-button compact-button",
            attrs=@html.Attrs::build().data_set("testid", "desk-location-go"),
            title="Open folder",
            disabled=desk_workspace_action_disabled(model),
            on_click=dispatch(OpenDeskLocation),
            "Go",
          ),
        ]),
      ],
    ),
  ])
}

///|
fn render_desk_file_row(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
) -> @rabbita.Html {
  let class_name = desk_file_row_class(model, entry)
  let selected_value = if desk_entry_is_selected(model, entry.path) {
    "true"
  } else {
    "false"
  }
  let open_msg = if entry.kind is Directory {
    OpenDirectory(entry.path)
  } else {
    SelectPath(entry.path)
  }
  div(
    class=class_name,
    title=entry.path,
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-file-row")
      .data_set("path", entry.path)
      .role("option")
      .aria_selected(selected_value)
      .on_mousedown(fn(event) {
        dispatch(desk_mouse_event_msg(entry.path, event))
      })
      .on_dblclick(fn(_) { dispatch(open_msg) }),
    [
      span(class="desk-file-name", [
        span(class="tree-icon", icon_for_kind(entry.kind)),
        if model.desk_rename_editing_path == entry.path {
          desk_inline_rename_input(dispatch, model, entry)
        } else {
          strong(entry.display_name)
        },
      ]),
      span(kind_label(entry.kind)),
      span(optional_text(entry.modified_at, "unknown")),
      span(size_label(entry.size_bytes)),
    ],
  )
}

///|
fn desk_inline_rename_input(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
) -> @rabbita.Html {
  input(
    class="line-input inline-rename-input",
    attrs=@html.Attrs::build()
      .data_set("testid", "desk-inline-rename")
      .data_set("path", entry.path),
    value=model.desk_rename_name,
    placeholder=entry.display_name,
    on_input=fn(value) { dispatch(SetDeskRenameName(value)) },
  )
}

///|
fn desk_file_row_class(model : Model, entry : @desk.DeskFileEntry) -> String {
  let selected = desk_entry_is_selected(model, entry.path)
  let focused = entry.path == model.selected_path
  if selected && focused {
    "desk-file-row selected focused"
  } else if selected {
    "desk-file-row selected"
  } else {
    "desk-file-row"
  }
}

///|
fn desk_entry_is_selected(model : Model, path : String) -> Bool {
  if model.desk_selected_paths.length() == 0 {
    path == model.selected_path
  } else {
    model.desk_selected_paths.contains(path)
  }
}

///|
fn render_desk_breadcrumb(
  dispatch : Dispatch[Msg],
  directory : String,
) -> @rabbita.Html {
  div(
    class="desk-breadcrumb",
    desk_breadcrumbs(directory).map(crumb => {
      let (label, path, active) = crumb
      button(
        class=if active { "breadcrumb-chip active" } else { "breadcrumb-chip" },
        title=empty_root_path(path),
        on_click=dispatch(OpenDirectory(path)),
        label,
      )
    }),
  )
}

///|
fn desk_breadcrumbs(directory : String) -> Array[(String, String, Bool)] {
  let crumbs : Array[(String, String, Bool)] = [("root", "", directory == "")]
  if directory == "" {
    return crumbs
  }
  let mut current = ""
  for part in directory.split("/") {
    if part == "" {
      continue
    }
    current = if current == "" {
      part.to_owned()
    } else {
      current + "/" + part.to_owned()
    }
    crumbs.push((part.to_owned(), current, current == directory))
  }
  crumbs
}

///|
fn desk_folder_outline(
  directory : String,
  entries : Array[@desk.DeskFileEntry],
) -> Array[(String, String, Bool, Int)] {
  let items : Array[(String, String, Bool, Int)] = [
    ("root", "", directory == "", 0),
  ]
  if directory != "" {
    let mut current = ""
    let mut depth = 1
    for part in directory.split("/") {
      if part == "" {
        continue
      }
      current = if current == "" {
        part.to_owned()
      } else {
        current + "/" + part.to_owned()
      }
      items.push((part.to_owned(), current, current == directory, depth))
      depth += 1
    }
  }
  for entry in entries {
    if !(entry.kind is Directory) || entry.path == directory {
      continue
    }
    if parent_path(entry.path) == directory {
      items.push(
        (
          entry.display_name,
          entry.path,
          false,
          desk_outline_child_depth(directory),
        ),
      )
    }
  }
  items
}

///|
fn desk_outline_child_depth(directory : String) -> Int {
  if directory == "" {
    1
  } else {
    directory.split("/").filter(part => part != "").length() + 1
  }
}

///|
fn desk_folder_outline_row_class(active : Bool, depth : Int) -> String {
  let capped_depth = if depth > 4 { 4 } else { depth }
  if active {
    "desk-folder-row active depth-\{capped_depth}"
  } else {
    "desk-folder-row depth-\{capped_depth}"
  }
}

///|
fn render_desk_details(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(
    class="desk-details",
    attrs=@html.Attrs::build()
      .aria_label("Selection details")
      .data_set("testid", "desk-details"),
    [
      div(class="pane-heading", [
        div([p(class="eyebrow", "selection"), h2("Details")]),
      ]),
      if model.desk_selected_paths.length() > 1 {
        render_desk_multi_selection_details(dispatch, model)
      } else {
        match selected_desk_entry(model) {
          Some(entry) =>
            section(class="desk-detail-panel", [
              div(class="desk-detail-title", [
                span(class="tree-icon", icon_for_kind(entry.kind)),
                h3(entry.display_name),
              ]),
              info_row("Type", kind_label(entry.kind)),
              info_row(
                "Modified",
                optional_text(entry.modified_at, "Not available"),
              ),
              info_row("Size", size_label(entry.size_bytes)),
              info_row("Access", desk_access_label(Some(entry))),
              desk_disclosure(
                "desk-technical-details",
                "desk-selection-technical-details",
                "Technical details",
                [
                  info_row("Path", empty_root_path(entry.path)),
                  info_row("Source area", layer_label(entry.source_layer)),
                  info_row("Readable", yes_no(entry.readable)),
                  info_row("Writable", yes_no(entry.writable)),
                ],
              ),
              render_desk_inline_preview(dispatch, model),
              div(class="desk-detail-actions", [
                input(
                  class="line-input",
                  value=model.desk_rename_name,
                  placeholder=entry.display_name,
                  on_input=fn(value) { dispatch(SetDeskRenameName(value)) },
                ),
                button(
                  class="secondary-button full",
                  title="Rename selected item",
                  on_click=dispatch(RenameDeskSelection),
                  "Rename",
                ),
                render_desk_operation_status(
                  "status-line",
                  model.desk_rename_status,
                ),
                button(
                  class="secondary-button full",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "desk-reveal-selection",
                  ),
                  title="Reveal selected item in the system file manager",
                  on_click=dispatch(RevealSelection),
                  "Reveal in File Manager",
                ),
                if entry.kind is Html {
                  @html.nothing
                } else {
                  button(
                    class="secondary-button full",
                    on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
                    "Open in Wiki",
                  )
                },
                render_desk_single_selection_more_actions(
                  dispatch, model, entry,
                ),
              ]),
            ])
          None =>
            if desk_workspace_action_disabled(model) {
              section(class="desk-detail-panel desk-detail-panel-empty", [
                div(class="desk-detail-title", [
                  span(class="tree-icon", "D"),
                  h3("No MoonBook selected"),
                ]),
              ])
            } else {
              section(class="desk-detail-panel", [
                div(class="desk-detail-title", [
                  span(class="tree-icon", "D"),
                  h3(workspace_name(model)),
                ]),
                info_row("Folder", empty_root_path(model.current_directory)),
                info_row("Items", model.entries.length().to_string()),
                desk_disclosure(
                  "desk-technical-details",
                  "desk-folder-technical-details",
                  "Technical details",
                  [
                    info_row("MoonBook", workspace_name(model)),
                    info_row("Storage path", workspace_root(model)),
                  ],
                ),
                div(class="desk-detail-actions", [
                  button(
                    class="secondary-button full",
                    attrs=@html.Attrs::build().data_set(
                      "testid", "desk-reveal-current-directory",
                    ),
                    title="Reveal current folder in the system file manager",
                    on_click=dispatch(RevealSelection),
                    "Reveal Folder",
                  ),
                  render_desk_folder_more_actions(dispatch, model),
                ]),
              ])
            }
        }
      },
    ],
  )
}

///|
fn render_desk_folder_more_actions(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  desk_disclosure(
    "desk-more-actions",
    "desk-folder-more-actions",
    "More actions",
    [
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-paste-clipboard"),
        title="Paste copied items here",
        on_click=dispatch(PasteDeskClipboard),
        "Paste Here",
      ),
      p(class="status-line", model.desk_clipboard_status),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-path"),
        title="Copy folder path",
        on_click=dispatch(CopyDeskPath),
        "Copy Folder Path",
      ),
      p(class="status-line", model.desk_path_status),
      button(
        class="secondary-button full",
        title="Restore the most recently trashed item",
        on_click=dispatch(RestoreLastTrashedDeskEntry),
        "Restore Last",
      ),
      p(class="status-line", model.desk_trash_status),
      render_desk_trash_panel(dispatch, model),
    ],
  )
}

///|
fn render_desk_single_selection_more_actions(
  dispatch : Dispatch[Msg],
  model : Model,
  entry : @desk.DeskFileEntry,
) -> @rabbita.Html {
  desk_disclosure(
    "desk-more-actions",
    "desk-selection-more-actions",
    "More actions",
    [
      input(
        class="line-input",
        value=model.desk_move_target_directory,
        placeholder="Move to folder",
        on_input=fn(value) { dispatch(SetDeskMoveTargetDirectory(value)) },
      ),
      button(
        class="secondary-button full",
        title="Move selected item",
        on_click=dispatch(MoveDeskSelection),
        "Move",
      ),
      p(class="status-line", model.desk_move_status),
      button(
        class="secondary-button full",
        title="Duplicate selected item",
        on_click=dispatch(DuplicateDeskSelection),
        "Duplicate",
      ),
      p(class="status-line", model.desk_copy_status),
      div(class="desk-disclosure-actions", [
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-copy-selection"),
          title="Copy selected item",
          on_click=dispatch(CopyDeskSelection),
          "Copy",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-cut-selection"),
          title="Cut selected item",
          on_click=dispatch(CutDeskSelection),
          "Cut",
        ),
        button(
          class="secondary-button compact-button",
          attrs=@html.Attrs::build().data_set("testid", "desk-paste-clipboard"),
          title="Paste into this folder",
          disabled=desk_workspace_action_disabled(model),
          on_click=dispatch(PasteDeskClipboard),
          "Paste",
        ),
      ]),
      p(class="status-line", model.desk_clipboard_status),
      button(
        class=desk_favorite_button_class(model, entry.path),
        attrs=@html.Attrs::build().data_set("testid", "desk-toggle-favorite"),
        title="Add or remove from Quick Access",
        on_click=dispatch(ToggleFavorite(entry.path)),
        desk_favorite_button_label(model, entry.path),
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-path"),
        title="Copy path",
        on_click=dispatch(CopyDeskPath),
        "Copy Path",
      ),
      p(class="status-line", model.desk_path_status),
      button(
        class="secondary-button full",
        title="Move selected item to Trash",
        on_click=dispatch(TrashDeskSelection),
        "Move to Trash",
      ),
      button(
        class="secondary-button full",
        title="Restore the most recently trashed item",
        on_click=dispatch(RestoreLastTrashedDeskEntry),
        "Restore Last",
      ),
      p(class="status-line", model.desk_trash_status),
      render_desk_trash_panel(dispatch, model),
      button(
        class="secondary-button full",
        on_click=dispatch(SelectWorkspaceMode(MoonCode)),
        "Ask Code",
      ),
      button(
        class="secondary-button full",
        on_click=dispatch(ClearDeskSelection),
        "Clear Selection",
      ),
    ],
  )
}

///|
fn render_desk_inline_preview(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="desk-inline-preview",
    attrs=@html.Attrs::build().data_set("testid", "desk-preview"),
    match model.preview {
      Some(preview) =>
        [
          match model.preview_state {
            Some(state) => render_preview_state_panel(dispatch, model, state)
            None => @html.nothing
          },
        ] +
        (match preview.renderer {
          Markdown
          | Text
          | Json
          | DirectoryListing
          | Unsupported
          | ArtifactSummary =>
            [
              strong(preview.title),
              pre(class="source-block compact", code(preview.body)),
            ]
          Image =>
            [strong(preview.title), img(src=preview.body, alt=preview.title)]
          Html =>
            [
              strong(preview.title),
              p(
                class="status-line",
                "Run this executable artifact in MoonDesk's isolated preview.",
              ),
              button(
                class="primary-button full",
                attrs=@html.Attrs::build().data_set(
                  "testid", "desk-open-embedded-preview",
                ),
                on_click=dispatch(SelectWorkspaceMode(MoonWiki)),
                "Preview / Run here",
              ),
            ]
        })
      None =>
        [
          match model.preview_state {
            Some(state) => render_preview_state_panel(dispatch, model, state)
            None => render_preview_state_panel(dispatch, model, FirstUseEmpty)
          },
        ]
    },
  )
}

///|
fn render_desk_multi_selection_details(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="desk-detail-panel", [
    div(class="desk-detail-title", [
      span(class="tree-icon", "*"),
      h3("\{model.desk_selected_paths.length()} items selected"),
    ]),
    info_row("Selection", desk_multi_selection_count_label(model)),
    info_row("Total Size", desk_multi_selection_size_label(model)),
    desk_disclosure(
      "desk-technical-details",
      "desk-multi-selection-technical-details",
      "Selection details",
      [
        info_row("Focused", empty_root_path(model.selected_path)),
        info_row("Folder", empty_root_path(model.current_directory)),
        info_row("Items", desk_selected_paths_summary(model)),
      ],
    ),
    div(class="desk-detail-actions", [
      input(
        class="line-input",
        value=model.desk_move_target_directory,
        placeholder="Target directory",
        on_input=fn(value) { dispatch(SetDeskMoveTargetDirectory(value)) },
      ),
      button(
        class="secondary-button full",
        title="Move selected items to target directory",
        on_click=dispatch(MoveDeskSelection),
        "Move",
      ),
      p(class="status-line", model.desk_move_status),
      button(
        class="secondary-button full",
        title="Duplicate selected items in their current directories",
        on_click=dispatch(DuplicateDeskSelection),
        "Duplicate",
      ),
      p(class="status-line", model.desk_copy_status),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-selection"),
        title="Copy selected items to the Desk clipboard",
        on_click=dispatch(CopyDeskSelection),
        "Copy",
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-cut-selection"),
        title="Cut selected items to move them with Paste Here",
        on_click=dispatch(CutDeskSelection),
        "Cut",
      ),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-paste-clipboard"),
        title="Paste copied items into the current directory",
        on_click=dispatch(PasteDeskClipboard),
        "Paste Here",
      ),
      p(class="status-line", model.desk_clipboard_status),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-copy-path"),
        title="Copy selected virtual paths",
        on_click=dispatch(CopyDeskPath),
        "Copy Paths",
      ),
      p(class="status-line", model.desk_path_status),
      button(
        class="secondary-button full",
        title="Move selected items to scoped MoonBook trash",
        on_click=dispatch(TrashDeskSelection),
        "Move to Trash",
      ),
      button(
        class="secondary-button full",
        title="Restore the most recently trashed item",
        on_click=dispatch(RestoreLastTrashedDeskEntry),
        "Restore Last",
      ),
      p(class="status-line", model.desk_trash_status),
      render_desk_trash_panel(dispatch, model),
      button(
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("testid", "desk-reveal-selection"),
        on_click=dispatch(RevealSelection),
        "Reveal Focused",
      ),
      button(
        class="secondary-button full",
        on_click=dispatch(ClearDeskSelection),
        "Clear Selection",
      ),
    ]),
  ])
}

///|
fn desk_favorite_button_class(model : Model, path : String) -> String {
  if has_string(model.favorites, path) {
    "secondary-button full active"
  } else {
    "secondary-button full"
  }
}

///|
fn desk_favorite_button_label(model : Model, path : String) -> String {
  if has_string(model.favorites, path) {
    "Remove Favorite"
  } else {
    "Add Favorite"
  }
}

///|
fn desk_multi_selection_count_label(model : Model) -> String {
  let entries = desk_selected_entries(model)
  if entries.length() == 0 {
    "\{model.desk_selected_paths.length()} selected"
  } else {
    desk_entry_count_label(desk_entry_counts(entries))
  }
}

///|
fn desk_multi_selection_size_label(model : Model) -> String {
  let entries = desk_selected_entries(model)
  let mut known = 0
  let mut total = 0
  for entry in entries {
    match entry.size_bytes {
      Some(bytes) => {
        known += 1
        total += bytes
      }
      None => ()
    }
  }
  if known == 0 {
    "-"
  } else if known == entries.length() {
    size_label(Some(total))
  } else {
    size_label(Some(total)) + " known"
  }
}

///|
fn desk_selected_entries(model : Model) -> Array[@desk.DeskFileEntry] {
  let entries : Array[@desk.DeskFileEntry] = []
  for path in model.desk_selected_paths {
    match find_entry(model, path) {
      Some(entry) => entries.push(entry)
      None => ()
    }
  }
  entries
}

///|
fn render_desk_trash_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(
    class="desk-trash-panel",
    attrs=@html.Attrs::build().data_set("testid", "desk-trash-panel"),
    [
      strong("Trash"),
      if model.desk_trash_entries.length() == 0 {
        p(class="status-line", "Trash is empty")
      } else {
        div(
          class="desk-trash-list",
          model.desk_trash_entries.map(entry => {
            button(
              class="desk-trash-row",
              attrs=@html.Attrs::build()
                .data_set("testid", "desk-trash-row")
                .data_set("workspace-id", entry.workspace_id)
                .data_set("trash-path", entry.trash_path)
                .data_set("receipt-path", entry.receipt_path)
                .data_set("original-path", entry.original_path),
              title="Restore " + entry.original_path,
              on_click=dispatch(RestoreDeskTrashEntry(entry.trash_path)),
              [span(entry.original_path), small(entry.trashed_at)],
            )
          }),
        )
      },
    ],
  )
}

///|
fn desk_selected_paths_summary(model : Model) -> String {
  let limit = if model.desk_selected_paths.length() < 4 {
    model.desk_selected_paths.length()
  } else {
    4
  }
  let parts : Array[String] = []
  for index in 0..<limit {
    parts.push(empty_root_path(model.desk_selected_paths[index]))
  }
  if model.desk_selected_paths.length() > limit {
    parts.push("+\{model.desk_selected_paths.length() - limit} more")
  }
  parts.join(", ")
}

///|
fn selected_desk_entry(model : Model) -> @desk.DeskFileEntry? {
  find_entry(model, model.selected_path)
}

///|
fn desk_entry_counts(entries : Array[@desk.DeskFileEntry]) -> (Int, Int, Int) {
  let mut directories = 0
  let mut files = 0
  for entry in entries {
    if entry.kind is Directory {
      directories += 1
    } else {
      files += 1
    }
  }
  (entries.length(), directories, files)
}

///|
fn desk_entry_count_label(counts : (Int, Int, Int)) -> String {
  let (total, directories, files) = counts
  "\{count_noun(total, "item")}, \{count_noun(directories, "folder")}, \{count_noun(files, "file")}"
}

///|
fn count_noun(count : Int, noun : String) -> String {
  if count == 1 {
    "\{count} \{noun}"
  } else {
    "\{count} \{noun}s"
  }
}

///|
fn desk_entry_count_label_for_model(
  model : Model,
  counts : (Int, Int, Int),
  visible_count : Int,
) -> String {
  match model.desk_entries_state {
    Some(FirstUseEmpty) => "No MoonBook selected"
    Some(Loading) =>
      if model.entries.is_empty() {
        "Loading items"
      } else {
        "Refreshing \{count_noun(model.entries.length(), "item")}"
      }
    Some(Stale) =>
      if model.entries.is_empty() {
        "Item count unavailable"
      } else {
        "\{count_noun(model.entries.length(), "retained item")}"
      }
    Some(Disconnected)
    | Some(CapabilityLimited)
    | Some(RecoverableError)
    | Some(TerminalError) => "Item count unavailable"
    Some(LegitimateZero) => desk_entry_count_label(counts)
    None =>
      if model.desk_filter_query.trim().to_owned() == "" {
        desk_entry_count_label(counts)
      } else {
        "\{visible_count} of \{model.entries.length()} shown"
      }
  }
}

///|
fn desk_selection_label(model : Model) -> String {
  if model.desk_selected_paths.length() > 1 {
    "\{model.desk_selected_paths.length()} selected"
  } else if model.selected_path == "" {
    "No selection"
  } else {
    "Selected " + empty_root_path(model.selected_path)
  }
}

///|
fn desk_access_label(entry : @desk.DeskFileEntry?) -> String {
  match entry {
    Some(entry) if entry.writable => "Writable"
    Some(_) => "Read-only"
    None => "Browse only"
  }
}

///|
fn desk_directory_title(path : String) -> String {
  if path == "" {
    "MoonBook Root"
  } else {
    path
  }
}

///|
fn parent_path(path : String) -> String {
  match path.rev_split_once("/") {
    Some((parent, _)) => parent.to_owned()
    None => ""
  }
}

///|
fn empty_root_path(path : String) -> String {
  if path == "" {
    "/"
  } else {
    path
  }
}

///|
fn optional_text(value : String?, fallback : String) -> String {
  match value {
    Some(text) if text != "" => text
    _ => fallback
  }
}

///|
fn size_label(value : Int?) -> String {
  match value {
    Some(size) if size >= 1024 * 1024 => "\{size / (1024 * 1024)} MB"
    Some(size) if size >= 1024 => "\{size / 1024} KB"
    Some(size) => "\{size} B"
    None => "-"
  }
}

///|
fn yes_no(value : Bool) -> String {
  if value {
    "yes"
  } else {
    "no"
  }
}

///|
fn kind_label(kind : @desk.EntryKind) -> String {
  match kind {
    Directory => "folder"
    Markdown => "markdown"
    Html => "html"
    Json => "json"
    Image => "image"
    Artifact => "artifact"
    Text => "text"
    Unknown => "unknown"
  }
}
