///|
test "provider handoff accepts only bounded one-time code syntax" {
  let valid = DesktopProviderHandoffRequest::{
    client_id: "desktop:customer_01",
    handoff_code: "lnxc_" + "a".repeat(64),
  }
  assert_true(valid_handoff_shape(valid))
  assert_false(valid_handoff_shape({ ..valid, client_id: "bad/client" }))
  assert_false(valid_handoff_shape({ ..valid, handoff_code: "lnxc_short" }))
}

///|
test "provider handoff payload names the MoonClaw contract without provider secrets" {
  let payload = desktop_provider_handoff_request_json({
    client_id: "desktop-01",
    handoff_code: "lnxc_" + "b".repeat(64),
  })
  guard payload is Object(fields) else { fail("expected object") }
  assert_eq(fields["contract"], Json::string("moonclaw.provider-handoff.v1"))
  assert_eq(fields["client_id"], Json::string("desktop-01"))
  assert_true(fields.get("api_secret") is None)
  assert_true(fields.get("api_base_url") is None)
}
