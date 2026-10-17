///|
async fn handle_workspace_table_pivot(
  workspace_id : String,
  source : WorkspaceTableSource,
  request : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let format = table_query(request, "format")
  let html = format == "" || format == "html"
  let row_name = table_query(request, "pivot_row")
  let column_name = table_query(request, "pivot_column")
  let aggregation = query_value(request, "aggregate")
    .map(decode_query_value)
    .unwrap_or("count")
  let value_name = table_query(request, "pivot_value")
  let mut error : String? = None
  let mut result : PivotReport? = None
  if row_name != "" || column_name != "" || !html {
    match
      pivot_report(source.table, row_name, column_name, aggregation, value_name) {
      Ok(table) => result = Some(table)
      Err(message) => error = Some(message)
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
          pivot_html(
            workspace_id, source, row_name, column_name, aggregation, value_name,
            result, error,
          ),
        ),
      )
    }
    conn.end_response()
    return
  }
  guard result is Some(report) else {
    send_api_error(
      conn,
      method_,
      400,
      "Bad Request",
      error.unwrap_or("Choose grouping columns before exporting"),
    )
    return
  }
  let report = report.table
  let (mime, bytes) = match format {
    "csv" =>
      ("text/csv; charset=utf-8", @encoding/utf8.encode(report.export_csv()))
    "xlsx" => {
      let data = @leafxlsx.create(
        [report.columns.map(value => Text(value))] + report.rows,
        sheet_name="Pivot report",
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
    "content-disposition": "attachment; filename=\"table-pivot.\{format}\"",
  })
  if !(method_ is Head) {
    conn.write(bytes)
  }
  conn.end_response()
}
