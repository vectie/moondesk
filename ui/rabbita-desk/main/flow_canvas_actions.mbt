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
let flow_zoom_min : Double = 0.25

///|
let flow_zoom_max : Double = 2.5

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
  for entry in model.flow_node_positions {
    let (id, x, y) = entry
    if id == item_id {
      return (x, y)
    }
  }
  flow_item_default_position(items, item_id)
}

///|
fn flow_content_center(
  model : Model,
  items : ArrayView[MoonFlowCompositionItem],
) -> (Double, Double) {
  if items.length() == 0 {
    return (flow_origin_x + 400.0, flow_origin_y + 240.0)
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
  ((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
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
  for entry in model.flow_node_positions {
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
  { ..model, flow_node_positions: positions }
}

///|
fn flow_canvas_wheel_action(
  model : Model,
  delta_y : Double,
) -> (@rabbita.Cmd, Model) {
  let factor = if delta_y < 0.0 { 1.12 } else { 1.0 / 1.12 }
  let next_zoom = flow_clamp_zoom(model.flow_zoom * factor)
  if next_zoom == model.flow_zoom {
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
      flow_zoom: next_zoom,
      flow_pan_x: model.flow_pan_x + cx * (model.flow_zoom - next_zoom),
      flow_pan_y: model.flow_pan_y + cy * (model.flow_zoom - next_zoom),
    },
  )
}

///|
fn flow_pan_start_action(
  model : Model,
  x : Int,
  y : Int,
) -> (@rabbita.Cmd, Model) {
  if model.flow_drag_node_id != "" {
    // A node drag already claimed this pointer; do not also start a pan.
    return (@rabbita.none, model)
  }
  (
    @rabbita.none,
    {
      ..model,
      flow_pan_dragging: true,
      flow_drag_last_x: x.to_double(),
      flow_drag_last_y: y.to_double(),
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
  let dx = next_x - model.flow_drag_last_x
  let dy = next_y - model.flow_drag_last_y
  if model.flow_drag_node_id != "" {
    match model.moonflow_composition {
      Some(composition) => {
        let (old_x, old_y) = flow_item_position(
          model,
          composition.items[:],
          model.flow_drag_node_id,
        )
        let moved = flow_set_node_position(
          model,
          model.flow_drag_node_id,
          old_x + dx / model.flow_zoom,
          old_y + dy / model.flow_zoom,
        )
        (
          @rabbita.none,
          { ..moved, flow_drag_last_x: next_x, flow_drag_last_y: next_y },
        )
      }
      None =>
        (
          @rabbita.none,
          { ..model, flow_drag_last_x: next_x, flow_drag_last_y: next_y },
        )
    }
  } else if model.flow_pan_dragging {
    (
      @rabbita.none,
      {
        ..model,
        flow_pan_x: model.flow_pan_x + dx,
        flow_pan_y: model.flow_pan_y + dy,
        flow_drag_last_x: next_x,
        flow_drag_last_y: next_y,
      },
    )
  } else {
    (@rabbita.none, model)
  }
}

///|
fn flow_pointer_end_action(model : Model) -> (@rabbita.Cmd, Model) {
  (@rabbita.none, { ..model, flow_pan_dragging: false, flow_drag_node_id: "" })
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
      flow_drag_node_id: item_id,
      flow_pan_dragging: false,
      flow_drag_last_x: x.to_double(),
      flow_drag_last_y: y.to_double(),
    },
  )
}

///|
fn flow_canvas_reset_action(model : Model) -> (@rabbita.Cmd, Model) {
  (
    @rabbita.none,
    {
      ..model,
      flow_pan_x: 0.0,
      flow_pan_y: 0.0,
      flow_zoom: 1.0,
      flow_node_positions: [],
      flow_pan_dragging: false,
      flow_drag_node_id: "",
    },
  )
}
