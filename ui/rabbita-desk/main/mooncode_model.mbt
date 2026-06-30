///|
struct MoonCodeMessage {
  role : String
  content : String
  status : String
} derive(FromJson)

///|
struct MoonCodePendingPrompt {
  session_id : String
  content : String
  status : String
  after_row_count : Int
  after_event_count : Int
}

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
  lane : String
  kind : String
  title : String
  status : String
  created_at : String
  detail : String
  path : String
  diff : String
  command : String
  exit_code : Int
  tool_result : Json?
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
  updated_at : String
  transcript : Array[MoonCodeMessage]
  mooncode_events : Array[MoonCodeEvent]
  mooncode_summary : MoonCodeSummary
} derive(FromJson)
