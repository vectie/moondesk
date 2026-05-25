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
struct StandingGoalRecord {
  id : String
  title : String
  prompt : String
  target_book_id : String
  cadence_ticks : Int
  next_due_tick : Int
  last_run_tick : Int?
  enabled : Bool
  source_policy : String
  quality_threshold : Int
} derive(FromJson)

///|
struct TownAnalytics {
  daemon_tick : Int
  standing_goal_count : Int
  due_goal_count : Int
  active_goal_count : Int
  request_count : Int
  message_count : Int
  run_count : Int
  watcher_run_count : Int
  updates : Int
  no_changes : Int
  needs_review : Int
  failures : Int
  deferred : Int
  event_count : Int
  failure_event_count : Int
  review_event_count : Int
  last_failure : String
  review_item_count : Int
  next_due_tick : Int
} derive(FromJson)

///|
struct TownProgress {
  daemon_tick : Int
  daemon_running : Bool
  daemon_status : String
  supervision_enabled : Bool
  due_goal_count : Int
  next_due_tick : Int
  request_count : Int
  message_count : Int
  dispatch_count : Int
  run_count : Int
  latest_request : String
  latest_message : String
  latest_dispatch : String
  latest_run : String
  latest_run_status : String
  latest_run_artifacts : Int
} derive(FromJson)

///|
struct MoonclawProgress {
  run_count : Int
  ready_count : Int
  artifact_count : Int
  latest_run : String
  latest_status : String
} derive(FromJson)

///|
struct DaemonDispatchResult {
  id : String
  ok : Bool
  status : String
  exit_code : Int
  path : String
  stdout : String
  stderr : String
} derive(FromJson)

///|
struct DaemonLifecycleResult {
  ok : Bool
  action : String
  status : String
  running : Bool
  pid : Int
  command : String
  cwd : String
  started_at : String
  stopped_at : String
  pid_file : String
  stdout_path : String
  stderr_path : String
  message : String
  supervision_enabled : Bool
  desired_state : String
  restart_count : Int
  last_health_check : String
  policy_file : String
} derive(FromJson)

///|
struct DaemonAgentResult {
  ok : Bool
  action : String
  installed : Bool
  loaded : Bool
  label : String
  plist_path : String
  command : String
  cwd : String
  exit_code : Int
  message : String
} derive(FromJson)

///|
struct RevealResult {
  ok : Bool
  status : String
  exit_code : Int
  workspace_id : String
  path : String
  absolute_path : String
} derive(FromJson)

///|
struct InboxCreated {
  ok : Bool
  workspace_id : String
  path : String
} derive(FromJson)

///|
struct InboxImportResult {
  ok : Bool
  workspace_id : String
  path : String
  kind : String
  data_path : String
} derive(FromJson)

///|
struct SavedViewRecord {
  id : String
  title : String
  query : String
  workspace_id : String
  path : String
  created_at : String
  updated_at : String
} derive(FromJson)

///|
struct TagRecord {
  id : String
  workspace_id : String
  path : String
  tag : String
  created_at : String
} derive(FromJson)

///|
struct DeskEvent {
  id : String
  source : String
  kind : String
  severity : String
  title : String
  detail : String
  path : String
  run_id : String
  tick : Int
  created_at : String
} derive(FromJson)

///|
struct ReviewItem {
  id : String
  workspace_id : String
  path : String
  title : String
  kind : String
  status : String
  detail : String
} derive(FromJson)

///|
struct ReviewDiff {
  ok : Bool
  workspace_id : String
  path : String
  base_path : String
  comparison_path : String
  added : Int
  removed : Int
  changed : Bool
  body : String
} derive(FromJson)

///|
struct LocalImportFile {
  id : String
  name : String
  media_type : String
  content : String
  source : String
} derive(FromJson)

///|
struct BrowserLocalImportBatch {
  ok : Bool
  files : Array[LocalImportFile]
  error : String?
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
  standing_goals : Array[StandingGoalRecord]
  analytics : TownAnalytics?
  town_progress : TownProgress?
  moonclaw_progress : MoonclawProgress?
  daemon_lifecycle : DaemonLifecycleResult?
  daemon_agent : DaemonAgentResult?
  events : Array[DeskEvent]
  review_items : Array[ReviewItem]
  review_diff : ReviewDiff?
  town_messages : Array[TownMessage]
  runs : Array[@desk.DeskRunProjection]
  inbox_title : String
  inbox_content : String
  import_url : String
  import_note : String
  editing_inbox_path : String
  inbox_status : String
  search_query : String
  search_status : String
  search_hits : Array[SearchHit]
  favorites : Array[String]
  saved_views : Array[SavedViewRecord]
  tags : Array[TagRecord]
  recent_paths : Array[String]
  view_title : String
  tag_value : String
  goal_title : String
  goal_cadence_ticks : String
  goal_quality_threshold : String
  goal_source_policy : String
  dispatch_status : String
  daemon_status : String
  reveal_status : String
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
  LoadedStandingGoals(Result[Array[StandingGoalRecord], String])
  LoadedAnalytics(Result[TownAnalytics, String])
  LoadedTownProgress(Result[TownProgress, String])
  LoadedMoonclawProgress(Result[MoonclawProgress, String])
  LoadedEvents(Result[Array[DeskEvent], String])
  LoadedReviewItems(Result[Array[ReviewItem], String])
  LoadedReviewDiff(Result[ReviewDiff, String])
  LoadedSavedViews(Result[Array[SavedViewRecord], String])
  LoadedTags(Result[Array[TagRecord], String])
  LoadedSearch(Result[Array[SearchHit], String])
  SavedInbox(Result[InboxCreated, String])
  ImportedInbox(Result[InboxImportResult, String])
  SavedView(Result[SavedViewRecord, String])
  SavedTag(Result[TagRecord, String])
  SubmittedRequest(Result[RequestRecord, String])
  CreatedStandingGoal(Result[StandingGoalRecord, String])
  DispatchedDaemon(Result[DaemonDispatchResult, String])
  LoadedDaemonLifecycle(Result[DaemonLifecycleResult, String])
  ManagedDaemon(Result[DaemonLifecycleResult, String])
  LoadedDaemonAgent(Result[DaemonAgentResult, String])
  ManagedDaemonAgent(Result[DaemonAgentResult, String])
  RevealedSelection(Result[RevealResult, String])
  LocalFilesPicked(Result[Array[LocalImportFile], String])
  SelectActivity(Activity)
  SelectWorkspace(String)
  SelectPath(String)
  OpenDirectory(String)
  OpenQuickPath(String)
  SelectSearchHit(String, String)
  ToggleCommand
  SetRequestPrompt(String)
  SubmitRequest
  SetGoalTitle(String)
  SetGoalCadenceTicks(String)
  SetGoalQualityThreshold(String)
  SetGoalSourcePolicy(String)
  CreateStandingGoal
  DispatchDaemonTick
  FetchDaemonLifecycle
  StartDaemon
  StopDaemon
  RestartDaemon
  EnableDaemonSupervision
  DisableDaemonSupervision
  InstallDaemonAgent
  UninstallDaemonAgent
  RevealSelection
  SetInboxTitle(String)
  SetInboxContent(String)
  SetImportUrl(String)
  SetImportNote(String)
  ImportUrlToInbox
  ImportLocalFiles
  PollDroppedImports
  LoadSelectionIntoInbox
  SaveInboxNote
  StageSelectedLink
  SetSearchQuery(String)
  SearchNow
  ToggleFavorite(String)
  SetViewTitle(String)
  SaveCurrentView
  SetTagValue(String)
  TagSelection
  NotifyDaily
  RefreshAll
}

///|
fn initial_activity() -> Activity {
  activity_from_slug(browser_initial_activity())
}

///|
fn activity_from_slug(slug : String) -> Activity {
  match slug {
    "search" => Activity::Search
    "inbox" => Activity::Inbox
    "town" => Activity::Town
    "runs" => Activity::Runs
    "settings" => Activity::Settings
    _ => Activity::Explorer
  }
}

///|
fn activity_slug(activity : Activity) -> String {
  match activity {
    Activity::Explorer => "explorer"
    Activity::Search => "search"
    Activity::Inbox => "inbox"
    Activity::Town => "town"
    Activity::Runs => "runs"
    Activity::Settings => "settings"
  }
}

///|
fn activity_href(activity : Activity) -> String {
  "?activity=\{activity_slug(activity)}"
}

///|
fn init_model() -> Model {
  {
    activity: initial_activity(),
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
    standing_goals: [],
    analytics: None,
    town_progress: None,
    moonclaw_progress: None,
    daemon_lifecycle: None,
    daemon_agent: None,
    events: [],
    review_items: [],
    review_diff: None,
    town_messages: [],
    runs: [],
    inbox_title: "Operator note",
    inbox_content: "",
    import_url: "",
    import_note: "",
    editing_inbox_path: "",
    inbox_status: "draft",
    search_query: "",
    search_status: "enter a query",
    search_hits: [],
    favorites: [],
    saved_views: [],
    tags: [],
    recent_paths: [],
    view_title: "Current view",
    tag_value: "",
    goal_title: "Standing watch",
    goal_cadence_ticks: "60",
    goal_quality_threshold: "85",
    goal_source_policy: "web-first",
    dispatch_status: "daemon idle",
    daemon_status: "daemon manager idle",
    reveal_status: "reveal idle",
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
fn int_text(value : String, fallback : Int) -> Int {
  @string.parse_int(value.trim().to_owned()) catch { _ => fallback }
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn daemon_lifecycle_label(result : DaemonLifecycleResult) -> String {
  let pid = if result.pid > 0 { " pid \{result.pid}" } else { "" }
  "\{result.status}\{pid}: \{result.message}"
}

///|
fn daemon_agent_label(result : DaemonAgentResult) -> String {
  let state = if result.installed {
    if result.loaded { "loaded" } else { "installed" }
  } else {
    "not installed"
  }
  "LaunchAgent \{state}: \{result.message}"
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
extern "js" fn browser_initial_activity() -> String =
  #| () => new URLSearchParams(globalThis.location?.search || "").get("activity") || ""

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
#cfg(target="js")
extern "js" fn browser_pick_import_files() -> String =
  #| async () => {
  #|   const readFile = async (file, source) => {
  #|     const textLike =
  #|       file.type.startsWith("text/") ||
  #|       /\.(md|txt|json|mbt|js|ts|tsx|jsx|css|html|xml|yaml|yml|toml|csv)$/i.test(file.name);
  #|     const content = textLike
  #|       ? await file.text()
  #|       : await new Promise((resolve, reject) => {
  #|           const reader = new FileReader();
  #|           reader.onerror = () => reject(reader.error ?? new Error("Failed to read file"));
  #|           reader.onload = () => resolve(String(reader.result ?? ""));
  #|           reader.readAsDataURL(file);
  #|         });
  #|     return {
  #|       id: `${source}:${file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name || "pasted-file",
  #|       media_type: file.type || "application/octet-stream",
  #|       content,
  #|       source,
  #|     };
  #|   };
  #|   try {
  #|     const input = document.createElement("input");
  #|     input.type = "file";
  #|     input.multiple = true;
  #|     const files = await new Promise((resolve) => {
  #|       input.onchange = () => resolve(Array.from(input.files || []));
  #|       input.click();
  #|     });
  #|     const loaded = await Promise.all(files.map((file) => readFile(file, "picker")));
  #|     return JSON.stringify({ ok: true, files: loaded, error: null });
  #|   } catch (error) {
  #|     return JSON.stringify({ ok: false, files: [], error: String(error) });
  #|   }
  #| }

///|
#cfg(target="js")
extern "js" fn browser_take_dropped_import_files() -> String =
  #| async () => {
  #|   const state =
  #|     (window.__moondeskImportState ||= { installed: false, queue: [] });
  #|   const readFile = async (file, source) => {
  #|     const textLike =
  #|       file.type.startsWith("text/") ||
  #|       /\.(md|txt|json|mbt|js|ts|tsx|jsx|css|html|xml|yaml|yml|toml|csv)$/i.test(file.name);
  #|     const content = textLike
  #|       ? await file.text()
  #|       : await new Promise((resolve, reject) => {
  #|           const reader = new FileReader();
  #|           reader.onerror = () => reject(reader.error ?? new Error("Failed to read local file"));
  #|           reader.onload = () => resolve(String(reader.result ?? ""));
  #|           reader.readAsDataURL(file);
  #|         });
  #|     return {
  #|       id: `${source}:${file.name}:${file.size}:${file.lastModified}`,
  #|       name: file.name || `${source}-image-${Date.now()}.png`,
  #|       media_type: file.type || "application/octet-stream",
  #|       content,
  #|       source,
  #|     };
  #|   };
  #|   if (!state.installed) {
  #|     const stop = (event) => {
  #|       event.preventDefault();
  #|       event.stopPropagation();
  #|     };
  #|     window.addEventListener("dragover", stop);
  #|     window.addEventListener("drop", (event) => {
  #|       stop(event);
  #|       const files = Array.from(event.dataTransfer?.files || []);
  #|       Promise.all(files.map((file) => readFile(file, "drop")))
  #|         .then((loaded) => state.queue.push(...loaded))
  #|         .catch((error) => state.queue.push({
  #|           id: `drop-error:${Date.now()}`,
  #|           name: "drop-error.txt",
  #|           media_type: "text/plain",
  #|           content: String(error),
  #|           source: "drop",
  #|         }));
  #|     });
  #|     window.addEventListener("paste", (event) => {
  #|       const files = Array.from(event.clipboardData?.files || []);
  #|       if (files.length === 0) return;
  #|       Promise.all(files.map((file) => readFile(file, "paste")))
  #|         .then((loaded) => state.queue.push(...loaded))
  #|         .catch((error) => state.queue.push({
  #|           id: `paste-error:${Date.now()}`,
  #|           name: "paste-error.txt",
  #|           media_type: "text/plain",
  #|           content: String(error),
  #|           source: "paste",
  #|         }));
  #|     });
  #|     state.installed = true;
  #|   }
  #|   const files = state.queue.splice(0, state.queue.length);
  #|   return JSON.stringify({ ok: true, files, error: null });
  #| }

///|
fn notify_cmd(title : String, body : String) -> @rabbita.Cmd {
  @cmd.raw_effect(_ => send_browser_notification(title, body), kind=@cmd.after_render)
}

///|
fn parse_browser_import_batch(
  text : String,
) -> Result[Array[LocalImportFile], String] {
  if text.trim().to_string() == "" {
    return Ok([])
  }
  let json : Result[Json, Error] = try? @json.parse(text)
  let payload = match json {
    Ok(json) =>
      match
        (try? @json.from_json(json) : Result[BrowserLocalImportBatch, Error]) {
        Ok(payload) => payload
        Err(error) => return Err("Failed to parse local import batch: \{error}")
      }
    Err(error) => return Err("Failed to parse local import wrapper: \{error}")
  }
  match payload.error {
    Some(error) => Err(error)
    None =>
      if payload.ok {
        Ok(payload.files)
      } else {
        Err("Local file import failed")
      }
  }
}

///|
fn pick_import_files_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @rabbita.perform(fn(result) { dispatch(LocalFilesPicked(result)) }, fn() noraise {
    parse_browser_import_batch(browser_pick_import_files())
  })
}

///|
fn take_dropped_imports_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @rabbita.perform(fn(result) { dispatch(LocalFilesPicked(result)) }, fn() noraise {
    parse_browser_import_batch(browser_take_dropped_import_files())
  })
}

///|
fn schedule_import_drop_poll(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @rabbita.delay(dispatch(PollDroppedImports), 1200)
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
fn fetch_standing_goals_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/standing-goals",
    expect=@http.Json(fn(result) { dispatch(LoadedStandingGoals(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid standing goal registry")
      }
    }),
  )
}

///|
fn fetch_analytics_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/analytics",
    expect=@http.Json(fn(result) { dispatch(LoadedAnalytics(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid town analytics")
      }
    }),
  )
}

///|
fn fetch_town_progress_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/progress",
    expect=@http.Json(fn(result) { dispatch(LoadedTownProgress(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid town progress")
      }
    }),
  )
}

///|
fn fetch_moonclaw_progress_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/moonclaw/progress?workspace=\{encode_component(workspace_id)}",
    expect=@http.Json(fn(result) { dispatch(LoadedMoonclawProgress(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonClaw progress")
      }
    }),
  )
}

///|
fn fetch_events_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/moonclaw/events?workspace=\{encode_component(workspace_id)}",
    expect=@http.Json(fn(result) { dispatch(LoadedEvents(result)) }, json => {
      let moonclaw_events : Result[Array[DeskEvent], Error] = try? @json.from_json(json)
      match moonclaw_events {
        Ok(events) => Ok(events)
        Err(_) => Err("Invalid event stream")
      }
    }),
  )
}

///|
fn fetch_town_events_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/events",
    expect=@http.Json(fn(result) { dispatch(LoadedEvents(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid town event stream")
      }
    }),
  )
}

///|
fn fetch_review_items_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/review/items?workspace=\{encode_component(workspace_id)}",
    expect=@http.Json(fn(result) { dispatch(LoadedReviewItems(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid review queue")
      }
    }),
  )
}

///|
fn fetch_review_diff_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
  path : String,
) -> @rabbita.Cmd {
  @http.get(
    "/api/workspaces/\{workspace_id}/review-diff?path=\{encode_component(path)}",
    expect=@http.Json(fn(result) { dispatch(LoadedReviewDiff(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid review diff")
      }
    }),
  )
}

///|
fn fetch_saved_views_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/preferences/views",
    expect=@http.Json(fn(result) { dispatch(LoadedSavedViews(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid saved views")
      }
    }),
  )
}

///|
fn fetch_tags_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/preferences/tags",
    expect=@http.Json(fn(result) { dispatch(LoadedTags(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid tags")
      }
    }),
  )
}

///|
fn fetch_daemon_lifecycle_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/daemon/status",
    expect=@http.Json(fn(result) { dispatch(LoadedDaemonLifecycle(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid daemon lifecycle status")
      }
    }),
  )
}

///|
fn fetch_daemon_agent_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/town/daemon/agent",
    expect=@http.Json(fn(result) { dispatch(LoadedDaemonAgent(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid daemon agent status")
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
fn import_url_cmd(dispatch : (Msg) -> @rabbita.Cmd, model : Model) -> @rabbita.Cmd {
  let url = model.import_url.trim().to_owned()
  let title = if url == "" { "Imported URL" } else { url }
  @http.post(
    "/api/workspaces/\{model.selected_workspace_id}/import",
    @http.Body::Json({
      "kind": "url",
      "title": title,
      "url": url,
      "note": model.import_note,
    }),
    expect=@http.Json(fn(result) { dispatch(ImportedInbox(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not import URL")
      }
    }),
  )
}

///|
fn import_local_file_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
  file : LocalImportFile,
) -> @rabbita.Cmd {
  let is_data_url = file.content.has_prefix("data:")
  @http.post(
    "/api/workspaces/\{model.selected_workspace_id}/import",
    @http.Body::Json({
      "kind": if file.source == "paste" { "paste" } else { "file" },
      "title": file.name,
      "filename": file.name,
      "browser_import_id": file.id,
      "content_type": file.media_type,
      "note": model.import_note,
      "content": if is_data_url { "" } else { file.content },
      "data_url": if is_data_url { file.content } else { "" },
    }),
    expect=@http.Json(fn(result) { dispatch(ImportedInbox(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not import local file")
      }
    }),
  )
}

///|
fn save_view_cmd(dispatch : (Msg) -> @rabbita.Cmd, model : Model) -> @rabbita.Cmd {
  @http.post(
    "/api/preferences/views",
    @http.Body::Json({
      "title": trimmed_or(model.view_title, "Current view"),
      "query": model.search_query,
      "workspace_id": model.selected_workspace_id,
      "path": model.selected_path,
    }),
    expect=@http.Json(fn(result) { dispatch(SavedView(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not save view")
      }
    }),
  )
}

///|
fn save_tag_cmd(dispatch : (Msg) -> @rabbita.Cmd, model : Model) -> @rabbita.Cmd {
  @http.post(
    "/api/preferences/tags",
    @http.Body::Json({
      "workspace_id": model.selected_workspace_id,
      "path": model.selected_path,
      "tag": trimmed_or(model.tag_value, "review"),
    }),
    expect=@http.Json(fn(result) { dispatch(SavedTag(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not save tag")
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
fn create_standing_goal_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let title = trimmed_or(model.goal_title, "Standing watch")
  let cadence = clamp_int(int_text(model.goal_cadence_ticks, 60), 1, 525600)
  let quality = clamp_int(int_text(model.goal_quality_threshold, 85), 1, 100)
  let body : Json = {
    "title": title,
    "prompt": trimmed_or(model.request_prompt, "Watch the selected MoonBook context for useful updates."),
    "target_book_id": model.selected_workspace_id,
    "cadence_ticks": cadence,
    "source_policy": trimmed_or(model.goal_source_policy, "web-first"),
    "quality_threshold": quality,
    "enabled": true,
  }
  @http.post(
    "/api/town/standing-goals",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) { dispatch(CreatedStandingGoal(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not create standing watch")
      }
    }),
  )
}

///|
fn dispatch_daemon_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.post(
    "/api/town/dispatch",
    @http.Body::Json(Json::object({})),
    expect=@http.Json(fn(result) { dispatch(DispatchedDaemon(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not dispatch daemon tick")
      }
    }),
  )
}

///|
fn manage_daemon_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  action : String,
) -> @rabbita.Cmd {
  @http.post(
    "/api/town/daemon/\{action}",
    @http.Body::Json(Json::object({})),
    expect=@http.Json(fn(result) { dispatch(ManagedDaemon(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not manage daemon lifecycle")
      }
    }),
  )
}

///|
fn set_daemon_supervision_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  enabled : Bool,
) -> @rabbita.Cmd {
  @http.post(
    "/api/town/daemon/supervision",
    @http.Body::Json({ "enabled": enabled }),
    expect=@http.Json(fn(result) { dispatch(ManagedDaemon(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not update daemon supervision")
      }
    }),
  )
}

///|
fn manage_daemon_agent_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  action : String,
) -> @rabbita.Cmd {
  @http.post(
    "/api/town/daemon/agent",
    @http.Body::Json({ "action": action }),
    expect=@http.Json(fn(result) { dispatch(ManagedDaemonAgent(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not update daemon LaunchAgent")
      }
    }),
  )
}

///|
fn reveal_selection_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  @http.post(
    "/api/workspaces/\{model.selected_workspace_id}/reveal",
    @http.Body::Json({ "path": model.selected_path }),
    expect=@http.Json(fn(result) { dispatch(RevealedSelection(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not reveal selection")
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
      fetch_moonclaw_progress_cmd(dispatch, workspace_id),
      fetch_messages_cmd(dispatch),
      fetch_requests_cmd(dispatch),
      fetch_standing_goals_cmd(dispatch),
      fetch_analytics_cmd(dispatch),
      fetch_town_progress_cmd(dispatch),
      fetch_town_events_cmd(dispatch),
      fetch_daemon_lifecycle_cmd(dispatch),
      fetch_daemon_agent_cmd(dispatch),
      fetch_review_items_cmd(dispatch, workspace_id),
      fetch_review_diff_cmd(dispatch, workspace_id, selected_path),
      fetch_saved_views_cmd(dispatch),
      fetch_tags_cmd(dispatch),
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
    LoadedStandingGoals(Ok(standing_goals)) =>
      (@rabbita.none, { ..model, standing_goals })
    LoadedStandingGoals(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedAnalytics(Ok(analytics)) => (@rabbita.none, { ..model, analytics: Some(analytics) })
    LoadedAnalytics(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedTownProgress(Ok(progress)) =>
      (@rabbita.none, { ..model, town_progress: Some(progress) })
    LoadedTownProgress(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedMoonclawProgress(Ok(progress)) =>
      (@rabbita.none, { ..model, moonclaw_progress: Some(progress) })
    LoadedMoonclawProgress(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedEvents(Ok(events)) => (@rabbita.none, { ..model, events })
    LoadedEvents(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedReviewItems(Ok(review_items)) =>
      (@rabbita.none, { ..model, review_items })
    LoadedReviewItems(Err(error)) =>
      (@rabbita.none, { ..model, reveal_status: error })
    LoadedReviewDiff(Ok(review_diff)) =>
      (@rabbita.none, { ..model, review_diff: Some(review_diff) })
    LoadedReviewDiff(Err(error)) =>
      (@rabbita.none, { ..model, reveal_status: error })
    LoadedSavedViews(Ok(saved_views)) =>
      (@rabbita.none, { ..model, saved_views })
    LoadedSavedViews(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedTags(Ok(tags)) => (@rabbita.none, { ..model, tags })
    LoadedTags(Err(error)) => (@rabbita.none, { ..model, host_status: error })
    LoadedDaemonLifecycle(Ok(result)) =>
      (
        @rabbita.none,
        {
          ..model,
          daemon_lifecycle: Some(result),
          daemon_status: daemon_lifecycle_label(result),
        },
      )
    LoadedDaemonLifecycle(Err(error)) =>
      (@rabbita.none, { ..model, daemon_status: error })
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
    ImportedInbox(Ok(created)) =>
      (
        @rabbita.batch([
          fetch_entries_cmd(dispatch, created.workspace_id, "inbox/imports"),
          fetch_preview_cmd(dispatch, created.workspace_id, created.path),
        ]),
        {
          ..model,
          activity: Activity::Inbox,
          current_directory: "inbox/imports",
          selected_workspace_id: created.workspace_id,
          selected_path: created.path,
          import_url: "",
          import_note: "",
          inbox_status: if created.ok {
            if created.data_path == "" {
              "imported \{created.kind} to \{created.path}"
            } else {
              "imported \{created.kind} to \{created.path} and \{created.data_path}"
            }
          } else {
            "import returned without ok"
          },
          preview_status: "loading import",
        },
      )
    ImportedInbox(Err(error)) =>
      (@rabbita.none, { ..model, inbox_status: error })
    SavedView(Ok(view)) =>
      (
        fetch_saved_views_cmd(dispatch),
        { ..model, host_status: "saved view \{view.title}" },
      )
    SavedView(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    SavedTag(Ok(tag)) =>
      (
        fetch_tags_cmd(dispatch),
        { ..model, tag_value: "", reveal_status: "tagged \{tag.path} as \{tag.tag}" },
      )
    SavedTag(Err(error)) =>
      (@rabbita.none, { ..model, reveal_status: error })
    SubmittedRequest(Ok(record)) =>
      (
        @rabbita.batch([
          fetch_requests_cmd(dispatch),
          fetch_messages_cmd(dispatch),
          fetch_analytics_cmd(dispatch),
          fetch_town_progress_cmd(dispatch),
          fetch_town_events_cmd(dispatch),
        ]),
        {
          ..model,
          activity: Activity::Town,
          request_status: "staged \{record.id}",
          command_open: false,
        },
      )
    SubmittedRequest(Err(error)) =>
      (@rabbita.none, { ..model, request_status: error })
    CreatedStandingGoal(Ok(goal)) =>
      (
        @rabbita.batch([
          fetch_standing_goals_cmd(dispatch),
          fetch_analytics_cmd(dispatch),
          fetch_town_progress_cmd(dispatch),
          fetch_town_events_cmd(dispatch),
        ]),
        {
          ..model,
          activity: Activity::Town,
          dispatch_status: "created \{goal.id}",
        },
      )
    CreatedStandingGoal(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    DispatchedDaemon(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_requests_cmd(dispatch),
          fetch_messages_cmd(dispatch),
          fetch_standing_goals_cmd(dispatch),
          fetch_analytics_cmd(dispatch),
          fetch_town_progress_cmd(dispatch),
          fetch_town_events_cmd(dispatch),
          fetch_runs_cmd(dispatch, model.selected_workspace_id),
          fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
          fetch_daemon_lifecycle_cmd(dispatch),
          fetch_daemon_agent_cmd(dispatch),
        ]),
        {
          ..model,
          activity: Activity::Town,
          dispatch_status: if result.ok {
            "\{result.status} (\{result.id}) -> \{result.path}"
          } else {
            "\{result.status} (\{result.exit_code}) \{result.path}: \{if result.stderr == "" { result.stdout } else { result.stderr }}"
          },
        },
      )
    DispatchedDaemon(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    ManagedDaemon(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_analytics_cmd(dispatch),
          fetch_town_progress_cmd(dispatch),
          fetch_town_events_cmd(dispatch),
          fetch_daemon_lifecycle_cmd(dispatch),
          fetch_daemon_agent_cmd(dispatch),
        ]),
        {
          ..model,
          activity: Activity::Town,
          daemon_lifecycle: Some(result),
          daemon_status: daemon_lifecycle_label(result),
          dispatch_status: result.message,
        },
      )
    ManagedDaemon(Err(error)) =>
      (@rabbita.none, { ..model, daemon_status: error, dispatch_status: error })
    LoadedDaemonAgent(Ok(result)) =>
      (
        @rabbita.none,
        {
          ..model,
          daemon_agent: Some(result),
          daemon_status: daemon_agent_label(result),
        },
      )
    LoadedDaemonAgent(Err(error)) =>
      (@rabbita.none, { ..model, daemon_status: error })
    ManagedDaemonAgent(Ok(result)) =>
      (
        fetch_daemon_agent_cmd(dispatch),
        {
          ..model,
          daemon_agent: Some(result),
          daemon_status: daemon_agent_label(result),
          dispatch_status: result.message,
        },
      )
    ManagedDaemonAgent(Err(error)) =>
      (@rabbita.none, { ..model, daemon_status: error })
    RevealedSelection(Ok(result)) =>
      (
        @rabbita.none,
        {
          ..model,
          reveal_status: if result.ok {
            "\{result.status}: \{result.path}"
          } else {
            "\{result.status} (\{result.exit_code}) \{result.absolute_path} [\{result.workspace_id}]"
          },
        },
      )
    RevealedSelection(Err(error)) =>
      (@rabbita.none, { ..model, reveal_status: error })
    LocalFilesPicked(Ok(files)) =>
      if files.length() == 0 {
        (@rabbita.none, model)
      } else if model.selected_workspace_id == "" {
        (@rabbita.none, { ..model, inbox_status: "select a workspace first" })
      } else {
        let cmds : Array[@rabbita.Cmd] = []
        for file in files {
          cmds.push(import_local_file_cmd(dispatch, model, file))
        }
        (
          @rabbita.batch(cmds),
          {
            ..model,
            activity: Activity::Inbox,
            inbox_status: "importing \{files.length()} local file(s)",
          },
        )
      }
    LocalFilesPicked(Err(error)) =>
      (@rabbita.none, { ..model, inbox_status: "local import failed: \{error}" })
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
          fetch_review_diff_cmd(dispatch, model.selected_workspace_id, path),
        ])
      } else {
        @rabbita.batch([
          fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
          fetch_review_diff_cmd(dispatch, model.selected_workspace_id, path),
        ])
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
        @rabbita.batch([
          fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
          fetch_review_diff_cmd(dispatch, model.selected_workspace_id, path),
        ]),
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
          fetch_review_diff_cmd(dispatch, workspace_id, path),
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
    SetGoalTitle(title) => (@rabbita.none, { ..model, goal_title: title })
    SetGoalCadenceTicks(value) =>
      (@rabbita.none, { ..model, goal_cadence_ticks: value })
    SetGoalQualityThreshold(value) =>
      (@rabbita.none, { ..model, goal_quality_threshold: value })
    SetGoalSourcePolicy(value) =>
      (@rabbita.none, { ..model, goal_source_policy: value })
    CreateStandingGoal =>
      (
        create_standing_goal_cmd(dispatch, model),
        { ..model, dispatch_status: "creating standing watch" },
      )
    DispatchDaemonTick =>
      (
        dispatch_daemon_cmd(dispatch),
        { ..model, dispatch_status: "running daemon tick" },
      )
    FetchDaemonLifecycle =>
      (
        fetch_daemon_lifecycle_cmd(dispatch),
        { ..model, daemon_status: "checking daemon" },
      )
    StartDaemon =>
      (
        manage_daemon_cmd(dispatch, "start"),
        { ..model, daemon_status: "starting daemon" },
      )
    StopDaemon =>
      (
        manage_daemon_cmd(dispatch, "stop"),
        { ..model, daemon_status: "stopping daemon" },
      )
    RestartDaemon =>
      (
        manage_daemon_cmd(dispatch, "restart"),
        { ..model, daemon_status: "restarting daemon" },
      )
    EnableDaemonSupervision =>
      (
        set_daemon_supervision_cmd(dispatch, true),
        { ..model, daemon_status: "enabling supervision" },
      )
    DisableDaemonSupervision =>
      (
        set_daemon_supervision_cmd(dispatch, false),
        { ..model, daemon_status: "disabling supervision" },
      )
    InstallDaemonAgent =>
      (
        manage_daemon_agent_cmd(dispatch, "install"),
        { ..model, daemon_status: "installing LaunchAgent" },
      )
    UninstallDaemonAgent =>
      (
        manage_daemon_agent_cmd(dispatch, "uninstall"),
        { ..model, daemon_status: "removing LaunchAgent" },
      )
    RevealSelection =>
      (
        reveal_selection_cmd(dispatch, model),
        { ..model, reveal_status: "revealing selection" },
      )
    SetInboxTitle(title) => (@rabbita.none, { ..model, inbox_title: title })
    SetInboxContent(content) =>
      (@rabbita.none, { ..model, inbox_content: content, inbox_status: "draft" })
    SetImportUrl(url) =>
      (@rabbita.none, { ..model, import_url: url, inbox_status: "import draft" })
    SetImportNote(note) =>
      (@rabbita.none, { ..model, import_note: note, inbox_status: "import draft" })
    ImportUrlToInbox => {
      if model.import_url.trim().to_owned() == "" {
        (@rabbita.none, { ..model, inbox_status: "enter a URL to import" })
      } else {
        (
          import_url_cmd(dispatch, model),
          { ..model, inbox_status: "importing URL" },
        )
      }
    }
    ImportLocalFiles =>
      (
        pick_import_files_cmd(dispatch),
        { ..model, activity: Activity::Inbox, inbox_status: "opening file picker" },
      )
    PollDroppedImports =>
      (
        @rabbita.batch([
          take_dropped_imports_cmd(dispatch),
          schedule_import_drop_poll(dispatch),
        ]),
        model,
      )
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
    SetViewTitle(title) => (@rabbita.none, { ..model, view_title: title })
    SaveCurrentView =>
      (
        save_view_cmd(dispatch, model),
        { ..model, host_status: "saving view" },
      )
    SetTagValue(tag) => (@rabbita.none, { ..model, tag_value: tag })
    TagSelection =>
      (
        save_tag_cmd(dispatch, model),
        { ..model, reveal_status: "saving tag" },
      )
    NotifyDaily =>
      (
        notify_cmd(
          "Moondesk daily surface",
          "\{model.requests.length()} requests, \{model.runs.length()} runs, \{model.standing_goals.length()} standing goals",
        ),
        { ..model, notification_status: "notification requested" },
      )
    RefreshAll =>
      (
        @rabbita.batch([
          fetch_workspaces_cmd(dispatch),
          fetch_messages_cmd(dispatch),
          fetch_requests_cmd(dispatch),
          fetch_standing_goals_cmd(dispatch),
          fetch_analytics_cmd(dispatch),
          fetch_town_progress_cmd(dispatch),
          fetch_town_events_cmd(dispatch),
          fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
          fetch_daemon_lifecycle_cmd(dispatch),
          fetch_daemon_agent_cmd(dispatch),
          fetch_review_items_cmd(dispatch, model.selected_workspace_id),
          fetch_review_diff_cmd(dispatch, model.selected_workspace_id, model.selected_path),
          fetch_saved_views_cmd(dispatch),
          fetch_tags_cmd(dispatch),
        ]),
        { ..model, host_status: "refreshing" },
      )
  }
}

///|
fn render_activity_rail(
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
        a(
          class=class_name,
          title=item.label,
          href=activity_href(item.key),
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
      h3("Import"),
      input(
        class="line-input",
        value=model.import_url,
        placeholder="https://...",
        on_input=fn(value) { dispatch(SetImportUrl(value)) },
        "",
      ),
      textarea(
        class="side-textarea compact-textarea",
        rows=4,
        value=model.import_note,
        placeholder="Why this belongs in the inbox.",
        on_input=fn(value) { dispatch(SetImportNote(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(class="secondary-button", on_click=dispatch(ImportUrlToInbox), "Import URL"),
        button(class="secondary-button", on_click=dispatch(ImportLocalFiles), "Import Files"),
      ]),
      div(class="import-dropzone", [
        span(class="record-kind", "local"),
        strong("File and Image Intake"),
        small("Queued drops and pasted images are staged as inbox imports."),
      ]),
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
      div(class="toolbar-actions", [
        button(class="icon-button", title="Run Daemon Tick", on_click=dispatch(DispatchDaemonTick), "D"),
        button(class="icon-button", title="Refresh", on_click=dispatch(RefreshAll), "R"),
      ]),
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
    section(class="side-section", [
      h3("Standing Watch"),
      input(
        class="line-input",
        value=model.goal_title,
        placeholder="Watch title",
        on_input=fn(value) { dispatch(SetGoalTitle(value)) },
        "",
      ),
      div(class="field-grid compact-fields", [
        input(
          class="line-input",
          value=model.goal_cadence_ticks,
          placeholder="Cadence ticks",
          on_input=fn(value) { dispatch(SetGoalCadenceTicks(value)) },
          "",
        ),
        input(
          class="line-input",
          value=model.goal_quality_threshold,
          placeholder="Quality",
          on_input=fn(value) { dispatch(SetGoalQualityThreshold(value)) },
          "",
        ),
      ]),
      input(
        class="line-input",
        value=model.goal_source_policy,
        placeholder="Source policy",
        on_input=fn(value) { dispatch(SetGoalSourcePolicy(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(class="secondary-button", on_click=dispatch(CreateStandingGoal), "Create Watch"),
        button(class="secondary-button", on_click=dispatch(DispatchDaemonTick), "Run Tick"),
      ]),
      p(class="status-line", model.dispatch_status),
    ]),
    render_town_progress_panel(model),
    render_event_panel(model),
    render_daemon_lifecycle_panel(dispatch, model),
    render_standing_goal_list(model),
    render_request_list(model),
  ])
}

///|
fn render_town_progress_panel(model : Model) -> @rabbita.Html {
  match model.town_progress {
    Some(progress) =>
      section(class="side-section", [
        h3("Live Progress"),
        info_row("Daemon", "\{progress.daemon_status} / tick \{progress.daemon_tick}"),
        info_row("Running", if progress.daemon_running { "yes" } else { "no" }),
        info_row("Supervision", if progress.supervision_enabled { "enabled" } else { "disabled" }),
        info_row("Due", "\{progress.due_goal_count} / next \{progress.next_due_tick}"),
        info_row("Queued", "\{progress.request_count} requests / \{progress.dispatch_count} dispatches"),
        info_row("Outputs", "\{progress.message_count} messages / \{progress.run_count} runs"),
        info_row("Latest Request", empty_label(progress.latest_request)),
        info_row("Latest Message", empty_label(progress.latest_message)),
        info_row("Latest Dispatch", empty_label(progress.latest_dispatch)),
        info_row("Latest Run", latest_run_label(progress)),
      ])
    None =>
      section(class="side-section", [
        h3("Live Progress"),
        p(class="status-line", "waiting for progress"),
      ])
  }
}

///|
fn empty_label(value : String) -> String {
  if value == "" { "none" } else { value }
}

///|
fn latest_run_label(progress : TownProgress) -> String {
  if progress.latest_run == "" {
    "none"
  } else {
    "\{progress.latest_run} / \{progress.latest_run_status} / \{progress.latest_run_artifacts} artifacts"
  }
}

///|
fn render_event_panel(model : Model) -> @rabbita.Html {
  section(class="side-section", [
    h3("Events"),
    if model.events.length() == 0 {
      p(class="status-line", "no recent events")
    } else {
      div(
        class="event-list",
        model.events[:event_limit(model.events)].map(event =>
          div(class="event-row " + event.severity, [
            span(class="record-kind", event.severity),
            strong(event.title),
            small("\{event.source} / \{event.kind} / \{event.id} / \{event_time_label(event)}"),
            p(event.detail),
          ])
        ),
      )
    },
  ])
}

///|
fn event_limit(events : Array[DeskEvent]) -> Int {
  if events.length() > 8 { 8 } else { events.length() }
}

///|
fn event_time_label(event : DeskEvent) -> String {
  let tick = if event.tick > 0 { "tick \{event.tick}" } else { "no tick" }
  let run = if event.run_id == "" { "no run" } else { event.run_id }
  let time = if event.created_at == "" { empty_label(event.path) } else { event.created_at }
  "\{tick} / \{run} / \{time}"
}

///|
fn render_daemon_lifecycle_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="side-section", [
    h3("Daemon Lifecycle"),
    match model.daemon_lifecycle {
      Some(result) =>
        div(class="daemon-state", [
          info_row("Result", if result.ok { "ok" } else { "failed" }),
          info_row("Action", result.action),
          info_row("Status", if result.running { "running" } else { result.status }),
          info_row("PID", if result.pid > 0 { result.pid.to_string() } else { "none" }),
          info_row("Command", result.command),
          info_row("CWD", result.cwd),
          info_row("Started", if result.started_at == "" { "none" } else { result.started_at }),
          info_row("Stopped", if result.stopped_at == "" { "none" } else { result.stopped_at }),
          info_row("Desired", result.desired_state),
          info_row("Supervision", if result.supervision_enabled { "enabled" } else { "disabled" }),
          info_row("Restarts", result.restart_count.to_string()),
          info_row("Health", if result.last_health_check == "" { "none" } else { result.last_health_check }),
          info_row("State File", result.pid_file),
          info_row("Policy File", result.policy_file),
          info_row("Logs", daemon_log_label(result)),
        ])
      None =>
        div(class="daemon-state", [
          info_row("Status", "unknown"),
          info_row("PID", "none"),
        ])
    },
    div(class="toolbar-actions stack-actions", [
      button(class="secondary-button", on_click=dispatch(StartDaemon), "Start"),
      button(class="secondary-button", on_click=dispatch(StopDaemon), "Stop"),
      button(class="secondary-button", on_click=dispatch(RestartDaemon), "Restart"),
      button(class="secondary-button", on_click=dispatch(FetchDaemonLifecycle), "Status"),
      button(class="secondary-button", on_click=dispatch(EnableDaemonSupervision), "Supervise"),
      button(class="secondary-button", on_click=dispatch(DisableDaemonSupervision), "Unsupervise"),
      button(class="secondary-button", on_click=dispatch(InstallDaemonAgent), "Install Agent"),
      button(class="secondary-button", on_click=dispatch(UninstallDaemonAgent), "Remove Agent"),
    ]),
    render_daemon_agent_state(model),
    p(class="status-line", model.daemon_status),
  ])
}

///|
fn render_daemon_agent_state(model : Model) -> @rabbita.Html {
  match model.daemon_agent {
    Some(agent) =>
      div(class="daemon-state", [
        info_row("Agent", if agent.installed { if agent.loaded { "loaded" } else { "installed" } } else { "none" }),
        info_row("Result", if agent.ok { "ok" } else { "failed \{agent.exit_code}" }),
        info_row("Action", agent.action),
        info_row("Label", agent.label),
        info_row("Plist", agent.plist_path),
        info_row("Command", agent.command),
        info_row("CWD", agent.cwd),
      ])
    None => div(class="daemon-state", [info_row("Agent", "unknown")])
  }
}

///|
fn daemon_log_label(result : DaemonLifecycleResult) -> String {
  if result.stdout_path == "" && result.stderr_path == "" {
    "none"
  } else if result.stderr_path == "" {
    result.stdout_path
  } else {
    result.stdout_path + " / " + result.stderr_path
  }
}

///|
fn render_standing_goal_list(model : Model) -> @rabbita.Html {
  div(
    class="side-records",
    model.standing_goals.map(goal => {
      div(class="side-record", [
        span(class="record-kind", if goal.enabled { "enabled" } else { "paused" }),
        strong(goal.title),
        small("\{goal.target_book_id} / every \{goal.cadence_ticks} ticks"),
        small("next \{goal.next_due_tick} / last \{last_run_label(goal)}"),
        small("quality \{goal.quality_threshold}% / \{goal.prompt}"),
      ])
    }),
  )
}

///|
fn last_run_label(goal : StandingGoalRecord) -> String {
  match goal.last_run_tick {
    Some(tick) => tick.to_string()
    None => "never"
  }
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
    render_moonclaw_progress_panel(model),
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
fn render_moonclaw_progress_panel(model : Model) -> @rabbita.Html {
  match model.moonclaw_progress {
    Some(progress) =>
      section(class="side-section", [
        h3("Progress"),
        info_row("Runs", "\{progress.ready_count} ready / \{progress.run_count} total"),
        info_row("Artifacts", progress.artifact_count.to_string()),
        info_row("Latest", if progress.latest_run == "" {
          "none"
        } else {
          "\{progress.latest_run} / \{progress.latest_status}"
        }),
      ])
    None =>
      section(class="side-section", [
        h3("Progress"),
        p(class="status-line", "waiting for run progress"),
      ])
  }
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
      info_row("Goals", model.standing_goals.length().to_string()),
      info_row("Favorites", model.favorites.length().to_string()),
      button(class="primary-button full", on_click=dispatch(NotifyDaily), "Notify Summary"),
      p(class="status-line", model.notification_status),
    ]),
    render_saved_views_panel(dispatch, model),
    render_review_queue_panel(dispatch, model),
    section(class="side-section", [
      h3("Calendar Export"),
      a(
        class="secondary-button link-button full",
        href="/api/town/calendar.ics",
        target=@html.Target::Blank,
        rel="noreferrer",
        "Open ICS",
      ),
    ]),
    render_cadence_panel(model),
    render_cadence_calendar(model),
    render_analytics_panel(model),
    section(class="side-section", [
      h3("Export Snapshot"),
      pre(class="source-block compact", code(export_snapshot(model))),
    ]),
  ])
}

///|
fn render_saved_views_panel(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  section(class="side-section", [
    h3("Saved Views"),
    input(
      class="line-input",
      value=model.view_title,
      placeholder="View title",
      on_input=fn(value) { dispatch(SetViewTitle(value)) },
      "",
    ),
    button(class="secondary-button full", on_click=dispatch(SaveCurrentView), "Save Current View"),
    div(
      class="mini-list",
      model.saved_views.map(view => {
        button(
          class="mini-link",
          title="\{view.id} / \{view.updated_at}",
          on_click=dispatch(SelectSearchHit(view.workspace_id, view.path)),
          [
            span(view.title),
            small(if view.query == "" {
              "\{view.path} / \{view.created_at}"
            } else {
              "\{view.query} / \{view.path}"
            }),
          ],
        )
      }),
    ),
  ])
}

///|
fn render_review_queue_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="side-section", [
    h3("Review Queue"),
    if model.review_items.length() == 0 {
      p(class="status-line", "none")
    } else {
      div(
        class="mini-list",
        model.review_items[:review_limit(model.review_items)].map(item => {
          let msg = if item.workspace_id == "" {
            SelectActivity(Activity::Town)
          } else {
            SelectSearchHit(item.workspace_id, item.path)
          }
          button(
            class="mini-link",
            title="\{item.id} / \{item.kind} / \{item.detail}",
            on_click=dispatch(msg),
            [
              span(item.title),
              small("\{item.status} / \{item.path}"),
            ],
          )
        }),
      )
    },
  ])
}

///|
fn review_limit(items : Array[ReviewItem]) -> Int {
  if items.length() > 8 { 8 } else { items.length() }
}

///|
fn render_cadence_panel(model : Model) -> @rabbita.Html {
  section(class="side-section", [
    h3("Cadence"),
    div(
      class="cadence-list",
      model.standing_goals.map(goal => {
        let due_label = match model.analytics {
          Some(analytics) if analytics.daemon_tick >= goal.next_due_tick => "due"
          Some(analytics) => "\{goal.next_due_tick - analytics.daemon_tick} ticks"
          None => "next \{goal.next_due_tick}"
        }
        div(class="cadence-row", [
          span(class="record-kind", due_label),
          div([
            strong(goal.title),
            small("\{goal.source_policy} / every \{goal.cadence_ticks}"),
          ]),
        ])
      }),
    ),
  ])
}

///|
fn render_cadence_calendar(model : Model) -> @rabbita.Html {
  let tick = match model.analytics {
    Some(analytics) => analytics.daemon_tick
    None => 0
  }
  let cells = if model.standing_goals.length() == 0 {
    [p(class="status-line", "no standing watches")]
  } else {
    model.standing_goals.map(goal => {
      let class_name = "calendar-cell " + cadence_state(tick, goal)
      div(class=class_name, [
        span(class="record-kind", cadence_due_label(tick, goal.next_due_tick)),
        strong(goal.title),
        small("tick \{goal.next_due_tick}"),
        small("every \{goal.cadence_ticks} ticks"),
      ])
    })
  }
  section(class="side-section", [
    h3("Calendar"),
    div(class="calendar-grid", cells),
  ])
}

///|
fn cadence_state(tick : Int, goal : StandingGoalRecord) -> String {
  if tick > 0 && tick >= goal.next_due_tick {
    "due"
  } else if tick > 0 && goal.next_due_tick - tick <= 12 {
    "soon"
  } else {
    "scheduled"
  }
}

///|
fn cadence_due_label(tick : Int, next_due_tick : Int) -> String {
  if tick > 0 {
    let delta = next_due_tick - tick
    if delta <= 0 {
      "due"
    } else {
      "+\{delta}"
    }
  } else {
    "tick"
  }
}

///|
fn render_analytics_panel(model : Model) -> @rabbita.Html {
  match model.analytics {
    Some(analytics) => {
      let outcomes = analytics.no_changes +
        analytics.updates +
        analytics.needs_review +
        analytics.failures +
        analytics.deferred
      section(class="side-section", [
        h3("Analytics"),
        info_row("Daemon", "tick \{analytics.daemon_tick}"),
        info_row("Goals", "\{analytics.standing_goal_count} total"),
        info_row("Due", "\{analytics.due_goal_count} / active \{analytics.active_goal_count}"),
        info_row("Next Due", analytics.next_due_tick.to_string()),
        info_row("Requests", analytics.request_count.to_string()),
        info_row("Messages", analytics.message_count.to_string()),
        info_row("Runs", analytics.run_count.to_string()),
        info_row("Watcher", "\{analytics.watcher_run_count} runs"),
        info_row("No-change", analytics.no_changes.to_string()),
        info_row("Updates", analytics.updates.to_string()),
        info_row("Review", analytics.needs_review.to_string()),
        info_row("Failures", analytics.failures.to_string()),
        info_row("Deferred", analytics.deferred.to_string()),
        info_row("Events", analytics.event_count.to_string()),
        info_row("Failure Events", analytics.failure_event_count.to_string()),
        info_row("Review Events", analytics.review_event_count.to_string()),
        info_row("Review Queue", analytics.review_item_count.to_string()),
        info_row("Last Failure", empty_label(analytics.last_failure)),
        div(class="outcome-mix", [
          outcome_row("updates", analytics.updates, outcomes, "updates"),
          outcome_row("no-change", analytics.no_changes, outcomes, "quiet"),
          outcome_row("review", analytics.needs_review, outcomes, "review"),
          outcome_row("failures", analytics.failures, outcomes, "failure"),
          outcome_row("deferred", analytics.deferred, outcomes, "deferred"),
        ]),
      ])
    }
    None =>
      section(class="side-section", [
        h3("Analytics"),
        p(class="status-line", "waiting for town analytics"),
      ])
  }
}

///|
fn outcome_row(label : String, value : Int, total : Int, tone : String) -> @rabbita.Html {
  div(class="outcome-row " + tone, [
    span(label),
    code("\{value} / \{percent_text(value, total)}"),
  ])
}

///|
fn percent_text(value : Int, total : Int) -> String {
  if total <= 0 {
    "0%"
  } else {
    "\{value * 100 / total}%"
  }
}

///|
fn daemon_snapshot_label(model : Model) -> String {
  match model.analytics {
    Some(analytics) => "tick \{analytics.daemon_tick}"
    None => "unknown"
  }
}

///|
fn export_snapshot(model : Model) -> String {
  "Moondesk snapshot\n" +
  "workspace: \{workspace_name(model)}\n" +
  "selected: \{model.selected_path}\n" +
  "requests: \{model.requests.length()}\n" +
  "runs: \{model.runs.length()}\n" +
  "messages: \{model.town_messages.length()}\n" +
  "standing goals: \{model.standing_goals.length()}\n" +
  "daemon: \{daemon_snapshot_label(model)}\n" +
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
          class="secondary-button",
          on_click=dispatch(RevealSelection),
          "Reveal",
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
      info_row("Reveal", model.reveal_status),
      button(
        class="secondary-button full",
        on_click=dispatch(StageSelectedLink),
        "Copy Link To Inbox",
      ),
    ]),
    section(class="inspector-section", [
      h3("Tags"),
      input(
        class="line-input",
        value=model.tag_value,
        placeholder="tag",
        on_input=fn(value) { dispatch(SetTagValue(value)) },
        "",
      ),
      button(class="secondary-button full", on_click=dispatch(TagSelection), "Tag Selection"),
      render_tag_list(model),
    ]),
    render_review_diff_panel(model),
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
fn render_review_diff_panel(model : Model) -> @rabbita.Html {
  section(class="inspector-section", [
    h3("Review"),
    match model.review_diff {
      Some(diff) =>
        div(class="review-diff", [
          info_row("Base", empty_label(diff.base_path)),
          info_row("Path", diff.path),
          info_row("Workspace", diff.workspace_id),
          info_row("Compare", empty_label(diff.comparison_path)),
          info_row("Ready", if diff.ok { "yes" } else { "no" }),
          info_row("Added", diff.added.to_string()),
          info_row("Removed", diff.removed.to_string()),
          info_row("Changed", if diff.changed { "yes" } else { "no" }),
          pre(class="source-block compact", code(diff.body)),
        ])
      None =>
        p(class="status-line", "waiting for diff")
    },
  ])
}

///|
fn render_tag_list(model : Model) -> @rabbita.Html {
  let tags = selection_tags(model)
  if tags.length() == 0 {
    p(class="status-line", "none")
  } else {
    div(
      class="mini-list",
      tags.map(tag =>
        span(
          class="option-chip active",
          title="\{tag.id} / \{tag.created_at}",
          tag.tag,
        )
      ),
    )
  }
}

///|
fn selection_tags(model : Model) -> Array[TagRecord] {
  let selected : Array[TagRecord] = []
  for tag in model.tags {
    if tag.workspace_id == model.selected_workspace_id && tag.path == model.selected_path {
      selected.push(tag)
    }
  }
  selected
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
          palette_command(dispatch, "Import URL", "Open the inbox importer", SelectActivity(Activity::Inbox)),
          palette_command(dispatch, "Submit to Town", "Send selected context to Moontown", SubmitRequest),
          palette_command(dispatch, "Run Daemon Tick", "Dispatch one Moontown scheduler tick", DispatchDaemonTick),
          palette_command(dispatch, "Start Daemon", "Start the managed Moontown daemon loop", StartDaemon),
          palette_command(dispatch, "Enable Supervision", "Restart the daemon when the policy says it should run", EnableDaemonSupervision),
          palette_command(dispatch, "Stop Daemon", "Stop the managed Moontown daemon loop", StopDaemon),
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
      render_activity_rail(model),
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
  ignore(fetch_standing_goals_cmd)
  ignore(fetch_analytics_cmd)
  ignore(fetch_town_progress_cmd)
  ignore(fetch_moonclaw_progress_cmd)
  ignore(fetch_town_events_cmd)
  ignore(fetch_events_cmd)
  ignore(fetch_review_items_cmd)
  ignore(fetch_review_diff_cmd)
  ignore(fetch_saved_views_cmd)
  ignore(fetch_tags_cmd)
  ignore(fetch_daemon_agent_cmd)
  ignore(fetch_search_cmd)
  ignore(save_inbox_cmd)
  ignore(import_url_cmd)
  ignore(import_local_file_cmd)
  ignore(save_view_cmd)
  ignore(save_tag_cmd)
  ignore(submit_request_cmd)
  ignore(create_standing_goal_cmd)
  ignore(dispatch_daemon_cmd)
  ignore(set_daemon_supervision_cmd)
  ignore(manage_daemon_agent_cmd)
  ignore(pick_import_files_cmd)
  ignore(take_dropped_imports_cmd)
  ignore(schedule_import_drop_poll)
  ignore(reveal_selection_cmd)
  ignore(notify_cmd)
}

///|
fn main {
  let (dispatch, cell) = @rabbita.cell_with_dispatch(model=init_model(), update~, view=(
    dispatch,
    model,
  ) => render_app(dispatch, model))
  let app = @rabbita.new(cell)
  app.with_init(@rabbita.batch([
    fetch_workspaces_cmd(dispatch),
    schedule_import_drop_poll(dispatch),
  ]))
  app.mount("app")
}
