///|
test "mooncode runtime command feed response owns runtime surface" {
  let command : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
    "action": "prompt",
    "control": "prompt",
    "code_command": "prompt",
    "command_packet": {
      "protocol": protocol_version(),
      "kind": kind_command(),
      "command_id": "cmd-1",
      "action": "prompt",
      "control": "prompt",
    },
    "native_mooncode_body": {
      "execution_plan": {
        "action": "prompt",
        "control": "prompt",
        "approval": "auto",
      },
    },
    "mooncode_command": { "command": "prompt", "text": "build it" },
  }
  let raw_receipt : Json = {
    "command_id": "cmd-other",
    "status": "runtime-completed",
  }
  let response = runtime_command_feed_response(
    "session-demo",
    [command],
    [raw_receipt],
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=false,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(response, "kind", default=""),
    "mooncode-runtime-command-feed",
  )
  assert_eq(rq_json_int(response, "runtime_command_count", default=0), 1)
  assert_eq(
    rq_json_int(response, "runtime_receipt_pending_count", default=0),
    1,
  )
  assert_eq(rq_json_int(response, "runtime_receipt_count", default=0), 1)
  let response_receipts = rq_json_array_items(response, "runtime_receipts")
  assert_eq(response_receipts.length(), 1)
  assert_true(
    rq_json_string(response_receipts[0], "receipt_id", default="").has_prefix(
      "mooncode-runtime-receipt-",
    ),
  )
  assert_eq(
    rq_json_string(response, "runtime_claim_endpoint", default=""),
    "/api/mooncode/sessions/session-demo/runtime-claim",
  )
  assert_true(
    rq_json_object_field(response, "runtime_replay") is Some(Object(_)),
  )
  assert_true(
    rq_json_object_field(response, "runtime_claim_contract") is Some(Object(_)),
  )
  assert_true(
    rq_json_object_field(response, "runtime_turn_packet") is Some(Object(_)),
  )
  assert_true(
    rq_json_object_field(response, "runtime_supervisor") is Some(Object(_)),
  )
  let aggregate = runtime_command_feed_result_response(
    "session-demo",
    [command],
    [raw_receipt],
    [],
    {
      "id": "session-demo",
      "workspace_id": "book-demo",
      "workspace_name": "Demo",
      "mooncode_runtime_session_id": "runtime-demo",
    },
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=false,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(aggregate, "kind", default=""),
    "mooncode-runtime-command-feed",
  )
  assert_eq(rq_json_string(aggregate, "workspace_id", default=""), "book-demo")
  assert_eq(rq_json_string(aggregate, "workspace_name", default=""), "Demo")
  assert_eq(
    rq_json_string(aggregate, "runtime_session_id", default=""),
    "runtime-demo",
  )
  let plan = runtime_execution_plan_response(
    "session-demo",
    [command],
    [],
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=true,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(plan, "kind", default=""),
    "mooncode-runtime-consumer-execution-plan",
  )
  assert_true(rq_json_bool(plan, "native_runtime_ready", default=false))
  assert_true(rq_json_object_field(plan, "runtime_control") is Some(Object(_)))
  assert_true(
    rq_json_object_field(plan, "runtime_turn_packet") is Some(Object(_)),
  )
  assert_true(
    rq_json_object_field(plan, "runtime_supervisor") is Some(Object(_)),
  )
  let supervisor = runtime_supervisor_response(
    "session-demo",
    [command],
    [],
    [],
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=true,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(supervisor, "kind", default=""),
    "mooncode-runtime-supervisor-launch",
  )
  assert_eq(
    rq_json_string(supervisor, "session_id", default=""),
    "session-demo",
  )
  assert_eq(rq_json_string(supervisor, "command_id", default=""), "cmd-1")
  assert_true(rq_json_bool(supervisor, "ready_to_launch", default=false))
  assert_true(
    rq_json_object_field(supervisor, "runtime_consumer") is Some(Object(_)),
  )
  assert_true(rq_json_object_field(supervisor, "readiness") is Some(Object(_)))
  assert_eq(rq_json_array_items(response, "decode_reports").length(), 1)
  assert_eq(rq_json_array_items(response, "execution_summaries").length(), 1)
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(response, "owner"),
      "standalone_component",
      default="",
    ),
    "mooncode",
  )
}

///|
test "mooncode derives runtime response metadata from session records" {
  let command : Json = {
    "protocol": protocol_version(),
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-1",
    "action": "prompt",
    "control": "prompt",
    "code_command": "prompt",
    "mooncode_command": { "command": "prompt", "text": "build it" },
  }
  let session : Json = {
    "id": "session-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
    "mooncode_runtime_session_id": "runtime-demo",
  }
  let replay = runtime_replay_state_for_session(
    session,
    [command],
    [],
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(rq_json_string(replay, "session_id", default=""), "session-demo")
  assert_eq(rq_json_string(replay, "workspace_id", default=""), "book-demo")
  assert_eq(rq_json_string(replay, "workspace_name", default=""), "Demo")
  assert_eq(
    rq_json_string(replay, "runtime_session_id", default=""),
    "runtime-demo",
  )
  let claim = runtime_claim_state_for_session(
    session,
    [command],
    [],
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(rq_json_string(claim, "session_id", default=""), "session-demo")
  assert_eq(rq_json_int(claim, "claimable_command_count", default=0), 1)
  let plan = runtime_execution_plan_response_for_session(
    session,
    [command],
    [],
    [],
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=true,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(plan, "kind", default=""),
    "mooncode-runtime-consumer-execution-plan",
  )
  assert_true(rq_json_bool(plan, "native_runtime_ready", default=false))
  let supervisor = runtime_supervisor_response_for_session(
    session,
    [command],
    [],
    [],
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
    workspace_root="/tmp/book",
    moonclaw_root="/tmp/moonclaw",
    host_base_url="",
    native_ready=true,
    lease_now="2026-06-15T00:00:00Z",
  )
  assert_eq(
    rq_json_string(supervisor, "kind", default=""),
    "mooncode-runtime-supervisor-launch",
  )
  assert_eq(
    rq_json_string(supervisor, "session_id", default=""),
    "session-demo",
  )
  assert_eq(
    rq_json_string(supervisor, "workspace_root", default=""),
    "/tmp/book",
  )
}

///|
test "mooncode runtime queue exports pending replay state" {
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-1",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "target": "tools/demo",
      "mooncode_command": { "command": "prompt", "text": "build it" },
    },
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-2",
      "action": "steer",
      "control": "steer",
      "code_command": "steer",
      "target": "tools/demo",
      "mooncode_command": { "command": "steer", "text": "add tests" },
      "tool_authorization": {
        "kind": "mooncode-tool-authorization-snapshot",
        "protocol": protocol_version(),
        "enforcement_state": "authorized",
        "runtime_may_execute": true,
        "pending_approval_count": 0,
      },
    },
  ]
  let receipts : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": kind_runtime_receipt(),
      "command_id": "cmd-1",
      "status": "runtime-completed",
    },
  ]
  let state = runtime_replay_state(
    "session-demo",
    commands,
    receipts,
    workspace_id="book-demo",
    workspace_name="Demo",
    runtime_session_id="runtime-demo",
    runtime_command_log_path="/tmp/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/runtime-receipts.jsonl",
  )
  assert_eq(
    rq_json_string(state, "kind", default=""),
    "mooncode-runtime-replay",
  )
  assert_eq(rq_json_int(state, "delivered_command_count", default=0), 1)
  assert_eq(rq_json_int(state, "pending_command_count", default=0), 1)
  assert_true(
    rq_json_string(state, "pending_mooncode_jsonl", default="").contains(
      "\"steer\"",
    ),
  )
  let pending = rq_json_array_items(state, "pending_commands")
  let auth = rq_json_object_field_or_empty(pending[0], "tool_authorization")
  assert_eq(rq_json_string(auth, "enforcement_state", default=""), "authorized")
  assert_true(
    rq_json_bool(pending[0], "runtime_may_execute_tools", default=false),
  )
}

///|
test "mooncode runtime consumer execution plan exposes next claimable command" {
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tests",
      "session_id": "s1",
      "action": "run_tests",
      "control": "command",
      "target": "tools/demo/main.mbt",
      "context_path": "tools/demo/main.mbt",
      "mooncode_command": {
        "command": "prompt",
        "text": "Run tests for tools/demo/main.mbt",
      },
      "execution_summary": {
        "kind": "mooncode-runtime-execution-summary",
        "required_events": [
          "tool_call", "tool_result", "test_result", "runtime_finished",
        ],
        "required_outputs": ["test/build log"],
        "event_sink": "/api/mooncode/sessions/s1/runtime-events",
        "ack_sink": "/api/mooncode/sessions/s1/runtime-replay",
        "execution_checklist": [
          { "id": "claim-command", "blocking": true },
          { "id": "emit-event-test_result", "blocking": true },
        ],
        "completion_rule": "Append test_result and acknowledge completion.",
      },
      "native_mooncode_body": {
        "protocol": protocol_version(),
        "command": "run_tests",
        "session_id": "s1",
      },
    },
  ]
  let replay = runtime_replay_state(
    "s1",
    commands,
    [],
    workspace_id="book",
    workspace_name="Book",
    runtime_session_id="runtime",
    runtime_command_log_path="/tmp/book/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/book/runtime-receipts.jsonl",
  )
  let claim = runtime_claim_state(
    "s1",
    commands,
    [],
    workspace_id="book",
    workspace_name="Book",
    runtime_session_id="runtime",
    runtime_command_log_path="/tmp/book/runtime-commands.jsonl",
    runtime_receipt_log_path="/tmp/book/runtime-receipts.jsonl",
  )
  let plan = runtime_consumer_execution_plan("s1", replay, claim, false)
  assert_eq(
    json_string(plan, "kind", default=""),
    "mooncode-runtime-consumer-execution-plan",
  )
  assert_eq(json_string(plan, "status", default=""), "ready-to-claim")
  assert_eq(json_string(plan, "operation", default=""), "claim-command")
  assert_true(json_bool(plan, "ready_to_claim", default=false))
  assert_true(json_bool(plan, "ready_to_execute", default=false))
  assert_eq(json_string(plan, "command_id", default=""), "cmd-tests")
  assert_eq(json_string(plan, "action", default=""), "run_tests")
  assert_eq(rq_json_int(plan, "required_event_count", default=0), 4)
  assert_true(
    rq_json_string_array_items(plan, "required_events").contains("test_result"),
  )
  assert_eq(
    json_string(
      rq_json_object_field_or_empty(plan, "claim_request_template"),
      "command_id",
      default="",
    ),
    "cmd-tests",
  )
  assert_eq(
    json_string(
      rq_json_object_field_or_empty(plan, "mooncode_command"),
      "command",
      default="",
    ),
    "prompt",
  )
  assert_true(rq_json_array_items(plan, "execution_checklist").length() >= 2)
  assert_eq(
    rq_json_string(plan, "native_session_listing_endpoint", default=""),
    "/v1/code/sessions?book_root=<path>&format=json",
  )
  assert_eq(
    rq_json_string(plan, "native_runtime_control_endpoint", default=""),
    "/v1/code/sessions/s1/runtime-control?book_root=<path>",
  )
  assert_eq(
    rq_json_string(plan, "native_eval_report_endpoint", default=""),
    "/v1/code/sessions/s1/eval-report?book_root=<path>",
  )
  let lifecycle = runtime_command_lifecycle("s1", commands, [], [])
  let control = runtime_control_projection("s1", commands, lifecycle)
  let packet = runtime_turn_packet("s1", replay, claim, control, false)
  assert_eq(
    rq_json_string(packet, "kind", default=""),
    "mooncode-runtime-turn-packet",
  )
  assert_eq(rq_json_string(packet, "command_id", default=""), "cmd-tests")
  assert_eq(
    rq_json_string(packet, "runtime_control_effect", default=""),
    "start-turn",
  )
  assert_true(
    rq_json_bool(packet, "runtime_control_allows_turn", default=false),
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(packet, "mooncode_command"),
      "command",
      default="",
    ),
    "prompt",
  )
  assert_eq(rq_json_array_items(packet, "required_events").length(), 4)
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(packet, "endpoints"),
      "native_session_listing",
      default="",
    ),
    "/v1/code/sessions?book_root=<path>&format=json",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(packet, "endpoints"),
      "native_runtime_control",
      default="",
    ),
    "/v1/code/sessions/s1/runtime-control?book_root=<path>",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(packet, "endpoints"),
      "native_eval_report",
      default="",
    ),
    "/v1/code/sessions/s1/eval-report?book_root=<path>",
  )
  assert_true(
    rq_json_string(packet, "safety_boundary", default="").contains(
      "Moondesk does not execute",
    ),
  )
  let supervisor = runtime_supervisor_launch_packet(
    "s1",
    packet,
    runtime_consumer_handoff("s1", replay, claim, false),
    workspace_root="/tmp/book",
    moonclaw_root="/opt/moonclaw",
    host_base_url="http://127.0.0.1:4304",
    false,
  )
  assert_eq(
    rq_json_string(supervisor, "kind", default=""),
    "mooncode-runtime-supervisor-launch",
  )
  assert_true(rq_json_bool(supervisor, "ready_to_launch", default=false))
  assert_eq(
    rq_json_string(supervisor, "mode", default=""),
    "moondesk-command-replay",
  )
  assert_eq(rq_json_string(supervisor, "command_id", default=""), "cmd-tests")
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(supervisor, "endpoints"),
      "claim",
      default="",
    ),
    "http://127.0.0.1:4304/api/mooncode/sessions/s1/runtime-claim",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(supervisor, "endpoints"),
      "readiness",
      default="",
    ),
    "http://127.0.0.1:4304/api/mooncode/sessions/s1/readiness",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(supervisor, "endpoints"),
      "native_session_listing",
      default="",
    ),
    "http://127.0.0.1:4304/v1/code/sessions?book_root=<path>&format=json",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(supervisor, "endpoints"),
      "native_runtime_control",
      default="",
    ),
    "http://127.0.0.1:4304/v1/code/sessions/s1/runtime-control?book_root=<path>",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(supervisor, "endpoints"),
      "native_eval_report",
      default="",
    ),
    "http://127.0.0.1:4304/v1/code/sessions/s1/eval-report?book_root=<path>",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(supervisor, "launch_request"),
      "command_id",
      default="",
    ),
    "cmd-tests",
  )
  assert_eq(rq_json_array_items(supervisor, "supervisor_loop").length(), 7)
  let loop_steps = rq_json_array_items(supervisor, "supervisor_loop")
  assert_eq(rq_json_string(loop_steps[6], "id", default=""), "check-readiness")
  assert_eq(rq_json_string(loop_steps[6], "method", default=""), "GET")
  let readiness = rq_json_object_field_or_empty(supervisor, "readiness")
  assert_eq(
    rq_json_string(readiness, "kind", default=""),
    "mooncode-runtime-supervisor-readiness",
  )
  assert_true(rq_json_bool(readiness, "ok", default=false))
  assert_eq(rq_json_string(readiness, "status", default=""), "launch-ready")
  assert_eq(rq_json_int(readiness, "missing_requirement_count", default=-1), 0)
  assert_true(rq_json_bool(readiness, "endpoint_ready", default=false))
  assert_true(rq_json_bool(readiness, "launch_request_ready", default=false))
  assert_true(rq_json_bool(readiness, "supervisor_loop_ready", default=false))
  assert_true(
    rq_json_string(supervisor, "safety_boundary", default="").contains(
      "declarative",
    ),
  )
}

///|
test "mooncode runtime supervisor launch explains idle state" {
  let packet : Json = {
    "kind": kind_runtime_turn_packet(),
    "protocol": protocol_version(),
    "session_id": "s1",
    "status": "idle",
    "operation": "wait",
    "command_id": "",
    "action": "",
    "ready_to_execute": false,
    "runtime_control_allows_turn": false,
    "endpoints": {},
  }
  let supervisor = runtime_supervisor_launch_packet(
    "s1",
    packet,
    Json::object({}),
    workspace_root="/tmp/book",
    moonclaw_root="",
    host_base_url="",
    true,
  )
  assert_eq(
    rq_json_string(supervisor, "mode", default=""),
    "native-mooncode-runtime",
  )
  assert_false(rq_json_bool(supervisor, "ready_to_launch", default=true))
  assert_eq(
    rq_json_string(supervisor, "launch_blocked_reason", default=""),
    "no runtime command is ready for execution",
  )
  assert_true(
    rq_json_string(supervisor, "standalone_component", default="").contains(
      "mooncode",
    ),
  )
  let readiness = rq_json_object_field_or_empty(supervisor, "readiness")
  assert_false(rq_json_bool(readiness, "ok", default=true))
  assert_eq(rq_json_string(readiness, "status", default=""), "blocked")
  assert_true(
    rq_json_string_array_items(readiness, "missing_requirements").contains(
      "command_id",
    ),
  )
  assert_true(
    rq_json_string_array_items(readiness, "missing_requirements").contains(
      "endpoint.claim",
    ),
  )
  assert_true(
    rq_json_string_array_items(readiness, "missing_requirements").contains(
      "endpoint.native_session_listing",
    ),
  )
  assert_true(
    rq_json_string_array_items(readiness, "missing_requirements").contains(
      "endpoint.native_runtime_control",
    ),
  )
  assert_true(
    rq_json_string(readiness, "safety_boundary", default="").contains(
      "does not mean Moondesk may execute tools",
    ),
  )
}

///|
test "mooncode runtime consumer handoff reports claim readiness" {
  let handoff = runtime_consumer_handoff(
    "s1",
    {
      "kind": "mooncode-runtime-replay-state",
      "pending_command_count": 1,
      "replay_ready": true,
    },
    {
      "kind": "mooncode-runtime-claim-state",
      "claimable_command_count": 1,
      "claimed_command_count": 0,
      "delivered_command_count": 0,
      "invalid_command_count": 0,
    },
    false,
  )
  assert_eq(
    rq_json_string(handoff, "kind", default=""),
    "mooncode-runtime-consumer-handoff",
  )
  assert_eq(rq_json_string(handoff, "status", default=""), "claim-ready")
  assert_true(rq_json_bool(handoff, "ready_to_claim", default=false))
  assert_true(rq_json_bool(handoff, "ready_to_replay", default=false))
  assert_true(
    rq_json_string(handoff, "next_action", default="").contains("runtime-claim"),
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(handoff, "endpoints"),
      "native_runtime_control",
      default="",
    ),
    "/v1/code/sessions/s1/runtime-control?book_root=<path>",
  )
  assert_eq(
    rq_json_string(
      rq_json_object_field_or_empty(handoff, "endpoints"),
      "native_session_listing",
      default="",
    ),
    "/v1/code/sessions?book_root=<path>&format=json",
  )
}

///|
test "mooncode runtime command lifecycle summarizes queue state" {
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-tests",
      "session_id": "session-demo",
      "action": "run_tests",
      "control": "command",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "run tests" },
      "tool_authorization": {
        "enforcement_state": "approved",
        "runtime_may_execute": true,
      },
    },
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-package",
      "session_id": "session-demo",
      "action": "package",
      "control": "command",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "package" },
      "tool_authorization": {
        "enforcement_state": "approved",
        "runtime_may_execute": true,
      },
    },
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-shell",
      "session_id": "session-demo",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "run shell" },
      "tool_authorization": {
        "enforcement_state": "requires-approval",
        "runtime_may_execute": false,
        "pending_approval_count": 1,
      },
    },
  ]
  let receipts : Array[Json] = [
    {
      "kind": kind_runtime_receipt(),
      "command_id": "cmd-tests",
      "status": "runtime-completed",
    },
    {
      "kind": kind_runtime_receipt(),
      "command_id": "cmd-package",
      "status": "runtime-claimed",
      "consumer_id": "moonclaw-runtime",
      "lease_expires_at": "2026-06-15T01:00:00Z",
    },
  ]
  let events : Array[Json] = [
    {
      "id": "evt-tests",
      "lane": "test",
      "kind": "test_result",
      "title": "Tests passed",
      "status": "done",
      "command_packet": { "command_id": "cmd-tests", "action": "run_tests" },
    },
    {
      "id": "evt-package",
      "lane": "artifact",
      "kind": "runtime.package_built",
      "title": "Package building",
      "status": "running",
      "command_packet": { "command_id": "cmd-package", "action": "package" },
    },
  ]
  let lifecycle = runtime_command_lifecycle(
    "session-demo",
    commands,
    receipts,
    events,
    lease_now="2026-06-15T00:30:00Z",
  )
  assert_eq(
    rq_json_string(lifecycle, "kind", default=""),
    "mooncode-runtime-command-lifecycle",
  )
  assert_eq(rq_json_int(lifecycle, "command_count", default=0), 3)
  assert_eq(rq_json_int(lifecycle, "completed_count", default=0), 1)
  assert_eq(rq_json_int(lifecycle, "running_count", default=0), 1)
  assert_eq(rq_json_int(lifecycle, "blocked_count", default=0), 1)
  assert_eq(rq_json_int(lifecycle, "scoped_event_count", default=0), 2)
  assert_eq(
    rq_json_string(lifecycle, "next_command_id", default=""),
    "cmd-package",
  )
  let rows = rq_json_array_items(lifecycle, "commands")
  assert_eq(rq_json_string(rows[0], "status", default=""), "completed")
  assert_eq(rq_json_int(rows[0], "proof_event_count", default=0), 1)
  assert_eq(rq_json_string(rows[1], "status", default=""), "running")
  assert_eq(
    rq_json_string(rows[2], "status", default=""),
    "blocked-tool-authorization",
  )
  assert_true(
    rq_json_string(rows[2], "blocking_reason", default="").contains("pending"),
  )
}

///|
test "mooncode runtime command lifecycle completes native terminal events" {
  let commands : Array[Json] = [
    {
      "protocol": protocol_version(),
      "kind": "mooncode.runtime-command",
      "command_id": "cmd-native",
      "session_id": "session-demo",
      "action": "prompt",
      "control": "prompt",
      "code_command": "prompt",
      "mooncode_command": { "command": "prompt", "text": "say ok" },
      "tool_authorization": {
        "enforcement_state": "approved",
        "runtime_may_execute": true,
      },
    },
  ]
  let receipts : Array[Json] = [
    {
      "kind": kind_runtime_receipt(),
      "command_id": "cmd-native",
      "status": "runtime-accepted",
    },
  ]
  let events : Array[Json] = [
    {
      "id": "native-started",
      "lane": "runtime",
      "kind": event_runtime_turn_started(),
      "title": "Native runtime turn started",
      "status": "running",
      "command_id": "cmd-native",
    },
    {
      "id": "native-finished",
      "lane": "runtime",
      "kind": event_runtime_turn_finished(),
      "title": "Native runtime turn completed",
      "status": "done",
      "command_id": "cmd-native",
    },
  ]
  let lifecycle = runtime_command_lifecycle(
    "session-demo",
    commands,
    receipts,
    events,
    lease_now="2026-06-15T00:30:00Z",
  )
  assert_eq(rq_json_int(lifecycle, "completed_count", default=0), 1)
  assert_eq(rq_json_int(lifecycle, "runtime_started_count", default=0), 0)
  assert_eq(rq_json_string(lifecycle, "next_command_id", default=""), "")
  let rows = rq_json_array_items(lifecycle, "commands")
  assert_eq(rq_json_string(rows[0], "status", default=""), "completed")
  assert_eq(rq_json_int(rows[0], "terminal_event_count", default=0), 1)
  assert_eq(rq_json_int(rows[0], "scoped_event_count", default=0), 2)
}
