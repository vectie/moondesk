///|
// Compatibility wrappers for the core-owned native command metadata contract.

///|
pub fn native_command_tool_sequence(action : String) -> Array[String] {
  @mooncode_core.native_command_tool_sequence(action)
}

///|
pub fn native_command_expected_events(action : String) -> Array[String] {
  @mooncode_core.native_command_expected_events(action)
}

///|
pub fn native_command_required_outputs(action : String) -> Array[String] {
  @mooncode_core.native_command_required_outputs(action)
}

///|
pub fn native_command_recommended_commands(
  action : String,
  context_path : String,
) -> Array[String] {
  @mooncode_core.native_command_recommended_commands(action, context_path)
}

///|
pub fn native_command_default_package_kind(action : String) -> String {
  @mooncode_core.native_command_default_package_kind(action)
}
