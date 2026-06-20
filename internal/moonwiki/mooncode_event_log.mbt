///|
fn mooncode_sessions_dir(workspace_root : String) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    @mooncode.sessions_relative_dir(),
  )
}

///|
fn mooncode_session_log_dir(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(mooncode_sessions_dir(workspace_root), session_id)
}

///|
fn mooncode_event_log_path(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    @mooncode.event_log_relative_path(session_id),
  )
}

///|
fn mooncode_command_log_path(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    @mooncode.command_log_relative_path(session_id),
  )
}

///|
fn mooncode_runtime_command_log_path(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    @mooncode.runtime_command_log_relative_path(session_id),
  )
}

///|
fn mooncode_runtime_receipt_log_path(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    @mooncode.runtime_receipt_log_relative_path(session_id),
  )
}

///|
fn mooncode_session_snapshot_path(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    @mooncode.session_snapshot_relative_path(session_id),
  )
}

///|
fn mooncode_stream_checkpoint_dir(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    @mooncode.stream_checkpoint_relative_dir(session_id),
  )
}

///|
fn mooncode_stream_checkpoint_path(
  workspace_root : String,
  session_id : String,
  consumer_id : String,
) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    @mooncode.stream_checkpoint_relative_path(session_id, consumer_id),
  )
}

///|
fn mooncode_valid_session_id(session_id : String) -> Bool {
  @mooncode.session_id_valid(session_id)
}

///|
async fn read_mooncode_event_log(
  workspace_root : String,
  session_id : String,
) -> Array[Json] {
  if !mooncode_valid_session_id(session_id) {
    return []
  }
  let path = mooncode_event_log_path(workspace_root, session_id)
  let text = @fs.read_file(path).text() catch { _ => return [] }
  parse_mooncode_event_log_text(text)
}

///|
async fn read_mooncode_command_log(
  workspace_root : String,
  session_id : String,
) -> Array[Json] {
  if !mooncode_valid_session_id(session_id) {
    return []
  }
  let path = mooncode_command_log_path(workspace_root, session_id)
  let text = @fs.read_file(path).text() catch { _ => return [] }
  parse_mooncode_command_log_text(text)
}

///|
async fn read_mooncode_runtime_command_log(
  workspace_root : String,
  session_id : String,
) -> Array[Json] {
  if !mooncode_valid_session_id(session_id) {
    return []
  }
  let path = mooncode_runtime_command_log_path(workspace_root, session_id)
  let text = @fs.read_file(path).text() catch { _ => return [] }
  parse_mooncode_runtime_command_log_text(text)
}

///|
async fn read_mooncode_stream_checkpoint(
  workspace_root : String,
  session_id : String,
  consumer_id : String,
) -> Json {
  if !mooncode_valid_session_id(session_id) {
    return Json::object({})
  }
  let path = mooncode_stream_checkpoint_path(
    workspace_root, session_id, consumer_id,
  )
  let text = @fs.read_file(path).text() catch { _ => return Json::object({}) }
  @json.parse(text) catch {
    _ => Json::object({})
  }
}

///|
async fn read_mooncode_runtime_receipt_log(
  workspace_root : String,
  session_id : String,
) -> Array[Json] {
  if !mooncode_valid_session_id(session_id) {
    return []
  }
  let path = mooncode_runtime_receipt_log_path(workspace_root, session_id)
  let text = @fs.read_file(path).text() catch { _ => return [] }
  parse_mooncode_runtime_receipt_log_text(text)
}

///|
async fn read_mooncode_session_snapshot(
  workspace_root : String,
  session_id : String,
) -> Json? {
  if !mooncode_valid_session_id(session_id) {
    return None
  }
  let text = @fs.read_file(
    mooncode_session_snapshot_path(workspace_root, session_id),
  ).text() catch {
    _ => return None
  }
  let snapshot = @json.parse(text) catch { _ => return None }
  if @mooncode.session_snapshot_valid(snapshot) {
    Some(snapshot)
  } else {
    None
  }
}

///|
fn parse_mooncode_event_log_text(text : String) -> Array[Json] {
  @mooncode.parse_event_log_text(text)
}

///|
fn parse_mooncode_command_log_text(text : String) -> Array[Json] {
  @mooncode.parse_command_log_text(text)
}

///|
fn parse_mooncode_runtime_command_log_text(text : String) -> Array[Json] {
  @mooncode.parse_runtime_command_log_text(text)
}

///|
fn parse_mooncode_runtime_receipt_log_text(text : String) -> Array[Json] {
  @mooncode.parse_runtime_receipt_log_text(text)
}

///|
async fn append_mooncode_event_log(
  workspace_root : String,
  session_id : String,
  event : Json,
) -> Unit {
  if !mooncode_valid_session_id(session_id) {
    fail("invalid MoonCode session id: \{session_id}")
  }
  let dir = mooncode_session_log_dir(workspace_root, session_id)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  append_mooncode_jsonl_file(
    mooncode_event_log_path(workspace_root, session_id),
    event,
  )
}

///|
async fn append_mooncode_jsonl_file(path : String, item : Json) -> Unit {
  let existing = @fs.read_file(path).text() catch { _ => "" }
  @fsx.write_to_file(path, @mooncode.append_jsonl_text(existing, item))
}

///|
async fn write_mooncode_stream_checkpoint(
  workspace_root : String,
  session_id : String,
  consumer_id : String,
  checkpoint : Json,
) -> Unit {
  if !mooncode_valid_session_id(session_id) {
    fail("invalid MoonCode session id: \{session_id}")
  }
  let dir = mooncode_stream_checkpoint_dir(workspace_root, session_id)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    mooncode_stream_checkpoint_path(workspace_root, session_id, consumer_id),
    checkpoint.stringify(indent=2) + "\n",
  )
}

///|
async fn append_mooncode_command_log(
  workspace_root : String,
  session_id : String,
  command_packet : Json,
) -> Unit {
  if !mooncode_valid_session_id(session_id) {
    fail("invalid MoonCode session id: \{session_id}")
  }
  if !@mooncode.command_packet_valid(command_packet) {
    fail("invalid MoonCode command packet")
  }
  let dir = mooncode_session_log_dir(workspace_root, session_id)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  append_mooncode_jsonl_file(
    mooncode_command_log_path(workspace_root, session_id),
    command_packet,
  )
}

///|
async fn append_mooncode_runtime_command_log(
  workspace_root : String,
  session_id : String,
  runtime_command : Json,
) -> Unit {
  if !mooncode_valid_session_id(session_id) {
    fail("invalid MoonCode session id: \{session_id}")
  }
  if !@mooncode.runtime_command_record_valid(runtime_command) {
    fail("invalid MoonCode runtime command")
  }
  let dir = mooncode_session_log_dir(workspace_root, session_id)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  append_mooncode_jsonl_file(
    mooncode_runtime_command_log_path(workspace_root, session_id),
    runtime_command,
  )
}

///|
async fn append_mooncode_runtime_receipt_log(
  workspace_root : String,
  session_id : String,
  receipt : Json,
) -> Unit {
  if !mooncode_valid_session_id(session_id) {
    fail("invalid MoonCode session id: \{session_id}")
  }
  if !@mooncode.runtime_receipt_record_valid(receipt) {
    fail("invalid MoonCode runtime receipt")
  }
  let dir = mooncode_session_log_dir(workspace_root, session_id)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  append_mooncode_jsonl_file(
    mooncode_runtime_receipt_log_path(workspace_root, session_id),
    receipt,
  )
}

///|
async fn write_mooncode_session_snapshot(
  workspace_root : String,
  session_id : String,
  snapshot : Json,
) -> Unit {
  if !mooncode_valid_session_id(session_id) {
    fail("invalid MoonCode session id: \{session_id}")
  }
  if !@mooncode.session_snapshot_valid(snapshot) {
    fail("invalid MoonCode session snapshot")
  }
  let dir = mooncode_session_log_dir(workspace_root, session_id)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  @fsx.write_to_file(
    mooncode_session_snapshot_path(workspace_root, session_id),
    snapshot.stringify(indent=2) + "\n",
  )
}
