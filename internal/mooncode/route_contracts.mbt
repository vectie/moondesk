///|
pub fn desktop_capabilities_endpoint() -> String {
  "/api/mooncode/capabilities"
}

///|
fn native_code_capabilities_endpoint() -> String {
  "/v1/code/capabilities"
}

///|
fn native_code_session_list_endpoint() -> String {
  "/v1/code/sessions?book_root=<path>"
}

///|
fn native_code_session_listing_endpoint() -> String {
  "/v1/code/sessions?book_root=<path>&format=json"
}

///|
fn native_code_session_show_endpoint() -> String {
  "/v1/code/sessions/<id>?book_root=<path>"
}

///|
fn native_code_session_commands_endpoint() -> String {
  "/v1/code/sessions/<id>/commands"
}

///|
fn native_code_session_runtime_control_endpoint() -> String {
  "/v1/code/sessions/<id>/runtime-control?book_root=<path>"
}

///|
fn native_code_session_runtime_claim_endpoint() -> String {
  "/v1/code/sessions/<id>/runtime-claim?book_root=<path>"
}

///|
fn native_code_session_stream_endpoint() -> String {
  "/v1/code/sessions/<id>/stream?book_root=<path>&format=jsonl|sse&since=<n>&wait_ms=<ms>&poll_ms=<ms>"
}

///|
fn native_code_session_runtime_turn_endpoint() -> String {
  "/v1/code/sessions/<id>/runtime-turn?book_root=<path>"
}

///|
fn native_code_session_runtime_loop_endpoint() -> String {
  "/v1/code/sessions/<id>/runtime-loop?book_root=<path>"
}

///|
fn native_code_session_runtime_service_endpoint() -> String {
  "/v1/code/sessions/<id>/runtime-service?book_root=<path>"
}

///|
fn native_code_session_runtime_events_endpoint() -> String {
  "/v1/code/sessions/<id>/runtime-events?book_root=<path>"
}

///|
fn native_code_session_tool_exec_endpoint() -> String {
  "/v1/code/sessions/<id>/tool-exec?book_root=<path>"
}

///|
fn native_code_session_eval_report_endpoint() -> String {
  "/v1/code/sessions/<id>/eval-report?book_root=<path>"
}

///|
fn native_code_session_package_result_endpoint() -> String {
  "/v1/code/sessions/<id>/package-result?book_root=<path>"
}

///|
fn native_projection_required_endpoints() -> Array[String] {
  [
    native_code_capabilities_endpoint(),
    native_code_session_list_endpoint(),
    native_code_session_listing_endpoint(),
    native_code_session_show_endpoint(),
    native_code_session_commands_endpoint(),
    native_code_session_runtime_control_endpoint(),
    native_code_session_runtime_claim_endpoint(),
    native_code_session_stream_endpoint(),
    native_code_session_runtime_turn_endpoint(),
    native_code_session_runtime_loop_endpoint(),
    native_code_session_runtime_service_endpoint(),
    native_code_session_runtime_events_endpoint(),
    native_code_session_tool_exec_endpoint(),
    native_code_session_eval_report_endpoint(),
    native_code_session_package_result_endpoint(),
  ]
}

///|
pub fn desktop_eval_harness_endpoint() -> String {
  "/api/mooncode/eval-harness"
}

///|
pub fn desktop_standalone_boundary_endpoint() -> String {
  "/api/mooncode/standalone-boundary"
}

///|
pub fn desktop_readiness_contract_endpoint() -> String {
  "/api/mooncode/readiness-contract"
}

///|
pub fn desktop_sessions_endpoint() -> String {
  "/api/mooncode/sessions"
}

///|
pub fn desktop_session_stream_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/stream?format=jsonl|sse&since=<sequence>"
}

///|
pub fn desktop_session_stream_state_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/stream-state?consumer=<consumer>&since=<sequence>"
}

///|
pub fn desktop_session_commands_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/commands"
}

///|
pub fn desktop_session_runtime_events_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-events"
}

///|
pub fn desktop_session_package_result_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/package-result"
}

///|
pub fn desktop_session_runtime_claim_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-claim"
}

///|
pub fn desktop_session_runtime_execution_plan_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-execution-plan"
}

///|
pub fn desktop_session_runtime_control_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-control"
}

///|
pub fn desktop_session_runtime_supervisor_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-supervisor"
}

///|
pub fn desktop_session_runtime_service_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-service"
}

///|
pub fn desktop_session_runtime_replay_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-replay"
}

///|
pub fn desktop_session_command_jsonl_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/command-jsonl?scope=pending|all"
}

///|
pub fn desktop_session_action_plan_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/action-plan"
}

///|
pub fn desktop_session_readiness_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/readiness"
}

///|
pub fn desktop_session_runtime_evidence_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-evidence"
}

///|
pub fn desktop_session_eval_report_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/eval-report"
}

///|
pub fn desktop_session_preflight_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/preflight?action=<action>&context_path=<path>"
}

///|
pub fn desktop_session_tool_authorization_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/tool-authorization"
}

///|
pub fn desktop_session_tool_approvals_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/tool-approvals"
}

///|
pub fn desktop_session_test_runs_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/test-runs"
}

///|
pub fn desktop_session_package_candidates_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/package-candidates"
}

///|
pub fn desktop_session_runtime_handoff_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-handoff"
}

///|
pub fn desktop_session_store_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/session-store"
}

///|
pub fn desktop_session_runtime_commands_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/runtime-commands"
}

///|
pub fn desktop_projection_required_endpoints() -> Array[String] {
  [
    desktop_capabilities_endpoint(),
    desktop_eval_harness_endpoint(),
    desktop_standalone_boundary_endpoint(),
    desktop_readiness_contract_endpoint(),
    desktop_sessions_endpoint(),
    desktop_session_stream_endpoint(),
    desktop_session_stream_state_endpoint(),
    desktop_session_commands_endpoint(),
    desktop_session_tool_approvals_endpoint(),
    desktop_session_tool_authorization_endpoint(),
    desktop_session_test_runs_endpoint(),
    desktop_session_package_candidates_endpoint(),
    desktop_session_action_plan_endpoint(),
    desktop_session_readiness_endpoint(),
    desktop_session_eval_report_endpoint(),
    desktop_session_package_result_endpoint(),
    desktop_session_runtime_handoff_endpoint(),
    desktop_session_store_endpoint(),
    desktop_session_runtime_commands_endpoint(),
    desktop_session_command_jsonl_endpoint(),
    desktop_session_runtime_events_endpoint(),
    desktop_session_runtime_claim_endpoint(),
    desktop_session_runtime_execution_plan_endpoint(),
    desktop_session_runtime_supervisor_endpoint(),
    desktop_session_runtime_service_endpoint(),
    desktop_session_runtime_control_endpoint(),
    desktop_session_runtime_replay_endpoint(),
    desktop_session_runtime_evidence_endpoint(),
    desktop_session_preflight_endpoint(),
  ]
}

///|
pub fn engine_supported_endpoints() -> Array[String] {
  let endpoints : Array[String] = ["/v1/models"]
  for endpoint in native_projection_required_endpoints() {
    endpoints.push(endpoint)
  }
  for endpoint in desktop_projection_required_endpoints() {
    endpoints.push(endpoint)
  }
  endpoints
}
