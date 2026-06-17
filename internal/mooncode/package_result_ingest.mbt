///|
pub fn package_result_ingest_report(
  payload : Json,
  session_id~ : String,
  ingested_at~ : String,
) -> Json {
  let candidates = package_result_candidates(payload)
  let incoming = if candidates.length() > 0 { candidates } else { [payload] }
  let events : Array[Json] = []
  let native_requests : Array[Json] = []
  let rejected : Array[Json] = []
  for candidate in incoming {
    let proof = package_result_proof_payload(candidate, session_id)
    let validation = package_result_validation(proof, session_id)
    if !json_bool(validation, "ok", default=false) {
      rejected.push({
        "reason": "invalid-package-result",
        "validation": validation,
        "package_result": candidate,
      })
      continue
    }
    match runtime_ingest_event(proof, ingested_at) {
      Some(event) => {
        events.push(event)
        native_requests.push(proof)
      }
      None =>
        rejected.push({
          "reason": "unsupported-package-result-shape",
          "validation": validation,
          "package_result": candidate,
        })
    }
  }
  {
    "kind": "mooncode-package-result-ingest-report",
    "protocol": protocol_version(),
    "session_id": session_id,
    "ingested_at": ingested_at,
    "submitted_count": incoming.length(),
    "accepted_count": events.length(),
    "rejected_count": rejected.length(),
    "events": Json::array(events),
    "native_requests": Json::array(native_requests),
    "rejected": Json::array(rejected),
    "command_progress": runtime_event_command_progress(events),
    "status": if events.length() > 0 {
      "accepted"
    } else {
      "empty"
    },
    "owner": { "runtime": "moonclaw", "protocol": "mooncode", "ui": "moondesk" },
  }
}

///|
pub fn package_result_ingest_result_response(
  session_id : String,
  accepted_events : Array[Json],
  all_events : Array[Json],
  ingest_report : Json,
  final_session : Json,
  session_response : Json,
  event_log_path~ : String,
  native_state~ : Json,
) -> Json {
  runtime_event_ingest_result_response(
    session_id,
    accepted_events,
    all_events,
    ingest_report,
    final_session,
    session_response,
    event_log_path~,
  )
  |> runtime_with_field("native_package_result", native_state)
  |> runtime_with_field(
    "native_package_result_ready",
    json_bool(native_state, "native_package_result_ready", default=false).to_json(),
  )
  |> runtime_with_field(
    "native_package_result_endpoint",
    runtime_json_string(native_state, "endpoint", default="").to_json(),
  )
  |> runtime_with_field(
    "native_package_result_error",
    runtime_json_string(native_state, "error", default="").to_json(),
  )
  |> runtime_with_field(
    "native_package_result_submitted_count",
    runtime_json_int(native_state, "submitted_count", default=0).to_json(),
  )
  |> runtime_with_field(
    "native_package_result_accepted_count",
    runtime_json_int(native_state, "accepted_count", default=0).to_json(),
  )
}

///|
pub fn native_package_result_unavailable_report(
  endpoint : String,
  submitted_count : Int,
  error : String,
) -> Json {
  {
    "native_package_result_ready": false,
    "endpoint": endpoint,
    "error": error,
    "submitted_count": submitted_count,
    "accepted_count": 0,
    "responses": [],
    "errors": [],
  }
}

///|
pub fn native_package_result_forwarding_report(
  endpoint : String,
  submitted_count : Int,
  responses : Array[Json],
  errors : Array[Json],
) -> Json {
  {
    "native_package_result_ready": errors.length() == 0,
    "endpoint": endpoint,
    "error": if errors.length() == 0 {
      ""
    } else {
      "MoonClaw rejected \{errors.length()} package result(s)"
    },
    "submitted_count": submitted_count,
    "accepted_count": responses.length(),
    "responses": Json::array(responses),
    "errors": Json::array(errors),
  }
}

///|
fn package_result_candidates(payload : Json) -> Array[Json] {
  let package_results = runtime_json_array_items(payload, "package_results")
  if package_results.length() > 0 {
    return package_results
  }
  let events = runtime_json_array_items(payload, "events")
  if events.length() > 0 {
    return events
  }
  []
}

///|
fn package_result_proof_payload(candidate : Json, session_id : String) -> Json {
  let nested = runtime_json_object_field_or_empty(candidate, "package_result")
  let mut proof = if nested.stringify() == "{}" { candidate } else { nested }
  proof = package_result_default_string_field(
    proof,
    "protocol",
    json_string(candidate, "protocol", default=protocol_version()),
  )
  proof = package_result_default_string_field(
    proof,
    "session_id",
    runtime_first_string(candidate, ["session_id"], default=session_id),
  )
  proof = package_result_default_string_field(
    proof,
    "event",
    package_result_event_name(proof, candidate),
  )
  proof = package_result_default_string_field(
    proof,
    "command_id",
    package_result_command_id(proof, candidate),
  )
  proof = package_result_default_string_field(
    proof,
    "path",
    package_result_path(proof, candidate),
  )
  let packet = runtime_json_object_field_or_empty(proof, "command_packet")
  if packet.stringify() == "{}" {
    let candidate_packet = runtime_json_object_field_or_empty(
      candidate, "command_packet",
    )
    if candidate_packet.stringify() != "{}" {
      proof = runtime_with_field(proof, "command_packet", candidate_packet)
    }
  }
  proof
}

///|
fn package_result_default_string_field(
  json : Json,
  key : String,
  value : String,
) -> Json {
  if json_string(json, key, default="") != "" || value == "" {
    json
  } else {
    runtime_with_field(json, key, value.to_json())
  }
}

///|
fn package_result_event_name(proof : Json, candidate : Json) -> String {
  let event = runtime_first_string(proof, ["event", "kind"], default="")
  if event == event_package_built() || event == event_package_verified() {
    return event
  }
  let outer = runtime_first_string(candidate, ["event", "kind"], default="")
  if outer == event_package_built() || outer == event_package_verified() {
    outer
  } else {
    event
  }
}

///|
fn package_result_command_id(proof : Json, candidate : Json) -> String {
  let direct = runtime_first_string(
    proof,
    ["command_id", "commandId", "mooncode_command_id"],
    default="",
  )
  if direct != "" {
    return direct
  }
  let packet = runtime_json_object_field_or_empty(proof, "command_packet")
  let from_packet = json_string(packet, "command_id", default="")
  if from_packet != "" {
    return from_packet
  }
  let outer = runtime_first_string(
    candidate,
    ["command_id", "commandId", "mooncode_command_id"],
    default="",
  )
  if outer != "" {
    return outer
  }
  let outer_packet = runtime_json_object_field_or_empty(
    candidate, "command_packet",
  )
  json_string(outer_packet, "command_id", default="")
}

///|
fn package_result_path(proof : Json, candidate : Json) -> String {
  let direct = runtime_first_string(
    proof,
    ["path", "artifact_path"],
    default="",
  )
  if direct != "" {
    return direct
  }
  runtime_first_string(candidate, ["path", "artifact_path"], default="")
}

///|
fn package_result_validation(proof : Json, session_id : String) -> Json {
  let missing : Array[Json] = []
  let event = json_string(proof, "event", default="")
  if json_string(proof, "protocol", default="") != protocol_version() {
    missing.push("protocol".to_json())
  }
  if json_string(proof, "session_id", default="") != session_id {
    missing.push("session_id".to_json())
  }
  if package_result_command_id(proof, {}) == "" {
    missing.push("command_id".to_json())
  }
  if event != event_package_built() && event != event_package_verified() {
    missing.push("event".to_json())
  }
  if package_result_path(proof, {}) == "" {
    missing.push("path".to_json())
  }
  {
    "ok": missing.length() == 0,
    "protocol": protocol_version(),
    "session_id": session_id,
    "command_id": package_result_command_id(proof, {}),
    "event": event,
    "path": package_result_path(proof, {}),
    "missing": Json::array(missing),
  }
}
