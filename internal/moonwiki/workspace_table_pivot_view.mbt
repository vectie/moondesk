///|
fn pivot_select(
  columns : Array[String],
  field : String,
  label : String,
  selected : String,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<label>" +
    label +
    "<select name=\"" +
    field +
    "\"><option value=\"\">Choose a column</option>",
  )
  for name in columns {
    let checked = if name == selected { " selected" } else { "" }
    let escaped = office_escape_xml(name)
    out.write_string(
      "<option value=\"\{escaped}\"\{checked}>\{escaped}</option>",
    )
  }
  if selected != "" && !columns.contains(selected) {
    out.write_string(
      "<option selected value=\"\{office_escape_xml(selected)}\">Missing: \{office_escape_xml(selected)}</option>",
    )
  }
  out.write_string("</select></label>")
  out.to_string()
}

///|
fn pivot_html(
  workspace_id : String,
  source : WorkspaceTableSource,
  row_name : String,
  column_name : String,
  aggregation : String,
  value_name : String,
  result : PivotReport?,
  error : String?,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Pivot report · MoonDesk</title><style>body{font:15px system-ui;margin:32px}label{display:block;margin:12px 0}select{margin-left:12px}table{border-collapse:collapse}th,td{border:1px solid #ccc;padding:8px;white-space:pre-wrap}nav{display:flex;gap:18px;margin:20px 0}.table-scroll{overflow:auto}</style><h1>Pivot report</h1>",
  )
  out.write_string(
    "<p>Source: <strong>\{office_escape_xml(comparison_source_label(source))}</strong></p><p>Compare categories side by side, for example region by month. Count every record or sum a numeric column. Every saved record is used; explorer filters do not apply. Your source stays unchanged.</p><form method=\"get\">",
  )
  out.write_string(
    comparison_hidden("path", source.path) + comparison_hidden("pivot", "1"),
  )
  out.write_string(comparison_sheet_select(source, "sheet", "Worksheet"))
  out.write_string(
    pivot_select(source.table.columns, "pivot_row", "Row groups", row_name),
  )
  out.write_string(
    pivot_select(
      source.table.columns,
      "pivot_column",
      "Column categories",
      column_name,
    ),
  )
  out.write_string("<label>Aggregation<select name=\"aggregate\">")
  for
    (value, label) in [
      ("count", "Count records"),
      ("sum", "Sum numeric values"),
    ] {
    let checked = if aggregation == value { " selected" } else { "" }
    out.write_string("<option value=\"\{value}\"\{checked}>\{label}</option>")
  }
  out.write_string("</select></label>")
  out.write_string(
    pivot_select(
      source.table.columns,
      "pivot_value",
      "Numeric values (sum only)",
      value_name,
    ),
  )
  out.write_string(
    "<button type=\"submit\">Create pivot report</button></form>",
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
  if result is Some(report) {
    let mode = if aggregation == "sum" {
      "Sum: " + value_name
    } else {
      "Record count"
    }
    out.write_string(
      "<h2>\{office_escape_xml(mode)} by \{office_escape_xml(row_name)} and \{office_escape_xml(column_name)}</h2><p>\{report.source_rows} source records; \{report.table.rows.length() - 1} row groups.</p>",
    )
    if aggregation == "sum" {
      out.write_string(
        "<p>\{report.numeric_rows} numeric values included; \{report.source_rows - report.numeric_rows} blank or non-numeric values ignored. Blank totals mean no numeric values, not zero. Overflow is marked explicitly.</p>",
      )
    }
    let selection = "&pivot_row=" +
      encode_query_value(row_name) +
      "&pivot_column=" +
      encode_query_value(column_name) +
      "&aggregate=" +
      aggregation +
      "&pivot_value=" +
      encode_query_value(value_name)
    out.write_string("<nav>")
    for format in ["csv", "xlsx"] {
      let url = @desk.workspace_json_table_url(
          workspace_id,
          source.path,
          format~,
        ) +
        "&pivot=1" +
        sheet +
        selection
      out.write_string(
        "<a download href=\"\{office_escape_xml(url)}\">Export pivot \{format.to_upper()}</a>",
      )
    }
    out.write_string("</nav><div class=\"table-scroll\"><table><thead><tr>")
    for name in report.table.columns {
      let label = if name.has_prefix("Category: ") {
        "Category: " + Json::string(name[10:].to_owned()).stringify()
      } else {
        name
      }
      out.write_string("<th scope=\"col\">\{office_escape_xml(label)}</th>")
    }
    out.write_string("</tr></thead><tbody>")
    for row in report.table.text_rows() {
      out.write_string("<tr>")
      for value in row {
        out.write_string("<td>\{office_escape_xml(value)}</td>")
      }
      out.write_string("</tr>")
    }
    out.write_string("</tbody></table></div>")
  }
  out.write_string(
    "<p>Groups and categories use exact displayed text, in first-seen order. Row type distinguishes group rows from the grand total. Empty category headers end after the colon in downloads. Count fills missing combinations with zero; sum leaves them blank. Sum accepts finite plain numbers (including exponents), without currency or thousands separators. XLSX keeps keys as literal text and counts/totals as numbers. CSV apps may reinterpret text. Files are read afresh for every preview or download; cached workbook formulas are not recalculated.</p></html>",
  )
  out.to_string()
}
