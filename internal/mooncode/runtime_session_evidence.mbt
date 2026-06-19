///|
pub fn session_runtime_evidence(
  session : Json,
  commands : Array[Json],
  runtime_commands : Array[Json],
  proof_events : Array[Json],
  recorded_at~ : String,
) -> Json {
  let items : Array[Json] = []
  let mut index = 0
  let mut proven_count = 0
  let mut missing_count = 0
  let mut failed_count = 0
  let mut missing_runtime_command_count = 0
  let mut required_event_count = 0
  let mut proven_required_event_count = 0
  let mut failed_required_event_count = 0
  let mut missing_required_event_count = 0
  let mut tool_harness_expected_tool_count = 0
  let mut tool_harness_proven_tool_count = 0
  let mut tool_harness_failed_tool_count = 0
  let mut tool_harness_missing_tool_count = 0
  for command in commands {
    let runtime_command = evidence_runtime_command_for_id(
      json_string(command, "command_id", default=""),
      runtime_commands,
    )
    let evidence = command_runtime_evidence(
      command, runtime_command, proof_events,
    )
    let status = json_string(evidence, "status", default="missing-evidence")
    if status == "proven" {
      proven_count += 1
    } else if status == "failed" {
      failed_count += 1
    } else {
      missing_count += 1
    }
    if !json_bool(evidence, "runtime_command_recorded", default=false) {
      missing_runtime_command_count += 1
    }
    required_event_count += runtime_json_int(
      evidence,
      "required_event_count",
      default=0,
    )
    proven_required_event_count += runtime_json_int(
      evidence,
      "proven_required_event_count",
      default=0,
    )
    failed_required_event_count += runtime_json_int(
      evidence,
      "failed_required_event_count",
      default=0,
    )
    missing_required_event_count += runtime_json_int(
      evidence,
      "missing_required_event_count",
      default=0,
    )
    tool_harness_expected_tool_count += runtime_json_int(
      evidence,
      "tool_harness_expected_tool_count",
      default=0,
    )
    tool_harness_proven_tool_count += runtime_json_int(
      evidence,
      "tool_harness_proven_tool_count",
      default=0,
    )
    tool_harness_failed_tool_count += runtime_json_int(
      evidence,
      "tool_harness_failed_tool_count",
      default=0,
    )
    tool_harness_missing_tool_count += runtime_json_int(
      evidence,
      "tool_harness_missing_tool_count",
      default=0,
    )
    items.push({
      "index": index,
      "command_id": json_string(command, "command_id", default=""),
      "action": json_string(command, "action", default="prompt"),
      "created_at": json_string(command, "created_at", default=""),
      "context_path": json_string(command, "context_path", default=""),
      "message": json_string(command, "message", default=""),
      "runtime_command_recorded": json_bool(
        evidence,
        "runtime_command_recorded",
        default=false,
      ),
      "status": status,
      "required_event_count": runtime_json_int(
        evidence,
        "required_event_count",
        default=0,
      ),
      "proven_required_event_count": runtime_json_int(
        evidence,
        "proven_required_event_count",
        default=0,
      ),
      "missing_required_events": evidence_json_array(
        evidence, "missing_required_events",
      ),
      "failed_required_events": evidence_json_array(
        evidence, "failed_required_events",
      ),
      "tool_harness_status": json_string(
        evidence,
        "tool_harness_status",
        default="missing-evidence",
      ),
      "tool_harness_proven_tool_count": runtime_json_int(
        evidence,
        "tool_harness_proven_tool_count",
        default=0,
      ),
      "tool_harness_expected_tool_count": runtime_json_int(
        evidence,
        "tool_harness_expected_tool_count",
        default=0,
      ),
      "evidence": evidence,
    })
    index += 1
  }
  {
    "kind": "mooncode-session-runtime-evidence",
    "protocol": protocol_version(),
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "runtime_session_id": session_runtime_session_id(session),
    "recorded_at": recorded_at,
    "command_count": commands.length(),
    "runtime_command_count": runtime_commands.length(),
    "proof_event_count": proof_events.length(),
    "proven_command_count": proven_count,
    "missing_evidence_command_count": missing_count,
    "failed_evidence_command_count": failed_count,
    "missing_runtime_command_count": missing_runtime_command_count,
    "required_event_count": required_event_count,
    "proven_required_event_count": proven_required_event_count,
    "missing_required_event_count": missing_required_event_count,
    "failed_required_event_count": failed_required_event_count,
    "tool_harness_expected_tool_count": tool_harness_expected_tool_count,
    "tool_harness_proven_tool_count": tool_harness_proven_tool_count,
    "tool_harness_missing_tool_count": tool_harness_missing_tool_count,
    "tool_harness_failed_tool_count": tool_harness_failed_tool_count,
    "tool_harness_status": if tool_harness_expected_tool_count == 0 {
      "no-tools"
    } else if tool_harness_failed_tool_count > 0 {
      "failed"
    } else if tool_harness_missing_tool_count > 0 {
      "missing-evidence"
    } else {
      "proven"
    },
    "status": if commands.length() == 0 {
      "no-commands"
    } else if failed_count > 0 || failed_required_event_count > 0 {
      "failed"
    } else if missing_count > 0 ||
      missing_runtime_command_count > 0 ||
      missing_required_event_count > 0 {
      "missing-evidence"
    } else {
      "proven"
    },
    "items": Json::array(items),
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "standalone_component": "mooncode",
    },
    "rule": "This projection is the session-level proof contract. Moondesk records and displays it, while MoonClaw must satisfy it with command-scoped runtime events.",
  }
}

///|
pub fn session_runtime_evidence_manifest_response(
  evidence : Json,
  manifest_path : String,
  absolute_manifest_path : String,
) -> Json {
  evidence
  |> runtime_with_field("manifest_path", manifest_path.to_json())
  |> runtime_with_field(
    "absolute_manifest_path",
    absolute_manifest_path.to_json(),
  )
}

///|
pub fn session_runtime_evidence_response(
  evidence : Json,
  manifest_path : String,
  absolute_manifest_path : String,
  command_log_path : String,
  runtime_command_log_path : String,
  event_log_path : String,
) -> Json {
  session_runtime_evidence_manifest_response(
    evidence, manifest_path, absolute_manifest_path,
  )
  |> runtime_with_field("command_log_path", command_log_path.to_json())
  |> runtime_with_field(
    "runtime_command_log_path",
    runtime_command_log_path.to_json(),
  )
  |> runtime_with_field("event_log_path", event_log_path.to_json())
}

///|
pub fn session_runtime_evidence_response_with_native(
  evidence : Json,
  manifest_path : String,
  absolute_manifest_path : String,
  command_log_path : String,
  runtime_command_log_path : String,
  event_log_path : String,
  local_event_count~ : Int,
  native_state~ : Json,
  native_report~ : Json,
) -> Json {
  session_runtime_evidence_response(
    evidence, manifest_path, absolute_manifest_path, command_log_path, runtime_command_log_path,
    event_log_path,
  )
  |> runtime_with_field("local_event_count", local_event_count.to_json())
  |> runtime_with_field(
    "native_event_count",
    runtime_json_array_items(native_report, "events").length().to_json(),
  )
  |> runtime_with_field(
    "native_runtime_ready",
    json_bool(native_state, "native_runtime_ready", default=false).to_json(),
  )
  |> runtime_with_field(
    "native_runtime_events_endpoint",
    runtime_json_string(native_state, "endpoint", default="").to_json(),
  )
  |> runtime_with_field(
    "native_runtime_events_error",
    runtime_json_string(native_state, "error", default="").to_json(),
  )
  |> runtime_with_field(
    "native_runtime_events_submitted_count",
    runtime_json_int(native_report, "submitted_count", default=0).to_json(),
  )
  |> runtime_with_field(
    "native_runtime_events_accepted_count",
    runtime_json_int(native_report, "accepted_count", default=0).to_json(),
  )
  |> runtime_with_field(
    "native_runtime_events_rejected_count",
    runtime_json_int(native_report, "rejected_count", default=0).to_json(),
  )
  |> runtime_with_field("native_runtime_events_report", native_report)
}

///|
fn evidence_runtime_command_for_id(
  command_id : String,
  runtime_commands : Array[Json],
) -> Json {
  if command_id == "" {
    return Json::object({})
  }
  for runtime_command in runtime_commands {
    if json_string(runtime_command, "command_id", default="") == command_id {
      return runtime_command
    }
  }
  Json::object({})
}
