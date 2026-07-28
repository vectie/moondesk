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
test "mooncode ordinary mutation preserves the selected session watch" {
  assert_eq(
    mooncode_session_effect_labels(mooncode_session_mutation_effects(false)).join(
      "|",
    ),
    "fetch-sessions:|sync-shell",
  )
}

///|
test "mooncode first session mutation starts exactly one watch" {
  assert_eq(
    mooncode_session_effect_labels(mooncode_session_mutation_effects(true)).join(
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

///|
test "mooncode watch ownership rejects stale timers and inactive modes" {
  let current = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_watch_generation: 7,
  }
  assert_true(mooncode_watch_is_current(current, 7, "session-a"))
  assert_false(mooncode_watch_is_current(current, 6, "session-a"))
  assert_false(mooncode_watch_is_current(current, 7, "session-b"))
  assert_false(mooncode_watch_is_current(current, 7, ""))
  assert_false(
    mooncode_watch_is_current(
      { ..current, workspace_mode: MoonWiki },
      7,
      "session-a",
    ),
  )
}

///|
test "typed selected-session response decoder accepts command result" {
  let payload : Json = {
    "id": "session-ui",
    "workspace_id": "book-demo",
    "workspace_name": "Demo",
    "workspace_root": "/tmp/demo",
    "cwd": "/tmp/demo",
    "source": "moonclaw-canonical-session",
    "mooncode_runtime_session_id": "session-ui",
    "title": "Demo",
    "model": "codex/gpt-5",
    "status": "running",
    "queued_count": 0,
    "archived": false,
    "created_at": "2026-07-28T00:00:00Z",
    "updated_at": "2026-07-28T00:00:00Z",
    "last_message": "Fix it",
    "component": "mooncode",
    "protocol": "mooncode.v1",
    "client_turn_id": "client-ui",
    "turn_id": "turn-ui",
    "mooncode_turn": null,
    "mooncode_conversation": null,
    "mooncode_summary": {
      "event_count": 0,
      "verified_test_count": 0,
      "pending_diff_count": 0,
    },
    "canonical_revision": 0,
    "canonical_unchanged": false,
  }
  guard decode_mooncode_selected_session(payload) is Ok(session) else {
    fail("expected typed selected-session response")
  }
  assert_eq(session.id, "session-ui")
}

///|
test "typed selected-session response decoder rejects malformed response" {
  assert_true(decode_mooncode_selected_session({ "id": 42 }) is Err(_))
}
