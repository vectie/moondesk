///|
// Compatibility wrappers for the core-owned native command tool policy contract.

///|
pub fn native_command_tool_policies(
  action : String,
  context_path : String,
) -> Array[Json] {
  @mooncode_core.native_command_tool_policies(action, context_path)
}

///|
pub fn native_command_tool_policy(
  tool : String,
  action : String,
  context_path : String,
) -> Json {
  @mooncode_core.native_command_tool_policy(tool, action, context_path)
}
