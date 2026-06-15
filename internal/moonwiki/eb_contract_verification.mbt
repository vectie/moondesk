///|
fn push_failed_unless(
  failed : Array[String],
  condition : Bool,
  label : String,
) -> Unit {
  if !condition {
    failed.push(label)
  }
}

///|
fn eb_proof_check_item(
  id : String,
  label : String,
  ok : Bool,
  requirement : String,
  evidence : String,
) -> Json {
  {
    "id": id,
    "label": label,
    "ok": ok,
    "requirement": requirement,
    "evidence": evidence,
  }
}

///|
async fn file_contains(path : String, token : String) -> Bool {
  let text = @fs.read_file(path).text() catch { _ => return false }
  text.contains(token)
}

///|
async fn eb_xlsx_package_valid(path : String) -> Bool {
  let bytes = @fs.read_file(path).binary() catch { _ => return false }
  eb_xlsx_zip_magic_valid(bytes) &&
  eb_xlsx_package_missing_parts_from_bytes(bytes).is_empty()
}

///|
fn eb_xlsx_zip_magic_valid(bytes : Bytes) -> Bool {
  bytes.length() > 100 && bytes[0] == b'P' && bytes[1] == b'K'
}

///|
async fn eb_xlsx_package_missing_parts(path : String) -> Array[String] {
  let bytes = @fs.read_file(path).binary() catch {
    _ => return eb_xlsx_required_package_parts()
  }
  if !eb_xlsx_zip_magic_valid(bytes) {
    return eb_xlsx_required_package_parts()
  }
  eb_xlsx_package_missing_parts_from_bytes(bytes)
}

///|
async fn eb_xlsx_internal_contract_valid(path : String) -> Bool {
  if !eb_xlsx_package_valid(path) {
    return false
  }
  let workbook_xml = eb_xlsx_xml_part(path, "xl/workbook.xml")
  let sheet1_xml = eb_xlsx_xml_part(path, "xl/worksheets/sheet1.xml")
  let sheet2_xml = eb_xlsx_xml_part(path, "xl/worksheets/sheet2.xml")
  let shared_strings_xml = eb_xlsx_xml_part(path, "xl/sharedStrings.xml")
  if workbook_xml == "" || sheet1_xml == "" || sheet2_xml == "" {
    return false
  }
  let combined = workbook_xml +
    "\n" +
    sheet1_xml +
    "\n" +
    sheet2_xml +
    "\n" +
    shared_strings_xml
  workbook_xml.contains("公告追踪主表") &&
  workbook_xml.contains("关键指标监控表") &&
  eb_text_contains_all(combined, eb_announcement_sheet_headers()) &&
  eb_text_contains_all(combined, eb_indicator_sheet_headers()) &&
  eb_xlsx_formatting_contract_valid(
    sheet1_xml,
    sheet2_xml,
    eb_xlsx_xml_part(path, "xl/styles.xml"),
  )
}

///|
async fn eb_xlsx_data_rows_valid(path : String) -> Bool {
  if !eb_xlsx_package_valid(path) {
    return false
  }
  eb_xlsx_sheet_data_row_count(
    eb_xlsx_xml_part(path, "xl/worksheets/sheet1.xml"),
  ) >
  0 &&
  eb_xlsx_sheet_data_row_count(
    eb_xlsx_xml_part(path, "xl/worksheets/sheet2.xml"),
  ) >
  0
}

///|
fn eb_xlsx_sheet_data_row_count(sheet_xml : String) -> Int {
  let rows = count_text_token(sheet_xml, "<row")
  if rows <= 1 {
    0
  } else {
    rows - 1
  }
}

///|
fn count_text_token(text : String, token : String) -> Int {
  let token_len = token.length()
  if token_len == 0 || text.length() < token_len {
    return 0
  }
  let mut count = 0
  let mut index = 0
  while index <= text.length() - token_len {
    if text[index:index + token_len] == token {
      count += 1
      index += token_len
    } else {
      index += 1
    }
  }
  count
}

///|
async fn eb_xlsx_indicator_core_metrics_valid(path : String) -> Bool {
  if !eb_xlsx_package_valid(path) {
    return false
  }
  eb_xlsx_indicator_core_metrics_valid_xml(
    eb_xlsx_xml_part(path, "xl/worksheets/sheet2.xml"),
  )
}

///|
fn eb_xlsx_indicator_core_metrics_valid_xml(sheet2_xml : String) -> Bool {
  let rows = sheet2_xml.split("<row").to_array()
  let mut data_row_count = 0
  let mut ready_row_count = 0
  for index = 1; index < rows.length(); index = index + 1 {
    let row = "<row" + rows[index].to_owned()
    if row.contains("债券代码") || !row.contains("<c ") {
      continue
    }
    data_row_count += 1
    if eb_xlsx_indicator_core_metric_count(row) >= 4 {
      ready_row_count += 1
    }
  }
  data_row_count > 0 && ready_row_count == data_row_count
}

///|
fn eb_xlsx_indicator_core_metric_count(row_xml : String) -> Int {
  let mut count = 0
  for
    column in [
      "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q",
      "R", "S", "T",
    ] {
    if eb_xlsx_indicator_metric_cell_valid(
        eb_xlsx_inline_cell_text(row_xml, column),
      ) {
      count += 1
    }
  }
  count
}

///|
fn eb_xlsx_inline_cell_text(row_xml : String, column : String) -> String {
  let cell_token = "<c r=\"" + column
  let cell_start = match row_xml.find(cell_token) {
    Some(index) => index
    None => return ""
  }
  let cell_tail = row_xml[cell_start:].to_owned()
  let value_token = "<t>"
  let value_start = match cell_tail.find(value_token) {
    Some(index) => index + value_token.length()
    None => return ""
  }
  let value_tail = cell_tail[value_start:].to_owned()
  let value_end = match value_tail.find("</t>") {
    Some(index) => index
    None => return ""
  }
  eb_xml_unescape_basic(value_tail[:value_end].to_owned())
}

///|
fn eb_xml_unescape_basic(text : String) -> String {
  text
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&amp;", new="&")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&apos;", new="'")
}

///|
fn eb_xlsx_indicator_metric_cell_valid(value : String) -> Bool {
  let clean = value.trim().to_owned()
  clean != "" &&
  clean != "未检索到" &&
  !clean.has_prefix("未检索到（") &&
  !clean.has_prefix("待AI") &&
  !clean.has_suffix("待核验")
}

///|
async fn eb_xlsx_official_hyperlinks_valid(path : String) -> Bool {
  if !eb_xlsx_package_valid(path) {
    return false
  }
  eb_xlsx_sheet1_official_hyperlinks_valid(
    eb_xlsx_xml_part(path, "xl/worksheets/sheet1.xml"),
    eb_xlsx_xml_part(path, "xl/worksheets/_rels/sheet1.xml.rels"),
  )
}

///|
fn eb_xlsx_sheet1_official_hyperlinks_valid(
  sheet1_xml : String,
  rels_xml : String,
) -> Bool {
  if !sheet1_xml.contains("<hyperlink") ||
    !sheet1_xml.contains("ref=\"J") ||
    !sheet1_xml.contains("r:id=\"") ||
    !rels_xml.contains("TargetMode=\"External\"") {
    return false
  }
  let targets = xml_attribute_values(rels_xml, "Target")
  let mut official_count = 0
  for target in targets {
    if eb_is_http_url(target) {
      if !eb_url_allowed_official_domain(target) {
        return false
      }
      official_count += 1
    }
  }
  official_count > 0
}

///|
fn xml_attribute_values(text : String, attribute : String) -> Array[String] {
  let values : Array[String] = []
  let token = attribute + "=\""
  let token_len = token.length()
  if token_len == 0 || text.length() < token_len {
    return values
  }
  let mut index = 0
  while index <= text.length() - token_len {
    if text[index:index + token_len] == token {
      let start = index + token_len
      let mut end = start
      while end < text.length() && text[end:end + 1] != "\"" {
        end += 1
      }
      if end > start {
        values.push(text[start:end].to_owned())
      }
      index = end + 1
    } else {
      index += 1
    }
  }
  values
}

///|
fn eb_xlsx_formatting_contract_valid(
  sheet1_xml : String,
  sheet2_xml : String,
  styles_xml : String,
) -> Bool {
  eb_xlsx_sheet_formatting_contract_valid(sheet1_xml, "A1:N1") &&
  eb_xlsx_sheet_formatting_contract_valid(sheet2_xml, "A1:U1") &&
  styles_xml.contains("<b/>") &&
  styles_xml.contains("applyFont=\"1\"")
}

///|
fn eb_xlsx_sheet_formatting_contract_valid(
  sheet_xml : String,
  auto_filter_ref : String,
) -> Bool {
  let prefix = if auto_filter_ref.has_suffix("1") {
    auto_filter_ref[:auto_filter_ref.length() - 1].to_owned()
  } else {
    auto_filter_ref
  }
  sheet_xml.contains("<cols>") &&
  sheet_xml.contains("customWidth=\"1\"") &&
  sheet_xml.contains("state=\"frozen\"") &&
  (
    sheet_xml.contains("<autoFilter ref=\"\{auto_filter_ref}\"") ||
    sheet_xml.contains("<autoFilter ref=\"\{prefix}")
  ) &&
  sheet_xml.contains(" s=\"1\"")
}

///|
async fn eb_xlsx_xml_part(path : String, part : String) -> String {
  let output = @process.collect_output("unzip", ["-p", path, part]) catch {
    _ => return ""
  }
  match output {
    (0, stdout, _) => stdout.text() catch { _ => "" }
    _ => ""
  }
}

///|
fn eb_text_contains_all(text : String, values : Array[String]) -> Bool {
  for value in values {
    if !text.contains(value) {
      return false
    }
  }
  true
}

///|
fn eb_xlsx_package_missing_parts_from_bytes(bytes : Bytes) -> Array[String] {
  let missing : Array[String] = []
  for part in eb_xlsx_required_package_parts() {
    if !bytes_contains_ascii(bytes, part) {
      missing.push(part)
    }
  }
  missing
}

///|
fn eb_xlsx_required_package_parts() -> Array[String] {
  [
    "[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels",
    "xl/styles.xml", "xl/worksheets/sheet1.xml", "xl/worksheets/sheet2.xml",
  ]
}

///|
fn bytes_contains_ascii(bytes : Bytes, token : String) -> Bool {
  let needle = ascii_token_bytes(token)
  if needle.is_empty() || bytes.length() < needle.length() {
    return false
  }
  let mut index = 0
  while index <= bytes.length() - needle.length() {
    let mut matched = true
    let mut offset = 0
    while offset < needle.length() {
      if bytes[index + offset] != needle[offset] {
        matched = false
        break
      }
      offset += 1
    }
    if matched {
      return true
    }
    index += 1
  }
  false
}

///|
fn ascii_token_bytes(token : String) -> Array[Byte] {
  let bytes : Array[Byte] = []
  for ch in token {
    let code = ch.to_int()
    if code > 0x7F {
      return []
    }
    bytes.push(code.to_byte())
  }
  bytes
}

///|
fn eb_tracking_template_xlsx_bytes() -> Bytes {
  base64_decode_bytes(eb_tracking_template_xlsx_base64())
}

///|
fn eb_tracking_template_xlsx_base64() -> String {
  [
    "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",
    "AQAAPQwAAAAA",
  ].join("")
}
