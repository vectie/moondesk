///|
fn explorer_sample() -> @jsontable.Table raise {
  @jsontable.parse(
    (
      #|[{"customer":"Northwind 東京","region":"East","amount":1250.5,"status":"Open"},{"customer":"Bluebird","region":"West","amount":90,"status":"Paid"},{"customer":"Acme, Inc.","region":"East","amount":300,"status":"open"},{"customer":"River","region":"West","amount":2500,"status":"Open"},{"customer":"Draft","region":"East","amount":null,"status":"Open"}]
    ),
  )
}

///|
test "explorer filters sorts summarizes exports and resets one projection" {
  let table = explorer_sample()
  let query = "?text_column=3&contains=OPEN&number_column=2&min=100&max=2000&sort=2&sort_type=number&direction=desc&group=1&sum=2"
  let projected = explore_table(table, query).unwrap()
  assert_eq(projected.rows.length(), 2)
  assert_eq(projected.text_rows()[0][0], "Northwind 東京")
  assert_eq(projected.text_rows()[1][0], "Acme, Inc.")
  assert_true(
    table_explorer_summary(projected, query).contains(
      "<td>East</td><td>2</td><td>2</td><td>1550.5</td>",
    ),
  )
  assert_eq(
    @leafcsv.parse(projected.export_csv()).rows,
    [table.columns] + projected.text_rows(),
  )
  assert_eq(explore_table(table, "").unwrap(), table)
  assert_eq(table.rows.length(), 5)
  let sorted = explore_table(table, "?sort=2&sort_type=number")
    .unwrap()
    .text_rows()
  assert_eq(sorted.map(row => row[0]), [
    "Bluebird", "Acme, Inc.", "Northwind 東京", "River", "Draft",
  ])
  assert_true(explore_table(table, "?number_column=2&min=abc") is Err(_))
  assert_true(explore_table(table, "?number_column=2&min=50&max=20") is Err(_))
  let empty = explore_table(table, "?text_column=0&contains=missing").unwrap()
  assert_eq(empty.rows.length(), 0)
  assert_eq(@leafcsv.parse(empty.export_csv()).rows, [table.columns])
  let html = json_table_html(
    "book-data",
    "sales & orders.csv",
    projected,
    request_path=query,
    total_rows=5,
  )
  assert_true(html.contains("Showing 2 of 5 saved rows"))
  assert_true(html.contains("name=\"contains\" value=\"OPEN\""))
  assert_true(html.contains("format=csv&amp;text_column=3&amp;contains=OPEN"))
  assert_true(html.contains("Reset all"))
}

///|
async test "local HTTP explorer shares CSV TSV JSON JSONL and XLSX projection" {
  @moonlib/fsx.with_temporary_directory("desk-explorer-", root => {
    let book = moonsuite_books_root(root) + "/sales"
    @fs.mkdir(book, recursive=true)
    let source = explorer_sample()
    let csv = source.export_csv()
    let tsv : @leafcsv.Table = {
      rows: [source.columns] + source.text_rows(),
      delimiter: '\t',
    }
    @fs.write_file(book + "/sales.csv", csv, create_mode=CreateOrTruncate)
    @fs.write_file(
      book + "/sales.tsv",
      tsv.serialize_quoted(),
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      book + "/sales.xlsx",
      Bytes::from_array(source.export_xlsx()),
      create_mode=CreateOrTruncate,
    )
    let records = source
      .text_rows()
      .map(row => {
        (
          {
            "customer": row[0],
            "region": row[1],
            "amount": row[2],
            "status": row[3],
          } : Json)
      })
    @fs.write_file(
      book + "/sales.json",
      records.to_json().stringify(),
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      book + "/sales.jsonl",
      records.map(record => record.stringify()).join("\n"),
      create_mode=CreateOrTruncate,
    )
    let query = "&text_column=3&contains=open&number_column=2&min=100&max=2000&sort=2&sort_type=number&direction=desc&group=1&sum=2"
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      for extension in ["csv", "tsv", "xlsx", "json", "jsonl"] {
        let file = "sales." + extension
        let before = @fs.read_file(book + "/" + file).binary()
        let url = @desk.workspace_json_table_url("book-sales", file)
        let (response, body) = @http.get(base + url + query)
        assert_eq(response.code, 200)
        let html = body.text()
        assert_true(html.contains("Showing 2 of 5 saved rows"))
        assert_true(html.contains("1550.5"))
        assert_false(html.contains("<td>River</td>"))
        let (export_response, exported) = @http.get(
          base +
          @desk.workspace_json_table_url("book-sales", file, format="csv") +
          query,
        )
        assert_eq(export_response.code, 200)
        let expected = [
          source.columns,
          source.text_rows()[0],
          source.text_rows()[2],
        ]
        assert_eq(@leafcsv.parse(exported.text()).rows, expected)
        let (reset_response, reset) = @http.get(base + url)
        assert_eq(reset_response.code, 200)
        assert_true(reset.text().contains("Showing 5 of 5 saved rows"))
        assert_eq(@fs.read_file(book + "/" + file).binary(), before)
        if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
          @fs.write_file(
            evidence + "/explorer-" + file + ".html",
            html,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/filtered-" + extension + ".csv",
            exported.text(),
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/sample-" + file,
            before,
            create_mode=CreateOrTruncate,
          )
        }
      }
      let (bad, error_body) = @http.get(
        base +
        @desk.workspace_json_table_url("book-sales", "sales.csv") +
        "&number_column=2&min=oops",
      )
      assert_eq(bad.code, 400)
      let error_html = error_body.text()
      assert_true(error_html.contains("No filter was applied"))
      assert_true(error_html.contains("name=\"min\" value=\"oops\""))
    })
  })
}
