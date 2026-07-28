///|
async test "Pages search scope availability fails closed" {
  let root = @pathx.join(
    "/tmp",
    "moondesk-search-scope-wbtest-" + @async.now().to_string(),
  )
  assert_false(search_scope_available(root))
  @fsx.make_directory(root, recursive=true, exists_ok=true)
  assert_true(search_scope_available(root))
}
