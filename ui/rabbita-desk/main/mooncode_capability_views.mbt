///|
fn render_mooncode_capability_panel(model : Model) -> @rabbita.Html {
  section(class="inspector-section", [
    h3("MoonCode Contract"),
    match model.mooncode_capabilities {
      Some(capabilities) =>
        div(class="mooncode-contract", [
          div(class="daemon-state", [
            info_row(
              "Version",
              "\{capabilities.component}.v\{capabilities.version}",
            ),
            info_row("Transport", capabilities.session_protocol.preferred_stream),
            info_row(
              "Target",
              capabilities.session_protocol.transport_target,
            ),
            info_row("Stream", capabilities.session_protocol.stream_endpoint),
            info_row(
              "Stream State",
              capabilities.session_protocol.stream_state_endpoint,
            ),
            info_row(
              "Command Queue",
              capabilities.session_protocol.command_queue_endpoint,
            ),
            info_row(
              "Runtime Replay",
              capabilities.session_protocol.runtime_replay_endpoint,
            ),
            info_row(
              "Runtime Claim",
              capabilities.session_protocol.runtime_claim_endpoint,
            ),
            info_row(
              "Event Sink",
              capabilities.session_protocol.runtime_event_ingest_endpoint,
            ),
            info_row(
              "Action Plan",
              capabilities.session_protocol.action_plan_endpoint,
            ),
            info_row(
              "Runtime Loop Options",
              capabilities.session_protocol.native_runtime_loop_options.stringify(),
            ),
            info_row(
              "Runtime",
              capabilities.runtime_contract.target_component +
              " / " +
              capabilities.runtime_contract.status,
            ),
            info_row("Engine", capabilities.engine_status.status),
            info_row("Runtime Mode", capabilities.engine_status.runtime_mode),
            info_row("Runtime", capabilities.engine_status.runtime_status),
            info_row(
              "Commands",
              capabilities.command_specs.length().to_string(),
            ),
            info_row("Tools", capabilities.tool_specs.length().to_string()),
            info_row("Future", capabilities.standalone.future_package),
            info_row("Core", capabilities.standalone.core_package),
            info_row("Projection", capabilities.standalone.projection_package),
            info_row("Host", capabilities.standalone.host_package),
          ]),
          div(
            class="mooncode-command-row",
            capabilities.session_protocol.commands.map(command => {
              span(class="option-chip", command)
            }),
          ),
          render_mooncode_engine_status(capabilities.engine_status),
          render_mooncode_standalone_boundary(
            capabilities.standalone_boundary,
          ),
          render_mooncode_runtime_contract(capabilities.runtime_contract),
          render_mooncode_tool_call_contract(
            capabilities.tool_call_contract,
          ),
          div(
            class="mooncode-tool-list",
            if capabilities.command_specs.length() == 0 {
              [p(class="status-line", "no command specs")]
            } else {
              capabilities.command_specs.map(spec =>
                render_mooncode_command_spec(spec)
              )
            },
          ),
          div(
            class="mooncode-tool-list",
            if capabilities.tool_specs.length() == 0 {
              [p(class="status-line", "no tool specs")]
            } else {
              capabilities.tool_specs.map(tool => render_mooncode_tool_spec(tool))
            },
          ),
          div(class="mooncode-output-roots", [
            small("Outputs"),
            p(capabilities.book_outputs.join(", ")),
          ]),
        ])
      None =>
        div(class="daemon-state", [
          info_row("Status", model.mooncode_status),
          info_row("Endpoint", "/api/mooncode/capabilities"),
        ])
    },
  ])
}

///|
fn render_mooncode_engine_status(
  engine : MoonCodeEngineStatus
) -> @rabbita.Html {
  let root_label = if engine.moonclaw_root == "" {
    "not configured"
  } else {
    engine.moonclaw_root
  }
  div(class="mooncode-engine-status", [
    div(class="mooncode-protocol-block", [
      div(class="mooncode-tool-head", [
        strong("Engine readiness"),
        span(
          class=if engine.ok {
            "record-kind good"
          } else {
            "record-kind warning"
          },
          engine.status,
        ),
      ]),
      p(engine.message),
      small("root: " + root_label),
      p(
        class="status-line",
        "runtime: " +
        engine.runtime_status +
        "; native runtime: " +
        (if engine.native_runtime_ready { "yes" } else { "no" }),
      ),
      p(
        class="status-line",
        "endpoints: " + engine.supported_endpoints.join(", "),
      ),
    ]),
    div(
      class="mooncode-engine-checks",
      engine.checks.map(check => render_mooncode_engine_check(check)),
    ),
  ])
}

///|
fn render_mooncode_engine_check(
  check : MoonCodeEngineCheck
) -> @rabbita.Html {
  let class_name = match check.status {
    "ready" => "mooncode-eval-check ok"
    "recorded" => "mooncode-eval-check recorded"
    "blocked" => "mooncode-eval-check missing"
    _ => "mooncode-eval-check missing"
  }
  div(class=class_name, [
    span(
      class=match check.status {
        "ready" => "record-kind good"
        "recorded" => "record-kind"
        _ => "record-kind warning"
      },
      check.status,
    ),
    div([
      strong(check.label),
      small(check.evidence),
    ]),
  ])
}

///|
fn render_mooncode_standalone_boundary(
  boundary : MoonCodeStandaloneBoundary
) -> @rabbita.Html {
  div(class="mooncode-runtime-contract", [
    div(class="mooncode-output-roots", [
      small("Standalone boundary"),
      p(
        "\{boundary.protocol}: \{boundary.core_package} -> \{boundary.runtime_package}",
      ),
    ]),
    div(class="daemon-state compact-state", [
      info_row("Core", boundary.core_package),
      info_row("Projection", boundary.moondesk_projection_package),
      info_row("MoonWiki Host", boundary.moonwiki_host_package),
      info_row("Runtime", boundary.runtime_package),
    ]),
    div(
      class="mooncode-tool-list",
      boundary.roles.map(role => render_mooncode_standalone_role(role)),
    ),
    ul(
      class="mooncode-evidence-list",
      boundary.rules.map(rule => li(rule)),
    ),
  ])
}

///|
fn render_mooncode_standalone_role(
  role : MoonCodeStandaloneRole
) -> @rabbita.Html {
  div(class="mooncode-tool-card", [
    div(class="mooncode-tool-head", [
      strong(role.id),
      span(class="record-kind", role.owner),
    ]),
    small(role.package_path),
    p(role.responsibility),
  ])
}

///|
fn render_mooncode_namespace_role(role : MoonCodeNamespaceRole) -> @rabbita.Html {
  div(class="mooncode-tool-card", [
    div(class="mooncode-tool-head", [
      strong(role.name),
      span(class="record-kind", role.id),
    ]),
    p(role.responsibility),
  ])
}

///|
fn render_mooncode_runtime_contract(
  contract : MoonCodeRuntimeContract
) -> @rabbita.Html {
  div(class="mooncode-runtime-contract", [
    div(class="mooncode-output-roots", [
      small("Runtime boundary"),
      p(
        "\{contract.reference} -> \{contract.target_component}; standalone as \{contract.standalone_component}",
      ),
    ]),
    div(class="mooncode-protocol-block", [
      div(class="mooncode-tool-head", [
        strong("Namespace roles"),
        span(class="record-kind", "one product boundary"),
      ]),
      div(
        class="mooncode-tool-list",
        contract.namespace_roles.map(role =>
          render_mooncode_namespace_role(role)
        ),
      ),
    ]),
    div(
      class="mooncode-tool-list",
      contract.components.map(component =>
        render_mooncode_runtime_component(component)
      ),
    ),
    div(class="mooncode-protocol-block", [
      div(class="mooncode-tool-head", [
        strong("Command protocol"),
        span(class="record-kind", contract.command_protocol.transport),
      ]),
      div(
        class="mooncode-command-row",
        contract.command_protocol.input_commands.map(command =>
          span(
            class="option-chip",
            command.command + " {" + command.required_fields.join(", ") + "}",
          )
        ),
      ),
      small(contract.command_protocol.ordering_rule),
      p(
        class="status-line",
        "events: " + contract.command_protocol.output_events.join(", "),
      ),
    ]),
    div(class="mooncode-protocol-block", [
      div(class="mooncode-tool-head", [
        strong("Session store"),
        span(class="record-kind", contract.session_store.owner),
      ]),
      p(contract.session_store.shape),
      small("resume: " + contract.session_store.resume_modes.join(", ")),
      p(class="status-line", contract.session_store.moondesk_projection),
    ]),
    render_mooncode_tool_contract(contract.tool_contract),
    div(class="mooncode-protocol-block", [
      div(class="mooncode-tool-head", [
        strong("Eval contract"),
        span(
          class="record-kind",
          contract.eval_contract.required_harnesses.join(" + "),
        ),
      ]),
      ul(
        class="mooncode-evidence-list",
        contract.eval_contract.minimum_evidence.map(item => li(item)),
      ),
      div(class="daemon-state compact-state", [
        info_row(
          "Harness Contract",
          contract.eval_contract.harness_contract_endpoint,
        ),
        info_row(
          "MoonCode Refs",
          contract.eval_contract.reference_paths.join(", "),
        ),
        info_row(
          "Native Owner",
          contract.eval_contract.native_eval_report.owner,
        ),
        info_row(
          "Native Endpoint",
          contract.eval_contract.native_eval_report.endpoint,
        ),
        info_row(
          "Transport",
          contract.eval_contract.native_eval_report.transport,
        ),
        info_row(
          "Status",
          contract.eval_contract.native_eval_report.status_values.join(", "),
        ),
      ]),
      small(contract.eval_contract.native_eval_report.normalization_rule),
      p(class="status-line", contract.eval_contract.current_gap),
    ]),
  ])
}

///|
fn render_mooncode_tool_contract(contract : MoonCodeToolContract) -> @rabbita.Html {
  div(class="mooncode-protocol-block", [
    div(class="mooncode-tool-head", [
      strong("Tool contract"),
      span(class="record-kind", contract.execution_owner),
    ]),
    p(
      "\{contract.supported_tools.length()} tools; approvals by \{contract.approval_owner}; artifacts by \{contract.artifact_owner}",
    ),
    div(
      class="mooncode-tool-list",
      contract.tools.map(tool => render_mooncode_tool_contract_spec(tool)),
    ),
    div(class="daemon-state compact-state", [
      info_row("Path Rule", contract.constraints.path_rule),
      info_row("Diff Rule", contract.constraints.diff_rule),
      info_row("Test Rule", contract.constraints.test_rule),
      info_row("Approval Rule", contract.constraints.approval_rule),
    ]),
    small(contract.constraints.extraction_rule),
  ])
}

///|
fn render_mooncode_tool_call_contract(
  contract : MoonCodeToolCallCommandContract
) -> @rabbita.Html {
  div(class="mooncode-protocol-block", [
    div(class="mooncode-tool-head", [
      strong("Tool-call contract"),
      span(class="record-kind", contract.runtime_owner),
      span(class="record-kind", contract.protocol),
    ]),
    p(
      "accepts " +
      contract.accepted_shapes.length().to_string() +
      " shapes; " +
      contract.supported_tools.length().to_string() +
      " bounded tools",
    ),
    div(
      class="mooncode-command-row",
      contract.supported_tools.map(tool => span(class="option-chip", tool)),
    ),
    ul(
      class="mooncode-evidence-list",
      contract.accepted_shapes.map(shape => li(shape)),
    ),
    div(class="daemon-state compact-state", [
      info_row("Owner", contract.owner),
      info_row("Runtime Owner", contract.runtime_owner),
      info_row("Reference", contract.reference),
    ]),
    small(contract.argument_rule),
    p(class="status-line", contract.unknown_tool_policy),
  ])
}

///|
fn render_mooncode_tool_contract_spec(
  tool : MoonCodeToolRuntimeContract
) -> @rabbita.Html {
  let badges : Array[@rabbita.Html] = [
    span(class="record-kind", tool.lane),
    span(class="record-kind", tool.approval),
  ]
  let badges = if tool.mutates_files {
    badges + [span(class="record-kind warning", "mutates files")]
  } else {
    badges
  }
  let badges = if tool.requires_review {
    badges + [span(class="record-kind", "review")]
  } else {
    badges
  }
  div(class="mooncode-tool-spec", [
    div(class="mooncode-tool-head", [strong(tool.id)] + badges),
    p(tool.safety_policy),
    small("inputs: " + mooncode_tool_field_summary(tool.input_fields)),
    p(class="status-line", "events: " + tool.output_events.join(", ")),
    small(tool.executable_boundary),
  ])
}

///|
fn mooncode_tool_field_summary(
  fields : Array[Json]
) -> String {
  if fields.length() == 0 {
    return "none"
  }
  fields
  .map(field =>
    if json_field_bool(field, "required", default=false) {
      json_field_string(field, "name", default="field") +
      ":" +
      json_field_string(field, "type", default="value")
    } else {
      json_field_string(field, "name", default="field") +
      "?:" +
      json_field_string(field, "type", default="value")
    }
  )
  .join(", ")
}

///|
fn render_mooncode_runtime_component(
  component : MoonCodeRuntimeComponent
) -> @rabbita.Html {
  div(class="mooncode-tool-spec", [
    div(class="mooncode-tool-head", [
      strong(component.id),
      span(class="record-kind", component.owner),
    ]),
    p(component.purpose),
    small(component.reference),
    p(class="status-line", component.moondesk_role),
  ])
}

///|
fn render_mooncode_command_spec(spec : MoonCodeCommandSpec) -> @rabbita.Html {
  div(class="mooncode-tool-spec", [
    div(class="mooncode-tool-head", [
      strong(spec.action),
      span(class="record-kind", spec.dispatch),
    ]),
    p(
      "approval: \{spec.approval}; lanes: \{spec.expected_lanes.join(", ")}",
    ),
    small("tools: \{spec.tool_hints.join(", ")}"),
  ])
}

///|
fn render_mooncode_tool_spec(tool : MoonCodeToolSpec) -> @rabbita.Html {
  div(class="mooncode-tool-spec", [
    div(class="mooncode-tool-head", [
      strong(tool.id),
      span(class="record-kind", tool.lane),
    ]),
    p(tool.purpose),
    small(
      "\{tool.owner} / approval: \{tool.approval} / outputs: \{tool.outputs.join(", ")}",
    ),
  ])
}
