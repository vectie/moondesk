///|
struct MoonFlowItemProjection {
  work_item_id : String
  product_id : String
  depends_on : Array[String]
  status : String
  attempt_count : Int
  blocker : String
  artifacts : Array[String]
  approvals : Array[String]
} derive(FromJson)

///|
struct MoonFlowRunProjection {
  protocol : String
  run_id : String
  last_sequence : Int
  outcome : String
  runnable_item_ids : Array[String]
  items : Array[MoonFlowItemProjection]
} derive(FromJson)
