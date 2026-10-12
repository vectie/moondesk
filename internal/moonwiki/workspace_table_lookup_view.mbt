///|
fn table_lookup_html(
  workspace_id : String,
  source : WorkspaceTableSource,
  lookup : WorkspaceTableSource?,
  request : String,
  result : TableLookup?,
  error : String?,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Enrich from a lookup table · MoonDesk</title><style>body{font:15px system-ui;margin:32px;color:#182326;background:#f7f9f8}a{color:#08796b}fieldset{margin:16px 0;padding:14px}label{display:inline-block;margin:6px}input,select,button{font:inherit;padding:6px;max-width:26rem}table{border-collapse:collapse;background:white}th,td{border:1px solid #ccd8d1;padding:8px;white-space:pre-wrap;text-align:left;vertical-align:top}.table-scroll{overflow:auto}nav{display:flex;gap:16px;margin:20px 0}[role=alert]{color:#922}</style><h1>Enrich from a lookup table</h1>",
  )
  out.write_string(
    "<p>Source: <strong>\{office_escape_xml(comparison_source_label(source))}</strong></p>",
  )
  if lookup is Some(reference) {
    out.write_string(
      "<p>Lookup: <strong>\{office_escape_xml(comparison_source_label(reference))}</strong></p>",
    )
  }
  out.write_string(
    "<p>Append lookup fields to every saved source record. Repeated source keys are allowed; lookup keys must be unique and nonblank. Existing explorer filters do not apply. Both files stay unchanged.</p>",
  )
  let common = comparison_hidden("lookup", "1") +
    comparison_hidden("path", source.path)
  let source_sheet = source.selected_sheet
    .map(name => comparison_hidden("sheet", name))
    .unwrap_or("")
  let lookup_path = office_escape_xml(table_query(request, "lookup_path"))
  out.write_string(
    "<form method=\"get\">\{common}\{source_sheet}<fieldset><legend>Choose the lookup file</legend><label>Workspace-relative path <input name=\"lookup_path\" value=\"\{lookup_path}\" placeholder=\"reports/new-sales.csv\" required></label><button type=\"submit\">Open lookup file</button></fieldset></form>",
  )
  if lookup is Some(reference) {
    let paths = common + comparison_hidden("lookup_path", reference.path)
    if !source.sheet_names.is_empty() || !reference.sheet_names.is_empty() {
      out.write_string(
        "<form method=\"get\">\{paths}<fieldset><legend>Choose worksheets</legend>",
      )
      out.write_string(
        comparison_sheet_select(source, "sheet", "Source worksheet"),
      )
      out.write_string(
        comparison_sheet_select(reference, "lookup_sheet", "Lookup worksheet"),
      )
      out.write_string(
        "<button type=\"submit\">Open worksheets</button><p>Opening files or worksheets clears the key selection. Choose keys again for the new schema.</p></fieldset></form>",
      )
    }
    let lookup_sheet = reference.selected_sheet
      .map(name => comparison_hidden("lookup_sheet", name))
      .unwrap_or("")
    out.write_string(
      "<form method=\"get\">\{paths}\{source_sheet}\{lookup_sheet}<fieldset><legend>Match records</legend>",
    )
    out.write_string(
      comparison_key_select(
        source,
        "source_key",
        "Source key",
        request,
        prompt="Choose a source key",
      ),
    )
    out.write_string(
      comparison_key_select(reference, "lookup_key", "Lookup key", request),
    )
    out.write_string(
      "<button type=\"submit\">Enrich table</button></fieldset></form>",
    )
  }
  if error is Some(message) {
    out.write_string("<p role=\"alert\">\{office_escape_xml(message)}</p>")
  } else if lookup is None {
    out.write_string(
      "<p>Open another saved CSV, TSV, JSON, JSONL, NDJSON or XLSX file in this workspace.</p>",
    )
  } else if result is None {
    out.write_string(
      "<p>Choose the source key and the unique lookup key, then enrich. Blank or missing source keys remain unmatched.</p>",
    )
  }
  if result is Some(report) {
    out.write_string(
      "<h2>\{report.matched} matched · \{report.unmatched} unmatched source records · \{report.unused_lookup} unused lookup records</h2>",
    )
    out.write_string("<nav>")
    for format in ["csv", "xlsx"] {
      let url = @desk.workspace_json_table_url(
          workspace_id,
          source.path,
          format~,
        ) +
        lookup_query(source, lookup.unwrap(), request)
      out.write_string(
        "<a download href=\"\{office_escape_xml(url)}\">Export enriched \{format.to_upper()}</a>",
      )
    }
    out.write_string("</nav>")
    if report.table.rows.is_empty() {
      out.write_string(
        "<p>No source records. Downloads contain headers only.</p>",
      )
    }
    out.write_string(
      "<div class=\"table-scroll\"><table><caption>All source records in source order, with matched lookup fields appended.</caption><thead><tr>",
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
  let back = @desk.workspace_json_table_url(workspace_id, source.path) +
    source.selected_sheet
    .map(name => "&sheet=" + encode_query_value(name))
    .unwrap_or("")
  out.write_string(
    "<p><a href=\"\{office_escape_xml(back)}\">Return to the source table</a></p><p>Keys and cell values match exact displayed text, including case and whitespace. Numeric 1 and text 1 match; 01 and 1 do not. Blank source keys stay unmatched. Blank or duplicate lookup keys and duplicate headers require correction. Repeated source keys reuse the same lookup record; rows never multiply. Record numbers are one-based data records, excluding the header; JSONL blank lines are not records. Selected key columns may have different names. Source and Lookup prefixes distinguish fields; all displayed values export as text and record numbers as numeric cells. No edits are written back. Formula cached values are used without recalculation. Files are reread on every request, so a later export may reflect saved changes.</p></html>",
  )
  out.to_string()
}

///|
fn lookup_query(
  source : WorkspaceTableSource,
  lookup : WorkspaceTableSource,
  request : String,
) -> String {
  let out = StringBuilder()
  out.write_string("&lookup=1&lookup_path=" + encode_query_value(lookup.path))
  for
    (key, value) in [
      ("sheet", source.selected_sheet),
      ("lookup_sheet", lookup.selected_sheet),
    ] {
    if value is Some(name) {
      out.write_string("&\{key}=" + encode_query_value(name))
    }
  }
  for key in ["source_key", "lookup_key"] {
    out.write_string("&\{key}=" + encode_query_value(table_query(request, key)))
  }
  out.to_string()
}
