///|
pub fn capabilities_json() -> Json {
  let native = @mooncode_core.native_capability_endpoints()
  {
    "ok": true,
    "component": "mooncode",
    "version": 2,
    "ownership": {
      "sessions": "moonclaw",
      "canonical_conversation": "moonclaw",
      "optimistic_rows": "moondesk",
      "artifacts": "moonbook",
    },
    "session_protocol": {
      "mutation_endpoint": desktop_session_commands_endpoint(),
      "canonical_watch_endpoint": desktop_session_watch_endpoint(),
      "canonical_watch_contract": conversation_watch_contract_json(),
      "native_submit_turn_endpoint": native.session_turns,
      "native_session_listing_endpoint": native.session_listing,
      "native_session_show_endpoint": native.session_show,
      "native_stream_endpoint": native.stream,
      "transport": "one durable submit followed by one resumable selected-session watcher",
      "durability": "MoonClaw is the sole durable command, event, receipt, session, and canonical-conversation owner.",
      "rendering": "MoonDesk renders canonical turns only and never merges raw logs into chat.",
      "commands": command_advertised_actions(),
    },
    "runtime_contract": runtime_contract_json(),
    "runtime_control_contract": runtime_control_contract_json(),
    "moonclaw_runtime_contract": moonclaw_runtime_contract_json(),
    "desktop_route_contracts": Json::array(desktop_projection_route_contracts()),
    "tool_contract": tool_contract_json(),
    "tool_call_contract": tool_call_contract_json(),
    "commands": command_specs_json(),
    "tools": capability_tool_names(),
    "tool_specs": capability_tool_specs(),
  }
}

///|
fn capability_tool_names() -> Array[String] {
  @mooncode_core.runtime_tool_capability_names()
}

///|
fn capability_tool_specs() -> Array[Json] {
  @mooncode_core.runtime_tool_capability_specs()
}

///|
fn command_specs_json() -> Array[Json] {
  command_advertised_actions().map(action => {
    "action": action,
    "control": command_control(action),
    "approval": command_approval(action),
    "expected_lanes": string_array_json(command_expected_lanes(action)),
    "tool_hints": string_array_json(command_tool_hints(action)),
  })
}
