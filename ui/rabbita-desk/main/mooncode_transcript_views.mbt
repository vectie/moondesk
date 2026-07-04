///|
struct MoonCodeTranscriptRow {
  role : String
  content : String
  status : String
}

///|
struct MoonCodeTranscriptItem {
  message : MoonCodeTranscriptRow?
  activity : MoonCodeActivityRow?
}

///|
fn render_mooncode_transcript(
  model : Model,
  session : MoonCodeSession,
) -> @rabbita.Html {
  let items = mooncode_transcript_items(model, session)
  if items.length() == 0 {
    div(class="mooncode-empty", [
      h1(session.title),
      p(class="lead", "Start a MoonCode prompt to begin the conversation."),
    ])
  } else {
    let children : Array[@rabbita.Html] = []
    for item in items {
      match item.message {
        Some(row) => children.push(render_mooncode_transcript_row(row))
        None =>
          match item.activity {
            Some(row) => children.push(render_mooncode_activity_row(row))
            None => ()
          }
      }
    }
    div(class="mooncode-transcript-list mooncode-transcript", children)
  }
}

///|
fn mooncode_transcript_items(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptItem] {
  mooncode_canonical_transcript_items(model, session)
}

///|
fn mooncode_transcript_message_item(
  row : MoonCodeTranscriptRow,
) -> MoonCodeTranscriptItem {
  { message: Some(row), activity: None }
}

///|
fn mooncode_transcript_activity_item(
  row : MoonCodeActivityRow,
) -> MoonCodeTranscriptItem {
  { message: None, activity: Some(row) }
}

///|
fn mooncode_fold_resolved_thinking_items(
  items : Array[MoonCodeTranscriptItem],
) -> Array[MoonCodeTranscriptItem] {
  let rest : Array[MoonCodeTranscriptItem] = []
  for index in 0..<items.length() {
    let item = items[index]
    if mooncode_transcript_item_is_thinking_activity(item) &&
      mooncode_transcript_has_assistant_after_before_user(items, index) {
      match item.activity {
        Some(row) =>
          rest.push(
            mooncode_transcript_activity_item(
              mooncode_fold_resolved_thinking_row(row),
            ),
          )
        None => rest.push(item)
      }
    } else {
      rest.push(item)
    }
  }
  rest
}

///|
fn mooncode_fold_resolved_thinking_row(
  row : MoonCodeActivityRow,
) -> MoonCodeActivityRow {
  {
    ..row,
    folded: true,
    status: if row.status == "running" {
      "done"
    } else {
      row.status
    },
  }
}

///|
fn mooncode_compact_folded_thinking_items(
  items : Array[MoonCodeTranscriptItem],
) -> Array[MoonCodeTranscriptItem] {
  let rest : Array[MoonCodeTranscriptItem] = []
  let thinking_rows : Array[MoonCodeActivityRow] = []
  for item in items {
    match item.activity {
      Some(row) if mooncode_activity_row_is_folded_thinking(row) =>
        thinking_rows.push(row)
      _ => {
        mooncode_push_compacted_thinking_rows(rest, thinking_rows)
        thinking_rows.clear()
        rest.push(item)
      }
    }
  }
  mooncode_push_compacted_thinking_rows(rest, thinking_rows)
  rest
}

///|
fn mooncode_push_compacted_thinking_rows(
  items : Array[MoonCodeTranscriptItem],
  rows : Array[MoonCodeActivityRow],
) -> Unit {
  if rows.length() == 0 {
    return
  }
  items.push(
    mooncode_transcript_activity_item(mooncode_compact_thinking_rows(rows)),
  )
}

///|
fn mooncode_compact_thinking_rows(
  rows : Array[MoonCodeActivityRow],
) -> MoonCodeActivityRow {
  {
    tone: "thinking",
    label: "Progress",
    title: mooncode_compact_thinking_title(rows),
    detail: mooncode_compact_thinking_detail(rows),
    status: mooncode_compact_thinking_status(rows),
    folded: true,
  }
}

///|
fn mooncode_compact_thinking_title(rows : Array[MoonCodeActivityRow]) -> String {
  if rows.length() == 1 &&
    (rows[0].title == "Prompt queued" || rows[0].title == "Starting request") {
    "Request sent"
  } else if mooncode_compact_thinking_status(rows) == "failed" {
    "Work interrupted"
  } else {
    "Prepared the response"
  }
}

///|
fn mooncode_compact_thinking_detail(
  rows : Array[MoonCodeActivityRow],
) -> String {
  let lines : Array[String] = []
  for row in rows {
    let line = mooncode_user_facing_thinking_detail(row)
    if line != "" && !lines.contains(line) {
      lines.push(line)
    }
  }
  if lines.length() == 0 {
    "Prepared the response."
  } else {
    lines.join("\n")
  }
}

///|
fn mooncode_user_facing_thinking_detail(row : MoonCodeActivityRow) -> String {
  let title = row.title.trim().to_owned()
  let detail = row.detail.trim().to_owned()
  if title == "Prompt queued" || title == "Starting request" {
    return "Started the request."
  }
  if title == "Planning next step" ||
    title == "Choosing next action" ||
    title == "Reviewing the request" {
    return "Reviewed the request."
  }
  if title == "Selected next action" || title == "Choosing what to do next" {
    return "Chose what to do next."
  }
  if title == "Thinking" ||
    title == "Model reasoning" ||
    title == "Working through the request" {
    if detail == "" {
      return "Thought through the request."
    }
    return detail
  }
  if detail.contains("asking model") {
    return "Reviewed the request."
  }
  if detail.contains("model-tool-calls") ||
    (detail.contains("selected") && detail.contains("tool call")) {
    return "Chose what to do next."
  }
  if detail != "" {
    detail
  } else if title != "" {
    title
  } else {
    "Prepared the response."
  }
}

///|
fn mooncode_compact_thinking_status(
  rows : Array[MoonCodeActivityRow],
) -> String {
  for row in rows {
    if row.status == "failed" {
      return "failed"
    }
  }
  "done"
}

///|
fn mooncode_activity_row_is_folded_thinking(row : MoonCodeActivityRow) -> Bool {
  row.folded &&
  row.status != "running" &&
  (row.tone == "thinking" || row.label == "Thinking" || row.label == "Working")
}

///|
fn mooncode_transcript_item_is_thinking_activity(
  item : MoonCodeTranscriptItem,
) -> Bool {
  match item.activity {
    Some(row) => row.tone == "thinking" || row.label == "Thinking"
    None => false
  }
}

///|
fn mooncode_transcript_has_assistant_after_before_user(
  items : Array[MoonCodeTranscriptItem],
  index : Int,
) -> Bool {
  let mut cursor = index + 1
  while cursor < items.length() {
    match items[cursor].message {
      Some(row) => {
        if row.role == "assistant" {
          return true
        }
        if row.role == "user" {
          return false
        }
      }
      None => ()
    }
    cursor = cursor + 1
  }
  false
}

///|
fn render_mooncode_transcript_row(row : MoonCodeTranscriptRow) -> @rabbita.Html {
  div(
    class="mooncode-message " + row.role + " " + row.status,
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-message")
      .data_set("role", row.role)
      .data_set("status", row.status),
    [pre(class="mooncode-message-body", row.content)],
  )
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
  mooncode_note_diagnostic_event_fields(event)
  (event.lane == "transcript" && event.kind == "user") ||
  event.command == "prompt" ||
  event.command == "steer" ||
  event.kind == "command.prompt" ||
  event.kind == "command.steer" ||
  event.title == "User prompt"
}

///|
fn mooncode_note_diagnostic_event_fields(event : MoonCodeEvent) -> Unit {
  ignore(event.command_id)
  ignore(event.status)
  ignore(event.created_at)
  ignore(event.path)
  ignore(event.exit_code)
  ignore(event.tool)
  ignore(event.tool_name)
  ignore(event.tool_result)
}
