///|
struct MoonCodeConversationRow {
  session_id : String
  role : String
  content : String
  status : String
  key : String
}

///|
struct MoonCodeEvent {
  id : String
  command_id : String?
  lane : String
  kind : String
  title : String
  status : String
  created_at : String
  detail : String
  path : String
  command : String
  exit_code : Int
  tool : String?
  tool_name : String?
  command_packet : Json?
  tool_result : Json?
} derive(FromJson)

///|
struct MoonCodeConversationTurn {
  kind : String
  turn_id : String
  client_turn_id : String
  command_id : String
  status : String
  started_at : String
  updated_at : String
  user : Json
  progress : Array[Json]
  assistant : Json
  items : Array[Json]
} derive(FromJson)

///|
struct MoonCodeConversation {
  kind : String
  protocol : String
  session_id : String
  workspace_id : String
  workspace_name : String
  turn_count : Int
  source_event_count : Int
  turns : Array[MoonCodeConversationTurn]
} derive(FromJson)

///|
struct MoonCodeSession {
  id : String
  workspace_id : String
  workspace_name : String
  cwd : String
  mooncode_runtime_session_id : String?
  title : String
  model : String
  status : String
  queued_count : Int
  mooncode_conversation : MoonCodeConversation?
  mooncode_summary : MoonCodeSummary
} derive(FromJson)
