///|
async fn write_mooncode_review_receipt_if_needed(
  session : Json,
  action : String,
  command_packet : Json,
  context_path : String,
  detail : String,
  command_created_at : String,
) -> Json? {
  if !@mooncode.command_writes_review_receipt(action) {
    return None
  }
  let receipt = write_mooncode_review_receipt(
    session, action, command_packet, context_path, detail, command_created_at,
  )
  let receipt_path = json_string(receipt, "receipt_path", default="")
  let recorded_at = json_string(receipt, "recorded_at", default="")
  let event = mooncode_review_receipt_event(
    action, receipt_path, context_path, recorded_at, command_packet,
  )
  let events = json_array_items(session, "mooncode_command_events")
  events.push(event)
  let with_receipt_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  let with_receipt = agent_session_with_field(
    with_receipt_events, "mooncode_last_review_receipt", receipt,
  )
  let with_package = if action == "package" {
    write_mooncode_package_manifest_for_receipt(
      with_receipt, receipt, command_packet, context_path, detail, command_created_at,
    )
  } else {
    with_receipt
  }
  Some(
    agent_session_with_field(with_package, "updated_at", recorded_at.to_json()),
  )
}

///|
async fn write_mooncode_change_set_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_change_set_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_change_set_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_change_set_manifest", manifest,
  )
}

///|
async fn write_mooncode_patch_set_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_patch_set_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_patch_set_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_patch_set_manifest", manifest,
  )
}

///|
async fn write_mooncode_tool_approvals_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_tool_approvals_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_tool_approvals_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_tool_approvals_manifest", manifest,
  )
}

///|
async fn write_mooncode_test_runs_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_test_runs_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_test_runs_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_test_runs_manifest", manifest,
  )
}

///|
async fn write_mooncode_action_plan_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let manifest = write_mooncode_action_plan_manifest(workspace_root, session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_action_plan_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_action_plan_manifest", manifest,
  )
}

///|
async fn write_mooncode_runtime_evidence_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let manifest = write_mooncode_runtime_evidence_manifest(
    workspace_root, session,
  )
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_runtime_evidence_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_runtime_evidence_manifest", manifest,
  )
}

///|
async fn write_mooncode_eval_report_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_eval_report_manifest(session)
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_eval_report_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  let with_manifest = agent_session_with_field(
    with_events, "mooncode_last_eval_report_manifest", manifest,
  )
  let refreshed_events = project_mooncode_events(with_manifest, [], [])
  let refreshed_summary = @mooncode.session_summary(
    with_manifest, refreshed_events,
  )
  agent_session_with_field(with_manifest, "mooncode_summary", refreshed_summary)
}

///|
async fn write_mooncode_runtime_handoff_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let manifest = write_mooncode_runtime_handoff_manifest(
    workspace_root, session,
  )
  let events = json_array_items(session, "mooncode_command_events")
  events.push(mooncode_runtime_handoff_manifest_event(manifest))
  let with_events = agent_session_with_field(
    session,
    "mooncode_command_events",
    Json::array(events),
  )
  agent_session_with_field(
    with_events, "mooncode_last_runtime_handoff_manifest", manifest,
  )
}

///|
fn mooncode_session_with_saved_eval_manifest(
  session : Json,
  manifest : Json,
) -> Json {
  let with_manifest = agent_session_with_field(
    session, "mooncode_last_eval_report_manifest", manifest,
  )
  let native_report = json_object_field_or_empty(manifest, "native_eval_report")
  if json_bool(native_report, "ok", default=false) &&
    !json_bool(
      json_object_field_or_empty(session, "mooncode_native_eval_report"),
      "ok",
      default=false,
    ) {
    agent_session_with_field(
      with_manifest, "mooncode_native_eval_report", native_report,
    )
  } else {
    with_manifest
  }
}

///|
async fn write_mooncode_change_set_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode change set needs a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.change_set_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.change_set_manifest(
    session,
    events,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_patch_set_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode patch set needs a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.patch_set_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.patch_set_manifest(
    session,
    events,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_tool_approvals_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode tool approvals need a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.tool_approvals_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.tool_approvals_manifest(
    session,
    events,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_test_runs_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode test runs need a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.test_runs_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.test_runs_manifest(
    session,
    events,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_action_plan_manifest(
  workspace_root : String,
  session : Json,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode action plan needs a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.action_plan_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let manifest = agent_session_with_field(
    agent_session_with_field(
      mooncode_action_plan_projection(workspace_root, session),
      "manifest_path",
      relative.to_json(),
    ),
    "absolute_manifest_path",
    absolute.to_json(),
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn write_mooncode_runtime_evidence_manifest(
  workspace_root : String,
  session : Json,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode runtime evidence needs a MoonBook workspace root")
  }
  let session_id = mooncode_safe_receipt_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.runtime_evidence_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let manifest = agent_session_with_field(
    agent_session_with_field(
      mooncode_session_runtime_evidence_projection(workspace_root, session),
      "manifest_path",
      relative.to_json(),
    ),
    "absolute_manifest_path",
    absolute.to_json(),
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}
