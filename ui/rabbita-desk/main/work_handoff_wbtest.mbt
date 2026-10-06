///|
fn handoff_desk_query() -> String {
  "?activity=code&session=S%2F%E4%B9%A6&command=C%3F0&book_root=%2Fbook%2F&work_task=T%26one&work_run=R&work_mode=inspect&return_to=https%3A%2F%2Fproj.example%2Fcustom%3Ftask%3DT%2526one%26keep%3D1%23run"
}

///|
fn handoff_desk_model() -> Model {
  {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "",
    requested_workspace_id: "",
    selected_mooncode_session_id: "S/书",
    mooncode_auto_select_session: false,
    work_handoff: work_handoff_from_query(handoff_desk_query()),
  }
}

///|
fn handoff_desk_fixture(
  session? : String = "S/书",
  command? : String = "C?0",
  root? : String = "/book",
) -> Json {
  {
    "schema": "moondesk.work-handoff.v1",
    "state": "ready",
    "workspace": { "id": "actual-desk-id", "root_path": root },
    "session_id": session,
    "original_command": {
      "command_id": command,
      "action": "prompt",
      "claim_status": "delivered",
      "receipt_status": "runtime-completed",
      "model": "captured-c0-model",
      "context_path": "/book/original/context.md",
    },
    "transcript": {
      "state": "runtime_unavailable",
      "message": "Saved transcript temporarily unavailable",
    },
    "session": Json::null(),
  }
}

///|
fn handoff_desk_ready() -> Model {
  let (_, pending) = update_work_handoff(
    code_mode_test_dispatch,
    Resolve,
    handoff_desk_model(),
  )
  let (_, ready) = update_work_handoff(
    code_mode_test_dispatch,
    Resolved(pending.work_handoff.generation, Ok(handoff_desk_fixture())),
    pending,
  )
  ready
}

///|
test "handoff cold start reload keeps exact hints without trusting workspace or setup" {
  for _index in 0..<2 {
    let previous = requested_selection_install_test_location(
      handoff_desk_query() + "&workspace=forged-workspace&path=unrelated",
    )
    let model = init_model()
    requested_selection_restore_test_location(previous)
    assert_true(model.workspace_mode is MoonCode)
    assert_eq(model.selected_workspace_id, "")
    assert_eq(model.requested_workspace_id, "")
    assert_eq(model.selected_path, "")
    assert_eq(model.work_handoff.target.unwrap().session_id, "S/书")
    assert_eq(model.work_handoff.target.unwrap().command_id, "C?0")
    assert_eq(model.work_handoff.target.unwrap().book_root, "/book/")
    assert_false(model.mooncode_auto_select_session)
    let (_, bootstrapped) = bootstrap_action(code_mode_test_dispatch, model)
    assert_eq(bootstrapped.work_handoff.phase, "loading")
    assert_true(bootstrapped.bootstrapped)
    assert_true(bootstrapped.moonclaw_daemon is None)
  }
}

///|
test "ordinary URLs do not activate handoff and partial handoff cannot open chat" {
  assert_true(
    work_handoff_from_query("?activity=code&session=ordinary&workspace=book").target
    is None,
  )
  let invalid = work_handoff_from_query("?work_task=T&session=S")
  assert_eq(invalid.phase, "invalid_request")
  let (_, next) = update_work_handoff(code_mode_test_dispatch, Resolve, {
    ..init_model(),
    work_handoff: invalid,
  })
  assert_eq(next.work_handoff.phase, "invalid_request")
}

///|
test "resolver request remains same origin and encodes exact S C0 root" {
  assert_eq(
    work_handoff_read_url("S/书", "C?0", "/book with space/"),
    "/api/mooncode/work-handoff?session_id=S%2F%E4%B9%A6&command_id=C%3F0&book_root=%2Fbook+with+space%2F&include_session=true&include_context=true",
  )
}

///|
test "host resolution verifies exact identity and accepts normalized trailing root" {
  let target = handoff_desk_model().work_handoff.target.unwrap()
  let canonical = work_handoff_decode(target, handoff_desk_fixture()).unwrap()
  assert_eq(canonical.workspace_id, "actual-desk-id")
  assert_eq(canonical.model, "captured-c0-model")
  assert_eq(canonical.context_path, "/book/original/context.md")
  assert_true(
    work_handoff_decode(target, handoff_desk_fixture(session="other")) is Err(_),
  )
  assert_true(
    work_handoff_decode(target, handoff_desk_fixture(command="C1")) is Err(_),
  )
  assert_true(
    work_handoff_decode(target, handoff_desk_fixture(root="/other")) is Err(_),
  )
}

///|
test "resolver error and missing pending target remain retryable without another chat" {
  let (_, pending) = update_work_handoff(
    code_mode_test_dispatch,
    Resolve,
    handoff_desk_model(),
  )
  for
    result in [
      Err("offline"),
      Ok(
        (
          {
            "schema": "moondesk.work-handoff.v1",
            "state": "command_not_found",
            "message": "Command not admitted yet",
          } : Json),
      ),
    ] {
    let (_, failed) = update_work_handoff(
      code_mode_test_dispatch,
      Resolved(pending.work_handoff.generation, result),
      pending,
    )
    assert_eq(failed.work_handoff.phase, "unavailable")
    assert_eq(failed.selected_mooncode_session_id, "S/书")
    assert_false(failed.mooncode_new_chat_active)
    let (_, retry) = update_work_handoff(
      code_mode_test_dispatch,
      Resolve,
      failed,
    )
    assert_eq(
      retry.work_handoff.generation,
      pending.work_handoff.generation + 1,
    )
  }
}

///|
test "both catalog callback orders cannot replace captured selection or model" {
  let (_, pending) = update_work_handoff(
    code_mode_test_dispatch,
    Resolve,
    handoff_desk_model(),
  )
  for first in [true, false] {
    let incoming = LoadedWorkspaces(
      Ok([
        @desk.workspace(
          id="wrong",
          name="Wrong",
          kind=MoonBook,
          root_path="/wrong",
        ),
      ]),
    )
    let model = if first {
      update(code_mode_test_dispatch, incoming, pending).1
    } else {
      pending
    }
    let (_, ready) = update(
      code_mode_test_dispatch,
      WorkHandoff(
        Resolved(pending.work_handoff.generation, Ok(handoff_desk_fixture())),
      ),
      model,
    )
    let next = if first {
      ready
    } else {
      update(code_mode_test_dispatch, incoming, ready).1
    }
    assert_eq(next.selected_workspace_id, "actual-desk-id")
    assert_eq(next.requested_workspace_id, "actual-desk-id")
    assert_eq(next.work_handoff.canonical.unwrap().model, "captured-c0-model")
  }
}

///|
test "bound view rejects generic hydration after resolver and later turns" {
  let ready = handoff_desk_ready()
  let later = {
    ..code_mode_test_session("S/书", workspace_id="actual-desk-id"),
    model: "later-C1-model",
  }
  let (_, next) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSelectedSession("S/书", Ok(later)),
    ready,
  )
  assert_eq(next.work_handoff.canonical.unwrap().command_id, "C?0")
  assert_eq(next.work_handoff.canonical.unwrap().model, "captured-c0-model")
  assert_eq(
    next.work_handoff.canonical.unwrap().context_path,
    "/book/original/context.md",
  )
}

///|
test "late resolver and file responses are ignored after exit new chat and navigation" {
  let (_, pending) = update_work_handoff(
    code_mode_test_dispatch,
    Resolve,
    handoff_desk_model(),
  )
  for
    exit in [
      WorkHandoff(Exit),
      NewMoonCodeSession,
      SelectActivity(Town),
      SelectWorkspaceMode(Desk),
      SelectMoonCodeSession("newer"),
    ] {
    let (_, departed) = update(code_mode_test_dispatch, exit, pending)
    assert_false(work_handoff_active(departed))
    let (_, late) = update(
      code_mode_test_dispatch,
      WorkHandoff(
        Resolved(pending.work_handoff.generation, Ok(handoff_desk_fixture())),
      ),
      departed,
    )
    assert_eq(
      late.selected_mooncode_session_id,
      departed.selected_mooncode_session_id,
    )
    assert_false(work_handoff_active(late))
  }
  let ready = handoff_desk_ready()
  let (_, next) = update_work_handoff(
    code_mode_test_dispatch,
    Browse("new-folder"),
    ready,
  )
  let (_, late) = update_work_handoff(
    code_mode_test_dispatch,
    FilesLoaded(
      ready.work_handoff.generation,
      ready.work_handoff.files_generation,
      "",
      Err("old error"),
    ),
    next,
  )
  assert_eq(late.work_handoff.directory, "new-folder")
  assert_eq(late.work_handoff.files_error, "")
}

///|
test "bound inspection blocks prompt retry file office drop import and setup mutations" {
  let model = handoff_desk_ready()
  for
    msg in [
      SendMoonCodeMessage("do work"),
      SendMoonCodeGuidance("steer"),
      RetryMoonCodeTurn("S/书", "retry"),
      CancelMoonCodeWork("S/书", "C?0"),
      SourcePane(Save),
      CreateDeskFolder,
      SaveInboxNote,
      ImportLocalFilesToDesk,
      PollDroppedImports,
      LocalFilesPicked(Ok([])),
      ManageMoonClaw("start"),
      SaveMoonClawOpenRouterKey,
    ] {
    assert_true(work_handoff_blocks(msg))
    let (_, next) = update(code_mode_test_dispatch, msg, model)
    assert_eq(next.work_handoff.generation, model.work_handoff.generation)
    assert_eq(next.mooncode_prompt, "")
    assert_true(next.activity is Files)
  }
}

///|
#warnings("-alert_unstable")
test "inspection renders original model context return and files without composer or setup gates" {
  let model = handoff_desk_ready()
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_mooncode_center(code_mode_test_dispatch, model)),
  )
  assert_true(html.contains("captured-c0-model"))
  assert_true(html.contains("/book/original/context.md"))
  assert_true(html.contains("inspection only"))
  assert_true(html.contains("task=T%26one&amp;keep=1#run"))
  assert_true(html.contains("Saved transcript temporarily unavailable"))
  assert_true(html.contains("Workspace files · read only"))
  assert_false(html.contains("mooncode-input"))
  assert_false(html.contains("runtime-setup"))
  assert_false(html.contains("Try another approach"))
}

///|
test "return navigation requires exact task and rejects unsafe credentials protocols" {
  assert_eq(
    handoff_safe_return(
      "https://proj.example/custom?task=T%26one&keep=1#run", "T&one",
    ),
    "https://proj.example/custom?task=T%26one&keep=1#run",
  )
  for
    url in [
      "javascript:alert(1)", "https://user:secret@proj.example/?task=T", "https://proj.example/?task=other",
      "",
    ] {
    assert_eq(handoff_safe_return(url, "T"), "")
  }
}

///|
test "file inspection permits workspace relative context and rejects outside paths" {
  assert_eq(
    handoff_relative_path("/book/", "/book/context.md"),
    Some("context.md"),
  )
  assert_eq(
    handoff_relative_path("/book", "nested/file.md"),
    Some("nested/file.md"),
  )
  assert_eq(handoff_relative_path("/book", "/other/file"), None)
  assert_eq(handoff_relative_path("/book", "../secret"), None)
}

///|
extern "js" fn handoff_install_history(query : String) -> @js.Value =
  #| query => {
  #|   const previous = [globalThis.location, globalThis.history];
  #|   globalThis.location = new URL('https://desk.example/' + query);
  #|   globalThis.history = {replaceState: (_state, _title, url) => {globalThis.location = new URL(url);}};
  #|   return previous;
  #| }

///|
test "canonicalization effect preserves exact lineage and ignores newer navigation" {
  let ready = handoff_desk_ready()
  let scheduler : RequestedSelectionTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  let target = ready.work_handoff.target.unwrap()
  let canonical = ready.work_handoff.canonical.unwrap()
  let previous = handoff_install_history(handoff_desk_query())
  @cmd.Scheduler::add(scheduler, handoff_canonicalize_cmd(target, canonical))
  let loaded = init_model()
  let canonical_workspace = browser_initial_workspace()
  requested_selection_restore_test_history(previous)
  assert_eq(canonical_workspace, "actual-desk-id")
  assert_eq(loaded.work_handoff.target.unwrap(), target)
  let previous = handoff_install_history("?activity=code&session=newer")
  @cmd.Scheduler::add(scheduler, handoff_canonicalize_cmd(target, canonical))
  let selected = browser_initial_mooncode_session()
  let workspace = browser_initial_workspace()
  requested_selection_restore_test_history(previous)
  assert_eq(selected, "newer")
  assert_eq(workspace, "")
}

///|
test "departure effects clear lineage and session on reload without replacing selected new chat" {
  let scheduler : RequestedSelectionTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  for
    navigation in [
      SelectWorkspaceMode(Desk),
      SelectActivity(Town),
      NewMoonCodeSession,
      SelectMoonCodeSession("newer"),
    ] {
    let previous = handoff_install_history(handoff_desk_query())
    let before = handoff_desk_ready()
    let (_, next) = update(code_mode_test_dispatch, navigation, before)
    @cmd.Scheduler::add(scheduler, handoff_departure_cmd(next))
    let reloaded = init_model()
    requested_selection_restore_test_history(previous)
    assert_false(work_handoff_active(reloaded))
    assert_eq(
      reloaded.selected_mooncode_session_id,
      next.selected_mooncode_session_id,
    )
    assert_eq(reloaded.selected_workspace_id, next.selected_workspace_id)
  }
}

///|
#warnings("-alert_unstable")
test "canonical hidden context text requires verified captured digest and mismatch stays explicit" {
  let canonical = {
    ..handoff_desk_ready().work_handoff.canonical.unwrap(),
    context_path: ".moonsuite/products/moonproj/execution-context/hash/context.md",
  }
  let context : Json = {
    "state": "ready",
    "path": canonical.context_path,
    "text": "Captured project requirements",
    "actual_sha256": "captured-bytes-digest",
    "expected_sha256": "captured-bytes-digest",
    "integrity": "verified",
  }
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_work_handoff_context(context, canonical)),
  )
  assert_true(html.contains("Captured project requirements"))
  assert_true(html.contains("verified these bytes"))
  assert_true(html.contains("captured-bytes-digest"))
  assert_false(html.contains("href="))
  for
    state in [
      "absent", "missing", "unavailable", "unsupported_path", "mismatch",
    ] {
    let response : Json = {
      "state": state,
      "message": "Context cannot be read",
      "text": "must not appear",
    }
    let html = @rabbita.render_to_string(
      @rabbita.static_cell(render_work_handoff_context(response, canonical)),
    )
    assert_true(html.contains("Context cannot be read"))
    assert_false(html.contains("must not appear"))
  }
  let unverified : Json = {
    "state": "ready",
    "path": canonical.context_path,
    "text": "must not appear",
    "actual_sha256": "new",
    "expected_sha256": "old",
    "integrity": "mismatch",
  }
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_work_handoff_context(unverified, canonical)),
  )
  assert_false(html.contains("must not appear"))
}

///|
test "transcript parser binds canonical session workspace and root independently of original model" {
  let canonical = handoff_desk_ready().work_handoff.canonical.unwrap()
  let payload : Json = {
    "transcript": { "state": "ready" },
    "session": {
      "id": canonical.session_id,
      "workspace_id": canonical.workspace_id,
      "cwd": canonical.root_path,
      "model": "later-model",
      "status": "done",
      "title": "Saved",
      "queued_count": 0,
      "archived": false,
    },
  }
  let (session, error) = handoff_decode_transcript(canonical, payload)
  assert_eq(error, "")
  assert_eq(session.unwrap().model, "later-model")
  assert_eq(canonical.model, "captured-c0-model")
  let (session, error) = handoff_decode_transcript(
    { ..canonical, session_id: "wrong", },
    payload,
  )
  assert_true(session is None)
  assert_true(error.contains("identity"))
}
