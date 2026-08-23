///|
fn wiki_chat_append(
  entries : Array[WikiChatEntry],
  role : String,
  content : String,
) -> Array[WikiChatEntry] {
  let next = entries.copy()
  next.push({ role, content })
  next
}

///|
fn wiki_chat_path_is_attachable(path : String) -> Bool {
  let value = path.trim()
  if value == "" ||
    value.has_prefix("~") ||
    value.has_prefix("file:") ||
    value.contains("://") ||
    source_pane_path_is_unsafe(value.to_owned()) {
    return false
  }
  true
}

///|
fn wiki_chat_attach_file(model : Model, path : String) -> Model {
  let value = path.trim().to_owned()
  if !wiki_chat_path_is_attachable(value) {
    return { ..model, request_status: "Choose a file from this workspace" }
  }
  if model.wiki_chat_file_paths.contains(value) {
    {
      ..model,
      wiki_chat_file_picker_open: false,
      wiki_chat_file_query: "",
      wiki_chat_file_results: [],
      wiki_chat_file_search_status: "",
      request_status: "File already attached",
    }
  } else {
    let paths = model.wiki_chat_file_paths.copy()
    paths.push(value)
    let prompt = match ComposerTrigger::parse(model.request_prompt) {
      Some(trigger) => trigger.draft_without_token.trim_end().to_owned()
      None => model.request_prompt
    }
    {
      ..model,
      request_prompt: prompt,
      wiki_chat_file_paths: paths,
      wiki_chat_file_picker_open: false,
      wiki_chat_file_query: "",
      wiki_chat_file_results: [],
      wiki_chat_file_search_status: "",
      request_status: "File attached",
    }
  }
}

///|
fn wiki_chat_search_results(
  model : Model,
  response : PagesSearchResponse,
) -> Array[SearchHit] {
  let results : Array[SearchHit] = []
  for hit in response.hits {
    if hit.workspace_id == model.selected_workspace_id &&
      wiki_chat_path_is_attachable(hit.path) &&
      !results.any(item => item.path == hit.path) {
      results.push(hit)
      if results.length() >= WikiChatFileSearchLimit {
        break
      }
    }
  }
  results
}

///|
fn wiki_chat_prompt_update(
  dispatch : Dispatch[Msg],
  model : Model,
  prompt : String,
) -> (@rabbita.Cmd, Model) {
  let generation = model.wiki_chat_file_search_generation + 1
  match ComposerTrigger::parse(prompt) {
    Some(trigger) => {
      let query = trigger.query.trim().to_owned()
      let command = if query == "" {
        @rabbita.none
      } else {
        @rabbita.delay(
          dispatch(RunWikiChatFileSearch(generation, query)),
          WikiChatFileSearchDebounceMs,
        )
      }
      (
        command,
        {
          ..model,
          request_prompt: prompt,
          request_status: "draft",
          wiki_chat_file_picker_open: true,
          wiki_chat_file_query: query,
          wiki_chat_file_results: [],
          wiki_chat_file_search_status: if trigger.query.trim() == "" {
            "Search this workspace by typing after @"
          } else {
            "Searching workspace…"
          },
          wiki_chat_file_search_generation: generation,
        },
      )
    }
    None =>
      (
        @rabbita.none,
        {
          ..model,
          request_prompt: prompt,
          request_status: "draft",
          wiki_chat_file_picker_open: false,
          wiki_chat_file_query: "",
          wiki_chat_file_results: [],
          wiki_chat_file_search_status: "",
          wiki_chat_file_search_generation: generation,
        },
      )
  }
}

///|
fn wiki_chat_file_query_update(
  dispatch : Dispatch[Msg],
  model : Model,
  query : String,
) -> (@rabbita.Cmd, Model) {
  let generation = model.wiki_chat_file_search_generation + 1
  let value = query.trim().to_owned()
  let command = if value == "" {
    @rabbita.none
  } else {
    @rabbita.delay(
      dispatch(RunWikiChatFileSearch(generation, value)),
      WikiChatFileSearchDebounceMs,
    )
  }
  (
    command,
    {
      ..model,
      wiki_chat_file_picker_open: true,
      wiki_chat_file_query: query,
      wiki_chat_file_results: [],
      wiki_chat_file_search_status: if value == "" {
        "Search this workspace by typing a file name"
      } else {
        "Searching workspace…"
      },
      wiki_chat_file_search_generation: generation,
    },
  )
}

///|
fn wiki_chat_apply_stream_event(model : Model, event : Json) -> (Model, Bool) {
  if json_field_string(event, "contract", default="") !=
    "moonclaw-task-stream.v2" {
    return (model, false)
  }
  let kind = json_field_string(event, "kind", default="")
  let mut next = model
  let mut terminal = false
  match kind {
    "lifecycle" =>
      next = { ..next, request_status: "working" }
    "answer_delta" => {
      let content = json_field_string(event, "content", default="")
      if content != "" {
        let entries = next.wiki_chat_entries.copy()
        if entries.length() > 0 &&
          entries[entries.length() - 1].role == "assistant-stream" {
          let index = entries.length() - 1
          entries[index] = {
            role: "assistant-stream",
            content: entries[index].content + content,
          }
        } else {
          entries.push({ role: "assistant-stream", content })
        }
        next = { ..next, wiki_chat_entries: entries, request_status: "working" }
      }
    }
    "answer" => {
      let content = json_field_string(event, "content", default="")
        .trim()
        .to_owned()
      let entries = next.wiki_chat_entries.copy()
      if entries.length() > 0 &&
        entries[entries.length() - 1].role == "assistant-stream" {
        let index = entries.length() - 1
        entries[index] = {
          role: "assistant",
          content: if content == "" {
            entries[index].content
          } else {
            content
          },
        }
      } else if content != "" {
        entries.push({ role: "assistant", content })
      }
      next = { ..next, wiki_chat_entries: entries }
    }
    "snapshot" => {
      let content = json_field_string(event, "answer", default="")
        .trim()
        .to_owned()
      let entries = next.wiki_chat_entries.copy()
      if content != "" {
        if entries.length() > 0 &&
          (entries[entries.length() - 1].role == "assistant-stream" ||
          entries[entries.length() - 1].role == "assistant") {
          entries[entries.length() - 1] = { role: "assistant", content }
        } else {
          entries.push({ role: "assistant", content })
        }
      }
      let state = json_field_string(event, "state", default="working")
      next = { ..next, wiki_chat_entries: entries, request_status: state }
      terminal = state == "complete" || state == "cancelled" || state == "failed"
    }
    "warning" => {
      let entries = next.wiki_chat_entries.copy()
      entries.push({
        role: "assistant",
        content: json_field_string(
          event,
          "message",
          default="I couldn't complete that request.",
        ),
      })
      next = {
        ..next,
        wiki_chat_entries: entries,
        request_status: "The document assistant could not complete the request",
      }
      terminal = true
    }
    "terminal" => {
      let state = json_field_string(event, "state", default="complete")
      next = { ..next, request_status: state }
      terminal = true
    }
    _ => ()
  }
  (next, terminal)
}

///|
fn update_wiki_chat(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    ToggleWikiChatFilePicker =>
      if model.wiki_chat_file_picker_open {
        (
          @rabbita.none,
          {
            ..model,
            wiki_chat_file_picker_open: false,
            wiki_chat_file_query: "",
            wiki_chat_file_results: [],
            wiki_chat_file_search_status: "",
            wiki_chat_file_search_generation: model.wiki_chat_file_search_generation +
            1,
          },
        )
      } else {
        (
          @rabbita.none,
          {
            ..model,
            wiki_chat_file_picker_open: true,
            wiki_chat_file_query: "",
            wiki_chat_file_results: [],
            wiki_chat_file_search_status: "Search this workspace by typing a file name",
            wiki_chat_file_search_generation: model.wiki_chat_file_search_generation +
            1,
          },
        )
      }
    SetWikiChatPrompt(prompt) =>
      wiki_chat_prompt_update(dispatch, model, prompt)
    SetWikiChatFileQuery(query) =>
      wiki_chat_file_query_update(dispatch, model, query)
    RunWikiChatFileSearch(generation, query) =>
      if generation != model.wiki_chat_file_search_generation ||
        query.trim() != model.wiki_chat_file_query.trim() ||
        query.trim() == "" {
        (@rabbita.none, model)
      } else {
        (wiki_chat_file_search_cmd(dispatch, generation, query), model)
      }
    LoadedWikiChatFileSearch(generation, Ok(response)) =>
      if generation != model.wiki_chat_file_search_generation {
        (@rabbita.none, model)
      } else if !response.ok {
        (
          @rabbita.none,
          {
            ..model,
            wiki_chat_file_results: [],
            wiki_chat_file_search_status: if response.message.trim() == "" {
              "Workspace search is unavailable"
            } else {
              response.message
            },
          },
        )
      } else {
        let results = wiki_chat_search_results(model, response)
        (
          @rabbita.none,
          {
            ..model,
            wiki_chat_file_results: results,
            wiki_chat_file_search_status: wiki_chat_file_search_status_for_count(
              results.length(),
            ),
          },
        )
      }
    LoadedWikiChatFileSearch(generation, Err(error)) =>
      if generation != model.wiki_chat_file_search_generation {
        (@rabbita.none, model)
      } else {
        (
          @rabbita.none,
          {
            ..model,
            wiki_chat_file_results: [],
            wiki_chat_file_search_status: error,
          },
        )
      }
    AttachWikiChatFile(path) =>
      (@rabbita.none, wiki_chat_attach_file(model, path))
    WikiChatDropPath(path) =>
      (@rabbita.none, wiki_chat_attach_file(model, path))
    RemoveWikiChatFile(path) =>
      (
        @rabbita.none,
        {
          ..model,
          wiki_chat_file_paths: model.wiki_chat_file_paths.filter(item => {
            item != path
          }),
          request_status: "File detached",
        },
      )
    SubmitWikiChat =>
      if model.selected_workspace_id == "" {
        (@rabbita.none, { ..model, request_status: "Choose a MoonBook first" })
      } else if model.request_prompt.trim().is_empty() {
        (@rabbita.none, { ..model, request_status: "Write a message first" })
      } else {
        (
          submit_wiki_chat_cmd(dispatch, model),
          { ..model, request_status: "sending" },
        )
      }
    SubmittedWikiChat(submitted_message, Ok(submission)) =>
      if submission.owner != "moonclaw-general-agent" {
        (
          @rabbita.none,
          {
            ..model,
            request_status: "The document assistant returned an invalid response",
          },
        )
      } else {
        let stream_cursor = if model.wiki_agent_task_id == submission.task_id {
          model.wiki_chat_stream_cursor
        } else {
          "start"
        }
        let next = {
          ..model,
          wiki_agent_task_id: submission.task_id,
          wiki_chat_stream_task_id: submission.task_id,
          wiki_chat_stream_cursor: stream_cursor,
          wiki_chat_entries: wiki_chat_append(
            model.wiki_chat_entries,
            "user",
            submitted_message,
          ),
          request_prompt: "",
          request_status: if submission.queued {
            "queued"
          } else {
            "working"
          },
        }
        (
          start_wiki_chat_stream_cmd(
            dispatch,
            submission.task_id,
            stream_cursor,
          ),
          next,
        )
      }
    SubmittedWikiChat(_, Err(error)) =>
      (
        stop_wiki_chat_stream_cmd(),
        { ..model, wiki_chat_stream_task_id: "", request_status: error },
      )
    PollWikiChatStream(task_id) =>
      if model.wiki_chat_stream_task_id == task_id {
        (poll_wiki_chat_stream_cmd(dispatch, task_id), model)
      } else {
        (@rabbita.none, model)
      }
    LoadedWikiChatEvents(task_id, cursor, Ok(events)) =>
      if model.wiki_chat_stream_task_id != task_id {
        (@rabbita.none, model)
      } else {
        let mut next = { ..model, wiki_chat_stream_cursor: cursor }
        let mut terminal = false
        for event in events {
          let (updated, done) = wiki_chat_apply_stream_event(next, event)
          next = updated
          terminal = terminal || done
        }
        if terminal {
          (
            stop_wiki_chat_stream_cmd(),
            { ..next, wiki_chat_stream_task_id: "" },
          )
        } else {
          (
            @rabbita.delay(
              dispatch(PollWikiChatStream(task_id)),
              WikiChatStreamPollDelayMs,
            ),
            next,
          )
        }
      }
    LoadedWikiChatEvents(task_id, cursor, Err(error)) =>
      if model.wiki_chat_stream_task_id == task_id {
        (
          stop_wiki_chat_stream_cmd(),
          {
            ..model,
            wiki_chat_stream_task_id: "",
            wiki_chat_stream_cursor: cursor,
            request_status: error,
          },
        )
      } else {
        (@rabbita.none, model)
      }
    _ => (@rabbita.none, model)
  }
}
