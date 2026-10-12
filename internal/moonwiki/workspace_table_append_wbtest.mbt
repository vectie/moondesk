///|
fn append_source(
  table : @jsontable.Table,
  path? : String = "first.csv",
  sheet? : String,
) -> WorkspaceTableSource {
  {
    path,
    table,
    sheet_names: sheet.map(name => [name]).unwrap_or([]),
    selected_sheet: sheet,
  }
}

///|
fn append_first_fixture() -> @jsontable.Table raise {
  @jsontable.parse(
    "[{\"id\":\"001\",\"amount\":10,\"Source path\":\"user field\"},{\"id\":\"=1+1\",\"amount\":0,\"Source path\":\"first\"},{\"id\":\"001\",\"amount\":10,\"Source path\":\"user field\"}]",
  )
}

///|
fn append_second_fixture() -> @jsontable.Table raise {
  @jsontable.parse(
    "[{\"amount\":5,\"id\":\"東京<&\\\"\",\"note\":\"line,\\nnext\"},{\"amount\":7,\"id\":\"001\",\"note\":\"=SUM(A1)\"}]",
  )
}

///|
test "append aligns reordered exact headers preserves repeated rows and namespaced provenance" {
  let first = append_source(append_first_fixture())
  let second = append_source(
    append_second_fixture(),
    path="second.xlsx",
    sheet="Sales & 東京",
  )
  let report = append_tables(first, second).unwrap()
  assert_eq(report.shared_columns, ["id", "amount"])
  assert_eq(report.first_only, ["Source path"])
  assert_eq(report.second_only, ["note"])
  assert_eq(report.table.columns, [
    "Source path", "Source worksheet", "Source record", "Field: id", "Field: amount",
    "Field: Source path", "Field: note",
  ])
  assert_eq(report.table.text_rows(), [
    ["first.csv", "", "1", "001", "10", "user field", ""],
    ["first.csv", "", "2", "=1+1", "0", "first", ""],
    ["first.csv", "", "3", "001", "10", "user field", ""],
    ["second.xlsx", "Sales & 東京", "1", "東京<&\"", "5", "", "line,\nnext"],
    ["second.xlsx", "Sales & 東京", "2", "001", "7", "", "=SUM(A1)"],
  ])
  assert_eq(report.table.rows[0][2], @leafscene.Number("1"))
  assert_eq(report.table.rows[0][3], @leafscene.Text("001"))
  assert_eq(report.table.rows[1][3], @leafscene.Text("=1+1"))
  assert_eq(report.table.rows[4][6], @leafscene.Text("=SUM(A1)"))
  assert_eq(report.table.rows[0][6], @leafscene.Empty)
  assert_eq(first.table, append_first_fixture())
  assert_eq(second.table, append_second_fixture())
  assert_eq(
    @leafcsv.parse(report.table.export_csv()).rows,
    [report.table.columns] + report.table.text_rows(),
  )
}

///|
test "append preserves exact header spelling accepts empty partitions and identical source rows" {
  let left = append_source(
    @jsontable.parse("[{\"ID\":\"x\",\"id\":\"y\",\" id\":\"z\"}]"),
  )
  let right = append_source(
    @jsontable.parse("[{\"id\":\"b\",\"ID \":\"c\"}]"),
    path="right.json",
  )
  let report = append_tables(left, right).unwrap()
  assert_eq(report.table.columns, [
    "Source path", "Source worksheet", "Source record", "Field: ID", "Field: id",
    "Field:  id", "Field: ID ",
  ])
  assert_eq(report.shared_columns, ["id"])
  assert_eq(report.table.text_rows()[1], [
    "right.json", "", "1", "", "b", "", "c",
  ])
  let empty = append_source({ columns: ["extra"], rows: [], })
  let combined = append_tables(empty, right).unwrap()
  assert_eq(combined.table.rows.length(), 1)
  assert_eq(combined.table.text_rows()[0], ["right.json", "", "1", "", "b", "c"])
  assert_eq(append_tables(empty, empty).unwrap().table.rows.length(), 0)
  let blank = append_source({ columns: [], rows: [], })
  assert_eq(append_tables(blank, blank).unwrap().table.columns.length(), 3)
  assert_eq(append_tables(left, left).unwrap().table.rows.length(), 2)
}

///|
test "append refuses ambiguous headers and bounded output overflows" {
  let duplicate = append_source({
    columns: ["id", "id"],
    rows: [[Text("a"), Text("b")]],
  })
  let empty = append_source({ columns: [], rows: [], })
  assert_true(
    append_tables(duplicate, empty) is Err(message) &&
    message.contains("First table has duplicate"),
  )
  assert_true(
    append_tables(empty, duplicate) is Err(message) &&
    message.contains("Second table has duplicate"),
  )
  let wide = append_source({
    columns: Array::makei(998, i => "c\{i}"),
    rows: [],
  })
  assert_true(append_tables(wide, empty) is Err(_))
  let rows = append_source({
    columns: ["id"],
    rows: Array::make(50000, [Text("x")]),
  })
  assert_true(append_tables(rows, rows) is Err(_))
  let dense = append_source({
    columns: Array::makei(100, i => "c\{i}"),
    rows: Array::make(5000, Array::make(100, @leafscene.Text("x"))),
  })
  assert_true(append_tables(dense, dense) is Err(_))
}

///|
fn append_download_link(html : String, format : String) -> String raise {
  for part in html.split("<a download href=\"") {
    let pieces = part.split("\">").to_array()
    if pieces.length() > 1 && pieces[1].has_prefix("Export combined " + format) {
      return office_unescape_xml(pieces[0].to_owned())
    }
  }
  fail("Missing combined-table download link")
}

///|
async test "HTTP append combines all supported saved formats exports real files and preserves sources" {
  @moonlib/fsx.with_temporary_directory("desk-append-http-", root => {
    let book = moonsuite_books_root(root) + "/append"
    @fs.mkdir(book, recursive=true)
    let first = append_first_fixture()
    let second = append_second_fixture()
    let first_name = "first & 東京.csv"
    @fs.write_file(
      book + "/" + first_name,
      first.export_csv(),
      create_mode=CreateOrTruncate,
    )
    let records = second
      .text_rows()
      .map(row => ({ "amount": row[0], "id": row[1], "note": row[2] } : Json))
    for
      (name, data) in [
        ("second.csv", second.export_csv()),
        (
          "second.tsv",
          (
            { rows: [second.columns] + second.text_rows(), delimiter: '\t', } :
            @leafcsv.Table).serialize_quoted(),
        ),
        ("second.json", Json::array(records).stringify()),
        ("second.jsonl", records.map(value => value.stringify()).join("\n")),
        ("second.ndjson", records.map(value => value.stringify()).join("\n")),
      ] {
      @fs.write_file(book + "/" + name, data, create_mode=CreateOrTruncate)
    }
    @fs.write_file(
      book + "/second.xlsx",
      Bytes::from_array(
        @leafxlsx.create(
          [second.columns.map(value => @leafscene.CellValue::Text(value))] +
          second.rows,
          sheet_name="Next & 東京",
        ),
      ),
      create_mode=CreateOrTruncate,
    )
    let first_bytes = @fs.read_file(book + "/" + first_name).binary()
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let route = @desk.workspace_json_table_url("book-append", first_name)
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      let (_, explorer) = @http.get(base + route)
      assert_true(explorer.text().contains("Combine rows with another table"))
      let (initial, initial_body) = @http.get(base + route + "&append=1")
      assert_eq(initial.code, 200)
      assert_true(initial_body.text().contains("Choose the second table"))
      for extension in ["csv", "tsv", "json", "jsonl", "ndjson", "xlsx"] {
        let file = "second." + extension
        let original = @fs.read_file(book + "/" + file).binary()
        let url = base +
          route +
          "&append=1&append_path=" +
          encode_query_value(file) +
          "&contains=never&text_column=0"
        let (response, body) = @http.get(url)
        assert_eq(response.code, 200)
        let html = body.text()
        assert_true(html.contains("5 combined records · 3 first · 2 second"))
        assert_true(html.contains("Shared columns (2): id, amount"))
        assert_true(html.contains("first &amp; 東京.csv"))
        assert_true(html.contains("東京&lt;&amp;&quot;"))
        assert_false(html.contains("<td>東京<&\"</td>"))
        let csv_link = append_download_link(html, "CSV")
        let xlsx_link = append_download_link(html, "XLSX")
        let expected = append_tables(
            append_source(first, path=first_name),
            append_source(
              second,
              path=file,
              sheet?=if extension == "xlsx" {
                Some("Next & 東京")
              } else {
                None
              },
            ),
          ).unwrap().table
        if extension == "xlsx" {
          assert_true(
            csv_link.contains(
              "&append_sheet=" + encode_query_value("Next & 東京"),
            ),
          )
        }
        let (csv_response, csv_body) = @http.get(base + csv_link)
        assert_eq(csv_response.code, 200)
        assert_eq(
          csv_response.headers.get("content-disposition"),
          Some("attachment; filename=\"table-combined.csv\""),
        )
        let csv = csv_body.text()
        let rows = @leafcsv.parse(csv).rows
        assert_eq(rows, [expected.columns] + expected.text_rows())
        let (xlsx_response, xlsx_body) = @http.get(base + xlsx_link)
        assert_eq(xlsx_response.code, 200)
        let xlsx = xlsx_body.binary()
        guard @moonleaf.open("combined.xlsx", xlsx.to_fixedarray())
          is @leafscene.WorkbookDocument(workbook) else {
          fail("Expected actual XLSX")
        }
        assert_eq(workbook.sheets[0].name, "Combined table")
        let reopened = table_from_sheet(workbook.sheets[0]).unwrap()
        assert_eq([reopened.columns] + reopened.text_rows(), rows)
        assert_eq(reopened.rows[0][3], @leafscene.Text("001"))
        assert_eq(reopened.rows[1][3], @leafscene.Text("=1+1"))
        assert_eq(reopened.rows[4][6], @leafscene.Text("=SUM(A1)"))
        assert_eq(reopened.rows[0][2], @leafscene.Number("1"))
        let (_, reload) = @http.get(url)
        assert_eq(reload.text(), html)
        assert_eq(@fs.read_file(book + "/" + first_name).binary(), first_bytes)
        assert_eq(@fs.read_file(book + "/" + file).binary(), original)
        if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
          @fs.write_file(
            evidence + "/append-" + extension + ".html",
            html,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/append-" + extension + ".csv",
            csv,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/append-" + extension + ".xlsx",
            xlsx,
            create_mode=CreateOrTruncate,
          )
        }
      }
      for
        query in [
          "&append_path=missing.csv", "&append_path=..%2Foutside.csv", "&append_path=second.xlsx&append_sheet=gone",
          "&append_path=second.csv&append_sheet=wrong",
        ] {
        let (bad, body) = @http.get(base + route + "&append=1" + query)
        assert_eq(bad.code, 400)
        assert_true(body.text().contains("Combine tables"))
      }
      for format in ["csv", "xlsx", "bad"] {
        let route = @desk.workspace_json_table_url(
          "book-append",
          first_name,
          format~,
        )
        let (incomplete, _) = @http.get(base + route + "&append=1")
        assert_eq(incomplete.code, 400)
      }
      let (bad_format, _) = @http.get(
        base +
        @desk.workspace_json_table_url("book-append", first_name, format="bad") +
        "&append=1&append_path=second.csv",
      )
      assert_eq(bad_format.code, 400)
    })
  })
}

///|
async test "append retains named worksheet context recovers schema errors and reloads saved changes" {
  @moonlib/fsx.with_temporary_directory("desk-append-recovery-", root => {
    let book = moonsuite_books_root(root) + "/sheets"
    @fs.mkdir(book, recursive=true)
    let original = Bytes::from_array(worksheet_explorer_fixture())
    @fs.write_file(book + "/data.xlsx", original, create_mode=CreateOrTruncate)
    @fs.write_file(
      book + "/first.csv",
      "id,amount\n001,10\n",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(
      book + "/second.csv",
      "id,id\na,b\n",
      create_mode=CreateOrTruncate,
    )
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let route = @desk.workspace_json_table_url("book-sheets", "data.xlsx") +
      "&append=1&append_path=data.xlsx"
    let selected = "&append_sheet=" + encode_query_value("Sales & 東京")
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      let (response, body) = @http.get(base + route + selected)
      assert_eq(response.code, 200)
      let html = body.text()
      assert_true(html.contains("6 combined records · 1 first · 5 second"))
      assert_true(html.contains("First worksheet"))
      assert_true(html.contains("Second worksheet"))
      let forms = html.split("</form>").to_array()
      assert_true(forms[0].contains("name=\"sheet\" value=\"Overview\""))
      assert_false(forms[0].contains("name=\"append_sheet\""))
      assert_true(
        forms[1].contains("<option value=\"Sales &amp; 東京\" selected>"),
      )
      let download = append_download_link(html, "CSV")
      assert_true(download.contains("&sheet=Overview"))
      assert_true(download.contains(selected))
      let (_, csv_body) = @http.get(base + download)
      let csv = csv_body.text()
      let rows = @leafcsv.parse(csv).rows
      assert_eq(rows.length(), 7)
      assert_eq(rows[1][1], "Overview")
      assert_eq(rows[2][1], "Sales & 東京")
      assert_eq(rows[1][2], "1")
      assert_eq(rows[2][2], "1")
      assert_eq(rows[6][2], "5")
      assert_eq(@fs.read_file(book + "/data.xlsx").binary(), original)
      @fs.write_file(
        book + "/data.xlsx",
        Bytes::from_array(
          worksheet_explorer_fixture(names=[
            "Empty", "Sales & 東京", "Overview",
          ]),
        ),
        create_mode=CreateOrTruncate,
      )
      let (reordered, reordered_body) = @http.get(base + download)
      assert_eq(reordered.code, 200)
      assert_eq(reordered_body.text(), csv)
      let (_, empty_body) = @http.get(
        base + route + "&sheet=Empty&append_sheet=Empty",
      )
      let empty_html = empty_body.text()
      assert_true(empty_html.contains("No saved records"))
      let (_, empty_csv) = @http.get(
        base + append_download_link(empty_html, "CSV"),
      )
      assert_eq(@leafcsv.parse(empty_csv.text()).rows, [
        ["Source path", "Source worksheet", "Source record"],
      ])
      @fs.write_file(
        book + "/data.xlsx",
        Bytes::from_array(worksheet_explorer_fixture(names=["Overview"])),
        create_mode=CreateOrTruncate,
      )
      let (missing, missing_body) = @http.get(base + download)
      assert_eq(missing.code, 400)
      assert_true(missing_body.text().contains("missing or ambiguous"))
      let (recover, recover_body) = @http.get(base + route + "&sheet=Overview")
      assert_eq(recover.code, 200)
      assert_true(
        recover_body
        .text()
        .contains("2 combined records · 1 first · 1 second"),
      )
      let csv_route = @desk.workspace_json_table_url("book-sheets", "first.csv") +
        "&append=1&append_path=second.csv"
      let (bad, bad_body) = @http.get(base + csv_route)
      assert_eq(bad.code, 400)
      let bad_html = bad_body.text()
      assert_true(
        bad_html.contains("Second table has duplicate column name: id"),
      )
      assert_true(bad_html.contains("value=\"second.csv\""))
      assert_false(bad_html.contains("Export combined CSV"))
      @fs.write_file(
        book + "/second.csv",
        "amount,id,new field\n777,002,added\n",
        create_mode=CreateOrTruncate,
      )
      let (fixed, fixed_body) = @http.get(base + csv_route)
      assert_eq(fixed.code, 200)
      let fixed_html = fixed_body.text()
      let fixed_link = append_download_link(fixed_html, "CSV")
      let (_, fixed_csv) = @http.get(base + fixed_link)
      assert_eq(@leafcsv.parse(fixed_csv.text()).rows, [
        [
          "Source path", "Source worksheet", "Source record", "Field: id", "Field: amount",
          "Field: new field",
        ],
        ["first.csv", "", "1", "001", "10", ""],
        ["second.csv", "", "1", "002", "777", "added"],
      ])
      // Existing download URLs read the latest saved schema and values.
      @fs.write_file(
        book + "/second.csv",
        "new field,id,amount\nchanged,003,888\n",
        create_mode=CreateOrTruncate,
      )
      let (_, latest_csv) = @http.get(base + fixed_link)
      assert_eq(@leafcsv.parse(latest_csv.text()).rows[2], [
        "second.csv", "", "1", "003", "888", "changed",
      ])
      assert_eq(
        @fs.read_file(book + "/first.csv").text(),
        "id,amount\n001,10\n",
      )
      if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
        @fs.write_file(
          evidence + "/append-worksheets.html",
          html,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/append-worksheets.csv",
          csv,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/append-duplicate-error.html",
          bad_html,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/append-empty.html",
          empty_html,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/append-workbook-source.xlsx",
          original,
          create_mode=CreateOrTruncate,
        )
      }
    })
  })
}
