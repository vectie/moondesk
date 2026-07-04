///|
pub fn runtime_protocol_contract_json() -> Json {
  {
    "protocol": protocol_version(),
    "reference": "mooncode/runtime-protocol",
    "code_commands": Json::array(
      [
        for command in code_command_names() => Json::string(command)
      ],
    ),
    "tool_registry": {
      "reference": "mooncode/runtime/tools",
      "required_tools": Json::array(
        [
          for tool in runtime_tool_names() => Json::string(tool)
        ],
      ),
      "tool_contract": tool_contract_json(),
      "tool_call_contract": tool_call_contract_json(),
      "boundary": {
        "owner": "moonclaw",
        "ui": "moondesk renders tool calls, approval state, outputs, and failures",
        "standalone_component": "mooncode",
      },
    },
    "event_stream": {
      "reference": "mooncode/runtime/events",
      "event_lane_contract": event_lane_contract_json(),
      "event_name_contract": runtime_event_name_contract_json(),
      "accepted_events": runtime_event_names(),
      "normalization": "MoonClaw/MoonCode JSONL events are normalized through the mooncode/core event lane and runtime event-name contracts before they can affect projections.",
      "model_planner_evidence_contract": model_planner_evidence_contract_json(),
      "conversation_ownership_contract": conversation_ownership_contract_json(),
      "package_review_model_flow_contract": package_review_model_flow_contract_json(),
    },
    "tool_authorization": {
      "snapshot": "Every mooncode.runtime-command and native MoonCode command body carries mooncode-tool-authorization-snapshot with approval manifest path, approval counts, approval rows, enforcement_state, and runtime_may_execute.",
      "enforcement_rule": "MoonClaw must block gated tool execution when the snapshot has pending or rejected approvals, and should recheck /tool-authorization immediately before execution. Runtime replay and claim projections exclude blocked commands from pending/claimable work and preserve queue order by blocking later non-delivered rows.",
    },
    "ordering_rule": "One ordered command queue per session; prompts, steers, cancels, turn completion, and shutdown must be serialized so steering cannot race terminal events.",
  }
}
