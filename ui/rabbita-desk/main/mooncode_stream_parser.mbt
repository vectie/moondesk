///|
fn parse_mooncode_stream_text(
  text : String,
) -> Result[MoonCodeStreamPoll, String] {
  let events : Array[MoonCodeEvent] = []
  let mut stream = "append-log-incremental"
  let mut stream_source = "unknown"
  let mut next_since = 0
  let mut emitted_count = 0
  let mut buffer = ""
  for line in text.split("\n") {
    let trimmed = line.trim()
    if trimmed.is_empty() {
      continue
    }
    buffer = if buffer == "" {
      trimmed.to_owned()
    } else {
      buffer + "\n" + trimmed.to_owned()
    }
    let record = @json.parse(buffer) catch {
      _ => continue
    }
    buffer = ""
    let record_type = json_string_value(record, "type", default="")
    if record_type == "meta" {
      stream = json_string_value(record, "stream", default=stream)
      stream_source = json_string_value(
        record,
        "stream_source",
        default=stream_source,
      )
      next_since = json_int_value(record, "next_since", default=next_since)
      emitted_count = json_int_value(
        record,
        "emitted_count",
        default=emitted_count,
      )
    } else if record_type == "event" {
      match json_field(record, "event") {
        Some(event_json) => {
          events.push(mooncode_stream_event_from_json(event_json))
        }
        None => return Err("MoonCode stream event missing payload")
      }
    } else if record_type == "done" {
      stream_source = json_string_value(
        record,
        "stream_source",
        default=stream_source,
      )
      next_since = json_int_value(record, "next_since", default=next_since)
      emitted_count = json_int_value(
        record,
        "emitted_count",
        default=emitted_count,
      )
    } else {
      for event in mooncode_stream_package_events_from_json(record) {
        events.push(event)
      }
    }
  }
  if buffer != "" {
    return Err("Invalid MoonCode stream record")
  }
  Ok({ stream, stream_source, next_since, emitted_count, events })
}

///|
fn mooncode_stream_event_from_json(event : Json) -> MoonCodeEvent {
  {
    id: json_string_value(event, "id", default=""),
    command_id: mooncode_stream_event_command_id(event),
    lane: json_string_value(event, "lane", default=""),
    kind: json_string_value(event, "kind", default=""),
    title: json_string_value(event, "title", default=""),
    status: json_string_value(event, "status", default=""),
    created_at: mooncode_stream_event_created_at(event),
    detail: mooncode_stream_event_detail(event),
    path: json_string_value(event, "path", default=""),
    diff: json_string_value(event, "diff", default=""),
    command: json_string_value(event, "command", default=""),
    exit_code: json_int_value(event, "exit_code", default=0),
    command_packet: json_field(event, "command_packet"),
    tool_result: json_field(event, "tool_result"),
  }
}

///|
fn mooncode_stream_event_command_id(event : Json) -> String? {
  let direct = json_string_value(event, "command_id", default="")
  if direct != "" {
    return Some(direct)
  }
  match json_field(event, "command_packet") {
    Some(packet) => {
      let command_id = json_string_value(packet, "command_id", default="")
      if command_id == "" {
        None
      } else {
        Some(command_id)
      }
    }
    None => None
  }
}

///|
fn mooncode_stream_event_created_at(event : Json) -> String {
  let value = json_string_value(event, "created_at", default="")
  if value != "" {
    value
  } else {
    match json_field(event, "created_at") {
      Some(Number(_, repr=Some(raw))) => raw
      Some(Number(value, repr=None)) => value.to_string()
      _ => ""
    }
  }
}

///|
fn mooncode_stream_event_detail(event : Json) -> String {
  let detail = json_string_value(event, "detail", default="")
  if detail != "" {
    detail
  } else {
    json_string_value(event, "content", default="")
  }
}

///|
fn mooncode_stream_package_events_from_json(record : Json) -> Array[MoonCodeEvent] {
  let message = mooncode_stream_json_object_field_or_empty(record, "message")
  let role = mooncode_stream_package_role(record, message)
  if role != "assistant" && role != "user" {
    return []
  }
  let blocks = mooncode_stream_package_content_blocks(record, message)
  if blocks.length() == 0 {
    return []
  }
  let has_tool_use = mooncode_stream_package_has_tool_use(blocks)
  let base_id = json_string_value(
    record,
    "id",
    default="package-stream-" + record.stringify().length().to_string(),
  )
  let created_at = mooncode_stream_package_created_at(record)
  let events : Array[MoonCodeEvent] = []
  let tool_names = mooncode_stream_package_tool_name_map(blocks)
  for index, block in blocks {
    match mooncode_stream_package_content_event(
      block,
      role~,
      has_tool_use~,
      base_id~,
      created_at~,
      index~,
      tool_names~,
    ) {
      Some(event) => events.push(event)
      None => ()
    }
  }
  events
}

///|
fn mooncode_stream_package_tool_name_map(
  blocks : Array[Json],
) -> Map[String, String] {
  let names : Map[String, String] = {}
  for block in blocks {
    let block_type = json_string_value(block, "type", default="")
    if block_type != "tool_use" && block_type != "server_tool_use" {
      continue
    }
    let id = json_string_value(block, "id", default="")
    let name = mooncode_stream_first_json_string(
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
fn mooncode_stream_package_role(record : Json, message : Json) -> String {
  let direct = json_string_value(record, "role", default="")
  if direct != "" {
    return direct
  }
  let message_role = json_string_value(message, "role", default="")
  if message_role != "" {
    message_role
  } else {
    json_string_value(record, "type", default="")
  }
}

///|
fn mooncode_stream_package_content_blocks(record : Json, message : Json) -> Array[Json] {
  let direct = mooncode_stream_json_array_items(record, "content")
  if direct.length() > 0 {
    return direct
  }
  mooncode_stream_json_array_items(message, "content")
}

///|
fn mooncode_stream_package_has_tool_use(blocks : Array[Json]) -> Bool {
  for block in blocks {
    let block_type = json_string_value(block, "type", default="")
    if block_type == "tool_use" || block_type == "server_tool_use" {
      return true
    }
  }
  false
}

///|
fn mooncode_stream_package_content_event(
  block : Json,
  role~ : String,
  has_tool_use~ : Bool,
  base_id~ : String,
  created_at~ : String,
  index~ : Int,
  tool_names~ : Map[String, String],
) -> MoonCodeEvent? {
  let block_type = json_string_value(block, "type", default="")
  let block_id = mooncode_stream_first_json_string(
    block,
    ["id", "tool_use_id"],
    default=base_id + "-block-" + index.to_string(),
  )
  match block_type {
    "text" => {
      let text = json_string_value(block, "text", default="").trim().to_owned()
      if text == "" || role != "assistant" {
        None
      } else {
        Some(mooncode_stream_event(
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
        ))
      }
    }
    "thinking" => {
      let thinking = mooncode_stream_first_json_string(
        block,
        ["thinking", "text"],
        default="",
      ).trim().to_owned()
      if thinking == "" {
        None
      } else {
        Some(mooncode_stream_event(
          id=block_id,
          lane="runtime",
          kind=if has_tool_use { "reasoning_delta" } else { "reasoning_message" },
          title="Reasoning",
          status=if has_tool_use { "running" } else { "done" },
          created_at~,
          detail=thinking,
        ))
      }
    }
    "tool_use" | "server_tool_use" => {
      let tool_name = mooncode_stream_first_json_string(
        block,
        ["name", "tool", "tool_name"],
        default="",
      )
      if tool_name == "" {
        None
      } else {
        let input = mooncode_stream_json_object_field_or_empty(block, "input")
        let command = mooncode_stream_tool_command(input)
        Some(mooncode_stream_event(
          id=block_id,
          lane=mooncode_stream_tool_lane(tool_name, command),
          kind="tool_call",
          title="Tool started: " + tool_name,
          status="running",
          created_at~,
          detail="{\"tool\":\"" + tool_name + "\",\"arguments\":" + input.stringify() + "}",
          path=mooncode_stream_tool_path(input),
          command~,
        ))
      }
    }
    "tool_result" => {
      let result_id = json_string_value(
        block,
        "id",
        default=base_id + "-block-" + index.to_string(),
      )
      let detail = mooncode_stream_package_block_text(block)
      let tool_call_id = mooncode_stream_first_json_string(
        block,
        ["tool_use_id", "id"],
        default="",
      )
      let tool_name = mooncode_stream_first_json_string(
        block,
        ["name", "tool", "tool_name"],
        default=tool_names.get(tool_call_id).unwrap_or(""),
      )
      Some(mooncode_stream_event(
        id=result_id,
        lane="tool",
        kind="tool_result",
        title="Tool finished",
        status=if mooncode_stream_json_bool_value(
          block,
          "is_error",
          default=false,
        ) {
          "failed"
        } else {
          "done"
        },
        created_at~,
        detail~,
        tool_result=Some({
          "tool": tool_name,
          "output": detail,
        }),
      ))
    }
    _ => None
  }
}

///|
fn mooncode_stream_event(
  id~ : String,
  command_id? : String = "",
  lane~ : String,
  kind~ : String,
  title~ : String,
  status~ : String,
  created_at~ : String,
  detail~ : String,
  path? : String = "",
  command? : String = "",
  command_packet? : Json? = None,
  tool_result? : Json? = None,
) -> MoonCodeEvent {
  {
    id,
    command_id: if command_id == "" { None } else { Some(command_id) },
    lane,
    kind,
    title,
    status,
    created_at,
    detail,
    path,
    diff: "",
    command,
    exit_code: 0,
    command_packet,
    tool_result,
  }
}

///|
fn mooncode_stream_tool_lane(tool_name : String, command : String) -> String {
  let lower = "\{tool_name}\n\{command}".to_lower()
  if lower.contains("test") ||
    lower.contains("check") ||
    lower.contains("build") {
    "test"
  } else {
    "tool"
  }
}

///|
fn mooncode_stream_tool_command(input : Json) -> String {
  let command = mooncode_stream_first_json_string(
    input,
    ["command", "cmd"],
    default="",
  )
  if command != "" {
    return command
  }
  match json_field(input, "cmd") {
    Some(Array(parts)) => {
      let values : Array[String] = []
      for part in parts {
        match part {
          String(text) => values.push(text)
          _ => ()
        }
      }
      values.join(" ")
    }
    _ => ""
  }
}

///|
fn mooncode_stream_tool_path(input : Json) -> String {
  mooncode_stream_first_json_string(
    input,
    ["path", "file_path", "notebook_path", "file", "target"],
    default="",
  )
}

///|
fn mooncode_stream_package_block_text(block : Json) -> String {
  match json_field(block, "content") {
    Some(String(text)) if text != "" => return text
    Some(content) =>
      match content {
        Object(_) => return content.stringify()
        Array(items) => return mooncode_stream_package_block_array_text(items)
        _ => ()
      }
    _ => ()
  }
  let values : Array[String] = []
  for part in mooncode_stream_json_array_items(block, "structuredContent") {
    let text = mooncode_stream_first_json_string(
      part,
      ["text", "content"],
      default="",
    )
    if text != "" {
      values.push(text)
    }
  }
  values.join("\n")
}

///|
fn mooncode_stream_package_block_array_text(items : Array[Json]) -> String {
  let values : Array[String] = []
  let structured : Array[String] = []
  for part in items {
    match part {
      String(text) if text != "" => values.push(text)
      Object(_) => {
        let text = mooncode_stream_first_json_string(
          part,
          ["text", "content"],
          default="",
        )
        if text != "" {
          values.push(text)
        } else {
          structured.push(part.stringify())
        }
      }
      _ => ()
    }
  }
  if values.length() > 0 {
    values.join("\n")
  } else {
    structured.join("\n")
  }
}

///|
fn mooncode_stream_package_created_at(record : Json) -> String {
  let value = json_string_value(record, "created_at", default="")
  if value != "" {
    value
  } else {
    match json_field(record, "created_at") {
      Some(Number(_, repr=Some(raw))) => raw
      Some(Number(value, repr=None)) => value.to_string()
      _ => ""
    }
  }
}

///|
fn mooncode_stream_first_json_string(
  json : Json,
  keys : Array[String],
  default~ : String,
) -> String {
  for key in keys {
    let value = json_string_value(json, key, default="").trim().to_owned()
    if value != "" {
      return value
    }
  }
  default
}

///|
fn mooncode_stream_json_object_field_or_empty(json : Json, key : String) -> Json {
  match json_field(json, key) {
    Some(value) =>
      match value {
        Object(_) => value
        _ => Json::object({})
      }
    None => Json::object({})
  }
}

///|
fn mooncode_stream_json_array_items(json : Json, key : String) -> Array[Json] {
  match json_field(json, key) {
    Some(Array(items)) => items
    _ => []
  }
}

///|
fn mooncode_stream_json_bool_value(
  json : Json,
  key : String,
  default~ : Bool,
) -> Bool {
  match json_field(json, key) {
    Some(value) => @json.from_json(value) catch { _ => default }
    None => default
  }
}
