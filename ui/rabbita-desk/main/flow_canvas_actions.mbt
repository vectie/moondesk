///|
/// MoonFlow infinite-canvas interaction state transitions.
/// The canvas keeps a pan offset (screen px), a zoom factor, and optional
/// user-dragged node positions on top of the automatic layered layout.
let flow_node_width : Double = 244.0

///|
let flow_node_height : Double = 150.0

///|
let flow_column_step : Double = 304.0

///|
let flow_row_step : Double = 196.0

///|
let flow_origin_x : Double = 64.0

///|
let flow_origin_y : Double = 72.0

///|
let flow_zoom_min : Double = 0.05

///|
let flow_zoom_max : Double = 2.5

///|
let flow_canvas_fit_width : Double = 1080.0

///|
let flow_canvas_fit_height : Double = 520.0

///|
let flow_canvas_padding : Double = 48.0

///|
fn flow_canvas_apply_composition_positions(
  canvas : FlowCanvasState,
  composition : MoonFlowComposition,
) -> FlowCanvasState {
  let positions : Array[(String, Double, Double)] = []
  for position in composition.node_positions.unwrap_or([]) {
    positions.push((position.work_item_id, position.x, position.y))
  }
  { ..canvas, pan_dragging: false, drag_node_id: "", node_positions: positions }
}

///|
fn flow_item_default_position(
  items : ArrayView[MoonFlowCompositionItem],
  item_id : String,
) -> (Double, Double) {
  let depth = moonflow_composition_depth(items, item_id, [])
  let mut index = 0
  for item in items {
    if item.work_item_id == item_id {
      break
    }
    if moonflow_composition_depth(items, item.work_item_id, []) == depth {
      index = index + 1
    }
  }
  (
    flow_origin_x + depth.to_double() * flow_column_step,
    flow_origin_y + index.to_double() * flow_row_step,
  )
}

///|
fn flow_item_position(
  model : Model,
  items : ArrayView[MoonFlowCompositionItem],
  item_id : String,
) -> (Double, Double) {
  for entry in model.flow_canvas.node_positions {
    let (id, x, y) = entry
    if id == item_id {
      return (x, y)
    }
  }
  flow_item_default_position(items, item_id)
}

///|
fn flow_content_bounds(
  model : Model,
  items : ArrayView[MoonFlowCompositionItem],
) -> (Double, Double, Double, Double) {
  if items.length() == 0 {
    return (
      flow_origin_x,
      flow_origin_y,
      flow_origin_x + 800.0,
      flow_origin_y + 480.0,
    )
  }
  let mut min_x = 100000.0
  let mut min_y = 100000.0
  let mut max_x = -100000.0
  let mut max_y = -100000.0
  for item in items {
    let (x, y) = flow_item_position(model, items[:], item.work_item_id)
    if x < min_x {
      min_x = x
    }
    if y < min_y {
      min_y = y
    }
    if x + flow_node_width > max_x {
      max_x = x + flow_node_width
    }
    if y + flow_node_height > max_y {
      max_y = y + flow_node_height
    }
  }
  (min_x, min_y, max_x, max_y)
}

///|
fn flow_content_center(
  model : Model,
  items : ArrayView[MoonFlowCompositionItem],
) -> (Double, Double) {
  let (min_x, min_y, max_x, max_y) = flow_content_bounds(model, items)
  ((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
}

///|
fn flow_virtual_extent(
  model : Model,
  items : ArrayView[MoonFlowCompositionItem],
) -> (Double, Double) {
  let (_, _, max_x, max_y) = flow_content_bounds(model, items)
  let width = max_x + flow_canvas_padding
  let height = max_y + flow_canvas_padding
  (
    if width < flow_canvas_fit_width {
      flow_canvas_fit_width
    } else {
      width
    },
    if height < flow_canvas_fit_height {
      flow_canvas_fit_height
    } else {
      height
    },
  )
}

///|
fn flow_clamp_zoom(zoom : Double) -> Double {
  if zoom < flow_zoom_min {
    flow_zoom_min
  } else if zoom > flow_zoom_max {
    flow_zoom_max
  } else {
    zoom
  }
}

///|
fn flow_set_node_position(
  model : Model,
  item_id : String,
  x : Double,
  y : Double,
) -> Model {
  let positions : Array[(String, Double, Double)] = []
  let mut replaced = false
  for entry in model.flow_canvas.node_positions {
    let (id, old_x, old_y) = entry
    if id == item_id {
      positions.push((item_id, x, y))
      replaced = true
    } else {
      positions.push((id, old_x, old_y))
    }
  }
  if !replaced {
    positions.push((item_id, x, y))
  }
  { ..model, flow_canvas: { ..model.flow_canvas, node_positions: positions } }
}

///|
fn flow_canvas_wheel_action(
  model : Model,
  delta_y : Double,
) -> (@rabbita.Cmd, Model) {
  let factor = if delta_y < 0.0 { 1.12 } else { 1.0 / 1.12 }
  let next_zoom = flow_clamp_zoom(model.flow_canvas.zoom * factor)
  if next_zoom == model.flow_canvas.zoom {
    return (@rabbita.none, model)
  }
  // Keep the content center stationary while zooming so the canvas never
  // jumps away from the nodes the operator is looking at.
  let center = match model.moonflow_composition {
    Some(composition) => flow_content_center(model, composition.items[:])
    None => (flow_origin_x + 400.0, flow_origin_y + 240.0)
  }
  let (cx, cy) = center
  (
    @rabbita.none,
    {
      ..model,
      flow_canvas: {
        ..model.flow_canvas,
        zoom: next_zoom,
        pan_x: model.flow_canvas.pan_x +
        cx * (model.flow_canvas.zoom - next_zoom),
        pan_y: model.flow_canvas.pan_y +
        cy * (model.flow_canvas.zoom - next_zoom),
      },
    },
  )
}

///|
fn flow_pan_start_action(
  model : Model,
  x : Int,
  y : Int,
) -> (@rabbita.Cmd, Model) {
  if model.flow_canvas.drag_node_id != "" {
    // A node drag already claimed this pointer; do not also start a pan.
    return (@rabbita.none, model)
  }
  (
    @rabbita.none,
    {
      ..model,
      flow_canvas: {
        ..model.flow_canvas,
        pan_dragging: true,
        drag_last_x: x.to_double(),
        drag_last_y: y.to_double(),
      },
    },
  )
}

///|
fn flow_pointer_move_action(
  model : Model,
  x : Int,
  y : Int,
) -> (@rabbita.Cmd, Model) {
  let next_x = x.to_double()
  let next_y = y.to_double()
  let dx = next_x - model.flow_canvas.drag_last_x
  let dy = next_y - model.flow_canvas.drag_last_y
  if model.flow_canvas.drag_node_id != "" {
    match model.moonflow_composition {
      Some(composition) => {
        let (old_x, old_y) = flow_item_position(
          model,
          composition.items[:],
          model.flow_canvas.drag_node_id,
        )
        let moved = flow_set_node_position(
          model,
          model.flow_canvas.drag_node_id,
          old_x + dx / model.flow_canvas.zoom,
          old_y + dy / model.flow_canvas.zoom,
        )
        (
          @rabbita.none,
          {
            ..moved,
            flow_canvas: {
              ..moved.flow_canvas,
              drag_last_x: next_x,
              drag_last_y: next_y,
            },
          },
        )
      }
      None =>
        (
          @rabbita.none,
          {
            ..model,
            flow_canvas: {
              ..model.flow_canvas,
              drag_last_x: next_x,
              drag_last_y: next_y,
            },
          },
        )
    }
  } else if model.flow_canvas.pan_dragging {
    (
      @rabbita.none,
      {
        ..model,
        flow_canvas: {
          ..model.flow_canvas,
          pan_x: model.flow_canvas.pan_x + dx,
          pan_y: model.flow_canvas.pan_y + dy,
          drag_last_x: next_x,
          drag_last_y: next_y,
        },
      },
    )
  } else {
    (@rabbita.none, model)
  }
}

///|
fn flow_pointer_end_action(model : Model) -> (@rabbita.Cmd, Model) {
  (
    @rabbita.none,
    {
      ..model,
      flow_canvas: {
        ..model.flow_canvas,
        pan_dragging: false,
        drag_node_id: "",
      },
    },
  )
}

///|
fn flow_node_drag_start_action(
  model : Model,
  item_id : String,
  x : Int,
  y : Int,
) -> (@rabbita.Cmd, Model) {
  (
    @rabbita.none,
    {
      ..model,
      flow_canvas: {
        ..model.flow_canvas,
        drag_node_id: item_id,
        pan_dragging: false,
        drag_last_x: x.to_double(),
        drag_last_y: y.to_double(),
      },
    },
  )
}

///|
fn flow_node_keydown_action(
  model : Model,
  item_id : String,
  key : String,
  shift : Bool,
) -> (@rabbita.Cmd, Model) {
  let step = if shift { 32.0 } else { 8.0 }
  let (dx, dy) = match key {
    "ArrowLeft" => (-step, 0.0)
    "ArrowRight" => (step, 0.0)
    "ArrowUp" => (0.0, -step)
    "ArrowDown" => (0.0, step)
    _ => return (@rabbita.none, model)
  }
  guard model.moonflow_composition is Some(composition) else {
    return (@rabbita.none, model)
  }
  guard composition.items.any(item => item.work_item_id == item_id) else {
    return (@rabbita.none, model)
  }
  let (x, y) = flow_item_position(model, composition.items[:], item_id)
  let moved = flow_set_node_position(model, item_id, x + dx, y + dy)
  (
    @rabbita.none,
    {
      ..moved,
      moonflow_composition_status: "Unsaved node position · " + item_id,
    },
  )
}

///|
fn flow_canvas_reset_action(model : Model) -> (@rabbita.Cmd, Model) {
  (@rabbita.none, { ..model, flow_canvas: init_flow_canvas_state() })
}

///|
fn flow_canvas_fit_action(model : Model) -> (@rabbita.Cmd, Model) {
  match model.moonflow_composition {
    None => flow_canvas_reset_action(model)
    Some(composition) => {
      let (min_x, min_y, max_x, max_y) = flow_content_bounds(
        model,
        composition.items[:],
      )
      let content_width = max_x - min_x
      let content_height = max_y - min_y
      let available_width = flow_canvas_fit_width - flow_canvas_padding * 2.0
      let available_height = flow_canvas_fit_height - flow_canvas_padding * 2.0
      let width_zoom = if content_width <= 0.0 {
        1.0
      } else {
        available_width / content_width
      }
      let height_zoom = if content_height <= 0.0 {
        1.0
      } else {
        available_height / content_height
      }
      let next_zoom = flow_clamp_zoom(
        if width_zoom < height_zoom {
          width_zoom
        } else {
          height_zoom
        },
      )
      (
        @rabbita.none,
        {
          ..model,
          flow_canvas: {
            ..model.flow_canvas,
            pan_x: flow_canvas_padding - min_x * next_zoom,
            pan_y: flow_canvas_padding - min_y * next_zoom,
            zoom: next_zoom,
            pan_dragging: false,
            drag_node_id: "",
          },
        },
      )
    }
  }
}
