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
pub fn mooncode_serve_command(message : String, command_packet : Json) -> Json {
  let dispatch = json_string(command_packet, "dispatch", default="command")
  let action = json_string(command_packet, "action", default="prompt")
  match dispatch {
    "cancel" => { "command": "cancel" }
    "steer" =>
      {
        "command": "steer",
        "text": command_runtime_message(message, command_packet),
      }
    "prompt" =>
      {
        "command": "prompt",
        "text": command_runtime_message(message, command_packet),
      }
    _ =>
      {
        "command": "prompt",
        "text": "MoonCode action `\{action}` requested.\n\n" +
        command_runtime_message(message, command_packet),
      }
  }
}
