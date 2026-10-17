///|
fn human_revision_test_ready() -> Model {
  let model = handoff_desk_ready()
  {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      output_hint: output_desk_hint(),
      output: output_desk_response(model.work_handoff.canonical.unwrap()),
      human_revision: empty_work_human_revision(enabled=true),
    },
  }
}

///|
fn human_revision_test_action(
  model : Model,
  action : WorkHumanRevisionMsg,
) -> Model {
  update(code_mode_test_dispatch, WorkHandoff(HumanRevision(action)), model).1
}

///|
fn human_revision_test_open(model : Model) -> Model {
  let opening = human_revision_test_action(model, RevisionOpen)
  human_revision_test_action(
    opening,
    RevisionReplied(
      opening.work_handoff.generation,
      opening.work_handoff.human_revision.request,
      "open",
      Ok({
        "schema": "moondesk.human-revision-editor.v1",
        "state": "ready",
        "source": work_continuation_source(model.work_handoff.target.unwrap()),
        "output": model.work_handoff.output_hint,
        "workspace_id": model.work_handoff.canonical.unwrap().workspace_id,
        "content": "original current file",
        "base_digest": "base-current-digest",
      }),
    ),
  )
}

///|
fn human_revision_test_saved(model : Model) -> Json {
  let state = model.work_handoff.human_revision
  let target = model.work_handoff.target.unwrap()
  let canonical = model.work_handoff.canonical.unwrap()
  let id = handoff_text(state.operation, "revision_id")
  {
    "schema": "moondesk.human-revision-editor.v1",
    "state": "saved",
    "content": state.draft,
    "revision": {
      "schema": "moonproj.human-revision.v1",
      "state": "saved",
      "revision_id": id,
      "task_id": target.task_id,
      "original_run_id": target.run_id,
      "session_id": target.session_id,
      "original_command_id": target.command_id,
      "workspace": canonical.root_path,
      "workspace_id": canonical.workspace_id,
      "output": model.work_handoff.output_hint,
      "author_type": "human",
      "capture_scope": "immutable_human_revision",
      "base": {
        "scope": "current_workspace_bytes_at_edit",
        "sha256": "base-current-digest",
      },
      "content": {
        "path": ".moonsuite/products/moonproj/human-revisions/" +
        id +
        "/content.txt",
        "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "size_bytes": work_human_revision_utf8_length(state.draft),
      },
      "created_at": "fixture",
    },
  }
}

///|
test "human revision exact output permits only explicit bound edit operation" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let ready = human_revision_test_ready()
  assert_true(work_handoff_blocks(SourcePane(Save)))
  let untouched = update(code_mode_test_dispatch, SourcePane(Save), ready).1
  assert_eq(untouched.work_handoff.human_revision.phase, "idle")
  let opened = human_revision_test_open(ready)
  assert_eq(opened.work_handoff.human_revision.phase, "editing")
  assert_eq(
    opened.work_handoff.human_revision.baseline,
    "original current file",
  )
  assert_eq(opened.work_handoff.continuation.selected_return, "")
  for accepted in ["true", "", "false"] {
    let state = work_handoff_from_query(
      handoff_desk_query() +
      "&work_output_command=C1&work_output_path=results%2Fa+%E4%B9%A6.md&work_output_evidence=E1&work_accepted=" +
      accepted,
    )
    assert_eq(state.human_revision.enabled, accepted == "false")
  }
}

///|
test "human save request is serialized retained and singleflight across transport failure and restart" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let edited = human_revision_test_action(
    human_revision_test_open(human_revision_test_ready()),
    RevisionDraft("Human 书 😀\n"),
  )
  let saving = human_revision_test_action(edited, RevisionSave)
  let state = saving.work_handoff.human_revision
  assert_eq(state.phase, "saving")
  let body = @json.parse(state.operation.stringify())
  assert_eq(handoff_text(body, "content"), "Human 书 😀\n")
  assert_eq(handoff_text(body, "expected_content"), "original current file")
  assert_eq(handoff_field(body, "output"), saving.work_handoff.output_hint)
  for key in ["receipt", "command_id", "model", "promotion"] {
    assert_true(handoff_field(body, key) is Null)
  }
  let duplicate = human_revision_test_action(saving, RevisionSave)
  assert_eq(duplicate.work_handoff.human_revision.request, state.request)
  let late_edit = human_revision_test_action(
    saving,
    RevisionDraft("must not replace in flight"),
  )
  assert_eq(late_edit.work_handoff.human_revision.draft, state.draft)
  let failed = human_revision_test_action(
    saving,
    RevisionReplied(
      saving.work_handoff.generation,
      state.request,
      "save",
      Err("network"),
    ),
  )
  assert_eq(failed.work_handoff.human_revision.phase, "retry")
  let restored = work_human_revision_restore(
    saving.work_handoff.target.unwrap(),
    saving.work_handoff.output_hint,
    true,
  )
  assert_eq(restored.phase, "retry")
  assert_eq(restored.operation, state.operation)
  let retry = human_revision_test_action(failed, RevisionSave)
  assert_eq(retry.work_handoff.human_revision.operation, state.operation)
  let saved = human_revision_test_action(
    retry,
    RevisionReplied(
      retry.work_handoff.generation,
      retry.work_handoff.human_revision.request,
      "save",
      Ok(human_revision_test_saved(retry)),
    ),
  )
  assert_eq(saved.work_handoff.human_revision.phase, "saved")
  assert_eq(saved.work_handoff.continuation.selected_return, "")
  let reopened = human_revision_test_action(saved, RevisionOpen)
  let failed_open = human_revision_test_action(
    reopened,
    RevisionReplied(
      reopened.work_handoff.generation,
      reopened.work_handoff.human_revision.request,
      "open",
      Err("file no longer available"),
    ),
  )
  assert_eq(failed_open.work_handoff.human_revision.phase, "saved")
  assert_eq(
    failed_open.work_handoff.human_revision.revision,
    saved.work_handoff.human_revision.revision,
  )
}

///|
test "failed save capture keeps draft and conflict needs explicit new baseline and revision identity" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let saving = human_revision_test_action(
    human_revision_test_action(
      human_revision_test_open(human_revision_test_ready()),
      RevisionDraft("my draft"),
    ),
    RevisionSave,
  )
  let state = saving.work_handoff.human_revision
  let failure = human_revision_test_action(
    saving,
    RevisionReplied(
      saving.work_handoff.generation,
      state.request,
      "save",
      Ok({
        "schema": "moondesk.human-revision-editor.v1",
        "state": "capture_unavailable",
        "message": "saved outcome retained; capture failed",
      }),
    ),
  )
  assert_eq(failure.work_handoff.human_revision.phase, "retry")
  assert_eq(failure.work_handoff.human_revision.draft, "my draft")
  assert_true(failure.work_handoff.human_revision.revision is Null)
  let conflict = human_revision_test_action(
    saving,
    RevisionReplied(
      saving.work_handoff.generation,
      state.request,
      "save",
      Ok({
        "schema": "moondesk.human-revision-editor.v1",
        "state": "conflict",
        "current_content": "",
      }),
    ),
  )
  assert_eq(conflict.work_handoff.human_revision.current_content, Some(""))
  assert_eq(
    human_revision_test_action(conflict, RevisionSave).work_handoff.human_revision.phase,
    "conflict",
  )
  let rebased = human_revision_test_action(conflict, RevisionRebase)
  assert_eq(rebased.work_handoff.human_revision.baseline, "")
  assert_eq(rebased.work_handoff.human_revision.draft, "my draft")
  let new_save = human_revision_test_action(rebased, RevisionSave)
  assert_true(
    handoff_text(new_save.work_handoff.human_revision.operation, "revision_id") !=
    handoff_text(state.operation, "revision_id"),
  )
}

///|
test "human revision late response cannot replace newer navigation and wrong manifest cannot report success" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let saving = human_revision_test_action(
    human_revision_test_action(
      human_revision_test_open(human_revision_test_ready()),
      RevisionDraft("human"),
    ),
    RevisionSave,
  )
  let result = human_revision_test_saved(saving)
  let newer = {
    ..saving,
    work_handoff: {
      ..saving.work_handoff,
      generation: saving.work_handoff.generation + 1,
    },
  }
  let ignored = human_revision_test_action(
    newer,
    RevisionReplied(
      saving.work_handoff.generation,
      saving.work_handoff.human_revision.request,
      "save",
      Ok(result),
    ),
  )
  assert_eq(ignored.work_handoff.human_revision.phase, "saving")
  let departed = update(code_mode_test_dispatch, WorkHandoff(Exit), saving).1
  let ignored = human_revision_test_action(
    departed,
    RevisionReplied(
      saving.work_handoff.generation,
      saving.work_handoff.human_revision.request,
      "save",
      Ok(result),
    ),
  )
  assert_false(work_handoff_active(ignored))
  guard result is Object(fields) &&
    handoff_field(result, "revision") is Object(revision) else {
    fail("fixture")
  }
  let changed = revision.copy()
  changed["task_id"] = ToJson::to_json("other")
  let response = fields.copy()
  response["revision"] = Json::object(changed)
  let wrong = human_revision_test_action(
    saving,
    RevisionReplied(
      saving.work_handoff.generation,
      saving.work_handoff.human_revision.request,
      "save",
      Ok(Json::object(response)),
    ),
  )
  assert_eq(wrong.work_handoff.human_revision.phase, "retry")
}

///|
test "blocked browser storage never dispatches a save and preserves the exact human draft" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let edited = human_revision_test_action(
    human_revision_test_open(human_revision_test_ready()),
    RevisionDraft("keep my edit"),
  )
  let blocked = continuation_draft_block_storage("write")
  let failed = human_revision_test_action(edited, RevisionSave)
  assert_eq(failed.work_handoff.human_revision.phase, "editing")
  assert_false(failed.work_handoff.human_revision.local_saved)
  assert_eq(failed.work_handoff.human_revision.draft, "keep my edit")
  assert_true(failed.work_handoff.human_revision.operation is Null)
  continuation_desk_storage_cleanup(blocked)
}

///|
test "human revision supports empty edits and retains oversized Unicode drafts without truncation" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let opened = human_revision_test_open(human_revision_test_ready())
  let cleared = human_revision_test_action(opened, RevisionDraft(""))
  let saving = human_revision_test_action(cleared, RevisionSave)
  assert_eq(saving.work_handoff.human_revision.phase, "saving")
  assert_eq(
    handoff_field(saving.work_handoff.human_revision.operation, "content"),
    Json::string(""),
  )
  let oversized = Array::make(90000, "书").join("")
  assert_true(work_human_revision_utf8_length(oversized) > 262144)
  let draft = human_revision_test_action(opened, RevisionDraft(oversized))
  let rejected = human_revision_test_action(draft, RevisionSave)
  assert_eq(rejected.work_handoff.human_revision.phase, "editing")
  assert_eq(rejected.work_handoff.human_revision.draft, oversized)
  assert_true(rejected.work_handoff.human_revision.operation is Null)
  let restored = work_human_revision_restore(
    opened.work_handoff.target.unwrap(),
    opened.work_handoff.output_hint,
    true,
  )
  assert_eq(restored.draft, oversized)
}

///|
test "human revision exact byte boundary survives escaped JSON and local operation restoration" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let opened = human_revision_test_open(human_revision_test_ready())
  let baseline = Array::make(262144, "\u0001").join("")
  let draft = baseline[:262143].to_owned() + "\u0002"
  let model = {
    ..opened,
    work_handoff: {
      ..opened.work_handoff,
      human_revision: { ..opened.work_handoff.human_revision, baseline, draft, },
    },
  }
  let saving = human_revision_test_action(model, RevisionSave)
  assert_eq(saving.work_handoff.human_revision.phase, "saving")
  assert_true(saving.work_handoff.human_revision.local_saved)
  let saved_body = work_human_revision_local_body(
    model.work_handoff.target.unwrap(),
    model.work_handoff.output_hint,
    saving.work_handoff.human_revision,
  ).stringify()
  assert_true(saved_body.length() < 800000)
  let request = @json.parse(
    saving.work_handoff.human_revision.operation.stringify(),
  )
  assert_eq(handoff_text(request, "content"), draft)
  assert_eq(
    work_human_revision_utf8_length(handoff_text(request, "content")),
    262144,
  )
  let restored = work_human_revision_restore(
    model.work_handoff.target.unwrap(),
    model.work_handoff.output_hint,
    true,
  )
  assert_eq(restored.operation, saving.work_handoff.human_revision.operation)
  assert_eq(restored.baseline, baseline)
  assert_eq(restored.draft, draft)
}

///|
test "unavailable native identity keeps operation and exact draft visible without a saved claim" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let saving = human_revision_test_action(
    human_revision_test_action(
      human_revision_test_open(human_revision_test_ready()),
      RevisionDraft("retained <draft>"),
    ),
    RevisionSave,
  )
  let target = saving.work_handoff.target.unwrap()
  let restored = work_human_revision_restore(
    target,
    saving.work_handoff.output_hint,
    true,
  )
  let unavailable = {
    ..saving,
    work_handoff: {
      ..saving.work_handoff,
      canonical: None,
      phase: "unavailable",
      human_revision: restored,
    },
  }
  let html = render_test_dom(
    @rabbita.static_cell(
      render_work_human_revision_pending(
        code_mode_test_dispatch,
        unavailable.work_handoff,
      ),
    ),
  )
  assert_true(html.contains("confirmation pending"))
  assert_true(html.contains("pending native identity verification"))
  assert_true(html.contains("retained &lt;draft&gt;"))
  assert_true(html.contains(handoff_text(restored.operation, "revision_id")))
  assert_false(html.contains("human_revision_id="))
  assert_eq(
    human_revision_test_action(unavailable, RevisionSave).work_handoff.human_revision.phase,
    "retry",
  )
}

///|
test "human revision ordered view returns only identity hint and exposes truthful authorship" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let saving = human_revision_test_action(
    human_revision_test_action(
      human_revision_test_open(human_revision_test_ready()),
      RevisionDraft("edited result"),
    ),
    RevisionSave,
  )
  let saved = human_revision_test_action(
    saving,
    RevisionReplied(
      saving.work_handoff.generation,
      saving.work_handoff.human_revision.request,
      "save",
      Ok(human_revision_test_saved(saving)),
    ),
  )
  let state = saved.work_handoff
  let html = render_test_dom(
    @rabbita.static_cell(
      render_work_human_revision(
        code_mode_test_dispatch,
        state,
        state.target.unwrap(),
        state.canonical.unwrap(),
      ),
    ),
  )
  assert_true(html.contains("2 · Edit this output yourself"))
  assert_true(html.contains("3 · Return your saved revision"))
  assert_true(html.contains("Human-authored revision"))
  assert_true(html.contains("human_revision_id="))
  assert_false(html.contains("continuation_command="))
  let url = work_human_revision_return_url(
    "https://proj.example/?task=T&continuation_id=old&continuation_command=C&source_run=R",
    "T", "revision-1",
  )
  assert_eq(url, "https://proj.example/?task=T&human_revision_id=revision-1")
  assert_eq(
    work_human_revision_return_url(
      "https://proj.example/?task=other", "T", "revision-1",
    ),
    "",
  )
}
