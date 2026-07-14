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
    source: None,
    mooncode_runtime_session_id: Some("runtime-" + id),
    title: "MoonCode - " + id,
    model: "deepseek-v4-flash",
    status,
    queued_count,
    last_message: None,
    mooncode_runtime_detail: None,
    mooncode_conversation: None,
    mooncode_summary: code_mode_test_summary(),
    canonical_unchanged: None,
  }
}

///|
fn code_mode_test_watch_snapshot(
  session : MoonCodeSession,
  sequence : Int,
) -> MoonCodeWatchResponse {
  {
    kind: "moonsuite-conversation-watch",
    contract_id: "moonsuite-conversation-watch.v1",
    session_id: session.id,
    revision: mooncode_session_conversation_revision(session),
    next_sequence: sequence,
    changed: true,
    heartbeat: false,
    terminal: session.status == "done" || session.status == "failed",
    retry_after_ms: 0,
    snapshot: Some(session),
  }
}

///|
fn code_mode_test_watch_heartbeat(
  session_id : String,
  revision : Int,
  sequence : Int,
) -> MoonCodeWatchResponse {
  {
    kind: "moonsuite-conversation-watch",
    contract_id: "moonsuite-conversation-watch.v1",
    session_id,
    revision,
    next_sequence: sequence,
    changed: false,
    heartbeat: true,
    terminal: false,
    retry_after_ms: 100,
    snapshot: None,
  }
}

///|
test "failed MoonCode session explains the user state before technical evidence" {
  let session = {
    ..code_mode_test_session("session-failed", status="failed"),
    mooncode_runtime_detail: Some("MoonClaw daemon is not running"),
  }
  assert_eq(mooncode_user_state_title(session), "MoonCode couldn't start")
  assert_eq(
    mooncode_user_state_message(session),
    "Your request was saved, but no coding work ran.",
  )
  assert_eq(
    mooncode_user_state_reason(session),
    "MoonClaw daemon is not running",
  )
  assert_eq(
    mooncode_user_next_action(session),
    "Next: connect or start MoonClaw for this workspace, then send the request again.",
  )
  assert_eq(mooncode_empty_transcript_title(session), "No coding result yet")
  assert_eq(
    mooncode_empty_transcript_message(session),
    "Resolve the issue above, then send the request again.",
  )
}

///|
test "MoonCode user state remains quiet for completed sessions" {
  let session = code_mode_test_session("session-ready", status="done")
  assert_eq(mooncode_user_state_title(session), "")
  assert_eq(mooncode_user_state_message(session), "")
  assert_eq(mooncode_user_next_action(session), "")
}

///|
test "MoonCode session decodes optional runtime explanation" {
  let session : MoonCodeSession = @json.from_json({
    "id": "session-json",
    "workspace_id": "book-demo",
    "workspace_name": "Demo Book",
    "cwd": "/workspace/book",
    "title": "MoonCode - Demo Book",
    "model": "codex/gpt-5",
    "status": "failed",
    "queued_count": 0,
    "last_message": "Build the helper",
    "mooncode_runtime_detail": "MoonClaw daemon is not running",
    "mooncode_summary": {
      "event_count": 2,
      "verified_test_count": 0,
      "pending_diff_count": 0,
    },
  })
  assert_true(session.last_message is Some("Build the helper"))
  assert_true(
    session.mooncode_runtime_detail is Some("MoonClaw daemon is not running"),
  )
}

///|
test "Desk loading empty state offers a visible retry without diagnostics" {
  let loading = init_model()
  assert_eq(
    desk_empty_library_title(loading),
    "Connecting to your MoonBooks…",
  )
  assert_true(desk_empty_library_message(loading).contains("choose Refresh"))
  let empty = { ..loading, loading: false }
  assert_eq(desk_empty_library_title(empty), "No MoonBooks in this workspace")
}

///|
fn code_mode_test_conversation(
  session_id : String,
  turns : Array[MoonCodeConversationTurn],
) -> MoonCodeConversation {
  {
    kind: "mooncode-conversation",
    protocol: "mooncode.v1",
    contract_id: "moonsuite-conversation.v2",
    session_id,
    workspace_id: "book-demo",
    workspace_name: "Demo Book",
    turn_count: turns.length(),
    revision: turns.length() * 2,
    last_sequence: turns.length() * 2,
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
  steps? : Array[Json] = [],
  status? : String = "done",
) -> MoonCodeConversationTurn {
  let turn_client_id = if client_turn_id == "" { id } else { client_turn_id }
  {
    kind: "mooncode-conversation-turn",
    turn_id: id,
    client_turn_id: turn_client_id,
    command_id: id,
    ordinal: 0,
    status,
    started_at: "2026-06-30T00:00:00Z",
    updated_at: "2026-06-30T00:00:01Z",
    user: {
      "role": "user",
      "content": user,
      "status": "done",
      "command_id": id,
      "client_turn_id": turn_client_id,
    },
    work: {
      "item_id": "turn:\{id}:work",
      "status": status,
      "summary": if steps.length() > 0 {
        json_field_string(
          steps[steps.length() - 1],
          "title",
          default="Completed work",
        )
      } else {
        "Completed work"
      },
      "steps": Json::array(steps),
      "live": {},
    },
    assistant: if assistant == "" {
      Json::object({})
    } else {
      {
        "role": "assistant",
        "content": assistant,
        "status": status,
        "command_id": id,
        "client_turn_id": turn_client_id,
      }
    },
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
test "code mode transcript uses backend canonical conversation" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "First prompt",
          assistant="First answer",
          steps=[
            {
              "title": "Thinking",
              "summary": "Prepared the first answer.",
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
  match items[0].message {
    Some(row) => {
      assert_eq(row.command_id, "command-first")
      assert_eq(row.client_turn_id, "command-first")
    }
    None => fail("expected owned user message")
  }
  match items[1].activity {
    Some(row) => {
      assert_eq(row.command_id, "command-first")
      assert_eq(row.client_turn_id, "command-first")
    }
    None => fail("expected progress activity")
  }
  match items[2].message {
    Some(row) => {
      assert_eq(row.command_id, "command-first")
      assert_eq(row.client_turn_id, "command-first")
    }
    None => fail("expected owned assistant message")
  }
  assert_eq(activities.length(), 2)
  assert_eq(activities[0], "Thinking:Prepared the first answer.")
  assert_eq(activities[1], "Completed work:")
}

///|
test "code mode transcript ignores backend conversation from another session" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-b", [
        code_mode_test_turn(
          "command-wrong",
          "Wrong prompt",
          assistant="Wrong answer",
        ),
      ]),
    ),
  }
  let rows = code_mode_test_transcript_rows(init_model(), session)
  assert_eq(rows.length(), 0)
}

///|
test "code mode transcript uses canonical conversation for visible chat rows" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "Canonical prompt",
          assistant="Canonical answer",
        ),
      ]),
    ),
  }
  let model = { ..init_model(), selected_mooncode_session_id: "session-a" }
  let messages : Array[String] = []
  for item in mooncode_transcript_items(model, session) {
    match item.message {
      Some(row) => messages.push(row.role + ":" + row.content)
      None => ()
    }
  }
  assert_eq(messages.length(), 2)
  assert_eq(messages[0], "user:Canonical prompt")
  assert_eq(messages[1], "assistant:Canonical answer")
}

///|
test "code mode transcript keeps canonical progress with existing command" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "Canonical prompt",
          assistant="Canonical answer",
          steps=[
            {
              "title": "Thinking",
              "summary": "Canonical progress.",
              "status": "done",
              "command_id": "command-first",
              "client_turn_id": "command-first",
            },
          ],
        ),
      ]),
    ),
  }
  let model = { ..init_model(), selected_mooncode_session_id: "session-a" }
  let messages : Array[String] = []
  let activities : Array[String] = []
  for item in mooncode_transcript_items(model, session) {
    match item.message {
      Some(row) => messages.push(row.role + ":" + row.content)
      None =>
        match item.activity {
          Some(row) => activities.push(row.title + ":" + row.detail)
          None => ()
        }
    }
  }
  assert_eq(messages.length(), 2)
  assert_eq(messages[0], "user:Canonical prompt")
  assert_eq(messages[1], "assistant:Canonical answer")
  assert_eq(activities.length(), 1)
  assert_eq(activities[0], "Thinking:Canonical progress.")
}

///|
test "code mode canonical work stays folded between user and assistant" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "First prompt",
          assistant="First answer",
          steps=[
            {
              "title": "Reading workspace",
              "summary": "Read the workspace.",
              "status": "done",
              "command_id": "command-first",
              "client_turn_id": "command-first",
            },
          ],
        ),
      ]),
    ),
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 3)
  match items[0].message {
    Some(row) => assert_eq(row.content, "First prompt")
    None => fail("expected user message")
  }
  match items[1].activity {
    Some(row) => {
      assert_true(row.folded)
      assert_eq(row.label, "Work")
      assert_eq(row.title, "Reading workspace")
      assert_eq(row.detail, "Read the workspace.")
      assert_eq(row.command_id, "command-first")
      assert_eq(row.client_turn_id, "command-first")
    }
    None => fail("expected progress activity")
  }
  match items[2].message {
    Some(row) => assert_eq(row.content, "First answer")
    None => fail("expected assistant message")
  }
}

///|
test "code mode canonical work exposes typed edit and test evidence in its turn" {
  let session = {
    ..code_mode_test_session("session-evidence", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-evidence", [
        code_mode_test_turn(
          "command-evidence",
          "Update the parser and run tests",
          assistant="Updated and verified.",
          steps=[
            {
              "item_id": "edit-parser",
              "title": "Updated files",
              "summary": "Updated `src/parser.mbt`.",
              "status": "done",
              "evidence": {
                "kind": "edit",
                "state": "applied",
                "path": "src/parser.mbt",
                "diff": "--- a/src/parser.mbt\n+++ b/src/parser.mbt\n-old\n+new\n",
                "command": "",
                "output": "",
                "exit_code": -1,
                "truncated": false,
              },
            },
            {
              "item_id": "test-parser",
              "title": "Checked result",
              "summary": "Finished checking the result.",
              "status": "done",
              "evidence": {
                "kind": "test",
                "state": "passed",
                "path": "",
                "diff": "",
                "command": "moon test",
                "output": "Total tests: 4, passed: 4",
                "exit_code": 0,
                "truncated": false,
              },
            },
          ],
        ),
      ]),
    ),
  }
  let items = mooncode_transcript_items(init_model(), session)
  match items[1].activity {
    Some(row) => {
      assert_true(row.folded)
      assert_eq(row.session_id, "session-evidence")
      assert_eq(row.retry_prompt, "Update the parser and run tests")
      assert_eq(row.evidence.length(), 2)
      assert_eq(row.evidence[0].kind, "edit")
      assert_eq(row.evidence[0].state, "applied")
      assert_eq(row.evidence[0].path, "src/parser.mbt")
      assert_true(row.evidence[0].diff.contains("+new"))
      assert_eq(row.evidence[1].kind, "test")
      assert_eq(row.evidence[1].state, "passed")
      assert_eq(row.evidence[1].command, "moon test")
      assert_eq(row.evidence[1].exit_code, 0)
    }
    None => fail("expected canonical work evidence")
  }
  match items[2].message {
    Some(row) => assert_eq(row.role, "assistant")
    None => fail("expected assistant result")
  }
}

///|
test "code mode folded work renders producer-owned user-facing wording" {
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "First prompt",
          assistant="First answer",
          steps=[
            {
              "title": "Reviewed request",
              "summary": "Thought through the request.",
              "status": "done",
            },
          ],
        ),
      ]),
    ),
  }
  let items = mooncode_transcript_items(init_model(), session)
  assert_eq(items.length(), 3)
  match items[1].activity {
    Some(row) => {
      assert_true(row.folded)
      assert_eq(row.title, "Reviewed request")
      assert_eq(row.detail, "Thought through the request.")
      assert_false(row.detail.contains("MoonClaw"))
      assert_false(row.detail.contains("runtime"))
    }
    None => fail("expected folded progress activity")
  }
}

///|
test "code mode transcript appends local optimistic turn after three backend turns" {
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
        code_mode_test_turn(
          "command-third",
          "Third prompt",
          assistant="Third answer",
        ),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_optimistic_rows: [
      {
        session_id: "session-a",
        role: "user",
        content: "Fourth prompt",
        status: "queued",
        key: "ui-user:session-a:fourth",
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
  assert_eq(messages.length(), 7)
  assert_eq(messages[0], "user:First prompt")
  assert_eq(messages[1], "assistant:First answer")
  assert_eq(messages[2], "user:Second prompt")
  assert_eq(messages[3], "assistant:Second answer")
  assert_eq(messages[4], "user:Third prompt")
  assert_eq(messages[5], "assistant:Third answer")
  assert_eq(messages[6], "user:Fourth prompt")
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
    mooncode_optimistic_rows: [
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
test "code mode transcript uses local rows without backend conversation" {
  let session = code_mode_test_session("session-a", status="running")
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_optimistic_rows: [
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
  let no_local_conversation = { ..model, mooncode_optimistic_rows: [] }
  assert_eq(
    code_mode_test_transcript_rows(no_local_conversation, session).length(),
    0,
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
  assert_true(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_composer_status, "new session draft")
}

///|
test "code mode selecting loaded session keeps selection" {
  let session = code_mode_test_session("session-a")
  let model = {
    ..init_model(),
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_watch_generation: 4,
    mooncode_watch_revision: 9,
    mooncode_watch_sequence: 11,
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SelectMoonCodeSession("session-a"),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "session-a")
  assert_false(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_watch_generation, 5)
  assert_eq(next.mooncode_watch_revision, 0)
  assert_eq(next.mooncode_watch_sequence, 0)
}

///|
test "code mode empty selection never reconstructs the first session" {
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "",
    mooncode_sessions: [
      code_mode_test_session("old-session", workspace_id="book-demo"),
    ],
  }
  assert_true(selected_mooncode_session(model) is None)
}

///|
test "code mode metadata refresh never invents a post-bootstrap selection" {
  let old_session = code_mode_test_session(
    "old-session",
    workspace_id="book-demo",
  )
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "",
    mooncode_sessions: [old_session],
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([old_session])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "")
  assert_true(selected_mooncode_session(next) is None)
  assert_eq(next.mooncode_metadata_generation, 1)
}

///|
test "code mode session listing failure also advances metadata generation" {
  let model = { ..init_model(), mooncode_metadata_generation: 7 }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Err("listing unavailable")),
    model,
  )
  assert_eq(next.mooncode_metadata_generation, 8)
}

///|
test "code mode selecting moonbook session updates active scope" {
  let general = code_mode_test_session("general-a", workspace_id="")
  let book = code_mode_test_session("book-a", workspace_id="book-a")
  let model = {
    ..init_model(),
    selected_workspace_id: "",
    mooncode_sessions: [general, book],
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SelectMoonCodeSession("book-a"),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "book-a")
  assert_eq(next.selected_workspace_id, "book-a")
}

///|
test "code mode selecting general session clears moonbook scope" {
  let general = code_mode_test_session("general-a", workspace_id="")
  let book = code_mode_test_session("book-a", workspace_id="book-a")
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    mooncode_sessions: [general, book],
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SelectMoonCodeSession("general-a"),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "general-a")
  assert_eq(next.selected_workspace_id, "")
}

///|
test "code mode general scope auto-selects only general sessions" {
  let book = code_mode_test_session("book-a", workspace_id="book-a")
  let general = code_mode_test_session("general-a", workspace_id="")
  let model = {
    ..init_model(),
    selected_workspace_id: "",
    selected_mooncode_session_id: "",
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([book, general])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "general-a")
}

///|
test "code mode general scope stays empty without general sessions" {
  let book = code_mode_test_session("book-a", workspace_id="book-a")
  let model = {
    ..init_model(),
    selected_workspace_id: "",
    selected_mooncode_session_id: "",
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([book])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "")
  assert_true(selected_mooncode_session(next) is None)
}

///|
test "code mode session rail groups general separately from moonbooks" {
  let general = code_mode_test_session("general-a", workspace_id="")
  let book = code_mode_test_session("book-a", workspace_id="book-a")
  let model = { ..init_model(), mooncode_sessions: [book, general] }
  let groups = mooncode_session_groups(model)
  assert_eq(groups.length(), 2)
  assert_eq(groups[0].id, "general")
  assert_eq(groups[0].workspace_id, "")
  assert_eq(groups[0].sessions.length(), 1)
  assert_eq(groups[0].sessions[0].id, "general-a")
  assert_eq(groups[1].workspace_id, "book-a")
  assert_eq(groups[1].sessions.length(), 1)
  assert_eq(groups[1].sessions[0].id, "book-a")
}

///|
test "code mode prompt action adds optimistic prompt before runtime reply" {
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
    SendMoonCodeMessage(model.mooncode_prompt),
    model,
  )
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_next_client_turn_index, 1)
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(next.mooncode_optimistic_rows[0].role, "user")
  assert_eq(
    next.mooncode_optimistic_rows[0].content,
    "Explain the latest error",
  )
  let rows = code_mode_test_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].content, "Explain the latest error")
}

///|
test "code mode keeps the first prompt as the stable new session title" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    mooncode_prompt: "  Explain the failing integration test  ",
  }
  assert_eq(
    mooncode_new_session_title(model),
    "Explain the failing integration test",
  )
  let draft_session_id = mooncode_draft_session_id(model)
  let optimistic = {
    ..model,
    mooncode_prompt: "",
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      draft_session_id,
      "Explain the failing integration test",
      client_turn_id="title-turn",
    ),
  }
  assert_eq(
    mooncode_new_session_title(optimistic),
    "Explain the failing integration test",
  )
}

///|
test "code mode prompt action queues behind an optimistic pending turn" {
  let session = code_mode_test_session("session-a", status="running")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_prompt: "Do not lose this prompt",
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      "session-a",
      "Previous pending prompt",
      client_turn_id="client-turn-pending",
    ),
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage(model.mooncode_prompt),
    model,
  )
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_optimistic_rows.length(), 2)
  assert_eq(next.mooncode_optimistic_rows[1].content, "Do not lose this prompt")
  assert_eq(next.mooncode_composer_status, "message queued for MoonCode")
}

///|
test "code mode prompt action queues behind a canonical running turn" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "Previous prompt",
          status="running",
          steps=[
            {
              "title": "Thinking",
              "summary": "Still working.",
              "status": "running",
              "command_id": "command-first",
              "client_turn_id": "command-first",
            },
          ],
        ),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_prompt: "Do not race ahead",
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage(model.mooncode_prompt),
    model,
  )
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(next.mooncode_optimistic_rows[0].content, "Do not race ahead")
  assert_eq(next.mooncode_composer_status, "message queued for MoonCode")
}

///|
test "code mode prompt action accepts stale running session after completed turn" {
  let session = {
    ..code_mode_test_session("session-a", status="running", queued_count=1),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "command-first",
          "Previous prompt",
          assistant="Previous answer",
          status="done",
        ),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_prompt: "Third prompt should insert",
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage(model.mooncode_prompt),
    model,
  )
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(
    next.mooncode_optimistic_rows[0].content,
    "Third prompt should insert",
  )
  assert_eq(next.mooncode_composer_status, "message queued for MoonCode")
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
    SendMoonCodeMessage(model.mooncode_prompt),
    model,
  )
  let draft_id = mooncode_draft_session_id(model)
  assert_eq(next.selected_mooncode_session_id, "")
  assert_true(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(next.mooncode_optimistic_rows[0].session_id, draft_id)
  assert_eq(next.mooncode_optimistic_rows[0].role, "user")
  assert_eq(
    next.mooncode_optimistic_rows[0].content,
    "Sketch the migration plan",
  )
  assert_eq(next.mooncode_next_client_turn_index, 1)
  let session = selected_mooncode_session(next).unwrap()
  assert_eq(session.id, draft_id)
  let rows = code_mode_test_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Sketch the migration plan")
}

///|
test "code mode new chat keeps prompt while draft turn is pending" {
  let base = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "",
    selected_mooncode_session_id: "",
    mooncode_sessions: [],
    mooncode_prompt: "Second draft prompt",
    mooncode_composer_status: "draft",
  }
  let draft_id = mooncode_draft_session_id(base)
  let model = {
    ..base,
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      draft_id,
      "First draft prompt",
      client_turn_id="draft-client-turn-pending",
    ),
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage(model.mooncode_prompt),
    model,
  )
  assert_eq(next.mooncode_prompt, "Second draft prompt")
  assert_true(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(
    next.mooncode_composer_status,
    "waiting for previous MoonCode reply",
  )
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
    SendMoonCodeMessage(base.mooncode_prompt),
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
test "code mode send uses the atomic click payload before draft state catches up" {
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "",
    selected_mooncode_session_id: "",
    mooncode_sessions: [],
    mooncode_prompt: "",
    mooncode_composer_status: "new session draft",
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage("Fast click"),
    model,
  )
  assert_eq(next.mooncode_prompt, "")
  assert_true(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(next.mooncode_optimistic_rows[0].content, "Fast click")
  assert_eq(next.mooncode_composer_status, "message queued for MoonCode")
}

///|
test "code mode canonical completion clears a stale optimistic gate before second send" {
  let first_turn = code_mode_test_turn(
    "command-first",
    "First prompt",
    client_turn_id="client-turn-first",
  )
  let session = {
    ..code_mode_test_session("session-second-turn", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-second-turn", [first_turn]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: session.id,
    mooncode_sessions: [session],
    mooncode_prompt: "",
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      session.id,
      "First prompt",
      client_turn_id="client-turn-first",
    ),
  }
  let (_, next) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage("Second prompt"),
    model,
  )
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(next.mooncode_optimistic_rows[0].content, "Second prompt")
  assert_true(next.mooncode_optimistic_rows[0].key != "client-turn-first")
  assert_eq(next.mooncode_composer_status, "message queued for MoonCode")
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
    SendMoonCodeMessage(draft_model.mooncode_prompt),
    draft_model,
  )
  let real_session = code_mode_test_session("session-created", workspace_id="")
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    CreatedMoonCodeSession(Ok(real_session)),
    pending,
  )
  assert_eq(next.selected_mooncode_session_id, "session-created")
  assert_false(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(next.mooncode_optimistic_rows[0].session_id, "session-created")
  assert_eq(
    next.mooncode_optimistic_rows[0].content,
    "Keep the first prompt visible",
  )
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
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      "session-created",
      "Keep the new chat selected",
    ),
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
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      "session-created",
      "Already adopted",
    ),
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    CreatedMoonCodeSession(Ok(session)),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "session-created")
  assert_false(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
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
    SendMoonCodeMessage(draft_model.mooncode_prompt),
    draft_model,
  )
  let newer_listing = code_mode_test_session("older", workspace_id="")
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([newer_listing])),
    pending,
  )
  assert_eq(next.selected_mooncode_session_id, "")
  assert_true(next.mooncode_new_chat_active)
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
    SendMoonCodeMessage(draft_model.mooncode_prompt),
    draft_model,
  )
  let client_turn_id = pending.mooncode_optimistic_rows[0].key
  let created = {
    ..code_mode_test_session(
      "session-created",
      workspace_id="",
      status="queued",
    ),
    workspace_name: "General MoonCode",
    mooncode_conversation: Some(
      code_mode_test_conversation("session-created", [
        code_mode_test_turn(
          "created-user",
          "Keep draft selected",
          client_turn_id~,
        ),
      ]),
    ),
    mooncode_summary: { ..code_mode_test_summary(), event_count: 1 },
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([created])),
    pending,
  )
  assert_eq(next.selected_mooncode_session_id, "session-created")
  assert_false(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_sessions.length(), 1)
  assert_eq(next.mooncode_sessions[0].id, "session-created")
  assert_eq(next.mooncode_optimistic_rows.length(), 0)
  assert_eq(next.mooncode_composer_status, "MoonCode session started")
  let session = selected_mooncode_session(next).unwrap()
  let rows = code_mode_test_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Keep draft selected")
}

///|
test "code mode compact session listing does not adopt draft by prompt title" {
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
    SendMoonCodeMessage(draft_model.mooncode_prompt),
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
    mooncode_summary: { ..code_mode_test_summary(), event_count: 1 },
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([compact])),
    pending,
  )
  assert_eq(next.selected_mooncode_session_id, "")
  assert_true(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(
    next.mooncode_optimistic_rows[0].session_id,
    mooncode_draft_session_id(next),
  )
  assert_eq(next.mooncode_composer_status, "message queued for MoonCode")
  let session = selected_mooncode_session(next).unwrap()
  let rows = code_mode_test_transcript_rows(next, session)
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].content, "Compact listing prompt")
  let items = mooncode_transcript_items(next, session)
  assert_eq(items.length(), 1)
}

///|
test "code mode command result keeps optimistic prompt until canonical turn arrives" {
  let session = code_mode_test_session("session-a", status="running")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      "session-a",
      "Stable order please",
      client_turn_id="client-turn-local",
    ),
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    CompletedMoonCodeCommand(Ok(session)),
    model,
  )
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
  assert_eq(next.mooncode_optimistic_rows[0].content, "Stable order please")
}

///|
test "code mode command result promotes touched session in rail" {
  let older = code_mode_test_session("older", status="done")
  let session = code_mode_test_session("session-a", status="running")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [older, session],
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      "session-a",
      "Bring this chat to the top",
      client_turn_id="client-turn-local",
    ),
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    CompletedMoonCodeCommand(Ok(session)),
    model,
  )
  assert_eq(next.mooncode_sessions.length(), 2)
  assert_eq(next.mooncode_sessions[0].id, "session-a")
  assert_eq(next.mooncode_sessions[1].id, "older")
}

///|
test "code mode stale listing cannot demote pending selected session" {
  let selected = code_mode_test_session("session-a", status="running")
  let older = code_mode_test_session("older", status="done")
  let selected_listing = {
    ..code_mode_test_session("session-a", status="queued"),
    source: Some("mooncode-session-listing"),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [selected, older],
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      "session-a",
      "Keep this chat pinned while pending",
      client_turn_id="client-turn-local",
    ),
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([older, selected_listing])),
    model,
  )
  assert_eq(next.mooncode_sessions.length(), 2)
  assert_eq(next.mooncode_sessions[0].id, "session-a")
  assert_eq(next.mooncode_sessions[1].id, "older")
  assert_eq(next.mooncode_optimistic_rows.length(), 1)
}

///|
test "code mode command error shows failed assistant row and unblocks composer" {
  let session = code_mode_test_session("session-a", status="done")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_optimistic_rows: mooncode_append_optimistic_user_prompt(
      [],
      "session-a",
      "Message that failed to send",
      client_turn_id="client-turn-local",
    ),
    mooncode_prompt: "Retry after failure",
  }
  let (_, failed) = update_mooncode_session_results(
    code_mode_test_dispatch,
    CompletedMoonCodeCommand(Err("network down")),
    model,
  )
  assert_eq(failed.mooncode_optimistic_rows.length(), 2)
  assert_eq(failed.mooncode_optimistic_rows[0].status, "failed")
  assert_eq(failed.mooncode_optimistic_rows[1].role, "assistant")
  let rows = code_mode_test_transcript_rows(failed, session)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].role, "user")
  assert_eq(rows[0].content, "Message that failed to send")
  assert_eq(rows[0].status, "failed")
  assert_eq(rows[1].role, "assistant")
  assert_eq(
    rows[1].content,
    "MoonCode could not send this message: network down",
  )
  let (_, retried) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    SendMoonCodeMessage(model.mooncode_prompt),
    failed,
  )
  assert_eq(retried.mooncode_composer_status, "message queued for MoonCode")
  assert_eq(retried.mooncode_prompt, "")
  assert_eq(retried.mooncode_optimistic_rows.length(), 3)
  assert_eq(retried.mooncode_optimistic_rows[2].content, "Retry after failure")
}

///|
test "code mode direct retry appends a new canonical prompt request" {
  let session = code_mode_test_session("session-retry", status="failed")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: session.id,
    mooncode_sessions: [session],
  }
  let (_, retried) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    RetryMoonCodeTurn(session.id, "Run the failed check again"),
    model,
  )
  assert_eq(retried.mooncode_prompt, "")
  assert_eq(retried.mooncode_optimistic_rows.length(), 1)
  assert_eq(
    retried.mooncode_optimistic_rows[0].content,
    "Run the failed check again",
  )
  assert_eq(retried.mooncode_composer_status, "message queued for MoonCode")
}

///|
test "code mode cancel is available only while canonical work is active" {
  let running = code_mode_test_session("session-running", status="running")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: running.id,
    mooncode_sessions: [running],
  }
  let (_, cancelling) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CancelMoonCodeWork(running.id),
    model,
  )
  assert_eq(cancelling.mooncode_composer_status, "Cancellation requested")
  let done = { ..running, status: "done" }
  let (_, unchanged) = update_mooncode_session_actions(
    code_mode_test_dispatch,
    CancelMoonCodeWork(done.id),
    { ..model, mooncode_sessions: [done] },
  )
  assert_eq(unchanged.mooncode_composer_status, "MoonCode is not running")
}

///|
test "code mode copy feedback clears only the matching item" {
  let (_, copied) = update_mooncode_actions(
    code_mode_test_dispatch,
    CopyMoonCodeText("answer-1", "answer"),
    init_model(),
  )
  assert_eq(copied.mooncode_copied_item_id, "answer-1")
  let (_, stale_clear) = update_mooncode_actions(
    code_mode_test_dispatch,
    ClearMoonCodeCopy("answer-2"),
    copied,
  )
  assert_eq(stale_clear.mooncode_copied_item_id, "answer-1")
  let (_, cleared) = update_mooncode_actions(
    code_mode_test_dispatch,
    ClearMoonCodeCopy("answer-1"),
    stale_clear,
  )
  assert_eq(cleared.mooncode_copied_item_id, "")
}

///|
test "code mode explicit new session draft is not replaced by existing sessions" {
  let session = code_mode_test_session("existing")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "",
    mooncode_sessions: [session],
    mooncode_new_chat_active: true,
    mooncode_composer_status: "new session draft",
  }
  assert_true(selected_mooncode_session(model) is None)
  let with_status_refresh = {
    ..model,
    mooncode_composer_status: "daemon temporarily unavailable",
  }
  assert_true(selected_mooncode_session(with_status_refresh) is None)
}

///|
test "code mode status copy cannot reconstruct an empty selection" {
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
  let with_validation_copy = {
    ..model,
    mooncode_composer_status: "enter a message",
  }
  assert_true(selected_mooncode_session(with_validation_copy) is None)
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
test "code mode compact polling cannot erase a hydrated conversation" {
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
test "code mode listing refresh preserves selected hydrated conversation" {
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
  let listing = {
    ..code_mode_test_session("session-a", status="idle"),
    source: Some("mooncode-session-listing"),
    title: "MoonCode - session-a listed",
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
    LoadedMoonCodeSessions(Ok([listing])),
    model,
  )
  let session = selected_mooncode_session(next).unwrap()
  assert_eq(session.title, "MoonCode - session-a listed")
  assert_true(session.mooncode_conversation is Some(_))
  let rows = code_mode_test_transcript_rows(next, session)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].content, "Keep this prompt")
  assert_eq(rows[1].content, "Keep this answer")
}

///|
test "code mode native listing refresh preserves selected hydrated conversation" {
  let hydrated = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "turn-a",
          "Keep native prompt",
          assistant="Keep native answer",
        ),
      ]),
    ),
  }
  let listing = {
    ..code_mode_test_session("session-a", status="done"),
    source: Some("mooncode-runtime-session-listing"),
    title: "Native session title",
    workspace_id: "",
    workspace_name: "",
    cwd: "",
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
    LoadedMoonCodeSessions(Ok([listing])),
    model,
  )
  let session = selected_mooncode_session(next).unwrap()
  assert_eq(session.title, "Native session title")
  assert_eq(session.workspace_id, hydrated.workspace_id)
  assert_eq(session.workspace_name, hydrated.workspace_name)
  assert_eq(session.cwd, hydrated.cwd)
  assert_true(session.mooncode_conversation is Some(_))
  let rows = code_mode_test_transcript_rows(next, session)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].content, "Keep native prompt")
  assert_eq(rows[1].content, "Keep native answer")
}

///|
test "code mode selected canonical watch hydrates listing row" {
  let listing = {
    ..code_mode_test_session("session-a", status="done"),
    source: Some("mooncode-session-listing"),
    mooncode_conversation: None,
  }
  let hydrated = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "turn-a",
          "Loaded prompt",
          assistant="Loaded answer",
        ),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [listing],
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeWatch(
      0,
      "session-a",
      Ok(code_mode_test_watch_snapshot(hydrated, 2)),
    ),
    model,
  )
  let session = selected_mooncode_session(next).unwrap()
  assert_true(session.mooncode_conversation is Some(_))
  let rows = code_mode_test_transcript_rows(next, session)
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].content, "Loaded prompt")
  assert_eq(rows[1].content, "Loaded answer")
}

///|
test "code mode selected canonical watch keeps rail order" {
  let newer = code_mode_test_session("newer", status="done")
  let listing = {
    ..code_mode_test_session("session-a", status="done"),
    source: Some("mooncode-session-listing"),
    mooncode_conversation: None,
  }
  let hydrated = {
    ..code_mode_test_session("session-a", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn("turn-a", "Loaded prompt"),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [newer, listing],
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeWatch(
      0,
      "session-a",
      Ok(code_mode_test_watch_snapshot(hydrated, 1)),
    ),
    model,
  )
  assert_eq(next.mooncode_sessions.length(), 2)
  assert_eq(next.mooncode_sessions[0].id, "newer")
  assert_eq(next.mooncode_sessions[1].id, "session-a")
  assert_true(next.mooncode_sessions[1].mooncode_conversation is Some(_))
}

///|
test "code mode ignores unchanged canonical conversation revisions" {
  let turn = code_mode_test_turn("command-first", "Prompt", assistant="Answer")
  let existing = {
    ..code_mode_test_session("session-a", status="done"),
    title: "Stable title",
    mooncode_conversation: Some({
      ..code_mode_test_conversation("session-a", [turn]),
      revision: 4,
    }),
  }
  let unchanged = {
    ..existing,
    title: "Polling replacement",
    mooncode_conversation: Some({
      ..code_mode_test_conversation("session-a", [turn]),
      revision: 4,
    }),
  }
  let preserved = mooncode_upsert_session_if_revision_changed(
    [existing],
    unchanged,
  )
  assert_eq(preserved[0].title, "Stable title")
  let regressed = {
    ..unchanged,
    title: "Regressed title",
    mooncode_conversation: Some({
      ..code_mode_test_conversation("session-a", [turn]),
      revision: 3,
    }),
  }
  let still_preserved = mooncode_upsert_session_if_revision_changed(
    preserved, regressed,
  )
  assert_eq(still_preserved[0].title, "Stable title")
  assert_eq(mooncode_session_conversation_revision(still_preserved[0]), 4)
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: still_preserved,
  }
  let (_, unchanged_model) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeWatch(
      0,
      "session-a",
      Ok(code_mode_test_watch_heartbeat("session-a", 4, 2)),
    ),
    model,
  )
  assert_eq(unchanged_model.mooncode_sessions[0].title, "Stable title")
  assert_eq(
    mooncode_session_conversation_revision(unchanged_model.mooncode_sessions[0]),
    4,
  )
  let advanced = {
    ..unchanged,
    title: "Advanced title",
    mooncode_conversation: Some({
      ..code_mode_test_conversation("session-a", [turn]),
      revision: 5,
    }),
  }
  let updated = mooncode_upsert_session_if_revision_changed(preserved, advanced)
  assert_eq(updated[0].title, "Advanced title")
}

///|
test "code mode delayed command response cannot replace a newer turn" {
  let turn = code_mode_test_turn("command-first", "Prompt", assistant="Answer")
  let existing = {
    ..code_mode_test_session("session-a", status="done"),
    title: "Current title",
    mooncode_conversation: Some({
      ..code_mode_test_conversation("session-a", [turn]),
      revision: 8,
    }),
  }
  let delayed = {
    ..existing,
    title: "Delayed title",
    mooncode_conversation: Some({
      ..code_mode_test_conversation("session-a", [turn]),
      revision: 6,
    }),
  }
  let other = code_mode_test_session("session-b", status="done")
  let updated = mooncode_upsert_session_at_top([other, existing], delayed)
  assert_eq(updated[0].id, "session-a")
  assert_eq(updated[0].title, "Current title")
  assert_eq(mooncode_session_conversation_revision(updated[0]), 8)
  assert_eq(updated[1].id, "session-b")
}

///|
test "code mode stale canonical watch response is ignored" {
  let selected = code_mode_test_session("session-a", status="done")
  let stale = {
    ..code_mode_test_session("session-b", status="done"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-b", [
        code_mode_test_turn("turn-b", "Wrong prompt"),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [selected],
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeWatch(
      0,
      "session-b",
      Ok(code_mode_test_watch_snapshot(stale, 1)),
    ),
    model,
  )
  let session = selected_mooncode_session(next).unwrap()
  assert_eq(session.id, "session-a")
  assert_true(session.mooncode_conversation is None)
}

///|
test "code mode canonical watch heartbeat preserves the last good transcript" {
  let turn = code_mode_test_turn(
    "turn-a",
    "Stable prompt",
    assistant="Stable answer",
  )
  let session = {
    ..code_mode_test_session("session-a", status="done"),
    title: "Stable title",
    mooncode_conversation: Some({
      ..code_mode_test_conversation("session-a", [turn]),
      revision: 8,
    }),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_watch_generation: 4,
    mooncode_watch_revision: 8,
    mooncode_watch_sequence: 11,
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeWatch(
      4,
      "session-a",
      Ok(code_mode_test_watch_heartbeat("session-a", 8, 9)),
    ),
    model,
  )
  assert_eq(next.mooncode_sessions[0].title, "Stable title")
  assert_eq(
    mooncode_session_conversation_revision(next.mooncode_sessions[0]),
    8,
  )
  assert_eq(next.mooncode_watch_revision, 8)
  assert_eq(next.mooncode_watch_sequence, 11)
  assert_eq(next.mooncode_watch_status, "watching")
  let rows = code_mode_test_transcript_rows(next, next.mooncode_sessions[0])
  assert_eq(rows.length(), 2)
  assert_eq(rows[0].content, "Stable prompt")
  assert_eq(rows[1].content, "Stable answer")
}

///|
test "code mode canonical watch cannot roll back revision but advances wake cursor" {
  let current = {
    ..code_mode_test_session("session-a", status="done"),
    title: "Current title",
    mooncode_conversation: Some({
      ..code_mode_test_conversation("session-a", [
        code_mode_test_turn(
          "turn-a",
          "Current prompt",
          assistant="Current answer",
        ),
      ]),
      revision: 8,
    }),
  }
  let stale = {
    ..current,
    title: "Stale title",
    mooncode_conversation: Some({
      ..code_mode_test_conversation("session-a", [
        code_mode_test_turn("turn-a", "Old prompt", assistant="Old answer"),
      ]),
      revision: 6,
    }),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [current],
    mooncode_watch_generation: 3,
    mooncode_watch_revision: 8,
    mooncode_watch_sequence: 5,
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeWatch(
      3,
      "session-a",
      Ok(code_mode_test_watch_snapshot(stale, 12)),
    ),
    model,
  )
  assert_eq(next.mooncode_sessions[0].title, "Current title")
  assert_eq(
    mooncode_session_conversation_revision(next.mooncode_sessions[0]),
    8,
  )
  assert_eq(next.mooncode_watch_revision, 8)
  assert_eq(next.mooncode_watch_sequence, 12)
}

///|
test "code mode watch disconnect preserves transcript while reconnecting" {
  let session = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn("turn-a", "Keep me", status="running"),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_watch_generation: 9,
    mooncode_watch_sequence: 4,
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeWatch(9, "session-a", Err("connection reset")),
    model,
  )
  assert_eq(next.mooncode_watch_status, "reconnecting")
  assert_eq(next.mooncode_watch_sequence, 4)
  assert_eq(next.mooncode_sessions.length(), 1)
  let items = mooncode_transcript_items(next, next.mooncode_sessions[0])
  assert_eq(items.length(), 2)
  let rows = code_mode_test_transcript_rows(next, next.mooncode_sessions[0])
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].content, "Keep me")
}

///|
test "code mode replaced watch leaves the healthy replacement alone" {
  let session = code_mode_test_session("session-a", status="running")
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [session],
    mooncode_watch_generation: 9,
    mooncode_watch_revision: 8,
    mooncode_watch_sequence: 4,
    mooncode_watch_status: "connecting",
    mooncode_composer_status: "message queued for MoonCode",
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeWatch(9, "session-a", Err("MoonCode watch replaced")),
    model,
  )
  assert_eq(next.mooncode_watch_status, "connecting")
  assert_eq(next.mooncode_watch_revision, 8)
  assert_eq(next.mooncode_watch_sequence, 4)
  assert_eq(next.mooncode_composer_status, "message queued for MoonCode")
  assert_eq(next.mooncode_sessions.length(), 1)
}

///|
test "code mode ignores a completed watch from an older generation" {
  let selected = code_mode_test_session("session-a", status="done")
  let stale = {
    ..selected,
    title: "Wrong generation",
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn("turn-a", "Wrong prompt"),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [selected],
    mooncode_watch_generation: 5,
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeWatch(
      4,
      "session-a",
      Ok(code_mode_test_watch_snapshot(stale, 2)),
    ),
    model,
  )
  assert_eq(next.mooncode_sessions[0].title, selected.title)
  assert_true(next.mooncode_sessions[0].mooncode_conversation is None)
}

///|
test "code mode listing refresh cannot roll back selected conversation" {
  let current = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn("turn-a", "First prompt", status="queued"),
        code_mode_test_turn("turn-b", "Second prompt", status="queued"),
        code_mode_test_turn("turn-c", "Third prompt", status="queued"),
      ]),
    ),
  }
  let stale = {
    ..code_mode_test_session("session-a", status="running"),
    mooncode_conversation: Some(
      code_mode_test_conversation("session-a", [
        code_mode_test_turn("turn-a", "First prompt", status="queued"),
        code_mode_test_turn("turn-b", "Second prompt", status="queued"),
      ]),
    ),
  }
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_mooncode_session_id: "session-a",
    mooncode_sessions: [current],
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([stale])),
    model,
  )
  let session = selected_mooncode_session(next).unwrap()
  let rows = code_mode_test_transcript_rows(next, session)
  assert_eq(rows.length(), 3)
  assert_eq(rows[0].content, "First prompt")
  assert_eq(rows[1].content, "Second prompt")
  assert_eq(rows[2].content, "Third prompt")
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
    mooncode_new_chat_active: true,
    mooncode_composer_status: "new session draft",
  }
  let (_, daemon_next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonClawDaemon(
      Ok({
        running: true,
        port: 1515,
        message: "daemon running",
        service_configured: true,
      }),
    ),
    model,
  )
  assert_eq(daemon_next.selected_mooncode_session_id, "")
  assert_true(daemon_next.mooncode_new_chat_active)
  assert_eq(daemon_next.mooncode_composer_status, "new session draft")
  assert_true(selected_mooncode_session(daemon_next) is None)

  let (_, models_next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonClawModels(
      Ok({
        ok: true,
        daemon: {
          running: true,
          port: 1515,
          message: "daemon running",
          service_configured: true,
        },
        models: [{ name: "deepseek-v4-flash" }],
      }),
    ),
    model,
  )
  assert_eq(models_next.selected_mooncode_session_id, "")
  assert_true(models_next.mooncode_new_chat_active)
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
test "code mode model polling leaves selection empty without executable models" {
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
        daemon: {
          running: true,
          port: 1515,
          message: "daemon running",
          service_configured: true,
        },
        models: [],
      }),
    ),
    model,
  )
  assert_eq(next.mooncode_model, "")
}

///|
test "code mode command payload lets MoonClaw own an empty default selection" {
  let empty_session = { ..code_mode_test_session("session-a"), model: "" }
  assert_eq(
    mooncode_selected_runtime_model(init_model(), Some(empty_session)),
    "",
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
test "code mode model refresh replaces a stale unavailable selection" {
  let result : MoonClawModelsResult = {
    ok: true,
    daemon: {
      running: true,
      port: 1515,
      message: "daemon running",
      service_configured: true,
    },
    models: [{ name: "codex/gpt-5.4" }],
  }
  assert_eq(
    mooncode_reconcile_runtime_model("gpt-5.6-sol", result),
    "codex/gpt-5.4",
  )
  assert_eq(
    mooncode_reconcile_runtime_model("codex/gpt-5.4", result),
    "codex/gpt-5.4",
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
    SendMoonCodeMessage(model.mooncode_prompt),
    model,
  )
  assert_true(next.workspace_mode is MoonCode)
  assert_true(next.activity is Search)
  assert_false(next.command_open)
  assert_eq(next.mooncode_composer_status, "enter a message")
  assert_eq(next.selected_mooncode_session_id, "")
}

///|
test "code mode composer always queues a prompt from the chat input" {
  let model = { ..init_model(), mooncode_prompt: "continue" }
  assert_eq(
    mooncode_composer_button_label(
      model,
      Some(code_mode_test_session("running", status="running")),
    ),
    "Prompt",
  )
  assert_eq(
    mooncode_composer_button_label(model, Some(code_mode_test_session("idle"))),
    "Prompt",
  )
  assert_eq(mooncode_composer_button_label(model, None), "Start")
}

///|
test "code mode only sends a context path for a real selected file" {
  let missing = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
    ],
  }
  assert_eq(mooncode_context_path(missing), "")
  let selected = {
    ..missing,
    selected_path: "tools/parser.mbt",
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="tools/parser.mbt"),
    ],
  }
  assert_eq(mooncode_context_path(selected), "tools/parser.mbt")
}

///|
test "code mode created session selects session and clears prompt" {
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
test "code mode session listing prefers selected session" {
  let session = code_mode_test_session("session-a")
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "session-a",
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "session-a")
  assert_eq(next.mooncode_composer_status, "1 MoonCode session(s)")
}

///|
test "code mode session listing selects first session when selected is missing" {
  let session = code_mode_test_session("session-b")
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_mooncode_session_id: "missing-session",
  }
  let (_, next) = update_mooncode_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    model,
  )
  assert_eq(next.selected_mooncode_session_id, "session-b")
}

///|

///|
test "code mode keeps every MoonBook group visible without sessions" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    workspaces: [
      @desk.workspace(
        id="book-a",
        name="Book A",
        root_path="/tmp/moonsuite/books/book-a",
        kind=MoonBook,
      ),
      @desk.workspace(
        id="book-b",
        name="Book B",
        root_path="/tmp/moonsuite/books/book-b",
        kind=MoonBook,
      ),
    ],
    mooncode_sessions: [],
  }
  let groups = mooncode_session_groups(model)
  assert_eq(groups.length(), 3)
  assert_eq(groups[0].label, "General")
  assert_eq(groups[1].label, "Book A")
  assert_eq(groups[2].label, "Book B")
}

///|
test "code mode polling cannot regroup an existing session" {
  let existing = {
    ..code_mode_test_session("session-stable", workspace_id="book-demo"),
    workspace_name: "Demo Book",
    cwd: "/tmp/moonsuite/books/book-demo",
  }
  let incoming = {
    ..existing,
    workspace_id: "wrong-runtime-id",
    workspace_name: "Wrong runtime name",
    cwd: "/tmp/moonsuite",
    status: "done",
  }
  let sessions = mooncode_upsert_session([existing], incoming)
  assert_eq(sessions[0].workspace_id, "book-demo")
  assert_eq(sessions[0].workspace_name, "Demo Book")
  assert_eq(sessions[0].cwd, "/tmp/moonsuite/books/book-demo")
  assert_eq(sessions[0].status, "done")
}

///|
test "MoonClaw setup action stays visible as a user operation" {
  let model = { ..init_model(), mooncode_composer_status: "idle" }
  let (_, next) = update_mooncode_actions(
    code_mode_test_dispatch,
    ManageMoonClaw("start"),
    model,
  )
  assert_eq(next.mooncode_composer_status, "Starting MoonClaw…")
}

///|
test "MoonClaw lifecycle result refreshes service and model state" {
  let model = init_model()
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    ManagedMoonClaw(
      Ok({
        running: true,
        port: 1515,
        message: "MoonClaw daemon started",
        service_configured: true,
      }),
    ),
    model,
  )
  assert_true(next.moonclaw_daemon.unwrap().running)
  assert_eq(next.mooncode_composer_status, "MoonClaw daemon started")
}

///|
test "MoonGate setup handoff uses the proven Desk mode action" {
  let model = {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-demo",
  }
  let (_, next) = update_navigation_actions(
    code_mode_test_dispatch,
    SelectWorkspaceMode(Desk),
    model,
  )
  assert_true(next.workspace_mode is Desk)
  assert_true(
    mooncode_center_class({
      ..model,
      moonclaw_daemon: Some({
        running: false,
        port: 0,
        message: "not running",
        service_configured: false,
      }),
    }).contains("runtime-setup-visible"),
  )
}
