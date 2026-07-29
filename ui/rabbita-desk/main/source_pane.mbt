///| Feature-owned state for MoonCode's source pane. This foundation deliberately

///| models read-only Source/Preview behavior; it makes no editing or saving

///|
/// promise.
enum SourcePaneContent {
  Empty
  Loading
  Ready(@desk.DeskPreview)
  Unsupported(String)
  Failed(String)
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
  requested_path : String
  request_generation : Int
  content : SourcePaneContent
} derive(Eq, Debug)

///|
enum SourcePaneMsg {
  SetOpen(Bool)
  SetCollapsed(Bool)
  Rebind(String, String)
  RequestSource(String)
  PreviewResult(SourcePaneRequestIdentity, Result[@desk.DeskPreview, String])
  PreviewUnsupported(SourcePaneRequestIdentity, String)
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
    requested_path: "",
    request_generation: 0,
    content: Empty,
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
/// The complete identity is checked so delayed requests cannot cross a rebind.
fn source_pane_is_current(
  state : SourcePaneState,
  identity : SourcePaneRequestIdentity,
) -> Bool {
  identity == source_pane_identity(state)
}

///|
fn source_pane_path_is_unsafe(path : String) -> Bool {
  path.has_prefix("/") ||
  path.has_prefix("\\") ||
  (path.length() >= 2 && path[1] == ':') ||
  path.split("/").any(segment => segment == "..") ||
  path.split("\\").any(segment => segment == "..")
}

///| Pure reducer. RequestSource only selects this feature's requested_path and

///|
/// never mutates the app's selected_path or prompt attachment/context.
fn update_source_pane(
  state : SourcePaneState,
  msg : SourcePaneMsg,
) -> SourcePaneState {
  match msg {
    SetOpen(open) => { ..state, open, }
    SetCollapsed(collapsed) => { ..state, collapsed, }
    Rebind(workspace_id, session_id) =>
      if state.workspace_id == workspace_id && state.session_id == session_id {
        state
      } else {
        {
          ..state,
          workspace_id,
          session_id,
          requested_path: "",
          request_generation: state.request_generation + 1,
          content: Empty,
        }
      }
    RequestSource(path) => {
      let path = path.trim().to_owned()
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
        requested_path: path,
        request_generation: state.request_generation + 1,
        content,
      }
    }
    PreviewResult(identity, result) =>
      if source_pane_is_current(state, identity) {
        match result {
          Ok(preview) => { ..state, content: Ready(preview) }
          Err(problem) => { ..state, content: Failed(problem) }
        }
      } else {
        state
      }
    PreviewUnsupported(identity, reason) =>
      if source_pane_is_current(state, identity) {
        { ..state, content: Unsupported(reason) }
      } else {
        state
      }
  }
}
