///|
test "archive entry validation rejects zip slip absolute symlink duplicate and oversized entries" {
  assert_true(archive_entry_path("wiki/page.md") is Ok("wiki/page.md"))
  assert_true(archive_entry_path("../escape") is Err(_))
  assert_true(archive_entry_path("wiki/../../escape") is Err(_))
  assert_true(archive_entry_path("/absolute") is Err(_))
  assert_true(archive_entry_path("wiki\\escape") is Err(_))

  let receipt = archive_entries_receipt([
    { "path": "wiki/page.md", "kind": "file", "expanded_size": 12 },
    { "path": "wiki/page.md", "kind": "file", "expanded_size": 4 },
    { "path": "../escape", "kind": "file", "expanded_size": 1 },
    { "path": "link", "kind": "symlink", "expanded_size": 0 },
    { "path": "huge.bin", "kind": "file", "expanded_size": 9 * 1024 * 1024 },
  ])
  assert_true(json_bool(receipt, "staging_required", default=false))
  assert_eq(json_string(receipt, "overwrite_policy", default=""), "refuse")
  guard receipt
    is {
      "accepted": Array(accepted),
      "rejected": Array(rejected),
      "quarantined": Array(quarantined),
      ..
    } else {
    fail("archive receipt arrays missing")
  }
  assert_eq(accepted.length(), 1)
  assert_eq(rejected.length(), 3)
  assert_eq(quarantined.length(), 1)
}

///|
async test "actual workspace import route boundary rejects archives with typed receipt" {
  let root = @fs.tmpdir(prefix="moondesk-archive-import-")
  let workspace = @desk.workspace(
    id="book-security",
    name="Security",
    root_path=root,
    kind=MoonBook,
  )
  let result = import_workspace_files(workspace, {
    "archive_entries": [
      { "path": "../escape", "kind": "file", "expanded_size": 1 },
      { "path": "link", "kind": "symlink", "expanded_size": 0 },
    ],
  })
  guard result is Err(error) else { fail("archive import must be rejected") }
  assert_eq(json_int(error, "code", default=0), 415)
  guard error is { "receipt": receipt, .. } else {
    fail("typed archive receipt missing")
  }
  assert_eq(
    json_string(receipt, "kind", default=""),
    "moondesk.archive-import-receipt.v1",
  )
  assert_true(json_bool(receipt, "staging_required", default=false))
  assert_eq(
    json_string(receipt, "promotion_policy", default=""),
    "all-accepted-entries-verified-before-promotion",
  )
  assert_eq(@fs.readdir(root).length(), 0)
}
