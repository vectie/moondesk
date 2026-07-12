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

///|
test "MoonFlow lists the newest declaration revision first" {
  let projections : Array[Json] = [
    { "run_id": "flow-robot-r1", "declaration_revision": "r1" },
    { "run_id": "flow-robot-r2", "declaration_revision": "r2" },
    { "run_id": "flow-robot-r10", "declaration_revision": "r10" },
  ]
  sort_moonflow_projections(projections)
  assert_eq(json_string(projections[0], "run_id", default=""), "flow-robot-r10")
}
