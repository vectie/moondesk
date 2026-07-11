///|
test "MoonFlow run ids reject path escapes" {
  assert_true(moonflow_safe_run_id("flow-selene-r1"))
  assert_false(moonflow_safe_run_id("../flow-secret"))
  assert_false(moonflow_safe_run_id("nested/flow"))
  assert_false(moonflow_safe_run_id(""))
}

///|
test "MoonFlow runtime state remains under the suite root" {
  assert_eq(
    moonflow_runs_root("/Users/kq/moonsuite"),
    "/Users/kq/moonsuite/.moonsuite/products/moonflow/runs",
  )
}
