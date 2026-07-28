///|
struct DaemonControlResult {
  id : String
  ok : Bool
  status : String
  exit_code : Int
  path : String
  stdout : String
  stderr : String
} derive(FromJson)

///|
priv struct TownInstallationEvidence {
  installed : Bool
  source : String
} derive(FromJson)

///|
// Host configuration evidence is optional for compatibility with older lifecycle responses.
priv struct DaemonConfigurationEvidence {
  configured : Bool
  valid : Bool
  reason : String
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
  service_configured : Bool
  service_config_path : String
  service_cwd : String
  platform_evidence : CapabilityPlatformEvidence?
  installation_evidence : TownInstallationEvidence?
  configuration_evidence : DaemonConfigurationEvidence?
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
