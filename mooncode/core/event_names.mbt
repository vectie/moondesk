///|
fn runtime_event_name_contract_id() -> String {
  "mooncode-runtime-event-names.v1"
}

///|
fn runtime_event_runtime_step() -> String {
  "runtime_step"
}

///|
fn runtime_event_assistant_delta() -> String {
  "assistant_delta"
}

///|
fn runtime_event_reasoning_delta() -> String {
  "reasoning_delta"
}

///|
fn runtime_event_reasoning_message() -> String {
  "reasoning_message"
}

///|
fn runtime_event_assistant_message() -> String {
  "assistant_message"
}

///|
fn runtime_event_runtime_update() -> String {
  "runtime_update"
}

///|
fn runtime_event_tool_call() -> String {
  "tool_call"
}

///|
fn runtime_event_tool_started() -> String {
  "tool_started"
}

///|
fn runtime_event_tool_result() -> String {
  "tool_result"
}

///|
fn runtime_event_tool_call_decode_error() -> String {
  "tool_call_decode_error"
}

///|
fn runtime_event_file_change() -> String {
  "file_change"
}

///|
fn runtime_event_diff() -> String {
  "diff"
}

///|
fn runtime_event_patch_applied() -> String {
  "patch_applied"
}

///|
fn runtime_event_patch_reverted() -> String {
  "patch_reverted"
}

///|
fn runtime_event_test_result() -> String {
  "test_result"
}

///|
fn runtime_event_package_manifest() -> String {
  "package_manifest"
}

///|
fn runtime_event_package_index() -> String {
  "package_index"
}

///|
fn runtime_event_package_built() -> String {
  "package_built"
}

///|
fn runtime_event_package_verified() -> String {
  "package_verified"
}

///|
fn runtime_event_review_receipt() -> String {
  "review_receipt"
}

///|
fn runtime_event_receipt_accept() -> String {
  "receipt.accept"
}

///|
fn runtime_event_receipt_reject() -> String {
  "receipt.reject"
}

///|
fn runtime_event_commit_created() -> String {
  "commit_created"
}

///|
fn runtime_event_artifact() -> String {
  "artifact"
}

///|
fn runtime_event_runtime_finished() -> String {
  "runtime_finished"
}

///|
fn runtime_event_runtime_aborted() -> String {
  "runtime_aborted"
}

///|
fn runtime_event_max_steps_exhausted() -> String {
  "max_steps_exhausted"
}

///|
fn runtime_event_command_error() -> String {
  "command_error"
}

///|
fn runtime_event_turn_failed() -> String {
  "turn_failed"
}

///|
fn runtime_event_steer_applied() -> String {
  "steer_applied"
}

///|
fn runtime_event_steer_deferred() -> String {
  "steer_deferred"
}

///|
fn runtime_event_steer_dropped() -> String {
  "steer_dropped"
}

///|
fn runtime_event_cancel_dropped() -> String {
  "cancel_dropped"
}

///|
fn runtime_event_usage() -> String {
  "usage"
}

///|
fn runtime_event_runtime_loop() -> String {
  "runtime_loop"
}

///|
fn runtime_event_turn_started() -> String {
  "runtime.turn_started"
}

///|
fn runtime_event_turn_finished() -> String {
  "runtime.turn_finished"
}

///|
fn runtime_event_runtime_unavailable() -> String {
  "runtime_unavailable"
}

///|
fn runtime_event_planner_failed() -> String {
  "runtime.planner_failed"
}

///|
fn runtime_event_planner_started() -> String {
  "runtime.planner_started"
}

///|
fn runtime_event_planner_selected() -> String {
  "runtime.planner_selected"
}

///|
fn runtime_event_service_started() -> String {
  "runtime.service_started"
}

///|
fn runtime_event_service_finished() -> String {
  "runtime.service_finished"
}

///|
fn runtime_event_service_failed() -> String {
  "runtime.service_failed"
}

///|
fn runtime_event_names() -> Array[String] {
  [
    runtime_event_runtime_step(),
    runtime_event_assistant_delta(),
    runtime_event_reasoning_delta(),
    runtime_event_reasoning_message(),
    runtime_event_assistant_message(),
    runtime_event_runtime_update(),
    runtime_event_tool_call(),
    runtime_event_tool_started(),
    runtime_event_tool_result(),
    runtime_event_tool_call_decode_error(),
    runtime_event_runtime_finished(),
    runtime_event_runtime_aborted(),
    runtime_event_max_steps_exhausted(),
    runtime_event_command_error(),
    runtime_event_turn_failed(),
    runtime_event_steer_applied(),
    runtime_event_steer_deferred(),
    runtime_event_steer_dropped(),
    runtime_event_usage(),
    runtime_event_file_change(),
    runtime_event_diff(),
    runtime_event_patch_applied(),
    runtime_event_patch_reverted(),
    runtime_event_test_result(),
    runtime_event_package_manifest(),
    runtime_event_package_index(),
    runtime_event_package_built(),
    runtime_event_package_verified(),
    runtime_event_review_receipt(),
    runtime_event_receipt_accept(),
    runtime_event_receipt_reject(),
    runtime_event_commit_created(),
    runtime_event_artifact(),
    runtime_event_turn_started(),
    runtime_event_turn_finished(),
    runtime_event_planner_started(),
    runtime_event_planner_selected(),
    runtime_event_planner_failed(),
  ]
}

///|
fn runtime_command_output_event_names() -> Array[String] {
  [
    runtime_event_assistant_delta(),
    runtime_event_reasoning_delta(),
    runtime_event_assistant_message(),
    runtime_event_tool_call(),
    runtime_event_tool_result(),
    runtime_event_runtime_update(),
    runtime_event_turn_started(),
    runtime_event_planner_started(),
    runtime_event_planner_selected(),
    runtime_event_planner_failed(),
    runtime_event_file_change(),
    runtime_event_diff(),
    runtime_event_test_result(),
    runtime_event_artifact(),
    runtime_event_runtime_finished(),
    runtime_event_runtime_aborted(),
    runtime_event_command_error(),
    runtime_event_steer_applied(),
    runtime_event_steer_deferred(),
    runtime_event_steer_dropped(),
  ]
}

///|
fn runtime_failure_event_names() -> Array[String] {
  [
    runtime_event_command_error(),
    runtime_event_turn_failed(),
    runtime_event_max_steps_exhausted(),
    runtime_event_runtime_unavailable(),
    runtime_event_planner_failed(),
  ]
}

///|
fn runtime_diagnostic_event_names() -> Array[String] {
  [
    runtime_event_runtime_loop(),
    runtime_event_usage(),
    runtime_event_service_started(),
    runtime_event_service_finished(),
    runtime_event_service_failed(),
  ]
}

///|
fn runtime_event_name_is_supported(name : String) -> Bool {
  runtime_event_names().contains(name)
}

///|
fn runtime_failure_event_name_is_supported(name : String) -> Bool {
  runtime_failure_event_names().contains(name)
}

///|
fn runtime_diagnostic_event_name_is_supported(name : String) -> Bool {
  runtime_diagnostic_event_names().contains(name)
}

///|
fn runtime_event_name_contract_json() -> Json {
  {
    "kind": "mooncode-runtime-event-name-contract",
    "protocol": protocol_version(),
    "contract_id": runtime_event_name_contract_id(),
    "accepted_events": runtime_event_names(),
    "command_output_events": runtime_command_output_event_names(),
    "failure_events": runtime_failure_event_names(),
    "diagnostic_events": runtime_diagnostic_event_names(),
    "event_lane_contract_id": event_lane_contract_id(),
    "rules": [
      "mooncode/core owns the accepted MoonClaw-to-MoonCode runtime event vocabulary",
      "internal MoonCode may normalize concrete events but must not publish a second accepted event list",
      "conversation rendering must use canonical turns and command-scoped runtime events",
      "failure events may become user-visible only when scoped to a MoonCode command",
    ],
  }
}
