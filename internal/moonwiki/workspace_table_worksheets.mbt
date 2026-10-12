///|
// A separate GET form resets column-based transforms when changing sheets.
fn table_worksheet_controls(
  file : String,
  names : Array[String],
  path : String,
) -> String {
  if names.is_empty() {
    return ""
  }
  let selected = table_query(path, "sheet")
  let out = StringBuilder()
  out.write_string(
    "<section aria-label=\"Workbook worksheets\"><p>Worksheet: <strong>\{office_escape_xml(selected)}</strong> · \{names.length()} worksheets</p><form method=\"get\"><input type=\"hidden\" name=\"path\" value=\"\{office_escape_xml(file)}\"><label>Worksheet <select name=\"sheet\">",
  )
  for name in names {
    let selection = if name == selected { " selected" } else { "" }
    let escaped = office_escape_xml(name)
    out.write_string(
      "<option value=\"\{escaped}\"\{selection}>\{escaped}</option>",
    )
  }
  out.write_string(
    "</select></label> <button type=\"submit\">Open worksheet</button></form><p>Opening a worksheet resets filters, sorting and grouping. Apply exploration, exports and Reset all keep the current worksheet. Sheet names are saved in the URL for reload and Back.</p></section>",
  )
  out.to_string()
}
