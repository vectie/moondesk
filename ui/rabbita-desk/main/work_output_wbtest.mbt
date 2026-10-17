///|
fn output_desk_hint() -> Json {
  { "command_id": "C1", "path": "results/a 书.md", "evidence_id": "E1" }
}

///|
fn output_desk_response(canonical : WorkHandoffCanonical) -> Json {
  {
    "state": "ready",
    "command_id": "C1",
    "path": "results/a 书.md",
    "evidence_id": "E1",
    "workspace_id": canonical.workspace_id,
    "content_scope": "current_workspace_bytes",
  }
}

///|
test "output handoff retains exact query and existing original identity on reload" {
  let query = handoff_desk_query() +
    "&work_output_command=C1&work_output_path=results%2Fa+%E4%B9%A6.md&work_output_evidence=E1"
  for _ in 0..<2 {
    let state = work_handoff_from_query(query)
    assert_eq(state.output_hint, output_desk_hint())
    assert_eq(state.target.unwrap().command_id, "C?0")
    assert_false(state.continuation.enabled)
  }
  let request = work_output_read_url(
    work_handoff_read_url("S/书", "C?0", "/book"),
    output_desk_hint(),
  )
  assert_true(request.contains("command_id=C%3F0"))
  assert_true(request.contains("output_command=C1"))
  assert_true(request.contains("output_path=results%2Fa+%E4%B9%A6.md"))
}

///|
#warnings("-alert_unstable")
test "output renders existing confined file route with honest current-byte label" {
  let model = handoff_desk_ready()
  let canonical = model.work_handoff.canonical.unwrap()
  let output = work_output_decode(
    output_desk_hint(),
    canonical,
    output_desk_response(canonical),
  )
  assert_eq(handoff_text(output, "state"), "ready")
  let state = { ..model.work_handoff, output_hint: output_desk_hint(), output, }
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_work_output(state, canonical)),
  )
  assert_true(
    html.contains(
      @desk.workspace_file_url(canonical.workspace_id, "results/a 书.md"),
    ),
  )
  assert_true(html.contains("current workspace file"))
  assert_true(html.contains("Later work or human edits"))
  assert_true(html.contains("download=\"\""))
  assert_eq(
    state.continuation.selected_return,
    model.work_handoff.continuation.selected_return,
  )
}

///|
test "output passive preview allowlist does not inline active documents" {
  for path in ["result.md", "result.txt", "result.pdf", "result.png"] {
    assert_true(work_output_previewable(path))
  }
  for
    path in [
      "result.html", "result.htm", "result.svg", "result.xhtml", "result.js", "result.docx",
      "result.PNG",
    ] {
    assert_false(work_output_previewable(path))
  }
}

///|
test "output rejects wrong source workspace scope and traversal from host response" {
  let canonical = handoff_desk_ready().work_handoff.canonical.unwrap()
  let response = output_desk_response(canonical)
  guard response is Object(fields) else { fail("fixture") }
  for
    (key, value) in [
      ("command_id", "C2"),
      ("evidence_id", "E2"),
      ("workspace_id", "other"),
      ("content_scope", "historical"),
      ("path", "../secret"),
    ] {
    let modified = fields.copy()
    modified[key] = ToJson::to_json(value)
    assert_eq(
      handoff_text(
        work_output_decode(
          output_desk_hint(),
          canonical,
          Json::object(modified),
        ),
        "state",
      ),
      "unavailable",
    )
  }
}

///|
test "output response cannot restore an exited or newer handoff" {
  let initial = {
    ..handoff_desk_model(),
    work_handoff: {
      ..handoff_desk_model().work_handoff,
      output_hint: output_desk_hint(),
    },
  }
  let (_, pending) = update_work_handoff(
    code_mode_test_dispatch,
    Resolve,
    initial,
  )
  let (_, exited) = update_work_handoff(code_mode_test_dispatch, Exit, pending)
  let (_, stale) = update_work_handoff(
    code_mode_test_dispatch,
    Resolved(pending.work_handoff.generation, Ok(handoff_desk_fixture())),
    exited,
  )
  assert_eq(stale.work_handoff.output, Json::null())
  assert_true(stale.work_handoff.target is None)
}
