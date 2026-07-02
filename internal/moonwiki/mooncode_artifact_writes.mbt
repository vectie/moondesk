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
  let manifest_ref = mooncode_runtime_handoff_manifest_ref(manifest)
  @mooncode.session_with_manifest_event(
    session,
    "mooncode_last_runtime_handoff_manifest",
    manifest_ref,
    @mooncode.runtime_handoff_manifest_projected_event(manifest_ref),
  )
}

///|
fn mooncode_runtime_handoff_manifest_ref(manifest : Json) -> Json {
  {
    "kind": json_string(manifest, "kind", default="mooncode-runtime-handoff"),
    "protocol": json_string(manifest, "protocol", default=""),
    "status": json_string(manifest, "status", default=""),
    "session_id": json_string(manifest, "session_id", default=""),
    "recorded_at": json_string(manifest, "recorded_at", default=""),
    "manifest_path": json_string(manifest, "manifest_path", default=""),
    "absolute_manifest_path": json_string(
      manifest,
      "absolute_manifest_path",
      default="",
    ),
    "command_count": json_int(manifest, "command_count", default=0),
    "runtime_command_count": json_int(
      manifest,
      "runtime_command_count",
      default=0,
    ),
    "runtime_receipt_count": json_int(
      manifest,
      "runtime_receipt_count",
      default=0,
    ),
    "runtime_receipts": json_array(manifest, "runtime_receipts"),
    "runtime_replay": json_object_field_or_empty(manifest, "runtime_replay"),
    "runtime_claim": json_object_field_or_empty(manifest, "runtime_claim"),
    "resume_contract": json_object_field_or_empty(manifest, "resume_contract"),
    "runtime_consumer": json_object_field_or_empty(manifest, "runtime_consumer"),
    "engine": json_object_field_or_empty(manifest, "engine"),
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
