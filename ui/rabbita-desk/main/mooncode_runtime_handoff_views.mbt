///|
fn render_mooncode_runtime_handoff_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-handoff-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "standalone runtime contract"),
        h3("Runtime Handoff"),
      ]),
      span(class="record-kind", model.mooncode_runtime_handoff_status),
    ]),
    match model.mooncode_runtime_handoff {
      Some(handoff) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", handoff.command_count.to_string()),
            info_chip(
              "Runtime",
              if handoff.engine.native_runtime_ready { "native" } else { "replay" },
            ),
            info_chip(
              "Daemon",
              if handoff.engine.daemon_running { "running" } else { "stopped" },
            ),
            info_chip(
              "Eval",
              "\{handoff.summary.eval_passed_check_count}/\{handoff.summary.eval_check_count}",
            ),
            info_chip(
              "Missing",
              handoff.summary.eval_missing_check_count.to_string(),
            ),
            info_chip(
              "Dispatches",
              handoff.summary.runtime_dispatch_count.to_string(),
            ),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Status", handoff.status),
            info_row("Manifest", empty_label(handoff.manifest_path)),
            info_row("Workspace", empty_label(handoff.workspace_root)),
            info_row("Runtime", empty_label(handoff.runtime_session_id)),
            info_row("Dispatch", handoff.engine.dispatch_mode),
            info_row("Daemon", handoff.engine.daemon_status),
            info_row("MoonClaw", empty_label(handoff.engine.moonclaw_root)),
          ]),
          render_mooncode_runtime_consumer(handoff.runtime_consumer),
          render_mooncode_runtime_turn_packet(handoff.runtime_turn_packet),
          render_mooncode_runtime_supervisor(handoff.runtime_supervisor),
          render_mooncode_runtime_execution_plan(
            handoff.runtime_execution_plan,
          ),
          div(class="daemon-state compact-state", [
            info_row(
              "Session Snapshot",
              handoff.resume_contract.session_snapshot_path,
            ),
            info_row(
              "Session Store",
              handoff.resume_contract.session_store_endpoint,
            ),
            info_row("Command Log", handoff.resume_contract.command_log_path),
            info_row(
              "Runtime Feed",
              handoff.resume_contract.runtime_command_log_path,
            ),
            info_row(
              "Runtime Dispatch",
              handoff.resume_contract.runtime_dispatch_log_path,
            ),
            info_row("Event Log", handoff.resume_contract.event_log_path),
            info_row("Stream", handoff.resume_contract.stream_endpoint),
            info_row(
              "Event Sink",
              handoff.resume_contract.runtime_event_ingest_endpoint,
            ),
            info_row("Queue", handoff.resume_contract.command_queue_endpoint),
            info_row(
              "Runtime Queue",
              handoff.resume_contract.runtime_command_feed_endpoint,
            ),
            info_row(
              "Dispatch State",
              handoff.resume_contract.runtime_dispatch_endpoint,
            ),
            info_row(
              "Runtime Replay",
              handoff.resume_contract.runtime_replay_endpoint,
            ),
            info_row(
              "Runtime Claim",
              handoff.resume_contract.runtime_claim_endpoint,
            ),
            info_row(
              "Action Plan",
              handoff.resume_contract.action_plan_endpoint,
            ),
            info_row(
              "Native Command",
              handoff.resume_contract.native_command_endpoint,
            ),
            info_row("Native Eval", handoff.resume_contract.native_eval_endpoint),
          ]),
          div(class="mooncode-output-roots", [
            small("MoonBook output roots"),
            p(handoff.book_output_roots.join(", ")),
          ]),
          p(class="mooncode-event-detail", handoff.next_runtime_step),
          small(class="status-line", handoff.resume_contract.ordering_rule),
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime handoff has been loaded for this session yet.",
        )
    },
  ])
}
