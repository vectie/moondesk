///|
fn runtime_runtime_control_decision_for_command(
  runtime_control : Json,
  command_id : String,
) -> Json {
  if command_id == "" {
    return Json::object({})
  }
  for decision in rq_json_array_items(runtime_control, "decisions") {
    if rq_json_string(decision, "command_id", default="") == command_id {
      return decision
    }
  }
  Json::object({})
}

///|
fn runtime_supervisor_has_loop_step(steps : Array[Json], id : String) -> Bool {
  for step in steps {
    if rq_json_string(step, "id", default="") == id {
      return true
    }
  }
  false
}

///|
fn runtime_supervisor_endpoint_from_turn(
  turn_packet : Json,
  key : String,
) -> String {
  let endpoints = rq_json_object_field_or_empty(turn_packet, "endpoints")
  rq_json_string(endpoints, key, default="")
}

///|
fn runtime_supervisor_url(host_base_url : String, path : String) -> String {
  if host_base_url == "" || path == "" {
    path
  } else {
    "\{host_base_url}\{path}"
  }
}

///|
fn runtime_supervisor_blocked_reason(
  command_id : String,
  status : String,
  ready_to_execute : Bool,
  runtime_control_allows_turn : Bool,
) -> String {
  if command_id == "" {
    "no runtime command is ready for execution"
  } else if !runtime_control_allows_turn {
    "runtime control does not allow this turn yet"
  } else if !ready_to_execute {
    "runtime command status `\{status}` is not executable"
  } else {
    ""
  }
}
