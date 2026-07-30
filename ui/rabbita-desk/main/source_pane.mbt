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
  Save
  SaveResult(SourceSaveOutcome)
  ReloadServer
  ReplaceServer
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
  }
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
      } else if source_pane_dirty(state) {
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
      if source_pane_dirty(state) && path != state.requested_path {
        {
          ..state,
          status: "Save or discard the unsaved draft before opening another file",
        }
      } else {
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
        {
          ..state,
          path_input: path,
          requested_path: path,
          request_generation: state.request_generation + 1,
          content,
          status: "",
          server_content: None,
        }
      }
    }
    PreviewResult(identity, result) =>
      if source_pane_is_current(state, identity) {
        match result {
          Ok(preview) =>
            {
              ..state,
              content: Ready(preview),
              baseline: preview.body,
              draft: preview.body,
              server_content: None,
              status: "Ready",
            }
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
    EditDraft(draft) => { ..state, draft, status: "Unsaved changes" }
    Save =>
      if source_pane_dirty(state) {
        { ..state, saving: true, status: "Saving" }
      } else {
        { ..state, status: "No changes to save" }
      }
    SaveResult(outcome) =>
      match outcome {
        SourceSaved(payload) => {
          let saved = json_field_string(payload, "content", default=state.draft)
          {
            ..state,
            baseline: saved,
            draft: saved,
            saving: false,
            server_content: None,
            status: "Saved",
          }
        }
        SourceConflict(current) =>
          {
            ..state,
            saving: false,
            server_content: Some(current),
            status: "File changed after this draft was opened",
          }
        SourceSaveFailed(problem) => { ..state, saving: false, status: problem }
      }
    ReloadServer =>
      match state.server_content {
        Some(current) =>
          {
            ..state,
            baseline: current,
            draft: current,
            server_content: None,
            status: "Reloaded external version",
          }
        None => state
      }
    ReplaceServer =>
      match state.server_content {
        Some(current) =>
          {
            ..state,
            baseline: current,
            saving: true,
            status: "Replacing external version",
          }
        None => state
      }
  }
}
