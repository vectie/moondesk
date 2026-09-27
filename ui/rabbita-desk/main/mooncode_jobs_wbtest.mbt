///|
#warnings("-alert_unstable")
test "Code job history shows failed and interrupted runs for selected session only" {
  let session = code_mode_test_session("session-a", workspace_id="book-a")
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
  }
  let (_, opened) = update_mooncode_actions(
    code_mode_test_dispatch,
    ToggleMoonCodeJobs,
    model,
  )
  assert_true(opened.mooncode_jobs_visible)
  assert_true(opened.mooncode_jobs_loading)
  let history : MoonCodeJobHistory = {
    kind: "mooncode-job-history.v1",
    owner: "moonclaw",
    session_id: "session-a",
    job_count: 2,
    truncated: false,
    jobs: [
      {
        run_id: "run-2",
        service_id: "service",
        status: "interrupted",
        started_at: "2026-09-26T00:02:00Z",
        finished_at: "",
        ran_turn_count: 0,
        failed_turn_count: 0,
        stopped_by: "",
        detail: "",
      },
      {
        run_id: "run-1",
        service_id: "service",
        status: "failed",
        started_at: "2026-09-26T00:00:00Z",
        finished_at: "2026-09-26T00:01:00Z",
        ran_turn_count: 0,
        failed_turn_count: 1,
        stopped_by: "",
        detail: "executor unavailable",
      },
    ],
  }
  let (_, stale) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedMoonCodeJobs("session-b", Ok(history)),
    opened,
  )
  assert_true(stale.mooncode_jobs_loading)
  let (_, loaded) = update_mooncode_actions(
    code_mode_test_dispatch,
    LoadedMoonCodeJobs("session-a", Ok(history)),
    opened,
  )
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_job_history(code_mode_test_dispatch, loaded),
    ),
  )
  assert_true(markup.contains("data-status=\"interrupted\""))
  assert_true(markup.contains("data-status=\"failed\""))
  assert_true(markup.contains("data-i18n=\"code.job_history\""))
  assert_true(markup.contains("data-i18n=\"code.job_interrupted\""))
  assert_true(markup.contains("data-i18n=\"code.job_turns\""))
  assert_true(markup.contains("executor unavailable"))
  assert_false(markup.contains("Completed"))
  let switched = { ..loaded, selected_mooncode_session_id: "session-b", }
  let switched_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_mooncode_job_history(code_mode_test_dispatch, switched),
    ),
  )
  assert_false(switched_markup.contains("executor unavailable"))
}
