///|
fn render_native_work(
  dispatch : Dispatch[Msg],
  state : NativeWorkState,
) -> @rabbita.Html {
  section(
    class="side-section native-work-section",
    attrs=@html.Attrs::build()
      .aria_label("Town native work saved status")
      .data_set("testid", "town-native-work"),
    [
      div(class="section-heading-row", [
        h3("Town native work"),
        button(
          class="secondary-button compact-button",
          disabled=state.pending is Some(_),
          attrs=@html.Attrs::build().data_set("testid", "native-work-reload"),
          on_click=dispatch(NativeWork(ReloadSavedNative)),
          "Reload saved status",
        ),
      ]),
      p(
        "Saved status across all Books. Loading this list does not contact native work or apply results. Observations are not live.",
      ),
      p(
        "Refresh observation only checks native status. Cancel remaining work does not undo applied edits. Retry / continue and sync may dispatch or resend saved work and apply verified results.",
      ),
      p(class="status-line", "Pause is not supported."),
      button(
        class="secondary-button compact-button",
        disabled=true,
        "Pause unavailable",
      ),
      div(attrs=@html.Attrs::build().role("status").aria_live("polite"), [
        match state.pending {
          Some({ operation: ReadSaved, .. }) => p("Loading saved status…")
          Some({ operation: ControlNative(_, action), .. }) =>
            p(native_work_action_label(action) + " pending…")
          None => @html.nothing
        },
        if state.notice == "" {
          @html.nothing
        } else {
          p(state.notice)
        },
        if state.error == "" {
          @html.nothing
        } else {
          p(class="status-line native-work-error", state.error)
        },
      ]),
      match state.revision {
        Some(revision) => small("Saved revision \{revision}")
        None if state.items.length() > 0 =>
          small(
            "Earlier saved status. Reload successfully before taking an action.",
          )
        None => @html.nothing
      },
      if state.loaded && state.items.is_empty() && state.error == "" {
        p("No saved native work.")
      } else if !state.loaded && state.pending is None && state.error == "" {
        p("Reload to read saved native work.")
      } else {
        @html.nothing
      },
      @html.fragment(
        state.items.map(item => render_native_work_item(dispatch, state, item)),
      ),
    ],
  )
}

///|
fn render_native_work_item(
  dispatch : Dispatch[Msg],
  state : NativeWorkState,
  item : NativeWorkStatus,
) -> @rabbita.Html {
  div(
    class="user-activity-row native-work-item",
    attrs=@html.Attrs::build()
      .data_set("testid", "native-work-item")
      .data_set("work-id", item.id),
    [
      div(class="activity-row-heading", [
        strong(item.book_id + " · " + item.kind),
        span(class="user-state", item.state),
      ]),
      info_row(
        "Last saved check / attempt",
        native_work_timestamp(item.observed_at_ms.to_string()),
      ),
      info_row(
        "Cancellation / control",
        trimmed_or(item.control_state, "none recorded"),
      ),
      if item.blocked_reason == "" {
        @html.nothing
      } else {
        info_row("Blocker", item.blocked_reason)
      },
      if item.blocker_help == "" {
        @html.nothing
      } else {
        p(item.blocker_help)
      },
      if item.retry_after_ms == 0UL {
        @html.nothing
      } else {
        info_row(
          "Retry after",
          native_work_timestamp(item.retry_after_ms.to_string()),
        )
      },
      div(class="task-material-actions native-work-actions", [
        render_native_work_action(dispatch, state, item.id, RefreshObservation),
        render_native_work_action(dispatch, state, item.id, CancelRemaining),
        render_native_work_action(dispatch, state, item.id, SyncResults),
      ]),
      details(class="technical-details", [
        summary("Work details and saved output"),
        info_row("Work ID", item.id),
        info_row("Book ID", item.book_id),
        info_row("Criterion ID", item.criterion_id),
        info_row("Generation", item.generation.to_string()),
        info_row("Session ID", trimmed_or(item.session_id, "not reserved")),
        info_row("Command ID", trimmed_or(item.command_id, "not reserved")),
        info_row(
          "Engineering status",
          trimmed_or(item.engineering_status, "not recorded"),
        ),
        pre(class="native-work-output", item.output),
      ]),
    ],
  )
}

///|
fn render_native_work_action(
  dispatch : Dispatch[Msg],
  state : NativeWorkState,
  id : String,
  action : NativeWorkAction,
) -> @rabbita.Html {
  button(
    class="secondary-button compact-button",
    attrs=@html.Attrs::build().data_set(
      "testid",
      "native-work-" + native_work_action_path(action),
    ),
    disabled=native_work_action_disabled(state, id),
    on_click=dispatch(NativeWork(ActOnNative(id, action))),
    native_work_action_label(action),
  )
}

///|
#cfg(target="js")
extern "js" fn native_work_timestamp(value : String) -> String =
  #| value => {
  #|   if (value === '0') return 'No saved check / attempt';
  #|   const date = new Date(Number(value));
  #|   return Number.isNaN(date.getTime()) ? value + ' ms since epoch' : date.toISOString();
  #| }
