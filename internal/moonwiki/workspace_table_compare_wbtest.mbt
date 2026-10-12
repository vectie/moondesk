///|
fn comparison_before_fixture() -> @jsontable.Table raise {
  @jsontable.parse(
    (
      #|[{"id":"001","name":"Acme, Inc.","amount":10},{"id":"東京<&\"","name":"keep","amount":20},{"id":"gone","name":"removed","amount":30}]
    ),
  )
}

///|
fn comparison_after_fixture() -> @jsontable.Table raise {
  @jsontable.parse(
    (
      #|[{"record":"東京<&\"","amount":"20","name":"keep"},{"record":"001","amount":12.5,"name":"Acme, Inc."},{"record":"=1+1","amount":0,"name":"new\nline"}]
    ),
  )
}

///|
test "keyed table comparison ignores record and column order and keeps exact text" {
  let before = comparison_before_fixture()
  let after = comparison_after_fixture()
  let report = compare_tables(before, after, 0, 0).unwrap()
  assert_eq(
    (report.added, report.removed, report.changed, report.unchanged),
    (1, 1, 1, 1),
  )
  assert_eq(report.differences.columns, [
    "Change", "Key", "Before record", "After record", "Changed columns", "Before: name",
    "After: name", "Before: amount", "After: amount",
  ])
  assert_eq(report.differences.text_rows(), [
    [
      "Changed", "001", "1", "2", "amount", "Acme, Inc.", "Acme, Inc.", "10", "12.5",
    ],
    ["Removed", "gone", "3", "", "name, amount", "removed", "", "30", ""],
    ["Added", "=1+1", "", "3", "name, amount", "", "new\nline", "", "0"],
  ])
  assert_eq(report.differences.rows[0][1], @leafscene.Text("001"))
  assert_eq(report.differences.rows[2][1], @leafscene.Text("=1+1"))
  assert_eq(report.differences.rows[0][2], @leafscene.Number("1"))
  assert_eq(
    @leafcsv.parse(report.differences.export_csv()).rows,
    [report.differences.columns] + report.differences.text_rows(),
  )
  guard @moonleaf.open("diff.xlsx", report.differences.export_xlsx())
    is @leafscene.WorkbookDocument(workbook) else {
    fail("expected comparison XLSX")
  }
  assert_eq(table_from_sheet(workbook.sheets[0]).unwrap(), report.differences)
  assert_eq(
    compare_tables(before, before, 0, 0).unwrap().differences.rows.length(),
    0,
  )
}

///|
test "table comparison exposes schema changes blank values and key-only additions" {
  let before = @jsontable.parse("[{\"id\":\"a\",\"old\":\"\",\"same\":1}]")
  let after = @jsontable.parse("[{\"key\":\"a\",\"new\":\"\",\"same\":1}]")
  let report = compare_tables(before, after, 0, 0).unwrap()
  assert_eq(report.changed, 1)
  assert_eq(report.added_columns, ["new"])
  assert_eq(report.removed_columns, ["old"])
  assert_eq(report.differences.text_rows()[0][4], "old, new")
  assert_eq(report.differences.rows[0][5], @leafscene.Text(""))
  assert_eq(report.differences.rows[0][6], @leafscene.Empty)
  let keys = @jsontable.parse("[{\"id\":\"a\"},{\"id\":\"b\"}]")
  let empty : @jsontable.Table = { columns: ["id"], rows: [], }
  let additions = compare_tables(empty, keys, 0, 0).unwrap()
  assert_eq((additions.added, additions.changed), (2, 0))
  assert_eq(additions.differences.text_rows(), [
    ["Added", "a", "", "1", ""],
    ["Added", "b", "", "2", ""],
  ])
  assert_eq(compare_tables(keys, empty, 0, 0).unwrap().removed, 2)
  assert_eq(
    compare_tables(empty, empty, 0, 0).unwrap().differences.rows.length(),
    0,
  )
  // Exact keys do not coerce leading zeroes, trim or case-fold.
  let other = @jsontable.parse(
    "[{\"id\":\"A\"},{\"id\":\" a\"},{\"id\":\"01\"},{\"id\":\"1\"}]",
  )
  assert_eq(compare_tables(keys, other, 0, 0).unwrap().added, 4)
}

///|
test "comparison rejects ambiguous keys headers and oversized projection" {
  let valid = comparison_before_fixture()
  for
    bad in [
      @jsontable.parse("[{\"id\":\"a\"},{\"id\":\"a\"}]"),
      @jsontable.parse("[{\"id\":\" \"}]"),
      @jsontable.parse("[{\"id\":\"\"}]"),
      @jsontable.parse("[{\"id\":\"a\"},{\"name\":\"missing key\"}]"),
    ] {
    assert_true(compare_tables(valid, bad, 0, 0) is Err(_))
    assert_true(compare_tables(bad, valid, 0, 0) is Err(_))
  }
  let duplicate : @jsontable.Table = {
    columns: ["id", "id"],
    rows: [[Text("a"), Text("b")]],
  }
  assert_true(compare_tables(duplicate, valid, 0, 0) is Err(_))
  assert_true(compare_tables(valid, duplicate, 0, 0) is Err(_))
  assert_true(compare_tables(valid, valid, -1, 0) is Err(_))
  assert_true(compare_tables(valid, valid, 0, 90) is Err(_))
  let wide : @jsontable.Table = {
    columns: Array::makei(500, i => "field\{i}"),
    rows: [],
  }
  assert_true(compare_tables(wide, wide, 0, 0) is Err(_))
}

///|
fn comparison_download_link(html : String, format : String) -> String raise {
  for part in html.split("<a download href=\"") {
    let pieces = part.split("\">").to_array()
    if pieces.length() > 1 &&
      pieces[1].has_prefix("Export differences " + format) {
      return office_unescape_xml(pieces[0].to_owned())
    }
  }
  fail("Missing comparison download link")
}

///|
async test "HTTP table comparison selects files and keys then downloads reloadable differences" {
  @moonlib/fsx.with_temporary_directory("desk-compare-http-", root => {
    let book = moonsuite_books_root(root) + "/compare"
    @fs.mkdir(book, recursive=true)
    let before = comparison_before_fixture()
    let after = comparison_after_fixture()
    let before_name = "before & 東京.csv"
    @fs.write_file(
      book + "/" + before_name,
      before.export_csv(),
      create_mode=CreateOrTruncate,
    )
    let records = after
      .text_rows()
      .map(row => {
        ({ "record": row[0], "amount": row[1], "name": row[2] } : Json)
      })
    let tsv : @leafcsv.Table = {
      rows: [after.columns] + after.text_rows(),
      delimiter: '\t',
    }
    for
      (name, data) in [
        ("after.csv", after.export_csv()),
        ("after.tsv", tsv.serialize_quoted()),
        ("after.json", records.to_json().stringify()),
        ("after.jsonl", records.map(record => record.stringify()).join("\n\n")),
        ("after.ndjson", records.map(record => record.stringify()).join("\n")),
      ] {
      @fs.write_file(book + "/" + name, data, create_mode=CreateOrTruncate)
    }
    @fs.write_file(
      book + "/after.xlsx",
      Bytes::from_array(
        @leafxlsx.create(
          [after.columns.map(value => @leafscene.CellValue::Text(value))] +
          after.rows,
          sheet_name="Revised & 東京",
        ),
      ),
      create_mode=CreateOrTruncate,
    )
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let route = @desk.workspace_json_table_url("book-compare", before_name)
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      let (_, explorer_body) = @http.get(base + route)
      assert_true(
        explorer_body.text().contains("Compare with another saved table"),
      )
      let (initial_response, initial) = @http.get(
        base + route + "&comparison=1",
      )
      assert_eq(initial_response.code, 200)
      assert_true(initial.text().contains("Open comparison file"))
      for extension in ["csv", "tsv", "json", "jsonl", "ndjson", "xlsx"] {
        let file = "after." + extension
        let original_before = @fs.read_file(book + "/" + before_name).binary()
        let original_after = @fs.read_file(book + "/" + file).binary()
        let choose = base +
          route +
          "&comparison=1&compare_path=" +
          encode_query_value(file)
        let (choose_response, choose_body) = @http.get(choose)
        assert_eq(choose_response.code, 200)
        assert_true(choose_body.text().contains("Before key"))
        let query = "&key=id&compare_key=record"
        let (response, body) = @http.get(choose + query)
        assert_eq(response.code, 200)
        let html = body.text()
        assert_true(
          html.contains(
            "1 added · 1 removed · 1 changed · 1 unchanged records",
          ),
        )
        assert_true(html.contains("before &amp; 東京.csv"))
        assert_true(html.contains("<option value=\"id\" selected>"))
        let csv_link = comparison_download_link(html, "CSV")
        let xlsx_link = comparison_download_link(html, "XLSX")
        if extension == "xlsx" {
          assert_true(
            csv_link.contains(
              "&compare_sheet=" + encode_query_value("Revised & 東京"),
            ),
          )
        }
        let (csv_response, csv_body) = @http.get(base + csv_link)
        assert_eq(csv_response.code, 200)
        assert_eq(
          csv_response.headers.get("content-disposition"),
          Some("attachment; filename=\"table-comparison.csv\""),
        )
        let csv = csv_body.text()
        let downloaded = @leafcsv.parse(csv).rows
        let expected = compare_tables(before, after, 0, 0).unwrap().differences
        assert_eq(downloaded[1:].to_owned(), expected.text_rows())
        assert_eq(downloaded[0][2], "Before record: " + before_name)
        let (xlsx_response, xlsx_body) = @http.get(base + xlsx_link)
        assert_eq(xlsx_response.code, 200)
        let xlsx = xlsx_body.binary()
        guard @moonleaf.open("difference.xlsx", xlsx.to_fixedarray())
          is @leafscene.WorkbookDocument(workbook) else {
          fail("expected real comparison workbook")
        }
        assert_eq(workbook.sheets[0].name, "Table differences")
        let reopened = table_from_sheet(workbook.sheets[0]).unwrap()
        assert_eq([reopened.columns] + reopened.text_rows(), downloaded)
        assert_eq(reopened.rows[2][1], @leafscene.Text("=1+1"))
        assert_eq(reopened.rows[0][1], @leafscene.Text("001"))
        let (_, reload) = @http.get(choose + query)
        assert_eq(reload.text(), html)
        assert_eq(
          @fs.read_file(book + "/" + before_name).binary(),
          original_before,
        )
        assert_eq(@fs.read_file(book + "/" + file).binary(), original_after)
        if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
          @fs.write_file(
            evidence + "/comparison-" + extension + ".html",
            html,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/comparison-" + extension + ".csv",
            csv,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/comparison-" + extension + ".xlsx",
            xlsx,
            create_mode=CreateOrTruncate,
          )
        }
      }
      let same = base +
        route +
        "&comparison=1&compare_path=" +
        encode_query_value(before_name) +
        "&key=id&compare_key=id"
      let (_, same_body) = @http.get(same)
      let same_html = same_body.text()
      assert_true(
        same_html.contains(
          "0 added · 0 removed · 0 changed · 3 unchanged records",
        ),
      )
      let (_, empty_csv) = @http.get(
        base + comparison_download_link(same_html, "CSV"),
      )
      assert_eq(@leafcsv.parse(empty_csv.text()).rows.length(), 1)
      for
        query in [
          "&compare_path=missing.csv", "&compare_path=..%2Foutside.csv", "&compare_path=after.csv&key=gone&compare_key=record",
          "&compare_path=after.csv&key=id", "&compare_path=after.xlsx&compare_sheet=missing",
        ] {
        let (response, _) = @http.get(base + route + "&comparison=1" + query)
        assert_eq(response.code, 400)
      }
      for format in ["csv", "xlsx"] {
        let export_route = @desk.workspace_json_table_url(
          "book-compare",
          before_name,
          format~,
        )
        let (incomplete, _) = @http.get(
          base + export_route + "&comparison=1&compare_path=after.csv",
        )
        assert_eq(incomplete.code, 400)
      }
    })
  })
}

///|
async test "comparison worksheets retain exact names and recover from duplicate keys and saved changes" {
  @moonlib/fsx.with_temporary_directory("desk-compare-sheets-", root => {
    let book = moonsuite_books_root(root) + "/sheets"
    @fs.mkdir(book, recursive=true)
    let bytes = Bytes::from_array(worksheet_explorer_fixture())
    for file in ["before.xlsx", "after.xlsx"] {
      @fs.write_file(book + "/" + file, bytes, create_mode=CreateOrTruncate)
    }
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let route = @desk.workspace_json_table_url("book-sheets", "before.xlsx") +
      "&comparison=1&compare_path=after.xlsx"
    let sheet = encode_query_value("Sales & 東京")
    let selections = "&sheet=" + sheet + "&compare_sheet=" + sheet
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      let (_, chooser) = @http.get(base + route + selections)
      let chooser_html = chooser.text()
      assert_true(chooser_html.contains("Before worksheet"))
      assert_true(chooser_html.contains("After worksheet"))
      assert_false(chooser_html.contains("unchanged records</h2>"))
      // File/sheet selectors intentionally omit keys, so switching resets them.
      let forms = chooser_html.split("</form>").to_array()
      assert_false(forms[0].contains("name=\"key\""))
      assert_false(forms[1].contains("name=\"key\""))
      let url = base + route + selections + "&key=customer&compare_key=customer"
      let (same_response, same_body) = @http.get(url)
      assert_eq(same_response.code, 200)
      let same_html = same_body.text()
      assert_true(
        same_html.contains(
          "0 added · 0 removed · 0 changed · 5 unchanged records",
        ),
      )
      let download = comparison_download_link(same_html, "CSV")
      assert_true(download.contains(selections))
      let (bad, bad_body) = @http.get(
        base + route + selections + "&key=region&compare_key=customer",
      )
      assert_eq(bad.code, 400)
      let bad_html = bad_body.text()
      assert_true(bad_html.contains("duplicate key"))
      assert_true(bad_html.contains("Compare tables"))
      // A saved edit is visible on an old download URL, and key column names
      // remain stable when the source columns move.
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
        book + "/after.xlsx",
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
      assert_eq(edited.length(), 2)
      assert_eq(edited[1][0], "Changed")
      assert_eq(edited[1][4], "amount")
      assert_true(
        edited[0][2].contains("before.xlsx [worksheet: Sales & 東京]"),
      )
      assert_true(
        edited[0][3].contains("after.xlsx [worksheet: Sales & 東京]"),
      )
      let (recovered, recovered_body) = @http.get(url)
      assert_eq(recovered.code, 200)
      assert_true(
        recovered_body
        .text()
        .contains("0 added · 0 removed · 1 changed · 4 unchanged records"),
      )
      assert_eq(@fs.read_file(book + "/before.xlsx").binary(), bytes)
      if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
        @fs.write_file(
          evidence + "/comparison-worksheets.html",
          chooser_html,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/comparison-duplicate-error.html",
          bad_html,
          create_mode=CreateOrTruncate,
        )
      }
    })
  })
}
