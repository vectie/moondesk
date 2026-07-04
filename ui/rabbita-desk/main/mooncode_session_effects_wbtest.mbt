///|
fn mooncode_session_effect_label(effect : MoonCodeSessionEffect) -> String {
  match effect {
    MoonCodeFetchDaemon => "fetch-daemon"
    MoonCodeFetchSessions(workspace_id) => "fetch-sessions:\{workspace_id}"
    MoonCodeFetchSelectedStream => "fetch-selected-stream"
    MoonCodeFetchStream(session_id, since) => "fetch-stream:\{session_id}:\{since}"
    MoonCodeStartRuntimeService(session_id) => "runtime-service:\{session_id}"
    MoonCodeScheduleFastPoll => "fast-poll"
    MoonCodeSchedulePoll => "poll"
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
  assert_eq(
    labels.join("|"),
    "runtime-service:session-a|fetch-sessions:book-demo|fetch-stream:session-a:0|fast-poll|poll|sync-shell",
  )
}

///|
test "mooncode session effects suppress runtime start in manual mode" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    mooncode_runtime_mode: "manual",
  }
  let labels = mooncode_session_effect_labels(
    mooncode_session_mutation_effects(model, "session-a"),
  )
  assert_eq(
    labels.join("|"),
    "fetch-sessions:book-demo|fetch-stream:session-a:0|fast-poll|poll|sync-shell",
  )
}

///|
test "mooncode session effects own poll and runtime settlement plans" {
  let model = { ..init_model(), selected_workspace_id: "book-demo" }
  assert_eq(
    mooncode_session_effect_labels(mooncode_poll_effects(model)).join("|"),
    "fetch-daemon|fetch-sessions:book-demo|fetch-selected-stream|poll",
  )
  assert_eq(
    mooncode_session_effect_labels(
      mooncode_runtime_started_effects(model, "session-a"),
    ).join("|"),
    "fetch-sessions:book-demo|fetch-stream:session-a:0|fast-poll|poll",
  )
  assert_eq(
    mooncode_session_effect_labels(
      mooncode_runtime_failed_effects(model, "session-a"),
    ).join("|"),
    "fetch-sessions:book-demo|fetch-stream:session-a:0|poll",
  )
}
