///|
pub fn runtime_event_command_progress(events : Array[Json]) -> Json {
  let command_ids : Array[String] = []
  let actions : Array[String] = []
  for event in events {
    let packet = runtime_json_object_field_or_empty(event, "command_packet")
    let command_id = json_string(packet, "command_id", default="")
    if command_id == "" {
      continue
    }
    let action = runtime_command_progress_action(event, packet)
    if runtime_command_progress_index(command_ids, actions, command_id, action) <
      0 {
      command_ids.push(command_id)
      actions.push(action)
    }
  }
  let items : Array[Json] = []
  let mut total_scoped_events = 0
  let mut running_commands = 0
  let mut failed_commands = 0
  let mut completed_commands = 0
  for index in 0..<command_ids.length() {
    let command_id = command_ids[index]
    let action = actions[index]
    let item = runtime_event_command_progress_item(command_id, action, events)
    total_scoped_events += runtime_json_int(item, "event_count", default=0)
    match json_string(item, "status", default="idle") {
      "failed" => failed_commands += 1
      "running" => running_commands += 1
      "done" => completed_commands += 1
      _ => ()
    }
    items.push(item)
  }
  {
    "kind": "mooncode-runtime-event-command-progress",
    "protocol": protocol_version(),
    "command_count": items.length(),
    "scoped_event_count": total_scoped_events,
    "running_command_count": running_commands,
    "failed_command_count": failed_commands,
    "completed_command_count": completed_commands,
    "commands": Json::array(items),
    "rule": "Progress is grouped only from runtime events with a command_packet.command_id or MoonCode command_id; unscoped transcript/runtime events remain visible but do not prove a command.",
  }
}

///|
pub fn runtime_event_unscoped_progress(events : Array[Json]) -> Json {
  let lanes : Array[String] = []
  let kinds : Array[String] = []
  let unscoped_events : Array[Json] = []
  let mut running_count = 0
  let mut done_count = 0
  let mut failed_count = 0
  let mut tool_event_count = 0
  let mut transcript_event_count = 0
  let mut latest_event_id = ""
  let mut latest_title = ""
  let mut latest_status = ""
  let mut latest_created_at = ""
  for event in events {
    if runtime_event_has_command_scope(event) {
      continue
    }
    let lane = json_string(event, "lane", default=event_lane_default())
    if !runtime_event_string_array_contains(lanes, lane) {
      lanes.push(lane)
    }
    let kind = json_string(event, "kind", default="")
    if kind != "" && !runtime_event_string_array_contains(kinds, kind) {
      kinds.push(kind)
    }
    match json_string(event, "status", default="") {
      "running" => running_count += 1
      "failed" => failed_count += 1
      _ => done_count += 1
    }
    if lane == event_lane_tool() ||
      json_string(event, "tool_call_id", default="") != "" {
      tool_event_count += 1
    }
    if lane == event_lane_transcript() {
      transcript_event_count += 1
    }
    latest_event_id = json_string(event, "id", default="")
    latest_title = json_string(event, "title", default="")
    latest_status = json_string(event, "status", default="")
    latest_created_at = json_string(event, "created_at", default="")
    unscoped_events.push(runtime_event_unscoped_progress_item(event))
  }
  let recent = runtime_recent_unscoped_events(unscoped_events, limit=6)
  {
    "kind": "mooncode-runtime-unscoped-progress",
    "protocol": protocol_version(),
    "event_count": unscoped_events.length(),
    "running_event_count": running_count,
    "done_event_count": done_count,
    "failed_event_count": failed_count,
    "tool_event_count": tool_event_count,
    "transcript_event_count": transcript_event_count,
    "lanes": runtime_event_string_array_json(lanes),
    "kinds": runtime_event_string_array_json(kinds),
    "latest_event_id": latest_event_id,
    "latest_title": latest_title,
    "latest_status": latest_status,
    "latest_created_at": latest_created_at,
    "recent_events": Json::array(recent),
    "rule": "Unscoped runtime events are live transcript, reasoning, tool, or progress records without command_packet.command_id. They are useful live evidence but do not satisfy command proof gates until the runtime binds them to a MoonCode command.",
  }
}

///|
pub fn runtime_event_command_rows(
  events : Array[Json],
  source~ : String,
) -> Array[Json] {
  let progress = runtime_event_command_progress(events)
  let commands = runtime_json_array_items(progress, "commands")
  let rows : Array[Json] = []
  for command in commands {
    rows.push({
      "command_id": json_string(command, "command_id", default=""),
      "action": json_string(command, "action", default="prompt"),
      "status": json_string(command, "status", default=""),
      "created_at": json_string(command, "latest_created_at", default=""),
      "message": json_string(command, "latest_title", default=""),
      "source": source,
      "event_count": runtime_json_int(command, "event_count", default=0),
      "latest_event_id": json_string(command, "latest_event_id", default=""),
    })
  }
  rows
}

///|
fn runtime_event_has_command_scope(event : Json) -> Bool {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  json_string(packet, "command_id", default="") != ""
}

///|
fn runtime_event_unscoped_progress_item(event : Json) -> Json {
  {
    "id": json_string(event, "id", default=""),
    "lane": json_string(event, "lane", default="runtime"),
    "kind": json_string(event, "kind", default=""),
    "title": json_string(event, "title", default=""),
    "status": json_string(event, "status", default=""),
    "created_at": json_string(event, "created_at", default=""),
    "detail": runtime_trimmed_text(
      json_string(event, "detail", default=""),
      fallback="",
    ),
    "path": json_string(event, "path", default=""),
  }
}

///|
fn runtime_recent_unscoped_events(
  events : Array[Json],
  limit~ : Int,
) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = events.length()
  let mut emitted = 0
  while index > 0 && emitted < limit {
    index -= 1
    recent.push(events[index])
    emitted += 1
  }
  recent
}

///|
fn runtime_event_command_progress_item(
  command_id : String,
  action : String,
  events : Array[Json],
) -> Json {
  let lanes : Array[String] = []
  let kinds : Array[String] = []
  let mut event_count = 0
  let mut running_count = 0
  let mut done_count = 0
  let mut failed_count = 0
  let mut tool_call_count = 0
  let mut tool_result_count = 0
  let mut latest_event_id = ""
  let mut latest_title = ""
  let mut latest_status = ""
  let mut latest_created_at = ""
  for event in events {
    let packet = runtime_json_object_field_or_empty(event, "command_packet")
    if json_string(packet, "command_id", default="") != command_id ||
      runtime_command_progress_action(event, packet) != action {
      continue
    }
    event_count += 1
    let lane = json_string(event, "lane", default=event_lane_default())
    if !runtime_event_string_array_contains(lanes, lane) {
      lanes.push(lane)
    }
    let kind = json_string(event, "kind", default="")
    if kind != "" && !runtime_event_string_array_contains(kinds, kind) {
      kinds.push(kind)
    }
    match json_string(event, "status", default="") {
      "running" => running_count += 1
      "failed" => failed_count += 1
      _ => done_count += 1
    }
    if json_string(event, "tool_call_id", default="") != "" {
      if json_string(event, "status", default="") == "running" {
        tool_call_count += 1
      } else {
        tool_result_count += 1
      }
    }
    latest_event_id = json_string(event, "id", default="")
    latest_title = json_string(event, "title", default="")
    latest_status = json_string(event, "status", default="")
    latest_created_at = json_string(event, "created_at", default="")
  }
  let status = if failed_count > 0 {
    "failed"
  } else if running_count > 0 {
    "running"
  } else if event_count > 0 {
    "done"
  } else {
    "idle"
  }
  {
    "command_id": command_id,
    "action": action,
    "status": status,
    "event_count": event_count,
    "running_event_count": running_count,
    "done_event_count": done_count,
    "failed_event_count": failed_count,
    "tool_call_count": tool_call_count,
    "tool_result_count": tool_result_count,
    "lanes": runtime_event_string_array_json(lanes),
    "kinds": runtime_event_string_array_json(kinds),
    "latest_event_id": latest_event_id,
    "latest_title": latest_title,
    "latest_status": latest_status,
    "latest_created_at": latest_created_at,
  }
}

///|
fn runtime_command_progress_action(event : Json, packet : Json) -> String {
  let packet_action = json_string(packet, "action", default="")
  if packet_action != "" {
    return packet_action
  }
  let command = json_string(event, "command", default="")
  if command != "" {
    command
  } else {
    "prompt"
  }
}

///|
fn runtime_command_progress_index(
  command_ids : Array[String],
  actions : Array[String],
  command_id : String,
  action : String,
) -> Int {
  for index in 0..<command_ids.length() {
    if command_ids[index] == command_id && actions[index] == action {
      return index
    }
  }
  -1
}

///|
fn runtime_event_string_array_contains(
  items : Array[String],
  target : String,
) -> Bool {
  for item in items {
    if item == target {
      return true
    }
  }
  false
}

///|
fn runtime_event_string_array_json(items : Array[String]) -> Json {
  @mooncore.string_array_json(items)
}
