///|
fn continuation_desk_ready() -> Model {
  let model = handoff_desk_ready()
  {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      continuation: {
        ..empty_work_continuation(),
        enabled: true,
        prior_command: model.work_handoff.target.unwrap().command_id,
        draft: "Please improve the actual output\nKeep this instruction exact.",
      },
    },
  }
}

///|
fn continuation_desk_record(
  operation : Json,
  command~ : String = "C1",
  state~ : String = "completed",
) -> Json {
  {
    "schema": "moondesk.work-continuation.v1",
    "continuation_id": handoff_field(operation, "continuation_id"),
    "client_turn_id": handoff_field(operation, "client_turn_id"),
    "session_id": "S/书",
    "command_id": command,
    "state": state,
    "admission": "accepted",
    "input_status": "verified",
    "source": handoff_field(operation, "source"),
    "instruction": handoff_field(operation, "instruction"),
    "prior_result_command_id": handoff_field(
      operation, "prior_result_command_id",
    ),
    "model": "captured-c0-model",
    "original_context": {
      "path": "original/context.md",
      "sha256": "original-digest",
    },
    "input": { "path": "captured/input.md", "sha256": "input-digest" },
    "summary": "Actual follow-up result",
    "error": "",
    "evidence": ["exact-C1-evidence"],
    "output_refs": ["result.txt"],
  }
}

///|
fn continuation_desk_response(operation : Json, record : Json) -> Json {
  let json = handoff_desk_fixture()
  if json is Object(fields) {
    fields["continuation_state"] = "ready"
    fields["continuation"] = record
    fields["continuations"] = Json::array([record])
    fields["pending_guidance_state"] = "ready"
    fields["pending_guidance"] = [
      {
        "command_id": "G0",
        "text": "Existing deferred guidance",
        "receipt_status": "deferred",
        "source_event_id": "E0",
      },
    ]
  }
  ignore(operation)
  json
}

///|
extern "js" fn continuation_desk_storage_setup() -> @js.Value =
  #| () => { const previous = globalThis.localStorage; const data = new Map(); globalThis.localStorage = {getItem:key=>data.get(key)||null,setItem:(key,value)=>data.set(key,value),removeItem:key=>data.delete(key)}; return previous; }

///|
extern "js" fn continuation_desk_storage_cleanup(previous : @js.Value) =
  #| previous => { if (previous === undefined) delete globalThis.localStorage; else globalThis.localStorage = previous; }

///|
test "fresh followup has immutable exact instruction lineage and no copied executable state" {
  for receipt in ["runtime-completed", "runtime-failed", "runtime-cancelled"] {
    let model = continuation_desk_ready()
    let original = {
      ..model.work_handoff.canonical.unwrap(),
      receipt_status: receipt,
    }
    let model = {
      ..model,
      work_handoff: { ..model.work_handoff, canonical: Some(original), },
    }
    let (_, saving) = update_work_continuation(
      code_mode_test_dispatch,
      Submit,
      model,
    )
    let body = saving.work_handoff.continuation.operation
    assert_eq(
      handoff_text(body, "instruction"),
      model.work_handoff.continuation.draft,
    )
    assert_eq(handoff_text(body, "prior_result_command_id"), "C?0")
    assert_true(
      work_continuation_matches(model.work_handoff.target.unwrap(), body),
    )
    assert_eq(saving.work_handoff.canonical, Some(original))
    for
      key in [
        "model", "context_path", "horizon_id", "horizon_checkpoint", "next_action",
        "approval_id", "task_intent", "credentials", "return_to",
      ] {
      assert_true(handoff_field(body, key) is Null)
    }
  }
}

///|
test "operation is durably stored before any native POST and repeated click keeps identity" {
  let previous = continuation_desk_storage_setup()
  let emitted : Array[Msg] = []
  let dispatch : Dispatch[Msg] = msg => {
    emitted.push(msg)
    @rabbita.none
  }
  let (save, saving) = update_work_continuation(
    dispatch,
    Submit,
    continuation_desk_ready(),
  )
  assert_eq(emitted.length(), 0)
  let scheduler : RequestedSelectionTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  @cmd.Scheduler::add(scheduler, save)
  assert_eq(emitted.length(), 1)
  let body = saving.work_handoff.continuation.operation
  let key = work_continuation_key(saving.work_handoff.target.unwrap())
  assert_eq(@json.parse(work_continuation_read_saved(key)), body)
  let (_, duplicate) = update_work_continuation(dispatch, Submit, saving)
  assert_eq(duplicate.work_handoff.continuation.operation, body)
  let (_, pending) = update(dispatch, emitted[0], saving)
  assert_eq(pending.work_handoff.continuation.phase, "submitting")
  let (_, edited) = update_work_continuation(
    dispatch,
    Draft(pending.work_handoff.continuation.draft_token, "must not replace"),
    pending,
  )
  assert_eq(edited.work_handoff.continuation.operation, body)
  continuation_desk_storage_cleanup(previous)
}

///|
test "reload lost response and missing snapshot recover same identity before explicit retry" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let operation = work_continuation_submit_body(
    target,
    model.work_handoff.continuation,
    "K1",
  )
  assert_true(
    work_continuation_store(
      work_continuation_key(target),
      operation.stringify(),
    ),
  )
  let restored = work_continuation_restore(target, true)
  assert_eq(restored.phase, "recovering")
  assert_eq(restored.operation, operation)
  let missing : Json = {
    "continuation_state": "not_found",
    "continuations": [],
    "pending_guidance_state": "ready",
  }
  let reconciled = work_continuation_reconcile(target, restored, missing)
  assert_eq(reconciled.phase, "missing")
  let (_, retrying) = update_work_continuation(
    code_mode_test_dispatch,
    Submit,
    {
      ..model,
      work_handoff: { ..model.work_handoff, continuation: reconciled, },
    },
  )
  assert_eq(retrying.work_handoff.continuation.operation, operation)
  let record = continuation_desk_record(operation, state="running")
  let known = work_continuation_reconcile(
    target,
    restored,
    continuation_desk_response(operation, record),
  )
  assert_eq(known.phase, "saved")
  let (_, resumed) = update_work_continuation(code_mode_test_dispatch, Resume, {
    ..model,
    work_handoff: { ..model.work_handoff, continuation: known, },
  })
  assert_eq(resumed.work_handoff.continuation.phase, "saving_resume")
  assert_eq(resumed.work_handoff.continuation.operation, operation)
  continuation_desk_storage_cleanup(previous)
}

///|
test "uncertain submission cannot create new identity or discard captured instruction" {
  let model = continuation_desk_ready()
  let operation = work_continuation_submit_body(
    model.work_handoff.target.unwrap(),
    model.work_handoff.continuation,
    "K1",
  )
  let model = {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      continuation: {
        ..model.work_handoff.continuation,
        operation,
        phase: "uncertain",
      },
    },
  }
  for
    action in [
      New,
      Submit,
      Draft(model.work_handoff.continuation.draft_token, "different"),
      Prior(model.work_handoff.continuation.draft_token, "C2"),
    ] {
    let (_, next) = update_work_continuation(
      code_mode_test_dispatch, action, model,
    )
    assert_eq(next.work_handoff.continuation.operation, operation)
    assert_eq(next.work_handoff.continuation.phase, "uncertain")
  }
}

///|
test "definitively uncaptured invalid draft can be discarded while uncertain cannot" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_desk_ready()
  let operation = work_continuation_submit_body(
    model.work_handoff.target.unwrap(),
    model.work_handoff.continuation,
    "K-rejected",
  )
  let missing = {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      continuation: {
        ..model.work_handoff.continuation,
        operation,
        phase: "missing",
      },
    },
  }
  let (_, editable) = update_work_continuation(
    code_mode_test_dispatch,
    New,
    missing,
  )
  assert_eq(editable.work_handoff.continuation.phase, "draft")
  assert_true(editable.work_handoff.continuation.operation is Null)
  let (_, typed) = update_work_continuation(
    code_mode_test_dispatch,
    Draft(
      editable.work_handoff.continuation.draft_token,
      "Corrected instruction",
    ),
    editable,
  )
  assert_eq(typed.work_handoff.continuation.draft, "Corrected instruction")
  let too_long = "x".repeat(65537)
  let (_, blocked) = update_work_continuation(code_mode_test_dispatch, Submit, {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      continuation: { ..model.work_handoff.continuation, draft: too_long, },
    },
  })
  assert_true(blocked.work_handoff.continuation.operation is Null)
  continuation_desk_storage_cleanup(previous)
}

///|
test "exact completed C1 selection survives C2 and rejects cross source or pending output" {
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let one = work_continuation_submit_body(
    target,
    model.work_handoff.continuation,
    "K1",
  )
  let two = work_continuation_submit_body(
    target,
    model.work_handoff.continuation,
    "K2",
  )
  let c1 = continuation_desk_record(one)
  let c2 = continuation_desk_record(two, command="C2")
  let state = { ..model.work_handoff.continuation, records: [c1, c2], }
  let (_, chosen) = update_work_continuation(
    code_mode_test_dispatch,
    SelectReturn("K1"),
    { ..model, work_handoff: { ..model.work_handoff, continuation: state, }, },
  )
  assert_eq(chosen.work_handoff.continuation.selected_return, "K1")
  let response : Json = { "continuations": [c2, c1] }
  assert_eq(
    work_continuation_reconcile(
      target,
      chosen.work_handoff.continuation,
      response,
    ).selected_return,
    "K1",
  )
  let foreign = continuation_desk_record(
    work_continuation_submit_body(
      { ..target, task_id: "another", },
      state,
      "K-foreign",
    ),
  )
  assert_false(work_continuation_record_valid(target, foreign))
  let (_, pending) = update_work_continuation(
    code_mode_test_dispatch,
    SelectReturn("K2"),
    {
      ..model,
      work_handoff: {
        ..model.work_handoff,
        continuation: {
          ..state,
          records: [
            continuation_desk_record(two, command="C2", state="running"),
          ],
        },
      },
    },
  )
  assert_eq(pending.work_handoff.continuation.selected_return, "")
}

///|
test "newer browser navigation and exit ignore stored submitted and poll callbacks" {
  let model = continuation_desk_ready()
  let (_, saving) = update_work_continuation(
    code_mode_test_dispatch,
    Submit,
    model,
  )
  let id = handoff_text(
    saving.work_handoff.continuation.operation,
    "continuation_id",
  )
  let old = handoff_install_history("?activity=code&session=newer")
  let (_, ignored) = update_work_continuation(
    code_mode_test_dispatch,
    Stored(
      saving.work_handoff.generation,
      saving.work_handoff.continuation.request,
      id,
      true,
    ),
    saving,
  )
  requested_selection_restore_test_history(old)
  assert_eq(ignored.work_handoff.continuation.phase, "saving")
  let (_, exited) = update_work_handoff(code_mode_test_dispatch, Exit, saving)
  let (_, late) = update_work_continuation(
    code_mode_test_dispatch,
    Submitted(
      saving.work_handoff.generation,
      saving.work_handoff.continuation.request,
      id,
      Err("late"),
    ),
    exited,
  )
  assert_false(work_handoff_active(late))
}

///|
test "accepted inspect mode cannot submit and normal chat remains outside bound wrapper" {
  let state = work_handoff_from_query(
    handoff_desk_query() + "&work_accepted=true",
  )
  assert_false(state.continuation.enabled)
  let model = { ..handoff_desk_ready(), work_handoff: state, }
  let (_, next) = update_work_continuation(
    code_mode_test_dispatch,
    Submit,
    model,
  )
  assert_true(next.work_handoff.continuation.operation is Null)
  assert_false(work_handoff_active(init_model()))
}

///|
test "return selected result encodes exact identity no credentials and remains navigation only" {
  let url = work_continuation_return_url(
    "https://proj.example/?task=T&keep=1", "T", "R /书", "K1", "C?1",
  )
  assert_true(url.contains("continuation_command=C%3F1"))
  assert_true(url.contains("source_run=R+%2F%E4%B9%A6"))
  assert_false(url.contains("instruction"))
  assert_eq(
    work_continuation_return_url(
      "https://user:secret@proj.example/?task=T", "T", "R", "K", "C",
    ),
    "",
  )
}

///|
#warnings("-alert_unstable")
test "followup view separates original pending guidance immutable input and actual result" {
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let operation = work_continuation_submit_body(
    target,
    model.work_handoff.continuation,
    "K1",
  )
  let record = continuation_desk_record(operation)
  let state = work_continuation_reconcile(
    target,
    { ..model.work_handoff.continuation, operation, },
    continuation_desk_response(operation, record),
  )
  let model = {
    ..model,
    work_handoff: { ..model.work_handoff, continuation: state, },
  }
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_work_handoff(code_mode_test_dispatch, model)),
  )
  for
    text in [
      "Original", "Existing deferred guidance", "captured-c0-model", "Actual follow-up result",
      "input-digest", "Historical prior result", "Select this exact result", "Prepare another distinct follow-up",
    ] {
    assert_true(html.contains(text), msg=text)
  }
  assert_false(html.contains("Return selected result to MoonProj for review"))
}

///|
test "native known capture conflict remains inspectable without resume discard or result return" {
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let operation = work_continuation_submit_body(
    target,
    model.work_handoff.continuation,
    "K1",
  )
  let record = continuation_desk_record(operation)
  if record is Object(fields) {
    fields["input_status"] = "capture_missing"
  }
  let response = continuation_desk_response(operation, record)
  if response is Object(fields) {
    fields["continuation_state"] = "conflict"
    fields["continuation_message"] = "Saved snapshot is missing"
  }
  let state = work_continuation_reconcile(
    target,
    { ..model.work_handoff.continuation, operation, },
    response,
  )
  assert_eq(state.phase, "conflict")
  assert_eq(state.records.length(), 1)
  assert_true(state.error.contains("Saved snapshot is missing"))
  let model = {
    ..model,
    work_handoff: { ..model.work_handoff, continuation: state, },
  }
  for action in [Resume, New, SelectReturn("K1")] {
    let (_, next) = update_work_continuation(
      code_mode_test_dispatch, action, model,
    )
    assert_eq(next.work_handoff.continuation.phase, "conflict")
    assert_eq(next.work_handoff.continuation.operation, operation)
    assert_eq(next.work_handoff.continuation.selected_return, "")
  }
}

///|
test "missing input can repair same saved command but cannot return unverifiable result" {
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let operation = work_continuation_submit_body(
    target,
    model.work_handoff.continuation,
    "K1",
  )
  let record = continuation_desk_record(operation)
  if record is Object(fields) {
    fields["input_status"] = "missing"
  }
  let state = work_continuation_reconcile(
    target,
    { ..model.work_handoff.continuation, operation, },
    continuation_desk_response(operation, record),
  )
  let model = {
    ..model,
    work_handoff: { ..model.work_handoff, continuation: state, },
  }
  let (_, unselected) = update_work_continuation(
    code_mode_test_dispatch,
    SelectReturn("K1"),
    model,
  )
  assert_eq(unselected.work_handoff.continuation.selected_return, "")
  let (_, repair) = update_work_continuation(
    code_mode_test_dispatch,
    Resume,
    model,
  )
  assert_eq(repair.work_handoff.continuation.phase, "saving_resume")
  assert_eq(repair.work_handoff.continuation.operation, operation)
}

///|
test "restoration strips unknown fields retains exact selected historical prior and mode on reload" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let operation = work_continuation_submit_body(
    target,
    { ..model.work_handoff.continuation, prior_command: "C1", },
    "K2",
  )
  if operation is Object(fields) {
    fields["credentials"] = "must never forward"
    fields["approval_id"] = "old"
  }
  assert_true(
    work_continuation_store(
      work_continuation_key(target),
      operation.stringify(),
    ),
  )
  let restored = work_continuation_restore(target, true)
  assert_eq(restored.prior_command, "C1")
  assert_true(handoff_field(restored.operation, "credentials") is Null)
  assert_true(handoff_field(restored.operation, "approval_id") is Null)
  let history = handoff_install_history(
    handoff_desk_query().replace(
      old="work_mode=inspect",
      new="work_mode=follow_up",
    ),
  )
  handoff_sync_workspace(
    handoff_target_query(
      target.task_id,
      target.run_id,
      target.session_id,
      target.command_id,
      target.book_root,
      target.return_to,
    ),
    "canonical",
  )
  assert_true(init_model().work_handoff.continuation.enabled)
  requested_selection_restore_test_history(history)
  continuation_desk_storage_cleanup(previous)
}

///|
test "delayed first POST absence never permits new identity and survives reload" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let (_, saving) = update_work_continuation(
    code_mode_test_dispatch,
    Submit,
    model,
  )
  let operation = saving.work_handoff.continuation.operation
  assert_true(
    work_continuation_store(
      work_continuation_key(target),
      operation.stringify(),
    ),
  )
  let (_, submitted) = update_work_continuation(
    code_mode_test_dispatch,
    Stored(
      saving.work_handoff.generation,
      saving.work_handoff.continuation.request,
      handoff_text(operation, "continuation_id"),
      true,
    ),
    saving,
  )
  let (_, timed) = update_work_continuation(
    code_mode_test_dispatch,
    AdmissionTimeout(
      submitted.work_handoff.generation,
      submitted.work_handoff.continuation.request,
      handoff_text(operation, "continuation_id"),
    ),
    submitted,
  )
  assert_eq(timed.work_handoff.continuation.phase, "recovering")
  assert_eq(timed.work_handoff.continuation.operation, operation)
  let restored = work_continuation_restore(target, true)
  assert_true(restored.admission_possible)
  let missing = work_continuation_reconcile(target, restored, {
    "continuation_state": "not_found",
    "continuations": [],
  })
  let (_, not_discarded) = update_work_continuation(
    code_mode_test_dispatch,
    New,
    { ..model, work_handoff: { ..model.work_handoff, continuation: missing, }, },
  )
  assert_eq(not_discarded.work_handoff.continuation.operation, operation)
  assert_eq(not_discarded.work_handoff.continuation.phase, "missing")
  let (_, same_retry) = update_work_continuation(
    code_mode_test_dispatch,
    Submit,
    not_discarded,
  )
  assert_eq(same_retry.work_handoff.continuation.operation, operation)
  continuation_desk_storage_cleanup(previous)
}

///|
test "definitive not sent response retains validation error and allows edit only after absence" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let operation = work_continuation_submit_body(
    target,
    model.work_handoff.continuation,
    "K-rejected",
  )
  let submitted = {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      continuation: {
        ..model.work_handoff.continuation,
        operation,
        phase: "submitting",
        admission_possible: true,
        request: 8,
      },
    },
  }
  let (effect, rejected) = update_work_continuation(
    code_mode_test_dispatch,
    Submitted(
      submitted.work_handoff.generation,
      8,
      "K-rejected",
      Ok({
        "schema": "moondesk.work-continuation.v1",
        "state": "invalid_request",
        "admission": "not_sent",
        "message": "Unsupported captured context",
      }),
    ),
    submitted,
  )
  let scheduler : RequestedSelectionTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  @cmd.Scheduler::add(scheduler, effect)
  assert_false(rejected.work_handoff.continuation.admission_possible)
  assert_false(work_continuation_restore(target, true).admission_possible)
  let missing = work_continuation_reconcile(
    target,
    rejected.work_handoff.continuation,
    { "continuation_state": "not_found", "continuations": [] },
  )
  assert_true(missing.error.contains("Unsupported captured context"))
  let (_, editable) = update_work_continuation(code_mode_test_dispatch, New, {
    ..model,
    work_handoff: { ..model.work_handoff, continuation: missing, },
  })
  assert_true(editable.work_handoff.continuation.operation is Null)
  continuation_desk_storage_cleanup(previous)
}

///|
test "timed out canonical lookup preserves operation and ignores its eventual stale response" {
  let model = continuation_desk_ready()
  let (_, saving) = update_work_continuation(
    code_mode_test_dispatch,
    Submit,
    model,
  )
  let (_, reading) = update_work_handoff(
    code_mode_test_dispatch,
    Resolve,
    saving,
  )
  let (_, timeout) = update_work_handoff(
    code_mode_test_dispatch,
    LookupTimedOut(reading.work_handoff.generation),
    reading,
  )
  assert_eq(timeout.work_handoff.phase, "unavailable")
  assert_eq(
    timeout.work_handoff.continuation.operation,
    saving.work_handoff.continuation.operation,
  )
  let (_, stale) = update_work_handoff(
    code_mode_test_dispatch,
    Resolved(reading.work_handoff.generation, Ok(handoff_desk_fixture())),
    timeout,
  )
  assert_eq(stale.work_handoff.phase, "unavailable")
  let (_, retry) = update_work_handoff(code_mode_test_dispatch, Resolve, stale)
  assert_eq(retry.work_handoff.phase, "loading")
}

///|
test "retry not sent acknowledgement cannot clear uncertainty from an older delayed POST" {
  let previous = continuation_desk_storage_setup()
  let model = continuation_desk_ready()
  let target = model.work_handoff.target.unwrap()
  let operation = work_continuation_submit_body(
    target,
    model.work_handoff.continuation,
    "K-sticky",
  )
  assert_true(
    work_continuation_store(
      work_continuation_key(target),
      operation.stringify(),
    ),
  )
  let missing = work_continuation_reconcile(
    target,
    work_continuation_restore(target, true),
    { "continuation_state": "not_found", "continuations": [] },
  )
  let (_, saving_retry) = update_work_continuation(
    code_mode_test_dispatch,
    Submit,
    { ..model, work_handoff: { ..model.work_handoff, continuation: missing, }, },
  )
  assert_true(saving_retry.work_handoff.continuation.prior_uncertainty)
  let (_, sent_retry) = update_work_continuation(
    code_mode_test_dispatch,
    Stored(
      saving_retry.work_handoff.generation,
      saving_retry.work_handoff.continuation.request,
      "K-sticky",
      true,
    ),
    saving_retry,
  )
  let (_, not_sent_retry) = update_work_continuation(
    code_mode_test_dispatch,
    Submitted(
      sent_retry.work_handoff.generation,
      sent_retry.work_handoff.continuation.request,
      "K-sticky",
      Ok({
        "schema": "moondesk.work-continuation.v1",
        "admission": "not_sent",
        "state": "invalid_request",
        "message": "This retry rejected",
      }),
    ),
    sent_retry,
  )
  assert_true(not_sent_retry.work_handoff.continuation.admission_possible)
  let absent = work_continuation_reconcile(
    target,
    not_sent_retry.work_handoff.continuation,
    { "continuation_state": "not_found", "continuations": [] },
  )
  let (_, blocked) = update_work_continuation(code_mode_test_dispatch, New, {
    ..model,
    work_handoff: { ..model.work_handoff, continuation: absent, },
  })
  assert_eq(blocked.work_handoff.continuation.operation, operation)
  assert_eq(blocked.work_handoff.continuation.phase, "missing")
  continuation_desk_storage_cleanup(previous)
}
