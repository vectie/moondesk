///|
async test "large Markdown preview and save preserve the entire dissertation" {
  let root = @fs.tmpdir(prefix="moondesk-large-markdown-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let book = moonsuite_books_root(root) + "/research"
  @fs.mkdir(book + "/wiki", recursive=true)
  let source = "# Dissertation\n\n" +
    "A complete paragraph with a citation.\n\n".repeat(12000) +
    "## Final references\n\nThe last reference must survive.\n"
  assert_true(source.length() > 400000)
  @fs.write_file(
    book + "/wiki/dissertation.md",
    source,
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
    let (response, body) = @http.get(
      base +
      @desk.workspace_preview_url("book-research", "wiki/dissertation.md"),
    )
    assert_eq(response.code, 200)
    let preview = @json.parse(body.text())
    assert_eq(json_string(preview, "body", default=""), source)
    let edited = source + "\nAn author revision.\n"
    let (saved, _) = @http.post(
      base + @desk.workspace_endpoint_url("book-research", "markdown"),
      ({ "path": "wiki/dissertation.md", "content": edited } : Json).stringify(),
      headers={ "Origin": base, "Content-Type": "application/json" },
    )
    assert_eq(saved.code, 200)
    assert_eq(@fs.read_file(book + "/wiki/dissertation.md").text(), edited)
  })
}
