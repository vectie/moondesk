///|
struct Model {
  workspace_mode : WorkspaceMode
  activity : Activity
  command_open : Bool
  drawer_tab : DrawerTab
  loading : Bool
  host_status : String
  workspaces : Array[@desk.DeskWorkspace]
  selected_workspace_id : String
  current_directory : String
  entries : Array[@desk.DeskFileEntry]
  selected_path : String
  primary_preview_path : String
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
  launch_agent : LaunchAgentResult?
  moonclaw_daemon : MoonClawDaemonStatus?
  moonclaw_models : Array[MoonClawModel]
  mooncode_sessions : Array[MoonCodeSession]
  selected_mooncode_session_id : String
  mooncode_capabilities : MoonCodeCapabilities?
  mooncode_status : String
  mooncode_stream_session_id : String
  mooncode_stream_cursor : Int
  mooncode_stream_status : String
  mooncode_stream_checkpoint_session_id : String
  mooncode_stream_checkpoint_status : String
  mooncode_stream_events : Array[MoonCodeEvent]
  mooncode_runtime_event_sink_session_id : String
  mooncode_runtime_event_sink_status : String
  mooncode_runtime_event_sink : MoonCodeRuntimeEventSink?
  mooncode_change_set_session_id : String
  mooncode_change_set_status : String
  mooncode_change_set : MoonCodeChangeSet?
  mooncode_eval_report_session_id : String
  mooncode_eval_report_status : String
  mooncode_eval_report : MoonCodeEvalReport?
  mooncode_runtime_handoff_session_id : String
  mooncode_runtime_handoff_status : String
  mooncode_runtime_handoff : MoonCodeRuntimeHandoff?
  mooncode_patch_set_session_id : String
  mooncode_patch_set_status : String
  mooncode_patch_set : MoonCodePatchSet?
  mooncode_tool_approvals_session_id : String
  mooncode_tool_approvals_status : String
  mooncode_tool_approvals : MoonCodeToolApprovals?
  mooncode_tool_authorization_session_id : String
  mooncode_tool_authorization_status : String
  mooncode_tool_authorization : MoonCodeToolAuthorization?
  mooncode_test_runs_session_id : String
  mooncode_test_runs_status : String
  mooncode_test_runs : MoonCodeTestRuns?
  mooncode_package_candidates_session_id : String
  mooncode_package_candidates_status : String
  mooncode_package_candidates : MoonCodePackageCandidates?
  mooncode_action_plan_session_id : String
  mooncode_action_plan_status : String
  mooncode_action_plan : MoonCodeActionPlan?
  mooncode_readiness_session_id : String
  mooncode_readiness_status : String
  mooncode_readiness : MoonCodeReadiness?
  mooncode_runtime_evidence_session_id : String
  mooncode_runtime_evidence_status : String
  mooncode_runtime_evidence : MoonCodeRuntimeEvidence?
  mooncode_command_queue_session_id : String
  mooncode_command_queue_status : String
  mooncode_command_queue : MoonCodeCommandQueue?
  mooncode_runtime_command_feed_session_id : String
  mooncode_runtime_command_feed_status : String
  mooncode_runtime_command_feed : MoonCodeRuntimeCommandFeed?
  mooncode_runtime_replay_session_id : String
  mooncode_runtime_replay_status : String
  mooncode_runtime_replay : MoonCodeRuntimeReplayState?
  mooncode_preflight_session_id : String
  mooncode_preflight_status : String
  mooncode_preflights : Array[MoonCodeCommandPreflight]
  mooncode_runtime_receipt_session_id : String
  mooncode_runtime_receipt_status : String
  mooncode_runtime_receipt : MoonCodeRuntimeReceiptState?
  mooncode_runtime_claim_session_id : String
  mooncode_runtime_claim_status : String
  mooncode_runtime_claim : MoonCodeRuntimeClaimState?
  mooncode_prompt : String
  mooncode_model : String
  mooncode_web_search : Bool
  mooncode_composer_status : String
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
  LoadedBookBaseTypes(Result[Array[BookBaseTypeRecord], String])
  LoadedBookPatterns(Result[Array[BookPatternRecord], String])
  SavedInbox(Result[InboxCreated, String])
  ImportedInbox(Result[InboxImportResult, String])
  SavedView(Result[SavedViewRecord, String])
  SavedTag(Result[TagRecord, String])
  SubmittedRequest(Result[RequestRecord, String])
  CreatedStandingGoal(Result[StandingGoalRecord, String])
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
  LoadedMoonCodeCapabilities(Result[MoonCodeCapabilities, String])
  LoadedMoonCodeStream(String, Result[MoonCodeStreamPoll, String])
  SavedMoonCodeStreamCheckpoint(String, Result[MoonCodeStreamState, String])
  LoadedMoonCodeRuntimeEventSink(
    String,
    Result[MoonCodeRuntimeEventSink, String],
  )
  LoadedMoonCodeChangeSet(String, Result[MoonCodeChangeSet, String])
  LoadedMoonCodeEvalReport(String, Result[MoonCodeEvalReport, String])
  LoadedMoonCodeRuntimeHandoff(String, Result[MoonCodeRuntimeHandoff, String])
  LoadedMoonCodePatchSet(String, Result[MoonCodePatchSet, String])
  LoadedMoonCodeToolApprovals(String, Result[MoonCodeToolApprovals, String])
  LoadedMoonCodeToolAuthorization(
    String,
    String,
    Result[MoonCodeToolAuthorization, String],
  )
  LoadedMoonCodeTestRuns(String, Result[MoonCodeTestRuns, String])
  LoadedMoonCodePackageCandidates(String, Result[MoonCodePackageCandidates, String])
  LoadedMoonCodeActionPlan(String, Result[MoonCodeActionPlan, String])
  LoadedMoonCodeReadiness(
    String,
    Result[MoonCodeReadiness, String],
  )
  LoadedMoonCodeRuntimeEvidence(String, Result[MoonCodeRuntimeEvidence, String])
  LoadedMoonCodeCommandQueue(String, Result[MoonCodeCommandQueue, String])
  LoadedMoonCodeRuntimeCommandFeed(
    String,
    Result[MoonCodeRuntimeCommandFeed, String],
  )
  LoadedMoonCodeRuntimeReplay(
    String,
    Result[MoonCodeRuntimeReplayState, String],
  )
  LoadedMoonCodeCommandPreflight(
    String,
    String,
    Result[MoonCodeCommandPreflight, String],
  )
  LoadedMoonCodeRuntimeReceipt(
    String,
    Result[MoonCodeRuntimeReceiptState, String],
  )
  LoadedMoonCodeRuntimeClaimState(
    String,
    Result[MoonCodeRuntimeClaimState, String],
  )
  ClaimedMoonCodeRuntime(
    String,
    Bool,
    Result[Json, String],
  )
  AckedMoonCodeRuntimeCommand(
    String,
    String,
    String,
    Result[Json, String],
  )
  CreatedMoonCodeSession(Result[MoonCodeSession, String])
  CompletedMoonCodeCommand(Result[MoonCodeSession, String])
  RevealedSelection(Result[RevealResult, String])
  LocalFilesPicked(Result[Array[LocalImportFile], String])
  SelectWorkspaceMode(WorkspaceMode)
  SelectActivity(Activity)
  SelectDrawerTab(DrawerTab)
  SelectMoonCodeSession(String)
  NewMoonCodeSession
  SetMoonCodePrompt(String)
  SetMoonClawModel(String)
  ToggleMoonCodeWebSearch
  SendMoonCodeMessage
  RunMoonCodeCommand(String)
  RunMoonCodeCommandForPath(String, String)
  RunMoonCodeCommandWithMessage(String, String, String, String)
  RunMoonCodeCommandOverride(String, String)
  RunMoonCodeRuntimeLoop
  StartMoonCodeRuntimeService
  RanMoonCodeRuntimeLoop(String, Result[MoonCodeSession, String])
  StartedMoonCodeRuntimeService(String, Result[MoonCodeSession, String])
  ProbeMoonCodeToolAuthorization(String)
  ClaimMoonCodeRuntime(Bool)
  AckMoonCodeRuntimeCommand(String, String)
  PollMoonCodeSessions
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
