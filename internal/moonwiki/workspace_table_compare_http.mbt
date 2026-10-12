///|
async fn handle_workspace_table_compare(
  workspace : @desk.DeskWorkspace,
  workspace_id : String,
  before : WorkspaceTableSource,
  request : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let format = table_query(request, "format")
  let html = format == "" || format == "html"
  let after_path = query_value(request, "compare_path").unwrap_or("")
  let mut after : WorkspaceTableSource? = None
  let mut error : String? = None
  let mut comparison : TableComparison? = None
  if after_path != "" {
    match
      read_workspace_json_table(
        workspace,
        after_path,
        sheet?=query_value(request, "compare_sheet").map(decode_query_value),
      ) {
      Ok(source) => after = Some(source)
      Err(message) => error = Some("After file: " + message)
    }
  }
  if after is Some(source) {
    match
      (
        comparison_key_index(before, request, "key"),
        comparison_key_index(source, request, "compare_key"),
      ) {
      (Some(left), Some(right)) =>
        match compare_tables(before.table, source.table, left, right) {
          Ok(report) => {
            // Keep provenance in exported headers, including named worksheets.
            report.differences.columns[2] = "Before record: " +
              comparison_source_label(before)
            report.differences.columns[3] = "After record: " +
              comparison_source_label(source)
            comparison = Some(report)
          }
          Err(message) => error = Some(message)
        }
      _ if table_query(request, "key") != "" ||
        table_query(request, "compare_key") != "" =>
        error = Some(
          "Choose an existing key column in both tables. A selected column may have been renamed or removed.",
        )
      _ => ()
    }
  }
  if html {
    let status = if error is Some(_) { 400 } else { 200 }
    conn.send_response(
      status,
      if status == 200 {
        "OK"
      } else {
        "Bad Request"
      },
      extra_headers={ "content-type": "text/html; charset=utf-8" },
    )
    if !(method_ is Head) {
      conn.write(
        @encoding/utf8.encode(
          table_comparison_html(
            workspace_id, before, after, request, comparison, error,
          ),
        ),
      )
    }
    conn.end_response()
    return
  }
  guard comparison is Some(report) else {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      error.unwrap_or(
        "Open an after file and choose both unique key columns before exporting",
      ),
    )
    return
  }
  let (mime, bytes) = match format {
    "csv" =>
      (
        "text/csv; charset=utf-8",
        @encoding/utf8.encode(report.differences.export_csv()),
      )
    "xlsx" => {
      let data = @leafxlsx.create(
        [
          report.differences.columns.map(value => {
            @leafscene.CellValue::Text(value)
          }),
        ] +
        report.differences.rows,
        sheet_name="Table differences",
      ) catch {
        error => {
          send_api_error(conn, method_, 400, "Bad Request", "\{Repr(error)}")
          return
        }
      }
      (
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        Bytes::from_array(data),
      )
    }
    _ => {
      send_api_error(
        conn, method_, 400, "Bad Request", "Use html, csv or xlsx format",
      )
      return
    }
  }
  conn.send_response(200, "OK", extra_headers={
    "content-type": mime,
    "content-disposition": "attachment; filename=\"table-comparison.\{format}\"",
  })
  if !(method_ is Head) {
    conn.write(bytes)
  }
  conn.end_response()
}
