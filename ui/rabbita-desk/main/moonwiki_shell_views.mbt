///|
fn render_app(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  let code_mode = model.workspace_mode == MoonCode
  let center = if code_mode {
    render_mooncode_center(dispatch, model)
  } else {
    render_preview_center(dispatch, model)
  }
  let inspector = if code_mode {
    render_mooncode_inspector(dispatch, model)
  } else {
    render_inspector(dispatch, model)
  }
  let side = if code_mode {
    render_mooncode_pane(dispatch, model)
  } else {
    render_explorer(dispatch, model)
  }
  div(class="desk-shell", [
    render_title_bar(dispatch, model),
    div(class="desk-main", [
      render_activity_rail(dispatch, model),
      side,
      center,
      inspector,
    ]),
    render_bottom_drawer(dispatch, model),
    render_command_palette(dispatch, model),
  ])
}
