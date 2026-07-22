///|
fn flow_test_item(status : String) -> MoonFlowItemProjection {
  {
    work_item_id: "research",
    declaration_id: "decl-research",
    product_id: "moonwiki",
    requested_authority: "knowledge-write",
    acceptance_criteria: ["sources are reviewed"],
    depends_on: [],
    status,
    attempt_count: 1,
    request_id: "request-1",
    result_id: "result-1",
    active_attempt_id: "attempt-1",
    idempotency_key: "retry-1",
    external_job_id: "job-1",
    attempt_status: "completed",
    operation: "research",
    input_digest: "input-digest",
    output_digest: "output-digest",
    error_kind: "",
    compensable: false,
    blocker: "",
    acceptance_review_id: "review-1",
    acceptance_review_artifact: "evidence/review.json",
    acceptance_reviewer_id: "reviewer-1",
    artifacts: ["evidence/research.json"],
    approvals: ["reviewer-1"],
  }
}

///|
test "Flow exposes durable execution identities" {
  let item = flow_test_item("review")
  assert_eq(item.request_id, "request-1")
  assert_eq(item.result_id, "result-1")
  assert_eq(item.active_attempt_id, "attempt-1")
  assert_eq(item.idempotency_key, "retry-1")
  assert_eq(item.external_job_id, "job-1")
}

///|
test "Flow explains governed readiness and acceptance" {
  assert_eq(
    moonflow_item_explanation(flow_test_item("ready")),
    "Dependencies are accepted; the declared product may execute now",
  )
  assert_eq(
    moonflow_item_explanation(flow_test_item("accepted")),
    "Accepted by explicit review with bound output evidence",
  )
}

///|
test "Flow exposes failure reasons instead of a status-only dead end" {
  let blocked = { ..flow_test_item("blocked"), blocker: "source missing" }
  assert_eq(moonflow_item_explanation(blocked), "source missing")
  let failed = {
    ..flow_test_item("failed"),
    acceptance_review_id: "",
    blocker: "",
    error_kind: "tool-timeout",
  }
  assert_eq(
    moonflow_item_explanation(failed),
    "Execution reported tool-timeout",
  )
}

///|
test "Flow describes migrated checkpoints without a zero-attempt implication" {
  let item = {
    ..flow_test_item("accepted"),
    attempt_count: 0,
    attempt_status: "checkpoint-reused",
  }
  assert_eq(moonflow_item_execution_label(item), "checkpoint reused")
}

///|
test "Flow first-run action requires a selected MoonBook" {
  let (_, missing) = update_workspace_surface_actions(
    code_mode_test_dispatch,
    PrepareMoonFlow,
    init_model(),
  )
  assert_eq(missing.moonflow_status, "Select a MoonBook first")
  let (_, selected) = update_workspace_surface_actions(
    code_mode_test_dispatch,
    PrepareMoonFlow,
    { ..init_model(), selected_workspace_id: "book-demo" },
  )
  assert_true(selected.moonflow_status.contains("up to 30 seconds"))
}

///|
test "Flow canvas drag pans by the pointer delta" {
  let (_, started) = flow_pan_start_action(init_model(), 120, 80)
  assert_true(started.flow_pan_dragging)
  let (_, moved) = flow_pointer_move_action(started, 165, 105)
  assert_eq(moved.flow_pan_x, started.flow_pan_x + 45.0)
  assert_eq(moved.flow_pan_y, started.flow_pan_y + 25.0)
  let (_, ended) = flow_pointer_end_action(moved)
  assert_false(ended.flow_pan_dragging)
}

///|
test "Flow node drag exclusively claims the canvas gesture" {
  let item : MoonFlowCompositionItem = {
    work_item_id: "research",
    declaration_id: "decl-research",
    product_id: "moonwiki",
    requested_authority: "knowledge-write",
    acceptance_criteria: ["sources are reviewed"],
    depends_on: [],
    operation: "research",
    input_contracts: [],
    output_contracts: [],
    required_claim: "",
    input_artifacts: [],
    timeout_ms: 30000,
  }
  let model = {
    ..init_model(),
    moonflow_composition: Some({
      contract_id: "composition-v1",
      workspace_id: "book-demo",
      source_graph_id: "graph-1",
      book_id: "demo",
      declaration_revision: "1",
      source_digest: "digest",
      status: "draft",
      selected_item_ids: ["research"],
      items: [item],
    }),
  }
  let (_, dragging) = flow_node_drag_start_action(model, "research", 100, 80)
  assert_eq(dragging.flow_drag_node_id, "research")
  assert_false(dragging.flow_pan_dragging)
  let (_, still_dragging) = flow_pan_start_action(dragging, 100, 80)
  assert_eq(still_dragging.flow_drag_node_id, "research")
  assert_false(still_dragging.flow_pan_dragging)
  let (old_x, old_y) = flow_item_position(model, [item][0:1], "research")
  let (_, moved) = flow_pointer_move_action(still_dragging, 132, 104)
  let (new_x, new_y) = flow_item_position(moved, [item][0:1], "research")
  assert_eq(new_x, old_x + 32.0)
  assert_eq(new_y, old_y + 24.0)
}

///|
test "Flow import status keeps the durable run or next action visible" {
  let decoded : MoonFlowImportResult = @json.from_json({
    "book_id": "book-demo",
    "run_id": "run-demo-r1",
    "ok": true,
    "status": "imported",
    "message": "Executable document imported into MoonFlow",
    "api_contract": "moonsuite.phase6.v1",
    "next_action": "open_run",
  })
  assert_eq(decoded.run_id, "run-demo-r1")
  assert_eq(
    moonflow_import_status({
      ok: true,
      status: "imported",
      message: "Executable document imported into MoonFlow",
      next_action: "open_run",
      book_id: "book-demo",
      run_id: "run-demo-r1",
    }),
    "Executable document imported into MoonFlow · run run-demo-r1",
  )
  assert_eq(
    moonflow_import_status({
      ok: false,
      status: "declaration_missing",
      message: "This MoonBook has no executable Work graph yet",
      next_action: "create_executable_document_in_wiki",
      book_id: "book-demo",
      run_id: "",
    }),
    "This MoonBook has no executable Work graph yet · next: create executable document in wiki",
  )
}

///|
test "Flow handoff availability follows the product registry" {
  let model = {
    ..init_model(),
    moonsuite_products: [
      { name: "MoonTown", status: "installed" },
      { name: "MoonRobo", status: "missing" },
    ],
  }
  assert_true(moonsuite_product_available(model, "moontown"))
  assert_false(moonsuite_product_available(model, "MoonRobo"))
}

///|
test "Flow scopes suite-wide runs to the selected MoonBook root" {
  assert_true(
    moonflow_book_root_matches(
      "/Users/kq/moonsuite/books/unified-lunar-robot", "unified-lunar-robot",
    ),
  )
  assert_false(
    moonflow_book_root_matches(
      "/Users/kq/moonsuite/books/unified-lunar-robot", "lunar-robot-autonomy-v3",
    ),
  )
  assert_true(moonflow_book_root_matches("books\\demo", "demo"))
}
