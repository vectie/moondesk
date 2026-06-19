///|
fn update_mooncode_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedMoonClawDaemon(_) | LoadedMoonClawModels(_) | LoadedMoonCodeSessions(_) | LoadedMoonCodeCapabilities(_) =>
      update_mooncode_session_results(dispatch, msg, model)
    LoadedMoonCodeStream(_, _) | SavedMoonCodeStreamCheckpoint(_, _) | LoadedMoonCodeRuntimeEventSink(_, _) =>
      update_mooncode_stream_results(dispatch, msg, model)
    LoadedMoonCodeChangeSet(_, _) | LoadedMoonCodeEvalReport(_, _) | LoadedMoonCodeRuntimeHandoff(_, _) | LoadedMoonCodePatchSet(_, _) | LoadedMoonCodeToolApprovals(_, _) | LoadedMoonCodeToolAuthorization(_, _, _) | LoadedMoonCodeTestRuns(_, _) | LoadedMoonCodePackageCandidates(_, _) | LoadedMoonCodeActionPlan(_, _) | LoadedMoonCodeReadiness(_, _) | LoadedMoonCodeRuntimeEvidence(_, _) | LoadedMoonCodeCommandQueue(_, _) | LoadedMoonCodeRuntimeCommandFeed(_, _) | LoadedMoonCodeRuntimeReplay(_, _) | LoadedMoonCodeCommandPreflight(_, _, _) =>
      update_mooncode_artifact_results(dispatch, msg, model)
    LoadedMoonCodeRuntimeReceipt(_, _) | LoadedMoonCodeRuntimeClaimState(_, _) | ClaimedMoonCodeRuntime(_, _, _) | AckedMoonCodeRuntimeCommand(_, _, _, _) | CreatedMoonCodeSession(_) | CompletedMoonCodeCommand(_) =>
      update_mooncode_runtime_results(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
