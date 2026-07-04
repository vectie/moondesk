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
  "mooncode-tool-call-contract"
}

///|
pub fn kind_tool_call() -> String {
  "mooncode-tool-call"
}

///|
pub fn event_tool_call() -> String {
  "tool_call"
}

///|
pub fn event_tool_started() -> String {
  "tool_started"
}

///|
pub fn event_tool_result() -> String {
  "tool_result"
}

///|
pub fn event_tool_call_decode_error() -> String {
  "tool_call_decode_error"
}

///|
pub fn event_test_result() -> String {
  "test_result"
}

///|
pub fn event_package_built() -> String {
  "package_built"
}

///|
pub fn event_package_verified() -> String {
  "package_verified"
}

///|
pub fn event_steer_applied() -> String {
  "steer_applied"
}

///|
pub fn event_steer_dropped() -> String {
  "steer_dropped"
}

///|
pub fn event_steer_deferred() -> String {
  "steer_deferred"
}

///|
pub fn event_cancel_dropped() -> String {
  "cancel_dropped"
}
