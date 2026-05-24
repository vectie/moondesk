///|
using @html {
  a,
  aside,
  button,
  code,
  div,
  h1,
  h2,
  h3,
  header,
  iframe,
  img,
  input,
  li,
  main_,
  p,
  pre,
  section,
  small,
  span,
  strong,
  textarea,
  ul,
}

///|
using @rabbita {type Dispatch}

///|
enum Activity {
  Explorer
  Search
  Inbox
  Town
  Runs
  Settings
} derive(Eq)

///|
struct ActivityButton {
  key : Activity
  icon : String
  label : String
}

///|
struct PreviewTab {
  title : String
  path : String
  renderer : @desk.PreviewRenderer
}

///|
struct TownMessage {
  id : String
  path : String
  title : String
  kind : String
} derive(FromJson)

///|
struct RequestRecord {
  id : String
  status : String
  path : String
  request : Json
} derive(FromJson)

///|
struct InboxCreated {
  ok : Bool
  workspace_id : String
  path : String
} derive(FromJson)

///|
struct SearchHit {
  workspace_id : String
  workspace_name : String
  path : String
  title : String
  kind : @desk.EntryKind
  source_layer : @desk.SourceLayer
  snippet : String
} derive(FromJson)

///|
struct Model {
  activity : Activity
  command_open : Bool
  loading : Bool
  host_status : String
  workspaces : Array[@desk.DeskWorkspace]
  selected_workspace_id : String
  current_directory : String
  entries : Array[@desk.DeskFileEntry]
  selected_path : String
  preview : @desk.DeskPreview?
  preview_status : String
  request_prompt : String
  request_status : String
  requests : Array[RequestRecord]
  town_messages : Array[TownMessage]
  runs : Array[@desk.DeskRunProjection]
  inbox_title : String
  inbox_content : String
  editing_inbox_path : String
  inbox_status : String
  search_query : String
  search_status : String
  search_hits : Array[SearchHit]
  favorites : Array[String]
  recent_paths : Array[String]
  notification_status : String
}

///|
enum Msg {
  LoadedWorkspaces(Result[Array[@desk.DeskWorkspace], String])
  LoadedEntries(Result[Array[@desk.DeskFileEntry], String])
  LoadedPreview(Result[@desk.DeskPreview, String])
  LoadedRuns(Result[Array[@desk.DeskRunProjection], String])
  LoadedTownMessages(Result[Array[TownMessage], String])
  LoadedRequests(Result[Array[RequestRecord], String])
  LoadedSearch(Result[Array[SearchHit], String])
  SavedInbox(Result[InboxCreated, String])
  SubmittedRequest(Result[RequestRecord, String])
  SelectActivity(Activity)
  SelectWorkspace(String)
  SelectPath(String)
  OpenDirectory(String)
  OpenQuickPath(String)
  SelectSearchHit(String, String)
  ToggleCommand
  SetRequestPrompt(String)
  SubmitRequest
  SetInboxTitle(String)
  SetInboxContent(String)
  LoadSelectionIntoInbox
  SaveInboxNote
  StageSelectedLink
  SetSearchQuery(String)
  SearchNow
  ToggleFavorite(String)
  NotifyDaily
  RefreshAll
}

///|
fn init_model() -> Model {
  {
    activity: Activity::Explorer,
    command_open: false,
    loading: true,
    host_status: "connecting to local host",
    workspaces: [],
    selected_workspace_id: "",
    current_directory: "",
    entries: [],
    selected_path: "wiki/index.md",
    preview: None,
    preview_status: "waiting for workspace",
    request_prompt: "Analyze the selected context and propose source-backed updates for this MoonBook.",
    request_status: "draft",
    requests: [],
    town_messages: [],
    runs: [],
    inbox_title: "Operator note",
    inbox_content: "",
    editing_inbox_path: "",
    inbox_status: "draft",
    search_query: "",
    search_status: "enter a query",
    search_hits: [],
    favorites: [],
    recent_paths: [],
    notification_status: "notifications idle",
  }
}

///|
fn activities() -> Array[ActivityButton] {
  [
    { key: Activity::Explorer, icon: "F", label: "Explorer" },
    { key: Activity::Search, icon: "S", label: "Search" },
    { key: Activity::Inbox, icon: "I", label: "Inbox" },
    { key: Activity::Town, icon: "T", label: "Town" },
    { key: Activity::Runs, icon: "R", label: "Runs" },
    { key: Activity::Settings, icon: "G", label: "Settings" },
  ]
}

///|
fn first_workspace_id(workspaces : Array[@desk.DeskWorkspace]) -> String {
  match workspaces {
    [workspace, ..] => workspace.id
    [] => ""
  }
}

///|
fn has_workspace(workspaces : Array[@desk.DeskWorkspace], id : String) -> Bool {
  for workspace in workspaces {
    if workspace.id == id {
      return true
    }
  }
  false
}

///|
fn workspace_name(model : Model) -> String {
  for workspace in model.workspaces {
    if workspace.id == model.selected_workspace_id {
      return workspace.name
    }
  }
  "No workspace"
}

///|
fn workspace_root(model : Model) -> String {
  for workspace in model.workspaces {
    if workspace.id == model.selected_workspace_id {
      return workspace.root_path
    }
  }
  "not connected"
}

///|
fn find_entry(model : Model, path : String) -> @desk.DeskFileEntry? {
  for entry in model.entries {
    if entry.path == path {
      return Some(entry)
    }
  }
  None
}

///|
fn selected_layer(model : Model) -> String {
  match find_entry(model, model.selected_path) {
    Some(entry) => layer_label(entry.source_layer)
    None => match model.preview {
      Some(preview) => renderer_label(preview.renderer)
      None => "unknown"
    }
  }
}

///|
fn is_inbox_path(path : String) -> Bool {
  path == "inbox" || path.has_prefix("inbox/")
}

///|
fn is_textual_renderer(renderer : @desk.PreviewRenderer) -> Bool {
  match renderer {
    @desk.PreviewRenderer::Markdown
    | @desk.PreviewRenderer::Json
    | @desk.PreviewRenderer::Text
    | @desk.PreviewRenderer::ArtifactSummary
    | @desk.PreviewRenderer::DirectoryListing
    | @desk.PreviewRenderer::Unsupported => true
    _ => false
  }
}

///|
fn remember_path(paths : Array[String], path : String) -> Array[String] {
  if path == "" {
    return paths
  }
  let next : Array[String] = [path]
  for item in paths {
    if item != path && next.length() < 8 {
      next.push(item)
    }
  }
  next
}

///|
fn has_string(items : Array[String], value : String) -> Bool {
  for item in items {
    if item == value {
      return true
    }
  }
  false
}

///|
fn toggle_string(items : Array[String], value : String) -> Array[String] {
  let next : Array[String] = []
  if has_string(items, value) {
    for item in items {
      if item != value {
        next.push(item)
      }
    }
  } else {
    for item in items {
      next.push(item)
    }
    next.push(value)
  }
  next
}

///|
fn json_string_array(items : Array[String]) -> Json {
  let values : Array[Json] = []
  for item in items {
    values.push(item.to_json())
  }
  Json::array(values)
}

///|
fn json_field_string(json : Json, key : String, default~ : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::String(value)) => value
        _ => default
      }
    _ => default
  }
}

///|
fn request_title(record : RequestRecord) -> String {
  json_field_string(record.request, "title", default="Moondesk request")
}

///|
fn trimmed_or(value : String, fallback : String) -> String {
  let value = value.trim().to_owned()
  if value == "" { fallback } else { value }
}

///|
fn raw_url(model : Model, path : String) -> String {
  if model.selected_workspace_id == "" {
    "#"
  } else {
    "/api/workspaces/\{model.selected_workspace_id}/raw?path=\{encode_component(path)}"
  }
}

///|
fn workspace_entries_url(workspace_id : String, path : String) -> String {
  "/api/workspaces/\{workspace_id}/entries?path=\{encode_component(path)}"
}

///|
fn workspace_preview_url(workspace_id : String, path : String) -> String {
  "/api/workspaces/\{workspace_id}/preview?path=\{encode_component(path)}"
}

///|
#cfg(target="js")
extern "js" fn encode_component(text : String) -> String =
  "(text)=>encodeURIComponent(text)"

///|
#cfg(target="js")
extern "js" fn send_browser_notification(title : String, body : String) =
  #| (title, body) => {
  #|   if (!("Notification" in window)) return;
  #|   const show = () => new Notification(title, { body });
  #|   if (Notification.permission === "granted") {
  #|     show();
  #|   } else if (Notification.permission !== "denied") {
  #|     Notification.requestPermission().then(permission => {
  #|       if (permission === "granted") show();
  #|     });
  #|   }
  #| }

///|
fn notify_cmd(title : String, body : String) -> @rabbita.Cmd {
  @cmd.raw_effect(_ => send_browser_notification(title, body), kind=@cmd.after_render)
}

///|
fn fetch_workspaces_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/workspaces",
    expect=@http.Json(fn(result) { dispatch(LoadedWorkspaces(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid workspace registry")
      }
    }),
  )
}

///|
fn fetch_entries_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
  path : String,
) -> @rabbita.Cmd {
  @http.get(
    workspace_entries_url(workspace_id, path),
    expect=@http.Json(fn(result) { dispatch(LoadedEntries(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid entry listing")
      }
    }),
  )
}

///|
fn fetch_preview_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
  path : String,
) -> @rabbita.Cmd {
  @http.get(
    workspace_preview_url(workspace_id, path),
    expect=@http.Json(fn(result) { dispatch(LoadedPreview(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Preview is not available")
      }
    }),
  )
}

///|
fn fetch_runs_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/moonclaw/runs?workspace=\{encode_component(workspace_id)}",
    expect=@http.Json(fn(result) { dispatch(LoadedRuns(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonClaw run listing")
      }
    }),
  )
}

///|
fn fetch_messages_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/messages",
    expect=@http.Json(fn(result) { dispatch(LoadedTownMessages(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid town message stream")
      }
    }),
  )
}

///|
fn fetch_requests_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/requests",
    expect=@http.Json(fn(result) { dispatch(LoadedRequests(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid request ledger")
      }
    }),
  )
}

///|
fn fetch_search_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  query : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/search?query=\{encode_component(query)}",
    expect=@http.Json(fn(result) { dispatch(LoadedSearch(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid search results")
      }
    }),
  )
}

///|
fn save_inbox_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
  title : String,
  content : String,
) -> @rabbita.Cmd {
  let body : Json = if model.editing_inbox_path == "" {
    { "title": title, "content": content }
  } else {
    { "title": title, "content": content, "path": model.editing_inbox_path }
  }
  @http.post(
    "/api/workspaces/\{model.selected_workspace_id}/inbox",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) { dispatch(SavedInbox(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not save inbox note")
      }
    }),
  )
}

///|
fn submit_request_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let title = "Moondesk request for \{workspace_name(model)}"
  let context_entries = if model.selected_path == "" {
    []
  } else {
    [model.selected_path]
  }
  let body : Json = {
    "title": title,
    "prompt": trimmed_or(model.request_prompt, "Review the selected context."),
    "target_book_id": model.selected_workspace_id,
    "context_entries": json_string_array(context_entries),
    "cadence": "one-shot",
    "quality_threshold": 85,
    "source_policy": "mixed",
  }
  @http.post(
    "/api/town/requests",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) { dispatch(SubmittedRequest(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not stage request")
      }
    }),
  )
}

///|
fn reload_workspace_cmds(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
  selected_path : String,
) -> @rabbita.Cmd {
  if workspace_id == "" {
    @rabbita.none
  } else {
    @rabbita.batch([
      fetch_entries_cmd(dispatch, workspace_id, ""),
      fetch_preview_cmd(dispatch, workspace_id, selected_path),
      fetch_runs_cmd(dispatch, workspace_id),
      fetch_messages_cmd(dispatch),
      fetch_requests_cmd(dispatch),
    ])
  }
}

///|
fn update(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedWorkspaces(Ok(workspaces)) => {
      let selected_workspace_id = if has_workspace(
        workspaces,
        model.selected_workspace_id,
      ) {
        model.selected_workspace_id
      } else {
        first_workspace_id(workspaces)
      }
      let selected_path = if model.selected_path == "" {
        "wiki/index.md"
      } else {
        model.selected_path
      }
      (
        reload_workspace_cmds(dispatch, selected_workspace_id, selected_path),
        {
          ..model,
          loading: false,
          host_status: "local host ready",
          workspaces,
          selected_workspace_id,
          selected_path,
          preview_status: "loading preview",
        },
      )
    }
    LoadedWorkspaces(Err(error)) =>
      (
        @rabbita.none,
        { ..model, loading: false, host_status: error, preview_status: error },
      )
    LoadedEntries(Ok(entries)) =>
      (@rabbita.none, { ..model, entries, host_status: "workspace indexed" })
    LoadedEntries(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedPreview(Ok(preview)) =>
      (
        @rabbita.none,
        {
          ..model,
          preview: Some(preview),
          preview_status: "preview ready",
          recent_paths: remember_path(model.recent_paths, model.selected_path),
          inbox_content: if model.editing_inbox_path == model.selected_path &&
            is_textual_renderer(preview.renderer) {
            preview.body
          } else {
            model.inbox_content
          },
        },
      )
    LoadedPreview(Err(error)) =>
      (@rabbita.none, { ..model, preview: None, preview_status: error })
    LoadedRuns(Ok(runs)) => (@rabbita.none, { ..model, runs })
    LoadedRuns(Err(error)) => (@rabbita.none, { ..model, host_status: error })
    LoadedTownMessages(Ok(town_messages)) =>
      (@rabbita.none, { ..model, town_messages })
    LoadedTownMessages(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedRequests(Ok(requests)) => (@rabbita.none, { ..model, requests })
    LoadedRequests(Err(error)) =>
      (@rabbita.none, { ..model, request_status: error })
    LoadedSearch(Ok(search_hits)) =>
      (
        @rabbita.none,
        {
          ..model,
          search_hits,
          search_status: "\{search_hits.length()} results",
        },
      )
    LoadedSearch(Err(error)) =>
      (@rabbita.none, { ..model, search_status: error })
    SavedInbox(Ok(created)) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, created.workspace_id, "inbox"),
          fetch_preview_cmd(dispatch, created.workspace_id, created.path),
        ]),
        {
          ..model,
          activity: Activity::Inbox,
          current_directory: "inbox",
          selected_workspace_id: created.workspace_id,
          selected_path: created.path,
          editing_inbox_path: created.path,
          inbox_status: if created.ok { "saved \{created.path}" } else { "save returned without ok" },
          preview_status: "loading saved note",
        },
      )
    SavedInbox(Err(error)) =>
      (@rabbita.none, { ..model, inbox_status: error })
    SubmittedRequest(Ok(record)) =>
      (
        @rabbita.batch([fetch_requests_cmd(dispatch), fetch_messages_cmd(dispatch)]),
        {
          ..model,
          activity: Activity::Town,
          request_status: "staged \{record.id}",
          command_open: false,
        },
      )
    SubmittedRequest(Err(error)) =>
      (@rabbita.none, { ..model, request_status: error })
    SelectActivity(activity) => (@rabbita.none, { ..model, activity })
    SelectWorkspace(workspace_id) =>
      (
        reload_workspace_cmds(dispatch, workspace_id, "wiki/index.md"),
        {
          ..model,
          selected_workspace_id: workspace_id,
          selected_path: "wiki/index.md",
          current_directory: "",
          preview: None,
          preview_status: "loading preview",
          entries: [],
        },
      )
    SelectPath(path) => {
      let is_directory = match find_entry(model, path) {
        Some(entry) => entry.kind is @desk.EntryKind::Directory
        None => false
      }
      let cmd = if is_directory {
        @rabbita.batch([
          fetch_entries_cmd(dispatch, model.selected_workspace_id, path),
          fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
        ])
      } else {
        fetch_preview_cmd(dispatch, model.selected_workspace_id, path)
      }
      (
        cmd,
        {
          ..model,
          selected_path: path,
          current_directory: if is_directory { path } else { model.current_directory },
          preview: None,
          preview_status: "loading preview",
          editing_inbox_path: if is_inbox_path(path) {
            path
          } else {
            model.editing_inbox_path
          },
        },
      )
    }
    OpenDirectory(path) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, model.selected_workspace_id, path),
          fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
        ]),
        {
          ..model,
          current_directory: path,
          selected_path: path,
          preview: None,
          preview_status: "loading directory",
        },
      )
    OpenQuickPath(path) =>
      (
        fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
        {
          ..model,
          selected_path: path,
          preview: None,
          preview_status: "loading preview",
        },
      )
    SelectSearchHit(workspace_id, path) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, workspace_id, ""),
          fetch_preview_cmd(dispatch, workspace_id, path),
          fetch_runs_cmd(dispatch, workspace_id),
        ]),
        {
          ..model,
          activity: Activity::Explorer,
          selected_workspace_id: workspace_id,
          selected_path: path,
          current_directory: "",
          preview: None,
          preview_status: "loading search result",
        },
      )
    ToggleCommand =>
      (@rabbita.none, { ..model, command_open: !model.command_open })
    SetRequestPrompt(prompt) =>
      (
        @rabbita.none,
        { ..model, request_prompt: prompt, request_status: "draft" },
      )
    SubmitRequest =>
      (
        submit_request_cmd(dispatch, model),
        { ..model, request_status: "staging request" },
      )
    SetInboxTitle(title) => (@rabbita.none, { ..model, inbox_title: title })
    SetInboxContent(content) =>
      (@rabbita.none, { ..model, inbox_content: content, inbox_status: "draft" })
    LoadSelectionIntoInbox => {
      let content = match model.preview {
        Some(preview) if is_textual_renderer(preview.renderer) => preview.body
        _ => model.inbox_content
      }
      (
        @rabbita.none,
        {
          ..model,
          activity: Activity::Inbox,
          inbox_title: @desk.display_name(model.selected_path),
          inbox_content: content,
          editing_inbox_path: if is_inbox_path(model.selected_path) {
            model.selected_path
          } else {
            ""
          },
          inbox_status: if is_inbox_path(model.selected_path) {
            "editing \{model.selected_path}"
          } else {
            "copied selected preview into a new inbox draft"
          },
        },
      )
    }
    SaveInboxNote => {
      let title = trimmed_or(model.inbox_title, "Moondesk inbox note")
      let content = trimmed_or(model.inbox_content, "Empty operator note.")
      (
        save_inbox_cmd(dispatch, model, title, content),
        { ..model, inbox_status: "saving inbox note" },
      )
    }
    StageSelectedLink => {
      let title = "Context link - \{@desk.display_name(model.selected_path)}"
      let content = "Linked Moondesk context\n\n" +
        "- Workspace: \{workspace_name(model)}\n" +
        "- Path: \{model.selected_path}\n" +
        "- Layer: \{selected_layer(model)}\n"
      (
        save_inbox_cmd(dispatch, { ..model, editing_inbox_path: "" }, title, content),
        { ..model, inbox_status: "copying selection to inbox" },
      )
    }
    SetSearchQuery(query) =>
      (@rabbita.none, { ..model, search_query: query, search_status: "draft" })
    SearchNow => {
      let query = model.search_query.trim().to_owned()
      if query == "" {
        (@rabbita.none, { ..model, search_status: "enter a query" })
      } else {
        (
          fetch_search_cmd(dispatch, query),
          { ..model, activity: Activity::Search, search_status: "searching" },
        )
      }
    }
    ToggleFavorite(path) =>
      (@rabbita.none, { ..model, favorites: toggle_string(model.favorites, path) })
    NotifyDaily =>
      (
        notify_cmd(
          "Moondesk daily surface",
          "\{model.requests.length()} requests, \{model.runs.length()} runs, \{model.town_messages.length()} town messages",
        ),
        { ..model, notification_status: "notification requested" },
      )
    RefreshAll =>
      (
        @rabbita.batch([
          fetch_workspaces_cmd(dispatch),
          fetch_messages_cmd(dispatch),
          fetch_requests_cmd(dispatch),
        ]),
        { ..model, host_status: "refreshing" },
      )
  }
}

///|
fn render_activity_rail(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="activity-rail", [
    div(class="rail-mark", "MD"),
    div(
      class="rail-buttons",
      activities().map(item => {
        let class_name = if item.key == model.activity {
          "rail-button active"
        } else {
          "rail-button"
        }
        button(
          class=class_name,
          title=item.label,
          on_click=dispatch(SelectActivity(item.key)),
          [
            span(class="rail-icon", item.icon),
            span(class="sr-only", item.label),
          ],
        )
      }),
    ),
  ])
}

///|
fn layer_label(layer : @desk.SourceLayer) -> String {
  match layer {
    @desk.SourceLayer::Wiki => "wiki"
    @desk.SourceLayer::RawEvidence => "raw"
    @desk.SourceLayer::GeneratedSite => "site"
    @desk.SourceLayer::BookOutput => "book"
    @desk.SourceLayer::Review => "review"
    @desk.SourceLayer::History => "history"
    @desk.SourceLayer::RunArtifact => "run"
    @desk.SourceLayer::Inbox => "inbox"
    @desk.SourceLayer::Config => "config"
    @desk.SourceLayer::Workspace => "root"
  }
}

///|
fn icon_for_kind(kind : @desk.EntryKind) -> String {
  match kind {
    @desk.EntryKind::Directory => "D"
    @desk.EntryKind::Markdown => "M"
    @desk.EntryKind::Html => "H"
    @desk.EntryKind::Json => "J"
    @desk.EntryKind::Image => "P"
    @desk.EntryKind::Artifact => "A"
    @desk.EntryKind::Text => "T"
    @desk.EntryKind::Unknown => "?"
  }
}

///|
fn renderer_label(renderer : @desk.PreviewRenderer) -> String {
  match renderer {
    @desk.PreviewRenderer::Markdown => "markdown"
    @desk.PreviewRenderer::Html => "html"
    @desk.PreviewRenderer::Json => "json"
    @desk.PreviewRenderer::Image => "image"
    @desk.PreviewRenderer::Text => "text"
    @desk.PreviewRenderer::ArtifactSummary => "artifact"
    @desk.PreviewRenderer::DirectoryListing => "directory"
    @desk.PreviewRenderer::Unsupported => "unsupported"
  }
}

///|
fn render_explorer(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  match model.activity {
    Activity::Search => render_search_pane(dispatch, model)
    Activity::Inbox => render_inbox_pane(dispatch, model)
    Activity::Town => render_town_pane(dispatch, model)
    Activity::Runs => render_runs_pane(dispatch, model)
    Activity::Settings => render_settings_pane(dispatch, model)
    Activity::Explorer => render_files_pane(dispatch, model)
  }
}

///|
fn render_files_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "workspace"), h2("All Books")]),
      button(
        class="icon-button",
        title="Refresh",
        on_click=dispatch(RefreshAll),
        "R",
      ),
    ]),
    render_workspace_card(dispatch, model),
    div(class="explorer-section-tabs", [
      button(
        class=if model.current_directory == "" { "section-pill active" } else { "section-pill" },
        on_click=dispatch(OpenDirectory("")),
        "Root",
      ),
      button(
        class=if model.current_directory == "wiki" { "section-pill active" } else { "section-pill" },
        on_click=dispatch(OpenDirectory("wiki")),
        "Wiki",
      ),
      button(
        class=if model.current_directory == "inbox" { "section-pill active" } else { "section-pill" },
        on_click=dispatch(OpenDirectory("inbox")),
        "Inbox",
      ),
      button(
        class=if model.current_directory == "book/site/generated" { "section-pill active" } else { "section-pill" },
        on_click=dispatch(OpenDirectory("book/site/generated")),
        "Outputs",
      ),
    ]),
    render_tree(dispatch, model),
  ])
}

///|
fn render_workspace_card(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(class="workspace-stack", [
    div(class="workspace-card", [
      span(class="status-dot live", ""),
      div([
        h3(workspace_name(model)),
        p(workspace_root(model)),
      ]),
    ]),
    div(
      class="workspace-list",
      model.workspaces.map(workspace => {
        let class_name = if workspace.id == model.selected_workspace_id {
          "workspace-row active"
        } else {
          "workspace-row"
        }
        button(
          class=class_name,
          title=workspace.root_path,
          on_click=dispatch(SelectWorkspace(workspace.id)),
          [
            span(workspace.name),
            small(workspace.kind.to_string()),
          ],
        )
      }),
    ),
  ])
}

///|
fn render_tree(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  if model.entries.length() == 0 {
    div(class="empty-state", [
      strong("No entries loaded"),
      p(model.host_status),
    ])
  } else {
    ul(
      class="tree-list",
      model.entries.map(entry => {
        let selected = entry.path == model.selected_path
        let class_name = if selected { "tree-row selected" } else { "tree-row" }
        li(class=class_name, on_click=dispatch(SelectPath(entry.path)), [
          span(class="tree-indent depth-0", ""),
          span(class="tree-icon", icon_for_kind(entry.kind)),
          span(class="tree-label", entry.display_name),
          span(class="tree-layer", layer_label(entry.source_layer)),
        ])
      }),
    )
  }
}

///|
fn render_search_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "cross-book"), h2("Search")]),
      button(class="icon-button", title="Run Search", on_click=dispatch(SearchNow), "S"),
    ]),
    section(class="side-section", [
      input(
        class="line-input",
        value=model.search_query,
        placeholder="Find markdown, json, html, logs...",
        on_input=fn(value) { dispatch(SetSearchQuery(value)) },
        "",
      ),
      button(class="primary-button full", on_click=dispatch(SearchNow), "Search Books"),
      p(class="status-line", model.search_status),
    ]),
    div(
      class="search-results",
      model.search_hits.map(hit => {
        button(
          class="search-result",
          title=hit.path,
          on_click=dispatch(SelectSearchHit(hit.workspace_id, hit.path)),
          [
            span(class="record-kind", layer_label(hit.source_layer)),
            strong(hit.title),
            small("\{icon_for_kind(hit.kind)} \{hit.workspace_name} / \{hit.path}"),
            p(hit.snippet),
          ],
        )
      }),
    ),
  ])
}

///|
fn render_inbox_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "safe writes"), h2("Inbox")]),
      button(
        class="icon-button",
        title="Load Selection",
        on_click=dispatch(LoadSelectionIntoInbox),
        "L",
      ),
    ]),
    section(class="side-section", [
      input(
        class="line-input",
        value=model.inbox_title,
        placeholder="Note title",
        on_input=fn(value) { dispatch(SetInboxTitle(value)) },
        "",
      ),
      textarea(
        class="side-textarea",
        rows=10,
        value=model.inbox_content,
        placeholder="Draft markdown before it enters durable wiki pages.",
        on_input=fn(value) { dispatch(SetInboxContent(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(class="secondary-button", on_click=dispatch(LoadSelectionIntoInbox), "Load Selection"),
        button(class="secondary-button", on_click=dispatch(StageSelectedLink), "Link Selection"),
      ]),
      button(class="primary-button full", on_click=dispatch(SaveInboxNote), "Save Inbox Note"),
      p(class="status-line", model.inbox_status),
    ]),
    section(class="side-section", [
      h3("Preview"),
      pre(class="source-block compact", code(model.inbox_content)),
    ]),
  ])
}

///|
fn render_town_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "moontown"), h2("Requests")]),
      button(class="icon-button", title="Refresh", on_click=dispatch(RefreshAll), "R"),
    ]),
    section(class="side-section", [
      textarea(
        class="side-textarea",
        rows=8,
        value=model.request_prompt,
        placeholder="Ask Moontown to act on selected context.",
        on_input=fn(value) { dispatch(SetRequestPrompt(value)) },
        "",
      ),
      button(class="primary-button full", on_click=dispatch(SubmitRequest), "Submit to Town"),
      p(class="status-line", model.request_status),
    ]),
    render_request_list(model),
  ])
}

///|
fn render_request_list(model : Model) -> @rabbita.Html {
  div(
    class="side-records",
    model.requests.map(record => {
      div(class="side-record", [
        span(class="record-kind", record.status),
        strong(request_title(record)),
        small(record.path),
      ])
    }),
  )
}

///|
fn render_runs_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "moonclaw"), h2("Runs")]),
      button(
        class="icon-button",
        title="Refresh Runs",
        on_click=dispatch(SelectWorkspace(model.selected_workspace_id)),
        "R",
      ),
    ]),
    div(
      class="side-records",
      model.runs.map(run => {
        div(class="run-record", [
          div([
            span(class="record-kind", run.status),
            strong(run.run_id),
            small(run.summary),
          ]),
          div(
            class="artifact-list",
            run.artifacts.map(artifact => {
              button(
                class="artifact-link",
                title=artifact.path,
                on_click=dispatch(OpenQuickPath(artifact.path)),
                [
                  span(class="artifact-icon", icon_for_kind(artifact.kind)),
                  span(artifact.title),
                ],
              )
            }),
          ),
        ])
      }),
    ),
  ])
}

///|
fn render_settings_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "daily"), h2("Operating Surface")]),
      button(class="icon-button", title="Notify", on_click=dispatch(NotifyDaily), "N"),
    ]),
    section(class="side-section", [
      h3("Today"),
      info_row("Requests", model.requests.length().to_string()),
      info_row("Runs", model.runs.length().to_string()),
      info_row("Messages", model.town_messages.length().to_string()),
      info_row("Favorites", model.favorites.length().to_string()),
      button(class="primary-button full", on_click=dispatch(NotifyDaily), "Notify Summary"),
      p(class="status-line", model.notification_status),
    ]),
    section(class="side-section", [
      h3("Export Snapshot"),
      pre(class="source-block compact", code(export_snapshot(model))),
    ]),
  ])
}

///|
fn export_snapshot(model : Model) -> String {
  "Moondesk snapshot\n" +
  "workspace: \{workspace_name(model)}\n" +
  "selected: \{model.selected_path}\n" +
  "requests: \{model.requests.length()}\n" +
  "runs: \{model.runs.length()}\n" +
  "messages: \{model.town_messages.length()}\n" +
  "favorites: \{model.favorites.join(", ")}\n"
}

///|
fn preview_tabs(model : Model) -> Array[PreviewTab] {
  let tabs : Array[PreviewTab] = []
  let renderer = match model.preview {
    Some(preview) => preview.renderer
    None => @desk.PreviewRenderer::Unsupported
  }
  tabs.push({
    title: @desk.display_name(model.selected_path),
    path: model.selected_path,
    renderer,
  })
  tabs.push({
    title: "generated site",
    path: "book/site/generated/index.html",
    renderer: @desk.PreviewRenderer::Html,
  })
  match first_run_report_path(model) {
    Some(path) =>
      tabs.push({
        title: "run report",
        path,
        renderer: @desk.PreviewRenderer::ArtifactSummary,
      })
    None => ()
  }
  tabs
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
fn render_preview_body(model : Model) -> @rabbita.Html {
  match model.preview {
    None =>
      div(class="markdown-preview", [
        h1("Preview"),
        p(class="lead", model.preview_status),
        pre(class="source-block", code(model.selected_path)),
      ])
    Some(preview) =>
      match preview.renderer {
        @desk.PreviewRenderer::Html =>
          div(class="site-preview", [
            div(class="site-toolbar", [
              span(model.selected_path),
              a(
                class="secondary-button link-button",
                href=raw_url(model, model.selected_path),
                target=@html.Target::Blank,
                rel="noreferrer",
                "Open",
              ),
            ]),
            iframe(
              class="site-iframe",
              src=raw_url(model, model.selected_path),
              title=preview.title,
              sandbox="allow-same-origin allow-scripts",
            ),
          ])
        @desk.PreviewRenderer::Image =>
          div(class="image-preview", [
            img(src=preview.body, alt=preview.title, ""),
          ])
        @desk.PreviewRenderer::DirectoryListing =>
          div(class="markdown-preview", [
            h1(preview.title),
            p(class="lead", "Directory listing"),
            pre(class="source-block", code(preview.body)),
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
      span(class="path-pill", model.selected_path),
      div(class="toolbar-actions", [
        button(
          class=if has_string(model.favorites, model.selected_path) {
            "secondary-button active"
          } else {
            "secondary-button"
          },
          on_click=dispatch(ToggleFavorite(model.selected_path)),
          "Favorite",
        ),
        a(
          class="secondary-button link-button",
          href=raw_url(model, model.selected_path),
          target=@html.Target::Blank,
          rel="noreferrer",
          "Open Raw",
        ),
        button(
          class="primary-button",
          on_click=dispatch(ToggleCommand),
          "Command",
        ),
      ]),
    ]),
    section(class="preview-surface", [render_preview_body(model)]),
  ])
}

///|
fn render_inspector(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="inspector-pane", [
    div(class="pane-heading compact", [
      div([p(class="eyebrow", "inspector"), h2("Context")]),
    ]),
    section(class="inspector-section", [
      h3("Selection"),
      info_row("Path", model.selected_path),
      info_row("Book", workspace_name(model)),
      info_row("Layer", selected_layer(model)),
      info_row("Writable", if is_inbox_path(model.selected_path) { "yes" } else { "inbox only" }),
      button(
        class="secondary-button full",
        on_click=dispatch(StageSelectedLink),
        "Copy Link To Inbox",
      ),
    ]),
    section(class="inspector-section", [
      h3("Favorites"),
      render_path_list(dispatch, model.favorites),
    ]),
    section(class="composer", [
      h3("Request"),
      textarea(
        class="composer-input",
        rows=8,
        value=model.request_prompt,
        on_input=fn(value) { dispatch(SetRequestPrompt(value)) },
        "",
      ),
      div(class="composer-options", [
        span(class="option-chip active", "one-shot"),
        span(class="option-chip", "selected-context"),
      ]),
      button(
        class="primary-button full",
        on_click=dispatch(SubmitRequest),
        "Submit to Town",
      ),
      p(class="status-line", model.request_status),
    ]),
  ])
}

///|
fn render_path_list(dispatch : Dispatch[Msg], paths : Array[String]) -> @rabbita.Html {
  if paths.length() == 0 {
    p(class="status-line", "none")
  } else {
    div(
      class="mini-list",
      paths.map(path => {
        button(
          class="mini-link",
          title=path,
          on_click=dispatch(OpenQuickPath(path)),
          path,
        )
      }),
    )
  }
}

///|
fn info_row(label : String, value : String) -> @rabbita.Html {
  div(class="info-row", [span(label), code(value)])
}

///|
fn render_bottom_drawer(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="bottom-drawer", [
    div(class="drawer-tabs", [
      span(class="drawer-tab active", "Requests"),
      span(class="drawer-tab", "Town Messages"),
      span(class="drawer-tab", "Runs"),
      span(class="drawer-tab", "Recent"),
    ]),
    div(class="drawer-records", [
      render_request_drawer(model),
      render_message_drawer(model),
      render_run_drawer(dispatch, model),
    ]),
  ])
}

///|
fn render_request_drawer(model : Model) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "requests"),
    div([
      h3("\{model.requests.length()} staged"),
      p(if model.requests.length() == 0 {
        "No Moondesk requests staged yet."
      } else {
        request_title(model.requests[model.requests.length() - 1])
      }),
    ]),
  ])
}

///|
fn render_message_drawer(model : Model) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "town"),
    div([
      h3("\{model.town_messages.length()} messages"),
      p(if model.town_messages.length() == 0 {
        "No recent town messages."
      } else {
        let message = model.town_messages[model.town_messages.length() - 1]
        "\{message.kind} \{message.id}: \{message.title} (\{message.path})"
      }),
    ]),
  ])
}

///|
fn render_run_drawer(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "runs"),
    div([
      h3("\{model.runs.length()} runs"),
      match first_run_report_path(model) {
        Some(path) =>
          button(
            class="mini-link inline",
            on_click=dispatch(OpenQuickPath(path)),
            "Open latest report",
          )
        None => p("No run reports found.")
      },
    ]),
  ])
}

///|
fn render_command_palette(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !model.command_open {
    @html.nothing
  } else {
    div(class="palette-backdrop", [
      div(class="command-palette", [
        div(class="palette-head", [
          input(
            class="palette-input",
            value="",
            placeholder="Open Book, Import Files, Search, Submit...",
            "",
          ),
          button(
            class="icon-button palette-close",
            title="Close command palette",
            attrs=@html.Attrs::build().aria_label("Close command palette"),
            on_click=dispatch(ToggleCommand),
            "X",
          ),
        ]),
        div(class="palette-list", [
          palette_command(dispatch, "Search Books", "Find files across MoonBooks", SelectActivity(Activity::Search)),
          palette_command(dispatch, "Create Inbox Note", "Stage a safe draft in inbox", SelectActivity(Activity::Inbox)),
          palette_command(dispatch, "Submit to Town", "Send selected context to Moontown", SubmitRequest),
          palette_command(dispatch, "Show Run Artifacts", "Open MoonClaw run projection", SelectActivity(Activity::Runs)),
          palette_command(dispatch, "Daily Surface", "Open operating summary", SelectActivity(Activity::Settings)),
        ]),
      ]),
    ])
  }
}

///|
fn palette_command(
  dispatch : Dispatch[Msg],
  title : String,
  detail : String,
  msg : Msg,
) -> @rabbita.Html {
  button(class="palette-command", on_click=dispatch(msg), [
    span(class="command-icon", ">"),
    div([h3(title), p(detail)]),
  ])
}

///|
fn render_title_bar(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  let status = if model.loading { "loading workspace" } else { model.host_status }
  header(class="title-bar", [
    div(class="title-copy", [
      span(class="app-dot", ""),
      h1("Moondesk"),
      span(class="workspace-switcher", workspace_name(model)),
    ]),
    button(
      class="command-button",
      on_click=dispatch(ToggleCommand),
      "Command Palette",
    ),
    div(class="sync-status", [
      span(class="status-dot live", ""),
      span(status),
    ]),
  ])
}

///|
fn render_app(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  div(class="desk-shell", [
    render_title_bar(dispatch, model),
    div(class="desk-main", [
      render_activity_rail(dispatch, model),
      render_explorer(dispatch, model),
      render_preview_center(dispatch, model),
      render_inspector(dispatch, model),
    ]),
    render_bottom_drawer(dispatch, model),
    render_command_palette(dispatch, model),
  ])
}

///|
#cfg(target="js")
test {
  ignore(fetch_workspaces_cmd)
  ignore(fetch_entries_cmd)
  ignore(fetch_preview_cmd)
  ignore(fetch_runs_cmd)
  ignore(fetch_messages_cmd)
  ignore(fetch_requests_cmd)
  ignore(fetch_search_cmd)
  ignore(save_inbox_cmd)
  ignore(submit_request_cmd)
  ignore(notify_cmd)
}

///|
fn main {
  let (dispatch, cell) = @rabbita.cell_with_dispatch(model=init_model(), update~, view=(
    dispatch,
    model,
  ) => render_app(dispatch, model))
  let app = @rabbita.new(cell)
  app.with_init(fetch_workspaces_cmd(dispatch))
  app.mount("app")
}
