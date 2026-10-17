///|
fn mooncode_human_revision_path(id : String, name : String) -> String {
  ".moonsuite/products/moonproj/human-revisions/" + id + "/" + name
}

///|
fn mooncode_human_revision_error(
  status : Int32,
  state : String,
  message : String,
) -> (Int32, Json) {
  (
    status,
    {
      "schema": "moondesk.human-revision-editor.v1",
      "state": state,
      "message": message,
    },
  )
}

///|
fn mooncode_human_revision_output(output : Json) -> Json {
  {
    "command_id": mooncode_output_text(output, "command_id"),
    "path": mooncode_output_text(output, "path"),
    "evidence_id": mooncode_output_text(output, "evidence_id"),
  }
}

///|
fn mooncode_human_revision_source(source : Json, root : String) -> Json {
  {
    "task_id": mooncode_output_text(source, "task_id"),
    "run_id": mooncode_output_text(source, "run_id"),
    "session_id": mooncode_output_text(source, "session_id"),
    "original_command_id": mooncode_output_text(source, "original_command_id"),
    "book_root": mooncode_work_normalized_root(root),
  }
}

///|
fn mooncode_human_revision_request(request : Json, root : String) -> Json {
  {
    "operation": "save",
    "revision_id": mooncode_output_text(request, "revision_id"),
    "source": mooncode_human_revision_source(
      mooncode_output_field(request, "source"),
      root,
    ),
    "output": mooncode_human_revision_output(
      mooncode_output_field(request, "output"),
    ),
    "expected_content": mooncode_output_text(request, "expected_content"),
    "content": mooncode_output_text(request, "content"),
  }
}

///|
fn mooncode_human_revision_manifest(
  request : Json,
  workspace_id : String,
  created_at : String,
) -> Json {
  let source = mooncode_output_field(request, "source")
  let id = mooncode_output_text(request, "revision_id")
  let content = mooncode_output_text(request, "content")
  {
    "schema": "moonproj.human-revision.v1",
    "capture_scope": "immutable_human_revision",
    "revision_id": id,
    "task_id": mooncode_output_text(source, "task_id"),
    "original_run_id": mooncode_output_text(source, "run_id"),
    "session_id": mooncode_output_text(source, "session_id"),
    "original_command_id": mooncode_output_text(source, "original_command_id"),
    "workspace": mooncode_output_text(source, "book_root"),
    "workspace_id": workspace_id,
    "output": mooncode_output_field(request, "output"),
    "author_type": "human",
    "base": {
      "scope": "current_workspace_bytes_at_edit",
      "sha256": mooncode_continuation_hash(
        mooncode_output_text(request, "expected_content"),
      ),
    },
    "content": {
      "path": mooncode_human_revision_path(id, "content.txt"),
      "sha256": mooncode_continuation_hash(content),
      "size_bytes": @encoding/utf8.encode(content).length(),
    },
    "state": "saved",
    "created_at": created_at,
  }
}

///|
/// Preserve the existing output path policy; only this feature's immutable
/// revision storage must not become its own editable output.
fn mooncode_human_revision_editable(path : String) -> Bool {
  mooncode_output_path_valid(path) &&
  !path.has_prefix(".moonsuite/products/moonproj/human-revisions/")
}

///|
/// Use the existing confined source policy and preserve the native relative
/// path literally (no URL decoding).
async fn mooncode_human_revision_read_current(
  root : String,
  relative : String,
) -> Result[String, String] {
  let canonical = @fs.realpath(root) catch {
    _ => return Err("The selected MoonBook is unavailable")
  }
  let path = match @fsx.resolve_confined_existing(root, relative) {
    Some(path) if (@fs.kind(path) catch { _ => Directory }) is Regular => path
    _ => return Err("The exact output must be an existing confined file")
  }
  if path.has_prefix(
      canonical + "/.moonsuite/products/moonproj/human-revisions/",
    ) {
    return Err("Immutable human revision storage cannot be an editable output")
  }
  let file = @fs.open(path, mode=ReadOnly) catch {
    _ => return Err("The exact output file cannot be read")
  }
  defer file.close()
  let size = file.size()
  if size > 256L * 1024L {
    return Err("Human revision supports at most 256 KiB of UTF-8 text")
  }
  let bytes = file.read_exactly_at(size.to_int(), position=0L) catch {
    _ => return Err("The exact output file cannot be read")
  }
  if file.size() != size {
    return Err(
      "The source changed while being read; retry without discarding the draft",
    )
  }
  let text = @encoding/utf8.decode(bytes) catch {
    _ => return Err("Human revision supports UTF-8 text files only")
  }
  if text.contains("\u0000") {
    return Err("Human revision does not support binary files")
  }
  Ok(text)
}

///|
async fn mooncode_human_revision_read_json(
  root : String,
  id : String,
  name : String,
) -> Result[Json?, String] {
  match
    mooncode_continuation_read_text(
      root,
      mooncode_human_revision_path(id, name),
    ) {
    Err(error) => Err(error)
    Ok(None) => Ok(None)
    Ok(Some(text)) => {
      let value = @json.parse(text) catch {
        _ => return Err("Saved human revision operation is invalid")
      }
      Ok(Some(value))
    }
  }
}

///|
fn mooncode_human_revision_marker(prepared : Json, state : String) -> Json {
  {
    "schema": "moondesk.human-revision-outcome.v1",
    "prepared_sha256": mooncode_continuation_hash(prepared.stringify()),
    "state": state,
  }
}

///|
fn mooncode_human_revision_base_marker(prepared : Json) -> Json {
  {
    "schema": "moondesk.human-revision-base-observation.v1",
    "prepared_sha256": mooncode_continuation_hash(prepared.stringify()),
    "scope": "current_workspace_bytes_at_edit",
    "sha256": mooncode_continuation_hash(
      mooncode_output_text(
        mooncode_output_field(prepared, "request"),
        "expected_content",
      ),
    ),
  }
}

///|
/// The two 256 KiB text fields can expand sixfold when JSON escaped. Four MiB
/// bounds transport allocation while preserving every accepted byte exactly.
async fn mooncode_human_revision_read_body(body : &@io.Reader) -> Json? {
  let limit = 4 * 1024 * 1024
  let bytes = @buffer.Buffer(size_hint=8192)
  while body.read_some(max_len=(limit + 1 - bytes.length()).min(65536))
        is Some(chunk) {
    if bytes.length() + chunk.length() > limit {
      return None
    }
    bytes.write_bytes(chunk)
  }
  Some(@json.parse(@encoding/utf8.decode(bytes.to_bytes()))) catch {
    _ => None
  }
}
