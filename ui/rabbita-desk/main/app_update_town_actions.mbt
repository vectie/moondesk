///|
fn update_town_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SetRequestPrompt(prompt) =>
      (
        @rabbita.none,
        { ..model, request_prompt: prompt, request_status: "draft" },
      )
    RemoveRequestMaterial(path) =>
      (
        @rabbita.none,
        {
          ..model,
          request_material_paths: remove_request_material(
            model.request_material_paths,
            path,
          ),
          request_material_status: "material removed",
        },
      )
    SubmitRequest =>
      if model.selected_workspace_id == "" {
        (@rabbita.none, { ..model, request_status: "select a book first" })
      } else if model.request_prompt.trim().is_empty() {
        (
          @rabbita.none,
          { ..model, request_status: "describe what this book should build" },
        )
      } else {
        (
          sync_activity_batch(Town, submit_request_cmd(dispatch, model)),
          {
            ..model,
            activity: Town,
            command_open: false,
            request_status: "staging request",
          },
        )
      }
    _ => (@rabbita.none, model)
  }
}

///|
fn add_request_material(paths : Array[String], path : String) -> Array[String] {
  let trimmed = path.trim().to_owned()
  if trimmed == "" || has_string(paths, trimmed) {
    paths
  } else {
    let next : Array[String] = []
    for item in paths {
      next.push(item)
    }
    next.push(trimmed)
    next
  }
}

///|
fn remove_request_material(
  paths : Array[String],
  path : String,
) -> Array[String] {
  paths.filter(item => item != path)
}

///|
fn request_context_entries(model : Model) -> Array[String] {
  let entries : Array[String] = []
  match model.preview {
    Some(_) if model.selected_path != "" => entries.push(model.selected_path)
    _ => ()
  }
  for path in model.request_material_paths {
    if path != "" && !has_string(entries, path) {
      entries.push(path)
    }
  }
  entries
}

///|
fn request_material_count_label(model : Model) -> String {
  let count = request_context_entries(model).length()
  if count == 0 {
    "No materials"
  } else if count == 1 {
    "1 material"
  } else {
    "\{count} materials"
  }
}
