///|
fn moonclaw_runtime_root() -> String {
  moonclaw_runtime_root_from_environment(
    @sys.get_env_var("MOONDESK_RUNTIME_ROOT").unwrap_or(""),
    @sys.get_env_var("LEPUSA_APP_DATA_DIR").unwrap_or(""),
    @sys.get_env_var("HOME").unwrap_or(""),
  )
}

///|
fn moonclaw_runtime_root_from_environment(
  override_root : String,
  app_data_root : String,
  home_root : String,
) -> String {
  if override_root.trim().length() > 0 {
    return @pathx.normalize(override_root)
  }
  if app_data_root.trim().length() > 0 {
    return @pathx.join(@pathx.normalize(app_data_root), "runtimes")
  }
  if home_root.trim().length() == 0 {
    ""
  } else {
    @pathx.join(
      home_root, "Library/Application Support/app.vectie.moondesk/runtimes",
    )
  }
}

///|
/// Explicit host evidence shared by installation and daemon-status reporting.
/// `supported` describes the host platform/architecture contract only; it does
/// not imply that a release is available or that the updater is enabled.
priv struct MoonClawPlatformSupport {
  supported : Bool
  platform : String
  architecture : String
}

///|
fn moonclaw_platform_support_from_values(
  platform : String,
  architecture : String,
) -> MoonClawPlatformSupport {
  {
    supported: platform == "macos" && architecture == "arm64",
    platform,
    architecture,
  }
}

///|
async fn moonclaw_platform_support() -> MoonClawPlatformSupport {
  let (platform, architecture) = moonclaw_install_platform()
  moonclaw_platform_support_from_values(platform, architecture)
}

///|
fn moonclaw_platform_support_json(evidence : MoonClawPlatformSupport) -> Json {
  {
    "supported": evidence.supported,
    "platform": evidence.platform,
    "architecture": evidence.architecture,
  }
}

///|
/// Host probing is a fixed, reviewed capability. No command, executable, or
/// argument vector crosses this package boundary.
async fn moonclaw_install_platform() -> (String, String) {
  let forced_platform = @sys.get_env_var("MOONCLAW_INSTALL_PLATFORM").unwrap_or(
    "",
  )
  let forced_architecture = @sys.get_env_var("MOONCLAW_INSTALL_ARCHITECTURE").unwrap_or(
    "",
  )
  if forced_platform != "" && forced_architecture != "" {
    return (forced_platform, forced_architecture)
  }
  let system = @trusted_host.system_name()
  let machine = @trusted_host.machine_name()
  let platform = match system.trim().to_owned() {
    "Darwin" => "macos"
    "Linux" => "linux"
    _ => "unsupported"
  }
  let architecture = match machine.trim().to_owned() {
    "arm64" | "aarch64" => "arm64"
    "x86_64" | "amd64" => "x86_64"
    _ => "unsupported"
  }
  (platform, architecture)
}

///|
/// Release versions are consumed by the managed-service descriptor. Keep the
/// accepted alphabet closed so a service record cannot become a path escape.
fn moonclaw_release_segment_valid(value : String) -> Bool {
  if value == "" || value.length() > 160 {
    return false
  }
  for char in value {
    if !char.is_ascii_alphabetic() &&
      !char.is_ascii_digit() &&
      char != '.' &&
      char != '-' &&
      char != '_' {
      return false
    }
  }
  true
}

///|
async fn moonclaw_install_failure(
  workspace_root : String,
  status : String,
  message : String,
  next_action? : String = "review_moonclaw_setup",
) -> Json {
  let current = moonclaw_daemon_status(workspace_root)
  api_contract_response(
    {
      "running": false,
      "port": json_int(current, "port", default=0),
      "pid": json_int(current, "pid", default=0),
      "service_configured": json_bool(
        current,
        "service_configured",
        default=false,
      ),
      "service_config_path": json_string(
        current,
        "service_config_path",
        default="",
      ),
      "managed_install": json_bool(current, "managed_install", default=false),
      "managed_running": json_bool(current, "managed_running", default=false),
      "repair_available": false,
      "platform_evidence": json_object_field(current, "platform_evidence").unwrap_or(
        Json::empty_object(),
      ),
      "installation_evidence": json_object_field(
        current, "installation_evidence",
      ).unwrap_or(Json::empty_object()),
      "configuration_evidence": json_object_field(
        current, "configuration_evidence",
      ).unwrap_or(Json::empty_object()),
      "model_readiness": json_object_field(current, "model_readiness").unwrap_or(
        Json::empty_object(),
      ),
      "auth_readiness": json_object_field(current, "auth_readiness").unwrap_or(
        Json::empty_object(),
      ),
      "installed_version": json_string(current, "installed_version", default=""),
      "running_version": json_string(current, "running_version", default=""),
      "service_source": json_string(
        current,
        "service_source",
        default="missing",
      ),
      "updater_boundary": {
        "kind": "execution-sandbox-updater.v1",
        "available": false,
        "fallback": "deny",
        "host_process_fallback": false,
      },
    },
    ok=false,
    status~,
    message~,
    next_action~,
  )
}

///|
async fn install_moonclaw_release(workspace_root : String) -> Json {
  let root = workspace_context(workspace_root).suite_root
  install_moonclaw_release_for_platform(root, moonclaw_platform_support())
}

///|
/// MoonDesk intentionally has no local updater fallback. A future updater must
/// provide authenticated manifest transport, bounded archive handling, and
/// isolated initialization as one reviewed capability before this can return
/// success. Until then, supported hosts receive a typed refusal and unsupported
/// hosts retain their more specific platform result.
async fn install_moonclaw_release_for_platform(
  root : String,
  platform_support : MoonClawPlatformSupport,
) -> Json {
  if !platform_support.supported {
    return moonclaw_install_failure(
      root,
      "platform_unsupported",
      "MoonClaw installation is not supported for " +
      platform_support.platform +
      " " +
      platform_support.architecture,
      next_action="review_supported_platforms",
    )
  }
  moonclaw_install_failure(
    root,
    "updater_sandbox_unavailable",
    "MoonDesk refused to run the MoonClaw updater on the host because an isolated updater backend is not configured",
    next_action="configure_execution_sandbox",
  )
}
