///|
fn ui_capability_payload(protocol : String) -> Json {
  @mooncode_core.encode_mooncode_capability({
    ..@mooncode_core.mooncode_capability(),
    protocol,
  })
}

///|
test "UI consumes negotiated supported capability as typed value" {
  let state = mooncode_capability_state(ui_capability_payload("mooncode.v1"))
  assert_true(
    state is CapabilitySupported(value) && value.session_owner == "moonclaw",
  )
  assert_true(mooncode_capability_available(state))
}

///|
test "UI maps negotiated unsupported malformed and unavailable states" {
  assert_true(
    mooncode_capability_state({
      "capability_status": "unsupported-version",
      "capability_version": 7,
    })
    is CapabilityUnsupportedVersion(7),
  )
  assert_true(
    mooncode_capability_state({
      "capability_status": "malformed",
      "capability_error": "bad payload",
    })
    is CapabilityMalformed("bad payload"),
  )
  assert_true(
    mooncode_capability_state({
      "capability_status": "unavailable",
      "capability_error": "offline",
    })
    is CapabilityUnavailable("offline"),
  )
}

///|
#warnings("-alert_unstable")
fn capability_setup_markup(
  state : MoonCodeCapabilityState,
  running? : Bool = false,
) -> String {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let daemon = if running {
    Some({
      ok: Some(true),
      status: Some("running"),
      next_action: None,
      model_ready: Some(true),
      model_readiness: None,
      repair_available: Some(false),
      running: true,
      port: 4545,
      message: "running",
      service_configured: true,
      managed_install: None,
      installation_evidence: None,
      configuration_evidence: None,
      managed_running: Some(true),
      platform_evidence: None,
    })
  } else {
    None
  }
  @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_runtime_setup(dispatch, {
        ..init_model(),
        mooncode_capability: state,
        moonclaw_daemon: daemon,
      }),
    ),
  )
}

///|
test "pending preserves pre-negotiation UI with no capability action" {
  let markup = capability_setup_markup(CapabilityPending, running=true)
  assert_false(markup.contains("mooncode-runtime-setup"))
}

///|
test "unsupported malformed and unavailable render distinct truthful actions" {
  let unsupported = capability_setup_markup(CapabilityUnsupportedVersion(7))
  assert_true(unsupported.contains("state=\"unsupported-version\""))
  assert_true(unsupported.contains("Update MoonDesk or MoonClaw"))
  assert_false(unsupported.contains("capability-refetch"))
  assert_false(unsupported.contains("capability-retry-daemon"))
  let malformed = capability_setup_markup(CapabilityMalformed("bad payload"))
  assert_true(malformed.contains("state=\"malformed\""))
  assert_true(malformed.contains("mooncode-capability-refetch"))
  assert_false(malformed.contains("mooncode-capability-retry-daemon"))
  let unavailable = capability_setup_markup(CapabilityUnavailable("offline"))
  assert_true(unavailable.contains("state=\"unavailable\""))
  assert_true(unavailable.contains("mooncode-capability-retry-daemon"))
  assert_false(unavailable.contains("mooncode-capability-refetch"))
}
