///|
fn render_mooncode_runtime_replay_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-replay-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "MoonCode serve replay"),
        h3("Runtime Replay"),
      ]),
      span(class="record-kind", model.mooncode_runtime_replay_status),
    ]),
    match model.mooncode_runtime_replay {
      Some(state) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", state.command_count.to_string()),
            info_chip("Pending", state.pending_command_count.to_string()),
            info_chip("Delivered", state.delivered_command_count.to_string()),
            info_chip("Claimed", state.claimed_command_count.to_string()),
            info_chip("Failed", state.failed_receipt_count.to_string()),
            info_chip("Invalid", state.invalid_command_count.to_string()),
            info_chip("Replay", if state.replay_ready { "ready" } else { "idle" }),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Runtime Feed", state.runtime_command_log_path),
            info_row("Receipt Log", state.runtime_receipt_log_path),
            info_row("First Pending", state.first_pending_index.to_string()),
            info_row("First Invalid", empty_label(state.first_invalid_command_id)),
          ]),
          if state.pending_mooncode_jsonl == "" {
            p(class="status-line", "no pending MoonCode JSONL commands")
          } else {
            div(class="mooncode-output-roots", [
              small("Pending MoonCode JSONL"),
              pre(
                class="source-block compact",
                code(state.pending_mooncode_jsonl),
              ),
            ])
          },
          if state.pending_commands.length() == 0 {
            p(class="status-line", "runtime replay has no pending commands")
          } else {
            div(
              class="mooncode-review-list runtime-replay-list",
              mooncode_recent_replay_items(state.pending_commands).map(item =>
                render_mooncode_runtime_replay_item(item)
              ),
            )
          },
          small(class="status-line", state.replay_policy),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime replay state has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_recent_replay_items(
  items : Array[MoonCodeRuntimeReplayItem]
) -> Array[MoonCodeRuntimeReplayItem] {
  let recent : Array[MoonCodeRuntimeReplayItem] = []
  let mut index = 0
  while index < items.length() && recent.length() < 8 {
    recent.push(items[index])
    index += 1
  }
  recent
}

///|
fn render_mooncode_runtime_replay_item(
  item : MoonCodeRuntimeReplayItem
) -> @rabbita.Html {
  let command_ok = json_field_bool(item.decode_report, "ok", default=false)
  div(class="mooncode-review-item " + mooncode_runtime_replay_item_class(item), [
    div(class="mooncode-review-head", [
      div([
        strong(item.action + " -> " + item.replay_status),
        small(item.code_command + " / " + item.created_at),
      ]),
      span(
        class=if command_ok { "record-kind good" } else { "record-kind warning" },
        if command_ok { "command valid" } else { "decode error" },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Receipt", item.receipt_status),
      info_chip("Control", item.control),
      info_chip(
        "Lease",
        if item.previous_claim_expired { "expired" } else { "current" },
      ),
      info_chip("Proof", item.proof_event_count.to_string()),
      info_chip("Events", item.normalized_event_count.to_string() + "/" + item.submitted_event_count.to_string()),
    ]),
    render_mooncode_runtime_proof_gate(
      json_field(item.latest_receipt, "proof_gate"),
    ),
    if item.target == "" {
      code(item.command_id)
    } else {
      code(item.target)
    },
    p(
      class="mooncode-event-detail",
      if command_ok {
        mooncode_runtime_replay_item_detail(item)
      } else {
        json_field_string(item.decode_report, "error", default="Invalid protocol command")
      },
    ),
    small(class="status-line", item.command_id),
  ])
}

///|
fn mooncode_runtime_replay_item_detail(
  item : MoonCodeRuntimeReplayItem
) -> String {
  let proof_gate = json_field(item.latest_receipt, "proof_gate")
  let proof_status = mooncode_runtime_proof_gate_status(proof_gate)
  if item.replay_status == "missing-proof-pending-retry" ||
    item.receipt_status == "proof-missing" {
    let missing = mooncode_runtime_proof_gate_missing_label(proof_gate)
    if missing == "" {
      "Runtime requested completion, but required command-scoped proof is missing."
    } else {
      "Runtime requested completion, but missing proof: " + missing
    }
  } else if proof_status == "passed" {
    "Runtime completion proof gate passed."
  } else if item.proof_event_count > 0 {
    let lanes = json_field_string_array_items(
      item.runtime_event_summary, "proof_lanes",
    )
    if lanes.length() > 0 {
      "Runtime acknowledgement submitted proof lanes: " + lanes.join(", ")
    } else {
      "Runtime acknowledgement submitted \{item.proof_event_count.to_string()} proof event(s)."
    }
  } else if item.replay_status == "delivered" {
    "Delivered without attached proof events; inspect runtime logs or eval evidence if review gates remain blocked."
  } else {
    "Ready for MoonClaw runtime consumption."
  }
}

///|
fn mooncode_runtime_replay_item_class(item : MoonCodeRuntimeReplayItem) -> String {
  match item.replay_status {
    "delivered" => "accepted"
    "claimed" => "running"
    "pending" | "failed-pending-retry" | "expired-claim-pending-retry" =>
      "queued"
    "missing-proof-pending-retry" => "rejected"
    "blocked-invalid" => "rejected"
    _ => "queued"
  }
}
