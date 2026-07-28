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
priv struct MoonClawModelReadiness {
  known : Bool
  ready : Bool
  status : String
  reason : String
  default_model : String
} derive(FromJson)

///|
struct MoonClawDaemonStatus {
  ok : Bool?
  status : String?
  next_action : String?
  model_ready : Bool?
  model_readiness : MoonClawModelReadiness?
  repair_available : Bool?
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
priv struct MoonClawProviderAuthStatus {
  authenticated : Bool?
  email : String?
  plan : String?
} derive(FromJson)

///|
struct MoonClawAuthStatus {
  ok : Bool?
  status : String?
  message : String?
  next_action : String?
  model_ready : Bool?
  codex : MoonClawProviderAuthStatus?
  copilot : MoonClawProviderAuthStatus?
} derive(FromJson)

///|
struct MoonClawCodexAuthFlow {
  ok : Bool?
  status : String?
  message : String?
  next_action : String?
  model_ready : Bool?
  auth_url : String?
  state : String?
} derive(FromJson)

///|
struct MoonClawCopilotAuthFlow {
  ok : Bool?
  status : String?
  message : String?
  next_action : String?
  model_ready : Bool?
  user_code : String?
  verification_uri : String?
  expires_in : Int?
  interval : Int?
} derive(FromJson)

///|
struct MoonClawSetupResult {
  ok : Bool
  status : String
  message : String
  next_action : String
  model_ready : Bool
} derive(FromJson)

///|
fn moonclaw_provider_is_connected(
  provider : MoonClawProviderAuthStatus?,
) -> Bool {
  match provider {
    Some(provider) => provider.authenticated is Some(true)
    None => false
  }
}

///|
fn moonclaw_auth_has_connected_provider(status : MoonClawAuthStatus?) -> Bool {
  match status {
    Some(status) =>
      moonclaw_provider_is_connected(status.codex) ||
      moonclaw_provider_is_connected(status.copilot)
    None => false
  }
}

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
