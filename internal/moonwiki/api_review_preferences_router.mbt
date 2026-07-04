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
      let endpoint = @desk.review_items_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_review_items(workspace_root, request_path, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "review", "items", "decision"] => {
      let endpoint = @desk.review_decision_route()
      if desktop_api_route_accepts_post(endpoint, method_) {
        handle_review_item_decision(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "preferences", "views"] => {
      let endpoint = @desk.preferences_views_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_saved_views(workspace_root, method_, conn)
      } else if desktop_api_route_accepts_post(endpoint, method_) {
        handle_save_view(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "preferences", "tags"] => {
      let endpoint = @desk.preferences_tags_route()
      if desktop_api_route_accepts_read(endpoint, method_) {
        handle_tags(workspace_root, method_, conn)
      } else if desktop_api_route_accepts_post(endpoint, method_) {
        handle_save_tag(workspace_root, body, method_, conn)
      } else {
        send_desktop_api_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    _ => false
  }
}
