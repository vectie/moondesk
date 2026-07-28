///|
test "capability classifier returns every state" {
  assert_true(
    classify_capability(true, true, true, true, true) is DetectedRunning,
  )
  assert_true(
    classify_capability(true, true, false, true, true) is InstalledStopped,
  )
  assert_true(
    classify_capability(true, true, false, false, true) is NotInstalled,
  )
  assert_true(
    classify_capability(true, true, false, true, false) is Misconfigured,
  )
  assert_true(
    classify_capability(false, true, true, true, true) is UnsupportedPlatform,
  )
  assert_true(
    classify_capability(true, false, true, true, true) is TemporarilyUnavailable,
  )
}

///|
test "capability classifier precedence is deterministic" {
  assert_true(
    classify_capability(false, false, true, false, false) is UnsupportedPlatform,
  )
  assert_true(
    classify_capability(true, false, true, false, false)
    is TemporarilyUnavailable,
  )
  assert_true(
    classify_capability(true, true, true, false, false) is DetectedRunning,
  )
  assert_true(
    classify_capability(true, true, false, false, false) is NotInstalled,
  )
  assert_true(
    classify_capability(true, true, false, true, false) is Misconfigured,
  )
}

///|
test "capability copy is exact for every state" {
  assert_eq(code_capability_title(DetectedRunning), "Code assistance is ready")
  assert_eq(
    code_capability_detail(DetectedRunning),
    "You can start or continue Code conversations.",
  )
  assert_eq(
    code_capability_title(InstalledStopped),
    "Code assistance is stopped",
  )
  assert_eq(
    code_capability_detail(InstalledStopped),
    "Start Code assistance before beginning a conversation.",
  )
  assert_eq(
    code_capability_title(InstalledNeedsConfiguration),
    "Code assistance needs an account or model",
  )
  assert_eq(
    code_capability_detail(InstalledNeedsConfiguration),
    "Connect Codex, GitHub Copilot, or OpenRouter to finish setup.",
  )
  assert_eq(
    code_capability_title(NotInstalled),
    "Code assistance is not installed",
  )
  assert_eq(
    code_capability_detail(NotInstalled),
    "Install Code assistance to use Code conversations.",
  )
  assert_eq(
    code_capability_title(Misconfigured),
    "Code assistance needs configuration",
  )
  assert_eq(
    code_capability_detail(Misconfigured),
    "Review the configuration before using Code assistance.",
  )
  assert_eq(
    code_capability_title(UnsupportedPlatform),
    "Code assistance is not supported here",
  )
  assert_eq(
    code_capability_detail(UnsupportedPlatform),
    "You can continue with Pages and files without local Code assistance.",
  )
  assert_eq(
    code_capability_title(TemporarilyUnavailable),
    "Code assistance status is unavailable",
  )
  assert_eq(
    code_capability_detail(TemporarilyUnavailable),
    "Check again when status information is available. Pages and files remain available.",
  )
}

///|
test "every capability primary action and label is exact" {
  assert_true(
    code_capability_primary_action(DetectedRunning) is NoPrimaryAction,
  )
  assert_true(
    code_capability_primary_action(InstalledStopped) is StartCapability,
  )
  assert_true(
    code_capability_primary_action(InstalledNeedsConfiguration)
    is ConfigureCapability,
  )
  assert_true(code_capability_primary_action(NotInstalled) is InstallCapability)
  assert_true(
    code_capability_primary_action(Misconfigured) is OpenConfiguration,
  )
  assert_true(
    code_capability_primary_action(UnsupportedPlatform) is NoPrimaryAction,
  )
  assert_true(
    code_capability_primary_action(TemporarilyUnavailable)
    is RetryCapabilityCheck,
  )
  assert_eq(code_capability_primary_action_label(NoPrimaryAction), "")
  assert_eq(
    code_capability_primary_action_label(StartCapability),
    "Start Code assistance",
  )
  assert_eq(
    code_capability_primary_action_label(InstallCapability),
    "Install Code assistance",
  )
  assert_eq(
    code_capability_primary_action_label(ConfigureCapability),
    "Connect Codex",
  )
  assert_eq(
    code_capability_primary_action_label(OpenConfiguration),
    "Review configuration",
  )
  assert_eq(
    code_capability_primary_action_label(RetryCapabilityCheck),
    "Check again",
  )
}

///|
fn capability_test_daemon(
  running : Bool,
  configured : Bool,
  installed : Bool?,
  platform_supported? : Bool,
  evidence_installed? : Bool,
  evidence_configured? : Bool,
  evidence_valid? : Bool,
) -> MoonClawDaemonStatus {
  {
    ok: None,
    status: None,
    next_action: None,
    model_ready: None,
    model_readiness: None,
    repair_available: None,
    running,
    port: 0,
    message: "",
    service_configured: configured,
    managed_install: installed,
    managed_running: Some(running),
    installation_evidence: evidence_installed.map(value => {
      installed: value,
      source: if value {
        "test-source"
      } else {
        "none"
      },
      reason: if value {
        "test-installation"
      } else {
        "not-installed"
      },
    }),
    configuration_evidence: match (evidence_configured, evidence_valid) {
      (Some(configured), Some(valid)) =>
        Some({
          configured,
          valid,
          reason: if valid {
            "service-configuration-valid"
          } else {
            "service-configuration-missing"
          },
        })
      _ => None
    },
    platform_evidence: match platform_supported {
      Some(supported) =>
        Some({
          supported,
          platform: if supported {
            "macos"
          } else {
            "unsupported"
          },
          architecture: if supported {
            "arm64"
          } else {
            "unsupported"
          },
        })
      None => None
    },
  }
}

///|
test "daemon evidence maps without parsing status messages" {
  assert_true(moonclaw_capability_state(None) is TemporarilyUnavailable)
  assert_true(
    moonclaw_capability_state(
      Some(capability_test_daemon(true, false, Some(false))),
    )
    is TemporarilyUnavailable,
  )
  assert_true(
    moonclaw_capability_state(
      Some(capability_test_daemon(false, true, Some(true))),
    )
    is InstalledStopped,
  )
  assert_true(
    moonclaw_capability_state(
      Some(capability_test_daemon(false, false, Some(false))),
    )
    is NotInstalled,
  )
  assert_true(
    moonclaw_capability_state(
      Some(capability_test_daemon(false, false, Some(true))),
    )
    is InstalledNeedsConfiguration,
  )
  assert_true(
    moonclaw_capability_state(Some(capability_test_daemon(false, false, None)))
    is NotInstalled,
  )
  assert_true(
    moonclaw_capability_state(
      Some(
        capability_test_daemon(true, true, Some(true), platform_supported=false),
      ),
    )
    is UnsupportedPlatform,
  )
  assert_true(
    moonclaw_capability_state(
      Some(
        capability_test_daemon(false, true, Some(true), platform_supported=true),
      ),
    )
    is InstalledStopped,
  )
  assert_true(
    moonclaw_capability_state(
      Some(
        capability_test_daemon(
          false,
          true,
          Some(false),
          evidence_installed=true,
          evidence_configured=true,
          evidence_valid=true,
        ),
      ),
    )
    is InstalledStopped,
  )
  assert_true(
    moonclaw_capability_state(
      Some(
        capability_test_daemon(
          false,
          false,
          Some(false),
          evidence_installed=true,
          evidence_configured=false,
          evidence_valid=false,
        ),
      ),
    )
    is Misconfigured,
  )
}

///|
#warnings("-alert_unstable")
test "fresh and copied clean-Mac evidence remains installable or repairable" {
  let fresh = {
    ..capability_test_daemon(
      false,
      false,
      Some(false),
      platform_supported=true,
      evidence_installed=false,
      evidence_configured=false,
      evidence_valid=true,
    ),
    ok: Some(false),
    status: Some("daemon_info_missing"),
    next_action: Some("install_moonclaw"),
  }
  assert_true(moonclaw_capability_state(Some(fresh)) is NotInstalled)
  let repair = {
    ..fresh,
    status: Some("repair_available"),
    repair_available: Some(true),
  }
  assert_true(moonclaw_capability_state(Some(repair)) is NotInstalled)
  let markup = home_code_capability_public_markup({
    ..init_model(),
    moonclaw_daemon: Some(repair),
  })
  assert_true(markup.contains(">Repair Code assistance<"))
  assert_code_assistance_i18n_key(markup, "code.assistance_action_repair")
  assert_false(markup.contains(">Review configuration<"))
  let repairing = {
    ..init_model(),
    moonclaw_daemon: Some(repair),
    moonclaw_installing: true,
  }
  let repairing_markup = home_code_capability_public_markup(repairing)
  assert_true(repairing_markup.contains(">Repairing Code assistance…<"))
  assert_code_assistance_i18n_key(repairing_markup, "code.assistance_repairing")
  let dispatch : Dispatch[Msg] = fn(_) { @rabbita.none }
  let runtime_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_mooncode_runtime_setup(dispatch, repairing)),
  )
  assert_true(runtime_markup.contains(">Repairing Code assistance…<"))
  assert_code_assistance_i18n_key(runtime_markup, "code.assistance_repairing")
}

///|
test "model readiness distinguishes running setup from ready and stopped" {
  let running = capability_test_daemon(true, true, Some(true))
  assert_true(
    moonclaw_capability_state(Some({ ..running, model_ready: Some(false) }))
    is InstalledNeedsConfiguration,
  )
  assert_true(
    moonclaw_capability_state(
      Some({
        ..running,
        model_readiness: Some({
          known: true,
          ready: false,
          status: "needs_configuration",
          reason: "default-model-unavailable",
          default_model: "",
        }),
      }),
    )
    is InstalledNeedsConfiguration,
  )
  assert_true(
    moonclaw_capability_state(Some({ ..running, model_ready: Some(true) }))
    is DetectedRunning,
  )
  assert_true(
    moonclaw_capability_state(
      Some({
        ..capability_test_daemon(false, true, Some(true)),
        model_ready: Some(true),
      }),
    )
    is InstalledStopped,
  )
}

///|
test "sessions require positively confirmed model readiness" {
  assert_true(moonclaw_model_readiness_allows_sessions(Some(true)))
  assert_false(moonclaw_model_readiness_allows_sessions(Some(false)))
  assert_false(moonclaw_model_readiness_allows_sessions(None))
}

///|
test "MoonClaw DTOs decode readiness and actionable auth failures" {
  let daemon : MoonClawDaemonStatus = @json.from_json({
    "ok": true,
    "status": "running_needs_configuration",
    "next_action": "configure_model",
    "repair_available": false,
    "running": true,
    "port": 1515,
    "message": "MoonClaw is running but no default model is available",
    "service_configured": true,
    "managed_install": true,
    "managed_running": true,
    "model_readiness": {
      "known": true,
      "ready": false,
      "status": "needs_configuration",
      "reason": "default-model-unavailable",
      "default_model": "",
      "models": [{ "name": "codex/gpt-5.4", "default": false }],
    },
  })
  assert_true(
    moonclaw_capability_state(Some(daemon)) is InstalledNeedsConfiguration,
  )
  assert_eq(daemon.status, Some("running_needs_configuration"))
  let auth_failure : MoonClawCodexAuthFlow = @json.from_json({
    "ok": false,
    "status": "auth_start_failed",
    "message": "callback port unavailable",
    "next_action": "retry_auth",
    "model_ready": false,
  })
  assert_true(auth_failure.auth_url is None)
  assert_eq(auth_failure.status, Some("auth_start_failed"))
}

///|
test "platform evidence remains optional and technical" {
  let missing = capability_test_daemon(false, true, Some(true))
  assert_true(capability_platform_technical_detail(missing) is None)
  let unsupported = capability_test_daemon(
    false,
    true,
    Some(true),
    platform_supported=false,
  )
  assert_true(
    capability_platform_technical_detail(unsupported)
    is Some(
      "Platform: unsupported; architecture: unsupported; supported: false"
    ),
  )
}

///|
test "capability status projection is exact" {
  assert_eq(capability_state_key(DetectedRunning), "detected-running")
  assert_eq(capability_state_key(InstalledStopped), "installed-stopped")
  assert_eq(
    capability_state_key(InstalledNeedsConfiguration),
    "installed-needs-configuration",
  )
  assert_eq(capability_state_key(NotInstalled), "not-installed")
  assert_eq(capability_state_key(Misconfigured), "misconfigured")
  assert_eq(capability_state_key(UnsupportedPlatform), "unsupported-platform")
  assert_eq(
    capability_state_key(TemporarilyUnavailable),
    "temporarily-unavailable",
  )
  assert_eq(capability_status_key(DetectedRunning), "ready")
  assert_eq(capability_status_key(TemporarilyUnavailable), "unknown")
  assert_eq(capability_status_key(Misconfigured), "missing")
  assert_eq(capability_status_label(DetectedRunning), "running")
  assert_eq(capability_status_label(InstalledStopped), "installed, stopped")
  assert_eq(
    capability_status_label(InstalledNeedsConfiguration),
    "setup needed",
  )
  assert_eq(capability_status_label(NotInstalled), "not installed")
  assert_eq(capability_status_label(Misconfigured), "needs configuration")
  assert_eq(capability_status_label(UnsupportedPlatform), "not supported")
  assert_eq(capability_status_label(TemporarilyUnavailable), "checking")
}

///|
fn requests_capability_test_lifecycle(
  running : Bool,
  configured : Bool,
  ok? : Bool = true,
  platform_supported? : Bool? = None,
  installed? : Bool? = None,
  configuration_valid? : Bool,
) -> DaemonLifecycleResult {
  {
    ok,
    action: "status",
    status: if running {
      "running"
    } else {
      "stopped"
    },
    running,
    pid: if running {
      42
    } else {
      0
    },
    command: if configured {
      "moon run moontown"
    } else {
      ""
    },
    cwd: "/suite",
    started_at: "",
    stopped_at: "",
    pid_file: "/suite/.moonsuite/products/moontown/daemon.json",
    stdout_path: "",
    stderr_path: "",
    message: "",
    supervision_enabled: false,
    desired_state: if running {
      "running"
    } else {
      "stopped"
    },
    restart_count: 0,
    last_health_check: "",
    policy_file: "/suite/.moonsuite/products/moontown/policy.json",
    service_configured: configured,
    service_config_path: "/suite/.moonsuite/products/moontown/service.json",
    service_cwd: "/suite/moontown",
    platform_evidence: platform_supported.map(supported => {
      supported,
      platform: if supported {
        "macos"
      } else {
        "windows"
      },
      architecture: "arm64",
    }),
    installation_evidence: installed.map(installed => {
      installed,
      source: if installed {
        "service-configured"
      } else {
        "none"
      },
    }),
    configuration_evidence: configuration_valid.map(valid => {
      configured,
      valid,
      reason: if !valid {
        "service-configuration-missing"
      } else if configured {
        "service-configured"
      } else {
        "not-installed"
      },
    }),
  }
}

///|
test "Requests automation capability uses structured lifecycle evidence" {
  assert_true(
    requests_capability_state(
      Some(requests_capability_test_lifecycle(true, true)),
      true,
    )
    is DetectedRunning,
  )
  assert_true(
    requests_capability_state(
      Some(requests_capability_test_lifecycle(false, true)),
      true,
    )
    is InstalledStopped,
  )
  assert_true(
    requests_capability_state(
      Some(requests_capability_test_lifecycle(false, false)),
      true,
    )
    is Misconfigured,
  )
  assert_true(
    requests_capability_state(
      Some(
        requests_capability_test_lifecycle(
          false,
          true,
          ok=false,
          installed=Some(true),
          configuration_valid=true,
        ),
      ),
      true,
    )
    is InstalledStopped,
  )
  assert_true(
    requests_capability_state(
      Some(
        requests_capability_test_lifecycle(
          false,
          false,
          installed=Some(true),
          configuration_valid=false,
        ),
      ),
      true,
    )
    is Misconfigured,
  )
  assert_true(
    requests_capability_state(
      Some(requests_capability_test_lifecycle(true, true)),
      false,
    )
    is TemporarilyUnavailable,
  )
  assert_true(requests_capability_state(None, true) is TemporarilyUnavailable)
  assert_true(
    requests_capability_state(
      Some(
        requests_capability_test_lifecycle(
          false,
          false,
          installed=Some(false),
          configuration_valid=true,
        ),
      ),
      true,
    )
    is NotInstalled,
  )
  assert_true(
    requests_capability_state(
      Some(
        requests_capability_test_lifecycle(
          false,
          true,
          platform_supported=Some(false),
          installed=Some(true),
          configuration_valid=true,
        ),
      ),
      true,
    )
    is UnsupportedPlatform,
  )
  assert_true(
    requests_capability_state(
      Some(requests_capability_test_lifecycle(false, false)),
      true,
    )
    is Misconfigured,
  )
}

///|
test "Requests automation copy and actions do not claim request staging is blocked" {
  assert_eq(
    requests_capability_title(DetectedRunning),
    "Request automation is ready",
  )
  assert_true(
    requests_capability_detail(InstalledStopped).contains(
      "Requests can still be saved",
    ),
  )
  assert_true(
    requests_capability_detail(Misconfigured).contains(
      "Requests can still be saved",
    ),
  )
  assert_true(
    requests_capability_detail(TemporarilyUnavailable).contains(
      "Requests can still be saved",
    ),
  )
  assert_true(
    requests_capability_primary_action(InstalledStopped)
    is StartRequestsAutomation,
  )
  assert_true(
    requests_capability_primary_action(Misconfigured) is ReviewRequestsSetup,
  )
  assert_true(
    requests_capability_primary_action(TemporarilyUnavailable)
    is RetryRequestsCapabilityCheck,
  )
  assert_eq(
    requests_capability_primary_action_label(StartRequestsAutomation),
    "Start automation",
  )
}

///|
test "Requests capability probe transitions preserve prior lifecycle evidence" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let stopped = requests_capability_test_lifecycle(false, true)
  let (_, loaded) = update_daemon_results(
    dispatch,
    LoadedDaemonLifecycle(Ok(stopped)),
    init_model(),
  )
  assert_true(loaded.town_capability_probe_available)
  assert_true(
    requests_capability_state(
      loaded.daemon_lifecycle,
      loaded.town_capability_probe_available,
    )
    is InstalledStopped,
  )
  let (_, failed) = update_daemon_results(
    dispatch,
    LoadedDaemonLifecycle(Err("automation probe failed")),
    loaded,
  )
  assert_false(failed.town_capability_probe_available)
  assert_eq(failed.daemon_status, "automation probe failed")
  match failed.daemon_lifecycle {
    Some(previous) => {
      assert_true(previous.service_configured)
      assert_eq(previous.service_config_path, stopped.service_config_path)
    }
    None => fail("transient failure discarded prior lifecycle evidence")
  }
  let (_, checking) = update_daemon_actions(
    dispatch,
    FetchDaemonLifecycle,
    loaded,
  )
  assert_false(checking.town_capability_probe_available)
  let status_items = workspace_service_status_items(loaded)
  assert_eq(status_items[4].0, "Requests")
  assert_eq(status_items[4].1, "missing")
  assert_eq(status_items[4].2, "installed, stopped")
}

///|
#warnings("-alert_unstable")
test "Requests capability rendering keeps setup technical and composer usable" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let stopped = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    request_prompt: "Update the book",
    daemon_lifecycle: Some(
      requests_capability_test_lifecycle(
        false,
        true,
        platform_supported=Some(true),
        installed=Some(true),
        configuration_valid=true,
      ),
    ),
    town_capability_probe_available: true,
  }
  assert_false(wiki_task_start_disabled(stopped))
  let stopped_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_town_pane(dispatch, stopped)),
  )
  assert_true(stopped_markup.contains("data-testid=\"requests-capability\""))
  assert_true(stopped_markup.contains("data-testid=\"requests-prompt\""))
  assert_true(stopped_markup.contains("data-testid=\"requests-submit\""))
  assert_true(stopped_markup.contains("data-state=\"installed-stopped\""))
  assert_true(stopped_markup.contains("Start automation"))
  assert_true(stopped_markup.contains("Requests can still be saved"))
  assert_true(stopped_markup.contains("Technical details"))
  assert_true(stopped_markup.contains("Configuration file"))
  assert_true(stopped_markup.contains("service.json"))
  assert_true(stopped_markup.contains("Platform"))
  assert_true(stopped_markup.contains("macos"))
  assert_true(stopped_markup.contains("Automation installation"))
  assert_true(stopped_markup.contains("service-configured"))
  assert_false(stopped_markup.contains("Code assistance is stopped"))
  let invalid = {
    ..stopped,
    daemon_lifecycle: Some(
      requests_capability_test_lifecycle(
        false,
        false,
        installed=Some(true),
        configuration_valid=false,
      ),
    ),
  }
  let invalid_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_town_pane(dispatch, invalid)),
  )
  assert_true(invalid_markup.contains("data-state=\"misconfigured\""))
  assert_true(invalid_markup.contains("<details"))
  assert_true(invalid_markup.contains("Technical details"))
  assert_true(invalid_markup.contains("service-configuration-missing"))
  assert_false(
    requests_capability_title(Misconfigured).contains(
      "service-configuration-missing",
    ),
  )
  assert_false(
    requests_capability_detail(Misconfigured).contains(
      "service-configuration-missing",
    ),
  )
  let unavailable_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_town_pane(dispatch, {
        ..stopped,
        town_capability_probe_available: false,
      }),
    ),
  )
  assert_true(unavailable_markup.contains("temporarily-unavailable"))
  assert_true(unavailable_markup.contains("Check again"))
  assert_false(
    wiki_task_start_disabled({
      ..stopped,
      town_capability_probe_available: false,
    }),
  )
}

///|
#warnings("-alert_unstable")
fn home_code_capability_markup(model : Model) -> String {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  @rabbita.render_to_string(
    @rabbita.static_cell(render_moongate_setup(dispatch, model)),
  )
}

///|
#warnings("-alert_unstable")
fn home_code_capability_public_markup(model : Model) -> String {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let state = moonclaw_capability_state(model.moonclaw_daemon)
  @rabbita.render_to_string(
    @rabbita.static_cell(
      render_home_code_assistance_public(
        dispatch,
        model,
        state,
        code_capability_primary_action(state),
      ),
    ),
  )
}

///|
fn assert_only_home_code_action(
  markup : String,
  expected : String,
) -> Unit raise {
  for
    label in [
      "Start Code assistance", "Install Code assistance", "Repair Code assistance",
      "Connect Codex", "Review configuration", "Check again",
    ] {
    assert_eq(markup.contains(">\{label}<"), label == expected)
  }
}

///|
fn assert_code_assistance_i18n_key(markup : String, key : String) -> Unit raise {
  assert_true(markup.contains("data-i18n=\"\{key}\""))
}

///|
test "Code assistance localization mappings use only authoritative keys" {
  let states : Array[(CapabilityState, String, String, String)] = [
    (
      DetectedRunning,
      "code.assistance_title_detected_running",
      "code.assistance_detail_detected_running",
      "code.assistance_status_running",
    ),
    (
      InstalledStopped,
      "code.assistance_title_installed_stopped",
      "code.assistance_detail_installed_stopped",
      "code.assistance_status_installed_stopped",
    ),
    (
      InstalledNeedsConfiguration,
      "code.assistance_title_installed_needs_configuration",
      "code.assistance_detail_installed_needs_configuration",
      "code.assistance_status_installed_needs_configuration",
    ),
    (
      NotInstalled,
      "code.assistance_title_not_installed",
      "code.assistance_detail_not_installed",
      "code.assistance_status_not_installed",
    ),
    (
      Misconfigured,
      "code.assistance_title_misconfigured",
      "code.assistance_detail_misconfigured",
      "code.assistance_status_needs_configuration",
    ),
    (
      UnsupportedPlatform,
      "code.assistance_title_unsupported_platform",
      "code.assistance_detail_unsupported_platform",
      "code.assistance_status_not_supported",
    ),
    (
      TemporarilyUnavailable,
      "code.assistance_title_temporarily_unavailable",
      "code.assistance_detail_temporarily_unavailable",
      "code.assistance_status_checking",
    ),
  ]
  for item in states {
    let (state, title_key, detail_key, status_key) = item
    assert_eq(code_capability_title_i18n_key(state), title_key)
    assert_eq(code_capability_detail_i18n_key(state), detail_key)
    assert_eq(code_capability_status_i18n_key(state), status_key)
  }
  let actions : Array[(CodeCapabilityPrimaryAction, String)] = [
    (NoPrimaryAction, ""),
    (StartCapability, "code.assistance_action_start"),
    (InstallCapability, "code.assistance_action_install"),
    (ConfigureCapability, "code.assistance_action_connect"),
    (OpenConfiguration, "code.assistance_action_open_configuration"),
    (RetryCapabilityCheck, "code.assistance_action_retry"),
  ]
  for item in actions {
    let (action, key) = item
    assert_eq(code_capability_primary_action_i18n_key(action), key)
  }
}

///|
test "Home Code assistance renders every evidence state and action allowlist" {
  let cases : Array[(Model, String, String, String)] = [
    (
      {
        ..init_model(),
        moonclaw_daemon: Some({
          ..capability_test_daemon(true, true, Some(true)),
          model_ready: Some(true),
        }),
      },
      "detected-running",
      "Code assistance is ready",
      "",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(capability_test_daemon(false, true, Some(true))),
      },
      "installed-stopped",
      "Code assistance is stopped",
      "Start Code assistance",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(capability_test_daemon(false, false, Some(false))),
      },
      "not-installed",
      "Code assistance is not installed",
      "Install Code assistance",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(capability_test_daemon(false, false, Some(true))),
      },
      "installed-needs-configuration",
      "Code assistance needs an account or model",
      "Connect Codex",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(
          capability_test_daemon(
            false,
            false,
            Some(true),
            evidence_configured=false,
            evidence_valid=false,
          ),
        ),
      },
      "misconfigured",
      "Code assistance needs configuration",
      "Review configuration",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(
          capability_test_daemon(
            false,
            true,
            Some(true),
            platform_supported=false,
          ),
        ),
      },
      "unsupported-platform",
      "Code assistance is not supported here",
      "",
    ),
    (
      init_model(),
      "temporarily-unavailable",
      "Code assistance status is unavailable",
      "Check again",
    ),
  ]
  for item in cases {
    let (model, state, title, action) = item
    let capability_state = moonclaw_capability_state(model.moonclaw_daemon)
    let primary_action = code_capability_primary_action(capability_state)
    let markup = home_code_capability_markup(model)
    assert_true(markup.contains("data-testid=\"moongate-summary\""))
    assert_true(markup.contains("data-state=\"\{state}\""))
    assert_true(markup.contains("Optional capability"))
    assert_true(markup.contains(">Code assistance<"))
    assert_true(markup.contains(title))
    assert_true(markup.contains(code_capability_detail(capability_state)))
    assert_true(markup.contains("Technical details"))
    assert_code_assistance_i18n_key(markup, "code.assistance_eyebrow")
    assert_code_assistance_i18n_key(markup, "code.assistance_heading")
    assert_code_assistance_i18n_key(
      markup,
      code_capability_status_i18n_key(capability_state),
    )
    assert_code_assistance_i18n_key(
      markup,
      code_capability_title_i18n_key(capability_state),
    )
    assert_code_assistance_i18n_key(
      markup,
      code_capability_detail_i18n_key(capability_state),
    )
    if !(primary_action is NoPrimaryAction) {
      assert_code_assistance_i18n_key(
        markup,
        code_capability_primary_action_i18n_key(primary_action),
      )
    }
    assert_only_home_code_action(markup, action)
  }
}

///|
#warnings("-alert_unstable")
test "ordinary Code assistance markup excludes raw service diagnostics" {
  let daemon = {
    ..capability_test_daemon(false, false, Some(false), platform_supported=true),
    message: "private daemon failure from MoonClaw",
  }
  let model = {
    ..init_model(),
    moonclaw_daemon: Some(daemon),
    moonclaw_installing: true,
    moonclaw_install_feedback: "raw MoonClaw installer path /private/tmp/tool",
  }
  let public_markup = home_code_capability_public_markup(model)
  assert_true(public_markup.contains("Installing Code assistance…"))
  assert_true(
    public_markup.contains("Preparing Code assistance. This can take a moment."),
  )
  assert_code_assistance_i18n_key(public_markup, "code.assistance_installing")
  assert_code_assistance_i18n_key(
    public_markup, "code.assistance_install_progress",
  )
  assert_false(public_markup.contains("MoonClaw"))
  assert_false(public_markup.contains("MoonGate"))
  assert_false(public_markup.contains("daemon"))
  assert_false(public_markup.contains("/private/tmp/tool"))
  let shared_summary = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_code_capability_summary(moonclaw_capability_state(Some(daemon))),
    ),
  )
  assert_false(shared_summary.contains("MoonClaw"))
  assert_false(shared_summary.contains("daemon"))
  let progress = @rabbita.render_to_string(
    @rabbita.static_cell(render_moonclaw_install_progress(model)),
  )
  assert_true(progress.contains("Preparing Code assistance"))
  assert_false(progress.contains("MoonClaw"))
  assert_false(progress.contains("/private/tmp/tool"))
}

///|
#warnings("-alert_unstable")
test "exact Code assistance diagnostics remain in one closed disclosure" {
  let daemon = {
    ..capability_test_daemon(false, false, Some(true), platform_supported=true),
    message: "private daemon failure from MoonClaw",
    installation_evidence: Some({
      installed: true,
      source: "observed-daemon-info",
      reason: "daemon-info-present",
    }),
    configuration_evidence: Some({
      configured: false,
      valid: false,
      reason: "service-configuration-missing",
    }),
  }
  let model = {
    ..init_model(),
    moonclaw_daemon: Some(daemon),
    moonclaw_install_feedback: "raw installer path /private/tmp/tool",
  }
  let technical_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_code_assistance_technical_details(model)),
  )
  assert_true(
    technical_markup.contains(
      "data-testid=\"code-assistance-technical-details\"",
    ),
  )
  assert_true(technical_markup.contains("Technical details"))
  assert_true(technical_markup.contains("MoonClaw"))
  assert_true(technical_markup.contains("private daemon failure"))
  assert_true(technical_markup.contains("/private/tmp/tool"))
  assert_true(technical_markup.contains("Platform: macos"))
  assert_true(technical_markup.contains("architecture: arm64"))
  assert_true(technical_markup.contains("Managed installation"))
  assert_true(technical_markup.contains("Managed process"))
  assert_true(technical_markup.contains("observed-daemon-info"))
  assert_true(technical_markup.contains("daemon-info-present"))
  assert_true(technical_markup.contains("service-configuration-missing"))
  assert_true(technical_markup.contains("Authority: workspace-local"))
  assert_false(technical_markup.contains(" open=\""))
  assert_false(technical_markup.contains("data-i18n=\"code.assistance"))
}

///|
#warnings("-alert_unstable")
test "repair and install failures stay actionable beside the setup action" {
  let daemon = {
    ..capability_test_daemon(false, false, Some(false)),
    ok: Some(false),
    status: Some("unsupported_platform"),
    next_action: Some("install_moonclaw"),
    repair_available: Some(true),
    message: "No MoonClaw artifact supports macos/x86_64",
  }
  let model = {
    ..init_model(),
    moonclaw_daemon: Some(daemon),
    moonclaw_operation_status: "unsupported_platform",
    moonclaw_operation_failed: true,
    moonclaw_install_feedback: "No MoonClaw artifact supports macos/x86_64",
  }
  let markup = home_code_capability_public_markup(model)
  assert_true(markup.contains(">Repair Code assistance<"))
  assert_true(
    markup.contains("data-testid=\"code-assistance-operation-error\""),
  )
  assert_true(markup.contains("role=\"alert\""))
  assert_true(markup.contains("<code>unsupported_platform</code>"))
  assert_true(markup.contains("No MoonClaw artifact supports macos/x86_64"))
  assert_true(markup.contains("<code>install_moonclaw</code>"))
}

///|
#warnings("-alert_unstable")
test "first-run setup renders provider handoffs and an advanced secret input" {
  let daemon = {
    ..capability_test_daemon(true, true, Some(true)),
    model_ready: Some(false),
  }
  let initial_markup = home_code_capability_public_markup({
    ..init_model(),
    moonclaw_daemon: Some(daemon),
  })
  assert_true(
    initial_markup.contains("data-testid=\"code-assistance-first-run\""),
  )
  assert_true(initial_markup.contains(">Connect Codex<"))
  assert_true(initial_markup.contains(">Connect GitHub Copilot<"))
  assert_true(initial_markup.contains(">Use OpenRouter API key<"))
  assert_true(initial_markup.contains("for=\"moonclaw-openrouter-key\""))
  assert_true(initial_markup.contains("type=\"password\""))

  let codex_markup = home_code_capability_public_markup({
    ..init_model(),
    moonclaw_daemon: Some(daemon),
    moonclaw_setup_started: true,
    moonclaw_codex_auth_flow: Some({
      ok: Some(true),
      status: Some("auth_started"),
      message: Some("Codex authorization started"),
      next_action: Some("open_authorization_url"),
      model_ready: Some(false),
      auth_url: Some("https://example.test/codex"),
      state: Some("state-1"),
    }),
  })
  assert_true(codex_markup.contains("data-testid=\"moonclaw-open-codex-auth\""))
  assert_true(codex_markup.contains("href=\"https://example.test/codex\""))
  assert_true(codex_markup.contains(">Open Codex sign-in<"))
  assert_true(codex_markup.contains("secondary-button full"))
  assert_true(codex_markup.contains(">Check setup<"))

  let copilot_markup = home_code_capability_public_markup({
    ..init_model(),
    moonclaw_daemon: Some(daemon),
    moonclaw_setup_started: true,
    moonclaw_copilot_auth_flow: Some({
      ok: Some(true),
      status: Some("auth_started"),
      message: Some("GitHub device authorization started"),
      next_action: Some("complete_device_authorization"),
      model_ready: Some(false),
      user_code: Some("ABCD-EFGH"),
      verification_uri: Some("https://github.com/login/device"),
      expires_in: Some(900),
      interval: Some(5),
    }),
  })
  assert_true(
    copilot_markup.contains("data-testid=\"moonclaw-open-copilot-auth\""),
  )
  assert_true(copilot_markup.contains("ABCD-EFGH"))
  assert_true(copilot_markup.contains("https://github.com/login/device"))
  assert_true(copilot_markup.contains(">Check setup<"))
}

///|
#warnings("-alert_unstable")
test "Code setup renders every non-ready typed state including unavailable" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let cases : Array[(Model, String, String)] = [
    (
      {
        ..init_model(),
        moonclaw_daemon: Some({
          ..capability_test_daemon(true, true, Some(true)),
          model_ready: Some(true),
        }),
      },
      "detected-running",
      "",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(capability_test_daemon(false, true, Some(true))),
      },
      "installed-stopped",
      "Start Code assistance",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(capability_test_daemon(false, false, Some(false))),
      },
      "not-installed",
      "Install Code assistance",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(capability_test_daemon(false, false, Some(true))),
      },
      "installed-needs-configuration",
      "Connect Codex",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(
          capability_test_daemon(
            false,
            false,
            Some(true),
            evidence_configured=false,
            evidence_valid=false,
          ),
        ),
      },
      "misconfigured",
      "Review configuration",
    ),
    (
      {
        ..init_model(),
        moonclaw_daemon: Some(
          capability_test_daemon(
            false,
            true,
            Some(true),
            platform_supported=false,
          ),
        ),
      },
      "unsupported-platform",
      "",
    ),
    (init_model(), "temporarily-unavailable", "Check again"),
  ]
  for item in cases {
    let (model, state, action) = item
    let markup = @rabbita.render_to_string(
      @rabbita.static_cell(render_mooncode_runtime_setup(dispatch, model)),
    )
    if state == "detected-running" {
      assert_eq(markup, "")
      assert_false(
        mooncode_center_class(model).contains("runtime-setup-visible"),
      )
    } else {
      let capability_state = moonclaw_capability_state(model.moonclaw_daemon)
      let primary_action = code_capability_primary_action(capability_state)
      assert_true(markup.contains("data-testid=\"mooncode-runtime-setup\""))
      assert_true(markup.contains("data-state=\"\{state}\""))
      assert_true(
        mooncode_center_class(model).contains("runtime-setup-visible"),
      )
      assert_true(markup.contains(code_capability_title(capability_state)))
      assert_true(markup.contains(code_capability_detail(capability_state)))
      assert_code_assistance_i18n_key(
        markup,
        code_capability_title_i18n_key(capability_state),
      )
      assert_code_assistance_i18n_key(
        markup,
        code_capability_detail_i18n_key(capability_state),
      )
      if !(primary_action is NoPrimaryAction) {
        assert_code_assistance_i18n_key(
          markup,
          code_capability_primary_action_i18n_key(primary_action),
        )
      }
      assert_only_home_code_action(markup, action)
    }
  }
  let unavailable = init_model()
  let unavailable_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_mooncode_runtime_setup(dispatch, unavailable)),
  )
  assert_true(
    unavailable_markup.contains("Code assistance status is unavailable"),
  )
  assert_true(unavailable_markup.contains("Check again"))
  assert_true(unavailable_markup.contains("Technical details"))
  assert_true(
    unavailable_markup.contains("No daemon status response was available."),
  )
  assert_false(unavailable_markup.contains(" open=\""))
  let unavailable_summary = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_code_capability_summary(
        moonclaw_capability_state(unavailable.moonclaw_daemon),
      ),
    ),
  )
  assert_false(unavailable_summary.contains("MoonClaw"))
  assert_false(unavailable_summary.contains("daemon"))
  let installing = {
    ..init_model(),
    moonclaw_daemon: Some(capability_test_daemon(false, false, Some(false))),
    moonclaw_installing: true,
  }
  let installing_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_mooncode_runtime_setup(dispatch, installing)),
  )
  assert_true(installing_markup.contains("Installing Code assistance…"))
  assert_true(
    installing_markup.contains(
      "Preparing Code assistance. This can take a moment.",
    ),
  )
  assert_code_assistance_i18n_key(
    installing_markup, "code.assistance_installing",
  )
  assert_code_assistance_i18n_key(
    installing_markup, "code.assistance_install_progress",
  )
}
