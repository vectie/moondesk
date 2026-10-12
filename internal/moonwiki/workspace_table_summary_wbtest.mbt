///|
test "summary exports use typed counts totals and exact group values" {
  let table = @jsontable.parse(
    (
      #|[{"group":"","amount":2},{"group":"(blank)","amount":null},{"group":"","amount":-2},{"group":"東京,\"quoted\"\nline","amount":"3.25"},{"group":"=1+1","amount":"n/a"},{"group":"001","amount":1e308},{"group":"001","amount":1e308}]
    ),
  )
  let summary = table_group_summary(table, "?group=0&sum=1").unwrap()
  assert_eq(summary.columns, [
    "Group: group", "Rows", "Numeric values: amount", "Sum: amount",
  ])
  assert_eq(summary.text_rows(), [
    ["", "2", "2", "0"],
    ["(blank)", "1", "0", ""],
    ["東京,\"quoted\"\nline", "1", "1", "3.25"],
    ["=1+1", "1", "0", ""],
    ["001", "2", "2", "Overflow"],
  ])
  assert_eq(summary.rows[0], [
    @leafscene.Text(""),
    Number("2"),
    Number("2"),
    Number("0"),
  ])
  assert_eq(summary.rows[1][3], @leafscene.Empty)
  assert_eq(summary.rows[4][3], @leafscene.Text("Overflow"))
  assert_eq(
    @leafcsv.parse(summary.export_csv()).rows,
    [summary.columns] + summary.text_rows(),
  )
  guard @moonleaf.open("summary.xlsx", summary.export_xlsx())
    is @leafscene.WorkbookDocument(workbook) else {
    fail("expected summary workbook")
  }
  let reopened = table_from_sheet(workbook.sheets[0]).unwrap()
  assert_eq(reopened, summary)
  let html = table_explorer_summary(table, "?group=0&sum=1")
  assert_true(html.contains("東京,&quot;quoted&quot;\nline"))
  assert_true(html.contains("<td>(blank)</td><td>2</td><td>2</td><td>0</td>"))
  assert_true(html.contains("Overflow"))
  assert_eq(table_group_summary(table, "?group=0").unwrap().text_rows(), [
    ["", "2"],
    ["(blank)", "1"],
    ["東京,\"quoted\"\nline", "1"],
    ["=1+1", "1"],
    ["001", "2"],
  ])
}

///|
test "summary needs a valid group and empty filtered results have headers only" {
  let source = explorer_sample()
  for query in ["", "?group=99", "?group=-1", "?group=bad", "?group=1&sum=99"] {
    assert_true(table_group_summary(source, query) is Err(_))
  }
  let query = "?text_column=0&contains=missing&group=1&sum=2"
  let empty = explore_table(source, query).unwrap()
  let summary = table_group_summary(empty, query).unwrap()
  assert_eq(summary.rows.length(), 0)
  assert_eq(@leafcsv.parse(summary.export_csv()).rows, [summary.columns])
  let html = json_table_html(
    "book-data",
    "sales.csv",
    empty,
    request_path=query,
  )
  assert_true(
    html.contains("No matching rows. Summary exports contain headers only."),
  )
  assert_true(html.contains("projection=summary"))
  let plain = json_table_html("book-data", "sales.csv", source)
  assert_false(plain.contains("Export summary"))
}

///|
fn summary_download_link(html : String, format : String) -> String raise {
  for part in html.split("<a download href=\"") {
    let pieces = part.split("\">").to_array()
    if pieces.length() > 1 && pieces[1].has_prefix("Export summary " + format) {
      return office_unescape_xml(pieces[0].to_owned())
    }
  }
  fail("Missing summary download link")
}

///|
async test "HTTP summary links export filtered sorted groups across formats and named worksheets" {
  @moonlib/fsx.with_temporary_directory("desk-summary-http-", root => {
    let book = moonsuite_books_root(root) + "/summary"
    @fs.mkdir(book, recursive=true)
    let sample = explorer_sample()
    let records = sample
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
    let tsv : @leafcsv.Table = {
      rows: [sample.columns] + sample.text_rows(),
      delimiter: '\t',
    }
    for
      (file, data) in [
        ("sales.csv", sample.export_csv()),
        ("sales.tsv", tsv.serialize_quoted()),
        ("sales.json", records.to_json().stringify()),
        ("sales.jsonl", records.map(record => record.stringify()).join("\n")),
      ] {
      @fs.write_file(book + "/" + file, data, create_mode=CreateOrTruncate)
    }
    @fs.write_file(
      book + "/sales.xlsx",
      Bytes::from_array(worksheet_explorer_fixture()),
      create_mode=CreateOrTruncate,
    )
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let filters = "&text_column=3&contains=open&sort=2&sort_type=number&direction=desc&group=1&sum=2"
    let expected = [
      ["Group: region", "Rows", "Numeric values: amount", "Sum: amount"],
      ["West", "1", "1", "2500"],
      ["East", "3", "2", "1550.5"],
    ]
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      for extension in ["csv", "tsv", "json", "jsonl", "xlsx"] {
        let file = "sales." + extension
        let original = @fs.read_file(book + "/" + file).binary()
        let sheet = if extension == "xlsx" {
          "&sheet=" + encode_query_value("Sales & 東京")
        } else {
          ""
        }
        let url = base +
          @desk.workspace_json_table_url("book-summary", file) +
          sheet +
          filters
        let (response, body) = @http.get(url)
        assert_eq(response.code, 200)
        let html = body.text()
        assert_true(html.contains("Showing 4 of 5 saved rows"))
        assert_true(
          html.contains("<td>West</td><td>1</td><td>1</td><td>2500</td>"),
        )
        assert_true(
          html.contains("<td>East</td><td>3</td><td>2</td><td>1550.5</td>"),
        )
        let csv_link = summary_download_link(html, "CSV")
        let xlsx_link = summary_download_link(html, "XLSX")
        assert_true(csv_link.contains(filters))
        assert_true(csv_link.contains(sheet))
        let (csv_response, csv_body) = @http.get(base + csv_link)
        assert_eq(csv_response.code, 200)
        assert_eq(
          csv_response.headers.get("content-type"),
          Some("text/csv; charset=utf-8"),
        )
        assert_eq(
          csv_response.headers.get("content-disposition"),
          Some("attachment; filename=\"table-summary.csv\""),
        )
        let csv = csv_body.text()
        assert_eq(@leafcsv.parse(csv).rows, expected)
        let (xlsx_response, xlsx_body) = @http.get(base + xlsx_link)
        assert_eq(xlsx_response.code, 200)
        assert_eq(
          xlsx_response.headers.get("content-disposition"),
          Some("attachment; filename=\"table-summary.xlsx\""),
        )
        let xlsx = xlsx_body.binary()
        guard @moonleaf.open("summary.xlsx", xlsx.to_fixedarray())
          is @leafscene.WorkbookDocument(workbook) else {
          fail("expected HTTP summary workbook")
        }
        assert_eq(workbook.sheets.length(), 1)
        assert_eq(
          workbook.sheets[0].name,
          if extension == "xlsx" {
            "Sales & 東京"
          } else {
            "Group summary"
          },
        )
        let summary = table_from_sheet(workbook.sheets[0]).unwrap()
        assert_eq([summary.columns] + summary.text_rows(), expected)
        assert_eq(summary.rows[1][1], @leafscene.Number("3"))
        assert_eq(summary.rows[1][3], @leafscene.Number("1550.5"))
        // Ordinary row exports are still rows even while grouping is selected.
        let (_, rows) = @http.get(
          base +
          @desk.workspace_json_table_url("book-summary", file, format="csv") +
          sheet +
          filters,
        )
        assert_eq(@leafcsv.parse(rows.text()).rows.length(), 5)
        let (_, reload) = @http.get(url)
        assert_eq(reload.text(), html)
        assert_eq(@fs.read_file(book + "/" + file).binary(), original)
        if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
          @fs.write_file(
            evidence + "/summary-" + extension + ".html",
            html,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/summary-" + extension + ".csv",
            csv,
            create_mode=CreateOrTruncate,
          )
          @fs.write_file(
            evidence + "/summary-" + extension + ".xlsx",
            xlsx,
            create_mode=CreateOrTruncate,
          )
        }
      }
      let endpoint = base +
        @desk.workspace_json_table_url(
          "book-summary",
          "sales.xlsx",
          format="csv",
        ) +
        "&sheet=" +
        encode_query_value("Sales & 東京")
      let (empty_response, empty) = @http.get(
        endpoint +
        "&projection=summary&group=1&sum=2&text_column=0&contains=missing",
      )
      assert_eq(empty_response.code, 200)
      assert_eq(@leafcsv.parse(empty.text()).rows, [expected[0]])
      let (counts_response, counts) = @http.get(
        endpoint + "&projection=summary&group=1",
      )
      assert_eq(counts_response.code, 200)
      assert_eq(@leafcsv.parse(counts.text()).rows, [
        ["Group: region", "Rows"],
        ["East", "3"],
        ["West", "2"],
      ])
      for
        query in [
          "&projection=summary", "&projection=summary&group=99", "&projection=summary&group=1&sum=99",
          "&projection=unknown", "&projection=summary&group=1&number_column=2&min=oops",
        ] {
        let (bad, _) = @http.get(endpoint + query)
        assert_eq(bad.code, 400)
      }
    })
  })
}
