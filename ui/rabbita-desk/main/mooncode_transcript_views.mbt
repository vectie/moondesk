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
  if mooncode_transcript_waiting_for_runtime_events(model, session) {
    return render_mooncode_transcript_loading(session)
  }
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
fn render_mooncode_transcript_loading(
  session : MoonCodeSession,
) -> @rabbita.Html {
  div(class="mooncode-empty loading", [
    h1(session.title),
    p(class="lead", "Loading conversation..."),
  ])
}

///|
fn mooncode_transcript_waiting_for_runtime_events(
  model : Model,
  session : MoonCodeSession,
) -> Bool {
  model.selected_mooncode_session_id == session.id &&
  model.mooncode_runtime_event_sink_status == "loading runtime events" &&
  mooncode_transcript_events(model, session).length() == 0 &&
  !(model.mooncode_runtime_event_sink_session_id == session.id &&
  model.mooncode_runtime_event_sink is Some(_)) &&
  !mooncode_session_has_pending_prompt(model, session.id) &&
  !mooncode_conversation_has_session(model.mooncode_conversation_rows, session.id)
}

///|
fn mooncode_transcript_items(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptItem] {
  let canonical_items = mooncode_canonical_transcript_items(model, session)
  if canonical_items.length() > 0 {
    return canonical_items
  }
  mooncode_legacy_transcript_items(model, session)
}

///|
fn mooncode_legacy_transcript_items(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptItem] {
  let events = mooncode_order_transcript_item_events(
    mooncode_transcript_events(model, session),
  )
  if events.length() > 0 {
    let items = match
      mooncode_first_pending_prompt_for_session(model, session.id) {
      Some(prompt) =>
        if mooncode_transcript_events_have_acknowledged_message(
            events,
            "user",
            prompt.content,
          ) {
          mooncode_transcript_items_with_acknowledged_pending_prompt(
            model, session, events, prompt,
          )
        } else {
          mooncode_transcript_items_with_pending_prompt(
            model, session, events, prompt,
          )
        }
      None => {
        let items = mooncode_transcript_items_from_events(session.id, events)
        mooncode_merge_local_transcript_items_with_events(
          items, model, session, events,
        )
        items
      }
    }
    if items.length() > 0 {
      let items = mooncode_drop_duplicated_user_prompt_prefix(items)
      return mooncode_drop_recovered_failed_assistant_items(
        mooncode_drop_recovered_failed_thinking_items(
          mooncode_compact_folded_thinking_items(
            mooncode_fold_resolved_thinking_items(
              mooncode_repair_grouped_user_prefix_items(
                mooncode_drop_leading_activity_items(items),
              ),
            ),
          ),
        ),
      )
    }
  }
  let items : Array[MoonCodeTranscriptItem] = []
  for row in mooncode_transcript_rows(model, session) {
    items.push(mooncode_transcript_message_item(row))
  }
  items
}

///|
fn mooncode_drop_recovered_failed_assistant_items(
  items : Array[MoonCodeTranscriptItem],
) -> Array[MoonCodeTranscriptItem] {
  let rest : Array[MoonCodeTranscriptItem] = []
  let mut assistant_done_since_user = false
  for index, item in items {
    match item.message {
      Some(row) =>
        if row.role == "user" {
          assistant_done_since_user = false
          rest.push(item)
        } else if row.role == "assistant" &&
          row.status == "failed" &&
          mooncode_recoverable_assistant_failure(row.content) &&
          (
            assistant_done_since_user ||
            mooncode_transcript_has_assistant_after_before_user(items, index)
          ) {
          continue
        } else {
          if row.role == "assistant" && row.status != "failed" {
            assistant_done_since_user = true
          }
          rest.push(item)
        }
      None => rest.push(item)
    }
  }
  rest
}

///|
fn mooncode_recoverable_assistant_failure(content : String) -> Bool {
  content.contains("Could not start MoonCode runtime service") ||
  content.contains("MoonClaw native MoonCode runtime is not available") ||
  content.contains("MoonClaw daemon is not running")
}

///|
fn mooncode_repair_grouped_user_prefix_items(
  items : Array[MoonCodeTranscriptItem],
) -> Array[MoonCodeTranscriptItem] {
  let mut prefix_end = 0
  while prefix_end < items.length() &&
        mooncode_transcript_item_is_user_message(items[prefix_end]) {
    prefix_end = prefix_end + 1
  }
  if prefix_end < 2 || prefix_end >= items.length() {
    return items
  }
  for index in prefix_end..<items.length() {
    if mooncode_transcript_item_is_user_message(items[index]) {
      return items
    }
  }
  let groups : Array[Array[MoonCodeTranscriptItem]] = []
  let current : Array[MoonCodeTranscriptItem] = []
  for index in prefix_end..<items.length() {
    current.push(items[index])
    if mooncode_transcript_item_is_assistant_message(items[index]) {
      groups.push(current.copy())
      current.clear()
    }
  }
  if groups.length() < prefix_end {
    return items
  }
  let repaired : Array[MoonCodeTranscriptItem] = []
  for index in 0..<prefix_end {
    repaired.push(items[index])
    for item in groups[index] {
      repaired.push(item)
    }
  }
  for index in prefix_end..<groups.length() {
    for item in groups[index] {
      repaired.push(item)
    }
  }
  for item in current {
    repaired.push(item)
  }
  repaired
}

///|
fn mooncode_drop_duplicated_user_prompt_prefix(
  items : Array[MoonCodeTranscriptItem],
) -> Array[MoonCodeTranscriptItem] {
  let mut prefix_end = 0
  while prefix_end < items.length() &&
        mooncode_transcript_item_is_user_message(items[prefix_end]) {
    prefix_end = prefix_end + 1
  }
  if prefix_end == 0 || prefix_end >= items.length() {
    return items
  }
  let next : Array[MoonCodeTranscriptItem] = []
  let mut changed = false
  for index in 0..<prefix_end {
    match items[index].message {
      Some(row) =>
        if mooncode_transcript_items_have_message_after(
            items,
            index + 1,
            row.role,
            row.content,
          ) {
          changed = true
        } else {
          next.push(items[index])
        }
      _ => next.push(items[index])
    }
  }
  if !changed {
    return items
  }
  for index in prefix_end..<items.length() {
    next.push(items[index])
  }
  next
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
  let transcript_user_contents : Array[String] = []
  let mut running_assistant_index = -1
  let mut has_user = initial_has_user
  for event in events {
    if mooncode_event_is_user_prompt(event) {
      if !mooncode_event_is_duplicate_visible_command_prompt(
          transcript_user_contents, event,
        ) {
        mooncode_push_transcript_message_item(items, {
          role: "user",
          content: event.detail,
          status: event.status,
        })
        if mooncode_event_is_transcript_user_prompt(event) {
          transcript_user_contents.push(event.detail.trim().to_owned())
        }
        has_user = true
        running_assistant_index = -1
        for row in pending_assistant_finals {
          mooncode_push_transcript_message_item(items, row)
        }
        pending_assistant_finals.clear()
      }
    } else if mooncode_event_is_assistant_delta(event) {
      let content = event.detail.trim().to_owned()
      if content != "" && has_user {
        if mooncode_transcript_running_assistant_is_tail(
            items, running_assistant_index,
          ) {
          mooncode_replace_transcript_message_item(
            items,
            running_assistant_index,
            "assistant",
            mooncode_transcript_item_message_content(
              items, running_assistant_index,
            ) +
            content,
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
          items, running_assistant_index,
        ) {
        mooncode_dedupe_assistant_final_content(items, raw_content)
      } else {
        raw_content
      }
      if content != "" {
        let status = if event.status == "" { "done" } else { event.status }
        if has_user {
          if mooncode_transcript_running_assistant_is_tail(
              items, running_assistant_index,
            ) {
            mooncode_replace_transcript_message_item(
              items, running_assistant_index, "assistant", content, status,
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
                items, running_assistant_index,
              ) {
              mooncode_mark_transcript_message_item_done(
                items, running_assistant_index,
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
          items, running_assistant_index,
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
fn mooncode_event_is_duplicate_visible_command_prompt(
  transcript_user_contents : Array[String],
  event : MoonCodeEvent,
) -> Bool {
  if !mooncode_event_is_command_prompt_like(event) {
    return false
  }
  let content = event.detail.trim().to_owned()
  if content == "" {
    return false
  }
  transcript_user_contents.contains(content)
}

///|
fn mooncode_event_is_command_prompt_like(event : MoonCodeEvent) -> Bool {
  event.kind == "command.prompt" ||
  event.kind == "command.steer" ||
  event.command == "prompt" ||
  event.command == "steer"
}

///|
fn mooncode_event_is_transcript_user_prompt(event : MoonCodeEvent) -> Bool {
  event.lane == "transcript" &&
  (event.kind == "user" || event.title == "User prompt")
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
fn mooncode_transcript_items_with_acknowledged_pending_prompt(
  model : Model,
  session : MoonCodeSession,
  events : Array[MoonCodeEvent],
  prompt : MoonCodePendingPrompt,
) -> Array[MoonCodeTranscriptItem] {
  ignore(prompt)
  let items = mooncode_transcript_items_from_events(session.id, events)
  mooncode_merge_local_transcript_items_with_events(
    items, model, session, events,
  )
  items
}

///|
fn mooncode_transcript_items_with_pending_prompt(
  model : Model,
  session : MoonCodeSession,
  events : Array[MoonCodeEvent],
  prompt : MoonCodePendingPrompt,
) -> Array[MoonCodeTranscriptItem] {
  let split = mooncode_pending_prompt_event_split(prompt, events)
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
  mooncode_merge_local_transcript_items_with_events(
    items, model, session, events,
  )
  let tail = mooncode_transcript_items_from_events_with_user(
    session.id,
    after,
    initial_has_user=true,
  )
  for item in mooncode_drop_leading_activity_items(tail) {
    mooncode_push_event_tail_transcript_item(items, item)
  }
  items
}

///|
fn mooncode_pending_prompt_event_split(
  prompt : MoonCodePendingPrompt,
  events : Array[MoonCodeEvent],
) -> Int {
  let split = mooncode_clamp_count(prompt.after_event_count, events.length())
  if split == 0 && events.length() > 0 && mooncode_events_have_user(events) {
    let unanchored = mooncode_first_unanchored_command_event_index(events)
    if unanchored >= 0 {
      return unanchored
    }
  }
  if split == 0 &&
    events.length() > 0 &&
    (prompt.after_row_count > 0 || mooncode_events_have_user(events)) {
    events.length()
  } else {
    split
  }
}

///|
fn mooncode_first_unanchored_command_event_index(
  events : Array[MoonCodeEvent],
) -> Int {
  for index, event in events {
    if mooncode_event_is_user_prompt(event) ||
      mooncode_event_is_runtime_service_lifecycle(event) {
      continue
    }
    let command_id = mooncode_event_command_id(event)
    if command_id != "" &&
      !mooncode_events_have_user_prompt_for_command(events, command_id) {
      return index
    }
  }
  -1
}

///|
fn mooncode_event_is_runtime_service_lifecycle(event : MoonCodeEvent) -> Bool {
  event.kind == "runtime.service_started" ||
  event.kind == "runtime.service_finished" ||
  event.kind == "runtime.service_failed"
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
    Some(row) =>
      items[index] = mooncode_transcript_message_item({ ..row, status: "done" })
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
fn mooncode_merge_local_transcript_items_with_events(
  items : Array[MoonCodeTranscriptItem],
  model : Model,
  session : MoonCodeSession,
  acknowledged_events : Array[MoonCodeEvent],
) -> Unit {
  for row in model.mooncode_conversation_rows {
    if row.session_id != session.id {
      continue
    }
    let role = mooncode_transcript_message_role(row.role)
    let content = row.content.trim().to_owned()
    if content == "" ||
      mooncode_transcript_items_have_message(items, role, content) ||
      mooncode_transcript_events_have_acknowledged_message(
        acknowledged_events, role, content,
      ) {
      continue
    }
    if role == "user" &&
      mooncode_local_row_is_pending_prompt(model, session.id, content) {
      mooncode_insert_pending_prompt_item(
        items,
        { role, content, status: row.status },
        model,
        session.id,
      )
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
      mooncode_transcript_items_have_message(items, "user", prompt.content) ||
      mooncode_transcript_events_have_acknowledged_message(
        acknowledged_events,
        "user",
        prompt.content,
      ) {
      continue
    }
    mooncode_insert_pending_prompt_item(
      items,
      { role: "user", content: prompt.content, status: prompt.status },
      model,
      session.id,
    )
  }
}

///|
fn mooncode_transcript_events_have_acknowledged_message(
  events : Array[MoonCodeEvent],
  role : String,
  content : String,
) -> Bool {
  let normalized = content.trim().to_owned()
  if role != "user" || normalized == "" {
    return false
  }
  for event in events {
    if mooncode_event_is_user_prompt(event) &&
      event.detail.trim().to_owned() == normalized {
      return true
    }
  }
  false
}

///|
fn mooncode_insert_pending_prompt_item(
  items : Array[MoonCodeTranscriptItem],
  row : MoonCodeTranscriptRow,
  model : Model,
  session_id : String,
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
  } else {
    items.insert(insertion, item)
  }
}

///|
fn mooncode_push_event_tail_transcript_item(
  items : Array[MoonCodeTranscriptItem],
  item : MoonCodeTranscriptItem,
) -> Unit {
  match item.message {
    Some(row) => {
      let role = mooncode_transcript_message_role(row.role)
      let content = row.content.trim().to_owned()
      if content != "" &&
        !mooncode_transcript_items_have_message(items, role, content) {
        items.push(mooncode_transcript_message_item({ ..row, role, content }))
      }
    }
    None => items.push(item)
  }
}

///|
fn mooncode_transcript_items_have_message(
  items : Array[MoonCodeTranscriptItem],
  role : String,
  content : String,
) -> Bool {
  mooncode_transcript_items_have_message_after(items, 0, role, content)
}

///|
fn mooncode_transcript_items_have_message_after(
  items : Array[MoonCodeTranscriptItem],
  start : Int,
  role : String,
  content : String,
) -> Bool {
  let normalized_role = mooncode_transcript_message_role(role)
  let normalized_content = content.trim().to_owned()
  let from = mooncode_clamp_count(start, items.length())
  for index in from..<items.length() {
    match items[index].message {
      Some(row) =>
        if row.role == normalized_role &&
          row.content.trim().to_owned() == normalized_content {
          return true
        }
      None => ()
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
      let index = mooncode_clamp_count(prompt.after_row_count, fallback)
      if index == 0 && fallback > 0 {
        return fallback
      }
      return index
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
  if rest.length() == items.length() ||
    !mooncode_transcript_items_have_user(rest) {
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
fn mooncode_drop_recovered_failed_thinking_items(
  items : Array[MoonCodeTranscriptItem],
) -> Array[MoonCodeTranscriptItem] {
  let rest : Array[MoonCodeTranscriptItem] = []
  for index, item in items {
    match item.activity {
      Some(row) if mooncode_activity_row_is_recovered_planner_failure(row) &&
        mooncode_transcript_has_assistant_after_before_user(items, index) =>
        continue
      _ => rest.push(item)
    }
  }
  rest
}

///|
fn mooncode_activity_row_is_recovered_planner_failure(
  row : MoonCodeActivityRow,
) -> Bool {
  row.status == "failed" &&
  (
    row.detail.contains("model planner returned no usable MoonCode tool calls") ||
    row.detail.contains("planner returned no usable MoonCode tool calls")
  )
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
fn mooncode_transcript_item_is_assistant_message(
  item : MoonCodeTranscriptItem,
) -> Bool {
  match item.message {
    Some(row) => row.role == "assistant"
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
  mooncode_order_transcript_events_by_command(events, false)
}

///|
fn mooncode_order_transcript_item_events(
  events : Array[MoonCodeEvent],
) -> Array[MoonCodeEvent] {
  mooncode_order_transcript_events_by_command(events, true)
}

///|
fn mooncode_order_transcript_events_by_command(
  events : Array[MoonCodeEvent],
  assistant_after_activity : Bool,
) -> Array[MoonCodeEvent] {
  if !mooncode_events_have_command_links(events) {
    return events
  }
  let ordered : Array[MoonCodeEvent] = []
  let used_keys : Array[String] = []
  let emitted_command_ids : Array[String] = []
  for event in events {
    let command_id = mooncode_event_command_id(event)
    if command_id != "" &&
      mooncode_events_have_user_prompt_for_command(events, command_id) {
      if !emitted_command_ids.contains(command_id) {
        emitted_command_ids.push(command_id)
        mooncode_push_command_group_events(
          ordered, used_keys, events, command_id, assistant_after_activity,
        )
      }
    } else {
      mooncode_push_ordered_transcript_event(ordered, used_keys, event)
    }
  }
  ordered
}

///|
fn mooncode_push_command_group_events(
  ordered : Array[MoonCodeEvent],
  used_keys : Array[String],
  events : Array[MoonCodeEvent],
  command_id : String,
  assistant_after_activity : Bool,
) -> Unit {
  for linked in events {
    if mooncode_event_is_user_prompt(linked) &&
      mooncode_event_command_id(linked) == command_id {
      mooncode_push_ordered_transcript_event(ordered, used_keys, linked)
    }
  }
  if assistant_after_activity {
    for linked in events {
      if !mooncode_event_is_user_prompt(linked) &&
        !mooncode_event_is_assistant_message(linked) &&
        mooncode_event_command_id(linked) == command_id {
        mooncode_push_ordered_transcript_event(ordered, used_keys, linked)
      }
    }
    for linked in events {
      if !mooncode_event_is_user_prompt(linked) &&
        mooncode_event_is_assistant_message(linked) &&
        mooncode_event_command_id(linked) == command_id {
        mooncode_push_ordered_transcript_event(ordered, used_keys, linked)
      }
    }
  } else {
    for linked in events {
      if !mooncode_event_is_user_prompt(linked) &&
        mooncode_event_command_id(linked) == command_id {
        mooncode_push_ordered_transcript_event(ordered, used_keys, linked)
      }
    }
  }
}

///|
fn mooncode_events_have_user_prompt_for_command(
  events : Array[MoonCodeEvent],
  command_id : String,
) -> Bool {
  if command_id == "" {
    return false
  }
  for event in events {
    if mooncode_event_is_user_prompt(event) &&
      mooncode_event_command_id(event) == command_id {
      return true
    }
  }
  false
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
      mooncode_complete_event_transcript_rows(
        event_rows, model, session, events,
      )
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
fn mooncode_session_has_pending_prompt(
  model : Model,
  session_id : String,
) -> Bool {
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
  if prompt.client_turn_id != "" {
    prompt.client_turn_id
  } else {
    "\{prompt.session_id}\n\{prompt.after_row_count}\n\{prompt.content}"
  }
}

///|
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
