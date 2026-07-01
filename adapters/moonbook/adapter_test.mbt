///|
test "canonical sections expose executable book roots" {
  let paths = @moonbook.canonical_sections().map(section => section.path)
  assert_true(paths.contains("wiki"))
  assert_true(paths.contains("raw"))
  assert_true(paths.contains("skills"))
  assert_true(paths.contains("schemas"))
  assert_true(paths.contains("tools"))
  assert_true(paths.contains("apps"))
  assert_true(paths.contains("app"))
  assert_true(paths.contains("book/site/generated"))
  assert_true(paths.contains("site/generated"))
  assert_true(paths.contains("portable/app-tool"))
  assert_true(paths.contains("wiki/reviews"))
  assert_true(paths.contains(".moonsuite/products/moonclaw/jobs"))
  assert_false(paths.contains("moonclaw-jobs"))
}

///|
test "section entries preserve executable book source layers" {
  let entries = @moonbook.section_entries("book-demo")
  assert_true(
    entries.any(entry => entry.path == "skills" && entry.source_layer is Skill),
  )
  assert_true(
    entries.any(entry => entry.path == "schemas" && entry.source_layer is Schema),
  )
  assert_true(
    entries.any(entry => entry.path == "tools" && entry.source_layer is Tool),
  )
  assert_true(
    entries.any(entry => entry.path == "apps" && entry.source_layer is App),
  )
  assert_true(
    entries.any(entry => {
      entry.path == "portable/app-tool" && entry.source_layer is PortableAppTool
    }),
  )
}
