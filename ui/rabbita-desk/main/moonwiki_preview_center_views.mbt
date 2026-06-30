///|
fn preview_tabs(model : Model) -> Array[PreviewTab] {
  let tabs : Array[PreviewTab] = []
  let primary_path = if is_generated_site_path(model.selected_path) {
    model.primary_preview_path
  } else {
    model.selected_path
  }
  tabs.push({
    title: @desk.display_name(primary_path),
    path: primary_path,
    renderer: tab_renderer(model, primary_path),
  })
  if primary_path != "book/site/generated/index.html" {
    tabs.push({
      title: "generated site",
      path: "book/site/generated/index.html",
      renderer: Html,
    })
  }
  match first_run_report_path(model) {
    Some(path) =>
      if path != primary_path && path != "book/site/generated/index.html" {
        tabs.push({ title: "run report", path, renderer: ArtifactSummary })
      }
    None => ()
  }
  tabs
}

///|
fn tab_renderer(model : Model, path : String) -> @desk.PreviewRenderer {
  if path == model.selected_path {
    match model.preview {
      Some(preview) => preview.renderer
      None => @desk.renderer_for_kind(@desk.infer_entry_kind(path))
    }
  } else {
    @desk.renderer_for_kind(@desk.infer_entry_kind(path))
  }
}

///|
fn first_run_report_path(model : Model) -> String? {
  for run in model.runs {
    for artifact in run.artifacts {
      if artifact.path.has_suffix("report.md") {
        return Some(artifact.path)
      }
    }
  }
  None
}

///|
fn render_tabs(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  div(
    class="tab-strip",
    preview_tabs(model).map(tab => {
      let class_name = if tab.path == model.selected_path {
        "preview-tab active"
      } else {
        "preview-tab"
      }
      button(
        class=class_name,
        title=tab.path,
        on_click=dispatch(OpenQuickPath(tab.path)),
        [
          span(class="tab-title", tab.title),
          span(class="tab-renderer", renderer_label(tab.renderer)),
        ],
      )
    }),
  )
}

///|
fn render_preview_body(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if markdown_editor_active(model) {
    return render_markdown_editor(dispatch, model)
  }
  match model.preview {
    None =>
      div(class="markdown-preview", [
        h1("Preview"),
        p(class="lead", model.preview_status),
        pre(class="source-block", code(model.selected_path)),
      ])
    Some(preview) =>
      match preview.renderer {
        Html =>
          div(class="site-preview", [
            div(class="site-toolbar", [
              span(model.selected_path),
              a(
                class="secondary-button link-button",
                href=html_preview_url(model, model.selected_path),
                target=Blank,
                rel="noreferrer",
                "Open",
              ),
            ]),
            iframe(
              class="site-iframe",
              src=html_preview_url(model, model.selected_path),
              title=preview.title,
              sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-downloads",
            ),
          ])
        Image =>
          div(class="image-preview", [img(src=preview.body, alt=preview.title)])
        DirectoryListing =>
          div(class="markdown-preview", [
            h1(preview.title),
            p(class="lead", "Directory listing"),
            pre(class="source-block", code(preview.body)),
          ])
        Markdown =>
          section(class="document-preview", render_markdown_document(preview))
        Text =>
          section(class="document-preview", [
            h1(preview.title),
            p(class="lead", preview.body),
          ])
        _ =>
          div(class="markdown-preview", [
            h1(preview.title),
            render_preview_warnings(preview),
            pre(class="source-block", code(preview.body)),
          ])
      }
  }
}

///|
fn render_markdown_editor(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="markdown-edit-surface", [
    div(class="site-toolbar", [
      span(model.markdown_editor_path),
      span(class="record-kind", model.markdown_editor_status),
    ]),
    textarea(
      class="markdown-editor",
      rows=28,
      value=model.markdown_editor_content,
      on_input=fn(value) { dispatch(SetMarkdownEditorContent(value)) },
      "",
    ),
  ])
}

///|
fn render_markdown_document(
  preview : @desk.DeskPreview,
) -> Array[@rabbita.Html] {
  let nodes : Array[@rabbita.Html] = []
  let mut saw_heading = false
  for raw in preview.body.split("\n") {
    let line = raw.trim().to_owned()
    if line == "" {
      continue
    } else if line.has_prefix("# ") {
      saw_heading = true
      nodes.push(h1(line[2:].to_owned()))
    } else if line.has_prefix("## ") {
      nodes.push(h2(line[3:].to_owned()))
    } else if line.has_prefix("### ") {
      nodes.push(h3(line[4:].to_owned()))
    } else if line.has_prefix("- ") {
      nodes.push(p(class="doc-list-line", line[2:].to_owned()))
    } else {
      nodes.push(p(line))
    }
  }
  if !saw_heading {
    nodes.insert(0, h1(preview.title))
  }
  if preview.warnings.length() > 0 {
    nodes.push(render_preview_warnings(preview))
  }
  nodes
}

///|
fn render_preview_warnings(preview : @desk.DeskPreview) -> @rabbita.Html {
  if preview.warnings.length() == 0 {
    @html.nothing
  } else {
    ul(class="warning-list", preview.warnings.map(warning => li(warning)))
  }
}

///|
fn render_preview_center(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  main_(class="preview-center", [
    render_tabs(dispatch, model),
    div(class="preview-toolbar", [
      span(class="path-pill", model.selected_path),
      div(class="toolbar-actions", [
        button(
          class=if has_string(model.favorites, model.selected_path) {
            "secondary-button active"
          } else {
            "secondary-button"
          },
          on_click=dispatch(ToggleFavorite(model.selected_path)),
          "Favorite",
        ),
        a(
          class="secondary-button link-button",
          href=raw_url(model, model.selected_path),
          target=Blank,
          rel="noreferrer",
          "Open Raw",
        ),
        if markdown_editor_active(model) {
          button(
            class="primary-button",
            on_click=dispatch(SaveMarkdownEdit),
            "Save",
          )
        } else if can_edit_markdown_selection(model) {
          button(
            class="secondary-button",
            on_click=dispatch(StartMarkdownEdit),
            "Edit",
          )
        } else {
          @html.nothing
        },
        if markdown_editor_active(model) {
          button(
            class="secondary-button",
            on_click=dispatch(CancelMarkdownEdit),
            "Cancel",
          )
        } else {
          @html.nothing
        },
        button(
          class="secondary-button",
          on_click=dispatch(RevealSelection),
          "Reveal",
        ),
        button(
          class="primary-button",
          on_click=dispatch(ToggleCommand),
          "Command",
        ),
      ]),
    ]),
    section(class="preview-surface", [render_preview_body(dispatch, model)]),
  ])
}
