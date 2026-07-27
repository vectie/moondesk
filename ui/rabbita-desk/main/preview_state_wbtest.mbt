///|
fn preview_state_test_preview(
  path : String,
  body : String,
) -> @desk.DeskPreview {
  @desk.preview(@desk.file_entry(workspace_id="book-demo", path~), body~)
}

///|
fn preview_state_test_model(path : String) -> Model {
  {
    ..init_model(),
    selected_workspace_id: "book-demo",
    selected_path: path,
    primary_preview_path: path,
  }
}

///|
test "preview request identity rejects stale path and same-path generations" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let path = "wiki/current.md"
  let (_, first) = update_workspace_results(
    dispatch,
    RequestPreview("book-demo", path),
    preview_state_test_model(path),
  )
  assert_eq(first.preview_request_generation, 1)
  assert_true(first.preview_state is Some(Loading))
  let (_, second) = update_workspace_results(
    dispatch,
    RequestPreview("book-demo", path),
    first,
  )
  assert_eq(second.preview_request_generation, 2)
  let (_, superseded) = update_workspace_results(
    dispatch,
    LoadedPreview(
      "book-demo",
      path,
      1,
      Ok(preview_state_test_preview(path, "older")),
    ),
    second,
  )
  assert_true(superseded.preview is None)
  assert_true(superseded.preview_state is Some(Loading))
  let (_, current) = update_workspace_results(
    dispatch,
    LoadedPreview(
      "book-demo",
      path,
      2,
      Ok(preview_state_test_preview(path, "current")),
    ),
    superseded,
  )
  guard current.preview is Some(preview) else {
    fail("expected current preview")
  }
  assert_eq(preview.body, "current")
  assert_true(current.preview_state is None)
  let next_path = "wiki/next.md"
  let (_, next_loading) = update_workspace_results(
    dispatch,
    RequestPreview("book-demo", next_path),
    { ..current, selected_path: next_path },
  )
  assert_true(next_loading.preview is None)
  assert_true(next_loading.preview_state is Some(Loading))
  let (_, late_old_path) = update_workspace_results(
    dispatch,
    LoadedPreview(
      "book-demo",
      path,
      2,
      Ok(preview_state_test_preview(path, "late")),
    ),
    next_loading,
  )
  assert_true(late_old_path.preview is None)
  assert_eq(late_old_path.preview_request_path, next_path)
}

///|
test "same-path preview refresh retains evidence and classifies failures" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let path = "wiki/current.md"
  let ready = {
    ..preview_state_test_model(path),
    preview: Some(preview_state_test_preview(path, "retained")),
    preview_state: None,
    preview_request_workspace_id: "book-demo",
    preview_request_path: path,
    preview_request_generation: 7,
  }
  let (_, loading) = update_workspace_results(
    dispatch,
    RequestPreview("book-demo", path),
    ready,
  )
  assert_true(loading.preview is Some(_))
  assert_true(loading.preview_state is Some(Loading))
  assert_eq(loading.preview_request_generation, 8)
  let (_, stale) = update_workspace_results(
    dispatch,
    LoadedPreview("book-demo", path, 8, Err("private host failure")),
    loading,
  )
  assert_true(stale.preview is Some(_))
  assert_true(stale.preview_state is Some(Stale))
  assert_eq(stale.preview_error, "private host failure")
  assert_false(stale.preview_status.contains("private host failure"))
  let (_, empty_loading) = update_workspace_results(
    dispatch,
    RequestPreview("book-demo", path),
    preview_state_test_model(path),
  )
  let (_, recoverable) = update_workspace_results(
    dispatch,
    LoadedPreview("book-demo", path, 1, Err("private initial failure")),
    empty_loading,
  )
  assert_true(recoverable.preview is None)
  assert_true(recoverable.preview_state is Some(RecoverableError))
  assert_eq(recoverable.preview_error, "private initial failure")
}

///|
test "clearing the selected workspace restores preview first-use state" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let path = "wiki/current.md"
  let (_, reset) = select_workspace_action(dispatch, "", {
    ..preview_state_test_model(path),
    preview: Some(preview_state_test_preview(path, "old")),
    preview_state: Some(Stale),
    preview_error: "old failure",
    preview_request_workspace_id: "book-demo",
    preview_request_path: path,
    preview_request_generation: 4,
  })
  assert_true(reset.preview is None)
  assert_true(reset.preview_state is Some(FirstUseEmpty))
  assert_eq(reset.preview_error, "")
  assert_eq(reset.preview_request_workspace_id, "")
  assert_eq(reset.preview_request_path, "")
}

///|
#warnings("-alert_unstable")
test "preview rendering follows typed state instead of status prose" {
  let dispatch : Dispatch[Msg] = fn(_msg) { @rabbita.none }
  let path = "wiki/current.md"
  let loading_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_desk_inline_preview(dispatch, {
        ..preview_state_test_model(path),
        preview_state: Some(Loading),
        preview_status: "this sentence contains no transport vocabulary",
      }),
    ),
  )
  assert_true(loading_markup.contains("data-state=\"loading\""))
  assert_true(loading_markup.contains("Opening preview"))
  let ready_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_desk_inline_preview(dispatch, {
        ..preview_state_test_model(path),
        preview: Some(preview_state_test_preview(path, "ready body")),
        preview_state: None,
        preview_status: "loading waiting not available",
      }),
    ),
  )
  assert_true(ready_markup.contains("ready body"))
  assert_false(ready_markup.contains("Opening preview"))
  let failed_markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_desk_inline_preview(dispatch, {
        ..preview_state_test_model(path),
        preview_state: Some(RecoverableError),
        preview_error: "private diagnostic",
      }),
    ),
  )
  assert_true(failed_markup.contains("Preview couldn’t be opened"))
  assert_true(failed_markup.contains("Technical details"))
  assert_true(failed_markup.contains("private diagnostic"))
}
