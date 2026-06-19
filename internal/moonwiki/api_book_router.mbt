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
      if is_read_method(method_) {
        send_json(
          conn,
          method_,
          Json::array(book_pattern_records_for_workspace(workspace_root)),
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "books", "base-types"] => {
      if is_read_method(method_) {
        send_json(
          conn,
          method_,
          Json::array(book_base_type_records_for_workspace(workspace_root)),
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "books", "template-registry"] => {
      if is_read_method(method_) {
        send_json(conn, method_, book_template_registry_status(workspace_root))
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "books", "verify"] => {
      if is_read_method(method_) {
        handle_book_contract_verify(workspace_root, request_path, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "books", "app-tool-portable"] => {
      if is_read_method(method_) {
        handle_app_tool_portable_status(
          workspace_root, request_path, method_, conn,
        )
      } else if method_ is Post {
        handle_app_tool_portable_export(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "books", "app-tool-portable", "all"] => {
      if is_read_method(method_) {
        handle_app_tool_portable_all_status(workspace_root, method_, conn)
      } else if method_ is Post {
        handle_app_tool_portable_all_export(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "books", "sync-standing-goal"] => {
      if method_ is Post {
        handle_book_sync_standing_goal(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "books", "from-pattern"] => {
      if method_ is Post {
        handle_create_book_from_pattern(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    _ => false
  }
}
