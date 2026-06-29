///|
fn render_app(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  match model.workspace_mode {
    Desk =>
      div(class="desk-shell file-desk-shell", [
        render_title_bar(dispatch, model),
        if model.workspaces.length() == 0 {
          div(class="desk-main onboarding-main", [
            render_wiki_bootstrap(dispatch, model),
          ])
        } else {
          render_desk_mode(dispatch, model)
        },
        render_command_palette(dispatch, model),
      ])
    MoonCode =>
      div(class="desk-shell code-shell", [
        render_title_bar(dispatch, model),
        div(class="desk-main code-main", [
          render_mooncode_pane(dispatch, model),
          render_mooncode_center(dispatch, model),
        ]),
        render_command_palette(dispatch, model),
      ])
    MoonWiki =>
      div(class="desk-shell wiki-shell", [
        render_title_bar(dispatch, model),
        if model.workspaces.length() == 0 && model.activity == Explorer {
          div(class="desk-main onboarding-main", [
            render_wiki_bootstrap(dispatch, model),
          ])
        } else {
          div(class="desk-main wiki-main", [
            render_activity_rail(dispatch, model),
            render_explorer(dispatch, model),
            render_preview_center(dispatch, model),
          ])
        },
        render_command_palette(dispatch, model),
      ])
  }
}
