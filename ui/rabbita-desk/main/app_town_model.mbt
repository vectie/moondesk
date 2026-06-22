///|
struct TownMessage {
  id : String
  path : String
  title : String
  kind : String
} derive(FromJson)

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
  cadence_ticks : Int
  next_due_tick : Int
  last_run_tick : Int?
  enabled : Bool
  source_policy : String
  review_policy : String
} derive(FromJson)

///|
struct TownAnalytics {
  daemon_tick : Int
  standing_goal_count : Int
  due_goal_count : Int
  active_goal_count : Int
  request_count : Int
  message_count : Int
  run_count : Int
  watcher_run_count : Int
  updates : Int
  no_changes : Int
  needs_review : Int
  failures : Int
  deferred : Int
  event_count : Int
  failure_event_count : Int
  review_event_count : Int
  last_failure : String
  review_item_count : Int
  next_due_tick : Int
} derive(FromJson)

///|
struct TownProgress {
  daemon_tick : Int
  daemon_running : Bool
  daemon_status : String
  supervision_enabled : Bool
  due_goal_count : Int
  next_due_tick : Int
  request_count : Int
  message_count : Int
  dispatch_count : Int
  run_count : Int
  latest_request : String
  latest_message : String
  latest_dispatch : String
  latest_run : String
  latest_run_status : String
  latest_run_artifacts : Int
} derive(FromJson)

///|
struct MoonclawProgress {
  run_count : Int
  ready_count : Int
  artifact_count : Int
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
  tick : Int
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
