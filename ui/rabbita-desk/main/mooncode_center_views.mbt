///|
fn render_mooncode_center(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if work_handoff_active(model) {
    return render_work_handoff(dispatch, model)
  }
  let session = selected_mooncode_session(model)
  let empty = session is None
  let setup_open = model.mooncode_skills_visible &&
    model.mooncode_skills_workspace_id == model.selected_workspace_id
  let setup_label = if setup_open { "Close setup" } else { "Coding setup" }
  let setup_key = if setup_open {
    "code.hide_skills"
  } else {
    "code.view_skills"
  }
  let schedules_open = model.mooncode_schedules_visible &&
    model.mooncode_schedules_workspace_id == model.selected_workspace_id
  let schedules_label = if schedules_open {
    "Hide schedules"
  } else {
    "Scheduled work"
  }
  let schedules_key = if schedules_open {
    "code.hide_schedules"
  } else {
    "code.schedules_title"
  }
  let send_key = if session is Some(active) &&
    mooncode_can_guide_running_work(active) {
    "code.queue_next_turn"
  } else if session is Some(_) {
    "code.prompt"
  } else {
    "common.start"
  }
  section(
    class=mooncode_center_class(model),
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-center")
      .data_set("workspace-id", model.selected_workspace_id)
      .data_set("session-id", model.selected_mooncode_session_id),
    [
      div(class="code-workbench-heading", [
        div(class="mooncode-context-bar", [
          button(
            class="moon-icon-button code-navigation-toggle",
            attrs=@html.Attrs::build()
              .data_set("workbench-action", "navigation")
              .data_set("i18n-title", "code.toggle_chats")
              .data_set("i18n-aria-label", "code.toggle_chats")
              .aria_label("Toggle chats sidebar")
              .title("Toggle chats sidebar")
              .aria_expanded("true")
              .aria_controls("code-chat-navigation"),
            ui_icon("panel-left"),
          ),
          div([
            strong(
              attrs=@html.Attrs::build().data_set(
                "i18n-scope",
                if session is Some(_) {
                  "content"
                } else {
                  "interface"
                },
              ),
              mooncode_context_title(model, session),
            ),
            if (session is None && model.selected_path == "") ||
              mooncode_context_path_label(model, session) ==
              workspace_name(model) {
              @html.nothing
            } else {
              span(
                attrs=@html.Attrs::build().data_set("i18n-scope", "content"),
                mooncode_context_path_label(model, session),
              )
            },
          ]),
          if model.selected_workspace_id == "" {
            @html.nothing
          } else {
            button(
              class="mooncode-skill-toggle mooncode-composer-icon-button moon-icon-button",
              attrs=@html.Attrs::build()
                .data_set("i18n-title", setup_key)
                .data_set("i18n-aria-label", setup_key)
                .title(setup_label)
                .aria_label(setup_label)
                .aria_expanded(
                  if model.mooncode_skills_visible &&
                    model.mooncode_skills_workspace_id ==
                    model.selected_workspace_id {
                    "true"
                  } else {
                    "false"
                  },
                ),
              on_click=dispatch(ToggleMoonCodeSkills),
              ui_icon("settings"),
            )
          },
          if model.selected_workspace_id == "" {
            @html.nothing
          } else {
            button(
              class="mooncode-skill-toggle mooncode-schedules-toggle mooncode-composer-icon-button moon-icon-button",
              attrs=@html.Attrs::build()
                .data_set("i18n-title", schedules_key)
                .data_set("i18n-aria-label", schedules_key)
                .title(schedules_label)
                .aria_label(schedules_label)
                .aria_expanded(
                  if model.mooncode_schedules_visible &&
                    model.mooncode_schedules_workspace_id ==
                    model.selected_workspace_id {
                    "true"
                  } else {
                    "false"
                  },
                ),
              on_click=dispatch(ToggleMoonCodeSchedules),
              ui_icon("calendar"),
            )
          },
          if model.selected_mooncode_session_id == "" {
            @html.nothing
          } else {
            button(
              class="mooncode-skill-toggle mooncode-jobs-toggle moon-icon-button",
              attrs=@html.Attrs::build()
                .data_set(
                  "i18n-aria-label",
                  if model.mooncode_jobs_visible &&
                    model.mooncode_jobs_session_id ==
                    model.selected_mooncode_session_id {
                    "code.hide_jobs"
                  } else {
                    "code.job_history"
                  },
                )
                .aria_label(
                  if model.mooncode_jobs_visible {
                    "Hide jobs"
                  } else {
                    "Job history"
                  },
                )
                .aria_expanded(
                  if model.mooncode_jobs_visible &&
                    model.mooncode_jobs_session_id ==
                    model.selected_mooncode_session_id {
                    "true"
                  } else {
                    "false"
                  },
                ),
              on_click=dispatch(ToggleMoonCodeJobs),
              ui_icon("history"),
            )
          },
          match session {
            Some(active) if active.mooncode_conversation is Some(_) =>
              a(
                class="mooncode-skill-toggle moon-icon-button",
                attrs=@html.Attrs::build()
                  .data_set("testid", "mooncode-export-conversation")
                  .data_set("i18n-aria-label", "code.export_conversation")
                  .aria_label("Export conversation")
                  .download("mooncode-\{active.id}.json"),
                href=@desk.mooncode_session_url(active.id) + "/export",
                ui_icon("download"),
              )
            _ => @html.nothing
          },
        ]),
        render_code_workbench_toolbar(),
      ]),
      render_mooncode_skill_catalog(dispatch, model),
      render_mooncode_job_history(dispatch, model),
      render_mooncode_schedules(dispatch, model),
      input(
        class="code-session-navigation-sync",
        attrs=@html.Attrs::build()
          .data_set("testid", "code-session-navigation")
          .aria_hidden("true")
          .tabindex(-1),
        on_input=fn(value) { dispatch(SelectMoonCodeSession(value)) },
      ),
      input(
        class="code-session-navigation-sync",
        attrs=@html.Attrs::build()
          .data_set("testid", "code-workspace-navigation")
          .aria_hidden("true")
          .tabindex(-1),
        on_input=fn(value) { dispatch(SelectWorkspace(value)) },
      ),
      div(class="code-workbench", [
        section(
          class=if empty {
            "mooncode-chat-surface empty"
          } else {
            "mooncode-chat-surface"
          },
          attrs=@html.Attrs::build().data_set("testid", "mooncode-chat-surface"),
          [
            render_mooncode_runtime_setup(dispatch, model),
            render_requested_selection(dispatch, model),
            match session {
              Some(active) =>
                details(class="code-task-inspector", [
                  summary("Task, queue and agents"),
                  div(
                    attrs=@html.Attrs::build()
                      .data_set("mooncode-task-controls", "true")
                      .data_set("session-id", active.id),
                    @html.nothing,
                  ),
                ])
              None => @html.nothing
            },
            match session {
              Some(session) =>
                div(class="mooncode-session-surface", [
                  render_mooncode_transcript(dispatch, model, session),
                ])
              None => @html.nothing
            },
            div(class="mooncode-composer", [
              div(
                class="code-context-tray",
                attrs=@html.Attrs::build()
                  .data_set("testid", "code-context-tray")
                  .aria_label("Context for the next message"),
                @html.nothing,
              ),
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
              render_mooncode_image_tray(dispatch, model),
              match session {
                Some(active) if mooncode_can_guide_running_work(active) =>
                  p(
                    class="mooncode-composer-intent",
                    attrs=@html.Attrs::build().data_set(
                      "i18n", "code.running_intent",
                    ),
                    "Guide current work now, or queue a separate turn after it.",
                  )
                _ => @html.nothing
              },
              match session {
                Some(active) if model.mooncode_guidance_feedback_session_id ==
                  active.id &&
                  model.mooncode_guidance_feedback != "" =>
                  p(
                    class="mooncode-guidance-feedback",
                    attrs=@html.Attrs::build()
                      .role("status")
                      .aria_live("polite"),
                    model.mooncode_guidance_feedback,
                  )
                _ => @html.nothing
              },
              div(class="composer-footer", [
                render_mooncode_composer_controls(dispatch, model),
                @html.label(
                  class="mooncode-attach-image mooncode-composer-icon-button",
                  attrs=@html.Attrs::build()
                    .data_set("testid", "mooncode-attach-image")
                    .data_set("i18n-title", "code.attach_image")
                    .title("Attach image"),
                  [
                    ui_icon("attach"),
                    input(
                      input_type=File,
                      accept="image/png,image/jpeg,image/webp",
                      multiple=true,
                      attrs=@html.Attrs::build()
                        .data_set("testid", "mooncode-image-file-input")
                        .data_set("i18n-aria-label", "code.attach_image_aria")
                        .aria_label("Attach images to Code request")
                        .disabled(
                          model.mooncode_image_submit_pending ||
                          model.mooncode_images.length() >= 4,
                        ),
                    ),
                  ],
                ),
                match session {
                  Some(active) if mooncode_can_guide_running_work(active) =>
                    button(
                      class="mooncode-guide-button",
                      attrs=@html.Attrs::build()
                        .data_set("testid", "mooncode-guide-current")
                        .data_set(
                          "i18n",
                          if model.mooncode_guidance_pending_session_id ==
                            active.id {
                            "code.guidance_sending"
                          } else {
                            "code.guide_current"
                          },
                        )
                        .data_set("i18n-aria-label", "code.guide_current_aria")
                        .aria_label("Guide current MoonCode work")
                        .on_click(_ => {
                          dispatch(
                            SendMoonCodeGuidance(
                              browser_mooncode_prompt_value(),
                            ),
                          )
                        })
                        .disabled(
                          model.mooncode_prompt.trim().to_owned() == "" ||
                          model.mooncode_guidance_pending_session_id != "" ||
                          mooncode_capability_submission_blocker(
                            model.mooncode_capability,
                          )
                          is Some(_),
                        ),
                      if model.mooncode_guidance_pending_session_id == active.id {
                        "Sending…"
                      } else {
                        "Guide current"
                      },
                    )
                  _ => @html.nothing
                },
                button(
                  class="primary-button mooncode-composer-icon-button",
                  attrs=@html.Attrs::build()
                    .data_set("testid", "mooncode-send")
                    .data_set("i18n-title", send_key)
                    .data_set("i18n-aria-label", send_key)
                    .title(mooncode_composer_button_label(model, session))
                    .aria_label(mooncode_composer_button_label(model, session))
                    .on_click(_ => {
                      dispatch(
                        SendMoonCodeMessage(browser_mooncode_prompt_value()),
                      )
                    })
                    .disabled(
                      (
                        model.mooncode_prompt.trim().to_owned() == "" &&
                        model.mooncode_images.is_empty()
                      ) ||
                      model.mooncode_image_submit_pending ||
                      mooncode_selection_unavailable(model) ||
                      (
                        !model.mooncode_images.is_empty() &&
                        !mooncode_selected_model_accepts_images(model)
                      ) ||
                      model.mooncode_guidance_pending_session_id != "" ||
                      mooncode_capability_submission_blocker(
                        model.mooncode_capability,
                      )
                      is Some(_),
                    ),
                  ui_icon(
                    if session is Some(active) &&
                      mooncode_can_guide_running_work(active) {
                      "queued"
                    } else {
                      "send"
                    },
                  ),
                ),
              ]),
              if model.mooncode_composer_status == "" ||
                model.mooncode_composer_status == "draft" ||
                model.mooncode_composer_status == "mooncode idle" ||
                model.mooncode_composer_status == "MoonCode workspace ready" ||
                model.mooncode_composer_status.has_prefix(
                  "MoonClaw daemon running on ",
                ) ||
                model.mooncode_composer_status.has_suffix(" model(s) available") ||
                model.mooncode_composer_status.has_suffix(
                  " MoonCode session(s)",
                ) ||
                model.mooncode_composer_status == "MoonClaw is not installed" {
                @html.nothing
              } else {
                let status_key = match model.mooncode_composer_status {
                  "MoonClaw is not installed" => "code.moonclaw_not_installed"
                  "MoonClaw is running but no default model is available" =>
                    "code.moonclaw_no_model"
                  "A copied MoonClaw service configuration points to an unavailable managed runtime; reinstall MoonClaw to repair it" =>
                    "code.moonclaw_copied_runtime_unavailable"
                  "MoonCode workspace ready" => "code.workspace_ready"
                  _ => ""
                }
                p(
                  class="mooncode-composer-status",
                  attrs=@html.Attrs::build()
                    .role("status")
                    .aria_live("polite")
                    .data_set("i18n", status_key)
                    .data_set(
                      "i18n-params",
                      ({ "count": model.mooncode_sessions.length() } : Json).stringify(),
                    )
                    .data_set(
                      "i18n-scope",
                      if status_key == "" {
                        "technical"
                      } else {
                        ""
                      },
                    ),
                  model.mooncode_composer_status,
                )
              },
            ]),
          ],
        ),
        div(class="code-workbench-work", [
          render_git_repository_context(dispatch, model),
          render_mooncode_workspace_editors(dispatch, model),
          render_mooncode_developer_tools(model),
        ]),
      ]),
    ],
  )
}

///|
fn render_mooncode_workspace_editors(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let office_only = model.office_editor.path != "" &&
    model.source_pane.requested_path == ""
  details(
    class="mooncode-workspace-editors",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-workspace-editors")
      .open(model.source_pane.open),
    [
      summary(
        class="mooncode-workspace-editors-summary",
        attrs=@html.Attrs::build()
          .data_set("i18n", "code.workspace_editors")
          .on_click(_ => dispatch(SourcePane(SetOpen(!model.source_pane.open)))),
        "Workspace editors · Source and Office",
      ),
      div(
        class="mooncode-workspace-editors-body",
        attrs=@html.Attrs::build().data_set(
          "coding-focus",
          if model.source_pane.requested_path != "" &&
            model.office_editor.path == "" {
            "true"
          } else {
            "false"
          },
        ),
        [
          if office_only {
            @html.nothing
          } else {
            render_source_editor(dispatch, model.source_pane)
          },
          if office_only {
            @html.nothing
          } else {
            @html.node(
              "div",
              @html.Attrs::build()
              .class("workspace-editor-splitter")
              .data_set("action", "resize-workspace-editors")
              .data_set("testid", "workspace-editor-splitter")
              .role("separator")
              .tabindex(0)
              .aria_label("Resize Source and Office editors")
              .data_set("i18n-aria-label", "code.resize_editors"),
              [span(class="workspace-editor-splitter-grip", "")],
            )
          },
          details(
            class="workspace-office-disclosure",
            attrs=@html.Attrs::build().open(model.office_editor.path != ""),
            [
              summary([
                ui_icon("book"),
                span(
                  attrs=@html.Attrs::build().data_set("i18n", "code.documents"),
                  "Documents",
                ),
              ]),
              render_office_editor(dispatch, model.office_editor),
            ],
          ),
        ],
      ),
    ],
  )
}

