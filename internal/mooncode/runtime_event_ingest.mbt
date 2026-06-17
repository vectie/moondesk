///|
pub fn runtime_event_fallback_id(event : Json) -> String {
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(event.stringify()).to_fixedarray()),
  )
  "mooncode-runtime-event-" + digest[:16].to_owned()
}

///|
pub fn normalize_runtime_event_with_defaults(
  event : Json,
  fallback_created_at~ : String,
) -> Json? {
  let with_created_at = if json_string(event, "created_at", default="") == "" &&
    json_string(event, "created", default="") == "" {
    runtime_with_field(event, "created_at", fallback_created_at.to_json())
  } else {
    event
  }
  normalize_runtime_event(
    with_created_at,
    fallback_id=runtime_event_fallback_id(event),
    fallback_created_at~,
  )
}

///|
pub fn normalize_runtime_loop_response_event(
  response : Json,
  fallback_id~ : String,
  fallback_created_at~ : String,
) -> Json? {
  if json_string(response, "kind", default="") != "mooncode-runtime-loop" {
    return None
  }
  let stopped_by = runtime_json_string(
    response,
    "stopped_by",
    default="unknown",
  )
  let status = match stopped_by {
    "failed" => "failed"
    "cancelled" => "cancelled"
    "max_turns" => "running"
    _ => "done"
  }
  Some(
    event_record(
      id=runtime_json_string(response, "id", default=fallback_id),
      lane="runtime",
      kind="runtime_loop",
      title="Native runtime loop: \{stopped_by}",
      status~,
      created_at=runtime_first_string(
        response,
        ["created_at", "created"],
        default=fallback_created_at,
      ),
      detail=runtime_json_string(
        response,
        "message",
        default="MoonClaw native runtime loop stopped by \{stopped_by}",
      ),
      path=runtime_json_string(response, "book_root", default=""),
      command="runtime-loop",
    ),
  )
}

///|
pub fn native_response_event_items(
  response : Json,
  loop_fallback_id~ : String,
  loop_fallback_created_at~ : String,
) -> Array[Json] {
  let incoming = runtime_json_array_items(response, "events")
  let execution = runtime_json_object_field_or_empty(response, "execution")
  for event in runtime_json_array_items(execution, "events") {
    incoming.push(event)
  }
  match
    normalize_runtime_loop_response_event(
      response,
      fallback_id=loop_fallback_id,
      fallback_created_at=loop_fallback_created_at,
    ) {
    Some(event) => incoming.push(event)
    None => ()
  }
  for event in runtime_json_array_items(response, "package_events") {
    incoming.push(event)
  }
  let turn_receipt = runtime_json_object_field_or_empty(
    response, "turn_receipt",
  )
  for event in runtime_json_array_items(turn_receipt, "events") {
    incoming.push(event)
  }
  let mut turn_index = 0
  for turn in runtime_json_array_items(response, "turns") {
    for
      event in native_response_event_items(
        turn,
        loop_fallback_id=loop_fallback_id + "-turn-" + turn_index.to_string(),
        loop_fallback_created_at~,
      ) {
      incoming.push(event)
    }
    turn_index += 1
  }
  incoming
}

///|
pub fn append_native_response_events(
  session : Json,
  response : Json,
  loop_fallback_id~ : String,
  loop_fallback_created_at~ : String,
) -> Json {
  let incoming = native_response_event_items(
    response,
    loop_fallback_id~,
    loop_fallback_created_at~,
  )
  if incoming.length() == 0 {
    return session
  }
  let current = runtime_json_array_items(session, "mooncode_command_events")
  let events = merge_events(current, incoming, [])
  runtime_with_field(session, "mooncode_command_events", Json::array(events))
}

///|
pub fn append_projected_native_response_events(
  session : Json,
  response : Json,
  loop_fallback_created_at~ : String,
) -> Json {
  append_native_response_events(
    session,
    response,
    loop_fallback_id=projected_runtime_loop_fallback_id(
      response, loop_fallback_created_at,
    ),
    loop_fallback_created_at~,
  )
}

///|
fn projected_runtime_loop_fallback_id(
  response : Json,
  loop_fallback_created_at : String,
) -> String {
  let stopped_by = runtime_json_string(
    response,
    "stopped_by",
    default="unknown",
  )
  let ran_turn_count = runtime_json_int(response, "ran_turn_count", default=0)
  let failed_turn_count = runtime_json_int(
    response,
    "failed_turn_count",
    default=0,
  )
  let session_id = runtime_json_string(response, "session_id", default="")
  let consumer_id = runtime_json_string(response, "consumer_id", default="")
  let seed = session_id +
    ":" +
    consumer_id +
    ":" +
    loop_fallback_created_at +
    ":" +
    stopped_by +
    ":" +
    ran_turn_count.to_string() +
    ":" +
    failed_turn_count.to_string()
  let digest = @crypto.bytes_to_hex_string(
    @crypto.sha256(@encoding/utf8.encode(seed).to_fixedarray()),
  )
  "mooncode-runtime-loop-" + digest[:16].to_owned()
}

///|
pub fn runtime_event_ingest_report(
  payload : Json,
  session_id~ : String,
  ingested_at~ : String,
) -> Json {
  let candidates = runtime_json_array_items(payload, "events")
  let incoming = if candidates.length() > 0 { candidates } else { [payload] }
  let events : Array[Json] = []
  let rejected : Array[Json] = []
  for candidate in incoming {
    match runtime_ingest_event(candidate, ingested_at) {
      Some(event) => events.push(event)
      None =>
        rejected.push({
          "reason": "unsupported-runtime-event-shape",
          "event": candidate,
        })
    }
  }
  {
    "kind": "mooncode-runtime-event-ingest-report",
    "protocol": protocol_version(),
    "session_id": session_id,
    "ingested_at": ingested_at,
    "submitted_count": incoming.length(),
    "accepted_count": events.length(),
    "rejected_count": rejected.length(),
    "events": Json::array(events),
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
pub fn runtime_event_ingest_report_with_moonclaw_adapter(
  payload : Json,
  session_id~ : String,
  ingested_at~ : String,
) -> Json {
  let report = runtime_event_ingest_report(payload, session_id~, ingested_at~)
  if runtime_json_int(report, "accepted_count", default=0) > 0 {
    return report
  }
  let legacy_events = moonclaw_adapter_ingest_events(payload, ingested_at)
  if legacy_events.length() == 0 {
    return report
  }
  report
  |> runtime_with_field("status", "accepted-legacy-moonclaw".to_json())
  |> runtime_with_field("accepted_count", legacy_events.length().to_json())
  |> runtime_with_field("events", Json::array(legacy_events))
  |> runtime_with_field("legacy_adapter", "mooncode.moonclaw.desc".to_json())
}

///|
fn moonclaw_adapter_ingest_events(
  payload : Json,
  ingested_at : String,
) -> Array[Json] {
  let candidates = json_array_items(payload, "events")
  let incoming = if candidates.length() > 0 { candidates } else { [payload] }
  let events : Array[Json] = []
  for candidate in incoming {
    match
      moonclaw_projected_event_record(
        candidate,
        fallback_created_at=ingested_at,
      ) {
      Some(event) => events.push(event)
      None => ()
    }
  }
  events
}

///|
pub fn runtime_native_event_report(
  payload : Json,
  session_id~ : String,
  observed_at~ : String,
) -> Json {
  runtime_event_ingest_report(payload, session_id~, ingested_at=observed_at)
  |> runtime_with_field(
    "kind",
    "mooncode-native-runtime-event-report".to_json(),
  )
  |> runtime_with_field(
    "native_payload_kind",
    runtime_json_string(payload, "kind", default="").to_json(),
  )
  |> runtime_with_field(
    "native_payload_event_count",
    runtime_json_array_items(payload, "events").length().to_json(),
  )
}

///|
pub fn native_runtime_events_for_projection(
  native_report : Json,
) -> Array[Json] {
  runtime_json_array_items(native_report, "events")
}

///|
pub fn runtime_ingest_events(
  payload : Json,
  ingested_at~ : String,
) -> Array[Json] {
  json_array_items(
    runtime_event_ingest_report(payload, session_id="", ingested_at~),
    "events",
  )
}

///|
fn runtime_ingest_event(event : Json, ingested_at : String) -> Json? {
  if json_string(event, "lane", default="") != "" &&
    json_string(event, "kind", default="") != "" {
    return Some(
      canonical_event_record(
        event,
        fallback_id=runtime_event_fallback_id(event),
        fallback_created_at=ingested_at,
      ),
    )
  }
  match
    normalize_runtime_event_with_defaults(
      event,
      fallback_created_at=ingested_at,
    ) {
    Some(normalized) => Some(normalized)
    None =>
      match
        moonclaw_event_to_runtime_event(
          event,
          fallback_id=runtime_event_fallback_id(event),
          fallback_created_at=ingested_at,
        ) {
        Some(converted) =>
          normalize_runtime_event_with_defaults(
            converted,
            fallback_created_at=ingested_at,
          )
        None => None
      }
  }
}
