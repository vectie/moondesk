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
  generation : Int
  workspace_id : String
  session_id : String
  path : String
} derive(Eq, Debug)

///|
struct SourcePaneBuffer {
  path : String
  content : SourcePaneContent
  baseline : String
  draft : String
  server_content : String?
  status : String
} derive(Eq, Debug)

///|
struct SourcePaneState {
  open : Bool
  collapsed : Bool
  workspace_id : String
  session_id : String
  path_input : String
  requested_path : String
  request_generation : Int
  content : SourcePaneContent
  baseline : String
  draft : String
  server_content : String?
  saving : Bool
  status : String
  buffers : Array[SourcePaneBuffer]
} derive(Eq, Debug)

///|
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
  SaveResult(SourceSaveOutcome)
  ReloadServer
  ReplaceServer
  SwitchBuffer(String)
  CloseBuffer(String)
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
    status: "",
    buffers: [],
  }
}

///|
fn source_pane_buffer_index(
  buffers : Array[SourcePaneBuffer],
  path : String,
) -> Int? {
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
    state.content is SourcePaneContent::Loading {
    return None
  }
  Some({
    path: state.requested_path,
    content: state.content,
    baseline: state.baseline,
    draft: state.draft,
    server_content: state.server_content,
    status: state.status,
  })
}

///|
fn source_pane_capture_active(state : SourcePaneState) -> Array[SourcePaneBuffer] {
  guard source_pane_active_buffer(state) is Some(active) else {
    return state.buffers
  }
  match source_pane_buffer_index(state.buffers, active.path) {
    Some(active_index) =>
      state.buffers.mapi((index, buffer) =>
        if index == active_index { active } else { buffer }
      )
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
  }
}

///|
fn source_pane_any_dirty(state : SourcePaneState) -> Bool {
  source_pane_capture_active(state).any(buffer =>
    buffer.draft != buffer.baseline
  )
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
fn source_pane_editable(state : SourcePaneState) -> Bool {
  state.content is Ready(_) && !state.saving
}

///|
fn source_pane_line_count(state : SourcePaneState) -> Int {
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
    SetOpen(open) => { ..state, open, }
    SetCollapsed(collapsed) => { ..state, collapsed, }
    SetPathInput(path_input) => { ..state, path_input, }
    Rebind(workspace_id, session_id) =>
      if state.workspace_id == workspace_id {
        { ..state, session_id, }
      } else if source_pane_any_dirty(state) {
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
        }
      }
    OpenPathInput => update_source_pane(state, RequestSource(state.path_input))
    RequestSource(path) => {
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
          }
        }
      }
    }
    PreviewResult(identity, result) =>
      if source_pane_is_current(state, identity) {
        match result {
          Ok(preview) =>
            source_pane_commit_active({
              ..state,
              content: Ready(preview),
              baseline: preview.body,
              draft: preview.body,
              server_content: None,
              status: "Ready",
            })
          Err(problem) => { ..state, content: Failed(problem), status: problem }
        }
      } else {
        state
      }
    PreviewUnsupported(identity, reason) =>
      if source_pane_is_current(state, identity) {
        { ..state, content: Unsupported(reason), status: reason }
      } else {
        state
      }
    EditDraft(draft) =>
      if source_pane_editable(state) {
        source_pane_commit_active({
          ..state,
          draft,
          status: "Unsaved changes",
        })
      } else {
        state
      }
    DiscardDraft =>
      if source_pane_dirty(state) {
        source_pane_commit_active({
          ..state,
          draft: state.baseline,
          server_content: None,
          status: "Discarded unsaved source changes",
        })
      } else {
        state
      }
    Save =>
      if source_pane_dirty(state) && source_pane_editable(state) {
        { ..state, saving: true, status: "Saving" }
      } else {
        { ..state, status: "No changes to save" }
      }
    SaveResult(outcome) =>
      match outcome {
        SourceSaved(payload) => {
          let saved = json_field_string(payload, "content", default=state.draft)
          source_pane_commit_active({
            ..state,
            baseline: saved,
            draft: saved,
            saving: false,
            server_content: None,
            status: "Saved",
          })
        }
        SourceConflict(current) =>
          source_pane_commit_active({
            ..state,
            saving: false,
            server_content: Some(current),
            status: "File changed after this draft was opened",
          })
        SourceSaveFailed(problem) => { ..state, saving: false, status: problem }
      }
    ReloadServer =>
      match state.server_content {
        Some(current) =>
          source_pane_commit_active({
            ..state,
            baseline: current,
            draft: current,
            server_content: None,
            status: "Reloaded external version",
          })
        None => state
      }
    ReplaceServer =>
      match state.server_content {
        Some(current) =>
          source_pane_commit_active({
            ..state,
            baseline: current,
            saving: true,
            status: "Replacing external version",
          })
        None => state
      }
    SwitchBuffer(path) => {
      guard !state.saving else {
        { ..state, status: "Wait for the current save before switching tabs" }
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
        { ..state, status: "Wait for the current save before closing tabs" }
      }
      let buffers = source_pane_capture_active(state)
      guard source_pane_buffer_index(buffers, path) is Some(index) else {
        state
      }
      if buffers[index].draft != buffers[index].baseline {
        { ..state, status: "Save or discard the modified tab before closing it" }
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
            buffers: [],
          }
        }
      }
    }
  }
}
