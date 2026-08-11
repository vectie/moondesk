///|
enum OfficeEditorKind {
  OfficeDocx
  OfficeXlsx
  OfficePptx
} derive(Eq, Debug)

///|
struct OfficeEditorItem {
  section : String
  reference : String
  section_index : Int
  item_index : Int
  text : String
  formula : String
  bold : Bool
  italic : Bool
  underline : Bool
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
struct OfficeEditorDocument {
  path : String
  kind : OfficeEditorKind
  items : Array[OfficeEditorItem]
  warnings : Array[String]
  baseline : String
} derive(Eq, Debug)

///|
struct OfficeEditorRequestIdentity {
  generation : Int
  workspace_id : String
  path : String
} derive(Eq, Debug)

///|
struct OfficeEditorState {
  workspace_id : String
  path_input : String
  path : String
  request_generation : Int
  document : OfficeEditorDocument?
  draft_items : Array[OfficeEditorItem]
  selected : Int
  loading : Bool
  saving : Bool
  status : String
  saved_baseline : String
  conflict_baseline : String?
} derive(Eq, Debug)

///|
enum OfficeEditorMsg {
  OfficeRebind(String)
  OfficeSetPath(String)
  OfficeOpen
  OfficeOpened(
    OfficeEditorRequestIdentity,
    Result[OfficeEditorDocument, String]
  )
  OfficeSelect(Int)
  OfficeEditText(String)
  OfficeEditFormula(String)
  OfficeToggleBold
  OfficeToggleItalic
  OfficeToggleUnderline
  OfficeEditX(Int)
  OfficeEditY(Int)
  OfficeEditWidth(Int)
  OfficeEditHeight(Int)
  OfficeDiscard
  OfficeSave
  OfficeSaved(OfficeEditorRequestIdentity, Result[OfficeEditorDocument, String])
  OfficeConflict(OfficeEditorRequestIdentity, String)
  OfficeReloadConflict
  OfficeReplaceConflict
  OfficeClose
  OfficeReopen
} derive(Eq, Debug)

///|
fn init_office_editor(workspace_id : String) -> OfficeEditorState {
  {
    workspace_id,
    path_input: "",
    path: "",
    request_generation: 0,
    document: None,
    draft_items: [],
    selected: 0,
    loading: false,
    saving: false,
    status: "",
    saved_baseline: "",
    conflict_baseline: None,
  }
}

///|
fn office_editor_dirty(state : OfficeEditorState) -> Bool {
  match state.document {
    Some(document) => state.draft_items != document.items
    None => false
  }
}

///|
fn office_editor_selected_dirty(state : OfficeEditorState) -> Bool {
  guard state.document is Some(document) else { return false }
  guard state.selected >= 0 &&
    state.selected < state.draft_items.length() &&
    state.selected < document.items.length() else {
    return false
  }
  state.draft_items[state.selected] != document.items[state.selected]
}

///|
fn office_editor_identity(
  state : OfficeEditorState,
) -> OfficeEditorRequestIdentity {
  {
    generation: state.request_generation,
    workspace_id: state.workspace_id,
    path: state.path,
  }
}

///|
fn office_editor_is_current(
  state : OfficeEditorState,
  identity : OfficeEditorRequestIdentity,
) -> Bool {
  identity.generation == state.request_generation &&
  identity.workspace_id == state.workspace_id &&
  identity.path == state.path
}

///|
fn office_editor_path_supported(path : String) -> Bool {
  let lower = path.to_lower()
  lower.has_suffix(".docx") ||
  lower.has_suffix(".xlsx") ||
  lower.has_suffix(".pptx")
}

///|
fn update_office_editor(
  state : OfficeEditorState,
  msg : OfficeEditorMsg,
) -> OfficeEditorState {
  match msg {
    OfficeRebind(workspace_id) =>
      if state.workspace_id == workspace_id {
        state
      } else if office_editor_dirty(state) {
        {
          ..state,
          status: "Save or discard the unsaved Office draft before changing workspace",
        }
      } else {
        {
          ..init_office_editor(workspace_id),
          request_generation: state.request_generation + 1,
        }
      }
    OfficeSetPath(path_input) => { ..state, path_input, }
    OfficeOpen =>
      if office_editor_dirty(state) {
        {
          ..state,
          status: "Save or close the dirty Office draft before opening another document",
        }
      } else if state.loading || state.saving {
        state
      } else if state.workspace_id.trim() == "" {
        { ..state, status: "Select a MoonBook before opening an Office file" }
      } else if state.path_input.trim() == "" {
        { ..state, status: "Enter a DOCX, XLSX, or PPTX workspace path" }
      } else if source_pane_path_is_unsafe(state.path_input.trim().to_owned()) {
        {
          ..state,
          status: "Unsafe Office path: absolute and parent-traversal paths are not allowed",
        }
      } else if !office_editor_path_supported(
          state.path_input.trim().to_owned(),
        ) {
        { ..state, status: "Choose a DOCX, XLSX, or PPTX workspace file" }
      } else {
        {
          ..state,
          path: state.path_input.trim().to_owned(),
          request_generation: state.request_generation + 1,
          loading: true,
          status: "Opening structured Office document...",
        }
      }
    OfficeOpened(identity, result) =>
      if office_editor_is_current(state, identity) {
        match result {
          Ok(document) =>
            {
              ..state,
              path: document.path,
              path_input: document.path,
              document: Some(document),
              draft_items: document.items,
              selected: 0,
              loading: false,
              saved_baseline: document.baseline,
              conflict_baseline: None,
              status: "Opened supported Office subset",
            }
          Err(error) => { ..state, loading: false, status: error }
        }
      } else {
        state
      }
    OfficeSelect(selected) =>
      if selected == state.selected {
        state
      } else if office_editor_selected_dirty(state) {
        {
          ..state,
          status: "Save or discard this Office item before selecting another",
        }
      } else if selected >= 0 && selected < state.draft_items.length() {
        { ..state, selected, }
      } else {
        state
      }
    OfficeEditText(text) =>
      office_editor_update_selected(state, item => { ..item, text, })
    OfficeEditFormula(formula) =>
      office_editor_update_selected(state, item => { ..item, formula, })
    OfficeToggleBold =>
      office_editor_update_selected(state, item => { ..item, bold: !item.bold })
    OfficeToggleItalic =>
      office_editor_update_selected(state, item => {
        ..item,
        italic: !item.italic,
      })
    OfficeToggleUnderline =>
      office_editor_update_selected(state, item => {
        ..item,
        underline: !item.underline,
      })
    OfficeEditX(x) =>
      office_editor_update_selected(state, item => { ..item, x, })
    OfficeEditY(y) =>
      office_editor_update_selected(state, item => { ..item, y, })
    OfficeEditWidth(width) =>
      office_editor_update_selected(state, item => { ..item, width, })
    OfficeEditHeight(height) =>
      office_editor_update_selected(state, item => { ..item, height, })
    OfficeDiscard =>
      match state.document {
        Some(document) if office_editor_dirty(state) =>
          {
            ..state,
            draft_items: document.items,
            conflict_baseline: None,
            status: "Discarded unsaved Office changes",
          }
        _ => state
      }
    OfficeSave =>
      if office_editor_selected_dirty(state) && !state.saving && !state.loading {
        { ..state, saving: true, status: "Saving Office bytes..." }
      } else {
        state
      }
    OfficeSaved(identity, result) =>
      if office_editor_is_current(state, identity) {
        match result {
          Ok(document) =>
            {
              ..state,
              path: document.path,
              path_input: document.path,
              document: Some(document),
              draft_items: document.items,
              selected: if document.items.is_empty() {
                0
              } else if state.selected < document.items.length() {
                state.selected
              } else {
                document.items.length() - 1
              },
              saved_baseline: document.baseline,
              saving: false,
              status: "Saved Office bytes; close and reopen are available",
              conflict_baseline: None,
            }
          Err(error) =>
            {
              ..state,
              saving: false,
              status: error + "; dirty draft preserved",
            }
        }
      } else {
        state
      }
    OfficeConflict(identity, current) =>
      if office_editor_is_current(state, identity) {
        {
          ..state,
          saving: false,
          conflict_baseline: Some(current),
          status: "File changed externally. Reload current bytes or deliberately replace them.",
        }
      } else {
        state
      }
    OfficeReloadConflict =>
      match state.conflict_baseline {
        Some(_) =>
          {
            ..state,
            request_generation: state.request_generation + 1,
            loading: true,
            status: "Reloading current Office bytes; draft remains until reload succeeds...",
          }
        None => state
      }
    OfficeReplaceConflict =>
      match state.conflict_baseline {
        Some(current) =>
          {
            ..state,
            saved_baseline: current,
            conflict_baseline: None,
            saving: true,
            status: "Replacing external Office bytes...",
          }
        None => state
      }
    OfficeClose =>
      if office_editor_dirty(state) {
        { ..state, status: "Save before closing this dirty Office draft" }
      } else {
        {
          ..state,
          document: None,
          draft_items: [],
          selected: 0,
          request_generation: state.request_generation + 1,
          status: "Closed",
        }
      }
    OfficeReopen =>
      if office_editor_dirty(state) {
        { ..state, status: "Save before reopening from disk" }
      } else if state.path == "" || state.loading || state.saving {
        state
      } else {
        {
          ..state,
          request_generation: state.request_generation + 1,
          loading: true,
          status: "Reopening saved Office bytes...",
        }
      }
  }
}

///|
fn office_editor_update_selected(
  state : OfficeEditorState,
  update : (OfficeEditorItem) -> OfficeEditorItem,
) -> OfficeEditorState {
  if state.loading ||
    state.saving ||
    state.document is None ||
    state.selected < 0 ||
    state.selected >= state.draft_items.length() {
    return state
  }
  {
    ..state,
    draft_items: state.draft_items.mapi((index, item) => {
      if index == state.selected {
        update(item)
      } else {
        item
      }
    }),
    status: "Unsaved Office changes",
  }
}

///|
