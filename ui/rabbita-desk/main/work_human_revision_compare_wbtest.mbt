///|
test "revision comparison handles empty insert remove identical and repeated lines" {
  let empty = work_human_revision_compare("", "")
  assert_true(empty.rows.is_empty())
  assert_eq(empty.added, 0)
  assert_eq(empty.removed, 0)
  assert_eq(work_human_revision_text_preview(""), "[empty file]")
  let insert = work_human_revision_compare("", "hello\n")
  assert_eq(insert.added, 1)
  assert_eq(insert.removed, 0)
  assert_eq(insert.rows[0].kind, "Added")
  assert_eq(insert.rows[0].line, 1)
  let remove = work_human_revision_compare("hello\n", "")
  assert_eq(remove.removed, 1)
  assert_eq(remove.added, 0)
  let repeat = work_human_revision_compare(
    "same\nold\nsame\n", "same\nnew\nsame\n",
  )
  assert_eq(repeat.removed, 1)
  assert_eq(repeat.added, 1)
  assert_eq(repeat.rows[0].line, 2)
  assert_eq(repeat.rows[1].line, 2)
  assert_false(repeat.coarse)
}

///|
test "revision comparison preserves Unicode blank lines and exact line endings" {
  let raw = "书😀\r\n\r\nlast\rfinal\n"
  assert_eq(work_human_revision_lines(raw).join(""), raw)
  assert_eq(work_human_revision_lines("\n"), ["\n"])
  assert_eq(work_human_revision_lines("a\nb"), ["a\n", "b"])
  let endings = work_human_revision_compare("书😀\r\n", "书😀\n")
  assert_eq(endings.removed, 1)
  assert_eq(endings.added, 1)
  assert_eq(endings.rows[0].text, "书😀 [CRLF]")
  assert_eq(endings.rows[1].text, "书😀 [LF]")
  let final_line = work_human_revision_compare("text\n", "text")
  assert_eq(final_line.rows[1].text, "text [no line ending]")
  assert_eq(work_human_revision_line_preview("\r"), "[empty line] [CR]")
  let unicode = Array::make(299, "x").join("") + "😀end"
  let preview = work_human_revision_line_preview(unicode)
  assert_true(preview.contains("[line shortened]"))
  assert_false(preview.contains("\uFFFD"))
  assert_eq(
    preview,
    Array::make(299, "x").join("") + "… [line shortened] [no line ending]",
  )
}

///|
test "revision comparison keeps minimal separated edits and late changes in large files" {
  let comparison = work_human_revision_compare(
    "a\nold one\nb\nold two\nz\n", "a\nnew one\nb\nnew two\nz\n",
  )
  assert_eq(comparison.removed, 2)
  assert_eq(comparison.added, 2)
  assert_eq(comparison.rows.map(row => row.line), [2, 2, 4, 4])
  let prefix = Array::make(10000, "same\n").join("")
  let late = work_human_revision_compare(prefix + "old\n", prefix + "new\n")
  assert_false(late.coarse)
  assert_eq(late.rows.length(), 2)
  assert_eq(late.rows[0].line, 10001)
  assert_eq(late.rows[1].line, 10001)
}

///|
test "revision comparison bounds exact and coarse rows without mutating text" {
  let old = Array::make(200, "old\n").join("")
  let new = Array::make(200, "new\n").join("")
  let exact = work_human_revision_compare(old, new)
  assert_false(exact.coarse)
  assert_eq(exact.removed, 200)
  assert_eq(exact.added, 200)
  assert_eq(exact.rows.length(), 160)
  let coarse = work_human_revision_compare(old + "old\n", new + "new\n")
  assert_true(coarse.coarse)
  assert_eq(coarse.removed, 201)
  assert_eq(coarse.added, 201)
  assert_eq(coarse.rows.length(), 160)
  assert_eq(coarse.rows.filter(row => row.kind == "Removed").length(), 80)
  assert_eq(coarse.rows.filter(row => row.kind == "Added").length(), 80)
  let preview = work_human_revision_text_preview(old)
  assert_true(preview.contains("120 more lines not shown"))
  assert_false(preview.contains("81 ·"))
  assert_eq(old.length(), 800)
}

///|
fn revision_comparison_test_html(model : Model) -> String {
  let state = model.work_handoff
  render_test_dom(
    @rabbita.static_cell(
      render_work_human_revision(
        code_mode_test_dispatch,
        state,
        state.target.unwrap(),
        state.canonical.unwrap(),
      ),
    ),
  )
}

///|
test "revision comparison has keyboard disclosure escaped bounded text and full downloads" {
  let before = "<script>alert('before')</script>\r\n"
  let after = "<img src=x onerror=evil()> & 😀\n"
  let html = render_test_dom(
    @rabbita.static_cell(
      render_work_human_revision_comparison(
        before, after, "Review my changes", "file when editing began", "my draft",
      ),
    ),
  )
  assert_true(html.contains("<summary"))
  assert_true(html.contains("Review my changes"))
  assert_true(html.contains("tabindex=\"0\""))
  assert_true(html.contains("aria-label=\"Line changes:"))
  assert_true(html.contains("Removed · line 1"))
  assert_true(html.contains("Added · line 1"))
  assert_true(html.contains("&lt;script&gt;"))
  assert_true(html.contains("&lt;img"))
  assert_false(html.contains("<script>"))
  assert_false(html.contains("<img src=x"))
  assert_true(html.contains("Download full before text"))
  assert_true(html.contains("Download full after text"))
  assert_true(
    html.contains(
      work_human_revision_download_url(before).replace_all(old="'", new="&#39;"),
    ),
  )
  assert_true(html.contains(work_human_revision_download_url(after)))
  let bounded = render_test_dom(
    @rabbita.static_cell(
      render_work_human_revision_comparison(
        Array::make(1000, "old\n").join(""),
        Array::make(1000, "new\n").join(""),
        "Review my changes",
        "before",
        "after",
      ),
    ),
  )
  assert_true(bounded.contains("Large change block"))
  assert_true(bounded.contains("Showing 160 of 2000 change rows"))
  assert_false(bounded.contains("Removed · line 81"))
  assert_false(bounded.contains("Added · line 81"))
}

///|
test "revision comparison follows repeated edits and exact saved recovery without changing authority" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let opened = human_revision_test_open(human_revision_test_ready())
  let first = human_revision_test_action(opened, RevisionDraft("first draft"))
  let second = human_revision_test_action(
    first,
    RevisionDraft("second 😀\r\n"),
  )
  let html = revision_comparison_test_html(second)
  assert_true(html.contains("Review my changes"))
  assert_true(html.contains("original current file [no line ending]"))
  assert_true(html.contains("second 😀 [CRLF]"))
  assert_false(html.contains("first draft"))
  assert_true(
    html.find("Review my changes").unwrap() <
    html.find("Save revision for this task</button>").unwrap(),
  )
  let saving = human_revision_test_action(second, RevisionSave)
  let retained = work_human_revision_restore(
    saving.work_handoff.target.unwrap(),
    saving.work_handoff.output_hint,
    true,
  )
  let restored = {
    ..saving,
    work_handoff: { ..saving.work_handoff, human_revision: retained, },
  }
  assert_eq(retained.baseline, "original current file")
  assert_eq(retained.draft, "second 😀\r\n")
  assert_true(
    revision_comparison_test_html(restored).contains(
      "retained draft for this save",
    ),
  )
  let retry = human_revision_test_action(restored, RevisionSave)
  let saved = human_revision_test_action(
    retry,
    RevisionReplied(
      retry.work_handoff.generation,
      retry.work_handoff.human_revision.request,
      "save",
      Ok(human_revision_test_saved(retry)),
    ),
  )
  let html = revision_comparison_test_html(saved)
  assert_true(html.contains("Review my saved changes"))
  assert_true(html.contains("confirmed retained human revision"))
  assert_true(html.contains("original current file [no line ending]"))
  assert_true(html.contains("second 😀 [CRLF]"))
  assert_eq(saved.work_handoff.continuation.selected_return, "")
  assert_eq(
    saved.work_handoff.human_revision.operation,
    saving.work_handoff.human_revision.operation,
  )
  let repeated = human_revision_test_open(saved)
  assert_eq(
    repeated.work_handoff.human_revision.baseline,
    "original current file",
  )
  assert_eq(repeated.work_handoff.human_revision.draft, "original current file")
  assert_true(revision_comparison_test_html(repeated).contains("No changes."))
  assert_false(revision_comparison_test_html(repeated).contains("second 😀"))
}

///|
test "revision comparison separates three conflict versions and updates only after explicit rebase" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let saving = human_revision_test_action(
    human_revision_test_action(
      human_revision_test_open(human_revision_test_ready()),
      RevisionDraft("my preserved edit"),
    ),
    RevisionSave,
  )
  let conflict = human_revision_test_action(
    saving,
    RevisionReplied(
      saving.work_handoff.generation,
      saving.work_handoff.human_revision.request,
      "save",
      Ok({
        "schema": "moondesk.human-revision-editor.v1",
        "state": "conflict",
        "current_content": "external changed text",
      }),
    ),
  )
  let html = revision_comparison_test_html(conflict)
  assert_true(html.contains("What changed in the working file?"))
  assert_true(html.contains("Compare current file with my draft"))
  assert_true(html.contains("original current file"))
  assert_true(html.contains("external changed text"))
  assert_true(html.contains("my preserved edit"))
  assert_eq(
    conflict.work_handoff.human_revision.baseline,
    "original current file",
  )
  let rebased = human_revision_test_action(conflict, RevisionRebase)
  assert_eq(
    rebased.work_handoff.human_revision.baseline,
    "external changed text",
  )
  assert_eq(rebased.work_handoff.human_revision.draft, "my preserved edit")
  assert_true(rebased.work_handoff.human_revision.operation is Null)
  let html = revision_comparison_test_html(rebased)
  assert_false(html.contains("original current file"))
  assert_false(html.contains("What changed in the working file?"))
}

///|
test "revision comparison never carries stale reply text into switched output" {
  let storage = continuation_desk_storage_setup()
  defer continuation_desk_storage_cleanup(storage)
  let saving = human_revision_test_action(
    human_revision_test_action(
      human_revision_test_open(human_revision_test_ready()),
      RevisionDraft("old output edit"),
    ),
    RevisionSave,
  )
  let next = human_revision_test_open(human_revision_test_ready())
  let switched = {
    ..next,
    work_handoff: {
      ..next.work_handoff,
      generation: saving.work_handoff.generation + 1,
    },
  }
  let late = human_revision_test_action(
    switched,
    RevisionReplied(
      saving.work_handoff.generation,
      saving.work_handoff.human_revision.request,
      "save",
      Ok(human_revision_test_saved(saving)),
    ),
  )
  assert_eq(late.work_handoff.human_revision.phase, "editing")
  assert_false(revision_comparison_test_html(late).contains("old output edit"))
  assert_true(revision_comparison_test_html(late).contains("No changes."))
}
