///|
pub fn runtime_consumer_expected_tool_sequence(
  runtime_command : Json,
) -> Array[String] {
  let summary = rq_json_object_field_or_empty(
    runtime_command, "execution_summary",
  )
  let from_summary = rq_json_string_array_items(summary, "tool_sequence")
  if from_summary.length() > 0 {
    from_summary
  } else {
    native_command_tool_sequence(
      rq_json_string(runtime_command, "action", default="prompt"),
    )
  }
}

///|
pub fn runtime_consumer_tool_outcome(
  tool : String,
  call_id? : String = "",
  arguments? : String = "",
  content? : String = "",
  path? : String = "",
  command? : String = "",
  exit_code? : Int = 0,
  is_error? : Bool = false,
) -> Json {
  {
    "tool": tool,
    "tool_call_id": if call_id == "" {
      "call-\{tool}"
    } else {
      call_id
    },
    "arguments": arguments,
    "content": content,
    "path": path,
    "command": command,
    "exit_code": exit_code,
    "is_error": is_error,
  }
}

///|
pub fn runtime_consumer_test_result_event(
  command? : String = "",
  status? : String = "done",
  exit_code? : Int = 0,
  detail? : String = "",
) -> Json {
  {
    "event": "test_result",
    "command": command,
    "status": status,
    "exit_code": exit_code,
    "detail": detail,
  }
}

///|
pub fn runtime_consumer_artifact_event(
  path : String,
  detail? : String = "",
) -> Json {
  { "event": "artifact", "path": path, "detail": detail }
}

///|
pub fn runtime_consumer_package_verified_event(
  path : String,
  detail? : String = "",
) -> Json {
  { "event": "package_verified", "path": path, "detail": detail }
}

///|
pub fn runtime_consumer_package_manifest_event(
  path : String,
  detail? : String = "",
) -> Json {
  { "event": "package_manifest", "path": path, "detail": detail }
}

///|
pub fn runtime_consumer_package_index_event(
  path : String,
  detail? : String = "",
) -> Json {
  { "event": "package_index", "path": path, "detail": detail }
}

///|
pub fn runtime_consumer_commit_created_event(
  sha : String,
  detail? : String = "",
) -> Json {
  { "event": "commit_created", "sha": sha, "detail": detail }
}

///|
pub fn runtime_consumer_package_output_ack(
  runtime_command : Json,
  source_path : String,
  output_path : String,
  manifest_path : String,
  index_path : String,
  package_kind? : String = "app-tool",
  check_command? : String = "moon check",
  test_command? : String = "moon test",
  consumer_id? : String = "mooncode-runtime",
  acknowledged_at? : String = "",
) -> Json {
  let package_args = (
    { "source": source_path, "output": output_path, "kind": package_kind } :
    Json).stringify()
  runtime_consumer_completion_ack(
    runtime_command,
    [
      runtime_consumer_tool_outcome(
        "read",
        call_id="call-read-package-source",
        arguments=({ "path": source_path } : Json).stringify(),
        content="source inventory recorded for \{source_path}",
        path=source_path,
      ),
      runtime_consumer_tool_outcome(
        "moon_check",
        call_id="call-package-check",
        arguments=({ "command": check_command } : Json).stringify(),
        content="\{check_command} passed",
        command=check_command,
      ),
      runtime_consumer_tool_outcome(
        "shell",
        call_id="call-package-test",
        arguments=({ "command": test_command } : Json).stringify(),
        content="\{test_command} passed",
        command=test_command,
      ),
      runtime_consumer_tool_outcome(
        "package_app_tool",
        call_id="call-package-app-tool",
        arguments=package_args,
        content="packaged \{source_path} into \{output_path}",
        path=output_path,
      ),
      runtime_consumer_tool_outcome(
        "finish",
        content="Packaged \{package_kind} output at \{output_path}.",
      ),
    ],
    [
      {
        "event": "diff",
        "path": output_path,
        "detail": "Packaged executable MoonBook output for \{source_path}.",
      },
      runtime_consumer_test_result_event(
        command=test_command,
        exit_code=0,
        detail="\{test_command} passed",
      ),
      runtime_consumer_artifact_event(
        output_path,
        detail="Packaged \{package_kind} artifact",
      ),
      runtime_consumer_package_manifest_event(
        manifest_path,
        detail="Package manifest for \{output_path}",
      ),
      runtime_consumer_package_index_event(
        index_path,
        detail="Package index includes \{output_path}",
      ),
      runtime_consumer_package_verified_event(
        output_path,
        detail="Package verification passed",
      ),
    ],
    consumer_id~,
    acknowledged_at~,
    detail="Runtime consumer packaged executable MoonBook output with typed proof.",
  )
}

///|
pub fn runtime_consumer_completion_ack(
  runtime_command : Json,
  tool_outcomes : Array[Json],
  proof_events : Array[Json],
  consumer_id? : String = "mooncode-runtime",
  acknowledged_at? : String = "",
  status? : String = "runtime-completed",
  detail? : String = "Runtime consumer completed command with typed tool proof.",
) -> Json {
  {
    "consumer_id": consumer_id,
    "command_id": rq_json_string(runtime_command, "command_id", default=""),
    "status": status,
    "detail": detail,
    "acknowledged_at": acknowledged_at,
    "events": Json::array(
      runtime_consumer_ack_events(
        runtime_command,
        tool_outcomes,
        proof_events,
        acknowledged_at~,
      ),
    ),
  }
}

///|
pub fn runtime_consumer_ack_events(
  runtime_command : Json,
  tool_outcomes : Array[Json],
  proof_events : Array[Json],
  acknowledged_at? : String = "",
) -> Array[Json] {
  let events : Array[Json] = []
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let action = rq_json_string(runtime_command, "action", default="prompt")
  let mut index = 0
  for tool in runtime_consumer_expected_tool_sequence(runtime_command) {
    let outcome = runtime_consumer_outcome_for_tool(tool, tool_outcomes)
    if rq_json_string(outcome, "tool", default="") == "" {
      events.push(
        runtime_consumer_tool_missing_event(
          command_id, action, tool, index, acknowledged_at,
        ),
      )
    } else if tool == "finish" {
      events.push(
        runtime_consumer_finish_event(
          runtime_command, outcome, index, acknowledged_at,
        ),
      )
    } else {
      events.push(
        runtime_consumer_tool_call_event(
          runtime_command, outcome, index, acknowledged_at,
        ),
      )
      events.push(
        runtime_consumer_tool_result_event(
          runtime_command, outcome, index, acknowledged_at,
        ),
      )
    }
    index += 1
  }
  for event in proof_events {
    events.push(runtime_consumer_scoped_raw_event(runtime_command, event))
  }
  events
}

///|
fn runtime_consumer_outcome_for_tool(
  tool : String,
  outcomes : Array[Json],
) -> Json {
  for outcome in outcomes {
    if rq_json_string(outcome, "tool", default="") == tool {
      return outcome
    }
  }
  Json::object({})
}

///|
fn runtime_consumer_tool_call_event(
  runtime_command : Json,
  outcome : Json,
  index : Int,
  acknowledged_at : String,
) -> Json {
  runtime_consumer_scoped_raw_event(runtime_command, {
    "event": "tool_call",
    "id": runtime_consumer_event_id(runtime_command, "tool-call", index),
    "created_at": acknowledged_at,
    "tool_name": rq_json_string(outcome, "tool", default=""),
    "tool_call_id": rq_json_string(outcome, "tool_call_id", default=""),
    "arguments": rq_json_string(outcome, "arguments", default=""),
    "path": rq_json_string(outcome, "path", default=""),
    "command": rq_json_string(outcome, "command", default=""),
    "status": "running",
  })
}

///|
fn runtime_consumer_tool_result_event(
  runtime_command : Json,
  outcome : Json,
  index : Int,
  acknowledged_at : String,
) -> Json {
  runtime_consumer_scoped_raw_event(runtime_command, {
    "event": "tool_result",
    "id": runtime_consumer_event_id(runtime_command, "tool-result", index),
    "created_at": acknowledged_at,
    "tool_name": rq_json_string(outcome, "tool", default=""),
    "tool_call_id": rq_json_string(outcome, "tool_call_id", default=""),
    "arguments": rq_json_string(outcome, "arguments", default=""),
    "content": rq_json_string(outcome, "content", default=""),
    "path": rq_json_string(outcome, "path", default=""),
    "command": rq_json_string(outcome, "command", default=""),
    "exit_code": rq_json_int(outcome, "exit_code", default=0),
    "is_error": rq_json_bool(outcome, "is_error", default=false),
  })
}

///|
fn runtime_consumer_finish_event(
  runtime_command : Json,
  outcome : Json,
  index : Int,
  acknowledged_at : String,
) -> Json {
  runtime_consumer_scoped_raw_event(runtime_command, {
    "event": "agent_finished",
    "id": runtime_consumer_event_id(runtime_command, "finish", index),
    "created_at": acknowledged_at,
    "answer": if rq_json_string(outcome, "content", default="") == "" {
      "Runtime command finished."
    } else {
      rq_json_string(outcome, "content", default="")
    },
  })
}

///|
fn runtime_consumer_tool_missing_event(
  command_id : String,
  action : String,
  tool : String,
  index : Int,
  acknowledged_at : String,
) -> Json {
  {
    "event": "tool_call_decode_error",
    "id": "\{command_id}:missing-tool:\{index}",
    "created_at": acknowledged_at,
    "tool_name": tool,
    "tool_call_id": "missing-\{tool}",
    "source_event": "tool_call",
    "status": "failed",
    "detail": "Runtime consumer did not provide an outcome for expected tool `\{tool}`.",
    "command_id": command_id,
    "action": action,
  }
}

///|
fn runtime_consumer_scoped_raw_event(
  runtime_command : Json,
  event : Json,
) -> Json {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  let action = rq_json_string(runtime_command, "action", default="prompt")
  let with_command = if rq_json_string(event, "command_id", default="") == "" {
    rq_json_with_field(event, "command_id", command_id.to_json())
  } else {
    event
  }
  if rq_json_string(with_command, "action", default="") == "" {
    rq_json_with_field(with_command, "action", action.to_json())
  } else {
    with_command
  }
}

///|
fn runtime_consumer_event_id(
  runtime_command : Json,
  kind : String,
  index : Int,
) -> String {
  let command_id = rq_json_string(runtime_command, "command_id", default="")
  if command_id == "" {
    "runtime-consumer:\{kind}:\{index}"
  } else {
    "\{command_id}:runtime-consumer:\{kind}:\{index}"
  }
}

///|
test "mooncode runtime consumer ack completes run_tests with typed tool proof" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let runtime_command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-tests",
    "session_id": "session-demo",
    "action": "run_tests",
    "dispatch": "command",
    "serve_command": "prompt",
    "openseek_wire_command": { "command": "prompt", "text": "run tests" },
    "execution_summary": {
      "tool_sequence": ["read", "moon_check", "shell", "finish"],
      "required_events": [
        "tool_call", "tool_result", "test_result", "agent_finished",
      ],
    },
  }
  let ack = runtime_consumer_completion_ack(
    runtime_command,
    [
      runtime_consumer_tool_outcome(
        "read",
        call_id="call-read",
        arguments="{\"path\":\"tools/demo/main.mbt\"}",
        content="fn main { println(\"demo\") }",
        path="tools/demo/main.mbt",
      ),
      runtime_consumer_tool_outcome(
        "moon_check",
        call_id="call-check",
        arguments="{\"command\":\"moon check\"}",
        content="moon check passed",
        command="moon check",
      ),
      runtime_consumer_tool_outcome(
        "shell",
        call_id="call-shell",
        arguments="{\"command\":\"moon test\"}",
        content="Total tests: 1, passed: 1",
        command="moon test",
      ),
      runtime_consumer_tool_outcome("finish", content="tests passed"),
    ],
    [
      runtime_consumer_test_result_event(
        command="moon test",
        exit_code=0,
        detail="Total tests: 1, passed: 1",
      ),
    ],
    consumer_id="mooncode-local",
    acknowledged_at="2026-06-15T00:00:00Z",
  )
  let receipts = runtime_replay_ack_receipts(session, [runtime_command], ack)
  assert_eq(receipts.length(), 1)
  assert_eq(
    rq_json_string(receipts[0], "status", default=""),
    "runtime-completed",
  )
  let gate = rq_json_object_field_or_empty(receipts[0], "proof_gate")
  assert_eq(rq_json_string(gate, "status", default=""), "passed")
  assert_eq(rq_json_string(gate, "tool_harness_status", default=""), "proven")
  assert_eq(rq_json_int(gate, "tool_harness_expected_tool_count", default=0), 4)
  assert_eq(rq_json_int(gate, "tool_harness_proven_tool_count", default=0), 4)
}

///|
test "mooncode runtime consumer ack is proof-missing when an expected tool outcome is absent" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let runtime_command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-tests",
    "session_id": "session-demo",
    "action": "run_tests",
    "dispatch": "command",
    "serve_command": "prompt",
    "openseek_wire_command": { "command": "prompt", "text": "run tests" },
    "execution_summary": {
      "tool_sequence": ["read", "moon_check", "shell", "finish"],
      "required_events": [
        "tool_call", "tool_result", "test_result", "agent_finished",
      ],
    },
  }
  let ack = runtime_consumer_completion_ack(
    runtime_command,
    [
      runtime_consumer_tool_outcome("read", call_id="call-read", content="ok"),
      runtime_consumer_tool_outcome(
        "moon_check",
        call_id="call-check",
        content="moon check passed",
      ),
      runtime_consumer_tool_outcome("finish", content="done"),
    ],
    [runtime_consumer_test_result_event(command="moon test", exit_code=0)],
    consumer_id="mooncode-local",
    acknowledged_at="2026-06-15T00:00:00Z",
  )
  let receipts = runtime_replay_ack_receipts(session, [runtime_command], ack)
  assert_eq(receipts.length(), 1)
  assert_eq(rq_json_string(receipts[0], "status", default=""), "proof-missing")
  let gate = rq_json_object_field_or_empty(receipts[0], "proof_gate")
  assert_true(rq_json_bool(gate, "completion_blocked", default=false))
  assert_true(
    rq_json_bool(gate, "tool_harness_completion_blocked", default=false),
  )
  assert_eq(rq_json_string(gate, "tool_harness_status", default=""), "failed")
  assert_eq(rq_json_int(gate, "tool_harness_failed_tool_count", default=0), 1)
}

///|
test "mooncode runtime consumer package output ack proves executable package completion" {
  let session : Json = { "id": "session-demo", "workspace_id": "book-demo" }
  let runtime_command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-package",
    "session_id": "session-demo",
    "action": "package",
    "dispatch": "command",
    "serve_command": "prompt",
    "openseek_wire_command": { "command": "prompt", "text": "package output" },
    "execution_summary": {
      "tool_sequence": [
        "read", "moon_check", "shell", "package_app_tool", "finish",
      ],
      "required_events": [
        "tool_call", "tool_result", "artifact", "package.manifest", "package.index",
        "package_verified", "agent_finished",
      ],
    },
  }
  let ack = runtime_consumer_package_output_ack(
    runtime_command,
    "tools/demo/main.mbt",
    "portable/app-tool/demo",
    "wiki/reviews/mooncode/session-demo/package-cmd-package.json",
    "portable/app-tool/mooncode/session-demo/index.json",
    package_kind="app-tool",
    consumer_id="mooncode-local",
    acknowledged_at="2026-06-15T00:00:00Z",
  )
  let receipts = runtime_replay_ack_receipts(session, [runtime_command], ack)
  assert_eq(receipts.length(), 1)
  assert_eq(
    rq_json_string(receipts[0], "status", default=""),
    "runtime-completed",
  )
  let gate = rq_json_object_field_or_empty(receipts[0], "proof_gate")
  assert_eq(rq_json_string(gate, "status", default=""), "passed")
  assert_eq(rq_json_string(gate, "tool_harness_status", default=""), "proven")
  assert_eq(rq_json_int(gate, "tool_harness_expected_tool_count", default=0), 5)
  assert_eq(rq_json_int(gate, "tool_harness_proven_tool_count", default=0), 5)
  assert_eq(rq_json_int(gate, "missing_required_event_count", default=-1), 0)
  let summary = rq_json_object_field_or_empty(
    receipts[0],
    "runtime_event_summary",
  )
  assert_true(rq_json_int(summary, "artifact_event_count", default=0) >= 4)
  let events = runtime_replay_ack_normalized_events(receipts)
  let mut saw_manifest = false
  let mut saw_index = false
  let mut saw_verified = false
  for event in events {
    match rq_json_string(event, "kind", default="") {
      "package.manifest" => saw_manifest = true
      "package.index" => saw_index = true
      "runtime.package_verified" => saw_verified = true
      _ => ()
    }
  }
  assert_true(saw_manifest)
  assert_true(saw_index)
  assert_true(saw_verified)
}
