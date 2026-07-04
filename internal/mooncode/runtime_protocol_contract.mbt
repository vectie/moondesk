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
      "accepted_events": [
        "runtime_step", "assistant_delta", "reasoning_delta", "reasoning_message",
        "assistant_message", "runtime_update", "tool_call", "tool_started", "tool_result",
        "tool_call_decode_error", "runtime_finished", "runtime_aborted", "max_steps_exhausted",
        "command_error", "turn_failed", "steer_applied", "steer_deferred", "steer_dropped",
        "usage", "file_change", "diff", "patch_applied", "patch_reverted", "test_result",
        "package_manifest", "package_index", "package_built", "package_verified",
        "review_receipt", "receipt.accept", "receipt.reject", "commit_created", "artifact",
      ],
      "normalization": "MoonClaw/MoonCode JSONL events are normalized into MoonCode lanes: transcript, runtime, tool, diff, test, artifact, and review.",
      "model_planner_evidence_contract": model_planner_evidence_contract_json(),
      "conversation_ownership_contract": conversation_ownership_contract_json(),
    },
    "tool_authorization": {
      "snapshot": "Every mooncode.runtime-command and native MoonCode command body carries mooncode-tool-authorization-snapshot with approval manifest path, approval counts, approval rows, enforcement_state, and runtime_may_execute.",
      "enforcement_rule": "MoonClaw must block gated tool execution when the snapshot has pending or rejected approvals, and should recheck /tool-authorization immediately before execution. Runtime replay and claim projections exclude blocked commands from pending/claimable work and preserve queue order by blocking later non-delivered rows.",
    },
    "ordering_rule": "One ordered command queue per session; prompts, steers, cancels, turn completion, and shutdown must be serialized so steering cannot race terminal events.",
  }
}
