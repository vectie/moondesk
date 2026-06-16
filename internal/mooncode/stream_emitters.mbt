///|
// MoonCode stream text and tail emitters.

///|
pub fn stream_jsonl_text(
  session : Json,
  events : Array[Json],
  since? : Int = 0,
) -> String {
  let latest_sequence = events.length()
  let emitted_count = stream_emitted_count(events, since)
  let lines : Array[String] = [
    stream_meta_record(session, since~, emitted_count~, latest_sequence~).stringify(),
  ]
  let mut sequence = 0
  for event in events {
    sequence += 1
    if sequence <= since {
      continue
    }
    lines.push(
      stream_event_record(session, event, sequence, since~).stringify(),
    )
  }
  lines.push(
    stream_done_record(session, latest_sequence, since~, emitted_count~).stringify(),
  )
  lines.join("\n") + "\n"
}

///|
pub fn stream_sse_text(
  session : Json,
  events : Array[Json],
  since? : Int = 0,
) -> String {
  let latest_sequence = events.length()
  let emitted_count = stream_emitted_count(events, since)
  let chunks : Array[String] = [
    stream_sse_chunk(
      "mooncode.meta",
      stream_meta_record(session, since~, emitted_count~, latest_sequence~),
    ),
  ]
  let mut sequence = 0
  for event in events {
    sequence += 1
    if sequence <= since {
      continue
    }
    chunks.push(
      stream_sse_chunk(
        "mooncode.event",
        stream_event_record(session, event, sequence, since~),
      ),
    )
  }
  chunks.push(
    stream_sse_chunk(
      "mooncode.done",
      stream_done_record(session, latest_sequence, since~, emitted_count~),
    ),
  )
  chunks.join("")
}

///|
pub fn stream_tail_event_records(
  session : Json,
  events : Array[Json],
  since : Int,
) -> Array[Json] {
  let tail : Array[Json] = []
  let mut sequence = 0
  for event in events {
    sequence += 1
    if sequence > since {
      tail.push(stream_event_record(session, event, sequence, since~))
    }
  }
  tail
}

///|
fn stream_sse_chunk(name : String, payload : Json) -> String {
  "event: \{name}\n" + "data: \{payload.stringify()}\n\n"
}
