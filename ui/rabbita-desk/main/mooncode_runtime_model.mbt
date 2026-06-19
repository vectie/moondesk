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
  daemon_status : String
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
  status : String
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
  status : String
  workspace_root : String
  runtime_session_id : String
  manifest_path : String
  resume_contract : MoonCodeResumeContract
  command_count : Int
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
struct MoonCodeQueuedCommand {
  command_id : String
  action : String
  dispatch : String
  approval : String
  created_at : String
  context_path : String
  target : String
  message : String
  web_search : Bool
  expected_lanes : Array[String]
  tool_hints : Array[String]
} derive(FromJson)

///|
struct MoonCodeCommandQueue {
  session_id : String
  runtime_session_id : String
  command_log_path : String
  command_count : Int
  commands : Array[MoonCodeQueuedCommand]
  ordering_rule : String
} derive(FromJson)

///|
struct MoonCodeRuntimeDispatchReceipt {
  dispatch_id : String
  command_id : String
  action : String
  dispatch : String
  status : String
  dispatch_mode : String
  created_at : String
  mooncode_command_valid : Bool
  native_mooncode_endpoint : String
  detail : String
  runtime_command : Json
  previous_dispatch_status : String?
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
  session_id : String
  runtime_session_id : String
  dispatch_mode : String
  runtime_command_count : Int
  runtime_dispatch_count : Int
  runtime_dispatch_pending_count : Int
  runtime_command_log_path : String
  runtime_dispatch_log_path : String
  dispatch_receipts : Array[MoonCodeRuntimeDispatchReceipt]
  pending_command_ids : Array[String]
} derive(FromJson)

///|
struct MoonCodeRuntimeCommandFeed {
  runtime_session_id : String
  runtime_command_log_path : String
  runtime_command_count : Int
  runtime_dispatch_log_path : String
  runtime_claim_endpoint : String
  runtime_dispatch_count : Int
  runtime_dispatch_pending_count : Int
  commands : Array[Json]
  execution_summaries : Array[Json]
  command_lifecycle : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeReplayItem {
  command_id : String
  action : String
  dispatch : String
  serve_command : String
  created_at : String
  target : String
  receipt_status : String
  replay_status : String
  previous_claim_expired : Bool
  latest_receipt : Json
  proof_event_count : Int
  submitted_event_count : Int
  normalized_event_count : Int
  runtime_event_summary : Json
  decode_report : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeReplayState {
  runtime_command_log_path : String
  runtime_dispatch_log_path : String
  command_count : Int
  invalid_command_count : Int
  delivered_command_count : Int
  claimed_command_count : Int
  failed_dispatch_count : Int
  pending_command_count : Int
  first_pending_index : Int
  first_invalid_command_id : String
  replay_ready : Bool
  replay_policy : String
  pending_commands : Array[MoonCodeRuntimeReplayItem]
  pending_mooncode_jsonl : String
} derive(FromJson)

///|
struct MoonCodeRuntimeServiceState {
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
  session_id : String
  event_log_path : String
  event_count : Int
  events : Array[MoonCodeEvent]
  command_progress : Json
  unscoped_progress : Json
  runtime_service : MoonCodeRuntimeServiceState
  post_contract : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeClaimItem {
  command_id : String
  action : String
  dispatch : String
  serve_command : String
  created_at : String
  target : String
  claim_status : String
  receipt_status : String
  tool_authorization_state : String
  runtime_may_execute_tools : Bool
  tool_authorization_blocked : Bool
  tool_authorization_blocked_reason : String
  blocked_by_command_id : String
  blocked_by_status : String
  consumer_id : String
  claimed_at : String
  lease_expires_at : String
  ack_endpoint : String
  runtime_command : Json
} derive(FromJson)

///|
struct MoonCodeRuntimeClaimState {
  runtime_command_log_path : String
  runtime_dispatch_log_path : String
  command_count : Int
  claimable_command_count : Int
  claimed_command_count : Int
  delivered_command_count : Int
  failed_command_count : Int
  invalid_command_count : Int
  order_blocked_command_count : Int
  tool_authorization_blocked_command_count : Int
  claim_endpoint : String
  ack_endpoint : String
  lease_policy : String
  claimable_commands : Array[MoonCodeRuntimeClaimItem]
  claimed_commands : Array[MoonCodeRuntimeClaimItem]
  order_blocked_commands : Array[MoonCodeRuntimeClaimItem]
  tool_authorization_blocked_commands : Array[MoonCodeRuntimeClaimItem]
} derive(FromJson)
