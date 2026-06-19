///|
// Native MoonCode runtime result and completion contracts.

///|
pub fn native_command_result_contract(action : String) -> Json {
  let required_events = native_command_expected_events(action)
  let required_outputs = native_command_required_outputs(action)
  let event_sink = "POST /api/mooncode/sessions/<session-id>/runtime-events"
  let eval_report_sink = if action == "run_eval" {
    "POST /api/mooncode/sessions/<session-id>/eval-report"
  } else {
    ""
  }
  let ack_sink = "POST /api/mooncode/sessions/<session-id>/runtime-replay"
  {
    "kind": "mooncode-native-result-contract",
    "required_events": string_array_json(required_events),
    "required_outputs": string_array_json(required_outputs),
    "event_sink": event_sink,
    "eval_report_sink": eval_report_sink,
    "ack_sink": ack_sink,
    "execution_checklist": Json::array(
      native_command_execution_checklist(
        action, required_events, required_outputs, event_sink, eval_report_sink,
        ack_sink,
      ),
    ),
    "completion_rule": "A runtime consumer should append typed progress events, then acknowledge the command as runtime-completed or failed through runtime replay.",
  }
}

///|
pub fn native_command_execution_checklist(
  action : String,
  required_events : Array[String],
  required_outputs : Array[String],
  event_sink : String,
  eval_report_sink : String,
  ack_sink : String,
) -> Array[Json] {
  let items : Array[Json] = []
  let mut index = 1
  let push_step = fn(
    id : String,
    title : String,
    owner : String,
    required_event : String,
    required_output : String,
    endpoint : String,
    blocking : Bool,
  ) {
    items.push({
      "index": index,
      "id": id,
      "title": title,
      "owner": owner,
      "required_event": required_event,
      "required_output": required_output,
      "endpoint": endpoint,
      "blocking": blocking,
    })
    index += 1
  }
  push_step(
    "claim-command", "Claim the runtime command before execution", "moonclaw", "runtime-claimed receipt",
    "claim id", "POST /api/mooncode/sessions/<session-id>/runtime-claim", true,
  )
  for tool in native_command_tool_sequence(action) {
    push_step(
      "run-tool-\{tool}",
      "Run tool: \{tool}",
      "moonclaw",
      "",
      "",
      "",
      true,
    )
  }
  for event in required_events {
    push_step(
      "emit-event-\{event}",
      "Emit event: \{event}",
      "moonclaw",
      event,
      "",
      event_sink,
      true,
    )
  }
  for output in required_outputs {
    push_step(
      "produce-output-\{index}",
      "Produce output: \{output}",
      "moonclaw",
      "",
      output,
      "",
      true,
    )
  }
  if eval_report_sink != "" {
    push_step(
      "publish-native-eval-report", "Publish native eval report", "moonclaw", "native eval report",
      "eval-report manifest", eval_report_sink, true,
    )
  }
  push_step(
    "ack-command", "Acknowledge command completion", "moonclaw", "runtime-completed or runtime-failed receipt",
    "ack receipt", ack_sink, true,
  )
  items
}
