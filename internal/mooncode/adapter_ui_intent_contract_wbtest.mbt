///|
/// Exact payloads emitted by the production Desk UI submission/codec regression.
test "production UI command payloads reach the native adapter unchanged" {
  let inputs = [
    @json.parse(
      "{\"action\":\"prompt\",\"client_turn_id\":\"ui-intent-auto\",\"context_path\":\"\",\"message\":\"Review this code; do not edit or fix any files\",\"model\":\"\",\"web_search\":false,\"planner_reasoning_effort\":\"none\",\"approval_id\":\"\",\"target_command_id\":\"\",\"tool_call_id\":\"\",\"force_preflight\":false}",
    ),
    @json.parse(
      "{\"action\":\"prompt\",\"client_turn_id\":\"ui-intent-read_only\",\"context_path\":\"\",\"message\":\"Review this code; do not edit or fix any files\",\"model\":\"\",\"web_search\":false,\"planner_reasoning_effort\":\"none\",\"approval_id\":\"\",\"target_command_id\":\"\",\"tool_call_id\":\"\",\"force_preflight\":false,\"task_intent\":\"read_only\"}",
    ),
    @json.parse(
      "{\"action\":\"prompt\",\"client_turn_id\":\"ui-intent-workspace_change\",\"context_path\":\"\",\"message\":\"Review this code; do not edit or fix any files\",\"model\":\"\",\"web_search\":false,\"planner_reasoning_effort\":\"none\",\"approval_id\":\"\",\"target_command_id\":\"\",\"tool_call_id\":\"\",\"force_preflight\":false,\"task_intent\":\"workspace_change\"}",
    ),
  ]
  for input in inputs {
    guard decode_command_submission(input) is Ok(command) else {
      fail("UI command must decode")
    }
    let native = native_command_body(
      {
        "id": "session-intent",
        "workspace_id": "book",
        "workspace_root": "/tmp/readonly-intent-book",
      },
      command,
      "2026-10-02T00:00:00Z",
      Json::empty_object(),
    )
    assert_eq(
      json_string(
        json_object_field_or_empty(native, "payload"),
        "task_intent",
        default="",
      ),
      json_string(input, "task_intent", default=""),
    )
    println("R7_DESK_NATIVE:" + native.stringify())
  }
}
