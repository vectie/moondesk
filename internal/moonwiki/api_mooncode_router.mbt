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
    ["api", "mooncode", "status"] => {
      let endpoint = @mooncode.desktop_status_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_status(workspace_root, method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "capabilities"] => {
      let endpoint = @mooncode.desktop_capabilities_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_capabilities(workspace_root, method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "eval-harness"] => {
      let endpoint = @mooncode.desktop_eval_harness_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_eval_harness_contract(method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "standalone-boundary"] => {
      let endpoint = @mooncode.desktop_standalone_boundary_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_standalone_boundary_contract(method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "readiness-contract"] => {
      let endpoint = @mooncode.desktop_readiness_contract_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_readiness_contract(method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions"] => {
      let endpoint = @mooncode.desktop_sessions_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_sessions(workspace_root, request_path, method_, conn)
      } else if mooncode_route_accepts_post(endpoint, method_) {
        handle_create_mooncode_session(workspace_root, body, method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id] => {
      let endpoint = @mooncode.desktop_session_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "events"] => {
      let endpoint = @mooncode.desktop_session_events_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_events(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "change-set"] => {
      let endpoint = @mooncode.desktop_session_change_set_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_change_set(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "patch-set"] => {
      let endpoint = @mooncode.desktop_session_patch_set_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_patch_set(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "tool-approvals"] => {
      let endpoint = @mooncode.desktop_session_tool_approvals_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_tool_approvals(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "tool-authorization"] => {
      let endpoint = @mooncode.desktop_session_tool_authorization_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_tool_authorization_contract(
          workspace_root, session_id, method_, conn,
        )
      } else if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_tool_authorization(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "test-runs"] => {
      let endpoint = @mooncode.desktop_session_test_runs_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_test_runs(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "package-candidates"] => {
      let endpoint = @mooncode.desktop_session_package_candidates_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_package_candidates(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "action-plan"] => {
      let endpoint = @mooncode.desktop_session_action_plan_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_action_plan(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "readiness"] => {
      let endpoint = @mooncode.desktop_session_readiness_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_readiness(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-evidence"] => {
      let endpoint = @mooncode.desktop_session_runtime_evidence_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_runtime_evidence(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "eval-report"] => {
      let endpoint = @mooncode.desktop_session_eval_report_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_eval_report(
          workspace_root, session_id, method_, conn,
        )
      } else if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_eval_report_ingest(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "package-result"] => {
      let endpoint = @mooncode.desktop_session_package_result_endpoint()
      if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_package_result(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-handoff"] => {
      let endpoint = @mooncode.desktop_session_runtime_handoff_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_runtime_handoff(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-execution-plan"] => {
      let endpoint = @mooncode.desktop_session_runtime_execution_plan_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_runtime_execution_plan(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "session-store"] => {
      let endpoint = @mooncode.desktop_session_store_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_store(workspace_root, session_id, method_, conn)
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-commands"] => {
      let endpoint = @mooncode.desktop_session_runtime_commands_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_runtime_commands(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-control"] => {
      let endpoint = @mooncode.desktop_session_runtime_control_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_runtime_control(
          workspace_root, session_id, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-supervisor"] => {
      let endpoint = @mooncode.desktop_session_runtime_supervisor_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_runtime_supervisor(
          workspace_root, session_id, method_, conn,
        )
      } else if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_runtime_supervisor_run(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-service"] => {
      let endpoint = @mooncode.desktop_session_runtime_service_endpoint()
      if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_runtime_service_run(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-events"] => {
      let endpoint = @mooncode.desktop_session_runtime_events_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_runtime_events(
          workspace_root, session_id, method_, conn,
        )
      } else if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_runtime_event_ingest(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-replay"] => {
      let endpoint = @mooncode.desktop_session_runtime_replay_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_runtime_replay(
          workspace_root, session_id, method_, conn,
        )
      } else if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_runtime_replay_ack(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "command-jsonl"] => {
      let endpoint = @mooncode.desktop_session_command_jsonl_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_command_jsonl(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "runtime-claim"] => {
      let endpoint = @mooncode.desktop_session_runtime_claim_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_runtime_claim_state(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_runtime_claim(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "stream-state"] => {
      let endpoint = @mooncode.desktop_session_stream_state_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) ||
        mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_stream_state(
          workspace_root, session_id, request_path, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "preflight"] => {
      let endpoint = @mooncode.desktop_session_preflight_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_preflight(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "stream"] => {
      let endpoint = @mooncode.desktop_session_stream_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_stream(
          workspace_root, session_id, request_path, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    ["api", "mooncode", "sessions", session_id, "commands"] => {
      let endpoint = @mooncode.desktop_session_commands_endpoint()
      if mooncode_route_accepts_read(endpoint, method_) {
        handle_mooncode_session_commands(
          workspace_root, session_id, method_, conn,
        )
      } else if mooncode_route_accepts_post(endpoint, method_) {
        handle_mooncode_session_command(
          workspace_root, session_id, body, method_, conn,
        )
      } else {
        send_mooncode_method_not_allowed(conn, method_, endpoint)
      }
      true
    }
    _ => false
  }
}
