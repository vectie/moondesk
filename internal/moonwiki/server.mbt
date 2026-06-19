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
pub fn Server::new(
  host : String,
  port : Int,
  dual_stack? : Bool = true,
  reuse_addr? : Bool = false,
) -> Server raise {
  let host = if host == "localhost" { "127.0.0.1" } else { host }
  let server = @http.Server::new(
    @socket.Addr::parse("\{host}:\{port}"),
    dual_stack~,
    reuse_addr~,
  )
  { server, port: server.addr().port() }
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
  let workspace_root = @pathx.normalize(workspace_root)
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
  let path = strip_query(request.path)
  if path == "/api" || path.has_prefix("/api/") {
    handle_api_request(workspace_root, request.meth, request.path, body, conn)
  } else {
    handle_file_request(ui_root, request.meth, path, conn)
  }
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
