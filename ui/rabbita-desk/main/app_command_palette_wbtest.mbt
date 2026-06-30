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

///|
test "command palette filters titles and details" {
  let search_titles = filtered_palette_commands_for_mode(MoonWiki, "search").map(command => {
      command.0
    },
  )
  assert_eq(search_titles.length(), 1)
  assert_true(search_titles.contains("Search Books"))
  let daemon_titles = filtered_palette_commands_for_mode(MoonWiki, "DAEMON").map(command => {
      command.0
    },
  )
  assert_true(daemon_titles.contains("Run Daemon Tick"))
  assert_true(daemon_titles.contains("Start Daemon"))
  assert_true(daemon_titles.contains("Enable Supervision"))
  assert_true(daemon_titles.contains("Stop Daemon"))
  assert_false(daemon_titles.contains("Search Books"))
  let code_titles = filtered_palette_commands_for_mode(Desk, "mooncode").map(command => {
    command.0
  })
  assert_eq(code_titles.length(), 1)
  assert_true(code_titles.contains("Open MoonCode"))
  assert_eq(filtered_palette_commands_for_mode(Desk, "  ").length(), 3)
}

///|
test "command palette query updates and clears on toggle" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, queried) = update_navigation_actions(
    dispatch,
    SetCommandQuery("search"),
    init_model(),
  )
  assert_eq(queried.command_query, "search")
  let (_, opened) = update_navigation_actions(dispatch, ToggleCommand, queried)
  assert_true(opened.command_open)
  assert_eq(opened.command_query, "")
  let (_, typed) = update_navigation_actions(
    dispatch,
    SetCommandQuery("daemon"),
    opened,
  )
  let (_, closed) = update_navigation_actions(dispatch, ToggleCommand, typed)
  assert_false(closed.command_open)
  assert_eq(closed.command_query, "")
}
