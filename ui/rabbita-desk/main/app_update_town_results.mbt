///|
fn update_town_results(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    LoadedTownMessages(Ok(town_messages)) =>
      (@rabbita.none, { ..model, town_messages, })
    LoadedTownMessages(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedRequests(Ok(requests)) => (@rabbita.none, { ..model, requests, })
    LoadedRequests(Err(error)) =>
      (@rabbita.none, { ..model, request_status: error })
    LoadedStandingGoals(Ok(standing_goals)) =>
      (@rabbita.none, { ..model, standing_goals, })
    LoadedStandingGoals(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedAnalytics(Ok(analytics)) =>
      (@rabbita.none, { ..model, analytics: Some(analytics) })
    LoadedAnalytics(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedTownProgress(Ok(progress)) =>
      (@rabbita.none, { ..model, town_progress: Some(progress) })
    LoadedTownProgress(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedMoonclawProgress(Ok(progress)) =>
      (@rabbita.none, { ..model, moonclaw_progress: Some(progress) })
    LoadedMoonclawProgress(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    LoadedEvents(Ok(events)) => (@rabbita.none, { ..model, events, })
    LoadedEvents(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    LoadedReviewItems(Ok(review_items)) =>
      (@rabbita.none, { ..model, review_items, })
    LoadedReviewItems(Err(error)) =>
      (@rabbita.none, { ..model, host_status: error })
    SubmittedRequest(Ok(record)) =>
      (
        sync_activity_batch(
          Town,
          @rabbita.batch([
            fetch_requests_cmd(dispatch),
            fetch_messages_cmd(dispatch),
            fetch_analytics_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
          ]),
        ),
        {
          ..model,
          activity: Town,
          request_status: "staged \{record.id}",
          request_prompt: "",
          request_material_paths: [],
          request_material_status: "",
          import_url: "",
          import_note: "",
          command_open: false,
        },
      )
    SubmittedRequest(Err(error)) =>
      (@rabbita.none, { ..model, request_status: error })
    CreatedStandingGoal(Ok(goal)) =>
      (
        sync_activity_batch(
          Town,
          @rabbita.batch([
            fetch_standing_goals_cmd(dispatch),
            fetch_analytics_cmd(dispatch),
            fetch_town_progress_cmd(dispatch),
            fetch_town_events_cmd(dispatch),
          ]),
        ),
        {
          ..model,
          activity: Town,
          command_open: false,
          dispatch_status: "created \{goal.id}",
        },
      )
    CreatedStandingGoal(Err(error)) =>
      (@rabbita.none, { ..model, dispatch_status: error })
    DecidedReviewItem(Ok(result)) =>
      (
        @rabbita.batch([
          fetch_review_items_cmd(dispatch, model.selected_workspace_id),
          fetch_search_cmd(dispatch, result.id),
        ]),
        {
          ..model,
          host_status: "\{result.decision} review decision recorded for \{result.workspace_id}",
          review_decision_note: "",
          review_decision_status: "\{result.status} \{result.source_path} -> \{result.receipt_path}",
          inbox_status: if result.note == "" {
            model.inbox_status
          } else {
            "review note recorded"
          },
        },
      )
    DecidedReviewItem(Err(error)) =>
      (@rabbita.none, { ..model, review_decision_status: error })
    _ => (@rabbita.none, model)
  }
}
