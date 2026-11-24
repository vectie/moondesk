///|
test "document text batch preserves XML structures and saves several edits together" {
  let xml = "<w:document><w:body><w:p><w:pPr><w:keepNext/></w:pPr><w:r><w:rPr><w:color w:val=\"FF0000\"/></w:rPr><w:t>one</w:t></w:r><w:r><w:t>two</w:t></w:r></w:p><w:p><w:r><w:t>three</w:t></w:r></w:p><w:sectPr/></w:body></w:document>"
  let bytes = @moonzip.zip_sync([
    ("[Content_Types].xml", office_xml("<Types/>")),
    ("_rels/.rels", office_xml("<Relationships/>")),
    ("word/document.xml", office_xml(xml)),
    ("custom/preserved.bin", [1, 2, 3]),
  ])
  let opened = office_document_open_bytes("sample.docx", bytes).unwrap()
  let edits : Array[Json] = [
    { "paragraph": 0, "run": 1, "text": " changed & 中文 " },
    { "paragraph": 1, "run": 0, "text": "last😀" },
  ]
  let edited = apply_workspace_office_edit(opened, {
    "operation": "docx-text",
    "edits": edits,
  }).unwrap()
  let saved = office_document_part_text(edited, "word/document.xml").unwrap()
  assert_eq(
    saved,
    xml
    .replace_all(
      old="<w:t>two</w:t>",
      new="<w:t xml:space=\"preserve\"> changed &amp; 中文 </w:t>",
    )
    .replace_all(
      old="<w:t>three</w:t>",
      new="<w:t xml:space=\"preserve\">last😀</w:t>",
    ),
  )
  let reopened = office_document_open_bytes(
    "sample.docx",
    office_document_save_bytes(edited),
  ).unwrap()
  guard reopened.supported is Word(paragraphs) else { fail("expected text") }
  assert_eq(paragraphs[0].runs[1].text, " changed & 中文 ")
  assert_eq(paragraphs[1].runs[0].text, "last😀")
  assert_true(
    office_document_set_docx_texts(
      opened,
      edits + [{ "paragraph": 900, "run": 0, "text": "bad" }],
    )
    is Err(_),
  )
  assert_eq(
    office_document_part_text(opened, "word/document.xml").unwrap(),
    xml,
  )
  assert_true(
    office_document_set_docx_texts(opened, [edits[0], edits[0]]) is Err(_),
  )
  let multiline = office_document_set_docx_texts(opened, [
    { "paragraph": 0, "run": 0, "text": "first\n第二行😀\n" },
  ]).unwrap()
  let multiline = office_document_open_bytes(
    "sample.docx",
    office_document_save_bytes(multiline),
  ).unwrap()
  guard multiline.supported is Word(lines) else { fail("expected lines") }
  assert_eq(lines[0].runs[0].text, "first\n第二行😀\n")
  let again = office_document_set_docx_texts(multiline, [
    { "paragraph": 0, "run": 0, "text": "edited\nagain" },
  ]).unwrap()
  guard again.supported is Word(lines) else { fail("expected lines") }
  assert_eq(lines[0].runs[0].text, "edited\nagain")
}
