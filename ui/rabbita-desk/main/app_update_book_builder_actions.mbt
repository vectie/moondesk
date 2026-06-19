///|
fn update_book_builder_actions(
  dispatch : Dispatch[Msg],
  msg : Msg,
  model : Model,
) -> (@rabbita.Cmd, Model) {
  match msg {
    SetGoalTitle(title) => (@rabbita.none, { ..model, goal_title: title })
    SetGoalCadenceTicks(value) =>
      (@rabbita.none, { ..model, goal_cadence_ticks: value })
    SetGoalReviewPolicy(value) =>
      (@rabbita.none, { ..model, goal_review_policy: value })
    SetGoalSourcePolicy(value) =>
      (@rabbita.none, { ..model, goal_source_policy: value })
    SetBookPatternBookId(value) =>
      (@rabbita.none, { ..model, book_pattern_book_id: value })
    SetBookPatternTopic(value) =>
      (@rabbita.none, { ..model, book_pattern_topic: value })
    SetBookPatternPurpose(value) =>
      (@rabbita.none, { ..model, book_pattern_purpose: value })
    SetBookPatternWebsites(value) =>
      (@rabbita.none, { ..model, book_pattern_websites: value })
    SetBookPatternCadenceMinutes(value) =>
      (@rabbita.none, { ..model, book_pattern_cadence_minutes: value })
    SetBookPatternSourcePolicy(value) =>
      (@rabbita.none, { ..model, book_pattern_source_policy: value })
    SetBookPatternNotifyRule(value) =>
      (@rabbita.none, { ..model, book_pattern_notify_rule: value })
    SetBookPatternSkillPack(value) =>
      (@rabbita.none, { ..model, book_pattern_skill_pack: value })
    SetBookPatternAnalysisMethod(value) =>
      (@rabbita.none, { ..model, book_pattern_analysis_method: value })
    SelectBookBaseType(base_type) =>
      (@rabbita.none, apply_selected_book_base_type(model, base_type))
    SelectBookPattern(pattern_id) =>
      (@rabbita.none, apply_selected_book_pattern(model, pattern_id))
    CreateStandingGoal =>
      (
        sync_activity_batch(
          Town,
          create_standing_goal_cmd(dispatch, model),
        ),
        {
          ..model,
          activity: Town,
          command_open: false,
          dispatch_status: "creating standing watch",
        },
      )
    CreateBookFromPattern =>
      if !book_pattern_creator_supported(model) {
        (
          @rabbita.none,
          {
            ..model,
            book_pattern_status: "select a pattern with a supported creation backend; `\{model.selected_book_pattern_id}` is registry-visible but cannot be published by this build",
          },
        )
      } else {
        (
          sync_activity_batch(
            Town,
            create_book_from_pattern_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Town,
            command_open: false,
            book_pattern_status: "publishing selected book pattern",
          },
        )
      }
    ExportAppToolPortable =>
      if selected_book_id_for_portable_export(model) == "" {
        (
          @rabbita.none,
          {
            ..model,
            book_pattern_status: "publish or select an app-tool MoonBook first",
          },
        )
      } else {
        (
          sync_activity_batch(
            Town,
            export_app_tool_portable_cmd(dispatch, model),
          ),
          {
            ..model,
            activity: Town,
            command_open: false,
            book_pattern_status: "exporting portable app-tool bundle",
          },
        )
      }
    ExportAllAppToolPortable =>
      (
        sync_activity_batch(
          Town,
          export_all_app_tool_portable_cmd(dispatch),
        ),
        {
          ..model,
          activity: Town,
          command_open: false,
          book_pattern_status: "exporting all portable app-tool bundles",
        },
      )
    _ => (@rabbita.none, model)
  }
}
