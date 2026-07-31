///|
test "Flow canvas drag pans by the pointer delta" {
  let (_, started) = flow_pan_start_action(init_model(), 120, 80)
  assert_true(started.flow_canvas.pan_dragging)
  let (_, moved) = flow_pointer_move_action(started, 165, 105)
  assert_eq(moved.flow_canvas.pan_x, started.flow_canvas.pan_x + 45.0)
  assert_eq(moved.flow_canvas.pan_y, started.flow_canvas.pan_y + 25.0)
  let (_, ended) = flow_pointer_end_action(moved)
  assert_false(ended.flow_canvas.pan_dragging)
}

///|
test "Flow canvas wheel keeps the active double-precision zoom path" {
  let (_, zoomed) = update_workspace_surface_actions(
    code_mode_test_dispatch,
    FlowCanvasWheel(-1.0),
    init_model(),
  )
  assert_true(zoomed.flow_canvas.zoom > 1.0)
}

///|
test "Flow node drag exclusively claims the canvas gesture" {
  let item : MoonFlowCompositionItem = {
    work_item_id: "research",
    declaration_id: "decl-research",
    product_id: "moonwiki",
    requested_authority: "knowledge-write",
    acceptance_criteria: ["sources reviewed"],
    depends_on: [],
    operation: "research",
    input_contracts: ["moonwiki/research-request@1.0.0"],
    output_contracts: ["moonwiki/research-evidence@1.0.0"],
    required_claim: "research-evidence",
    input_artifacts: ["requests/research.json"],
    timeout_ms: 30000,
    adapter_id: Some("moonwiki-adapter"),
    claim_ceiling: Some("accepted-knowledge"),
    review_required: Some(true),
    health_checked_at: Some("2026-07-31T00:00:00Z"),
    health_valid_until: Some("2026-08-01T00:00:00Z"),
    health_evidence_ref: Some("evidence/health.json"),
    health_evidence_digest: Some(
      "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    ),
  }
  let model = {
    ..init_model(),
    moonflow_composition: Some({
      selected_item_ids: ["research"],
      items: [item],
      catalog_id: Some("catalog-1"),
      catalog_status: Some("conformant"),
      evaluated_at: Some("2026-07-31T12:00:00Z"),
      validation_status: Some("accepted"),
      validation_issues: Some([]),
    }),
  }
  let (_, dragging) = flow_node_drag_start_action(model, "research", 100, 80)
  assert_eq(dragging.flow_canvas.drag_node_id, "research")
  assert_false(dragging.flow_canvas.pan_dragging)
  let (_, still_dragging) = flow_pan_start_action(dragging, 100, 80)
  assert_eq(still_dragging.flow_canvas.drag_node_id, "research")
  assert_false(still_dragging.flow_canvas.pan_dragging)
  let (old_x, old_y) = flow_item_position(model, [item][0:1], "research")
  let (_, moved) = flow_pointer_move_action(still_dragging, 132, 104)
  let (new_x, new_y) = flow_item_position(moved, [item][0:1], "research")
  assert_eq(new_x, old_x + 32.0)
  assert_eq(new_y, old_y + 24.0)
}

///|
test "Flow pointer end releases gesture ownership without discarding canvas layout" {
  let canvas = {
    ..init_flow_canvas_state(),
    pan_x: 48.0,
    pan_y: -24.0,
    zoom: 1.5,
    pan_dragging: true,
    drag_node_id: "research",
    node_positions: [("research", 128.0, 96.0)],
  }
  let (_, ended) = flow_pointer_end_action({
    ..init_model(),
    flow_canvas: canvas,
  })
  assert_false(ended.flow_canvas.pan_dragging)
  assert_eq(ended.flow_canvas.drag_node_id, "")
  assert_eq(ended.flow_canvas.pan_x, canvas.pan_x)
  assert_eq(ended.flow_canvas.pan_y, canvas.pan_y)
  assert_eq(ended.flow_canvas.zoom, canvas.zoom)
  assert_eq(ended.flow_canvas.node_positions, canvas.node_positions)
}

///|
fn flow_canvas_large_graph_item(
  index : Int,
  depends_on : Array[String],
) -> MoonFlowCompositionItem {
  {
    work_item_id: "stage-\{index}",
    declaration_id: "stage-\{index}-v1",
    product_id: "product-\{index % 11}",
    requested_authority: "workspace-mutation",
    acceptance_criteria: ["typed output accepted"],
    depends_on,
    operation: "product/operation-\{index}@1.0.0",
    input_contracts: ["product/input-\{index}@1.0.0"],
    output_contracts: ["product/output-\{index}@1.0.0"],
    required_claim: "digital-artifact",
    input_artifacts: ["requests/stage-\{index}.json"],
    timeout_ms: 30000,
    adapter_id: Some("adapter-\{index % 11}"),
    claim_ceiling: Some("digital-artifact"),
    review_required: Some(true),
    health_checked_at: Some("2026-07-31T00:00:00Z"),
    health_valid_until: Some("2026-08-01T00:00:00Z"),
    health_evidence_ref: Some("evidence/health-\{index % 11}.json"),
    health_evidence_digest: Some(
      "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    ),
  }
}

///|
test "Flow computes virtual extent and fits a 63-stage graph" {
  let items : Array[MoonFlowCompositionItem] = []
  let selected : Array[String] = []
  for index in 0..<63 {
    let item_id = "stage-\{index}"
    selected.push(item_id)
    items.push(
      flow_canvas_large_graph_item(
        index,
        if index == 0 {
          []
        } else {
          ["stage-\{index - 1}"]
        },
      ),
    )
  }
  let model = {
    ..init_model(),
    moonflow_composition: Some({
      selected_item_ids: selected,
      items,
      catalog_id: Some("catalog-large"),
      catalog_status: Some("conformant"),
      evaluated_at: Some("2026-07-31T12:00:00Z"),
      validation_status: Some("accepted"),
      validation_issues: Some([]),
    }),
  }
  let (width, height) = flow_virtual_extent(model, items[:])
  assert_true(width > 4800.0)
  assert_true(height >= flow_canvas_fit_height)
  let (_, fitted) = flow_canvas_fit_action(model)
  assert_true(fitted.flow_canvas.zoom < 0.1)
  assert_true(fitted.flow_canvas.zoom >= flow_zoom_min)
  let (last_x, _) = flow_item_position(fitted, items[:], "stage-62")
  let screen_x = fitted.flow_canvas.pan_x + last_x * fitted.flow_canvas.zoom
  assert_true(screen_x < flow_canvas_fit_width)
}
