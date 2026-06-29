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
          let event : MoonCodeEvent = @json.from_json(event_json) catch {
            _ => return Err("Invalid MoonCode stream event")
          }
          events.push(event)
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
