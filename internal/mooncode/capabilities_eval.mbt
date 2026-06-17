///|
// MoonCode eval harness and native eval report contracts.

///|
pub fn eval_harness_contract_json() -> Json {
  {
    "ok": true,
    "kind": "mooncode-eval-harness-contract",
    "protocol": protocol_version(),
    "version": 1,
    "reference": "../openseek/eval",
    "owner": "moonclaw-or-extractable-mooncode",
    "moondesk_role": "display harness status, expose missing evidence, and block production-ready claims until MoonClaw reports passing tool and file-edit evals",
    "moonclaw_result_endpoint": "/v1/mooncode/sessions/<id>/eval-report?book_root=<path>",
    "moondesk_projection_endpoint": "/api/mooncode/sessions/<id>/eval-report",
    "required_harnesses": [
      {
        "id": "tool_harness",
        "reference_path": "../openseek/eval/tool_harness",
        "execution": "deterministic-host-side",
        "purpose": "Dispatch every built-in coding tool through the same typed registry used by the agent loop.",
        "required_tools": [
          "read", "write", "edit", "shell", "moon_ide", "moon_cmd", "moon_check",
          "finish",
        ],
        "required_evidence": [
          "tool registry builds", "each tool returns a typed result event", "filesystem mutations match expected disk state",
          "moon_ide runs semantic navigation against a temporary MoonBit package",
          "moon_cmd executes structured MoonBit commands with bounded output", "moon_check executes against a temporary MoonBit package",
          "finish emits a terminal agent_finished event",
        ],
      },
      {
        "id": "file_edit",
        "reference_path": "../openseek/eval/file_edit",
        "execution": "model-facing-repeatable",
        "purpose": "Prove the MoonClaw coding loop can choose read/edit/write/test tools to complete file changes without corrupting protected files.",
        "required_cases": [
          "exact_replace", "ambiguous_replace", "multiline_replace", "create_file",
          "compile_fix",
        ],
        "required_evidence": [
          "expected files match exactly", "protected files remain unchanged", "case-specific validation passes",
          "shell is not used for file mutation", "final transcript contains file-edit-eval:<case>",
        ],
      },
    ],
    "report_schema": {
      "required_fields": [
        "ok", "source", "session_id", "required_harnesses", "harnesses", "tool_harness",
        "file_edit", "passed_count", "failed_count", "evidence", "generated_at",
      ],
      "harness_status_values": [
        "passed", "failed", "missing", "stale", "not-run",
      ],
      "production_rule": "production-ready requires tool_harness and file_edit to be present, fresh for the current MoonClaw build, and passing.",
    },
    "extraction_boundary": {
      "future_package": "mooncode/eval",
      "rule": "The contract must not depend on Moondesk UI state; MoonClaw or standalone mooncode can implement the harness and Moondesk only renders the report.",
    },
  }
}

///|
pub fn native_eval_report_contract_json() -> Json {
  {
    "owner": "moonclaw",
    "endpoint": "/v1/mooncode/sessions/<id>/eval-report?book_root=<path>",
    "transport": "http-json",
    "purpose": "Report MoonClaw-owned OpenSeek-style eval proof for the selected durable MoonCode session.",
    "required_fields": [
      "ok", "source", "endpoint", "session_id", "required_harnesses", "harnesses",
      "tool_harness", "file_edit", "passed_count", "failed_count", "evidence",
    ],
    "status_values": ["production-ready", "native-partial", "failed", "missing"],
    "normalization_rule": "Moondesk treats explicit ok=true, native_eval_evidence_ready=true, accepted/passed status, or passing nested native_eval harnesses as native evidence; explicit ok=false is preserved. Moondesk annotates source=moonclaw-native-runtime and endpoint before persisting wiki/reviews/mooncode/<session-id>/eval-report.json.",
  }
}
