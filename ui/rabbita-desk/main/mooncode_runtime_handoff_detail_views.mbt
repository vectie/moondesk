///|
fn render_mooncode_runtime_turn_packet(packet : Json?) -> @rabbita.Html {
  match packet {
    Some(packet) => {
      let endpoints = json_field_object_or_self(packet, "endpoints")
      div(class="mooncode-protocol-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Turn Packet"),
          span(
            class=mooncode_runtime_consumer_status_class(
              json_field_string(packet, "status", default="idle"),
            ),
            json_field_string(packet, "status", default="idle"),
          ),
          span(
            class=if json_field_bool(
              packet,
              "runtime_control_allows_turn",
              default=false,
            ) {
              "record-kind good"
            } else {
              "record-kind warning"
            },
            json_field_string(packet, "runtime_control_effect", default="none"),
          ),
        ]),
        div(class="mooncode-stats", [
          info_chip("Operation", json_field_string(packet, "operation", default="wait")),
          info_chip("Action", empty_label(json_field_string(packet, "action", default=""))),
          info_chip("Command", empty_label(json_field_string(packet, "command_id", default=""))),
          info_chip(
            "Claim",
            if json_field_bool(packet, "ready_to_claim", default=false) {
              "ready"
            } else {
              "no"
            },
          ),
          info_chip(
            "Ack",
            if json_field_bool(packet, "ready_to_ack", default=false) {
              "ready"
            } else {
              "no"
            },
          ),
        ]),
        div(class="daemon-state compact-state", [
          info_row("Claim", json_field_string(endpoints, "claim", default="")),
          info_row("Ack", json_field_string(endpoints, "ack", default="")),
          info_row(
            "Events",
            json_field_string(endpoints, "runtime_events", default=""),
          ),
          info_row(
            "Native",
            json_field_string(endpoints, "native_commands", default=""),
          ),
        ]),
        div(class="mooncode-output-roots", [
          small("Required proof events"),
          p(json_field_string_array_summary(packet, "required_events")),
        ]),
        p(
          class="mooncode-event-detail",
          json_field_string(packet, "next_step", default=""),
        ),
        small(json_field_string(packet, "safety_boundary", default="")),
      ])
    }
    None =>
      div(class="mooncode-protocol-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Turn Packet"),
          span(class="record-kind warning", "missing"),
        ]),
        p(class="status-line", "No runtime turn packet has been projected yet."),
      ])
  }
}

///|
fn render_mooncode_runtime_supervisor(supervisor : Json?) -> @rabbita.Html {
  match supervisor {
    Some(supervisor) => {
      let endpoints = json_field_object_or_self(supervisor, "endpoints")
      let readiness = json_field_object_or_self(supervisor, "readiness")
      let loop_steps = json_field_json_array_items(supervisor, "supervisor_loop")
      div(class="mooncode-protocol-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Supervisor"),
          span(
            class=if json_field_bool(
              supervisor,
              "ready_to_launch",
              default=false,
            ) {
              "record-kind good"
            } else {
              "record-kind warning"
            },
            if json_field_bool(supervisor, "ready_to_launch", default=false) {
              "launchable"
            } else {
              "blocked"
            },
          ),
          span(
            class="record-kind",
            json_field_string(supervisor, "mode", default="replay"),
          ),
        ]),
        div(class="mooncode-stats", [
          info_chip("Status", json_field_string(supervisor, "status", default="idle")),
          info_chip(
            "Action",
            empty_label(json_field_string(supervisor, "action", default="")),
          ),
          info_chip(
            "Command",
            empty_label(json_field_string(supervisor, "command_id", default="")),
          ),
          info_chip(
            "Scheduler",
            json_field_string(supervisor, "runtime_control_effect", default="none"),
          ),
          info_chip(
            "Readiness",
            json_field_string(readiness, "status", default="unknown"),
          ),
        ]),
        div(class="daemon-state compact-state", [
          info_row("Claim", json_field_string(endpoints, "claim", default="")),
          info_row("Ack", json_field_string(endpoints, "ack", default="")),
          info_row(
            "Events",
            json_field_string(endpoints, "runtime_events", default=""),
          ),
          info_row(
            "Supervisor",
            json_field_string(endpoints, "runtime_supervisor", default=""),
          ),
          info_row(
            "Session",
            json_field_string(endpoints, "session_store", default=""),
          ),
          info_row(
            "MoonClaw",
            empty_label(json_field_string(supervisor, "moonclaw_root", default="")),
          ),
        ]),
        if json_field_bool(supervisor, "ready_to_launch", default=false) {
          p(
            class="mooncode-event-detail",
            "MoonClaw can claim and execute this turn through the listed loop.",
          )
        } else {
          p(
            class="mooncode-event-detail",
            json_field_string(
              supervisor,
              "launch_blocked_reason",
              default="No launchable runtime command.",
            ),
          )
        },
        div(class="mooncode-output-roots", [
          small("Missing launch requirements"),
          p(
            if json_field_int(
              readiness,
              "missing_requirement_count",
              default=0,
            ) == 0 {
              "none"
            } else {
              json_field_string_array_summary(
                readiness,
                "missing_requirements",
              )
            },
          ),
        ]),
        div(class="mooncode-consumer-loop", [
          small("Supervisor loop"),
          ul(
            class="mooncode-evidence-list",
            loop_steps.map(step => {
              let http_method = json_field_string(step, "method", default="")
              let endpoint = json_field_string(
                step,
                "endpoint",
                default=json_field_string(step, "id", default=""),
              )
              li("\{http_method} \{endpoint}")
            }),
          ),
        ]),
        small(json_field_string(supervisor, "safety_boundary", default="")),
      ])
    }
    None =>
      div(class="mooncode-protocol-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Supervisor"),
          span(class="record-kind warning", "missing"),
        ]),
        p(
          class="status-line",
          "This handoff predates the runtime supervisor launch packet.",
        ),
      ])
  }
}

///|
fn render_mooncode_runtime_execution_plan(plan : Json?) -> @rabbita.Html {
  match plan {
    Some(plan) =>
      div(class="mooncode-protocol-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Execution Plan"),
          span(
            class=mooncode_runtime_consumer_status_class(
              json_field_string(plan, "status", default="idle"),
            ),
            json_field_string(plan, "status", default="idle"),
          ),
        ]),
        div(class="mooncode-stats", [
          info_chip("Operation", json_field_string(plan, "operation", default="wait")),
          info_chip("Action", empty_label(json_field_string(plan, "action", default=""))),
          info_chip("Command", empty_label(json_field_string(plan, "command_id", default=""))),
          info_chip(
            "Execute",
            if json_field_bool(plan, "ready_to_execute", default=false) {
              "ready"
            } else {
              "no"
            },
          ),
          info_chip(
            "Proof",
            json_field_int(plan, "required_event_count", default=0).to_string(),
          ),
        ]),
        div(class="daemon-state compact-state", [
          info_row("Target", empty_label(json_field_string(plan, "target", default=""))),
          info_row(
            "Context",
            empty_label(json_field_string(plan, "context_path", default="")),
          ),
          info_row("Claim", json_field_string(plan, "claim_endpoint", default="")),
          info_row("Ack", json_field_string(plan, "ack_endpoint", default="")),
          info_row(
            "Events",
            json_field_string(plan, "runtime_event_ingest_endpoint", default=""),
          ),
          info_row(
            "Native",
            json_field_string(plan, "native_command_endpoint", default=""),
          ),
        ]),
        div(class="mooncode-output-roots", [
          small("Required proof events"),
          p(json_field_string_array_summary(plan, "required_events")),
        ]),
        p(class="mooncode-event-detail", json_field_string(plan, "next_step", default="")),
        small(json_field_string(plan, "safety_boundary", default="")),
      ])
    None =>
      div(class="mooncode-protocol-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Execution Plan"),
          span(class="status-warn", "missing"),
        ]),
        p(
          class="status-line",
          "This handoff predates the runtime execution plan. Queue or refresh a MoonCode command to regenerate it.",
        ),
      ])
  }
}

///|
fn render_mooncode_runtime_consumer(
  consumer : MoonCodeRuntimeConsumer?,
) -> @rabbita.Html {
  match consumer {
    Some(consumer) =>
      div(class="mooncode-protocol-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Consumer"),
          span(
            class=mooncode_runtime_consumer_status_class(consumer.status),
            consumer.status,
          ),
        ]),
        div(class="mooncode-stats", [
          info_chip("Claimable", consumer.claimable_command_count.to_string()),
          info_chip("Claimed", consumer.claimed_command_count.to_string()),
          info_chip("Pending", consumer.pending_command_count.to_string()),
          info_chip("Invalid", consumer.invalid_command_count.to_string()),
          info_chip(
            "Claim",
            if consumer.ready_to_claim { "ready" } else { "no" },
          ),
          info_chip(
            "Replay",
            if consumer.ready_to_replay { "ready" } else { "no" },
          ),
        ]),
        p(consumer.next_action),
        div(class="daemon-state compact-state", [
          info_row("Claim", consumer.endpoints.runtime_claim),
          info_row("Replay", consumer.endpoints.runtime_replay),
          info_row("Events", consumer.endpoints.runtime_events),
          info_row("Runtime Feed", consumer.endpoints.runtime_commands),
          info_row("Stream", consumer.endpoints.stream),
          info_row("Native Commands", consumer.endpoints.native_commands),
          info_row("Native Eval", consumer.endpoints.native_eval_report),
        ]),
        div(class="mooncode-consumer-loop", [
          small("Required loop"),
          ul(
            class="mooncode-evidence-list",
            consumer.required_loop.map(step => li(step)),
          ),
        ]),
        small(consumer.safety_boundary),
      ])
    None =>
      div(class="mooncode-protocol-block runtime-consumer-block", [
        div(class="mooncode-tool-head", [
          strong("Runtime Consumer"),
          span(class="record-kind warning", "missing"),
        ]),
        p(
          "This handoff predates the runtime consumer contract. Refresh the session or enqueue a MoonCode command to regenerate it.",
        ),
      ])
  }
}

///|
fn mooncode_runtime_consumer_status_class(status : String) -> String {
  match status {
    "claim-ready" => "record-kind good"
    "delivered" => "record-kind good"
    "lease-held" => "record-kind"
    "replay-ready" => "record-kind"
    "idle" => "record-kind"
    _ => "record-kind warning"
  }
}
