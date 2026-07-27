///|
fn render_app(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  match model.workspace_mode {
    PackHome =>
      div(class="desk-shell pack-home-shell", [
        render_skip_to_main(),
        render_title_bar(dispatch, model),
        render_pack_home(dispatch, model),
        render_command_palette(dispatch, model),
      ])
    Desk =>
      div(class="desk-shell file-desk-shell", [
        render_skip_to_main(),
        render_title_bar(dispatch, model),
        render_desk_mode(dispatch, model),
        render_command_palette(dispatch, model),
      ])
    MoonCode =>
      div(class="desk-shell code-shell", [
        render_skip_to_main(),
        render_title_bar(dispatch, model),
        main_(class="desk-main code-main", attrs=main_content_attrs(MoonCode), [
          h1(class="visually-hidden", "Code"),
          render_mooncode_pane(dispatch, model),
          render_mooncode_center(dispatch, model),
        ]),
        render_command_palette(dispatch, model),
      ])
    RequestsWorkspace =>
      div(class="desk-shell wiki-shell", [
        render_skip_to_main(),
        render_title_bar(dispatch, model),
        main_(
          class="desk-main primary-destination-main",
          attrs=main_content_attrs(RequestsWorkspace),
          [
            h1(class="visually-hidden", "Requests"),
            render_town_pane(dispatch, model),
          ],
        ),
        render_command_palette(dispatch, model),
      ])
    RunsWorkspace =>
      div(class="desk-shell wiki-shell", [
        render_skip_to_main(),
        render_title_bar(dispatch, model),
        render_runs_workspace(dispatch, model),
        render_command_palette(dispatch, model),
      ])
    ReviewWorkspace =>
      div(class="desk-shell wiki-shell", [
        render_skip_to_main(),
        render_title_bar(dispatch, model),
        main_(
          class="desk-main primary-destination-main",
          attrs=main_content_attrs(ReviewWorkspace),
          [
            h1(class="visually-hidden", "Review"),
            render_review_pane(dispatch, model),
          ],
        ),
        render_command_palette(dispatch, model),
      ])
    PublishWorkspace =>
      div(class="desk-shell wiki-shell", [
        render_skip_to_main(),
        render_title_bar(dispatch, model),
        render_publish_workspace(dispatch, model),
        render_command_palette(dispatch, model),
      ])
    MoonFlow =>
      div(class="desk-shell flow-shell", [
        render_skip_to_main(),
        render_title_bar(dispatch, model),
        render_moonflow_workspace(dispatch, model),
        render_command_palette(dispatch, model),
      ])
    MoonWiki =>
      div(class="desk-shell wiki-shell", [
        render_skip_to_main(),
        render_title_bar(dispatch, model),
        if model.workspaces.length() == 0 && model.activity == Files {
          main_(
            class="desk-main onboarding-main",
            attrs=main_content_attrs(MoonWiki),
            [render_wiki_bootstrap(dispatch, model)],
          )
        } else {
          main_(
            class="desk-main wiki-main",
            attrs=main_content_attrs(MoonWiki),
            [
              h1(class="visually-hidden", "Pages"),
              render_activity_rail(dispatch, model),
              render_activity_pane(dispatch, model),
              render_preview_center(dispatch, model),
            ],
          )
        },
        render_command_palette(dispatch, model),
        render_unsaved_markdown_navigation(dispatch, model),
      ])
  }
}
