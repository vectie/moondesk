///|
// Phase 28 package/review model-flow fixtures.

///|
fn package_flow_test_packet(command_id : String) -> Json {
  {
    "protocol": protocol_version(),
    "kind": kind_command(),
    "command_id": command_id,
    "client_turn_id": "turn-\{command_id}",
    "action": "package",
    "model": "moonclaw-model",
    "runtime_session_id": "runtime-s1",
    "run_id": "run-\{command_id}",
  }
}

///|
fn package_flow_test_event(
  command_id : String,
  id : String,
  lane : String,
  kind : String,
  status : String,
  created_at : String,
) -> Json {
  event_record(
    id~,
    lane~,
    kind~,
    title=kind,
    status~,
    created_at~,
    detail=kind,
    command=if kind == "command.package" { "package" } else { "" },
    command_packet=package_flow_test_packet(command_id),
  )
}

///|
fn package_flow_test_command(command_id : String) -> Json {
  package_flow_test_event(
    command_id,
    "event-\{command_id}",
    "command",
    "command.package",
    "queued",
    "2026-07-04T00:00:00Z",
  )
}

///|
fn package_flow_test_report(events : Array[Json]) -> Json {
  package_review_model_flow_report("session-a", events)
}

///|
fn package_flow_test_first_command(report : Json) -> Json raise {
  let commands = json_array_items(report, "commands")
  if commands.length() == 0 {
    fail("expected package flow command")
  }
  commands[0]
}

///|
test "mooncode package review model flow accepts complete owned package run" {
  let report = package_flow_test_report([
    package_flow_test_command("cmd-package"),
    package_flow_test_event(
      "cmd-package", "manifest", "artifact", "package.manifest", "candidate", "2026-07-04T00:00:01Z",
    ),
    package_flow_test_event(
      "cmd-package", "accept", "review", "receipt.accept", "recorded", "2026-07-04T00:00:02Z",
    ),
    package_flow_test_event(
      "cmd-package",
      "tests",
      "test",
      event_test_result(),
      "passed",
      "2026-07-04T00:00:03Z",
    ),
    package_flow_test_event(
      "cmd-package", "verified", "artifact", "runtime.package_verified", "done",
      "2026-07-04T00:00:04Z",
    ),
    package_flow_test_event(
      "cmd-package", "assistant", "transcript", "assistant", "done", "2026-07-04T00:00:05Z",
    ),
  ])
  assert_eq(json_string(report, "status", default=""), "accepted")
  assert_true(json_bool(report, "contract_satisfied", default=false))
  assert_eq(runtime_json_int(report, "accepted_command_count", default=0), 1)
  assert_eq(runtime_json_int(report, "stale_evidence_count", default=-1), 0)
  let command = package_flow_test_first_command(report)
  assert_eq(json_string(command, "status", default=""), "accepted")
  assert_eq(
    json_string(
      runtime_json_object_field_or_empty(command, "owner"),
      "command_id",
      default="",
    ),
    "cmd-package",
  )
  assert_eq(json_array_items(command, "missing_steps").length(), 0)
}

///|
test "mooncode package review model flow rejects with owned reject receipt and summary" {
  let report = package_flow_test_report([
    package_flow_test_command("cmd-reject"),
    package_flow_test_event(
      "cmd-reject", "manifest", "artifact", "package.manifest", "candidate", "2026-07-04T00:01:01Z",
    ),
    package_flow_test_event(
      "cmd-reject", "reject", "review", "receipt.reject", "recorded", "2026-07-04T00:01:02Z",
    ),
    package_flow_test_event(
      "cmd-reject", "assistant", "transcript", "assistant", "done", "2026-07-04T00:01:03Z",
    ),
  ])
  assert_eq(json_string(report, "status", default=""), "rejected")
  assert_true(json_bool(report, "contract_satisfied", default=false))
  assert_eq(runtime_json_int(report, "rejected_command_count", default=0), 1)
  let command = package_flow_test_first_command(report)
  assert_eq(json_string(command, "status", default=""), "rejected")
  assert_eq(runtime_json_int(command, "review_reject_count", default=0), 1)
}

///|
test "mooncode package review model flow fails on command scoped test failure" {
  let failed_test = runtime_with_field(
    package_flow_test_event(
      "cmd-fail",
      "tests",
      "test",
      event_test_result(),
      "failed",
      "2026-07-04T00:02:03Z",
    ),
    "exit_code",
    (1).to_json(),
  )
  let report = package_flow_test_report([
    package_flow_test_command("cmd-fail"),
    package_flow_test_event(
      "cmd-fail", "manifest", "artifact", "package.manifest", "candidate", "2026-07-04T00:02:01Z",
    ),
    package_flow_test_event(
      "cmd-fail", "accept", "review", "receipt.accept", "recorded", "2026-07-04T00:02:02Z",
    ),
    failed_test,
  ])
  assert_eq(json_string(report, "status", default=""), "failed")
  assert_true(json_bool(report, "contract_satisfied", default=false))
  assert_eq(runtime_json_int(report, "failed_command_count", default=0), 1)
  let command = package_flow_test_first_command(report)
  assert_eq(json_string(command, "status", default=""), "failed")
  assert_eq(runtime_json_int(command, "test_fail_count", default=0), 1)
}

///|
test "mooncode package review model flow treats other command evidence as stale" {
  let report = package_flow_test_report([
    package_flow_test_command("cmd-current"),
    package_flow_test_event(
      "cmd-old", "manifest-old", "artifact", "package.manifest", "candidate", "2026-07-04T00:03:01Z",
    ),
    package_flow_test_event(
      "cmd-old", "accept-old", "review", "receipt.accept", "recorded", "2026-07-04T00:03:02Z",
    ),
    package_flow_test_event(
      "cmd-old", "verified-old", "artifact", "runtime.package_verified", "done",
      "2026-07-04T00:03:03Z",
    ),
    package_flow_test_event(
      "cmd-old", "assistant-old", "transcript", "assistant", "done", "2026-07-04T00:03:04Z",
    ),
  ])
  assert_eq(json_string(report, "status", default=""), "stale")
  assert_false(json_bool(report, "contract_satisfied", default=true))
  assert_eq(runtime_json_int(report, "stale_evidence_count", default=0), 4)
  let command = package_flow_test_first_command(report)
  assert_eq(json_string(command, "status", default=""), "waiting-for-manifest")
  let stale = json_array_items(report, "stale_evidence")
  assert_eq(json_string(stale[0], "command_id", default=""), "cmd-old")
  assert_eq(
    json_string(stale[0], "reason", default=""),
    "evidence-without-package-command",
  )
}

///|
test "mooncode package review model flow contract is advertised by runtime protocol" {
  let protocol = runtime_protocol_contract_json()
  let stream = runtime_json_object_field_or_empty(protocol, "event_stream")
  let contract = runtime_json_object_field_or_empty(
    stream, "package_review_model_flow_contract",
  )
  assert_eq(
    json_string(contract, "kind", default=""),
    "mooncode-package-review-model-flow-contract",
  )
  assert_true(
    json_string(contract, "command_scope_rule", default="").contains(
      "same package command_id",
    ),
  )
}
