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
  let started_event = runtime_json_object_field_or_empty(
    response, "started_event",
  )
  if runtime_json_string(started_event, "kind", default="") != "" {
    incoming.push(started_event)
  }
  let finished_event = runtime_json_object_field_or_empty(
    response, "finished_event",
  )
  if runtime_json_string(finished_event, "kind", default="") != "" {
    incoming.push(finished_event)
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
    let accepted = runtime_ingest_event_items(candidate, ingested_at)
    if accepted.length() > 0 {
      for event in accepted {
        events.push(event)
      }
    } else {
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
fn runtime_ingest_event_items(
  event : Json,
  ingested_at : String,
) -> Array[Json] {
  let package_events = runtime_package_message_events(event, ingested_at)
  if package_events.length() > 0 {
    return package_events
  }
  match runtime_ingest_event(event, ingested_at) {
    Some(normalized) => [normalized]
    None => []
  }
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
    None => None
  }
}

///|
fn runtime_package_message_events(
  event : Json,
  ingested_at : String,
) -> Array[Json] {
  let message = runtime_json_object_field_or_empty(event, "message")
  let role = runtime_package_role(event, message)
  if role != "assistant" && role != "user" {
    return []
  }
  let content = runtime_package_content_blocks(event, message)
  if content.length() == 0 {
    return []
  }
  let has_tool_use = runtime_package_has_tool_use(content)
  let base_id = runtime_json_string(
    event,
    "id",
    default=runtime_event_fallback_id(event),
  )
  let created_at = runtime_first_string(
    event,
    ["created_at", "created"],
    default=ingested_at,
  )
  let events : Array[Json] = []
  let tool_names = runtime_package_tool_name_map(content)
  for index, block in content {
    match
      runtime_package_content_event(
        block,
        role~,
        has_tool_use~,
        base_id~,
        created_at~,
        index~,
        tool_names~,
      ) {
      Some(projected) => events.push(projected)
      None => ()
    }
  }
  events
}

///|
fn runtime_package_tool_name_map(blocks : Array[Json]) -> Map[String, String] {
  let names : Map[String, String] = {}
  for block in blocks {
    let block_type = runtime_json_string(block, "type", default="")
    if block_type != "tool_use" && block_type != "server_tool_use" {
      continue
    }
    let id = runtime_json_string(block, "id", default="")
    let name = runtime_first_string(
      block,
      ["name", "tool", "tool_name"],
      default="",
    )
    if id != "" && name != "" {
      names[id] = name
    }
  }
  names
}

///|
fn runtime_package_role(event : Json, message : Json) -> String {
  let direct = runtime_json_string(event, "role", default="")
  if direct != "" {
    return direct
  }
  let message_role = runtime_json_string(message, "role", default="")
  if message_role != "" {
    message_role
  } else {
    runtime_json_string(event, "type", default="")
  }
}

///|
fn runtime_package_content_blocks(event : Json, message : Json) -> Array[Json] {
  let direct = runtime_json_array_items(event, "content")
  if direct.length() > 0 {
    return direct
  }
  runtime_json_array_items(message, "content")
}

///|
fn runtime_package_has_tool_use(blocks : Array[Json]) -> Bool {
  for block in blocks {
    let block_type = runtime_json_string(block, "type", default="")
    if block_type == "tool_use" || block_type == "server_tool_use" {
      return true
    }
  }
  false
}

///|
fn runtime_package_content_event(
  block : Json,
  role~ : String,
  has_tool_use~ : Bool,
  base_id~ : String,
  created_at~ : String,
  index~ : Int,
  tool_names~ : Map[String, String],
) -> Json? {
  let block_type = runtime_json_string(block, "type", default="")
  let block_id = runtime_first_string(
    block,
    ["id", "tool_use_id"],
    default=base_id + "-block-" + index.to_string(),
  )
  match block_type {
    "text" => {
      let text = runtime_json_string(block, "text", default="")
        .trim()
        .to_owned()
      if text == "" || role != "assistant" {
        None
      } else {
        Some(
          event_record(
            id=block_id,
            lane="transcript",
            kind=if has_tool_use { "assistant_delta" } else { "assistant" },
            title=if has_tool_use {
              "Assistant streaming"
            } else {
              "Assistant response"
            },
            status=if has_tool_use { "running" } else { "done" },
            created_at~,
            detail=text,
          ),
        )
      }
    }
    "thinking" => {
      let thinking = runtime_first_string(
          block,
          ["thinking", "text"],
          default="",
        )
        .trim()
        .to_owned()
      if thinking == "" {
        None
      } else {
        Some(
          event_record(
            id=block_id,
            lane="runtime",
            kind=if has_tool_use {
              "reasoning_delta"
            } else {
              "reasoning_message"
            },
            title="Reasoning",
            status=if has_tool_use { "running" } else { "done" },
            created_at~,
            detail=thinking,
          ),
        )
      }
    }
    "tool_use" | "server_tool_use" => {
      let tool_name = runtime_first_string(
        block,
        ["name", "tool", "tool_name"],
        default="",
      )
      if tool_name == "" {
        None
      } else {
        let input = runtime_json_object_field_or_empty(block, "input")
        normalize_runtime_event(
          {
            "event": event_tool_call(),
            "id": block_id,
            "tool_call_id": block_id,
            "tool_name": tool_name,
            "arguments": input.stringify(),
            "created_at": created_at,
          },
          fallback_id=block_id,
          fallback_created_at=created_at,
        )
      }
    }
    "tool_result" => {
      let result_id = runtime_json_string(
        block,
        "id",
        default=base_id + "-block-" + index.to_string(),
      )
      let tool_call_id = runtime_first_string(
        block,
        ["tool_use_id", "id"],
        default=result_id,
      )
      let detail = runtime_package_block_text(block)
      let tool_name = runtime_first_string(
        block,
        ["name", "tool", "tool_name"],
        default=tool_names.get(tool_call_id).unwrap_or(""),
      )
      if tool_name != "" {
        normalize_runtime_event(
          {
            "event": event_tool_result(),
            "id": result_id,
            "tool_call_id": tool_call_id,
            "tool_name": tool_name,
            "content": detail,
            "is_error": json_bool(block, "is_error", default=false),
            "created_at": created_at,
          },
          fallback_id=block_id,
          fallback_created_at=created_at,
        )
      } else {
        Some(
          event_record(
            id=result_id,
            lane="tool",
            kind="runtime.tool_result",
            title="Tool finished",
            status=if json_bool(block, "is_error", default=false) {
              "failed"
            } else {
              "done"
            },
            created_at~,
            detail~,
          ),
        )
      }
    }
    _ => None
  }
}

///|
fn runtime_package_block_text(block : Json) -> String {
  let direct = runtime_json_string(block, "content", default="")
  if direct != "" {
    return direct
  }
  let parts = runtime_json_array_items(block, "content")
  let values : Array[String] = []
  for part in parts {
    let text = runtime_first_string(part, ["text", "content"], default="")
    if text != "" {
      values.push(text)
    }
  }
  values.join("\n")
}
