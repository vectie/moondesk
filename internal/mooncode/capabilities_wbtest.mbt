///|
test "mooncode capability publishes canonical ownership and transport" {
  let capability = capabilities_json()
  assert_eq(json_string(capability, "component", default=""), "mooncode")
  assert_eq(summary_json_int(capability, "version", default=0), 2)
  let ownership = summary_json_object_field_or_empty(capability, "ownership")
  assert_eq(json_string(ownership, "sessions", default=""), "moonclaw")
  assert_eq(
    json_string(ownership, "canonical_conversation", default=""),
    "moonclaw",
  )
  assert_eq(json_string(ownership, "optimistic_rows", default=""), "moondesk")
  let protocol = summary_json_object_field_or_empty(
    capability, "session_protocol",
  )
  let native = @mooncode_core.native_capability_endpoints()
  assert_eq(
    json_string(protocol, "native_submit_turn_endpoint", default=""),
    native.session_turns,
  )
  assert_eq(
    json_string(protocol, "native_session_listing_endpoint", default=""),
    native.session_listing,
  )
  assert_eq(
    json_string(protocol, "canonical_watch_endpoint", default=""),
    desktop_session_watch_endpoint(),
  )
  assert_true(
    json_string(protocol, "durability", default="").contains("sole durable"),
  )
}

///|
test "mooncode capability publishes only implemented desktop routes" {
  let published = json_array_items(
    capabilities_json(),
    "desktop_route_contracts",
  )
  let expected = desktop_projection_route_contracts()
  assert_eq(published.length(), 6)
  assert_eq(published.length(), expected.length())
  let payload = Json::array(published).stringify()
  assert_true(payload.contains(desktop_session_watch_endpoint()))
  assert_true(payload.contains(desktop_session_commands_endpoint()))
  assert_false(payload.contains("runtime-service"))
  assert_false(payload.contains("runtime-replay"))
  assert_false(payload.contains("session-store"))
}

///|
test "mooncode capability derives commands and tools from core contracts" {
  let capability = capabilities_json()
  let protocol = summary_json_object_field_or_empty(
    capability, "session_protocol",
  )
  let commands = command_json_string_array_items(protocol, "commands")
  assert_eq(commands.length(), command_advertised_actions().length())
  for action in command_advertised_actions() {
    assert_true(commands.contains(action))
  }
  let tools = command_json_string_array_items(capability, "tools")
  assert_eq(tools.length(), capability_tool_names().length())
  for tool in native_capability_required_tools() {
    assert_true(tools.contains(tool))
  }
  assert_eq(json_array_items(capability, "tool_specs").length(), tools.length())
}

///|
test "mooncode engine status projection remains independent of HTTP" {
  let missing = engine_status_projection_json(
    daemon={ "running": false, "message": "daemon stopped" },
    moonclaw_root="",
    checkout_ready=false,
    running=false,
    models_ready=false,
    runtime_contract_ready=false,
    model_evidence="MoonClaw daemon is not running",
    runtime_evidence="MoonClaw daemon is not running",
  )
  assert_false(json_bool(missing, "ready", default=true))
  assert_eq(
    json_string(missing, "runtime_status", default=""),
    "missing-runtime",
  )
  let endpoints = command_json_string_array_items(
    missing, "supported_endpoints",
  )
  assert_true(endpoints.contains("/v1/code/sessions/<id>/turns"))
  assert_true(endpoints.contains(desktop_session_watch_endpoint()))
  assert_false(endpoints.contains(desktop_session_runtime_service_endpoint()))
}
