///|
pub fn capabilities_json() -> Json {
  let native_endpoints = @mooncode_core.native_capability_endpoints()
  {
    "ok": true,
    "component": "mooncode",
    "version": 1,
    "boundary": {
      "moondesk": [
        "native window shell", "MoonWiki/MoonCode workspace switcher", "book and session selection",
        "canonical chat, event evidence, diff, test, artifact, and review UI", "approval and packaging controls",
      ],
      "moonclaw": [
        "typed MoonCode turn loop", "model provider integration", "durable coding sessions",
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
      "stream_endpoint": desktop_session_stream_endpoint(),
      "stream_state_endpoint": desktop_session_stream_state_endpoint(),
      "canonical_watch_endpoint": desktop_session_watch_endpoint(),
      "canonical_watch_contract": conversation_watch_contract_json(),
      "eval_harness_contract_endpoint": desktop_eval_harness_endpoint(),
      "standalone_boundary_endpoint": desktop_standalone_boundary_endpoint(),
      "readiness_contract_endpoint": desktop_readiness_contract_endpoint(),
      "runtime_event_ingest_endpoint": desktop_session_runtime_events_endpoint(),
      "package_result_ingest_endpoint": desktop_session_package_result_endpoint(),
      "native_session_list_endpoint": native_endpoints.session_list,
      "native_session_listing_endpoint": native_endpoints.session_listing,
      "native_session_show_endpoint": native_endpoints.session_show,
      "native_package_result_endpoint": native_endpoints.package_result,
      "native_runtime_control_endpoint": native_endpoints.runtime_control,
      "native_eval_report_endpoint": native_endpoints.eval_report,
      "native_runtime_claim_endpoint": native_endpoints.runtime_claim,
      "native_runtime_turn_endpoint": native_endpoints.runtime_turn,
      "native_runtime_loop_endpoint": native_endpoints.runtime_loop,
      "native_runtime_service_endpoint": native_endpoints.runtime_service,
      "native_runtime_loop_options": native_capability_runtime_loop_options(),
      "native_durable_session_store": "\{@moonsuite.product_display_artifact("moonclaw", "mooncode/sessions/<session-id>/session.json")}, commands.jsonl, runtime-receipts.jsonl, events.jsonl, and package-results.jsonl under the selected MoonSuite root",
      "native_capabilities_readiness": "MoonDesk treats MoonClaw as native-runtime-ready only when /v1/code/capabilities passes the MoonCode-owned component/protocol, endpoint, and tool-set native contract check.",
      "command_queue_endpoint": desktop_session_commands_endpoint(),
      "runtime_claim_endpoint": desktop_session_runtime_claim_endpoint(),
      "event_lane_contract": event_lane_contract_json(),
      "runtime_execution_plan_endpoint": desktop_session_runtime_execution_plan_endpoint(),
      "runtime_control_endpoint": desktop_session_runtime_control_endpoint(),
      "runtime_supervisor_endpoint": desktop_session_runtime_supervisor_endpoint(),
      "runtime_service_endpoint": desktop_session_runtime_service_endpoint(),
      "runtime_control": "GET /runtime-control projects MoonCode ordered prompt/steer/cancel semantics from commands.jsonl plus runtime lifecycle state, so MoonClaw can enforce one active turn, queued prompts, steer delivery, and cancel withdrawal without relying on MoonDesk UI state.",
      "runtime_supervisor": "GET /runtime-supervisor returns a declarative launch packet that tells MoonClaw how to load session state, claim the next turn, execute the MoonCode command, stream proof events, acknowledge completion/failure, and report native eval evidence. The packet embeds mooncode-runtime-supervisor-readiness so blocked launches expose missing command, runtime control, endpoint, request-template, or loop requirements.",
      "runtime_claim_state": "GET /runtime-claim returns claimable, claimed, delivered, failed, invalid, tool-authorization-blocked, and order-blocked command projections; POST /runtime-claim appends runtime-claimed lease receipts only for claimable commands before execution. MoonClaw also exposes native /v1 runtime-claim, runtime-turn, runtime-loop, and runtime-service endpoints over commands.jsonl/runtime-receipts.jsonl/events.jsonl sidecars in the MoonClaw product home, so a native loop or daemon supervisor can claim, execute explicit, deterministic, or bounded model-planned MoonCode tools with tool-result feedback, emit planner reasoning/assistant/tool-call/tool-result events, and close durable commands without reading MoonDesk UI state.",
      "runtime_replay_endpoint": desktop_session_runtime_replay_endpoint(),
      "mooncode_protocol_jsonl_endpoint": desktop_session_command_jsonl_endpoint(),
      "action_plan_endpoint": desktop_session_action_plan_endpoint(),
      "readiness_endpoint": desktop_session_readiness_endpoint(),
      "runtime_evidence_endpoint": desktop_session_runtime_evidence_endpoint(),
      "preflight_endpoint": desktop_session_preflight_endpoint(),
      "tool_authorization_endpoint": desktop_session_tool_authorization_endpoint(),
      "tool_authorization_snapshot": "Every native MoonCode command body and runtime-command row includes a mooncode-tool-authorization-snapshot with manifest path, approval counts, current approval rows, enforcement_state, and runtime_may_execute. MoonClaw must enforce this snapshot and recheck /tool-authorization before gated tool execution. Commands with runtime_may_execute=false are excluded from pending replay/claim and block later non-delivered rows until approval state is resolved.",
      "command_preflight": "GET /preflight returns the same gate projection without mutation; POST /commands rejects blocked accept/package/commit/apply/revert commands before command log append when tests fail, approvals are pending, file changes lack verified tests, reviewed changes are missing for commit, or no selected patch target exists; rejected attempts are recorded as preflight.blocked events and projected into the Action Plan without entering the runtime command queue. Payloads with force_preflight=true append preflight.override audit events, then enter the normal command/runtime command queue as operator overrides that still require runtime evidence before output is trusted",
      "commands": command_advertised_actions(),
      "command_action_contract": command_action_contract_json(),
      "events": runtime_command_output_event_names(),
      "event_lanes": event_lanes(),
      "runtime_event_name_contract": runtime_event_name_contract_json(),
      "durability": "append-only commands.jsonl plus events.jsonl owned by MoonClaw behind the MoonCode runtime contract; MoonDesk supports ordered command replay, checkpointed cursor state, pollable incremental event replay with stable sequence numbers, and a session-level runtime evidence proof projection. MoonClaw also exposes cold product-home sidecar list/show endpoints, native runtime-claim receipts, runtime-turn execution receipts with planner reasoning/tool-call events, runtime-loop queue supervision, daemon runtime-service lifecycle events, and native runtime settlement receipts for \{@moonsuite.product_display_artifact("moonclaw", "mooncode/sessions")} so sessions can be discovered, leased, executed, and advanced after daemon restart.",
    },
    "runtime_protocol": runtime_protocol_contract_json(),
    "runtime_contract": runtime_contract_json(),
    "runtime_control_contract": runtime_control_contract_json(),
    "moonclaw_runtime_contract": moonclaw_runtime_contract_json(),
    "desktop_route_contracts": Json::array(desktop_projection_route_contracts()),
    "standalone_boundary": standalone_boundary_json(),
    "executable_book_lifecycle": executable_book_lifecycle_contract_json(),
    "readiness_contract": readiness_contract_json(),
    "tool_contract": tool_contract_json(),
    "tool_call_contract": tool_call_contract_json(),
    "command_specs": command_specs_json(),
    "tools": capability_tool_names(),
    "tool_specs": capability_tool_specs(),
    "book_outputs": [
      "tools/", "apps/", "book/site/generated/", "portable/app-tool/", "wiki/reviews/",
      "raw/analysis-runs/",
    ],
    "standalone": {
      "future_package": "mooncode",
      "core_package": "mooncode/core",
      "projection_package": "internal/mooncode",
      "host_package": "internal/moonwiki",
      "rule": "MoonDesk may render and approve MoonCode sessions, but the coding engine and durable protocol must remain movable out of MoonDesk.",
    },
  }
}

///|
fn capability_tool_names() -> Array[String] {
  @mooncode_core.runtime_tool_capability_names()
}

///|
fn capability_tool_specs() -> Array[Json] {
  @mooncode_core.runtime_tool_capability_specs()
}

///|
fn command_specs_json() -> Array[Json] {
  command_advertised_actions().map(action => {
    "action": action,
    "control": command_control(action),
    "approval": command_approval(action),
    "expected_lanes": string_array_json(command_expected_lanes(action)),
    "tool_hints": string_array_json(command_tool_hints(action)),
  })
}
