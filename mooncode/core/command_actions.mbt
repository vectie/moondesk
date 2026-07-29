///|
fn command_action_contract_id() -> String {
  "mooncode-command-actions.v1"
}

///|
fn command_prompt() -> String {
  "prompt"
}

///|
fn command_steer() -> String {
  "steer"
}

///|
fn command_run_tests() -> String {
  "run_tests"
}

///|
fn command_run_build() -> String {
  "run_build"
}

///|
fn command_run_eval() -> String {
  "run_eval"
}

///|
fn command_package() -> String {
  "package"
}

///|
fn command_commit() -> String {
  "commit"
}

///|
fn command_accept() -> String {
  "accept"
}

///|
fn command_reject() -> String {
  "reject"
}

///|
fn command_approve_tool() -> String {
  "approve_tool"
}

///|
fn command_reject_tool() -> String {
  "reject_tool"
}

///|
fn command_apply_patch() -> String {
  "apply_patch"
}

///|
fn command_revert_patch() -> String {
  "revert_patch"
}

///|
fn command_cancel() -> String {
  "cancel"
}

///|
fn command_note() -> String {
  "note"
}

///|
fn command_turn_actions() -> Array[String] {
  [command_prompt(), command_steer(), command_cancel()]
}

///|
fn command_supported_actions() -> Array[String] {
  let actions = command_advertised_actions()
  actions.push(command_note())
  actions
}

///|
fn command_action_is_advertised(action : String) -> Bool {
  command_advertised_actions().contains(action)
}

///|
fn command_action_is_turn(action : String) -> Bool {
  command_turn_actions().contains(action)
}

///|
fn command_action_is_prompt_or_steer(action : String) -> Bool {
  action == command_prompt() || action == command_steer()
}

///|
fn command_action_is_cancel(action : String) -> Bool {
  action == command_cancel()
}

///|
fn command_action_is_test(action : String) -> Bool {
  action == command_run_tests() || action == command_run_build()
}

///|
fn command_action_is_eval(action : String) -> Bool {
  action == command_run_eval()
}

///|
fn command_action_is_package(action : String) -> Bool {
  action == command_package()
}

///|
fn command_action_is_commit(action : String) -> Bool {
  action == command_commit()
}

///|
fn command_action_is_review_decision(action : String) -> Bool {
  action == command_accept() || action == command_reject()
}

///|
fn command_action_is_tool_approval(action : String) -> Bool {
  action == command_approve_tool() || action == command_reject_tool()
}

///|
fn command_action_is_patch(action : String) -> Bool {
  action == command_apply_patch() || action == command_revert_patch()
}

///|
fn command_action_requires_tool_harness(action : String) -> Bool {
  command_action_is_prompt_or_steer(action) ||
  action == command_run_tests() ||
  command_action_is_eval(action) ||
  command_action_is_package(action) ||
  command_action_is_commit(action) ||
  action == command_accept() ||
  command_action_is_patch(action)
}

///|
fn command_action_requires_runtime_completion_proof(
  action : String,
) -> Bool {
  action == command_run_tests() ||
  command_action_is_eval(action) ||
  command_action_is_package(action) ||
  command_action_is_commit(action) ||
  command_action_is_review_decision(action) ||
  command_action_is_patch(action) ||
  command_action_is_tool_approval(action)
}

///|
fn command_action_writes_review_receipt(action : String) -> Bool {
  command_action_is_review_decision(action) ||
  command_action_is_package(action) ||
  command_action_is_commit(action) ||
  command_action_is_tool_approval(action) ||
  command_action_is_patch(action)
}

///|
fn command_action_tool_hints(action : String) -> Array[String] {
  if command_action_is_test(action) {
    [
      runtime_tool_moon_ide(),
      runtime_tool_moon_cmd(),
      runtime_tool_moon_check(),
      runtime_tool_shell(),
    ]
  } else if command_action_is_eval(action) {
    [
      runtime_tool_eval_harness(),
      runtime_tool_moon_ide(),
      runtime_tool_moon_cmd(),
      runtime_tool_shell(),
      runtime_tool_moon_check(),
    ]
  } else if command_action_is_package(action) {
    [
      runtime_tool_package_app_tool(),
      runtime_tool_moon_ide(),
      runtime_tool_moon_cmd(),
      runtime_tool_moon_check(),
      runtime_tool_shell(),
    ]
  } else if command_action_is_commit(action) {
    [
      runtime_tool_read(),
      runtime_tool_moon_ide(),
      runtime_tool_moon_cmd(),
      runtime_tool_moon_check(),
      runtime_tool_shell(),
      runtime_tool_finish(),
    ]
  } else if action == command_accept() {
    [runtime_tool_finish(), runtime_tool_package_app_tool()]
  } else if action == command_reject() {
    [runtime_tool_finish()]
  } else if command_action_is_tool_approval(action) {
    [
      runtime_tool_read(),
      runtime_tool_edit(),
      runtime_tool_write(),
      runtime_tool_shell(),
      runtime_tool_moon_ide(),
      runtime_tool_moon_cmd(),
      runtime_tool_moon_check(),
    ]
  } else if action == command_apply_patch() {
    [
      runtime_tool_moon_ide(),
      runtime_tool_apply_patch(),
      runtime_tool_moon_cmd(),
      runtime_tool_moon_check(),
    ]
  } else if action == command_revert_patch() {
    [
      runtime_tool_moon_ide(),
      runtime_tool_revert_patch(),
      runtime_tool_moon_cmd(),
      runtime_tool_moon_check(),
    ]
  } else if command_action_is_prompt_or_steer(action) {
    [
      runtime_tool_moon_ide(),
      runtime_tool_read(),
      runtime_tool_edit(),
      runtime_tool_write(),
      runtime_tool_shell(),
      runtime_tool_moon_cmd(),
      runtime_tool_moon_check(),
      runtime_tool_finish(),
    ]
  } else {
    []
  }
}

///|
fn command_action_expected_lanes(action : String) -> Array[String] {
  if command_action_is_test(action) {
    [event_lane_test(), event_lane_tool(), event_lane_runtime()]
  } else if command_action_is_eval(action) {
    [event_lane_runtime(), event_lane_test(), event_lane_review()]
  } else if command_action_is_package(action) {
    [event_lane_artifact(), event_lane_test(), event_lane_review()]
  } else if command_action_is_commit(action) {
    [event_lane_review(), event_lane_runtime(), event_lane_tool()]
  } else if command_action_is_review_decision(action) {
    [event_lane_review(), event_lane_artifact()]
  } else if command_action_is_tool_approval(action) {
    [event_lane_tool(), event_lane_runtime(), event_lane_review()]
  } else if command_action_is_patch(action) {
    [event_lane_diff(), event_lane_test(), event_lane_review()]
  } else if command_action_is_prompt_or_steer(action) {
    event_lanes()
  } else if command_action_is_cancel(action) {
    [event_lane_runtime()]
  } else {
    [event_lane_runtime()]
  }
}

///|
fn command_action_lane(action : String) -> String {
  if command_action_is_test(action) || command_action_is_eval(action) {
    event_lane_test()
  } else if command_action_is_package(action) {
    event_lane_artifact()
  } else if command_action_is_commit(action) ||
    command_action_is_review_decision(action) ||
    command_action_is_tool_approval(action) ||
    command_action_is_patch(action) {
    event_lane_review()
  } else {
    event_lane_runtime()
  }
}

///|
fn command_action_title(action : String, status : String) -> String {
  let label = if action == command_run_tests() {
    "Run tests"
  } else if action == command_run_build() {
    "Run build"
  } else if action == command_run_eval() {
    "Run eval"
  } else if action == command_package() {
    "Package result"
  } else if action == command_commit() {
    "Commit result"
  } else if action == command_accept() {
    "Accept result"
  } else if action == command_reject() {
    "Reject result"
  } else if action == command_approve_tool() {
    "Approve tool"
  } else if action == command_reject_tool() {
    "Reject tool"
  } else if action == command_apply_patch() {
    "Apply patch"
  } else if action == command_revert_patch() {
    "Revert patch"
  } else if action == command_cancel() {
    "Cancel session"
  } else if action == command_prompt() {
    "Prompt"
  } else if action == command_steer() {
    "Steer"
  } else {
    "Note"
  }
  "\{label}: \{status}"
}

///|
fn command_action_contract_json() -> Json {
  {
    "kind": "mooncode-command-action-contract",
    "protocol": protocol_version(),
    "contract_id": command_action_contract_id(),
    "event_lane_contract_id": event_lane_contract_id(),
    "runtime_event_name_contract_id": runtime_event_name_contract_id(),
    "turn_actions": command_turn_actions(),
    "advertised_actions": command_advertised_actions(),
    "supported_actions": command_supported_actions(),
    "actions": command_advertised_actions().map(action => {
      command_action_json(action)
    }),
    "rules": [
      "mooncode/core owns the supported MoonCode command action vocabulary", "internal MoonCode may execute action-specific behavior but must not publish a second command list",
      "prompt, steer, and cancel are ordered turn-control commands", "operator/review actions must remain command-scoped before they can write review receipts",
      "native runtime progress must reference this command contract plus the event lane and runtime event-name contracts",
    ],
  }
}

///|
fn command_action_json(action : String) -> Json {
  {
    "action": action,
    "control": command_action_control(action),
    "approval": command_action_approval(action),
    "lane": command_action_lane(action),
    "expected_lanes": command_action_expected_lanes(action),
    "tool_hints": command_action_tool_hints(action),
    "requires_tool_harness": command_action_requires_tool_harness(action),
    "requires_runtime_completion_proof": command_action_requires_runtime_completion_proof(
      action,
    ),
    "writes_review_receipt": command_action_writes_review_receipt(action),
  }
}
