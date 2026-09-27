///|
struct MoonCodeTranscriptRow {
  item_id : String
  role : String
  content : String
  content_parts : Array[Json]
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
  dispatch : Dispatch[Msg],
  model : Model,
  session : MoonCodeSession,
) -> @rabbita.Html {
  let items = mooncode_transcript_items(model, session)
  if items.length() == 0 {
    div(class="mooncode-empty", [
      h1(mooncode_empty_transcript_title(session)),
      p(class="lead", mooncode_empty_transcript_message(session)),
    ])
  } else {
    let children : Array[@rabbita.Html] = []
    for item in items {
      match item.message {
        Some(row) =>
          children.push(
            render_mooncode_transcript_row(dispatch, model, session.id, row),
          )
        None =>
          match item.activity {
            Some(row) =>
              children.push(render_mooncode_activity_row(dispatch, model, row))
            None => ()
          }
      }
    }
    div(class="mooncode-transcript-list mooncode-transcript", children)
  }
}

///|
fn mooncode_empty_transcript_title(session : MoonCodeSession) -> String {
  if session.status == "failed" {
    "No coding result yet"
  } else if session.status == "queued" || session.queued_count > 0 {
    "Request saved"
  } else if session.status == "running" {
    "MoonCode is working"
  } else {
    session.title
  }
}

///|
fn mooncode_empty_transcript_message(session : MoonCodeSession) -> String {
  if session.status == "failed" {
    "Resolve the issue above, then send the request again."
  } else if session.status == "queued" || session.queued_count > 0 {
    "The conversation will appear here when the worker begins."
  } else if session.status == "running" {
    "The first verified update will appear here."
  } else {
    "Start a MoonCode prompt to begin the conversation."
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
  { message: Some(row), activity: None, }
}

///|
fn mooncode_transcript_activity_item(
  row : MoonCodeActivityRow,
) -> MoonCodeTranscriptItem {
  { message: None, activity: Some(row), }
}

///|
fn render_mooncode_transcript_row(
  dispatch : Dispatch[Msg],
  model : Model,
  session_id : String,
  row : MoonCodeTranscriptRow,
) -> @rabbita.Html {
  let message_id = if row.item_id == "" {
    @desk.stable_id("mooncode-message", row.client_turn_id + ":" + row.content)
  } else {
    row.item_id
  }
  let body = if row.role == "assistant" {
    div(
      class="mooncode-message-body mooncode-markdown",
      mooncode_markdown_nodes(
        dispatch,
        model.mooncode_copied_item_id,
        row.content,
      ),
    )
  } else if row.role == "user" && !row.content_parts.is_empty() {
    render_mooncode_ordered_user_content(
      session_id,
      row.command_id,
      row.content_parts,
    )
  } else {
    pre(class="mooncode-message-body", row.content)
  }
  div(
    class="mooncode-message " + row.role + " " + row.status,
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-message")
      .data_set("role", row.role)
      .data_set("status", row.status)
      .data_set("command-id", row.command_id)
      .data_set("client-turn-id", row.client_turn_id),
    [
      body,
      if row.role == "assistant" {
        div(class="mooncode-message-actions", [
          button(
            class="mooncode-inline-action",
            attrs=@html.Attrs::build()
              .aria_label(
                if model.mooncode_copied_item_id == message_id {
                  "Copied answer"
                } else {
                  "Copy answer"
                },
              )
              .data_set(
                "i18n-aria-label",
                if model.mooncode_copied_item_id == message_id {
                  "code.copied_answer_aria"
                } else {
                  "code.copy_answer_aria"
                },
              )
              .data_set(
                "i18n",
                if model.mooncode_copied_item_id == message_id {
                  "code.copied_answer"
                } else {
                  "code.copy_answer"
                },
              )
              .data_set("testid", "mooncode-copy-answer"),
            on_click=dispatch(CopyMoonCodeText(message_id, row.content)),
            if model.mooncode_copied_item_id == message_id {
              "Copied"
            } else {
              "Copy"
            },
          ),
          button(
            class="mooncode-inline-action",
            attrs=@html.Attrs::build()
              .data_set("mooncode-compare-from", "true")
              .aria_label("Try another implementation approach from here")
              .data_set("i18n-aria-label", "code.try_another_approach_aria")
              .data_set("i18n", "code.try_another_approach"),
            "Try another approach",
          ),
        ])
      } else {
        @html.nothing
      },
    ],
  )
}

///|
fn mooncode_transcript_part_string(part : Json, key : String) -> String {
  match part {
    Object(fields) =>
      match fields.get(key) {
        Some(String(value)) => value
        _ => ""
      }
    _ => ""
  }
}

///|
fn render_mooncode_ordered_user_content(
  session_id : String,
  command_id : String,
  parts : Array[Json],
) -> @rabbita.Html {
  let children : Array[@rabbita.Html] = []
  for part in parts {
    match mooncode_transcript_part_string(part, "type") {
      "text" =>
        children.push(
          pre(
            class="mooncode-message-text-part",
            mooncode_transcript_part_string(part, "text"),
          ),
        )
      "image" => {
        let media_type = mooncode_transcript_part_string(part, "media_type")
        let index = match part {
          Object(fields) =>
            match fields.get("image_index") {
              Some(Number(value, ..)) => value.to_int()
              _ => -1
            }
          _ => -1
        }
        let name = mooncode_transcript_part_string(part, "name")
        if ["image/png", "image/jpeg", "image/webp"].contains(media_type) &&
          mooncode_media_path_safe(session_id) &&
          mooncode_media_path_safe(command_id) &&
          index >= 0 &&
          index < 12 {
          children.push(
            img(
              src="/api/mooncode/sessions/\{session_id}/media/\{command_id}/\{index}",
              alt=if name == "" { "Attached image" } else { name },
              attrs=@html.Attrs::build().data_set(
                "testid", "mooncode-user-image",
              ),
            ),
          )
        }
      }
      _ => ()
    }
  }
  div(class="mooncode-message-body mooncode-ordered-content", children)
}

///|
fn mooncode_media_path_safe(value : String) -> Bool {
  if value == "" || value.length() > 160 {
    return false
  }
  for ch in value {
    if !((ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' ||
      ch == '_' ||
      ch == '.' ||
      ch == '~') {
      return false
    }
  }
  true
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
