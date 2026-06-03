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
async fn handle_api_request(
  workspace_root : String,
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Unit {
  let segments = path_segments(strip_query(request_path))
  match segments {
    ["api", "workspaces"] =>
      if is_read_method(method_) {
        send_json(conn, method_, discover_workspaces(workspace_root).to_json())
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "entries"] =>
      if is_read_method(method_) {
        handle_workspace_entries(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "preview"] =>
      if is_read_method(method_) {
        handle_workspace_preview(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "raw"] =>
      if is_read_method(method_) {
        handle_workspace_raw(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "file", .. asset_segments] =>
      if is_read_method(method_) {
        handle_workspace_file_asset(
          workspace_root,
          workspace_id,
          asset_segments.join("/"),
          method_,
          conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "site"] =>
      if is_read_method(method_) {
        handle_workspace_site_asset(
          workspace_root, workspace_id, "", method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "site", .. asset_segments] =>
      if is_read_method(method_) {
        handle_workspace_site_asset(
          workspace_root,
          workspace_id,
          asset_segments.join("/"),
          method_,
          conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "inbox"] =>
      if method_ is @http.RequestMethod::Post {
        handle_workspace_inbox(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "import"] =>
      if method_ is @http.RequestMethod::Post {
        handle_workspace_import(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "reveal"] =>
      if method_ is @http.RequestMethod::Post {
        handle_workspace_reveal(
          workspace_root, workspace_id, body, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "search"] =>
      if is_read_method(method_) {
        handle_search(workspace_root, request_path, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "state"] =>
      if is_read_method(method_) {
        handle_town_state(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "daemon"] =>
      if is_read_method(method_) {
        handle_town_daemon(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "daemon", "status"] =>
      if is_read_method(method_) {
        handle_daemon_lifecycle(workspace_root, "status", body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "daemon", "supervision"] =>
      if is_read_method(method_) || method_ is @http.RequestMethod::Post {
        handle_daemon_supervision(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "daemon", "agent"] =>
      if is_read_method(method_) || method_ is @http.RequestMethod::Post {
        handle_daemon_agent(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "daemon", action] =>
      if method_ is @http.RequestMethod::Post &&
        (action == "start" || action == "stop" || action == "restart") {
        handle_daemon_lifecycle(workspace_root, action, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "analytics"] =>
      if is_read_method(method_) {
        handle_town_analytics(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "progress"] =>
      if is_read_method(method_) {
        handle_town_progress(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "events"] =>
      if is_read_method(method_) {
        handle_town_events(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "calendar.ics"] =>
      if is_read_method(method_) {
        handle_town_calendar(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "messages"] =>
      if is_read_method(method_) {
        handle_town_messages(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "requests"] =>
      if is_read_method(method_) {
        handle_town_requests(workspace_root, method_, conn)
      } else if method_ is @http.RequestMethod::Post {
        handle_town_request(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "standing-goals"] =>
      if is_read_method(method_) {
        handle_town_standing_goals(workspace_root, method_, conn)
      } else if method_ is @http.RequestMethod::Post {
        handle_create_standing_goal(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "patterns"] =>
      if is_read_method(method_) {
        send_json(
          conn,
          method_,
          Json::array(book_pattern_records_for_workspace(workspace_root)),
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "base-types"] =>
      if is_read_method(method_) {
        send_json(
          conn,
          method_,
          Json::array(book_base_type_records_for_workspace(workspace_root)),
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "template-registry"] =>
      if is_read_method(method_) {
        send_json(conn, method_, book_template_registry_status(workspace_root))
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "verify"] =>
      if is_read_method(method_) {
        handle_book_contract_verify(workspace_root, request_path, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "sync-standing-goal"] =>
      if method_ is @http.RequestMethod::Post {
        handle_book_sync_standing_goal(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "refresh-eb-runtime"] =>
      if method_ is @http.RequestMethod::Post {
        handle_eb_refresh_runtime(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "run-health"] =>
      if is_read_method(method_) {
        handle_eb_run_health(workspace_root, request_path, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "eb-sample-run"] =>
      if method_ is @http.RequestMethod::Post {
        handle_eb_sample_run(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "moonclaw-import"] =>
      if method_ is @http.RequestMethod::Post {
        handle_eb_moonclaw_import(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "moonclaw-run"] =>
      if method_ is @http.RequestMethod::Post {
        handle_eb_moonclaw_run(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "moonclaw-reconcile"] =>
      if method_ is @http.RequestMethod::Post {
        handle_eb_moonclaw_reconcile(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "accept-recovered-eb-output"] =>
      if method_ is @http.RequestMethod::Post {
        handle_eb_accept_recovered_output(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "eb-production-proof"] =>
      if method_ is @http.RequestMethod::Post {
        handle_eb_production_proof(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "from-pattern"] =>
      if method_ is @http.RequestMethod::Post {
        handle_create_pdf_evidence_watch_book(
          workspace_root, body, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "books", "pdf-evidence-watch"] =>
      if method_ is @http.RequestMethod::Post {
        handle_create_pdf_evidence_watch_book(
          workspace_root, body, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "town", "dispatch"] =>
      if method_ is @http.RequestMethod::Post {
        handle_town_dispatch(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "moonclaw", "runs"] =>
      if is_read_method(method_) {
        handle_moonclaw_runs(workspace_root, request_path, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "moonclaw", "progress"] =>
      if is_read_method(method_) {
        handle_moonclaw_progress(workspace_root, request_path, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "moonclaw", "events"] =>
      if is_read_method(method_) {
        handle_moonclaw_events(workspace_root, request_path, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "moonclaw", "runs", run_id, "artifacts"] =>
      if is_read_method(method_) {
        handle_moonclaw_artifacts(workspace_root, run_id, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "agents", "daemon"] =>
      if is_read_method(method_) {
        handle_agent_daemon(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "agents", "models"] =>
      if is_read_method(method_) {
        handle_agent_models(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "agents", "tasks"] =>
      if is_read_method(method_) {
        handle_agent_tasks(workspace_root, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "agents", "sessions"] =>
      handle_agent_sessions(workspace_root, request_path, body, method_, conn)
    ["api", "agents", "sessions", session_id, action] =>
      handle_agent_session_action(
        workspace_root, session_id, action, body, method_, conn,
      )
    ["api", "review", "items"] =>
      if is_read_method(method_) {
        handle_review_items(workspace_root, request_path, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "workspaces", workspace_id, "review-diff"] =>
      if is_read_method(method_) {
        handle_workspace_review_diff(
          workspace_root, workspace_id, request_path, method_, conn,
        )
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "preferences", "views"] =>
      if is_read_method(method_) {
        handle_saved_views(workspace_root, method_, conn)
      } else if method_ is @http.RequestMethod::Post {
        handle_save_view(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    ["api", "preferences", "tags"] =>
      if is_read_method(method_) {
        handle_tags(workspace_root, method_, conn)
      } else if method_ is @http.RequestMethod::Post {
        handle_save_tag(workspace_root, body, method_, conn)
      } else {
        send_api_error(
          conn, method_, 405, "Method Not Allowed", "Method Not Allowed",
        )
      }
    _ => send_api_error(conn, method_, 404, "Not Found", "Not Found")
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
  guard method_ is @http.RequestMethod::Get ||
    method_ is @http.RequestMethod::Head else {
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
