///|
fn render_mooncode_runtime_command_feed_panel(model : Model) -> @rabbita.Html {
  section(class="mooncode-review-board runtime-command-feed-board", [
    div(class="mooncode-stream-header", [
      div([
        p(class="eyebrow", "engine-facing command feed"),
        h3("Runtime Feed"),
      ]),
      span(class="record-kind", model.mooncode_runtime_command_feed_status),
    ]),
    match model.mooncode_runtime_command_feed {
      Some(feed) =>
        div([
          div(class="mooncode-stats", [
            info_chip("Commands", feed.runtime_command_count.to_string()),
            info_chip("Receipts", feed.runtime_dispatch_count.to_string()),
            info_chip("Pending", feed.runtime_dispatch_pending_count.to_string()),
            info_chip("Summaries", feed.execution_summaries.length().to_string()),
          ]),
          div(class="daemon-state compact-state", [
            info_row("Runtime Feed", feed.runtime_command_log_path),
            info_row("Dispatch Log", feed.runtime_dispatch_log_path),
            info_row("Claim Endpoint", feed.runtime_claim_endpoint),
            info_row("Runtime", empty_label(feed.runtime_session_id)),
          ]),
          render_mooncode_runtime_command_lifecycle(feed.command_lifecycle),
          if feed.commands.length() == 0 {
            p(class="status-line", "no runtime commands have been recorded")
          } else {
            div(
              class="mooncode-review-list runtime-command-feed-list",
              mooncode_recent_runtime_commands(feed.commands).map(command =>
                render_mooncode_runtime_command_feed_item(command)
              ),
            )
          },
        ])
      None =>
        p(
          class="status-line",
          "No MoonCode runtime command feed has been loaded for this session yet.",
        )
    },
  ])
}

///|
fn mooncode_recent_runtime_commands(commands : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = commands.length()
  let mut emitted = 0
  while index > 0 && emitted < 8 {
    index -= 1
    recent.push(commands[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_runtime_command_lifecycle(
  lifecycle : Json
) -> @rabbita.Html {
  let commands = json_field_json_array_items(lifecycle, "commands")
  div(class="mooncode-output-roots", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "runtime command lifecycle"),
        h3("Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "next_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Pending", json_field_int(lifecycle, "pending_count", default=0).to_string()),
      info_chip("Running", json_field_int(lifecycle, "running_count", default=0).to_string()),
      info_chip("Dispatched", json_field_int(lifecycle, "dispatched_count", default=0).to_string()),
      info_chip("Completed", json_field_int(lifecycle, "completed_count", default=0).to_string()),
      info_chip("Failed", json_field_int(lifecycle, "failed_count", default=0).to_string()),
      info_chip("Blocked", json_field_int(lifecycle, "blocked_count", default=0).to_string()),
    ]),
    div(class="daemon-state compact-state", [
      info_row("Next Command", empty_label(json_field_string(lifecycle, "next_command_id", default=""))),
      info_row("Next Action", empty_label(json_field_string(lifecycle, "next_action", default=""))),
      info_row("Scoped Events", json_field_int(lifecycle, "scoped_event_count", default=0).to_string()),
    ]),
    if commands.length() == 0 {
      p(class="status-line", "no lifecycle rows yet")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_runtime_lifecycle_commands(commands).map(command =>
          render_mooncode_runtime_lifecycle_item(command)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "rule", default=""),
    ),
  ])
}

///|
fn mooncode_recent_runtime_lifecycle_commands(
  commands : Array[Json]
) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = commands.length()
  let mut emitted = 0
  while index > 0 && emitted < 6 {
    index -= 1
    recent.push(commands[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_runtime_lifecycle_item(command : Json) -> @rabbita.Html {
  let status = json_field_string(command, "status", default="pending")
  div(class="mooncode-review-item " + mooncode_runtime_lifecycle_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(
          json_field_string(command, "action", default="prompt") +
          " -> " +
          status,
        ),
        small(json_field_string(command, "receipt_status", default="missing")),
      ]),
      span(
        class=if json_field_bool(command, "valid_command", default=false) {
          "record-kind good"
        } else {
          "record-kind warning"
        },
        if json_field_bool(command, "valid_command", default=false) {
          "command ok"
        } else {
          "command blocked"
        },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Proof", json_field_int(command, "proof_event_count", default=0).to_string()),
      info_chip("Events", json_field_int(command, "scoped_event_count", default=0).to_string()),
      info_chip("Running", json_field_int(command, "running_event_count", default=0).to_string()),
      info_chip("Failed", json_field_int(command, "failed_event_count", default=0).to_string()),
      info_chip("Auth", empty_label(json_field_string(command, "tool_authorization_state", default=""))),
    ]),
    code(json_field_string(command, "command_id", default="")),
    p(
      class="mooncode-event-detail",
      mooncode_runtime_lifecycle_detail(command),
    ),
  ])
}

///|
fn mooncode_runtime_lifecycle_detail(command : Json) -> String {
  let blocker = json_field_string(command, "blocking_reason", default="")
  if blocker != "" {
    return blocker
  }
  let latest = json_field_string(command, "latest_event_title", default="")
  let step = json_field_string(command, "next_step", default="")
  if latest != "" {
    latest + " / " + step
  } else {
    step
  }
}

///|
fn mooncode_runtime_lifecycle_class(status : String) -> String {
  match status {
    "completed" => "accepted"
    "failed" | "blocked-invalid" | "blocked-tool-authorization" => "rejected"
    "running" | "dispatched" => "running"
    _ => "queued"
  }
}

///|
fn render_mooncode_runtime_command_feed_item(command : Json) -> @rabbita.Html {
  let action = json_field_string(command, "action", default="command")
  let dispatch = json_field_string(command, "dispatch", default="prompt")
  let command_id = json_field_string(command, "command_id", default="")
  let target = json_field_string(command, "target", default="")
  let auth_state = mooncode_command_tool_authorization_state(command)
  div(class="mooncode-review-item " + mooncode_runtime_command_feed_item_class(command), [
    div(class="mooncode-review-head", [
      div([
        strong(action + " -> " + dispatch),
        small(json_field_string(command, "created_at", default="")),
      ]),
      span(
        class=if json_field_bool(command, "mooncode_command_valid", default=false) {
          "record-kind good"
        } else {
          "record-kind"
        },
        if json_field_bool(command, "mooncode_command_valid", default=false) {
          "command valid"
        } else {
          "command invalid"
        },
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Approval", json_field_string(command, "approval", default="none")),
      info_chip("Auth", if auth_state == "" { "unknown" } else { auth_state }),
      info_chip("Serve", json_field_string(command, "serve_command", default="")),
      info_chip(
        "Native",
        if json_field_string(command, "native_mooncode_endpoint", default="") == "" {
          "none"
        } else {
          "ready"
        },
      ),
    ]),
    if target == "" {
      code(command_id)
    } else {
      code(target)
    },
    render_mooncode_runtime_execution_summary(command),
    small(class="status-line", command_id),
  ])
}

///|
fn mooncode_command_tool_authorization_state(command : Json) -> String {
  let direct = json_field_string(command, "tool_authorization_state", default="")
  if direct != "" {
    return direct
  }
  match json_field(command, "tool_authorization") {
    Some(auth) => json_field_string(auth, "enforcement_state", default="")
    None => ""
  }
}

///|
fn mooncode_runtime_command_feed_item_class(command : Json) -> String {
  match json_field_string(command, "action", default="") {
    "cancel" => "rejected"
    "run_tests" | "run_build" | "run_eval" => "running"
    "package" => "pending"
    "accept" | "approve_tool" | "apply_patch" => "accepted"
    "reject" | "reject_tool" | "revert_patch" => "rejected"
    _ => "queued"
  }
}

