///|
async fn route_book_requests(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "books", "patterns"] => {
      let endpoint = @desk.books_route("patterns")
      if desktop_api_route_accepts_read(endpoint, method_) {
        send_json(
          conn,
          method_,
          Json::array(book_pattern_records_for_workspace(workspace_root)),
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "books", "base-types"] => {
      let endpoint = @desk.books_route("base-types")
      if desktop_api_route_accepts_read(endpoint, method_) {
        send_json(
          conn,
          method_,
          Json::array(book_base_type_records_for_workspace(workspace_root)),
        )
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "books", "template-registry"] => {
      let endpoint = @desk.books_route("template-registry")
      if desktop_api_route_accepts_read(endpoint, method_) {
        send_json(conn, method_, book_template_registry_status(workspace_root))
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "books", "verify"] => {
      let endpoint = @desk.books_route("verify")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_book_contract_verify(workspace_root, request_path, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "books", "app-tool-portable"] => {
      let endpoint = @desk.books_route("app-tool-portable")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_app_tool_portable_status(
          workspace_root, request_path, method_, conn,
        )
      } else if desktop_api_route_accepts_post(endpoint, method_) {
        handle_app_tool_portable_export(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "books", "app-tool-portable", "all"] => {
      let endpoint = @desk.books_route("app-tool-portable/all")
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_app_tool_portable_all_status(workspace_root, method_, conn)
      } else if desktop_api_route_accepts_post(endpoint, method_) {
        handle_app_tool_portable_all_export(workspace_root, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "books", "sync-standing-goal"] => {
      let endpoint = @desk.books_route("sync-standing-goal")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_book_sync_standing_goal(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "books", "from-pattern"] => {
      let endpoint = @desk.books_route("from-pattern")
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_create_book_from_pattern(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    _ => false
  }
}
