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
fn code_mode_test_transcript_rows(
  model : Model,
  session : MoonCodeSession,
) -> Array[MoonCodeTranscriptRow] {
  let rows : Array[MoonCodeTranscriptRow] = []
  for item in mooncode_transcript_items(model, session) {
    match item.message {
      Some(row) => rows.push(row)
      None => ()
    }
  }
  rows
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
  assert_eq(messages.length(), 2)
  assert_eq(messages[0], "user:Same text")
  assert_eq(messages[1], "user:Same text")
}


///|
test "code mode transcript uses local rows instead of runtime wait state" {
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
  assert_eq(code_mode_test_transcript_rows(model, session).length(), 1)
  let no_local_conversation = { ..model, mooncode_conversation_rows: [] }
  assert_eq(code_mode_test_transcript_rows(no_local_conversation, session).length(), 0)
  let with_pending = {
    ..model,
    mooncode_pending_prompts: [
      {
        session_id: "session-a",
        client_turn_id: "",
        content: "New prompt",
      },
    ],
  }
  assert_eq(code_mode_test_transcript_rows(with_pending, session).length(), 1)
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
  assert_eq(code_mode_test_transcript_rows(with_sink, session).length(), 1)
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
  let rows = code_mode_test_transcript_rows(next, session)
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
  let rows = code_mode_test_transcript_rows(next, session)
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
  let rows = code_mode_test_transcript_rows(next, session)
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
  let rows = code_mode_test_transcript_rows(next, session)
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
  let rows = code_mode_test_transcript_rows(next, session)
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
  let rows = code_mode_test_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].content, "Compact listing prompt")
  let items = mooncode_transcript_items(next, session)
  assert_eq(items.length(), 1)
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
test "code mode session polling preserves canonical conversation from compact listing" {
  let hydrated = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "turn-a",
          "Keep this prompt",
          assistant="Keep this answer",
        ),
      ]),
    ),
  }
  let compact = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_events: [],
    transcript: [],
    mooncode_conversation: None,
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
  assert_true(session.mooncode_conversation is Some(_))
  let rows = code_mode_test_transcript_rows(next, session)
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
test "code mode stream parser parses package assistant blocks as diagnostic events" {
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
    }
    Err(error) => fail("expected parsed package stream, got \{error}")
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
