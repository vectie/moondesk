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

///|
test "universal code search recognizes supported source paths only" {
  assert_true(is_code_search_path("src/main.mbt"))
  assert_true(is_code_search_path("ui/runtime.tsx"))
  assert_true(is_code_search_path("scripts/check.mjs"))
  assert_false(is_code_search_path("documents/report.docx"))
  assert_false(is_code_search_path("raw/archive.zip"))
}

///|
test "universal search providers explain meaning structure and issue matches" {
  let text = "# Revenue assumptions\nTODO: validate regional growth risk\npub fn calculate_growth() -> Int { 1 }\n"
  assert_true(
    search_match_detail("semantic", "report.md", text, "regional revenue")
    is Some(detail) &&
    detail.contains("Meaning match"),
  )
  assert_true(
    search_match_detail("structure", "report.md", text, "revenue")
    is Some(detail) &&
    detail.contains("Structure match"),
  )
  assert_true(
    search_match_detail("issues", "report.md", text, "risk") is Some(detail) &&
    detail.contains("Issue match"),
  )
  assert_true(
    search_match_detail("code", "main.mbt", text, "calculate_growth")
    is Some(detail) &&
    detail.contains("Code match"),
  )
}
