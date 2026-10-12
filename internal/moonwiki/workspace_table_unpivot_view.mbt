///|
fn unpivot_html(
  workspace_id : String,
  source : WorkspaceTableSource,
  measures : Array[String],
  result : @jsontable.Table?,
  error : String?,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Reshape columns into rows · MoonDesk</title><style>body{font:15px system-ui;margin:32px}label{display:block;margin:8px}table{border-collapse:collapse}th,td{border:1px solid #ccc;padding:8px;white-space:pre-wrap}nav{display:flex;gap:18px;margin:20px 0}.table-scroll{overflow:auto}</style><h1>Reshape columns into rows</h1>",
  )
  out.write_string(
    "<p>Source: <strong>\{office_escape_xml(comparison_source_label(source))}</strong></p><p>Turn selected measurement columns (for example monthly totals) into Measurement and Value rows. All other columns remain identifiers. Every saved row and blank value is kept. Explorer filters do not apply. Your source stays unchanged.</p><form method=\"get\">",
  )
  out.write_string(
    comparison_hidden("path", source.path) + comparison_hidden("unpivot", "1"),
  )
  out.write_string(comparison_sheet_select(source, "sheet", "Worksheet"))
  out.write_string("<fieldset><legend>Choose measurement columns</legend>")
  for name in source.table.columns {
    let checked = if measures.contains(name) { " checked" } else { "" }
    let escaped = office_escape_xml(name)
    out.write_string(
      "<label><input type=\"checkbox\" name=\"measure\" value=\"\{escaped}\"\{checked}>\{escaped}</label>",
    )
  }
  out.write_string(
    "</fieldset><button type=\"submit\">Reshape table</button></form>",
  )
  if error is Some(message) {
    out.write_string("<p role=\"alert\">\{office_escape_xml(message)}</p>")
  }
  let sheet = source.selected_sheet
    .map(name => "&sheet=" + encode_query_value(name))
    .unwrap_or("")
  out.write_string(
    "<nav><a href=\"" +
    office_escape_xml(
      @desk.workspace_json_table_url(workspace_id, source.path) + sheet,
    ) +
    "\">Back to source table</a></nav>",
  )
  if result is Some(table) {
    out.write_string(
      "<h2>\{table.rows.length()} reshaped records from \{source.table.rows.length()} source records</h2><nav>",
    )
    let selection = measures
      .map(name => "&measure=" + encode_query_value(name))
      .join("")
    for format in ["csv", "xlsx"] {
      let url = @desk.workspace_json_table_url(
          workspace_id,
          source.path,
          format~,
        ) +
        "&unpivot=1" +
        sheet +
        selection
      out.write_string(
        "<a download href=\"\{office_escape_xml(url)}\">Export reshaped \{format.to_upper()}</a>",
      )
    }
    out.write_string("</nav><div class=\"table-scroll\"><table><thead><tr>")
    for name in table.columns {
      out.write_string("<th scope=\"col\">\{office_escape_xml(name)}</th>")
    }
    out.write_string("</tr></thead><tbody>")
    for row in table.text_rows() {
      out.write_string("<tr>")
      for value in row {
        out.write_string("<td>\{office_escape_xml(value)}</td>")
      }
      out.write_string("</tr>")
    }
    out.write_string(
      "</tbody></table></div><p>Rows follow source-record order, then source-column order. XLSX retains displayed values as literal text; only Source record is numeric. CSV applications may reinterpret text. Files are read afresh for each preview or export.</p>",
    )
  }
  out.write_string("</html>")
  out.to_string()
}
