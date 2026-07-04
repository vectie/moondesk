///|
pub fn command_advertised_actions() -> Array[String] {
  @mooncode_core.command_advertised_actions()
}

///|
pub fn command_supported_actions() -> Array[String] {
  @mooncode_core.command_supported_actions()
}

///|
pub fn command_is_supported(action : String) -> Bool {
  @mooncode_core.command_action_is_supported(action)
}

///|
pub fn command_control(action : String) -> String {
  @mooncode_core.command_action_control(action)
}

///|
pub fn command_approval(action : String) -> String {
  @mooncode_core.command_action_approval(action)
}

///|
pub fn command_tool_hints(action : String) -> Array[String] {
  @mooncode_core.command_action_tool_hints(action)
}

///|
pub fn command_expected_lanes(action : String) -> Array[String] {
  @mooncode_core.command_action_expected_lanes(action)
}

///|
pub fn command_lane(action : String) -> String {
  @mooncode_core.command_action_lane(action)
}

///|
pub fn command_title(action : String, status : String) -> String {
  @mooncode_core.command_action_title(action, status)
}
