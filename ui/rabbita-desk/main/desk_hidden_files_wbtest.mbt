///|
test "desk hides dot files and dot folders by default and toggles them cleanly" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let entries : Array[@desk.DeskFileEntry] = [
    @desk.file_entry(
      workspace_id="opc-doctoral-research",
      path=".moonsuite",
      is_directory=true,
    ),
    @desk.file_entry(
      workspace_id="opc-doctoral-research",
      path=".git",
      is_directory=true,
    ),
    @desk.file_entry(workspace_id="opc-doctoral-research", path=".DS_Store"),
    @desk.file_entry(
      workspace_id="opc-doctoral-research",
      path="raw/.moonproj-deliveries",
      is_directory=true,
    ),
    @desk.file_entry(
      workspace_id="opc-doctoral-research",
      path="notes",
      is_directory=true,
    ),
    @desk.file_entry(
      workspace_id="opc-doctoral-research",
      path="notes/opening.md",
    ),
  ]
  let model = {
    ..init_model(),
    selected_workspace_id: "opc-doctoral-research",
    entries,
  }
  assert_false(model.desk_show_hidden)
  assert_eq(desk_hidden_entry_count(model), 4)
  assert_eq(filtered_desk_entries(model).length(), 2)
  assert_eq(filtered_desk_entries(model)[0].path, "notes")
  assert_eq(filtered_desk_entries(model)[1].path, "notes/opening.md")

  let outline_hidden = render_test_dom(
    @rabbita.static_cell(render_desk_folder_outline(dispatch, model)),
  )
  assert_false(outline_hidden.contains(".moonsuite"))
  assert_false(outline_hidden.contains(".git"))
  assert_true(outline_hidden.contains("notes"))

  let (_, toggled) = update_workspace_surface_actions(
    dispatch,
    ToggleDeskShowHidden,
    model,
  )
  assert_true(toggled.desk_show_hidden)
  assert_eq(filtered_desk_entries(toggled).length(), 6)

  let outline_shown = render_test_dom(
    @rabbita.static_cell(render_desk_folder_outline(dispatch, toggled)),
  )
  assert_true(outline_shown.contains(".moonsuite"))
  assert_true(outline_shown.contains(".git"))
}
