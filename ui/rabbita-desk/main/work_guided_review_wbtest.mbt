///|
extern "js" fn guided_desk_before(
  html : String,
  left : String,
  right : String,
) -> Bool =
  #| (html, left, right) => html.indexOf(left) >= 0 && html.indexOf(right) > html.indexOf(left)

///|
extern "js" fn guided_desk_visible(html : String, text : String) -> Bool =
  #| (html, text) => {
  #|   const end = html.indexOf(text); if (end < 0) return false;
  #|   let depth = 0;
  #|   for (const tag of html.slice(0, end).match(/<\/?details\b[^>]*>/g) || []) depth += tag.startsWith('</') ? -1 : 1;
  #|   return depth === 0;
  #| }

///|
#warnings("-alert_unstable")
fn guided_desk_markup(model : Model) -> String {
  @rabbita.render_to_string(
    @rabbita.static_cell(render_work_handoff(code_mode_test_dispatch, model)),
  )
}

///|
#warnings("-alert_unstable")
test "guided handoff shows current output before instruction and exact return" {
  let model = continuation_desk_ready()
  let canonical = model.work_handoff.canonical.unwrap()
  let state = {
    ..model.work_handoff,
    output_hint: output_desk_hint(),
    output: output_desk_response(canonical),
  }
  let model = { ..model, work_handoff: state, }
  let html = guided_desk_markup(model)
  assert_true(
    guided_desk_before(html, "1 · Inspect result", "2 · Request a change"),
  )
  assert_true(
    guided_desk_before(html, "Download current file", "New human instruction"),
  )
  assert_true(
    guided_desk_before(
      html, "New human instruction", "3 · Return selected result",
    ),
  )
  assert_true(
    html.contains("Later work or human edits may have changed this file"),
  )
  assert_true(html.contains("T&amp;one"))
  assert_true(html.contains("<summary>Work identity and navigation</summary>"))
  assert_true(html.contains("Captured original command details"))
  assert_false(guided_desk_visible(html, "Requested book root:"))
  assert_true(guided_desk_visible(html, "Original execution:"))
  assert_true(
    guided_desk_visible(html, "Saved transcript temporarily unavailable"),
  )
  assert_false(html.contains("Return selected result to MoonProj for review"))
  assert_eq(model.work_handoff.target, state.target)
  assert_eq(
    model.work_handoff.continuation.selected_return,
    state.continuation.selected_return,
  )
}

///|
test "guided handoff keeps uncertainty and recovery visible without new submission" {
  let model = continuation_desk_ready()
  let state = {
    ..model.work_handoff.continuation,
    phase: "uncertain",
    error: "Submission outcome is unknown",
  }
  let html = guided_desk_markup({
    ..model,
    work_handoff: {
      ..model.work_handoff,
      continuation: state,
      files_error: "Files cannot be read",
    },
  })
  assert_true(guided_desk_visible(html, "Submission outcome is unknown"))
  assert_true(guided_desk_visible(html, "Recover saved operation"))
  assert_true(guided_desk_visible(html, "Files cannot be read"))
  assert_false(html.contains("Capture and start fresh follow-up"))
}

///|
#warnings("-alert_unstable")
test "guided original result never substitutes later session messages" {
  let model = handoff_desk_ready()
  let session = {
    ..code_mode_test_session("S/书"),
    mooncode_conversation: Some(
      code_mode_test_conversation("S/书", [
        code_mode_test_turn(
          "C?0",
          "Original instruction",
          assistant="Original result <exact>",
        ),
        code_mode_test_turn(
          "C1",
          "Later instruction",
          assistant="Later result must stay separate",
        ),
      ]),
    ),
  }
  let html = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_work_handoff_original_result(model, session, "C?0"),
    ),
  )
  assert_true(html.contains("Original result &lt;exact&gt;"))
  assert_false(html.contains("Later result"))
  let absent = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_work_handoff_original_result(model, session, "missing"),
    ),
  )
  assert_true(
    absent.contains(
      "No saved assistant result is recorded for this exact command",
    ),
  )
  assert_false(absent.contains("Original result &lt;exact&gt;"))
}

///|
test "guided followup result remains explicitly selected and unchanged" {
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
  let (_, selected) = update_work_continuation(
    code_mode_test_dispatch,
    SelectReturn("K1"),
    model,
  )
  let html = guided_desk_markup(selected)
  assert_true(html.contains("Return selected result to MoonProj for review"))
  assert_true(html.contains("Selected exact result"))
  assert_true(html.contains("input-digest"))
  assert_false(guided_desk_visible(html, "input-digest"))
  assert_eq(selected.work_handoff.continuation.selected_return, "K1")
  assert_true(
    guided_desk_before(html, "New human instruction", "Actual follow-up result"),
  )
}
