///|
pub fn content_type(path : String) -> String {
  match @pathx.ext(path) {
    ".html" => "text/html; charset=utf-8"
    ".css" => "text/css; charset=utf-8"
    ".js" => "application/javascript"
    ".json" => "application/json"
    ".svg" => "image/svg+xml"
    ".png" => "image/png"
    ".jpg" | ".jpeg" => "image/jpeg"
    ".gif" => "image/gif"
    ".webp" => "image/webp"
    ".ico" => "image/x-icon"
    ".txt" | ".md" => "text/plain; charset=utf-8"
    _ => "application/octet-stream"
  }
}

///|
pub fn isolated_preview_headers(path : String) -> Map[String, String] {
  {
    "content-type": content_type(path),
    "cache-control": "no-store",
    "content-security-policy": "default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; media-src 'self'; connect-src 'none'; child-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; navigate-to 'self'; frame-ancestors 'self'; sandbox allow-scripts",
    "permissions-policy": "accelerometer=(), camera=(), clipboard-read=(), clipboard-write=(), geolocation=(), gyroscope=(), microphone=(), payment=(), serial=(), usb=()",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
    "x-moondesktop-preview-origin": "opaque-sandbox",
  }
}
