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
    updated_at: "2026-06-30T00:00:00Z",
    transcript: [],
    mooncode_events: [],
    mooncode_summary: code_mode_test_summary(),
  }
}

///|
fn code_mode_test_event(
  id : String,
  title? : String = "runtime event",
  lane? : String = "runtime",
  kind? : String = "mooncode.runtime-event",
  status? : String = "ok",
  detail? : String = "",
  path? : String = "",
  diff? : String = "",
  command? : String = "",
  created_at? : String = "2026-06-30T00:00:00Z",
  exit_code? : Int = 0,
  tool_result? : Json? = None,
) -> MoonCodeEvent {
  {
    id,
    lane,
    kind,
    title,
    status,
    created_at,
    detail,
    path,
    diff,
    command,
    exit_code,
    tool_result,
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
        detail="{\"tool\":\"finish\"}",
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
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Done.",
        }),
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
  assert_eq(rows[0].label, "Thinking")
  assert_eq(rows[0].detail, "Inspect the parser before editing.")
  assert_eq(rows[0].folded, true)
  assert_eq(rows[1].label, "Checking project")
  assert_eq(rows[1].title, "moon check")
  assert_eq(rows[1].detail, "")
  assert_eq(rows[2].label, "Checked")
  assert_eq(rows[2].title, "moon check")
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
  assert_eq(rows[0].label, "Thinking")
  assert_eq(rows[0].title, "Choosing next action")
  assert_eq(rows[0].detail, "Choosing the next action.")
  assert_eq(rows[1].label, "Thinking")
  assert_eq(rows[1].title, "Selected next action")
  assert_eq(rows[1].detail, "Selected the next action.")
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
  assert_eq(rows[0].label, "Thinking")
  assert_eq(rows[0].title, "Selected next action")
  assert_eq(rows[0].detail, "Selected the next action.")
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
        tool_result=Some({
          "tool": "finish",
          "ok": true,
          "output": "Done.",
        }),
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
      assert_eq(row.label, "Thinking")
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
      assert_eq(row.label, "Thinking")
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
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "hey hows going?")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "Working on it...")
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
test "code mode transcript uses one working reply instead of runtime event dump" {
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
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Add tests")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "Working on it...")
}

///|
test "code mode transcript shows pending prompt immediately" {
  let session = code_mode_test_session("session-a", status="running")
  let rows = mooncode_transcript_rows(
    {
      ..init_model(),
      mooncode_pending_prompts: [
        {
          session_id: "session-a",
          content: "Run the tests now",
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
  assert_eq(rows[0].content, "Run the tests now")
  assert_eq(rows[1].role, "assistant")
  assert_eq(rows[1].content, "Working on it...")
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
test "code mode transcript ignores assistant-only raw transcript during live conversation" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    transcript: [
      { role: "assistant", content: "Raw assistant should not jump first", status: "done" },
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
  assert_true(next.activity is Files)
  assert_false(next.command_open)
  assert_eq(next.selected_workspace_id, "book-demo")
  assert_eq(next.selected_path, "tools/parser.mbt")
  assert_eq(next.selected_mooncode_session_id, "")
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_composer_status, "new session draft")
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
  assert_eq(next.mooncode_pending_prompts[0].content, "Explain the latest error")
  assert_eq(next.mooncode_conversation_rows.length(), 1)
  assert_eq(next.mooncode_conversation_rows[0].role, "user")
  assert_eq(next.mooncode_conversation_rows[0].content, "Explain the latest error")
  let rows = mooncode_transcript_rows(next, session)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].content, "Explain the latest error")
  assert_eq(rows[1].content, "Working on it...")
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
    Some(row) => {
      assert_eq(row.role, "user")
      assert_eq(row.content, "New question")
    }
    None => fail("expected pending user prompt")
  }
  match items[3].message {
    Some(row) => {
      assert_eq(row.role, "assistant")
      assert_eq(row.content, "Working on it...")
    }
    None => fail("expected working placeholder")
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
      assert_eq(row.label, "Thinking")
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
      assert_eq(row.label, "Thinking")
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
        content: "New question",
        status: "queued",
        after_row_count: 2,
        after_event_count: 2,
      },
    ],
  }
  let items = mooncode_transcript_items(model, session)
  assert_eq(items.length(), 4)
  match items[1].activity {
    Some(row) => assert_eq(row.detail, "Old thinking.")
    None => fail("expected old activity before pending prompt")
  }
  match items[2].message {
    Some(row) => assert_eq(row.content, "New question")
    None => fail("expected pending prompt after old activity")
  }
  match items[3].message {
    Some(row) => assert_eq(row.content, "Working on it...")
    None => fail("expected working placeholder")
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
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
  }
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
test "code mode runtime sink keeps final answer emitted before prompt record" {
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
  }
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
  assert_true(next.activity is Files)
  assert_false(next.command_open)
  assert_eq(next.mooncode_composer_status, "enter a message")
  assert_eq(next.selected_mooncode_session_id, "")
}

///|
test "code mode composer chooses prompt for idle sessions and steer for active sessions" {
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
    "steer",
  )
  assert_eq(
    mooncode_composer_action(
      model,
      code_mode_test_session("queued", status="queued"),
    ),
    "steer",
  )
  assert_eq(
    mooncode_composer_action(
      model,
      code_mode_test_session("queued-count", queued_count=2),
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
  assert_true(next.activity is Files)
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
  let text = #|{
  #|  "type": "event",
  #|  "event": {
  #|    "id": "finish-1",
  #|    "lane": "review",
  #|    "kind": "finish",
  #|    "title": "MoonCode tool `finish` completed",
  #|    "status": "done",
  #|    "detail": "finished",
  #|    "created_at": 1782824149398,
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
      assert_eq(stream.events[0].tool_result is Some(_), true)
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
        Some(result) => assert_eq(json_string_value(result, "tool", default=""), "Bash")
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
          assert_eq(row.label, "Thinking")
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
          assert_eq(row.label, "Thinking")
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
