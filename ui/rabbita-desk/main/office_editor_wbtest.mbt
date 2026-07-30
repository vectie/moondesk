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
test "Office save uses the nested workspace route contract" {
  assert_eq(
    @desk.workspace_endpoint_url("book-research-alpha", "office/save"),
    "/api/workspaces/book-research-alpha/office/save",
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
  let failed = update_office_editor(dirty, OfficeSaved(Err("conflict")))
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
  let conflict = update_office_editor(dirty, OfficeConflict("current-baseline"))
  assert_eq(conflict.draft_items[0].text, "draft survives conflict")
  assert_eq(conflict.conflict_baseline, Some("current-baseline"))
  let reload = update_office_editor(conflict, OfficeReloadConflict)
  assert_true(reload.loading)
  assert_eq(reload.draft_items[0].text, "draft survives conflict")
  let reload_failed = update_office_editor(
    reload,
    OfficeOpened(Err("reload failed")),
  )
  assert_eq(reload_failed.draft_items[0].text, "draft survives conflict")
  assert_true(office_editor_dirty(reload_failed))
  let replace = update_office_editor(conflict, OfficeReplaceConflict)
  assert_true(replace.saving)
  assert_eq(replace.saved_baseline, "current-baseline")
  assert_eq(replace.draft_items[0].text, "draft survives conflict")
}
