///|
struct MoonCodeSummary {
  protocol : String
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
  steer_settlement_count : Int
  deferred_steer_count : Int
  pending_steer_count : Int
  steering_lifecycle : Json
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
  mooncode_runtime_handoff_manifest_count : Int
  pending_tool_approval_count : Int
  standalone_component : String
  eval_passed_check_count : Int
  eval_check_count : Int
  eval_missing_check_count : Int
  eval_checks : Array[MoonCodeEvalCheck]
  readiness_passed_check_count : Int
  readiness_check_count : Int
  readiness_blocked_count : Int
  readiness : Json
  readiness_checks : Array[MoonCodeEvalCheck]
} derive(FromJson)

///|
struct MoonCodeEvalCheck {
  label : String
  ok : Bool
  evidence : String
} derive(FromJson)

///|
struct MoonCodeReadiness {
  readiness : Json
  passed_count : Int
  check_count : Int
  blocked_count : Int
  checks : Array[MoonCodeEvalCheck]
  endpoint : String
} derive(FromJson)

///|
struct MoonCodeEvalReport {
  status : String
  runtime_session_id : String
  runtime_owner : String
  ui_owner : String
  artifact_owner : String
  standalone_component : String
  recorded_at : String
  manifest_path : String
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
