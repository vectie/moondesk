///|
test "classifies every supported MIME type and fallback exactly" {
  let cases = [
    ("index.html", "text/html; charset=utf-8"),
    ("styles.css", "text/css; charset=utf-8"),
    ("app.js", "application/javascript"),
    ("data.json", "application/json"),
    ("icon.svg", "image/svg+xml"),
    ("image.png", "image/png"),
    ("photo.jpg", "image/jpeg"),
    ("photo.jpeg", "image/jpeg"),
    ("animation.gif", "image/gif"),
    ("image.webp", "image/webp"),
    ("favicon.ico", "image/x-icon"),
    ("notes.txt", "text/plain; charset=utf-8"),
    ("README.md", "text/plain; charset=utf-8"),
    ("archive.bin", "application/octet-stream"),
    ("no-extension", "application/octet-stream"),
  ]
  for case in cases {
    let (path, expected) = case
    assert_eq(@preview.content_type(path), expected)
  }
}

///|
test "isolated preview headers preserve the exact policy" {
  let headers = @preview.isolated_preview_headers("generated/index.html")
  assert_eq(headers.length(), 7)
  assert_eq(headers["content-type"], "text/html; charset=utf-8")
  assert_eq(headers["cache-control"], "no-store")
  assert_eq(
    headers["content-security-policy"],
    "default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; media-src 'self'; connect-src 'none'; child-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; navigate-to 'self'; frame-ancestors 'self'; sandbox allow-scripts",
  )
  assert_eq(
    headers["permissions-policy"],
    "accelerometer=(), camera=(), clipboard-read=(), clipboard-write=(), geolocation=(), gyroscope=(), microphone=(), payment=(), serial=(), usb=()",
  )
  assert_eq(headers["referrer-policy"], "no-referrer")
  assert_eq(headers["x-content-type-options"], "nosniff")
  assert_eq(headers["x-moondesktop-preview-origin"], "opaque-sandbox")
}
