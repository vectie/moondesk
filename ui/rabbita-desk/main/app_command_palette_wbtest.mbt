///|
test "desk command palette exposes every primary destination" {
  let titles = palette_commands_for_mode(Desk).map(command => command.0)
  assert_eq(titles.length(), 9)
  assert_true(titles.contains("Open Packs"))
  assert_true(titles.contains("Open Home"))
  assert_true(titles.contains("Open Pages"))
  assert_true(titles.contains("Open Code"))
  assert_true(titles.contains("Open Flow"))
  assert_true(titles.contains("Open Requests"))
  assert_true(titles.contains("Open Runs"))
  assert_true(titles.contains("Open Review"))
  assert_true(titles.contains("Open Publish"))
  assert_false(titles.contains("Create Inbox Note"))
  assert_false(titles.contains("Import URL"))
  assert_false(titles.contains("Submit Request"))
  assert_false(titles.contains("Run Daemon Tick"))
  assert_false(titles.contains("Start Daemon"))
}

///|
test "wiki command palette exposes user jobs without runtime controls" {
  let titles = palette_commands_for_mode(MoonWiki).map(command => command.0)
  assert_eq(titles.length(), 12)
  assert_true(titles.contains("Open Home"))
  assert_true(titles.contains("Open Pages"))
  assert_true(titles.contains("Search Books"))
  assert_true(titles.contains("New Inbox Note"))
  assert_true(titles.contains("Open Requests"))
  assert_true(titles.contains("Open Review"))
  assert_true(titles.contains("Open Settings"))
  assert_true(titles.contains("Open Flow"))
  assert_false(titles.contains("Submit Request"))
  assert_false(titles.contains("Run Daemon Tick"))
  assert_false(titles.contains("Start Daemon"))
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
  assert_eq(daemon_titles.length(), 0)
  let code_daemon_titles = filtered_palette_commands_for_mode(
    MoonCode,
    "DAEMON",
  ).map(command => command.0)
  assert_true(code_daemon_titles.contains("Run Daemon Tick"))
  assert_true(code_daemon_titles.contains("Start Daemon"))
  assert_true(code_daemon_titles.contains("Enable Supervision"))
  assert_true(code_daemon_titles.contains("Stop Daemon"))
  let code_titles = filtered_palette_commands_for_mode(Desk, "code").map(command => {
    command.0
  })
  assert_eq(code_titles.length(), 1)
  assert_true(code_titles.contains("Open Code"))
  assert_eq(filtered_palette_commands_for_mode(Desk, "  ").length(), 9)
}

///|
test "Pack Home command palette keeps normal work ahead of internals" {
  let titles = palette_commands_for_mode(PackHome).map(command => command.0)
  assert_eq(titles.length(), 9)
  assert_true(titles.contains("Open Packs"))
  assert_true(titles.contains("Open Flow"))
  assert_true(titles.contains("Open Home"))
}

///|
test "MoonFlow palette keeps orchestration separate from editing" {
  let titles = palette_commands_for_mode(MoonFlow).map(command => command.0)
  assert_eq(titles.length(), 10)
  assert_true(titles.contains("Refresh Flow"))
  assert_true(titles.contains("Open Pages"))
  assert_true(titles.contains("Open Code"))
  assert_true(titles.contains("Open Home"))
  assert_true(titles.contains("Open Packs"))
  assert_false(titles.contains("Run Daemon Tick"))
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

///|
#warnings("-alert_unstable")
test "command palette owns dialog semantics and stable focus hooks" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let opened = { ..init_model(), command_open: true }
  let palette_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_command_palette(dispatch, opened)),
  )
  assert_true(palette_markup.contains("role=\"dialog\""))
  assert_true(palette_markup.contains("aria-modal=\"true\""))
  assert_true(palette_markup.contains("aria-label=\"Commands\""))
  assert_true(palette_markup.contains("data-testid=\"command-palette-panel\""))
  assert_true(palette_markup.contains("data-testid=\"command-palette-input\""))
  assert_true(palette_markup.contains("data-testid=\"command-palette-close\""))
  assert_true(palette_markup.contains("aria-hidden=\"true\""))
  let open_title_markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_title_bar(dispatch, opened)),
  )
  assert_true(open_title_markup.contains("aria-haspopup=\"dialog\""))
  assert_true(open_title_markup.contains("aria-expanded=\"true\""))
  let closed_title_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_title_bar(dispatch, { ..opened, command_open: false }),
    ),
  )
  assert_true(closed_title_markup.contains("aria-expanded=\"false\""))
}
