///|
test "JSON table HTML includes optional columns and export actions" {
  let table = @jsontable.parse(
    "[{\"name\":\"東京 <tag>\",\"amount\":4.25},{\"note\":{\"a\":1}}]",
  )
  let html = json_table_html("book-data", "data.json", table)
  assert_true(html.contains("2 rows · 3 columns"))
  assert_true(html.contains("東京 &lt;tag&gt;"))
  assert_true(html.contains("<th scope=\"col\">note</th>"))
  assert_true(html.contains("format=csv"))
  assert_true(html.contains("format=xlsx"))
  assert_true(json_table_path("DATA.JSONL"))
  assert_false(json_table_path("notes.md"))
}

///|
async test "JSON table reads saved workspace data without mutating source" {
  @moonlib/fsx.with_temporary_directory("moondesk-json-table-", root => {
    let workspace = @desk.workspace(
      id="book-data",
      name="Data",
      root_path=root,
      kind=MoonBook,
    )
    let content = "{\"name\":\"東京\",\"value\":12.5}\n{\"optional\":true,\"nested\":[1,2]}\n"
    @fs.write_file(root + "/records.jsonl", content, create_mode=CreateNew)
    let source = read_workspace_json_table(workspace, "records.jsonl").unwrap()
    let path = source.path
    let table = source.table
    assert_eq(path, "records.jsonl")
    assert_eq(table.columns, ["name", "value", "optional", "nested"])
    assert_eq(table.text_rows(), [
      ["東京", "12.5", "", ""],
      ["", "", "true", "[1,2]"],
    ])
    ignore(table.export_csv())
    ignore(table.export_xlsx())
    assert_eq(@fs.read_file(root + "/records.jsonl").text(), content)
  })
}
