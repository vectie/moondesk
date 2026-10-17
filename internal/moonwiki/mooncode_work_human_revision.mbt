///|
/// Bound editing uses only native GET evidence and immutable local capture.
/// Live workspace output bytes are never written by this operation.
async fn mooncode_edit_work_output(
  workspace_root : String,
  workspaces : Array[@desk.DeskWorkspace],
  request : Json,
  read : async (String) -> Result[Json, String],
  capture~ : async (String, String, String) -> Result[Unit, String] = mooncode_human_revision_capture,
) -> (Int32, Json) {
  let operation = mooncode_output_text(request, "operation")
  let source = mooncode_output_field(request, "source")
  let output = mooncode_output_field(request, "output")
  let id = mooncode_output_text(request, "revision_id")
  if !["open", "save"].contains(operation) ||
    ["task_id", "run_id", "session_id", "original_command_id"].any(key => {
      !mooncode_continuation_native_id(mooncode_output_text(source, key))
    }) ||
    !mooncode_continuation_native_id(mooncode_output_text(output, "command_id")) ||
    mooncode_output_text(output, "evidence_id").is_empty() ||
    mooncode_output_text(output, "evidence_id").length() > 4096 ||
    !mooncode_human_revision_editable(mooncode_output_text(output, "path")) {
    return mooncode_human_revision_error(
      400, "invalid_request", "Select an exact work output with valid source and evidence identities",
    )
  }
  if operation == "save" {
    if !mooncode_continuation_valid_id(id) ||
      !(mooncode_output_field(request, "content") is String(_)) ||
      !(mooncode_output_field(request, "expected_content") is String(_)) {
      return mooncode_human_revision_error(
        400, "invalid_request", "Save requires a stable revision_id, content and explicit expected_content baseline",
      )
    }
    for key in ["content", "expected_content"] {
      let text = mooncode_output_text(request, key)
      if @encoding/utf8.encode(text).length() > 256 * 1024 ||
        text.contains("\u0000") {
        return mooncode_human_revision_error(
          400, "invalid_request", "Human revision supports at most 256 KiB of UTF-8 text without binary NUL bytes",
        )
      }
    }
  }
  let target = mooncode_continuation_request_target(request)
  let workspace = match mooncode_work_workspace(target, workspaces) {
    Ok(value) => value
    Err((status, failure)) =>
      return mooncode_human_revision_error(
        status,
        mooncode_output_text(failure, "state"),
        mooncode_output_text(failure, "message"),
      )
  }
  let (status, descriptor) = mooncode_resolve_work_handoff(
    workspace_root,
    workspaces,
    target,
    read,
    include_continuations=true,
  )
  if status != 200 {
    return mooncode_human_revision_error(
      status,
      mooncode_output_text(descriptor, "state"),
      mooncode_output_text(descriptor, "message"),
    )
  }
  let verified = mooncode_work_output_projection(descriptor, output)
  if mooncode_output_text(verified, "state") != "ready" {
    return mooncode_human_revision_error(
      409,
      "output_unavailable",
      mooncode_output_text(verified, "message"),
    )
  }
  // A continuation's captured task/run cannot be relabeled by editor hints.
  if mooncode_output_text(output, "command_id") != target.command_id {
    let records = mooncode_output_items(descriptor, "continuations").filter(item => {
      mooncode_output_text(item, "command_id") ==
      mooncode_output_text(output, "command_id")
    })
    if records.length() != 1 ||
      mooncode_human_revision_source(
        mooncode_output_field(records[0], "source"),
        workspace.root_path,
      ) !=
      mooncode_human_revision_source(source, workspace.root_path) {
      return mooncode_human_revision_error(
        409, "identity_mismatch", "The continuation belongs to different task or run lineage",
      )
    }
  }
  let path = mooncode_output_text(verified, "path")
  if operation == "open" {
    let content = match
      mooncode_human_revision_read_current(workspace.root_path, path) {
      Ok(value) => value
      Err(error) =>
        return mooncode_human_revision_error(409, "output_unavailable", error)
    }
    return (
      200,
      {
        "schema": "moondesk.human-revision-editor.v1",
        "state": "ready",
        "capture_scope": "immutable_human_revision",
        "source": mooncode_human_revision_source(source, workspace.root_path),
        "output": mooncode_human_revision_output(verified),
        "workspace_id": workspace.id,
        "content": content,
        "base_digest": mooncode_continuation_hash(content),
      },
    )
  }
  let lock_path = match
    mooncode_continuation_file(
      workspace.root_path,
      ".moonsuite/products/moonproj/human-revisions/.capture.lock",
      write=true,
    ) {
    Ok(value) => value
    Err(error) =>
      return mooncode_human_revision_error(503, "storage_unavailable", error)
  }
  let lock = @fs.open(
    lock_path,
    mode=ReadWrite,
    create_mode=OpenOrCreate,
    permission=0o600,
  ) catch {
    _ =>
      return mooncode_human_revision_error(
        503, "storage_unavailable", "Revision capture lock is unavailable",
      )
  }
  defer lock.close()
  lock.lock(Exclusive)
  defer lock.unlock()
  mooncode_human_revision_save_locked(workspace, request, capture)
}

///|
async fn handle_mooncode_work_human_revision(
  workspace_root : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let request = match mooncode_human_revision_read_body(body) {
    Some(value) => value
    None => Json::null()
  }
  // Existing daemon metadata only: this editor never auto-starts a service.
  let daemon = moonclaw_model_route_daemon_candidate(workspace_root)
  let (status, payload) = mooncode_edit_work_output(
    workspace_root,
    discover_workspaces(workspace_root),
    request,
    path => moonclaw_get_json(daemon, path),
  ) catch {
    _ =>
      mooncode_human_revision_error(
        503, "capture_unavailable", "The revision capture could not be confirmed; retain the exact revision identity and draft for retry",
      )
  }
  conn.send_response(
    status,
    if status == 200 {
      "OK"
    } else if status == 400 {
      "Bad Request"
    } else if status == 409 {
      "Conflict"
    } else {
      "Service Unavailable"
    },
    extra_headers={
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  )
  if !(method_ is Head) {
    conn.write(payload.stringify())
  }
  conn.end_response()
}
