///|
test "MoonClaw setup action stays visible as a user operation" {
  let model = { ..init_model(), mooncode_composer_status: "idle" }
  let (_, next) = update_mooncode_actions(
    code_mode_test_dispatch,
    ManageMoonClaw("start"),
    model,
  )
  assert_eq(next.mooncode_composer_status, "Starting MoonClaw…")
}

///|
test "MoonClaw install action exposes progress until lifecycle result" {
  let model = { ..init_model(), mooncode_composer_status: "idle" }
  let (_, installing) = update_mooncode_actions(
    code_mode_test_dispatch,
    ManageMoonClaw("install"),
    model,
  )
  assert_true(installing.moonclaw_installing)
  assert_eq(
    installing.mooncode_composer_status,
    "Downloading, verifying, and installing MoonClaw…",
  )
  assert_eq(
    installing.moonclaw_install_feedback,
    "Downloading, verifying, and installing MoonClaw…",
  )
  let (_, ready) = update_mooncode_session_results(
    code_mode_test_dispatch,
    ManagedMoonClaw(
      Ok({
        ok: None,
        status: None,
        next_action: None,
        model_ready: None,
        model_readiness: None,
        repair_available: None,
        running: true,
        port: 1515,
        message: "MoonClaw 0.1.2 is installed and running",
        service_configured: true,
        managed_install: Some(true),
        managed_running: Some(true),
        installation_evidence: None,
        configuration_evidence: None,
        platform_evidence: None,
      }),
    ),
    installing,
  )
  assert_false(ready.moonclaw_installing)
  assert_true(ready.moonclaw_daemon.unwrap().running)
  assert_eq(
    ready.moonclaw_install_feedback,
    "MoonClaw 0.1.2 is installed and running",
  )
}

///|
test "MoonClaw failed start keeps the installed state and exact failure" {
  let model = {
    ..init_model(),
    moonclaw_installing: true,
    moonclaw_operation: "install",
    moonclaw_install_feedback: "Downloading, verifying, and installing MoonClaw…",
  }
  let (_, stopped) = update_mooncode_session_results(
    code_mode_test_dispatch,
    ManagedMoonClaw(
      Ok({
        ok: None,
        status: None,
        next_action: None,
        model_ready: None,
        model_readiness: None,
        repair_available: None,
        running: false,
        port: 0,
        message: "MoonClaw 0.1.3 was installed, but could not be started: daemon exited",
        service_configured: true,
        managed_install: Some(true),
        managed_running: Some(false),
        installation_evidence: None,
        configuration_evidence: None,
        platform_evidence: None,
      }),
    ),
    model,
  )
  assert_false(stopped.moonclaw_installing)
  assert_true(stopped.moonclaw_daemon.unwrap().managed_install.unwrap())
  assert_true(stopped.moonclaw_operation_failed)
  assert_eq(stopped.moonclaw_operation_status, "operation_failed")
  assert_eq(
    stopped.moonclaw_install_feedback,
    "MoonClaw 0.1.3 was installed, but could not be started: daemon exited",
  )
}

///|
test "MoonClaw auth status treats fresh setup as guidance, not failure" {
  let model = { ..init_model(), moonclaw_auth_pending: "check" }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonClawAuth(
      Ok({
        ok: Some(false),
        status: Some("authentication_required"),
        message: Some("Connect a model provider"),
        next_action: Some("configure_model"),
        model_ready: Some(false),
        codex: Some({ authenticated: Some(false), email: None, plan: None }),
        copilot: Some({ authenticated: Some(false), email: None, plan: None }),
      }),
    ),
    model,
  )
  assert_false(next.moonclaw_auth_failed)
  assert_eq(
    next.moonclaw_auth_feedback,
    "Sign-in is not complete yet. Finish setup, then check again.",
  )
  assert_eq(next.moonclaw_auth_status, "authentication_required")
}

///|
test "MoonClaw auth actions retain returned handoff state through failure" {
  let (_, starting) = update_mooncode_actions(
    code_mode_test_dispatch,
    StartMoonClawAuth("codex"),
    init_model(),
  )
  assert_eq(starting.moonclaw_auth_pending, "codex")
  assert_true(starting.moonclaw_setup_started)
  let flow : MoonClawCodexAuthFlow = {
    ok: Some(true),
    status: Some("auth_started"),
    message: Some("Codex authorization started"),
    next_action: Some("open_authorization_url"),
    model_ready: Some(false),
    auth_url: Some("https://example.test/codex"),
    state: Some("state-1"),
  }
  let (_, handed_off) = update_mooncode_session_results(
    code_mode_test_dispatch,
    StartedMoonClawCodexAuth(Ok(flow)),
    starting,
  )
  assert_true(handed_off.moonclaw_codex_auth_flow is Some(_))
  let (_, failed) = update_mooncode_session_results(
    code_mode_test_dispatch,
    StartedMoonClawCodexAuth(Err("callback port unavailable")),
    handed_off,
  )
  assert_true(failed.moonclaw_codex_auth_flow is Some(_))
  assert_true(failed.moonclaw_auth_failed)
  assert_eq(failed.moonclaw_auth_feedback, "callback port unavailable")
}

///|
test "OpenRouter key clears only after a successful save" {
  let model = {
    ..init_model(),
    moonclaw_openrouter_key: "sk-or-test",
    moonclaw_setup_started: true,
  }
  let (_, failed) = update_mooncode_session_results(
    code_mode_test_dispatch,
    SavedMoonClawOpenRouterKey(
      Ok({
        ok: false,
        status: "openrouter_key_invalid",
        message: "OpenRouter rejected this API key",
        next_action: "review_api_key",
        model_ready: false,
      }),
    ),
    model,
  )
  assert_eq(failed.moonclaw_openrouter_key, "sk-or-test")
  assert_true(failed.moonclaw_auth_failed)
  assert_eq(failed.moonclaw_auth_status, "openrouter_key_invalid")
  let (_, saved) = update_mooncode_session_results(
    code_mode_test_dispatch,
    SavedMoonClawOpenRouterKey(
      Ok({
        ok: true,
        status: "openrouter_key_configured",
        message: "OpenRouter API key saved",
        next_action: "check_model",
        model_ready: false,
      }),
    ),
    model,
  )
  assert_eq(saved.moonclaw_openrouter_key, "")
  assert_false(saved.moonclaw_auth_failed)
  assert_eq(saved.moonclaw_auth_feedback, "OpenRouter API key saved")
}
