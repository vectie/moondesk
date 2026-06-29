///|
test "desk command palette stays navigation only" {
  let titles = palette_commands_for_mode(Desk).map(command => command.0)
  assert_eq(titles.length(), 3)
  assert_true(titles.contains("Browse Desk"))
  assert_true(titles.contains("Open in Wiki"))
  assert_true(titles.contains("Open MoonCode"))
  assert_false(titles.contains("Create Inbox Note"))
  assert_false(titles.contains("Import URL"))
  assert_false(titles.contains("Submit to Town"))
  assert_false(titles.contains("Run Daemon Tick"))
  assert_false(titles.contains("Start Daemon"))
}

///|
test "wiki command palette keeps operating commands" {
  let titles = palette_commands_for_mode(MoonWiki).map(command => command.0)
  assert_true(titles.contains("Browse Desk"))
  assert_true(titles.contains("Search Books"))
  assert_true(titles.contains("Create Inbox Note"))
  assert_true(titles.contains("Submit to Town"))
  assert_true(titles.contains("Start Daemon"))
}
