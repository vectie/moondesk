///|
fn render_mooncode_command_queue_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board command-queue-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "ordered command queue"),
        h3("Command Queue"),
      ]),
      span(class="record-kind", model.mooncode_command_queue_status),
    ]),
    match model.mooncode_command_queue {
      Some(queue) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", queue.command_count.to_string()),
            info_chip("Prompts", mooncode_command_queue_count(queue, "prompt").to_string()),
            info_chip("Steers", mooncode_command_queue_count(queue, "steer").to_string()),
            info_chip("Pending Steers", mooncode_pending_steer_count(model, queue.session_id).to_string()),
            info_chip("Cancels", mooncode_command_queue_count(queue, "cancel").to_string()),
            info_chip("Reviews", mooncode_command_queue_review_count(queue).to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Queue", queue.command_log_path),
            info_row("Session", queue.session_id),
            info_row("Runtime", empty_label(queue.runtime_session_id)),
            info_row("Ordering", queue.ordering_rule),
          ]),
          div(class="toolbar-actions", [
            button(
              class="secondary-button",
              on_click=dispatch(RunMoonCodeCommand("steer")),
              "Steer",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(RunMoonCodeCommand("cancel")),
              "Cancel",
            ),
          ]),
          mooncode_pending_steer_status_line(model, queue.session_id),
          if queue.commands.length() == 0 {
            p(class="status-line", "no command packets recorded")
          } else {
            div(
              class="mooncode-review-list command-queue-list",
              mooncode_recent_commands(queue.commands).map(command =>
                render_mooncode_queued_command(dispatch, command)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No durable MoonCode command queue has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_recent_commands(
  commands : Array[MoonCodeQueuedCommand]
) -> Array[MoonCodeQueuedCommand] {
  let recent : Array[MoonCodeQueuedCommand] = []
  let mut index = commands.length()
  let mut emitted = 0
  while index > 0 && emitted < 8 {
    index -= 1
    recent.push(commands[index])
    emitted += 1
  }
  recent
}

///|
fn mooncode_command_queue_count(
  queue : MoonCodeCommandQueue,
  action : String,
) -> Int {
  let mut count = 0
  for command in queue.commands {
    if command.action == action {
      count += 1
    }
  }
  count
}

///|
fn mooncode_pending_steer_count(model : Model, session_id : String) -> Int {
  let steer_count = match model.mooncode_command_queue {
    Some(queue) if queue.session_id == session_id =>
      mooncode_command_queue_count(queue, "steer")
    _ => 0
  }
  let settled_count = mooncode_steer_settlement_count(model, session_id)
  if steer_count > settled_count {
    steer_count - settled_count
  } else {
    0
  }
}

///|
fn mooncode_summary_pending_steer_label(summary : MoonCodeSummary) -> String {
  let count = summary.pending_steer_count
  if count == 0 {
    "settled"
  } else if count == 1 {
    "1 pending"
  } else {
    "\{count} pending"
  }
}

///|
fn mooncode_pending_steer_status_line(
  model : Model,
  session_id : String,
) -> @rabbita.Html {
  let count = mooncode_pending_steer_count(model, session_id)
  if count == 0 {
    @html.nothing
  } else {
    p(
      class="status-line",
      "\{count} steer request(s) are waiting for runtime apply/defer/drop confirmation.",
    )
  }
}

///|
fn mooncode_steer_settlement_count(model : Model, session_id : String) -> Int {
  match model.mooncode_runtime_event_sink {
    Some(sink) if model.mooncode_runtime_event_sink_session_id == session_id =>
      mooncode_steer_settlement_count_from_events(sink.events)
    _ =>
      if model.mooncode_stream_session_id == session_id {
        mooncode_steer_settlement_count_from_events(model.mooncode_stream_events)
      } else {
        0
      }
  }
}

///|
fn mooncode_steer_settlement_count_from_events(events : Array[MoonCodeEvent]) -> Int {
  let mut count = 0
  for event in events {
    if mooncode_event_settles_steer(event) {
      count += 1
    }
  }
  count
}

///|
fn mooncode_event_settles_steer(event : MoonCodeEvent) -> Bool {
  let text = (event.kind + "\n" + event.title + "\n" + event.detail).to_lower()
  text.contains("steer_applied") ||
  text.contains("steer applied") ||
  text.contains("steer_dropped") ||
  text.contains("steer dropped")
}

///|
fn mooncode_command_queue_review_count(queue : MoonCodeCommandQueue) -> Int {
  let mut count = 0
  for command in queue.commands {
    if command.approval == "operator" {
      count += 1
    }
  }
  count
}

///|
fn render_mooncode_queued_command(
  dispatch : Dispatch[Msg],
  command : MoonCodeQueuedCommand,
) -> @rabbita.Html {
  div(class="mooncode-review-item " + mooncode_command_queue_item_state(command), [
    div(class="mooncode-review-head", [
      div([
        strong(command.action + " -> " + command.dispatch),
        small(command.approval + " / " + command.created_at),
      ]),
      div(class="toolbar-actions", [
        if command.context_path == "" {
          span(class="hidden-inline", "")
        } else {
          button(
            class="secondary-button",
            on_click=dispatch(OpenQuickPath(command.context_path)),
            "Open",
          )
        },
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_tests", command.target)),
          "Test",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("run_build", command.target)),
          "Build",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("package", command.target)),
          "Package",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(RunMoonCodeCommandForPath("commit", command.target)),
          "Commit",
        ),
      ]),
    ]),
    div(class="mooncode-stats", [
      info_chip("Lanes", command.expected_lanes.length().to_string()),
      info_chip("Tools", command.tool_hints.length().to_string()),
      info_chip("Web", if command.web_search { "on" } else { "off" }),
    ]),
    if command.context_path == "" {
      code(command.target)
    } else {
      code(command.context_path)
    },
    p(class="mooncode-event-detail", command.message),
    small(class="status-line", command.command_id),
  ])
}

///|
fn mooncode_command_queue_item_state(command : MoonCodeQueuedCommand) -> String {
  match command.action {
    "cancel" => "rejected"
    "accept" | "approve_tool" | "apply_patch" => "accepted"
    "reject" | "reject_tool" | "revert_patch" => "rejected"
    "run_tests" | "run_build" | "run_eval" => "running"
    "package" => "pending"
    _ => "queued"
  }
}

///|
