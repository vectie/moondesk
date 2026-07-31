///|
/// Read-only MoonDesk projections of the shared MoonLib collaboration refs.
/// These types do not define a second collaboration wire contract: adapters
/// must validate the frozen MoonLib contract ids and canonical digest strings
/// before constructing this view model.
struct CollaborationPrincipalRef {
  contract_id : String
  principal_id : String
  kind : String
  issuer : String
  subject : String
} derive(FromJson)

///|
struct CollaborationWorkspaceRef {
  contract_id : String
  workspace_id : String
  revision : String
  digest : String
} derive(FromJson)

///|
struct CollaborationCorrelationRef {
  contract_id : String
  run_id : String
  work_item_id : String
  request_id : String?
  attempt_id : String?
  idempotency_key : String?
} derive(FromJson)

///|
struct CollaborationOperationRef {
  contract_id : String
  product_id : String
  tool_id : String
  pack_version : String
} derive(FromJson)

///|
struct CollaborationContractRef {
  contract_id : String
  referenced_contract_id : String
  referenced_contract_version : String
} derive(FromJson)

///|
struct CollaborationBudgetCeilings {
  max_cost_micros : Int64?
  max_runtime_ms : Int64?
  max_tokens : Int64?
  max_artifacts : Int?
} derive(FromJson)

///|
struct MoonFlowCollaborationMembership {
  membership_id : String
  principal : CollaborationPrincipalRef
  roles : Array[String]
  status : String
  added_by : CollaborationPrincipalRef
  updated_at : String
} derive(FromJson)

///|
struct MoonFlowCollaborationAssignment {
  assignment_id : String
  assignee : CollaborationPrincipalRef
  operation : CollaborationOperationRef
  subject_digest : String
  state : String
  due_at : String?
  submitted_artifact_ref : String?
  submitted_artifact_digest : String?
  approval_review_id : String?
  updated_at : String
} derive(FromJson)

///|
struct MoonFlowCollaborationComment {
  comment_id : String
  author : CollaborationPrincipalRef
  subject_digest : String
  anchor_ref : String
  body_ref : String
  body_digest : String
  mentions : Array[CollaborationPrincipalRef]
  created_at : String
} derive(FromJson)

///|
struct MoonFlowCollaborationReview {
  review_id : String
  subject_digest : String
  submitted_by : CollaborationPrincipalRef
  assigned_reviewer : CollaborationPrincipalRef
  requirement_id : String
  state : String
  decision_evidence_ref : String?
  decision_evidence_digest : String?
  updated_at : String
} derive(FromJson)

///|
struct MoonFlowCollaborationPayload {
  workspace_ref : CollaborationWorkspaceRef
  memberships : Array[MoonFlowCollaborationMembership]
  assignments : Array[MoonFlowCollaborationAssignment]
  claims : Array[Json]
  comments : Array[MoonFlowCollaborationComment]
  reviews : Array[MoonFlowCollaborationReview]
  events : Array[Json]
  head_digest : String
} derive(FromJson)

///|
struct MoonFlowCollaborationSnapshot {
  contract_id : String
  payload : MoonFlowCollaborationPayload
  content_digest : String
} derive(FromJson)

///|
struct MoonFlowHandoverCatalogEntry {
  handover_id : String
  state : String
  head_digest : String?
  envelope_digest : String?
  valid : Bool
} derive(FromJson)

///|
struct MoonFlowHandoverCatalog {
  contract_id : String
  handovers : Array[MoonFlowHandoverCatalogEntry]
} derive(FromJson)

///|
struct MoonFlowCollaborationReply {
  ok : Bool
  status : String
  message : String
  next_action : String?
  workspace_id : String
  source_contract : String
  snapshot : MoonFlowCollaborationSnapshot?
  handover_catalog : MoonFlowHandoverCatalog?
} derive(FromJson)

///|
struct CollaborationPersonProjection {
  principal_ref : CollaborationPrincipalRef
  workspace_ref : CollaborationWorkspaceRef
  roles : Array[String]
  status : String
}

///|
struct CollaborationAssignmentProjection {
  assignment_id : String
  assignee_principal : CollaborationPrincipalRef
  operation_ref : CollaborationOperationRef
  state : String
  due_at : String?
  head_digest : String
}

///|
struct CollaborationCommentProjection {
  comment_id : String
  author_principal : CollaborationPrincipalRef
  artifact_digest : String
  anchor_ref : String
  body_digest : String
  created_at : String
}

///|
struct CollaborationReviewProjection {
  review_id : String
  subject_digest : String
  assigned_reviewer : CollaborationPrincipalRef
  state : String
  separation_of_duty_ok : Bool
  head_digest : String
}

///|
struct CollaborationHandoverProjection {
  handover_id : String
  state : String
  envelope_digest : String?
  head_digest : String
  valid : Bool
}

///|
struct CollaborationConflictReceiptProjection {
  expected_head : String
  actual_head : String
  mutation_id : String
}

///|
struct CollaborationSurfaceProjection {
  people : Array[CollaborationPersonProjection]
  assignments : Array[CollaborationAssignmentProjection]
  comments : Array[CollaborationCommentProjection]
  reviews : Array[CollaborationReviewProjection]
  handovers : Array[CollaborationHandoverProjection]
  conflicts : Array[CollaborationConflictReceiptProjection]
}

///|
fn empty_collaboration_surface() -> CollaborationSurfaceProjection {
  {
    people: [],
    assignments: [],
    comments: [],
    reviews: [],
    handovers: [],
    conflicts: [],
  }
}

///|
fn CollaborationSurfaceProjection::is_empty(
  self : CollaborationSurfaceProjection,
) -> Bool {
  self.people.is_empty() &&
  self.assignments.is_empty() &&
  self.comments.is_empty() &&
  self.reviews.is_empty() &&
  self.handovers.is_empty() &&
  self.conflicts.is_empty()
}

///|
fn collaboration_principals_equal(
  left : CollaborationPrincipalRef,
  right : CollaborationPrincipalRef,
) -> Bool {
  left.contract_id == right.contract_id &&
  left.principal_id == right.principal_id &&
  left.kind == right.kind &&
  left.issuer == right.issuer &&
  left.subject == right.subject
}

///|
fn collaboration_surface_from_snapshot(
  snapshot : MoonFlowCollaborationSnapshot,
  handover_catalog : MoonFlowHandoverCatalog?,
) -> CollaborationSurfaceProjection {
  let payload = snapshot.payload
  let handovers : Array[CollaborationHandoverProjection] = match handover_catalog {
    Some(catalog) if catalog.contract_id == "moonflow.handover-catalog.v1" =>
      catalog.handovers.map(handover => {
        handover_id: handover.handover_id,
        state: handover.state,
        envelope_digest: handover.envelope_digest,
        head_digest: handover.head_digest.unwrap_or(""),
        valid: handover.valid,
      })
    _ => []
  }
  {
    people: payload.memberships.map(membership => {
      principal_ref: membership.principal,
      workspace_ref: payload.workspace_ref,
      roles: membership.roles,
      status: membership.status,
    }),
    assignments: payload.assignments.map(assignment => {
      assignment_id: assignment.assignment_id,
      assignee_principal: assignment.assignee,
      operation_ref: assignment.operation,
      state: assignment.state,
      due_at: assignment.due_at,
      head_digest: payload.head_digest,
    }),
    comments: payload.comments.map(comment => {
      comment_id: comment.comment_id,
      author_principal: comment.author,
      artifact_digest: comment.subject_digest,
      anchor_ref: comment.anchor_ref,
      body_digest: comment.body_digest,
      created_at: comment.created_at,
    }),
    reviews: payload.reviews.map(review => {
      review_id: review.review_id,
      subject_digest: review.subject_digest,
      assigned_reviewer: review.assigned_reviewer,
      state: review.state,
      separation_of_duty_ok: !collaboration_principals_equal(
        review.submitted_by,
        review.assigned_reviewer,
      ),
      head_digest: payload.head_digest,
    }),
    handovers: handovers,
    conflicts: [],
  }
}
