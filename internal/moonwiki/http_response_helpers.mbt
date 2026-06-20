///|
async fn send_file(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  path : String,
  code : Int,
  reason : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": content_type(path),
  })
  if method_ is Head {
    conn.end_response()
    return
  }
  conn.write(@fs.read_file(path).binary())
  conn.end_response()
}

///|
async fn send_status(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  body : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "text/plain; charset=utf-8",
  })
  conn.write(body)
  conn.end_response()
}

///|
async fn send_json(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  body : Json,
) -> Unit {
  send_json_text(conn, method_, body.stringify(indent=2) + "\n")
}

///|
async fn send_json_text(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  body : String,
) -> Unit {
  conn.send_response(200, "OK", extra_headers={
    "content-type": "application/json; charset=utf-8",
  })
  if method_ is Head {
    conn.end_response()
    return
  }
  conn.write(body)
  conn.end_response()
}

///|
async fn send_text(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  content_type : String,
  body : String,
) -> Unit {
  conn.send_response(200, "OK", extra_headers={ "content-type": content_type })
  if method_ is Head {
    conn.end_response()
    return
  }
  conn.write(body)
  conn.end_response()
}

///|
async fn send_api_error(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  code : Int,
  reason : String,
  message : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "application/json; charset=utf-8",
  })
  if method_ is Head {
    conn.end_response()
    return
  }
  let body : Json = { "error": message }
  conn.write(body.stringify(indent=2) + "\n")
  conn.end_response()
}

///|
async fn send_api_json_error(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  code : Int,
  reason : String,
  payload : Json,
) -> Unit {
  conn.send_response(code, reason, extra_headers={
    "content-type": "application/json; charset=utf-8",
  })
  if method_ is Head {
    conn.end_response()
    return
  }
  conn.write(payload.stringify(indent=2) + "\n")
  conn.end_response()
}

///|
fn content_type(path : String) -> String {
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
