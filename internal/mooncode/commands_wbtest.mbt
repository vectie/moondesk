///|
// MoonCode command packet and native command contract tests.

///|
fn command_checklist_contains_id(checklist : Array[Json], id : String) -> Bool {
  for step in checklist {
    if json_string(step, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn command_checklist_contains_id_prefix(
  checklist : Array[Json],
  prefix : String,
) -> Bool {
  for step in checklist {
    if json_string(step, "id", default="").has_prefix(prefix) {
      return true
    }
  }
  false
}

///|
fn command_policy_has_guardrail(
  policies : Array[Json],
  tool : String,
  phrase : String,
) -> Bool {
  for policy in policies {
    if json_string(policy, "tool", default="") == tool {
      for guardrail in command_json_string_array_items(policy, "guardrails") {
        if guardrail.contains(phrase) {
          return true
        }
      }
    }
  }
  false
}

///|
test "mooncode command metadata captures runtime dispatch and approval" {
  assert_true(command_is_supported("prompt"))
  assert_true(command_is_supported("run_build"))
  assert_true(command_is_supported("run_eval"))
  assert_true(command_is_supported("commit"))
  assert_false(command_is_supported("deploy_global"))
  assert_eq(command_dispatch("prompt"), "prompt")
  assert_eq(command_dispatch("steer"), "steer")
  assert_eq(command_dispatch("cancel"), "cancel")
  assert_eq(command_dispatch("package"), "command")
  assert_eq(command_dispatch("commit"), "command")
  assert_eq(command_approval("package"), "operator")
  assert_eq(command_approval("commit"), "operator")
  assert_eq(command_approval("run_build"), "auto")
  assert_eq(command_approval("run_eval"), "auto")
  assert_eq(command_approval("prompt"), "user")
}

///|
test "mooncode command defaults are book coding oriented" {
  let payload : Json = {
    "action": " run_tests ",
    "context_path": "tools/demo/main.mbt",
  }
  assert_eq(command_action(payload), "run_tests")
  assert_eq(command_context_path(payload), "tools/demo/main.mbt")
  assert_eq(command_target_label(payload), "`tools/demo/main.mbt`")
  assert_true(
    command_message("run_tests", payload).contains(
      "Run the relevant tests or build checks",
    ),
  )
  assert_true(
    command_message("run_build", payload).contains(
      "Run the relevant build checks",
    ),
  )
  let explicit : Json = { "message": "Use the local harness." }
  assert_eq(command_message("prompt", explicit), "Use the local harness.")
}

///|
test "mooncode command packet and runtime feed preserve execution boundary" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "moonclaw_task_id": "task-demo",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "package_kind": "miniapp",
    "web_search": false,
  }
  let packet = command_packet(
    session,
    payload,
    "package",
    "Package it",
    "2026-06-14T00:00:00Z",
    "tools/demo/main.mbt",
    command_id="cmd-package",
  )
  assert_eq(json_string(packet, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(packet, "approval", default=""), "operator")
  assert_true(
    command_json_string_array_items(packet, "tool_hints").contains(
      "package_app_tool",
    ),
  )
  assert_true(
    command_runtime_message("Package it", packet).contains(
      "MoonCode command packet",
    ),
  )
  let command = runtime_command_record(session, payload, "Package it", packet)
  assert_true(json_bool(command, "openseek_wire_valid", default=false))
  let summary = command_json_object_field_or_empty(command, "execution_summary")
  assert_eq(
    json_string(summary, "kind", default=""),
    "mooncode-runtime-execution-summary",
  )
  assert_eq(json_string(summary, "action", default=""), "package")
  assert_eq(json_string(summary, "package_kind", default=""), "miniapp")
  assert_true(
    command_json_string_array_items(summary, "tool_sequence").contains(
      "package_app_tool",
    ),
  )
  assert_true(command_json_int(summary, "tool_policy_count", default=0) > 0)
  assert_true(
    command_policy_has_guardrail(
      json_array_items(summary, "tool_policies"),
      "package_app_tool",
      "runtime-proven",
    ),
  )
  let native = command_json_object_field_or_empty(
    command, "native_mooncode_body",
  )
  let plan = command_json_object_field_or_empty(native, "execution_plan")
  assert_true(json_bool(plan, "review_required", default=false))
  assert_true(
    command_policy_has_guardrail(
      json_array_items(plan, "tool_policies"),
      "moon_check",
      "bounded diagnostics",
    ),
  )
  let result_contract = command_json_object_field_or_empty(
    native, "result_contract",
  )
  assert_true(
    json_string(result_contract, "ack_sink", default="").contains(
      "/runtime-replay",
    ),
  )
  let checklist = json_array_items(result_contract, "execution_checklist")
  assert_true(checklist.length() >= 4)
  assert_eq(json_string(checklist[0], "id", default=""), "claim-command")
  assert_true(
    command_checklist_contains_id_prefix(checklist, "emit-event-package.index"),
  )
  assert_true(command_checklist_contains_id(checklist, "ack-command"))
}

///|
test "mooncode projected command packet owns stable command ids" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_root": "/tmp/demo-book",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "web_search": true,
  }
  let first = projected_command_packet(
    session, payload, "prompt", "Build a miniapp", "2026-06-16T00:00:00Z", "tools/demo/main.mbt",
  )
  let second = projected_command_packet(
    session, payload, "prompt", "Build a miniapp", "2026-06-16T00:00:00Z", "tools/demo/main.mbt",
  )
  assert_eq(
    json_string(first, "command_id", default=""),
    json_string(second, "command_id", default=""),
  )
  assert_true(
    json_string(first, "command_id", default="").has_prefix("mooncode-command-"),
  )
  assert_eq(json_string(first, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(first, "action", default=""), "prompt")
  assert_true(json_bool(first, "web_search", default=false))
}

///|
test "mooncode command model reaches runtime and native body" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_root": "/tmp/demo-book",
    "model": "session-model",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "model": "payload-model",
  }
  let packet = projected_command_packet(
    session, payload, "prompt", "Build a tool", "2026-06-17T00:00:00Z", "tools/demo/main.mbt",
  )
  assert_eq(json_string(packet, "model", default=""), "payload-model")
  let runtime = runtime_command_record(session, payload, "Build a tool", packet)
  assert_eq(json_string(runtime, "model", default=""), "payload-model")
  let native = command_json_object_field_or_empty(
    runtime, "native_mooncode_body",
  )
  assert_eq(json_string(native, "model", default=""), "payload-model")
  let native_packet = command_json_object_field_or_empty(native, "packet")
  assert_eq(json_string(native_packet, "model", default=""), "payload-model")
}

///|
test "mooncode command model falls back to session model" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_root": "/tmp/demo-book",
    "model": "session-model",
  }
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  let packet = projected_command_packet(
    session, payload, "prompt", "Build a tool", "2026-06-17T00:00:00Z", "tools/demo/main.mbt",
  )
  assert_eq(json_string(packet, "model", default=""), "session-model")
  let runtime = runtime_command_record(session, payload, "Build a tool", packet)
  assert_eq(json_string(runtime, "model", default=""), "session-model")
  let native = command_json_object_field_or_empty(
    runtime, "native_mooncode_body",
  )
  assert_eq(json_string(native, "model", default=""), "session-model")
}

///|
test "mooncode command queue response owns queue surface" {
  let command : Json = {
    "protocol": protocol_version(),
    "kind": kind_command(),
    "command_id": "cmd-1",
    "action": "prompt",
  }
  let response = command_queue_response(
    "session-demo",
    [command],
    workspace_id="book-demo",
    workspace_name="Demo Book",
    task_id="task-demo",
    command_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/commands.jsonl",
  )
  assert_eq(json_string(response, "kind", default=""), "mooncode-command-queue")
  assert_eq(json_string(response, "session_id", default=""), "session-demo")
  assert_eq(
    json_string(response, "command_log_path", default=""),
    "/tmp/book/.moontown/mooncode-sessions/session-demo/commands.jsonl",
  )
  assert_eq(command_json_int(response, "command_count", default=0), 1)
  assert_eq(json_array_items(response, "commands").length(), 1)
  assert_eq(
    json_string(
      command_json_object_field_or_empty(response, "owner"),
      "extractable_component",
      default="",
    ),
    "mooncode",
  )
  let aggregate = command_queue_result_response(
    "session-demo",
    [command],
    {
      "id": "session-demo",
      "workspace_id": "book-demo",
      "workspace_name": "Demo Book",
      "moonclaw_task_id": "task-demo",
    },
    command_log_path="/tmp/book/.moontown/mooncode-sessions/session-demo/commands.jsonl",
  )
  assert_eq(json_string(aggregate, "workspace_id", default=""), "book-demo")
  assert_eq(json_string(aggregate, "workspace_name", default=""), "Demo Book")
  assert_eq(json_string(aggregate, "task_id", default=""), "task-demo")
}

///|
test "mooncode runtime commands carry tool authorization snapshots" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "mooncode_last_tool_approvals_manifest": {
      "kind": "mooncode-tool-approvals",
      "protocol": protocol_version(),
      "status": "pending",
      "manifest_path": "wiki/reviews/mooncode/agent-demo/tool-approvals.json",
      "approval_count": 1,
      "pending_approval_count": 1,
      "approved_approval_count": 0,
      "rejected_approval_count": 0,
      "approvals": [
        {
          "target": "moon test",
          "tool_name": "shell",
          "approval_state": "pending",
        },
      ],
    },
  }
  let payload : Json = {
    "action": "run_tests",
    "context_path": "tools/demo/main.mbt",
  }
  let packet = command_packet(
    session,
    payload,
    "run_tests",
    "Run tests",
    "2026-06-15T00:00:00Z",
    "tools/demo/main.mbt",
    command_id="cmd-tests",
  )
  let command = runtime_command_record(session, payload, "Run tests", packet)
  let auth = command_json_object_field_or_empty(command, "tool_authorization")
  assert_eq(
    json_string(auth, "kind", default=""),
    "mooncode-tool-authorization-snapshot",
  )
  assert_eq(
    json_string(auth, "enforcement_state", default=""),
    "requires-approval",
  )
  assert_false(json_bool(auth, "runtime_may_execute", default=true))
  assert_eq(command_json_int(auth, "pending_approval_count", default=0), 1)
  let native = command_json_object_field_or_empty(
    command, "native_mooncode_body",
  )
  let native_tool_contract = command_json_object_field_or_empty(
    native, "tool_contract",
  )
  assert_true(
    command_policy_has_guardrail(
      json_array_items(native_tool_contract, "tool_policies"),
      "shell",
      "argv arrays",
    ),
  )
  let native_auth = command_json_object_field_or_empty(
    native, "tool_authorization",
  )
  assert_eq(
    json_string(native_auth, "manifest_path", default=""),
    "wiki/reviews/mooncode/agent-demo/tool-approvals.json",
  )
  let summary = command_json_object_field_or_empty(command, "execution_summary")
  assert_eq(
    json_string(summary, "tool_authorization_state", default=""),
    "requires-approval",
  )
  assert_false(json_bool(summary, "runtime_may_execute_tools", default=true))
}

///|
test "mooncode command event is reusable outside moonwiki" {
  let packet : Json = { "command_id": "cmd-1", "action": "run_tests" }
  let event = command_event(
    action="run_tests",
    status="queued",
    detail="Run tests",
    created_at="2026-06-15T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet=packet,
    event_id="cmd-1",
  )
  assert_eq(json_string(event, "lane", default=""), "test")
  assert_eq(json_string(event, "kind", default=""), "command.run_tests")
  assert_eq(json_string(event, "command", default=""), "run_tests")
  assert_eq(
    json_string(
      command_json_object_field_or_empty(event, "command_packet"),
      "command_id",
      default="",
    ),
    "cmd-1",
  )
}

///|
test "mooncode command metadata exposes tool and lane contracts" {
  assert_true(command_tool_hints("run_eval").contains("eval_harness"))
  assert_true(command_tool_hints("run_build").contains("moon_cmd"))
  assert_true(command_tool_hints("prompt").contains("edit"))
  assert_true(command_expected_lanes("prompt").contains("diff"))
  assert_true(command_expected_lanes("package").contains("artifact"))
  assert_true(command_expected_lanes("commit").contains("review"))
  assert_eq(command_lane("run_build"), "test")
  assert_eq(command_lane("run_tests"), "test")
  assert_eq(command_lane("accept"), "review")
  assert_eq(command_lane("commit"), "review")
  assert_eq(command_title("apply_patch", "queued"), "Apply patch: queued")
  assert_eq(command_title("commit", "queued"), "Commit result: queued")
  assert_true(
    native_command_expected_events("apply_patch").contains("patch_applied"),
  )
  assert_true(
    native_command_expected_events("revert_patch").contains("patch_reverted"),
  )
  assert_true(
    native_command_tool_sequence("apply_patch").contains("apply_patch"),
  )
  assert_false(native_command_tool_sequence("apply_patch").contains("edit"))
  assert_true(
    native_command_required_outputs("apply_patch").contains(
      "patch_applied proof event",
    ),
  )
  assert_true(
    native_command_required_outputs("apply_patch").contains(
      "selected-hunk proof metadata",
    ),
  )
  assert_true(
    native_command_expected_events("package").contains("package_verified"),
  )
  assert_true(
    native_command_required_outputs("package").contains(
      "package_verified proof event",
    ),
  )
  assert_true(
    native_command_expected_events("commit").contains("commit_created"),
  )
  assert_true(
    native_command_required_outputs("commit").contains(
      "commit_created proof event",
    ),
  )
}

///|
test "mooncode native command tool policies expose OpenSeek style guardrails" {
  let prompt_policies = native_command_tool_policies(
    "prompt", "tools/demo/main.mbt",
  )
  assert_true(
    command_policy_has_guardrail(
      prompt_policies, "moon_ide", "semantic discovery",
    ),
  )
  assert_true(
    command_policy_has_guardrail(
      prompt_policies, "moon_cmd", "selected moon commands",
    ),
  )
  assert_true(
    command_policy_has_guardrail(prompt_policies, "edit", "recent bounded read"),
  )
  assert_true(
    command_policy_has_guardrail(prompt_policies, "write", "moon.mod.json"),
  )
  let shell = native_command_tool_policy(
    "shell", "run_tests", "tools/demo/main.mbt",
  )
  assert_eq(json_string(shell, "approval", default=""), "policy")
  assert_false(json_bool(shell, "mutates_files", default=true))
  assert_true(
    command_json_string_array_items(shell, "proof_events").contains(
      "runtime_update",
    ),
  )
  let package_policies = native_command_tool_policies(
    "package", "tools/demo/main.mbt",
  )
  assert_true(
    command_policy_has_guardrail(
      package_policies, "package_app_tool", "runtime-proven",
    ),
  )
  let sequence = native_command_tool_sequence("run_tests")
  assert_true(sequence.contains("moon_ide"))
  assert_true(sequence.contains("moon_cmd"))
  assert_true(sequence.contains("moon_check"))
  let build_sequence = native_command_tool_sequence("run_build")
  assert_true(build_sequence.contains("moon_cmd"))
  assert_true(build_sequence.contains("moon_check"))
  assert_true(
    native_command_expected_events("run_build").contains("test_result"),
  )
  assert_true(
    native_command_required_outputs("run_build").contains("build command"),
  )
  assert_true(
    native_command_recommended_commands("run_build", "tools/demo/main.mbt").contains(
      "moon build",
    ),
  )
}
