///|
fn duplicate_sample() -> @jsontable.Table raise {
  @jsontable.parse(
    "[{\"id\":\"A\",\"region\":\"East\",\"amount\":10,\"status\":\"Open\"},{\"id\":\"B\",\"region\":\"West\",\"amount\":7,\"status\":\"Open\"},{\"id\":\"A\",\"region\":\"West\",\"amount\":30,\"status\":\"Open\"},{\"id\":\"A\",\"region\":\"East\",\"amount\":20,\"status\":\"Closed\"},{\"id\":\"C\",\"region\":\"East\",\"amount\":2,\"status\":\"Open\"}]",
  )
}

///|
test "duplicate curation keeps saved representatives and composes with filters sort and summaries" {
  let table = duplicate_sample()
  let before = table_export_records(table).unwrap()
  for
    (mode, amounts) in [
      ("first", ["10", "7", "2"]),
      ("last", ["7", "20", "2"]),
      ("unique", ["7", "2"]),
      ("repeated", ["10", "30", "20"]),
    ] {
    let result = explore_table(
      table,
      "?duplicates=" + mode + "&duplicate_key=0",
    ).unwrap()
    assert_eq(result.text_rows().map(row => row[2]), amounts)
  }
  let query = "?text_column=3&contains=Open&sort=2&sort_type=number&direction=desc&group=1&sum=2&duplicates=last&duplicate_key=0"
  let result = explore_table(table, query).unwrap()
  assert_eq(result.text_rows().map(row => row[2]), ["30", "7", "2"])
  assert_eq(table_group_summary(result, query).unwrap().text_rows(), [
    ["West", "2", "2", "37"],
    ["East", "1", "1", "2"],
  ])
  assert_eq(
    explore_table(table, "?duplicates=first&duplicate_key=0&duplicate_key2=1").unwrap().rows.length(),
    4,
  )
  assert_eq(explore_table(table, "?duplicates=first").unwrap(), table)
  assert_eq(
    explore_table(table, "?duplicates=all&duplicate_key=999").unwrap(),
    table,
  )
  assert_eq(table_export_records(table).unwrap(), before)
  for
    query in [
      "?duplicates=invalid", "?duplicates=first&duplicate_key=99", "?duplicates=last&duplicate_key=-1",
      "?duplicates=unique&duplicate_key=x", "?duplicates=first&duplicate_key2=1",
      "?duplicates=first&duplicate_key=0&duplicate_key2=0", "?duplicates=repeated&duplicate_key=0&duplicate_key2=8",
    ] {
    assert_true(explore_table(table, query) is Err(_))
  }
  let empty = explore_table(
    table, "?text_column=0&contains=missing&duplicates=last&duplicate_key=0",
  ).unwrap()
  assert_eq(empty.columns, table.columns)
  assert_eq(empty.rows.length(), 0)
  assert_eq(table_export_records(empty).unwrap(), "[]\n")
}

///|
test "duplicate keys match displayed text without delimiter collisions and preserve typed survivors" {
  let table : @jsontable.Table = {
    columns: ["key", "key", "value"],
    rows: [
      [Number("1"), Text("a|b"), Boolean(true)],
      [Text("1"), Text("a|b"), Boolean(false)],
      [Text("1|a"), Text("b"), Number("9007199254740993")],
      [Text("01"), Text("a|b"), Text("=1+1")],
      [Empty, Text("東京\n\""), Text("first")],
      [Text(""), Text("東京\n\""), Text("last")],
      [Text("A"), Text(" "), Text("upper")],
      [Text("a"), Text(" "), Text("lower")],
      [Text("A"), Text(""), Text("space matters")],
    ],
  }
  let last = explore_table(
    table, "?duplicates=last&duplicate_key=0&duplicate_key2=1",
  ).unwrap()
  assert_eq(last.rows.length(), 7)
  assert_eq(last.rows[0], table.rows[1])
  assert_eq(last.rows[1], table.rows[2])
  assert_eq(last.rows[3], table.rows[5])
  assert_true(table_export_records(last) is Err(_)) // duplicate headers still cannot be object keys
  assert_eq(
    @leafcsv.parse(last.export_csv()).rows,
    [table.columns] + last.text_rows(),
  )
  let repeated : @jsontable.Table = {
    columns: ["a", "b"],
    rows: [[Text("x"), Number("2")], [Text("x"), Number("2")]],
  }
  assert_eq(
    explore_table(repeated, "?duplicates=first").unwrap().rows.length(),
    1,
  )
  assert_eq(
    explore_table(repeated, "?duplicates=unique").unwrap().rows.length(),
    0,
  )
  assert_eq(
    explore_table(repeated, "?duplicates=repeated").unwrap().rows.length(),
    2,
  )
}

///|
async test "HTTP duplicate review and exports retain query sheet and untouched saved sources" {
  let evidence_root = @env.get_env_var("MOONDESK_DUPLICATE_EVIDENCE").unwrap_or(
    "/tmp",
  )
  let fixture_root = evidence_root + "/retained-fixtures"
  @fsx.make_directory(fixture_root, recursive=true, exists_ok=true)
  let root = @moonlib/fsx.mkdtemp(fixture_root + "/desk-duplicates-XXXXXX")
  let book = moonsuite_books_root(root) + "/duplicates"
  @fs.mkdir(book, recursive=true)
  let sample = duplicate_sample()
  let records = table_export_records(sample).unwrap()
  let tsv : @leafcsv.Table = {
    rows: [sample.columns] + sample.text_rows(),
    delimiter: '\t',
  }
  for
    (name, text) in [
      ("rows.csv", sample.export_csv()),
      ("rows.tsv", tsv.serialize_quoted()),
      ("rows.json", records),
      ("rows.jsonl", table_export_records(sample, jsonl=true).unwrap()),
      ("rows.ndjson", table_export_records(sample, jsonl=true).unwrap()),
    ] {
    @fs.write_file(book + "/" + name, text, create_mode=CreateOrTruncate)
  }
  @fs.write_file(
    book + "/rows.xlsx",
    Bytes::from_array(sample.export_xlsx()),
    create_mode=CreateOrTruncate,
  )
  let server = Server::new("127.0.0.1", 0, reuse_addr=true)
  defer server.close()
  let base = "http://127.0.0.1:\{server.port()}"
  let query = "&text_column=3&contains=Open&sort=2&sort_type=number&direction=desc&group=1&sum=2&duplicates=last&duplicate_key=0&duplicate_key2="
  @async.with_task_group(group => {
    group.spawn_bg(
      () => server.serve_desk(root, root),
      no_wait=true,
      allow_failure=true,
    )
    for extension in ["csv", "tsv", "json", "jsonl", "ndjson", "xlsx"] {
      let file = "rows." + extension
      let before = @fs.read_file(book + "/" + file).binary()
      let sheet = if extension == "xlsx" { "&sheet=JSON%20data" } else { "" }
      let url = base +
        @desk.workspace_json_table_url("book-duplicates", file) +
        sheet +
        query
      let (response, body) = @http.get(url)
      assert_eq(response.code, 200)
      let html = body.text()
      assert_true(html.contains("Showing 3 of 5 saved rows"))
      assert_true(
        html.contains(
          "<option value=\"last\" selected>Last row for each key</option>",
        ),
      )
      assert_true(html.contains("Review duplicate records"))
      assert_true(html.contains("First/last refers to saved row order"))
      for format in ["csv", "xlsx", "json", "jsonl"] {
        let link = record_download_link(
          html,
          "Export filtered " + format.to_upper(),
        )
        assert_true(link.contains(sheet + query))
        let (download, body) = @http.get(base + link)
        assert_eq(download.code, 200)
        let bytes = body.binary()
        if format == "csv" {
          let text = @encoding/utf8.decode(bytes)
          assert_eq(@leafcsv.parse(text).rows, [
            sample.columns,
            ["A", "West", "30", "Open"],
            ["B", "West", "7", "Open"],
            ["C", "East", "2", "Open"],
          ])
        } else if format == "xlsx" {
          let document = @moonleaf.open("output.xlsx", bytes.to_fixedarray())
          guard document is @leafscene.WorkbookDocument(workbook) else {
            fail("expected workbook")
          }
          assert_eq(
            table_from_sheet(workbook.sheets[0])
            .unwrap()
            .text_rows()
            .map(row => row[2]),
            ["30", "7", "2"],
          )
        } else {
          let rows = record_output(@encoding/utf8.decode(bytes), format)
          assert_eq(rows.length(), 3)
          assert_eq(rows.map(row => json_object_field(row, "id")), [
            Some(("A" : Json)),
            Some(("B" : Json)),
            Some(("C" : Json)),
          ])
        }
        if @env.get_env_var("MOONDESK_DUPLICATE_EVIDENCE") is Some(evidence) {
          @fs.write_file(
            evidence + "/rows-" + extension + "." + format,
            bytes,
            create_mode=CreateOrTruncate,
          )
        }
      }
      let summary_link = record_download_link(html, "Export summary JSON")
      assert_true(summary_link.contains(sheet + query))
      let (summary_response, summary_body) = @http.get(base + summary_link)
      assert_eq(summary_response.code, 200)
      assert_eq(record_output(summary_body.text(), "json"), [
        {
          "Group: region": "West",
          "Rows": 2,
          "Numeric values: amount": 2,
          "Sum: amount": 37,
        },
        {
          "Group: region": "East",
          "Rows": 1,
          "Numeric values: amount": 1,
          "Sum: amount": 2,
        },
      ])
      let (again, again_body) = @http.get(url)
      assert_eq(again.code, 200)
      assert_eq(again_body.text(), html)
      assert_eq(@fs.read_file(book + "/" + file).binary(), before)
      if @env.get_env_var("MOONDESK_DUPLICATE_EVIDENCE") is Some(evidence) {
        @fs.write_file(
          evidence + "/rows-" + extension + ".html",
          html,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/source." + extension,
          before,
          create_mode=CreateOrTruncate,
        )
      }
    }
    let csv_url = base +
      @desk.workspace_json_table_url("book-duplicates", "rows.csv")
    for mode in ["first", "last", "unique", "repeated"] {
      let (response, body) = @http.get(
        csv_url + "&duplicates=" + mode + "&duplicate_key=0",
      )
      assert_eq(response.code, 200)
      let html = body.text()
      let expected = if mode == "unique" { "2" } else { "3" }
      assert_true(html.contains("Showing " + expected + " of 5 saved rows"))
    }
    let (invalid, invalid_body) = @http.get(
      base +
      @desk.workspace_json_table_url(
        "book-duplicates",
        "rows.csv",
        format="csv",
      ) +
      "&duplicates=first&duplicate_key=99",
    )
    assert_eq(invalid.code, 400)
    assert_true(invalid_body.text().contains("valid duplicate key"))
    let (empty, empty_body) = @http.get(
      base +
      @desk.workspace_json_table_url(
        "book-duplicates",
        "rows.csv",
        format="json",
      ) +
      "&duplicates=repeated&duplicate_key=0&text_column=0&contains=missing",
    )
    assert_eq(empty.code, 200)
    assert_eq(record_output(empty_body.text(), "json").length(), 0)
    @fs.write_file(
      book + "/rows.csv",
      "id,region,amount,status\nA,East,99,Open\n",
      create_mode=CreateOrTruncate,
    )
    let (changed, changed_body) = @http.get(
      base +
      @desk.workspace_json_table_url(
        "book-duplicates",
        "rows.csv",
        format="csv",
      ) +
      query,
    )
    assert_eq(changed.code, 200)
    assert_eq(@leafcsv.parse(changed_body.text()).rows, [
      ["id", "region", "amount", "status"],
      ["A", "East", "99", "Open"],
    ])
    let (reset, reset_body) = @http.get(csv_url)
    assert_eq(reset.code, 200)
    assert_true(reset_body.text().contains("Showing 1 of 1 saved rows"))
    group.return_immediately(())
  })
}
