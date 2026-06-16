///|
async fn write_mooncode_eval_report_manifest(session : Json) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode eval report needs a MoonBook workspace root")
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.eval_report_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let summary = @mooncode.session_summary(session, events)
  let report = @mooncode.eval_report_projection(
    agent_session_with_field(session, "mooncode_summary", summary),
  )
  let recorded_at = @async.now().to_string()
  let manifest = agent_session_with_field(
    agent_session_with_field(
      agent_session_with_field(report, "recorded_at", recorded_at.to_json()),
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
async fn write_mooncode_session_snapshot_if_possible(
  workspace_root : String,
  session : Json,
) -> Json {
  let session_id = json_string(session, "id", default="")
  if session_id == "" {
    fail("MoonCode session snapshot needs a session id")
  }
  let events = project_mooncode_events(session, [], [])
  let commands = read_mooncode_command_log(workspace_root, session_id)
  let runtime_commands = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  )
  let runtime_dispatches = read_mooncode_runtime_dispatch_log(
    workspace_root, session_id,
  )
  let session_id = json_string(session, "id", default="")
  let snapshot = @mooncode.session_snapshot(
    session,
    events,
    commands,
    runtime_commands,
    runtime_dispatches,
    recorded_at=@async.now().to_string(),
    snapshot_path=mooncode_session_snapshot_path(workspace_root, session_id),
    command_log_path=mooncode_command_log_path(workspace_root, session_id),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    event_log_path=mooncode_event_log_path(workspace_root, session_id),
  )
  write_mooncode_session_snapshot(workspace_root, session_id, snapshot)
  agent_session_with_field(session, "mooncode_session_snapshot", snapshot)
}

///|
async fn write_mooncode_runtime_handoff_manifest(
  workspace_root : String,
  session : Json,
) -> Json {
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    fail("MoonCode runtime handoff needs a MoonBook workspace root")
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let relative = @mooncode.runtime_handoff_manifest_relative_path(session_id)
  let absolute = @pathx.join(book_root, relative)
  @fsx.make_directory(@pathx.dirname(absolute), recursive=true, exists_ok=true)
  let events = project_mooncode_events(session, [], [])
  let commands = read_mooncode_command_log(workspace_root, session_id)
  let runtime_commands = read_mooncode_runtime_command_log(
    workspace_root, session_id,
  )
  let runtime_dispatches = read_mooncode_runtime_dispatch_log(
    workspace_root, session_id,
  )
  let summary = @mooncode.session_summary(session, events)
  let daemon = moonclaw_daemon_status(workspace_root)
  let daemon_running = json_bool(daemon, "running", default=false)
  let native_ready = if daemon_running {
    mooncode_native_runtime_ready(daemon) catch {
      _ => false
    }
  } else {
    false
  }
  let runtime_replay = mooncode_runtime_replay_state(
    session_id,
    runtime_commands,
    runtime_dispatches,
    workspace_id=json_string(session, "workspace_id", default=""),
    workspace_name=json_string(session, "workspace_name", default=""),
    task_id=json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
  )
  let runtime_claim = mooncode_runtime_claim_state(
    session_id,
    runtime_commands,
    runtime_dispatches,
    workspace_id=json_string(session, "workspace_id", default=""),
    workspace_name=json_string(session, "workspace_name", default=""),
    task_id=json_string(session, "moonclaw_task_id", default=""),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
  )
  let recorded_at = @async.now().to_string()
  let manifest = @mooncode.runtime_handoff_manifest(
    session,
    summary,
    runtime_replay,
    runtime_claim,
    commands,
    runtime_commands,
    runtime_dispatches,
    daemon,
    native_ready,
    recorded_at~,
    manifest_path=relative,
    absolute_manifest_path=absolute,
    workspace_root=book_root,
    session_snapshot_path=mooncode_session_snapshot_path(
      workspace_root, session_id,
    ),
    command_log_path=mooncode_command_log_path(workspace_root, session_id),
    runtime_command_log_path=mooncode_runtime_command_log_path(
      workspace_root, session_id,
    ),
    runtime_dispatch_log_path=mooncode_runtime_dispatch_log_path(
      workspace_root, session_id,
    ),
    event_log_path=mooncode_event_log_path(workspace_root, session_id),
    stream_checkpoint_path=mooncode_stream_checkpoint_path(
      workspace_root, session_id, "moondesk-ui",
    ),
  )
  @fsx.write_to_file(absolute, manifest.stringify(indent=2) + "\n")
  manifest
}

///|
async fn mooncode_read_change_set_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_change_set_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-change-set" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.change_set_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-change-set" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_patch_set_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_patch_set_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-patch-set" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.patch_set_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-patch-set" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_tool_approvals_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_tool_approvals_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-tool-approvals" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.tool_approvals_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-tool-approvals" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_test_runs_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_test_runs_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-test-runs" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.test_runs_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-test-runs" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_eval_report_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_eval_report_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-eval-report" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.eval_report_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-eval-report" {
    Some(manifest)
  } else {
    None
  }
}

///|
async fn mooncode_read_runtime_handoff_manifest(session : Json) -> Json? {
  match json_object_field(session, "mooncode_last_runtime_handoff_manifest") {
    Some(manifest) =>
      if json_string(manifest, "kind", default="") == "mooncode-runtime-handoff" {
        return Some(manifest)
      }
    None => ()
  }
  let book_root = mooncode_review_receipt_book_root(
    session,
    json_object_field_or_empty(session, "mooncode_last_command_packet"),
  )
  if book_root == "" {
    return None
  }
  let session_id = @mooncode.artifact_safe_id(
    json_string(session, "id", default="session"),
    fallback="session",
  )
  let absolute = @pathx.join(
    book_root,
    @mooncode.runtime_handoff_manifest_relative_path(session_id),
  )
  let text = @fs.read_file(absolute).text() catch { _ => return None }
  let manifest = @json.parse(text) catch { _ => return None }
  if json_string(manifest, "kind", default="") == "mooncode-runtime-handoff" {
    Some(manifest)
  } else {
    None
  }
}

///|
fn mooncode_tool_authorization_preview_event(
  payload : Json,
  created_at : String,
) -> Json {
  @mooncode.tool_authorization_preview_event(
    payload,
    created_at,
    fallback_id=@desk.stable_id(
      "mooncode-tool-auth",
      payload.stringify() + ":" + created_at,
    ),
  )
}

///|
fn mooncode_tool_authorization_response(
  session : Json,
  preview : Json,
  events : Array[Json],
) -> Json {
  @mooncode.tool_authorization_response(
    json_string(session, "id", default=""),
    preview,
    events,
    json_object_field_or_empty(session, "mooncode_last_tool_approvals_manifest"),
  )
}

///|
fn mooncode_action_plan_items(
  session : Json,
  commands : Array[Json],
  runtime_commands : Array[Json],
  runtime_dispatches : Array[Json],
  events : Array[Json],
) -> Array[Json] {
  let summary = @mooncode.session_summary(session, events)
  @mooncode.action_plan_items(
    commands,
    runtime_commands,
    runtime_dispatches,
    events,
    summary,
    lease_now=@async.now().to_string(),
  )
}

///|
fn mooncode_change_set_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.change_set_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-change-set",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_patch_set_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.patch_set_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-patch-set",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_tool_approvals_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.tool_approvals_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-tool-approvals",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_test_runs_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.test_runs_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-test-runs",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_action_plan_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.action_plan_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-action-plan",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_runtime_evidence_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.runtime_evidence_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-runtime-evidence",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_eval_report_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.eval_report_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-eval-report",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}

///|
fn mooncode_runtime_handoff_manifest_event(manifest : Json) -> Json {
  let manifest_path = json_string(manifest, "manifest_path", default="")
  @mooncode.runtime_handoff_manifest_event(
    manifest,
    @desk.stable_id(
      "mooncode-runtime-handoff",
      json_string(manifest, "session_id", default="session") +
      ":" +
      manifest_path,
    ),
  )
}
