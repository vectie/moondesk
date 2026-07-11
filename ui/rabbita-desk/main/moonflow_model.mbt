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
  input_digest : String
  output_digest : String
  error_kind : String
  compensable : Bool
  blocker : String
  artifacts : Array[String]
  approvals : Array[String]
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
} derive(FromJson)
