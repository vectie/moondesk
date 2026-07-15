///|
test "mooncode HTTP capability reports MoonClaw ownership" {
  let capability = @mooncode.capabilities_json()
  let ownership = json_object_field_or_empty(capability, "ownership")
  assert_eq(json_string(ownership, "sessions", default=""), "moonclaw")
  assert_eq(
    json_string(ownership, "canonical_conversation", default=""),
    "moonclaw",
  )
  let routes = json_array_items(capability, "desktop_route_contracts")
  assert_eq(routes.length(), 7)
  let payload = Json::array(routes).stringify()
  assert_true(payload.contains("/lifecycle"))
  assert_false(payload.contains("runtime-service"))
  assert_false(payload.contains("runtime-replay"))
  assert_false(payload.contains("session-store"))
}

///|
test "mooncode model readiness requires a listed executable default" {
  assert_true(
    moonclaw_models_response_ready({
      "ready": true,
      "default_model": "codex/gpt-5.4",
      "models": [{ "name": "codex/gpt-5.4", "default": true }],
    }),
  )
  assert_false(
    moonclaw_models_response_ready({
      "ready": true,
      "default_model": "phantom",
      "models": [{ "name": "codex/gpt-5.4" }],
    }),
  )
  assert_false(
    moonclaw_models_response_ready({
      "ready": false,
      "default_model": "",
      "models": [],
    }),
  )
}

///|
async test "mooncode engine status fails closed without MoonClaw" {
  let status = mooncode_engine_status_json(
    "/tmp/moondesk-mooncode-engine-status-canonical-test",
  )
  assert_false(json_bool(status, "ready", default=true))
  assert_false(json_bool(status, "native_runtime_ready", default=true))
  let endpoints = json_string_array_items(status, "supported_endpoints")
  assert_true(endpoints.contains("/v1/code/sessions/<id>/turns"))
  assert_true(endpoints.contains(@mooncode.desktop_session_watch_endpoint()))
  assert_false(
    endpoints.contains("/api/mooncode/sessions/<session-id>/runtime-service"),
  )
}
