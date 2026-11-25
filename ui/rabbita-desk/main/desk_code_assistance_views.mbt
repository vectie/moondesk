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
      button(
        type_="button",
        class="secondary-button full",
        attrs=@html.Attrs::build().data_set("provider-connection-import", ""),
        "Scan connection QR",
      ),
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
      a(
        class="primary-button full link-button",
        href="http://127.0.0.1:15721/ui/rabbita#bindings",
        target=Blank,
        rel="noopener noreferrer",
        attrs=@html.Attrs::build()
          .data_set("testid", "moonclaw-open-moongate")
          .data_set("i18n", "code.assistance_action_connect"),
        "Open MoonGate",
      ),
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
      ),
      details(
        class="technical-details",
        open=authorization_started || setup_ready_to_check,
        attrs=@html.Attrs::build().data_set(
          "testid", "moonclaw-direct-provider-setup",
        ),
        [
          summary(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.direct_provider_setup",
            ),
            "Direct provider sign-in (advanced)",
          ),
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
                  button(
                    class="secondary-button full",
                    attrs=@html.Attrs::build().data_set(
                      "testid", "moonclaw-connect-codex",
                    ),
                    disabled=busy,
                    on_click=dispatch(StartMoonClawAuth("codex")),
                    if model.moonclaw_auth_pending == "codex" {
                      "Starting Codex setup…"
                    } else {
                      "Connect Codex"
                    },
                  )
              }
          },
          if authorization_started {
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
                auto_complete="off",
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
