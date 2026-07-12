///|
test "isolated preview headers deny ambient browser capabilities" {
  let headers = isolated_preview_headers("generated/index.html")
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
  assert_true(bridge.contains("unnamed controls"))
  assert_false(bridge.contains("fetch("))
  assert_false(bridge.contains("localStorage"))
  assert_false(bridge.contains("document.cookie"))
}
