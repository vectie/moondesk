///|
test "isolated preview headers deny ambient browser capabilities" {
  let headers = @preview.isolated_preview_headers("generated/index.html")
  let csp = headers["content-security-policy"]
  assert_true(csp.contains("default-src 'none'"))
  assert_true(csp.contains("connect-src 'none'"))
  assert_true(csp.contains("form-action 'none'"))
  assert_true(csp.contains("navigate-to 'self'"))
  assert_true(csp.contains("sandbox allow-scripts"))
  assert_false(csp.contains("allow-same-origin"))
  assert_eq(headers["cache-control"], "no-store")
  assert_eq(headers["referrer-policy"], "no-referrer")
  assert_eq(headers["x-moondesktop-preview-origin"], "opaque-sandbox")
  assert_true(headers["permissions-policy"].contains("clipboard-write=()"))
}

///|
test "preview observer is observation-only and parent-scoped" {
  let bridge = isolated_preview_observer_bridge()
  assert_true(bridge.contains("event.source !== parent"))
  assert_true(bridge.contains("moondesk-preview-v1"))
  assert_true(bridge.contains("snapshot-request"))
  assert_true(bridge.contains("ready-request"))
  assert_true(bridge.contains("unnamed controls"))
  assert_false(bridge.contains("fetch("))
  assert_false(bridge.contains("localStorage"))
  assert_false(bridge.contains("document.cookie"))
}

///|
test "browser host and origin validation reject rebinding and opaque API calls" {
  for host in ["localhost", "localhost:4199", "127.0.0.1:4199", "[::1]:4199"] {
    assert_true(moondesk_browser_host_allowed(host))
  }
  for host in ["", "0.0.0.0:4199", "evil.test", "127.0.0.1.evil.test"] {
    assert_false(moondesk_browser_host_allowed(host))
  }
  assert_true(
    moondesk_browser_origin_allowed("http://127.0.0.1:4199", "127.0.0.1:4199"),
  )
  assert_true(moondesk_browser_origin_allowed("", "127.0.0.1:4199"))
  assert_false(
    moondesk_browser_origin_allowed("", "127.0.0.1:4199", method_=Post),
  )
  assert_false(moondesk_browser_origin_allowed("null", "127.0.0.1:4199"))
  assert_false(
    moondesk_browser_origin_allowed("http://evil.test", "127.0.0.1:4199"),
  )
}

///|
test "remote hosts are exact authorities without wildcards or suffix matches" {
  let allowed = "198.51.100.10:5001,192.0.2.10:5001"
  assert_true(moondesk_host_matches("198.51.100.10:5001", allowed))
  for
    host in [
      "198.51.100.10", "198.51.100.10:5002", "198.51.100.10.evil:5001", "x.test",
      "localhost:abc", "localhost:0", "localhost:65536", "localhost:5001@evil",
    ] {
    assert_false(moondesk_host_matches(host, allowed))
  }
  assert_false(moondesk_host_matches("x.test", "*"))
  assert_false(moondesk_host_matches("x.test", "*.test"))
}

///|
test "hosted gateway mode only accepts an exact personal Kubernetes service" {
  let service = "webide-0123456789abcdef.ns.svc.cluster.local:8188"
  assert_true(moondesk_trusted_workspace_gateway(service, "true"))
  assert_false(moondesk_trusted_workspace_gateway(service, "false"))
  assert_false(moondesk_trusted_workspace_gateway("example.com:8188", "true"))
  assert_false(
    moondesk_trusted_workspace_gateway(service + ",evil.test", "true"),
  )
  assert_false(
    moondesk_trusted_workspace_gateway("*.svc.cluster.local:8188", "true"),
  )
}

///|
test "remote desktop authority requires active PlatformOperator" {
  assert_true(
    moondesk_active_operator({
      "state": "Active",
      "roles": ["PlatformOperator"],
    }),
  )
  assert_false(
    moondesk_active_operator({
      "state": "Disabled",
      "roles": ["PlatformOperator"],
    }),
  )
  assert_false(
    moondesk_active_operator({ "state": "Active", "roles": ["Developer"] }),
  )
  assert_false(
    moondesk_active_operator({ "state": "Active", "roles": "PlatformOperator" }),
  )
  assert_false(moondesk_active_operator({ "roles": ["PlatformOperator"] }))
}

///|
test "identity authority cannot rely on duplicated Host headers" {
  assert_true(
    moondesk_identity_authority_matches(
      "http://198.51.100.10:5003", "198.51.100.10:5003",
    ),
  )
  assert_false(
    moondesk_identity_authority_matches(
      "http://127.0.0.1:5003", "198.51.100.10:5003",
    ),
  )
  assert_false(
    moondesk_identity_authority_matches(
      "http://198.51.100.10:5003/other", "198.51.100.10:5003",
    ),
  )
  assert_false(moondesk_identity_authority_matches("http://*", "*"))
}
