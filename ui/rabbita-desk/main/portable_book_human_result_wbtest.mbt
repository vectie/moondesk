///|
fn portable_human_test_source() -> PortableBookHumanResult {
  {
    filename: "accepted-human-result.json",
    raw_base64: "ZXhhY3Qgc291cmNlIGJ5dGVzCg==",
    raw_size_bytes: 19,
    raw_sha256: portable_book_test_sha(),
    task: {
      record_id: "task:alpha",
      record_version: "3",
      record_digest: portable_book_test_sha(),
    },
    report: {
      record_id: "report:alpha",
      record_version: "1",
      record_digest: portable_book_test_sha(),
    },
    revision: {
      revision_id: "revision-1",
      original_run_id: "run:1",
      session_id: "session:1",
      original_command_id: "command:1",
      output_command_id: "command:2",
      output_evidence_id: "report/result.txt:sha256:captured",
      revision_snapshot_digest: portable_book_test_sha(),
    },
    content_text: "<script>alert('no')</script>\n完整文本 & \"quoted\"",
    content_size_bytes: 55,
    content_sha256: portable_book_test_sha(),
  }
}

///|
fn portable_human_test_selected() -> PortableBookState {
  {
    ..portable_book_test_ready(),
    accepted_human_result: Some(portable_human_test_source()),
  }
}

///|
test "accepted human result selection is local and only Prepare transports original bytes" {
  let ready = { ..portable_book_test_ready(), paths: ["output/extra.txt"], }
  let (picking, effect) = reduce_portable_book(ready, ChooseAcceptedHumanResult)
  assert_true(effect is PickAcceptedHumanResult(0, 1))
  assert_false(portable_book_can_prepare(picking))
  assert_true(portable_book_inputs_locked(picking))
  let (selected, effect) = reduce_portable_book(
    picking,
    AcceptedHumanResultPicked(0, 1, Ok(Some(portable_human_test_source()))),
  )
  assert_true(effect is NoPortableEffect)
  assert_eq(selected.operation_id, "")
  assert_eq(selected.paths, ready.paths)
  assert_true(selected.accepted_human_result is Some(_))
  let (preparing, effect) = reduce_portable_book(
    selected,
    Prepare(portable_book_test_id()),
  )
  assert_true(
    effect
    is PreparePortablePackageWithHumanResult(
      0,
      2,
      _,
      "1.2.3",
      ["output/extra.txt"],
      raw
    ) &&
    raw == portable_human_test_source().raw_base64,
  )
  let (_, effect) = reduce_portable_book(preparing, ChooseAcceptedHumanResult)
  assert_true(effect is NoPortableEffect)
  let (unchanged, effect) = reduce_portable_book(
    preparing,
    RemoveAcceptedHumanResult,
  )
  assert_true(effect is NoPortableEffect)
  assert_true(unchanged.accepted_human_result is Some(_))
}

///|
test "accepted human result remove returns unchanged backward-compatible prepare effect" {
  let source = portable_human_test_selected()
  let (removed, effect) = reduce_portable_book(
    source,
    RemoveAcceptedHumanResult,
  )
  assert_true(effect is NoPortableEffect)
  assert_true(removed.accepted_human_result is None)
  let (_, effect) = reduce_portable_book(
    removed,
    Prepare(portable_book_test_id()),
  )
  assert_true(effect is PreparePortablePackage(0, 1, _, "1.2.3", []))
}

///|
test "accepted human result cancellation error and timeout retain prior selection without preparing" {
  for result in [Ok(None), Err("invalid digest")] {
    let (picking, _) = reduce_portable_book(
      portable_human_test_selected(),
      ChooseAcceptedHumanResult,
    )
    let (cancelled, effect) = reduce_portable_book(
      picking,
      AcceptedHumanResultPicked(0, 1, result),
    )
    assert_true(effect is NoPortableEffect)
    assert_eq(
      cancelled.accepted_human_result,
      Some(portable_human_test_source()),
    )
    assert_eq(cancelled.operation_id, "")
    assert_true(cancelled.pending is None)
  }
  let (picking, _) = reduce_portable_book(
    portable_human_test_selected(),
    ChooseAcceptedHumanResult,
  )
  let (timed_out, effect) = reduce_portable_book(picking, TimedOut(0, 1))
  assert_true(effect is NoPortableEffect)
  assert_true(timed_out.error.contains("timed out"))
  assert_eq(timed_out.accepted_human_result, Some(portable_human_test_source()))
  let (retry, effect) = reduce_portable_book(
    timed_out,
    ChooseAcceptedHumanResult,
  )
  assert_true(effect is PickAcceptedHumanResult(0, 2))
  let (ignored, effect) = reduce_portable_book(
    retry,
    AcceptedHumanResultPicked(0, 1, Ok(None)),
  )
  assert_true(effect is NoPortableEffect)
  assert_true(ignored.pending is Some({ request: 2, .. }))
}

///|
test "accepted human result clears across Book library mode and reload boundaries" {
  for
    binding in [
      BindPortable(true, "/library-a", "book-b"),
      BindPortable(true, "/library-b", "book-a"),
      BindPortable(false, "/library-a", "book-a"),
    ] {
    let (picking, _) = reduce_portable_book(
      portable_human_test_selected(),
      ChooseAcceptedHumanResult,
    )
    let (switched, _) = reduce_portable_book(picking, binding)
    assert_true(switched.accepted_human_result is None)
    let (ignored, effect) = reduce_portable_book(
      switched,
      AcceptedHumanResultPicked(0, 1, Ok(Some(portable_human_test_source()))),
    )
    assert_true(effect is NoPortableEffect)
    assert_true(ignored.accepted_human_result is None)
  }
  assert_true(init_portable_book().accepted_human_result is None)
  assert_true(init_model().portable_book.accepted_human_result is None)
  let model = { ..init_model(), portable_book: portable_human_test_selected(), }
  let changing = portable_book_library_transition(PickLibraryFolder, model)
  assert_true(changing.portable_book.accepted_human_result is None)
  assert_true(changing.portable_book.library_changing)
}

///|
test "accepted human result edits invalidate old inspection but never bypass uncertain preparation" {
  let prepared = {
    ..portable_human_test_selected(),
    prepared: Some(portable_book_test_package()),
    operation_id: portable_book_test_id(),
  }
  let (removed, _) = reduce_portable_book(prepared, RemoveAcceptedHumanResult)
  assert_true(removed.prepared is None)
  assert_eq(removed.operation_id, "")
  let (pending, _) = reduce_portable_book(
    portable_human_test_selected(),
    Prepare(portable_book_test_id()),
  )
  let (uncertain, _) = reduce_portable_book(pending, TimedOut(0, 1))
  for action in [ChooseAcceptedHumanResult, RemoveAcceptedHumanResult] {
    let (unchanged, effect) = reduce_portable_book(uncertain, action)
    assert_true(effect is NoPortableEffect)
    assert_eq(unchanged.operation_id, portable_book_test_id())
    assert_true(unchanged.accepted_human_result is Some(_))
  }
  let (_, effect) = reduce_portable_book(uncertain, CheckPreparation)
  assert_true(effect is InspectPortablePackage(0, 2, _))
}

///|
test "accepted human result prepare wire preserves four old fields and exact optional bytes" {
  let legacy = portable_book_prepare_body(
    "/library-a",
    portable_book_test_id(),
    "1.2.3",
    ["output/extra.txt"],
  )
  guard legacy is Object(old_fields) else { fail("body must be an object") }
  assert_eq(old_fields.length(), 4)
  assert_true(old_fields.get("accepted_human_result_base64") is None)
  let raw = portable_human_test_source().raw_base64
  let body = portable_book_prepare_body(
    "/library-a",
    portable_book_test_id(),
    "1.2.3",
    ["output/extra.txt"],
    accepted_human_result_base64=raw,
  )
  guard body is Object(fields) else { fail("body must be an object") }
  assert_eq(fields.length(), 5)
  assert_eq(fields["accepted_human_result_base64"], raw.to_json())
  for key, value in old_fields {
    assert_eq(fields[key], value)
  }
}

///|
#warnings("-alert_unstable")
test "accepted human result preview escapes full text and labels captured unsigned provenance" {
  let source = portable_human_test_source()
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(render_portable_book_human_result_preview(source)),
  )
  assert_true(html.contains("&lt;script&gt;"))
  assert_false(html.contains("<script>"))
  assert_true(html.contains("完整文本"))
  for
    text in [
      "Unsigned source observation",
      "no live authenticity, signature, or acceptance authority",
      "non-authorizing",
      source.task.record_id,
      source.report.record_id,
      source.revision.revision_id,
      source.revision.output_evidence_id,
      source.content_sha256,
      "Full captured text",
    ] {
    assert_true(html.contains(text))
  }
  let dispatch : Dispatch[Msg] = _ => @rabbita.none
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_portable_book_human_result_picker(
        dispatch,
        portable_human_test_selected(),
      ),
    ),
  )
  assert_eq(
    html.split("data-testid=\"portable-book-human-result-choose\"").length(),
    2,
  )
  assert_true(html.contains("Remove accepted human result"))
  assert_true(html.contains("explicitly includes this exact source JSON"))
}
