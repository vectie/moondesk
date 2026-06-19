///|
fn render_mooncode_runtime_execution_summary(command : Json) -> @rabbita.Html {
  match json_field(command, "execution_summary") {
    Some(summary) => {
      let tool_sequence = json_field_string_array_items(
        summary, "tool_sequence",
      )
      let expected_events = json_field_string_array_items(
        summary, "expected_events",
      )
      let required_outputs = json_field_string_array_items(
        summary, "required_outputs",
      )
      let execution_checklist = json_field_json_array_items(
        summary, "execution_checklist",
      )
      let tool_policies = json_field_json_array_items(summary, "tool_policies")
      let recommended = json_field_string_array_items(
        summary, "recommended_commands",
      )
      div(class="mooncode-runtime-summary", [
        div(class="mooncode-stats", [
          info_chip(
            "Plan",
            json_field_string(summary, "action", default="command"),
          ),
          info_chip(
            "Tools",
            if tool_sequence.length() == 0 {
              "none"
            } else {
              tool_sequence.join(" -> ")
            },
          ),
          info_chip("Events", expected_events.length().to_string()),
          info_chip("Outputs", required_outputs.length().to_string()),
          info_chip(
            "Checklist",
            json_field_int(
              summary,
              "checklist_count",
              default=execution_checklist.length(),
            ).to_string(),
          ),
          info_chip(
            "Review",
            if json_field_bool(summary, "review_required", default=false) {
              "required"
            } else {
              "not required"
            },
          ),
          info_chip(
            "Auth",
            empty_label(
              json_field_string(
                summary,
                "tool_authorization_state",
                default="",
              ),
            ),
          ),
          info_chip(
            "Tool Run",
            if json_field_bool(summary, "runtime_may_execute_tools", default=true) {
              "allowed"
            } else {
              "blocked"
            },
          ),
        ]),
        if recommended.length() == 0 {
          span(class="hidden-inline", "")
        } else {
          div(class="mooncode-output-roots", [
            small("Recommended commands"),
            p(recommended.join(", ")),
          ])
        },
        div(class="mooncode-output-roots", [
          small("Required outputs"),
          p(if required_outputs.length() == 0 {
            "none"
          } else {
            required_outputs.join(", ")
          }),
        ]),
        render_mooncode_tool_policy_list(tool_policies),
        render_mooncode_execution_checklist(execution_checklist),
        div(class="daemon-state compact-state", [
          info_row(
            "Events",
            if expected_events.length() == 0 {
              "none"
            } else {
              expected_events.join(", ")
            },
          ),
          info_row(
            "Event Sink",
            empty_label(json_field_string(summary, "event_sink", default="")),
          ),
          info_row(
            "Ack Sink",
            empty_label(json_field_string(summary, "ack_sink", default="")),
          ),
        ]),
      ])
    }
    None => span(class="hidden-inline", "")
  }
}

///|
fn render_mooncode_tool_policy_list(policies : Array[Json]) -> @rabbita.Html {
  if policies.length() == 0 {
    span(class="hidden-inline", "")
  } else {
    div(class="mooncode-tool-policy-list", [
      small("Tool policies"),
      div(
        class="mooncode-review-list compact-list",
        mooncode_tool_policy_limit(policies).map(render_mooncode_tool_policy),
      ),
    ])
  }
}

///|
fn mooncode_tool_policy_limit(policies : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = 0
  while index < policies.length() && recent.length() < 6 {
    recent.push(policies[index])
    index += 1
  }
  recent
}

///|
fn render_mooncode_tool_policy(policy : Json) -> @rabbita.Html {
  let required_inputs = json_field_string_array_items(policy, "required_inputs")
  let proof_events = json_field_string_array_items(policy, "proof_events")
  let guardrails = json_field_string_array_items(policy, "guardrails")
  div(class="mooncode-tool-policy", [
    div(class="mooncode-tool-head", [
      strong(json_field_string(policy, "tool", default="tool")),
      span(
        class=if json_field_bool(policy, "mutates_files", default=false) {
          "record-kind warning"
        } else {
          "record-kind good"
        },
        json_field_string(policy, "approval", default="policy"),
      ),
    ]),
    small(
      [
        "inputs " + mooncode_inline_list(required_inputs),
        "proof " + mooncode_inline_list(proof_events),
      ].join(" / "),
    ),
    p(
      if guardrails.length() == 0 {
        "Runtime must enforce this tool before execution."
      } else {
        guardrails.join("; ")
      },
    ),
  ])
}

///|
fn mooncode_inline_list(items : Array[String]) -> String {
  if items.length() == 0 {
    "none"
  } else {
    items.join(", ")
  }
}

///|
fn render_mooncode_execution_checklist(items : Array[Json]) -> @rabbita.Html {
  if items.length() == 0 {
    span(class="hidden-inline", "")
  } else {
    div(class="mooncode-execution-checklist", [
      small("Runtime checklist"),
      div(
        class="mooncode-review-list compact-list",
        items.map(item => render_mooncode_execution_checklist_item(item)),
      ),
    ])
  }
}

///|
fn render_mooncode_execution_checklist_item(item : Json) -> @rabbita.Html {
  let required_event = json_field_string(item, "required_event", default="")
  let required_output = json_field_string(item, "required_output", default="")
  let endpoint = json_field_string(item, "endpoint", default="")
  div(class="mooncode-checklist-row", [
    span(
      class="record-kind",
      json_field_int(item, "index", default=0).to_string(),
    ),
    div([
      strong(json_field_string(item, "title", default="Runtime step")),
      small(json_field_string(item, "owner", default="moonclaw")),
      if required_event == "" && required_output == "" && endpoint == "" {
        span(class="hidden-inline", "")
      } else {
        small(
          [
            empty_label(required_event),
            empty_label(required_output),
            empty_label(endpoint),
          ].join(" / "),
        )
      },
    ]),
  ])
}

