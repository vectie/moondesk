///|
// OpenSeek-style runtime contract advertised by MoonCode capabilities.

///|
pub fn runtime_contract_json() -> Json {
  {
    "reference": "../openseek",
    "target_component": "moonclaw",
    "extractable_component": "mooncode",
    "namespace_roles": [
      namespace_role(
        "workspace_mode", "Moondesk MoonCode", "Human-facing coding/chat workspace beside MoonWiki; owns navigation, context selection, review controls, and status projection.",
      ),
      namespace_role(
        "extractable_protocol", "mooncode.v1", "Portable command, session, stream, tool, review, and package contracts that can move out as a standalone mooncode library.",
      ),
      namespace_role(
        "runtime_owner", "MoonClaw", "Executes model planning, tool calls, filesystem edits, test/build commands, packaging, streaming, steering, and cancellation.",
      ),
      namespace_role(
        "artifact_owner", "MoonBook", "Stores accepted code artifacts, miniapps, app-tool packages, reviews, command logs, and durable session evidence.",
      ),
    ],
    "status": "contract-specified",
    "runtime_protocol": runtime_protocol_contract_json(),
    "components": [
      runtime_component(
        "agent_runtime", "openseek/agent_runtime", "Loop-scoped runtime state, workspace root, bounded event queue, task scope, and steering input shared by tools.",
        "observe runtime state and render progress; do not execute tools directly",
      ),
      runtime_component(
        "agent_session", "openseek/agent_session + agent_session/store", "Typed durable coding conversation with append-only JSONL event storage and resumable session ids.",
        "select, list, resume, and project sessions for the native UI",
      ),
      runtime_component(
        "agent_tool", "openseek/agent_tool + agent/tool_definition.mbt", "Typed registry for read, edit, write, shell, moon_ide, moon_cmd, moon_check, and finish tools with explicit output/control actions.",
        "show tool calls, approval state, outputs, and failures",
      ),
      runtime_component(
        "agent_loop", "openseek/agent/agent.mbt", "run_turn/run_turn_with_append/run_turn_in_scope loop that preserves tool batches, reasoning, tool results, and finish control.",
        "send prompt/steer/cancel commands and render the event stream",
      ),
      runtime_component(
        "eval_harness", "openseek/eval/tool_harness + eval/file_edit", "Deterministic tool and file-edit evals that prove the coding agent can safely modify workspace files.",
        "display eval scores and block production claims when harness evidence is missing",
      ),
    ],
    "wire_protocol": {
      "transport": "jsonl-or-sse",
      "input_commands": [
        {
          "command": "prompt",
          "required_fields": ["command", "text", "session_id", "book_root"],
          "purpose": "Start or queue a coding turn for the selected MoonBook.",
        },
        {
          "command": "steer",
          "required_fields": ["command", "text", "session_id"],
          "purpose": "Inject operator guidance into the active or queued turn without starting an implicit new task.",
        },
        {
          "command": "cancel",
          "required_fields": ["command", "session_id"],
          "purpose": "Cancel the active turn or withdraw the next queued prompt while keeping the session process alive.",
        },
      ],
      "output_events": [
        "assistant_delta", "reasoning_delta", "assistant_message", "tool_call", "tool_result",
        "runtime_update", "file_change", "diff", "test_result", "artifact", "agent_finished",
        "agent_aborted", "command_error", "steer_applied", "steer_deferred", "steer_dropped",
      ],
      "ordering_rule": "one ordered command queue per session; prompts, steer, cancel, turn-done, and shutdown are serialized; idle steer is persisted as deferred steering context for the next eligible turn",
    },
    "session_store": {
      "owner": "moonclaw-or-mooncode",
      "shape": "session header plus append-only commands.jsonl and events.jsonl",
      "resume_modes": ["list", "show", "continue", "session-id"],
      "moondesk_projection": "MoonCode session list, transcript lanes, review queue, live tail, and readiness score",
    },
    "tool_contract": tool_contract_json(),
    "eval_contract": {
      "required_harnesses": ["tool_harness", "file_edit"],
      "harness_contract_endpoint": "/api/mooncode/eval-harness",
      "reference_paths": [
        "../openseek/eval/tool_harness", "../openseek/eval/file_edit",
      ],
      "minimum_evidence": [
        "each built-in tool dispatches through the typed registry", "file edit cases prove final file contents",
        "moon_ide provides semantic discovery", "moon_cmd/moon_check/test failures surface as test_result events",
        "finish produces a terminal review summary",
      ],
      "native_eval_report": native_eval_report_contract_json(),
      "current_gap": "Moondesk exposes readiness gates and MoonClaw now reports a first native tool/file-edit eval harness; the remaining engine gap is autonomous model-backed planning across multi-turn coding work.",
    },
  }
}

///|
fn namespace_role(id : String, name : String, responsibility : String) -> Json {
  { "id": id, "name": name, "responsibility": responsibility }
}

///|
fn runtime_component(
  id : String,
  reference : String,
  purpose : String,
  moondesk_role : String,
) -> Json {
  {
    "id": id,
    "owner": "moonclaw",
    "reference": reference,
    "purpose": purpose,
    "moondesk_role": moondesk_role,
  }
}
