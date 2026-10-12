///|
test "object record export preserves typed projection and numeric lexemes" {
  let table : @jsontable.Table = {
    columns: [
      "quote\"\n東京", "number", "flag", "empty", "text", "error", "cache",
    ],
    rows: [
      [
        Text("<tag>\\\n🙂"),
        Number("9007199254740993"),
        Boolean(true),
        Empty,
        Text("001"),
        Error("#DIV/0!"),
        Formula(expression="A1+1", cached=Some("2")),
      ],
      [
        Text("null"),
        Number("-1.25e+2"),
        Boolean(false),
        Text(""),
        Text("{\"x\":1}"),
        Text("=1+1"),
        Formula(expression="A1+1", cached=None),
      ],
    ],
  }
  let text = table_export_records(table).unwrap()
  assert_true(text.contains("9007199254740993"))
  assert_true(text.contains("-1.25e+2"))
  guard @json.parse(text) is Array(rows) else { fail("expected array") }
  assert_eq(rows.length(), 2)
  assert_eq(
    json_object_field(rows[0], "quote\"\n東京"),
    Some(("<tag>\\\n🙂" : Json)),
  )
  assert_eq(json_object_field(rows[0], "flag"), Some((true : Json)))
  assert_eq(json_object_field(rows[0], "empty"), Some(Json::null()))
  assert_eq(json_object_field(rows[0], "text"), Some(("001" : Json)))
  assert_eq(json_object_field(rows[0], "error"), Some(("#DIV/0!" : Json)))
  assert_eq(json_object_field(rows[0], "cache"), Some(("2" : Json)))
  assert_eq(json_object_field(rows[1], "empty"), Some(("" : Json)))
  assert_eq(json_object_field(rows[1], "cache"), Some(Json::null()))
  assert_eq(json_object_field(rows[1], "text"), Some(("{\"x\":1}" : Json)))
  let lines = table_export_records(table, jsonl=true).unwrap()
  assert_true(lines.has_suffix("\n"))
  let records = record_output(lines, "jsonl")
  assert_eq(records, rows)
  assert_eq(records.length(), 2)
}

///|
test "record export refuses lossy schemas and invalid typed numbers" {
  let duplicate : @jsontable.Table = { columns: ["a", "a"], rows: [], }
  assert_true(
    table_export_records(duplicate) is Err(message) &&
    message.contains("unique headers"),
  )
  let empty : @jsontable.Table = { columns: ["a"], rows: [], }
  assert_eq(table_export_records(empty), Ok("[]\n"))
  assert_eq(table_export_records(empty, jsonl=true), Ok(""))
  let no_columns : @jsontable.Table = { columns: [], rows: [[]], }
  assert_eq(table_export_records(no_columns), Ok("[{}]\n"))
  let ragged : @jsontable.Table = {
    columns: ["a"],
    rows: [[], [Text("lost"), Text("extra")]],
  }
  assert_true(table_export_records(ragged) is Err(_))
  for token in ["NaN", "Infinity", "1e999", "001", "true", "1,2", "", "{}"] {
    let invalid : @jsontable.Table = {
      columns: ["a"],
      rows: [[Number(token)]],
    }
    assert_true(
      table_export_records(invalid) is Err(message) &&
      message.contains("Record 1, column 1"),
    )
  }
  let projected = @jsontable.parse(
    "[{\"null\":null,\"nested\":{\"x\":1},\"text\":\"true\"},{\"text\":\"001\"}]",
  )
  assert_eq(
    @json.parse(table_export_records(projected).unwrap()),
    @json.parse(
      "[{\"null\":\"null\",\"nested\":\"{\\\"x\\\":1}\",\"text\":\"true\"},{\"null\":null,\"nested\":null,\"text\":\"001\"}]",
    ),
  )
}

///|
fn record_download_link(html : String, label : String) -> String raise {
  for part in html.split("<a download href=\"") {
    let pieces = part.split("\">").to_array()
    if pieces.length() > 1 && pieces[1].has_prefix(label + "</a>") {
      return office_unescape_xml(pieces[0].to_owned())
    }
  }
  fail("Missing record download link: " + label)
}

///|
fn record_output(text : String, format : String) -> Array[Json] raise {
  if format == "jsonl" {
    let records : Array[Json] = []
    for line in text.split("\n") {
      if line != "" {
        records.push(@json.parse(line.to_owned()))
      }
    }
    return records
  }
  guard @json.parse(text) is Array(rows) else { fail("Expected JSON array") }
  rows
}

///|
async test "HTTP exports rows and summaries from six saved formats without changing source" {
  @moonlib/fsx.with_temporary_directory("desk-records-", root => {
    let book = moonsuite_books_root(root) + "/records"
    @fs.mkdir(book, recursive=true)
    let sample = explorer_sample()
    let json = "[{\"customer\":\"Northwind 東京\",\"region\":\"East\",\"amount\":1250.5,\"status\":\"Open\"},{\"customer\":\"Bluebird\",\"region\":\"West\",\"amount\":90,\"status\":\"Paid\"},{\"customer\":\"Acme, Inc.\",\"region\":\"East\",\"amount\":300,\"status\":\"open\"},{\"customer\":\"River\",\"region\":\"West\",\"amount\":2500,\"status\":\"Open\"},{\"customer\":\"Draft\",\"region\":\"East\",\"amount\":null,\"status\":\"Open\"}]"
    guard @json.parse(json) is Array(records) else { fail("fixture array") }
    let tsv : @leafcsv.Table = {
      rows: [sample.columns] + sample.text_rows(),
      delimiter: '\t',
    }
    for
      (name, text) in [
        ("sales.csv", sample.export_csv()),
        ("sales.tsv", tsv.serialize_quoted()),
        ("sales.json", json),
        ("sales.jsonl", records.map(row => row.stringify()).join("\n")),
        ("sales.ndjson", records.map(row => row.stringify()).join("\n")),
        ("duplicate.csv", "name,name\nleft,right\n"),
      ] {
      @fs.write_file(book + "/" + name, text, create_mode=CreateOrTruncate)
    }
    @fs.write_file(
      book + "/sales.xlsx",
      Bytes::from_array(worksheet_explorer_fixture()),
      create_mode=CreateOrTruncate,
    )
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let filters = "&text_column=3&contains=open&number_column=2&min=100&sort=2&sort_type=number&direction=desc&group=1&sum=2"
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      for extension in ["csv", "tsv", "json", "jsonl", "ndjson", "xlsx"] {
        let file = "sales." + extension
        let original = @fs.read_file(book + "/" + file).binary()
        let sheet = if extension == "xlsx" {
          "&sheet=" + encode_query_value("Sales & 東京")
        } else {
          ""
        }
        let url = base +
          @desk.workspace_json_table_url("book-records", file) +
          sheet +
          filters
        let (response, body) = @http.get(url)
        assert_eq(response.code, 200)
        let html = body.text()
        assert_true(html.contains("Showing 3 of 5 saved rows"))
        assert_true(
          html.contains(
            "Nested JSON and literal null imported by the table reader remain text",
          ),
        )
        for format in ["json", "jsonl"] {
          let link = record_download_link(
            html,
            "Export filtered " + format.to_upper(),
          )
          assert_true(link.contains(sheet + filters))
          let (download, body) = @http.get(base + link)
          assert_eq(download.code, 200)
          assert_eq(
            download.headers.get("content-type"),
            Some(
              if format == "json" {
                "application/json; charset=utf-8"
              } else {
                "application/x-ndjson; charset=utf-8"
              },
            ),
          )
          assert_eq(
            download.headers.get("content-disposition"),
            Some("attachment; filename=\"json-table.\{format}\""),
          )
          let text = body.text()
          let rows = record_output(text, format)
          assert_eq(rows.length(), 3)
          assert_eq(rows.map(row => json_object_field(row, "customer")), [
            Some(("River" : Json)),
            Some(("Northwind 東京" : Json)),
            Some(("Acme, Inc." : Json)),
          ])
          assert_eq(
            json_object_field(rows[0], "amount"),
            Some(
              if extension == "csv" || extension == "tsv" {
                ("2500" : Json)
              } else {
                (2500 : Json)
              },
            ),
          )
          let summary_link = record_download_link(
            html,
            "Export summary " + format.to_upper(),
          )
          assert_true(summary_link.contains(sheet + filters))
          let (summary_response, summary_body) = @http.get(base + summary_link)
          assert_eq(summary_response.code, 200)
          assert_eq(
            summary_response.headers.get("content-disposition"),
            Some("attachment; filename=\"table-summary.\{format}\""),
          )
          let summary = summary_body.text()
          assert_eq(record_output(summary, format), [
            {
              "Group: region": "West",
              "Rows": 1,
              "Numeric values: amount": 1,
              "Sum: amount": 2500,
            },
            {
              "Group: region": "East",
              "Rows": 2,
              "Numeric values: amount": 2,
              "Sum: amount": 1550.5,
            },
          ])
          if @env.get_env_var("MOONDESK_RECORD_EXPORT_EVIDENCE")
            is Some(evidence) {
            @fs.write_file(
              evidence + "/rows-\{extension}.\{format}",
              text,
              create_mode=CreateOrTruncate,
            )
            @fs.write_file(
              evidence + "/summary-\{extension}.\{format}",
              summary,
              create_mode=CreateOrTruncate,
            )
            @fs.write_file(
              evidence + "/explorer-\{extension}.html",
              html,
              create_mode=CreateOrTruncate,
            )
          }
        }
        let (_, reloaded) = @http.get(url)
        assert_eq(reloaded.text(), html)
        assert_eq(@fs.read_file(book + "/" + file).binary(), original)
      }
      for format in ["json", "jsonl"] {
        let endpoint = base +
          @desk.workspace_json_table_url("book-records", "sales.csv", format~)
        let (empty_response, empty) = @http.get(
          endpoint + "&text_column=0&contains=missing",
        )
        assert_eq(empty_response.code, 200)
        assert_eq(empty.text(), if format == "json" { "[]\n" } else { "" })
        let (summary_response, empty_summary) = @http.get(
          endpoint +
          "&text_column=0&contains=missing&group=1&projection=summary",
        )
        assert_eq(summary_response.code, 200)
        assert_eq(record_output(empty_summary.text(), format), [])
        for
          query in [
            "&projection=summary", "&projection=other", "&number_column=2&min=oops",
          ] {
          let (bad, _) = @http.get(endpoint + query)
          assert_eq(bad.code, 400)
        }
        let (duplicate, _) = @http.get(
          base +
          @desk.workspace_json_table_url(
            "book-records",
            "duplicate.csv",
            format~,
          ),
        )
        assert_eq(duplicate.code, 400)
      }
      let (_, duplicate_html) = @http.get(
        base + @desk.workspace_json_table_url("book-records", "duplicate.csv"),
      )
      assert_true(duplicate_html.text().contains("Rename duplicate header"))
      // An old download URL reads the latest saved bytes while retaining the
      // selected named sheet, even after worksheet order changes.
      let pinned = base +
        @desk.workspace_json_table_url(
          "book-records",
          "sales.xlsx",
          format="json",
        ) +
        "&sheet=" +
        encode_query_value("Sales & 東京") +
        filters
      @fs.write_file(
        book + "/sales.xlsx",
        Bytes::from_array(
          worksheet_explorer_fixture(names=[
            "Empty", "Sales & 東京", "Overview",
          ]),
        ),
        create_mode=CreateOrTruncate,
      )
      let (reordered, body) = @http.get(pinned)
      assert_eq(reordered.code, 200)
      assert_eq(record_output(body.text(), "json").length(), 3)
      @fs.write_file(
        book + "/sales.xlsx",
        Bytes::from_array(worksheet_explorer_fixture(names=["Overview"])),
        create_mode=CreateOrTruncate,
      )
      let (missing, _) = @http.get(pinned)
      assert_eq(missing.code, 400)
      @fs.write_file(
        book + "/sales.csv",
        "customer,region,amount,status\nChanged,North,700,Open\n",
        create_mode=CreateOrTruncate,
      )
      let (updated, body) = @http.get(
        base +
        @desk.workspace_json_table_url(
          "book-records",
          "sales.csv",
          format="json",
        ) +
        filters,
      )
      assert_eq(updated.code, 200)
      assert_eq(
        json_object_field(record_output(body.text(), "json")[0], "customer"),
        Some(("Changed" : Json)),
      )
    })
  })
}
