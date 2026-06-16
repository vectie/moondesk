///|
pub fn change_set_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="change_set.manifest",
    title="MoonCode change set",
    detail_prefix="MoonBook change-set manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn patch_set_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="patch_set.manifest",
    title="MoonCode patch set",
    detail_prefix="MoonBook patch-set manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn tool_approvals_manifest_event(
  manifest : Json,
  event_id : String,
) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="tool_approvals.manifest",
    title="MoonCode tool approvals",
    detail_prefix="MoonBook tool-approval manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn test_runs_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="test_runs.manifest",
    title="MoonCode test runs",
    detail_prefix="MoonBook test-run manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn action_plan_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="runtime",
    kind="action_plan.manifest",
    title="MoonCode action plan",
    detail_prefix="MoonCode action plan recorded at",
  )
}

///|
pub fn runtime_evidence_manifest_event(
  manifest : Json,
  event_id : String,
) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="runtime",
    kind="runtime_evidence.manifest",
    title="MoonCode runtime evidence",
    detail_prefix="MoonCode runtime evidence recorded at",
  )
}

///|
pub fn eval_report_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="review",
    kind="eval_report.manifest",
    title="MoonCode eval report",
    detail_prefix="MoonBook eval report manifest recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
pub fn review_receipt_event(
  action : String,
  receipt_path : String,
  context_path : String,
  recorded_at : String,
  command_packet : Json,
  event_id : String,
) -> Json {
  event_record(
    id=event_id,
    lane="review",
    kind="receipt.\{action}",
    title="MoonBook review receipt",
    status="recorded",
    created_at=recorded_at,
    detail="MoonBook review receipt recorded at \{receipt_path}",
    path=if context_path == "" { receipt_path } else { context_path },
    command_packet~,
  )
}

///|
pub fn review_receipt_manifest(
  session : Json,
  action : String,
  command_packet : Json,
  context_path : String,
  detail : String,
  command_created_at : String,
  command_id~ : String,
  recorded_at~ : String,
  receipt_path~ : String,
  absolute_receipt_path~ : String,
) -> Json {
  {
    "kind": "mooncode-review-receipt",
    "protocol": "mooncode.v1",
    "status": "recorded",
    "action": action,
    "session_id": json_string(session, "id", default=""),
    "workspace_id": json_string(session, "workspace_id", default=""),
    "workspace_name": json_string(session, "workspace_name", default=""),
    "task_id": json_string(session, "moonclaw_task_id", default=""),
    "context_path": context_path,
    "command_id": command_id,
    "command_created_at": command_created_at,
    "recorded_at": recorded_at,
    "receipt_path": receipt_path,
    "absolute_receipt_path": absolute_receipt_path,
    "detail": detail,
    "command_packet": command_packet,
    "owner": {
      "ui": "moondesk",
      "runtime": "moonclaw",
      "artifact": "moonbook",
      "review": "moonbook",
      "extractable_component": "mooncode",
    },
  }
}

///|
pub fn package_manifest_event(
  manifest : Json,
  context_path : String,
  recorded_at : String,
  command_packet : Json,
  event_id : String,
) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  event_record(
    id=event_id,
    lane="artifact",
    kind="package.manifest",
    title="MoonBook package manifest",
    status=json_string(manifest, "status", default="candidate"),
    created_at=recorded_at,
    detail="MoonCode package candidate recorded at \{manifest_path}",
    path=if context_path == "" { manifest_path } else { context_path },
    command_packet~,
  )
}

///|
pub fn package_index_manifest_event(manifest : Json, event_id : String) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="artifact",
    kind="package.index",
    title="MoonBook package index",
    detail_prefix="MoonCode package index recorded at",
    command_packet=summary_json_object_field_or_empty(
      summary_json_object_field_or_empty(manifest, "latest_package_manifest"),
      "command_packet",
    ),
  )
}

///|
pub fn runtime_handoff_manifest_event(
  manifest : Json,
  event_id : String,
) -> Json {
  review_manifest_event(
    manifest,
    event_id,
    lane="runtime",
    kind="runtime.handoff",
    title="MoonCode runtime handoff",
    detail_prefix="MoonCode runtime handoff recorded at",
    command_packet=summary_json_object_field_or_empty(
      manifest, "last_command_packet",
    ),
  )
}

///|
fn review_manifest_event(
  manifest : Json,
  event_id : String,
  lane~ : String,
  kind~ : String,
  title~ : String,
  detail_prefix~ : String,
  command_packet? : Json = Json::object({}),
) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  event_record(
    id=event_id,
    lane~,
    kind~,
    title~,
    status=json_string(manifest, "status", default="recorded"),
    created_at=json_string(manifest, "recorded_at", default=""),
    detail="\{detail_prefix} \{manifest_path}",
    path=manifest_path,
    command_packet~,
  )
}
