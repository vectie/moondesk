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
  let event = @mooncode.review_receipt_projected_event(
    action, receipt_path, context_path, recorded_at, command_packet,
  )
  let with_receipt = @mooncode.session_with_review_receipt_event(
    session, receipt, event,
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
  @mooncode.session_with_manifest_event(
    session,
    "mooncode_last_change_set_manifest",
    manifest,
    @mooncode.change_set_manifest_projected_event(manifest),
  )
}

///|
async fn write_mooncode_patch_set_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_patch_set_manifest(session)
  @mooncode.session_with_manifest_event(
    session,
    "mooncode_last_patch_set_manifest",
    manifest,
    @mooncode.patch_set_manifest_projected_event(manifest),
  )
}

///|
async fn write_mooncode_tool_approvals_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_tool_approvals_manifest(session)
  @mooncode.session_with_manifest_event(
    session,
    "mooncode_last_tool_approvals_manifest",
    manifest,
    @mooncode.tool_approvals_manifest_projected_event(manifest),
  )
}

///|
async fn write_mooncode_test_runs_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_test_runs_manifest(session)
  @mooncode.session_with_manifest_event(
    session,
    "mooncode_last_test_runs_manifest",
    manifest,
    @mooncode.test_runs_manifest_projected_event(manifest),
  )
}

///|
async fn write_mooncode_action_plan_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let manifest = write_mooncode_action_plan_manifest(workspace_root, session)
  @mooncode.session_with_manifest_event(
    session,
    "mooncode_last_action_plan_manifest",
    manifest,
    @mooncode.action_plan_manifest_projected_event(manifest),
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
  @mooncode.session_with_manifest_event(
    session,
    "mooncode_last_runtime_evidence_manifest",
    manifest,
    @mooncode.runtime_evidence_manifest_projected_event(manifest),
  )
}

///|
async fn write_mooncode_eval_report_if_possible(session : Json) -> Json {
  let manifest = write_mooncode_eval_report_manifest(session)
  @mooncode.session_with_eval_report_manifest_event(
    session,
    manifest,
    @mooncode.eval_report_manifest_projected_event(manifest),
  )
}

///|
async fn write_mooncode_runtime_handoff_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let manifest = write_mooncode_runtime_handoff_manifest(
    workspace_root, session,
  )
  @mooncode.session_with_manifest_event(
    session,
    "mooncode_last_runtime_handoff_manifest",
    manifest,
    @mooncode.runtime_handoff_manifest_projected_event(manifest),
  )
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
  let session_id = json_string(session, "id", default="session")
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
  let session_id = json_string(session, "id", default="session")
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
  let session_id = json_string(session, "id", default="session")
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
  let session_id = json_string(session, "id", default="session")
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
  let session_id = json_string(session, "id", default="session")
  let relative = @mooncode.action_plan_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let manifest = @mooncode.action_plan_manifest_response(
    mooncode_action_plan_projection(workspace_root, session),
    relative,
    absolute,
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
  let session_id = json_string(session, "id", default="session")
  let relative = @mooncode.runtime_evidence_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let manifest = @mooncode.session_runtime_evidence_manifest_response(
    mooncode_session_runtime_evidence_projection(workspace_root, session),
    relative,
    absolute,
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}
