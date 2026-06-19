///|
// MoonCode action-plan recommendation policy.

///|
pub fn action_plan_recommended_command(next_required_action : String) -> Json {
  match next_required_action {
    "dispatch_or_replay_runtime_commands" =>
      {
        "available": true,
        "ui_action": "runtime_loop",
        "action": "runtime_loop",
        "label": "Run Native Loop",
        "context_path": "",
        "message": "",
        "status": "running MoonClaw native MoonCode loop",
      }
    "retry_failed_runtime_dispatch" =>
      {
        "available": true,
        "ui_action": "runtime_loop",
        "action": "runtime_loop",
        "label": "Retry Runtime",
        "context_path": "",
        "message": "",
        "status": "retrying failed MoonCode runtime dispatch",
      }
    "await_runtime_proof" =>
      {
        "available": true,
        "ui_action": "runtime_loop",
        "action": "runtime_loop",
        "label": "Refresh Proof",
        "context_path": "",
        "message": "",
        "status": "refreshing MoonCode runtime proof",
      }
    "start_next_turn_for_deferred_steering" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "prompt",
        "label": "Start Next Turn",
        "context_path": "",
        "message": "Continue this MoonCode session and apply the deferred steering already saved in the command queue.",
        "status": "queued next MoonCode turn for deferred steering",
      }
    "fix_failed_tests" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "prompt",
        "label": "Fix Tests",
        "context_path": "",
        "message": "Inspect the failing MoonCode test evidence, edit the relevant files, and rerun the appropriate tests until they pass.",
        "status": "queued MoonCode test-fix prompt",
      }
    "run_tests" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "run_tests",
        "label": "Run Tests",
        "context_path": "",
        "message": "",
        "status": "queued MoonCode tests from action plan",
      }
    "package_executable_output" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "package",
        "label": "Package",
        "context_path": "",
        "message": "",
        "status": "queued MoonCode package from action plan",
      }
    "run_native_eval" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "run_eval",
        "label": "Run Eval",
        "context_path": "",
        "message": "",
        "status": "queued MoonCode native eval from action plan",
      }
    "start_or_resume_session" =>
      {
        "available": true,
        "ui_action": "mooncode_command",
        "action": "prompt",
        "label": "Resume",
        "context_path": "",
        "message": "Resume this MoonCode session for the selected MoonBook and propose the next executable-code change.",
        "status": "queued MoonCode resume prompt",
      }
    _ =>
      {
        "available": false,
        "ui_action": "",
        "action": "",
        "label": "",
        "context_path": "",
        "message": "",
        "status": "",
      }
  }
}

///|
fn action_plan_runtime_service_command(status : String) -> Json {
  {
    "available": true,
    "ui_action": "runtime_service",
    "action": "runtime_service",
    "label": "Start Service",
    "context_path": "",
    "message": "",
    "status": status,
  }
}

///|
pub fn action_plan_recommended_commands(
  next_required_action : String,
) -> Array[Json] {
  match next_required_action {
    "dispatch_or_replay_runtime_commands" =>
      [
        action_plan_recommended_command(next_required_action),
        action_plan_runtime_service_command(
          "starting MoonClaw native MoonCode service",
        ),
      ]
    "retry_failed_runtime_dispatch" =>
      [
        action_plan_recommended_command(next_required_action),
        action_plan_runtime_service_command(
          "starting MoonClaw native MoonCode service for retry",
        ),
      ]
    "await_runtime_proof" =>
      [
        action_plan_recommended_command(next_required_action),
        action_plan_runtime_service_command(
          "starting MoonClaw native MoonCode service for proof refresh",
        ),
      ]
    "run_native_eval" =>
      [
        action_plan_recommended_command(next_required_action),
        action_plan_runtime_service_command(
          "starting MoonClaw native MoonCode service for eval proof",
        ),
      ]
    "resolve_tool_approvals" =>
      [
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "approve_tool",
          "label": "Approve Tool",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode tool approval",
        },
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "reject_tool",
          "label": "Reject Tool",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode tool rejection",
        },
      ]
    "accept_or_reject_changes" =>
      [
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "accept",
          "label": "Accept",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode accept from action plan",
        },
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "reject",
          "label": "Reject",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode reject from action plan",
        },
      ]
    "ready_for_book_review" =>
      [
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "package",
          "label": "Package",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode package from review-ready plan",
        },
        {
          "available": true,
          "ui_action": "mooncode_command",
          "action": "commit",
          "label": "Commit",
          "context_path": "",
          "message": "",
          "status": "queued MoonCode commit from review-ready plan",
        },
      ]
    _ => {
      let primary = action_plan_recommended_command(next_required_action)
      if json_bool(primary, "available", default=false) {
        [primary]
      } else {
        []
      }
    }
  }
}
