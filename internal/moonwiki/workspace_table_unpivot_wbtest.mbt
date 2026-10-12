///|
fn unpivot_fixture() -> @jsontable.Table {
  {
    columns: ["id", "Jan & 東京", "Feb"],
    rows: [
      [Text("001"), Text("=1+1"), Empty],
      [Text("<b>"), Text("line,\nnext"), Text("0")],
    ],
  }
}

///|
fn unpivot_source(table : @jsontable.Table) -> WorkspaceTableSource {
  { path: "wide.csv", table, sheet_names: [], selected_sheet: None, }
}

///|
test "unpivot preserves identity blanks literal values and source order" {
  let source = unpivot_source(unpivot_fixture())
  let table = unpivot_table(source, ["Feb", "Jan & 東京"]).unwrap()
  assert_eq(table.columns, [
    "Source path", "Source worksheet", "Source record", "Field: id", "Measurement",
    "Value",
  ])
  assert_eq(table.text_rows(), [
    ["wide.csv", "", "1", "001", "Jan & 東京", "=1+1"],
    ["wide.csv", "", "1", "001", "Feb", ""],
    ["wide.csv", "", "2", "<b>", "Jan & 東京", "line,\nnext"],
    ["wide.csv", "", "2", "<b>", "Feb", "0"],
  ])
  assert_eq(table.rows[0][2], @leafscene.Number("1"))
  assert_eq(table.rows[0][5], @leafscene.Text("=1+1"))
  assert_eq(source.table, unpivot_fixture())
  assert_eq(
    unpivot_table(source, source.table.columns).unwrap().rows.length(),
    6,
  )
  assert_eq(
    unpivot_table(unpivot_source({ columns: ["x"], rows: [], }), ["x"]).unwrap().rows.length(),
    0,
  )
  let reordered = unpivot_source({
    columns: ["Feb", "id", "Jan & 東京"],
    rows: [[Text("0"), Text("001"), Text("x")]],
  })
  assert_eq(
    unpivot_table(reordered, ["Jan & 東京"]).unwrap().text_rows()[0],
    ["wide.csv", "", "1", "0", "001", "Jan & 東京", "x"],
  )
  assert_eq(
    unpivot_measures("/?measure=Jan+%26+%E6%9D%B1%E4%BA%AC&measure=Feb"),
    ["Jan & 東京", "Feb"],
  )
}

///|
test "unpivot validates selection ambiguity and expansion before allocation" {
  let source = unpivot_source(unpivot_fixture())
  assert_true(unpivot_table(source, []) is Err(_))
  assert_true(unpivot_table(source, ["missing"]) is Err(_))
  assert_true(unpivot_table(source, ["Feb", "Feb"]) is Err(_))
  assert_true(
    unpivot_table(unpivot_source({ columns: ["x", "x"], rows: [], }), ["x"])
    is Err(_),
  )
  let tall = unpivot_source({
    columns: ["x", "y"],
    rows: Array::make(50000, [Text("a"), Text("b")]),
  })
  assert_true(unpivot_table(tall, ["x", "y"]) is Err(_))
  let wide = unpivot_source({
    columns: Array::makei(1000, i => i.to_string()),
    rows: [],
  })
  assert_true(unpivot_table(wide, ["0"]) is Err(_))
  let dense = unpivot_source({
    columns: Array::makei(100, i => i.to_string()),
    rows: Array::make(6000, Array::make(100, Text("x"))),
  })
  assert_true(unpivot_table(dense, ["0", "1"]) is Err(_))
}

///|
fn unpivot_link(html : String, format : String) -> String raise {
  for part in html.split("<a download href=\"") {
    let pieces = part.split("\">").to_array()
    if pieces.length() > 1 && pieces[1].has_prefix("Export reshaped " + format) {
      return office_unescape_xml(pieces[0].to_owned())
    }
  }
  fail("Missing reshape download link")
}

///|
async test "unpivot HTTP all formats real downloads reload errors and unchanged sources" {
  @moonlib/fsx.with_temporary_directory("desk-unpivot-", root => {
    let book = moonsuite_books_root(root) + "/reshape"
    @fs.mkdir(book, recursive=true)
    let table = unpivot_fixture()
    let records = table
      .text_rows()
      .map(row => {
        ({ "id": row[0], "Jan & 東京": row[1], "Feb": row[2] } : Json)
      })
    for
      (name, text) in [
        ("wide.csv", table.export_csv()),
        (
          "wide.tsv",
          (
            { rows: [table.columns] + table.text_rows(), delimiter: '\t', } :
            @leafcsv.Table).serialize_quoted(),
        ),
        ("wide.json", Json::array(records).stringify()),
        ("wide.jsonl", records.map(value => value.stringify()).join("\n")),
        ("wide.ndjson", records.map(value => value.stringify()).join("\n")),
      ] {
      @fs.write_file(book + "/" + name, text, create_mode=CreateOrTruncate)
    }
    @fs.write_file(
      book + "/wide.xlsx",
      Bytes::from_array(
        @leafxlsx.create(
          [table.columns.map(name => @leafscene.Text(name))] + table.rows,
          sheet_name="Months & 東京",
        ),
      ),
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
      for extension in ["csv", "tsv", "json", "jsonl", "ndjson", "xlsx"] {
        let file = "wide." + extension
        let before = @fs.read_file(book + "/" + file).binary()
        let route = base + @desk.workspace_json_table_url("book-reshape", file)
        let (_, explorer) = @http.get(route)
        assert_true(explorer.text().contains("Reshape columns into rows"))
        let (initial, chooser) = @http.get(route + "&unpivot=1")
        assert_eq(initial.code, 200)
        assert_true(chooser.text().contains("Choose measurement columns"))
        let request = route +
          "&unpivot=1&measure=" +
          encode_query_value("Jan & 東京") +
          "&measure=Feb&contains=never&text_column=0"
        let (response, body) = @http.get(request)
        assert_eq(response.code, 200)
        let html = body.text()
        assert_true(html.contains("4 reshaped records from 2 source records"))
        assert_true(html.contains("&lt;b&gt;"))
        let csv_link = unpivot_link(html, "CSV")
        if extension == "xlsx" {
          assert_true(
            csv_link.contains("&sheet=" + encode_query_value("Months & 東京")),
          )
        }
        let (csv_response, csv_body) = @http.get(base + csv_link)
        assert_eq(csv_response.code, 200)
        assert_eq(
          csv_response.headers.get("content-disposition"),
          Some("attachment; filename=\"table-reshaped.csv\""),
        )
        let rows = @leafcsv.parse(csv_body.text()).rows
        assert_eq(rows.length(), 5)
        assert_eq(rows[1][3], "001")
        assert_eq(rows[1][5], "=1+1")
        assert_eq(rows[2][5], "")
        let (xlsx_response, xlsx_body) = @http.get(
          base + unpivot_link(html, "XLSX"),
        )
        assert_eq(xlsx_response.code, 200)
        let xlsx = xlsx_body.binary()
        guard @moonleaf.open("reshaped.xlsx", xlsx.to_fixedarray())
          is @leafscene.WorkbookDocument(workbook) else {
          fail("Expected real XLSX")
        }
        let reopened = table_from_sheet(workbook.sheets[0]).unwrap()
        assert_eq([reopened.columns] + reopened.text_rows(), rows)
        assert_eq(reopened.rows[0][3], @leafscene.Text("001"))
        assert_eq(reopened.rows[0][5], @leafscene.Text("=1+1"))
        let (_, reload) = @http.get(request)
        assert_eq(reload.text(), html)
        assert_eq(@fs.read_file(book + "/" + file).binary(), before)
        let (bad, _) = @http.get(route + "&unpivot=1&measure=missing")
        assert_eq(bad.code, 400)
        let (empty, _) = @http.get(
          base +
          @desk.workspace_json_table_url("book-reshape", file, format="csv") +
          "&unpivot=1",
        )
        assert_eq(empty.code, 400)
        if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
          @fs.write_file(
            evidence + "/unpivot-" + extension + ".html",
            html,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/unpivot-" + extension + ".csv",
            csv_body.text(),
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/unpivot-" + extension + ".xlsx",
            xlsx,
            create_mode=CreateOrTruncate,
          )
        }
      }
    })
  })
}

///|
async test "unpivot named worksheet survives reorder and reports changed schema with recovery" {
  @moonlib/fsx.with_temporary_directory("desk-unpivot-sheets-", root => {
    let book = moonsuite_books_root(root) + "/reshape"
    @fs.mkdir(book, recursive=true)
    let file = book + "/sheets.xlsx"
    @fs.write_file(
      file,
      Bytes::from_array(worksheet_explorer_fixture()),
      create_mode=CreateOrTruncate,
    )
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let route = base +
      @desk.workspace_json_table_url("book-reshape", "sheets.xlsx") +
      "&unpivot=1"
    let selected = route +
      "&sheet=" +
      encode_query_value("Sales & 東京") +
      "&measure=amount"
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      let (response, body) = @http.get(selected)
      assert_eq(response.code, 200)
      assert_true(
        body.text().contains("5 reshaped records from 5 source records"),
      )
      let download = base + unpivot_link(body.text(), "CSV")
      let (_, original) = @http.get(download)
      @fs.write_file(
        file,
        Bytes::from_array(
          worksheet_explorer_fixture(names=[
            "Sales & 東京", "Empty", "Overview",
          ]),
        ),
        create_mode=CreateOrTruncate,
      )
      let (_, reordered) = @http.get(download)
      assert_eq(original.text(), reordered.text())
      let (other, _) = @http.get(route + "&sheet=Overview&measure=amount")
      assert_eq(other.code, 400)
      let (recovered, _) = @http.get(
        base +
        @desk.workspace_json_table_url(
          "book-reshape",
          "sheets.xlsx",
          format="csv",
        ) +
        "&unpivot=1&sheet=Overview&measure=summary",
      )
      assert_eq(recovered.code, 200)
      @fs.write_file(
        file,
        Bytes::from_array(worksheet_explorer_fixture(names=["Overview"])),
        create_mode=CreateOrTruncate,
      )
      let (missing, _) = @http.get(download)
      assert_eq(missing.code, 400)
      let csv = book + "/wide.csv"
      @fs.write_file(csv, "id,Jan,Jan\nx,1,2\n", create_mode=CreateOrTruncate)
      let csv_route = base +
        @desk.workspace_json_table_url("book-reshape", "wide.csv") +
        "&unpivot=1&measure=Jan"
      let (duplicate, duplicate_body) = @http.get(csv_route)
      assert_eq(duplicate.code, 400)
      assert_true(duplicate_body.text().contains("Duplicate source header"))
      @fs.write_file(csv, "id,Jan,Feb\nx,1,2\n", create_mode=CreateOrTruncate)
      let (fixed, _) = @http.get(csv_route)
      assert_eq(fixed.code, 200)
      @fs.write_file(csv, "id,Jan,Feb\n", create_mode=CreateOrTruncate)
      let (empty, headers) = @http.get(
        base +
        @desk.workspace_json_table_url("book-reshape", "wide.csv", format="csv") +
        "&unpivot=1&measure=Jan",
      )
      assert_eq(empty.code, 200)
      assert_eq(@leafcsv.parse(headers.text()).rows.length(), 1)
      if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
        @fs.write_file(
          evidence + "/unpivot-selected-sheet.html",
          body.text(),
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/unpivot-selected-sheet.csv",
          original.text(),
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/unpivot-duplicate-error.html",
          duplicate_body.text(),
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/unpivot-empty.csv",
          headers.text(),
          create_mode=CreateOrTruncate,
        )
      }
    })
  })
}
