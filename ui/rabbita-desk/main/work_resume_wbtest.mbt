///|
fn resume_test_scope() -> Json {
  ["/suite", "/suite/books", "/suite/books", "actual-desk-id", "/book"].to_json()
}

///|
fn resume_test_response() -> Json {
  guard handoff_desk_fixture() is Object(fields) else { abort("fixture") }
  fields["resume_scope"] = resume_test_scope()
  Json::object(fields)
}

///|
fn resume_test_resolve(
  model : Model,
  response~ : Json = resume_test_response(),
) -> Model {
  let (_, pending) = update(
    code_mode_test_dispatch,
    WorkHandoff(Resolve),
    model,
  )
  let (_, ready) = update(
    code_mode_test_dispatch,
    WorkHandoff(Resolved(pending.work_handoff.generation, Ok(response))),
    pending,
  )
  ready
}

///|
fn resume_test_library(model : Model) -> Model {
  {
    ..model,
    work_handoff: empty_work_handoff(),
    workspace_mode: Desk,
    selected_workspace_id: "actual-desk-id",
    workspace_suite_root_path: "/suite",
    workspace_books_root_path: "/suite/books",
    workspace_library_path: "/suite/books",
    workspaces: [
      @desk.workspace(
        id="actual-desk-id",
        name="Campaign",
        root_path="/book",
        kind=MoonBook,
      ),
      @desk.workspace(
        id="other",
        name="Other",
        root_path="/book-b",
        kind=MoonBook,
      ),
    ],
  }
}

///|
fn resume_test_rebind(model : Model) -> Model {
  sync_work_resume(model, model, ToggleCommand)
}

///|
test "Resume work cold boot saves only after exact host resolution and reloads scoped history" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let model = handoff_desk_model()
  assert_true(model.work_resume.entries.is_empty())
  let (_, pending) = update(
    code_mode_test_dispatch,
    WorkHandoff(Resolve),
    model,
  )
  assert_true(pending.work_resume.entries.is_empty())
  let (_, ready) = update(
    code_mode_test_dispatch,
    WorkHandoff(
      Resolved(pending.work_handoff.generation, Ok(resume_test_response())),
    ),
    pending,
  )
  assert_eq(ready.work_resume.entries.length(), 1)
  assert_eq(ready.work_resume.scope, resume_test_scope().stringify())
  let ordinary = resume_test_rebind(resume_test_library(init_model()))
  assert_eq(ordinary.work_resume.entries, ready.work_resume.entries)
  let again = resume_test_resolve(ready)
  assert_eq(again.work_resume.entries.length(), 1)
}

///|
test "Resume work legacy missing or mismatched host scope keeps work usable without persistence" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let legacy = resume_test_resolve(
    handoff_desk_model(),
    response=handoff_desk_fixture(),
  )
  assert_eq(legacy.work_handoff.phase, "ready")
  assert_true(legacy.work_resume.entries.is_empty())
  assert_eq(legacy.work_resume.scope, "")
  let canonical = legacy.work_handoff.canonical.unwrap()
  for
    scope in [
      ["/suite", "/books", "/books", "other", "/book"].to_json(),
      ["/suite", "/books", "/books", "actual-desk-id", "/other"].to_json(),
      ["", "/books", "/books", "actual-desk-id", "/book"].to_json(),
    ] {
    assert_eq(work_resume_host_scope({ "resume_scope": scope }, canonical), "")
  }
  let failed = resume_test_resolve(
    handoff_desk_model(),
    response=handoff_desk_fixture(command="wrong"),
  )
  assert_eq(failed.work_handoff.phase, "unavailable")
  assert_true(failed.work_resume.entries.is_empty())
}

///|
test "Resume work preserves exact existing draft but does not submit or select a new result" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve({
    ..handoff_desk_model(),
    work_handoff: work_handoff_from_query(
      handoff_desk_query().replace_all(
        old="work_mode=inspect",
        new="work_mode=follow_up",
      ),
    ),
  })
  let typed = continuation_draft_type(
    ready, "Revise the introduction, keeping the evidence 书",
  )
  let query = handoff_text(typed.work_resume.entries[0], "query")
  let restored = work_handoff_from_query(query)
  assert_eq(restored.phase, "waiting")
  assert_eq(restored.continuation.draft, typed.work_handoff.continuation.draft)
  assert_eq(restored.continuation.phase, "draft")
  assert_true(restored.continuation.operation is Null)
  assert_false(restored.continuation.admission_possible)
  assert_eq(restored.continuation.selected_return, "")
  assert_eq(
    restored.target.unwrap().task_id,
    typed.work_handoff.target.unwrap().task_id,
  )
  assert_eq(restored.target.unwrap().command_id, "C?0")
}

///|
test "Resume work isolates another Book changed library and removed catalog Book" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve(handoff_desk_model())
  let ordinary = resume_test_rebind(resume_test_library(ready))
  let other = resume_test_rebind({ ..ordinary, selected_workspace_id: "other", })
  assert_true(other.work_resume.entries.is_empty())
  let changed = resume_test_rebind({
    ..ordinary,
    workspace_library_path: "/elsewhere",
  })
  assert_true(changed.work_resume.entries.is_empty())
  let removed = resume_test_rebind({ ..ordinary, workspaces: [], })
  assert_eq(removed.work_resume.scope, "")
  assert_true(removed.work_resume.entries.is_empty())
  let returned = resume_test_rebind(resume_test_library(other))
  assert_eq(returned.work_resume.entries.length(), 1)
  let stale_forget = forget_resumable_work(
    other,
    ordinary.work_resume.scope,
    None,
  )
  assert_eq(stale_forget.work_resume.entries, other.work_resume.entries)
  assert_eq(work_resume_load(ordinary.work_resume.scope).entries.length(), 1)
}

///|
test "Resume work remembers exact output identity without converting unavailable references" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let model = handoff_desk_model()
  let canonical = work_handoff_decode(
    model.work_handoff.target.unwrap(),
    handoff_desk_fixture(),
  ).unwrap()
  let scoped = {
    ..model,
    work_handoff: { ..model.work_handoff, output_hint: output_desk_hint(), },
  }
  let missing = resume_test_resolve(scoped)
  assert_true(missing.work_resume.entries.is_empty())
  guard resume_test_response() is Object(fields) else { fail("fixture") }
  fields["output"] = output_desk_response(canonical)
  let ready = resume_test_resolve(scoped, response=Json::object(fields))
  assert_eq(ready.work_resume.entries.length(), 1)
  let query = handoff_text(ready.work_resume.entries[0], "query")
  let reopened = work_handoff_from_query(query)
  assert_eq(reopened.output_hint, output_desk_hint())
  assert_eq(reopened.target.unwrap().command_id, "C?0")
  assert_true(
    handoff_text(ready.work_resume.entries[0], "title").contains(
      "results/a 书.md",
    ),
  )
}

///|
test "Resume work missing command readback remains unavailable without erasing the saved shortcut" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve(handoff_desk_model())
  let saved = ready.work_resume.entries[0]
  let model = {
    ..init_model(),
    work_handoff: work_handoff_from_query(handoff_text(saved, "query")),
  }
  let missing = resume_test_resolve(model, response={
    "schema": "moondesk.work-handoff.v1",
    "state": "command_not_found",
    "message": "Retain this target and retry",
  })
  assert_eq(missing.work_handoff.phase, "unavailable")
  assert_true(missing.work_handoff.canonical is None)
  assert_true(missing.work_handoff.continuation.operation is Null)
  assert_eq(work_resume_load(ready.work_resume.scope).entries[0], saved)
}

///|
test "Resume work rejects old malformed duplicate foreign and hostile routes" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve(handoff_desk_model())
  let scope = ready.work_resume.scope
  let item = ready.work_resume.entries[0]
  let query = handoff_text(item, "query")
  for
    malformed in [
      "https://evil.invalid/",
      query + "&token=secret",
      query + "&command=other",
      query.replace_all(old="book_root=%2Fbook%2F", new="book_root=%2Fbook-b"),
      query.replace_all(old="work_mode=inspect", new="work_mode=execute"),
      query + "#unexpected",
    ] {
    assert_eq(work_resume_checked_query(malformed, scope), "")
  }
  let invalid : Array[Json] = [
    { "schema": "legacy", "scope": scope, "entries": [item] },
    { "schema": "moondesk.work-resume.v1", "scope": "other", "entries": [item] },
    {
      "schema": "moondesk.work-resume.v1",
      "scope": scope,
      "entries": [item, item],
    },
  ]
  for saved in invalid {
    assert_true(
      work_continuation_draft_write(work_resume_key(scope), saved.stringify()),
    )
    let restored = work_resume_load(scope)
    assert_eq(restored.status, "invalid")
    assert_true(restored.entries.is_empty())
  }
  let cleared = forget_resumable_work(ready, scope, None)
  assert_eq(cleared.work_resume.status, "saved")
  assert_true(work_resume_load(scope).entries.is_empty())
}

///|
test "Resume work does not retain arbitrary return tokens or full prompts" {
  let model = handoff_desk_model()
  let target = model.work_handoff.target.unwrap()
  let query = work_resume_make_query(
    {
      ..target,
      return_to: "https://proj.example/custom?task=T%26one&token=secret#private",
    },
    false,
    Json::null(),
  )
  assert_false(query.contains("secret"))
  assert_false(query.contains("private"))
  assert_true(query.contains("%2Fcustom%3Ftask%3DT%2526one"))
  assert_eq(
    work_resume_checked_query(query, resume_test_scope().stringify()),
    query,
  )
  let unsafe_return = work_resume_make_query(
    { ..target, return_to: "https://user:secret@proj.example/?task=T%26one", },
    false,
    Json::null(),
  )
  assert_false(unsafe_return.contains("secret"))
}

///|
test "Resume work bounded latest-first history merges another tab without collapsing commands" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve(handoff_desk_model())
  let base = ready.work_handoff.target.unwrap()
  for i in 0..<15 {
    let model = {
      ..ready,
      work_handoff: {
        ..ready.work_handoff,
        target: Some({
          ..base,
          task_id: "task-" + i.to_string(),
          return_to: "",
        }),
      },
    }
    ignore(work_resume_capture(model, ready.work_resume))
  }
  let result = work_resume_load(ready.work_resume.scope)
  assert_eq(result.entries.length(), 12)
  assert_true(handoff_text(result.entries[0], "query").contains("task-14"))
  assert_true(handoff_text(result.entries[11], "query").contains("task-3"))
}

///|
test "Resume work blocked quota and forget failures keep work and saved drafts intact" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve(handoff_desk_model())
  let blocked = continuation_draft_block_storage("write")
  let failed = forget_resumable_work(ready, ready.work_resume.scope, None)
  assert_eq(failed.work_resume.status, "storage_failed")
  assert_eq(failed.work_resume.entries.length(), 1)
  assert_eq(failed.work_handoff.phase, "ready")
  continuation_desk_storage_cleanup(blocked)
  assert_eq(work_resume_load(ready.work_resume.scope).entries.length(), 1)
  let blocked = continuation_draft_block_storage("read")
  assert_eq(work_resume_load(ready.work_resume.scope).status, "unavailable")
  let resolved = resume_test_resolve(handoff_desk_model())
  assert_eq(resolved.work_handoff.phase, "ready")
  assert_eq(resolved.work_resume.status, "unavailable")
  continuation_desk_storage_cleanup(blocked)
}

///|
#warnings("-alert_unstable")
test "Resume work HTML labels stale observation new tab and exact scope forget honestly" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve(handoff_desk_model())
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_work_resume(code_mode_test_dispatch, ready)),
  )
  assert_true(html.contains("book · captured work"))
  assert_true(html.contains("Last observed original command"))
  assert_true(html.contains("not a current or acceptance status"))
  assert_true(html.contains("new tab"))
  assert_true(html.contains("target=\"_blank\""))
  assert_true(html.contains("noopener noreferrer"))
  assert_true(html.contains("Forget shortcut"))
  let legacy = resume_test_resolve(
    handoff_desk_model(),
    response=handoff_desk_fixture(),
  )
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_work_resume(code_mode_test_dispatch, legacy)),
  )
  assert_true(html.contains("no shortcut is saved"))
}

///|
test "Resume work stale callbacks cannot restore a forgotten shortcut or cross to newer work" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve(handoff_desk_model())
  let (_, cleared) = update(
    code_mode_test_dispatch,
    ClearResumableWork(ready.work_resume.scope),
    ready,
  )
  assert_true(cleared.work_resume.entries.is_empty())
  let (_, duplicate) = update(
    code_mode_test_dispatch,
    WorkHandoff(
      Resolved(ready.work_handoff.generation, Ok(resume_test_response())),
    ),
    cleared,
  )
  assert_true(duplicate.work_resume.entries.is_empty())
  let (_, loading) = update(
    code_mode_test_dispatch,
    WorkHandoff(Resolve),
    duplicate,
  )
  let (_, stale) = update(
    code_mode_test_dispatch,
    WorkHandoff(
      Resolved(ready.work_handoff.generation, Ok(resume_test_response())),
    ),
    loading,
  )
  assert_eq(stale.work_handoff.phase, "loading")
  assert_true(stale.work_resume.entries.is_empty())
}

///|
test "Resume work forget preserves submitted recovery and unsent draft storage" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve({
    ..handoff_desk_model(),
    work_handoff: work_handoff_from_query(
      handoff_desk_query().replace_all(
        old="work_mode=inspect",
        new="work_mode=follow_up",
      ),
    ),
  })
  let typed = continuation_draft_type(ready, "Keep this unsent instruction")
  let target = typed.work_handoff.target.unwrap()
  let body = work_continuation_submit_body(
    target,
    typed.work_handoff.continuation,
    "operation-pending",
  )
  assert_true(
    work_continuation_store(work_continuation_key(target), body.stringify()),
  )
  let (_, cleared) = update(
    code_mode_test_dispatch,
    ClearResumableWork(typed.work_resume.scope),
    typed,
  )
  assert_true(cleared.work_resume.entries.is_empty())
  assert_eq(
    cleared.work_handoff.continuation.draft,
    typed.work_handoff.continuation.draft,
  )
  assert_eq(
    work_continuation_read_saved(work_continuation_key(target)),
    body.stringify(),
  )
  assert_true(
    work_continuation_draft_read(work_continuation_draft_key(target)).contains(
      "Keep this unsent instruction",
    ),
  )
}

///|
test "Resume work pending refresh cannot undo successful forget and fresh refresh still remembers" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  for clear in [false, true] {
    let ready = resume_test_resolve(handoff_desk_model())
    let (_, loading) = update(
      code_mode_test_dispatch,
      WorkHandoff(Resolve),
      ready,
    )
    let action = if clear {
      ClearResumableWork(ready.work_resume.scope)
    } else {
      ForgetResumableWork(
        ready.work_resume.scope,
        handoff_text(ready.work_resume.entries[0], "query"),
      )
    }
    let (_, forgotten) = update(code_mode_test_dispatch, action, loading)
    assert_true(forgotten.work_resume.entries.is_empty())
    let (_, completed) = update(
      code_mode_test_dispatch,
      WorkHandoff(
        Resolved(loading.work_handoff.generation, Ok(resume_test_response())),
      ),
      forgotten,
    )
    assert_eq(completed.work_handoff.phase, "ready")
    assert_true(completed.work_resume.entries.is_empty())
    assert_true(work_resume_load(ready.work_resume.scope).entries.is_empty())
    let refreshed = resume_test_resolve(completed)
    assert_eq(refreshed.work_resume.entries.length(), 1)
  }
}

///|
test "Resume work failed forget does not suppress a pending successful refresh" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve(handoff_desk_model())
  let (_, loading) = update(
    code_mode_test_dispatch,
    WorkHandoff(Resolve),
    ready,
  )
  let blocked = continuation_draft_block_storage("write")
  let (_, failed) = update(
    code_mode_test_dispatch,
    ClearResumableWork(ready.work_resume.scope),
    loading,
  )
  assert_eq(failed.work_resume.status, "storage_failed")
  assert_eq(failed.work_resume.forgotten_read, "")
  continuation_desk_storage_cleanup(blocked)
  let (_, completed) = update(
    code_mode_test_dispatch,
    WorkHandoff(
      Resolved(loading.work_handoff.generation, Ok(resume_test_response())),
    ),
    failed,
  )
  assert_eq(completed.work_resume.entries.length(), 1)
}

///|
#warnings("-alert_unstable")
test "Resume work same-named output versions expose distinct command and evidence details" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = resume_test_resolve(handoff_desk_model())
  let target = ready.work_handoff.target.unwrap()
  let entries = ["C1", "C2"].map(command => {
    let output : Json = {
      "command_id": command,
      "path": "results/report.md",
      "evidence_id": "evidence-" + command,
    }
    let item : Json = {
      "schema": "moondesk.work-resume-entry.v1",
      "query": work_resume_make_query(target, false, output),
      "title": "Output · results/report.md",
      "observed": "delivered / runtime-completed",
    }
    item
  })
  let model = { ..ready, work_resume: { ..ready.work_resume, entries, }, }
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_work_resume(code_mode_test_dispatch, model)),
  )
  assert_true(html.contains("Output command / evidence: C1 / evidence-C1"))
  assert_true(html.contains("Output command / evidence: C2 / evidence-C2"))
  assert_true(html.contains("work_output_command=C1"))
  assert_true(html.contains("work_output_command=C2"))
}
