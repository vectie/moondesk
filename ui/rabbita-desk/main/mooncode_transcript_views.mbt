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
  let events = mooncode_transcript_events(model, session)
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
      return mooncode_drop_leading_activity_items(items)
    }
  }
  let items : Array[MoonCodeTranscriptItem] = []
  for row in mooncode_transcript_rows(model, session) {
    items.push(mooncode_transcript_message_item(row))
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
    } else if mooncode_event_is_assistant_delta(event) {
      let content = event.detail.trim().to_owned()
      if content != "" && has_user {
        if running_assistant_index >= 0 {
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
      let content = mooncode_event_assistant_content(event)
      if content != "" && has_user {
        if running_assistant_index >= 0 {
          mooncode_replace_transcript_message_item(
            items,
            running_assistant_index,
            "assistant",
            content,
            if event.status == "" { "done" } else { event.status },
          )
          running_assistant_index = -1
        } else {
          mooncode_push_transcript_message_item(items, {
            role: "assistant",
            content,
            status: if event.status == "" { "done" } else { event.status },
          })
        }
      }
    } else {
      match mooncode_activity_row_from_event(event) {
        Some(row) => {
          let key = mooncode_activity_item_key(row)
          if !pushed_activity.contains(key) {
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
fn mooncode_activity_item_key(row : MoonCodeActivityRow) -> String {
  "\{row.label}\n\{row.title}\n\{row.detail}\n\{row.status}"
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
      mooncode_push_transcript_message_item(items, {
        role: "assistant",
        content: "Working on it...",
        status: "running",
      })
    }
  } else {
    items.insert(insertion, item)
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
  let events = mooncode_transcript_events(model, session)
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
  } else if mooncode_session_is_active(session) {
    mooncode_push_transcript_row(rows, [], {
      role: "assistant",
      content: "Working on it...",
      status: "running",
    })
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
