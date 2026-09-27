///|
#warnings("-alert_unstable")
test "Code schedule panel keeps MoonTown state scoped to selected MoonBook" {
  let model = { ..init_model(), selected_workspace_id: "book-a", }
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSchedules,
    model,
  )
  assert_true(opened.mooncode_schedules_visible)
  assert_true(opened.mooncode_schedules_loading)
  let state : MoonCodeScheduleState = {
    schema: "moontown.code-schedules.v1",
    revision: 2,
    schedules: [
      {
        id: "nightly-review",
        book_id: "book-a",
        book_root: "/tmp/book-a",
        session_id: "code-schedule-nightly-review",
        prompt: "Review changed code",
        model: "moongate/example",
        interval_seconds: 3600,
        enabled: true,
        next_due_at: 1700000000L,
        pending_command_id: "",
        last_command_id: "code-schedule-nightly-review-1699996400",
        last_status: "done",
        last_finished_at: 1699996400L,
      },
    ],
  }
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedMoonCodeSchedules(
      "book-b",
      opened.mooncode_schedules_generation,
      Ok(state),
    ),
    opened,
  )
  assert_true(stale.mooncode_schedules_loading)
  let (_, loaded) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedMoonCodeSchedules(
      "book-a",
      opened.mooncode_schedules_generation,
      Ok(state),
    ),
    opened,
  )
  assert_false(loaded.mooncode_schedules_loading)
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_schedules(code_mode_test_dispatch, loaded),
    ),
  )
  assert_true(markup.contains("nightly-review"))
  assert_true(markup.contains("Review changed code"))
  assert_true(markup.contains("data-i18n=\"code.schedule_next\""))
  let switched = { ..loaded, selected_workspace_id: "book-b", }
  let switched_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_schedules(code_mode_test_dispatch, switched),
    ),
  )
  assert_false(switched_markup.contains("nightly-review"))
}

///|
test "schedule read shows owner outage and ignores an old request after retry" {
  let model = { ..init_model(), selected_workspace_id: "book-a", }
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeSchedules,
    model,
  )
  match
    mooncode_schedule_decode_response(
      "{\"ok\":false,\"message\":\"MoonTown is not configured\"}",
    ) {
    Err(message) =>
      assert_eq(
        message, "MoonTown is not configured. Start its owner service, then refresh MoonDesk.",
      )
    Ok(_) => assert_false(true)
  }
  let (_, timed_out) = update_mooncode_actions(
    code_mode_test_dispatch,
    MoonCodeSchedulesTimedOut("book-a", opened.mooncode_schedules_generation),
    opened,
  )
  assert_false(timed_out.mooncode_schedules_loading)
  assert_eq(
    timed_out.mooncode_schedules_error,
    "MoonTown is unavailable. Your draft is safe; retry when it reconnects.",
  )
  let (_, retrying) = update_mooncode_actions(
    code_mode_test_dispatch,
    RefreshMoonCodeSchedules,
    timed_out,
  )
  assert_true(retrying.mooncode_schedules_loading)
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedMoonCodeSchedules(
      "book-a",
      opened.mooncode_schedules_generation,
      Err("old request"),
    ),
    retrying,
  )
  assert_true(stale.mooncode_schedules_loading)
  let (_, failed) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedMoonCodeSchedules(
      "book-a",
      retrying.mooncode_schedules_generation,
      Err(
        "MoonTown is unavailable. Your draft is safe; retry when it reconnects.",
      ),
    ),
    stale,
  )
  assert_false(failed.mooncode_schedules_loading)
  assert_true(failed.mooncode_schedules_error.contains("MoonTown"))
}

///|
test "schedule conversation action requires the exact MoonBook session" {
  let schedule : MoonCodeSchedule = {
    id: "review",
    book_id: "book-a",
    book_root: "/tmp/book-a",
    session_id: "code-schedule-review",
    prompt: "Review code",
    model: "example",
    interval_seconds: 60,
    enabled: true,
    next_due_at: 1L,
    pending_command_id: "",
    last_command_id: "",
    last_status: "done",
    last_finished_at: 0L,
  }
  let wrong_book = {
    ..code_mode_test_session(schedule.session_id, workspace_id="book-b"),
    cwd: "/tmp/book-b",
  }
  assert_false(
    mooncode_schedule_has_matching_session(
      { ..init_model(), mooncode_sessions: [wrong_book], },
      schedule,
    ),
  )
  let right_book = { ..wrong_book, workspace_id: "book-a", cwd: "/tmp/book-a", }
  assert_true(
    mooncode_schedule_has_matching_session(
      { ..init_model(), mooncode_sessions: [wrong_book, right_book], },
      schedule,
    ),
  )
}

///|
test "Code schedule pause preserves an unsent create draft" {
  let state : MoonCodeScheduleState = {
    schema: "moontown.code-schedules.v1",
    revision: 1,
    schedules: [],
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    mooncode_schedules_saving: true,
    mooncode_schedule_id_draft: "future-review",
    mooncode_schedule_prompt_draft: "Review tomorrow's changes",
  }
  let (_, paused) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedMoonCodeSchedule("book-a", false, Ok(state)),
    model,
  )
  assert_false(paused.mooncode_schedules_saving)
  assert_eq(paused.mooncode_schedule_id_draft, "future-review")
  assert_eq(paused.mooncode_schedule_prompt_draft, "Review tomorrow's changes")
  let (_, created) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedMoonCodeSchedule("book-a", true, Ok(state)),
    model,
  )
  assert_eq(created.mooncode_schedule_id_draft, "")
  assert_eq(created.mooncode_schedule_prompt_draft, "")
  let (_, switched) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedMoonCodeSchedule("book-a", false, Ok(state)),
    { ..model, selected_workspace_id: "book-b", },
  )
  assert_false(switched.mooncode_schedules_saving)
  assert_eq(switched.mooncode_schedule_id_draft, "future-review")
}

///|
test "duplicate schedule receipt gives a specific error and preserves draft" {
  let payload = @json.parse(
    "{\"error\":\"A Code schedule with this ID already exists.\"}",
  )
  let error = mooncode_schedule_mutation_payload_error(payload, true)
  assert_eq(error, "This schedule ID already exists. Choose another ID.")
  assert_eq(mooncode_schedule_error_key(error), "code.schedule_duplicate")
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    mooncode_schedules_saving: true,
    mooncode_schedule_id_draft: "already-used",
    mooncode_schedule_prompt_draft: "Review changes",
  }
  let (_, failed) = update_mooncode_actions(
    code_mode_test_dispatch,
    SavedMoonCodeSchedule("book-a", true, Err(error)),
    model,
  )
  assert_false(failed.mooncode_schedules_saving)
  assert_eq(failed.mooncode_schedule_id_draft, "already-used")
  assert_eq(failed.mooncode_schedule_prompt_draft, "Review changes")
}
