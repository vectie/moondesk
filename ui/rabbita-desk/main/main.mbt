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
  Agents
  Town
  Runs
  Settings
} derive(Eq)

///|
enum WorkspaceMode {
  MoonWiki
  MoonCode
} derive(Eq)

///|
struct ActivityButton {
  key : Activity
  icon : String
  label : String
}

///|
enum DrawerTab {
  DrawerRequests
  DrawerMessages
  DrawerRuns
  DrawerAgents
  DrawerRecent
} derive(Eq)

///|
struct DrawerTabButton {
  key : DrawerTab
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
struct AgentDaemonStatus {
  ok : Bool
  running : Bool
  port : Int
  pid : Int
  info_path : String
  moonclaw_root : String
  message : String
} derive(FromJson)

///|
struct AgentModel {
  name : String
} derive(FromJson)

///|
struct AgentModelsResult {
  ok : Bool
  daemon : AgentDaemonStatus
  models : Array[AgentModel]
} derive(FromJson)

///|
struct AgentMessage {
  id : String?
  role : String
  content : String
  status : String
  created_at : String
} derive(FromJson)

///|
struct MoonCodeEvent {
  id : String
  lane : String
  kind : String
  title : String
  status : String
  created_at : String
  detail : String
  path : String
  diff : String
  command : String
  exit_code : Int
} derive(FromJson)

///|
struct MoonCodeSummary {
  protocol : String
  session_id : String
  workspace_id : String
  task_id : String
  stream_url : String
  stream_mode : String
  stream_source : String
  dispatch_mode : String
  live_stream_ready : Bool
  live_stream_url : String
  incremental_stream_ready : Bool
  incremental_stream_url : String
  stream_state_url : String
  event_log_path : String
  append_log_ready : Bool
  append_log_count : Int
  command_log_path : String
  command_log_ready : Bool
  command_log_count : Int
  runtime_command_log_path : String
  runtime_command_feed_ready : Bool
  runtime_command_count : Int
  runtime_dispatch_log_path : String
  runtime_dispatch_ready : Bool
  runtime_dispatch_count : Int
  session_snapshot_path : String
  session_snapshot_ready : Bool
  event_count : Int
  tool_count : Int
  diff_count : Int
  test_count : Int
  verified_test_count : Int
  failed_test_count : Int
  artifact_count : Int
  source_bound_package_count : Int
  runtime_package_proof_count : Int
  runtime_verified_package_count : Int
  runtime_commit_proof_count : Int
  steer_command_count : Int
  steer_settlement_count : Int
  deferred_steer_count : Int
  pending_steer_count : Int
  steering_lifecycle : Json
  cancel_command_count : Int
  cancel_dropped_count : Int
  cancel_settlement_count : Int
  pending_cancel_count : Int
  cancel_lifecycle : Json
  review_count : Int
  pending_diff_count : Int
  accepted_review_count : Int
  rejected_review_count : Int
  review_state : String
  runtime_count : Int
  transcript_count : Int
  has_packaging_candidate : Bool
  moonbook_package_manifest_count : Int
  moonbook_package_index_manifest_count : Int
  moonbook_change_set_manifest_count : Int
  moonbook_patch_set_manifest_count : Int
  patch_lifecycle : Json
  package_lifecycle : Json
  resume_lifecycle : Json
  runtime_patch_execution_proof_count : Int
  moonbook_tool_approvals_manifest_count : Int
  moonbook_test_runs_manifest_count : Int
  moonbook_eval_report_manifest_count : Int
  mooncode_runtime_evidence_manifest_count : Int
  mooncode_runtime_handoff_manifest_count : Int
  pending_tool_approval_count : Int
  extractable_component : String
  eval_score : Int
  eval_level : String
  eval_checks : Array[MoonCodeEvalCheck]
  production_score : Int
  production_level : String
  production_passed_check_count : Int
  production_check_count : Int
  production_readiness : Json
  production_checks : Array[MoonCodeEvalCheck]
} derive(FromJson)

///|
struct MoonCodeEvalCheck {
  id : String
  label : String
  ok : Bool
  evidence : String
} derive(FromJson)

///|
struct MoonCodeEvalReport {
  kind : String
  protocol : String
  status : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  runtime_owner : String
  ui_owner : String
  artifact_owner : String
  extractable_component : String
  bridge_score : Int
  bridge_level : String
  recorded_at : String
  manifest_path : String
  absolute_manifest_path : String
  passed_check_count : Int
  missing_check_count : Int
  check_count : Int
  checks : Array[MoonCodeEvalCheck]
  native_eval_evidence_ready : Bool
  native_eval_source : String
  native_eval_endpoint : String
  native_eval_ingest_method : String
  native_eval_ingest_endpoint : String
  required_native_harnesses : Array[String]
  minimum_native_evidence : Array[String]
  current_gap : String
} derive(FromJson)

///|
struct MoonCodeResumeContract {
  session_snapshot_path : String
  session_store_endpoint : String
  command_log_path : String
  runtime_command_log_path : String
  runtime_dispatch_log_path : String
  event_log_path : String
  stream_endpoint : String
  runtime_event_ingest_endpoint : String
  command_queue_endpoint : String
  runtime_command_feed_endpoint : String
  runtime_claim_endpoint : String
  runtime_dispatch_endpoint : String
  runtime_replay_endpoint : String
  action_plan_endpoint : String
  native_command_endpoint : String
  native_eval_endpoint : String
  ordering_rule : String
} derive(FromJson)

///|
struct MoonCodeRuntimeEngine {
  daemon_running : Bool
  native_runtime_ready : Bool
  dispatch_mode : String
  bridge_status : String
  moonclaw_root : String
} derive(FromJson)

///|
struct MoonCodeRuntimeConsumerEndpoints {
  runtime_claim : String
  runtime_replay : String
  runtime_events : String
  runtime_commands : String
  stream : String
  native_commands : String
  native_eval_report : String
} derive(FromJson)

///|
struct MoonCodeRuntimeConsumer {
  kind : String
  protocol : String
  session_id : String
  status : String
  native_runtime_ready : Bool
  ready_to_claim : Bool
  ready_to_replay : Bool
  claimable_command_count : Int
  claimed_command_count : Int
  pending_command_count : Int
  invalid_command_count : Int
  next_action : String
  endpoints : MoonCodeRuntimeConsumerEndpoints
  required_loop : Array[String]
  safety_boundary : String
} derive(FromJson)

///|
struct MoonCodeRuntimeHandoff {
  kind : String
  protocol : String
  status : String
  session_id : String
  workspace_id : String
  workspace_name : String
  workspace_root : String
  task_id : String
  recorded_at : String
  manifest_path : String
  absolute_manifest_path : String
  resume_contract : MoonCodeResumeContract
  command_count : Int
  commands : Array[MoonCodeQueuedCommand]
  book_output_roots : Array[String]
  engine : MoonCodeRuntimeEngine
  runtime_consumer : MoonCodeRuntimeConsumer?
  runtime_execution_plan : Json?
  runtime_turn_packet : Json?
  runtime_supervisor : Json?
  summary : MoonCodeSummary
  next_runtime_step : String
} derive(FromJson)

///|
struct MoonCodeBoundary {
  moondesk : Array[String]
  moonclaw : Array[String]
  moonbook : Array[String]
} derive(FromJson)

///|
struct MoonCodeWorkspaceModeInfo {
  id : String
  title : String
  purpose : String
} derive(FromJson)

///|
struct MoonCodeSessionProtocol {
  transport_target : String
  preferred_stream : String
  stream_endpoint : String
  stream_state_endpoint : String
  runtime_event_ingest_endpoint : String
  command_queue_endpoint : String
  runtime_claim_endpoint : String
  runtime_replay_endpoint : String
  action_plan_endpoint : String
  native_runtime_loop_options : Json
  commands : Array[String]
  events : Array[String]
  durability : String
} derive(FromJson)

///|
struct MoonCodeToolSpec {
  id : String
  owner : String
  lane : String
  approval : String
  purpose : String
  outputs : Array[String]
} derive(FromJson)

///|
struct MoonCodeCommandSpec {
  action : String
  dispatch : String
  approval : String
  expected_lanes : Array[String]
  tool_hints : Array[String]
} derive(FromJson)

///|
struct MoonCodeQueuedCommand {
  protocol : String
  kind : String
  command_id : String
  action : String
  dispatch : String
  approval : String
  created_at : String
  session_id : String
  workspace_id : String
  workspace_name : String
  workspace_root : String
  task_id : String
  context_path : String
  target : String
  message : String
  web_search : Bool
  expected_lanes : Array[String]
  tool_hints : Array[String]
} derive(FromJson)

///|
struct MoonCodeCommandQueue {
  protocol : String
  kind : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  command_log_path : String
  command_count : Int
  commands : Array[MoonCodeQueuedCommand]
  ordering_rule : String
} derive(FromJson)

///|
struct MoonCodeRuntimeDispatchReceipt {
  protocol : String
  kind : String
  dispatch_id : String
  command_id : String
  session_id : String
  action : String
  dispatch : String
  status : String
  dispatch_mode : String
  created_at : String
  openseek_wire_valid : Bool
  native_mooncode_endpoint : String
  legacy_bridge_endpoint : String
  detail : String
  runtime_command : Json
  owner : Json
  previous_dispatch_status : String?
  previous_dispatch_id : String?
  previous_claim_id : String?
  previous_consumer_id : String?
  claimed_by_same_consumer : Bool?
  ack_order_status : String?
  order_blocker : Json?
  requested_status : String?
  proof_gate : Json?
} derive(FromJson)

///|
struct MoonCodeRuntimeDispatchState {
  protocol : String
  kind : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  dispatch_mode : String
  runtime_command_count : Int
  runtime_dispatch_count : Int
  runtime_dispatch_pending_count : Int
  runtime_command_log_path : String
  runtime_dispatch_log_path : String
  dispatch_receipts : Array[MoonCodeRuntimeDispatchReceipt]
  pending_command_ids : Array[String]
  runtime_protocol : Json
  owner : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeCommandFeed {
  protocol : String
  kind : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  runtime_command_log_path : String
  runtime_command_count : Int
  runtime_dispatch_log_path : String
  runtime_claim_endpoint : String
  runtime_dispatch_count : Int
  runtime_dispatch_pending_count : Int
  commands : Array[Json]
  execution_summaries : Array[Json]
  dispatch_receipts : Array[MoonCodeRuntimeDispatchReceipt]
  runtime_replay : Json
  decode_reports : Array[Json]
  wire_protocol : Json
  runtime_protocol : Json
  runtime_claim_contract : Json
  command_lifecycle : Json
  owner : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeReplayItem {
  index : Int
  command_id : String
  action : String
  dispatch : String
  serve_command : String
  created_at : String
  target : String
  context_path : String
  receipt_status : String
  replay_status : String
  previous_claim_expired : Bool
  latest_receipt : Json
  proof_event_count : Int
  submitted_event_count : Int
  normalized_event_count : Int
  runtime_event_summary : Json
  openseek_wire_command : Json
  native_mooncode_body : Json
  decode_report : Json
  previous_completion_missing_proof : Bool?
} derive(FromJson)

///|
struct MoonCodeRuntimeReplayState {
  protocol : String
  kind : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  runtime_command_log_path : String
  runtime_dispatch_log_path : String
  command_count : Int
  valid_command_count : Int
  invalid_command_count : Int
  delivered_command_count : Int
  claimed_command_count : Int
  failed_dispatch_count : Int
  pending_command_count : Int
  first_pending_index : Int
  first_invalid_command_id : String
  replay_ready : Bool
  replay_policy : String
  ordering_rule : String
  decode_reports : Array[Json]
  replay_items : Array[MoonCodeRuntimeReplayItem]
  pending_commands : Array[MoonCodeRuntimeReplayItem]
  pending_openseek_jsonl : String
  runtime_protocol : Json
  owner : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeServiceState {
  kind : String
  protocol : String
  session_id : String
  service_id : String
  active : Bool
  status : String
  started_at : String
  finished_at : String
  detail : String
  stopped_by : String
  started_count : Int
  finished_count : Int
  failed_count : Int
  ran_turn_count : Int
  failed_turn_count : Int
  control_hint : String
  owner : String
} derive(FromJson)

///|
struct MoonCodeRuntimeEventSink {
  protocol : String
  kind : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  event_log_path : String
  event_count : Int
  events : Array[MoonCodeEvent]
  command_progress : Json
  unscoped_progress : Json
  runtime_service : MoonCodeRuntimeServiceState
  post_contract : Json
  runtime_protocol : Json
  owner : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeClaimItem {
  index : Int
  command_id : String
  action : String
  dispatch : String
  serve_command : String
  created_at : String
  target : String
  context_path : String
  claim_status : String
  receipt_status : String
  tool_authorization_state : String
  runtime_may_execute_tools : Bool
  tool_authorization_blocked : Bool
  tool_authorization_blocked_reason : String
  blocked_by_command_id : String
  blocked_by_status : String
  consumer_id : String
  claim_id : String
  claimed_at : String
  lease_expires_at : String
  ack_endpoint : String
  runtime_command : Json
  latest_receipt : Json
  decode_report : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeClaimState {
  protocol : String
  kind : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  runtime_command_log_path : String
  runtime_dispatch_log_path : String
  command_count : Int
  receipt_count : Int
  claimable_command_count : Int
  claimed_command_count : Int
  delivered_command_count : Int
  failed_command_count : Int
  invalid_command_count : Int
  order_blocked_command_count : Int
  tool_authorization_blocked_command_count : Int
  claim_ready : Bool
  claim_endpoint : String
  ack_endpoint : String
  ordering_rule : String
  lease_policy : String
  claim_items : Array[MoonCodeRuntimeClaimItem]
  claimable_commands : Array[MoonCodeRuntimeClaimItem]
  claimed_commands : Array[MoonCodeRuntimeClaimItem]
  delivered_commands : Array[MoonCodeRuntimeClaimItem]
  failed_commands : Array[MoonCodeRuntimeClaimItem]
  invalid_commands : Array[MoonCodeRuntimeClaimItem]
  order_blocked_commands : Array[MoonCodeRuntimeClaimItem]
  tool_authorization_blocked_commands : Array[MoonCodeRuntimeClaimItem]
  consumer_contract : Json
  owner : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeComponent {
  id : String
  owner : String
  reference : String
  purpose : String
  moondesk_role : String
} derive(FromJson)

///|
struct MoonCodeNamespaceRole {
  id : String
  name : String
  responsibility : String
} derive(FromJson)

///|
struct MoonCodeWireCommand {
  command : String
  required_fields : Array[String]
  purpose : String
} derive(FromJson)

///|
struct MoonCodeWireProtocol {
  transport : String
  input_commands : Array[MoonCodeWireCommand]
  output_events : Array[String]
  ordering_rule : String
} derive(FromJson)

///|
struct MoonCodeSessionStoreContract {
  owner : String
  shape : String
  resume_modes : Array[String]
  moondesk_projection : String
} derive(FromJson)

///|
struct MoonCodeEvalContract {
  required_harnesses : Array[String]
  harness_contract_endpoint : String
  reference_paths : Array[String]
  minimum_evidence : Array[String]
  native_eval_report : MoonCodeNativeEvalReportContract
  current_gap : String
} derive(FromJson)

///|
struct MoonCodeNativeEvalReportContract {
  owner : String
  endpoint : String
  transport : String
  purpose : String
  required_fields : Array[String]
  status_values : Array[String]
  normalization_rule : String
} derive(FromJson)

///|
struct MoonCodeToolRuntimeContract {
  id : String
  owner : String
  lane : String
  approval : String
  input_fields : Array[Json]
  output_events : Array[String]
  mutates_files : Bool
  requires_review : Bool
  executable_boundary : String
  safety_policy : String
} derive(FromJson)

///|
struct MoonCodeToolContractConstraints {
  workspace_scope : String
  path_rule : String
  diff_rule : String
  test_rule : String
  approval_rule : String
  extraction_rule : String
} derive(FromJson)

///|
struct MoonCodeToolContract {
  kind : String
  protocol : String
  version : Int
  owner : String
  execution_owner : String
  approval_owner : String
  artifact_owner : String
  supported_tools : Array[String]
  tools : Array[MoonCodeToolRuntimeContract]
  constraints : MoonCodeToolContractConstraints
} derive(FromJson)

///|
struct MoonCodeToolCallWireContract {
  kind : String
  protocol : String
  owner : String
  runtime_owner : String
  reference : String
  accepted_shapes : Array[String]
  supported_tools : Array[String]
  argument_rule : String
  unknown_tool_policy : String
} derive(FromJson)

///|
struct MoonCodeRuntimeContract {
  reference : String
  target_component : String
  extractable_component : String
  namespace_roles : Array[MoonCodeNamespaceRole]
  status : String
  components : Array[MoonCodeRuntimeComponent]
  wire_protocol : MoonCodeWireProtocol
  session_store : MoonCodeSessionStoreContract
  tool_contract : MoonCodeToolContract
  eval_contract : MoonCodeEvalContract
} derive(FromJson)

///|
struct MoonCodeEngineCheck {
  id : String
  label : String
  status : String
  evidence : String
} derive(FromJson)

///|
struct MoonCodeEngineStatus {
  ok : Bool
  status : String
  bridge_mode : String
  production_ready : Bool
  native_runtime_ready : Bool
  legacy_task_bridge_ready : Bool
  adapter_status : String
  moonclaw_root : String
  message : String
  daemon : AgentDaemonStatus
  supported_endpoints : Array[String]
  checks : Array[MoonCodeEngineCheck]
} derive(FromJson)

///|
struct MoonCodeExtractable {
  future_package : String
  core_package : String
  projection_package : String
  host_package : String
  rule : String
} derive(FromJson)

///|
struct MoonCodeExtractionRole {
  id : String
  package : String
  owner : String
  responsibility : String
} derive(FromJson)

///|
struct MoonCodeExtractionBoundary {
  kind : String
  protocol : String
  portable_core_package : String
  moondesk_projection_package : String
  moonwiki_host_package : String
  future_standalone_package : String
  roles : Array[MoonCodeExtractionRole]
  rules : Array[String]
} derive(FromJson)

///|
struct MoonCodeCapabilities {
  ok : Bool
  component : String
  version : Int
  boundary : MoonCodeBoundary
  workspace_modes : Array[MoonCodeWorkspaceModeInfo]
  session_protocol : MoonCodeSessionProtocol
  runtime_contract : MoonCodeRuntimeContract
  tool_contract : MoonCodeToolContract
  tool_call_wire : MoonCodeToolCallWireContract
  extraction_boundary : MoonCodeExtractionBoundary
  engine_status : MoonCodeEngineStatus
  command_specs : Array[MoonCodeCommandSpec]
  tools : Array[String]
  tool_specs : Array[MoonCodeToolSpec]
  book_outputs : Array[String]
  extractable : MoonCodeExtractable
} derive(FromJson)

///|
struct MoonCodeStreamPoll {
  session_id : String
  stream : String
  stream_source : String
  since : Int
  next_since : Int
  emitted_count : Int
  events : Array[MoonCodeEvent]
}

///|
struct MoonCodeStreamState {
  kind : String
  session_id : String
  consumer_id : String
  latest_sequence : Int
  next_since : Int
  checkpoint_ready : Bool
  checkpoint_path : String
} derive(FromJson)

///|
struct MoonCodeChangeSetEntry {
  id : String
  kind : String
  title : String
  status : String
  path : String
  command : String
  exit_code : Int
  created_at : String
  detail : String
  diff : String
  command_id : String
} derive(FromJson)

///|
struct MoonCodeChangeSet {
  kind : String
  protocol : String
  status : String
  session_id : String
  workspace_id : String
  task_id : String
  recorded_at : String
  manifest_path : String
  diff_count : Int
  test_count : Int
  artifact_count : Int
  review_count : Int
  accepted_review_count : Int
  rejected_review_count : Int
  pending_diff_count : Int
  verified_test_count : Int
  failed_test_count : Int
  diffs : Array[MoonCodeChangeSetEntry]
  tests : Array[MoonCodeChangeSetEntry]
  artifacts : Array[MoonCodeChangeSetEntry]
  reviews : Array[MoonCodeChangeSetEntry]
} derive(FromJson)

///|
struct MoonCodePatchSetEntry {
  id : String
  path : String
  title : String
  status : String
  review_state : String
  execution_state : String
  created_at : String
  detail : String
  diff : String
  diff_present : Bool
  hunks : Array[MoonCodePatchHunk]
  hunk_count : Int
  command : String
  command_id : String
  accepted_review_count : Int
  rejected_review_count : Int
  applied_review_count : Int
  reverted_review_count : Int
  runtime_applied_count : Int
  runtime_reverted_count : Int
  runtime_proof_count : Int
  execution_verified : Bool
  package_review_count : Int
  gate_status : String?
  next_action : String?
  blocked_reason : String?
} derive(FromJson)

///|
struct MoonCodePatchHunk {
  id : String
  index : Int
  target : String
  header : String
  review_state : String
  execution_state : String
  added_lines : Int
  removed_lines : Int
  context_lines : Int
  line_count : Int
  preview : String
  accepted_review_count : Int
  rejected_review_count : Int
  applied_review_count : Int
  reverted_review_count : Int
  runtime_applied_count : Int
  runtime_reverted_count : Int
  runtime_proof_count : Int
  gate_status : String?
  next_action : String?
  blocked_reason : String?
} derive(FromJson)

///|
struct MoonCodePatchSet {
  kind : String
  protocol : String
  status : String
  execution_status : String
  session_id : String
  workspace_id : String
  task_id : String
  recorded_at : String
  manifest_path : String
  patch_count : Int
  accepted_patch_count : Int
  rejected_patch_count : Int
  applied_patch_count : Int
  reverted_patch_count : Int
  pending_patch_count : Int
  runtime_applied_patch_count : Int
  runtime_reverted_patch_count : Int
  runtime_pending_patch_count : Int
  runtime_patch_proof_count : Int
  patches : Array[MoonCodePatchSetEntry]
} derive(FromJson)

///|
struct MoonCodeToolApprovalEntry {
  id : String
  event_id : String
  tool_id : String
  title : String
  status : String
  approval : String
  approval_state : String
  created_at : String
  detail : String
  path : String
  command : String
  target : String
  target_kind : String
  target_label : String
  approved_review_count : Int
  rejected_review_count : Int
} derive(FromJson)

///|
struct MoonCodeToolApprovals {
  kind : String
  protocol : String
  status : String
  session_id : String
  workspace_id : String
  task_id : String
  recorded_at : String
  manifest_path : String
  approval_count : Int
  pending_approval_count : Int
  approved_approval_count : Int
  rejected_approval_count : Int
  approvals : Array[MoonCodeToolApprovalEntry]
} derive(FromJson)

///|
struct MoonCodeToolAuthorization {
  kind : String
  protocol : String
  session_id : String
  decision : String
  allowed : Bool
  requires_approval : Bool
  blocked : Bool
  approval : String
  approval_state : String
  target : String
  tool_call_id : String
  tool_id : String
  path : String
  command : String
  reason : String
  preview_event : Json
  approval_entry : Json
  tool_approvals : Json
} derive(FromJson)

///|
struct MoonCodeTestRunEntry {
  id : String
  title : String
  kind : String
  status : String
  run_state : String
  created_at : String
  path : String
  command : String
  exit_code : Int
  detail : String
  target : String
  verified : Bool
  command_id : String
} derive(FromJson)

///|
struct MoonCodeTestRuns {
  kind : String
  protocol : String
  status : String
  session_id : String
  workspace_id : String
  task_id : String
  recorded_at : String
  manifest_path : String
  run_count : Int
  passed_run_count : Int
  failed_run_count : Int
  running_run_count : Int
  queued_run_count : Int
  verified_run_count : Int
  runs : Array[MoonCodeTestRunEntry]
} derive(FromJson)

///|
struct MoonCodePackageSourceRecord {
  path : String
  exists : Bool
  kind : String
  size_bytes : Int?
  sha256 : String?
  package_ready : Bool
} derive(FromJson)

///|
struct MoonCodePackageCandidate {
  kind : String
  protocol : String
  status : String
  package_kind : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  context_path : String
  candidate_paths : Array[String]
  source_inventory : Array[MoonCodePackageSourceRecord]
  source_inventory_count : Int
  source_present_count : Int
  source_inventory_status : String
  execution_state : String
  runtime_built_count : Int
  runtime_verified_count : Int
  runtime_proof_count : Int
  execution_verified : Bool
  command_id : String
  command_created_at : String
  recorded_at : String
  manifest_path : String
  absolute_manifest_path : String
  review_receipt_path : String
  detail : String
} derive(FromJson)

///|
struct MoonCodePackageCandidates {
  kind : String
  protocol : String
  status : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  recorded_at : String
  package_count : Int
  source_bound_package_count : Int
  missing_source_package_count : Int
  runtime_built_package_count : Int
  runtime_verified_package_count : Int
  runtime_package_proof_count : Int
  package_index_status : String
  package_index_path : String
  package_index_source_bound_count : Int
  package_index_executable_ready_count : Int
  package_index_entry_points : Array[String]
  packages : Array[MoonCodePackageCandidate]
  rule : String
} derive(FromJson)

///|
struct MoonCodeActionPlanItem {
  index : Int
  command_id : String
  action : String
  dispatch : String
  approval : String
  state : String
  runtime_state : String
  created_at : String
  target : String
  context_path : String
  message : String
  expected_lanes : Array[String]
  tool_hints : Array[String]
  required_gates : Array[String]
  runtime_evidence_status : String
  required_event_count : Int
  proven_required_event_count : Int
  missing_required_events : Array[String]
  failed_required_events : Array[String]
  tool_harness_status : String?
  tool_harness_expected_tool_count : Int?
  tool_harness_proven_tool_count : Int?
  tool_harness_missing_tool_count : Int?
  tool_harness_failed_tool_count : Int?
  blocking_reason : String
  next_step : String
} derive(FromJson)

///|
struct MoonCodeActionPlanGates {
  no_failing_tests : Bool
  has_verified_tests : Bool
  tool_approvals_resolved : Bool
  diffs_resolved : Bool
  has_source_bound_package : Bool
} derive(FromJson)

///|
struct MoonCodeSelectedPatchPreflight {
  context_path : String
  matched : Bool
  review_state : String
  execution_state : String
  gate_status : String
  next_action : String
  blocked_reason : String
  runtime_proven : Bool
} derive(FromJson)

///|
struct MoonCodeCommandPreflight {
  action : String
  dispatch : String
  approval : String
  lane : String
  title : String
  tool_hints : Array[String]
  expected_lanes : Array[String]
  required_gates : Array[String]
  blocked : Bool
  reason : String
  context_path : String
  acceptance_gates : MoonCodeActionPlanGates
  selected_patch : MoonCodeSelectedPatchPreflight
} derive(FromJson)

///|
struct MoonCodeActionPlanRecommendedCommand {
  available : Bool
  ui_action : String
  action : String
  label : String
  context_path : String
  message : String
  status : String
} derive(FromJson)

///|
struct MoonCodeActionPlan {
  kind : String
  protocol : String
  status : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  recorded_at : String
  manifest_path : String
  action_count : Int
  pending_runtime_count : Int
  running_count : Int
  blocked_count : Int
  ready_for_review_count : Int
  completed_count : Int
  run_test_command_count : Int
  package_command_count : Int
  commit_command_count : Int
  accept_command_count : Int
  review_command_count : Int
  verified_test_count : Int
  failed_test_count : Int
  pending_diff_count : Int
  pending_tool_approval_count : Int
  pending_steer_count : Int
  deferred_steer_count : Int
  source_bound_package_count : Int
  next_required_action : String
  production_readiness : Json
  recommended_command : MoonCodeActionPlanRecommendedCommand
  recommended_commands : Array[MoonCodeActionPlanRecommendedCommand]
  actions : Array[MoonCodeActionPlanItem]
  acceptance_gates : MoonCodeActionPlanGates
  rule : String
} derive(FromJson)

///|
struct MoonCodeRuntimeEvidenceItem {
  index : Int
  command_id : String
  action : String
  created_at : String
  context_path : String
  message : String
  runtime_command_recorded : Bool
  status : String
  required_event_count : Int
  proven_required_event_count : Int
  missing_required_events : Array[String]
  failed_required_events : Array[String]
  tool_harness_status : String?
  tool_harness_expected_tool_count : Int?
  tool_harness_proven_tool_count : Int?
} derive(FromJson)

///|
struct MoonCodeRuntimeEvidence {
  kind : String
  protocol : String
  session_id : String
  workspace_id : String
  workspace_name : String
  task_id : String
  recorded_at : String
  command_count : Int
  runtime_command_count : Int
  proof_event_count : Int
  proven_command_count : Int
  missing_evidence_command_count : Int
  failed_evidence_command_count : Int
  missing_runtime_command_count : Int
  required_event_count : Int
  proven_required_event_count : Int
  missing_required_event_count : Int
  failed_required_event_count : Int
  tool_harness_status : String?
  tool_harness_expected_tool_count : Int?
  tool_harness_proven_tool_count : Int?
  tool_harness_missing_tool_count : Int?
  tool_harness_failed_tool_count : Int?
  status : String
  manifest_path : String
  absolute_manifest_path : String
  command_log_path : String
  runtime_command_log_path : String
  event_log_path : String
  items : Array[MoonCodeRuntimeEvidenceItem]
  rule : String
} derive(FromJson)

///|
struct AgentSession {
  id : String
  workspace_id : String
  workspace_name : String
  workspace_root : String
  cwd : String
  moonclaw_task_id : String
  title : String
  model : String
  status : String
  port : Int
  web_search : Bool
  queued_count : Int
  created_at : String
  updated_at : String
  last_message : String
  transcript : Array[AgentMessage]
  mooncode_events : Array[MoonCodeEvent]
  mooncode_summary : MoonCodeSummary
} derive(FromJson)

///|
struct PdfEvidenceWatchBookResult {
  book_id : String
  workspace_id : String
  standing_goal : Json
  moontown_publish : Json
  readiness : Json
} derive(FromJson)

///|
struct EbSampleRunResult {
  book_id : String
  run_id : String
  status : String
  output_path : String
  watcher_goal_id : String
  verification : Json
  run_health : Json
} derive(FromJson)

///|
struct MoonclawImportResult {
  ok : Bool
  status : String
  book_id : String
  proposal_id : String
  run_id : String
  receipt_path : String
  run_health : Json
} derive(FromJson)

///|
struct MoonclawRunResult {
  ok : Bool
  status : String
  book_id : String
  run_id : String
  receipt_path : String
  run_health : Json
} derive(FromJson)

///|
struct MoonclawReconcileResult {
  ok : Bool
  status : String
  book_id : String
  run_id : String
  output_path : String
  source_screen_path : String
  run_health : Json
} derive(FromJson)

///|
struct EbRecoveredOutputResult {
  ok : Bool
  status : String
  book_id : String
  run_id : String
  output_path : String
  source_screen_path : String
  receipt_path : String
  run_health : Json
  failed_checks : Array[String]
} derive(FromJson)

///|
struct EbProductionProofResult {
  ok : Bool
  status : String
  book_id : String
  run_id : String
  proof_level : String
  receipt_path : String
  run_health : Json
  failed_checks : Array[String]
} derive(FromJson)

///|
struct ProductionChecklistItem {
  id : String
  label : String
  ok : Bool
  requirement : String
  evidence : String
} derive(FromJson)

struct BookPatternRecord {
  id : String
  title : String
  base_type : String
  description : String
  output : String
  default_topic : String
  default_cadence_minutes : Int
  default_source_policy : String
  default_websites : Array[String]
  skills : Array[String]
} derive(FromJson)

///|
struct BookBaseTypeRecord {
  id : String
  title : String
  description : String
  owner : String
  source : String
  creation_palette_source : String
  moonbook_layout_refs : Array[String]
  template_registry_refs : Array[String]
  supported_patterns : Array[String]
  required_roots : Array[String]
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
  daemon_agent : DaemonAgentResult?
  agent_daemon : AgentDaemonStatus?
  agent_models : Array[AgentModel]
  agent_sessions : Array[AgentSession]
  selected_agent_session_id : String
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
  mooncode_runtime_dispatch_session_id : String
  mooncode_runtime_dispatch_status : String
  mooncode_runtime_dispatch : MoonCodeRuntimeDispatchState?
  mooncode_runtime_claim_session_id : String
  mooncode_runtime_claim_status : String
  mooncode_runtime_claim : MoonCodeRuntimeClaimState?
  agent_prompt : String
  agent_model : String
  agent_web_search : Bool
  agent_status : String
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
  book_base_types : Array[BookBaseTypeRecord]
  selected_book_base_type : String
  book_patterns : Array[BookPatternRecord]
  selected_book_pattern_id : String
  pdf_watch_book_id : String
  pdf_watch_topic : String
  pdf_watch_purpose : String
  pdf_watch_websites : String
  pdf_watch_cadence_minutes : String
  pdf_watch_source_policy : String
  pdf_watch_notify_rule : String
  pdf_watch_skill_pack : String
  pdf_watch_analysis_method : String
  pdf_watch_last_book_id : String
  eb_target_scope : String
  eb_bond_code : String
  eb_bond_short_name : String
  eb_issuer : String
  eb_underlying_company : String
  eb_exchange : String
  eb_as_of : String
  eb_additional_bonds : String
  eb_production_checklist : Array[ProductionChecklistItem]
  eb_production_proof_receipt_path : String
  eb_production_proof_status : String
  eb_production_proof_level : String
  eb_production_proof_run_id : String
  eb_production_proof_failed_checks : Array[String]
  eb_moonclaw_import_run_id : String
  eb_moonclaw_import_status : String
  eb_moonclaw_import_receipt_recovered : Bool
  eb_moonclaw_import_recovery_source : String
  eb_moonclaw_retry_recommended : Bool
  eb_moonclaw_orphaned_after_timeout : Bool
  eb_moonclaw_confirmed_run_status : String
  eb_moonclaw_run_receipt_path : String
  eb_moonclaw_retry_import_receipt_path : String
  eb_moonclaw_retry_import_status : String
  eb_moonclaw_result_path : String
  eb_book_result_path : String
  eb_output_path : String
  eb_base_type_selection_path : String
  eb_base_type_selection_ready : Bool
  eb_base_type : String
  eb_base_type_handoff_target : String
  eb_moontown_publish_receipt_path : String
  eb_moontown_publish_receipt_ready : Bool
  eb_global_standing_goal_ready : Bool
  eb_standing_goal_registration_ready : Bool
  eb_expected_output_contract_path : String
  eb_expected_output_contract_ready : Bool
  eb_expected_output_contract_id : String
  eb_workbook_validation_path : String
  eb_source_screen_path : String
  eb_output_validation_status : String
  pdf_watch_status : String
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
  CreatedPdfEvidenceWatchBook(Result[PdfEvidenceWatchBookResult, String])
  ImportedMoonclawPacket(Result[MoonclawImportResult, String])
  RanConfirmedMoonclawJob(Result[MoonclawRunResult, String])
  ReconciledMoonclawResult(Result[MoonclawReconcileResult, String])
  AcceptedRecoveredEbOutput(Result[EbRecoveredOutputResult, String])
  ProvedEbProduction(Result[EbProductionProofResult, String])
  RanEbSampleValidation(Result[EbSampleRunResult, String])
  AuditedEbProductionHealth(Result[Json, String])
  ExportedAppToolPortable(Result[Json, String])
  ExportedAllAppToolPortable(Result[Json, String])
  DispatchedDaemon(Result[DaemonDispatchResult, String])
  LoadedDaemonLifecycle(Result[DaemonLifecycleResult, String])
  ManagedDaemon(Result[DaemonLifecycleResult, String])
  LoadedDaemonAgent(Result[DaemonAgentResult, String])
  ManagedDaemonAgent(Result[DaemonAgentResult, String])
  LoadedAgentDaemon(Result[AgentDaemonStatus, String])
  LoadedAgentModels(Result[AgentModelsResult, String])
  LoadedAgentSessions(Result[Array[AgentSession], String])
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
  LoadedMoonCodeRuntimeDispatch(
    String,
    Result[MoonCodeRuntimeDispatchState, String],
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
  CreatedAgentSession(Result[AgentSession, String])
  SentAgentMessage(Result[AgentSession, String])
  CancelledAgentSession(Result[AgentSession, String])
  CompletedMoonCodeCommand(Result[AgentSession, String])
  RevealedSelection(Result[RevealResult, String])
  LocalFilesPicked(Result[Array[LocalImportFile], String])
  SelectWorkspaceMode(WorkspaceMode)
  SelectActivity(Activity)
  SelectDrawerTab(DrawerTab)
  SelectAgentSession(String)
  NewAgentSession
  SetAgentPrompt(String)
  SetAgentModel(String)
  ToggleAgentWebSearch
  SendAgentMessage
  RunMoonCodeCommand(String)
  RunMoonCodeCommandForPath(String, String)
  RunMoonCodeCommandWithMessage(String, String, String, String)
  RunMoonCodeCommandOverride(String, String)
  RunMoonCodeRuntimeLoop
  StartMoonCodeRuntimeService
  RanMoonCodeRuntimeLoop(String, Result[AgentSession, String])
  StartedMoonCodeRuntimeService(String, Result[AgentSession, String])
  ProbeMoonCodeToolAuthorization(String)
  ClaimMoonCodeRuntime(Bool)
  AckMoonCodeRuntimeCommand(String, String)
  PollAgentSessions
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
  SetPdfWatchBookId(String)
  SetPdfWatchTopic(String)
  SetPdfWatchPurpose(String)
  SetPdfWatchWebsites(String)
  SetPdfWatchCadenceMinutes(String)
  SetPdfWatchSourcePolicy(String)
  SetPdfWatchNotifyRule(String)
  SetPdfWatchSkillPack(String)
  SetPdfWatchAnalysisMethod(String)
  SetEbTargetScope(String)
  SetEbBondCode(String)
  SetEbBondShortName(String)
  SetEbIssuer(String)
  SetEbUnderlyingCompany(String)
  SetEbExchange(String)
  SetEbAsOf(String)
  SetEbAdditionalBonds(String)
  SelectBookBaseType(String)
  SelectBookPattern(String)
  CreatePdfEvidenceWatchBook
  ImportMoonclawPacket
  LaunchMoonclawRun
  RunConfirmedMoonclawJob
  ReconcileMoonclawResult
  AcceptRecoveredEbOutput
  ProveEbProduction
  FreshRetryEbProduction
  RunEbSampleValidation
  AuditEbProductionHealth
  ExportAppToolPortable
  ExportAllAppToolPortable
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
    "agents" => Activity::Agents
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
    Activity::Agents => "agents"
    Activity::Town => "town"
    Activity::Runs => "runs"
    Activity::Settings => "settings"
  }
}

///|
fn workspace_mode_summary(mode : WorkspaceMode) -> String {
  match mode {
    WorkspaceMode::MoonWiki => "book/wiki workspace"
    WorkspaceMode::MoonCode => "coding/chat workspace"
  }
}

///|
fn workspace_mode_for_activity(activity : Activity) -> WorkspaceMode {
  match activity {
    Activity::Agents => WorkspaceMode::MoonCode
    _ => WorkspaceMode::MoonWiki
  }
}

///|
fn init_model() -> Model {
  {
    workspace_mode: workspace_mode_for_activity(initial_activity()),
    activity: initial_activity(),
    command_open: false,
    drawer_tab: DrawerTab::DrawerRequests,
    loading: true,
    host_status: "connecting to local host",
    workspaces: [],
    selected_workspace_id: "",
    current_directory: "",
    entries: [],
    selected_path: "wiki/index.md",
    primary_preview_path: "wiki/index.md",
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
    agent_daemon: None,
    agent_models: [],
    agent_sessions: [],
    selected_agent_session_id: "",
    mooncode_capabilities: None,
    mooncode_status: "MoonCode contract not loaded",
    mooncode_stream_session_id: "",
    mooncode_stream_cursor: 0,
    mooncode_stream_status: "stream idle",
    mooncode_stream_checkpoint_session_id: "",
    mooncode_stream_checkpoint_status: "checkpoint idle",
    mooncode_stream_events: [],
    mooncode_runtime_event_sink_session_id: "",
    mooncode_runtime_event_sink_status: "runtime events idle",
    mooncode_runtime_event_sink: None,
    mooncode_change_set_session_id: "",
    mooncode_change_set_status: "change set idle",
    mooncode_change_set: None,
    mooncode_eval_report_session_id: "",
    mooncode_eval_report_status: "eval report idle",
    mooncode_eval_report: None,
    mooncode_runtime_handoff_session_id: "",
    mooncode_runtime_handoff_status: "runtime handoff idle",
    mooncode_runtime_handoff: None,
    mooncode_patch_set_session_id: "",
    mooncode_patch_set_status: "patch set idle",
    mooncode_patch_set: None,
    mooncode_tool_approvals_session_id: "",
    mooncode_tool_approvals_status: "tool approvals idle",
    mooncode_tool_approvals: None,
    mooncode_tool_authorization_session_id: "",
    mooncode_tool_authorization_status: "tool authorization idle",
    mooncode_tool_authorization: None,
    mooncode_test_runs_session_id: "",
    mooncode_test_runs_status: "test runs idle",
    mooncode_test_runs: None,
  mooncode_package_candidates_session_id: "",
  mooncode_package_candidates_status: "package candidates idle",
  mooncode_package_candidates: None,
  mooncode_action_plan_session_id: "",
  mooncode_action_plan_status: "action plan idle",
  mooncode_action_plan: None,
  mooncode_runtime_evidence_session_id: "",
  mooncode_runtime_evidence_status: "runtime evidence idle",
  mooncode_runtime_evidence: None,
  mooncode_command_queue_session_id: "",
  mooncode_command_queue_status: "command queue idle",
  mooncode_command_queue: None,
  mooncode_runtime_command_feed_session_id: "",
  mooncode_runtime_command_feed_status: "runtime feed idle",
  mooncode_runtime_command_feed: None,
  mooncode_runtime_replay_session_id: "",
  mooncode_runtime_replay_status: "runtime replay idle",
  mooncode_runtime_replay: None,
  mooncode_preflight_session_id: "",
  mooncode_preflight_status: "preflight idle",
  mooncode_preflights: [],
    mooncode_runtime_dispatch_session_id: "",
    mooncode_runtime_dispatch_status: "runtime dispatch idle",
    mooncode_runtime_dispatch: None,
    mooncode_runtime_claim_session_id: "",
    mooncode_runtime_claim_status: "runtime claim idle",
    mooncode_runtime_claim: None,
    agent_prompt: "Help me improve this book/code workspace. Use the selected context and explain the concrete changes you recommend.",
    agent_model: "",
    agent_web_search: false,
    agent_status: "agent idle",
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
    book_base_types: [],
    selected_book_base_type: "research-book",
    book_patterns: [],
    selected_book_pattern_id: "pdf-evidence-watch",
    pdf_watch_book_id: "research-my-domain-pdf-watch",
    pdf_watch_topic: "my domain",
    pdf_watch_purpose: "Watch approved websites for relevant PDFs, extract full text, analyze with the book-owned method, and notify only when accepted knowledge changes.",
    pdf_watch_websites: "https://example.org/reports\nhttps://example.com/publications",
    pdf_watch_cadence_minutes: "30",
    pdf_watch_source_policy: "web-first",
    pdf_watch_notify_rule: "accepted_new_knowledge",
    pdf_watch_skill_pack: "pdf-watch\npdf-analysis",
    pdf_watch_analysis_method: default_pdf_builder_method(),
    pdf_watch_last_book_id: "",
    eb_target_scope: "active_universe",
    eb_bond_code: "",
    eb_bond_short_name: "",
    eb_issuer: "",
    eb_underlying_company: "",
    eb_exchange: "上交所/深交所",
    eb_as_of: "20260601",
    eb_additional_bonds: "",
    eb_production_checklist: [],
    eb_production_proof_receipt_path: "",
    eb_production_proof_status: "not_run",
    eb_production_proof_level: "",
    eb_production_proof_run_id: "",
    eb_production_proof_failed_checks: [],
    eb_moonclaw_import_run_id: "",
    eb_moonclaw_import_status: "",
    eb_moonclaw_import_receipt_recovered: false,
    eb_moonclaw_import_recovery_source: "",
    eb_moonclaw_retry_recommended: false,
    eb_moonclaw_orphaned_after_timeout: false,
    eb_moonclaw_confirmed_run_status: "",
    eb_moonclaw_run_receipt_path: "",
    eb_moonclaw_retry_import_receipt_path: "",
    eb_moonclaw_retry_import_status: "",
    eb_moonclaw_result_path: "",
    eb_book_result_path: "",
    eb_output_path: "",
    eb_base_type_selection_path: "",
    eb_base_type_selection_ready: false,
    eb_base_type: "",
    eb_base_type_handoff_target: "",
    eb_moontown_publish_receipt_path: "",
    eb_moontown_publish_receipt_ready: false,
    eb_global_standing_goal_ready: false,
    eb_standing_goal_registration_ready: false,
    eb_expected_output_contract_path: "",
    eb_expected_output_contract_ready: false,
    eb_expected_output_contract_id: "",
    eb_workbook_validation_path: "",
    eb_source_screen_path: "",
    eb_output_validation_status: "",
    pdf_watch_status: "ready to publish a book pattern",
    dispatch_status: "daemon idle",
    daemon_status: "daemon manager idle",
    reveal_status: "reveal idle",
    notification_status: "notifications idle",
  }
}

///|
fn default_pdf_builder_method() -> String {
  "# PDF Evidence Watch Method\n\nScreen PDFs for source quality, extract claims that change the current book baseline, and queue Bookkeeper review before accepted knowledge is published."
}

///|
fn default_eb_builder_method() -> String {
  "# Exchangeable Bond Tracking Method\n\nRole: act as an exchangeable-bond credit research and compliance tracking analyst. Use official disclosure PDFs first, reject third-party repost URLs for accepted knowledge, and track one or more EB instruments through issuance/listing, periodic reports, interim events, exchange-window management, redemption/sell-back, and repayment/exit.\n\nOfficial source priority:\n- P0 SSE/SZSE: bond disclosure pages, prospectus, issuance, listing, exchange, redemption, sell-back notices.\n- P1 CNInfo: underlying listed-company mirrored announcements, equity-change reports, control-risk notices, periodic reports.\n- P2 ChinaBond: issuance, tendering, valuation, custody information.\n- P3 SHCH: registration, custody, coupon, redemption and repayment information.\n- P4 CSRC or official review sites: approval, registration, review progress.\n\nLifecycle checklist:\n1. 发行与上市: approval/registration, prospectus, issuance announcement, listing notice, pledge/trust registration.\n2. 存续期定期报告: EB special disclosure in annual/semiannual reports and tracking rating reports.\n3. 存续期临时公告: exchange-price adjustment, ST/suspension/delisting, frozen or defective pledged shares, coverage deterioration, control-transfer risk.\n4. 换股期管理: exchange-start notice, progress notices, 20-trading-day end reminders, equity-change reports.\n5. 赎回与回售: trigger notices, at least 3 implementation reminders, result notices.\n6. 兑付与退出: coupon, principal/interest repayment, delisting, pledge/trust release.\n\nRequired outputs:\n- Maintain accepted findings in wiki/findings/.\n- Produce XLSX files under book/outputs/ named EB追踪_[债券代码]_[债券简称]_[YYYYMMDD].xlsx only after Bookkeeper acceptance.\n- Include Sheet 1 公告追踪主表 and Sheet 2 关键指标监控表 with official source URLs and evidence notes.\n- Mark expected-but-missing disclosures as 未检索到 with reason.\n- Apply cross-verification, timing checks, cumulative-share reconciliation, and official-link validation.\n- Notify only when accepted source-backed knowledge changes the baseline."
}

///|
fn default_eb_builder_websites() -> String {
  [
    "https://www.sse.com.cn/",
    "https://www.szse.cn/",
    "https://www.cninfo.com.cn/",
    "https://www.chinabond.com.cn/",
    "https://www.shclearing.com.cn/",
    "https://www.csrc.gov.cn/",
  ].join("\n")
}

///|
fn apply_selected_book_pattern(model : Model, pattern_id : String) -> Model {
  if pattern_id == "exchangeable-bond-evidence-watch" {
    {
      ..model,
      selected_book_base_type: "research-book",
      selected_book_pattern_id: pattern_id,
      pdf_watch_book_id: "research-exchangeable-bond-credit-compliance-eb-watch",
      pdf_watch_topic: "exchangeable bond credit compliance",
      pdf_watch_purpose: "Standing research-book for official-source PDF discovery, exchangeable bond lifecycle extraction, credit/compliance review, Bookkeeper acceptance, and durable XLSX/wiki outputs when accepted knowledge changes.",
      pdf_watch_websites: default_eb_builder_websites(),
      pdf_watch_cadence_minutes: "30",
      pdf_watch_source_policy: "web-first",
      pdf_watch_notify_rule: "accepted_new_knowledge",
      pdf_watch_skill_pack: "pdf-watch\npdf-analysis\neb-credit-compliance",
      pdf_watch_analysis_method: default_eb_builder_method(),
      eb_target_scope: "active_universe",
      eb_bond_code: "",
      eb_bond_short_name: "",
      eb_issuer: "",
      eb_underlying_company: "",
      eb_exchange: "",
      eb_as_of: "20260601",
      eb_additional_bonds: "",
      pdf_watch_status: "fill a real EB target before launching MoonClaw",
    }
  } else if pattern_id == "pdf-evidence-watch" || pattern_id == "" {
    {
      ..model,
      selected_book_base_type: "research-book",
      selected_book_pattern_id: "pdf-evidence-watch",
      pdf_watch_book_id: "research-my-domain-pdf-watch",
      pdf_watch_topic: "my domain",
      pdf_watch_purpose: "Watch approved websites for relevant PDFs, extract full text, analyze with the book-owned method, and notify only when accepted knowledge changes.",
      pdf_watch_websites: "https://example.org/reports\nhttps://example.com/publications",
      pdf_watch_cadence_minutes: "30",
      pdf_watch_source_policy: "web-first",
      pdf_watch_notify_rule: "accepted_new_knowledge",
      pdf_watch_skill_pack: "pdf-watch\npdf-analysis",
      pdf_watch_analysis_method: default_pdf_builder_method(),
      eb_target_scope: "active_universe",
      eb_bond_code: "",
      eb_bond_short_name: "",
      eb_issuer: "",
      eb_underlying_company: "",
      eb_exchange: "上交所/深交所",
      eb_as_of: "20260601",
      eb_additional_bonds: "",
      pdf_watch_status: "ready to publish PDF Evidence Watch Book",
    }
  } else {
    {
      ..model,
      selected_book_base_type: book_pattern_base_type_from_model(
        model,
        pattern_id,
        default=model.selected_book_base_type,
      ),
      selected_book_pattern_id: pattern_id,
      pdf_watch_status: "discovered registry pattern `\{pattern_id}`; the current creator supports PDF/EB research-book patterns",
    }
  }
}

///|
fn activities() -> Array[ActivityButton] {
  [
    { key: Activity::Explorer, icon: "F", label: "Explorer" },
    { key: Activity::Search, icon: "S", label: "Search" },
    { key: Activity::Inbox, icon: "I", label: "Inbox" },
    { key: Activity::Agents, icon: "A", label: "Agents" },
    { key: Activity::Town, icon: "T", label: "Town" },
    { key: Activity::Runs, icon: "R", label: "Runs" },
    { key: Activity::Settings, icon: "G", label: "Settings" },
  ]
}

///|
fn drawer_tabs() -> Array[DrawerTabButton] {
  [
    { key: DrawerTab::DrawerRequests, label: "Requests" },
    { key: DrawerTab::DrawerMessages, label: "Town Messages" },
    { key: DrawerTab::DrawerRuns, label: "Runs" },
    { key: DrawerTab::DrawerAgents, label: "Agents" },
    { key: DrawerTab::DrawerRecent, label: "Recent" },
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
fn selected_book_id_for_validation(model : Model) -> String {
  if model.pdf_watch_last_book_id != "" {
    model.pdf_watch_last_book_id
  } else if model.pdf_watch_book_id.trim() != "" {
    model.pdf_watch_book_id.trim().to_owned()
  } else if model.selected_workspace_id.has_prefix("book-") {
    model.selected_workspace_id["book-".length():].to_owned()
  } else {
    ""
  }
}

///|
fn selected_book_id_for_portable_export(model : Model) -> String {
  if model.selected_workspace_id.has_prefix("book-") {
    model.selected_workspace_id["book-".length():].to_owned()
  } else {
    selected_book_id_for_validation(model)
  }
}

///|
fn apply_selected_book_base_type(model : Model, base_type : String) -> Model {
  let selected = if base_type == "" { "research-book" } else { base_type }
  let pattern_id = if pattern_matches_base_type(
    model.selected_book_pattern_id,
    selected,
    model.book_patterns,
  ) {
    model.selected_book_pattern_id
  } else {
    first_pattern_for_base_type(model.book_patterns, selected)
  }
  apply_selected_book_pattern(
    { ..model, selected_book_base_type: selected },
    pattern_id,
  )
}

///|
fn pattern_matches_base_type(
  pattern_id : String,
  base_type : String,
  patterns : Array[BookPatternRecord],
) -> Bool {
  for pattern in patterns {
    if pattern.id == pattern_id && pattern.base_type == base_type {
      return true
    }
  }
  pattern_id == "pdf-evidence-watch" && base_type == "research-book"
}

///|
fn first_pattern_for_base_type(
  patterns : Array[BookPatternRecord],
  base_type : String,
) -> String {
  for pattern in patterns {
    if pattern.base_type == base_type {
      return pattern.id
    }
  }
  "pdf-evidence-watch"
}

///|
fn selected_pattern_is_eb(model : Model) -> Bool {
  model.selected_book_pattern_id == "exchangeable-bond-evidence-watch" ||
  selected_book_id_for_validation(model).contains("-eb-watch")
}

///|
fn selected_book_pattern_title(model : Model) -> String {
  for pattern in model.book_patterns {
    if pattern.id == model.selected_book_pattern_id {
      return pattern.title
    }
  }
  if selected_pattern_is_eb(model) {
    "Exchangeable Bond Evidence Watch"
  } else {
    "PDF Evidence Watch Book"
  }
}

///|
fn book_pattern_base_type_from_model(
  model : Model,
  pattern_id : String,
  default~ : String,
) -> String {
  for pattern in model.book_patterns {
    if pattern.id == pattern_id {
      return pattern.base_type
    }
  }
  default
}

///|
fn pdf_watch_builder_pattern_supported(model : Model) -> Bool {
  model.selected_book_base_type == "research-book" &&
  (
    model.selected_book_pattern_id == "pdf-evidence-watch" ||
    model.selected_book_pattern_id == "exchangeable-bond-evidence-watch"
  )
}

///|
fn selected_agent_session(model : Model) -> AgentSession? {
  if model.selected_agent_session_id != "" {
    for session in model.agent_sessions {
      if session.id == model.selected_agent_session_id {
        return Some(session)
      }
    }
  }
  for session in model.agent_sessions {
    if session.workspace_id == model.selected_workspace_id {
      return Some(session)
    }
  }
  None
}

///|
fn first_agent_session_id(
  sessions : Array[AgentSession],
  workspace_id : String,
) -> String {
  for session in sessions {
    if workspace_id == "" || session.workspace_id == workspace_id {
      return session.id
    }
  }
  ""
}

///|
fn agent_session_exists(
  sessions : Array[AgentSession],
  session_id : String,
) -> Bool {
  for session in sessions {
    if session.id == session_id {
      return true
    }
  }
  false
}

///|
fn selected_agent_task_label(model : Model) -> String {
  match selected_agent_session(model) {
    Some(session) =>
      if session.moonclaw_task_id == "" {
        "not attached"
      } else {
        "\{session.moonclaw_task_id} / \{session.status}"
      }
    None => "new session"
  }
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
    None =>
      match model.preview {
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
fn is_generated_site_path(path : String) -> Bool {
  path == "book/site/generated" || path.has_prefix("book/site/generated/")
}

///|
fn remember_primary_preview_path(model : Model, path : String) -> String {
  if path != "" && !is_generated_site_path(path) {
    path
  } else {
    model.primary_preview_path
  }
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
fn json_field(json : Json, key : String) -> Json? {
  match json {
    Json::Object(object) => object.get(key)
    _ => None
  }
}

///|
fn json_string_value(json : Json, key : String, default~ : String) -> String {
  match json_field(json, key) {
    Some(value) =>
      @json.from_json(value) catch {
        _ => default
      }
    None => default
  }
}

///|
fn json_int_value(json : Json, key : String, default~ : Int) -> Int {
  match json_field(json, key) {
    Some(value) =>
      @json.from_json(value) catch {
        _ => default
      }
    None => default
  }
}

///|
fn parse_mooncode_stream_text(text : String) -> Result[MoonCodeStreamPoll, String] {
  let events : Array[MoonCodeEvent] = []
  let mut session_id = ""
  let mut stream = "append-log-incremental"
  let mut stream_source = "unknown"
  let mut since = 0
  let mut next_since = 0
  let mut emitted_count = 0
  for line in text.split("\n") {
    let trimmed = line.trim()
    if trimmed.is_empty() {
      continue
    }
    let record = @json.parse(trimmed.to_owned()) catch {
      _ => { return Err("Invalid MoonCode stream record") }
    }
    let record_type = json_string_value(record, "type", default="")
    if record_type == "meta" {
      session_id = json_string_value(record, "session_id", default=session_id)
      stream = json_string_value(record, "stream", default=stream)
      stream_source = json_string_value(
        record, "stream_source", default=stream_source,
      )
      since = json_int_value(record, "since", default=since)
      next_since = json_int_value(record, "next_since", default=next_since)
      emitted_count = json_int_value(
        record, "emitted_count", default=emitted_count,
      )
    } else if record_type == "event" {
      match json_field(record, "event") {
        Some(event_json) => {
          let event : MoonCodeEvent = @json.from_json(event_json) catch {
            _ => { return Err("Invalid MoonCode stream event") }
          }
          events.push(event)
        }
        None => return Err("MoonCode stream event missing payload")
      }
    } else if record_type == "done" {
      session_id = json_string_value(record, "session_id", default=session_id)
      stream_source = json_string_value(
        record, "stream_source", default=stream_source,
      )
      next_since = json_int_value(record, "next_since", default=next_since)
      emitted_count = json_int_value(
        record, "emitted_count", default=emitted_count,
      )
    }
  }
  Ok({
    session_id,
    stream,
    stream_source,
    since,
    next_since,
    emitted_count,
    events,
  })
}

///|
fn pipe_field(parts : Array[String], index : Int) -> String {
  if index < parts.length() {
    parts[index]
  } else {
    ""
  }
}

///|
fn eb_bond_target_json(
  code : String,
  short_name : String,
  issuer : String,
  underlying : String,
  exchange : String,
) -> Json {
  {
    "bond_code": code,
    "bond_full_name_or_short_name": short_name,
    "issuer": issuer,
    "underlying_listed_company": underlying,
    "exchange": exchange,
  }
}

///|
fn eb_bond_target_has_identity(target : Json) -> Bool {
  json_field_string(target, "bond_code", default="") != "" ||
  json_field_string(target, "bond_full_name_or_short_name", default="") != "" ||
  json_field_string(target, "issuer", default="") != "" ||
  json_field_string(target, "underlying_listed_company", default="") != ""
}

///|
fn eb_target_text_is_placeholder(text : String) -> Bool {
  let clean = text.trim().to_owned()
  clean == "" ||
  clean.contains("示例") ||
  clean.contains("样例") ||
  clean.contains("测试") ||
  clean.contains("请在此处填入") ||
  clean.contains("[") ||
  clean.contains("]") ||
  clean.to_lower().contains("example") ||
  clean.to_lower().contains("placeholder")
}

///|
fn eb_target_code_is_production(code : String) -> Bool {
  let clean = code.trim().to_owned()
  if clean.length() != 6 || !clean.has_prefix("132") || clean == "132001" {
    return false
  }
  for ch in clean {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn eb_target_exchange_is_production(exchange : String) -> Bool {
  let clean = exchange.trim().to_owned()
  clean == "上交所" ||
  clean == "深交所" ||
  clean == "上海证券交易所" ||
  clean == "深圳证券交易所"
}

///|
fn eb_target_production_failed_checks(target : Json) -> Array[String] {
  let failed : Array[String] = []
  if !eb_target_code_is_production(
      json_field_string(target, "bond_code", default=""),
    ) {
    failed.push("real 132XXX EB code")
  }
  if eb_target_text_is_placeholder(
    json_field_string(target, "bond_full_name_or_short_name", default=""),
  ) {
    failed.push("bond full/short name")
  }
  if eb_target_text_is_placeholder(
    json_field_string(target, "issuer", default=""),
  ) {
    failed.push("issuer")
  }
  if eb_target_text_is_placeholder(
    json_field_string(target, "underlying_listed_company", default=""),
  ) {
    failed.push("underlying listed company")
  }
  if !eb_target_exchange_is_production(
      json_field_string(target, "exchange", default=""),
    ) {
    failed.push("exchange 上交所/深交所")
  }
  failed
}

///|
fn eb_targets_production_failed_checks(model : Model) -> Array[String] {
  let failed : Array[String] = []
  let target_scope = eb_target_scope_from_model(model)
  if target_scope == "active_universe" {
    return failed
  }
  let targets = eb_target_bonds_from_model(model)
  if targets.length() == 0 {
    failed.push("add at least one EB target or switch to active universe")
    return failed
  }
  if target_scope == "portfolio" && targets.length() < 2 {
    failed.push("portfolio scope needs at least two EB targets")
  }
  for index, target in targets {
    let target_failed = eb_target_production_failed_checks(target)
    if target_failed.length() > 0 {
      failed.push(
        "target " + (index + 1).to_string() + " needs " +
        target_failed.join(", "),
      )
    }
  }
  failed
}

///|
fn eb_targets_production_ready(model : Model) -> Bool {
  selected_pattern_is_eb(model) &&
  eb_targets_production_failed_checks(model).length() == 0
}

///|
fn eb_target_readiness_summary(model : Model) -> String {
  if eb_target_scope_from_model(model) == "active_universe" {
    return "Active EB universe ready; MoonClaw will discover official sources dynamically"
  }
  let failed = eb_targets_production_failed_checks(model)
  if failed.length() == 0 {
    "EB target ready for MoonClaw production run"
  } else {
    "Production target blocked: " + failed.join("; ")
  }
}

///|
fn eb_builder_moonclaw_action_blocked(model : Model) -> Bool {
  model.pdf_watch_last_book_id != "" &&
  model.selected_book_pattern_id == "exchangeable-bond-evidence-watch" &&
  !eb_targets_production_ready(model)
}

///|
fn eb_target_scope_from_model(model : Model) -> String {
  if !selected_pattern_is_eb(model) {
    return ""
  }
  match model.eb_target_scope.trim().to_lower() {
    "single_bond" | "single-bond" | "single" => "single_bond"
    "portfolio" | "multi_bond" | "multi-bond" | "multi" => "portfolio"
    _ => "active_universe"
  }
}

///|
fn text_lines(value : String) -> Array[String] {
  let lines : Array[String] = []
  for line in value.split("\n") {
    let line = line.to_string().trim().to_owned()
    if line != "" {
      lines.push(line)
    }
  }
  lines
}

///|
fn eb_target_bonds_from_model(model : Model) -> Array[Json] {
  let bonds : Array[Json] = []
  if eb_target_scope_from_model(model) == "active_universe" {
    return bonds
  }
  let primary = eb_bond_target_json(
    trimmed_or(model.eb_bond_code, ""),
    trimmed_or(model.eb_bond_short_name, ""),
    trimmed_or(model.eb_issuer, ""),
    trimmed_or(model.eb_underlying_company, ""),
    trimmed_or(model.eb_exchange, ""),
  )
  if eb_bond_target_has_identity(primary) {
    bonds.push(primary)
  }
  for line in text_lines(model.eb_additional_bonds) {
    let parts : Array[String] = []
    for part in line.split("|") {
      parts.push(part.to_string().trim().to_owned())
    }
    let target = eb_bond_target_json(
      pipe_field(parts, 0),
      pipe_field(parts, 1),
      pipe_field(parts, 2),
      pipe_field(parts, 3),
      pipe_field(parts, 4),
    )
    if eb_bond_target_has_identity(target) {
      bonds.push(target)
    }
  }
  bonds
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
fn json_path_string(json : Json, keys : Array[String], default~ : String) -> String {
  let mut current = json
  for key in keys {
    match current {
      Json::Object(object) =>
        match object.get(key) {
          Some(value) => current = value
          None => return default
        }
      _ => return default
    }
  }
  match current {
    Json::String(value) => value
    _ => default
  }
}

///|
fn json_field_object_or_self(json : Json, key : String) -> Json {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) =>
          match value {
            Json::Object(_) => value
            _ => json
          }
        _ => json
      }
    _ => json
  }
}

///|
fn json_field_bool_label(json : Json, key : String) -> String {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => {
          let parsed : Bool = @json.from_json(value) catch { _ => false }
          if parsed { "true" } else { "false" }
        }
        _ => "false"
      }
    _ => "false"
  }
}

///|
fn json_path_bool_label(json : Json, keys : Array[String]) -> String {
  let mut current = json
  for key in keys {
    match current {
      Json::Object(object) =>
        match object.get(key) {
          Some(value) => current = value
          None => return "false"
        }
      _ => return "false"
    }
  }
  let parsed : Bool = @json.from_json(current) catch { _ => false }
  if parsed { "true" } else { "false" }
}

///|
fn json_field_bool(json : Json, key : String, default~ : Bool) -> Bool {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
fn json_field_int(json : Json, key : String, default~ : Int) -> Int {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => @json.from_json(value) catch { _ => default }
        _ => default
      }
    _ => default
  }
}

///|
fn json_field_string_array_summary(
  json : Json,
  key : String,
  limit~ : Int = 2,
) -> String {
  let items : Array[String] = []
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) =>
          for value in values {
            match value {
              Json::String(text) => if text != "" { items.push(text) }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  if items.length() == 0 {
    "none"
  } else if items.length() <= limit {
    items.join("; ")
  } else {
    items[:limit].join("; ") + " +" + (items.length() - limit).to_string()
  }
}

///|
fn json_field_string_array_items(json : Json, key : String) -> Array[String] {
  let items : Array[String] = []
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) =>
          for value in values {
            match value {
              Json::String(text) => if text != "" { items.push(text) }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  items
}

///|
fn json_field_json_array_items(json : Json, key : String) -> Array[Json] {
  let items : Array[Json] = []
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) =>
          for value in values {
            items.push(value)
          }
        _ => ()
      }
    _ => ()
  }
  items
}

///|
fn production_checklist_item_from_json(
  json : Json,
) -> ProductionChecklistItem? {
  match json {
    Json::Object(_) =>
      Some({
        id: json_field_string(json, "id", default=""),
        label: json_field_string(json, "label", default="Production gate"),
        ok: json_field_bool(json, "ok", default=false),
        requirement: json_field_string(json, "requirement", default=""),
        evidence: json_field_string(json, "evidence", default=""),
      })
    _ => None
  }
}

///|
fn production_checklist_from_json(json : Json) -> Array[ProductionChecklistItem] {
  let items : Array[ProductionChecklistItem] = []
  match json {
    Json::Object(object) =>
      match object.get("production_checklist") {
        Some(Json::Array(values)) =>
          for value in values {
            match production_checklist_item_from_json(value) {
              Some(item) => items.push(item)
              None => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
  items
}

///|
fn model_with_eb_health_json(model : Model, health : Json) -> Model {
  {
    ..model,
    eb_production_checklist: production_checklist_from_json(health),
    eb_production_proof_receipt_path: json_field_string(
      health,
      "production_proof_receipt_path",
      default="",
    ),
    eb_production_proof_status: json_field_string(
      health,
      "production_proof_status",
      default="not_run",
    ),
    eb_production_proof_level: json_field_string(
      health,
      "production_proof_level",
      default="",
    ),
    eb_production_proof_run_id: json_field_string(
      health,
      "production_proof_run_id",
      default="",
    ),
    eb_production_proof_failed_checks: json_field_string_array_items(
      health,
      "production_proof_failed_checks",
    ),
    eb_moonclaw_import_run_id: json_field_string(
      health,
      "moonclaw_import_run_id",
      default="",
    ),
    eb_moonclaw_import_status: json_field_string(
      health,
      "moonclaw_import_status",
      default="",
    ),
    eb_moonclaw_import_receipt_recovered: json_field_bool(
      health,
      "moonclaw_import_receipt_recovered",
      default=false,
    ),
    eb_moonclaw_import_recovery_source: json_field_string(
      health,
      "moonclaw_import_recovery_source",
      default="",
    ),
    eb_moonclaw_retry_recommended: json_field_bool(
      health,
      "moonclaw_run_retry_recommended",
      default=false,
    ),
    eb_moonclaw_orphaned_after_timeout: json_field_bool(
      health,
      "moonclaw_run_orphaned_after_timeout",
      default=false,
    ),
    eb_moonclaw_confirmed_run_status: json_field_string(
      health,
      "moonclaw_confirmed_run_status",
      default="",
    ),
    eb_moonclaw_run_receipt_path: json_field_string(
      health,
      "moonclaw_run_receipt_path",
      default="",
    ),
    eb_moonclaw_retry_import_receipt_path: json_field_string(
      health,
      "moonclaw_retry_import_receipt_path",
      default="",
    ),
    eb_moonclaw_retry_import_status: json_field_string(
      health,
      "moonclaw_retry_import_status",
      default="",
    ),
    eb_moonclaw_result_path: json_field_string(
      health,
      "moonclaw_result_path",
      default="",
    ),
    eb_book_result_path: json_field_string(
      health,
      "book_result_path",
      default="",
    ),
    eb_output_path: json_field_string(health, "output_path", default=""),
    eb_base_type_selection_path: json_field_string(
      health,
      "base_type_selection_path",
      default="",
    ),
    eb_base_type_selection_ready: json_field_bool(
      health,
      "base_type_selection_ready",
      default=false,
    ),
    eb_base_type: json_field_string(health, "base_type", default=""),
    eb_base_type_handoff_target: json_field_string(
      health,
      "base_type_handoff_target",
      default="",
    ),
    eb_moontown_publish_receipt_path: json_field_string(
      health,
      "moontown_template_publish_receipt_path",
      default="",
    ),
    eb_moontown_publish_receipt_ready: json_field_bool(
      health,
      "moontown_template_publish_receipt_ready",
      default=false,
    ),
    eb_global_standing_goal_ready: json_field_bool(
      health,
      "global_standing_goal_ready",
      default=false,
    ),
    eb_standing_goal_registration_ready: json_field_bool(
      health,
      "standing_goal_registration_ready",
      default=false,
    ),
    eb_expected_output_contract_path: json_field_string(
      health,
      "expected_output_contract_path",
      default="",
    ),
    eb_expected_output_contract_ready: json_field_bool(
      health,
      "expected_output_contract_ready",
      default=false,
    ),
    eb_expected_output_contract_id: json_path_string(
      health,
      ["expected_output_contract", "output_contract"],
      default="",
    ),
    eb_workbook_validation_path: json_field_string(
      health,
      "workbook_validation_path",
      default="",
    ),
    eb_source_screen_path: json_field_string(
      health,
      "source_screen_path",
      default="",
    ),
    eb_output_validation_status: json_path_string(
      health,
      ["output_validation", "status"],
      default="",
    ),
  }
}

fn moonclaw_import_status_summary(result : MoonclawImportResult) -> String {
  let run_status = json_field_string(
    result.run_health,
    "moonclaw_confirmed_run_status",
    default="unknown",
  )
  let stderr_clean = json_field_bool_label(
    result.run_health,
    "moonclaw_execution_stderr_clean",
  )
  let production = json_field_bool_label(result.run_health, "production_ready")
  let workbook_validation = json_field_bool_label(
    result.run_health,
    "workbook_validation_ready",
  )
  let workbook_xml = json_field_bool_label(
    result.run_health,
    "workbook_internal_contract_ready",
  )
  let appendix_notes = json_field_bool_label(
    result.run_health,
    "workbook_appendix_notes_ready",
  )
  let data_rows = json_field_bool_label(
    result.run_health,
    "workbook_data_proof_ready",
  )
  let hyperlinks = json_field_bool_label(
    result.run_health,
    "workbook_hyperlinks_ready",
  )
  let quality_proof = json_field_bool_label(
    result.run_health,
    "workbook_quality_proof_ready",
  )
  let lifecycle_proof = json_field_bool_label(
    result.run_health,
    "workbook_lifecycle_proof_ready",
  )
  let target_match = json_field_bool_label(
    result.run_health,
    "output_target_match_ready",
  )
  let production_failed = json_field_string_array_summary(
    result.run_health,
    "production_failed_checks",
    limit=2,
  )
  let expected_output = json_field_bool_label(
    result.run_health,
    "expected_output_contract_ready",
  )
  "MoonClaw import \{result.status}; proposal \{empty_label(result.proposal_id)}; run \{run_status}; execution stderr clean \{stderr_clean}; expected output contract \{expected_output}; workbook validation \{workbook_validation}; workbook XML \{workbook_xml}; data rows \{data_rows}; hyperlinks \{hyperlinks}; appendix notes \{appendix_notes}; quality proof \{quality_proof}; lifecycle proof \{lifecycle_proof}; target match \{target_match}; production \{production}; blocking \{production_failed}"
}

///|
fn moonclaw_run_status_summary(result : MoonclawRunResult) -> String {
  let run_status = json_field_string(
    result.run_health,
    "moonclaw_confirmed_run_status",
    default=result.status,
  )
  let production = json_field_bool_label(result.run_health, "production_ready")
  let live = json_field_bool_label(
    result.run_health,
    "real_moonclaw_result_ready",
  )
  let production_source = json_field_bool_label(
    result.run_health,
    "source_screen_production_ready",
  )
  let workbook_validation = json_field_bool_label(
    result.run_health,
    "workbook_validation_ready",
  )
  let appendix_notes = json_field_bool_label(
    result.run_health,
    "workbook_appendix_notes_ready",
  )
  let data_rows = json_field_bool_label(
    result.run_health,
    "workbook_data_proof_ready",
  )
  let hyperlinks = json_field_bool_label(
    result.run_health,
    "workbook_hyperlinks_ready",
  )
  let quality_proof = json_field_bool_label(
    result.run_health,
    "workbook_quality_proof_ready",
  )
  let lifecycle_proof = json_field_bool_label(
    result.run_health,
    "workbook_lifecycle_proof_ready",
  )
  let target_match = json_field_bool_label(
    result.run_health,
    "output_target_match_ready",
  )
  let production_failed = json_field_string_array_summary(
    result.run_health,
    "production_failed_checks",
    limit=2,
  )
  let expected_output = json_field_bool_label(
    result.run_health,
    "expected_output_contract_ready",
  )
  "MoonClaw run \{result.status}; run \{empty_label(result.run_id)}; confirmed status \{run_status}; live result \{live}; expected output contract \{expected_output}; workbook validation \{workbook_validation}; data rows \{data_rows}; hyperlinks \{hyperlinks}; appendix notes \{appendix_notes}; quality proof \{quality_proof}; lifecycle proof \{lifecycle_proof}; target match \{target_match}; production source \{production_source}; production \{production}; blocking \{production_failed}"
}

///|
fn moonclaw_reconcile_status_summary(result : MoonclawReconcileResult) -> String {
  let ok = if result.ok { "accepted" } else { "waiting" }
  let health_status = json_field_string(
    result.run_health,
    "status",
    default="unknown",
  )
  let durable = json_field_bool_label(result.run_health, "durable_ready")
  let production = json_field_bool_label(result.run_health, "production_ready")
  let live = json_field_bool_label(
    result.run_health,
    "real_moonclaw_result_ready",
  )
  let production_source = json_field_bool_label(
    result.run_health,
    "source_screen_production_ready",
  )
  let workbook_validation = json_field_bool_label(
    result.run_health,
    "workbook_validation_ready",
  )
  let workbook_xml = json_field_bool_label(
    result.run_health,
    "workbook_internal_contract_ready",
  )
  let appendix_notes = json_field_bool_label(
    result.run_health,
    "workbook_appendix_notes_ready",
  )
  let data_rows = json_field_bool_label(
    result.run_health,
    "workbook_data_proof_ready",
  )
  let hyperlinks = json_field_bool_label(
    result.run_health,
    "workbook_hyperlinks_ready",
  )
  let quality_proof = json_field_bool_label(
    result.run_health,
    "workbook_quality_proof_ready",
  )
  let lifecycle_proof = json_field_bool_label(
    result.run_health,
    "workbook_lifecycle_proof_ready",
  )
  let sample_validation = json_field_bool_label(
    result.run_health,
    "workbook_validation_sample_run",
  )
  let target_match = json_field_bool_label(
    result.run_health,
    "output_target_match_ready",
  )
  let production_failed = json_field_string_array_summary(
    result.run_health,
    "production_failed_checks",
    limit=2,
  )
  let expected_output = json_field_bool_label(
    result.run_health,
    "expected_output_contract_ready",
  )
  "MoonClaw reconcile \{result.status} (\{ok}); book \{empty_label(result.book_id)}; run \{empty_label(result.run_id)}; output \{empty_label(result.output_path)}; source screen \{empty_label(result.source_screen_path)}; durable \{durable}; production \{production}; live result \{live}; production source \{production_source}; expected output contract \{expected_output}; workbook validation \{workbook_validation}; workbook XML \{workbook_xml}; data rows \{data_rows}; hyperlinks \{hyperlinks}; appendix notes \{appendix_notes}; quality proof \{quality_proof}; lifecycle proof \{lifecycle_proof}; sample validation \{sample_validation}; target match \{target_match}; health \{health_status}; blocking \{production_failed}"
}

///|
fn eb_recovered_output_status_summary(result : EbRecoveredOutputResult) -> String {
  let ok = if result.ok { "accepted" } else { "rejected" }
  let durable = json_field_bool_label(result.run_health, "durable_ready")
  let production = json_field_bool_label(result.run_health, "production_ready")
  let live = json_field_bool_label(
    result.run_health,
    "real_moonclaw_result_ready",
  )
  let production_source = json_field_bool_label(
    result.run_health,
    "source_screen_production_ready",
  )
  let target_match = json_field_bool_label(
    result.run_health,
    "output_target_match_ready",
  )
  let workbook_validation = json_field_bool_label(
    result.run_health,
    "workbook_validation_ready",
  )
  let production_failed = json_field_string_array_summary(
    result.run_health,
    "production_failed_checks",
    limit=2,
  )
  let expected_output = json_field_bool_label(
    result.run_health,
    "expected_output_contract_ready",
  )
  "Recovered EB output \{result.status} (\{ok}); run \{empty_label(result.run_id)}; output \{empty_label(result.output_path)}; source screen \{empty_label(result.source_screen_path)}; durable \{durable}; production \{production}; live MoonClaw result \{live}; production source \{production_source}; expected output contract \{expected_output}; workbook validation \{workbook_validation}; target match \{target_match}; blocking \{production_failed}"
}

///|
fn eb_production_proof_status_summary(result : EbProductionProofResult) -> String {
  let production = json_field_bool_label(result.run_health, "production_ready")
  let durable = json_field_bool_label(result.run_health, "durable_ready")
  let targets = json_field_bool_label(
    result.run_health,
    "targets_production_ready",
  )
  let health_status = json_field_string(
    result.run_health,
    "status",
    default="unknown",
  )
  let recovered = json_field_bool_label(
    result.run_health,
    "moonclaw_import_receipt_recovered",
  )
  let retry = json_field_bool_label(
    result.run_health,
    "moonclaw_run_retry_recommended",
  )
  let expected_output = json_field_bool_label(
    result.run_health,
    "expected_output_contract_ready",
  )
  let base_type = json_field_bool_label(
    result.run_health,
    "base_type_selection_ready",
  )
  let moontown_publish = json_field_bool_label(
    result.run_health,
    "moontown_template_publish_receipt_ready",
  )
  let import_run = json_field_string(
    result.run_health,
    "moonclaw_import_run_id",
    default=result.run_id,
  )
  let blockers = if result.failed_checks.length() == 0 {
    "none"
  } else if result.failed_checks.length() <= 2 {
    result.failed_checks.join("; ")
  } else {
    result.failed_checks[:2].join("; ") +
    " +" +
    (result.failed_checks.length() - 2).to_string()
  }
  "EB production proof \{result.status}; level \{result.proof_level}; run \{empty_label(import_run)}; base type \{base_type}; Moontown publish \{moontown_publish}; recovered import \{recovered}; retry recommended \{retry}; targets \{targets}; expected output contract \{expected_output}; durable \{durable}; production \{production}; health \{health_status}; receipt \{result.receipt_path}; blocking \{blockers}"
}

fn eb_run_health_json_status_summary(health : Json) -> String {
  let production_failed = json_field_string_array_items(
    health,
    "production_failed_checks",
  )
  let blocking = if production_failed.length() == 0 {
    "none"
  } else if production_failed.length() <= 2 {
    production_failed.join("; ")
  } else {
    production_failed[:2].join("; ") +
    " +" +
    (production_failed.length() - 2).to_string()
  }
  "Production audit \{json_field_string(health, "status", default="unknown")}; durable \{json_field_bool_label(health, "durable_ready")}; production \{json_field_bool_label(health, "production_ready")}; base type \{json_field_bool_label(health, "base_type_selection_ready")}; Moontown publish \{json_field_bool_label(health, "moontown_template_publish_receipt_ready")}; standing goal \{json_field_bool_label(health, "standing_goal_registration_ready")}; run \{empty_label(json_field_string(health, "moonclaw_import_run_id", default=""))}; run status \{empty_label(json_field_string(health, "moonclaw_confirmed_run_status", default=""))}; recovered import \{json_field_bool_label(health, "moonclaw_import_receipt_recovered")}; retry recommended \{json_field_bool_label(health, "moonclaw_run_retry_recommended")}; confirmed \{json_field_bool_label(health, "moonclaw_confirmed_run_ready")}; succeeded \{json_field_bool_label(health, "moonclaw_confirmed_run_succeeded")}; live result \{json_field_bool_label(health, "real_moonclaw_result_ready")}; expected output contract \{json_field_bool_label(health, "expected_output_contract_ready")}; workbook validation \{json_field_bool_label(health, "workbook_validation_ready")}; workbook XML \{json_field_bool_label(health, "workbook_internal_contract_ready")}; data rows \{json_field_bool_label(health, "workbook_data_proof_ready")}; hyperlinks \{json_field_bool_label(health, "workbook_hyperlinks_ready")}; appendix notes \{json_field_bool_label(health, "workbook_appendix_notes_ready")}; quality proof \{json_field_bool_label(health, "workbook_quality_proof_ready")}; lifecycle proof \{json_field_bool_label(health, "workbook_lifecycle_proof_ready")}; sample validation \{json_field_bool_label(health, "workbook_validation_sample_run")}; target match \{json_field_bool_label(health, "output_target_match_ready")}; source production \{json_field_bool_label(health, "source_screen_production_ready")}; blocking \{blocking}"
}

///|
fn app_tool_portable_status_summary(result : Json) -> String {
  let status = json_field_string(result, "status", default="unknown")
  let book_id = json_field_string(result, "book_id", default="")
  let index_path = json_field_string(
    result,
    "index_path",
    default=json_field_string(
      result,
      "portable_index_path",
      default="portable/app-tool/index.html",
    ),
  )
  let manifest_path = json_field_string(
    result,
    "manifest_path",
    default=json_field_string(
      result,
      "portable_manifest_path",
      default="portable/app-tool/portable-manifest.json",
    ),
  )
  let copied = json_field_string_array_items(result, "copied_paths").length()
  let missing = json_field_string_array_items(result, "missing_paths").length()
  let api_free = json_field_bool_label(result, "operatable_without_moondesk_api")
  "Portable app-tool export \{status}; book \{empty_label(book_id)}; index \{index_path}; manifest \{manifest_path}; copied \{copied}; missing \{missing}; API-free \{api_free}"
}

///|
fn app_tool_portable_all_status_summary(result : Json) -> String {
  let status = json_field_string(result, "status", default="unknown")
  let book_count = json_field_int(result, "app_tool_book_count", default=0)
  let exported = json_field_int(result, "exported_count", default=0)
  let failures = json_field_int(result, "failure_count", default=0)
  let warnings = json_field_int(result, "api_warning_count", default=0)
  let ready = json_field_int(result, "portable_ready_count", default=0)
  let required = json_field_int(result, "export_required_count", default=0)
  let api_free = json_field_bool_label(result, "operatable_without_moondesk_api")
  "Portable app-tool batch \{status}; books \{book_count}; exported \{exported}; ready \{ready}; export required \{required}; failures \{failures}; API warnings \{warnings}; API-free \{api_free}"
}

fn request_title(record : RequestRecord) -> String {
  json_field_string(record.request, "title", default="Moondesk request")
}

///|
fn trimmed_or(value : String, fallback : String) -> String {
  let value = value.trim().to_owned()
  if value == "" {
    fallback
  } else {
    value
  }
}

///|
fn int_text(value : String, fallback : Int) -> Int {
  @string.parse_int(value.trim().to_owned()) catch {
    _ => fallback
  }
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
    if result.loaded {
      "loaded"
    } else {
      "installed"
    }
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
fn file_url(model : Model, path : String) -> String {
  if model.selected_workspace_id == "" {
    "#"
  } else {
    "/api/workspaces/\{model.selected_workspace_id}/file/\{encode_path(path)}"
  }
}

///|
fn html_preview_url(model : Model, path : String) -> String {
  file_url(model, path)
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
extern "js" fn encode_component(text : String) -> String = "(text)=>encodeURIComponent(text)"

///|
#cfg(target="js")
extern "js" fn encode_path(text : String) -> String =
  #| (text) => String(text).split("/").map(encodeURIComponent).join("/")

///|
#cfg(target="js")
extern "js" fn browser_initial_activity() -> String =
  #| () => new URLSearchParams(globalThis.location?.search || "").get("activity") || ""

///|
#cfg(target="js")
extern "js" fn browser_set_activity(slug : String) =
  #| (slug) => {
  #|   if (!globalThis.location || !globalThis.history) return;
  #|   const url = new URL(globalThis.location.href);
  #|   url.searchParams.set("activity", slug);
  #|   globalThis.history.replaceState(null, "", url.toString());
  #| }

///|
fn sync_activity_cmd(activity : Activity) -> @rabbita.Cmd {
  @cmd.raw_effect(
    _ => browser_set_activity(activity_slug(activity)),
    kind=@cmd.after_render,
  )
}

///|
fn sync_activity_batch(activity : Activity, cmd : @rabbita.Cmd) -> @rabbita.Cmd {
  @rabbita.batch([cmd, sync_activity_cmd(activity)])
}

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
extern "js" fn browser_pick_import_files() -> @js.Promise =
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
  #| () => {
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
  @cmd.raw_effect(
    _ => send_browser_notification(title, body),
    kind=@cmd.after_render,
  )
}

///|
fn parse_browser_import_batch(
  text : String,
) -> Result[Array[LocalImportFile], String] {
  if text.trim().to_owned() == "" {
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
  @rabbita.perform(fn(result) { dispatch(LocalFilesPicked(result)) }, async fn() noraise {
    let text : String = browser_pick_import_files().wait().cast() catch {
        error => return Err("Failed to read local files: \{error}")
      }
    parse_browser_import_batch(text)
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
      let moonclaw_events : Result[Array[DeskEvent], Error] = try? @json.from_json(
        json,
      )
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
fn fetch_agent_daemon_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/agents/daemon",
    expect=@http.Json(fn(result) { dispatch(LoadedAgentDaemon(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonClaw daemon status")
      }
    }),
  )
}

///|
fn fetch_agent_models_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/agents/models",
    expect=@http.Json(fn(result) { dispatch(LoadedAgentModels(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonClaw model listing")
      }
    }),
  )
}

///|
fn fetch_mooncode_capabilities_cmd(
  dispatch : (Msg) -> @rabbita.Cmd
) -> @rabbita.Cmd {
  @http.get(
    "/api/mooncode/capabilities",
    expect=@http.Json(fn(result) { dispatch(LoadedMoonCodeCapabilities(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode capability contract")
      }
    }),
  )
}

///|
fn fetch_agent_sessions_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  workspace_id : String,
) -> @rabbita.Cmd {
  let query = if workspace_id == "" {
    ""
  } else {
    "?workspace=\{encode_component(workspace_id)}"
  }
  @http.get(
    "/api/agents/sessions\{query}",
    expect=@http.Json(fn(result) { dispatch(LoadedAgentSessions(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid agent session listing")
      }
    }),
  )
}

///|
fn fetch_mooncode_stream_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  since : Int,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/stream?format=jsonl&since=\{since}&live=true&timeout_ms=1000&poll_ms=100",
    expect=@http.Text(fn(result) {
      let decoded : Result[MoonCodeStreamPoll, String] = match result {
        Ok(text) => parse_mooncode_stream_text(text)
        Err(error) => Err(error)
      }
      dispatch(LoadedMoonCodeStream(session_id, decoded))
    }),
  )
}

///|
fn save_mooncode_stream_checkpoint_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  next_since : Int,
) -> @rabbita.Cmd {
  if session_id == "" || next_since <= 0 {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/stream-state",
    @http.Body::Json({
      "consumer_id": "moondesk-ui",
      "last_seen_sequence": next_since,
    }),
    expect=@http.Json(
      fn(result) { dispatch(SavedMoonCodeStreamCheckpoint(session_id, result)) },
      json => {
        Ok(@json.from_json(json)) catch {
          _ => Err("Could not save MoonCode stream checkpoint")
        }
      },
    ),
  )
}

///|
fn fetch_mooncode_change_set_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/change-set",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeChangeSet(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode change set")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_event_sink_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-events",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeEventSink(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime event sink")
      }
    }),
  )
}

///|
fn fetch_mooncode_eval_report_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/eval-report",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeEvalReport(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode eval report")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_handoff_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-handoff",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeHandoff(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime handoff")
      }
    }),
  )
}

///|
fn fetch_mooncode_patch_set_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/patch-set",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodePatchSet(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode patch set")
      }
    }),
  )
}

///|
fn fetch_mooncode_tool_approvals_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/tool-approvals",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeToolApprovals(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode tool approvals")
      }
    }),
  )
}

///|
fn mooncode_tool_authorization_probe_payload(
  selected_path : String,
  tool_id : String,
) -> Json {
  let path = if selected_path == "" { "wiki/index.md" } else { selected_path }
  match tool_id {
    "read" => {
      "tool_call_id": "moondesk-ui-probe-read",
      "tool_name": "read",
      "path": path,
      "arguments": "{\"path\":\"\{path}\"}",
    }
    "write" => {
      "tool_call_id": "moondesk-ui-probe-write",
      "tool_name": "write",
      "path": path,
      "arguments": "{\"path\":\"\{path}\",\"content\":\"MoonCode authorization probe\"}",
    }
    "shell" => {
      "tool_call_id": "moondesk-ui-probe-shell",
      "tool_name": "shell",
      "command": "moon check",
      "arguments": "{\"cmd\":[\"moon\",\"check\"]}",
    }
    _ => {
      "tool_call_id": "moondesk-ui-probe-\{tool_id}",
      "tool_name": tool_id,
      "path": path,
      "arguments": "{\"path\":\"\{path}\"}",
    }
  }
}

///|
fn probe_mooncode_tool_authorization_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  selected_path : String,
  tool_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/tool-authorization",
    @http.Body::Json(
      mooncode_tool_authorization_probe_payload(selected_path, tool_id),
    ),
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeToolAuthorization(session_id, tool_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode tool authorization")
      }
    }),
  )
}

///|
fn fetch_mooncode_test_runs_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/test-runs",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeTestRuns(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode test runs")
      }
    }),
  )
}

///|
fn fetch_mooncode_package_candidates_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/package-candidates",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodePackageCandidates(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode package candidates")
      }
    }),
  )
}

///|
fn fetch_mooncode_action_plan_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/action-plan",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeActionPlan(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode action plan")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_evidence_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-evidence",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeEvidence(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime evidence")
      }
    }),
  )
}

///|
fn fetch_mooncode_command_queue_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/commands",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeCommandQueue(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode command queue")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_command_feed_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-commands",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeCommandFeed(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime command feed")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_replay_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-replay",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeReplay(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime replay state")
      }
    }),
  )
}

///|
fn fetch_mooncode_command_preflight_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  action : String,
  context_path : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/preflight?action=\{encode_component(action)}&context_path=\{encode_component(context_path)}",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeCommandPreflight(session_id, action, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode command preflight")
      }
    }),
  )
}

///|
fn fetch_mooncode_preflight_matrix_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  context_path : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @rabbita.batch([
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "run_tests", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "run_build", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "run_eval", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "package", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "commit", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "accept", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "apply_patch", context_path,
    ),
    fetch_mooncode_command_preflight_cmd(
      dispatch, session_id, "revert_patch", context_path,
    ),
  ])
}

///|
fn fetch_mooncode_runtime_dispatch_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-dispatch",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeDispatch(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime dispatch state")
      }
    }),
  )
}

///|
fn fetch_mooncode_runtime_claim_state_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.get(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-claim",
    expect=@http.Json(fn(result) {
      dispatch(LoadedMoonCodeRuntimeClaimState(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime claim state")
      }
    }),
  )
}

///|
fn claim_mooncode_runtime_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  force : Bool,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-claim",
    @http.Body::Json({
      "consumer_id": "moondesk-ui-inspector",
      "max_count": 1,
      "force": force,
    }),
    expect=@http.Json(fn(result) {
      dispatch(ClaimedMoonCodeRuntime(session_id, force, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime claim response")
      }
    }),
  )
}

///|
fn run_mooncode_runtime_loop_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-supervisor",
    @http.Body::Json({
      "consumer_id": "moondesk-ui-runtime-loop",
      "max_turns": 8,
      "live_wait_ms": 5000,
      "poll_ms": 250,
    }),
    expect=@http.Json(fn(result) {
      dispatch(RanMoonCodeRuntimeLoop(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode native runtime loop response")
      }
    }),
  )
}

///|
fn start_mooncode_runtime_service_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
) -> @rabbita.Cmd {
  if session_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-service",
    @http.Body::Json({
      "consumer_id": "moondesk-ui-runtime-service",
      "max_turns": 8,
      "live_wait_ms": 5000,
      "poll_ms": 250,
    }),
    expect=@http.Json(fn(result) {
      dispatch(StartedMoonCodeRuntimeService(session_id, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode native runtime service response")
      }
    }),
  )
}

///|
fn ack_mooncode_runtime_command_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session_id : String,
  command_id : String,
  status : String,
) -> @rabbita.Cmd {
  if session_id == "" || command_id == "" {
    return @rabbita.none
  }
  @http.post(
    "/api/mooncode/sessions/\{encode_component(session_id)}/runtime-replay",
    @http.Body::Json({
      "consumer_id": "moondesk-ui-inspector",
      "command_id": command_id,
      "status": status,
      "detail": "Moondesk UI inspector recorded runtime \{status} for \{command_id}.",
    }),
    expect=@http.Json(fn(result) {
      dispatch(AckedMoonCodeRuntimeCommand(session_id, command_id, status, result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid MoonCode runtime replay acknowledgement")
      }
    }),
  )
}

///|
fn fetch_selected_mooncode_stream_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  match selected_agent_session(model) {
    Some(session) => {
      let since = if model.mooncode_stream_session_id == session.id {
        model.mooncode_stream_cursor
      } else {
        0
      }
      fetch_mooncode_stream_cmd(dispatch, session.id, since)
    }
    None => @rabbita.none
  }
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
fn fetch_book_patterns_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/books/patterns",
    expect=@http.Json(fn(result) { dispatch(LoadedBookPatterns(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid book pattern catalog")
      }
    }),
  )
}

///|
fn fetch_book_base_types_cmd(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @http.get(
    "/api/books/base-types",
    expect=@http.Json(fn(result) { dispatch(LoadedBookBaseTypes(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Invalid book base-type catalog")
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
fn import_url_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
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
      "kind": if file.source == "paste" {
        "paste"
      } else {
        "file"
      },
      "title": file.name,
      "filename": file.name,
      "browser_import_id": file.id,
      "content_type": file.media_type,
      "note": model.import_note,
      "content": if is_data_url {
        ""
      } else {
        file.content
      },
      "data_url": if is_data_url {
        file.content
      } else {
        ""
      },
    }),
    expect=@http.Json(fn(result) { dispatch(ImportedInbox(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not import local file")
      }
    }),
  )
}

///|
fn save_view_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
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
fn save_tag_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
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
    "prompt": trimmed_or(
      model.request_prompt,
      "Watch the selected MoonBook context for useful updates.",
    ),
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
fn create_pdf_evidence_watch_book_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let cadence = clamp_int(
    int_text(model.pdf_watch_cadence_minutes, 30),
    1,
    525600,
  )
  let websites = text_lines(model.pdf_watch_websites)
  let skill_pack = text_lines(model.pdf_watch_skill_pack)
  let notify_on = [
    trimmed_or(model.pdf_watch_notify_rule, "accepted_new_knowledge"),
  ]
  let body : Json = {
    "base_type": model.selected_book_base_type,
    "pattern_id": model.selected_book_pattern_id,
    "book_id": trimmed_or(model.pdf_watch_book_id, ""),
    "topic": trimmed_or(model.pdf_watch_topic, "my domain"),
    "purpose": trimmed_or(model.pdf_watch_purpose, ""),
    "websites": json_string_array(websites),
    "cadence_minutes": cadence,
    "source_policy": trimmed_or(model.pdf_watch_source_policy, "web-first"),
    "notify_on": json_string_array(notify_on),
    "skill_pack": json_string_array(skill_pack),
    "analysis_method": trimmed_or(
      model.pdf_watch_analysis_method,
      "# My Analysis Method\n\nScreen PDFs against the current book baseline and queue Bookkeeper review before accepted knowledge is published.",
    ),
    "notify_rule": trimmed_or(
      model.pdf_watch_notify_rule,
      "accepted_new_knowledge",
    ),
    "watch": {
      "cadence_minutes": cadence,
      "source_policy": trimmed_or(model.pdf_watch_source_policy, "web-first"),
      "websites": json_string_array(websites),
      "file_types": json_string_array(["pdf"]),
      "dedupe_by": json_string_array(["url", "title", "sha256"]),
    },
    "analysis": {
      "method_page": "wiki/methods/my-analysis-method.md",
      "notify_on": json_string_array(notify_on),
    },
    "bond_code": trimmed_or(model.eb_bond_code, ""),
    "bond_short_name": trimmed_or(model.eb_bond_short_name, ""),
    "issuer": trimmed_or(model.eb_issuer, ""),
    "underlying_company": trimmed_or(model.eb_underlying_company, ""),
    "exchange": trimmed_or(model.eb_exchange, ""),
    "target_scope": eb_target_scope_from_model(model),
    "target_bonds": Json::array(eb_target_bonds_from_model(model)),
  }
  @http.post(
    "/api/books/from-pattern",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(CreatedPdfEvidenceWatchBook(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not publish PDF evidence watch book")
      }
    }),
  )
}

///|
fn run_eb_sample_validation_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "book_id": selected_book_id_for_validation(model),
    "bond_code": trimmed_or(model.eb_bond_code, "132001"),
    "bond_short_name": trimmed_or(model.eb_bond_short_name, "示例EB"),
    "as_of": trimmed_or(model.eb_as_of, "20260601"),
  }
  @http.post(
    "/api/books/eb-sample-run",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(RanEbSampleValidation(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not run EB output validation")
      }
    }),
  )
}

///|
fn import_eb_moonclaw_packet_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
  confirm : Bool,
) -> @rabbita.Cmd {
  let body : Json = {
    "book_id": selected_book_id_for_validation(model),
    "confirm": confirm,
    "inline": false,
  }
  @http.post(
    "/api/books/moonclaw-import",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(ImportedMoonclawPacket(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not import MoonClaw proposal packet")
      }
    }),
  )
}

///|
fn run_confirmed_eb_moonclaw_job_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "book_id": selected_book_id_for_validation(model),
    "timeout_ms": 120000,
  }
  @http.post(
    "/api/books/moonclaw-run",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(RanConfirmedMoonclawJob(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not run confirmed MoonClaw job")
      }
    }),
  )
}

///|
fn reconcile_eb_moonclaw_result_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "book_id": selected_book_id_for_validation(model),
  }
  @http.post(
    "/api/books/moonclaw-reconcile",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(ReconciledMoonclawResult(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not reconcile MoonClaw result")
      }
    }),
  )
}

///|
fn accept_recovered_eb_output_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "book_id": selected_book_id_for_validation(model),
    "reason": "Operator accepted the currently validated EB workbook/source-screen package as recovered durable output.",
  }
  @http.post(
    "/api/books/accept-recovered-eb-output",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(AcceptedRecoveredEbOutput(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not accept recovered EB output")
      }
    }),
  )
}

///|
fn prove_eb_production_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "book_id": selected_book_id_for_validation(model),
    "launch_if_missing": true,
    "execute_moonclaw": true,
    "force_execute": false,
    "timeout_ms": 300000,
  }
  @http.post(
    "/api/books/eb-production-proof",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(ProvedEbProduction(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not prove EB production run")
      }
    }),
  )
}

///|
fn fresh_retry_eb_production_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = {
    "book_id": selected_book_id_for_validation(model),
    "launch_if_missing": true,
    "execute_moonclaw": true,
    "force_execute": true,
    "timeout_ms": 300000,
  }
  @http.post(
    "/api/books/eb-production-proof",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(ProvedEbProduction(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not retry EB production run")
      }
    }),
  )
}

///|
fn audit_eb_production_health_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = { "book_id": selected_book_id_for_validation(model) }
  @http.post(
    "/api/books/refresh-eb-runtime",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(AuditedEbProductionHealth(result))
    }, json => {
      Ok(json_field_object_or_self(json, "run_health"))
    }),
  )
}

///|
fn export_app_tool_portable_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let body : Json = { "book_id": selected_book_id_for_portable_export(model) }
  @http.post(
    "/api/books/app-tool-portable",
    @http.Body::Json(body),
    expect=@http.Json(fn(result) {
      dispatch(ExportedAppToolPortable(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not export portable app-tool bundle")
      }
    }),
  )
}

///|
fn export_all_app_tool_portable_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
) -> @rabbita.Cmd {
  @http.post(
    "/api/books/app-tool-portable/all",
    @http.Body::Json(Json::object({})),
    expect=@http.Json(fn(result) {
      dispatch(ExportedAllAppToolPortable(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not export all portable app-tool bundles")
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
fn create_agent_session_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
) -> @rabbita.Cmd {
  let mooncode_mode = model.workspace_mode == WorkspaceMode::MoonCode
  let body : Json = {
    "workspace_id": model.selected_workspace_id,
    "title": if mooncode_mode {
      "MoonCode - \{workspace_name(model)}"
    } else {
      "Agent - \{workspace_name(model)}"
    },
    "message": trimmed_or(
      model.agent_prompt,
      if mooncode_mode {
        "Create, inspect, test, or package executable code inside this MoonBook."
      } else {
        "Help me improve this workspace."
      },
    ),
    "model": model.agent_model,
    "web_search": model.agent_web_search,
    "context_path": model.selected_path,
  }
  let endpoint = if mooncode_mode {
    "/api/mooncode/sessions"
  } else {
    "/api/agents/sessions"
  }
  @http.post(
    endpoint,
    @http.Body::Json(body),
    expect=@http.Json(fn(result) { dispatch(CreatedAgentSession(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not create agent session")
      }
    }),
  )
}

///|
fn send_agent_message_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
  session : AgentSession,
) -> @rabbita.Cmd {
  @http.post(
    "/api/agents/sessions/\{session.id}/message",
    @http.Body::Json({
      "message": trimmed_or(
        model.agent_prompt,
        "Continue helping with this workspace.",
      ),
      "web_search": model.agent_web_search,
      "context_path": model.selected_path,
    }),
    expect=@http.Json(fn(result) { dispatch(SentAgentMessage(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not send agent message")
      }
    }),
  )
}

///|
fn send_mooncode_composer_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
  session : AgentSession,
) -> @rabbita.Cmd {
  let action = mooncode_composer_action(model, session)
  mooncode_session_command_cmd(
    dispatch,
    model,
    session,
    action,
    message=model.agent_prompt.trim().to_owned(),
  )
}

///|
fn mooncode_composer_action(
  model : Model,
  session : AgentSession
) -> String {
  if mooncode_session_accepts_steer(model, session) {
    "steer"
  } else {
    "prompt"
  }
}

///|
fn mooncode_session_accepts_steer(
  model : Model,
  session : AgentSession
) -> Bool {
  if session.status == "running" ||
    session.status == "queued" ||
    session.queued_count > 0 {
    return true
  }
  match model.mooncode_action_plan {
    Some(plan) if model.mooncode_action_plan_session_id == session.id =>
      plan.running_count > 0 || plan.pending_runtime_count > 0
    _ => false
  }
}

///|
fn cancel_agent_session_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  session : AgentSession,
) -> @rabbita.Cmd {
  @http.post(
    "/api/agents/sessions/\{session.id}/cancel",
    @http.Body::Json(Json::object({})),
    expect=@http.Json(fn(result) { dispatch(CancelledAgentSession(result)) }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not cancel agent session")
      }
    }),
  )
}

///|
fn mooncode_session_command_cmd(
  dispatch : (Msg) -> @rabbita.Cmd,
  model : Model,
  session : AgentSession,
  action : String,
  context_path? : String = "",
  message? : String = "",
  force_preflight? : Bool = false,
) -> @rabbita.Cmd {
  let target_path = if context_path == "" {
    model.selected_path
  } else {
    context_path
  }
  let selected_model = trimmed_or(model.agent_model, session.model)
  @http.post(
    "/api/mooncode/sessions/\{session.id}/commands",
    @http.Body::Json({
      "action": action,
      "message": message,
      "model": selected_model,
      "web_search": model.agent_web_search,
      "context_path": target_path,
      "force_preflight": force_preflight,
    }),
    expect=@http.Json(fn(result) {
      dispatch(CompletedMoonCodeCommand(result))
    }, json => {
      Ok(@json.from_json(json)) catch {
        _ => Err("Could not run MoonCode command")
      }
    }),
  )
}

///|
fn schedule_agent_poll(dispatch : (Msg) -> @rabbita.Cmd) -> @rabbita.Cmd {
  @rabbita.delay(dispatch(PollAgentSessions), 5000)
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
      fetch_agent_daemon_cmd(dispatch),
      fetch_agent_models_cmd(dispatch),
      fetch_agent_sessions_cmd(dispatch, workspace_id),
      fetch_mooncode_capabilities_cmd(dispatch),
      fetch_review_items_cmd(dispatch, workspace_id),
      fetch_review_diff_cmd(dispatch, workspace_id, selected_path),
      fetch_saved_views_cmd(dispatch),
      fetch_tags_cmd(dispatch),
      fetch_book_base_types_cmd(dispatch),
      fetch_book_patterns_cmd(dispatch),
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
    LoadedRuns(Ok(runs)) => (@rabbita.none, { ..model, runs, })
    LoadedRuns(Err(error)) => (@rabbita.none, { ..model, host_status: error })
    LoadedTownMessages(Ok(town_messages)) =>
      (@rabbita.none, { ..model, town_messages, })
    LoadedTownMessages(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedRequests(Ok(requests)) => (@rabbita.none, { ..model, requests, })
    LoadedRequests(Err(error)) =>
      (@rabbita.none, { ..model, request_status: error })
    LoadedStandingGoals(Ok(standing_goals)) =>
      (@rabbita.none, { ..model, standing_goals, })
    LoadedStandingGoals(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedAnalytics(Ok(analytics)) =>
      (@rabbita.none, { ..model, analytics: Some(analytics) })
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
    LoadedEvents(Ok(events)) => (@rabbita.none, { ..model, events, })
    LoadedEvents(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedReviewItems(Ok(review_items)) =>
      (@rabbita.none, { ..model, review_items, })
    LoadedReviewItems(Err(error)) =>
      (@rabbita.none, { ..model, reveal_status: error })
    LoadedReviewDiff(Ok(review_diff)) =>
      (@rabbita.none, { ..model, review_diff: Some(review_diff) })
    LoadedReviewDiff(Err(error)) =>
      (@rabbita.none, { ..model, reveal_status: error })
    LoadedSavedViews(Ok(saved_views)) =>
      (@rabbita.none, { ..model, saved_views, })
    LoadedSavedViews(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedTags(Ok(tags)) => (@rabbita.none, { ..model, tags, })
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
    LoadedBookBaseTypes(Ok(book_base_types)) =>
      (@rabbita.none, { ..model, book_base_types })
    LoadedBookBaseTypes(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    LoadedBookPatterns(Ok(book_patterns)) =>
      (@rabbita.none, { ..model, book_patterns })
    LoadedBookPatterns(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    SavedInbox(Ok(created)) =>
      (
        sync_activity_batch(
          Activity::Inbox,
          @rabbita.batch([
            fetch_entries_cmd(dispatch, created.workspace_id, "inbox"),
            fetch_preview_cmd(dispatch, created.workspace_id, created.path),
          ]),
        ),
        {
          ..model,
          activity: Activity::Inbox,
          command_open: false,
          current_directory: "inbox",
          selected_workspace_id: created.workspace_id,
          selected_path: created.path,
          primary_preview_path: created.path,
          editing_inbox_path: created.path,
          inbox_status: if created.ok {
            "saved \{created.path}"
          } else {
            "save returned without ok"
          },
          preview_status: "loading saved note",
        },
      )
    SavedInbox(Err(error)) => (@rabbita.none, { ..model, inbox_status: error })
    ImportedInbox(Ok(created)) =>
      (
        sync_activity_batch(
          Activity::Inbox,
          @rabbita.batch([
            fetch_entries_cmd(dispatch, created.workspace_id, "inbox/imports"),
            fetch_preview_cmd(dispatch, created.workspace_id, created.path),
          ]),
        ),
        {
          ..model,
          activity: Activity::Inbox,
          command_open: false,
          current_directory: "inbox/imports",
          selected_workspace_id: created.workspace_id,
          selected_path: created.path,
          primary_preview_path: created.path,
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
    SavedView(Err(error)) => (@rabbita.none, { ..model, host_status: error })
    SavedTag(Ok(tag)) =>
      (
        fetch_tags_cmd(dispatch),
        {
          ..model,
          tag_value: "",
          reveal_status: "tagged \{tag.path} as \{tag.tag}",
        },
      )
    SavedTag(Err(error)) => (@rabbita.none, { ..model, reveal_status: error })
    SubmittedRequest(Ok(record)) =>
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_requests_cmd(dispatch),
            fetch_messages_cmd(dispatch),
            fetch_analytics_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
          ]),
        ),
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
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_standing_goals_cmd(dispatch),
            fetch_analytics_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
          ]),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          dispatch_status: "created \{goal.id}",
        },
      )
    CreatedStandingGoal(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    CreatedPdfEvidenceWatchBook(Ok(result)) => {
      let goal_id = json_field_string(result.standing_goal, "id", default="watch")
      let output_summary = if selected_pattern_is_eb(model) {
        let output_status = json_path_string(
          result.readiness,
          ["contract_verification", "output_validation", "status"],
          default="output gate unknown",
        )
        let workbook_gate = json_path_bool_label(
          result.readiness,
          [
            "contract_verification", "output_validation", "template_workbook_validation_ready",
          ],
        )
        let expected_contract_gate = json_path_bool_label(
          result.readiness,
          [
            "contract_verification", "output_validation", "expected_output_contract_ready",
          ],
        )
        "; output gate \{output_status}; expected output contract \{expected_contract_gate}; workbook validation gate \{workbook_gate}"
      } else {
        "; reusable research-book pattern"
      }
      let publish_status = json_field_string(
        result.moontown_publish,
        "status",
        default="published",
      )
      let publish_config = json_field_string(
        result.moontown_publish,
        "config_relative_path",
        default="book-template-config",
      )
      let operator_config = json_field_string(
        result.moontown_publish,
        "operator_config_path",
        default="raw/inbox/pdf-evidence-watch-config.json",
      )
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_workspaces_cmd(dispatch),
            reload_workspace_cmds(dispatch, result.workspace_id, "wiki/index.md"),
            fetch_standing_goals_cmd(dispatch),
            fetch_analytics_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
          ]),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          selected_workspace_id: result.workspace_id,
          selected_path: "wiki/index.md",
          primary_preview_path: "wiki/index.md",
          current_directory: "",
          preview: None,
          preview_status: "loading published book",
          pdf_watch_last_book_id: result.book_id,
          eb_production_checklist: [],
          eb_production_proof_receipt_path: "",
          eb_production_proof_status: "not_run",
          eb_production_proof_level: "",
          eb_production_proof_run_id: "",
          eb_production_proof_failed_checks: [],
          eb_moonclaw_import_run_id: "",
          eb_moonclaw_import_status: "",
          eb_moonclaw_import_receipt_recovered: false,
          eb_moonclaw_import_recovery_source: "",
          eb_moonclaw_retry_recommended: false,
          eb_moonclaw_orphaned_after_timeout: false,
          eb_moonclaw_confirmed_run_status: "",
          eb_moonclaw_run_receipt_path: "",
          eb_moonclaw_retry_import_receipt_path: "",
          eb_moonclaw_retry_import_status: "",
          eb_moonclaw_result_path: "",
          eb_book_result_path: "",
          eb_output_path: "",
          eb_base_type_selection_path: "",
          eb_base_type_selection_ready: false,
          eb_base_type: "",
          eb_base_type_handoff_target: "",
          eb_moontown_publish_receipt_path: "",
          eb_moontown_publish_receipt_ready: false,
          eb_global_standing_goal_ready: false,
          eb_standing_goal_registration_ready: false,
          eb_expected_output_contract_path: "",
          eb_expected_output_contract_ready: false,
          eb_expected_output_contract_id: "",
          eb_workbook_validation_path: "",
          eb_source_screen_path: "",
          eb_output_validation_status: "",
          pdf_watch_status: "published \{result.book_id}; Moontown \{publish_status} via \{publish_config}; editable config \{operator_config}\{output_summary}; registered standing watch",
          dispatch_status: "created \{goal_id}",
        },
      )
    }
    CreatedPdfEvidenceWatchBook(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    ImportedMoonclawPacket(Ok(result)) => {
      let next = model_with_eb_health_json(model, result.run_health)
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_runs_cmd(dispatch, model.selected_workspace_id),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
          ]),
        ),
        {
          ..next,
          activity: Activity::Town,
          pdf_watch_status: moonclaw_import_status_summary(result),
        },
      )
    }
    ImportedMoonclawPacket(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    RanConfirmedMoonclawJob(Ok(result)) => {
      let next = model_with_eb_health_json(model, result.run_health)
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_runs_cmd(dispatch, model.selected_workspace_id),
            fetch_messages_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
            fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
          ]),
        ),
        {
          ..next,
          activity: Activity::Town,
          pdf_watch_status: moonclaw_run_status_summary(result),
        },
      )
    }
    RanConfirmedMoonclawJob(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    ReconciledMoonclawResult(Ok(result)) => {
      let next = model_with_eb_health_json(model, result.run_health)
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_runs_cmd(dispatch, model.selected_workspace_id),
            fetch_messages_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
            fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
          ]),
        ),
        {
          ..next,
          activity: Activity::Town,
          pdf_watch_status: moonclaw_reconcile_status_summary(result),
        },
      )
    }
    ReconciledMoonclawResult(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    AcceptedRecoveredEbOutput(Ok(result)) => {
      let next = model_with_eb_health_json(model, result.run_health)
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_runs_cmd(dispatch, model.selected_workspace_id),
            fetch_messages_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
            fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
          ]),
        ),
        {
          ..next,
          activity: Activity::Town,
          pdf_watch_status: eb_recovered_output_status_summary(result),
        },
      )
    }
    AcceptedRecoveredEbOutput(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    ProvedEbProduction(Ok(result)) => {
      let next = model_with_eb_health_json(model, result.run_health)
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_runs_cmd(dispatch, model.selected_workspace_id),
            fetch_messages_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
            fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
          ]),
        ),
        {
          ..next,
          activity: Activity::Town,
          pdf_watch_status: eb_production_proof_status_summary(result),
        },
      )
    }
    ProvedEbProduction(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    RanEbSampleValidation(Ok(result)) => {
      let next = model_with_eb_health_json(model, result.run_health)
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_runs_cmd(dispatch, model.selected_workspace_id),
            fetch_messages_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
          ]),
        ),
        {
          ..next,
          activity: Activity::Town,
          pdf_watch_status: "validated EB output \{result.output_path}; durable run \{json_field_string(result.run_health, "status", default="unknown")}; expected output contract \{json_field_bool_label(result.run_health, "expected_output_contract_ready")}; workbook validation \{json_field_bool_label(result.run_health, "workbook_validation_ready")}; workbook XML \{json_field_bool_label(result.run_health, "workbook_internal_contract_ready")}; data rows \{json_field_bool_label(result.run_health, "workbook_data_proof_ready")}; hyperlinks \{json_field_bool_label(result.run_health, "workbook_hyperlinks_ready")}; quality proof \{json_field_bool_label(result.run_health, "workbook_quality_proof_ready")}; lifecycle proof \{json_field_bool_label(result.run_health, "workbook_lifecycle_proof_ready")}; production \{json_field_bool_label(result.run_health, "production_ready")}; goal \{result.watcher_goal_id}",
        },
      )
    }
    RanEbSampleValidation(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    AuditedEbProductionHealth(Ok(result)) => {
      let next = model_with_eb_health_json(model, result)
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_runs_cmd(dispatch, model.selected_workspace_id),
            fetch_messages_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
            fetch_moonclaw_progress_cmd(dispatch, model.selected_workspace_id),
          ]),
        ),
        {
          ..next,
          activity: Activity::Town,
          pdf_watch_status: eb_run_health_json_status_summary(result),
        },
      )
    }
    AuditedEbProductionHealth(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    ExportedAppToolPortable(Ok(result)) => {
      let book_id = json_field_string(
        result,
        "book_id",
        default=selected_book_id_for_portable_export(model),
      )
      let workspace_id = if model.selected_workspace_id.has_prefix("book-") {
        model.selected_workspace_id
      } else {
        @desk.stable_id("book", book_id)
      }
      (
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_workspaces_cmd(dispatch),
            reload_workspace_cmds(
              dispatch,
              workspace_id,
              "portable/app-tool/index.html",
            ),
          ]),
        ),
        {
          ..model,
          activity: Activity::Town,
          selected_workspace_id: workspace_id,
          selected_path: "portable/app-tool/index.html",
          primary_preview_path: "portable/app-tool/index.html",
          preview: None,
          preview_status: "loading portable app-tool bundle",
          pdf_watch_status: app_tool_portable_status_summary(result),
        },
      )
    }
    ExportedAppToolPortable(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    ExportedAllAppToolPortable(Ok(result)) => {
      let book_ids = json_field_string_array_items(result, "book_ids")
      let has_book = book_ids.length() > 0
      let workspace_id = if has_book {
        @desk.stable_id("book", book_ids[0])
      } else {
        model.selected_workspace_id
      }
      let command = if has_book {
        @rabbita.batch([
          fetch_workspaces_cmd(dispatch),
          reload_workspace_cmds(
            dispatch,
            workspace_id,
            "portable/app-tool/index.html",
          ),
        ])
      } else {
        fetch_workspaces_cmd(dispatch)
      }
      (
        sync_activity_batch(Activity::Town, command),
        {
          ..model,
          activity: Activity::Town,
          selected_workspace_id: workspace_id,
          selected_path: if has_book {
            "portable/app-tool/index.html"
          } else {
            model.selected_path
          },
          primary_preview_path: if has_book {
            "portable/app-tool/index.html"
          } else {
            model.primary_preview_path
          },
          preview: if has_book { None } else { model.preview },
          preview_status: if has_book {
            "loading portable app-tool bundle"
          } else {
            model.preview_status
          },
          pdf_watch_status: app_tool_portable_all_status_summary(result),
        },
      )
    }
    ExportedAllAppToolPortable(Err(error)) =>
      (@rabbita.none, { ..model, pdf_watch_status: error })
    DispatchedDaemon(Ok(result)) =>
      (
        sync_activity_batch(
          Activity::Town,
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
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
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
        sync_activity_batch(
          Activity::Town,
          @rabbita.batch([
            fetch_analytics_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
            fetch_daemon_lifecycle_cmd(dispatch),
            fetch_daemon_agent_cmd(dispatch),
          ]),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
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
    LoadedAgentDaemon(Ok(status)) =>
      (
        @rabbita.none,
        {
          ..model,
          agent_daemon: Some(status),
          agent_status: if status.running {
            "MoonClaw daemon running on \{status.port}"
          } else {
            status.message
          },
        },
      )
    LoadedAgentDaemon(Err(error)) =>
      (@rabbita.none, { ..model, agent_status: error })
    LoadedAgentModels(Ok(result)) =>
      (
        @rabbita.none,
        {
          ..model,
          agent_daemon: Some(result.daemon),
          agent_models: result.models,
          agent_model: if model.agent_model == "" && result.models.length() > 0 {
            result.models[0].name
          } else {
            model.agent_model
          },
          agent_status: if result.ok {
            "\{result.models.length()} model(s) available"
          } else {
            result.daemon.message
          },
        },
      )
    LoadedAgentModels(Err(error)) =>
      (@rabbita.none, { ..model, agent_status: error })
    LoadedAgentSessions(Ok(agent_sessions)) => {
      let selected = if model.selected_agent_session_id != "" &&
        agent_session_exists(agent_sessions, model.selected_agent_session_id) {
        model.selected_agent_session_id
      } else {
        first_agent_session_id(agent_sessions, model.selected_workspace_id)
      }
      let stream_session_id = if selected == model.mooncode_stream_session_id {
        model.mooncode_stream_session_id
      } else {
        ""
      }
      let stream_cursor = if selected == model.mooncode_stream_session_id {
        model.mooncode_stream_cursor
      } else {
        0
      }
      let stream_events = if selected == model.mooncode_stream_session_id {
        model.mooncode_stream_events
      } else {
        []
      }
      let runtime_event_sink = if selected ==
        model.mooncode_runtime_event_sink_session_id {
        model.mooncode_runtime_event_sink
      } else {
        None
      }
      let stream_checkpoint_session_id = if selected ==
        model.mooncode_stream_checkpoint_session_id {
        model.mooncode_stream_checkpoint_session_id
      } else {
        ""
      }
      let change_set = if selected == model.mooncode_change_set_session_id {
        model.mooncode_change_set
      } else {
        None
      }
      let eval_report = if selected == model.mooncode_eval_report_session_id {
        model.mooncode_eval_report
      } else {
        None
      }
      let runtime_handoff = if selected ==
        model.mooncode_runtime_handoff_session_id {
        model.mooncode_runtime_handoff
      } else {
        None
      }
      let patch_set = if selected == model.mooncode_patch_set_session_id {
        model.mooncode_patch_set
      } else {
        None
      }
      let tool_approvals = if selected == model.mooncode_tool_approvals_session_id {
        model.mooncode_tool_approvals
      } else {
        None
      }
      let tool_authorization = if selected ==
        model.mooncode_tool_authorization_session_id {
        model.mooncode_tool_authorization
      } else {
        None
      }
      let test_runs = if selected == model.mooncode_test_runs_session_id {
        model.mooncode_test_runs
      } else {
        None
      }
      let package_candidates = if selected ==
        model.mooncode_package_candidates_session_id {
        model.mooncode_package_candidates
      } else {
        None
      }
      let action_plan = if selected == model.mooncode_action_plan_session_id {
        model.mooncode_action_plan
      } else {
        None
      }
      let runtime_evidence = if selected ==
        model.mooncode_runtime_evidence_session_id {
        model.mooncode_runtime_evidence
      } else {
        None
      }
      let command_queue = if selected == model.mooncode_command_queue_session_id {
        model.mooncode_command_queue
      } else {
        None
      }
      let runtime_command_feed = if selected ==
        model.mooncode_runtime_command_feed_session_id {
        model.mooncode_runtime_command_feed
      } else {
        None
      }
      let runtime_replay = if selected ==
        model.mooncode_runtime_replay_session_id {
        model.mooncode_runtime_replay
      } else {
        None
      }
      let runtime_dispatch = if selected ==
        model.mooncode_runtime_dispatch_session_id {
        model.mooncode_runtime_dispatch
      } else {
        None
      }
      let runtime_claim = if selected ==
        model.mooncode_runtime_claim_session_id {
        model.mooncode_runtime_claim
      } else {
        None
      }
      (
        if selected == "" {
          @rabbita.none
        } else {
          @rabbita.batch([
            fetch_mooncode_runtime_event_sink_cmd(dispatch, selected),
            fetch_mooncode_change_set_cmd(dispatch, selected),
            fetch_mooncode_eval_report_cmd(dispatch, selected),
            fetch_mooncode_runtime_handoff_cmd(dispatch, selected),
            fetch_mooncode_patch_set_cmd(dispatch, selected),
            fetch_mooncode_tool_approvals_cmd(dispatch, selected),
            fetch_mooncode_test_runs_cmd(dispatch, selected),
            fetch_mooncode_package_candidates_cmd(dispatch, selected),
            fetch_mooncode_action_plan_cmd(dispatch, selected),
            fetch_mooncode_runtime_evidence_cmd(dispatch, selected),
            fetch_mooncode_command_queue_cmd(dispatch, selected),
            fetch_mooncode_runtime_command_feed_cmd(dispatch, selected),
            fetch_mooncode_runtime_replay_cmd(dispatch, selected),
            fetch_mooncode_preflight_matrix_cmd(
              dispatch, selected, model.selected_path,
            ),
            fetch_mooncode_runtime_dispatch_cmd(dispatch, selected),
            fetch_mooncode_runtime_claim_state_cmd(dispatch, selected),
          ])
        },
        {
          ..model,
          agent_sessions,
          selected_agent_session_id: selected,
          mooncode_stream_session_id: stream_session_id,
          mooncode_stream_cursor: stream_cursor,
          mooncode_stream_events: stream_events,
          mooncode_stream_status: if selected == "" {
            "stream idle"
          } else if selected == model.mooncode_stream_session_id {
            model.mooncode_stream_status
          } else {
            "stream cursor reset"
          },
          mooncode_stream_checkpoint_session_id: stream_checkpoint_session_id,
          mooncode_stream_checkpoint_status: if selected == "" {
            "checkpoint idle"
          } else if selected == model.mooncode_stream_checkpoint_session_id {
            model.mooncode_stream_checkpoint_status
          } else {
            "checkpoint idle"
          },
          mooncode_runtime_event_sink_session_id: if selected ==
            model.mooncode_runtime_event_sink_session_id {
            model.mooncode_runtime_event_sink_session_id
          } else {
            ""
          },
          mooncode_runtime_event_sink: runtime_event_sink,
          mooncode_runtime_event_sink_status: if selected == "" {
            "runtime events idle"
          } else if selected == model.mooncode_runtime_event_sink_session_id {
            model.mooncode_runtime_event_sink_status
          } else {
            "loading runtime events"
          },
          mooncode_change_set_session_id: if selected == model.mooncode_change_set_session_id {
            model.mooncode_change_set_session_id
          } else {
            ""
          },
          mooncode_change_set: change_set,
          mooncode_change_set_status: if selected == "" {
            "change set idle"
          } else if selected == model.mooncode_change_set_session_id {
            model.mooncode_change_set_status
          } else {
            "loading change set"
          },
          mooncode_eval_report_session_id: if selected ==
            model.mooncode_eval_report_session_id {
            model.mooncode_eval_report_session_id
          } else {
            ""
          },
          mooncode_eval_report: eval_report,
          mooncode_eval_report_status: if selected == "" {
            "eval report idle"
          } else if selected == model.mooncode_eval_report_session_id {
            model.mooncode_eval_report_status
          } else {
            "loading eval report"
          },
          mooncode_runtime_handoff_session_id: if selected ==
            model.mooncode_runtime_handoff_session_id {
            model.mooncode_runtime_handoff_session_id
          } else {
            ""
          },
          mooncode_runtime_handoff: runtime_handoff,
          mooncode_runtime_handoff_status: if selected == "" {
            "runtime handoff idle"
          } else if selected == model.mooncode_runtime_handoff_session_id {
            model.mooncode_runtime_handoff_status
          } else {
            "loading runtime handoff"
          },
          mooncode_patch_set_session_id: if selected == model.mooncode_patch_set_session_id {
            model.mooncode_patch_set_session_id
          } else {
            ""
          },
          mooncode_patch_set: patch_set,
          mooncode_patch_set_status: if selected == "" {
            "patch set idle"
          } else if selected == model.mooncode_patch_set_session_id {
            model.mooncode_patch_set_status
          } else {
            "loading patch set"
          },
          mooncode_tool_approvals_session_id: if selected ==
            model.mooncode_tool_approvals_session_id {
            model.mooncode_tool_approvals_session_id
          } else {
            ""
          },
          mooncode_tool_approvals: tool_approvals,
          mooncode_tool_approvals_status: if selected == "" {
            "tool approvals idle"
          } else if selected == model.mooncode_tool_approvals_session_id {
            model.mooncode_tool_approvals_status
          } else {
            "loading tool approvals"
          },
          mooncode_tool_authorization_session_id: if selected ==
            model.mooncode_tool_authorization_session_id {
            model.mooncode_tool_authorization_session_id
          } else {
            ""
          },
          mooncode_tool_authorization: tool_authorization,
          mooncode_tool_authorization_status: if selected == "" {
            "tool authorization idle"
          } else if selected == model.mooncode_tool_authorization_session_id {
            model.mooncode_tool_authorization_status
          } else {
            "tool authorization idle"
          },
          mooncode_test_runs_session_id: if selected ==
            model.mooncode_test_runs_session_id {
            model.mooncode_test_runs_session_id
          } else {
            ""
          },
          mooncode_test_runs: test_runs,
          mooncode_test_runs_status: if selected == "" {
            "test runs idle"
          } else if selected == model.mooncode_test_runs_session_id {
            model.mooncode_test_runs_status
          } else {
            "loading test runs"
          },
          mooncode_package_candidates_session_id: if selected ==
            model.mooncode_package_candidates_session_id {
            model.mooncode_package_candidates_session_id
          } else {
            ""
          },
          mooncode_package_candidates: package_candidates,
          mooncode_package_candidates_status: if selected == "" {
            "package candidates idle"
          } else if selected == model.mooncode_package_candidates_session_id {
            model.mooncode_package_candidates_status
          } else {
            "loading package candidates"
          },
          mooncode_action_plan_session_id: if selected ==
            model.mooncode_action_plan_session_id {
            model.mooncode_action_plan_session_id
          } else {
            ""
          },
          mooncode_action_plan: action_plan,
          mooncode_action_plan_status: if selected == "" {
            "action plan idle"
          } else if selected == model.mooncode_action_plan_session_id {
            model.mooncode_action_plan_status
          } else {
            "loading action plan"
          },
          mooncode_runtime_evidence_session_id: if selected ==
            model.mooncode_runtime_evidence_session_id {
            model.mooncode_runtime_evidence_session_id
          } else {
            ""
          },
          mooncode_runtime_evidence: runtime_evidence,
          mooncode_runtime_evidence_status: if selected == "" {
            "runtime evidence idle"
          } else if selected == model.mooncode_runtime_evidence_session_id {
            model.mooncode_runtime_evidence_status
          } else {
            "loading runtime evidence"
          },
          mooncode_command_queue_session_id: if selected ==
            model.mooncode_command_queue_session_id {
            model.mooncode_command_queue_session_id
          } else {
            ""
          },
          mooncode_command_queue: command_queue,
          mooncode_command_queue_status: if selected == "" {
            "command queue idle"
          } else if selected == model.mooncode_command_queue_session_id {
            model.mooncode_command_queue_status
          } else {
            "loading command queue"
          },
          mooncode_runtime_command_feed_session_id: if selected ==
            model.mooncode_runtime_command_feed_session_id {
            model.mooncode_runtime_command_feed_session_id
          } else {
            ""
          },
          mooncode_runtime_command_feed: runtime_command_feed,
          mooncode_runtime_command_feed_status: if selected == "" {
            "runtime feed idle"
          } else if selected == model.mooncode_runtime_command_feed_session_id {
            model.mooncode_runtime_command_feed_status
          } else {
            "loading runtime feed"
          },
          mooncode_runtime_replay_session_id: if selected ==
            model.mooncode_runtime_replay_session_id {
            model.mooncode_runtime_replay_session_id
          } else {
            ""
          },
          mooncode_runtime_replay: runtime_replay,
          mooncode_runtime_replay_status: if selected == "" {
            "runtime replay idle"
          } else if selected == model.mooncode_runtime_replay_session_id {
            model.mooncode_runtime_replay_status
          } else {
            "loading runtime replay"
          },
          mooncode_preflight_session_id: if selected ==
            model.mooncode_preflight_session_id {
            model.mooncode_preflight_session_id
          } else {
            ""
          },
          mooncode_preflights: if selected == model.mooncode_preflight_session_id {
            model.mooncode_preflights
          } else {
            []
          },
          mooncode_preflight_status: if selected == "" {
            "preflight idle"
          } else if selected == model.mooncode_preflight_session_id {
            model.mooncode_preflight_status
          } else {
            "loading preflight gates"
          },
          mooncode_runtime_dispatch_session_id: if selected ==
            model.mooncode_runtime_dispatch_session_id {
            model.mooncode_runtime_dispatch_session_id
          } else {
            ""
          },
          mooncode_runtime_dispatch: runtime_dispatch,
          mooncode_runtime_dispatch_status: if selected == "" {
            "runtime dispatch idle"
          } else if selected == model.mooncode_runtime_dispatch_session_id {
            model.mooncode_runtime_dispatch_status
          } else {
            "loading runtime dispatch"
          },
          mooncode_runtime_claim_session_id: if selected ==
            model.mooncode_runtime_claim_session_id {
            model.mooncode_runtime_claim_session_id
          } else {
            ""
          },
          mooncode_runtime_claim: runtime_claim,
          mooncode_runtime_claim_status: if selected == "" {
            "runtime claim idle"
          } else if selected == model.mooncode_runtime_claim_session_id {
            model.mooncode_runtime_claim_status
          } else {
            "loading runtime claim"
          },
          agent_status: "\{agent_sessions.length()} agent session(s)",
        },
      )
    }
    LoadedAgentSessions(Err(error)) =>
      (@rabbita.none, { ..model, agent_status: error })
    LoadedMoonCodeCapabilities(Ok(capabilities)) =>
      (
        @rabbita.none,
        {
          ..model,
          mooncode_capabilities: Some(capabilities),
          mooncode_status: "MoonCode \{capabilities.component}.v\{capabilities.version} contract loaded",
        },
      )
    LoadedMoonCodeCapabilities(Err(error)) =>
      (@rabbita.none, { ..model, mooncode_status: error })
    LoadedMoonCodeStream(session_id, Ok(stream)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        let stream_events = if session_id == model.mooncode_stream_session_id {
          mooncode_merge_stream_events(model.mooncode_stream_events, stream.events)
        } else {
          mooncode_merge_stream_events([], stream.events)
        }
        (
          save_mooncode_stream_checkpoint_cmd(
            dispatch, session_id, stream.next_since,
          ),
          {
            ..model,
            mooncode_stream_session_id: session_id,
            mooncode_stream_cursor: stream.next_since,
            mooncode_stream_events: stream_events,
            mooncode_stream_status: "live tail / \{stream.stream_source} / \{stream.stream} +\{stream.emitted_count} event(s), cursor \{stream.next_since}",
            mooncode_stream_checkpoint_session_id: session_id,
            mooncode_stream_checkpoint_status: if stream.next_since > 0 {
              "saving checkpoint \{stream.next_since}"
            } else {
              "checkpoint idle"
            },
          },
        )
      }
    LoadedMoonCodeStream(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_stream_session_id: session_id,
            mooncode_stream_status: error,
          },
        )
      }
    SavedMoonCodeStreamCheckpoint(session_id, Ok(state)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_stream_checkpoint_session_id: session_id,
            mooncode_stream_checkpoint_status: "\{state.consumer_id} checkpoint \{state.next_since} / latest \{state.latest_sequence}",
          },
        )
      }
    SavedMoonCodeStreamCheckpoint(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_stream_checkpoint_session_id: session_id,
            mooncode_stream_checkpoint_status: "checkpoint failed: \{error}",
          },
        )
      }
    LoadedMoonCodeRuntimeEventSink(session_id, Ok(sink)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        let service_status = if sink.runtime_service.status == "idle" {
          ""
        } else {
          " / service " + sink.runtime_service.status
        }
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_event_sink_session_id: session_id,
            mooncode_runtime_event_sink: Some(sink),
            mooncode_runtime_event_sink_status: "\{sink.event_count} runtime event(s)\{service_status}",
          },
        )
      }
    LoadedMoonCodeRuntimeEventSink(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_event_sink_session_id: session_id,
            mooncode_runtime_event_sink: None,
            mooncode_runtime_event_sink_status: error,
          },
        )
      }
    LoadedMoonCodeChangeSet(session_id, Ok(change_set)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_change_set_session_id: session_id,
            mooncode_change_set: Some(change_set),
            mooncode_change_set_status: "\{change_set.status} / \{change_set.diff_count} diff(s), \{change_set.test_count} test(s)",
          },
        )
      }
    LoadedMoonCodeChangeSet(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_change_set_session_id: session_id,
            mooncode_change_set: None,
            mooncode_change_set_status: error,
          },
        )
      }
    LoadedMoonCodeEvalReport(session_id, Ok(report)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_eval_report_session_id: session_id,
            mooncode_eval_report: Some(report),
            mooncode_eval_report_status: "\{report.status} / \{report.passed_check_count} passed, \{report.missing_check_count} missing",
          },
        )
      }
    LoadedMoonCodeEvalReport(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_eval_report_session_id: session_id,
            mooncode_eval_report: None,
            mooncode_eval_report_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeHandoff(session_id, Ok(handoff)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_handoff_session_id: session_id,
            mooncode_runtime_handoff: Some(handoff),
            mooncode_runtime_handoff_status: "\{handoff.status} / \{handoff.command_count} command(s)",
          },
        )
      }
    LoadedMoonCodeRuntimeHandoff(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_handoff_session_id: session_id,
            mooncode_runtime_handoff: None,
            mooncode_runtime_handoff_status: error,
          },
        )
      }
    LoadedMoonCodePatchSet(session_id, Ok(patch_set)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_patch_set_session_id: session_id,
            mooncode_patch_set: Some(patch_set),
            mooncode_patch_set_status: "\{patch_set.status} / \{patch_set.patch_count} patch(es)",
          },
        )
      }
    LoadedMoonCodePatchSet(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_patch_set_session_id: session_id,
            mooncode_patch_set: None,
            mooncode_patch_set_status: error,
          },
        )
      }
    LoadedMoonCodeToolApprovals(session_id, Ok(approvals)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_tool_approvals_session_id: session_id,
            mooncode_tool_approvals: Some(approvals),
            mooncode_tool_approvals_status: "\{approvals.status} / \{approvals.pending_approval_count} pending",
          },
        )
      }
    LoadedMoonCodeToolApprovals(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_tool_approvals_session_id: session_id,
            mooncode_tool_approvals: None,
            mooncode_tool_approvals_status: error,
          },
        )
      }
    LoadedMoonCodeToolAuthorization(session_id, tool_id, Ok(authorization)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          sync_activity_batch(
            Activity::Agents,
            @rabbita.batch([
              fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
              fetch_mooncode_tool_approvals_cmd(dispatch, session_id),
              fetch_mooncode_action_plan_cmd(dispatch, session_id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
              fetch_mooncode_preflight_matrix_cmd(
                dispatch, session_id, model.selected_path,
              ),
            ]),
          ),
          {
            ..model,
            mooncode_tool_authorization_session_id: session_id,
            mooncode_tool_authorization: Some(authorization),
            mooncode_tool_authorization_status: "\{tool_id}: \{authorization.decision}",
          },
        )
      }
    LoadedMoonCodeToolAuthorization(session_id, tool_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_tool_authorization_session_id: session_id,
            mooncode_tool_authorization: None,
            mooncode_tool_authorization_status: "\{tool_id}: \{error}",
          },
        )
      }
    LoadedMoonCodeTestRuns(session_id, Ok(test_runs)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_test_runs_session_id: session_id,
            mooncode_test_runs: Some(test_runs),
            mooncode_test_runs_status: "\{test_runs.status} / \{test_runs.passed_run_count} passed, \{test_runs.failed_run_count} failed",
          },
        )
      }
    LoadedMoonCodeTestRuns(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_test_runs_session_id: session_id,
            mooncode_test_runs: None,
            mooncode_test_runs_status: error,
          },
        )
      }
    LoadedMoonCodePackageCandidates(session_id, Ok(candidates)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_package_candidates_session_id: session_id,
            mooncode_package_candidates: Some(candidates),
            mooncode_package_candidates_status: "\{candidates.status} / \{candidates.source_bound_package_count} source-bound, \{candidates.missing_source_package_count} missing-source",
          },
        )
      }
    LoadedMoonCodePackageCandidates(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_package_candidates_session_id: session_id,
            mooncode_package_candidates: None,
            mooncode_package_candidates_status: error,
          },
        )
      }
    LoadedMoonCodeActionPlan(session_id, Ok(plan)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_action_plan_session_id: session_id,
            mooncode_action_plan: Some(plan),
            mooncode_action_plan_status: "\{plan.status} / \{plan.next_required_action}",
          },
        )
      }
    LoadedMoonCodeActionPlan(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_action_plan_session_id: session_id,
            mooncode_action_plan: None,
            mooncode_action_plan_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeEvidence(session_id, Ok(evidence)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_evidence_session_id: session_id,
            mooncode_runtime_evidence: Some(evidence),
            mooncode_runtime_evidence_status: "\{evidence.status} / \{evidence.proven_command_count}/\{evidence.command_count} command(s) proven",
          },
        )
      }
    LoadedMoonCodeRuntimeEvidence(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_evidence_session_id: session_id,
            mooncode_runtime_evidence: None,
            mooncode_runtime_evidence_status: error,
          },
        )
      }
    LoadedMoonCodeCommandQueue(session_id, Ok(queue)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_command_queue_session_id: session_id,
            mooncode_command_queue: Some(queue),
            mooncode_command_queue_status: "\{queue.command_count} command(s)",
          },
        )
      }
    LoadedMoonCodeCommandQueue(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_command_queue_session_id: session_id,
            mooncode_command_queue: None,
            mooncode_command_queue_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeCommandFeed(session_id, Ok(feed)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_command_feed_session_id: session_id,
            mooncode_runtime_command_feed: Some(feed),
            mooncode_runtime_command_feed_status: "\{feed.runtime_command_count} runtime command(s), \{feed.runtime_dispatch_pending_count} pending dispatch",
          },
        )
      }
    LoadedMoonCodeRuntimeCommandFeed(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_command_feed_session_id: session_id,
            mooncode_runtime_command_feed: None,
            mooncode_runtime_command_feed_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeReplay(session_id, Ok(replay)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_replay_session_id: session_id,
            mooncode_runtime_replay: Some(replay),
            mooncode_runtime_replay_status: "\{replay.pending_command_count} pending, \{replay.delivered_command_count} delivered",
          },
        )
      }
    LoadedMoonCodeRuntimeReplay(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_replay_session_id: session_id,
            mooncode_runtime_replay: None,
            mooncode_runtime_replay_status: error,
          },
        )
      }
    LoadedMoonCodeCommandPreflight(session_id, _action, Ok(preflight)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        let preflights = mooncode_replace_command_preflight(
          model.mooncode_preflights, preflight,
        )
        (
          @rabbita.none,
          {
            ..model,
            mooncode_preflight_session_id: session_id,
            mooncode_preflights: preflights,
            mooncode_preflight_status: mooncode_preflight_status(preflights),
          },
        )
      }
    LoadedMoonCodeCommandPreflight(session_id, action, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_preflight_session_id: session_id,
            mooncode_preflight_status: "\{action}: \{error}",
          },
        )
      }
    LoadedMoonCodeRuntimeDispatch(session_id, Ok(state)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_dispatch_session_id: session_id,
            mooncode_runtime_dispatch: Some(state),
            mooncode_runtime_dispatch_status: "\{state.runtime_dispatch_count} receipt(s), \{state.runtime_dispatch_pending_count} pending",
          },
        )
      }
    LoadedMoonCodeRuntimeDispatch(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_dispatch_session_id: session_id,
            mooncode_runtime_dispatch: None,
            mooncode_runtime_dispatch_status: error,
          },
        )
      }
    LoadedMoonCodeRuntimeClaimState(session_id, Ok(state)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim: Some(state),
            mooncode_runtime_claim_status: "\{state.claimable_command_count} claimable, \{state.claimed_command_count} claimed, \{state.tool_authorization_blocked_command_count} auth blocked",
          },
        )
      }
    LoadedMoonCodeRuntimeClaimState(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim: None,
            mooncode_runtime_claim_status: error,
          },
        )
      }
    ClaimedMoonCodeRuntime(session_id, force, Ok(response)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        let claimed_count = json_field_int(response, "claimed_count", default=0)
        (
          sync_activity_batch(
            Activity::Agents,
            @rabbita.batch([
              fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
              fetch_mooncode_runtime_claim_state_cmd(dispatch, session_id),
              fetch_mooncode_runtime_replay_cmd(dispatch, session_id),
              fetch_mooncode_runtime_dispatch_cmd(dispatch, session_id),
              fetch_mooncode_runtime_command_feed_cmd(dispatch, session_id),
              fetch_mooncode_action_plan_cmd(dispatch, session_id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
              fetch_mooncode_runtime_handoff_cmd(dispatch, session_id),
            ]),
          ),
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: if force {
              "force-claimed \{claimed_count} command(s)"
            } else {
              "claimed \{claimed_count} command(s)"
            },
            agent_status: if claimed_count == 0 {
              "no claimable MoonCode runtime command"
            } else if force {
              "force-claimed MoonCode runtime command"
            } else {
              "claimed MoonCode runtime command"
            },
          },
        )
      }
    ClaimedMoonCodeRuntime(session_id, force, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: if force {
              "force claim failed: \{error}"
            } else {
              "claim failed: \{error}"
            },
            agent_status: error,
          },
        )
      }
    AckedMoonCodeRuntimeCommand(session_id, _command_id, status, Ok(response)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        let accepted_count = json_field_int(
          response, "accepted_receipt_count", default=0,
        )
        (
          sync_activity_batch(
            Activity::Agents,
            @rabbita.batch([
              fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
              fetch_mooncode_runtime_claim_state_cmd(dispatch, session_id),
              fetch_mooncode_runtime_replay_cmd(dispatch, session_id),
              fetch_mooncode_runtime_dispatch_cmd(dispatch, session_id),
              fetch_mooncode_runtime_command_feed_cmd(dispatch, session_id),
              fetch_mooncode_runtime_event_sink_cmd(dispatch, session_id),
              fetch_mooncode_action_plan_cmd(dispatch, session_id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
              fetch_mooncode_runtime_handoff_cmd(dispatch, session_id),
            ]),
          ),
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: "runtime \{status}: \{accepted_count} receipt(s)",
            agent_status: if accepted_count == 0 {
              "MoonCode runtime acknowledgement recorded no receipts"
            } else {
              "MoonCode runtime \{status} recorded"
            },
          },
        )
      }
    AckedMoonCodeRuntimeCommand(session_id, _command_id, status, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: "runtime \{status} failed: \{error}",
            agent_status: error,
          },
        )
      }
    CreatedAgentSession(Ok(session)) =>
      (
        sync_activity_batch(
          Activity::Agents,
          @rabbita.batch([
            fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
            fetch_agent_daemon_cmd(dispatch),
            fetch_agent_models_cmd(dispatch),
            fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
            fetch_mooncode_eval_report_cmd(dispatch, session.id),
            fetch_mooncode_runtime_handoff_cmd(dispatch, session.id),
            fetch_mooncode_command_queue_cmd(dispatch, session.id),
            fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
            fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
            fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
            fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
            fetch_mooncode_package_candidates_cmd(dispatch, session.id),
            fetch_mooncode_action_plan_cmd(dispatch, session.id),
            fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
            fetch_mooncode_preflight_matrix_cmd(
              dispatch, session.id, model.selected_path,
            ),
            schedule_agent_poll(dispatch),
          ]),
        ),
        {
          ..model,
          workspace_mode: WorkspaceMode::MoonCode,
          activity: Activity::Agents,
          command_open: false,
          selected_agent_session_id: session.id,
          agent_prompt: "",
          agent_status: "created \{session.title}",
        },
      )
    CreatedAgentSession(Err(error)) =>
      (
        sync_activity_cmd(Activity::Agents),
        {
          ..model,
          workspace_mode: WorkspaceMode::MoonCode,
          activity: Activity::Agents,
          command_open: false,
          agent_status: error,
        },
      )
    SentAgentMessage(Ok(session)) =>
      (
        sync_activity_batch(
          Activity::Agents,
          @rabbita.batch([
            fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
            fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
            fetch_mooncode_change_set_cmd(dispatch, session.id),
            fetch_mooncode_eval_report_cmd(dispatch, session.id),
            fetch_mooncode_runtime_handoff_cmd(dispatch, session.id),
            fetch_mooncode_patch_set_cmd(dispatch, session.id),
            fetch_mooncode_tool_approvals_cmd(dispatch, session.id),
            fetch_mooncode_test_runs_cmd(dispatch, session.id),
            fetch_mooncode_package_candidates_cmd(dispatch, session.id),
            fetch_mooncode_action_plan_cmd(dispatch, session.id),
            fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
            fetch_mooncode_command_queue_cmd(dispatch, session.id),
            fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
            fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
            fetch_mooncode_preflight_matrix_cmd(
              dispatch, session.id, model.selected_path,
            ),
            fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
            fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
            schedule_agent_poll(dispatch),
          ]),
        ),
        {
          ..model,
          workspace_mode: WorkspaceMode::MoonCode,
          activity: Activity::Agents,
          command_open: false,
          selected_agent_session_id: session.id,
          agent_prompt: "",
          agent_status: "\{session.status} / \{session.queued_count} queued",
        },
      )
    SentAgentMessage(Err(error)) =>
      (
        sync_activity_cmd(Activity::Agents),
        {
          ..model,
          workspace_mode: WorkspaceMode::MoonCode,
          activity: Activity::Agents,
          command_open: false,
          agent_status: error,
        },
      )
    CancelledAgentSession(Ok(session)) =>
      (
        sync_activity_batch(
          Activity::Agents,
          @rabbita.batch([
            fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
            fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
            fetch_mooncode_command_queue_cmd(dispatch, session.id),
            fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
            fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
            fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
            fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
            fetch_mooncode_action_plan_cmd(dispatch, session.id),
            fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
            fetch_mooncode_preflight_matrix_cmd(
              dispatch, session.id, model.selected_path,
            ),
          ]),
        ),
        {
          ..model,
          workspace_mode: WorkspaceMode::MoonCode,
          activity: Activity::Agents,
          command_open: false,
          selected_agent_session_id: session.id,
          agent_status: "cancel requested",
        },
      )
    CancelledAgentSession(Err(error)) =>
      (
        sync_activity_cmd(Activity::Agents),
        {
          ..model,
          workspace_mode: WorkspaceMode::MoonCode,
          activity: Activity::Agents,
          command_open: false,
          agent_status: error,
        },
      )
    CompletedMoonCodeCommand(Ok(session)) =>
      (
        sync_activity_batch(
          Activity::Agents,
          @rabbita.batch([
            fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
            fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
            fetch_mooncode_change_set_cmd(dispatch, session.id),
            fetch_mooncode_eval_report_cmd(dispatch, session.id),
            fetch_mooncode_runtime_handoff_cmd(dispatch, session.id),
            fetch_mooncode_patch_set_cmd(dispatch, session.id),
            fetch_mooncode_tool_approvals_cmd(dispatch, session.id),
            fetch_mooncode_test_runs_cmd(dispatch, session.id),
            fetch_mooncode_package_candidates_cmd(dispatch, session.id),
            fetch_mooncode_action_plan_cmd(dispatch, session.id),
            fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
            fetch_mooncode_command_queue_cmd(dispatch, session.id),
            fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
            fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
            fetch_mooncode_preflight_matrix_cmd(
              dispatch, session.id, model.selected_path,
            ),
            fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
            fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
            schedule_agent_poll(dispatch),
          ]),
        ),
        {
          ..model,
          workspace_mode: WorkspaceMode::MoonCode,
          activity: Activity::Agents,
          command_open: false,
          selected_agent_session_id: session.id,
          agent_status: "MoonCode command queued",
        },
      )
    CompletedMoonCodeCommand(Err(error)) =>
      match selected_agent_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              Activity::Agents,
              @rabbita.batch([
                fetch_mooncode_stream_cmd(
                  dispatch,
                  session.id,
                  if model.mooncode_stream_session_id == session.id {
                    model.mooncode_stream_cursor
                  } else {
                    0
                  },
                ),
                fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
                fetch_mooncode_action_plan_cmd(dispatch, session.id),
                fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
                fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
                fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
                fetch_mooncode_command_queue_cmd(dispatch, session.id),
                fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
                fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
                fetch_mooncode_preflight_matrix_cmd(
                  dispatch, session.id, model.selected_path,
                ),
              ]),
            ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: error,
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: error,
            },
          )
      }
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
          sync_activity_batch(Activity::Inbox, @rabbita.batch(cmds)),
          {
            ..model,
            activity: Activity::Inbox,
            command_open: false,
            inbox_status: "importing \{files.length()} local file(s)",
          },
        )
      }
    LocalFilesPicked(Err(error)) =>
      (
        @rabbita.none,
        { ..model, inbox_status: "local import failed: \{error}" },
      )
    SelectWorkspaceMode(mode) => {
      let activity = if mode == WorkspaceMode::MoonCode {
        Activity::Agents
      } else if model.activity == Activity::Agents {
        Activity::Explorer
      } else {
        model.activity
      }
      let prompt = if mode == WorkspaceMode::MoonCode &&
        model.agent_prompt.trim().to_owned() == "" {
        "Help me improve \{workspace_name(model)} by adding or changing executable code for the selected MoonBook."
      } else {
        model.agent_prompt
      }
      (
        sync_activity_cmd(activity),
        {
          ..model,
          workspace_mode: mode,
          activity,
          command_open: false,
          agent_prompt: prompt,
          agent_status: if mode == WorkspaceMode::MoonCode {
            "MoonCode workspace ready"
          } else {
            model.agent_status
          },
        },
      )
    }
    SelectActivity(activity) =>
      (
        sync_activity_cmd(activity),
        {
          ..model,
          workspace_mode: workspace_mode_for_activity(activity),
          activity,
          command_open: false,
        },
      )
    SelectDrawerTab(tab) => (@rabbita.none, { ..model, drawer_tab: tab })
    SelectAgentSession(session_id) =>
      (
        @rabbita.batch([
          fetch_mooncode_stream_cmd(dispatch, session_id, 0),
          fetch_mooncode_runtime_event_sink_cmd(dispatch, session_id),
          fetch_mooncode_change_set_cmd(dispatch, session_id),
          fetch_mooncode_eval_report_cmd(dispatch, session_id),
          fetch_mooncode_runtime_handoff_cmd(dispatch, session_id),
          fetch_mooncode_patch_set_cmd(dispatch, session_id),
          fetch_mooncode_tool_approvals_cmd(dispatch, session_id),
          fetch_mooncode_test_runs_cmd(dispatch, session_id),
          fetch_mooncode_package_candidates_cmd(dispatch, session_id),
          fetch_mooncode_action_plan_cmd(dispatch, session_id),
          fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
          fetch_mooncode_command_queue_cmd(dispatch, session_id),
          fetch_mooncode_runtime_command_feed_cmd(dispatch, session_id),
          fetch_mooncode_runtime_replay_cmd(dispatch, session_id),
          fetch_mooncode_preflight_matrix_cmd(
            dispatch, session_id, model.selected_path,
          ),
          fetch_mooncode_runtime_dispatch_cmd(dispatch, session_id),
          fetch_mooncode_runtime_claim_state_cmd(dispatch, session_id),
        ]),
        {
          ..model,
          selected_agent_session_id: session_id,
          mooncode_stream_session_id: "",
          mooncode_stream_cursor: 0,
          mooncode_stream_events: [],
          mooncode_stream_status: "stream cursor reset",
          mooncode_stream_checkpoint_session_id: "",
          mooncode_stream_checkpoint_status: "checkpoint idle",
          mooncode_runtime_event_sink_session_id: "",
          mooncode_runtime_event_sink_status: "loading runtime events",
          mooncode_runtime_event_sink: None,
          mooncode_change_set_session_id: "",
          mooncode_change_set_status: "loading change set",
          mooncode_change_set: None,
          mooncode_eval_report_session_id: "",
          mooncode_eval_report_status: "loading eval report",
          mooncode_eval_report: None,
          mooncode_runtime_handoff_session_id: "",
          mooncode_runtime_handoff_status: "loading runtime handoff",
          mooncode_runtime_handoff: None,
          mooncode_patch_set_session_id: "",
          mooncode_patch_set_status: "loading patch set",
          mooncode_patch_set: None,
          mooncode_tool_approvals_session_id: "",
          mooncode_tool_approvals_status: "loading tool approvals",
          mooncode_tool_approvals: None,
          mooncode_tool_authorization_session_id: "",
          mooncode_tool_authorization_status: "tool authorization idle",
          mooncode_tool_authorization: None,
          mooncode_test_runs_session_id: "",
          mooncode_test_runs_status: "loading test runs",
          mooncode_test_runs: None,
          mooncode_package_candidates_session_id: "",
          mooncode_package_candidates_status: "loading package candidates",
          mooncode_package_candidates: None,
          mooncode_action_plan_session_id: "",
          mooncode_action_plan_status: "loading action plan",
          mooncode_action_plan: None,
          mooncode_runtime_evidence_session_id: "",
          mooncode_runtime_evidence_status: "loading runtime evidence",
          mooncode_runtime_evidence: None,
          mooncode_command_queue_session_id: "",
          mooncode_command_queue_status: "loading command queue",
          mooncode_command_queue: None,
          mooncode_runtime_command_feed_session_id: "",
          mooncode_runtime_command_feed_status: "loading runtime feed",
          mooncode_runtime_command_feed: None,
          mooncode_runtime_replay_session_id: "",
          mooncode_runtime_replay_status: "loading runtime replay",
          mooncode_runtime_replay: None,
          mooncode_preflight_session_id: "",
          mooncode_preflight_status: "loading preflight gates",
          mooncode_preflights: [],
          mooncode_runtime_dispatch_session_id: "",
          mooncode_runtime_dispatch_status: "loading runtime dispatch",
          mooncode_runtime_dispatch: None,
          mooncode_runtime_claim_session_id: "",
          mooncode_runtime_claim_status: "loading runtime claim",
          mooncode_runtime_claim: None,
        },
      )
    NewAgentSession =>
      (
        sync_activity_cmd(Activity::Agents),
        {
          ..model,
          workspace_mode: WorkspaceMode::MoonCode,
          activity: Activity::Agents,
          command_open: false,
          selected_agent_session_id: "",
          agent_prompt: "Help me improve \{workspace_name(model)} using the selected context \{model.selected_path}.",
          agent_status: "new session draft",
        },
      )
    SetAgentPrompt(prompt) =>
      (@rabbita.none, { ..model, agent_prompt: prompt, agent_status: "draft" })
    SetAgentModel(value) =>
      (
        @rabbita.none,
        { ..model, agent_model: value, agent_status: "model selected" },
      )
    ToggleAgentWebSearch =>
      (
        @rabbita.none,
        {
          ..model,
          agent_web_search: !model.agent_web_search,
          agent_status: if !model.agent_web_search {
            "web search on"
          } else {
            "web search off"
          },
        },
      )
    SendAgentMessage =>
      if model.selected_workspace_id == "" {
        (
          sync_activity_cmd(Activity::Agents),
          {
            ..model,
            workspace_mode: WorkspaceMode::MoonCode,
            activity: Activity::Agents,
            command_open: false,
            agent_status: "select a book first",
          },
        )
      } else if model.agent_prompt.trim().to_owned() == "" {
        (
          sync_activity_cmd(Activity::Agents),
          {
            ..model,
            workspace_mode: WorkspaceMode::MoonCode,
            activity: Activity::Agents,
            command_open: false,
            agent_status: "enter a message",
          },
        )
      } else {
        match selected_agent_session(model) {
          Some(session) =>
            if model.workspace_mode == WorkspaceMode::MoonCode {
              let action = mooncode_composer_action(model, session)
              (
                sync_activity_batch(
                  Activity::Agents,
                  send_mooncode_composer_cmd(dispatch, model, session),
                ),
                {
                  ..model,
                  workspace_mode: WorkspaceMode::MoonCode,
                  activity: Activity::Agents,
                  command_open: false,
                  agent_status: if action == "steer" {
                    "steering MoonCode turn"
                  } else {
                    "prompting MoonCode runtime"
                  },
                },
              )
            } else {
              (
                sync_activity_batch(
                  Activity::Agents,
                  send_agent_message_cmd(dispatch, model, session),
                ),
                {
                  ..model,
                  activity: Activity::Agents,
                  command_open: false,
                  agent_status: "sending to MoonClaw",
                },
              )
            }
          None =>
            (
              sync_activity_batch(
                Activity::Agents,
                create_agent_session_cmd(dispatch, model),
              ),
              {
                ..model,
                workspace_mode: WorkspaceMode::MoonCode,
                activity: Activity::Agents,
                command_open: false,
                agent_status: "starting MoonClaw session",
              },
            )
        }
      }
    RunMoonCodeCommand(action) =>
      match selected_agent_session(model) {
        Some(session) =>
          (
              sync_activity_batch(
                Activity::Agents,
                mooncode_session_command_cmd(
                  dispatch,
                  model,
                  session,
                  action,
                  message=mooncode_command_message_from_prompt(model, action),
                ),
              ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "queued MoonCode \{action}",
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "start or select a MoonCode session first",
            },
          )
      }
    RunMoonCodeCommandForPath(action, context_path) =>
      match selected_agent_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              Activity::Agents,
              mooncode_session_command_cmd(
                dispatch,
                model,
                session,
                action,
                context_path~,
              ),
            ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "queued MoonCode \{action} for \{context_path}",
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "start or select a MoonCode session first",
            },
          )
      }
    RunMoonCodeCommandWithMessage(action, context_path, message, status) =>
      match selected_agent_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              Activity::Agents,
              mooncode_session_command_cmd(
                dispatch,
                model,
                session,
                action,
                context_path~,
                message~,
              ),
            ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: if status == "" {
                "queued MoonCode \{action}"
              } else {
                status
              },
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "start or select a MoonCode session first",
            },
          )
      }
    RunMoonCodeCommandOverride(action, context_path) =>
      match selected_agent_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              Activity::Agents,
              mooncode_session_command_cmd(
                dispatch,
                model,
                session,
                action,
                context_path~,
                force_preflight=true,
              ),
            ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "forced MoonCode \{action} for \{context_path}",
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "start or select a MoonCode session first",
            },
          )
      }
    RunMoonCodeRuntimeLoop =>
      match selected_agent_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              Activity::Agents,
              run_mooncode_runtime_loop_cmd(dispatch, session.id),
            ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              mooncode_runtime_claim_session_id: session.id,
              mooncode_runtime_claim_status: "running native runtime loop",
              agent_status: "running MoonClaw native MoonCode loop",
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "start or select a MoonCode session first",
            },
          )
      }
    RanMoonCodeRuntimeLoop(session_id, Ok(session)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          sync_activity_batch(
            Activity::Agents,
            @rabbita.batch([
              fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
              fetch_mooncode_stream_cmd(
                dispatch,
                session.id,
                if model.mooncode_stream_session_id == session.id {
                  model.mooncode_stream_cursor
                } else {
                  0
                },
              ),
              fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
              fetch_mooncode_change_set_cmd(dispatch, session.id),
              fetch_mooncode_eval_report_cmd(dispatch, session.id),
              fetch_mooncode_runtime_handoff_cmd(dispatch, session.id),
              fetch_mooncode_patch_set_cmd(dispatch, session.id),
              fetch_mooncode_tool_approvals_cmd(dispatch, session.id),
              fetch_mooncode_test_runs_cmd(dispatch, session.id),
              fetch_mooncode_package_candidates_cmd(dispatch, session.id),
              fetch_mooncode_action_plan_cmd(dispatch, session.id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
              fetch_mooncode_command_queue_cmd(dispatch, session.id),
              fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
              fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
              fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
              fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
              fetch_mooncode_preflight_matrix_cmd(
                dispatch, session.id, model.selected_path,
              ),
              schedule_agent_poll(dispatch),
            ]),
          ),
          {
            ..model,
            workspace_mode: WorkspaceMode::MoonCode,
            activity: Activity::Agents,
            selected_agent_session_id: session.id,
            mooncode_runtime_claim_session_id: session.id,
            mooncode_runtime_claim_status: "native runtime loop completed",
            agent_status: "MoonClaw native MoonCode loop completed",
          },
        )
      }
    RanMoonCodeRuntimeLoop(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          sync_activity_batch(
            Activity::Agents,
            @rabbita.batch([
              fetch_mooncode_stream_cmd(
                dispatch,
                session_id,
                if model.mooncode_stream_session_id == session_id {
                  model.mooncode_stream_cursor
                } else {
                  0
                },
              ),
              fetch_mooncode_runtime_event_sink_cmd(dispatch, session_id),
              fetch_mooncode_action_plan_cmd(dispatch, session_id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
              fetch_mooncode_runtime_dispatch_cmd(dispatch, session_id),
              fetch_mooncode_runtime_claim_state_cmd(dispatch, session_id),
              fetch_mooncode_command_queue_cmd(dispatch, session_id),
              fetch_mooncode_runtime_command_feed_cmd(dispatch, session_id),
              fetch_mooncode_runtime_replay_cmd(dispatch, session_id),
            ]),
          ),
          {
            ..model,
            workspace_mode: WorkspaceMode::MoonCode,
            activity: Activity::Agents,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: "native runtime loop failed: \{error}",
            agent_status: error,
          },
        )
      }
    StartMoonCodeRuntimeService =>
      match selected_agent_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              Activity::Agents,
              start_mooncode_runtime_service_cmd(dispatch, session.id),
            ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              mooncode_runtime_claim_session_id: session.id,
              mooncode_runtime_claim_status: "starting native runtime service",
              agent_status: "starting MoonClaw native MoonCode service",
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "start or select a MoonCode session first",
            },
          )
      }
    StartedMoonCodeRuntimeService(session_id, Ok(session)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          sync_activity_batch(
            Activity::Agents,
            @rabbita.batch([
              fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
              fetch_mooncode_stream_cmd(
                dispatch,
                session.id,
                if model.mooncode_stream_session_id == session.id {
                  model.mooncode_stream_cursor
                } else {
                  0
                },
              ),
              fetch_mooncode_runtime_event_sink_cmd(dispatch, session.id),
              fetch_mooncode_change_set_cmd(dispatch, session.id),
              fetch_mooncode_eval_report_cmd(dispatch, session.id),
              fetch_mooncode_runtime_handoff_cmd(dispatch, session.id),
              fetch_mooncode_patch_set_cmd(dispatch, session.id),
              fetch_mooncode_tool_approvals_cmd(dispatch, session.id),
              fetch_mooncode_test_runs_cmd(dispatch, session.id),
              fetch_mooncode_package_candidates_cmd(dispatch, session.id),
              fetch_mooncode_action_plan_cmd(dispatch, session.id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session.id),
              fetch_mooncode_command_queue_cmd(dispatch, session.id),
              fetch_mooncode_runtime_command_feed_cmd(dispatch, session.id),
              fetch_mooncode_runtime_replay_cmd(dispatch, session.id),
              fetch_mooncode_runtime_dispatch_cmd(dispatch, session.id),
              fetch_mooncode_runtime_claim_state_cmd(dispatch, session.id),
              fetch_mooncode_preflight_matrix_cmd(
                dispatch, session.id, model.selected_path,
              ),
              schedule_agent_poll(dispatch),
            ]),
          ),
          {
            ..model,
            workspace_mode: WorkspaceMode::MoonCode,
            activity: Activity::Agents,
            selected_agent_session_id: session.id,
            mooncode_runtime_claim_session_id: session.id,
            mooncode_runtime_claim_status: "native runtime service started",
            agent_status: "MoonClaw native MoonCode service started",
          },
        )
      }
    StartedMoonCodeRuntimeService(session_id, Err(error)) =>
      if session_id != model.selected_agent_session_id {
        (@rabbita.none, model)
      } else {
        (
          sync_activity_batch(
            Activity::Agents,
            @rabbita.batch([
              fetch_mooncode_stream_cmd(
                dispatch,
                session_id,
                if model.mooncode_stream_session_id == session_id {
                  model.mooncode_stream_cursor
                } else {
                  0
                },
              ),
              fetch_mooncode_runtime_event_sink_cmd(dispatch, session_id),
              fetch_mooncode_action_plan_cmd(dispatch, session_id),
              fetch_mooncode_runtime_evidence_cmd(dispatch, session_id),
              fetch_mooncode_runtime_dispatch_cmd(dispatch, session_id),
              fetch_mooncode_runtime_claim_state_cmd(dispatch, session_id),
              fetch_mooncode_command_queue_cmd(dispatch, session_id),
              fetch_mooncode_runtime_command_feed_cmd(dispatch, session_id),
              fetch_mooncode_runtime_replay_cmd(dispatch, session_id),
            ]),
          ),
          {
            ..model,
            workspace_mode: WorkspaceMode::MoonCode,
            activity: Activity::Agents,
            mooncode_runtime_claim_session_id: session_id,
            mooncode_runtime_claim_status: "native runtime service failed: \{error}",
            agent_status: error,
          },
        )
      }
    ProbeMoonCodeToolAuthorization(tool_id) =>
      match selected_agent_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              Activity::Agents,
              probe_mooncode_tool_authorization_cmd(
                dispatch, session.id, model.selected_path, tool_id,
              ),
            ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              mooncode_tool_authorization_session_id: session.id,
              mooncode_tool_authorization_status: "probing \{tool_id}",
              agent_status: "probing MoonCode \{tool_id} authorization",
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "start or select a MoonCode session first",
            },
          )
      }
    ClaimMoonCodeRuntime(force) =>
      match selected_agent_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              Activity::Agents,
              claim_mooncode_runtime_cmd(dispatch, session.id, force),
            ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              mooncode_runtime_claim_session_id: session.id,
              mooncode_runtime_claim_status: if force {
                "force-claiming runtime command"
              } else {
                "claiming runtime command"
              },
              agent_status: if force {
                "force-claiming MoonCode runtime command"
              } else {
                "claiming MoonCode runtime command"
              },
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "start or select a MoonCode session first",
            },
          )
      }
    AckMoonCodeRuntimeCommand(command_id, status) =>
      match selected_agent_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              Activity::Agents,
              ack_mooncode_runtime_command_cmd(
                dispatch, session.id, command_id, status,
              ),
            ),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              mooncode_runtime_claim_session_id: session.id,
              mooncode_runtime_claim_status: "recording runtime \{status}",
              agent_status: "recording MoonCode runtime acknowledgement",
            },
          )
        None =>
          (
            sync_activity_cmd(Activity::Agents),
            {
              ..model,
              workspace_mode: WorkspaceMode::MoonCode,
              activity: Activity::Agents,
              command_open: false,
              agent_status: "start or select a MoonCode session first",
            },
          )
      }
    PollAgentSessions =>
      (
        @rabbita.batch([
          fetch_agent_daemon_cmd(dispatch),
          fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
          fetch_selected_mooncode_stream_cmd(dispatch, model),
          fetch_mooncode_runtime_event_sink_cmd(
            dispatch, model.selected_agent_session_id,
          ),
          fetch_mooncode_change_set_cmd(
            dispatch, model.selected_agent_session_id,
          ),
          fetch_mooncode_eval_report_cmd(
            dispatch, model.selected_agent_session_id,
          ),
          fetch_mooncode_runtime_handoff_cmd(
            dispatch, model.selected_agent_session_id,
          ),
          fetch_mooncode_patch_set_cmd(
            dispatch, model.selected_agent_session_id,
          ),
          schedule_agent_poll(dispatch),
        ]),
        model,
      )
    SelectWorkspace(workspace_id) =>
      (
        @rabbita.batch([
          reload_workspace_cmds(dispatch, workspace_id, "wiki/index.md"),
          fetch_agent_sessions_cmd(dispatch, workspace_id),
        ]),
        {
          ..model,
          selected_workspace_id: workspace_id,
          selected_agent_session_id: "",
          selected_path: "wiki/index.md",
          primary_preview_path: "wiki/index.md",
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
      let base_cmd = if is_directory {
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
      let cmd = match selected_agent_session(model) {
        Some(session) =>
          @rabbita.batch([
            base_cmd,
            fetch_mooncode_preflight_matrix_cmd(dispatch, session.id, path),
          ])
        None => base_cmd
      }
      (
        cmd,
        {
          ..model,
          selected_path: path,
          primary_preview_path: remember_primary_preview_path(model, path),
          current_directory: if is_directory {
            path
          } else {
            model.current_directory
          },
          preview: None,
          preview_status: "loading preview",
          mooncode_preflight_status: if model.selected_agent_session_id == "" {
            model.mooncode_preflight_status
          } else {
            "loading preflight gates"
          },
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
          match selected_agent_session(model) {
            Some(session) =>
              fetch_mooncode_preflight_matrix_cmd(dispatch, session.id, path)
            None => @rabbita.none
          },
        ]),
        {
          ..model,
          current_directory: path,
          selected_path: path,
          primary_preview_path: remember_primary_preview_path(model, path),
          preview: None,
          preview_status: "loading directory",
          mooncode_preflight_status: if model.selected_agent_session_id == "" {
            model.mooncode_preflight_status
          } else {
            "loading preflight gates"
          },
        },
      )
    OpenQuickPath(path) =>
      (
        @rabbita.batch([
          fetch_preview_cmd(dispatch, model.selected_workspace_id, path),
          fetch_review_diff_cmd(dispatch, model.selected_workspace_id, path),
          match selected_agent_session(model) {
            Some(session) =>
              fetch_mooncode_preflight_matrix_cmd(dispatch, session.id, path)
            None => @rabbita.none
          },
        ]),
        {
          ..model,
          selected_path: path,
          primary_preview_path: remember_primary_preview_path(model, path),
          preview: None,
          preview_status: "loading preview",
          mooncode_preflight_status: if model.selected_agent_session_id == "" {
            model.mooncode_preflight_status
          } else {
            "loading preflight gates"
          },
        },
      )
    SelectSearchHit(workspace_id, path) =>
      (
        sync_activity_batch(
          Activity::Explorer,
          @rabbita.batch([
            fetch_entries_cmd(dispatch, workspace_id, ""),
            fetch_preview_cmd(dispatch, workspace_id, path),
            fetch_runs_cmd(dispatch, workspace_id),
            fetch_review_diff_cmd(dispatch, workspace_id, path),
          ]),
        ),
        {
          ..model,
          activity: Activity::Explorer,
          command_open: false,
          selected_workspace_id: workspace_id,
          selected_path: path,
          primary_preview_path: if is_generated_site_path(path) {
            "wiki/index.md"
          } else {
            path
          },
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
        sync_activity_batch(Activity::Town, submit_request_cmd(dispatch, model)),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          request_status: "staging request",
        },
      )
    SetGoalTitle(title) => (@rabbita.none, { ..model, goal_title: title })
    SetGoalCadenceTicks(value) =>
      (@rabbita.none, { ..model, goal_cadence_ticks: value })
    SetGoalQualityThreshold(value) =>
      (@rabbita.none, { ..model, goal_quality_threshold: value })
    SetGoalSourcePolicy(value) =>
      (@rabbita.none, { ..model, goal_source_policy: value })
    SetPdfWatchBookId(value) =>
      (@rabbita.none, { ..model, pdf_watch_book_id: value })
    SetPdfWatchTopic(value) =>
      (@rabbita.none, { ..model, pdf_watch_topic: value })
    SetPdfWatchPurpose(value) =>
      (@rabbita.none, { ..model, pdf_watch_purpose: value })
    SetPdfWatchWebsites(value) =>
      (@rabbita.none, { ..model, pdf_watch_websites: value })
    SetPdfWatchCadenceMinutes(value) =>
      (@rabbita.none, { ..model, pdf_watch_cadence_minutes: value })
    SetPdfWatchSourcePolicy(value) =>
      (@rabbita.none, { ..model, pdf_watch_source_policy: value })
    SetPdfWatchNotifyRule(value) =>
      (@rabbita.none, { ..model, pdf_watch_notify_rule: value })
    SetPdfWatchSkillPack(value) =>
      (@rabbita.none, { ..model, pdf_watch_skill_pack: value })
    SetPdfWatchAnalysisMethod(value) =>
      (@rabbita.none, { ..model, pdf_watch_analysis_method: value })
    SetEbTargetScope(value) =>
      (@rabbita.none, { ..model, eb_target_scope: value })
    SetEbBondCode(value) => (@rabbita.none, { ..model, eb_bond_code: value })
    SetEbBondShortName(value) =>
      (@rabbita.none, { ..model, eb_bond_short_name: value })
    SetEbIssuer(value) => (@rabbita.none, { ..model, eb_issuer: value })
    SetEbUnderlyingCompany(value) =>
      (@rabbita.none, { ..model, eb_underlying_company: value })
    SetEbExchange(value) => (@rabbita.none, { ..model, eb_exchange: value })
    SetEbAsOf(value) => (@rabbita.none, { ..model, eb_as_of: value })
    SetEbAdditionalBonds(value) =>
      (@rabbita.none, { ..model, eb_additional_bonds: value })
    SelectBookBaseType(base_type) =>
      (@rabbita.none, apply_selected_book_base_type(model, base_type))
    SelectBookPattern(pattern_id) =>
      (@rabbita.none, apply_selected_book_pattern(model, pattern_id))
    CreateStandingGoal =>
      (
        sync_activity_batch(
          Activity::Town,
          create_standing_goal_cmd(dispatch, model),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          dispatch_status: "creating standing watch",
        },
      )
    CreatePdfEvidenceWatchBook =>
      if !pdf_watch_builder_pattern_supported(model) {
        (
          @rabbita.none,
          {
            ..model,
            pdf_watch_status: "select `pdf-evidence-watch` or `exchangeable-bond-evidence-watch`; `\{model.selected_book_pattern_id}` is registry-visible but not handled by this creator",
          },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            create_pdf_evidence_watch_book_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "publishing PDF evidence watch book",
          },
        )
      }
    RunEbSampleValidation =>
      if selected_book_id_for_validation(model) == "" {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: "publish or select an EB watch book first" },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            run_eb_sample_validation_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "running EB durable output validation",
          },
        )
      }
    ImportMoonclawPacket =>
      if selected_book_id_for_validation(model) == "" {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: "publish or select an EB watch book first" },
        )
      } else if eb_builder_moonclaw_action_blocked(model) {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: eb_target_readiness_summary(model) },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            import_eb_moonclaw_packet_cmd(dispatch, model, false),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "importing MoonClaw proposal packet",
          },
        )
      }
    LaunchMoonclawRun =>
      if selected_book_id_for_validation(model) == "" {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: "publish or select an EB watch book first" },
        )
      } else if eb_builder_moonclaw_action_blocked(model) {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: eb_target_readiness_summary(model) },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            import_eb_moonclaw_packet_cmd(dispatch, model, true),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "launching MoonClaw run",
          },
        )
      }
    RunConfirmedMoonclawJob =>
      if selected_book_id_for_validation(model) == "" {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: "publish or select an EB watch book first" },
        )
      } else if eb_builder_moonclaw_action_blocked(model) {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: eb_target_readiness_summary(model) },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            run_confirmed_eb_moonclaw_job_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "running confirmed MoonClaw job",
          },
        )
      }
    ReconcileMoonclawResult =>
      if selected_book_id_for_validation(model) == "" {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: "publish or select an EB watch book first" },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            reconcile_eb_moonclaw_result_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "reconciling completed MoonClaw result",
          },
        )
      }
    AcceptRecoveredEbOutput =>
      if selected_book_id_for_validation(model) == "" {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: "publish or select an EB watch book first" },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            accept_recovered_eb_output_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "accepting recovered EB output evidence",
          },
        )
      }
    ProveEbProduction =>
      if selected_book_id_for_validation(model) == "" {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: "publish or select an EB watch book first" },
        )
      } else if eb_builder_moonclaw_action_blocked(model) {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: eb_target_readiness_summary(model) },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            prove_eb_production_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "proving EB production run",
          },
        )
      }
    FreshRetryEbProduction =>
      if selected_book_id_for_validation(model) == "" {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: "publish or select an EB watch book first" },
        )
      } else if eb_builder_moonclaw_action_blocked(model) {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: eb_target_readiness_summary(model) },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            fresh_retry_eb_production_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "retrying EB production run from orphaned MoonClaw state",
          },
        )
      }
    AuditEbProductionHealth =>
      if selected_book_id_for_validation(model) == "" {
        (
          @rabbita.none,
          { ..model, pdf_watch_status: "publish or select an EB watch book first" },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            audit_eb_production_health_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "auditing EB production health",
          },
        )
      }
    ExportAppToolPortable =>
      if selected_book_id_for_portable_export(model) == "" {
        (
          @rabbita.none,
          {
            ..model,
            pdf_watch_status: "publish or select an app-tool MoonBook first",
          },
        )
      } else {
        (
          sync_activity_batch(
            Activity::Town,
            export_app_tool_portable_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Activity::Town,
            command_open: false,
            pdf_watch_status: "exporting portable app-tool bundle",
          },
        )
      }
    ExportAllAppToolPortable =>
      (
        sync_activity_batch(
          Activity::Town,
          export_all_app_tool_portable_cmd(dispatch),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          pdf_watch_status: "exporting all portable app-tool bundles",
        },
      )
    DispatchDaemonTick =>
      (
        sync_activity_batch(Activity::Town, dispatch_daemon_cmd(dispatch)),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          dispatch_status: "running daemon tick",
        },
      )
    FetchDaemonLifecycle =>
      (
        sync_activity_batch(
          Activity::Town,
          fetch_daemon_lifecycle_cmd(dispatch),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          daemon_status: "checking daemon",
        },
      )
    StartDaemon =>
      (
        sync_activity_batch(
          Activity::Town,
          manage_daemon_cmd(dispatch, "start"),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          daemon_status: "starting daemon",
        },
      )
    StopDaemon =>
      (
        sync_activity_batch(Activity::Town, manage_daemon_cmd(dispatch, "stop")),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          daemon_status: "stopping daemon",
        },
      )
    RestartDaemon =>
      (
        sync_activity_batch(
          Activity::Town,
          manage_daemon_cmd(dispatch, "restart"),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          daemon_status: "restarting daemon",
        },
      )
    EnableDaemonSupervision =>
      (
        sync_activity_batch(
          Activity::Town,
          set_daemon_supervision_cmd(dispatch, true),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          daemon_status: "enabling supervision",
        },
      )
    DisableDaemonSupervision =>
      (
        sync_activity_batch(
          Activity::Town,
          set_daemon_supervision_cmd(dispatch, false),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          daemon_status: "disabling supervision",
        },
      )
    InstallDaemonAgent =>
      (
        sync_activity_batch(
          Activity::Town,
          manage_daemon_agent_cmd(dispatch, "install"),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          daemon_status: "installing LaunchAgent",
        },
      )
    UninstallDaemonAgent =>
      (
        sync_activity_batch(
          Activity::Town,
          manage_daemon_agent_cmd(dispatch, "uninstall"),
        ),
        {
          ..model,
          activity: Activity::Town,
          command_open: false,
          daemon_status: "removing LaunchAgent",
        },
      )
    RevealSelection =>
      (
        reveal_selection_cmd(dispatch, model),
        { ..model, reveal_status: "revealing selection" },
      )
    SetInboxTitle(title) => (@rabbita.none, { ..model, inbox_title: title })
    SetInboxContent(content) =>
      (
        @rabbita.none,
        { ..model, inbox_content: content, inbox_status: "draft" },
      )
    SetImportUrl(url) =>
      (
        @rabbita.none,
        { ..model, import_url: url, inbox_status: "import draft" },
      )
    SetImportNote(note) =>
      (
        @rabbita.none,
        { ..model, import_note: note, inbox_status: "import draft" },
      )
    ImportUrlToInbox =>
      if model.import_url.trim().to_owned() == "" {
        (@rabbita.none, { ..model, inbox_status: "enter a URL to import" })
      } else {
        (
          import_url_cmd(dispatch, model),
          { ..model, inbox_status: "importing URL" },
        )
      }
    ImportLocalFiles =>
      (
        sync_activity_batch(Activity::Inbox, pick_import_files_cmd(dispatch)),
        {
          ..model,
          activity: Activity::Inbox,
          command_open: false,
          inbox_status: "opening file picker",
        },
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
        sync_activity_cmd(Activity::Inbox),
        {
          ..model,
          activity: Activity::Inbox,
          command_open: false,
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
        save_inbox_cmd(
          dispatch,
          { ..model, editing_inbox_path: "" },
          title,
          content,
        ),
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
          sync_activity_batch(
            Activity::Search,
            fetch_search_cmd(dispatch, query),
          ),
          {
            ..model,
            activity: Activity::Search,
            command_open: false,
            search_status: "searching",
          },
        )
      }
    }
    ToggleFavorite(path) =>
      (
        @rabbita.none,
        { ..model, favorites: toggle_string(model.favorites, path) },
      )
    SetViewTitle(title) => (@rabbita.none, { ..model, view_title: title })
    SaveCurrentView =>
      (save_view_cmd(dispatch, model), { ..model, host_status: "saving view" })
    SetTagValue(tag) => (@rabbita.none, { ..model, tag_value: tag })
    TagSelection =>
      (save_tag_cmd(dispatch, model), { ..model, reveal_status: "saving tag" })
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
          fetch_agent_daemon_cmd(dispatch),
          fetch_agent_models_cmd(dispatch),
          fetch_agent_sessions_cmd(dispatch, model.selected_workspace_id),
          fetch_mooncode_capabilities_cmd(dispatch),
          fetch_review_items_cmd(dispatch, model.selected_workspace_id),
          fetch_review_diff_cmd(
            dispatch,
            model.selected_workspace_id,
            model.selected_path,
          ),
          fetch_saved_views_cmd(dispatch),
          fetch_tags_cmd(dispatch),
          fetch_book_patterns_cmd(dispatch),
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
    Activity::Agents => render_agents_pane(dispatch, model)
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
        class=if model.current_directory == "" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("")),
        "Root",
      ),
      button(
        class=if model.current_directory == "wiki" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("wiki")),
        "Wiki",
      ),
      button(
        class=if model.current_directory == "inbox" {
          "section-pill active"
        } else {
          "section-pill"
        },
        on_click=dispatch(OpenDirectory("inbox")),
        "Inbox",
      ),
      button(
        class=if model.current_directory == "book/site/generated" {
          "section-pill active"
        } else {
          "section-pill"
        },
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
      div([h3(workspace_name(model)), p(workspace_root(model))]),
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
          [span(workspace.name), small(workspace.kind.to_string())],
        )
      }),
    ),
  ])
}

///|
fn render_tree(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  if model.entries.length() == 0 {
    div(class="empty-state", [strong("No entries loaded"), p(model.host_status)])
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
      button(
        class="icon-button",
        title="Run Search",
        on_click=dispatch(SearchNow),
        "S",
      ),
    ]),
    section(class="side-section", [
      input(
        class="line-input",
        value=model.search_query,
        placeholder="Find markdown, json, html, logs...",
        on_input=fn(value) { dispatch(SetSearchQuery(value)) },
        "",
      ),
      button(
        class="primary-button full",
        on_click=dispatch(SearchNow),
        "Search Books",
      ),
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
            small(
              "\{icon_for_kind(hit.kind)} \{hit.workspace_name} / \{hit.path}",
            ),
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
        button(
          class="secondary-button",
          on_click=dispatch(LoadSelectionIntoInbox),
          "Load Selection",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(StageSelectedLink),
          "Link Selection",
        ),
      ]),
      button(
        class="primary-button full",
        on_click=dispatch(SaveInboxNote),
        "Save Inbox Note",
      ),
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
        button(
          class="secondary-button",
          on_click=dispatch(ImportUrlToInbox),
          "Import URL",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(ImportLocalFiles),
          "Import Files",
        ),
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
fn render_agents_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "moonclaw"), h2("Agents")]),
      div(class="toolbar-actions", [
        button(
          class="icon-button",
          title="New Session",
          on_click=dispatch(NewAgentSession),
          "N",
        ),
        button(
          class="icon-button",
          title="Refresh Agents",
          on_click=dispatch(PollAgentSessions),
          "R",
        ),
      ]),
    ]),
    section(class="side-section", [
      h3("Daemon"),
      render_agent_daemon_state(model),
      p(class="status-line", model.agent_status),
    ]),
    section(class="side-section", [
      h3("Book Sessions"),
      button(
        class="primary-button full",
        on_click=dispatch(NewAgentSession),
        "New Session",
      ),
      div(
        class="agent-session-list",
        if model.agent_sessions.length() == 0 {
          [p(class="status-line", "no agent sessions yet")]
        } else {
          model.agent_sessions.map(session => {
            let selected = selected_agent_session(model)
              .map(fn(item) { item.id })
              .unwrap_or("") ==
              session.id
            button(
              class=if selected {
                "agent-session active"
              } else {
                "agent-session"
              },
              title="\{session.id} / \{session.cwd}",
              on_click=dispatch(SelectAgentSession(session.id)),
              [
                span(class="record-kind", session.status),
                strong(session.title),
                small(
                  "\{session.workspace_name} / \{agent_session_task_line(session)}",
                ),
                small(
                  "\{session.transcript.length()} messages / \{session.updated_at}",
                ),
              ],
            )
          })
        },
      ),
    ]),
  ])
}

///|
fn render_agent_daemon_state(model : Model) -> @rabbita.Html {
  match model.agent_daemon {
    Some(daemon) =>
      div(class="daemon-state", [
        info_row("Running", if daemon.running { "yes" } else { "no" }),
        info_row(
          "Port",
          if daemon.port > 0 {
            daemon.port.to_string()
          } else {
            "none"
          },
        ),
        info_row(
          "PID",
          if daemon.pid > 0 {
            daemon.pid.to_string()
          } else {
            "none"
          },
        ),
        info_row("Root", empty_label(daemon.moonclaw_root)),
        info_row("Info", daemon.info_path),
      ])
    None =>
      div(class="daemon-state", [
        info_row("Running", "unknown"),
        info_row("Port", "none"),
      ])
  }
}

///|
fn agent_session_task_line(session : AgentSession) -> String {
  let model = if session.model == "" { "default" } else { session.model }
  let task = if session.moonclaw_task_id == "" {
    "not attached"
  } else {
    session.moonclaw_task_id
  }
  "\{model} / \{task} / queued \{session.queued_count}"
}

///|
fn book_base_type_buttons(
  dispatch : Dispatch[Msg],
  model : Model,
) -> Array[@rabbita.Html] {
  if model.book_base_types.length() == 0 {
    [
      button(
        class=book_base_type_button_class(model, "research-book"),
        title="MoonBook base type for source-backed research books",
        on_click=dispatch(SelectBookBaseType("research-book")),
        "Research Book",
      ),
    ]
  } else {
    model.book_base_types.map(base => {
      button(
        class=book_base_type_button_class(model, base.id),
        title=book_base_type_tooltip(base),
        on_click=dispatch(SelectBookBaseType(base.id)),
        base.title,
      )
    })
  }
}

///|
fn book_base_type_tooltip(base : BookBaseTypeRecord) -> String {
  [
    base.description,
    "Owner: " + base.owner,
    "Source: " + base.source,
    "Creation palette: " + base.creation_palette_source,
    "MoonBook refs: " + base.moonbook_layout_refs.join(", "),
    "Template refs: " + base.template_registry_refs.join(", "),
    "Patterns: " + base.supported_patterns.join(", "),
    "Roots: " + base.required_roots.join(", "),
  ].join("\n")
}

///|
fn book_base_type_button_class(model : Model, base_type : String) -> String {
  if model.selected_book_base_type == base_type {
    "option-chip active"
  } else {
    "option-chip"
  }
}

///|
fn book_pattern_buttons(
  dispatch : Dispatch[Msg],
  model : Model,
) -> Array[@rabbita.Html] {
  if model.book_patterns.length() == 0 {
    [
      button(
        class=book_pattern_button_class(model, "pdf-evidence-watch"),
        on_click=dispatch(SelectBookPattern("pdf-evidence-watch")),
        "PDF Evidence Watch",
      ),
      button(
        class=book_pattern_button_class(model, "exchangeable-bond-evidence-watch"),
        on_click=dispatch(SelectBookPattern("exchangeable-bond-evidence-watch")),
        "EB Evidence Watch",
      ),
    ]
  } else {
    let buttons : Array[@rabbita.Html] = []
    for pattern in model.book_patterns {
      if pattern.base_type == model.selected_book_base_type {
        buttons.push(
          button(
            class=book_pattern_button_class(model, pattern.id),
            title=book_pattern_tooltip(pattern),
            on_click=dispatch(SelectBookPattern(pattern.id)),
            pattern.title,
          ),
        )
      }
    }
    buttons
  }
}

///|
fn book_pattern_tooltip(pattern : BookPatternRecord) -> String {
  [
    pattern.base_type + " / " + pattern.output,
    pattern.description,
    "Default topic: " + pattern.default_topic,
    "Cadence: \{pattern.default_cadence_minutes} minutes",
    "Source policy: " + pattern.default_source_policy,
    "Sites: \{pattern.default_websites.length()}",
    "Skills: " + pattern.skills.join(", "),
  ].join("\n")
}

///|
fn book_pattern_button_class(model : Model, pattern_id : String) -> String {
  if model.selected_book_pattern_id == pattern_id {
    "option-chip active"
  } else {
    "option-chip"
  }
}

///|
fn eb_target_scope_button_class(model : Model, target_scope : String) -> String {
  if eb_target_scope_from_model(model) == target_scope {
    "option-chip active"
  } else {
    "option-chip"
  }
}

///|
fn eb_moonclaw_action_button_class(model : Model) -> String {
  if eb_builder_moonclaw_action_blocked(model) {
    "secondary-button full disabled"
  } else {
    "secondary-button full"
  }
}

///|
fn render_eb_tracking_fields(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !selected_pattern_is_eb(model) {
    return span(class="hidden-inline", "")
  }
  let ready = eb_targets_production_ready(model)
  let target_scope = eb_target_scope_from_model(model)
  div(class="eb-target-fields", [
    div(class="toolbar-actions scope-toggle", [
      button(
        class=eb_target_scope_button_class(model, "active_universe"),
        on_click=dispatch(SetEbTargetScope("active_universe")),
        "Active Universe",
      ),
      button(
        class=eb_target_scope_button_class(model, "single_bond"),
        on_click=dispatch(SetEbTargetScope("single_bond")),
        "Single Bond",
      ),
      button(
        class=eb_target_scope_button_class(model, "portfolio"),
        on_click=dispatch(SetEbTargetScope("portfolio")),
        "Portfolio",
      ),
    ]),
    p(
      class=if ready { "status-line good" } else { "status-line warning" },
      eb_target_readiness_summary(model),
    ),
    if target_scope == "active_universe" {
      div(class="field-grid compact-fields", [
        input(
          class="line-input",
          value=model.eb_as_of,
          placeholder="YYYYMMDD",
          on_input=fn(value) { dispatch(SetEbAsOf(value)) },
          "",
        ),
        code("ACTIVEEB aggregate"),
      ])
    } else {
      div(class="eb-target-fields", [
        div(class="field-grid compact-fields", [
          input(
            class="line-input",
            value=model.eb_bond_code,
            placeholder="Bond code, e.g. 132018",
            on_input=fn(value) { dispatch(SetEbBondCode(value)) },
            "",
          ),
          input(
            class="line-input",
            value=model.eb_bond_short_name,
            placeholder="Bond full/short name",
            on_input=fn(value) { dispatch(SetEbBondShortName(value)) },
            "",
          ),
        ]),
        input(
          class="line-input",
          value=model.eb_issuer,
          placeholder="Issuer",
          on_input=fn(value) { dispatch(SetEbIssuer(value)) },
          "",
        ),
        input(
          class="line-input",
          value=model.eb_underlying_company,
          placeholder="Underlying listed company",
          on_input=fn(value) { dispatch(SetEbUnderlyingCompany(value)) },
          "",
        ),
        div(class="field-grid compact-fields", [
          input(
            class="line-input",
            value=model.eb_exchange,
            placeholder="上交所 or 深交所",
            on_input=fn(value) { dispatch(SetEbExchange(value)) },
            "",
          ),
          input(
            class="line-input",
            value=model.eb_as_of,
            placeholder="YYYYMMDD",
            on_input=fn(value) { dispatch(SetEbAsOf(value)) },
            "",
          ),
        ]),
        textarea(
          class="side-textarea compact-textarea",
          rows=3,
          value=model.eb_additional_bonds,
          placeholder="Additional bonds: code | short name | issuer | underlying | exchange",
          on_input=fn(value) { dispatch(SetEbAdditionalBonds(value)) },
          "",
        ),
      ])
    },
  ])
}

///|
fn pdf_watch_wizard_step_class(done : Bool) -> String {
  if done {
    "wizard-step done"
  } else {
    "wizard-step"
  }
}

///|
fn production_checklist_item_class(item : ProductionChecklistItem) -> String {
  if item.ok {
    "production-gate-row good"
  } else {
    "production-gate-row blocked"
  }
}

///|
fn nonempty_or_dash(value : String) -> String {
  if value.trim().is_empty() {
    "-"
  } else {
    value
  }
}

///|
fn bool_word(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn render_eb_production_audit_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !selected_pattern_is_eb(model) ||
    (model.eb_production_checklist.length() == 0 &&
      model.eb_production_proof_receipt_path == "") {
    return span(class="hidden-inline", "")
  }
  let blocker_limit = if model.eb_production_proof_failed_checks.length() < 5 {
    model.eb_production_proof_failed_checks.length()
  } else {
    5
  }
  let blockers = if model.eb_production_proof_failed_checks.length() == 0 {
    [span(class="record-kind good", "no proof blockers recorded")]
  } else {
    model.eb_production_proof_failed_checks[:blocker_limit].map(check =>
      span(class="record-kind warning", check)
    )
  }
  div(class="production-audit-panel", [
    div(class="production-audit-header", [
      div([
        p(class="eyebrow", "durable evidence"),
        h3("Production Audit"),
      ]),
      span(
        class="record-kind",
        nonempty_or_dash(model.eb_production_proof_status),
      ),
    ]),
    div(class="audit-proof-grid", [
      div([
        span(class="mini-label", "Proof receipt"),
        code(nonempty_or_dash(model.eb_production_proof_receipt_path)),
      ]),
      div([
        span(class="mini-label", "Proof level"),
        code(nonempty_or_dash(model.eb_production_proof_level)),
      ]),
      div([
        span(class="mini-label", "Base type"),
        code(nonempty_or_dash(model.eb_base_type)),
      ]),
      div([
        span(class="mini-label", "Base selection"),
        code(nonempty_or_dash(model.eb_base_type_selection_path)),
      ]),
      div([
        span(class="mini-label", "Base selection ready"),
        code(bool_word(model.eb_base_type_selection_ready)),
      ]),
      div([
        span(class="mini-label", "Handoff target"),
        code(nonempty_or_dash(model.eb_base_type_handoff_target)),
      ]),
      div([
        span(class="mini-label", "Moontown publish"),
        code(nonempty_or_dash(model.eb_moontown_publish_receipt_path)),
      ]),
      div([
        span(class="mini-label", "Moontown publish ready"),
        code(bool_word(model.eb_moontown_publish_receipt_ready)),
      ]),
      div([
        span(class="mini-label", "Standing goal registered"),
        code(bool_word(model.eb_standing_goal_registration_ready)),
      ]),
      div([
        span(class="mini-label", "Global standing goal"),
        code(bool_word(model.eb_global_standing_goal_ready)),
      ]),
      div([
        span(class="mini-label", "Run id"),
        code(
          nonempty_or_dash(
            trimmed_or(
              model.eb_production_proof_run_id,
              model.eb_moonclaw_import_run_id,
            ),
          ),
        ),
      ]),
      div([
        span(class="mini-label", "MoonClaw status"),
        code(nonempty_or_dash(model.eb_moonclaw_confirmed_run_status)),
      ]),
      div([
        span(class="mini-label", "Import status"),
        code(nonempty_or_dash(model.eb_moonclaw_import_status)),
      ]),
      div([
        span(class="mini-label", "Recovered import"),
        code(if model.eb_moonclaw_import_receipt_recovered { "true" } else { "false" }),
      ]),
      div([
        span(class="mini-label", "Recovery source"),
        code(nonempty_or_dash(model.eb_moonclaw_import_recovery_source)),
      ]),
      div([
        span(class="mini-label", "Retry recommended"),
        code(if model.eb_moonclaw_retry_recommended { "true" } else { "false" }),
      ]),
    ]),
    div(class="audit-output-evidence", [
      div([
        span(class="mini-label", "Run receipt"),
        code(nonempty_or_dash(model.eb_moonclaw_run_receipt_path)),
      ]),
      div([
        span(class="mini-label", "Retry import"),
        code(nonempty_or_dash(model.eb_moonclaw_retry_import_receipt_path)),
      ]),
      div([
        span(class="mini-label", "Retry status"),
        code(nonempty_or_dash(model.eb_moonclaw_retry_import_status)),
      ]),
      div([
        span(class="mini-label", "Accepted workbook"),
        code(nonempty_or_dash(model.eb_output_path)),
      ]),
      div([
        span(class="mini-label", "Expected output contract"),
        code(nonempty_or_dash(model.eb_expected_output_contract_path)),
      ]),
      div([
        span(class="mini-label", "Expected contract ready"),
        code(bool_word(model.eb_expected_output_contract_ready)),
      ]),
      div([
        span(class="mini-label", "Output contract id"),
        code(nonempty_or_dash(model.eb_expected_output_contract_id)),
      ]),
      div([
        span(class="mini-label", "Workbook validation"),
        code(nonempty_or_dash(model.eb_workbook_validation_path)),
      ]),
      div([
        span(class="mini-label", "Source screen"),
        code(nonempty_or_dash(model.eb_source_screen_path)),
      ]),
      div([
        span(class="mini-label", "Book result"),
        code(nonempty_or_dash(model.eb_book_result_path)),
      ]),
      div([
        span(class="mini-label", "MoonClaw result"),
        code(nonempty_or_dash(model.eb_moonclaw_result_path)),
      ]),
      div([
        span(class="mini-label", "Output validation"),
        code(nonempty_or_dash(model.eb_output_validation_status)),
      ]),
    ]),
    if model.eb_moonclaw_orphaned_after_timeout ||
      model.eb_moonclaw_retry_recommended {
      div(class="orphaned-run-callout", [
        strong("MoonClaw run is orphaned after timeout"),
        p(
          "The confirmed run is still recorded as Running after Moondesk's bounded execution window. Start a fresh production proof to import a replacement run instead of reusing the abandoned one.",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(FreshRetryEbProduction),
          "Fresh Retry Orphaned Run",
        ),
      ])
    } else {
      span(class="hidden-inline", "")
    },
    div(class="proof-blockers", blockers),
    ul(
      class="production-gate-list",
      model.eb_production_checklist.map(item => {
        li(class=production_checklist_item_class(item), [
          div(class="gate-main", [
            span(class="gate-state", if item.ok { "ok" } else { "wait" }),
            strong(item.label),
          ]),
          p(class="gate-requirement", item.requirement),
          if item.evidence.trim().is_empty() {
            span(class="gate-evidence empty", "no evidence path yet")
          } else {
            code(item.evidence)
          },
        ])
      }),
    ),
  ])
}

///|
fn render_pdf_watch_wizard(model : Model) -> @rabbita.Html {
  let websites = text_lines(model.pdf_watch_websites)
  let skills = text_lines(model.pdf_watch_skill_pack)
  let method_ready = !model.pdf_watch_analysis_method.trim().is_empty()
  let book_ready = pdf_watch_builder_pattern_supported(model)
  let cadence = @string.parse_int(model.pdf_watch_cadence_minutes) catch {
    _ => 0
  }
  let watch_ready = websites.length() > 0 && cadence > 0
  let notify_ready = !model.pdf_watch_notify_rule.trim().is_empty()
  div(class="book-wizard", [
    div(class="book-wizard-header", [
      strong(selected_book_pattern_title(model)),
      span(class="record-kind", model.selected_book_base_type + " pattern"),
    ]),
    ul(class="wizard-steps", [
      li(class=pdf_watch_wizard_step_class(book_ready), [
        span(class="wizard-index", "1"),
        span(
          if book_ready {
            "Choose research-book + " + model.selected_book_pattern_id
          } else {
            "Select a PDF/EB research-book pattern to publish"
          },
        ),
      ]),
      li(class=pdf_watch_wizard_step_class(websites.length() > 0), [
        span(class="wizard-index", "2"),
        span("\{websites.length()} source website(s)"),
      ]),
      li(class=pdf_watch_wizard_step_class(method_ready), [
        span(class="wizard-index", "3"),
        span("Write wiki/methods/my-analysis-method.md"),
      ]),
      li(class=pdf_watch_wizard_step_class(skills.contains("pdf-watch") && skills.contains("pdf-analysis")), [
        span(class="wizard-index", "4"),
        span("Select pdf-watch + pdf-analysis skills"),
      ]),
      li(class=pdf_watch_wizard_step_class(watch_ready), [
        span(class="wizard-index", "5"),
        span("Enable standing watch every " + model.pdf_watch_cadence_minutes + " minutes"),
      ]),
      li(class=pdf_watch_wizard_step_class(notify_ready), [
        span(class="wizard-index", "6"),
        span("Notify on " + model.pdf_watch_notify_rule),
      ]),
      li(class=pdf_watch_wizard_step_class(model.pdf_watch_last_book_id != ""), [
        span(class="wizard-index", "7"),
        span("Publish book to Moontown"),
      ]),
    ]),
    pre(
      class="source-block compact builder-config-preview",
      code(pdf_watch_builder_config_preview(model)),
    ),
  ])
}

///|
fn pdf_watch_builder_config_preview(model : Model) -> String {
  let websites = text_lines(model.pdf_watch_websites)
  let skills = text_lines(model.pdf_watch_skill_pack)
  let targets = eb_target_bonds_from_model(model)
  (
    {
      "id": trimmed_or(model.pdf_watch_book_id, "research-my-domain-pdf-watch"),
      "type": "research-book",
      "specialization": model.selected_book_pattern_id,
      "pattern_components": {
        "source_adapter": "websites",
        "extractor": "pdf-full-text",
        "analysis_skill": "pdf-analysis",
        "standing_watch": true,
      },
      "watch": {
        "cadence_minutes": @string.parse_int(model.pdf_watch_cadence_minutes) catch {
          _ => 30
        },
        "source_policy": trimmed_or(model.pdf_watch_source_policy, "web-first"),
        "websites": json_string_array(websites),
        "file_types": json_string_array(["pdf"]),
        "dedupe_by": json_string_array(["url", "title", "sha256"]),
      },
      "analysis": {
        "method_page": "wiki/methods/my-analysis-method.md",
        "notify_on": json_string_array([
          trimmed_or(model.pdf_watch_notify_rule, "accepted_new_knowledge"),
        ]),
        "skill_pack": json_string_array(skills),
      },
      "targets": {
        "target_scope": eb_target_scope_from_model(model),
        "active_universe_default": eb_target_scope_from_model(model) ==
        "active_universe",
        "production_ready": if selected_pattern_is_eb(model) {
          eb_targets_production_ready(model).to_json()
        } else {
          Json::null()
        },
        "target_count": targets.length(),
        "bonds": Json::array(targets),
      },
    } : Json).stringify(indent=2)
}

///|
fn render_town_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "moontown"), h2("Requests")]),
      div(class="toolbar-actions", [
        button(
          class="icon-button",
          title="Run Daemon Tick",
          on_click=dispatch(DispatchDaemonTick),
          "D",
        ),
        button(
          class="icon-button",
          title="Refresh",
          on_click=dispatch(RefreshAll),
          "R",
        ),
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
      button(
        class="primary-button full",
        on_click=dispatch(SubmitRequest),
        "Submit to Town",
      ),
      p(class="status-line", model.request_status),
    ]),
    section(class="side-section", [
      h3("Book Pattern Builder"),
      render_pdf_watch_wizard(model),
      div(
        class="pattern-picker",
        book_base_type_buttons(dispatch, model),
      ),
      div(
        class="pattern-picker",
        book_pattern_buttons(dispatch, model),
      ),
      input(
        class="line-input",
        value=model.pdf_watch_book_id,
        placeholder="Book id, e.g. research-my-domain-pdf-watch",
        on_input=fn(value) { dispatch(SetPdfWatchBookId(value)) },
        "",
      ),
      input(
        class="line-input",
        value=model.pdf_watch_topic,
        placeholder="Domain title/topic",
        on_input=fn(value) { dispatch(SetPdfWatchTopic(value)) },
        "",
      ),
      textarea(
        class="side-textarea compact-textarea",
        rows=3,
        value=model.pdf_watch_purpose,
        placeholder="Book purpose",
        on_input=fn(value) { dispatch(SetPdfWatchPurpose(value)) },
        "",
      ),
      textarea(
        class="side-textarea compact-textarea",
        rows=4,
        value=model.pdf_watch_websites,
        placeholder="One source website per line",
        on_input=fn(value) { dispatch(SetPdfWatchWebsites(value)) },
        "",
      ),
      div(class="field-grid compact-fields", [
        input(
          class="line-input",
          value=model.pdf_watch_cadence_minutes,
          placeholder="Cadence minutes",
          on_input=fn(value) { dispatch(SetPdfWatchCadenceMinutes(value)) },
          "",
        ),
        input(
          class="line-input",
          value=model.pdf_watch_source_policy,
          placeholder="Source policy",
          on_input=fn(value) { dispatch(SetPdfWatchSourcePolicy(value)) },
          "",
        ),
      ]),
      input(
        class="line-input",
        value=model.pdf_watch_notify_rule,
        placeholder="Notification rule",
        on_input=fn(value) { dispatch(SetPdfWatchNotifyRule(value)) },
        "",
      ),
      textarea(
        class="side-textarea mini-textarea",
        rows=3,
        value=model.pdf_watch_skill_pack,
        placeholder="Skill pack, one skill per line",
        on_input=fn(value) { dispatch(SetPdfWatchSkillPack(value)) },
        "",
      ),
      render_eb_tracking_fields(dispatch, model),
      textarea(
        class="side-textarea compact-textarea",
        rows=6,
        value=model.pdf_watch_analysis_method,
        placeholder="wiki/methods/my-analysis-method.md",
        on_input=fn(value) { dispatch(SetPdfWatchAnalysisMethod(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(
          class=if pdf_watch_builder_pattern_supported(model) {
            "primary-button full"
          } else {
            "secondary-button full"
          },
          on_click=dispatch(CreatePdfEvidenceWatchBook),
          if pdf_watch_builder_pattern_supported(model) {
            "Publish Book + Watch"
          } else {
            "Choose PDF/EB Pattern First"
          },
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(ExportAppToolPortable),
          "Export Portable App",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(ExportAllAppToolPortable),
          "Export All Portable Apps",
        ),
        if selected_pattern_is_eb(model) {
          div(class="button-stack", [
            button(
              class=eb_moonclaw_action_button_class(model),
              on_click=dispatch(ImportMoonclawPacket),
              "Import MoonClaw Packet",
            ),
            button(
              class=eb_moonclaw_action_button_class(model),
              on_click=dispatch(LaunchMoonclawRun),
              "Launch MoonClaw Run",
            ),
            button(
              class=eb_moonclaw_action_button_class(model),
              on_click=dispatch(RunConfirmedMoonclawJob),
              "Run Confirmed MoonClaw",
            ),
            button(
              class="secondary-button full",
              on_click=dispatch(ReconcileMoonclawResult),
              "Reconcile MoonClaw Result",
            ),
            button(
              class="secondary-button full",
              on_click=dispatch(AcceptRecoveredEbOutput),
              "Accept Recovered Output",
            ),
            button(
              class=eb_moonclaw_action_button_class(model),
              on_click=dispatch(ProveEbProduction),
              "Prove Production Run",
            ),
            button(
              class="secondary-button full",
              on_click=dispatch(AuditEbProductionHealth),
              "Audit Production Health",
            ),
            button(
              class="secondary-button full",
              on_click=dispatch(RunEbSampleValidation),
              "Validate EB Output",
            ),
          ])
        } else {
          span(class="hidden-inline", "")
        },
      ]),
      p(class="status-line", model.pdf_watch_status),
      render_eb_production_audit_panel(dispatch, model),
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
        button(
          class="secondary-button",
          on_click=dispatch(CreateStandingGoal),
          "Create Watch",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(DispatchDaemonTick),
          "Run Tick",
        ),
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
        info_row(
          "Daemon",
          "\{progress.daemon_status} / tick \{progress.daemon_tick}",
        ),
        info_row("Running", if progress.daemon_running { "yes" } else { "no" }),
        info_row(
          "Supervision",
          if progress.supervision_enabled {
            "enabled"
          } else {
            "disabled"
          },
        ),
        info_row(
          "Due",
          "\{progress.due_goal_count} / next \{progress.next_due_tick}",
        ),
        info_row(
          "Queued",
          "\{progress.request_count} requests / \{progress.dispatch_count} dispatches",
        ),
        info_row(
          "Outputs",
          "\{progress.message_count} messages / \{progress.run_count} runs",
        ),
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
  if value == "" {
    "none"
  } else {
    value
  }
}

///|
fn string_list_label(values : Array[String]) -> String {
  if values.length() == 0 {
    "none"
  } else {
    values.join(", ")
  }
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
        model.events[:event_limit(model.events)].map(event => {
          div(class="event-row " + event.severity, [
            span(class="record-kind", event.severity),
            strong(event.title),
            small(
              "\{event.source} / \{event.kind} / \{event.id} / \{event_time_label(event)}",
            ),
            p(event.detail),
          ])
        }),
      )
    },
  ])
}

///|
fn event_limit(events : Array[DeskEvent]) -> Int {
  if events.length() > 8 {
    8
  } else {
    events.length()
  }
}

///|
fn event_time_label(event : DeskEvent) -> String {
  let tick = if event.tick > 0 { "tick \{event.tick}" } else { "no tick" }
  let run = if event.run_id == "" { "no run" } else { event.run_id }
  let time = if event.created_at == "" {
    empty_label(event.path)
  } else {
    event.created_at
  }
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
          info_row(
            "Status",
            if result.running {
              "running"
            } else {
              result.status
            },
          ),
          info_row(
            "PID",
            if result.pid > 0 {
              result.pid.to_string()
            } else {
              "none"
            },
          ),
          info_row("Command", result.command),
          info_row("CWD", result.cwd),
          info_row(
            "Started",
            if result.started_at == "" {
              "none"
            } else {
              result.started_at
            },
          ),
          info_row(
            "Stopped",
            if result.stopped_at == "" {
              "none"
            } else {
              result.stopped_at
            },
          ),
          info_row("Desired", result.desired_state),
          info_row(
            "Supervision",
            if result.supervision_enabled {
              "enabled"
            } else {
              "disabled"
            },
          ),
          info_row("Restarts", result.restart_count.to_string()),
          info_row(
            "Health",
            if result.last_health_check == "" {
              "none"
            } else {
              result.last_health_check
            },
          ),
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
      button(
        class="secondary-button",
        on_click=dispatch(RestartDaemon),
        "Restart",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(FetchDaemonLifecycle),
        "Status",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(EnableDaemonSupervision),
        "Supervise",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(DisableDaemonSupervision),
        "Unsupervise",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(InstallDaemonAgent),
        "Install Agent",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(UninstallDaemonAgent),
        "Remove Agent",
      ),
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
        info_row(
          "Agent",
          if agent.installed {
            if agent.loaded {
              "loaded"
            } else {
              "installed"
            }
          } else {
            "none"
          },
        ),
        info_row(
          "Result",
          if agent.ok {
            "ok"
          } else {
            "failed \{agent.exit_code}"
          },
        ),
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
        span(
          class="record-kind",
          if goal.enabled {
            "enabled"
          } else {
            "paused"
          },
        ),
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
        info_row(
          "Runs",
          "\{progress.ready_count} ready / \{progress.run_count} total",
        ),
        info_row("Artifacts", progress.artifact_count.to_string()),
        info_row(
          "Latest",
          if progress.latest_run == "" {
            "none"
          } else {
            "\{progress.latest_run} / \{progress.latest_status}"
          },
        ),
      ])
    None =>
      section(class="side-section", [
        h3("Progress"),
        p(class="status-line", "waiting for run progress"),
      ])
  }
}

///|
fn render_settings_pane(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "daily"), h2("Operating Surface")]),
      button(
        class="icon-button",
        title="Notify",
        on_click=dispatch(NotifyDaily),
        "N",
      ),
    ]),
    section(class="side-section", [
      h3("Today"),
      info_row("Requests", model.requests.length().to_string()),
      info_row("Runs", model.runs.length().to_string()),
      info_row("Messages", model.town_messages.length().to_string()),
      info_row("Goals", model.standing_goals.length().to_string()),
      info_row("Favorites", model.favorites.length().to_string()),
      button(
        class="primary-button full",
        on_click=dispatch(NotifyDaily),
        "Notify Summary",
      ),
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
fn render_saved_views_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="side-section", [
    h3("Saved Views"),
    input(
      class="line-input",
      value=model.view_title,
      placeholder="View title",
      on_input=fn(value) { dispatch(SetViewTitle(value)) },
      "",
    ),
    button(
      class="secondary-button full",
      on_click=dispatch(SaveCurrentView),
      "Save Current View",
    ),
    div(
      class="mini-list",
      model.saved_views.map(view => {
        button(
          class="mini-link",
          title="\{view.id} / \{view.updated_at}",
          on_click=dispatch(SelectSearchHit(view.workspace_id, view.path)),
          [
            span(view.title),
            small(
              if view.query == "" {
                "\{view.path} / \{view.created_at}"
              } else {
                "\{view.query} / \{view.path}"
              },
            ),
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
            [span(item.title), small("\{item.status} / \{item.path}")],
          )
        }),
      )
    },
  ])
}

///|
fn review_limit(items : Array[ReviewItem]) -> Int {
  if items.length() > 8 {
    8
  } else {
    items.length()
  }
}

///|
fn render_cadence_panel(model : Model) -> @rabbita.Html {
  section(class="side-section", [
    h3("Cadence"),
    div(
      class="cadence-list",
      model.standing_goals.map(goal => {
        let due_label = match model.analytics {
          Some(analytics) if analytics.daemon_tick >= goal.next_due_tick =>
            "due"
          Some(analytics) =>
            "\{goal.next_due_tick - analytics.daemon_tick} ticks"
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
        info_row(
          "Due",
          "\{analytics.due_goal_count} / active \{analytics.active_goal_count}",
        ),
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
fn outcome_row(
  label : String,
  value : Int,
  total : Int,
  tone : String,
) -> @rabbita.Html {
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
  let primary_path = if is_generated_site_path(model.selected_path) {
    model.primary_preview_path
  } else {
    model.selected_path
  }
  tabs.push({
    title: @desk.display_name(primary_path),
    path: primary_path,
    renderer: tab_renderer(model, primary_path),
  })
  if primary_path != "book/site/generated/index.html" {
    tabs.push({
      title: "generated site",
      path: "book/site/generated/index.html",
      renderer: @desk.PreviewRenderer::Html,
    })
  }
  match first_run_report_path(model) {
    Some(path) =>
      if path != primary_path && path != "book/site/generated/index.html" {
        tabs.push({
          title: "run report",
          path,
          renderer: @desk.PreviewRenderer::ArtifactSummary,
        })
      }
    None => ()
  }
  tabs
}

///|
fn tab_renderer(model : Model, path : String) -> @desk.PreviewRenderer {
  if path == model.selected_path {
    match model.preview {
      Some(preview) => preview.renderer
      None => @desk.renderer_for_kind(@desk.infer_entry_kind(path))
    }
  } else {
    @desk.renderer_for_kind(@desk.infer_entry_kind(path))
  }
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
                href=html_preview_url(model, model.selected_path),
                target=@html.Target::Blank,
                rel="noreferrer",
                "Open",
              ),
            ]),
            iframe(
              class="site-iframe",
              src=html_preview_url(model, model.selected_path),
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
fn render_agent_center(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let session = selected_agent_session(model)
  main_(class="preview-center agent-center", [
    div(class="preview-toolbar", [
      span(class="path-pill", selected_agent_task_label(model)),
      div(class="toolbar-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(NewAgentSession),
          "New",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(PollAgentSessions),
          "Refresh",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeRuntimeLoop),
          "Run Native Loop",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_tests")),
          "Run Tests",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_build")),
          "Run Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_eval")),
          "Run Eval",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("package")),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("commit")),
          "Commit",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("accept")),
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("reject")),
          "Reject",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("cancel")),
          "Cancel",
        ),
      ]),
    ]),
    section(class="agent-chat-surface", [
      match session {
        Some(session) => div(class="agent-session-surface", [
          render_mooncode_session_header(dispatch, model, session),
          render_mooncode_preflight_panel(dispatch, model),
          render_mooncode_transcript(model, session),
          render_mooncode_command_queue_panel(dispatch, model),
          render_mooncode_runtime_command_feed_panel(model),
          render_mooncode_runtime_replay_panel(model),
          render_mooncode_runtime_event_sink_panel(model),
          render_mooncode_action_plan_panel(dispatch, model),
          render_mooncode_runtime_evidence_panel(model),
          render_mooncode_runtime_claim_panel(dispatch, model),
          render_mooncode_runtime_dispatch_panel(model),
          render_mooncode_eval_report_panel(dispatch, model),
          render_mooncode_runtime_handoff_panel(model),
          render_mooncode_review_queue(dispatch, session),
          render_mooncode_change_set_panel(model),
          render_mooncode_test_runs_panel(dispatch, model),
          render_mooncode_package_candidates_panel(dispatch, model),
          render_mooncode_patch_set_panel(dispatch, model),
          render_mooncode_tool_authorization_panel(dispatch, model),
          render_mooncode_tool_approvals_panel(dispatch, model),
          render_mooncode_event_lanes(model, session),
        ])
        None =>
          div(class="agent-empty", [
            h1("Agents"),
            p(
              class="lead",
              "Start a book-scoped MoonClaw session for the selected workspace.",
            ),
          ])
      },
      div(class="agent-composer", [
        textarea(
          class="agent-input",
          rows=7,
          value=model.agent_prompt,
          placeholder="Ask MoonClaw to inspect, code, refactor, test, or explain this book/code workspace.",
          on_input=fn(value) { dispatch(SetAgentPrompt(value)) },
          "",
        ),
        div(class="composer-options", [
          span(class="option-chip active", workspace_name(model)),
          span(class="option-chip", model.selected_path),
          button(
            class=if model.agent_web_search {
              "secondary-button active"
            } else {
              "secondary-button"
            },
            on_click=dispatch(ToggleAgentWebSearch),
            if model.agent_web_search {
              "Web On"
            } else {
              "Web Off"
            },
          ),
          button(
            class="primary-button",
            on_click=dispatch(SendAgentMessage),
            mooncode_composer_button_label(model, session),
          ),
        ]),
        p(class="status-line", model.agent_status),
      ]),
    ]),
  ])
}

///|
fn mooncode_command_message_from_prompt(
  model : Model,
  action : String
) -> String {
  match action {
    "prompt" | "steer" => model.agent_prompt.trim().to_owned()
    _ => ""
  }
}

///|
fn mooncode_composer_button_label(
  model : Model,
  session : AgentSession?
) -> String {
  match session {
    Some(active) if mooncode_session_accepts_steer(model, active) => "Steer"
    Some(_) => "Prompt"
    None => "Start"
  }
}

///|
fn render_mooncode_session_header(
  dispatch : Dispatch[Msg],
  model : Model,
  session : AgentSession,
) -> @rabbita.Html {
  let summary = session.mooncode_summary
  let action_state = match model.mooncode_action_plan {
    Some(plan) => "\{plan.status} / \{plan.next_required_action}"
    None => model.mooncode_action_plan_status
  }
  let dispatch_state = match model.mooncode_runtime_dispatch {
    Some(dispatch_state) =>
      "\{dispatch_state.runtime_dispatch_count} receipt(s), \{dispatch_state.runtime_dispatch_pending_count} pending"
    None => model.mooncode_runtime_dispatch_status
  }
  let production_next_action = json_string_value(
    summary.production_readiness,
    "next_action",
    default="inspect_production_check",
  )
  let production_next_owner = json_string_value(
    summary.production_readiness,
    "next_owner",
    default="mooncode",
  )
  div(class="mooncode-session-header", [
    div(class="mooncode-session-title", [
      div([
        p(class="eyebrow", "mooncode session"),
        h2(session.title),
        small(
          "\{session.workspace_name} / \{agent_session_task_line(session)}",
        ),
      ]),
      div(class="toolbar-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("steer")),
          "Steer",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("cancel")),
          "Cancel",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeRuntimeLoop),
          "Run Native Loop",
        ),
        button(
          class="primary-button",
          on_click=dispatch(RunMoonCodeCommand("run_tests")),
          "Run Tests",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_build")),
          "Run Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_eval")),
          "Run Eval",
        ),
      ]),
    ]),
    div(class="mooncode-session-grid", [
      info_chip("next action", action_state),
      info_chip(
        "production next",
        "\{production_next_action} / \{production_next_owner}",
      ),
      info_chip("stream", "\{summary.stream_source} / \{summary.stream_mode}"),
      info_chip("dispatch", "\{summary.dispatch_mode} / \{dispatch_state}"),
      info_chip("pending steers", mooncode_summary_pending_steer_label(summary)),
      info_chip("pending cancels", summary.pending_cancel_count.to_string()),
      info_chip("events", summary.event_count.to_string()),
      info_chip("diffs pending", summary.pending_diff_count.to_string()),
      info_chip("tests verified", summary.verified_test_count.to_string()),
      info_chip("tool approvals", summary.pending_tool_approval_count.to_string()),
      info_chip("packages", summary.source_bound_package_count.to_string()),
    ]),
    div(class="mooncode-session-evidence", [
      info_row("Session", session.id),
      info_row("Snapshot", empty_label(summary.session_snapshot_path)),
      info_row("Command Log", empty_label(summary.command_log_path)),
      info_row("Runtime Feed", empty_label(summary.runtime_command_log_path)),
      info_row("Event Log", empty_label(summary.event_log_path)),
      info_row("Eval", "\{summary.eval_level} / \{summary.eval_score}"),
    ]),
    render_mooncode_resume_lifecycle(summary),
    render_mooncode_steering_lifecycle(summary),
    render_mooncode_cancel_lifecycle(summary),
    render_mooncode_patch_lifecycle(summary),
    render_mooncode_package_lifecycle(summary),
  ])
}

///|
fn render_mooncode_resume_lifecycle(
  summary : MoonCodeSummary
) -> @rabbita.Html {
  let lifecycle = summary.resume_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots resume-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "durable session resume"),
        h3("Resume Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip(
        "Snapshot",
        if json_field_bool(lifecycle, "snapshot_ready", default=false) {
          "ready"
        } else {
          "missing"
        },
      ),
      info_chip("Pending", json_field_int(lifecycle, "pending_count", default=0).to_string()),
      info_chip("Running", json_field_int(lifecycle, "running_count", default=0).to_string()),
      info_chip("Blocked", json_field_int(lifecycle, "blocked_count", default=0).to_string()),
      info_chip("Complete", json_field_int(lifecycle, "completed_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no runtime commands recorded for resume")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_resume_lifecycle_rows(rows).map(row =>
          render_mooncode_resume_lifecycle_row(row)
        ),
      )
    },
    div(class="mooncode-session-evidence", [
      info_row(
        "Snapshot",
        empty_label(json_field_string(lifecycle, "snapshot_path", default="")),
      ),
      info_row(
        "Runtime Feed",
        empty_label(json_field_string(lifecycle, "runtime_command_log_path", default="")),
      ),
      info_row(
        "Dispatch Log",
        empty_label(json_field_string(lifecycle, "runtime_dispatch_log_path", default="")),
      ),
      info_row(
        "Resume Modes",
        json_field_string_array_summary(lifecycle, "resume_modes", limit=3),
      ),
    ]),
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_resume_lifecycle_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_resume_lifecycle_row(row : Json) -> @rabbita.Html {
  let status = json_field_string(row, "status", default="pending")
  div(class="mooncode-review-item " + mooncode_resume_lifecycle_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(empty_label(json_field_string(row, "command_id", default=""))),
        small(
          json_field_string(row, "action", default="prompt") +
          " / " +
          json_field_string(row, "receipt_status", default="missing"),
        ),
      ]),
      span(class="record-kind", status),
    ]),
    div(class="mooncode-stats", [
      info_chip("Events", json_field_int(row, "scoped_event_count", default=0).to_string()),
      info_chip("Proof", json_field_int(row, "proof_event_count", default=0).to_string()),
      info_chip(
        "Wire",
        if json_field_bool(row, "valid_wire", default=false) {
          "valid"
        } else {
          "invalid"
        },
      ),
      info_chip(
        "Tools",
        if json_field_bool(row, "runtime_may_execute_tools", default=true) {
          "allowed"
        } else {
          "blocked"
        },
      ),
    ]),
    code(empty_label(json_field_string(row, "target", default=""))),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "next_step", default="")),
    ),
  ])
}

///|
fn mooncode_resume_lifecycle_class(status : String) -> String {
  match status {
    "completed" => "accepted"
    "failed"
    | "blocked-invalid"
    | "blocked-tool-authorization"
    | "blocked-missing-proof" => "rejected"
    "pending" | "running" | "dispatched" => "queued"
    _ => "queued"
  }
}

///|
fn render_mooncode_steering_lifecycle(
  summary : MoonCodeSummary
) -> @rabbita.Html {
  let lifecycle = summary.steering_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots steering-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "prompt/steer/cancel lifecycle"),
        h3("Steering Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Applied", json_field_int(lifecycle, "applied_count", default=0).to_string()),
      info_chip("Deferred", json_field_int(lifecycle, "deferred_count", default=0).to_string()),
      info_chip("Dropped", json_field_int(lifecycle, "dropped_count", default=0).to_string()),
      info_chip("Pending", json_field_int(lifecycle, "pending_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no steering commands recorded")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_steering_rows(rows).map(row =>
          render_mooncode_steering_lifecycle_row(row)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_steering_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_steering_lifecycle_row(row : Json) -> @rabbita.Html {
  let status = json_field_string(row, "status", default="pending")
  div(class="mooncode-review-item " + mooncode_steering_lifecycle_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(json_field_string(row, "command_id", default="steer")),
        small(empty_label(json_field_string(row, "settlement_kind", default=""))),
      ]),
      span(class="record-kind", status),
    ]),
    div(class="mooncode-stats", [
      info_chip(
        "Command",
        if json_field_bool(row, "command_recorded", default=false) {
          "recorded"
        } else {
          "missing"
        },
      ),
      info_chip(
        "Settlement",
        if json_field_bool(row, "settlement_recorded", default=false) {
          "recorded"
        } else {
          "pending"
        },
      ),
      info_chip(
        "Applied To",
        empty_label(json_field_string(row, "applied_to_command_id", default="")),
      ),
    ]),
    code(empty_label(json_field_string(row, "target", default=""))),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "message", default="")),
    ),
  ])
}

///|
fn mooncode_steering_lifecycle_class(status : String) -> String {
  match status {
    "applied" => "accepted"
    "deferred" | "pending" => "queued"
    "dropped" => "rejected"
    _ => "queued"
  }
}

///|
fn render_mooncode_cancel_lifecycle(
  summary : MoonCodeSummary
) -> @rabbita.Html {
  let lifecycle = summary.cancel_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots cancel-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "prompt/steer/cancel lifecycle"),
        h3("Cancel Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Cancelled", json_field_int(lifecycle, "cancelled_count", default=0).to_string()),
      info_chip("Dropped", json_field_int(lifecycle, "dropped_count", default=0).to_string()),
      info_chip("Failed", json_field_int(lifecycle, "failed_count", default=0).to_string()),
      info_chip("Pending", json_field_int(lifecycle, "pending_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no cancel commands recorded")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_cancel_rows(rows).map(row =>
          render_mooncode_cancel_lifecycle_row(row)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_cancel_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_cancel_lifecycle_row(row : Json) -> @rabbita.Html {
  let status = json_field_string(row, "status", default="pending")
  div(class="mooncode-review-item " + mooncode_cancel_lifecycle_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(json_field_string(row, "command_id", default="cancel")),
        small(empty_label(json_field_string(row, "settlement_kind", default=""))),
      ]),
      span(class="record-kind", status),
    ]),
    div(class="mooncode-stats", [
      info_chip(
        "Command",
        if json_field_bool(row, "command_recorded", default=false) {
          "recorded"
        } else {
          "missing"
        },
      ),
      info_chip(
        "Settlement",
        if json_field_bool(row, "settlement_recorded", default=false) {
          "recorded"
        } else {
          "pending"
        },
      ),
      info_chip(
        "Command Status",
        empty_label(json_field_string(row, "command_status", default="")),
      ),
    ]),
    code(empty_label(json_field_string(row, "target", default=""))),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "message", default="")),
    ),
  ])
}

///|
fn mooncode_cancel_lifecycle_class(status : String) -> String {
  match status {
    "cancelled" => "accepted"
    "dropped" | "failed" => "rejected"
    "pending" => "queued"
    _ => "queued"
  }
}

///|
fn render_mooncode_patch_lifecycle(summary : MoonCodeSummary) -> @rabbita.Html {
  let lifecycle = summary.patch_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots patch-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "diff review/runtime proof"),
        h3("Patch Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Patches", json_field_int(lifecycle, "patch_count", default=0).to_string()),
      info_chip("Needs Review", json_field_int(lifecycle, "needs_review_count", default=0).to_string()),
      info_chip("Runtime Needed", json_field_int(lifecycle, "runtime_needed_count", default=0).to_string()),
      info_chip("Runtime Proven", json_field_int(lifecycle, "runtime_proven_count", default=0).to_string()),
      info_chip("Blocked", json_field_int(lifecycle, "blocked_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no file diffs recorded for patch review")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_patch_lifecycle_rows(rows).map(row =>
          render_mooncode_patch_lifecycle_row(row)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_patch_lifecycle_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_patch_lifecycle_row(row : Json) -> @rabbita.Html {
  let gate = json_field_string(row, "gate_status", default="needs-review")
  div(class="mooncode-review-item " + mooncode_patch_lifecycle_class(gate), [
    div(class="mooncode-review-head", [
      div([
        strong(empty_label(json_field_string(row, "path", default=""))),
        small(
          json_field_string(row, "review_state", default="pending") +
          " / " +
          json_field_string(row, "execution_state", default="pending"),
        ),
      ]),
      span(class="record-kind", gate),
    ]),
    div(class="mooncode-stats", [
      info_chip("Next", empty_label(json_field_string(row, "next_action", default=""))),
      info_chip("Hunks", json_field_int(row, "hunk_count", default=0).to_string()),
      info_chip("Runtime", json_field_int(row, "runtime_proof_count", default=0).to_string()),
      info_chip(
        "Diff",
        if json_field_bool(row, "diff_present", default=false) {
          "yes"
        } else {
          "no"
        },
      ),
    ]),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "blocked_reason", default="")),
    ),
  ])
}

///|
fn mooncode_patch_lifecycle_class(status : String) -> String {
  match status {
    "runtime-proven" | "ready" => "accepted"
    "runtime-needed" | "needs-review" => "queued"
    "blocked" => "rejected"
    _ => "queued"
  }
}

///|
fn render_mooncode_package_lifecycle(
  summary : MoonCodeSummary
) -> @rabbita.Html {
  let lifecycle = summary.package_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots package-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "bundle/package assembly"),
        h3("Package Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Packages", json_field_int(lifecycle, "package_count", default=0).to_string()),
      info_chip("Source-bound", json_field_int(lifecycle, "source_bound_package_count", default=0).to_string()),
      info_chip("Missing Source", json_field_int(lifecycle, "missing_source_package_count", default=0).to_string()),
      info_chip("Executable-ready", json_field_int(lifecycle, "executable_ready_count", default=0).to_string()),
      info_chip("Runtime Verified", json_field_int(lifecycle, "runtime_verified_package_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no package candidates recorded")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_package_lifecycle_rows(rows).map(row =>
          render_mooncode_package_lifecycle_row(row)
        ),
      )
    },
    div(class="mooncode-session-evidence", [
      info_row(
        "Index",
        empty_label(json_field_string(lifecycle, "package_index_status", default="")),
      ),
      info_row(
        "Index Path",
        empty_label(json_field_string(lifecycle, "package_index_path", default="")),
      ),
      info_row(
        "Entry Points",
        json_field_string_array_summary(lifecycle, "entry_points", limit=3),
      ),
    ]),
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_package_lifecycle_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_package_lifecycle_row(row : Json) -> @rabbita.Html {
  let state = json_field_string(row, "execution_state", default="pending")
  div(class="mooncode-review-item " + mooncode_package_lifecycle_class(state), [
    div(class="mooncode-review-head", [
      div([
        strong(empty_label(json_field_string(row, "context_path", default=""))),
        small(
          json_field_string(row, "package_kind", default="package") +
          " / " +
          json_field_string(row, "source_inventory_status", default="unknown"),
        ),
      ]),
      span(class="record-kind", state),
    ]),
    div(class="mooncode-stats", [
      info_chip("Sources", json_field_int(row, "source_present_count", default=0).to_string()),
      info_chip("Promoted", json_field_int(row, "promoted_source_count", default=0).to_string()),
      info_chip("Runtime", json_field_int(row, "runtime_proof_count", default=0).to_string()),
      info_chip(
        "Verified",
        if json_field_bool(row, "execution_verified", default=false) {
          "yes"
        } else {
          "no"
        },
      ),
    ]),
    code(empty_label(json_field_string(row, "manifest_path", default=""))),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "next_runtime_step", default="")),
    ),
  ])
}

///|
fn mooncode_package_lifecycle_class(status : String) -> String {
  match status {
    "verified" => "accepted"
    "built" | "pending" => "queued"
    _ => "queued"
  }
}

///|
fn render_mooncode_transcript(
  model : Model,
  session : AgentSession,
) -> @rabbita.Html {
  let events = mooncode_transcript_events(model, session)
  if session.transcript.length() == 0 && events.length() == 0 {
    div(class="agent-empty", [
      h1(session.title),
      p(
        class="lead",
        "Start a MoonCode prompt to stream reasoning, tool calls, diffs, tests, and packaging evidence here.",
      ),
    ])
  } else {
    let children : Array[@rabbita.Html] = []
    for message in session.transcript {
      children.push(render_agent_message(message))
    }
    for event in events {
      children.push(render_mooncode_transcript_event(event))
    }
    div(class="agent-transcript mooncode-transcript", children)
  }
}

///|
fn render_agent_message(message : AgentMessage) -> @rabbita.Html {
  div(class="agent-message " + message.role + " " + message.status, [
    div(class="agent-message-head", [
      span(class="record-kind", message.role),
      small("\{message.status} / \{message.created_at}"),
    ]),
    pre(class="agent-message-body", code(message.content)),
  ])
}

///|
fn mooncode_transcript_events(
  model : Model,
  session : AgentSession,
) -> Array[MoonCodeEvent] {
  let events = mooncode_merge_stream_events(session.mooncode_events, [])
  let with_stream = if model.mooncode_stream_session_id == session.id {
    mooncode_merge_stream_events(events, model.mooncode_stream_events)
  } else {
    events
  }
  match model.mooncode_runtime_event_sink {
    Some(sink) if model.mooncode_runtime_event_sink_session_id == session.id =>
      mooncode_merge_stream_events(with_stream, sink.events)
    _ => with_stream
  }
}

///|
fn render_mooncode_transcript_event(event : MoonCodeEvent) -> @rabbita.Html {
  let message_class = "agent-message mooncode-transcript-event " +
    mooncode_transcript_event_class(event)
  div(class=message_class, [
    div(class="agent-message-head", [
      span(class="record-kind", event.lane),
      small("\{event.status} / \{event.created_at}"),
    ]),
    div(class="mooncode-transcript-event-title", [
      strong(event.title),
      if event.command == "" {
        span(class="hidden-inline", "")
      } else {
        code(event.command)
      },
    ]),
    if event.path == "" {
      span(class="hidden-inline", "")
    } else {
      code(class="mooncode-transcript-path", event.path)
    },
    if event.diff != "" {
      pre(class="source-block compact", code(event.diff))
    } else {
      pre(
        class="agent-message-body",
        code(
          if event.detail == "" {
            mooncode_transcript_event_fallback_detail(event)
          } else {
            event.detail
          },
        ),
      )
    },
  ])
}

///|
fn mooncode_transcript_event_class(event : MoonCodeEvent) -> String {
  let lane = if event.lane == "" {
    "runtime"
  } else {
    event.lane
  }
  let state = if event.status == "failed" || event.status == "blocked" {
    "failed"
  } else {
    event.status
  }
  "\{lane} \{state}"
}

///|
fn mooncode_transcript_event_fallback_detail(event : MoonCodeEvent) -> String {
  let mut detail = if event.kind == "" {
    "MoonCode runtime event"
  } else {
    event.kind
  }
  if event.exit_code != 0 {
    detail = "\{detail}\nexit code: \{event.exit_code}"
  }
  detail
}

///|
fn mooncode_replace_command_preflight(
  preflights : Array[MoonCodeCommandPreflight],
  preflight : MoonCodeCommandPreflight,
) -> Array[MoonCodeCommandPreflight] {
  let next : Array[MoonCodeCommandPreflight] = []
  let mut replaced = false
  for existing in preflights {
    if existing.action == preflight.action {
      next.push(preflight)
      replaced = true
    } else {
      next.push(existing)
    }
  }
  if !replaced {
    next.push(preflight)
  }
  next
}

///|
fn mooncode_preflight_status(preflights : Array[MoonCodeCommandPreflight]) -> String {
  if preflights.length() == 0 {
    return "preflight idle"
  }
  let mut blocked = 0
  for preflight in preflights {
    if preflight.blocked {
      blocked += 1
    }
  }
  if blocked == 0 {
    "\{preflights.length()} gate(s) ready"
  } else {
    "\{blocked} blocked / \{preflights.length()} gate(s)"
  }
}

///|
fn render_mooncode_preflight_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board preflight-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "server-side gates"),
        h3("Preflight Gates"),
      ]),
      span(class="record-kind", model.mooncode_preflight_status),
    ]),
    if model.mooncode_preflights.length() == 0 {
      p(class="muted", "Select a MoonCode session to load command gates.")
    } else {
      div(
        class="mooncode-review-list",
        model.mooncode_preflights.map(preflight =>
          render_mooncode_preflight_item(dispatch, preflight)
        ),
      )
    },
  ])
}

///|
fn render_mooncode_preflight_item(
  dispatch : Dispatch[Msg],
  preflight : MoonCodeCommandPreflight,
) -> @rabbita.Html {
  let state = if preflight.blocked { "failed" } else { "approved" }
  div(class="mooncode-review-item " + state, [
    div(class="mooncode-review-head", [
      div([
        strong(preflight.title),
        small(
          if preflight.context_path == "" {
            "this MoonBook code workspace"
          } else {
            preflight.context_path
          },
        ),
      ]),
      span(
        class="record-kind",
        if preflight.blocked { "blocked" } else { "ready" },
      ),
    ]),
    p(
      class="mooncode-event-detail",
      if preflight.blocked {
        preflight.reason
      } else {
        "Ready to dispatch with the current MoonBook evidence."
      },
    ),
    div(class="mooncode-stats", [
      info_chip("dispatch", preflight.dispatch),
      info_chip("approval", preflight.approval),
      info_chip("lane", preflight.lane),
      info_chip(
        "failing tests",
        if preflight.acceptance_gates.no_failing_tests { "clear" } else { "blocked" },
      ),
      info_chip(
        "verified tests",
        if preflight.acceptance_gates.has_verified_tests { "ready" } else { "missing" },
      ),
      info_chip(
        "tool approvals",
        if preflight.acceptance_gates.tool_approvals_resolved { "clear" } else { "pending" },
      ),
      info_chip(
        "diffs",
        if preflight.acceptance_gates.diffs_resolved { "resolved" } else { "pending" },
      ),
      info_chip(
        "package",
        if preflight.acceptance_gates.has_source_bound_package { "source-bound" } else { "missing" },
      ),
    ]),
    div(class="daemon-state compact-state", [
      info_row("Expected Lanes", string_list_label(preflight.expected_lanes)),
      info_row("Tool Hints", string_list_label(preflight.tool_hints)),
      info_row("Required Gates", string_list_label(preflight.required_gates)),
    ]),
    render_mooncode_preflight_selected_patch(preflight.selected_patch),
    div(class="toolbar-actions", [
      button(
        class=if preflight.blocked { "secondary-button" } else { "primary-button" },
        on_click=if preflight.context_path == "" {
          if preflight.blocked {
            dispatch(RunMoonCodeCommandOverride(preflight.action, ""))
          } else {
            dispatch(RunMoonCodeCommand(preflight.action))
          }
        } else {
          if preflight.blocked {
            dispatch(
              RunMoonCodeCommandOverride(
                preflight.action, preflight.context_path,
              ),
            )
          } else {
            dispatch(
              RunMoonCodeCommandForPath(
                preflight.action, preflight.context_path,
              ),
            )
          }
        },
        if preflight.blocked { "Try Anyway" } else { "Run" },
      ),
    ]),
  ])
}

///|
fn render_mooncode_preflight_selected_patch(
  selected : MoonCodeSelectedPatchPreflight,
) -> @rabbita.Html {
  if !selected.matched {
    span(class="hidden-inline", "")
  } else {
    div(class="daemon-state compact-state mooncode-selected-patch", [
      info_row("Patch Target", selected.context_path),
      info_row("Review", empty_label(selected.review_state)),
      info_row("Execution", empty_label(selected.execution_state)),
      info_row("Gate", empty_label(selected.gate_status)),
      info_row("Next", empty_label(selected.next_action)),
      info_row(
        "Runtime Proof",
        if selected.runtime_proven { "recorded" } else { "missing" },
      ),
      if selected.blocked_reason == "" {
        span(class="hidden-inline", "")
      } else {
        p(class="mooncode-event-detail", selected.blocked_reason)
      },
    ])
  }
}

///|
fn render_mooncode_command_queue_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board command-queue-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "ordered command queue"),
        h3("Command Queue"),
      ]),
      span(class="record-kind", model.mooncode_command_queue_status),
    ]),
    match model.mooncode_command_queue {
      Some(queue) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", queue.command_count.to_string()),
            info_chip("Prompts", mooncode_command_queue_count(queue, "prompt").to_string()),
            info_chip("Steers", mooncode_command_queue_count(queue, "steer").to_string()),
            info_chip("Pending Steers", mooncode_pending_steer_count(model, queue.session_id).to_string()),
            info_chip("Cancels", mooncode_command_queue_count(queue, "cancel").to_string()),
            info_chip("Reviews", mooncode_command_queue_review_count(queue).to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Queue", queue.command_log_path),
            info_row("Session", queue.session_id),
            info_row("Task", empty_label(queue.task_id)),
            info_row("Ordering", queue.ordering_rule),
          ]),
          div(class="toolbar-actions", [
            button(
              class="secondary-button",
              on_click=dispatch(RunMoonCodeCommand("steer")),
              "Steer",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(RunMoonCodeCommand("cancel")),
              "Cancel",
            ),
          ]),
          mooncode_pending_steer_status_line(model, queue.session_id),
          if queue.commands.length() == 0 {
            p(class="status-line", "no command packets recorded")
          } else {
            div(
              class="mooncode-review-list command-queue-list",
              mooncode_recent_commands(queue.commands).map(command =>
                render_mooncode_queued_command(dispatch, command)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonCode command queue has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_recent_commands(
  commands : Array[MoonCodeQueuedCommand]
) -> Array[MoonCodeQueuedCommand] {
  let recent : Array[MoonCodeQueuedCommand] = []
  let mut index = commands.length()
  let mut emitted = 0
  while index > 0 && emitted < 8 {
    index -= 1
    recent.push(commands[index])
    emitted += 1
  }
  recent
}

///|
fn mooncode_command_queue_count(
  queue : MoonCodeCommandQueue,
  action : String,
) -> Int {
  let mut count = 0
  for command in queue.commands {
    if command.action == action {
      count += 1
    }
  }
  count
}

///|
fn mooncode_pending_steer_count(model : Model, session_id : String) -> Int {
  let steer_count = match model.mooncode_command_queue {
    Some(queue) if queue.session_id == session_id =>
      mooncode_command_queue_count(queue, "steer")
    _ => 0
  }
  let settled_count = mooncode_steer_settlement_count(model, session_id)
  if steer_count > settled_count {
    steer_count - settled_count
  } else {
    0
  }
}

///|
fn mooncode_pending_steer_label(model : Model, session_id : String) -> String {
  let count = mooncode_pending_steer_count(model, session_id)
  if count == 0 {
    "settled"
  } else if count == 1 {
    "1 pending"
  } else {
    "\{count} pending"
  }
}

///|
fn mooncode_summary_pending_steer_label(summary : MoonCodeSummary) -> String {
  let count = summary.pending_steer_count
  if count == 0 {
    "settled"
  } else if count == 1 {
    "1 pending"
  } else {
    "\{count} pending"
  }
}

///|
fn mooncode_pending_steer_status_line(
  model : Model,
  session_id : String,
) -> @rabbita.Html {
  let count = mooncode_pending_steer_count(model, session_id)
  if count == 0 {
    @html.nothing
  } else {
    p(
      class="status-line",
      "\{count} steer request(s) are waiting for runtime apply/defer/drop confirmation.",
    )
  }
}

///|
fn mooncode_steer_settlement_count(model : Model, session_id : String) -> Int {
  match model.mooncode_runtime_event_sink {
    Some(sink) if model.mooncode_runtime_event_sink_session_id == session_id =>
      mooncode_steer_settlement_count_from_events(sink.events)
    _ =>
      if model.mooncode_stream_session_id == session_id {
        mooncode_steer_settlement_count_from_events(model.mooncode_stream_events)
      } else {
        0
      }
  }
}

///|
fn mooncode_steer_settlement_count_from_events(events : Array[MoonCodeEvent]) -> Int {
  let mut count = 0
  for event in events {
    if mooncode_event_settles_steer(event) {
      count += 1
    }
  }
  count
}

///|
fn mooncode_event_settles_steer(event : MoonCodeEvent) -> Bool {
  let text = (event.kind + "\n" + event.title + "\n" + event.detail).to_lower()
  text.contains("steer_applied") ||
  text.contains("steer applied") ||
  text.contains("steer_dropped") ||
  text.contains("steer dropped")
}

///|
fn mooncode_command_queue_review_count(queue : MoonCodeCommandQueue) -> Int {
  let mut count = 0
  for command in queue.commands {
    if command.approval == "operator" {
      count += 1
    }
  }
  count
}

///|
fn render_mooncode_queued_command(
  dispatch : Dispatch[Msg],
  command : MoonCodeQueuedCommand,
) -> @rabbita.Html {
  div(class="mooncode-review-item " + mooncode_command_queue_item_state(command), [
    div(class="mooncode-review-head", [
      div([
        strong(command.action + " -> " + command.dispatch),
        small(command.approval + " / " + command.created_at),
      ]),
      div(class="toolbar-actions", [
        if command.context_path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(command.context_path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_tests", command.target)),
          "Test",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_build", command.target)),
          "Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("package", command.target)),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("commit", command.target)),
          "Commit",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Lanes", command.expected_lanes.length().to_string()),
      info_chip("Tools", command.tool_hints.length().to_string()),
      info_chip("Web", if command.web_search { "on" } else { "off" }),
    ]),
    if command.context_path == "" {
      code(command.target)
    } else {
      code(command.context_path)
    },
    p(class="mooncode-event-detail", command.message),
    small(class="status-line", command.command_id),
  ])
}

///|
fn mooncode_command_queue_item_state(command : MoonCodeQueuedCommand) -> String {
  match command.action {
    "cancel" => "rejected"
    "accept" | "approve_tool" | "apply_patch" => "accepted"
    "reject" | "reject_tool" | "revert_patch" => "rejected"
    "run_tests" | "run_build" | "run_eval" => "running"
    "package" => "pending"
    _ => "queued"
  }
}

///|
fn render_mooncode_runtime_command_feed_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-command-feed-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "engine-facing command feed"),
        h3("Runtime Feed"),
      ]),
      span(class="record-kind", model.mooncode_runtime_command_feed_status),
    ]),
    match model.mooncode_runtime_command_feed {
      Some(feed) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", feed.runtime_command_count.to_string()),
            info_chip("Receipts", feed.runtime_dispatch_count.to_string()),
            info_chip("Pending", feed.runtime_dispatch_pending_count.to_string()),
            info_chip("Summaries", feed.execution_summaries.length().to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Runtime Feed", feed.runtime_command_log_path),
            info_row("Dispatch Log", feed.runtime_dispatch_log_path),
            info_row("Claim Endpoint", feed.runtime_claim_endpoint),
            info_row("Task", empty_label(feed.task_id)),
          ]),
          render_mooncode_runtime_command_lifecycle(feed.command_lifecycle),
          if feed.commands.length() == 0 {
            p(class="status-line", "no runtime commands have been recorded")
          } else {
            div(
              class="mooncode-review-list runtime-command-feed-list",
              mooncode_recent_runtime_commands(feed.commands).map(command =>
                render_mooncode_runtime_command_feed_item(command)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime command feed has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_recent_runtime_commands(commands : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = commands.length()
  let mut emitted = 0
  while index > 0 && emitted < 8 {
    index -= 1
    recent.push(commands[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_runtime_command_lifecycle(
  lifecycle : Json
) -> @rabbita.Html {
  let commands = json_field_json_array_items(lifecycle, "commands")
  div(class="mooncode-output-roots", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "runtime command lifecycle"),
        h3("Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "next_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Pending", json_field_int(lifecycle, "pending_count", default=0).to_string()),
      info_chip("Running", json_field_int(lifecycle, "running_count", default=0).to_string()),
      info_chip("Dispatched", json_field_int(lifecycle, "dispatched_count", default=0).to_string()),
      info_chip("Completed", json_field_int(lifecycle, "completed_count", default=0).to_string()),
      info_chip("Failed", json_field_int(lifecycle, "failed_count", default=0).to_string()),
      info_chip("Blocked", json_field_int(lifecycle, "blocked_count", default=0).to_string()),
    ]),
    div(class="daemon-state compact-state", [
      info_row("Next Command", empty_label(json_field_string(lifecycle, "next_command_id", default=""))),
      info_row("Next Action", empty_label(json_field_string(lifecycle, "next_action", default=""))),
      info_row("Scoped Events", json_field_int(lifecycle, "scoped_event_count", default=0).to_string()),
    ]),
    if commands.length() == 0 {
      p(class="status-line", "no lifecycle rows yet")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_runtime_lifecycle_commands(commands).map(command =>
          render_mooncode_runtime_lifecycle_item(command)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "rule", default=""),
    ),
  ])
}

///|
fn mooncode_recent_runtime_lifecycle_commands(
  commands : Array[Json]
) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = commands.length()
  let mut emitted = 0
  while index > 0 && emitted < 6 {
    index -= 1
    recent.push(commands[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_runtime_lifecycle_item(command : Json) -> @rabbita.Html {
  let status = json_field_string(command, "status", default="pending")
  div(class="mooncode-review-item " + mooncode_runtime_lifecycle_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(
          json_field_string(command, "action", default="prompt") +
          " -> " +
          status,
        ),
        small(json_field_string(command, "receipt_status", default="missing")),
      ]),
      span(
        class=if json_field_bool(command, "valid_wire", default=false) {
          "record-kind good"
        } else {
          "record-kind warning"
        },
        if json_field_bool(command, "valid_wire", default=false) {
          "wire ok"
        } else {
          "wire blocked"
        },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Proof", json_field_int(command, "proof_event_count", default=0).to_string()),
      info_chip("Events", json_field_int(command, "scoped_event_count", default=0).to_string()),
      info_chip("Running", json_field_int(command, "running_event_count", default=0).to_string()),
      info_chip("Failed", json_field_int(command, "failed_event_count", default=0).to_string()),
      info_chip("Auth", empty_label(json_field_string(command, "tool_authorization_state", default=""))),
    ]),
    code(json_field_string(command, "command_id", default="")),
    p(
      class="mooncode-event-detail",
      mooncode_runtime_lifecycle_detail(command),
    ),
  ])
}

///|
fn mooncode_runtime_lifecycle_detail(command : Json) -> String {
  let blocker = json_field_string(command, "blocking_reason", default="")
  if blocker != "" {
    return blocker
  }
  let latest = json_field_string(command, "latest_event_title", default="")
  let step = json_field_string(command, "next_step", default="")
  if latest != "" {
    latest + " / " + step
  } else {
    step
  }
}

///|
fn mooncode_runtime_lifecycle_class(status : String) -> String {
  match status {
    "completed" => "accepted"
    "failed" | "blocked-invalid" | "blocked-tool-authorization" => "rejected"
    "running" | "dispatched" => "running"
    _ => "queued"
  }
}

///|
fn render_mooncode_runtime_replay_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-replay-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "OpenSeek serve replay"),
        h3("Runtime Replay"),
      ]),
      span(class="record-kind", model.mooncode_runtime_replay_status),
    ]),
    match model.mooncode_runtime_replay {
      Some(state) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", state.command_count.to_string()),
            info_chip("Pending", state.pending_command_count.to_string()),
            info_chip("Delivered", state.delivered_command_count.to_string()),
            info_chip("Claimed", state.claimed_command_count.to_string()),
            info_chip("Failed", state.failed_dispatch_count.to_string()),
            info_chip("Invalid", state.invalid_command_count.to_string()),
            info_chip("Replay", if state.replay_ready { "ready" } else { "idle" }),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Runtime Feed", state.runtime_command_log_path),
            info_row("Dispatch Log", state.runtime_dispatch_log_path),
            info_row("First Pending", state.first_pending_index.to_string()),
            info_row("First Invalid", empty_label(state.first_invalid_command_id)),
          ]),
          if state.pending_openseek_jsonl == "" {
            p(class="status-line", "no pending OpenSeek JSONL commands")
          } else {
            div(class="mooncode-output-roots", [
              small("Pending OpenSeek JSONL"),
              pre(
                class="source-block compact",
                code(state.pending_openseek_jsonl),
              ),
            ])
          },
          if state.pending_commands.length() == 0 {
            p(class="status-line", "runtime replay has no pending commands")
          } else {
            div(
              class="mooncode-review-list runtime-replay-list",
              mooncode_recent_replay_items(state.pending_commands).map(item =>
                render_mooncode_runtime_replay_item(item)
              ),
            )
          },
          small(class="status-line", state.replay_policy),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime replay state has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_recent_replay_items(
  items : Array[MoonCodeRuntimeReplayItem]
) -> Array[MoonCodeRuntimeReplayItem] {
  let recent : Array[MoonCodeRuntimeReplayItem] = []
  let mut index = 0
  while index < items.length() && recent.length() < 8 {
    recent.push(items[index])
    index += 1
  }
  recent
}

///|
fn render_mooncode_runtime_replay_item(
  item : MoonCodeRuntimeReplayItem
) -> @rabbita.Html {
  let wire_ok = json_field_bool(item.decode_report, "ok", default=false)
  div(class="mooncode-review-item " + mooncode_runtime_replay_item_class(item), [
    div(class="mooncode-review-head", [
      div([
        strong(item.action + " -> " + item.replay_status),
        small(item.serve_command + " / " + item.created_at),
      ]),
      span(
        class=if wire_ok { "record-kind good" } else { "record-kind warning" },
        if wire_ok { "wire valid" } else { "decode error" },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Receipt", item.receipt_status),
      info_chip("Dispatch", item.dispatch),
      info_chip(
        "Lease",
        if item.previous_claim_expired { "expired" } else { "current" },
      ),
      info_chip("Proof", item.proof_event_count.to_string()),
      info_chip("Events", item.normalized_event_count.to_string() + "/" + item.submitted_event_count.to_string()),
    ]),
    render_mooncode_runtime_proof_gate(
      json_field(item.latest_receipt, "proof_gate"),
    ),
    if item.target == "" {
      code(item.command_id)
    } else {
      code(item.target)
    },
    p(
      class="mooncode-event-detail",
      if wire_ok {
        mooncode_runtime_replay_item_detail(item)
      } else {
        json_field_string(item.decode_report, "error", default="Invalid wire command")
      },
    ),
    small(class="status-line", item.command_id),
  ])
}

///|
fn mooncode_runtime_replay_item_detail(
  item : MoonCodeRuntimeReplayItem
) -> String {
  let proof_gate = json_field(item.latest_receipt, "proof_gate")
  let proof_status = mooncode_runtime_proof_gate_status(proof_gate)
  if item.replay_status == "missing-proof-pending-retry" ||
    item.receipt_status == "proof-missing" {
    let missing = mooncode_runtime_proof_gate_missing_label(proof_gate)
    if missing == "" {
      "Runtime requested completion, but required command-scoped proof is missing."
    } else {
      "Runtime requested completion, but missing proof: " + missing
    }
  } else if proof_status == "passed" {
    "Runtime completion proof gate passed."
  } else if item.proof_event_count > 0 {
    let lanes = json_field_string_array_items(
      item.runtime_event_summary, "proof_lanes",
    )
    if lanes.length() > 0 {
      "Runtime acknowledgement submitted proof lanes: " + lanes.join(", ")
    } else {
      "Runtime acknowledgement submitted \{item.proof_event_count.to_string()} proof event(s)."
    }
  } else if item.replay_status == "delivered" {
    "Delivered without attached proof events; inspect runtime logs or eval evidence if review gates remain blocked."
  } else {
    "Ready for a MoonClaw or standalone MoonCode runtime consumer."
  }
}

///|
fn mooncode_runtime_replay_item_class(item : MoonCodeRuntimeReplayItem) -> String {
  match item.replay_status {
    "delivered" => "accepted"
    "claimed" => "running"
    "pending" | "failed-pending-retry" | "expired-claim-pending-retry" =>
      "queued"
    "missing-proof-pending-retry" => "rejected"
    "blocked-invalid" => "rejected"
    _ => "queued"
  }
}

///|
fn render_mooncode_runtime_event_sink_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-event-sink-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "runtime event ingress"),
        h3("Runtime Events"),
      ]),
      span(class="record-kind", model.mooncode_runtime_event_sink_status),
    ]),
    match model.mooncode_runtime_event_sink {
      Some(sink) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Events", sink.event_count.to_string()),
            info_chip(
              "Payloads",
              json_field_string_array_items(
                sink.post_contract, "accepted_payloads",
              ).length().to_string(),
            ),
            info_chip(
              "Producer",
              json_field_string(
                sink.post_contract, "producer", default="moonclaw",
              ),
            ),
            info_chip(
              "Commands",
              json_field_int(
                sink.command_progress, "command_count", default=0,
              ).to_string(),
            ),
            info_chip(
              "Scoped",
              json_field_int(
                sink.command_progress, "scoped_event_count", default=0,
              ).to_string(),
            ),
            info_chip(
              "Unscoped",
              json_field_int(
                sink.unscoped_progress, "event_count", default=0,
              ).to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Event Log", sink.event_log_path),
            info_row(
              "Post Endpoint",
              json_field_string(sink.post_contract, "endpoint", default=""),
            ),
            info_row(
              "Method",
              json_field_string(sink.post_contract, "method", default="POST"),
            ),
            info_row(
              "Ordering",
              json_field_string(sink.post_contract, "ordering_rule", default=""),
            ),
          ]),
          div(class="mooncode-output-roots", [
            small("Accepted payloads"),
            p(
              json_field_string_array_items(
                sink.post_contract, "accepted_payloads",
              ).join("; "),
            ),
          ]),
          p(
            class="mooncode-event-detail",
            json_field_string(sink.post_contract, "normalization", default=""),
          ),
          render_mooncode_runtime_event_command_progress(sink.command_progress),
          render_mooncode_runtime_unscoped_progress(sink.unscoped_progress),
          if sink.events.length() == 0 {
            p(class="status-line", "no durable runtime events recorded")
          } else {
            div(
              class="mooncode-event-list compact",
              mooncode_recent_runtime_sink_events(sink.events).map(event =>
                render_mooncode_event(event)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime event sink has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_runtime_event_command_progress(
  progress : Json
) -> @rabbita.Html {
  let commands = json_field_json_array_items(progress, "commands")
  div(class="mooncode-review-board embedded-board", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "command-scoped runtime proof"),
        h3("Command Progress"),
      ]),
      span(
        class="record-kind",
        json_field_int(progress, "command_count", default=0).to_string() +
        " command(s)",
      ),
    ]),
    if commands.length() == 0 {
      p(
        class="status-line",
        "no command-scoped runtime events have been recorded",
      )
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_runtime_command_progress(commands).map(command =>
          render_mooncode_runtime_command_progress_item(command)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(progress, "rule", default=""),
    ),
  ])
}

///|
fn render_mooncode_runtime_unscoped_progress(
  progress : Json
) -> @rabbita.Html {
  let events = json_field_json_array_items(progress, "recent_events")
  div(class="mooncode-review-board embedded-board", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "live events without command proof"),
        h3("Unscoped Live Events"),
      ]),
      span(
        class=if json_field_int(progress, "event_count", default=0) > 0 {
          "record-kind warning"
        } else {
          "record-kind"
        },
        json_field_int(progress, "event_count", default=0).to_string() +
        " event(s)",
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Running", json_field_int(progress, "running_event_count", default=0).to_string()),
      info_chip("Done", json_field_int(progress, "done_event_count", default=0).to_string()),
      info_chip("Failed", json_field_int(progress, "failed_event_count", default=0).to_string()),
      info_chip("Tools", json_field_int(progress, "tool_event_count", default=0).to_string()),
      info_chip("Transcript", json_field_int(progress, "transcript_event_count", default=0).to_string()),
    ]),
    div(class="daemon-state compact-state", [
      info_row("Latest", empty_label(json_field_string(progress, "latest_title", default=""))),
      info_row("Latest Status", empty_label(json_field_string(progress, "latest_status", default=""))),
      info_row("Lanes", json_field_string_array_items(progress, "lanes").join(", ")),
    ]),
    if events.length() == 0 {
      p(class="status-line", "no unscoped live runtime events")
    } else {
      div(
        class="mooncode-review-list compact",
        events.map(event => render_mooncode_runtime_unscoped_event_item(event)),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(progress, "rule", default=""),
    ),
  ])
}

///|
fn render_mooncode_runtime_unscoped_event_item(event : Json) -> @rabbita.Html {
  let status = json_field_string(event, "status", default="done")
  div(class="mooncode-review-item " + mooncode_runtime_command_progress_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(
          json_field_string(event, "lane", default="runtime") +
          " -> " +
          json_field_string(event, "kind", default="event"),
        ),
        small(empty_label(json_field_string(event, "created_at", default=""))),
      ]),
      span(class="record-kind", empty_label(json_field_string(event, "id", default=""))),
    ]),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(event, "title", default="")) +
      " / " +
      empty_label(json_field_string(event, "detail", default="")),
    ),
  ])
}

///|
fn mooncode_recent_runtime_command_progress(
  commands : Array[Json]
) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = commands.length()
  let mut emitted = 0
  while index > 0 && emitted < 6 {
    index -= 1
    recent.push(commands[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_runtime_command_progress_item(command : Json) -> @rabbita.Html {
  let status = json_field_string(command, "status", default="idle")
  div(class="mooncode-review-item " + mooncode_runtime_command_progress_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(
          json_field_string(command, "action", default="prompt") +
          " -> " +
          status,
        ),
        small(empty_label(json_field_string(command, "latest_created_at", default=""))),
      ]),
      span(class="record-kind", json_field_string(command, "latest_event_id", default="event")),
    ]),
    div(class="mooncode-stats", [
      info_chip("Events", json_field_int(command, "event_count", default=0).to_string()),
      info_chip("Running", json_field_int(command, "running_event_count", default=0).to_string()),
      info_chip("Done", json_field_int(command, "done_event_count", default=0).to_string()),
      info_chip("Failed", json_field_int(command, "failed_event_count", default=0).to_string()),
      info_chip("Tools", "\{json_field_int(command, "tool_call_count", default=0)}/\{json_field_int(command, "tool_result_count", default=0)}"),
    ]),
    code(json_field_string(command, "command_id", default="")),
    p(
      class="mooncode-event-detail",
      "lanes " +
      json_field_string_array_items(command, "lanes").join(", ") +
      "; latest " +
      empty_label(json_field_string(command, "latest_title", default="")),
    ),
  ])
}

///|
fn mooncode_runtime_command_progress_class(status : String) -> String {
  match status {
    "done" => "accepted"
    "failed" => "rejected"
    "running" => "running"
    _ => "queued"
  }
}

///|
fn mooncode_recent_runtime_sink_events(
  events : Array[MoonCodeEvent]
) -> Array[MoonCodeEvent] {
  let recent : Array[MoonCodeEvent] = []
  let mut index = events.length()
  let mut emitted = 0
  while index > 0 && emitted < 8 {
    index -= 1
    recent.push(events[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_runtime_command_feed_item(command : Json) -> @rabbita.Html {
  let action = json_field_string(command, "action", default="command")
  let dispatch = json_field_string(command, "dispatch", default="prompt")
  let command_id = json_field_string(command, "command_id", default="")
  let target = json_field_string(command, "target", default="")
  let auth_state = mooncode_command_tool_authorization_state(command)
  div(class="mooncode-review-item " + mooncode_runtime_command_feed_item_class(command), [
    div(class="mooncode-review-head", [
      div([
        strong(action + " -> " + dispatch),
        small(json_field_string(command, "created_at", default="")),
      ]),
      span(
        class=if json_field_bool(command, "openseek_wire_valid", default=false) {
          "record-kind good"
        } else {
          "record-kind"
        },
        if json_field_bool(command, "openseek_wire_valid", default=false) {
          "wire valid"
        } else {
          "wire invalid"
        },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Approval", json_field_string(command, "approval", default="none")),
      info_chip("Auth", if auth_state == "" { "unknown" } else { auth_state }),
      info_chip("Serve", json_field_string(command, "serve_command", default="")),
      info_chip(
        "Native",
        if json_field_string(command, "native_mooncode_endpoint", default="") == "" {
          "none"
        } else {
          "ready"
        },
      ),
    ]),
    if target == "" {
      code(command_id)
    } else {
      code(target)
    },
    render_mooncode_runtime_execution_summary(command),
    small(class="status-line", command_id),
  ])
}

///|
fn mooncode_command_tool_authorization_state(command : Json) -> String {
  let direct = json_field_string(command, "tool_authorization_state", default="")
  if direct != "" {
    return direct
  }
  match json_field(command, "tool_authorization") {
    Some(auth) => json_field_string(auth, "enforcement_state", default="")
    None => ""
  }
}

///|
fn mooncode_runtime_command_feed_item_class(command : Json) -> String {
  match json_field_string(command, "action", default="") {
    "cancel" => "rejected"
    "run_tests" | "run_build" | "run_eval" => "running"
    "package" => "pending"
    "accept" | "approve_tool" | "apply_patch" => "accepted"
    "reject" | "reject_tool" | "revert_patch" => "rejected"
    _ => "queued"
  }
}

///|
fn render_mooncode_action_plan_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board action-plan-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "execution and review plan"),
        h3("Action Plan"),
      ]),
      span(class="record-kind", model.mooncode_action_plan_status),
    ]),
    match model.mooncode_action_plan {
      Some(plan) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Actions", plan.action_count.to_string()),
            info_chip("Pending runtime", plan.pending_runtime_count.to_string()),
            info_chip("Running", plan.running_count.to_string()),
            info_chip("Blocked", plan.blocked_count.to_string()),
            info_chip("Ready review", plan.ready_for_review_count.to_string()),
            info_chip("Completed", plan.completed_count.to_string()),
            info_chip("Tests", plan.run_test_command_count.to_string()),
            info_chip("Packages", plan.package_command_count.to_string()),
            info_chip("Commits", plan.commit_command_count.to_string()),
            info_chip("Deferred Steers", plan.deferred_steer_count.to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Status", plan.status),
            info_row("Next", plan.next_required_action),
            info_row(
              "Production Next",
              json_string_value(
                plan.production_readiness,
                "next_action",
                default=plan.next_required_action,
              ),
            ),
            info_row(
              "Production Owner",
              json_string_value(
                plan.production_readiness,
                "next_owner",
                default="mooncode",
              ),
            ),
            info_row(
              "Production Blocker",
              json_string_value(
                plan.production_readiness,
                "first_blocker_label",
                default="none",
              ),
            ),
            info_row("Manifest", empty_label(plan.manifest_path)),
            info_row("Recorded", empty_label(plan.recorded_at)),
            info_row("Task", empty_label(plan.task_id)),
          ]),
          render_mooncode_action_plan_recommended_command(dispatch, plan),
          render_mooncode_action_plan_gates(plan.acceptance_gates),
          if plan.actions.length() == 0 {
            p(class="status-line", "no MoonCode actions queued yet")
          } else {
            div(
              class="mooncode-review-list action-plan-list",
              plan.actions[:mooncode_action_plan_limit(plan.actions)].map(action =>
                render_mooncode_action_plan_item(dispatch, action)
              ),
            )
          },
          p(class="mooncode-event-detail", plan.rule),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode action plan has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_action_plan_recommended_command(
  dispatch : Dispatch[Msg],
  plan : MoonCodeActionPlan,
) -> @rabbita.Html {
  let commands = if plan.recommended_commands.length() > 0 {
    plan.recommended_commands
  } else if plan.recommended_command.available {
    [plan.recommended_command]
  } else {
    []
  }
  if commands.length() > 0 {
    let children : Array[@rabbita.Html] = []
    for index, command in commands {
      if command.available && command.action != "" && command.label != "" {
        children.push(
          button(
            class=if index == 0 { "primary-button" } else { "secondary-button" },
            on_click=dispatch(
              mooncode_recommended_command_message(command),
            ),
            command.label,
          ),
        )
      }
    }
    children.push(span(class="status-line", plan.next_required_action))
    div(class="toolbar-actions action-plan-actions", children)
  } else {
    span(class="hidden-inline", "")
  }
}

///|
fn mooncode_recommended_command_message(
  command : MoonCodeActionPlanRecommendedCommand
) -> Msg {
  match command.ui_action {
    "runtime_loop" => RunMoonCodeRuntimeLoop
    "runtime_service" => StartMoonCodeRuntimeService
    _ =>
      RunMoonCodeCommandWithMessage(
        command.action,
        command.context_path,
        command.message,
        command.status,
      )
  }
}

///|
fn render_mooncode_action_plan_gates(
  gates : MoonCodeActionPlanGates
) -> @rabbita.Html {
  div(class="mooncode-stats gate-stats", [
    info_chip("No failing tests", if gates.no_failing_tests { "yes" } else { "no" }),
    info_chip("Verified tests", if gates.has_verified_tests { "yes" } else { "no" }),
    info_chip(
      "Tool approvals",
      if gates.tool_approvals_resolved { "resolved" } else { "pending" },
    ),
    info_chip("Diffs", if gates.diffs_resolved { "resolved" } else { "pending" }),
    info_chip(
      "Package",
      if gates.has_source_bound_package { "source-bound" } else { "missing" },
    ),
  ])
}

///|
fn mooncode_action_plan_limit(actions : Array[MoonCodeActionPlanItem]) -> Int {
  if actions.length() > 8 {
    8
  } else {
    actions.length()
  }
}

///|
fn render_mooncode_action_plan_item(
  dispatch : Dispatch[Msg],
  action : MoonCodeActionPlanItem,
) -> @rabbita.Html {
  let target = if action.context_path == "" {
    action.target
  } else {
    action.context_path
  }
  div(class="mooncode-review-item " + mooncode_action_plan_item_class(action), [
    div(class="mooncode-review-head", [
      div([
        strong(action.action + " -> " + action.state),
        small(action.runtime_state + " / " + action.created_at),
      ]),
      div(class="toolbar-actions", [
        if action.context_path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(action.context_path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_tests", target)),
          "Test",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_build", target)),
          "Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("package", target)),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("commit", target)),
          "Commit",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("accept", target)),
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("reject", target)),
          "Reject",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Approval", action.approval),
      info_chip("Dispatch", action.dispatch),
      info_chip("Lanes", action.expected_lanes.length().to_string()),
      info_chip("Tools", action.tool_hints.length().to_string()),
      info_chip("Evidence", action.runtime_evidence_status),
      info_chip(
        "Proof",
        "\{action.proven_required_event_count}/\{action.required_event_count}",
      ),
      info_chip(
        "Tool Proof",
        mooncode_optional_ratio_label(
          action.tool_harness_proven_tool_count,
          action.tool_harness_expected_tool_count,
        ),
      ),
      info_chip(
        "Tool Harness",
        mooncode_optional_text_label(action.tool_harness_status),
      ),
    ]),
    code(if target == "" { action.command_id } else { target }),
    div(class="mooncode-output-roots", [
      small("Required gates"),
      p(if action.required_gates.length() == 0 {
        "none"
      } else {
        action.required_gates.join(", ")
      }),
    ]),
    render_mooncode_action_plan_evidence(action),
    if action.blocking_reason == "" {
      p(class="mooncode-event-detail", action.next_step)
    } else {
      p(class="mooncode-event-detail", action.blocking_reason)
    },
    small(class="status-line", action.command_id),
  ])
}

///|
fn render_mooncode_action_plan_evidence(
  action : MoonCodeActionPlanItem
) -> @rabbita.Html {
  if action.required_event_count == 0 {
    return span(class="hidden-inline", "")
  }
  div(class="mooncode-output-roots", [
    small("Runtime evidence"),
    p(
      "required " +
      action.required_event_count.to_string() +
      ", proven " +
      action.proven_required_event_count.to_string() +
      mooncode_action_plan_event_gap_text(
        action.missing_required_events, "missing",
      ) +
      mooncode_action_plan_event_gap_text(
        action.failed_required_events, "failed",
      ),
    ),
    if action.tool_harness_status is Some(_) {
      p(
        class="mooncode-event-detail",
        "tool harness " +
        mooncode_optional_text_label(action.tool_harness_status) +
        " / proven " +
        mooncode_optional_ratio_label(
          action.tool_harness_proven_tool_count,
          action.tool_harness_expected_tool_count,
        ) +
        " / missing " +
        mooncode_optional_int_label(action.tool_harness_missing_tool_count) +
        " / failed " +
        mooncode_optional_int_label(action.tool_harness_failed_tool_count),
      )
    } else {
      span(class="hidden-inline", "")
    },
  ])
}

///|
fn mooncode_action_plan_event_gap_text(
  events : Array[String],
  label : String,
) -> String {
  if events.length() == 0 {
    ""
  } else {
    "; " + label + " " + events.join(", ")
  }
}

///|
fn mooncode_action_plan_item_class(action : MoonCodeActionPlanItem) -> String {
  match action.state {
    "completed" => "accepted"
    "ready-for-review" => "pending"
    "blocked" | "runtime-retry" => "rejected"
    "awaiting-proof" => "running"
    "running" => "running"
    "queued-for-runtime" => "queued"
    _ => "queued"
  }
}

///|
fn render_mooncode_runtime_evidence_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-evidence-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "session proof contract"),
        h3("Runtime Evidence"),
      ]),
      span(class="record-kind", model.mooncode_runtime_evidence_status),
    ]),
    match model.mooncode_runtime_evidence {
      Some(evidence) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Status", evidence.status),
            info_chip("Commands", evidence.command_count.to_string()),
            info_chip("Proven", evidence.proven_command_count.to_string()),
            info_chip(
              "Missing",
              evidence.missing_evidence_command_count.to_string(),
            ),
            info_chip("Failed", evidence.failed_evidence_command_count.to_string()),
            info_chip(
              "Proof",
              "\{evidence.proven_required_event_count}/\{evidence.required_event_count}",
            ),
            info_chip(
              "Tool Proof",
              mooncode_optional_ratio_label(
                evidence.tool_harness_proven_tool_count,
                evidence.tool_harness_expected_tool_count,
              ),
            ),
            info_chip(
              "Tool Missing",
              mooncode_optional_int_label(
                evidence.tool_harness_missing_tool_count,
              ),
            ),
            info_chip(
              "Tool Failed",
              mooncode_optional_int_label(
                evidence.tool_harness_failed_tool_count,
              ),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Recorded", empty_label(evidence.recorded_at)),
            info_row(
              "Tool Harness",
              mooncode_optional_text_label(evidence.tool_harness_status),
            ),
            info_row("Manifest", empty_label(evidence.manifest_path)),
            info_row("Commands Log", empty_label(evidence.command_log_path)),
            info_row(
              "Runtime Feed",
              empty_label(evidence.runtime_command_log_path),
            ),
            info_row("Event Log", empty_label(evidence.event_log_path)),
            info_row(
              "Artifact",
              empty_label(evidence.absolute_manifest_path),
            ),
            info_row("Task", empty_label(evidence.task_id)),
          ]),
          if evidence.items.length() == 0 {
            p(class="status-line", "no commands have runtime evidence yet")
          } else {
            div(
              class="mooncode-review-list runtime-evidence-list",
              evidence.items[:mooncode_runtime_evidence_limit(evidence.items)].map(item =>
                render_mooncode_runtime_evidence_item(item)
              ),
            )
          },
          p(class="mooncode-event-detail", evidence.rule),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime evidence has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_runtime_evidence_limit(
  items : Array[MoonCodeRuntimeEvidenceItem]
) -> Int {
  if items.length() > 8 {
    8
  } else {
    items.length()
  }
}

///|
fn render_mooncode_runtime_evidence_item(
  item : MoonCodeRuntimeEvidenceItem
) -> @rabbita.Html {
  let target = if item.context_path == "" {
    item.command_id
  } else {
    item.context_path
  }
  div(class="mooncode-review-item " + mooncode_runtime_evidence_item_class(item), [
    div(class="mooncode-review-head", [
      div([
        strong(item.action + " -> " + item.status),
        small(item.created_at),
      ]),
      span(
        class="record-kind",
        if item.runtime_command_recorded {
          "runtime command"
        } else {
          "missing runtime command"
        },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip(
        "Proof",
        "\{item.proven_required_event_count}/\{item.required_event_count}",
      ),
      info_chip(
        "Tools",
        mooncode_optional_ratio_label(
          item.tool_harness_proven_tool_count,
          item.tool_harness_expected_tool_count,
        ),
      ),
      info_chip(
        "Tool Harness",
        mooncode_optional_text_label(item.tool_harness_status),
      ),
      info_chip("Missing", item.missing_required_events.length().to_string()),
      info_chip("Failed", item.failed_required_events.length().to_string()),
    ]),
    code(target),
    if item.message == "" {
      span(class="hidden-inline", "")
    } else {
      p(class="mooncode-event-detail", item.message)
    },
    if item.required_event_count == 0 {
      p(class="mooncode-event-detail", "no required runtime events")
    } else {
      p(
        class="mooncode-event-detail",
        "required " +
        item.required_event_count.to_string() +
        ", proven " +
        item.proven_required_event_count.to_string() +
        mooncode_action_plan_event_gap_text(
          item.missing_required_events, "missing",
        ) +
        mooncode_action_plan_event_gap_text(
          item.failed_required_events, "failed",
        ),
      )
    },
  ])
}

///|
fn mooncode_runtime_evidence_item_class(
  item : MoonCodeRuntimeEvidenceItem
) -> String {
  match item.status {
    "proven" => "accepted"
    "failed" => "rejected"
    "missing-evidence" => "running"
    _ => "queued"
  }
}

///|
fn render_mooncode_runtime_claim_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-claim-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "runtime lease state"),
        h3("Runtime Claims"),
      ]),
      span(class="record-kind", model.mooncode_runtime_claim_status),
    ]),
    div(class="toolbar-actions", [
      button(
        class="secondary-button",
        on_click=dispatch(ClaimMoonCodeRuntime(false)),
        "Claim Next",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(ClaimMoonCodeRuntime(true)),
        "Force Claim",
      ),
      button(
        class="primary-button",
        on_click=dispatch(RunMoonCodeRuntimeLoop),
        "Run Native Loop",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(StartMoonCodeRuntimeService),
        "Start Service",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(RunMoonCodeCommand("cancel")),
        "Stop Service",
      ),
    ]),
    render_mooncode_runtime_service_state(model),
    match model.mooncode_runtime_claim {
      Some(state) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", state.command_count.to_string()),
            info_chip("Claimable", state.claimable_command_count.to_string()),
            info_chip("Claimed", state.claimed_command_count.to_string()),
            info_chip("Delivered", state.delivered_command_count.to_string()),
            info_chip("Failed", state.failed_command_count.to_string()),
            info_chip("Invalid", state.invalid_command_count.to_string()),
            info_chip(
              "Auth Blocked",
              state.tool_authorization_blocked_command_count.to_string(),
            ),
            info_chip(
              "Order Blocked",
              state.order_blocked_command_count.to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Claim Endpoint", state.claim_endpoint),
            info_row("Ack Endpoint", state.ack_endpoint),
            info_row("Runtime Feed", state.runtime_command_log_path),
            info_row("Dispatch Log", state.runtime_dispatch_log_path),
          ]),
          if state.claimed_commands.length() == 0 &&
            state.claimable_commands.length() == 0 &&
            state.tool_authorization_blocked_commands.length() == 0 &&
            state.order_blocked_commands.length() == 0 {
            p(class="status-line", "no runtime commands are leased or claimable")
          } else {
            div(
              class="mooncode-review-list runtime-claim-list",
              mooncode_recent_claim_items(
                state.claimed_commands,
                state.claimable_commands,
                state.tool_authorization_blocked_commands,
                state.order_blocked_commands,
              ).map(item =>
                render_mooncode_runtime_claim_item(dispatch, item)
              ),
            )
          },
          small(class="status-line", state.lease_policy),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime claim state has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_runtime_service_state(model : Model) -> @rabbita.Html {
  match model.mooncode_runtime_event_sink {
    Some(sink) if sink.session_id == model.selected_agent_session_id => {
      let service = sink.runtime_service
      div(class="daemon-state compact-state runtime-service-state", [
        info_row("Service", "\{service.status} / \{empty_label(service.service_id)}"),
        info_row("Active", if service.active { "yes" } else { "no" }),
        info_row("Started", empty_label(service.started_at)),
        info_row("Finished", empty_label(service.finished_at)),
        info_row("Stopped By", empty_label(service.stopped_by)),
        info_row(
          "Turns",
          "\{service.ran_turn_count} ran, \{service.failed_turn_count} failed",
        ),
        info_row(
          "Lifecycle",
          "\{service.started_count} started, \{service.finished_count} finished, \{service.failed_count} failed",
        ),
        info_row("Owner", empty_label(service.owner)),
        if service.detail == "" {
          span(class="hidden-inline", "")
        } else {
          p(class="mooncode-event-detail", service.detail)
        },
        if service.control_hint == "" {
          span(class="hidden-inline", "")
        } else {
          p(class="status-line", service.control_hint)
        },
      ])
    }
    _ => p(
      class="status-line",
      "Runtime service state appears after MoonCode runtime events are loaded.",
    )
  }
}

///|
fn mooncode_recent_claim_items(
  claimed : Array[MoonCodeRuntimeClaimItem],
  claimable : Array[MoonCodeRuntimeClaimItem],
  auth_blocked : Array[MoonCodeRuntimeClaimItem],
  order_blocked : Array[MoonCodeRuntimeClaimItem],
) -> Array[MoonCodeRuntimeClaimItem] {
  let items : Array[MoonCodeRuntimeClaimItem] = []
  for item in claimable {
    if items.length() < 8 {
      items.push(item)
    }
  }
  for item in auth_blocked {
    if items.length() < 8 {
      items.push(item)
    }
  }
  for item in claimed {
    if items.length() < 8 {
      items.push(item)
    }
  }
  for item in order_blocked {
    if items.length() < 8 {
      items.push(item)
    }
  }
  items
}

///|
fn render_mooncode_runtime_claim_item(
  dispatch : Dispatch[Msg],
  item : MoonCodeRuntimeClaimItem
) -> @rabbita.Html {
  div(class="mooncode-review-item " + mooncode_runtime_claim_item_class(item), [
    div(class="mooncode-review-head", [
      div([
        strong(item.action + " -> " + item.claim_status),
        small(
          if item.claimed_at == "" {
            item.created_at
          } else {
            item.consumer_id + " / " + item.claimed_at
          },
        ),
      ]),
      div(
        class="toolbar-actions",
        render_mooncode_runtime_claim_actions(dispatch, item),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Dispatch", item.dispatch),
      info_chip("Serve", item.serve_command),
      info_chip("Lease", empty_label(item.lease_expires_at)),
      info_chip("Auth", empty_label(item.tool_authorization_state)),
      info_chip(
        "Tool Run",
        if item.runtime_may_execute_tools { "allowed" } else { "blocked" },
      ),
    ]),
    if item.tool_authorization_blocked {
      p(
        class="status-line",
        "Tool authorization blocks this command: " +
        empty_label(item.tool_authorization_blocked_reason),
      )
    } else if item.blocked_by_command_id != "" {
      p(
        class="status-line",
        "Waiting behind " + item.blocked_by_command_id + " (" +
        empty_label(item.blocked_by_status) + ")",
      )
    } else {
      span(class="sr-only", "")
    },
    if item.target == "" {
      code(item.command_id)
    } else {
      code(item.target)
    },
    render_mooncode_runtime_execution_summary(item.runtime_command),
    small(class="status-line", item.ack_endpoint),
  ])
}

///|
fn render_mooncode_runtime_claim_actions(
  dispatch : Dispatch[Msg],
  item : MoonCodeRuntimeClaimItem
) -> Array[@rabbita.Html] {
  let actions : Array[@rabbita.Html] = [
    span(class="record-kind", item.receipt_status),
  ]
  if item.claim_status == "claimed" {
    actions.push(
      button(
        class="secondary-button",
        on_click=dispatch(
          AckMoonCodeRuntimeCommand(item.command_id, "runtime-acknowledged"),
        ),
        "Ack",
      ),
    )
    actions.push(
      button(
        class="secondary-button",
        on_click=dispatch(
          AckMoonCodeRuntimeCommand(item.command_id, "runtime-completed"),
        ),
        "Complete",
      ),
    )
    actions.push(
      button(
        class="secondary-button",
        on_click=dispatch(AckMoonCodeRuntimeCommand(item.command_id, "failed")),
        "Fail",
      ),
    )
  }
  actions
}

///|
fn mooncode_runtime_claim_item_class(item : MoonCodeRuntimeClaimItem) -> String {
  match item.claim_status {
    "claimed" => "running"
    "claimable" => "queued"
    "delivered" => "accepted"
    "blocked-tool-authorization" | "failed" | "invalid" => "rejected"
    "blocked-by-prior-command" => "running"
    _ => "queued"
  }
}

///|
fn render_mooncode_runtime_dispatch_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-dispatch-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "runtime delivery audit"),
        h3("Dispatch Receipts"),
      ]),
      span(class="record-kind", model.mooncode_runtime_dispatch_status),
    ]),
    match model.mooncode_runtime_dispatch {
      Some(state) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", state.runtime_command_count.to_string()),
            info_chip("Receipts", state.runtime_dispatch_count.to_string()),
            info_chip("Pending", state.runtime_dispatch_pending_count.to_string()),
            info_chip("Mode", state.dispatch_mode),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Runtime Feed", state.runtime_command_log_path),
            info_row("Dispatch Log", state.runtime_dispatch_log_path),
            info_row("Session", state.session_id),
            info_row("Task", empty_label(state.task_id)),
          ]),
          if state.pending_command_ids.length() == 0 {
            p(class="status-line", "all runtime commands have dispatch receipts")
          } else {
            div(class="mooncode-output-roots", [
              small("Pending command ids"),
              p(state.pending_command_ids.join(", ")),
            ])
          },
          if state.dispatch_receipts.length() == 0 {
            p(class="status-line", "no dispatch receipts recorded yet")
          } else {
            div(
              class="mooncode-review-list runtime-dispatch-list",
              mooncode_recent_dispatch_receipts(state.dispatch_receipts).map(receipt =>
                render_mooncode_runtime_dispatch_receipt(receipt)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime dispatch state has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_recent_dispatch_receipts(
  receipts : Array[MoonCodeRuntimeDispatchReceipt]
) -> Array[MoonCodeRuntimeDispatchReceipt] {
  let recent : Array[MoonCodeRuntimeDispatchReceipt] = []
  let mut index = receipts.length()
  let mut emitted = 0
  while index > 0 && emitted < 8 {
    index -= 1
    recent.push(receipts[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_runtime_dispatch_receipt(
  receipt : MoonCodeRuntimeDispatchReceipt
) -> @rabbita.Html {
  let target = json_field_string(receipt.runtime_command, "target", default="")
  div(class="mooncode-review-item " + mooncode_runtime_dispatch_state(receipt), [
    div(class="mooncode-review-head", [
      div([
        strong(receipt.action + " -> " + receipt.status),
        small(receipt.dispatch_mode + " / " + receipt.created_at),
      ]),
      span(
        class=if receipt.openseek_wire_valid {
          "record-kind good"
        } else {
          "record-kind"
        },
        if receipt.openseek_wire_valid { "wire valid" } else { "wire pending" },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Dispatch", receipt.dispatch),
      info_chip("Ack Order", mooncode_ack_order_status_label(receipt)),
      info_chip(
        "Requested",
        mooncode_optional_text_label(receipt.requested_status),
      ),
      info_chip(
        "Native",
        if receipt.native_mooncode_endpoint == "" {
          "none"
        } else {
          "ready"
        },
      ),
      info_chip("Legacy", empty_label(receipt.legacy_bridge_endpoint)),
    ]),
    if target == "" {
      code(receipt.command_id)
    } else {
      code(target)
    },
    render_mooncode_runtime_ack_audit(receipt),
    render_mooncode_runtime_proof_gate(receipt.proof_gate),
    render_mooncode_runtime_execution_summary(receipt.runtime_command),
    p(class="mooncode-event-detail", receipt.detail),
    small(class="status-line", receipt.dispatch_id),
  ])
}

///|
fn mooncode_ack_order_status_label(
  receipt : MoonCodeRuntimeDispatchReceipt
) -> String {
  match receipt.ack_order_status {
    Some(status) => if status == "" { "n/a" } else { status }
    None => "n/a"
  }
}

///|
fn mooncode_optional_text_label(value : String?) -> String {
  match value {
    Some(text) => if text == "" { "none" } else { text }
    None => "none"
  }
}

///|
fn mooncode_optional_bool_label(value : Bool?) -> String {
  match value {
    Some(true) => "yes"
    Some(false) => "no"
    None => "n/a"
  }
}

///|
fn render_mooncode_runtime_ack_audit(
  receipt : MoonCodeRuntimeDispatchReceipt
) -> @rabbita.Html {
  match receipt.ack_order_status {
    Some(_) =>
      div(class="daemon-state compact-state", [
        info_row(
          "Previous Dispatch",
          mooncode_optional_text_label(receipt.previous_dispatch_status),
        ),
        info_row(
          "Previous Claim",
          mooncode_optional_text_label(receipt.previous_claim_id),
        ),
        info_row(
          "Previous Consumer",
          mooncode_optional_text_label(receipt.previous_consumer_id),
        ),
        info_row(
          "Same Consumer",
          mooncode_optional_bool_label(receipt.claimed_by_same_consumer),
        ),
        render_mooncode_runtime_ack_blocker(receipt.order_blocker),
      ])
    None => span(class="hidden-inline", "")
  }
}

///|
fn render_mooncode_runtime_ack_blocker(blocker : Json?) -> @rabbita.Html {
  match blocker {
    Some(value) => {
      let command_id = json_field_string(value, "command_id", default="")
      if command_id == "" {
        span(class="hidden-inline", "")
      } else {
        info_row(
          "Order Blocker",
          "\{command_id} / \{json_field_string(value, "status", default="blocked")}",
        )
      }
    }
    None => span(class="hidden-inline", "")
  }
}

///|
fn render_mooncode_runtime_proof_gate(gate : Json?) -> @rabbita.Html {
  match gate {
    Some(value) => {
      let kind = json_field_string(value, "kind", default="")
      if kind == "" {
        span(class="hidden-inline", "")
      } else {
        let status = json_field_string(value, "status", default="unknown")
        let blocked = json_field_bool(value, "completion_blocked", default=false)
        let missing = mooncode_runtime_proof_gate_missing_label(Some(value))
        let failed = json_field_string_array_items(
          value, "failed_required_events",
        )
        let gate_class = if blocked {
          "blocked"
        } else if status == "passed" {
          "passed"
        } else {
          "idle"
        }
        let badge_class = if blocked {
          "record-kind warning"
        } else if status == "passed" {
          "record-kind good"
        } else {
          "record-kind"
        }
        let missing_text = if missing == "" {
          "missing none"
        } else {
          "missing " + missing
        }
        let failed_text = if failed.length() == 0 {
          "failed none"
        } else {
          "failed " + failed.join(", ")
        }
        div(class="mooncode-proof-gate " + gate_class, [
            div(class="mooncode-tool-head", [
              strong("Completion proof"),
              span(class=badge_class, status),
            ]),
            div(class="mooncode-stats", [
              info_chip(
                "Required",
                json_field_int(value, "required_event_count", default=0).to_string(),
              ),
              info_chip(
                "Proven",
                json_field_int(value, "proven_required_event_count", default=0).to_string(),
              ),
              info_chip(
                "Missing",
                json_field_int(value, "missing_required_event_count", default=0).to_string(),
              ),
              info_chip(
                "Failed",
                json_field_int(value, "failed_required_event_count", default=0).to_string(),
              ),
            ]),
            if missing == "" && failed.length() == 0 {
              small("Required command-scoped proof is satisfied or not required.")
            } else {
              small(
                [missing_text, failed_text].join(" / "),
              )
            },
          ])
      }
    }
    None => span(class="hidden-inline", "")
  }
}

///|
fn mooncode_runtime_proof_gate_status(gate : Json?) -> String {
  match gate {
    Some(value) => json_field_string(value, "status", default="")
    None => ""
  }
}

///|
fn mooncode_runtime_proof_gate_missing_label(gate : Json?) -> String {
  match gate {
    Some(value) => {
      let missing = json_field_string_array_items(
        value, "missing_required_events",
      )
      if missing.length() == 0 {
        ""
      } else {
        missing.join(", ")
      }
    }
    None => ""
  }
}

///|
fn render_mooncode_runtime_execution_summary(command : Json) -> @rabbita.Html {
  match json_field(command, "execution_summary") {
    Some(summary) => {
      let tool_sequence = json_field_string_array_items(
        summary, "tool_sequence",
      )
      let expected_events = json_field_string_array_items(
        summary, "expected_events",
      )
      let required_outputs = json_field_string_array_items(
        summary, "required_outputs",
      )
      let execution_checklist = json_field_json_array_items(
        summary, "execution_checklist",
      )
      let tool_policies = json_field_json_array_items(summary, "tool_policies")
      let recommended = json_field_string_array_items(
        summary, "recommended_commands",
      )
      div(class="mooncode-runtime-summary", [
        div(class="mooncode-stats", [
          info_chip(
            "Plan",
            json_field_string(summary, "action", default="command"),
          ),
          info_chip(
            "Tools",
            if tool_sequence.length() == 0 {
              "none"
            } else {
              tool_sequence.join(" -> ")
            },
          ),
          info_chip("Events", expected_events.length().to_string()),
          info_chip("Outputs", required_outputs.length().to_string()),
          info_chip(
            "Checklist",
            json_field_int(
              summary,
              "checklist_count",
              default=execution_checklist.length(),
            ).to_string(),
          ),
          info_chip(
            "Review",
            if json_field_bool(summary, "review_required", default=false) {
              "required"
            } else {
              "not required"
            },
          ),
          info_chip(
            "Auth",
            empty_label(
              json_field_string(
                summary,
                "tool_authorization_state",
                default="",
              ),
            ),
          ),
          info_chip(
            "Tool Run",
            if json_field_bool(summary, "runtime_may_execute_tools", default=true) {
              "allowed"
            } else {
              "blocked"
            },
          ),
        ]),
        if recommended.length() == 0 {
          span(class="hidden-inline", "")
        } else {
          div(class="mooncode-output-roots", [
            small("Recommended commands"),
            p(recommended.join(", ")),
          ])
        },
        div(class="mooncode-output-roots", [
          small("Required outputs"),
          p(if required_outputs.length() == 0 {
            "none"
          } else {
            required_outputs.join(", ")
          }),
        ]),
        render_mooncode_tool_policy_list(tool_policies),
        render_mooncode_execution_checklist(execution_checklist),
        div(class="daemon-state compact-state", [
          info_row(
            "Events",
            if expected_events.length() == 0 {
              "none"
            } else {
              expected_events.join(", ")
            },
          ),
          info_row(
            "Event Sink",
            empty_label(json_field_string(summary, "event_sink", default="")),
          ),
          info_row(
            "Ack Sink",
            empty_label(json_field_string(summary, "ack_sink", default="")),
          ),
        ]),
      ])
    }
    None => span(class="hidden-inline", "")
  }
}

///|
fn render_mooncode_tool_policy_list(policies : Array[Json]) -> @rabbita.Html {
  if policies.length() == 0 {
    span(class="hidden-inline", "")
  } else {
    div(class="mooncode-tool-policy-list", [
      small("Tool policies"),
      div(
        class="mooncode-review-list compact-list",
        mooncode_tool_policy_limit(policies).map(render_mooncode_tool_policy),
      ),
    ])
  }
}

///|
fn mooncode_tool_policy_limit(policies : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = 0
  while index < policies.length() && recent.length() < 6 {
    recent.push(policies[index])
    index += 1
  }
  recent
}

///|
fn render_mooncode_tool_policy(policy : Json) -> @rabbita.Html {
  let required_inputs = json_field_string_array_items(policy, "required_inputs")
  let proof_events = json_field_string_array_items(policy, "proof_events")
  let guardrails = json_field_string_array_items(policy, "guardrails")
  div(class="mooncode-tool-policy", [
    div(class="mooncode-tool-head", [
      strong(json_field_string(policy, "tool", default="tool")),
      span(
        class=if json_field_bool(policy, "mutates_files", default=false) {
          "record-kind warning"
        } else {
          "record-kind good"
        },
        json_field_string(policy, "approval", default="policy"),
      ),
    ]),
    small(
      [
        "inputs " + mooncode_inline_list(required_inputs),
        "proof " + mooncode_inline_list(proof_events),
      ].join(" / "),
    ),
    p(
      if guardrails.length() == 0 {
        "Runtime must enforce this tool before execution."
      } else {
        guardrails.join("; ")
      },
    ),
  ])
}

///|
fn mooncode_inline_list(items : Array[String]) -> String {
  if items.length() == 0 {
    "none"
  } else {
    items.join(", ")
  }
}

///|
fn render_mooncode_execution_checklist(items : Array[Json]) -> @rabbita.Html {
  if items.length() == 0 {
    span(class="hidden-inline", "")
  } else {
    div(class="mooncode-execution-checklist", [
      small("Runtime checklist"),
      div(
        class="mooncode-review-list compact-list",
        items.map(item => render_mooncode_execution_checklist_item(item)),
      ),
    ])
  }
}

///|
fn render_mooncode_execution_checklist_item(item : Json) -> @rabbita.Html {
  let required_event = json_field_string(item, "required_event", default="")
  let required_output = json_field_string(item, "required_output", default="")
  let endpoint = json_field_string(item, "endpoint", default="")
  div(class="mooncode-checklist-row", [
    span(
      class="record-kind",
      json_field_int(item, "index", default=0).to_string(),
    ),
    div([
      strong(json_field_string(item, "title", default="Runtime step")),
      small(json_field_string(item, "owner", default="moonclaw")),
      if required_event == "" && required_output == "" && endpoint == "" {
        span(class="hidden-inline", "")
      } else {
        small(
          [
            empty_label(required_event),
            empty_label(required_output),
            empty_label(endpoint),
          ].join(" / "),
        )
      },
    ]),
  ])
}

///|
fn mooncode_runtime_dispatch_state(
  receipt : MoonCodeRuntimeDispatchReceipt
) -> String {
  match receipt.ack_order_status {
    Some("blocked-by-prior-command") | Some("consumer-mismatch") => return "rejected"
    Some("matching-claim") | Some("already-delivered") => return "accepted"
    _ => ()
  }
  match receipt.status {
    "native-dispatched" | "runtime-acknowledged" | "runtime-completed" =>
      "accepted"
    "legacy-bridged" => "pending"
    "failed" => "rejected"
    "recorded" => "queued"
    _ => "queued"
  }
}

///|
fn render_mooncode_event_lanes(
  model : Model,
  session : AgentSession,
) -> @rabbita.Html {
  let summary = session.mooncode_summary
  section(class="mooncode-stream", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", summary.protocol),
        h3("MoonCode Stream"),
      ]),
      span(
        class=if summary.has_packaging_candidate {
          "record-kind good"
        } else {
          "record-kind"
        },
        if summary.has_packaging_candidate {
          "package ready"
        } else {
          "\{summary.event_count} events"
        },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Tools", summary.tool_count.to_string()),
      info_chip("Diffs", summary.diff_count.to_string()),
      info_chip("Tests", summary.test_count.to_string()),
      info_chip("Verified", summary.verified_test_count.to_string()),
      info_chip("Artifacts", summary.artifact_count.to_string()),
      info_chip("Source-bound", summary.source_bound_package_count.to_string()),
      info_chip("Review", summary.review_count.to_string()),
      info_chip("Pending", summary.pending_diff_count.to_string()),
      info_chip("Deferred Steers", summary.deferred_steer_count.to_string()),
      info_chip("Cursor", model.mooncode_stream_cursor.to_string()),
    ]),
    render_mooncode_live_tail(model),
    div(class="mooncode-lane-grid", [
      render_mooncode_lane(session, "tool", "Tools"),
      render_mooncode_lane(session, "diff", "Diffs"),
      render_mooncode_lane(session, "test", "Tests"),
      render_mooncode_lane(session, "artifact", "Artifacts"),
      render_mooncode_lane(session, "review", "Review"),
    ]),
  ])
}

///|
fn render_mooncode_live_tail(model : Model) -> @rabbita.Html {
  div(class="mooncode-live-tail", [
    div(class="mooncode-lane-title", [
      strong("Live Tail"),
      span(class="record-kind", model.mooncode_stream_status),
      span(class="record-kind", model.mooncode_stream_checkpoint_status),
    ]),
    if model.mooncode_stream_events.length() == 0 {
      p(class="status-line", "waiting for incremental stream events")
    } else {
      div(
        class="mooncode-event-list compact",
        model.mooncode_stream_events[:mooncode_lane_limit(
          model.mooncode_stream_events,
        )].map(event => render_mooncode_event(event)),
      )
    },
  ])
}

///|
fn info_chip(label : String, value : String) -> @rabbita.Html {
  span(class="info-chip", [strong(value), small(label)])
}

///|
fn render_mooncode_lane(
  session : AgentSession,
  lane : String,
  title : String,
) -> @rabbita.Html {
  let events = mooncode_lane_events(session, lane)
  div(class="mooncode-lane " + lane, [
    div(class="mooncode-lane-title", [
      strong(title),
      span(class="record-kind", events.length().to_string()),
    ]),
    if events.length() == 0 {
      p(class="status-line", "waiting")
    } else {
      div(
        class="mooncode-event-list",
        events[:mooncode_lane_limit(events)].map(event => render_mooncode_event(event)),
      )
    },
  ])
}

///|
fn render_mooncode_eval_report_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board eval-report-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "OpenSeek-style evidence"),
        h3("Eval Report"),
      ]),
      div(class="toolbar-actions", [
        span(class="record-kind", model.mooncode_eval_report_status),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_eval")),
          "Run Eval",
        ),
      ]),
    ]),
    match model.mooncode_eval_report {
      Some(report) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Score", report.bridge_score.to_string()),
            info_chip("Level", report.bridge_level),
            info_chip("Passed", report.passed_check_count.to_string()),
            info_chip("Missing", report.missing_check_count.to_string()),
            info_chip(
              "Native",
              if report.native_eval_evidence_ready { "ready" } else { "missing" },
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Status", report.status),
            info_row("Runtime", report.runtime_owner),
            info_row("UI", report.ui_owner),
            info_row("Artifact", report.artifact_owner),
            info_row("Extractable", report.extractable_component),
            info_row("Native Source", report.native_eval_source),
            info_row("Native Endpoint", report.native_eval_endpoint),
            info_row(
              "Native Ingest",
              report.native_eval_ingest_method +
              " " +
              report.native_eval_ingest_endpoint,
            ),
            info_row("Manifest", empty_label(report.manifest_path)),
            info_row("Recorded", empty_label(report.recorded_at)),
            info_row("Task", empty_label(report.task_id)),
          ]),
          p(class="mooncode-event-detail", report.current_gap),
          div(class="mooncode-output-roots", [
            small("Required native harnesses"),
            p(report.required_native_harnesses.join(", ")),
          ]),
          ul(
            class="mooncode-evidence-list",
            report.minimum_native_evidence.map(item => li(item)),
          ),
          render_mooncode_eval_checks(report.checks),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode eval report has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_runtime_handoff_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-handoff-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "extractable runtime contract"),
        h3("Runtime Handoff"),
      ]),
      span(class="record-kind", model.mooncode_runtime_handoff_status),
    ]),
    match model.mooncode_runtime_handoff {
      Some(handoff) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", handoff.command_count.to_string()),
            info_chip(
              "Runtime",
              if handoff.engine.native_runtime_ready { "native" } else { "bridge" },
            ),
            info_chip(
              "Daemon",
              if handoff.engine.daemon_running { "running" } else { "stopped" },
            ),
            info_chip("Eval", handoff.summary.eval_level),
            info_chip("Score", handoff.summary.eval_score.to_string()),
            info_chip(
              "Dispatches",
              handoff.summary.runtime_dispatch_count.to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Status", handoff.status),
            info_row("Manifest", empty_label(handoff.manifest_path)),
            info_row("Workspace", empty_label(handoff.workspace_root)),
            info_row("Task", empty_label(handoff.task_id)),
            info_row("Dispatch", handoff.engine.dispatch_mode),
            info_row("Bridge", handoff.engine.bridge_status),
            info_row("MoonClaw", empty_label(handoff.engine.moonclaw_root)),
          ]),
          render_mooncode_runtime_consumer(handoff.runtime_consumer),
          render_mooncode_runtime_turn_packet(handoff.runtime_turn_packet),
          render_mooncode_runtime_supervisor(handoff.runtime_supervisor),
          render_mooncode_runtime_execution_plan(
            handoff.runtime_execution_plan,
          ),
          div(class="daemon-state compact-state", [
            info_row(
              "Session Snapshot",
              handoff.resume_contract.session_snapshot_path,
            ),
            info_row(
              "Session Store",
              handoff.resume_contract.session_store_endpoint,
            ),
            info_row("Command Log", handoff.resume_contract.command_log_path),
            info_row(
              "Runtime Feed",
              handoff.resume_contract.runtime_command_log_path,
            ),
            info_row(
              "Runtime Dispatch",
              handoff.resume_contract.runtime_dispatch_log_path,
            ),
            info_row("Event Log", handoff.resume_contract.event_log_path),
            info_row("Stream", handoff.resume_contract.stream_endpoint),
            info_row(
              "Event Sink",
              handoff.resume_contract.runtime_event_ingest_endpoint,
            ),
            info_row("Queue", handoff.resume_contract.command_queue_endpoint),
            info_row(
              "Runtime Queue",
              handoff.resume_contract.runtime_command_feed_endpoint,
            ),
            info_row(
              "Dispatch State",
              handoff.resume_contract.runtime_dispatch_endpoint,
            ),
            info_row(
              "Runtime Replay",
              handoff.resume_contract.runtime_replay_endpoint,
            ),
            info_row(
              "Runtime Claim",
              handoff.resume_contract.runtime_claim_endpoint,
            ),
            info_row(
              "Action Plan",
              handoff.resume_contract.action_plan_endpoint,
            ),
            info_row(
              "Native Command",
              handoff.resume_contract.native_command_endpoint,
            ),
            info_row("Native Eval", handoff.resume_contract.native_eval_endpoint),
          ]),
          div(class="mooncode-output-roots", [
            small("MoonBook output roots"),
            p(handoff.book_output_roots.join(", ")),
          ]),
          p(class="mooncode-event-detail", handoff.next_runtime_step),
          small(class="status-line", handoff.resume_contract.ordering_rule),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime handoff has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_runtime_turn_packet(packet : Json?) -> @rabbita.Html {
  match packet {
    Some(packet) => {
      let endpoints = json_field_object_or_self(packet, "endpoints")
      div(class="mooncode-wire-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Turn Packet"),
          span(
            class=mooncode_runtime_consumer_status_class(
              json_field_string(packet, "status", default="idle"),
            ),
            json_field_string(packet, "status", default="idle"),
          ),
          span(
            class=if json_field_bool(
              packet,
              "scheduler_allows_turn",
              default=false,
            ) {
              "record-kind good"
            } else {
              "record-kind warning"
            },
            json_field_string(packet, "scheduler_effect", default="none"),
          ),
        ]),
        div(class="mooncode-stats", [
          info_chip("Operation", json_field_string(packet, "operation", default="wait")),
          info_chip("Action", empty_label(json_field_string(packet, "action", default=""))),
          info_chip("Command", empty_label(json_field_string(packet, "command_id", default=""))),
          info_chip(
            "Claim",
            if json_field_bool(packet, "ready_to_claim", default=false) {
              "ready"
            } else {
              "no"
            },
          ),
          info_chip(
            "Ack",
            if json_field_bool(packet, "ready_to_ack", default=false) {
              "ready"
            } else {
              "no"
            },
          ),
        ]),
        div(class="daemon-state compact-state", [
          info_row("Claim", json_field_string(endpoints, "claim", default="")),
          info_row("Ack", json_field_string(endpoints, "ack", default="")),
          info_row(
            "Events",
            json_field_string(endpoints, "runtime_events", default=""),
          ),
          info_row(
            "Native",
            json_field_string(endpoints, "native_commands", default=""),
          ),
        ]),
        div(class="mooncode-output-roots", [
          small("Required proof events"),
          p(json_field_string_array_summary(packet, "required_events")),
        ]),
        p(
          class="mooncode-event-detail",
          json_field_string(packet, "next_step", default=""),
        ),
        small(json_field_string(packet, "safety_boundary", default="")),
      ])
    }
    None =>
      div(class="mooncode-wire-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Turn Packet"),
          span(class="record-kind warning", "missing"),
        ]),
        p(class="status-line", "No runtime turn packet has been projected yet."),
      ])
  }
}

///|
fn render_mooncode_runtime_supervisor(supervisor : Json?) -> @rabbita.Html {
  match supervisor {
    Some(supervisor) => {
      let endpoints = json_field_object_or_self(supervisor, "endpoints")
      let readiness = json_field_object_or_self(supervisor, "readiness")
      let loop_steps = json_field_json_array_items(supervisor, "supervisor_loop")
      div(class="mooncode-wire-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Supervisor"),
          span(
            class=if json_field_bool(
              supervisor,
              "ready_to_launch",
              default=false,
            ) {
              "record-kind good"
            } else {
              "record-kind warning"
            },
            if json_field_bool(supervisor, "ready_to_launch", default=false) {
              "launchable"
            } else {
              "blocked"
            },
          ),
          span(
            class="record-kind",
            json_field_string(supervisor, "mode", default="bridge"),
          ),
        ]),
        div(class="mooncode-stats", [
          info_chip("Status", json_field_string(supervisor, "status", default="idle")),
          info_chip(
            "Action",
            empty_label(json_field_string(supervisor, "action", default="")),
          ),
          info_chip(
            "Command",
            empty_label(json_field_string(supervisor, "command_id", default="")),
          ),
          info_chip(
            "Scheduler",
            json_field_string(supervisor, "scheduler_effect", default="none"),
          ),
          info_chip(
            "Readiness",
            json_field_string(readiness, "status", default="unknown"),
          ),
        ]),
        div(class="daemon-state compact-state", [
          info_row("Claim", json_field_string(endpoints, "claim", default="")),
          info_row("Ack", json_field_string(endpoints, "ack", default="")),
          info_row(
            "Events",
            json_field_string(endpoints, "runtime_events", default=""),
          ),
          info_row(
            "Supervisor",
            json_field_string(endpoints, "runtime_supervisor", default=""),
          ),
          info_row(
            "Session",
            json_field_string(endpoints, "session_store", default=""),
          ),
          info_row(
            "MoonClaw",
            empty_label(json_field_string(supervisor, "moonclaw_root", default="")),
          ),
        ]),
        if json_field_bool(supervisor, "ready_to_launch", default=false) {
          p(
            class="mooncode-event-detail",
            "MoonClaw can claim and execute this turn through the listed loop.",
          )
        } else {
          p(
            class="mooncode-event-detail",
            json_field_string(
              supervisor,
              "launch_blocked_reason",
              default="No launchable runtime command.",
            ),
          )
        },
        div(class="mooncode-output-roots", [
          small("Missing launch requirements"),
          p(
            if json_field_int(
              readiness,
              "missing_requirement_count",
              default=0,
            ) == 0 {
              "none"
            } else {
              json_field_string_array_summary(
                readiness,
                "missing_requirements",
              )
            },
          ),
        ]),
        div(class="mooncode-consumer-loop", [
          small("Supervisor loop"),
          ul(
            class="mooncode-evidence-list",
            loop_steps.map(step => {
              let http_method = json_field_string(step, "method", default="")
              let endpoint = json_field_string(
                step,
                "endpoint",
                default=json_field_string(step, "id", default=""),
              )
              li("\{http_method} \{endpoint}")
            }),
          ),
        ]),
        small(json_field_string(supervisor, "safety_boundary", default="")),
      ])
    }
    None =>
      div(class="mooncode-wire-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Supervisor"),
          span(class="record-kind warning", "missing"),
        ]),
        p(
          class="status-line",
          "This handoff predates the runtime supervisor launch packet.",
        ),
      ])
  }
}

///|
fn render_mooncode_runtime_execution_plan(plan : Json?) -> @rabbita.Html {
  match plan {
    Some(plan) =>
      div(class="mooncode-wire-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Execution Plan"),
          span(
            class=mooncode_runtime_consumer_status_class(
              json_field_string(plan, "status", default="idle"),
            ),
            json_field_string(plan, "status", default="idle"),
          ),
        ]),
        div(class="mooncode-stats", [
          info_chip("Operation", json_field_string(plan, "operation", default="wait")),
          info_chip("Action", empty_label(json_field_string(plan, "action", default=""))),
          info_chip("Command", empty_label(json_field_string(plan, "command_id", default=""))),
          info_chip(
            "Execute",
            if json_field_bool(plan, "ready_to_execute", default=false) {
              "ready"
            } else {
              "no"
            },
          ),
          info_chip(
            "Proof",
            json_field_int(plan, "required_event_count", default=0).to_string(),
          ),
        ]),
        div(class="daemon-state compact-state", [
          info_row("Target", empty_label(json_field_string(plan, "target", default=""))),
          info_row(
            "Context",
            empty_label(json_field_string(plan, "context_path", default="")),
          ),
          info_row("Claim", json_field_string(plan, "claim_endpoint", default="")),
          info_row("Ack", json_field_string(plan, "ack_endpoint", default="")),
          info_row(
            "Events",
            json_field_string(plan, "runtime_event_ingest_endpoint", default=""),
          ),
          info_row(
            "Native",
            json_field_string(plan, "native_command_endpoint", default=""),
          ),
        ]),
        div(class="mooncode-output-roots", [
          small("Required proof events"),
          p(json_field_string_array_summary(plan, "required_events")),
        ]),
        p(class="mooncode-event-detail", json_field_string(plan, "next_step", default="")),
        small(json_field_string(plan, "safety_boundary", default="")),
      ])
    None =>
      div(class="mooncode-wire-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Execution Plan"),
          span(class="status-warn", "missing"),
        ]),
        p(
          class="status-line",
          "This handoff predates the runtime execution plan. Queue or refresh a MoonCode command to regenerate it.",
        ),
      ])
  }
}

///|
fn render_mooncode_runtime_consumer(
  consumer : MoonCodeRuntimeConsumer?,
) -> @rabbita.Html {
  match consumer {
    Some(consumer) =>
      div(class="mooncode-wire-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Consumer"),
          span(
            class=mooncode_runtime_consumer_status_class(consumer.status),
            consumer.status,
          ),
        ]),
        div(class="mooncode-stats", [
          info_chip("Claimable", consumer.claimable_command_count.to_string()),
          info_chip("Claimed", consumer.claimed_command_count.to_string()),
          info_chip("Pending", consumer.pending_command_count.to_string()),
          info_chip("Invalid", consumer.invalid_command_count.to_string()),
          info_chip(
            "Claim",
            if consumer.ready_to_claim { "ready" } else { "no" },
          ),
          info_chip(
            "Replay",
            if consumer.ready_to_replay { "ready" } else { "no" },
          ),
        ]),
        p(consumer.next_action),
        div(class="daemon-state compact-state", [
          info_row("Claim", consumer.endpoints.runtime_claim),
          info_row("Replay", consumer.endpoints.runtime_replay),
          info_row("Events", consumer.endpoints.runtime_events),
          info_row("Runtime Feed", consumer.endpoints.runtime_commands),
          info_row("Stream", consumer.endpoints.stream),
          info_row("Native Commands", consumer.endpoints.native_commands),
          info_row("Native Eval", consumer.endpoints.native_eval_report),
        ]),
        div(class="mooncode-consumer-loop", [
          small("Required loop"),
          ul(
            class="mooncode-evidence-list",
            consumer.required_loop.map(step => li(step)),
          ),
        ]),
        small(consumer.safety_boundary),
      ])
    None =>
      div(class="mooncode-wire-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Consumer"),
          span(class="record-kind warning", "missing"),
        ]),
        p(
          "This handoff predates the runtime consumer contract. Refresh the session or enqueue a MoonCode command to regenerate it.",
        ),
      ])
  }
}

///|
fn mooncode_runtime_consumer_status_class(status : String) -> String {
  match status {
    "claim-ready" => "record-kind good"
    "delivered" => "record-kind good"
    "lease-held" => "record-kind"
    "replay-ready" => "record-kind"
    "idle" => "record-kind"
    _ => "record-kind warning"
  }
}

///|
fn render_mooncode_review_queue(
  dispatch : Dispatch[Msg],
  session : AgentSession,
) -> @rabbita.Html {
  let summary = session.mooncode_summary
  let diffs = mooncode_lane_events(session, "diff")
  section(class="mooncode-review-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "review"),
        h3("Code Review"),
      ]),
      span(
        class=match summary.review_state {
          "accepted" => "record-kind good"
          "rejected" => "record-kind"
          "pending" => "record-kind"
          _ => "record-kind"
        },
        summary.review_state,
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Diffs", summary.diff_count.to_string()),
      info_chip("Pending", summary.pending_diff_count.to_string()),
      info_chip("Accepted", summary.accepted_review_count.to_string()),
      info_chip("Rejected", summary.rejected_review_count.to_string()),
      info_chip("Change Sets", summary.moonbook_change_set_manifest_count.to_string()),
      info_chip("Patch Sets", summary.moonbook_patch_set_manifest_count.to_string()),
    ]),
    if diffs.length() == 0 {
      p(class="status-line", "no diff candidates")
    } else {
      div(
        class="mooncode-review-list",
        diffs[:mooncode_review_limit(diffs)].map(event =>
          render_mooncode_review_item(dispatch, event)
        ),
      )
    },
  ])
}

///|
fn render_mooncode_change_set_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board change-set-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "moonbook review object"),
        h3("Change Set"),
      ]),
      span(class="record-kind", model.mooncode_change_set_status),
    ]),
    match model.mooncode_change_set {
      Some(change_set) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Diffs", change_set.diff_count.to_string()),
            info_chip("Tests", change_set.test_count.to_string()),
            info_chip("Verified", change_set.verified_test_count.to_string()),
            info_chip("Failed", change_set.failed_test_count.to_string()),
            info_chip("Artifacts", change_set.artifact_count.to_string()),
            info_chip("Reviews", change_set.review_count.to_string()),
            info_chip("Pending", change_set.pending_diff_count.to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Manifest", change_set.manifest_path),
            info_row("Recorded", change_set.recorded_at),
            info_row("Status", change_set.status),
          ]),
          div(class="mooncode-lane-grid change-set-grid", [
            render_mooncode_change_set_group("Diffs", change_set.diffs),
            render_mooncode_change_set_group("Tests", change_set.tests),
            render_mooncode_change_set_group("Artifacts", change_set.artifacts),
            render_mooncode_change_set_group("Review", change_set.reviews),
          ]),
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook change set has been recorded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_patch_set_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board patch-set-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "file review object"),
        h3("Patch Set"),
      ]),
      span(class="record-kind", model.mooncode_patch_set_status),
    ]),
    match model.mooncode_patch_set {
      Some(patch_set) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Patches", patch_set.patch_count.to_string()),
            info_chip("Pending", patch_set.pending_patch_count.to_string()),
            info_chip("Accepted", patch_set.accepted_patch_count.to_string()),
            info_chip("Rejected", patch_set.rejected_patch_count.to_string()),
            info_chip("Applied", patch_set.applied_patch_count.to_string()),
            info_chip("Reverted", patch_set.reverted_patch_count.to_string()),
            info_chip(
              "Runtime applied",
              patch_set.runtime_applied_patch_count.to_string(),
            ),
            info_chip(
              "Runtime proof",
              patch_set.runtime_patch_proof_count.to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Manifest", patch_set.manifest_path),
            info_row("Recorded", patch_set.recorded_at),
            info_row("Status", patch_set.status),
            info_row("Execution", patch_set.execution_status),
          ]),
          if patch_set.patches.length() == 0 {
            p(class="status-line", "no staged file patches")
          } else {
            div(
              class="mooncode-review-list patch-set-list",
              patch_set.patches[:mooncode_patch_set_limit(patch_set.patches)].map(
                patch => render_mooncode_patch_set_entry(dispatch, patch),
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook patch set has been recorded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_test_runs_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board test-runs-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "test/build object"),
        h3("Test Runs"),
      ]),
      span(class="record-kind", model.mooncode_test_runs_status),
    ]),
    match model.mooncode_test_runs {
      Some(test_runs) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Runs", test_runs.run_count.to_string()),
            info_chip("Passed", test_runs.passed_run_count.to_string()),
            info_chip("Failed", test_runs.failed_run_count.to_string()),
            info_chip("Running", test_runs.running_run_count.to_string()),
            info_chip("Queued", test_runs.queued_run_count.to_string()),
            info_chip("Verified", test_runs.verified_run_count.to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Manifest", test_runs.manifest_path),
            info_row("Recorded", test_runs.recorded_at),
            info_row("Status", test_runs.status),
          ]),
          if test_runs.runs.length() == 0 {
            p(class="status-line", "no test/build runs recorded")
          } else {
            div(
              class="mooncode-review-list test-run-list",
              test_runs.runs[:mooncode_test_run_limit(test_runs.runs)].map(run =>
                render_mooncode_test_run_entry(dispatch, run)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook test-run manifest has been recorded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_test_run_limit(entries : Array[MoonCodeTestRunEntry]) -> Int {
  if entries.length() > 6 {
    6
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_test_run_entry(
  dispatch : Dispatch[Msg],
  run : MoonCodeTestRunEntry,
) -> @rabbita.Html {
  let target = if run.target == "" {
    if run.path == "" { run.command } else { run.path }
  } else {
    run.target
  }
  div(class="mooncode-review-item " + run.run_state, [
    div(class="mooncode-review-head", [
      div([
        strong(if run.command == "" { run.title } else { run.command }),
        small(run.run_state + " / " + run.created_at),
      ]),
      div(class="toolbar-actions", [
        if run.path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(run.path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_tests", target)),
          "Rerun",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_build", target)),
          "Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("package", target)),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("commit", target)),
          "Commit",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Exit", run.exit_code.to_string()),
      info_chip("Verified", if run.verified { "yes" } else { "no" }),
      info_chip("Kind", run.kind),
    ]),
    if run.path != "" {
      code(run.path)
    } else if run.command != "" {
      code(run.command)
    } else {
      code(run.id)
    },
    p(class="mooncode-event-detail", run.detail),
  ])
}

///|
fn render_mooncode_package_candidates_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board package-candidate-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "MoonBook package candidates"),
        h3("Package Candidates"),
      ]),
      span(class="record-kind", model.mooncode_package_candidates_status),
    ]),
    match model.mooncode_package_candidates {
      Some(candidates) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Packages", candidates.package_count.to_string()),
            info_chip("Source-bound", candidates.source_bound_package_count.to_string()),
            info_chip("Missing source", candidates.missing_source_package_count.to_string()),
            info_chip(
              "Runtime verified",
              candidates.runtime_verified_package_count.to_string(),
            ),
            info_chip(
              "Runtime proof",
              candidates.runtime_package_proof_count.to_string(),
            ),
            info_chip(
              "Executable-ready",
              candidates.package_index_executable_ready_count.to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Status", candidates.status),
            info_row("Index", candidates.package_index_status),
            info_row("Index Path", empty_label(candidates.package_index_path)),
            info_row(
              "Index Sources",
              candidates.package_index_source_bound_count.to_string(),
            ),
            info_row(
              "Entry Points",
              if candidates.package_index_entry_points.length() == 0 {
                "none yet"
              } else {
                candidates.package_index_entry_points.join(", ")
              },
            ),
            info_row("Session", candidates.session_id),
            info_row("Task", empty_label(candidates.task_id)),
            info_row("Rule", candidates.rule),
          ]),
          if candidates.packages.length() == 0 {
            p(
              class="status-line",
              "no MoonBook package candidate has been recorded for this session yet",
            )
          } else {
            div(
              class="mooncode-review-list package-candidate-list",
              candidates.packages[:mooncode_package_candidate_limit(candidates.packages)].map(
                candidate =>
                  render_mooncode_package_candidate(dispatch, candidate),
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook package-candidate projection has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_package_candidate_limit(
  entries : Array[MoonCodePackageCandidate]
) -> Int {
  if entries.length() > 6 {
    6
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_package_candidate(
  dispatch : Dispatch[Msg],
  candidate : MoonCodePackageCandidate,
) -> @rabbita.Html {
  let target = if candidate.context_path == "" {
    candidate.manifest_path
  } else {
    candidate.context_path
  }
  div(class="mooncode-review-item " + candidate.source_inventory_status, [
    div(class="mooncode-review-head", [
      div([
        strong(if target == "" { candidate.package_kind } else { target }),
        small(
          candidate.package_kind +
          " / " +
          candidate.source_inventory_status +
          " / " +
          candidate.recorded_at,
        ),
      ]),
      div(class="toolbar-actions", [
        if candidate.manifest_path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(candidate.manifest_path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_tests", target)),
          "Test",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_build", target)),
          "Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("accept", target)),
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("package", target)),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("commit", target)),
          "Commit",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Sources", candidate.source_inventory_count.to_string()),
      info_chip("Ready", candidate.source_present_count.to_string()),
      info_chip("Command", empty_label(candidate.command_id)),
    ]),
    div(class="daemon-state compact-state", [
            info_row("Manifest", candidate.manifest_path),
            info_row("Receipt", empty_label(candidate.review_receipt_path)),
            info_row("Context", empty_label(candidate.context_path)),
            info_row("Execution", candidate.execution_state),
            info_row("Candidates", mooncode_candidate_paths_label(candidate.candidate_paths)),
          ]),
    div(class="mooncode-stats", [
      info_chip("Runtime built", candidate.runtime_built_count.to_string()),
      info_chip("Runtime verified", candidate.runtime_verified_count.to_string()),
      info_chip("Runtime proof", candidate.runtime_proof_count.to_string()),
      info_chip("Verified", if candidate.execution_verified { "yes" } else { "no" }),
    ]),
    render_mooncode_package_source_inventory(candidate.source_inventory),
    p(class="mooncode-event-detail", candidate.detail),
  ])
}

///|
fn mooncode_candidate_paths_label(paths : Array[String]) -> String {
  if paths.length() == 0 {
    "none"
  } else if paths.length() <= 3 {
    paths.join(", ")
  } else {
    paths[:3].join(", ") + " +" + (paths.length() - 3).to_string()
  }
}

///|
fn render_mooncode_package_source_inventory(
  records : Array[MoonCodePackageSourceRecord]
) -> @rabbita.Html {
  if records.length() == 0 {
    p(class="status-line", "no source inventory recorded")
  } else {
    div(
      class="mooncode-event-list compact package-source-list",
      records[:mooncode_package_source_limit(records)].map(record => {
        div(class="mooncode-event " + mooncode_package_source_state(record), [
          div(class="mooncode-event-head", [
            span(class="record-kind", record.kind),
            strong(record.path),
          ]),
          div(class="mooncode-stats", [
            info_chip("Exists", if record.exists { "yes" } else { "no" }),
            info_chip(
              "Ready",
              if record.package_ready { "yes" } else { "no" },
            ),
            info_chip("Size", mooncode_optional_int_label(record.size_bytes)),
            info_chip("SHA", mooncode_optional_hash_label(record.sha256)),
          ]),
        ])
      }),
    )
  }
}

///|
fn mooncode_package_source_limit(
  records : Array[MoonCodePackageSourceRecord]
) -> Int {
  if records.length() > 4 {
    4
  } else {
    records.length()
  }
}

///|
fn mooncode_package_source_state(
  record : MoonCodePackageSourceRecord
) -> String {
  if record.package_ready {
    "ready"
  } else if record.exists {
    "partial"
  } else {
    "missing"
  }
}

///|
fn mooncode_optional_int_label(value : Int?) -> String {
  match value {
    Some(number) => number.to_string()
    None => "none"
  }
}

///|
fn mooncode_optional_ratio_label(
  numerator : Int?,
  denominator : Int?,
) -> String {
  match (numerator, denominator) {
    (Some(proven), Some(expected)) => "\{proven}/\{expected}"
    _ => "none"
  }
}

///|
fn mooncode_optional_hash_label(value : String?) -> String {
  match value {
    Some(text) =>
      if text.length() > 12 {
        text[:12].to_owned()
      } else {
        text
      }
    None => "none"
  }
}

///|
fn render_mooncode_tool_authorization_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board tool-authorization-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "runtime authorization gate"),
        h3("Tool Authorization"),
      ]),
      span(class="record-kind", model.mooncode_tool_authorization_status),
    ]),
    div(class="toolbar-actions", [
      button(
        class="secondary-button",
        on_click=dispatch(ProbeMoonCodeToolAuthorization("read")),
        "Probe Read",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(ProbeMoonCodeToolAuthorization("write")),
        "Probe Write",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(ProbeMoonCodeToolAuthorization("shell")),
        "Probe Shell",
      ),
    ]),
    match model.mooncode_tool_authorization {
      Some(authorization) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Decision", authorization.decision),
            info_chip("Approval", authorization.approval),
            info_chip("State", authorization.approval_state),
            info_chip("Tool", authorization.tool_id),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Session", authorization.session_id),
            info_row("Target", empty_label(authorization.target)),
            info_row("Path", empty_label(authorization.path)),
            info_row("Command", empty_label(authorization.command)),
            info_row("Tool Call", empty_label(authorization.tool_call_id)),
            info_row(
              "Flags",
              "allowed=\{authorization.allowed}, requires_approval=\{authorization.requires_approval}, blocked=\{authorization.blocked}",
            ),
          ]),
          p(class="mooncode-event-detail", authorization.reason),
          render_mooncode_tool_authorization_approval_entry(authorization),
        ])
      None =>
        p(
          class="status-line",
          "Probe read, write, or shell to ask the MoonCode authorization endpoint for the current decision.",
        )
    },
  ])
}

///|
fn render_mooncode_tool_authorization_approval_entry(
  authorization : MoonCodeToolAuthorization
) -> @rabbita.Html {
  let entry = authorization.approval_entry
  let entry_state = json_field_string(entry, "approval_state", default="")
  if entry_state == "" {
    span(class="hidden-inline", "")
  } else {
    div(class="mooncode-wire-block", [
      div(class="mooncode-tool-head", [
        strong("Matching Approval"),
        span(class="record-kind", entry_state),
      ]),
      div(class="daemon-state compact-state", [
        info_row("Approval", json_field_string(entry, "approval", default="")),
        info_row("Tool", json_field_string(entry, "tool_id", default="")),
        info_row("Target", json_field_string(entry, "target", default="")),
        info_row("Path", json_field_string(entry, "path", default="")),
        info_row("Command", json_field_string(entry, "command", default="")),
      ]),
    ])
  }
}

///|
fn render_mooncode_tool_approvals_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board tool-approval-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "tool approval object"),
        h3("Tool Approvals"),
      ]),
      span(class="record-kind", model.mooncode_tool_approvals_status),
    ]),
    match model.mooncode_tool_approvals {
      Some(approvals) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Tools", approvals.approval_count.to_string()),
            info_chip("Pending", approvals.pending_approval_count.to_string()),
            info_chip("Approved", approvals.approved_approval_count.to_string()),
            info_chip("Rejected", approvals.rejected_approval_count.to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Manifest", approvals.manifest_path),
            info_row("Recorded", approvals.recorded_at),
            info_row("Status", approvals.status),
          ]),
          if approvals.approvals.length() == 0 {
            p(class="status-line", "no policy or review-gated tool calls")
          } else {
            div(
              class="mooncode-review-list tool-approval-list",
              approvals.approvals[:mooncode_tool_approval_limit(approvals.approvals)].map(
                approval =>
                  render_mooncode_tool_approval_entry(dispatch, approval),
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonBook tool approval manifest has been recorded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_tool_approval_limit(
  entries : Array[MoonCodeToolApprovalEntry]
) -> Int {
  if entries.length() > 6 {
    6
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_tool_approval_entry(
  dispatch : Dispatch[Msg],
  approval : MoonCodeToolApprovalEntry,
) -> @rabbita.Html {
  let target = if approval.target == "" {
    approval.event_id
  } else {
    approval.target
  }
  div(class="mooncode-review-item " + approval.approval_state, [
    div(class="mooncode-review-head", [
      div([
        strong(approval.title),
        small(
          approval.tool_id +
          " / " +
          approval.approval +
          " / " +
          approval.approval_state,
        ),
      ]),
      div(class="toolbar-actions", [
        if approval.path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(approval.path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("approve_tool", target)),
          "Approve",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("reject_tool", target)),
          "Reject",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Approves", approval.approved_review_count.to_string()),
      info_chip("Rejects", approval.rejected_review_count.to_string()),
    ]),
    div(class="mooncode-stats", [
      info_chip("Target", approval.target_kind),
      info_chip("Call", approval.target),
    ]),
    code(
      if approval.target_label != "" {
        approval.target_label
      } else if approval.path != "" {
        approval.path
      } else if approval.command != "" {
        approval.command
      } else {
        approval.event_id
      },
    ),
    p(class="mooncode-event-detail", approval.detail),
  ])
}

///|
fn mooncode_patch_set_limit(entries : Array[MoonCodePatchSetEntry]) -> Int {
  if entries.length() > 6 {
    6
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_patch_set_entry(
  dispatch : Dispatch[Msg],
  patch : MoonCodePatchSetEntry,
) -> @rabbita.Html {
  div(class="mooncode-review-item " + patch.review_state, [
    div(class="mooncode-review-head", [
      div([
        strong(if patch.path == "" { patch.title } else { patch.path }),
        small(patch.review_state + " / " + patch.created_at),
        small("execution: " + patch.execution_state),
      ]),
      div(class="toolbar-actions", [
        if patch.path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(patch.path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("accept", patch.path)),
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("reject", patch.path)),
          "Reject",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("apply_patch", patch.path)),
          "Apply",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("revert_patch", patch.path)),
          "Revert",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("package", patch.path)),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("commit", patch.path)),
          "Commit",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Gate", mooncode_optional_text_label(patch.gate_status)),
      info_chip("Next", mooncode_optional_text_label(patch.next_action)),
      info_chip("Accepts", patch.accepted_review_count.to_string()),
      info_chip("Rejects", patch.rejected_review_count.to_string()),
      info_chip("Applies", patch.applied_review_count.to_string()),
      info_chip("Reverts", patch.reverted_review_count.to_string()),
      info_chip("Runtime", patch.runtime_proof_count.to_string()),
      info_chip("Executed", if patch.execution_verified { "yes" } else { "no" }),
      info_chip("Packages", patch.package_review_count.to_string()),
      info_chip("Hunks", patch.hunk_count.to_string()),
    ]),
    match patch.blocked_reason {
      Some(reason) =>
        if reason == "" {
          span(class="hidden-inline", "")
        } else {
          p(class="mooncode-event-detail", reason)
        }
      None => span(class="hidden-inline", "")
    },
    render_mooncode_patch_hunks(dispatch, patch),
    if patch.diff_present {
      pre(class="source-block compact", code(patch.diff))
    } else {
      p(class="mooncode-event-detail", patch.detail)
    },
  ])
}

///|
fn render_mooncode_patch_hunks(
  dispatch : Dispatch[Msg],
  patch : MoonCodePatchSetEntry,
) -> @rabbita.Html {
  if patch.hunks.length() == 0 {
    p(class="status-line", "no hunk metadata")
  } else {
    div(
      class="mooncode-hunk-list",
      patch.hunks[:mooncode_patch_hunk_limit(patch.hunks)].map(hunk => {
        div(class="mooncode-hunk " + hunk.review_state, [
          div(class="mooncode-event-head", [
            span(class="record-kind", hunk.id),
            strong(if hunk.header == "" { "synthetic" } else { hunk.header }),
          ]),
          div(class="mooncode-stats", [
            info_chip("Gate", mooncode_optional_text_label(hunk.gate_status)),
            info_chip("Next", mooncode_optional_text_label(hunk.next_action)),
            info_chip("State", hunk.review_state),
            info_chip("Exec", hunk.execution_state),
            info_chip("+", hunk.added_lines.to_string()),
            info_chip("-", hunk.removed_lines.to_string()),
            info_chip("ctx", hunk.context_lines.to_string()),
            info_chip("Accepts", hunk.accepted_review_count.to_string()),
            info_chip("Rejects", hunk.rejected_review_count.to_string()),
            info_chip("Runtime", hunk.runtime_proof_count.to_string()),
          ]),
          div(class="toolbar-actions hunk-actions", [
            button(
              class="secondary-button",
              on_click=dispatch(RunMoonCodeCommandForPath("accept", hunk.target)),
              "Accept",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(RunMoonCodeCommandForPath("reject", hunk.target)),
              "Reject",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(
                RunMoonCodeCommandForPath("apply_patch", hunk.target),
              ),
              "Apply",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(
                RunMoonCodeCommandForPath("revert_patch", hunk.target),
              ),
              "Revert",
            ),
          ]),
          match hunk.blocked_reason {
            Some(reason) =>
              if reason == "" {
                span(class="hidden-inline", "")
              } else {
                small(class="status-line", reason)
              }
            None => span(class="hidden-inline", "")
          },
        ])
      }),
    )
  }
}

///|
fn mooncode_patch_hunk_limit(hunks : Array[MoonCodePatchHunk]) -> Int {
  if hunks.length() > 4 {
    4
  } else {
    hunks.length()
  }
}

///|
fn render_mooncode_change_set_group(
  title : String,
  entries : Array[MoonCodeChangeSetEntry],
) -> @rabbita.Html {
  div(class="mooncode-lane change-set-group", [
    div(class="mooncode-lane-title", [
      strong(title),
      span(class="record-kind", entries.length().to_string()),
    ]),
    if entries.length() == 0 {
      p(class="status-line", "none")
    } else {
      div(
        class="mooncode-event-list compact",
        entries[:mooncode_change_set_limit(entries)].map(entry =>
          render_mooncode_change_set_entry(entry)
        ),
      )
    },
  ])
}

///|
fn mooncode_change_set_limit(
  entries : Array[MoonCodeChangeSetEntry]
) -> Int {
  if entries.length() > 3 {
    3
  } else {
    entries.length()
  }
}

///|
fn render_mooncode_change_set_entry(
  entry : MoonCodeChangeSetEntry
) -> @rabbita.Html {
  div(class="mooncode-event " + entry.status, [
    div(class="mooncode-event-head", [
      span(class="record-kind", entry.status),
      strong(if entry.path == "" { entry.title } else { entry.path }),
    ]),
    if entry.command == "" {
      span(class="hidden-inline", "")
    } else {
      code(entry.command + " -> " + entry.exit_code.to_string())
    },
    if entry.diff == "" {
      p(class="mooncode-event-detail", entry.detail)
    } else {
      pre(class="source-block compact", code(entry.diff))
    },
  ])
}

///|
fn mooncode_review_limit(events : Array[MoonCodeEvent]) -> Int {
  if events.length() > 6 {
    6
  } else {
    events.length()
  }
}

///|
fn render_mooncode_review_item(
  dispatch : Dispatch[Msg],
  event : MoonCodeEvent,
) -> @rabbita.Html {
  div(class="mooncode-review-item " + event.status, [
    div(class="mooncode-review-head", [
      div([
        strong(if event.path == "" { event.title } else { event.path }),
        small(event.status + " / " + event.created_at),
      ]),
      div(class="toolbar-actions", [
        if event.path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(event.path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=if event.path == "" {
            dispatch(RunMoonCodeCommand("accept"))
          } else {
            dispatch(RunMoonCodeCommandForPath("accept", event.path))
          },
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=if event.path == "" {
            dispatch(RunMoonCodeCommand("reject"))
          } else {
            dispatch(RunMoonCodeCommandForPath("reject", event.path))
          },
          "Reject",
        ),
        button(
          class="secondary-button",
          on_click=if event.path == "" {
            dispatch(RunMoonCodeCommand("package"))
          } else {
            dispatch(RunMoonCodeCommandForPath("package", event.path))
          },
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=if event.path == "" {
            dispatch(RunMoonCodeCommand("commit"))
          } else {
            dispatch(RunMoonCodeCommandForPath("commit", event.path))
          },
          "Commit",
        ),
      ]),
    ]),
    if event.diff == "" {
      p(class="mooncode-event-detail", event.detail)
    } else {
      pre(class="source-block compact", code(event.diff))
    },
  ])
}

///|
fn mooncode_lane_events(
  session : AgentSession,
  lane : String,
) -> Array[MoonCodeEvent] {
  let events : Array[MoonCodeEvent] = []
  for event in session.mooncode_events {
    if event.lane == lane {
      events.push(event)
    }
  }
  events
}

///|
fn mooncode_lane_limit(events : Array[MoonCodeEvent]) -> Int {
  if events.length() > 4 {
    4
  } else {
    events.length()
  }
}

///|
fn mooncode_stream_buffer_limit() -> Int {
  80
}

///|
fn mooncode_merge_stream_events(
  existing : Array[MoonCodeEvent],
  incoming : Array[MoonCodeEvent],
) -> Array[MoonCodeEvent] {
  let merged : Array[MoonCodeEvent] = []
  for event in existing {
    mooncode_push_unique_stream_event(merged, event)
  }
  for event in incoming {
    mooncode_push_unique_stream_event(merged, event)
  }
  mooncode_trim_stream_events(merged, mooncode_stream_buffer_limit())
}

///|
fn mooncode_push_unique_stream_event(
  events : Array[MoonCodeEvent],
  event : MoonCodeEvent,
) -> Unit {
  if event.id != "" {
    for existing in events {
      if existing.id == event.id {
        return
      }
    }
  }
  events.push(event)
}

///|
fn mooncode_trim_stream_events(
  events : Array[MoonCodeEvent],
  limit : Int,
) -> Array[MoonCodeEvent] {
  if events.length() <= limit {
    events
  } else {
    let trimmed : Array[MoonCodeEvent] = []
    let start = events.length() - limit
    for index in start..<events.length() {
      trimmed.push(events[index])
    }
    trimmed
  }
}

///|
fn render_mooncode_event(event : MoonCodeEvent) -> @rabbita.Html {
  div(class="mooncode-event " + event.status, [
    div(class="mooncode-event-head", [
      span(class="record-kind", event.status),
      strong(event.title),
    ]),
    if event.path == "" {
      span(class="hidden-inline", "")
    } else {
      code(event.path)
    },
    if event.command == "" {
      span(class="hidden-inline", "")
    } else {
      code(event.command + " -> " + event.exit_code.to_string())
    },
    if event.diff == "" {
      p(class="mooncode-event-detail", event.detail)
    } else {
      pre(class="source-block compact", code(event.diff))
    },
  ])
}

///|
fn render_agent_inspector(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  aside(class="inspector-pane", [
    div(class="pane-heading compact", [
      div([p(class="eyebrow", "agent context"), h2("Session")]),
    ]),
    section(class="inspector-section", [
      h3("Book Scope"),
      info_row("Book", workspace_name(model)),
      info_row("Root", workspace_root(model)),
      info_row("Selected", model.selected_path),
      button(
        class="secondary-button full",
        on_click=dispatch(SendAgentMessage),
        mooncode_inspector_send_label(model),
      ),
    ]),
    section(class="inspector-section", [
      h3("Runtime"),
      match selected_agent_session(model) {
        Some(session) =>
          div(class="daemon-state", [
            info_row("Session", session.id),
            info_row("Task", empty_label(session.moonclaw_task_id)),
            info_row("Status", session.status),
            info_row("Model", empty_label(session.model)),
            info_row(
              "Port",
              if session.port > 0 {
                session.port.to_string()
              } else {
                "none"
              },
            ),
            info_row("Web", if session.web_search { "on" } else { "off" }),
            info_row("Queued", session.queued_count.to_string()),
            info_row("Updated", session.updated_at),
          ])
        None =>
          div(class="daemon-state", [
            info_row("Session", "new"),
            info_row("Task", "not attached"),
          ])
      },
      input(
        class="line-input",
        value=model.agent_model,
        placeholder=if model.agent_models.length() == 0 {
          "model (daemon not connected)"
        } else {
          model.agent_models[0].name
        },
        on_input=fn(value) { dispatch(SetAgentModel(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(ToggleAgentWebSearch),
          if model.agent_web_search {
            "Disable Web"
          } else {
            "Enable Web"
          },
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("cancel")),
          "Cancel",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_tests")),
          "Run Tests",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_build")),
          "Run Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("run_eval")),
          "Run Eval",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("package")),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("commit")),
          "Commit",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("accept")),
          "Accept",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommand("reject")),
          "Reject",
        ),
      ]),
    ]),
    render_mooncode_readiness(model),
    render_mooncode_capability_panel(model),
    section(class="inspector-section", [
      h3("Available Models"),
      if model.agent_models.length() == 0 {
        p(class="status-line", "none")
      } else {
        div(
          class="mini-list",
          model.agent_models.map(model_info => {
            button(
              class="mini-link",
              title=model_info.name,
              on_click=dispatch(SetAgentModel(model_info.name)),
              model_info.name,
            )
          }),
        )
      },
    ]),
  ])
}

///|
fn mooncode_inspector_send_label(model : Model) -> String {
  match selected_agent_session(model) {
    Some(session) if model.workspace_mode == WorkspaceMode::MoonCode =>
      mooncode_composer_button_label(model, Some(session)) + " MoonCode"
    Some(_) => "Send To Agent"
    None =>
      if model.workspace_mode == WorkspaceMode::MoonCode {
        "Start MoonCode"
      } else {
        "Send To Agent"
      }
  }
}

///|
fn render_mooncode_capability_panel(model : Model) -> @rabbita.Html {
  section(class="inspector-section", [
    h3("MoonCode Contract"),
    match model.mooncode_capabilities {
      Some(capabilities) =>
        div(class="mooncode-contract", [
          div(class="daemon-state", [
            info_row(
              "Version",
              "\{capabilities.component}.v\{capabilities.version}",
            ),
            info_row("Transport", capabilities.session_protocol.preferred_stream),
            info_row(
              "Target",
              capabilities.session_protocol.transport_target,
            ),
            info_row("Stream", capabilities.session_protocol.stream_endpoint),
            info_row(
              "Stream State",
              capabilities.session_protocol.stream_state_endpoint,
            ),
            info_row(
              "Command Queue",
              capabilities.session_protocol.command_queue_endpoint,
            ),
            info_row(
              "Runtime Replay",
              capabilities.session_protocol.runtime_replay_endpoint,
            ),
            info_row(
              "Runtime Claim",
              capabilities.session_protocol.runtime_claim_endpoint,
            ),
            info_row(
              "Event Sink",
              capabilities.session_protocol.runtime_event_ingest_endpoint,
            ),
            info_row(
              "Action Plan",
              capabilities.session_protocol.action_plan_endpoint,
            ),
            info_row(
              "Runtime Loop Options",
              capabilities.session_protocol.native_runtime_loop_options.stringify(),
            ),
            info_row(
              "Runtime",
              capabilities.runtime_contract.target_component +
              " / " +
              capabilities.runtime_contract.status,
            ),
            info_row("Engine", capabilities.engine_status.status),
            info_row("Bridge", capabilities.engine_status.bridge_mode),
            info_row("Adapter", capabilities.engine_status.adapter_status),
            info_row(
              "Commands",
              capabilities.command_specs.length().to_string(),
            ),
            info_row("Tools", capabilities.tool_specs.length().to_string()),
            info_row("Future", capabilities.extractable.future_package),
            info_row("Core", capabilities.extractable.core_package),
            info_row("Projection", capabilities.extractable.projection_package),
            info_row("Host", capabilities.extractable.host_package),
          ]),
          div(
            class="mooncode-command-row",
            capabilities.session_protocol.commands.map(command => {
              span(class="option-chip", command)
            }),
          ),
          render_mooncode_engine_status(capabilities.engine_status),
          render_mooncode_extraction_boundary(
            capabilities.extraction_boundary,
          ),
          render_mooncode_runtime_contract(capabilities.runtime_contract),
          render_mooncode_tool_call_wire_contract(
            capabilities.tool_call_wire,
          ),
          div(
            class="mooncode-tool-list",
            if capabilities.command_specs.length() == 0 {
              [p(class="status-line", "no command specs")]
            } else {
              capabilities.command_specs.map(spec =>
                render_mooncode_command_spec(spec)
              )
            },
          ),
          div(
            class="mooncode-tool-list",
            if capabilities.tool_specs.length() == 0 {
              [p(class="status-line", "no tool specs")]
            } else {
              capabilities.tool_specs.map(tool => render_mooncode_tool_spec(tool))
            },
          ),
          div(class="mooncode-output-roots", [
            small("Outputs"),
            p(capabilities.book_outputs.join(", ")),
          ]),
        ])
      None =>
        div(class="daemon-state", [
          info_row("Status", model.mooncode_status),
          info_row("Endpoint", "/api/mooncode/capabilities"),
        ])
    },
  ])
}

///|
fn render_mooncode_engine_status(
  engine : MoonCodeEngineStatus
) -> @rabbita.Html {
  let root_label = if engine.moonclaw_root == "" {
    "not configured"
  } else {
    engine.moonclaw_root
  }
  div(class="mooncode-engine-status", [
    div(class="mooncode-wire-block", [
      div(class="mooncode-tool-head", [
        strong("Engine readiness"),
        span(
          class=if engine.production_ready {
            "record-kind good"
          } else if engine.ok {
            "record-kind"
          } else {
            "record-kind warning"
          },
          engine.status,
        ),
      ]),
      p(engine.message),
      small("root: " + root_label),
      p(
        class="status-line",
        "adapter: " +
        engine.adapter_status +
        "; native runtime: " +
        (if engine.native_runtime_ready { "yes" } else { "no" }) +
        "; legacy task bridge: " +
        (if engine.legacy_task_bridge_ready { "yes" } else { "no" }),
      ),
      p(
        class="status-line",
        "endpoints: " + engine.supported_endpoints.join(", "),
      ),
    ]),
    div(
      class="mooncode-engine-checks",
      engine.checks.map(check => render_mooncode_engine_check(check)),
    ),
  ])
}

///|
fn render_mooncode_engine_check(
  check : MoonCodeEngineCheck
) -> @rabbita.Html {
  let class_name = match check.status {
    "ready" => "mooncode-eval-check ok"
    "bridged" => "mooncode-eval-check bridged"
    "blocked" => "mooncode-eval-check missing"
    _ => "mooncode-eval-check missing"
  }
  div(class=class_name, [
    span(
      class=match check.status {
        "ready" => "record-kind good"
        "bridged" => "record-kind"
        _ => "record-kind warning"
      },
      check.status,
    ),
    div([
      strong(check.label),
      small(check.evidence),
    ]),
  ])
}

///|
fn render_mooncode_extraction_boundary(
  boundary : MoonCodeExtractionBoundary
) -> @rabbita.Html {
  div(class="mooncode-runtime-contract", [
    div(class="mooncode-output-roots", [
      small("Extraction boundary"),
      p(
        "\{boundary.protocol}: \{boundary.portable_core_package} -> \{boundary.future_standalone_package}",
      ),
    ]),
    div(class="daemon-state compact-state", [
      info_row("Core", boundary.portable_core_package),
      info_row("Projection", boundary.moondesk_projection_package),
      info_row("MoonWiki Host", boundary.moonwiki_host_package),
      info_row("Standalone", boundary.future_standalone_package),
    ]),
    div(
      class="mooncode-tool-list",
      boundary.roles.map(role => render_mooncode_extraction_role(role)),
    ),
    ul(
      class="mooncode-evidence-list",
      boundary.rules.map(rule => li(rule)),
    ),
  ])
}

///|
fn render_mooncode_extraction_role(
  role : MoonCodeExtractionRole
) -> @rabbita.Html {
  div(class="mooncode-tool-card", [
    div(class="mooncode-tool-head", [
      strong(role.id),
      span(class="record-kind", role.owner),
    ]),
    small(role.package),
    p(role.responsibility),
  ])
}

///|
fn render_mooncode_namespace_role(role : MoonCodeNamespaceRole) -> @rabbita.Html {
  div(class="mooncode-tool-card", [
    div(class="mooncode-tool-head", [
      strong(role.name),
      span(class="record-kind", role.id),
    ]),
    p(role.responsibility),
  ])
}

///|
fn render_mooncode_runtime_contract(
  contract : MoonCodeRuntimeContract
) -> @rabbita.Html {
  div(class="mooncode-runtime-contract", [
    div(class="mooncode-output-roots", [
      small("Runtime boundary"),
      p(
        "\{contract.reference} -> \{contract.target_component}; extractable as \{contract.extractable_component}",
      ),
    ]),
    div(class="mooncode-wire-block", [
      div(class="mooncode-tool-head", [
        strong("Namespace roles"),
        span(class="record-kind", "one product boundary"),
      ]),
      div(
        class="mooncode-tool-list",
        contract.namespace_roles.map(role =>
          render_mooncode_namespace_role(role)
        ),
      ),
    ]),
    div(
      class="mooncode-tool-list",
      contract.components.map(component =>
        render_mooncode_runtime_component(component)
      ),
    ),
    div(class="mooncode-wire-block", [
      div(class="mooncode-tool-head", [
        strong("Wire protocol"),
        span(class="record-kind", contract.wire_protocol.transport),
      ]),
      div(
        class="mooncode-command-row",
        contract.wire_protocol.input_commands.map(command =>
          span(
            class="option-chip",
            command.command + " {" + command.required_fields.join(", ") + "}",
          )
        ),
      ),
      small(contract.wire_protocol.ordering_rule),
      p(
        class="status-line",
        "events: " + contract.wire_protocol.output_events.join(", "),
      ),
    ]),
    div(class="mooncode-wire-block", [
      div(class="mooncode-tool-head", [
        strong("Session store"),
        span(class="record-kind", contract.session_store.owner),
      ]),
      p(contract.session_store.shape),
      small("resume: " + contract.session_store.resume_modes.join(", ")),
      p(class="status-line", contract.session_store.moondesk_projection),
    ]),
    render_mooncode_tool_contract(contract.tool_contract),
    div(class="mooncode-wire-block", [
      div(class="mooncode-tool-head", [
        strong("Eval contract"),
        span(
          class="record-kind",
          contract.eval_contract.required_harnesses.join(" + "),
        ),
      ]),
      ul(
        class="mooncode-evidence-list",
        contract.eval_contract.minimum_evidence.map(item => li(item)),
      ),
      div(class="daemon-state compact-state", [
        info_row(
          "Harness Contract",
          contract.eval_contract.harness_contract_endpoint,
        ),
        info_row(
          "OpenSeek Refs",
          contract.eval_contract.reference_paths.join(", "),
        ),
        info_row(
          "Native Owner",
          contract.eval_contract.native_eval_report.owner,
        ),
        info_row(
          "Native Endpoint",
          contract.eval_contract.native_eval_report.endpoint,
        ),
        info_row(
          "Transport",
          contract.eval_contract.native_eval_report.transport,
        ),
        info_row(
          "Status",
          contract.eval_contract.native_eval_report.status_values.join(", "),
        ),
      ]),
      small(contract.eval_contract.native_eval_report.normalization_rule),
      p(class="status-line", contract.eval_contract.current_gap),
    ]),
  ])
}

///|
fn render_mooncode_tool_contract(contract : MoonCodeToolContract) -> @rabbita.Html {
  div(class="mooncode-wire-block", [
    div(class="mooncode-tool-head", [
      strong("Tool contract"),
      span(class="record-kind", contract.execution_owner),
    ]),
    p(
      "\{contract.supported_tools.length()} tools; approvals by \{contract.approval_owner}; artifacts by \{contract.artifact_owner}",
    ),
    div(
      class="mooncode-tool-list",
      contract.tools.map(tool => render_mooncode_tool_contract_spec(tool)),
    ),
    div(class="daemon-state compact-state", [
      info_row("Path Rule", contract.constraints.path_rule),
      info_row("Diff Rule", contract.constraints.diff_rule),
      info_row("Test Rule", contract.constraints.test_rule),
      info_row("Approval Rule", contract.constraints.approval_rule),
    ]),
    small(contract.constraints.extraction_rule),
  ])
}

///|
fn render_mooncode_tool_call_wire_contract(
  contract : MoonCodeToolCallWireContract
) -> @rabbita.Html {
  div(class="mooncode-wire-block", [
    div(class="mooncode-tool-head", [
      strong("Tool-call wire"),
      span(class="record-kind", contract.runtime_owner),
      span(class="record-kind", contract.protocol),
    ]),
    p(
      "accepts " +
      contract.accepted_shapes.length().to_string() +
      " shapes; " +
      contract.supported_tools.length().to_string() +
      " bounded tools",
    ),
    div(
      class="mooncode-command-row",
      contract.supported_tools.map(tool => span(class="option-chip", tool)),
    ),
    ul(
      class="mooncode-evidence-list",
      contract.accepted_shapes.map(shape => li(shape)),
    ),
    div(class="daemon-state compact-state", [
      info_row("Owner", contract.owner),
      info_row("Runtime Owner", contract.runtime_owner),
      info_row("Reference", contract.reference),
    ]),
    small(contract.argument_rule),
    p(class="status-line", contract.unknown_tool_policy),
  ])
}

///|
fn render_mooncode_tool_contract_spec(
  tool : MoonCodeToolRuntimeContract
) -> @rabbita.Html {
  let badges : Array[@rabbita.Html] = [
    span(class="record-kind", tool.lane),
    span(class="record-kind", tool.approval),
  ]
  let badges = if tool.mutates_files {
    badges + [span(class="record-kind warning", "mutates files")]
  } else {
    badges
  }
  let badges = if tool.requires_review {
    badges + [span(class="record-kind", "review")]
  } else {
    badges
  }
  div(class="mooncode-tool-spec", [
    div(class="mooncode-tool-head", [strong(tool.id)] + badges),
    p(tool.safety_policy),
    small("inputs: " + mooncode_tool_field_summary(tool.input_fields)),
    p(class="status-line", "events: " + tool.output_events.join(", ")),
    small(tool.executable_boundary),
  ])
}

///|
fn mooncode_tool_field_summary(
  fields : Array[Json]
) -> String {
  if fields.length() == 0 {
    return "none"
  }
  fields
  .map(field =>
    if json_field_bool(field, "required", default=false) {
      json_field_string(field, "name", default="field") +
      ":" +
      json_field_string(field, "type", default="value")
    } else {
      json_field_string(field, "name", default="field") +
      "?:" +
      json_field_string(field, "type", default="value")
    }
  )
  .join(", ")
}

///|
fn render_mooncode_runtime_component(
  component : MoonCodeRuntimeComponent
) -> @rabbita.Html {
  div(class="mooncode-tool-spec", [
    div(class="mooncode-tool-head", [
      strong(component.id),
      span(class="record-kind", component.owner),
    ]),
    p(component.purpose),
    small(component.reference),
    p(class="status-line", component.moondesk_role),
  ])
}

///|
fn render_mooncode_command_spec(spec : MoonCodeCommandSpec) -> @rabbita.Html {
  div(class="mooncode-tool-spec", [
    div(class="mooncode-tool-head", [
      strong(spec.action),
      span(class="record-kind", spec.dispatch),
    ]),
    p(
      "approval: \{spec.approval}; lanes: \{spec.expected_lanes.join(", ")}",
    ),
    small("tools: \{spec.tool_hints.join(", ")}"),
  ])
}

///|
fn render_mooncode_tool_spec(tool : MoonCodeToolSpec) -> @rabbita.Html {
  div(class="mooncode-tool-spec", [
    div(class="mooncode-tool-head", [
      strong(tool.id),
      span(class="record-kind", tool.lane),
    ]),
    p(tool.purpose),
    small(
      "\{tool.owner} / approval: \{tool.approval} / outputs: \{tool.outputs.join(", ")}",
    ),
  ])
}

///|
fn render_mooncode_readiness(model : Model) -> @rabbita.Html {
  section(class="inspector-section", [
    h3("MoonCode Readiness"),
    match selected_agent_session(model) {
      Some(session) => {
        let summary = session.mooncode_summary
        div(class="mooncode-readiness", [
          div(class="daemon-state", [
            info_row("Protocol", summary.protocol),
            info_row("Component", summary.extractable_component),
            info_row("Dispatch", summary.dispatch_mode),
            info_row("Stream", summary.stream_url),
            info_row("Stream Mode", summary.stream_mode),
            info_row("Stream Source", summary.stream_source),
            info_row(
              "Incremental",
              if summary.incremental_stream_ready {
                summary.incremental_stream_url
              } else {
                "not ready"
              },
            ),
            info_row(
              "Live Stream",
              if summary.live_stream_ready {
                summary.live_stream_url
              } else {
                "not ready"
              },
            ),
            info_row("Stream State", summary.stream_state_url),
            info_row(
              "Append Log",
              if summary.append_log_ready {
                "\{summary.append_log_count} event(s)"
              } else {
                "empty"
              },
            ),
            info_row("Log Path", summary.event_log_path),
            info_row(
              "Command Queue",
              if summary.command_log_ready {
                "\{summary.command_log_count} command(s)"
              } else {
                "empty"
              },
            ),
            info_row("Command Path", summary.command_log_path),
            info_row(
              "Runtime Feed",
              if summary.runtime_command_feed_ready {
                "\{summary.runtime_command_count} command(s)"
              } else {
                "empty"
              },
            ),
            info_row("Runtime Path", summary.runtime_command_log_path),
            info_row(
              "Runtime Dispatch",
              if summary.runtime_dispatch_ready {
                "\{summary.runtime_dispatch_count} receipt(s)"
              } else {
                "empty"
              },
            ),
            info_row("Dispatch Path", summary.runtime_dispatch_log_path),
            info_row(
              "Session Snapshot",
              if summary.session_snapshot_ready {
                summary.session_snapshot_path
              } else {
                "missing"
              },
            ),
            info_row(
              "Eval",
              "\{summary.eval_level} / \{summary.eval_score}",
            ),
            info_row(
              "Production Grade",
              "\{summary.production_level} / \{summary.production_score} (\{summary.production_passed_check_count}/\{summary.production_check_count})",
            ),
            info_row(
              "Next Production Action",
              json_string_value(
                summary.production_readiness,
                "next_action",
                default="inspect_production_check",
              ),
            ),
            info_row(
              "Next Owner",
              json_string_value(
                summary.production_readiness,
                "next_owner",
                default="mooncode",
              ),
            ),
            info_row(
              "First Blocker",
              json_string_value(
                summary.production_readiness,
                "first_blocker_label",
                default="none",
              ),
            ),
            info_row(
              "Blocker Evidence",
              json_string_value(
                summary.production_readiness,
                "first_blocker_evidence",
                default="none",
              ),
            ),
            info_row("Events", summary.event_count.to_string()),
            info_row("Transcript", summary.transcript_count.to_string()),
            info_row("Runtime", summary.runtime_count.to_string()),
            info_row("Tools", summary.tool_count.to_string()),
            info_row("Diffs", summary.diff_count.to_string()),
            info_row("Tests", summary.test_count.to_string()),
            info_row("Verified Tests", summary.verified_test_count.to_string()),
            info_row("Failed Tests", summary.failed_test_count.to_string()),
            info_row("Artifacts", summary.artifact_count.to_string()),
            info_row(
              "Source-bound Packages",
              summary.source_bound_package_count.to_string(),
            ),
            info_row(
              "Package Execution",
              "\{summary.runtime_verified_package_count} verified / \{summary.runtime_package_proof_count} proof event(s)",
            ),
            info_row(
              "Commit Execution",
              "\{summary.runtime_commit_proof_count} proof event(s)",
            ),
            info_row(
              "Steering",
              "\{summary.pending_steer_count} pending / \{summary.deferred_steer_count} deferred / \{summary.steer_settlement_count} settled",
            ),
            info_row("Review", summary.review_count.to_string()),
            info_row("Review State", summary.review_state),
            info_row("Pending Diffs", summary.pending_diff_count.to_string()),
            info_row("Accepted", summary.accepted_review_count.to_string()),
            info_row("Rejected", summary.rejected_review_count.to_string()),
            info_row(
              "Package",
              if summary.has_packaging_candidate {
                "candidate available"
              } else {
                "none yet"
              },
            ),
            info_row(
              "Manifest",
              "\{summary.moonbook_package_manifest_count} package manifest(s)",
            ),
            info_row(
              "Package Index",
              "\{summary.moonbook_package_index_manifest_count} manifest(s)",
            ),
            info_row(
              "Change Set",
              "\{summary.moonbook_change_set_manifest_count} manifest(s)",
            ),
            info_row(
              "Patch Set",
              "\{summary.moonbook_patch_set_manifest_count} manifest(s)",
            ),
            info_row(
              "Patch Execution",
              "\{summary.runtime_patch_execution_proof_count} runtime proof event(s)",
            ),
            info_row(
              "Tool Approvals",
              "\{summary.moonbook_tool_approvals_manifest_count} manifest(s), \{summary.pending_tool_approval_count} pending",
            ),
            info_row(
              "Test Runs",
              "\{summary.moonbook_test_runs_manifest_count} manifest(s)",
            ),
            info_row(
              "Eval Report",
              "\{summary.moonbook_eval_report_manifest_count} manifest(s)",
            ),
            info_row(
              "Runtime Handoff",
              "\{summary.mooncode_runtime_handoff_manifest_count} manifest(s)",
            ),
          ]),
          div(class="mooncode-output-roots", [
            small("Production-grade checklist"),
            render_mooncode_eval_checks(summary.production_checks),
          ]),
          div(class="mooncode-output-roots", [
            small("Eval-readiness checklist"),
            render_mooncode_eval_checks(summary.eval_checks),
          ]),
        ])
      }
      None =>
        div(class="daemon-state", [
          info_row("Protocol", "mooncode.v1"),
          info_row("Session", "none"),
        ])
    },
  ])
}

///|
fn render_mooncode_eval_checks(
  checks : Array[MoonCodeEvalCheck]
) -> @rabbita.Html {
  if checks.length() == 0 {
    p(class="status-line", "no eval checks")
  } else {
    div(
      class="mooncode-eval-list",
      checks.map(check => {
        div(
          class=if check.ok {
            "mooncode-eval-check ok"
          } else {
            "mooncode-eval-check missing"
          },
          [
            span(
              class=if check.ok { "record-kind good" } else { "record-kind" },
              if check.ok { "ok" } else { "missing" },
            ),
            div([
              strong(check.label),
              small(check.evidence),
            ]),
          ],
        )
      }),
    )
  }
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
      info_row(
        "Writable",
        if is_inbox_path(model.selected_path) {
          "yes"
        } else {
          "inbox only"
        },
      ),
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
      button(
        class="secondary-button full",
        on_click=dispatch(TagSelection),
        "Tag Selection",
      ),
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
      None => p(class="status-line", "waiting for diff")
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
      tags.map(tag => {
        span(
          class="option-chip active",
          title="\{tag.id} / \{tag.created_at}",
          tag.tag,
        )
      }),
    )
  }
}

///|
fn selection_tags(model : Model) -> Array[TagRecord] {
  let selected : Array[TagRecord] = []
  for tag in model.tags {
    if tag.workspace_id == model.selected_workspace_id &&
      tag.path == model.selected_path {
      selected.push(tag)
    }
  }
  selected
}

///|
fn render_path_list(
  dispatch : Dispatch[Msg],
  paths : Array[String],
) -> @rabbita.Html {
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
    div(
      class="drawer-tabs",
      drawer_tabs().map(tab => {
        let class_name = if tab.key == model.drawer_tab {
          "drawer-tab active"
        } else {
          "drawer-tab"
        }
        button(
          class=class_name,
          on_click=dispatch(SelectDrawerTab(tab.key)),
          tab.label,
        )
      }),
    ),
    div(
      class="drawer-records drawer-records-single",
      match model.drawer_tab {
        DrawerTab::DrawerRequests => [render_request_drawer(model)]
        DrawerTab::DrawerMessages => [render_message_drawer(model)]
        DrawerTab::DrawerRuns => [render_run_drawer(dispatch, model)]
        DrawerTab::DrawerAgents => [render_agent_drawer(dispatch, model)]
        DrawerTab::DrawerRecent => [render_recent_drawer(dispatch, model)]
      },
    ),
  ])
}

///|
fn render_request_drawer(model : Model) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "requests"),
    div([
      h3("\{model.requests.length()} staged"),
      p(
        if model.requests.length() == 0 {
          "No Moondesk requests staged yet."
        } else {
          request_title(model.requests[model.requests.length() - 1])
        },
      ),
    ]),
  ])
}

///|
fn render_message_drawer(model : Model) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "town"),
    div([
      h3("\{model.town_messages.length()} messages"),
      p(
        if model.town_messages.length() == 0 {
          "No recent town messages."
        } else {
          let message = model.town_messages[model.town_messages.length() - 1]
          "\{message.kind} \{message.id}: \{message.title} (\{message.path})"
        },
      ),
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
fn render_agent_drawer(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "agents"),
    div([
      h3("\{model.agent_sessions.length()} sessions"),
      match selected_agent_session(model) {
        Some(session) =>
          button(
            class="mini-link inline",
            on_click=dispatch(SelectActivity(Activity::Agents)),
            "\{session.title} / \{session.status}",
          )
        None => p("No agent session selected.")
      },
    ]),
  ])
}

///|
fn render_recent_drawer(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(class="drawer-record", [
    span(class="record-kind", "recent"),
    div([
      h3("\{model.recent_paths.length()} paths"),
      if model.recent_paths.length() == 0 {
        p("No recent paths yet.")
      } else {
        div(
          class="mini-list",
          model.recent_paths.map(path => {
            button(
              class="mini-link",
              on_click=dispatch(OpenQuickPath(path)),
              path,
            )
          }),
        )
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
          palette_command(
            dispatch,
            "Search Books",
            "Find files across MoonBooks",
            SelectActivity(Activity::Search),
          ),
          palette_command(
            dispatch,
            "Create Inbox Note",
            "Stage a safe draft in inbox",
            SelectActivity(Activity::Inbox),
          ),
          palette_command(
            dispatch,
            "Import URL",
            "Open the inbox importer",
            SelectActivity(Activity::Inbox),
          ),
          palette_command(
            dispatch,
            "Talk To Agent",
            "Open a book-scoped MoonClaw coding session",
            SelectActivity(Activity::Agents),
          ),
          palette_command(
            dispatch,
            "Submit to Town",
            "Send selected context to Moontown",
            SubmitRequest,
          ),
          palette_command(
            dispatch,
            "PDF Evidence Watch",
            "Publish a research-book with PDF sources, analysis method, skills, and standing watch",
            SelectActivity(Activity::Town),
          ),
          palette_command(
            dispatch,
            "Run Daemon Tick",
            "Dispatch one Moontown scheduler tick",
            DispatchDaemonTick,
          ),
          palette_command(
            dispatch,
            "Start Daemon",
            "Start the managed Moontown daemon loop",
            StartDaemon,
          ),
          palette_command(
            dispatch,
            "Enable Supervision",
            "Restart the daemon when the policy says it should run",
            EnableDaemonSupervision,
          ),
          palette_command(
            dispatch,
            "Stop Daemon",
            "Stop the managed Moontown daemon loop",
            StopDaemon,
          ),
          palette_command(
            dispatch,
            "Show Run Artifacts",
            "Open MoonClaw run projection",
            SelectActivity(Activity::Runs),
          ),
          palette_command(
            dispatch,
            "Daily Surface",
            "Open operating summary",
            SelectActivity(Activity::Settings),
          ),
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
  let status = if model.loading {
    "loading workspace"
  } else {
    model.host_status
  }
  header(class="title-bar", [
    div(class="title-copy", [
      span(class="app-dot", ""),
      h1("Moondesk"),
      span(class="workspace-switcher", workspace_name(model)),
      span(class="mode-caption", workspace_mode_summary(model.workspace_mode)),
    ]),
    div(class="workspace-mode-toggle", [
      button(
        class=workspace_mode_button_class(model, WorkspaceMode::MoonWiki),
        title="Switch to the MoonWiki book workspace",
        on_click=dispatch(SelectWorkspaceMode(WorkspaceMode::MoonWiki)),
        "MoonWiki",
      ),
      button(
        class=workspace_mode_button_class(model, WorkspaceMode::MoonCode),
        title="Switch to the MoonCode coding workspace",
        on_click=dispatch(SelectWorkspaceMode(WorkspaceMode::MoonCode)),
        "MoonCode",
      ),
    ]),
    button(
      class="command-button",
      on_click=dispatch(ToggleCommand),
      "Command Palette",
    ),
    div(class="sync-status", [span(class="status-dot live", ""), span(status)]),
  ])
}

///|
fn workspace_mode_button_class(model : Model, mode : WorkspaceMode) -> String {
  if model.workspace_mode == mode {
    "mode-button active"
  } else {
    "mode-button"
  }
}

///|
fn render_app(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  let code_mode = model.workspace_mode == WorkspaceMode::MoonCode
  let center = if code_mode {
    render_agent_center(dispatch, model)
  } else {
    render_preview_center(dispatch, model)
  }
  let inspector = if code_mode {
    render_agent_inspector(dispatch, model)
  } else {
    render_inspector(dispatch, model)
  }
  let side = if code_mode {
    render_agents_pane(dispatch, model)
  } else {
    render_explorer(dispatch, model)
  }
  div(class="desk-shell", [
    render_title_bar(dispatch, model),
    div(class="desk-main", [
      render_activity_rail(dispatch, model),
      side,
      center,
      inspector,
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
  ignore(fetch_agent_daemon_cmd)
  ignore(fetch_agent_models_cmd)
  ignore(fetch_agent_sessions_cmd)
  ignore(fetch_mooncode_capabilities_cmd)
  ignore(fetch_book_patterns_cmd)
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
  ignore(create_agent_session_cmd)
  ignore(send_agent_message_cmd)
  ignore(cancel_agent_session_cmd)
  ignore(schedule_agent_poll)
  ignore(pick_import_files_cmd)
  ignore(take_dropped_imports_cmd)
  ignore(schedule_import_drop_poll)
  ignore(reveal_selection_cmd)
  ignore(notify_cmd)
}

///|
fn main {
  let (dispatch, cell) = @rabbita.cell_with_dispatch(
    model=init_model(),
    update~,
    view=(dispatch, model) => render_app(dispatch, model),
  )
  let app = @rabbita.new(cell)
  app.with_init(
    @rabbita.batch([
      fetch_workspaces_cmd(dispatch),
      fetch_agent_daemon_cmd(dispatch),
      fetch_agent_models_cmd(dispatch),
      fetch_agent_sessions_cmd(dispatch, ""),
      fetch_mooncode_capabilities_cmd(dispatch),
      fetch_book_base_types_cmd(dispatch),
      fetch_book_patterns_cmd(dispatch),
      schedule_agent_poll(dispatch),
      schedule_import_drop_poll(dispatch),
    ]),
  )
  app.mount("app")
}
