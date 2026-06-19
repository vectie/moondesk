///|
async fn route_review_preferences_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "review", "items"] => {
      if is_read_method(method_) {
        handle_review_items(workspace_root, request_path, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "preferences", "views"] => {
      if is_read_method(method_) {
        handle_saved_views(workspace_root, method_, conn)
      } else if method_ is Post {
        handle_save_view(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "preferences", "tags"] => {
      if is_read_method(method_) {
        handle_tags(workspace_root, method_, conn)
      } else if method_ is Post {
        handle_save_tag(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    _ => false
  }
}
