///|
test "generated HTML SVG and JavaScript remain opaque and disconnected from app state" {
  for path in ["generated/index.html", "generated/icon.svg", "generated/app.js"] {
    let headers = @preview.isolated_preview_headers(path)
    let csp = headers["content-security-policy"]
    assert_eq(headers["x-moondesktop-preview-origin"], "opaque-sandbox")
    assert_eq(headers["cache-control"], "no-store")
    assert_eq(headers["referrer-policy"], "no-referrer")
    assert_true(csp.contains("default-src 'none'"))
    assert_true(csp.contains("connect-src 'none'"))
    assert_true(csp.contains("form-action 'none'"))
    assert_true(csp.contains("sandbox allow-scripts"))
    assert_false(csp.contains("allow-same-origin"))
  }
}
