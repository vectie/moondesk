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
    product_id: "moonwiki",
    requested_authority: "knowledge-write",
    depends_on: [],
    operation: "research",
  }
  let model = {
    ..init_model(),
    moonflow_composition: Some({
      selected_item_ids: ["research"],
      items: [item],
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
