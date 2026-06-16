///|
// MoonCode runtime consumer event emission from tool outcomes and proof events.

///|
pub fn runtime_consumer_ack_events(
  runtime_command : Json,
  tool_outcomes : Array[Json],
  proof_events : Array[Json],
  acknowledged_at? : String = "",
) -> Array[Json] {
  let events : Array[Json] = []
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let action = rq_json_string(runtime_command, "action", default="prompt")
  let mut index = 0
  for tool in runtime_consumer_expected_tool_sequence(runtime_command) {
    let outcome = runtime_consumer_outcome_for_tool(tool, tool_outcomes)
    if rq_json_string(outcome, "tool", default="") == "" {
      events.push(
        runtime_consumer_tool_missing_event(
          command_id, action, tool, index, acknowledged_at,
        ),
      )
    } else if tool == "finish" {
      events.push(
        runtime_consumer_finish_event(
          runtime_command, outcome, index, acknowledged_at,
        ),
      )
    } else {
      events.push(
        runtime_consumer_tool_call_event(
          runtime_command, outcome, index, acknowledged_at,
        ),
      )
      events.push(
        runtime_consumer_tool_result_event(
          runtime_command, outcome, index, acknowledged_at,
        ),
      )
    }
    index += 1
  }
  for event in proof_events {
    events.push(runtime_consumer_scoped_raw_event(runtime_command, event))
  }
  events
}

///|
fn runtime_consumer_outcome_for_tool(
  tool : String,
  outcomes : Array[Json],
) -> Json {
  for outcome in outcomes {
    if rq_json_string(outcome, "tool", default="") == tool {
      return outcome
    }
  }
  Json::object({})
}

///|
fn runtime_consumer_tool_call_event(
  runtime_command : Json,
  outcome : Json,
  index : Int,
  acknowledged_at : String,
) -> Json {
  runtime_consumer_scoped_raw_event(runtime_command, {
    "event": "tool_call",
    "id": runtime_consumer_event_id(runtime_command, "tool-call", index),
    "created_at": acknowledged_at,
    "tool_name": rq_json_string(outcome, "tool", default=""),
    "tool_call_id": rq_json_string(outcome, "tool_call_id", default=""),
    "arguments": rq_json_string(outcome, "arguments", default=""),
    "path": rq_json_string(outcome, "path", default=""),
    "command": rq_json_string(outcome, "command", default=""),
    "status": "running",
  })
}

///|
fn runtime_consumer_tool_result_event(
  runtime_command : Json,
  outcome : Json,
  index : Int,
  acknowledged_at : String,
) -> Json {
  runtime_consumer_scoped_raw_event(runtime_command, {
    "event": "tool_result",
    "id": runtime_consumer_event_id(runtime_command, "tool-result", index),
    "created_at": acknowledged_at,
    "tool_name": rq_json_string(outcome, "tool", default=""),
    "tool_call_id": rq_json_string(outcome, "tool_call_id", default=""),
    "arguments": rq_json_string(outcome, "arguments", default=""),
    "content": rq_json_string(outcome, "content", default=""),
    "path": rq_json_string(outcome, "path", default=""),
    "command": rq_json_string(outcome, "command", default=""),
    "exit_code": rq_json_int(outcome, "exit_code", default=0),
    "is_error": rq_json_bool(outcome, "is_error", default=false),
  })
}

///|
fn runtime_consumer_finish_event(
  runtime_command : Json,
  outcome : Json,
  index : Int,
  acknowledged_at : String,
) -> Json {
  runtime_consumer_scoped_raw_event(runtime_command, {
    "event": "agent_finished",
    "id": runtime_consumer_event_id(runtime_command, "finish", index),
    "created_at": acknowledged_at,
    "answer": if rq_json_string(outcome, "content", default="") == "" {
      "Runtime command finished."
    } else {
      rq_json_string(outcome, "content", default="")
    },
  })
}

///|
fn runtime_consumer_tool_missing_event(
  command_id : String,
  action : String,
  tool : String,
  index : Int,
  acknowledged_at : String,
) -> Json {
  {
    "event": "tool_call_decode_error",
    "id": "\{command_id}:missing-tool:\{index}",
    "created_at": acknowledged_at,
    "tool_name": tool,
    "tool_call_id": "missing-\{tool}",
    "source_event": "tool_call",
    "status": "failed",
    "detail": "Runtime consumer did not provide an outcome for expected tool `\{tool}`.",
    "command_id": command_id,
    "action": action,
  }
}

///|
fn runtime_consumer_scoped_raw_event(
  runtime_command : Json,
  event : Json,
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let action = rq_json_string(runtime_command, "action", default="prompt")
  let with_command = if rq_json_string(event, "command_id", default="") == "" {
    rq_json_with_field(event, "command_id", command_id.to_json())
  } else {
    event
  }
  if rq_json_string(with_command, "action", default="") == "" {
    rq_json_with_field(with_command, "action", action.to_json())
  } else {
    with_command
  }
}

///|
fn runtime_consumer_event_id(
  runtime_command : Json,
  kind : String,
  index : Int,
) -> String {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  if command_id == "" {
    "runtime-consumer:\{kind}:\{index}"
  } else {
    "\{command_id}:runtime-consumer:\{kind}:\{index}"
  }
}
