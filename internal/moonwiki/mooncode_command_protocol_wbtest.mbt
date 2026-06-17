///|
test "mooncode command preflight blocks accept until changed code is tested" {
  let diff_event = @mooncode.event_record(
    id="diff-1",
    lane="diff",
    kind="write",
    title="File changed",
    status="done",
    created_at="2026-06-14T00:00:00Z",
    detail="changed",
    path="tools/demo/main.mbt",
    diff="+fn main { println(1) }",
  )
  let session : Json = { "id": "agent-demo", "mooncode_events": [diff_event] }
  let session = @mooncode.append_projected_command_event(
    session,
    action="approve_tool",
    status="queued",
    detail="Approve file write",
    created_at="2026-06-14T00:00:30Z",
    path="tools/demo/main.mbt",
  )
  let blocked = mooncode_command_preflight(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "accept",
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(
    json_string(blocked, "reason", default="").contains("run tests/builds"),
  )
  let test_event = @mooncode.event_record(
    id="test-1",
    lane="test",
    kind="test_result",
    title="Tests passed",
    status="done",
    created_at="2026-06-14T00:01:00Z",
    detail="Total tests: 1, passed: 1",
    command="moon test",
    exit_code=0,
  )
  let tested = agent_session_with_field(
    session,
    "mooncode_events",
    Json::array([diff_event, test_event]),
  )
  let allowed = mooncode_command_preflight(
    tested,
    { "context_path": "tools/demo/main.mbt" },
    "accept",
  )
  assert_true(json_bool(allowed, "allowed", default=false))
}

///|
test "mooncode command preflight blocks package while tool approvals are pending" {
  let preview = @mooncode.tool_authorization_preview_projected_event(
    {
      "tool_call_id": "call-build",
      "tool_name": "shell",
      "arguments": "{\"cmd\":[\"npm\",\"run\",\"build\"]}",
    },
    "2026-06-14T00:00:00Z",
  )
  let session : Json = { "id": "agent-demo", "mooncode_events": [preview] }
  let blocked = mooncode_command_preflight(
    session,
    { "context_path": "apps/demo" },
    "package",
  )
  assert_true(json_bool(blocked, "blocked", default=false))
  assert_true(
    json_string(blocked, "reason", default="").contains(
      "pending tool approvals",
    ),
  )
}

///|
test "mooncode command preflight requires selected accepted patch target for apply" {
  let diff_event = @mooncode.event_record(
    id="diff-1",
    lane="diff",
    kind="write",
    title="File changed",
    status="done",
    created_at="2026-06-14T00:00:00Z",
    detail="changed",
    path="tools/demo/main.mbt",
    diff="+fn main { println(1) }",
  )
  let accept_event = @mooncode.event_record(
    id="review-1",
    lane="review",
    kind="command.accept",
    title="Accept patch",
    status="done",
    created_at="2026-06-14T00:01:00Z",
    detail="accepted",
    path="tools/demo/main.mbt",
    command="accept",
  )
  let session : Json = { "id": "agent-demo", "mooncode_events": [diff_event] }
  let missing = mooncode_command_preflight(
    session,
    Json::object({}),
    "apply_patch",
  )
  assert_true(json_bool(missing, "blocked", default=false))
  let wrong = mooncode_command_preflight(
    session,
    { "context_path": "tools/other/main.mbt" },
    "apply_patch",
  )
  assert_true(json_bool(wrong, "blocked", default=false))
  let unreviewed = mooncode_command_preflight(
    session,
    { "context_path": "tools/demo/main.mbt" },
    "apply_patch",
  )
  assert_true(json_bool(unreviewed, "blocked", default=false))
  assert_true(
    json_string(unreviewed, "reason", default="").contains(
      "accept patch target",
    ),
  )
  let accepted_session : Json = {
    "id": "agent-demo",
    "mooncode_events": [diff_event, accept_event],
  }
  let allowed = mooncode_command_preflight(
    accepted_session,
    { "context_path": "tools/demo/main.mbt" },
    "apply_patch",
  )
  assert_true(json_bool(allowed, "allowed", default=false))
}

///|
test "mooncode preflight endpoint query builds command payload" {
  let payload = mooncode_preflight_payload_from_request(
    "/api/mooncode/sessions/s1/preflight?action=apply_patch&context_path=tools%2Fdemo%2Fmain.mbt",
  )
  assert_eq(json_string(payload, "action", default=""), "apply_patch")
  assert_eq(
    json_string(payload, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  let path_alias = mooncode_preflight_payload_from_request(
    "/api/mooncode/sessions/s1/preflight?action=accept&path=wiki%2Findex.md",
  )
  assert_eq(json_string(path_alias, "action", default=""), "accept")
  assert_eq(
    json_string(path_alias, "context_path", default=""),
    "wiki/index.md",
  )
}

///|
test "mooncode command preflight blocked attempts become runtime events" {
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": "mooncode.v1",
    "action": "package",
    "blocked": true,
    "reason": "resolve pending tool approvals before package",
  }
  let event = @mooncode.command_preflight_blocked_projected_event(
    preflight,
    action="package",
    context_path="tools/demo/main.mbt",
    created_at="2026-06-14T00:02:00Z",
  )
  assert_eq(json_string(event, "kind", default=""), "preflight.blocked")
  assert_eq(json_string(event, "lane", default=""), "artifact")
  assert_eq(json_string(event, "status", default=""), "blocked")
  assert_eq(json_string(event, "path", default=""), "tools/demo/main.mbt")
  assert_true(
    json_string(event, "detail", default="").contains("pending tool approvals"),
  )
  assert_eq(
    json_string(
      json_object_field_or_empty(event, "command_packet"),
      "kind",
      default="",
    ),
    "mooncode-command-preflight",
  )
}

///|
test "mooncode forced preflight command creates override audit event and packet" {
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "force_preflight": true,
  }
  let preflight : Json = {
    "kind": "mooncode-command-preflight",
    "protocol": "mooncode.v1",
    "action": "commit",
    "blocked": true,
    "reason": "accept reviewed file changes before commit",
  }
  let event = @mooncode.command_preflight_override_projected_event(
    preflight,
    action="commit",
    context_path=@mooncode.command_context_path(payload),
    created_at="2026-06-15T00:03:00Z",
  )
  assert_eq(json_string(event, "kind", default=""), "preflight.override")
  assert_eq(json_string(event, "status", default=""), "override")
  assert_eq(json_string(event, "path", default=""), "tools/demo/main.mbt")
  assert_true(
    json_string(event, "detail", default="").contains(
      "accept reviewed file changes",
    ),
  )
  let packet = @mooncode.projected_command_packet(
    { "id": "agent-demo", "workspace_root": "/tmp/book" },
    payload,
    "commit",
    "Commit anyway",
    "2026-06-15T00:03:00Z",
    "tools/demo/main.mbt",
  )
  assert_true(json_bool(packet, "force_preflight", default=false))
}

///|
test "mooncode review commands preserve target path" {
  let payload : Json = { "context_path": "tools/demo/main.mbt" }
  let target_path = @mooncode.command_context_path(payload)
  let session = @mooncode.append_projected_command_event(
    Json::object({}),
    action="accept",
    status="queued",
    detail=@mooncode.command_message("accept", payload),
    created_at="1",
    path=target_path,
  )
  let events = project_mooncode_events(session, [], [])
  assert_eq(events.length(), 1)
  assert_eq(json_string(events[0], "lane", default=""), "review")
  assert_eq(json_string(events[0], "path", default=""), "tools/demo/main.mbt")
  assert_true(
    json_string(events[0], "detail", default="").contains("tools/demo/main.mbt"),
  )
}

///|
test "mooncode patch set groups diff candidates by review state" {
  let command_packet : Json = {
    "protocol": "mooncode.v1",
    "command_id": "cmd-apply",
    "action": "apply_patch",
  }
  let events = [
    @mooncode.event_record(
      id="diff",
      lane="diff",
      kind="file.write",
      title="File changed",
      status="done",
      created_at="1",
      detail="updated tool",
      path="tools/demo/main.mbt",
      diff="@@ -1,1 +1,1 @@\n-fn main { println(\"old\") }\n+fn main { println(\"ok\") }",
    ),
    @mooncode.event_record(
      id="review",
      lane="review",
      kind="command.apply_patch",
      title="Apply patch",
      status="queued",
      created_at="2",
      detail="applied",
      path="tools/demo/main.mbt",
      command="apply_patch",
      command_packet~,
    ),
  ]
  let patches = @mooncode.patch_set_entries(events)
  assert_eq(patches.length(), 1)
  assert_eq(json_string(patches[0], "path", default=""), "tools/demo/main.mbt")
  assert_eq(json_string(patches[0], "review_state", default=""), "applied")
  assert_true(json_bool(patches[0], "diff_present", default=false))
  assert_eq(json_int(patches[0], "hunk_count", default=0), 1)
  let hunks = json_array_items(patches[0], "hunks")
  assert_eq(json_string(hunks[0], "header", default=""), "@@ -1,1 +1,1 @@")
  assert_eq(
    json_string(hunks[0], "target", default=""),
    "tools/demo/main.mbt#hunk-1",
  )
  assert_eq(json_string(hunks[0], "review_state", default=""), "applied")
  assert_eq(json_int(hunks[0], "added_lines", default=0), 1)
  assert_eq(json_int(hunks[0], "removed_lines", default=0), 1)
  assert_eq(json_int(hunks[0], "applied_review_count", default=0), 1)
  assert_true(
    @mooncode.command_preflight_has_patch_target(
      @mooncode.patch_set_entries(events),
      "tools/demo/main.mbt#hunk-1",
    ),
  )
  assert_eq(json_int(patches[0], "applied_review_count", default=0), 1)
  assert_eq(@mooncode.count_patch_review_state(patches, "pending"), 0)
  assert_eq(@mooncode.count_patch_review_state(patches, "applied"), 1)
}

///|
test "mooncode command prompts are book coding specific" {
  assert_true(@mooncode.command_is_supported("reject"))
  assert_true(@mooncode.command_is_supported("approve_tool"))
  assert_true(@mooncode.command_is_supported("reject_tool"))
  assert_true(@mooncode.command_is_supported("apply_patch"))
  assert_true(@mooncode.command_is_supported("revert_patch"))
  assert_true(@mooncode.command_is_supported("cancel"))
  assert_true(@mooncode.command_is_supported("run_eval"))
  assert_true(@mooncode.command_is_supported("commit"))
  assert_true(
    @mooncode.command_message("run_tests", Json::object({})).contains("tests"),
  )
  assert_true(
    @mooncode.command_message("run_eval", Json::object({})).contains(
      "eval harnesses",
    ),
  )
  assert_true(
    @mooncode.command_message("package", Json::object({})).contains("MoonBook"),
  )
  assert_true(
    @mooncode.command_message("commit", Json::object({})).contains(
      "commit_created",
    ),
  )
  assert_true(
    @mooncode.command_message("accept", Json::object({})).contains(
      "operator accepts",
    ),
  )
  assert_true(
    @mooncode.command_message("reject", Json::object({})).contains(
      "operator rejects",
    ),
  )
  assert_true(
    @mooncode.command_message("approve_tool", Json::object({})).contains(
      "Approve",
    ),
  )
  assert_true(
    @mooncode.command_message("reject_tool", Json::object({})).contains(
      "Reject",
    ),
  )
  assert_true(
    @mooncode.command_message("apply_patch", Json::object({})).contains("Apply"),
  )
  assert_true(
    @mooncode.command_message("revert_patch", Json::object({})).contains(
      "Revert",
    ),
  )
  assert_true(
    @mooncode.command_message("cancel", Json::object({})).contains("Cancel"),
  )
}

///|
test "mooncode tool approvals identify policy and review gated tools" {
  let approve_packet : Json = {
    "protocol": "mooncode.v1",
    "command_id": "cmd-approve",
    "action": "approve_tool",
  }
  let events = [
    @mooncode.event_record(
      id="shell",
      lane="tool",
      kind="execute_command",
      title="Tool finished: execute_command",
      status="done",
      created_at="1",
      detail="ran command",
      command="npm test",
    ),
    @mooncode.event_record(
      id="write",
      lane="diff",
      kind="meta_write_to_file",
      title="File changed",
      status="done",
      created_at="2",
      detail="wrote file",
      path="tools/demo/main.mbt",
      diff="+fn main { println(\"ok\") }",
    ),
    @mooncode.event_record(
      id="approve",
      lane="review",
      kind="command.approve_tool",
      title="Approve tool",
      status="queued",
      created_at="3",
      detail="approved",
      path="npm test",
      command="approve_tool",
      command_packet=approve_packet,
    ),
  ]
  let approvals = @mooncode.tool_approval_entries(events)
  assert_eq(approvals.length(), 2)
  assert_eq(json_string(approvals[0], "approval", default=""), "policy")
  assert_eq(json_string(approvals[0], "approval_state", default=""), "approved")
  assert_eq(json_string(approvals[1], "approval", default=""), "review")
  assert_eq(json_string(approvals[1], "approval_state", default=""), "pending")
  assert_eq(@mooncode.count_tool_approval_state(approvals, "approved"), 1)
  assert_eq(@mooncode.count_tool_approval_state(approvals, "pending"), 1)
}

///|
test "mooncode command packet preserves runtime boundary" {
  let session : Json = {
    "id": "agent-demo",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "workspace_root": "/tmp/demo-book",
    "moonclaw_task_id": "task-demo",
  }
  let payload : Json = {
    "context_path": "tools/demo/main.mbt",
    "web_search": false,
  }
  let message = @mooncode.command_message("run_tests", payload)
  let packet = @mooncode.projected_command_packet(
    session, payload, "run_tests", message, "2026-06-14T00:00:00Z", "tools/demo/main.mbt",
  )
  assert_eq(json_string(packet, "protocol", default=""), "mooncode.v1")
  assert_eq(json_string(packet, "dispatch", default=""), "command")
  assert_eq(json_string(packet, "approval", default=""), "auto")
  assert_eq(
    json_string(packet, "context_path", default=""),
    "tools/demo/main.mbt",
  )
  assert_true(
    json_string_array_items(packet, "tool_hints").contains("moon_check"),
  )
  let output_contract = json_object_field_or_empty(packet, "output_contract")
  assert_eq(json_string(output_contract, "owner", default=""), "moonbook")
  assert_true(
    json_string_array_items(output_contract, "roots").contains("tools/"),
  )
  assert_true(
    @mooncode.command_runtime_message(message, packet).contains(
      "MoonCode command packet",
    ),
  )
}
