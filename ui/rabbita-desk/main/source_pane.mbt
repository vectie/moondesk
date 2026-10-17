///|
/// Feature-owned direct editor state for MoonCode's source pane.
enum SourcePaneContent {
  Empty
  Loading
  Ready(@desk.DeskPreview)
  Unsupported(String)
  Failed(String)
} derive(Eq, Debug)

///|
enum SourceSaveOutcome {
  SourceSaved(Json)
  SourceConflict(String)
  SourceSaveFailed(String)
} derive(Eq, Debug)

///|
struct SourcePaneRequestIdentity {
  generation : Int32
  workspace_id : String
  session_id : String
  path : String
} derive(Eq, Debug)

///|
struct SourcePaneSaveRequest {
  generation : Int32
  source : SourcePaneRequestIdentity
  baseline : String
  content : String
} derive(Eq, Debug)

///|
struct SourcePaneBuffer {
  path : String
  content : SourcePaneContent
  baseline : String
  draft : String
  server_content : String?
  status : String
  search : SourceLiteralState
} derive(Eq, Debug)

///|
struct SourcePaneState {
  open : Bool
  collapsed : Bool
  workspace_id : String
  session_id : String
  path_input : String
  requested_path : String
  request_generation : Int32
  content : SourcePaneContent
  baseline : String
  draft : String
  server_content : String?
  saving : Bool
  save_generation : Int32
  pending_save : SourcePaneSaveRequest?
  status : String
  buffers : Array[SourcePaneBuffer]
  search : SourceLiteralState
} derive(Eq, Debug)

///|
#warnings("-unused_constructor")
enum SourcePaneMsg {
  SetOpen(Bool)
  SetCollapsed(Bool)
  SetPathInput(String)
  Rebind(String, String)
  OpenPathInput
  RequestSource(String)
  PreviewResult(SourcePaneRequestIdentity, Result[@desk.DeskPreview, String])
  PreviewUnsupported(SourcePaneRequestIdentity, String)
  EditDraft(String)
  DiscardDraft
  Save
  SaveResult(SourcePaneSaveRequest, SourceSaveOutcome)
  ReloadServer
  ReplaceServer
  SwitchBuffer(String)
  CloseBuffer(String)
  FindQuery(String)
  FindReplacement(String)
  FindCaseSensitive(Bool)
  FindNext
  FindPrevious
  ReplaceNext
  ReplaceAll
  UndoEdit
  RedoEdit
  SelectMarkdownSection(Int32)
  MoveMarkdownSection(Int32, Bool)
  SetLineIndent(@edit.LineIndent)
  IndentLines(Bool)
  DuplicateLines
  EditChecklist(@edit.MarkdownChecklistAction)
  WrapMarkdown(@edit.MarkdownInlineStyle)
  CleanupLines(@edit.LineCleanupAction)
  LayoutJson(@edit.JsonLayout)
  ConvertDelimitedTable(@edit.TableDelimiter)
} derive(Eq, Debug)

///|
fn init_source_pane(
  workspace_id : String,
  session_id : String,
) -> SourcePaneState {
  {
    open: false,
    collapsed: false,
    workspace_id,
    session_id,
    path_input: "",
    requested_path: "",
    request_generation: 0,
    content: Empty,
    baseline: "",
    draft: "",
    server_content: None,
    saving: false,
    save_generation: 0,
    pending_save: None,
    status: "",
    buffers: [],
    search: init_source_literal(),
  }
}

///|
fn source_pane_buffer_index(
  buffers : Array[SourcePaneBuffer],
  path : String,
) -> Int32? {
  for index, buffer in buffers {
    if buffer.path == path {
      return Some(index)
    }
  }
  None
}

///|
fn source_pane_active_buffer(state : SourcePaneState) -> SourcePaneBuffer? {
  if state.requested_path == "" ||
    state.content is Empty ||
    state.content is Loading {
    return None
  }
  Some({
    path: state.requested_path,
    content: state.content,
    baseline: state.baseline,
    draft: state.draft,
    server_content: state.server_content,
    status: state.status,
    search: state.search,
  })
}

///|
fn source_pane_capture_active(
  state : SourcePaneState,
) -> Array[SourcePaneBuffer] {
  guard source_pane_active_buffer(state) is Some(active) else {
    return state.buffers
  }
  match source_pane_buffer_index(state.buffers, active.path) {
    Some(active_index) =>
      state.buffers.mapi((index, buffer) => {
        if index == active_index {
          active
        } else {
          buffer
        }
      })
    None => state.buffers + [active]
  }
}

///|
fn source_pane_commit_active(state : SourcePaneState) -> SourcePaneState {
  { ..state, buffers: source_pane_capture_active(state), }
}

///|
fn source_pane_activate_buffer(
  state : SourcePaneState,
  buffer : SourcePaneBuffer,
) -> SourcePaneState {
  {
    ..state,
    path_input: buffer.path,
    requested_path: buffer.path,
    content: buffer.content,
    baseline: buffer.baseline,
    draft: buffer.draft,
    server_content: buffer.server_content,
    status: buffer.status,
    search: buffer.search,
  }
}

///|
fn source_pane_any_dirty(state : SourcePaneState) -> Bool {
  source_pane_capture_active(state).any(buffer => {
    buffer.draft != buffer.baseline
  })
}

///|
fn source_pane_buffer_dirty(buffer : SourcePaneBuffer) -> Bool {
  buffer.draft != buffer.baseline
}

///|
fn source_pane_identity(state : SourcePaneState) -> SourcePaneRequestIdentity {
  {
    generation: state.request_generation,
    workspace_id: state.workspace_id,
    session_id: state.session_id,
    path: state.requested_path,
  }
}

///|
fn source_pane_is_current(
  state : SourcePaneState,
  identity : SourcePaneRequestIdentity,
) -> Bool {
  identity.generation == state.request_generation &&
  identity.workspace_id == state.workspace_id &&
  identity.path == state.requested_path
}

///|
fn source_pane_dirty(state : SourcePaneState) -> Bool {
  state.draft != state.baseline
}

///|
fn source_pane_begin_save(
  state : SourcePaneState,
  status : String,
) -> SourcePaneState {
  let generation = state.save_generation + 1
  {
    ..state,
    saving: true,
    save_generation: generation,
    pending_save: Some({
      generation,
      source: source_pane_identity(state),
      baseline: state.baseline,
      content: state.draft,
    }),
    status,
  }
}

///|
fn source_pane_editable(state : SourcePaneState) -> Bool {
  state.content is Ready(_) && !state.saving
}

///|
fn source_pane_line_count(state : SourcePaneState) -> Int32 {
  state.draft.split("\n").length()
}

///|
fn source_pane_line_numbers(state : SourcePaneState) -> String {
  let lines : Array[String] = []
  for line in 1..<=source_pane_line_count(state) {
    lines.push(line.to_string())
  }
  lines.join("\n")
}

///|
fn source_pane_language_label(state : SourcePaneState) -> String {
  let path = state.requested_path.to_lower()
  if path.has_suffix(".mbt") || path.has_suffix(".mbti") {
    "MoonBit"
  } else if path.has_suffix(".md") || path.has_suffix(".mdx") {
    "Markdown"
  } else if path.has_suffix(".json") {
    "JSON"
  } else if path.has_suffix(".js") || path.has_suffix(".mjs") {
    "JavaScript"
  } else if path.has_suffix(".ts") || path.has_suffix(".tsx") {
    "TypeScript"
  } else if path.has_suffix(".css") {
    "CSS"
  } else if path.has_suffix(".html") || path.has_suffix(".htm") {
    "HTML"
  } else if path.has_suffix(".py") {
    "Python"
  } else if path.has_suffix(".sh") || path.has_suffix(".zsh") {
    "Shell"
  } else {
    "Plain text"
  }
}

///|
fn source_pane_path_is_unsafe(path : String) -> Bool {
  path.has_prefix("/") ||
  path.has_prefix("\\") ||
  (path.length() >= 2 && path[1] == ':') ||
  path.split("/").any(segment => segment == "..") ||
  path.split("\\").any(segment => segment == "..")
}

///|
fn update_source_pane(
  state : SourcePaneState,
  msg : SourcePaneMsg,
) -> SourcePaneState {
  match msg {
    ConvertDelimitedTable(delimiter) =>
      update_source_table_import(state, delimiter)
    SetLineIndent(_)
    | IndentLines(_)
    | DuplicateLines
    | EditChecklist(_)
    | WrapMarkdown(_) => update_source_line_authoring(state, msg)
    CleanupLines(action) => update_source_line_cleanup(state, action)
    LayoutJson(layout) => update_source_json_layout(state, layout)
    SelectMarkdownSection(_) | MoveMarkdownSection(_, _) =>
      update_source_outline(state, msg)
    FindQuery(_)
    | FindReplacement(_)
    | FindCaseSensitive(_)
    | FindNext
    | FindPrevious
    | ReplaceNext
    | ReplaceAll
    | UndoEdit
    | RedoEdit => update_source_literal(state, msg)
    SetOpen(open) => { ..state, open, }
    SetCollapsed(collapsed) => { ..state, collapsed, }
    SetPathInput(path_input) => { ..state, path_input, }
    Rebind(workspace_id, session_id) =>
      if state.workspace_id == workspace_id {
        { ..state, session_id, }
      } else if state.saving || source_pane_any_dirty(state) {
        {
          ..state,
          status: "Save or discard the unsaved draft before changing workspace",
        }
      } else {
        let reset = init_source_pane(workspace_id, session_id)
        {
          ..reset,
          open: state.open,
          collapsed: state.collapsed,
          request_generation: state.request_generation + 1,
          save_generation: state.save_generation,
        }
      }
    OpenPathInput => update_source_pane(state, RequestSource(state.path_input))
    RequestSource(path) => {
      guard !state.saving else {
        {
          ..state,
          status: "Wait for the current save before opening another file",
        }
      }
      let path = path.trim().to_owned()
      let buffers = source_pane_capture_active(state)
      match source_pane_buffer_index(buffers, path) {
        Some(index) if path != "" =>
          source_pane_activate_buffer({ ..state, buffers, }, buffers[index])
        _ => {
          let content = if path == "" {
            Empty
          } else if state.workspace_id.trim() == "" {
            Failed("Cannot load source without workspace authority")
          } else if source_pane_path_is_unsafe(path) {
            Failed(
              "Unsafe source path: absolute and parent-traversal paths are not allowed",
            )
          } else {
            Loading
          }
          let status = match content {
            Failed(problem) => problem
            _ => ""
          }
          {
            ..state,
            path_input: path,
            requested_path: path,
            request_generation: state.request_generation + 1,
            content,
            baseline: "",
            draft: "",
            status,
            server_content: None,
            buffers,
            search: init_source_literal(),
          }
        }
      }
    }
    PreviewResult(identity, result) =>
      if !state.saving && source_pane_is_current(state, identity) {
        match result {
          Ok(preview) =>
            source_pane_commit_active({
              ..state,
              content: Ready(preview),
              baseline: preview.body,
              draft: preview.body,
              server_content: None,
              status: "Ready",
              search: init_source_literal(),
            })
          Err(problem) =>
            { ..state, content: Failed(problem), status: problem, }
        }
      } else {
        state
      }
    PreviewUnsupported(identity, reason) =>
      if !state.saving && source_pane_is_current(state, identity) {
        { ..state, content: Unsupported(reason), status: reason, }
      } else {
        state
      }
    EditDraft(draft) =>
      if source_pane_editable(state) {
        source_pane_commit_active(source_literal_record(state, draft, None))
      } else {
        state
      }
    DiscardDraft =>
      if !state.saving && source_pane_dirty(state) {
        source_pane_commit_active({
          ..state,
          draft: state.baseline,
          server_content: None,
          status: "Discarded unsaved source changes",
          search: init_source_literal(),
        })
      } else {
        state
      }
    Save =>
      if state.saving {
        state
      } else if source_pane_dirty(state) && source_pane_editable(state) {
        source_pane_begin_save(state, "Saving")
      } else {
        { ..state, status: "No changes to save", }
      }
    SaveResult(request, outcome) => {
      guard state.saving &&
        state.pending_save == Some(request) &&
        source_pane_is_current(state, request.source) else {
        return state
      }
      match outcome {
        SourceSaved(payload) => {
          let saved = json_field_string(
            payload,
            "content",
            default=request.content,
          )
          let newer_draft = state.draft != request.content
          source_pane_commit_active({
            ..state,
            baseline: saved,
            draft: if newer_draft {
              state.draft
            } else {
              saved
            },
            saving: false,
            pending_save: None,
            server_content: None,
            status: if newer_draft {
              "Saved earlier edit; newer changes are unsaved"
            } else {
              "Saved"
            },
          })
        }
        SourceConflict(current) =>
          source_pane_commit_active({
            ..state,
            saving: false,
            pending_save: None,
            server_content: Some(current),
            status: "File changed after this draft was opened",
          })
        SourceSaveFailed(problem) =>
          { ..state, saving: false, pending_save: None, status: problem, }
      }
    }
    ReloadServer => {
      guard !state.saving else { return state }
      match state.server_content {
        Some(current) =>
          source_pane_commit_active({
            ..state,
            baseline: current,
            draft: current,
            server_content: None,
            status: "Reloaded external version",
            search: init_source_literal(),
          })
        None => state
      }
    }
    ReplaceServer => {
      guard !state.saving else { return state }
      match state.server_content {
        Some(current) =>
          source_pane_commit_active(
            source_pane_begin_save(
              { ..state, baseline: current, },
              "Replacing external version",
            ),
          )
        None => state
      }
    }
    SwitchBuffer(path) => {
      guard !state.saving else {
        { ..state, status: "Wait for the current save before switching tabs", }
      }
      let buffers = source_pane_capture_active(state)
      match source_pane_buffer_index(buffers, path) {
        Some(index) =>
          source_pane_activate_buffer({ ..state, buffers, }, buffers[index])
        None => state
      }
    }
    CloseBuffer(path) => {
      guard !state.saving else {
        { ..state, status: "Wait for the current save before closing tabs", }
      }
      let buffers = source_pane_capture_active(state)
      guard source_pane_buffer_index(buffers, path) is Some(index) else {
        state
      }
      if buffers[index].draft != buffers[index].baseline {
        {
          ..state,
          status: "Save or discard the modified tab before closing it",
        }
      } else {
        let remaining = buffers.filter(buffer => buffer.path != path)
        if state.requested_path != path {
          { ..state, buffers: remaining, }
        } else if remaining is [next, ..] {
          source_pane_activate_buffer({ ..state, buffers: remaining, }, next)
        } else {
          {
            ..state,
            path_input: "",
            requested_path: "",
            content: Empty,
            baseline: "",
            draft: "",
            server_content: None,
            status: "Closed source tab",
            search: init_source_literal(),
            buffers: [],
          }
        }
      }
    }
  }
}
