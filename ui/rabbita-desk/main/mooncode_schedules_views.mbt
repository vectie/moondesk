///|
#cfg(target="js")
extern "js" fn browser_code_schedule_time(seconds : String) -> String =
  #| (seconds) => {
  #|   const value = Number(seconds);
  #|   if (!Number.isFinite(value) || value <= 0) return "—";
  #|   return new Date(value * 1000).toLocaleString();
  #| }

///|
fn mooncode_schedule_status_key(status : String) -> String {
  match status {
    "never-run" => "code.schedule_never_run"
    "dispatching" => "code.schedule_dispatching"
    "uncertain" => "code.schedule_uncertain"
    "waiting-control" => "code.schedule_waiting_control"
    "book-unavailable" => "code.schedule_book_unavailable"
    "accepted" => "code.schedule_accepted"
    "done" => "code.schedule_done"
    "failed" => "code.schedule_failed"
    "cancelled" => "code.schedule_cancelled"
    _ => "code.schedule_unknown"
  }
}

///|
fn mooncode_schedule_status_label(status : String) -> String {
  match status {
    "never-run" => "Not run yet"
    "dispatching" => "Dispatching"
    "uncertain" => "Delivery uncertain"
    "waiting-control" => "MoonClaw connection needed"
    "book-unavailable" => "MoonBook unavailable"
    "accepted" => "Running or awaiting result"
    "done" => "Completed"
    "failed" => "Failed"
    "cancelled" => "Cancelled"
    _ => "Unknown"
  }
}

///|
fn mooncode_schedule_has_matching_session(
  model : Model,
  schedule : MoonCodeSchedule,
) -> Bool {
  model.mooncode_sessions.any(session => {
    session.id == schedule.session_id &&
    session.workspace_id == schedule.book_id &&
    session.cwd == schedule.book_root
  })
}

///|
fn render_mooncode_schedule_row(
  dispatch : Dispatch[Msg],
  model : Model,
  schedule : MoonCodeSchedule,
) -> @rabbita.Html {
  let can_open = mooncode_schedule_has_matching_session(model, schedule)
  div(
    class="mooncode-schedule-row",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-schedule-row")
      .data_set("status", schedule.last_status),
    [
      div(class="mooncode-schedule-row-title", [
        strong(schedule.id),
        span(
          class="mooncode-schedule-status",
          attrs=@html.Attrs::build().data_set(
            "i18n",
            mooncode_schedule_status_key(schedule.last_status),
          ),
          mooncode_schedule_status_label(schedule.last_status),
        ),
        if schedule.enabled {
          span(
            attrs=@html.Attrs::build().data_set("i18n", "code.schedule_active"),
            "Active",
          )
        } else {
          span(
            attrs=@html.Attrs::build().data_set("i18n", "code.schedule_paused"),
            "Paused",
          )
        },
      ]),
      p(schedule.prompt),
      div(class="mooncode-schedule-meta", [
        span(
          attrs=@html.Attrs::build()
            .data_set("i18n", "code.schedule_every")
            .data_set(
              "i18n-params",
              ({ "minutes": schedule.interval_seconds / 60 } : Json).stringify(),
            ),
          "Every \{schedule.interval_seconds / 60} min",
        ),
        span(
          attrs=@html.Attrs::build()
            .data_set(
              "i18n",
              if schedule.pending_command_id != "" {
                "code.schedule_due"
              } else {
                "code.schedule_next"
              },
            )
            .data_set(
              "i18n-params",
              (
                {
                  "time": browser_code_schedule_time(
                    schedule.next_due_at.to_string(),
                  ),
                } : Json).stringify(),
            ),
          (if schedule.pending_command_id != "" { "Due: " } else { "Next: " }) +
          browser_code_schedule_time(schedule.next_due_at.to_string()),
        ),
      ]),
      if schedule.last_status == "waiting-control" {
        p(
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.schedule_control_action",
          ),
          "Start and configure MoonClaw. This same scheduled turn will resume after connection returns.",
        )
      } else if schedule.last_status == "book-unavailable" {
        p(
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.schedule_book_action",
          ),
          "Restore this registered MoonBook path, or pause the schedule.",
        )
      } else if schedule.last_status == "uncertain" {
        p(
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.schedule_uncertain_action",
          ),
          "MoonTown will retry the same turn ID and reconcile its result. Review the conversation for details.",
        )
      } else if schedule.last_status == "failed" {
        p(
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.schedule_failed_action",
          ),
          "Open the conversation to inspect the failed run. MoonTown will use the next scheduled time for a new turn.",
        )
      } else {
        @html.nothing
      },
      div(class="mooncode-schedule-actions", [
        button(
          class="mooncode-skill-toggle",
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.schedule_open_conversation",
          ),
          on_click=dispatch(SelectMoonCodeSession(schedule.session_id)),
          disabled=!can_open,
          "Open conversation",
        ),
        button(
          class="mooncode-skill-toggle",
          attrs=@html.Attrs::build().data_set(
            "i18n",
            if schedule.enabled {
              "code.schedule_pause"
            } else {
              "code.schedule_resume"
            },
          ),
          on_click=dispatch(
            SetMoonCodeScheduleEnabled(schedule.id, !schedule.enabled),
          ),
          disabled=model.mooncode_schedules_saving,
          if schedule.enabled {
            "Pause"
          } else {
            "Resume"
          },
        ),
      ]),
      details(class="technical-details", [
        summary(
          attrs=@html.Attrs::build().data_set("i18n", "code.schedule_details"),
          "Technical details",
        ),
        code("Session: " + schedule.session_id),
        code("MoonBook root: " + schedule.book_root),
        code("Command: " + schedule.last_command_id),
        code("Pending: " + schedule.pending_command_id),
        code("Model: " + schedule.model),
        if schedule.last_finished_at > 0L {
          code(
            "Finished: " +
            browser_code_schedule_time(schedule.last_finished_at.to_string()),
          )
        } else {
          @html.nothing
        },
      ]),
    ],
  )
}

///|
fn render_mooncode_schedules(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !model.mooncode_schedules_visible ||
    model.selected_workspace_id == "" ||
    model.mooncode_schedules_workspace_id != model.selected_workspace_id {
    return @html.nothing
  }
  let rows = match model.mooncode_schedule_state {
    Some(state) =>
      state.schedules.filter(schedule => {
        schedule.book_id == model.selected_workspace_id
      })
    None => []
  }
  let schedule_model = mooncode_selected_runtime_model(model, None)
  section(
    class="mooncode-schedule-panel",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-schedules")
      .aria_label("Scheduled Code work")
      .data_set("i18n-aria-label", "code.schedules_title"),
    [
      div(class="mooncode-schedule-heading", [
        div([
          strong(
            attrs=@html.Attrs::build().data_set("i18n", "code.schedules_title"),
            "Scheduled Code work",
          ),
          p(
            attrs=@html.Attrs::build().data_set("i18n", "code.schedules_desc"),
            "MoonTown schedules a turn in one durable MoonClaw conversation.",
          ),
        ]),
        button(
          class="mooncode-skill-toggle",
          attrs=@html.Attrs::build().data_set("i18n", "common.refresh"),
          on_click=dispatch(RefreshMoonCodeSchedules),
          disabled=model.mooncode_schedules_loading ||
            model.mooncode_schedules_saving,
          "Refresh",
        ),
      ]),
      div(attrs=@html.Attrs::build().role("status").aria_live("polite"), [
        if model.mooncode_schedules_loading {
          p(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.schedules_loading",
            ),
            "Loading Code schedules…",
          )
        } else if model.mooncode_schedules_error != "" {
          p(
            attrs=@html.Attrs::build().data_set(
              "i18n",
              mooncode_schedule_error_key(model.mooncode_schedules_error),
            ),
            model.mooncode_schedules_error,
          )
        } else if model.mooncode_schedules_status != "" {
          p(
            attrs=@html.Attrs::build().data_set("i18n", "code.schedule_saved"),
            model.mooncode_schedules_status,
          )
        } else {
          @html.nothing
        },
      ]),
      if rows.is_empty() && model.mooncode_schedule_state is Some(_) {
        p(
          attrs=@html.Attrs::build().data_set("i18n", "code.schedules_empty"),
          "No Code schedules for this MoonBook yet.",
        )
      } else {
        @html.nothing
      },
      details(class="mooncode-schedule-create-shell", [
        summary(
          attrs=@html.Attrs::build().data_set(
            "i18n", "code.schedule_create_title",
          ),
          "New schedule",
        ),
        div(class="mooncode-schedule-create", [
          @html.label([
            span(
              attrs=@html.Attrs::build().data_set("i18n", "code.schedule_id"),
              "Schedule ID",
            ),
            input(
              attrs=@html.Attrs::build()
                .aria_label("Schedule ID")
                .data_set("i18n-aria-label", "code.schedule_id")
                .data_set("i18n-placeholder", "code.schedule_id_example")
                .disabled(model.mooncode_schedules_saving),
              value=model.mooncode_schedule_id_draft,
              placeholder="nightly-review",
              on_input=fn(value) { dispatch(SetMoonCodeScheduleId(value)) },
            ),
          ]),
          @html.label([
            span(
              attrs=@html.Attrs::build().data_set(
                "i18n", "code.schedule_prompt",
              ),
              "Code task",
            ),
            textarea(
              attrs=@html.Attrs::build()
                .aria_label("Scheduled Code task")
                .data_set("i18n-aria-label", "code.schedule_prompt")
                .data_set("i18n-placeholder", "code.schedule_prompt_example"),
              rows=3,
              value=model.mooncode_schedule_prompt_draft,
              disabled=model.mooncode_schedules_saving,
              placeholder="Review the current code and report findings",
              on_input=fn(value) { dispatch(SetMoonCodeSchedulePrompt(value)) },
              "",
            ),
          ]),
          @html.label([
            span(
              attrs=@html.Attrs::build().data_set(
                "i18n", "code.schedule_cadence",
              ),
              "Repeat every (minutes)",
            ),
            input(
              attrs=@html.Attrs::build()
                .aria_label("Cadence in minutes")
                .data_set("i18n-aria-label", "code.schedule_cadence")
                .disabled(model.mooncode_schedules_saving),
              value=model.mooncode_schedule_interval_draft,
              placeholder="60",
              on_input=fn(value) {
                dispatch(SetMoonCodeScheduleInterval(value))
              },
            ),
          ]),
          button(
            class="primary-button",
            attrs=@html.Attrs::build().data_set("i18n", "code.schedule_create"),
            on_click=dispatch(CreateMoonCodeSchedule),
            disabled=model.mooncode_schedules_saving || schedule_model == "",
            "Create schedule",
          ),
          if schedule_model == "" {
            p(
              class="mooncode-schedule-form-help",
              attrs=@html.Attrs::build().data_set(
                "i18n", "code.schedule_model_needed",
              ),
              "Connect MoonClaw and select a model before creating a schedule.",
            )
          } else {
            p(
              class="mooncode-schedule-form-help",
              attrs=@html.Attrs::build()
                .data_set("i18n", "code.schedule_selected_model")
                .data_set(
                  "i18n-params",
                  ({ "model": schedule_model } : Json).stringify(),
                ),
              "New runs use the Code model selected below: {schedule_model}.",
            )
          },
          p(
            class="mooncode-schedule-form-help",
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.schedule_form_help",
            ),
            "Use lowercase letters, numbers, and hyphens in the ID. Pausing stops new turns; a reserved or running turn is still reconciled.",
          ),
        ]),
      ]),
      div(
        class="mooncode-schedule-list",
        rows.map(schedule => {
          render_mooncode_schedule_row(dispatch, model, schedule)
        }),
      ),
    ],
  )
}
