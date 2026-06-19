///|
fn render_mooncode_runtime_claim_panel(
  dispatch : Dispatch[Msg],
  model : Model,
) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-claim-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "runtime lease state"),
        h3("Runtime Claims"),
      ]),
      span(class="record-kind", model.mooncode_runtime_claim_status),
    ]),
    div(class="toolbar-actions", [
      button(
        class="secondary-button",
        on_click=dispatch(ClaimMoonCodeRuntime(false)),
        "Claim Next",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(ClaimMoonCodeRuntime(true)),
        "Force Claim",
      ),
      button(
        class="primary-button",
        on_click=dispatch(RunMoonCodeRuntimeLoop),
        "Run Native Loop",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(StartMoonCodeRuntimeService),
        "Start Service",
      ),
      button(
        class="secondary-button",
        on_click=dispatch(RunMoonCodeCommand("cancel")),
        "Stop Service",
      ),
    ]),
    render_mooncode_runtime_service_state(model),
    match model.mooncode_runtime_claim {
      Some(state) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", state.command_count.to_string()),
            info_chip("Claimable", state.claimable_command_count.to_string()),
            info_chip("Claimed", state.claimed_command_count.to_string()),
            info_chip("Delivered", state.delivered_command_count.to_string()),
            info_chip("Failed", state.failed_command_count.to_string()),
            info_chip("Invalid", state.invalid_command_count.to_string()),
            info_chip(
              "Auth Blocked",
              state.tool_authorization_blocked_command_count.to_string(),
            ),
            info_chip(
              "Order Blocked",
              state.order_blocked_command_count.to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Claim Endpoint", state.claim_endpoint),
            info_row("Ack Endpoint", state.ack_endpoint),
            info_row("Runtime Feed", state.runtime_command_log_path),
            info_row("Receipt Log", state.runtime_receipt_log_path),
          ]),
          if state.claimed_commands.length() == 0 &&
            state.claimable_commands.length() == 0 &&
            state.tool_authorization_blocked_commands.length() == 0 &&
            state.order_blocked_commands.length() == 0 {
            p(class="status-line", "no runtime commands are leased or claimable")
          } else {
            div(
              class="mooncode-review-list runtime-claim-list",
              mooncode_recent_claim_items(
                state.claimed_commands,
                state.claimable_commands,
                state.tool_authorization_blocked_commands,
                state.order_blocked_commands,
              ).map(item =>
                render_mooncode_runtime_claim_item(dispatch, item)
              ),
            )
          },
          small(class="status-line", state.lease_policy),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime claim state has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn render_mooncode_runtime_service_state(model : Model) -> @rabbita.Html {
  match model.mooncode_runtime_event_sink {
    Some(sink) if sink.session_id == model.selected_mooncode_session_id => {
      let service = sink.runtime_service
      div(class="daemon-state compact-state runtime-service-state", [
        info_row("Service", "\{service.status} / \{empty_label(service.service_id)}"),
        info_row("Active", if service.active { "yes" } else { "no" }),
        info_row("Started", empty_label(service.started_at)),
        info_row("Finished", empty_label(service.finished_at)),
        info_row("Stopped By", empty_label(service.stopped_by)),
        info_row(
          "Turns",
          "\{service.ran_turn_count} ran, \{service.failed_turn_count} failed",
        ),
        info_row(
          "Lifecycle",
          "\{service.started_count} started, \{service.finished_count} finished, \{service.failed_count} failed",
        ),
        info_row("Owner", empty_label(service.owner)),
        if service.detail == "" {
          span(class="hidden-inline", "")
        } else {
          p(class="mooncode-event-detail", service.detail)
        },
        if service.control_hint == "" {
          span(class="hidden-inline", "")
        } else {
          p(class="status-line", service.control_hint)
        },
      ])
    }
    _ => p(
      class="status-line",
      "Runtime service state appears after MoonCode runtime events are loaded.",
    )
  }
}

///|
fn mooncode_recent_claim_items(
  claimed : Array[MoonCodeRuntimeClaimItem],
  claimable : Array[MoonCodeRuntimeClaimItem],
  auth_blocked : Array[MoonCodeRuntimeClaimItem],
  order_blocked : Array[MoonCodeRuntimeClaimItem],
) -> Array[MoonCodeRuntimeClaimItem] {
  let items : Array[MoonCodeRuntimeClaimItem] = []
  for item in claimable {
    if items.length() < 8 {
      items.push(item)
    }
  }
  for item in auth_blocked {
    if items.length() < 8 {
      items.push(item)
    }
  }
  for item in claimed {
    if items.length() < 8 {
      items.push(item)
    }
  }
  for item in order_blocked {
    if items.length() < 8 {
      items.push(item)
    }
  }
  items
}

///|
fn render_mooncode_runtime_claim_item(
  dispatch : Dispatch[Msg],
  item : MoonCodeRuntimeClaimItem
) -> @rabbita.Html {
  div(class="mooncode-review-item " + mooncode_runtime_claim_item_class(item), [
    div(class="mooncode-review-head", [
      div([
        strong(item.action + " -> " + item.claim_status),
        small(
          if item.claimed_at == "" {
            item.created_at
          } else {
            item.consumer_id + " / " + item.claimed_at
          },
        ),
      ]),
      div(
        class="toolbar-actions",
        render_mooncode_runtime_claim_actions(dispatch, item),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Control", item.control),
      info_chip("Serve", item.code_command),
      info_chip("Lease", empty_label(item.lease_expires_at)),
      info_chip("Auth", empty_label(item.tool_authorization_state)),
      info_chip(
        "Tool Run",
        if item.runtime_may_execute_tools { "allowed" } else { "blocked" },
      ),
    ]),
    if item.tool_authorization_blocked {
      p(
        class="status-line",
        "Tool authorization blocks this command: " +
        empty_label(item.tool_authorization_blocked_reason),
      )
    } else if item.blocked_by_command_id != "" {
      p(
        class="status-line",
        "Waiting behind " + item.blocked_by_command_id + " (" +
        empty_label(item.blocked_by_status) + ")",
      )
    } else {
      span(class="sr-only", "")
    },
    if item.target == "" {
      code(item.command_id)
    } else {
      code(item.target)
    },
    render_mooncode_runtime_execution_summary(item.runtime_command),
    small(class="status-line", item.ack_endpoint),
  ])
}

///|
fn render_mooncode_runtime_claim_actions(
  dispatch : Dispatch[Msg],
  item : MoonCodeRuntimeClaimItem
) -> Array[@rabbita.Html] {
  let actions : Array[@rabbita.Html] = [
    span(class="record-kind", item.receipt_status),
  ]
  if item.claim_status == "claimed" {
    actions.push(
      button(
        class="secondary-button",
        on_click=dispatch(
          AckMoonCodeRuntimeCommand(item.command_id, "runtime-acknowledged"),
        ),
        "Ack",
      ),
    )
    actions.push(
      button(
        class="secondary-button",
        on_click=dispatch(
          AckMoonCodeRuntimeCommand(item.command_id, "runtime-completed"),
        ),
        "Complete",
      ),
    )
    actions.push(
      button(
        class="secondary-button",
        on_click=dispatch(AckMoonCodeRuntimeCommand(item.command_id, "failed")),
        "Fail",
      ),
    )
  }
  actions
}

///|
fn mooncode_runtime_claim_item_class(item : MoonCodeRuntimeClaimItem) -> String {
  match item.claim_status {
    "claimed" => "running"
    "claimable" => "queued"
    "delivered" => "accepted"
    "blocked-tool-authorization" | "failed" | "invalid" => "rejected"
    "blocked-by-prior-command" => "running"
    _ => "queued"
  }
}

