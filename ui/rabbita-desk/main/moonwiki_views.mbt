///|
fn render_activity_rail(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="activity-rail", [
    div(class="rail-mark", "MD"),
    div(
      class="rail-buttons",
      activities().map(item => {
        let class_name = if item.key == model.activity {
          "rail-button active"
        } else {
          "rail-button"
        }
        button(
          class=class_name,
          title=item.label,
          on_click=dispatch(SelectActivity(item.key)),
          [
            span(class="rail-icon", item.icon),
            span(class="sr-only", item.label),
          ],
        )
      }),
    ),
  ])
}

///|
fn layer_label(layer : @desk.SourceLayer) -> String {
  match layer {
    Wiki => "wiki"
    RawEvidence => "raw"
    GeneratedSite => "site"
    BookOutput => "book"
    Review => "review"
    History => "history"
    RunArtifact => "run"
    Inbox => "inbox"
    Config => "config"
    Workspace => "root"
  }
}

///|
fn icon_for_kind(kind : @desk.EntryKind) -> String {
  match kind {
    Directory => "D"
    Markdown => "M"
    Html => "H"
    Json => "J"
    Image => "P"
    Artifact => "A"
    Text => "T"
    Unknown => "?"
  }
}

///|
fn renderer_label(renderer : @desk.PreviewRenderer) -> String {
  match renderer {
    Markdown => "markdown"
    Html => "html"
    Json => "json"
    Image => "image"
    Text => "text"
    ArtifactSummary => "artifact"
    DirectoryListing => "directory"
    Unsupported => "unsupported"
  }
}

///|
fn render_explorer(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  match model.activity {
    Search => render_search_pane(dispatch, model)
    Inbox => render_inbox_pane(dispatch, model)
    MoonCode => render_mooncode_pane(dispatch, model)
    Town => render_town_pane(dispatch, model)
    Runs => render_runs_pane(dispatch, model)
    Settings => render_settings_pane(dispatch, model)
    Explorer => render_files_pane(dispatch, model)
  }
}
