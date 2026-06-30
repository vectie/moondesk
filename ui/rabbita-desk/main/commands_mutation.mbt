///|
fn save_inbox_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  title : String,
  content : String,
) -> @rabbita.Cmd {
  let body : Json = if model.editing_inbox_path == "" {
    { "title": title, "content": content }
  } else {
    { "title": title, "content": content, "path": model.editing_inbox_path }
  }
  @http.post("/api/workspaces/\{model.selected_workspace_id}/inbox")
  .with_json(body)
  .expect_json(result => {
    dispatch(SavedInbox(http_result(result, "Could not save inbox note")))
  })
}

///|
fn save_markdown_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let body : Json = {
    "path": model.markdown_editor_path,
    "content": model.markdown_editor_content,
  }
  @http.post("/api/workspaces/\{model.selected_workspace_id}/markdown")
  .with_json(body)
  .expect_json(result => {
    dispatch(
      SavedMarkdownEdit(
        http_result(result, "Could not save markdown document"),
      ),
    )
  })
}

///|
fn import_url_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let url = model.import_url.trim().to_owned()
  let title = if url == "" { "Imported URL" } else { url }
  let body : Json = {
    "kind": "url",
    "title": title,
    "url": url,
    "note": model.import_note,
  }
  @http.post("/api/workspaces/\{model.selected_workspace_id}/import")
  .with_json(body)
  .expect_json(result => {
    dispatch(ImportedInbox(http_result(result, "Could not import URL")))
  })
}

///|
fn import_local_file_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
  file : LocalImportFile,
) -> @rabbita.Cmd {
  let is_data_url = file.content.has_prefix("data:")
  let body : Json = {
    "kind": if file.source == "paste" {
      "paste"
    } else {
      "file"
    },
    "title": file.name,
    "filename": file.name,
    "browser_import_id": file.id,
    "content_type": file.media_type,
    "note": model.import_note,
    "content": if is_data_url {
      ""
    } else {
      file.content
    },
    "data_url": if is_data_url {
      file.content
    } else {
      ""
    },
  }
  @http.post("/api/workspaces/\{model.selected_workspace_id}/import")
  .with_json(body)
  .expect_json(result => {
    dispatch(ImportedInbox(http_result(result, "Could not import local file")))
  })
}

///|
fn save_view_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let body : Json = {
    "title": trimmed_or(model.view_title, "Current view"),
    "query": model.search_query,
    "workspace_id": model.selected_workspace_id,
    "path": model.selected_path,
  }
  @http.post("/api/preferences/views")
  .with_json(body)
  .expect_json(result => {
    dispatch(SavedView(http_result(result, "Could not save view")))
  })
}

///|
fn submit_request_cmd(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Cmd {
  let title = "Moondesk request for \{workspace_name(model)}"
  let context_entries = if model.selected_path == "" {
    []
  } else {
    [model.selected_path]
  }
  let body : Json = {
    "title": title,
    "prompt": trimmed_or(model.request_prompt, "Review the selected context."),
    "target_book_id": model.selected_workspace_id,
    "context_entries": json_string_array(context_entries),
    "cadence": "one-shot",
    "review_policy": "bookkeeper_review",
    "source_policy": "mixed",
  }
  @http.post("/api/town/requests")
  .with_json(body)
  .expect_json(result => {
    dispatch(SubmittedRequest(http_result(result, "Could not stage request")))
  })
}

///|
fn create_standing_goal_cmd(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Cmd {
  let title = trimmed_or(model.goal_title, "Standing watch")
  let cadence = clamp_int(int_text(model.goal_cadence_ticks, 60), 1, 525600)
  let body : Json = {
    "title": title,
    "prompt": trimmed_or(
      model.request_prompt,
      "Watch the selected MoonBook context for useful updates.",
    ),
    "target_book_id": model.selected_workspace_id,
    "cadence_ticks": cadence,
    "source_policy": trimmed_or(model.goal_source_policy, "web-first"),
    "review_policy": trimmed_or(model.goal_review_policy, "bookkeeper_review"),
    "enabled": true,
  }
  @http.post("/api/town/standing-goals")
  .with_json(body)
  .expect_json(result => {
    dispatch(
      CreatedStandingGoal(
        http_result(result, "Could not create standing watch"),
      ),
    )
  })
}
