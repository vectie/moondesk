///|
/// Flush again on replay: earlier publication may have outlived a failed sync.
async fn mooncode_human_revision_capture(
  root : String,
  relative : String,
  text : String,
) -> Result[Unit, String] {
  match mooncode_continuation_create_once(root, relative, text) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let path = match mooncode_continuation_file(root, relative) {
    Ok(path) => path
    Err(error) => return Err(error)
  }
  try {
    let file = @fs.open(path, mode=ReadOnly)
    file.sync()
    file.close()
    let canonical = @fs.realpath(root)
    for parent = @pathx.dirname(path).to_owned() {
      let directory = @fs.open(parent, mode=ReadOnly)
      directory.sync()
      directory.close()
      if parent == canonical {
        break
      }
      continue @pathx.dirname(parent).to_owned()
    }
  } catch {
    _ => return Err("Human revision capture could not be durably retained")
  }
  Ok(())
}

///|
/// Capture a human-authored revision, never replace the live workspace output.
/// The lock serializes revision identity publication, not external file writers.
async fn mooncode_human_revision_save_locked(
  workspace : @desk.DeskWorkspace,
  raw_request : Json,
  capture : async (String, String, String) -> Result[Unit, String],
) -> (Int, Json) {
  let root = workspace.root_path
  let request = mooncode_human_revision_request(raw_request, root)
  let id = mooncode_output_text(request, "revision_id")
  let path = mooncode_output_text(
    mooncode_output_field(request, "output"),
    "path",
  )
  let content = mooncode_output_text(request, "content")
  let expected = mooncode_output_text(request, "expected_content")
  let saved = match
    mooncode_human_revision_read_json(root, id, "operation.json") {
    Ok(value) => value
    Err(error) =>
      return mooncode_human_revision_error(409, "idempotency_conflict", error)
  }
  let prepared = match saved {
    Some(value) => {
      let manifest = mooncode_output_field(value, "revision")
      if mooncode_output_text(value, "schema") !=
        "moondesk.human-revision-operation.v1" ||
        mooncode_output_field(value, "request") != request ||
        mooncode_output_text(manifest, "created_at").is_empty() ||
        manifest !=
        mooncode_human_revision_manifest(
          request,
          workspace.id,
          mooncode_output_text(manifest, "created_at"),
        ) {
        return mooncode_human_revision_error(
          409, "idempotency_conflict", "This revision identity already contains different input or lineage; retain its original operation",
        )
      }
      value
    }
    None => {
      for name in ["base.json", "conflict.json", "revision.json", "content.txt"] {
        match
          mooncode_continuation_read_text(
            root,
            mooncode_human_revision_path(id, name),
          ) {
          Ok(None) => ()
          _ =>
            return mooncode_human_revision_error(
              409, "idempotency_conflict", "Revision storage exists without its immutable operation; do not recapture this identity",
            )
        }
      }
      let revision = mooncode_human_revision_manifest(
        request,
        workspace.id,
        @async.now().to_string(),
      )
      let value : Json = {
        "schema": "moondesk.human-revision-operation.v1",
        "request": request,
        "revision": revision,
      }
      match
        capture(
          root,
          mooncode_human_revision_path(id, "operation.json"),
          value.stringify(),
        ) {
        Ok(_) => ()
        Err(error) =>
          return mooncode_human_revision_error(
            503, "capture_unavailable", error,
          )
      }
      value
    }
  }
  let conflict = match
    mooncode_human_revision_read_json(root, id, "conflict.json") {
    Ok(value) => value
    Err(error) =>
      return mooncode_human_revision_error(409, "idempotency_conflict", error)
  }
  if conflict is Some(value) {
    let current = mooncode_output_field(value, "current_content")
    if !(current is String(_)) ||
      value !=
      mooncode_session_with_field(
        mooncode_human_revision_marker(prepared, "conflict"),
        "current_content",
        current,
      ) {
      return mooncode_human_revision_error(
        409, "idempotency_conflict", "Saved conflict does not match this revision operation",
      )
    }
    // A previous publish may have survived a failed directory sync. A definite
    // conflict acknowledgement must retry durability, just like saved capture.
    match
      capture(
        root,
        mooncode_human_revision_path(id, "conflict.json"),
        value.stringify(),
      ) {
      Ok(_) => ()
      Err(error) =>
        return mooncode_human_revision_error(503, "capture_unavailable", error)
    }
    return mooncode_human_revision_conflict(current)
  }
  let observed = match
    mooncode_human_revision_read_json(root, id, "base.json") {
    Ok(value) => value
    Err(error) =>
      return mooncode_human_revision_error(409, "idempotency_conflict", error)
  }
  let marker = mooncode_human_revision_base_marker(prepared)
  if observed is Some(value) && value != marker {
    return mooncode_human_revision_error(
      409, "idempotency_conflict", "Saved base observation belongs to different revision input",
    )
  }
  if observed is None {
    match mooncode_human_revision_read_json(root, id, "revision.json") {
      Ok(None) => ()
      _ =>
        return mooncode_human_revision_error(
          409, "idempotency_conflict", "Published revision is missing its exact base observation",
        )
    }
    let current = match mooncode_human_revision_read_current(root, path) {
      Ok(value) => value
      Err(error) =>
        return mooncode_human_revision_error(409, "output_unavailable", error)
    }
    if current != expected {
      let record = mooncode_session_with_field(
        mooncode_human_revision_marker(prepared, "conflict"),
        "current_content",
        current.to_json(),
      )
      match
        capture(
          root,
          mooncode_human_revision_path(id, "conflict.json"),
          record.stringify(),
        ) {
        Ok(_) => ()
        Err(error) =>
          return mooncode_human_revision_error(
            503, "capture_unavailable", error,
          )
      }
      return mooncode_human_revision_conflict(current.to_json())
    }
  }
  // Existing observation survives source changes/deletion. Reflushing it also
  // repairs an uncertain earlier directory sync without touching the live file.
  match
    capture(
      root,
      mooncode_human_revision_path(id, "base.json"),
      marker.stringify(),
    ) {
    Ok(_) => ()
    Err(error) =>
      return mooncode_human_revision_error(503, "capture_unavailable", error)
  }
  match
    capture(root, mooncode_human_revision_path(id, "content.txt"), content) {
    Ok(_) => ()
    Err(error) =>
      return mooncode_human_revision_error(503, "capture_unavailable", error)
  }
  let revision = mooncode_output_field(prepared, "revision")
  match
    capture(
      root,
      mooncode_human_revision_path(id, "revision.json"),
      revision.stringify(),
    ) {
    Ok(_) => ()
    Err(error) =>
      return mooncode_human_revision_error(503, "capture_unavailable", error)
  }
  (
    200,
    {
      "schema": "moondesk.human-revision-editor.v1",
      "capture_scope": "immutable_human_revision",
      "state": "saved",
      "revision": revision,
      "content": content,
    },
  )
}

///|
fn mooncode_human_revision_conflict(current : Json) -> (Int, Json) {
  (
    409,
    mooncode_session_with_field(
      mooncode_human_revision_error(
        409, "conflict", "File changed after this draft was opened; refresh the baseline and keep your draft to create a new revision",
      ).1,
      "current_content",
      current,
    ),
  )
}
