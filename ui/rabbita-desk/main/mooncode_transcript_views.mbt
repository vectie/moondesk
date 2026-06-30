///|
struct MoonCodeTranscriptRow {
  role : String
  content : String
  status : String
}

///|
fn render_mooncode_transcript(
  model : Model,
  session : MoonCodeSession,
) -> @rabbita.Html {
  let rows = mooncode_transcript_rows(model, session)
  if rows.length() == 0 {
    div(class="mooncode-empty", [
      h1(session.title),
      p(class="lead", "Start a MoonCode prompt to begin the conversation."),
    ])
  } else {
    let children : Array[@rabbita.Html] = []
    for row in rows {
      children.push(render_mooncode_transcript_row(row))
    }
    div(class="mooncode-transcript-list mooncode-transcript", children)
  }
}

///|
fn render_mooncode_transcript_row(row : MoonCodeTranscriptRow) -> @rabbita.Html {
  div(class="mooncode-message " + row.role + " " + row.status, [
    pre(class="mooncode-message-body", row.content),
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
      mooncode_order_transcript_events(
        mooncode_merge_stream_events(with_stream, sink.events),
      )
    _ => mooncode_order_transcript_events(with_stream)
  }
}

///|
fn mooncode_order_transcript_events(
  events : Array[MoonCodeEvent],
) -> Array[MoonCodeEvent] {
  events.sort_by(fn(left, right) {
    let by_time = left.created_at.compare(right.created_at)
    if by_time != 0 {
      by_time
    } else {
      left.id.compare(right.id)
    }
  })
  events
}

///|
fn mooncode_transcript_rows(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptRow] {
  let conversation_rows = mooncode_conversation_transcript_rows(model, session)
  if conversation_rows.length() > 0 {
    return conversation_rows
  }
  let event_conversation = mooncode_hydrate_conversation_from_events(
    [],
    session.id,
    mooncode_transcript_events(model, session),
  )
  let event_rows = mooncode_conversation_rows_to_transcript(
    event_conversation,
    session.id,
  )
  if event_rows.length() > 0 {
    return event_rows
  }
  let pending_rows : Array[MoonCodeTranscriptRow] = []
  let pending_keys : Array[String] = []
  let pending_inserted : Array[String] = []
  mooncode_insert_due_pending_prompts(
    pending_rows,
    pending_keys,
    model,
    session.id,
    pending_inserted,
  )
  if pending_rows.length() > 0 &&
    !mooncode_transcript_last_row_is_assistant(pending_rows) {
    pending_rows.push({
      role: "assistant",
      content: "Working on it...",
      status: "running",
    })
  }
  return pending_rows
}

///|
fn mooncode_session_has_pending_prompt(model : Model, session_id : String) -> Bool {
  for prompt in model.mooncode_pending_prompts {
    if prompt.session_id == session_id {
      return true
    }
  }
  false
}

///|
fn mooncode_insert_due_pending_prompts(
  rows : Array[MoonCodeTranscriptRow],
  keys : Array[String],
  model : Model,
  session_id : String,
  inserted_keys : Array[String],
) -> Unit {
  for prompt in model.mooncode_pending_prompts {
    if prompt.session_id != session_id {
      continue
    }
    let key = mooncode_pending_prompt_key(prompt)
    if inserted_keys.contains(key) || rows.length() < prompt.after_row_count {
      continue
    }
    inserted_keys.push(key)
    mooncode_push_transcript_row(rows, keys, {
      role: "user",
      content: prompt.content,
      status: prompt.status,
    })
  }
}

///|
fn mooncode_pending_prompt_key(prompt : MoonCodePendingPrompt) -> String {
  "\{prompt.session_id}\n\{prompt.after_row_count}\n\{prompt.content}"
}

fn mooncode_push_transcript_row(
  rows : Array[MoonCodeTranscriptRow],
  keys : Array[String],
  row : MoonCodeTranscriptRow,
) -> Unit {
  ignore(keys)
  let content = row.content.trim().to_owned()
  if content == "" {
    return
  }
  let role = mooncode_transcript_message_role(row.role)
  if mooncode_transcript_last_row_matches(rows, role, content) {
    return
  }
  rows.push({ ..row, role, content })
}

///|
fn mooncode_transcript_last_row_matches(
  rows : Array[MoonCodeTranscriptRow],
  role : String,
  content : String,
) -> Bool {
  if rows.length() == 0 {
    return false
  }
  let last = rows[rows.length() - 1]
  last.role == role && last.content == content
}

///|
fn mooncode_transcript_last_row_is_assistant(
  rows : Array[MoonCodeTranscriptRow],
) -> Bool {
  rows.length() > 0 && rows[rows.length() - 1].role == "assistant"
}

///|
fn mooncode_transcript_message_role(role : String) -> String {
  match role {
    "user" => "user"
    "assistant" => "assistant"
    "tool" | "status" | "activity" => "activity"
    _ => "activity"
  }
}

///|
fn mooncode_event_is_user_prompt(event : MoonCodeEvent) -> Bool {
  (event.lane == "transcript" && event.kind == "user") ||
  event.command == "prompt" ||
  event.command == "steer" ||
  event.kind == "command.prompt" ||
  event.kind == "command.steer" ||
  event.title == "User prompt"
}

///|
fn mooncode_event_is_assistant_final(event : MoonCodeEvent) -> Bool {
  (event.lane == "transcript" && event.kind == "assistant") ||
  event.kind == "finish" ||
  event.title == "Assistant response"
}

///|
fn mooncode_event_is_assistant_delta(event : MoonCodeEvent) -> Bool {
  event.lane == "transcript" && event.kind == "assistant_delta"
}

///|
fn mooncode_event_assistant_content(event : MoonCodeEvent) -> String {
  match event.tool_result {
    Some(result) => {
      let output = json_string_value(result, "output", default="")
        .trim()
        .to_owned()
      if output != "" && !mooncode_event_finish_content_is_status(output) {
        return output
      }
    }
    None => ()
  }
  let content = event.detail.trim().to_owned()
  if event.kind == "finish" && mooncode_event_finish_content_is_status(content) {
    ""
  } else {
    content
  }
}

///|
fn mooncode_event_is_terminal_without_answer(event : MoonCodeEvent) -> Bool {
  (
    event.kind == "finish" ||
    event.kind == "runtime.turn_finished" ||
    event.kind == "runtime_loop" ||
    event.kind == "runtime.service_finished"
  ) &&
  (event.status == "done" || event.status == "failed")
}

///|
fn mooncode_event_finish_content_is_status(content : String) -> Bool {
  content == "" ||
  content == "finished" ||
  content == "Runtime command finished." ||
  content.contains("runtime loop completed") ||
  content.contains("MoonClaw native MoonCode runtime") ||
  content.contains("Native MoonCode runtime recorded this prompt")
}

///|
fn mooncode_session_is_active(session : MoonCodeSession) -> Bool {
  session.status == "running" ||
  session.status == "queued" ||
  session.status == "created" ||
  session.queued_count > 0
}
