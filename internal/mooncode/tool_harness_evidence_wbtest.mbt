///|
test "mooncode tool harness evidence proves command scoped tool calls" {
  let command : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let runtime_command : Json = {
    "command_id": "cmd-test",
    "execution_summary": { "tool_sequence": ["read", "moon_check", "finish"] },
  }
  let packet : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let evidence = tool_harness_evidence(command, runtime_command, [
    event_record(
      id="read-call",
      lane="tool",
      kind="read",
      title="Tool started",
      status="running",
      created_at="2026-06-15T00:00:00Z",
      detail="read file",
      command_packet=packet,
    )
    |> runtime_with_field("tool_call_id", "call-read".to_json()),
    event_record(
      id="read-result",
      lane="tool",
      kind="read",
      title="Tool finished",
      status="done",
      created_at="2026-06-15T00:00:01Z",
      detail="content",
      command_packet=packet,
    )
    |> runtime_with_field("tool_call_id", "call-read".to_json()),
    event_record(
      id="check-call",
      lane="test",
      kind="moon_check",
      title="Tool started",
      status="running",
      created_at="2026-06-15T00:00:02Z",
      detail="moon check",
      command_packet=packet,
    )
    |> runtime_with_field("tool_call_id", "call-check".to_json()),
    event_record(
      id="check-result",
      lane="test",
      kind="moon_check",
      title="Tool finished",
      status="done",
      created_at="2026-06-15T00:00:03Z",
      detail="ok",
      command_packet=packet,
    )
    |> runtime_with_field("tool_call_id", "call-check".to_json()),
    event_record(
      id="finish",
      lane="review",
      kind="finish",
      title="Runtime finished",
      status="done",
      created_at="2026-06-15T00:00:04Z",
      detail="done",
      command_packet=packet,
    ),
  ])
  assert_eq(json_string(evidence, "status", default=""), "proven")
  assert_eq(json_bool(evidence, "proven", default=false), true)
  assert_eq(json_array_items(evidence, "cases").length(), 3)
}

///|
test "mooncode tool harness evidence fails malformed tool events" {
  let command : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let runtime_command : Json = {
    "command_id": "cmd-test",
    "execution_summary": { "tool_sequence": ["moon_check"] },
  }
  let packet : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let evidence = tool_harness_evidence(command, runtime_command, [
    event_record(
      id="decode-error",
      lane="tool",
      kind=event_tool_call_decode_error(),
      title="Tool decode failed",
      status="failed",
      created_at="2026-06-15T00:00:00Z",
      detail="bad args",
      command_packet=packet,
    )
    |> runtime_with_field("tool_name", "moon_check".to_json())
    |> runtime_with_field("tool_call_id", "call-check".to_json()),
  ])
  assert_eq(json_string(evidence, "status", default=""), "failed")
  assert_eq(json_bool(evidence, "proven", default=true), false)
  let cases = json_array_items(evidence, "cases")
  assert_eq(json_string(cases[0], "status", default=""), "failed")
}
