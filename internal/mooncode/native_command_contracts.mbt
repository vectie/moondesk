///|
// Native MoonCode command execution contracts and tool policies.

///|
pub fn native_command_execution_plan(
  action : String,
  context_path : String,
  payload : Json,
  command_packet : Json,
) -> Json {
  let web_search = json_bool(command_packet, "web_search", default=false)
  let approval = json_string(command_packet, "approval", default="none")
  @mooncode_core.native_command_execution_plan(
    action,
    context_path,
    trimmed_or(
      json_string(payload, "package_kind", default=""),
      fallback=@mooncode_core.native_command_default_package_kind(action),
    ),
    json_string(command_packet, "workspace_root", default=""),
    json_string(command_packet, "control", default="command"),
    approval,
    web_search,
  )
}

///|
pub fn native_command_tool_contract(action : String) -> Json {
  @mooncode_core.native_command_tool_contract(action)
}

///|
fn native_command_tool_contract_for_command(
  action : String,
  web_search : Bool,
) -> Json {
  @mooncode_core.native_command_tool_contract_for_command(action, web_search)
}
