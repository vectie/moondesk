///|
// Command-scoped proof correlation helpers for MoonCode action plans.

///|
pub fn command_proof_count(
  events : Array[Json],
  command_id : String,
  action : String,
  proof_kind~ : String,
) -> Int {
  if command_id == "" {
    return 0
  }
  let mut count = 0
  for event in events {
    if json_string(event, "kind", default="") == proof_kind &&
      command_event_matches(event, command_id, action) &&
      json_string(event, "status", default="") != "failed" {
      count += 1
    }
  }
  count
}

///|
pub fn command_proofs_are_scoped(events : Array[Json], action : String) -> Bool {
  for event in events {
    if command_proof_action(event) == action &&
      json_string(
        runtime_json_object_field_or_empty(event, "command_packet"),
        "command_id",
        default="",
      ) !=
      "" {
      return true
    }
  }
  false
}

///|
fn command_event_matches(
  event : Json,
  command_id : String,
  action : String,
) -> Bool {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  json_string(packet, "command_id", default="") == command_id &&
  command_proof_action(event) == action
}

///|
fn command_proof_action(event : Json) -> String {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let packet_action = json_string(packet, "action", default="")
  if packet_action != "" {
    return packet_action
  }
  let command = json_string(event, "command", default="")
  if command == "package" {
    "package"
  } else if command == "commit" {
    "commit"
  } else if command == "run_tests" {
    "run_tests"
  } else {
    command
  }
}
