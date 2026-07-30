///|
test "structured DOCX edit preserves unknown XML and unsupported ZIP members" {
  let opened = office_document_open_bytes("sample.docx", valid_docx_bytes()).unwrap()
  guard opened.supported is Word([paragraph, ..]) else {
    fail("expected DOCX model")
  }
  assert_true(paragraph.runs[0].bold)
  let edited = office_document_set_docx_paragraphs(opened, [
    {
      runs: [
        { text: "Edited DOCX", bold: true, italic: true, underline: false },
      ],
    },
  ]).unwrap()
  let saved = office_document_save_bytes(edited)
  let independently_parsed = @moonzip.unzip_sync(saved)
  let document = independently_parsed
    .search_by(entry => entry.0 == "word/document.xml")
    .unwrap()
  let xml = @moonzip.str_from_u8(independently_parsed[document].1)
  assert_true(xml.contains("Edited DOCX"))
  assert_true(xml.contains("<w:sectPr"))
  let preserved = independently_parsed
    .search_by(entry => entry.0 == "custom/preserved.bin")
    .unwrap()
  assert_eq(
    independently_parsed[preserved].1,
    ([0x00, 0xff, 0x42] : FixedArray[Byte]),
  )
  let reopened = office_document_open_bytes("sample.docx", saved).unwrap()
  guard reopened.supported is Word([reopened_paragraph, ..]) else {
    fail("expected reopened DOCX")
  }
  assert_eq(reopened_paragraph.runs[0].text, "Edited DOCX")
  assert_true(reopened_paragraph.runs[0].italic)
}

///|
test "structured XLSX edit changes value and formula and independently reopens saved bytes" {
  let opened = office_document_open_bytes("sample.xlsx", valid_xlsx_bytes()).unwrap()
  guard opened.supported is Spreadsheet([sheet, ..]) else {
    fail("expected XLSX model")
  }
  assert_eq(sheet.cells[0].reference, "A1")
  assert_eq(sheet.cells[0].formula, Some("1+1"))
  let edited = office_document_set_xlsx_cell(
    opened,
    "xl/worksheets/sheet1.xml",
    "A1",
    "6",
    Some("SUM(1,2,3)"),
  ).unwrap()
  let saved = office_document_save_bytes(edited)
  let entries = @moonzip.unzip_sync(saved)
  let index = entries
    .search_by(entry => entry.0 == "xl/worksheets/sheet1.xml")
    .unwrap()
  let xml = @moonzip.str_from_u8(entries[index].1)
  assert_true(xml.contains("<f>SUM(1,2,3)</f>"))
  assert_true(xml.contains("<v>6</v>"))
  assert_true(xml.contains("<sheetData>"))
  let reopened = office_document_open_bytes("sample.xlsx", saved).unwrap()
  guard reopened.supported is Spreadsheet([reopened_sheet, ..]) else {
    fail("expected reopened XLSX")
  }
  assert_eq(reopened_sheet.cells[0].value, "6")
  assert_eq(reopened_sheet.cells[0].formula, Some("SUM(1,2,3)"))
}

///|
test "structured PPTX edit changes text and basic object properties" {
  let opened = office_document_open_bytes("sample.pptx", valid_pptx_bytes()).unwrap()
  guard opened.supported is Presentation([slide, ..]) else {
    fail("expected PPTX model")
  }
  let current = slide.objects[0]
  let changed = {
    ..current,
    text: "Edited slide",
    x: Some(200),
    y: Some(300),
    width: Some(400),
    height: Some(500),
  }
  let edited = office_document_set_pptx_object(
    opened, "ppt/slides/slide1.xml", 0, changed,
  ).unwrap()
  let saved = office_document_save_bytes(edited)
  let entries = @moonzip.unzip_sync(saved)
  let index = entries
    .search_by(entry => entry.0 == "ppt/slides/slide1.xml")
    .unwrap()
  let xml = @moonzip.str_from_u8(entries[index].1)
  assert_true(xml.contains("Edited slide"))
  assert_true(xml.contains("<a:off x=\"200\" y=\"300\"/>"))
  assert_true(xml.contains("<a:ext cx=\"400\" cy=\"500\"/>"))
  let reopened = office_document_open_bytes("sample.pptx", saved).unwrap()
  guard reopened.supported is Presentation([reopened_slide, ..]) else {
    fail("expected reopened PPTX")
  }
  assert_eq(reopened_slide.objects[0].text, "Edited slide")
  assert_eq(reopened_slide.objects[0].x, Some(200))
}

///|
test "XML supported-node parser requires a complete element-name boundary" {
  let docx = "<w:document><w:pPr><w:r><w:t>wrong</w:t></w:r></w:pPr><w:p><w:r><w:t>right</w:t></w:r></w:p></w:document>"
  let paragraphs = parse_docx(docx)
  assert_eq(paragraphs.length(), 1)
  assert_eq(paragraphs[0].runs[0].text, "right")
  let slide = "<p:sld><p:spTree><p:sp><p:spPr><a:xfrm><a:off x=\"1\" y=\"2\"/><a:ext cx=\"3\" cy=\"4\"/></a:xfrm></p:spPr><p:txBody><a:p><a:r><a:t>right</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:sld>"
  assert_eq(
    parse_pptx_slide("ppt/slides/slide1.xml", slide).objects.length(),
    1,
  )
  assert_eq(
    office_opening_tags("<sheets><sheet name=\"one\"/></sheets>", "sheet").length(),
    1,
  )
  assert_eq(
    office_opening_tags(
      "<p:sldIdLst><p:sldId r:id=\"r7\"/></p:sldIdLst>", "p:sldId",
    ).length(),
    1,
  )
}

///|
test "targeted DOCX run edit preserves sibling runs and unknown paragraph and run XML" {
  let xml = "<?xml version=\"1.0\"?><w:document><w:body><w:p><w:pPr><w:keepNext/></w:pPr><w:r><w:rPr><w:color w:val=\"FF0000\"/></w:rPr><w:t>first</w:t></w:r><w:r><w:custom preserved=\"yes\"/><w:t>second</w:t></w:r></w:p><w:sectPr/></w:body></w:document>"
  let bytes = @moonzip.zip_sync([
    ("[Content_Types].xml", @moonzip.str_to_u8("<Types/>")),
    ("_rels/.rels", @moonzip.str_to_u8("<Relationships/>")),
    ("word/document.xml", @moonzip.str_to_u8(xml)),
  ])
  let opened = office_document_open_bytes("sample.docx", bytes).unwrap()
  let edited = office_document_set_docx_run(opened, 0, 1, {
    text: "changed",
    bold: true,
    italic: false,
    underline: false,
  }).unwrap()
  let saved = office_document_part_text(edited, "word/document.xml").unwrap()
  assert_true(saved.contains("<w:keepNext/>"))
  assert_true(saved.contains("<w:color w:val=\"FF0000\"/>"))
  assert_true(saved.contains("<w:t>first</w:t>"))
  assert_true(saved.contains("<w:custom preserved=\"yes\"/>"))
  assert_true(saved.contains("changed"))
  assert_true(
    office_document_set_docx_run(edited, 0, 9, {
      text: "bad",
      bold: false,
      italic: false,
      underline: false,
    })
    is Err(_),
  )
}

///|
test "Office model rejects invalid packages and states limited support" {
  let opened = office_document_open_bytes("sample.docx", valid_docx_bytes()).unwrap()
  assert_true(opened.warnings[0].contains("Supported subset only"))
  assert_true(
    office_document_open_bytes("sample.docx", @moonzip.zip_sync([])) is Err(_),
  )
}

///|
test "XLSX workbook relationships define sheet order names and preserve attributed cell XML" {
  let workbook = "<workbook><sheets><sheet name=\"First real\" r:id=\"rel-A\"/><sheet name=\"Second real\" r:id=\"rel-Z\"/></sheets></workbook>"
  let rels = "<Relationships><Relationship Id=\"rel-A\" Target=\"worksheets/alpha.xml\"/><Relationship Id=\"rel-Z\" Target=\"worksheets/zeta.xml\"/></Relationships>"
  let alpha = "<worksheet><sheetData><row><c r=\"A1\" s=\"7\" custom=\"keep\"><extLst><ext uri=\"unknown\"/></extLst><f>1+1</f><v>2</v></c></row></sheetData></worksheet>"
  let zeta = "<worksheet><sheetData><row><c r=\"Z9\"><v>9</v></c></row></sheetData></worksheet>"
  let package = @moonzip.zip_sync([
    ("xl/worksheets/zeta.xml", office_xml(zeta)),
    ("[Content_Types].xml", office_xml("<Types/>")),
    ("_rels/.rels", office_xml("<Relationships/>")),
    ("xl/worksheets/alpha.xml", office_xml(alpha)),
    ("xl/_rels/workbook.xml.rels", office_xml(rels)),
    ("xl/workbook.xml", office_xml(workbook)),
  ])
  let opened = office_document_open_bytes("ordered.xlsx", package).unwrap()
  guard opened.supported is Spreadsheet(sheets) else {
    fail("expected spreadsheet")
  }
  assert_eq(sheets.map(sheet => sheet.name), ["First real", "Second real"])
  assert_eq(sheets.map(sheet => sheet.part), [
    "xl/worksheets/alpha.xml", "xl/worksheets/zeta.xml",
  ])
  let edited = office_document_set_xlsx_cell(
    opened,
    "xl/worksheets/alpha.xml",
    "A1",
    "6",
    Some("SUM(1,2,3)"),
  ).unwrap()
  let saved = office_document_part_text(edited, "xl/worksheets/alpha.xml").unwrap()
  assert_true(saved.contains("s=\"7\" custom=\"keep\""))
  assert_true(saved.contains("<extLst><ext uri=\"unknown\"/></extLst>"))
  let reopened = office_document_open_bytes(
    "ordered.xlsx",
    office_document_save_bytes(edited),
  ).unwrap()
  guard reopened.supported is Spreadsheet([first, ..]) else {
    fail("expected reopened spreadsheet")
  }
  assert_eq(first.name, "First real")
  assert_eq(first.cells[0].value, "6")
}

///|
test "PPTX relationships define slide order and targeted shape edit preserves unrelated XML" {
  let presentation = "<p:presentation><p:sldIdLst><p:sldId id=\"9\" r:id=\"slide-A\"/><p:sldId id=\"3\" r:id=\"slide-B\"/></p:sldIdLst></p:presentation>"
  let rels = "<Relationships><Relationship Id=\"slide-A\" Target=\"slides/alpha.xml\"/><Relationship Id=\"slide-B\" Target=\"slides/beta.xml\"/></Relationships>"
  let alpha = "<p:sld><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id=\"7\" name=\"Keep me\"/></p:nvSpPr><p:spPr><a:prstGeom prst=\"roundRect\"/><a:xfrm><a:off x=\"1\" y=\"2\"/><a:ext cx=\"3\" cy=\"4\"/></a:xfrm></p:spPr><p:txBody><a:p><a:r><a:t>alpha</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>"
  let beta = alpha.replace_all(old="alpha", new="beta")
  let package = @moonzip.zip_sync([
    ("ppt/slides/beta.xml", office_xml(beta)),
    ("[Content_Types].xml", office_xml("<Types/>")),
    ("_rels/.rels", office_xml("<Relationships/>")),
    ("ppt/slides/alpha.xml", office_xml(alpha)),
    ("ppt/_rels/presentation.xml.rels", office_xml(rels)),
    ("ppt/presentation.xml", office_xml(presentation)),
  ])
  let opened = office_document_open_bytes("ordered.pptx", package).unwrap()
  guard opened.supported is Presentation(slides) else {
    fail("expected presentation")
  }
  assert_eq(slides.map(slide => slide.part), [
    "ppt/slides/alpha.xml", "ppt/slides/beta.xml",
  ])
  let current = slides[0].objects[0]
  let edited = office_document_set_pptx_object(
    opened,
    "ppt/slides/alpha.xml",
    0,
    {
      ..current,
      text: "changed",
      x: Some(10),
      y: Some(20),
      width: Some(30),
      height: Some(40),
    },
  ).unwrap()
  let saved = office_document_part_text(edited, "ppt/slides/alpha.xml").unwrap()
  assert_true(saved.contains("name=\"Keep me\""))
  assert_true(saved.contains("<a:prstGeom prst=\"roundRect\"/>"))
  assert_true(saved.contains("changed"))
  let ambiguous = alpha.replace(
    old="</a:r></a:p>",
    new="</a:r><a:r><a:t>extra</a:t></a:r></a:p>",
  )
  let bad_package = @moonzip.zip_sync([
    ("[Content_Types].xml", office_xml("<Types/>")),
    ("_rels/.rels", office_xml("<Relationships/>")),
    (
      "ppt/presentation.xml",
      office_xml(
        "<p:presentation><p:sldIdLst><p:sldId r:id=\"one\"/></p:sldIdLst></p:presentation>",
      ),
    ),
    (
      "ppt/_rels/presentation.xml.rels",
      office_xml(
        "<Relationships><Relationship Id=\"one\" Target=\"slides/alpha.xml\"/></Relationships>",
      ),
    ),
    ("ppt/slides/alpha.xml", office_xml(ambiguous)),
  ])
  let bad = office_document_open_bytes("bad.pptx", bad_package).unwrap()
  guard bad.supported is Presentation([bad_slide, ..]) else {
    fail("expected bad presentation model")
  }
  assert_true(
    office_document_set_pptx_object(
      bad,
      "ppt/slides/alpha.xml",
      0,
      bad_slide.objects[0],
    )
    is Err(_),
  )
}
