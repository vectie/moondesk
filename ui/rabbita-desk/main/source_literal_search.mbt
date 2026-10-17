///|
struct SourceLiteralSnapshot {
  text : String
  selection : @edit.Range?
} derive(Eq, Debug)

///|
struct SourceLiteralState {
  query : String
  replacement : String
  case_sensitive : Bool
  indentation : @edit.LineIndent
  selection : @edit.Range?
  undo : Array[SourceLiteralSnapshot]
  redo : Array[SourceLiteralSnapshot]
} derive(Eq, Debug)

///|
fn init_source_literal() -> SourceLiteralState {
  {
    query: "",
    replacement: "",
    case_sensitive: true,
    indentation: TwoSpaces,
    selection: None,
    undo: [],
    redo: [],
  }
}

///|
fn source_literal_document(state : SourcePaneState) -> @edit.Document {
  let document = @edit.Document::new(state.draft)
  if state.search.selection is Some(range) &&
    document.contains_position(range.start) &&
    document.contains_position(range.end) {
    let _ = document.set_selections([
      @edit.Selection::new(range.start, range.end),
    ])
  }
  document
}

///|
fn source_literal_matches(state : SourcePaneState) -> Array[@edit.Range] {
  source_literal_document(state).literal_matches(
    state.search.query,
    case_sensitive=state.search.case_sensitive,
  )
}

///|
fn source_literal_summary(state : SourcePaneState) -> String {
  if state.search.query == "" {
    return "No search"
  }
  let matches = source_literal_matches(state)
  let active = for index, range in matches {
    if state.search.selection == Some(range) {
      break index + 1
    }
  } nobreak {
    0
  }
  "\{active}/\{matches.length()} matches"
}

///|
fn source_literal_record(
  state : SourcePaneState,
  draft : String,
  selection : @edit.Range?,
) -> SourcePaneState {
  if state.draft == draft {
    return { ..state, search: { ..state.search, selection, }, }
  }
  let undo = state.search.undo +
    [{ text: state.draft, selection: state.search.selection, }]
  // Bound ordinary editor history, retaining each replace-all as one entry.
  let undo = if undo.length() > 100 { undo[1:].to_owned() } else { undo }
  {
    ..state,
    draft,
    search: { ..state.search, selection, undo, redo: [], },
    status: "Unsaved changes",
  }
}

///|
fn update_source_literal(
  state : SourcePaneState,
  msg : SourcePaneMsg,
) -> SourcePaneState {
  match msg {
    FindQuery(query) =>
      { ..state, search: { ..state.search, query, selection: None, }, }
    FindReplacement(replacement) =>
      { ..state, search: { ..state.search, replacement, }, }
    FindCaseSensitive(case_sensitive) =>
      { ..state, search: { ..state.search, case_sensitive, selection: None, }, }
    FindNext | FindPrevious => {
      guard source_pane_editable(state) else { return state }
      let document = source_literal_document(state)
      let selection = document.find_literal(
        state.search.query,
        backwards=msg is FindPrevious,
        case_sensitive=state.search.case_sensitive,
      )
      source_pane_commit_active({
        ..state,
        search: { ..state.search, selection, },
      })
    }
    ReplaceNext | ReplaceAll => {
      guard source_pane_editable(state) else { return state }
      let document = source_literal_document(state)
      let result = if msg is ReplaceAll {
        document.replace_literal_all_count(
          state.search.query,
          state.search.replacement,
          expected_revision=document.revision(),
          case_sensitive=state.search.case_sensitive,
        )
      } else {
        document.replace_literal_next(
          state.search.query,
          state.search.replacement,
          expected_revision=document.revision(),
          case_sensitive=state.search.case_sensitive,
        )
      }
      match result {
        Err(_) => { ..state, status: "Could not replace this selection", }
        Ok(count) => {
          let selected = document.selections()[0]
          let next = source_literal_record(
            state,
            document.text(),
            Some(@edit.Range::new(selected.anchor, selected.active)),
          )
          source_pane_commit_active({
            ..next,
            status: "Replaced \{count} matches",
          })
        }
      }
    }
    UndoEdit | RedoEdit => {
      guard source_pane_editable(state) else { return state }
      let history = if msg is UndoEdit {
        state.search.undo
      } else {
        state.search.redo
      }
      guard history.last() is Some(snapshot) else { return state }
      let remaining = history[:history.length() - 1].to_owned()
      let current = { text: state.draft, selection: state.search.selection, }
      let search = if msg is UndoEdit {
        {
          ..state.search,
          selection: snapshot.selection,
          undo: remaining,
          redo: state.search.redo + [current],
        }
      } else {
        {
          ..state.search,
          selection: snapshot.selection,
          redo: remaining,
          undo: state.search.undo + [current],
        }
      }
      source_pane_commit_active({
        ..state,
        draft: snapshot.text,
        search,
        status: if msg is UndoEdit {
          "Undo"
        } else {
          "Redo"
        },
      })
    }
    _ => state
  }
}

///|
extern "js" fn browser_source_selection_coordinate(
  end : Bool,
  column : Bool,
) -> Int32 =
  #| (end, column) => {
  #|   if (typeof document === 'undefined') return -1;
  #|   const editor = document.querySelector('[data-testid="source-editor-input"]');
  #|   if (!editor || typeof editor.selectionStart !== 'number') return -1;
  #|   const before = editor.value.slice(0, end ? editor.selectionEnd : editor.selectionStart);
  #|   const lines = before.split('\n');
  #|   return column ? lines[lines.length - 1].length : lines.length - 1;
  #| }

///|
extern "js" fn browser_source_selection_backwards() -> Bool =
  #| () => typeof document !== 'undefined' && document.querySelector('[data-testid="source-editor-input"]')?.selectionDirection === 'backward'

///|
fn source_literal_capture_selection(state : SourcePaneState) -> SourcePaneState {
  let start_line = browser_source_selection_coordinate(false, false)
  if start_line < 0 {
    return state
  }
  let range = @edit.Range::new(
    @edit.Position::new(
      start_line,
      browser_source_selection_coordinate(false, true),
    ),
    @edit.Position::new(
      browser_source_selection_coordinate(true, false),
      browser_source_selection_coordinate(true, true),
    ),
  )
  if source_literal_document(state).contains_range(range) {
    let selected = if browser_source_selection_backwards() {
      @edit.Range::new(range.end, range.start)
    } else {
      range
    }
    { ..state, search: { ..state.search, selection: Some(selected), }, }
  } else {
    state
  }
}

///|
extern "js" fn browser_source_select_literal(
  sl : Int32,
  sc : Int32,
  el : Int32,
  ec : Int32,
) =
  #| (sl, sc, el, ec) => {
  #|   if (typeof document === 'undefined') return;
  #|   const editor = document.querySelector('[data-testid="source-editor-input"]');
  #|   if (!editor || typeof editor.setSelectionRange !== 'function') return;
  #|   const lines = editor.value.split('\n');
  #|   const offset = (line, column) => lines.slice(0, line).reduce((n, s) => n + s.length + 1, 0) + column;
  #|   editor.focus();
  #|   const start = offset(sl, sc), end = offset(el, ec);
  #|   editor.setSelectionRange(Math.min(start, end), Math.max(start, end), start > end ? 'backward' : 'forward');
  #|   editor.scrollTop = sl * (parseFloat(globalThis.getComputedStyle?.(editor)?.lineHeight) || 20);
  #| }

///|
fn source_literal_selection_cmd(state : SourcePaneState) -> @rabbita.Cmd {
  match state.search.selection {
    Some(range) =>
      @cmd.custom_cmd(
        _ => {
          browser_source_select_literal(
            range.start.line,
            range.start.column,
            range.end.line,
            range.end.column,
          )
        },
        kind=AfterRender,
      )
    None => @rabbita.none
  }
}

///|
fn render_source_literal_search(
  dispatch : Dispatch[Msg],
  source : SourcePaneState,
) -> @rabbita.Html {
  let enabled = source_pane_editable(source)
  let has_matches = enabled && !source_literal_matches(source).is_empty()
  div(class="source-editor-find", [
    @html.label([
      span("Find"),
      input(
        attrs=@html.Attrs::build()
          .data_set("testid", "source-find")
          .aria_label("Find literal text in source file")
          .disabled(!enabled),
        value=source.search.query,
        placeholder="Find literal text",
        on_input=fn(value) { dispatch(SourcePane(FindQuery(value))) },
      ),
    ]),
    button(
      class="secondary-button",
      attrs=@html.Attrs::build().data_set("testid", "source-find-previous"),
      disabled=!has_matches,
      on_click=dispatch(SourcePane(FindPrevious)),
      "Previous",
    ),
    button(
      class="secondary-button",
      attrs=@html.Attrs::build().data_set("testid", "source-find-next"),
      disabled=!has_matches,
      on_click=dispatch(SourcePane(FindNext)),
      "Next",
    ),
    button(
      class="secondary-button",
      attrs=@html.Attrs::build()
        .data_set("testid", "source-match-case")
        .aria_pressed(
          if source.search.case_sensitive {
            "true"
          } else {
            "false"
          },
        )
        .title("Case-insensitive mode folds A-Z; other Unicode is exact"),
      disabled=!enabled,
      on_click=dispatch(
        SourcePane(FindCaseSensitive(!source.search.case_sensitive)),
      ),
      if source.search.case_sensitive {
        "Match case: on"
      } else {
        "Match case: off"
      },
    ),
    span(
      class="source-find-result",
      attrs=@html.Attrs::build()
        .data_set("testid", "source-find-result")
        .aria_live("polite"),
      source_literal_summary(source),
    ),
    @html.label([
      span("Replace"),
      input(
        attrs=@html.Attrs::build()
          .data_set("testid", "source-replacement")
          .aria_label("Literal replacement text")
          .disabled(!enabled),
        value=source.search.replacement,
        placeholder="Replacement text",
        on_input=fn(value) { dispatch(SourcePane(FindReplacement(value))) },
      ),
    ]),
    button(
      class="secondary-button",
      attrs=@html.Attrs::build().data_set("testid", "source-replace-next"),
      disabled=!has_matches,
      on_click=dispatch(SourcePane(ReplaceNext)),
      "Replace next",
    ),
    button(
      class="secondary-button",
      attrs=@html.Attrs::build().data_set("testid", "source-replace-all"),
      disabled=!has_matches,
      on_click=dispatch(SourcePane(ReplaceAll)),
      "Replace all",
    ),
    button(
      class="secondary-button",
      attrs=@html.Attrs::build().data_set("testid", "source-undo"),
      disabled=!enabled || source.search.undo.is_empty(),
      on_click=dispatch(SourcePane(UndoEdit)),
      "Undo",
    ),
    button(
      class="secondary-button",
      attrs=@html.Attrs::build().data_set("testid", "source-redo"),
      disabled=!enabled || source.search.redo.is_empty(),
      on_click=dispatch(SourcePane(RedoEdit)),
      "Redo",
    ),
  ])
}
