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
fn mooncode_runtime_dispatch_log_path(
  workspace_root : String,
  session_id : String,
) -> String {
  @pathx.join(
    @pathx.normalize(workspace_root),
    @mooncode.runtime_dispatch_log_relative_path(session_id),
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
async fn read_mooncode_runtime_dispatch_log(
  workspace_root : String,
  session_id : String,
) -> Array[Json] {
  if !mooncode_valid_session_id(session_id) {
    return []
  }
  let path = mooncode_runtime_dispatch_log_path(workspace_root, session_id)
  let text = @fs.read_file(path).text() catch { _ => return [] }
  parse_mooncode_runtime_dispatch_log_text(text)
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
fn parse_mooncode_runtime_dispatch_log_text(text : String) -> Array[Json] {
  @mooncode.parse_runtime_dispatch_log_text(text)
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
async fn append_mooncode_runtime_dispatch_log(
  workspace_root : String,
  session_id : String,
  receipt : Json,
) -> Unit {
  if !mooncode_valid_session_id(session_id) {
    fail("invalid MoonCode session id: \{session_id}")
  }
  if !@mooncode.runtime_dispatch_record_valid(receipt) {
    fail("invalid MoonCode runtime dispatch receipt")
  }
  let dir = mooncode_session_log_dir(workspace_root, session_id)
  @fsx.make_directory(dir, recursive=true, exists_ok=true)
  append_mooncode_jsonl_file(
    mooncode_runtime_dispatch_log_path(workspace_root, session_id),
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

///|
test "mooncode parses jsonl event log and skips invalid lines" {
  let event = @mooncode.event_record(
    id="event-1",
    lane="runtime",
    kind="command.note",
    title="Note",
    status="queued",
    created_at="1",
    detail="hello",
  )
  let events = parse_mooncode_event_log_text(
    event.stringify() + "\nnot-json\n\n" + event.stringify() + "\n",
  )
  assert_eq(events.length(), 2)
  assert_eq(json_string(events[0], "id", default=""), "event-1")
}

///|
test "mooncode event merge dedupes durable log against inline commands" {
  let event = @mooncode.event_record(
    id="event-1",
    lane="review",
    kind="command.accept",
    title="Accept",
    status="queued",
    created_at="1",
    detail="accepted",
  )
  let merged = @mooncode.merge_events([], [event], [event])
  assert_eq(merged.length(), 1)
  assert_eq(json_string(merged[0], "lane", default=""), "review")
}

///|
async test "mooncode appends and replays durable session event log" {
  let root = "/tmp/moondesk-mooncode-event-log-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let event = @mooncode.event_record(
    id="event-1",
    lane="runtime",
    kind="command.note",
    title="Note",
    status="queued",
    created_at="1",
    detail="hello",
  )
  let second = @mooncode.event_record(
    id="event-2",
    lane="test",
    kind="test_result",
    title="Tests",
    status="passed",
    created_at="2",
    detail="passed",
  )
  append_mooncode_event_log(root, session_id, event)
  append_mooncode_event_log(root, session_id, second)
  let events = read_mooncode_event_log(root, session_id)
  assert_eq(events.length(), 2)
  assert_eq(json_string(events[0], "id", default=""), "event-1")
  assert_eq(json_string(events[1], "id", default=""), "event-2")
  assert_true(@fs.exists(mooncode_event_log_path(root, session_id)))
}

///|
test "mooncode parses command log and requires typed packets" {
  let command : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_command(),
    "command_id": "cmd-1",
    "action": "prompt",
  }
  let commands = parse_mooncode_command_log_text(
    command.stringify() +
    "\nnot-json\n{\"protocol\":\"other\",\"command_id\":\"bad\"}\n",
  )
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "command_id", default=""), "cmd-1")
}

///|
test "mooncode parses runtime command log and requires typed records" {
  let command : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_runtime_command(),
    "command_id": "cmd-1",
    "serve_command": "prompt",
  }
  let commands = parse_mooncode_runtime_command_log_text(
    command.stringify() +
    "\nnot-json\n{\"protocol\":\"mooncode.v1\",\"kind\":\"mooncode.command\",\"command_id\":\"bad\"}\n",
  )
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "serve_command", default=""), "prompt")
}

///|
test "mooncode parses runtime dispatch log and requires typed receipts" {
  let receipt : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_runtime_dispatch(),
    "command_id": "cmd-1",
    "status": "recorded",
  }
  let receipts = parse_mooncode_runtime_dispatch_log_text(
    receipt.stringify() +
    "\nnot-json\n{\"protocol\":\"mooncode.v1\",\"kind\":\"mooncode.command\",\"command_id\":\"bad\"}\n",
  )
  assert_eq(receipts.length(), 1)
  assert_eq(json_string(receipts[0], "status", default=""), "recorded")
}

///|
async test "mooncode appends and replays durable command queue" {
  let root = "/tmp/moondesk-mooncode-command-log-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let command : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_command(),
    "command_id": "cmd-1",
    "action": "prompt",
  }
  append_mooncode_command_log(root, session_id, command)
  let commands = read_mooncode_command_log(root, session_id)
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "action", default=""), "prompt")
  assert_true(@fs.exists(mooncode_command_log_path(root, session_id)))
}

///|
async test "mooncode appends and replays durable runtime command feed" {
  let root = "/tmp/moondesk-mooncode-runtime-command-log-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let command : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_runtime_command(),
    "command_id": "cmd-1",
    "serve_command": "prompt",
  }
  append_mooncode_runtime_command_log(root, session_id, command)
  let commands = read_mooncode_runtime_command_log(root, session_id)
  assert_eq(commands.length(), 1)
  assert_eq(json_string(commands[0], "serve_command", default=""), "prompt")
  assert_true(@fs.exists(mooncode_runtime_command_log_path(root, session_id)))
}

///|
async test "mooncode appends and replays durable runtime dispatch receipts" {
  let root = "/tmp/moondesk-mooncode-runtime-dispatch-log-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let receipt : Json = {
    "protocol": @mooncode.protocol_version(),
    "kind": @mooncode.kind_runtime_dispatch(),
    "command_id": "cmd-1",
    "status": "recorded",
  }
  append_mooncode_runtime_dispatch_log(root, session_id, receipt)
  let receipts = read_mooncode_runtime_dispatch_log(root, session_id)
  assert_eq(receipts.length(), 1)
  assert_eq(json_string(receipts[0], "status", default=""), "recorded")
  assert_true(@fs.exists(mooncode_runtime_dispatch_log_path(root, session_id)))
}

///|
async test "mooncode writes and reads typed durable session snapshot" {
  let root = "/tmp/moondesk-mooncode-session-snapshot-wbtest-" +
    @async.now().to_string()
  let session_id = "session-a"
  let snapshot : Json = {
    "kind": "mooncode-session-snapshot",
    "protocol": @mooncode.protocol_version(),
    "session_id": session_id,
  }
  write_mooncode_session_snapshot(root, session_id, snapshot)
  match read_mooncode_session_snapshot(root, session_id) {
    Some(read_back) =>
      assert_eq(json_string(read_back, "session_id", default=""), session_id)
    None => fail("snapshot should be readable")
  }
  assert_true(@fs.exists(mooncode_session_snapshot_path(root, session_id)))
}
