///|
fn mooncode_backend_route_contract(
  path : String,
  methods : Array[String],
) -> Json {
  { "path": path, "methods": json_from_string_array(methods) }
}

///|
fn mooncode_backend_router_route_contracts() -> Array[Json] {
  [
    mooncode_backend_route_contract("/api/mooncode/status", ["GET", "HEAD"]),
    mooncode_backend_route_contract("/api/mooncode/capabilities", [
      "GET", "HEAD",
    ]),
    mooncode_backend_route_contract("/api/mooncode/eval-harness", [
      "GET", "HEAD",
    ]),
    mooncode_backend_route_contract("/api/mooncode/standalone-boundary", [
      "GET", "HEAD",
    ]),
    mooncode_backend_route_contract("/api/mooncode/readiness-contract", [
      "GET", "HEAD",
    ]),
    mooncode_backend_route_contract("/api/mooncode/sessions", [
      "GET", "HEAD", "POST",
    ]),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/events",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/change-set",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/patch-set",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/tool-approvals",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/tool-authorization",
      ["GET", "HEAD", "POST"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/test-runs",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/package-candidates",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/action-plan",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/readiness",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-evidence",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/eval-report",
      ["GET", "HEAD", "POST"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/package-result",
      ["POST"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-handoff",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-execution-plan",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/session-store",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-commands",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-control",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-supervisor",
      ["GET", "HEAD", "POST"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-service",
      ["POST"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-events",
      ["GET", "HEAD", "POST"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-replay",
      ["GET", "HEAD", "POST"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/command-jsonl",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/runtime-claim",
      ["GET", "HEAD", "POST"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/stream-state",
      ["GET", "HEAD", "POST"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/preflight",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/stream",
      ["GET", "HEAD"],
    ),
    mooncode_backend_route_contract(
      "/api/mooncode/sessions/<session-id>/commands",
      ["GET", "HEAD", "POST"],
    ),
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
fn mooncode_route_contract_fingerprint(contract : Json) -> String {
  let path = mooncode_endpoint_path_without_query(
    json_string(contract, "path", default=""),
  )
  let methods = json_string_array_items(contract, "methods").join(",")
  [path, methods].join(" ")
}

///|
fn mooncode_backend_router_endpoint_paths() -> Array[String] {
  let paths : Array[String] = []
  for contract in mooncode_backend_router_route_contracts() {
    paths.push(json_string(contract, "path", default=""))
  }
  paths
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
fn mooncode_desktop_contract_fingerprints() -> Array[String] {
  let fingerprints : Array[String] = []
  for contract in @mooncode.desktop_projection_route_contracts() {
    fingerprints.push(mooncode_route_contract_fingerprint(contract))
  }
  fingerprints
}

///|
fn mooncode_backend_router_fingerprints() -> Array[String] {
  let fingerprints : Array[String] = []
  for contract in mooncode_backend_router_route_contracts() {
    fingerprints.push(mooncode_route_contract_fingerprint(contract))
  }
  fingerprints
}

///|
test "mooncode backend route contract matches router path surface" {
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

///|
test "mooncode backend route contract matches router method surface" {
  let router_fingerprints = mooncode_backend_router_fingerprints()
  let contract_fingerprints = mooncode_desktop_contract_fingerprints()
  assert_eq(router_fingerprints.length(), contract_fingerprints.length())
  for fingerprint in router_fingerprints {
    assert_true(contract_fingerprints.contains(fingerprint))
  }
  for fingerprint in contract_fingerprints {
    assert_true(router_fingerprints.contains(fingerprint))
  }
}
