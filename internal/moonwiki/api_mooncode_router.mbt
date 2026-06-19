///|
async fn route_mooncode_api(
  workspace_root : String,
  segments : Array[String],
  method_ : @http.RequestMethod,
  request_path : String,
  body : &@io.Reader,
  conn : @http.ServerConnection,
) -> Bool {
  match segments {
    ["api", "mooncode", "capabilities"] => {
      if is_read_method(method_) {
        handle_mooncode_capabilities(workspace_root, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "eval-harness"] => {
      if is_read_method(method_) {
        handle_mooncode_eval_harness_contract(method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "standalone-boundary"] => {
      if is_read_method(method_) {
        handle_mooncode_standalone_boundary_contract(method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "readiness-contract"] => {
      if is_read_method(method_) {
        handle_mooncode_readiness_contract(method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions"] => {
      if is_read_method(method_) {
        handle_mooncode_sessions(workspace_root, request_path, method_, conn)
      } else if method_ is Post {
        handle_create_mooncode_session(workspace_root, body, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "events"] => {
      if is_read_method(method_) {
        handle_mooncode_session_events(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "change-set"] => {
      if is_read_method(method_) {
        handle_mooncode_session_change_set(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "patch-set"] => {
      if is_read_method(method_) {
        handle_mooncode_session_patch_set(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "tool-approvals"] => {
      if is_read_method(method_) {
        handle_mooncode_session_tool_approvals(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "tool-authorization"] => {
      if is_read_method(method_) {
        handle_mooncode_session_tool_authorization_contract(
          workspace_root, session_id, method_, conn,
        )
      } else if method_ is Post {
        handle_mooncode_session_tool_authorization(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "test-runs"] => {
      if is_read_method(method_) {
        handle_mooncode_session_test_runs(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "package-candidates"] => {
      if is_read_method(method_) {
        handle_mooncode_session_package_candidates(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "action-plan"] => {
      if is_read_method(method_) {
        handle_mooncode_session_action_plan(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "readiness"] => {
      if is_read_method(method_) {
        handle_mooncode_session_readiness(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-evidence"] => {
      if is_read_method(method_) {
        handle_mooncode_session_runtime_evidence(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "eval-report"] => {
      if is_read_method(method_) {
        handle_mooncode_session_eval_report(
          workspace_root, session_id, method_, conn,
        )
      } else if method_ is Post {
        handle_mooncode_session_eval_report_ingest(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "package-result"] => {
      if method_ is Post {
        handle_mooncode_session_package_result(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-handoff"] => {
      if is_read_method(method_) {
        handle_mooncode_session_runtime_handoff(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-execution-plan"] => {
      if is_read_method(method_) {
        handle_mooncode_session_runtime_execution_plan(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "session-store"] => {
      if is_read_method(method_) {
        handle_mooncode_session_store(workspace_root, session_id, method_, conn)
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-commands"] => {
      if is_read_method(method_) {
        handle_mooncode_session_runtime_commands(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "serve-scheduler"] => {
      if is_read_method(method_) {
        handle_mooncode_session_serve_scheduler(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-supervisor"] => {
      if is_read_method(method_) {
        handle_mooncode_session_runtime_supervisor(
          workspace_root, session_id, method_, conn,
        )
      } else if method_ is Post {
        handle_mooncode_session_runtime_supervisor_run(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-service"] => {
      if method_ is Post {
        handle_mooncode_session_runtime_service_run(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-dispatch"] => {
      if is_read_method(method_) {
        handle_mooncode_session_runtime_dispatch(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-events"] => {
      if is_read_method(method_) {
        handle_mooncode_session_runtime_events(
          workspace_root, session_id, method_, conn,
        )
      } else if method_ is Post {
        handle_mooncode_session_runtime_event_ingest(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-replay"] => {
      if is_read_method(method_) {
        handle_mooncode_session_runtime_replay(
          workspace_root, session_id, method_, conn,
        )
      } else if method_ is Post {
        handle_mooncode_session_runtime_replay_ack(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "serve-jsonl"] => {
      if is_read_method(method_) {
        handle_mooncode_session_serve_jsonl(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-claim"] => {
      if is_read_method(method_) {
        handle_mooncode_session_runtime_claim_state(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else if method_ is Post {
        handle_mooncode_session_runtime_claim(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "stream-state"] => {
      if is_read_method(method_) || method_ is Post {
        handle_mooncode_session_stream_state(
          workspace_root, session_id, request_path, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "preflight"] => {
      if is_read_method(method_) {
        handle_mooncode_session_preflight(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "stream"] => {
      if is_read_method(method_) {
        handle_mooncode_session_stream(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "commands"] => {
      if is_read_method(method_) {
        handle_mooncode_session_commands(
          workspace_root, session_id, method_, conn,
        )
      } else if method_ is Post {
        handle_mooncode_session_command(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_method_not_allowed(conn, method_)
      }
      true
    }
    _ => false
  }
}
