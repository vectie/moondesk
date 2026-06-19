///|
struct DaemonDispatchResult {
  id : String
  ok : Bool
  status : String
  exit_code : Int
  path : String
  stdout : String
  stderr : String
} derive(FromJson)

///|
struct DaemonLifecycleResult {
  ok : Bool
  action : String
  status : String
  running : Bool
  pid : Int
  command : String
  cwd : String
  started_at : String
  stopped_at : String
  pid_file : String
  stdout_path : String
  stderr_path : String
  message : String
  supervision_enabled : Bool
  desired_state : String
  restart_count : Int
  last_health_check : String
  policy_file : String
} derive(FromJson)

///|
struct LaunchAgentResult {
  ok : Bool
  action : String
  installed : Bool
  loaded : Bool
  label : String
  plist_path : String
  command : String
  cwd : String
  exit_code : Int
  message : String
} derive(FromJson)

///|
struct RevealResult {
  ok : Bool
  status : String
  exit_code : Int
  workspace_id : String
  path : String
  absolute_path : String
} derive(FromJson)

