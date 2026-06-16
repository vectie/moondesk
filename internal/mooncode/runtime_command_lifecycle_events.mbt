///|
fn runtime_command_lifecycle_event_counts(
  command_id : String,
  action : String,
  events : Array[Json],
) -> Json {
  let lanes : Array[String] = []
  let mut event_count = 0
  let mut running_event_count = 0
  let mut done_event_count = 0
  let mut failed_event_count = 0
  let mut proof_event_count = 0
  let mut latest_event_id = ""
  let mut latest_event_title = ""
  let mut latest_event_status = ""
  for event in events {
    if !runtime_event_matches_command(event, command_id, action) {
      continue
    }
    event_count += 1
    let lane = rq_json_string(event, "lane", default="")
    if lane != "" && !runtime_string_array_contains(lanes, lane) {
      lanes.push(lane)
    }
    if runtime_lane_is_proof(lane) {
      proof_event_count += 1
    }
    match rq_json_string(event, "status", default="") {
      "running" => running_event_count += 1
      "failed" => failed_event_count += 1
      _ => done_event_count += 1
    }
    latest_event_id = rq_json_string(event, "id", default="")
    latest_event_title = rq_json_string(event, "title", default="")
    latest_event_status = rq_json_string(event, "status", default="")
  }
  {
    "event_count": event_count,
    "running_event_count": running_event_count,
    "done_event_count": done_event_count,
    "failed_event_count": failed_event_count,
    "proof_event_count": proof_event_count,
    "lanes": Json::array([ for lane in lanes => Json::string(lane) ]),
    "latest_event_id": latest_event_id,
    "latest_event_title": latest_event_title,
    "latest_event_status": latest_event_status,
  }
}

///|
fn runtime_event_matches_command(
  event : Json,
  command_id : String,
  action : String,
) -> Bool {
  if command_id == "" {
    return false
  }
  let packet = rq_json_object_field_or_empty(event, "command_packet")
  rq_json_string(packet, "command_id", default="") == command_id &&
  (
    rq_json_string(packet, "action", default="") == "" ||
    rq_json_string(packet, "action", default="") == action
  )
}
