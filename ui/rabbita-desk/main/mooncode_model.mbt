///|
struct MoonCodeMessage {
  role : String
  content : String
  status : String
  created_at : String
} derive(FromJson)

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
