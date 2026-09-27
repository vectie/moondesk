///|
fn mooncode_job_status_label(status : String) -> String {
  match status {
    "running" => "Running"
    "waiting" => "Waiting"
    "failed" => "Failed"
    "interrupted" => "Interrupted"
    "done" => "Completed"
    "cancelled" => "Cancelled"
    _ => "Unknown"
  }
}

///|
fn mooncode_job_status_i18n_key(status : String) -> String {
  match status {
    "running" => "code.job_running"
    "waiting" => "code.job_waiting"
    "failed" => "code.job_failed"
    "interrupted" => "code.job_interrupted"
    "done" => "code.job_completed"
    "cancelled" => "code.job_cancelled"
    _ => "code.job_unknown"
  }
}

///|
fn render_mooncode_job_history(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  if !model.mooncode_jobs_visible ||
    model.selected_mooncode_session_id == "" ||
    model.mooncode_jobs_session_id != model.selected_mooncode_session_id {
    return @html.nothing
  }
  section(
    class="mooncode-job-history",
    attrs=@html.Attrs::build()
      .data_set("testid", "mooncode-job-history")
      .aria_label("Code job history")
      .data_set("i18n-aria-label", "code.job_history_aria"),
    [
      div(class="mooncode-job-history-heading", [
        div([
          strong(
            attrs=@html.Attrs::build().data_set("i18n", "code.job_history"),
            "Job history",
          ),
          p(
            attrs=@html.Attrs::build().data_set("i18n", "code.job_history_desc"),
            "Durable MoonClaw runs for this Code session.",
          ),
        ]),
        button(
          class="mooncode-skill-toggle",
          attrs=@html.Attrs::build().data_set("i18n", "common.refresh"),
          on_click=dispatch(RefreshMoonCodeJobs),
          disabled=model.mooncode_jobs_loading,
          "Refresh",
        ),
      ]),
      div(attrs=@html.Attrs::build().role("status").aria_live("polite"), [
        if model.mooncode_jobs_loading {
          p(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.job_history_loading",
            ),
            "Loading job history…",
          )
        } else if model.mooncode_jobs_error != "" {
          p(model.mooncode_jobs_error)
        } else {
          @html.nothing
        },
      ]),
      match model.mooncode_job_history {
        Some(history) if history.jobs.is_empty() =>
          p(
            attrs=@html.Attrs::build().data_set(
              "i18n", "code.job_history_empty",
            ),
            "No Code jobs have run in this session yet.",
          )
        Some(history) =>
          div(class="mooncode-job-history-results", [
            if history.truncated {
              p(
                attrs=@html.Attrs::build().data_set(
                  "i18n", "code.job_recent_limit",
                ),
                "Showing the 50 most recent runs.",
              )
            } else {
              @html.nothing
            },
            div(
              class="mooncode-job-list",
              history.jobs.map(job => {
                div(
                  class="mooncode-job-row",
                  attrs=@html.Attrs::build().data_set("status", job.status),
                  [
                    div(class="mooncode-job-row-heading", [
                      strong(
                        attrs=@html.Attrs::build().data_set(
                          "i18n",
                          mooncode_job_status_i18n_key(job.status),
                        ),
                        mooncode_job_status_label(job.status),
                      ),
                      span(job.started_at),
                    ]),
                    if job.finished_at != "" {
                      p(
                        attrs=@html.Attrs::build()
                          .data_set("i18n", "code.job_finished")
                          .data_set(
                            "i18n-params",
                            ({ "time": job.finished_at } : Json).stringify(),
                          ),
                        "Finished: " + job.finished_at,
                      )
                    } else {
                      @html.nothing
                    },
                    p(
                      attrs=@html.Attrs::build()
                        .data_set("i18n", "code.job_turns")
                        .data_set(
                          "i18n-params",
                          (
                            {
                              "ran": job.ran_turn_count,
                              "failed": job.failed_turn_count,
                            } : Json).stringify(),
                        ),
                      "Turns run: \{job.ran_turn_count} · failed: \{job.failed_turn_count}",
                    ),
                    if job.stopped_by != "" {
                      p(
                        attrs=@html.Attrs::build()
                          .data_set("i18n", "code.job_stopped_by")
                          .data_set(
                            "i18n-params",
                            ({ "reason": job.stopped_by } : Json).stringify(),
                          ),
                        "Stopped by: " + job.stopped_by,
                      )
                    } else {
                      @html.nothing
                    },
                    if job.detail != "" {
                      p(job.detail)
                    } else if job.status == "interrupted" {
                      p(
                        attrs=@html.Attrs::build().data_set(
                          "i18n", "code.job_interrupted_detail",
                        ),
                        "The daemon stopped before this run recorded a result.",
                      )
                    } else {
                      @html.nothing
                    },
                    details(class="technical-details", [
                      summary(
                        attrs=@html.Attrs::build().data_set(
                          "i18n", "common.technical_details",
                        ),
                        "Technical details",
                      ),
                      code(
                        attrs=@html.Attrs::build()
                          .data_set("i18n", "code.job_run_id")
                          .data_set(
                            "i18n-params",
                            (
                              { "run": job.run_id, "service": job.service_id } :
                              Json).stringify(),
                          ),
                        "Run " + job.run_id + " · service " + job.service_id,
                      ),
                    ]),
                  ],
                )
              }),
            ),
          ])
        None => @html.nothing
      },
    ],
  )
}
