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
async test "capability host response does not fabricate runtime support" {
  let response = mooncode_capabilities_response_json(
    "/tmp/moondesk-capability-route-test",
  )
  assert_false(json_bool(response, "ok", default=true))
  assert_eq(
    json_string(response, "capability_status", default=""),
    "unavailable",
  )
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
test "capability and engine status agree for supported v2 subset probe" {
  let probe : Json = {
    "component": "mooncode",
    "provider": "moonclaw",
    "protocol": "mooncode.v2",
    "capability_contract_id": "mooncode-native-capability-surface.v2",
    "capability_surface_fingerprint": "subset-fingerprint",
    "native_runtime_ready": true,
    "runtime_owner": "moonclaw",
    "session_owner": "moonclaw",
    "endpoints": [
      "/v1/code/capabilities", "/v1/code/sessions?book_root=<path>", "/v1/code/sessions/<id>/turns",
      "/v1/code/sessions/<id>/stream?book_root=<path>&format=jsonl|sse&since=<canonical-decimal>&wait_ms=<ms>&poll_ms=<ms>",
    ],
    "tools": ["read", "edit", "write", "shell"],
    "capability_surface": {
      "component": "mooncode",
      "capability_contract_id": "mooncode-native-capability-surface.v2",
      "capability_surface_fingerprint": "subset-fingerprint",
    },
  }
  let negotiated = @mooncode.negotiate_capabilities_json(probe)
  let engine = mooncode_engine_status_projection_json(
    {
      "running": true,
      "moonclaw_root": "/tmp/moonclaw",
      "service_configured": true,
    },
    Ok({ "ready": false, "default_model": "", "models": [] }),
    Ok(probe),
  )
  let native = json_object_field_or_empty(
    engine, "native_capabilities_readiness",
  )
  assert_true(json_bool(negotiated, "ok", default=false))
  assert_true(json_bool(native, "ok", default=false))
  assert_true(json_bool(engine, "native_runtime_ready", default=false))
  assert_eq(json_string(native, "status", default=""), "native-runtime-ready")
}

///|
test "capability and engine status agree for incompatible probe" {
  let probe : Json = {
    "component": "mooncode",
    "provider": "moonclaw",
    "protocol": "mooncode.v2",
    "capability_contract_id": "mooncode-native-capability-surface.v7",
    "capability_surface_fingerprint": "subset-fingerprint",
    "native_runtime_ready": true,
    "runtime_owner": "moonclaw",
    "session_owner": "moonclaw",
    "endpoints": [
      "/v1/code/capabilities", "/v1/code/sessions?book_root=<path>", "/v1/code/sessions/<id>/turns",
      "/v1/code/sessions/<id>/stream?book_root=<path>&format=jsonl|sse&since=<canonical-decimal>&wait_ms=<ms>&poll_ms=<ms>",
    ],
    "tools": ["read", "edit", "write", "shell"],
    "capability_surface": {
      "component": "mooncode",
      "capability_contract_id": "mooncode-native-capability-surface.v7",
      "capability_surface_fingerprint": "subset-fingerprint",
    },
  }
  let negotiated = @mooncode.negotiate_capabilities_json(probe)
  let engine = mooncode_engine_status_projection_json(
    {
      "running": true,
      "moonclaw_root": "/tmp/moonclaw",
      "service_configured": true,
    },
    Ok({ "ready": false, "default_model": "", "models": [] }),
    Ok(probe),
  )
  let native = json_object_field_or_empty(
    engine, "native_capabilities_readiness",
  )
  assert_eq(
    json_string(negotiated, "capability_status", default=""),
    json_string(native, "status", default=""),
  )
  assert_eq(
    json_bool(negotiated, "ok", default=true),
    json_bool(native, "ok", default=true),
  )
  assert_false(json_bool(engine, "native_runtime_ready", default=true))
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
