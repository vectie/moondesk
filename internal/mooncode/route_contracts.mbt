///|
pub fn desktop_capabilities_endpoint() -> String {
  "/api/mooncode/capabilities"
}

///|
pub fn desktop_status_endpoint() -> String {
  "/api/mooncode/status"
}

///|
fn native_projection_required_endpoints() -> Array[String] {
  native_capability_required_endpoints()
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
pub fn desktop_session_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>"
}

///|
pub fn desktop_session_events_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/events"
}

///|
pub fn desktop_session_change_set_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/change-set"
}

///|
pub fn desktop_session_patch_set_endpoint() -> String {
  "/api/mooncode/sessions/<session-id>/patch-set"
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
fn desktop_route_contract(path : String, methods : Array[String]) -> Json {
  { "path": path, "methods": string_array_json(methods) }
}

///|
pub fn desktop_projection_route_contracts() -> Array[Json] {
  [
    desktop_route_contract(desktop_status_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_capabilities_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_eval_harness_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_standalone_boundary_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_readiness_contract_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_sessions_endpoint(), ["GET", "HEAD", "POST"]),
    desktop_route_contract(desktop_session_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_session_events_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_session_change_set_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_patch_set_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_session_stream_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_session_stream_state_endpoint(), [
      "GET", "HEAD", "POST",
    ]),
    desktop_route_contract(desktop_session_commands_endpoint(), [
      "GET", "HEAD", "POST",
    ]),
    desktop_route_contract(desktop_session_tool_approvals_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_tool_authorization_endpoint(), [
      "GET", "HEAD", "POST",
    ]),
    desktop_route_contract(desktop_session_test_runs_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_session_package_candidates_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_action_plan_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_readiness_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_session_eval_report_endpoint(), [
      "GET", "HEAD", "POST",
    ]),
    desktop_route_contract(desktop_session_package_result_endpoint(), ["POST"]),
    desktop_route_contract(desktop_session_runtime_handoff_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_store_endpoint(), ["GET", "HEAD"]),
    desktop_route_contract(desktop_session_runtime_commands_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_command_jsonl_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_runtime_events_endpoint(), [
      "GET", "HEAD", "POST",
    ]),
    desktop_route_contract(desktop_session_runtime_claim_endpoint(), [
      "GET", "HEAD", "POST",
    ]),
    desktop_route_contract(desktop_session_runtime_execution_plan_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_runtime_supervisor_endpoint(), [
      "GET", "HEAD", "POST",
    ]),
    desktop_route_contract(desktop_session_runtime_service_endpoint(), ["POST"]),
    desktop_route_contract(desktop_session_runtime_control_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_runtime_replay_endpoint(), [
      "GET", "HEAD", "POST",
    ]),
    desktop_route_contract(desktop_session_runtime_evidence_endpoint(), [
      "GET", "HEAD",
    ]),
    desktop_route_contract(desktop_session_preflight_endpoint(), ["GET", "HEAD"]),
  ]
}

///|
pub fn desktop_projection_required_endpoints() -> Array[String] {
  let endpoints : Array[String] = []
  for contract in desktop_projection_route_contracts() {
    let path = json_string(contract, "path", default="")
    if path != "" {
      endpoints.push(path)
    }
  }
  endpoints
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
