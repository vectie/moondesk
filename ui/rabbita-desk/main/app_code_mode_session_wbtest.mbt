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
