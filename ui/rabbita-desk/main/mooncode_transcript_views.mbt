///|
struct MoonCodeTranscriptRow {
  role : String
  content : String
  status : String
  command_id : String
  client_turn_id : String
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
  // Hard architecture gate: the visible chat transcript is canonical
  // conversation plus unacknowledged optimistic rows. Raw stream/runtime events
  // stay diagnostic and must not become an alternate transcript source here.
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
fn render_mooncode_transcript_row(row : MoonCodeTranscriptRow) -> @rabbita.Html {
  div(
    class="mooncode-message " + row.role + " " + row.status,
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-message")
      .data_set("role", row.role)
      .data_set("status", row.status)
      .data_set("command-id", row.command_id)
      .data_set("client-turn-id", row.client_turn_id),
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
