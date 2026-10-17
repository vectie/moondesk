///|
async fn handle_workspace_table_lookup(
  workspace : @desk.DeskWorkspace,
  workspace_id : String,
  source : WorkspaceTableSource,
  request : String,
  method_ : @http.RequestMethod,
  conn : @http.ServerConnection,
) -> Unit {
  let format = table_query(request, "format")
  let html = format == "" || format == "html"
  let lookup_path = query_value(request, "lookup_path").unwrap_or("")
  let mut lookup : WorkspaceTableSource? = None
  let mut error : String? = None
  let mut result : TableLookup? = None
  if lookup_path != "" {
    match
      read_workspace_json_table(
        workspace,
        lookup_path,
        sheet?=query_value(request, "lookup_sheet").map(decode_query_value),
      ) {
      Ok(reference) => lookup = Some(reference)
      Err(message) => error = Some("Lookup file: " + message)
    }
  }
  if lookup is Some(reference) {
    match
      (
        comparison_key_index(source, request, "source_key"),
        comparison_key_index(reference, request, "lookup_key"),
      ) {
      (Some(left), Some(right)) =>
        match enrich_table(source.table, reference.table, left, right) {
          Ok(report) => {
            // Keep provenance in exported headers, including named worksheets.
            report.table.columns[1] = "Source record: " +
              comparison_source_label(source)
            report.table.columns[2] = "Lookup record: " +
              comparison_source_label(reference)
            result = Some(report)
          }
          Err(message) => error = Some(message)
        }
      _ if table_query(request, "source_key") != "" ||
        table_query(request, "lookup_key") != "" =>
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
          table_lookup_html(
            workspace_id, source, lookup, request, result, error,
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
      error.unwrap_or(
        "Open a lookup file and choose source and lookup keys before exporting",
      ),
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
        sheet_name="Enriched table",
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
    "content-disposition": "attachment; filename=\"table-enriched.\{format}\"",
  })
  if !(method_ is Head) {
    conn.write(bytes)
  }
  conn.end_response()
}
