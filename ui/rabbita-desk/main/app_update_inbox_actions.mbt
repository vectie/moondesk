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
        { ..model, import_url: url, inbox_status: "import draft" },
      )
    SetImportNote(note) =>
      (
        @rabbita.none,
        { ..model, import_note: note, inbox_status: "import draft" },
      )
    ImportUrlToInbox =>
      if model.import_url.trim().to_owned() == "" {
        (@rabbita.none, { ..model, inbox_status: "enter a URL to import" })
      } else {
        (
          import_url_cmd(dispatch, model),
          { ..model, inbox_status: "importing URL" },
        )
      }
    ImportLocalFiles =>
      (
        sync_activity_batch(Inbox, pick_import_files_cmd(dispatch)),
        {
          ..model,
          activity: Inbox,
          command_open: false,
          inbox_status: "opening file picker",
        },
      )
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
      let title = trimmed_or(model.inbox_title, "Moondesk inbox note")
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
  let content = "Linked Moondesk context\n\n" +
    "- Workspace: \{workspace_name(model)}\n" +
    "- Path: \{model.selected_path}\n" +
    "- Layer: \{selected_layer(model)}\n"
  (
    save_inbox_cmd(dispatch, { ..model, editing_inbox_path: "" }, title, content),
    { ..model, inbox_status: "copying selection to inbox" },
  )
}
