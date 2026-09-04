///|
fn update_workspace_features(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  guard msg is WorkspaceFeature(action, first, second, third, _fourth) else {
    return (@rabbita.none, model)
  }
  match action {
    "open-search" | "open-synthesis" =>
      (
        workspace_feature_signal_cmd(action, first),
        { ..model, command_open: false },
      )
    "open-toolbox" =>
      (
        workspace_feature_signal_cmd("open-toolbox", first),
        { ..model, command_open: false },
      )
    "query" =>
      update_workspace_surface_actions(dispatch, SetSearchQuery(first), model)
    "search" =>
      search_now_action(
        dispatch,
        model,
        mode=first,
        scope_workspace=second == "document" || second == "attach",
      )
    "choose" =>
      choose_universal_search_result(dispatch, model, first, second, third)
    "open-path" => open_universal_path(dispatch, model, first, second)
    "desk-intake" => select_workspace_mode_action(dispatch, Desk, model)
    "destination" => {
      let mode = match first {
        "requests" => RequestsWorkspace
        "review" => ReviewWorkspace
        _ => RunsWorkspace
      }
      select_workspace_mode_action(dispatch, mode, model)
    }
    "import-files" => update_inbox_actions(dispatch, ImportLocalFiles, model)
    "import-folder" =>
      update_workspace_surface_actions(dispatch, ImportLocalFolderToDesk, model)
    "export" =>
      (
        workspace_feature_signal_cmd("export", ""),
        { ..model, command_open: false },
      )
    "start-synthesis" =>
      start_synthesis_action(dispatch, model, first, second, third)
    "ask-selection" => {
      let staged = { ..model, request_prompt: first, request_status: "draft" }
      if second == "send" {
        update_wiki_chat(dispatch, SubmitWikiChat, staged)
      } else {
        (@rabbita.none, staged)
      }
    }
    "set-chat-prompt" =>
      (
        @rabbita.none,
        { ..model, request_prompt: first, request_status: "draft" },
      )
    "submit-chat-prompt" => {
      let staged = { ..model, request_prompt: first, request_status: "draft" }
      update_wiki_chat(dispatch, SubmitWikiChat, staged)
    }
    "add-context" =>
      add_wiki_chat_context(dispatch, model, first, second, third)
    "remove-context" =>
      (
        @rabbita.none,
        {
          ..model,
          wiki_chat_context_items: model.wiki_chat_context_items.filter(item => {
            item.id != first
          }),
        },
      )
    "append-background-results" =>
      append_wiki_chat_background_results(model, first)
    "restore-thread" =>
      restore_wiki_chat_thread(dispatch, model, first, second, third)
    "new-thread" =>
      (
        @rabbita.none,
        {
          ..model,
          wiki_agent_task_id: "",
          wiki_chat_entries: [],
          wiki_chat_file_paths: [],
          wiki_chat_context_items: [],
          wiki_chat_stream_task_id: "",
          wiki_chat_stream_cursor: "start",
          request_prompt: "",
          request_status: "draft",
        },
      )
    "reveal-inbox" =>
      (
        reveal_selection_cmd(dispatch, { ..model, selected_path: "inbox" }),
        { ..model, dispatch_status: "opening MoonDesk Inbox" },
      )
    "run-goal" => run_standing_goal_now(dispatch, model, first)
    _ => (@rabbita.none, model)
  }
}

///|
fn append_wiki_chat_background_results(
  model : Model,
  payload_text : String,
) -> (@rabbita.Cmd, Model) {
  let payload = @json.parse(payload_text) catch {
    _ => return (@rabbita.none, model)
  }
  guard payload is Array(values) else { return (@rabbita.none, model) }
  let entries = model.wiki_chat_entries.copy()
  for value in values {
    if json_field_string(value, "contract", default="") !=
      "moondesk.document_automation_result.v1" ||
      json_field_string(value, "kind", default="") != "background_result" ||
      json_field_string(value, "id", default="") == "" {
      continue
    }
    let content = value.stringify()
    if !entries.any(entry => {
        entry.role == "background_result" && entry.content == content
      }) {
      entries.push({ role: "background_result", content })
    }
  }
  (@rabbita.none, { ..model, wiki_chat_entries: entries })
}

///|
fn restore_wiki_chat_thread(
  dispatch : Dispatch[Msg],
  model : Model,
  task_id : String,
  document_path : String,
  entries_text : String,
) -> (@rabbita.Cmd, Model) {
  let entries : Array[WikiChatEntry] = @json.from_json(
    @json.parse(entries_text),
  ) catch {
    _ =>
      return (
        @rabbita.none,
        {
          ..model,
          request_status: "That saved conversation could not be restored",
        },
      )
  }
  let restored = {
    ..model,
    selected_path: if document_path == "" {
      model.selected_path
    } else {
      document_path
    },
    wiki_agent_task_id: task_id,
    wiki_chat_entries: entries,
    wiki_chat_file_paths: [],
    wiki_chat_context_items: [],
    wiki_chat_stream_task_id: "",
    wiki_chat_stream_cursor: "start",
    request_prompt: "",
    request_status: "ready",
  }
  if document_path != "" && office_editor_path_supported(document_path) {
    open_quick_path_action(dispatch, document_path, restored)
  } else {
    (@rabbita.none, restored)
  }
}

///|
fn add_wiki_chat_context(
  dispatch : Dispatch[Msg],
  model : Model,
  item_text : String,
  prompt : String,
  behavior : String,
) -> (@rabbita.Cmd, Model) {
  let item : WikiChatContextItem = @json.from_json(@json.parse(item_text)) catch {
    _ =>
      return (
        @rabbita.none,
        { ..model, request_status: "That context item is invalid" },
      )
  }
  if item.id.trim() == "" ||
    item.id.length() > 160 ||
    item.label.trim() == "" ||
    item.label.length() > 160 ||
    item.value.length() > 4_000 ||
    item.detail.length() > 24_000 ||
    !["selection", "conversation", "artifact", "inbox", "url"].contains(
      item.kind,
    ) {
    return (
      @rabbita.none,
      { ..model, request_status: "That context item is invalid" },
    )
  }
  let items = model.wiki_chat_context_items.filter(existing => {
    existing.id != item.id
  })
  if items.length() >= 12 {
    return (
      @rabbita.none,
      { ..model, request_status: "Remove a context item before adding another" },
    )
  }
  items.push(item)
  let staged = {
    ..model,
    wiki_chat_context_items: items,
    request_prompt: if prompt == "" {
      model.request_prompt
    } else {
      prompt
    },
    request_status: "draft",
  }
  if behavior == "send" {
    update_wiki_chat(dispatch, SubmitWikiChat, staged)
  } else {
    (@rabbita.none, staged)
  }
}

///|
fn choose_universal_search_result(
  dispatch : Dispatch[Msg],
  model : Model,
  workspace_id : String,
  path : String,
  purpose : String,
) -> (@rabbita.Cmd, Model) {
  if purpose == "attach" {
    if workspace_id != model.selected_workspace_id {
      (
        @rabbita.none,
        {
          ..model,
          pages_search: {
            ..model.pages_search,
            status: "Choose a file from the current book",
          },
        },
      )
    } else {
      update_wiki_chat(dispatch, AttachWikiChatFile(path), model)
    }
  } else {
    select_search_hit_action(dispatch, workspace_id, path, model)
  }
}

///|
fn open_universal_path(
  dispatch : Dispatch[Msg],
  model : Model,
  path : String,
  purpose : String,
) -> (@rabbita.Cmd, Model) {
  let path = path.trim().to_owned()
  if path == "" {
    (@rabbita.none, model)
  } else if source_pane_path_is_unsafe(path) {
    (
      @rabbita.none,
      {
        ..model,
        pages_search: {
          ..model.pages_search,
          status: "Use a safe workspace-relative path",
        },
      },
    )
  } else if purpose == "document" && !wiki_document_path_supported(path) {
    (
      @rabbita.none,
      {
        ..model,
        pages_search: {
          ..model.pages_search,
          status: "Choose a DOCX, XLSX, PPTX, or PDF document",
        },
      },
    )
  } else if purpose == "attach" {
    update_wiki_chat(dispatch, AttachWikiChatFile(path), model)
  } else {
    open_quick_path_action(dispatch, path, model)
  }
}

///|
fn start_synthesis_action(
  dispatch : Dispatch[Msg],
  model : Model,
  outcome : String,
  title : String,
  source_text : String,
) -> (@rabbita.Cmd, Model) {
  let paths : Array[String] = []
  let notes : Array[String] = []
  for source in source_text.split("\n") {
    let value = source.trim().to_owned()
    if value.has_prefix("note:") {
      let note = value["note:".length():].trim().to_owned()
      if note != "" {
        notes.push(note)
      }
    } else if value != "" {
      paths.push(value)
    }
  }
  if paths.is_empty() && notes.is_empty() {
    return (
      workspace_feature_signal_cmd(
        "synthesis-error", "Pin at least one source first",
      ),
      model,
    )
  }
  let prompt = "Create a " +
    outcome +
    " titled \"" +
    title.trim().to_owned() +
    "\" from these pinned sources: " +
    paths.map(path => "@" + path).join(" ") +
    (if notes.is_empty() {
      ""
    } else {
      "\nPinned conversation excerpts:\n" +
      notes.map(note => "- " + note).join("\n")
    }) +
    ". Preserve source links, distinguish facts from inference, validate the result, and report only actionable warnings."
  update_wiki_chat(dispatch, SubmitWikiChat, {
    ..model,
    request_prompt: prompt,
    wiki_chat_file_paths: paths,
  })
}

///|
fn run_standing_goal_now(
  dispatch : Dispatch[Msg],
  model : Model,
  goal_id : String,
) -> (@rabbita.Cmd, Model) {
  let mut prompt = ""
  for goal in model.standing_goals {
    if goal.id == goal_id {
      prompt = goal.prompt
      break
    }
  }
  if prompt == "" {
    return (
      @rabbita.none,
      { ..model, dispatch_status: "Automation is no longer available" },
    )
  }
  update_town_actions(dispatch, SubmitRequest, {
    ..model,
    request_prompt: prompt,
    request_status: "staging request",
  })
}

///|
#cfg(target="js")
extern "js" fn browser_workspace_feature_signal(
  action : String,
  value : String,
) =
  #| (action, value) => {
  #|   if (globalThis.__moondeskWorkspaceFeatureSignal) {
  #|     globalThis.__moondeskWorkspaceFeatureSignal(action, value);
  #|   } else {
  #|     (globalThis.__moondeskPendingWorkspaceFeatureSignals ||= []).push([action, value]);
  #|   }
  #| }

///|
fn workspace_feature_signal_cmd(
  action : String,
  value : String,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(
    _ => browser_workspace_feature_signal(action, value),
    kind=Immediately,
  )
}
