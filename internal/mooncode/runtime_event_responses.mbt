///|
// Response builders for MoonCode runtime-event sink and ingest endpoints.

///|
pub fn runtime_event_sink_response(
  session_id : String,
  events : Array[Json],
  event_log_path~ : String,
  workspace_id~ : String,
  workspace_name~ : String,
  runtime_session_id~ : String,
) -> Json {
  {
    "protocol": protocol_version(),
    "kind": "mooncode-runtime-event-sink",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "runtime_session_id": runtime_session_id,
    "event_log_path": event_log_path,
    "event_count": events.length(),
    "events": Json::array(events),
    "command_progress": runtime_event_command_progress(events),
    "unscoped_progress": runtime_event_unscoped_progress(events),
    "runtime_service": runtime_service_state(session_id, events),
    "post_contract": runtime_event_ingest_contract(session_id),
    "runtime_protocol": runtime_protocol_contract_json(),
    "owner": runtime_owner_record(),
  }
}

///|
pub fn runtime_service_state(session_id : String, events : Array[Json]) -> Json {
  let mut started_count = 0
  let mut finished_count = 0
  let mut failed_count = 0
  let mut active = false
  let mut status = "idle"
  let mut service_id = ""
  let mut started_at = ""
  let mut finished_at = ""
  let mut detail = "No MoonClaw native runtime service lifecycle event has been recorded."
  let mut stopped_by = ""
  let mut ran_turn_count = 0
  let mut failed_turn_count = 0
  for event in events {
    let kind = runtime_first_string(event, ["kind", "event"], default="")
    if kind == "runtime.service_started" {
      started_count += 1
      active = true
      status = "running"
      service_id = runtime_json_string(event, "service_id", default=service_id)
      started_at = runtime_first_string(
        event,
        ["created_at", "created"],
        default=started_at,
      )
      finished_at = ""
      stopped_by = ""
      ran_turn_count = 0
      failed_turn_count = 0
      detail = runtime_json_string(
        event,
        "detail",
        default="MoonClaw native runtime service is running.",
      )
    } else if kind == "runtime.service_finished" ||
      kind == "runtime.service_failed" {
      if kind == "runtime.service_failed" {
        failed_count += 1
      } else {
        finished_count += 1
      }
      active = false
      status = runtime_json_string(
        event,
        "status",
        default=if kind == "runtime.service_failed" { "failed" } else { "done" },
      )
      service_id = runtime_json_string(event, "service_id", default=service_id)
      finished_at = runtime_first_string(
        event,
        ["created_at", "created"],
        default=finished_at,
      )
      detail = runtime_json_string(
        event,
        "detail",
        default=if kind == "runtime.service_failed" {
          "MoonClaw native runtime service failed."
        } else {
          "MoonClaw native runtime service finished."
        },
      )
      stopped_by = runtime_json_string(event, "stopped_by", default=stopped_by)
      ran_turn_count = runtime_json_int(
        event,
        "ran_turn_count",
        default=ran_turn_count,
      )
      failed_turn_count = runtime_json_int(
        event,
        "failed_turn_count",
        default=failed_turn_count,
      )
    }
  }
  {
    "kind": "mooncode-runtime-service-state",
    "protocol": protocol_version(),
    "session_id": session_id,
    "service_id": service_id,
    "active": active,
    "status": status,
    "started_at": started_at,
    "finished_at": finished_at,
    "detail": detail,
    "stopped_by": stopped_by,
    "started_count": started_count,
    "finished_count": finished_count,
    "failed_count": failed_count,
    "ran_turn_count": ran_turn_count,
    "failed_turn_count": failed_turn_count,
    "control_hint": if active {
      "Queue a MoonCode cancel command to ask the MoonClaw runtime service to stop at the next scheduler boundary."
    } else {
      "Start Service launches the MoonClaw-owned runtime supervisor for this session."
    },
    "owner": "moonclaw",
  }
}

///|
pub fn runtime_event_sink_result_response(
  session_id : String,
  events : Array[Json],
  session : Json,
  event_log_path~ : String,
) -> Json {
  runtime_event_sink_response(
    session_id,
    events,
    event_log_path~,
    workspace_id=runtime_json_string(session, "workspace_id", default=""),
    workspace_name=runtime_json_string(session, "workspace_name", default=""),
    runtime_session_id=session_runtime_session_id(session),
  )
}

///|
pub fn runtime_event_sink_result_response_with_native(
  session_id : String,
  events : Array[Json],
  session : Json,
  event_log_path~ : String,
  local_event_count~ : Int,
  native_state~ : Json,
  native_report~ : Json,
) -> Json {
  let native_contract = native_runtime_event_contract_report(
    native_report,
    session_id~,
    observed_at=runtime_json_string(native_report, "ingested_at", default=""),
  )
  runtime_event_sink_result_response(
    session_id,
    events,
    session,
    event_log_path~,
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
  |> runtime_with_field("native_runtime_contract", native_contract)
  |> runtime_with_field(
    "native_runtime_contract_status",
    runtime_json_string(native_contract, "status", default="").to_json(),
  )
  |> runtime_with_field(
    "native_runtime_contract_projection_safe",
    json_bool(native_contract, "projection_safe", default=false).to_json(),
  )
  |> runtime_with_field(
    "native_runtime_contract_unscoped_projection_event_count",
    runtime_json_int(
      native_contract,
      "unscoped_projection_event_count",
      default=0,
    ).to_json(),
  )
}

///|
pub fn native_runtime_events_unavailable_state(
  endpoint : String,
  error : String,
) -> Json {
  {
    "native_runtime_ready": false,
    "endpoint": endpoint,
    "error": error,
    "events": [],
  }
}

///|
pub fn native_runtime_events_available_state(
  payload : Json,
  endpoint : String,
) -> Json {
  payload
  |> runtime_with_field("native_runtime_ready", true.to_json())
  |> runtime_with_field("endpoint", endpoint.to_json())
  |> runtime_with_field("error", "".to_json())
}

///|
pub fn runtime_event_ingest_result_response(
  session_id : String,
  accepted_events : Array[Json],
  all_events : Array[Json],
  ingest_report : Json,
  final_session : Json,
  session_response : Json,
  event_log_path~ : String,
) -> Json {
  {
    "protocol": protocol_version(),
    "kind": "mooncode-runtime-event-ingest-result",
    "session_id": session_id,
    "accepted_event_count": accepted_events.length(),
    "ingest_report": ingest_report,
    "event_log_path": event_log_path,
    "command_progress": runtime_event_command_progress(all_events),
    "action_plan": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_action_plan_manifest",
    ),
    "change_set": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_change_set_manifest",
    ),
    "patch_set": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_patch_set_manifest",
    ),
    "tool_approvals": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_tool_approvals_manifest",
    ),
    "test_runs": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_test_runs_manifest",
    ),
    "runtime_evidence": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_runtime_evidence_manifest",
    ),
    "eval_report": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_eval_report_manifest",
    ),
    "runtime_handoff": runtime_json_object_field_or_empty(
      final_session, "mooncode_last_runtime_handoff_manifest",
    ),
    "session": session_response,
  }
}
