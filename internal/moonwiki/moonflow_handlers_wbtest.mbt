///|
test "MoonFlow run ids reject path escapes" {
  assert_true(moonflow_safe_run_id("flow-selene-r1"))
  assert_false(moonflow_safe_run_id("../flow-secret"))
  assert_false(moonflow_safe_run_id("nested/flow"))
  assert_false(moonflow_safe_run_id(""))
}

///|
test "MoonFlow execution boundary is fail closed" {
  assert_false(execution_sandbox_client_available())
  assert_eq(
    execution_sandbox_unavailable_message(),
    "Execution sandbox is unavailable; MoonDesk refused host execution",
  )
}

///|
test "MoonFlow import reports canonical Work graph identity" {
  assert_eq(
    moonflow_graph_run_id({
      "graph_id": "robot-r2",
      "run_id": "legacy-wrong-value",
    }),
    "robot-r2",
  )
  assert_eq(moonflow_graph_run_id({ "run_id": "legacy-r1" }), "legacy-r1")
}

///|
async test "MoonFlow projections expose safe default run controls" {
  let root = "/tmp/moondesk-moonflow-control-projection"
  if !@fs.exists(root) {
    @fs.mkdir(root, permission=0o755, recursive=true)
  }
  let projection : Json = {
    "protocol": "moonflow.run-projection.v3",
    "run_id": "flow-control-r1",
  }
  let enriched = moonflow_enriched_projection(root, projection)
  let text = enriched.stringify()
  assert_true(text.contains("\"run_control\""))
  assert_true(text.contains("\"state\":\"running\""))
  assert_true(text.contains("\"authority_ceiling\":\"\""))
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
