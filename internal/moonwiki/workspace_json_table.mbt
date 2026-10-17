///|
priv struct WorkspaceTableSource {
  path : String
  table : @jsontable.Table
  sheet_names : Array[String]
  selected_sheet : String?
}

///|
fn json_table_path(path : String) -> Bool {
  let lower = path.to_lower()
  lower.has_suffix(".json") ||
  lower.has_suffix(".jsonl") ||
  lower.has_suffix(".ndjson") ||
  lower.has_suffix(".csv") ||
  lower.has_suffix(".tsv") ||
  lower.has_suffix(".xlsx")
}

///|
async fn read_workspace_json_table(
  workspace : @desk.DeskWorkspace,
  path : String,
  sheet? : String,
) -> Result[WorkspaceTableSource, String] {
  let relative = decode_query_value(path)
  guard resolve_workspace_existing_path(workspace.root_path, relative)
    is Some((absolute, clean)) else {
    return Err("Table path is missing or outside the selected workspace")
  }
  if !json_table_path(clean) || is_directory(absolute) {
    return Err("Choose JSON, JSONL, CSV, TSV or XLSX data")
  }
  if clean.to_lower().has_suffix(".xlsx") {
    let document = @moonleaf.open(
      clean,
      @fs.read_file(absolute).binary().to_fixedarray(),
    ) catch {
      error => return Err("\{Repr(error)}")
    }
    guard document is @leafscene.WorkbookDocument(workbook) &&
      !workbook.sheets.is_empty() else {
      return Err("Workbook has no sheets")
    }
    let selected = sheet.unwrap_or(workbook.sheets[0].name)
    let matching = workbook.sheets.filter(item => item.name == selected)
    if matching.length() != 1 {
      return Err(
        "Worksheet \{selected} is missing or ambiguous. Reopen this workbook's table view and choose an available worksheet.",
      )
    }
    return table_from_sheet(matching[0]).map(table => {
      path: clean,
      table,
      sheet_names: workbook.sheets.map(item => item.name),
      selected_sheet: Some(selected),
    })
  }
  if sheet is Some(_) {
    return Err("Worksheet selection is only available for XLSX files")
  }
  let text = @fs.read_file(absolute).text() catch {
    _ => return Err("JSON table could not be read as UTF-8")
  }
  if clean.to_lower().has_suffix(".csv") || clean.to_lower().has_suffix(".tsv") {
    let parsed = @leafcsv.parse(
      text,
      delimiter=if clean.to_lower().has_suffix(".tsv") { '\t' } else { ',' },
    ) catch {
      _ =>
        return Err(
          "CSV/TSV could not be read: invalid quoting or size limit exceeded",
        )
    }
    return table_from_sheet(parsed.workbook().sheets[0]).map(table => {
      path: clean,
      table,
      sheet_names: [],
      selected_sheet: None,
    })
  }
  let table = @jsontable.parse(
    text,
    jsonl=!clean.to_lower().has_suffix(".json"),
  ) catch {
    error => return Err("\{Repr(error)}")
  }
  Ok({ path: clean, table, sheet_names: [], selected_sheet: None, })
}

///|
fn json_table_html(
  workspace_id : String,
  path : String,
  table : @jsontable.Table,
  request_path~ : String = "",
  total_rows~ : Int32 = table.rows.length(),
  sheet_names~ : Array[String] = [],
) -> String {
  let output = StringBuilder()
  output.write_string(
    "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Local data explorer · MoonDesk</title><style>body{font:15px system-ui;margin:32px;color:#182326;background:#f7f9f8}h1{font-size:24px}nav{display:flex;gap:16px;margin:20px 0}a{color:#08796b}table{border-collapse:collapse;background:white}th,td{border:1px solid #d4deda;padding:9px 12px;text-align:left;white-space:pre-wrap;vertical-align:top}th{background:#e3efea;position:sticky;top:0}.table-scroll{overflow:auto}p{color:#475650}</style><h1>",
  )
  output.write_string(office_escape_xml(path))
  output.write_string(
    "</h1><p>\{table.rows.length()} rows · \{table.columns.length()} columns. Showing \{table.rows.length()} of \{total_rows} saved rows. Source unchanged. CSV/TSV/XLSX use the first row as headers. Missing fields are blank; nested values are JSON text.</p>",
  )
  output.write_string(table_worksheet_controls(path, sheet_names, request_path))
  output.write_string(
    table_explorer_controls(workspace_id, path, table.columns, request_path),
  )
  output.write_string(table_explorer_summary(table, request_path))
  output.write_string("<nav>")
  for format in ["csv", "xlsx", "json", "jsonl"] {
    let url = @desk.workspace_json_table_url(workspace_id, path, format~) +
      table_explorer_query(request_path)
    output.write_string(
      "<a download href=\"\{office_escape_xml(url)}\">Export filtered \{format.to_upper()}</a>",
    )
  }
  if table_group_summary(table, request_path) is Ok(_) {
    for format in ["csv", "xlsx", "json", "jsonl"] {
      let url = @desk.workspace_json_table_url(workspace_id, path, format~) +
        table_explorer_query(request_path) +
        "&projection=summary"
      output.write_string(
        "<a download href=\"\{office_escape_xml(url)}\">Export summary \{format.to_upper()}</a>",
      )
    }
  }
  let compare_url = @desk.workspace_json_table_url(workspace_id, path) +
    "&comparison=1" +
    query_value(request_path, "sheet")
    .map(value => "&sheet=" + value)
    .unwrap_or("")
  output.write_string(
    "<a href=\"\{office_escape_xml(compare_url)}\">Compare with another saved table</a>",
  )
  let lookup_url = @desk.workspace_json_table_url(workspace_id, path) +
    "&lookup=1" +
    query_value(request_path, "sheet")
    .map(value => "&sheet=" + value)
    .unwrap_or("")
  output.write_string(
    "<a href=\"\{office_escape_xml(lookup_url)}\">Enrich from a lookup table</a>",
  )
  let append_url = @desk.workspace_json_table_url(workspace_id, path) +
    "&append=1" +
    query_value(request_path, "sheet")
    .map(value => "&sheet=" + value)
    .unwrap_or("")
  output.write_string(
    "<a href=\"\{office_escape_xml(append_url)}\">Combine rows with another table</a>",
  )
  let unpivot_url = @desk.workspace_json_table_url(workspace_id, path) +
    "&unpivot=1" +
    query_value(request_path, "sheet")
    .map(value => "&sheet=" + value)
    .unwrap_or("")
  output.write_string(
    "<a href=\"\{office_escape_xml(unpivot_url)}\">Reshape columns into rows</a>",
  )
  let pivot_url = @desk.workspace_json_table_url(workspace_id, path) +
    "&pivot=1" +
    query_value(request_path, "sheet")
    .map(value => "&sheet=" + value)
    .unwrap_or("")
  output.write_string(
    "<a href=\"\{office_escape_xml(pivot_url)}\">Create pivot report</a>",
  )
  output.write_string(
    "</nav><p>JSON/JSONL downloads contain object records from this table projection: text stays text, numbers and booleans keep their types, and empty cells become null. Nested JSON and literal null imported by the table reader remain text. Duplicate headers must be renamed before JSON/JSONL row export.</p>",
  )
  if table_record_headers(table.columns) is Err(message) {
    output.write_string("<p role=\"alert\">\{office_escape_xml(message)}</p>")
  }
  output.write_string("<div class=\"table-scroll\"><table><thead><tr>")
  for column in table.columns {
    output.write_string("<th scope=\"col\">\{office_escape_xml(column)}</th>")
  }
  output.write_string("</tr></thead><tbody>")
  for row in table.text_rows() {
    output.write_string("<tr>")
    for value in row {
      output.write_string("<td>\{office_escape_xml(value)}</td>")
    }
    output.write_string("</tr>")
  }
  output.write_string(
    "</tbody></table></div><p>Your saved source is unchanged. Return to the MoonDesk tab to continue editing. Filtered exports contain individual rows; summary exports contain only the displayed groups and their counts/totals.</p></html>",
  )
  output.to_string()
}

///|
async fn handle_workspace_json_table(
  workspace_root : String,
  workspace_id : String,
  request_path : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  guard find_workspace(workspace_root, workspace_id) is Some(workspace) else {
    send_api_error(conn, method_, 404, "Not Found", "Unknown workspace")
    return
  }
  let result = read_workspace_json_table(
    workspace,
    query_value(request_path, "path").unwrap_or(""),
    sheet?=query_value(request_path, "sheet").map(decode_query_value),
  )
  guard result is Ok(source) else {
    let message = match result {
      Err(error) => error
      _ => "Table could not be read"
    }
    send_api_error(conn, method_, 400, "Bad Request", message)
    return
  }
  if table_query(request_path, "pivot") == "1" {
    handle_workspace_table_pivot(
      workspace_id, source, request_path, method_, conn,
    )
    return
  }
  if table_query(request_path, "unpivot") == "1" {
    handle_workspace_table_unpivot(
      workspace_id, source, request_path, method_, conn,
    )
    return
  }
  if table_query(request_path, "append") == "1" {
    handle_workspace_table_append(
      workspace, workspace_id, source, request_path, method_, conn,
    )
    return
  }
  if table_query(request_path, "lookup") == "1" {
    handle_workspace_table_lookup(
      workspace, workspace_id, source, request_path, method_, conn,
    )
    return
  }
  if table_query(request_path, "comparison") == "1" {
    handle_workspace_table_compare(
      workspace, workspace_id, source, request_path, method_, conn,
    )
    return
  }
  let path = source.path
  let table = source.table
  // Pin the default first sheet by name in every form and export URL too.
  let request_path = if query_value(request_path, "sheet") is None &&
    source.selected_sheet is Some(name) {
    request_path + "&sheet=" + encode_query_value(name)
  } else {
    request_path
  }
  let format = query_value(request_path, "format").unwrap_or("html")
  let total_rows = table.rows.length()
  let table = match explore_table(table, request_path) {
    Ok(table) => table
    Err(message) => {
      if format == "html" {
        let controls = table_worksheet_controls(
            path,
            source.sheet_names,
            request_path,
          ) +
          table_explorer_controls(
            workspace_id,
            path,
            table.columns,
            request_path,
          )
        let error_html = "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><title>Check table filters · MoonDesk</title><h1>Check table filters</h1><p role=\"alert\">\{office_escape_xml(message)}</p><p>No filter was applied. Your source is unchanged.</p>\{controls}</html>"
        conn.send_response(400, "Bad Request", extra_headers={
          "content-type": "text/html; charset=utf-8",
        })
        if !(method_ is Head) {
          conn.write(@encoding/utf8.encode(error_html))
        }
        conn.end_response()
      } else {
        send_api_error(conn, method_, 400, "Bad Request", message)
      }
      return
    }
  }
  if format == "html" {
    send_text(
      conn,
      method_,
      "text/html; charset=utf-8",
      json_table_html(
        workspace_id,
        path,
        table,
        request_path~,
        total_rows~,
        sheet_names=source.sheet_names,
      ),
    )
    return
  }
  let projection = table_query(request_path, "projection")
  let summary = projection == "summary"
  let table = match projection {
    "" | "rows" => table
    "summary" =>
      match table_group_summary(table, request_path) {
        Ok(summary) => summary
        Err(message) => {
          send_api_error(conn, method_, 400, "Bad Request", message)
          return
        }
      }
    _ => {
      send_api_error(
        conn, method_, 400, "Bad Request", "Use rows or summary projection",
      )
      return
    }
  }
  let (mime, bytes) = match format {
    "json" | "jsonl" => {
      let records = match table_export_records(table, jsonl=format == "jsonl") {
        Ok(text) => text
        Err(message) => {
          send_api_error(conn, method_, 400, "Bad Request", message)
          return
        }
      }
      (
        if format == "json" {
          "application/json; charset=utf-8"
        } else {
          "application/x-ndjson; charset=utf-8"
        },
        @encoding/utf8.encode(records),
      )
    }
    "csv" =>
      ("text/csv; charset=utf-8", @encoding/utf8.encode(table.export_csv()))
    "xlsx" => {
      let bytes = @leafxlsx.create(
        [table.columns.map(column => @leafscene.Text(column))] + table.rows,
        sheet_name=source.selected_sheet.unwrap_or(
          if summary {
            "Group summary"
          } else {
            "JSON data"
          },
        ),
      ) catch {
        error => {
          send_api_error(conn, method_, 400, "Bad Request", "\{Repr(error)}")
          return
        }
      }
      (
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        Bytes::from_array(bytes),
      )
    }
    _ => {
      send_api_error(
        conn, method_, 400, "Bad Request", "Use html, csv, xlsx, json or jsonl format",
      )
      return
    }
  }
  let filename = if summary { "table-summary" } else { "json-table" }
  conn.send_response(200, "OK", extra_headers={
    "content-type": mime,
    "content-disposition": "attachment; filename=\"\{filename}.\{format}\"",
  })
  if !(method_ is Head) {
    conn.write(bytes)
  }
  conn.end_response()
}
