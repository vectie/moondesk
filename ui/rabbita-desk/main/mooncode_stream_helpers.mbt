///|
fn mooncode_stream_buffer_limit() -> Int {
  80
}

///|
fn mooncode_merge_stream_events(
  existing : Array[MoonCodeEvent],
  incoming : Array[MoonCodeEvent],
) -> Array[MoonCodeEvent] {
  let merged : Array[MoonCodeEvent] = []
  for event in existing {
    mooncode_note_diagnostic_event_fields(event)
    mooncode_push_unique_stream_event(merged, event)
  }
  for event in incoming {
    mooncode_note_diagnostic_event_fields(event)
    mooncode_push_unique_stream_event(merged, event)
  }
  mooncode_trim_stream_events(merged, mooncode_stream_buffer_limit())
}

///|
fn mooncode_note_diagnostic_events(events : Array[MoonCodeEvent]) -> Unit {
  for event in events {
    mooncode_note_diagnostic_event_fields(event)
  }
}

///|
fn mooncode_note_diagnostic_event_fields(event : MoonCodeEvent) -> Unit {
  ignore(event.command_id)
  ignore(event.lane)
  ignore(event.kind)
  ignore(event.title)
  ignore(event.status)
  ignore(event.created_at)
  ignore(event.detail)
  ignore(event.path)
  ignore(event.command)
  ignore(event.exit_code)
  ignore(event.tool)
  ignore(event.tool_name)
  ignore(event.command_packet)
  ignore(event.tool_result)
}

///|
fn mooncode_push_unique_stream_event(
  events : Array[MoonCodeEvent],
  event : MoonCodeEvent,
) -> Unit {
  if event.id != "" {
    for existing in events {
      if existing.id == event.id {
        return
      }
    }
  }
  events.push(event)
}

///|
fn mooncode_trim_stream_events(
  events : Array[MoonCodeEvent],
  limit : Int,
) -> Array[MoonCodeEvent] {
  if events.length() <= limit {
    events
  } else {
    let trimmed : Array[MoonCodeEvent] = []
    let start = events.length() - limit
    for index in start..<events.length() {
      trimmed.push(events[index])
    }
    trimmed
  }
}
