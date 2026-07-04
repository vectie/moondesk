///|
enum DeskSortKey {
  SortByName
  SortByKind
  SortByLayer
  SortByModified
  SortBySize
} derive(Eq)

///|
enum DeskDensity {
  DeskDensityComfortable
  DeskDensityCompact
} derive(Eq)

///|
struct Model {
  bootstrapped : Bool
  workspace_mode : WorkspaceMode
  activity : Activity
  command_open : Bool
  command_query : String
  loading : Bool
  host_status : String
  workspace_root_path : String
  workspace_suite_root_path : String
  workspace_library_path : String
  workspace_books_root_path : String
  moonsuite_products : Array[MoonSuiteProduct]
  workspaces : Array[@desk.DeskWorkspace]
  selected_workspace_id : String
  new_book_name : String
  new_book_id : String
  new_book_status : String
  import_book_path : String
  import_book_status : String
  current_directory : String
  desk_location_input : String
  desk_filter_query : String
  desk_back_stack : Array[String]
  desk_forward_stack : Array[String]
  entries : Array[@desk.DeskFileEntry]
  desk_sort_key : DeskSortKey
  desk_sort_desc : Bool
  desk_density : DeskDensity
  desk_selected_paths : Array[String]
  desk_selection_anchor : String
  desk_new_item_name : String
  desk_new_item_status : String
  desk_rename_editing_path : String
  desk_rename_name : String
  desk_rename_status : String
  desk_move_target_directory : String
  desk_move_status : String
  desk_clipboard_paths : Array[String]
  desk_clipboard_workspace_id : String
  desk_clipboard_operation : String
  desk_clipboard_status : String
  desk_path_status : String
  desk_copy_status : String
  desk_trash_status : String
  desk_last_trash_path : String
  desk_trash_entries : Array[DeskTrashEntry]
  selected_path : String
  primary_preview_path : String
  preview : @desk.DeskPreview?
  preview_status : String
  markdown_editor_path : String
  markdown_editor_content : String
  markdown_editor_status : String
  request_prompt : String
  request_status : String
  requests : Array[RequestRecord]
  standing_goals : Array[StandingGoalRecord]
  analytics : TownAnalytics?
  town_progress : TownProgress?
  moonclaw_progress : MoonclawProgress?
  daemon_lifecycle : DaemonLifecycleResult?
  launch_agent : LaunchAgentResult?
  moonclaw_daemon : MoonClawDaemonStatus?
  mooncode_sessions : Array[MoonCodeSession]
  selected_mooncode_session_id : String
  mooncode_new_chat_active : Bool
  mooncode_stream_session_id : String
  mooncode_stream_cursor : Int
  mooncode_stream_status : String
  mooncode_stream_checkpoint_session_id : String
  mooncode_stream_checkpoint_status : String
  mooncode_stream_events : Array[MoonCodeEvent]
  mooncode_prompt : String
  mooncode_model : String
  mooncode_web_search : Bool
  mooncode_composer_status : String
  mooncode_next_client_turn_index : Int
  mooncode_optimistic_rows : Array[MoonCodeOptimisticRow]
  events : Array[DeskEvent]
  review_items : Array[ReviewItem]
  review_decision_note : String
  review_decision_status : String
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
  recent_paths : Array[String]
  view_title : String
  goal_title : String
  goal_cadence_ticks : String
  goal_review_policy : String
  goal_source_policy : String
  book_base_types : Array[BookBaseTypeRecord]
  selected_book_base_type : String
  book_patterns : Array[BookPatternRecord]
  selected_book_pattern_id : String
  book_pattern_book_id : String
  book_pattern_topic : String
  book_pattern_purpose : String
  book_pattern_websites : String
  book_pattern_cadence_minutes : String
  book_pattern_source_policy : String
  book_pattern_notify_rule : String
  book_pattern_skill_pack : String
  book_pattern_analysis_method : String
  book_pattern_last_book_id : String
  book_pattern_status : String
  dispatch_status : String
  daemon_status : String
  notification_status : String
}

///|
enum Msg {
  Bootstrap
  LoadedWorkspaceMetadata(Result[WorkspaceMetadata, String])
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
  LoadedSavedViews(Result[Array[SavedViewRecord], String])
  LoadedSearch(Result[Array[SearchHit], String])
  LoadedDeskTrash(Result[Array[DeskTrashEntry], String])
  LoadedBookBaseTypes(Result[Array[BookBaseTypeRecord], String])
  LoadedBookPatterns(Result[Array[BookPatternRecord], String])
  CreatedBlankMoonBook(Result[CreatedWorkspace, String])
  ImportedMoonBook(Result[CreatedWorkspace, String])
  LocalMoonBookFolderPicked(Result[Array[LocalImportFile], String])
  LocalMoonBookArchivePicked(Result[LocalImportFile, String])
  CreatedDeskEntry(Result[DeskEntryCreated, String])
  RenamedDeskEntry(Result[DeskEntryRenamed, String])
  MovedDeskEntry(Result[DeskEntryMoved, String])
  CopiedDeskEntry(Result[DeskEntryCopied, String])
  TrashedDeskEntry(Result[DeskEntryTrashed, String])
  RestoredDeskEntry(Result[DeskEntryRestored, String])
  ImportedDeskFiles(Result[DeskFilesImported, String])
  SavedInbox(Result[InboxCreated, String])
  SavedMarkdownEdit(Result[MarkdownEditResult, String])
  ImportedInbox(Result[InboxImportResult, String])
  SavedView(Result[SavedViewRecord, String])
  SubmittedRequest(Result[RequestRecord, String])
  CreatedStandingGoal(Result[StandingGoalRecord, String])
  DecidedReviewItem(Result[ReviewDecisionResult, String])
  CreatedBookFromPattern(Result[BookPatternCreationResult, String])
  ExportedAppToolPortable(Result[Json, String])
  ExportedAllAppToolPortable(Result[Json, String])
  DispatchedDaemon(Result[DaemonControlResult, String])
  LoadedDaemonLifecycle(Result[DaemonLifecycleResult, String])
  ManagedDaemon(Result[DaemonLifecycleResult, String])
  LoadedLaunchAgent(Result[LaunchAgentResult, String])
  ManagedLaunchAgent(Result[LaunchAgentResult, String])
  LoadedMoonClawDaemon(Result[MoonClawDaemonStatus, String])
  LoadedMoonClawModels(Result[MoonClawModelsResult, String])
  LoadedMoonCodeSessions(Result[Array[MoonCodeSession], String])
  LoadedMoonCodeStream(String, Result[MoonCodeStreamPoll, String])
  SavedMoonCodeStreamCheckpoint(String, Result[MoonCodeStreamState, String])
  CreatedMoonCodeSession(Result[MoonCodeSession, String])
  CompletedMoonCodeCommand(Result[MoonCodeSession, String])
  StartedMoonCodeRuntime(String, Result[Json, String])
  RevealedSelection(Result[RevealResult, String])
  LocalFilesPicked(Result[Array[LocalImportFile], String])
  SelectWorkspaceMode(WorkspaceMode)
  SelectActivity(Activity)
  SelectMoonCodeSession(String)
  NewMoonCodeSession
  SetMoonCodePrompt(String)
  SendMoonCodeMessage
  PollMoonCodeSessions
  SelectWorkspace(String)
  SelectPath(String)
  OpenDirectory(String)
  NavigateDeskBack
  NavigateDeskForward
  SetDeskLocationInput(String)
  OpenDeskLocation
  OpenQuickPath(String)
  SelectSearchHit(String, String)
  SetNewBookName(String)
  SetNewBookId(String)
  CreateBlankMoonBook
  SetImportBookPath(String)
  ImportMoonBook
  PickImportMoonBookFolder
  PickImportMoonBookArchive
  ToggleCommand
  SetCommandQuery(String)
  SetRequestPrompt(String)
  SubmitRequest
  SetGoalTitle(String)
  SetGoalCadenceTicks(String)
  SetGoalReviewPolicy(String)
  SetGoalSourcePolicy(String)
  CreateStandingGoal
  SetBookPatternBookId(String)
  SetBookPatternTopic(String)
  SetBookPatternPurpose(String)
  SetBookPatternWebsites(String)
  SetBookPatternCadenceMinutes(String)
  SetBookPatternSourcePolicy(String)
  SetBookPatternNotifyRule(String)
  SetBookPatternSkillPack(String)
  SetBookPatternAnalysisMethod(String)
  SelectBookBaseType(String)
  SelectBookPattern(String)
  CreateBookFromPattern
  ExportAppToolPortable
  ExportAllAppToolPortable
  ControlDaemonTick
  FetchDaemonLifecycle
  StartDaemon
  StopDaemon
  RestartDaemon
  EnableDaemonSupervision
  DisableDaemonSupervision
  InstallLaunchAgent
  UninstallLaunchAgent
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
  StartMarkdownEdit
  SetMarkdownEditorContent(String)
  CancelMarkdownEdit
  SaveMarkdownEdit
  StageSelectedLink
  SetSearchQuery(String)
  SearchNow
  SetDeskSort(DeskSortKey)
  SetDeskFilterQuery(String)
  SetDeskDensity(DeskDensity)
  DeskKeyDown(String, Bool, Bool)
  DeskMouseDown(String, Bool, Bool)
  ClearDeskSelection
  SetDeskNewItemName(String)
  CreateDeskFolder
  CreateDeskMarkdown
  ImportLocalFilesToDesk
  ImportLocalFolderToDesk
  StartDeskRename
  CancelDeskRename
  SetDeskRenameName(String)
  RenameDeskSelection
  SetDeskMoveTargetDirectory(String)
  MoveDeskSelection
  CopyDeskSelection
  CutDeskSelection
  PasteDeskClipboard
  CopyDeskPath
  DuplicateDeskSelection
  TrashDeskSelection
  RestoreLastTrashedDeskEntry
  RestoreDeskTrashEntry(String)
  ToggleFavorite(String)
  SetViewTitle(String)
  SaveCurrentView
  SetReviewDecisionNote(String)
  DecideReviewItem(ReviewItem, String)
  NotifyDaily
  RefreshAll
}
