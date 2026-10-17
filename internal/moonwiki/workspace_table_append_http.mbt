///|
async fn handle_workspace_table_append(
  workspace : @desk.DeskWorkspace,
  workspace_id : String,
  source : WorkspaceTableSource,
  request : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let format = table_query(request, "format")
  let html = format == "" || format == "html"
  let append_path = query_value(request, "append_path").unwrap_or("")
  let mut second : WorkspaceTableSource? = None
  let mut error : String? = None
  let mut result : TableAppend? = None
  if append_path != "" {
    match
      read_workspace_json_table(
        workspace,
        append_path,
        sheet?=query_value(request, "append_sheet").map(decode_query_value),
      ) {
      Ok(reference) => second = Some(reference)
      Err(message) => error = Some("Second file: " + message)
    }
  }
  if second is Some(reference) {
    match append_tables(source, reference) {
      Ok(report) => result = Some(report)
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
          table_append_html(
            workspace_id, source, second, request, result, error,
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
      error.unwrap_or("Open a second saved table before exporting"),
    )
    return
  }
  let (mime, bytes) = match format {
    "csv" =>
      (
        "text/csv; charset=utf-8",
        @encoding/utf8.encode(report.table.export_csv()),
      )
    "xlsx" => {
      let data = @leafxlsx.create(
        [report.table.columns.map(value => Text(value))] + report.table.rows,
        sheet_name="Combined table",
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
    "content-disposition": "attachment; filename=\"table-combined.\{format}\"",
  })
  if !(method_ is Head) {
    conn.write(bytes)
  }
  conn.end_response()
}
