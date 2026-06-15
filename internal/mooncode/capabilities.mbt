///|
pub fn capabilities_json() -> Json {
  {
    "ok": true,
    "component": "mooncode",
    "version": 1,
    "boundary": {
      "moondesk": [
        "native window shell", "MoonWiki/MoonCode workspace switcher", "book and session selection",
        "chat, transcript, diff, test, artifact, and review UI", "approval and packaging controls",
      ],
      "moonclaw": [
        "typed agent loop", "model provider integration", "durable coding sessions",
        "streaming events", "tool execution", "test and build execution", "result packaging",
      ],
      "moonbook": [
        "durable code artifacts", "generated miniapps and tools", "app-tool book structure",
        "accepted outputs", "review state",
      ],
    },
    "workspace_modes": [
      {
        "id": "moonwiki",
        "title": "MoonWiki",
        "purpose": "knowledge/book workspace for wiki, raw evidence, generated sites, reviews, publishing, and standing-watch inspection",
      },
      {
        "id": "mooncode",
        "title": "MoonCode",
        "purpose": "coding/chat workspace for book-scoped MoonClaw sessions that create, modify, test, and package executable code inside a MoonBook",
      },
    ],
    "session_protocol": {
      "transport_target": "MoonClaw daemon",
      "preferred_stream": "jsonl-or-sse-incremental",
      "stream_endpoint": "/api/mooncode/sessions/<session-id>/stream?format=jsonl|sse&since=<sequence>",
      "stream_state_endpoint": "/api/mooncode/sessions/<session-id>/stream-state?consumer=<consumer>&since=<sequence>",
      "eval_harness_contract_endpoint": "/api/mooncode/eval-harness",
      "runtime_event_ingest_endpoint": "/api/mooncode/sessions/<session-id>/runtime-events",
      "native_session_list_endpoint": "/v1/mooncode/sessions?book_root=<path>",
      "native_session_show_endpoint": "/v1/mooncode/sessions/<session-id>?book_root=<path>",
      "native_package_result_endpoint": "/v1/mooncode/sessions/<session-id>/package-result",
      "native_durable_session_store": ".moonclaw/mooncode/sessions/<session-id>/session.json, commands.jsonl, events.jsonl, and package-results.jsonl under the selected MoonBook root",
      "command_queue_endpoint": "/api/mooncode/sessions/<session-id>/commands",
      "runtime_claim_endpoint": "/api/mooncode/sessions/<session-id>/runtime-claim",
      "runtime_execution_plan_endpoint": "/api/mooncode/sessions/<session-id>/runtime-execution-plan",
      "serve_scheduler_endpoint": "/api/mooncode/sessions/<session-id>/serve-scheduler",
      "runtime_supervisor_endpoint": "/api/mooncode/sessions/<session-id>/runtime-supervisor",
      "serve_scheduler": "GET /serve-scheduler projects OpenSeek-style ordered prompt/steer/cancel semantics from commands.jsonl plus runtime lifecycle state, so MoonClaw or standalone mooncode can enforce one active turn, queued prompts, steer delivery, and cancel withdrawal without relying on Moondesk UI state.",
      "runtime_supervisor": "GET /runtime-supervisor returns a declarative launch packet that tells MoonClaw or standalone mooncode how to load session state, claim the next turn, execute the OpenSeek-compatible command, stream proof events, acknowledge completion/failure, and report native eval evidence. The packet embeds mooncode-runtime-supervisor-readiness so blocked launches expose missing command, scheduler, endpoint, request-template, or loop requirements.",
      "runtime_claim_state": "GET /runtime-claim returns claimable, claimed, delivered, failed, invalid, tool-authorization-blocked, and order-blocked command projections; POST /runtime-claim appends runtime-claimed lease receipts only for claimable commands before execution",
      "runtime_replay_endpoint": "/api/mooncode/sessions/<session-id>/runtime-replay",
      "openseek_serve_jsonl_endpoint": "/api/mooncode/sessions/<session-id>/serve-jsonl?scope=pending|all",
      "action_plan_endpoint": "/api/mooncode/sessions/<session-id>/action-plan",
      "runtime_evidence_endpoint": "/api/mooncode/sessions/<session-id>/runtime-evidence",
      "preflight_endpoint": "/api/mooncode/sessions/<session-id>/preflight?action=<action>&context_path=<path>",
      "tool_authorization_endpoint": "/api/mooncode/sessions/<session-id>/tool-authorization",
      "tool_authorization_snapshot": "Every native MoonCode command body and runtime-command row includes a mooncode-tool-authorization-snapshot with manifest path, approval counts, current approval rows, enforcement_state, and runtime_may_execute. MoonClaw or standalone MoonCode must enforce this snapshot and recheck /tool-authorization before gated tool execution. Commands with runtime_may_execute=false are excluded from pending replay/claim and block later non-delivered rows until approval state is resolved.",
      "command_preflight": "GET /preflight returns the same gate projection without mutation; POST /commands rejects blocked accept/package/commit/apply/revert commands before command log append when tests fail, approvals are pending, file changes lack verified tests, reviewed changes are missing for commit, or no selected patch target exists; rejected attempts are recorded as preflight.blocked events and projected into the Action Plan without entering the runtime command queue. Payloads with force_preflight=true append preflight.override audit events, then enter the normal command/runtime command queue as operator overrides that still require runtime evidence before output is trusted",
      "commands": [
        "prompt", "steer", "run_tests", "run_eval", "package", "commit", "accept",
        "reject", "apply_patch", "revert_patch", "approve_tool", "reject_tool", "cancel",
      ],
      "events": [
        "assistant_delta", "reasoning_delta", "tool_call", "tool_result", "file_change",
        "diff", "test_result", "artifact", "review", "terminal",
      ],
      "durability": "append-only commands.jsonl plus events.jsonl owned by MoonClaw or extractable MoonCode runtime; Moondesk supports ordered command replay, checkpointed cursor state, pollable incremental event replay with stable sequence numbers, and a session-level runtime evidence proof projection. MoonClaw also exposes cold book-local sidecar list/show endpoints for .moonclaw/mooncode/sessions so sessions can be discovered after daemon restart without spawning a task.",
    },
    "runtime_protocol": runtime_protocol_contract_json(),
    "runtime_contract": runtime_contract_json(),
    "serve_scheduler_contract": serve_scheduler_contract_json(),
    "moonclaw_adapter_contract": moonclaw_adapter_contract_json(),
    "tool_contract": tool_contract_json(),
    "tool_call_wire": tool_call_wire_contract_json(),
    "command_specs": command_specs_json(),
    "tools": [
      "shell", "read", "edit", "write", "moon_check", "finish", "apply_patch", "package_app_tool",
      "eval_harness",
    ],
    "tool_specs": [
      tool_spec(
        id="read",
        owner="moonclaw",
        lane="tool",
        approval="auto",
        purpose="Read bounded files inside the selected MoonBook context.",
        outputs=["tool_result"],
      ),
      tool_spec(
        id="edit",
        owner="moonclaw",
        lane="diff",
        approval="review",
        purpose="Apply focused edits that remain inside the selected MoonBook workspace.",
        outputs=["file_change", "diff"],
      ),
      tool_spec(
        id="write",
        owner="moonclaw",
        lane="diff",
        approval="review",
        purpose="Create generated source files, scripts, tools, miniapps, or app-tool assets.",
        outputs=["file_change", "diff"],
      ),
      tool_spec(
        id="shell",
        owner="moonclaw",
        lane="tool",
        approval="policy",
        purpose="Run bounded build, inspect, and packaging commands under the book workspace.",
        outputs=["terminal", "tool_result"],
      ),
      tool_spec(
        id="moon_check",
        owner="moonclaw",
        lane="test",
        approval="auto",
        purpose="Run MoonBit checks, tests, builds, and package validation for generated code.",
        outputs=["test_result"],
      ),
      tool_spec(
        id="package_app_tool",
        owner="moonbook",
        lane="artifact",
        approval="review",
        purpose="Package accepted executable output as a MoonBook tool, miniapp, generated site, or app-tool bundle.",
        outputs=["artifact", "review"],
      ),
      tool_spec(
        id="eval_harness",
        owner="moonclaw",
        lane="test",
        approval="auto",
        purpose="Run OpenSeek-style tool_harness and file_edit evals, then publish native eval proof for this MoonCode session.",
        outputs=["test_result", "eval_report.manifest"],
      ),
      tool_spec(
        id="finish",
        owner="moonclaw",
        lane="review",
        approval="operator",
        purpose="Summarize final changes, tests, residual risks, and accept/reject/package readiness.",
        outputs=["review"],
      ),
    ],
    "book_outputs": [
      "tools/", "apps/", "book/site/generated/", "portable/app-tool/", "wiki/reviews/",
      "raw/analysis-runs/",
    ],
    "extractable": {
      "future_package": "mooncode",
      "rule": "Moondesk may render and approve MoonCode sessions, but the coding engine and durable protocol must remain movable out of Moondesk.",
    },
  }
}

///|
pub fn runtime_contract_json() -> Json {
  {
    "reference": "../openseek",
    "target_component": "moonclaw",
    "extractable_component": "mooncode",
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
        "agent_tool", "openseek/agent_tool + agent/tool_definition.mbt", "Typed registry for read, edit, write, shell, moon_check, and finish tools with explicit output/control actions.",
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
        "agent_aborted", "command_error", "steer_dropped",
      ],
      "ordering_rule": "one ordered command queue per session; prompts, steer, cancel, turn-done, and shutdown are serialized so steering cannot race terminal events",
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
        "moon_check/test failures surface as test_result events", "finish produces a terminal review summary",
      ],
      "native_eval_report": native_eval_report_contract_json(),
      "current_gap": "Moondesk exposes readiness gates, but MoonClaw still needs to own and report these OpenSeek-style eval results.",
    },
  }
}

///|
pub fn eval_harness_contract_json() -> Json {
  {
    "ok": true,
    "kind": "mooncode-eval-harness-contract",
    "protocol": "mooncode.v1",
    "version": 1,
    "reference": "../openseek/eval",
    "owner": "moonclaw-or-extractable-mooncode",
    "moondesk_role": "display harness status, expose missing evidence, and block production-ready claims until MoonClaw reports passing tool and file-edit evals",
    "moonclaw_result_endpoint": "/v1/mooncode/sessions/<id>/eval-report",
    "moondesk_projection_endpoint": "/api/mooncode/sessions/<id>/eval-report",
    "required_harnesses": [
      {
        "id": "tool_harness",
        "reference_path": "../openseek/eval/tool_harness",
        "execution": "deterministic-host-side",
        "purpose": "Dispatch every built-in coding tool through the same typed registry used by the agent loop.",
        "required_tools": [
          "read", "write", "edit", "shell", "moon_check", "moon_cmd", "moon_ide",
          "finish",
        ],
        "required_evidence": [
          "tool registry builds", "each tool returns a typed result event", "filesystem mutations match expected disk state",
          "moon_check/moon_cmd/moon_ide execute against a temporary MoonBit package",
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
    "endpoint": "/v1/mooncode/sessions/<id>/eval-report",
    "transport": "http-json",
    "purpose": "Report MoonClaw-owned OpenSeek-style eval proof for the selected durable MoonCode session.",
    "required_fields": [
      "ok", "source", "endpoint", "session_id", "required_harnesses", "harnesses",
      "tool_harness", "file_edit", "passed_count", "failed_count", "evidence",
    ],
    "status_values": ["production-ready", "native-partial", "failed", "missing"],
    "normalization_rule": "Moondesk treats ok=true or native_eval_evidence_ready=true as native evidence, then annotates source=moonclaw-native-runtime and endpoint before persisting wiki/reviews/mooncode/<session-id>/eval-report.json.",
  }
}

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
        "eval_harness_evidence", "OpenSeek-style eval evidence", "missing", "MoonClaw still needs tool_harness and file_edit eval results before Moondesk can claim production-grade coding-agent behavior",
      ),
    ],
  }
}

///|
fn supported_engine_endpoints() -> Array[String] {
  [
    "/api/mooncode/eval-harness", "/v1/models", "/v1/tasks", "/v1/task", "/v1/task/<id>/message",
    "/v1/task/<id>/cancel", "/v1/mooncode/capabilities", "/v1/mooncode/sessions?book_root=<path>",
    "/v1/mooncode/sessions/<id>?book_root=<path>", "/v1/mooncode/sessions/<id>/commands",
    "/v1/mooncode/sessions/<id>/stream", "/v1/mooncode/sessions/<id>/eval-report",
    "/api/mooncode/sessions", "/api/mooncode/sessions/<id>/tool-approvals", "/api/mooncode/sessions/<id>/tool-authorization",
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

///|
fn command_specs_json() -> Array[Json] {
  let actions = [
    "prompt", "steer", "run_tests", "run_eval", "package", "commit", "accept", "reject",
    "approve_tool", "reject_tool", "apply_patch", "revert_patch", "cancel",
  ]
  actions.map(action => {
    "action": action,
    "dispatch": command_dispatch(action),
    "approval": command_approval(action),
    "expected_lanes": string_array_json(command_expected_lanes(action)),
    "tool_hints": string_array_json(command_tool_hints(action)),
  })
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

///|
fn tool_spec(
  id~ : String,
  owner~ : String,
  lane~ : String,
  approval~ : String,
  purpose~ : String,
  outputs~ : Array[String],
) -> Json {
  {
    "id": id,
    "owner": owner,
    "lane": lane,
    "approval": approval,
    "purpose": purpose,
    "outputs": string_array_json(outputs),
  }
}

///|
test "mooncode capability contract names the split packages" {
  let payload = capabilities_json().stringify()
  assert_true(payload.contains("\"component\":\"mooncode\""))
  assert_true(payload.contains("MoonWiki"))
  assert_true(payload.contains("MoonCode"))
  assert_true(payload.contains("MoonClaw daemon"))
  assert_true(payload.contains("package_app_tool"))
  assert_true(payload.contains("\"tool_specs\""))
  assert_true(payload.contains("\"command_specs\""))
  assert_true(payload.contains("\"dispatch\":\"steer\""))
  assert_true(payload.contains("\"approval\":\"operator\""))
  assert_true(payload.contains("\"action\":\"approve_tool\""))
  assert_true(payload.contains("\"action\":\"commit\""))
  assert_true(payload.contains("\"runtime_contract\""))
  assert_true(payload.contains("\"moonclaw_adapter_contract\""))
  assert_true(
    payload.contains("\"kind\":\"mooncode-moonclaw-adapter-contract\""),
  )
  assert_true(payload.contains("\"tool_contract\""))
  assert_true(payload.contains("\"kind\":\"mooncode-tool-contract\""))
  assert_true(payload.contains("\"tool_call_wire\""))
  assert_true(payload.contains("\"kind\":\"mooncode-tool-call-wire-contract\""))
  assert_true(payload.contains("openseek/agent_runtime"))
  assert_true(payload.contains("\"command\":\"prompt\""))
  assert_true(payload.contains("\"agent_finished\""))
  assert_true(payload.contains("\"required_harnesses\""))
  assert_true(payload.contains("\"harness_contract_endpoint\""))
  assert_true(payload.contains("/api/mooncode/eval-harness"))
  assert_true(payload.contains("\"native_eval_report\""))
  assert_true(payload.contains("/v1/mooncode/sessions/<id>/eval-report"))
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/action-plan"),
  )
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/runtime-events"),
  )
  assert_true(
    payload.contains("/api/mooncode/sessions/<session-id>/serve-jsonl"),
  )
}

///|
test "mooncode engine status projection is extractable from http probing" {
  let missing = engine_status_projection_json(
    daemon={ "running": false, "message": "daemon stopped" },
    moonclaw_root="",
    checkout_ready=false,
    running=false,
    models_ready=false,
    tasks_ready=false,
    runtime_contract_ready=false,
    model_evidence="MoonClaw daemon is not running",
    task_evidence="MoonClaw daemon is not running",
    runtime_evidence="MoonClaw daemon is not running",
  )
  assert_eq(json_string(missing, "status", default=""), "moonclaw-missing")
  assert_eq(
    json_string(missing, "adapter_status", default=""),
    "missing-runtime",
  )
  assert_false(json_bool(missing, "ok", default=true))
  assert_false(json_bool(missing, "native_runtime_ready", default=true))
  assert_false(json_bool(missing, "legacy_task_bridge_ready", default=true))
  assert_eq(json_array_items(missing, "checks").length(), 10)
  assert_eq(
    json_string(
      summary_json_object_field_or_empty(missing, "moonclaw_adapter"),
      "status",
      default="",
    ),
    "missing-runtime",
  )
  let endpoints = json_array_items(missing, "supported_endpoints")
  assert_true(
    endpoints
    .map(endpoint => endpoint.stringify())
    .contains("\"/v1/mooncode/sessions/<id>/commands\""),
  )
  let ready = engine_status_projection_json(
    daemon={ "running": true, "message": "running" },
    moonclaw_root="/tmp/moonclaw",
    checkout_ready=true,
    running=true,
    models_ready=true,
    tasks_ready=true,
    runtime_contract_ready=true,
    model_evidence="/v1/models responded",
    task_evidence="/v1/tasks responded",
    runtime_evidence="/v1/mooncode/capabilities responded",
  )
  assert_eq(json_string(ready, "status", default=""), "production-ready")
  assert_eq(json_string(ready, "adapter_status", default=""), "native-ready")
  assert_true(json_bool(ready, "ok", default=false))
  assert_true(json_bool(ready, "production_ready", default=false))
  assert_true(json_bool(ready, "native_runtime_ready", default=false))
  assert_true(json_bool(ready, "legacy_task_bridge_ready", default=false))
}

///|
test "mooncode runtime contract mirrors openseek serve/tool boundaries" {
  let contract = runtime_contract_json()
  assert_eq(json_string(contract, "reference", default=""), "../openseek")
  assert_eq(json_string(contract, "target_component", default=""), "moonclaw")
  let components = json_array_items(contract, "components")
  assert_eq(components.length(), 5)
  let ids = components.map(component => json_string(component, "id", default=""))
  assert_true(ids.contains("agent_runtime"))
  assert_true(ids.contains("agent_session"))
  assert_true(ids.contains("agent_tool"))
  assert_true(ids.contains("agent_loop"))
  assert_true(ids.contains("eval_harness"))
  let wire = summary_json_object_field_or_empty(contract, "wire_protocol")
  let commands = json_array_items(wire, "input_commands")
  assert_eq(commands.length(), 3)
  assert_eq(json_string(commands[0], "command", default=""), "prompt")
  assert_eq(json_string(commands[1], "command", default=""), "steer")
  assert_eq(json_string(commands[2], "command", default=""), "cancel")
  assert_true(
    json_array_items(wire, "output_events")
    .map(item => item.stringify())
    .contains("\"tool_result\""),
  )
  assert_true(
    json_array_items(wire, "output_events")
    .map(item => item.stringify())
    .contains("\"steer_dropped\""),
  )
  let eval = summary_json_object_field_or_empty(contract, "eval_contract")
  assert_true(
    json_array_items(eval, "required_harnesses")
    .map(item => item.stringify())
    .contains("\"file_edit\""),
  )
  assert_eq(
    json_string(eval, "harness_contract_endpoint", default=""),
    "/api/mooncode/eval-harness",
  )
  assert_true(
    json_array_items(eval, "reference_paths")
    .map(item => item.stringify())
    .contains("\"../openseek/eval/tool_harness\""),
  )
  let native_eval_report = summary_json_object_field_or_empty(
    eval, "native_eval_report",
  )
  assert_eq(json_string(native_eval_report, "owner", default=""), "moonclaw")
  assert_eq(
    json_string(native_eval_report, "endpoint", default=""),
    "/v1/mooncode/sessions/<id>/eval-report",
  )
  assert_true(
    json_array_items(native_eval_report, "required_fields")
    .map(item => item.stringify())
    .contains("\"file_edit\""),
  )
  let tool_contract = summary_json_object_field_or_empty(
    contract, "tool_contract",
  )
  assert_eq(
    json_string(tool_contract, "kind", default=""),
    "mooncode-tool-contract",
  )
  assert_true(tool_contract_tool_ids(tool_contract).contains("moon_check"))
}

///|
test "mooncode eval harness contract names openseek cases and evidence" {
  let contract = eval_harness_contract_json()
  assert_eq(
    json_string(contract, "kind", default=""),
    "mooncode-eval-harness-contract",
  )
  assert_eq(json_string(contract, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(contract, "reference", default=""), "../openseek/eval")
  assert_eq(
    json_string(contract, "moonclaw_result_endpoint", default=""),
    "/v1/mooncode/sessions/<id>/eval-report",
  )
  let harnesses = json_array_items(contract, "required_harnesses")
  assert_eq(harnesses.length(), 2)
  let ids = harnesses.map(harness => json_string(harness, "id", default=""))
  assert_true(ids.contains("tool_harness"))
  assert_true(ids.contains("file_edit"))
  let payload = contract.stringify()
  assert_true(payload.contains("../openseek/eval/tool_harness"))
  assert_true(payload.contains("../openseek/eval/file_edit"))
  assert_true(payload.contains("\"moon_ide\""))
  assert_true(payload.contains("\"compile_fix\""))
  assert_true(payload.contains("file-edit-eval:<case>"))
  assert_true(payload.contains("\"future_package\":\"mooncode/eval\""))
}
