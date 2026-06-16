///|
// MoonCode action-plan operator guidance strings.

///|
pub fn action_plan_blocking_reason(
  action : String,
  runtime_state : String,
  state : String,
  summary : Json,
) -> String {
  if state == "queued-for-runtime" {
    return "command is recorded but has not been delivered to MoonClaw/native MoonCode yet"
  }
  if state == "runtime-retry" {
    if runtime_state == "expired-claim" {
      return "runtime claim lease expired; reclaim the command before execution"
    }
    return "last runtime dispatch failed; replay or retry the command"
  }
  if state == "running" {
    return "MoonClaw or standalone MoonCode has claimed this command and should acknowledge it through runtime replay"
  }
  if state != "blocked" {
    return ""
  }
  let failed_tests = runtime_json_int(summary, "failed_test_count", default=0)
  let pending_approvals = runtime_json_int(
    summary,
    "pending_tool_approval_count",
    default=0,
  )
  let pending_diffs = runtime_json_int(summary, "pending_diff_count", default=0)
  let verified_tests = runtime_json_int(
    summary,
    "verified_test_count",
    default=0,
  )
  if failed_tests > 0 {
    "fix failing test/build results before \{action}"
  } else if pending_approvals > 0 {
    "resolve pending tool approvals before \{action}"
  } else if pending_diffs > 0 && verified_tests == 0 {
    "run tests/builds before accepting pending file changes"
  } else if runtime_state == "" {
    "missing runtime state"
  } else {
    "waiting for MoonClaw proof events"
  }
}

///|
pub fn action_plan_item_next_step(_action : String, state : String) -> String {
  match state {
    "queued-for-runtime" =>
      "deliver command through runtime replay or native MoonCode"
    "running" => "wait for runtime acknowledgement or recover a stale claim"
    "runtime-retry" => "retry dispatch and preserve the failed receipt"
    "awaiting-proof" => "wait for MoonClaw to emit typed proof events"
    "blocked" => "resolve blocking gates before continuing"
    "ready-for-review" => "operator can review this action in Moondesk"
    "completed" => "no immediate operator action"
    _ => "inspect command"
  }
}
