///|
fn update_inbox_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SavedInbox(Ok(created)) =>
      (
        sync_activity_batch(
          Inbox,
          @rabbita.batch([
            fetch_entries_cmd(dispatch, created.workspace_id, "inbox"),
            fetch_preview_cmd(dispatch, created.workspace_id, created.path),
          ]),
        ),
        {
          ..model,
          activity: Inbox,
          command_open: false,
          current_directory: "inbox",
          desk_location_input: "inbox",
          selected_workspace_id: created.workspace_id,
          selected_path: created.path,
          desk_selected_paths: [created.path],
          desk_selection_anchor: created.path,
          primary_preview_path: created.path,
          editing_inbox_path: created.path,
          inbox_status: if created.ok {
            "saved \{created.path}"
          } else {
            "save returned without ok"
          },
          preview_status: "loading saved note",
        },
      )
    SavedInbox(Err(error)) => (@rabbita.none, { ..model, inbox_status: error })
    ImportedInbox(Ok(created)) =>
      if task_material_capture_active(model) {
        (
          sync_activity_cmd(Town),
          {
            ..model,
            activity: Town,
            command_open: false,
            selected_workspace_id: created.workspace_id,
            import_url: "",
            import_note: "",
            request_material_paths: if created.ok {
              add_request_material(model.request_material_paths, created.path)
            } else {
              model.request_material_paths
            },
            request_material_status: if created.ok {
              "added \{created.path}"
            } else {
              "material import returned without ok"
            },
          },
        )
      } else {
        (
          sync_activity_batch(
            Inbox,
            @rabbita.batch([
              fetch_entries_cmd(dispatch, created.workspace_id, "inbox/imports"),
              fetch_preview_cmd(dispatch, created.workspace_id, created.path),
            ]),
          ),
          {
            ..model,
            activity: Inbox,
            command_open: false,
            current_directory: "inbox/imports",
            desk_location_input: "inbox/imports",
            selected_workspace_id: created.workspace_id,
            selected_path: created.path,
            desk_selected_paths: [created.path],
            desk_selection_anchor: created.path,
            primary_preview_path: created.path,
            import_url: "",
            import_note: "",
            inbox_status: if created.ok {
              if created.data_path == "" {
                "imported \{created.kind} to \{created.path}"
              } else {
                "imported \{created.kind} to \{created.path} and \{created.data_path}"
              }
            } else {
              "import returned without ok"
            },
            preview_status: "loading import",
          },
        )
      }
    ImportedInbox(Err(error)) =>
      if task_material_capture_active(model) {
        (@rabbita.none, { ..model, request_material_status: error })
      } else {
        (@rabbita.none, { ..model, inbox_status: error })
      }
    LocalFilesPicked(Ok(files)) =>
      if files.length() == 0 {
        if task_material_capture_active(model) {
          (@rabbita.none, { ..model, request_material_status: "" })
        } else {
          (@rabbita.none, model)
        }
      } else if model.selected_workspace_id == "" {
        if task_material_capture_active(model) {
          (
            @rabbita.none,
            { ..model, request_material_status: "select a book first" },
          )
        } else {
          (@rabbita.none, { ..model, inbox_status: "select a workspace first" })
        }
      } else {
        let cmds : Array[@rabbita.Cmd] = []
        for file in files {
          cmds.push(import_local_file_cmd(dispatch, model, file))
        }
        if task_material_capture_active(model) {
          (
            sync_activity_batch(Town, @rabbita.batch(cmds)),
            {
              ..model,
              activity: Town,
              command_open: false,
              request_material_status: "adding \{files.length()} file(s)",
            },
          )
        } else {
          (
            sync_activity_batch(Inbox, @rabbita.batch(cmds)),
            {
              ..model,
              activity: Inbox,
              command_open: false,
              inbox_status: "importing \{files.length()} local file(s)",
            },
          )
        }
      }
    LocalFilesPicked(Err(error)) =>
      if task_material_capture_active(model) {
        (
          @rabbita.none,
          { ..model, request_material_status: "local import failed: \{error}" },
        )
      } else {
        (
          @rabbita.none,
          { ..model, inbox_status: "local import failed: \{error}" },
        )
      }
    _ => (@rabbita.none, model)
  }
}
