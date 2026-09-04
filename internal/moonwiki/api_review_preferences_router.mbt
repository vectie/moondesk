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
    ["api", "document-review-threads"] => {
      if desktop_api_route_accepts_read(
          @desk.document_review_threads_route(),
          method_,
        ) {
        handle_document_review_threads(
          workspace_root, request_path, method_, conn,
        )
      } else if desktop_api_route_accepts_post(
          @desk.document_review_threads_route(),
          method_,
        ) {
        handle_save_document_review_thread(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "POST"])
      }
      true
    }
    ["api", "document-conversations"] => {
      if desktop_api_route_accepts_read(
          @desk.document_conversations_route(),
          method_,
        ) {
        handle_document_conversations(
          workspace_root, request_path, method_, conn,
        )
      } else if desktop_api_route_accepts_post(
          @desk.document_conversations_route(),
          method_,
        ) {
        handle_save_document_conversation(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "POST"])
      }
      true
    }
    ["api", "document-followups"] => {
      if desktop_api_route_accepts_read(
          @desk.document_followups_route(),
          method_,
        ) {
        handle_document_followups(workspace_root, request_path, method_, conn)
      } else if desktop_api_route_accepts_post(
          @desk.document_followups_route(),
          method_,
        ) {
        handle_save_document_followups(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "POST"])
      }
      true
    }
    ["api", "document-automation-results"] => {
      if desktop_api_route_accepts_read(
          @desk.document_automation_results_route(),
          method_,
        ) {
        handle_document_automation_results(
          workspace_root, request_path, method_, conn,
        )
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET"])
      }
      true
    }
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
    ["api", "preferences", "agent-memory"] => {
      if desktop_api_route_accepts_read(
          @desk.agent_preferences_route(),
          method_,
        ) {
        handle_agent_preferences(workspace_root, request_path, method_, conn)
      } else if desktop_api_route_accepts_post(
          @desk.agent_preferences_route(),
          method_,
        ) {
        handle_save_agent_preference(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "POST"])
      }
      true
    }
    _ => false
  }
}
