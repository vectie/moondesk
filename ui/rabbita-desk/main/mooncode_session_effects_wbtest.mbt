///|
fn mooncode_session_effect_label(effect : MoonCodeSessionEffect) -> String {
  match effect {
    MoonCodeFetchDaemon => "fetch-daemon"
    MoonCodeFetchModels => "fetch-models"
    MoonCodeFetchSessions(workspace_id) => "fetch-sessions:\{workspace_id}"
    MoonCodeStartWatch => "start-watch"
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
test "mooncode submit does not create a second selected-session fetch loop" {
  assert_eq(
    mooncode_session_effect_labels(mooncode_user_submit_effects()).join("|"),
    "sync-shell",
  )
}

///|
test "mooncode mutation resumes one watch and refreshes metadata" {
  assert_eq(
    mooncode_session_effect_labels(mooncode_session_mutation_effects()).join(
      "|",
    ),
    "fetch-sessions:|start-watch|sync-shell",
  )
}

///|
test "mooncode metadata refresh never hydrates selected conversation" {
  assert_eq(
    mooncode_session_effect_labels(mooncode_metadata_refresh_effects()).join(
      "|",
    ),
    "fetch-daemon|fetch-models|fetch-sessions:",
  )
}

///|
test "mooncode selection starts exactly one canonical watch" {
  assert_eq(
    mooncode_session_effect_labels(mooncode_selected_session_effects()).join(
      "|",
    ),
    "start-watch",
  )
}
