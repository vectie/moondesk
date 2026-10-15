///|
fn update_workspace_features(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  guard msg is WorkspaceFeature(action, first, second, third, fourth) else {
    return (@rabbita.none, model)
  }
  match action {
    "open-search" | "open-synthesis" =>
      (
        workspace_feature_signal_cmd(action, first),
        { ..model, command_open: false, },
      )
    "open-toolbox" =>
      (
        @rabbita.batch([
          workspace_feature_signal_cmd("open-toolbox", first),
          if first == "threads" {
            fetch_mooncode_sessions_cmd(dispatch, model.selected_workspace_id)
          } else {
            @rabbita.none
          },
        ]),
        { ..model, command_open: false, },
      )
    "draft-task" => {
      if second == "code" &&
        (model.git_review_saving || model.git_review_note.trim() != "") {
        return update_mooncode_actions(dispatch, NewMoonCodeSession, model)
      }
      let (cmd, opened) = select_workspace_mode_action(
        dispatch,
        if second == "code" {
          MoonCode
        } else {
          MoonWiki
        },
        model,
      )
      if second == "code" {
        let (fresh_cmd, fresh) = update_mooncode_actions(
          dispatch,
          NewMoonCodeSession,
          opened,
        )
        (
          @rabbita.batch([
            cmd,
            fresh_cmd,
            workspace_feature_signal_cmd("code-task-draft", first),
          ]),
          { ..fresh, mooncode_prompt: first, command_open: false, },
        )
      } else {
        (
          cmd,
          {
            ..opened,
            request_prompt: first,
            request_status: "draft",
            work_title: third,
            wiki_agent_task_id: "",
            wiki_chat_entries: [],
            command_open: false,
          },
        )
      }
    }
    "return-work" => update_navigation_actions(dispatch, ReturnToWork, model)
    "resume-code-task" => {
      let (mode_cmd, opened) = select_workspace_mode_action(
        dispatch,
        MoonCode,
        model,
      )
      let (session_cmd, ready) = update_mooncode_actions(
        dispatch,
        SelectMoonCodeSession(first),
        opened,
      )
      (
        @rabbita.batch([
          mode_cmd,
          session_cmd,
          if second == "" {
            @rabbita.none
          } else {
            workspace_feature_signal_cmd("code-add-context", second)
          },
        ]),
        ready,
      )
    }
    "open-book-work" => select_workspace_mode_action(dispatch, MoonWiki, model)
    "open-work-file" =>
      update_navigation_actions(dispatch, OpenWorkFile(first), model)
    "open-task-output" => {
      if markdown_navigation_needs_confirmation(model, true) {
        return (@rabbita.none, model)
      }
      let (mode_cmd, opened) = select_workspace_mode_action(
        dispatch,
        MoonWiki,
        model,
      )
      let (path_cmd, ready) = open_quick_path_action(dispatch, first, opened)
      (
        @rabbita.batch([mode_cmd, path_cmd]),
        { ..ready, work_return: Some(work_location(model)), },
      )
    }
    "revise-result" | "schedule-result" => {
      let (cmd, opened) = select_workspace_mode_action(
        dispatch,
        MoonWiki,
        model,
      )
      let prompt = if action == "revise-result" {
        "Revise " + second + ".\n\nChanges I want: "
      } else {
        "Make this work recurring: " +
        second +
        ".\n\nSchedule: \nKeep future outputs with this task and show me the proposed schedule before enabling it."
      }
      (
        cmd,
        {
          ..opened,
          request_prompt: prompt,
          request_status: "draft",
          work_title: second,
          wiki_chat_file_paths: if first == "" {
            opened.wiki_chat_file_paths
          } else {
            add_request_material(opened.wiki_chat_file_paths, first)
          },
        },
      )
    }
    "open-flow-files" =>
      (
        workspace_feature_signal_cmd("open-search", "workflow"),
        { ..model, command_open: false, },
      )
    "open-recipe" => {
      let (select_cmd, selected) = select_workspace_action(
        dispatch, first, model,
      )
      (
        @rabbita.batch([
          select_cmd,
          workspace_feature_signal_cmd("open-recipe", ""),
        ]),
        { ..selected, command_open: false, },
      )
    }
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
    "attach-captured" => {
      let with_note = add_request_material(model.request_material_paths, first)
      let paths = if second == "" {
        with_note
      } else {
        add_request_material(with_note, second)
      }
      (
        @rabbita.none,
        {
          ..model,
          request_material_paths: paths,
          request_material_status: "captured media added",
        },
      )
    }
    "import-folder" =>
      update_workspace_surface_actions(dispatch, ImportLocalFolderToDesk, model)
    "export" =>
      (
        workspace_feature_signal_cmd("export", ""),
        { ..model, command_open: false, },
      )
    "start-synthesis" =>
      start_synthesis_action(dispatch, model, first, second, third)
    "ask-selection" => {
      let staged = { ..model, request_prompt: first, request_status: "draft", }
      if second == "send" {
        update_wiki_chat(dispatch, SubmitWikiChat, staged)
      } else {
        (@rabbita.none, staged)
      }
    }
    "set-chat-prompt" =>
      (
        @rabbita.none,
        { ..model, request_prompt: first, request_status: "draft", },
      )
    "submit-chat-prompt" => {
      let staged = { ..model, request_prompt: first, request_status: "draft", }
      update_wiki_chat(dispatch, SubmitWikiChat, staged)
    }
    "start-recipe" => {
      let staged = {
        ..model,
        request_prompt: first,
        request_status: "draft",
        work_title: third,
        wiki_agent_task_id: "",
        wiki_chat_entries: [],
      }
      let (mode_cmd, in_wiki) = select_workspace_mode_action(
        dispatch,
        MoonWiki,
        staged,
      )
      let (chat_cmd, chatting) = update_wiki_chat(
        dispatch,
        SubmitWikiChat,
        in_wiki,
      )
      (@rabbita.batch([mode_cmd, chat_cmd]), chatting)
    }
    "try-another" => {
      let fresh = {
        ..model,
        wiki_agent_task_id: "",
        wiki_chat_entries: [],
        wiki_chat_stream_task_id: "",
        wiki_chat_stream_cursor: "start",
        request_prompt: alternative_version_prompt(first),
        request_status: "draft",
      }
      update_wiki_chat(dispatch, SubmitWikiChat, fresh)
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
      restore_wiki_chat_thread(
        dispatch,
        model,
        first,
        second,
        third,
        position_text=fourth,
      )
    "new-thread" =>
      (
        @rabbita.none,
        {
          ..model,
          wiki_agent_task_id: "",
          work_title: "",
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
        reveal_selection_cmd(dispatch, { ..model, selected_path: "inbox", }),
        { ..model, dispatch_status: "opening MoonDesk Inbox", },
      )
    "run-goal" => run_standing_goal_now(dispatch, model, first)
    _ => (@rabbita.none, model)
  }
}

///|
const AlternativeVersionContextMaxChars : Int = 48_000

///|
fn alternative_version_prompt(previous : String) -> String {
  let bounded = if previous.length() > AlternativeVersionContextMaxChars {
    previous[:AlternativeVersionContextMaxChars].to_owned()
  } else {
    previous
  }
  "Create a genuinely different version for the same selected document and goal. Preserve supported facts and source references, but change the structure or approach where that improves the result. Keep proposed document edits reviewable before saving.\n\nPrevious version:\n" +
  bounded
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
      entries.push({ role: "background_result", content, })
    }
  }
  (@rabbita.none, { ..model, wiki_chat_entries: entries, })
}

///|
fn restore_wiki_chat_thread(
  dispatch : Dispatch[Msg],
  model : Model,
  task_id : String,
  document_path : String,
  entries_text : String,
  position_text? : String = "",
) -> (@rabbita.Cmd, Model) {
  if markdown_navigation_needs_confirmation(model, true) {
    return queue_markdown_navigation(
      model,
      PendingWorkThread(task_id, document_path, entries_text, position_text),
    )
  }
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
  let position = @json.parse(position_text) catch { _ => Json::object({}) }
  let files = json_field_string_array_items(position, "files")
  let context : Array[WikiChatContextItem] = @json.from_json(
    Json::array(json_field_json_array_items(position, "context")),
  ) catch {
    _ => []
  }
  let materials = json_field_string_array_items(position, "materials")
  let status = json_field_string(position, "status", default="ready")
  let resume_stream = task_id != "" &&
    ["sending", "working", "generating", "queued"].any(word => {
      status.to_lower().contains(word)
    })
  let cursor = json_field_string(position, "cursor", default="start")
  let restored = {
    ..model,
    work_title: json_field_string(position, "title", default=""),
    selected_path: document_path,
    wiki_agent_task_id: task_id,
    wiki_chat_entries: entries,
    wiki_chat_file_paths: files,
    wiki_chat_context_items: context,
    request_material_paths: materials,
    wiki_chat_stream_task_id: if resume_stream {
      task_id
    } else {
      ""
    },
    wiki_chat_stream_cursor: cursor,
    request_prompt: json_field_string(position, "prompt", default=""),
    request_status: status,
  }
  let (mode_cmd, opened) = select_workspace_mode_action(
    dispatch,
    MoonWiki,
    restored,
  )
  let (file_cmd, ready) = if document_path != "" {
    open_quick_path_action(dispatch, document_path, opened)
  } else {
    (@rabbita.none, { ..opened, primary_preview_path: "", })
  }
  (
    @rabbita.batch([
      mode_cmd,
      file_cmd,
      if resume_stream {
        start_wiki_chat_stream_cmd(dispatch, task_id, cursor)
      } else {
        @rabbita.none
      },
    ]),
    {
      ..ready,
      current_directory: json_field_string(
        position,
        "directory",
        default=ready.current_directory,
      ),
      desk_filter_query: json_field_string(position, "filter", default=""),
    },
  )
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
        { ..model, request_status: "That context item is invalid", },
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
      { ..model, request_status: "That context item is invalid", },
    )
  }
  let items = model.wiki_chat_context_items.filter(existing => {
    existing.id != item.id
  })
  if items.length() >= 12 {
    return (
      @rabbita.none,
      {
        ..model,
        request_status: "Remove a context item before adding another",
      },
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
  if purpose != "attach" &&
    markdown_navigation_needs_confirmation(
      model,
      workspace_id != model.selected_workspace_id ||
      path != model.markdown_editor_path,
    ) {
    return queue_markdown_navigation(
      model,
      PendingWorkSearch(workspace_id, path),
    )
  }
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
    let (book_cmd, selected) = select_workspace_action(
      dispatch, workspace_id, model,
    )
    if selected.selected_workspace_id != workspace_id {
      (book_cmd, selected)
    } else {
      let (open_cmd, opened) = update_navigation_actions(
        dispatch,
        OpenWorkFile(path),
        selected,
      )
      (@rabbita.batch([book_cmd, open_cmd]), opened)
    }
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
  } else if purpose == "attach" {
    update_wiki_chat(dispatch, AttachWikiChatFile(path), model)
  } else {
    update_navigation_actions(dispatch, OpenWorkFile(path), model)
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
      { ..model, dispatch_status: "Automation is no longer available", },
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
    kind=AfterRender,
  )
}
