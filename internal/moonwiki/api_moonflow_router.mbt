///|
async fn route_moonflow_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  body : &@io.Reader,
  conn : @http.ServerConnection,
  cookie? : String = "",
) -> Bool {
  match segments {
    [
      "api",
      "moonflow",
      "retained",
      workspace,
      run,
      item,
      attempt,
      result,
      action,
      ordinal,
      .. tail,
    ] => {
      if !is_read_method(method_) {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD"])
      } else if tail.is_empty() ||
        (tail.length() == 2 && tail[0] == "download") ||
        tail == ["review"] {
        let number = @string.parse_int(ordinal) catch { _ => -1 }
        if number < 0 || number.to_string() != ordinal {
          send_api_error(
            conn, method_, 400, "Bad Request", "Invalid retained output ordinal",
          )
        } else {
          let identity : Json = {
            "workspace_id": workspace,
            "run_id": run,
            "work_item_id": item,
            "attempt_id": attempt,
            "result_id": result,
            "action_id": action,
            "artifact_index": number,
          }
          if tail == ["review"] {
            handle_moonflow_review(
              workspace_root,
              Some(identity),
              cookie,
              body,
              method_,
              conn,
            )
          } else {
            handle_moonflow_retained_result(
              workspace_root,
              identity,
              if tail.is_empty() {
                None
              } else {
                Some(tail[1])
              },
              method_,
              conn,
            )
          }
        }
      } else {
        send_api_error(
          conn, method_, 400, "Bad Request", "Unsupported retained result route",
        )
      }
      true
    }
    ["api", "moonflow", "review"] => {
      if method_ is Post {
        handle_moonflow_review(
          workspace_root,
          None,
          cookie,
          body,
          method_,
          conn,
        )
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    ["api", "moonflow", "single-step"] => {
      if method_ is Post {
        handle_moonflow_single_step(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    ["api", "moonflow", "plans"] => {
      if method_ is Post {
        handle_moonflow_plan(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    ["api", "moonflow", "capability"] => {
      if is_read_method(method_) {
        handle_moonflow_capability(method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD"])
      }
      true
    }
    ["api", "moonflow", "runs"] => {
      if is_read_method(method_) {
        handle_moonflow_runs(workspace_root, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD"])
      }
      true
    }
    ["api", "moonflow", "collaboration", workspace_id] => {
      if is_read_method(method_) {
        handle_moonflow_collaboration(
          workspace_root, workspace_id, method_, conn,
        )
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
    ["api", "moonflow", "composition"] => {
      if method_ is Post {
        handle_moonflow_composition(workspace_root, body, method_, conn)
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
    ["api", "moonflow", "runs", run_id, "actions"] => {
      if is_read_method(method_) {
        handle_moonflow_operator_actions(workspace_root, run_id, method_, conn)
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD"])
      }
      true
    }
    ["api", "moonflow", "runs", run_id, "actions", action_id] => {
      if method_ is Post {
        handle_moonflow_operator_action(
          workspace_root, run_id, action_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    ["api", "moonflow", "runs", run_id, "handoffs", token] => {
      if is_read_method(method_) {
        handle_moonflow_receiver_intake(
          workspace_root, run_id, token, method_, conn,
        )
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD"])
      }
      true
    }
    ["api", "moonflow", "runs", run_id, "handoffs", token, "status"] => {
      if is_read_method(method_) {
        handle_moonflow_receiver_status(
          workspace_root, run_id, token, method_, conn,
        )
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["GET", "HEAD"])
      }
      true
    }
    ["api", "moonflow", "runs", run_id, "handoffs", token, "receipt"] => {
      if method_ is Post {
        handle_moonflow_receiver_receipt(
          workspace_root, run_id, token, body, method_, conn,
        )
      } else {
        send_method_not_allowed_with_methods(conn, method_, ["POST"])
      }
      true
    }
    _ => false
  }
}
