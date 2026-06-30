///|
fn parse_mooncode_stream_text(
  text : String,
) -> Result[MoonCodeStreamPoll, String] {
  let events : Array[MoonCodeEvent] = []
  let mut stream = "append-log-incremental"
  let mut stream_source = "unknown"
  let mut next_since = 0
  let mut emitted_count = 0
  for line in text.split("\n") {
    let trimmed = line.trim()
    if trimmed.is_empty() {
      continue
    }
    let record = @json.parse(trimmed.to_owned()) catch {
      _ => return Err("Invalid MoonCode stream record")
    }
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
    }
  }
  Ok({ stream, stream_source, next_since, emitted_count, events })
}

///|
fn mooncode_stream_event_from_json(event : Json) -> MoonCodeEvent {
  {
    id: json_string_value(event, "id", default=""),
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
    tool_result: json_field(event, "tool_result"),
  }
}

///|
fn mooncode_stream_event_created_at(event : Json) -> String {
  let value = json_string_value(event, "created_at", default="")
  if value != "" {
    value
  } else {
    let number = json_int_value(event, "created_at", default=0)
    if number == 0 {
      ""
    } else {
      number.to_string()
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
