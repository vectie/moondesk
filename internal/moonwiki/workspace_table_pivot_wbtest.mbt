///|
fn pivot_fixture() -> @jsontable.Table {
  {
    columns: ["region & 東京", "month", "amount"],
    rows: [
      [Text("001"), Text("Jan"), Text("10")],
      [Text("001"), Text("Jan"), Text("-10")],
      [Text("001"), Text("Feb"), Text("invalid")],
      [Text("=1+1"), Text("Feb"), Text("2.5")],
      [Text("=1+1"), Text(""), Empty],
      [Text("<b>\n,東京"), Text("Jan"), Text("1e2")],
      [Text("<b>\n,東京"), Text("(empty)"), Text("$4")],
    ],
  }
}

///|
test "pivot count and sum preserve exact categories numeric meaning and totals" {
  let input = pivot_fixture()
  let count = pivot_report(input, "region & 東京", "month", "count", "").unwrap()
  assert_eq(count.table.columns, [
    "Row type", "Row: region & 東京", "Category: Jan", "Category: Feb", "Category: ",
    "Category: (empty)", "Total records",
  ])
  assert_eq(count.table.text_rows(), [
    ["Group", "001", "2", "1", "0", "0", "3"],
    ["Group", "=1+1", "0", "1", "1", "0", "2"],
    ["Group", "<b>\n,東京", "1", "0", "0", "1", "2"],
    ["Grand total", "", "3", "2", "1", "1", "7"],
  ])
  let sum = pivot_report(input, "region & 東京", "month", "sum", "amount").unwrap()
  assert_eq(sum.numeric_rows, 4)
  assert_eq(sum.source_rows, 7)
  assert_eq(sum.table.text_rows(), [
    ["Group", "001", "0", "", "", "", "0"],
    ["Group", "=1+1", "", "2.5", "", "", "2.5"],
    ["Group", "<b>\n,東京", "100", "", "", "", "100"],
    ["Grand total", "", "100", "2.5", "", "", "102.5"],
  ])
  assert_eq(sum.table.rows[0][1], @leafscene.Text("001"))
  assert_eq(sum.table.rows[0][2], @leafscene.Number("0"))
  assert_eq(sum.table.rows[0][3], @leafscene.Empty)
  assert_eq(input, pivot_fixture())
  let reordered : @jsontable.Table = {
    columns: ["amount", "month", "region & 東京"],
    rows: input.rows.map(row => [row[2], row[1], row[0]]),
  }
  assert_eq(
    pivot_report(reordered, "region & 東京", "month", "sum", "amount").unwrap().table,
    sum.table,
  )
  let overflow : @jsontable.Table = {
    columns: ["row", "category", "value"],
    rows: [
      [Text("Grand total"), Text("Total records"), Number("1e308")],
      [Text("Grand total"), Text("Total records"), Number("1e308")],
    ],
  }
  let report = pivot_report(overflow, "row", "category", "sum", "value").unwrap()
  assert_eq(report.table.rows[0][2], @leafscene.Text("Overflow"))
  assert_eq(report.table.rows[1][3], @leafscene.Text("Overflow"))
  assert_eq(report.table.text_rows()[0][0], "Group")
}

///|
test "pivot invalid selections empty input and matrix bounds are explicit" {
  let table = pivot_fixture()
  for
    (row, column, mode, value) in [
      ("", "month", "count", ""),
      ("gone", "month", "count", ""),
      ("month", "month", "count", ""),
      ("month", "amount", "median", ""),
      ("month", "amount", "sum", "gone"),
    ] {
    assert_true(pivot_report(table, row, column, mode, value) is Err(_))
  }
  assert_true(
    pivot_report({ columns: ["x", "x"], rows: [], }, "x", "x", "count", "")
    is Err(_),
  )
  let empty : @jsontable.Table = {
    columns: ["row", "category", "value"],
    rows: [],
  }
  assert_eq(
    pivot_report(empty, "row", "category", "count", "").unwrap().table.text_rows(),
    [["Grand total", "", "0"]],
  )
  assert_eq(
    pivot_report(empty, "row", "category", "sum", "value").unwrap().table.rows[0][2],
    @leafscene.Empty,
  )
  let many_categories : @jsontable.Table = {
    columns: ["row", "category"],
    rows: Array::makei(998, i => [@leafscene.Text("x"), Text(i.to_string())]),
  }
  assert_true(
    pivot_report(many_categories, "row", "category", "count", "") is Err(_),
  )
  let large_matrix : @jsontable.Table = {
    columns: ["row", "category"],
    rows: Array::makei(2000, i => {
      [@leafscene.Text(i.to_string()), Text((i % 600).to_string())]
    }),
  }
  assert_true(
    pivot_report(large_matrix, "row", "category", "count", "") is Err(_),
  )
}

///|
fn pivot_link(html : String, format : String) -> String raise {
  for part in html.split("<a download href=\"") {
    let pieces = part.split("\">").to_array()
    if pieces.length() > 1 && pieces[1].has_prefix("Export pivot " + format) {
      return office_unescape_xml(pieces[0].to_owned())
    }
  }
  fail("Missing pivot download link")
}

///|
async test "pivot HTTP six formats actual CSV XLSX downloads context and errors" {
  @moonlib/fsx.with_temporary_directory("desk-pivot-", root => {
    let book = moonsuite_books_root(root) + "/pivot"
    @fs.mkdir(book, recursive=true)
    let table = pivot_fixture()
    let records = table
      .text_rows()
      .map(row => {
        ({ "region & 東京": row[0], "month": row[1], "amount": row[2] } : Json)
      })
    for
      (name, text) in [
        ("data.csv", table.export_csv()),
        (
          "data.tsv",
          (
            { rows: [table.columns] + table.text_rows(), delimiter: '\t', } :
            @leafcsv.Table).serialize_quoted(),
        ),
        ("data.json", Json::array(records).stringify()),
        ("data.jsonl", records.map(value => value.stringify()).join("\n")),
        ("data.ndjson", records.map(value => value.stringify()).join("\n")),
      ] {
      @fs.write_file(book + "/" + name, text, create_mode=CreateOrTruncate)
    }
    @fs.write_file(
      book + "/data.xlsx",
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
    let selected = "&pivot=1&pivot_row=" +
      encode_query_value("region & 東京") +
      "&pivot_column=month&aggregate=sum&pivot_value=amount"
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      for extension in ["csv", "tsv", "json", "jsonl", "ndjson", "xlsx"] {
        let file = "data." + extension
        let before = @fs.read_file(book + "/" + file).binary()
        let route = base + @desk.workspace_json_table_url("book-pivot", file)
        let (_, explorer) = @http.get(route)
        assert_true(explorer.text().contains("Create pivot report"))
        let (initial, chooser) = @http.get(route + "&pivot=1")
        assert_eq(initial.code, 200)
        assert_true(chooser.text().contains("Row groups"))
        let request = route + selected + "&contains=never&text_column=0"
        let (response, body) = @http.get(request)
        assert_eq(response.code, 200)
        let html = body.text()
        assert_true(
          html.contains(
            "4 numeric values included; 3 blank or non-numeric values ignored",
          ),
        )
        assert_true(html.contains("&lt;b&gt;"))
        assert_false(html.contains("<b>"))
        assert_true(html.contains("Category: &quot;&quot;"))
        assert_true(html.contains("Category: &quot;(empty)&quot;"))
        assert_true(html.contains("value=\"region &amp; 東京\" selected"))
        assert_true(html.contains("value=\"sum\" selected"))
        let csv_link = pivot_link(html, "CSV")
        if extension == "xlsx" {
          assert_true(
            csv_link.contains("&sheet=" + encode_query_value("Months & 東京")),
          )
        }
        assert_true(csv_link.contains("&pivot_value=amount"))
        let (csv_response, csv_body) = @http.get(base + csv_link)
        assert_eq(csv_response.code, 200)
        assert_eq(
          csv_response.headers.get("content-disposition"),
          Some("attachment; filename=\"table-pivot.csv\""),
        )
        let rows = @leafcsv.parse(csv_body.text()).rows
        let expected = pivot_report(
            table, "region & 東京", "month", "sum", "amount",
          ).unwrap().table
        assert_eq(rows, [expected.columns] + expected.text_rows())
        let (xlsx_response, xlsx_body) = @http.get(
          base + pivot_link(html, "XLSX"),
        )
        assert_eq(xlsx_response.code, 200)
        let xlsx = xlsx_body.binary()
        guard @moonleaf.open("pivot.xlsx", xlsx.to_fixedarray())
          is @leafscene.WorkbookDocument(workbook) else {
          fail("Expected actual XLSX workbook")
        }
        let reopened = table_from_sheet(workbook.sheets[0]).unwrap()
        assert_eq([reopened.columns] + reopened.text_rows(), rows)
        assert_eq(reopened.rows[0][1], @leafscene.Text("001"))
        assert_eq(reopened.rows[1][1], @leafscene.Text("=1+1"))
        assert_eq(reopened.rows[0][2], @leafscene.Number("0"))
        assert_eq(reopened.rows[0][3], @leafscene.Empty)
        let (_, reload) = @http.get(request)
        assert_eq(reload.text(), html)
        assert_eq(@fs.read_file(book + "/" + file).binary(), before)
        let (bad, bad_body) = @http.get(
          route + "&pivot=1&pivot_row=gone&pivot_column=month",
        )
        assert_eq(bad.code, 400)
        assert_true(bad_body.text().contains("Missing: gone"))
        let (missing, _) = @http.get(
          base +
          @desk.workspace_json_table_url("book-pivot", file, format="csv") +
          "&pivot=1",
        )
        assert_eq(missing.code, 400)
        let (unknown, _) = @http.get(
          base +
          @desk.workspace_json_table_url("book-pivot", file, format="pdf") +
          selected,
        )
        assert_eq(unknown.code, 400)
        let (_, count_body) = @http.get(
          base +
          @desk.workspace_json_table_url("book-pivot", file, format="csv") +
          "&pivot=1&pivot_row=" +
          encode_query_value("region & 東京") +
          "&pivot_column=month&aggregate=count",
        )
        assert_eq(@leafcsv.parse(count_body.text()).rows[4][6], "7")
        if @env.get_env_var("MOONDESK_PIVOT_EVIDENCE") is Some(evidence) {
          @fs.write_file(
            evidence + "/pivot-" + extension + ".html",
            html,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/pivot-" + extension + ".csv",
            csv_body.text(),
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/pivot-" + extension + ".xlsx",
            xlsx,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/pivot-count-" + extension + ".csv",
            count_body.text(),
            create_mode=CreateOrTruncate,
          )
        }
      }
    })
  })
}

///|
async test "pivot named sheet and source schema recover after saved changes" {
  @moonlib/fsx.with_temporary_directory("desk-pivot-context-", root => {
    let book = moonsuite_books_root(root) + "/pivot"
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
    let selected = "&pivot=1&sheet=" +
      encode_query_value("Sales & 東京") +
      "&pivot_row=region&pivot_column=status&aggregate=sum&pivot_value=amount"
    let route = base +
      @desk.workspace_json_table_url("book-pivot", "sheets.xlsx")
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      let (response, body) = @http.get(route + selected)
      assert_eq(response.code, 200)
      assert_true(body.text().contains("Sales &amp; 東京"))
      let download = base + pivot_link(body.text(), "CSV")
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
      let (other, _) = @http.get(
        route + "&pivot=1&sheet=Overview&pivot_row=region&pivot_column=status",
      )
      assert_eq(other.code, 400)
      @fs.write_file(
        file,
        Bytes::from_array(worksheet_explorer_fixture(names=["Overview"])),
        create_mode=CreateOrTruncate,
      )
      let (missing, _) = @http.get(download)
      assert_eq(missing.code, 400)
      let csv = book + "/changing.csv"
      let csv_route = base +
        @desk.workspace_json_table_url("book-pivot", "changing.csv") +
        "&pivot=1&pivot_row=region&pivot_column=month&aggregate=sum&pivot_value=amount"
      @fs.write_file(
        csv,
        "region,month,amount\nEast,Jan,4\n",
        create_mode=CreateOrTruncate,
      )
      let (valid, valid_body) = @http.get(csv_route)
      assert_eq(valid.code, 200)
      let csv_download = base + pivot_link(valid_body.text(), "CSV")
      @fs.write_file(
        csv,
        "amount,month,region\n8,Jan,East\n",
        create_mode=CreateOrTruncate,
      )
      let (_, changed) = @http.get(csv_download)
      assert_eq(@leafcsv.parse(changed.text()).rows[1][2], "8")
      @fs.write_file(
        csv,
        "amount,month,renamed\n8,Jan,East\n",
        create_mode=CreateOrTruncate,
      )
      let (stale, stale_body) = @http.get(csv_route)
      assert_eq(stale.code, 400)
      assert_true(stale_body.text().contains("Missing: region"))
      @fs.write_file(
        csv,
        "region,month,amount,amount\nEast,Jan,1,2\n",
        create_mode=CreateOrTruncate,
      )
      let (duplicate, duplicate_body) = @http.get(csv_route)
      assert_eq(duplicate.code, 400)
      assert_true(duplicate_body.text().contains("Duplicate source header"))
      @fs.write_file(csv, "region,month,amount\n", create_mode=CreateOrTruncate)
      let (fixed, empty_body) = @http.get(csv_download)
      assert_eq(fixed.code, 200)
      assert_eq(@leafcsv.parse(empty_body.text()).rows, [
        ["Row type", "Row: region", "Total sum: amount"],
        ["Grand total", "", ""],
      ])
      if @env.get_env_var("MOONDESK_PIVOT_EVIDENCE") is Some(evidence) {
        @fs.write_file(
          evidence + "/pivot-selected-sheet.html",
          body.text(),
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/pivot-selected-sheet.csv",
          original.text(),
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/pivot-missing-column.html",
          stale_body.text(),
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/pivot-empty.csv",
          empty_body.text(),
          create_mode=CreateOrTruncate,
        )
      }
    })
  })
}
