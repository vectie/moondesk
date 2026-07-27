///|
fn main_content_attrs(mode : WorkspaceMode) -> @html.Attrs {
  @html.Attrs::build()
  .id("moondesk-main-content")
  .tabindex(-1)
  .aria_label(workspace_mode_label(mode) + " workspace")
}

///|
fn render_skip_to_main() -> @rabbita.Html {
  a(
    class="moondesk-skip-link",
    href="#moondesk-main-content",
    attrs=@html.Attrs::build().data_set("testid", "skip-to-main"),
    "Skip to main content",
  )
}

///|
fn destination_announcement(model : Model) -> String {
  let destination = workspace_mode_label(model.workspace_mode)
  if model.selected_workspace_id == "" {
    "\{destination} destination. No book selected."
  } else {
    "\{destination} destination. Selected book: \{workspace_name(model)}."
  }
}

///|
fn render_destination_announcement(model : Model) -> @rabbita.Html {
  p(
    class="visually-hidden",
    attrs=@html.Attrs::build()
      .data_set("testid", "destination-announcement")
      .role("status")
      .aria_live("polite")
      .aria_atomic("true"),
    destination_announcement(model),
  )
}

///|
fn render_polite_state_announcement(
  test_id : String,
  title : String,
  detail : String,
) -> @rabbita.Html {
  div(
    class="surface-state-announcement visually-hidden",
    attrs=@html.Attrs::build()
      .data_set("testid", test_id)
      .role("status")
      .aria_live("polite")
      .aria_atomic("true"),
    [strong(title), p(detail)],
  )
}
