///|
fn code_mode_test_dispatch(_msg : Msg) -> @rabbita.Cmd {
  @rabbita.none
}

///|
fn code_mode_test_summary() -> MoonCodeSummary {
  { event_count: 0, verified_test_count: 0, pending_diff_count: 0 }
}

///|
fn code_mode_test_session(
  id : String,
  workspace_id? : String = "book-demo",
  status? : String = "idle",
  queued_count? : Int = 0,
) -> MoonCodeSession {
  {
    id,
    workspace_id,
    workspace_name: if workspace_id == "" {
      "General"
    } else {
      "Demo Book"
    },
    cwd: if workspace_id == "" {
      ""
    } else {
      "/tmp/demo-book"
    },
    mooncode_runtime_session_id: Some("runtime-" + id),
    title: "MoonCode - " + id,
    model: "deepseek-v4-flash",
    status,
    queued_count,
    transcript: [],
    mooncode_events: [],
    mooncode_conversation: None,
    mooncode_summary: code_mode_test_summary(),
  }
}

///|
fn code_mode_test_event(
  id : String,
  command_id? : String = "",
  title? : String = "runtime event",
  lane? : String = "runtime",
  kind? : String = "mooncode.runtime-event",
  status? : String = "ok",
  detail? : String = "",
  path? : String = "",
  command? : String = "",
  created_at? : String = "2026-06-30T00:00:00Z",
  exit_code? : Int = 0,
  tool? : String = "",
  tool_name? : String = "",
  command_packet? : Json? = None,
  tool_result? : Json? = None,
) -> MoonCodeEvent {
  {
    id,
    command_id: if command_id == "" {
      None
    } else {
      Some(command_id)
    },
    lane,
    kind,
    title,
    status,
    created_at,
    detail,
    path,
    command,
    exit_code,
    tool: if tool == "" {
      None
    } else {
      Some(tool)
    },
    tool_name: if tool_name == "" {
      None
    } else {
      Some(tool_name)
    },
    command_packet,
    tool_result,
  }
}

///|
fn code_mode_test_conversation(
  session_id : String,
  turns : Array[MoonCodeConversationTurn],
) -> MoonCodeConversation {
  {
    kind: "mooncode-conversation",
    protocol: "mooncode.v1",
    session_id,
    workspace_id: "book-demo",
    workspace_name: "Demo Book",
    turn_count: turns.length(),
    source_event_count: turns.length() * 2,
    turns,
  }
}

///|
fn code_mode_test_turn(
  id : String,
  user : String,
  client_turn_id? : String = "",
  assistant? : String = "",
  progress? : Array[Json] = [],
  status? : String = "done",
) -> MoonCodeConversationTurn {
  {
    kind: "mooncode-conversation-turn",
    turn_id: id,
    client_turn_id,
    command_id: id,
    status,
    started_at: "2026-06-30T00:00:00Z",
    updated_at: "2026-06-30T00:00:01Z",
    user: {
      "role": "user",
      "content": user,
      "status": "done",
    },
    progress,
    assistant: if assistant == "" {
      Json::object({})
    } else {
      {
        "role": "assistant",
        "content": assistant,
        "status": status,
      }
    },
    items: [],
  }
}

///|
test "code mode transcript shows clean user and assistant conversation" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Fix the parser bug",
        command="prompt",
      ),
      code_mode_test_event(
        "runtime-step",
        title="Runtime step",
        kind="runtime_step",
        status="running",
        detail="{\"internal\":\"protocol\"}",
      ),
      code_mode_test_event(
        "tool-result",
        title="moon check",
        lane="tool",
        kind="moon_check",
        status="done",
        detail="lots of tool output",
      ),
      code_mode_test_event(
        "finish",
        title="Runtime finished",
        lane="review",
        kind="finish",
        status="done",
        detail="The parser bug is fixed.",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Fix the parser bug")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "The parser bug is fixed.")
}

///|
test "code mode activity rows show runtime work but not chat bubbles" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Fix the parser bug",
        command="prompt",
      ),
      code_mode_test_event(
        "runtime-command-queued",
        title="MoonCode command queued for native runtime turn",
        lane="runtime",
        kind="runtime.command_queued",
        status="queued",
        detail="Queued `prompt` for MoonClaw native runtime-turn execution without spawning a generic task.",
      ),
      code_mode_test_event(
        "thinking",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Inspect the parser before editing.",
      ),
      code_mode_test_event(
        "assistant",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="I will check it.",
      ),
      code_mode_test_event(
        "tool",
        title="Tool started: moon_check",
        lane="test",
        kind="tool_call",
        status="running",
        detail="{\"tool\":\"moon_check\"}",
      ),
      code_mode_test_event(
        "finish-tool-start",
        title="Tool started: finish",
        lane="review",
        kind="tool_call",
        status="running",
        detail="{\"answer\":\"Done.\"}",
        tool="finish",
        tool_name="finish",
      ),
      code_mode_test_event(
        "test",
        title="moon check",
        lane="test",
        kind="tool_result",
        status="done",
        detail="Finished. moon: no work to do",
      ),
      code_mode_test_event(
        "finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({ "tool": "finish", "ok": true, "output": "Done." }),
      ),
      code_mode_test_event(
        "runtime-done",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
      ),
      code_mode_test_event(
        "idle-loop-a",
        title="Native runtime loop: idle",
        lane="runtime",
        kind="runtime_loop",
        status="done",
        detail="runtime-loop",
      ),
      code_mode_test_event(
        "idle-loop-b",
        title="Native runtime loop: idle",
        lane="runtime",
        kind="runtime_loop",
        status="done",
        detail="runtime-loop",
      ),
      code_mode_test_event(
        "manifest",
        title="MoonCode action plan",
        lane="runtime",
        kind="action_plan.manifest",
        status="queued",
        detail="MoonCode action plan recorded at wiki/reviews/action-plan.json",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let rows : Array[MoonCodeActivityRow] = []
  for item in items {
    match item.activity {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  assert_eq(rows.length(), 3)
  assert_eq(rows[0].label, "Progress")
  assert_eq(rows[0].detail, "Inspect the parser before editing.")
  assert_eq(rows[0].folded, true)
  assert_eq(rows[1].label, "Checking project")
  assert_eq(rows[1].title, "moon check")
  assert_eq(rows[1].detail, "")
  assert_eq(rows[2].label, "Checked")
  assert_eq(rows[2].title, "moon check")
}

///|
test "code mode planner no-tool-call message is sanitized" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Find the module name",
        command="prompt",
      ),
      code_mode_test_event(
        "planner-failed",
        title="MoonCode planner failed",
        lane="runtime",
        kind="runtime.planner_failed",
        status="failed",
        detail="model planner follow-up returned no usable MoonCode tool calls",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  match items[1].activity {
    Some(row) => {
      assert_eq(row.status, "running")
      assert_eq(row.detail, "Trying another approach.")
      assert_true(!row.detail.contains("no usable"))
    }
    None => fail("expected sanitized planner activity")
  }
}

///|
test "code mode activity rows use package-style friendly tool labels" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Find package behavior",
        command="prompt",
      ),
      code_mode_test_event(
        "turn-start",
        title="MoonCode native runtime turn started",
        lane="runtime",
        kind="runtime.turn_started",
        status="running",
        detail="control",
      ),
      code_mode_test_event(
        "web",
        title="Tool started: WebSearch",
        lane="tool",
        kind="tool_call",
        status="running",
        detail="{\"tool\":\"WebSearch\",\"query\":\"moonbit package docs\"}",
      ),
      code_mode_test_event(
        "todo",
        title="Tool started: TodoWrite",
        lane="tool",
        kind="tool_call",
        status="running",
        detail="{\"tool\":\"TodoWrite\",\"description\":\"Track implementation steps\"}",
      ),
      code_mode_test_event(
        "read",
        title="Tool started: FileRead",
        lane="tool",
        kind="tool_call",
        status="running",
        detail="{\"tool\":\"FileRead\",\"file_path\":\"src/app.mbt\"}",
      ),
      code_mode_test_event(
        "bash",
        title="Tool started: Bash",
        lane="tool",
        kind="tool_call",
        status="running",
        command="moon test ui/rabbita-desk",
        detail="{\"tool\":\"Bash\",\"command\":\"moon test ui/rabbita-desk\"}",
      ),
      code_mode_test_event(
        "turn-done",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="control",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let rows : Array[MoonCodeActivityRow] = []
  for item in items {
    match item.activity {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  assert_eq(rows.length(), 4)
  assert_eq(rows[0].label, "Searching web")
  assert_eq(rows[0].title, "moonbit package docs")
  assert_eq(rows[0].detail, "")
  assert_eq(rows[1].label, "Updating plan")
  assert_eq(rows[1].title, "Track implementation steps")
  assert_eq(rows[2].label, "Reading file")
  assert_eq(rows[2].title, "src/app.mbt")
  assert_eq(rows[3].label, "Running tests")
  assert_eq(rows[3].title, "moon test ui/rabbita-desk")
}

///|
test "code mode activity rows parse decoded tool arguments" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Mirror package stream",
        command="prompt",
      ),
      code_mode_test_event(
        "shell",
        title="Tool started: shell",
        lane="tool",
        kind="shell",
        status="running",
        detail="{\"tool_name\":\"shell\",\"arguments\":\"{\\\"cmd\\\":[\\\"npm\\\",\\\"run\\\",\\\"build\\\"],\\\"description\\\":\\\"Build frontend bundle\\\"}\"}",
      ),
      code_mode_test_event(
        "read",
        title="Tool started: read",
        lane="tool",
        kind="read",
        status="running",
        detail="{\"tool_name\":\"read\",\"arguments\":\"{\\\"file_path\\\":\\\"src/main.mbt\\\"}\"}",
      ),
      code_mode_test_event(
        "edit",
        title="Tool started: edit",
        lane="tool",
        kind="edit",
        status="running",
        detail="{\"tool_name\":\"edit\",\"arguments\":{\"file_path\":\"src/main.mbt\"}}",
      ),
      code_mode_test_event(
        "todo",
        title="Tool started: TodoWrite",
        lane="tool",
        kind="tool_call",
        status="running",
        detail="{\"tool\":\"TodoWrite\",\"todos\":[{\"content\":\"Patch stream projection\",\"status\":\"in_progress\",\"activeForm\":\"Patching stream projection\"}]}",
      ),
      code_mode_test_event(
        "web",
        title="Tool started: WebSearch",
        lane="tool",
        kind="tool_call",
        status="running",
        detail="{\"tool_call\":{\"function\":{\"name\":\"WebSearch\",\"arguments\":\"{\\\"query\\\":\\\"moonbit package docs\\\"}\"}}}",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let rows : Array[MoonCodeActivityRow] = []
  for item in items {
    match item.activity {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  assert_eq(rows.length(), 5)
  assert_eq(rows[0].label, "Running tests")
  assert_eq(rows[0].title, "Build frontend bundle")
  assert_eq(rows[1].label, "Reading file")
  assert_eq(rows[1].title, "src/main.mbt")
  assert_eq(rows[2].label, "Editing file")
  assert_eq(rows[2].title, "src/main.mbt")
  assert_eq(rows[3].label, "Updating plan")
  assert_eq(rows[3].title, "Patching stream projection")
  assert_eq(rows[4].label, "Searching web")
  assert_eq(rows[4].title, "moonbit package docs")
}

///|
test "code mode runtime planner updates render as friendly thinking" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Explain your work",
        command="prompt",
      ),
      code_mode_test_event(
        "choosing",
        title="Runtime update",
        lane="runtime",
        kind="runtime_update",
        status="running",
        detail="asking model for next tool batch",
      ),
      code_mode_test_event(
        "selected",
        title="Runtime update",
        lane="runtime",
        kind="runtime_update",
        status="running",
        detail="model-tool-calls selected 1 tool call",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let rows : Array[MoonCodeActivityRow] = []
  for item in items {
    match item.activity {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].label, "Working")
  assert_eq(rows[0].title, "Reviewing the request")
  assert_eq(rows[0].detail, "Reviewed the request.")
  assert_eq(rows[1].label, "Working")
  assert_eq(rows[1].title, "Choosing what to do next")
  assert_eq(rows[1].detail, "Chose what to do next.")
}

///|
test "code mode resolved thinking compacts into one user-facing progress row" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Explain the bug",
        command="prompt",
      ),
      code_mode_test_event(
        "planning",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="runtime.planner_started",
        status="running",
        detail="planner entered",
      ),
      code_mode_test_event(
        "selected",
        title="MoonCode planner selected action",
        lane="runtime",
        kind="runtime.planner_selected",
        status="running",
        detail="selected tool call",
      ),
      code_mode_test_event(
        "thinking",
        title="MoonCode planner reasoning",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Drafted the answer.",
      ),
      code_mode_test_event(
        "finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "The bug is in the projection layer.",
        }),
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 3)
  match items[1].activity {
    Some(row) => {
      assert_eq(row.label, "Progress")
      assert_eq(row.title, "Prepared the response")
      assert_eq(row.status, "done")
      assert_eq(row.folded, true)
      assert_eq(
        row.detail,
        "Reviewed the request.\nChose what to do next.\nDrafted the answer.",
      )
      assert_true(!row.detail.contains("planner"))
      assert_true(!row.detail.contains("tool call"))
    }
    None => fail("expected compacted progress activity")
  }
}

///|
test "code mode hides recovered internal planner failure before answer" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Find the module name",
        command="prompt",
      ),
      code_mode_test_event(
        "planner-started",
        title="MoonCode planner started",
        lane="runtime",
        kind="runtime.planner_started",
        status="running",
        detail="asking model",
      ),
      code_mode_test_event(
        "planner-failed",
        title="MoonCode planner failed",
        lane="runtime",
        kind="runtime.planner_failed",
        status="failed",
        detail="model planner returned no usable MoonCode tool calls",
      ),
      code_mode_test_event(
        "read",
        title="Tool started",
        lane="tool",
        kind="tool_call",
        status="running",
        detail="{\"path\":\"moon.mod\"}",
        tool="read",
        path="moon.mod",
      ),
      code_mode_test_event(
        "read-done",
        title="Tool completed",
        lane="tool",
        kind="tool_result",
        status="done",
        detail="moon.mod contents",
        tool="read",
        path="moon.mod",
      ),
      code_mode_test_event(
        "finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "vectie/moondesk",
        }),
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let mut has_assistant = false
  for item in items {
    match item.activity {
      Some(row) => assert_true(row.status != "failed")
      None => ()
    }
    match item.message {
      Some(row) if row.role == "assistant" => {
        has_assistant = true
        assert_eq(row.content, "vectie/moondesk")
      }
      _ => ()
    }
  }
  assert_true(has_assistant)
}

///|
test "code mode activity rows hide raw runtime controls" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Keep transcript clean",
        command="prompt",
      ),
      code_mode_test_event(
        "queued",
        title="MoonCode command queued for native runtime turn",
        lane="runtime",
        kind="runtime.command_queued",
        status="queued",
        detail="Queued `prompt` for MoonClaw native runtime-turn execution.",
      ),
      code_mode_test_event(
        "started",
        title="MoonCode native runtime turn started",
        lane="runtime",
        kind="runtime.turn_started",
        status="running",
        detail="Started.",
      ),
      code_mode_test_event(
        "runtime-status",
        title="Runtime status",
        lane="runtime",
        kind="status",
        status="running",
        detail="MoonClaw native runtime service started in the daemon task group.",
      ),
      code_mode_test_event(
        "usage",
        title="Token usage",
        lane="runtime",
        kind="usage",
        status="done",
        detail="{\"tokens\":123}",
      ),
      code_mode_test_event(
        "loop",
        title="Native runtime loop: idle",
        lane="runtime",
        kind="runtime_loop",
        status="done",
        detail="runtime-loop",
      ),
      code_mode_test_event(
        "done",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="Finished.",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let rows : Array[MoonCodeActivityRow] = []
  for item in items {
    match item.activity {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  assert_eq(rows.length(), 0)
}

///|
test "code mode activity rows hide raw runtime step updates" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Keep protocol out of the chat",
        command="prompt",
      ),
      code_mode_test_event(
        "runtime-step",
        title="Runtime step",
        lane="runtime",
        kind="runtime_step",
        status="running",
        detail="{\"internal\":\"protocol\"}",
      ),
      code_mode_test_event(
        "runtime-update",
        title="Runtime update",
        lane="runtime",
        kind="runtime_update",
        status="running",
        detail="{\"queue\":\"poll\"}",
      ),
      code_mode_test_event(
        "selected",
        title="Runtime update",
        lane="runtime",
        kind="runtime_update",
        status="running",
        detail="model-tool-calls selected 1 tool call",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let rows : Array[MoonCodeActivityRow] = []
  for item in items {
    match item.activity {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].label, "Working")
  assert_eq(rows[0].title, "Choosing what to do next")
  assert_eq(rows[0].detail, "Chose what to do next.")
}

///|
test "code mode activity rows render runtime proof events as friendly progress" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Package and commit the work",
        command="prompt",
      ),
      code_mode_test_event(
        "package",
        title="Package verified by runtime",
        lane="artifact",
        kind="runtime.package_verified",
        status="verified",
        detail="{\"proof\":\"raw\"}",
        path="portable/app-tool/mooncode/session-a/index.json",
        command="package",
      ),
      code_mode_test_event(
        "commit",
        title="Commit created by runtime",
        lane="review",
        kind="runtime.commit_created",
        status="done",
        detail="abc1234",
        command="commit",
      ),
      code_mode_test_event(
        "patch",
        title="Patch applied by runtime",
        lane="review",
        kind="runtime.patch_applied",
        status="done",
        detail="applied cleanly",
        path="wiki/index.md",
        command="apply_patch",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let rows : Array[MoonCodeActivityRow] = []
  for item in items {
    match item.activity {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  assert_eq(rows.length(), 3)
  assert_eq(rows[0].label, "Packaged")
  assert_eq(rows[0].title, "Package verified")
  assert_eq(rows[0].detail, "portable/app-tool/mooncode/session-a/index.json")
  assert_eq(rows[1].label, "Committed")
  assert_eq(rows[1].title, "Commit created")
  assert_eq(rows[1].detail, "abc1234")
  assert_eq(rows[2].label, "Edited")
  assert_eq(rows[2].title, "Patch applied")
  assert_eq(rows[2].detail, "applied cleanly")
}

///|
test "code mode transcript items keep messages and progress in event order" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "001-command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Fix the parser bug",
        command="prompt",
        created_at="001",
      ),
      code_mode_test_event(
        "002-thinking",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Inspect the parser before editing.",
        created_at="002",
      ),
      code_mode_test_event(
        "003-tool",
        title="Tool started: moon_check",
        lane="test",
        kind="tool_call",
        status="running",
        detail="{\"tool\":\"moon_check\"}",
        created_at="003",
      ),
      code_mode_test_event(
        "004-result",
        title="moon check",
        lane="test",
        kind="tool_result",
        status="done",
        detail="Finished. moon: no work to do",
        created_at="004",
      ),
      code_mode_test_event(
        "005-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        created_at="005",
        tool_result=Some({ "tool": "finish", "ok": true, "output": "Done." }),
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 5)
  match items[0].message {
    Some(row) => {
      assert_eq(row.role, "user")
      assert_eq(row.content, "Fix the parser bug")
    }
    None => fail("expected user message")
  }
  match items[1].activity {
    Some(row) => {
      assert_eq(row.label, "Progress")
      assert_eq(row.detail, "Inspect the parser before editing.")
      assert_eq(row.folded, true)
    }
    None => fail("expected folded thinking activity")
  }
  match items[2].activity {
    Some(row) => {
      assert_eq(row.label, "Checking project")
      assert_eq(row.title, "moon check")
    }
    None => fail("expected tool activity")
  }
  match items[3].activity {
    Some(row) => {
      assert_eq(row.label, "Checked")
      assert_eq(row.title, "moon check")
    }
    None => fail("expected check activity")
  }
  match items[4].message {
    Some(row) => {
      assert_eq(row.role, "assistant")
      assert_eq(row.content, "Done.")
    }
    None => fail("expected assistant message")
  }
}

///|
test "code mode transcript uses backend canonical conversation before raw events" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "First prompt",
          assistant="First answer",
          progress=[
            {
              "role": "progress",
              "title": "Thinking",
              "detail": "Prepared the first answer.",
              "status": "done",
            },
          ],
        ),
        code_mode_test_turn(
          "command-second",
          "Second prompt",
          assistant="Second answer",
        ),
      ]),
    ),
    mooncode_events: [
      code_mode_test_event(
        "finish-second",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Second answer from raw event",
        }),
      ),
      code_mode_test_event(
        "prompt-first",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First prompt",
        command="prompt",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let messages : Array[String] = []
  let activities : Array[String] = []
  for item in items {
    match item.message {
      Some(row) => messages.push(row.role + ":" + row.content)
      None =>
        match item.activity {
          Some(row) => activities.push(row.title + ":" + row.detail)
          None => ()
        }
    }
  }
  assert_eq(messages.length(), 4)
  assert_eq(messages[0], "user:First prompt")
  assert_eq(messages[1], "assistant:First answer")
  assert_eq(messages[2], "user:Second prompt")
  assert_eq(messages[3], "assistant:Second answer")
  assert_eq(activities.length(), 1)
  assert_eq(activities[0], "Prepared the response:Prepared the first answer.")
}

///|
test "code mode transcript appends local optimistic turn after backend conversation" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "First prompt",
          assistant="First answer",
        ),
        code_mode_test_turn(
          "command-second",
          "Second prompt",
          assistant="Second answer",
        ),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "Third prompt",
        status: "queued",
        key: "ui-user:session-a:third",
      },
    ],
    mooncode_stream_session_id: "session-a",
    mooncode_stream_events: [
      code_mode_test_event(
        "raw-old",
        title="Raw old event",
        lane="runtime",
        kind="runtime_step",
        status="running",
        detail="This raw event must not reorder the chat.",
      ),
    ],
  }
  let items = mooncode_transcript_items(model, session)
  let messages : Array[String] = []
  for item in items {
    match item.message {
      Some(row) => messages.push(row.role + ":" + row.content)
      None => ()
    }
  }
  assert_eq(messages.length(), 5)
  assert_eq(messages[0], "user:First prompt")
  assert_eq(messages[1], "assistant:First answer")
  assert_eq(messages[2], "user:Second prompt")
  assert_eq(messages[3], "assistant:Second answer")
  assert_eq(messages[4], "user:Third prompt")
}

///|
test "code mode transcript drops acknowledged optimistic turn by client turn id" {
  let session = {
    ..code_mode_test_session("session-a", status="queued"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "Same text",
          client_turn_id="client-turn-1",
        ),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "Local echo that should be replaced",
        status: "queued",
        key: "client-turn-1",
      },
      {
        session_id: "session-a",
        role: "user",
        content: "Same text",
        status: "queued",
        key: "client-turn-2",
      },
    ],
  }
  let items = mooncode_transcript_items(model, session)
  let messages : Array[String] = []
  for item in items {
    match item.message {
      Some(row) => messages.push(row.role + ":" + row.content)
      None => ()
    }
  }
  assert_eq(messages.length(), 1)
  assert_eq(messages[0], "user:Same text")
}

///|
test "code mode transcript pairs durable prompts with native runtime groups" {
  let events = [
    code_mode_test_event(
      "cmd-a-queued",
      command_id="cmd-a",
      title="MoonCode command queued for native runtime turn",
      lane="runtime",
      kind="command.queued_for_runtime_turn",
      status="queued",
      detail="Queued first command",
      created_at="2000",
    ),
    code_mode_test_event(
      "cmd-a-thinking",
      command_id="cmd-a",
      title="MoonCode planner step 1",
      lane="runtime",
      kind="reasoning_delta",
      status="running",
      detail="Thinking about first command",
      created_at="2100",
    ),
    code_mode_test_event(
      "cmd-a-finish",
      command_id="cmd-a",
      title="MoonCode tool `finish` completed",
      lane="review",
      kind="finish",
      status="done",
      detail="finished",
      created_at="2200",
      tool_result=Some({
        "tool": "finish",
        "ok": true,
        "output": "First answer",
      }),
    ),
    code_mode_test_event(
      "cmd-b-queued",
      command_id="cmd-b",
      title="MoonCode command queued for native runtime turn",
      lane="runtime",
      kind="command.queued_for_runtime_turn",
      status="queued",
      detail="Queued second command",
      created_at="4000",
    ),
    code_mode_test_event(
      "cmd-b-thinking",
      command_id="cmd-b",
      title="MoonCode planner step 1",
      lane="runtime",
      kind="reasoning_delta",
      status="running",
      detail="Thinking about second command",
      created_at="4100",
    ),
    code_mode_test_event(
      "cmd-b-finish",
      command_id="cmd-b",
      title="MoonCode tool `finish` completed",
      lane="review",
      kind="finish",
      status="done",
      detail="finished",
      created_at="4200",
      tool_result=Some({
        "tool": "finish",
        "ok": true,
        "output": "Second answer",
      }),
    ),
    code_mode_test_event(
      "cmd-a-prompt",
      command_id="cmd-a",
      title="Prompt: queued",
      lane="runtime",
      kind="command.prompt",
      status="queued",
      detail="First prompt",
      command="prompt",
      created_at="1000",
    ),
    code_mode_test_event(
      "cmd-b-prompt",
      command_id="cmd-b",
      title="Prompt: queued",
      lane="runtime",
      kind="command.prompt",
      status="queued",
      detail="Second prompt",
      command="prompt",
      created_at="3000",
    ),
  ]
  let session = code_mode_test_session("session-a", status="done")
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_runtime_event_sink_session_id: "session-a",
    mooncode_runtime_event_sink: Some({
      event_count: events.length(),
      events,
      runtime_service: { status: "idle" },
    }),
  }
  let items = mooncode_transcript_items(model, session)
  let mut first_user = -1
  let mut first_thinking = -1
  let mut first_assistant = -1
  let mut second_user = -1
  let mut second_thinking = -1
  let mut second_assistant = -1
  for index, item in items {
    match item.message {
      Some(row) =>
        if row.role == "user" && row.content == "First prompt" {
          first_user = index
        } else if row.role == "assistant" && row.content == "First answer" {
          first_assistant = index
        } else if row.role == "user" && row.content == "Second prompt" {
          second_user = index
        } else if row.role == "assistant" && row.content == "Second answer" {
          second_assistant = index
        }
      None => ()
    }
    match item.activity {
      Some(row) =>
        if row.detail == "Thinking about first command" {
          first_thinking = index
        } else if row.detail == "Thinking about second command" {
          second_thinking = index
        }
      None => ()
    }
  }
  assert_true(first_user >= 0)
  assert_true(first_thinking >= 0)
  assert_true(first_assistant >= 0)
  assert_true(second_user >= 0)
  assert_true(second_thinking >= 0)
  assert_true(second_assistant >= 0)
  assert_true(first_user < first_thinking)
  assert_true(first_thinking < first_assistant)
  assert_true(first_assistant < second_user)
  assert_true(second_user < second_thinking)
  assert_true(second_thinking < second_assistant)
}

///|
test "code mode transcript ignores stale optimistic prompt prefix after native events" {
  let events = [
    code_mode_test_event(
      "cmd-a-thinking",
      command_id="cmd-a",
      title="MoonCode planner step 1",
      lane="runtime",
      kind="reasoning_delta",
      status="running",
      detail="Thinking about first command",
      created_at="2100",
    ),
    code_mode_test_event(
      "cmd-a-finish",
      command_id="cmd-a",
      title="MoonCode tool `finish` completed",
      lane="review",
      kind="finish",
      status="done",
      detail="finished",
      created_at="2200",
      tool_result=Some({
        "tool": "finish",
        "ok": true,
        "output": "First answer",
      }),
    ),
    code_mode_test_event(
      "cmd-b-thinking",
      command_id="cmd-b",
      title="MoonCode planner step 1",
      lane="runtime",
      kind="reasoning_delta",
      status="running",
      detail="Thinking about second command",
      created_at="4100",
    ),
    code_mode_test_event(
      "cmd-b-finish",
      command_id="cmd-b",
      title="MoonCode tool `finish` completed",
      lane="review",
      kind="finish",
      status="done",
      detail="finished",
      created_at="4200",
      tool_result=Some({
        "tool": "finish",
        "ok": true,
        "output": "Second answer",
      }),
    ),
    code_mode_test_event(
      "cmd-a-prompt",
      command_id="cmd-a",
      title="Prompt: queued",
      lane="runtime",
      kind="command.prompt",
      status="queued",
      detail="First prompt",
      command="prompt",
      created_at="1000",
    ),
    code_mode_test_event(
      "cmd-b-prompt",
      command_id="cmd-b",
      title="Prompt: queued",
      lane="runtime",
      kind="command.prompt",
      status="queued",
      detail="Second prompt",
      command="prompt",
      created_at="3000",
    ),
  ]
  let session = code_mode_test_session("session-a", status="done")
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "First prompt",
        status: "queued",
        key: "ui-user:session-a:0",
      },
      {
        session_id: "session-a",
        role: "user",
        content: "Second prompt",
        status: "queued",
        key: "ui-user:session-a:1",
      },
    ],
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "First prompt",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "Second prompt",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
    mooncode_runtime_event_sink_session_id: "session-a",
    mooncode_runtime_event_sink: Some({
      event_count: events.length(),
      events,
      runtime_service: { status: "idle" },
    }),
  }
  let items = mooncode_transcript_items(model, session)
  let mut first_assistant = -1
  let mut second_user = -1
  for index, item in items {
    match item.message {
      Some(row) =>
        if row.role == "assistant" && row.content == "First answer" {
          first_assistant = index
        } else if row.role == "user" && row.content == "Second prompt" {
          second_user = index
        }
      None => ()
    }
  }
  assert_true(first_assistant >= 0)
  assert_true(second_user > first_assistant)
}

///|
test "code mode transcript appends optimistic second prompt after first native answer" {
  let events = [
    code_mode_test_event(
      "cmd-a-thinking",
      command_id="cmd-a",
      title="MoonCode planner step 1",
      lane="runtime",
      kind="reasoning_delta",
      status="running",
      detail="Thinking about first command",
      created_at="2100",
    ),
    code_mode_test_event(
      "cmd-a-finish",
      command_id="cmd-a",
      title="MoonCode tool `finish` completed",
      lane="review",
      kind="finish",
      status="done",
      detail="finished",
      created_at="2200",
      tool_result=Some({
        "tool": "finish",
        "ok": true,
        "output": "First answer",
      }),
    ),
    code_mode_test_event(
      "cmd-b-thinking",
      command_id="cmd-b",
      title="MoonCode planner step 1",
      lane="runtime",
      kind="reasoning_delta",
      status="running",
      detail="Thinking about second command",
      created_at="4100",
    ),
    code_mode_test_event(
      "cmd-b-finish",
      command_id="cmd-b",
      title="MoonCode tool `finish` completed",
      lane="review",
      kind="finish",
      status="done",
      detail="finished",
      created_at="4200",
      tool_result=Some({
        "tool": "finish",
        "ok": true,
        "output": "Second answer",
      }),
    ),
    code_mode_test_event(
      "cmd-a-prompt",
      command_id="cmd-a",
      title="Prompt: queued",
      lane="runtime",
      kind="command.prompt",
      status="queued",
      detail="First prompt",
      command="prompt",
      created_at="1000",
    ),
  ]
  let session = code_mode_test_session("session-a", status="done")
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "First prompt",
        status: "queued",
        key: "ui-user:session-a:0",
      },
      {
        session_id: "session-a",
        role: "user",
        content: "Second prompt",
        status: "queued",
        key: "ui-user:session-a:1",
      },
    ],
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "Second prompt",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
    mooncode_runtime_event_sink_session_id: "session-a",
    mooncode_runtime_event_sink: Some({
      event_count: events.length(),
      events,
      runtime_service: { status: "idle" },
    }),
  }
  let items = mooncode_transcript_items(model, session)
  let mut first_assistant = -1
  let mut second_user = -1
  let mut second_assistant = -1
  for index, item in items {
    match item.message {
      Some(row) =>
        if row.role == "assistant" && row.content == "First answer" {
          first_assistant = index
        } else if row.role == "user" && row.content == "Second prompt" {
          second_user = index
        } else if row.role == "assistant" && row.content == "Second answer" {
          second_assistant = index
        }
      None => ()
    }
  }
  assert_true(first_assistant >= 0)
  assert_true(second_user > first_assistant)
  assert_true(second_assistant > second_user)
}

///|
test "code mode transcript repair interleaves grouped optimistic user prefix" {
  let items = [
    mooncode_transcript_message_item({
      role: "user",
      content: "First prompt",
      status: "queued",
    }),
    mooncode_transcript_message_item({
      role: "user",
      content: "Second prompt",
      status: "queued",
    }),
    mooncode_transcript_message_item({
      role: "assistant",
      content: "First answer",
      status: "done",
    }),
    mooncode_transcript_message_item({
      role: "assistant",
      content: "Second answer",
      status: "done",
    }),
  ]
  let repaired = mooncode_repair_grouped_user_prefix_items(items)
  assert_eq(repaired.length(), 4)
  match repaired[0].message {
    Some(row) => assert_eq(row.content, "First prompt")
    None => fail("expected first user")
  }
  match repaired[1].message {
    Some(row) => assert_eq(row.content, "First answer")
    None => fail("expected first assistant")
  }
  match repaired[2].message {
    Some(row) => assert_eq(row.content, "Second prompt")
    None => fail("expected second user")
  }
  match repaired[3].message {
    Some(row) => assert_eq(row.content, "Second answer")
    None => fail("expected second assistant")
  }
}

///|
test "code mode transcript drops recovered runtime service failure assistant" {
  let items = [
    mooncode_transcript_message_item({
      role: "user",
      content: "how are you",
      status: "queued",
    }),
    mooncode_transcript_message_item({
      role: "assistant",
      content: "I am doing well.",
      status: "done",
    }),
    mooncode_transcript_message_item({
      role: "assistant",
      content: "Could not start MoonCode runtime service",
      status: "failed",
    }),
  ]
  let cleaned = mooncode_drop_recovered_failed_assistant_items(items)
  assert_eq(cleaned.length(), 2)
  match cleaned[1].message {
    Some(row) => {
      assert_eq(row.role, "assistant")
      assert_eq(row.status, "done")
      assert_eq(row.content, "I am doing well.")
    }
    None => fail("expected successful assistant")
  }
}

///|
test "code mode transcript items do not repeat final assistant text after progress" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "001-command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Check the build",
        command="prompt",
        created_at="001",
      ),
      code_mode_test_event(
        "002-delta",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="I will run the build.",
        created_at="002",
      ),
      code_mode_test_event(
        "003-tool",
        title="Tool started: moon_check",
        lane="test",
        kind="tool_call",
        status="running",
        detail="{\"tool\":\"moon_check\"}",
        created_at="003",
      ),
      code_mode_test_event(
        "004-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        created_at="004",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "I will run the build.",
        }),
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 3)
  match items[0].message {
    Some(row) => assert_eq(row.role, "user")
    None => fail("expected user message")
  }
  match items[1].message {
    Some(row) => {
      assert_eq(row.role, "assistant")
      assert_eq(row.content, "I will run the build.")
      assert_eq(row.status, "done")
    }
    None => fail("expected assistant stream message")
  }
  match items[2].activity {
    Some(row) => assert_eq(row.label, "Checking project")
    None => fail("expected progress row")
  }
}

///|
test "code mode transcript items append only final assistant suffix after progress" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "001-command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Check the build",
        command="prompt",
        created_at="001",
      ),
      code_mode_test_event(
        "002-delta",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="I will run the build.",
        created_at="002",
      ),
      code_mode_test_event(
        "003-tool",
        title="Tool started: moon_check",
        lane="test",
        kind="tool_call",
        status="running",
        detail="{\"tool\":\"moon_check\"}",
        created_at="003",
      ),
      code_mode_test_event(
        "004-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        created_at="004",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "I will run the build. It passes.",
        }),
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 4)
  match items[1].message {
    Some(row) => assert_eq(row.content, "I will run the build.")
    None => fail("expected assistant stream message")
  }
  match items[2].activity {
    Some(row) => assert_eq(row.label, "Checking project")
    None => fail("expected progress row")
  }
  match items[3].message {
    Some(row) => {
      assert_eq(row.role, "assistant")
      assert_eq(row.content, "It passes.")
      assert_eq(row.status, "done")
    }
    None => fail("expected assistant final suffix")
  }
}

///|
test "code mode transcript items prefer append order over skewed timestamps" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Why is order broken?",
        command="prompt",
        created_at="300",
      ),
      code_mode_test_event(
        "thinking",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Inspecting event order.",
        created_at="100",
      ),
      code_mode_test_event(
        "assistant",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="Found it.",
        created_at="200",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 3)
  match items[0].message {
    Some(row) => {
      assert_eq(row.role, "user")
      assert_eq(row.content, "Why is order broken?")
    }
    None => fail("expected user message first")
  }
  match items[1].activity {
    Some(row) => {
      assert_eq(row.label, "Progress")
      assert_eq(row.detail, "Inspecting event order.")
      assert_eq(row.folded, true)
    }
    None => fail("expected folded thinking second")
  }
  match items[2].message {
    Some(row) => {
      assert_eq(row.role, "assistant")
      assert_eq(row.content, "Found it.")
    }
    None => fail("expected assistant third")
  }
}

///|
test "code mode final reply appends after tool work" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "001-command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Fix the parser bug",
        command="prompt",
      ),
      code_mode_test_event(
        "002-assistant",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="I will inspect it.",
      ),
      code_mode_test_event(
        "003-tool",
        title="Tool started: Bash",
        lane="test",
        kind="tool_call",
        status="running",
        detail="{\"tool\":\"Bash\",\"arguments\":{\"command\":\"moon test internal/mooncode\",\"description\":\"Run MoonCode tests\"}}",
      ),
      code_mode_test_event(
        "004-result",
        title="Tool finished",
        lane="test",
        kind="tool_result",
        status="done",
        detail="Total tests: 256, passed: 256",
        tool_result=Some({
          "tool": "Bash",
          "output": "Total tests: 256, passed: 256",
        }),
      ),
      code_mode_test_event(
        "005-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "The parser bug is fixed.",
        }),
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 5)
  match items[0].message {
    Some(row) => assert_eq(row.content, "Fix the parser bug")
    None => fail("expected user prompt")
  }
  match items[1].message {
    Some(row) => {
      assert_eq(row.content, "I will inspect it.")
      assert_eq(row.status, "done")
    }
    None => fail("expected early assistant update")
  }
  match items[2].activity {
    Some(row) => assert_eq(row.label, "Running tests")
    None => fail("expected tool activity")
  }
  match items[3].activity {
    Some(row) => assert_eq(row.label, "Checked")
    None => fail("expected tool result")
  }
  match items[4].message {
    Some(row) => assert_eq(row.content, "The parser bug is fixed.")
    None => fail("expected final assistant reply at tail")
  }
}

///|
test "code mode transcript drops leading orphan activity" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "thinking",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Thinking should not lead the transcript.",
        created_at="100",
      ),
      code_mode_test_event(
        "prompt-a",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Older prompt",
        command="prompt",
        created_at="200",
      ),
      code_mode_test_event(
        "prompt-b",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Latest prompt",
        command="prompt",
        created_at="300",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 2)
  match items[0].message {
    Some(row) => assert_eq(row.content, "Older prompt")
    None => fail("expected first prompt")
  }
  match items[1].message {
    Some(row) => assert_eq(row.content, "Latest prompt")
    None => fail("expected latest prompt")
  }
}

///|
test "code mode transcript uses finish tool output as assistant reply" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Say hello",
        command="prompt",
      ),
      code_mode_test_event(
        "finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Hello from MoonCode.",
        }),
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "Hello from MoonCode.")
}

///|
test "code mode transcript keeps previous assistant replies append-only" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command-a",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First question",
        command="prompt",
      ),
      code_mode_test_event(
        "finish-a",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Same answer.",
        }),
      ),
      code_mode_test_event(
        "command-b",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Second question",
        command="prompt",
      ),
      code_mode_test_event(
        "finish-b",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Same answer.",
        }),
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 4)
  assert_eq(rows[0].content, "First question")
  assert_eq(rows[1].content, "Same answer.")
  assert_eq(rows[2].content, "Second question")
  assert_eq(rows[3].content, "Same answer.")
}

///|
test "code mode transcript splits assistant deltas by completed runtime turn" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command-a",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First question",
        command="prompt",
      ),
      code_mode_test_event(
        "assistant-a",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="First answer.",
      ),
      code_mode_test_event(
        "turn-a",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
      ),
      code_mode_test_event(
        "command-b",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Second question",
        command="prompt",
      ),
      code_mode_test_event(
        "assistant-b",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="Second answer.",
      ),
      code_mode_test_event(
        "turn-b",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 4)
  assert_eq(rows[0].content, "First question")
  assert_eq(rows[1].content, "First answer.")
  assert_eq(rows[2].content, "Second question")
  assert_eq(rows[3].content, "Second answer.")
}

///|
test "code mode transcript orders prompt before runtime sink reply" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "assistant-a",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="First answer.",
        created_at="200",
      ),
      code_mode_test_event(
        "turn-a",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
        created_at="201",
      ),
      code_mode_test_event(
        "command-a",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First question",
        command="prompt",
        created_at="100",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "First question")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "First answer.")
}

///|
test "code mode transcript interleaves recovered native replies by command id" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "mooncode-command-first",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First recovered prompt",
        command="prompt",
      ),
      code_mode_test_event(
        "mooncode-command-second",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Second recovered prompt",
        command="prompt",
      ),
      code_mode_test_event(
        "moonclaw-session-a-mooncode-command-first-assistant-step-1",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="First recovered reply.",
      ),
      code_mode_test_event(
        "moonclaw-session-a-mooncode-command-first-runtime.turn_finished",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
      ),
      code_mode_test_event(
        "moonclaw-session-a-mooncode-command-second-assistant-step-1",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="Second recovered reply.",
      ),
      code_mode_test_event(
        "moonclaw-session-a-mooncode-command-second-runtime.turn_finished",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 4)
  assert_eq(rows[0].content, "First recovered prompt")
  assert_eq(rows[1].content, "First recovered reply.")
  assert_eq(rows[2].content, "Second recovered prompt")
  assert_eq(rows[3].content, "Second recovered reply.")
}

///|
test "code mode transcript links native replies by explicit command id" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "assistant-random-first",
        command_id="cmd-first",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="First explicit reply.",
      ),
      code_mode_test_event(
        "prompt-random-first",
        command_id="cmd-first",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First explicit prompt",
        command="prompt",
      ),
      code_mode_test_event(
        "assistant-random-second",
        command_id="cmd-second",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="Second explicit reply.",
      ),
      code_mode_test_event(
        "prompt-random-second",
        command_packet=Some({ "command_id": "cmd-second" }),
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Second explicit prompt",
        command="prompt",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 4)
  assert_eq(rows[0].content, "First explicit prompt")
  assert_eq(rows[1].content, "First explicit reply.")
  assert_eq(rows[2].content, "Second explicit prompt")
  assert_eq(rows[3].content, "Second explicit reply.")
}

///|
test "code mode transcript keeps thinking between each native prompt and reply" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "mooncode-command-first",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First turn",
        command="prompt",
      ),
      code_mode_test_event(
        "mooncode-command-second",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Second turn",
        command="prompt",
      ),
      code_mode_test_event(
        "moonclaw-session-a-mooncode-command-first-assistant-step-1",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="First answer.",
      ),
      code_mode_test_event(
        "moonclaw-session-a-mooncode-command-first-planner-step-1",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Planning next step.",
      ),
      code_mode_test_event(
        "moonclaw-session-a-mooncode-command-second-assistant-step-1",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="Second answer.",
      ),
      code_mode_test_event(
        "moonclaw-session-a-mooncode-command-second-planner-step-1",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Planning next step.",
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 6)
  match items[0].message {
    Some(row) => assert_eq(row.content, "First turn")
    None => fail("expected first user message")
  }
  match items[1].activity {
    Some(row) => assert_eq(row.label, "Progress")
    None => fail("expected first thinking row before assistant")
  }
  match items[2].message {
    Some(row) => assert_eq(row.content, "First answer.")
    None => fail("expected first assistant reply")
  }
  match items[3].message {
    Some(row) => assert_eq(row.content, "Second turn")
    None => fail("expected second user message")
  }
  match items[4].activity {
    Some(row) => assert_eq(row.label, "Progress")
    None => fail("expected second thinking row before assistant")
  }
  match items[5].message {
    Some(row) => assert_eq(row.content, "Second answer.")
    None => fail("expected second assistant reply")
  }
}

///|
test "code mode transcript keeps final reply when sink emits finish before prompt" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "finish-a",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        created_at="200",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Final answer from replay.",
        }),
      ),
      code_mode_test_event(
        "command-a",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Replay question",
        command="prompt",
        created_at="100",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Replay question")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].status, "done")
  assert_eq(rows[1].content, "Final answer from replay.")
}

///|
test "code mode transcript keeps duplicated prompt status out of chat" {
  let session = {
    ..code_mode_test_session("session-a", status="created"),
    transcript: [
      {
        role: "status",
        content: "Local agent is not reachable yet.",
        status: "queued",
      },
    ],
    mooncode_events: [
      code_mode_test_event(
        "command-a",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="hey hows going?",
        command="prompt",
      ),
      code_mode_test_event(
        "command-a",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Local agent is not reachable yet.",
        command="prompt",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "hey hows going?")
}

///|
test "code mode transcript does not show generic finished as reply" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Say hello",
        command="prompt",
      ),
      code_mode_test_event(
        "finish",
        title="Runtime finished",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Say hello")
}

///|
test "code mode transcript does not show runtime completion as reply" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    transcript: [
      {
        role: "status",
        content: "MoonClaw native MoonCode runtime loop completed",
        status: "done",
      },
    ],
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Say only hello",
        command="prompt",
      ),
      code_mode_test_event(
        "finish",
        title="Runtime finished",
        lane="review",
        kind="finish",
        status="done",
        detail="MoonClaw native MoonCode runtime loop completed",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Say only hello")
}

///|
test "code mode transcript does not show native recorded prompt as reply" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="hello?",
        command="prompt",
      ),
      code_mode_test_event(
        "finish",
        title="Runtime finished",
        lane="review",
        kind="finish",
        status="done",
        detail="Native MoonCode runtime recorded this prompt. Ask for a tool, script, miniapp, app, or generated site to have MoonClaw create executable MoonBook code with native tools.",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "hello?")
}

///|
test "code mode transcript does not show native recorded tool output as reply" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="hello?",
        command="prompt",
      ),
      code_mode_test_event(
        "finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Native MoonCode runtime recorded this prompt. Ask for a tool, script, miniapp, app, or generated site to have MoonClaw create executable MoonBook code with native tools.",
        }),
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "hello?")
}

///|
test "code mode transcript replaces stale working row with model blocker" {
  let session = {
    ..code_mode_test_session("session-a", status="created"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="hello?",
        command="prompt",
      ),
      code_mode_test_event(
        "runtime-loop",
        title="Native runtime loop: idle",
        kind="runtime_loop",
        status="done",
        detail="MoonClaw native runtime loop completed 1 turn(s) and reached an idle queue.",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(init_model(), session)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "hello?")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "No AI model is configured for MoonCode yet.")
}

///|
test "code mode transcript suppresses stale working row after terminal with model" {
  let session = {
    ..code_mode_test_session("session-a", status="created"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="hello?",
        command="prompt",
      ),
      code_mode_test_event(
        "runtime-loop",
        title="Native runtime loop: idle",
        kind="runtime_loop",
        status="done",
        detail="MoonClaw native runtime loop completed 1 turn(s) and reached an idle queue.",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "hello?")
}

///|
test "code mode transcript shows terminal failure as assistant response" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Reply with hello",
        command="prompt",
      ),
      code_mode_test_event(
        "planner-failed",
        title="Planner failed",
        kind="runtime.planner_failed",
        status="failed",
        detail="MoonCode model planner failed: Codex auth is not available.",
      ),
      code_mode_test_event(
        "fallback-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Native MoonCode runtime recorded this prompt. Ask for a tool, script, miniapp, app, or generated site to have MoonClaw create executable MoonBook code with native tools.",
        }),
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    { ..init_model(), mooncode_model: "codex/gpt-5.4" },
    session,
  )
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Reply with hello")
  assert_eq(rows[1].role, "assistant")
  assert_eq(
    rows[1].content,
    "MoonCode model planner failed: Codex auth is not available.",
  )
}

///|
test "code mode transcript keeps runtime progress out of assistant reply rows" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "command",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Add tests",
        command="prompt",
      ),
      code_mode_test_event(
        "runtime-step",
        title="Runtime step",
        kind="runtime_step",
        status="running",
        detail="{\"step\":\"decode-command\"}",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(init_model(), session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Add tests")
}

///|
test "code mode transcript shows pending prompt immediately" {
  let session = code_mode_test_session("session-a", status="running")
  let model = {
    ..init_model(),
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "Run the tests now",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
  }
  let rows = mooncode_transcript_rows(model, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Run the tests now")
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 1)
  match items[0].message {
    Some(row) => assert_eq(row.content, "Run the tests now")
    None => fail("expected pending user prompt")
  }
}

///|
test "code mode transcript keeps pending prompt before early assistant event" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "assistant-early",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="Early reply",
        created_at="200",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    {
      ..init_model(),
      mooncode_pending_prompts: [
        {
          session_id: "session-a",
          client_turn_id: "",
          content: "Pending question",
          status: "queued",
          after_row_count: 0,
          after_event_count: 0,
        },
      ],
    },
    session,
  )
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Pending question")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "Early reply")
}

///|
test "code mode transcript keeps pending prompt directly before fast answer" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "prompt-event",
        command_id="cmd-1",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Browser smoke prompt append order",
        command="prompt",
        created_at="100",
      ),
      code_mode_test_event(
        "fast-answer",
        command_id="cmd-1",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        created_at="101",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Fast answer",
        }),
      ),
    ],
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
      [],
      "session-a",
      "Browser smoke prompt append order",
    ),
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "Browser smoke prompt append order",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
  }
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 2)
  match items[0].message {
    Some(row) => {
      assert_eq(row.role, "user")
      assert_eq(row.content, "Browser smoke prompt append order")
    }
    None => fail("expected user prompt first")
  }
  match items[1].message {
    Some(row) => {
      assert_eq(row.role, "assistant")
      assert_eq(row.content, "Fast answer")
    }
    None => fail("expected assistant answer second")
  }
}

///|
test "code mode transcript ignores assistant-only raw transcript during live conversation" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    transcript: [
      {
        role: "assistant",
        content: "Raw assistant should not jump first",
        status: "done",
      },
    ],
    mooncode_events: [
      code_mode_test_event(
        "assistant-live",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="Live answer",
        created_at="200",
      ),
      code_mode_test_event(
        "turn-live",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
        created_at="201",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(
    {
      ..init_model(),
      mooncode_pending_prompts: [
        {
          session_id: "session-a",
          client_turn_id: "",
          content: "User prompt stays first",
          status: "queued",
          after_row_count: 0,
          after_event_count: 0,
        },
      ],
    },
    session,
  )
  assert_eq(rows.length(), 3)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "User prompt stays first")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "Live answer")
  assert_eq(rows[2].role, "assistant")
  assert_eq(rows[2].content, "Raw assistant should not jump first")
}

///|
test "code mode transcript repairs assistant-first raw transcript fallback" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    transcript: [
      { role: "assistant", content: "Second answer", status: "done" },
      { role: "assistant", content: "First answer", status: "done" },
      { role: "user", content: "First prompt", status: "queued" },
      { role: "user", content: "Second prompt", status: "queued" },
    ],
  }
  let rows = mooncode_transcript_rows(init_model(), session)
  assert_eq(rows.length(), 4)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "First prompt")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "First answer")
  assert_eq(rows[2].role, "user")
  assert_eq(rows[2].content, "Second prompt")
  assert_eq(rows[3].role, "assistant")
  assert_eq(rows[3].content, "Second answer")
}

///|
test "code mode transcript waits for runtime events instead of flashing stale rows" {
  let session = code_mode_test_session("session-a", status="running")
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_stream_session_id: "session-a",
    mooncode_stream_events: [
      code_mode_test_event(
        "prompt-only",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Prompt from fast stream",
        command="prompt",
      ),
    ],
    mooncode_runtime_event_sink_session_id: "",
    mooncode_runtime_event_sink: None,
    mooncode_runtime_event_sink_status: "loading runtime events",
    mooncode_conversation_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "Cached prompt",
        status: "queued",
        key: "ui-user:session-a:0",
      },
    ],
  }
  let no_events = {
    ..model,
    mooncode_stream_session_id: "",
    mooncode_stream_events: [],
  }
  assert_false(
    mooncode_transcript_waiting_for_runtime_events(no_events, session),
  )
  let no_local_conversation = { ..no_events, mooncode_conversation_rows: [] }
  assert_true(
    mooncode_transcript_waiting_for_runtime_events(no_local_conversation, session),
  )
  assert_false(mooncode_transcript_waiting_for_runtime_events(model, session))
  let with_pending = {
    ..model,
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "New prompt",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
  }
  assert_false(
    mooncode_transcript_waiting_for_runtime_events(with_pending, session),
  )
  let with_sink = {
    ..model,
    mooncode_runtime_event_sink_session_id: "session-a",
    mooncode_runtime_event_sink: Some({
      event_count: 1,
      events: [code_mode_test_event("runtime-a")],
      runtime_service: { status: "idle" },
    }),
    mooncode_runtime_event_sink_status: "1 runtime event(s)",
  }
  assert_false(
    mooncode_transcript_waiting_for_runtime_events(with_sink, session),
  )
}

///|
test "code mode new session action opens MoonCode draft without losing book context" {
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Inbox,
    command_open: true,
    selected_workspace_id: "book-demo",
    selected_path: "tools/parser.mbt",
    selected_mooncode_session_id: "old-session",
    mooncode_prompt: "stale draft",
    mooncode_composer_status: "old status",
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    NewMoonCodeSession,
    model,
  )
  assert_true(next.workspace_mode is MoonCode)
  assert_true(next.activity is Inbox)
  assert_false(next.command_open)
  assert_eq(next.selected_workspace_id, "book-demo")
  assert_eq(next.selected_path, "tools/parser.mbt")
  assert_eq(next.selected_mooncode_session_id, "")
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_composer_status, "new session draft")
}

///|
test "code mode selecting loaded session keeps runtime sink to avoid repaint" {
  let session = code_mode_test_session("session-a")
  let sink = {
    event_count: 1,
    events: [code_mode_test_event("runtime-a")],
    runtime_service: { status: "idle" },
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_stream_session_id: "session-a",
    mooncode_stream_cursor: 4,
    mooncode_stream_events: [code_mode_test_event("stream-a")],
    mooncode_stream_status: "live tail",
    mooncode_runtime_event_sink_session_id: "session-a",
    mooncode_runtime_event_sink: Some(sink),
    mooncode_runtime_event_sink_status: "1 runtime event(s)",
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SelectMoonCodeSession("session-a"),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "session-a")
  assert_eq(next.mooncode_stream_session_id, "session-a")
  assert_eq(next.mooncode_stream_cursor, 4)
  assert_eq(next.mooncode_stream_events.length(), 1)
  assert_eq(next.mooncode_runtime_event_sink_session_id, "session-a")
  assert_true(next.mooncode_runtime_event_sink is Some(_))
  assert_eq(next.mooncode_runtime_event_sink_status, "1 runtime event(s)")
}

///|
test "code mode prompt action adds pending prompt before runtime reply" {
  let session = code_mode_test_session("session-a", status="done")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_prompt: "Explain the latest error",
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage,
    model,
  )
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_pending_prompts.length(), 1)
  assert_eq(next.mooncode_pending_prompts[0].session_id, "session-a")
  assert_eq(
    next.mooncode_pending_prompts[0].content,
    "Explain the latest error",
  )
  assert_eq(next.mooncode_conversation_rows.length(), 1)
  assert_eq(next.mooncode_conversation_rows[0].role, "user")
  assert_eq(
    next.mooncode_conversation_rows[0].content,
    "Explain the latest error",
  )
  let rows = mooncode_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].content, "Explain the latest error")
}

///|
test "code mode new chat send appends local prompt immediately" {
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "",
    selected_mooncode_session_id: "",
    mooncode_sessions: [],
    mooncode_prompt: "Sketch the migration plan",
    mooncode_composer_status: "draft",
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage,
    model,
  )
  let draft_id = mooncode_draft_session_id(model)
  assert_eq(next.selected_mooncode_session_id, "")
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_conversation_rows.length(), 1)
  assert_eq(next.mooncode_conversation_rows[0].session_id, draft_id)
  assert_eq(next.mooncode_conversation_rows[0].role, "user")
  assert_eq(
    next.mooncode_conversation_rows[0].content,
    "Sketch the migration plan",
  )
  assert_eq(next.mooncode_pending_prompts.length(), 1)
  assert_eq(next.mooncode_pending_prompts[0].session_id, draft_id)
  let session = selected_mooncode_session(next).unwrap()
  assert_eq(session.id, draft_id)
  let rows = mooncode_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Sketch the migration plan")
}

///|
test "code mode draft transcript survives background status refresh" {
  let base = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "",
    mooncode_sessions: [],
    mooncode_prompt: "Keep this visible",
    mooncode_composer_status: "draft",
  }
  let (_, pending) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage,
    base,
  )
  let refreshed = {
    ..pending,
    mooncode_composer_status: "loaded MoonCode sessions",
  }
  let session = selected_mooncode_session(refreshed).unwrap()
  assert_eq(session.id, mooncode_draft_session_id(refreshed))
  let items = mooncode_transcript_items(refreshed, session)
  assert_eq(items.length(), 1)
  match items[0].message {
    Some(row) => assert_eq(row.content, "Keep this visible")
    None => fail("expected draft prompt after background refresh")
  }
}

///|
test "code mode created session adopts draft prompt rows" {
  let draft_model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "",
    selected_mooncode_session_id: "",
    mooncode_sessions: [],
    mooncode_prompt: "Keep the first prompt visible",
    mooncode_composer_status: "draft",
  }
  let (_, pending) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage,
    draft_model,
  )
  let real_session = code_mode_test_session("session-created", workspace_id="")
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    CreatedMoonCodeSession(Ok(real_session)),
    pending,
  )
  assert_eq(next.selected_mooncode_session_id, "session-created")
  assert_eq(next.mooncode_conversation_rows.length(), 1)
  assert_eq(next.mooncode_conversation_rows[0].session_id, "session-created")
  assert_eq(
    next.mooncode_conversation_rows[0].content,
    "Keep the first prompt visible",
  )
  assert_eq(next.mooncode_pending_prompts.length(), 1)
  assert_eq(next.mooncode_pending_prompts[0].session_id, "session-created")
  let session = selected_mooncode_session(next).unwrap()
  let rows = mooncode_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Keep the first prompt visible")
}

///|
test "code mode stale session listing preserves selected in-flight session" {
  let active = code_mode_test_session("session-created", workspace_id="")
  let older = code_mode_test_session("session-old", workspace_id="")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "",
    selected_mooncode_session_id: "session-created",
    mooncode_sessions: [active],
    mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
      [],
      "session-created",
      "Keep the new chat selected",
    ),
    mooncode_pending_prompts: [
      {
        session_id: "session-created",
        client_turn_id: "",
        content: "Keep the new chat selected",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([older])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "session-created")
  assert_eq(next.mooncode_sessions.length(), 2)
  assert_eq(next.mooncode_sessions[0].id, "session-created")
}

///|
test "code mode create response is idempotent after listing adoption" {
  let session = code_mode_test_session("session-created", workspace_id="")
  let model = {
    ..init_model(),
    selected_workspace_id: "",
    selected_mooncode_session_id: "session-created",
    mooncode_sessions: [session],
    mooncode_runtime_event_sink_session_id: "session-created",
    mooncode_runtime_event_sink_status: "waiting for backend runtime events",
    mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
      [],
      "session-created",
      "Already adopted",
    ),
    mooncode_pending_prompts: [
      {
        session_id: "session-created",
        client_turn_id: "",
        content: "Already adopted",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    CreatedMoonCodeSession(Ok(session)),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "session-created")
  assert_eq(next.mooncode_runtime_event_sink_session_id, "session-created")
  assert_eq(
    next.mooncode_runtime_event_sink_status,
    "waiting for backend runtime events",
  )
  assert_eq(next.mooncode_conversation_rows.length(), 1)
}

///|
test "code mode stale session listing keeps new chat draft selected" {
  let draft_model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "",
    selected_mooncode_session_id: "",
    mooncode_sessions: [code_mode_test_session("older", workspace_id="")],
    mooncode_prompt: "Keep draft selected",
    mooncode_composer_status: "draft",
  }
  let (_, pending) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage,
    draft_model,
  )
  let newer_listing = code_mode_test_session("older", workspace_id="")
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([newer_listing])),
    pending,
  )
  assert_eq(next.selected_mooncode_session_id, "")
  assert_true(mooncode_draft_session(next) is Some(_))
  let session = selected_mooncode_session(next).unwrap()
  let rows = mooncode_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].content, "Keep draft selected")
}

///|
test "code mode session listing adopts acknowledged new chat draft" {
  let draft_model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "",
    selected_mooncode_session_id: "",
    mooncode_sessions: [],
    mooncode_prompt: "Keep draft selected",
    mooncode_composer_status: "draft",
  }
  let (_, pending) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage,
    draft_model,
  )
  let client_turn_id = pending.mooncode_pending_prompts[0].client_turn_id
  let created = {
    ..code_mode_test_session(
      "session-created",
      workspace_id="",
      status="queued",
    ),
    workspace_name: "General MoonCode",
    transcript: [
      { role: "user", content: "Keep draft selected", status: "queued" },
    ],
    mooncode_events: [
      code_mode_test_event(
        "created-user",
        lane="transcript",
        kind="user",
        status="queued",
        detail="Keep draft selected",
        command_packet=Some({ "client_turn_id": client_turn_id }),
      ),
    ],
    mooncode_summary: { ..code_mode_test_summary(), event_count: 1 },
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([created])),
    pending,
  )
  assert_eq(next.selected_mooncode_session_id, "session-created")
  assert_eq(next.mooncode_sessions.length(), 1)
  assert_eq(next.mooncode_sessions[0].id, "session-created")
  assert_eq(next.mooncode_conversation_rows.length(), 1)
  assert_eq(next.mooncode_conversation_rows[0].session_id, "session-created")
  assert_eq(next.mooncode_pending_prompts.length(), 0)
  assert_eq(next.mooncode_composer_status, "MoonCode session started")
  let session = selected_mooncode_session(next).unwrap()
  let rows = mooncode_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Keep draft selected")
}

///|
test "code mode compact session listing adopts draft by prompt title" {
  let draft_model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "",
    selected_mooncode_session_id: "",
    mooncode_sessions: [],
    mooncode_prompt: "Compact listing prompt",
    mooncode_composer_status: "draft",
  }
  let (_, pending) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage,
    draft_model,
  )
  let compact = {
    ..code_mode_test_session(
      "session-compact",
      workspace_id="general-mooncode-users-kq-workspace-moondesk",
      status="queued",
    ),
    workspace_name: "General MoonCode",
    title: "Compact listing prompt",
    transcript: [],
    mooncode_events: [],
    mooncode_summary: { ..code_mode_test_summary(), event_count: 1 },
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([compact])),
    pending,
  )
  assert_eq(next.selected_mooncode_session_id, "session-compact")
  assert_eq(next.mooncode_conversation_rows.length(), 1)
  assert_eq(next.mooncode_conversation_rows[0].session_id, "session-compact")
  assert_eq(next.mooncode_composer_status, "MoonCode session started")
  let session = selected_mooncode_session(next).unwrap()
  let rows = mooncode_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].content, "Compact listing prompt")
  let items = mooncode_transcript_items(next, session)
  assert_eq(items.length(), 1)
}

///|
test "code mode transcript items show pending prompt over existing events" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "old-prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Old question",
        command="prompt",
      ),
      code_mode_test_event(
        "old-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Old answer",
        }),
      ),
    ],
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
      [],
      "session-a",
      "New question",
    ),
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "New question",
        status: "queued",
        after_row_count: 2,
        after_event_count: 2,
      },
    ],
  }
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 3)
  match items[2].message {
    Some(row) => {
      assert_eq(row.role, "user")
      assert_eq(row.content, "New question")
    }
    None => fail("expected pending user prompt")
  }
}

///|
test "code mode pending prompt with stale row index appends after existing events" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "old-prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Old question",
        command="prompt",
      ),
      code_mode_test_event(
        "old-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Old answer",
        }),
      ),
    ],
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
      [],
      "session-a",
      "Second question",
    ),
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "Second question",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
  }
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 3)
  match items[0].message {
    Some(row) => assert_eq(row.content, "Old question")
    None => fail("expected old prompt")
  }
  match items[1].message {
    Some(row) => assert_eq(row.content, "Old answer")
    None => fail("expected old answer")
  }
  match items[2].message {
    Some(row) => assert_eq(row.content, "Second question")
    None => fail("expected pending user prompt at the end")
  }
}

///|
test "code mode acknowledged local third prompt stays visible without pending marker" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "first-prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First question",
        command="prompt",
      ),
      code_mode_test_event(
        "first-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "First answer",
        }),
      ),
      code_mode_test_event(
        "second-prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Second question",
        command="prompt",
      ),
      code_mode_test_event(
        "second-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Second answer",
        }),
      ),
    ],
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
      [
        {
          session_id: "session-a",
          role: "user",
          content: "First question",
          status: "queued",
          key: "ui-user:session-a:0",
        },
        {
          session_id: "session-a",
          role: "user",
          content: "Second question",
          status: "queued",
          key: "ui-user:session-a:1",
        },
      ],
      "session-a",
      "Third question",
    ),
    mooncode_pending_prompts: [],
  }
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 5)
  match items[4].message {
    Some(row) => {
      assert_eq(row.role, "user")
      assert_eq(row.content, "Third question")
    }
    None => fail("expected local third prompt to remain visible")
  }
}

///|
test "code mode pending prompt keeps old native events before appended prompt" {
  let prompt : MoonCodePendingPrompt = {
    session_id: "session-a",
    client_turn_id: "",
    content: "New question",
    status: "queued",
    after_row_count: 1,
    after_event_count: 0,
  }
  let events = [
    code_mode_test_event(
      "old-runtime",
      title="MoonCode planner step 1",
      lane="runtime",
      kind="reasoning_delta",
      status="done",
      detail="Old runtime event.",
    ),
  ]
  assert_eq(mooncode_pending_prompt_event_split(prompt, events), 1)
}

///|
test "code mode queued session does not fake progress after prompt event acknowledgement" {
  let session = {
    ..code_mode_test_session("session-a", status="queued"),
    mooncode_events: [
      code_mode_test_event(
        "prompt-event",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Queued question",
        command="prompt",
      ),
    ],
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "Queued question",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
  }
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 1)
  match items[0].message {
    Some(row) => assert_eq(row.content, "Queued question")
    None => fail("expected queued user prompt")
  }
}

///|
test "code mode acknowledged multi prompt session stays prompt-only without runtime signal" {
  let session = {
    ..code_mode_test_session("session-a", status="queued"),
    mooncode_events: [
      code_mode_test_event(
        "prompt-one",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First durable question",
        command="prompt",
      ),
      code_mode_test_event(
        "prompt-two",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Second durable question",
        command="prompt",
      ),
    ],
  }
  let items = mooncode_transcript_items(
    { ..init_model(), selected_mooncode_session_id: "session-a" },
    session,
  )
  assert_eq(items.length(), 2)
  match items[0].message {
    Some(row) => assert_eq(row.content, "First durable question")
    None => fail("expected first durable prompt")
  }
  match items[1].message {
    Some(row) => assert_eq(row.content, "Second durable question")
    None => fail("expected second durable prompt")
  }
}

///|
test "code mode paired prompt transcript and command events render once" {
  let session = {
    ..code_mode_test_session("session-a", status="queued"),
    mooncode_events: [
      code_mode_test_event(
        "user-one",
        title="User prompt",
        lane="transcript",
        kind="user",
        status="queued",
        detail="First visible question",
        created_at="100",
      ),
      code_mode_test_event(
        "user-two",
        title="User prompt",
        lane="transcript",
        kind="user",
        status="queued",
        detail="Second visible question",
        created_at="200",
      ),
      code_mode_test_event(
        "command-one",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First visible question",
        command="prompt",
        created_at="101",
      ),
      code_mode_test_event(
        "command-two",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Second visible question",
        command="prompt",
        created_at="201",
      ),
    ],
  }
  let items = mooncode_transcript_items(
    { ..init_model(), selected_mooncode_session_id: "session-a" },
    session,
  )
  assert_eq(items.length(), 2)
  match items[0].message {
    Some(row) => assert_eq(row.content, "First visible question")
    None => fail("expected first visible prompt")
  }
  match items[1].message {
    Some(row) => assert_eq(row.content, "Second visible question")
    None => fail("expected second visible prompt")
  }
}

test "code mode transcript hides acknowledged local prompts in pending event tail" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "prompt-first",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First prompt",
        command="prompt",
      ),
      code_mode_test_event(
        "finish-first",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "First answer",
        }),
      ),
      code_mode_test_event(
        "prompt-second",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Second prompt",
        command="prompt",
      ),
      code_mode_test_event(
        "finish-second",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Second answer",
        }),
      ),
    ],
  }
  let model = {
    ..init_model(),
    mooncode_conversation_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "First prompt",
        status: "queued",
        key: "ui-user:session-a:0",
      },
      {
        session_id: "session-a",
        role: "user",
        content: "Second prompt",
        status: "queued",
        key: "ui-user:session-a:1",
      },
    ],
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "Second prompt",
        status: "queued",
        after_row_count: 2,
        after_event_count: 0,
      },
    ],
  }
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 4)
  match items[0].message {
    Some(row) => assert_eq(row.content, "First prompt")
    None => fail("expected first durable prompt")
  }
  match items[1].message {
    Some(row) => assert_eq(row.content, "First answer")
    None => fail("expected first answer")
  }
  match items[2].message {
    Some(row) => assert_eq(row.content, "Second prompt")
    None => fail("expected second durable prompt")
  }
  match items[3].message {
    Some(row) => assert_eq(row.content, "Second answer")
    None => fail("expected second answer")
  }
}

///|
test "code mode transcript drops duplicated optimistic user prefix" {
  let items = [
    mooncode_transcript_message_item({
      role: "user",
      content: "First prompt",
      status: "queued",
    }),
    mooncode_transcript_message_item({
      role: "user",
      content: "Second prompt",
      status: "queued",
    }),
    mooncode_transcript_message_item({
      role: "user",
      content: "First prompt",
      status: "queued",
    }),
    mooncode_transcript_message_item({
      role: "assistant",
      content: "First answer",
      status: "done",
    }),
    mooncode_transcript_message_item({
      role: "user",
      content: "Second prompt",
      status: "queued",
    }),
    mooncode_transcript_message_item({
      role: "assistant",
      content: "Second answer",
      status: "done",
    }),
  ]
  let cleaned = mooncode_drop_duplicated_user_prompt_prefix(items)
  assert_eq(cleaned.length(), 4)
  match cleaned[0].message {
    Some(row) => assert_eq(row.content, "First prompt")
    None => fail("expected first durable prompt")
  }
  match cleaned[1].message {
    Some(row) => assert_eq(row.content, "First answer")
    None => fail("expected first answer")
  }
  match cleaned[2].message {
    Some(row) => assert_eq(row.content, "Second prompt")
    None => fail("expected second durable prompt")
  }
  match cleaned[3].message {
    Some(row) => assert_eq(row.content, "Second answer")
    None => fail("expected second answer")
  }
}

///|
test "code mode transcript puts early thinking under pending prompt" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "old-prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Old question",
        command="prompt",
      ),
      code_mode_test_event(
        "old-finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Old answer",
        }),
      ),
      code_mode_test_event(
        "early-thinking",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Inspecting now.",
      ),
    ],
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
      [],
      "session-a",
      "New question",
    ),
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "New question",
        status: "queued",
        after_row_count: 2,
        after_event_count: 2,
      },
    ],
  }
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 4)
  match items[2].message {
    Some(row) => assert_eq(row.content, "New question")
    None => fail("expected pending prompt before thinking")
  }
  match items[3].activity {
    Some(row) => {
      assert_eq(row.label, "Working")
      assert_eq(row.detail, "Inspecting now.")
    }
    None => fail("expected thinking after pending prompt")
  }
}

///|
test "code mode transcript folds first-turn thinking after answer arrives" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="First question",
        command="prompt",
      ),
      code_mode_test_event(
        "thinking",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Inspecting before replying.",
      ),
      code_mode_test_event(
        "finish",
        title="MoonCode tool `finish` completed",
        lane="review",
        kind="finish",
        status="done",
        detail="finished",
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "First answer",
        }),
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 3)
  match items[0].message {
    Some(row) => {
      assert_eq(row.role, "user")
      assert_eq(row.content, "First question")
    }
    None => fail("expected user message")
  }
  match items[1].activity {
    Some(row) => {
      assert_eq(row.label, "Progress")
      assert_eq(row.detail, "Inspecting before replying.")
      assert_eq(row.folded, true)
    }
    None => fail("expected folded thinking")
  }
  match items[2].message {
    Some(row) => {
      assert_eq(row.role, "assistant")
      assert_eq(row.content, "First answer")
    }
    None => fail("expected assistant answer")
  }
}

///|
test "code mode transcript does not move old activity onto pending prompt" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "old-prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Old question",
        command="prompt",
      ),
      code_mode_test_event(
        "old-thinking",
        title="MoonCode planner step 1",
        lane="runtime",
        kind="reasoning_delta",
        status="running",
        detail="Old thinking.",
      ),
    ],
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
      [],
      "session-a",
      "New question",
    ),
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "New question",
        status: "queued",
        after_row_count: 2,
        after_event_count: 2,
      },
    ],
  }
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 3)
  match items[1].activity {
    Some(row) => assert_eq(row.detail, "Old thinking.")
    None => fail("expected old activity before pending prompt")
  }
  match items[2].message {
    Some(row) => assert_eq(row.content, "New question")
    None => fail("expected pending prompt after old activity")
  }
}

///|
test "code mode stream appends assistant after ui prompt row" {
  let prompt_row : MoonCodeConversationRow = {
    session_id: "session-a",
    role: "user",
    content: "Question",
    status: "queued",
    key: "ui-user:session-a:0",
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: [prompt_row],
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeStream(
      "session-a",
      Ok({
        stream: "events",
        stream_source: "disk",
        next_since: 2,
        emitted_count: 1,
        events: [
          code_mode_test_event(
            "finish",
            title="MoonCode tool `finish` completed",
            lane="review",
            kind="finish",
            status="done",
            detail="finished",
            tool_result=Some({
              "tool": "finish",
              "ok": true,
              "output": "Answer",
            }),
          ),
        ],
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_conversation_rows.length(), 2)
  assert_eq(next.mooncode_conversation_rows[0].role, "user")
  assert_eq(next.mooncode_conversation_rows[0].content, "Question")
  assert_eq(next.mooncode_conversation_rows[1].role, "assistant")
  assert_eq(next.mooncode_conversation_rows[1].content, "Answer")
}

///|
test "code mode transcript hydrates assistant after durable prompt row" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_events: [
      code_mode_test_event(
        "native-assistant",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="Durable answer",
        created_at="1782827303151",
      ),
      code_mode_test_event(
        "native-turn-done",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
        created_at="1782827303152",
      ),
      code_mode_test_event(
        "durable-prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Durable question",
        command="prompt",
        created_at="1782827300809",
      ),
    ],
  }
  let rows = mooncode_transcript_rows(init_model(), session)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Durable question")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "Durable answer")
}

///|
test "code mode runtime sink hydrates append only conversation rows" {
  let model = { ..init_model(), selected_mooncode_session_id: "session-a" }
  let (_, next) = update_mooncode_stream_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 3,
        events: [
          code_mode_test_event(
            "native-assistant",
            title="MoonCode assistant update",
            lane="transcript",
            kind="assistant_delta",
            status="running",
            detail="Sink answer",
            created_at="1782827303151",
          ),
          code_mode_test_event(
            "native-turn-done",
            title="MoonCode native runtime turn completed",
            lane="runtime",
            kind="runtime.turn_finished",
            status="done",
            detail="MoonClaw native runtime turn executed 1 tool call(s).",
            created_at="1782827303152",
          ),
          code_mode_test_event(
            "durable-prompt",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="Sink question",
            command="prompt",
            created_at="1782827300809",
          ),
        ],
        runtime_service: { status: "idle" },
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_conversation_rows.length(), 2)
  assert_eq(next.mooncode_conversation_rows[0].role, "user")
  assert_eq(next.mooncode_conversation_rows[0].content, "Sink question")
  assert_eq(next.mooncode_conversation_rows[1].role, "assistant")
  assert_eq(next.mooncode_conversation_rows[1].content, "Sink answer")
}

///|
test "code mode runtime sink acknowledges optimistic prompts without duplicates" {
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "First prompt",
        status: "queued",
        key: "ui-user:session-a:0",
      },
      {
        session_id: "session-a",
        role: "user",
        content: "Second prompt",
        status: "queued",
        key: "ui-user:session-a:1",
      },
    ],
  }
  let (_, next) = update_mooncode_stream_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 4,
        events: [
          code_mode_test_event(
            "prompt-first",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="First prompt",
            command="prompt",
          ),
          code_mode_test_event(
            "finish-first",
            title="MoonCode tool `finish` completed",
            lane="review",
            kind="finish",
            status="done",
            detail="finished",
            tool_result=Some({
              "tool": "finish",
              "ok": true,
              "output": "First answer",
            }),
          ),
          code_mode_test_event(
            "prompt-second",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="Second prompt",
            command="prompt",
          ),
          code_mode_test_event(
            "finish-second",
            title="MoonCode tool `finish` completed",
            lane="review",
            kind="finish",
            status="done",
            detail="finished",
            tool_result=Some({
              "tool": "finish",
              "ok": true,
              "output": "Second answer",
            }),
          ),
        ],
        runtime_service: { status: "idle" },
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_conversation_rows.length(), 4)
  assert_eq(next.mooncode_conversation_rows[0].role, "user")
  assert_eq(next.mooncode_conversation_rows[0].content, "First prompt")
  assert_eq(next.mooncode_conversation_rows[1].role, "assistant")
  assert_eq(next.mooncode_conversation_rows[1].content, "First answer")
  assert_eq(next.mooncode_conversation_rows[2].role, "user")
  assert_eq(next.mooncode_conversation_rows[2].content, "Second prompt")
  assert_eq(next.mooncode_conversation_rows[3].role, "assistant")
  assert_eq(next.mooncode_conversation_rows[3].content, "Second answer")
}

///|
test "code mode runtime sink keeps final answer emitted before prompt record" {
  let model = { ..init_model(), selected_mooncode_session_id: "session-a" }
  let (_, next) = update_mooncode_stream_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 2,
        events: [
          code_mode_test_event(
            "finish-a",
            title="MoonCode tool `finish` completed",
            lane="review",
            kind="finish",
            status="done",
            detail="finished",
            created_at="1782827303151",
            tool_result=Some({
              "tool": "finish",
              "ok": true,
              "output": "Sink final answer.",
            }),
          ),
          code_mode_test_event(
            "durable-prompt",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="Sink final question",
            command="prompt",
            created_at="1782827300809",
          ),
        ],
        runtime_service: { status: "idle" },
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_conversation_rows.length(), 2)
  assert_eq(next.mooncode_conversation_rows[0].role, "user")
  assert_eq(next.mooncode_conversation_rows[0].content, "Sink final question")
  assert_eq(next.mooncode_conversation_rows[1].role, "assistant")
  assert_eq(next.mooncode_conversation_rows[1].status, "done")
  assert_eq(next.mooncode_conversation_rows[1].content, "Sink final answer.")
}

///|
test "code mode final answer replaces running assistant delta row" {
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "Question",
        status: "queued",
        key: "ui-user:session-a:0",
      },
      {
        session_id: "session-a",
        role: "assistant",
        content: "Partial",
        status: "running",
        key: "assistant-delta:session-a:1",
      },
    ],
  }
  let (_, next) = update_mooncode_stream_results(
    code_mode_test_dispatch,
    LoadedMoonCodeStream(
      "session-a",
      Ok({
        stream: "events",
        stream_source: "moonclaw",
        next_since: 3,
        emitted_count: 1,
        events: [
          code_mode_test_event(
            "finish",
            title="MoonCode tool `finish` completed",
            lane="review",
            kind="finish",
            status="done",
            detail="finished",
            tool_result=Some({
              "tool": "finish",
              "ok": true,
              "output": "Partial final answer.",
            }),
          ),
        ],
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_conversation_rows.length(), 2)
  assert_eq(next.mooncode_conversation_rows[0].role, "user")
  assert_eq(next.mooncode_conversation_rows[1].role, "assistant")
  assert_eq(next.mooncode_conversation_rows[1].status, "done")
  assert_eq(next.mooncode_conversation_rows[1].content, "Partial final answer.")
}

///|
test "code mode command result keeps pending prompt until durable prompt event arrives" {
  let session = code_mode_test_session("session-a", status="running")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "Stable order please",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    CompletedMoonCodeCommand(Ok(session)),
    model,
  )
  assert_eq(next.mooncode_pending_prompts.length(), 1)
  assert_eq(next.mooncode_pending_prompts[0].content, "Stable order please")
}

///|
test "code mode runtime prompt event clears matching pending prompt" {
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "Stable order please",
        status: "queued",
        after_row_count: 0,
        after_event_count: 0,
      },
    ],
  }
  let prompt_event = code_mode_test_event(
    "prompt-event",
    title="Prompt: queued",
    kind="command.prompt",
    status="queued",
    detail="Stable order please",
    command="prompt",
  )
  let (_, next) = update_mooncode_stream_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 1,
        events: [prompt_event],
        runtime_service: { status: "running" },
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_pending_prompts.length(), 0)
}

///|
test "code mode runtime prompt event clears pending prompt by client turn id" {
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "client-turn-2",
        content: "Same text",
        status: "queued",
        after_row_count: 1,
        after_event_count: 1,
      },
    ],
  }
  let first_prompt_event = code_mode_test_event(
    "prompt-event-1",
    title="Prompt: queued",
    kind="command.prompt",
    status="queued",
    detail="Same text",
    command="prompt",
    command_packet=Some({ "client_turn_id": "client-turn-1" }),
  )
  let (_, after_first_event) = update_mooncode_stream_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 1,
        events: [first_prompt_event],
        runtime_service: { status: "running" },
      }),
    ),
    model,
  )
  assert_eq(after_first_event.mooncode_pending_prompts.length(), 1)
  let second_prompt_event = code_mode_test_event(
    "prompt-event-2",
    title="Prompt: queued",
    kind="command.prompt",
    status="queued",
    detail="Same text",
    command="prompt",
    command_packet=Some({ "client_turn_id": "client-turn-2" }),
  )
  let (_, after_second_event) = update_mooncode_stream_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 2,
        events: [first_prompt_event, second_prompt_event],
        runtime_service: { status: "running" },
      }),
    ),
    after_first_event,
  )
  assert_eq(after_second_event.mooncode_pending_prompts.length(), 0)
}

///|
test "code mode new session draft is not replaced by existing sessions" {
  let session = code_mode_test_session("existing")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "",
    mooncode_sessions: [session],
    mooncode_composer_status: "new session draft",
  }
  assert_true(selected_mooncode_session(model) is None)
  let with_prompt = { ..model, mooncode_composer_status: "draft" }
  assert_true(selected_mooncode_session(with_prompt) is None)
  let with_validation = { ..model, mooncode_composer_status: "enter a message" }
  assert_true(selected_mooncode_session(with_validation) is None)
}

///|
test "code mode session polling preserves new session draft" {
  let session = code_mode_test_session("existing")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "",
    mooncode_prompt: "draft prompt",
    mooncode_composer_status: "draft",
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "")
  assert_eq(next.mooncode_prompt, "draft prompt")
  assert_eq(next.mooncode_composer_status, "draft")
  assert_true(selected_mooncode_session(next) is None)
}

///|
test "code mode typed new session draft survives overwritten status" {
  let session = code_mode_test_session("existing")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "",
    mooncode_sessions: [session],
    mooncode_prompt: "h",
    mooncode_composer_status: "daemon temporarily unavailable",
  }
  assert_true(mooncode_new_session_draft_active(model))
  assert_true(selected_mooncode_session(model) is None)
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "")
  assert_eq(next.mooncode_prompt, "h")
  assert_true(selected_mooncode_session(next) is None)
}

///|
test "code mode background errors do not kick typed draft into existing chat" {
  let session = code_mode_test_session("existing")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "",
    mooncode_sessions: [session],
    mooncode_prompt: "hello",
    mooncode_composer_status: "draft",
  }
  let (_, daemon_error) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonClawDaemon(Err("daemon down")),
    model,
  )
  assert_eq(daemon_error.mooncode_composer_status, "draft")
  assert_true(selected_mooncode_session(daemon_error) is None)
  let (_, model_error) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonClawModels(Err("models down")),
    daemon_error,
  )
  assert_eq(model_error.mooncode_composer_status, "draft")
  assert_true(selected_mooncode_session(model_error) is None)
  let (_, sessions_error) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Err("sessions down")),
    model_error,
  )
  assert_eq(sessions_error.mooncode_composer_status, "draft")
  assert_true(selected_mooncode_session(sessions_error) is None)
  let (_, refreshed) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    sessions_error,
  )
  assert_eq(refreshed.selected_mooncode_session_id, "")
  assert_eq(refreshed.mooncode_prompt, "hello")
  assert_true(selected_mooncode_session(refreshed) is None)
}

///|
test "code mode session polling preserves hydrated conversation from compact listing" {
  let hydrated = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "prompt-a",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Keep this prompt",
        command="prompt",
      ),
      code_mode_test_event(
        "assistant-a",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="Keep this answer",
      ),
      code_mode_test_event(
        "turn-a",
        title="MoonCode native runtime turn completed",
        lane="runtime",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
      ),
    ],
  }
  let compact = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [],
    transcript: [],
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [hydrated],
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([compact])),
    model,
  )
  let session = selected_mooncode_session(next).unwrap()
  assert_eq(session.mooncode_events.length(), 3)
  let rows = mooncode_transcript_rows(next, session)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].content, "Keep this prompt")
  assert_eq(rows[1].content, "Keep this answer")
}

///|
test "code mode daemon and model polling preserve new session draft" {
  let session = code_mode_test_session("existing")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "",
    mooncode_sessions: [session],
    mooncode_composer_status: "new session draft",
  }
  let (_, daemon_next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonClawDaemon(
      Ok({ running: true, port: 1515, message: "daemon running" }),
    ),
    model,
  )
  assert_eq(daemon_next.selected_mooncode_session_id, "")
  assert_eq(daemon_next.mooncode_composer_status, "new session draft")
  assert_true(selected_mooncode_session(daemon_next) is None)

  let (_, models_next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonClawModels(
      Ok({
        ok: true,
        daemon: { running: true, port: 1515, message: "daemon running" },
        models: [{ name: "deepseek-v4-flash" }],
      }),
    ),
    model,
  )
  assert_eq(models_next.selected_mooncode_session_id, "")
  assert_eq(models_next.mooncode_model, "deepseek-v4-flash")
  assert_eq(models_next.mooncode_composer_status, "new session draft")
  assert_true(selected_mooncode_session(models_next) is None)
}

///|
test "code mode labels no-book state as general chat" {
  let model = { ..init_model(), selected_workspace_id: "" }
  assert_eq(mooncode_workspace_label(model), "General chat")
}

///|
test "code mode enables web search by default" {
  assert_true(init_model().mooncode_web_search)
}

///|
test "code mode model polling defaults empty model list to codex runtime model" {
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonClawModels(
      Ok({
        ok: true,
        daemon: { running: true, port: 1515, message: "daemon running" },
        models: [],
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_model, "codex/gpt-5.4")
}

///|
test "code mode command payload model falls back to codex runtime model" {
  let empty_session = { ..code_mode_test_session("session-a"), model: "" }
  assert_eq(
    mooncode_selected_runtime_model(init_model(), Some(empty_session)),
    "codex/gpt-5.4",
  )
  assert_eq(
    mooncode_selected_runtime_model(
      { ..init_model(), mooncode_model: "deepseek-v4-flash" },
      Some(empty_session),
    ),
    "deepseek-v4-flash",
  )
}

///|
test "code mode empty composer is rejected before creating a session" {
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Search,
    command_open: true,
    mooncode_prompt: " \n\t ",
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage,
    model,
  )
  assert_true(next.workspace_mode is MoonCode)
  assert_true(next.activity is Search)
  assert_false(next.command_open)
  assert_eq(next.mooncode_composer_status, "enter a message")
  assert_eq(next.selected_mooncode_session_id, "")
}

///|
test "code mode composer chooses steer only for running runtime service" {
  let model = { ..init_model(), mooncode_prompt: "continue" }
  assert_eq(
    mooncode_composer_action(model, code_mode_test_session("idle")),
    "prompt",
  )
  assert_eq(
    mooncode_composer_action(
      model,
      code_mode_test_session("running", status="running"),
    ),
    "prompt",
  )
  assert_eq(
    mooncode_composer_action(
      model,
      code_mode_test_session("queued", status="queued"),
    ),
    "prompt",
  )
  assert_eq(
    mooncode_composer_action(
      model,
      code_mode_test_session("queued-count", queued_count=2),
    ),
    "prompt",
  )
  let running_service = {
    ..model,
    mooncode_runtime_event_sink_session_id: "running",
    mooncode_runtime_event_sink: Some({
      event_count: 1,
      events: [code_mode_test_event("runtime-service-started")],
      runtime_service: { status: "running" },
    }),
  }
  assert_eq(
    mooncode_composer_action(
      running_service,
      code_mode_test_session("running", status="running"),
    ),
    "steer",
  )
}

///|
test "code mode created session selects session clears prompt and reloads streams" {
  let session = code_mode_test_session("session-a")
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Inbox,
    selected_workspace_id: "book-demo",
    selected_path: "tools/parser.mbt",
    mooncode_prompt: "add parser tests",
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    CreatedMoonCodeSession(Ok(session)),
    model,
  )
  assert_true(next.workspace_mode is MoonCode)
  assert_true(next.activity is Inbox)
  assert_eq(next.selected_mooncode_session_id, "session-a")
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_composer_status, "MoonCode session started")
}

///|
test "code mode session listing prefers selected session and preserves matching stream state" {
  let session = code_mode_test_session("session-a")
  let sink = {
    event_count: 1,
    events: [code_mode_test_event("event-a")],
    runtime_service: { status: "idle" },
  }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "session-a",
    mooncode_stream_session_id: "session-a",
    mooncode_stream_cursor: 7,
    mooncode_stream_events: [code_mode_test_event("stream-a")],
    mooncode_stream_status: "live tail / disk / events +1 event(s), cursor 7",
    mooncode_stream_checkpoint_session_id: "session-a",
    mooncode_stream_checkpoint_status: "ui checkpoint 7 / latest 7",
    mooncode_runtime_event_sink_session_id: "session-a",
    mooncode_runtime_event_sink: Some(sink),
    mooncode_runtime_event_sink_status: "1 runtime event(s)",
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "session-a")
  assert_eq(next.mooncode_stream_session_id, "session-a")
  assert_eq(next.mooncode_stream_cursor, 7)
  assert_eq(next.mooncode_stream_events.length(), 1)
  assert_eq(next.mooncode_stream_checkpoint_session_id, "session-a")
  assert_eq(next.mooncode_runtime_event_sink_session_id, "session-a")
  assert_true(next.mooncode_runtime_event_sink is Some(_))
  assert_eq(next.mooncode_composer_status, "1 MoonCode session(s)")
}

///|
test "code mode session listing resets stale stream state when selection changes" {
  let session = code_mode_test_session("session-b")
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "missing-session",
    mooncode_stream_session_id: "missing-session",
    mooncode_stream_cursor: 12,
    mooncode_stream_events: [code_mode_test_event("stale")],
    mooncode_stream_status: "stale stream",
    mooncode_stream_checkpoint_session_id: "missing-session",
    mooncode_stream_checkpoint_status: "stale checkpoint",
    mooncode_runtime_event_sink_session_id: "missing-session",
    mooncode_runtime_event_sink: Some({
      event_count: 1,
      events: [code_mode_test_event("stale-runtime")],
      runtime_service: { status: "running" },
    }),
    mooncode_runtime_event_sink_status: "stale runtime events",
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "session-b")
  assert_eq(next.mooncode_stream_session_id, "")
  assert_eq(next.mooncode_stream_cursor, 0)
  assert_eq(next.mooncode_stream_events.length(), 0)
  assert_eq(next.mooncode_stream_status, "stream cursor reset")
  assert_eq(next.mooncode_stream_checkpoint_session_id, "")
  assert_eq(next.mooncode_stream_checkpoint_status, "checkpoint idle")
  assert_eq(next.mooncode_runtime_event_sink_session_id, "")
  assert_true(next.mooncode_runtime_event_sink is None)
  assert_eq(next.mooncode_runtime_event_sink_status, "loading runtime events")
}

///|
test "code mode stream poll ignores stale sessions and merges selected events" {
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_stream_session_id: "session-a",
    mooncode_stream_cursor: 1,
    mooncode_stream_events: [code_mode_test_event("event-a")],
  }
  let (_, stale) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeStream(
      "session-b",
      Ok({
        stream: "events",
        stream_source: "disk",
        next_since: 2,
        emitted_count: 1,
        events: [code_mode_test_event("event-b")],
      }),
    ),
    model,
  )
  assert_eq(stale.mooncode_stream_cursor, 1)
  assert_eq(stale.mooncode_stream_events.length(), 1)

  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeStream(
      "session-a",
      Ok({
        stream: "events",
        stream_source: "disk",
        next_since: 3,
        emitted_count: 2,
        events: [
          code_mode_test_event("event-a", title="duplicate"),
          code_mode_test_event("event-c"),
        ],
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_stream_session_id, "session-a")
  assert_eq(next.mooncode_stream_cursor, 3)
  assert_eq(next.mooncode_stream_events.length(), 2)
  assert_eq(next.mooncode_stream_events[0].id, "event-a")
  assert_eq(next.mooncode_stream_events[1].id, "event-c")
  assert_eq(next.mooncode_stream_checkpoint_session_id, "session-a")
  assert_eq(next.mooncode_stream_checkpoint_status, "saving checkpoint 3")
}

///|
test "code mode stream parser accepts numeric MoonClaw event timestamps" {
  let text =
    #|{
    #|  "type": "event",
    #|  "event": {
    #|    "id": "finish-1",
    #|    "command_id": "cmd-flat",
    #|    "lane": "review",
    #|    "kind": "finish",
    #|    "title": "MoonCode tool `finish` completed",
    #|    "status": "done",
    #|    "detail": "finished",
    #|    "created_at": 1782824149398,
    #|    "tool": "finish",
    #|    "tool_name": "finish",
    #|    "tool_result": {
    #|      "tool": "finish",
    #|      "ok": true,
    #|      "output": "Final answer"
    #|    }
    #|  }
    #|}
    #|{
    #|  "type": "done",
    #|  "next_since": 9,
    #|  "emitted_count": 1,
    #|  "stream_source": "moonclaw"
    #|}
  match parse_mooncode_stream_text(text) {
    Ok(stream) => {
      assert_eq(stream.next_since, 9)
      assert_eq(stream.events.length(), 1)
      assert_eq(stream.events[0].id, "finish-1")
      assert_eq(stream.events[0].created_at, "1782824149398")
      assert_true(stream.events[0].command_id is Some("cmd-flat"))
      assert_true(stream.events[0].tool is Some("finish"))
      assert_true(stream.events[0].tool_name is Some("finish"))
      assert_eq(stream.events[0].tool_result is Some(_), true)
    }
    Err(error) => fail("expected parsed stream, got \{error}")
  }
}

///|
test "code mode stream parser preserves nested command packet id" {
  let text =
    #|{
    #|  "type": "event",
    #|  "event": {
    #|    "id": "tool-1",
    #|    "lane": "tool",
    #|    "kind": "tool_result",
    #|    "title": "Tool finished",
    #|    "status": "done",
    #|    "detail": "ok",
    #|    "created_at": "2026-06-30T00:00:00Z",
    #|    "command_packet": {
    #|      "command_id": "cmd-nested",
    #|      "action": "prompt"
    #|    }
    #|  }
    #|}
  match parse_mooncode_stream_text(text) {
    Ok(stream) => {
      assert_eq(stream.events.length(), 1)
      assert_true(stream.events[0].command_id is Some("cmd-nested"))
      match stream.events[0].command_packet {
        Some(packet) =>
          assert_eq(
            json_string_value(packet, "command_id", default=""),
            "cmd-nested",
          )
        None => fail("expected command packet")
      }
    }
    Err(error) => fail("expected parsed stream, got \{error}")
  }
}

///|
test "code mode stream parser renders package assistant blocks inline" {
  let text =
    #|{"type":"assistant","id":"package-message","message":{"role":"assistant","content":[{"type":"thinking","thinking":"Need inspect the repo first."},{"type":"tool_use","id":"tool-bash","name":"Bash","input":{"command":"moon test internal/mooncode","description":"Run MoonCode tests"}},{"type":"tool_result","tool_use_id":"tool-bash","content":"Total tests: 256, passed: 256"},{"type":"text","text":"The tests pass."}]}}
    #|{"type":"done","next_since":4,"emitted_count":4,"stream_source":"moonclaw"}
  match parse_mooncode_stream_text(text) {
    Ok(stream) => {
      assert_eq(stream.events.length(), 4)
      assert_eq(stream.events[0].kind, "reasoning_delta")
      assert_eq(stream.events[0].detail, "Need inspect the repo first.")
      assert_eq(stream.events[1].kind, "tool_call")
      assert_eq(stream.events[1].lane, "test")
      assert_eq(stream.events[1].command, "moon test internal/mooncode")
      assert_eq(stream.events[2].kind, "tool_result")
      assert_eq(stream.events[2].status, "done")
      match stream.events[2].tool_result {
        Some(result) =>
          assert_eq(json_string_value(result, "tool", default=""), "Bash")
        None => fail("expected tool result payload")
      }
      assert_eq(stream.events[3].kind, "assistant_delta")
      assert_eq(stream.events[3].detail, "The tests pass.")
      let session = {
        ..code_mode_test_session("session-package", status="running"),
        mooncode_events: [
          code_mode_test_event(
            "prompt",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="Run package-style tests",
            command="prompt",
          ),
          ..stream.events,
        ],
      }
      let items = mooncode_transcript_items(init_model(), session)
      assert_eq(items.length(), 5)
      match items[0].message {
        Some(row) => assert_eq(row.content, "Run package-style tests")
        None => fail("expected prompt message")
      }
      match items[1].activity {
        Some(row) => {
          assert_eq(row.label, "Progress")
          assert_eq(row.detail, "Need inspect the repo first.")
          assert_eq(row.folded, true)
        }
        None => fail("expected folded thinking activity")
      }
      match items[2].activity {
        Some(row) => {
          assert_eq(row.label, "Running tests")
          assert_eq(row.title, "Run MoonCode tests")
        }
        None => fail("expected command activity")
      }
      match items[3].activity {
        Some(row) => assert_eq(row.label, "Completed")
        None => fail("expected result activity")
      }
      match items[4].message {
        Some(row) => assert_eq(row.content, "The tests pass.")
        None => fail("expected assistant message")
      }
    }
    Err(error) => fail("expected parsed package stream, got \{error}")
  }
}

///|
test "code mode stream parser preserves package object tool results" {
  let text =
    #|{"type":"assistant","id":"package-object-result","message":{"role":"assistant","content":[{"type":"thinking","thinking":"Read the file before editing."},{"type":"tool_use","id":"tool-read","name":"Read","input":{"file_path":"src/main.mbt"}},{"type":"tool_result","tool_use_id":"tool-read","content":{"type":"text","file":{"filePath":"src/main.mbt","content":"raw file body should stay hidden","numLines":4,"startLine":1,"totalLines":20}}},{"type":"text","text":"I found the entry point."}]}}
    #|{"type":"done","next_since":4,"emitted_count":4,"stream_source":"moonclaw"}
  match parse_mooncode_stream_text(text) {
    Ok(stream) => {
      assert_eq(stream.events.length(), 4)
      assert_eq(stream.events[2].kind, "tool_result")
      assert_true(stream.events[2].detail.has_prefix("{"))
      let session = {
        ..code_mode_test_session("session-package-object", status="running"),
        mooncode_events: [
          code_mode_test_event(
            "prompt",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="Read src/main.mbt",
            command="prompt",
          ),
          ..stream.events,
        ],
      }
      let items = mooncode_transcript_items(init_model(), session)
      assert_eq(items.length(), 5)
      match items[1].activity {
        Some(row) => {
          assert_eq(row.label, "Progress")
          assert_eq(row.detail, "Read the file before editing.")
          assert_eq(row.folded, true)
        }
        None => fail("expected folded thinking activity")
      }
      match items[3].activity {
        Some(row) => {
          assert_eq(row.label, "Completed")
          assert_eq(row.title, "Reading file")
          assert_eq(row.detail, "Read 4 line(s) from src/main.mbt.")
        }
        None => fail("expected summarized tool result")
      }
      match items[4].message {
        Some(row) => assert_eq(row.content, "I found the entry point.")
        None => fail("expected assistant message")
      }
    }
    Err(error) => fail("expected parsed package stream, got \{error}")
  }
}

///|
test "code mode activity rows summarize package structured tool results" {
  let session = {
    ..code_mode_test_session("session-package", status="running"),
    mooncode_events: [
      code_mode_test_event(
        "prompt",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="Read and edit package-style files",
        command="prompt",
      ),
      code_mode_test_event(
        "file-read-result",
        title="Tool finished",
        lane="tool",
        kind="tool_result",
        status="done",
        detail="",
        tool_result=Some({
          "tool": "Read",
          "output": "{\"type\":\"text\",\"file\":{\"filePath\":\"src/main.mbt\",\"content\":\"raw file body should stay hidden\",\"numLines\":12,\"startLine\":1,\"totalLines\":80}}",
        }),
      ),
      code_mode_test_event(
        "file-edit-result",
        title="Tool finished",
        lane="tool",
        kind="tool_result",
        status="done",
        detail="",
        tool_result=Some({
          "tool": "Edit",
          "output": "{\"filePath\":\"src/main.mbt\",\"oldString\":\"before\",\"newString\":\"after\",\"originalFile\":\"raw original file should stay hidden\",\"structuredPatch\":[],\"userModified\":false,\"replaceAll\":false,\"gitDiff\":{\"filename\":\"src/main.mbt\",\"status\":\"modified\",\"additions\":4,\"deletions\":2,\"changes\":6,\"patch\":\"raw diff should stay hidden\"}}",
        }),
      ),
      code_mode_test_event(
        "web-search-result",
        title="Tool finished",
        lane="tool",
        kind="tool_result",
        status="done",
        detail="",
        tool_result=Some({
          "tool": "WebSearch",
          "output": "{\"query\":\"moonbit docs\",\"results\":[{\"tool_use_id\":\"web-1\",\"content\":[{\"title\":\"MoonBit\",\"url\":\"https://www.moonbitlang.com\"},{\"title\":\"Docs\",\"url\":\"https://docs.moonbitlang.com\"}]}],\"durationSeconds\":1}",
        }),
      ),
      code_mode_test_event(
        "bash-result",
        title="Tool finished",
        lane="test",
        kind="tool_result",
        status="done",
        detail="",
        tool_result=Some({
          "tool": "Bash",
          "output": "{\"stdout\":\"Total tests: 445, passed: 445, failed: 0.\",\"stderr\":\"\",\"interrupted\":false}",
        }),
      ),
    ],
  }
  let items = mooncode_transcript_items(init_model(), session)
  let rows : Array[MoonCodeActivityRow] = []
  for item in items {
    match item.activity {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  assert_eq(rows.length(), 4)
  assert_eq(rows[0].title, "Reading file")
  assert_eq(rows[0].detail, "Read 12 line(s) from src/main.mbt.")
  assert_eq(rows[1].title, "Editing file")
  assert_eq(rows[1].detail, "Updated src/main.mbt (+4 -2).")
  assert_eq(rows[2].title, "Searching web")
  assert_eq(rows[2].detail, "Found 2 web result(s) for moonbit docs.")
  assert_eq(rows[3].title, "Running command")
  assert_eq(rows[3].detail, "Total tests: 445, passed: 445, failed: 0.")
}

///|
test "code mode runtime event sink reports service status only when active" {
  let model = { ..init_model(), selected_mooncode_session_id: "session-a" }
  let (_, idle) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 2,
        events: [
          code_mode_test_event("event-a"),
          code_mode_test_event("event-b"),
        ],
        runtime_service: { status: "idle" },
      }),
    ),
    model,
  )
  assert_eq(idle.mooncode_runtime_event_sink_session_id, "session-a")
  assert_eq(idle.mooncode_runtime_event_sink_status, "2 runtime event(s)")

  let (_, running) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 3,
        events: [
          code_mode_test_event("event-a"),
          code_mode_test_event("event-b"),
          code_mode_test_event("event-c"),
        ],
        runtime_service: { status: "running" },
      }),
    ),
    model,
  )
  assert_eq(
    running.mooncode_runtime_event_sink_status,
    "3 runtime event(s) / service running",
  )
}

///|
test "code mode idle runtime sink reports unanswered prompt without browser start" {
  let model = { ..init_model(), selected_mooncode_session_id: "session-a" }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 1,
        events: [
          code_mode_test_event(
            "prompt-a",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="Start service for this prompt",
            command="prompt",
          ),
        ],
        runtime_service: { status: "idle" },
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_runtime_event_sink_session_id, "session-a")
  assert_eq(next.mooncode_runtime_event_sink_status, "1 runtime event(s)")
}

///|
test "code mode idle runtime sink reports later prompt after prior turn finished" {
  let previous_sink : MoonCodeRuntimeEventSink = {
    event_count: 3,
    events: [
      code_mode_test_event(
        "first-prompt",
        command_id="cmd-first",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="first",
        command="prompt",
      ),
      code_mode_test_event(
        "first-answer",
        command_id="cmd-first",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="first answer",
      ),
      code_mode_test_event(
        "first-done",
        command_id="cmd-first",
        title="MoonCode native runtime turn completed",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
      ),
    ],
    runtime_service: { status: "idle" },
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_runtime_event_sink_session_id: "session-a",
    mooncode_runtime_event_sink: Some(previous_sink),
    mooncode_runtime_event_sink_status: "waiting for backend runtime events",
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 4,
        events: previous_sink.events +
        [
          code_mode_test_event(
            "second-prompt",
            command_id="cmd-second",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="second",
            command="prompt",
          ),
        ],
        runtime_service: { status: "idle" },
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_runtime_event_sink_session_id, "session-a")
  assert_eq(next.mooncode_runtime_event_sink_status, "4 runtime event(s)")
}

///|
test "code mode idle runtime sink reports local unanswered prompt" {
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: mooncode_append_conversation_user_prompt(
      [
        {
          session_id: "session-a",
          role: "user",
          content: "First question",
          status: "queued",
          key: "ui-user:session-a:0",
        },
        {
          session_id: "session-a",
          role: "assistant",
          content: "First answer",
          status: "done",
          key: "assistant:event:first",
        },
      ],
      "session-a",
      "Third question",
    ),
    mooncode_pending_prompts: [],
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({ event_count: 0, events: [], runtime_service: { status: "idle" } }),
    ),
    model,
  )
  assert_eq(next.mooncode_runtime_event_sink_session_id, "session-a")
  assert_eq(next.mooncode_runtime_event_sink_status, "0 runtime event(s)")
}

///|
test "code mode idle runtime sink does not start service for answered local turn" {
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_conversation_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "Question",
        status: "queued",
        key: "ui-user:session-a:0",
      },
      {
        session_id: "session-a",
        role: "assistant",
        content: "Answer",
        status: "done",
        key: "assistant:event:answer",
      },
    ],
    mooncode_pending_prompts: [],
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({ event_count: 0, events: [], runtime_service: { status: "idle" } }),
    ),
    model,
  )
  assert_eq(next.mooncode_runtime_event_sink_session_id, "session-a")
  assert_eq(next.mooncode_runtime_event_sink_status, "0 runtime event(s)")
}

///|
test "code mode running runtime sink does not restart the first active prompt" {
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_runtime_event_sink_session_id: "session-a",
    mooncode_runtime_event_sink_status: "waiting for backend runtime events",
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 2,
        events: [
          code_mode_test_event(
            "first-prompt",
            command_id="cmd-first",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="first",
            command="prompt",
            created_at="1000",
          ),
          code_mode_test_event(
            "service-start",
            command_id="service-session-a",
            title="Runtime service started",
            kind="runtime.service_started",
            status="running",
            detail="MoonClaw native runtime service is supervising queued MoonCode commands.",
            created_at="1500",
          ),
        ],
        runtime_service: { status: "running" },
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_runtime_event_sink_session_id, "session-a")
  assert_eq(
    next.mooncode_runtime_event_sink_status,
    "2 runtime event(s) / service running",
  )
}

///|
test "code mode stale running runtime sink reports later unstarted prompt" {
  let previous_sink : MoonCodeRuntimeEventSink = {
    event_count: 4,
    events: [
      code_mode_test_event(
        "first-prompt",
        command_id="cmd-first",
        title="Prompt: queued",
        kind="command.prompt",
        status="queued",
        detail="first",
        command="prompt",
        created_at="1000",
      ),
      code_mode_test_event(
        "service-start",
        command_id="service-session-a",
        title="Runtime service started",
        kind="runtime.service_started",
        status="running",
        detail="MoonClaw native runtime service is supervising queued MoonCode commands.",
        created_at="1500",
      ),
      code_mode_test_event(
        "first-answer",
        command_id="cmd-first",
        title="MoonCode assistant update",
        lane="transcript",
        kind="assistant_delta",
        status="running",
        detail="first answer",
        created_at="2000",
      ),
      code_mode_test_event(
        "first-done",
        command_id="cmd-first",
        title="MoonCode native runtime turn completed",
        kind="runtime.turn_finished",
        status="done",
        detail="MoonClaw native runtime turn executed 1 tool call(s).",
        created_at="2500",
      ),
    ],
    runtime_service: { status: "running" },
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_runtime_event_sink_session_id: "session-a",
    mooncode_runtime_event_sink: Some(previous_sink),
    mooncode_runtime_event_sink_status: "4 runtime event(s) / service running",
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeRuntimeEventSink(
      "session-a",
      Ok({
        event_count: 5,
        events: previous_sink.events +
        [
          code_mode_test_event(
            "second-prompt",
            command_id="cmd-second",
            title="Prompt: queued",
            kind="command.prompt",
            status="queued",
            detail="second",
            command="prompt",
            created_at="3000",
          ),
        ],
        runtime_service: { status: "running" },
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_runtime_event_sink_session_id, "session-a")
  assert_eq(
    next.mooncode_runtime_event_sink_status,
    "5 runtime event(s) / service running",
  )
}
