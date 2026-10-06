///|
fn source_save_action_send(
  fixture : @js.Value,
  cell : Ref[Model],
  message : Msg,
) -> Unit {
  let previous = source_save_http_activate(fixture)
  defer source_save_http_restore(previous)
  let scheduler : RequestedSelectionTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  fn dispatch(message : Msg) -> @rabbita.Cmd {
    let (command, next) = match message {
      SourcePane(action) => source_pane_action(dispatch, action, cell.val)
      _ => update_mooncode_actions(dispatch, message, cell.val)
    }
    cell.val = next
    @cmd.Scheduler::add(scheduler, command)
    @rabbita.none
  }
  ignore(dispatch(message))
}

///|
fn source_save_request_count(fixture : @js.Value) -> Int {
  let value = @json.parse(source_save_http_requests(fixture)) catch {
    _ => Json::null()
  }
  match value {
    Array(requests) => requests.length()
    _ => -1
  }
}

///|
test "source save action sends one request for repeated Save and ignores settled replies" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    let cell = Ref({ ..init_model(), source_pane: source_save_test_state(), })
    source_save_action_send(fixture, cell, SourcePane(Save))
    let request = cell.val.source_pane.pending_save.unwrap()
    source_save_action_send(fixture, cell, SourcePane(Save))
    assert_eq(source_save_request_count(fixture), 1)
    assert_true(cell.val.source_pane.saving)
    assert_true(cell.val.source_pane.pending_save == Some(request))
    ignore(
      source_save_http_resolve(
        fixture,
        0,
        200,
        source_save_test_success("human edit").stringify(),
      ).wait(),
    )
    source_save_action_send(fixture, cell, SourcePane(EditDraft("newer edit")))
    let newer = cell.val.source_pane
    for
      outcome in [
        SourceSaved(source_save_test_success("human edit")),
        SourceConflict("older conflict"),
        SourceSaveFailed("older failure"),
      ] {
      source_save_action_send(
        fixture,
        cell,
        SourcePane(SaveResult(request, outcome)),
      )
      assert_true(cell.val.source_pane == newer)
    }
    assert_true(source_pane_dirty(cell.val.source_pane))
    assert_eq(cell.val.source_pane.draft, "newer edit")
  })
}

///|
test "source replacement is single flight and pending conflict choices cannot change its draft" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    let cell = Ref({ ..init_model(), source_pane: source_save_test_state(), })
    source_save_action_send(fixture, cell, SourcePane(Save))
    let conflict : Json = {
      "code": 409,
      "current_content": "external edit",
      "error": "File changed after this draft was opened",
    }
    ignore(
      source_save_http_resolve(fixture, 0, 409, conflict.stringify()).wait(),
    )
    source_save_action_send(fixture, cell, SourcePane(ReplaceServer))
    let replacing = cell.val.source_pane
    for
      action in [
        ReplaceServer,
        Save,
        ReloadServer,
        DiscardDraft,
        EditDraft("must not replace pending content"),
      ] {
      source_save_action_send(fixture, cell, SourcePane(action))
      assert_true(cell.val.source_pane == replacing)
    }
    assert_eq(source_save_request_count(fixture), 2)
    assert_eq(replacing.baseline, "external edit")
    assert_eq(replacing.draft, "human edit")
    ignore(
      source_save_http_resolve(
        fixture,
        1,
        200,
        source_save_test_success("human edit").stringify(),
      ).wait(),
    )
    assert_false(cell.val.source_pane.saving)
    assert_true(cell.val.source_pane.pending_save is None)
    source_save_action_send(
      fixture,
      cell,
      SourcePane(EditDraft("newer edit after replacement")),
    )
    source_save_action_send(
      fixture,
      cell,
      SourcePane(
        SaveResult(
          replacing.pending_save.unwrap(),
          SourceConflict("human edit"),
        ),
      ),
    )
    assert_eq(cell.val.source_pane.draft, "newer edit after replacement")
    assert_true(source_pane_dirty(cell.val.source_pane))
    assert_true(cell.val.source_pane.server_content is None)
  })
}

///|
test "Git open waits for source save and old replies cannot overwrite the next file" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    let projection : GitRepositoryProjection = {
      state: "ready",
      branch: "work",
      head: "abc123",
      has_remote: false,
      changes: [
        {
          path: "src/other.mbt",
          previous_path: "",
          index_status: " ",
          worktree_status: "M",
        },
      ],
      truncated: false,
      error: "",
    }
    let cell = Ref({
      ..init_model(),
      selected_workspace_id: "book-demo",
      git_projection_workspace_id: "book-demo",
      git_projection: Some(projection),
      source_pane: source_save_test_state(),
    })
    source_save_action_send(fixture, cell, SourcePane(Save))
    let request = cell.val.source_pane.pending_save.unwrap()
    source_save_action_send(fixture, cell, OpenGitChange("src/other.mbt"))
    assert_eq(source_save_request_count(fixture), 1)
    assert_eq(cell.val.source_pane.requested_path, "src/main.mbt")
    assert_eq(cell.val.source_pane.draft, "human edit")
    assert_true(
      cell.val.source_pane.status.contains("Wait for the current save"),
    )
    ignore(
      source_save_http_resolve(
        fixture,
        0,
        200,
        source_save_test_success("human edit").stringify(),
      ).wait(),
    )
    source_save_action_send(fixture, cell, OpenGitChange("src/other.mbt"))
    assert_eq(source_save_request_count(fixture), 2)
    let preview = @desk.preview(
      @desk.file_entry(workspace_id="book-demo", path="src/other.mbt"),
      body="other file body",
    )
    ignore(
      source_save_http_resolve(fixture, 1, 200, preview.to_json().stringify()).wait(),
    )
    assert_eq(cell.val.source_pane.requested_path, "src/other.mbt")
    assert_eq(cell.val.source_pane.draft, "other file body")
    let other = cell.val.source_pane
    source_save_action_send(
      fixture,
      cell,
      SourcePane(
        SaveResult(request, SourceSaved(source_save_test_success("human edit"))),
      ),
    )
    assert_true(cell.val.source_pane == other)
  })
}

///|
test "source save retry keeps a distinct identity and older replies cannot finish it" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    let cell = Ref({ ..init_model(), source_pane: source_save_test_state(), })
    source_save_action_send(fixture, cell, SourcePane(Save))
    let first = cell.val.source_pane.pending_save.unwrap()
    ignore(source_save_http_reject(fixture, 0).wait())
    source_save_action_send(fixture, cell, SourcePane(Save))
    let retry = cell.val.source_pane.pending_save.unwrap()
    assert_true(retry.generation > first.generation)
    assert_true(retry.source == first.source)
    let pending = cell.val.source_pane
    for
      outcome in [
        SourceSaved(source_save_test_success("human edit")),
        SourceConflict("older conflict"),
        SourceSaveFailed("older failure"),
      ] {
      source_save_action_send(
        fixture,
        cell,
        SourcePane(SaveResult(first, outcome)),
      )
      assert_true(cell.val.source_pane == pending)
    }
    ignore(
      source_save_http_resolve(
        fixture,
        1,
        200,
        source_save_test_success("human edit").stringify(),
      ).wait(),
    )
    assert_false(cell.val.source_pane.saving)
    assert_eq(cell.val.source_pane.status, "Saved")
  })
}

///|
test "source save acknowledgement never retires a newer draft" {
  @js.async_test(async fn() {
    let fixture = source_save_http_fixture()
    let cell = Ref({ ..init_model(), source_pane: source_save_test_state(), })
    source_save_action_send(fixture, cell, SourcePane(Save))
    // Model-level completion protection remains valid even if another source
    // of edits has already produced a newer draft before the response arrives.
    cell.val = {
      ..cell.val,
      source_pane: { ..cell.val.source_pane, draft: "newer draft", },
    }
    ignore(
      source_save_http_resolve(
        fixture,
        0,
        200,
        source_save_test_success("human edit").stringify(),
      ).wait(),
    )
    assert_eq(cell.val.source_pane.draft, "newer draft")
    assert_eq(cell.val.source_pane.baseline, "human edit")
    assert_true(source_pane_dirty(cell.val.source_pane))
    assert_false(cell.val.source_pane.saving)
    assert_true(
      cell.val.source_pane.status.contains("newer changes are unsaved"),
    )
  })
}

///|
extern "js" fn source_save_disabled_label(
  markup : String,
  label : String,
) -> Bool =
  #| (markup, label) => [...markup.matchAll(/<button\b([^>]*)>([\s\S]*?)<\/button>/g)].some(([, attrs, text]) => text === label && /\bdisabled(?:=|\s|$)/.test(attrs))

///|
#warnings("-alert_unstable")
test "pending source replacement disables the existing conflict controls" {
  let conflict = {
    ..source_save_test_state(),
    server_content: Some("external edit"),
  }
  let replacing = update_source_pane(conflict, ReplaceServer)
  let markup = @rabbita.render_to_string(
    @rabbita.static_cell(
      render_source_editor(code_mode_test_dispatch, replacing),
    ),
  )
  assert_true(source_save_disabled_label(markup, "Replace external"))
  assert_true(source_save_disabled_label(markup, "Reload external"))
  assert_true(source_save_disabled_label(markup, "Reload external version"))
  assert_true(update_source_pane(replacing, ReloadServer) == replacing)
  assert_true(update_source_pane(replacing, DiscardDraft) == replacing)
  let rebound = update_source_pane(
    replacing,
    Rebind("other-book", "other-session"),
  )
  assert_eq(rebound.workspace_id, "book-demo")
  assert_true(rebound.pending_save == replacing.pending_save)
}
