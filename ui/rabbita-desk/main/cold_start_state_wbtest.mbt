///|
fn cold_start_test_workspace(id : String) -> @desk.DeskWorkspace {
  @desk.workspace(
    id~,
    name=id,
    root_path="/tmp/moonsuite/books/" + id,
    kind=MoonBook,
  )
}

///|
fn cold_start_test_model(
  loading : Bool,
  library_path : String,
  workspaces : Array[@desk.DeskWorkspace],
) -> Model {
  {
    ..init_model(),
    loading,
    workspace_library_path: library_path,
    workspace_books_root_path: library_path,
    workspaces,
    workspace_catalog_state: if loading {
      Some(Loading)
    } else if workspaces.is_empty() {
      Some(LegitimateZero)
    } else {
      None
    },
    workspace_catalog_error: "",
  }
}

///|
test "cold start classifier returns all six states" {
  assert_true(classify_cold_start(init_model()) is Connecting)
  assert_true(
    classify_cold_start(cold_start_test_model(false, "", []))
    is LibraryUnavailable,
  )
  assert_true(
    classify_cold_start(
      cold_start_test_model(false, "/tmp/moonsuite/books", []),
    )
    is EmptyLibrary,
  )
  assert_true(
    classify_cold_start({
      ..cold_start_test_model(false, "/tmp/moonsuite/books", []),
      workspace_catalog_state: Some(RecoverableError),
    })
    is CatalogUnavailable,
  )
  assert_true(
    classify_cold_start(
      cold_start_test_model(false, "/tmp/moonsuite/books", [
        cold_start_test_workspace("book-a"),
      ]),
    )
    is OneBook,
  )
  assert_true(
    classify_cold_start(
      cold_start_test_model(false, "/tmp/moonsuite/books", [
        cold_start_test_workspace("book-a"),
        cold_start_test_workspace("book-b"),
      ]),
    )
    is ManyBooks,
  )
}

///|
test "cold start precedence is deterministic" {
  assert_true(
    classify_cold_start(
      cold_start_test_model(true, "/tmp/moonsuite/books", [
        cold_start_test_workspace("book-a"),
      ]),
    )
    is OneBook,
  )
  assert_true(
    classify_cold_start(
      cold_start_test_model(false, "", [cold_start_test_workspace("book-a")]),
    )
    is OneBook,
  )
}

///|
test "cold start copy state keys and primary actions are exact" {
  assert_eq(cold_start_state_key(Connecting), "connecting")
  assert_eq(cold_start_state_key(LibraryUnavailable), "library-unavailable")
  assert_eq(cold_start_state_key(CatalogUnavailable), "catalog-unavailable")
  assert_eq(cold_start_state_key(EmptyLibrary), "empty-library")
  assert_eq(cold_start_state_key(OneBook), "one-book")
  assert_eq(cold_start_state_key(ManyBooks), "many-books")
  assert_eq(cold_start_title(Connecting), "Connecting to your library")
  assert_eq(
    cold_start_detail(Connecting),
    "MoonDesk is checking your MoonBook library.",
  )
  assert_eq(
    cold_start_title(LibraryUnavailable),
    "MoonBook library unavailable",
  )
  assert_eq(
    cold_start_detail(LibraryUnavailable),
    "Choose a folder where MoonDesk can keep your MoonBooks.",
  )
  assert_eq(
    cold_start_title(CatalogUnavailable),
    "MoonBook library could not be checked",
  )
  assert_eq(
    cold_start_detail(CatalogUnavailable),
    "MoonDesk could not check this library. Refresh to try again.",
  )
  assert_eq(cold_start_title(EmptyLibrary), "No MoonBooks yet")
  assert_eq(
    cold_start_detail(EmptyLibrary),
    "Create a MoonBook or import an existing one.",
  )
  assert_true(cold_start_primary_action(Connecting) is Refresh)
  assert_true(cold_start_primary_action(LibraryUnavailable) is ChooseLibrary)
  assert_true(cold_start_primary_action(CatalogUnavailable) is Refresh)
  assert_true(cold_start_primary_action(EmptyLibrary) is AddMoonBook)
  assert_true(cold_start_primary_action(OneBook) is OpenMoonBook)
  assert_true(cold_start_primary_action(ManyBooks) is ChooseMoonBook)
  assert_eq(cold_start_primary_action_label(Refresh), "Refresh")
  assert_eq(
    cold_start_primary_action_label(ChooseLibrary),
    "Choose library folder",
  )
  assert_eq(cold_start_primary_action_label(AddMoonBook), "Add MoonBook")
  assert_eq(cold_start_primary_action_label(OpenMoonBook), "Open MoonBook")
  assert_eq(cold_start_primary_action_label(ChooseMoonBook), "Choose MoonBook")
}

///|
#warnings("-alert_unstable")
test "empty-library creation fields have stable accessible names" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_new_moonbook_panel_open(dispatch, init_model())),
  )
  assert_true(markup.contains("data-testid=\"desk-new-book-name\""))
  assert_true(markup.contains("aria-label=\"MoonBook name\""))
  assert_true(markup.contains("data-testid=\"desk-new-book-id\""))
  assert_true(markup.contains("aria-label=\"Optional folder name\""))
  assert_true(markup.contains("data-testid=\"desk-create-book\""))
}

///|
test "workspace result preserves known selection and falls back deterministically" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let workspaces = [
    cold_start_test_workspace("book-a"),
    cold_start_test_workspace("book-b"),
  ]
  let (_, preserved) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(Ok(workspaces)),
    {
      ..cold_start_test_model(false, "/tmp/moonsuite/books", []),
      selected_workspace_id: "book-b",
    },
  )
  assert_eq(preserved.selected_workspace_id, "book-b")
  let (_, fallback) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(Ok(workspaces)),
    {
      ..cold_start_test_model(false, "/tmp/moonsuite/books", []),
      selected_workspace_id: "missing",
    },
  )
  assert_eq(fallback.selected_workspace_id, "book-a")
}

///|
#warnings("-alert_unstable")
test "restored Flow workspace immediately hydrates its full operator state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let workspace = cold_start_test_workspace("book-flow")
  let (_, restored) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(Ok([workspace])),
    {
      ..cold_start_test_model(false, "/tmp/moonsuite/books", []),
      workspace_mode: MoonFlow,
      selected_workspace_id: "book-flow",
    },
  )
  assert_true(restored.moonflow_runs_state is Some(Loading))
  assert_true(restored.moonflow_runs_error is None)
  assert_eq(restored.moonflow_composition_status, "Loading composition…")
  assert_eq(
    restored.moonflow_operator_action_status,
    "Loading operator actions…",
  )
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(render_moonflow_composition_canvas(dispatch, restored)),
  )
  assert_true(markup.contains("Loading executable Work graph"))
  assert_true(
    markup.contains(
      "Restoring the selected MoonBook composition, runs, and authorized actions.",
    ),
  )
  assert_false(markup.contains("No executable Work graph yet"))
}

///|
test "workspace catalog success failure and refresh own honest state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let configured = cold_start_test_model(false, "/tmp/moonsuite/books", [])
  let (_, failed) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(Err("private catalog failure")),
    { ..configured, workspace_catalog_state: Some(Loading) },
  )
  assert_true(failed.workspace_catalog_state is Some(RecoverableError))
  assert_eq(failed.workspace_catalog_error, "private catalog failure")
  assert_true(failed.workspaces.is_empty())
  assert_true(classify_cold_start(failed) is CatalogUnavailable)
  let (_, zero) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(Ok([])),
    failed,
  )
  assert_true(zero.workspace_catalog_state is Some(LegitimateZero))
  assert_eq(zero.workspace_catalog_error, "")
  assert_true(classify_cold_start(zero) is EmptyLibrary)
  let book = cold_start_test_workspace("book-a")
  let (_, ready) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(Ok([book])),
    zero,
  )
  assert_true(ready.workspace_catalog_state is None)
  assert_eq(ready.workspaces.length(), 1)
  let (_, refreshing) = update_workspace_surface_actions(
    dispatch,
    RefreshAll,
    ready,
  )
  assert_true(refreshing.workspace_catalog_state is Some(Loading))
  assert_eq(refreshing.workspaces.length(), 1)
  let (_, stale) = update_workspace_results(
    dispatch,
    LoadedWorkspaces(Err("refresh failed")),
    refreshing,
  )
  assert_true(stale.workspace_catalog_state is Some(Stale))
  assert_eq(stale.workspace_catalog_error, "refresh failed")
  assert_eq(stale.workspaces.length(), 1)
  assert_true(classify_cold_start(stale) is OneBook)
}

///|
test "missing library and failed configured catalog stay distinct" {
  let missing = {
    ..cold_start_test_model(false, "", []),
    workspace_catalog_state: Some(RecoverableError),
  }
  assert_true(classify_cold_start(missing) is LibraryUnavailable)
  assert_true(
    cold_start_primary_action(classify_cold_start(missing)) is ChooseLibrary,
  )
  let configured = {
    ..cold_start_test_model(false, "/tmp/moonsuite/books", []),
    workspace_catalog_state: Some(RecoverableError),
  }
  assert_true(classify_cold_start(configured) is CatalogUnavailable)
  assert_true(
    cold_start_primary_action(classify_cold_start(configured)) is Refresh,
  )
}

///|
test "workspace catalog rendering never turns failure into empty success" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let failed = {
    ..cold_start_test_model(false, "/tmp/moonsuite/books", []),
    workspace_catalog_state: Some(RecoverableError),
    workspace_catalog_error: "PRIVATE_WORKSPACE_CATALOG_MARKER",
  }
  let failed_markup = render_accessibility_test_html(
    render_desk_workspace_sidebar(dispatch, failed),
  )
  assert_true(
    failed_markup.contains("data-testid=\"workspace-catalog-state-panel\""),
  )
  assert_true(failed_markup.contains("data-state=\"recoverable-error\""))
  assert_true(failed_markup.contains("aria-live=\"polite\""))
  assert_true(failed_markup.contains("could not be checked"))
  assert_true(failed_markup.contains(">Refresh<"))
  assert_false(failed_markup.contains("No MoonBooks yet"))
  assert_false(failed_markup.contains("data-testid=\"desk-add-moonbook\""))
  assert_false(failed_markup.contains("data-testid=\"desk-create-book\""))
  assert_true(failed_markup.contains("<details"))
  assert_false(failed_markup.contains("<details open"))
  assert_true(failed_markup.contains("PRIVATE_WORKSPACE_CATALOG_MARKER"))
  let stale = {
    ..cold_start_test_model(false, "/tmp/moonsuite/books", [
      cold_start_test_workspace("book-a"),
    ]),
    workspace_catalog_state: Some(Stale),
    workspace_catalog_error: "PRIVATE_STALE_CATALOG_MARKER",
    selected_workspace_id: "book-a",
  }
  let stale_markup = render_accessibility_test_html(
    render_desk_workspace_sidebar(dispatch, stale),
  )
  assert_true(stale_markup.contains("data-state=\"stale\""))
  assert_true(stale_markup.contains("book-a"))
  assert_true(stale_markup.contains("last successful check"))
  assert_true(stale_markup.contains("PRIVATE_STALE_CATALOG_MARKER"))
}
