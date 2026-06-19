///|
fn update_mooncode_command_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    RunMoonCodeCommand(action) =>
      match selected_mooncode_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              MoonCode,
              mooncode_session_command_cmd(
                dispatch,
                model,
                session,
                action,
                message=mooncode_command_message_from_prompt(model, action),
              ),
            ),
            {
              ..model,
              workspace_mode: MoonCode,
              activity: MoonCode,
              command_open: false,
              mooncode_composer_status: "queued MoonCode \{action}",
            },
          )
        None => mooncode_needs_selected_session(model)
      }
    RunMoonCodeCommandForPath(action, context_path) =>
      match selected_mooncode_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              MoonCode,
              mooncode_session_command_cmd(
                dispatch,
                model,
                session,
                action,
                context_path~,
              ),
            ),
            {
              ..model,
              workspace_mode: MoonCode,
              activity: MoonCode,
              command_open: false,
              mooncode_composer_status: "queued MoonCode \{action} for \{context_path}",
            },
          )
        None => mooncode_needs_selected_session(model)
      }
    RunMoonCodeCommandWithMessage(action, context_path, message, status) =>
      match selected_mooncode_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              MoonCode,
              mooncode_session_command_cmd(
                dispatch,
                model,
                session,
                action,
                context_path~,
                message~,
              ),
            ),
            {
              ..model,
              workspace_mode: MoonCode,
              activity: MoonCode,
              command_open: false,
              mooncode_composer_status: if status == "" {
                "queued MoonCode \{action}"
              } else {
                status
              },
            },
          )
        None => mooncode_needs_selected_session(model)
      }
    RunMoonCodeCommandOverride(action, context_path) =>
      match selected_mooncode_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              MoonCode,
              mooncode_session_command_cmd(
                dispatch,
                model,
                session,
                action,
                context_path~,
                force_preflight=true,
              ),
            ),
            {
              ..model,
              workspace_mode: MoonCode,
              activity: MoonCode,
              command_open: false,
              mooncode_composer_status: "forced MoonCode \{action} for \{context_path}",
            },
          )
        None => mooncode_needs_selected_session(model)
      }
    _ => (@rabbita.none, model)
  }
}

