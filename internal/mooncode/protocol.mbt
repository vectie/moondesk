///|
pub fn protocol_version() -> String {
  @mooncode_core.protocol_version()
}

///|
pub fn native_capability_contract_id() -> String {
  @mooncode_core.native_capability_contract_id()
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
