///|
priv struct FlowCanvasState {
  pan_x : Double
  pan_y : Double
  zoom : Double
  pan_dragging : Bool
  drag_last_x : Double
  drag_last_y : Double
  drag_node_id : String
  node_positions : Array[(String, Double, Double)]
}

///|
fn init_flow_canvas_state() -> FlowCanvasState {
  {
    pan_x: 0.0,
    pan_y: 0.0,
    zoom: 1.0,
    pan_dragging: false,
    drag_last_x: 0.0,
    drag_last_y: 0.0,
    drag_node_id: "",
    node_positions: [],
  }
}
