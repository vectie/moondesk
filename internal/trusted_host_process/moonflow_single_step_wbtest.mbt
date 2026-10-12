///|
test "single step host has only fixed execute and reconcile arguments" {
  let execute = ExecuteOne(
    run_id="run-one",
    item_id="selected",
    request_id="action-one",
    recorded_at="2026-10-07T00:00:00Z",
  )
  assert_eq(
    moonflow_single_step_arguments("/tmp/suite", "trusted/step.json", execute).unwrap(),
    [
      "execute-one", "/tmp/suite", "run-one", "selected", "action-one", "trusted/step.json",
      "2026-10-07T00:00:00Z",
    ],
  )
  assert_eq(
    moonflow_single_step_arguments(
      "/tmp/suite",
      "trusted/step.json",
      ReconcileOne(
        run_id="run-one",
        item_id="selected",
        request_id="action-one",
        recorded_at="2026-10-07T00:00:00Z",
      ),
    ).unwrap()[0],
    "reconcile-one",
  )
  for
    config in [
      "../secret", "/absolute/config", "trusted/../escape", "trusted//step", "$(command)",
      "--execute",
    ] {
    assert_true(
      moonflow_single_step_arguments("/tmp/suite", config, execute) is Err(_),
    )
  }
  assert_true(
    moonflow_single_step_arguments(
      "/tmp/../suite", "trusted/step.json", execute,
    )
    is Err(_),
  )
  assert_true(
    moonflow_single_step_arguments(
      "/tmp/suite",
      "trusted/step.json",
      ExecuteOne(
        run_id="--run",
        item_id="selected",
        request_id="action-one",
        recorded_at="2026-10-07T00:00:00Z",
      ),
    )
    is Err(_),
  )
  assert_false(
    moonflow_single_step_help_compatible("execute-one reconcile-one"),
  )
  assert_true(
    moonflow_single_step_help_compatible(
      "moonflow execute-one <workspace> <run-id> <item-id> <request-id> <configuration-ref> <recorded-at>\nmoonflow reconcile-one <workspace> <run-id> <item-id> <request-id> <configuration-ref> <recorded-at>",
    ),
  )
}
