///|
fn lookup_source_fixture() -> @jsontable.Table raise {
  @jsontable.parse(
    (
      #|[{"customer":"001","amount":10},{"customer":"東京<&\"","amount":0},{"customer":"001","amount":12.5},{"customer":"missing","amount":7},{"customer":"","amount":3},{"customer":"=1+1","amount":4}]
    ),
  )
}

///|
fn lookup_reference_fixture() -> @jsontable.Table raise {
  @jsontable.parse(
    (
      #|[{"id":"東京<&\"","name":"Tokyo","tier":"gold"},{"id":"001","name":"Acme, Inc.\nWest","tier":"silver"},{"id":"unused","name":"Unused","tier":""},{"id":"=1+1","name":"=SUM(A1)","tier":"formula-looking"}]
    ),
  )
}

///|
test "lookup enriches repeated source keys in order without multiplying rows" {
  let source = lookup_source_fixture()
  let lookup = lookup_reference_fixture()
  let report = enrich_table(source, lookup, 0, 0).unwrap()
  assert_eq((report.matched, report.unmatched, report.unused_lookup), (4, 2, 1))
  assert_eq(report.table.columns, [
    "Match", "Source record", "Lookup record", "Source: customer", "Source: amount",
    "Lookup: id", "Lookup: name", "Lookup: tier",
  ])
  assert_eq(report.table.text_rows(), [
    ["Matched", "1", "2", "001", "10", "001", "Acme, Inc.\nWest", "silver"],
    ["Matched", "2", "1", "東京<&\"", "0", "東京<&\"", "Tokyo", "gold"],
    ["Matched", "3", "2", "001", "12.5", "001", "Acme, Inc.\nWest", "silver"],
    ["Unmatched", "4", "", "missing", "7", "", "", ""],
    ["Unmatched", "5", "", "", "3", "", "", ""],
    ["Matched", "6", "4", "=1+1", "4", "=1+1", "=SUM(A1)", "formula-looking"],
  ])
  assert_eq(report.table.rows[0][1], @leafscene.Number("1"))
  assert_eq(report.table.rows[0][3], @leafscene.Text("001"))
  assert_eq(report.table.rows[5][6], @leafscene.Text("=SUM(A1)"))
  assert_eq(
    @leafcsv.parse(report.table.export_csv()).rows,
    [report.table.columns] + report.table.text_rows(),
  )
  assert_eq(source, lookup_source_fixture())
  assert_eq(lookup, lookup_reference_fixture())
}

///|
test "lookup exact text matching blank sources empty inputs and key-only lookup" {
  let source = @jsontable.parse(
    "[{\"id\":1},{\"id\":\"01\"},{\"id\":\"A\"},{\"id\":\" a\"},{\"id\":\"a\"},{\"id\":\" \"},{}]",
  )
  let lookup = @jsontable.parse("[{\"key\":\"1\"},{\"key\":\"a\"}]")
  let report = enrich_table(source, lookup, 0, 0).unwrap()
  assert_eq((report.matched, report.unmatched, report.unused_lookup), (2, 5, 0))
  let collision = enrich_table(
      @jsontable.parse("[{\"id\":\"a\",\"name\":\"Source name\"}]"),
      @jsontable.parse("[{\"id\":\"a\",\"name\":\"Reference name\"}]"),
      0,
      0,
    ).unwrap().table
  assert_eq(collision.columns, [
    "Match", "Source record", "Lookup record", "Source: id", "Source: name", "Lookup: id",
    "Lookup: name",
  ])
  assert_eq(collision.text_rows()[0][4], "Source name")
  assert_eq(collision.text_rows()[0][6], "Reference name")
  let empty : @jsontable.Table = { columns: ["id"], rows: [], }
  assert_eq(enrich_table(empty, lookup, 0, 0).unwrap().unused_lookup, 2)
  assert_eq(enrich_table(source, empty, 0, 0).unwrap().unmatched, 7)
  assert_eq(enrich_table(empty, empty, 0, 0).unwrap().table.rows.length(), 0)
  let same = enrich_table(lookup, lookup, 0, 0).unwrap()
  assert_eq((same.matched, same.unused_lookup), (2, 0))
}

///|
test "lookup refuses ambiguous reference keys duplicate headers and excessive output" {
  let source = lookup_source_fixture()
  for
    text in [
      "[{\"id\":\"a\"},{\"id\":\"a\"}]", "[{\"id\":\" \"}]", "[{\"id\":\"a\"},{}]",
    ] {
    assert_true(enrich_table(source, @jsontable.parse(text), 0, 0) is Err(_))
  }
  let duplicate : @jsontable.Table = {
    columns: ["id", "id"],
    rows: [[Text("a"), Text("b")]],
  }
  assert_true(enrich_table(source, duplicate, 0, 0) is Err(_))
  assert_true(enrich_table(duplicate, source, 0, 0) is Err(_))
  assert_true(enrich_table(source, source, -1, 0) is Err(_))
  assert_true(enrich_table(source, source, 0, 20) is Err(_))
  let wide : @jsontable.Table = {
    columns: Array::makei(500, i => "column\{i}"),
    rows: [],
  }
  assert_true(enrich_table(wide, wide, 0, 0) is Err(_))
  let many : @jsontable.Table = {
    columns: ["id"],
    rows: Array::make(200000, [Text("a")]),
  }
  let key : @jsontable.Table = { columns: ["id"], rows: [[Text("a")]], }
  assert_true(enrich_table(many, key, 0, 0) is Err(_))
}

///|
fn lookup_download_link(html : String, format : String) -> String raise {
  for part in html.split("<a download href=\"") {
    let pieces = part.split("\">").to_array()
    if pieces.length() > 1 && pieces[1].has_prefix("Export enriched " + format) {
      return office_unescape_xml(pieces[0].to_owned())
    }
  }
  fail("Missing enrichment download link")
}

///|
async test "HTTP lookup connects saved formats and downloads exact enriched records" {
  @moonlib/fsx.with_temporary_directory("desk-lookup-http-", root => {
    let book = moonsuite_books_root(root) + "/lookup"
    @fs.mkdir(book, recursive=true)
    let source = lookup_source_fixture()
    let lookup = lookup_reference_fixture()
    let source_name = "orders & 東京.csv"
    @fs.write_file(
      book + "/" + source_name,
      source.export_csv(),
      create_mode=CreateOrTruncate,
    )
    let records = lookup
      .text_rows()
      .map(row => ({ "id": row[0], "name": row[1], "tier": row[2] } : Json))
    let tsv : @leafcsv.Table = {
      rows: [lookup.columns] + lookup.text_rows(),
      delimiter: '\t',
    }
    for
      (name, data) in [
        ("customers.csv", lookup.export_csv()),
        ("customers.tsv", tsv.serialize_quoted()),
        ("customers.json", records.to_json().stringify()),
        (
          "customers.jsonl",
          records.map(record => record.stringify()).join("\n\n"),
        ),
        (
          "customers.ndjson",
          records.map(record => record.stringify()).join("\n"),
        ),
      ] {
      @fs.write_file(book + "/" + name, data, create_mode=CreateOrTruncate)
    }
    @fs.write_file(
      book + "/customers.xlsx",
      Bytes::from_array(
        @leafxlsx.create(
          [lookup.columns.map(value => @leafscene.CellValue::Text(value))] +
          lookup.rows,
          sheet_name="Customers & 東京",
        ),
      ),
      create_mode=CreateOrTruncate,
    )
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let route = @desk.workspace_json_table_url("book-lookup", source_name)
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      let (_, explorer) = @http.get(base + route)
      assert_true(explorer.text().contains("Enrich from a lookup table"))
      let (initial, initial_body) = @http.get(base + route + "&lookup=1")
      assert_eq(initial.code, 200)
      assert_true(initial_body.text().contains("Open lookup file"))
      for extension in ["csv", "tsv", "json", "jsonl", "ndjson", "xlsx"] {
        let file = "customers." + extension
        let source_bytes = @fs.read_file(book + "/" + source_name).binary()
        let lookup_bytes = @fs.read_file(book + "/" + file).binary()
        let choose = base +
          route +
          "&lookup=1&lookup_path=" +
          encode_query_value(file)
        let (chooser, chooser_body) = @http.get(choose)
        assert_eq(chooser.code, 200)
        assert_true(chooser_body.text().contains("Choose a source key"))
        let url = choose + "&source_key=customer&lookup_key=id"
        let (response, body) = @http.get(url)
        assert_eq(response.code, 200)
        let html = body.text()
        assert_true(
          html.contains(
            "4 matched · 2 unmatched source records · 1 unused lookup records",
          ),
        )
        assert_true(html.contains("orders &amp; 東京.csv"))
        assert_true(html.contains("東京&lt;&amp;&quot;"))
        assert_false(html.contains("<td>東京<&\"</td>"))
        let csv_link = lookup_download_link(html, "CSV")
        let xlsx_link = lookup_download_link(html, "XLSX")
        if extension == "xlsx" {
          assert_true(
            csv_link.contains(
              "&lookup_sheet=" + encode_query_value("Customers & 東京"),
            ),
          )
        }
        let (csv_response, csv_body) = @http.get(base + csv_link)
        assert_eq(csv_response.code, 200)
        assert_eq(
          csv_response.headers.get("content-disposition"),
          Some("attachment; filename=\"table-enriched.csv\""),
        )
        let csv = csv_body.text()
        let rows = @leafcsv.parse(csv).rows
        assert_eq(
          rows[1:].to_owned(),
          enrich_table(source, lookup, 0, 0).unwrap().table.text_rows(),
        )
        assert_eq(rows[0][1], "Source record: " + source_name)
        assert_true(rows[0][2].contains(file))
        let (xlsx_response, xlsx_body) = @http.get(base + xlsx_link)
        assert_eq(xlsx_response.code, 200)
        let xlsx = xlsx_body.binary()
        guard @moonleaf.open("enriched.xlsx", xlsx.to_fixedarray())
          is @leafscene.WorkbookDocument(workbook) else {
          fail("Expected real XLSX")
        }
        assert_eq(workbook.sheets[0].name, "Enriched table")
        let reopened = table_from_sheet(workbook.sheets[0]).unwrap()
        assert_eq([reopened.columns] + reopened.text_rows(), rows)
        assert_eq(reopened.rows[0][3], @leafscene.Text("001"))
        assert_eq(reopened.rows[5][6], @leafscene.Text("=SUM(A1)"))
        assert_eq(reopened.rows[0][1], @leafscene.Number("1"))
        let (_, reload) = @http.get(url)
        assert_eq(reload.text(), html)
        assert_eq(
          @fs.read_file(book + "/" + source_name).binary(),
          source_bytes,
        )
        assert_eq(@fs.read_file(book + "/" + file).binary(), lookup_bytes)
        if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
          @fs.write_file(
            evidence + "/lookup-" + extension + ".html",
            html,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/lookup-" + extension + ".csv",
            csv,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/lookup-" + extension + ".xlsx",
            xlsx,
            create_mode=CreateOrTruncate,
          )
        }
      }
      for
        query in [
          "&lookup_path=missing.csv", "&lookup_path=..%2Foutside.csv", "&lookup_path=customers.csv&source_key=gone&lookup_key=id",
          "&lookup_path=customers.csv&source_key=customer", "&lookup_path=customers.xlsx&lookup_sheet=missing",
        ] {
        let (bad, bad_body) = @http.get(base + route + "&lookup=1" + query)
        assert_eq(bad.code, 400)
        assert_true(bad_body.text().contains("Open lookup file"))
      }
      for format in ["csv", "xlsx", "unknown"] {
        let route = @desk.workspace_json_table_url(
          "book-lookup",
          source_name,
          format~,
        )
        let (bad, _) = @http.get(
          base + route + "&lookup=1&lookup_path=customers.csv",
        )
        assert_eq(bad.code, 400)
      }
    })
  })
}

///|
async test "lookup worksheets survive reload and saved reordering with recoverable key errors" {
  @moonlib/fsx.with_temporary_directory("desk-lookup-sheets-", root => {
    let book = moonsuite_books_root(root) + "/sheets"
    @fs.mkdir(book, recursive=true)
    let bytes = Bytes::from_array(worksheet_explorer_fixture())
    for file in ["source.xlsx", "lookup.xlsx"] {
      @fs.write_file(book + "/" + file, bytes, create_mode=CreateOrTruncate)
    }
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let route = @desk.workspace_json_table_url("book-sheets", "source.xlsx") +
      "&lookup=1&lookup_path=lookup.xlsx"
    let selected = "&sheet=" +
      encode_query_value("Sales & 東京") +
      "&lookup_sheet=" +
      encode_query_value("Sales & 東京")
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      let (_, chooser) = @http.get(base + route + selected)
      let chooser_html = chooser.text()
      assert_true(chooser_html.contains("Source worksheet"))
      assert_true(chooser_html.contains("Lookup worksheet"))
      let forms = chooser_html.split("</form>").to_array()
      assert_false(forms[0].contains("name=\"source_key\""))
      assert_false(forms[0].contains("name=\"lookup_sheet\""))
      assert_false(forms[1].contains("name=\"source_key\""))
      let url = base +
        route +
        selected +
        "&source_key=customer&lookup_key=customer"
      let (response, body) = @http.get(url)
      assert_eq(response.code, 200)
      let html = body.text()
      assert_true(
        html.contains(
          "5 matched · 0 unmatched source records · 0 unused lookup records",
        ),
      )
      let download = lookup_download_link(html, "CSV")
      assert_true(download.contains(selected))
      let (bad, bad_body) = @http.get(
        base + route + selected + "&source_key=customer&lookup_key=region",
      )
      assert_eq(bad.code, 400)
      let bad_html = bad_body.text()
      assert_true(bad_html.contains("Lookup has duplicate key"))
      assert_true(bad_html.contains("Enrich table"))
      assert_false(bad_html.contains("Export enriched CSV"))
      // Reordering lookup columns cannot silently change the selected key.
      let changed = explorer_sample()
      changed.rows[0][2] = @leafscene.Number("777")
      let reordered : @jsontable.Table = {
        columns: [
          changed.columns[2],
          changed.columns[0],
          changed.columns[3],
          changed.columns[1],
        ],
        rows: changed.rows.map(row => [row[2], row[0], row[3], row[1]]),
      }
      @fs.write_file(
        book + "/lookup.xlsx",
        Bytes::from_array(
          @leafxlsx.create(
            [reordered.columns.map(value => @leafscene.CellValue::Text(value))] +
            reordered.rows,
            sheet_name="Sales & 東京",
          ),
        ),
        create_mode=CreateOrTruncate,
      )
      let (edited_response, edited_body) = @http.get(base + download)
      assert_eq(edited_response.code, 200)
      let edited = @leafcsv.parse(edited_body.text()).rows
      assert_eq(edited.length(), 6)
      assert_eq(edited[0][7], "Lookup: amount")
      assert_eq(edited[1][7], "777")
      assert_true(
        edited[0][1].contains("source.xlsx [worksheet: Sales & 東京]"),
      )
      assert_true(
        edited[0][2].contains("lookup.xlsx [worksheet: Sales & 東京]"),
      )
      let (recovered, recovered_body) = @http.get(url)
      assert_eq(recovered.code, 200)
      assert_true(
        recovered_body
        .text()
        .contains("5 matched · 0 unmatched source records"),
      )
      assert_eq(@fs.read_file(book + "/source.xlsx").binary(), bytes)
      // A new valid lookup file opens without stale keys/sheet and an empty
      // saved source with headers produces a real headers-only download.
      @fs.write_file(book + "/empty.csv", "id\n", create_mode=CreateOrTruncate)
      let empty_route = @desk.workspace_json_table_url(
          "book-sheets", "empty.csv",
        ) +
        "&lookup=1&lookup_path=empty.csv&source_key=id&lookup_key=id"
      let (empty_response, empty_body) = @http.get(base + empty_route)
      assert_eq(empty_response.code, 200)
      let empty_html = empty_body.text()
      assert_true(empty_html.contains("No source records"))
      let (_, csv) = @http.get(base + lookup_download_link(empty_html, "CSV"))
      assert_eq(@leafcsv.parse(csv.text()).rows.length(), 1)
      let bad_format = @desk.workspace_json_table_url(
          "book-sheets",
          "empty.csv",
          format="bad",
        ) +
        "&lookup=1&lookup_path=empty.csv&source_key=id&lookup_key=id"
      let (bad_format_response, _) = @http.get(base + bad_format)
      assert_eq(bad_format_response.code, 400)
      if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
        @fs.write_file(
          evidence + "/lookup-worksheets.html",
          html,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/lookup-duplicate-error.html",
          bad_html,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/lookup-empty.html",
          empty_html,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/lookup-workbook-source.xlsx",
          bytes,
          create_mode=CreateOrTruncate,
        )
      }
    })
  })
}
