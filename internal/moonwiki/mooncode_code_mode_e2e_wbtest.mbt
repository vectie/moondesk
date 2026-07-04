///|
async test "mooncode code mode durable session reload projects command runtime and stream state" {
  let root = "/tmp/moondesk-code-mode-e2e-" +
    @desk.stable_id("code-mode-e2e", @async.now().to_string())
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  let session = @mooncode.session_record(
    session_id="code-demo",
    workspace_id="book-demo",
    workspace_name="Demo Book",
    workspace_root=root,
    runtime={
      "id": "runtime-demo",
      "status": "created",
      "model": "deepseek-v4-flash",
      "web_search": false,
      "queued_messages": [],
    },
    title="MoonCode - Demo Book",
    created_at="2026-06-30T00:00:00Z",
    updated_at="2026-06-30T00:00:00Z",
    last_message="Run the parser tests",
    initial_context_path="tools/parser/main.mbt",
  )
  write_mooncode_session_record(root, session)

  let payload : Json = {
    "context_path": "tools/parser/main.mbt",
    "model": "deepseek-v4-flash",
  }
  let message = @mooncode.command_message("run_tests", payload)
  let packet = @mooncode.projected_command_packet(
    session, payload, "run_tests", message, "2026-06-30T00:01:00Z", "tools/parser/main.mbt",
  )
  let runtime_command = @mooncode.runtime_command_record(
    session, payload, message, packet,
  )
  append_mooncode_command_log(root, "code-demo", packet)
  append_mooncode_runtime_command_log(root, "code-demo", runtime_command)
  append_mooncode_runtime_receipt_log(
    root,
    "code-demo",
    @mooncode.projected_runtime_receipt(
      session, runtime_command, "2026-06-30T00:01:10Z",
    ),
  )

  let queued = @mooncode.append_projected_command_event(
    session,
    action="run_tests",
    status="queued",
    detail=message,
    created_at="2026-06-30T00:01:00Z",
    path="tools/parser/main.mbt",
    command_packet=packet,
  )
  append_new_mooncode_command_events(root, session, queued)
  let command_id = json_string(packet, "command_id", default="")
  for
    event in @mooncode.runtime_ingest_events(
      {
        "events": [
          {
            "event": "tool_call",
            "id": "tool-call-check",
            "created_at": "2026-06-30T00:01:30Z",
            "tool_name": "moon_check",
            "tool_call_id": "call-check",
            "arguments": "{\"command\":\"moon check\"}",
            "command_id": command_id,
            "action": "run_tests",
          },
          {
            "event": "tool_result",
            "id": "tool-result-check",
            "created_at": "2026-06-30T00:01:40Z",
            "tool_name": "moon_check",
            "tool_call_id": "call-check",
            "content": "moon check passed",
            "command_id": command_id,
            "action": "run_tests",
          },
          {
            "event": "test_result",
            "id": "test-result",
            "created_at": "2026-06-30T00:02:00Z",
            "status": "passed",
            "command": "moon test internal/parser",
            "exit_code": 0,
            "detail": "Total tests: 8, passed: 8",
            "command_id": command_id,
            "action": "run_tests",
          },
          {
            "event": "runtime_finished",
            "id": "runtime-finished",
            "created_at": "2026-06-30T00:02:30Z",
            "answer": "tests passed",
            "command_id": command_id,
            "action": "run_tests",
          },
        ],
      },
      ingested_at="2026-06-30T00:03:00Z",
    ) {
    append_mooncode_event_log(root, "code-demo", event)
  }

  guard read_mooncode_session_record(root, "code-demo") is Some(reloaded) else {
    fail("expected durable MoonCode session record")
  }
  let projected = attach_mooncode_session_projection(root, reloaded)
  let events = json_array_items(projected, "mooncode_events")
  let summary = json_object_field_or_empty(projected, "mooncode_summary")
  assert_eq(events.length(), 5)
  assert_eq(json_int(summary, "command_packet_count", default=0), 1)
  assert_eq(json_int(summary, "event_count", default=0), 5)
  assert_eq(json_int(summary, "verified_test_count", default=0), 2)
  assert_eq(json_int(summary, "command_log_count", default=0), 1)
  assert_eq(json_int(summary, "runtime_command_count", default=0), 1)
  assert_eq(json_int(summary, "runtime_receipt_count", default=0), 1)
  assert_true(
    json_string(summary, "event_log_path", default="").contains(
      "/.moonsuite/products/mooncode/sessions/code-demo/events.jsonl",
    ),
  )
  assert_true(
    json_string(summary, "runtime_command_log_path", default="").contains(
      "/.moonsuite/products/mooncode/sessions/code-demo/runtime-commands.jsonl",
    ),
  )

  let stream = @mooncode.stream_jsonl_text(projected, events, since=1)
  assert_false(stream.contains("command.run_tests"))
  assert_true(stream.contains("tool-call-check"))
  assert_true(stream.contains("test-result"))

  let state = mooncode_stream_state_projection(
    root, reloaded, 2, "code-mode-ui",
  )
  assert_eq(json_string(state, "session_id", default=""), "code-demo")
  assert_eq(json_int(state, "latest_sequence", default=0), 5)
  assert_eq(json_int(state, "next_since", default=0), 5)
}

///|
async test "mooncode code mode package result promotes package candidates to verified" {
  let root = "/tmp/moondesk-code-mode-package-e2e-" +
    @desk.stable_id("code-mode-package-e2e", @async.now().to_string())
  @fsx.make_directory(
    @pathx.join(root, "tools/parser"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(root, "tools/parser/main.mbt"),
    "fn main { println(\"parser\") }\n",
  )
  let session : Json = {
    "id": "code-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": root,
    "mooncode_runtime_session_id": "runtime-demo",
    "mooncode_runtime_mode": "moonclaw-mooncode-runtime",
    "component": "mooncode",
    "protocol": "mooncode.v1",
  }
  write_mooncode_session_record(root, session)
  let payload : Json = { "context_path": "tools/parser/main.mbt" }
  let message = @mooncode.command_message("package", payload)
  let packet = @mooncode.projected_command_packet(
    session, payload, "package", message, "2026-06-30T01:00:00Z", "tools/parser/main.mbt",
  )
  let runtime_command = @mooncode.runtime_command_record(
    session, payload, message, packet,
  )
  append_mooncode_command_log(root, "code-demo", packet)
  append_mooncode_runtime_command_log(root, "code-demo", runtime_command)
  append_mooncode_runtime_receipt_log(
    root,
    "code-demo",
    @mooncode.projected_runtime_receipt(
      session, runtime_command, "2026-06-30T01:00:10Z",
    ),
  )
  let receipt = write_mooncode_review_receipt(
    session, "package", packet, "tools/parser/main.mbt", message, "2026-06-30T01:00:00Z",
  )
  let recorded_at = json_string(receipt, "recorded_at", default="")
  let with_receipt = @mooncode.session_with_review_receipt_event(
    session,
    receipt,
    @mooncode.review_receipt_projected_event(
      "package",
      json_string(receipt, "receipt_path", default=""),
      "tools/parser/main.mbt",
      recorded_at,
      packet,
    ),
  )
  let with_package = mooncode_session_with_field(
    write_mooncode_package_manifest_for_receipt(
      with_receipt, receipt, packet, "tools/parser/main.mbt", message, "2026-06-30T01:00:00Z",
    ),
    "updated_at",
    recorded_at.to_json(),
  )
  write_mooncode_session_record(root, with_package)
  let initial_candidates = mooncode_package_candidates_projection(
    with_package, "code-demo",
  )
  assert_eq(json_string(initial_candidates, "status", default=""), "candidate")
  assert_eq(
    json_string(initial_candidates, "package_index_status", default=""),
    "source-bound",
  )
  assert_eq(json_int(initial_candidates, "package_count", default=0), 1)
  assert_eq(
    json_int(initial_candidates, "runtime_package_proof_count", default=-1),
    0,
  )

  let ingest_report = @mooncode.package_result_ingest_report(
    {
      "protocol": "mooncode.v1",
      "session_id": "code-demo",
      "command_id": json_string(packet, "command_id", default=""),
      "event": @mooncode.event_package_verified(),
      "path": "tools/parser/main.mbt",
      "detail": "runtime verified packaged parser tool",
    },
    session_id="code-demo",
    ingested_at="2026-06-30T01:01:00Z",
  )
  assert_eq(json_string(ingest_report, "status", default=""), "accepted")
  let package_events = json_array_items(ingest_report, "events")
  assert_eq(package_events.length(), 1)
  let final_session = persist_mooncode_runtime_events_and_projection(
    root, "code-demo", with_package, package_events,
  )
  let final_candidates = mooncode_package_candidates_projection(
    final_session, "code-demo",
  )
  assert_eq(
    json_string(final_candidates, "kind", default=""),
    "mooncode-package-candidates",
  )
  assert_eq(json_string(final_candidates, "status", default=""), "verified")
  assert_eq(json_int(final_candidates, "package_count", default=0), 1)
  assert_eq(
    json_int(final_candidates, "runtime_package_proof_count", default=0),
    1,
  )
  assert_eq(
    json_int(
      final_candidates,
      "package_index_executable_ready_count",
      default=0,
    ),
    1,
  )
  let packages = json_array_items(final_candidates, "packages")
  assert_eq(packages.length(), 1)
  assert_eq(json_string(packages[0], "execution_state", default=""), "verified")
  assert_true(json_bool(packages[0], "execution_verified", default=false))
  assert_true(
    @fs.exists(
      @pathx.join(root, "portable/app-tool/mooncode/code-demo/index.json"),
    ),
  )
  assert_eq(read_mooncode_event_log(root, "code-demo").length(), 1)
}

///|
fn assert_mooncode_http_conversation_turns(
  payload : Json,
  prompts : Array[String],
  client_turn_ids : Array[String],
) -> Unit raise {
  let conversation = json_object_field_or_empty(
    payload, "mooncode_conversation",
  )
  assert_eq(
    json_string(conversation, "kind", default=""),
    "mooncode-conversation",
  )
  let turns = json_array_items(conversation, "turns")
  assert_eq(turns.length(), prompts.length())
  assert_eq(client_turn_ids.length(), prompts.length())
  for index in 0..<prompts.length() {
    let turn = turns[index]
    assert_eq(
      json_string(turn, "client_turn_id", default=""),
      client_turn_ids[index],
    )
    assert_true(json_string(turn, "turn_id", default="") != "")
    assert_true(json_string(turn, "command_id", default="") != "")
    let user = json_object_field_or_empty(turn, "user")
    assert_eq(json_string(user, "role", default=""), "user")
    assert_eq(json_string(user, "content", default=""), prompts[index])
  }
  let serialized = conversation.stringify()
  assert_false(serialized.contains("Local agent is not reachable yet"))
  assert_false(
    serialized.contains("Native MoonCode runtime recorded this prompt"),
  )
}

///|
fn assert_mooncode_http_current_turn(
  payload : Json,
  prompt : String,
  client_turn_id : String,
) -> Unit raise {
  assert_eq(json_string(payload, "client_turn_id", default=""), client_turn_id)
  assert_true(json_string(payload, "turn_id", default="") != "")
  let summary = json_object_field_or_empty(payload, "mooncode_summary")
  assert_true(json_int(summary, "event_count", default=0) >= 1)
  let turn = json_object_field_or_empty(payload, "mooncode_turn")
  assert_eq(json_string(turn, "client_turn_id", default=""), client_turn_id)
  let user = json_object_field_or_empty(turn, "user")
  assert_eq(json_string(user, "content", default=""), prompt)
}

///|
fn assert_mooncode_http_runtime_unavailable_turn(payload : Json) -> Unit raise {
  let turn = json_object_field_or_empty(payload, "mooncode_turn")
  assert_eq(json_string(turn, "status", default=""), "failed")
  let assistant = json_object_field_or_empty(turn, "assistant")
  assert_eq(json_string(assistant, "status", default=""), "failed")
  assert_true(
    json_string(assistant, "content", default="").contains("MoonClaw daemon"),
  )
}

///|
async test "mooncode code mode HTTP routes preserve three prompt conversation order" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-code-mode-http-order-e2e-" + @async.now().to_string(),
  )
  let ui_root = @pathx.join(root, "ui")
  let book_root = @pathx.join(root, "books/research-code")
  @fsx.make_directory(ui_root, recursive=true, exists_ok=true)
  @fsx.make_directory(
    @pathx.join(book_root, "wiki"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(@pathx.join(ui_root, "index.html"), "<main>code ui</main>")
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    "{\"name\":\"Research Code\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/index.md"),
    "# Research Code\n\nThree-turn chat fixture.\n",
  )

  let server = Server::new("127.0.0.1", 0, reuse_addr=true)
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_desk(ui_root, root),
      no_wait=true,
      allow_failure=true,
    )
    @async.sleep(20)
    let base = "http://127.0.0.1:\{server.port()}"
    let workspace_id = @desk.stable_id("book", "research-code")
    let prompts = [
      "Plan parser tests", "Add parser fixtures", "Explain the parser flow",
    ]
    let client_turn_ids = [
      "client-turn-api-1", "client-turn-api-2", "client-turn-api-3",
    ]

    let created = test_http_post_json(
      base + "/api/mooncode/sessions",
      {
        "workspace_id": workspace_id,
        "title": "MoonCode - Research Code",
        "message": prompts[0],
        "client_turn_id": client_turn_ids[0],
        "model": "deepseek-v4-flash",
        "web_search": false,
        "context_path": "wiki/index.md",
      },
      200,
    )
    let session_id = json_string(created, "id", default="")
    assert_true(session_id.has_prefix("mooncode-"))
    assert_mooncode_http_current_turn(created, prompts[0], client_turn_ids[0])
    assert_mooncode_http_conversation_turns(created, [prompts[0]], [
      client_turn_ids[0],
    ])

    let second = test_http_post_json(
      base + "/api/mooncode/sessions/\{session_id}/commands",
      {
        "action": "prompt",
        "message": prompts[1],
        "client_turn_id": client_turn_ids[1],
        "model": "deepseek-v4-flash",
        "web_search": false,
        "context_path": "wiki/index.md",
      },
      200,
    )
    assert_mooncode_http_current_turn(second, prompts[1], client_turn_ids[1])
    assert_mooncode_http_conversation_turns(second, [prompts[0], prompts[1]], [
      client_turn_ids[0],
      client_turn_ids[1],
    ])

    let third = test_http_post_json(
      base + "/api/mooncode/sessions/\{session_id}/commands",
      {
        "action": "prompt",
        "message": prompts[2],
        "client_turn_id": client_turn_ids[2],
        "model": "deepseek-v4-flash",
        "web_search": false,
        "context_path": "wiki/index.md",
      },
      200,
    )
    assert_mooncode_http_current_turn(third, prompts[2], client_turn_ids[2])
    assert_mooncode_http_conversation_turns(third, prompts, client_turn_ids)

    let listed = test_http_get_json(
      base + "/api/mooncode/sessions?workspace=\{workspace_id}",
      200,
    )
    match listed {
      Array(items) => {
        assert_eq(items.length(), 1)
        assert_eq(json_string(items[0], "id", default=""), session_id)
        assert_mooncode_http_conversation_turns(
          items[0],
          prompts,
          client_turn_ids,
        )
      }
      _ => fail("expected one replayed MoonCode session")
    }

    let commands = test_http_get_json(
      base + "/api/mooncode/sessions/\{session_id}/commands",
      200,
    )
    assert_eq(json_int(commands, "command_count", default=0), 3)
    let command_items = json_array_items(commands, "commands")
    assert_eq(command_items.length(), 3)
    for index in 0..<prompts.length() {
      assert_eq(
        json_string(command_items[index], "client_turn_id", default=""),
        client_turn_ids[index],
      )
      assert_eq(
        json_string(command_items[index], "message", default=""),
        prompts[index],
      )
    }

    let runtime_feed = test_http_get_json(
      base + "/api/mooncode/sessions/\{session_id}/runtime-commands",
      200,
    )
    assert_eq(json_int(runtime_feed, "runtime_command_count", default=0), 3)
    assert_eq(
      json_int(runtime_feed, "runtime_receipt_pending_count", default=0),
      3,
    )
  })
}

///|
async test "mooncode code mode HTTP routes create replay and checkpoint a session end to end" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-code-mode-http-e2e-" + @async.now().to_string(),
  )
  let ui_root = @pathx.join(root, "ui")
  let book_root = @pathx.join(root, "books/research-code")
  @fsx.make_directory(ui_root, recursive=true, exists_ok=true)
  @fsx.make_directory(
    @pathx.join(book_root, "wiki"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.make_directory(
    @pathx.join(book_root, "tools/parser"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(@pathx.join(ui_root, "index.html"), "<main>code ui</main>")
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    "{\"name\":\"Research Code\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "wiki/index.md"),
    "# Research Code\n\nExecutable code fixture.\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "tools/parser/main.mbt"),
    "fn main { println(\"parser\") }\n",
  )

  let server = Server::new("127.0.0.1", 0, reuse_addr=true)
  defer server.close()
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_desk(ui_root, root),
      no_wait=true,
      allow_failure=true,
    )
    @async.sleep(20)
    let base = "http://127.0.0.1:\{server.port()}"
    let workspace_id = @desk.stable_id("book", "research-code")

    let capabilities = test_http_get_json(
      base + "/api/mooncode/capabilities",
      200,
    )
    assert_eq(json_string(capabilities, "component", default=""), "mooncode")
    assert_true(
      capabilities
      .stringify()
      .contains("/api/mooncode/sessions/<session-id>/stream-state"),
    )
    assert_true(
      capabilities
      .stringify()
      .contains("/api/mooncode/sessions/<session-id>/runtime-replay"),
    )

    let initial_sessions = test_http_get_json(
      base + "/api/mooncode/sessions?workspace=\{workspace_id}",
      200,
    )
    match initial_sessions {
      Array(items) => assert_eq(items.length(), 0)
      _ => fail("expected empty MoonCode session array")
    }

    let created = test_http_post_json(
      base + "/api/mooncode/sessions",
      {
        "workspace_id": workspace_id,
        "title": "MoonCode - Research Code",
        "message": "Create parser tests",
        "model": "deepseek-v4-flash",
        "web_search": true,
        "context_path": "tools/parser/main.mbt",
      },
      200,
    )
    let session_id = json_string(created, "id", default="")
    assert_true(session_id.has_prefix("mooncode-"))
    assert_eq(json_string(created, "workspace_id", default=""), workspace_id)
    assert_eq(
      json_string(created, "last_message", default=""),
      "Create parser tests",
    )
    assert_eq(
      json_string(created, "mooncode_initial_context_path", default=""),
      "tools/parser/main.mbt",
    )
    assert_eq(
      json_string(created, "api_contract", default=""),
      "moonsuite.phase6.v1",
    )
    assert_true(json_bool(created, "accepted", default=false))
    assert_eq(json_string(created, "status", default=""), "failed")
    assert_mooncode_http_runtime_unavailable_turn(created)
    assert_eq(
      json_string(created, "next_action", default=""),
      "poll_mooncode_stream",
    )
    assert_true(json_object_field(created, "transcript") is None)
    assert_true(
      @fs.exists(
        @pathx.join(
          root,
          ".moonsuite/products/mooncode/sessions/\{session_id}/record.json",
        ),
      ),
    )
    assert_true(
      @fs.exists(
        @pathx.join(
          root,
          ".moonsuite/products/mooncode/sessions/\{session_id}/commands.jsonl",
        ),
      ),
    )
    assert_true(
      @fs.exists(
        @pathx.join(
          root,
          ".moonsuite/products/mooncode/sessions/\{session_id}/runtime-commands.jsonl",
        ),
      ),
    )

    let listed = test_http_get_json(
      base + "/api/mooncode/sessions?workspace=\{workspace_id}",
      200,
    )
    match listed {
      Array(items) => {
        assert_eq(items.length(), 1)
        assert_eq(json_string(items[0], "id", default=""), session_id)
      }
      _ => fail("expected one MoonCode session")
    }

    let commands = test_http_get_json(
      base + "/api/mooncode/sessions/\{session_id}/commands",
      200,
    )
    assert_eq(
      json_string(commands, "kind", default=""),
      "mooncode-command-queue",
    )
    assert_eq(json_int(commands, "command_count", default=0), 1)
    let command_items = json_array_items(commands, "commands")
    assert_eq(command_items.length(), 1)
    let command_id = json_string(command_items[0], "command_id", default="")
    assert_true(command_id.has_prefix("mooncode-command-"))
    assert_eq(json_string(command_items[0], "action", default=""), "prompt")
    assert_eq(
      json_string(command_items[0], "message", default=""),
      "Create parser tests",
    )
    assert_eq(
      json_string(command_items[0], "context_path", default=""),
      "tools/parser/main.mbt",
    )
    assert_true(json_bool(command_items[0], "web_search", default=false))

    let runtime_feed = test_http_get_json(
      base + "/api/mooncode/sessions/\{session_id}/runtime-commands",
      200,
    )
    assert_eq(
      json_string(runtime_feed, "kind", default=""),
      "mooncode-runtime-command-feed",
    )
    assert_eq(json_int(runtime_feed, "runtime_command_count", default=0), 1)
    assert_eq(
      json_int(runtime_feed, "runtime_receipt_pending_count", default=0),
      1,
    )
    assert_eq(
      json_string(runtime_feed, "runtime_mode", default=""),
      "runtime-replay-receipts",
    )

    let claim_state = test_http_get_json(
      base + "/api/mooncode/sessions/\{session_id}/runtime-claim",
      200,
    )
    assert_eq(
      json_string(claim_state, "kind", default=""),
      "mooncode-runtime-claim-state",
    )
    assert_eq(json_int(claim_state, "claimable_command_count", default=0), 1)

    let claim_result = test_http_post_json(
      base + "/api/mooncode/sessions/\{session_id}/runtime-claim",
      {
        "consumer_id": "code-mode-http-e2e",
        "max_count": 1,
        "now": "2026-06-30T02:00:00Z",
        "lease_expires_at": "2026-06-30T02:05:00Z",
      },
      200,
    )
    assert_eq(
      json_string(claim_result, "kind", default=""),
      "mooncode-runtime-claim",
    )
    assert_eq(json_int(claim_result, "claimed_count", default=0), 1)

    let replay_after_claim = test_http_get_json(
      base + "/api/mooncode/sessions/\{session_id}/runtime-replay",
      200,
    )
    assert_eq(
      json_string(replay_after_claim, "kind", default=""),
      "mooncode-runtime-replay",
    )
    assert_eq(
      json_int(replay_after_claim, "claimed_command_count", default=0),
      1,
    )

    let ack = test_http_post_json(
      base + "/api/mooncode/sessions/\{session_id}/runtime-replay",
      {
        "consumer_id": "code-mode-http-e2e",
        "command_id": command_id,
        "status": "runtime-complete",
        "detail": "parser tests generated",
        "events": [
          { "event": "runtime_finished", "answer": "parser tests generated" },
        ],
      },
      200,
    )
    assert_eq(
      json_string(ack, "kind", default=""),
      "mooncode-runtime-replay-ack",
    )
    assert_eq(json_int(ack, "accepted_receipt_count", default=0), 1)
    assert_true(json_int(ack, "accepted_event_count", default=0) >= 1)
    assert_true(ack.stringify().contains("parser tests generated"))

    let events = test_http_get_json(
      base + "/api/mooncode/sessions/\{session_id}/events",
      200,
    )
    match events {
      Array(items) => assert_true(items.length() >= 2)
      _ => fail("expected MoonCode event array")
    }

    let stream_state = test_http_get_json(
      base +
      "/api/mooncode/sessions/\{session_id}/stream-state?consumer=code-mode-http-e2e&since=0",
      200,
    )
    assert_eq(
      json_string(stream_state, "kind", default=""),
      "mooncode-stream-state",
    )
    assert_eq(
      json_string(stream_state, "consumer_id", default=""),
      "code-mode-http-e2e",
    )
    assert_true(json_int(stream_state, "latest_sequence", default=0) >= 2)
    assert_true(json_int(stream_state, "emitted_count", default=0) >= 2)

    let checkpointed = test_http_post_json(
      base +
      "/api/mooncode/sessions/\{session_id}/stream-state?consumer=ignored-query-consumer&since=0",
      {
        "consumer_id": "code-mode-http-e2e",
        "last_seen_sequence": json_int(
          stream_state,
          "latest_sequence",
          default=0,
        ),
      },
      200,
    )
    assert_true(json_bool(checkpointed, "checkpoint_ready", default=false))
    let checkpoint = json_object_field_or_empty(checkpointed, "checkpoint")
    assert_eq(
      json_int(checkpoint, "last_seen_sequence", default=0),
      json_int(stream_state, "latest_sequence", default=0),
    )

    let (_, stream_body) = test_http_get(
      base +
      "/api/mooncode/sessions/\{session_id}/stream?format=jsonl&since=0&live=false",
      200,
    )
    assert_true(stream_body.contains("command.prompt"))
    assert_true(stream_body.contains("parser tests generated"))

    ignore(
      test_http_post_json(
        base + "/api/mooncode/sessions/\{session_id}/commands",
        { "action": "deploy_global", "message": "should be rejected" },
        400,
      ),
    )
    let commands_after_reject = test_http_get_json(
      base + "/api/mooncode/sessions/\{session_id}/commands",
      200,
    )
    assert_eq(json_int(commands_after_reject, "command_count", default=0), 1)

    ignore(
      test_http_get_json(
        base + "/api/mooncode/sessions/not-a-session/runtime-replay",
        404,
      ),
    )
  })
}
