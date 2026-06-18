///|
pub fn engine_check_json(
  id : String,
  label : String,
  status : String,
  evidence : String,
) -> Json {
  { "id": id, "label": label, "status": status, "evidence": evidence }
}

///|
pub fn engine_status_projection_json(
  daemon~ : Json,
  moonclaw_root~ : String,
  checkout_ready~ : Bool,
  running~ : Bool,
  models_ready~ : Bool,
  tasks_ready~ : Bool,
  runtime_contract_ready~ : Bool,
  model_evidence~ : String,
  task_evidence~ : String,
  runtime_evidence~ : String,
) -> Json {
  let bridge_ready = running && tasks_ready
  let production_ready = bridge_ready && runtime_contract_ready
  let adapter_readiness = moonclaw_adapter_readiness(
    running, runtime_contract_ready, bridge_ready, tasks_ready,
  )
  let adapter_status = json_string(
    adapter_readiness,
    "status",
    default="missing-runtime",
  )
  let status = if production_ready {
    "production-ready"
  } else if bridge_ready {
    "daemon-bridge-ready"
  } else if running {
    "daemon-bridge-partial"
  } else if checkout_ready {
    "daemon-not-running"
  } else {
    "moonclaw-missing"
  }
  {
    "ok": bridge_ready,
    "status": status,
    "bridge_mode": "moonclaw-daemon-v1-task-bridge",
    "production_ready": production_ready,
    "native_runtime_ready": runtime_contract_ready,
    "legacy_task_bridge_ready": bridge_ready,
    "adapter_status": adapter_status,
    "moonclaw_adapter": adapter_readiness,
    "moonclaw_root": moonclaw_root,
    "message": json_string(daemon, "message", default=""),
    "daemon": daemon,
    "supported_endpoints": string_array_json(supported_engine_endpoints()),
    "checks": [
      engine_check_json(
        "moonclaw_checkout",
        "MoonClaw checkout",
        if checkout_ready {
          "ready"
        } else {
          "missing"
        },
        if checkout_ready {
          moonclaw_root
        } else {
          "no runnable MoonClaw checkout found from MOONCLAW_ROOT or sibling ../moonclaw"
        },
      ),
      engine_check_json(
        "daemon_running",
        "MoonClaw daemon",
        if running {
          "ready"
        } else {
          "missing"
        },
        json_string(daemon, "message", default="MoonClaw daemon is not running"),
      ),
      engine_check_json(
        "model_api",
        "Model API",
        if models_ready {
          "ready"
        } else if running {
          "missing"
        } else {
          "blocked"
        },
        model_evidence,
      ),
      engine_check_json(
        "task_api",
        "Task API",
        if tasks_ready {
          "ready"
        } else if running {
          "missing"
        } else {
          "blocked"
        },
        task_evidence,
      ),
      engine_check_json(
        "prompt_message_cancel",
        "Prompt/message/cancel bridge",
        if runtime_contract_ready {
          "ready"
        } else if bridge_ready {
          "bridged"
        } else {
          "blocked"
        },
        if runtime_contract_ready {
          "Moondesk prefers /v1/mooncode/sessions/<id>/commands for prompt/steer/cancel/test/package/review commands"
        } else {
          "Moondesk falls back to /v1/task and /v1/task/<id>/message; cancel through /v1/task/<id>/cancel"
        },
      ),
      engine_check_json(
        "append_only_session_log", "Append-only session log", "ready", "MoonClaw owns book-local .moonclaw/mooncode/sessions/<session-id>/events.jsonl sidecars and exposes /v1/mooncode/sessions?book_root=<path> for cold discovery; Moondesk still mirrors UI-side logs under .moontown/mooncode-sessions",
      ),
      engine_check_json(
        "append_only_command_queue", "Append-only command queue", "ready", "MoonClaw owns book-local .moonclaw/mooncode/sessions/<session-id>/commands.jsonl sidecars and reports command counts from the native session show endpoint; Moondesk still mirrors UI-side command logs under .moontown/mooncode-sessions",
      ),
      engine_check_json(
        "typed_runtime_contract",
        "Typed MoonCode runtime contract",
        if runtime_contract_ready {
          "ready"
        } else {
          "missing"
        },
        runtime_evidence,
      ),
      engine_check_json(
        "moonclaw_adapter",
        "MoonClaw event adapter",
        if adapter_status == "native-ready" {
          "ready"
        } else if adapter_status == "compatibility-bridge" {
          "bridged"
        } else {
          "missing"
        },
        "adapter=\{adapter_status}; normalizes current MoonClaw task/tool events into mooncode.v1 runtime events",
      ),
      engine_check_json(
        "eval_harness_evidence", "OpenSeek-style eval evidence", "partial", "MoonClaw native eval readiness now requires tool_harness, file_edit, patch_review, command_execution, and package_output proof. Production-grade behavior still needs broader model-backed coding eval cases for live steering, diff-review decisions, and long-running resume/cancel workflows.",
      ),
    ],
  }
}

///|
fn supported_engine_endpoints() -> Array[String] {
  [
    "/api/mooncode/eval-harness", "/api/mooncode/extraction-boundary", "/api/mooncode/production-rubric",
    "/v1/models", "/v1/tasks", "/v1/task", "/v1/task/<id>/message", "/v1/task/<id>/cancel",
    "/v1/mooncode/capabilities", "/v1/mooncode/sessions?book_root=<path>", "/v1/mooncode/sessions/<id>?book_root=<path>",
    "/v1/mooncode/sessions/<id>/commands", "/v1/mooncode/sessions/<id>/runtime-claim?book_root=<path>",
    "/v1/mooncode/sessions/<id>/runtime-dispatch?book_root=<path>", "/v1/mooncode/sessions/<id>/runtime-turn?book_root=<path>",
    "/v1/mooncode/sessions/<id>/runtime-loop?book_root=<path>", "/v1/mooncode/sessions/<id>/stream?book_root=<path>",
    "/v1/mooncode/sessions/<id>/eval-report?book_root=<path>", "/api/mooncode/sessions",
    "/api/mooncode/sessions/<id>/tool-approvals", "/api/mooncode/sessions/<id>/tool-authorization",
    "/api/mooncode/sessions/<id>/test-runs", "/api/mooncode/sessions/<id>/package-candidates",
    "/api/mooncode/sessions/<id>/preflight", "/api/mooncode/sessions/<id>/action-plan",
    "/api/mooncode/sessions/<id>/runtime-evidence", "/api/mooncode/sessions/<id>/eval-report",
    "/api/mooncode/sessions/<id>/runtime-handoff", "/api/mooncode/sessions/<id>/session-store",
    "/api/mooncode/sessions/<id>/runtime-commands", "/api/mooncode/sessions/<id>/runtime-dispatch",
    "/api/mooncode/sessions/<id>/runtime-events", "GET /api/mooncode/sessions/<id>/runtime-claim",
    "/api/mooncode/sessions/<id>/runtime-execution-plan", "POST /api/mooncode/sessions/<id>/runtime-claim",
    "/api/mooncode/sessions/<id>/runtime-supervisor", "/api/mooncode/sessions/<id>/runtime-replay",
  ]
}
