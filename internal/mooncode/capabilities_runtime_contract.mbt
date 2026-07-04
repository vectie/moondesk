///|
// MoonCode runtime contract advertised by MoonCode capabilities.

///|
pub fn runtime_contract_json() -> Json {
  let tool_registry_names = runtime_tool_names().join(", ")
  {
    "reference": "mooncode",
    "target_component": "moonclaw",
    "standalone_component": "mooncode",
    "namespace_roles": [
      namespace_role(
        "workspace_mode", "Moondesk MoonCode", "Human-facing coding/chat workspace beside MoonWiki; owns navigation, context selection, review controls, and status projection.",
      ),
      namespace_role(
        "standalone_protocol", "mooncode.v1", "Portable command, session, stream, tool, review, and package contracts that can move out as a shared MoonCode protocol package.",
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
        "mooncode_runtime", "mooncode/runtime", "Loop-scoped runtime state, workspace root, bounded event queue, command scope, and steering input shared by tools.",
        "observe runtime state and render progress; do not execute tools directly",
      ),
      runtime_component(
        "mooncode_session", "mooncode/session + mooncode/session_store", "Typed durable coding conversation with append-only JSONL event storage and resumable session ids.",
        "select, list, resume, and project sessions for the native UI",
      ),
      runtime_component(
        "mooncode_tool",
        "mooncode/tool + mooncode/tool_contract",
        "Typed registry for \{tool_registry_names} tools with explicit output/control actions.",
        "show tool calls, approval state, outputs, and failures",
      ),
      runtime_component(
        "mooncode_turn_loop", "mooncode/turn_loop", "run_turn/run_turn_with_append/run_turn_in_scope loop that preserves tool batches, reasoning, tool results, and finish control.",
        "send prompt/steer/cancel commands and render the event stream",
      ),
      runtime_component(
        "eval_harness", "mooncode/eval/tool_harness + eval/file_edit + eval/patch_review + eval/command_execution + eval/package_output",
        "Deterministic tool, file-edit, patch-review, command-execution, and package-output evals that prove the coding agent can safely modify, verify, review, and package workspace files.",
        "display eval evidence and keep readiness blocked when harness evidence is missing",
      ),
    ],
    "command_protocol": {
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
          "purpose": "Inject operator guidance into the active or queued turn without starting an implicit new command.",
        },
        {
          "command": "cancel",
          "required_fields": ["command", "session_id"],
          "purpose": "Cancel the active turn or withdraw the next queued prompt while keeping the session process alive.",
        },
      ],
      "output_events": [
        "assistant_delta", "reasoning_delta", "assistant_message", "tool_call", "tool_result",
        "runtime_update", "file_change", "diff", "test_result", "artifact", "runtime_finished",
        "runtime_aborted", "command_error", "steer_applied", "steer_deferred", "steer_dropped",
      ],
      "ordering_rule": "one ordered command queue per session; prompts, steer, cancel, turn-done, and shutdown are serialized; idle steer is persisted as deferred steering context for the next eligible turn",
    },
    "session_store": {
      "owner": "moonclaw-or-mooncode",
      "shape": "session header plus append-only commands.jsonl and events.jsonl",
      "resume_modes": ["list", "show", "continue", "session-id"],
      "moondesk_projection": "MoonCode session list, canonical conversation, event-lane evidence, review queue, live tail, and readiness evidence",
    },
    "tool_contract": tool_contract_json(),
    "eval_contract": {
      "required_harnesses": [
        "tool_harness", "file_edit", "patch_review", "command_execution", "package_output",
      ],
      "harness_contract_endpoint": "/api/mooncode/eval-harness",
      "reference_paths": [
        "mooncode/eval/tool_harness", "mooncode/eval/file_edit", "mooncode/eval/patch_review",
        "mooncode/eval/command_execution", "mooncode/eval/package_output",
      ],
      "minimum_evidence": [
        "each built-in tool executes through the typed registry", "file edit cases prove final file contents",
        "patch review and apply/revert proof remains command-scoped", "moon_ide provides semantic discovery",
        "moon_cmd/moon_check/test failures surface as test_result events", "package output proof records source-bound executable-ready artifacts",
        "finish produces a terminal review summary",
      ],
      "native_eval_report": native_eval_report_contract_json(),
      "current_gap": "Moondesk exposes readiness gates and MoonClaw reports native baseline harness evidence; the remaining engine gap is broader autonomous model-backed planning across multi-turn coding work.",
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
