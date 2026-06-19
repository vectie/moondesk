///|
fn render_town_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(class="explorer-pane", [
    div(class="pane-heading", [
      div([p(class="eyebrow", "moontown"), h2("Requests")]),
      div(class="toolbar-actions", [
        button(
          class="icon-button",
          title="Run Daemon Tick",
          on_click=dispatch(ControlDaemonTick),
          "D",
        ),
        button(
          class="icon-button",
          title="Refresh",
          on_click=dispatch(RefreshAll),
          "R",
        ),
      ]),
    ]),
    section(class="side-section", [
      textarea(
        class="side-textarea",
        rows=8,
        value=model.request_prompt,
        placeholder="Ask Moontown to act on selected context.",
        on_input=fn(value) { dispatch(SetRequestPrompt(value)) },
        "",
      ),
      button(
        class="primary-button full",
        on_click=dispatch(SubmitRequest),
        "Submit to Town",
      ),
      p(class="status-line", model.request_status),
    ]),
    section(class="side-section", [
      h3("Book Pattern Builder"),
      render_book_pattern_wizard(model),
      div(
        class="pattern-picker",
        book_base_type_buttons(dispatch, model),
      ),
      div(
        class="pattern-picker",
        book_pattern_buttons(dispatch, model),
      ),
      input(
        class="line-input",
        value=model.book_pattern_book_id,
        placeholder="Book id, e.g. research-my-domain-pdf-watch",
        on_input=fn(value) { dispatch(SetBookPatternBookId(value)) },
        "",
      ),
      input(
        class="line-input",
        value=model.book_pattern_topic,
        placeholder="Domain title/topic",
        on_input=fn(value) { dispatch(SetBookPatternTopic(value)) },
        "",
      ),
      textarea(
        class="side-textarea compact-textarea",
        rows=3,
        value=model.book_pattern_purpose,
        placeholder="Book purpose",
        on_input=fn(value) { dispatch(SetBookPatternPurpose(value)) },
        "",
      ),
      textarea(
        class="side-textarea compact-textarea",
        rows=4,
        value=model.book_pattern_websites,
        placeholder="One source website per line",
        on_input=fn(value) { dispatch(SetBookPatternWebsites(value)) },
        "",
      ),
      div(class="field-grid compact-fields", [
        input(
          class="line-input",
          value=model.book_pattern_cadence_minutes,
          placeholder="Cadence minutes",
          on_input=fn(value) { dispatch(SetBookPatternCadenceMinutes(value)) },
          "",
        ),
        input(
          class="line-input",
          value=model.book_pattern_source_policy,
          placeholder="Source policy",
          on_input=fn(value) { dispatch(SetBookPatternSourcePolicy(value)) },
          "",
        ),
      ]),
      input(
        class="line-input",
        value=model.book_pattern_notify_rule,
        placeholder="Notification rule",
        on_input=fn(value) { dispatch(SetBookPatternNotifyRule(value)) },
        "",
      ),
      textarea(
        class="side-textarea mini-textarea",
        rows=3,
        value=model.book_pattern_skill_pack,
        placeholder="Skill pack, one skill per line",
        on_input=fn(value) { dispatch(SetBookPatternSkillPack(value)) },
        "",
      ),
      textarea(
        class="side-textarea compact-textarea",
        rows=6,
        value=model.book_pattern_analysis_method,
        placeholder="wiki/methods/my-analysis-method.md",
        on_input=fn(value) { dispatch(SetBookPatternAnalysisMethod(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(
          class=if book_pattern_creator_supported(model) {
            "primary-button full"
          } else {
            "secondary-button full"
          },
          on_click=dispatch(CreateBookFromPattern),
          if book_pattern_creator_supported(model) {
            "Publish Book + Watch"
          } else {
            "Choose PDF Pattern First"
          },
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(ExportAppToolPortable),
          "Export Portable App",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(ExportAllAppToolPortable),
          "Export All Portable Apps",
        ),
      ]),
      p(class="status-line", model.book_pattern_status),
    ]),
    section(class="side-section", [
      h3("Standing Watch"),
      input(
        class="line-input",
        value=model.goal_title,
        placeholder="Watch title",
        on_input=fn(value) { dispatch(SetGoalTitle(value)) },
        "",
      ),
      div(class="field-grid compact-fields", [
        input(
          class="line-input",
          value=model.goal_cadence_ticks,
          placeholder="Cadence ticks",
          on_input=fn(value) { dispatch(SetGoalCadenceTicks(value)) },
          "",
        ),
        input(
          class="line-input",
          value=model.goal_review_policy,
          placeholder="Review policy",
          on_input=fn(value) { dispatch(SetGoalReviewPolicy(value)) },
          "",
        ),
      ]),
      input(
        class="line-input",
        value=model.goal_source_policy,
        placeholder="Source policy",
        on_input=fn(value) { dispatch(SetGoalSourcePolicy(value)) },
        "",
      ),
      div(class="toolbar-actions stack-actions", [
        button(
          class="secondary-button",
          on_click=dispatch(CreateStandingGoal),
          "Create Watch",
        ),
        button(
          class="secondary-button",
          on_click=dispatch(ControlDaemonTick),
          "Run Tick",
        ),
      ]),
      p(class="status-line", model.dispatch_status),
    ]),
    render_town_progress_panel(model),
    render_event_panel(model),
    render_daemon_lifecycle_panel(dispatch, model),
    render_standing_goal_list(model),
    render_request_list(model),
  ])
}
