///|
async fn handle_mooncode_session_stream(
  workspace_root : String,
  session_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let format = query_value(request_path, "format").unwrap_or("jsonl")
  let since = @mooncode.stream_since_value(
    query_value(request_path, "since").unwrap_or(""),
  )
  let content_type = @mooncode.stream_content_type(format)
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => {
      let live = @mooncode.stream_live_enabled_value(
        query_value(request_path, "live").unwrap_or(""),
      )
      let live_timeout_ms = @mooncode.stream_live_timeout_ms_value(
        query_value(request_path, "timeout_ms").unwrap_or(""),
      )
      let live_poll_ms = @mooncode.stream_live_poll_ms_value(
        query_value(request_path, "poll_ms").unwrap_or(""),
      )
      match
        mooncode_native_stream_text(workspace_root, session_id, format, since) {
        Ok(text) => send_text(conn, method_, content_type, text)
        Err(_) => {
          let projected = if live {
            mooncode_live_stream_projection(
              workspace_root, session_id, session, since, live_timeout_ms, live_poll_ms,
            )
          } else {
            attach_mooncode_session_projection(workspace_root, session)
          }
          let events = json_array_items(projected, "mooncode_events")
          if format == "sse" {
            send_text(
              conn,
              method_,
              content_type,
              @mooncode.stream_sse_text(projected, events, since~),
            )
          } else {
            send_text(
              conn,
              method_,
              content_type,
              @mooncode.stream_jsonl_text(projected, events, since~),
            )
          }
        }
      }
    }
    None =>
      match
        mooncode_native_stream_text(workspace_root, session_id, format, since) {
        Ok(text) => send_text(conn, method_, content_type, text)
        Err(_) =>
          send_api_error(
            conn, method_, 404, "Not Found", "Unknown MoonCode session",
          )
      }
  }
}

///|
async fn handle_mooncode_session_stream_state(
  workspace_root : String,
  session_id : String,
  request_path : String,
  body : &@io.Reader,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let session = match read_agent_session_record(workspace_root, session_id) {
    Some(session) => session
    None => {
      send_api_error(
        conn, method_, 404, "Not Found", "Unknown MoonCode session",
      )
      return
    }
  }
  let since = @mooncode.stream_since_value(
    query_value(request_path, "since").unwrap_or(""),
  )
  if method_ is @http.RequestMethod::Post {
    let payload = match read_json_body(body) {
      Some(json) => json
      None => {
        send_api_error(conn, method_, 400, "Bad Request", "Invalid JSON body")
        return
      }
    }
    let consumer_id = @mooncode.stream_checkpoint_consumer_id(
      payload,
      query_value(request_path, "consumer").unwrap_or(""),
    )
    let projected = attach_mooncode_session_projection(workspace_root, session)
    let events = json_array_items(projected, "mooncode_events")
    let requested_sequence = @mooncode.stream_checkpoint_sequence(
      payload,
      since,
      events.length(),
    )
    let checkpoint = mooncode_stream_checkpoint_record(
      workspace_root,
      projected,
      consumer_id,
      requested_sequence,
      events.length(),
    )
    write_mooncode_stream_checkpoint(
      workspace_root, session_id, consumer_id, checkpoint,
    ) catch {
      _ => {
        send_api_error(
          conn, method_, 500, "Internal Server Error", "Could not save MoonCode stream checkpoint",
        )
        return
      }
    }
    send_json(
      conn,
      method_,
      mooncode_stream_state_projection(
        workspace_root, projected, since, consumer_id,
      ),
    )
  } else {
    let consumer_id = @mooncode.stream_checkpoint_consumer_id(
      Json::object({}),
      query_value(request_path, "consumer").unwrap_or(""),
    )
    send_json(
      conn,
      method_,
      mooncode_stream_state_projection(
        workspace_root, session, since, consumer_id,
      ),
    )
  }
}

///|
async fn mooncode_live_stream_projection(
  workspace_root : String,
  session_id : String,
  fallback_session : Json,
  since : Int,
  timeout_ms : Int,
  poll_ms : Int,
) -> Json {
  let initial = attach_mooncode_session_projection(
    workspace_root, fallback_session,
  )
  if json_array_items(initial, "mooncode_events").length() > since ||
    timeout_ms <= 0 {
    return initial
  }
  let attempts = @mooncode.stream_live_attempt_count(timeout_ms, poll_ms)
  for _ in 0..<attempts {
    @async.sleep(poll_ms)
    match read_agent_session_record(workspace_root, session_id) {
      Some(session) => {
        let projected = attach_mooncode_session_projection(
          workspace_root, session,
        )
        if json_array_items(projected, "mooncode_events").length() > since {
          return projected
        }
      }
      None => ()
    }
  }
  match read_agent_session_record(workspace_root, session_id) {
    Some(session) => attach_mooncode_session_projection(workspace_root, session)
    None => initial
  }
}

///|
fn mooncode_stream_checkpoint_record(
  workspace_root : String,
  session : Json,
  consumer_id : String,
  last_seen_sequence : Int,
  latest_sequence : Int,
) -> Json {
  let session_id = json_string(session, "id", default="")
  let clamped = @mooncode.stream_checkpoint_sequence(
    { "last_seen_sequence": last_seen_sequence },
    0,
    latest_sequence,
  )
  @mooncode.moondesk_stream_checkpoint_record(
    session,
    consumer_id,
    clamped,
    latest_sequence,
    @async.now().to_string(),
    mooncode_stream_checkpoint_path(workspace_root, session_id, consumer_id),
  )
}

///|
async fn mooncode_stream_state_projection(
  workspace_root : String,
  session : Json,
  since : Int,
  consumer_id : String,
) -> Json {
  let projected = attach_mooncode_session_projection(workspace_root, session)
  let session_id = json_string(projected, "id", default="")
  let events = json_array_items(projected, "mooncode_events")
  let checkpoint = read_mooncode_stream_checkpoint(
    workspace_root, session_id, consumer_id,
  )
  @mooncode.moondesk_stream_state_projection_record(
    projected,
    events,
    since,
    consumer_id,
    mooncode_event_log_path(workspace_root, session_id),
    mooncode_stream_checkpoint_path(workspace_root, session_id, consumer_id),
    checkpoint,
    @mooncode.moonclaw_native_stream_endpoint(
      session_id, workspace_root, "sse", since,
    ),
  )
}

///|
async fn mooncode_native_stream_text(
  workspace_root : String,
  session_id : String,
  format : String,
  since : Int,
) -> Result[String, String] {
  let daemon = moonclaw_daemon_status(workspace_root)
  let running = json_bool(daemon, "running", default=false)
  if !running {
    return Err("MoonClaw daemon is not running")
  }
  if !mooncode_native_runtime_ready(daemon) {
    return Err("MoonClaw MoonCode runtime is not available")
  }
  moonclaw_get_text(
    daemon,
    @mooncode.moonclaw_native_stream_endpoint(
      session_id, workspace_root, format, since,
    ),
  )
}

///|
test "mooncode jsonl stream includes meta events and done records" {
  let event = @mooncode.event_record(
    id="e1",
    lane="test",
    kind="command.run_tests",
    title="Run tests: queued",
    status="queued",
    created_at="1",
    detail="Run tests",
  )
  let fields : Map[String, Json] = {}
  fields["id"] = "s1".to_json()
  fields["workspace_id"] = "book".to_json()
  fields["moonclaw_task_id"] = "task".to_json()
  fields["mooncode_events"] = Json::array([event])
  let session = Json::object(fields)
  let text = @mooncode.stream_jsonl_text(session, [event])
  let lines = text.trim().split("\n").to_array()
  assert_eq(lines.length(), 3)
  let meta = @json.parse(lines[0].to_owned()) catch { _ => Json::object({}) }
  let item = @json.parse(lines[1].to_owned()) catch { _ => Json::object({}) }
  let done = @json.parse(lines[2].to_owned()) catch { _ => Json::object({}) }
  assert_eq(json_string(meta, "type", default=""), "meta")
  assert_eq(json_int(meta, "event_count", default=0), 1)
  assert_eq(json_int(meta, "since", default=-1), 0)
  assert_eq(json_int(meta, "emitted_count", default=0), 1)
  assert_eq(json_int(meta, "next_since", default=0), 1)
  assert_eq(
    json_string(meta, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_eq(json_string(item, "type", default=""), "event")
  assert_eq(json_int(item, "sequence", default=0), 1)
  assert_eq(
    json_string(item, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_eq(json_string(done, "type", default=""), "done")
  assert_eq(json_int(done, "next_since", default=0), 1)
  assert_eq(
    json_string(done, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
}

///|
test "mooncode jsonl stream supports incremental since sequence" {
  let first = @mooncode.event_record(
    id="e1",
    lane="tool",
    kind="tool.read",
    title="Read",
    status="done",
    created_at="1",
    detail="first",
  )
  let second = @mooncode.event_record(
    id="e2",
    lane="diff",
    kind="tool.write",
    title="Write",
    status="done",
    created_at="2",
    detail="second",
  )
  let fields : Map[String, Json] = {}
  fields["id"] = "s1".to_json()
  fields["mooncode_events"] = Json::array([first, second])
  let session = Json::object(fields)
  let text = @mooncode.stream_jsonl_text(session, [first, second], since=1)
  let lines = text.trim().split("\n").to_array()
  assert_eq(lines.length(), 3)
  let meta = @json.parse(lines[0].to_owned()) catch { _ => Json::object({}) }
  let item = @json.parse(lines[1].to_owned()) catch { _ => Json::object({}) }
  let done = @json.parse(lines[2].to_owned()) catch { _ => Json::object({}) }
  assert_eq(json_string(meta, "stream", default=""), "append-log-incremental")
  assert_eq(
    json_string(meta, "stream_source", default=""),
    "moondesk-append-log-projection",
  )
  assert_eq(json_int(meta, "since", default=0), 1)
  assert_eq(json_int(meta, "emitted_count", default=0), 1)
  assert_eq(json_int(meta, "next_since", default=0), 2)
  assert_eq(json_int(item, "sequence", default=0), 2)
  let event_payload = match item {
    Json::Object(object) => object.get("event").unwrap_or(Json::object({}))
    _ => Json::object({})
  }
  assert_eq(json_string(event_payload, "id", default=""), "e2")
  assert_eq(json_int(done, "sequence", default=0), 2)
}

///|
async test "mooncode stream state records resumable checkpoint" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-mooncode-stream-state-wbtest-" +
    @desk.stable_id("mooncode-stream-state", @async.now().to_string()),
  )
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "moonclaw_task_id": "task-demo",
  }
  append_mooncode_event_log(
    root,
    "agent-demo",
    @mooncode.event_record(
      id="event-1",
      lane="runtime",
      kind="assistant_delta",
      title="Assistant delta",
      status="running",
      created_at="1",
      detail="first",
    ),
  )
  append_mooncode_event_log(
    root,
    "agent-demo",
    @mooncode.event_record(
      id="event-2",
      lane="test",
      kind="test_result",
      title="Tests passed",
      status="passed",
      created_at="2",
      detail="second",
    ),
  )
  assert_eq(read_mooncode_event_log(root, "agent-demo").length(), 2)
  let state = mooncode_stream_state_projection(root, session, 1, "moondesk-ui")
  assert_eq(json_string(state, "kind", default=""), "mooncode-stream-state")
  assert_eq(json_int(state, "latest_sequence", default=0), 2)
  assert_eq(json_int(state, "emitted_count", default=0), 1)
  assert_eq(json_int(state, "next_since", default=0), 2)
  assert_false(json_bool(state, "checkpoint_ready", default=true))
  let tail = json_array_items(state, "tail_events")
  assert_eq(tail.length(), 1)
  assert_eq(json_int(tail[0], "sequence", default=0), 2)
  assert_eq(
    json_string(
      json_object_field_or_empty(tail[0], "event"),
      "kind",
      default="",
    ),
    "test_result",
  )
  let checkpoint = mooncode_stream_checkpoint_record(
    root,
    session,
    "moondesk-ui",
    json_int(state, "next_since", default=0),
    2,
  )
  write_mooncode_stream_checkpoint(
    root, "agent-demo", "moondesk-ui", checkpoint,
  )
  let resumed = mooncode_stream_state_projection(
    root, session, 2, "moondesk-ui",
  )
  assert_true(json_bool(resumed, "checkpoint_ready", default=false))
  assert_eq(json_int(resumed, "emitted_count", default=-1), 0)
  let saved = json_object_field_or_empty(resumed, "checkpoint")
  assert_eq(
    json_string(saved, "kind", default=""),
    "mooncode-stream-checkpoint",
  )
  assert_eq(json_int(saved, "last_seen_sequence", default=0), 2)
  assert_true(@fs.exists(json_string(saved, "checkpoint_path", default="")))
  assert_true(
    json_string(resumed, "checkpoint_endpoint", default="").contains(
      "/api/mooncode/sessions/agent-demo/stream-state",
    ),
  )
  let native_tail = json_string(
    json_object_field_or_empty(resumed, "live_tail_boundary"),
    "native_blocking_tail",
    default="",
  )
  assert_true(
    native_tail.contains(
      @mooncode.moonclaw_native_stream_endpoint("agent-demo", root, "sse", 2),
    ),
  )
}

///|
test "mooncode native stream path targets typed runtime endpoint" {
  assert_eq(
    @mooncode.moonclaw_native_stream_endpoint(
      "agent-demo", "/tmp/moon book", "sse", 7,
    ),
    "/v1/mooncode/sessions/agent-demo/stream?book_root=%2Ftmp%2Fmoon%20book&format=sse&since=7",
  )
}

///|
test "mooncode stream live query opts into bounded tail" {
  assert_true(
    @mooncode.stream_live_enabled_value(
      query_value(
        "/api/mooncode/sessions/s1/stream?format=sse&since=2&live=true", "live",
      ).unwrap_or(""),
    ),
  )
  assert_true(
    @mooncode.stream_live_enabled_value(
      query_value(
        "/api/mooncode/sessions/s1/stream?format=jsonl&live=wait", "live",
      ).unwrap_or(""),
    ),
  )
  assert_false(
    @mooncode.stream_live_enabled_value(
      query_value("/api/mooncode/sessions/s1/stream?live=false", "live").unwrap_or(
        "",
      ),
    ),
  )
  assert_eq(
    @mooncode.stream_live_timeout_ms_value(
      query_value(
        "/api/mooncode/sessions/s1/stream?timeout_ms=20000", "timeout_ms",
      ).unwrap_or(""),
    ),
    15000,
  )
  assert_eq(
    @mooncode.stream_live_poll_ms_value(
      query_value("/api/mooncode/sessions/s1/stream?poll_ms=10", "poll_ms").unwrap_or(
        "",
      ),
    ),
    50,
  )
  assert_eq(
    @mooncode.stream_content_type("sse"),
    "text/event-stream; charset=utf-8",
  )
}

///|
test "mooncode sse stream uses named events" {
  let event = @mooncode.event_record(
    id="e1",
    lane="artifact",
    kind="command.package",
    title="Package result: queued",
    status="queued",
    created_at="1",
    detail="Package",
  )
  let fields : Map[String, Json] = {}
  fields["id"] = "s1".to_json()
  fields["mooncode_events"] = Json::array([event])
  let session = Json::object(fields)
  let text = @mooncode.stream_sse_text(session, [event])
  assert_true(text.contains("event: mooncode.meta\n"))
  assert_true(text.contains("event: mooncode.event\n"))
  assert_true(text.contains("event: mooncode.done\n"))
}
