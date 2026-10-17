///|
fn continuation_draft_type(model : Model, text : String) -> Model {
  let (_, next) = update_work_continuation(
    code_mode_test_dispatch,
    Draft(model.work_handoff.continuation.draft_token, text),
    model,
  )
  next
}

///|
extern "js" fn continuation_draft_block_storage(mode : String) -> @js.Value =
  #| mode => { const previous = globalThis.localStorage; globalThis.localStorage = {getItem:key=>{if(mode==='read')throw new Error('blocked');return previous.getItem(key);},setItem:(key,value)=>{if(mode==='write')throw new Error('quota');return previous.setItem(key,value);},removeItem:key=>{if(mode==='remove')throw new Error('blocked');return previous.removeItem(key);}}; return previous; }

///|
extern "js" fn continuation_draft_browser_setup() -> @js.Value =
  #| () => { const names=['confirm','addEventListener','removeEventListener','__moondeskUnsentFollowupUnload','__draftTest']; const old={}; for(const name of names)old[name]=globalThis[name]; delete globalThis.__moondeskUnsentFollowupUnload; const state={allow:false,asks:0,handlers:new Set()};globalThis.__draftTest=state;globalThis.confirm=()=>{state.asks++;return state.allow;};globalThis.addEventListener=(name,fn)=>{if(name==='beforeunload')state.handlers.add(fn);};globalThis.removeEventListener=(name,fn)=>{if(name==='beforeunload')state.handlers.delete(fn);};return old; }

///|
extern "js" fn continuation_draft_browser_cleanup(old : @js.Value) =
  #| old => { for(const name of Object.keys(old)){ if(old[name]===undefined)delete globalThis[name]; else globalThis[name]=old[name]; } }

///|
extern "js" fn continuation_draft_browser_allow() =
  #| () => { globalThis.__draftTest.allow=true; }

///|
extern "js" fn continuation_draft_browser_asks() -> Int32 =
  #| () => globalThis.__draftTest.asks

///|
extern "js" fn continuation_draft_browser_unload() -> Bool =
  #| () => { let prevented=false;const event={preventDefault:()=>{prevented=true;},returnValue:undefined};for(const fn of globalThis.__draftTest.handlers)fn(event);return prevented && event.returnValue===''; }

///|
test "only a genuinely unsaved draft guards departure and cancellation preserves screen and URL" {
  let previous = continuation_desk_storage_setup()
  let browser = continuation_draft_browser_setup()
  let model = continuation_draft_type(continuation_desk_ready(), "Saved draft")
  assert_false(continuation_draft_browser_unload())
  let (_, saved_exit) = update(
    code_mode_test_dispatch,
    WorkHandoff(Exit),
    model,
  )
  assert_false(work_handoff_active(saved_exit))
  assert_eq(continuation_draft_browser_asks(), 0)
  let blocked = continuation_draft_block_storage("write")
  let unsaved = continuation_draft_type(model, "Newest unsaved draft")
  assert_true(continuation_draft_browser_unload())
  let history = handoff_install_history(handoff_desk_query())
  let before_query = work_handoff_initial_query()
  for
    action in [
      WorkHandoff(Exit),
      NewMoonCodeSession,
      SelectWorkspace("another"),
      SelectActivity(Files),
      SelectWorkspaceMode(MoonCode),
    ] {
    let (_, cancelled) = update(code_mode_test_dispatch, action, unsaved)
    assert_true(work_handoff_active(cancelled))
    assert_eq(cancelled.work_handoff.continuation.draft, "Newest unsaved draft")
    assert_eq(cancelled.selected_workspace_id, unsaved.selected_workspace_id)
    assert_eq(work_handoff_initial_query(), before_query)
    assert_true(continuation_draft_browser_unload())
  }
  assert_eq(continuation_draft_browser_asks(), 5)
  continuation_draft_browser_allow()
  let (_, departed) = update(
    code_mode_test_dispatch,
    WorkHandoff(Exit),
    unsaved,
  )
  assert_false(work_handoff_active(departed))
  assert_false(continuation_draft_browser_unload())
  requested_selection_restore_test_history(history)
  continuation_desk_storage_cleanup(blocked)
  let saved = continuation_draft_type(unsaved, "Newest unsaved draft")
  assert_false(work_continuation_draft_unsaved(saved.work_handoff.continuation))
  assert_false(continuation_draft_browser_unload())
  let empty = continuation_draft_type(saved, "")
  let (_, _) = update(code_mode_test_dispatch, NewMoonCodeSession, empty)
  assert_eq(continuation_draft_browser_asks(), 6)
  continuation_draft_browser_cleanup(browser)
  continuation_desk_storage_cleanup(previous)
}

///|
test "unsent draft saves last keystroke immediately and exact reopening never submits" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_draft_type(
    continuation_desk_ready(),
    "  Exact\n书 😀\ttext  ",
  )
  let state = model.work_handoff.continuation
  let target = model.work_handoff.target.unwrap()
  assert_eq(state.draft_status, "saved")
  assert_true(state.operation is Null)
  let restored = work_continuation_restore(target, true)
  assert_eq(restored.draft, state.draft)
  assert_eq(restored.draft_status, "restored")
  assert_eq(restored.phase, "draft")
  assert_true(restored.operation is Null)
  assert_false(restored.admission_possible)
  assert_true(restored.draft_token != state.draft_token)
  assert_eq(work_continuation_read_saved(work_continuation_key(target)), "null")
  let json = @json.parse(
    work_continuation_draft_read(work_continuation_draft_key(target)),
  )
  assert_true(json is Object(fields) && fields.length() == 4)
  for
    key in [
      "continuation_id", "client_turn_id", "credentials", "model", "context", "return_to",
      "approval_id",
    ] {
    assert_true(handoff_field(json, key) is Null)
  }
  continuation_desk_storage_cleanup(previous)
}

///|
test "unsent draft survives Exit New chat workspace activity and browser reopen" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_draft_type(
    continuation_desk_ready(),
    "Keep across departure",
  )
  let target = model.work_handoff.target.unwrap()
  let (_, exited) = update_work_handoff(code_mode_test_dispatch, Exit, model)
  assert_false(work_handoff_active(exited))
  for
    action in [
      NewMoonCodeSession,
      SelectWorkspace("another"),
      SelectActivity(Files),
      SelectWorkspaceMode(MoonCode),
    ] {
    let (_, left) = update(code_mode_test_dispatch, action, model)
    assert_false(work_handoff_active(left))
    assert_eq(
      work_continuation_restore(target, true).draft,
      "Keep across departure",
    )
  }
  let query = handoff_desk_query().replace(
    old="work_mode=inspect",
    new="work_mode=follow_up",
  )
  assert_eq(
    work_handoff_from_query(query).continuation.draft,
    "Keep across departure",
  )
  assert_eq(work_handoff_from_query("").continuation.draft, "")
  assert_eq(work_continuation_restore(target, false).draft, "")
  assert_eq(
    work_continuation_restore(target, true).draft,
    "Keep across departure",
  )
  continuation_desk_storage_cleanup(previous)
}

///|
test "draft identity isolates task run session original command and book even under poisoned key" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_draft_type(
    continuation_desk_ready(),
    "Only this work",
  )
  let target = model.work_handoff.target.unwrap()
  let saved = work_continuation_draft_read(work_continuation_draft_key(target))
  for
    other in [
      { ..target, task_id: "other-task", },
      { ..target, run_id: "other-run", },
      { ..target, session_id: "other-session", },
      { ..target, command_id: "other-command", },
      { ..target, book_root: "/other-book", },
    ] {
    assert_eq(work_continuation_restore(other, true).draft, "")
    assert_true(
      work_continuation_draft_write(work_continuation_draft_key(other), saved),
    )
    let rejected = work_continuation_restore(other, true)
    assert_eq(rejected.draft, "")
    assert_eq(rejected.draft_status, "invalid")
    assert_true(rejected.operation is Null)
  }
  continuation_desk_storage_cleanup(previous)
}

///|
test "stale editor input discard prior and navigated callback cannot change a reopened draft" {
  let previous = continuation_desk_storage_setup()
  let old = continuation_draft_type(continuation_desk_ready(), "Old text")
  let target = old.work_handoff.target.unwrap()
  let reopened = {
    ..old,
    work_handoff: {
      ..old.work_handoff,
      continuation: work_continuation_restore(target, true),
    },
  }
  let current = continuation_draft_type(reopened, "New text")
  let token = old.work_handoff.continuation.draft_token
  for
    action in [
      Draft(token, "stale"),
      DiscardDraft(token),
      Prior(token, target.command_id),
    ] {
    let (_, next) = update_work_continuation(
      code_mode_test_dispatch, action, current,
    )
    assert_eq(next.work_handoff.continuation.draft, "New text")
    assert_eq(work_continuation_restore(target, true).draft, "New text")
  }
  let history = handoff_install_history("?activity=code&session=newer")
  let ignored = continuation_draft_type(
    current, "Must not save after navigation",
  )
  requested_selection_restore_test_history(history)
  assert_eq(ignored.work_handoff.continuation.draft, "New text")
  assert_eq(work_continuation_restore(target, true).draft, "New text")
  continuation_desk_storage_cleanup(previous)
}

///|
test "empty draft explicit discard and blocked discard have honest persistence status" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_draft_type(
    continuation_desk_ready(),
    "Keep until intentional removal",
  )
  let target = model.work_handoff.target.unwrap()
  let blocked = continuation_draft_block_storage("remove")
  let (_, retained) = update_work_continuation(
    code_mode_test_dispatch,
    DiscardDraft(model.work_handoff.continuation.draft_token),
    model,
  )
  assert_eq(
    retained.work_handoff.continuation.draft,
    model.work_handoff.continuation.draft,
  )
  assert_eq(retained.work_handoff.continuation.draft_status, "saved")
  assert_true(
    retained.work_handoff.continuation.error.contains("Could not discard"),
  )
  assert_false(
    work_continuation_draft_unsaved(retained.work_handoff.continuation),
  )
  continuation_desk_storage_cleanup(blocked)
  let (_, discarded) = update_work_continuation(
    code_mode_test_dispatch,
    DiscardDraft(retained.work_handoff.continuation.draft_token),
    retained,
  )
  assert_eq(discarded.work_handoff.continuation.draft, "")
  assert_eq(discarded.work_handoff.continuation.draft_status, "empty")
  assert_eq(work_continuation_restore(target, true).draft, "")
  let typed = continuation_draft_type(discarded, "Then clear the textarea")
  let empty = continuation_draft_type(typed, "")
  assert_eq(empty.work_handoff.continuation.draft_status, "empty")
  assert_eq(work_continuation_restore(target, true).draft, "")
  continuation_desk_storage_cleanup(previous)
}

///|
test "blocked or full storage preserves typed text and never claims locally saved" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_draft_type(
    continuation_desk_ready(),
    "Older local text",
  )
  let target = model.work_handoff.target.unwrap()
  let blocked = continuation_draft_block_storage("write")
  let unsaved = continuation_draft_type(model, "Newest in-memory text")
  assert_eq(unsaved.work_handoff.continuation.draft, "Newest in-memory text")
  assert_eq(unsaved.work_handoff.continuation.draft_status, "storage_failed")
  assert_true(
    work_continuation_draft_status(unsaved.work_handoff.continuation).contains(
      "copy your text",
    ),
  )
  continuation_desk_storage_cleanup(blocked)
  assert_eq(work_continuation_restore(target, true).draft, "Older local text")
  let retried = continuation_draft_type(unsaved, "Newest in-memory text")
  assert_eq(retried.work_handoff.continuation.draft_status, "saved")
  let blocked = continuation_draft_block_storage("read")
  let missing = work_continuation_restore(target, true)
  assert_eq(missing.draft_status, "storage_failed")
  assert_eq(missing.draft, "")
  continuation_desk_storage_cleanup(blocked)
  assert_eq(
    work_continuation_restore(target, true).draft,
    "Newest in-memory text",
  )
  continuation_desk_storage_cleanup(previous)
}

///|
test "corrupted wrong schema unknown fields and oversize drafts are not restored" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let unknown = work_continuation_draft_body(target, "text", target.command_id)
  if unknown is Object(fields) {
    fields["credentials"] = "must never import"
  }
  for
    raw in [
      "{bad",
      "null",
      "[]",
      "true",
      "{\"schema\":\"old\"}",
      unknown.stringify(),
      work_continuation_draft_body(target, "x".repeat(65537), target.command_id).stringify(),
    ] {
    assert_true(
      work_continuation_draft_write(work_continuation_draft_key(target), raw),
    )
    let restored = work_continuation_restore(target, true)
    assert_eq(restored.draft, "")
    assert_eq(restored.draft_status, "invalid")
    assert_true(restored.operation is Null)
  }
  let oversized = continuation_draft_type(model, "x".repeat(65537))
  assert_eq(oversized.work_handoff.continuation.draft.length(), 65537)
  assert_eq(oversized.work_handoff.continuation.draft_status, "too_large")
  continuation_desk_storage_cleanup(previous)
}

///|
test "selected historical prior persists but cannot submit until verified again" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let record = continuation_desk_record(
    work_continuation_submit_body(
      target,
      model.work_handoff.continuation,
      "K-prior",
    ),
  )
  let model = {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      continuation: { ..model.work_handoff.continuation, records: [record], },
    },
  }
  let (_, chosen) = update_work_continuation(
    code_mode_test_dispatch,
    Prior(model.work_handoff.continuation.draft_token, "C1"),
    model,
  )
  let restored = work_continuation_restore(target, true)
  assert_eq(restored.prior_command, "C1")
  assert_eq(restored.draft, chosen.work_handoff.continuation.draft)
  let reopened = {
    ..model,
    work_handoff: { ..model.work_handoff, continuation: restored, },
  }
  let (_, blocked) = update_work_continuation(
    code_mode_test_dispatch,
    Submit,
    reopened,
  )
  assert_true(blocked.work_handoff.continuation.operation is Null)
  assert_true(blocked.work_handoff.continuation.error.contains("not verified"))
  let verified = work_continuation_reconcile(target, restored, {
    "continuations": [record],
  })
  assert_true(work_continuation_draft_prior_valid(target, verified))
  continuation_desk_storage_cleanup(previous)
}

///|
test "submit uncertain retry and conflict retain draft while exact verified acceptance retires only matching text" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_draft_type(
    continuation_desk_ready(),
    "Exact unsent draft",
  )
  let target = model.work_handoff.target.unwrap()
  let (save, saving) = update_work_continuation(
    code_mode_test_dispatch,
    Submit,
    model,
  )
  let scheduler : RequestedSelectionTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  @cmd.Scheduler::add(scheduler, save)
  let operation = saving.work_handoff.continuation.operation
  let restored = work_continuation_restore(target, true)
  assert_eq(restored.phase, "recovering")
  assert_eq(restored.operation, operation)
  assert_eq(restored.draft, "Exact unsent draft")
  let responses : Array[Json] = [
    { "continuation_state": "not_found", "continuations": [] },
    { "continuation_state": "conflict", "continuations": [] },
    { "continuations": [] },
  ]
  for response in responses {
    let waiting = work_continuation_draft_retire(
      target,
      work_continuation_reconcile(target, restored, response),
    )
    assert_true(waiting.phase != "saved")
    assert_true(
      work_continuation_draft_read(work_continuation_draft_key(target)).contains(
        "Exact unsent draft",
      ),
    )
  }
  let accepted = work_continuation_reconcile(
    target,
    restored,
    continuation_desk_response(operation, continuation_desk_record(operation)),
  )
  let blocked = continuation_draft_block_storage("remove")
  assert_eq(
    work_continuation_draft_retire(target, accepted).draft_status,
    "retire_failed",
  )
  continuation_desk_storage_cleanup(blocked)
  let retired = work_continuation_draft_retire(target, accepted)
  assert_eq(retired.draft_status, "retired")
  assert_eq(
    work_continuation_draft_read(work_continuation_draft_key(target)),
    "missing",
  )
  assert_eq(work_continuation_restore(target, true).operation, operation)
  let newer = continuation_draft_type(model, "Newer draft from another editor")
  ignore(work_continuation_draft_retire(target, accepted))
  assert_true(
    work_continuation_draft_read(work_continuation_draft_key(target)).contains(
      newer.work_handoff.continuation.draft,
    ),
  )
  let (_, next) = update_work_continuation(code_mode_test_dispatch, New, {
    ..model,
    work_handoff: { ..model.work_handoff, continuation: retired, },
  })
  assert_eq(
    next.work_handoff.continuation.draft,
    "Newer draft from another editor",
  )
  assert_true(next.work_handoff.continuation.operation is Null)
  continuation_desk_storage_cleanup(previous)
}

///|
test "draft composer exposes saved unsaved restored and discard status without automatic action" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_draft_type(
    continuation_desk_ready(),
    "Visible draft",
  )
  for status in ["saved", "restored", "storage_failed", "invalid"] {
    let state = { ..model.work_handoff.continuation, draft_status: status, }
    let html = render_test_dom(
      @rabbita.static_cell(
        render_work_continuation(
          code_mode_test_dispatch,
          { ..model.work_handoff, continuation: state, },
          model.work_handoff.target.unwrap(),
          model.work_handoff.canonical.unwrap(),
        ),
      ),
    )
    assert_true(html.contains(work_continuation_draft_status(state)))
    assert_true(html.contains("Discard unsent draft"))
    assert_true(html.contains("aria-live=\"polite\""))
    if status == "storage_failed" {
      assert_true(html.contains("Retry saving draft locally"))
    }
  }
  continuation_desk_storage_cleanup(previous)
}
