///|
// Response builders for MoonCode runtime-event sink and ingest endpoints.

///|
pub fn runtime_event_sink_response(
  session_id : String,
  events : Array[Json],
  event_log_path~ : String,
  workspace_id~ : String,
  workspace_name~ : String,
  task_id~ : String,
) -> Json {
  {
    "protocol": protocol_version(),
    "kind": "mooncode-runtime-event-sink",
    "session_id": session_id,
    "workspace_id": workspace_id,
    "workspace_name": workspace_name,
    "task_id": task_id,
    "event_log_path": event_log_path,
    "event_count": events.length(),
    "events": Json::array(events),
    "command_progress": runtime_event_command_progress(events),
    "post_contract": runtime_event_ingest_contract(session_id),
    "runtime_protocol": runtime_protocol_contract_json(),
    "owner": runtime_owner_record(),
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
    task_id=runtime_json_string(session, "moonclaw_task_id", default=""),
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
