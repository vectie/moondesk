///|
fn mooncode_backend_router_endpoint_paths() -> Array[String] {
  [
    "/api/mooncode/status", "/api/mooncode/capabilities", "/api/mooncode/eval-harness",
    "/api/mooncode/standalone-boundary", "/api/mooncode/readiness-contract", "/api/mooncode/sessions",
    "/api/mooncode/sessions/<session-id>/events", "/api/mooncode/sessions/<session-id>/change-set",
    "/api/mooncode/sessions/<session-id>/patch-set", "/api/mooncode/sessions/<session-id>/tool-approvals",
    "/api/mooncode/sessions/<session-id>/tool-authorization", "/api/mooncode/sessions/<session-id>/test-runs",
    "/api/mooncode/sessions/<session-id>/package-candidates", "/api/mooncode/sessions/<session-id>/action-plan",
    "/api/mooncode/sessions/<session-id>/readiness", "/api/mooncode/sessions/<session-id>/runtime-evidence",
    "/api/mooncode/sessions/<session-id>/eval-report", "/api/mooncode/sessions/<session-id>/package-result",
    "/api/mooncode/sessions/<session-id>/runtime-handoff", "/api/mooncode/sessions/<session-id>/runtime-execution-plan",
    "/api/mooncode/sessions/<session-id>/session-store", "/api/mooncode/sessions/<session-id>/runtime-commands",
    "/api/mooncode/sessions/<session-id>/runtime-control", "/api/mooncode/sessions/<session-id>/runtime-supervisor",
    "/api/mooncode/sessions/<session-id>/runtime-service", "/api/mooncode/sessions/<session-id>/runtime-events",
    "/api/mooncode/sessions/<session-id>/runtime-replay", "/api/mooncode/sessions/<session-id>/command-jsonl",
    "/api/mooncode/sessions/<session-id>/runtime-claim", "/api/mooncode/sessions/<session-id>/stream-state",
    "/api/mooncode/sessions/<session-id>/preflight", "/api/mooncode/sessions/<session-id>/stream",
    "/api/mooncode/sessions/<session-id>/commands",
  ]
}

///|
fn mooncode_endpoint_path_without_query(endpoint : String) -> String {
  let parts = endpoint.split("?").to_array()
  if parts.length() > 0 {
    parts[0].to_owned()
  } else {
    endpoint
  }
}

///|
fn mooncode_desktop_contract_paths() -> Array[String] {
  let paths : Array[String] = []
  for endpoint in @mooncode.desktop_projection_required_endpoints() {
    let path = mooncode_endpoint_path_without_query(endpoint)
    if !paths.contains(path) {
      paths.push(path)
    }
  }
  paths
}

///|
test "mooncode backend route contract matches router surface" {
  let router_paths = mooncode_backend_router_endpoint_paths()
  let contract_paths = mooncode_desktop_contract_paths()
  assert_eq(router_paths.length(), contract_paths.length())
  for path in router_paths {
    assert_true(contract_paths.contains(path))
  }
  for path in contract_paths {
    assert_true(router_paths.contains(path))
  }
}
