///|
pub fn action_plan_items(
  commands : Array[Json],
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  events : Array[Json],
  summary : Json,
  lease_now? : String = "",
) -> Array[Json] {
  let items : Array[Json] = []
  for index in 0..<commands.length() {
    let command = commands[index]
    items.push(
      action_plan_item(
        index,
        command,
        runtime_commands,
        runtime_dispatches,
        events,
        summary,
        lease_now~,
      ),
    )
  }
  let mut blocked_index = 0
  for event in events {
    if json_string(event, "kind", default="") == "preflight.blocked" ||
      json_string(event, "kind", default="") == "preflight.override" {
      items.push(
        action_plan_preflight_item(commands.length() + blocked_index, event),
      )
      blocked_index += 1
    }
  }
  items
}

///|
pub fn action_plan_preflight_item(index : Int, event : Json) -> Json {
  let action = json_string(event, "command", default="command")
  let overridden = json_string(event, "kind", default="") ==
    "preflight.override"
  {
    "index": index,
    "command_id": json_string(event, "id", default=""),
    "action": action,
    "dispatch": "preflight",
    "approval": command_approval(action),
    "state": if overridden {
      "override"
    } else {
      "blocked"
    },
    "runtime_state": if overridden {
      "operator-override"
    } else {
      "blocked-before-dispatch"
    },
    "created_at": json_string(event, "created_at", default=""),
    "target": json_string(event, "path", default="moonbook"),
    "context_path": json_string(event, "path", default=""),
    "message": json_string(event, "detail", default=""),
    "expected_lanes": action_plan_string_array_json(
      command_expected_lanes(action),
    ),
    "tool_hints": action_plan_string_array_json(command_tool_hints(action)),
    "required_gates": action_plan_string_array_json(
      action_required_gates(action),
    ),
    "runtime_evidence": {
      "kind": "mooncode-command-runtime-evidence",
      "protocol": "mooncode.v1",
      "command_id": json_string(event, "id", default=""),
      "action": action,
      "status": if overridden {
        "operator-override"
      } else {
        "blocked-before-dispatch"
      },
      "required_event_count": 0,
      "proven_required_event_count": 0,
      "missing_required_event_count": 0,
      "failed_required_event_count": 0,
      "missing_required_events": [],
      "failed_required_events": [],
      "events": [],
      "proven": false,
    },
    "runtime_evidence_status": if overridden {
      "operator-override"
    } else {
      "blocked-before-dispatch"
    },
    "required_event_count": 0,
    "proven_required_event_count": 0,
    "missing_required_events": [],
    "failed_required_events": [],
    "blocking_reason": json_string(event, "detail", default=""),
    "next_step": if overridden {
      "operator forced dispatch; audit runtime evidence before accepting output"
    } else {
      "resolve the preflight gates and retry this command"
    },
  }
}

///|
pub fn action_plan_item(
  index : Int,
  command : Json,
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  proof_events : Array[Json],
  summary : Json,
  lease_now? : String = "",
) -> Json {
  let command_id = json_string(command, "command_id", default="")
  let action = json_string(command, "action", default="prompt")
  let runtime_state = action_plan_runtime_state_at(
    command_id,
    runtime_commands,
    runtime_dispatches,
    lease_now~,
  )
  let runtime_command = action_plan_runtime_command_for_id(
    command_id, runtime_commands,
  )
  let runtime_evidence = command_runtime_evidence(
    command, runtime_command, proof_events,
  )
  let base_state = action_plan_item_state_for_command(
    action, command_id, runtime_state, summary, proof_events,
  )
  let state = action_plan_item_state_with_tool_harness(
    action, runtime_state, base_state, runtime_evidence,
  )
  {
    "index": index,
    "command_id": command_id,
    "action": action,
    "dispatch": json_string(command, "dispatch", default="command"),
    "approval": json_string(command, "approval", default="none"),
    "state": state,
    "runtime_state": runtime_state,
    "created_at": json_string(command, "created_at", default=""),
    "target": json_string(command, "target", default="moonbook"),
    "context_path": json_string(command, "context_path", default=""),
    "message": json_string(command, "message", default=""),
    "expected_lanes": action_plan_json_array(command, "expected_lanes"),
    "tool_hints": action_plan_json_array(command, "tool_hints"),
    "required_gates": action_plan_string_array_json(
      action_required_gates(action),
    ),
    "runtime_evidence": runtime_evidence,
    "runtime_evidence_status": json_string(
      runtime_evidence,
      "status",
      default="missing-evidence",
    ),
    "required_event_count": runtime_json_int(
      runtime_evidence,
      "required_event_count",
      default=0,
    ),
    "proven_required_event_count": runtime_json_int(
      runtime_evidence,
      "proven_required_event_count",
      default=0,
    ),
    "missing_required_events": action_plan_json_array(
      runtime_evidence, "missing_required_events",
    ),
    "failed_required_events": action_plan_json_array(
      runtime_evidence, "failed_required_events",
    ),
    "tool_harness_status": json_string(
      runtime_evidence,
      "tool_harness_status",
      default="no-tools",
    ),
    "tool_harness_expected_tool_count": runtime_json_int(
      runtime_evidence,
      "tool_harness_expected_tool_count",
      default=0,
    ),
    "tool_harness_proven_tool_count": runtime_json_int(
      runtime_evidence,
      "tool_harness_proven_tool_count",
      default=0,
    ),
    "tool_harness_missing_tool_count": runtime_json_int(
      runtime_evidence,
      "tool_harness_missing_tool_count",
      default=0,
    ),
    "tool_harness_failed_tool_count": runtime_json_int(
      runtime_evidence,
      "tool_harness_failed_tool_count",
      default=0,
    ),
    "blocking_reason": action_plan_blocking_reason(
      action, runtime_state, state, summary,
    ),
    "next_step": action_plan_item_next_step(action, state),
  }
}
