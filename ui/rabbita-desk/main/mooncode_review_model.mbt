///|
struct MoonCodeStreamPoll {
  stream : String
  stream_source : String
  next_since : Int
  emitted_count : Int
  events : Array[MoonCodeEvent]
}

///|
struct MoonCodeStreamState {
  consumer_id : String
  latest_sequence : Int
  next_since : Int
} derive(FromJson)

///|
struct MoonCodeChangeSetEntry {
  title : String
  status : String
  path : String
  command : String
  exit_code : Int
  detail : String
  diff : String
} derive(FromJson)

///|
struct MoonCodeChangeSet {
  status : String
  recorded_at : String
  manifest_path : String
  diff_count : Int
  test_count : Int
  artifact_count : Int
  review_count : Int
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
  path : String
  title : String
  review_state : String
  execution_state : String
  created_at : String
  detail : String
  diff : String
  diff_present : Bool
  hunks : Array[MoonCodePatchHunk]
  hunk_count : Int
  accepted_review_count : Int
  rejected_review_count : Int
  applied_review_count : Int
  reverted_review_count : Int
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
  target : String
  header : String
  review_state : String
  execution_state : String
  added_lines : Int
  removed_lines : Int
  context_lines : Int
  accepted_review_count : Int
  rejected_review_count : Int
  runtime_proof_count : Int
  gate_status : String?
  next_action : String?
  blocked_reason : String?
} derive(FromJson)

///|
struct MoonCodePatchSet {
  status : String
  execution_status : String
  recorded_at : String
  manifest_path : String
  patch_count : Int
  accepted_patch_count : Int
  rejected_patch_count : Int
  applied_patch_count : Int
  reverted_patch_count : Int
  pending_patch_count : Int
  runtime_applied_patch_count : Int
  runtime_patch_proof_count : Int
  patches : Array[MoonCodePatchSetEntry]
} derive(FromJson)

///|
struct MoonCodeToolApprovalEntry {
  event_id : String
  tool_id : String
  title : String
  approval : String
  approval_state : String
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
  status : String
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
  approval_entry : Json
} derive(FromJson)

///|
struct MoonCodeTestRunEntry {
  id : String
  title : String
  kind : String
  run_state : String
  created_at : String
  path : String
  command : String
  exit_code : Int
  detail : String
  target : String
  verified : Bool
} derive(FromJson)

///|
struct MoonCodeTestRuns {
  status : String
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
  package_kind : String
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
  recorded_at : String
  manifest_path : String
  review_receipt_path : String
  detail : String
} derive(FromJson)

///|
struct MoonCodePackageCandidates {
  status : String
  session_id : String
  runtime_session_id : String
  package_count : Int
  source_bound_package_count : Int
  missing_source_package_count : Int
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
