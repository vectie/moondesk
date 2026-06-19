///|
fn render_inspector(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="inspector-pane", [
    div(class="pane-heading compact", [
      div([p(class="eyebrow", "inspector"), h2("Context")]),
    ]),
    section(class="inspector-section", [
      h3("Selection"),
      info_row("Path", model.selected_path),
      info_row("Book", workspace_name(model)),
      info_row("Layer", selected_layer(model)),
      info_row(
        "Writable",
        if is_inbox_path(model.selected_path) {
          "yes"
        } else {
          "inbox only"
        },
      ),
      info_row("Reveal", model.reveal_status),
      button(
        class="secondary-button full",
        on_click=dispatch(StageSelectedLink),
        "Copy Link To Inbox",
      ),
    ]),
    section(class="inspector-section", [
      h3("Tags"),
      input(
        class="line-input",
        value=model.tag_value,
        placeholder="tag",
        on_input=fn(value) { dispatch(SetTagValue(value)) },
        "",
      ),
      button(
        class="secondary-button full",
        on_click=dispatch(TagSelection),
        "Tag Selection",
      ),
      render_tag_list(model),
    ]),
    render_review_diff_panel(model),
    section(class="inspector-section", [
      h3("Favorites"),
      render_path_list(dispatch, model.favorites),
    ]),
    section(class="composer", [
      h3("Request"),
      textarea(
        class="composer-input",
        rows=8,
        value=model.request_prompt,
        on_input=fn(value) { dispatch(SetRequestPrompt(value)) },
        "",
      ),
      div(class="composer-options", [
        span(class="option-chip active", "one-shot"),
        span(class="option-chip", "selected-context"),
      ]),
      button(
        class="primary-button full",
        on_click=dispatch(SubmitRequest),
        "Submit to Town",
      ),
      p(class="status-line", model.request_status),
    ]),
  ])
}

///|
fn render_review_diff_panel(model : Model) -> @rabbita.Html {
  section(class="inspector-section", [
    h3("Review"),
    match model.review_diff {
      Some(diff) =>
        div(class="review-diff", [
          info_row("Base", empty_label(diff.base_path)),
          info_row("Path", diff.path),
          info_row("Workspace", diff.workspace_id),
          info_row("Compare", empty_label(diff.comparison_path)),
          info_row("Ready", if diff.ok { "yes" } else { "no" }),
          info_row("Added", diff.added.to_string()),
          info_row("Removed", diff.removed.to_string()),
          info_row("Changed", if diff.changed { "yes" } else { "no" }),
          pre(class="source-block compact", code(diff.body)),
        ])
      None => p(class="status-line", "waiting for diff")
    },
  ])
}

///|
fn render_tag_list(model : Model) -> @rabbita.Html {
  let tags = selection_tags(model)
  if tags.length() == 0 {
    p(class="status-line", "none")
  } else {
    div(
      class="mini-list",
      tags.map(tag => {
        span(
          class="option-chip active",
          title="\{tag.id} / \{tag.created_at}",
          tag.tag,
        )
      }),
    )
  }
}

///|
fn selection_tags(model : Model) -> Array[TagRecord] {
  let selected : Array[TagRecord] = []
  for tag in model.tags {
    if tag.workspace_id == model.selected_workspace_id &&
      tag.path == model.selected_path {
      selected.push(tag)
    }
  }
  selected
}

///|
fn render_path_list(
  dispatch : Dispatch[Msg],
  paths : Array[String],
) -> @rabbita.Html {
  if paths.length() == 0 {
    p(class="status-line", "none")
  } else {
    div(
      class="mini-list",
      paths.map(path => {
        button(
          class="mini-link",
          title=path,
          on_click=dispatch(OpenQuickPath(path)),
          path,
        )
      }),
    )
  }
}

///|
fn info_row(label : String, value : String) -> @rabbita.Html {
  div(class="info-row", [span(label), code(value)])
}
