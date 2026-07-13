///|
async fn route_moonflow_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "moonflow", "runs"] => {
      if is_read_method(method_) {
        handle_moonflow_runs(workspace_root, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD"])
      }
      true
    }
    ["api", "moonflow", "runs", "import-selected"] => {
      if method_ is Post {
        handle_moonflow_import_selected(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    ["api", "moonflow", "runs", run_id] => {
      if is_read_method(method_) {
        handle_moonflow_run(workspace_root, run_id, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD"])
      }
      true
    }
    ["api", "moonflow", "runs", run_id, "control"] => {
      if method_ is Post {
        handle_moonflow_control(workspace_root, run_id, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    _ => false
  }
}
