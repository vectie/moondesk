///|
test "Code composer task purpose survives real typed encode and decode" {
  for intent in ["auto", "read_only", "workspace_change"] {
    let (_, model) = update_mooncode_actions(
      fn(_msg) { @rabbita.none },
      SetMoonCodeTaskIntent(intent),
      init_model(),
    )
    assert_eq(model.mooncode_task_intent, intent)
    let submission = mooncode_submission_with_task_intent(
      {
        "action": "prompt",
        "client_turn_id": "ui-intent-" + intent,
        "message": "Review this code; do not edit or fix any files",
      },
      model.mooncode_task_intent,
    )
    guard typed_mooncode_command_body(submission) is Ok(encoded) else {
      fail("UI command must encode")
    }
    println("R7_UI_ENCODED:" + encoded.stringify())
    guard @mooncode_core.decode_mooncode_command(encoded) is Ok(command) else {
      fail("UI command must decode")
    }
    assert_eq(
      command.task_intent.map(value => value.to_string()),
      if intent == "auto" {
        None
      } else {
        Some(intent)
      },
    )
  }
}

///|
test "Code task purpose resets on accepted send but remains after failure" {
  let session = code_mode_test_session("intent-session", status="done")
  let model = {
    ..init_model(),
    selected_mooncode_session_id: session.id,
    mooncode_sessions: [session],
    mooncode_task_intent: "read_only",
    mooncode_task_intent_submit_pending: true,
    mooncode_image_submit_revision: 4,
    mooncode_draft_revision: 4,
  }
  let (_, success) = update_mooncode_session_results(
    fn(_msg) { @rabbita.none },
    CompletedMoonCodeCommand(Ok(session)),
    model,
  )
  assert_eq(success.mooncode_task_intent, "auto")
  assert_false(success.mooncode_task_intent_submit_pending)
  let (_, failed) = update_mooncode_session_results(
    fn(_msg) { @rabbita.none },
    CompletedMoonCodeCommand(Err("network unavailable")),
    model,
  )
  assert_eq(failed.mooncode_task_intent, "read_only")
  assert_false(failed.mooncode_task_intent_submit_pending)
  let (_, created) = update_mooncode_session_results(
    fn(_msg) { @rabbita.none },
    CreatedMoonCodeSession(Ok(session)),
    model,
  )
  assert_eq(created.mooncode_task_intent, "auto")
  let (_, creation_failed) = update_mooncode_session_results(
    fn(_msg) { @rabbita.none },
    CreatedMoonCodeSession(Err("network unavailable")),
    model,
  )
  assert_eq(creation_failed.mooncode_task_intent, "read_only")
}

///|
test "Code task mode follows a new draft and does not leak across reopened sessions" {
  let first = code_mode_test_session("first", status="done")
  let second = code_mode_test_session("second", status="done")
  let model = {
    ..init_model(),
    selected_mooncode_session_id: first.id,
    mooncode_sessions: [first, second],
    mooncode_task_intent: "read_only",
  }
  let same = mooncode_select_session_model(model, first.id)
  assert_eq(same.mooncode_task_intent, "read_only")
  let switched = mooncode_select_session_model(same, second.id)
  assert_eq(switched.mooncode_task_intent, "auto")
  let reopened = mooncode_select_session_model(switched, first.id)
  assert_eq(reopened.mooncode_task_intent, "auto")
  let (_, fresh) = update_mooncode_session_actions(
    fn(_msg) { @rabbita.none },
    NewMoonCodeSession,
    model,
  )
  assert_eq(fresh.mooncode_task_intent, "auto")
  let (_, invalid) = update_mooncode_session_actions(
    fn(_msg) { @rabbita.none },
    SetMoonCodeTaskIntent("invalid"),
    model,
  )
  assert_eq(invalid.mooncode_task_intent, "read_only")
  let (_, selected) = update_mooncode_session_actions(
    fn(_msg) { @rabbita.none },
    SetMoonCodeTaskIntent("workspace_change"),
    {
      ..model,
      mooncode_task_intent_submit_pending: true,
      mooncode_image_submit_revision: model.mooncode_draft_revision,
    },
  )
  let (_, late_success) = update_mooncode_session_results(
    fn(_msg) { @rabbita.none },
    CompletedMoonCodeCommand(Ok(first)),
    selected,
  )
  assert_eq(late_success.mooncode_task_intent, "workspace_change")
  assert_eq(init_model().mooncode_task_intent, "auto")
}
