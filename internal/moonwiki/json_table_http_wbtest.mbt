///|
async fn json_table_http_journey(root : String) -> Unit {
  let book = moonsuite_books_root(root) + "/table-data"
  @fs.mkdir(book, recursive=true)
  let records = [
    "{\"name\":\"東京 🐈\",\"amount\":12.5,\"meta\":{\"a\":\"x,y\"}}", "{\"name\":\"Zoë\",\"enabled\":true,\"note\":\"line\\n\\\"two\\\"\",\"amount\":-2e3}",
    "{\"name\":\"=literal\",\"items\":[1,\"好\"],\"amount\":null}",
  ]
  let json = "[" + records.join(",") + "]"
  let jsonl = records.join("\n") + "\n"
  @fs.write_file(book + "/records.json", json, create_mode=CreateOrTruncate)
  @fs.write_file(book + "/records.jsonl", jsonl, create_mode=CreateOrTruncate)
  @fs.write_file(
    book + "/config.json",
    "{\"setting\":true}",
    create_mode=CreateOrTruncate,
  )
  let server = Server::new("127.0.0.1", 0, reuse_addr=true)
  defer server.close()
  let base = "http://127.0.0.1:\{server.port()}"
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_desk(root, root),
      no_wait=true,
      allow_failure=true,
    )
    for filename in ["records.json", "records.jsonl"] {
      let source = if filename.has_suffix(".jsonl") { jsonl } else { json }
      let table = @jsontable.parse(source, jsonl=filename.has_suffix(".jsonl"))
      let preview_url = @desk.workspace_preview_url("book-table-data", filename)
      let (preview_response, preview_body) = @http.get(base + preview_url)
      assert_eq(preview_response.code, 200)
      let preview = @json.parse(preview_body.text())
      assert_eq(json_string(preview, "body", default=""), source)
      let (response, body) = @http.get(
        base + @desk.workspace_json_table_url("book-table-data", filename),
      )
      assert_eq(response.code, 200)
      let html = body.text()
      assert_true(html.contains("3 rows · 6 columns"))
      assert_true(html.contains("東京 🐈"))
      assert_true(
        html.contains("Export filtered CSV") &&
        html.contains("Export filtered XLSX"),
      )
      @fs.write_file(
        root + "/" + filename + ".html",
        html,
        create_mode=CreateOrTruncate,
      )
      let (csv_response, csv_body) = @http.get(
        base +
        @desk.workspace_json_table_url(
          "book-table-data",
          filename,
          format="csv",
        ),
      )
      assert_eq(csv_response.code, 200)
      let csv = csv_body.text()
      @fs.write_file(
        root + "/" + filename + ".csv",
        csv,
        create_mode=CreateOrTruncate,
      )
      assert_eq(@leafcsv.parse(csv).rows, [table.columns] + table.text_rows())
      let (xlsx_response, xlsx_body) = @http.get(
        base +
        @desk.workspace_json_table_url(
          "book-table-data",
          filename,
          format="xlsx",
        ),
      )
      assert_eq(xlsx_response.code, 200)
      let xlsx = xlsx_body.binary()
      @fs.write_file(
        root + "/" + filename + ".xlsx",
        xlsx,
        create_mode=CreateOrTruncate,
      )
      guard @moonleaf.open("export.xlsx", xlsx.to_fixedarray())
        is WorkbookDocument(workbook) else {
        fail("XLSX reopen failed")
      }
      assert_eq(
        workbook.sheets[0].cells.map(cell => cell.value),
        table.workbook().sheets[0].cells.map(cell => cell.value),
      )
      assert_eq(@fs.read_file(book + "/" + filename).text(), source)
    }
    let (object_response, _) = @http.get(
      base + @desk.workspace_json_table_url("book-table-data", "config.json"),
    )
    assert_eq(object_response.code, 400)
    // A normal JSON object remains editable even though it is not tabular.
    let payload : Json = {
      "path": "config.json",
      "expected_content": "{\"setting\":true}",
      "content": "{\"setting\":false}",
    }
    let (saved, _) = @http.post(
      base + "/api/workspaces/book-table-data/source",
      payload.stringify(),
      headers={ "Origin": base, "Content-Type": "application/json" },
    )
    assert_eq(saved.code, 200)
    let (reopened, body) = @http.get(
      base + @desk.workspace_preview_url("book-table-data", "config.json"),
    )
    assert_eq(reopened.code, 200)
    assert_eq(
      json_string(@json.parse(body.text()), "body", default=""),
      "{\"setting\":false}",
    )
    @fs.write_file(
      root + "/RECEIPT.json",
      (
        {
          "status": "PASS",
          "actual_host_http": true,
          "input_formats": ["json", "jsonl"],
          "rows": 3,
          "union_columns": 6,
          "csv_reopened": true,
          "xlsx_reopened": true,
          "source_unchanged_after_exports": true,
          "normal_json_edit_save_reopen": true,
        } : Json).stringify(indent=2),
      create_mode=CreateOrTruncate,
    )
  })
}

///|
async test "actual host JSON table view exports and normal source editing" {
  match @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") {
    Some(root) => json_table_http_journey(root)
    None =>
      @moonlib/fsx.with_temporary_directory(
        "moondesk-json-http-", json_table_http_journey,
      )
  }
}
