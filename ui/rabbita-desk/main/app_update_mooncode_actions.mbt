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
    | SetMoonClawModel(_)
    | ToggleMoonCodeWebSearch
    | SendMoonCodeMessage => update_mooncode_session_actions(dispatch, msg, model)
    RunMoonCodeCommand(_)
    | RunMoonCodeCommandForPath(_, _)
    | RunMoonCodeCommandWithMessage(_, _, _, _)
    | RunMoonCodeCommandOverride(_, _) =>
      update_mooncode_command_actions(dispatch, msg, model)
    RunMoonCodeRuntimeLoop
    | RanMoonCodeRuntimeLoop(_, _)
    | StartMoonCodeRuntimeService
    | StartedMoonCodeRuntimeService(_, _)
    | ClaimMoonCodeRuntime(_)
    | AckMoonCodeRuntimeCommand(_, _) =>
      update_mooncode_runtime_actions(dispatch, msg, model)
    ProbeMoonCodeToolAuthorization(_) =>
      update_mooncode_tool_actions(dispatch, msg, model)
    PollMoonCodeSessions => update_mooncode_poll_actions(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}

