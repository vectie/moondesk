///|
async fn handle_moonclaw_daemon(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  send_json(conn, method_, moonclaw_daemon_status(workspace_root))
}

///|
async fn handle_moonclaw_models(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let daemon = moonclaw_daemon_status(workspace_root)
  if !json_bool(daemon, "running", default=false) {
    send_json(
      conn,
      method_,
      api_contract_response(
        { "daemon": daemon, "models": Json::array([]) },
        ok=false,
        status="moonclaw_unreachable",
        message=json_string(
          daemon,
          "message",
          default="MoonClaw daemon is not running",
        ),
        next_action=json_string(
          daemon,
          "next_action",
          default="configure_or_start_moonclaw",
        ),
      ),
    )
    return
  }
  match moonclaw_get_json(daemon, "/v1/models") {
    Ok(payload) => {
      let ready = moonclaw_models_response_ready(payload)
      send_json(
        conn,
        method_,
        api_contract_response(
          {
            "daemon": daemon,
            "models": json_array(payload, "models"),
            "default_model": json_string(payload, "default_model", default=""),
          },
          ok=ready,
          status=if ready { "ready" } else { "moonclaw_models_unavailable" },
          message=if ready {
            "MoonClaw models are available"
          } else {
            "MoonClaw has no executable default model"
          },
          next_action=if ready { "use_moonclaw" } else { "configure_model" },
        ),
      )
    }
    Err(message) =>
      send_json(
        conn,
        method_,
        api_contract_response(
          {
            "daemon": moonclaw_daemon_with_message(daemon, message),
            "models": Json::array([]),
          },
          ok=false,
          status="moonclaw_models_unavailable",
          message~,
          next_action="inspect_moonclaw_daemon",
        ),
      )
  }
}

///|
fn moonclaw_model_readiness_unknown(
  reason : String,
  error? : String = "",
) -> Json {
  {
    "known": false,
    "ready": false,
    "status": "unknown",
    "reason": reason,
    "default_model": "",
    "models": [],
    "error": error,
  }
}

///|
fn moonclaw_model_readiness_from_probe(probe : Result[Json, String]) -> Json {
  match probe {
    Ok(payload) => {
      let ready = moonclaw_models_response_ready(payload)
      {
        "known": true,
        "ready": ready,
        "status": if ready {
          "ready"
        } else {
          "needs_configuration"
        },
        "reason": if ready {
          "default-model-available"
        } else {
          "default-model-unavailable"
        },
        "default_model": json_string(payload, "default_model", default=""),
        "models": json_array(payload, "models"),
        "error": "",
      }
    }
    Err(error) => moonclaw_model_readiness_unknown("route-unavailable", error~)
  }
}

///|
fn moonclaw_provider_auth_readiness(payload : Json, provider : String) -> Json {
  match json_object_field(payload, provider) {
    Some(status) =>
      {
        "known": true,
        "authenticated": json_bool(status, "authenticated", default=false),
        "email": json_string(status, "email", default=""),
        "plan": json_string(status, "plan", default=""),
      }
    None => { "known": false, "authenticated": false, "email": "", "plan": "" }
  }
}

///|
fn moonclaw_auth_readiness_unknown(
  reason : String,
  error? : String = "",
) -> Json {
  {
    "known": false,
    "ready": false,
    "status": "unknown",
    "reason": reason,
    "codex": moonclaw_provider_auth_readiness(Json::empty_object(), "codex"),
    "copilot": moonclaw_provider_auth_readiness(Json::empty_object(), "copilot"),
    "error": error,
  }
}

///|
fn moonclaw_auth_readiness_from_probe(probe : Result[Json, String]) -> Json {
  match probe {
    Ok(payload) => {
      let codex = moonclaw_provider_auth_readiness(payload, "codex")
      let copilot = moonclaw_provider_auth_readiness(payload, "copilot")
      let known = json_bool(codex, "known", default=false) ||
        json_bool(copilot, "known", default=false)
      let ready = json_bool(codex, "authenticated", default=false) ||
        json_bool(copilot, "authenticated", default=false)
      {
        "known": known,
        "ready": ready,
        "status": if !known {
          "unknown"
        } else if ready {
          "ready"
        } else {
          "authentication_required"
        },
        "reason": if !known {
          "provider-status-unavailable"
        } else if ready {
          "provider-authenticated"
        } else {
          "provider-authentication-required"
        },
        "codex": codex,
        "copilot": copilot,
        "error": "",
      }
    }
    Err(error) => moonclaw_auth_readiness_unknown("route-unavailable", error~)
  }
}

///|
fn moonclaw_daemon_model_ready(daemon : Json) -> Bool? {
  if json_object_field(daemon, "model_readiness") is Some(readiness) &&
    json_bool(readiness, "known", default=false) {
    Some(json_bool(readiness, "ready", default=false))
  } else {
    None
  }
}

///|
fn moonclaw_auth_status_response_from_probe(
  daemon : Json,
  probe : Result[Json, String],
) -> Json {
  match probe {
    Ok(payload) => {
      let auth_readiness = moonclaw_auth_readiness_from_probe(Ok(payload))
      let auth_known = json_bool(auth_readiness, "known", default=false)
      let auth_ready = json_bool(auth_readiness, "ready", default=false)
      let model_ready = moonclaw_daemon_model_ready(daemon).unwrap_or(false)
      let ready = auth_ready || model_ready
      let fields = match payload {
        Object(fields) => fields.copy()
        _ => Map([])
      }
      fields["daemon"] = daemon
      fields["auth_readiness"] = auth_readiness
      if moonclaw_daemon_model_ready(daemon) is Some(model_ready) {
        fields["model_ready"] = model_ready.to_json()
      }
      api_contract_response(
        Json::object(fields),
        ok=ready,
        status=if ready {
          "ready"
        } else if !auth_known {
          "auth_status_unknown"
        } else {
          "authentication_required"
        },
        message=if model_ready {
          "A MoonClaw model is configured and ready"
        } else if auth_ready {
          "A MoonClaw model provider is authenticated"
        } else if !auth_known {
          "MoonClaw did not provide provider authentication status"
        } else {
          "Authenticate Codex or GitHub Copilot, or configure an OpenRouter API key"
        },
        next_action=if ready {
          "use_moonclaw"
        } else if !auth_known {
          "inspect_or_upgrade_moonclaw"
        } else {
          "authenticate_model_provider"
        },
      )
    }
    Err(error) =>
      api_contract_response(
        {
          "daemon": daemon,
          "auth_readiness": moonclaw_auth_readiness_unknown(
            "route-unavailable",
            error~,
          ),
          "upstream_error": error,
        },
        ok=false,
        status="auth_status_unknown",
        message=error,
        next_action="inspect_or_upgrade_moonclaw",
      )
  }
}

///|
async fn handle_moonclaw_auth_status(
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let daemon = moonclaw_daemon_status(workspace_root)
  let probe = if json_bool(daemon, "running", default=false) {
    moonclaw_get_json(daemon, "/v1/auth/status")
  } else {
    Err(
      json_string(daemon, "message", default="MoonClaw daemon is not running"),
    )
  }
  send_json(
    conn,
    method_,
    moonclaw_auth_status_response_from_probe(daemon, probe),
  )
}

///|
fn moonclaw_auth_start_response_from_probe(
  daemon : Json,
  provider : String,
  probe : Result[Json, String],
) -> Json {
  match probe {
    Ok(payload) => {
      let payload_error = if provider == "codex" {
        let auth_url = json_string(payload, "auth_url", default="")
        if auth_url == "" || json_string(payload, "state", default="") == "" {
          Some(
            "MoonClaw Codex authentication response did not include auth_url and state",
          )
        } else if !moonclaw_auth_destination_allowed(provider, auth_url) {
          Some(
            "MoonClaw Codex authentication response used an untrusted authorization destination",
          )
        } else {
          None
        }
      } else {
        let verification_uri = json_string(
          payload,
          "verification_uri",
          default="",
        )
        if json_string(payload, "user_code", default="") == "" ||
          verification_uri == "" {
          Some(
            "MoonClaw GitHub Copilot authentication response did not include user_code and verification_uri",
          )
        } else if !moonclaw_auth_destination_allowed(provider, verification_uri) {
          Some(
            "MoonClaw GitHub Copilot authentication response used an untrusted verification destination",
          )
        } else {
          None
        }
      }
      if payload_error is Some(error) {
        return moonclaw_auth_start_failure_response(daemon, provider, error)
      }
      let fields = match payload {
        Object(fields) => fields.copy()
        _ => Map([])
      }
      fields["daemon"] = daemon
      fields["provider"] = provider.to_json()
      if moonclaw_daemon_model_ready(daemon) is Some(model_ready) {
        fields["model_ready"] = model_ready.to_json()
      }
      api_contract_response(
        Json::object(fields),
        ok=true,
        status="auth_started",
        message=if provider == "codex" {
          "Codex authorization started"
        } else {
          "GitHub Copilot device authorization started"
        },
        next_action=if provider == "codex" {
          "open_authorization_url"
        } else {
          "complete_device_authorization"
        },
      )
    }
    Err(error) => moonclaw_auth_start_failure_response(daemon, provider, error)
  }
}

///|
fn moonclaw_auth_destination_allowed(
  provider : String,
  destination : String,
) -> Bool {
  if provider == "codex" {
    destination.has_prefix("https://auth.openai.com/oauth/authorize?")
  } else if provider == "copilot" {
    destination == "https://github.com/login/device"
  } else {
    false
  }
}

///|
fn moonclaw_auth_start_failure_response(
  daemon : Json,
  provider : String,
  error : String,
) -> Json {
  api_contract_response(
    { "daemon": daemon, "provider": provider, "upstream_error": error },
    ok=false,
    status="auth_start_failed",
    message=error,
    next_action="inspect_moonclaw_auth",
  )
}

///|
async fn handle_moonclaw_auth_start(
  workspace_root : String,
  provider : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let daemon = moonclaw_daemon_status(workspace_root)
  let probe = if json_bool(daemon, "running", default=false) {
    moonclaw_post_json(
      daemon,
      "/v1/auth/\{provider}/start",
      Json::empty_object(),
    )
  } else {
    Err(
      json_string(daemon, "message", default="MoonClaw daemon is not running"),
    )
  }
  send_json(
    conn,
    method_,
    moonclaw_auth_start_response_from_probe(daemon, provider, probe),
  )
}

///|
fn moonclaw_openrouter_key_from_payload(
  payload : Json,
) -> Result[String, String] {
  guard json_string_opt(payload, "api_key") is Some(value) else {
    return Err("api_key must be a JSON string")
  }
  let value = value.trim().to_owned()
  if value == "" {
    return Err("api_key must not be empty")
  }
  if value.length() > 4096 {
    return Err("api_key must be at most 4096 characters")
  }
  Ok(value)
}

///|
fn moonclaw_config_with_openrouter_key(
  existing : Json,
  api_key : String,
) -> Json {
  let fields = match existing {
    Object(fields) => fields.copy()
    _ => Map([])
  }
  fields["api_key"] = api_key.to_json()
  Json::object(fields)
}

///|
async fn moonclaw_secure_product_directory(
  root : String,
  product_dir : String,
) -> Result[Unit, String] {
  let canonical_root = @fs.realpath(root) catch {
    _ => return Err("MoonDesk could not verify the MoonClaw workspace root")
  }
  let canonical_product_dir = @fs.realpath(product_dir) catch {
    _ =>
      return Err(
        "MoonDesk could not verify the MoonClaw configuration directory",
      )
  }
  let expected_product_dir = moonsuite_product_artifact_for_workspace_root(
    canonical_root, "moonclaw", "",
  )
  if canonical_product_dir != expected_product_dir {
    return Err("MoonDesk refused a redirected MoonClaw configuration directory")
  }
  Ok(())
}

///|
async fn moonclaw_existing_config_is_safe(
  config_path : String,
) -> Result[Bool, String] {
  if !@fs.exists(config_path) {
    return Ok(false)
  }
  let kind = @fs.kind(config_path, follow_symlink=false) catch {
    _ => return Err("MoonDesk could not inspect the MoonClaw configuration")
  }
  match kind {
    Regular => Ok(true)
    SymLink => Err("MoonDesk refused a redirected MoonClaw configuration file")
    _ => Err("The existing MoonClaw configuration is not a regular file")
  }
}

///|
async fn moonclaw_remove_config_temp(path : String) -> Unit {
  @fs.remove(path) catch {
    _ => ()
  }
}

///|
async fn moonclaw_write_config_atomically(
  config_path : String,
  content : String,
) -> Result[Unit, String] {
  let temp_path = @pathx.join(
    @pathx.dirname(config_path),
    ".moonclaw.json." +
    @desk.stable_id("openrouter-config", @async.now().to_string()) +
    ".tmp",
  )
  @fs.write_file(
    temp_path,
    @encoding/utf8.encode(content),
    create_mode=CreateNew,
    permission=0o600,
    sync=Full,
  ) catch {
    _ =>
      return Err(
        "MoonDesk could not create a private MoonClaw configuration update",
      )
  }
  @fs.chmod(temp_path, 0o600) catch {
    _ => {
      moonclaw_remove_config_temp(temp_path)
      return Err("MoonDesk could not secure the MoonClaw configuration update")
    }
  }
  @fs.rename(temp_path, config_path, replace=true) catch {
    _ => {
      moonclaw_remove_config_temp(temp_path)
      return Err("MoonDesk could not replace the MoonClaw configuration")
    }
  }
  @fs.chmod(config_path, 0o600) catch {
    _ => return Err("MoonDesk could not secure the MoonClaw configuration")
  }
  Ok(())
}

///|
async fn moonclaw_write_openrouter_key(
  workspace_root : String,
  api_key : String,
) -> Result[String, String] {
  let root = workspace_context(workspace_root).suite_root
  let product_dir = moonsuite_product_artifact_for_workspace_root(
    root, "moonclaw", "",
  )
  @fsx.make_directory(product_dir, recursive=true, exists_ok=true) catch {
    _ =>
      return Err(
        "MoonDesk could not prepare the MoonClaw configuration directory",
      )
  }
  match moonclaw_secure_product_directory(root, product_dir) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  let config_path = moonsuite_product_artifact_for_workspace_root(
    root, "moonclaw", "moonclaw.json",
  )
  let config_exists = match moonclaw_existing_config_is_safe(config_path) {
    Ok(exists) => exists
    Err(message) => return Err(message)
  }
  let existing = if config_exists {
    let text = @fs.read_file(config_path).text() catch {
      _ =>
        return Err(
          "MoonDesk could not read the existing MoonClaw configuration",
        )
    }
    let json = @json.parse(text) catch {
      _ => return Err("The existing MoonClaw configuration is not valid JSON")
    }
    guard json is Object(_) else {
      return Err("The existing MoonClaw configuration must be a JSON object")
    }
    json
  } else {
    Json::empty_object()
  }
  let config = moonclaw_config_with_openrouter_key(existing, api_key)
  match moonclaw_secure_product_directory(root, product_dir) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  match
    moonclaw_write_config_atomically(
      config_path,
      config.stringify(indent=2) + "\n",
    ) {
    Err(message) => return Err(message)
    Ok(_) => ()
  }
  Ok(config_path)
}

///|
fn moonclaw_openrouter_key_success_response(
  config_path : String,
  daemon : Json,
  model_readiness : Json,
) -> Json {
  let ready = json_bool(model_readiness, "ready", default=false)
  api_contract_response(
    {
      "configured": true,
      "config_path": config_path,
      "daemon": daemon,
      "model_ready": ready,
      "model_readiness": model_readiness,
    },
    ok=true,
    status="openrouter_key_configured",
    message=if ready {
      "OpenRouter API key saved securely and a model is ready"
    } else {
      "OpenRouter API key saved securely; MoonClaw model readiness is not confirmed yet"
    },
    next_action=if ready { "use_moonclaw" } else { "inspect_moonclaw_models" },
  )
}

///|
fn moonclaw_openrouter_key_failure_response(
  status : String,
  message : String,
  next_action : String,
) -> Json {
  api_contract_response(
    { "model_ready": false },
    ok=false,
    status~,
    message~,
    next_action~,
  )
}

///|
async fn handle_moonclaw_openrouter_key(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let payload = match read_json_body(body) {
    Some(payload) => payload
    None => {
      send_json(
        conn,
        method_,
        moonclaw_openrouter_key_failure_response(
          "invalid_api_key", "Request body must be valid JSON", "enter_openrouter_api_key",
        ),
      )
      return
    }
  }
  let api_key = match moonclaw_openrouter_key_from_payload(payload) {
    Ok(api_key) => api_key
    Err(message) => {
      send_json(
        conn,
        method_,
        moonclaw_openrouter_key_failure_response(
          "invalid_api_key", message, "enter_openrouter_api_key",
        ),
      )
      return
    }
  }
  let config_path = match
    moonclaw_write_openrouter_key(workspace_root, api_key) {
    Ok(config_path) => config_path
    Err(message) => {
      send_json(
        conn,
        method_,
        moonclaw_openrouter_key_failure_response(
          "openrouter_key_write_failed", message, "inspect_moonclaw_configuration",
        ),
      )
      return
    }
  }
  let daemon = ensure_moonclaw_daemon_running(
    workspace_root,
    action="configure",
  )
  let model_readiness = if json_bool(daemon, "running", default=false) {
    moonclaw_model_readiness_from_probe(moonclaw_get_json(daemon, "/v1/models"))
  } else {
    moonclaw_model_readiness_unknown(
      "daemon-not-running",
      error=json_string(
        daemon,
        "message",
        default="MoonClaw daemon is not running",
      ),
    )
  }
  send_json(
    conn,
    method_,
    moonclaw_openrouter_key_success_response(
      config_path, daemon, model_readiness,
    ),
  )
}

///|
async fn handle_moonclaw_daemon_action(
  workspace_root : String,
  action : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let result = if action == "install" {
    install_moonclaw_release(workspace_root)
  } else {
    ensure_moonclaw_daemon_running(
      workspace_root,
      action=if action == "retry" { "restart" } else { "start" },
    )
  }
  send_json(conn, method_, result)
}

///|
async fn moonclaw_daemon_status(workspace_root : String) -> Json {
  moonclaw_daemon_status_with_platform(
    workspace_root,
    moonclaw_platform_support(),
  )
}

///|
fn moonclaw_installation_evidence_from_values(
  managed_install : Bool,
  service_configured : Bool,
  daemon_observed : Bool,
  repair_available? : Bool = false,
) -> Json {
  if managed_install {
    {
      "installed": true,
      "source": "managed-service",
      "reason": "managed-service-present",
    }
  } else if repair_available {
    {
      "installed": false,
      "source": "none",
      "reason": "stale-managed-service-config",
    }
  } else if service_configured {
    {
      "installed": true,
      "source": "external-configured-service",
      "reason": "external-service-configured",
    }
  } else if daemon_observed {
    {
      "installed": true,
      "source": "observed-daemon-info",
      "reason": "daemon-info-present",
    }
  } else {
    {
      "installed": false,
      "source": "none",
      "reason": "no-installation-evidence",
    }
  }
}

///|
fn moonclaw_configuration_evidence_from_values(
  installed : Bool,
  service_configured : Bool,
  configuration_valid? : Bool = true,
  configuration_reason? : String = "",
  repair_available? : Bool = false,
) -> Json {
  {
    "configured": service_configured,
    "valid": repair_available ||
    !installed ||
    (service_configured && configuration_valid),
    "reason": if repair_available {
      "stale-managed-service-config"
    } else if !installed {
      "not-installed"
    } else if !service_configured {
      "service-configuration-missing"
    } else if configuration_reason != "" {
      configuration_reason
    } else if configuration_valid {
      "service-configuration-valid"
    } else {
      "command-unavailable"
    },
  }
}

///|
fn moonclaw_configuration_evidence_from_descriptor(
  installed : Bool,
  descriptor : Json,
) -> Json {
  let configured = json_bool(descriptor, "configured", default=false)
  let valid = json_bool(descriptor, "configuration_valid", default=configured)
  let repair_available = json_bool(
    descriptor,
    "repair_available",
    default=false,
  )
  moonclaw_configuration_evidence_from_values(
    installed,
    configured,
    configuration_valid=valid,
    configuration_reason=json_string(
      descriptor,
      "configuration_reason",
      default=if valid { "configuration-valid" } else { "command-unavailable" },
    ),
    repair_available~,
  )
}

///|
async fn moonclaw_daemon_status_with_platform(
  workspace_root : String,
  platform_support : MoonClawPlatformSupport,
) -> Json {
  let context = workspace_context(workspace_root)
  let root = context.suite_root
  let info_path = moonclaw_daemon_info_path(root)
  let descriptor = moonclaw_service_descriptor(root, "daemon")
  let service_cwd = json_string(descriptor, "cwd", default=root)
  let service_configured = json_bool(descriptor, "configured", default=false)
  let managed_install = json_bool(descriptor, "managed_install", default=false)
  let repair_available = json_bool(
    descriptor,
    "repair_available",
    default=false,
  )
  let installed_version = json_string(descriptor, "version", default="")
  let service_source = if managed_install {
    "managed"
  } else if repair_available {
    "stale-managed"
  } else if service_configured {
    "external"
  } else {
    "missing"
  }
  let installation_evidence = moonclaw_installation_evidence_from_values(
    managed_install,
    service_configured,
    @fsx.exists(info_path),
    repair_available~,
  )
  let configuration_evidence = moonclaw_configuration_evidence_from_descriptor(
    json_bool(installation_evidence, "installed", default=false),
    descriptor,
  )
  if !@fsx.exists(info_path) {
    let message = if repair_available {
      "A copied MoonClaw service configuration points to an unavailable managed runtime; reinstall MoonClaw to repair it"
    } else if managed_install {
      "MoonClaw " + installed_version + " is installed but not running"
    } else if service_configured {
      "An external MoonClaw service is configured but not running"
    } else {
      "MoonClaw is not installed"
    }
    return api_contract_response(
      {
        "ok": false,
        "running": false,
        "port": 0,
        "pid": 0,
        "info_path": info_path,
        "moonclaw_root": service_cwd,
        "service_configured": service_configured,
        "service_config_path": json_string(
          descriptor,
          "config_path",
          default="",
        ),
        "service_command": json_string(descriptor, "display", default=""),
        "managed_install": managed_install,
        "managed_running": false,
        "repair_available": repair_available,
        "platform_evidence": moonclaw_platform_support_json(platform_support),
        "installation_evidence": installation_evidence,
        "configuration_evidence": configuration_evidence,
        "model_readiness": moonclaw_model_readiness_unknown(
          "daemon-not-running",
        ),
        "auth_readiness": moonclaw_auth_readiness_unknown("daemon-not-running"),
        "installed_version": installed_version,
        "running_version": "",
        "service_source": service_source,
        "service_path": moonsuite_product_artifact_for_workspace_root(
          root, "moonclaw", "",
        ),
      },
      ok=false,
      status=if repair_available {
        "repair_available"
      } else {
        "daemon_info_missing"
      },
      message~,
      next_action=if repair_available {
        "install_moonclaw"
      } else if managed_install || service_configured {
        "start_moonclaw"
      } else {
        "install_moonclaw"
      },
    )
  }
  let info = read_json_file_or_object(info_path)
  let port = json_int(info, "port", default=0)
  let pid = json_int(info, "pid", default=0)
  let running_version = json_string(info, "version", default="")
  let alive = pid > 0 && process_is_alive(pid)
  let port_reachable = port > 0 && moonclaw_port_reachable(port)
  let existing_allowed = !repair_available &&
    (
      service_configured ||
      moonclaw_allows_unconfigured_existing_daemon(context)
    )
  let reachable = moonclaw_existing_daemon_reachable(
    alive, port, port_reachable, existing_allowed,
  )
  let managed_running = reachable &&
    managed_install &&
    running_version.has_prefix(installed_version)
  let probe_daemon : Json = { "port": port }
  let model_readiness = if reachable {
    moonclaw_model_readiness_from_probe(
      moonclaw_get_json(probe_daemon, "/v1/models"),
    )
  } else {
    moonclaw_model_readiness_unknown("daemon-not-reachable")
  }
  let auth_readiness = if reachable {
    moonclaw_auth_readiness_from_probe(
      moonclaw_get_json(probe_daemon, "/v1/auth/status"),
    )
  } else {
    moonclaw_auth_readiness_unknown("daemon-not-reachable")
  }
  let model_known = json_bool(model_readiness, "known", default=false)
  let model_ready = json_bool(model_readiness, "ready", default=false)
  let needs_configuration = reachable && model_known && !model_ready
  let message = if repair_available {
    "A copied MoonClaw service configuration points to an unavailable managed runtime; reinstall MoonClaw to repair it"
  } else if managed_running && needs_configuration {
    "MoonClaw " +
    installed_version +
    " is installed and running, but a model must be configured"
  } else if managed_running {
    "MoonClaw " + installed_version + " is installed and running"
  } else if reachable && managed_install {
    "MoonClaw " +
    installed_version +
    " is installed, but a different MoonClaw service is running"
  } else if reachable && needs_configuration {
    "MoonClaw is running from an external service, but a model must be configured"
  } else if reachable {
    "MoonClaw is running from an external service; a MoonDesk-managed installation is not installed"
  } else if managed_install {
    "MoonClaw " + installed_version + " is installed but not running"
  } else if service_configured {
    "An external MoonClaw service is configured but not running"
  } else if alive && port > 0 && !existing_allowed {
    "MoonClaw daemon info exists but this temporary workspace needs an explicit service config"
  } else if alive && port > 0 {
    "MoonClaw daemon info exists but the HTTP port is not reachable"
  } else {
    "MoonClaw is not installed"
  }
  api_contract_response(
    {
      "ok": reachable,
      "running": reachable,
      "port": port,
      "pid": pid,
      "info_path": info_path,
      "moonclaw_root": service_cwd,
      "service_configured": service_configured,
      "service_config_path": json_string(descriptor, "config_path", default=""),
      "service_command": json_string(descriptor, "display", default=""),
      "managed_install": managed_install,
      "managed_running": managed_running,
      "repair_available": repair_available,
      "platform_evidence": moonclaw_platform_support_json(platform_support),
      "installation_evidence": installation_evidence,
      "configuration_evidence": configuration_evidence,
      "model_readiness": model_readiness,
      "auth_readiness": auth_readiness,
      "installed_version": installed_version,
      "running_version": running_version,
      "service_source": service_source,
      "service_path": moonsuite_product_artifact_for_workspace_root(
        root, "moonclaw", "",
      ),
    },
    ok=reachable,
    status=if repair_available {
      "repair_available"
    } else if needs_configuration {
      "running_needs_configuration"
    } else if reachable {
      "running"
    } else if alive && port > 0 && !existing_allowed {
      "service_config_required"
    } else if alive && port > 0 {
      "port_unreachable"
    } else {
      "process_unreachable"
    },
    message~,
    next_action=if repair_available {
      "install_moonclaw"
    } else if needs_configuration {
      "configure_model"
    } else if managed_running {
      "use_moonclaw"
    } else if reachable {
      "install_moonclaw"
    } else if service_configured {
      "restart_moonclaw"
    } else {
      "configure_moonclaw_service"
    },
  )
}

///|
async fn ensure_moonclaw_daemon_running(
  workspace_root : String,
  action? : String = "start",
) -> Json {
  let status = moonclaw_daemon_status(workspace_root)
  if json_bool(status, "running", default=false) {
    return status
  }
  if !json_bool(status, "service_configured", default=false) {
    return status
  }
  let root = workspace_context(workspace_root).suite_root
  let start = start_moonclaw_daemon(root, action~)
  if !json_bool(start, "ok", default=false) {
    return start
  }
  moonclaw_daemon_status(workspace_root)
}

///|
async fn start_moonclaw_daemon(
  root : String,
  action? : String = "start",
) -> Json {
  let descriptor = moonclaw_service_descriptor(root, "daemon")
  if !json_bool(descriptor, "configured", default=false) {
    return moonclaw_daemon_lifecycle_result(
      root,
      action~,
      ok=false,
      status="not-configured",
      message="MoonClaw daemon service is not configured for this workspace",
    )
  }
  if !json_bool(descriptor, "configuration_valid", default=true) {
    return moonclaw_daemon_configuration_failure(
      root,
      action~,
      message="MoonClaw daemon service configuration is not usable",
    )
  }
  let state_dir = moonsuite_product_artifact_for_workspace_root(
    root, "moonclaw", "moondesk-daemon-lifecycle",
  )
  @fsx.make_directory(state_dir, recursive=true, exists_ok=true) catch {
    _ =>
      return moonclaw_daemon_lifecycle_result(
        root,
        action~,
        ok=false,
        status="failed",
        message="Could not create MoonClaw daemon lifecycle directory",
      )
  }
  let id = @desk.stable_id("moonclaw-daemon", @async.now().to_string())
  let stdout_path = @pathx.join(state_dir, id + ".out.log")
  let stderr_path = @pathx.join(state_dir, id + ".err.log")
  let stdout_file = @process.redirect_to_file(
    stdout_path,
    append=true,
    create_mode=OpenOrCreate,
    permission=0o644,
  ) catch {
    _ =>
      return moonclaw_daemon_lifecycle_result(
        root,
        action~,
        ok=false,
        status="failed",
        message="Could not open MoonClaw daemon stdout log",
      )
  }
  let stderr_file = @process.redirect_to_file(
    stderr_path,
    append=true,
    create_mode=OpenOrCreate,
    permission=0o644,
  ) catch {
    _ =>
      return moonclaw_daemon_lifecycle_result(
        root,
        action~,
        ok=false,
        status="failed",
        message="Could not open MoonClaw daemon stderr log",
      )
  }
  let executable = json_string(descriptor, "command", default="")
  let args = json_string_array_items(descriptor, "args")
  let cwd = json_string(descriptor, "cwd", default=root)
  let command = json_string(descriptor, "display", default="")
  let pid = @process.spawn_orphan(
    executable,
    args,
    cwd~,
    stdout=stdout_file,
    stderr=stderr_file,
  ) catch {
    error =>
      return moonclaw_daemon_lifecycle_result(
        root,
        action~,
        ok=false,
        status="failed",
        message="Could not start MoonClaw daemon: \{error}",
        command~,
        stdout_path~,
        stderr_path~,
      )
  }
  let info_path = moonclaw_daemon_info_path(root)
  let mut reachable = false
  let mut exited = false
  let mut checks = 0
  while checks < 120 {
    @async.sleep(500)
    let status = moonclaw_daemon_status(root)
    if json_bool(status, "running", default=false) {
      reachable = true
      break
    }
    if pid > 0 && !process_is_alive(pid) {
      exited = true
      break
    }
    checks += 1
  }
  let failure_detail = if exited {
    moonclaw_startup_failure_detail(stderr_path, stdout_path)
  } else {
    ""
  }
  moonclaw_daemon_lifecycle_result(
    root,
    action~,
    ok=reachable,
    status=if reachable {
      "running"
    } else if exited {
      "exited"
    } else {
      "starting"
    },
    running=reachable,
    message=if reachable {
      "MoonClaw daemon started"
    } else if exited && failure_detail != "" {
      failure_detail
    } else if exited {
      "MoonClaw daemon exited before it became reachable"
    } else {
      "MoonClaw daemon was spawned but is not reachable yet"
    },
    pid~,
    command~,
    info_path~,
    stdout_path~,
    stderr_path~,
  )
}

///|
async fn moonclaw_daemon_configuration_failure(
  root : String,
  action~ : String,
  message~ : String,
) -> Json {
  let status = moonclaw_daemon_status(root)
  let fields = match status {
    Object(fields) => fields.copy()
    _ => {}
  }
  fields["action"] = action.to_json()
  fields["ok"] = false.to_json()
  fields["running"] = false.to_json()
  fields["status"] = "misconfigured".to_json()
  fields["message"] = message.to_json()
  fields["next_action"] = "configure_moonclaw".to_json()
  Json::object(fields)
}

///|
async fn moonclaw_startup_failure_detail(
  stderr_path : String,
  stdout_path : String,
) -> String {
  let stderr_text = @fs.read_file(stderr_path).text() catch { _ => "" }
  let stderr_text = stderr_text.trim().to_owned()
  if stderr_text != "" {
    return "MoonClaw daemon exited: " + stderr_text
  }
  let stdout_text = @fs.read_file(stdout_path).text() catch { _ => "" }
  let stdout_text = stdout_text.trim().to_owned()
  if stdout_text != "" {
    return "MoonClaw daemon exited: " + stdout_text
  }
  ""
}

///|
fn moonclaw_daemon_lifecycle_result(
  root : String,
  action~ : String,
  ok~ : Bool,
  status~ : String,
  message~ : String,
  running? : Bool = false,
  pid? : Int = 0,
  command? : String = "",
  info_path? : String = "",
  stdout_path? : String = "",
  stderr_path? : String = "",
) -> Json {
  api_contract_response(
    {
      "action": action,
      "running": running,
      "pid": pid,
      "command": command,
      "info_path": if info_path == "" {
        moonclaw_daemon_info_path(root)
      } else {
        info_path
      },
      "stdout_path": stdout_path,
      "stderr_path": stderr_path,
    },
    ok~,
    status~,
    message~,
    next_action=if ok { "use_moonclaw" } else { "inspect_moonclaw_daemon" },
  )
}

///|
fn moonclaw_existing_daemon_reachable(
  alive : Bool,
  port : Int,
  port_reachable : Bool,
  existing_allowed : Bool,
) -> Bool {
  existing_allowed && alive && port > 0 && port_reachable
}

///|
fn moonclaw_allows_unconfigured_existing_daemon(
  context : WorkspaceContext,
) -> Bool {
  let root = context.suite_root
  !(root.has_prefix("/tmp/") ||
  root.has_prefix("/private/tmp/") ||
  root.has_prefix("/var/folders/") ||
  root.has_prefix("/private/var/folders/"))
}

///|
async fn process_is_alive(pid : Int) -> Bool {
  let code = run_process_quiet("kill", ["-0", pid.to_string()])
  if code != 0 {
    return false
  }
  let (status_code, stdout, _) = run_process_capture("ps", [
    "-p",
    pid.to_string(),
    "-o",
    "stat=",
  ])
  status_code == 0 && process_status_is_alive(stdout)
}

///|
fn process_status_is_alive(status : String) -> Bool {
  let status = status.trim().to_owned()
  status != "" && !status.has_prefix("Z")
}

///|
async fn moonclaw_port_reachable(port : Int) -> Bool {
  let (response, body) = @http.get("http://127.0.0.1:\{port}/v1/health") catch {
    _ => return false
  }
  if response.code != 200 {
    return false
  }
  let health = @json.parse(body.text()) catch { _ => return false }
  json_bool(health, "ok", default=false) &&
  json_string(health, "service", default="") == "moonclaw"
}

///|
fn moonclaw_daemon_info_path(workspace_root : String) -> String {
  moonsuite_product_artifact_for_workspace_root(
    workspace_root, "moonclaw", "daemon.json",
  )
}

///|
fn moonclaw_daemon_with_message(daemon : Json, message : String) -> Json {
  @mooncore.session_with_field(
    @mooncore.session_with_field(daemon, "ok", false.to_json()),
    "message",
    message.to_json(),
  )
}

///|
async fn moonclaw_get_json(
  daemon : Json,
  path : String,
) -> Result[Json, String] {
  let port = json_int(daemon, "port", default=0)
  if port <= 0 {
    return Err("MoonClaw daemon port is not available")
  }
  let (response, data) = @http.get("http://127.0.0.1:\{port}\{path}") catch {
    error => return Err("MoonClaw GET \{path} failed: \{error}")
  }
  let text = data.text() catch { _ => "" }
  if response.code < 200 || response.code > 299 {
    return Err("MoonClaw GET \{path} returned \{response.code}: \{text}")
  }
  let payload = @json.parse(text) catch {
    _ => return Err("MoonClaw GET \{path} returned invalid JSON")
  }
  Ok(payload)
}

///|
async fn moonclaw_get_text(
  daemon : Json,
  path : String,
) -> Result[String, String] {
  let port = json_int(daemon, "port", default=0)
  if port <= 0 {
    return Err("MoonClaw daemon port is not available")
  }
  let (response, data) = @http.get("http://127.0.0.1:\{port}\{path}") catch {
    error => return Err("MoonClaw GET \{path} failed: \{error}")
  }
  let text = data.text() catch { _ => "" }
  if response.code < 200 || response.code > 299 {
    return Err("MoonClaw GET \{path} returned \{response.code}: \{text}")
  }
  Ok(text)
}

///|
async fn moonclaw_post_json(
  daemon : Json,
  path : String,
  body : Json,
) -> Result[Json, String] {
  let port = json_int(daemon, "port", default=0)
  if port <= 0 {
    return Err("MoonClaw daemon port is not available")
  }
  let (response, data) = @http.post("http://127.0.0.1:\{port}\{path}", body, headers={
    "Content-Type": "application/json",
  }) catch {
    error => return Err("MoonClaw POST \{path} failed: \{error}")
  }
  let text = data.text() catch { _ => "" }
  if response.code < 200 || response.code > 299 {
    return Err("MoonClaw POST \{path} returned \{response.code}: \{text}")
  }
  let payload = @json.parse(text) catch {
    _ => return Err("MoonClaw POST \{path} returned invalid JSON")
  }
  Ok(payload)
}

///|
fn json_object_field(json : Json, key : String) -> Json? {
  @mooncore.json_object_field(json, key)
}

///|
fn json_array(json : Json, key : String) -> Json {
  Json::array(json_array_items(json, key))
}

///|
fn json_array_items(json : Json, key : String) -> Array[Json] {
  @mooncore.json_array_items(json, key)
}
