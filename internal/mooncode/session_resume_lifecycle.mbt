///|
// Session-level resume lifecycle projection for MoonCode headers.

///|
pub fn session_resume_lifecycle(session : Json, events : Array[Json]) -> Json {
  let session_id = json_string(session, "id", default="")
  let snapshot = summary_json_object_field_or_empty(
    session, "mooncode_session_snapshot",
  )
  let snapshot_ready = json_string(snapshot, "kind", default="") ==
    "mooncode-session-snapshot" &&
    json_string(snapshot, "protocol", default=protocol_version()) ==
    protocol_version()
  let runtime_commands = if snapshot_ready {
    json_array_items(snapshot, "runtime_commands")
  } else {
    []
  }
  let runtime_receipts = if snapshot_ready {
    json_array_items(snapshot, "runtime_receipts")
  } else {
    []
  }
  let snapshot_events = if snapshot_ready {
    json_array_items(snapshot, "events")
  } else {
    []
  }
  let lifecycle_events = if snapshot_events.length() > 0 {
    snapshot_events
  } else {
    events
  }
  let canonical_conversation = session_canonical_conversation(session)
  let canonical_turn_count = summary_json_int(
    canonical_conversation,
    "turn_count",
    default=0,
  )
  let runtime_lifecycle = runtime_command_lifecycle(
    session_id,
    runtime_commands,
    runtime_receipts,
    lifecycle_events,
    lease_now=json_string(snapshot, "recorded_at", default=""),
  )
  let status = resume_lifecycle_status(snapshot_ready, runtime_lifecycle)
  {
    "kind": "mooncode-resume-lifecycle",
    "protocol": protocol_version(),
    "session_id": session_id,
    "workspace_id": json_string(session, "workspace_id", default=""),
    "runtime_session_id": session_runtime_session_id(session),
    "status": status,
    "latest_status": status,
    "snapshot_ready": snapshot_ready,
    "snapshot_path": if snapshot_ready {
      json_string(snapshot, "snapshot_path", default="")
    } else {
      ""
    },
    "recorded_at": json_string(snapshot, "recorded_at", default=""),
    "command_log_path": json_string(snapshot, "command_log_path", default=""),
    "runtime_command_log_path": json_string(
      snapshot,
      "runtime_command_log_path",
      default="",
    ),
    "runtime_receipt_log_path": json_string(
      snapshot,
      "runtime_receipt_log_path",
      default="",
    ),
    "event_log_path": json_string(snapshot, "event_log_path", default=""),
    "canonical_conversation_turn_count": canonical_turn_count,
    "canonical_conversation_ready": canonical_turn_count > 0,
    "command_count": summary_json_int(snapshot, "command_count", default=0),
    "runtime_command_count": summary_json_int(
      runtime_lifecycle,
      "command_count",
      default=0,
    ),
    "runtime_receipt_count": runtime_receipts.length(),
    "pending_count": summary_json_int(
      runtime_lifecycle,
      "pending_count",
      default=0,
    ),
    "running_count": summary_json_int(
      runtime_lifecycle,
      "running_count",
      default=0,
    ),
    "runtime_started_count": summary_json_int(
      runtime_lifecycle,
      "runtime_started_count",
      default=0,
    ),
    "completed_count": summary_json_int(
      runtime_lifecycle,
      "completed_count",
      default=0,
    ),
    "failed_count": summary_json_int(
      runtime_lifecycle,
      "failed_count",
      default=0,
    ),
    "blocked_count": summary_json_int(
      runtime_lifecycle,
      "blocked_count",
      default=0,
    ),
    "scoped_event_count": summary_json_int(
      runtime_lifecycle,
      "scoped_event_count",
      default=0,
    ),
    "next_command_id": json_string(
      runtime_lifecycle,
      "next_command_id",
      default="",
    ),
    "next_action": json_string(runtime_lifecycle, "next_action", default=""),
    "next_status": json_string(runtime_lifecycle, "next_status", default=""),
    "rows": Json::array(json_array_items(runtime_lifecycle, "commands")),
    "runtime_lifecycle": runtime_lifecycle,
    "resume_modes": resume_lifecycle_modes(snapshot),
    "next_step": resume_lifecycle_next_step(snapshot_ready, runtime_lifecycle),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "session_store": "mooncode",
      "standalone_component": "mooncode",
    },
    "rule": "Resume lifecycle is computed from the typed MoonCode session snapshot plus runtime command and receipt logs. MoonDesk renders resumability; MoonClaw consumes the ordered runtime queue.",
  }
}

///|
fn resume_lifecycle_status(snapshot_ready : Bool, lifecycle : Json) -> String {
  if !snapshot_ready {
    return "missing-snapshot"
  }
  let command_count = summary_json_int(lifecycle, "command_count", default=0)
  if summary_json_int(lifecycle, "blocked_count", default=0) > 0 ||
    summary_json_int(lifecycle, "failed_count", default=0) > 0 {
    "blocked"
  } else if summary_json_int(lifecycle, "running_count", default=0) > 0 {
    "running"
  } else if summary_json_int(lifecycle, "pending_count", default=0) > 0 ||
    summary_json_int(lifecycle, "runtime_started_count", default=0) > 0 {
    "resumable"
  } else if command_count > 0 &&
    summary_json_int(lifecycle, "completed_count", default=0) == command_count {
    "complete"
  } else {
    "ready"
  }
}

///|
fn resume_lifecycle_modes(snapshot : Json) -> Json {
  let store = summary_json_object_field_or_empty(snapshot, "store_contract")
  Json::array(json_array_items(store, "resume_modes"))
}

///|
fn resume_lifecycle_next_step(
  snapshot_ready : Bool,
  lifecycle : Json,
) -> String {
  if !snapshot_ready {
    return "Record a typed MoonCode session snapshot before claiming resumable state."
  }
  if summary_json_int(lifecycle, "blocked_count", default=0) > 0 {
    return "Resolve blocked runtime commands before continuing the ordered queue."
  }
  if summary_json_int(lifecycle, "failed_count", default=0) > 0 {
    return "Retry failed runtime work while preserving failure proof."
  }
  if summary_json_int(lifecycle, "running_count", default=0) > 0 {
    return "Wait for runtime acknowledgement or recover the active lease if it is stale."
  }
  if summary_json_int(lifecycle, "pending_count", default=0) > 0 {
    return "Start the native loop or service to claim the next pending runtime command."
  }
  if summary_json_int(lifecycle, "runtime_started_count", default=0) > 0 {
    return "Wait for command-scoped proof events or append completion acknowledgement."
  }
  if summary_json_int(lifecycle, "command_count", default=0) > 0 {
    return "All recorded runtime commands are complete; start the next MoonCode turn when needed."
  }
  "Start or resume a MoonCode turn for the selected MoonBook."
}
