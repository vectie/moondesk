///|
pub fn command_runtime_evidence(
  command : Json,
  runtime_command : Json,
  events : Array[Json],
) -> Json {
  let command_id = json_string(command, "command_id", default="")
  let action = json_string(command, "action", default="prompt")
  let summary = evidence_json_object_field_or_empty(
    runtime_command, "execution_summary",
  )
  let required_events = evidence_required_events(action, summary)
  let event_results : Array[Json] = []
  let mut proven_count = 0
  let mut missing_count = 0
  let mut failed_count = 0
  for required in required_events {
    let proof = evidence_match_required_event(
      required, command_id, action, events,
    )
    event_results.push(proof)
    match json_string(proof, "status", default="missing") {
      "proven" => proven_count += 1
      "failed" => failed_count += 1
      _ => missing_count += 1
    }
  }
  let required_outputs = if json_string(summary, "kind", default="") == "" {
    native_command_required_outputs(action)
  } else {
    evidence_json_string_array_items(summary, "required_outputs")
  }
  let tool_harness = tool_harness_evidence(command, runtime_command, events)
  {
    "kind": "mooncode-command-runtime-evidence",
    "protocol": "mooncode.v1",
    "command_id": command_id,
    "action": action,
    "runtime_command_recorded": json_string(
      runtime_command,
      "command_id",
      default="",
    ) !=
    "",
    "required_event_count": required_events.length(),
    "proven_required_event_count": proven_count,
    "missing_required_event_count": missing_count,
    "failed_required_event_count": failed_count,
    "required_events": string_array_json(required_events),
    "missing_required_events": string_array_json(
      evidence_events_with_status(event_results, "missing"),
    ),
    "failed_required_events": string_array_json(
      evidence_events_with_status(event_results, "failed"),
    ),
    "required_outputs": string_array_json(required_outputs),
    "tool_harness": tool_harness,
    "tool_harness_status": json_string(
      tool_harness,
      "status",
      default="missing-evidence",
    ),
    "tool_harness_proven": json_bool(tool_harness, "proven", default=false),
    "tool_harness_expected_tool_count": runtime_json_int(
      tool_harness,
      "expected_tool_count",
      default=0,
    ),
    "tool_harness_proven_tool_count": runtime_json_int(
      tool_harness,
      "proven_tool_count",
      default=0,
    ),
    "tool_harness_failed_tool_count": runtime_json_int(
      tool_harness,
      "failed_tool_count",
      default=0,
    ),
    "tool_harness_missing_tool_count": runtime_json_int(
      tool_harness,
      "missing_tool_count",
      default=0,
    ),
    "events": Json::array(event_results),
    "proven": required_events.length() > 0 &&
    missing_count == 0 &&
    failed_count == 0,
    "status": if required_events.length() == 0 {
      "no-required-events"
    } else if failed_count > 0 {
      "failed"
    } else if missing_count > 0 {
      "missing-evidence"
    } else {
      "proven"
    },
    "rule": "Required runtime events are proven only by command-scoped MoonCode events. Unscoped legacy events may still render in the transcript, but they do not satisfy this command-level proof.",
  }
}

///|
pub fn session_runtime_evidence(
  session : Json,
  commands : Array[Json],
  runtime_commands : Array[Json],
  proof_events : Array[Json],
  recorded_at~ : String,
) -> Json {
  let items : Array[Json] = []
  let mut index = 0
  let mut proven_count = 0
  let mut missing_count = 0
  let mut failed_count = 0
  let mut missing_runtime_command_count = 0
  let mut required_event_count = 0
  let mut proven_required_event_count = 0
  let mut failed_required_event_count = 0
  let mut missing_required_event_count = 0
  let mut tool_harness_expected_tool_count = 0
  let mut tool_harness_proven_tool_count = 0
  let mut tool_harness_failed_tool_count = 0
  let mut tool_harness_missing_tool_count = 0
  for command in commands {
    let runtime_command = evidence_runtime_command_for_id(
      json_string(command, "command_id", default=""),
      runtime_commands,
    )
    let evidence = command_runtime_evidence(
      command, runtime_command, proof_events,
    )
    let status = json_string(evidence, "status", default="missing-evidence")
    if status == "proven" {
      proven_count += 1
    } else if status == "failed" {
      failed_count += 1
    } else {
      missing_count += 1
    }
    if !json_bool(evidence, "runtime_command_recorded", default=false) {
      missing_runtime_command_count += 1
    }
    required_event_count += runtime_json_int(
      evidence,
      "required_event_count",
      default=0,
    )
    proven_required_event_count += runtime_json_int(
      evidence,
      "proven_required_event_count",
      default=0,
    )
    failed_required_event_count += runtime_json_int(
      evidence,
      "failed_required_event_count",
      default=0,
    )
    missing_required_event_count += runtime_json_int(
      evidence,
      "missing_required_event_count",
      default=0,
    )
    tool_harness_expected_tool_count += runtime_json_int(
      evidence,
      "tool_harness_expected_tool_count",
      default=0,
    )
    tool_harness_proven_tool_count += runtime_json_int(
      evidence,
      "tool_harness_proven_tool_count",
      default=0,
    )
    tool_harness_failed_tool_count += runtime_json_int(
      evidence,
      "tool_harness_failed_tool_count",
      default=0,
    )
    tool_harness_missing_tool_count += runtime_json_int(
      evidence,
      "tool_harness_missing_tool_count",
      default=0,
    )
    items.push({
      "index": index,
      "command_id": json_string(command, "command_id", default=""),
      "action": json_string(command, "action", default="prompt"),
      "created_at": json_string(command, "created_at", default=""),
      "context_path": json_string(command, "context_path", default=""),
      "message": json_string(command, "message", default=""),
      "runtime_command_recorded": json_bool(
        evidence,
        "runtime_command_recorded",
        default=false,
      ),
      "status": status,
      "required_event_count": runtime_json_int(
        evidence,
        "required_event_count",
        default=0,
      ),
      "proven_required_event_count": runtime_json_int(
        evidence,
        "proven_required_event_count",
        default=0,
      ),
      "missing_required_events": evidence_json_array(
        evidence, "missing_required_events",
      ),
      "failed_required_events": evidence_json_array(
        evidence, "failed_required_events",
      ),
      "tool_harness_status": json_string(
        evidence,
        "tool_harness_status",
        default="missing-evidence",
      ),
      "tool_harness_proven_tool_count": runtime_json_int(
        evidence,
        "tool_harness_proven_tool_count",
        default=0,
      ),
      "tool_harness_expected_tool_count": runtime_json_int(
        evidence,
        "tool_harness_expected_tool_count",
        default=0,
      ),
      "evidence": evidence,
    })
    index += 1
  }
  {
    "kind": "mooncode-session-runtime-evidence",
    "protocol": "mooncode.v1",
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "recorded_at": recorded_at,
    "command_count": commands.length(),
    "runtime_command_count": runtime_commands.length(),
    "proof_event_count": proof_events.length(),
    "proven_command_count": proven_count,
    "missing_evidence_command_count": missing_count,
    "failed_evidence_command_count": failed_count,
    "missing_runtime_command_count": missing_runtime_command_count,
    "required_event_count": required_event_count,
    "proven_required_event_count": proven_required_event_count,
    "missing_required_event_count": missing_required_event_count,
    "failed_required_event_count": failed_required_event_count,
    "tool_harness_expected_tool_count": tool_harness_expected_tool_count,
    "tool_harness_proven_tool_count": tool_harness_proven_tool_count,
    "tool_harness_missing_tool_count": tool_harness_missing_tool_count,
    "tool_harness_failed_tool_count": tool_harness_failed_tool_count,
    "tool_harness_status": if tool_harness_expected_tool_count == 0 {
      "no-tools"
    } else if tool_harness_failed_tool_count > 0 {
      "failed"
    } else if tool_harness_missing_tool_count > 0 {
      "missing-evidence"
    } else {
      "proven"
    },
    "status": if commands.length() == 0 {
      "no-commands"
    } else if failed_count > 0 || failed_required_event_count > 0 {
      "failed"
    } else if missing_count > 0 ||
      missing_runtime_command_count > 0 ||
      missing_required_event_count > 0 {
      "missing-evidence"
    } else {
      "proven"
    },
    "items": Json::array(items),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "extractable_component": "mooncode",
    },
    "rule": "This projection is the session-level proof contract. Moondesk records and displays it, while MoonClaw or standalone MoonCode must satisfy it with command-scoped runtime events.",
  }
}

///|
fn evidence_runtime_command_for_id(
  command_id : String,
  runtime_commands : Array[Json],
) -> Json {
  if command_id == "" {
    return Json::object({})
  }
  for runtime_command in runtime_commands {
    if json_string(runtime_command, "command_id", default="") == command_id {
      return runtime_command
    }
  }
  Json::object({})
}

///|
fn evidence_required_events(action : String, summary : Json) -> Array[String] {
  let required = evidence_json_string_array_items(summary, "required_events")
  if required.length() == 0 {
    native_command_expected_events(action)
  } else {
    required
  }
}

///|
fn evidence_match_required_event(
  required : String,
  command_id : String,
  action : String,
  events : Array[Json],
) -> Json {
  let mut failed_event = Json::object({})
  for event in events {
    if !evidence_event_matches_command(event, command_id, action) {
      continue
    }
    if evidence_event_fails_required(required, event) {
      if json_string(failed_event, "id", default="") == "" {
        failed_event = event
      }
      continue
    }
    if !evidence_event_satisfies(required, event) {
      continue
    }
    if json_string(event, "status", default="") == "failed" {
      if json_string(failed_event, "id", default="") == "" {
        failed_event = event
      }
      continue
    }
    return evidence_required_event_result(required, "proven", event)
  }
  if json_string(failed_event, "id", default="") != "" {
    evidence_required_event_result(required, "failed", failed_event)
  } else {
    evidence_required_event_result(required, "missing", Json::object({}))
  }
}

///|
fn evidence_required_event_result(
  required : String,
  status : String,
  event : Json,
) -> Json {
  {
    "required_event": required,
    "status": status,
    "event_id": json_string(event, "id", default=""),
    "event_kind": json_string(event, "kind", default=""),
    "event_status": json_string(event, "status", default=""),
    "event_title": json_string(event, "title", default=""),
    "event_path": json_string(event, "path", default=""),
    "event_detail": json_string(event, "detail", default=""),
    "tool_call_id": json_string(event, "tool_call_id", default=""),
  }
}

///|
fn evidence_event_matches_command(
  event : Json,
  command_id : String,
  action : String,
) -> Bool {
  if command_id == "" {
    return false
  }
  let packet = evidence_json_object_field_or_empty(event, "command_packet")
  json_string(packet, "command_id", default="") == command_id &&
  evidence_event_action(event) == action
}

///|
fn evidence_event_action(event : Json) -> String {
  let packet = evidence_json_object_field_or_empty(event, "command_packet")
  let packet_action = json_string(packet, "action", default="")
  if packet_action != "" {
    return packet_action
  }
  json_string(event, "command", default="")
}

///|
fn evidence_event_satisfies(required : String, event : Json) -> Bool {
  let kind = json_string(event, "kind", default="")
  match required {
    "tool_call" =>
      json_string(event, "tool_call_id", default="") != "" &&
      json_string(event, "status", default="") == "running"
    "tool_result" =>
      json_string(event, "tool_call_id", default="") != "" &&
      kind != "tool_call_decode_error" &&
      json_string(event, "status", default="") != "running"
    "agent_finished" => kind == "finish"
    "review.receipt" => kind.has_prefix("receipt.")
    "package_verified" => kind == "runtime.package_verified"
    "package_built" => kind == "runtime.package_built"
    "commit_created" => kind == "runtime.commit_created"
    "patch_applied" => kind == "runtime.patch_applied"
    "patch_reverted" => kind == "runtime.patch_reverted"
    "native eval report" => kind == "eval_report.manifest"
    _ => kind == required
  }
}

///|
fn evidence_event_fails_required(required : String, event : Json) -> Bool {
  if json_string(event, "status", default="") != "failed" {
    return false
  }
  let kind = json_string(event, "kind", default="")
  let source_event = json_string(event, "source_event", default="")
  match required {
    "tool_call" =>
      kind == "tool_call_decode_error" &&
      source_event != "tool_result" &&
      json_string(event, "tool_call_id", default="") != ""
    "tool_result" =>
      kind == "tool_call_decode_error" &&
      source_event == "tool_result" &&
      json_string(event, "tool_call_id", default="") != ""
    _ => evidence_event_satisfies(required, event)
  }
}

///|
fn evidence_events_with_status(
  event_results : Array[Json],
  status : String,
) -> Array[String] {
  let result : Array[String] = []
  for item in event_results {
    if json_string(item, "status", default="") == status {
      result.push(json_string(item, "required_event", default=""))
    }
  }
  result
}

///|
fn evidence_json_object_field_or_empty(json : Json, key : String) -> Json {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(value) => value
        None => Json::object({})
      }
    _ => Json::object({})
  }
}

///|
fn evidence_json_array(json : Json, key : String) -> Json {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) => Json::array(values)
        _ => []
      }
    _ => []
  }
}

///|
fn evidence_json_string_array_items(json : Json, key : String) -> Array[String] {
  match json {
    Json::Object(object) =>
      match object.get(key) {
        Some(Json::Array(values)) => {
          let result : Array[String] = []
          for value in values {
            match value {
              Json::String(item) => result.push(item)
              _ => ()
            }
          }
          result
        }
        _ => []
      }
    _ => []
  }
}

///|
test "mooncode command runtime evidence requires command scoped proof" {
  let command : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let runtime_command : Json = {
    "command_id": "cmd-test",
    "execution_summary": {
      "required_events": [
        "tool_call", "tool_result", "test_result", "agent_finished",
      ],
      "required_outputs": ["exit code"],
    },
  }
  let scoped_packet : Json = { "command_id": "cmd-test", "action": "run_tests" }
  let evidence = command_runtime_evidence(command, runtime_command, [
    event_record(
      id="tool-start",
      lane="test",
      kind="moon_check",
      title="Tool started",
      status="running",
      created_at="2026-06-15T00:00:00Z",
      detail="moon check",
      command_packet=scoped_packet,
    )
    |> runtime_with_field("tool_call_id", "call-1".to_json()),
    event_record(
      id="tool-result",
      lane="test",
      kind="moon_check",
      title="Tool finished",
      status="done",
      created_at="2026-06-15T00:00:01Z",
      detail="ok",
      command_packet=scoped_packet,
    )
    |> runtime_with_field("tool_call_id", "call-1".to_json()),
    event_record(
      id="test-result",
      lane="test",
      kind="test_result",
      title="Test result",
      status="done",
      created_at="2026-06-15T00:00:02Z",
      detail="ok",
      command_packet=scoped_packet,
    ),
    event_record(
      id="finish",
      lane="review",
      kind="finish",
      title="Agent finished",
      status="done",
      created_at="2026-06-15T00:00:03Z",
      detail="done",
      command_packet=scoped_packet,
    ),
    event_record(
      id="unscoped-test",
      lane="test",
      kind="test_result",
      title="Ignored",
      status="done",
      created_at="2026-06-15T00:00:04Z",
      detail="legacy",
    ),
  ])
  assert_eq(json_string(evidence, "status", default=""), "proven")
  assert_true(json_bool(evidence, "proven", default=false))
  assert_eq(
    runtime_json_int(evidence, "proven_required_event_count", default=0),
    4,
  )
  assert_eq(
    runtime_json_int(evidence, "missing_required_event_count", default=-1),
    0,
  )
}

///|
test "mooncode runtime evidence accepts command-scoped replay ack events" {
  let command : Json = { "command_id": "cmd-tests", "action": "run_tests" }
  let runtime_command : Json = {
    "protocol": "mooncode.v1",
    "kind": "mooncode.runtime-command",
    "command_id": "cmd-tests",
    "session_id": "session-demo",
    "action": "run_tests",
    "dispatch": "command",
    "execution_summary": {
      "required_events": [
        "tool_call", "tool_result", "test_result", "agent_finished",
      ],
    },
    "openseek_wire_command": { "command": "prompt", "text": "run tests" },
  }
  let receipts = runtime_replay_ack_receipts(
    { "id": "session-demo", "workspace_id": "book-demo" },
    [runtime_command],
    {
      "consumer_id": "moonclaw-runtime",
      "command_id": "cmd-tests",
      "status": "runtime-completed",
      "acknowledged_at": "2026-06-15T00:00:00Z",
      "events": [
        {
          "event": "tool_call",
          "id": "evt-tool-start",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "arguments": "{\"command\":\"moon check\"}",
        },
        {
          "event": "tool_result",
          "id": "evt-tool-result",
          "tool_name": "moon_check",
          "tool_call_id": "call-check",
          "content": "moon check passed",
        },
        {
          "event": "test_result",
          "id": "evt-test",
          "command": "moon test",
          "status": "passed",
          "exit_code": 0,
        },
        { "event": "agent_finished", "id": "evt-finish", "answer": "done" },
      ],
    },
  )
  let events = runtime_replay_ack_normalized_events(receipts)
  let evidence = command_runtime_evidence(command, runtime_command, events)
  assert_eq(json_string(evidence, "status", default=""), "proven")
  assert_eq(
    runtime_json_int(evidence, "proven_required_event_count", default=0),
    4,
  )
  let packet = evidence_json_object_field_or_empty(events[0], "command_packet")
  assert_eq(json_string(packet, "command_id", default=""), "cmd-tests")
  assert_eq(json_string(packet, "action", default=""), "run_tests")
}

///|
test "mooncode session runtime evidence aggregates command proof" {
  let run_tests : Json = {
    "command_id": "cmd-tests",
    "action": "run_tests",
    "created_at": "2026-06-15T00:00:00Z",
  }
  let commit : Json = {
    "command_id": "cmd-commit",
    "action": "commit",
    "created_at": "2026-06-15T00:00:10Z",
  }
  let runtime_command : Json = {
    "command_id": "cmd-tests",
    "execution_summary": {
      "required_events": ["tool_call", "tool_result", "test_result"],
    },
  }
  let packet : Json = { "command_id": "cmd-tests", "action": "run_tests" }
  let projection = session_runtime_evidence(
    { "id": "session-demo", "workspace_id": "book-demo" },
    [run_tests, commit],
    [runtime_command],
    [
      event_record(
        id="tool-start",
        lane="test",
        kind="moon_check",
        title="Tool started",
        status="running",
        created_at="2026-06-15T00:00:01Z",
        detail="moon check",
        command_packet=packet,
      )
      |> runtime_with_field("tool_call_id", "call-1".to_json()),
      event_record(
        id="tool-result",
        lane="test",
        kind="moon_check",
        title="Tool finished",
        status="done",
        created_at="2026-06-15T00:00:02Z",
        detail="ok",
        command_packet=packet,
      )
      |> runtime_with_field("tool_call_id", "call-1".to_json()),
      event_record(
        id="test-result",
        lane="test",
        kind="test_result",
        title="Tests passed",
        status="done",
        created_at="2026-06-15T00:00:03Z",
        detail="ok",
        command_packet=packet,
      ),
    ],
    recorded_at="2026-06-15T00:01:00Z",
  )
  assert_eq(
    json_string(projection, "kind", default=""),
    "mooncode-session-runtime-evidence",
  )
  assert_eq(json_string(projection, "status", default=""), "missing-evidence")
  assert_eq(runtime_json_int(projection, "command_count", default=0), 2)
  assert_eq(runtime_json_int(projection, "proven_command_count", default=0), 1)
  assert_eq(
    runtime_json_int(projection, "missing_runtime_command_count", default=0),
    1,
  )
}

///|
test "mooncode command runtime evidence reports missing and failed requirements" {
  let command : Json = { "command_id": "cmd-commit", "action": "commit" }
  let runtime_command : Json = {
    "command_id": "cmd-commit",
    "execution_summary": {
      "required_events": [
        "tool_call", "tool_result", "commit_created", "agent_finished",
      ],
    },
  }
  let packet : Json = { "command_id": "cmd-commit", "action": "commit" }
  let evidence = command_runtime_evidence(command, runtime_command, [
    event_record(
      id="commit-failed",
      lane="review",
      kind="runtime.commit_created",
      title="Commit failed",
      status="failed",
      created_at="2026-06-15T00:00:00Z",
      detail="git failed",
      command_packet=packet,
    ),
  ])
  assert_eq(json_string(evidence, "status", default=""), "failed")
  assert_eq(
    runtime_json_int(evidence, "failed_required_event_count", default=0),
    1,
  )
  assert_true(
    evidence_json_string_array_items(evidence, "missing_required_events").contains(
      "agent_finished",
    ),
  )
  assert_true(
    evidence_json_string_array_items(evidence, "failed_required_events").contains(
      "commit_created",
    ),
  )
}

///|
test "mooncode command runtime evidence fails command scoped tool decode errors" {
  let command : Json = { "command_id": "cmd-prompt", "action": "prompt" }
  let runtime_command : Json = {
    "command_id": "cmd-prompt",
    "execution_summary": {
      "required_events": ["tool_call", "tool_result", "agent_finished"],
    },
  }
  let packet : Json = { "command_id": "cmd-prompt", "action": "prompt" }
  let evidence = command_runtime_evidence(command, runtime_command, [
    event_record(
      id="tool-decode-failed",
      lane="tool",
      kind="tool_call_decode_error",
      title="Tool decode failed",
      status="failed",
      created_at="2026-06-15T00:00:00Z",
      detail="unknown tool: delete_everything",
      command_packet=packet,
    )
    |> runtime_with_field("tool_call_id", "call-danger".to_json())
    |> runtime_with_field("source_event", "tool_call".to_json()),
  ])
  assert_eq(json_string(evidence, "status", default=""), "failed")
  assert_eq(
    runtime_json_int(evidence, "failed_required_event_count", default=0),
    1,
  )
  assert_true(
    evidence_json_string_array_items(evidence, "failed_required_events").contains(
      "tool_call",
    ),
  )
  assert_true(
    evidence_json_string_array_items(evidence, "missing_required_events").contains(
      "tool_result",
    ),
  )
}
