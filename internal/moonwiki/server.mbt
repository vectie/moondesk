///|
pub struct Server {
  server : @http.Server
  port : Int
}

///|
priv struct RunRef {
  workspace_id : String
  run_id : String
  run_root : String
}

///|
pub fn Server::port(self : Server) -> Int {
  self.port
}

///|
pub fn Server::close(self : Server) -> Unit {
  self.server.close()
}

///|
pub fn moondesk_health_path() -> String {
  "/__moondesk_health"
}

///|
fn moondesk_health_json(ui_root : String, workspace_root : String) -> Json {
  let context = workspace_context(workspace_root)
  {
    "ok": true,
    "service": "moondesk",
    "ui_root": @pathx.normalize(ui_root),
    "workspace_root": context.requested_root,
    "suite_root": context.suite_root,
    "books_root": context.books_root,
    "suite_path": context.state_dir,
    "tmp_path": context.tmp_root,
    "workspace_context": workspace_context_json(context),
  }
}

///|
pub async fn Server::new(
  host : String,
  port : Int,
  dual_stack? : Bool = true,
  reuse_addr? : Bool = false,
) -> Server {
  let host = if host == "localhost" { "127.0.0.1" } else { host }
  let server = @http.Server::Server(
    @socket.Addr::parse("\{host}:\{port}"),
    dual_stack~,
    reuse_addr~,
  )
  { server, port: server.addr.port() }
}

///|
pub async fn Server::serve_directory(self : Server, root : String) -> Unit {
  self.server.run_forever(
    (request, _, conn) => {
      handle_file_request(root, request.meth, strip_query(request.path), conn)
    },
    allow_failure=true,
  )
}

///|
pub async fn Server::serve_desk(
  self : Server,
  ui_root : String,
  workspace_root : String,
) -> Unit {
  let ui_root = @pathx.normalize(ui_root)
  let workspace_root = workspace_context(workspace_root).requested_root
  self.server.run_forever(
    (request, body, conn) => {
      handle_desk_request(ui_root, workspace_root, request, body, conn)
    },
    allow_failure=true,
  )
}

///|
async fn handle_desk_request(
  ui_root : String,
  workspace_root : String,
  request : @http.Request,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let host = request.headers.get("host").unwrap_or("")
  if !moondesk_browser_host_allowed(host) {
    send_status(conn, 421, "Misdirected Request", "Unapproved MoonDesk host\n")
    return
  }
  let origin = request.headers.get("origin").unwrap_or("")
  if !moondesk_browser_origin_allowed(origin, host) {
    send_status(conn, 403, "Forbidden", "Unapproved MoonDesk origin\n")
    return
  }
  let path = strip_query(request.path)
  if path == moondesk_health_path() {
    handle_health_request(ui_root, workspace_root, request.meth, conn)
  } else if path.has_prefix("/pack-apps/") {
    handle_pack_app_proxy(
      workspace_root,
      request.meth,
      request.path,
      body,
      conn,
    )
  } else if path == "/api" || path.has_prefix("/api/") {
    handle_api_request(workspace_root, request.meth, request.path, body, conn)
  } else {
    handle_file_request(ui_root, request.meth, path, conn)
  }
}

///|
fn moondesk_browser_host_allowed(host : StringView) -> Bool {
  let value = host.to_owned().trim().to_owned().to_lower()
  value == "localhost" ||
  value.has_prefix("localhost:") ||
  value == "127.0.0.1" ||
  value.has_prefix("127.0.0.1:") ||
  value == "[::1]" ||
  value.has_prefix("[::1]:")
}

///|
fn moondesk_browser_origin_allowed(
  origin : StringView,
  host : StringView,
) -> Bool {
  let origin = origin.to_owned().trim().to_owned().to_lower()
  let host = host.to_owned().trim().to_owned().to_lower()
  origin == "" ||
  (
    moondesk_browser_host_allowed(host) &&
    (origin == "http://" + host || origin == "https://" + host)
  )
}

///|
async fn handle_health_request(
  ui_root : String,
  workspace_root : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  guard method_ is Get || method_ is Head else {
    send_status(conn, 405, "Method Not Allowed", "Method Not Allowed\n")
    return
  }
  send_json(conn, method_, moondesk_health_json(ui_root, workspace_root))
}

///|
async fn handle_file_request(
  root : String,
  method_ : @http.RequestMethod,
  path : StringView,
  conn : @http.ServerConnection,
) -> Unit {
  let root = @pathx.normalize(root)
  guard method_ is Get || method_ is Head else {
    send_status(conn, 405, "Method Not Allowed", "Method Not Allowed\n")
    return
  }
  match resolve_request_path(root, path) {
    Some(file_path) =>
      if @fs.exists(file_path) {
        send_file(conn, method_, file_path, 200, "OK")
      } else {
        send_status(conn, 404, "Not Found", "Not Found\n")
      }
    None => send_status(conn, 400, "Bad Request", "Bad Request\n")
  }
}
