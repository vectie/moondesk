///|
async test "confined Office open save conflict and independent reopen" {
  let project = @env.current_dir().unwrap_or(".")
  let test_root = @pathx.join(project, "_build/phase7-tests")
  if !@fs.exists(test_root) {
    @fs.mkdir(test_root, permission=0o755)
  }
  let root = @pathx.join(test_root, "office-route")
  if !@fs.exists(root) {
    @fs.mkdir(root, permission=0o755)
  }
  let workspace = @desk.workspace(
    id="office-book",
    name="Office book",
    root_path=root,
    kind=MoonBook,
  )
  let path = @pathx.join(root, "sample.docx")
  let initial = valid_docx_bytes()
  let initial_bytes = Bytes::from_array(initial.view())
  @fs.write_file(path, initial_bytes, create_mode=CreateOrTruncate)
  let (clean, opened) = open_workspace_office(workspace, "sample.docx").unwrap()
  assert_eq(clean, "sample.docx")
  guard opened.supported is Word([paragraph, ..]) else { fail("expected DOCX") }
  assert_eq(paragraph.runs[0].text, "MoonDesk DOCX")
  let opened_json = office_document_json(clean, opened, initial_bytes.view())
  let baseline = json_string(opened_json, "baseline", default="")
  assert_eq(@base64.decode(baseline), initial_bytes)
  let payload : Json = {
    "operation": "docx-paragraph",
    "paragraph": 0,
    "text": "Route saved DOCX",
    "bold": true,
    "italic": false,
    "underline": true,
  }
  let receipt = save_workspace_office(
    workspace, "sample.docx", baseline, payload,
  ).unwrap()
  assert_eq(json_string(receipt, "path", default=""), "sample.docx")
  let saved_bytes = @fs.read_file(path).binary()
  assert_eq(
    @base64.decode(json_string(receipt, "baseline", default="")),
    saved_bytes,
  )
  let independently_reopened = office_document_open_bytes(
    "sample.docx",
    saved_bytes.to_fixedarray(),
  ).unwrap()
  guard independently_reopened.supported is Word([saved_paragraph, ..]) else {
    fail("expected independently reopened DOCX")
  }
  assert_eq(saved_paragraph.runs[0].text, "Route saved DOCX")
  assert_true(saved_paragraph.runs[0].underline)
  let conflict = save_workspace_office(workspace, "sample.docx", baseline, {
    "operation": "docx-paragraph",
    "paragraph": 0,
    "text": "Must not overwrite",
    "bold": true,
    "italic": false,
    "underline": true,
  })
  guard conflict is Err(error) else { fail("expected stale baseline conflict") }
  assert_eq(json_int(error, "code", default=0), 409)
  let final = office_document_open_bytes(
    "sample.docx",
    @fs.read_file(path).binary().to_fixedarray(),
  ).unwrap()
  guard final.supported is Word([final_paragraph, ..]) else {
    fail("expected final DOCX")
  }
  assert_eq(final_paragraph.runs[0].text, "Route saved DOCX")
}

///|
test "Office routes are selected-workspace confined contracts" {
  let contracts = @desk.desktop_api_route_contracts()
  let open_path = @desk.workspace_action_route("office")
  let save_path = @desk.workspace_action_route("office/save")
  let open = contracts
    .search_by(contract => contract.path == open_path)
    .unwrap()
  let save = contracts
    .search_by(contract => contract.path == save_path)
    .unwrap()
  assert_eq(contracts[open].authority_scope, "read-only")
  assert_eq(contracts[open].methods, ["GET", "HEAD"])
  assert_eq(contracts[save].authority_scope, "selected-book")
  assert_eq(contracts[save].methods, ["POST"])
}
