///|
fn render_town_pane(dispatch : Dispatch[Msg], model : Model) -> @rabbita.Html {
  aside(
    class="activity-pane user-pane",
    attrs=@html.Attrs::build().aria_label("Book requests"),
    [
      div(class="pane-heading", [
        div([p(class="eyebrow", "Knowledge work"), h2("Requests")]),
        button(
          class="secondary-button compact-button",
          title="Refresh requests",
          on_click=dispatch(SelectWorkspaceMode(RequestsWorkspace)),
          "Refresh",
        ),
      ]),
      render_requests_capability(dispatch, model),
      render_request_list(dispatch, model),
      section(class="side-section task-composer", [
        h3("Build or update this book"),
        textarea(
          class="side-textarea",
          attrs=@html.Attrs::build()
            .aria_label("Describe the book task")
            .data_set("testid", "requests-prompt"),
          rows=5,
          value=model.request_prompt,
          placeholder="Describe what to research, organize, or produce.",
          on_input=fn(value) { dispatch(SetRequestPrompt(value)) },
          "",
        ),
        render_request_materials(dispatch, model),
        div(class="task-material-inputs", [
          input(
            class="line-input",
            value=model.import_url,
            placeholder="Add a link",
            on_input=fn(value) { dispatch(SetImportUrl(value)) },
          ),
          textarea(
            class="side-textarea compact-textarea",
            attrs=@html.Attrs::build().aria_label("Material note"),
            rows=2,
            value=model.import_note,
            placeholder="Optional note about the materials",
            on_input=fn(value) { dispatch(SetImportNote(value)) },
            "",
          ),
          div(class="task-material-actions", [
            button(
              class="secondary-button",
              disabled=model.import_url.trim().is_empty(),
              on_click=dispatch(ImportUrlToInbox),
              "Add link",
            ),
            button(
              class="secondary-button",
              on_click=dispatch(ImportLocalFiles),
              "Add files",
            ),
          ]),
          if wiki_task_material_status(model.request_material_status) == "" {
            @html.nothing
          } else {
            p(
              class="status-line task-material-status",
              wiki_task_material_status(model.request_material_status),
            )
          },
        ]),
        button(
          class="primary-button full",
          attrs=@html.Attrs::build().data_set("testid", "requests-submit"),
          disabled=wiki_task_start_disabled(model),
          on_click=dispatch(SubmitRequest),
          "Start building",
        ),
        p(class="status-line", wiki_request_status_label(model.request_status)),
      ]),
      if requests_have_visible_activity(model) {
        section(class="side-section activity-list-section", [
          div(class="section-heading-row", [
            h3("Recent work"),
            small("Tasks and results"),
          ]),
          render_user_activity_list(dispatch, model),
        ])
      } else {
        @html.nothing
      },
      render_automation_disclosure(dispatch, model),
      render_book_creation_disclosure(dispatch, model),
    ],
  )
}

///|
fn render_requests_capability(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let state = requests_capability_state(
    model.daemon_lifecycle,
    model.town_capability_probe_available,
  )
  let action = requests_capability_primary_action(state)
  section(
    class="side-section surface-state-panel requests-capability",
    attrs=@html.Attrs::build()
      .data_set("testid", "requests-capability")
      .data_set("state", capability_state_key(state))
      .role("status")
      .aria_live("polite"),
    [
      strong(requests_capability_title(state)),
      p(requests_capability_detail(state)),
      match action {
        StartRequestsAutomation =>
          button(
            class="primary-button full",
            on_click=dispatch(StartDaemon),
            requests_capability_primary_action_label(action),
          )
        ReviewRequestsSetup =>
          button(
            class="primary-button full",
            on_click=dispatch(SelectActivity(Settings)),
            requests_capability_primary_action_label(action),
          )
        RetryRequestsCapabilityCheck =>
          button(
            class="primary-button full",
            on_click=dispatch(FetchDaemonLifecycle),
            requests_capability_primary_action_label(action),
          )
        NoRequestsCapabilityAction => @html.nothing
      },
      match model.daemon_lifecycle {
        Some(result) =>
          details(class="technical-details", [
            summary("Technical details"),
            info_row(
              "Configuration",
              if result.service_configured {
                "configured"
              } else {
                "needs setup"
              },
            ),
            match result.configuration_evidence {
              Some(evidence) =>
                info_row("Configuration reason", evidence.reason)
              None => @html.nothing
            },
            info_row("Configuration file", result.service_config_path),
            info_row("Working directory", result.service_cwd),
            match result.platform_evidence {
              Some(evidence) =>
                @html.fragment([
                  info_row("Platform", evidence.platform),
                  info_row("Architecture", evidence.architecture),
                  info_row(
                    "Platform support",
                    if evidence.supported {
                      "supported"
                    } else {
                      "unsupported"
                    },
                  ),
                ])
              None => @html.nothing
            },
            match result.installation_evidence {
              Some(evidence) =>
                @html.fragment([
                  info_row(
                    "Automation installation",
                    if evidence.installed {
                      "installed"
                    } else {
                      "not installed"
                    },
                  ),
                  info_row("Installation evidence", evidence.source),
                ])
              None => @html.nothing
            },
          ])
        None => @html.nothing
      },
    ],
  )
}

///|
fn render_request_materials(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  let materials = request_context_entries(model)
  div(class="task-materials", [
    div(class="task-material-heading", [
      strong("Materials"),
      small(request_material_count_label(model)),
    ]),
    if materials.length() == 0 {
      p(class="task-material-empty", "No materials added")
    } else {
      div(
        class="task-material-list",
        materials.map(path => {
          div(class="task-material-row", [
            span(title=path, @desk.display_name(path)),
            if has_string(model.request_material_paths, path) {
              button(
                class="icon-button task-material-remove",
                title="Remove material",
                attrs=@html.Attrs::build().aria_label(
                  "Remove " + @desk.display_name(path),
                ),
                on_click=dispatch(RemoveRequestMaterial(path)),
                "X",
              )
            } else {
              small("Current page")
            },
          ])
        }),
      )
    },
  ])
}

///|
fn wiki_task_start_disabled(model : Model) -> Bool {
  model.selected_workspace_id == "" || model.request_prompt.trim().is_empty()
}

///|
fn wiki_task_material_status(status : String) -> String {
  let value = status.trim().to_lower()
  if value == "" || value.contains("draft") {
    ""
  } else if value.contains("opening file picker") {
    "Choose files to add."
  } else if value.has_prefix("adding") {
    "Adding materials..."
  } else if value.has_prefix("added") {
    "Material added."
  } else if value.contains("removed") {
    "Material removed."
  } else if value.contains("fail") ||
    value.contains("error") ||
    value.contains("could not") {
    "Could not add materials."
  } else {
    status
  }
}

///|
fn render_user_activity_list(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  div(class="user-activity-list", [
    if requests_state_keeps_items(model.requests_state) {
      @html.fragment(
        model.requests[:wiki_request_limit(model.requests)].map(record => {
          render_user_request(record)
        }),
      )
    } else {
      @html.nothing
    },
    @html.fragment(
      model.runs[:wiki_run_limit(model.runs)].map(run => {
        render_user_run(dispatch, run)
      }),
    ),
  ])
}

///|
fn requests_have_visible_activity(model : Model) -> Bool {
  (
    requests_state_keeps_items(model.requests_state) &&
    model.requests.length() > 0
  ) ||
  model.runs.length() > 0
}

///|
fn render_user_request(record : RequestRecord) -> @rabbita.Html {
  let state = wiki_task_state(record.status)
  let prompt = json_field_string(record.request, "prompt", default="")
  div(class="user-activity-row " + wiki_task_tone(record.status), [
    div(class="activity-row-heading", [
      strong(request_title(record)),
      span(class="user-state", state),
    ]),
    if prompt == "" {
      @html.nothing
    } else {
      p(prompt)
    },
    if request_record_material_count(record) == 0 {
      @html.nothing
    } else {
      small(
        class="task-record-materials",
        request_record_material_label(record),
      )
    },
    details(class="technical-details", [
      summary("Details"),
      code("\{record.status} | \{record.id} | \{record.path}"),
    ]),
  ])
}

///|
fn request_record_material_count(record : RequestRecord) -> Int {
  json_field_string_array_items(record.request, "context_entries").length()
}

///|
fn request_record_material_label(record : RequestRecord) -> String {
  let count = request_record_material_count(record)
  if count == 1 {
    "1 material"
  } else {
    "\{count} materials"
  }
}

///|
fn render_user_run(
  dispatch : Dispatch[Msg],
  run : @desk.DeskRunProjection,
) -> @rabbita.Html {
  let title = trimmed_or(run.summary, "Completed book activity")
  div(class="user-activity-row " + wiki_task_tone(run.status), [
    div(class="activity-row-heading", [
      strong(title),
      span(class="user-state", wiki_task_state(run.status)),
    ]),
    if run.artifacts.length() == 0 {
      p("No result files were attached.")
    } else {
      div(
        class="result-link-list",
        run.artifacts.map(artifact => {
          button(
            class="result-link",
            on_click=dispatch(OpenQuickPath(artifact.path)),
            artifact.title,
          )
        }),
      )
    },
    details(class="technical-details", [
      summary("Details"),
      code("\{run.status} | \{run.phase} | \{run.run_id}"),
    ]),
  ])
}

///|
fn wiki_request_limit(items : Array[RequestRecord]) -> Int {
  if items.length() > 4 {
    4
  } else {
    items.length()
  }
}

///|
fn wiki_run_limit(items : Array[@desk.DeskRunProjection]) -> Int {
  if items.length() > 4 {
    4
  } else {
    items.length()
  }
}

///|
fn render_automation_disclosure(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  details(class="wiki-disclosure", [
    summary(class="wiki-disclosure-summary", "Automations"),
    div(class="wiki-disclosure-body", [
      p(
        class="disclosure-intro",
        "Schedule this book to check for useful updates.",
      ),
      if model.standing_goals.length() == 0 {
        p(class="status-line", "No automations yet.")
      } else {
        div(
          class="automation-list",
          model.standing_goals.map(goal => {
            div(class="automation-row", [
              strong(goal.title),
              span(if goal.enabled { "Active" } else { "Paused" }),
            ])
          }),
        )
      },
      input(
        class="line-input",
        value=model.goal_title,
        placeholder="Automation name",
        on_input=fn(value) { dispatch(SetGoalTitle(value)) },
      ),
      input(
        class="line-input",
        value=model.goal_cadence_ticks,
        placeholder="Check interval",
        on_input=fn(value) { dispatch(SetGoalCadenceTicks(value)) },
      ),
      button(
        class="secondary-button full",
        on_click=dispatch(CreateStandingGoal),
        "Create automation",
      ),
      p(
        class="status-line",
        wiki_automation_status_label(model.dispatch_status),
      ),
      details(class="technical-details", [
        summary("Advanced automation settings"),
        input(
          class="line-input",
          value=model.goal_review_policy,
          placeholder="Review policy",
          on_input=fn(value) { dispatch(SetGoalReviewPolicy(value)) },
        ),
        input(
          class="line-input",
          value=model.goal_source_policy,
          placeholder="Source policy",
          on_input=fn(value) { dispatch(SetGoalSourcePolicy(value)) },
        ),
      ]),
    ]),
  ])
}

///|
fn render_book_creation_disclosure(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  details(class="wiki-disclosure", [
    summary(class="wiki-disclosure-summary", "Create a new book"),
    div(class="wiki-disclosure-body", [
      p(
        class="disclosure-intro",
        "Start a source-backed book and decide what it should watch for.",
      ),
      input(
        class="line-input",
        value=model.book_pattern_topic,
        placeholder="Book topic",
        on_input=fn(value) { dispatch(SetBookPatternTopic(value)) },
      ),
      textarea(
        class="side-textarea compact-textarea",
        rows=3,
        value=model.book_pattern_purpose,
        placeholder="What is this book for?",
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
      input(
        class="line-input",
        value=model.book_pattern_cadence_minutes,
        placeholder="Check every N minutes",
        on_input=fn(value) { dispatch(SetBookPatternCadenceMinutes(value)) },
      ),
      button(
        class=if book_pattern_creator_supported(model) {
          "primary-button full"
        } else {
          "secondary-button full"
        },
        on_click=dispatch(CreateBookFromPattern),
        if book_pattern_creator_supported(model) {
          "Create book"
        } else {
          "Choose a supported setup"
        },
      ),
      p(
        class="status-line",
        wiki_book_creation_status(model.book_pattern_status),
      ),
      details(class="technical-details", [
        summary("Advanced setup"),
        render_book_pattern_wizard(model),
        div(class="pattern-picker", book_base_type_buttons(dispatch, model)),
        div(class="pattern-picker", book_pattern_buttons(dispatch, model)),
        input(
          class="line-input",
          value=model.book_pattern_book_id,
          placeholder="Book id",
          on_input=fn(value) { dispatch(SetBookPatternBookId(value)) },
        ),
        input(
          class="line-input",
          value=model.book_pattern_source_policy,
          placeholder="Source policy",
          on_input=fn(value) { dispatch(SetBookPatternSourcePolicy(value)) },
        ),
        input(
          class="line-input",
          value=model.book_pattern_notify_rule,
          placeholder="Notification rule",
          on_input=fn(value) { dispatch(SetBookPatternNotifyRule(value)) },
        ),
        textarea(
          class="side-textarea mini-textarea",
          rows=3,
          value=model.book_pattern_skill_pack,
          placeholder="Skill pack",
          on_input=fn(value) { dispatch(SetBookPatternSkillPack(value)) },
          "",
        ),
        textarea(
          class="side-textarea compact-textarea",
          rows=5,
          value=model.book_pattern_analysis_method,
          placeholder="Analysis method",
          on_input=fn(value) { dispatch(SetBookPatternAnalysisMethod(value)) },
          "",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(ExportAppToolPortable),
          "Export this book's portable app",
        ),
        button(
          class="secondary-button full",
          on_click=dispatch(ExportAllAppToolPortable),
          "Export all portable apps",
        ),
      ]),
    ]),
  ])
}

///|
fn wiki_book_creation_status(status : String) -> String {
  let value = status.trim().to_lower()
  if value.contains("ready") {
    "Ready to create."
  } else if value.contains("published") {
    "Book created."
  } else if value.contains("fail") ||
    value.contains("error") ||
    value.contains("unsupported") {
    "Could not create the book. Check Advanced setup."
  } else {
    status
  }
}
