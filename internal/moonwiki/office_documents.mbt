///|
enum OfficeDocumentKind {
  Docx
  Xlsx
  Pptx
} derive(Eq, Debug)

///|
struct DocxRun {
  text : String
  bold : Bool
  italic : Bool
  underline : Bool
} derive(Eq, Debug)

///|
struct DocxParagraph {
  runs : Array[DocxRun]
} derive(Eq, Debug)

///|
struct XlsxCell {
  reference : String
  value : String
  formula : String?
} derive(Eq, Debug)

///|
struct XlsxSheet {
  part : String
  name : String
  cells : Array[XlsxCell]
} derive(Eq, Debug)

///|
struct PptxTextObject {
  text : String
  x : Int?
  y : Int?
  width : Int?
  height : Int?
} derive(Eq, Debug)

///|
struct PptxSlide {
  part : String
  objects : Array[PptxTextObject]
} derive(Eq, Debug)

///|
enum OfficeSupportedModel {
  Word(Array[DocxParagraph])
  Spreadsheet(Array[XlsxSheet])
  Presentation(Array[PptxSlide])
} derive(Eq, Debug)

///|
struct OfficeDocumentModel {
  kind : OfficeDocumentKind
  entries : Array[(String, FixedArray[Byte])]
  editable_parts : Array[String]
  supported : OfficeSupportedModel
  warnings : Array[String]
} derive(Debug)

///|
fn office_document_kind(path : String) -> OfficeDocumentKind? {
  let lower = path.to_lower()
  if lower.has_suffix(".docx") {
    Some(Docx)
  } else if lower.has_suffix(".xlsx") {
    Some(Xlsx)
  } else if lower.has_suffix(".pptx") {
    Some(Pptx)
  } else {
    None
  }
}

///|
fn office_required_parts(kind : OfficeDocumentKind) -> Array[String] {
  match kind {
    Docx => ["[Content_Types].xml", "_rels/.rels", "word/document.xml"]
    Xlsx => ["[Content_Types].xml", "_rels/.rels", "xl/workbook.xml"]
    Pptx => ["[Content_Types].xml", "_rels/.rels", "ppt/presentation.xml"]
  }
}

///|
fn office_editable_part(kind : OfficeDocumentKind, path : String) -> Bool {
  match kind {
    Docx => path == "word/document.xml"
    Xlsx => path.has_prefix("xl/worksheets/") && path.has_suffix(".xml")
    Pptx => path.has_prefix("ppt/slides/") && path.has_suffix(".xml")
  }
}

///|
fn office_escape_xml(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
}

///|
fn office_unescape_xml(text : String) -> String {
  text
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&apos;", new="'")
  .replace_all(old="&amp;", new="&")
}

///|
fn office_tag_ranges(
  xml : String,
  local : String,
) -> Array[(Int, Int, String, String)] {
  let ranges : Array[(Int, Int, String, String)] = []
  let open = "<" + local
  let close = "</" + local + ">"
  let mut offset = 0
  while offset < xml.length() {
    let tail = xml.substring(start=offset)
    let relative_open = match tail.find(open) {
      Some(index) => index
      None => break
    }
    let boundary = offset + relative_open + open.length()
    if boundary < xml.length() {
      let next = xml[boundary]
      if next != '>' &&
        next != '/' &&
        next != ' ' &&
        next != '\t' &&
        next != '\n' &&
        next != '\r' {
        offset = boundary
        continue
      }
    }
    let start = offset + relative_open
    let after_open = xml.substring(start~)
    let body_marker = match after_open.find(">") {
      Some(index) => index + 1
      None => break
    }
    let body_start = start + body_marker
    let after_body = xml.substring(start=body_start)
    let relative_close = match after_body.find(close) {
      Some(index) => index
      None => break
    }
    let end = body_start + relative_close + close.length()
    let opening = xml.substring(start~, end=body_start)
    ranges.push(
      (
        start,
        end,
        opening,
        xml.substring(start=body_start, end=body_start + relative_close),
      ),
    )
    offset = end
  }
  ranges
}

///|
fn office_tag_contents(xml : String, local : String) -> Array[String] {
  office_tag_ranges(xml, local).map(range => range.3)
}

///|
fn office_opening_tags(xml : String, local : String) -> Array[String] {
  let tags : Array[String] = []
  let open = "<" + local
  let mut offset = 0
  while offset < xml.length() {
    let tail = xml.substring(start=offset)
    let relative = match tail.find(open) {
      Some(index) => index
      None => break
    }
    let boundary = offset + relative + open.length()
    if boundary < xml.length() {
      let next = xml[boundary]
      if next != '>' &&
        next != '/' &&
        next != ' ' &&
        next != '\t' &&
        next != '\n' &&
        next != '\r' {
        offset = boundary
        continue
      }
    }
    let start = offset + relative
    let after = xml.substring(start~)
    let relative_end = match after.find(">") {
      Some(index) => index + 1
      None => break
    }
    tags.push(after.substring(start=0, end=relative_end))
    offset = start + relative_end
  }
  tags
}

///|
fn office_first_tag_text(xml : String, local : String) -> String? {
  match office_tag_contents(xml, local) {
    [first, ..] => Some(office_unescape_xml(first))
    _ => None
  }
}

///|
fn office_attribute(xml : String, name : String) -> String? {
  let needle = name + "=\""
  let start = match xml.find(needle) {
    Some(index) => index + needle.length()
    None => return None
  }
  let tail = xml.substring(start~)
  match tail.find("\"") {
    Some(end) => Some(office_unescape_xml(tail.substring(start=0, end~)))
    None => None
  }
}

///|
fn office_parse_int(value : String) -> Int? {
  let mut result = 0
  let mut has_digit = false
  for char in value {
    if char >= '0' && char <= '9' {
      has_digit = true
      result = result * 10 + char.to_int() - '0'.to_int()
    } else {
      return None
    }
  }
  if has_digit {
    Some(result)
  } else {
    None
  }
}

///|
fn office_int_attribute(xml : String, name : String) -> Int? {
  match office_attribute(xml, name) {
    Some(value) => office_parse_int(value)
    None => None
  }
}

///|
fn parse_docx(xml : String) -> Array[DocxParagraph] {
  office_tag_contents(xml, "w:p").map(paragraph => {
    let runs = office_tag_contents(paragraph, "w:r").map(run => {
      text: office_first_tag_text(run, "w:t").unwrap_or(""),
      bold: run.contains("<w:b") || run.contains("<b"),
      italic: run.contains("<w:i") || run.contains("<i"),
      underline: run.contains("<w:u") || run.contains("<u"),
    })
    { runs, }
  })
}

///|
fn render_docx_paragraph(paragraph : DocxParagraph) -> String {
  let runs = paragraph.runs
    .map(run => {
      let props = (if run.bold { "<w:b/>" } else { "" }) +
        (if run.italic { "<w:i/>" } else { "" }) +
        (if run.underline { "<w:u w:val=\"single\"/>" } else { "" })
      let run_props = if props == "" {
        ""
      } else {
        "<w:rPr>" + props + "</w:rPr>"
      }
      "<w:r>" +
      run_props +
      "<w:t xml:space=\"preserve\">" +
      office_escape_xml(run.text) +
      "</w:t></w:r>"
    })
    .join("")
  "<w:p>" + runs + "</w:p>"
}

///|
fn office_replace_ranges(
  xml : String,
  ranges : Array[(Int, Int, String, String)],
  replacements : Array[String],
) -> String {
  let builder = StringBuilder::new()
  let mut offset = 0
  for index, range in ranges {
    builder.write_string(xml.substring(start=offset, end=range.0))
    builder.write_string(replacements[index])
    offset = range.1
  }
  builder.write_string(xml.substring(start=offset))
  builder.to_string()
}

///|
fn render_docx_into(
  original : String,
  paragraphs : Array[DocxParagraph],
) -> Result[String, String] {
  let ranges = office_tag_ranges(original, "w:p")
  if ranges.length() != paragraphs.length() {
    return Err("Paragraph count changes are outside the supported DOCX subset")
  }
  Ok(
    office_replace_ranges(
      original,
      ranges,
      paragraphs.map(render_docx_paragraph),
    ),
  )
}

///|
fn parse_xlsx_sheet(part : String, xml : String) -> XlsxSheet {
  let cells = office_tag_ranges(xml, "c").map(range => {
    let cell = range.3
    {
      reference: office_attribute(range.2, "r").unwrap_or(""),
      value: office_first_tag_text(cell, "v").unwrap_or(""),
      formula: office_first_tag_text(cell, "f"),
    }
  })
  { part, name: part, cells }
}

///|
fn render_xlsx_cell_into(
  original : String,
  cell : XlsxCell,
) -> Result[String, String] {
  let with_formula = match cell.formula {
    Some(value) =>
      match office_tag_ranges(original, "f") {
        [(start, end, opening, _), ..] =>
          Ok(
            original.substring(start=0, end=start) +
            opening +
            office_escape_xml(value) +
            "</f>" +
            original.substring(start=end),
          )
        _ => Err("Adding a formula is outside the supported XLSX subset")
      }
    None => Ok(original)
  }
  let formula_xml = match with_formula {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match office_tag_ranges(formula_xml, "v") {
    [(start, end, opening, _), ..] =>
      Ok(
        formula_xml.substring(start=0, end=start) +
        opening +
        office_escape_xml(cell.value) +
        "</v>" +
        formula_xml.substring(start=end),
      )
    _ => Err("Supported XLSX value node is missing")
  }
}

///|
fn render_xlsx_into(
  original : String,
  sheet : XlsxSheet,
) -> Result[String, String] {
  let ranges = office_tag_ranges(original, "c")
  if ranges.length() != sheet.cells.length() {
    return Err("Adding cells is outside the supported XLSX subset")
  }
  let replacements : Array[String] = []
  for index, range in ranges {
    let current = original.substring(start=range.0, end=range.1)
    match render_xlsx_cell_into(current, sheet.cells[index]) {
      Ok(value) => replacements.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok(office_replace_ranges(original, ranges, replacements))
}

///|
fn parse_pptx_slide(part : String, xml : String) -> PptxSlide {
  let objects = office_tag_contents(xml, "p:sp").map(shape => {
    let offset = office_opening_tags(shape, "a:off")
    let extent = office_opening_tags(shape, "a:ext")
    {
      text: office_tag_contents(shape, "a:t").map(office_unescape_xml).join(""),
      x: match offset {
        [value, ..] => office_int_attribute(value, "x")
        _ => None
      },
      y: match offset {
        [value, ..] => office_int_attribute(value, "y")
        _ => None
      },
      width: match extent {
        [value, ..] => office_int_attribute(value, "cx")
        _ => None
      },
      height: match extent {
        [value, ..] => office_int_attribute(value, "cy")
        _ => None
      },
    }
  })
  { part, objects }
}

///|
fn office_replace_first_tag_text(
  xml : String,
  local : String,
  text : String,
) -> Result[String, String] {
  match office_tag_ranges(xml, local) {
    [(start, end, _, _), ..] =>
      Ok(
        xml.substring(start=0, end=start) +
        "<" +
        local +
        ">" +
        office_escape_xml(text) +
        "</" +
        local +
        ">" +
        xml.substring(start=end),
      )
    _ => Err("Supported text node is missing")
  }
}

///|
fn office_replace_self_closing_tag(
  xml : String,
  local : String,
  replacement : String,
) -> Result[String, String] {
  let needle = "<" + local
  let start = match xml.find(needle) {
    Some(index) => index
    None => return Err("Supported object property is missing")
  }
  let tail = xml.substring(start~)
  let end = match tail.find(">") {
    Some(index) => start + index + 1
    None => return Err("Supported object property is malformed")
  }
  Ok(xml.substring(start=0, end=start) + replacement + xml.substring(start=end))
}

///|
fn render_pptx_object_into(
  original : String,
  object : PptxTextObject,
) -> Result[String, String] {
  if office_tag_ranges(original, "a:t").length() != 1 {
    return Err("PPTX objects with zero or multiple text runs are unsupported")
  }
  let text = match office_replace_first_tag_text(original, "a:t", object.text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let offset = "<a:off x=\"" +
    object.x.unwrap_or(0).to_string() +
    "\" y=\"" +
    object.y.unwrap_or(0).to_string() +
    "\"/>"
  let with_offset = match
    office_replace_self_closing_tag(text, "a:off", offset) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let extent = "<a:ext cx=\"" +
    object.width.unwrap_or(1000000).to_string() +
    "\" cy=\"" +
    object.height.unwrap_or(500000).to_string() +
    "\"/>"
  office_replace_self_closing_tag(with_offset, "a:ext", extent)
}

///|
fn render_pptx_into(
  original : String,
  slide : PptxSlide,
) -> Result[String, String] {
  let ranges = office_tag_ranges(original, "p:sp")
  if ranges.length() != slide.objects.length() {
    return Err("Adding slide objects is outside the supported PPTX subset")
  }
  let replacements : Array[String] = []
  for index, range in ranges {
    let full = original.substring(start=range.0, end=range.1)
    match render_pptx_object_into(full, slide.objects[index]) {
      Ok(value) => replacements.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok(office_replace_ranges(original, ranges, replacements))
}

///|
fn office_entry_text(
  entries : Array[(String, FixedArray[Byte])],
  part : String,
) -> Result[String, String] {
  for entry in entries {
    let (name, bytes) = entry
    if name == part {
      return Ok(
        @moonzip.str_from_u8(bytes) catch {
          _ => return Err("Office XML part is not valid UTF-8")
        },
      )
    }
  }
  Err("Office package part not found")
}

///|
fn office_relationship_targets(xml : String) -> Map[String, String] {
  let targets : Map[String, String] = {}
  for tag in office_opening_tags(xml, "Relationship") {
    match (office_attribute(tag, "Id"), office_attribute(tag, "Target")) {
      (Some(id), Some(target)) => targets[id] = target
      _ => ()
    }
  }
  targets
}

///|
fn office_join_part(base : String, target : String) -> String {
  let clean = target.trim(chars=['/']).to_owned()
  if clean.has_prefix(base + "/") {
    clean
  } else {
    base + "/" + clean
  }
}

///|
fn ordered_xlsx_sheets(
  entries : Array[(String, FixedArray[Byte])],
) -> Result[Array[XlsxSheet], String] {
  let workbook = match office_entry_text(entries, "xl/workbook.xml") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let relationships = match
    office_entry_text(entries, "xl/_rels/workbook.xml.rels") {
    Ok(value) => office_relationship_targets(value)
    Err(error) => return Err(error)
  }
  let sheets : Array[XlsxSheet] = []
  for tag in office_opening_tags(workbook, "sheet") {
    let name = office_attribute(tag, "name").unwrap_or("")
    let id = office_attribute(tag, "r:id").unwrap_or("")
    match relationships.get(id) {
      Some(target) => {
        let part = office_join_part("xl", target)
        match office_entry_text(entries, part) {
          Ok(xml) => sheets.push({ ..parse_xlsx_sheet(part, xml), name, })
          Err(error) => return Err(error)
        }
      }
      None => return Err("XLSX sheet relationship is missing")
    }
  }
  if sheets.length() == 0 {
    Err("XLSX workbook has no supported sheets")
  } else {
    Ok(sheets)
  }
}

///|
fn ordered_pptx_slides(
  entries : Array[(String, FixedArray[Byte])],
) -> Result[Array[PptxSlide], String] {
  let presentation = match office_entry_text(entries, "ppt/presentation.xml") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let relationships = match
    office_entry_text(entries, "ppt/_rels/presentation.xml.rels") {
    Ok(value) => office_relationship_targets(value)
    Err(error) => return Err(error)
  }
  let slides : Array[PptxSlide] = []
  for tag in office_opening_tags(presentation, "p:sldId") {
    let id = office_attribute(tag, "r:id").unwrap_or("")
    match relationships.get(id) {
      Some(target) => {
        let part = office_join_part("ppt", target)
        match office_entry_text(entries, part) {
          Ok(xml) => slides.push(parse_pptx_slide(part, xml))
          Err(error) => return Err(error)
        }
      }
      None => return Err("PPTX slide relationship is missing")
    }
  }
  if slides.length() == 0 {
    Err("PPTX presentation has no supported slides")
  } else {
    Ok(slides)
  }
}

///|
fn office_supported_model(
  kind : OfficeDocumentKind,
  entries : Array[(String, FixedArray[Byte])],
  editable_parts : Array[String],
) -> Result[OfficeSupportedModel, String] {
  match kind {
    Docx =>
      match office_entry_text(entries, "word/document.xml") {
        Ok(xml) => Ok(Word(parse_docx(xml)))
        Err(error) => Err(error)
      }
    Xlsx => ordered_xlsx_sheets(entries).map(sheets => Spreadsheet(sheets))
    Pptx => ordered_pptx_slides(entries).map(slides => Presentation(slides))
  }
}

///|
fn office_document_open_bytes(
  path : String,
  bytes : FixedArray[Byte],
) -> Result[OfficeDocumentModel, String] {
  let kind = match office_document_kind(path) {
    Some(kind) => kind
    None => return Err("Unsupported Office document type")
  }
  let entries = @moonzip.unzip_sync(bytes) catch {
    _ => return Err("Invalid or unsupported Office ZIP package")
  }
  let names = entries.map(entry => entry.0)
  for required in office_required_parts(kind) {
    if !names.contains(required) {
      return Err("Invalid Office package: missing " + required)
    }
  }
  let editable_parts = names.filter(name => office_editable_part(kind, name))
  if editable_parts.length() == 0 {
    return Err("Office package has no supported editable content")
  }
  let supported = match office_supported_model(kind, entries, editable_parts) {
    Ok(model) => model
    Err(error) => return Err(error)
  }
  Ok({
    kind,
    entries,
    editable_parts,
    supported,
    warnings: [
      "Supported subset only. MoonDesk edits DOCX paragraphs and bold/italic/underline runs, XLSX cells and formulas, and PPTX text objects with position and size. Unsupported features and unedited package members are preserved.",
    ],
  })
}

///|
fn office_document_part_text(
  document : OfficeDocumentModel,
  part : String,
) -> Result[String, String] {
  office_entry_text(document.entries, part)
}

///|
fn office_document_replace_part(
  document : OfficeDocumentModel,
  part : String,
  content : String,
  supported : OfficeSupportedModel,
) -> Result[OfficeDocumentModel, String] {
  let mut found = false
  let entries = document.entries.map(entry => {
    let (name, bytes) = entry
    if name == part {
      found = true
      (name, @moonzip.str_to_u8(content))
    } else {
      (name, bytes)
    }
  })
  if found {
    Ok({ ..document, entries, supported })
  } else {
    Err("Office package part not found")
  }
}

///|
fn office_document_set_docx_paragraphs(
  document : OfficeDocumentModel,
  paragraphs : Array[DocxParagraph],
) -> Result[OfficeDocumentModel, String] {
  guard document.kind is Docx else { return Err("Not a DOCX document") }
  let original = match
    office_document_part_text(document, "word/document.xml") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let rendered = match render_docx_into(original, paragraphs) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  office_document_replace_part(
    document,
    "word/document.xml",
    rendered,
    Word(paragraphs),
  )
}

///|
fn office_document_set_docx_run(
  document : OfficeDocumentModel,
  paragraph_index : Int,
  run_index : Int,
  replacement : DocxRun,
) -> Result[OfficeDocumentModel, String] {
  guard document.supported is Word(paragraphs) else {
    return Err("Not a DOCX document")
  }
  if paragraph_index < 0 ||
    paragraph_index >= paragraphs.length() ||
    run_index < 0 ||
    run_index >= paragraphs[paragraph_index].runs.length() {
    return Err("DOCX run is outside the supported model")
  }
  let original = match
    office_document_part_text(document, "word/document.xml") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let paragraph_ranges = office_tag_ranges(original, "w:p")
  if paragraph_index >= paragraph_ranges.length() {
    return Err("DOCX paragraph XML is missing")
  }
  let paragraph_range = paragraph_ranges[paragraph_index]
  let paragraph_xml = original.substring(
    start=paragraph_range.0,
    end=paragraph_range.1,
  )
  let run_ranges = office_tag_ranges(paragraph_xml, "w:r")
  if run_index >= run_ranges.length() {
    return Err("DOCX run XML is missing")
  }
  let run_range = run_ranges[run_index]
  let run_xml = paragraph_xml.substring(start=run_range.0, end=run_range.1)
  if office_tag_ranges(run_xml, "w:t").length() != 1 {
    return Err("DOCX runs with zero or multiple text nodes are unsupported")
  }
  let with_text = match
    office_replace_first_tag_text(run_xml, "w:t", replacement.text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let properties = (if replacement.bold { "<w:b/>" } else { "" }) +
    (if replacement.italic { "<w:i/>" } else { "" }) +
    (if replacement.underline { "<w:u w:val=\"single\"/>" } else { "" })
  let with_properties = match office_tag_ranges(with_text, "w:rPr") {
    [(start, end, opening, body), ..] => {
      let unsupported = body
        .replace_all(old="<w:b/>", new="")
        .replace_all(old="<w:i/>", new="")
        .replace_all(old="<w:u w:val=\"single\"/>", new="")
      with_text.substring(start=0, end=start) +
      opening +
      unsupported +
      properties +
      "</w:rPr>" +
      with_text.substring(start=end)
    }
    _ =>
      with_text.replace(
        old="<w:r>",
        new="<w:r><w:rPr>" + properties + "</w:rPr>",
      )
  }
  let edited_paragraph = paragraph_xml.substring(start=0, end=run_range.0) +
    with_properties +
    paragraph_xml.substring(start=run_range.1)
  let edited_xml = original.substring(start=0, end=paragraph_range.0) +
    edited_paragraph +
    original.substring(start=paragraph_range.1)
  let next = paragraphs.mapi((p, paragraph) => {
    if p == paragraph_index {
      {
        runs: paragraph.runs.mapi((r, run) => {
          if r == run_index {
            replacement
          } else {
            run
          }
        }),
      }
    } else {
      paragraph
    }
  })
  office_document_replace_part(
    document,
    "word/document.xml",
    edited_xml,
    Word(next),
  )
}

///|
fn office_document_set_xlsx_cell(
  document : OfficeDocumentModel,
  sheet_part : String,
  reference : String,
  value : String,
  formula : String?,
) -> Result[OfficeDocumentModel, String] {
  guard document.supported is Spreadsheet(sheets) else {
    return Err("Not an XLSX document")
  }
  let mut found_sheet = false
  let mut found_cell = false
  let next = sheets.map(sheet => {
    if sheet.part == sheet_part {
      found_sheet = true
      let cells = sheet.cells.map(cell => {
        if cell.reference == reference {
          found_cell = true
          { reference, value, formula }
        } else {
          cell
        }
      })
      { ..sheet, cells, }
    } else {
      sheet
    }
  })
  if !found_sheet {
    return Err("Worksheet is outside the supported document model")
  }
  if !found_cell {
    return Err("Adding cells is outside the supported XLSX subset")
  }
  let index = next.search_by(sheet => sheet.part == sheet_part)
  guard index is Some(selected_index) else {
    return Err("Worksheet is outside the supported document model")
  }
  let original = match office_document_part_text(document, sheet_part) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let rendered = match render_xlsx_into(original, next[selected_index]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  office_document_replace_part(
    document,
    sheet_part,
    rendered,
    Spreadsheet(next),
  )
}

///|
fn office_document_set_pptx_object(
  document : OfficeDocumentModel,
  slide_part : String,
  index : Int,
  object : PptxTextObject,
) -> Result[OfficeDocumentModel, String] {
  guard document.supported is Presentation(slides) else {
    return Err("Not a PPTX document")
  }
  let mut found_slide = false
  let mut found_object = false
  let next = slides.map(slide => {
    if slide.part == slide_part {
      found_slide = true
      let objects = slide.objects.mapi((i, current) => {
        if i == index {
          found_object = true
          object
        } else {
          current
        }
      })
      { ..slide, objects, }
    } else {
      slide
    }
  })
  if !found_slide || !found_object {
    return Err("Slide object is outside the supported document model")
  }
  let selected_index = match next.search_by(slide => slide.part == slide_part) {
    Some(value) => value
    None => return Err("Slide is outside the supported document model")
  }
  let original = match office_document_part_text(document, slide_part) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let rendered = match render_pptx_into(original, next[selected_index]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  office_document_replace_part(
    document,
    slide_part,
    rendered,
    Presentation(next),
  )
}

///|
fn office_document_save_bytes(
  document : OfficeDocumentModel,
) -> FixedArray[Byte] {
  @moonzip.zip_sync(document.entries)
}
