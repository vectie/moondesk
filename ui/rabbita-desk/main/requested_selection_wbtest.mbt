///|
fn requested_selection_test_model() -> Model {
  {
    ..init_model(),
    workspace_mode: MoonCode,
    selected_workspace_id: "book-requested",
    requested_workspace_id: "book-requested",
    selected_mooncode_session_id: "session-requested",
    selected_path: "src/requested.mbt",
  }
}

///|
extern "js" fn requested_selection_install_test_location(
  search : String,
) -> @js.Value =
  #| (search) => { const previous = globalThis.location; globalThis.location = { search }; return previous; }

///|
extern "js" fn requested_selection_restore_test_location(previous : @js.Value) =
  #| (previous) => { if (previous === undefined) delete globalThis.location; else globalThis.location = previous; }

///|
test "requested URL restores exact escaped identities on each reload" {
  for _index in 0..<2 {
    let previous = requested_selection_install_test_location(
      "?activity=code&workspace=book%2Frequested&session=session%3Frequested&path=src%2Fmain.mbt",
    )
    let model = init_model()
    requested_selection_restore_test_location(previous)
    assert_eq(model.selected_workspace_id, "book/requested")
    assert_eq(model.requested_workspace_id, "book/requested")
    assert_eq(model.selected_mooncode_session_id, "session?requested")
    assert_eq(model.selected_path, "src/main.mbt")
    assert_true(model.mooncode_selected_session_loading)
    assert_true(model.workspace_mode is MoonCode)
  }
}

///|
test "requested selection cold start never adopts an unrelated listed session" {
  let model = requested_selection_test_model()
  for
    rows in [
      [],
      [code_mode_test_session("unrelated", workspace_id="book-requested")],
    ] {
    let (_, next) = update_mooncode_session_results(
      code_mode_test_dispatch,
      LoadedMoonCodeSessions(Ok(rows)),
      model,
    )
    assert_eq(next.selected_mooncode_session_id, "session-requested")
    assert_eq(next.selected_workspace_id, "book-requested")
    assert_false(next.mooncode_new_chat_active)
  }
}

///|
test "requested workspace survives empty and unrelated catalog results" {
  let model = { ..requested_selection_test_model(), workspace_mode: Desk, }
  for
    rows in [
      [],
      [
        @desk.workspace(
          id="unrelated",
          name="Unrelated",
          kind=MoonBook,
          root_path="/unrelated",
        ),
      ],
    ] {
    let (_, next) = update_workspace_results(
      code_mode_test_dispatch,
      LoadedWorkspaces(Ok(rows)),
      model,
    )
    assert_eq(next.selected_workspace_id, "book-requested")
    assert_eq(next.selected_path, "src/requested.mbt")
  }
}

///|
test "requested session only does not borrow the first catalog workspace" {
  let model = {
    ..requested_selection_test_model(),
    selected_workspace_id: "",
    requested_workspace_id: "",
  }
  let (_, next) = update_workspace_results(
    code_mode_test_dispatch,
    LoadedWorkspaces(
      Ok([
        @desk.workspace(
          id="unrelated",
          name="Unrelated",
          kind=MoonBook,
          root_path="/unrelated",
        ),
      ]),
    ),
    model,
  )
  assert_eq(next.selected_workspace_id, "")
  assert_eq(next.selected_mooncode_session_id, "session-requested")
}

///|
test "requested session detail binds its real workspace before catalog arrives" {
  let model = {
    ..requested_selection_test_model(),
    selected_workspace_id: "",
    requested_workspace_id: "",
  }
  let (_, next) = update_mooncode_session_results(
    code_mode_test_dispatch,
    LoadedMoonCodeSelectedSession(
      "session-requested",
      Ok(
        code_mode_test_session(
          "session-requested",
          workspace_id="book-requested",
        ),
      ),
    ),
    model,
  )
  assert_eq(next.selected_workspace_id, "book-requested")
  assert_eq(next.selected_mooncode_session_id, "session-requested")
}

///|
test "requested missing session cannot silently create a different chat" {
  let model = {
    ..requested_selection_test_model(),
    mooncode_prompt: "Continue the exact work",
  }
  let (_, next) = mooncode_send_composer(code_mode_test_dispatch, model)
  assert_eq(next.mooncode_prompt, model.mooncode_prompt)
  assert_eq(next.selected_mooncode_session_id, "session-requested")
  assert_false(next.mooncode_new_chat_active)
  assert_true(next.mooncode_optimistic_rows.is_empty())
}

///|
test "requested missing session shows recovery instead of a new chat invitation" {
  let model = requested_selection_test_model()
  let markup = render_test_dom(
    @rabbita.static_cell(render_mooncode_center(code_mode_test_dispatch, model)),
  )
  assert_true(markup.contains("data-testid=\"requested-selection\""))
  assert_true(markup.contains("session-requested"))
  assert_true(markup.contains("Retry"))
  assert_false(markup.contains("<h1 data-i18n=\"code.ask\">Ask MoonCode</h1>"))
}

///|
fn requested_selection_test_workspace(id : String) -> @desk.DeskWorkspace {
  @desk.workspace(id~, name=id, kind=MoonBook, root_path="/books/" + id)
}

///|
test "requested selection resolves in either catalog order and survives later stale lists" {
  let session = code_mode_test_session(
    "session-requested",
    workspace_id="book-requested",
  )
  let workspaces = [requested_selection_test_workspace("book-requested")]
  for sessions_first in [true, false] {
    let first = if sessions_first {
      LoadedMoonCodeSessions(Ok([session]))
    } else {
      LoadedWorkspaces(Ok(workspaces))
    }
    let second = if sessions_first {
      LoadedWorkspaces(Ok(workspaces))
    } else {
      LoadedMoonCodeSessions(Ok([session]))
    }
    let (_, one) = update(
      code_mode_test_dispatch,
      first,
      requested_selection_test_model(),
    )
    let (_, two) = update(code_mode_test_dispatch, second, one)
    assert_eq(two.selected_workspace_id, "book-requested")
    assert_eq(two.selected_mooncode_session_id, "session-requested")
    assert_false(mooncode_selection_unavailable(two))
    let (_, stale_catalog) = update(
      code_mode_test_dispatch,
      LoadedWorkspaces(Ok([])),
      two,
    )
    let (_, stale_sessions) = update(
      code_mode_test_dispatch,
      LoadedMoonCodeSessions(Ok([])),
      stale_catalog,
    )
    assert_eq(stale_sessions.selected_workspace_id, "book-requested")
    assert_eq(stale_sessions.selected_mooncode_session_id, "session-requested")
    assert_true(selected_mooncode_session(stale_sessions) is Some(_))
    assert_false(mooncode_selection_unavailable(stale_sessions))
    assert_true(stale_sessions.workspace_catalog_state is Some(Stale))
    let (_, sent) = mooncode_send_composer(code_mode_test_dispatch, {
      ..stale_sessions,
      mooncode_prompt: "Continue the same work",
    })
    assert_eq(sent.selected_mooncode_session_id, "session-requested")
    assert_eq(sent.mooncode_prompt, "")
    assert_true(
      sent.mooncode_optimistic_rows.any(row => {
        row.session_id == "session-requested"
      }),
    )
    let (_, refreshed) = update(
      code_mode_test_dispatch,
      LoadedWorkspaces(Ok(workspaces)),
      stale_sessions,
    )
    assert_true(refreshed.workspace_catalog_state is None)
    assert_eq(stale_sessions.source_pane.workspace_id, "book-requested")
  }
}

///|
test "requested selection delayed success recovers after missing and transport errors" {
  let model = requested_selection_test_model()
  let (_, absent) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([])),
    model,
  )
  let (_, error) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSelectedSession("session-requested", Err("not found yet")),
    absent,
  )
  assert_true(mooncode_selection_unavailable(error))
  assert_false(error.mooncode_selected_session_loading)
  let (_, retry) = update(code_mode_test_dispatch, RetryBootstrap, error)
  assert_true(retry.mooncode_selected_session_loading)
  assert_eq(retry.selected_mooncode_session_id, "session-requested")
  let session = code_mode_test_session(
    "session-requested",
    workspace_id="book-requested",
  )
  let (_, found) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSelectedSession(session.id, Ok(session)),
    retry,
  )
  let (_, ready) = update(
    code_mode_test_dispatch,
    LoadedWorkspaces(Ok([requested_selection_test_workspace("book-requested")])),
    found,
  )
  assert_false(mooncode_selection_unavailable(ready))
  assert_false(ready.mooncode_selected_session_loading)
  assert_eq(ready.mooncode_sessions_error, "")
}

///|
test "requested session late responses cannot undo New Chat or workspace navigation" {
  let departed = code_mode_test_session(
    "session-requested",
    workspace_id="book-requested",
  )
  for
    action in [
      NewMoonCodeSession,
      SelectWorkspace("book-next"),
      SelectWorkspace(""),
    ] {
    let (_, navigation) = update(
      code_mode_test_dispatch,
      action,
      requested_selection_test_model(),
    )
    let (_, late_detail) = update(
      code_mode_test_dispatch,
      LoadedMoonCodeSelectedSession(departed.id, Ok(departed)),
      navigation,
    )
    let (_, late_error) = update(
      code_mode_test_dispatch,
      LoadedMoonCodeSelectedSession(departed.id, Err("late error")),
      late_detail,
    )
    let (_, late_list) = update(
      code_mode_test_dispatch,
      LoadedMoonCodeSessions(Ok([departed])),
      late_error,
    )
    let (_, late_catalog) = update(
      code_mode_test_dispatch,
      LoadedWorkspaces(Ok([requested_selection_test_workspace("unrelated")])),
      late_list,
    )
    assert_eq(late_catalog.selected_mooncode_session_id, "")
    assert_eq(
      late_catalog.selected_workspace_id,
      navigation.selected_workspace_id,
    )
    assert_eq(late_catalog.mooncode_sessions_error, "")
    assert_false(late_catalog.mooncode_auto_select_session)
  }
}

///|
test "selecting the current workspace preserves its requested conversation" {
  let model = requested_selection_test_model()
  let (_, selected) = update(
    code_mode_test_dispatch,
    SelectWorkspace(model.selected_workspace_id),
    model,
  )
  let session = code_mode_test_session(
    "session-requested",
    workspace_id="book-requested",
  )
  let (_, loaded) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSelectedSession(session.id, Ok(session)),
    selected,
  )
  assert_eq(loaded.selected_mooncode_session_id, session.id)
  assert_eq(loaded.selected_workspace_id, model.selected_workspace_id)
  assert_eq(loaded.mooncode_sessions_error, "")
}

///|
test "requested session late responses cannot undo selecting another chat" {
  let next_session = code_mode_test_session(
    "session-next",
    workspace_id="book-next",
  )
  let model = {
    ..requested_selection_test_model(),
    mooncode_sessions: [next_session],
  }
  let (_, selected) = update(
    code_mode_test_dispatch,
    SelectMoonCodeSession(next_session.id),
    model,
  )
  let old_session = code_mode_test_session(
    "session-requested",
    workspace_id="book-requested",
  )
  let (_, late_detail) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSelectedSession(old_session.id, Ok(old_session)),
    selected,
  )
  let (_, late_list) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([old_session])),
    late_detail,
  )
  assert_eq(late_list.selected_mooncode_session_id, next_session.id)
  assert_eq(late_list.selected_workspace_id, "book-next")
  assert_eq(late_list.requested_workspace_id, "")
}

///|
test "requested unresolved session is not restored after leaving Code" {
  let old_session = code_mode_test_session(
    "session-requested",
    workspace_id="book-requested",
  )
  let (_, left) = update(
    code_mode_test_dispatch,
    SelectWorkspaceMode(Desk),
    requested_selection_test_model(),
  )
  let (_, late) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSelectedSession(old_session.id, Ok(old_session)),
    left,
  )
  let (_, listed) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([old_session])),
    late,
  )
  assert_eq(listed.selected_mooncode_session_id, "")
  assert_true(listed.workspace_mode is Desk)
}

///|
test "requested workspace only can select its chat when an unrelated list arrives first" {
  let model = {
    ..requested_selection_test_model(),
    selected_mooncode_session_id: "",
  }
  let (_, empty) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(
      Ok([code_mode_test_session("unrelated", workspace_id="book-other")]),
    ),
    model,
  )
  let session = code_mode_test_session(
    "session-requested",
    workspace_id="book-requested",
  )
  let (_, resolved) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    empty,
  )
  assert_eq(resolved.selected_workspace_id, "book-requested")
  assert_eq(resolved.selected_mooncode_session_id, session.id)
}

///|
test "requested mismatched workspace and session never open the other book" {
  let model = {
    ..requested_selection_test_model(),
    workspaces: [requested_selection_test_workspace("book-requested")],
  }
  let wrong = code_mode_test_session(
    "session-requested",
    workspace_id="other-book",
  )
  for
    result in [
      LoadedMoonCodeSessions(Ok([wrong])),
      LoadedMoonCodeSelectedSession(wrong.id, Ok(wrong)),
    ] {
    let (_, next) = update(code_mode_test_dispatch, result, model)
    assert_eq(next.selected_workspace_id, "book-requested")
    assert_eq(next.selected_mooncode_session_id, "session-requested")
    assert_true(selected_mooncode_session(next) is None)
    let markup = render_test_dom(
      @rabbita.static_cell(
        render_requested_selection(code_mode_test_dispatch, next),
      ),
    )
    assert_true(markup.contains("belongs to another MoonBook"))
  }
}

///|
test "requested selection leaves ordinary no-target default selection intact" {
  let (_, catalog) = update(
    code_mode_test_dispatch,
    LoadedWorkspaces(Ok([requested_selection_test_workspace("book-first")])),
    init_model(),
  )
  assert_eq(catalog.selected_workspace_id, "book-first")
  let session = code_mode_test_session(
    "session-first",
    workspace_id="book-first",
  )
  let (_, selected) = update(
    code_mode_test_dispatch,
    LoadedMoonCodeSessions(Ok([session])),
    catalog,
  )
  assert_eq(selected.selected_mooncode_session_id, session.id)
}

///|
test "requested missing workspace renders recoverable Desk state" {
  let model = {
    ..requested_selection_test_model(),
    selected_mooncode_session_id: "",
    workspace_mode: Desk,
  }
  let markup = render_test_dom(
    @rabbita.static_cell(render_app(code_mode_test_dispatch, model)),
  )
  assert_true(markup.contains("data-testid=\"requested-selection\""))
  assert_true(markup.contains("book-requested"))
  assert_true(markup.contains("Loading the requested work"))
}

///|
test "requested session cannot return after creating or importing another MoonBook" {
  let created : CreatedWorkspace = {
    workspace_id: "book-new",
    book_id: "new",
    name: "New",
    path: "wiki/index.md",
  }
  for
    message in [
      CreatedBlankMoonBook(Ok(created)),
      ImportedMoonBook(Ok(created)),
    ] {
    let (_, opened) = update(
      code_mode_test_dispatch,
      message,
      requested_selection_test_model(),
    )
    let old = code_mode_test_session(
      "session-requested",
      workspace_id="book-requested",
    )
    let (_, late) = update(
      code_mode_test_dispatch,
      LoadedMoonCodeSelectedSession(old.id, Ok(old)),
      opened,
    )
    let (_, listed) = update(
      code_mode_test_dispatch,
      LoadedMoonCodeSessions(Ok([old])),
      late,
    )
    assert_eq(listed.selected_workspace_id, "book-new")
    assert_eq(listed.selected_mooncode_session_id, "")
    assert_eq(listed.requested_workspace_id, "book-new")
    assert_true(
      listed.mooncode_watch_generation >
      requested_selection_test_model().mooncode_watch_generation,
    )
  }
}

///|
test "requested session survives entering Code from a link without activity" {
  let previous = requested_selection_install_test_location(
    "?session=session-requested",
  )
  let model = init_model()
  requested_selection_restore_test_location(previous)
  let (_, code) = update(
    code_mode_test_dispatch,
    SelectWorkspaceMode(MoonCode),
    model,
  )
  assert_eq(code.selected_mooncode_session_id, "session-requested")
  assert_true(code.mooncode_selected_session_loading)
}

///|
struct RequestedSelectionTestScheduler {
  hooks : @cmd.Hooks
}

///|
impl @cmd.Scheduler for RequestedSelectionTestScheduler with fn run_effect(
  self,
  _kind,
  effect,
) {
  effect(self)
}

///|
impl @cmd.Scheduler for RequestedSelectionTestScheduler with fn queue_message(
  _self,
  _id,
  send,
) {
  send()
}

///|
impl @cmd.Scheduler for RequestedSelectionTestScheduler with fn drain_message(
  _self,
) {
  ()
}

///|
impl @cmd.Scheduler for RequestedSelectionTestScheduler with fn hooks(self) {
  self.hooks
}

///|
extern "js" fn requested_selection_install_test_history() -> @js.Value =
  #| () => {
  #|   const previous = [globalThis.location, globalThis.history];
  #|   globalThis.location = new URL("https://example.test/?activity=code&workspace=book-requested&session=session-requested");
  #|   globalThis.history = { replaceState: (_state, _title, url) => { globalThis.location = new URL(url); } };
  #|   return previous;
  #| }

///|
extern "js" fn requested_selection_restore_test_history(previous : @js.Value) =
  #| (previous) => {
  #|   if (previous[0] === undefined) delete globalThis.location; else globalThis.location = previous[0];
  #|   if (previous[1] === undefined) delete globalThis.history; else globalThis.history = previous[1];
  #| }

///|
test "requested session cancellation clears URL before a reload" {
  let scheduler : RequestedSelectionTestScheduler = {
    hooks: { url_request: None, url_changed: None, },
  }
  for
    navigation in [
      SelectWorkspaceMode(Desk),
      SelectActivity(Town),
      SelectSearchHit("book-requested", "wiki/next.md"),
    ] {
    let previous = requested_selection_install_test_history()
    let model = init_model()
    let (_, next) = update(code_mode_test_dispatch, navigation, model)
    @cmd.Scheduler::add(
      scheduler,
      sync_departed_session_context_cmd(model, next),
    )
    let reloaded = init_model()
    requested_selection_restore_test_history(previous)
    assert_eq(next.selected_mooncode_session_id, "")
    assert_eq(reloaded.selected_mooncode_session_id, "")
    assert_eq(reloaded.selected_workspace_id, next.selected_workspace_id)
  }
}
