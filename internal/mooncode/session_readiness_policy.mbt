///|
// MoonCode readiness next-action and owner policy.

///|
fn readiness_next_action(blocker_id : String) -> String {
  match blocker_id {
    "" => "completed"
    "moonbook_selected" => "select_moonbook"
    "runtime_session_attached" => "attach_runtime_session"
    "durable_session" => "persist_session_snapshot"
    "resume_lifecycle" => "resume_runtime"
    "runtime_supervisor_ready" => "refresh_runtime_supervisor"
    "native_eval_ready" => "run_native_eval"
    "canonical_conversation" => "send_prompt"
    "typed_command_queue" => "queue_prompt_command"
    "live_runtime_stream" => "run_native_runtime_service"
    "tool_execution" => "run_tool_execution"
    "diff_review" => "review_patch_set"
    "test_build_execution" => "run_tests_or_build"
    "review_receipts" => "accept_or_reject_changes"
    "package_result" => "package_result"
    "package_lifecycle" => "verify_package"
    "action_plan_current" => "refresh_action_plan"
    "live_blockers_clear" => "resolve_live_blockers"
    "standalone_boundary" => "write_runtime_handoff"
    _ => "inspect_readiness_check"
  }
}

///|
fn readiness_next_owner(blocker_id : String) -> String {
  match blocker_id {
    "" => "none"
    "moonbook_selected" => "moondesk"
    "runtime_session_attached" => "moondesk-mooncode"
    "durable_session" => "mooncode-moonbook"
    "resume_lifecycle" => "moonclaw"
    "runtime_supervisor_ready" => "moonclaw"
    "native_eval_ready" => "moonclaw"
    "canonical_conversation" => "mooncode"
    "typed_command_queue" => "mooncode"
    "live_runtime_stream" => "moonclaw"
    "tool_execution" => "moonclaw"
    "diff_review" => "moondesk-moonbook"
    "test_build_execution" => "moonclaw"
    "review_receipts" => "moondesk-moonbook"
    "package_result" => "moonbook-moonclaw"
    "package_lifecycle" => "moonbook-moonclaw"
    "action_plan_current" => "mooncode-moonbook"
    "live_blockers_clear" => "moondesk-moonclaw"
    "standalone_boundary" => "mooncode"
    _ => "mooncode"
  }
}
