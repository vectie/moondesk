///|
fn update_mooncode_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SelectMoonCodeSession(_)
    | NewMoonCodeSession
    | SetMoonCodePrompt(_)
    | SendMoonCodeMessage(_)
    | RetryMoonCodeTurn(_, _)
    | CancelMoonCodeWork(_, _)
    | DecideMoonCodeTool(_, _, _, _, _)
    | SetMoonCodeSessionQuery(_)
    | BeginMoonCodeSessionRename(_)
    | SetMoonCodeSessionTitleDraft(_)
    | CancelMoonCodeSessionRename
    | SaveMoonCodeSessionRename(_)
    | ArchiveMoonCodeSession(_)
    | RestoreMoonCodeSession(_)
    | RequestDeleteMoonCodeSession(_)
    | CancelDeleteMoonCodeSession
    | ConfirmDeleteMoonCodeSession(_) =>
      update_mooncode_session_actions(dispatch, msg, model)
    CopyMoonCodeText(item_id, text) =>
      (
        @rabbita.batch([
          copy_text_to_clipboard_cmd(text),
          @rabbita.delay(dispatch(ClearMoonCodeCopy(item_id)), 1500),
        ]),
        { ..model, mooncode_copied_item_id: item_id },
      )
    ClearMoonCodeCopy(item_id) =>
      if model.mooncode_copied_item_id == item_id {
        (@rabbita.none, { ..model, mooncode_copied_item_id: "" })
      } else {
        (@rabbita.none, model)
      }
    ManageMoonClaw(action) =>
      (
        manage_moonclaw_cmd(dispatch, action),
        {
          ..model,
          moonclaw_installing: action == "install",
          mooncode_composer_status: if action == "install" {
            "Downloading and verifying MoonClaw…"
          } else {
            "Starting MoonClaw…"
          },
        },
      )
    RefreshMoonCodeMetadata(_) | ResumeMoonCodeWatch(_, _) =>
      update_mooncode_transport_actions(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
