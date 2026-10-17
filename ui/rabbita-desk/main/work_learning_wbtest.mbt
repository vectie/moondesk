///|
fn learning_work_model(turns : Array[@mooncode_core.MoonCodeTurn]) -> Model {
  let model = handoff_desk_ready()
  let session = {
    ..code_mode_test_session("S/书"),
    workspace_id: "actual-desk-id",
    cwd: "/book/",
    mooncode_conversation: Some(code_mode_test_conversation("S/书", turns)),
  }
  {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      session: Some(session),
      session_error: "",
    },
  }
}

///|
fn learning_original_model() -> Model {
  learning_work_model([
    code_mode_test_turn(
      "C?0",
      "Original",
      assistant="Result <exact>\nKeep lines",
    ),
    code_mode_test_turn("C1", "Later", assistant="Do not substitute this"),
  ])
}

///|
test "captured learning binds canonical Book and source instead of selected workspace" {
  let model = {
    ..learning_original_model(),
    selected_workspace_id: "wrong-book",
  }
  let binding = work_learning_binding(model)
  assert_eq(handoff_text(binding, "workspace_id"), "actual-desk-id")
  assert_eq(handoff_text(binding, "book_root"), "/book")
  assert_eq(handoff_text(binding, "session_id"), "S/书")
  assert_eq(handoff_text(binding, "original_command_id"), "C?0")
  let sources = work_learning_sources(model)
  assert_eq(sources.length(), 1)
  assert_eq(handoff_text(sources[0], "command_id"), "C?0")
  assert_eq(handoff_text(sources[0], "turn_id"), "C?0")
  assert_eq(handoff_text(sources[0], "content"), "Result <exact>\nKeep lines")
  let payload = work_learning_payload(
    model,
    model.work_handoff.generation,
    "C?0",
    "C?0",
    "",
  ).unwrap()
  assert_eq(handoff_field(payload, "binding"), binding)
  assert_eq(handoff_field(payload, "source"), sources[0])
}

///|
test "captured learning rejects stale generation and mismatched source identities" {
  let model = learning_original_model()
  let generation = model.work_handoff.generation
  for
    (version, command, turn, item) in [
      (generation - 1, "C?0", "C?0", ""),
      (generation, "C1", "C1", ""),
      (generation, "C?0", "other-turn", ""),
      (generation, "C?0", "C?0", "other-item"),
    ] {
    assert_true(
      work_learning_payload(model, version, command, turn, item) is None,
    )
  }
  let (_, loading) = update_work_handoff(
    code_mode_test_dispatch,
    Resolve,
    model,
  )
  assert_eq(work_learning_sources(loading).length(), 0)
  let (_, exited) = update_work_handoff(code_mode_test_dispatch, Exit, model)
  assert_eq(work_learning_sources(exited).length(), 0)
  assert_eq(handoff_text(work_learning_binding(exited), "binding_key"), "")
}

///|
extern "js" fn learning_work_install_location(query : String) -> @js.Value =
  #| query => { const previous = globalThis.location; const url = new URL(query, 'https://desk.example/'); globalThis.location = {href:url.href, search:url.search}; return previous; }

///|
fn learning_work_payload_at_query(model : Model, query : String) -> Json? {
  let previous = learning_work_install_location(query)
  defer requested_selection_restore_test_location(previous)
  work_learning_payload(model, model.work_handoff.generation, "C?0", "C?0", "")
}

///|
test "captured learning never opens stale Back Forward or selected-output navigation" {
  let model = learning_original_model()
  for
    query in [
      handoff_desk_query().replace_all(old="work_run=R", new="work_run=other"),
      handoff_desk_query() +
      "&work_output_command=C1&work_output_path=result.txt&work_output_evidence=E1",
      "?workspace=another&activity=code",
    ] {
    let payload = learning_work_payload_at_query(model, query)
    assert_true(payload is None)
  }
  let payload = learning_work_payload_at_query(model, handoff_desk_query())
  assert_true(payload is Some(_))
}

///|
test "captured learning rejects foreign session workspace root and conversation" {
  let model = learning_original_model()
  let session = model.work_handoff.session.unwrap()
  for
    wrong in [
      { ..session, id: "other-session", },
      { ..session, workspace_id: "other-workspace", },
      { ..session, cwd: "/other-book", },
      {
        ..session,
        mooncode_conversation: Some({
          ..session.mooncode_conversation.unwrap(),
          session_id: "other",
        }),
      },
    ] {
    assert_eq(
      work_learning_sources({
        ..model,
        work_handoff: { ..model.work_handoff, session: Some(wrong), },
      }).length(),
      0,
    )
  }
}

///|
test "captured learning requires one saved done assistant with consistent turn ownership" {
  let good = code_mode_test_turn("C?0", "Original", assistant="Saved answer")
  let answer = good.assistant.unwrap()
  for
    wrong in [
      { ..good, turn_id: "", },
      { ..good, status: "running", },
      { ..good, assistant: None, },
      { ..good, assistant: Some({ ..answer, status: "running", }), },
      { ..good, assistant: Some({ ..answer, role: "user", }), },
      { ..good, assistant: Some({ ..answer, command_id: "other", }), },
      { ..good, assistant: Some({ ..answer, client_turn_id: "other", }), },
      { ..good, assistant: Some({ ..answer, content: " \n ", }), },
    ] {
    assert_eq(work_learning_sources(learning_work_model([wrong])).length(), 0)
  }
  assert_eq(
    work_learning_sources(learning_work_model([good, good])).length(),
    0,
  )
}

///|
test "captured learning permits only uniquely bound completed followup answers" {
  let model = learning_original_model()
  let operation : Json = {
    "continuation_id": "followup-1",
    "client_turn_id": "C1",
    "source": work_continuation_source(model.work_handoff.target.unwrap()),
    "instruction": "Improve it",
    "prior_result_command_id": "C?0",
  }
  let record = continuation_desk_record(operation)
  let with_records = fn(records) {
    {
      ..model,
      work_handoff: {
        ..model.work_handoff,
        continuation: { ..model.work_handoff.continuation, records, },
      },
    }
  }
  let sources = work_learning_sources(with_records([record]))
  assert_eq(sources.length(), 2)
  assert_eq(handoff_text(sources[1], "continuation_id"), "followup-1")
  assert_eq(handoff_text(sources[1], "command_id"), "C1")
  for
    (key, value) in [
      ("state", "running"),
      ("admission", "rejected"),
      ("input_status", "missing"),
      ("client_turn_id", "other"),
      ("session_id", "other"),
    ] {
    let changed = @json.parse(record.stringify())
    if changed is Object(fields) {
      fields[key] = ToJson::to_json(value)
    }
    assert_eq(work_learning_sources(with_records([changed])).length(), 1)
  }
  assert_eq(work_learning_sources(with_records([record, record])).length(), 1)
}

///|
#warnings("-alert_unstable")
test "captured answer actions stay next to exact escaped result and preserve inspection" {
  let model = learning_original_model()
  let html = guided_desk_markup(model)
  assert_true(html.contains("Teach this book from command C?0"))
  assert_false(html.contains("Teach this book from command C1"))
  assert_true(html.contains("Result &lt;exact&gt;"))
  assert_true(html.contains("Review this Book’s learning"))
  assert_true(html.contains("Return to MoonProj"))
  assert_true(html.contains("2 · Request a change"))
  assert_false(
    work_handoff_blocks(
      WorkHandoff(
        TeachLearning(model.work_handoff.generation, "C?0", "C?0", ""),
      ),
    ),
  )
  assert_true(
    work_handoff_blocks(workspace_feature_msg("open-toolbox", first="learning")),
  )
  let (_, next) = update(
    code_mode_test_dispatch,
    WorkHandoff(TeachLearning(model.work_handoff.generation, "C?0", "C?0", "")),
    model,
  )
  assert_eq(next.work_handoff.target, model.work_handoff.target)
  assert_eq(next.work_handoff.canonical, model.work_handoff.canonical)
  assert_eq(
    next.work_handoff.continuation.selected_return,
    model.work_handoff.continuation.selected_return,
  )
  assert_eq(next.selected_workspace_id, model.selected_workspace_id)
}

///|
test "captured bridge projection carries identity without copying answer content" {
  let model = learning_original_model()
  let payload = workspace_features_state_payload(model)
  assert_eq(
    handoff_field(payload, "captured_work"),
    work_learning_binding(model),
  )
  assert_false(payload.stringify().contains("Result <exact>"))
  let refreshed = {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      generation: model.work_handoff.generation + 1,
    },
  }
  assert_false(
    handoff_text(work_learning_binding(model), "binding_key") ==
    handoff_text(work_learning_binding(refreshed), "binding_key"),
  )
}

///|
test "captured learning waits through automatic polls and delayed admission refreshes" {
  let model = learning_original_model()
  let operation : Json = {
    "continuation_id": "followup-1",
    "client_turn_id": "C1",
    "source": work_continuation_source(model.work_handoff.target.unwrap()),
    "instruction": "Improve it",
    "prior_result_command_id": "C?0",
  }
  for
    phase in [
      "saving", "saving_resume", "submitting", "recovering", "missing", "uncertain",
      "saved",
    ] {
    let busy = {
      ..model,
      work_handoff: {
        ..model.work_handoff,
        continuation: {
          ..model.work_handoff.continuation,
          phase,
          operation,
          records: [continuation_desk_record(operation, state="running")],
        },
      },
    }
    assert_true(work_learning_refresh_pending(busy))
    assert_eq(handoff_text(work_learning_binding(busy), "binding_key"), "")
    assert_eq(work_learning_sources(busy).length(), 0)
    assert_true(
      work_learning_payload(
        busy,
        busy.work_handoff.generation,
        "C?0",
        "C?0",
        "",
      )
      is None,
    )
    let html = guided_desk_markup(busy)
    assert_true(html.contains("Finish or recover the current follow-up"))
    assert_false(html.contains("Teach this book from command"))
  }
  let done = {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      continuation: {
        ..model.work_handoff.continuation,
        phase: "saved",
        operation,
        records: [continuation_desk_record(operation)],
      },
    },
  }
  assert_false(work_learning_refresh_pending(done))
  assert_eq(work_learning_sources(done).length(), 2)
  let uncertain_storage = {
    ..model,
    work_handoff: {
      ..model.work_handoff,
      continuation: {
        ..model.work_handoff.continuation,
        phase: "storage_failed",
        prior_uncertainty: true,
      },
    },
  }
  assert_true(work_learning_refresh_pending(uncertain_storage))
}
