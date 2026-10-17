///|
fn mooncode_continuation_hash(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@encoding/utf8.encode(text)))
}

///|
fn mooncode_continuation_limits(snapshot : Json) -> Result[Unit, String] {
  if @encoding/utf8.encode(json_string(snapshot, "input_text", default="")).length() >
    4 * 1024 * 1024 {
    Err(
      "Captured follow-up input exceeds the shared 4 MiB UTF-8 limit; nothing was submitted",
    )
  } else if @encoding/utf8.encode(snapshot.stringify()).length() >
    8 * 1024 * 1024 {
    Err(
      "Complete continuation snapshot exceeds the shared 8 MiB UTF-8 limit; nothing was submitted",
    )
  } else if @encoding/utf8.encode(
      json_string(snapshot, "request_body", default=""),
    ).length() >
    1024 * 1024 {
    Err(
      "Prepared native request exceeds the 1 MiB bound-work request limit; nothing was submitted",
    )
  } else {
    Ok(())
  }
}

///|
fn mooncode_continuation_valid_id(value : String) -> Bool {
  !value.is_empty() &&
  value.length() <= 128 &&
  value
  .iter()
  .all(c => {
    c.is_ascii_digit() ||
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    c == '-' ||
    c == '_'
  })
}

///|
fn mooncode_continuation_native_id(value : String) -> Bool {
  !value.is_empty() &&
  value.length() <= 128 &&
  value
  .iter()
  .all(c => {
    c.is_ascii_digit() ||
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    c == '_' ||
    c == '-' ||
    c == '.' ||
    c == ':'
  })
}

///|
fn mooncode_continuation_base() -> String {
  ".moonsuite/products/moonproj/human-continuations"
}

///|
fn mooncode_continuation_path(id : String, name : String) -> String {
  mooncode_continuation_base() + "/" + id + "/" + name
}

///|
/// Refuse symlink aliases as well as escapes. These artifacts are immutable
/// identities, so a different in-book alias is not an interchangeable target.
async fn mooncode_continuation_file(
  root : String,
  relative : String,
  write~ : Bool = false,
) -> Result[String, String] {
  let canonical = @fs.realpath(root) catch {
    _ => return Err("MoonBook is unavailable")
  }
  let path = if write {
    @fsx.resolve_confined_write(canonical, relative) catch {
      _ => return Err("Continuation storage cannot be resolved")
    }
  } else {
    @fsx.resolve_confined_existing(canonical, relative) catch {
      _ => return Err("Continuation storage cannot be resolved")
    }
  }
  match path {
    Some(path) if path == @pathx.join(canonical, relative) =>
      if @fs.exists(path) && !(@fs.kind(path, follow_symlink=false) is Regular) {
        Err("Continuation storage must be a direct regular file")
      } else {
        Ok(path)
      }
    _ =>
      Err("Continuation storage is outside the verified MoonBook or is missing")
  }
}

///|
async fn mooncode_continuation_read_text(
  root : String,
  relative : String,
) -> Result[String?, String] {
  let canonical = @fs.realpath(root) catch {
    _ => return Err("MoonBook is unavailable")
  }
  // Reading a missing K must not create directories or files. Check every
  // existing component, including dangling symlinks, before reporting absence.
  let mut component = canonical
  for part in relative.split("/") {
    component = @pathx.join(component, part.to_owned())
    let kind = @fs.kind(component, follow_symlink=false) catch {
      @os_error.OSError(_) as error if error.is_ENOENT() => return Ok(None)
      _ => return Err("Continuation storage could not be inspected")
    }
    if kind is SymLink {
      return Err("Continuation storage cannot traverse a symlink")
    }
  }
  let path = match mooncode_continuation_file(root, relative) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let file = @fs.open(path, mode=ReadOnly) catch {
    _ => return Err("Continuation snapshot cannot be read")
  }
  defer file.close()
  if file.size() > 8L * 1024L * 1024L {
    return Err("Continuation snapshot exceeds its size limit")
  }
  let text = file.read_all().text() catch {
      _ => return Err("Continuation snapshot is not readable UTF-8")
    }
  Ok(Some(text))
}

///|
/// Publish fully flushed bytes once. A temporary file is never considered a
/// captured submission. Parent-directory sync makes the published name durable.
async fn mooncode_continuation_create_once(
  root : String,
  relative : String,
  text : String,
) -> Result[Unit, String] {
  let path = match mooncode_continuation_file(root, relative, write=true) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if @fs.exists(path) {
    return match mooncode_continuation_read_text(root, relative) {
      Ok(Some(old)) if old == text => Ok(())
      _ => Err("Immutable continuation input conflicts with existing bytes")
    }
  }
  let temporary = path + ".pending-" + @async.now().to_string()
  try {
    let file = @fs.open(
      temporary,
      mode=WriteOnly,
      create_mode=CreateNew,
      permission=0o600,
    )
    defer file.close()
    file.write(@encoding/utf8.encode(text))
    file.sync()
    @fs.rename(temporary, path, replace=false)
    let canonical_root = @fs.realpath(root)
    for parent = @pathx.dirname(path).to_owned() {
      let directory = @fs.open(parent, mode=ReadOnly)
      directory.sync()
      directory.close()
      if parent == canonical_root {
        break
      }
      continue @pathx.dirname(parent).to_owned()
    }
  } catch {
    _ => return Err("Could not durably capture immutable continuation input")
  }
  Ok(())
}

///|
fn mooncode_continuation_source_matches(
  source : Json,
  target : MoonCodeWorkTarget,
) -> Bool {
  json_string(source, "session_id", default="") == target.session_id &&
  json_string(source, "original_command_id", default="") == target.command_id &&
  mooncode_work_normalized_root(json_string(source, "book_root", default="")) ==
  mooncode_work_normalized_root(target.book_root)
}

///|
fn mooncode_continuation_lineage(snapshot : Json) -> Json {
  let source = json_object_field_or_empty(snapshot, "source")
  {
    "schema": "moonproj.work-continuation.v1",
    "continuation_id": json_string(snapshot, "continuation_id", default=""),
    "task_id": json_string(source, "task_id", default=""),
    "run_id": json_string(source, "run_id", default=""),
    "original_command_id": json_string(
      source,
      "original_command_id",
      default="",
    ),
    "prior_result_command_id": json_string(
      snapshot,
      "prior_result_command_id",
      default="",
    ),
    "input": json_object_field_or_empty(snapshot, "input"),
  }
}

///|
fn mooncode_continuation_dispatch_marker(snapshot : Json) -> Json {
  {
    "schema": "moondesk.work-continuation-dispatch.v1",
    "command_id": json_string(snapshot, "command_id", default=""),
    "client_turn_id": json_string(snapshot, "client_turn_id", default=""),
    "request_sha256": json_string(snapshot, "request_sha256", default=""),
  }
}

///|
/// Missing native readback after a possible POST must remain unconfirmed after
/// reload. This create-once marker records only possibility, never acceptance.
async fn mooncode_continuation_unobserved_admission(
  root : String,
  snapshot : Json,
) -> Result[String, String] {
  let id = json_string(snapshot, "continuation_id", default="")
  match
    mooncode_continuation_read_text(
      root,
      mooncode_continuation_path(id, "dispatch.json"),
    ) {
    Ok(None) => Ok("not_sent")
    Ok(Some(text)) => {
      let marker = @json.parse(text) catch {
        _ => return Err("Continuation dispatch marker is invalid")
      }
      if marker == mooncode_continuation_dispatch_marker(snapshot) {
        Ok("unconfirmed")
      } else {
        Err("Continuation dispatch marker belongs to another request")
      }
    }
    Err(error) => Err(error)
  }
}

///|
fn mooncode_continuation_validate_snapshot(
  snapshot : Json,
  id : String,
  target : MoonCodeWorkTarget,
) -> Result[Json, String] {
  match mooncode_continuation_limits(snapshot) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let source = json_object_field_or_empty(snapshot, "source")
  let input = json_object_field_or_empty(snapshot, "input")
  let request = json_string(snapshot, "request_body", default="")
  let input_text = json_string(snapshot, "input_text", default="")
  let body = @json.parse(request) catch {
    _ => return Err("Saved native request is invalid")
  }
  let packet = json_object_field_or_empty(body, "packet")
  let payload = json_object_field_or_empty(body, "payload")
  if json_string(snapshot, "schema", default="") !=
    "moondesk.work-continuation-snapshot.v1" ||
    json_string(snapshot, "continuation_id", default="") != id ||
    !mooncode_continuation_source_matches(source, target) ||
    json_string(source, "task_id", default="").is_empty() ||
    json_string(source, "run_id", default="").is_empty() ||
    json_string(input, "path", default="") !=
    mooncode_continuation_path(id, "input.md") ||
    mooncode_continuation_hash(input_text) !=
    json_string(input, "sha256", default="") ||
    mooncode_continuation_hash(request) !=
    json_string(snapshot, "request_sha256", default="") ||
    json_string(body, "protocol", default="") != "mooncode.v1" ||
    json_string(body, "command", default="") != "prompt" ||
    json_string(body, "session_id", default="") != target.session_id ||
    mooncode_work_normalized_root(json_string(body, "book_root", default="")) !=
    mooncode_work_normalized_root(target.book_root) ||
    json_string(body, "context_path", default="") !=
    json_string(input, "path", default="") ||
    json_string(body, "model", default="") !=
    json_string(snapshot, "model", default="") ||
    json_string(body, "text", default="") !=
    json_string(snapshot, "instruction", default="") ||
    json_string(packet, "command_id", default="") !=
    json_string(snapshot, "command_id", default="") ||
    json_string(packet, "client_turn_id", default="") !=
    json_string(snapshot, "client_turn_id", default="") ||
    json_object_field(payload, "moonproj_continuation") !=
    Some(mooncode_continuation_lineage(snapshot)) ||
    json_string(snapshot, "command_id", default="").is_empty() ||
    json_string(snapshot, "command_id", default="") == target.command_id ||
    json_string(snapshot, "client_turn_id", default="").is_empty() {
    return Err(
      "Saved continuation identity or input digest does not match its captured native request",
    )
  }
  for
    key in [
      "horizon_id", "horizon_checkpoint", "horizon_evidence", "next_action", "task_intent",
      "approval_id", "planner_continuation", "plan", "tool_calls",
    ] {
    if json_object_field(body, key) is Some(_) ||
      json_object_field(payload, key) is Some(_) {
      return Err(
        "Saved continuation contains executable state from another command",
      )
    }
  }
  if !json_array_items(body, "runtime_tool_calls").is_empty() ||
    !json_array_items(payload, "runtime_tool_calls").is_empty() {
    return Err("Saved continuation contains inherited runtime tool calls")
  }
  let command = match @mooncode.decode_command_submission(packet) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if command.web_search ||
    command.task_intent is Some(_) ||
    command.planner_max_steps is Some(_) ||
    command.planner_reasoning_effort != "none" ||
    command.force_preflight ||
    !command.content_parts.is_empty() ||
    !mooncode_continuation_native_id(command.client_turn_id) {
    return Err("Saved continuation does not use the fixed bound-work options")
  }
  let session : Json = {
    "id": target.session_id,
    "workspace_id": json_string(packet, "workspace_id", default=""),
    "workspace_name": json_string(packet, "workspace_name", default=""),
    "workspace_root": json_string(source, "book_root", default=""),
    "model": json_string(snapshot, "model", default=""),
  }
  let rebuilt = @mooncode.native_command_body(
    session,
    command,
    json_string(snapshot, "created_at", default=""),
    { "moonproj_continuation": mooncode_continuation_lineage(snapshot) },
  )
  if rebuilt != body {
    return Err(
      "Saved native request is not the allowed fresh bound-work command",
    )
  }
  Ok(body)
}

///|
async fn mooncode_continuation_load(
  root : String,
  id : String,
  target : MoonCodeWorkTarget,
  repair_input~ : Bool = false,
  allow_missing_input~ : Bool = false,
) -> Result[Json?, String] {
  if !mooncode_continuation_valid_id(id) {
    return Err("Invalid continuation_id")
  }
  let text = match
    mooncode_continuation_read_text(
      root,
      mooncode_continuation_path(id, "submission.json"),
    ) {
    Ok(Some(value)) => value
    Ok(None) => return Ok(None)
    Err(error) => return Err(error)
  }
  let snapshot = @json.parse(text) catch {
    _ => return Err("Saved continuation snapshot is invalid")
  }
  match mooncode_continuation_validate_snapshot(snapshot, id, target) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let input_path = mooncode_continuation_path(id, "input.md")
  let expected = json_string(snapshot, "input_text", default="")
  match mooncode_continuation_read_text(root, input_path) {
    Ok(Some(value)) if value == expected => ()
    Ok(None) if repair_input =>
      match mooncode_continuation_create_once(root, input_path, expected) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    Ok(None) if allow_missing_input =>
      return Ok(
        Some(
          snapshot
          |> mooncode_session_with_field("input_status", "missing".to_json()),
        ),
      )
    Ok(None) =>
      return Err(
        "Saved continuation input is missing; resume can restore its captured bytes",
      )
    _ =>
      return Err(
        "Immutable continuation input bytes failed integrity verification",
      )
  }
  Ok(Some(snapshot))
}
