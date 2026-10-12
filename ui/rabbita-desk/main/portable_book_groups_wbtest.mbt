///|
fn portable_group_test_ready() -> PortableBookState {
  let state = {
    ..portable_book_test_ready(),
    directory: "outputs/demo",
    entries: [
      portable_book_test_entry("outputs/demo/index.html", Text),
      portable_book_test_entry("outputs/demo/css/main.css", Text),
      portable_book_test_entry("outputs/demo/images/main.css", Text),
      portable_book_test_entry("elsewhere/file.txt", Text),
      portable_book_test_entry("outputs/demo/css", Directory),
    ],
  }
  reduce_portable_group(
    reduce_portable_group(state, NameNewGroup("Demo app")),
    AddGroup,
  )
}

///|
test "grouped deliverables preserve nested paths and separate equal basenames" {
  let empty = portable_group_test_ready()
  assert_false(portable_book_can_prepare(empty))
  let state = reduce_portable_group(
    empty,
    ToggleGroupFile("outputs/demo/index.html"),
  )
  let state = reduce_portable_group(
    state,
    ToggleGroupFile("outputs/demo/css/main.css"),
  )
  let state = reduce_portable_group(
    state,
    ToggleGroupFile("outputs/demo/images/main.css"),
  )
  assert_true(portable_book_can_prepare(state))
  assert_eq(state.output_groups[0].files.map(file => file.path), [
    "index.html", "css/main.css", "images/main.css",
  ])
  assert_eq(
    reduce_portable_group(state, ToggleGroupFile("elsewhere/file.txt")).output_groups,
    state.output_groups,
  )
  assert_eq(
    reduce_portable_group(state, ToggleGroupFile("outputs/demo/css")).output_groups,
    state.output_groups,
  )
  let group = state.output_groups[0]
  assert_eq(
    portable_book_group_relative(group, "outputs/demo-too/index.html"),
    None,
  )
  assert_eq(
    portable_book_group_relative(
      { ..group, root: "", },
      "outputs/demo/index.html",
    ),
    Some("outputs/demo/index.html"),
  )
}

///|
test "group preview and entrypoint only select members and clear on removal" {
  let state = reduce_portable_group(
    portable_group_test_ready(),
    ToggleGroupFile("outputs/demo/index.html"),
  )
  let state = reduce_portable_group(
    state,
    ChooseGroupPreview("group-1", "index.html"),
  )
  let state = reduce_portable_group(
    state,
    ChooseGroupEntrypoint("group-1", "index.html"),
  )
  assert_eq(state.output_groups[0].app_entrypoint, Some("index.html"))
  assert_eq(
    reduce_portable_group(state, ChooseGroupPreview("group-1", "missing.html")).output_groups,
    state.output_groups,
  )
  let wire = portable_book_group_wire(state.output_groups[0])
  assert_true(
    wire
    is {
      "mime_type": "text/html",
      "preview_path": "index.html",
      "app_entrypoint": "index.html",
      ..
    },
  )
  let removed = reduce_portable_group(
    state,
    RemoveGroupFile("group-1", "outputs/demo/index.html"),
  )
  assert_eq(removed.output_groups[0].preview_path, None)
  assert_eq(removed.output_groups[0].app_entrypoint, None)
  assert_false(portable_book_can_prepare(removed))
  assert_true(
    portable_book_can_prepare(
      reduce_portable_group(removed, RemoveGroup("group-1")),
    ),
  )
}

///|
test "grouped preparation preserves flat and human result inputs without duplicate pack" {
  let state = {
    ..reduce_portable_group(
      portable_group_test_ready(),
      ToggleGroupFile("outputs/demo/index.html"),
    ),
    paths: ["standalone.txt"],
    accepted_human_result: Some(portable_human_test_source()),
  }
  let (pending, effect) = reduce_portable_book(
    state,
    Prepare(portable_book_test_id()),
  )
  assert_true(
    effect
    is PreparePortableGroupedPackage(
      0,
      1,
      _,
      "1.2.3",
      ["standalone.txt"],
      [_],
      Some(_)
    ),
  )
  let (_, duplicate) = reduce_portable_book(
    pending,
    Prepare(portable_book_test_id()),
  )
  assert_true(duplicate is NoPortableEffect)
  assert_eq(
    reduce_portable_group(pending, RemoveGroup("group-1")).output_groups,
    pending.output_groups,
  )
  let body = portable_book_grouped_body(
    "/library-a",
    portable_book_test_id(),
    "1.2.3",
    state.paths,
    state.output_groups,
    Some("ZXhhY3Q="),
  )
  assert_true(
    body
    is {
      "paths": ["standalone.txt"],
      "accepted_human_result_base64": "ZXhhY3Q=",
      "output_groups": [
        {
          "files": [
            { "source_path": "outputs/demo/index.html", "path": "index.html" },
          ],
          ..
        },
      ],
      ..
    },
  )
}

///|
test "grouped drafts survive refresh but never cross Books or bypass uncertain preparation" {
  let state = reduce_portable_group(
    portable_group_test_ready(),
    ToggleGroupFile("outputs/demo/index.html"),
  )
  let (refresh, _) = reduce_portable_book(state, RefreshCatalog)
  assert_eq(refresh.output_groups, state.output_groups)
  let (other, _) = reduce_portable_book(
    state,
    BindPortable(true, "/library-a", "book-b"),
  )
  assert_true(other.output_groups.is_empty())
  let (pending, _) = reduce_portable_book(
    state,
    Prepare(portable_book_test_id()),
  )
  let (uncertain, _) = reduce_portable_book(pending, TimedOut(0, 1))
  assert_eq(
    reduce_portable_group(uncertain, RenameGroup("group-1", "new")).output_groups,
    state.output_groups,
  )
  let (checking, effect) = reduce_portable_book(uncertain, CheckPreparation)
  assert_true(effect is InspectPortablePackage(0, 2, _))
  assert_eq(checking.output_groups, state.output_groups)
  assert_true(init_portable_book().output_groups.is_empty())
}

///|
test "named deliverable ids do not reuse deleted group identities and case collisions stay visible" {
  let state = reduce_portable_group(
    portable_group_test_ready(),
    ToggleGroupFile("outputs/demo/index.html"),
  )
  let state = {
    ..state,
    entries: [portable_book_test_entry("outputs/demo/INDEX.html", Text)],
  }
  let blocked = reduce_portable_group(
    state,
    ToggleGroupFile("outputs/demo/INDEX.html"),
  )
  assert_eq(blocked.output_groups, state.output_groups)
  assert_true(blocked.error.contains("conflicts"))
  let removed = reduce_portable_group(state, RemoveGroup("group-1"))
  let next = reduce_portable_group(
    reduce_portable_group(removed, NameNewGroup("Report")),
    AddGroup,
  )
  assert_eq(next.output_groups[0].artifact_id, "group-2")
}

///|
test "named deliverable view offers actual file actions with no acknowledgment gate" {
  let state = reduce_portable_group(
    portable_group_test_ready(),
    ToggleGroupFile("outputs/demo/index.html"),
  )
  let dispatch : Dispatch[Msg] = _ => @rabbita.none
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_portable_book_groups(dispatch, state)),
  )
  for
    text in [
      "Demo app", "index.html", "Choose as preview", "Choose as app entrypoint",
      "Remove file", "outputs/demo",
    ] {
    assert_true(markup.contains(text))
  }
  assert_false(markup.contains("checkbox"))
  let picker = @rabbita.render_to_string(
    @rabbita.static_cell(render_portable_book_picker(dispatch, state)),
  )
  assert_true(picker.contains("In Demo app: index.html"))
  assert_true(picker.contains("Add to Demo app: css/main.css"))
  assert_true(picker.contains("Outside Demo app folder"))
}
