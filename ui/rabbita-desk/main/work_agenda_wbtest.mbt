///|
fn work_agenda_test_goal(
  id : String,
  next_due_tick : Int,
  enabled : Bool,
) -> StandingGoalRecord {
  {
    id,
    title: "Goal " + id,
    prompt: "Check useful changes",
    target_book_id: "book-one",
    cadence_ticks: 60,
    next_due_tick,
    last_run_tick: Json::null(),
    enabled,
    source_policy: "mixed",
    review_policy: "bookkeeper_review",
  }
}

///|
test "work agenda groups due upcoming and paused work without mutating input" {
  let goals = [
    work_agenda_test_goal("later", 12, true),
    work_agenda_test_goal("paused", 1, false),
    work_agenda_test_goal("now", 5, true),
  ]
  let items = work_agenda_items(goals, 5)
  assert_true(items[0].state is AgendaDue)
  assert_eq(items[0].goal.id, "now")
  assert_true(items[1].state is AgendaUpcoming)
  assert_eq(items[1].goal.id, "later")
  assert_true(items[2].state is AgendaPaused)
  assert_eq(items[2].goal.id, "paused")
  assert_eq(goals[0].id, "later")
}

///|
#warnings("-alert_unstable")
test "work agenda renders normal-language schedule and recent results" {
  let model = {
    ..init_model(),
    standing_goals: [
      work_agenda_test_goal("due", 2, true),
      work_agenda_test_goal("later", 9, true),
    ],
    town_progress: Some({
      daemon_tick: 3,
      daemon_running: true,
      daemon_status: "running",
      supervision_enabled: true,
      due_goal_count: 1,
      next_due_tick: 9,
      request_count: 0,
      message_count: 0,
      dispatch_count: 0,
      run_count: 1,
      latest_request: "",
      latest_message: "",
      latest_dispatch: "",
      latest_run: "run-one",
      latest_run_status: "completed",
      latest_run_artifacts: 1,
    }),
    runs: [
      @desk.run_projection(
        run_id="run-one",
        book_id="book-one",
        status="completed",
        phase="done",
        summary="Weekly brief updated",
        artifacts=[],
      ),
    ],
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_work_agenda(code_mode_test_dispatch, model)),
  )
  assert_true(markup.contains("Agenda"))
  assert_true(markup.contains("Due now"))
  assert_true(markup.contains("Upcoming"))
  assert_true(markup.contains("Weekly brief updated"))
  assert_true(markup.contains("Completed"))
  assert_false(markup.contains("tick"))
}
