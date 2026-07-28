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
    | DecideMoonCodeTool(_, _)
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
          moonclaw_operation: action,
          moonclaw_operation_status: "",
          moonclaw_operation_failed: false,
          moonclaw_install_feedback: if action == "install" {
            if moonclaw_repair_available(model.moonclaw_daemon) {
              "Repairing the MoonClaw installation…"
            } else {
              "Downloading, verifying, and installing MoonClaw…"
            }
          } else {
            ""
          },
          mooncode_composer_status: if action == "install" {
            if moonclaw_repair_available(model.moonclaw_daemon) {
              "Repairing MoonClaw…"
            } else {
              "Downloading, verifying, and installing MoonClaw…"
            }
          } else {
            "Starting MoonClaw…"
          },
        },
      )
    StartMoonClawAuth(provider) =>
      (
        start_moonclaw_auth_cmd(dispatch, provider),
        {
          ..model,
          moonclaw_auth_pending: provider,
          moonclaw_auth_status: "",
          moonclaw_auth_feedback: "",
          moonclaw_auth_failed: false,
          moonclaw_setup_started: true,
        },
      )
    CheckMoonClawSetup =>
      (
        @rabbita.batch([
          fetch_moonclaw_auth_cmd(dispatch),
          fetch_moonclaw_daemon_cmd(dispatch),
        ]),
        {
          ..model,
          moonclaw_auth_pending: "check",
          moonclaw_auth_status: "",
          moonclaw_auth_feedback: "Checking Code assistance setup…",
          moonclaw_auth_failed: false,
        },
      )
    SetMoonClawOpenRouterKey(value) =>
      (@rabbita.none, { ..model, moonclaw_openrouter_key: value })
    SaveMoonClawOpenRouterKey =>
      if model.moonclaw_openrouter_key.trim().to_owned() == "" {
        (
          @rabbita.none,
          {
            ..model,
            moonclaw_auth_status: "api_key_required",
            moonclaw_auth_feedback: "OpenRouter API key is required.",
            moonclaw_auth_failed: true,
          },
        )
      } else {
        (
          save_moonclaw_openrouter_key_cmd(
            dispatch,
            model.moonclaw_openrouter_key.trim().to_owned(),
          ),
          {
            ..model,
            moonclaw_auth_pending: "openrouter",
            moonclaw_auth_status: "",
            moonclaw_auth_feedback: "",
            moonclaw_auth_failed: false,
            moonclaw_setup_started: true,
          },
        )
      }
    RefreshMoonCodeMetadata(_) | ResumeMoonCodeWatch(_, _) =>
      update_mooncode_transport_actions(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
