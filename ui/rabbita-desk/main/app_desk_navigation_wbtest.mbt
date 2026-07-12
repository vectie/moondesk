///|
test "desk breadcrumbs expose clickable path segments" {
  let crumbs = desk_breadcrumbs("book/site/generated")
  assert_eq(crumbs.length(), 4)
  assert_eq(crumbs[0].0, "root")
  assert_eq(crumbs[0].1, "")
  assert_false(crumbs[0].2)
  assert_eq(crumbs[1].0, "book")
  assert_eq(crumbs[1].1, "book")
  assert_eq(crumbs[2].0, "site")
  assert_eq(crumbs[2].1, "book/site")
  assert_eq(crumbs[3].0, "generated")
  assert_eq(crumbs[3].1, "book/site/generated")
  assert_true(crumbs[3].2)
}

///|
test "desk root breadcrumb is active at project root" {
  let crumbs = desk_breadcrumbs("")
  assert_eq(crumbs.length(), 1)
  assert_eq(crumbs[0].0, "root")
  assert_true(crumbs[0].2)
}

///|
test "desk path helpers find containing directories" {
  assert_eq(parent_path("wiki/index.md"), "wiki")
  assert_eq(
    parent_path("book/site/generated/index.html"),
    "book/site/generated",
  )
  assert_eq(parent_path("wiki"), "")
  assert_eq(parent_path(""), "")
}

///|
test "desk quick path opens containing directory and preserves scoped selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, next) = update_navigation_actions(
    dispatch,
    OpenQuickPath("wiki/notes/alpha.md"),
    {
      ..init_model(),
      selected_workspace_id: "book-demo",
      current_directory: "raw",
      desk_location_input: "raw",
      desk_filter_query: "evidence",
    },
  )
  assert_eq(next.selected_path, "wiki/notes/alpha.md")
  assert_eq(next.current_directory, "wiki/notes")
  assert_eq(next.desk_location_input, "wiki/notes")
  assert_eq(next.desk_filter_query, "")
  assert_true(next.desk_selected_paths == ["wiki/notes/alpha.md"])
  assert_eq(next.preview_status, "loading preview")
}

///|
test "desk favorite action and labels toggle selected paths" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = { ..init_model(), selected_path: "wiki/index.md" }
  assert_eq(desk_favorite_button_label(base, "wiki/index.md"), "Add Favorite")
  let (_, favorited) = update_workspace_surface_actions(
    dispatch,
    ToggleFavorite("wiki/index.md"),
    base,
  )
  assert_true(favorited.favorites == ["wiki/index.md"])
  assert_eq(
    desk_favorite_button_label(favorited, "wiki/index.md"),
    "Remove Favorite",
  )
  assert_eq(
    desk_favorite_button_class(favorited, "wiki/index.md"),
    "secondary-button full active",
  )
  let (_, removed) = update_workspace_surface_actions(
    dispatch,
    ToggleFavorite("wiki/index.md"),
    favorited,
  )
  assert_true(removed.favorites == [])
}

///|
test "desk folder outline includes root and current child directories" {
  let outline = desk_folder_outline("", [
    @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
    @desk.file_entry(workspace_id="book-demo", path="raw", is_directory=true),
    @desk.file_entry(workspace_id="book-demo", path="book.json"),
  ])
  assert_eq(outline.length(), 3)
  assert_eq(outline[0].0, "root")
  assert_eq(outline[0].1, "")
  assert_true(outline[0].2)
  assert_eq(outline[1].0, "wiki")
  assert_eq(outline[1].1, "wiki")
  assert_false(outline[1].2)
  assert_eq(outline[1].3, 1)
  assert_eq(outline[2].0, "raw")
  assert_eq(outline[2].1, "raw")
}

///|
test "desk folder outline keeps ancestor chain for nested directory" {
  let outline = desk_folder_outline("book/site", [
    @desk.file_entry(
      workspace_id="book-demo",
      path="book/site/generated",
      is_directory=true,
    ),
    @desk.file_entry(workspace_id="book-demo", path="book/site/index.html"),
  ])
  assert_eq(outline.length(), 4)
  assert_eq(outline[0].1, "")
  assert_eq(outline[1].1, "book")
  assert_eq(outline[1].3, 1)
  assert_false(outline[1].2)
  assert_eq(outline[2].1, "book/site")
  assert_eq(outline[2].3, 2)
  assert_true(outline[2].2)
  assert_eq(outline[3].1, "book/site/generated")
  assert_eq(outline[3].3, 3)
  assert_false(outline[3].2)
}

///|
test "desk entry counts split folders and files" {
  let counts = desk_entry_counts([
    @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
    @desk.file_entry(workspace_id="book-demo", path="raw", is_directory=true),
    @desk.file_entry(workspace_id="book-demo", path="book.json"),
    @desk.file_entry(workspace_id="book-demo", path="wiki/index.md"),
  ])
  assert_eq(counts.0, 4)
  assert_eq(counts.1, 2)
  assert_eq(counts.2, 2)
  assert_eq(desk_entry_count_label(counts), "4 items, 2 folders, 2 files")
}

///|
test "desk multi selection details summarize counts and known size" {
  let model = {
    ..init_model(),
    desk_selected_paths: ["wiki", "wiki/index.md", "raw/evidence.txt"],
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
      @desk.file_entry(
        workspace_id="book-demo",
        path="wiki/index.md",
        size_bytes=Some(24),
      ),
      @desk.file_entry(
        workspace_id="book-demo",
        path="raw/evidence.txt",
        size_bytes=Some(4096),
      ),
    ],
  }
  assert_eq(
    desk_multi_selection_count_label(model),
    "3 items, 1 folder, 2 files",
  )
  assert_eq(desk_multi_selection_size_label(model), "4 KB known")
  let files_only = {
    ..model,
    desk_selected_paths: ["wiki/index.md", "raw/evidence.txt"],
  }
  assert_eq(desk_multi_selection_size_label(files_only), "4 KB")
  let missing = { ..init_model(), desk_selected_paths: ["wiki/missing.md"] }
  assert_eq(desk_multi_selection_count_label(missing), "1 selected")
  assert_eq(desk_multi_selection_size_label(missing), "-")
}

///|
test "desk selection label uses virtual root for empty path" {
  assert_eq(desk_selection_label(init_model()), "No selection")
  let model = { ..init_model(), selected_path: "wiki/index.md" }
  assert_eq(desk_selection_label(model), "Selected wiki/index.md")
}

///|
test "desk access labels distinguish browse and writable entries" {
  assert_eq(desk_access_label(None), "Browse only")
  assert_eq(
    desk_access_label(
      Some(@desk.file_entry(workspace_id="book-demo", path="book.json")),
    ),
    "Read-only",
  )
  assert_eq(
    desk_access_label(
      Some(
        @desk.file_entry(
          workspace_id="book-demo",
          path="wiki/index.md",
          writable=true,
        ),
      ),
    ),
    "Writable",
  )
}

///|
test "desk size labels use compact units" {
  assert_eq(size_label(None), "-")
  assert_eq(size_label(Some(24)), "24 B")
  assert_eq(size_label(Some(4096)), "4 KB")
  assert_eq(size_label(Some(3 * 1024 * 1024)), "3 MB")
}

///|
test "desk sort headers show active direction" {
  let model = init_model()
  assert_eq(desk_sort_header_label(model, SortByName, "Name"), "Name ^")
  assert_eq(desk_sort_header_label(model, SortBySize, "Size"), "Size")
  let desc = { ..model, desk_sort_desc: true }
  assert_eq(desk_sort_header_label(desc, SortByName, "Name"), "Name v")
}

///|
test "desk sort action toggles current column and resets new columns" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, by_size) = update_workspace_surface_actions(
    dispatch,
    SetDeskSort(SortBySize),
    init_model(),
  )
  assert_true(by_size.desk_sort_key is SortBySize)
  assert_false(by_size.desk_sort_desc)
  let (_, size_desc) = update_workspace_surface_actions(
    dispatch,
    SetDeskSort(SortBySize),
    by_size,
  )
  assert_true(size_desc.desk_sort_key is SortBySize)
  assert_true(size_desc.desk_sort_desc)
  let (_, by_modified) = update_workspace_surface_actions(
    dispatch,
    SetDeskSort(SortByModified),
    size_desc,
  )
  assert_true(by_modified.desk_sort_key is SortByModified)
  assert_false(by_modified.desk_sort_desc)
}

///|
test "desk density action updates presentation without changing selection context" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    selected_path: "wiki/index.md",
    desk_selected_paths: ["wiki/index.md"],
    preview_status: "preview ready",
  }
  let (_, compact) = update_workspace_surface_actions(
    dispatch,
    SetDeskDensity(DeskDensityCompact),
    model,
  )
  assert_true(compact.desk_density is DeskDensityCompact)
  assert_eq(compact.current_directory, "wiki")
  assert_eq(compact.selected_path, "wiki/index.md")
  assert_true(compact.desk_selected_paths == ["wiki/index.md"])
  assert_eq(compact.preview_status, "preview ready")
  assert_eq(desk_file_table_class(compact), "desk-file-table density-compact")
  assert_eq(
    desk_density_button_class(compact, DeskDensityCompact),
    "secondary-button compact-button density-button active",
  )
  let (_, comfortable) = update_workspace_surface_actions(
    dispatch,
    SetDeskDensity(DeskDensityComfortable),
    compact,
  )
  assert_true(comfortable.desk_density is DeskDensityComfortable)
  assert_eq(
    desk_file_table_class(comfortable),
    "desk-file-table density-comfortable",
  )
}

///|
test "desk reveal target uses selection or current directory" {
  assert_eq(
    reveal_target_path({
      ..init_model(),
      current_directory: "wiki",
      selected_path: "wiki/index.md",
    }),
    "wiki/index.md",
  )
  assert_eq(
    reveal_target_path({ ..init_model(), current_directory: "wiki/notes" }),
    "wiki/notes",
  )
  assert_eq(reveal_target_path(init_model()), "")
}

///|
test "desk empty folder state uses file-manager language" {
  let no_workspace = init_model()
  assert_eq(desk_empty_folder_title(no_workspace), "No MoonBook selected")
  assert_eq(
    desk_empty_folder_message(no_workspace),
    "Select or create a MoonBook to browse its files.",
  )
  let root = { ..init_model(), selected_workspace_id: "book-demo" }
  assert_eq(desk_empty_folder_title(root), "This MoonBook root is empty")
  assert_eq(
    desk_empty_folder_message(root),
    "Create a folder, create a note, import files, or paste items into this MoonBook.",
  )
  let child = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki/notes",
  }
  assert_eq(desk_empty_folder_title(child), "This folder is empty")
  assert_eq(
    desk_empty_folder_message(child),
    "Create a folder, create a note, import files, or paste items into wiki/notes.",
  )
}

///|
test "desk create moonbook action tracks draft and opens created book" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  assert_true(desk_workspace_action_disabled(init_model()))
  assert_false(
    desk_workspace_action_disabled({
      ..init_model(),
      selected_workspace_id: "book-demo",
    }),
  )
  let empty_draft = { ..init_model(), new_book_name: "", new_book_id: "" }
  assert_true(desk_create_book_disabled(empty_draft))
  assert_false(desk_create_book_disabled(init_model()))
  let (_, named) = update_workspace_surface_actions(
    dispatch,
    SetNewBookName("Field Notes"),
    init_model(),
  )
  assert_eq(named.new_book_name, "Field Notes")
  assert_eq(named.new_book_id, "research-field-notes")
  assert_false(desk_create_book_disabled(named))
  let (_, creating) = update_workspace_surface_actions(
    dispatch,
    CreateBlankMoonBook,
    named,
  )
  assert_eq(creating.new_book_status, "creating MoonBook")
  let (_, opened) = update_workspace_results(
    dispatch,
    CreatedBlankMoonBook(
      Ok({
        workspace_id: "book-research-field-notes",
        book_id: "research-field-notes",
        name: "Field Notes",
        path: "wiki/index.md",
      }),
    ),
    creating,
  )
  assert_eq(opened.selected_workspace_id, "book-research-field-notes")
  assert_eq(opened.selected_path, "wiki/index.md")
  assert_eq(opened.current_directory, "wiki")
  assert_eq(opened.new_book_name, "")
  assert_eq(opened.new_book_id, "")
  assert_true(desk_create_book_disabled(opened))
  assert_eq(opened.new_book_status, "created research-field-notes")
  assert_eq(opened.host_status, "created MoonBook Field Notes")
}

///|
test "desk import moonbook action opens imported book in library" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  assert_true(desk_import_book_disabled(init_model()))
  let (_, draft) = update_workspace_surface_actions(
    dispatch,
    SetImportBookPath("/Users/demo/Field Notes"),
    init_model(),
  )
  assert_eq(draft.import_book_path, "/Users/demo/Field Notes")
  assert_eq(draft.import_book_status, "draft import path")
  assert_false(desk_import_book_disabled(draft))
  let (_, blocked) = update_workspace_surface_actions(
    dispatch,
    ImportMoonBook,
    { ..draft, import_book_path: "" },
  )
  assert_eq(blocked.import_book_status, "enter a MoonBook folder path")
  let (_, importing) = update_workspace_surface_actions(
    dispatch,
    ImportMoonBook,
    draft,
  )
  assert_eq(importing.import_book_status, "importing MoonBook")
  let (_, opened) = update_workspace_results(
    dispatch,
    ImportedMoonBook(
      Ok({
        workspace_id: "book-field-notes",
        book_id: "field-notes",
        name: "Field Notes",
        path: "wiki/index.md",
      }),
    ),
    importing,
  )
  assert_eq(opened.selected_workspace_id, "book-field-notes")
  assert_eq(opened.selected_path, "wiki/index.md")
  assert_eq(opened.current_directory, "wiki")
  assert_eq(opened.import_book_path, "")
  assert_eq(opened.import_book_status, "imported field-notes")
  assert_eq(opened.host_status, "imported MoonBook Field Notes")
}

///|
test "desk archive picker action imports picked archive payload" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, choosing) = update_workspace_surface_actions(
    dispatch,
    PickImportMoonBookArchive,
    init_model(),
  )
  assert_eq(choosing.import_book_status, "choose a MoonBook .zip archive")
  let picked_file : LocalImportFile = {
    id: "archive-1",
    name: "Field Notes.zip",
    relative_path: Some(""),
    media_type: "application/zip",
    content: "data:application/zip;base64,UEs=",
    source: "moonbook-archive-picker",
  }
  let (_, importing) = update_workspace_results(
    dispatch,
    LocalMoonBookArchivePicked(Ok(picked_file)),
    choosing,
  )
  assert_eq(importing.import_book_path, "")
  assert_eq(
    importing.import_book_status,
    "importing MoonBook archive Field Notes.zip",
  )
  let (_, failed) = update_workspace_results(
    dispatch,
    LocalMoonBookArchivePicked(Err("No archive selected")),
    choosing,
  )
  assert_eq(
    failed.import_book_status,
    "archive import failed: No archive selected",
  )
}

///|
test "desk folder picker action imports picked moonbook folder payload" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, choosing) = update_workspace_surface_actions(
    dispatch,
    PickImportMoonBookFolder,
    init_model(),
  )
  assert_eq(choosing.import_book_status, "choose a MoonBook folder")
  let files : Array[LocalImportFile] = [
    {
      id: "folder-book-json",
      name: "book.json",
      relative_path: Some("Field Notes/book.json"),
      media_type: "application/json",
      content: "{\"name\":\"Field Notes\"}",
      source: "folder-picker",
    },
    {
      id: "folder-index",
      name: "index.md",
      relative_path: Some("Field Notes/wiki/index.md"),
      media_type: "text/markdown",
      content: "# Field Notes\n",
      source: "folder-picker",
    },
  ]
  let (_, importing) = update_workspace_results(
    dispatch,
    LocalMoonBookFolderPicked(Ok(files)),
    choosing,
  )
  assert_eq(importing.import_book_path, "")
  assert_eq(importing.import_book_status, "importing MoonBook folder")
  let (_, empty) = update_workspace_results(
    dispatch,
    LocalMoonBookFolderPicked(Ok([])),
    choosing,
  )
  assert_eq(empty.import_book_status, "no MoonBook folder selected")
  let (_, failed) = update_workspace_results(
    dispatch,
    LocalMoonBookFolderPicked(Err("Folder picker unavailable")),
    choosing,
  )
  assert_eq(
    failed.import_book_status,
    "folder import failed: Folder picker unavailable",
  )
}

///|
test "desk create item actions validate name and open created entry" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
  }
  let (_, named) = update_workspace_surface_actions(
    dispatch,
    SetDeskNewItemName("Notes"),
    model,
  )
  assert_eq(named.desk_new_item_name, "Notes")
  assert_eq(named.desk_new_item_status, "draft item name")
  let (_, creating) = update_workspace_surface_actions(
    dispatch,
    CreateDeskFolder,
    named,
  )
  assert_eq(creating.desk_new_item_status, "creating folder")
  let (_, opened) = update_workspace_results(
    dispatch,
    CreatedDeskEntry(
      Ok({ workspace_id: "book-demo", path: "wiki/Notes", directory: "wiki" }),
    ),
    creating,
  )
  assert_eq(opened.selected_path, "wiki/Notes")
  assert_eq(opened.current_directory, "wiki")
  assert_true(opened.desk_selected_paths == ["wiki/Notes"])
  assert_eq(opened.desk_new_item_name, "Untitled")
  assert_eq(opened.desk_new_item_status, "created wiki/Notes")
}

///|
test "desk new folder shortcut uses current directory" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, blocked) = desk_keydown_action(dispatch, "N", true, true, {
    ..init_model(),
    workspace_mode: Desk,
  })
  assert_eq(blocked.desk_new_item_status, "select a MoonBook first")
  let (_, creating) = desk_keydown_action(dispatch, "N", true, true, {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    desk_new_item_name: "Shortcut Notes",
  })
  assert_eq(creating.desk_new_item_status, "creating folder")
  let (_, typing) = desk_keydown_action(dispatch, "n", false, false, creating)
  assert_eq(typing.desk_new_item_status, "creating folder")
}

///|
test "desk rename action validates selection and opens renamed entry" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/old.md",
    desk_selected_paths: ["wiki/old.md"],
    desk_rename_editing_path: "wiki/old.md",
    desk_rename_name: "new",
    current_directory: "wiki",
  }
  let (_, named) = update_workspace_surface_actions(
    dispatch,
    SetDeskRenameName("new-title"),
    model,
  )
  assert_eq(named.desk_rename_name, "new-title")
  assert_eq(named.desk_rename_status, "draft rename")
  let (_, renaming) = update_workspace_surface_actions(
    dispatch,
    RenameDeskSelection,
    named,
  )
  assert_eq(renaming.desk_rename_status, "renaming selection")
  let (_, opened) = update_workspace_results(
    dispatch,
    RenamedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/new-title.md",
        directory: "wiki",
      }),
    ),
    renaming,
  )
  assert_eq(opened.selected_path, "wiki/new-title.md")
  assert_eq(opened.current_directory, "wiki")
  assert_true(opened.desk_selected_paths == ["wiki/new-title.md"])
  assert_eq(opened.desk_rename_editing_path, "")
  assert_eq(opened.desk_rename_name, "new-title.md")
  assert_eq(opened.desk_rename_status, "renamed wiki/new-title.md")
}

///|
test "desk F2 starts inline rename and Escape cancels editing" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/old.md",
    desk_selected_paths: ["wiki/old.md"],
    current_directory: "wiki",
  }
  let (_, editing) = desk_keydown_action(dispatch, "F2", false, false, base)
  assert_eq(editing.desk_rename_editing_path, "wiki/old.md")
  assert_eq(editing.desk_rename_name, "old.md")
  assert_eq(editing.desk_rename_status, "editing rename")
  let (_, ignored_typing) = desk_keydown_action(
    dispatch, "n", false, false, editing,
  )
  assert_eq(ignored_typing.selected_path, "wiki/old.md")
  assert_eq(ignored_typing.desk_rename_editing_path, "wiki/old.md")
  let (_, named) = update_workspace_surface_actions(
    dispatch,
    SetDeskRenameName("new-inline"),
    editing,
  )
  let (_, renaming) = desk_keydown_action(
    dispatch, "Enter", false, false, named,
  )
  assert_eq(renaming.desk_rename_status, "renaming selection")
  let (_, canceled) = desk_keydown_action(
    dispatch, "Escape", false, false, editing,
  )
  assert_eq(canceled.desk_rename_editing_path, "")
  assert_eq(canceled.desk_rename_status, "rename canceled")
}

///|
test "desk inline rename blocks multi selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, blocked) = desk_keydown_action(dispatch, "F2", false, false, {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/alpha.md",
    desk_selected_paths: ["wiki/alpha.md", "wiki/beta.md"],
  })
  assert_eq(blocked.desk_rename_editing_path, "")
  assert_eq(blocked.desk_rename_status, "rename one item at a time")
}

///|
test "desk rename action blocks multi selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, blocked) = update_workspace_surface_actions(
    dispatch,
    RenameDeskSelection,
    {
      ..init_model(),
      selected_workspace_id: "book-demo",
      selected_path: "wiki/alpha.md",
      desk_selected_paths: ["wiki/alpha.md", "wiki/beta.md"],
      desk_rename_name: "renamed",
    },
  )
  assert_eq(blocked.desk_rename_status, "rename one item at a time")
}

///|
test "desk move action validates target and opens moved entry" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/old.md",
    desk_selected_paths: ["wiki/old.md"],
    desk_move_target_directory: "wiki/archive",
    current_directory: "wiki",
  }
  let (_, targeted) = update_workspace_surface_actions(
    dispatch,
    SetDeskMoveTargetDirectory("raw/archive"),
    model,
  )
  assert_eq(targeted.desk_move_target_directory, "raw/archive")
  assert_eq(targeted.desk_move_status, "draft move target")
  let (_, moving) = update_workspace_surface_actions(
    dispatch,
    MoveDeskSelection,
    targeted,
  )
  assert_eq(moving.desk_move_status, "moving selection")
  let (_, opened) = update_workspace_results(
    dispatch,
    MovedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "raw/archive/old.md",
        directory: "raw/archive",
        moved_count: 1,
      }),
    ),
    moving,
  )
  assert_eq(opened.selected_path, "raw/archive/old.md")
  assert_eq(opened.current_directory, "raw/archive")
  assert_true(opened.desk_selected_paths == ["raw/archive/old.md"])
  assert_eq(opened.desk_rename_name, "old.md")
  assert_eq(opened.desk_move_target_directory, "raw/archive")
  assert_eq(opened.desk_move_status, "moved raw/archive/old.md")
}

///|
test "desk move action accepts multi selection and blocks missing target" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/alpha.md",
    desk_selected_paths: ["wiki/alpha.md"],
  }
  let (_, missing_target) = update_workspace_surface_actions(
    dispatch,
    MoveDeskSelection,
    base,
  )
  assert_eq(missing_target.desk_move_status, "enter a target directory")
  let (_, moving) = update_workspace_surface_actions(
    dispatch,
    MoveDeskSelection,
    {
      ..base,
      desk_selected_paths: ["wiki/alpha.md", "wiki/beta.md"],
      desk_move_target_directory: "raw",
    },
  )
  assert_eq(moving.desk_move_status, "moving 2 items")
  let (_, moved) = update_workspace_results(
    dispatch,
    MovedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "raw/alpha.md",
        directory: "raw",
        moved_count: 2,
      }),
    ),
    moving,
  )
  assert_eq(moved.selected_path, "raw/alpha.md")
  assert_eq(moved.desk_move_status, "moved 2 items")
}

///|
test "desk duplicate action accepts single and multi selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/alpha.md",
    desk_selected_paths: ["wiki/alpha.md"],
    current_directory: "wiki",
  }
  let (_, copying) = update_workspace_surface_actions(
    dispatch,
    DuplicateDeskSelection,
    base,
  )
  assert_eq(copying.desk_copy_status, "duplicating selection")
  let (_, copied) = update_workspace_results(
    dispatch,
    CopiedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/alpha copy.md",
        directory: "wiki",
        copied_count: 1,
      }),
    ),
    copying,
  )
  assert_eq(copied.selected_path, "wiki/alpha copy.md")
  assert_eq(copied.current_directory, "wiki")
  assert_true(copied.desk_selected_paths == ["wiki/alpha copy.md"])
  assert_eq(copied.desk_copy_status, "duplicated wiki/alpha copy.md")
  let (_, batch_copying) = update_workspace_surface_actions(
    dispatch,
    DuplicateDeskSelection,
    { ..base, desk_selected_paths: ["wiki/alpha.md", "wiki/beta.md"] },
  )
  assert_eq(batch_copying.desk_copy_status, "duplicating 2 items")
  let (_, batch_copied) = update_workspace_results(
    dispatch,
    CopiedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/alpha copy.md",
        directory: "wiki",
        copied_count: 2,
      }),
    ),
    batch_copying,
  )
  assert_eq(batch_copied.selected_path, "wiki/alpha copy.md")
  assert_eq(batch_copied.desk_copy_status, "duplicated 2 items")
}

///|
test "desk duplicate action blocks missing workspace and selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, missing_workspace) = update_workspace_surface_actions(
    dispatch,
    DuplicateDeskSelection,
    init_model(),
  )
  assert_eq(missing_workspace.desk_copy_status, "select a MoonBook first")
  let (_, missing_selection) = update_workspace_surface_actions(
    dispatch,
    DuplicateDeskSelection,
    { ..init_model(), selected_workspace_id: "book-demo" },
  )
  assert_eq(missing_selection.desk_copy_status, "select an item to duplicate")
}

///|
test "desk clipboard copy and paste track current directory" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/alpha.md",
    desk_selected_paths: ["wiki/alpha.md"],
    current_directory: "wiki/target",
  }
  let (_, copied_to_clipboard) = update_workspace_surface_actions(
    dispatch,
    CopyDeskSelection,
    base,
  )
  assert_true(copied_to_clipboard.desk_clipboard_paths == ["wiki/alpha.md"])
  assert_eq(copied_to_clipboard.desk_clipboard_workspace_id, "book-demo")
  assert_eq(copied_to_clipboard.desk_clipboard_status, "copied wiki/alpha.md")
  let (_, pasting) = update_workspace_surface_actions(
    dispatch,
    PasteDeskClipboard,
    copied_to_clipboard,
  )
  assert_eq(pasting.desk_clipboard_status, "pasting selection")
  let (_, pasted) = update_workspace_results(
    dispatch,
    CopiedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/target/alpha.md",
        directory: "wiki/target",
        copied_count: 1,
      }),
    ),
    pasting,
  )
  assert_eq(pasted.selected_path, "wiki/target/alpha.md")
  assert_eq(pasted.current_directory, "wiki/target")
  assert_true(pasted.desk_selected_paths == ["wiki/target/alpha.md"])
  assert_eq(pasted.desk_clipboard_status, "pasted wiki/target/alpha.md")
  assert_eq(pasted.host_status, "pasted wiki/target/alpha.md")
  let (_, batch_clipboard) = update_workspace_surface_actions(
    dispatch,
    CopyDeskSelection,
    { ..base, desk_selected_paths: ["wiki/alpha.md", "wiki/beta.md"] },
  )
  assert_true(
    batch_clipboard.desk_clipboard_paths == ["wiki/alpha.md", "wiki/beta.md"],
  )
  assert_eq(batch_clipboard.desk_clipboard_status, "copied 2 items")
  let (_, batch_pasting) = update_workspace_surface_actions(
    dispatch,
    PasteDeskClipboard,
    batch_clipboard,
  )
  assert_eq(batch_pasting.desk_clipboard_status, "pasting 2 items")
  let (_, batch_pasted) = update_workspace_results(
    dispatch,
    CopiedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/target/alpha.md",
        directory: "wiki/target",
        copied_count: 2,
      }),
    ),
    batch_pasting,
  )
  assert_eq(batch_pasted.desk_clipboard_status, "pasted 2 items")
}

///|
test "desk clipboard cut and paste moves then clears clipboard" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/alpha.md",
    desk_selected_paths: ["wiki/alpha.md"],
    current_directory: "wiki/target",
  }
  let (_, cut_to_clipboard) = update_workspace_surface_actions(
    dispatch,
    CutDeskSelection,
    base,
  )
  assert_true(cut_to_clipboard.desk_clipboard_paths == ["wiki/alpha.md"])
  assert_eq(cut_to_clipboard.desk_clipboard_workspace_id, "book-demo")
  assert_eq(cut_to_clipboard.desk_clipboard_operation, "cut")
  assert_eq(cut_to_clipboard.desk_clipboard_status, "cut wiki/alpha.md")
  let (_, moving_clipboard) = update_workspace_surface_actions(
    dispatch,
    PasteDeskClipboard,
    cut_to_clipboard,
  )
  assert_eq(
    moving_clipboard.desk_clipboard_status,
    "moving clipboard selection",
  )
  let (_, moved_clipboard) = update_workspace_results(
    dispatch,
    MovedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/target/alpha.md",
        directory: "wiki/target",
        moved_count: 1,
      }),
    ),
    moving_clipboard,
  )
  assert_eq(moved_clipboard.selected_path, "wiki/target/alpha.md")
  assert_eq(moved_clipboard.current_directory, "wiki/target")
  assert_true(moved_clipboard.desk_selected_paths == ["wiki/target/alpha.md"])
  assert_true(moved_clipboard.desk_clipboard_paths == [])
  assert_eq(moved_clipboard.desk_clipboard_workspace_id, "")
  assert_eq(moved_clipboard.desk_clipboard_operation, "")
  assert_eq(
    moved_clipboard.desk_clipboard_status,
    "moved clipboard wiki/target/alpha.md",
  )
  assert_eq(moved_clipboard.host_status, "moved clipboard wiki/target/alpha.md")
  let (_, batch_cut) = update_workspace_surface_actions(
    dispatch,
    CutDeskSelection,
    { ..base, desk_selected_paths: ["wiki/alpha.md", "wiki/beta.md"] },
  )
  assert_eq(batch_cut.desk_clipboard_status, "cut 2 items")
  let (_, batch_moving) = update_workspace_surface_actions(
    dispatch,
    PasteDeskClipboard,
    batch_cut,
  )
  assert_eq(batch_moving.desk_clipboard_status, "moving clipboard 2 items")
  let (_, batch_moved) = update_workspace_results(
    dispatch,
    MovedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/target/alpha.md",
        directory: "wiki/target",
        moved_count: 2,
      }),
    ),
    batch_moving,
  )
  assert_true(batch_moved.desk_clipboard_paths == [])
  assert_eq(batch_moved.desk_clipboard_status, "moved clipboard 2 items")
}

///|
test "desk clipboard copy and paste block invalid state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, copy_missing_workspace) = update_workspace_surface_actions(
    dispatch,
    CopyDeskSelection,
    init_model(),
  )
  assert_eq(
    copy_missing_workspace.desk_clipboard_status,
    "select a MoonBook first",
  )
  let (_, copy_missing_selection) = update_workspace_surface_actions(
    dispatch,
    CopyDeskSelection,
    { ..init_model(), selected_workspace_id: "book-demo" },
  )
  assert_eq(
    copy_missing_selection.desk_clipboard_status,
    "select items to copy",
  )
  let (_, cut_missing_selection) = update_workspace_surface_actions(
    dispatch,
    CutDeskSelection,
    { ..init_model(), selected_workspace_id: "book-demo" },
  )
  assert_eq(cut_missing_selection.desk_clipboard_status, "select items to cut")
  let (_, paste_missing_workspace) = update_workspace_surface_actions(
    dispatch,
    PasteDeskClipboard,
    { ..init_model(), desk_clipboard_paths: ["wiki/alpha.md"] },
  )
  assert_eq(
    paste_missing_workspace.desk_clipboard_status,
    "select a MoonBook first",
  )
  let (_, paste_empty_clipboard) = update_workspace_surface_actions(
    dispatch,
    PasteDeskClipboard,
    { ..init_model(), selected_workspace_id: "book-demo" },
  )
  assert_eq(paste_empty_clipboard.desk_clipboard_status, "clipboard empty")
  let (_, paste_other_workspace) = update_workspace_surface_actions(
    dispatch,
    PasteDeskClipboard,
    {
      ..init_model(),
      selected_workspace_id: "book-other",
      desk_clipboard_workspace_id: "book-demo",
      desk_clipboard_paths: ["wiki/alpha.md"],
    },
  )
  assert_eq(
    paste_other_workspace.desk_clipboard_status,
    "clipboard belongs to another MoonBook",
  )
}

///|
test "desk copy path action copies scoped virtual paths" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    selected_path: "wiki/index.md",
  }
  assert_eq(desk_path_clipboard_text(model), "wiki/index.md")
  assert_eq(desk_path_copied_status(model), "copied path wiki/index.md")
  let multi = {
    ..model,
    desk_selected_paths: ["wiki/index.md", "raw/evidence.txt"],
  }
  assert_eq(desk_path_clipboard_text(multi), "wiki/index.md\nraw/evidence.txt")
  assert_eq(desk_path_copied_status(multi), "copied 2 paths")
  let current_folder = { ..model, selected_path: "", desk_selected_paths: [] }
  assert_eq(desk_path_clipboard_text(current_folder), "wiki")
  let root = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "",
  }
  assert_eq(desk_path_clipboard_text(root), "/")
}

///|
test "desk copy path action updates status without changing desk clipboard" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, missing_workspace) = update_workspace_surface_actions(
    dispatch,
    CopyDeskPath,
    init_model(),
  )
  assert_eq(missing_workspace.desk_path_status, "select a MoonBook first")
  let (_, copied) = update_workspace_surface_actions(dispatch, CopyDeskPath, {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
    desk_clipboard_paths: ["raw/evidence.txt"],
    desk_clipboard_operation: "copy",
    desk_clipboard_status: "copied raw/evidence.txt",
  })
  assert_eq(copied.desk_path_status, "copied path wiki/index.md")
  assert_true(copied.desk_clipboard_paths == ["raw/evidence.txt"])
  assert_eq(copied.desk_clipboard_operation, "copy")
  assert_eq(copied.desk_clipboard_status, "copied raw/evidence.txt")
}

///|
test "app update routes desk duplicate result to workspace results" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, copied) = update(
    dispatch,
    CopiedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/alpha copy.md",
        directory: "wiki",
        copied_count: 1,
      }),
    ),
    { ..init_model(), selected_workspace_id: "book-demo" },
  )
  assert_eq(copied.selected_path, "wiki/alpha copy.md")
  assert_eq(copied.desk_copy_status, "duplicated wiki/alpha copy.md")
}

///|
test "desk trash action clears selection and restore opens item" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "wiki/old.md",
    desk_selected_paths: ["wiki/old.md"],
    current_directory: "wiki",
  }
  let (_, trashing) = update_workspace_surface_actions(
    dispatch,
    TrashDeskSelection,
    model,
  )
  assert_eq(trashing.desk_trash_status, "moving selection to trash")
  let (_, trashed) = update_workspace_results(
    dispatch,
    TrashedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/old.md",
        directory: "wiki",
        trash_path: ".moonsuite/products/moondesk/trash/files/trash-demo/old.md",
        trashed_count: 1,
      }),
    ),
    trashing,
  )
  assert_eq(trashed.selected_path, "")
  assert_true(trashed.desk_selected_paths == [])
  assert_eq(
    trashed.desk_last_trash_path,
    ".moonsuite/products/moondesk/trash/files/trash-demo/old.md",
  )
  assert_eq(trashed.desk_trash_status, "moved to trash wiki/old.md")
  let (_, restoring) = update_workspace_surface_actions(
    dispatch,
    RestoreLastTrashedDeskEntry,
    trashed,
  )
  assert_eq(restoring.desk_trash_status, "restoring last trashed item")
  let (_, restored) = update_workspace_results(
    dispatch,
    RestoredDeskEntry(
      Ok({ workspace_id: "book-demo", path: "wiki/old.md", directory: "wiki" }),
    ),
    restoring,
  )
  assert_eq(restored.selected_path, "wiki/old.md")
  assert_true(restored.desk_selected_paths == ["wiki/old.md"])
  assert_eq(restored.desk_last_trash_path, "")
  assert_eq(restored.desk_trash_status, "restored wiki/old.md")
}

///|
test "desk trash listing loads entries and restores selected trash item" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, loaded) = update_workspace_results(
    dispatch,
    LoadedDeskTrash(
      Ok([
        {
          workspace_id: "book-demo",
          original_path: "wiki/old.md",
          trash_path: ".moonsuite/products/moondesk/trash/files/trash-demo/old.md",
          receipt_path: ".moonsuite/products/moondesk/trash/receipts/trash-demo.json",
          trashed_at: "2026-06-30T10:00:00Z",
        },
      ]),
    ),
    { ..init_model(), selected_workspace_id: "book-demo" },
  )
  assert_eq(loaded.desk_trash_entries.length(), 1)
  assert_eq(loaded.desk_trash_entries[0].original_path, "wiki/old.md")
  assert_eq(loaded.desk_trash_status, "1 item(s) in trash")
  let (_, restoring) = update_workspace_surface_actions(
    dispatch,
    RestoreDeskTrashEntry(
      ".moonsuite/products/moondesk/trash/files/trash-demo/old.md",
    ),
    loaded,
  )
  assert_eq(restoring.desk_trash_status, "restoring trash item")
}

///|
test "desk local file import stays in current directory" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    activity: Files,
    selected_workspace_id: "book-demo",
    current_directory: "wiki/drop-target",
  }
  let (_, picking) = update_workspace_surface_actions(
    dispatch,
    ImportLocalFilesToDesk,
    model,
  )
  assert_true(picking.workspace_mode is Desk)
  assert_true(picking.activity is Files)
  assert_eq(picking.desk_new_item_status, "opening file picker")
  let (_, folder_picking) = update_workspace_surface_actions(
    dispatch,
    ImportLocalFolderToDesk,
    model,
  )
  assert_true(folder_picking.workspace_mode is Desk)
  assert_true(folder_picking.activity is Files)
  assert_eq(folder_picking.desk_new_item_status, "opening folder picker")
  let (_, importing) = update_app_results(
    dispatch,
    LocalFilesPicked(
      Ok([
        {
          id: "drop:report.txt:11:1",
          name: "report.txt",
          relative_path: Some("local-folder/report.txt"),
          media_type: "text/plain",
          content: "new report\n",
          source: "drop",
        },
      ]),
    ),
    picking,
  )
  assert_true(importing.activity is Files)
  assert_eq(importing.desk_new_item_status, "importing 1 local file(s)")
  let (_, stale_activity_importing) = update_app_results(
    dispatch,
    LocalFilesPicked(
      Ok([
        {
          id: "drop:stale.txt:5:1",
          name: "stale.txt",
          relative_path: None,
          media_type: "text/plain",
          content: "stale",
          source: "drop",
        },
      ]),
    ),
    { ..model, activity: Inbox },
  )
  assert_true(stale_activity_importing.workspace_mode is Desk)
  assert_true(stale_activity_importing.activity is Inbox)
  assert_eq(
    stale_activity_importing.desk_new_item_status,
    "importing 1 local file(s)",
  )
  let (_, imported) = update_workspace_results(
    dispatch,
    ImportedDeskFiles(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/drop-target/report.txt",
        directory: "wiki/drop-target",
        imported_count: 1,
      }),
    ),
    importing,
  )
  assert_eq(imported.selected_path, "wiki/drop-target/report.txt")
  assert_true(imported.desk_selected_paths == ["wiki/drop-target/report.txt"])
  assert_eq(imported.current_directory, "wiki/drop-target")
  assert_eq(
    imported.desk_new_item_status,
    "imported wiki/drop-target/report.txt",
  )
}

///|
test "desk trash action accepts multi selection and blocks empty restore" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, trashing) = update_workspace_surface_actions(
    dispatch,
    TrashDeskSelection,
    {
      ..init_model(),
      selected_workspace_id: "book-demo",
      selected_path: "wiki/alpha.md",
      desk_selected_paths: ["wiki/alpha.md", "wiki/beta.md"],
    },
  )
  assert_eq(trashing.desk_trash_status, "moving 2 items to trash")
  let (_, trashed) = update_workspace_results(
    dispatch,
    TrashedDeskEntry(
      Ok({
        workspace_id: "book-demo",
        path: "wiki/alpha.md",
        directory: "wiki",
        trash_path: ".moonsuite/products/moondesk/trash/files/trash-beta/beta.md",
        trashed_count: 2,
      }),
    ),
    trashing,
  )
  assert_eq(trashed.selected_path, "")
  assert_true(trashed.desk_selected_paths == [])
  assert_eq(trashed.desk_trash_status, "moved 2 items to trash")
  let (_, restore_blocked) = update_workspace_surface_actions(
    dispatch,
    RestoreLastTrashedDeskEntry,
    { ..init_model(), selected_workspace_id: "book-demo" },
  )
  assert_eq(restore_blocked.desk_trash_status, "nothing to restore")
}

///|
test "desk create item blocks empty names" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, blocked) = update_workspace_surface_actions(
    dispatch,
    CreateDeskMarkdown,
    {
      ..init_model(),
      selected_workspace_id: "book-demo",
      desk_new_item_name: "",
    },
  )
  assert_eq(blocked.desk_new_item_status, "enter a name")
}

///|
test "desk workspace refresh preserves selected path for known workspace" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    selected_path: "wiki/index.md",
  }
  let (_, refreshed) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(
      Ok([
        @desk.workspace(
          id="book-demo",
          name="Demo",
          root_path="/tmp/moonsuite/books/demo",
          kind=MoonBook,
        ),
      ]),
    ),
    model,
  )
  assert_eq(refreshed.selected_workspace_id, "book-demo")
  assert_eq(refreshed.selected_path, "wiki/index.md")
}

///|
test "desk library root derives dedicated user data directory" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    workspaces: [
      @desk.workspace(
        id="book-demo",
        name="Demo",
        root_path="/Users/example/moonsuite/books/demo",
        kind=MoonBook,
      ),
      @desk.workspace(
        id="book-lab",
        name="Lab",
        root_path="/Users/example/moonsuite/books/lab",
        kind=MoonBook,
      ),
    ],
  }
  assert_eq(workspace_library_root(model), "/Users/example/moonsuite")
  assert_eq(
    workspace_moonbook_library_path(model),
    "/Users/example/moonsuite/books",
  )
  assert_eq(workspace_library_count_label(model), "2 MoonBooks")
}

///|
test "desk empty library uses workspace metadata path" {
  let model = {
    ..init_model(),
    workspace_root_path: "/Users/example/moonsuite",
    workspace_library_path: "/Users/example/moonsuite/books",
  }
  assert_eq(workspace_name(model), "MoonSuite: moonsuite")
  assert_eq(workspace_root(model), "/Users/example/moonsuite")
  assert_eq(workspace_library_root(model), "/Users/example/moonsuite")
  assert_eq(
    workspace_moonbook_library_path(model),
    "/Users/example/moonsuite/books",
  )
  assert_eq(workspace_library_count_label(model), "0 MoonBooks")
}

///|
test "desk workspace status labels expose incomplete moonbooks" {
  assert_eq(workspace_status_key(Ready), "ready")
  assert_eq(workspace_status_label(Ready), "Ready")
  assert_eq(workspace_status_class(Ready), "status-ready")
  assert_eq(workspace_status_key(NeedsAttention), "needs-attention")
  assert_eq(workspace_status_label(NeedsAttention), "Needs setup")
  assert_eq(workspace_status_class(NeedsAttention), "status-needs-attention")
}

///|
test "workspace metadata result records empty library location" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, model) = update_workspace_results(
    dispatch,
    LoadedWorkspaceMetadata(
      Ok({
        root_path: "/Users/example/moonsuite",
        suite_root: "/Users/example/moonsuite",
        active_suite_root: "/Users/example/moonsuite",
        library_path: "/Users/example/moonsuite/books",
        books_root: "/Users/example/moonsuite/books",
        products: [
          { name: "MoonDesk", status: "installed" },
          { name: "MoonClaw", status: "installed" },
          { name: "MoonRobo", status: "installed" },
        ],
      }),
    ),
    init_model(),
  )
  assert_eq(model.workspace_root_path, "/Users/example/moonsuite")
  assert_eq(model.workspace_library_path, "/Users/example/moonsuite/books")
  assert_eq(model.moonsuite_products.length(), 3)
  assert_eq(workspace_product_count_label(model), "3 products installed")
  assert_eq(workspace_display_products(model).length(), 3)
  assert_eq(
    workspace_product_chip_title(model.moonsuite_products[0]),
    "MoonDesk: Installed",
  )
  assert_eq(
    workspace_product_chip_title(model.moonsuite_products[2]),
    "MoonRobo: Installed",
  )
}

///|
test "desk sorted entries keep folders first and sort files by selected column" {
  let entries = [
    @desk.file_entry(
      workspace_id="book-demo",
      path="wiki/beta.md",
      size_bytes=Some(20),
      modified_at=Some("2026-06-02T00:00:00Z"),
    ),
    @desk.file_entry(workspace_id="book-demo", path="raw", is_directory=true),
    @desk.file_entry(
      workspace_id="book-demo",
      path="wiki/alpha.md",
      size_bytes=Some(10),
      modified_at=Some("2026-06-01T00:00:00Z"),
    ),
    @desk.file_entry(
      workspace_id="book-demo",
      path="wiki/gamma.md",
      size_bytes=Some(30),
      modified_at=Some("2026-06-03T00:00:00Z"),
    ),
  ]
  let by_name = sorted_desk_entries({ ..init_model(), entries, })
  assert_eq(by_name[0].path, "raw")
  assert_eq(by_name[1].path, "wiki/alpha.md")
  assert_eq(by_name[2].path, "wiki/beta.md")
  assert_eq(by_name[3].path, "wiki/gamma.md")
  let by_size_desc = sorted_desk_entries({
    ..init_model(),
    entries,
    desk_sort_key: SortBySize,
    desk_sort_desc: true,
  })
  assert_eq(by_size_desc[0].path, "raw")
  assert_eq(by_size_desc[1].path, "wiki/gamma.md")
  assert_eq(by_size_desc[2].path, "wiki/beta.md")
  assert_eq(by_size_desc[3].path, "wiki/alpha.md")
  let by_modified = sorted_desk_entries({
    ..init_model(),
    entries,
    desk_sort_key: SortByModified,
  })
  assert_eq(by_modified[1].path, "wiki/alpha.md")
  assert_eq(by_modified[3].path, "wiki/gamma.md")
}

///|
test "desk filter narrows visible entries by name or path" {
  let entries = [
    @desk.file_entry(
      workspace_id="book-demo",
      path="wiki/notes",
      is_directory=true,
    ),
    @desk.file_entry(workspace_id="book-demo", path="wiki/alpha.md"),
    @desk.file_entry(workspace_id="book-demo", path="raw/evidence.txt"),
  ]
  let filtered = sorted_desk_entries({
    ..init_model(),
    entries,
    desk_filter_query: "note",
  })
  assert_eq(filtered.length(), 1)
  assert_eq(filtered[0].path, "wiki/notes")
  let path_filtered = sorted_desk_entries({
    ..init_model(),
    entries,
    desk_filter_query: "RAW/",
  })
  assert_eq(path_filtered.length(), 1)
  assert_eq(path_filtered[0].path, "raw/evidence.txt")
  assert_eq(
    desk_entry_count_label_for_model(
      { ..init_model(), entries, desk_filter_query: "raw" },
      desk_entry_counts(path_filtered),
      path_filtered.length(),
    ),
    "1 of 3 shown",
  )
}

///|
test "desk filter action updates query and keyboard uses filtered rows" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="wiki/alpha.md"),
      @desk.file_entry(workspace_id="book-demo", path="wiki/beta.md"),
      @desk.file_entry(workspace_id="book-demo", path="raw/evidence.txt"),
    ],
  }
  let (_, filtered) = update_workspace_surface_actions(
    dispatch,
    SetDeskFilterQuery("beta"),
    model,
  )
  assert_eq(filtered.desk_filter_query, "beta")
  let (_, selected) = desk_keydown_action(
    dispatch, "ArrowDown", false, false, filtered,
  )
  assert_eq(selected.selected_path, "wiki/beta.md")
  assert_true(selected.desk_selected_paths == ["wiki/beta.md"])
  let (_, cleared) = update_navigation_actions(
    dispatch,
    OpenDirectory("raw"),
    filtered,
  )
  assert_eq(cleared.current_directory, "raw")
  assert_eq(cleared.desk_filter_query, "")
}

///|
test "desk filter clears hidden focused selection and stale preview" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let entries = [
    @desk.file_entry(workspace_id="book-demo", path="wiki/alpha.md"),
    @desk.file_entry(workspace_id="book-demo", path="wiki/beta.md"),
  ]
  let (_, filtered) = update_workspace_surface_actions(
    dispatch,
    SetDeskFilterQuery("beta"),
    {
      ..init_model(),
      workspace_mode: Desk,
      selected_workspace_id: "book-demo",
      selected_path: "wiki/alpha.md",
      desk_selected_paths: ["wiki/alpha.md"],
      desk_selection_anchor: "wiki/alpha.md",
      desk_rename_editing_path: "wiki/alpha.md",
      desk_rename_name: "alpha.md",
      desk_move_target_directory: "wiki",
      desk_path_status: "copied path wiki/alpha.md",
      entries,
      preview: Some(
        @desk.preview(
          @desk.file_entry(workspace_id="book-demo", path="wiki/alpha.md"),
          body="# Alpha\n",
        ),
      ),
      preview_status: "preview ready",
    },
  )
  assert_eq(filtered.selected_path, "")
  assert_true(filtered.desk_selected_paths == [])
  assert_eq(filtered.desk_selection_anchor, "")
  assert_eq(filtered.desk_rename_editing_path, "")
  assert_eq(filtered.desk_rename_name, "")
  assert_eq(filtered.desk_move_target_directory, "")
  assert_eq(filtered.desk_path_status, "ready to copy path")
  assert_true(filtered.preview is None)
  assert_eq(filtered.preview_status, "selection hidden by filter")
}

///|
test "desk filter moves focus to retained visible multi selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, filtered) = update_workspace_surface_actions(
    dispatch,
    SetDeskFilterQuery("beta"),
    {
      ..init_model(),
      workspace_mode: Desk,
      selected_workspace_id: "book-demo",
      selected_path: "wiki/alpha.md",
      desk_selected_paths: ["wiki/alpha.md", "wiki/beta.md"],
      desk_selection_anchor: "wiki/alpha.md",
      entries: [
        @desk.file_entry(workspace_id="book-demo", path="wiki/alpha.md"),
        @desk.file_entry(workspace_id="book-demo", path="wiki/beta.md"),
      ],
      preview_status: "preview ready",
    },
  )
  assert_eq(filtered.selected_path, "wiki/beta.md")
  assert_true(filtered.desk_selected_paths == ["wiki/beta.md"])
  assert_eq(filtered.desk_selection_anchor, "wiki/beta.md")
  assert_eq(filtered.desk_rename_name, "beta.md")
  assert_eq(filtered.desk_move_target_directory, "wiki")
  assert_eq(filtered.preview_status, "loading filtered selection")
}

///|
test "desk keyboard arrows move selection without opening folders" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "",
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
      @desk.file_entry(workspace_id="book-demo", path="book.json"),
    ],
  }
  let (_, first) = desk_keydown_action(
    dispatch, "ArrowDown", false, false, model,
  )
  assert_eq(first.selected_path, "wiki")
  assert_eq(first.current_directory, "")
  assert_true(first.desk_selected_paths == ["wiki"])
  assert_eq(first.preview_status, "loading selection")
  let (_, second) = desk_keydown_action(
    dispatch, "ArrowDown", false, false, first,
  )
  assert_eq(second.selected_path, "book.json")
  assert_true(second.desk_selected_paths == ["book.json"])
}

///|
test "desk keyboard shift arrows extend contiguous selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    selected_path: "wiki/alpha.md",
    desk_selected_paths: ["wiki/alpha.md"],
    desk_selection_anchor: "wiki/alpha.md",
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="wiki/alpha.md"),
      @desk.file_entry(workspace_id="book-demo", path="wiki/beta.md"),
      @desk.file_entry(workspace_id="book-demo", path="wiki/gamma.md"),
    ],
  }
  let (_, next) = desk_keydown_action(dispatch, "ArrowDown", true, false, model)
  assert_eq(next.selected_path, "wiki/beta.md")
  assert_eq(next.desk_selection_anchor, "wiki/alpha.md")
  assert_true(next.desk_selected_paths == ["wiki/alpha.md", "wiki/beta.md"])
  assert_eq(desk_selection_label(next), "2 selected")
}

///|
test "desk keyboard typeahead enter and escape follow file explorer expectations" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "",
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="raw", is_directory=true),
      @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
      @desk.file_entry(workspace_id="book-demo", path="book.json"),
    ],
  }
  let (_, typed) = desk_keydown_action(dispatch, "w", false, false, model)
  assert_eq(typed.selected_path, "wiki")
  assert_eq(typed.current_directory, "")
  let (_, opened) = desk_keydown_action(dispatch, "Enter", false, false, typed)
  assert_eq(opened.selected_path, "wiki")
  assert_eq(opened.current_directory, "wiki")
  assert_true(opened.desk_back_stack == [""])
  assert_true(opened.desk_forward_stack == [])
  let (_, cleared) = desk_keydown_action(
    dispatch, "Escape", false, false, opened,
  )
  assert_eq(cleared.selected_path, "")
  assert_true(cleared.desk_selected_paths == [])
  assert_eq(cleared.preview_status, "selection cleared")
}

///|
test "desk directory history supports back and forward navigation" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "",
  }
  let (_, wiki) = update_navigation_actions(
    dispatch,
    OpenDirectory("wiki"),
    base,
  )
  assert_eq(wiki.current_directory, "wiki")
  assert_eq(wiki.desk_location_input, "wiki")
  assert_true(wiki.desk_back_stack == [""])
  assert_true(wiki.desk_forward_stack == [])
  assert_eq(wiki.preview_status, "loading directory")
  let (_, notes) = update_navigation_actions(
    dispatch,
    OpenDirectory("wiki/notes"),
    wiki,
  )
  assert_eq(notes.current_directory, "wiki/notes")
  assert_eq(notes.desk_location_input, "wiki/notes")
  assert_true(notes.desk_back_stack == ["", "wiki"])
  assert_true(notes.desk_forward_stack == [])
  let (_, back_to_wiki) = update_navigation_actions(
    dispatch,
    NavigateDeskBack,
    notes,
  )
  assert_eq(back_to_wiki.current_directory, "wiki")
  assert_eq(back_to_wiki.desk_location_input, "wiki")
  assert_true(back_to_wiki.desk_back_stack == [""])
  assert_true(back_to_wiki.desk_forward_stack == ["wiki/notes"])
  assert_eq(back_to_wiki.preview_status, "loading previous directory")
  let (_, back_to_root) = update_navigation_actions(
    dispatch,
    NavigateDeskBack,
    back_to_wiki,
  )
  assert_eq(back_to_root.current_directory, "")
  assert_eq(back_to_root.desk_location_input, "")
  assert_true(back_to_root.desk_back_stack == [])
  assert_true(back_to_root.desk_forward_stack == ["wiki/notes", "wiki"])
  let (_, forward_to_wiki) = update_navigation_actions(
    dispatch,
    NavigateDeskForward,
    back_to_root,
  )
  assert_eq(forward_to_wiki.current_directory, "wiki")
  assert_eq(forward_to_wiki.desk_location_input, "wiki")
  assert_true(forward_to_wiki.desk_back_stack == [""])
  assert_true(forward_to_wiki.desk_forward_stack == ["wiki/notes"])
  assert_eq(forward_to_wiki.preview_status, "loading next directory")
}

///|
test "desk location bar opens typed directory paths" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  assert_eq(desk_location_path_from_input(" /wiki/notes/ "), "wiki/notes")
  assert_eq(desk_location_path_from_input("wiki/./notes"), "wiki/notes")
  assert_eq(desk_location_path_from_input("wiki//notes"), "wiki/notes")
  assert_eq(desk_location_path_from_input("wiki/../raw"), "raw")
  assert_eq(
    desk_location_path_from_input("wiki\\notes\\..\\index.md"),
    "wiki/index.md",
  )
  assert_eq(desk_location_path_from_input("../outside"), "")
  assert_eq(desk_location_path_from_input("wiki/../../outside"), "")
  assert_eq(desk_location_path_from_input("root"), "")
  assert_eq(desk_location_path_from_input("(root)"), "")
  let base = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "",
  }
  let (_, typed) = update_navigation_actions(
    dispatch,
    SetDeskLocationInput(" /wiki/notes/ "),
    base,
  )
  assert_eq(typed.desk_location_input, " /wiki/notes/ ")
  let (_, opened) = update_navigation_actions(dispatch, OpenDeskLocation, typed)
  assert_eq(opened.current_directory, "wiki/notes")
  assert_eq(opened.desk_location_input, "wiki/notes")
  assert_eq(opened.selected_path, "wiki/notes")
  assert_true(opened.desk_back_stack == [""])
}

///|
test "desk directory history avoids duplicates and resets on branch navigation" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let base = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    desk_back_stack: [""],
    desk_forward_stack: ["wiki/notes"],
  }
  let (_, same) = update_navigation_actions(
    dispatch,
    OpenDirectory("wiki"),
    base,
  )
  assert_true(same.desk_back_stack == [""])
  assert_true(same.desk_forward_stack == [])
  let (_, branched) = update_navigation_actions(
    dispatch,
    OpenDirectory("raw"),
    base,
  )
  assert_eq(branched.current_directory, "raw")
  assert_true(branched.desk_back_stack == ["", "wiki"])
  assert_true(branched.desk_forward_stack == [])
}

///|
test "desk directory history resets when switching MoonBooks" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, switched) = update_navigation_actions(
    dispatch,
    SelectWorkspace("book-next"),
    {
      ..init_model(),
      workspace_mode: Desk,
      selected_workspace_id: "book-demo",
      current_directory: "wiki/notes",
      desk_back_stack: ["", "wiki"],
      desk_forward_stack: ["raw"],
    },
  )
  assert_eq(switched.selected_workspace_id, "book-next")
  assert_true(switched.desk_back_stack == [])
  assert_true(switched.desk_forward_stack == [])
  assert_eq(switched.current_directory, "")
}

///|
test "desk folder refresh reports recoverable connection feedback" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, refreshing) = update_workspace_surface_actions(
    dispatch,
    RefreshAll,
    init_model(),
  )
  assert_eq(refreshing.desk_new_item_status, "Refreshing folder...")
  let (_, failed) = update_workspace_results(
    dispatch,
    LoadedEntries(Err("Invalid Desk entries response")),
    refreshing,
  )
  assert_eq(
    failed.desk_new_item_status,
    "Couldn't refresh this folder. Check the connection and try Refresh again.",
  )
  let (_, recovered) = update_workspace_results(
    dispatch,
    LoadedEntries(Ok([])),
    failed,
  )
  assert_eq(recovered.desk_new_item_status, "")
  assert_eq(recovered.host_status, "workspace indexed")
}

///|
test "desk keyboard shortcuts copy cut paste and trash selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    selected_path: "wiki/alpha.md",
    desk_selected_paths: ["wiki/alpha.md"],
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="wiki/alpha.md"),
      @desk.file_entry(workspace_id="book-demo", path="wiki/beta.md"),
      @desk.file_entry(workspace_id="book-demo", path="wiki/gamma.md"),
    ],
  }
  let (_, selected_all) = desk_keydown_action(dispatch, "a", false, true, model)
  assert_true(
    selected_all.desk_selected_paths ==
    ["wiki/alpha.md", "wiki/beta.md", "wiki/gamma.md"],
  )
  assert_eq(selected_all.selected_path, "wiki/alpha.md")
  assert_eq(desk_selection_label(selected_all), "3 selected")
  let (_, copied) = desk_keydown_action(dispatch, "c", false, true, model)
  assert_eq(copied.desk_clipboard_operation, "copy")
  assert_true(copied.desk_clipboard_paths == ["wiki/alpha.md"])
  assert_eq(copied.desk_clipboard_status, "copied wiki/alpha.md")
  let (_, cut) = desk_keydown_action(dispatch, "X", false, true, model)
  assert_eq(cut.desk_clipboard_operation, "cut")
  assert_true(cut.desk_clipboard_paths == ["wiki/alpha.md"])
  assert_eq(cut.desk_clipboard_status, "cut wiki/alpha.md")
  let (_, paste_copy) = desk_keydown_action(dispatch, "v", false, true, copied)
  assert_eq(paste_copy.desk_clipboard_status, "pasting selection")
  let (_, paste_cut) = desk_keydown_action(dispatch, "v", false, true, cut)
  assert_eq(paste_cut.desk_clipboard_status, "moving clipboard selection")
  let (_, refreshing) = desk_keydown_action(dispatch, "F5", false, false, model)
  assert_eq(refreshing.host_status, "refreshing")
  let (_, trashing) = desk_keydown_action(
    dispatch, "Delete", false, false, model,
  )
  assert_eq(trashing.desk_trash_status, "moving selection to trash")
}

///|
test "desk mouse single click selects directory without opening it" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "",
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
      @desk.file_entry(workspace_id="book-demo", path="book.json"),
    ],
  }
  let (_, selected) = desk_mouse_action(dispatch, "wiki", false, false, model)
  assert_eq(selected.selected_path, "wiki")
  assert_eq(selected.current_directory, "")
  assert_true(selected.desk_selected_paths == ["wiki"])
  assert_eq(selected.preview_status, "loading selection")
}

///|
test "desk mouse shift and accelerator clicks manage multi selection" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="wiki/alpha.md"),
      @desk.file_entry(workspace_id="book-demo", path="wiki/beta.md"),
      @desk.file_entry(workspace_id="book-demo", path="wiki/gamma.md"),
    ],
  }
  let (_, alpha) = desk_mouse_action(
    dispatch, "wiki/alpha.md", false, false, model,
  )
  let (_, range) = desk_mouse_action(
    dispatch, "wiki/gamma.md", true, false, alpha,
  )
  assert_eq(range.selected_path, "wiki/gamma.md")
  assert_eq(range.desk_selection_anchor, "wiki/alpha.md")
  assert_true(
    range.desk_selected_paths ==
    ["wiki/alpha.md", "wiki/beta.md", "wiki/gamma.md"],
  )
  assert_eq(desk_selection_label(range), "3 selected")
  let (_, toggled) = desk_mouse_action(
    dispatch, "wiki/beta.md", false, true, range,
  )
  assert_true(toggled.desk_selected_paths == ["wiki/alpha.md", "wiki/gamma.md"])
  assert_eq(toggled.selected_path, "wiki/alpha.md")
  assert_eq(
    desk_selected_paths_summary(toggled),
    "wiki/alpha.md, wiki/gamma.md",
  )
}

///|
test "desk clear selection resets focus and preview state" {
  let model = {
    ..init_model(),
    selected_path: "wiki/alpha.md",
    desk_selected_paths: ["wiki/alpha.md", "wiki/beta.md"],
    desk_selection_anchor: "wiki/alpha.md",
    preview_status: "preview ready",
  }
  let (_, cleared) = clear_desk_selection_action(model)
  assert_eq(cleared.selected_path, "")
  assert_true(cleared.desk_selected_paths == [])
  assert_eq(cleared.desk_selection_anchor, "")
  assert_eq(cleared.preview_status, "selection cleared")
}

///|
test "desk workspace routes encode query and path segments" {
  assert_eq(
    workspace_entries_url("book-demo", "docs with spaces/encoded # name.md"),
    "/api/workspaces/book-demo/entries?path=docs%20with%20spaces%2Fencoded%20%23%20name.md",
  )
  assert_eq(
    workspace_preview_url("book-demo", "raw/data?set%.json"),
    "/api/workspaces/book-demo/preview?path=raw%2Fdata%3Fset%25.json",
  )
  let model = { ..init_model(), selected_workspace_id: "book-demo" }
  assert_eq(
    raw_url(model, "images/logo #1.png"),
    "/api/workspaces/book-demo/raw?path=images%2Flogo%20%231.png",
  )
  assert_eq(
    file_url(model, "book/site/generated/assets/site #1.css"),
    "/api/workspaces/book-demo/file/book/site/generated/assets/site%20%231.css",
  )
}

///|
test "desk preview tabs preserve generated site primary context" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "book/site/generated/index.html",
    primary_preview_path: "wiki/index.md",
    preview: Some(
      @desk.preview(
        @desk.file_entry(
          workspace_id="book-demo",
          path="book/site/generated/index.html",
        ),
        body="<html></html>",
      ),
    ),
  }
  let tabs = preview_tabs(model)
  assert_eq(tabs.length(), 2)
  assert_eq(tabs[0].path, "wiki/index.md")
  assert_eq(tabs[0].title, "index.md")
  assert_true(tabs[0].renderer is Markdown)
  assert_eq(tabs[1].path, "book/site/generated/index.html")
  assert_true(tabs[1].renderer is Html)
}

///|
test "generated executable preview uses isolated site projection" {
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "book/site/generated/tool.html",
  }
  assert_eq(
    html_preview_url(model, model.selected_path),
    "/api/workspaces/book-demo/site/tool.html",
  )
  assert_eq(
    html_preview_url(model, "book/site/generated/assets/app #1.js"),
    "/api/workspaces/book-demo/site/assets/app%20%231.js",
  )
}

///|
test "Fix in MoonCode carries selected executable artifact context" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: "book/site/generated/tool.html",
  }
  let (_, next) = update_workspace_surface_actions(
    dispatch,
    FixBrowserPreviewInMoonCode,
    model,
  )
  assert_true(next.workspace_mode is MoonCode)
  assert_true(next.mooncode_prompt.contains("book/site/generated/tool.html"))
  assert_true(next.mooncode_prompt.contains("browser diagnostics"))
}

///|
test "search hit focuses Desk on containing directory" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectSearchHit("book-demo", "wiki/sources/report.md"),
    init_model(),
  )
  assert_true(next.workspace_mode is Desk)
  assert_true(next.activity is Files)
  assert_eq(next.selected_workspace_id, "book-demo")
  assert_eq(next.selected_path, "wiki/sources/report.md")
  assert_eq(next.current_directory, "wiki/sources")
  assert_eq(next.preview_status, "loading search result")
}

///|
test "selecting a desk directory updates current directory" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "",
    entries: [
      @desk.file_entry(workspace_id="book-demo", path="wiki", is_directory=true),
      @desk.file_entry(workspace_id="book-demo", path="book.json"),
    ],
  }
  let (_, next) = update_navigation_actions(dispatch, SelectPath("wiki"), model)
  assert_eq(next.selected_path, "wiki")
  assert_eq(next.current_directory, "wiki")
  assert_eq(next.desk_location_input, "wiki")
  assert_eq(next.preview_status, "loading preview")
}

///|
test "selecting a desk file keeps containing directory context" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-demo",
    current_directory: "wiki",
    entries: [@desk.file_entry(workspace_id="book-demo", path="wiki/index.md")],
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectPath("wiki/index.md"),
    model,
  )
  assert_eq(next.selected_path, "wiki/index.md")
  assert_eq(next.current_directory, "wiki")
  assert_eq(next.desk_location_input, "")
  assert_eq(next.primary_preview_path, "wiki/index.md")
}

///|
test "workspace switch confirms draft then resets stale desk context" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    selected_workspace_id: "book-a",
    current_directory: "wiki/old",
    selected_path: "wiki/old/page.md",
    primary_preview_path: "wiki/old/page.md",
    entries: [@desk.file_entry(workspace_id="book-a", path="wiki/old/page.md")],
    preview: Some(
      @desk.preview(
        @desk.file_entry(workspace_id="book-a", path="wiki/old/page.md"),
        body="old",
      ),
    ),
    markdown_editor_path: "wiki/old/page.md",
    markdown_editor_content: "draft",
    desk_new_item_status: "created wiki/old/stale.md",
    desk_rename_status: "renamed wiki/old/stale.md",
    desk_move_status: "moved wiki/old/stale.md",
    desk_clipboard_paths: ["wiki/old/stale.md"],
    desk_clipboard_workspace_id: "book-a",
    desk_clipboard_operation: "copy",
    desk_clipboard_status: "copied wiki/old/stale.md",
    desk_path_status: "copied path wiki/old/stale.md",
    desk_copy_status: "duplicated wiki/old/stale copy.md",
    desk_trash_status: "moved to trash wiki/old/stale.md",
    selected_mooncode_session_id: "",
    mooncode_new_chat_active: true,
    mooncode_prompt: "stale code draft",
  }
  let (_, pending) = update_navigation_actions(
    dispatch,
    SelectWorkspace("book-b"),
    model,
  )
  assert_eq(pending.selected_workspace_id, "book-a")
  assert_eq(pending.markdown_editor_content, "draft")
  assert_true(pending.pending_markdown_navigation is PendingWorkspace("book-b"))
  let (_, next) = update_navigation_actions(
    dispatch,
    ConfirmDiscardMarkdownNavigation,
    pending,
  )
  assert_eq(next.selected_workspace_id, "book-b")
  assert_eq(next.selected_path, "")
  assert_eq(next.current_directory, "")
  assert_eq(next.primary_preview_path, "wiki/index.md")
  assert_eq(next.entries.length(), 0)
  assert_true(next.preview is None)
  assert_eq(next.preview_status, "loading workspace")
  assert_eq(next.markdown_editor_path, "")
  assert_eq(next.markdown_editor_content, "")
  assert_false(next.mooncode_new_chat_active)
  assert_eq(next.mooncode_prompt, "")
  assert_eq(next.desk_new_item_status, "ready to create item")
  assert_eq(next.desk_rename_status, "ready to rename selection")
  assert_eq(next.desk_move_status, "ready to move selection")
  assert_true(next.desk_clipboard_paths == [])
  assert_eq(next.desk_clipboard_workspace_id, "")
  assert_eq(next.desk_clipboard_operation, "")
  assert_eq(next.desk_clipboard_status, "clipboard empty")
  assert_eq(next.desk_path_status, "ready to copy path")
  assert_eq(next.desk_copy_status, "ready to duplicate selection")
  assert_eq(next.desk_trash_status, "ready to trash selection")
  assert_true(next.pending_markdown_navigation is NoPendingMarkdownNavigation)
}

///|
test "switching to desk loads selected file context directory" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    activity: Inbox,
    selected_workspace_id: "book-demo",
    selected_path: "wiki/sources/report.md",
    current_directory: "raw",
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(Desk),
    model,
  )
  assert_true(next.workspace_mode is Desk)
  assert_true(next.activity is Files)
  assert_eq(next.selected_path, "wiki/sources/report.md")
  assert_eq(next.current_directory, "wiki/sources")
  assert_eq(next.preview_status, "loading desk context")
}

///|
test "mode switches preserve selected desk context without starting code" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: Desk,
    activity: Files,
    selected_workspace_id: "book-demo",
    selected_path: "tools/demo/main.mbt",
    current_directory: "tools/demo",
    mooncode_new_chat_active: true,
    mooncode_prompt: "stale prompt",
    mooncode_composer_status: "idle",
  }
  let (_, wiki) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(MoonWiki),
    model,
  )
  assert_true(wiki.workspace_mode is MoonWiki)
  assert_eq(wiki.selected_workspace_id, "book-demo")
  assert_eq(wiki.selected_path, "tools/demo/main.mbt")
  assert_eq(wiki.current_directory, "tools/demo")
  assert_eq(wiki.mooncode_prompt, "stale prompt")

  let (_, code) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(MoonCode),
    wiki,
  )
  assert_true(code.workspace_mode is MoonCode)
  assert_eq(code.selected_workspace_id, "book-demo")
  assert_eq(code.selected_path, "tools/demo/main.mbt")
  assert_eq(code.current_directory, "tools/demo")
  assert_eq(code.mooncode_prompt, "")
  assert_false(code.mooncode_new_chat_active)
  assert_eq(code.mooncode_composer_status, "MoonCode workspace ready")

  let (_, back_to_desk) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(Desk),
    code,
  )
  assert_true(back_to_desk.workspace_mode is Desk)
  assert_eq(back_to_desk.selected_path, "tools/demo/main.mbt")
  assert_eq(back_to_desk.current_directory, "tools/demo")
  assert_eq(back_to_desk.preview_status, "loading desk context")
}

///|
test "switching to desk keeps selected directory as context" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let model = {
    ..init_model(),
    workspace_mode: MoonWiki,
    selected_workspace_id: "book-demo",
    selected_path: "wiki/sources",
    current_directory: "wiki",
    entries: [
      @desk.file_entry(
        workspace_id="book-demo",
        path="wiki/sources",
        is_directory=true,
      ),
    ],
  }
  let (_, next) = update_navigation_actions(
    dispatch,
    SelectWorkspaceMode(Desk),
    model,
  )
  assert_true(next.workspace_mode is Desk)
  assert_eq(next.selected_path, "wiki/sources")
  assert_eq(next.current_directory, "wiki/sources")
  assert_eq(next.preview_status, "loading desk context")
}
