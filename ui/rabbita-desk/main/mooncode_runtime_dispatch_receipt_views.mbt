///|
fn render_mooncode_runtime_dispatch_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-dispatch-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "runtime delivery audit"),
        h3("Dispatch Receipts"),
      ]),
      span(class="record-kind", model.mooncode_runtime_dispatch_status),
    ]),
    match model.mooncode_runtime_dispatch {
      Some(state) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", state.runtime_command_count.to_string()),
            info_chip("Receipts", state.runtime_dispatch_count.to_string()),
            info_chip("Pending", state.runtime_dispatch_pending_count.to_string()),
            info_chip("Mode", state.dispatch_mode),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Runtime Feed", state.runtime_command_log_path),
            info_row("Dispatch Log", state.runtime_dispatch_log_path),
            info_row("Session", state.session_id),
            info_row("Runtime", empty_label(state.runtime_session_id)),
          ]),
          if state.pending_command_ids.length() == 0 {
            p(class="status-line", "all runtime commands have dispatch receipts")
          } else {
            div(class="mooncode-output-roots", [
              small("Pending command ids"),
              p(state.pending_command_ids.join(", ")),
            ])
          },
          if state.dispatch_receipts.length() == 0 {
            p(class="status-line", "no dispatch receipts recorded yet")
          } else {
            div(
              class="mooncode-review-list runtime-dispatch-list",
              mooncode_recent_dispatch_receipts(state.dispatch_receipts).map(receipt =>
                render_mooncode_runtime_dispatch_receipt(receipt)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime dispatch state has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_recent_dispatch_receipts(
  receipts : Array[MoonCodeRuntimeDispatchReceipt]
) -> Array[MoonCodeRuntimeDispatchReceipt] {
  let recent : Array[MoonCodeRuntimeDispatchReceipt] = []
  let mut index = receipts.length()
  let mut emitted = 0
  while index > 0 && emitted < 8 {
    index -= 1
    recent.push(receipts[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_runtime_dispatch_receipt(
  receipt : MoonCodeRuntimeDispatchReceipt
) -> @rabbita.Html {
  let target = json_field_string(receipt.runtime_command, "target", default="")
  div(class="mooncode-review-item " + mooncode_runtime_dispatch_state(receipt), [
    div(class="mooncode-review-head", [
      div([
        strong(receipt.action + " -> " + receipt.status),
        small(receipt.dispatch_mode + " / " + receipt.created_at),
      ]),
      span(
        class=if receipt.mooncode_command_valid {
          "record-kind good"
        } else {
          "record-kind"
        },
        if receipt.mooncode_command_valid { "command valid" } else { "command pending" },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Dispatch", receipt.dispatch),
      info_chip("Ack Order", mooncode_ack_order_status_label(receipt)),
      info_chip(
        "Requested",
        mooncode_optional_text_label(receipt.requested_status),
      ),
      info_chip(
        "Native",
        if receipt.native_mooncode_endpoint == "" {
          "none"
        } else {
          "ready"
        },
      ),
    ]),
    if target == "" {
      code(receipt.command_id)
    } else {
      code(target)
    },
    render_mooncode_runtime_ack_audit(receipt),
    render_mooncode_runtime_proof_gate(receipt.proof_gate),
    render_mooncode_runtime_execution_summary(receipt.runtime_command),
    p(class="mooncode-event-detail", receipt.detail),
    small(class="status-line", receipt.dispatch_id),
  ])
}

///|
fn mooncode_ack_order_status_label(
  receipt : MoonCodeRuntimeDispatchReceipt
) -> String {
  match receipt.ack_order_status {
    Some(status) => if status == "" { "n/a" } else { status }
    None => "n/a"
  }
}

///|
fn mooncode_optional_text_label(value : String?) -> String {
  match value {
    Some(text) => if text == "" { "none" } else { text }
    None => "none"
  }
}

///|
fn mooncode_optional_bool_label(value : Bool?) -> String {
  match value {
    Some(true) => "yes"
    Some(false) => "no"
    None => "n/a"
  }
}

///|
fn render_mooncode_runtime_ack_audit(
  receipt : MoonCodeRuntimeDispatchReceipt
) -> @rabbita.Html {
  match receipt.ack_order_status {
    Some(_) =>
      div(class="daemon-state compact-state", [
        info_row(
          "Previous Dispatch",
          mooncode_optional_text_label(receipt.previous_dispatch_status),
        ),
        info_row(
          "Previous Claim",
          mooncode_optional_text_label(receipt.previous_claim_id),
        ),
        info_row(
          "Previous Consumer",
          mooncode_optional_text_label(receipt.previous_consumer_id),
        ),
        info_row(
          "Same Consumer",
          mooncode_optional_bool_label(receipt.claimed_by_same_consumer),
        ),
        render_mooncode_runtime_ack_blocker(receipt.order_blocker),
      ])
    None => span(class="hidden-inline", "")
  }
}

///|
fn render_mooncode_runtime_ack_blocker(blocker : Json?) -> @rabbita.Html {
  match blocker {
    Some(value) => {
      let command_id = json_field_string(value, "command_id", default="")
      if command_id == "" {
        span(class="hidden-inline", "")
      } else {
        info_row(
          "Order Blocker",
          "\{command_id} / \{json_field_string(value, "status", default="blocked")}",
        )
      }
    }
    None => span(class="hidden-inline", "")
  }
}

///|
fn render_mooncode_runtime_proof_gate(gate : Json?) -> @rabbita.Html {
  match gate {
    Some(value) => {
      let kind = json_field_string(value, "kind", default="")
      if kind == "" {
        span(class="hidden-inline", "")
      } else {
        let status = json_field_string(value, "status", default="unknown")
        let blocked = json_field_bool(value, "completion_blocked", default=false)
        let missing = mooncode_runtime_proof_gate_missing_label(Some(value))
        let failed = json_field_string_array_items(
          value, "failed_required_events",
        )
        let gate_class = if blocked {
          "blocked"
        } else if status == "passed" {
          "passed"
        } else {
          "idle"
        }
        let badge_class = if blocked {
          "record-kind warning"
        } else if status == "passed" {
          "record-kind good"
        } else {
          "record-kind"
        }
        let missing_text = if missing == "" {
          "missing none"
        } else {
          "missing " + missing
        }
        let failed_text = if failed.length() == 0 {
          "failed none"
        } else {
          "failed " + failed.join(", ")
        }
        div(class="mooncode-proof-gate " + gate_class, [
            div(class="mooncode-tool-head", [
              strong("Completion proof"),
              span(class=badge_class, status),
            ]),
            div(class="mooncode-stats", [
              info_chip(
                "Required",
                json_field_int(value, "required_event_count", default=0).to_string(),
              ),
              info_chip(
                "Proven",
                json_field_int(value, "proven_required_event_count", default=0).to_string(),
              ),
              info_chip(
                "Missing",
                json_field_int(value, "missing_required_event_count", default=0).to_string(),
              ),
              info_chip(
                "Failed",
                json_field_int(value, "failed_required_event_count", default=0).to_string(),
              ),
            ]),
            if missing == "" && failed.length() == 0 {
              small("Required command-scoped proof is satisfied or not required.")
            } else {
              small(
                [missing_text, failed_text].join(" / "),
              )
            },
          ])
      }
    }
    None => span(class="hidden-inline", "")
  }
}

///|
fn mooncode_runtime_proof_gate_status(gate : Json?) -> String {
  match gate {
    Some(value) => json_field_string(value, "status", default="")
    None => ""
  }
}

///|
fn mooncode_runtime_proof_gate_missing_label(gate : Json?) -> String {
  match gate {
    Some(value) => {
      let missing = json_field_string_array_items(
        value, "missing_required_events",
      )
      if missing.length() == 0 {
        ""
      } else {
        missing.join(", ")
      }
    }
    None => ""
  }
}

///|
fn mooncode_runtime_dispatch_state(
  receipt : MoonCodeRuntimeDispatchReceipt
) -> String {
  match receipt.ack_order_status {
    Some("blocked-by-prior-command") | Some("consumer-mismatch") => return "rejected"
    Some("matching-claim") | Some("already-delivered") => return "accepted"
    _ => ()
  }
  match receipt.status {
    "native-dispatched" | "runtime-acknowledged" | "runtime-completed" =>
      "accepted"
    "failed" => "rejected"
    "recorded" => "queued"
    _ => "queued"
  }
}
