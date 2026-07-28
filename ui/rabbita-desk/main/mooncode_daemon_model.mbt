///|
priv struct CapabilityPlatformEvidence {
  supported : Bool
  platform : String
  architecture : String
} derive(FromJson)

///|
priv struct CapabilityInstallationEvidence {
  installed : Bool
  source : String
  reason : String
} derive(FromJson)

///|
priv struct CapabilityConfigurationEvidence {
  configured : Bool
  valid : Bool
  reason : String
} derive(FromJson)

///|
struct MoonClawDaemonStatus {
  running : Bool
  port : Int
  message : String
  service_configured : Bool
  managed_install : Bool?
  managed_running : Bool?
  platform_evidence : CapabilityPlatformEvidence?
  installation_evidence : CapabilityInstallationEvidence?
  configuration_evidence : CapabilityConfigurationEvidence?
} derive(FromJson)

///|
struct MoonClawModel {
  name : String
} derive(FromJson)

///|
struct MoonClawModelsResult {
  ok : Bool
  daemon : MoonClawDaemonStatus
  models : Array[MoonClawModel]
} derive(FromJson)
