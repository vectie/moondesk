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
struct OfficeEditorState {
  workspace_id : String
  path_input : String
  path : String
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
  OfficeSetPath(String)
  OfficeOpen
  OfficeOpened(Result[OfficeEditorDocument, String])
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
  OfficeSave
  OfficeSaved(Result[OfficeEditorDocument, String])
  OfficeConflict(String)
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
fn update_office_editor(
  state : OfficeEditorState,
  msg : OfficeEditorMsg,
) -> OfficeEditorState {
  match msg {
    OfficeSetPath(path_input) => { ..state, path_input, }
    OfficeOpen =>
      if office_editor_dirty(state) {
        {
          ..state,
          status: "Save or close the dirty Office draft before opening another document",
        }
      } else if state.path_input.trim() == "" {
        { ..state, status: "Enter a DOCX, XLSX, or PPTX workspace path" }
      } else {
        {
          ..state,
          path: state.path_input.trim().to_owned(),
          loading: true,
          status: "Opening structured Office document...",
        }
      }
    OfficeOpened(result) =>
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
    OfficeSelect(selected) =>
      if selected >= 0 && selected < state.draft_items.length() {
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
    OfficeSave =>
      if office_editor_dirty(state) && !state.saving {
        { ..state, saving: true, status: "Saving Office bytes..." }
      } else {
        state
      }
    OfficeSaved(result) =>
      match result {
        Ok(document) =>
          {
            ..state,
            document: Some(document),
            draft_items: document.items,
            saved_baseline: document.baseline,
            saving: false,
            status: "Saved Office bytes; close and reopen are available",
            conflict_baseline: None,
          }
        Err(error) =>
          { ..state, saving: false, status: error + "; dirty draft preserved" }
      }
    OfficeConflict(current) =>
      {
        ..state,
        saving: false,
        conflict_baseline: Some(current),
        status: "File changed externally. Reload current bytes or deliberately replace them.",
      }
    OfficeReloadConflict =>
      match state.conflict_baseline {
        Some(_) =>
          {
            ..state,
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
          status: "Closed",
        }
      }
    OfficeReopen =>
      if office_editor_dirty(state) {
        { ..state, status: "Save before reopening from disk" }
      } else {
        { ..state, loading: true, status: "Reopening saved Office bytes..." }
      }
  }
}

///|
fn office_editor_update_selected(
  state : OfficeEditorState,
  update : (OfficeEditorItem) -> OfficeEditorItem,
) -> OfficeEditorState {
  if state.selected < 0 || state.selected >= state.draft_items.length() {
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
