///|
fn update_mooncode_tool_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    ProbeMoonCodeToolAuthorization(tool_id) =>
      match selected_mooncode_session(model) {
        Some(session) =>
          (
            sync_activity_batch(
              MoonCode,
              probe_mooncode_tool_authorization_cmd(
                dispatch, session.id, model.selected_path, tool_id,
              ),
            ),
            {
              ..model,
              workspace_mode: MoonCode,
              activity: MoonCode,
              command_open: false,
              mooncode_tool_authorization_session_id: session.id,
              mooncode_tool_authorization_status: "probing \{tool_id}",
              mooncode_composer_status: "probing MoonCode \{tool_id} authorization",
            },
          )
        None => mooncode_needs_selected_session(model)
      }
    _ => (@rabbita.none, model)
  }
}

