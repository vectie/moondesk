///|
struct MoonCodeOptimisticRow {
  session_id : String
  role : String
  content : String
  status : String
  key : String
}

///|
struct MoonCodeConversationTurn {
  kind : String
  turn_id : String
  client_turn_id : String
  command_id : String
  ordinal : Int
  status : String
  started_at : String
  updated_at : String
  user : Json
  work : Json
  assistant : Json
} derive(FromJson)

///|
struct MoonCodeConversation {
  kind : String
  protocol : String
  contract_id : String
  session_id : String
  workspace_id : String
  workspace_name : String
  turn_count : Int
  revision : Int
  last_sequence : Int
  source_event_count : Int
  turns : Array[MoonCodeConversationTurn]
} derive(FromJson)

///|
struct MoonCodeSession {
  id : String
  workspace_id : String
  workspace_name : String
  cwd : String
  source : String?
  mooncode_runtime_session_id : String?
  title : String
  model : String
  status : String
  queued_count : Int
  last_message : String?
  mooncode_runtime_detail : String?
  mooncode_conversation : MoonCodeConversation?
  mooncode_summary : MoonCodeSummary
} derive(FromJson)
