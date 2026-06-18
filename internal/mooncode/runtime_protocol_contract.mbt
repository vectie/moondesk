///|
pub fn runtime_protocol_contract_json() -> Json {
  {
    "protocol": protocol_version(),
    "reference": "../openseek/cmd/openseek/serve.mbt",
    "serve_commands": Json::array(
      [
        for command in serve_command_names() => Json::string(command)
      ],
    ),
    "tool_registry": {
      "reference": "../openseek/agent/tool_definition.mbt",
      "required_tools": Json::array(
        [
          for tool in runtime_tool_names() => Json::string(tool)
        ],
      ),
      "tool_contract": tool_contract_json(),
      "tool_call_wire": tool_call_wire_contract_json(),
      "boundary": {
        "owner": "moonclaw",
        "ui": "moondesk renders tool calls, approval state, outputs, and failures",
        "extractable_component": "mooncode",
      },
    },
    "event_stream": {
      "reference": "../openseek/cmd/tui/internal/event/decode.mbt",
      "accepted_events": [
        "agent_step", "assistant_delta", "reasoning_delta", "reasoning_message",
        "assistant_message", "runtime_update", "tool_call", "tool_started", "tool_result",
        "tool_call_decode_error", "agent_finished", "agent_aborted", "max_steps_exhausted",
        "command_error", "turn_failed", "steer_applied", "steer_deferred", "steer_dropped",
        "usage", "file_change", "diff", "patch_applied", "patch_reverted", "test_result",
        "package_manifest", "package_index", "package_built", "package_verified",
        "review_receipt", "receipt.accept", "receipt.reject", "commit_created", "artifact",
      ],
      "normalization": "MoonClaw/OpenSeek JSONL events are normalized into MoonCode lanes: transcript, runtime, tool, diff, test, artifact, and review.",
    },
    "tool_authorization": {
      "snapshot": "Every mooncode.runtime-command and native MoonCode command body carries mooncode-tool-authorization-snapshot with approval manifest path, approval counts, approval rows, enforcement_state, and runtime_may_execute.",
      "enforcement_rule": "MoonClaw or standalone MoonCode must block gated tool execution when the snapshot has pending or rejected approvals, and should recheck /tool-authorization immediately before execution. Runtime replay and claim projections exclude blocked commands from pending/claimable work and preserve queue order by blocking later non-delivered rows.",
    },
    "ordering_rule": "One ordered command queue per session; prompts, steers, cancels, turn completion, and shutdown must be serialized so steering cannot race terminal events.",
  }
}
