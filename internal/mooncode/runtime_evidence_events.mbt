///|
fn evidence_match_required_event(
  required : String,
  command_id : String,
  action : String,
  events : Array[Json],
) -> Json {
  let mut failed_event = Json::object({})
  for event in events {
    if !evidence_event_matches_command(event, command_id, action) {
      continue
    }
    if @mooncode_core.runtime_evidence_event_fails_required(required, event) {
      if json_string(failed_event, "id", default="") == "" {
        failed_event = event
      }
      continue
    }
    if !@mooncode_core.runtime_evidence_event_satisfies(required, event) {
      continue
    }
    if json_string(event, "status", default="") ==
      @mooncode_core.runtime_evidence_status_failed() {
      if json_string(failed_event, "id", default="") == "" {
        failed_event = event
      }
      continue
    }
    return @mooncode_core.runtime_evidence_required_event_result(
      required,
      @mooncode_core.runtime_required_event_status_proven(),
      event,
    )
  }
  if json_string(failed_event, "id", default="") != "" {
    @mooncode_core.runtime_evidence_required_event_result(
      required,
      @mooncode_core.runtime_required_event_status_failed(),
      failed_event,
    )
  } else {
    @mooncode_core.runtime_evidence_required_event_result(
      required,
      @mooncode_core.runtime_required_event_status_missing(),
      Json::object({}),
    )
  }
}

///|
fn evidence_event_matches_command(
  event : Json,
  command_id : String,
  action : String,
) -> Bool {
  if command_id == "" {
    return false
  }
  let packet = evidence_json_object_field_or_empty(event, "command_packet")
  json_string(packet, "command_id", default="") == command_id &&
  evidence_event_action(event) == action
}

///|
fn evidence_event_action(event : Json) -> String {
  let packet = evidence_json_object_field_or_empty(event, "command_packet")
  let packet_action = json_string(packet, "action", default="")
  if packet_action != "" {
    return packet_action
  }
  json_string(event, "command", default="")
}

///|
fn evidence_events_with_status(
  event_results : Array[Json],
  status : String,
) -> Array[String] {
  @mooncode_core.runtime_evidence_events_with_status(event_results, status)
}
