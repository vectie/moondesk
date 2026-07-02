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
        None => {
          match item.activity {
            Some(row) => children.push(render_mooncode_activity_row(row))
            None => ()
          }
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
  let events = mooncode_order_transcript_item_events(
    mooncode_transcript_events(model, session),
  )
  if events.length() > 0 {
    let items = match mooncode_first_pending_prompt_for_session(
      model,
      session.id,
    ) {
      Some(prompt) => mooncode_transcript_items_with_pending_prompt(
        model,
        session,
        events,
        prompt,
      )
      None => {
        let items = mooncode_transcript_items_from_events(session.id, events)
        mooncode_merge_local_transcript_items(
          items,
          model,
          session,
          has_following_work=false,
        )
        items
      }
    }
    if items.length() > 0 {
      return mooncode_fold_resolved_thinking_items(
        mooncode_drop_leading_activity_items(items),
      )
    }
  }
  let items : Array[MoonCodeTranscriptItem] = []
  for row in mooncode_transcript_rows(model, session) {
    items.push(mooncode_transcript_message_item(row))
  }
  if mooncode_session_has_pending_prompt(model, session.id) &&
    !mooncode_transcript_items_have_assistant_after_last_user(items) {
    mooncode_push_pending_activity_item(items)
  }
  items
}

///|
fn mooncode_transcript_items_from_events(
  session_id : String,
  events : Array[MoonCodeEvent],
) -> Array[MoonCodeTranscriptItem] {
  mooncode_transcript_items_from_events_with_user(
    session_id,
    events,
    initial_has_user=false,
  )
}

///|
fn mooncode_transcript_items_from_events_with_user(
  session_id : String,
  events : Array[MoonCodeEvent],
  initial_has_user~ : Bool,
) -> Array[MoonCodeTranscriptItem] {
  let items : Array[MoonCodeTranscriptItem] = []
  let pushed_activity : Array[String] = []
  let pending_assistant_finals : Array[MoonCodeTranscriptRow] = []
  let mut running_assistant_index = -1
  let mut has_user = initial_has_user
  for event in events {
    if mooncode_event_is_user_prompt(event) {
      mooncode_push_transcript_message_item(items, {
        role: "user",
        content: event.detail,
        status: event.status,
      })
      has_user = true
      running_assistant_index = -1
      for row in pending_assistant_finals {
        mooncode_push_transcript_message_item(items, row)
      }
      pending_assistant_finals.clear()
    } else if mooncode_event_is_assistant_delta(event) {
      let content = event.detail.trim().to_owned()
      if content != "" && has_user {
        if mooncode_transcript_running_assistant_is_tail(
          items,
          running_assistant_index,
        ) {
          mooncode_replace_transcript_message_item(
            items,
            running_assistant_index,
            "assistant",
            mooncode_transcript_item_message_content(
              items,
              running_assistant_index,
            ) + content,
            "running",
          )
        } else {
          running_assistant_index = items.length()
          mooncode_push_transcript_message_item(items, {
            role: "assistant",
            content,
            status: "running",
          })
        }
      }
    } else if mooncode_event_is_assistant_final(event) {
      let raw_content = mooncode_event_assistant_content(event)
      let content = if has_user &&
        !mooncode_transcript_running_assistant_is_tail(
          items,
          running_assistant_index,
        ) {
        mooncode_dedupe_assistant_final_content(items, raw_content)
      } else {
        raw_content
      }
      if content != "" {
        let status = if event.status == "" { "done" } else { event.status }
        if has_user {
          if mooncode_transcript_running_assistant_is_tail(
            items,
            running_assistant_index,
          ) {
            mooncode_replace_transcript_message_item(
              items,
              running_assistant_index,
              "assistant",
              content,
              status,
            )
            running_assistant_index = -1
          } else {
            mooncode_push_transcript_message_item(items, {
              role: "assistant",
              content,
              status,
            })
          }
        } else {
          pending_assistant_finals.push({ role: "assistant", content, status })
        }
      }
    } else {
      match mooncode_activity_row_from_event(event) {
        Some(row) => {
          let key = mooncode_activity_item_key(event, row)
          if !pushed_activity.contains(key) {
            if mooncode_transcript_running_assistant_is_tail(
              items,
              running_assistant_index,
            ) {
              mooncode_mark_transcript_message_item_done(
                items,
                running_assistant_index,
              )
              running_assistant_index = -1
            }
            pushed_activity.push(key)
            items.push(mooncode_transcript_activity_item(row))
          }
        }
        None => ()
      }
      if mooncode_event_is_terminal_without_answer(event) &&
        running_assistant_index >= 0 {
        mooncode_mark_transcript_message_item_done(
          items,
          running_assistant_index,
        )
        running_assistant_index = -1
      }
    }
  }
  if items.length() == 0 && session_id != "" {
    return []
  }
  items
}

///|
fn mooncode_dedupe_assistant_final_content(
  items : Array[MoonCodeTranscriptItem],
  content : String,
) -> String {
  let normalized = content.trim().to_owned()
  if normalized == "" {
    return ""
  }
  let mut index = items.length()
  while index > 0 {
    index = index - 1
    match items[index].message {
      Some(row) => {
        if row.role == "user" {
          return normalized
        }
        if row.role == "assistant" {
          let prior = row.content.trim().to_owned()
          if prior == normalized {
            return ""
          }
          if prior != "" && normalized.has_prefix(prior) {
            return normalized[prior.length():].trim().to_owned()
          }
        }
      }
      None => ()
    }
  }
  normalized
}

///|
fn mooncode_transcript_running_assistant_is_tail(
  items : Array[MoonCodeTranscriptItem],
  index : Int,
) -> Bool {
  index >= 0 && index == items.length() - 1
}

///|
fn mooncode_transcript_items_with_pending_prompt(
  model : Model,
  session : MoonCodeSession,
  events : Array[MoonCodeEvent],
  prompt : MoonCodePendingPrompt,
) -> Array[MoonCodeTranscriptItem] {
  let split = mooncode_clamp_count(prompt.after_event_count, events.length())
  let before : Array[MoonCodeEvent] = []
  let after : Array[MoonCodeEvent] = []
  for index in 0..<events.length() {
    if index < split {
      before.push(events[index])
    } else {
      after.push(events[index])
    }
  }
  let items = mooncode_transcript_items_from_events(session.id, before)
  mooncode_merge_local_transcript_items(
    items,
    model,
    session,
    has_following_work=after.length() > 0,
  )
  let tail = mooncode_transcript_items_from_events_with_user(
    session.id,
    after,
    initial_has_user=true,
  )
  for item in mooncode_drop_leading_activity_items(tail) {
    items.push(item)
  }
  items
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
fn mooncode_push_transcript_message_item(
  items : Array[MoonCodeTranscriptItem],
  row : MoonCodeTranscriptRow,
) -> Unit {
  let content = row.content.trim().to_owned()
  if content == "" {
    return
  }
  let role = mooncode_transcript_message_role(row.role)
  if mooncode_transcript_last_message_item_matches(items, role, content) {
    return
  }
  items.push(mooncode_transcript_message_item({ ..row, role, content }))
}

///|
fn mooncode_transcript_last_message_item_matches(
  items : Array[MoonCodeTranscriptItem],
  role : String,
  content : String,
) -> Bool {
  if items.length() == 0 {
    return false
  }
  match items[items.length() - 1].message {
    Some(row) => row.role == role && row.content == content
    None => false
  }
}

///|
fn mooncode_replace_transcript_message_item(
  items : Array[MoonCodeTranscriptItem],
  index : Int,
  role : String,
  content : String,
  status : String,
) -> Unit {
  if index < 0 || index >= items.length() {
    return
  }
  items[index] = mooncode_transcript_message_item({ role, content, status })
}

///|
fn mooncode_mark_transcript_message_item_done(
  items : Array[MoonCodeTranscriptItem],
  index : Int,
) -> Unit {
  if index < 0 || index >= items.length() {
    return
  }
  match items[index].message {
    Some(row) => {
      items[index] = mooncode_transcript_message_item({ ..row, status: "done" })
    }
    None => ()
  }
}

///|
fn mooncode_transcript_item_message_content(
  items : Array[MoonCodeTranscriptItem],
  index : Int,
) -> String {
  if index < 0 || index >= items.length() {
    return ""
  }
  match items[index].message {
    Some(row) => row.content
    None => ""
  }
}

///|
fn mooncode_activity_item_key(
  event : MoonCodeEvent,
  row : MoonCodeActivityRow,
) -> String {
  "\{mooncode_event_order_key(event)}\n\{row.label}\n\{row.title}\n\{row.detail}\n\{row.status}"
}

///|
fn mooncode_merge_local_transcript_items(
  items : Array[MoonCodeTranscriptItem],
  model : Model,
  session : MoonCodeSession,
  has_following_work~ : Bool,
) -> Unit {
  for row in model.mooncode_conversation_rows {
    if row.session_id != session.id {
      continue
    }
    let role = mooncode_transcript_message_role(row.role)
    let content = row.content.trim().to_owned()
    if content == "" ||
      mooncode_transcript_items_have_message(items, role, content) {
      continue
    }
    if role == "user" &&
      mooncode_local_row_is_pending_prompt(model, session.id, content) {
      mooncode_insert_pending_prompt_item(items, {
        role,
        content,
        status: row.status,
      }, model, session.id, has_following_work=has_following_work)
    } else {
      mooncode_push_transcript_message_item(items, {
        role,
        content,
        status: row.status,
      })
    }
  }
  for prompt in model.mooncode_pending_prompts {
    if prompt.session_id != session.id ||
      mooncode_transcript_items_have_message(items, "user", prompt.content) {
      continue
    }
    mooncode_insert_pending_prompt_item(items, {
      role: "user",
      content: prompt.content,
      status: prompt.status,
    }, model, session.id, has_following_work=has_following_work)
  }
}

///|
fn mooncode_insert_pending_prompt_item(
  items : Array[MoonCodeTranscriptItem],
  row : MoonCodeTranscriptRow,
  model : Model,
  session_id : String,
  has_following_work~ : Bool,
) -> Unit {
  let insertion = mooncode_pending_prompt_item_index(
    model,
    session_id,
    row.content,
    items.length(),
  )
  let item = mooncode_transcript_message_item({
    ..row,
    role: mooncode_transcript_message_role(row.role),
    content: row.content.trim().to_owned(),
  })
  if insertion >= items.length() {
    items.push(item)
    if !has_following_work {
      mooncode_push_pending_activity_item(items)
    }
  } else {
    items.insert(insertion, item)
  }
}

///|
fn mooncode_push_pending_activity_item(
  items : Array[MoonCodeTranscriptItem],
) -> Unit {
  if mooncode_transcript_last_activity_item_matches(
    items,
    "Thinking",
    "Prompt queued",
  ) {
    return
  }
  items.push(mooncode_transcript_activity_item({
    tone: "thinking",
    label: "Thinking",
    title: "Prompt queued",
    detail: "Waiting for MoonClaw to stream runtime events.",
    status: "running",
    folded: true,
  }))
}

///|
fn mooncode_transcript_last_activity_item_matches(
  items : Array[MoonCodeTranscriptItem],
  label : String,
  title : String,
) -> Bool {
  if items.length() == 0 {
    return false
  }
  match items[items.length() - 1].activity {
    Some(row) => row.label == label && row.title == title
    None => false
  }
}

///|
fn mooncode_transcript_items_have_message(
  items : Array[MoonCodeTranscriptItem],
  role : String,
  content : String,
) -> Bool {
  for item in items {
    match item.message {
      Some(row) if row.role == role && row.content == content => return true
      _ => ()
    }
  }
  false
}

///|
fn mooncode_local_row_is_pending_prompt(
  model : Model,
  session_id : String,
  content : String,
) -> Bool {
  for prompt in model.mooncode_pending_prompts {
    if prompt.session_id == session_id && prompt.content == content {
      return true
    }
  }
  false
}

///|
fn mooncode_pending_prompt_item_index(
  model : Model,
  session_id : String,
  content : String,
  fallback : Int,
) -> Int {
  for prompt in model.mooncode_pending_prompts {
    if prompt.session_id == session_id && prompt.content == content {
      return mooncode_clamp_count(prompt.after_row_count, fallback)
    }
  }
  fallback
}

///|
fn mooncode_first_pending_prompt_for_session(
  model : Model,
  session_id : String,
) -> MoonCodePendingPrompt? {
  for prompt in model.mooncode_pending_prompts {
    if prompt.session_id == session_id {
      return Some(prompt)
    }
  }
  None
}

///|
fn mooncode_clamp_count(value : Int, limit : Int) -> Int {
  if value < 0 {
    0
  } else if value > limit {
    limit
  } else {
    value
  }
}

///|
fn mooncode_drop_leading_activity_items(
  items : Array[MoonCodeTranscriptItem],
) -> Array[MoonCodeTranscriptItem] {
  let rest : Array[MoonCodeTranscriptItem] = []
  let mut index = 0
  let mut still_leading = true
  while index < items.length() {
    let item = items[index]
    if still_leading && mooncode_transcript_item_is_activity(item) {
      ()
    } else {
      still_leading = false
      rest.push(item)
    }
    index = index + 1
  }
  if rest.length() == items.length() || !mooncode_transcript_items_have_user(rest) {
    return items
  }
  rest
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
        Some(row) => rest.push(mooncode_transcript_activity_item(
          mooncode_fold_resolved_thinking_row(row),
        ))
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
  { ..row, folded: true, status: if row.status == "running" { "done" } else { row.status } }
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
fn mooncode_transcript_item_is_activity(item : MoonCodeTranscriptItem) -> Bool {
  item.activity is Some(_)
}

///|
fn mooncode_transcript_item_is_user_message(
  item : MoonCodeTranscriptItem,
) -> Bool {
  match item.message {
    Some(row) => row.role == "user"
    None => false
  }
}

///|
fn mooncode_transcript_items_have_user(
  items : Array[MoonCodeTranscriptItem],
) -> Bool {
  for item in items {
    if mooncode_transcript_item_is_user_message(item) {
      return true
    }
  }
  false
}

///|
fn mooncode_transcript_items_have_assistant_after_last_user(
  items : Array[MoonCodeTranscriptItem],
) -> Bool {
  let mut seen_user = false
  let mut seen_assistant = false
  for item in items {
    match item.message {
      Some(row) => {
        if row.role == "user" {
          seen_user = true
          seen_assistant = false
        } else if row.role == "assistant" && seen_user {
          seen_assistant = true
        }
      }
      None => ()
    }
  }
  seen_assistant
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
  if !mooncode_events_have_command_links(events) {
    return events
  }
  let ordered : Array[MoonCodeEvent] = []
  let used_keys : Array[String] = []
  for event in events {
    if mooncode_event_is_user_prompt(event) {
      mooncode_push_ordered_transcript_event(ordered, used_keys, event)
      let command_id = mooncode_event_command_id(event)
      if command_id != "" {
        for linked in events {
          if !mooncode_event_is_user_prompt(linked) &&
            mooncode_event_command_id(linked) == command_id {
            mooncode_push_ordered_transcript_event(
              ordered, used_keys, linked,
            )
          }
        }
      }
    }
  }
  for event in events {
    mooncode_push_ordered_transcript_event(ordered, used_keys, event)
  }
  ordered
}

///|
fn mooncode_order_transcript_item_events(
  events : Array[MoonCodeEvent],
) -> Array[MoonCodeEvent] {
  if !mooncode_events_have_command_links(events) {
    return events
  }
  let ordered : Array[MoonCodeEvent] = []
  let used_keys : Array[String] = []
  for event in events {
    if mooncode_event_is_user_prompt(event) {
      mooncode_push_ordered_transcript_event(ordered, used_keys, event)
      let command_id = mooncode_event_command_id(event)
      if command_id != "" {
        for linked in events {
          if !mooncode_event_is_user_prompt(linked) &&
            !mooncode_event_is_assistant_message(linked) &&
            mooncode_event_command_id(linked) == command_id {
            mooncode_push_ordered_transcript_event(
              ordered, used_keys, linked,
            )
          }
        }
        for linked in events {
          if !mooncode_event_is_user_prompt(linked) &&
            mooncode_event_is_assistant_message(linked) &&
            mooncode_event_command_id(linked) == command_id {
            mooncode_push_ordered_transcript_event(
              ordered, used_keys, linked,
            )
          }
        }
      }
    }
  }
  for event in events {
    mooncode_push_ordered_transcript_event(ordered, used_keys, event)
  }
  ordered
}

///|
fn mooncode_event_is_assistant_message(event : MoonCodeEvent) -> Bool {
  mooncode_event_is_assistant_delta(event) ||
  mooncode_event_is_assistant_final(event)
}

///|
fn mooncode_events_have_command_links(events : Array[MoonCodeEvent]) -> Bool {
  let prompt_command_ids : Array[String] = []
  for event in events {
    if mooncode_event_is_user_prompt(event) {
      let command_id = mooncode_event_command_id(event)
      if command_id != "" {
        prompt_command_ids.push(command_id)
      }
    }
  }
  if prompt_command_ids.length() == 0 {
    return false
  }
  for event in events {
    if mooncode_event_is_user_prompt(event) {
      continue
    }
    let command_id = mooncode_event_command_id(event)
    if command_id != "" && prompt_command_ids.contains(command_id) {
      return true
    }
  }
  false
}

///|
fn mooncode_push_ordered_transcript_event(
  ordered : Array[MoonCodeEvent],
  used_keys : Array[String],
  event : MoonCodeEvent,
) -> Unit {
  let key = mooncode_event_order_key(event)
  if used_keys.contains(key) {
    return
  }
  used_keys.push(key)
  ordered.push(event)
}

///|
fn mooncode_event_order_key(event : MoonCodeEvent) -> String {
  if event.id != "" {
    event.id
  } else {
    "\{event.kind}:\{event.created_at}:\{event.detail}"
  }
}

///|
fn mooncode_event_command_id(event : MoonCodeEvent) -> String {
  match event.command_id {
    Some(command_id) if command_id != "" => return command_id
    _ => ()
  }
  match event.command_packet {
    Some(packet) => {
      let command_id = json_string_value(packet, "command_id", default="")
      if command_id != "" {
        return command_id
      }
    }
    None => ()
  }
  if event.kind == "command.prompt" && event.id.contains("mooncode-command-") {
    return event.id
  }
  let parts = event.id.split("mooncode-command-").to_array()
  if parts.length() < 2 {
    return ""
  }
  let suffix = parts[1]
  let suffix_parts = suffix.split("-").to_array()
  if suffix_parts.length() == 0 || suffix_parts[0] == "" {
    ""
  } else {
    "mooncode-command-" + suffix_parts[0].to_owned()
  }
}

///|
fn mooncode_transcript_rows(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptRow] {
  let events = mooncode_transcript_events(model, session)
  if events.length() > 0 {
    let seed_rows = if mooncode_events_have_user(events) {
      []
    } else {
      mooncode_pending_conversation_seed_rows(model, session.id)
    }
    let event_conversation = mooncode_hydrate_conversation_from_events(
      seed_rows,
      session.id,
      events,
    )
    let event_rows = mooncode_conversation_rows_to_transcript(
      event_conversation,
      session.id,
    )
    if event_rows.length() > 0 {
      mooncode_append_session_transcript_tail(event_rows, session)
      mooncode_complete_event_transcript_rows(event_rows, model, session, events)
      return event_rows
    }
  }
  let conversation_rows = mooncode_conversation_transcript_rows(model, session)
  if conversation_rows.length() > 0 {
    return conversation_rows
  }
  let session_rows = mooncode_session_transcript_rows(session)
  if session_rows.length() > 0 {
    return session_rows
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
  return pending_rows
}

///|
fn mooncode_pending_conversation_seed_rows(
  model : Model,
  session_id : String,
) -> Array[MoonCodeConversationRow] {
  let rows : Array[MoonCodeConversationRow] = []
  for prompt in model.mooncode_pending_prompts {
    if prompt.session_id == session_id {
      mooncode_push_conversation_row(
        rows,
        session_id,
        "user",
        prompt.content,
        prompt.status,
        mooncode_pending_prompt_key(prompt),
        dedupe_content=false,
      )
    }
  }
  rows
}

///|
fn mooncode_events_have_user(events : Array[MoonCodeEvent]) -> Bool {
  for event in events {
    if mooncode_event_is_user_prompt(event) {
      return true
    }
  }
  false
}

///|
fn mooncode_complete_event_transcript_rows(
  rows : Array[MoonCodeTranscriptRow],
  model : Model,
  session : MoonCodeSession,
  events : Array[MoonCodeEvent],
) -> Unit {
  ignore(session)
  if rows.length() == 0 || mooncode_transcript_last_row_is_assistant(rows) {
    return
  }
  match mooncode_event_failure_reply(events) {
    Some(message) => {
      mooncode_push_transcript_row(rows, [], {
        role: "assistant",
        content: message,
        status: "failed",
      })
      return
    }
    None => ()
  }
  if mooncode_events_have_terminal_without_answer(events) {
    if model.mooncode_model == "" {
      mooncode_push_transcript_row(rows, [], {
        role: "assistant",
        content: "No AI model is configured for MoonCode yet.",
        status: "failed",
      })
    }
  }
}

///|
fn mooncode_events_have_terminal_without_answer(
  events : Array[MoonCodeEvent],
) -> Bool {
  for event in events {
    if mooncode_event_is_terminal_without_answer(event) {
      return true
    }
  }
  false
}

///|
fn mooncode_event_failure_reply(events : Array[MoonCodeEvent]) -> String? {
  for event in events {
    if event.status == "failed" &&
      (
        event.kind == "runtime.planner_failed" ||
        event.kind == "command_error" ||
        event.kind == "turn_failed" ||
        event.kind == "max_steps_exhausted"
      ) {
      let content = event.detail.trim().to_owned()
      if content != "" {
        return Some(content)
      }
    }
  }
  None
}

///|
fn mooncode_session_transcript_rows(
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptRow] {
  let normalized : Array[MoonCodeTranscriptRow] = []
  for row in session.transcript {
    let role = mooncode_transcript_message_role(row.role)
    if role == "user" || role == "assistant" {
      mooncode_push_transcript_row(normalized, [], {
        role,
        content: row.content,
        status: row.status,
      })
    }
  }
  if normalized.length() == 0 {
    return normalized
  }
  if mooncode_transcript_item_order_is_assistant_first(normalized) {
    return mooncode_repair_assistant_first_transcript_rows(normalized)
  }
  normalized
}

///|
fn mooncode_transcript_item_order_is_assistant_first(
  rows : Array[MoonCodeTranscriptRow],
) -> Bool {
  for row in rows {
    if row.role == "assistant" {
      return true
    } else if row.role == "user" {
      return false
    }
  }
  false
}

///|
fn mooncode_repair_assistant_first_transcript_rows(
  rows : Array[MoonCodeTranscriptRow],
) -> Array[MoonCodeTranscriptRow] {
  let users : Array[MoonCodeTranscriptRow] = []
  let assistants : Array[MoonCodeTranscriptRow] = []
  for row in rows {
    if row.role == "user" {
      users.push(row)
    } else if row.role == "assistant" {
      assistants.push(row)
    }
  }
  if users.length() == 0 {
    return rows
  }
  let repaired : Array[MoonCodeTranscriptRow] = []
  for index in 0..<users.length() {
    repaired.push(users[index])
    let assistant_index = assistants.length() - 1 - index
    if assistant_index >= 0 && assistant_index < assistants.length() {
      repaired.push(assistants[assistant_index])
    }
  }
  repaired
}

///|
fn mooncode_append_session_transcript_tail(
  rows : Array[MoonCodeTranscriptRow],
  session : MoonCodeSession,
) -> Unit {
  let raw_rows = mooncode_session_transcript_rows(session)
  for row in raw_rows {
    if row.role == "assistant" &&
      !mooncode_transcript_rows_have_message(rows, row.role, row.content) {
      mooncode_push_transcript_row(rows, [], row)
    }
  }
}

///|
fn mooncode_transcript_rows_have_message(
  rows : Array[MoonCodeTranscriptRow],
  role : String,
  content : String,
) -> Bool {
  for row in rows {
    if row.role == role && row.content == content {
      return true
    }
  }
  false
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
