///|
fn specialist_library_scope(model : Model) -> String {
  [
    model.workspace_suite_root_path,
    model.workspace_books_root_path,
    model.workspace_library_path,
  ]
  .to_json()
  .stringify()
}

///|
priv struct SpecialistExampleBinding {
  request_id : String
  library_scope : String
  book_id : String
  version : String
  capabilities : Array[String]
  knowledge_paths : Array[String]
} derive(FromJson)

///|
fn specialist_knowledge_path_safe(path : String) -> Bool {
  (path.has_prefix("wiki/") || path.has_prefix("raw/")) &&
  path.length() <= 1024 &&
  !path.contains("\\") &&
  path.iter().all(ch => ch.to_int() >= 32 && ch.to_int() != 127) &&
  path.split("/").all(part => part != "" && part != "." && part != "..")
}

///|
fn specialist_preparation_reply(
  action : String,
  request_id : String,
  message : String,
) -> @rabbita.Cmd {
  let payload : Json = { "request_id": request_id, "message": message }
  workspace_feature_signal_cmd(action, payload.stringify())
}

///|
fn prepare_specialist_example(
  dispatch : Dispatch[Msg],
  model : Model,
  workspace_id : String,
  prompt : String,
  encoded_binding : String,
) -> (@rabbita.Cmd, Model) {
  let binding : SpecialistExampleBinding = @json.from_json(
    @json.parse(encoded_binding),
  ) catch {
    _ => return (@rabbita.none, model)
  }
  let reject = fn(message) {
    (
      specialist_preparation_reply(
        "specialist-error",
        binding.request_id,
        message,
      ),
      model,
    )
  }
  if binding.library_scope != specialist_library_scope(model) {
    return reject(
      "The Desk library changed. Reopen the specialist in its original library.",
    )
  }
  if prompt.trim().is_empty() ||
    prompt.length() > 48000 ||
    binding.request_id.is_empty() ||
    binding.knowledge_paths.length() > 20 ||
    !binding.knowledge_paths.all(specialist_knowledge_path_safe) {
    return reject(
      "This specialist has an invalid brief or knowledge reference.",
    )
  }
  if !model.agent_passports.any(agent => {
      agent.workspace_id == workspace_id &&
      agent.book_id == binding.book_id &&
      agent.version == binding.version &&
      agent.status == "ready" &&
      agent.source_kind == "moonbook" &&
      binding.capabilities.all(capability => {
        agent.capabilities.contains(capability)
      })
    }) {
    return reject(
      "The selected MoonBook changed or is unavailable. Refresh Pack Home and reselect it.",
    )
  }
  if model.request_status == "sending" ||
    model.request_status == "working" ||
    model.request_status == "queued" ||
    model.wiki_chat_stream_task_id != "" {
    return reject(
      "Wait for the current chat to finish before preparing a new example.",
    )
  }
  if !model.request_prompt.trim().is_empty() {
    return reject(
      "Send or clear your current chat draft before preparing this example.",
    )
  }
  if !model.mooncode_prompt.trim().is_empty() ||
    !model.mooncode_images.is_empty() ||
    model.mooncode_image_submit_pending ||
    model.mooncode_task_intent_submit_pending ||
    model.mooncode_guidance_pending_session_id != "" {
    return reject(
      "Finish sending or clear your Code chat draft before preparing this example.",
    )
  }
  if markdown_navigation_needs_confirmation(model, true) ||
    office_editor_dirty(model.office_editor) ||
    model.office_editor.saving ||
    source_pane_dirty(model.source_pane) ||
    model.git_review_saving {
    return reject(
      "Save or discard the current document edits before preparing this example.",
    )
  }
  if !model.git_review_note.trim().is_empty() {
    return reject(
      "Save or discard your current review note before preparing this example.",
    )
  }
  let (select_cmd, selected) = select_workspace_action(
    dispatch, workspace_id, model,
  )
  if selected.selected_workspace_id != workspace_id {
    return reject(
      "The selected Book could not be opened. Your current work is unchanged.",
    )
  }
  let staged = {
    ..selected,
    request_prompt: prompt,
    request_status: "Example prepared. Review it and click Send to try your specialist.",
    wiki_chat_file_paths: binding.knowledge_paths,
  }
  let (mode_cmd, in_wiki) = select_workspace_mode_action(
    dispatch,
    MoonWiki,
    staged,
  )
  (
    @rabbita.batch([
      select_cmd,
      mode_cmd,
      specialist_preparation_reply(
        "specialist-prepared",
        binding.request_id,
        "The exact example is prepared in chat; no trial has run yet.",
      ),
    ]),
    in_wiki,
  )
}
