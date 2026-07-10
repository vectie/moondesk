///|
async test "mooncode session scope supports general chat without a moonbook" {
  let root = "/tmp/moondesk-general-mooncode-scope"
  let workspace = match resolve_mooncode_workspace_scope(root, "") {
    Ok(workspace) => workspace
    Err(message) => fail(message)
  }
  assert_eq(workspace.name, "General MoonCode")
  assert_eq(workspace.root_path, @pathx.normalize(root))
  assert_true(workspace.kind is SuiteRoot)
}

///|
async test "mooncode session scope still rejects unknown explicit workspace" {
  match
    resolve_mooncode_workspace_scope(
      "/tmp/moondesk-general-mooncode-scope", "missing",
    ) {
    Ok(_) => fail("unexpected workspace")
    Err(message) => assert_eq(message, "Unknown workspace")
  }
}

///|
test "mooncode immediate queued session appends canonical user event only" {
  let session : Json = {
    "id": "mooncode-demo",
    "workspace_id": "general",
    "workspace_name": "General MoonCode",
    "workspace_root": "/tmp/moondesk-general",
    "mooncode_runtime_session_id": "mooncode-demo",
  }
  let packet : Json = {
    "command_id": "cmd-1",
    "client_turn_id": "client-turn-1",
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "action": "prompt",
  }
  let queued = mooncode_immediate_queued_session(
    session,
    action="prompt",
    message="hello mooncode",
    context_path="",
    command_packet=packet,
    created_at="2026-06-15T00:00:00Z",
  )
  let events = json_array_items(queued, "mooncode_command_events")
  assert_eq(json_string(events[0], "status", default=""), "queued")
  assert_eq(json_string(events[0], "detail", default=""), "hello mooncode")
  assert_true(json_object_field(queued, "transcript") is None)
  assert_eq(json_string(queued, "status", default=""), "queued")
  assert_eq(json_string(queued, "last_message", default=""), "hello mooncode")
}

///|
async test "mooncode post enqueue response fails loudly without runtime" {
  let root = "/tmp/moondesk-mooncode-runtime-unavailable-" +
    @desk.stable_id("runtime-unavailable", @async.now().to_string())
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = @mooncode.projected_session_record(
    workspace_id="general",
    workspace_name="General MoonCode",
    workspace_root=root,
    runtime={
      "id": "",
      "status": "created",
      "model": "deepseek-v4-flash",
      "web_search": false,
      "queued_messages": [],
    },
    title="MoonCode - General",
    created_at="2026-06-15T00:00:00Z",
    updated_at="2026-06-15T00:00:00Z",
    last_message="hello mooncode",
    initial_context_path="",
  )
  let packet : Json = {
    "command_id": "cmd-runtime-unavailable",
    "client_turn_id": "client-turn-runtime-unavailable",
    "protocol": "mooncode.v1",
    "kind": "mooncode.command",
    "action": "prompt",
  }
  let queued = mooncode_immediate_queued_session(
    session,
    action="prompt",
    message="hello mooncode",
    context_path="",
    command_packet=packet,
    created_at="2026-06-15T00:00:00Z",
  )
  write_mooncode_session_record(root, queued)
  append_new_mooncode_command_events(root, session, queued)
  match
    mooncode_command_response_after_enqueue(root, queued, packet, {
      "max_turns": 1,
      "live_wait_ms": 1,
      "poll_ms": 1,
    }) {
    Ok(response) => fail(response.stringify())
    Err(error) => {
      assert_eq(json_int(error, "code", default=0), 409)
      assert_eq(json_string(error, "reason", default=""), "Conflict")
      assert_true(
        json_string(error, "message", default="").contains("MoonClaw"),
      )
    }
  }
  let events = read_mooncode_event_log(
    root,
    json_string(queued, "id", default=""),
  )
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "kind", default=""), "command.prompt")
}

///|
async test "runtime service failure appends command-scoped durable event once" {
  let root = "/tmp/moondesk-mooncode-runtime-service-failure-" +
    @desk.stable_id("runtime-service-failure", @async.now().to_string())
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session : Json = @mooncode.projected_session_record(
    workspace_id="general",
    workspace_name="General MoonCode",
    workspace_root=root,
    runtime={
      "id": "",
      "status": "created",
      "model": "deepseek-v4-flash",
      "web_search": false,
      "queued_messages": [],
    },
    title="MoonCode - General",
    created_at="2026-06-15T00:00:00Z",
    updated_at="2026-06-15T00:00:00Z",
    last_message="hello mooncode",
    initial_context_path="",
  )
  let payload : Json = {
    "message": "hello mooncode",
    "client_turn_id": "client-turn-runtime-service-failure",
    "model": "deepseek-v4-flash",
    "web_search": false,
  }
  let action = "prompt"
  let message = "hello mooncode"
  let now = "2026-06-15T00:00:00Z"
  let command_packet = @mooncode.projected_command_packet(
    session, payload, action, message, now, "",
  )
  let session_id = json_string(session, "id", default="")
  let queued = mooncode_immediate_queued_session(
    session,
    action~,
    message~,
    context_path="",
    command_packet~,
    created_at=now,
  )
  append_mooncode_command_log(root, session_id, command_packet)
  write_mooncode_session_record(root, queued)
  append_new_mooncode_command_events(root, session, queued)
  let error = mooncode_runtime_service_error(
    409, "Conflict", "MoonClaw daemon is not running",
  )
  let projected = record_mooncode_runtime_service_failure(
    root, session_id, queued, error,
  )
  let durable_events = read_mooncode_event_log(root, session_id)
  assert_eq(durable_events.length(), 2)
  assert_eq(
    json_string(durable_events[0], "kind", default=""),
    "command.prompt",
  )
  assert_eq(
    json_string(durable_events[1], "kind", default=""),
    "runtime_unavailable",
  )
  assert_eq(json_string(durable_events[1], "status", default=""), "failed")
  assert_eq(
    json_string(
      json_object_field_or_empty(durable_events[1], "command_packet"),
      "command_id",
      default="",
    ),
    json_string(command_packet, "command_id", default=""),
  )
  let conversation = json_object_field_or_empty(
    projected, "mooncode_conversation",
  )
  let turns = json_array_items(conversation, "turns")
  assert_eq(turns.length(), 0)
  match read_mooncode_session_record(root, session_id) {
    Some(stored) =>
      assert_eq(json_string(stored, "status", default=""), "failed")
    None => fail("missing stored MoonCode session")
  }
  ignore(
    record_mooncode_runtime_service_failure(root, session_id, queued, error),
  )
  assert_eq(read_mooncode_event_log(root, session_id).length(), 2)
}

///|
test "mooncode new session record starts with typed coding protocol" {
  let workspace = @desk.workspace(
    id="book-demo",
    name="Demo Book",
    root_path="/tmp/demo-book",
    kind=MoonBook,
  )
  let runtime : Json = {
    "id": "runtime-demo",
    "status": "created",
    "model": "default",
    "web_search": true,
  }
  let session = @mooncode.projected_session_record(
    workspace_id=workspace.id,
    workspace_name=workspace.name,
    workspace_root=workspace.root_path,
    runtime~,
    title="MoonCode - Demo Book",
    created_at="2026-06-15T00:00:00Z",
    updated_at="2026-06-15T00:00:00Z",
    last_message="Build a demo tool",
    initial_context_path="tools/demo/main.mbt",
  )
  assert_true(json_string(session, "id", default="").has_prefix("mooncode-"))
  assert_eq(json_string(session, "component", default=""), "mooncode")
  assert_eq(json_string(session, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(session, "mooncode_session_kind", default=""), "coding")
  assert_eq(
    json_string(session, "mooncode_initial_context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_eq(json_string(session, "workspace_id", default=""), "book-demo")
  assert_eq(
    json_string(session, "mooncode_runtime_session_id", default=""),
    json_string(session, "id", default=""),
  )
  assert_eq(
    json_string(session, "mooncode_runtime_session_id", default=""),
    json_string(session, "id", default=""),
  )
  assert_true(json_object_field(session, "transcript") is None)
}

///|
test "mooncode prompt command packet seeds durable session creation" {
  let session : Json = {
    "id": "mooncode-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "mooncode_runtime_session_id": "runtime-demo",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "client_turn_id": "client-turn-2",
    "web_search": false,
  }
  let packet = @mooncode.projected_command_packet(
    session, payload, "prompt", "Build a demo tool", "2026-06-15T00:00:00Z", "tools/demo/main.mbt",
  )
  assert_eq(json_string(packet, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(packet, "action", default=""), "prompt")
  assert_eq(json_string(packet, "client_turn_id", default=""), "client-turn-2")
  assert_eq(json_string(packet, "control", default=""), "prompt")
  assert_eq(json_string(packet, "approval", default=""), "user")
  assert_eq(
    json_string(packet, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_true(
    json_string_array_items(packet, "expected_lanes").contains("diff"),
  )
  assert_true(json_string_array_items(packet, "tool_hints").contains("write"))
  let queued = @mooncode.append_projected_command_event(
    session,
    action="prompt",
    status="queued",
    detail="Build a demo tool",
    created_at="2026-06-15T00:00:00Z",
    path="tools/demo/main.mbt",
    command_packet=packet,
  )
  let events = project_mooncode_events(queued, [], [])
  let summary = @mooncode.session_summary(queued, events)
  assert_eq(json_int(summary, "command_packet_count", default=0), 1)
  assert_eq(json_int(summary, "event_count", default=0), 1)
  assert_eq(json_string(events[0], "lane", default=""), "runtime")
}

///|
test "mooncode summary and eval report use extracted protocol" {
  let event = @mooncode.event_record(
    id="d1",
    lane="diff",
    kind="tool.write",
    title="Write file",
    status="done",
    created_at="1",
    detail="updated file",
    path="tools/demo/main.mbt",
    diff="+fn main { println(\"ok\") }",
  )
  let session : Json = {
    "id": "s1",
    "workspace_id": "book-demo",
    "mooncode_runtime_session_id": "runtime-demo",
    "mooncode_append_log_count": 1,
    "mooncode_command_log_count": 1,
    "mooncode_runtime_command_log_count": 1,
  }
  let extracted_summary = @mooncode.session_summary(session, [event])
  assert_eq(json_int(extracted_summary, "diff_count", default=0), 1)
  assert_eq(
    json_string(extracted_summary, "review_state", default=""),
    "pending",
  )
  let with_summary = mooncode_session_with_field(
    session, "mooncode_summary", extracted_summary,
  )
  let extracted_report = @mooncode.eval_report_projection(with_summary)
  assert_eq(
    json_string(extracted_report, "kind", default=""),
    "mooncode-eval-report",
  )
  assert_eq(
    json_string(extracted_report, "standalone_component", default=""),
    "mooncode",
  )
}

///|
test "mooncode runtime execution root follows the persisted MoonBook" {
  let session : Json = {
    "id": "session-book-root",
    "workspace_root": "/tmp/moonsuite/books/code-lab",
  }
  assert_eq(
    mooncode_session_execution_root(session, fallback="/tmp/moonsuite"),
    "/tmp/moonsuite/books/code-lab",
  )
  assert_eq(
    mooncode_session_execution_root(
      { "id": "general" },
      fallback="/tmp/moonsuite",
    ),
    "/tmp/moonsuite",
  )
}
