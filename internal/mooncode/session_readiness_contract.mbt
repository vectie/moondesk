///|
// MoonCode readiness contract metadata.

///|
fn readiness_contract_check(
  id : String,
  label : String,
  evidence_required : String,
) -> Json {
  {
    "id": id,
    "label": label,
    "evidence_required": evidence_required,
    "next_action": readiness_next_action(id),
    "next_owner": readiness_next_owner(id),
  }
}

///|
pub fn readiness_contract_json() -> Json {
  let checks = [
    readiness_contract_check(
      "moonbook_selected", "MoonBook selected", "selected workspace/book id is present",
    ),
    readiness_contract_check(
      "runtime_session_attached", "MoonCode runtime session attached", "book-scoped MoonCode runtime session id is present",
    ),
    readiness_contract_check(
      "durable_session", "Durable session", "append-only event log, command log, and session snapshot are persisted",
    ),
    readiness_contract_check(
      "resume_lifecycle", "Resume lifecycle", "session snapshot can be resumed and is not blocked",
    ),
    readiness_contract_check(
      "runtime_supervisor_ready", "Runtime supervisor ready", "runtime handoff embeds a launch-ready supervisor with readiness checkpoint",
    ),
    readiness_contract_check(
      "native_eval_ready", "Native eval ready", "MoonBook eval-report manifest carries complete MoonClaw native harness proof",
    ),
    readiness_contract_check(
      "chat_transcript", "Chat transcript", "assistant/transcript lane has durable chat evidence",
    ),
    readiness_contract_check(
      "typed_command_queue", "Typed command queue", "mooncode.v1 command packet and runtime command queue are present",
    ),
    readiness_contract_check(
      "live_runtime_stream", "Live runtime stream", "runtime events and dispatch receipts prove live progress",
    ),
    readiness_contract_check(
      "tool_execution", "Tool execution", "tool lane has MoonClaw execution evidence",
    ),
    readiness_contract_check(
      "diff_review", "Diff review", "diff events plus MoonBook change-set and patch-set manifests exist",
    ),
    readiness_contract_check(
      "test_build_execution", "Test/build execution", "verified test/build result exists, no failing tests remain, and test-run manifest exists",
    ),
    readiness_contract_check(
      "review_receipts", "Review receipts", "review lane and MoonBook accept/reject receipt are present",
    ),
    readiness_contract_check(
      "package_result", "Package result", "source-bound package, package index, artifact event, and verified package proof exist",
    ),
    readiness_contract_check(
      "package_lifecycle", "Package lifecycle", "package lifecycle is verified and executable-ready",
    ),
    readiness_contract_check(
      "action_plan_current", "Current action plan", "MoonBook action-plan manifest is current",
    ),
    readiness_contract_check(
      "live_blockers_clear", "Live blockers clear", "no blocked action, pending diff, pending tool approval, pending steer, or failing test remains",
    ),
    readiness_contract_check(
      "standalone_boundary", "Standalone MoonCode boundary", "runtime handoff manifest proves the protocol/runtime boundary",
    ),
  ]
  {
    "kind": "mooncode-readiness-contract",
    "protocol": protocol_version(),
    "standalone_component": "mooncode",
    "check_count": checks.length(),
    "checks": checks,
    "readiness_contract": "readiness_summary(checks) returns ready, passed and blocked counts, first blocker, next action, next owner, and blocking check ids.",
    "owner_rule": "MoonCode owns the readiness projection; Moondesk renders status and blockers, MoonClaw provides execution evidence, and MoonBook owns accepted artifacts and review state.",
  }
}
