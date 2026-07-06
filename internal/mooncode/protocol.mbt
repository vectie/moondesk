///|
pub fn protocol_version() -> String {
  @mooncode_core.protocol_version()
}

///|
pub fn native_capability_contract_id() -> String {
  @mooncode_core.native_capability_contract_id()
}

///|
pub fn executable_book_lifecycle_contract_id() -> String {
  @mooncode_core.executable_book_lifecycle_contract_id()
}

///|
pub fn executable_book_lifecycle_steps() -> Array[String] {
  @mooncode_core.executable_book_lifecycle_steps()
}

///|
pub fn executable_book_lifecycle_contract_json() -> Json {
  @mooncode_core.executable_book_lifecycle_contract_json()
}

///|
pub fn conversation_contract_id() -> String {
  @mooncode_core.conversation_contract_id()
}

///|
pub fn conversation_kind() -> String {
  @mooncode_core.conversation_kind()
}

///|
pub fn conversation_turn_kind() -> String {
  @mooncode_core.conversation_turn_kind()
}

///|
pub fn conversation_contract_json() -> Json {
  @mooncode_core.conversation_contract_json()
}

///|
pub fn native_capability_required_endpoints() -> Array[String] {
  @mooncode_core.native_capability_required_endpoints()
}

///|
pub fn native_capability_required_tools() -> Array[String] {
  @mooncode_core.native_capability_required_tools()
}

///|
pub fn native_capability_runtime_loop_options() -> Json {
  @mooncode_core.native_capability_runtime_loop_options()
}

///|
pub fn native_capability_surface_fingerprint() -> String {
  @mooncode_core.native_capability_surface_fingerprint()
}

///|
pub fn native_capability_surface_json() -> Json {
  @mooncode_core.native_capability_surface_json()
}

///|
pub fn command_action_contract_id() -> String {
  @mooncode_core.command_action_contract_id()
}

///|
fn command_prompt() -> String {
  @mooncode_core.command_prompt()
}

///|
fn command_steer() -> String {
  @mooncode_core.command_steer()
}

///|
fn command_run_tests() -> String {
  @mooncode_core.command_run_tests()
}

///|
fn command_run_eval() -> String {
  @mooncode_core.command_run_eval()
}

///|
fn command_package() -> String {
  @mooncode_core.command_package()
}

///|
fn command_commit() -> String {
  @mooncode_core.command_commit()
}

///|
fn command_accept() -> String {
  @mooncode_core.command_accept()
}

///|
fn command_reject() -> String {
  @mooncode_core.command_reject()
}

///|
fn command_approve_tool() -> String {
  @mooncode_core.command_approve_tool()
}

///|
fn command_reject_tool() -> String {
  @mooncode_core.command_reject_tool()
}

///|
fn command_apply_patch() -> String {
  @mooncode_core.command_apply_patch()
}

///|
fn command_revert_patch() -> String {
  @mooncode_core.command_revert_patch()
}

///|
fn command_cancel() -> String {
  @mooncode_core.command_cancel()
}

///|
pub fn command_action_contract_json() -> Json {
  @mooncode_core.command_action_contract_json()
}

///|
pub fn standalone_boundary_json() -> Json {
  @mooncode_core.standalone_boundary_json()
}

///|
pub fn event_lane_contract_id() -> String {
  @mooncode_core.event_lane_contract_id()
}

///|
pub fn event_lane_transcript() -> String {
  @mooncode_core.event_lane_transcript()
}

///|
pub fn event_lane_runtime() -> String {
  @mooncode_core.event_lane_runtime()
}

///|
pub fn event_lane_tool() -> String {
  @mooncode_core.event_lane_tool()
}

///|
pub fn event_lane_diff() -> String {
  @mooncode_core.event_lane_diff()
}

///|
pub fn event_lane_test() -> String {
  @mooncode_core.event_lane_test()
}

///|
pub fn event_lane_artifact() -> String {
  @mooncode_core.event_lane_artifact()
}

///|
pub fn event_lane_review() -> String {
  @mooncode_core.event_lane_review()
}

///|
pub fn event_lane_default() -> String {
  @mooncode_core.event_lane_default()
}

///|
pub fn event_lanes() -> Array[String] {
  @mooncode_core.event_lanes()
}

///|
pub fn event_progress_lanes() -> Array[String] {
  @mooncode_core.event_progress_lanes()
}

///|
pub fn event_lane_is_supported(lane : String) -> Bool {
  @mooncode_core.event_lane_is_supported(lane)
}

///|
pub fn event_lane_is_progress(lane : String) -> Bool {
  @mooncode_core.event_lane_is_progress(lane)
}

///|
pub fn event_lane_normalize(lane : String) -> String {
  @mooncode_core.event_lane_normalize(lane)
}

///|
pub fn event_lane_contract_json() -> Json {
  @mooncode_core.event_lane_contract_json()
}

///|
pub fn runtime_event_name_contract_id() -> String {
  @mooncode_core.runtime_event_name_contract_id()
}

///|
pub fn runtime_event_names() -> Array[String] {
  @mooncode_core.runtime_event_names()
}

///|
pub fn runtime_command_output_event_names() -> Array[String] {
  @mooncode_core.runtime_command_output_event_names()
}

///|
pub fn runtime_failure_event_names() -> Array[String] {
  @mooncode_core.runtime_failure_event_names()
}

///|
pub fn runtime_diagnostic_event_names() -> Array[String] {
  @mooncode_core.runtime_diagnostic_event_names()
}

///|
pub fn runtime_event_name_is_supported(name : String) -> Bool {
  @mooncode_core.runtime_event_name_is_supported(name)
}

///|
pub fn runtime_failure_event_name_is_supported(name : String) -> Bool {
  @mooncode_core.runtime_failure_event_name_is_supported(name)
}

///|
pub fn runtime_diagnostic_event_name_is_supported(name : String) -> Bool {
  @mooncode_core.runtime_diagnostic_event_name_is_supported(name)
}

///|
pub fn runtime_event_name_contract_json() -> Json {
  @mooncode_core.runtime_event_name_contract_json()
}

///|
pub fn event_runtime_step() -> String {
  @mooncode_core.runtime_event_runtime_step()
}

///|
pub fn event_assistant_delta() -> String {
  @mooncode_core.runtime_event_assistant_delta()
}

///|
pub fn event_reasoning_delta() -> String {
  @mooncode_core.runtime_event_reasoning_delta()
}

///|
pub fn event_reasoning_message() -> String {
  @mooncode_core.runtime_event_reasoning_message()
}

///|
pub fn event_assistant_message() -> String {
  @mooncode_core.runtime_event_assistant_message()
}

///|
pub fn event_runtime_update() -> String {
  @mooncode_core.runtime_event_runtime_update()
}

///|
pub fn kind_command() -> String {
  "mooncode.command"
}

///|
pub fn kind_command_ref() -> String {
  "mooncode.command-ref"
}

///|
pub fn kind_runtime_receipt() -> String {
  "mooncode.runtime-receipt"
}

///|
pub fn kind_runtime_command() -> String {
  "mooncode.runtime-command"
}

///|
pub fn kind_runtime_turn_packet() -> String {
  "mooncode-runtime-turn-packet"
}

///|
pub fn kind_tool_call_contract() -> String {
  @mooncode_core.runtime_tool_call_contract_kind()
}

///|
pub fn kind_tool_call() -> String {
  "mooncode-tool-call"
}

///|
pub fn event_tool_call() -> String {
  @mooncode_core.runtime_event_tool_call()
}

///|
pub fn event_tool_started() -> String {
  @mooncode_core.runtime_event_tool_started()
}

///|
pub fn event_tool_result() -> String {
  @mooncode_core.runtime_event_tool_result()
}

///|
pub fn event_tool_call_decode_error() -> String {
  @mooncode_core.runtime_event_tool_call_decode_error()
}

///|
pub fn event_file_change() -> String {
  @mooncode_core.runtime_event_file_change()
}

///|
pub fn event_diff() -> String {
  @mooncode_core.runtime_event_diff()
}

///|
pub fn event_patch_applied() -> String {
  @mooncode_core.runtime_event_patch_applied()
}

///|
pub fn event_patch_reverted() -> String {
  @mooncode_core.runtime_event_patch_reverted()
}

///|
pub fn event_test_result() -> String {
  @mooncode_core.runtime_event_test_result()
}

///|
pub fn event_package_manifest() -> String {
  @mooncode_core.runtime_event_package_manifest()
}

///|
pub fn event_package_index() -> String {
  @mooncode_core.runtime_event_package_index()
}

///|
pub fn event_package_built() -> String {
  @mooncode_core.runtime_event_package_built()
}

///|
pub fn event_package_verified() -> String {
  @mooncode_core.runtime_event_package_verified()
}

///|
pub fn event_review_receipt() -> String {
  @mooncode_core.runtime_event_review_receipt()
}

///|
pub fn event_receipt_accept() -> String {
  @mooncode_core.runtime_event_receipt_accept()
}

///|
pub fn event_receipt_reject() -> String {
  @mooncode_core.runtime_event_receipt_reject()
}

///|
pub fn event_commit_created() -> String {
  @mooncode_core.runtime_event_commit_created()
}

///|
pub fn event_artifact() -> String {
  @mooncode_core.runtime_event_artifact()
}

///|
pub fn event_runtime_finished() -> String {
  @mooncode_core.runtime_event_runtime_finished()
}

///|
pub fn event_runtime_aborted() -> String {
  @mooncode_core.runtime_event_runtime_aborted()
}

///|
pub fn event_max_steps_exhausted() -> String {
  @mooncode_core.runtime_event_max_steps_exhausted()
}

///|
pub fn event_command_error() -> String {
  @mooncode_core.runtime_event_command_error()
}

///|
pub fn event_turn_failed() -> String {
  @mooncode_core.runtime_event_turn_failed()
}

///|
pub fn event_steer_applied() -> String {
  @mooncode_core.runtime_event_steer_applied()
}

///|
pub fn event_steer_dropped() -> String {
  @mooncode_core.runtime_event_steer_dropped()
}

///|
pub fn event_steer_deferred() -> String {
  @mooncode_core.runtime_event_steer_deferred()
}

///|
pub fn event_cancel_dropped() -> String {
  @mooncode_core.runtime_event_cancel_dropped()
}

///|
pub fn event_usage() -> String {
  @mooncode_core.runtime_event_usage()
}

///|
pub fn event_runtime_loop() -> String {
  @mooncode_core.runtime_event_runtime_loop()
}

///|
pub fn event_runtime_turn_started() -> String {
  @mooncode_core.runtime_event_turn_started()
}

///|
pub fn event_runtime_turn_finished() -> String {
  @mooncode_core.runtime_event_turn_finished()
}

///|
pub fn event_runtime_unavailable() -> String {
  @mooncode_core.runtime_event_runtime_unavailable()
}

///|
pub fn event_planner_failed() -> String {
  @mooncode_core.runtime_event_planner_failed()
}

///|
pub fn event_runtime_service_started() -> String {
  @mooncode_core.runtime_event_service_started()
}

///|
pub fn event_runtime_service_finished() -> String {
  @mooncode_core.runtime_event_service_finished()
}

///|
pub fn event_runtime_service_failed() -> String {
  @mooncode_core.runtime_event_service_failed()
}
