///|
// One save, one confined compare-and-write. Only changed w:t nodes are patched;
// paragraph/run properties, links, equations and other package parts stay put.
fn office_document_set_docx_texts(
  document : OfficeDocumentModel,
  edits : Array[Json],
) -> Result[OfficeDocumentModel, String] {
  guard document.supported is Word(paragraphs) else {
    return Err("Not a DOCX document")
  }
  let replacements : Map[String, String] = Map([])
  for edit in edits {
    guard edit
      is {
        "paragraph": Number(p, ..),
        "run": Number(r, ..),
        "text": String(text),
        ..
      } else {
      return Err("Invalid DOCX text edit")
    }
    let pi = p.to_int()
    let ri = r.to_int()
    if p != pi.to_double() ||
      r != ri.to_double() ||
      pi < 0 ||
      pi >= paragraphs.length() ||
      ri < 0 ||
      ri >= paragraphs[pi].runs.length() {
      return Err("DOCX text is outside the document")
    }
    let key = "\{pi}:\{ri}"
    if replacements.contains(key) {
      return Err("Duplicate DOCX text edit")
    }
    replacements[key] = text
  }
  let original = match
    office_document_part_text(document, "word/document.xml") {
    Ok(xml) => xml
    Err(error) => return Err(error)
  }
  let paragraph_ranges = office_tag_ranges(original, "w:p")
  let rendered : Array[String] = []
  for pi, range in paragraph_ranges {
    let paragraph_xml = original[range.0:range.1].to_owned()
    let run_ranges = office_tag_ranges(paragraph_xml, "w:r")
    let run_xmls : Array[String] = []
    for ri, run_range in run_ranges {
      let run_xml = paragraph_xml[run_range.0:run_range.1].to_owned()
      match replacements.get("\{pi}:\{ri}") {
        None => run_xmls.push(run_xml)
        Some(text) => {
          let text_ranges = office_tag_ranges(run_xml, "w:t")
          guard text_ranges is [first, ..] else {
            return Err(
              "This text contains unsupported Word fields. Edit it in Word instead; your draft is preserved.",
            )
          }
          let start = first.0
          let end = text_ranges[text_ranges.length() - 1].1
          let mut between = run_xml[start:end].to_owned()
          for range in text_ranges {
            between = between.replace(
              old=run_xml[range.0:range.1].to_owned(),
              new="",
            )
          }
          if between
            .replace_all(old="<w:br/>", new="")
            .replace_all(old="<w:br />", new="")
            .trim() !=
            "" ||
            run_xml[:start].contains("<w:br") ||
            run_xml[end:].contains("<w:br") {
            return Err(
              "This text contains unsupported Word fields. Edit it in Word instead; your draft is preserved.",
            )
          }
          let opening = if first.2.contains("xml:space=") {
            first.2.replace_all(
              old="xml:space=\"default\"",
              new="xml:space=\"preserve\"",
            )
          } else {
            first.2[:first.2.length() - 1].to_owned() +
            " xml:space=\"preserve\">"
          }
          let lines = text
            .replace_all(old="\r\n", new="\n")
            .split("\n")
            .map(line => opening + office_escape_xml(line.to_owned()) + "</w:t>")
            .collect()
            .join("<w:br/>")
          run_xmls.push(
            run_xml[:start].to_owned() + lines + run_xml[end:].to_owned(),
          )
        }
      }
    }
    rendered.push(office_replace_ranges(paragraph_xml, run_ranges, run_xmls))
  }
  let next = paragraphs.mapi((pi, paragraph) => {
    runs: paragraph.runs.mapi((ri, run) => {
      match replacements.get("\{pi}:\{ri}") {
        Some(text) => { ..run, text, }
        None => run
      }
    }),
  })
  office_document_replace_part(
    document,
    "word/document.xml",
    office_replace_ranges(original, paragraph_ranges, rendered),
    Word(next),
  )
}

///|
fn office_docx_run_text(xml : String) -> String {
  let output = StringBuilder()
  let mut offset = 0
  for range in office_tag_ranges(xml, "w:t") {
    for _ in office_opening_tags(xml[offset:range.0].to_owned(), "w:br") {
      output.write_string("\n")
    }
    output.write_string(office_unescape_xml(range.3))
    offset = range.1
  }
  for _ in office_opening_tags(xml[offset:].to_owned(), "w:br") {
    output.write_string("\n")
  }
  output.to_string()
}
