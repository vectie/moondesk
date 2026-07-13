///|
async test "browser evidence persistence is scoped durable and idempotent" {
  let stamp = @async.now().to_string()
  let root = "/tmp/moondesk-browser-evidence-\{stamp}"
  let book_root = @pathx.join(root, "books/browser-book")
  @fsx.make_directory(
    @pathx.join(book_root, "book/site/generated"),
    recursive=true,
    exists_ok=true,
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book.json"),
    "{\"id\":\"browser-book\",\"name\":\"Browser Book\"}\n",
  )
  @fsx.write_to_file(
    @pathx.join(book_root, "book/site/generated/index.html"), "<main>robot</main>",
  )
  let payload : Json = {
    "protocol": "moondesk-preview-evidence-v1",
    "request_id": "request-1",
    "source_path": "book/site/generated/index.html",
    "accessibility": "main Robot design",
    "resources": [],
  }
  let first = persist_browser_evidence(root, "book-browser-book", payload).unwrap()
  let changed : Json = {
    "protocol": "moondesk-preview-evidence-v1",
    "request_id": "request-1",
    "source_path": "book/site/generated/index.html",
    "accessibility": "changed after terminal delivery",
    "resources": [],
  }
  let second = persist_browser_evidence(root, "book-browser-book", changed).unwrap()
  assert_eq(
    json_string(first, "host_receipt_id", default=""),
    json_string(second, "host_receipt_id", default=""),
  )
  assert_true(second.stringify().contains("main Robot design"))
  assert_false(second.stringify().contains("changed after terminal delivery"))
  let evidence_ref = json_string(first, "evidence_ref", default="")
  assert_true(evidence_ref.has_prefix("book/evidence/browser/"))
  assert_true(@fs.exists(@pathx.join(book_root, evidence_ref)))
  assert_eq(
    json_string(first, "acceptance_status", default=""),
    "awaiting-bookkeeper-review",
  )
  let outside : Json = {
    "protocol": "moondesk-preview-evidence-v1",
    "request_id": "request-2",
    "source_path": "../../secret.txt",
  }
  assert_true(
    persist_browser_evidence(root, "book-browser-book", outside) is Err(_),
  )
  @fs.remove(@pathx.join(book_root, evidence_ref)) catch { _ => () }
  @fs.remove(@pathx.join(book_root, "book/evidence/browser")) catch { _ => () }
  @fs.remove(@pathx.join(book_root, "book/evidence")) catch { _ => () }
  @fs.remove(@pathx.join(book_root, "book/site/generated/index.html")) catch { _ => () }
  @fs.remove(@pathx.join(book_root, "book/site/generated")) catch { _ => () }
  @fs.remove(@pathx.join(book_root, "book/site")) catch { _ => () }
  @fs.remove(@pathx.join(book_root, "book.json")) catch { _ => () }
  @fs.remove(@pathx.join(book_root, "book")) catch { _ => () }
  @fs.remove(book_root) catch { _ => () }
  @fs.remove(@pathx.join(root, "books")) catch { _ => () }
  @fs.remove(root) catch { _ => () }
}
