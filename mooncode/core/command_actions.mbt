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
fn command_action_contract_json() -> Json {
  {
    "kind": "mooncode-command-action-contract",
    "protocol": protocol_version(),
    "contract_id": command_action_contract_id(),
    "turn_actions": command_turn_actions(),
    "advertised_actions": command_advertised_actions(),
    "supported_actions": command_supported_actions(),
  }
}

///|
fn command_advertised_actions() -> Array[String] {
  [
    command_prompt(),
    command_steer(),
    command_run_tests(),
    command_run_build(),
    command_run_eval(),
    command_package(),
    command_commit(),
    command_accept(),
    command_reject(),
    command_approve_tool(),
    command_reject_tool(),
    command_apply_patch(),
    command_revert_patch(),
    command_cancel(),
  ]
}
