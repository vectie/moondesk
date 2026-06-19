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
  let lane = if event.lane == "" {
    "runtime"
  } else {
    event.lane
  }
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

///|
fn mooncode_replace_command_preflight(
  preflights : Array[MoonCodeCommandPreflight],
  preflight : MoonCodeCommandPreflight,
) -> Array[MoonCodeCommandPreflight] {
  let next : Array[MoonCodeCommandPreflight] = []
  let mut replaced = false
  for existing in preflights {
    if existing.action == preflight.action {
      next.push(preflight)
      replaced = true
    } else {
      next.push(existing)
    }
  }
  if !replaced {
    next.push(preflight)
  }
  next
}

///|
fn mooncode_preflight_status(preflights : Array[MoonCodeCommandPreflight]) -> String {
  if preflights.length() == 0 {
    return "preflight idle"
  }
  let mut blocked = 0
  for preflight in preflights {
    if preflight.blocked {
      blocked += 1
    }
  }
  if blocked == 0 {
    "\{preflights.length()} gate(s) ready"
  } else {
    "\{blocked} blocked / \{preflights.length()} gate(s)"
  }
}

///|
fn render_mooncode_preflight_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board preflight-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "server-side gates"),
        h3("Preflight Gates"),
      ]),
      span(class="record-kind", model.mooncode_preflight_status),
    ]),
    if model.mooncode_preflights.length() == 0 {
      p(class="muted", "Select a MoonCode session to load command gates.")
    } else {
      div(
        class="mooncode-review-list",
        model.mooncode_preflights.map(preflight =>
          render_mooncode_preflight_item(dispatch, preflight)
        ),
      )
    },
  ])
}

///|
fn render_mooncode_preflight_item(
  dispatch : Dispatch[Msg],
  preflight : MoonCodeCommandPreflight,
) -> @rabbita.Html {
  let state = if preflight.blocked { "failed" } else { "approved" }
  div(class="mooncode-review-item " + state, [
    div(class="mooncode-review-head", [
      div([
        strong(preflight.title),
        small(
          if preflight.context_path == "" {
            "this MoonBook code workspace"
          } else {
            preflight.context_path
          },
        ),
      ]),
      span(
        class="record-kind",
        if preflight.blocked { "blocked" } else { "ready" },
      ),
    ]),
    p(
      class="mooncode-event-detail",
      if preflight.blocked {
        preflight.reason
      } else {
        "Ready to run with the current MoonBook evidence."
      },
    ),
    div(class="mooncode-stats", [
      info_chip("control", preflight.control),
      info_chip("approval", preflight.approval),
      info_chip("lane", preflight.lane),
      info_chip(
        "failing tests",
        if preflight.acceptance_gates.no_failing_tests { "clear" } else { "blocked" },
      ),
      info_chip(
        "verified tests",
        if preflight.acceptance_gates.has_verified_tests { "ready" } else { "missing" },
      ),
      info_chip(
        "tool approvals",
        if preflight.acceptance_gates.tool_approvals_resolved { "clear" } else { "pending" },
      ),
      info_chip(
        "diffs",
        if preflight.acceptance_gates.diffs_resolved { "resolved" } else { "pending" },
      ),
      info_chip(
        "package",
        if preflight.acceptance_gates.has_source_bound_package { "source-bound" } else { "missing" },
      ),
    ]),
    div(class="daemon-state compact-state", [
      info_row("Expected Lanes", string_list_label(preflight.expected_lanes)),
      info_row("Tool Hints", string_list_label(preflight.tool_hints)),
      info_row("Required Gates", string_list_label(preflight.required_gates)),
    ]),
    render_mooncode_preflight_selected_patch(preflight.selected_patch),
    div(class="toolbar-actions", [
      button(
        class=if preflight.blocked { "secondary-button" } else { "primary-button" },
        on_click=if preflight.context_path == "" {
          if preflight.blocked {
            dispatch(RunMoonCodeCommandOverride(preflight.action, ""))
          } else {
            dispatch(RunMoonCodeCommand(preflight.action))
          }
        } else {
          if preflight.blocked {
            dispatch(
              RunMoonCodeCommandOverride(
                preflight.action, preflight.context_path,
              ),
            )
          } else {
            dispatch(
              RunMoonCodeCommandForPath(
                preflight.action, preflight.context_path,
              ),
            )
          }
        },
        if preflight.blocked { "Try Anyway" } else { "Run" },
      ),
    ]),
  ])
}

///|
fn render_mooncode_preflight_selected_patch(
  selected : MoonCodeSelectedPatchPreflight,
) -> @rabbita.Html {
  if !selected.matched {
    span(class="hidden-inline", "")
  } else {
    div(class="daemon-state compact-state mooncode-selected-patch", [
      info_row("Patch Target", selected.context_path),
      info_row("Review", empty_label(selected.review_state)),
      info_row("Execution", empty_label(selected.execution_state)),
      info_row("Gate", empty_label(selected.gate_status)),
      info_row("Next", empty_label(selected.next_action)),
      info_row(
        "Runtime Proof",
        if selected.runtime_proven { "recorded" } else { "missing" },
      ),
      if selected.blocked_reason == "" {
        span(class="hidden-inline", "")
      } else {
        p(class="mooncode-event-detail", selected.blocked_reason)
      },
    ])
  }
}

///|
