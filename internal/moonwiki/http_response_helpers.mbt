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
async fn send_isolated_preview_file(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  path : String,
  code : Int,
  reason : String,
) -> Unit {
  conn.send_response(code, reason, extra_headers=isolated_preview_headers(path))
  if method_ is Head {
    conn.end_response()
    return
  }
  if @pathx.ext(path) == ".html" {
    conn.write(@fs.read_file(path).text() + isolated_preview_observer_bridge())
  } else {
    conn.write(@fs.read_file(path).binary())
  }
  conn.end_response()
}

///|
fn isolated_preview_headers(path : String) -> Map[String, String] {
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

///|
fn isolated_preview_observer_bridge() -> String {
  (
    #|<script>
    #|(() => {
    #|  'use strict';
    #|  const protocol = 'moondesk-preview-v1';
    #|  const send = (type, detail = {}) => parent.postMessage({ protocol, type, ...detail }, '*');
    #|  for (const level of ['log', 'info', 'warn', 'error']) {
    #|    const original = console[level]?.bind(console);
    #|    if (!original) continue;
    #|    console[level] = (...args) => {
    #|      original(...args);
    #|      send('console', { level, message: args.map(String).join(' ').slice(0, 4000) });
    #|    };
    #|  }
    #|  addEventListener('error', (event) => send('runtime', {
    #|    message: String(event.message || 'Runtime error').slice(0, 4000),
    #|  }));
    #|  addEventListener('unhandledrejection', (event) => send('runtime', {
    #|    message: String(event.reason || 'Unhandled promise rejection').slice(0, 4000),
    #|  }));
    #|  addEventListener('message', (event) => {
    #|    if (event.source !== parent || event.data?.protocol !== protocol || event.data?.type !== 'snapshot-request') return;
    #|    const resources = performance.getEntriesByType('resource').map((entry) => {
    #|      try { return new URL(entry.name).pathname; } catch { return '[unparseable resource]'; }
    #|    }).slice(0, 100);
    #|    const landmarks = Array.from(document.querySelectorAll('main,nav,header,footer,aside,[role]'))
    #|      .map((node) => node.getAttribute('role') || node.tagName.toLowerCase());
    #|    const headings = Array.from(document.querySelectorAll('h1,h2,h3,h4,h5,h6'))
    #|      .map((node) => `${node.tagName.toLowerCase()}: ${String(node.textContent || '').trim()}`)
    #|      .filter(Boolean).slice(0, 50);
    #|    const unnamedControls = Array.from(document.querySelectorAll('button,input,select,textarea,a[href]'))
    #|      .filter((node) => !String(node.getAttribute('aria-label') || node.textContent || node.getAttribute('title') || '').trim()).length;
    #|    send('snapshot', {
    #|      resources,
    #|      accessibility: `title: ${document.title || '(none)'}\nlandmarks: ${landmarks.join(', ') || '(none)'}\nheadings:\n${headings.join('\n') || '(none)'}\nunnamed controls: ${unnamedControls}`,
    #|    });
    #|  });
    #|  send('ready', { title: document.title || '' });
    #|})();
    #|</script>
  )
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
  let body = api_contract_response(
    { "error": message },
    ok=false,
    status="error",
    message~,
    next_action="inspect_request",
  )
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
  send_api_json_error_with_headers(conn, method_, code, reason, payload, {})
}

///|
async fn send_api_json_error_with_headers(
  conn : @http.ServerConnection,
  method_ : @http.RequestMethod,
  code : Int,
  reason : String,
  payload : Json,
  extra_headers : Map[String, String],
) -> Unit {
  let headers = { "content-type": "application/json; charset=utf-8" }
  for key, value in extra_headers {
    headers[key] = value
  }
  conn.send_response(code, reason, extra_headers=headers)
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
