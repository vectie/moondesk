///|
struct TownMessage {
  title : String
} derive(FromJson)

///|
struct WikiChatEntry {
  role : String
  content : String
} derive(FromJson, ToJson, Eq, Debug)

///|
struct WikiChatContextItem {
  id : String
  kind : String
  label : String
  value : String
  detail : String
} derive(FromJson, ToJson, Eq, Debug)

///|
struct WikiChatSubmission {
  task_id : String
  status : String
  message : String
  queued : Bool
  owner : String
  automation_suggestion : Json?
  preferences_used : Int32
  preference_ids : Array[String]
} derive(FromJson, Eq, Debug)

///|
struct RequestRecord {
  id : String
  status : String
  path : String
  request : Json
} derive(FromJson)

///|
struct StandingGoalRecord {
  id : String
  title : String
  prompt : String
  target_book_id : String
  cadence_ticks : Int32
  next_due_tick : Int32
  last_run_tick : Json
  enabled : Bool
  source_policy : String
  review_policy : String
} derive(FromJson)

///|
struct TownAnalytics {
  daemon_tick : Int32
  standing_goal_count : Int32
  due_goal_count : Int32
  active_goal_count : Int32
  request_count : Int32
  message_count : Int32
  run_count : Int32
  watcher_run_count : Int32
  updates : Int32
  no_changes : Int32
  needs_review : Int32
  failures : Int32
  deferred : Int32
  event_count : Int32
  failure_event_count : Int32
  review_event_count : Int32
  last_failure : String
  review_item_count : Int32
  next_due_tick : Int32
} derive(FromJson)

///|
struct TownProgress {
  daemon_tick : Int32
  daemon_running : Bool
  daemon_status : String
  supervision_enabled : Bool
  due_goal_count : Int32
  next_due_tick : Int32
  request_count : Int32
  message_count : Int32
  dispatch_count : Int32
  run_count : Int32
  latest_request : String
  latest_message : String
  latest_dispatch : String
  latest_run : String
  latest_run_status : String
  latest_run_artifacts : Int32
} derive(FromJson)

///|
struct MoonclawProgress {
  run_count : Int32
  ready_count : Int32
  artifact_count : Int32
  latest_run : String
  latest_status : String
} derive(FromJson)

///|
struct DeskEvent {
  id : String
  source : String
  kind : String
  severity : String
  title : String
  detail : String
  path : String
  run_id : String
  tick : Int32
  created_at : String
} derive(FromJson)

///|
struct ReviewItem {
  id : String
  workspace_id : String
  path : String
  title : String
  kind : String
  status : String
  detail : String
} derive(FromJson)

///|
struct ReviewDecisionResult {
  id : String
  workspace_id : String
  source_path : String
  decision : String
  status : String
  note : String
  receipt_path : String
} derive(FromJson)
