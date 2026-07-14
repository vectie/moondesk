///|
fn route_contract_methods(contract : Json) -> Array[String] {
  let methods : Array[String] = []
  for item in json_array_items(contract, "methods") {
    match item {
      String(raw_method) => {
        let method_name = raw_method.trim().to_owned()
        if method_name != "" {
          methods.push(method_name)
        }
      }
      _ => ()
    }
  }
  methods
}

///|
fn assert_route_methods(
  methods : Array[String],
  expected : Array[String],
) -> Unit raise {
  assert_eq(methods.length(), expected.length())
  for i, expected_method in expected {
    assert_true(methods[i] == expected_method)
  }
}

///|
test "desktop projection endpoint contract covers runtime and review controls" {
  let endpoints = desktop_projection_required_endpoints()
  let route_contracts = desktop_projection_route_contracts()
  let old_route_namespace = ["/v1/", "mooncode"].join("")
  let old_scheduler = ["serve", "scheduler"].join("-")
  let old_runtime_receipt = ["runtime", "dispatch"].join("-")
  assert_false(endpoints.length() == 0)
  assert_eq(endpoints.length(), route_contracts.length())
  assert_true(endpoints.contains(desktop_status_endpoint()))
  assert_true(endpoints.contains(desktop_capabilities_endpoint()))
  assert_true(endpoints.contains(desktop_sessions_endpoint()))
  assert_true(endpoints.contains(desktop_session_endpoint()))
  assert_true(endpoints.contains(desktop_session_watch_endpoint()))
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
  for contract in route_contracts {
    let path = json_string(contract, "path", default="")
    let methods = route_contract_methods(contract)
    assert_true(endpoints.contains(path))
    assert_false(methods.length() == 0)
    for method_name in methods {
      assert_true(
        method_name == "GET" || method_name == "HEAD" || method_name == "POST",
      )
      if method_name == "HEAD" {
        assert_true(methods.contains("GET"))
      }
    }
  }
  for endpoint in endpoints {
    let matches : Array[String] = []
    for contract in route_contracts {
      let path = json_string(contract, "path", default="")
      if path == endpoint {
        matches.push(path)
      }
    }
    assert_eq(matches.length(), 1)
  }
  for contract in route_contracts {
    let path = json_string(contract, "path", default="")
    let methods = route_contract_methods(contract)
    if path == desktop_session_runtime_service_endpoint() ||
      path == desktop_session_package_result_endpoint() {
      assert_route_methods(methods, ["POST"])
    } else if path == desktop_sessions_endpoint() ||
      path == desktop_session_stream_state_endpoint() ||
      path == desktop_session_commands_endpoint() ||
      path == desktop_session_tool_authorization_endpoint() ||
      path == desktop_session_eval_report_endpoint() ||
      path == desktop_session_runtime_events_endpoint() ||
      path == desktop_session_runtime_claim_endpoint() ||
      path == desktop_session_runtime_supervisor_endpoint() ||
      path == desktop_session_runtime_replay_endpoint() {
      assert_route_methods(methods, ["GET", "HEAD", "POST"])
    } else {
      assert_route_methods(methods, ["GET", "HEAD"])
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
