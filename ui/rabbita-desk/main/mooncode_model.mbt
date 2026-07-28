///|
struct MoonCodeOptimisticRow {
  session_id : String
  role : String
  content : String
  status : String
  key : String
}

///|
struct MoonCodeSession {
  id : String
  workspace_id : String
  workspace_name : String
  cwd : String
  source : String?
  mooncode_runtime_session_id : String?
  title : String
  updated_at : String?
  model : String
  status : String
  queued_count : Int
  last_message : String?
  mooncode_runtime_detail : String?
  mooncode_conversation : @mooncode_core.MoonCodeConversation?
  mooncode_summary : MoonCodeSummary
  canonical_unchanged : Bool?
  archived : Bool
} derive(FromJson)

///|
struct MoonCodeSessionLifecycleResult {
  kind : String
  protocol : String
  owner : String
  action : String
  session_id : String
  title : String
  archived : Bool
  deleted : Bool
} derive(FromJson)
