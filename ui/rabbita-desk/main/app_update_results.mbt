///|
fn update_app_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedWorkspaceMetadata(_)
    | LoadedWorkspaces(_)
    | LoadedEntries(_)
    | LoadedPreview(_)
    | LoadedRuns(_)
    | LoadedSavedViews(_)
    | LoadedSearch(_)
    | LoadedDeskTrash(_)
    | SavedView(_)
    | CreatedBlankMoonBook(_)
    | ImportedMoonBook(_)
    | CreatedDeskEntry(_)
    | RenamedDeskEntry(_)
    | MovedDeskEntry(_)
    | CopiedDeskEntry(_)
    | TrashedDeskEntry(_)
    | RestoredDeskEntry(_)
    | ImportedDeskFiles(_)
    | SavedMarkdownEdit(_) => update_workspace_results(dispatch, msg, model)
    LoadedTownMessages(_)
    | LoadedRequests(_)
    | LoadedStandingGoals(_)
    | LoadedAnalytics(_)
    | LoadedTownProgress(_)
    | LoadedMoonclawProgress(_)
    | LoadedEvents(_)
    | LoadedReviewItems(_)
    | SubmittedRequest(_)
    | CreatedStandingGoal(_)
    | DecidedReviewItem(_) => update_town_results(dispatch, msg, model)
    LoadedBookBaseTypes(_)
    | LoadedBookPatterns(_)
    | CreatedBookFromPattern(_)
    | ExportedAppToolPortable(_)
    | ExportedAllAppToolPortable(_) =>
      update_book_runtime_results(dispatch, msg, model)
    LoadedDaemonLifecycle(_)
    | DispatchedDaemon(_)
    | ManagedDaemon(_)
    | LoadedLaunchAgent(_)
    | ManagedLaunchAgent(_)
    | RevealedSelection(_) => update_daemon_results(dispatch, msg, model)
    LocalFilesPicked(_) =>
      if model.workspace_mode == Desk {
        update_workspace_results(dispatch, msg, model)
      } else {
        update_inbox_results(dispatch, msg, model)
      }
    SavedInbox(_) | ImportedInbox(_) =>
      update_inbox_results(dispatch, msg, model)
    _ => (@rabbita.none, model)
  }
}
