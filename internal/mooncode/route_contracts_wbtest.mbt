///|
test "desktop projection endpoint contract covers runtime and review controls" {
  let endpoints = desktop_projection_required_endpoints()
  let old_route_namespace = ["/v1/", "mooncode"].join("")
  let old_scheduler = ["serve", "scheduler"].join("-")
  let old_runtime_receipt = ["runtime", "dispatch"].join("-")
  assert_false(endpoints.length() == 0)
  assert_true(endpoints.contains(desktop_status_endpoint()))
  assert_true(endpoints.contains(desktop_capabilities_endpoint()))
  assert_true(endpoints.contains(desktop_sessions_endpoint()))
  assert_true(endpoints.contains(desktop_session_events_endpoint()))
  assert_true(endpoints.contains(desktop_session_change_set_endpoint()))
  assert_true(endpoints.contains(desktop_session_patch_set_endpoint()))
  assert_true(endpoints.contains(desktop_session_commands_endpoint()))
  assert_true(endpoints.contains(desktop_session_runtime_control_endpoint()))
  assert_true(endpoints.contains(desktop_session_runtime_service_endpoint()))
  assert_true(endpoints.contains(desktop_session_runtime_replay_endpoint()))
  assert_true(endpoints.contains(desktop_session_runtime_events_endpoint()))
  assert_true(endpoints.contains(desktop_session_package_result_endpoint()))
  assert_true(endpoints.contains(desktop_session_command_jsonl_endpoint()))
  assert_true(endpoints.contains(desktop_session_readiness_endpoint()))
  assert_true(endpoints.contains(desktop_session_tool_authorization_endpoint()))
  for i, endpoint in endpoints {
    assert_true(endpoint.has_prefix("/api/mooncode/"))
    assert_false(endpoint.contains(old_route_namespace))
    assert_false(endpoint.contains(old_scheduler))
    assert_false(endpoint.contains(old_runtime_receipt))
    for j = i + 1; j < endpoints.length(); j = j + 1 {
      if endpoint == endpoints[j] {
        fail("duplicate desktop endpoint: \{endpoint}")
      }
    }
  }
}

///|
test "native endpoint helpers mirror mooncode core surface" {
  let endpoints = native_projection_required_endpoints()
  assert_eq(endpoints.length(), native_capability_required_endpoints().length())
  for i, endpoint in endpoints {
    assert_true(native_capability_required_endpoints().contains(endpoint))
    assert_true(endpoint.has_prefix("/v1/code/"))
    assert_false(endpoint.contains("<session-id>"))
    for j = i + 1; j < endpoints.length(); j = j + 1 {
      if endpoint == endpoints[j] {
        fail("duplicate native endpoint helper: \{endpoint}")
      }
    }
  }
}

///|
test "engine endpoint contract combines native runtime and desktop projection" {
  let endpoints = engine_supported_endpoints()
  let old_route_namespace = ["/v1/", "mooncode"].join("")
  let old_scheduler = ["serve", "scheduler"].join("-")
  let old_runtime_receipt = ["runtime", "dispatch"].join("-")
  assert_true(endpoints.contains("/v1/models"))
  assert_true(endpoints.contains("/v1/code/capabilities"))
  assert_true(
    endpoints.contains(
      "/v1/code/sessions/<id>/runtime-service?book_root=<path>",
    ),
  )
  assert_true(endpoints.contains(desktop_session_runtime_service_endpoint()))
  assert_true(endpoints.contains(desktop_session_runtime_control_endpoint()))
  assert_true(endpoints.contains(desktop_session_command_jsonl_endpoint()))
  assert_eq(
    endpoints.length(),
    1 +
    native_capability_required_endpoints().length() +
    desktop_projection_required_endpoints().length(),
  )
  for i, endpoint in endpoints {
    assert_true(
      endpoint == "/v1/models" ||
      endpoint.has_prefix("/v1/code/") ||
      endpoint.has_prefix("/api/mooncode/"),
    )
    assert_false(endpoint.contains(old_route_namespace))
    assert_false(endpoint.contains(old_scheduler))
    assert_false(endpoint.contains(old_runtime_receipt))
    for j = i + 1; j < endpoints.length(); j = j + 1 {
      if endpoint == endpoints[j] {
        fail("duplicate engine endpoint: \{endpoint}")
      }
    }
  }
}
