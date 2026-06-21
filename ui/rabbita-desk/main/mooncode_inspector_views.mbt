///|
fn render_mooncode_inspector(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="inspector-pane", [
    div(class="pane-heading compact", [
      div([
        p(class="eyebrow", "context"),
        h2("What the agent can see"),
      ]),
    ]),
    section(class="inspector-section", [
      h3("Selected Book"),
      info_row("Book", workspace_name(model)),
      info_row("Root", workspace_root(model)),
      info_row("Selected", model.selected_path),
      button(
        class="secondary-button full",
        on_click=dispatch(SendMoonCodeMessage),
        mooncode_inspector_send_label(model),
      ),
    ]),
    section(class="inspector-section", [
      h3("Chat Settings"),
      match selected_mooncode_session(model) {
        Some(session) =>
          div(class="daemon-state", [
            info_row("Session", session.id),
            info_row("Status", session.status),
            info_row("Model", empty_label(session.model)),
            info_row(
              "Port",
              if session.port > 0 {
                session.port.to_string()
              } else {
                "none"
              },
            ),
            info_row("Web", if session.web_search { "on" } else { "off" }),
            info_row("Queued", session.queued_count.to_string()),
          ])
        None =>
          div(class="daemon-state", [
            info_row("Session", "new"),
            info_row("Runtime", "not attached"),
          ])
      },
      input(
        class="line-input",
        value=model.mooncode_model,
        placeholder=if model.moonclaw_models.length() == 0 {
          "model (daemon not connected)"
        } else {
          model.moonclaw_models[0].name
        },
        on_input=fn(value) { dispatch(SetMoonClawModel(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(ToggleMoonCodeWebSearch),
          if model.mooncode_web_search {
            "Disable Web"
          } else {
            "Enable Web"
          },
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("cancel")),
          "Cancel",
        ),
      ]),
    ]),
    div(class="hidden-advanced", [
      render_mooncode_readiness(model),
      render_mooncode_capability_panel(model),
    ]),
    section(class="inspector-section", [
      h3("Code Actions"),
      div(class="button-stack", [
        button(
          class="secondary-button full",
          on_click=dispatch(RunMoonCodeCommand("run_tests")),
          "Run Tests",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(RunMoonCodeCommand("run_build")),
          "Run Build",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(RunMoonCodeCommand("package")),
          "Package",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(RunMoonCodeCommand("commit")),
          "Commit",
        ),
      ]),
    ]),
    section(class="inspector-section", [
      h3("Available Models"),
      if model.moonclaw_models.length() == 0 {
        p(class="status-line", "none")
      } else {
        div(
          class="mini-list",
          model.moonclaw_models.map(model_info => {
            button(
              class="mini-link",
              title=model_info.name,
              on_click=dispatch(SetMoonClawModel(model_info.name)),
              model_info.name,
            )
          }),
        )
      },
    ]),
  ])
}

///|
fn mooncode_inspector_send_label(model : Model) -> String {
  match selected_mooncode_session(model) {
    Some(session) if model.workspace_mode == MoonCode =>
      mooncode_composer_button_label(model, Some(session)) + " MoonCode"
    Some(_) => "Send To MoonCode"
    None =>
      if model.workspace_mode == MoonCode {
        "Start MoonCode"
      } else {
        "Send To MoonCode"
      }
  }
}
