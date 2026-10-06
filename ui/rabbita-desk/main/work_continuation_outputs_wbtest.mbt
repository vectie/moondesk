///|
fn continuation_output_record(command : String, evidence : String) -> Json {
  let model = continuation_desk_ready()
  let operation = work_continuation_submit_body(
    model.work_handoff.target.unwrap(),
    model.work_handoff.continuation,
    "follow-" + command,
  )
  let record = continuation_desk_record(operation, command~)
  guard record is Object(fields) else { abort("fixture") }
  fields["output_refs"] = [
    {
      "command_id": command,
      "path": "results/a & 书.md",
      "evidence_id": evidence,
    },
  ].to_json()
  record
}

///|
test "continuation named outputs route same filenames through exact command evidence and original identity" {
  let target = continuation_desk_ready().work_handoff.target.unwrap()
  for (command, evidence) in [("C1", "E?1"), ("C2", "E?2")] {
    let record = continuation_output_record(command, evidence)
    let output = handoff_json_array(record, "output_refs")[0]
    let url = work_continuation_output_url(target, record, output)
    assert_true(url.has_prefix("?"))
    assert_true(url.contains("work_mode=inspect"))
    assert_false(url.contains("follow_up"))
    assert_true(url.contains("command=C%3F0"))
    assert_true(url.contains("work_output_path=results%2Fa+%26+%E4%B9%A6.md"))
    let opened = work_handoff_from_query(url)
    assert_eq(opened.target, Some(target))
    assert_eq(opened.output_hint, output)
    assert_false(opened.continuation.enabled)
    let request = work_output_read_url(
      work_handoff_read_url(
        target.session_id,
        target.command_id,
        target.book_root,
      ),
      opened.output_hint,
    )
    assert_true(request.has_prefix("/api/mooncode/work-handoff?"))
    assert_true(request.contains("command_id=C%3F0"))
    assert_true(request.contains("output_command=" + command))
    assert_true(request.contains("output_path=results%2Fa+%26+%E4%B9%A6.md"))
    assert_true(
      request.contains(
        if command == "C1" {
          "output_evidence=E%3F1"
        } else {
          "output_evidence=E%3F2"
        },
      ),
    )
  }
}

///|
#warnings("-alert_unstable")
test "continuation output inspection links are read only new tabs without replacing draft prior or return selection" {
  let base = continuation_desk_ready()
  let first = continuation_output_record("C1", "E?1")
  let second = continuation_output_record("C2", "E?2")
  let state = {
    ..base.work_handoff.continuation,
    draft: "Do not send my unsent change",
    prior_command: "C1",
    selected_return: "follow-C2",
    records: [first, second],
  }
  let model = {
    ..base,
    work_handoff: { ..base.work_handoff, continuation: state, },
  }
  for record in state.records {
    let html = @rabbita.render_to_string(
      @rabbita.static_cell(
        render_work_continuation_outputs(
          model.work_handoff.target.unwrap(),
          record,
        ),
      ),
    )
    assert_true(
      html.contains("Inspect output · results/a &amp; 书.md (new tab)"),
    )
    assert_true(html.contains("target=\"_blank\""))
    assert_true(html.contains("rel=\"noopener noreferrer\""))
    assert_false(html.contains("<button"))
    assert_false(html.contains("<form"))
    assert_false(html.contains("/api/workspaces/"))
    assert_eq(
      model.work_handoff.continuation.draft,
      "Do not send my unsent change",
    )
    assert_eq(model.work_handoff.continuation.prior_command, "C1")
    assert_eq(model.work_handoff.continuation.selected_return, "follow-C2")
  }
}

///|
test "continuation output links refuse unverified source evidence and unsafe paths" {
  let target = continuation_desk_ready().work_handoff.target.unwrap()
  let record = continuation_output_record("C1", "E?1")
  let output = handoff_json_array(record, "output_refs")[0]
  guard output is Object(fields) else { fail("fixture") }
  for
    (key, value) in [
      ("command_id", "C2"),
      ("evidence_id", ""),
      ("path", "../private"),
      ("path", "/private"),
      ("path", "a\\b"),
      ("path", "a//b"),
      ("path", "a/./b"),
      ("path", "a\u0000b"),
      ("path", ""),
    ] {
    let changed = fields.copy()
    changed[key] = value.to_json()
    assert_eq(
      work_continuation_output_url(target, record, Json::object(changed)),
      "",
    )
  }
  guard record is Object(records) else { fail("fixture") }
  for key in ["source", "admission", "input_status", "session_id"] {
    let changed = records.copy()
    changed[key] = Json::null()
    assert_eq(
      work_continuation_output_url(target, Json::object(changed), output),
      "",
    )
  }
  for
    wrong in [
      { ..target, task_id: "other-task", },
      { ..target, run_id: "other-run", },
      { ..target, session_id: "other-session", },
      { ..target, book_root: "/other-book", },
      { ..target, command_id: "other-original", },
    ] {
    assert_eq(work_continuation_output_url(wrong, record, output), "")
  }
}

///|
#warnings("-alert_unstable")
test "continuation missing and legacy output refs remain explicitly unavailable outside details" {
  let target = continuation_desk_ready().work_handoff.target.unwrap()
  let cases : Array[Array[Json]] = [
    [],
    ["legacy.txt"],
    [{ "path": "no-evidence.md" }],
  ]
  for outputs in cases {
    let record = continuation_output_record("C1", "E?1")
    guard record is Object(fields) else { fail("fixture") }
    fields["output_refs"] = Json::array(outputs)
    let html = @rabbita.render_to_string(
      @rabbita.static_cell(render_work_continuation_outputs(target, record)),
    )
    assert_false(html.contains("<a "))
    assert_false(html.contains("<details"))
    assert_true(
      html.contains(
        if outputs.is_empty() {
          "No output file references"
        } else {
          "unavailable"
        },
      ),
    )
  }
}

///|
#warnings("-alert_unstable")
test "continuation output route still requires verified host response and preserves active document download policy" {
  let base = continuation_desk_ready()
  let target = base.work_handoff.target.unwrap()
  let record = continuation_output_record("C1", "E?1")
  let hint : Json = {
    "command_id": "C1",
    "path": "results/site.html",
    "evidence_id": "E?1",
  }
  guard record is Object(record_fields) else { fail("fixture") }
  record_fields["output_refs"] = [hint].to_json()
  let url = work_continuation_output_url(target, record, hint)
  let initial = { ..base, work_handoff: work_handoff_from_query(url), }
  let (_, loading) = update_work_handoff(
    code_mode_test_dispatch,
    Resolve,
    initial,
  )
  let response = handoff_desk_fixture()
  guard response is Object(fields) else { fail("fixture") }
  fields["output"] = {
    "state": "ready",
    "command_id": "C1",
    "path": "results/site.html",
    "evidence_id": "E?1",
    "workspace_id": "actual-desk-id",
    "content_scope": "current_workspace_bytes",
  }
  let (_, ready) = update_work_handoff(
    code_mode_test_dispatch,
    Resolved(loading.work_handoff.generation, Ok(response)),
    loading,
  )
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_work_output(
        ready.work_handoff,
        ready.work_handoff.canonical.unwrap(),
      ),
    ),
  )
  assert_true(html.contains("Download current file"))
  assert_false(html.contains("Open current file"))
  assert_true(
    html.contains("Active documents are not opened inside the Desk origin"),
  )
  assert_false(ready.work_handoff.continuation.enabled)
  fields["output"] = {
    "state": "unavailable",
    "message": "The exact output reference could not be verified.",
  }
  let (_, unavailable) = update_work_handoff(
    code_mode_test_dispatch,
    Resolved(loading.work_handoff.generation, Ok(response)),
    loading,
  )
  let unavailable_html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_work_output(
        unavailable.work_handoff,
        unavailable.work_handoff.canonical.unwrap(),
      ),
    ),
  )
  assert_true(unavailable_html.contains("could not be verified"))
  assert_false(unavailable_html.contains("Download current file"))
}

///|
test "new tab output resolution cannot overwrite or retire a newer local unsent draft" {
  let previous = continuation_desk_storage_setup()
  let base = continuation_draft_type(continuation_desk_ready(), "Older draft")
  let target = base.work_handoff.target.unwrap()
  let record = continuation_output_record("C1", "E?1")
  let output = handoff_json_array(record, "output_refs")[0]
  let url = work_continuation_output_url(target, record, output)
  let (_, pending) = update_work_handoff(code_mode_test_dispatch, Resolve, {
    ..base,
    work_handoff: work_handoff_from_query(url),
  })
  let current = continuation_draft_type(
    base, "Newer unsent draft in original tab",
  )
  let key = work_continuation_draft_key(target)
  let saved = work_continuation_draft_read(key)
  let (_, inspected) = update_work_handoff(
    code_mode_test_dispatch,
    Resolved(pending.work_handoff.generation, Ok(handoff_desk_fixture())),
    pending,
  )
  assert_false(inspected.work_handoff.continuation.enabled)
  assert_eq(work_continuation_draft_read(key), saved)
  assert_true(saved.contains(current.work_handoff.continuation.draft))
  assert_eq(
    current.work_handoff.continuation.prior_command,
    base.work_handoff.continuation.prior_command,
  )
  assert_eq(
    work_continuation_restore(target, true).draft,
    current.work_handoff.continuation.draft,
  )
  assert_eq(work_continuation_read_saved(work_continuation_key(target)), "null")
  continuation_desk_storage_cleanup(previous)
}
