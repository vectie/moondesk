///|
/// Admission callbacks and polling can refresh the handoff without navigation.
/// Do not offer an ephemeral form while those updates can replace its binding.
fn work_learning_refresh_pending(model : Model) -> Bool {
  let state = model.work_handoff.continuation
  !(state.phase == "draft" ||
  state.phase == "conflict" ||
  (state.phase == "storage_failed" && !state.prior_uncertainty) ||
  (
    state.phase == "saved" &&
    work_continuation_settled(work_continuation_current(state))
  ))
}

///|
/// Only the host-resolved work identity may open the captured learning surface.
/// Ordinary selected-workspace and optimistic conversation state are not inputs.
fn work_learning_binding(model : Model) -> Json {
  let state = model.work_handoff
  let inactive : Json = {
    "active": state.target is Some(_),
    "phase": state.phase,
    "generation": state.generation,
  }
  guard state.phase == "ready" else { return inactive }
  if work_learning_refresh_pending(model) {
    return inactive
  }
  guard state.target is Some(target) else { return inactive }
  guard state.canonical is Some(canonical) else { return inactive }
  if canonical.workspace_id == "" ||
    canonical.root_path == "" ||
    canonical.session_id != target.session_id ||
    canonical.command_id != target.command_id ||
    handoff_normalize_root(canonical.root_path) !=
    handoff_normalize_root(target.book_root) {
    return inactive
  }
  let key : Json = [
    ToJson::to_json(state.generation),
    ToJson::to_json(canonical.workspace_id),
    ToJson::to_json(canonical.root_path),
    ToJson::to_json(canonical.session_id),
    ToJson::to_json(canonical.command_id),
    ToJson::to_json(target.task_id),
    ToJson::to_json(target.run_id),
    ToJson::to_json(target.return_to),
    handoff_field(state.output_hint, "command_id"),
    handoff_field(state.output_hint, "path"),
    handoff_field(state.output_hint, "evidence_id"),
  ]
  {
    "active": true,
    "phase": "ready",
    "generation": state.generation,
    "binding_key": key.stringify(),
    "workspace_id": canonical.workspace_id,
    "book_root": canonical.root_path,
    "session_id": canonical.session_id,
    "original_command_id": canonical.command_id,
    "task_id": target.task_id,
    "run_id": target.run_id,
    "target_query": handoff_target_query(
      target.task_id,
      target.run_id,
      target.session_id,
      target.command_id,
      target.book_root,
      target.return_to,
    ),
    "output_hint": {
      "command_id": handoff_text(state.output_hint, "command_id"),
      "path": handoff_text(state.output_hint, "path"),
      "evidence_id": handoff_text(state.output_hint, "evidence_id"),
    },
  }
}

///|
fn work_learning_sources(model : Model) -> Array[Json] {
  let state = model.work_handoff
  if handoff_text(work_learning_binding(model), "binding_key") == "" {
    return []
  }
  guard state.target is Some(target) else { return [] }
  guard state.canonical is Some(canonical) else { return [] }
  guard state.session is Some(session) else { return [] }
  if session.id != canonical.session_id ||
    session.workspace_id != canonical.workspace_id ||
    handoff_normalize_root(session.cwd) !=
    handoff_normalize_root(canonical.root_path) {
    return []
  }
  guard session.mooncode_conversation is Some(conversation) else { return [] }
  if conversation.session_id != canonical.session_id {
    return []
  }
  let sources : Array[Json] = []
  let turn_counts : Map[String, Int32] = Map([])
  for turn in conversation.turns {
    turn_counts[turn.turn_id] = turn_counts.get(turn.turn_id).unwrap_or(0) + 1
  }
  for turn in conversation.turns {
    guard turn.assistant is Some(answer) else { continue }
    if turn.turn_id == "" ||
      turn.command_id == "" ||
      turn.status != "done" ||
      answer.status != "done" ||
      answer.role != "assistant" ||
      answer.content.trim().is_empty() ||
      answer.command_id != turn.command_id ||
      answer.client_turn_id != turn.client_turn_id ||
      turn_counts.get(turn.turn_id) != Some(1) {
      continue
    }
    let mut continuation_id = ""
    if turn.command_id != canonical.command_id {
      let records = state.continuation.records.filter(record => {
        work_continuation_record_valid(target, record) &&
        handoff_text(record, "command_id") == turn.command_id &&
        handoff_text(record, "client_turn_id") == turn.client_turn_id &&
        handoff_text(record, "state") == "completed" &&
        handoff_text(record, "admission") == "accepted" &&
        work_continuation_input_verified(record)
      })
      if records.length() != 1 {
        continue
      }
      continuation_id = handoff_text(records[0], "continuation_id")
    }
    sources.push({
      "command_id": turn.command_id,
      "turn_id": turn.turn_id,
      "item_id": answer.item_id,
      "client_turn_id": turn.client_turn_id,
      "content": answer.content,
      "conversation_revision": conversation.revision,
      "continuation_id": continuation_id,
    })
  }
  sources
}

///|
fn work_learning_payload(
  model : Model,
  generation : Int32,
  command : String,
  turn : String,
  item : String,
) -> Json? {
  let binding = work_learning_binding(model)
  if model.work_handoff.generation != generation ||
    handoff_text(binding, "binding_key") == "" ||
    !work_continuation_location_matches(handoff_text(binding, "target_query")) ||
    !work_output_location_matches(model.work_handoff.output_hint) {
    return None
  }
  let matches = work_learning_sources(model).filter(source => {
    handoff_text(source, "command_id") == command &&
    handoff_text(source, "turn_id") == turn &&
    handoff_text(source, "item_id") == item
  })
  if matches.length() == 1 {
    Some({ "binding": binding, "source": matches[0] })
  } else {
    None
  }
}

///|
fn render_work_learning_action(
  dispatch : Dispatch[Msg],
  model : Model,
  row : MoonCodeTranscriptRow,
) -> @rabbita.Html {
  if row.role != "assistant" || row.status != "done" {
    return @html.nothing
  }
  let sources = work_learning_sources(model).filter(source => {
    handoff_text(source, "command_id") == row.command_id &&
    handoff_text(source, "item_id") == row.item_id &&
    handoff_text(source, "client_turn_id") == row.client_turn_id &&
    handoff_text(source, "content").trim().to_owned() == row.content
  })
  guard sources.length() == 1 else { return @html.nothing }
  let source = sources[0]
  button(
    attrs=@html.Attrs::build().aria_label(
      "Teach this book from command " + row.command_id,
    ),
    on_click=dispatch(
      WorkHandoff(
        TeachLearning(
          model.work_handoff.generation,
          handoff_text(source, "command_id"),
          handoff_text(source, "turn_id"),
          handoff_text(source, "item_id"),
        ),
      ),
    ),
    "Teach this book",
  )
}
