///|
fn render_source_editor(
  dispatch : Dispatch[Msg],
  source : SourcePaneState,
) -> @rabbita.Html {
  section(
    class="source-editor",
    attrs=@html.Attrs::build()
      .aria_label("Source editor")
      .data_set("testid", "source-editor")
      .data_set("search-engine", "moonedit")
      .data_set("workspace-id", source.workspace_id)
      .data_set("source-path", source.requested_path)
      .data_set(
        "source-dirty",
        if source_pane_dirty(source) {
          "true"
        } else {
          "false"
        },
      ),
    [
      if source.buffers.is_empty() {
        @html.nothing
      } else {
        div(
          class="source-editor-tabs",
          attrs=@html.Attrs::build()
            .role("tablist")
            .aria_label("Open source files")
            .data_set("i18n-aria-label", "code.open_source_files")
            .aria_orientation("horizontal")
            .data_set("testid", "source-tabs"),
          source.buffers.map(buffer => {
            let active = buffer.path == source.requested_path
            div(
              class=if active {
                "source-editor-tab is-active"
              } else {
                "source-editor-tab"
              },
              attrs=@html.Attrs::build().role("presentation"),
              [
                button(
                  class="source-editor-tab-select",
                  attrs=@html.Attrs::build()
                    .role("tab")
                    .aria_selected(if active { "true" } else { "false" })
                    .aria_controls("source-buffer-panel")
                    .tabindex(if active { 0 } else { -1 })
                    .title(buffer.path)
                    .aria_label(buffer.path)
                    .data_set("i18n-preserve", "aria-label title")
                    .data_set("testid", "source-tab-" + buffer.path),
                  on_click=dispatch(SourcePane(SwitchBuffer(buffer.path))),
                  disabled=source.saving,
                  [
                    span(
                      class="source-editor-tab-path",
                      attrs=@html.Attrs::build().data_set(
                        "i18n-scope", "content",
                      ),
                      buffer.path,
                    ),
                    if source_pane_buffer_dirty(buffer) {
                      span(
                        class="source-editor-tab-modified",
                        interface_label("desk.modified", "Modified"),
                      )
                    } else {
                      @html.nothing
                    },
                  ],
                ),
                button(
                  class="source-editor-tab-close",
                  attrs=@html.Attrs::build()
                    .aria_label("Close source file")
                    .data_set("i18n-aria-label", "code.close_source_file")
                    .title(buffer.path)
                    .data_set("i18n-preserve", "title")
                    .data_set("testid", "source-tab-close-" + buffer.path),
                  on_click=dispatch(SourcePane(CloseBuffer(buffer.path))),
                  disabled=source.saving,
                  ui_icon("close"),
                ),
              ],
            )
          }),
        )
      },
      div(class="source-editor-toolbar", [
        render_source_json_table_action(source),
        @html.label(class="editor-path-field", [
          span("Source path"),
          input(
            attrs=@html.Attrs::build()
              .data_set("testid", "source-path")
              .aria_label("Workspace source path"),
            value=source.path_input,
            placeholder="src/main.mbt",
            on_input=fn(value) { dispatch(SourcePane(SetPathInput(value))) },
          ),
        ]),
        button(
          class="secondary-button",
          attrs=@html.Attrs::build()
            .data_set("testid", "source-open")
            .on_click(_ => {
              dispatch(SourcePane(RequestSource(browser_source_path_value())))
            }),
          disabled=source.path_input.trim() == "" ||
            source.content is Loading ||
            source.saving,
          "Open",
        ),
        button(
          class="primary-button source-save-button",
          attrs=@html.Attrs::build().data_set("testid", "source-save"),
          disabled=!source_pane_dirty(source) || source.saving,
          on_click=dispatch(SourcePane(Save)),
          [
            ui_icon(if source.saving { "running" } else { "save" }),
            span(if source.saving { "Saving..." } else { "Save" }),
          ],
        ),
        details(
          class="source-file-actions",
          attrs=@html.Attrs::build().data_set("popup", "source-actions"),
          [
            summary(
              class="moon-icon-button",
              attrs=@html.Attrs::build()
                .aria_label("File actions")
                .data_set("i18n-aria-label", "code.file_actions")
                .title("File actions"),
              ui_icon("more"),
            ),
            div(class="source-file-action-menu", [
              button(
                class="secondary-button",
                attrs=@html.Attrs::build().data_set("testid", "source-discard"),
                disabled=!source_pane_dirty(source) || source.saving,
                on_click=dispatch(SourcePane(DiscardDraft)),
                "Discard",
              ),
              button(
                class="secondary-button",
                attrs=@html.Attrs::build().data_set("testid", "source-reload"),
                disabled=source.server_content is None || source.saving,
                on_click=dispatch(SourcePane(ReloadServer)),
                "Reload external version",
              ),
            ]),
          ],
        ),
      ]),
      div(class="source-quiet-tools", [
        details(
          class="source-quiet-disclosure source-find-disclosure",
          attrs=@html.Attrs::build().data_set(
            "testid", "source-find-disclosure",
          ),
          [
            summary(
              attrs=@html.Attrs::build().title("Find and replace · Ctrl/Cmd+F"),
              [ui_icon("search"), span("Find and replace")],
            ),
            div(class="source-quiet-disclosure-body", [
              render_source_literal_search(dispatch, source),
            ]),
          ],
        ),
        details(class="source-quiet-disclosure source-edit-tools", [
          summary([ui_icon("edit"), span("Edit tools")]),
          div(class="source-quiet-disclosure-body", [
            render_source_line_authoring(dispatch, source),
            render_source_json_layout(dispatch, source),
            render_source_table_import(dispatch, source),
            render_source_outline(dispatch, source),
          ]),
        ]),
      ]),
      div(class="source-editor-workbench", [
        pre(
          class="source-editor-line-numbers",
          attrs=@html.Attrs::build()
            .data_set("testid", "source-line-numbers")
            .aria_hidden("true"),
          source_pane_line_numbers(source),
        ),
        pre(
          class="source-editor-highlight",
          attrs=@html.Attrs::build()
            .data_set("testid", "source-highlight")
            .aria_hidden("true"),
          code(""),
        ),
        textarea(
          class="source-editor-input",
          attrs=@html.Attrs::build()
            .data_set("testid", "source-editor-input")
            .aria_label("Source editor")
            .wrap("off")
            .spellcheck(false)
            .autocapitalize("off")
            .on_keydown(keyboard => {
              if !source_pane_editable(source) {
                return @rabbita.none
              }
              match
                source_line_shortcut(
                  keyboard.key(),
                  keyboard.ctrl_key() || keyboard.meta_key(),
                  keyboard.shift_key(),
                  keyboard.alt_key(),
                  keyboard.is_composing(),
                ) {
                Some(action) => {
                  @dom.IsEvent::prevent_default(keyboard)
                  @dom.IsEvent::stop_propagation(keyboard)
                  dispatch(SourcePane(action))
                }
                None => @rabbita.none
              }
            })
            .disabled(!source_pane_editable(source)),
          rows=12,
          value=source.draft,
          placeholder=match source.content {
            Empty => "Open a workspace source file to begin editing."
            Loading => "Loading source..."
            Unsupported(reason) | Failed(reason) => reason
            Ready(_) => ""
          },
          on_input=fn(value) { dispatch(SourcePane(EditDraft(value))) },
          "",
        ),
      ]),
      div(
        class="source-editor-assist",
        attrs=@html.Attrs::build().data_set("testid", "source-assist"),
        [
          div(class="source-semantic-toolbar", [
            button(
              class="secondary-button",
              attrs=@html.Attrs::build()
                .data_set("action", "source-compiler-check")
                .data_set("testid", "source-compiler-check"),
              disabled=!source_pane_editable(source) ||
                source_pane_dirty(source) ||
                source_pane_language_label(source) != "MoonBit",
              "Check workspace",
            ),
            button(
              class="secondary-button",
              attrs=@html.Attrs::build()
                .data_set("action", "source-go-definition")
                .data_set("testid", "source-go-definition"),
              disabled=!source_pane_editable(source) ||
                source_pane_dirty(source) ||
                source_pane_language_label(source) != "MoonBit",
              "Go to definition",
            ),
            button(
              class="secondary-button",
              attrs=@html.Attrs::build()
                .data_set("action", "source-find-references")
                .data_set("testid", "source-find-references"),
              disabled=!source_pane_editable(source) ||
                source_pane_dirty(source) ||
                source_pane_language_label(source) != "MoonBit",
              "Find references",
            ),
          ]),
          div(
            class="source-completions",
            attrs=@html.Attrs::build()
              .data_set("testid", "source-completions")
              .role("listbox")
              .aria_label("Local source completions"),
            [@html.nothing],
          ),
          p(
            class="source-local-diagnostics",
            attrs=@html.Attrs::build()
              .data_set("testid", "source-local-diagnostics")
              .role("status")
              .aria_live("polite"),
            "Local diagnostics ready",
          ),
          div(
            class="source-semantic-results",
            attrs=@html.Attrs::build()
              .data_set("testid", "source-semantic-results")
              .aria_live("polite"),
            [@html.nothing],
          ),
        ],
      ),
      div(class="source-editor-meta", [
        span(
          if source.requested_path == "" {
            "No file open"
          } else {
            source.requested_path
          },
        ),
        if source.content is Ready(_) {
          span(if source_pane_dirty(source) { "Modified" } else { "Saved" })
        } else {
          @html.nothing
        },
        span(
          attrs=@html.Attrs::build().data_set("testid", "source-language"),
          source_pane_language_label(source),
        ),
        span(
          attrs=@html.Attrs::build().data_set(
            "testid", "source-cursor-position",
          ),
          "Ln 1, Col 1",
        ),
        span("UTF-8 · LF"),
      ]),
      p(
        class="source-editor-status",
        attrs=@html.Attrs::build()
          .role("status")
          .aria_live("polite")
          .data_set("testid", "source-status"),
        source.status,
      ),
      if source_pane_dirty(source) {
        details(class="source-editor-diff", [
          summary("Diff and diagnostics"),
          pre(
            "Saved baseline:\n" +
            source.baseline +
            "\n\nDraft:\n" +
            source.draft,
          ),
          if source.server_content is Some(current) {
            div([
              pre("External version:\n" + current),
              button(
                class="secondary-button",
                disabled=source.saving,
                on_click=dispatch(SourcePane(ReloadServer)),
                "Reload external",
              ),
              button(
                class="primary-button",
                disabled=source.saving,
                on_click=dispatch(SourcePane(ReplaceServer)),
                "Replace external",
              ),
            ])
          } else {
            @html.nothing
          },
        ])
      } else {
        @html.nothing
      },
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
  if moonclaw_capability_state(model.moonclaw_daemon) is DetectedRunning &&
    (
      model.mooncode_capability is CapabilityPending ||
      mooncode_capability_available(model.mooncode_capability)
    ) {
    "preview-center mooncode-center"
  } else {
    "preview-center mooncode-center runtime-setup-visible"
  }
}

///|
fn render_mooncode_runtime_setup(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let explicit_capability_failure = match model.mooncode_capability {
    CapabilityUnsupportedVersion(_) | CapabilityMalformed(_) => true
    CapabilityUnavailable(_) =>
      moonclaw_capability_state(model.moonclaw_daemon) is DetectedRunning
    CapabilityPending | CapabilitySupported(_) => false
  }
  if explicit_capability_failure {
    let title = mooncode_capability_title(model.mooncode_capability)
    return section(
      class="mooncode-runtime-setup",
      attrs=@html.Attrs::build()
        .data_set("testid", "mooncode-runtime-setup")
        .data_set(
          "state",
          mooncode_capability_state_key(model.mooncode_capability),
        )
        .role("status")
        .aria_live("polite"),
      [
        h3(
          attrs=@html.Attrs::build().data_set(
            "i18n",
            mooncode_capability_title_i18n_key(model.mooncode_capability),
          ),
          title,
        ),
        match model.mooncode_capability {
          CapabilityUnsupportedVersion(_) =>
            p(
              attrs=@html.Attrs::build().data_set("i18n", "code.runtime_update"),
              "Update MoonDesk or MoonClaw so their capability contracts are compatible.",
            )
          CapabilityMalformed(_) =>
            button(
              class="primary-button compact-button",
              attrs=@html.Attrs::build()
                .data_set("testid", "mooncode-capability-refetch")
                .data_set("i18n", "code.runtime_refetch"),
              on_click=dispatch(RefreshMoonCodeCapability),
              "Refetch capability",
            )
          CapabilityUnavailable(_) =>
            button(
              class="primary-button compact-button",
              attrs=@html.Attrs::build()
                .data_set("testid", "mooncode-capability-retry-daemon")
                .data_set("i18n", "code.runtime_retry"),
              on_click=dispatch(ManageMoonClaw("retry")),
              "Retry Code runtime",
            )
          CapabilityPending | CapabilitySupported(_) => @html.nothing
        },
      ],
    )
  }
  let state = moonclaw_capability_state(model.moonclaw_daemon)
  if !(state is DetectedRunning) &&
    model.moonclaw_startup_probes > 0 &&
    model.moonclaw_startup_probes < 6 &&
    model.moonclaw_operation == "" &&
    !model.moonclaw_installing {
    return section(
      class="mooncode-runtime-setup is-startup-connecting",
      attrs=@html.Attrs::build()
        .data_set("testid", "mooncode-runtime-setup")
        .data_set("state", "connecting")
        .role("status")
        .aria_live("polite"),
      [
        div(class="code-capability-summary", [
          strong(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.assistance_connecting",
            ),
            "Connecting…",
          ),
        ]),
      ],
    )
  }
  match state {
    DetectedRunning => @html.nothing
    _ => {
      let action = code_capability_primary_action(state)
      section(
        class="mooncode-runtime-setup",
        attrs=@html.Attrs::build()
          .data_set("testid", "mooncode-runtime-setup")
          .data_set("state", capability_state_key(state))
          .role("status")
          .aria_live("polite"),
        [
          render_code_capability_summary(state),
          match action {
            StartCapability =>
              button(
                class="primary-button compact-button",
                attrs=@html.Attrs::build()
                  .data_set("testid", "mooncode-start-moonclaw")
                  .data_set(
                    "i18n",
                    code_capability_primary_action_i18n_key(action),
                  ),
                on_click=dispatch(ManageMoonClaw("retry")),
                code_capability_primary_action_label(action),
              )
            InstallCapability =>
              div(class="mooncode-runtime-install", [
                button(
                  class="primary-button compact-button",
                  attrs=@html.Attrs::build()
                    .data_set("testid", "mooncode-install-moonclaw")
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
            ConfigureCapability =>
              render_moonclaw_first_run_setup(dispatch, model)
            OpenConfiguration =>
              button(
                class="primary-button compact-button",
                attrs=@html.Attrs::build().data_set(
                  "i18n",
                  code_capability_primary_action_i18n_key(action),
                ),
                on_click=dispatch(SelectActivity(Settings)),
                code_capability_primary_action_label(action),
              )
            RetryCapabilityCheck =>
              button(
                class="primary-button compact-button",
                attrs=@html.Attrs::build().data_set(
                  "i18n",
                  code_capability_primary_action_i18n_key(action),
                ),
                on_click=dispatch(ManageMoonClaw("retry")),
                code_capability_primary_action_label(action),
              )
            NoPrimaryAction => @html.nothing
          },
          render_code_assistance_operation_alert(model),
          render_code_assistance_technical_details(model),
        ],
      )
    }
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
    Some(active) if mooncode_can_guide_running_work(active) => "Queue next turn"
    Some(_) => "Prompt"
    None => "Start"
  }
}

///|
fn mooncode_can_guide_running_work(session : MoonCodeSession) -> Bool {
  session.status == "running" &&
  mooncode_conversation_has_unfinished_turn(session)
}

///|
fn mooncode_sessions_state_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  match model.mooncode_sessions_state {
    None => @html.nothing
    Some(state) =>
      section(
        class="surface-state-panel mooncode-sessions-state-panel",
        attrs=@html.Attrs::build()
          .data_set("testid", "mooncode-sessions-state-panel")
          .data_set("state", mooncode_sessions_state_key(state)),
        [
          p(
            class="eyebrow",
            attrs=@html.Attrs::build().data_set("i18n", "code.chat_history"),
            "Chat history",
          ),
          render_polite_state_announcement(
            "mooncode-sessions-state-announcement",
            mooncode_sessions_state_title(state),
            mooncode_sessions_state_detail(
              state,
              model.mooncode_sessions.length() > 0,
            ),
            title_i18n_key=mooncode_sessions_state_title_i18n_key(state),
            detail_i18n_key=mooncode_sessions_state_detail_i18n_key(
              state,
              model.mooncode_sessions.length() > 0,
            ),
          ),
          if mooncode_sessions_state_shows_details(state) &&
            model.mooncode_sessions_error != "" {
            details(class="technical-details", [
              summary(
                attrs=@html.Attrs::build().data_set(
                  "i18n", "common.technical_details",
                ),
                "Technical details",
              ),
              p(model.mooncode_sessions_error),
            ])
          } else {
            @html.nothing
          },
          match mooncode_sessions_state_action(state) {
            Some(label) =>
              button(
                attrs=@html.Attrs::build().data_set(
                  "testid", "mooncode-sessions-state-action",
                ),
                on_click=dispatch(SelectWorkspaceMode(MoonCode)),
                label,
              )
            None => @html.nothing
          },
        ],
      )
  }
}
