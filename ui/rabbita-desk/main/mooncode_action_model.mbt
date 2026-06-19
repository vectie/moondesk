///|
struct MoonCodeActionPlanItem {
  command_id : String
  action : String
  control : String
  approval : String
  state : String
  runtime_state : String
  created_at : String
  target : String
  context_path : String
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
  control : String
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
  status : String
  runtime_session_id : String
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
  deferred_steer_count : Int
  next_required_action : String
  readiness : Json
  recommended_command : MoonCodeActionPlanRecommendedCommand
  recommended_commands : Array[MoonCodeActionPlanRecommendedCommand]
  actions : Array[MoonCodeActionPlanItem]
  acceptance_gates : MoonCodeActionPlanGates
  rule : String
} derive(FromJson)

///|
struct MoonCodeRuntimeEvidenceItem {
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
  runtime_session_id : String
  recorded_at : String
  command_count : Int
  proven_command_count : Int
  missing_evidence_command_count : Int
  failed_evidence_command_count : Int
  required_event_count : Int
  proven_required_event_count : Int
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
