///|
fn mooncode_sessions_state_test_session() -> MoonCodeSession {
  code_mode_test_session("session-state", workspace_id="")
}

///|
#warnings("-alert_unstable")
fn mooncode_sessions_state_test_markup(model : Model) -> String {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  @rabbita.render_to_string(
    @rabbita.static_cell(render_mooncode_pane(dispatch, model)),
  )
}

///|
test "MoonCode list selection enters loading only with running evidence" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let first_use = init_model()
  assert_true(first_use.mooncode_sessions_state is Some(FirstUseEmpty))
  assert_eq(first_use.mooncode_sessions_error, "")
  let (_, unavailable) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(MoonCode),
    { ..first_use, mooncode_sessions_error: "earlier failure" },
  )
  assert_true(unavailable.mooncode_sessions_state is Some(FirstUseEmpty))
  assert_eq(unavailable.mooncode_sessions_error, "earlier failure")
  let session = mooncode_sessions_state_test_session()
  let (_, loading) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(MoonCode),
    {
      ..first_use,
      moonclaw_daemon: Some({
        ok: None,
        status: None,
        next_action: None,
        model_ready: None,
        model_readiness: None,
        repair_available: None,
        running: true,
        port: 4545,
        message: "running",
        service_configured: true,
        managed_install: None,
        installation_evidence: None,
        configuration_evidence: None,
        managed_running: Some(true),
        platform_evidence: None,
      }),
      mooncode_sessions: [session],
      mooncode_sessions_state: Some(Stale),
      mooncode_sessions_error: "earlier failure",
    },
  )
  assert_true(loading.mooncode_sessions_state is Some(Loading))
  assert_eq(loading.mooncode_sessions.length(), 1)
  assert_eq(loading.mooncode_sessions_error, "")
}

///|
test "MoonCode list results distinguish zero ready stale and failure" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = init_model()
  let (_, zero) = update_mooncode_session_results(
    dispatch,
    LoadedMoonCodeSessions(Ok([])),
    base,
  )
  assert_true(zero.mooncode_sessions_state is Some(LegitimateZero))
  assert_eq(zero.mooncode_sessions_error, "")
  let session = mooncode_sessions_state_test_session()
  let (_, ready) = update_mooncode_session_results(
    dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    { ..base, mooncode_sessions_error: "earlier failure" },
  )
  assert_true(ready.mooncode_sessions_state is None)
  assert_eq(ready.mooncode_sessions.length(), 1)
  assert_eq(ready.mooncode_sessions_error, "")
  let (_, stale) = update_mooncode_session_results(
    dispatch,
    LoadedMoonCodeSessions(Err("listing refresh failed")),
    { ..ready, mooncode_sessions_state: Some(Loading) },
  )
  assert_true(stale.mooncode_sessions_state is Some(Stale))
  assert_eq(stale.mooncode_sessions.length(), 1)
  assert_eq(stale.mooncode_sessions_error, "listing refresh failed")
  let (_, failed) = update_mooncode_session_results(
    dispatch,
    LoadedMoonCodeSessions(Err("listing unavailable")),
    base,
  )
  assert_true(failed.mooncode_sessions_state is Some(RecoverableError))
  assert_eq(failed.mooncode_sessions.length(), 0)
  assert_eq(failed.mooncode_sessions_error, "listing unavailable")
}

///|
test "MoonCode list owns all eight state mappings and bounded actions" {
  let states = [
    FirstUseEmpty,
    LegitimateZero,
    Loading,
    Stale,
    Disconnected,
    CapabilityLimited,
    RecoverableError,
    TerminalError,
  ]
  for state in states {
    assert_true(mooncode_sessions_state_key(state).length() > 0)
    assert_true(mooncode_sessions_state_title(state).length() > 0)
    assert_true(mooncode_sessions_state_detail(state, false).length() > 0)
  }
  assert_true(mooncode_sessions_state_action(FirstUseEmpty) is None)
  assert_true(mooncode_sessions_state_action(LegitimateZero) is None)
  assert_true(mooncode_sessions_state_action(Loading) is None)
  assert_true(mooncode_sessions_state_action(Stale) is Some("Refresh"))
  assert_true(mooncode_sessions_state_action(Disconnected) is Some("Retry"))
  assert_true(mooncode_sessions_state_action(CapabilityLimited) is None)
  assert_true(mooncode_sessions_state_action(RecoverableError) is Some("Retry"))
  assert_true(mooncode_sessions_state_action(TerminalError) is None)
}

///|
#warnings("-alert_unstable")
test "MoonCode list renders honest transport states and retained rows" {
  let session = mooncode_sessions_state_test_session()
  let first_use = mooncode_sessions_state_test_markup(init_model())
  assert_true(first_use.contains("data-state=\"first-use-empty\""))
  assert_false(first_use.contains("No general chats"))
  let loading = mooncode_sessions_state_test_markup({
    ..init_model(),
    mooncode_sessions: [session],
    mooncode_sessions_state: Some(Loading),
  })
  assert_true(loading.contains("data-state=\"loading\""))
  assert_true(loading.contains("data-session-id=\"session-state\""))
  assert_true(loading.contains("last successful chat list remains visible"))
  assert_false(loading.contains("No general chats"))
  let zero = mooncode_sessions_state_test_markup({
    ..init_model(),
    mooncode_sessions_state: Some(LegitimateZero),
  })
  assert_true(zero.contains("data-state=\"legitimate-zero\""))
  assert_true(zero.contains("No chats yet"))
  assert_true(zero.contains("No general chats"))
  let stale = mooncode_sessions_state_test_markup({
    ..init_model(),
    mooncode_sessions: [session],
    mooncode_sessions_state: Some(Stale),
    mooncode_sessions_error: "private listing failure",
  })
  assert_true(stale.contains("data-state=\"stale\""))
  assert_true(stale.contains("data-session-id=\"session-state\""))
  assert_true(stale.contains("Technical details"))
  assert_true(stale.contains("private listing failure"))
  let failed = mooncode_sessions_state_test_markup({
    ..init_model(),
    mooncode_sessions_state: Some(RecoverableError),
    mooncode_sessions_error: "private listing failure",
  })
  assert_true(failed.contains("data-state=\"recoverable-error\""))
  assert_true(failed.contains("Retry"))
  assert_true(failed.contains("private listing failure"))
  assert_false(failed.contains("No general chats"))
  assert_false(failed.contains("No chats in this MoonBook"))
  let ready = mooncode_sessions_state_test_markup({
    ..init_model(),
    mooncode_sessions: [session],
    mooncode_sessions_state: None,
  })
  assert_false(ready.contains("data-testid=\"mooncode-sessions-state-panel\""))
  assert_true(ready.contains("data-session-id=\"session-state\""))
}

///|
#warnings("-alert_unstable")
test "MoonCode search empty copy requires a successful listing" {
  let failed = mooncode_sessions_state_test_markup({
    ..init_model(),
    mooncode_session_query: "missing",
    mooncode_sessions_state: Some(RecoverableError),
  })
  assert_false(failed.contains("No matching chats"))
  let loaded = mooncode_sessions_state_test_markup({
    ..init_model(),
    mooncode_session_query: "missing",
    mooncode_sessions_state: Some(LegitimateZero),
  })
  assert_true(loaded.contains("No matching chats"))
}
