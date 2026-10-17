///|
fn comparison_hidden(key : String, value : String) -> String {
  "<input type=\"hidden\" name=\"\{key}\" value=\"\{office_escape_xml(value)}\">"
}

///|
fn comparison_sheet_select(
  source : WorkspaceTableSource,
  key : String,
  label : String,
) -> String {
  if source.sheet_names.is_empty() {
    return ""
  }
  let out = StringBuilder()
  out.write_string("<label>\{label} <select name=\"\{key}\">")
  for name in source.sheet_names {
    let selected = if source.selected_sheet == Some(name) {
      " selected"
    } else {
      ""
    }
    let escaped = office_escape_xml(name)
    out.write_string(
      "<option value=\"\{escaped}\"\{selected}>\{escaped}</option>",
    )
  }
  out.write_string("</select></label>")
  out.to_string()
}

///|
fn comparison_key_select(
  source : WorkspaceTableSource,
  key : String,
  label : String,
  request : String,
  prompt~ : String = "Choose a unique key",
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<label>\{label} <select name=\"\{key}\"><option value=\"\">\{office_escape_xml(prompt)}</option>",
  )
  for name in source.table.columns {
    let selected = if table_query(request, key) == name {
      " selected"
    } else {
      ""
    }
    let escaped = office_escape_xml(name)
    out.write_string(
      "<option value=\"\{escaped}\"\{selected}>\{escaped}</option>",
    )
  }
  out.write_string("</select></label>")
  out.to_string()
}

///|
fn comparison_key_index(
  source : WorkspaceTableSource,
  request : String,
  key : String,
) -> Int32? {
  let name = table_query(request, key)
  if name == "" {
    return None
  }
  for i, column in source.table.columns {
    if column == name {
      return Some(i)
    }
  }
  None
}

///|
fn comparison_source_label(source : WorkspaceTableSource) -> String {
  source.path +
  source.selected_sheet.map(name => " [worksheet: " + name + "]").unwrap_or("")
}

///|
fn table_comparison_html(
  workspace_id : String,
  before : WorkspaceTableSource,
  after : WorkspaceTableSource?,
  request : String,
  result : TableComparison?,
  error : String?,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Compare saved tables · MoonDesk</title><style>body{font:15px system-ui;margin:32px;color:#182326;background:#f7f9f8}a{color:#08796b}fieldset{margin:16px 0;padding:14px}label{display:inline-block;margin:6px}input,select,button{font:inherit;padding:6px;max-width:26rem}table{border-collapse:collapse;background:white}th,td{border:1px solid #ccd8d1;padding:8px;white-space:pre-wrap;text-align:left;vertical-align:top}.table-scroll{overflow:auto}nav{display:flex;gap:16px;margin:20px 0}[role=alert]{color:#922}</style><h1>Compare saved tables</h1>",
  )
  out.write_string(
    "<p>Before: <strong>\{office_escape_xml(comparison_source_label(before))}</strong></p>",
  )
  if after is Some(source) {
    out.write_string(
      "<p>After: <strong>\{office_escape_xml(comparison_source_label(source))}</strong></p>",
    )
  }
  out.write_string(
    "<p>Compare every saved record by a unique key, regardless of row or column order. Existing explorer filters do not apply. Both files stay unchanged.</p>",
  )
  let common = comparison_hidden("comparison", "1") +
    comparison_hidden("path", before.path)
  let left_sheet = before.selected_sheet
    .map(name => comparison_hidden("sheet", name))
    .unwrap_or("")
  let after_path = office_escape_xml(table_query(request, "compare_path"))
  out.write_string(
    "<form method=\"get\">\{common}\{left_sheet}<fieldset><legend>Choose the after file</legend><label>Workspace-relative path <input name=\"compare_path\" value=\"\{after_path}\" placeholder=\"reports/new-sales.csv\" required></label><button type=\"submit\">Open comparison file</button></fieldset></form>",
  )
  if after is Some(source) {
    let paths = common + comparison_hidden("compare_path", source.path)
    if !before.sheet_names.is_empty() || !source.sheet_names.is_empty() {
      out.write_string(
        "<form method=\"get\">\{paths}<fieldset><legend>Choose worksheets</legend>",
      )
      out.write_string(
        comparison_sheet_select(before, "sheet", "Before worksheet"),
      )
      out.write_string(
        comparison_sheet_select(source, "compare_sheet", "After worksheet"),
      )
      out.write_string(
        "<button type=\"submit\">Open worksheets</button><p>Opening files or worksheets clears the key selection. Choose keys again for the new schema.</p></fieldset></form>",
      )
    }
    let right_sheet = source.selected_sheet
      .map(name => comparison_hidden("compare_sheet", name))
      .unwrap_or("")
    out.write_string(
      "<form method=\"get\">\{paths}\{left_sheet}\{right_sheet}<fieldset><legend>Match records</legend>",
    )
    out.write_string(
      comparison_key_select(before, "key", "Before key", request),
    )
    out.write_string(
      comparison_key_select(source, "compare_key", "After key", request),
    )
    out.write_string(
      "<button type=\"submit\">Compare tables</button></fieldset></form>",
    )
  }
  if error is Some(message) {
    out.write_string("<p role=\"alert\">\{office_escape_xml(message)}</p>")
  } else if after is None {
    out.write_string(
      "<p>Open another saved CSV, TSV, JSON, JSONL, NDJSON or XLSX file in this workspace.</p>",
    )
  } else if result is None {
    out.write_string(
      "<p>Choose the column that uniquely identifies each record in both tables, then compare.</p>",
    )
  }
  if result is Some(report) {
    out.write_string(
      "<h2>\{report.added} added · \{report.removed} removed · \{report.changed} changed · \{report.unchanged} unchanged records</h2>",
    )
    for
      (label, names) in [
        ("Added columns", report.added_columns),
        ("Removed columns", report.removed_columns),
      ] {
      if !names.is_empty() {
        out.write_string(
          "<p>\{label}: \{office_escape_xml(names.join(", "))}</p>",
        )
      }
    }
    out.write_string("<nav>")
    for format in ["csv", "xlsx"] {
      let url = @desk.workspace_json_table_url(
          workspace_id,
          before.path,
          format~,
        ) +
        comparison_query(before, after.unwrap(), request)
      out.write_string(
        "<a download href=\"\{office_escape_xml(url)}\">Export differences \{format.to_upper()}</a>",
      )
    }
    out.write_string("</nav>")
    if report.differences.rows.is_empty() {
      out.write_string(
        "<p>No changed, added or removed records. Downloads contain headers only.</p>",
      )
    }
    out.write_string(
      "<div class=\"table-scroll\"><table><caption>Changed, removed and added records; unchanged records are omitted.</caption><thead><tr>",
    )
    for name in report.differences.columns {
      out.write_string("<th scope=\"col\">\{office_escape_xml(name)}</th>")
    }
    out.write_string("</tr></thead><tbody>")
    for row in report.differences.text_rows() {
      out.write_string("<tr>")
      for value in row {
        out.write_string("<td>\{office_escape_xml(value)}</td>")
      }
      out.write_string("</tr>")
    }
    out.write_string("</tbody></table></div>")
  }
  let back = @desk.workspace_json_table_url(workspace_id, before.path) +
    before.selected_sheet
    .map(name => "&sheet=" + encode_query_value(name))
    .unwrap_or("")
  out.write_string(
    "<p><a href=\"\{office_escape_xml(back)}\">Return to the before table</a></p><p>Keys and cell values match exact displayed text, including case and whitespace. Numeric 1 and text 1 match; 01 and 1 do not. Blank or duplicate keys and duplicate headers need correction before comparing. Record numbers are one-based data records, excluding the header; JSONL blank lines are not records. Column names match exactly, except the two selected key columns may have different names. Formula cached values are used without recalculation. Files are reread on every request, so a later export may reflect saved changes.</p></html>",
  )
  out.to_string()
}

///|
fn comparison_query(
  before : WorkspaceTableSource,
  after : WorkspaceTableSource,
  request : String,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "&comparison=1&compare_path=" + encode_query_value(after.path),
  )
  for
    (key, value) in [
      ("sheet", before.selected_sheet),
      ("compare_sheet", after.selected_sheet),
    ] {
    if value is Some(name) {
      out.write_string("&\{key}=" + encode_query_value(name))
    }
  }
  for key in ["key", "compare_key"] {
    out.write_string("&\{key}=" + encode_query_value(table_query(request, key)))
  }
  out.to_string()
}
