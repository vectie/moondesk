///|
fn render_mooncode_runtime_event_sink_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-event-sink-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "runtime event ingress"),
        h3("Runtime Events"),
      ]),
      span(class="record-kind", model.mooncode_runtime_event_sink_status),
    ]),
    match model.mooncode_runtime_event_sink {
      Some(sink) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Events", sink.event_count.to_string()),
            info_chip(
              "Payloads",
              json_field_string_array_items(
                sink.post_contract, "accepted_payloads",
              ).length().to_string(),
            ),
            info_chip(
              "Producer",
              json_field_string(
                sink.post_contract, "producer", default="moonclaw",
              ),
            ),
            info_chip(
              "Commands",
              json_field_int(
                sink.command_progress, "command_count", default=0,
              ).to_string(),
            ),
            info_chip(
              "Scoped",
              json_field_int(
                sink.command_progress, "scoped_event_count", default=0,
              ).to_string(),
            ),
            info_chip(
              "Unscoped",
              json_field_int(
                sink.unscoped_progress, "event_count", default=0,
              ).to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Event Log", sink.event_log_path),
            info_row(
              "Post Endpoint",
              json_field_string(sink.post_contract, "endpoint", default=""),
            ),
            info_row(
              "Method",
              json_field_string(sink.post_contract, "method", default="POST"),
            ),
            info_row(
              "Ordering",
              json_field_string(sink.post_contract, "ordering_rule", default=""),
            ),
          ]),
          div(class="mooncode-output-roots", [
            small("Accepted payloads"),
            p(
              json_field_string_array_items(
                sink.post_contract, "accepted_payloads",
              ).join("; "),
            ),
          ]),
          p(
            class="mooncode-event-detail",
            json_field_string(sink.post_contract, "normalization", default=""),
          ),
          render_mooncode_runtime_event_command_progress(sink.command_progress),
          render_mooncode_runtime_unscoped_progress(sink.unscoped_progress),
          if sink.events.length() == 0 {
            p(class="status-line", "no durable runtime events recorded")
          } else {
            div(
              class="mooncode-event-list compact",
              mooncode_recent_runtime_sink_events(sink.events).map(event =>
                render_mooncode_event(event)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime event sink has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_runtime_event_command_progress(
  progress : Json
) -> @rabbita.Html {
  let commands = json_field_json_array_items(progress, "commands")
  div(class="mooncode-review-board embedded-board", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "command-scoped runtime proof"),
        h3("Command Progress"),
      ]),
      span(
        class="record-kind",
        json_field_int(progress, "command_count", default=0).to_string() +
        " command(s)",
      ),
    ]),
    if commands.length() == 0 {
      p(
        class="status-line",
        "no command-scoped runtime events have been recorded",
      )
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_runtime_command_progress(commands).map(command =>
          render_mooncode_runtime_command_progress_item(command)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(progress, "rule", default=""),
    ),
  ])
}

///|
fn render_mooncode_runtime_unscoped_progress(
  progress : Json
) -> @rabbita.Html {
  let events = json_field_json_array_items(progress, "recent_events")
  div(class="mooncode-review-board embedded-board", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "live events without command proof"),
        h3("Unscoped Live Events"),
      ]),
      span(
        class=if json_field_int(progress, "event_count", default=0) > 0 {
          "record-kind warning"
        } else {
          "record-kind"
        },
        json_field_int(progress, "event_count", default=0).to_string() +
        " event(s)",
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Running", json_field_int(progress, "running_event_count", default=0).to_string()),
      info_chip("Done", json_field_int(progress, "done_event_count", default=0).to_string()),
      info_chip("Failed", json_field_int(progress, "failed_event_count", default=0).to_string()),
      info_chip("Tools", json_field_int(progress, "tool_event_count", default=0).to_string()),
      info_chip("Transcript", json_field_int(progress, "transcript_event_count", default=0).to_string()),
    ]),
    div(class="daemon-state compact-state", [
      info_row("Latest", empty_label(json_field_string(progress, "latest_title", default=""))),
      info_row("Latest Status", empty_label(json_field_string(progress, "latest_status", default=""))),
      info_row("Lanes", json_field_string_array_items(progress, "lanes").join(", ")),
    ]),
    if events.length() == 0 {
      p(class="status-line", "no unscoped live runtime events")
    } else {
      div(
        class="mooncode-review-list compact",
        events.map(event => render_mooncode_runtime_unscoped_event_item(event)),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(progress, "rule", default=""),
    ),
  ])
}

///|
fn render_mooncode_runtime_unscoped_event_item(event : Json) -> @rabbita.Html {
  let status = json_field_string(event, "status", default="done")
  div(class="mooncode-review-item " + mooncode_runtime_command_progress_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(
          json_field_string(event, "lane", default="runtime") +
          " -> " +
          json_field_string(event, "kind", default="event"),
        ),
        small(empty_label(json_field_string(event, "created_at", default=""))),
      ]),
      span(class="record-kind", empty_label(json_field_string(event, "id", default=""))),
    ]),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(event, "title", default="")) +
      " / " +
      empty_label(json_field_string(event, "detail", default="")),
    ),
  ])
}

///|
fn mooncode_recent_runtime_command_progress(
  commands : Array[Json]
) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = commands.length()
  let mut emitted = 0
  while index > 0 && emitted < 6 {
    index -= 1
    recent.push(commands[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_runtime_command_progress_item(command : Json) -> @rabbita.Html {
  let status = json_field_string(command, "status", default="idle")
  div(class="mooncode-review-item " + mooncode_runtime_command_progress_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(
          json_field_string(command, "action", default="prompt") +
          " -> " +
          status,
        ),
        small(empty_label(json_field_string(command, "latest_created_at", default=""))),
      ]),
      span(class="record-kind", json_field_string(command, "latest_event_id", default="event")),
    ]),
    div(class="mooncode-stats", [
      info_chip("Events", json_field_int(command, "event_count", default=0).to_string()),
      info_chip("Running", json_field_int(command, "running_event_count", default=0).to_string()),
      info_chip("Done", json_field_int(command, "done_event_count", default=0).to_string()),
      info_chip("Failed", json_field_int(command, "failed_event_count", default=0).to_string()),
      info_chip("Tools", "\{json_field_int(command, "tool_call_count", default=0)}/\{json_field_int(command, "tool_result_count", default=0)}"),
    ]),
    code(json_field_string(command, "command_id", default="")),
    p(
      class="mooncode-event-detail",
      "lanes " +
      json_field_string_array_items(command, "lanes").join(", ") +
      "; latest " +
      empty_label(json_field_string(command, "latest_title", default="")),
    ),
  ])
}

///|
fn mooncode_runtime_command_progress_class(status : String) -> String {
  match status {
    "done" => "accepted"
    "failed" => "rejected"
    "running" => "running"
    _ => "queued"
  }
}

///|
fn mooncode_recent_runtime_sink_events(
  events : Array[MoonCodeEvent]
) -> Array[MoonCodeEvent] {
  let recent : Array[MoonCodeEvent] = []
  let mut index = events.length()
  let mut emitted = 0
  while index > 0 && emitted < 8 {
    index -= 1
    recent.push(events[index])
    emitted += 1
  }
  recent
}

