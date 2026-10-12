///|
async fn handle_workspace_table_unpivot(
  workspace_id : String,
  source : WorkspaceTableSource,
  request : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let format = table_query(request, "format")
  let html = format == "" || format == "html"
  let measures = unpivot_measures(request)
  let mut error : String? = None
  let mut result : @jsontable.Table? = None
  if !measures.is_empty() || !html {
    match unpivot_table(source, measures) {
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
          unpivot_html(workspace_id, source, measures, result, error),
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
      error.unwrap_or("Choose measurement columns before exporting"),
    )
    return
  }
  let (mime, bytes) = match format {
    "csv" =>
      ("text/csv; charset=utf-8", @encoding/utf8.encode(report.export_csv()))
    "xlsx" => {
      let data = @leafxlsx.create(
        [report.columns.map(value => @leafscene.CellValue::Text(value))] +
        report.rows,
        sheet_name="Reshaped table",
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
    "content-disposition": "attachment; filename=\"table-reshaped.\{format}\"",
  })
  if !(method_ is Head) {
    conn.write(bytes)
  }
  conn.end_response()
}
