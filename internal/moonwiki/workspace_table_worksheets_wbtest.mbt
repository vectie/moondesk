///|
// Build real OOXML with workbook order different from ZIP entry order.
fn worksheet_explorer_fixture(
  names~ : Array[String] = ["Overview", "Sales & 東京", "Empty"],
) -> FixedArray[Byte] raise {
  let content = StringBuilder()
  content.write_string(
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>",
  )
  let workbook = StringBuilder()
  workbook.write_string(
    "<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>",
  )
  let relationships = StringBuilder()
  relationships.write_string(
    "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">",
  )
  let entries : Array[(String, FixedArray[Byte])] = []
  for i, name in names {
    let id = i + 1
    let table = if name == "Sales & 東京" {
      explorer_sample()
    } else if name == "Empty" {
      { columns: [], rows: [], }
    } else {
      @jsontable.parse("[{\"summary\":\"Overview only\"}]")
    }
    for (path, bytes) in @moonzip.unzip_sync(table.export_xlsx()) {
      if path == "xl/worksheets/sheet1.xml" {
        entries.push(("xl/worksheets/sheet\{id}.xml", bytes))
      }
    }
    content.write_string(
      "<Override PartName=\"/xl/worksheets/sheet\{id}.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>",
    )
    workbook.write_string(
      "<sheet name=\"\{office_escape_xml(name)}\" sheetId=\"\{id}\" r:id=\"rId\{id}\"/>",
    )
    relationships.write_string(
      "<Relationship Id=\"rId\{id}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\{id}.xml\"/>",
    )
  }
  content.write_string("</Types>")
  workbook.write_string("</sheets></workbook>")
  relationships.write_string("</Relationships>")
  let entries = entries.rev()
  entries.push(("[Content_Types].xml", office_xml(content.to_string())))
  entries.push(
    (
      "_rels/.rels",
      office_xml(
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
      ),
    ),
  )
  entries.push(("xl/workbook.xml", office_xml(workbook.to_string())))
  entries.push(
    ("xl/_rels/workbook.xml.rels", office_xml(relationships.to_string())),
  )
  @moonzip.zip_sync(entries)
}

///|
test "worksheet forms name exact source and reset transforms only on sheet change" {
  let selected = "Sales & 東京"
  let query = "?sheet=" +
    encode_query_value(selected) +
    "&text_column=3&contains=open"
  let switch = table_worksheet_controls(
    "two & books.xlsx",
    ["Overview", selected, "Empty"],
    query,
  )
  assert_true(switch.contains("Worksheet: <strong>Sales &amp; 東京</strong>"))
  assert_true(switch.contains("<option value=\"Sales &amp; 東京\" selected>"))
  assert_true(switch.contains("name=\"path\" value=\"two &amp; books.xlsx\""))
  assert_false(switch.contains("name=\"contains\""))
  assert_false(switch.contains("name=\"format\""))
  let controls = table_explorer_controls(
    "book-data",
    "data.xlsx",
    ["name"],
    query,
  )
  assert_true(
    controls.contains(
      "type=\"hidden\" name=\"sheet\" value=\"Sales &amp; 東京\"",
    ),
  )
  let reset = @desk.workspace_json_table_url("book-data", "data.xlsx") +
    "&sheet=" +
    encode_query_value(selected)
  assert_true(
    controls.contains("href=\"" + office_escape_xml(reset) + "\">Reset all"),
  )
  assert_eq(table_worksheet_controls("data.csv", [], ""), "")
}

///|
async test "worksheet reader retains exact name across reorder and refuses stale selections" {
  @moonlib/fsx.with_temporary_directory("desk-sheet-read-", root => {
    let workspace = @desk.workspace(
      id="book-data",
      name="Data",
      root_path=root,
      kind=MoonBook,
    )
    let bytes = Bytes::from_array(worksheet_explorer_fixture())
    @fs.write_file(root + "/data.xlsx", bytes, create_mode=CreateOrTruncate)
    let source = read_workspace_json_table(
      workspace,
      "data.xlsx",
      sheet="Sales & 東京",
    ).unwrap()
    assert_eq(source.selected_sheet, Some("Sales & 東京"))
    assert_eq(source.sheet_names, ["Overview", "Sales & 東京", "Empty"])
    assert_eq(source.table.text_rows(), explorer_sample().text_rows())
    assert_eq(
      read_workspace_json_table(workspace, "data.xlsx").unwrap().selected_sheet,
      Some("Overview"),
    )
    assert_eq(
      read_workspace_json_table(workspace, "data.xlsx", sheet="Empty").unwrap().table.rows.length(),
      0,
    )
    assert_true(
      read_workspace_json_table(workspace, "data.xlsx", sheet="missing")
      is Err(_),
    )
    assert_true(
      read_workspace_json_table(workspace, "data.xlsx", sheet="") is Err(_),
    )
    assert_eq(@fs.read_file(root + "/data.xlsx").binary(), bytes)
    @fs.write_file(
      root + "/data.xlsx",
      Bytes::from_array(
        worksheet_explorer_fixture(names=["Empty", "Sales & 東京", "Overview"]),
      ),
      create_mode=CreateOrTruncate,
    )
    assert_eq(
      read_workspace_json_table(workspace, "data.xlsx", sheet="Sales & 東京").unwrap().table.text_rows(),
      source.table.text_rows(),
    )
    @fs.write_file(root + "/data.csv", "a\nb", create_mode=CreateOrTruncate)
    assert_true(
      read_workspace_json_table(workspace, "data.csv", sheet="Sales & 東京")
      is Err(_),
    )
    @fs.write_file(
      root + "/data.xlsx",
      Bytes::from_array(worksheet_explorer_fixture(names=["Overview"])),
      create_mode=CreateOrTruncate,
    )
    assert_true(
      read_workspace_json_table(workspace, "data.xlsx", sheet="Sales & 東京")
      is Err(_),
    )
  })
}

///|
async test "local HTTP selected worksheet exploration exports reload and independent file selection" {
  @moonlib/fsx.with_temporary_directory("desk-sheet-http-", root => {
    let book = moonsuite_books_root(root) + "/sheets"
    @fs.mkdir(book, recursive=true)
    let original = Bytes::from_array(worksheet_explorer_fixture())
    @fs.write_file(book + "/data.xlsx", original, create_mode=CreateOrTruncate)
    @fs.write_file(book + "/other.xlsx", original, create_mode=CreateOrTruncate)
    let server = Server::new("127.0.0.1", 0, reuse_addr=true)
    defer server.close()
    let base = "http://127.0.0.1:\{server.port()}"
    let url = base + @desk.workspace_json_table_url("book-sheets", "data.xlsx")
    let selected = "&sheet=" + encode_query_value("Sales & 東京")
    let filters = "&text_column=3&contains=open&number_column=2&min=100&max=2000&sort=2&sort_type=number&direction=desc&group=1&sum=2"
    @async.with_task_group(group => {
      group.spawn_bg(
        () => server.serve_desk(root, root),
        no_wait=true,
        allow_failure=true,
      )
      let (first_response, first) = @http.get(url)
      assert_eq(first_response.code, 200)
      let first_html = first.text()
      assert_true(first_html.contains("Worksheet: <strong>Overview</strong>"))
      assert_true(first_html.contains("name=\"sheet\" value=\"Overview\""))
      assert_true(first_html.contains("format=csv&amp;sheet=Overview"))
      let (response, body) = @http.get(url + selected + filters)
      assert_eq(response.code, 200)
      let html = body.text()
      assert_true(
        html.contains("Worksheet: <strong>Sales &amp; 東京</strong>"),
      )
      assert_true(html.contains("Showing 2 of 5 saved rows"))
      assert_true(
        html.contains("<td>East</td><td>2</td><td>2</td><td>1550.5</td>"),
      )
      assert_false(html.contains("<td>Overview only</td>"))
      let (reload_response, reload) = @http.get(url + selected + filters)
      assert_eq(reload_response.code, 200)
      assert_eq(reload.text(), html)
      let (csv_response, csv_body) = @http.get(
        base +
        @desk.workspace_json_table_url("book-sheets", "data.xlsx", format="csv") +
        selected +
        filters,
      )
      assert_eq(csv_response.code, 200)
      let csv = csv_body.text()
      let expected = [
        explorer_sample().columns,
        explorer_sample().text_rows()[0],
        explorer_sample().text_rows()[2],
      ]
      assert_eq(@leafcsv.parse(csv).rows, expected)
      let (xlsx_response, xlsx_body) = @http.get(
        base +
        @desk.workspace_json_table_url(
          "book-sheets",
          "data.xlsx",
          format="xlsx",
        ) +
        selected +
        filters,
      )
      assert_eq(xlsx_response.code, 200)
      let xlsx = xlsx_body.binary()
      guard @moonleaf.open("filtered.xlsx", xlsx.to_fixedarray())
        is WorkbookDocument(workbook) else {
        fail("expected exported workbook")
      }
      assert_eq(workbook.sheets.length(), 1)
      assert_eq(workbook.sheets[0].name, "Sales & 東京")
      assert_eq(
        table_from_sheet(workbook.sheets[0]).unwrap().text_rows(),
        expected[1:].to_owned(),
      )
      let (_, reset) = @http.get(url + selected)
      assert_true(reset.text().contains("Showing 5 of 5 saved rows"))
      let (_, empty) = @http.get(url + "&sheet=Empty")
      assert_true(empty.text().contains("Showing 0 of 0 saved rows"))
      let (bad, bad_body) = @http.get(
        url + selected + "&number_column=2&min=oops",
      )
      assert_eq(bad.code, 400)
      let bad_html = bad_body.text()
      assert_true(
        bad_html.contains("name=\"sheet\" value=\"Sales &amp; 東京\""),
      )
      assert_true(
        bad_html.contains("<option value=\"Sales &amp; 東京\" selected>"),
      )
      for format in ["html", "csv", "xlsx"] {
        let (missing, missing_body) = @http.get(
          base +
          @desk.workspace_json_table_url("book-sheets", "data.xlsx", format~) +
          "&sheet=missing",
        )
        assert_eq(missing.code, 400)
        assert_true(missing_body.text().contains("missing or ambiguous"))
      }
      let (_, other) = @http.get(
        base + @desk.workspace_json_table_url("book-sheets", "other.xlsx"),
      )
      assert_true(other.text().contains("Worksheet: <strong>Overview</strong>"))
      let (_, back) = @http.get(url + selected + filters)
      assert_eq(back.text(), html)
      assert_eq(@fs.read_file(book + "/data.xlsx").binary(), original)
      assert_eq(@fs.read_file(book + "/other.xlsx").binary(), original)
      if @env.get_env_var("MOONDESK_JSON_TABLE_EVIDENCE") is Some(evidence) {
        for
          (name, value) in [
            ("worksheets-default.html", first_html),
            ("worksheets-selected.html", html),
            ("worksheets-filter-error.html", bad_html),
            ("worksheets-filtered.csv", csv),
          ] {
          @fs.write_file(
            evidence + "/" + name,
            value,
            create_mode=CreateOrTruncate,
          )
        }
        @fs.write_file(
          evidence + "/worksheets-source.xlsx",
          original,
          create_mode=CreateOrTruncate,
        )
        @fs.write_file(
          evidence + "/worksheets-filtered.xlsx",
          xlsx,
          create_mode=CreateOrTruncate,
        )
      }
    })
  })
}
