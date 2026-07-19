///|
/// Read-only recovery state published by MoonFlow for human operation. Every
/// field is optional so an older or partially upgraded host remains readable.
struct MoonFlowRecoveryOperatorProjection {
  state : String?
  owner : String?
  claim_id : String?
  epoch : Int?
  fence : Int?
  expires_at : String?
  next_due_at : String?
  deadline : String?
  attempt_count : Int?
  unknown_since : String?
  reconciliation_age_seconds : Int?
  last_provider_observation_digest : String?
  manual_intervention : Bool?
  blocker : String?
  evidence_refs : Array[String]?
  recorded_at : String?
} derive(FromJson)

///|
struct MoonFlowDueActionOperatorProjection {
  action_id : String?
  kind : String?
  state : String?
  due_at : String?
  deadline : String?
  overdue : Bool?
  authority_ref : String?
  source_ref : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowCallbackOperatorProjection {
  callback_id : String?
  state : String?
  provider_event_id : String?
  disposition : String?
  source_at : String?
  received_at : String?
  reason : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowQuarantineOperatorProjection {
  quarantine_id : String?
  state : String?
  callback_ref : String?
  reason : String?
  quarantined_at : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowManualInterventionOperatorProjection {
  intervention_id : String?
  state : String?
  reason : String?
  required_action : String?
  owner : String?
  opened_at : String?
  resolved_at : String?
  authority_ref : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowFinalDeliverableOperatorProjection {
  candidate_id : String?
  state : String?
  decision : String?
  submitted_at : String?
  decided_at : String?
  producer_version : String?
  ability_version : String?
  policy_version : String?
  human_review_required : Bool?
  reviewer_id : String?
  source_terminal_ref : String?
  blocker : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowArtifactOperatorProjection {
  artifact_id : String?
  state : String?
  revision : Int?
  media_type : String?
  locator : String?
  digest : String?
  accepted_at : String?
  lineage_root_ref : String?
  previous_revision_ref : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowDeliveryOperatorProjection {
  delivery_id : String?
  state : String?
  destination : String?
  artifact_ref : String?
  authorized : Bool?
  authority_ref : String?
  delivered_at : String?
  receipt_ref : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowOutcomeOperatorProjection {
  observation_id : String?
  state : String?
  artifact_ref : String?
  source : String?
  window_start : String?
  window_end : String?
  effective_at : String?
  retrieved_at : String?
  digest : String?
  summary : String?
  corrects_observation_ref : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowProposalOperatorProjection {
  proposal_id : String?
  state : String?
  owner_kind : String?
  scope : String?
  expected_benefit : String?
  risk : String?
  evaluation_method : String?
  expires_at : String?
  rollback : String?
  source_assessment_ref : String?
  policy_version : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowEvaluationOperatorProjection {
  evaluation_id : String?
  state : String?
  proposal_ref : String?
  proposed_version : String?
  baseline_version : String?
  result : String?
  regression_gate : String?
  completed_at : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
struct MoonFlowHumanAdoptionOperatorProjection {
  decision_id : String?
  state : String?
  proposal_ref : String?
  reviewer_id : String?
  decision : String?
  old_version : String?
  new_version : String?
  decided_at : String?
  reason : String?
  evidence_refs : Array[String]?
} derive(FromJson)

///|
/// Generic host-facing closed-loop projection. The envelope is deliberately
/// domain-neutral and read-only; commands continue through separately
/// authorized MoonFlow routes.
struct MoonFlowOperatorSurface {
  contract_id : String?
  run_id : String?
  available : Bool?
  status : String?
  recorded_at : String?
  recovery : MoonFlowRecoveryOperatorProjection?
  due_actions : Array[MoonFlowDueActionOperatorProjection]?
  callbacks : Array[MoonFlowCallbackOperatorProjection]?
  quarantine : Array[MoonFlowQuarantineOperatorProjection]?
  manual_interventions : Array[MoonFlowManualInterventionOperatorProjection]?
  final_deliverables : Array[MoonFlowFinalDeliverableOperatorProjection]?
  artifacts : Array[MoonFlowArtifactOperatorProjection]?
  deliveries : Array[MoonFlowDeliveryOperatorProjection]?
  outcomes : Array[MoonFlowOutcomeOperatorProjection]?
  proposals : Array[MoonFlowProposalOperatorProjection]?
  evaluations : Array[MoonFlowEvaluationOperatorProjection]?
  human_adoptions : Array[MoonFlowHumanAdoptionOperatorProjection]?
} derive(FromJson)
