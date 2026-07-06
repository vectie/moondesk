///|
pub fn command_runtime_message(
  message : String,
  command_packet : Json,
) -> String {
  message +
  "\n\nMoonCode command packet (JSON, protocol mooncode.v1):\n```json\n" +
  command_packet.stringify(indent=2) +
  "\n```\nUse this packet as the durable command contract. Keep all edits inside the selected MoonBook workspace, emit tool/diff/test/artifact/review events when available, and preserve the output contract."
}

///|
pub fn mooncode_code_command(message : String, command_packet : Json) -> Json {
  let control = json_string(command_packet, "control", default="command")
  let action = json_string(command_packet, "action", default="prompt")
  match control {
    "cancel" => mooncode_protocol_command("cancel", command_packet~)
    "steer" =>
      mooncode_protocol_command(
        "steer",
        command_packet~,
        text=command_runtime_message(message, command_packet),
      )
    "prompt" =>
      mooncode_protocol_command(
        "prompt",
        command_packet~,
        text=command_runtime_message(message, command_packet),
      )
    _ =>
      mooncode_protocol_command(
        "prompt",
        command_packet~,
        text="MoonCode action `\{action}` requested.\n\n" +
          command_runtime_message(message, command_packet),
      )
  }
}

///|
fn mooncode_protocol_command(
  command : String,
  text? : String = "",
  command_packet~ : Json,
) -> Json {
  let web_search = json_bool(command_packet, "web_search", default=false)
  let action = json_string(command_packet, "action", default=command)
  let tools = string_array_json(
    command_allowed_tool_sequence(action, web_search),
  )
  if command == "cancel" {
    { "command": command, "web_search": web_search, "allowed_tools": tools }
  } else if web_search {
    {
      "command": command,
      "text": text,
      "web_search": web_search,
      "allowed_tools": tools,
      "capability_note": "Web search is enabled for this turn; use web_search or web_fetch when current external context is needed.",
    }
  } else {
    {
      "command": command,
      "text": text,
      "web_search": web_search,
      "allowed_tools": tools,
    }
  }
}

///|
fn command_allowed_tool_sequence(
  action : String,
  web_search : Bool,
) -> Array[String] {
  @mooncode_core.native_command_allowed_tool_sequence(action, web_search)
}
