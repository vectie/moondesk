///|
fn mooncode_session_effect_label(effect : MoonCodeSessionEffect) -> String {
  match effect {
    MoonCodeFetchDaemon => "fetch-daemon"
    MoonCodeFetchSessions(workspace_id) => "fetch-sessions:\{workspace_id}"
    MoonCodeFetchSelectedSession => "fetch-selected-session"
    MoonCodeFetchSession(session_id) => "fetch-session:\{session_id}"
    MoonCodeScheduleFastPoll(generation) => "fast-poll:\{generation}"
    MoonCodeSchedulePoll(generation) => "poll:\{generation}"
    MoonCodeSyncShell => "sync-shell"
  }
}

///|
fn mooncode_session_effect_labels(
  effects : Array[MoonCodeSessionEffect],
) -> Array[String] {
  let labels : Array[String] = []
  for effect in effects {
    labels.push(mooncode_session_effect_label(effect))
  }
  labels
}

///|
test "mooncode session effects own submit acknowledgement followups" {
  let model = { ..init_model(), selected_workspace_id: "book-demo" }
  let labels = mooncode_session_effect_labels(
    mooncode_session_mutation_effects(model, "session-a"),
  )
  assert_eq(labels.join("|"), "fetch-session:session-a|sync-shell")
}

///|
test "mooncode user submit effects fetch selected session immediately" {
  let model = { ..init_model(), selected_mooncode_session_id: "session-a" }
  assert_eq(
    mooncode_session_effect_labels(mooncode_user_submit_effects(model, 4)).join(
      "|",
    ),
    "fetch-selected-session|fast-poll:4|sync-shell",
  )
}

///|
test "mooncode new-chat submit discovers the native session without hydrating an old selection" {
  let model = { ..init_model(), selected_mooncode_session_id: "" }
  assert_eq(
    mooncode_session_effect_labels(mooncode_user_submit_effects(model, 7)).join(
      "|",
    ),
    "fetch-sessions:|fast-poll:7|sync-shell",
  )
}

///|
test "mooncode session effects own poll plans" {
  let model = { ..init_model(), selected_workspace_id: "book-demo" }
  assert_eq(
    mooncode_session_effect_labels(mooncode_poll_effects(model, 2)).join("|"),
    "fetch-daemon|fetch-sessions:|fetch-selected-session|poll:2",
  )
}

///|
test "mooncode poll refreshes selected session" {
  let session = code_mode_test_session("session-a", workspace_id="book-demo")
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: session.id,
    mooncode_sessions: [session],
  }
  assert_eq(
    mooncode_session_effect_labels(mooncode_poll_effects(model, 3)).join("|"),
    "fetch-daemon|fetch-sessions:|fetch-selected-session|poll:3",
  )
}

///|
test "mooncode poll stays fast while draft prompt is pending" {
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    mooncode_new_chat_active: true,
  }
  let draft = mooncode_draft_session_id(base)
  let model = {
    ..base,
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      draft,
      "first prompt",
      client_turn_id="client-turn-draft",
    ),
  }
  assert_eq(
    mooncode_session_effect_labels(mooncode_poll_effects(model, 5)).join("|"),
    "fetch-sessions:|fast-poll:5",
  )
}

///|
test "mooncode poll stays fast while selected turn is unfinished" {
  let session = {
    ..code_mode_test_session(
      "session-a",
      workspace_id="book-demo",
      status="running",
    ),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn("command-first", "First prompt", status="running"),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: session.id,
    mooncode_sessions: [session],
  }
  assert_eq(
    mooncode_session_effect_labels(mooncode_poll_effects(model, 6)).join("|"),
    "fetch-selected-session|fast-poll:6",
  )
}

///|
test "mooncode poll ignores stale running session after completed turn" {
  let session = {
    ..code_mode_test_session(
      "session-a",
      workspace_id="book-demo",
      status="running",
      queued_count=1,
    ),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "First prompt",
          assistant="First answer",
          status="done",
        ),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: session.id,
    mooncode_sessions: [session],
  }
  assert_eq(
    mooncode_session_effect_labels(mooncode_poll_effects(model, 8)).join("|"),
    "fetch-daemon|fetch-sessions:|fetch-selected-session|poll:8",
  )
}
