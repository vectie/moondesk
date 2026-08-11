///|
fn office_test_item(
  section : String,
  reference : String,
  section_index : Int,
  item_index : Int,
) -> OfficeEditorItem {
  {
    section,
    reference,
    section_index,
    item_index,
    text: "before",
    formula: "",
    bold: false,
    italic: false,
    underline: false,
    x: 1,
    y: 2,
    width: 3,
    height: 4,
  }
}

///|
fn office_test_state(
  kind : OfficeEditorKind,
  item : OfficeEditorItem,
) -> OfficeEditorState {
  let document = {
    path: "file",
    kind,
    items: [item],
    warnings: ["Supported subset only"],
    baseline: "baseline",
  }
  {
    ..init_office_editor("workspace"),
    path: "file",
    path_input: "file",
    document: Some(document),
    draft_items: [item],
    saved_baseline: "baseline",
  }
}

///|
fn office_test_identity(
  state : OfficeEditorState,
) -> OfficeEditorRequestIdentity {
  office_editor_identity(state)
}

///|
fn office_view_test_dispatch(_msg : Msg) -> @rabbita.Cmd {
  @rabbita.none
}

///|
test "Office editor renders honest live previews for every supported kind" {
  let item = office_test_item("section", "item", 0, 0)
  let docx = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_office_editor(office_view_test_dispatch, {
        ..office_test_state(OfficeDocx, item),
        draft_items: [{ ..item, bold: true }],
      }),
    ),
  )
  let xlsx = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_office_editor(office_view_test_dispatch, {
        ..office_test_state(OfficeXlsx, item),
        draft_items: [{ ..item, text: "42", formula: "SUM(A1:A6)" }],
      }),
    ),
  )
  let pptx = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_office_editor(office_view_test_dispatch, {
        ..office_test_state(OfficePptx, item),
        draft_items: [{ ..item, text: "Slide title" }],
      }),
    ),
  )
  assert_true(docx.contains("data-testid=\"office-docx-preview\""))
  assert_true(docx.contains("is-bold"))
  assert_true(xlsx.contains("data-testid=\"office-xlsx-preview\""))
  assert_true(xlsx.contains("SUM(A1:A6)"))
  assert_true(pptx.contains("data-testid=\"office-pptx-preview\""))
  assert_true(pptx.contains("Content, not slide fidelity"))
  assert_true(pptx.contains("X 1"))
  assert_true(pptx.contains("Y 2"))
  assert_true(pptx.contains("W 3"))
  assert_true(pptx.contains("H 4"))
}

///|
test "Office preview renders every supported item and selected geometry" {
  let first = { ..office_test_item("paragraph 0", "run 0", 0, 0), text: "First", }
  let second = {
    ..office_test_item("paragraph 1", "run 0", 1, 0),
    text: "Second",
    x: 20,
    y: 30,
    width: 40,
    height: 50,
  }
  let initial = office_test_state(OfficePptx, first)
  let document = match initial.document {
    Some(document) => { ..document, items: [first, second], }
    None => fail("office test document missing")
  }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_office_editor(office_view_test_dispatch, {
        ..initial,
        document: Some(document),
        draft_items: [first, second],
        selected: 1,
      }),
    ),
  )
  assert_true(markup.contains("First"))
  assert_true(markup.contains("Second"))
  assert_true(markup.contains("office-preview-slide-object is-selected"))
  assert_true(markup.contains("left:"))
  assert_true(markup.contains("width:"))
}

///|
test "Office save uses the nested workspace route contract" {
  assert_eq(
    @desk.workspace_endpoint_url("book-research-alpha", "office/save"),
    "/api/workspaces/book-research-alpha/office/save",
  )
  assert_eq(
    office_editor_endpoint_url(
      "book research/#one", "office", "documents/report #1.xlsx",
    ),
    "/api/workspaces/book%20research%2F%23one/office?path=documents%2Freport%20%231.xlsx",
  )
}

///|
test "DOCX styles produce paragraph-local structured save payload" {
  let initial = office_test_state(
    OfficeDocx,
    office_test_item("paragraph 2", "run 1", 2, 1),
  )
  let edited = update_office_editor(
    update_office_editor(initial, OfficeEditText("after")),
    OfficeToggleBold,
  )
  let payload = office_editor_save_body(edited)
  assert_eq(
    json_field_string(payload, "operation", default=""),
    "docx-paragraph",
  )
  assert_eq(json_field_int(payload, "paragraph", default=-1), 2)
  assert_true(json_field_bool(payload, "bold", default=false))
  assert_eq(json_field_string(payload, "text", default=""), "after")
}

///|
test "XLSX payload keeps sheet cell value and formula" {
  let initial = office_test_state(
    OfficeXlsx,
    office_test_item("xl/worksheets/sheet2.xml", "C7", 1, 4),
  )
  let edited = update_office_editor(
    update_office_editor(initial, OfficeEditText("42")),
    OfficeEditFormula("SUM(A1:A6)"),
  )
  let payload = office_editor_save_body(edited)
  assert_eq(
    json_field_string(payload, "sheet_part", default=""),
    "xl/worksheets/sheet2.xml",
  )
  assert_eq(json_field_string(payload, "reference", default=""), "C7")
  assert_eq(json_field_string(payload, "value", default=""), "42")
  assert_eq(json_field_string(payload, "formula", default=""), "SUM(A1:A6)")
}

///|
test "PPTX payload uses slide-local object and editable geometry" {
  let initial = office_test_state(
    OfficePptx,
    office_test_item("ppt/slides/slide3.xml", "object 2", 2, 2),
  )
  let edited = update_office_editor(
    update_office_editor(
      update_office_editor(initial, OfficeEditX(100)),
      OfficeEditY(200),
    ),
    OfficeEditWidth(300),
  )
  let edited = update_office_editor(edited, OfficeEditHeight(400))
  let payload = office_editor_save_body(edited)
  assert_eq(
    json_field_string(payload, "slide_part", default=""),
    "ppt/slides/slide3.xml",
  )
  assert_eq(json_field_int(payload, "object", default=-1), 2)
  assert_eq(json_field_int(payload, "x", default=0), 100)
  assert_eq(json_field_int(payload, "height", default=0), 400)
}

///|
test "Office non-success payload surfaces backend message or error" {
  assert_true(
    parse_office_editor_http(Ok({ "message": "Office package is encrypted" }))
    is Err("Office package is encrypted"),
  )
  assert_true(
    parse_office_editor_http(Ok({ "error": "Office member is malformed" }))
    is Err("Office member is malformed"),
  )
}

///|
test "Office failure preserves dirty draft and dirty state blocks close reopen" {
  let initial = office_test_state(
    OfficeDocx,
    office_test_item("paragraph 0", "run 0", 0, 0),
  )
  let dirty = update_office_editor(initial, OfficeEditText("draft survives"))
  let failed = update_office_editor(
    dirty,
    OfficeSaved(office_test_identity(dirty), Err("conflict")),
  )
  assert_true(office_editor_dirty(failed))
  assert_eq(failed.draft_items[0].text, "draft survives")
  let closed = update_office_editor(failed, OfficeClose)
  assert_true(closed.document is Some(_))
  let reopened = update_office_editor(failed, OfficeReopen)
  assert_false(reopened.loading)
  assert_true(reopened.status.contains("Save before reopening"))
}

///|
test "Office conflict supports explicit reload and deliberate replacement without silent draft loss" {
  let initial = office_test_state(
    OfficeDocx,
    office_test_item("paragraph 0", "run 0", 0, 0),
  )
  let dirty = update_office_editor(
    initial,
    OfficeEditText("draft survives conflict"),
  )
  let conflict = update_office_editor(
    dirty,
    OfficeConflict(office_test_identity(dirty), "current-baseline"),
  )
  assert_eq(conflict.draft_items[0].text, "draft survives conflict")
  assert_eq(conflict.conflict_baseline, Some("current-baseline"))
  let reload = update_office_editor(conflict, OfficeReloadConflict)
  assert_true(reload.loading)
  assert_eq(reload.draft_items[0].text, "draft survives conflict")
  let reload_failed = update_office_editor(
    reload,
    OfficeOpened(office_test_identity(reload), Err("reload failed")),
  )
  assert_eq(reload_failed.draft_items[0].text, "draft survives conflict")
  assert_true(office_editor_dirty(reload_failed))
  let replace = update_office_editor(conflict, OfficeReplaceConflict)
  assert_true(replace.saving)
  assert_eq(replace.saved_baseline, "current-baseline")
  assert_eq(replace.draft_items[0].text, "draft survives conflict")
}

///|
test "Office request identity rejects stale results after workspace rebind" {
  let opening = update_office_editor(
    { ..init_office_editor("book-a"), path_input: "documents/a.docx" },
    OfficeOpen,
  )
  let stale = office_test_identity(opening)
  let rebound = update_office_editor(opening, OfficeRebind("book-b"))
  assert_eq(rebound.workspace_id, "book-b")
  assert_false(office_editor_is_current(rebound, stale))
  let ignored = update_office_editor(
    rebound,
    OfficeOpened(
      stale,
      Ok({
        path: "documents/a.docx",
        kind: OfficeDocx,
        items: [],
        warnings: [],
        baseline: "old",
      }),
    ),
  )
  assert_true(ignored.document is None)
}

///|
test "Office item changes must be saved or discarded before selection moves" {
  let first = office_test_item("paragraph 0", "run 0", 0, 0)
  let second = office_test_item("paragraph 1", "run 0", 1, 0)
  let document : OfficeEditorDocument = {
    path: "documents/report.docx",
    kind: OfficeDocx,
    items: [first, second],
    warnings: [],
    baseline: "baseline",
  }
  let initial = {
    ..init_office_editor("workspace"),
    path: document.path,
    path_input: document.path,
    document: Some(document),
    draft_items: document.items,
    saved_baseline: document.baseline,
  }
  let dirty = update_office_editor(initial, OfficeEditText("edited first"))
  let blocked = update_office_editor(dirty, OfficeSelect(1))
  assert_eq(blocked.selected, 0)
  assert_true(blocked.status.contains("Save or discard"))
  let discarded = update_office_editor(blocked, OfficeDiscard)
  assert_false(office_editor_dirty(discarded))
  let selected = update_office_editor(discarded, OfficeSelect(1))
  assert_eq(selected.selected, 1)
}

///|
test "Office open validates authority path safety and supported file type" {
  let unbound = update_office_editor(
    { ..init_office_editor(""), path_input: "documents/report.docx" },
    OfficeOpen,
  )
  assert_false(unbound.loading)
  assert_true(unbound.status.contains("Select a MoonBook"))
  let unsafe = update_office_editor(
    { ..init_office_editor("book"), path_input: "../report.docx" },
    OfficeOpen,
  )
  assert_false(unsafe.loading)
  assert_true(unsafe.status.contains("Unsafe Office path"))
  let unsupported = update_office_editor(
    { ..init_office_editor("book"), path_input: "documents/report.pdf" },
    OfficeOpen,
  )
  assert_false(unsupported.loading)
  assert_true(unsupported.status.contains("DOCX, XLSX, or PPTX"))
}
