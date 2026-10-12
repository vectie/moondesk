///|
fn source_outline_supported(source : SourcePaneState) -> Bool {
  let path = source.requested_path.to_lower()
  path.has_suffix(".md") ||
  path.has_suffix(".markdown") ||
  path.has_suffix(".mdx")
}

///|
fn update_source_outline(
  state : SourcePaneState,
  msg : SourcePaneMsg,
) -> SourcePaneState {
  guard source_outline_supported(state) && source_pane_editable(state) else {
    return state
  }
  let document = source_literal_document(state)
  match msg {
    SelectMarkdownSection(line) => {
      guard document.select_markdown_section(line) is Some(selection) else {
        return state
      }
      source_pane_commit_active({
        ..state,
        search: { ..state.search, selection: Some(selection), },
        status: "Selected section, including nested headings",
      })
    }
    MoveMarkdownSection(line, backwards) =>
      match
        document.move_markdown_section(
          line,
          expected_revision=document.revision(),
          backwards~,
        ) {
        Err(_) => { ..state, status: "Could not move this section", }
        Ok(false) => state
        Ok(true) => {
          let selected = document.selections()[0]
          let next = source_literal_record(
            state,
            document.text(),
            Some(@edit.Range::new(selected.anchor, selected.active)),
          )
          source_pane_commit_active({
            ..next,
            status: if backwards {
              "Moved section up; unsaved changes"
            } else {
              "Moved section down; unsaved changes"
            },
          })
        }
      }
    _ => state
  }
}

///|
fn render_source_outline(
  dispatch : Dispatch[Msg],
  source : SourcePaneState,
) -> @rabbita.Html {
  if !source_outline_supported(source) {
    return div("")
  }
  let document = source_literal_document(source)
  let outline = document.markdown_outline()
  let enabled = source_pane_editable(source)
  div(
    class="source-editor-outline",
    attrs=@html.Attrs::build()
      .data_set("testid", "source-outline")
      .aria_label("Markdown section outline"),
    [
      div(class="source-outline-description", [
        strong("Markdown sections · \{outline.length()}"),
        span(
          "Select a heading to edit its whole section. Move keeps nested headings together. Undo and Save work as usual.",
        ),
      ]),
      if outline.is_empty() {
        p(
          "Add a # heading to begin. Outline supports # through ###### headings outside fenced code.",
        )
      } else {
        div(
          class="source-outline-list",
          outline.map(heading => {
            let line = heading.heading.start.line
            let title = if heading.title == "" {
              "(untitled)"
            } else {
              heading.title
            }
            div(class="source-outline-row", [
              button(
                class="secondary-button source-outline-heading",
                attrs=@html.Attrs::build()
                  .data_set("testid", "source-outline-select-\{line}")
                  .data_set("level", heading.level.to_string())
                  .aria_label("Select section: " + title)
                  .aria_pressed(
                    if source.search.selection == Some(heading.section) {
                      "true"
                    } else {
                      "false"
                    },
                  )
                  .title("Line \{line + 1}; includes child sections"),
                disabled=!enabled,
                on_click=dispatch(SourcePane(SelectMarkdownSection(line))),
                "H\{heading.level} · " + title + " · L\{line + 1}",
              ),
              button(
                class="secondary-button",
                attrs=@html.Attrs::build()
                  .data_set("testid", "source-outline-up-\{line}")
                  .aria_label("Move section up: " + title),
                disabled=!enabled ||
                  !outline.any(other => {
                    other.level == heading.level &&
                    other.section.end == heading.heading.start
                  }),
                on_click=dispatch(SourcePane(MoveMarkdownSection(line, true))),
                "Up",
              ),
              button(
                class="secondary-button",
                attrs=@html.Attrs::build()
                  .data_set("testid", "source-outline-down-\{line}")
                  .aria_label("Move section down: " + title),
                disabled=!enabled ||
                  !outline.any(other => {
                    other.level == heading.level &&
                    other.heading.start == heading.section.end
                  }),
                on_click=dispatch(SourcePane(MoveMarkdownSection(line, false))),
                "Down",
              ),
            ])
          }),
        )
      },
    ],
  )
}
