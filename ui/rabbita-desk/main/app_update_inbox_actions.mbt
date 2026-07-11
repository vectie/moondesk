///|
fn update_inbox_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SetInboxTitle(title) => (@rabbita.none, { ..model, inbox_title: title })
    SetInboxContent(content) =>
      (
        @rabbita.none,
        { ..model, inbox_content: content, inbox_status: "draft" },
      )
    SetImportUrl(url) =>
      (
        @rabbita.none,
        if task_material_capture_active(model) {
          {
            ..model,
            import_url: url,
            request_material_status: "material draft",
          }
        } else {
          { ..model, import_url: url, inbox_status: "import draft" }
        },
      )
    SetImportNote(note) =>
      (
        @rabbita.none,
        if task_material_capture_active(model) {
          {
            ..model,
            import_note: note,
            request_material_status: "material draft",
          }
        } else {
          { ..model, import_note: note, inbox_status: "import draft" }
        },
      )
    ImportUrlToInbox =>
      if model.import_url.trim().to_owned() == "" {
        if task_material_capture_active(model) {
          (
            @rabbita.none,
            { ..model, request_material_status: "enter a link to add" },
          )
        } else {
          (@rabbita.none, { ..model, inbox_status: "enter a URL to import" })
        }
      } else if model.selected_workspace_id == "" {
        if task_material_capture_active(model) {
          (
            @rabbita.none,
            { ..model, request_material_status: "select a book first" },
          )
        } else {
          (@rabbita.none, { ..model, inbox_status: "select a book first" })
        }
      } else {
        (
          import_url_cmd(dispatch, model),
          if task_material_capture_active(model) {
            { ..model, request_material_status: "adding link" }
          } else {
            { ..model, inbox_status: "importing URL" }
          },
        )
      }
    ImportLocalFiles =>
      if model.selected_workspace_id == "" {
        if task_material_capture_active(model) {
          (
            @rabbita.none,
            { ..model, request_material_status: "select a book first" },
          )
        } else {
          (@rabbita.none, { ..model, inbox_status: "select a book first" })
        }
      } else {
        let target = if task_material_capture_active(model) {
          Town
        } else {
          Inbox
        }
        (
          sync_activity_batch(target, pick_import_files_cmd(dispatch)),
          if target is Town {
            {
              ..model,
              activity: Town,
              command_open: false,
              request_material_status: "opening file picker",
            }
          } else {
            {
              ..model,
              activity: Inbox,
              command_open: false,
              inbox_status: "opening file picker",
            }
          },
        )
      }
    PollDroppedImports =>
      (
        @rabbita.batch([
          take_dropped_imports_cmd(dispatch),
          schedule_import_drop_poll(dispatch),
        ]),
        model,
      )
    LoadSelectionIntoInbox => load_selection_into_inbox_action(model)
    SaveInboxNote => {
      let title = trimmed_or(model.inbox_title, "MoonDesk inbox note")
      let content = trimmed_or(model.inbox_content, "Empty operator note.")
      (
        save_inbox_cmd(dispatch, model, title, content),
        { ..model, inbox_status: "saving inbox note" },
      )
    }
    StageSelectedLink => stage_selected_link_action(dispatch, model)
    _ => (@rabbita.none, model)
  }
}

///|
fn task_material_capture_active(model : Model) -> Bool {
  model.workspace_mode == MoonWiki && model.activity == Town
}

///|
fn load_selection_into_inbox_action(model : Model) -> (@rabbita.Cmd, Model) {
  let content = match model.preview {
    Some(preview) if is_textual_renderer(preview.renderer) => preview.body
    _ => model.inbox_content
  }
  (
    sync_activity_cmd(Inbox),
    {
      ..model,
      activity: Inbox,
      command_open: false,
      inbox_title: @desk.display_name(model.selected_path),
      inbox_content: content,
      editing_inbox_path: if is_inbox_path(model.selected_path) {
        model.selected_path
      } else {
        ""
      },
      inbox_status: if is_inbox_path(model.selected_path) {
        "editing \{model.selected_path}"
      } else {
        "copied selected preview into a new inbox draft"
      },
    },
  )
}

///|
fn stage_selected_link_action(
  dispatch : Dispatch[Msg],
  model : Model,
) -> (@rabbita.Cmd, Model) {
  let title = "Context link - \{@desk.display_name(model.selected_path)}"
  let content = "Linked MoonDesk context\n\n" +
    "- Workspace: \{workspace_name(model)}\n" +
    "- Path: \{model.selected_path}\n" +
    "- Layer: \{selected_layer(model)}\n"
  (
    save_inbox_cmd(
      dispatch,
      { ..model, editing_inbox_path: "" },
      title,
      content,
    ),
    { ..model, inbox_status: "copying selection to inbox" },
  )
}
