///|
priv struct ConversationTurnDraft {
  mut turn_id : String
  mut client_turn_id : String
  mut command_id : String
  mut user : Json
  progress : Array[Json]
  mut assistant : Json
  mut assistant_delta : String
  mut status : String
  mut started_at : String
  mut updated_at : String
}

///|
fn conversation_empty_message() -> Json {
  Json::object({})
}

///|
pub fn conversation_ownership_contract_json() -> Json {
  @mooncode_core.conversation_ownership_contract_json()
}

///|
fn conversation_turn_draft(
  turn_id~ : String,
  client_turn_id~ : String,
  command_id~ : String,
  created_at~ : String,
) -> ConversationTurnDraft {
  {
    turn_id,
    client_turn_id,
    command_id,
    user: conversation_empty_message(),
    progress: [],
    assistant: conversation_empty_message(),
    assistant_delta: "",
    status: "queued",
    started_at: created_at,
    updated_at: created_at,
  }
}

///|
pub fn conversation_projection(session : Json, events : Array[Json]) -> Json {
  let turns = conversation_turns_from_events(events)
  let turn_json : Array[Json] = []
  for turn in turns {
    turn_json.push(conversation_turn_json(turn))
  }
  let ownership = conversation_ownership_report(events)
  {
    "kind": conversation_kind(),
    "protocol": protocol_version(),
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "turn_count": turn_json.length(),
    "source_event_count": events.length(),
    "turns": Json::array(turn_json),
    "ownership": ownership,
    "ownership_contract": conversation_ownership_contract_json(),
    "owner": {
      "projection": "mooncode",
      "ui": "moondesk",
      "runtime": "moonclaw",
    },
  }
}

///|
fn conversation_ownership_report(events : Array[Json]) -> Json {
  let ignored_ids : Array[Json] = []
  let mut owned_visible_count = 0
  let mut ignored_unowned_count = 0
  for event in events {
    if !conversation_event_requires_owner_for_visibility(event) {
      continue
    }
    if conversation_event_command_id(event) == "" {
      ignored_unowned_count += 1
      ignored_ids.push(json_string(event, "id", default="").to_json())
    } else {
      owned_visible_count += 1
    }
  }
  {
    "kind": "mooncode-conversation-ownership-report",
    "protocol": protocol_version(),
    "owned_visible_event_count": owned_visible_count,
    "ignored_unowned_visible_event_count": ignored_unowned_count,
    "ignored_unowned_visible_event_ids": Json::array(ignored_ids),
    "contract_satisfied": ignored_unowned_count == 0,
    "rule": "Visible rows are projected only from events with explicit command ownership; ignored unowned events remain diagnostic runtime evidence.",
  }
}

///|
fn conversation_turns_from_events(
  events : Array[Json],
) -> Array[ConversationTurnDraft] {
  let turns : Array[ConversationTurnDraft] = []
  let pending_scoped_events : Array[Json] = []
  for event in events {
    if conversation_event_is_runtime_service_lifecycle(event) {
      continue
    }
    if conversation_event_is_user_prompt(event) {
      let turn_index = conversation_apply_user_event(turns, event)
      conversation_apply_pending_scoped_events(
        turns,
        pending_scoped_events,
        turn_index,
        conversation_event_command_id(event),
      )
    } else {
      let command_id = conversation_event_command_id(event)
      if command_id != "" &&
        conversation_turn_index_for_command(turns, command_id) < 0 {
        pending_scoped_events.push(event)
      } else {
        conversation_apply_runtime_event(turns, event)
      }
    }
  }
  turns
}

///|
fn conversation_apply_user_event(
  turns : Array[ConversationTurnDraft],
  event : Json,
) -> Int {
  let command_id = conversation_event_command_id(event)
  let client_turn_id = conversation_event_client_turn_id(event)
  let created_at = json_string(event, "created_at", default="")
  let turn_id = conversation_turn_id_for_event(event, command_id)
  let index = conversation_turn_index_for_command(turns, command_id)
  let target = if index >= 0 {
    index
  } else {
    turns.push(
      conversation_turn_draft(
        turn_id~,
        client_turn_id~,
        command_id~,
        created_at~,
      ),
    )
    turns.length() - 1
  }
  let turn = turns[target]
  turn.turn_id = if turn.turn_id == "" { turn_id } else { turn.turn_id }
  turn.client_turn_id = if turn.client_turn_id == "" {
    client_turn_id
  } else {
    turn.client_turn_id
  }
  turn.command_id = if turn.command_id == "" {
    command_id
  } else {
    turn.command_id
  }
  turn.user = conversation_user_message(event)
  turn.status = conversation_merge_status(
    turn.status,
    json_string(event, "status", default="queued"),
  )
  if turn.started_at == "" {
    turn.started_at = created_at
  }
  turn.updated_at = conversation_latest_timestamp(turn.updated_at, created_at)
  turns[target] = turn
  target
}

///|
fn conversation_apply_pending_scoped_events(
  turns : Array[ConversationTurnDraft],
  pending_scoped_events : Array[Json],
  turn_index : Int,
  command_id : String,
) -> Unit {
  if turn_index < 0 || command_id == "" {
    return
  }
  let keep : Array[Json] = []
  for event in pending_scoped_events {
    if conversation_event_command_id(event) == command_id {
      conversation_apply_runtime_event_to_turn(turns, turn_index, event)
    } else {
      keep.push(event)
    }
  }
  pending_scoped_events.clear()
  for event in keep {
    pending_scoped_events.push(event)
  }
}

///|
fn conversation_apply_runtime_event(
  turns : Array[ConversationTurnDraft],
  event : Json,
) -> Unit {
  let command_id = conversation_event_command_id(event)
  let index = conversation_target_turn_index(turns, event, command_id)
  if index < 0 {
    return
  }
  conversation_apply_runtime_event_to_turn(turns, index, event)
}

///|
fn conversation_apply_runtime_event_to_turn(
  turns : Array[ConversationTurnDraft],
  index : Int,
  event : Json,
) -> Unit {
  if index < 0 || index >= turns.length() {
    return
  }
  let turn = turns[index]
  let created_at = json_string(event, "created_at", default="")
  if conversation_event_is_assistant_delta(event) {
    let detail = json_string(event, "detail", default="")
    if detail.trim().to_owned() != "" {
      turn.assistant_delta = turn.assistant_delta + detail
      turn.status = conversation_merge_status(turn.status, "running")
    }
  } else if conversation_event_is_assistant_final(event) {
    let content = conversation_event_assistant_content(event)
    if content != "" {
      turn.assistant = conversation_assistant_message(event, content)
      turn.assistant_delta = ""
      turn.status = conversation_assistant_final_status(
        turn.status,
        json_string(event, "status", default="done"),
      )
    } else if conversation_event_is_terminal_without_answer(event) {
      turn.status = conversation_merge_status(
        turn.status,
        json_string(event, "status", default="done"),
      )
      conversation_mark_assistant_terminal_status(turn, event)
    }
  } else if conversation_event_is_terminal_without_answer(event) {
    if conversation_message_content(turn.assistant) == "" &&
      turn.assistant_delta.trim().to_owned() != "" {
      turn.assistant = conversation_assistant_delta_message(
        event,
        turn.assistant_delta,
      )
      turn.assistant_delta = ""
    }
    turn.status = conversation_merge_status(
      turn.status,
      json_string(event, "status", default="done"),
    )
    conversation_mark_assistant_terminal_status(turn, event)
  } else if conversation_event_is_abort_reply(event) {
    turn.assistant = conversation_abort_message(event)
    turn.assistant_delta = ""
    turn.status = "cancelled"
  } else if conversation_event_is_failure_reply(event) {
    let content = json_string(event, "detail", default="").trim().to_owned()
    if content != "" {
      turn.assistant = conversation_assistant_message(event, content)
      turn.assistant_delta = ""
    }
    turn.status = "failed"
  } else if conversation_event_is_visible_progress(event) {
    let progress = conversation_progress_item(event)
    if conversation_message_content(progress) != "" ||
      json_string(progress, "title", default="") != "" {
      turn.progress.push(progress)
      turn.status = conversation_merge_status(
        turn.status,
        json_string(event, "status", default="running"),
      )
    }
  }
  turn.updated_at = conversation_latest_timestamp(turn.updated_at, created_at)
  turns[index] = turn
}

///|
fn conversation_turn_json(turn : ConversationTurnDraft) -> Json {
  let assistant = if conversation_message_content(turn.assistant) != "" {
    turn.assistant
  } else if turn.assistant_delta.trim().to_owned() != "" {
    {
      "role": "assistant",
      "content": turn.assistant_delta.trim().to_owned(),
      "status": "running",
    }
  } else {
    conversation_empty_message()
  }
  let items : Array[Json] = []
  if conversation_message_content(turn.user) != "" {
    items.push(turn.user)
  }
  for progress in turn.progress {
    items.push(progress)
  }
  if conversation_message_content(assistant) != "" {
    items.push(assistant)
  }
  {
    "kind": conversation_turn_kind(),
    "turn_id": turn.turn_id,
    "client_turn_id": turn.client_turn_id,
    "command_id": turn.command_id,
    "owner": {
      "turn_id": turn.turn_id,
      "client_turn_id": turn.client_turn_id,
      "command_id": turn.command_id,
    },
    "status": conversation_final_turn_status(turn, assistant),
    "started_at": turn.started_at,
    "updated_at": turn.updated_at,
    "user": turn.user,
    "progress": Json::array(turn.progress),
    "assistant": assistant,
    "items": Json::array(items),
  }
}

///|
fn conversation_final_turn_status(
  turn : ConversationTurnDraft,
  assistant : Json,
) -> String {
  if conversation_message_content(assistant) != "" &&
    json_string(assistant, "status", default="") == "done" {
    "done"
  } else if turn.status == "failed" {
    "failed"
  } else if turn.status == "cancelled" {
    "cancelled"
  } else {
    turn.status
  }
}

///|
fn conversation_user_message(event : Json) -> Json {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let content = trimmed_or(
    json_string(
      event,
      "detail",
      default=json_string(packet, "message", default=""),
    ),
    fallback=json_string(packet, "message", default=""),
  )
  conversation_with_owner(
    {
      "role": "user",
      "content": content,
      "status": json_string(event, "status", default="queued"),
      "event_id": json_string(event, "id", default=""),
      "created_at": json_string(event, "created_at", default=""),
    },
    event,
  )
}

///|
fn conversation_assistant_message(event : Json, content : String) -> Json {
  conversation_with_owner(
    {
      "role": "assistant",
      "content": content,
      "status": json_string(event, "status", default="done"),
      "event_id": json_string(event, "id", default=""),
      "created_at": json_string(event, "created_at", default=""),
    },
    event,
  )
}

///|
fn conversation_assistant_delta_message(event : Json, content : String) -> Json {
  conversation_with_owner(
    {
      "role": "assistant",
      "content": content.trim().to_owned(),
      "status": json_string(event, "status", default="running"),
      "event_id": json_string(event, "id", default=""),
      "created_at": json_string(event, "created_at", default=""),
    },
    event,
  )
}

///|
fn conversation_abort_message(event : Json) -> Json {
  conversation_with_owner(
    {
      "role": "assistant",
      "content": conversation_abort_content(event),
      "status": "cancelled",
      "event_id": json_string(event, "id", default=""),
      "created_at": json_string(event, "created_at", default=""),
    },
    event,
  )
}

///|
fn conversation_abort_content(event : Json) -> String {
  let detail = json_string(event, "detail", default="").trim().to_owned()
  if detail == "" || conversation_progress_text_looks_internal(detail) {
    "Request cancelled."
  } else {
    detail
  }
}

///|
fn conversation_mark_assistant_terminal_status(
  turn : ConversationTurnDraft,
  event : Json,
) -> Unit {
  let status = json_string(event, "status", default="done")
  if conversation_message_content(turn.assistant) != "" &&
    (status == "done" || status == "failed") {
    turn.assistant = runtime_with_field(
      turn.assistant,
      "status",
      status.to_json(),
    )
  }
}

///|
fn conversation_progress_item(event : Json) -> Json {
  conversation_with_owner(
    {
      "role": "progress",
      "event_id": json_string(event, "id", default=""),
      "lane": json_string(event, "lane", default="runtime"),
      "kind": json_string(event, "kind", default="runtime_update"),
      "title": conversation_progress_title(event),
      "detail": conversation_progress_detail(event),
      "status": json_string(event, "status", default="running"),
      "created_at": json_string(event, "created_at", default=""),
    },
    event,
  )
}

///|
fn conversation_with_owner(message : Json, event : Json) -> Json {
  let owner = conversation_owner(event)
  message
  |> runtime_with_field(
    "turn_id",
    json_string(owner, "turn_id", default="").to_json(),
  )
  |> runtime_with_field(
    "client_turn_id",
    json_string(owner, "client_turn_id", default="").to_json(),
  )
  |> runtime_with_field(
    "command_id",
    json_string(owner, "command_id", default="").to_json(),
  )
  |> runtime_with_field(
    "run_id",
    json_string(owner, "run_id", default="").to_json(),
  )
  |> runtime_with_field(
    "runtime_session_id",
    json_string(owner, "runtime_session_id", default="").to_json(),
  )
  |> runtime_with_field(
    "action",
    json_string(owner, "action", default="").to_json(),
  )
  |> runtime_with_field("owner", owner)
}

///|
fn conversation_owner(event : Json) -> Json {
  let command_id = conversation_event_command_id(event)
  {
    "turn_id": conversation_turn_id_for_event(event, command_id),
    "client_turn_id": conversation_event_client_turn_id(event),
    "command_id": command_id,
    "run_id": conversation_event_run_id(event),
    "runtime_session_id": conversation_event_runtime_session_id(event),
    "action": conversation_event_action(event),
    "event_id": json_string(event, "id", default=""),
    "event_kind": json_string(event, "kind", default=""),
  }
}

///|
fn conversation_progress_title(event : Json) -> String {
  let kind = json_string(event, "kind", default="")
  let event_name = json_string(event, "event", default="")
  let lane = json_string(event, "lane", default="")
  let title = json_string(event, "title", default="")
  let tool = conversation_event_tool_name(event)
  if kind == event_runtime_turn_started() {
    "Starting request"
  } else if kind == event_reasoning_delta() || kind == event_reasoning_message() {
    "Thinking"
  } else if event_name == event_tool_call() || kind == event_tool_call() {
    conversation_tool_progress_title(lane, tool, started=true)
  } else if event_name == event_tool_result() {
    conversation_tool_progress_title(lane, tool, started=false)
  } else if kind == event_test_result() {
    "Checked the result"
  } else if kind == event_package_built() {
    "Prepared output"
  } else if lane == event_lane_diff() {
    "Edited files"
  } else if lane == event_lane_artifact() {
    "Prepared output"
  } else if title != "" {
    title
  } else {
    "Working on request"
  }
}

///|
fn conversation_progress_detail(event : Json) -> String {
  let kind = json_string(event, "kind", default="")
  let event_name = json_string(event, "event", default="")
  let lane = json_string(event, "lane", default="")
  let tool = conversation_event_tool_name(event)
  let detail = json_string(event, "detail", default="").trim().to_owned()
  if kind == event_runtime_turn_started() {
    "Started working on the request."
  } else if kind == event_reasoning_delta() || kind == event_reasoning_message() {
    conversation_reasoning_progress_detail(detail)
  } else if event_name == event_tool_call() || kind == event_tool_call() {
    conversation_tool_progress_detail(event, lane, tool, started=true)
  } else if event_name == event_tool_result() {
    conversation_tool_progress_detail(event, lane, tool, started=false)
  } else if kind == event_test_result() {
    "Finished checking the result."
  } else if kind == event_package_built() {
    "Prepared the requested output."
  } else if lane == event_lane_diff() {
    "Updated the relevant files."
  } else if lane == event_lane_artifact() {
    "Prepared the requested output."
  } else if detail == "" {
    ""
  } else {
    conversation_sanitize_progress_detail(detail)
  }
}

///|
fn conversation_reasoning_progress_detail(detail : String) -> String {
  if detail.contains("model-tool-calls") ||
    (detail.contains("selected") && detail.contains("tool call")) {
    "Chose what to do next."
  } else if detail.contains("asking model") {
    "Reviewed the request."
  } else if conversation_progress_text_looks_internal(detail) {
    "Thought through the request."
  } else if detail == "" {
    "Reviewed the request."
  } else {
    detail
  }
}

///|
fn conversation_tool_progress_title(
  lane : String,
  tool : String,
  started~ : Bool,
) -> String {
  if lane == event_lane_diff() {
    if started {
      "Editing files"
    } else {
      "Updated files"
    }
  } else if lane == event_lane_test() {
    if started {
      "Checking result"
    } else {
      "Checked result"
    }
  } else if lane == event_lane_artifact() {
    if started {
      "Preparing output"
    } else {
      "Prepared output"
    }
  } else if lane == event_lane_review() {
    if started {
      "Preparing answer"
    } else {
      "Prepared answer"
    }
  } else if conversation_tool_is_context_lookup(tool) {
    "Checking context"
  } else if tool == "shell" || tool == "moon_cmd" || tool == "moon_check" {
    if started {
      "Running command"
    } else {
      "Finished command"
    }
  } else if started {
    "Choosing next action"
  } else {
    "Finished action"
  }
}

///|
fn conversation_tool_progress_detail(
  event : Json,
  lane : String,
  tool : String,
  started~ : Bool,
) -> String {
  let status = json_string(event, "status", default="")
  if status == "failed" {
    return "A step failed before the assistant finished."
  }
  let path = json_string(event, "path", default="").trim().to_owned()
  if lane == event_lane_diff() {
    if started {
      if path == "" {
        "Preparing file changes."
      } else {
        "Preparing changes to `\{path}`."
      }
    } else if path == "" {
      "Updated the relevant files."
    } else {
      "Updated `\{path}`."
    }
  } else if lane == event_lane_test() {
    if started {
      "Running the requested check."
    } else {
      "Finished checking the result."
    }
  } else if lane == event_lane_artifact() {
    if started {
      "Preparing the requested output."
    } else {
      "Prepared the requested output."
    }
  } else if lane == event_lane_review() {
    if started {
      "Preparing the answer."
    } else {
      "Prepared the answer."
    }
  } else if conversation_tool_is_context_lookup(tool) {
    "Checking relevant project context."
  } else if tool == "shell" || tool == "moon_cmd" || tool == "moon_check" {
    if started {
      "Running a command."
    } else {
      "Finished the command."
    }
  } else if started {
    "Chose what to do next."
  } else {
    "Finished a work step."
  }
}

///|
fn conversation_tool_is_context_lookup(tool : String) -> Bool {
  tool == "read" ||
  tool == "grep" ||
  tool == "glob" ||
  tool == "web_search" ||
  tool == "web_fetch"
}

///|
fn conversation_event_tool_name(event : Json) -> String {
  let tool_name = json_string(event, "tool_name", default="")
  if tool_name != "" {
    return tool_name
  }
  let tool = json_string(event, "tool", default="")
  if tool != "" {
    return tool
  }
  let kind = json_string(event, "kind", default="")
  if kind == event_tool_call() {
    ""
  } else {
    kind
  }
}

///|
fn conversation_sanitize_progress_detail(detail : String) -> String {
  if conversation_progress_text_looks_internal(detail) {
    "Prepared the response."
  } else {
    detail
  }
}

///|
fn conversation_progress_text_looks_internal(text : String) -> Bool {
  text.contains("MoonClaw") ||
  text.contains("moonclaw") ||
  text.contains("MoonCode native") ||
  text.contains("runtime") ||
  text.contains("Runtime") ||
  text.contains("command_id") ||
  text.contains("client_turn_id") ||
  text.contains("turn_id") ||
  text.contains("model-tool-calls") ||
  text.contains("tool call") ||
  text.contains(event_assistant_delta()) ||
  text.contains("command.prompt") ||
  text.contains("stdout") ||
  text.contains("stderr") ||
  text.contains("debug") ||
  text.contains("trace") ||
  text.contains("\"role\"") ||
  text.contains("\"kind\"")
}

///|
fn conversation_event_is_visible_progress(event : Json) -> Bool {
  let kind = json_string(event, "kind", default="")
  let lane = json_string(event, "lane", default="")
  let event_name = json_string(event, "event", default="")
  kind == event_runtime_turn_started() ||
  kind == event_reasoning_delta() ||
  kind == event_reasoning_message() ||
  kind == event_tool_call() ||
  event_name == event_tool_call() ||
  event_name == event_tool_result() ||
  kind == event_test_result() ||
  kind == event_package_built() ||
  lane == event_lane_diff() ||
  lane == event_lane_artifact()
}

///|
fn conversation_event_command_id(event : Json) -> String {
  let explicit = json_string(event, "command_id", default="")
  if explicit != "" {
    return explicit
  }
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let packet_id = json_string(packet, "command_id", default="")
  if packet_id != "" {
    return packet_id
  }
  let event_id = json_string(event, "id", default="")
  if json_string(event, "kind", default="") == "command.prompt" &&
    event_id.has_prefix("mooncode-command-") {
    return event_id
  }
  ""
}

///|
fn conversation_event_client_turn_id(event : Json) -> String {
  let explicit = json_string(event, "client_turn_id", default="")
  if explicit != "" {
    return explicit
  }
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  json_string(packet, "client_turn_id", default="")
}

///|
fn conversation_event_action(event : Json) -> String {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let action = json_string(packet, "action", default="")
  if action != "" {
    return action
  }
  let command = json_string(event, "command", default="")
  if command != "" {
    return command
  }
  let kind = json_string(event, "kind", default="")
  if kind.has_prefix("command.") {
    kind["command.".length():].to_owned()
  } else {
    "prompt"
  }
}

///|
fn conversation_event_run_id(event : Json) -> String {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let packet_run = runtime_first_string(
    packet,
    ["run_id", "runtime_run_id", "service_id"],
    default="",
  )
  if packet_run != "" {
    return packet_run
  }
  runtime_first_string(
    event,
    ["run_id", "runId", "runtime_run_id", "service_id"],
    default="",
  )
}

///|
fn conversation_event_runtime_session_id(event : Json) -> String {
  let packet = runtime_json_object_field_or_empty(event, "command_packet")
  let packet_runtime_session_id = json_string(
    packet,
    "runtime_session_id",
    default="",
  )
  if packet_runtime_session_id != "" {
    return packet_runtime_session_id
  }
  json_string(event, "runtime_session_id", default="")
}

///|
fn conversation_turn_id_for_event(event : Json, command_id : String) -> String {
  if command_id != "" {
    command_id
  } else {
    let event_id = json_string(event, "id", default="")
    if event_id != "" {
      event_id
    } else {
      stable_event_id("mooncode-conversation-turn:" + event.stringify())
    }
  }
}

///|
fn conversation_turn_index_for_command(
  turns : Array[ConversationTurnDraft],
  command_id : String,
) -> Int {
  if command_id == "" {
    return -1
  }
  for index, turn in turns {
    if turn.command_id == command_id {
      return index
    }
  }
  -1
}

///|
fn conversation_target_turn_index(
  turns : Array[ConversationTurnDraft],
  event : Json,
  command_id : String,
) -> Int {
  let command_index = conversation_turn_index_for_command(turns, command_id)
  if command_index >= 0 {
    return command_index
  }
  if command_id != "" {
    return -1
  }
  if conversation_event_can_attach_to_active_turn(event) {
    conversation_active_turn_index(turns)
  } else {
    -1
  }
}

///|
fn conversation_event_can_attach_to_active_turn(event : Json) -> Bool {
  let _ = event
  false
}

///|
fn conversation_active_turn_index(turns : Array[ConversationTurnDraft]) -> Int {
  for offset in 0..<turns.length() {
    let index = turns.length() - 1 - offset
    let status = turns[index].status
    if status == "queued" || status == "running" {
      return index
    }
  }
  -1
}

///|
fn conversation_event_is_user_prompt(event : Json) -> Bool {
  let lane = json_string(event, "lane", default="")
  let kind = json_string(event, "kind", default="")
  let command = json_string(event, "command", default="")
  let title = json_string(event, "title", default="")
  (lane == event_lane_transcript() && kind == "user") ||
  command == "prompt" ||
  kind == "command.prompt" ||
  title == "User prompt"
}

///|
fn conversation_event_is_assistant_delta(event : Json) -> Bool {
  json_string(event, "lane", default="") == event_lane_transcript() &&
  json_string(event, "kind", default="") == event_assistant_delta()
}

///|
fn conversation_event_is_assistant_final(event : Json) -> Bool {
  (
    json_string(event, "lane", default="") == event_lane_transcript() &&
    json_string(event, "kind", default="") == "assistant"
  ) ||
  conversation_event_finish_tool_call_answer(event) != "" ||
  json_string(event, "kind", default="") == "finish" ||
  json_string(event, "title", default="") == "Assistant response"
}

///|
fn conversation_event_assistant_content(event : Json) -> String {
  let finish_answer = conversation_event_finish_tool_call_answer(event)
  if finish_answer != "" {
    return finish_answer
  }
  let result = runtime_json_object_field_or_empty(event, "tool_result")
  let output = json_string(result, "output", default="").trim().to_owned()
  if output != "" && !conversation_finish_content_is_status(output) {
    return output
  }
  let content = json_string(event, "detail", default="").trim().to_owned()
  if json_string(event, "kind", default="") == "finish" &&
    conversation_finish_content_is_status(content) {
    ""
  } else {
    content
  }
}

///|
fn conversation_event_finish_tool_call_answer(event : Json) -> String {
  if json_string(event, "kind", default="") != event_tool_call() {
    return ""
  }
  let title = json_string(event, "title", default="").to_lower().to_string()
  let tool_name = json_string(event, "tool_name", default="")
  if tool_name != "finish" && !title.contains("finish") {
    return ""
  }
  let detail = json_string(event, "detail", default="")
  let parsed = @json.parse(detail) catch { _ => Json::object({}) }
  json_string(parsed, "answer", default="").trim().to_owned()
}

///|
fn conversation_event_is_terminal_without_answer(event : Json) -> Bool {
  let kind = json_string(event, "kind", default="")
  (
    kind == "finish" ||
    kind == event_runtime_turn_finished() ||
    kind == event_runtime_loop() ||
    kind == event_runtime_service_finished()
  ) &&
  (
    json_string(event, "status", default="") == "done" ||
    json_string(event, "status", default="") == "failed"
  )
}

///|
fn conversation_event_is_failure_reply(event : Json) -> Bool {
  conversation_event_command_id(event) != "" &&
  conversation_event_is_failure_shape(event)
}

///|
fn conversation_event_is_failure_shape(event : Json) -> Bool {
  json_string(event, "status", default="") == "failed" &&
  conversation_event_failure_kind(event)
}

///|
fn conversation_event_failure_kind(event : Json) -> Bool {
  let kind = json_string(event, "kind", default="")
  runtime_failure_event_name_is_supported(kind)
}

///|
fn conversation_event_is_abort_reply(event : Json) -> Bool {
  conversation_event_is_abort_shape(event) &&
  conversation_event_command_id(event) != "" &&
  conversation_event_action(event) != "cancel" &&
  conversation_event_action(event) != "steer"
}

///|
fn conversation_event_is_abort_shape(event : Json) -> Bool {
  json_string(event, "kind", default="") == event_runtime_aborted()
}

///|
fn conversation_event_requires_owner_for_visibility(event : Json) -> Bool {
  conversation_event_is_assistant_delta(event) ||
  conversation_event_is_assistant_final(event) ||
  conversation_event_is_terminal_without_answer(event) ||
  conversation_event_is_failure_shape(event) ||
  conversation_event_is_abort_shape(event) ||
  conversation_event_is_visible_progress(event)
}

///|
fn conversation_event_is_runtime_service_lifecycle(event : Json) -> Bool {
  let kind = json_string(event, "kind", default="")
  kind == event_runtime_service_started() ||
  kind == event_runtime_service_finished() ||
  kind == event_runtime_service_failed()
}

///|
fn conversation_finish_content_is_status(content : String) -> Bool {
  content == "" ||
  content == "finished" ||
  content == "Runtime command finished." ||
  content.contains("runtime loop completed") ||
  content.contains("MoonClaw native MoonCode runtime") ||
  content.contains("Native MoonCode runtime recorded this prompt")
}

///|
fn conversation_message_content(message : Json) -> String {
  json_string(message, "content", default="").trim().to_owned()
}

///|
fn conversation_merge_status(current : String, incoming : String) -> String {
  if current == "failed" || incoming == "failed" {
    "failed"
  } else if current == "cancelled" || incoming == "cancelled" {
    "cancelled"
  } else if incoming == "running" {
    "running"
  } else if current == "running" && incoming != "done" {
    "running"
  } else if incoming == "done" {
    "done"
  } else if current == "" {
    incoming
  } else {
    current
  }
}

///|
fn conversation_assistant_final_status(
  current : String,
  incoming : String,
) -> String {
  if incoming == "failed" {
    "failed"
  } else if incoming == "running" {
    "running"
  } else if incoming == "done" {
    "done"
  } else if current == "" {
    incoming
  } else {
    current
  }
}

///|
fn conversation_latest_timestamp(current : String, incoming : String) -> String {
  if incoming == "" {
    current
  } else if current == "" || incoming.compare(current) > 0 {
    incoming
  } else {
    current
  }
}
