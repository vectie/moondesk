///|
fn render_mooncode_resume_lifecycle(
  summary : MoonCodeSummary
) -> @rabbita.Html {
  let lifecycle = summary.resume_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots resume-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "durable session resume"),
        h3("Resume Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip(
        "Snapshot",
        if json_field_bool(lifecycle, "snapshot_ready", default=false) {
          "ready"
        } else {
          "missing"
        },
      ),
      info_chip("Pending", json_field_int(lifecycle, "pending_count", default=0).to_string()),
      info_chip("Running", json_field_int(lifecycle, "running_count", default=0).to_string()),
      info_chip("Blocked", json_field_int(lifecycle, "blocked_count", default=0).to_string()),
      info_chip("Complete", json_field_int(lifecycle, "completed_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no runtime commands recorded for resume")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_resume_lifecycle_rows(rows).map(row =>
          render_mooncode_resume_lifecycle_row(row)
        ),
      )
    },
    div(class="mooncode-session-evidence", [
      info_row(
        "Snapshot",
        empty_label(json_field_string(lifecycle, "snapshot_path", default="")),
      ),
      info_row(
        "Runtime Feed",
        empty_label(json_field_string(lifecycle, "runtime_command_log_path", default="")),
      ),
      info_row(
        "Dispatch Log",
        empty_label(json_field_string(lifecycle, "runtime_dispatch_log_path", default="")),
      ),
      info_row(
        "Resume Modes",
        json_field_string_array_summary(lifecycle, "resume_modes", limit=3),
      ),
    ]),
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_resume_lifecycle_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_resume_lifecycle_row(row : Json) -> @rabbita.Html {
  let status = json_field_string(row, "status", default="pending")
  div(class="mooncode-review-item " + mooncode_resume_lifecycle_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(empty_label(json_field_string(row, "command_id", default=""))),
        small(
          json_field_string(row, "action", default="prompt") +
          " / " +
          json_field_string(row, "receipt_status", default="missing"),
        ),
      ]),
      span(class="record-kind", status),
    ]),
    div(class="mooncode-stats", [
      info_chip("Events", json_field_int(row, "scoped_event_count", default=0).to_string()),
      info_chip("Proof", json_field_int(row, "proof_event_count", default=0).to_string()),
      info_chip(
        "Command",
        if json_field_bool(row, "valid_command", default=false) {
          "valid"
        } else {
          "invalid"
        },
      ),
      info_chip(
        "Tools",
        if json_field_bool(row, "runtime_may_execute_tools", default=true) {
          "allowed"
        } else {
          "blocked"
        },
      ),
    ]),
    code(empty_label(json_field_string(row, "target", default=""))),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "next_step", default="")),
    ),
  ])
}

///|
fn mooncode_resume_lifecycle_class(status : String) -> String {
  match status {
    "completed" => "accepted"
    "failed"
    | "blocked-invalid"
    | "blocked-tool-authorization"
    | "blocked-missing-proof" => "rejected"
    "pending" | "running" | "dispatched" => "queued"
    _ => "queued"
  }
}

///|
fn render_mooncode_steering_lifecycle(
  summary : MoonCodeSummary
) -> @rabbita.Html {
  let lifecycle = summary.steering_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots steering-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "prompt/steer/cancel lifecycle"),
        h3("Steering Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Applied", json_field_int(lifecycle, "applied_count", default=0).to_string()),
      info_chip("Deferred", json_field_int(lifecycle, "deferred_count", default=0).to_string()),
      info_chip("Dropped", json_field_int(lifecycle, "dropped_count", default=0).to_string()),
      info_chip("Pending", json_field_int(lifecycle, "pending_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no steering commands recorded")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_steering_rows(rows).map(row =>
          render_mooncode_steering_lifecycle_row(row)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_steering_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_steering_lifecycle_row(row : Json) -> @rabbita.Html {
  let status = json_field_string(row, "status", default="pending")
  div(class="mooncode-review-item " + mooncode_steering_lifecycle_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(json_field_string(row, "command_id", default="steer")),
        small(empty_label(json_field_string(row, "settlement_kind", default=""))),
      ]),
      span(class="record-kind", status),
    ]),
    div(class="mooncode-stats", [
      info_chip(
        "Command",
        if json_field_bool(row, "command_recorded", default=false) {
          "recorded"
        } else {
          "missing"
        },
      ),
      info_chip(
        "Settlement",
        if json_field_bool(row, "settlement_recorded", default=false) {
          "recorded"
        } else {
          "pending"
        },
      ),
      info_chip(
        "Applied To",
        empty_label(json_field_string(row, "applied_to_command_id", default="")),
      ),
    ]),
    code(empty_label(json_field_string(row, "target", default=""))),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "message", default="")),
    ),
  ])
}

///|
fn mooncode_steering_lifecycle_class(status : String) -> String {
  match status {
    "applied" => "accepted"
    "deferred" | "pending" => "queued"
    "dropped" => "rejected"
    _ => "queued"
  }
}

///|
fn render_mooncode_cancel_lifecycle(
  summary : MoonCodeSummary
) -> @rabbita.Html {
  let lifecycle = summary.cancel_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots cancel-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "prompt/steer/cancel lifecycle"),
        h3("Cancel Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Cancelled", json_field_int(lifecycle, "cancelled_count", default=0).to_string()),
      info_chip("Dropped", json_field_int(lifecycle, "dropped_count", default=0).to_string()),
      info_chip("Failed", json_field_int(lifecycle, "failed_count", default=0).to_string()),
      info_chip("Pending", json_field_int(lifecycle, "pending_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no cancel commands recorded")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_cancel_rows(rows).map(row =>
          render_mooncode_cancel_lifecycle_row(row)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_cancel_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_cancel_lifecycle_row(row : Json) -> @rabbita.Html {
  let status = json_field_string(row, "status", default="pending")
  div(class="mooncode-review-item " + mooncode_cancel_lifecycle_class(status), [
    div(class="mooncode-review-head", [
      div([
        strong(json_field_string(row, "command_id", default="cancel")),
        small(empty_label(json_field_string(row, "settlement_kind", default=""))),
      ]),
      span(class="record-kind", status),
    ]),
    div(class="mooncode-stats", [
      info_chip(
        "Command",
        if json_field_bool(row, "command_recorded", default=false) {
          "recorded"
        } else {
          "missing"
        },
      ),
      info_chip(
        "Settlement",
        if json_field_bool(row, "settlement_recorded", default=false) {
          "recorded"
        } else {
          "pending"
        },
      ),
      info_chip(
        "Command Status",
        empty_label(json_field_string(row, "command_status", default="")),
      ),
    ]),
    code(empty_label(json_field_string(row, "target", default=""))),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "message", default="")),
    ),
  ])
}

///|
fn mooncode_cancel_lifecycle_class(status : String) -> String {
  match status {
    "cancelled" => "accepted"
    "dropped" | "failed" => "rejected"
    "pending" => "queued"
    _ => "queued"
  }
}

///|
fn render_mooncode_patch_lifecycle(summary : MoonCodeSummary) -> @rabbita.Html {
  let lifecycle = summary.patch_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots patch-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "diff review/runtime proof"),
        h3("Patch Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Patches", json_field_int(lifecycle, "patch_count", default=0).to_string()),
      info_chip("Needs Review", json_field_int(lifecycle, "needs_review_count", default=0).to_string()),
      info_chip("Runtime Needed", json_field_int(lifecycle, "runtime_needed_count", default=0).to_string()),
      info_chip("Runtime Proven", json_field_int(lifecycle, "runtime_proven_count", default=0).to_string()),
      info_chip("Blocked", json_field_int(lifecycle, "blocked_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no file diffs recorded for patch review")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_patch_lifecycle_rows(rows).map(row =>
          render_mooncode_patch_lifecycle_row(row)
        ),
      )
    },
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_patch_lifecycle_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_patch_lifecycle_row(row : Json) -> @rabbita.Html {
  let gate = json_field_string(row, "gate_status", default="needs-review")
  div(class="mooncode-review-item " + mooncode_patch_lifecycle_class(gate), [
    div(class="mooncode-review-head", [
      div([
        strong(empty_label(json_field_string(row, "path", default=""))),
        small(
          json_field_string(row, "review_state", default="pending") +
          " / " +
          json_field_string(row, "execution_state", default="pending"),
        ),
      ]),
      span(class="record-kind", gate),
    ]),
    div(class="mooncode-stats", [
      info_chip("Next", empty_label(json_field_string(row, "next_action", default=""))),
      info_chip("Hunks", json_field_int(row, "hunk_count", default=0).to_string()),
      info_chip("Runtime", json_field_int(row, "runtime_proof_count", default=0).to_string()),
      info_chip(
        "Diff",
        if json_field_bool(row, "diff_present", default=false) {
          "yes"
        } else {
          "no"
        },
      ),
    ]),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "blocked_reason", default="")),
    ),
  ])
}

///|
fn mooncode_patch_lifecycle_class(status : String) -> String {
  match status {
    "runtime-proven" | "ready" => "accepted"
    "runtime-needed" | "needs-review" => "queued"
    "blocked" => "rejected"
    _ => "queued"
  }
}

///|
fn render_mooncode_package_lifecycle(
  summary : MoonCodeSummary
) -> @rabbita.Html {
  let lifecycle = summary.package_lifecycle
  let rows = json_field_json_array_items(lifecycle, "rows")
  div(class="mooncode-output-roots package-lifecycle", [
    div(class="mooncode-stream-header compact-header", [
      div([
        p(class="eyebrow", "bundle/package assembly"),
        h3("Package Lifecycle"),
      ]),
      span(
        class="record-kind",
        empty_label(json_field_string(lifecycle, "latest_status", default="idle")),
      ),
    ]),
    div(class="mooncode-stats", [
      info_chip("Packages", json_field_int(lifecycle, "package_count", default=0).to_string()),
      info_chip("Source-bound", json_field_int(lifecycle, "source_bound_package_count", default=0).to_string()),
      info_chip("Missing Source", json_field_int(lifecycle, "missing_source_package_count", default=0).to_string()),
      info_chip("Executable-ready", json_field_int(lifecycle, "executable_ready_count", default=0).to_string()),
      info_chip("Runtime Verified", json_field_int(lifecycle, "runtime_verified_package_count", default=0).to_string()),
    ]),
    if rows.length() == 0 {
      p(class="status-line", "no package candidates recorded")
    } else {
      div(
        class="mooncode-review-list compact",
        mooncode_recent_package_lifecycle_rows(rows).map(row =>
          render_mooncode_package_lifecycle_row(row)
        ),
      )
    },
    div(class="mooncode-session-evidence", [
      info_row(
        "Index",
        empty_label(json_field_string(lifecycle, "package_index_status", default="")),
      ),
      info_row(
        "Index Path",
        empty_label(json_field_string(lifecycle, "package_index_path", default="")),
      ),
      info_row(
        "Entry Points",
        json_field_string_array_summary(lifecycle, "entry_points", limit=3),
      ),
    ]),
    p(
      class="mooncode-event-detail",
      json_field_string(lifecycle, "next_step", default=""),
    ),
  ])
}

///|
fn mooncode_recent_package_lifecycle_rows(rows : Array[Json]) -> Array[Json] {
  let recent : Array[Json] = []
  let mut index = rows.length()
  let mut emitted = 0
  while index > 0 && emitted < 4 {
    index -= 1
    recent.push(rows[index])
    emitted += 1
  }
  recent
}

///|
fn render_mooncode_package_lifecycle_row(row : Json) -> @rabbita.Html {
  let state = json_field_string(row, "execution_state", default="pending")
  div(class="mooncode-review-item " + mooncode_package_lifecycle_class(state), [
    div(class="mooncode-review-head", [
      div([
        strong(empty_label(json_field_string(row, "context_path", default=""))),
        small(
          json_field_string(row, "package_kind", default="package") +
          " / " +
          json_field_string(row, "source_inventory_status", default="unknown"),
        ),
      ]),
      span(class="record-kind", state),
    ]),
    div(class="mooncode-stats", [
      info_chip("Sources", json_field_int(row, "source_present_count", default=0).to_string()),
      info_chip("Promoted", json_field_int(row, "promoted_source_count", default=0).to_string()),
      info_chip("Runtime", json_field_int(row, "runtime_proof_count", default=0).to_string()),
      info_chip(
        "Verified",
        if json_field_bool(row, "execution_verified", default=false) {
          "yes"
        } else {
          "no"
        },
      ),
    ]),
    code(empty_label(json_field_string(row, "manifest_path", default=""))),
    p(
      class="mooncode-event-detail",
      empty_label(json_field_string(row, "next_runtime_step", default="")),
    ),
  ])
}

///|
fn mooncode_package_lifecycle_class(status : String) -> String {
  match status {
    "verified" => "accepted"
    "built" | "pending" => "queued"
    _ => "queued"
  }
}

///|
