///|
fn render_mooncode_transcript(
  model : Model,
  session : MoonCodeSession,
) -> @rabbita.Html {
  let events = mooncode_transcript_events(model, session)
  if session.transcript.length() == 0 && events.length() == 0 {
    div(class="mooncode-empty", [
      h1(session.title),
      p(
        class="lead",
        "Start a MoonCode prompt to stream reasoning, tool calls, diffs, tests, and packaging evidence here.",
      ),
    ])
  } else {
    let children : Array[@rabbita.Html] = []
    for message in session.transcript {
      children.push(render_mooncode_message(message))
    }
    for event in events {
      children.push(render_mooncode_transcript_event(event))
    }
    div(class="mooncode-transcript-list mooncode-transcript", children)
  }
}

///|
fn render_mooncode_message(message : MoonCodeMessage) -> @rabbita.Html {
  div(class="mooncode-message " + message.role + " " + message.status, [
    div(class="mooncode-message-head", [
      span(class="record-kind", message.role),
      small("\{message.status} / \{message.created_at}"),
    ]),
    pre(class="mooncode-message-body", code(message.content)),
  ])
}

///|
fn mooncode_transcript_events(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeEvent] {
  let events = mooncode_merge_stream_events(session.mooncode_events, [])
  let with_stream = if model.mooncode_stream_session_id == session.id {
    mooncode_merge_stream_events(events, model.mooncode_stream_events)
  } else {
    events
  }
  match model.mooncode_runtime_event_sink {
    Some(sink) if model.mooncode_runtime_event_sink_session_id == session.id =>
      mooncode_merge_stream_events(with_stream, sink.events)
    _ => with_stream
  }
}

///|
fn render_mooncode_transcript_event(event : MoonCodeEvent) -> @rabbita.Html {
  let message_class = "mooncode-message mooncode-transcript-event " +
    mooncode_transcript_event_class(event)
  div(class=message_class, [
    div(class="mooncode-message-head", [
      span(class="record-kind", event.lane),
      small("\{event.status} / \{event.created_at}"),
    ]),
    div(class="mooncode-transcript-event-title", [
      strong(event.title),
      if event.command == "" {
        span(class="hidden-inline", "")
      } else {
        code(event.command)
      },
    ]),
    if event.path == "" {
      span(class="hidden-inline", "")
    } else {
      code(class="mooncode-transcript-path", event.path)
    },
    if event.diff != "" {
      pre(class="source-block compact", code(event.diff))
    } else {
      pre(
        class="mooncode-message-body",
        code(
          if event.detail == "" {
            mooncode_transcript_event_fallback_detail(event)
          } else {
            event.detail
          },
        ),
      )
    },
  ])
}

///|
fn mooncode_transcript_event_class(event : MoonCodeEvent) -> String {
  let lane = if event.lane == "" { "runtime" } else { event.lane }
  let state = if event.status == "failed" || event.status == "blocked" {
    "failed"
  } else {
    event.status
  }
  "\{lane} \{state}"
}

///|
fn mooncode_transcript_event_fallback_detail(event : MoonCodeEvent) -> String {
  let mut detail = if event.kind == "" {
    "MoonCode runtime event"
  } else {
    event.kind
  }
  if event.exit_code != 0 {
    detail = "\{detail}\nexit code: \{event.exit_code}"
  }
  detail
}
