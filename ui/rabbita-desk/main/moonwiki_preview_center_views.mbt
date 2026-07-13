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
      title: "Published",
      path: "book/site/generated/index.html",
      renderer: Html,
    })
  }
  match first_run_report_path(model) {
    Some(path) =>
      if path != primary_path && path != "book/site/generated/index.html" {
        tabs.push({ title: "Latest result", path, renderer: ArtifactSummary })
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
      if wiki_book_is_empty(model) {
        section(class="wiki-empty-book", [
          h1("Start this book"),
          p(
            class="lead",
            "Capture your first note or ask Wiki to turn a question into useful book content.",
          ),
          div(class="wiki-empty-book-actions", [
            button(
              class="primary-button",
              on_click=dispatch(SelectActivity(Inbox)),
              "Create a note",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(SelectActivity(Town)),
              "Ask this book",
            ),
          ]),
        ])
      } else if model.preview_status.to_lower().contains("loading") ||
        model.preview_status.to_lower().contains("waiting") {
        div(class="markdown-preview", [
          h1("Opening page"),
          p(class="lead", "Please wait."),
        ])
      } else {
        div(class="markdown-preview", [
          h1("Choose a page"),
          p(class="lead", "Select a page from the library to read it here."),
        ])
      }
    Some(preview) =>
      match preview.renderer {
        Html =>
          div(
            class="site-preview embedded-browser",
            attrs=@html.Attrs::build()
              .data_set("testid", "browser-preview-host")
              .data_set("viewport", "desktop"),
            [
              div(class="site-toolbar browser-toolbar", [
                div(class="browser-location", [
                  span(class="browser-security-badge", "Isolated"),
                  span(class="quiet-path", model.selected_path),
                ]),
                div(class="browser-toolbar-actions", [
                  button(
                    class="secondary-button browser-tool-button",
                    attrs=@html.Attrs::build()
                      .data_set("browser-viewport", "desktop")
                      .aria_pressed("true"),
                    on_click=dispatch(SetBrowserPreviewViewport("desktop")),
                    "Desktop",
                  ),
                  button(
                    class="secondary-button browser-tool-button",
                    attrs=@html.Attrs::build()
                      .data_set("browser-viewport", "tablet")
                      .aria_pressed("false"),
                    on_click=dispatch(SetBrowserPreviewViewport("tablet")),
                    "Tablet",
                  ),
                  button(
                    class="secondary-button browser-tool-button",
                    attrs=@html.Attrs::build()
                      .data_set("browser-viewport", "mobile")
                      .aria_pressed("false"),
                    on_click=dispatch(SetBrowserPreviewViewport("mobile")),
                    "Mobile",
                  ),
                  button(
                    class="secondary-button browser-tool-button",
                    on_click=dispatch(ReloadBrowserPreview),
                    "Reload",
                  ),
                ]),
              ]),
              div(class="browser-frame-stage", [
                iframe(
                  class="site-iframe",
                  src=html_preview_url(model, model.selected_path),
                  title=preview.title,
                  sandbox="allow-scripts",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "browser-preview-frame",
                  ),
                ),
              ]),
              div(class="browser-observation-bar", [
                span(
                  class="browser-preview-status",
                  attrs=@html.Attrs::build().data_set(
                    "testid", "browser-preview-status",
                  ),
                  "Loading isolated preview",
                ),
                div(class="browser-observation-actions", [
                  button(
                    class="secondary-button",
                    attrs=@html.Attrs::build().data_set(
                      "testid", "browser-prepare-evidence",
                    ),
                    on_click=dispatch(CaptureBrowserPreviewEvidence),
                    "Prepare evidence",
                  ),
                  button(
                    class="primary-button",
                    on_click=dispatch(FixBrowserPreviewInMoonCode),
                    "Fix in MoonCode",
                  ),
                ]),
              ]),
              div(
                class="browser-operation-banner",
                attrs=@html.Attrs::build()
                  .data_set("testid", "browser-operation-banner")
                  .data_set("host-attached", "false")
                  .data_set("operation-state", "user-control"),
                [
                  div(class="browser-operation-copy", [
                    strong("User control"),
                    span(
                      attrs=@html.Attrs::build().data_set(
                        "testid", "browser-operation-status",
                      ),
                      "No agent operation is attached",
                    ),
                  ]),
                  div(class="browser-operation-controls", [
                    browser_host_control_button(
                      dispatch, "pause", "Pause agent",
                    ),
                    browser_host_control_button(dispatch, "stop", "Stop agent"),
                    browser_host_control_button(
                      dispatch, "takeover", "Take over",
                    ),
                  ]),
                ],
              ),
              details(class="browser-diagnostics", [
                summary("Diagnostics"),
                div(class="browser-diagnostics-grid", [
                  browser_diagnostic_panel(
                    "Console", "browser-console-output", "No console output observed",
                  ),
                  browser_diagnostic_panel(
                    "Runtime", "browser-runtime-output", "No runtime errors observed",
                  ),
                  browser_diagnostic_panel(
                    "Network", "browser-network-output", "Local assets only",
                  ),
                  browser_diagnostic_panel(
                    "Accessibility", "browser-accessibility-output", "Prepare evidence to inspect semantics",
                  ),
                ]),
                p(
                  class="browser-diagnostics-note",
                  "Prepared observations remain untrusted until a host receipt is accepted and durable evidence persistence succeeds.",
                ),
              ]),
            ],
          )
        Image =>
          div(class="image-preview", [img(src=preview.body, alt=preview.title)])
        DirectoryListing =>
          div(class="markdown-preview", [
            h1(preview.title),
            p(class="lead", "Choose an item from the left."),
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
fn browser_host_control_button(
  dispatch : Dispatch[Msg],
  control : String,
  label : String,
) -> @rabbita.Html {
  button(
    class="secondary-button",
    attrs=@html.Attrs::build()
      .data_set("browser-control", control)
      .disabled(true),
    on_click=dispatch(RequestBrowserHostControl(control)),
    label,
  )
}

///|
fn browser_diagnostic_panel(
  title : String,
  testid : String,
  empty : String,
) -> @rabbita.Html {
  section(class="browser-diagnostic-panel", [
    strong(title),
    pre(attrs=@html.Attrs::build().data_set("testid", testid), code(empty)),
  ])
}

///|
fn render_markdown_editor(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="markdown-edit-surface", [
    div(class="site-toolbar", [
      span(class="quiet-path", model.markdown_editor_path),
      span(class="editor-save-state", wiki_editor_status_label(model)),
    ]),
    div(class="markdown-editor-grid", [
      textarea(
        class="markdown-editor",
        attrs=@html.Attrs::build().aria_label("Edit page Markdown"),
        rows=28,
        value=model.markdown_editor_content,
        on_input=fn(value) { dispatch(SetMarkdownEditorContent(value)) },
        "",
      ),
      section(
        class="document-preview markdown-live-preview",
        render_markdown_document(markdown_editor_preview(model)),
      ),
    ]),
  ])
}

///|
fn markdown_editor_preview(model : Model) -> @desk.DeskPreview {
  @desk.preview(
    @desk.file_entry(
      workspace_id=model.selected_workspace_id,
      path=model.markdown_editor_path,
    ),
    body=model.markdown_editor_content,
  )
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
      span(class="path-pill quiet-path", model.selected_path),
      div(class="toolbar-actions", [
        if !markdown_editor_active(model) &&
          model.markdown_editor_status.to_lower().contains("saved") {
          span(class="editor-save-state saved", "Saved")
        } else {
          @html.nothing
        },
        if markdown_editor_active(model) {
          button(
            class="primary-button",
            on_click=dispatch(SaveMarkdownEdit),
            "Save",
          )
        } else if can_edit_markdown_selection(model) {
          button(
            class="primary-button",
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
        if markdown_editor_active(model) {
          @html.nothing
        } else {
          render_sources_history_menu(dispatch, model)
        },
        if markdown_editor_active(model) {
          @html.nothing
        } else {
          render_document_more_menu(dispatch, model)
        },
      ]),
    ]),
    section(class="preview-surface", [render_preview_body(dispatch, model)]),
  ])
}

///|
fn render_unsaved_markdown_navigation(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if model.pending_markdown_navigation is NoPendingMarkdownNavigation {
    @html.nothing
  } else {
    div(class="unsaved-navigation-backdrop", [
      section(
        class="unsaved-navigation-dialog",
        attrs=@html.Attrs::build()
          .role("dialog")
          .aria_label("Discard unsaved changes?"),
        [
          h2("Discard unsaved changes?"),
          p(wiki_unsaved_navigation_message(model)),
          div(class="unsaved-navigation-actions", [
            button(
              class="primary-button",
              on_click=dispatch(CancelDiscardMarkdownNavigation),
              "Keep editing",
            ),
            button(
              class="secondary-button danger-button",
              on_click=dispatch(ConfirmDiscardMarkdownNavigation),
              "Discard changes",
            ),
          ]),
        ],
      ),
    ])
  }
}

///|
fn wiki_unsaved_navigation_message(model : Model) -> String {
  "Your changes to " +
  @desk.display_name(model.markdown_editor_path) +
  " have not been saved."
}

///|
fn render_sources_history_menu(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  details(class="toolbar-disclosure", [
    summary(class="secondary-button disclosure-button", "Sources and history"),
    div(class="disclosure-panel", [
      strong("Trace this book's knowledge"),
      p(
        "Review proposed changes, completed work, and original material without leaving Wiki.",
      ),
      div(class="button-stack", [
        button(
          class="secondary-button full",
          on_click=dispatch(SelectActivity(Runs)),
          "Open review",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(SelectActivity(Town)),
          "Open activity",
        ),
      ]),
      details(class="technical-details", [
        summary("Technical location"),
        code(model.selected_path),
      ]),
    ]),
  ])
}

///|
fn render_document_more_menu(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  details(class="toolbar-disclosure", [
    summary(class="secondary-button disclosure-button", "More"),
    div(class="disclosure-panel compact-menu", [
      button(
        class=if has_string(model.favorites, model.selected_path) {
          "secondary-button active full"
        } else {
          "secondary-button full"
        },
        on_click=dispatch(ToggleFavorite(model.selected_path)),
        if has_string(model.favorites, model.selected_path) {
          "Remove favorite"
        } else {
          "Add favorite"
        },
      ),
      if model.preview is Some({ renderer: Html, .. }) {
        @html.nothing
      } else {
        a(
          class="secondary-button link-button full",
          href=raw_url(model, model.selected_path),
          target=Blank,
          rel="noreferrer",
          "Open original",
        )
      },
      button(
        class="secondary-button full",
        on_click=dispatch(RevealSelection),
        "Reveal in files",
      ),
    ]),
  ])
}
