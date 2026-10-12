///|
fn table_append_html(
  workspace_id : String,
  first : WorkspaceTableSource,
  second : WorkspaceTableSource?,
  request : String,
  result : TableAppend?,
  error : String?,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Combine saved tables · MoonDesk</title><style>body{font:15px system-ui;margin:32px;color:#182326;background:#f7f9f8}a{color:#08796b}fieldset{margin:16px 0;padding:14px}label{display:inline-block;margin:6px}input,select,button{font:inherit;padding:6px;max-width:26rem}table{border-collapse:collapse;background:white}th,td{border:1px solid #ccd8d1;padding:8px;white-space:pre-wrap;text-align:left;vertical-align:top}.table-scroll{overflow:auto}nav{display:flex;gap:16px;margin:20px 0}[role=alert]{color:#922}</style><h1>Combine saved tables</h1>",
  )
  out.write_string(
    "<p>First: <strong>\{office_escape_xml(comparison_source_label(first))}</strong></p>",
  )
  if second is Some(source) {
    out.write_string(
      "<p>Second: <strong>\{office_escape_xml(comparison_source_label(source))}</strong></p>",
    )
  }
  out.write_string(
    "<p>Stack every saved record from the first table, then the second. Columns align by exact header text, even when reordered; columns missing from either table are blank. All repeated records are kept. Explorer filters do not apply. Both files stay unchanged.</p>",
  )
  let common = comparison_hidden("append", "1") +
    comparison_hidden("path", first.path)
  let first_sheet = first.selected_sheet
    .map(name => comparison_hidden("sheet", name))
    .unwrap_or("")
  let second_path = office_escape_xml(table_query(request, "append_path"))
  out.write_string(
    "<form method=\"get\">\{common}\{first_sheet}<fieldset><legend>Choose the second table</legend><label>Workspace-relative path <input name=\"append_path\" value=\"\{second_path}\" placeholder=\"reports/next-month.csv\" required></label><button type=\"submit\">Combine tables</button><p>Opening a different file resets its worksheet selection.</p></fieldset></form>",
  )
  if second is Some(source) {
    let paths = common + comparison_hidden("append_path", source.path)
    if !first.sheet_names.is_empty() || !source.sheet_names.is_empty() {
      out.write_string(
        "<form method=\"get\">\{paths}<fieldset><legend>Choose worksheets</legend>",
      )
      out.write_string(
        comparison_sheet_select(first, "sheet", "First worksheet"),
      )
      out.write_string(
        comparison_sheet_select(source, "append_sheet", "Second worksheet"),
      )
      out.write_string(
        "<button type=\"submit\">Combine selected worksheets</button></fieldset></form>",
      )
    }
  }
  if error is Some(message) {
    out.write_string("<p role=\"alert\">\{office_escape_xml(message)}</p>")
  } else if second is None {
    out.write_string(
      "<p>Choose another saved CSV, TSV, JSON, JSONL, NDJSON or XLSX file in this workspace. You can also combine two named worksheets from the same workbook.</p>",
    )
  }
  if result is Some(report) {
    let second = second.unwrap()
    out.write_string(
      "<h2>\{report.table.rows.length()} combined records · \{first.table.rows.length()} first · \{second.table.rows.length()} second</h2>",
    )
    for
      (label, names) in [
        ("Shared columns", report.shared_columns),
        ("Only in first table", report.first_only),
        ("Only in second table", report.second_only),
      ] {
      out.write_string(
        "<p>\{label} (\{names.length()}): \{office_escape_xml(names.join(", "))}</p>",
      )
    }
    out.write_string("<nav>")
    for format in ["csv", "xlsx"] {
      let url = @desk.workspace_json_table_url(
          workspace_id,
          first.path,
          format~,
        ) +
        append_query(first, second)
      out.write_string(
        "<a download href=\"\{office_escape_xml(url)}\">Export combined \{format.to_upper()}</a>",
      )
    }
    out.write_string("</nav>")
    if report.table.rows.is_empty() {
      out.write_string(
        "<p>No saved records. Downloads contain headers only.</p>",
      )
    }
    out.write_string(
      "<div class=\"table-scroll\"><table><caption>Every saved record, with its source path, worksheet and one-based record number.</caption><thead><tr>",
    )
    for name in report.table.columns {
      out.write_string("<th scope=\"col\">\{office_escape_xml(name)}</th>")
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
  let back = @desk.workspace_json_table_url(workspace_id, first.path) +
    first.selected_sheet
    .map(name => "&sheet=" + encode_query_value(name))
    .unwrap_or("")
  out.write_string(
    "<p><a href=\"\{office_escape_xml(back)}\">Return to the first table</a></p><p>Headers match case and whitespace exactly. First-table fields appear first, followed by second-only fields; duplicate headers within a table require correction. Field: prefixes distinguish data columns from provenance. Record numbers exclude the header; JSONL blank lines are not records. XLSX values export as literal displayed text, except numeric source record numbers. Formula cached values are used without recalculation. CSV has no types: use XLSX to preserve text identifiers and formula-looking text. Files are reread for every preview and download, so saved edits appear on reload. Selecting the same path and worksheet twice intentionally repeats its rows. No edits are written back.</p></html>",
  )
  out.to_string()
}

///|
fn append_query(
  first : WorkspaceTableSource,
  second : WorkspaceTableSource,
) -> String {
  let out = StringBuilder()
  out.write_string("&append=1&append_path=" + encode_query_value(second.path))
  for
    (key, value) in [
      ("sheet", first.selected_sheet),
      ("append_sheet", second.selected_sheet),
    ] {
    if value is Some(name) {
      out.write_string("&\{key}=" + encode_query_value(name))
    }
  }
  out.to_string()
}
