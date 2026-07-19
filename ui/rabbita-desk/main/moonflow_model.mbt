///|
struct MoonFlowItemProjection {
  work_item_id : String
  declaration_id : String
  product_id : String
  requested_authority : String
  acceptance_criteria : Array[String]
  depends_on : Array[String]
  status : String
  attempt_count : Int
  request_id : String
  result_id : String
  active_attempt_id : String
  idempotency_key : String
  external_job_id : String
  attempt_status : String
  operation : String
  input_digest : String
  output_digest : String
  error_kind : String
  compensable : Bool
  blocker : String
  acceptance_review_id : String
  acceptance_review_artifact : String
  acceptance_reviewer_id : String
  artifacts : Array[String]
  approvals : Array[String]
} derive(FromJson)

///|
struct MoonFlowBudget {
  model_tokens : Int
  tool_calls : Int
  storage_bytes : Int
  attempts : Int
  concurrency : Int
} derive(FromJson)

///|
struct MoonFlowEnvelopeSummary {
  envelope_id : String
  mode : String
  expires_at : String
  revoked : Bool
  external_effects_allowed : Bool
  physical_effects_allowed : Bool
  budget : MoonFlowBudget
} derive(FromJson)

///|
struct MoonFlowAutonomyBinding {
  contract_id : String
  run_id : String
  envelope : MoonFlowEnvelopeSummary
  usage_ref : String
  usage : MoonFlowBudget
  recorded_at : String
} derive(FromJson)

///|
struct MoonFlowInterventionScorecard {
  contract_id : String
  run_id : String
  required_intervention_count : Int
  hidden_orchestration_count : Int
  normal_path_manual_count : Int
  unattended_qualified : Bool
  finalization_findings : Array[String]
  recorded_at : String
} derive(FromJson)

///|
struct MoonFlowRunControl {
  contract_id : String
  run_id : String
  state : String
  authority_ceiling : String
  reason : String
  recorded_at : String
} derive(FromJson)

///|
struct MoonFlowImportResult {
  ok : Bool
  status : String
  message : String
  next_action : String
  book_id : String
  run_id : String
} derive(FromJson)

///|
struct MoonFlowOperatorAction {
  action_id : String
  label : String
  summary : String
  status : String
  enabled : Bool
} derive(FromJson)

///|
struct MoonFlowOperatorActions {
  run_id : String
  status : String
  actions : Array[MoonFlowOperatorAction]
} derive(FromJson)

///|
struct MoonFlowOperatorActionReceipt {
  run_id : String
  action_id : String
  operation : String
  status : String
  record_persisted : Bool
  source_digest : String
} derive(FromJson)

///|
struct MoonFlowRunProjection {
  protocol : String
  run_id : String
  book_id : String
  declaration_revision : String
  source_digest : String
  last_sequence : Int
  outcome : String
  runnable_item_ids : Array[String]
  items : Array[MoonFlowItemProjection]
  autonomy_binding : MoonFlowAutonomyBinding
  intervention_scorecard : MoonFlowInterventionScorecard
  run_control : MoonFlowRunControl
  operator_surface : MoonFlowOperatorSurface?
} derive(FromJson)
