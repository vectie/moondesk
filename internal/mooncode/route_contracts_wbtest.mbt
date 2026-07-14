///|
fn route_contract_methods(contract : Json) -> Array[String] {
  let methods : Array[String] = []
  for item in json_array_items(contract, "methods") {
    if item is String(raw) {
      methods.push(raw)
    }
  }
  methods
}

///|
test "desktop projection exposes only the canonical interaction surface" {
  let contracts = desktop_projection_route_contracts()
  let endpoints = desktop_projection_required_endpoints()
  assert_eq(contracts.length(), 6)
  assert_eq(endpoints.length(), 6)
  assert_true(endpoints.contains(desktop_status_endpoint()))
  assert_true(endpoints.contains(desktop_capabilities_endpoint()))
  assert_true(endpoints.contains(desktop_sessions_endpoint()))
  assert_true(endpoints.contains(desktop_session_endpoint()))
  assert_true(endpoints.contains(desktop_session_watch_endpoint()))
  assert_true(endpoints.contains(desktop_session_commands_endpoint()))
  for endpoint in endpoints {
    assert_true(endpoint.has_prefix("/api/mooncode/"))
    assert_false(endpoint.contains("runtime-service"))
    assert_false(endpoint.contains("runtime-replay"))
    assert_false(endpoint.contains("session-store"))
    assert_false(endpoint.contains("runtime-events"))
  }
}

///|
test "desktop canonical routes publish exact methods" {
  for contract in desktop_projection_route_contracts() {
    let path = json_string(contract, "path", default="")
    let methods = route_contract_methods(contract)
    if path == desktop_sessions_endpoint() {
      assert_true(methods == ["GET", "HEAD", "POST"])
    } else if path == desktop_session_commands_endpoint() {
      assert_true(methods == ["POST"])
    } else {
      assert_true(methods == ["GET", "HEAD"])
    }
  }
}

///|
test "engine endpoint contract includes native submit turn" {
  let endpoints = engine_supported_endpoints()
  assert_true(endpoints.contains("/v1/models"))
  assert_true(endpoints.contains("/v1/code/sessions/<id>/turns"))
  assert_true(endpoints.contains(desktop_session_commands_endpoint()))
  assert_eq(
    endpoints.length(),
    1 +
    native_capability_required_endpoints().length() +
    desktop_projection_required_endpoints().length(),
  )
}
