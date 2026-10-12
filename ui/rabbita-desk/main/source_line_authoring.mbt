///|
fn source_line_shortcut(
  key : String,
  command : Bool,
  shift : Bool,
  alt : Bool,
  composing : Bool,
) -> SourcePaneMsg? {
  if composing {
    return None
  }
  if command && !shift && !alt {
    match key {
      "]" => Some(IndentLines(false))
      "[" => Some(IndentLines(true))
      _ => None
    }
  } else if !command && shift && alt && key == "ArrowDown" {
    Some(DuplicateLines)
  } else {
    None
  }
}

///|
fn update_source_line_authoring(
  state : SourcePaneState,
  msg : SourcePaneMsg,
) -> SourcePaneState {
  guard source_pane_editable(state) else { return state }
  if msg is SetLineIndent(indentation) {
    return source_pane_commit_active({
      ..state,
      search: { ..state.search, indentation, },
    })
  }
  let document = source_literal_document(state)
  if msg is WrapMarkdown(_) &&
    state.search.selection is Some(range) &&
    (
      !document.contains_position(range.start) ||
      !document.contains_position(range.end)
    ) {
    return { ..state, status: "Select text again before wrapping Markdown", }
  }
  let status = match msg {
    WrapMarkdown(style) =>
      match
        document.wrap_markdown_selection(
          style,
          expected_revision=document.revision(),
        ) {
        Err(_) =>
          return { ..state, status: "Could not wrap the selected text", }
        Ok(_) => "Added Markdown delimiters; content selected, unsaved changes"
      }
    EditChecklist(action) =>
      match
        document.edit_markdown_checklist(
          action,
          expected_revision=document.revision(),
        ) {
        Err(_) =>
          return { ..state, status: "Could not edit the selected checklist", }
        Ok(0) =>
          return {
            ..state,
            status: "No eligible checklist lines; fenced code is skipped",
          }
        Ok(count) => "Updated \{count} checklist lines; unsaved changes"
      }
    IndentLines(backwards) =>
      match
        document.indent_selected_lines(
          expected_revision=document.revision(),
          indentation=state.search.indentation,
          backwards~,
        ) {
        Err(_) =>
          return { ..state, status: "Could not edit the selected lines", }
        Ok(0) =>
          return {
            ..state,
            status: "Selected lines have no leading indentation",
          }
        Ok(count) =>
          if backwards {
            "Outdented \{count} lines; unsaved changes"
          } else {
            "Indented \{count} lines; unsaved changes"
          }
      }
    DuplicateLines =>
      match
        document.duplicate_selected_lines(expected_revision=document.revision()) {
        Err(_) =>
          return { ..state, status: "Could not duplicate the selected lines", }
        Ok(_) => "Duplicated lines; copy selected, unsaved changes"
      }
    _ => return state
  }
  let selected = document.selections()[0]
  let next = source_literal_record(
    state,
    document.text(),
    Some(@edit.Range::new(selected.anchor, selected.active)),
  )
  source_pane_commit_active({ ..next, status, })
}

///|
fn render_source_line_authoring(
  dispatch : Dispatch[Msg],
  source : SourcePaneState,
) -> @rabbita.Html {
  let enabled = source_pane_editable(source)
  div(
    class="source-editor-line-actions",
    attrs=@html.Attrs::build()
      .data_set("testid", "source-line-actions")
      .aria_label("Line authoring"),
    [
      div(
        attrs=@html.Attrs::build().aria_label("Selected text Markdown"),
        [@edit.MarkdownInlineStyle::Bold, Italic, Code].map(style => {
          let (id, label) = match style {
            Bold => ("bold", "Wrap bold")
            Italic => ("italic", "Wrap italic")
            Code => ("code", "Wrap code")
          }
          button(
            class="secondary-button",
            attrs=@html.Attrs::build()
              .data_set("testid", "source-inline-" + id)
              .title(
                "Insert Markdown delimiters around selected text; not a toggle",
              ),
            disabled=!enabled,
            on_click=dispatch(SourcePane(WrapMarkdown(style))),
            label,
          )
        }),
      ),
      span("Selected lines"),
      render_source_line_cleanup(dispatch, source),
      div(
        attrs=@html.Attrs::build().aria_label("Markdown checklist"),
        [
          @edit.MarkdownChecklistAction::CreateTasks,
          CompleteTasks,
          ReopenTasks,
          RemoveTasks,
        ].map(action => {
          let (id, label) = match action {
            CreateTasks => ("create", "Make checklist")
            CompleteTasks => ("complete", "Mark complete")
            ReopenTasks => ("reopen", "Mark incomplete")
            RemoveTasks => ("remove", "Remove task prefixes")
          }
          button(
            class="secondary-button",
            attrs=@html.Attrs::build()
              .data_set("testid", "source-checklist-" + id)
              .title("Selected lines only; fenced code is skipped"),
            disabled=!enabled,
            on_click=dispatch(SourcePane(EditChecklist(action))),
            label,
          )
        }),
      ),
      button(
        class="secondary-button",
        attrs=@html.Attrs::build()
          .data_set("testid", "source-indent-lines")
          .title("Indent selected lines (Ctrl/Cmd+])"),
        disabled=!enabled,
        on_click=dispatch(SourcePane(IndentLines(false))),
        "Indent",
      ),
      button(
        class="secondary-button",
        attrs=@html.Attrs::build()
          .data_set("testid", "source-outdent-lines")
          .title("Outdent selected lines (Ctrl/Cmd+[)"),
        disabled=!enabled,
        on_click=dispatch(SourcePane(IndentLines(true))),
        "Outdent",
      ),
      button(
        class="secondary-button",
        attrs=@html.Attrs::build()
          .data_set("testid", "source-duplicate-lines")
          .title("Duplicate selected lines below (Alt+Shift+Down)"),
        disabled=!enabled,
        on_click=dispatch(SourcePane(DuplicateLines)),
        "Duplicate lines",
      ),
      span("Indent with:"),
      div(
        class="source-line-indent-options",
        [@edit.LineIndent::TwoSpaces, FourSpaces, Tab].map(indentation => {
          let label = match indentation {
            TwoSpaces => "2 spaces"
            FourSpaces => "4 spaces"
            Tab => "Tab"
          }
          let id = match indentation {
            TwoSpaces => "2"
            FourSpaces => "4"
            Tab => "tab"
          }
          button(
            class="secondary-button",
            attrs=@html.Attrs::build()
              .data_set("testid", "source-indent-" + id)
              .aria_label("Indent with " + label)
              .aria_pressed(
                if source.search.indentation == indentation {
                  "true"
                } else {
                  "false"
                },
              ),
            disabled=!enabled,
            on_click=dispatch(SourcePane(SetLineIndent(indentation))),
            label,
          )
        }),
      ),
      span(
        class="source-line-help",
        "A caret edits its line. A selection edits whole lines. Undo works as usual.",
      ),
    ],
  )
}
