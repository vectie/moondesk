///|
// Contract report for MoonClaw native runtime evidence after Moondesk
// normalization. This is intentionally diagnostic: it proves whether accepted
// native events are safe for canonical conversation projection without making
// the browser a second event owner.

///|
pub fn native_runtime_event_contract_report(
  native_report : Json,
  session_id~ : String,
  observed_at~ : String,
) -> Json {
  let events = runtime_json_array_items(native_report, "events")
  let problems : Array[Json] = []
  let mut scoped_count = 0
  let mut diagnostic_count = 0
  let mut unscoped_projection_count = 0
  let mut transcript_count = 0
  let mut progress_count = 0
  for event in events {
    if native_runtime_event_has_command_scope(event) {
      scoped_count += 1
    } else if native_runtime_event_is_diagnostic_only(event) {
      diagnostic_count += 1
    } else if native_runtime_event_requires_command_scope(event) {
      unscoped_projection_count += 1
      problems.push(
        native_runtime_event_contract_problem(
          event,
          reason="user-facing-native-event-without-command-scope",
        ),
      )
    } else {
      diagnostic_count += 1
    }
    if native_runtime_event_is_transcript(event) {
      transcript_count += 1
    } else if native_runtime_event_is_progress(event) {
      progress_count += 1
    }
  }
  let rejected_count = runtime_json_int(
    native_report,
    "rejected_count",
    default=0,
  )
  let status = if unscoped_projection_count > 0 {
    "unsafe"
  } else if events.length() == 0 && rejected_count > 0 {
    "rejected"
  } else {
    "projection-safe"
  }
  {
    "kind": "mooncode-native-runtime-contract-report",
    "protocol": protocol_version(),
    "session_id": session_id,
    "observed_at": observed_at,
    "status": status,
    "projection_safe": unscoped_projection_count == 0,
    "accepted_event_count": events.length(),
    "rejected_event_count": rejected_count,
    "command_scoped_event_count": scoped_count,
    "diagnostic_event_count": diagnostic_count,
    "unscoped_projection_event_count": unscoped_projection_count,
    "transcript_event_count": transcript_count,
    "progress_event_count": progress_count,
    "problems": Json::array(problems),
    "rule": "Accepted native runtime events may affect canonical chat only when they carry command_packet.command_id or direct command_id normalized into a command packet. Unscoped service, watcher, usage, and runtime-loop records remain diagnostics.",
    "owner": {
      "runtime": "moonclaw",
      "projection": "mooncode",
      "ui": "moondesk",
    },
  }
}

///|
pub fn native_runtime_events_for_canonical_projection(
  native_report : Json,
) -> Array[Json] {
  let events = runtime_json_array_items(native_report, "events")
  let projected : Array[Json] = []
  for event in events {
    if native_runtime_event_has_command_scope(event) ||
      native_runtime_event_is_diagnostic_only(event) {
      projected.push(event)
    }
  }
  projected
}

///|
fn native_runtime_event_has_command_scope(event : Json) -> Bool {
  runtime_event_has_command_scope(event) ||
  runtime_first_string(
    event,
    ["command_id", "commandId", "mooncode_command_id"],
    default="",
  ) !=
  ""
}

///|
fn native_runtime_event_is_diagnostic_only(event : Json) -> Bool {
  let kind = runtime_first_string(event, ["kind", "event"], default="")
  let source = runtime_json_string(event, "source", default="")
  let title = runtime_json_string(event, "title", default="")
  kind == "runtime.service_started" ||
  kind == "runtime.service_finished" ||
  kind == "runtime.service_failed" ||
  kind == "runtime_loop" ||
  kind == "usage" ||
  source == "moonclaw-native-moon-check-watcher" ||
  title == "MoonCode moon_check update"
}

///|
fn native_runtime_event_requires_command_scope(event : Json) -> Bool {
  let lane = runtime_json_string(event, "lane", default=event_lane_default())
  let kind = runtime_first_string(event, ["kind", "event"], default="")
  lane == event_lane_transcript() ||
  lane == event_lane_tool() ||
  lane == event_lane_diff() ||
  lane == event_lane_test() ||
  lane == event_lane_artifact() ||
  lane == event_lane_review() ||
  kind == "reasoning_delta" ||
  kind == "reasoning_message" ||
  kind == "runtime_update" ||
  kind == "assistant_delta" ||
  kind == "assistant" ||
  kind == "command_error" ||
  kind == "turn_failed" ||
  kind == "max_steps_exhausted" ||
  kind == "runtime_unavailable"
}

///|
fn native_runtime_event_is_transcript(event : Json) -> Bool {
  runtime_json_string(event, "lane", default="") == event_lane_transcript()
}

///|
fn native_runtime_event_is_progress(event : Json) -> Bool {
  let lane = runtime_json_string(event, "lane", default="")
  event_lane_is_progress(lane)
}

///|
fn native_runtime_event_contract_problem(
  event : Json,
  reason~ : String,
) -> Json {
  {
    "reason": reason,
    "id": runtime_json_string(event, "id", default=""),
    "lane": runtime_json_string(event, "lane", default=event_lane_default()),
    "kind": runtime_first_string(event, ["kind", "event"], default=""),
    "title": runtime_json_string(event, "title", default=""),
    "status": runtime_json_string(event, "status", default=""),
    "created_at": runtime_json_string(event, "created_at", default=""),
  }
}
